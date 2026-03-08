AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local DEFAULT_CONFIG = {
    health_base = 33750,
    health_per_player = 2500,
    min_players = 10,
    speed = 600,
    chase_range = 2000,
    chase_duration = 7,
    attack_range = 200,
    attack_cooldown = 1,
    attack_damage = 125,
    teleport_interval = 12,
    teleport_reappear_delay = 0.35,
    teleport_ground_offset = 75,
    disguise_interval = 25,
    disguise_duration = 8,
    disguise_regen_fraction = 0.001,
    fireball_interval_min = 4,
    fireball_interval_max = 7,
    grenade_interval_min = 6,
    grenade_interval_max = 10,
    zap_interval_min = 8,
    zap_interval_max = 12,
    bomb_head_interval = 10,
    bomb_head_duration = 15,
    bomb_head_per_team = 1,
    bomb_head_damage = 120,
    bomb_head_radius = 220,
    bomb_stun_radius = 350,
    stun_duration = 2,
}

local BASE_GAME_PATH = "gamemodes/tf/gamemode/halloween/merasmus/"
local BASE_DATA_PATH = "tf2gm/halloween/merasmus/"
local DEFAULT_PROP_MODELS = {
    "models/props_halloween/pumpkin_02.mdl",
    "models/props_halloween/pumpkin_03.mdl",
    "models/egypt/palm_tree/palm_tree.mdl",
    "models/props_spytech/control_room_console01.mdl",
    "models/props_spytech/work_table001.mdl",
    "models/props_coalmines/boulder1.mdl",
    "models/props_coalmines/boulder2.mdl",
    "models/props_farm/concrete_block001.mdl",
    "models/props_farm/welding_machine01.mdl",
    "models/props_medieval/medieval_resupply.mdl",
    "models/props_medieval/target/target.mdl",
    "models/props_swamp/picnic_table.mdl",
    "models/props_manor/baby_grand_01.mdl",
    "models/props_manor/bookcase_132_02.mdl",
    "models/props_manor/chair_01.mdl",
    "models/props_manor/couch_01.mdl",
    "models/props_manor/grandfather_clock_01.mdl",
    "models/props_viaduct_event/coffin_simple_closed.mdl",
    "models/props_2fort/miningcrate001.mdl",
    "models/props_gameplay/resupply_locker.mdl",
    "models/props_2fort/oildrum.mdl",
    "models/props_lakeside/wood_crate_01.mdl",
    "models/props_well/hand_truck01.mdl",
    "models/props_vehicles/mining_car_metal.mdl",
    "models/props_2fort/tire002.mdl",
    "models/props_well/computer_cart01.mdl",
}

local function deep_copy(tbl)
    local out = {}
    for k, v in pairs(tbl or {}) do
        out[k] = istable(v) and deep_copy(v) or v
    end
    return out
end

local function merge_into(dst, src)
    if not istable(src) then return dst end
    for k, v in pairs(src) do
        if istable(v) and istable(dst[k]) then
            merge_into(dst[k], v)
        elseif istable(v) then
            dst[k] = deep_copy(v)
        else
            dst[k] = v
        end
    end
    return dst
end

local function read_json(path, realm)
    local raw = file.Read(path, realm)
    if not raw or raw == "" then return nil end
    local parsed = util.JSONToTable(raw)
    if not istable(parsed) then
        ErrorNoHalt(string.format("[merasmus] Invalid JSON in %s (%s)\n", path, realm))
        return nil
    end
    return parsed
end

local function read_lua_module(path, realm)
    local raw = file.Read(path, realm)
    if not raw or raw == "" then return nil end
    local fn = CompileString(raw, string.format("merasmus_cfg_%s", path), false)
    if type(fn) ~= "function" then
        ErrorNoHalt(string.format("[merasmus] Failed to compile %s (%s)\n", path, realm))
        return nil
    end
    local ok, out = pcall(fn)
    if not ok then
        ErrorNoHalt(string.format("[merasmus] Error running %s: %s\n", path, tostring(out)))
        return nil
    end
    return istable(out) and out or nil
end

local function collect_living_humans()
    local total = 0
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply)
            and ply:IsPlayer()
            and ply:Alive()
            and (GAMEMODE:EntityTeam(ply) == TEAM_RED or GAMEMODE:EntityTeam(ply) == TEAM_BLU)
        then
            total = total + 1
        end
    end
    return total
end

local function is_valid_target(ply)
    return IsValid(ply)
        and ply:IsPlayer()
        and ply:Alive()
        and not ply:IsFlagSet(FL_NOTARGET)
        and (GAMEMODE:EntityTeam(ply) == TEAM_RED or GAMEMODE:EntityTeam(ply) == TEAM_BLU)
end

local function safe_ground(pos, filter)
    local tr = util.TraceHull({
        start = pos + Vector(0, 0, 256),
        endpos = pos - Vector(0, 0, 2048),
        mins = Vector(-30, -30, 0),
        maxs = Vector(30, 30, 100),
        mask = MASK_NPCSOLID_BRUSHONLY,
        filter = filter,
    })
    if tr.Hit then
        return tr.HitPos
    end
    return pos
end

local function start_activity_safe(ent, activity)
    if not activity or not ent.StartActivity then return false end
    if ent._tfDesiredActivity == activity and ent.GetActivity and ent:GetActivity() == activity then
        return true
    end
    local ok = pcall(ent.StartActivity, ent, activity)
    if ok then
        ent._tfDesiredActivity = activity
    end
    return ok
end

local function resolve_pos(other)
    if isvector(other) then
        return other
    end
    if IsValid(other) and other.GetPos then
        return other:GetPos()
    end
    return nil
end

local function explode_bomb_head(victim, owner, damage, radius)
    if not IsValid(victim) then return end
    local info = DamageInfo()
    info:SetAttacker(IsValid(owner) and owner or game.GetWorld())
    info:SetInflictor(IsValid(owner) and owner or game.GetWorld())
    info:SetDamage(damage)
    info:SetDamageType(bit.bor(DMG_BLAST, DMG_SONIC))
    util.BlastDamageInfo(info, victim:WorldSpaceCenter(), radius)
    victim:EmitSound("Halloween.Merasmus_Hiding_Explode", 90, 100)
    if DispatchParticleEffect then
        DispatchParticleEffect("merasmus_dazed_explosion", victim:WorldSpaceCenter(), angle_zero)
    end
end

function ENT:LoadDynamicConfig()
    local map = string.lower(game.GetMap() or "")
    local cfg = deep_copy(DEFAULT_CONFIG)
    merge_into(cfg, read_json(BASE_GAME_PATH .. "default.json", "GAME"))
    merge_into(cfg, read_json(BASE_GAME_PATH .. "maps/" .. map .. ".json", "GAME"))
    merge_into(cfg, read_json(BASE_DATA_PATH .. "default.json", "DATA"))
    merge_into(cfg, read_json(BASE_DATA_PATH .. "maps/" .. map .. ".json", "DATA"))

    local script = { prop_models = deep_copy(DEFAULT_PROP_MODELS) }
    merge_into(script, read_lua_module(BASE_GAME_PATH .. "default.lua", "GAME"))
    merge_into(script, read_lua_module(BASE_GAME_PATH .. "maps/" .. map .. ".lua", "GAME"))
    merge_into(script, read_lua_module(BASE_DATA_PATH .. "default.lua", "DATA"))
    merge_into(script, read_lua_module(BASE_DATA_PATH .. "maps/" .. map .. ".lua", "DATA"))

    self.DynamicConfig = cfg
    self.DynamicScript = script
end

function ENT:ComputeScaledHealth()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    local hp = tonumber(cfg.health_base) or DEFAULT_CONFIG.health_base
    local minPlayers = tonumber(cfg.min_players) or DEFAULT_CONFIG.min_players
    local perPlayer = tonumber(cfg.health_per_player) or DEFAULT_CONFIG.health_per_player
    local total = collect_living_humans()
    if total > minPlayers then
        hp = hp + (total - minPlayers) * perPlayer
    end
    return math.max(1, math.floor(hp))
end

function ENT:Team()
    return TEAM_NEUTRAL
end

function ENT:GetTeamNumber()
    return TEAM_NEUTRAL
end

function ENT:IsRangeLessThan(other, dist)
    local otherPos = resolve_pos(other)
    if not otherPos then return false end
    return self:GetPos():DistToSqr(otherPos) < (dist * dist)
end

function ENT:IsRangeGreaterThan(other, dist)
    local otherPos = resolve_pos(other)
    if not otherPos then return false end
    return self:GetPos():DistToSqr(otherPos) > (dist * dist)
end

function ENT:SetBossState(name, duration)
    self.StateName = name
    self.StateUntil = CurTime() + math.max(0, tonumber(duration) or 0)
    self:UpdateAnimationState()
    if istable(self.DynamicScript) and isfunction(self.DynamicScript.OnStateChanged) then
        pcall(self.DynamicScript.OnStateChanged, self, name, self.DynamicConfig)
    end
end

function ENT:UpdateAnimationState()
    if self.StateName == "reveal" then
        start_activity_safe(self, ACT_SHIELD_UP)
        return
    end
    if self.StateName == "teleporting" then
        start_activity_safe(self, ACT_SHIELD_DOWN)
        return
    end
    if self.StateName == "stunned" then
        start_activity_safe(self, ACT_IDLE)
        return
    end

    local target = IsValid(self.Target) and self.Target or nil
    if IsValid(target) then
        local attackRange = tonumber((self.DynamicConfig or DEFAULT_CONFIG).attack_range) or DEFAULT_CONFIG.attack_range
        if self:IsRangeLessThan(target, attackRange) then
            start_activity_safe(self, ACT_MP_RUN_MELEE)
        else
            start_activity_safe(self, ACT_MP_RUN_ITEM1)
        end
    else
        start_activity_safe(self, ACT_MP_RUN_MELEE)
    end
end

function ENT:Initialize()
    self:LoadDynamicConfig()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG

    self:SetModel(self.Model)
    self:SetSkin(1)
    self:SetHealth(self:ComputeScaledHealth())
    if self.SetMaxHealth then
        self:SetMaxHealth(self:Health())
    end
    if self.SetBloodColor then
        self:SetBloodColor(DONT_BLEED)
    end
    self:SetNWInt("Team", TEAM_NEUTRAL)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-30, -30, 0), Vector(30, 30, 100))
    self:SetCollisionGroup(COLLISION_GROUP_NPC)

    self.HomePos = safe_ground(self:GetPos(), self) + Vector(0, 0, tonumber(cfg.teleport_ground_offset) or DEFAULT_CONFIG.teleport_ground_offset)
    self.Path = Path("Follow")
    self.Path:SetMinLookAheadDistance(100)
    self.Path:SetGoalTolerance(20)
    self.PathTarget = nil
    self.NextRepath = 0
    self.Target = nil
    self.FocusUntil = 0
    self.NextAttack = 0
    self.NextTeleport = CurTime() + (tonumber(cfg.teleport_interval) or DEFAULT_CONFIG.teleport_interval)
    self.NextDisguise = CurTime() + (tonumber(cfg.disguise_interval) or DEFAULT_CONFIG.disguise_interval)
    self.NextFireball = CurTime() + math.Rand(tonumber(cfg.fireball_interval_min) or DEFAULT_CONFIG.fireball_interval_min, tonumber(cfg.fireball_interval_max) or DEFAULT_CONFIG.fireball_interval_max)
    self.NextGrenade = CurTime() + math.Rand(tonumber(cfg.grenade_interval_min) or DEFAULT_CONFIG.grenade_interval_min, tonumber(cfg.grenade_interval_max) or DEFAULT_CONFIG.grenade_interval_max)
    self.NextZap = CurTime() + math.Rand(tonumber(cfg.zap_interval_min) or DEFAULT_CONFIG.zap_interval_min, tonumber(cfg.zap_interval_max) or DEFAULT_CONFIG.zap_interval_max)
    self.NextBombHead = CurTime() + (tonumber(cfg.bomb_head_interval) or DEFAULT_CONFIG.bomb_head_interval)
    self.FakeProps = {}
    self.BombHeadVictims = {}

    self:SetPos(self.HomePos)
    self:SetBossState("reveal", 1.2)
    self:EmitSound("Halloween.MerasmusAppears", 100, 100)
    if DispatchParticleEffect then
        DispatchParticleEffect("merasmus_spawn", self:GetPos(), self:GetAngles())
        ParticleEffectAttach("merasmus_ambient_body", PATTACH_ABSORIGIN_FOLLOW, self, 0)
    end
    self:UpdateAnimationState()
end

function ENT:RunBehaviour()
    while true do
        coroutine.yield()
    end
end

function ENT:BodyUpdate()
    local act = self.GetActivity and self:GetActivity() or ACT_IDLE
    if act == ACT_MP_RUN_ITEM1 or act == ACT_MP_RUN_MELEE then
        self:BodyMoveXY()
        return
    end
    self:FrameAdvance()
end

function ENT:OnRemove()
    self:RemoveFakeProps()
    for entIndex, _ in pairs(self.BombHeadVictims or {}) do
        timer.Remove("TF2MerasmusBombHead" .. tostring(entIndex))
    end
end

function ENT:PickTarget()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    if is_valid_target(self.Target) and CurTime() < self.FocusUntil and self.HomePos:Distance(self.Target:GetPos()) <= (tonumber(cfg.chase_range) or DEFAULT_CONFIG.chase_range) then
        return self.Target
    end

    local best, bestDist
    for _, ply in ipairs(player.GetAll()) do
        if is_valid_target(ply) and self.HomePos:Distance(ply:GetPos()) <= (tonumber(cfg.chase_range) or DEFAULT_CONFIG.chase_range) then
            local dist = self:GetRangeTo(ply:GetPos())
            if not best or dist < bestDist then
                best = ply
                bestDist = dist
            end
        end
    end

    if istable(self.DynamicScript) and isfunction(self.DynamicScript.SelectTarget) then
        local ok, override = pcall(self.DynamicScript.SelectTarget, self, best)
        if ok and IsValid(override) then
            best = override
        end
    end

    self.Target = best
    self.FocusUntil = CurTime() + (tonumber(cfg.chase_duration) or DEFAULT_CONFIG.chase_duration)
    return best
end

function ENT:UpdatePath(goal)
    if not goal then return end
    if CurTime() < self.NextRepath and self.Path:IsValid() and self.PathTarget and self.PathTarget:DistToSqr(goal) < 1 then
        self.Path:Update(self)
        return
    end

    self.PathTarget = Vector(goal.x, goal.y, goal.z)
    self.NextRepath = CurTime() + 0.4
    self.Path:Compute(self, self.PathTarget)
    if self.Path:IsValid() then
        self.Path:Update(self)
    else
        -- Fall back to direct NextBot locomotion when nav/path following is unavailable.
        self.loco:Approach(self.PathTarget, 1)
    end
end

function ENT:OnTakeDamage(dmginfo)
    if not dmginfo then return 0 end

    if IsValid(dmginfo:GetAttacker()) and GAMEMODE:EntityTeam(dmginfo:GetAttacker()) == self:Team() then
        return 0
    end

    local damage = math.max(0, math.floor(dmginfo:GetDamage() or 0))
    if damage > 0 then
        self:SetHealth(math.max(0, self:Health() - damage))
    end

    local event = gameeventmanager and gameeventmanager.CreateEvent and gameeventmanager:CreateEvent("npc_hurt")
    if event then
        event:SetInt("entindex", self:EntIndex())
        event:SetInt("health", math.max(0, self:Health()))
        event:SetInt("damageamount", damage)
        event:SetBool("crit", bit.band(dmginfo:GetDamageType() or 0, DMG_CRITICAL) ~= 0)
        event:SetInt("boss", HALLOWEEN_BOSS_MERASMUS or 0)

        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() then
            event:SetInt("attacker_player", attacker:UserID())
            local weapon = attacker.GetActiveWeapon and attacker:GetActiveWeapon() or NULL
            if IsValid(weapon) and weapon.GetWeaponID then
                event:SetInt("weaponid", weapon:GetWeaponID() or 0)
            else
                event:SetInt("weaponid", 0)
            end
        else
            event:SetInt("attacker_player", 0)
            event:SetInt("weaponid", 0)
        end

        gameeventmanager:FireEvent(event)
    end

    self:OnInjured(dmginfo)

    if self:Health() <= 0 then
        self:OnKilled(dmginfo)
    end

    return damage
end

function ENT:SpawnFireball(target)
    if not IsValid(target) then return end
    local proj = ents.Create("tf_projectile_rocket_fireball")
    if not IsValid(proj) then return end
    local from = self:WorldSpaceCenter() + self:GetForward() * 30 + Vector(0, 0, 40)
    local dir = (target:WorldSpaceCenter() - from):GetNormalized()
    proj:SetPos(from)
    proj:SetAngles(dir:Angle())
    proj:SetOwner(self)
    proj.BaseDamage = 90
    proj.BaseSpeed = 1000
    proj.critical = true
    proj:Spawn()
    proj:Activate()
    self:EmitSound("Halloween.MerasmusCastFireSpell", 100, 100)
    self:EmitSound("Halloween.MerasmusLaunchSpell", 100, 100)
    if DispatchParticleEffect then
        DispatchParticleEffect("merasmus_shoot", from, dir:Angle())
    end
end

function ENT:SpawnGrenade(target)
    if not IsValid(target) then return end
    local proj = ents.Create("tf_projectile_pipe")
    if not IsValid(proj) then return end
    local from = self:WorldSpaceCenter() + Vector(0, 0, 45)
    local toTarget = target:WorldSpaceCenter() - from
    proj:SetPos(from)
    proj:SetAngles(toTarget:Angle())
    proj:SetOwner(self)
    proj.BaseDamage = 100
    proj.GrenadeMode = 0
    proj:Spawn()
    proj:Activate()
    local phys = proj:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(toTarget:GetNormalized() * 700 + Vector(0, 0, 260))
    end
    self:EmitSound("Halloween.MerasmusGrenadeThrow", 100, 100)
end

function ENT:DoZap()
    local hits = 0
    for _, ply in ipairs(player.GetAll()) do
        if hits >= 3 then break end
        if is_valid_target(ply) and self:IsLineOfSightClear(ply) and self:IsRangeLessThan(ply, 900) then
            local info = DamageInfo()
            info:SetAttacker(self)
            info:SetInflictor(self)
            info:SetDamage(math.random(15, 30))
            info:SetDamageType(bit.bor(DMG_SHOCK, DMG_ENERGYBEAM))
            ply:TakeDamageInfo(info)
            ply:AddPlayerState(PLAYERSTATE_STUNNED, true)
            timer.Create("TF2MerasmusZapStun" .. ply:EntIndex(), 0.75, 1, function()
                if IsValid(ply) then
                    ply:RemovePlayerState(PLAYERSTATE_STUNNED, true)
                end
            end)
            if DispatchParticleEffect then
                DispatchParticleEffect("merasmus_zap", ply:WorldSpaceCenter(), angle_zero)
            end
            hits = hits + 1
        end
    end
    if hits > 0 then
        self:EmitSound("Halloween.Merasmus_Spell", 100, 100)
    end
end

function ENT:BeginStun(attacker)
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    self.StunAttacker = attacker
    self:SetBossState("stunned", tonumber(cfg.stun_duration) or DEFAULT_CONFIG.stun_duration)
    self:EmitSound("Halloween.Merasmus_Stun", 100, 100)
    self:EmitSound("Halloween.MerasmusHitByBomb", 100, 100)
    if DispatchParticleEffect then
        DispatchParticleEffect("merasmus_dazed", self:WorldSpaceCenter(), self:GetAngles())
    end
end

function ENT:PickTeleportPosition()
    local origin = self.HomePos
    if IsValid(self.Target) then
        origin = self.Target:GetPos() + Vector(math.Rand(-600, 600), math.Rand(-600, 600), 0)
    else
        origin = self.HomePos + Vector(math.Rand(-500, 500), math.Rand(-500, 500), 0)
    end
    if istable(self.DynamicScript) and isfunction(self.DynamicScript.SelectTeleportPos) then
        local ok, override = pcall(self.DynamicScript.SelectTeleportPos, self, origin)
        if ok and isvector(override) then
            origin = override
        end
    end
    return safe_ground(origin, self) + Vector(0, 0, tonumber((self.DynamicConfig or DEFAULT_CONFIG).teleport_ground_offset) or DEFAULT_CONFIG.teleport_ground_offset)
end

function ENT:DoTeleport()
    if DispatchParticleEffect then
        DispatchParticleEffect("merasmus_tp", self:WorldSpaceCenter(), self:GetAngles())
    end
    self:AddEffects(EF_NODRAW)
    self:SetNotSolid(true)
    self.TeleportDestination = self:PickTeleportPosition()
    self:SetBossState("teleporting", tonumber((self.DynamicConfig or DEFAULT_CONFIG).teleport_reappear_delay) or DEFAULT_CONFIG.teleport_reappear_delay)
end

function ENT:FinishTeleport()
    self:SetPos(self.TeleportDestination or self.HomePos)
    self:RemoveEffects(EF_NODRAW)
    self:SetNotSolid(false)
    if DispatchParticleEffect then
        DispatchParticleEffect("merasmus_tp", self:WorldSpaceCenter(), self:GetAngles())
    end
    self.TeleportDestination = nil
    self:SetBossState("attack", 0)
end

function ENT:RemoveFakeProps()
    for _, prop in ipairs(self.FakeProps or {}) do
        if IsValid(prop) then
            prop:Remove()
        end
    end
    self.FakeProps = {}
end

function ENT:SpawnFakeProps()
    self:RemoveFakeProps()
    local models = (istable(self.DynamicScript) and istable(self.DynamicScript.prop_models) and self.DynamicScript.prop_models) or DEFAULT_PROP_MODELS
    for i = 1, math.min(10, #models) do
        local prop = ents.Create("prop_dynamic")
        if not IsValid(prop) then continue end
        prop:SetModel(table.Random(models))
        prop:SetPos(safe_ground(self.HomePos + Vector(math.Rand(-700, 700), math.Rand(-700, 700), 0), self))
        prop:SetAngles(Angle(0, math.random(0, 359), 0))
        prop:Spawn()
        self.FakeProps[#self.FakeProps + 1] = prop
    end
end

function ENT:StartDisguise()
    self:SpawnFakeProps()
    self:AddEffects(EF_NODRAW)
    self:SetNotSolid(true)
    self:EmitSound("Halloween.MerasmusInitiateHiding", 100, 100)
    self:SetBossState("disguise", tonumber((self.DynamicConfig or DEFAULT_CONFIG).disguise_duration) or DEFAULT_CONFIG.disguise_duration)
end

function ENT:RevealFromDisguise(playSound)
    self:RemoveEffects(EF_NODRAW)
    self:SetNotSolid(false)
    self:RemoveFakeProps()
    if playSound ~= false then
        self:EmitSound("Halloween.MerasmusDiscovered", 100, 100)
    end
    if DispatchParticleEffect then
        DispatchParticleEffect("merasmus_tp", self:WorldSpaceCenter(), self:GetAngles())
    end
    self:SetBossState("attack", 0)
end

function ENT:ApplyBombHeadToPlayer(ply)
    if not is_valid_target(ply) then return end
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    local duration = tonumber(cfg.bomb_head_duration) or DEFAULT_CONFIG.bomb_head_duration
    self.BombHeadVictims[ply:EntIndex()] = true
    ply:AddCond(TF_COND_HALLOWEEN_BOMB_HEAD, duration, self)
    timer.Remove("TF2MerasmusBombHead" .. ply:EntIndex())
    timer.Create("TF2MerasmusBombHead" .. ply:EntIndex(), duration, 1, function()
        if not IsValid(ply) then return end
        ply:RemoveCond(TF_COND_HALLOWEEN_BOMB_HEAD, true)
        explode_bomb_head(ply, self, tonumber(cfg.bomb_head_damage) or DEFAULT_CONFIG.bomb_head_damage, tonumber(cfg.bomb_head_radius) or DEFAULT_CONFIG.bomb_head_radius)
        if IsValid(self) and self:IsRangeLessThan(ply, tonumber(cfg.bomb_stun_radius) or DEFAULT_CONFIG.bomb_stun_radius) then
            self:BeginStun(ply)
        end
        self.BombHeadVictims[ply:EntIndex()] = nil
    end)
end

function ENT:DoBombHeadMode()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    local perTeam = tonumber(cfg.bomb_head_per_team) or DEFAULT_CONFIG.bomb_head_per_team
    local teams = { [TEAM_RED] = {}, [TEAM_BLU] = {} }
    for _, ply in ipairs(player.GetAll()) do
        if is_valid_target(ply) and teams[GAMEMODE:EntityTeam(ply)] then
            teams[GAMEMODE:EntityTeam(ply)][#teams[GAMEMODE:EntityTeam(ply)] + 1] = ply
        end
    end
    for _, list in pairs(teams) do
        for _ = 1, math.min(perTeam, #list) do
            local idx = math.random(1, #list)
            local pick = list[idx]
            table.remove(list, idx)
            if IsValid(pick) then
                self:ApplyBombHeadToPlayer(pick)
            end
        end
    end
end

function ENT:DoMeleeAttack(target)
    if not is_valid_target(target) then return end
    if not self:IsRangeLessThan(target, tonumber((self.DynamicConfig or DEFAULT_CONFIG).attack_range) or DEFAULT_CONFIG.attack_range) then return end
    local info = DamageInfo()
    info:SetAttacker(self)
    info:SetInflictor(self)
    info:SetDamage(tonumber((self.DynamicConfig or DEFAULT_CONFIG).attack_damage) or DEFAULT_CONFIG.attack_damage)
    info:SetDamageType(bit.bor(DMG_CLUB, DMG_SLASH))
    target:TakeDamageInfo(info)
    target:SetVelocity((target:GetPos() - self:GetPos()):GetNormalized() * 250 + Vector(0, 0, 150))
    self:EmitSound((math.random(1, 8) == 1) and "Halloween.MerasmusStaffAttackRare" or "Halloween.MerasmusStaffAttack", 100, 100)
end

function ENT:OnInjured(dmginfo)
    if DispatchParticleEffect then
        DispatchParticleEffect((self.StateName == "stunned") and "merasmus_blood_bits" or "merasmus_blood", dmginfo:GetDamagePosition(), self:GetAngles())
    end
end

function ENT:OnKilled(dmginfo)
    hook.Call("OnNPCKilled", GAMEMODE, self, IsValid(dmginfo) and dmginfo:GetAttacker() or NULL, IsValid(dmginfo) and dmginfo:GetInflictor() or NULL)
    self:EmitSound("Halloween.MerasmusBanish", 100, 100)
    self:EmitSound("Halloween.Merasmus_Death", 100, 100)
    if DispatchParticleEffect then
        DispatchParticleEffect("merasmus_tp", self:WorldSpaceCenter(), self:GetAngles())
    end
    self:Remove()
end

function ENT:Think()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    local now = CurTime()
    if self:Health() <= 0 then
        self:Remove()
        return
    end

    if self.StateName == "reveal" then
        if now >= self.StateUntil then
            self:SetBossState("attack", 0)
        end
    elseif self.StateName == "teleporting" then
        if now >= self.StateUntil then
            self:FinishTeleport()
        end
    elseif self.StateName == "disguise" then
        local regen = (tonumber(cfg.disguise_regen_fraction) or DEFAULT_CONFIG.disguise_regen_fraction) * self:GetMaxHealth() * FrameTime()
        self:SetHealth(math.min(self:GetMaxHealth(), self:Health() + math.floor(regen)))
        if now >= self.StateUntil then
            self:RevealFromDisguise(true)
        end
    elseif self.StateName == "stunned" then
        self.loco:SetDesiredSpeed(0)
        if now >= self.StateUntil then
            self:SetBossState("attack", 0)
        end
    else
        local target = self:PickTarget()
        self:UpdateAnimationState()
        self.loco:SetDesiredSpeed(tonumber(cfg.speed) or DEFAULT_CONFIG.speed)

        if IsValid(target) then
            self.loco:FaceTowards(target:GetPos())
            if self:IsRangeLessThan(target, tonumber(cfg.attack_range) or DEFAULT_CONFIG.attack_range) then
                if now >= self.NextAttack then
                    self.NextAttack = now + (tonumber(cfg.attack_cooldown) or DEFAULT_CONFIG.attack_cooldown)
                    self:DoMeleeAttack(target)
                end
            else
                self:UpdatePath(target:GetPos())
                self.loco:Approach(target:GetPos(), 1)
            end

            if now >= self.NextFireball then
                self.NextFireball = now + math.Rand(tonumber(cfg.fireball_interval_min) or DEFAULT_CONFIG.fireball_interval_min, tonumber(cfg.fireball_interval_max) or DEFAULT_CONFIG.fireball_interval_max)
                self:SpawnFireball(target)
            end
            if now >= self.NextGrenade then
                self.NextGrenade = now + math.Rand(tonumber(cfg.grenade_interval_min) or DEFAULT_CONFIG.grenade_interval_min, tonumber(cfg.grenade_interval_max) or DEFAULT_CONFIG.grenade_interval_max)
                self:SpawnGrenade(target)
            end
            if now >= self.NextZap then
                self.NextZap = now + math.Rand(tonumber(cfg.zap_interval_min) or DEFAULT_CONFIG.zap_interval_min, tonumber(cfg.zap_interval_max) or DEFAULT_CONFIG.zap_interval_max)
                self:DoZap()
            end
        else
            self:UpdatePath(self.HomePos)
            self.loco:Approach(self.HomePos, 1)
        end

        if now >= self.NextBombHead then
            self.NextBombHead = now + (tonumber(cfg.bomb_head_interval) or DEFAULT_CONFIG.bomb_head_interval)
            self:DoBombHeadMode()
        end
        if now >= self.NextTeleport then
            self.NextTeleport = now + (tonumber(cfg.teleport_interval) or DEFAULT_CONFIG.teleport_interval)
            self:DoTeleport()
        elseif now >= self.NextDisguise and self:Health() < self:GetMaxHealth() * 0.75 then
            self.NextDisguise = now + (tonumber(cfg.disguise_interval) or DEFAULT_CONFIG.disguise_interval)
            self:StartDisguise()
        end
    end

    if istable(self.DynamicScript) and isfunction(self.DynamicScript.OnThink) then
        pcall(self.DynamicScript.OnThink, self, self.DynamicConfig)
    end

    self:NextThink(CurTime())
    return true
end

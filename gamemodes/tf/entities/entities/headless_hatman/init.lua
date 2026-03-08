AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local DEFAULT_CONFIG = {
    health_base = 3000,
    health_per_player = 200,
    min_players = 10,
    speed = 400,
    attack_range = 200,
    attack_cooldown = 1.0,
    attack_hit_delay = 0.58,
    attack_damage = 130,
    attack_damage_health_fraction = 0.8,
    chase_range = 1500,
    quit_range = 2000,
    chase_duration = 30,
    stand_and_swing_range = 100,
    it_warn_interval = 7,
    terrify_radius = 500,
    terrify_interval = 20,
    terrify_duration = 2,
    emerge_time = 3,
    emerge_height = 200,
}

local BASE_GAME_PATH = "gamemodes/tf/gamemode/halloween/headless_hatman/"
local BASE_DATA_PATH = "tf2gm/halloween/headless_hatman/"

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
        ErrorNoHalt(string.format("[headless_hatman] Invalid JSON in %s (%s)\n", path, realm))
        return nil
    end
    return parsed
end

local function read_lua_module(path, realm)
    local raw = file.Read(path, realm)
    if not raw or raw == "" then return nil end
    local fn = CompileString(raw, string.format("headless_hatman_cfg_%s", path), false)
    if type(fn) ~= "function" then
        ErrorNoHalt(string.format("[headless_hatman] Failed to compile %s (%s)\n", path, realm))
        return nil
    end
    local ok, out = pcall(fn)
    if not ok then
        ErrorNoHalt(string.format("[headless_hatman] Error running %s: %s\n", path, tostring(out)))
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
        mins = Vector(-24, -24, 0),
        maxs = Vector(24, 24, 170),
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

local function add_gesture_safe(ent, activity)
    if not activity or not ent then return false end
    if ent.AddGesture then
        local ok = pcall(ent.AddGesture, ent, activity)
        if ok then return true end
    end
    if ent.RestartGesture then
        local ok = pcall(ent.RestartGesture, ent, activity, true)
        if ok then return true end
    end
    return false
end

local function try_emit_sound(ent, candidates, level, pitch)
    if not IsValid(ent) then return false end
    if isstring(candidates) then
        candidates = { candidates }
    end
    if not istable(candidates) then return false end
    for _, snd in ipairs(candidates) do
        if isstring(snd) and snd ~= "" then
            local ok = pcall(ent.EmitSound, ent, snd, level, pitch)
            if ok then
                return true
            end
        end
    end
    return false
end

local function play_sequence_safe(ent, names)
    if not IsValid(ent) or not ent.LookupSequence or not ent.SetSequence then return false end
    if not istable(names) then return false end
    for _, name in ipairs(names) do
        local seq = ent:LookupSequence(name)
        if seq and seq > 0 then
            ent:SetSequence(seq)
            ent:SetPlaybackRate(1)
            ent:SetCycle(0)
            if ent.ResetSequenceInfo then
                ent:ResetSequenceInfo()
            end
            return true
        end
    end
    return false
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

function ENT:LoadDynamicConfig()
    local map = string.lower(game.GetMap() or "")
    local cfg = deep_copy(DEFAULT_CONFIG)
    merge_into(cfg, read_json(BASE_GAME_PATH .. "default.json", "GAME"))
    merge_into(cfg, read_json(BASE_GAME_PATH .. "maps/" .. map .. ".json", "GAME"))
    merge_into(cfg, read_json(BASE_DATA_PATH .. "default.json", "DATA"))
    merge_into(cfg, read_json(BASE_DATA_PATH .. "maps/" .. map .. ".json", "DATA"))

    local script = {}
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

function ENT:GetBossWeaponModel()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG

    if isstring(cfg.weapon_model) and cfg.weapon_model ~= "" then
        return cfg.weapon_model
    end
    if tobool(cfg.use_hammer) then
        return "models/weapons/c_models/c_big_mallet/c_big_mallet.mdl"
    end

    if istable(self.DynamicScript) and isfunction(self.DynamicScript.SelectWeaponModel) then
        local ok, model = pcall(self.DynamicScript.SelectWeaponModel, self, cfg)
        if ok and isstring(model) and model ~= "" then
            return model
        end
    end

    local map = string.lower(game.GetMap() or "")
    if string.find(map, "doomsday", 1, true) then
        return "models/weapons/c_models/c_big_mallet/c_big_mallet.mdl"
    end

    return "models/weapons/c_models/c_bigaxe/c_bigaxe.mdl"
end

function ENT:AttachWeaponModelTF2Style()
    if not IsValid(self.Axe) then return end

    -- TF2 source behavior: spawn prop_dynamic and FollowEntity(this, true).
    self.Axe:SetParent(nil)
    self.Axe:AddEffects(bit.bor(EF_BONEMERGE, EF_BONEMERGE_FASTCULL, EF_PARENT_ANIMATES))
    if self.Axe.FollowEntity then
        pcall(self.Axe.FollowEntity, self.Axe, self, true)
    else
        self.Axe:SetParent(self)
        self.Axe:SetLocalPos(vector_origin)
        self.Axe:SetLocalAngles(angle_zero)
    end
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

function ENT:GetCurrentIT()
    if GAMEMODE and GAMEMODE.GetIT then
        local it = GAMEMODE:GetIT()
        return IsValid(it) and it or nil
    end
    return IsValid(self.ITVictim) and self.ITVictim or nil
end

function ENT:SetCurrentIT(victim)
    if GAMEMODE and GAMEMODE.SetIT then
        GAMEMODE:SetIT(victim)
    else
        local oldIT = IsValid(self.ITVictim) and self.ITVictim or nil
        local newIT = IsValid(victim) and victim or nil
        if IsValid(newIT) and oldIT ~= newIT then
            if newIT.PrintMessage then
                newIT:PrintMessage(HUD_PRINTTALK, "#TF_HALLOWEEN_BOSS_WARN_VICTIM")
                newIT:PrintMessage(HUD_PRINTCENTER, "#TF_HALLOWEEN_BOSS_WARN_VICTIM")
            end
            try_emit_sound(newIT, { "Player.YouAreIT", "Player.YouAreIt" }, 100, 100)
            try_emit_sound(newIT, "Halloween.PlayerScream", 100, 100)
        end
        if IsValid(oldIT) and oldIT ~= newIT and oldIT:Alive() then
            try_emit_sound(oldIT, { "Player.TaggedOtherIT", "Player.TaggedOtherIt" }, 100, 100)
            if oldIT.PrintMessage then
                oldIT:PrintMessage(HUD_PRINTTALK, "#TF_HALLOWEEN_BOSS_LOST_AGGRO")
                oldIT:PrintMessage(HUD_PRINTCENTER, "#TF_HALLOWEEN_BOSS_LOST_AGGRO")
            end
        end
        self.ITVictim = newIT
    end
    self.ITVictim = IsValid(victim) and victim or nil
end

function ENT:ApplySpookStun(victim, duration)
    if not IsValid(victim) then return end
    local stunFlags = bit.bor(_G.TF_STUN_LOSER_STATE or 0, _G.TF_STUN_BY_TRIGGER or 0)
    duration = math.max(0.1, tonumber(duration) or 2)

    if victim.StunPlayer then
        pcall(victim.StunPlayer, victim, duration, 0, stunFlags, self)
    end

    if victim.AddCond and _G.TF_COND_STUNNED then
        pcall(victim.AddCond, victim, TF_COND_STUNNED, duration, self)
    end

    if victim.AddPlayerState then
        victim:AddPlayerState(PLAYERSTATE_STUNNED, true)
    end

    timer.Create("TF2HHHSpookFallback" .. victim:EntIndex(), duration, 1, function()
        if not IsValid(victim) then return end
        if victim.RemovePlayerState then
            victim:RemovePlayerState(PLAYERSTATE_STUNNED, true)
        end
        if victim.RemoveCond and _G.TF_COND_STUNNED then
            victim:RemoveCond(TF_COND_STUNNED, true)
        end
    end)

    if victim.EmitSound then
        victim:EmitSound("player/pl_impact_stun.wav", 90, 100)
    end

    if DispatchParticleEffect then
        DispatchParticleEffect("yikes_fx", victim:WorldSpaceCenter(), angle_zero, victim)
    end
end

function ENT:SetBossState(name, duration)
    local previous = self.StateName
    self.StateName = name
    self.StateUntil = CurTime() + math.max(0, tonumber(duration) or 0)
    if name ~= "attack" then
        self.AttackSwinging = false
        self.AttackTarget = nil
    end
    self:UpdateAnimationState()
    if name == "terrify" and previous ~= "terrify" then
        local now = CurTime()
        self.BooAt = self.BooAt or (now + 0.25)
        self.ScareAt = self.ScareAt or (now + 0.75)
        self.BooPlayed = false
        self.ScareApplied = false
        add_gesture_safe(self, ACT_MP_GESTURE_VC_HANDMOUTH_ITEM1)
    end
    if istable(self.DynamicScript) and isfunction(self.DynamicScript.OnStateChanged) then
        pcall(self.DynamicScript.OnStateChanged, self, name, self.DynamicConfig)
    end
end

function ENT:UpdateAnimationState()
    if self.StateName == "emerge" then
        start_activity_safe(self, ACT_TRANSITION)
        return
    end
    if self.AttackSwinging then
        start_activity_safe(self, ACT_MP_ATTACK_STAND_ITEM1)
        return
    end
    if self.StateName == "terrify" then
        start_activity_safe(self, ACT_MP_STAND_ITEM1)
        return
    end

    local moving = self.loco and self.loco.IsAttemptingToMove and self.loco:IsAttemptingToMove()
    if moving then
        local maxHealth = math.max(1, (self.GetMaxHealth and self:GetMaxHealth()) or self:Health())
        local healthRatio = self:Health() / maxHealth
        if healthRatio > 0.5 then
            start_activity_safe(self, ACT_MP_RUN_ITEM1)
        else
            start_activity_safe(self, ACT_MP_RUN_MELEE)
        end
        return
    end

    start_activity_safe(self, ACT_MP_STAND_ITEM1)
end

function ENT:Initialize()
    self:LoadDynamicConfig()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG

    self:SetModel(self.Model)
    self:SetHealth(self:ComputeScaledHealth())
    if self.SetMaxHealth then
        self:SetMaxHealth(self:Health())
    end
    if self.SetBloodColor then
        self:SetBloodColor(DONT_BLEED)
    end
    self:SetNWInt("Team", TEAM_NEUTRAL)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-24, -24, 0), Vector(24, 24, 170))
    self:SetCollisionGroup(COLLISION_GROUP_NPC)

    self.HomePos = safe_ground(self:GetPos(), self) + Vector(0, 0, 10)
    self.Path = Path("Follow")
    self.Path:SetMinLookAheadDistance(100)
    self.Path:SetGoalTolerance(20)
    self.PathTarget = nil
    self.NextRepath = 0
    self.Target = nil
    self.FocusUntil = 0
    self.NextAttack = 0
    self.AttackSwinging = false
    self.AttackHitAt = 0
    self.AttackTarget = nil
    self.NextScare = CurTime() + (tonumber(cfg.terrify_interval) or DEFAULT_CONFIG.terrify_interval)
    self.NextITWarn = 0
    self.NextRumble = 0
    self.BooPlayed = false
    self.ScareApplied = false

    self.EmergeHeight = tonumber(cfg.emerge_height) or DEFAULT_CONFIG.emerge_height
    self:SetPos(self.HomePos - Vector(0, 0, self.EmergeHeight))
    self:SetBossState("emerge", tonumber(cfg.emerge_time) or DEFAULT_CONFIG.emerge_time)

    self:EmitSound("Halloween.HeadlessBossSpawnRumble", 100, 100)
    self:EmitSound("Halloween.HeadlessBossSpawn", 100, 100)
    if DispatchParticleEffect then
        DispatchParticleEffect("halloween_boss_summon", self.HomePos, self:GetAngles())
        ParticleEffectAttach("halloween_boss_eye_glow", PATTACH_ABSORIGIN_FOLLOW, self, 0)
    end
    self.NextFootstep = 0

    self.Axe = ents.Create("prop_dynamic")
    if IsValid(self.Axe) then
        self.Axe:SetModel(self:GetBossWeaponModel())
        self.Axe:SetPos(self:GetPos())
        self.Axe:SetAngles(self:GetAngles())
        self.Axe:Spawn()
        self:AttachWeaponModelTF2Style()
        timer.Simple(0, function()
            if IsValid(self) then
                self:AttachWeaponModelTF2Style()
            end
        end)
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
    self:SetCurrentIT(nil)
    if IsValid(self.Axe) then
        self.Axe:Remove()
    end
end

function ENT:IsPotentiallyChaseable(ply)
    if not is_valid_target(ply) then return false end
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    if self.HomePos:Distance(ply:GetPos()) > (tonumber(cfg.quit_range) or DEFAULT_CONFIG.quit_range) then
        return false
    end
    if ply.GetNWBool and ply:GetNWBool("InRespawnRoom", false) then
        return false
    end
    if ply.InCond and (ply:InCond(TF_COND_HALLOWEEN_GHOST_MODE) or ply:InCond(TF_COND_INVULNERABLE)) then
        return false
    end
    if ply.InCond and ply:InCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED) then
        return false
    end
    return true
end

function ENT:PickTarget()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    self.NextITWarn = tonumber(self.NextITWarn) or 0
    self.FocusUntil = tonumber(self.FocusUntil) or 0
    if not isvector(self.HomePos) then
        self.HomePos = safe_ground(self:GetPos(), self)
    end
    local currentIT = self:GetCurrentIT()

    if IsValid(currentIT) and currentIT ~= self.LastITVictim then
        self.FocusUntil = CurTime() + (tonumber(cfg.chase_duration) or DEFAULT_CONFIG.chase_duration)
        self.LastITVictim = currentIT
    end

    if IsValid(currentIT) and not self:IsPotentiallyChaseable(currentIT) then
        self:SetCurrentIT(nil)
        currentIT = nil
    end

    -- TF2 parity: if someone is currently IT and still chaseable, always chase them.
    if IsValid(currentIT) then
        self.Target = currentIT
        return currentIT
    end

    local target = currentIT
    if not IsValid(target) then
        local best, bestDist
        for _, ply in ipairs(player.GetAll()) do
            if self:IsPotentiallyChaseable(ply) and self.HomePos:Distance(ply:GetPos()) <= (tonumber(cfg.chase_range) or DEFAULT_CONFIG.chase_range) then
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

        target = best
        if IsValid(target) then
            self:SetCurrentIT(target)
            self.FocusUntil = CurTime() + (tonumber(cfg.chase_duration) or DEFAULT_CONFIG.chase_duration)
            self.LastITVictim = target
        end
    else
        if CurTime() >= (self.NextITWarn or 0) then
            self.NextITWarn = CurTime() + (tonumber(cfg.it_warn_interval) or DEFAULT_CONFIG.it_warn_interval)
            if target.PrintMessage then
                target:PrintMessage(HUD_PRINTCENTER, "#TF_HALLOWEEN_BOSS_WARN_VICTIM")
            end
        end
    end

    self.Target = target
    return target
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
    elseif self.loco and self.loco.Approach then
        -- Fallback when nav/path compute fails: keep walking toward IT directly.
        self.loco:Approach(self.PathTarget, 1)
    end
end

function ENT:ApplyTerrify()
    if self.ScareApplied then return end
    self.ScareApplied = true
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    local radius = tonumber(cfg.terrify_radius) or DEFAULT_CONFIG.terrify_radius
    local duration = tonumber(cfg.terrify_duration) or DEFAULT_CONFIG.terrify_duration

    for _, ply in ipairs(player.GetAll()) do
        if is_valid_target(ply) and self:IsRangeLessThan(ply, radius) and self:IsLineOfSightClear(ply) then
            self:ApplySpookStun(ply, duration)
        end
    end
end

function ENT:DoMeleeAttack(target)
    if not self:IsPotentiallyChaseable(target) then return false end
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    local attackRange = tonumber(cfg.attack_range) or DEFAULT_CONFIG.attack_range
    local toVictim = target:WorldSpaceCenter() - self:WorldSpaceCenter()
    if toVictim:Length() > attackRange then return false end
    toVictim:Normalize()
    if self:GetForward():Dot(toVictim) < 0.15 then return false end
    if not self:IsLineOfSightClear(target) then return false end

    local baseDamage = tonumber(cfg.attack_damage) or DEFAULT_CONFIG.attack_damage
    local fracDamage = tonumber(cfg.attack_damage_health_fraction) or DEFAULT_CONFIG.attack_damage_health_fraction
    local targetMax = isfunction(target.GetMaxHealth) and target:GetMaxHealth() or target:Health()
    local damage = math.max(baseDamage, math.floor(targetMax * fracDamage))

    local info = DamageInfo()
    info:SetAttacker(self)
    info:SetInflictor(self)
    info:SetDamage(damage)
    info:SetDamageType(bit.bor(DMG_CLUB, DMG_SLASH))
    info:SetDamageForce(toVictim * 12000 + Vector(0, 0, 8000))
    target:TakeDamageInfo(info)
    target:SetVelocity(toVictim * 300 + Vector(0, 0, 250))

    self:EmitSound("Halloween.HeadlessBossAxeHitFlesh", 95, 100)
    return true
end

function ENT:BeginMeleeSwing(target)
    if self.AttackSwinging then return end
    local cfg = self.DynamicConfig or DEFAULT_CONFIG

    local played = add_gesture_safe(self, ACT_MP_ATTACK_STAND_ITEM1)
    if not played then
        play_sequence_safe(self, { "attackstand_item1", "attackstand_melee", "attack", "swing", "idle" })
    end
    self.AttackSwinging = true
    self.AttackTarget = target
    self.AttackHitAt = CurTime() + (tonumber(cfg.attack_hit_delay) or DEFAULT_CONFIG.attack_hit_delay)
    self.NextAttack = CurTime() + (tonumber(cfg.attack_cooldown) or DEFAULT_CONFIG.attack_cooldown)
    self:EmitSound("Halloween.HeadlessBossAttack", 95, 100)
end

function ENT:UpdateMeleeSwing(now)
    if not self.AttackSwinging then return end
    if now < self.AttackHitAt then return end

    self.AttackSwinging = false
    local target = self.AttackTarget
    self.AttackTarget = nil

    if IsValid(target) then
        self:DoMeleeAttack(target)
    end

    self:EmitSound("Halloween.HeadlessBossAxeHitWorld", 95, 100)
    if DispatchParticleEffect then
        local effectPos = self:GetPos()
        local effectAng = self:GetAngles()
        if IsValid(self.Axe) and self.Axe.GetAttachment then
            local attachment = self.Axe:LookupAttachment("axe_blade")
            if attachment and attachment > 0 then
                local data = self.Axe:GetAttachment(attachment)
                if data and data.Pos then
                    effectPos = data.Pos
                    effectAng = data.Ang or effectAng
                end
            end
        end
        DispatchParticleEffect("halloween_boss_axe_hit_world", effectPos, effectAng)
    end
    util.ScreenShake(self:GetPos(), 15, 5, 1, 1000)
end

function ENT:OnInjured(dmginfo)
    self:EmitSound("Halloween.HeadlessBossPain", 95, 100)
    if DispatchParticleEffect then
        DispatchParticleEffect("halloween_boss_injured", dmginfo:GetDamagePosition(), self:GetAngles())
    end
end

function ENT:OnKilled(dmginfo)
    self:SetCurrentIT(nil)
    hook.Call("OnNPCKilled", GAMEMODE, self, IsValid(dmginfo) and dmginfo:GetAttacker() or NULL, IsValid(dmginfo) and dmginfo:GetInflictor() or NULL)
    self:EmitSound("Halloween.HeadlessBossDying", 100, 100)
    self:EmitSound("Halloween.HeadlessBossDeath", 100, 100)
    if DispatchParticleEffect then
        DispatchParticleEffect("halloween_boss_death", self:GetPos(), self:GetAngles())
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

    if self.StateName == "emerge" then
        local total = math.max(0.01, tonumber(cfg.emerge_time) or DEFAULT_CONFIG.emerge_time)
        local frac = math.Clamp(1 - ((self.StateUntil - now) / total), 0, 1)
        self:SetPos(self.HomePos - Vector(0, 0, self.EmergeHeight * (1 - frac)))
        if now >= self.NextRumble then
            self.NextRumble = now + 0.25
            util.ScreenShake(self.HomePos, 15, 5, 1, 1000)
        end
        if now >= self.StateUntil then
            self:SetPos(self.HomePos)
            self:SetBossState("attack", 0)
        end
    elseif self.StateName == "terrify" then
        if self.BooAt and not self.BooPlayed and now >= self.BooAt then
            self.BooPlayed = true
            self:EmitSound("Halloween.HeadlessBossBoo", 100, 100)
        end
        if self.ScareAt and now >= self.ScareAt then
            self:ApplyTerrify()
        end
        if now >= self.StateUntil then
            self.ScareApplied = false
            self:SetBossState("attack", 0)
        end
    else
        local target = self:PickTarget()
        self:UpdateAnimationState()
        if now >= self.NextScare then
            self.NextScare = now + (tonumber(cfg.terrify_interval) or DEFAULT_CONFIG.terrify_interval)
            self.BooAt = now + 0.25
            self.ScareAt = now + 0.75
            self.BooPlayed = false
            self.ScareApplied = false
            self:SetBossState("terrify", 1.25)
        elseif IsValid(target) then
            self.loco:SetDesiredSpeed(tonumber(cfg.speed) or DEFAULT_CONFIG.speed)
            self.loco:FaceTowards(target:GetPos())
            if now >= self.NextFootstep and self:GetVelocity():Length2D() > 20 then
                self.NextFootstep = now + 0.4
                self:EmitSound("Halloween.HeadlessBossFootfalls", 90, 100)
                if DispatchParticleEffect then
                    DispatchParticleEffect("halloween_boss_foot_impact", self:GetPos(), self:GetAngles())
                end
            end
            local standRange = tonumber(cfg.stand_and_swing_range) or DEFAULT_CONFIG.stand_and_swing_range
            if self:IsRangeLessThan(target, standRange) and self:IsLineOfSightClear(target) then
                if now >= self.NextAttack and not self.AttackSwinging then
                    self:BeginMeleeSwing(target)
                end
            else
                self:UpdatePath(target:GetPos())
            end
        else
            self.loco:SetDesiredSpeed(tonumber(cfg.speed) or DEFAULT_CONFIG.speed)
            self:UpdatePath(self.HomePos)
        end
    end

    self:UpdateMeleeSwing(now)

    if istable(self.DynamicScript) and isfunction(self.DynamicScript.OnThink) then
        pcall(self.DynamicScript.OnThink, self, self.DynamicConfig)
    end

    self:NextThink(CurTime())
    return true
end

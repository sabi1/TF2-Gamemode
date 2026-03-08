AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local DEFAULT_CONFIG = {
    speed = 250,
    hover_height = 200,
    acceleration = 500,
    horiz_damping = 2,
    vert_damping = 1,
    attack_range = 750,
    health_base = 8000,
    health_per_player = 400,
    min_players = 10,
    emerge_time = 1.4,
    notice_time = 0.25,
    stun_time = 5.0,
    stun_burst_window = 2.0,
    stun_burst_damage = 500,
    teleport_interval_min = 10.0,
    teleport_interval_max = 15.0,
    volley_count = 1,
    volley_interval = 0.3,
    volley_initial_delay = 0.5,
    strafe_distance = 100,
    chase_give_up_time = 5.0,
    min_chase_time = 0.5,
    lose_linger_time = 1.0,
    max_teleport_height = 300,
    teleport_arrive_height = 75,
    rocket_damage = 50,
    calm_rocket_speed_factor = 0.3,
    projectile_class = "tf_projectile_rocket",
    projectile_speed = 1100,
}

local BASE_GAME_PATH = "gamemodes/tf/gamemode/halloween/eyeball_boss/"
local BASE_DATA_PATH = "tf2gm/halloween/eyeball_boss/"
local MAX_REASONABLE_COORD = 16384

local function deep_copy(tbl)
    local out = {}
    for k, v in pairs(tbl or {}) do
        if istable(v) then
            out[k] = deep_copy(v)
        else
            out[k] = v
        end
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
    local t = util.JSONToTable(raw)
    if not istable(t) then
        ErrorNoHalt(string.format("[eyeball_boss] Invalid JSON in %s (%s)\n", path, realm))
        return nil
    end
    return t
end

local function read_lua_module(path, realm)
    local raw = file.Read(path, realm)
    if not raw or raw == "" then return nil end
    local fn = CompileString(raw, string.format("eyeball_boss_cfg_%s", path), false)
    if type(fn) ~= "function" then
        ErrorNoHalt(string.format("[eyeball_boss] Failed to compile %s (%s)\n", path, realm))
        return nil
    end
    local ok, out = pcall(fn)
    if not ok then
        ErrorNoHalt(string.format("[eyeball_boss] Error running %s: %s\n", path, tostring(out)))
        return nil
    end
    if not istable(out) then return nil end
    return out
end

local function collect_living_humans()
    local total = 0
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
            total = total + 1
        end
    end
    return total
end

local function is_reasonable_vector(vec)
    if not isvector(vec) then return false end
    return math.abs(vec.x) <= MAX_REASONABLE_COORD
        and math.abs(vec.y) <= MAX_REASONABLE_COORD
        and math.abs(vec.z) <= MAX_REASONABLE_COORD
end

local function find_safe_ground(pos)
    if not is_reasonable_vector(pos) then return nil end

    local tr = util.TraceHull({
        start = pos + Vector(0, 0, 256),
        endpos = pos - Vector(0, 0, 2048),
        mins = Vector(-32, -32, -32),
        maxs = Vector(32, 32, 32),
        mask = MASK_NPCSOLID_BRUSHONLY,
    })

    if tr.Hit then
        return tr.HitPos
    end

    return pos
end

local function get_trace_bounds(ent)
    local mins = Vector(-48, -48, -48)
    local maxs = Vector(48, 48, 48)

    if IsValid(ent) then
        if ent.OBBMins and ent.OBBMaxs then
            local okMins, obbMins = pcall(ent.OBBMins, ent)
            local okMaxs, obbMaxs = pcall(ent.OBBMaxs, ent)
            if okMins and okMaxs and isvector(obbMins) and isvector(obbMaxs) then
                mins = obbMins
                maxs = obbMaxs
            end
        end
    end

    return mins, maxs
end

local function get_ground_below(ent, pos)
    local mins, maxs = get_trace_bounds(ent)
    local tr = util.TraceHull({
        start = pos + Vector(0, 0, 1000),
        endpos = pos - Vector(0, 0, 2000),
        mins = mins,
        maxs = maxs,
        mask = MASK_NPCSOLID_BRUSHONLY,
        filter = function(hit)
            return hit ~= ent and hit:GetClass() ~= "eyeball_boss"
        end
    })

    if tr.Hit then
        return tr.HitPos
    end

    return nil
end

local function play_sequence_safe(ent, names)
    for _, name in ipairs(names) do
        local seq = ent:LookupSequence(name)
        if seq and seq > 0 then
            if ent._tfDesiredSequence == seq then
                return true
            end
            ent:SetSequence(seq)
            ent:SetPlaybackRate(1)
            ent:SetCycle(0)
            if ent.ResetSequenceInfo then
                ent:ResetSequenceInfo()
            end
            ent._tfDesiredSequence = seq
            return true
        end
    end
    return false
end

function ENT:LoadDynamicConfig()
    local map = string.lower(game.GetMap() or "")
    local cfg = deep_copy(DEFAULT_CONFIG)

    -- Static config shipped with the gamemode.
    merge_into(cfg, read_json(BASE_GAME_PATH .. "default.json", "GAME"))
    merge_into(cfg, read_json(BASE_GAME_PATH .. "maps/" .. map .. ".json", "GAME"))

    -- Runtime overrides from DATA, matching "dynamic script/file" behavior.
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
    local bonusPer = tonumber(cfg.health_per_player) or DEFAULT_CONFIG.health_per_player
    local totalPlayers = collect_living_humans()

    if totalPlayers > minPlayers then
        hp = hp + (totalPlayers - minPlayers) * bonusPer
    end

    return math.max(1, math.floor(hp))
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
    if self.StateName == "emerge" then
        play_sequence_safe(self, { "arrives", "teleport_in", "spawn", "idle" })
        return
    end
    if self.StateName == "teleport" then
        play_sequence_safe(self, { "teleport_out", "teleport", "idle" })
        return
    end
    if self.StateName == "launch" then
        play_sequence_safe(self, { "attack", "shoot", "idle" })
        return
    end
    if self.StateName == "stunned" then
        play_sequence_safe(self, { "stunned", "idle" })
        return
    end
    play_sequence_safe(self, { "idle", "fly", "hover", "lookaround" })
end

function ENT:PickTarget()
    local best, bestDist
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsPlayer() and ply:Alive() and not ply:IsFlagSet(FL_NOTARGET) then
            local d = self:GetRangeTo(ply:GetPos())
            if not best or d < bestDist then
                best = ply
                bestDist = d
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
    return best
end

function ENT:PickTeleportPosition()
    local origin = self:GetPos()

    local custom = ents.FindByClass("spawn_boss")[1]
    if IsValid(custom) then
        origin = custom:GetPos()
    elseif IsValid(self.Target) then
        origin = self.Target:GetPos() + Vector(math.Rand(-700, 700), math.Rand(-700, 700), 0)
    else
        origin = self:GetPos() + Vector(math.Rand(-500, 500), math.Rand(-500, 500), 0)
    end

    if istable(self.DynamicScript) and isfunction(self.DynamicScript.SelectTeleportPos) then
        local ok, override = pcall(self.DynamicScript.SelectTeleportPos, self, origin)
        if ok and isvector(override) then
            origin = override
        end
    end

    local ground = find_safe_ground(origin)
    if not ground then
        ground = self.LastSafePos or self:GetPos()
    end

    return ground + Vector(0, 0, 24)
end

function ENT:SpawnBossProjectile(targetPos)
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    local className = tostring(cfg.projectile_class or DEFAULT_CONFIG.projectile_class)
    local proj = ents.Create(className)
    if not IsValid(proj) then return end

    local from = self:WorldSpaceCenter()
    local dir = (targetPos - from)
    if dir:LengthSqr() <= 1 then
        dir = self:GetForward()
    else
        dir:Normalize()
    end

    proj:SetPos(from + dir * 50)
    proj:SetAngles(dir:Angle())
    proj:SetOwner(self)
    proj.BaseSpeed = tonumber(cfg.projectile_speed) or DEFAULT_CONFIG.projectile_speed
    proj.BaseDamage = tonumber(cfg.rocket_damage) or DEFAULT_CONFIG.rocket_damage
    proj:Spawn()
    proj:Activate()
end

function ENT:Initialize()
    self:LoadDynamicConfig()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG

    self:SetModel(self.Model)
    self:AddFlags(FL_OBJECT)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    self:SetCollisionBounds(Vector(-48, -48, -48), Vector(48, 48, 48))
    self:SetMoveType(MOVETYPE_NOCLIP)
    self:SetHealth(self:ComputeScaledHealth())
    if self.SetMaxHealth then
        self:SetMaxHealth(self:Health())
    end
    if self.SetBloodColor then
        self:SetBloodColor(DONT_BLEED)
    end
    self:SetNWInt("Team", TEAM_NEUTRAL)

    self.Velocity = Vector(0, 0, 0)
    self.Acceleration = Vector(0, 0, 0)
    self.DesiredAltitude = tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height
    self.LastSafePos = self:GetPos()
    self.StateName = "emerge"
    self.StateUntil = CurTime()
    self.NextAcquire = 0
    self.NextTeleport = 0
    self.NextAttack = 0
    self.RemainingVolley = 0
    self.StunBurst = 0
    self.StunBurstReset = CurTime()
    self.ChaseGiveUpAt = 0
    self.MinChaseUntil = 0
    self.LingerUntil = 0
    self.LastVictim = nil
    self.NextRumble = 0
    self.EmergeAnchor = self:GetPos()
    self.EmergeHeight = 200

    local spawnGround = find_safe_ground(self:GetPos())
    if spawnGround then
        self.EmergeAnchor = spawnGround
        local spawnHeight = tonumber(cfg.teleport_arrive_height) or DEFAULT_CONFIG.teleport_arrive_height
        local safeSpawn = spawnGround + Vector(0, 0, spawnHeight)
        if is_reasonable_vector(safeSpawn) then
            self.EmergeAnchor = safeSpawn
        end
    end
    self.EmergeHeight = math.max(self.EmergeHeight, tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height)
    self:SetPos(self.EmergeAnchor - Vector(0, 0, self.EmergeHeight))

    self:SetBossState("emerge", tonumber(cfg.emerge_time) or DEFAULT_CONFIG.emerge_time)
    self.NextTeleport = CurTime() + math.Rand(
        tonumber(cfg.teleport_interval_min) or DEFAULT_CONFIG.teleport_interval_min,
        tonumber(cfg.teleport_interval_max) or DEFAULT_CONFIG.teleport_interval_max
    )

    self:EmitSound("Halloween.MonoculusBossSpawn", 100, 100)
    if DispatchParticleEffect then
        DispatchParticleEffect("eyeboss_tp_normal", self.EmergeAnchor, self:GetAngles())
    end

    if istable(self.DynamicScript) and isfunction(self.DynamicScript.OnSpawn) then
        pcall(self.DynamicScript.OnSpawn, self, self.DynamicConfig)
    end
    self:UpdateAnimationState()
end

function ENT:RunBehaviour()
    while true do
        coroutine.yield()
    end
end

function ENT:Team()
    return TEAM_NEUTRAL
end

function ENT:GetTeamNumber()
    return TEAM_NEUTRAL
end

function ENT:SetDesiredAltitude(z)
    self.DesiredAltitude = tonumber(z) or self.DesiredAltitude or DEFAULT_CONFIG.hover_height
end

function ENT:MaintainAltitude(cfg, dt)
    local ground = get_ground_below(self, self:GetPos() + Vector(self.Velocity.x, self.Velocity.y, 0) * dt * 0.2)
    if not ground then return end

    local currentAltitude = self:GetPos().z - ground.z
    local desiredAltitude = self.DesiredAltitude or tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height
    local error = math.Clamp(desiredAltitude - currentAltitude, -tonumber(cfg.acceleration) or -DEFAULT_CONFIG.acceleration, tonumber(cfg.acceleration) or DEFAULT_CONFIG.acceleration)
    self.Acceleration.z = self.Acceleration.z + error
end

function ENT:ApproachXY(goalPos, cfg)
    local flyGoal = Vector(goalPos.x, goalPos.y, self:GetPos().z)
    local toGoal = flyGoal - self:GetPos()
    toGoal.z = 0
    if toGoal:LengthSqr() <= 1 then return end
    toGoal:Normalize()
    local accel = tonumber(cfg.acceleration) or DEFAULT_CONFIG.acceleration
    self.Acceleration = self.Acceleration + accel * toGoal
end

function ENT:OnInjured(dmginfo)
    if not dmginfo then return end

    local now = CurTime()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    local window = tonumber(cfg.stun_burst_window) or DEFAULT_CONFIG.stun_burst_window
    local burst = tonumber(cfg.stun_burst_damage) or DEFAULT_CONFIG.stun_burst_damage

    if now > self.StunBurstReset then
        self.StunBurst = 0
        self.StunBurstReset = now + math.max(0.1, window)
    end

    self.StunBurst = self.StunBurst + math.max(0, dmginfo:GetDamage())
    if self.StateName ~= "stunned" and self.StunBurst >= burst then
        self.StunBurst = 0
        hook.Run("TF_HalloweenBossStunned", self, IsValid(dmginfo:GetAttacker()) and dmginfo:GetAttacker() or NULL)
        self:SetDesiredAltitude(0)
        self:SetBossState("stunned", tonumber(cfg.stun_time) or DEFAULT_CONFIG.stun_time)
    end
end

function ENT:OnKilled(dmginfo)
    hook.Call("OnNPCKilled", GAMEMODE, self, IsValid(dmginfo) and dmginfo:GetAttacker() or NULL, IsValid(dmginfo) and dmginfo:GetInflictor() or NULL)
    self:EmitSound("Halloween.MonoculusBossDeath", 95, 100)
    self:Remove()
end

function ENT:Think()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    local now = CurTime()

    if self:Health() <= 0 then
        self:Remove()
        return
    end

    if now >= (self.NextAcquire or 0) then
        self:PickTarget()
        self.NextAcquire = now + 0.25
    end

    local target = IsValid(self.Target) and self.Target or nil
    if self.StateName == "emerge" then
        self:SetDesiredAltitude(tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height)
        local total = math.max(0.01, tonumber(cfg.emerge_time) or DEFAULT_CONFIG.emerge_time)
        local frac = math.Clamp(1 - ((self.StateUntil - now) / total), 0, 1)
        local emergePos = self.EmergeAnchor - Vector(0, 0, self.EmergeHeight * (1 - frac))
        if is_reasonable_vector(emergePos) then
            self:SetPos(emergePos)
            self.LastSafePos = emergePos
        end

        if now >= (self.NextRumble or 0) then
            self.NextRumble = now + 0.25
            util.ScreenShake(self.EmergeAnchor, 15, 5, 1, 1000)
        end

        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
                local toPlayer = ply:EyePosition() - self.EmergeAnchor
                local range = toPlayer:Length()
                if range < 250 and range > 0 then
                    toPlayer.z = 0
                    toPlayer:Normalize()
                    toPlayer.z = 1
                    ply:SetVelocity(toPlayer * 200)
                end
            end
        end

        if now >= self.StateUntil then
            self:SetPos(self.EmergeAnchor)
            self.LastSafePos = self.EmergeAnchor
            if DispatchParticleEffect then
                DispatchParticleEffect("eyeboss_tp_normal", self.EmergeAnchor, self:GetAngles())
            end
            self:SetBossState("idle", 0)
        end
    elseif self.StateName == "idle" then
        self:SetDesiredAltitude(tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height)
        if target then
            self.LastVictim = target
            self:SetBossState("notice", tonumber(cfg.notice_time) or DEFAULT_CONFIG.notice_time)
        elseif now >= (self.NextTeleport or 0) then
            self.SetDesiredAltitude(self, 0)
            local ground = get_ground_below(self, self:WorldSpaceCenter())
            if ground and (self:WorldSpaceCenter().z - ground.z) < (tonumber(cfg.max_teleport_height) or DEFAULT_CONFIG.max_teleport_height) then
                self:SetBossState("teleport", 0)
            end
        end
    elseif self.StateName == "notice" then
        self:SetDesiredAltitude(tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height)
        if now >= self.StateUntil then
            self.ChaseGiveUpAt = now + (tonumber(cfg.chase_give_up_time) or DEFAULT_CONFIG.chase_give_up_time)
            self.MinChaseUntil = now + (tonumber(cfg.min_chase_time) or DEFAULT_CONFIG.min_chase_time)
            self.LingerUntil = 0
            self:SetBossState("approach", 0)
        end
    elseif self.StateName == "approach" then
        self:SetDesiredAltitude(tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height)
        if not target then
            self:SetBossState("idle", 0)
        elseif IsValid(self.LastVictim) and target ~= self.LastVictim and now >= (self.MinChaseUntil or 0) then
            self:SetBossState("idle", 0)
        elseif now >= (self.ChaseGiveUpAt or 0) then
            self:SetBossState("idle", 0)
        else
            local tr = util.TraceLine({
                start = self:WorldSpaceCenter(),
                endpos = target:WorldSpaceCenter(),
                filter = { self, target },
                mask = MASK_SOLID_BRUSHONLY,
            })
            if tr.Hit then
                if self.LingerUntil == 0 then
                    self.LingerUntil = now + (tonumber(cfg.lose_linger_time) or DEFAULT_CONFIG.lose_linger_time)
                elseif now >= self.LingerUntil then
                    self:SetBossState("idle", 0)
                end
            else
                self.LingerUntil = now + (tonumber(cfg.lose_linger_time) or DEFAULT_CONFIG.lose_linger_time)
                if self:GetRangeTo(target:GetPos()) <= (tonumber(cfg.attack_range) or DEFAULT_CONFIG.attack_range) then
                    self.RemainingVolley = math.max(1, math.floor(tonumber(cfg.volley_count) or DEFAULT_CONFIG.volley_count))
                    self.NextAttack = now + (tonumber(cfg.volley_initial_delay) or DEFAULT_CONFIG.volley_initial_delay)
                    self:SetBossState("launch", 0)
                else
                    self:ApproachXY(target:WorldSpaceCenter(), cfg)
                end
            end
        end
    elseif self.StateName == "launch" then
        self:SetDesiredAltitude(tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height)
        if not target then
            self:SetBossState("idle", 0)
        else
            local right = self:GetRight()
            local strafe = tonumber(cfg.strafe_distance) or DEFAULT_CONFIG.strafe_distance
            if target:EntIndex() % 2 == 1 then
                self:ApproachXY(self:WorldSpaceCenter() + right * strafe, cfg)
            else
                self:ApproachXY(self:WorldSpaceCenter() - right * strafe, cfg)
            end

            if now >= (self.NextAttack or 0) then
                self:SpawnBossProjectile(target:WorldSpaceCenter())
                self.RemainingVolley = math.max(0, (self.RemainingVolley or 0) - 1)
                self.NextAttack = now + math.max(0.05, tonumber(cfg.volley_interval) or DEFAULT_CONFIG.volley_interval)
                if self.RemainingVolley <= 0 then
                    self:SetBossState("idle", 0)
                end
            end
        end
    elseif self.StateName == "teleport" then
        self:EmitSound("Halloween.MonoculusBossTeleport", 95, 100)
        local tpPos = self:PickTeleportPosition()
        if is_reasonable_vector(tpPos) then
            local arriveHeight = tonumber(cfg.teleport_arrive_height) or DEFAULT_CONFIG.teleport_arrive_height
            local finalPos = tpPos + Vector(0, 0, arriveHeight)
            if DispatchParticleEffect then
                DispatchParticleEffect("eyeboss_tp_normal", self:GetPos(), self:GetAngles())
            end
            self:SetPos(finalPos)
            self.LastSafePos = finalPos
            self.EmergeAnchor = finalPos
            if DispatchParticleEffect then
                DispatchParticleEffect("eyeboss_tp_normal", finalPos, self:GetAngles())
            end
        end
        self.Velocity = Vector(0, 0, 0)
        self.Acceleration = Vector(0, 0, 0)
        self:SetDesiredAltitude(tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height)
        self.NextTeleport = now + math.Rand(
            tonumber(cfg.teleport_interval_min) or DEFAULT_CONFIG.teleport_interval_min,
            tonumber(cfg.teleport_interval_max) or DEFAULT_CONFIG.teleport_interval_max
        )
        self:SetBossState("idle", 0)
    elseif self.StateName == "stunned" then
        self:SetDesiredAltitude(0)
        if now >= self.StateUntil then
            self:SetDesiredAltitude(tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height)
            self:SetBossState("idle", 0)
        end
    end

    local dt = FrameTime()
    local accel = tonumber(cfg.acceleration) or DEFAULT_CONFIG.acceleration
    local maxSpeed = tonumber(cfg.speed) or DEFAULT_CONFIG.speed
    local dampH = tonumber(cfg.horiz_damping) or DEFAULT_CONFIG.horiz_damping
    local dampV = tonumber(cfg.vert_damping) or DEFAULT_CONFIG.vert_damping

    self:MaintainAltitude(cfg, dt)

    local totalAccel = Vector(
        self.Acceleration.x - self.Velocity.x * dampH,
        self.Acceleration.y - self.Velocity.y * dampH,
        self.Acceleration.z - self.Velocity.z * dampV
    )
    self.Velocity = self.Velocity + totalAccel * dt

    local xy = Vector(self.Velocity.x, self.Velocity.y, 0)
    local xyLen = xy:Length()
    if xyLen > maxSpeed then
        xy = xy:GetNormalized() * maxSpeed
        self.Velocity.x = xy.x
        self.Velocity.y = xy.y
    end

    if self.StateName == "stunned" then
        self.Velocity = self.Velocity * 0.25
    end

    local nextPos = self:GetPos() + self.Velocity * dt
    if not is_reasonable_vector(nextPos) then
        nextPos = self.LastSafePos or self:GetPos()
        self.Velocity = Vector(0, 0, 0)
    else
        self.LastSafePos = nextPos
    end

    self:SetPos(nextPos)
    self:SetGroundEntity(NULL)
    self.Acceleration = Vector(0, 0, 0)

    if target then
        local look = (target:WorldSpaceCenter() - self:WorldSpaceCenter()):Angle()
        self:SetAngles(Angle(0, look.y, 0))
    end

    if istable(self.DynamicScript) and isfunction(self.DynamicScript.OnThink) then
        pcall(self.DynamicScript.OnThink, self, self.DynamicConfig, self.StateName, target)
    end

    self:NextThink(now)
    return true
end

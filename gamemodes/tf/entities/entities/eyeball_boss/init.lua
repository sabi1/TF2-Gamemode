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
    teleport_arrive_height = 200,
    rocket_damage = 50,
    calm_rocket_speed_factor = 0.3,
    projectile_class = "tf_projectile_rocket",
    projectile_speed = 1100,
    aggro_lock_time = 6.0,
    escape_portal_interval_min = 20.0,
    escape_portal_interval_max = 35.0,
    escape_portal_lifetime = 15.0,
    vertical_acceleration = 900,
    max_vertical_speed = 260,
    altitude_lookahead = 0.3,
}

local BASE_GAME_PATH = "gamemodes/tf/gamemode/halloween/eyeball_boss/"
local BASE_DATA_PATH = "tf2gm/halloween/eyeball_boss/"
local MAX_REASONABLE_COORD = 16384
local EYEBALL_PARTICLE_DEBUG_CVAR = "tf_halloween_eyeball_particle_debug"
local VIADUCT_HELL_EXIT_POS = Vector(1738.189087, -3142.666016, -11305.007812)
local VIADUCT_DEATH_VORTEX_EXIT_POS = Vector(2969.978516, 2119.812500, -11531.245117)
local VIADUCT_MONOCULUS_MAX_Z = 969.228638
local DEATH_VORTEX_LIFETIME = 15.0
local ENABLE_DEATH_VORTEX = true

local EYEBALL_CALM = 0
local EYEBALL_GRUMPY = 1
local EYEBALL_ANGRY = 2
local EYEBALL_STUNNED = 3
local EYEBALL_PROJECTILE_MODEL = "models/props_halloween/eyeball_projectile.mdl"
local TF2_EYEBALL_BOSS_SPEED = 250
local EYEBALL_ENRAGE_DAMAGE_RATE = 300 -- TF2 behavior threshold (DPS-ish)

local EYEBALL_PARTICLE_SYSTEMS = {
    "eyeboss_death",
    "eyeboss_aura_angry",
    "eyeboss_aura_grumpy",
    "eyeboss_aura_calm",
    "eyeboss_aura_stunned",
    "eyeboss_tp_normal",
    "eyeboss_tp_escape",
    "eyeboss_tp_vortex",
    "eyeboss_doorway_vortex",
    "eyeboss_vortex_red",
    "eyeboss_vortex_blue",
    "eyeboss_tp_player",
    "eyeboss_death_vortex",
    "eyeboss_team_red",
    "eyeboss_team_blue",
    "halloween_boss_summon",
    "ghost_pumpkin",
}

local EYEBALL_PARTICLE_FILES = {
    "particles/eyeboss.pcf",
    "particles/halloween.pcf",
}

if SERVER and not ConVarExists(EYEBALL_PARTICLE_DEBUG_CVAR) then
    CreateConVar(EYEBALL_PARTICLE_DEBUG_CVAR, "0", FCVAR_ARCHIVE, "Enable Monoculus particle debug logging.")
end

local function eye_particle_debug_enabled()
    local cv = GetConVar(EYEBALL_PARTICLE_DEBUG_CVAR)
    return cv and cv:GetBool() or false
end

local function eye_particle_debug(fmt, ...)
    if not eye_particle_debug_enabled() then return end
    MsgN(string.format("[Eyeball Particle Debug] " .. tostring(fmt), ...))
end

local function add_particle_file_safe(path)
    if not game or not game.AddParticles then return false end
    if not isstring(path) or path == "" then return false end

    if file.Exists(path, "GAME") then
        local ok, err = pcall(game.AddParticles, path)
        if not ok then
            eye_particle_debug("game.AddParticles failed for '%s': %s", path, tostring(err))
            return false
        end
        return true
    end

    local fallback = "gamemodes/tf/content/" .. path
    if file.Exists(fallback, "GAME") then
        local ok, err = pcall(game.AddParticles, fallback)
        if not ok then
            eye_particle_debug("game.AddParticles failed for fallback '%s': %s", fallback, tostring(err))
            return false
        end
        return true
    end

    eye_particle_debug("Missing particle file '%s'", path)
    return false
end

local eyeParticleFilesLoaded = false
local function EnsureEyeballParticleFilesLoaded()
    if eyeParticleFilesLoaded then return end
    eyeParticleFilesLoaded = true
    for _, pcf in ipairs(EYEBALL_PARTICLE_FILES) do
        add_particle_file_safe(pcf)
    end
end

local eyeParticlesPrecached = false
local function EnsureEyeballParticlesPrecached()
    if eyeParticlesPrecached then return end
    eyeParticlesPrecached = true
    EnsureEyeballParticleFilesLoaded()
    if not PrecacheParticleSystem then return end
    for _, system in ipairs(EYEBALL_PARTICLE_SYSTEMS) do
        local ok, err = pcall(PrecacheParticleSystem, system)
        if not ok then
            eye_particle_debug("PrecacheParticleSystem failed for '%s': %s", system, tostring(err))
        end
    end
end

local function DispatchEyeballParticle(name, pos, ang, parent)
    if not isstring(name) or name == "" then return false end
    local p = isvector(pos) and pos or vector_origin
    local a = isangle(ang) and ang or angle_zero

    local ok, err
    if DispatchParticleEffect then
        if IsValid(parent) then
            ok, err = pcall(DispatchParticleEffect, name, p, a, parent)
        else
            ok, err = pcall(DispatchParticleEffect, name, p, a)
        end
    elseif ParticleEffect then
        if IsValid(parent) then
            ok, err = pcall(ParticleEffect, name, p, a, parent)
        else
            ok, err = pcall(ParticleEffect, name, p, a)
        end
    else
        eye_particle_debug("No particle dispatch function available for '%s'", name)
        return false
    end

    if not ok then
        eye_particle_debug("Particle dispatch failed for '%s': %s", name, tostring(err))
        return false
    end
    return true
end

local function class_has_prefix(ent, prefix)
    if not IsValid(ent) then return false end
    local cls = string.lower(tostring(ent:GetClass() or ""))
    return string.sub(cls, 1, #prefix) == prefix
end

local function eyeball_modify_incoming_damage(dmginfo)
    if not dmginfo then return end

    local inflictor = dmginfo.GetInflictor and dmginfo:GetInflictor() or nil
    local weapon = dmginfo.GetWeapon and dmginfo:GetWeapon() or nil
    local damage = tonumber(dmginfo:GetDamage() or 0) or 0
    local scale = 1.0

    -- TF2 source (EyeballBossModifyDamage):
    -- sentry / sentry rocket: 0.25x
    -- flamethrower: 0.5x
    -- minigun: 0.25x
    if IsValid(inflictor) then
        local icls = string.lower(tostring(inflictor:GetClass() or ""))
        if icls == "obj_sentrygun" or icls == "tf_obj_sentrygun" or icls == "tf_projectile_sentryrocket" then
            scale = 0.25
        end
    end

    if scale == 1.0 and IsValid(weapon) then
        if class_has_prefix(weapon, "tf_weapon_flamethrower") then
            scale = 0.5
        elseif class_has_prefix(weapon, "tf_weapon_minigun") then
            scale = 0.25
        end
    end

    if scale ~= 1.0 then
        dmginfo:SetDamage(damage * scale)
    end
end

if SERVER then
    hook.Add("EntityTakeDamage", "TF_EyeballBoss_TF2DamageModel", function(target, dmginfo)
        if not IsValid(target) or target:GetClass() ~= "eyeball_boss" then return end
        eyeball_modify_incoming_damage(dmginfo)
    end)
end

local function SpawnTeleportVortex(pos)
    if not isvector(pos) then return nil end
    local vortex = ents.Create("teleport_vortex")
    if IsValid(vortex) then
        vortex:SetPos(pos)
        vortex:SetAngles(angle_zero)
        vortex:Spawn()
        vortex:Activate()
        return vortex
    end
    eye_particle_debug("teleport_vortex class unavailable; using particle-only teleport effect")
    return nil
end

local function count_active_escape_vortexes()
    local c = 0
    for _, ent in ipairs(ents.FindByClass("teleport_vortex")) do
        if IsValid(ent) then
            c = c + 1
        end
    end
    return c
end

local function collect_escape_portal_nodes()
    local out = {}
    for _, ent in ipairs(ents.FindByClass("hightower_teleport_vortex")) do
        if IsValid(ent) then
            local baseName = ""
            if istable(ent.Properties) and isstring(ent.Properties.target_base_name) then
                baseName = string.Trim(string.lower(ent.Properties.target_base_name))
            end
            out[#out + 1] = {
                ent = ent,
                pos = ent:GetPos(),
                base = baseName,
                name = string.lower(tostring(ent.GetName and ent:GetName() or "")),
            }
        end
    end

    if #out > 0 then
        return out
    end

    for _, ent in ipairs(ents.FindByClass("tf_teleport_location")) do
        if IsValid(ent) then
            out[#out + 1] = {
                ent = ent,
                pos = ent:GetPos(),
                base = "",
                name = string.lower(tostring(ent.GetName and ent:GetName() or "")),
            }
        end
    end

    return out
end

local function collect_escape_destination_nodes()
    local out = {}

    local function push(ent, className)
        if not IsValid(ent) then return end
        out[#out + 1] = {
            ent = ent,
            pos = ent:GetPos(),
            class = className or "",
            name = string.lower(tostring(ent.GetName and ent:GetName() or "")),
        }
    end

    for _, ent in ipairs(ents.FindByClass("info_teleport_destination")) do
        push(ent, "info_teleport_destination")
    end

    for _, ent in ipairs(ents.FindByClass("tf_teleport_location")) do
        push(ent, "tf_teleport_location")
    end

    for _, ent in ipairs(ents.FindByClass("info_target")) do
        local name = string.lower(tostring(ent.GetName and ent:GetName() or ""))
        if string.find(name, "teleport", 1, true) or string.find(name, "underworld", 1, true) or string.find(name, "hell", 1, true) then
            push(ent, "info_target")
        end
    end

    return out
end

local is_reasonable_vector

local function is_valid_world_destination(pos, requireInWorld)
    if not isvector(pos) then return false end
    if is_reasonable_vector then
        if not is_reasonable_vector(pos) then
            return false
        end
    elseif math.abs(pos.x) > MAX_REASONABLE_COORD or math.abs(pos.y) > MAX_REASONABLE_COORD or math.abs(pos.z) > MAX_REASONABLE_COORD then
        return false
    end
    if requireInWorld and util and util.IsInWorld then
        if not util.IsInWorld(pos + Vector(0, 0, 24)) then
            return false
        end
    end
    return true
end

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

local function player_is_spawn_protected(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if ply.GetNWBool and ply:GetNWBool("InRespawnRoom", false) then
        return true
    end
    if ply.InCond then
        if isnumber(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED) and ply:InCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED) then
            return true
        end
        if isnumber(TF_COND_INVULNERABLE) and ply:InCond(TF_COND_INVULNERABLE) then
            return true
        end
    end
    return false
end

is_reasonable_vector = function(vec)
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

local function find_safe_world_hover(pos, hoverHeight)
    local hover = tonumber(hoverHeight) or DEFAULT_CONFIG.hover_height
    local base = find_safe_ground(pos) or pos
    if not is_reasonable_vector(base) then return nil end

    local cand = base + Vector(0, 0, hover)
    if util and util.IsInWorld and not util.IsInWorld(cand + Vector(0, 0, 24)) then
        local offsets = {
            Vector(128, 0, 0), Vector(-128, 0, 0), Vector(0, 128, 0), Vector(0, -128, 0),
            Vector(256, 0, 0), Vector(-256, 0, 0), Vector(0, 256, 0), Vector(0, -256, 0),
        }
        for _, off in ipairs(offsets) do
            local g = find_safe_ground(base + off)
            if g then
                local c = g + Vector(0, 0, hover)
                if util.IsInWorld(c + Vector(0, 0, 24)) then
                    return c
                end
            end
        end
        return nil
    end
    return cand
end

local function get_spawn_boss_pos()
    local custom = ents.FindByClass("spawn_boss")[1]
    if IsValid(custom) then
        return custom:GetPos()
    end
    return nil
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
    local prev = self.StateName
    self.StateName = name
    self.StateUntil = CurTime() + math.max(0, tonumber(duration) or 0)
    self:UpdateAnimationState()

    if prev ~= name then
        if name == "notice" then
            self:EmitSound("Halloween.EyeballBossBecomeAlert", 95, 100)
            self:EmitSound("Halloween.EyeballBossAcquiredVictim", 95, 100)
        elseif name == "launch" and self:IsEnraged() then
            self:EmitSound("Halloween.EyeballBossRage", 95, 100)
        elseif name == "stunned" then
            self:EmitSound("Halloween.EyeballBossStunned", 95, 100)
        end
    end

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
        play_sequence_safe(self, istable(self.LaunchAnimNames) and self.LaunchAnimNames or { "firing1", "attack", "shoot", "idle" })
        return
    end
    if self.StateName == "stunned" then
        play_sequence_safe(self, { "stunned", "idle" })
        return
    end
    if self.StateName == "escape" then
        play_sequence_safe(self, { "escape", "teleport_out", "idle" })
        return
    end
    -- Monoculus uses lookaround1/2/3 style idle sequences in TF2.
    play_sequence_safe(self, { "idle", "fly", "hover", "lookaround", "lookaround1", "lookaround2", "lookaround3" })
end

function ENT:GetVolleyProfile()
    local attitude = EYEBALL_CALM
    if self:IsEnraged() then
        attitude = EYEBALL_ANGRY
    elseif self.StateName == "notice" or self.StateName == "approach" or self.StateName == "launch" then
        attitude = EYEBALL_GRUMPY
    end
    local calmSpeedFactor = tonumber((self.DynamicConfig or DEFAULT_CONFIG).calm_rocket_speed_factor) or DEFAULT_CONFIG.calm_rocket_speed_factor

    if attitude == EYEBALL_ANGRY then
        return 3, 0.25, { "firing3", "firing2", "attack", "shoot", "idle" }, 1.0
    end

    if attitude == EYEBALL_GRUMPY then
        return 3, 0.25, { "firing2", "firing3", "attack", "shoot", "idle" }, calmSpeedFactor
    end

    return 1, 0.5, { "firing1", "attack", "shoot", "idle" }, calmSpeedFactor
end

function ENT:ApplyAttitudeVisuals(attitude, target)
    self:SetNWInt("EyeballAttitude", attitude)
    if self.SetSkin then
        -- Match expected behavior: angry monoculus uses alternate skin.
        self:SetSkin(attitude == EYEBALL_ANGRY and 1 or 0)
    end

    local lookTarget
    if IsValid(target) then
        if target.EyePos then
            lookTarget = target:EyePos()
        elseif target.EyePosition then
            lookTarget = target:EyePosition()
        else
            lookTarget = target.WorldSpaceCenter and target:WorldSpaceCenter() or target:GetPos()
        end
    else
        local yawOnly = Angle(0, self:GetAngles().y, 0)
        lookTarget = self:WorldSpaceCenter() + yawOnly:Forward() * 300
    end
    self:SetNWVector("EyeballLookAtSpot", lookTarget)
end

function ENT:PickTarget()
    local now = CurTime()
    if IsValid(self.AggroTarget) and self.AggroUntil and now < self.AggroUntil and self.AggroTarget:Alive() then
        self.Target = self.AggroTarget
        return self.Target
    end

    local best, bestDist
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsPlayer() and ply:Alive() and not ply:IsFlagSet(FL_NOTARGET) and not player_is_spawn_protected(ply) then
            local d = self:GetRangeTo(ply:WorldSpaceCenter())
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
    if IsValid(best) then
        self.AggroTarget = best
        self.AggroUntil = now + math.max(1.0, tonumber((self.DynamicConfig or DEFAULT_CONFIG).aggro_lock_time) or DEFAULT_CONFIG.aggro_lock_time)
        self:SetNWBool("EyeballAggro", true)
    else
        self:SetNWBool("EyeballAggro", false)
    end
    return best
end

function ENT:IsEnraged()
    return (self.EnragedUntil or 0) > CurTime()
end

function ENT:BecomeEnraged(duration, attacker)
    local now = CurTime()
    local wasEnraged = self:IsEnraged()
    self.EnragedUntil = math.max(self.EnragedUntil or 0, now + math.max(0.1, tonumber(duration) or 5))
    if not wasEnraged then
        self:EmitSound("Halloween.EyeballBossBecomeEnraged", 95, 100)
    end
    if IsValid(attacker) and attacker:IsPlayer() and attacker:Alive() then
        self.AggroTarget = attacker
        self.AggroUntil = now + math.max(1.0, tonumber((self.DynamicConfig or DEFAULT_CONFIG).aggro_lock_time) or DEFAULT_CONFIG.aggro_lock_time)
        self.Target = attacker
        self:SetNWBool("EyeballAggro", true)
    end
end

function ENT:RequestEscapeDespawn()
    if self.TF_HalloweenDespawnRequested then return true end
    self.TF_HalloweenDespawnRequested = true
    self:ClearEscapePortals()
    self:EmitSound("Halloween.EyeballBossLaugh", 95, 100)
    self:SetBossState("escape", 0)
    local seqDur = (self.SequenceDuration and self:SequenceDuration()) or 0
    self.EscapeDespawnAt = CurTime() + math.max(1.5, tonumber(seqDur) or 0)
    self.EscapeEffectPlayed = false
    return true
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

    local out = find_safe_world_hover(origin, 24)
    if out then
        return out
    end

    local fallback = find_safe_world_hover(self.LastSafePos or self.EmergeAnchor or self:GetPos(), 24)
    if fallback then
        return fallback
    end

    -- Absolute last resort: keep current position and let Think's OOB snap logic recover.
    return self:GetPos()
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
    local speedScale = tonumber(self.LaunchSpeedScale) or 1
    proj.BaseSpeed = (tonumber(cfg.projectile_speed) or DEFAULT_CONFIG.projectile_speed) * math.max(0.05, speedScale)
    proj.BaseDamage = tonumber(cfg.rocket_damage) or DEFAULT_CONFIG.rocket_damage
    proj:Spawn()
    proj:Activate()

    if proj.SetModel then
        pcall(proj.SetModel, proj, EYEBALL_PROJECTILE_MODEL)
    end
end

function ENT:Initialize()
    EnsureEyeballParticlesPrecached()
    self:LoadDynamicConfig()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG

    self:SetModel(self.Model)
    self:AddFlags(FL_OBJECT)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    self:SetCollisionBounds(Vector(-48, -48, -48), Vector(48, 48, 48))
    self:SetMoveType(MOVETYPE_NOCLIP)
    if self.SetGravity then
        self:SetGravity(0)
    end
    if self.loco and self.loco.SetGravity then
        self.loco:SetGravity(0)
    end
    self:SetHealth(self:ComputeScaledHealth())
    if self.SetMaxHealth then
        self:SetMaxHealth(self:Health())
    end
    if self.SetBloodColor then
        self:SetBloodColor(DONT_BLEED)
    end
    self:SetNWInt("Team", TEAM_NEUTRAL)
    self:SetNWInt("EyeballAttitude", EYEBALL_CALM)
    self:SetNWVector("EyeballLookAtSpot", self:WorldSpaceCenter() + self:GetForward() * 300)

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
    self.AggroTarget = nil
    self.AggroUntil = 0
    self.LastKnownGroundZ = nil
    self.ControlVector = Vector(0, 0, 0)
    self.NextEscapePortal = 0
    self.ActiveEscapePortalA = nil
    self.ActiveEscapePortalB = nil

    local spawnGround = find_safe_ground(self:GetPos())
    if spawnGround then
        self.EmergeAnchor = spawnGround
        local spawnHeight = math.max(
            tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height,
            tonumber(cfg.teleport_arrive_height) or DEFAULT_CONFIG.teleport_arrive_height
        )
        local safeSpawn = spawnGround + Vector(0, 0, spawnHeight)
        if is_reasonable_vector(safeSpawn) then
            self.EmergeAnchor = safeSpawn
        end
    end
    self.EmergeHeight = math.max(self.EmergeHeight, tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height)
    self:SetPos(self.EmergeAnchor - Vector(0, 0, self.EmergeHeight))

    self:SetBossState("emerge", tonumber(cfg.emerge_time) or DEFAULT_CONFIG.emerge_time)
    local emergeAnimDur = self.SequenceDuration and self:SequenceDuration() or 0
    if emergeAnimDur and emergeAnimDur > 0 then
        self.StateUntil = math.max(self.StateUntil or CurTime(), CurTime() + emergeAnimDur)
    end
    self.NextTeleport = CurTime() + math.Rand(
        tonumber(cfg.teleport_interval_min) or DEFAULT_CONFIG.teleport_interval_min,
        tonumber(cfg.teleport_interval_max) or DEFAULT_CONFIG.teleport_interval_max
    )
    self.NextEscapePortal = 0
    self.EnragedUntil = 0
    self._wasEnraged = false
    self.InjuryRateWindowUntil = CurTime() + 1.0
    self.InjuryRateWindowDamage = 0
    self.NextVoiceLineAt = CurTime() + math.Rand(3.0, 5.0)
    self.SpawnGraceUntil = CurTime() + 2.0
    self.NextGroundSampleAt = 0
    self.SmoothedDesiredWorldZ = nil

    self:EmitSound("Halloween.MonoculusBossSpawn", 100, 100)
    -- Match HHH spawn circle implementation: one halloween_boss_summon at grounded home position.
    local spawnFxPos = (find_safe_ground(self:GetPos()) or self:GetPos()) + Vector(0, 0, 10)
    DispatchEyeballParticle("halloween_boss_summon", spawnFxPos, self:GetAngles())

    if istable(self.DynamicScript) and isfunction(self.DynamicScript.OnSpawn) then
        pcall(self.DynamicScript.OnSpawn, self, self.DynamicConfig)
    end
    self:UpdateAnimationState()
end

function ENT:ClearControls()
    self.ControlVector = Vector(0, 0, 0)
end

function ENT:ControlForward(amount)
    self.ControlVector = self.ControlVector + self:GetForward() * (tonumber(amount) or 1)
end

function ENT:ControlBackward(amount)
    self.ControlVector = self.ControlVector - self:GetForward() * (tonumber(amount) or 1)
end

function ENT:ControlRight(amount)
    self.ControlVector = self.ControlVector + self:GetRight() * (tonumber(amount) or 1)
end

function ENT:ControlLeft(amount)
    self.ControlVector = self.ControlVector - self:GetRight() * (tonumber(amount) or 1)
end

function ENT:ControlUp(amount)
    self.ControlVector = self.ControlVector + Vector(0, 0, (tonumber(amount) or 1))
end

function ENT:ControlDown(amount)
    self.ControlVector = self.ControlVector - Vector(0, 0, (tonumber(amount) or 1))
end

function ENT:ApplyControls(cfg)
    local accel = tonumber(cfg.acceleration) or DEFAULT_CONFIG.acceleration
    local cv = self.ControlVector or vector_origin
    local mag = cv:Length()
    if mag <= 0.0001 then return end
    cv = cv / mag
    self.Acceleration = self.Acceleration + cv * accel
end

function ENT:ClearEscapePortals()
    if IsValid(self.ActiveEscapePortalA) then
        self.ActiveEscapePortalA:Remove()
    end
    self.ActiveEscapePortalA = nil
    self.ActiveEscapePortalB = nil
end

function ENT:SpawnEscapeVortexFrom(originPos)
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    if not isvector(originPos) then return false end

    local entryPos = originPos
    if not is_reasonable_vector(entryPos) then return false end

    local _, toPos = self:PickEscapePortalPair(originPos)
    if not isvector(toPos) then return false end
    if not is_valid_world_destination(toPos, false) then return false end
    if entryPos:DistToSqr(toPos) < (512 * 512) then return false end

    self:ClearEscapePortals()
    if count_active_escape_vortexes() >= 1 then
        return false
    end

    local vortex = ents.Create("teleport_vortex")
    if not IsValid(vortex) then return false end

    -- Match TF2 behavior: vortex appears where Monoculus teleported out, in-air.
    local fromPos = entryPos
    vortex:SetPos(fromPos)
    vortex:SetAngles(angle_zero)
    vortex:Spawn()
    vortex:Activate()

    local life = tonumber(cfg.escape_portal_lifetime) or DEFAULT_CONFIG.escape_portal_lifetime
    if vortex.SetLifetime then vortex:SetLifetime(life) end
    if vortex.SetDestinationPos then vortex:SetDestinationPos(toPos) end

    DispatchEyeballParticle("eyeboss_tp_escape", fromPos, angle_zero)
    DispatchEyeballParticle("eyeboss_tp_escape", toPos, angle_zero)
    self.ActiveEscapePortalA = vortex
    self.ActiveEscapePortalB = nil
    return true
end

function ENT:PickEscapePortalPair(centerOverride)
    local nodes = collect_escape_portal_nodes()
    local destNodes = collect_escape_destination_nodes()
    local mapName = string.lower(game.GetMap() or "")
    local center = isvector(centerOverride) and centerOverride or (IsValid(self.Target) and self.Target:GetPos() or self:GetPos())

    local validNodes = {}
    for _, node in ipairs(nodes) do
        if node and is_valid_world_destination(node.pos, true) then
            validNodes[#validNodes + 1] = node
        end
    end
    nodes = validNodes

    local validDestNodes = {}
    for _, node in ipairs(destNodes) do
        if node and is_valid_world_destination(node.pos, false) then
            validDestNodes[#validDestNodes + 1] = node
        end
    end
    destNodes = validDestNodes

    if mapName == "koth_viaduct_event" and is_valid_world_destination(VIADUCT_HELL_EXIT_POS, false) then
        local entryGround = find_safe_ground(center) or center
        if entryGround and is_reasonable_vector(entryGround) then
            return entryGround + Vector(0, 0, 16), VIADUCT_HELL_EXIT_POS
        end
    end

    if #nodes >= 1 then
        local entry = nil
        local entryDist = math.huge
        for _, node in ipairs(nodes) do
            local d = node.pos:DistToSqr(center)
            if d < entryDist then
                entry = node
                entryDist = d
            end
        end

        if entry then
            local exitNode = nil
            local bestScore = -math.huge

            local strictViaduct = mapName == "koth_viaduct_event"

            local candidateDestNodes = destNodes
            if strictViaduct then
                local viaductPreferred = {}
                for _, dest in ipairs(destNodes) do
                    local name = dest.name or ""
                    local isHellNamed = string.find(name, "underworld", 1, true) or string.find(name, "hell", 1, true)
                    local isDeepHell = (dest.pos and dest.pos.z < (center.z - 512))
                    if dest.class == "info_teleport_destination" and (isHellNamed or isDeepHell) then
                        viaductPreferred[#viaductPreferred + 1] = dest
                    end
                end
                if #viaductPreferred > 0 then
                    candidateDestNodes = viaductPreferred
                else
                    -- On viaduct_event never guess a generic destination; skip spawn if hell dest is unknown.
                    candidateDestNodes = {}
                end
            end

            local function scoreDestination(entryNode, destNode)
                local score = 0
                local d = destNode.pos:DistToSqr(entryNode.pos)
                score = score + math.min(d / (900 * 900), 10)

                if entryNode.base ~= "" and string.find(destNode.name, entryNode.base, 1, true) then
                    score = score + 50
                end

                if string.find(destNode.name, "underworld", 1, true) then score = score + 8 end
                if string.find(destNode.name, "hell", 1, true) then score = score + 8 end
                if destNode.class == "info_teleport_destination" then score = score + 20 end

                return score
            end

            if #candidateDestNodes > 0 then
                for _, dest in ipairs(candidateDestNodes) do
                    local score = scoreDestination(entry, dest)
                    if score > bestScore then
                        exitNode = dest
                        bestScore = score
                    end
                end
            elseif not strictViaduct then
                for _, node in ipairs(nodes) do
                    if node ~= entry then
                        local baseMatch = entry.base ~= "" and node.base == entry.base
                        if baseMatch or entry.base == "" then
                            local d = node.pos:DistToSqr(entry.pos)
                            if d > bestScore then
                                exitNode = node
                                bestScore = d
                            end
                        end
                    end
                end
            end

            if exitNode then
                return entry.pos, exitNode.pos
            end
        end
    end

    -- If no explicit entry nodes exist, create entry near the boss and still use map destinations.
    if #destNodes > 0 then
        local entryGround = find_safe_ground(center) or center
        if entryGround and is_reasonable_vector(entryGround) then
            if mapName == "koth_viaduct_event" then
                local strictDestNodes = {}
                for _, dest in ipairs(destNodes) do
                    local name = dest.name or ""
                    local isHellNamed = string.find(name, "underworld", 1, true) or string.find(name, "hell", 1, true)
                    local isDeepHell = (dest.pos and dest.pos.z < (center.z - 512))
                    if dest.class == "info_teleport_destination" and (isHellNamed or isDeepHell) then
                        strictDestNodes[#strictDestNodes + 1] = dest
                    end
                end
                destNodes = strictDestNodes
            end

            if #destNodes <= 0 then
                return nil, nil
            end

            local exitNode = nil
            local bestScore = -math.huge
            for _, dest in ipairs(destNodes) do
                local score = 0
                local name = dest.name or ""
                if dest.class == "info_teleport_destination" then score = score + 20 end
                if string.find(name, "underworld", 1, true) then score = score + 8 end
                if string.find(name, "hell", 1, true) then score = score + 8 end
                score = score + math.min(dest.pos:DistToSqr(entryGround) / (900 * 900), 10)
                if score > bestScore then
                    exitNode = dest
                    bestScore = score
                end
            end
            if exitNode then
                return entryGround + Vector(0, 0, 16), exitNode.pos
            end
        end
    end

    local function random_ground(origin, minR, maxR, attempts)
        for _ = 1, attempts do
            local ang = math.Rand(0, math.pi * 2)
            local dist = math.Rand(minR, maxR)
            local guess = origin + Vector(math.cos(ang) * dist, math.sin(ang) * dist, 0)
            local ground = find_safe_ground(guess)
            if ground and is_reasonable_vector(ground) then
                return ground + Vector(0, 0, 16)
            end
        end
        return nil
    end

    -- On viaduct_event, never fallback to random/out-of-bounds portal routing.
    if mapName ~= "koth_viaduct_event" then
        local from = random_ground(center, 256, 900, 8)
        local to = random_ground(center, 1200, 2600, 12)
        if from and to and from:DistToSqr(to) > (700 * 700) then
            return from, to
        end
    end

    return nil, nil
end

function ENT:SpawnEscapePortals()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    local fromPos, toPos = self:PickEscapePortalPair()
    if not (isvector(fromPos) and isvector(toPos)) then
        return false
    end

    self:ClearEscapePortals()
    if count_active_escape_vortexes() >= 1 then
        return false
    end

    local fromVortex = ents.Create("teleport_vortex")
    if not IsValid(fromVortex) then
        if IsValid(fromVortex) then fromVortex:Remove() end
        return false
    end

    fromVortex:SetPos(fromPos)
    fromVortex:SetAngles(angle_zero)
    fromVortex:Spawn()
    fromVortex:Activate()

    local life = tonumber(cfg.escape_portal_lifetime) or DEFAULT_CONFIG.escape_portal_lifetime
    if fromVortex.SetLifetime then fromVortex:SetLifetime(life) end
    if fromVortex.SetDestinationPos then fromVortex:SetDestinationPos(toPos) end

    DispatchEyeballParticle("eyeboss_tp_escape", fromPos, angle_zero)
    DispatchEyeballParticle("eyeboss_tp_escape", toPos, angle_zero)

    self.ActiveEscapePortalA = fromVortex
    self.ActiveEscapePortalB = nil
    return true
end

function ENT:SpawnDeathEscapeVortex()
    if not ENABLE_DEATH_VORTEX then return false end
    local mapName = string.lower(game.GetMap() or "")
    if mapName ~= "koth_viaduct_event" then return false end
    if not is_valid_world_destination(VIADUCT_DEATH_VORTEX_EXIT_POS, false) then return false end

    local entryPos = find_safe_ground(self:GetPos()) or self:GetPos()
    if not isvector(entryPos) then return false end

    if count_active_escape_vortexes() >= 1 then return false end

    local vortex = ents.Create("teleport_vortex")
    if not IsValid(vortex) then return false end

    vortex.DisablePurpleVortex = true
    vortex:SetPos(entryPos + Vector(0, 0, 16))
    vortex:SetAngles(angle_zero)
    vortex:Spawn()
    vortex:Activate()
    if vortex.SetLifetime then vortex:SetLifetime(DEATH_VORTEX_LIFETIME) end
    if vortex.SetDestinationPos then vortex:SetDestinationPos(VIADUCT_DEATH_VORTEX_EXIT_POS) end

    DispatchEyeballParticle("eyeboss_tp_escape", entryPos, angle_zero)
    DispatchEyeballParticle("eyeboss_tp_escape", VIADUCT_DEATH_VORTEX_EXIT_POS, angle_zero)
    DispatchEyeballParticle("eyeboss_death_vortex", entryPos, angle_zero)
    vortex:EmitSound("Halloween.TeleportVortex.EyeballDiedVortex", 95, 100)
    return true
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
    local pos = self:GetPos()
    local desiredAltitude = self.DesiredAltitude or tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height
    local mins, maxs = get_trace_bounds(self)
    local filter = function(hit)
        return hit ~= self and hit:GetClass() ~= "eyeball_boss"
    end

    local now = CurTime()
    if now >= (self.NextGroundSampleAt or 0) then
        self.NextGroundSampleAt = now + 0.08

        local trUp = util.TraceHull({
            start = pos,
            endpos = pos + Vector(0, 0, 1000),
            mins = mins,
            maxs = maxs,
            mask = MASK_PLAYERSOLID_BRUSHONLY,
            filter = filter,
        })

        local ceilingOffset = (trUp.HitPos and (trUp.HitPos.z - pos.z)) or 1000
        local aheadXY = Vector(0, 0, 0)
        local velXY = Vector(self.Velocity.x, self.Velocity.y, 0)
        if velXY:LengthSqr() > 1 then
            aheadXY = velXY:GetNormalized() * 50
        end

        local trDown = util.TraceHull({
            start = pos + Vector(0, 0, ceilingOffset) + aheadXY,
            endpos = pos + Vector(0, 0, -2000) + aheadXY,
            mins = Vector(1.25 * mins.x, 1.25 * mins.y, mins.z),
            maxs = Vector(1.25 * maxs.x, 1.25 * maxs.y, maxs.z),
            mask = MASK_PLAYERSOLID_BRUSHONLY,
            filter = filter,
        })

        if trDown.Hit then
            local groundZ = trDown.HitPos.z
            if self.LastKnownGroundZ == nil then
                self.LastKnownGroundZ = groundZ
            else
                local blend = 0.2
                self.LastKnownGroundZ = Lerp(blend, self.LastKnownGroundZ, groundZ)
            end
        end
    end

    local fallbackGroundZ = (self.EmergeAnchor and (self.EmergeAnchor.z - desiredAltitude)) or (pos.z - desiredAltitude)
    local groundZ = self.LastKnownGroundZ or fallbackGroundZ
    local currentAltitude = pos.z - groundZ
    local accel = tonumber(cfg.acceleration) or DEFAULT_CONFIG.acceleration
    local errorZ = desiredAltitude - currentAltitude
    if math.abs(errorZ) < 6 then
        errorZ = 0
    end
    self._altitudeError = errorZ

    -- Damped spring vertical controller to remove hover vibration.
    local damping = 2.0
    local accelZ = math.Clamp((errorZ * 4.0) - (self.Velocity.z * damping), -accel, accel)
    self.Acceleration = self.Acceleration + Vector(0, 0, accelZ)
end

function ENT:ApproachXY(goalPos, cfg)
    local toGoal = Vector(goalPos.x - self:GetPos().x, goalPos.y - self:GetPos().y, 0)
    local dist = toGoal:Length()
    if dist <= 8 then return end

    local fwd = self:GetForward()
    local right = self:GetRight()
    local x = toGoal:Dot(fwd)
    local y = toGoal:Dot(right)
    local deadzone = 16

    if x > deadzone then
        self:ControlForward(math.Clamp(x / 512, 0.25, 1.0))
    elseif x < -deadzone then
        self:ControlBackward(math.Clamp(math.abs(x) / 512, 0.25, 1.0))
    end

    if y > deadzone then
        self:ControlRight(math.Clamp(y / 512, 0.25, 1.0))
    elseif y < -deadzone then
        self:ControlLeft(math.Clamp(math.abs(y) / 512, 0.25, 1.0))
    end
end

function ENT:OnInjured(dmginfo)
    if not dmginfo then return end

    local now = CurTime()
    if now < (self.SpawnGraceUntil or 0) then
        return
    end

    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    local window = tonumber(cfg.stun_burst_window) or DEFAULT_CONFIG.stun_burst_window
    local burst = tonumber(cfg.stun_burst_damage) or DEFAULT_CONFIG.stun_burst_damage

    if now > self.StunBurstReset then
        self.StunBurst = 0
        self.StunBurstReset = now + math.max(0.1, window)
    end

    self.StunBurst = self.StunBurst + math.max(0, dmginfo:GetDamage())
    local attacker = IsValid(dmginfo:GetAttacker()) and dmginfo:GetAttacker() or nil
    local inflictor = IsValid(dmginfo:GetInflictor()) and dmginfo:GetInflictor() or nil
    if IsValid(attacker) and attacker:IsPlayer() and attacker:Alive() then
        self.AggroTarget = attacker
        self.AggroUntil = now + math.max(1.0, tonumber(cfg.aggro_lock_time) or DEFAULT_CONFIG.aggro_lock_time)
        self.Target = attacker
        self:SetNWBool("EyeballAggro", true)
    end

    if now > (self.InjuryRateWindowUntil or 0) then
        self.InjuryRateWindowUntil = now + 1.0
        self.InjuryRateWindowDamage = 0
    end
    self.InjuryRateWindowDamage = (self.InjuryRateWindowDamage or 0) + math.max(0, dmginfo:GetDamage())
    -- Mirror TF2 intent: heavy recent DPS enrages the boss.
    -- Use damage accumulated in a ~1 second sliding bucket as DPS proxy.
    local injuryRate = self.InjuryRateWindowDamage

    local reflectedRocket = false
    if IsValid(inflictor) then
        local cls = string.lower(tostring(inflictor:GetClass() or ""))
        if cls == "tf_projectile_rocket" or cls == "tf_projectile_rocket_airstrike" or cls == "tf_projectile_rocket_fireball" or cls == "tf_projectile_sentryrocket" then
            local override = string.lower(tostring(inflictor.NameOverride or ""))
            reflectedRocket = string.find(override, "deflect", 1, true) ~= nil
        end
    end

    if IsValid(attacker) and attacker:IsPlayer() and (reflectedRocket or dmginfo:IsDamageType(DMG_CRITICAL) or injuryRate > EYEBALL_ENRAGE_DAMAGE_RATE) then
        self:BecomeEnraged(5.0, attacker)
    end

    if self.StateName ~= "stunned" and self.StunBurst >= burst then
        self.StunBurst = 0
        hook.Run("TF_HalloweenBossStunned", self, IsValid(dmginfo:GetAttacker()) and dmginfo:GetAttacker() or NULL)
        self:SetDesiredAltitude(0)
        self:SetBossState("stunned", tonumber(cfg.stun_time) or DEFAULT_CONFIG.stun_time)
    end
end

function ENT:OnKilled(dmginfo)
    self:ClearEscapePortals()
    if ENABLE_DEATH_VORTEX then
        self:SpawnDeathEscapeVortex()
    end
    hook.Call("OnNPCKilled", GAMEMODE, self, IsValid(dmginfo) and dmginfo:GetAttacker() or NULL, IsValid(dmginfo) and dmginfo:GetInflictor() or NULL)
    self:EmitSound("Cart.Explode", 95, 100)
    self:EmitSound("Halloween.EyeballBossDie", 95, 100)
    self:EmitSound("Halloween.MonoculusBossDeath", 95, 100)
    DispatchEyeballParticle("eyeboss_death", self:GetPos(), self:GetAngles())
    self:Remove()
end

function ENT:OnRemove()
    if self.StateName == "escape" and not self.EscapeEffectPlayed then
        DispatchEyeballParticle("eyeboss_tp_escape", self:GetPos(), self:GetAngles())
    end
    self:ClearEscapePortals()
end

function ENT:Think()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    local now = CurTime()
    local hover = tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height

    if util and util.IsInWorld and not util.IsInWorld(self:GetPos() + Vector(0, 0, 24)) then
        local snap = find_safe_world_hover(self.LastSafePos or self.EmergeAnchor or self:GetPos(), hover)
            or find_safe_world_hover(get_spawn_boss_pos() or self:GetPos(), hover)
            or find_safe_world_hover(self:GetPos(), hover)

        if not snap then
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
                    snap = find_safe_world_hover(ply:GetPos(), hover)
                    if snap then break end
                end
            end
        end

        if snap then
            self:SetPos(snap)
            self.LastSafePos = snap
            self.Velocity = vector_origin
            self.Acceleration = vector_origin
            self.SmoothedDesiredWorldZ = snap.z
        end
    end

    local enragedNow = self:IsEnraged()
    if self._wasEnraged and not enragedNow then
        self:EmitSound("Halloween.EyeballBossCalmDown", 95, 100)
    end
    self._wasEnraged = enragedNow

    if self:Health() <= 0 then
        self:Remove()
        return
    end

    if self.StateName == "escape" then
        self.Velocity = self.Velocity * 0.85
        self.Acceleration = vector_origin
        self:SetDesiredAltitude(hover)
        if self.FrameAdvance then
            self:FrameAdvance(FrameTime())
        end
        if now >= (self.EscapeDespawnAt or 0) then
            self.EscapeEffectPlayed = true
            DispatchEyeballParticle("eyeboss_tp_escape", self:GetPos(), self:GetAngles())
            self:Remove()
            return
        end
        self:NextThink(now)
        return true
    end

    if now >= (self.NextAcquire or 0) then
        self:PickTarget()
        self.NextAcquire = now + 0.25
    end

    local target = IsValid(self.Target) and self.Target or nil
    self:ClearControls()

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
                local eyePos = (ply.EyePos and ply:EyePos()) or (ply.WorldSpaceCenter and ply:WorldSpaceCenter()) or ply:GetPos()
                local toPlayer = eyePos - self.EmergeAnchor
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
            self:SetBossState("idle", 0)
        end
    elseif self.StateName == "idle" then
        self:SetDesiredAltitude(tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height)
        if target then
            self.LastVictim = target
            self.AggroTarget = target
            self.AggroUntil = now + math.max(1.0, tonumber(cfg.aggro_lock_time) or DEFAULT_CONFIG.aggro_lock_time)
            self:SetNWBool("EyeballAggro", true)
            self:SetBossState("notice", tonumber(cfg.notice_time) or DEFAULT_CONFIG.notice_time)
        elseif now >= (self.NextTeleport or 0) then
            self:SetDesiredAltitude(0)
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
                    local volleyCount, volleyDelay, volleyAnimNames, volleySpeedScale = self:GetVolleyProfile()
                    self.RemainingVolley = math.max(1, math.floor(volleyCount))
                    self.NextAttack = now + math.max(0.05, tonumber(volleyDelay) or 0.5)
                    self.LaunchAnimNames = volleyAnimNames
                    self.LaunchSpeedScale = math.max(0.05, tonumber(volleySpeedScale) or 1)
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
            self:ApproachXY(target:WorldSpaceCenter(), cfg)

            if now >= (self.NextAttack or 0) then
                self:SpawnBossProjectile(target:WorldSpaceCenter())
                self.RemainingVolley = math.max(0, (self.RemainingVolley or 0) - 1)
                self.NextAttack = now + math.max(0.05, tonumber(cfg.volley_interval) or DEFAULT_CONFIG.volley_interval)
                if self.RemainingVolley <= 0 then
                    self.LaunchAnimNames = nil
                    self.LaunchSpeedScale = nil
                    self:SetBossState("idle", 0)
                end
            end
        end
    elseif self.StateName == "teleport" then
        self:EmitSound("Halloween.MonoculusBossTeleport", 95, 100)
        local oldPos = self:GetPos()
        self:SpawnEscapeVortexFrom(oldPos)
        local tpPos = self:PickTeleportPosition()
        if is_reasonable_vector(tpPos) then
            local arriveHeight = tonumber(cfg.teleport_arrive_height) or DEFAULT_CONFIG.teleport_arrive_height
            local finalPos = find_safe_world_hover(tpPos, arriveHeight)
                or find_safe_world_hover(self.LastSafePos or self.EmergeAnchor or oldPos, arriveHeight)
                or self.LastSafePos
                or self.EmergeAnchor
                or self:GetPos()
            DispatchEyeballParticle("eyeboss_tp_normal", self:GetPos(), self:GetAngles())
            self:SetPos(finalPos)
            self.LastSafePos = finalPos
            self.EmergeAnchor = finalPos
            self.SpawnGraceUntil = now + 1.0
            DispatchEyeballParticle("eyeboss_tp_normal", finalPos, self:GetAngles())
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
            self:BecomeEnraged(20.0, target)
            self:SetDesiredAltitude(tonumber(cfg.hover_height) or DEFAULT_CONFIG.hover_height)
            self:SetBossState("idle", 0)
        end
    end

    local dt = FrameTime()
    local accel = tonumber(cfg.acceleration) or DEFAULT_CONFIG.acceleration
    local configuredSpeed = tonumber(cfg.speed) or DEFAULT_CONFIG.speed
    local maxSpeed = math.min(configuredSpeed, TF2_EYEBALL_BOSS_SPEED)
    local dampH = tonumber(cfg.horiz_damping) or DEFAULT_CONFIG.horiz_damping
    local dampV = tonumber(cfg.vert_damping) or DEFAULT_CONFIG.vert_damping

    if self.StateName == "emerge" then
        self.Velocity = vector_origin
        self.Acceleration = vector_origin
        if self.FrameAdvance then
            self:FrameAdvance(FrameTime())
        end
        self:NextThink(now)
        return true
    end

    self:MaintainAltitude(cfg, dt)
    self:ApplyControls(cfg)

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

    local desiredAltitudeNow = self.DesiredAltitude or hover
    local fallbackGroundZ = (self.EmergeAnchor and (self.EmergeAnchor.z - desiredAltitudeNow)) or (self:GetPos().z - desiredAltitudeNow)
    local desiredGroundZ = self.LastKnownGroundZ or fallbackGroundZ
    local desiredWorldZ = desiredGroundZ + desiredAltitudeNow
    if self.SmoothedDesiredWorldZ == nil then
        self.SmoothedDesiredWorldZ = desiredWorldZ
    else
        self.SmoothedDesiredWorldZ = Lerp(math.Clamp(dt * 6, 0.08, 0.3), self.SmoothedDesiredWorldZ, desiredWorldZ)
    end

    local maxVz = tonumber(cfg.max_vertical_speed) or DEFAULT_CONFIG.max_vertical_speed
    local altitudeDelta = (self.SmoothedDesiredWorldZ or self:GetPos().z) - self:GetPos().z
    local nextVz = altitudeDelta / math.max(dt, 0.001)
    -- Ensure Monoculus can meaningfully float down while translating horizontally.
    if altitudeDelta < -24 then
        nextVz = math.min(nextVz, -120)
    end
    self.Velocity.z = math.Clamp(nextVz, -maxVz, maxVz)

    local nextPos = self:GetPos() + self.Velocity * dt
    local outsideWorld = util and util.IsInWorld and (not util.IsInWorld(nextPos + Vector(0, 0, 24)))
    if not is_reasonable_vector(nextPos) or outsideWorld then
        nextPos = find_safe_world_hover(self.LastSafePos or self.EmergeAnchor or self:GetPos(), hover)
            or find_safe_world_hover(get_spawn_boss_pos() or self:GetPos(), hover)
            or find_safe_world_hover(self:GetPos(), hover)
            or (self.LastSafePos or self:GetPos())
        self.Velocity = Vector(0, 0, 0)
    end

    nextPos.z = self.SmoothedDesiredWorldZ or nextPos.z

    -- Keep Monoculus from climbing too high over local/fallback ground.
    do
        local nearbyGround = get_ground_below(self, nextPos)
        local groundZ = nearbyGround and nearbyGround.z
            or self.LastKnownGroundZ
            or (self.EmergeAnchor and (self.EmergeAnchor.z - hover))
            or (self.LastSafePos and (self.LastSafePos.z - hover))

        if groundZ then
            local maxExtra = 96
            local maxAllowedZ = groundZ + hover + maxExtra
            if nextPos.z > maxAllowedZ then
                nextPos.z = maxAllowedZ
                if self.Velocity.z > 0 then
                    self.Velocity.z = 0
                end
                -- Also keep the smoothed target from re-pushing upward next tick.
                if self.SmoothedDesiredWorldZ and self.SmoothedDesiredWorldZ > maxAllowedZ then
                    self.SmoothedDesiredWorldZ = maxAllowedZ
                end
            end
        end
    end

    -- Map-specific absolute altitude cap for viaduct_event.
    do
        local mapName = string.lower(game.GetMap() or "")
        if mapName == "koth_viaduct_event" and nextPos.z > VIADUCT_MONOCULUS_MAX_Z then
            nextPos.z = VIADUCT_MONOCULUS_MAX_Z
            if self.Velocity.z > 0 then
                self.Velocity.z = 0
            end
            if self.SmoothedDesiredWorldZ and self.SmoothedDesiredWorldZ > VIADUCT_MONOCULUS_MAX_Z then
                self.SmoothedDesiredWorldZ = VIADUCT_MONOCULUS_MAX_Z
            end
        end
    end

    -- Prevent ping-pong near map/building geometry: resolve hull hits explicitly.
    do
        local mins, maxs = get_trace_bounds(self)
        local tr = util.TraceHull({
            start = self:GetPos(),
            endpos = nextPos,
            mins = mins,
            maxs = maxs,
            mask = MASK_PLAYERSOLID,
            filter = function(hit)
                return hit ~= self and hit:GetClass() ~= "eyeball_boss"
            end
        })

        if tr.StartSolid then
            nextPos = find_safe_world_hover(self.LastSafePos or self.EmergeAnchor or self:GetPos(), hover)
                or find_safe_world_hover(get_spawn_boss_pos() or self:GetPos(), hover)
                or self:GetPos()
            self.Velocity = vector_origin
        elseif tr.Hit then
            local n = tr.HitNormal
            local push = -n * 8
            -- Never resolve a hit by pushing Monoculus upward into/through ceilings.
            if n.z < 0 and push.z > 0 then
                push.z = 0
            end
            nextPos = tr.HitPos + push
            local blocked = (self.Velocity.x * n.x) + (self.Velocity.y * n.y) + (self.Velocity.z * n.z)
            self.Velocity = self.Velocity - n * blocked
            self.Velocity.x = self.Velocity.x * 0.35
            self.Velocity.y = self.Velocity.y * 0.35
            self.Velocity.z = self.Velocity.z * 0.5
            self.WallRecoverUntil = now + 0.4
        end
    end

    -- If we just hit geometry, keep horizontal speed low briefly so we settle instead of rebounding.
    if (self.WallRecoverUntil or 0) > now then
        local recoverMax = math.min(maxSpeed, 120)
        local vxy = Vector(self.Velocity.x, self.Velocity.y, 0)
        local vxyLen = vxy:Length()
        if vxyLen > recoverMax and vxyLen > 0 then
            vxy = vxy:GetNormalized() * recoverMax
            self.Velocity.x = vxy.x
            self.Velocity.y = vxy.y
        end
    end

    if util and util.IsInWorld and not util.IsInWorld(nextPos + Vector(0, 0, 24)) then
        nextPos = find_safe_world_hover(self.LastSafePos or self.EmergeAnchor or self:GetPos(), hover)
            or find_safe_world_hover(get_spawn_boss_pos() or self:GetPos(), hover)
            or self:GetPos()
        self.Velocity = vector_origin
        self.WallRecoverUntil = now + 0.4
    end

    local delta = nextPos - self:GetPos()
    if delta:LengthSqr() < (0.5 * 0.5) and self.Velocity:LengthSqr() < (6 * 6) then
        nextPos = self:GetPos()
        self.Velocity = vector_origin
    end

    if util and util.IsInWorld and util.IsInWorld(nextPos + Vector(0, 0, 24)) then
        self.LastSafePos = nextPos
    end

    self:SetPos(nextPos)
    self:SetGroundEntity(NULL)
    self.Acceleration = Vector(0, 0, 0)

    if target then
        local look = (target:WorldSpaceCenter() - self:WorldSpaceCenter()):Angle()
        self:SetAngles(Angle(math.Clamp(look.p, -35, 35), look.y, 0))
    end

    -- Mirror TF2 attitude-driven aura updates on client.
    local attitude = EYEBALL_CALM
    if self.StateName == "stunned" then
        attitude = EYEBALL_STUNNED
    elseif self:IsEnraged() then
        attitude = EYEBALL_ANGRY
    elseif self.StateName == "approach" or self.StateName == "notice" or self.StateName == "launch" then
        attitude = EYEBALL_GRUMPY
    end
    self:ApplyAttitudeVisuals(attitude, target)

    if self.StateName == "idle" and now >= (self.NextVoiceLineAt or 0) then
        if self:IsEnraged() then
            self:EmitSound("Halloween.EyeballBossRage", 95, 100)
            self.NextVoiceLineAt = now + math.Rand(1.0, 2.0)
        else
            self:EmitSound("Halloween.EyeballBossIdle", 95, 100)
            self.NextVoiceLineAt = now + math.Rand(3.0, 5.0)
        end
    end

    if istable(self.DynamicScript) and isfunction(self.DynamicScript.OnThink) then
        pcall(self.DynamicScript.OnThink, self, self.DynamicConfig, self.StateName, target)
    end

    if self.FrameAdvance then
        self:FrameAdvance(dt)
    end

    self:NextThink(now)
    return true
end

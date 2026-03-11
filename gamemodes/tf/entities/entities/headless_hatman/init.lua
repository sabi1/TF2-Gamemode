AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local DEFAULT_CONFIG = {
    health_base = 3000,
    health_per_player = 200,
    health_max = 7800,
    min_players = 0,
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
    weapon_model = "models/weapons/c_models/c_headtaker/c_headtaker.mdl",
}

local BASE_GAME_PATH = "gamemodes/tf/gamemode/halloween/headless_hatman/"
local BASE_DATA_PATH = "tf2gm/halloween/headless_hatman/"
local TF_STUN_LOSER_STATE_FALLBACK = bit.lshift(1, 6) -- 64 in TF2.
local TF_STUN_BY_TRIGGER_FALLBACK = bit.lshift(1, 7) -- 128 in TF2.
local HHH_SCARE_PARTICLE = "yikes_fx"
local HHH_PARTICLE_DEBUG_CVAR = "tf_halloween_hhh_particle_debug"

local PARTICLE_SYSTEMS_TO_PRECACHE = {
    "halloween_boss_summon",
    "halloween_boss_axe_hit_world",
    "halloween_boss_injured",
    "halloween_boss_death",
    "halloween_boss_foot_impact",
    "halloween_boss_eye_glow",
    "ghost_pumpkin",
    "bonk_text",
    "yikes_fx",
}

local PARTICLE_FILES_TO_LOAD = {
    "particles/halloween.pcf",
    "particles/eyeboss.pcf",
    "particles/impact_fx.pcf",
    "particles/speechbubbles.pcf",
}

if SERVER and not ConVarExists(HHH_PARTICLE_DEBUG_CVAR) then
    CreateConVar(HHH_PARTICLE_DEBUG_CVAR, "0", FCVAR_ARCHIVE, "Enable HHH particle debug logging.")
end

local function hhh_particle_debug_enabled()
    local cv = GetConVar(HHH_PARTICLE_DEBUG_CVAR)
    return cv and cv:GetBool() or false
end

local function hhh_particle_debug(fmt, ...)
    if not hhh_particle_debug_enabled() then return end
    MsgN(string.format("[HHH Particle Debug] " .. tostring(fmt), ...))
end

local function add_particle_file_safe(path)
    if not game or not game.AddParticles then return false end
    if not isstring(path) or path == "" then return false end

    if file.Exists(path, "GAME") then
        local ok, err = pcall(game.AddParticles, path)
        if not ok then
            hhh_particle_debug("game.AddParticles failed for '%s': %s", path, tostring(err))
            return false
        end
        hhh_particle_debug("Loaded particle file '%s'", path)
        return true
    end

    local fallback = "gamemodes/tf/content/" .. path
    if file.Exists(fallback, "GAME") then
        local ok, err = pcall(game.AddParticles, fallback)
        if not ok then
            hhh_particle_debug("game.AddParticles failed for fallback '%s': %s", fallback, tostring(err))
            return false
        end
        hhh_particle_debug("Loaded particle file '%s' (fallback)", fallback)
        return true
    end

    hhh_particle_debug("Missing particle file '%s' (and fallback)", path)
    return false
end

local particleFilesLoaded = false
local function EnsureHHHParticleFilesLoaded()
    if particleFilesLoaded then return end
    particleFilesLoaded = true
    for _, pcf in ipairs(PARTICLE_FILES_TO_LOAD) do
        add_particle_file_safe(pcf)
    end
end

local particlesPrecached = false
local function EnsureHHHParticlesPrecached()
    if particlesPrecached then return end
    particlesPrecached = true
    EnsureHHHParticleFilesLoaded()
    if not PrecacheParticleSystem then return end
    for _, system in ipairs(PARTICLE_SYSTEMS_TO_PRECACHE) do
        local ok, err = pcall(PrecacheParticleSystem, system)
        if not ok then
            hhh_particle_debug("PrecacheParticleSystem failed for '%s': %s", system, tostring(err))
        else
            hhh_particle_debug("Precached particle system '%s'", system)
        end
    end
end

local function DispatchHHHParticle(name, pos, ang, parent)
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
        hhh_particle_debug("No particle dispatch function available for '%s'", name)
        return false
    end

    if not ok then
        hhh_particle_debug("Particle dispatch failed for '%s': %s", name, tostring(err))
        return false
    end

    if not DispatchParticleEffect then
        hhh_particle_debug("Dispatched particle '%s' via ParticleEffect fallback at %s", name, tostring(p))
    else
        hhh_particle_debug("Dispatched particle '%s' at %s", name, tostring(p))
    end

    return true
end

local function get_nextbot_speed_2d(ent)
    if not IsValid(ent) then return 0 end

    local speed = 0
    if ent.GetVelocity then
        local vel = ent:GetVelocity()
        if isvector(vel) then
            speed = vel:Length2D()
        end
    end

    if ent.loco and ent.loco.GetVelocity then
        local lvel = ent.loco:GetVelocity()
        if isvector(lvel) then
            speed = math.max(speed, lvel:Length2D())
        end
    end

    return speed
end

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

local function resolve_lang_token(token)
    if not isstring(token) or token == "" then return "" end
    if tf_lang and tf_lang.GetRaw then
        local text = tf_lang.GetRaw(token, true)
        if isstring(text) and text ~= "" then
            return text
        end
    end
    if string.StartWith(token, "#") then
        return string.sub(token, 2)
    end
    return token
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

local function IsWearingPumpkinHeadOrSaxtonMask(ply)
    if not IsValid(ply) or not ply.GetTFItems then return false end

    for _, item in ipairs(ply:GetTFItems()) do
        if IsValid(item) and item.IsTFItem then
            local itemID = nil
            if item.ItemIndex then
                itemID = tonumber(item:ItemIndex())
            elseif item.GetItemData then
                local data = item:GetItemData() or {}
                itemID = tonumber(data.item_index or data.id)
            end

            if itemID == 277 or itemID == 278 then
                return true
            end
        end
    end

    return false
end

local function PlayScarePresentation(victim, duration)
    if not IsValid(victim) then return end
    local entId = victim:EntIndex()
    local loserTimer = "TF2HHHScareLoser_" .. entId
    timer.Remove(loserTimer)

    local wasLoser = victim.GetNWBool and victim:GetNWBool("Loser", false) or false
    if victim.SetNWBool and not wasLoser then
        victim:SetNWBool("Loser", true)
        timer.Create(loserTimer, duration, 1, function()
            if not IsValid(victim) then return end
            if victim.SetNWBool then
                victim:SetNWBool("Loser", false)
            end
        end)
    end

    -- TF2 scare presentation: scream + yikes at head.
    if victim.EmitSound then
        victim:EmitSound("Halloween.PlayerScream", 95, 100)
        victim:EmitSound("player/pl_impact_stun.wav", 90, 100)
    end

    local pos = victim:WorldSpaceCenter()
    local att = victim.LookupAttachment and victim:LookupAttachment("head") or 0
    if att and att > 0 and victim.GetAttachment then
        local data = victim:GetAttachment(att)
        if data and data.Pos then
            pos = data.Pos
        end
    end
    -- TF2 boo scare presentation uses yikes-style feedback; fall back to bonk if unavailable.
    if not DispatchHHHParticle(HHH_SCARE_PARTICLE, pos, angle_zero, victim) then
        DispatchHHHParticle("bonk_text", pos, angle_zero, victim)
    end
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
    local perPlayer = tonumber(cfg.health_per_player) or DEFAULT_CONFIG.health_per_player
    local hpMax = tonumber(cfg.health_max) or DEFAULT_CONFIG.health_max
    local total = collect_living_humans()
    hp = hp + (total * perPlayer)
    if hpMax and hpMax > 0 then
        hp = math.min(hp, hpMax)
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

    return "models/weapons/c_models/c_headtaker/c_headtaker.mdl"
end

function ENT:AttachWeaponModelTF2Style()
    if not IsValid(self.Axe) then return end

    local mergeFx = bit.bor(EF_BONEMERGE, EF_BONEMERGE_FASTCULL, EF_PARENT_ANIMATES)
    self.Axe:AddEffects(mergeFx)
    if self.Axe.DrawShadow then
        self.Axe:DrawShadow(false)
    end
    if self.Axe.SetNotSolid then
        self.Axe:SetNotSolid(true)
    end

    -- Valve style: prop_dynamic follows the boss with bonemerge.
    if self.Axe.FollowEntity then
        local ok, err = pcall(self.Axe.FollowEntity, self.Axe, self, true)
        if not ok then
            hhh_particle_debug("FollowEntity failed for axe: %s", tostring(err))
            self.Axe:SetParent(self)
        end
    else
        self.Axe:SetParent(self)
    end

    self.Axe:SetLocalPos(vector_origin)
    self.Axe:SetLocalAngles(angle_zero)

    -- Fallback for models that do not resolve well with bonemerge alone.
    local weaponBone = self:LookupBone("weapon_bone")
    if self.Axe.FollowBone and weaponBone and weaponBone >= 0 then
        pcall(self.Axe.FollowBone, self.Axe, self, weaponBone)
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
                local msg = resolve_lang_token("#TF_HALLOWEEN_BOSS_WARN_VICTIM")
                newIT:PrintMessage(HUD_PRINTTALK, msg)
                newIT:PrintMessage(HUD_PRINTCENTER, msg)
            end
            try_emit_sound(newIT, { "Player.YouAreIT", "Player.YouAreIt" }, 100, 100)
            try_emit_sound(newIT, "Halloween.PlayerScream", 100, 100)
        end
        if IsValid(oldIT) and oldIT ~= newIT and oldIT:Alive() then
            try_emit_sound(oldIT, { "Player.TaggedOtherIT", "Player.TaggedOtherIt" }, 100, 100)
            if oldIT.PrintMessage then
                local msg = resolve_lang_token("#TF_HALLOWEEN_BOSS_LOST_AGGRO")
                oldIT:PrintMessage(HUD_PRINTTALK, msg)
                oldIT:PrintMessage(HUD_PRINTCENTER, msg)
            end
        end
        self.ITVictim = newIT
    end
    self.ITVictim = IsValid(victim) and victim or nil
end

function ENT:ApplySpookStun(victim, duration)
    if not IsValid(victim) then return end
    local stunBase = tonumber(_G.TF_STUN_LOSER_STATE) or TF_STUN_LOSER_STATE_FALLBACK
    local stunByTrigger = tonumber(_G.TF_STUN_BY_TRIGGER) or TF_STUN_BY_TRIGGER_FALLBACK
    local stunFlags = bit.bor(stunBase, stunByTrigger)
    local stunnedCond = _G.TF_COND_STUNNED
    local loserCond = _G.TF_COND_COMPETITIVE_LOSER
    local freezeInputCond = _G.TF_COND_FREEZE_INPUT
    duration = math.max(0.1, tonumber(duration) or 2)
    local stunnedByEngine = false

    if victim.StunPlayer then
        local ok = pcall(victim.StunPlayer, victim, duration, 0, stunFlags, self)
        stunnedByEngine = ok and true or false
    end

    PlayScarePresentation(victim, duration)

    -- Force loser/scared visuals for boo (match-lost style).
    if victim.AddCond and loserCond then
        pcall(victim.AddCond, victim, loserCond, duration, self)
    end

    -- TF2 loser-state stun effectively locks player controls during the scare.
    if victim.AddCond and freezeInputCond then
        pcall(victim.AddCond, victim, freezeInputCond, duration, self)
    end

    -- Engine stun can force ACT_MP_STUN_*; clear that condition so boo uses
    -- loser/scared animation instead of generic stun animation.
    if stunnedByEngine and stunnedCond and victim.RemoveCond then
        timer.Simple(0, function()
            if not IsValid(victim) then return end
            victim:RemoveCond(stunnedCond, true)
            if victim.RemovePlayerState then
                victim:RemovePlayerState(PLAYERSTATE_STUNNED, true)
            end
        end)
    end

    -- Only apply manual stun fallback if StunPlayer could not be used.
    if not stunnedByEngine then
        timer.Create("TF2HHHSpookFallback" .. victim:EntIndex(), duration, 1, function()
            if not IsValid(victim) then return end
            if victim.RemovePlayerState then
                victim:RemovePlayerState(PLAYERSTATE_STUNNED, true)
            end
            if victim.RemoveCond and loserCond then
                victim:RemoveCond(loserCond, true)
            end
            if victim.RemoveCond and stunnedCond then
                victim:RemoveCond(stunnedCond, true)
            end
            if victim.RemoveCond and freezeInputCond then
                victim:RemoveCond(freezeInputCond, true)
            end
        end)
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
    if name == "emerge" then
        self.EmergeAnimStartedAt = CurTime()
        self.EmergeAnimFinishAt = nil
        if self.SetCycle then
            self:SetCycle(0)
        end
        if self.SequenceDuration then
            local seqDur = tonumber(self:SequenceDuration()) or 0
            if seqDur > 0 then
                self.EmergeAnimFinishAt = self.EmergeAnimStartedAt + seqDur
            end
        end
    end
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
    EnsureHHHParticlesPrecached()
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
    DispatchHHHParticle("halloween_boss_summon", self.HomePos, self:GetAngles())
    -- Ambient HHH effects (eye glows + ghost body aura) are managed clientside
    -- so they persist for observers regardless of server-side particle dispatch API.
    self.NextFootstep = 0

    self.Axe = ents.Create("prop_dynamic")
    if IsValid(self.Axe) then
        self.Axe:SetModel(self:GetBossWeaponModel())
        self.Axe:Spawn()
        self:AttachWeaponModelTF2Style()
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
    timer.Remove("TF2HHHDeath_" .. self:EntIndex())
    if IsValid(self.Axe) then
        self.Axe:Remove()
    end
end

function ENT:GetFootstepEffectPos()
    local useLeft = self._nextFootLeft ~= true
    self._nextFootLeft = useLeft

    local attachmentNames = useLeft
        and { "foot_L", "left_foot", "LFoot", "leftfoot", "l_foot" }
        or { "foot_R", "right_foot", "RFoot", "rightfoot", "r_foot" }

    if self.LookupAttachment and self.GetAttachment then
        for _, name in ipairs(attachmentNames) do
            local id = self:LookupAttachment(name)
            if id and id > 0 then
                local data = self:GetAttachment(id)
                if data and data.Pos then
                    return data.Pos, data.Ang or self:GetAngles()
                end
            end
        end
    end

    local boneNames = useLeft
        and { "bip_foot_L", "ValveBiped.Bip01_L_Foot" }
        or { "bip_foot_R", "ValveBiped.Bip01_R_Foot" }

    if self.LookupBone and self.GetBonePosition then
        for _, name in ipairs(boneNames) do
            local id = self:LookupBone(name)
            if id and id >= 0 then
                local pos, ang = self:GetBonePosition(id)
                if isvector(pos) then
                    return pos, ang or self:GetAngles()
                end
            end
        end
    end

    return self:GetPos(), self:GetAngles()
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
                target:PrintMessage(HUD_PRINTCENTER, resolve_lang_token("#TF_HALLOWEEN_BOSS_WARN_VICTIM"))
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
        if is_valid_target(ply)
            and not IsWearingPumpkinHeadOrSaxtonMask(ply)
            and self:IsRangeLessThan(ply, radius)
            and self:IsLineOfSightClear(ply)
        then
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
    local healthBeforeHit = isfunction(target.Health) and target:Health() or 0
    local markForDecap = healthBeforeHit > 0 and damage >= healthBeforeHit and isfunction(target.AddDeathFlag)

    if markForDecap then
        target:AddDeathFlag(DF_DECAP)
    end

    local info = DamageInfo()
    info:SetAttacker(self)
    info:SetInflictor(self)
    info:SetDamage(damage)
    info:SetDamageType(bit.bor(DMG_CLUB, DMG_SLASH))
    info:SetDamageForce(toVictim * 12000 + Vector(0, 0, 8000))
    target:TakeDamageInfo(info)
    target:SetVelocity(toVictim * 300 + Vector(0, 0, 250))

    -- Keep decap only if this strike actually killed the target.
    if markForDecap and isfunction(target.RemoveDeathFlag) then
        timer.Simple(0, function()
            if not IsValid(target) then return end
            if target:Health() > 0 then
                target:RemoveDeathFlag(DF_DECAP)
            end
        end)
    end

    self:EmitSound("Halloween.HeadlessBossAxeHitFlesh", 95, 100)
    return true
end

function ENT:BeginMeleeSwing(target)
    if self.AttackSwinging then return end
    local cfg = self.DynamicConfig or DEFAULT_CONFIG

    add_gesture_safe(self, ACT_MP_ATTACK_STAND_ITEM1)
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
    DispatchHHHParticle("halloween_boss_axe_hit_world", effectPos, effectAng)
    util.ScreenShake(self:GetPos(), 15, 5, 1, 1000)
end

function ENT:OnInjured(dmginfo)
    self:EmitSound("Halloween.HeadlessBossPain", 95, 100)
    DispatchHHHParticle("halloween_boss_injured", dmginfo:GetDamagePosition(), self:GetAngles())
end

function ENT:FinalizeDeath(gibForce)
    if not IsValid(self) then return end
    if self.DeathFinalized then return end
    self.DeathFinalized = true

    if IsValid(self.Axe) then
        self.Axe:Remove()
    end

    DispatchHHHParticle("halloween_boss_death", self:GetPos(), self:GetAngles())
    self:EmitSound("Halloween.HeadlessBossDeath", 100, 100)

    if self.PrecacheGibs then
        pcall(self.PrecacheGibs, self)
    end
    if self.GibBreakServer then
        pcall(self.GibBreakServer, self, gibForce or vector_origin)
    end

    self:Remove()
end

function ENT:StartDeathSequence(dmginfo)
    if self.IsDying then return end
    self.IsDying = true
    self.DeathFinalized = false
    self:SetCurrentIT(nil)
    self.AttackSwinging = false
    self.AttackTarget = nil
    self.StateName = "death"
    self.StateUntil = math.huge
    self:NextThink(CurTime())

    local attacker = IsValid(dmginfo) and dmginfo:GetAttacker() or NULL
    local inflictor = IsValid(dmginfo) and dmginfo:GetInflictor() or NULL
    hook.Call("OnNPCKilled", GAMEMODE, self, attacker, inflictor)

    self:EmitSound("Halloween.HeadlessBossDying", 100, 100)
    if self.loco then
        self.loco:SetDesiredSpeed(0)
    end
    if self.SetCollisionGroup then
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
    end

    -- Match TF2: use ACT_DIESIMPLE and gib when the death activity is finished.
    local played = start_activity_safe(self, ACT_DIESIMPLE)
    if not played then
        played = play_sequence_safe(self, {
            "shake",
            "taunt_burstchester_death",
            "knight_death",
            "death",
            "die",
        })
    end
    if self.SetCycle then
        self:SetCycle(0)
    end

    local gibForce = vector_origin
    if IsValid(dmginfo) and dmginfo.GetDamageForce then
        local force = dmginfo:GetDamageForce()
        if isvector(force) then
            gibForce = force * 2
        end
    end

    self.DeathGibForce = gibForce
    self.DeathAnimStartedAt = CurTime()
    self.DeathAnimFinishAt = nil
    if played and self.SequenceDuration then
        local seqDur = tonumber(self:SequenceDuration()) or 0
        if seqDur > 0 then
            self.DeathAnimFinishAt = self.DeathAnimStartedAt + seqDur
        end
    end
end

function ENT:OnKilled(dmginfo)
    self:StartDeathSequence(dmginfo)
end

function ENT:Think()
    local cfg = self.DynamicConfig or DEFAULT_CONFIG
    local now = CurTime()
    if self.IsDying then
        local finished = false
        if self.IsActivityFinished then
            local ok, out = pcall(self.IsActivityFinished, self)
            finished = ok and out == true
        end
        if not finished and self.GetCycle and self:GetCycle() >= 0.995 then
            finished = true
        end
        if not finished and self.DeathAnimFinishAt and now >= (self.DeathAnimFinishAt + 0.05) then
            finished = true
        end
        if finished then
            self:FinalizeDeath(self.DeathGibForce)
        end
        self:NextThink(CurTime())
        return true
    end
    if self:Health() <= 0 then
        self:StartDeathSequence()
        self:NextThink(CurTime())
        return true
    end

    if self.StateName == "emerge" then
        local total = math.max(0.01, tonumber(cfg.emerge_time) or DEFAULT_CONFIG.emerge_time)
        local frac = math.Clamp(1 - ((self.StateUntil - now) / total), 0, 1)
        self:SetPos(self.HomePos - Vector(0, 0, self.EmergeHeight * (1 - frac)))
        if self.loco then
            self.loco:SetDesiredSpeed(0)
        end
        if now >= self.NextRumble then
            self.NextRumble = now + 0.25
            util.ScreenShake(self.HomePos, 15, 5, 1, 1000)
        end
        local riseDone = now >= self.StateUntil
        local animDone = false
        if self.IsActivityFinished then
            local ok, out = pcall(self.IsActivityFinished, self)
            animDone = ok and out == true
        end
        if not animDone and self.EmergeAnimFinishAt and now >= (self.EmergeAnimFinishAt + 0.05) then
            animDone = true
        end
        if riseDone and animDone then
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
        if IsValid(target) then
            self.loco:SetDesiredSpeed(tonumber(cfg.speed) or DEFAULT_CONFIG.speed)
            self.loco:FaceTowards(target:GetPos())
            if now >= self.NextFootstep and get_nextbot_speed_2d(self) > 20 then
                self.NextFootstep = now + 0.4
                self:EmitSound("Halloween.HeadlessBossFootfalls", 90, 100)
                local footPos, footAng = self:GetFootstepEffectPos()
                util.ScreenShake(footPos, 12, 4, 0.35, 700)
                DispatchHHHParticle("halloween_boss_foot_impact", footPos, footAng)
            end
            local standRange = tonumber(cfg.stand_and_swing_range) or DEFAULT_CONFIG.stand_and_swing_range
            if self:IsRangeLessThan(target, standRange) and self:IsLineOfSightClear(target) then
                if target:IsPlayer() and now >= self.NextScare then
                    self.NextScare = now + (tonumber(cfg.terrify_interval) or DEFAULT_CONFIG.terrify_interval)
                    self.BooAt = now + 0.25
                    self.ScareAt = now + 0.75
                    self.BooPlayed = false
                    self.ScareApplied = false
                    self:SetBossState("terrify", 1.25)
                    self:NextThink(CurTime())
                    return true
                end
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

if SERVER then
    concommand.Add("tf_halloween_hhh_particle_test", function(ply)
        if IsValid(ply) and ply:IsPlayer() and not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        EnsureHHHParticlesPrecached()
        local basePos = IsValid(ply) and ply:GetPos() or vector_origin
        local ang = IsValid(ply) and ply:EyeAngles() or angle_zero

        DispatchHHHParticle("halloween_boss_summon", basePos + Vector(0, 0, 8), ang)
        DispatchHHHParticle("halloween_boss_injured", basePos + Vector(24, 0, 8), ang)
        DispatchHHHParticle("halloween_boss_foot_impact", basePos + Vector(-24, 0, 0), ang)
        DispatchHHHParticle("halloween_boss_death", basePos + Vector(0, 24, 8), ang)

        hhh_particle_debug("Ran tf_halloween_hhh_particle_test at %s", tostring(basePos))
    end)
end

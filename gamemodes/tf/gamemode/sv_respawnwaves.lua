if SERVER then AddCSLuaFile("sh_respawnwaves.lua") end
include("sh_respawnwaves.lua")

local RW = TF2.RespawnWaves

-- ConVars
local cv_disable  = CreateConVar("mp_disable_respawn_times", "0", {FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE})
local cv_wave     = CreateConVar("mp_respawnwavetime", "10", {FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE})
local cv_deathcam = CreateConVar("tf_deathcam_time", "5",  {FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE})

-- Use RW team ids everywhere (they safely map to TEAM_RED/TEAM_BLU or sane defaults)
local T_RED, T_BLU = RW.TEAM_RED, RW.TEAM_BLU

-- Optional map overrides
local explicitWave = { [T_RED] = nil, [T_BLU] = nil }

-- Mode state
local modeKind = RW.MODE.DEFAULT
local kothOwner = -1
local cp_owned_by_blu = 0
local ad_blu_owned = 0
local pl_checkpoints_passed = 0
local plr_stage = 1

-- Internals
local tfteamQueues  = { [T_RED] = {}, [T_BLU] = {} }
local nextWaveIndex = { [T_RED] = 0,   [T_BLU] = 0   }
local nextWaveTime  = { [T_RED] = 0,   [T_BLU] = 0   }

-- Scaling
local function ApplyTeamSizeScaling(base, tfteam)
    local n = (team.GetPlayers and #team.GetPlayers(tfteam)) or 0
    if n <= 3 then return math.max(base, 5) end  -- clamp up to at least 5s
    if n >= 8 then return base end
    local t = (n - 3) / 5
    return 5 + t * (base - 5)
end

-- Mode wave calculators
local function KothWave(tfteam)
    if kothOwner == -1 then return 6 end
    if tfteam == kothOwner then return 9 end
    return 2
end

local function FiveCPWave(tfteam)
    local base = 10
    if tfteam == T_RED then
        local blu = cp_owned_by_blu
        if blu == 0 then return 7 end
        if blu == 1 then return 8 end
        if blu == 2 or blu == 3 then return base end
        if blu == 4 then return 9 end
        return 10
    else
        local red_owned = 5 - cp_owned_by_blu
        if red_owned == 0 then return 7 end
        if red_owned == 1 then return 8 end
        if red_owned == 2 or red_owned == 3 then return base end
        if red_owned == 4 then return 9 end
        return 10
    end
end

local function PayloadWave(tfteam)
    if tfteam == T_BLU then
        if pl_checkpoints_passed <= 0 then return 4 end
        if pl_checkpoints_passed <= 2 then return 2 end
        return 2
    else
        if pl_checkpoints_passed <= 0 then return 9 end
        if pl_checkpoints_passed <= 2 then return 10 end
        return 9
    end
end

local function DefaultWave(_) return cv_wave:GetFloat() + 5.5 end

-- Public setters
function RW.SetMode(kind) modeKind = kind or RW.MODE.DEFAULT end
function RW.SetKothOwner(owner) kothOwner = owner or -1 end
function RW.SetFiveCP_BLUOwned(n) cp_owned_by_blu = math.Clamp(tonumber(n) or 0, 0, 5) end
function RW.SetAD_BLUOwned(n) ad_blu_owned = math.max(0, tonumber(n) or 0) end
function RW.SetPL_CheckpointsPassed(n) pl_checkpoints_passed = math.max(0, tonumber(n) or 0) end
function RW.OverrideTeamWave(tfteam, seconds) explicitWave[tfteam] = seconds and math.max(0, tonumber(seconds)) or nil end
function RW.GetOverriddenTeamWave(tfteam) return explicitWave[tfteam] end

local function ComputeTeamWave(tfteam)
    if cv_disable:GetBool() then return 0 end
    if explicitWave[tfteam] ~= nil then return explicitWave[tfteam] end

    local base
    if modeKind == RW.MODE.KOTH then
        base = KothWave(tfteam)
    elseif modeKind == RW.MODE.CP_5CP then
        base = FiveCPWave(tfteam)
    elseif modeKind == RW.MODE.PL or modeKind == RW.MODE.PLR then
        base = PayloadWave(tfteam)
    elseif modeKind == RW.MODE.SD then
        base = 6
    elseif modeKind == RW.MODE.PASS then
        base = 7.5
    else
        base = DefaultWave(tfteam)
    end
    return ApplyTeamSizeScaling(base, tfteam)
end

-- Scheduler (fix: advance wave index even when waves are disabled)
local function EnsureNextWaveScheduled(tfteam)
    local now = CurTime()
    local period = ComputeTeamWave(tfteam)

    if period <= 0 then
        -- instant respawn mode: tick waves every 0.1s so assignments complete
        local nxt = nextWaveTime[tfteam]
        if nxt <= 0 then
            nextWaveTime[tfteam] = now + 0.1
            return
        end
        if now >= nxt then
            nextWaveIndex[tfteam] = nextWaveIndex[tfteam] + 1
            nextWaveTime[tfteam]  = now + 0.1
        end
        return
    end

    if nextWaveTime[tfteam] <= now then
        local cycles = math.max(1, math.ceil((now - nextWaveTime[tfteam]) / period))
        nextWaveIndex[tfteam] = nextWaveIndex[tfteam] + cycles
        nextWaveTime[tfteam]  = (nextWaveTime[tfteam] > 0 and nextWaveTime[tfteam] or now) + cycles * period
    end
end

local function AssignToNextWaveAfter(tfteam)
    EnsureNextWaveScheduled(tfteam)
    return nextWaveIndex[tfteam] + 1
end

-- Add this at the top with the other locals:

-- Modify EnqueueDeadPlayer to compute respawnAt and send it:
local function EnqueueDeadPlayer(ply)
    if not IsValid(ply) or not ply:Team() then return end
    local tfteam = ply:Team()
    if tfteam ~= TEAM_RED and tfteam ~= TEAM_BLU then return end

    local targetWave = AssignToNextWaveAfter(tfteam)
    local readyAt = CurTime() + math.max(0, cv_deathcam:GetFloat())

    local wavePeriod = ComputeTeamWave(tfteam)
    -- This is the corrected line:
    local targetWaveTime = nextWaveTime[tfteam]
    local respawnAt = math.max(targetWaveTime, readyAt)

    tfteamQueues[tfteam][ply:SteamID64() or ply:EntIndex()] = {
        ply = ply,
        readyAt = readyAt,
        targetWave = targetWave,
        respawnAt = respawnAt
    }
end

-- Modify TryProcessTeam to also print respawn messages:
local function TryProcessTeam(tfteam)
    EnsureNextWaveScheduled(tfteam)
    local waveFired = nextWaveIndex[tfteam]
    local now = CurTime()

    for k, rec in pairs(tfteamQueues[tfteam]) do
        local p = rec.ply
        if not IsValid(p) or p:Team() ~= tfteam then
            tfteamQueues[tfteam][k] = nil
        else
            if rec.targetWave <= waveFired and now >= rec.readyAt then
                -- Time to respawn
                tfteamQueues[tfteam][k] = nil
                if (!p:Alive()) then
                    p:PrintMessage(HUD_PRINTCENTER, "Prepare to respawn")
                    timer.Simple(1, function()
                        p:UnSpectate()
                        p:TF2_ForceRespawn()
                    end)
                end
            else
                -- Still waiting: show countdown messages
                local obs = p:GetObserverMode()
                if obs ~= OBS_MODE_NONE and obs ~= OBS_MODE_DEATHCAM and obs ~= OBS_MODE_FREEZECAM then
                    local remain = math.ceil((rec.respawnAt or now) - now)
                    if remain > 1 then
                        p:PrintMessage(HUD_PRINTCENTER, string.format("You will respawn in %d seconds", remain))
                    elseif (remain == 1) then
                        p:PrintMessage(HUD_PRINTCENTER, string.format("You will respawn in %d second", remain))
                    else
                        p:PrintMessage(HUD_PRINTCENTER, "Prepare to respawn")
                    end
                end
            end
        end
    end
end


-- Think loop
hook.Add("Think", "tf2_respawnwaves_tick", function()
    TryProcessTeam(T_RED)
    TryProcessTeam(T_BLU)
end)

-- Queue on death
hook.Add("PlayerDeath", "tf2_respawnwaves_ondeath", function(victim)
    timer.Simple(0, function()
        if IsValid(victim) then EnqueueDeadPlayer(victim) end
    end)
end)

-- Cleanup
hook.Add("PlayerDisconnected", "tf2_respawnwaves_discon", function(p)
    for _, q in pairs(tfteamQueues) do q[p:SteamID64() or p:EntIndex()] = nil end
end)
hook.Add("OnPlayerChangedTeam", "tf2_respawnwaves_teamchange", function(p)
    for _, q in pairs(tfteamQueues) do q[p:SteamID64() or p:EntIndex()] = nil end
end)

-- Debug
concommand.Add("tf2_dbg_respawnwaves", function(ply)
    if IsValid(ply) then return end
    print(string.format("[TF2] RED  idx=%d next=%.2f period=%.2f", nextWaveIndex[T_RED], nextWaveTime[T_RED] or 0, ComputeTeamWave(T_RED)))
    print(string.format("[TF2] BLU  idx=%d next=%.2f period=%.2f", nextWaveIndex[T_BLU], nextWaveTime[T_BLU] or 0, ComputeTeamWave(T_BLU)))
end)

-- Init (start waves immediately)

nextWaveTime[T_RED] = CurTime()
nextWaveTime[T_BLU] = CurTime()

-- Player meta
local PLAYER = FindMetaTable("Player")
function PLAYER:TF2_ForceRespawn()
    self:Spawn()
end

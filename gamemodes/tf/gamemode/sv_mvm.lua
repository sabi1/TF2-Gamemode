CreateConVar("tf_mvm_enabled", "1", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Enable POP-driven MvM runtime.")
CreateConVar("tf_mvm_autoload", "1", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Auto-load MvM mission for current map.")
CreateConVar("tf_mvm_autostart", "1", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Auto-start mission after autoload.")
CreateConVar("tf_mvm_mission_override", "", { FCVAR_ARCHIVE }, "Mission override path (.pop).")
CreateConVar("tf_mvm_external_pop_root", "C:/Program Files (x86)/Steam/steamapps/common/Team Fortress 2/tf/scripts/population", { FCVAR_ARCHIVE }, "External TF2 population root.")
CreateConVar("tf_mvm_setup_time_override", "0", { FCVAR_ARCHIVE }, "Setup duration before each wave (seconds). Set <=0 to use mission values.")
CreateConVar("tf_mvm_debug", "0", { FCVAR_ARCHIVE }, "Enable MvM runtime debug logging.")

TF_MVM = TF_MVM or {}

include("sv_mvm_mission_lookup.lua")
include("sv_mvm_pop_parser.lua")
include("sv_mvm_outputs.lua")
include("sv_mvm_spawner.lua")
include("sv_mvm_economy.lua")
include("sv_mvm_runtime.lua")

local function IsMvMMap()
    return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

local function IsAdminOrConsole(ply)
    if not IsValid(ply) then return true end
    return ply:IsAdmin()
end

local function PrintStatus(ply)
    local rt = TF_MVM.Runtime

    local lines = {
        "[TF_MVM] Status",
        "  enabled: " .. tostring(rt and rt:IsEnabled() or false),
        "  active: " .. tostring(rt and rt.Active or false),
        "  setup: " .. tostring(rt and rt.Setup or false),
        "  wave active: " .. tostring(rt and rt.WaveActive or false),
        "  wave: " .. tostring(rt and rt.WaveIndex or 0) .. "/" .. tostring((rt and rt.Mission and #rt.Mission.Waves) or 0),
        "  mission: " .. tostring((rt and rt.Mission and rt.Mission.Path) or "<none>"),
        "  scope: " .. tostring((rt and rt.Mission and rt.Mission.Scope) or "<none>"),
        "  error: " .. tostring((rt and rt.LastError) or ""),
    }

    for _, line in ipairs(lines) do
        print(line)
        if IsValid(ply) then
            ply:ChatPrint(line)
        end
    end
end

local function LoadAndMaybeStart(ply, overridePath, forceStart)
    local rt = TF_MVM.Runtime
    if not rt then return end

    local ok = rt:LoadMissionForCurrentMap(overridePath)
    if not ok then
        if IsValid(ply) then
            ply:ChatPrint("[TF_MVM] Mission load failed. See server console for searched paths.")
        end
        return
    end

    if forceStart then
        if not rt:Start() then
            if IsValid(ply) then
                ply:ChatPrint("[TF_MVM] Mission start failed.")
            end
        end
    end
end

concommand.Add("tf_mvm_start", function(ply, _, args)
    if not IsAdminOrConsole(ply) then return end
    if not TF_MVM or not TF_MVM.Runtime then return end

    local overridePath = args and args[1] or nil
    if overridePath and overridePath ~= "" then
        LoadAndMaybeStart(ply, overridePath, true)
        return
    end

    if TF_MVM.Runtime.Mission == nil then
        LoadAndMaybeStart(ply, nil, true)
        return
    end

    TF_MVM.Runtime:Start()
end)

concommand.Add("mvm_start", function(ply, _, args)
    if not IsAdminOrConsole(ply) then return end
    if not TF_MVM or not TF_MVM.Runtime then return end

    local overridePath = args and args[1] or nil
    if overridePath and overridePath ~= "" then
        LoadAndMaybeStart(ply, overridePath, true)
        return
    end

    if TF_MVM.Runtime.Mission == nil then
        LoadAndMaybeStart(ply, nil, true)
        return
    end

    TF_MVM.Runtime:Start()
end)

concommand.Add("tf_mvm_stop", function(ply)
    if not IsAdminOrConsole(ply) then return end
    if not TF_MVM or not TF_MVM.Runtime then return end

    TF_MVM.Runtime:Stop("manual_stop")
end)

concommand.Add("tf_mvm_reload_mission", function(ply)
    if not IsAdminOrConsole(ply) then return end
    if not TF_MVM or not TF_MVM.Runtime then return end

    local wasActive = TF_MVM.Runtime.Active
    if wasActive then
        TF_MVM.Runtime:Stop("reload_mission")
    end

    local ok = TF_MVM.Runtime:LoadMissionForCurrentMap()
    if ok and wasActive then
        TF_MVM.Runtime:Start()
    end
end)

concommand.Add("tf_mvm_set_mission", function(ply, _, args)
    if not IsAdminOrConsole(ply) then return end
    if not TF_MVM or not TF_MVM.Runtime then return end

    local overridePath = args and args[1] or ""
    if overridePath == "" then
        if IsValid(ply) then
            ply:ChatPrint("Usage: tf_mvm_set_mission <path-to-pop>")
        end
        return
    end

    local wasActive = TF_MVM.Runtime.Active
    if wasActive then
        TF_MVM.Runtime:Stop("set_mission")
    end

    local ok = TF_MVM.Runtime:LoadMissionForCurrentMap(overridePath)
    if ok and IsValid(ply) then
        ply:ChatPrint("[TF_MVM] Mission override loaded: " .. overridePath)
    end
    if ok and wasActive then
        TF_MVM.Runtime:Start()
    end
end)

concommand.Add("tf_mvm_status", function(ply)
    if not IsAdminOrConsole(ply) then return end
    if not TF_MVM or not TF_MVM.Runtime then return end

    PrintStatus(ply)
end)

concommand.Add("tf_mvm_ready_up", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not TF_MVM or not TF_MVM.Runtime then return end
    TF_MVM.Runtime:TogglePlayerReady(ply)
end)

concommand.Add("player_ready_toggle", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not TF_MVM or not TF_MVM.Runtime then return end
    TF_MVM.Runtime:TogglePlayerReady(ply)
end)

hook.Add("InitPostEntity", "TF_MVM_AutoloadMission", function()
    if not TF_MVM or not TF_MVM.Runtime then return end
    if not IsMvMMap() then return end

    local enabled = GetConVar("tf_mvm_enabled")
    if enabled and not enabled:GetBool() then
        return
    end

    local autoload = GetConVar("tf_mvm_autoload")
    if autoload and not autoload:GetBool() then
        return
    end

    local loaded = TF_MVM.Runtime:LoadMissionForCurrentMap()
    if not loaded then
        return
    end

    local autostart = GetConVar("tf_mvm_autostart")
    if autostart and autostart:GetBool() then
        TF_MVM.Runtime:Start()
    end
end)

hook.Add("ShutDown", "TF_MVM_ShutdownCleanup", function()
    if not TF_MVM or not TF_MVM.Runtime then return end
    TF_MVM.Runtime:Stop("shutdown")
end)

local function PlayMvMAnnouncerSound(soundName)
    if not isstring(soundName) or soundName == "" then return end
    umsg.Start("TF_PlayGlobalSound")
        umsg.String(soundName)
    umsg.End()
end

local function PlayMvMMusic(soundName)
    if not isstring(soundName) or soundName == "" then return end
    umsg.Start("TF_PlayGlobalSound")
        umsg.String(soundName)
    umsg.End()
end

local function GetWaveStartMusic(waveIndex, waveTotal)
    waveIndex = math.max(1, tonumber(waveIndex) or 1)
    waveTotal = math.max(1, tonumber(waveTotal) or 1)
    if waveIndex >= waveTotal then
        return "music.mvm_start_last_wave"
    end
    if waveIndex > 1 then
        return "music.mvm_start_mid_wave"
    end
    return "music.mvm_start_wave"
end

local function GetWaveEndMusic(waveIndex, waveTotal)
    waveIndex = math.max(1, tonumber(waveIndex) or 1)
    waveTotal = math.max(1, tonumber(waveTotal) or 1)
    if waveIndex >= waveTotal then
        return "music.mvm_end_last_wave"
    end
    if waveIndex > 1 then
        return "music.mvm_end_mid_wave"
    end
    return "music.mvm_end_wave"
end

local setupCountdownTimerName = "TF_MVM_SetupCountdownAudio"
local function StopSetupCountdownAudioTimer()
    if timer.Exists(setupCountdownTimerName) then
        timer.Remove(setupCountdownTimerName)
    end
end

hook.Add("TF_MVM_MissionStarted", "TF_MVM_Announcer_MissionStart", function()
    PlayMvMAnnouncerSound("Announcer.MVM_Manned_Up")
end)

hook.Add("TF_MVM_WaveSetupStarted", "TF_MVM_SetupCountdownAudio", function(waveIndex)
    StopSetupCountdownAudioTimer()

    local fired = {
        music10 = false,
        announce5 = false,
        announce4 = false,
        announce3 = false,
        announce2 = false,
        announce1 = false,
    }

    timer.Create(setupCountdownTimerName, 0.1, 0, function()
        local rt = TF_MVM and TF_MVM.Runtime or nil
        if not rt or not rt:IsManagedActive() or not rt:IsSetupPhase() then
            StopSetupCountdownAudioTimer()
            return
        end

        local left = math.max(0, math.ceil((rt.SetupEndTime or CurTime()) - CurTime()))
        local total = #(rt.Mission and rt.Mission.Waves or {})

        if left <= 10 and left > 0 and not fired.music10 then
            fired.music10 = true
            PlayMvMMusic(GetWaveStartMusic(waveIndex, total))
        end

        if left <= 5 and left >= 1 then
            local key = "announce" .. tostring(left)
            if not fired[key] then
                fired[key] = true
                PlayMvMAnnouncerSound("Announcer.RoundBegins" .. tostring(left) .. "Seconds")
            end
        end

        if left <= 0 then
            StopSetupCountdownAudioTimer()
        end
    end)
end)

hook.Add("TF_MVM_WaveStarted", "TF_MVM_Announcer_WaveStart", function(waveIndex)
    StopSetupCountdownAudioTimer()
    local rt = TF_MVM and TF_MVM.Runtime or nil
    local total = #(rt and rt.Mission and rt.Mission.Waves or {})
    local isFinal = total > 0 and waveIndex == total

    if waveIndex == 1 then
        PlayMvMAnnouncerSound("Announcer.MVM_First_Wave_Start")
    elseif isFinal then
        PlayMvMAnnouncerSound("Announcer.MVM_Final_Wave_Start")
    else
        PlayMvMAnnouncerSound("Announcer.MVM_Wave_Start")
    end
end)

hook.Add("TF_MVM_WaveCompleted", "TF_MVM_Announcer_WaveEnd", function(waveIndex)
    StopSetupCountdownAudioTimer()
    local rt = TF_MVM and TF_MVM.Runtime or nil
    local total = #(rt and rt.Mission and rt.Mission.Waves or {})
    local isFinal = total > 0 and waveIndex == total

    PlayMvMMusic(GetWaveEndMusic(waveIndex, total))

    if isFinal then
        PlayMvMAnnouncerSound("Announcer.MVM_Final_Wave_End")
    else
        PlayMvMAnnouncerSound("Announcer.MVM_Wave_End")
    end
end)

hook.Add("TF_MVM_MissionCompleted", "TF_MVM_Announcer_MissionComplete", function()
    PlayMvMAnnouncerSound("Announcer.MVM_All_Dead")
end)

hook.Add("TF_MVM_MissionFailed", "TF_MVM_Announcer_MissionFailed", function()
    PlayMvMAnnouncerSound("Announcer.MVM_Game_Over_Loss")
    PlayMvMMusic("music.mvm_lost_wave")
end)

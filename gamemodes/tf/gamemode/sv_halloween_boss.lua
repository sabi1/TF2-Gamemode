local MAP_SCENARIO = {
    cp_manor_event = "mann_manor",
    koth_viaduct_event = "viaduct",
    koth_lakeside_event = "lakeside",
}

local SCENARIO_BOSS_CANDIDATES = {
    mann_manor = { "headless_hatman" },
    viaduct = { "eyeball_boss" },
    lakeside = { "merasmus" },
}

local SCENARIO_SPAWN_SOUND = {
    mann_manor = "Halloween.HeadlessBossSpawn",
    viaduct = "Halloween.MonoculusBossSpawn",
    lakeside = "Halloween.MerasmusBossSpawn",
}

local SCENARIO_EVENT_TEXT = {
    mann_manor = {
        appeared = "#TF_Halloween_Boss_Appeared",
        killed = "#TF_Halloween_Boss_Killed",
        killer = "#TF_Halloween_Boss_Killers",
        escaped = "#TF_Halloween_Boss_Killed",
    },
    viaduct = {
        appeared = "#TF_Halloween_Eyeball_Boss_Appeared",
        killed = "#TF_Halloween_Eyeball_Boss_Killed",
        killer = "#TF_Halloween_Eyeball_Boss_Killers",
        stun = "#TF_Halloween_Eyeball_Boss_Stun",
        escaped = "#TF_Halloween_Eyeball_Boss_Escaped",
        warning_60 = "#TF_Halloween_Eyeball_Boss_Escaping_In_60",
        warning_30 = "#TF_Halloween_Eyeball_Boss_Escaping_In_30",
        warning_10 = "#TF_Halloween_Eyeball_Boss_Escaping_In_10",
    },
    lakeside = {
        appeared = "#TF_Halloween_Merasmus_Appeared",
        killed = "#TF_Halloween_Merasmus_Killed",
        killer = "#TF_Halloween_Merasmus_Killers",
        escaped = "#TF_Halloween_Merasmus_Escaped",
        warning_60 = "#TF_Halloween_Merasmus_Escaping_In_60",
        warning_30 = "#TF_Halloween_Merasmus_Escaping_In_30",
        warning_10 = "#TF_Halloween_Merasmus_Escaping_In_10",
    },
}

local ALL_BOSS_CLASSES = {
    headless_hatman = true,
    eyeball_boss = true,
    merasmus = true,
}

local tf_halloween_bosses_enable = CreateConVar(
    "tf_halloween_bosses_enable",
    "1",
    { FCVAR_ARCHIVE, FCVAR_NOTIFY },
    "Enable TF2-style Halloween boss spawning on Halloween boss maps."
)
local tf_halloween_boss_spawn_interval = CreateConVar(
    "tf_halloween_boss_spawn_interval",
    "480",
    { FCVAR_ARCHIVE, FCVAR_NOTIFY },
    "Average interval between Horseless Headless Horsemann spawns, in seconds."
)
local tf_halloween_boss_spawn_interval_variation = CreateConVar(
    "tf_halloween_boss_spawn_interval_variation",
    "60",
    { FCVAR_ARCHIVE, FCVAR_NOTIFY },
    "Variation of Horseless Headless Horsemann spawn interval (+/-), in seconds."
)
local tf_halloween_eyeball_boss_spawn_interval = CreateConVar(
    "tf_halloween_eyeball_boss_spawn_interval",
    "180",
    { FCVAR_ARCHIVE, FCVAR_NOTIFY },
    "Average interval between MONOCULUS spawns, in seconds."
)
local tf_halloween_eyeball_boss_spawn_interval_variation = CreateConVar(
    "tf_halloween_eyeball_boss_spawn_interval_variation",
    "30",
    { FCVAR_ARCHIVE, FCVAR_NOTIFY },
    "Variation of MONOCULUS spawn interval (+/-), in seconds."
)
local tf_merasmus_spawn_interval = CreateConVar(
    "tf_merasmus_spawn_interval",
    "180",
    { FCVAR_ARCHIVE, FCVAR_NOTIFY },
    "Average interval between Merasmus spawns, in seconds."
)
local tf_merasmus_spawn_interval_variation = CreateConVar(
    "tf_merasmus_spawn_interval_variation",
    "30",
    { FCVAR_ARCHIVE, FCVAR_NOTIFY },
    "Variation of Merasmus spawn interval (+/-), in seconds."
)
local tf_halloween_bot_min_player_count = CreateConVar(
    "tf_halloween_bot_min_player_count",
    "10",
    { FCVAR_ARCHIVE, FCVAR_NOTIFY },
    "Minimum living human RED+BLU players required before a Halloween boss can spawn."
)
local tf_eyeball_boss_lifetime = CreateConVar(
    "tf_eyeball_boss_lifetime",
    "120",
    { FCVAR_ARCHIVE, FCVAR_NOTIFY },
    "How long MONOCULUS can stay active before escaping, in seconds."
)
local tf_merasmus_lifetime = CreateConVar(
    "tf_merasmus_lifetime",
    "120",
    { FCVAR_ARCHIVE, FCVAR_NOTIFY },
    "How long Merasmus can stay active before escaping, in seconds."
)

local state = {
    timerStarted = false,
    nextSpawnAt = 0,
    forceSpawn = false,
    activeBoss = NULL,
    bossWasActive = false,
    pausedTimers = {},
    lastBossSpawnAt = 0,
    activeBossScenario = nil,
    pendingRemoval = {},
    lastAttacker = {},
    entityScenario = {},
    bossExpireAt = 0,
    warnedAt = {},
    lockedPoints = {},
    lastHudStateKey = nil,
    nextHudStateUpdate = 0,
}

util.AddNetworkString("TF_HalloweenBossEvent")
util.AddNetworkString("TF_HalloweenBossHudState")

local ResolveManagedScenarioForEnt
local FindActiveBossEntity

local function emit_sound_alias(ent, names)
    if not IsValid(ent) then return false end
    if isstring(names) then
        names = { names }
    end
    if not istable(names) then return false end
    for _, name in ipairs(names) do
        if isstring(name) and name ~= "" then
            local ok = pcall(ent.EmitSound, ent, name, 100, 100, 1, CHAN_AUTO)
            if ok then
                return true
            end
        end
    end
    return false
end

function GAMEMODE:GetIT()
    return IsValid(self.HalloweenITVictim) and self.HalloweenITVictim or NULL
end

function GAMEMODE:IsIT(ent)
    return IsValid(ent) and self:GetIT() == ent
end

function GAMEMODE:SetIT(who)
    local oldIT = IsValid(self.HalloweenITVictim) and self.HalloweenITVictim or NULL
    local newIT = IsValid(who) and who or NULL

    if IsValid(newIT) and newIT ~= oldIT then
        if newIT.PrintMessage then
            newIT:PrintMessage(HUD_PRINTTALK, "#TF_HALLOWEEN_BOSS_WARN_VICTIM")
            newIT:PrintMessage(HUD_PRINTCENTER, "#TF_HALLOWEEN_BOSS_WARN_VICTIM")
        end
        emit_sound_alias(newIT, { "Player.YouAreIT", "Player.YouAreIt" })
        emit_sound_alias(newIT, "Halloween.PlayerScream")

        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsPlayer() and ply ~= newIT then
                emit_sound_alias(ply, { "Player.IsNowIT", "Player.IsNowIt" })
            end
        end
    end

    if IsValid(oldIT) and oldIT ~= newIT and oldIT:Alive() then
        emit_sound_alias(oldIT, { "Player.TaggedOtherIT", "Player.TaggedOtherIt" })
        if oldIT.PrintMessage then
            oldIT:PrintMessage(HUD_PRINTTALK, "#TF_HALLOWEEN_BOSS_LOST_AGGRO")
            oldIT:PrintMessage(HUD_PRINTCENTER, "#TF_HALLOWEEN_BOSS_LOST_AGGRO")
        end
    end

    self.HalloweenITVictim = newIT
    hook.Run("TF_HalloweenITChanged", oldIT, newIT)
end

local function GetScenario()
    local map = string.lower(game.GetMap() or "")
    return MAP_SCENARIO[map]
end

local function GetScenarioInterval(scenario)
    if scenario == "mann_manor" then
        return math.max(1, tf_halloween_boss_spawn_interval:GetFloat()),
            math.max(0, tf_halloween_boss_spawn_interval_variation:GetFloat())
    end
    if scenario == "viaduct" then
        return math.max(1, tf_halloween_eyeball_boss_spawn_interval:GetFloat()),
            math.max(0, tf_halloween_eyeball_boss_spawn_interval_variation:GetFloat())
    end
    if scenario == "lakeside" then
        return math.max(1, tf_merasmus_spawn_interval:GetFloat()),
            math.max(0, tf_merasmus_spawn_interval_variation:GetFloat())
    end
    return 0, 0
end

local function StartTimer(interval, variation)
    local delay = interval + math.Rand(-variation, variation)
    state.nextSpawnAt = CurTime() + math.max(0.1, delay)
    state.timerStarted = true
end

local function StartInitialTimer(scenario, interval, variation)
    -- TF2 behavior: Lakeside initial spawn uses regular timer; other scenarios use shorter random start.
    if scenario == "lakeside" then
        StartTimer(interval, variation)
        return
    end

    local delay = 0.5 * math.Rand(0, interval + variation)
    state.nextSpawnAt = CurTime() + math.max(0.1, delay)
    state.timerStarted = true
end

local function IsSetupOrWaitingForPlayers()
    if GAMEMODE and GAMEMODE.IsSetupPhase then
        return true
    end

    for _, timerEnt in ipairs(ents.FindByClass("team_round_timer")) do
        if IsValid(timerEnt) and timerEnt.WaitingForPlayers then
            return true
        end
    end

    return false
end

local function CountLivingHumans()
    local total = 0
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply)
            and ply:IsPlayer()
            and ply:Alive()
            and (ply:Team() == TEAM_RED or ply:Team() == TEAM_BLU)
        then
            total = total + 1
        end
    end
    return total
end

local function GetPointEntities()
    local points = ents.FindByClass("team_control_point")
    if #points == 0 then
        points = ents.FindByClass("tf_team_control_point")
    end
    return points
end

local function BlueCanCapture(point)
    if not IsValid(point) then return false end
    if point.Locked then return false end

    local trigger = point.TriggerEntity
    if IsValid(trigger) and trigger.Properties then
        local canCapBlue = trigger.Properties.team_cancap_3
        if tonumber(canCapBlue) == 0 then
            return false
        end
    end

    if istable(point.TeamCanCap) then
        local canCap = point.TeamCanCap[TEAM_BLU]
        if canCap == false or canCap == 0 then
            return false
        end
    end

    return true
end

local function FindContestedPoint()
    local points = GetPointEntities()
    table.sort(points, function(a, b)
        local aId = tonumber(a.ID or (a.Properties and a.Properties.point_index) or 0) or 0
        local bId = tonumber(b.ID or (b.Properties and b.Properties.point_index) or 0) or 0
        return aId < bId
    end)

    for _, point in ipairs(points) do
        if not IsValid(point) then continue end
        if point.GetOwnerTeam and point:GetOwnerTeam() == TEAM_BLU then continue end
        if not BlueCanCapture(point) then continue end
        return point
    end
    return nil
end

local function FindSpawnPosition()
    local custom = ents.FindByClass("spawn_boss")[1]
    if IsValid(custom) then
        return custom:GetPos(), nil
    end

    local contested = FindContestedPoint()
    if IsValid(contested) then
        return contested:GetPos(), contested
    end

    if navmesh and navmesh.IsLoaded and navmesh.IsLoaded() and navmesh.GetAllNavAreas then
        local candidates = {}
        for _, area in ipairs(navmesh.GetAllNavAreas()) do
            if not area or not area.GetCenter then continue end
            local center = area:GetCenter()
            if not isvector(center) then continue end
            candidates[#candidates + 1] = area
        end

        if #candidates > 0 then
            local pick = table.Random(candidates)
            return pick:GetCenter() + Vector(0, 0, 8), nil
        end
    end

    local spawns = ents.FindByClass("info_player_teamspawn")
    if #spawns > 0 then
        local pick = table.Random(spawns)
        if IsValid(pick) then
            return pick:GetPos() + Vector(0, 0, 16), nil
        end
    end

    return Vector(0, 0, 64), nil
end

local function PauseKothTeamTimers()
    state.pausedTimers = {}

    for _, timerEnt in ipairs(ents.FindByClass("team_round_timer")) do
        if not IsValid(timerEnt) then continue end
        if timerEnt.PauseTimer == nil then continue end
        if timerEnt.TimerPaused ~= nil then continue end

        local props = timerEnt.Properties or {}
        local teamNum = tonumber(props.teamnum or props.team)
        if teamNum ~= TEAM_RED and teamNum ~= TEAM_BLU then
            continue
        end

        local t = timerEnt.GetTime and timerEnt:GetTime() or 0
        state.pausedTimers[timerEnt:EntIndex()] = t
        timerEnt:PauseTimer()
    end
end

local function ResumeKothTeamTimers()
    if not istable(state.pausedTimers) then return end

    for entIndex, pausedTime in pairs(state.pausedTimers) do
        local timerEnt = Entity(tonumber(entIndex) or -1)
        if not IsValid(timerEnt) then continue end

        if timerEnt.SetAndResumeTimer then
            timerEnt:SetAndResumeTimer(tonumber(pausedTime) or 0)
        elseif timerEnt.ResumeTimer then
            timerEnt:ResumeTimer()
        end
    end

    state.pausedTimers = {}
end

local function GetPointID(point)
    if not IsValid(point) then return nil end
    return tonumber(point.ID or (point.Properties and point.Properties.point_index))
end

local function GetLinkedControlPoints()
    local points = {}
    for _, point in ipairs(GetPointEntities()) do
        if not IsValid(point) then continue end
        if not IsValid(point.TriggerEntity) then continue end
        points[#points + 1] = point
    end
    return points
end

local function SetLakesideBossTruceActive(active)
    GAMEMODE.HalloweenBossTruceActive = active and true or false

    local shouldLock = active and true or false
    if shouldLock then
        state.lockedPoints = {}
        for _, point in ipairs(GetLinkedControlPoints()) do
            state.lockedPoints[point:EntIndex()] = point.Locked and true or false
            if point.SetLocked then
                point:SetLocked(true)
            end
        end
    else
        for _, point in ipairs(GetLinkedControlPoints()) do
            local wasLocked = state.lockedPoints[point:EntIndex()]
            if wasLocked ~= nil then
                if point.SetLocked then
                    point:SetLocked(wasLocked and true or false)
                end
            end
        end
        state.lockedPoints = {}

        local master = ents.FindByClass("team_control_point_master")[1]
        if IsValid(master) and master.UpdateControlPoints then
            master:UpdateControlPoints()
        end
    end
end

local function BuildBossHudState()
    local boss = IsValid(state.activeBoss) and state.activeBoss or FindActiveBossEntity()
    local scenario = ResolveManagedScenarioForEnt(boss) or state.activeBossScenario or GetScenario() or ""
    local truceActive = scenario == "lakeside" and IsValid(boss) and true or false

    if not IsValid(boss) then
        return {
            active = false,
            entIndex = -1,
            scenario = scenario,
            health = 0,
            maxHealth = 0,
            truceActive = truceActive,
        }
    end

    local maxHealth = 0
    if boss.GetMaxHealth then
        maxHealth = tonumber(boss:GetMaxHealth() or 0) or 0
    end
    if maxHealth <= 0 then
        maxHealth = tonumber(boss:Health() or 0) or 0
    end

    return {
        active = true,
        entIndex = boss:EntIndex(),
        scenario = scenario,
        health = math.max(0, tonumber(boss:Health() or 0) or 0),
        maxHealth = math.max(0, maxHealth),
        truceActive = truceActive,
    }
end

local function BroadcastBossHudState(recipient, force)
    local hudState = BuildBossHudState()
    local stateKey = table.concat({
        hudState.active and 1 or 0,
        hudState.entIndex,
        hudState.scenario,
        hudState.health,
        hudState.maxHealth,
        hudState.truceActive and 1 or 0,
    }, ":")

    if not recipient and not force and state.lastHudStateKey == stateKey and CurTime() < (state.nextHudStateUpdate or 0) then
        return
    end

    if not recipient then
        state.lastHudStateKey = stateKey
        state.nextHudStateUpdate = CurTime() + 0.15
    end

    net.Start("TF_HalloweenBossHudState")
        net.WriteBool(hudState.active)
        net.WriteInt(hudState.entIndex, 16)
        net.WriteString(hudState.scenario or "")
        net.WriteInt(hudState.health or 0, 32)
        net.WriteInt(hudState.maxHealth or 0, 32)
        net.WriteBool(hudState.truceActive and true or false)
    if recipient then
        net.Send(recipient)
    else
        net.Broadcast()
    end
end

local function NeutralizePoint(point)
    if not IsValid(point) then return end

    if point.SetOwnerTeam then
        point:SetOwnerTeam(0)
        return
    end

    if point.AcceptInput then
        point:AcceptInput("SetOwner", nil, nil, "0")
    end
end

FindActiveBossEntity = function()
    for className, _ in pairs(ALL_BOSS_CLASSES) do
        for _, ent in ipairs(ents.FindByClass(className)) do
            if IsValid(ent) then
                return ent
            end
        end
    end

    return nil
end

local function SpawnBossEntity(scenario, pos)
    local candidates = SCENARIO_BOSS_CANDIDATES[scenario] or {}
    for _, className in ipairs(candidates) do
        local ent = ents.Create(className)
        if not IsValid(ent) then continue end

        ent:SetPos(pos + Vector(0, 0, 16))
        ent:SetAngles(Angle(0, math.random(0, 359), 0))
        ent:Spawn()
        ent:Activate()

        if IsValid(ent) then
            ent.TF_HalloweenBossScenario = scenario
            return ent, className
        end
    end

    return nil, nil
end

local function EmitBossSpawnAnnouncement(scenario)
    local snd = SCENARIO_SPAWN_SOUND[scenario]
    if not snd or snd == "" then return end

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsPlayer() then
            ply:EmitSound(snd, 100, 100, 1, CHAN_AUTO)
        end
    end
end

local function EmitBossTextEvent(eventName, scenario, playerName, secondsRemaining)
    local byScenario = SCENARIO_EVENT_TEXT[scenario] or {}
    local textToken = ""
    if eventName == "warning" then
        local warningKey = "warning_" .. tostring(math.max(0, math.floor(tonumber(secondsRemaining) or 0)))
        textToken = byScenario[warningKey] or ""
    else
        textToken = byScenario[eventName] or ""
    end
    if textToken == "" then return end

    net.Start("TF_HalloweenBossEvent")
        net.WriteString(eventName or "")
        net.WriteString(scenario or "")
        net.WriteString(textToken)
        net.WriteString(tostring(playerName or ""))
        net.WriteUInt(math.max(0, math.floor(tonumber(secondsRemaining) or 0)), 16)
    net.Broadcast()
end

local function ShouldPauseForScenario(scenario)
    return scenario == "viaduct" or scenario == "lakeside"
end

local function ShouldNeutralizeForScenario(scenario)
    return scenario == "viaduct"
end

local function SpawnScenarioBoss(scenario)
    local pos, contestedPoint = FindSpawnPosition()
    local ent = SpawnBossEntity(scenario, pos)
    if not IsValid(ent) then
        print(string.format("[TF2-Gamemode] Failed to spawn Halloween boss for scenario '%s'.", tostring(scenario)))
        return false
    end

    state.activeBoss = ent
    state.activeBossScenario = scenario
    state.lastBossSpawnAt = CurTime()
    state.entityScenario[ent:EntIndex()] = scenario
    state.warnedAt = {}
    if scenario == "viaduct" then
        state.bossExpireAt = CurTime() + math.max(1, tf_eyeball_boss_lifetime:GetFloat())
    elseif scenario == "lakeside" then
        state.bossExpireAt = CurTime() + math.max(1, tf_merasmus_lifetime:GetFloat())
    else
        state.bossExpireAt = 0
    end
    EmitBossSpawnAnnouncement(scenario)
    EmitBossTextEvent("appeared", scenario, "")
    hook.Run("TF_HalloweenBossSpawned", ent, scenario)

    if IsValid(contestedPoint) and ShouldNeutralizeForScenario(scenario) then
        NeutralizePoint(contestedPoint)
    end
    if ShouldPauseForScenario(scenario) then
        PauseKothTeamTimers()
    end
    SetLakesideBossTruceActive(scenario == "lakeside")
    BroadcastBossHudState(nil, true)

    return true
end

local function IsManagedBossClass(className)
    return className and ALL_BOSS_CLASSES[className] == true
end

ResolveManagedScenarioForEnt = function(ent)
    if not IsValid(ent) then return nil end
    local cached = state.entityScenario[ent:EntIndex()]
    if isstring(cached) and cached ~= "" then
        return cached
    end
    if isstring(ent.TF_HalloweenBossScenario) and ent.TF_HalloweenBossScenario ~= "" then
        return ent.TF_HalloweenBossScenario
    end
    return state.activeBossScenario
end

local function EmitBossKilledForEnt(ent, attacker)
    if not IsValid(ent) then return end
    local scenario = ResolveManagedScenarioForEnt(ent)
    if not scenario then return end

    local killerName = ""
    if IsValid(attacker) and attacker:IsPlayer() then
        killerName = attacker:Nick()
    end

    EmitBossTextEvent("killed", scenario, "")
    if killerName ~= "" then
        EmitBossTextEvent("killer", scenario, killerName)
    end
end

local function EmitBossEscapedForEnt(ent)
    if not IsValid(ent) then return end
    local scenario = ResolveManagedScenarioForEnt(ent)
    if not scenario then return end
    EmitBossTextEvent("escaped", scenario, "")
end

local function EmitBossStunForEnt(ent, attacker)
    if not IsValid(ent) then return end
    local scenario = ResolveManagedScenarioForEnt(ent)
    if scenario ~= "viaduct" then return end

    local playerName = ""
    if IsValid(attacker) and attacker:IsPlayer() then
        playerName = attacker:Nick()
    end
    if playerName == "" then return end

    EmitBossTextEvent("stun", scenario, playerName)
end

local function EmitBossEscapeWarning(scenario, secondsRemaining)
    if not scenario then return end
    EmitBossTextEvent("warning", scenario, "", secondsRemaining)
end

local function IsLakesideWheelBlockingSpawn()
    local scenario = GetScenario()
    if scenario ~= "lakeside" then return false end

    local wheel = ents.FindByClass("wheel_of_doom")[1]
    if not IsValid(wheel) then return false end
    if not wheel.IsDoneBoardcastingEffectSound then return false end
    return not wheel:IsDoneBoardcastingEffectSound()
end

local function RunBossScheduler()
    local scenario = GetScenario()
    if not scenario then
        if next(state.pausedTimers) ~= nil then
            ResumeKothTeamTimers()
        end
        SetLakesideBossTruceActive(false)
        BroadcastBossHudState(nil, true)
        state.activeBoss = NULL
        state.activeBossScenario = nil
        return
    end
    if not tf_halloween_bosses_enable:GetBool() then return end

    local interval, variation = GetScenarioInterval(scenario)
    if interval <= 0 then return end

    local active = FindActiveBossEntity()
    if IsValid(active) then
        -- TF2 behavior: while a boss is active, keep re-arming the timer.
        StartTimer(interval, variation)
        state.bossWasActive = true
        state.activeBoss = active
        state.activeBossScenario = ResolveManagedScenarioForEnt(active) or scenario
        if state.activeBossScenario == "viaduct" and state.bossExpireAt <= 0 then
            state.bossExpireAt = CurTime() + math.max(1, tf_eyeball_boss_lifetime:GetFloat())
            state.warnedAt = {}
        elseif state.activeBossScenario == "lakeside" and state.bossExpireAt <= 0 then
            state.bossExpireAt = CurTime() + math.max(1, tf_merasmus_lifetime:GetFloat())
            state.warnedAt = {}
        end

        if state.bossExpireAt > 0 then
            local remaining = state.bossExpireAt - CurTime()
            if remaining <= 10 and not state.warnedAt[10] then
                state.warnedAt[10] = true
                EmitBossEscapeWarning(state.activeBossScenario, 10)
            elseif remaining <= 30 and not state.warnedAt[30] then
                state.warnedAt[30] = true
                EmitBossEscapeWarning(state.activeBossScenario, 30)
            elseif remaining <= 60 and not state.warnedAt[60] then
                state.warnedAt[60] = true
                EmitBossEscapeWarning(state.activeBossScenario, 60)
            end

            if remaining <= 0 and IsValid(active) then
                active:Remove()
                return
            end
        end
        state.forceSpawn = false
        SetLakesideBossTruceActive(state.activeBossScenario == "lakeside")
        BroadcastBossHudState(nil, false)
        return
    end

    if state.bossWasActive then
        state.bossWasActive = false
    end

    if IsValid(state.activeBoss) or next(state.pausedTimers) ~= nil then
        state.activeBoss = NULL
        ResumeKothTeamTimers()
        SetLakesideBossTruceActive(false)
        state.bossExpireAt = 0
        state.warnedAt = {}
        BroadcastBossHudState(nil, true)
    end

    if not state.timerStarted and not state.forceSpawn then
        StartInitialTimer(scenario, interval, variation)
        return
    end

    if not state.forceSpawn and CurTime() < state.nextSpawnAt then
        return
    end

    if not state.forceSpawn then
        if IsSetupOrWaitingForPlayers() then return end
        if IsLakesideWheelBlockingSpawn() then return end
        if CountLivingHumans() < math.max(0, tf_halloween_bot_min_player_count:GetInt()) then
            return
        end
    end

    local ok = SpawnScenarioBoss(scenario)
    if ok then
        StartTimer(interval, variation)
    end
    state.forceSpawn = false
end

local function ResetState()
    state.timerStarted = false
    state.nextSpawnAt = 0
    state.forceSpawn = false
    state.activeBoss = NULL
    state.bossWasActive = false
    state.pausedTimers = {}
    state.activeBossScenario = nil
    state.pendingRemoval = {}
    state.lastAttacker = {}
    state.entityScenario = {}
    state.bossExpireAt = 0
    state.warnedAt = {}
    state.lockedPoints = {}
    state.lastHudStateKey = nil
    state.nextHudStateUpdate = 0
    GAMEMODE.HalloweenBossTruceActive = false
    GAMEMODE.HalloweenITVictim = NULL
    BroadcastBossHudState(nil, true)
end

hook.Add("InitPostEntity", "TF_HalloweenBoss_ResetInit", ResetState)
hook.Add("PostCleanupMap", "TF_HalloweenBoss_ResetCleanup", ResetState)
hook.Add("Think", "TF_HalloweenBoss_Scheduler", RunBossScheduler)

hook.Add("OnNPCKilled", "TF_HalloweenBoss_KilledNPC", function(victim, attacker)
    if not IsValid(victim) then return end
    if not IsManagedBossClass(victim:GetClass()) then return end
    if state.pendingRemoval[victim:EntIndex()] then return end

    state.entityScenario[victim:EntIndex()] = ResolveManagedScenarioForEnt(victim) or state.activeBossScenario
    state.pendingRemoval[victim:EntIndex()] = "killed"
    EmitBossKilledForEnt(victim, attacker)
end)

hook.Add("EntityTakeDamage", "TF_HalloweenBoss_RecordAttacker", function(target, dmginfo)
    if not IsValid(target) then return end
    if not IsManagedBossClass(target:GetClass()) then return end
    if not dmginfo then return end

    local attacker = dmginfo:GetAttacker()
    if IsValid(attacker) then
        state.lastAttacker[target:EntIndex()] = attacker
    end
end)

hook.Add("EntityRemoved", "TF_HalloweenBoss_EntityRemoved", function(ent)
    if ent == nil then return end
    if not IsManagedBossClass(ent:GetClass()) then return end

    local idx = ent:EntIndex()
    if not state.entityScenario[idx] and isstring(ent.TF_HalloweenBossScenario) and ent.TF_HalloweenBossScenario ~= "" then
        state.entityScenario[idx] = ent.TF_HalloweenBossScenario
    end
    local why = state.pendingRemoval[idx]
    local attacker = state.lastAttacker[idx]
    state.pendingRemoval[idx] = nil
    state.lastAttacker[idx] = nil

    if why == "killed" then
        return
    end

    local hp = tonumber(ent:Health() or 0) or 0
    if hp <= 0 then
        EmitBossKilledForEnt(ent, attacker)
    else
        -- Any non-kill removal is treated as escape/depart for parity messaging.
        EmitBossEscapedForEnt(ent)
    end

    state.entityScenario[idx] = nil
    if state.activeBoss == ent then
        state.activeBoss = NULL
        state.bossExpireAt = 0
        state.warnedAt = {}
    end
    BroadcastBossHudState(nil, true)
end)

hook.Add("TF_HalloweenBossStunned", "TF_HalloweenBoss_OnStunned", function(ent, attacker)
    if not IsValid(ent) then return end
    if not IsManagedBossClass(ent:GetClass()) then return end
    EmitBossStunForEnt(ent, attacker)
end)

hook.Add("EntityTakeDamage", "TF_HalloweenBoss_LakesideTruce", function(target, dmginfo)
    if not GAMEMODE.HalloweenBossTruceActive then return end
    if not dmginfo then return end

    local attacker = dmginfo:GetAttacker()
    if not IsValid(target) or not IsValid(attacker) then return end

    local targetIsBoss = target.GetClass and ALL_BOSS_CLASSES[target:GetClass()] == true
    local attackerIsBoss = attacker.GetClass and ALL_BOSS_CLASSES[attacker:GetClass()] == true
    if targetIsBoss or attackerIsBoss then
        return
    end

    if IsValid(attacker:GetOwner()) then
        local owner = attacker:GetOwner()
        if IsValid(owner) and owner ~= attacker then
            attacker = owner
            attackerIsBoss = attacker.GetClass and ALL_BOSS_CLASSES[attacker:GetClass()] == true
            if attackerIsBoss then
                return
            end
        end
    end

    local attackerTeam = GAMEMODE:EntityTeam(attacker)
    local targetTeam = GAMEMODE:EntityTeam(target)
    local gameplayAttacker = attackerTeam == TEAM_RED or attackerTeam == TEAM_BLU
    local gameplayTarget = targetTeam == TEAM_RED or targetTeam == TEAM_BLU
    if not gameplayAttacker or not gameplayTarget then return end
    if attackerTeam == targetTeam then return end

    dmginfo:SetDamage(0)
    dmginfo:SetDamageType(DMG_GENERIC)
    dmginfo:SetAttacker(game.GetWorld())
end)

local function SyncHalloweenBossStateToPlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    BroadcastBossHudState(ply, true)
end

hook.Add("PlayerInitialSpawn", "TF_HalloweenBossHudSync_InitialSpawn", function(ply)
    timer.Simple(1.0, function()
        SyncHalloweenBossStateToPlayer(ply)
    end)
end)

hook.Add("PlayerSpawn", "TF_HalloweenBossHudSync_Spawn", function(ply)
    timer.Simple(0.25, function()
        SyncHalloweenBossStateToPlayer(ply)
    end)
end)

concommand.Add("tf_halloween_force_boss_spawn", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    state.forceSpawn = true
    RunBossScheduler()
end)

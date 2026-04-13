TF_MVM = TF_MVM or {}

local RUNTIME = {}
TF_MVM.Runtime = RUNTIME

RUNTIME.Enabled = false
RUNTIME.Active = false
RUNTIME.Setup = false
RUNTIME.WaveActive = false
RUNTIME.WaveIndex = 0
RUNTIME.Mission = nil
RUNTIME.ManagedBots = {}
RUNTIME.ManagedTanks = {}
RUNTIME.ManagedEntities = {}
RUNTIME.CurrentWaveState = nil
RUNTIME.SpawnStatesByName = {}
RUNTIME.CurrentMissionStates = {}
RUNTIME.TimerNames = {}
RUNTIME.LastError = ""
RUNTIME.PendingSetupDuration = nil
RUNTIME.LastWaveStatusHash = ""
RUNTIME.ReadyPlayers = {}
RUNTIME.SetupInitialDuration = 0
RUNTIME.SetupWaitingTimerDuration = nil
RUNTIME.SetupReadyCountdownTotal = nil
RUNTIME.BotSpawningPaused = false
RUNTIME.DefaultEventChangeAttributesName = ""

local READY_COUNTDOWN_START = 150
local READY_COUNTDOWN_PARTIAL_MIN = 30
local READY_COUNTDOWN_ALL_READY = 10
local cv_sentrybuster_kills = CreateConVar("tf_mvm_sentry_buster_kills", "15", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Defender sentry kills in one sentry life required before a Sentry Buster can spawn.")

local function ToArray(v)
    if v == nil then return {} end
    if istable(v) and v[1] ~= nil then return v end
    return { v }
end

local function ScalarValue(v)
    if istable(v) then
        return v[1] or select(2, next(v))
    end
    return v
end

local function NumValue(v, fallback)
    local n = tonumber(ScalarValue(v))
    if n == nil then
        return fallback
    end
    return n
end

local function IsMvMMap()
    if TF_IsMvMMap then
        return TF_IsMvMMap()
    end
    return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

local function IsReadyEligiblePlayer(ply)
    return IsValid(ply)
        and ply:IsPlayer()
        and not ply:IsBot()
        and not ply.TFBot
        and ply:Team() == TEAM_RED
end

local READY_SOUND_COOLDOWN = 4
local READY_CLASS_SOUND = {
    scout = "scout.ReadyMvM",
    soldier = "soldier.ReadyMvM",
    pyro = "pyro.ReadyMvM",
    demoman = "demoman.ReadyMvM",
    demo = "demoman.ReadyMvM",
    heavy = "heavy.ReadyMvM",
    heavyweapons = "heavy.ReadyMvM",
    engineer = "engineer.ReadyMvM",
    engi = "engineer.ReadyMvM",
    medic = "medic.ReadyMvM",
    sniper = "sniper.ReadyMvM",
    spy = "spy.ReadyMvM",
}

local function GetPlayerReadyClassSound(ply)
    local cls = string.lower(tostring(IsValid(ply) and ply.GetPlayerClass and ply:GetPlayerClass() or "scout"))
    return READY_CLASS_SOUND[cls] or READY_CLASS_SOUND.scout
end

local function DebugEnabled()
    local c = GetConVar("tf_mvm_debug")
    return c and c:GetBool()
end

local function DebugPrint(...)
    if not DebugEnabled() then return end
    print("[TF_MVM][Runtime]", ...)
end

local function SpawnCurrencyPack(className, pos, amount)
    if amount <= 0 then return nil end
    local ent = ents.Create(className)
    if not IsValid(ent) then return nil end

    ent:SetPos(pos)
    ent:SetAngles(Angle(0, math.random(0, 360), 0))
    ent.CurrencyAmount = math.max(1, math.floor(amount))
    ent:SetRespawnTime(-1)
    ent:Spawn()
    ent:Activate()
    ent:DropWithGravity(VectorRand() * 120 + Vector(0, 0, 140))

    return ent
end

local function DropCurrencyPacks(origin, totalAmount)
    local total = math.max(0, math.floor(tonumber(totalAmount) or 0))
    if total <= 0 then return end

    local pos = origin + Vector(0, 0, 16)
    local remaining = total

    while remaining > 0 do
        local className = "item_currencypack_small"
        local packAmount = remaining

        if remaining >= 100 then
            className = "item_currencypack_large"
            packAmount = 100
        elseif remaining >= 50 then
            className = "item_currencypack_medium"
            packAmount = 50
        elseif remaining > 25 then
            className = "item_currencypack_small"
            packAmount = 25
        end

        SpawnCurrencyPack(className, pos + VectorRand() * 12, packAmount)
        remaining = remaining - packAmount
    end
end

local function TimerName(tag)
    return "TF_MVM_" .. tag
end

local function RemoveTimer(name)
    if timer.Exists(name) then
        timer.Remove(name)
    end
end

local function AddTimerRef(self, name)
    self.TimerNames[name] = true
end

local function TrimLower(s)
    s = ScalarValue(s)
    return string.lower(string.Trim(tostring(s or "")))
end

local function BoolValue(v, fallback)
    local lower = TrimLower(v)
    if lower == "" then
        return fallback and true or false
    end
    if lower == "0" or lower == "false" or lower == "no" or lower == "off" then
        return false
    end
    if lower == "1" or lower == "true" or lower == "yes" or lower == "on" then
        return true
    end
    return true
end

local function HasMiniBossAttr(def)
    if not istable(def) then return false end
    for _, attr in ipairs(ToArray(def.Attributes or def.attributes)) do
        local lower = TrimLower(attr)
        if lower == "mini-boss" or lower == "miniboss" then
            return true
        end
    end
    return false
end

local function ClassAlias(name)
    local lower = TrimLower(name)
    if lower == "demoman" then return "demo" end
    if lower == "heavyweapons" then return "heavy" end
    return lower
end

local function IsSentryBusterObjective(objective)
    local o = TrimLower(objective)
    return o == "destroysentries" or o == "sentrybuster"
end

local function ResolveSentryFromKillSources(attacker, inflictor)
    local function asSentry(ent)
        if not IsValid(ent) then return nil end
        return (ent:GetClass() == "obj_sentrygun") and ent or nil
    end

    local sentry = asSentry(attacker) or asSentry(inflictor)
    if sentry then return sentry end

    if IsValid(attacker) and attacker.GetOwner then
        sentry = asSentry(attacker:GetOwner())
        if sentry then return sentry end
    end
    if IsValid(inflictor) and inflictor.GetOwner then
        sentry = asSentry(inflictor:GetOwner())
        if sentry then return sentry end
    end
    return nil
end

local function RemoveManagedBotEntity(ent, reason)
    if not IsValid(ent) then return end
    if ent.IsPlayer and ent:IsPlayer() then
        ent:Kick(reason or "MvM bot removed")
        return
    end
    ent.TF_MVM_SilentRemove = true
    ent:Remove()
end

local function CreateManagedSquad(def)
    return {
        Id = "mvm_squad_" .. tostring(CurTime()) .. "_" .. tostring(math.random(1000, 9999)),
        FormationSize = math.max(0, tonumber(def and (def.FormationSize or def.formationsize)) or 0),
        ShouldPreserveSquad = BoolValue(def and (def.ShouldPreserveSquad or def.shouldpreservesquad), false),
        Members = {},
    }
end

local function AttachBotToManagedSquad(bot, squad)
    if not IsValid(bot) or not squad then return end

    squad.Members[bot] = true
    bot.TF_MVM_Squad = squad
    bot.IsInASquad = function(self)
        return istable(self.TF_MVM_Squad) and next(self.TF_MVM_Squad.Members or {}) ~= nil
    end
    bot.GetSquadFormationSize = function(self)
        return tonumber(self.TF_MVM_Squad and self.TF_MVM_Squad.FormationSize) or 0
    end
    bot.ShouldPreserveSquad = function(self)
        return self.TF_MVM_Squad and self.TF_MVM_Squad.ShouldPreserveSquad == true or false
    end
end

local function DetachBotFromManagedSquad(bot)
    if not IsValid(bot) then return end
    local squad = bot.TF_MVM_Squad
    if not istable(squad) then
        bot.TF_MVM_Squad = nil
        return
    end

    squad.Members[bot] = nil
    if next(squad.Members or {}) == nil then
        squad.Members = {}
    end
    bot.TF_MVM_Squad = nil
end

local function ReadIconName(def)
    if not istable(def) then return "" end
    local raw = def.ClassIcon or def.classicon or def.Icon or def.icon or ""
    raw = string.Trim(tostring(ScalarValue(raw) or ""))
    return raw
end

local function ResolveBotDefForRuntime(runtime, def)
    if not istable(def) then return def end
    if runtime and TF_MVM and TF_MVM.Spawner and TF_MVM.Spawner.BuildBotDef then
        return TF_MVM.Spawner:BuildBotDef(runtime, def)
    end
    return def
end

local OBJECTIVE_STATUS_CLASS = {
    spy = "spy",
    sniper = "sniper",
    destroysentries = "sentry_buster",
    sentrybuster = "sentry_buster",
}

local function PickRepresentativeBotDef(spawnDef)
    if not istable(spawnDef) then return nil end
    if spawnDef.TFBot then
        return ToArray(spawnDef.TFBot)[1]
    end
    if spawnDef.Squad then
        local first = ToArray(spawnDef.Squad)[1]
        if istable(first) and first.TFBot then
            return ToArray(first.TFBot)[1]
        end
        return first
    end
    if spawnDef.RandomChoice then
        local firstChoice = ToArray(spawnDef.RandomChoice)[1]
        if istable(firstChoice) then
            if firstChoice.TFBot then
                return ToArray(firstChoice.TFBot)[1]
            end
            if firstChoice.Squad then
                return ToArray(firstChoice.Squad)[1]
            end
        end
    end
    return nil
end

local function BuildSpawnVisualInfo(spawnDef)
    if not istable(spawnDef) then
        return { class = "scout", giant = false, tank = false, icon = "" }
    end
    if spawnDef.Tank then
        return { class = "tank", giant = true, tank = true, icon = "" }
    end
    if spawnDef.SentryGun then
        return { class = "sentry", giant = false, tank = false, icon = ReadIconName(spawnDef) }
    end
    if spawnDef.Mob then
        local firstMob = ToArray(spawnDef.Mob)[1]
        if istable(firstMob) then
            return BuildSpawnVisualInfo(firstMob)
        end
    end

    local botDef = PickRepresentativeBotDef(spawnDef)
    local className = ClassAlias((istable(botDef) and (botDef.Class or botDef.class)) or spawnDef.Class or spawnDef.class or "scout")
    if className == "" then
        className = "scout"
    end

    local giant = HasMiniBossAttr(spawnDef) or HasMiniBossAttr(botDef)
    local icon = ReadIconName(botDef)
    if icon == "" then
        icon = ReadIconName(spawnDef)
    end
    return { class = className, giant = giant, tank = false, icon = icon }
end

local function PickRepresentativeMissionBotDef(missionDef, runtime)
    if not istable(missionDef) then return nil end
    local def = ResolveBotDefForRuntime(runtime, missionDef)
    local botDef = PickRepresentativeBotDef(def)
    if not istable(botDef) then return nil end
    return ResolveBotDefForRuntime(runtime, botDef)
end

local function BuildSpawnVisualInfos(spawnDef, runtime)
    if not istable(spawnDef) then
        return { { class = "scout", giant = false, tank = false, icon = "", weight = 1 } }
    end
    if spawnDef.Tank then
        return { { class = "tank", giant = true, tank = true, icon = "", weight = 1 } }
    end
    if spawnDef.SentryGun then
        return { { class = "sentry", giant = false, tank = false, icon = ReadIconName(spawnDef), weight = 1 } }
    end

    local grouped = {}
    local ordered = {}

    local function addInfo(className, giant, tank, icon, weight)
        className = ClassAlias(className)
        if className == "" then
            className = "scout"
        end
        icon = string.Trim(tostring(icon or ""))
        local key = string.format("%s|%d|%d|%s", className, giant and 1 or 0, tank and 1 or 0, icon)
        local node = grouped[key]
        if not node then
            node = {
                class = className,
                giant = giant and true or false,
                tank = tank and true or false,
                icon = icon,
                weight = 0,
            }
            grouped[key] = node
            ordered[#ordered + 1] = node
        end
        if node.icon == "" and icon ~= "" then
            node.icon = icon
        end
        node.weight = node.weight + math.max(1, math.floor(tonumber(weight) or 1))
    end

    local function addBotDef(botDef)
        if not istable(botDef) then return end
        if runtime and TF_MVM and TF_MVM.Spawner and TF_MVM.Spawner.BuildBotDef then
            botDef = TF_MVM.Spawner:BuildBotDef(runtime, botDef)
        end
        local icon = ReadIconName(botDef)
        if icon == "" then
            icon = ReadIconName(spawnDef)
        end
        addInfo(
            botDef.Class or botDef.class or spawnDef.Class or spawnDef.class or "scout",
            HasMiniBossAttr(spawnDef) or HasMiniBossAttr(botDef),
            false,
            icon,
            NumValue(botDef.Count or botDef.count, 1)
        )
    end

    local function walk(def)
        if not istable(def) then return end
        if runtime and TF_MVM and TF_MVM.Spawner and TF_MVM.Spawner.BuildBotDef then
            def = TF_MVM.Spawner:BuildBotDef(runtime, def)
        end
        if def.Tank then
            addInfo("tank", true, true, "", 1)
            return
        end
        if def.SentryGun then
            addInfo("sentry", false, false, ReadIconName(def), 1)
            return
        end
        if def.Mob then
            for _, member in ipairs(ToArray(def.Mob)) do
                walk(member)
            end
            return
        end
        if def.TFBot then
            for _, botDef in ipairs(ToArray(def.TFBot)) do
                addBotDef(botDef)
            end
            return
        end
        if def.Squad then
            for _, member in ipairs(ToArray(def.Squad)) do
                if istable(member) and member.TFBot then
                    for _, botDef in ipairs(ToArray(member.TFBot)) do
                        addBotDef(botDef)
                    end
                else
                    addBotDef(member)
                end
            end
            return
        end
        if def.RandomChoice then
            for _, choice in ipairs(ToArray(def.RandomChoice)) do
                walk(choice)
            end
            return
        end

        -- Fallback for unusual defs with only Class on the spawn.
        addInfo(def.Class or def.class or spawnDef.Class or spawnDef.class or "scout", HasMiniBossAttr(def), false, ReadIconName(def), 1)
    end

    walk(spawnDef)

    if #ordered == 0 then
        local info = BuildSpawnVisualInfo(spawnDef)
        return {
            {
                class = info.class,
                giant = info.giant,
                tank = info.tank,
                icon = info.icon,
                weight = 1,
            }
        }
    end

    return ordered
end

local function ResolveSupportDisplayCountFromSpawnDef(spawnDef)
    if not istable(spawnDef) then return 0 end

    local supportMode = TrimLower(spawnDef.Support or spawnDef.support)
    local limitedSupport = supportMode == "limited"
    if limitedSupport then
        return math.max(0, math.floor(NumValue(spawnDef.TotalCount or spawnDef.totalcount, NumValue(spawnDef.MaxActive or spawnDef.maxactive, NumValue(spawnDef.SpawnCount or spawnDef.spawncount, 1))) or 0))
    end

    return math.max(0, math.floor(NumValue(spawnDef.DesiredCount or spawnDef.desiredcount, NumValue(spawnDef.MaxActive or spawnDef.maxactive, NumValue(spawnDef.SpawnCount or spawnDef.spawncount, 1))) or 0))
end

local function ResolveSupportDisplayCountFromSpawnState(spawnState)
    if not istable(spawnState) then return 0 end
    if spawnState.SupportLimited then
        local remaining = math.max(0, (tonumber(spawnState.TotalCount) or 0) - (tonumber(spawnState.Spawned) or 0) + (tonumber(spawnState.Alive) or 0))
        return math.floor(remaining)
    end
    return math.max(0, math.floor(tonumber(spawnState.MaxActive) or tonumber(spawnState.SpawnCount) or 0))
end

local function BuildMissionVisualInfo(missionDef, runtime)
    if not istable(missionDef) then
        return nil
    end

    local resolvedMissionDef = ResolveBotDefForRuntime(runtime, missionDef)
    local missionBotDef = PickRepresentativeMissionBotDef(resolvedMissionDef, runtime)

    local icon = ReadIconName(missionBotDef)
    if icon == "" then
        icon = ReadIconName(resolvedMissionDef)
    end

    local explicitClass = ClassAlias(resolvedMissionDef.Class or resolvedMissionDef.class or "")
    if explicitClass == "" and istable(missionBotDef) then
        explicitClass = ClassAlias(missionBotDef.Class or missionBotDef.class or "")
    end

    if explicitClass ~= "" then
        return { class = explicitClass, giant = false, tank = false, icon = icon }
    end

    local objective = TrimLower(resolvedMissionDef.Objective or resolvedMissionDef.objective or "")
    if objective == "" and icon == "" then
        -- Invalid/empty mission definitions should not create fallback scout support icons.
        return nil
    end
    local cls = OBJECTIVE_STATUS_CLASS[objective] or "scout"
    return { class = cls, giant = false, tank = false, icon = icon }
end

local function ResolveMissionDisplayCount(missionDef)
    local desired = NumValue(missionDef and (missionDef.DesiredCount or missionDef.desiredcount or missionDef.Count or missionDef.count), 1)
    return math.max(0, math.floor(desired or 0))
end

local function MissionAppliesToWave(missionDef, waveIndex, totalWaves, isGlobal)
    local beginDefault = isGlobal and 1 or waveIndex
    local begin = math.max(1, math.floor(NumValue(missionDef.BeginAtWave or missionDef.beginatwave, beginDefault) or beginDefault))
    local runDefault = isGlobal and math.max(1, totalWaves - begin + 1) or 1
    local runCount = math.max(1, math.floor(NumValue(missionDef.RunForThisManyWaves or missionDef.runforthismanywaves, runDefault) or runDefault))
    local finish = begin + runCount - 1
    return waveIndex >= begin and waveIndex <= finish
end

local function GetRoundTimers()
    local out = {}
    for _, ent in ipairs(ents.FindByClass("team_round_timer")) do
        if IsValid(ent) then
            out[#out + 1] = ent
        end
    end
    return out
end

local function EnsureRoundTimerExists()
    local timers = GetRoundTimers()
    if #timers > 0 then
        return timers
    end

    local rt = ents.Create("team_round_timer")
    if not IsValid(rt) then
        return {}
    end

    rt.Properties = rt.Properties or {}
    rt.Properties.start_paused = 1
    rt.Properties.timer_length = 90
    rt.Properties.max_length = 90
    rt.Properties.auto_countdown = 1
    rt.Properties.show_in_hud = 1

    rt:SetPos(vector_origin)
    rt:Spawn()
    rt:Activate()

    return GetRoundTimers()
end

function RUNTIME:IsEnabled()
    local c = GetConVar("tf_mvm_enabled")
    if c and not c:GetBool() then
        return false
    end
    return true
end

function RUNTIME:IsManagedActive()
    return self.Active == true
end

function RUNTIME:IsBotSpawningPaused()
    return self.BotSpawningPaused == true
end

function RUNTIME:PauseSpawning()
    self.BotSpawningPaused = true
end

function RUNTIME:UnpauseSpawning()
    self.BotSpawningPaused = false
end

function RUNTIME:SetDefaultEventChangeAttributesName(name)
    self.DefaultEventChangeAttributesName = string.Trim(string.lower(tostring(name or "")))
end

function RUNTIME:GetDefaultEventChangeAttributesName()
    return self.DefaultEventChangeAttributesName or ""
end

function RUNTIME:IsSetupPhase()
    return self.Setup == true
end

function RUNTIME:IsWaveInProgress()
    return self.WaveActive == true
end

function RUNTIME:GetReadyCounts()
    if not self.Active or not self.Setup then
        return 0, 0
    end

    local total = 0
    local ready = 0
    for _, ply in ipairs(player.GetAll()) do
        if IsReadyEligiblePlayer(ply) then
            total = total + 1
            if self.ReadyPlayers[ply] then
                ready = ready + 1
            end
        end
    end

    return ready, total
end

function RUNTIME:ResetReadyPlayers()
    self.ReadyPlayers = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsPlayer() then
            ply:SetNWBool("TF_MVM_Ready", false)
        end
    end
end

function RUNTIME:StartWaveFromSetup(reason)
    if not self.Active or not self.Setup then return false end

    local nextWave = math.max(1, (tonumber(self.WaveIndex) or 0) + 1)
    local setupTimer = TimerName("SetupStartWave")
    RemoveTimer(setupTimer)
    self.TimerNames[setupTimer] = nil

    self:StartWave(nextWave)
    hook.Run("TF_MVM_SetupEndedEarly", nextWave, reason or "manual")
    return true
end

function RUNTIME:GetMinPlayersToStart()
    local c = GetConVar("tf_mvm_min_players_to_start")
    local n = c and c:GetInt() or 1
    return math.max(1, n)
end

function RUNTIME:GetReadyCountdownDuration(readyCount, totalCount)
    readyCount = math.max(0, tonumber(readyCount) or 0)
    totalCount = math.max(0, tonumber(totalCount) or 0)

    local effectiveTotal = math.max(1, tonumber(self.SetupReadyCountdownTotal) or totalCount)
    if effectiveTotal <= 0 then
        return nil
    end

    if readyCount <= 0 then
        return nil
    end

    if readyCount >= effectiveTotal then
        return READY_COUNTDOWN_ALL_READY
    end

    local span = math.max(1, effectiveTotal - 1)
    local t = math.Clamp((readyCount - 1) / span, 0, 1)
    local duration = math.Round(READY_COUNTDOWN_START + ((READY_COUNTDOWN_PARTIAL_MIN - READY_COUNTDOWN_START) * t))
    return math.Clamp(duration, READY_COUNTDOWN_PARTIAL_MIN, READY_COUNTDOWN_START)
end

function RUNTIME:RecomputeSetupCountdown()
    if not self.Active or not self.Setup then
        return false
    end

    local readyCount, totalCount = self:GetReadyCounts()
    local minPlayers = self:GetMinPlayersToStart()
    local changed = false
    local now = CurTime()
    local currentEnd = tonumber(self.SetupEndTime) or 0

    if currentEnd <= 0 then
        if totalCount < minPlayers or readyCount <= 0 then
            self.SetupReadyCountdownTotal = nil
            if self.SetupEndTime and self.SetupEndTime > 0 then
                self.SetupEndTime = 0
                changed = true
            end
            local pausedDuration = math.max(0, math.floor(tonumber(self.SetupInitialDuration) or 0))
            if self.SetupWaitingTimerDuration ~= pausedDuration then
                self:ApplyRoundTimerSetup(pausedDuration, true)
                self.SetupWaitingTimerDuration = pausedDuration
            end
            return changed
        end

        -- TF2 ready mode: once a player readies and min player gate is met, start the long countdown.
        self.SetupReadyCountdownTotal = math.max(minPlayers, totalCount)
        local desired = self:GetReadyCountdownDuration(readyCount, totalCount) or READY_COUNTDOWN_START
        local desiredRemaining = math.max(0, desired)
        self.SetupEndTime = now + desiredRemaining
        self:ApplyRoundTimerSetup(math.max(0, math.ceil(desiredRemaining)), false)
        self.SetupWaitingTimerDuration = nil
        return true
    end

    self.SetupWaitingTimerDuration = nil
    if now >= currentEnd then
        self:StartWaveFromSetup("countdown")
        return true
    end

    -- TF2 behavior: more players ready can only shorten the active countdown, never lengthen it.
    local desired = self:GetReadyCountdownDuration(readyCount, totalCount)
    if desired ~= nil then
        local desiredRemaining = math.max(0, desired)
        local currentRemaining = math.max(0, currentEnd - now)
        if desiredRemaining < (currentRemaining - 0.2) then
            self.SetupEndTime = now + desiredRemaining
            self:ApplyRoundTimerSetup(math.max(0, math.ceil(desiredRemaining)), false)
            changed = true
        end
    end

    return changed
end

function RUNTIME:SetPlayerReady(ply, ready)
    if not self.Active or not self.Setup then return false, "not_in_setup" end
    if not IsReadyEligiblePlayer(ply) then return false, "not_eligible" end

    ready = ready and true or false
    if ready then
        self.ReadyPlayers[ply] = true
    else
        self.ReadyPlayers[ply] = nil
    end
    ply:SetNWBool("TF_MVM_Ready", ready)
    self:PushState()

    local readyCount, totalCount = self:GetReadyCounts()
    hook.Run("TF_MVM_PlayerReadyStateChanged", ply, ready, readyCount, totalCount)

    if self:RecomputeSetupCountdown() then
        self:PushState()
    end

    return true
end

function RUNTIME:PlayPlayerReadySound(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    local now = CurTime()
    ply.TF_MVM_LastReadySoundAt = tonumber(ply.TF_MVM_LastReadySoundAt) or 0
    if ply.TF_MVM_LastReadySoundAt > now then
        return false
    end

    local snd = GetPlayerReadyClassSound(ply)
    for _, listener in ipairs(player.GetAll()) do
        if not IsValid(listener) then continue end
        local t = listener:Team()
        if t == ply:Team() or t == TEAM_SPECTATOR then
            listener:EmitSound(snd, 75, 100, 1, CHAN_AUTO)
        end
    end
    ply.TF_MVM_LastReadySoundAt = now + READY_SOUND_COOLDOWN
    return true
end

function RUNTIME:IsReadyToggleLocked()
    if not self.Active or not self.Setup then return false end
    local setupEnd = tonumber(self.SetupEndTime) or 0
    if setupEnd <= 0 then return false end
    return (setupEnd - CurTime()) <= 10
end

function RUNTIME:TogglePlayerReady(ply)
    if self:IsReadyToggleLocked() then
        -- TF2 behavior: during final countdown, F4 still plays class ready voice
        -- but does not change the ready state.
        self:PlayPlayerReadySound(ply)
        return false, "ready_locked_final_countdown"
    end

    local isReady = self.ReadyPlayers[ply] and true or false
    local nextReady = not isReady
    local ok, reason = self:SetPlayerReady(ply, nextReady)
    if ok and nextReady then
        self:PlayPlayerReadySound(ply)
    end
    return ok, reason
end

function RUNTIME:PushState()
    if not TF_MVMState or not TF_MVMState.Set then return end

    local isEndless = BoolValue(self.Mission and self.Mission.IsEndless, false)
    local eventPopfile = tostring(self.Mission and self.Mission.EventPopfile or "")

    TF_MVMState:Set("enabled", self:IsEnabled())
    TF_MVMState:Set("active", self.Active)
    TF_MVMState:Set("in_setup", self.Setup)
    TF_MVMState:Set("wave_active", self.WaveActive)
    TF_MVMState:Set("wave_current", math.max(0, self.WaveIndex))
    TF_MVMState:Set("wave_total", self.Mission and #self.Mission.Waves or 0)
    TF_MVMState:Set("is_endless", isEndless)
    TF_MVMState:Set("event_popfile", eventPopfile)
    TF_MVMState:Set("mission_name", self.Mission and (self.Mission.Path or "") or "")
    TF_MVMState:Set("error", self.LastError or "")
    local readyCount, readyTotal = self:GetReadyCounts()
    TF_MVMState:Set("ready_count", readyCount)
    TF_MVMState:Set("ready_total", readyTotal)

    if self.Setup and self.SetupEndTime then
        TF_MVMState:Set("setup_end_time", self.SetupEndTime)
    else
        TF_MVMState:Set("setup_end_time", 0)
    end
end

function RUNTIME:SetError(msg)
    self.LastError = tostring(msg or "")
    self:PushState()
end

function RUNTIME:GetSentryBusterKillThreshold()
    local missionOverride = self.Mission and tonumber(self.Mission.AddSentryBusterWhenKillCountExceeds) or nil
    if missionOverride and missionOverride > 0 then
        return math.max(1, math.floor(missionOverride))
    end

    local n = cv_sentrybuster_kills and cv_sentrybuster_kills:GetInt() or 15
    return math.max(1, n)
end

function RUNTIME:GetSentryBusterDamageThreshold()
    local missionOverride = self.Mission and tonumber(self.Mission.AddSentryBusterWhenDamageDealtExceeds) or nil
    if missionOverride and missionOverride > 0 then
        return math.max(1, math.floor(missionOverride))
    end
    return nil
end

function RUNTIME:GetSentryBusterKillTimeThreshold()
    local missionOverride = self.Mission and tonumber(self.Mission.AddSentryBusterWhenKillTimeExceeds) or nil
    if missionOverride and missionOverride > 0 then
        return missionOverride
    end
    return nil
end

function RUNTIME:ResetSentryBusterState()
    self.SentryBusterKillsBySentry = {}
    self.SentryBusterDamageBySentry = {}
    self.SentryBusterKillWindowStartBySentry = {}
    self.SentryBusterPendingByBuilder = {}
    self.SentryBusterCooldownUntil = 0
    self.SentryBusterKillsSinceLastSpawn = 0
    self.SentryBustersSpawnedThisWave = 0
end

function RUNTIME:EnsureSentryBusterState()
    self.SentryBusterKillsBySentry = self.SentryBusterKillsBySentry or {}
    self.SentryBusterDamageBySentry = self.SentryBusterDamageBySentry or {}
    self.SentryBusterKillWindowStartBySentry = self.SentryBusterKillWindowStartBySentry or {}
    self.SentryBusterPendingByBuilder = self.SentryBusterPendingByBuilder or {}
    self.SentryBusterCooldownUntil = tonumber(self.SentryBusterCooldownUntil) or 0
    self.SentryBusterKillsSinceLastSpawn = tonumber(self.SentryBusterKillsSinceLastSpawn) or 0
    self.SentryBustersSpawnedThisWave = tonumber(self.SentryBustersSpawnedThisWave) or 0
end

function RUNTIME:ComputeMissionRespawnWaveTime(waveNumber)
    local respawn = self.Mission and tonumber(self.Mission.RespawnWaveTime) or nil
    if respawn == nil or respawn < 0 then
        return nil
    end

    local waveNum = math.max(1, math.floor(tonumber(waveNumber) or 1))
    if BoolValue(self.Mission and self.Mission.IsEndless, false) then
        return waveNum / 3
    end

    if BoolValue(self.Mission and self.Mission.FixedRespawnWaveTime, false) then
        return respawn
    end

    return math.min(respawn, waveNum * 2)
end

function RUNTIME:ApplyMissionRespawnWaveSetting(waveNumber)
    if not TF2 or not TF2.RespawnWaves or not TF2.RespawnWaves.OverrideTeamWave then
        return
    end

    local respawn = self:ComputeMissionRespawnWaveTime(waveNumber or self.WaveIndex)
    if respawn ~= nil then
        TF2.RespawnWaves.OverrideTeamWave(TEAM_RED, respawn)
    end
end

function RUNTIME:ApplyMissionPresentationState()
    local isEndless = BoolValue(self.Mission and self.Mission.IsEndless, false)
    local eventPopfile = tostring(self.Mission and self.Mission.EventPopfile or "")

    SetGlobalBool("TF_MVM_IsEndless", isEndless)
    SetGlobalString("TF_MVM_EventPopfile", eventPopfile)
end

function RUNTIME:ClearMissionPresentationState()
    SetGlobalBool("TF_MVM_IsEndless", false)
    SetGlobalString("TF_MVM_EventPopfile", "")
end

function RUNTIME:ClearMissionRespawnWaveSetting()
    if not TF2 or not TF2.RespawnWaves or not TF2.RespawnWaves.OverrideTeamWave then
        return
    end

    TF2.RespawnWaves.OverrideTeamWave(TEAM_RED, nil)
end

function RUNTIME:MakeAuxiliarySpawnState(id, def)
    return {
        Id = tostring(id or "aux"),
        Name = tostring(id or "aux"),
        Def = def or {},
        Support = false,
        SupportLimited = false,
        InfiniteSupport = false,
        TotalCount = 0,
        Spawned = 0,
        Alive = 0,
        CompletedSpawned = false,
        CompletedDead = false,
        SelectorState = { index = 0 },
        RandomSpawn = BoolValue(def and (def.RandomSpawn or def.randomspawn), true),
        FixedSpawnEnt = nil,
    }
end

function RUNTIME:SpawnAuxiliaryDef(def, spawnState, fixedSpawnEnt)
    if not TF_MVM or not TF_MVM.Spawner then
        return false
    end

    local tempState = spawnState or self:MakeAuxiliarySpawnState("aux", def)
    local ok, spawnedAny = false, false
    local fixedSpawnPos = spawnState and spawnState.FixedSpawnPos or nil

    local function spawnNode(node)
        if not istable(node) then
            return false
        end

        if node.RandomChoice then
            local choice = table.Random(ToArray(node.RandomChoice))
            return spawnNode(choice)
        end

        if node.Squad then
            local any = false
            for _, member in ipairs(ToArray(node.Squad)) do
                if spawnNode(member) then
                    any = true
                end
            end
            return any
        end

        if node.Mob then
            local mobNode = table.Random(ToArray(node.Mob))
            return spawnNode(mobNode)
        end

        if node.Tank then
            local tankDef = table.Random(ToArray(node.Tank))
            local tank = TF_MVM.Spawner:SpawnTank(self, tankDef, tempState, fixedSpawnEnt, tempState.SelectorState, tempState.RandomSpawn, fixedSpawnPos)
            return IsValid(tank)
        end

        if node.SentryGun then
            local sentryDef = table.Random(ToArray(node.SentryGun))
            local sentry = TF_MVM.Spawner:SpawnSentryGun(self, sentryDef, tempState, fixedSpawnEnt, tempState.SelectorState, tempState.RandomSpawn, fixedSpawnPos)
            return IsValid(sentry)
        end

        local rawBotDef = node.TFBot and table.Random(ToArray(node.TFBot)) or node
        local auxWhere = def and (def.ClosestPoint or def.closestpoint or def.Where or def.where) or nil
        local bot = TF_MVM.Spawner:SpawnTFBot(self, rawBotDef, tempState, auxWhere, nil, fixedSpawnEnt, tempState.SelectorState, tempState.RandomSpawn, fixedSpawnPos)
        return IsValid(bot)
    end

    ok = spawnNode(def or {})
    spawnedAny = ok and true or false
    return spawnedAny
end

function RUNTIME:InitializeRandomPlacements()
    for idx, placementDef in ipairs(ToArray(self.Mission and self.Mission.RandomPlacements)) do
        if not istable(placementDef) then
            continue
        end

        local count = math.max(0, math.floor(NumValue(placementDef.Count or placementDef.count, 0) or 0))
        if count <= 0 then
            continue
        end

        local minSep = NumValue(placementDef.MinimumSeparation or placementDef.minimumseparation, 0) or 0
        local classHint = BuildSpawnVisualInfo(placementDef).class or "scout"
        local fixedSpawns = {}
        local fixedPositions = {}
        if TF_MVM.Spawner and placementDef.NavAreaFilter and TF_MVM.Spawner.PickSeparatedNavAreaPositions then
            fixedPositions = TF_MVM.Spawner:PickSeparatedNavAreaPositions(placementDef.NavAreaFilter, count, minSep)
        elseif TF_MVM.Spawner and TF_MVM.Spawner.PickSeparatedSpawnEntities then
            fixedSpawns = TF_MVM.Spawner:PickSeparatedSpawnEntities(placementDef.Where or placementDef.ClosestPoint, classHint, count, minSep)
        end

        local auxState = self:MakeAuxiliarySpawnState(string.format("randomplacement_%d", idx), placementDef)
        if #fixedSpawns > 0 then
            for _, spawnEnt in ipairs(fixedSpawns) do
                auxState.FixedSpawnPos = nil
                self:SpawnAuxiliaryDef(placementDef, auxState, spawnEnt)
            end
        elseif #fixedPositions > 0 then
            for _, spawnPos in ipairs(fixedPositions) do
                auxState.FixedSpawnPos = spawnPos
                self:SpawnAuxiliaryDef(placementDef, auxState, nil)
            end
            auxState.FixedSpawnPos = nil
        else
            for _ = 1, count do
                auxState.FixedSpawnPos = nil
                self:SpawnAuxiliaryDef(placementDef, auxState, nil)
            end
        end
    end
end

function RUNTIME:SchedulePeriodicSpawns()
    for idx, periodicDef in ipairs(ToArray(self.Mission and self.Mission.PeriodicSpawns)) do
        if not istable(periodicDef) then
            continue
        end

        local whenDef = periodicDef.When
        local minInterval = NumValue((istable(whenDef) and (whenDef.MinInterval or whenDef.mininterval)) or periodicDef.MinInterval, nil)
        local maxInterval = NumValue((istable(whenDef) and (whenDef.MaxInterval or whenDef.maxinterval)) or periodicDef.MaxInterval, minInterval)
        local intervalMin = math.max(0.1, tonumber(minInterval) or 30)
        local intervalMax = math.max(intervalMin, tonumber(maxInterval) or intervalMin)
        local timerName = TimerName(string.format("PeriodicSpawn_%d", idx))
        local auxState = self:MakeAuxiliarySpawnState(string.format("periodicspawn_%d", idx), periodicDef)

        local function scheduleNext()
            if not self.Active then
                RemoveTimer(timerName)
                self.TimerNames[timerName] = nil
                return
            end

            local delay = math.Rand(intervalMin, intervalMax)
            timer.Create(timerName, delay, 1, function()
                if not self.Active then
                    self.TimerNames[timerName] = nil
                    return
                end
                if self.WaveActive and not self:IsBotSpawningPaused() then
                    self:SpawnAuxiliaryDef(periodicDef, auxState, nil)
                end
                scheduleNext()
            end)
        end

        AddTimerRef(self, timerName)
        scheduleNext()
    end
end

function RUNTIME:GetActiveSentryBusterCountForTarget(targetSentry)
    if not IsValid(targetSentry) then return 0 end
    local n = 0
    for bot, info in pairs(self.ManagedBots or {}) do
        if not IsValid(bot) then continue end
        local objective = (info and info.objective) or self:GetManagedBotObjective(bot)
        if not IsSentryBusterObjective(objective) then continue end
        local botTarget = IsValid(bot.TF_MVM_SentryTarget) and bot.TF_MVM_SentryTarget or bot:GetNWEntity("TF_MVM_SentryTarget")
        if IsValid(botTarget) and botTarget == targetSentry then
            n = n + 1
        end
    end
    return n
end

function RUNTIME:OnSentryBusterSpawned(baseCooldown)
    self:EnsureSentryBusterState()
    local base = math.max(0, tonumber(baseCooldown) or 0)
    local mult = 1 + math.max(0, math.floor(self.SentryBusterKillsSinceLastSpawn or 0))
    self.SentryBusterCooldownUntil = CurTime() + (base * mult)
    self.SentryBusterKillsSinceLastSpawn = 0
    self.SentryBustersSpawnedThisWave = (self.SentryBustersSpawnedThisWave or 0) + 1

    if isfunction(BroadcastSound) then
        if self.SentryBustersSpawnedThisWave > 1 then
            BroadcastSound("Announcer.MVM_Sentry_Buster_Alert_Another")
        else
            BroadcastSound("Announcer.MVM_Sentry_Buster_Alert")
        end
    end
end

function RUNTIME:OnSentryBusterKilled()
    self:EnsureSentryBusterState()
    self.SentryBusterKillsSinceLastSpawn = (self.SentryBusterKillsSinceLastSpawn or 0) + 1
end

function RUNTIME:GetSentryBusterTargetData()
    self:EnsureSentryBusterState()
    if CurTime() < (self.SentryBusterCooldownUntil or 0) then
        return nil
    end
    local best = nil
    for _, sentry in ipairs(ents.FindByClass("obj_sentrygun")) do
        if not IsValid(sentry) then continue end
        if sentry:Team() ~= TEAM_RED then continue end
        local builder = IsValid(sentry:GetBuilder()) and sentry:GetBuilder() or nil
        if not IsValid(builder) then continue end
        local pending = tonumber(self.SentryBusterPendingByBuilder[builder]) or 0
        if pending <= 0 then continue end
        if self:GetActiveSentryBusterCountForTarget(sentry) > 0 then continue end
        local kills = tonumber(self.SentryBusterKillsBySentry[sentry]) or 0
        if not best or kills > best.kills then
            best = { sentry = sentry, builder = builder, kills = kills }
        end
    end
    return best
end

function RUNTIME:HasEligibleSentryBusterTarget()
    return self:GetSentryBusterTargetData() ~= nil
end

function RUNTIME:ConsumeSentryBusterTarget()
    local data = self:GetSentryBusterTargetData()
    if not data then return nil end
    local pending = tonumber(self.SentryBusterPendingByBuilder[data.builder]) or 0
    self.SentryBusterPendingByBuilder[data.builder] = math.max(0, pending - 1)
    self.SentryBusterKillsBySentry[data.sentry] = 0
    return data
end

function RUNTIME:OnDefenderSentryKill(sentry, victim)
    if not self:IsManagedActive() or not self:IsWaveInProgress() then return end
    if not IsValid(sentry) or sentry:GetClass() ~= "obj_sentrygun" then return end
    if sentry:Team() ~= TEAM_RED then return end
    if not IsValid(victim) then return end
    if victim:IsPlayer() then
        local vt = victim:Team()
        if vt ~= TEAM_BLU and vt ~= TF_TEAM_PVE_INVADERS then return end
    end

    self:EnsureSentryBusterState()
    local builder = IsValid(sentry:GetBuilder()) and sentry:GetBuilder() or nil
    if not IsValid(builder) then return end

    local killTimeThreshold = self:GetSentryBusterKillTimeThreshold()
    if killTimeThreshold and killTimeThreshold > 0 then
        local firstKillAt = tonumber(self.SentryBusterKillWindowStartBySentry[sentry]) or 0
        if firstKillAt <= 0 then
            self.SentryBusterKillWindowStartBySentry[sentry] = CurTime()
        end
    end

    local kills = (tonumber(self.SentryBusterKillsBySentry[sentry]) or 0) + 1
    self.SentryBusterKillsBySentry[sentry] = kills
    if kills >= self:GetSentryBusterKillThreshold() then
        self.SentryBusterPendingByBuilder[builder] = (tonumber(self.SentryBusterPendingByBuilder[builder]) or 0) + 1
        self.SentryBusterKillsBySentry[sentry] = 0
        self.SentryBusterKillWindowStartBySentry[sentry] = 0
    end
end

function RUNTIME:OnDefenderSentryDamage(sentry, victim, damage)
    if not self:IsManagedActive() or not self:IsWaveInProgress() then return end
    if not IsValid(sentry) or sentry:GetClass() ~= "obj_sentrygun" then return end
    if sentry:Team() ~= TEAM_RED then return end
    if not IsValid(victim) then return end

    local amount = math.max(0, tonumber(damage) or 0)
    if amount <= 0 then return end

    if victim:IsPlayer() then
        local vt = victim:Team()
        if vt ~= TEAM_BLU and vt ~= TF_TEAM_PVE_INVADERS then return end
    end

    local threshold = self:GetSentryBusterDamageThreshold()
    if not threshold or threshold <= 0 then return end

    self:EnsureSentryBusterState()
    local builder = IsValid(sentry:GetBuilder()) and sentry:GetBuilder() or nil
    if not IsValid(builder) then return end

    local total = (tonumber(self.SentryBusterDamageBySentry[sentry]) or 0) + amount
    self.SentryBusterDamageBySentry[sentry] = total
    if total >= threshold then
        self.SentryBusterPendingByBuilder[builder] = (tonumber(self.SentryBusterPendingByBuilder[builder]) or 0) + 1
        self.SentryBusterDamageBySentry[sentry] = 0
        self.SentryBusterKillsBySentry[sentry] = 0
        self.SentryBusterKillWindowStartBySentry[sentry] = 0
    end
end

function RUNTIME:UpdateSentryBusterKillTimeThreshold(now)
    local threshold = self:GetSentryBusterKillTimeThreshold()
    if not threshold or threshold <= 0 then
        return
    end

    self:EnsureSentryBusterState()
    for _, sentry in ipairs(ents.FindByClass("obj_sentrygun")) do
        if not IsValid(sentry) or sentry:Team() ~= TEAM_RED then
            continue
        end

        local firstKillAt = tonumber(self.SentryBusterKillWindowStartBySentry[sentry]) or 0
        if firstKillAt <= 0 then
            continue
        end

        local builder = IsValid(sentry:GetBuilder()) and sentry:GetBuilder() or nil
        if not IsValid(builder) then
            continue
        end

        if (now - firstKillAt) >= threshold then
            self.SentryBusterPendingByBuilder[builder] = math.max(1, tonumber(self.SentryBusterPendingByBuilder[builder]) or 0)
            self.SentryBusterKillsBySentry[sentry] = 0
            self.SentryBusterDamageBySentry[sentry] = 0
            self.SentryBusterKillWindowStartBySentry[sentry] = 0
        end
    end
end

local function BuildStatusHash(entries)
    local parts = {}
    for _, e in ipairs(entries or {}) do
        parts[#parts + 1] = string.format(
            "%s|%d|%d|%d|%d|%d|%d|%d|%s",
            tostring(e.class or "scout"),
            tonumber(e.count or 0) or 0,
            e.support and 1 or 0,
            e.giant and 1 or 0,
            e.tank and 1 or 0,
            e.mission and 1 or 0,
            e.active and 1 or 0,
            e.support_limited and 1 or 0,
            tostring(e.icon or "")
        )
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

local function BuildStatusFromItems(items)
    local grouped = {}
    local ordered = {}

    local function addItem(info, count, support, mission, active, supportLimited)
        local icon = string.Trim(tostring((info and info.icon) or ""))
        local key = string.format(
            "%s|%d|%d|%d|%d|%d|%s",
            tostring(info.class or "scout"),
            info.giant and 1 or 0,
            info.tank and 1 or 0,
            support and 1 or 0,
            mission and 1 or 0,
            supportLimited and 1 or 0,
            icon
        )
        local node = grouped[key]
        if not node then
            node = {
                class = info.class or "scout",
                giant = info.giant and true or false,
                tank = info.tank and true or false,
                icon = icon,
                support = support and true or false,
                mission = mission and true or false,
                active = active and true or false,
                support_limited = supportLimited and true or false,
                count = 0,
            }
            grouped[key] = node
            ordered[#ordered + 1] = node
        end
        if active then
            node.active = true
        end
        node.count = node.count + math.max(0, math.floor(tonumber(count) or 0))
    end

    for _, item in ipairs(items or {}) do
        addItem(item.info or {}, item.count or 0, item.support, item.mission, item.active, item.support_limited)
    end

    table.sort(ordered, function(a, b)
        if a.support ~= b.support then
            return not a.support
        end
        if a.mission ~= b.mission then
            return not a.mission
        end
        if a.tank ~= b.tank then
            return a.tank
        end
        if a.giant ~= b.giant then
            return a.giant
        end
        return tostring(a.class) < tostring(b.class)
    end)

    return ordered, BuildStatusHash(ordered)
end

function RUNTIME:BuildWaveMissionStatusItemsFromDefs(wave, waveIndex)
    if not self.Mission then return {} end

    local missionBlocks = {}
    for _, missionDef in ipairs(ToArray(self.Mission.GlobalMissions)) do
        missionBlocks[#missionBlocks + 1] = { def = missionDef, global = true }
    end
    for _, missionDef in ipairs(ToArray(wave and wave.Mission)) do
        missionBlocks[#missionBlocks + 1] = { def = missionDef, global = false }
    end

    local totalWaves = #(self.Mission.Waves or {})
    local items = {}
    for _, entry in ipairs(missionBlocks) do
        if not istable(entry.def) then
            continue
        end
        if not MissionAppliesToWave(entry.def, waveIndex, totalWaves, entry.global) then
            continue
        end
        if IsSentryBusterObjective(entry.def.Objective or entry.def.objective) and not self:HasEligibleSentryBusterTarget() then
            continue
        end
        local info = BuildMissionVisualInfo(entry.def, self)
        if not info then
            continue
        end
        items[#items + 1] = {
            info = info,
            count = ResolveMissionDisplayCount(entry.def),
            support = false,
            mission = true,
            active = false,
            support_limited = false,
        }
    end
    return items
end

function RUNTIME:BuildWaveMissionStatusItemsFromStates()
    local items = {}
    local keys = {}
    for missionId, _ in pairs(self.CurrentMissionStates or {}) do
        keys[#keys + 1] = missionId
    end
    table.sort(keys)

    for _, missionId in ipairs(keys) do
        local state = self.CurrentMissionStates[missionId]
        if not state or not istable(state.Def) then
            continue
        end
        if IsSentryBusterObjective(state.Def.Objective or state.Def.objective) and not self:HasEligibleSentryBusterTarget() then
            continue
        end

        local count = math.max(0, math.floor(tonumber(state.DesiredCount) or ResolveMissionDisplayCount(state.Def)))
        if state.MaxTotal ~= nil then
            local remainingTotal = math.max(0, math.floor((tonumber(state.MaxTotal) or 0) - (tonumber(state.SpawnedTotal) or 0)))
            count = math.min(count, remainingTotal)
        end

        local info = BuildMissionVisualInfo(state.Def, self)
        if not info then
            continue
        end
        items[#items + 1] = {
            info = info,
            count = count,
            support = false,
            mission = true,
            active = count > 0,
            support_limited = false,
        }
    end

    return items
end

function RUNTIME:BuildWavePreviewStatus(waveIndex)
    local wave = self.Mission and self.Mission.Waves and self.Mission.Waves[waveIndex] or nil
    if not wave then return {}, "" end

    local items = {}
    for _, spawnDef in ipairs(ToArray(wave.WaveSpawn)) do
        local support = BoolValue(spawnDef.Support or spawnDef.support, false)
        local count = support and ResolveSupportDisplayCountFromSpawnDef(spawnDef)
            or NumValue(spawnDef.TotalCount or spawnDef.totalcount, NumValue(spawnDef.MaxActive or spawnDef.maxactive, NumValue(spawnDef.SpawnCount or spawnDef.spawncount, 1)))
        local totalCount = math.max(0, math.floor(tonumber(count) or 0))
        local infos = BuildSpawnVisualInfos(spawnDef, self)
        local totalWeight = 0
        for _, info in ipairs(infos) do
            totalWeight = totalWeight + math.max(1, math.floor(tonumber(info.weight) or 1))
        end
        totalWeight = math.max(1, totalWeight)
        local allocated = 0

        for i, info in ipairs(infos) do
            local weight = math.max(1, math.floor(tonumber(info.weight) or 1))
            local alloc = (i == #infos)
                and math.max(0, totalCount - allocated)
                or math.max(0, math.floor((totalCount * weight) / totalWeight))
            allocated = allocated + alloc
            items[#items + 1] = {
                info = info,
                count = alloc,
                support = support,
                mission = false,
                active = false,
                support_limited = support and (TrimLower(spawnDef.Support or spawnDef.support) == "limited") or false,
            }
        end
    end
    for _, item in ipairs(self:BuildWaveMissionStatusItemsFromDefs(wave, waveIndex)) do
        items[#items + 1] = item
    end

    return BuildStatusFromItems(items)
end

function RUNTIME:BuildWaveRuntimeStatus()
    if not self.CurrentWaveState then return {}, "" end
    local items = {}
    for _, st in ipairs(self.CurrentWaveState.Spawns or {}) do
        local support = st.Support and true or false
        local remaining = support and ResolveSupportDisplayCountFromSpawnState(st)
            or math.max(0, (tonumber(st.TotalCount) or 0) - (tonumber(st.Spawned) or 0) + (tonumber(st.Alive) or 0))
        local infos = BuildSpawnVisualInfos(st.Def, self)
        local totalWeight = 0
        for _, info in ipairs(infos) do
            totalWeight = totalWeight + math.max(1, math.floor(tonumber(info.weight) or 1))
        end
        totalWeight = math.max(1, totalWeight)
        local allocated = 0

        for i, info in ipairs(infos) do
            local weight = math.max(1, math.floor(tonumber(info.weight) or 1))
            local alloc = (i == #infos)
                and math.max(0, remaining - allocated)
                or math.max(0, math.floor((remaining * weight) / totalWeight))
            allocated = allocated + alloc
            items[#items + 1] = {
                info = info,
                count = alloc,
                support = support,
                mission = false,
                active = support and ((tonumber(st.Alive) or 0) > 0) or false,
                support_limited = st.SupportLimited and true or false,
            }
        end
    end
    for _, item in ipairs(self:BuildWaveMissionStatusItemsFromStates()) do
        items[#items + 1] = item
    end
    return BuildStatusFromItems(items)
end

function RUNTIME:UpdateWaveStatusState(force, explicitEntries, explicitHash)
    if not TF_MVMState or not TF_MVMState.Set then return end

    local entries, hash = explicitEntries, explicitHash
    if entries == nil then
        if self.WaveActive then
            entries, hash = self:BuildWaveRuntimeStatus()
        else
            entries, hash = {}, ""
        end
    end

    if force or hash ~= self.LastWaveStatusHash then
        self.LastWaveStatusHash = hash
        TF_MVMState:Set("wave_status", entries or {})
    end
end

function RUNTIME:ClearTimers()
    for name, _ in pairs(self.TimerNames) do
        RemoveTimer(name)
        self.TimerNames[name] = nil
    end
end

function RUNTIME:CleanupManagedEntities()
    for ent, _ in pairs(self.ManagedBots) do
        if IsValid(ent) then
            RemoveManagedBotEntity(ent, "MvM runtime cleanup")
        end
    end

    for ent, _ in pairs(self.ManagedTanks) do
        if IsValid(ent) then
            ent.TF_MVM_SilentRemove = true
            ent:Remove()
        end
    end

    for ent, _ in pairs(self.ManagedEntities) do
        if IsValid(ent) then
            ent.TF_MVM_SilentRemove = true
            ent:Remove()
        end
    end

    self.ManagedBots = {}
    self.ManagedTanks = {}
    self.ManagedEntities = {}
end

function RUNTIME:ResetWaveState()
    self.CurrentWaveState = nil
    self.SpawnStatesByName = {}
    self.CurrentMissionStates = {}
end

function RUNTIME:ClearMissionTimers()
    for name, _ in pairs(self.TimerNames) do
        if string.find(name, "TF_MVM_Mission_", 1, true) or string.find(name, "TF_MVM_MissionStart_", 1, true) then
            RemoveTimer(name)
            self.TimerNames[name] = nil
        end
    end
end

function RUNTIME:Stop(reason)
    DebugPrint("Stopping runtime", reason or "")

    self.Active = false
    self.Setup = false
    self.WaveActive = false
    self.SetupEndTime = nil
    self.PendingSetupDuration = nil
    self.SetupInitialDuration = 0
    self.SetupWaitingTimerDuration = nil
    self.SetupReadyCountdownTotal = nil
    self.WaveIndex = 0
    self.LastWaveStatusHash = ""
    self:ResetReadyPlayers()
    self:ResetSentryBusterState()
    self.BotSpawningPaused = false
    self.DefaultEventChangeAttributesName = ""
    self:ClearMissionRespawnWaveSetting()
    self:ClearMissionPresentationState()
    for _, roundTimer in ipairs(GetRoundTimers()) do
        if IsValid(roundTimer) then
            roundTimer.TF_MVM_Managed = false
            roundTimer.WaitingForPlayers = false
        end
    end

    self:ClearTimers()
    self:CleanupManagedEntities()
    self:ResetWaveState()
    self:UpdateWaveStatusState(true, {}, "")

    self:PushState()

    if reason then
        hook.Run("TF_MVM_RuntimeStopped", reason)
    end
end

function RUNTIME:LoadMission(path, scope)
    scope = scope or "GAME"

    if not TF_MVM.POPParser then
        self:SetError("parser_missing")
        return false
    end

    local parsed = TF_MVM.POPParser:Parse(path, scope)
    if not parsed or not parsed.ok then
        local err = parsed and parsed.error or "parse_failed"
        self:SetError(err)
        print(string.format("[TF_MVM][POP] parse failed for %s (%s): %s", tostring(path), tostring(scope), tostring(err)))
        if parsed and istable(parsed.strictErrors) then
            for i = 1, math.min(#parsed.strictErrors, 12) do
                print("  [strict] " .. tostring(parsed.strictErrors[i]))
            end
            if #parsed.strictErrors > 12 then
                print("  [strict] ... +" .. tostring(#parsed.strictErrors - 12) .. " more")
            end
        end
        return false
    end

      self.Mission = parsed
      self.DefaultEventChangeAttributesName = ""
      self:SetError("")
      self:PushState()
    if istable(parsed.Warnings) and #parsed.Warnings > 0 then
        for _, warn in ipairs(parsed.Warnings) do
            print("[TF_MVM][POP] warning: " .. tostring(warn))
        end
    end

    hook.Run("TF_MVM_MissionLoaded", parsed)
    return true
end

function RUNTIME:LoadMissionForCurrentMap(override)
    if not TF_MVM.MissionLookup then
        self:SetError("lookup_missing")
        return false
    end

    local result = TF_MVM.MissionLookup:FindMission({ override = override })
    if not result.ok then
        self:SetError("no_mission_found")

        print("[TF_MVM] No mission found for map " .. tostring(result.map or game.GetMap()))
        print("[TF_MVM] Searched paths:")
        for _, p in ipairs(result.searched or {}) do
            print("  - " .. tostring(p))
        end
        print("[TF_MVM] Hint: place a mission as scripts/population/<map>.pop or set tf_mvm_mission_override")

        return false
    end

    return self:LoadMission(result.path, result.scope)
end

function RUNTIME:GetSetupDuration()
    local c = GetConVar("tf_mvm_setup_time_override")
    local override = c and tonumber(c:GetString() or "") or nil
    if override and override > 0 then
        return override
    end

    if self.PendingSetupDuration ~= nil then
        local pending = tonumber(self.PendingSetupDuration) or 0
        self.PendingSetupDuration = nil
        if pending > 0 then
            return pending
        end
    end

    return 30
end

function RUNTIME:ApplyRoundTimerSetup(duration, paused)
    duration = math.max(0, tonumber(duration) or 0)

    local timers = EnsureRoundTimerExists()
    if #timers <= 0 then return end

    for _, roundTimer in ipairs(timers) do
        roundTimer.TF_MVM_Managed = true
        roundTimer.IsSetupPhase = true
        roundTimer.WaitingForPlayers = paused and true or false
        roundTimer.Properties = roundTimer.Properties or {}
        roundTimer.Properties.show_in_hud = 1
        roundTimer.Properties.auto_countdown = 1
        roundTimer.Properties.start_paused = paused and 1 or 0
        roundTimer.Properties.timer_length = duration
        roundTimer.Properties.max_length = math.max(duration, tonumber(roundTimer.Properties.max_length) or duration)

        if roundTimer.SetShowInHUD then
            roundTimer:SetShowInHUD(true)
        end

        if paused and roundTimer.SetAndResumeTimer2 then
            roundTimer:SetAndResumeTimer2(duration, true)
            if roundTimer.PauseTimer then
                roundTimer:PauseTimer()
            elseif roundTimer.SetAndPauseTimer then
                roundTimer:SetAndPauseTimer(duration, true)
            end
        elseif paused and roundTimer.SetAndPauseTimer then
            roundTimer:SetAndPauseTimer(duration, true)
        elseif roundTimer.SetAndResumeTimer then
            roundTimer:SetAndResumeTimer(duration, true)
        elseif roundTimer.SetAndResumeTimer2 then
            roundTimer:SetAndResumeTimer2(duration, false)
        elseif roundTimer.SetAndPauseTimer then
            roundTimer:SetAndPauseTimer(duration, true)
        end
    end
end

function RUNTIME:ApplyRoundTimerWave()
    local timers = EnsureRoundTimerExists()
    if #timers <= 0 then return end

    for _, roundTimer in ipairs(timers) do
        roundTimer.TF_MVM_Managed = true
        roundTimer.IsSetupPhase = false
        roundTimer.WaitingForPlayers = false
        roundTimer.Properties = roundTimer.Properties or {}
        roundTimer.Properties.show_in_hud = 1
        roundTimer.Properties.start_paused = 1

        if roundTimer.SetShowInHUD then
            roundTimer:SetShowInHUD(true)
        end

        if roundTimer.SetAndPauseTimer then
            roundTimer:SetAndPauseTimer(0, true)
        elseif roundTimer.SetAndResumeTimer2 then
            roundTimer:SetAndResumeTimer2(0, true)
            if roundTimer.Pause then
                roundTimer:Pause()
            end
        end
    end
end

function RUNTIME:StartSetupForWave(waveIndex)
    local duration = self:GetSetupDuration()

    self.Setup = true
    self.WaveActive = false
    self.WaveIndex = math.max(0, waveIndex - 1)
    self.SetupInitialDuration = math.max(1, math.floor(duration))
    self.SetupWaitingTimerDuration = nil
    self.SetupEndTime = 0
    self.SetupReadyCountdownTotal = nil
    self:ResetReadyPlayers()
    self:ApplyMissionRespawnWaveSetting(waveIndex)
    local preview, hash = self:BuildWavePreviewStatus(waveIndex)
    self:UpdateWaveStatusState(true, preview, hash)

    self:PushState()
    self:ApplyRoundTimerSetup(duration, true)

    hook.Run("TF_MVM_WaveSetupStarted", waveIndex, duration)

    local name = TimerName("SetupStartWave")
    AddTimerRef(self, name)
    timer.Create(name, 0.1, 0, function()
        if not self.Active or not self.Setup then
            RemoveTimer(name)
            self.TimerNames[name] = nil
            return
        end

        local changed = self:RecomputeSetupCountdown()
        if changed then
            self:PushState()
        end
    end)
end

function RUNTIME:CreateSpawnState(wave, index, def)
    local isTank = (def.Tank ~= nil) or (def.tank ~= nil)
    local isSentry = (def.SentryGun ~= nil) or (def.sentrygun ~= nil)
    local isSingleEntitySpawner = isTank or isSentry
    local visualInfo = BuildSpawnVisualInfo(def)

    local spawnCount = NumValue(def.SpawnCount or def.spawncount, 1)
    spawnCount = math.max(1, math.floor(spawnCount))

    local totalDefault = isSingleEntitySpawner and 1 or NumValue(def.MaxActive or def.maxactive, spawnCount)
    local totalCount = NumValue(def.TotalCount or def.totalcount, totalDefault)
    totalCount = math.max(0, math.floor(totalCount))

    local maxActive = NumValue(def.MaxActive or def.maxactive, totalCount)
    maxActive = math.max(1, math.floor(maxActive))

    local hasAfterDeath = (def.WaitBetweenSpawnsAfterDeath ~= nil) or (def.waitbetweenspawnsafterdeath ~= nil)
    local waitBetween = NumValue(def.WaitBetweenSpawns or def.waitbetweenspawns, 0)
    if hasAfterDeath then
        waitBetween = NumValue(def.WaitBetweenSpawnsAfterDeath or def.waitbetweenspawnsafterdeath, waitBetween)
    end
    waitBetween = math.max(0, waitBetween)

    local waitBefore = NumValue(def.WaitBeforeStarting or def.waitbeforestarting, 0)
    waitBefore = math.max(0, waitBefore)

    local totalCurrency = NumValue(def.TotalCurrency or def.totalcurrency, 0)
    totalCurrency = math.max(0, math.floor(totalCurrency))

    local supportMode = TrimLower(def.Support or def.support)
    local isSupport = supportMode ~= "" and supportMode ~= "0" and supportMode ~= "false" and supportMode ~= "no" and supportMode ~= "off"
    local limitedSupport = isSupport and supportMode == "limited"
    local infiniteSupport = isSupport and not limitedSupport
    local waitBetweenAfterDeath = NumValue(def.WaitBetweenSpawnsAfterDeath or def.waitbetweenspawnsafterdeath, 0)
    waitBetweenAfterDeath = math.max(0, waitBetweenAfterDeath)
    local randomSpawn = BoolValue(def.RandomSpawn or def.randomspawn, false)

    local id = string.format("wave_%d_spawn_%d", self.WaveIndex, index)
    local name = TrimLower(def.Name or def.name)
    if name == "" then
        name = id
    end

    local st = {
        Id = id,
        Name = name,
        Def = def,
        TotalCount = totalCount,
        SpawnCount = spawnCount,
        MaxActive = maxActive,
        WaitBetween = waitBetween,
        WaitBetweenAfterDeath = waitBetweenAfterDeath,
        WaitBetweenAfterDeathMode = hasAfterDeath,
        StartAt = CurTime() + waitBefore,
        WaitForSpawned = TrimLower(def.WaitForAllSpawned or def.waitforallspawned),
        WaitForDead = TrimLower(def.WaitForAllDead or def.waitforalldead),
        Support = isSupport,
        SupportLimited = limitedSupport,
        InfiniteSupport = infiniteSupport,
        TotalCurrency = totalCurrency,
        CurrencyRemaining = totalCurrency,
        Spawned = 0,
        Alive = 0,
        Started = false,
        CompletedSpawned = (totalCount <= 0),
        CompletedDead = (totalCount <= 0),
        NextSpawnAt = CurTime() + waitBefore,
        NextAfterDeathAt = nil,
        FirstSpawnOutputFired = false,
        FirstSpawnWarningFired = false,
        DoneOutputFired = false,
        DoneWarningFired = false,
        StartWaveOutputFired = false,
        StartWaveWarningFired = false,
        LastSpawnOutputFired = false,
        LastSpawnWarningFired = false,
        RandomSpawn = randomSpawn,
        SelectorState = { index = 0 },
        FixedSpawnEnt = nil,
        SpawnClassHint = visualInfo and visualInfo.class or nil,
    }

    if st.InfiniteSupport then
        st.TotalCount = math.max(st.MaxActive, st.SpawnCount)
        st.CompletedSpawned = false
        st.CompletedDead = false
    end

    return st
end

function RUNTIME:DependenciesMet(st)
    local function check(name, field)
        if name == "" then return true end
        local dep = self.SpawnStatesByName[name]
        if not dep then
            return true
        end
        return dep[field] == true
    end

    if not check(st.WaitForSpawned, "CompletedSpawned") then
        return false
    end

    if not check(st.WaitForDead, "CompletedDead") then
        return false
    end

    return true
end

function RUNTIME:AllocateCurrencyForSpawn(st)
    if st.TotalCurrency <= 0 then
        return 0
    end

    local remainingUnits = math.max(1, st.TotalCount - st.Spawned + 1)
    local value = math.floor(st.CurrencyRemaining / remainingUnits)

    if value <= 0 and st.CurrencyRemaining > 0 then
        value = 1
    end

    value = math.min(value, st.CurrencyRemaining)
    st.CurrencyRemaining = math.max(0, st.CurrencyRemaining - value)

    return value
end

function RUNTIME:PickRawBotDef(st)
    local def = st.Def

    if def.RandomChoice then
        local choice = table.Random(ToArray(def.RandomChoice))
        if istable(choice) and choice.TFBot then
            return table.Random(ToArray(choice.TFBot))
        end
        return choice
    end

    if def.Mob then
        local mobDef = table.Random(ToArray(def.Mob))
        if istable(mobDef) and mobDef.TFBot then
            return table.Random(ToArray(mobDef.TFBot))
        end
        return mobDef
    end

    if def.Squad then
        return table.Random(ToArray(def.Squad))
    end

    if def.SentryGun then
        return table.Random(ToArray(def.SentryGun))
    end

    if def.TFBot then
        return table.Random(ToArray(def.TFBot))
    end

    return def
end

function RUNTIME:SpawnOne(st, fixedSpawnEnt)
    if not TF_MVM.Spawner then
        return false
    end

    local def = st.Def
    local spawnedNow = 0
    local spawnedEntities = {}

    local function registerSpawned(ent)
        if not IsValid(ent) then return false end
        st.Spawned = st.Spawned + 1
        st.Alive = st.Alive + 1
        spawnedNow = spawnedNow + 1
        spawnedEntities[#spawnedEntities + 1] = ent
        ent.TF_MVM_CurrencyValue = self:AllocateCurrencyForSpawn(st)
        return true
    end

    local function spawnNode(node)
        if not istable(node) then
            return false
        end

        if node.RandomChoice then
            local choice = table.Random(ToArray(node.RandomChoice))
            return spawnNode(choice)
        end

        if node.Squad then
            local squad = CreateManagedSquad(node)
            local any = false
            for _, member in ipairs(ToArray(node.Squad)) do
                local beforeCount = #spawnedEntities
                if spawnNode(member) then
                    any = true
                    for idx = beforeCount + 1, #spawnedEntities do
                        local spawnedEnt = spawnedEntities[idx]
                        if IsValid(spawnedEnt) and spawnedEnt.IsPlayer and spawnedEnt:IsPlayer() then
                            AttachBotToManagedSquad(spawnedEnt, squad)
                        end
                    end
                end
            end
            return any
        end

        if node.Mob then
            local mobNode = table.Random(ToArray(node.Mob))
            return spawnNode(mobNode)
        end

        if node.Tank then
            local tankDef = table.Random(ToArray(node.Tank))
            local tank, err = TF_MVM.Spawner:SpawnTank(self, tankDef, st, fixedSpawnEnt, st.SelectorState, st.RandomSpawn)
            if not IsValid(tank) then
                DebugPrint("Failed to spawn tank", err or "")
                return false
            end
            return registerSpawned(tank)
        end

        if node.SentryGun then
            local sentryDef = table.Random(ToArray(node.SentryGun))
            local sentry, err = TF_MVM.Spawner:SpawnSentryGun(self, sentryDef, st, fixedSpawnEnt, st.SelectorState, st.RandomSpawn)
            if not IsValid(sentry) then
                DebugPrint("Failed to spawn sentrygun", err or "")
                return false
            end
            return registerSpawned(sentry)
        end

        local rawBotDef = node
        if node.TFBot then
            rawBotDef = table.Random(ToArray(node.TFBot))
        end
        local whereField = def.ClosestPoint or def.closestpoint or def.Where or def.where
        local bot, err = TF_MVM.Spawner:SpawnTFBot(self, rawBotDef, st, whereField, nil, fixedSpawnEnt, st.SelectorState, st.RandomSpawn)
        if not IsValid(bot) then
            DebugPrint("Failed to spawn bot", err or "")
            return false
        end
        return registerSpawned(bot)
    end

    local ok = spawnNode(def)
    if ok and spawnedNow > 0 and TF_MVM.Outputs then
        TF_MVM.Outputs:Fire(st.Def.OnSpawnOutput)
    end
    return ok
end


function RUNTIME:UpdateSpawnState(st, now)
    if self:IsBotSpawningPaused() then
        return
    end

    if st.CompletedSpawned and st.Alive <= 0 and not st.CompletedDead then
        st.CompletedDead = true
        if not st.DoneWarningFired and isfunction(BroadcastSound) and st.Def.DoneWarningSound then
            st.DoneWarningFired = true
            BroadcastSound(tostring(ScalarValue(st.Def.DoneWarningSound)))
        end
        if not st.DoneOutputFired and TF_MVM.Outputs then
            st.DoneOutputFired = true
            TF_MVM.Outputs:Fire(st.Def.DoneOutput)
        end
    end

    if st.CompletedDead then
        return
    end

    if now < st.StartAt then
        return
    end

    if not self:DependenciesMet(st) then
        return
    end

    if not st.Started then
        st.Started = true
        if not st.StartWaveWarningFired and isfunction(BroadcastSound) and st.Def.StartWaveWarningSound then
            st.StartWaveWarningFired = true
            BroadcastSound(tostring(ScalarValue(st.Def.StartWaveWarningSound)))
        end
        if TF_MVM.Outputs then
            st.StartWaveOutputFired = true
            TF_MVM.Outputs:Fire(st.Def.StartWaveOutput)
        end

        if not self.CurrentWaveState.FirstSpawnOutputFired then
            self.CurrentWaveState.FirstSpawnOutputFired = true
            if TF_MVM.Outputs then
                TF_MVM.Outputs:Fire(self.CurrentWaveState.Def.FirstSpawnOutput)
            end
        end
    end

    if st.CompletedSpawned then
        if st.Support and st.Alive <= 0 then
            st.CompletedDead = true
        end
        return
    end

    if st.WaitBetweenAfterDeathMode then
        if st.Alive > 0 then
            return
        end
        if st.NextAfterDeathAt and now < st.NextAfterDeathAt then
            return
        end
    else
        if st.Alive >= st.MaxActive then
            return
        end
        if now < st.NextSpawnAt then
            return
        end
    end

    local spawnBudget
    if st.InfiniteSupport then
        spawnBudget = st.SpawnCount
    else
        spawnBudget = math.min(st.SpawnCount, st.TotalCount - st.Spawned)
    end

    if st.WaitBetweenAfterDeathMode and (st.MaxActive - st.Alive) < st.SpawnCount then
        return
    end

    local groupSpawnEnt = st.FixedSpawnEnt
    if not st.RandomSpawn then
        if not IsValid(groupSpawnEnt) and TF_MVM.Spawner then
            local whereField = st.Def.ClosestPoint or st.Def.closestpoint or st.Def.Where or st.Def.where
            groupSpawnEnt = TF_MVM.Spawner:PickSpawnEntity(whereField, st.SpawnClassHint or "scout", st.SelectorState, false)
        end
        if IsValid(groupSpawnEnt) then
            st.FixedSpawnEnt = groupSpawnEnt
        end
    end

    while spawnBudget > 0 and st.Alive < st.MaxActive and (st.InfiniteSupport or st.Spawned < st.TotalCount) do
        local fixedSpawnEnt = st.RandomSpawn and nil or groupSpawnEnt
        local ok = self:SpawnOne(st, fixedSpawnEnt)
        if not ok then
            break
        end
        if not st.FirstSpawnOutputFired then
            st.FirstSpawnOutputFired = true
            if not st.FirstSpawnWarningFired and isfunction(BroadcastSound) and st.Def.FirstSpawnWarningSound then
                st.FirstSpawnWarningFired = true
                BroadcastSound(tostring(ScalarValue(st.Def.FirstSpawnWarningSound)))
            end
            if TF_MVM.Outputs then
                TF_MVM.Outputs:Fire(st.Def.FirstSpawnOutput)
            end
        end
        spawnBudget = spawnBudget - 1
    end

    if st.WaitBetweenAfterDeathMode then
        st.NextAfterDeathAt = nil
        if st.RandomSpawn then
            st.FixedSpawnEnt = nil
        end
    else
        st.NextSpawnAt = now + st.WaitBetween
        if st.RandomSpawn then
            st.FixedSpawnEnt = nil
        end
    end

    if not st.InfiniteSupport and st.Spawned >= st.TotalCount then
        st.CompletedSpawned = true
        if not st.LastSpawnOutputFired then
            st.LastSpawnOutputFired = true
            if not st.LastSpawnWarningFired and isfunction(BroadcastSound) and st.Def.LastSpawnWarningSound then
                st.LastSpawnWarningFired = true
                BroadcastSound(tostring(ScalarValue(st.Def.LastSpawnWarningSound)))
            end
            if TF_MVM.Outputs then
                TF_MVM.Outputs:Fire(st.Def.LastSpawnOutput)
            end
        end
        if st.Support and st.Alive <= 0 then
            st.CompletedDead = true
            if not st.DoneWarningFired and isfunction(BroadcastSound) and st.Def.DoneWarningSound then
                st.DoneWarningFired = true
                BroadcastSound(tostring(ScalarValue(st.Def.DoneWarningSound)))
            end
            if not st.DoneOutputFired and TF_MVM.Outputs then
                st.DoneOutputFired = true
                TF_MVM.Outputs:Fire(st.Def.DoneOutput)
            end
        end
    end
end

function RUNTIME:GetMvMBombEntity()
    local fallback = nil
    for _, ent in ipairs(ents.FindByClass("item_teamflag_mvm")) do
        if not IsValid(ent) then continue end
        if IsValid(ent.Carrier) then
            return ent
        end
        if not fallback then
            fallback = ent
        end
    end
    return fallback
end

function RUNTIME:TryAssignBombToBot(bot)
    if not IsValid(bot) then return false end
    if not self.WaveActive or not self.CurrentWaveState then return false end
    if self.CurrentWaveState.BombAssigned then return false end
    if bot:Team() ~= TEAM_BLU and bot:Team() ~= TF_TEAM_PVE_INVADERS then return false end

    local bomb = self:GetMvMBombEntity()
    if not IsValid(bomb) then return false end
    if IsValid(bomb.Carrier) then
        self.CurrentWaveState.BombAssigned = true
        return true
    end

    bomb:SetPos(bot:GetPos() + Vector(0, 0, 8))
    if bomb.Pickup then
        bomb:Pickup(bot)
    end

    if IsValid(bomb.Carrier) and bomb.Carrier == bot then
        self.CurrentWaveState.BombAssigned = true
        return true
    end

    return false
end

function RUNTIME:ApplyDeathRespawnDelay(st)
    if not st then return end
    if st.CompletedSpawned then return end

    local now = CurTime()
    local delay = tonumber(st.WaitBetweenAfterDeath or st.WaitBetween or 0) or 0
    if delay <= 0 then return end

    if st.WaitBetweenAfterDeathMode then
        if st.Alive <= 0 then
            st.NextAfterDeathAt = math.max(st.NextAfterDeathAt or now, now + delay)
            if st.RandomSpawn then
                st.FixedSpawnEnt = nil
            end
        end
        return
    end

    st.NextSpawnAt = math.max(st.NextSpawnAt or now, now + delay)
end

function RUNTIME:CheckWaveCompleted()
    if not self.CurrentWaveState then return false end

    for _, st in ipairs(self.CurrentWaveState.Spawns) do
        if st.Support then
            continue
        end
        if not st.CompletedDead then
            return false
        end
    end

    return true
end

function RUNTIME:GetMissionAliveCount(missionId)
    local count = 0
    for bot, info in pairs(self.ManagedBots) do
        if IsValid(bot) and info and info.missionId == missionId then
            count = count + 1
        end
    end
    return count
end

function RUNTIME:ScheduleMissionBotSpawns(wave)
    self:ClearMissionTimers()
    self.CurrentMissionStates = {}

    local missionBlocks = {}
    for _, missionDef in ipairs(ToArray(self.Mission and self.Mission.GlobalMissions)) do
        missionBlocks[#missionBlocks + 1] = { def = missionDef, global = true }
    end
    for _, missionDef in ipairs(ToArray(wave.Mission)) do
        missionBlocks[#missionBlocks + 1] = { def = missionDef, global = false }
    end

    local totalWaves = #(self.Mission and self.Mission.Waves or {})

    for idx, missionEntry in ipairs(missionBlocks) do
        local missionDef = missionEntry.def
        if not istable(missionDef) then
            continue
        end
        if not MissionAppliesToWave(missionDef, self.WaveIndex, totalWaves, missionEntry.global) then
            continue
        end

        local desiredCount = math.max(1, math.floor(NumValue(missionDef.DesiredCount or missionDef.desiredcount or missionDef.Count or missionDef.count, 1)))
        local maxTotal = NumValue(missionDef.Count or missionDef.count, nil)
        if maxTotal ~= nil then
            maxTotal = math.max(1, math.floor(maxTotal))
        end
        local firstDelay = math.max(0, NumValue(missionDef.InitialCooldown or missionDef.initialcooldown, 0))
        local cooldown = math.max(0.1, NumValue(missionDef.CooldownTime or missionDef.cooldowntime or missionDef.Cooldown or missionDef.cooldown, 20))

        local missionId = string.format("wave_%d_mission_%d", self.WaveIndex, idx)
        self.CurrentMissionStates[missionId] = {
            Def = missionDef,
            DesiredCount = desiredCount,
            MaxTotal = maxTotal,
            SpawnedTotal = 0,
        }

        local timerName = TimerName(string.format("Mission_%d_%d", self.WaveIndex, idx))
        local startName = TimerName(string.format("MissionStart_%d_%d", self.WaveIndex, idx))

        local function MissionTick()
            if not self.Active or not self.WaveActive then
                RemoveTimer(timerName)
                self.TimerNames[timerName] = nil
                return
            end

            if self:IsBotSpawningPaused() then
                return
            end

            local state = self.CurrentMissionStates[missionId]
            if not state then
                RemoveTimer(timerName)
                self.TimerNames[timerName] = nil
                return
            end

            if state.MaxTotal and state.SpawnedTotal >= state.MaxTotal then
                RemoveTimer(timerName)
                self.TimerNames[timerName] = nil
                return
            end

            local alive = self:GetMissionAliveCount(missionId)
            if alive >= state.DesiredCount then
                return
            end

            local objective = missionDef.Objective or missionDef.objective
            if IsSentryBusterObjective(objective) and not self:HasEligibleSentryBusterTarget() then
                return
            end

            if TF_MVM.Spawner then
                local bot = TF_MVM.Spawner:SpawnMissionBot(self, missionDef, missionId)
                if IsValid(bot) then
                    if IsSentryBusterObjective(objective) then
                        local targetData = self:ConsumeSentryBusterTarget()
                        if targetData and IsValid(targetData.sentry) then
                            bot.TF_MVM_SentryTarget = targetData.sentry
                            bot.TargetEnt = targetData.sentry
                            bot:SetNWEntity("TF_MVM_SentryTarget", targetData.sentry)
                        end
                        self:OnSentryBusterSpawned(cooldown)
                    end
                    state.SpawnedTotal = state.SpawnedTotal + 1
                end
            end
        end

        if firstDelay <= 0 then
            MissionTick()
            AddTimerRef(self, timerName)
            timer.Create(timerName, cooldown, 0, MissionTick)
        else
            AddTimerRef(self, startName)
            timer.Create(startName, firstDelay, 1, function()
                self.TimerNames[startName] = nil
                if not self.Active or not self.WaveActive then
                    return
                end

                MissionTick()
                AddTimerRef(self, timerName)
                timer.Create(timerName, cooldown, 0, MissionTick)
            end)
        end
    end
end

function RUNTIME:StartWave(waveIndex)
    if not self.Active then return end
    if not self.Mission then return end

    local wave = self.Mission.Waves[waveIndex]
    if not wave then
        self:FinishMission()
        return
    end

    self.Setup = false
    self.WaveActive = true
    self.SetupEndTime = nil
    self.SetupInitialDuration = 0
    self.SetupWaitingTimerDuration = nil
    self.SetupReadyCountdownTotal = nil
    self.WaveIndex = waveIndex
    self:ResetReadyPlayers()
    self:ApplyMissionRespawnWaveSetting(waveIndex)

    self:ApplyRoundTimerWave()

    self.CurrentWaveState = {
        Def = wave,
        Spawns = {},
        FirstSpawnOutputFired = false,
        BombAssigned = false,
    }
    self.SentryBusterCooldownUntil = 0
    self.SentryBusterKillsSinceLastSpawn = 0
    self.SentryBustersSpawnedThisWave = 0

    self.SpawnStatesByName = {}

    for idx, spawnDef in ipairs(ToArray(wave.WaveSpawn)) do
        local st = self:CreateSpawnState(wave, idx, spawnDef)
        self.CurrentWaveState.Spawns[#self.CurrentWaveState.Spawns + 1] = st
        self.SpawnStatesByName[st.Name] = st
        self.SpawnStatesByName[st.Id] = st
        if TF_MVM.Outputs then
            TF_MVM.Outputs:Fire(spawnDef.InitWaveOutput)
        end
    end

    if TF_MVM.Outputs then
        TF_MVM.Outputs:Fire(wave.InitWaveOutput)
        TF_MVM.Outputs:Fire(wave.StartWaveOutput)
    end
    if isfunction(BroadcastSound) and wave.Sound then
        BroadcastSound(tostring(ScalarValue(wave.Sound)))
    end

    self:ScheduleMissionBotSpawns(wave)
    self:UpdateWaveStatusState(true)

    hook.Run("TF_MVM_WaveStarted", waveIndex, wave)
    self:PushState()

    if #self.CurrentWaveState.Spawns == 0 then
        local name = TimerName("ImmediateWaveComplete")
        AddTimerRef(self, name)
        timer.Create(name, 0.25, 1, function()
            if self.Active and self.WaveActive then
                self:CompleteWave()
            end
        end)
    end
end

function RUNTIME:DespawnSupportEntities()
    for bot, info in pairs(self.ManagedBots) do
        if IsValid(bot) and info and info.spawn and info.spawn.Support then
            RemoveManagedBotEntity(bot, "MvM support cleanup")
        end
    end

    for tank, info in pairs(self.ManagedTanks) do
        if IsValid(tank) and info and info.spawn and info.spawn.Support then
            tank.TF_MVM_SilentRemove = true
            tank:Remove()
        end
    end

    for ent, info in pairs(self.ManagedEntities) do
        if IsValid(ent) and info and info.spawn and info.spawn.Support then
            ent.TF_MVM_SilentRemove = true
            ent:Remove()
        end
    end
end

function RUNTIME:CompleteWave()
    if not self.Active then return end
    if not self.WaveActive then return end

    local wave = self.CurrentWaveState and self.CurrentWaveState.Def or nil

    self.WaveActive = false
    self:ClearMissionTimers()
    self:DespawnSupportEntities()

    if TF_MVM.Outputs and wave then
        TF_MVM.Outputs:Fire(wave.DoneOutput)
    end
    self:UpdateWaveStatusState(true, {}, "")

    hook.Run("TF_MVM_WaveCompleted", self.WaveIndex, wave)

    if self.WaveIndex >= #(self.Mission and self.Mission.Waves or {}) then
        self:FinishMission()
        return
    end

    self.PendingSetupDuration = NumValue(wave and wave.WaitWhenDone, nil)
    self:StartSetupForWave(self.WaveIndex + 1)
end

function RUNTIME:FinishMission()
    if not self.Active then return end

    self.Active = false
    self.Setup = false
    self.WaveActive = false
    self.SetupEndTime = nil
    self.PendingSetupDuration = nil
    self.SetupInitialDuration = 0
    self.SetupWaitingTimerDuration = nil
    self.SetupReadyCountdownTotal = nil
    self.LastWaveStatusHash = ""
    self:ResetReadyPlayers()
    self:ClearMissionRespawnWaveSetting()
    self:ClearMissionPresentationState()
    for _, roundTimer in ipairs(GetRoundTimers()) do
        if IsValid(roundTimer) then
            roundTimer.TF_MVM_Managed = false
            roundTimer.WaitingForPlayers = false
        end
    end

    hook.Run("TF_MVM_MissionCompleted", self.Mission)

    if GAMEMODE and GAMEMODE.RoundWin then
        GAMEMODE:RoundWin(TEAM_RED)
    end

    self:ClearTimers()
    self:CleanupManagedEntities()
    self:ResetWaveState()
    self:UpdateWaveStatusState(true, {}, "")

    self:PushState()
end

function RUNTIME:FailMission(reason)
    if not self.Active then return end

    self.Active = false
    self.Setup = false
    self.WaveActive = false
    self.SetupEndTime = nil
    self.PendingSetupDuration = nil
    self.SetupInitialDuration = 0
    self.SetupWaitingTimerDuration = nil
    self.SetupReadyCountdownTotal = nil
    self.LastWaveStatusHash = ""
    self:ResetReadyPlayers()
    self:ClearMissionRespawnWaveSetting()
    self:ClearMissionPresentationState()
    for _, roundTimer in ipairs(GetRoundTimers()) do
        if IsValid(roundTimer) then
            roundTimer.TF_MVM_Managed = false
            roundTimer.WaitingForPlayers = false
        end
    end

    hook.Run("TF_MVM_MissionFailed", reason or "failed")

    if GAMEMODE and GAMEMODE.RoundWin then
        GAMEMODE:RoundWin(TEAM_BLU)
    end

    self:ClearTimers()
    self:CleanupManagedEntities()
    self:ResetWaveState()
    self:UpdateWaveStatusState(true, {}, "")

    self:PushState()
end

function RUNTIME:Start()
    if not IsMvMMap() then
        self:SetError("not_mvm_map")
        return false
    end

    if not self:IsEnabled() then
        self:SetError("disabled")
        return false
    end

    if not self.Mission then
        if not self:LoadMissionForCurrentMap() then
            return false
        end
    end

    self:Stop()

    self.Active = true
    self.Setup = false
    self.WaveActive = false
    self.PendingSetupDuration = nil
    self.SetupInitialDuration = 0
    self.SetupWaitingTimerDuration = nil
    self.SetupReadyCountdownTotal = nil
    self.WaveIndex = 0
    self.ManagedBots = {}
    self.ManagedTanks = {}
    self.ManagedEntities = {}
    self.LastWaveStatusHash = ""
    self.ReadyPlayers = {}
    self:ResetSentryBusterState()
    self:ApplyMissionRespawnWaveSetting()
    self:ApplyMissionPresentationState()

    if TF_MVM.Economy then
        TF_MVM.Economy:ResetAll(self.Mission.StartingCurrency or 600)
    end

    self:InitializeRandomPlacements()
    self:SchedulePeriodicSpawns()

    hook.Run("TF_MVM_MissionStarted", self.Mission)

    self:StartSetupForWave(1)
    self:PushState()

    return true
end

function RUNTIME:RegisterManagedBot(bot, spawnState, def, missionId)
    if not IsValid(bot) then return end
    local objective = TrimLower(def and (def.Objective or def.objective) or "")

    self.ManagedBots[bot] = {
        spawn = spawnState,
        def = def,
        missionId = missionId,
        objective = objective,
    }

    bot.TF_MVMManaged = true
    if objective ~= "" then
        bot.TF_MVM_Objective = objective
    end

    timer.Simple(0, function()
        if not IsValid(bot) then return end
        self:TryAssignBombToBot(bot)
    end)
end

function RUNTIME:GetManagedBotInfo(bot)
    if not IsValid(bot) then return nil end
    return self.ManagedBots and self.ManagedBots[bot] or nil
end

function RUNTIME:GetManagedBotObjective(bot)
    local info = self:GetManagedBotInfo(bot)
    if info and isstring(info.objective) and info.objective ~= "" then
        return info.objective
    end
    return TrimLower(IsValid(bot) and bot.TF_MVM_Objective or "")
end

function RUNTIME:RegisterManagedTank(tank, spawnState, def)
    if not IsValid(tank) then return end

    self.ManagedTanks[tank] = {
        spawn = spawnState,
        def = def,
    }
end

function RUNTIME:RegisterManagedEntity(ent, spawnState, def, kind)
    if not IsValid(ent) then return end
    self.ManagedEntities[ent] = {
        spawn = spawnState,
        def = def,
        kind = tostring(kind or ""),
    }
    ent.TF_MVMManaged = true
end

function RUNTIME:HandleManagedEntityRemoved(ent)
    local info = self.ManagedEntities[ent]
    if not info then return end
    self.ManagedEntities[ent] = nil

    local st = info.spawn
    if st then
        st.Alive = math.max(0, (st.Alive or 1) - 1)
        self:ApplyDeathRespawnDelay(st)
        if st.CompletedSpawned and st.Alive <= 0 then
            st.CompletedDead = true
        end
    end

    if IsValid(ent) and ent:GetClass() == "obj_sentrygun" then
        self:EnsureSentryBusterState()
        self.SentryBusterKillsBySentry[ent] = nil
        self.SentryBusterDamageBySentry[ent] = nil
        self.SentryBusterKillWindowStartBySentry[ent] = nil
        local builder = IsValid(ent:GetBuilder()) and ent:GetBuilder() or nil
        if IsValid(builder) then
            self.SentryBusterPendingByBuilder[builder] = 0
        end
    end
end

function RUNTIME:OnManagedTankDestroyed(spawnState, tank, attacker)
    if spawnState then
        spawnState.Alive = math.max(0, (spawnState.Alive or 1) - 1)
        self:ApplyDeathRespawnDelay(spawnState)
        if spawnState.CompletedSpawned and spawnState.Alive <= 0 then
            spawnState.CompletedDead = true
        end
    end

    local currency = tonumber(IsValid(tank) and tank.TF_MVM_CurrencyValue or 0) or 0
    if currency > 0 and IsValid(tank) then
        DropCurrencyPacks(tank:GetPos(), currency)
    end

    self.ManagedTanks[tank] = nil
end

function RUNTIME:OnManagedTankDeployed(spawnState, tank)
    self.ManagedTanks[tank] = nil
    self:FailMission("tank_deployed")
end

function RUNTIME:HandleManagedBotDeath(bot, attacker)
    local info = self.ManagedBots[bot]
    if not info then return end

    self.ManagedBots[bot] = nil
    DetachBotFromManagedSquad(bot)
    if IsSentryBusterObjective((info and info.objective) or bot.TF_MVM_Objective or "") or TrimLower(bot:GetPlayerClass()) == "sentrybuster" then
        self:OnSentryBusterKilled()
    end

    local st = info.spawn
    if st then
        st.Alive = math.max(0, (st.Alive or 1) - 1)
        self:ApplyDeathRespawnDelay(st)
        if st.CompletedSpawned and st.Alive <= 0 then
            st.CompletedDead = true
        end
    end

    local currency = tonumber(bot.TF_MVM_CurrencyValue or 0) or 0
    if currency > 0 then
        DropCurrencyPacks(bot:GetPos(), currency)
    end

    timer.Simple(0.2, function()
        if IsValid(bot) then
            RemoveManagedBotEntity(bot, "MvM bot removed")
        end
    end)
end

function RUNTIME:HandleManagedBotDisconnected(bot)
    local info = self.ManagedBots[bot]
    if not info then return end

    self.ManagedBots[bot] = nil
    DetachBotFromManagedSquad(bot)

    local st = info.spawn
    if st then
        st.Alive = math.max(0, (st.Alive or 1) - 1)
        self:ApplyDeathRespawnDelay(st)
        if st.CompletedSpawned and st.Alive <= 0 then
            st.CompletedDead = true
        end
    end
end

function RUNTIME:Tick()
    if not self.Active then return end
    if not self.WaveActive then return end
    if not self.CurrentWaveState then return end

    self:UpdateSentryBusterKillTimeThreshold(CurTime())

    for bot, info in pairs(self.ManagedBots) do
        if not IsValid(bot) then
            self.ManagedBots[bot] = nil
            DetachBotFromManagedSquad(bot)
            local st = info and info.spawn
            if st then
                st.Alive = math.max(0, (st.Alive or 1) - 1)
                self:ApplyDeathRespawnDelay(st)
                if st.CompletedSpawned and st.Alive <= 0 then
                    st.CompletedDead = true
                end
            end
        elseif (not bot:IsPlayer()) and bot:Health() <= 0 then
            self:HandleManagedBotDeath(bot, bot)
        end
    end

    for ent, info in pairs(self.ManagedEntities) do
        if not IsValid(ent) then
            self:HandleManagedEntityRemoved(ent)
        elseif ent.Health and ent:Health() <= 0 then
            self:HandleManagedEntityRemoved(ent)
        end
    end

    local now = CurTime()

    for _, st in ipairs(self.CurrentWaveState.Spawns) do
        self:UpdateSpawnState(st, now)
    end
    self:UpdateWaveStatusState(false)

    if self:CheckWaveCompleted() then
        self:CompleteWave()
    end
end

hook.Add("Think", "TF_MVM_RuntimeThink", function()
    if not TF_MVM or not TF_MVM.Runtime then return end
    TF_MVM.Runtime:Tick()
end)

hook.Add("PlayerDeath", "TF_MVM_ManagedBotDeath", function(victim, inflictor, attacker)
    if not TF_MVM or not TF_MVM.Runtime then return end
    if not IsValid(victim) then return end

    local sentry = ResolveSentryFromKillSources(attacker, inflictor)
    if IsValid(sentry) then
        TF_MVM.Runtime:OnDefenderSentryKill(sentry, victim)
    end

    if not victim.TF_MVMManaged then return end

    TF_MVM.Runtime:HandleManagedBotDeath(victim, attacker)
end)

hook.Add("OnNPCKilled", "TF_MVM_SentryKillForBuster", function(npc, attacker, inflictor)
    if not TF_MVM or not TF_MVM.Runtime then return end
    if not IsValid(npc) then return end
    local sentry = ResolveSentryFromKillSources(attacker, inflictor)
    if IsValid(sentry) then
        TF_MVM.Runtime:OnDefenderSentryKill(sentry, npc)
    end
end)

hook.Add("EntityTakeDamage", "TF_MVM_SentryDamageForBuster", function(target, dmginfo)
    if not TF_MVM or not TF_MVM.Runtime then return end
    if not IsValid(target) or not dmginfo then return end

    local sentry = ResolveSentryFromKillSources(dmginfo:GetAttacker(), dmginfo:GetInflictor())
    if not IsValid(sentry) then return end

    TF_MVM.Runtime:OnDefenderSentryDamage(sentry, target, dmginfo:GetDamage())
end)

hook.Add("PlayerDisconnected", "TF_MVM_ManagedBotDisconnect", function(ply)
    if not TF_MVM or not TF_MVM.Runtime then return end
    if not IsValid(ply) then return end

    TF_MVM.Runtime:HandleManagedBotDisconnected(ply)
    if TF_MVM.Runtime.ReadyPlayers then
        TF_MVM.Runtime.ReadyPlayers[ply] = nil
    end
    if TF_MVM.Runtime:IsManagedActive() and TF_MVM.Runtime:IsSetupPhase() then
        TF_MVM.Runtime:RecomputeSetupCountdown()
        TF_MVM.Runtime:PushState()
    end
end)

hook.Add("EntityRemoved", "TF_MVM_ManagedEntityRemoved", function(ent)
    if not TF_MVM or not TF_MVM.Runtime then return end
    TF_MVM.Runtime:HandleManagedEntityRemoved(ent)
    if IsValid(ent) and ent:GetClass() == "obj_sentrygun" then
        TF_MVM.Runtime:EnsureSentryBusterState()
        TF_MVM.Runtime.SentryBusterKillsBySentry[ent] = nil
        TF_MVM.Runtime.SentryBusterDamageBySentry[ent] = nil
        TF_MVM.Runtime.SentryBusterKillWindowStartBySentry[ent] = nil
    end
end)

hook.Add("PlayerChangedTeam", "TF_MVM_ReadyStateTeamChange", function(ply)
    if not TF_MVM or not TF_MVM.Runtime then return end
    if TF_MVM.Runtime.ReadyPlayers then
        TF_MVM.Runtime.ReadyPlayers[ply] = nil
    end
    if IsValid(ply) and ply:IsPlayer() then
        ply:SetNWBool("TF_MVM_Ready", false)
    end
    if TF_MVM.Runtime:IsManagedActive() and TF_MVM.Runtime:IsSetupPhase() then
        TF_MVM.Runtime:RecomputeSetupCountdown()
        TF_MVM.Runtime:PushState()
    end
end)

return RUNTIME

TF_MVM = TF_MVM or {}

local PARSER = {}
TF_MVM.POPParser = PARSER
local CV_POP_STRICT = SERVER and CreateConVar("tf_mvm_pop_strict", "1", FCVAR_ARCHIVE, "Use TF2-strict MvM POP parsing (reject unknown/invalid keys).") or nil

local CANON = {
    ["waveschedule"] = "WaveSchedule",
    ["templates"] = "Templates",
    ["wave"] = "Wave",
    ["wavespawn"] = "WaveSpawn",
    ["mission"] = "Mission",
    ["tfbot"] = "TFBot",
    ["tank"] = "Tank",
    ["sentrygun"] = "SentryGun",
    ["mob"] = "Mob",
    ["randomchoice"] = "RandomChoice",
    ["squad"] = "Squad",
    ["startwaveoutput"] = "StartWaveOutput",
    ["doneoutput"] = "DoneOutput",
    ["initwaveoutput"] = "InitWaveOutput",
    ["firstspawnoutput"] = "FirstSpawnOutput",
    ["lastspawnoutput"] = "LastSpawnOutput",
    ["firstspawnoutputput"] = "FirstSpawnOutput",
    ["firstspawnoutputputt"] = "FirstSpawnOutput",
    ["startwavewarningsound"] = "StartWaveWarningSound",
    ["firstspawnwarningsound"] = "FirstSpawnWarningSound",
    ["lastspawnwarningsound"] = "LastSpawnWarningSound",
    ["donewarningsound"] = "DoneWarningSound",
    ["waitforallspawned"] = "WaitForAllSpawned",
    ["waitforalldead"] = "WaitForAllDead",
    ["waitbetweenspawns"] = "WaitBetweenSpawns",
    ["waitbetweenspawnsafterdeath"] = "WaitBetweenSpawnsAfterDeath",
    ["waitbeforestarting"] = "WaitBeforeStarting",
    ["waitwhendone"] = "WaitWhenDone",
    ["spawncount"] = "SpawnCount",
    ["maxactive"] = "MaxActive",
    ["totalcount"] = "TotalCount",
    ["totalcurrency"] = "TotalCurrency",
    ["money"] = "TotalCurrency",
    ["startingcurrency"] = "StartingCurrency",
    ["where"] = "Where",
    ["target"] = "Target",
    ["action"] = "Action",
    ["param"] = "Param",
    ["delay"] = "Delay",
    ["support"] = "Support",
    ["randomspawn"] = "RandomSpawn",
    ["name"] = "Name",
    ["class"] = "Class",
    ["objective"] = "Objective",
    ["beginatwave"] = "BeginAtWave",
    ["runforthismanywaves"] = "RunForThisManyWaves",
    ["desiredcount"] = "DesiredCount",
    ["cooldown"] = "CooldownTime",
    ["attributes"] = "Attributes",
    ["extattr"] = "Attributes",
    ["item"] = "Item",
    ["behaviormodifiers"] = "BehaviorModifiers",
    ["maxvisionrange"] = "MaxVisionRange",
    ["template"] = "Template",
    ["teleportwhere"] = "TeleportWhere",
    ["autojumpmin"] = "AutoJumpMin",
    ["autojumpmax"] = "AutoJumpMax",
    ["scale"] = "Scale",
    ["pathtrack"] = "PathTrack",
    ["startingpathtracknode"] = "PathTrack",
    ["health"] = "Health",
    ["speed"] = "Speed",
    ["onkilledoutput"] = "OnKilledOutput",
    ["onbombdroppedoutput"] = "OnBombDroppedOutput",
    ["onspawnoutput"] = "OnSpawnOutput",
    ["cooldowntime"] = "CooldownTime",
    ["initialcooldown"] = "InitialCooldown",
    ["count"] = "Count",
    ["checkpoint"] = "Checkpoint",
    ["eventchangeattributes"] = "EventChangeAttributes",
    ["itemname"] = "ItemName",
    ["shouldpreservesquad"] = "ShouldPreserveSquad",
    ["tags"] = "Tag",
}

local APPEND_KEYS = {
    ["wave"] = true,
    ["wavespawn"] = true,
    ["mission"] = true,
    ["startwaveoutput"] = true,
    ["doneoutput"] = true,
    ["initwaveoutput"] = true,
    ["firstspawnoutput"] = true,
    ["onkilledoutput"] = true,
    ["onbombdroppedoutput"] = true,
    ["onspawnoutput"] = true,
    ["where"] = true,
    ["item"] = true,
    ["attributes"] = true,
}

local function CanonKey(key)
    if not isstring(key) then return key end
    return CANON[string.lower(key)] or key
end

local function IsArray(t)
    return istable(t) and t[1] ~= nil
end

local function ToArray(v)
    if v == nil then return {} end
    if IsArray(v) then return v end
    return { v }
end

local function AddValue(obj, key, value)
    key = CanonKey(key)

    local existing = obj[key]
    if existing == nil then
        obj[key] = value
        return
    end

    if IsArray(existing) then
        table.insert(existing, value)
        return
    end

    obj[key] = { existing, value }
end

local function RemoveComments(raw)
    local out = {}
    for line in string.gmatch(raw or "", "[^\r\n]+") do
        local inQuote = false
        local escaped = false
        local buf = {}
        local i = 1
        while i <= #line do
            local ch = string.sub(line, i, i)
            local nx = string.sub(line, i + 1, i + 1)

            if not inQuote and ch == "/" and nx == "/" then
                break
            end

            buf[#buf + 1] = ch

            if ch == "\\" and not escaped then
                escaped = true
            else
                if ch == "\"" and not escaped then
                    inQuote = not inQuote
                end
                escaped = false
            end

            i = i + 1
        end

        local cleaned = string.Trim(table.concat(buf))
        if cleaned ~= "" then
            out[#out + 1] = cleaned
        end
    end
    return table.concat(out, "\n")
end

local function Tokenize(raw)
    local tokens = {}
    local i = 1

    while i <= #raw do
        local ch = string.sub(raw, i, i)

        if string.match(ch, "%s") then
            i = i + 1
        elseif ch == "{" or ch == "}" then
            tokens[#tokens + 1] = ch
            i = i + 1
        elseif ch == "\"" then
            local j = i + 1
            local buf = {}
            local escaped = false
            while j <= #raw do
                local c = string.sub(raw, j, j)
                if c == "\"" and not escaped then
                    break
                end
                if c == "\\" and not escaped then
                    escaped = true
                    buf[#buf + 1] = c
                else
                    escaped = false
                    buf[#buf + 1] = c
                end
                j = j + 1
            end
            tokens[#tokens + 1] = table.concat(buf)
            i = j + 1
        else
            local j = i
            while j <= #raw do
                local c = string.sub(raw, j, j)
                if string.match(c, "%s") or c == "{" or c == "}" then
                    break
                end
                j = j + 1
            end
            tokens[#tokens + 1] = string.sub(raw, i, j - 1)
            i = j
        end
    end

    return tokens
end

local function ParseBlock(tokens, idx)
    local obj = {}
    local i = idx

    while i <= #tokens do
        local token = tokens[i]

        if token == "}" then
            return obj, i + 1
        end

        if string.lower(token) == "#base" then
            local basePath = tokens[i + 1] or ""
            local list = obj["#base"]
            if not list then
                obj["#base"] = { basePath }
            else
                table.insert(list, basePath)
            end
            i = i + 2
        else
            local key = token
            local nextToken = tokens[i + 1]

            if nextToken == "{" then
                local child
                child, i = ParseBlock(tokens, i + 2)
                AddValue(obj, key, child)
            else
                AddValue(obj, key, nextToken or "")
                i = i + 2
            end
        end
    end

    return obj, i
end

local function DirName(path)
    path = string.Replace(path or "", "\\", "/")
    local dir = string.match(path, "^(.*)/[^/]+$")
    return dir or ""
end

local function JoinPath(a, b)
    a = string.Replace(tostring(a or ""), "\\", "/")
    b = string.Replace(tostring(b or ""), "\\", "/")

    if a == "" then return b end
    if b == "" then return a end

    if string.sub(a, -1) == "/" then
        return a .. b
    end
    return a .. "/" .. b
end

local function IsAbsolutePath(path)
    if not isstring(path) then return false end
    if string.find(path, "^[A-Za-z]:[/\\]") then return true end
    if string.StartWith(path, "\\\\") then return true end
    if string.StartWith(path, "/") then return true end
    return false
end

local function DeepCopy(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end

    local out = {}
    seen[v] = out
    for k, vv in pairs(v) do
        out[k] = DeepCopy(vv, seen)
    end
    return out
end

local function MergeValue(base, child, parentKey)
    if child == nil then
        return DeepCopy(base)
    end

    if type(base) ~= "table" or type(child) ~= "table" then
        return DeepCopy(child)
    end

    local keyLower = string.lower(tostring(parentKey or ""))

    if APPEND_KEYS[keyLower] then
        local out = {}
        for _, v in ipairs(ToArray(base)) do
            out[#out + 1] = DeepCopy(v)
        end
        for _, v in ipairs(ToArray(child)) do
            out[#out + 1] = DeepCopy(v)
        end
        return out
    end

    if IsArray(base) or IsArray(child) then
        local out = {}
        for _, v in ipairs(ToArray(base)) do
            out[#out + 1] = DeepCopy(v)
        end
        for _, v in ipairs(ToArray(child)) do
            out[#out + 1] = DeepCopy(v)
        end
        return out
    end

    local out = DeepCopy(base)
    for k, v in pairs(child) do
        out[k] = MergeValue(out[k], v, k)
    end

    return out
end

local function ReadByScope(path, scope)
    if TF_MVM and TF_MVM.MissionLookup and TF_MVM.MissionLookup.ReadMission then
        return TF_MVM.MissionLookup:ReadMission(path, scope)
    end
    if scope == "ABS" and io and io.open then
        local f = io.open(path, "rb")
        if not f then return nil end
        local c = f:read("*a")
        f:close()
        return c
    end
    return file.Read(path, scope)
end

local function ResolveBasePath(currentPath, basePath)
    basePath = string.Replace(basePath or "", "\\", "/")
    if IsAbsolutePath(basePath) then
        return basePath
    end
    local dir = DirName(currentPath)
    return JoinPath(dir, basePath)
end

local function ParseFileRecursive(path, scope, stack, cache, warnings)
    local cacheKey = scope .. "|" .. string.lower(path)
    if cache[cacheKey] then
        return DeepCopy(cache[cacheKey])
    end

    if stack[cacheKey] then
        warnings[#warnings + 1] = "Cycle detected in #base include: " .. path
        return {}
    end
    stack[cacheKey] = true

    local raw = ReadByScope(path, scope)
    if not raw then
        warnings[#warnings + 1] = "Failed to read POP: [" .. scope .. "] " .. path
        stack[cacheKey] = nil
        return {}
    end

    local cleaned = RemoveComments(raw)
    local tokens = Tokenize(cleaned)
    local parsed = ParseBlock(tokens, 1)

    local bases = parsed["#base"]
    parsed["#base"] = nil

    local merged = {}

    for _, basePath in ipairs(ToArray(bases)) do
        if isstring(basePath) and basePath ~= "" then
            local resolved = ResolveBasePath(path, basePath)
            local baseScope = scope
            if IsAbsolutePath(resolved) then
                baseScope = "ABS"
            end
            local baseTree = ParseFileRecursive(resolved, baseScope, stack, cache, warnings)
            merged = MergeValue(merged, baseTree)
        end
    end

    merged = MergeValue(merged, parsed)

    cache[cacheKey] = DeepCopy(merged)
    stack[cacheKey] = nil

    return merged
end

local function FindWaveSchedule(tree)
    if tree.WaveSchedule then
        return tree.WaveSchedule
    end

    for _, v in pairs(tree) do
        if istable(v) and v.WaveSchedule then
            return v.WaveSchedule
        end
    end

    return nil
end

local function CollectTemplates(templatesNode)
    local out = {}

    if not istable(templatesNode) then
        return out
    end

    if IsArray(templatesNode) then
        for _, entry in ipairs(templatesNode) do
            local merged = CollectTemplates(entry)
            for k, v in pairs(merged) do
                out[string.lower(k)] = v
            end
        end
        return out
    end

    for k, v in pairs(templatesNode) do
        if isstring(k) and istable(v) then
            out[string.lower(k)] = v
        end
    end

    return out
end

local function NormalizeOutputs(block)
    return ToArray(block)
end

local function NormalizeWaveSpawn(spawn)
    if not istable(spawn) then return end
    spawn.StartWaveOutput = NormalizeOutputs(spawn.StartWaveOutput)
    spawn.DoneOutput = NormalizeOutputs(spawn.DoneOutput)
    spawn.InitWaveOutput = NormalizeOutputs(spawn.InitWaveOutput)
    spawn.FirstSpawnOutput = NormalizeOutputs(spawn.FirstSpawnOutput)
    spawn.OnSpawnOutput = NormalizeOutputs(spawn.OnSpawnOutput)
end

local STRICT_SCHEMA = {
    WaveSchedule = {
        StartingCurrency = true,
        RespawnWaveTime = true,
        CanBotsAttackWhileInSpawnRoom = true,
        FixedRespawnWaveTime = true,
        Advanced = true,
        AddSentryBusterWhenDamageDealtExceeds = true,
        AddSentryBusterWhenKillCountExceeds = true,
        AddSentryBusterWhenKillTimeExceeds = true,
        Templates = true,
        Mission = true,
        Wave = true,
    },
    Wave = {
        Checkpoint = true,
        Sound = true,
        Description = true,
        WaitWhenDone = true,
        StartWaveOutput = true,
        DoneOutput = true,
        InitWaveOutput = true,
        Mission = true,
        WaveSpawn = true,
    },
    WaveSpawn = {
        Name = true,
        WaitForAllSpawned = true,
        WaitForAllDead = true,
        WaitBeforeStarting = true,
        WaitBetweenSpawns = true,
        WaitBetweenSpawnsAfterDeath = true,
        TotalCurrency = true,
        TotalCount = true,
        MaxActive = true,
        SpawnCount = true,
        Support = true,
        RandomSpawn = true,
        Where = true,
        StartWaveWarningSound = true,
        FirstSpawnWarningSound = true,
        LastSpawnWarningSound = true,
        DoneWarningSound = true,
        StartWaveOutput = true,
        FirstSpawnOutput = true,
        LastSpawnOutput = true,
        DoneOutput = true,
        FirstSpawnOutput = true,
        TFBot = true,
        Tank = true,
        SentryGun = true,
        Squad = true,
        RandomChoice = true,
        Mob = true,
    },
    Mission = {
        Objective = true,
        InitialCooldown = true,
        CooldownTime = true,
        BeginAtWave = true,
        RunForThisManyWaves = true,
        DesiredCount = true,
        Where = true,
        TFBot = true,
    },
    TFBot = {
        Class = true,
        Name = true,
        ClassIcon = true,
        Skill = true,
        Health = true,
        Scale = true,
        WeaponRestrictions = true,
        CharacterAttributes = true,
        Attributes = true,
        Item = true,
        ItemAttributes = true,
        EventChangeAttributes = true,
        Action = true,
        Tag = true,
        BehaviorModifiers = true,
        MaxVisionRange = true,
        AutoJumpMin = true,
        AutoJumpMax = true,
        Template = true,
        TeleportWhere = true,
    },
    EventChangeAttributes = {},
    Tank = {
        Name = true,
        Health = true,
        Speed = true,
        StartingPathTrackNode = true,
        PathTrack = true,
        Skin = true,
        Scale = true,
        OnKilledOutput = true,
        OnBombDroppedOutput = true,
        OnSpawnOutput = true,
    },
}

local REQUIRED_KEYS = {
    WaveSchedule = { "Wave" },
    WaveSpawn = { "TotalCount" },
}

local function StrictEnabled()
    if not CV_POP_STRICT then return true end
    return CV_POP_STRICT:GetBool()
end

local function ChildNodeContext(parentCtx, key)
    if parentCtx == "WaveSchedule" and key == "Wave" then return "Wave" end
    if parentCtx == "WaveSchedule" and key == "Mission" then return "Mission" end
    if parentCtx == "Wave" and key == "WaveSpawn" then return "WaveSpawn" end
    if parentCtx == "Wave" and key == "Mission" then return "Mission" end
    if parentCtx == "WaveSpawn" and key == "TFBot" then return "TFBot" end
    if parentCtx == "WaveSpawn" and key == "Tank" then return "Tank" end
    if parentCtx == "TFBot" and key == "EventChangeAttributes" then return "EventChangeAttributes" end
    if parentCtx == "EventChangeAttributes" then return "TFBot" end
    if key == "WaveSchedule" then return "WaveSchedule" end
    return nil
end

local function ValidateStrictNode(node, ctx, path, errors)
    if not istable(node) then return end
    path = path or ctx
    local schema = STRICT_SCHEMA[ctx]

    if schema ~= nil then
        for key, value in pairs(node) do
            if isstring(key) then
                local isAllowed = schema[key] == true
                if not isAllowed and CANON[string.lower(key)] ~= nil then
                    isAllowed = true
                end
                if not isAllowed and ctx == "EventChangeAttributes" and istable(value) then
                    isAllowed = true
                end
                if not isAllowed then
                    errors[#errors + 1] = string.format("%s: unknown key '%s' for %s", tostring(path), tostring(key), tostring(ctx))
                end
            end
        end
    end

    local required = REQUIRED_KEYS[ctx]
    if required then
        for _, req in ipairs(required) do
            if node[req] == nil then
                errors[#errors + 1] = string.format("%s: missing required key '%s' for %s", tostring(path), tostring(req), tostring(ctx))
            end
        end
    end

    for key, value in pairs(node) do
        if not isstring(key) then continue end
        local childCtx = ChildNodeContext(ctx, key)
        if not childCtx then continue end
        for idx, child in ipairs(ToArray(value)) do
            ValidateStrictNode(child, childCtx, string.format("%s.%s[%d]", tostring(path), tostring(key), idx), errors)
        end
    end
end

local function ValidateStrictMission(mission)
    local errors = {}
    local schedule = mission and mission.WaveSchedule
    ValidateStrictNode(schedule, "WaveSchedule", "WaveSchedule", errors)
    return errors
end

function PARSER:Parse(path, scope)
    scope = scope or "GAME"

    local warnings = {}
    local tree = ParseFileRecursive(path, scope, {}, {}, warnings)
    local schedule = FindWaveSchedule(tree)

    if not schedule then
        return {
            ok = false,
            error = "missing_waveschedule",
            warnings = warnings,
            tree = tree,
        }
    end

    local mission = {
        Path = path,
        Scope = scope,
        Tree = tree,
        WaveSchedule = schedule,
        Templates = CollectTemplates(schedule.Templates),
        GlobalMissions = ToArray(schedule.Mission),
        Waves = ToArray(schedule.Wave),
        StartingCurrency = tonumber(schedule.StartingCurrency or 600) or 600,
        Warnings = warnings,
    }

    for _, wave in ipairs(mission.Waves) do
        wave.WaveSpawn = ToArray(wave.WaveSpawn)
        wave.Mission = ToArray(wave.Mission)

        wave.StartWaveOutput = NormalizeOutputs(wave.StartWaveOutput)
        wave.DoneOutput = NormalizeOutputs(wave.DoneOutput)
        wave.InitWaveOutput = NormalizeOutputs(wave.InitWaveOutput)
        wave.FirstSpawnOutput = NormalizeOutputs(wave.FirstSpawnOutput)

        for _, spawn in ipairs(wave.WaveSpawn) do
            NormalizeWaveSpawn(spawn)
        end
    end

    if StrictEnabled() then
        local strictErrors = ValidateStrictMission(mission)
        if #strictErrors > 0 then
            return {
                ok = false,
                error = "strict_validation_failed: " .. strictErrors[1],
                warnings = warnings,
                strictErrors = strictErrors,
                tree = tree,
            }
        end
    end

    mission.ok = true
    return mission
end

return PARSER

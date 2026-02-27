TF_MVM = TF_MVM or {}

local LOOKUP = {}
TF_MVM.MissionLookup = LOOKUP

local function DebugEnabled()
    local c = GetConVar("tf_mvm_debug")
    return c and c:GetBool()
end

local function DebugPrint(...)
    if not DebugEnabled() then return end
    print("[TF_MVM][Lookup]", ...)
end

local function IsArray(t)
    return istable(t) and t[1] ~= nil
end

local function ReadAbsolute(path)
    if not isstring(path) or path == "" then return nil end
    if not io or not io.open then return nil end

    local f = io.open(path, "rb")
    if not f then return nil end

    local content = f:read("*a")
    f:close()
    return content
end

local function ExistsAbsolute(path)
    return ReadAbsolute(path) ~= nil
end

local function FileExists(path, scope)
    if scope == "ABS" then
        return ExistsAbsolute(path)
    end
    return file.Exists(path, scope)
end

local function ReadFile(path, scope)
    if scope == "ABS" then
        return ReadAbsolute(path)
    end
    return file.Read(path, scope)
end

local function IsAbsolutePath(path)
    if not isstring(path) then return false end
    if string.find(path, "^[A-Za-z]:[/\\]") then return true end
    if string.StartWith(path, "\\\\") then return true end
    if string.StartWith(path, "/") then return true end
    return false
end

local function NormalizePath(path)
    path = tostring(path or "")
    path = string.Replace(path, "\\", "/")
    path = string.Trim(path)
    return path
end

local function JoinPath(a, b)
    a = NormalizePath(a)
    b = NormalizePath(b)
    if a == "" then return b end
    if b == "" then return a end
    if string.sub(a, -1) == "/" then
        return a .. b
    end
    return a .. "/" .. b
end

local DIFFICULTY_ORDER = {
    normal = 1,
    nor = 1,
    intermediate = 2,
    int = 2,
    advanced = 3,
    adv = 3,
    expert = 4,
    exp = 4,
}

local function DifficultyRank(name)
    local lower = string.lower(name or "")
    for token, rank in pairs(DIFFICULTY_ORDER) do
        if string.find(lower, "_" .. token, 1, true) or string.find(lower, "-" .. token, 1, true) then
            return rank
        end
    end
    return 5
end

local function CandidateSort(a, b)
    if a.priority ~= b.priority then
        return a.priority < b.priority
    end

    if a.diffRank ~= b.diffRank then
        return a.diffRank < b.diffRank
    end

    return string.lower(a.path) < string.lower(b.path)
end

local function AddCandidate(candidates, seen, searched, path, scope, reason, priority)
    path = NormalizePath(path)
    if path == "" then return end

    local key = scope .. "|" .. string.lower(path)
    if seen[key] then
        return
    end
    seen[key] = true

    table.insert(searched, scope .. ":" .. path)

    if not FileExists(path, scope) then
        return
    end

    local filename = string.GetFileFromFilename(path)

    table.insert(candidates, {
        path = path,
        scope = scope,
        reason = reason,
        priority = priority,
        diffRank = DifficultyRank(filename),
        filename = filename,
    })
end

local function AddWildcardCandidates(candidates, seen, searched, folder, pattern, scope, reason, priority)
    folder = NormalizePath(folder)
    pattern = NormalizePath(pattern)

    local query
    if folder == "" then
        query = pattern
    else
        query = JoinPath(folder, pattern)
    end
    table.insert(searched, scope .. ":" .. query)

    local wildcardLua = "^" .. string.gsub(string.lower(pattern), "([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1")
    wildcardLua = string.gsub(wildcardLua, "%*", ".*")
    wildcardLua = wildcardLua .. "$"

    local files = {}

    if scope == "GAME" or scope == "DATA" then
        local found = file.Find(query, scope)
        if found and found[1] then
            files = found
        end
    elseif scope == "ABS" and io and io.popen then
        local absFolder = folder
        local cmd
        if system and system.IsWindows and system.IsWindows() then
            cmd = 'cmd /c dir /b /a:-d "' .. absFolder .. '"'
        else
            cmd = 'ls -1 "' .. absFolder .. '"'
        end

        local p = io.popen(cmd)
        if p then
            for line in p:lines() do
                files[#files + 1] = line
            end
            p:close()
        end
    end

    for _, name in ipairs(files) do
        local nameLower = string.lower(name or "")
        if string.match(nameLower, wildcardLua) then
            local candidatePath = JoinPath(folder, name)
            AddCandidate(candidates, seen, searched, candidatePath, scope, reason, priority)
        end
    end
end

local function BuildNameVariants(mapName)
    local out = {}
    local seen = {}

    local function add(v)
        v = NormalizePath(v)
        if v == "" then return end
        local k = string.lower(v)
        if seen[k] then return end
        seen[k] = true
        out[#out + 1] = v
    end

    add(mapName)

    if string.StartWith(string.lower(mapName), "mvm_") then
        add(string.sub(mapName, 5))
    end

    return out
end

local function BuildExternalRoots(root)
    local roots = {}
    local seen = {}

    local function add(v)
        v = NormalizePath(v)
        if v == "" then return end
        local key = string.lower(v)
        if seen[key] then return end
        seen[key] = true
        roots[#roots + 1] = v
    end

    add(root)

    -- Many local TF2 missions exist under tf/download/scripts/population.
    local lower = string.lower(root or "")
    if string.find(lower, "/scripts/population", 1, true) then
        add(string.gsub(root, "/scripts/population", "/download/scripts/population"))
    end

    return roots
end

function LOOKUP:ReadMission(path, scope)
    return ReadFile(path, scope)
end

function LOOKUP:GetCurrentMapName()
    local mapName = game.GetMap() or ""
    return string.lower(mapName)
end

function LOOKUP:FindMission(opts)
    opts = opts or {}

    local mapName = string.lower(opts.map or self:GetCurrentMapName())
    local override = opts.override or ""
    local cvarOverride = GetConVar("tf_mvm_mission_override")
    if override == "" and cvarOverride then
        override = cvarOverride:GetString() or ""
    end

    local externalRoot = ""
    local extCvar = GetConVar("tf_mvm_external_pop_root")
    if extCvar then
        externalRoot = NormalizePath(extCvar:GetString() or "")
    end

    local candidates = {}
    local seen = {}
    local searched = {}

    if override ~= "" then
        override = NormalizePath(override)

        if IsAbsolutePath(override) then
            AddCandidate(candidates, seen, searched, override, "ABS", "override_absolute", 0)
        else
            AddCandidate(candidates, seen, searched, override, "GAME", "override_game", 0)
            AddCandidate(candidates, seen, searched, override, "DATA", "override_data", 0)

            AddCandidate(candidates, seen, searched, JoinPath("scripts/population", override), "GAME", "override_game_population", 0)
            AddCandidate(candidates, seen, searched, JoinPath("tf/population", override), "DATA", "override_data_population", 0)
        end
    end

    local nameVariants = BuildNameVariants(mapName)

    for _, name in ipairs(nameVariants) do
        AddCandidate(candidates, seen, searched, JoinPath("scripts/population", name .. ".pop"), "GAME", "game_exact", 1)
    end

    for _, name in ipairs(nameVariants) do
        AddWildcardCandidates(candidates, seen, searched, "scripts/population", name .. "_*.pop", "GAME", "game_wildcard", 2)
    end

    for _, name in ipairs(nameVariants) do
        AddCandidate(candidates, seen, searched, JoinPath("tf/population", name .. ".pop"), "DATA", "data_exact", 3)
    end

    for _, name in ipairs(nameVariants) do
        AddWildcardCandidates(candidates, seen, searched, "tf/population", name .. "_*.pop", "DATA", "data_wildcard", 4)
    end

    if externalRoot ~= "" then
        local externalRoots = BuildExternalRoots(externalRoot)
        if not io or not io.open then
            table.insert(searched, "ABS:" .. externalRoot .. " (unavailable: io.open disabled)")
        else
            for _, root in ipairs(externalRoots) do
                for _, name in ipairs(nameVariants) do
                    AddCandidate(candidates, seen, searched, JoinPath(root, name .. ".pop"), "ABS", "external_exact", 5)
                end

                for _, name in ipairs(nameVariants) do
                    AddWildcardCandidates(candidates, seen, searched, root, name .. "_*.pop", "ABS", "external_wildcard", 6)
                end
            end
        end
    end

    table.sort(candidates, CandidateSort)

    if #candidates == 0 then
        return {
            ok = false,
            error = "no_mission_found",
            searched = searched,
            map = mapName,
        }
    end

    local winner = candidates[1]
    DebugPrint("Selected mission", winner.path, "scope", winner.scope, "reason", winner.reason)

    return {
        ok = true,
        path = winner.path,
        scope = winner.scope,
        reason = winner.reason,
        filename = winner.filename,
        candidates = candidates,
        searched = searched,
        map = mapName,
    }
end

return LOOKUP

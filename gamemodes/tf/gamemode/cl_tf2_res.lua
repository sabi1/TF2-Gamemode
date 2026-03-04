-- Minimal Valve .res (KeyValues) reader for client UI layout mirroring.
TF2Res = TF2Res or {}

local cache = {}
local loading = {}

local function isWindows()
	return system and system.IsWindows and system.IsWindows() or false
end

local function isLinux()
	return system and system.IsLinux and system.IsLinux() or false
end

local function isOSX()
	return system and system.IsOSX and system.IsOSX() or false
end

local function evalConditionToken(tok)
	if not isstring(tok) then return nil end
	local inner = string.match(tok, "^%[(.+)%]$")
	if not inner then return nil end
	inner = string.Trim(inner)
	if inner == "" then return nil end

	local neg = false
	if string.StartWith(inner, "!") then
		neg = true
		inner = string.Trim(string.sub(inner, 2))
	end
	if string.StartWith(inner, "$") then
		inner = string.sub(inner, 2)
	end
	inner = string.upper(inner)

	local flags = {
		WIN32 = isWindows(),
		WINDOWS = isWindows(),
		X360 = false,
		LINUX = isLinux(),
		OSX = isOSX(),
		MAC = isOSX(),
		POSIX = isLinux() or isOSX(),
	}

	local value = flags[inner]
	if value == nil then
		value = false
	end
	return neg and (not value) or value
end

local function trimComments(text)
    text = string.gsub(text, "/%*.-%*/", "")
    text = string.gsub(text, "//[^\r\n]*", "")
    return text
end

local function trimBaseLines(text)
	if not isstring(text) or text == "" then return text end
	local out = {}
	for line in string.gmatch(text, "[^\r\n]+") do
		local t = string.Trim(line)
		if not string.find(string.lower(t), "^#base%s+") then
			out[#out + 1] = line
		end
	end
	return table.concat(out, "\n")
end

local function extractBasePaths(text)
	local out = {}
	if not isstring(text) or text == "" then return out end
	for quoted in string.gmatch(text, "#base%s+\"([^\"]+)\"") do
		out[#out + 1] = quoted
	end
	for unquoted in string.gmatch(text, "#base%s+([^\r\n]+)") do
		local cleaned = string.Trim(unquoted or "")
		if cleaned ~= "" and cleaned:sub(1, 1) ~= "\"" then
			out[#out + 1] = cleaned
		end
	end
	return out
end

local function normalizePath(path)
	if not isstring(path) then return nil end
	local p = string.Trim(path)
	if p == "" then return nil end
	p = string.Replace(p, "\\", "/")
	local segs = {}
	for seg in string.gmatch(p, "[^/]+") do
		if seg == "." then
			-- skip
		elseif seg == ".." then
			if #segs > 0 then table.remove(segs) end
		else
			segs[#segs + 1] = seg
		end
	end
	return table.concat(segs, "/")
end

local function dirname(path)
	if not isstring(path) then return "" end
	local p = string.Replace(path, "\\", "/")
	local idx = string.match(p, "^.*()/")
	if not idx then return "" end
	return string.sub(p, 1, idx - 1)
end

local function joinPath(base, rel)
	if not isstring(rel) or rel == "" then return nil end
	rel = string.Replace(rel, "\\", "/")
	if string.find(rel, "^[A-Za-z]:/") then
		return normalizePath(rel)
	end
	if string.sub(rel, 1, 1) == "/" then
		return normalizePath(string.sub(rel, 2))
	end
	if not isstring(base) or base == "" then
		return normalizePath(rel)
	end
	return normalizePath(base .. "/" .. rel)
end

local function deepMerge(baseTbl, overrideTbl)
	if not istable(baseTbl) then
		baseTbl = {}
	end
	if not istable(overrideTbl) then
		return baseTbl
	end
	for k, v in pairs(overrideTbl) do
		if istable(v) and istable(baseTbl[k]) then
			baseTbl[k] = deepMerge(baseTbl[k], v)
		elseif istable(v) then
			baseTbl[k] = deepMerge({}, v)
		else
			baseTbl[k] = v
		end
	end
	return baseTbl
end

local function cloneTable(tbl)
	if not istable(tbl) then return tbl end
	local out = {}
	for k, v in pairs(tbl) do
		out[k] = istable(v) and cloneTable(v) or v
	end
	return out
end

local function tokenize(text)
    local out = {}
    local i, n = 1, #text
    while i <= n do
        local c = string.sub(text, i, i)
        if c == " " or c == "\t" or c == "\r" or c == "\n" then
            i = i + 1
        elseif c == "{" or c == "}" then
            out[#out + 1] = c
            i = i + 1
        elseif c == "\"" then
            local j = i + 1
            local buf = {}
            while j <= n do
                local ch = string.sub(text, j, j)
                if ch == "\"" then
                    break
                end
                if ch == "\\" and j < n then
                    local nextCh = string.sub(text, j + 1, j + 1)
                    if nextCh == "\"" or nextCh == "\\" then
                        buf[#buf + 1] = nextCh
                        j = j + 2
                    else
                        buf[#buf + 1] = ch
                        j = j + 1
                    end
                else
                    buf[#buf + 1] = ch
                    j = j + 1
                end
            end
            out[#out + 1] = table.concat(buf)
            i = j + 1
        else
            local j = i
            while j <= n do
                local ch = string.sub(text, j, j)
                if ch == " " or ch == "\t" or ch == "\r" or ch == "\n" or ch == "{" or ch == "}" then
                    break
                end
                j = j + 1
            end
            out[#out + 1] = string.sub(text, i, j - 1)
            i = j
        end
    end
    return out
end

local function parseTokens(tokens, pos)
	local t = {}
	local i = pos
	while i <= #tokens do
		local key = tokens[i]
        if key == "}" then
            return t, i + 1
        end
        if key == "{" then
            i = i + 1
        else
			local val = tokens[i + 1]
			if val == "{" then
				local child
				child, i = parseTokens(tokens, i + 2)
				t[key] = child
			elseif val == nil then
				return t, i + 1
			else
				local j = i + 2
				local hasCond = false
				local pass = true
				while j <= #tokens do
					local cond = evalConditionToken(tokens[j])
					if cond == nil then break end
					hasCond = true
					pass = pass and cond
					j = j + 1
				end

				if (not hasCond) or pass then
					t[key] = val
				end
				i = j
			end
		end
	end
	return t, i
end

local function parseKeyValues(text)
    local tokens = tokenize(trimComments(text))
    if #tokens == 0 then return nil end

    local first = tokens[1]
    if first == "{" then
        local parsed = parseTokens(tokens, 2)
        return parsed
    end

    if tokens[2] == "{" then
        local parsed = parseTokens(tokens, 3)
        return {[first] = parsed}
    end

    return nil
end

local function getInsensitive(tbl, key)
    if not istable(tbl) or not key then return nil end
    if tbl[key] ~= nil then return tbl[key] end
    local needle = string.lower(tostring(key))
    for k, v in pairs(tbl) do
        if string.lower(tostring(k)) == needle then
            return v
        end
    end
    return nil
end

local function visitTables(tbl, fn)
    if not istable(tbl) then return nil end
    local found = fn(tbl)
    if found ~= nil then return found end
    for _, v in pairs(tbl) do
        if istable(v) then
            local nested = visitTables(v, fn)
            if nested ~= nil then return nested end
        end
    end
    return nil
end

function TF2Res.Load(path)
    if not isstring(path) or path == "" then return nil end
    local normalized = normalizePath(path) or path
    local key = string.lower(normalized)
    if cache[key] ~= nil then
        return cache[key]
    end
	if loading[key] then
		cache[key] = false
		return nil
	end
	loading[key] = true

    local text = file.Read(normalized, "GAME")
    if not isstring(text) or text == "" then
		loading[key] = nil
        cache[key] = false
        return nil
    end

	local merged = {}
	local basePaths = extractBasePaths(text)
	if #basePaths > 0 then
		local baseDir = dirname(normalized)
		for _, rawBase in ipairs(basePaths) do
			local resolved = joinPath(baseDir, rawBase)
			if resolved then
				local baseTree = TF2Res.Load(resolved)
				if istable(baseTree) then
					merged = deepMerge(merged, cloneTable(baseTree))
				end
			end
		end
	end

	local parsed = parseKeyValues(trimBaseLines(text))
	if istable(parsed) then
		merged = deepMerge(merged, parsed)
	end

	loading[key] = nil
    cache[key] = next(merged) ~= nil and merged or false
    return cache[key] or nil
end

function TF2Res.FindByKey(tree, key)
    if not istable(tree) or not isstring(key) then return nil end
    local needle = string.lower(key)
    local function match(tbl)
        for k, v in pairs(tbl) do
            if string.lower(tostring(k)) == needle and istable(v) then
                return v
            end
        end
        return nil
    end
    return visitTables(tree, match)
end

function TF2Res.FindByFieldName(tree, fieldName)
    if not istable(tree) or not isstring(fieldName) then return nil end
    local needle = string.lower(fieldName)
    return visitTables(tree, function(tbl)
        local val = getInsensitive(tbl, "fieldName")
        if isstring(val) and string.lower(val) == needle then
            return tbl
        end
        return nil
    end)
end

function TF2Res.GetString(node, key, default)
    local v = getInsensitive(node, key)
    if isstring(v) then return v end
    return default
end

function TF2Res.GetNumber(node, key, default)
    local v = getInsensitive(node, key)
    if isnumber(v) then return v end
    if not isstring(v) then return default end
    local num = tonumber(v)
    if num then return num end
    local extracted = string.match(v, "([%+%-]?%d+%.?%d*)$")
    return tonumber(extracted) or default
end

function TF2Res.GetColor(node, key, default)
    local v = getInsensitive(node, key)
    if not isstring(v) then return default end
    local r, g, b, a = string.match(v, "^(%d+)%s+(%d+)%s+(%d+)%s*(%d*)$")
    if not r or not g or not b then return default end
    local alpha = tonumber(a)
    return Color(tonumber(r), tonumber(g), tonumber(b), (alpha and alpha > 0) and alpha or 255)
end

function TF2Res.NormalizeImagePath(path)
    if not isstring(path) or path == "" then return nil end
    local out = string.Trim(path)
    out = string.Replace(out, "\\", "/")
    out = string.gsub(out, "^materials/", "")
    out = string.gsub(out, "^%./", "")
    while string.StartWith(out, "../") do
        out = string.sub(out, 4)
    end
    out = string.gsub(out, "%.vmt$", "")
    out = string.gsub(out, "%.vtf$", "")
    return out
end

function TF2Res.GetTextureID(node, key, fallbackPath)
	local raw = TF2Res.GetString(node, key, fallbackPath)
	local normalized = TF2Res.NormalizeImagePath(raw)
	if not normalized then
		return surface.GetTextureID(TF2Res.NormalizeImagePath(fallbackPath or "") or "")
	end
	return surface.GetTextureID(normalized)
end

function TF2Res.ParseCoord(raw, actualSize, default)
	if raw == nil then return default end
	if isnumber(raw) then return raw end
	if not isstring(raw) then return default end

	local v = string.Trim(raw)
	if v == "" then return default end

	local n = tonumber(v)
	if n ~= nil then
		return n
	end

	local center = string.match(v, "^c([%+%-]?%d*%.?%d*)$")
	if center ~= nil then
		local offs = tonumber(center)
		if center == "" or offs == nil then offs = 0 end
		if isnumber(actualSize) then
			return actualSize * 0.5 + offs
		end
		return offs
	end

	local right = string.match(v, "^r([%+%-]?%d*%.?%d*)$")
	if right ~= nil then
		local offs = tonumber(right)
		if right == "" or offs == nil then offs = 0 end
		if isnumber(actualSize) then
			return actualSize - offs
		end
		return -offs
	end

	return default
end

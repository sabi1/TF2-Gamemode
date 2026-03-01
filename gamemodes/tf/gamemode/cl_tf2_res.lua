-- Minimal Valve .res (KeyValues) reader for client UI layout mirroring.
TF2Res = TF2Res or {}

local cache = {}

local function trimComments(text)
    text = string.gsub(text, "/%*.-%*/", "")
    text = string.gsub(text, "//[^\r\n]*", "")
    return text
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
                t[key] = val
                i = i + 2
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
    local key = string.lower(path)
    if cache[key] ~= nil then
        return cache[key]
    end

    local text = file.Read(path, "GAME")
    if not isstring(text) or text == "" then
        cache[key] = false
        return nil
    end

    local parsed = parseKeyValues(text)
    cache[key] = parsed or false
    return parsed
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

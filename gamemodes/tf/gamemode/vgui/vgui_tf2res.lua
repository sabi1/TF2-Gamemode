if SERVER then
    AddCSLuaFile()
    return
end

TF2Res = TF2Res or {}
if TF2Res.Load and TF2Res.FindByFieldName and TF2Res.GetNumber and TF2Res.GetTextureID and TF2Res.ParseCoord then
    return
end

TF2Res._cache = TF2Res._cache or {}
TF2Res._loading = TF2Res._loading or {}

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

local function tokenizeKeyValues(text)
    local tokens = {}
    local i = 1
    local len = #text

    while i <= len do
        local ch = text:sub(i, i)

        if ch == " " or ch == "\t" or ch == "\r" or ch == "\n" then
            i = i + 1
        elseif ch == "/" and text:sub(i + 1, i + 1) == "/" then
            i = i + 2
            while i <= len and text:sub(i, i) ~= "\n" do
                i = i + 1
            end
        elseif ch == "{" or ch == "}" then
            tokens[#tokens + 1] = ch
            i = i + 1
        elseif ch == "\"" then
            local j = i + 1
            local buf = {}
            while j <= len do
                local c = text:sub(j, j)
                if c == "\\" then
                    local n = text:sub(j + 1, j + 1)
                    if n == "\"" or n == "\\" then
                        buf[#buf + 1] = n
                        j = j + 2
                    else
                        buf[#buf + 1] = c
                        j = j + 1
                    end
                elseif c == "\"" then
                    break
                else
                    buf[#buf + 1] = c
                    j = j + 1
                end
            end
            tokens[#tokens + 1] = table.concat(buf)
            if j <= len and text:sub(j, j) == "\"" then
                i = j + 1
            else
                i = j
            end
        else
            local j = i
            local buf = {}
            while j <= len do
                local c = text:sub(j, j)
                if c == " " or c == "\t" or c == "\r" or c == "\n" or c == "{" or c == "}" then
                    break
                end
                if c == "/" and text:sub(j + 1, j + 1) == "/" then
                    break
                end
                buf[#buf + 1] = c
                j = j + 1
            end
            local tok = table.concat(buf)
            if tok ~= "" then
                tokens[#tokens + 1] = tok
            end
            i = j
        end
    end

    return tokens
end

local function parseNode(tokens, idx, keyName)
    local node = { key = keyName, props = {}, children = {} }
    local i = idx
    while i <= #tokens do
        local t = tokens[i]
        if t == "}" then
            return node, i + 1
        end

        local key = t
        local nxt = tokens[i + 1]
        if nxt == "{" then
            local child, nextIndex = parseNode(tokens, i + 2, key)
            node.children[#node.children + 1] = child
            i = nextIndex
        elseif nxt ~= nil and nxt ~= "}" then
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
                node.props[key] = nxt
            end
            i = j
        else
            i = i + 1
        end
    end
    return node, i
end

local function parseResTree(text)
    if not isstring(text) or text == "" then return nil end
    local tokens = tokenizeKeyValues(text)
    if #tokens == 0 then return nil end

    local root = { key = "__root__", props = {}, children = {} }
    local i = 1
    while i <= #tokens do
        local key = tokens[i]
        local nxt = tokens[i + 1]
        if nxt == "{" then
            local child, nextIndex = parseNode(tokens, i + 2, key)
            root.children[#root.children + 1] = child
            i = nextIndex
        elseif nxt ~= nil and nxt ~= "}" then
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
                root.props[key] = nxt
            end
            i = j
        else
            i = i + 1
        end
    end
    return root
end

local function cloneNode(node)
    if not istable(node) then return nil end

    local out = {
        key = node.key,
        props = {},
        children = {},
    }

    for k, v in pairs(node.props or {}) do
        out.props[k] = v
    end

    for i, child in ipairs(node.children or {}) do
        out.children[i] = cloneNode(child)
    end

    return out
end

local function findChildIndexByKey(children, keyName)
    for i, child in ipairs(children or {}) do
        if isstring(child.key) and string.lower(child.key) == string.lower(tostring(keyName or "")) then
            return i
        end
    end
end

local function mergeNodeTrees(baseNode, overrideNode)
    if not baseNode then return cloneNode(overrideNode) end
    if not overrideNode then return cloneNode(baseNode) end

    local out = cloneNode(baseNode)

    for k, v in pairs(overrideNode.props or {}) do
        out.props[k] = v
    end

    for _, child in ipairs(overrideNode.children or {}) do
        local idx = findChildIndexByKey(out.children, child.key)
        if idx then
            out.children[idx] = mergeNodeTrees(out.children[idx], child)
        else
            out.children[#out.children + 1] = cloneNode(child)
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
            if #segs > 0 then
                table.remove(segs)
            end
        else
            segs[#segs + 1] = seg
        end
    end

    return string.lower(table.concat(segs, "/"))
end

local function resolveBasePath(path, basePath)
    if not isstring(basePath) or basePath == "" then
        return nil
    end

    basePath = string.Replace(basePath, "\\", "/")

    if string.find(basePath, "^[A-Za-z]:/") then
        return normalizePath(basePath)
    end

    if string.sub(basePath, 1, 1) == "/" then
        return normalizePath(string.sub(basePath, 2))
    end

    local dir = string.match(path, "^(.*)/[^/]+$") or ""
    if dir ~= "" then
        return normalizePath(dir .. "/" .. basePath)
    end

    return normalizePath(basePath)
end

local function stripComments(text)
    if not isstring(text) or text == "" then return text end
    text = string.gsub(text, "/%*.-%*/", "")
    text = string.gsub(text, "//[^\r\n]*", "")
    return text
end

local function stripBaseDirectives(text)
    if not isstring(text) or text == "" then return text end

    local stripped = string.gsub(text, '[ \t]*#base[ \t]+"[^"\r\n]+"[ \t]*\r?\n?', "")
    stripped = string.gsub(stripped, "[ \t]*#base[ \t]+[^\"\r\n][^\r\n]*\r?\n?", "")
    return stripped
end

local function collectBaseDirectives(text)
    local out = {}
    for basePath in string.gmatch(text or "", '#base%s+"([^"]+)"') do
        out[#out + 1] = basePath
    end
    for basePath in string.gmatch(text or "", "#base%s+([^\r\n]+)") do
        local cleaned = string.Trim(basePath or "")
        if cleaned ~= "" and cleaned:sub(1, 1) ~= "\"" then
            out[#out + 1] = cleaned
        end
    end
    return out
end

local function findNodeRecursive(node, fieldName)
    if not node then return nil end

    local needle = string.lower(tostring(fieldName or ""))
    if node.props then
        for key, value in pairs(node.props) do
            if string.lower(tostring(key)) == "fieldname" and isstring(value) and string.lower(value) == needle then
                return node
            end
        end
    end

    for _, child in ipairs(node.children or {}) do
        local found = findNodeRecursive(child, fieldName)
        if found then return found end
    end
    return nil
end

local function findNodeByKeyRecursive(node, keyName)
    if not node then return nil end
    if isstring(node.key) and string.lower(node.key) == string.lower(tostring(keyName or "")) then
        return node
    end
    for _, child in ipairs(node.children or {}) do
        local found = findNodeByKeyRecursive(child, keyName)
        if found then return found end
    end
    return nil
end

local function getPropInsensitive(node, key)
    if not node or not node.props then return nil end
    if node.props[key] ~= nil then
        return node.props[key]
    end

    local needle = string.lower(tostring(key))
    for propKey, value in pairs(node.props) do
        if string.lower(tostring(propKey)) == needle then
            return value
        end
    end

    return nil
end

function TF2Res.Load(path)
    path = normalizePath(path or "")
    if not path or path == "" then return nil end

    if TF2Res._cache[path] then
        return cloneNode(TF2Res._cache[path])
    end
    if TF2Res._loading[path] then
        return nil
    end

    TF2Res._loading[path] = true

    local text = file.Read(path, "GAME")
    if not text then
        TF2Res._loading[path] = nil
        return nil
    end

    local strippedText = stripComments(text)

    local merged
    for _, basePath in ipairs(collectBaseDirectives(strippedText)) do
        local resolved = resolveBasePath(path, basePath)
        local baseTree = resolved and TF2Res.Load(resolved)
        if baseTree then
            merged = merged and mergeNodeTrees(merged, baseTree) or cloneNode(baseTree)
        end
    end

    local currentTree = parseResTree(stripBaseDirectives(strippedText))
    if currentTree then
        merged = merged and mergeNodeTrees(merged, currentTree) or currentTree
    end

    TF2Res._loading[path] = nil
    TF2Res._cache[path] = merged and cloneNode(merged) or false

    if not merged then return nil end
    return cloneNode(merged)
end

function TF2Res.FindByFieldName(tree, fieldName)
    return findNodeRecursive(tree, fieldName)
end

function TF2Res.FindByKey(tree, keyName)
    return findNodeByKeyRecursive(tree, keyName)
end

function TF2Res.GetNumber(node, key, default)
    local raw = getPropInsensitive(node, key)
    if isnumber(raw) then return raw end
    if not isstring(raw) then return default end

    local n = tonumber(raw)
    if n then return n end

    return tonumber(string.match(raw, "([%+%-]?%d+%.?%d*)$")) or default
end

function TF2Res.GetColor(node, key, default)
    local raw = getPropInsensitive(node, key)
    if not isstring(raw) then return default end

    local r, g, b, a = raw:match("^(%d+)%s+(%d+)%s+(%d+)%s*(%d*)$")
    if not r or not g or not b then return default end

    local alpha = tonumber(a)
    return Color(tonumber(r), tonumber(g), tonumber(b), (alpha and alpha > 0) and alpha or 255)
end

function TF2Res.GetString(node, key, default)
    local raw = getPropInsensitive(node, key)
    if not isstring(raw) or raw == "" then return default end
    return raw
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

function TF2Res.GetTextureID(node, key, default)
    local texture = TF2Res.NormalizeImagePath(TF2Res.GetString(node, key, default))
    if not texture then
        return surface.GetTextureID(TF2Res.NormalizeImagePath(default or "") or "")
    end
    return surface.GetTextureID(texture)
end

function TF2Res.ParseCoord(raw, axisSize, default, axisScale)
    if raw == nil then return default end
    if isnumber(raw) then return raw end
    if not isstring(raw) then return default end

    raw = string.Trim(raw)
    if raw == "" then return default end

    axisScale = axisScale or 1

    local numeric = tonumber(raw)
    if numeric ~= nil then
        return numeric * axisScale
    end

    local anchor, offset = string.match(raw, "^([crf])([%+%-]?%d*%.?%d*)$")
    if not anchor then
        return default
    end

    offset = tonumber(offset) or 0
    if anchor == "c" then
        return axisSize * 0.5 + offset * axisScale
    end
    if anchor == "r" or anchor == "f" then
        return axisSize - offset * axisScale
    end

    return default
end

function TF2Res.GetRect(node, parentW, parentH, defaults, xScale, yScale)
    local out = table.Copy(defaults or {})
    out.x = TF2Res.ParseCoord(TF2Res.GetString(node, "xpos", nil), parentW, out.x, xScale)
    out.y = TF2Res.ParseCoord(TF2Res.GetString(node, "ypos", nil), parentH, out.y, yScale)
    out.w = TF2Res.ParseCoord(TF2Res.GetString(node, "wide", nil), parentW, out.w, xScale)
    out.h = TF2Res.ParseCoord(TF2Res.GetString(node, "tall", nil), parentH, out.h, yScale)
    return out
end

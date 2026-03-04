if SERVER then
    AddCSLuaFile()
    return
end

TF2Res = TF2Res or {}
if TF2Res.Load and TF2Res.FindByFieldName and TF2Res.GetNumber and TF2Res.GetTextureID and TF2Res.ParseCoord then
    return
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
            node.props[key] = nxt
            i = i + 2
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
            root.props[key] = nxt
            i = i + 2
        else
            i = i + 1
        end
    end
    return root
end

local function findNodeRecursive(node, fieldName)
    if not node then return nil end
    if node.props and node.props.fieldName == fieldName then
        return node
    end
    for _, child in ipairs(node.children or {}) do
        local found = findNodeRecursive(child, fieldName)
        if found then return found end
    end
    return nil
end

local function findNodeByKeyRecursive(node, keyName)
    if not node then return nil end
    if node.key == keyName then
        return node
    end
    for _, child in ipairs(node.children or {}) do
        local found = findNodeByKeyRecursive(child, keyName)
        if found then return found end
    end
    return nil
end

function TF2Res.Load(path)
    local text = file.Read(path, "GAME")
    if not text then return nil end
    return parseResTree(text)
end

function TF2Res.FindByFieldName(tree, fieldName)
    return findNodeRecursive(tree, fieldName)
end

function TF2Res.FindByKey(tree, keyName)
    return findNodeByKeyRecursive(tree, keyName)
end

function TF2Res.GetNumber(node, key, default)
    if not node or not node.props then return default end
    local raw = node.props[key]
    if not isstring(raw) then return default end

    -- We only need numeric values from TF2 upgrade resources for now.
    local n = tonumber(raw)
    if n then return n end

    -- Handles patterns like c-250 and c250 by taking the offset part.
    local c = raw:match("^c([%+%-]?%d+)$")
    if c then
        return tonumber(c) or default
    end

    return default
end

function TF2Res.GetColor(node, key, default)
    if not node or not node.props then return default end
    local raw = node.props[key]
    if not isstring(raw) then return default end
    local r, g, b, a = raw:match("^(%d+)%s+(%d+)%s+(%d+)%s+(%d+)$")
    if not r then return default end
    return Color(tonumber(r), tonumber(g), tonumber(b), tonumber(a))
end

function TF2Res.GetString(node, key, default)
    if not node or not node.props then return default end
    local raw = node.props[key]
    if not isstring(raw) or raw == "" then return default end
    return raw
end

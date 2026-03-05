if SERVER then
    AddCSLuaFile()
    util.AddNetworkString("TF_MVM_UpgradeOpen")
    util.AddNetworkString("TF_MVM_UpgradeClose")
    util.AddNetworkString("TF_MVM_UpgradeAction")
    util.AddNetworkString("TF_MVM_CanteenUse")
end

TF_MVMShop = TF_MVMShop or {}

TF_MVMShop.StartingCredits = 600
TF_MVMShop.BuybackBaseCost = 200

TF_MVMShop.CanteenTypes = {
    crit = { name = "CRIT BOOST", description = "Temporary guaranteed crits.", cost = 75 },
    uber = { name = "UBERCHARGE", description = "Temporary invulnerability.", cost = 75 },
    refill = { name = "AMMO REFILL", description = "Instant clip and ammo refill.", cost = 50 },
    build = { name = "BUILD UPGRADE", description = "Repair and boost buildings.", cost = 75 },
}

TF_MVMShop.DefaultUpgrades = {
    { id = "max_health", name = "Max Health", category = "Player", target = "player", description = "+25 max health", costs = { 150, 250, 350, 450 }, requiresScript = true },
    { id = "move_speed", name = "Move Speed", category = "Player", target = "player", description = "+8% movement speed", costs = { 200, 300, 425 } },
    { id = "resist_all", name = "Damage Resistance", category = "Player", target = "player", description = "-8% incoming damage", costs = { 200, 325, 450, 600 } },
    { id = "resist_bullet", name = "Bullet Resistance", category = "Player", target = "player", description = "-10% bullet damage", costs = { 150, 250, 350 } },
    { id = "resist_blast", name = "Blast Resistance", category = "Player", target = "player", description = "-10% explosive damage", costs = { 150, 250, 350 } },
    { id = "resist_fire", name = "Fire Resistance", category = "Player", target = "player", description = "-12% fire damage", costs = { 150, 250, 350 } },
    { id = "autoheal", name = "Auto-Heal", category = "Player", target = "player", description = "+2 health regen", costs = { 200, 200, 200, 200, 200 } },
    { id = "jump_height", name = "Jump Height", category = "Player", target = "player", description = "+10% jump height", costs = { 100, 175, 250 } },

    { id = "damage_primary", name = "Primary Damage", category = "Primary", target = "primary", description = "+12% damage", costs = { 150, 250, 350, 475 } },
    { id = "firerate_primary", name = "Primary Fire Rate", category = "Primary", target = "primary", description = "+8% fire speed", costs = { 150, 250, 350, 500 } },
    { id = "reload_primary", name = "Primary Reload", category = "Primary", target = "primary", description = "+10% reload speed", costs = { 125, 225, 325 } },
    { id = "clip_primary", name = "Primary Clip Size", category = "Primary", target = "primary", description = "+20% clip size", costs = { 100, 175, 250 } },
    { id = "ammo_primary", name = "Primary Ammo", category = "Primary", target = "primary", description = "+25% max ammo", costs = { 100, 200, 300 } },
    { id = "effectbar_primary", name = "Recharge Rate", category = "Primary", target = "primary", description = "+25% faster recharge rate", costs = { 100, 150, 200, 250 }, requiresScript = true },

    { id = "damage_secondary", name = "Secondary Damage", category = "Secondary", target = "secondary", description = "+12% damage", costs = { 150, 250, 350, 475 } },
    { id = "firerate_secondary", name = "Secondary Fire Rate", category = "Secondary", target = "secondary", description = "+8% fire speed", costs = { 150, 250, 350, 500 } },
    { id = "reload_secondary", name = "Secondary Reload", category = "Secondary", target = "secondary", description = "+10% reload speed", costs = { 125, 225, 325 } },
    { id = "clip_secondary", name = "Secondary Clip Size", category = "Secondary", target = "secondary", description = "+20% clip size", costs = { 100, 175, 250 } },
    { id = "ammo_secondary", name = "Secondary Ammo", category = "Secondary", target = "secondary", description = "+25% max ammo", costs = { 100, 200, 300 } },
    { id = "effectbar_secondary", name = "Recharge Rate", category = "Secondary", target = "secondary", description = "+25% faster recharge rate", costs = { 100, 150, 200, 250 }, requiresScript = false },
    { id = "buff_duration_secondary", name = "Buff Duration", category = "Secondary", target = "secondary", description = "+25% buff duration", costs = { 250, 250 }, requiresScript = false },

    { id = "damage_melee", name = "Melee Damage", category = "Melee", target = "melee", description = "+15% melee damage", costs = { 125, 225, 325, 425 } },
    { id = "swing_melee", name = "Melee Swing Speed", category = "Melee", target = "melee", description = "+10% swing speed", costs = { 125, 225, 325 } },
    { id = "lifesteal_melee", name = "Melee Heal On Kill", category = "Melee", target = "melee", description = "+25 health on melee kill", costs = { 150, 275, 400 } },
    { id = "effectbar_melee", name = "Recharge Rate", category = "Melee", target = "melee", description = "+25% faster recharge rate", costs = { 100, 150, 200, 250 }, requiresScript = true },

    { id = "building_health", name = "Building Health", category = "Engineer", target = "player", classes = { "engineer" }, description = "+15% building health", costs = { 150, 250, 350 } },
    { id = "building_rate", name = "Building Fire Rate", category = "Engineer", target = "player", classes = { "engineer" }, description = "+10% sentry fire rate", costs = { 200, 300, 450 } },
    { id = "canteen_capacity", name = "Canteen Specialist", category = "Canteen", target = "action", description = "+1 max canteen charge", costs = { 150, 300 } },
}

local function NormalizeUpgradeCostsFlat(list)
    for _, up in ipairs(list or {}) do
        if istable(up.costs) and #up.costs > 0 then
            local flat = tonumber(up.costs[1]) or 0
            for i = 1, #up.costs do
                up.costs[i] = flat
            end
        end
    end
end

NormalizeUpgradeCostsFlat(TF_MVMShop.DefaultUpgrades)
TF_MVMShop.BaseDefaultUpgrades = TF_MVMShop.BaseDefaultUpgrades or table.Copy(TF_MVMShop.DefaultUpgrades)

TF_MVMShop.Upgrades = table.Copy(TF_MVMShop.DefaultUpgrades)
TF_MVMShop.CustomUpgradeAttributeMap = {
    max_health = "max health additive bonus",
    move_speed = "move speed bonus",
    resist_all = "dmg taken from crit reduced",
    resist_bullet = "dmg taken from bullets reduced",
    resist_blast = "dmg taken from blast reduced",
    resist_fire = "dmg taken from fire reduced",
    autoheal = "health regen",
    jump_height = "increased jump height",

    damage_primary = "damage bonus",
    firerate_primary = "fire rate bonus",
    reload_primary = "faster reload rate",
    clip_primary = "clip size bonus upgrade",
    ammo_primary = "maxammo primary increased",
    effectbar_primary = { "effect bar recharge rate increased", "charge recharge rate increased" },

    damage_secondary = "damage bonus",
    firerate_secondary = "fire rate bonus",
    reload_secondary = "faster reload rate",
    clip_secondary = "clip size bonus upgrade",
    ammo_secondary = "maxammo secondary increased",
    effectbar_secondary = { "effect bar recharge rate increased", "charge recharge rate increased" },
    buff_duration_secondary = "increase buff duration",

    damage_melee = "damage bonus",
    swing_melee = "melee attack rate bonus",
    lifesteal_melee = "heal on kill",
    effectbar_melee = { "effect bar recharge rate increased", "charge recharge rate increased" },

    building_health = "engy building health bonus",
    building_rate = "engy sentry fire rate increased",
    canteen_capacity = "canteen specialist",
}
TF_MVMShop.CustomUpgradeQualityById = {
    -- closer to in-game behavior for common explosive primaries/secondaries
    damage_primary = 1,
    damage_secondary = 1,
}
TF_MVMShop.DisplayNameById = {
    max_health = "+25 Max Health",
    move_speed = "+10% Movement Speed",
    resist_all = "Crit Resistance",
    resist_bullet = "Bullet Resistance",
    resist_blast = "Blast Resistance",
    resist_fire = "Fire Resistance",
    autoheal = "Auto-Heal",
    jump_height = "+20% Jump Height",
    damage_primary = "+25% Damage",
    firerate_primary = "+10% Firing Speed",
    reload_primary = "+20% Reload Speed",
    clip_primary = "+50% Clip Size",
    ammo_primary = "+50% Ammo Capacity",
    effectbar_primary = "+25% Recharge Rate",
    damage_secondary = "+25% Damage",
    firerate_secondary = "+10% Firing Speed",
    reload_secondary = "+20% Reload Speed",
    clip_secondary = "+50% Clip Size",
    ammo_secondary = "+50% Ammo Capacity",
    effectbar_secondary = "+25% Recharge Rate",
    buff_duration_secondary = "+25% Buff Duration",
    damage_melee = "+25% Damage",
    swing_melee = "+10% Attack Speed",
    lifesteal_melee = "+25 Health On Kill",
    effectbar_melee = "+25% Recharge Rate",
    building_health = "+100% Building Health",
    building_rate = "+10% Sentry Fire Speed",
    canteen_capacity = "+1 Canteen Capacity",
}
TF_MVMShop.AttributeDisplayNameMap = {
    ["damage bonus"] = "+25% Damage",
    ["fire rate bonus"] = "+10% Firing Speed",
    ["faster reload rate"] = "+20% Reload Speed",
    ["clip size bonus upgrade"] = "+50% Clip Size",
    ["maxammo primary increased"] = "+50% Ammo Capacity",
    ["maxammo secondary increased"] = "+50% Ammo Capacity",
    ["effect bar recharge rate increased"] = "+25% Recharge Rate",
    ["increase buff duration"] = "+25% Buff Duration",
    ["melee attack rate bonus"] = "+10% Attack Speed",
    ["move speed bonus"] = "+10% Movement Speed",
    ["increased jump height"] = "+20% Jump Height",
    ["dmg taken from bullets reduced"] = "Bullet Resistance",
    ["dmg taken from blast reduced"] = "Blast Resistance",
    ["dmg taken from fire reduced"] = "Fire Resistance",
    ["dmg taken from crit reduced"] = "Crit Resistance",
    ["health regen"] = "Auto-Heal",
    ["heal on kill"] = "+25 Health On Kill",
    ["engy building health bonus"] = "+100% Building Health",
    ["engy sentry fire rate increased"] = "+10% Sentry Fire Speed",
    ["canteen specialist"] = "+1 Canteen Capacity",
}
TF_MVMShop.ScriptDescriptionById = TF_MVMShop.ScriptDescriptionById or {}

local function PrettifyAttributeName(attr)
    local pretty = string.gsub(string.lower(tostring(attr or "")), "_", " ")
    pretty = string.gsub(pretty, "([%a])([%w']*)", function(a, b) return string.upper(a) .. b end)
    return pretty
end

-- lookups
local upgradesById = {}
local function rebuildUpgradesById()
    upgradesById = {}
    for _,u in ipairs(TF_MVMShop.Upgrades) do
        if u.id then upgradesById[u.id] = u end
    end
end

-- helper to parse a KeyValues table produced by util.KeyValuesToTable
local function parseUpgradesKV(kv)
    local out = {}
    if not istable(kv) then return out end
    -- the file tends to wrap everything under an "Upgrades" key
    if kv.Upgrades and istable(kv.Upgrades) then
        kv = kv.Upgrades
    end

    local function doGroup(group, defaultCat)
        for name,data in pairs(group or {}) do
            if not istable(data) then continue end
            local attrib = data.attribute or name
            -- make a human‑friendly display name if the key is machine‑style
            local prettyName = name
            prettyName = prettyName:gsub("_"," ")
            prettyName = prettyName:gsub("(%a)([%w]*)", function(a,b) return string.upper(a)..b end)
            local desc = data.description or data.desc or ""
            local inc = tonumber(data.increment) or 0
            local cap = tonumber(data.cap) or 0
            local levels = 1
            if inc > 0 and cap > 0 then
                levels = math.floor(cap / inc)
                if levels < 1 then levels = 1 end
            end
            local cost = tonumber(data.cost) or 0
            local costs = {}
            for i = 1, levels do costs[i] = cost end
            local cat = defaultCat == 1 and "Player" or "Primary"
            -- try categorising a bit smarter by attribute name
            local attrl = string.lower(attrib)
            if attrl:find("secondary") then cat = "Secondary" end
            if attrl:find("melee") then cat = "Melee" end
            table.insert(out, {
                id = attrib,
                name = prettyName,
                category = cat,
                target = (attrl:find("primary") and "primary") or (attrl:find("secondary") and "secondary") or (attrl:find("melee") and "melee") or "player",
                description = desc,
                costs = costs,
                icon = data.icon,
            })
        end
    end

    doGroup(kv.ItemUpgrades, 0)
    doGroup(kv.PlayerUpgrades, 1)
    return out
end

local function ParseUpgradeScriptLookup(kv)
    local byAttrib = {}
    if not istable(kv) then return byAttrib end
    if kv.Upgrades and istable(kv.Upgrades) then
        kv = kv.Upgrades
    elseif kv.upgrades and istable(kv.upgrades) then
        kv = kv.upgrades
    end

    local function readGroup(group)
        for _, data in pairs(group or {}) do
            if not istable(data) then continue end
            local attrib = string.lower(tostring(data.attribute or ""))
            if attrib == "" then continue end

            local parsed = {
                icon = tostring(data.icon or ""),
                attribute = tostring(data.attribute or ""),
                cost = tonumber(data.cost) or 0,
                increment = tonumber(data.increment) or 0,
                cap = tonumber(data.cap) or 0,
                quality = tonumber(data.quality) or 2,
                uiGroup = tonumber(data.ui_group) or 0,
            }

            byAttrib[attrib] = byAttrib[attrib] or {}
            byAttrib[attrib][parsed.quality] = parsed
        end
    end

    readGroup(kv.ItemUpgrades)
    readGroup(kv.PlayerUpgrades)
    return byAttrib
end

-- Parses raw mvm_upgrades text directly so duplicated numeric keys (e.g. "2.1")
-- do not get collapsed by util.KeyValuesToTable before we resolve quality variants.
local function ParseUpgradeScriptLookupFromText(txt)
    local byAttrib = {}
    if not isstring(txt) or txt == "" then
        return byAttrib
    end

    -- Strip C++-style line comments so disabled entries (// "14" { ... }) are
    -- not parsed as active upgrades.
    txt = string.gsub(txt, "//[^\r\n]*", "")

    for entry in string.gmatch(txt, "\"[%w%._%-]+\"%s*%b{}") do
        local attrib = entry:match("\"attribute\"%s*\"([^\"]+)\"")
        local icon = entry:match("\"icon\"%s*\"([^\"]+)\"")
        local increment = tonumber(entry:match("\"increment\"%s*\"([^\"]+)\""))
        local cap = tonumber(entry:match("\"cap\"%s*\"([^\"]+)\""))
        local cost = tonumber(entry:match("\"cost\"%s*\"([^\"]+)\""))
        local quality = tonumber(entry:match("\"quality\"%s*\"([^\"]+)\"")) or 2
        local uiGroup = tonumber(entry:match("\"ui_group\"%s*\"([^\"]+)\"")) or 0

        if attrib and icon and increment and cap and cost then
            local attrKey = string.lower(attrib)
            byAttrib[attrKey] = byAttrib[attrKey] or {}
            byAttrib[attrKey][quality] = byAttrib[attrKey][quality] or {
                icon = tostring(icon or ""),
                attribute = tostring(attrib or ""),
                cost = cost,
                increment = increment,
                cap = cap,
                quality = quality,
                uiGroup = uiGroup,
            }
        end
    end

    return byAttrib
end

local function ExtractNamedKVBlock(txt, groupName)
    if not isstring(txt) or txt == "" then return nil end
    local marker = "\"" .. tostring(groupName or "") .. "\""
    if marker == "\"\"" then return nil end
    local s = string.find(txt, marker, 1, true)
    if not s then return nil end
    local open = string.find(txt, "{", s, true)
    if not open then return nil end
    local depth = 0
    local i = open
    while i <= #txt do
        local ch = string.sub(txt, i, i)
        if ch == "{" then
            depth = depth + 1
        elseif ch == "}" then
            depth = depth - 1
            if depth == 0 then
                return string.sub(txt, open + 1, i - 1)
            end
        end
        i = i + 1
    end
    return nil
end

local function GuessUpgradeTargetFromAttribute(attributeName, isPlayerUpgrade)
    if isPlayerUpgrade then return "player" end
    local attr = string.lower(tostring(attributeName or ""))
    if attr == "" then return "primary" end
    if string.find(attr, "melee", 1, true) then return "melee" end
    if string.find(attr, "secondary", 1, true) then return "secondary" end
    if string.find(attr, "buff", 1, true)
        or string.find(attr, "jar", 1, true)
        or string.find(attr, "canteen", 1, true)
        or string.find(attr, "effect bar", 1, true)
        or string.find(attr, "charge recharge", 1, true) then
        return "secondary"
    end
    return "primary"
end

local DeriveTierCountFromScript

local function ParseUpgradeEntriesFromText(txt)
    local out = {
        item = {},
        player = {},
        all = {},
    }
    if not isstring(txt) or txt == "" then
        return out
    end

    local clean = string.gsub(txt, "//[^\r\n]*", "")

    local function parseGroup(groupName, isPlayerUpgrade)
        local body = ExtractNamedKVBlock(clean, groupName)
        if not isstring(body) or body == "" then return end
        for numericId, block in string.gmatch(body, "\"([%w%._%-]+)\"%s*(%b{})") do
            local attrib = block:match("\"attribute\"%s*\"([^\"]+)\"")
            local icon = block:match("\"icon\"%s*\"([^\"]+)\"")
            local increment = tonumber(block:match("\"increment\"%s*\"([^\"]+)\""))
            local cap = tonumber(block:match("\"cap\"%s*\"([^\"]+)\""))
            local cost = tonumber(block:match("\"cost\"%s*\"([^\"]+)\""))
            local quality = tonumber(block:match("\"quality\"%s*\"([^\"]+)\"")) or 2
            local uiGroup = tonumber(block:match("\"ui_group\"%s*\"([^\"]+)\"")) or 0
            if not attrib or not increment or not cap or not cost then
                continue
            end

            local entry = {
                id = tostring(numericId),
                name = PrettifyAttributeName(attrib),
                target = (uiGroup == 2) and "action" or GuessUpgradeTargetFromAttribute(attrib, isPlayerUpgrade),
                category = isPlayerUpgrade and "Player" or "Weapon",
                description = "",
                icon = tostring(icon or ""),
                scriptAttribute = tostring(attrib),
                scriptQuality = quality,
                scriptUiGroup = uiGroup,
                scriptIncrement = increment,
                scriptCap = cap,
                costs = {},
            }
            local tiers = DeriveTierCountFromScript(increment, cap, 1)
            for i = 1, tiers do
                entry.costs[i] = cost
            end
            if #entry.costs == 0 then
                entry.costs[1] = cost
            end

            out.all[#out.all + 1] = entry
            if isPlayerUpgrade then
                out.player[#out.player + 1] = entry
            else
                out.item[#out.item + 1] = entry
            end
        end
    end

    parseGroup("ItemUpgrades", false)
    parseGroup("PlayerUpgrades", true)
    return out
end

DeriveTierCountFromScript = function(increment, cap, fallback)
    local inc = tonumber(increment) or 0
    local maxCap = tonumber(cap) or 0
    if inc == 0 or maxCap == 0 then return fallback end

    local levels = nil
    if inc > 0 then
        if maxCap > 1 then
            levels = math.floor(((maxCap - 1) / inc) + 0.5)
        else
            levels = math.floor((maxCap / inc) + 0.5)
        end
    else
        local absInc = math.abs(inc)
        if maxCap < 1 then
            levels = math.floor(((1 - maxCap) / absInc) + 0.5)
        else
            levels = math.floor((math.abs(maxCap) / absInc) + 0.5)
        end
    end

    if not levels or levels < 1 then return fallback end
    return math.Clamp(levels, 1, 8)
end

local function SanitizeUpgradeIdPart(value)
    local s = string.lower(tostring(value or ""))
    s = string.gsub(s, "[^%w]+", "_")
    s = string.gsub(s, "^_+", "")
    s = string.gsub(s, "_+$", "")
    if s == "" then
        s = "custom"
    end
    return s
end

local function BuildDynamicUpgradeId(entry)
    local attr = SanitizeUpgradeIdPart(entry and (entry.scriptAttribute or entry.attribute or entry.id) or "")
    local target = SanitizeUpgradeIdPart(entry and entry.target or "weapon")
    return "dyn_" .. target .. "_" .. attr
end

local function IsDynamicUpgradeCandidate(src)
    if not istable(src) then return false end
    local attr = string.lower(tostring(src.scriptAttribute or src.attribute or ""))
    if attr == "" then return false end
    return true
end

local function ApplyCustomUpgradeScriptData(dataByAttrib)
    if not istable(dataByAttrib) then return end
    for _, up in ipairs(TF_MVMShop.DefaultUpgrades) do
        if up.requiresScript then
            up.scriptAvailable = false
        end
        local attr = TF_MVMShop.CustomUpgradeAttributeMap[up.id]
        if attr then
            local byQuality = nil
            local resolvedAttr = nil

            local function tryResolveAttr(attrName)
                if not isstring(attrName) or attrName == "" then return false end
                local key = string.lower(attrName)
                local candidate = dataByAttrib[key]
                if istable(candidate) then
                    byQuality = candidate
                    resolvedAttr = attrName
                    return true
                end
                return false
            end

            if isstring(attr) then
                tryResolveAttr(attr)
            elseif istable(attr) then
                for _, name in ipairs(attr) do
                    if tryResolveAttr(name) then break end
                end
            end

            local preferQuality = tonumber(TF_MVMShop.CustomUpgradeQualityById[up.id]) or 2
            local scriptData = byQuality and (byQuality[preferQuality] or byQuality[2] or byQuality[1] or byQuality[3]) or nil
            if scriptData then
                if up.requiresScript then
                    up.scriptAvailable = true
                end
                up.scriptAttribute = string.lower(tostring(scriptData.attribute or resolvedAttr or ""))
                up.scriptQuality = tonumber(scriptData.quality) or nil
                up.scriptUiGroup = tonumber(scriptData.uiGroup) or nil
                up.scriptIncrement = tonumber(scriptData.increment) or nil
                up.scriptCap = tonumber(scriptData.cap) or nil
                if scriptData.icon and scriptData.icon ~= "" then
                    up.icon = scriptData.icon
                end
                if scriptData.description and scriptData.description ~= "" then
                    up.description = scriptData.description
                    TF_MVMShop.ScriptDescriptionById[up.id] = scriptData.description
                end

                local tierCount = DeriveTierCountFromScript(scriptData.increment, scriptData.cap, #up.costs)
                local baseCost = tonumber(scriptData.cost) or 0
                if baseCost > 0 and tierCount > 0 then
                    up.costs = {}
                    for i = 1, tierCount do
                        up.costs[i] = baseCost
                    end
                end

                local attrLower = string.lower(tostring(scriptData.attribute or resolvedAttr or (isstring(attr) and attr or "") ))
                up.name = TF_MVMShop.AttributeDisplayNameMap[attrLower]
                    or TF_MVMShop.DisplayNameById[up.id]
                    or PrettifyAttributeName(attrLower)
            end
        end
    end
end

function TF_MVMShop:LoadUpgrades()
    TF_MVMShop.DefaultUpgrades = table.Copy(TF_MVMShop.BaseDefaultUpgrades or {})
    TF_MVMShop.ScriptDescriptionById = {}
    for _, up in ipairs(TF_MVMShop.DefaultUpgrades) do
        if up.requiresScript then
            up.scriptAvailable = false
        end
    end

    local function ReadUpgradeData(path)
        local txt = file.Read(path, "GAME")
        if not txt then return nil end
        local kv = util.KeyValuesToTable(txt)
        if not kv then return nil end

        local lookup = ParseUpgradeScriptLookupFromText(txt)
        if not next(lookup) then
            lookup = ParseUpgradeScriptLookup(kv)
        end
        local entries = ParseUpgradeEntriesFromText(txt)

        return {
            path = path,
            lookup = lookup or {},
            parsed = parseUpgradesKV(kv) or {},
            scriptEntries = entries or { item = {}, player = {}, all = {} },
        }
    end

    local function MergeLookup(baseLookup, extraLookup)
        if not istable(extraLookup) then return baseLookup end
        baseLookup = baseLookup or {}
        for attr, byQuality in pairs(extraLookup) do
            if not istable(byQuality) then continue end
            local attrKey = string.lower(tostring(attr or ""))
            if attrKey == "" then continue end
            baseLookup[attrKey] = baseLookup[attrKey] or {}
            for quality, entry in pairs(byQuality) do
                baseLookup[attrKey][quality] = entry
            end
        end
        return baseLookup
    end

    local function MergeParsedIntoList(list, parsed)
        if not istable(list) or not istable(parsed) then return end
        local byId = {}
        local byAttribute = {}
        local byAttributeTarget = {}
        local byDynamicKey = {}
        for _, up in ipairs(list) do
            if up.id then
                byId[string.lower(tostring(up.id))] = up
            end
            local upTarget = string.lower(tostring(up.target or ""))
            local mappedAttr = TF_MVMShop.CustomUpgradeAttributeMap[up.id]
            if isstring(mappedAttr) and mappedAttr ~= "" then
                local attrKey = string.lower(mappedAttr)
                if byAttribute[attrKey] == nil then
                    byAttribute[attrKey] = up
                end
                if upTarget ~= "" then
                    byAttributeTarget[upTarget .. "|" .. attrKey] = up
                end
            elseif istable(mappedAttr) then
                for _, attrName in ipairs(mappedAttr) do
                    attrName = string.lower(tostring(attrName or ""))
                    if attrName ~= "" then
                        if byAttribute[attrName] == nil then
                            byAttribute[attrName] = up
                        end
                        if upTarget ~= "" then
                            byAttributeTarget[upTarget .. "|" .. attrName] = up
                        end
                    end
                end
            end

            local upAttr = string.lower(tostring(up.scriptAttribute or ""))
            if upAttr ~= "" and upTarget ~= "" then
                byDynamicKey[upTarget .. "|" .. upAttr] = up
            end
        end
        for _, src in ipairs(parsed) do
            local srcId = string.lower(tostring(src.id or ""))
            local srcAttr = string.lower(tostring(src.scriptAttribute or src.attribute or src.id or ""))
            local srcTarget = string.lower(tostring(src.target or GuessUpgradeTargetFromAttribute(srcAttr, src.category == "Player") or ""))
            local dst = byId[srcId] or byAttributeTarget[srcTarget .. "|" .. srcAttr] or byAttribute[srcAttr] or byDynamicKey[srcTarget .. "|" .. srcAttr]

            if not dst and IsDynamicUpgradeCandidate(src) then
                local id = BuildDynamicUpgradeId(src)
                if byId[id] then
                    local qualityPart = tonumber(src.scriptQuality or 0)
                    id = id .. "_q" .. tostring(qualityPart)
                end

                dst = {
                    id = id,
                    name = TF_MVMShop.AttributeDisplayNameMap[srcAttr] or PrettifyAttributeName(srcAttr),
                    category = src.category or ((srcTarget == "player") and "Player" or "Weapon"),
                    target = srcTarget ~= "" and srcTarget or "primary",
                    description = src.description or "",
                    costs = istable(src.costs) and table.Copy(src.costs) or {},
                    icon = src.icon,
                    scriptAttribute = srcAttr,
                    scriptQuality = tonumber(src.scriptQuality) or nil,
                    scriptUiGroup = tonumber(src.scriptUiGroup) or nil,
                    scriptIncrement = tonumber(src.scriptIncrement) or nil,
                    scriptCap = tonumber(src.scriptCap) or nil,
                    dynamicScript = true,
                }
                if #dst.costs == 0 then
                    dst.costs[1] = 100
                end
                list[#list + 1] = dst
                byId[string.lower(id)] = dst
                byDynamicKey[dst.target .. "|" .. srcAttr] = dst
            end

            if not dst then continue end
            if istable(src.costs) and #src.costs > 0 then dst.costs = src.costs end
            if isstring(src.description) and src.description ~= "" then dst.description = src.description end
            if isstring(src.icon) and src.icon ~= "" then dst.icon = src.icon end
            if isstring(src.name) and src.name ~= "" then dst.name = src.name end
            if isstring(src.category) and src.category ~= "" then dst.category = src.category end
            if isstring(src.target) and src.target ~= "" then dst.target = src.target end
            if srcAttr ~= "" then dst.scriptAttribute = srcAttr end
            if src.scriptQuality ~= nil then dst.scriptQuality = tonumber(src.scriptQuality) or dst.scriptQuality end
            if src.scriptUiGroup ~= nil then dst.scriptUiGroup = tonumber(src.scriptUiGroup) or dst.scriptUiGroup end
            if src.scriptIncrement ~= nil then dst.scriptIncrement = tonumber(src.scriptIncrement) or dst.scriptIncrement end
            if src.scriptCap ~= nil then dst.scriptCap = tonumber(src.scriptCap) or dst.scriptCap end
        end
    end

    -- Always use Valve TF2 script as base first.
    local basePaths = {
        "tf/scripts/items/mvm_upgrades.txt",
        "scripts/items/mvm_upgrades.txt",
        "scripts/items/mvm_upgrades_tf2_stock.txt",
    }

    local baseData = nil
    for _, path in ipairs(basePaths) do
        baseData = ReadUpgradeData(path)
        if baseData then break end
    end

    if not baseData then
        if SERVER then
            print("[MVMShop] could not load TF2 base mvm_upgrades.txt, using default list")
        end
        TF_MVMShop.Upgrades = table.Copy(TF_MVMShop.DefaultUpgrades)
        rebuildUpgradesById()
        return
    end

    local mergedLookup = table.Copy(baseData.lookup or {})
    local mergedList = table.Copy(TF_MVMShop.DefaultUpgrades)
    MergeParsedIntoList(mergedList, baseData.parsed)
    local itemUpgradeCount = #(baseData.scriptEntries and baseData.scriptEntries.item or {})
    local playerUpgradeCount = #(baseData.scriptEntries and baseData.scriptEntries.player or {})

    -- Optional custom layers (map script + convar script) override TF2 base.
    local overridePaths = {}
    local map = string.lower(game.GetMap() or "")
    if map ~= "" then
        table.insert(overridePaths, string.format("maps/%s_upgrades.txt", map))
    end
    if SERVER then
        local cv = GetConVar("tf_mvm_upgrades_file")
        if cv and cv:GetString() ~= "" then
            table.insert(overridePaths, cv:GetString())
        end
    end

    local loadedOverrides = {}
    for _, path in ipairs(overridePaths) do
        local extra = ReadUpgradeData(path)
        if not extra then continue end
        MergeParsedIntoList(mergedList, extra.parsed)
        mergedLookup = MergeLookup(mergedLookup, extra.lookup)
        itemUpgradeCount = itemUpgradeCount + #(extra.scriptEntries and extra.scriptEntries.item or {})
        playerUpgradeCount = playerUpgradeCount + #(extra.scriptEntries and extra.scriptEntries.player or {})
        loadedOverrides[#loadedOverrides + 1] = path
    end

    -- Apply script-derived icon/cost/name mapping against the final merged lookup.
    -- This helper writes into DefaultUpgrades, so rebuild final list from it.
    ApplyCustomUpgradeScriptData(mergedLookup)
    TF_MVMShop.Upgrades = table.Copy(TF_MVMShop.DefaultUpgrades)
    MergeParsedIntoList(TF_MVMShop.Upgrades, mergedList)
    rebuildUpgradesById()

    if SERVER then
        local extraMsg = (#loadedOverrides > 0) and (" + overrides: " .. table.concat(loadedOverrides, ", ")) or ""
        print("[MVMShop] loaded TF2 base upgrades from " .. tostring(baseData.path) .. extraMsg
            .. " entries=" .. tostring(#TF_MVMShop.Upgrades)
            .. " itemDefs=" .. tostring(itemUpgradeCount)
            .. " playerDefs=" .. tostring(playerUpgradeCount))
    end
end

if SERVER then
    CreateConVar("tf_mvm_upgrades_file", "", FCVAR_ARCHIVE, "Custom MvM upgrades file (GAME path)")
    hook.Add("InitPostEntity", "TF_MVMShopLoadUpgrades", function()
        TF_MVMShop:LoadUpgrades()
    end)
    concommand.Add("tf_mvm_reload_upgrades", function(ply)
        if IsValid(ply) and not ply:IsAdmin() then return end
        TF_MVMShop:LoadUpgrades()
        print("[MVMShop] reload complete, " .. #TF_MVMShop.Upgrades .. " entries")
    end)
    concommand.Add("tf_mvm_upgrade_coverage", function(ply)
        if IsValid(ply) and not ply:IsAdmin() then return end
        local report = TF_MVMShop:BuildScriptCoverageReport()
        print(string.format("[MVMShop] coverage totalScriptEntries=%d uniqueScriptAttributes=%d unsupported=%d",
            tonumber(report.totalScriptEntries) or 0,
            tonumber(report.uniqueScriptAttributes) or 0,
            #(report.unsupported or {})
        ))
        if #(report.unsupported or {}) > 0 then
            print("[MVMShop] unsupported attrs: " .. table.concat(report.unsupported, ", "))
        end
    end)
else
    -- client should refresh lookup when panel is opened
    hook.Add("NetworkEntityCreated", "TF_MVMShopRefreshLookup", function()
        -- no-op placeholder, kept for symmetry
    end)
end


-- construct lookup table from current Upgrades (will be filled during LoadUpgrades)
rebuildUpgradesById()

local function IsMvMMap()
    if TF_IsMvMMap then
        return TF_IsMvMMap()
    end
    return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

local function IsMvMPlayer(ply)
    return IsValid(ply) and ply:IsPlayer() and not ply.TFBot and ply:Team() == TEAM_RED
end

local function ClampInt(v)
    return math.max(0, math.floor(tonumber(v) or 0))
end

function TF_MVMShop:IsEnabledFor(ply)
    return IsMvMMap() and IsMvMPlayer(ply)
end

function TF_MVMShop:GetState(ply)
    ply.TF_MVMShopState = ply.TF_MVMShopState or {
        credits = self.StartingCredits,
        spent = 0,
        buybacks = 0,
        upgrades = {},
        canteen = {
            selected = "crit",
            cooldown = 0,
            charges = { crit = 0, uber = 0, refill = 0, build = 0 },
        },
    }
    return ply.TF_MVMShopState
end

function TF_MVMShop:GetCredits(ply)
    return self:GetState(ply).credits
end

function TF_MVMShop:SetCredits(ply, amount)
    local state = self:GetState(ply)
    state.credits = ClampInt(amount)
    ply:SetNWInt("TF_MVM_Credits", state.credits)
end

function TF_MVMShop:AddCredits(ply, amount)
    self:SetCredits(ply, self:GetCredits(ply) + (tonumber(amount) or 0))
end

function TF_MVMShop:GetLevel(ply, id)
    local upgrades = self:GetState(ply).upgrades
    if id == "autoheal" then
        local v = upgrades.autoheal or upgrades.heal_on_kill or 0
        return ClampInt(v)
    end
    return ClampInt(upgrades[id] or 0)
end

function TF_MVMShop:SetLevel(ply, id, level)
    local upgrades = self:GetState(ply).upgrades
    if id == "autoheal" then
        upgrades.heal_on_kill = nil
    end
    upgrades[id] = ClampInt(level)
end

function TF_MVMShop:GetBaseSpeed(ply)
    local classTable = ply.GetPlayerClassTable and ply:GetPlayerClassTable() or nil
    return tonumber(classTable and classTable.Speed) or 300
end

function TF_MVMShop:GetBaseHealth(ply)
    local classTable = ply.GetPlayerClassTable and ply:GetPlayerClassTable() or nil
    return tonumber(classTable and classTable.Health) or tonumber(classTable and classTable.MaxHealth) or 125
end

function TF_MVMShop:IsSetupOpenForPurchases()
    if not TF_MVM or not TF_MVM.Runtime then return true end
    if not TF_MVM.Runtime:IsManagedActive() then return true end
    if TF_MVM.Runtime:IsSetupPhase() then return true end
    if TF_MVMState and TF_MVMState.Get and TF_MVMState:Get("in_setup", false) then
        return true
    end
    if TF_MVM.Runtime.IsWaveInProgress and not TF_MVM.Runtime:IsWaveInProgress() then
        return true
    end
    return false
end

function TF_MVMShop:IsUpgradeAllowedForClass(ply, upgrade)
    if not upgrade.classes then return true end
    local className = string.lower(tostring(ply:GetPlayerClass() or ""))
    for _, name in ipairs(upgrade.classes) do
        if className == string.lower(name) then
            return true
        end
    end
    return false
end

function TF_MVMShop:GetWeaponInLogicalSlot(ply, logicalSlot)
    if not IsValid(ply) then return nil end
    logicalSlot = string.lower(tostring(logicalSlot or ""))

    local candidates = {}
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) and self:GetWeaponSlotName(wep) == logicalSlot then
            candidates[#candidates + 1] = wep
        end
    end
    if #candidates == 0 then return nil end
    if #candidates == 1 then return candidates[1] end

    local active = ply.GetActiveWeapon and ply:GetActiveWeapon() or nil
    if IsValid(active) and self:GetWeaponSlotName(active) == logicalSlot then
        return active
    end

    -- Prefer effect-bar / drink variants (Sandman, Milk, Jar-like secondaries, etc.)
    -- to match TF2 upgrade intent when multiple same-slot entities are present.
    local effectCandidates = {}
    for _, wep in ipairs(candidates) do
        if self:WeaponHasEffectBarLike(wep) or self:IsWeaponDrinkLike(wep) then
            effectCandidates[#effectCandidates + 1] = wep
        end
    end
    if #effectCandidates == 1 then
        return effectCandidates[1]
    elseif #effectCandidates > 1 then
        table.sort(effectCandidates, function(a, b)
            return (a:EntIndex() or 0) > (b:EntIndex() or 0)
        end)
        return effectCandidates[1]
    end

    -- Otherwise pick the most recently created entity in the slot.
    table.sort(candidates, function(a, b)
        return (a:EntIndex() or 0) > (b:EntIndex() or 0)
    end)
    return candidates[1]
end

function TF_MVMShop:GetStrictTargetKey(ply, target)
    target = string.lower(tostring(target or ""))
    if target == "primary" or target == "secondary" or target == "melee" or target == "action" then
        local wep = self:GetWeaponInLogicalSlot(ply, target)
        if IsValid(wep) and wep.GetClass then
            return target .. ":" .. string.lower(tostring(wep:GetClass() or ""))
        end
        return target .. ":<none>"
    end
    return "player:<self>"
end

function TF_MVMShop:BuildStrictUpgradeValidationMatrix(ply)
    local matrix = {}
    local flatSet = {}
    local baseSlots = { "primary", "secondary", "melee", "action" }
    for _, slot in ipairs(baseSlots) do
        matrix[self:GetStrictTargetKey(ply, slot)] = matrix[self:GetStrictTargetKey(ply, slot)] or {}
    end
    matrix["player:<self>"] = matrix["player:<self>"] or {}

    for _, upgrade in ipairs(self.Upgrades or {}) do
        local scriptAllowed = self:IsUpgradeEnabledByScript(upgrade)
        local classAllowed = self:IsUpgradeAllowedForClass(ply, upgrade)
        local loadoutAllowed = self:IsUpgradeAllowedForLoadout(ply, upgrade)
        local allowed = scriptAllowed and classAllowed and loadoutAllowed
        if allowed then
            local key = self:GetStrictTargetKey(ply, upgrade.target)
            matrix[key] = matrix[key] or {}
            matrix[key][upgrade.id] = true
            flatSet[upgrade.id] = true
        end
    end
    return matrix, flatSet
end

function TF_MVMShop:FormatStrictUpgradeMatrixLines(ply, matrix)
    local lines = {}
    local keys = {}
    for key, _ in pairs(matrix or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    for _, key in ipairs(keys) do
        lines[#lines + 1] = string.format("[MVMShop] %s", key)
        local ids = {}
        for id, _ in pairs(matrix[key] or {}) do
            ids[#ids + 1] = id
        end
        table.sort(ids)
        for _, id in ipairs(ids) do
            local up = upgradesById[id]
            local name = up and tostring(up.name or id) or id
            lines[#lines + 1] = string.format("  - %s (%s)", id, name)
        end
    end

    if #lines == 0 then
        lines[1] = "[MVMShop] strict matrix: no upgrades available for current loadout"
    end

    return lines
end

function TF_MVMShop:WeaponSupportsClipUpgrade(wep)
    if not IsValid(wep) then return false end
    local maxClip = tonumber((wep.GetMaxClip1 and wep:GetMaxClip1()) or -1) or -1
    if maxClip > 0 then return true end
    return wep.Primary and isnumber(wep.Primary.ClipSize) and (wep.Primary.ClipSize or -1) > 0
end

function TF_MVMShop:WeaponSupportsReserveAmmoUpgrade(wep)
    if not IsValid(wep) then return false end
    local ammoType = wep.GetPrimaryAmmoType and wep:GetPrimaryAmmoType() or -1
    if ammoType and ammoType >= 0 then
        return true
    end
    if wep.Primary and isstring(wep.Primary.Ammo) then
        local ammoName = string.lower(wep.Primary.Ammo)
        return ammoName ~= "" and ammoName ~= "none"
    end
    return false
end

function TF_MVMShop:GetWeaponClassNameLower(wep)
    if not IsValid(wep) or not wep.GetClass then return "" end
    return string.lower(tostring(wep:GetClass() or ""))
end

function TF_MVMShop:IsWeaponEnergyLike(wep)
    if not IsValid(wep) then return false end
    if wep.IsEnergyWeapon and wep:IsEnergyWeapon() then return true end
    if wep.Primary and isstring(wep.Primary.Ammo) then
        local ammoName = string.lower(wep.Primary.Ammo)
        if ammoName == "energy" or ammoName == "metal" then
            return true
        end
    end
    local cls = self:GetWeaponClassNameLower(wep)
    return string.find(cls, "raygun", 1, true) ~= nil
        or string.find(cls, "pomson", 1, true) ~= nil
        or string.find(cls, "shortcircuit", 1, true) ~= nil
end

function TF_MVMShop:IsWeaponSniperOrBowLike(wep)
    local cls = self:GetWeaponClassNameLower(wep)
    return string.find(cls, "sniperrifle", 1, true) ~= nil
        or string.find(cls, "compound_bow", 1, true) ~= nil
        or string.find(cls, "crossbow", 1, true) ~= nil
        or string.find(cls, "bow", 1, true) ~= nil
end

function TF_MVMShop:IsWeaponFlamethrowerLike(wep)
    local cls = self:GetWeaponClassNameLower(wep)
    return string.find(cls, "flamethrower", 1, true) ~= nil
        or string.find(cls, "airblaster", 1, true) ~= nil
end

function TF_MVMShop:IsWeaponMinigunLike(wep)
    local cls = self:GetWeaponClassNameLower(wep)
    return string.find(cls, "minigun", 1, true) ~= nil
        or string.find(cls, "gatling", 1, true) ~= nil
end

function TF_MVMShop:IsWeaponSupportLike(wep)
    local cls = self:GetWeaponClassNameLower(wep)
    return string.find(cls, "medigun", 1, true) ~= nil
        or string.find(cls, "buff_item", 1, true) ~= nil
        or string.find(cls, "builder", 1, true) ~= nil
        or string.find(cls, "pda_", 1, true) ~= nil
        or string.find(cls, "invis", 1, true) ~= nil
        or string.find(cls, "spellbook", 1, true) ~= nil
        or string.find(cls, "lunchbox", 1, true) ~= nil
        or string.find(cls, "rocketpack", 1, true) ~= nil
        or string.find(cls, "parachute", 1, true) ~= nil
        or string.find(cls, "wrangler", 1, true) ~= nil
        or string.find(cls, "laser_pointer", 1, true) ~= nil
end

function TF_MVMShop:WeaponHasEffectBarLike(wep)
    if not IsValid(wep) then return false end
    if wep.HasEffectBarRegeneration and wep:HasEffectBarRegeneration() then
        return true
    end
    if wep.OffhandProjectileReady ~= nil then
        return true
    end
    local cls = self:GetWeaponClassNameLower(wep)
    if string.find(cls, "buff_item", 1, true)
        or string.find(cls, "conch", 1, true)
        or string.find(cls, "banner", 1, true)
        or string.find(cls, "backup", 1, true)
        or string.find(cls, "battalion", 1, true) then
        return true
    end
    return false
end

function TF_MVMShop:IsWeaponDrinkLike(wep)
    local cls = self:GetWeaponClassNameLower(wep)
    return string.find(cls, "lunchbox", 1, true) ~= nil
        or string.find(cls, "jar", 1, true) ~= nil
        or string.find(cls, "milk", 1, true) ~= nil
        or string.find(cls, "bat_wood", 1, true) ~= nil
        or string.find(cls, "giftwrap", 1, true) ~= nil
end

-- Explicit per-weapon upgrade overrides for known TF2-style edge cases.
-- If a class appears here, only listed upgrade ids are allowed for that weapon.
local EXPLICIT_WEAPON_UPGRADE_ALLOW = {
    -- Scout throwables / drinks / jars
    tf_weapon_jar_milk = { effectbar_secondary = true },
    tf_weapon_jar = { effectbar_secondary = true },
    tf_weapon_jar_gas = { effectbar_secondary = true },
    tf_weapon_lunchbox_drink = { effectbar_secondary = true },
    tf_weapon_cleaver = { effectbar_secondary = true, damage_secondary = true },

    -- Soldier banners (Concheror / Buff Banner / Battalion's Backup style)
    tf_weapon_buff_item = { buff_duration_secondary = true },
    tf_weapon_buff_item_conch = { buff_duration_secondary = true },
    tf_weapon_buff_item_backup = { buff_duration_secondary = true },
    tf_weapon_buff_item_battalion = { buff_duration_secondary = true },

    -- Scout melee with rechargeable projectile
    tf_weapon_bat_wood = { damage_melee = true, swing_melee = true, lifesteal_melee = true, effectbar_melee = true },
    tf_weapon_bat_giftwrap = { damage_melee = true, swing_melee = true, lifesteal_melee = true, effectbar_melee = true },
}

function TF_MVMShop:GetExplicitUpgradeAllowSetForWeapon(wep, target)
    if not IsValid(wep) then return nil end
    local cls = self:GetWeaponClassNameLower(wep)
    local explicit = EXPLICIT_WEAPON_UPGRADE_ALLOW[cls]
    if explicit then return explicit end

    -- Pattern-based fallbacks for variants/custom subclasses.
    if target == "secondary" then
        if string.find(cls, "buff_item", 1, true)
            or string.find(cls, "conch", 1, true)
            or string.find(cls, "banner", 1, true)
            or string.find(cls, "backup", 1, true)
            or string.find(cls, "battalion", 1, true) then
            return { buff_duration_secondary = true }
        end
        if string.find(cls, "lunchbox_drink", 1, true)
            or string.find(cls, "jar", 1, true)
            or string.find(cls, "milk", 1, true) then
            return { effectbar_secondary = true }
        end
        if string.find(cls, "cleaver", 1, true) then
            return { effectbar_secondary = true, damage_secondary = true }
        end
    elseif target == "melee" then
        if string.find(cls, "bat_wood", 1, true) or string.find(cls, "giftwrap", 1, true) then
            return { damage_melee = true, swing_melee = true, lifesteal_melee = true, effectbar_melee = true }
        end
    end

    return nil
end

function TF_MVMShop:WeaponReloadsSinglyLike(wep)
    if not IsValid(wep) then return false end
    if wep.ReloadsSingly and wep:ReloadsSingly() then
        return true
    end
    return wep.ReloadsSingly == true
end

function TF_MVMShop:WeaponAutoFiresFullClipAllAtOnceLike(wep)
    if not IsValid(wep) then return false end
    if wep.AutoFiresFullClipAllAtOnce and wep:AutoFiresFullClipAllAtOnce() then
        return true
    end
    return wep.AutoFiresFullClipAllAtOnce == true
end

function TF_MVMShop:WeaponIsBlastImpactLike(wep)
    if not IsValid(wep) then return false end
    if wep.IsBlastImpactWeapon and wep:IsBlastImpactWeapon() then
        return true
    end
    local cls = self:GetWeaponClassNameLower(wep)
    return string.find(cls, "rocketlauncher", 1, true) ~= nil
        or string.find(cls, "directhit", 1, true) ~= nil
        or string.find(cls, "flaregun_revenge", 1, true) ~= nil
end

function TF_MVMShop:GetUpgradeAttributeCandidates(upgrade)
    local out = {}
    if not istable(upgrade) then return out end

    local function addAttr(name)
        local key = string.lower(tostring(name or ""))
        if key == "" then return end
        out[#out + 1] = key
    end

    addAttr(upgrade.scriptAttribute)
    local mapped = self.CustomUpgradeAttributeMap and self.CustomUpgradeAttributeMap[upgrade.id] or nil
    if isstring(mapped) then
        addAttr(mapped)
    elseif istable(mapped) then
        for _, name in ipairs(mapped) do
            addAttr(name)
        end
    end
    return out
end

function TF_MVMShop:UpgradeAttrMatches(upgrade, token)
    token = string.lower(tostring(token or ""))
    if token == "" then return false end
    for _, attr in ipairs(self:GetUpgradeAttributeCandidates(upgrade)) do
        if string.find(attr, token, 1, true) then
            return true
        end
    end
    return false
end

function TF_MVMShop:IsUpgradeAllowedForLoadout(ply, upgrade)
    local target = string.lower(tostring(upgrade.target or ""))
    local id = string.lower(tostring(upgrade.id or ""))

    if target == "primary" or target == "secondary" or target == "melee" then
        local wep = self:GetWeaponInLogicalSlot(ply, target)
        if not IsValid(wep) then
            return false, "missing_weapon"
        end
        local explicitAllow = self:GetExplicitUpgradeAllowSetForWeapon(wep, target)
        if explicitAllow ~= nil and explicitAllow[id] ~= true then
            return false, "explicit_filtered"
        end
        local drinkLike = self:IsWeaponDrinkLike(wep)
        local isDamageUpgrade = id == "damage_primary" or id == "damage_secondary" or self:UpgradeAttrMatches(upgrade, "damage bonus")
        local isFireRateUpgrade = id == "firerate_primary" or id == "firerate_secondary" or self:UpgradeAttrMatches(upgrade, "fire rate bonus")
        local isClipUpgrade = id == "clip_primary" or id == "clip_secondary" or self:UpgradeAttrMatches(upgrade, "clip size bonus")
        local isReloadUpgrade = id == "reload_primary" or id == "reload_secondary" or self:UpgradeAttrMatches(upgrade, "reload")
        local isAmmoUpgrade = id == "ammo_primary" or id == "ammo_secondary" or self:UpgradeAttrMatches(upgrade, "maxammo")
        local isEffectBarUpgrade = id == "effectbar_primary" or id == "effectbar_secondary" or id == "effectbar_melee"
            or self:UpgradeAttrMatches(upgrade, "effect bar")
            or self:UpgradeAttrMatches(upgrade, "charge recharge")
            or self:UpgradeAttrMatches(upgrade, "item meter charge rate")

        if isDamageUpgrade then
            if self:IsWeaponSupportLike(wep) or drinkLike then
                return false, "weapon_no_damage_upgrade"
            end
        elseif isFireRateUpgrade then
            -- Mirrors TF2 CanUpgradeWithAttrib(fire rate bonus): exclude melee,
            -- flamethrowers, miniguns, sniper/bow, effect-bar weapons and full-clip dumpers.
            if target == "melee" then
                return false, "weapon_wrong_slot"
            end
            if self:IsWeaponSupportLike(wep)
                or drinkLike
                or self:IsWeaponFlamethrowerLike(wep)
                or self:IsWeaponMinigunLike(wep)
                or self:IsWeaponSniperOrBowLike(wep)
                or self:WeaponHasEffectBarLike(wep)
                or self:WeaponAutoFiresFullClipAllAtOnceLike(wep) then
                return false, "weapon_no_firerate"
            end
        elseif isClipUpgrade then
            if drinkLike then
                return false, "weapon_no_clip"
            end
            if not self:WeaponSupportsClipUpgrade(wep) then
                return false, "weapon_no_clip"
            end
            if self:WeaponIsBlastImpactLike(wep) then
                return false, "weapon_no_clip"
            end
        elseif isReloadUpgrade then
            if drinkLike then
                return false, "weapon_no_reload"
            end
            local canReloadUpgrade = self:WeaponReloadsSinglyLike(wep)
                or self:IsWeaponSniperOrBowLike(wep)
                or string.find(self:GetWeaponClassNameLower(wep), "flaregun", 1, true) ~= nil
            if not canReloadUpgrade then
                return false, "weapon_no_reload"
            end
        elseif isAmmoUpgrade then
            if drinkLike then
                return false, "weapon_no_ammo"
            end
            if not self:WeaponSupportsReserveAmmoUpgrade(wep) then
                return false, "weapon_no_ammo"
            end
            if self:IsWeaponEnergyLike(wep) then
                return false, "weapon_no_ammo"
            end
        elseif isEffectBarUpgrade then
            if id == "effectbar_primary" and target ~= "primary" then
                return false, "weapon_wrong_slot"
            end
            if id == "effectbar_secondary" and target ~= "secondary" then
                return false, "weapon_wrong_slot"
            end
            if id == "effectbar_melee" and target ~= "melee" then
                return false, "weapon_wrong_slot"
            end
            if not (self:WeaponHasEffectBarLike(wep) or drinkLike) then
                return false, "weapon_no_effectbar"
            end
        elseif id == "damage_melee" or id == "swing_melee" or id == "lifesteal_melee" then
            if target ~= "melee" then
                return false, "weapon_wrong_slot"
            end
        end
    elseif target == "action" then
        -- keep canteen capacity available to mirror TF2 station behavior
        return true, nil
    end

    return true, nil
end

function TF_MVMShop:IsUpgradeEnabledByScript(upgrade)
    if not istable(upgrade) then return false end
    if not upgrade.requiresScript then return true end
    return upgrade.scriptAvailable == true
end

function TF_MVMShop:CanBuyUpgrade(ply, id)
    if not self:IsEnabledFor(ply) then return false, "not_enabled" end
    if not self:IsSetupOpenForPurchases() then return false, "setup_only" end

    local upgrade = upgradesById[id]
    if not upgrade then return false, "invalid_upgrade" end
    local canteenType = self:GetCanteenTypeForScriptAttribute(upgrade.scriptAttribute)
    if tonumber(upgrade.scriptUiGroup) == 2 and canteenType then
        return self:CanBuyCanteenAsUpgrade(ply, canteenType)
    end
    if not self:IsUpgradeEnabledByScript(upgrade) then return false, "script_disabled" end
    if not self:IsUpgradeAllowedForClass(ply, upgrade) then return false, "class_restricted" end
    local allowedForLoadout, loadoutReason = self:IsUpgradeAllowedForLoadout(ply, upgrade)
    if not allowedForLoadout then return false, loadoutReason or "weapon_restricted" end

    local level = self:GetLevel(ply, id)
    if level >= #upgrade.costs then return false, "maxed" end
    local cost = upgrade.costs[level + 1]
    if self:GetCredits(ply) < cost then return false, "no_credits" end

    return true
end

function TF_MVMShop:CanBuyCanteenAsUpgrade(ply, canteenType)
    local c = self.CanteenTypes[canteenType]
    if not c then return false, "invalid_canteen" end
    local state = self:GetState(ply)
    if ClampInt(state.canteen.charges[canteenType]) >= self:GetMaxCanteenCharges(ply) then
        return false, "canteen_full"
    end
    if self:GetCredits(ply) < c.cost then
        return false, "no_credits"
    end
    return true
end

function TF_MVMShop:CanSellUpgrade(ply, id)
    if not self:IsEnabledFor(ply) then return false, "not_enabled" end
    if not self:IsSetupOpenForPurchases() then return false, "setup_only" end

    local upgrade = upgradesById[id]
    if not upgrade then return false, "invalid_upgrade" end
    if tonumber(upgrade.scriptUiGroup) == 2 then
        return false, "no_upgrade"
    end
    if not self:IsUpgradeEnabledByScript(upgrade) then return false, "script_disabled" end
    if not self:IsUpgradeAllowedForClass(ply, upgrade) then return false, "class_restricted" end
    local allowedForLoadout, loadoutReason = self:IsUpgradeAllowedForLoadout(ply, upgrade)
    if not allowedForLoadout then return false, loadoutReason or "weapon_restricted" end

    local level = self:GetLevel(ply, id)
    if level <= 0 then return false, "no_upgrade" end

    return true
end

function TF_MVMShop:GetUpgradeCost(ply, id)
    local upgrade = upgradesById[id]
    if not upgrade then return nil end
    local level = self:GetLevel(ply, id)
    return upgrade.costs[level + 1]
end

function TF_MVMShop:GetWeaponSlotName(wep)
    if not IsValid(wep) then return "" end
    local cls = string.lower(tostring((wep.GetClass and wep:GetClass()) or ""))

    -- Explicit fallback for known secondary drinks/jars when item metadata is unavailable.
    if string.find(cls, "jar_milk", 1, true)
        or string.find(cls, "jar_gas", 1, true)
        or string.find(cls, "tf_weapon_jar", 1, true)
        or string.find(cls, "lunchbox_drink", 1, true) then
        return "secondary"
    end

    if wep.GetItemData then
        local itemData = wep:GetItemData()
        if itemData and isstring(itemData.item_slot) then
            local slot = string.lower(itemData.item_slot)
            if slot == "primary" or slot == "secondary" or slot == "melee" or slot == "action" then
                return slot
            end
        end
    end

    if string.find(cls, "powerup", 1, true)
        or string.find(cls, "canteen", 1, true)
        or string.find(cls, "battery", 1, true)
        or string.find(cls, "kritz_or_treat", 1, true) then
        return "action"
    end

    local slot = tonumber(wep.Slot or (wep.GetSlot and wep:GetSlot()) or -1) or -1
    if slot == 0 then return "primary" end
    if slot == 1 then return "secondary" end
    if slot == 2 then return "melee" end
    if slot == 3 or slot == 4 or slot == 5 then return "action" end
    return ""
end

function TF_MVMShop:GetDamageMultiplier(ply, slot)
    local level, inc, hasInc = self:GetUpgradeProgressForSlot(ply, slot, "damage bonus")
    local _, apInc, apHas = self:GetScriptAttributeProgress(ply, slot, "armor piercing")
    local _, penInc, penHas = self:GetScriptAttributeProgress(ply, slot, "projectile penetration")
    local _, penHeavyInc, penHeavyHas = self:GetScriptAttributeProgress(ply, slot, "projectile penetration heavy")
    local _, rocketSpecInc, rocketSpecHas = self:GetScriptAttributeProgress(ply, slot, "rocket specialist")
    local _, expSniperInc, expSniperHas = self:GetScriptAttributeProgress(ply, slot, "explosive sniper shot")
    local _, attackProjInc, attackProjHas = self:GetScriptAttributeProgress(ply, slot, "attack projectiles")
    if hasInc then
        local extra = 0
        if apHas then extra = extra + math.max(0, apInc) end
        if penHas then extra = extra + math.max(0, penInc) * 0.05 end
        if penHeavyHas then extra = extra + math.max(0, penHeavyInc) * 0.04 end
        if rocketSpecHas then extra = extra + math.max(0, rocketSpecInc) * 0.05 end
        if expSniperHas then extra = extra + math.max(0, expSniperInc) * 0.05 end
        if attackProjHas then extra = extra + math.max(0, attackProjInc) * 0.03 end
        return math.max(0.1, 1 + inc + extra)
    end
    local base = 1
    if slot == "primary" then base = 1 + (0.12 * level) end
    if slot == "secondary" then base = 1 + (0.12 * level) end
    if slot == "melee" then base = 1 + (0.15 * level) end
    if apHas then base = base + math.max(0, apInc) end
    if penHas then base = base + (math.max(0, penInc) * 0.05) end
    if penHeavyHas then base = base + (math.max(0, penHeavyInc) * 0.04) end
    if rocketSpecHas then base = base + (math.max(0, rocketSpecInc) * 0.05) end
    if expSniperHas then base = base + (math.max(0, expSniperInc) * 0.05) end
    if attackProjHas then base = base + (math.max(0, attackProjInc) * 0.03) end
    return math.max(0.1, base)
end

function TF_MVMShop:SlotMatchesUpgradeTarget(slot, target)
    slot = string.lower(tostring(slot or ""))
    target = string.lower(tostring(target or ""))
    if target == "" then return false end
    if target == slot then return true end
    if target == "weapon" or target == "all" then
        return slot == "primary" or slot == "secondary" or slot == "melee"
    end
    return false
end

function TF_MVMShop:UpgradeMatchesAnyTokens(upgrade, tokens)
    if not istable(tokens) then return false end
    for _, token in ipairs(tokens) do
        if self:UpgradeAttrMatches(upgrade, token) then
            return true
        end
    end
    return false
end

function TF_MVMShop:GetUpgradeProgressForSlot(ply, slot, ...)
    local tokens = { ... }
    local totalLevel = 0
    local totalInc = 0
    local hasInc = false
    for _, upgrade in ipairs(self.Upgrades or {}) do
        if not self:SlotMatchesUpgradeTarget(slot, upgrade.target) then continue end
        if not self:UpgradeMatchesAnyTokens(upgrade, tokens) then continue end
        local level = self:GetLevel(ply, upgrade.id)
        if level <= 0 then continue end
        totalLevel = totalLevel + level
        local inc = tonumber(upgrade.scriptIncrement)
        if inc ~= nil then
            totalInc = totalInc + (inc * level)
            hasInc = true
        end
    end
    return totalLevel, totalInc, hasInc
end

function TF_MVMShop:GetScriptAttributeProgress(ply, target, attributeName)
    local want = string.lower(tostring(attributeName or ""))
    if want == "" then return 0, 0, false end
    local totalLevel = 0
    local totalInc = 0
    local hasInc = false
    for _, upgrade in ipairs(self.Upgrades or {}) do
        if not self:SlotMatchesUpgradeTarget(target, upgrade.target) then continue end
        local attr = string.lower(tostring(upgrade.scriptAttribute or ""))
        if attr ~= want then continue end
        local level = self:GetLevel(ply, upgrade.id)
        if level <= 0 then continue end
        totalLevel = totalLevel + level
        local inc = tonumber(upgrade.scriptIncrement)
        if inc ~= nil then
            totalInc = totalInc + (inc * level)
            hasInc = true
        end
    end
    return totalLevel, totalInc, hasInc
end

function TF_MVMShop:GetScriptAttributeProgressAnyTarget(ply, attributeName)
    local levelA, incA, hasA = self:GetScriptAttributeProgress(ply, "primary", attributeName)
    local levelB, incB, hasB = self:GetScriptAttributeProgress(ply, "secondary", attributeName)
    local levelC, incC, hasC = self:GetScriptAttributeProgress(ply, "melee", attributeName)
    local levelP, incP, hasP = self:GetScriptAttributeProgress(ply, "player", attributeName)
    return (levelA + levelB + levelC + levelP), (incA + incB + incC + incP), (hasA or hasB or hasC or hasP)
end

function TF_MVMShop:GetCanteenTypeForScriptAttribute(attr)
    attr = string.lower(tostring(attr or ""))
    if attr == "critboost" then return "crit" end
    if attr == "ubercharge" then return "uber" end
    if attr == "refill_ammo" then return "refill" end
    if attr == "recall" then return "refill" end
    if attr == "building instant upgrade" then return "build" end
    return nil
end

function TF_MVMShop:BuildScriptCoverageReport()
    local report = {
        totalScriptEntries = 0,
        uniqueScriptAttributes = 0,
        unsupported = {},
    }
    local byAttr = {}
    for _, up in ipairs(self.Upgrades or {}) do
        local attr = string.lower(tostring(up.scriptAttribute or ""))
        if attr == "" then continue end
        report.totalScriptEntries = report.totalScriptEntries + 1
        byAttr[attr] = true
    end

    local supported = {
        ["damage bonus"] = true,
        ["fire rate bonus"] = true,
        ["melee attack rate bonus"] = true,
        ["faster reload rate"] = true,
        ["clip size bonus upgrade"] = true,
        ["clip size upgrade atomic"] = true,
        ["maxammo primary increased"] = true,
        ["maxammo secondary increased"] = true,
        ["maxammo metal increased"] = true,
        ["maxammo grenades1 increased"] = true,
        ["effect bar recharge rate increased"] = true,
        ["charge recharge rate increased"] = true,
        ["mult_item_meter_charge_rate"] = true,
        ["increase buff duration"] = true,
        ["srifle charge rate increased"] = true,
        ["projectile speed increased"] = true,
        ["weapon burn dmg increased"] = true,
        ["weapon burn time increased"] = true,
        ["airblast pushback scale"] = true,
        ["move speed bonus"] = true,
        ["increased jump height"] = true,
        ["health regen"] = true,
        ["max health additive bonus"] = true,
        ["heal on kill"] = true,
        ["ubercharge rate bonus"] = true,
        ["healing mastery"] = true,
        ["overheal expert"] = true,
        ["metal regen"] = true,
        ["dmg taken from bullets reduced"] = true,
        ["dmg taken from blast reduced"] = true,
        ["dmg taken from fire reduced"] = true,
        ["dmg taken from crit reduced"] = true,
        ["damage force reduction"] = true,
        ["engy building health bonus"] = true,
        ["engy sentry fire rate increased"] = true,
        ["engy dispenser radius increased"] = true,
        ["engy disposable sentries"] = true,
        ["bidirectional teleport"] = true,
        ["building instant upgrade"] = true,
        ["canteen specialist"] = true,
        ["critboost"] = true,
        ["ubercharge"] = true,
        ["refill_ammo"] = true,
        ["recall"] = true,
        ["applies snare effect"] = true,
        ["mark for death"] = true,
        ["bleeding duration"] = true,
        ["rocket specialist"] = true,
        ["projectile penetration"] = true,
        ["projectile penetration heavy"] = true,
        ["armor piercing"] = true,
        ["attack projectiles"] = true,
        ["explosive sniper shot"] = true,
        ["generate rage on damage"] = true,
        ["generate rage on heal"] = true,
        ["uber duration bonus"] = true,
        ["critboost on kill"] = true,
        ["robo sapper"] = true,
        ["mad milk syringes"] = true,
        ["falling_impact_radius_stun"] = true,
        ["explode_on_ignite"] = true,
        ["thermal_thruster_air_launch"] = true,
    }
    for attr, _ in pairs(byAttr) do
        report.uniqueScriptAttributes = report.uniqueScriptAttributes + 1
        if not supported[attr] then
            report.unsupported[#report.unsupported + 1] = attr
        end
    end
    table.sort(report.unsupported)
    return report
end

function TF_MVMShop:ApplyWeaponStats(ply)
    ply.TF_MVM_BaseAmmoByType = ply.TF_MVM_BaseAmmoByType or {}
    ply.TF_MVM_BaseAmmoMaxByType = ply.TF_MVM_BaseAmmoMaxByType or {}
    for _, wep in ipairs(ply:GetWeapons()) do
        if not IsValid(wep) then continue end

        local slot = self:GetWeaponSlotName(wep)
        local fireLevel, fireInc, fireHasInc = self:GetUpgradeProgressForSlot(ply, slot, "fire rate bonus", "melee attack rate bonus")
        local reloadLevel, reloadInc, reloadHasInc = self:GetUpgradeProgressForSlot(ply, slot, "faster reload rate", "reload")
        local clipLevel, clipInc, clipHasInc = self:GetUpgradeProgressForSlot(ply, slot, "clip size bonus")
        local ammoLevel, ammoInc, ammoHasInc = self:GetUpgradeProgressForSlot(ply, slot, "maxammo", "ammo capacity")
        local effectbarLevel, effectbarInc, effectbarHasInc = self:GetUpgradeProgressForSlot(ply, slot, "effect bar", "charge recharge", "item meter charge rate")
        local buffDurationLevel, buffDurationInc, buffDurationHasInc = self:GetUpgradeProgressForSlot(ply, slot, "increase buff duration", "buff duration")
        local _, sniperChargeInc, sniperChargeHas = self:GetScriptAttributeProgress(ply, slot, "srifle charge rate increased")
        local _, projSpeedInc, projSpeedHas = self:GetScriptAttributeProgress(ply, slot, "projectile speed increased")
        local _, burnDmgInc, burnDmgHas = self:GetScriptAttributeProgress(ply, slot, "weapon burn dmg increased")
        local _, burnTimeInc, burnTimeHas = self:GetScriptAttributeProgress(ply, slot, "weapon burn time increased")
        local _, airblastInc, airblastHas = self:GetScriptAttributeProgress(ply, slot, "airblast pushback scale")
        local _, uberRateInc, uberRateHas = self:GetScriptAttributeProgress(ply, slot, "ubercharge rate bonus")
        local _, healRateInc, healRateHas = self:GetScriptAttributeProgress(ply, slot, "healing mastery")
        local _, overhealInc, overhealHas = self:GetScriptAttributeProgress(ply, slot, "overheal expert")
        local _, meterInc, meterHas = self:GetScriptAttributeProgress(ply, slot, "mult_item_meter_charge_rate")

        if wep.Primary and isnumber(wep.Primary.Delay) then
            wep.TF_MVM_BasePrimaryDelay = wep.TF_MVM_BasePrimaryDelay or wep.Primary.Delay
            local mul = nil
            if fireHasInc then
                mul = math.max(0.2, 1 + fireInc)
            else
                mul = math.max(0.2, 1 - ((slot == "melee" and 0.1 or 0.08) * fireLevel))
            end
            wep.Primary.Delay = wep.TF_MVM_BasePrimaryDelay * mul
        end

        if wep.Secondary and isnumber(wep.Secondary.Delay) and slot ~= "melee" then
            wep.TF_MVM_BaseSecondaryDelay = wep.TF_MVM_BaseSecondaryDelay or wep.Secondary.Delay
            local mul = nil
            if fireHasInc then
                mul = math.max(0.2, 1 + fireInc)
            else
                mul = math.max(0.2, 1 - (0.08 * fireLevel))
            end
            wep.Secondary.Delay = wep.TF_MVM_BaseSecondaryDelay * mul
        end

        if isnumber(wep.ReloadTime) then
            wep.TF_MVM_BaseReloadTime = wep.TF_MVM_BaseReloadTime or wep.ReloadTime
            local reloadMul = reloadHasInc and math.max(0.2, 1 + reloadInc) or math.max(0.2, 1 - (0.1 * reloadLevel))
            wep.ReloadTime = wep.TF_MVM_BaseReloadTime * reloadMul
        end
        -- tf_weapon_base consumes this NW var in its reload flow.
        local reloadNW = reloadHasInc and math.max(0.2, 1 + reloadInc) or math.max(0.2, 1 - (0.1 * reloadLevel))
        wep:SetNWFloat("ReloadTimeMultiplier", reloadNW)

        -- TF2-like "effect bar recharge rate increased" for drinks / jars / recharge secondaries.
        if effectbarLevel > 0 then
            local rechargeMul = effectbarHasInc and math.max(0.2, 1 + effectbarInc) or math.max(0.2, 1 - (0.25 * effectbarLevel))
            if isnumber(wep.RechargeTime) then
                wep.TF_MVM_BaseRechargeTime = wep.TF_MVM_BaseRechargeTime or wep.RechargeTime
                wep.RechargeTime = wep.TF_MVM_BaseRechargeTime * rechargeMul
            end
            if wep.Secondary and isnumber(wep.Secondary.Delay) and (wep.OffhandProjectileReady ~= nil or self:IsWeaponDrinkLike(wep)) then
                wep.TF_MVM_BaseOffhandDelay = wep.TF_MVM_BaseOffhandDelay or wep.Secondary.Delay
                wep.Secondary.Delay = wep.TF_MVM_BaseOffhandDelay * rechargeMul
            end
        end

        -- Buff banner family: extend active buff duration.
        if self:GetWeaponClassNameLower(wep):find("buff_item", 1, true) then
            if buffDurationHasInc then
                wep.TF_MVM_BuffDurationMul = math.max(0.1, 1 + buffDurationInc)
            else
                wep.TF_MVM_BuffDurationMul = 1 + (0.25 * buffDurationLevel)
            end
        end

        if sniperChargeHas then
            wep.SniperChargeRateMultiplier = math.max(0.1, 1 + sniperChargeInc)
        end
        if projSpeedHas then
            wep.TF_MVM_BaseProjectileSpeed = wep.TF_MVM_BaseProjectileSpeed or wep.ProjectileSpeed or 1
            wep.ProjectileSpeed = wep.TF_MVM_BaseProjectileSpeed * math.max(0.1, 1 + projSpeedInc)
            wep.ProjectileSpeedMultiplier = math.max(0.1, 1 + projSpeedInc)
        end
        if burnDmgHas then
            wep.BurnDamageMultiplier = math.max(0.1, 1 + burnDmgInc)
        end
        if burnTimeHas then
            wep.BurnTimeMultiplier = math.max(0.1, 1 + burnTimeInc)
        end
        if airblastHas then
            wep.AirblastPushbackMultiplier = math.max(0.1, 1 + airblastInc)
        end
        if uberRateHas then
            wep.UberchargeRateMultiplier = math.max(0.1, 1 + uberRateInc)
        end
        if healRateHas then
            wep.HealRateMultiplier = math.max(0.1, 1 + healRateInc)
        end
        if overhealHas then
            wep.OverhealMultiplier = math.max(0.1, 1 + overhealInc)
        end
        if meterHas then
            wep.ItemMeterChargeRateMultiplier = math.max(0.1, 1 + meterInc)
        end

        if wep.Primary and isnumber(wep.Primary.ClipSize) and wep.Primary.ClipSize > 0 then
            wep.TF_MVM_BaseClipSize = wep.TF_MVM_BaseClipSize or wep.Primary.ClipSize
            local clipMul = clipHasInc and (1 + clipInc) or (1 + (0.2 * clipLevel))
            local newClip = math.max(1, math.floor(wep.TF_MVM_BaseClipSize * clipMul))
            wep.Primary.ClipSize = newClip
            wep:SetClip1(math.min(wep:Clip1(), newClip))
        end

        local ammoType = wep.GetPrimaryAmmoType and wep:GetPrimaryAmmoType() or -1
        local ammoKey = nil
        if wep.Primary and isstring(wep.Primary.Ammo) and wep.Primary.Ammo ~= "" and wep.Primary.Ammo ~= "none" then
            ammoKey = wep.Primary.Ammo
        elseif isnumber(ammoType) and ammoType >= 0 and game.GetAmmoName then
            ammoKey = game.GetAmmoName(ammoType)
        end
        local ammoHandle = ammoKey or ammoType
        if ammoHandle ~= nil and ((isnumber(ammoHandle) and ammoHandle >= 0) or (isstring(ammoHandle) and ammoHandle ~= "" and ammoHandle ~= "none")) then
            local currentAmmo = math.max(0, ply:GetAmmoCount(ammoHandle))
            local baseAmmo = ply.TF_MVM_BaseAmmoByType[ammoHandle]
            if baseAmmo == nil then
                baseAmmo = currentAmmo
                ply.TF_MVM_BaseAmmoByType[ammoHandle] = baseAmmo
            end

            if ply.AmmoMax and ply.AmmoMax[ammoHandle] then
                local baseMax = ply.TF_MVM_BaseAmmoMaxByType[ammoHandle]
                if baseMax == nil then
                    baseMax = tonumber(ply.AmmoMax[ammoHandle]) or baseAmmo
                    ply.TF_MVM_BaseAmmoMaxByType[ammoHandle] = baseMax
                end
                local ammoMul = ammoHasInc and (1 + ammoInc) or (1 + (0.25 * ammoLevel))
                ply.AmmoMax[ammoHandle] = math.max(1, math.floor(baseMax * ammoMul))
            end

            if ammoLevel > 0 then
                local ammoMul = ammoHasInc and (1 + ammoInc) or (1 + (0.25 * ammoLevel))
                local targetAmmo = math.max(currentAmmo, math.floor(baseAmmo * ammoMul))
                if targetAmmo > currentAmmo then
                    if ply.SetAmmoCount then
                        ply:SetAmmoCount(targetAmmo, ammoHandle)
                    else
                        ply:SetAmmo(targetAmmo, ammoHandle)
                    end
                end
            elseif ply.AmmoMax and ply.AmmoMax[ammoHandle] then
                local clampedAmmo = math.min(currentAmmo, ply.AmmoMax[ammoHandle])
                if ply.SetAmmoCount then
                    ply:SetAmmoCount(clampedAmmo, ammoHandle)
                else
                    ply:SetAmmo(clampedAmmo, ammoHandle)
                end
            end
        end
    end
end

function TF_MVMShop:ApplyEngineerBuildingStats(ply)
    if not IsValid(ply) then return end
    local healthMul = 1 + (0.15 * self:GetLevel(ply, "building_health"))
    local fireMul = 1 + (0.1 * self:GetLevel(ply, "building_rate"))
    local _, engyHealthInc, engyHealthHas = self:GetScriptAttributeProgressAnyTarget(ply, "engy building health bonus")
    local _, engyRateInc, engyRateHas = self:GetScriptAttributeProgressAnyTarget(ply, "engy sentry fire rate increased")
    local _, dispRangeInc, dispRangeHas = self:GetScriptAttributeProgressAnyTarget(ply, "engy dispenser radius increased")
    local biTeleLevel = self:GetScriptAttributeProgressAnyTarget(ply, "bidirectional teleport")
    local instLevel = self:GetScriptAttributeProgressAnyTarget(ply, "building instant upgrade")
    if engyHealthHas then
        healthMul = healthMul * math.max(0.1, 1 + engyHealthInc)
    end
    if engyRateHas then
        fireMul = fireMul * math.max(0.1, 1 - engyRateInc)
    end
    for _, className in ipairs({ "obj_sentrygun", "obj_dispenser", "obj_teleporter" }) do
        for _, ent in ipairs(ents.FindByClass(className)) do
            if not IsValid(ent) or ent:GetOwner() ~= ply then continue end
            local base = ent.TF_MVM_BaseMaxHealth or ent:GetMaxHealth()
            ent.TF_MVM_BaseMaxHealth = base
            local newMax = math.max(1, math.floor(base * healthMul))
            ent:SetMaxHealth(newMax)
            ent:SetHealth(math.min(ent:Health(), newMax))
            if className == "obj_sentrygun" then
                ent.TF_MVM_BaseFireRate = ent.TF_MVM_BaseFireRate or (ent.FireRate or 0.1)
                ent.FireRate = ent.TF_MVM_BaseFireRate / fireMul
                local _, rocketSpecInc, rocketSpecHas = self:GetScriptAttributeProgress(ply, "primary", "rocket specialist")
                if rocketSpecHas then
                    ent.TF_MVM_RocketSpecialist = math.max(0, rocketSpecInc)
                end
            elseif className == "obj_dispenser" and dispRangeHas then
                ent.TF_MVM_BaseRange = ent.TF_MVM_BaseRange or tonumber(ent.Range) or 100
                ent.Range = math.max(32, math.floor(ent.TF_MVM_BaseRange * math.max(0.1, 1 + dispRangeInc)))
            elseif className == "obj_teleporter" then
                ent.TF_MVM_BidirectionalTeleport = (biTeleLevel and biTeleLevel > 0) and true or false
            end
            if instLevel and instLevel > 0 and ent.GetLevel and ent.Upgrade and ent.NumLevels then
                local levelNow = tonumber(ent:GetLevel()) or 1
                if levelNow < (tonumber(ent.NumLevels) or 3) then
                    ent:Upgrade()
                end
            end
        end
    end
end

function TF_MVMShop:ApplyPlayerStats(ply)
    if not self:IsEnabledFor(ply) then return end

    local hpBonus = 25 * self:GetLevel(ply, "max_health")
    local speedMul = 1 + (0.08 * self:GetLevel(ply, "move_speed"))
    local jumpMul = 1 + (0.2 * self:GetLevel(ply, "jump_height"))
    local buffDurationMul = 1 + (0.25 * self:GetLevel(ply, "buff_duration_secondary"))
    local _, dynHpInc, dynHpHas = self:GetScriptAttributeProgress(ply, "player", "max health additive bonus")
    local _, dynSpeedInc, dynSpeedHas = self:GetScriptAttributeProgress(ply, "player", "move speed bonus")
    local _, dynJumpInc, dynJumpHas = self:GetScriptAttributeProgress(ply, "player", "increased jump height")
    local _, dynBuffInc, dynBuffHas = self:GetScriptAttributeProgress(ply, "secondary", "increase buff duration")
    local _, dynMetalInc, dynMetalHas = self:GetScriptAttributeProgressAnyTarget(ply, "metal regen")
    local _, dynRegenInc, dynRegenHas = self:GetScriptAttributeProgressAnyTarget(ply, "health regen")
    local _, dynCanteenInc, dynCanteenHas = self:GetScriptAttributeProgressAnyTarget(ply, "canteen specialist")
    local _, dynDmgForceInc, dynDmgForceHas = self:GetScriptAttributeProgressAnyTarget(ply, "damage force reduction")
    local _, dynResBulletInc, dynResBulletHas = self:GetScriptAttributeProgressAnyTarget(ply, "dmg taken from bullets reduced")
    local _, dynResBlastInc, dynResBlastHas = self:GetScriptAttributeProgressAnyTarget(ply, "dmg taken from blast reduced")
    local _, dynResFireInc, dynResFireHas = self:GetScriptAttributeProgressAnyTarget(ply, "dmg taken from fire reduced")
    local _, dynResCritInc, dynResCritHas = self:GetScriptAttributeProgressAnyTarget(ply, "dmg taken from crit reduced")
    local _, dynHealOnKillInc, dynHealOnKillHas = self:GetScriptAttributeProgressAnyTarget(ply, "heal on kill")
    local _, dynCritOnKillInc, dynCritOnKillHas = self:GetScriptAttributeProgressAnyTarget(ply, "critboost on kill")
    local _, dynSnareInc, dynSnareHas = self:GetScriptAttributeProgressAnyTarget(ply, "applies snare effect")
    local _, dynMarkInc, dynMarkHas = self:GetScriptAttributeProgressAnyTarget(ply, "mark for death")
    local _, dynBleedInc, dynBleedHas = self:GetScriptAttributeProgressAnyTarget(ply, "bleeding duration")
    local _, dynUberDurInc, dynUberDurHas = self:GetScriptAttributeProgressAnyTarget(ply, "uber duration bonus")

    if dynHpHas then hpBonus = hpBonus + math.floor(dynHpInc + 0.5) end
    if dynSpeedHas then speedMul = speedMul * math.max(0.1, 1 + dynSpeedInc) end
    if dynJumpHas then jumpMul = jumpMul * math.max(0.1, 1 + dynJumpInc) end
    if dynBuffHas then buffDurationMul = buffDurationMul * math.max(0.1, 1 + dynBuffInc) end

    local maxHp = self:GetBaseHealth(ply) + hpBonus
    ply:SetMaxHealth(maxHp)
    if ply:Health() > maxHp then
        ply:SetHealth(maxHp)
    end

    local speed = math.floor(self:GetBaseSpeed(ply) * speedMul)
    if ply.SetClassSpeed then
        ply:SetClassSpeed(speed)
    else
        ply:SetWalkSpeed(speed)
        ply:SetRunSpeed(speed)
    end

    local classTable = ply.GetPlayerClassTable and ply:GetPlayerClassTable() or nil
    local baseJump = tonumber(ply.TF_MVM_BaseJumpPower)
    if not baseJump or baseJump <= 0 then
        baseJump = tonumber(ply.PlayerJumpPower)
            or tonumber(classTable and classTable.JumpPower)
            or tonumber(ply:GetJumpPower())
            or 220
        if baseJump <= 0 then
            baseJump = 220
        end
    end
    local jumpPower = math.floor((baseJump * jumpMul) + 0.5)
    ply.TF_MVM_BaseJumpPower = baseJump
    -- ResetClassSpeed in class code writes PlayerJumpPower back into SetJumpPower.
    ply.PlayerJumpPower = jumpPower
    ply:SetJumpPower(jumpPower)
    ply:SetNWFloat("TF_MVM_BuffDurationMul", buffDurationMul)
    ply.TF_MVM_Dynamic = ply.TF_MVM_Dynamic or {}
    ply.TF_MVM_Dynamic.HealthRegenPerSec = dynRegenHas and math.max(0, dynRegenInc) or 0
    ply.TF_MVM_Dynamic.MetalRegenPerSec = dynMetalHas and math.max(0, dynMetalInc) or 0
    ply.TF_MVM_Dynamic.CanteenBonus = dynCanteenHas and math.max(0, math.floor(dynCanteenInc + 0.5)) or 0
    ply.TF_MVM_Dynamic.DamageForceMult = dynDmgForceHas and math.max(0.1, 1 - math.max(0, dynDmgForceInc)) or 1
    ply.TF_MVM_Dynamic.ResistBulletMult = dynResBulletHas and math.max(0.1, 1 + dynResBulletInc) or 1
    ply.TF_MVM_Dynamic.ResistBlastMult = dynResBlastHas and math.max(0.1, 1 + dynResBlastInc) or 1
    ply.TF_MVM_Dynamic.ResistFireMult = dynResFireHas and math.max(0.1, 1 + dynResFireInc) or 1
    ply.TF_MVM_Dynamic.ResistCritMult = dynResCritHas and math.max(0.1, 1 + dynResCritInc) or 1
    ply.TF_MVM_Dynamic.HealOnKill = dynHealOnKillHas and math.max(0, math.floor(dynHealOnKillInc + 0.5)) or 0
    ply.TF_MVM_Dynamic.CritOnKillDuration = dynCritOnKillHas and math.max(0, dynCritOnKillInc) or 0
    ply.TF_MVM_Dynamic.SnareScale = dynSnareHas and dynSnareInc or 0
    ply.TF_MVM_Dynamic.MarkForDeathDuration = dynMarkHas and math.max(0, dynMarkInc) or 0
    ply.TF_MVM_Dynamic.BleedDuration = dynBleedHas and math.max(0, dynBleedInc) or 0
    ply.TF_MVM_Dynamic.UberDurationBonus = dynUberDurHas and math.max(0, dynUberDurInc) or 0

    local _, maxMetalInc, maxMetalHas = self:GetScriptAttributeProgressAnyTarget(ply, "maxammo metal increased")
    if maxMetalHas and ply.AmmoMax and ply.AmmoMax[TF_METAL] then
        ply.TF_MVM_BaseAmmoMaxByType = ply.TF_MVM_BaseAmmoMaxByType or {}
        local base = ply.TF_MVM_BaseAmmoMaxByType[TF_METAL] or tonumber(ply.AmmoMax[TF_METAL]) or 0
        ply.TF_MVM_BaseAmmoMaxByType[TF_METAL] = base
        ply.AmmoMax[TF_METAL] = math.max(1, math.floor(base * (1 + maxMetalInc)))
    end
    local _, maxGrenInc, maxGrenHas = self:GetScriptAttributeProgressAnyTarget(ply, "maxammo grenades1 increased")
    if maxGrenHas and ply.AmmoMax and ply.AmmoMax[TF_GRENADES1] then
        ply.TF_MVM_BaseAmmoMaxByType = ply.TF_MVM_BaseAmmoMaxByType or {}
        local base = ply.TF_MVM_BaseAmmoMaxByType[TF_GRENADES1] or tonumber(ply.AmmoMax[TF_GRENADES1]) or 0
        ply.TF_MVM_BaseAmmoMaxByType[TF_GRENADES1] = base
        ply.AmmoMax[TF_GRENADES1] = math.max(1, math.floor(base * (1 + maxGrenInc)))
    end

    self:ApplyWeaponStats(ply)
    self:ApplyEngineerBuildingStats(ply)
end

function TF_MVMShop:GetUpgradeSellRefund(ply, id)
    local upgrade = upgradesById[id]
    if not upgrade then return nil end
    local level = self:GetLevel(ply, id)
    if level <= 0 then return nil end
    return upgrade.costs[level]
end

function TF_MVMShop:GetMaxCanteenCharges(ply)
    local dynamicBonus = 0
    if IsValid(ply) and ply.TF_MVM_Dynamic then
        dynamicBonus = tonumber(ply.TF_MVM_Dynamic.CanteenBonus) or 0
    end
    return 1 + self:GetLevel(ply, "canteen_capacity") + math.max(0, math.floor(dynamicBonus))
end

function TF_MVMShop:SyncCanteenNW(ply)
    local state = self:GetState(ply)
    ply:SetNWString("TF_MVM_CanteenSelected", state.canteen.selected or "crit")
    ply:SetNWInt("TF_MVM_Canteen_crit", ClampInt(state.canteen.charges.crit))
    ply:SetNWInt("TF_MVM_Canteen_uber", ClampInt(state.canteen.charges.uber))
    ply:SetNWInt("TF_MVM_Canteen_refill", ClampInt(state.canteen.charges.refill))
    ply:SetNWInt("TF_MVM_Canteen_build", ClampInt(state.canteen.charges.build))
end

function TF_MVMShop:BuildPayload(ply)
    local state = self:GetState(ply)
    local list = {}
    local strictMatrix, strictAllowedSet = self:BuildStrictUpgradeValidationMatrix(ply)
    state.strictUpgradeMatrix = strictMatrix

    for _, upgrade in ipairs(self.Upgrades) do
        local scriptAllowed = self:IsUpgradeEnabledByScript(upgrade)
        local classAllowed = self:IsUpgradeAllowedForClass(ply, upgrade)
        local weaponAllowed, restrictionReason = self:IsUpgradeAllowedForLoadout(ply, upgrade)
        local matrixAllowed = strictAllowedSet[upgrade.id] == true
        local available = scriptAllowed and classAllowed and weaponAllowed and matrixAllowed
        if available then
            local level = self:GetLevel(ply, upgrade.id)
            local costs = istable(upgrade.costs) and upgrade.costs or {}
            local maxLevel = math.max(1, #costs)
            local nextCost = tonumber(costs[level + 1]) or 0
            local displayName = tostring(upgrade.name or "")
            displayName = TF_MVMShop.DisplayNameById[upgrade.id]
                or displayName
                or ""
            if displayName == "" or #displayName <= 2 then
                displayName = PrettifyAttributeName(TF_MVMShop.CustomUpgradeAttributeMap[upgrade.id] or upgrade.id)
            end
            list[#list + 1] = {
                id = upgrade.id,
                name = displayName,
                description = upgrade.description or TF_MVMShop.ScriptDescriptionById[upgrade.id] or "",
                category = upgrade.category,
                target = upgrade.target,
                level = level,
                maxLevel = maxLevel,
                nextCost = nextCost,
                classAllowed = classAllowed,
                weaponAllowed = weaponAllowed,
                available = available,
                restrictionReason = restrictionReason,
                icon = upgrade.icon,
            }
        end
    end

    return {
        credits = self:GetCredits(ply),
        inSetup = TF_MVMState and TF_MVMState:Get("in_setup", false) or false,
        waveCurrent = TF_MVMState and TF_MVMState:Get("wave_current", 0) or 0,
        waveTotal = TF_MVMState and TF_MVMState:Get("wave_total", 0) or 0,
        canteen = {
            selected = state.canteen.selected,
            maxCharges = self:GetMaxCanteenCharges(ply),
            charges = {
                crit = ClampInt(state.canteen.charges.crit),
                uber = ClampInt(state.canteen.charges.uber),
                refill = ClampInt(state.canteen.charges.refill),
                build = ClampInt(state.canteen.charges.build),
            },
        },
        canteenTypes = self.CanteenTypes,
        upgrades = list,
    }
end

if SERVER then
    concommand.Add("tf_mvm_dump_upgrade_matrix", function(ply)
        if not IsValid(ply) then return end
        if not TF_MVMShop:IsEnabledFor(ply) then
            ply:ChatPrint("[MVM] Upgrade system not enabled for this player.")
            return
        end
        local matrix = select(1, TF_MVMShop:BuildStrictUpgradeValidationMatrix(ply))
        local lines = TF_MVMShop:FormatStrictUpgradeMatrixLines(ply, matrix)
        for _, line in ipairs(lines) do
            ply:PrintMessage(HUD_PRINTCONSOLE, line .. "\n")
        end
        ply:ChatPrint("[MVM] Printed strict upgrade matrix to your console.")
    end)

    local function IsPlayerSpectatingTarget(spec, target)
        if not IsValid(spec) or not spec:IsPlayer() then return false end
        if not IsValid(target) or not target:IsPlayer() then return false end
        if spec == target then return false end
        if not spec.GetObserverTarget then return false end
        local observed = spec:GetObserverTarget()
        return IsValid(observed) and observed == target
    end

    local function GetSpectatorsWatching(target)
        local out = {}
        for _, spec in ipairs(player.GetAll()) do
            if IsPlayerSpectatingTarget(spec, target) then
                out[#out + 1] = spec
            end
        end
        return out
    end

    local function SendPanelToViewer(subject, viewer, spectatorView)
        if not IsValid(subject) or not IsValid(viewer) then return end
        local payload = TF_MVMShop:BuildPayload(subject)
        payload.spectatorView = spectatorView and true or false
        payload.observedEntIndex = subject:EntIndex()
        payload.observedName = subject:Nick()
        net.Start("TF_MVM_UpgradeOpen")
        net.WriteTable(payload)
        net.Send(viewer)
    end

    local function SendCloseToSpectators(target)
        for _, spec in ipairs(GetSpectatorsWatching(target)) do
            net.Start("TF_MVM_UpgradeClose")
            net.Send(spec)
        end
    end

    local function SendPanel(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        SendPanelToViewer(ply, ply, false)
        for _, spec in ipairs(GetSpectatorsWatching(ply)) do
            SendPanelToViewer(ply, spec, true)
            spec.TF_MVMShopWatching = ply
        end
        ply.TF_MVMUpgradePanelOpen = true
        ply.TF_MVMUpgradePanelOpenedAt = CurTime()
    end

    function TF_MVMShop:IsNearUpgradeStation(ply)
        if ply:GetNWBool("TF_MVM_InUpgradeStation", false) then return true end
        local eyePos = ply:EyePos()
        for _, ent in ipairs(ents.FindInSphere(eyePos, 170)) do
            if not IsValid(ent) then continue end
            local className = string.lower(ent:GetClass() or "")
            local entName = ent.GetName and string.lower(ent:GetName() or "") or ""
            if string.find(className, "upgrade", 1, true) or string.find(entName, "upgrade", 1, true) then
                return true
            end
        end
        return false
    end

    function TF_MVMShop:ResetPlayer(ply, startingCredits)
        local state = self:GetState(ply)
        state.spent = 0
        state.buybacks = 0
        state.upgrades = {}
        state.canteen.selected = "crit"
        state.canteen.cooldown = 0
        state.canteen.charges = { crit = 0, uber = 0, refill = 0, build = 0 }
        self:SetCredits(ply, startingCredits or self.StartingCredits)
        self:SyncCanteenNW(ply)
        self:ApplyPlayerStats(ply)
    end

    function TF_MVMShop:ResetAllPlayers(startingCredits)
        for _, ply in ipairs(player.GetAll()) do
            if self:IsEnabledFor(ply) then
                self:ResetPlayer(ply, startingCredits)
            end
        end
    end

    function TF_MVMShop:BuyUpgrade(ply, id)
        local can, reason = self:CanBuyUpgrade(ply, id)
        if not can then return false, reason end
        local upgrade = upgradesById[id]
        if not upgrade then return false, "invalid_upgrade" end
        local canteenType = self:GetCanteenTypeForScriptAttribute(upgrade.scriptAttribute)
        if tonumber(upgrade.scriptUiGroup) == 2 and canteenType then
            return self:BuyCanteenCharge(ply, canteenType)
        end

        local cost = self:GetUpgradeCost(ply, id)
        if not cost then return false, "invalid_upgrade" end

        local state = self:GetState(ply)
        self:AddCredits(ply, -cost)
        self:SetLevel(ply, id, self:GetLevel(ply, id) + 1)
        state.spent = state.spent + cost
        self:ApplyPlayerStats(ply)
        if id == "max_health" then
            ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + 25))
        end
        ply:EmitSound("MVM.PlayerUpgraded")
        return true
    end

    function TF_MVMShop:SellUpgrade(ply, id)
        local can, reason = self:CanSellUpgrade(ply, id)
        if not can then return false, reason end
        local refund = self:GetUpgradeSellRefund(ply, id)
        if not refund then return false, "invalid_upgrade" end

        local state = self:GetState(ply)
        self:SetLevel(ply, id, self:GetLevel(ply, id) - 1)
        self:AddCredits(ply, refund)
        state.spent = math.max(0, (tonumber(state.spent) or 0) - refund)
        self:ApplyPlayerStats(ply)
        if id == "max_health" and ply:Health() > ply:GetMaxHealth() then
            ply:SetHealth(ply:GetMaxHealth())
        end
        return true
    end

    function TF_MVMShop:Respec(ply)
        if not self:IsEnabledFor(ply) then return false, "not_enabled" end
        if not self:IsSetupOpenForPurchases() then return false, "setup_only" end

        local state = self:GetState(ply)
        local refund = ClampInt(state.spent)
        state.spent = 0
        state.upgrades = {}
        self:AddCredits(ply, refund)
        self:ApplyPlayerStats(ply)
        ply:Spawn()
        return true
    end

    function TF_MVMShop:BuyCanteenCharge(ply, ctype)
        if not self:IsEnabledFor(ply) then return false, "not_enabled" end
        if not self:IsSetupOpenForPurchases() then return false, "setup_only" end

        local c = self.CanteenTypes[ctype]
        if not c then return false, "invalid_canteen" end

        local state = self:GetState(ply)
        if ClampInt(state.canteen.charges[ctype]) >= self:GetMaxCanteenCharges(ply) then
            return false, "canteen_full"
        end

        if self:GetCredits(ply) < c.cost then
            return false, "no_credits"
        end

        self:AddCredits(ply, -c.cost)
        state.canteen.charges[ctype] = ClampInt(state.canteen.charges[ctype]) + 1
        self:SyncCanteenNW(ply)
        return true
    end

    function TF_MVMShop:SelectCanteen(ply, ctype)
        if not self.CanteenTypes[ctype] then return false, "invalid_canteen" end
        self:GetState(ply).canteen.selected = ctype
        self:SyncCanteenNW(ply)
        return true
    end
    local function ApplyCanteenCrit(ply)
        if GAMEMODE and GAMEMODE.AddCritBoostTime then
            GAMEMODE:AddCritBoostTime(ply, 8)
        end
    end

    local function ApplyCanteenUber(ply)
        local bonus = (ply.TF_MVM_Dynamic and tonumber(ply.TF_MVM_Dynamic.UberDurationBonus)) or 0
        ply.TF_MVMUberUntil = CurTime() + 5 + math.max(0, bonus)
        ply:SetNWFloat("TF_MVMUberUntil", ply.TF_MVMUberUntil)
    end

    local function ApplyCanteenRefill(ply)
        for _, wep in ipairs(ply:GetWeapons()) do
            if not IsValid(wep) then continue end
            local max1 = wep:GetMaxClip1()
            if max1 and max1 > 0 then wep:SetClip1(max1) end
            local max2 = wep:GetMaxClip2()
            if max2 and max2 > 0 then wep:SetClip2(max2) end
        end
        if GAMEMODE and GAMEMODE.GiveAmmoPercent then
            GAMEMODE:GiveAmmoPercent(ply, 100)
        end
    end

    local function ApplyCanteenBuildings(ply)
        local healthMul = 1 + (0.15 * TF_MVMShop:GetLevel(ply, "building_health"))
        local fireMul = 1 + (0.1 * TF_MVMShop:GetLevel(ply, "building_rate"))
        for _, className in ipairs({ "obj_sentrygun", "obj_dispenser", "obj_teleporter" }) do
            for _, ent in ipairs(ents.FindByClass(className)) do
                if not IsValid(ent) or ent:GetOwner() ~= ply then continue end
                local base = ent.TF_MVM_BaseMaxHealth or ent:GetMaxHealth()
                ent.TF_MVM_BaseMaxHealth = base
                local newMax = math.max(1, math.floor(base * healthMul))
                ent:SetMaxHealth(newMax)
                ent:SetHealth(newMax)
                if className == "obj_sentrygun" then
                    ent.FireRate = (ent.FireRate or 0.1) / fireMul
                end
            end
        end
    end

    function TF_MVMShop:GetBuybackCost(ply)
        local state = self:GetState(ply)
        local wave = TF_MVMState and ClampInt(TF_MVMState:Get("wave_current", 1)) or 1
        local base = self.BuybackBaseCost + (state.buybacks * 150)
        return math.floor(base * (1 + ((wave - 1) * 0.15)))
    end

    function TF_MVMShop:TryBuyback(ply)
        if not self:IsEnabledFor(ply) then return false, "not_enabled" end
        if ply:Alive() then return false, "alive" end
        if not (TF_MVM and TF_MVM.Runtime and TF_MVM.Runtime:IsWaveInProgress()) then return false, "wave_only" end

        local cost = self:GetBuybackCost(ply)
        if self:GetCredits(ply) < cost then return false, "no_credits" end

        local state = self:GetState(ply)
        state.buybacks = state.buybacks + 1
        self:AddCredits(ply, -cost)
        ply:Spawn()
        ply:EmitSound("MVM.PlayerBoughtIn")
        return true
    end

    function TF_MVMShop:UseCanteen(ply)
        if not self:IsEnabledFor(ply) then return false, "not_enabled" end
        if not ply:Alive() then return self:TryBuyback(ply) end

        if TF_MVM and TF_MVM.Runtime and TF_MVM.Runtime:IsManagedActive() and not TF_MVM.Runtime:IsWaveInProgress() then
            return false, "wave_only"
        end

        local state = self:GetState(ply)
        if state.canteen.cooldown > CurTime() then return false, "cooldown" end

        local selected = state.canteen.selected or "crit"
        local charges = ClampInt(state.canteen.charges[selected])
        if charges <= 0 then return false, "no_charge" end

        state.canteen.charges[selected] = charges - 1
        state.canteen.cooldown = CurTime() + 1.5

        if selected == "crit" then
            ApplyCanteenCrit(ply)
        elseif selected == "uber" then
            ApplyCanteenUber(ply)
        elseif selected == "refill" then
            ApplyCanteenRefill(ply)
        elseif selected == "build" then
            ApplyCanteenBuildings(ply)
        end

        self:SyncCanteenNW(ply)
        ply:EmitSound("MVM.PlayerUsedPowerup")
        return true
    end

    hook.Add("PlayerInitialSpawn", "TF_MVMShop_Init", function(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            TF_MVMShop:GetState(ply)
            local missionStart = TF_MVM and TF_MVM.Runtime and TF_MVM.Runtime.Mission and tonumber(TF_MVM.Runtime.Mission.StartingCurrency) or nil
            TF_MVMShop:SetCredits(ply, missionStart or TF_MVMShop.StartingCredits)
            TF_MVMShop:SyncCanteenNW(ply)
        end)
    end)

    hook.Add("PlayerSpawn", "TF_MVMShop_OnSpawn", function(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            TF_MVMShop:ApplyPlayerStats(ply)
        end)
    end)

    hook.Add("PlayerSwitchWeapon", "TF_MVMShop_OnSwitch", function(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        TF_MVMShop:ApplyPlayerStats(ply)
    end)

    hook.Add("EntityTakeDamage", "TF_MVMShop_DamageHooks", function(target, dmginfo)
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() and TF_MVMShop:IsEnabledFor(attacker) then
            local slot = ""
            local weapon = attacker:GetActiveWeapon()
            if IsValid(weapon) then slot = TF_MVMShop:GetWeaponSlotName(weapon) end
            dmginfo:ScaleDamage(TF_MVMShop:GetDamageMultiplier(attacker, slot))
            local dynAtk = attacker.TF_MVM_Dynamic or {}
            if IsValid(target) and target:IsPlayer() then
                local markDur = tonumber(dynAtk.MarkForDeathDuration) or 0
                if markDur > 0 and target.AddPlayerState and target.RemovePlayerState then
                    target:AddPlayerState(PLAYERSTATE_MARKED, true)
                    timer.Create("TF_MVMShop_Mark_" .. target:EntIndex(), markDur, 1, function()
                        if IsValid(target) then
                            target:RemovePlayerState(PLAYERSTATE_MARKED, true)
                        end
                    end)
                end
                local snareScale = tonumber(dynAtk.SnareScale) or 0
                if snareScale < 0 and target.AddPlayerState and target.RemovePlayerState then
                    local dur = math.max(0.2, math.min(3, math.abs(snareScale) * 2))
                    target:AddPlayerState(PLAYERSTATE_STUNNED, true)
                    timer.Create("TF_MVMShop_Snare_" .. target:EntIndex(), dur, 1, function()
                        if IsValid(target) then
                            target:RemovePlayerState(PLAYERSTATE_STUNNED, true)
                        end
                    end)
                end
            end
        end

        if IsValid(target) and target:IsPlayer() and TF_MVMShop:IsEnabledFor(target) then
            if target.TF_MVMUberUntil and target.TF_MVMUberUntil > CurTime() then
                dmginfo:ScaleDamage(0)
                return
            end
            local dyn = target.TF_MVM_Dynamic or {}
            dmginfo:SetDamageForce(dmginfo:GetDamageForce() * (tonumber(dyn.DamageForceMult) or 1))

            local resistAll = TF_MVMShop:GetLevel(target, "resist_all")
            if resistAll > 0 then
                dmginfo:ScaleDamage(math.max(0.2, 1 - (0.08 * resistAll)))
            end

            local damageType = dmginfo:GetDamageType()
            if bit.band(damageType, DMG_BULLET) ~= 0 then
                local v = TF_MVMShop:GetLevel(target, "resist_bullet")
                if v > 0 then dmginfo:ScaleDamage(math.max(0.15, 1 - (0.1 * v))) end
                dmginfo:ScaleDamage(tonumber(dyn.ResistBulletMult) or 1)
            end
            if bit.band(damageType, DMG_BLAST) ~= 0 then
                local v = TF_MVMShop:GetLevel(target, "resist_blast")
                if v > 0 then dmginfo:ScaleDamage(math.max(0.15, 1 - (0.1 * v))) end
                dmginfo:ScaleDamage(tonumber(dyn.ResistBlastMult) or 1)
            end
            if bit.band(damageType, DMG_BURN) ~= 0 then
                local v = TF_MVMShop:GetLevel(target, "resist_fire")
                if v > 0 then dmginfo:ScaleDamage(math.max(0.15, 1 - (0.12 * v))) end
                dmginfo:ScaleDamage(tonumber(dyn.ResistFireMult) or 1)
            end
            if dmginfo:IsDamageType(DMG_CRUSH) or dmginfo:IsDamageType(DMG_CLUB) or dmginfo:IsDamageType(DMG_SLASH) then
                dmginfo:ScaleDamage(tonumber(dyn.ResistCritMult) or 1)
            end
        end
    end)

    hook.Add("PlayerDeath", "TF_MVMShop_HealOnKill", function(victim, inflictor, attacker)
        if not IsValid(attacker) or not attacker:IsPlayer() then return end
        if attacker == victim or not TF_MVMShop:IsEnabledFor(attacker) then return end
        if not attacker:Alive() then return end

        local healAmount = 0

        local meleeLevel = TF_MVMShop:GetLevel(attacker, "lifesteal_melee")
        if meleeLevel > 0 then
            local meleeKill = false
            if IsValid(inflictor) and inflictor:IsWeapon() then
                meleeKill = TF_MVMShop:GetWeaponSlotName(inflictor) == "melee"
            end
            if not meleeKill then
                local active = attacker:GetActiveWeapon()
                if IsValid(active) then
                    meleeKill = TF_MVMShop:GetWeaponSlotName(active) == "melee"
                end
            end
            if meleeKill then
                healAmount = healAmount + (meleeLevel * 25)
            end
        end

        if healAmount > 0 then
            attacker:SetHealth(math.min(attacker:Health() + healAmount, attacker:GetMaxHealth()))
        end

        local dyn = attacker.TF_MVM_Dynamic or {}
        local genericHeal = tonumber(dyn.HealOnKill) or 0
        if genericHeal > 0 then
            attacker:SetHealth(math.min(attacker:Health() + math.floor(genericHeal), attacker:GetMaxHealth()))
        end
        local critDur = tonumber(dyn.CritOnKillDuration) or 0
        if critDur > 0 and GAMEMODE and GAMEMODE.AddCritBoostTime then
            GAMEMODE:AddCritBoostTime(attacker, critDur)
        end
    end)

    hook.Add("Think", "TF_MVMShop_AutoHealRegen", function()
        TF_MVMShop._NextAutoHealTick = TF_MVMShop._NextAutoHealTick or 0
        if CurTime() < TF_MVMShop._NextAutoHealTick then return end
        TF_MVMShop._NextAutoHealTick = CurTime() + 1

        for _, ply in ipairs(player.GetAll()) do
            if not TF_MVMShop:IsEnabledFor(ply) then continue end
            if not ply:Alive() then continue end

            local hp = ply:Health()
            local maxHp = ply:GetMaxHealth()
            local level = TF_MVMShop:GetLevel(ply, "autoheal")
            local healPerSec = 2 * level
            local dyn = ply.TF_MVM_Dynamic or {}
            healPerSec = healPerSec + math.max(0, tonumber(dyn.HealthRegenPerSec) or 0)
            if healPerSec > 0 and hp < maxHp then
                ply:SetHealth(math.min(maxHp, hp + healPerSec))
            end

            local metalRegen = math.max(0, tonumber(dyn.MetalRegenPerSec) or 0)
            if metalRegen > 0 and ply.AmmoMax and ply.AmmoMax[TF_METAL] then
                local metal = math.max(0, ply:GetAmmoCount(TF_METAL))
                local newMetal = math.min(tonumber(ply.AmmoMax[TF_METAL]) or metal, metal + metalRegen)
                if ply.SetAmmoCount then
                    ply:SetAmmoCount(newMetal, TF_METAL)
                else
                    ply:SetAmmo(newMetal, TF_METAL)
                end
            end
        end
    end)

    hook.Add("Think", "TF_MVMShop_BuildingUpgradeThink", function()
        TF_MVMShop._NextBuildingUpgradeTick = TF_MVMShop._NextBuildingUpgradeTick or 0
        if CurTime() < TF_MVMShop._NextBuildingUpgradeTick then return end
        TF_MVMShop._NextBuildingUpgradeTick = CurTime() + 1.0
        for _, ply in ipairs(player.GetAll()) do
            if TF_MVMShop:IsEnabledFor(ply) then
                TF_MVMShop:ApplyEngineerBuildingStats(ply)
            end
        end
    end)

    hook.Add("TF_MVM_MissionStarted", "TF_MVMShop_ResetMission", function(mission)
        local start = tonumber(mission and mission.StartingCurrency) or TF_MVMShop.StartingCredits
        TF_MVMShop:ResetAllPlayers(start)
    end)

    hook.Add("TF_MVM_WaveStarted", "TF_MVMShop_ResetBuybacks", function()
        for _, ply in ipairs(player.GetAll()) do
            if TF_MVMShop:IsEnabledFor(ply) then
                TF_MVMShop:GetState(ply).buybacks = 0
            end
        end
    end)

    hook.Add("Think", "TF_MVMShop_SpectatorMirror", function()
        TF_MVMShop._NextSpectatorMirrorTick = TF_MVMShop._NextSpectatorMirrorTick or 0
        if CurTime() < TF_MVMShop._NextSpectatorMirrorTick then return end
        TF_MVMShop._NextSpectatorMirrorTick = CurTime() + 0.25

        for _, spec in ipairs(player.GetAll()) do
            if not IsValid(spec) then continue end
            if not spec.GetObserverTarget then continue end

            local observed = spec:GetObserverTarget()
            if IsValid(observed) and observed:IsPlayer() and observed.TF_MVMUpgradePanelOpen then
                if spec.TF_MVMShopWatching ~= observed then
                    SendPanelToViewer(observed, spec, true)
                    spec.TF_MVMShopWatching = observed
                end
            elseif IsValid(spec.TF_MVMShopWatching) then
                net.Start("TF_MVM_UpgradeClose")
                net.Send(spec)
                spec.TF_MVMShopWatching = nil
            end
        end
    end)

    hook.Add("KeyPress", "TF_MVMShop_OpenOnUse", function(ply, key)
        if key ~= IN_USE then return end
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        if not TF_MVMShop:IsNearUpgradeStation(ply) then return end
        SendPanel(ply)
    end)

    concommand.Add("tf_mvm_shop", function(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        if not TF_MVMShop:IsNearUpgradeStation(ply) then return end
        SendPanel(ply)
    end)

    concommand.Add("tf_mvm_use_canteen", function(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        TF_MVMShop:UseCanteen(ply)
    end)

    concommand.Add("tf_mvm_buyback", function(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        TF_MVMShop:TryBuyback(ply)
    end)

    concommand.Add("use_action_slot_item", function(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        if TF_MVM and TF_MVM.Runtime and TF_MVM.Runtime:IsManagedActive() and TF_MVM.Runtime:IsSetupPhase() then
            TF_MVM.Runtime:TogglePlayerReady(ply)
            return
        end
        TF_MVMShop:UseCanteen(ply)
    end)

    net.Receive("TF_MVM_CanteenUse", function(_, ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        TF_MVMShop:UseCanteen(ply)
        SendPanel(ply)
    end)

    net.Receive("TF_MVM_UpgradeAction", function(_, ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end

        local action = net.ReadString()
        local arg = net.ReadString()

        if action == "ui_closed" then
            ply.TF_MVMUpgradePanelOpen = nil
            SendCloseToSpectators(ply)
            return
        end

        local nearStation = TF_MVMShop:IsNearUpgradeStation(ply)
        local hasOpenContext = ply.TF_MVMUpgradePanelOpen
            and ((CurTime() - (tonumber(ply.TF_MVMUpgradePanelOpenedAt) or 0)) <= 30)

        if not nearStation and not hasOpenContext then
            ply.TF_MVMUpgradePanelOpen = nil
            net.Start("TF_MVM_UpgradeClose")
            net.Send(ply)
            SendCloseToSpectators(ply)
            if action == "buy_upgrade" then
                ply:ChatPrint("[MvM] Upgrade failed: not near station")
            end
            return
        end

        if action == "request_open" then
            SendPanel(ply)
            return
        elseif action == "buy_upgrade" then
            local ok, reason = TF_MVMShop:BuyUpgrade(ply, arg)
            if not ok then
                local why = tostring(reason or "unknown")
                ply:ChatPrint("[MvM] Upgrade failed: " .. why)
                print(string.format("[MVMShop] buy failed player=%s id=%s reason=%s credits=%d setup=%s near=%s",
                    tostring(IsValid(ply) and ply:Nick() or "unknown"),
                    tostring(arg or ""),
                    why,
                    tonumber(TF_MVMShop:GetCredits(ply) or 0) or 0,
                    tostring(TF_MVMShop:IsSetupOpenForPurchases()),
                    tostring(TF_MVMShop:IsNearUpgradeStation(ply))
                ))
            end
        elseif action == "sell_upgrade" then
            TF_MVMShop:SellUpgrade(ply, arg)
        elseif action == "respec" then
            local ok, reason = TF_MVMShop:Respec(ply)
            if ok then
                ply.TF_MVMUpgradePanelOpen = nil
                net.Start("TF_MVM_UpgradeClose")
                net.Send(ply)
                SendCloseToSpectators(ply)
                return
            end
        elseif action == "buy_canteen" then
            TF_MVMShop:BuyCanteenCharge(ply, arg)
        elseif action == "select_canteen" then
            TF_MVMShop:SelectCanteen(ply, arg)
        elseif action == "buyback" then
            TF_MVMShop:TryBuyback(ply)
        end

        SendPanel(ply)
    end)
else
    include("vgui/vgui_tf2res.lua")

    local function IsNearUpgradeStationClient()
        local ply = LocalPlayer()
        if not IsValid(ply) then return false end
        if ply:GetNWBool("TF_MVM_InUpgradeStation", false) then return true end

        local eyePos = ply:EyePos()
        for _, ent in ipairs(ents.FindInSphere(eyePos, 170)) do
            if not IsValid(ent) then continue end
            local className = string.lower(ent:GetClass() or "")
            local entName = ent.GetName and string.lower(ent:GetName() or "") or ""
            if string.find(className, "upgrade", 1, true) or string.find(entName, "upgrade", 1, true) then
                return true
            end
        end

        return false
    end

    local function SendAction(action, arg)
        net.Start("TF_MVM_UpgradeAction")
        net.WriteString(action or "")
        net.WriteString(arg or "")
        net.SendToServer()
    end

    local UPGRADE_ICON = {
        max_health = "vgui/achievements/tf_heavy_heal_medikits",
        move_speed = "vgui/achievements/tf_scout_long_distance_runner",
        resist_all = "vgui/achievements/tf_soldier_shoot_mult_crits",
        resist_bullet = "vgui/mvm/upgradeicons/upgrade_resistance_bullet",
        resist_blast = "vgui/achievements/tf_demoman_kill_x_heavies_fullhp_onedet",
        resist_fire = "vgui/mvm/upgradeicons/upgrade_resistance_fire",
        autoheal = "vgui/achievements/tf_pyro_burn_medicpair",
        jump_height = "vgui/achievements/tf_scout_double_jumps",
        damage_primary = "vgui/achievements/tf_demoman_kill_x_with_directpipe",
        firerate_primary = "vgui/achievements/tf_scout_dodge_damage",
        reload_primary = "vgui/achievements/tf_heavy_survive_crocket",
        clip_primary = "vgui/achievements/tf_scout_destroy_sentry_with_pistol",
        ammo_primary = "vgui/achievements/tf_heavy_assist_grind",
        effectbar_primary = "vgui/achievements/tf_win_well_minimumtime",
        damage_secondary = "vgui/achievements/tf_demoman_kill_x_with_directpipe",
        firerate_secondary = "vgui/achievements/tf_scout_dodge_damage",
        reload_secondary = "vgui/achievements/tf_heavy_survive_crocket",
        clip_secondary = "vgui/achievements/tf_scout_destroy_sentry_with_pistol",
        ammo_secondary = "vgui/achievements/tf_heavy_assist_grind",
        effectbar_secondary = "vgui/achievements/tf_win_well_minimumtime",
        buff_duration_secondary = "vgui/achievements/tf_soldier_buff_teammates",
        damage_melee = "vgui/achievements/tf_demoman_kill_x_with_directpipe",
        swing_melee = "vgui/mvm/upgradeicons/upgrade_attackspeed",
        lifesteal_melee = "vgui/achievements/tf_medic_kill_healed_spy",
        effectbar_melee = "vgui/achievements/tf_win_well_minimumtime",
        building_health = "vgui/achievements/tf_engineer_repair_sentry_w_medic",
        building_rate = "vgui/achievements/tf_engineer_sentry_kill_lifetime_grind",
        canteen_capacity = "vgui/achievements/tf_medic_charge_blocker",
    }

    local SLOT_FALLBACK_ICON = {
        player = "hud/class_scoutred",
        primary = "vgui/mvm/upgradeicons/upgrade_attackspeed",
        secondary = "vgui/mvm/upgradeicons/upgrade_attackspeed",
        melee = "vgui/mvm/upgradeicons/upgrade_attackspeed",
        building = "vgui/mvm/upgradeicons/upgrade_teleporter",
        pda = "vgui/mvm/upgradeicons/upgrade_teleporter",
        action = "backpack/player/items/all_class/powerupbottle",
    }

    local lastCloseTime = 0
    local tf2UpgradeResCache = nil
    local tf2SchemeColorCache = nil
    local IsStillSpectatingObserved

    local function LocalizeToken(token, ...)
        if not isstring(token) or token == "" then return "" end
        local key = token
        if string.sub(key, 1, 1) == "#" then
            key = string.sub(key, 2)
        end

        if tf_lang and tf_lang.GetRaw then
            if select("#", ...) > 0 and tf_lang.GetFormatted then
                return tf_lang.GetFormatted(key, ...)
            end
            return tf_lang.GetRaw(key, true)
        end

        if select("#", ...) > 0 then
            local args = { ... }
            return string.gsub(key, "%%s(%d+)", function(n) return tostring(args[tonumber(n)] or "") end)
        end
        return key
    end

    local function MaybeLocalize(value)
        if not isstring(value) then return value end
        if string.sub(value, 1, 1) == "#" then
            return LocalizeToken(value)
        end
        return value
    end

    local function ParseSchemeColors(path)
        local out = {}
        local text = file.Read(path, "GAME")
        if not isstring(text) or text == "" then return out end

        local inColors = false
        local sawColorsKey = false
        local braceDepth = 0

        for rawLine in string.gmatch(text, "[^\r\n]+") do
            local line = string.Trim((rawLine:gsub("//.*$", "")))
            if line == "" then
                continue
            end

            if not inColors then
                if line:match('^"Colors"%s*$') then
                    sawColorsKey = true
                    continue
                end
                if sawColorsKey and line == "{" then
                    inColors = true
                    braceDepth = 1
                end
                continue
            end

            if line == "{" then
                braceDepth = braceDepth + 1
                continue
            end
            if line == "}" then
                braceDepth = braceDepth - 1
                if braceDepth <= 0 then
                    break
                end
                continue
            end

            local k, v = line:match('^"([^"]+)"%s+"([^"]+)"')
            if not k or not v then
                continue
            end

            local r, g, b, a = v:match("^(%d+)%s+(%d+)%s+(%d+)%s*(%d*)$")
            if r and g and b then
                local alpha = tonumber(a)
                out[string.lower(k)] = Color(tonumber(r), tonumber(g), tonumber(b), alpha and alpha > 0 and alpha or 255)
            end
        end

        return out
    end

    local function GetSchemeColor(name, fallback)
        if not tf2SchemeColorCache then
            tf2SchemeColorCache = ParseSchemeColors("resource/clientscheme.res")
            if not next(tf2SchemeColorCache) then
                tf2SchemeColorCache = ParseSchemeColors("tf/resource/clientscheme.res")
            end
        end

        local key = string.lower(tostring(name or ""))
        return (tf2SchemeColorCache and tf2SchemeColorCache[key]) or fallback
    end

    local function GetTF2UpgradeRes()
        if tf2UpgradeResCache then return tf2UpgradeResCache end

        local hudTree = nil
        local buyTree = nil
        if TF2Res and TF2Res.Load then
            for _, p in ipairs({
                "resource/ui/hudupgradepanel.res",
                "resource/ui/HudUpgradePanel.res",
                "tf/resource/ui/hudupgradepanel.res",
                "tf/resource/ui/HudUpgradePanel.res",
            }) do
                hudTree = TF2Res.Load(p)
                if hudTree then break end
            end
            for _, p in ipairs({
                "resource/ui/upgradebuypanel.res",
                "resource/ui/UpgradeBuyPanel.res",
                "tf/resource/ui/upgradebuypanel.res",
                "tf/resource/ui/UpgradeBuyPanel.res",
            }) do
                buyTree = TF2Res.Load(p)
                if buyTree then break end
            end
        end

        local function FindByFieldNames(tree, ...)
            if not TF2Res or not TF2Res.FindByFieldName then return nil end
            for i = 1, select("#", ...) do
                local name = select(i, ...)
                local found = TF2Res.FindByFieldName(tree, name)
                if found then return found end
            end
            return nil
        end

        local bgGrayout = hudTree and TF2Res.FindByFieldName(hudTree, "BGGrayoutPanel") or nil
        local selectPanel = hudTree and TF2Res.FindByFieldName(hudTree, "SelectWeaponPanel") or nil
        local hudPanelRoot = hudTree and TF2Res.FindByKey(hudTree, "HudUpgradePanel") or nil
        local modelPanelsKV = hudPanelRoot and TF2Res.FindByKey(hudPanelRoot, "modelpanels_kv") or nil
        local outterPanelBG = hudTree and (TF2Res.FindByFieldName(hudTree, "OutterPanelBG") or TF2Res.FindByFieldName(hudTree, "OuterPanelBG")) or nil
        local innerRim = hudTree and TF2Res.FindByFieldName(hudTree, "InnerPanelRim") or nil
        local innerBG = hudTree and TF2Res.FindByFieldName(hudTree, "InnerBGPanel") or nil
        local playerUpgradeButton = hudTree and TF2Res.FindByFieldName(hudTree, "PlayerUpgradeButton") or nil
        local activeTabPanel = hudTree and TF2Res.FindByFieldName(hudTree, "ActiveTabPanel") or nil
        local inactiveTabPanel = hudTree and TF2Res.FindByFieldName(hudTree, "InactiveTabPanel1") or nil
        local hoverTabPanel = hudTree and TF2Res.FindByFieldName(hudTree, "MouseOverTabPanel") or nil
        local hoverUpgradePanel = hudTree and TF2Res.FindByFieldName(hudTree, "MouseOverUpgradePanel") or nil
        local classImagePanel = hudTree and TF2Res.FindByFieldName(hudTree, "ClassImage") or nil
        local creditsLabel = hudTree and TF2Res.FindByFieldName(hudTree, "CreditsLabel") or nil
        local creditsTextLabel = hudTree and TF2Res.FindByFieldName(hudTree, "CreditsTextLabel") or nil
        local upgradeItemsBG = hudTree and TF2Res.FindByFieldName(hudTree, "UpgradeItemsBG") or nil
        local itemsDescBG = hudTree and TF2Res.FindByFieldName(hudTree, "UpgradeItemsDescriptionBG") or nil
        local itemsDescLabel = hudTree and TF2Res.FindByFieldName(hudTree, "UpgradeItemsDescriptionLabel") or nil
        local upgradeItemsHeaderBG = hudTree and TF2Res.FindByFieldName(hudTree, "UpgradeItemsHeaderBG") or nil
        local upgradeItemsLabel = hudTree and TF2Res.FindByFieldName(hudTree, "UpgradeItemsLabel") or nil
        local itemStatsLabel = hudTree and TF2Res.FindByFieldName(hudTree, "UpgradeItemStatsLabel") or nil
        local itemNameBG = hudTree and TF2Res.FindByFieldName(hudTree, "ItemNameBG") or nil
        local respecButton = hudTree and TF2Res.FindByFieldName(hudTree, "RespecButton") or nil
        local cancelButton = hudTree and TF2Res.FindByFieldName(hudTree, "CancelButton") or nil
        local closeButton = hudTree and TF2Res.FindByFieldName(hudTree, "CloseButton") or nil
        local inactiveSeparatorPanel = FindByFieldNames(hudTree, "InactiveSeparatorPanel")

        local upgradeCard = buyTree and TF2Res.FindByFieldName(buyTree, "UpgradeBuyPanel") or nil
        local iconBorder = buyTree and TF2Res.FindByFieldName(buyTree, "IconBorder") or nil
        local iconPanel = buyTree and TF2Res.FindByFieldName(buyTree, "Icon") or nil
        local buySellBG = buyTree and TF2Res.FindByFieldName(buyTree, "BuySellBG") or nil
        local priceLabel = buyTree and TF2Res.FindByFieldName(buyTree, "PriceLabel") or nil
        local shortDesc = buyTree and TF2Res.FindByFieldName(buyTree, "ShortDescriptionLabel") or nil
        local incrementBtn = buyTree and TF2Res.FindByFieldName(buyTree, "IncrementButton") or nil
        local decrementBtn = buyTree and TF2Res.FindByFieldName(buyTree, "DecrementButton") or nil
        local skillTreeKV = buyTree and TF2Res.FindByKey(buyTree, "skilltreebuttons_kv") or nil

        -- Fallback when TF2Res helper isn't available yet; panel code uses defaults via `or`.
        if not TF2Res or not TF2Res.GetNumber then
            tf2UpgradeResCache = {}
            return tf2UpgradeResCache
        end

        tf2UpgradeResCache = {
            selectW = TF2Res.GetNumber(selectPanel, "wide", 500),
            selectH = TF2Res.GetNumber(selectPanel, "tall", 350),
            panelY = TF2Res.GetNumber(selectPanel, "ypos", 85),
            backdropColor = TF2Res.GetColor(bgGrayout, "bgcolor_override", Color(0, 0, 0, 210)),
            innerX = TF2Res.GetNumber(innerRim, "xpos", 10),
            innerY = TF2Res.GetNumber(innerRim, "ypos", 50),
            innerW = TF2Res.GetNumber(innerRim, "wide", 480),
            innerH = TF2Res.GetNumber(innerRim, "tall", 230),
            innerBGX = TF2Res.GetNumber(innerBG, "xpos", 15),
            innerBGY = TF2Res.GetNumber(innerBG, "ypos", 55),
            innerBGW = TF2Res.GetNumber(innerBG, "wide", 470),
            innerBGH = TF2Res.GetNumber(innerBG, "tall", 220),
            tabW = TF2Res.GetNumber(playerUpgradeButton, "wide", 70),
            tabH = TF2Res.GetNumber(playerUpgradeButton, "tall", 50),
            tabTextInsetX = TF2Res.GetNumber(playerUpgradeButton, "textinsetx", 50),
            tabFont = TF2Res.GetString(playerUpgradeButton, "font", "HudFontSmallBold"),
            tabSoundDown = TF2Res.GetString(playerUpgradeButton, "sound_depressed", "ui/buttonclick.wav"),
            tabSoundUp = TF2Res.GetString(playerUpgradeButton, "sound_released", "ui/buttonclickrelease.wav"),
            tabTextColor = GetSchemeColor("TanLight", Color(231, 218, 186)),
            tabIconX = TF2Res.GetNumber(modelPanelsKV, "model_center_x", 4),
            tabIconY = TF2Res.GetNumber(modelPanelsKV, "model_ypos", 3),
            tabIconW = TF2Res.GetNumber(modelPanelsKV, "model_wide", 30),
            tabIconH = TF2Res.GetNumber(modelPanelsKV, "model_tall", 30),
            tabLabelY = TF2Res.GetNumber(modelPanelsKV, "text_ypos", 6),
            tabStartX = TF2Res.GetNumber(activeTabPanel, "xpos", 88),
            tabStartY = TF2Res.GetNumber(playerUpgradeButton, "ypos", 10),
            tabGap = TF2Res.GetNumber(hudPanelRoot, "itempanel_xdelta", 5),
            tabRowBottomY = TF2Res.GetNumber(inactiveSeparatorPanel, "ypos", 48),
            tabSeparatorH = TF2Res.GetNumber(inactiveSeparatorPanel, "tall", 5),
            infoW = TF2Res.GetNumber(itemNameBG, "wide", 130),
            infoX = TF2Res.GetNumber(upgradeItemsBG, "xpos", 25),
            infoY = TF2Res.GetNumber(upgradeItemsBG, "ypos", 135),
            infoH = TF2Res.GetNumber(upgradeItemsBG, "tall", 130),
            infoHeaderH = TF2Res.GetNumber(upgradeItemsHeaderBG, "tall", 20),
            infoDescX = TF2Res.GetNumber(itemStatsLabel, "xpos", 30),
            infoDescY = TF2Res.GetNumber(itemStatsLabel, "ypos", 160),
            infoDescW = TF2Res.GetNumber(itemStatsLabel, "wide", 120),
            infoDescH = TF2Res.GetNumber(itemStatsLabel, "tall", 105),
            rowW = TF2Res.GetNumber(upgradeCard, "wide", 155),
            rowH = TF2Res.GetNumber(upgradeCard, "tall", 45),
            rowIconW = TF2Res.GetNumber(iconBorder, "wide", 30),
            rowIconH = TF2Res.GetNumber(iconBorder, "tall", 30),
            rowIconBorderX = TF2Res.GetNumber(iconBorder, "xpos", 2),
            rowIconBorderY = TF2Res.GetNumber(iconBorder, "ypos", 2),
            rowIconX = TF2Res.GetNumber(iconPanel, "xpos", 4),
            rowIconY = TF2Res.GetNumber(iconPanel, "ypos", 4),
            rowIconInnerW = TF2Res.GetNumber(iconPanel, "wide", 26),
            rowIconInnerH = TF2Res.GetNumber(iconPanel, "tall", 26),
            rowRightW = TF2Res.GetNumber(buySellBG, "wide", 20),
            priceX = TF2Res.GetNumber(priceLabel, "xpos", 2),
            priceW = TF2Res.GetNumber(priceLabel, "wide", 30),
            priceH = TF2Res.GetNumber(priceLabel, "tall", 13),
            priceY = TF2Res.GetNumber(priceLabel, "ypos", 32),
            textX = TF2Res.GetNumber(shortDesc, "xpos", 37),
            textY = TF2Res.GetNumber(shortDesc, "ypos", 4),
            textW = TF2Res.GetNumber(shortDesc, "wide", 97),
            textH = TF2Res.GetNumber(shortDesc, "tall", 22),
            plusX = TF2Res.GetNumber(incrementBtn, "xpos", 137),
            plusY = TF2Res.GetNumber(incrementBtn, "ypos", 4),
            plusW = TF2Res.GetNumber(incrementBtn, "wide", 16),
            plusH = TF2Res.GetNumber(incrementBtn, "tall", 16),
            minusX = TF2Res.GetNumber(decrementBtn, "xpos", 137),
            minusY = TF2Res.GetNumber(decrementBtn, "ypos", 24),
            minusW = TF2Res.GetNumber(decrementBtn, "wide", 16),
            minusH = TF2Res.GetNumber(decrementBtn, "tall", 16),
            -- TF2 CImageButton behavior: activeimage = enabled art, inactiveimage = disabled art.
            buyEnabledImage = TF2Res.GetString(incrementBtn, "activeimage", "vgui/pve/buy_enabled"),
            buyDisabledImage = TF2Res.GetString(incrementBtn, "inactiveimage", "vgui/pve/buy_disabled"),
            -- Optional press/hover override art (TF2 commonly uses buy_selected).
            buySelectedImage = TF2Res.GetString(incrementBtn, "selectedimage", "vgui/pve/buy_selected"),
            sellEnabledImage = TF2Res.GetString(decrementBtn, "activeimage", "vgui/pve/sell_enabled"),
            sellDisabledImage = TF2Res.GetString(decrementBtn, "inactiveimage", "vgui/pve/sell_disabled"),
            sellSelectedImage = TF2Res.GetString(decrementBtn, "selectedimage", "vgui/pve/sell_selected"),
            plusSoundDown = TF2Res.GetString(incrementBtn, "sound_depressed", "ui/buttonclick.wav"),
            plusSoundUp = TF2Res.GetString(incrementBtn, "sound_released", "ui/buttonclickrelease.wav"),
            minusSoundDown = TF2Res.GetString(decrementBtn, "sound_depressed", "ui/buttonclick.wav"),
            minusSoundUp = TF2Res.GetString(decrementBtn, "sound_released", "ui/buttonclickrelease.wav"),
            respecW = TF2Res.GetNumber(respecButton, "wide", 120),
            respecH = TF2Res.GetNumber(respecButton, "tall", 17),
            respecX = TF2Res.GetNumber(respecButton, "xpos", 50),
            respecY = TF2Res.GetNumber(respecButton, "ypos", 285),
            cancelW = TF2Res.GetNumber(cancelButton, "wide", 75),
            cancelH = TF2Res.GetNumber(cancelButton, "tall", 17),
            cancelX = TF2Res.GetNumber(cancelButton, "xpos", 335),
            cancelY = TF2Res.GetNumber(cancelButton, "ypos", 285),
            closeW = TF2Res.GetNumber(closeButton, "wide", 75),
            closeH = TF2Res.GetNumber(closeButton, "tall", 17),
            closeX = TF2Res.GetNumber(closeButton, "xpos", 415),
            closeY = TF2Res.GetNumber(closeButton, "ypos", 285),
            upgradeButtonY = TF2Res.GetNumber(upgradeCard, "upgradebutton_ypos", 26),
            upgradeDelta = TF2Res.GetNumber(hudPanelRoot, "upgradebuypanel_delta", 6),
            upgradeListX = TF2Res.GetNumber(hudPanelRoot, "upgradebuypanel_xpos", 160),
            upgradeListY = TF2Res.GetNumber(hudPanelRoot, "upgradebuypanel_ypos", 65),
            pipW = TF2Res.GetNumber(skillTreeKV, "wide", 16),
            pipH = TF2Res.GetNumber(skillTreeKV, "tall", 16),
            classX = TF2Res.GetNumber(classImagePanel, "xpos", 30),
            classY = TF2Res.GetNumber(classImagePanel, "ypos", 15),
            classW = TF2Res.GetNumber(classImagePanel, "wide", 40),
            classH = TF2Res.GetNumber(classImagePanel, "tall", 40),
            colCardBG = TF2Res.GetColor(selectPanel, "bgcolor_override", Color(63, 59, 55, 250)),
            colActiveTab = TF2Res.GetColor(activeTabPanel, "bgcolor_override", Color(142, 132, 121, 255)),
            colInactiveTab = TF2Res.GetColor(inactiveTabPanel, "bgcolor_override", Color(77, 72, 68, 255)),
            colHoverTab = TF2Res.GetColor(hoverTabPanel, "bgcolor_override", Color(239, 128, 73, 255)),
            colHoverUpgrade = TF2Res.GetColor(hoverUpgradePanel, "bgcolor_override", Color(239, 128, 73, 255)),
            colInactiveSeparator = TF2Res.GetColor(inactiveSeparatorPanel, "bgcolor_override", Color(0, 0, 0, 128)),
            colListBG = TF2Res.GetColor(upgradeItemsBG, "bgcolor_override", Color(97, 94, 85, 255)),
            colDescBG = TF2Res.GetColor(itemsDescBG, "bgcolor_override", Color(52, 48, 45, 255)),
            colListHeader = TF2Res.GetColor(upgradeItemsHeaderBG, "bgcolor_override", Color(72, 68, 63, 255)),
            colRowBG = TF2Res.GetColor(TF2Res.FindByFieldName(buyTree, "InnerPanelRim"), "bgcolor_override", Color(97, 94, 85, 255)),
            colRowIcon = TF2Res.GetColor(iconBorder, "bgcolor_override", Color(235, 226, 202, 255)),
            colRowRight = TF2Res.GetColor(buySellBG, "bgcolor_override", Color(117, 114, 103, 255)),
            creditsFont = TF2Res.GetString(creditsLabel, "font", "HudFontMedium"),
            creditsTextFont = TF2Res.GetString(creditsTextLabel, "font", "HudFontSmallBold"),
            creditsX = TF2Res.GetNumber(creditsLabel, "xpos", 0),
            creditsY = TF2Res.GetNumber(creditsLabel, "ypos", 280),
            creditsW = TF2Res.GetNumber(creditsLabel, "wide", 245),
            creditsH = TF2Res.GetNumber(creditsLabel, "tall", 30),
            creditsColor = TF2Res.GetColor(creditsLabel, "fgcolor", GetSchemeColor("CreditsGreen", Color(121, 195, 58))),
            creditsTextX = TF2Res.GetNumber(creditsTextLabel, "xpos", 250),
            creditsTextY = TF2Res.GetNumber(creditsTextLabel, "ypos", 280),
            creditsTextW = TF2Res.GetNumber(creditsTextLabel, "wide", 500),
            creditsTextH = TF2Res.GetNumber(creditsTextLabel, "tall", 30),
            creditsTextColor = TF2Res.GetColor(creditsTextLabel, "fgcolor", GetSchemeColor("TanLight", Color(231, 218, 186))),
            buttonFont = TF2Res.GetString(cancelButton, "font", "HudFontSmallestBold"),
            cancelSoundDown = TF2Res.GetString(cancelButton, "sound_depressed", "ui/buttonclick.wav"),
            cancelSoundUp = TF2Res.GetString(cancelButton, "sound_released", "ui/buttonclickrelease.wav"),
            closeSoundDown = TF2Res.GetString(closeButton, "sound_depressed", "ui/buttonclick.wav"),
            closeSoundUp = TF2Res.GetString(closeButton, "sound_released", "ui/buttonclickrelease.wav"),
            respecSoundDown = TF2Res.GetString(respecButton, "sound_depressed", "ui/buttonclick.wav"),
            respecSoundUp = TF2Res.GetString(respecButton, "sound_released", "ui/buttonclickrelease.wav"),
            rowNameFont = TF2Res.GetString(shortDesc, "font", "HudFontSmallest"),
            rowPriceFont = TF2Res.GetString(priceLabel, "font", "HudFontSmallestBold"),
            creditsTextToken = TF2Res.GetString(creditsTextLabel, "labelText", "#TF_PVE_UpgradeAmount"),
            cancelTextToken = TF2Res.GetString(cancelButton, "labelText", "#TF_PVE_UpgradeCancel"),
            closeTextToken = TF2Res.GetString(closeButton, "labelText", "#TF_PVE_UpgradeDone"),
            respecTextToken = TF2Res.GetString(respecButton, "labelText", "#TF_PVE_UpgradeRespec"),
            itemHeaderFont = TF2Res.GetString(upgradeItemsLabel, "font", "HudFontSmallBold"),
            itemStatsFont = TF2Res.GetString(itemStatsLabel, "font", "HudFontSmallest"),
            colInnerRim = TF2Res.GetColor(innerRim, "bgcolor_override", Color(142, 132, 121, 255)),
            colInnerBG = TF2Res.GetColor(innerBG, "bgcolor_override", Color(77, 72, 68, 255)),
            cardBorderImage = TF2Res.GetString(outterPanelBG, "image", "../HUD/tournament_panel_brown"),
            cardCornerSrcW = TF2Res.GetNumber(outterPanelBG, "src_corner_width", 23),
            cardCornerSrcH = TF2Res.GetNumber(outterPanelBG, "src_corner_height", 23),
            cardCornerDrawW = TF2Res.GetNumber(outterPanelBG, "draw_corner_width", 8),
            cardCornerDrawH = TF2Res.GetNumber(outterPanelBG, "draw_corner_height", 8),
        }

        return tf2UpgradeResCache
    end

    local function IsValidIconPath(path)
        if not isstring(path) or path == "" then return false end
        local mat = Material(path)
        return mat and not mat:IsError()
    end

    local CLASS_ICON_ALIAS = {
        demoman = "demo",
        engineer = "engi",
        mercenary = "scout",
        civilian = "scout",
        gmodplayer = "scout",
    }

    local function NormalizeIconPath(path)
        if not isstring(path) or path == "" then return nil end
        local out = string.Trim(path)
        out = string.Replace(out, "\\", "/")
        out = string.gsub(out, "^materials/", "")
        out = string.gsub(out, "^%./", "")
        out = string.gsub(out, "^%.%./", "")
        out = string.gsub(out, "%.vmt$", "")
        out = string.gsub(out, "%.vtf$", "")

        if string.StartWith(out, "achievements/") or string.StartWith(out, "mvm/") or string.StartWith(out, "pve/") then
            out = "vgui/" .. out
        end

        return out
    end

    local function SetAspectIcon(panel, path)
        if not IsValid(panel) then return end
        local normalized = NormalizeIconPath(path)
        if not isstring(normalized) or normalized == "" then
            normalized = isstring(path) and path or nil
        end
        panel.IconPath = normalized
        panel.IconMat = nil
        panel.Paint = function(self, w, h)
            local p = self.IconPath
            if not isstring(p) or p == "" then return end
            if not self.IconMat then
                self.IconMat = Material(p)
            end
            local mat = self.IconMat
            if not mat or (mat.IsError and mat:IsError()) then return end

            local mw = tonumber(mat:Width()) or w
            local mh = tonumber(mat:Height()) or h
            if mw <= 0 or mh <= 0 then
                surface.SetMaterial(mat)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(0, 0, w, h)
                return
            end

            local scale = math.min(w / mw, h / mh)
            local dw = math.floor(mw * scale + 0.5)
            local dh = math.floor(mh * scale + 0.5)
            local dx = math.floor((w - dw) * 0.5)
            local dy = math.floor((h - dh) * 0.5)

            surface.SetMaterial(mat)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRect(dx, dy, dw, dh)
        end
    end

    local function ResolveClassPortraitIcon(ply, className)
        local rawClass = string.lower(tostring(className or "scout"))
        local classKey = CLASS_ICON_ALIAS[rawClass] or rawClass
        local teamSuffix = "red"
        if IsValid(ply) and tonumber(ply:Team() or 0) == 3 then
            teamSuffix = "blue"
        end

        local candidates = {
            "hud/class_" .. classKey .. teamSuffix,
            "hud/class_" .. classKey .. "red",
            "hud/class_" .. classKey .. "blue",
            SLOT_FALLBACK_ICON.player,
        }

        for _, icon in ipairs(candidates) do
            if IsValidIconPath(icon) then
                return icon
            end
        end

        return SLOT_FALLBACK_ICON.player
    end

    local function GetClientWeaponSlotName(wep)
        if not IsValid(wep) then return "" end
        local cls = string.lower(tostring((wep.GetClass and wep:GetClass()) or ""))

        -- Mirror server-side fallback so drink/jar/banners resolve consistently.
        if string.find(cls, "jar_milk", 1, true)
            or string.find(cls, "jar_gas", 1, true)
            or string.find(cls, "tf_weapon_jar", 1, true)
            or string.find(cls, "lunchbox_drink", 1, true) then
            return "secondary"
        end

        if string.find(cls, "powerup", 1, true)
            or string.find(cls, "canteen", 1, true)
            or string.find(cls, "battery", 1, true)
            or string.find(cls, "kritz_or_treat", 1, true) then
            return "action"
        end

        if wep.GetItemData then
            local itemData = wep:GetItemData()
            if itemData and isstring(itemData.item_slot) then
                local slot = string.lower(itemData.item_slot)
                if slot ~= "" then
                    return slot
                end
            end
        end
        local slot = tonumber(wep.Slot or (wep.GetSlot and wep:GetSlot()) or -1) or -1
        if slot == 0 then return "primary" end
        if slot == 1 then return "secondary" end
        if slot == 2 then return "melee" end
        if slot == 3 or slot == 4 or slot == 5 then return "action" end
        return ""
    end

    local function GetSlotItemVisual(slotName, subjectPly)
        local ply = IsValid(subjectPly) and subjectPly or LocalPlayer()
        if not IsValid(ply) then return nil, nil end
        if slotName == "player" then
            local className = string.lower(tostring(ply:GetPlayerClass() or "scout"))
            return string.upper(className), ResolveClassPortraitIcon(ply, className)
        end
        if slotName == "action" then
            local icon = nil
            if ply == LocalPlayer() then
                local className = string.lower(tostring(ply:GetPlayerClass() or ""))
                local cvar = GetConVar("loadout_" .. className)
                if cvar and _G.tf_items and istable(tf_items.Items) then
                    local split = string.Split(cvar:GetString() or "", ",")
                    local actionDef = tonumber(split[7] or "-1") or -1
                    if actionDef > 0 then
                        for _, item in pairs(tf_items.Items) do
                            if istable(item) and tonumber(item.id or -1) == actionDef then
                                icon = NormalizeIconPath(item.image_inventory)
                                break
                            end
                        end
                    end
                end
            end
            if not IsValidIconPath(icon) then
                icon = SLOT_FALLBACK_ICON.action
            end
            return LocalizeToken("TF_Usable_PowerupBottle"), icon
        end

        for _, wep in ipairs(ply:GetWeapons()) do
            if not IsValid(wep) then continue end
            local slot = GetClientWeaponSlotName(wep)
            if slot ~= slotName then continue end

            local itemData = wep.GetItemData and wep:GetItemData() or nil
            local displayName = (itemData and itemData.name) or wep:GetPrintName() or wep:GetClass()
            local icon = itemData and NormalizeIconPath(itemData.image_inventory) or nil
            if not IsValidIconPath(icon) then
                icon = SLOT_FALLBACK_ICON[slotName]
            end
            return displayName, icon
        end

        return nil, SLOT_FALLBACK_ICON[slotName]
    end

    local function BuildTabsForPlayer(payload, subjectPly)
        local ply = IsValid(subjectPly) and subjectPly or LocalPlayer()
        local className = string.lower(tostring(IsValid(ply) and ply:GetPlayerClass() or ""))

        local function UpgradeMatchesTab(up, tabKey)
            local target = string.lower(tostring(up and up.target or ""))
            local category = string.lower(tostring(up and up.category or ""))
            if tabKey == "player" then
                return target == "player" or category == "player"
            end
            if tabKey == "primary" or tabKey == "secondary" or tabKey == "melee" then
                return target == tabKey or category == tabKey
            end
            if tabKey == "special" then
                return category == "engineer"
            end
            if tabKey == "action" then
                return category == "canteen" or target == "action"
            end
            return false
        end

        local function HasVisibleUpgradesForTab(tabKey)
            for _, up in ipairs((payload and payload.upgrades) or {}) do
                if up.available ~= false and UpgradeMatchesTab(up, tabKey) then
                    return true
                end
            end
            return false
        end

        local function HasEquippedItemInSlot(slotName)
            if not IsValid(ply) then return false end
            if slotName == "player" then return true end
            for _, wep in ipairs(ply:GetWeapons()) do
                if not IsValid(wep) then continue end
                if GetClientWeaponSlotName(wep) == slotName then
                    return true
                end
            end
            return false
        end

        local tabDefs = {
            { key = "player", label = "PLAYER", slot = "player", fallbackIcon = SLOT_FALLBACK_ICON.player, always = true },
            { key = "primary", label = "PRIMARY", slot = "primary", fallbackIcon = SLOT_FALLBACK_ICON.primary },
            { key = "secondary", label = "SECONDARY", slot = "secondary", fallbackIcon = SLOT_FALLBACK_ICON.secondary },
            { key = "melee", label = "MELEE", slot = "melee", fallbackIcon = SLOT_FALLBACK_ICON.melee },
        }

        if className == "engineer" or className == "spy" then
            local slot = className == "engineer" and "pda" or "building"
            tabDefs[#tabDefs + 1] = { key = "special", label = className == "engineer" and "PDA" or "SAPPER", slot = slot, fallbackIcon = SLOT_FALLBACK_ICON[slot] }
        end

        tabDefs[#tabDefs + 1] = { key = "action", label = "CANTEEN", slot = "action", fallbackIcon = SLOT_FALLBACK_ICON.action }

        local tabs = {}
        for _, def in ipairs(tabDefs) do
            if def.always or HasVisibleUpgradesForTab(def.key) or HasEquippedItemInSlot(def.slot) then
                tabs[#tabs + 1] = def
            end
        end

        if #tabs == 0 then
            tabs[1] = { key = "player", label = "PLAYER", slot = "player", fallbackIcon = SLOT_FALLBACK_ICON.player }
        end

        return tabs
    end

    local function UpgradeBelongsToTab(up, tabKey)
        local target = string.lower(tostring(up.target or ""))
        local category = string.lower(tostring(up.category or ""))

        if tabKey == "player" then
            return target == "player" or category == "player"
        end
        if tabKey == "primary" or tabKey == "secondary" or tabKey == "melee" then
            return target == tabKey or category == tabKey
        end
        if tabKey == "special" then
            return category == "engineer"
        end
        if tabKey == "action" then
            return category == "canteen" or target == "action"
        end
        return false
    end

    local function BuildPanel(payload)
        if not istable(payload) then return end

        if IsValid(TF_MVMUpgradeFrame) and TF_MVMUpgradeFrame.ApplyPayload then
            TF_MVMUpgradeFrame:ApplyPayload(payload)
            return
        end

        local res = GetTF2UpgradeRes()
        local uiScale = math.Clamp(
            math.min(
                ScrW() / ((res.selectW or 500) + 90),
                ScrH() / ((res.selectH or 350) + 120)
            ),
            1.0,
            2.4
        )

        local cardW = math.floor((res.selectW or 500) * uiScale)
        local cardH = math.floor((res.selectH or 350) * uiScale)
        local pad = math.floor((res.innerX or 10) * uiScale)
        local infoW = math.floor((res.infoW or 130) * uiScale)
        local topBarH = math.floor((res.innerY or 50) * uiScale)
        local bottomY = math.floor(((res.innerY or 50) + (res.innerH or 230) + 5) * uiScale)
        local bottomBarH = math.floor((math.max(res.cancelH or 17, res.respecH or 17) + 12) * uiScale)
        local listTop = math.floor((res.innerBGY or 55) * uiScale)
        local matBuySelected = Material(NormalizeIconPath(res.buySelectedImage) or "vgui/pve/buy_selected")
        local matBuyEnabled = Material(NormalizeIconPath(res.buyEnabledImage) or "vgui/pve/buy_enabled")
        local matBuyDisabled = Material(NormalizeIconPath(res.buyDisabledImage) or "vgui/pve/buy_disabled")
        local matSellSelected = Material(NormalizeIconPath(res.sellSelectedImage) or "vgui/pve/sell_selected")
        local matSellEnabled = Material(NormalizeIconPath(res.sellEnabledImage) or "vgui/pve/sell_enabled")
        local matSellDisabled = Material(NormalizeIconPath(res.sellDisabledImage) or "vgui/pve/sell_disabled")
        local function SafeMat(mat, fallback)
            if mat and (not mat.IsError or not mat:IsError()) then return mat end
            return fallback
        end
        matBuyEnabled = SafeMat(matBuyEnabled, Material("vgui/pve/buy_enabled"))
        matBuyDisabled = SafeMat(matBuyDisabled, Material("vgui/pve/buy_disabled"))
        matBuySelected = SafeMat(matBuySelected, matBuyEnabled)
        matSellEnabled = SafeMat(matSellEnabled, Material("vgui/pve/sell_enabled"))
        matSellDisabled = SafeMat(matSellDisabled, Material("vgui/pve/sell_disabled"))
        matSellSelected = SafeMat(matSellSelected, matSellEnabled)
        local matPipFilled = Material("vgui/pve/chalf_circle")
        local matPipEmpty = Material("vgui/pve/chalf_circle_empty")

        local colTanLight = GetSchemeColor("TanLight", Color(231, 218, 186))
        local colCreditsGreen = GetSchemeColor("CreditsGreen", Color(121, 195, 58))
        local colUpgradeDisabled = GetSchemeColor("UpgradeDisabledFg", Color(64, 59, 52, 255))
        local colListHeaderText = GetSchemeColor("TanLight", Color(231, 218, 186))
        local colAttribPositive = GetSchemeColor("ItemAttribPositive", Color(153, 204, 255, 255))
        local colButtonBG = GetSchemeColor("TanDark", Color(117, 107, 94, 255))
        local colButtonHover = GetSchemeColor("TFOrange", Color(145, 73, 59, 255))
        local colButtonPressed = GetSchemeColor("Orange", Color(178, 82, 22, 255))
        local colButtonText = GetSchemeColor("TanLight", Color(235, 226, 202, 255))
        local colButtonPressedText = GetSchemeColor("Black", Color(46, 43, 42, 255))

        local txtCredits = LocalizeToken(res.creditsTextToken or "#TF_PVE_UpgradeAmount")
        local txtSelectUpgrade = LocalizeToken("TF_PVE_UpgradeAttrib")
        local txtCostFormat = "Cost: %s1"
        if tf_lang and tf_lang.GetRaw then
            txtCostFormat = tf_lang.GetRaw("TF_PVE_UpgradeCost", true)
        end
        local txtMaxReached = LocalizeToken("TF_PVE_UpgradeMaxed")
        local txtNotEnough = LocalizeToken("TF_Not_Enough_Resources")
        local txtCancel = LocalizeToken(res.cancelTextToken or "#TF_PVE_UpgradeCancel")
        local txtAccept = LocalizeToken(res.closeTextToken or "#TF_PVE_UpgradeDone")
        local txtRespec = LocalizeToken(res.respecTextToken or "#TF_PVE_UpgradeRespec")
        local txtItemToUpgrade = LocalizeToken("TF_PVE_UpgradeTitle")

        local function PlayUiRollover()
            surface.PlaySound("ui/buttonrollover.wav")
        end

        local function PlayUiClick(soundPath)
            if isstring(soundPath) and soundPath ~= "" then
                surface.PlaySound(soundPath)
            else
                surface.PlaySound("ui/buttonclickrelease.wav")
            end
        end

        local function FormatUpgradeCost(cost)
            local fmt = txtCostFormat
            local replaced = string.gsub(fmt, "%%s1", tostring(cost or 0))
            if replaced == fmt and tf_lang and tf_lang.GetFormatted then
                replaced = tf_lang.GetFormatted("TF_PVE_UpgradeCost", tostring(cost or 0))
            end
            return replaced
        end

        local function SkinActionButton(btn)
            btn:SetTextColor(colButtonText)
            btn:SetFont(res.buttonFont or "HudFontSmallestBold")
            btn.OnCursorEntered = function()
                PlayUiRollover()
            end
            btn.Paint = function(self, w, h)
                local bg = colButtonBG
                local fg = colButtonText
                if not self:IsEnabled() then
                    bg = Color(colUpgradeDisabled.r, colUpgradeDisabled.g, colUpgradeDisabled.b, 220)
                elseif self:IsDown() then
                    bg = colButtonPressed
                    fg = colButtonPressedText
                elseif self:IsHovered() then
                    bg = colButtonHover
                end
                surface.SetDrawColor(bg)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(0, 0, 0, 170)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(self:GetText(), res.buttonFont or "HudFontSmallestBold", w * 0.5, h * 0.5, fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        local frame = vgui.Create("DFrame")
        TF_MVMUpgradeFrame = frame
        frame.SpectatorView = payload.spectatorView == true
        frame.ObservedEntIndex = tonumber(payload.observedEntIndex or -1) or -1
        local subjectPly = frame.SpectatorView and Entity(frame.ObservedEntIndex) or LocalPlayer()
        frame:SetTitle("")
        frame:SetDraggable(false)
        frame:ShowCloseButton(false)
        frame:SetSize(ScrW(), ScrH())
        frame:MakePopup()
        frame:SetKeyboardInputEnabled(false)
        frame:SetMouseInputEnabled(true)
        gui.EnableScreenClicker(true)
        frame:Center()
        frame.Paint = function(self, w, h)
            local c = res.backdropColor or Color(0, 0, 0, 210)
            surface.SetDrawColor(c.r, c.g, c.b, c.a)
            surface.DrawRect(0, 0, w, h)
        end
        frame.OnKeyCodePressed = function(self, code)
            if code == KEY_ESCAPE then
                self:Close()
            end
        end
        frame.OnClose = function(self)
            lastCloseTime = CurTime()
            gui.EnableScreenClicker(false)
            if LocalPlayer and IsValid(LocalPlayer()) then
                SendAction("ui_closed", "")
            end
        end

        local card = vgui.Create("DPanel", frame)
        card:SetSize(cardW, cardH)
        card:SetPos((ScrW() - cardW) * 0.5, math.floor((res.panelY or 85) * uiScale))
        card.Paint = function(self, w, h)
            if tf_draw and tf_draw.BorderPanel then
                local borderImage = NormalizeIconPath(res.cardBorderImage) or "hud/tournament_panel_brown"
                tf_draw.BorderPanel(
                    surface.GetTextureID(borderImage),
                    0,
                    0,
                    w,
                    h,
                    res.cardCornerSrcW or 23,
                    res.cardCornerSrcH or 23,
                    (res.cardCornerDrawW or 8) * uiScale,
                    (res.cardCornerDrawH or 8) * uiScale
                )
            else
                surface.SetDrawColor(res.colCardBG or Color(63, 59, 55, 250))
                surface.DrawRect(0, 0, w, h)
            end

            surface.SetDrawColor(res.colInnerRim or Color(142, 132, 121, 255))
            surface.DrawRect(pad, topBarH, w - pad * 2, h - topBarH - bottomBarH - pad)
            surface.SetDrawColor(res.colInnerBG or Color(77, 72, 68, 255))
            surface.DrawRect(pad + 2, topBarH + 2, w - (pad * 2) - 4, h - topBarH - bottomBarH - pad - 4)

            draw.SimpleText("UPGRADE STATION", "HudFontSmallBold", pad + math.floor(8 * uiScale), math.floor(6 * uiScale), colTanLight, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("WAVE " .. tostring(payload.waveCurrent or 0) .. " / " .. tostring(payload.waveTotal or 0), "HudFontSmallestBold", w - pad - math.floor(8 * uiScale), math.floor(10 * uiScale), colTanLight, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end

        -- Class portrait is represented by the PLAYER tab icon; avoid drawing a second standalone portrait.

        local tabs = {}
        local selectedTab = "player"
        local tabButtons = {}
        local tabSep = nil
        local tabsSignature = ""

        local tabX = math.floor((res.tabStartX or 88) * uiScale)
        local tabW = math.floor((res.tabW or 70) * uiScale)
        local tabH = math.floor((res.tabH or 50) * uiScale)
        local tabGap = math.floor((res.tabGap or 5) * uiScale)
        local tabSepY = math.floor((res.tabRowBottomY or 48) * uiScale)
        local tabSepH = math.max(1, math.floor((res.tabSeparatorH or 5) * uiScale))

        local function BuildTabsSignature(list)
            local out = {}
            for _, t in ipairs(list or {}) do
                out[#out + 1] = tostring(t.key or "")
            end
            return table.concat(out, "|")
        end

        local function RebuildTabButtons(force)
            local nextTabs = BuildTabsForPlayer(payload, subjectPly)
            local nextSignature = BuildTabsSignature(nextTabs)
            if not force and nextSignature == tabsSignature and #tabButtons > 0 then
                return false
            end
            tabsSignature = nextSignature

            for _, entry in ipairs(tabButtons) do
                if IsValid(entry.button) then
                    entry.button:Remove()
                end
            end
            tabButtons = {}
            if IsValid(tabSep) then
                tabSep:Remove()
                tabSep = nil
            end

            tabs = nextTabs
            if #tabs <= 0 then
                tabs = {
                    { key = "player", label = "PLAYER", slot = "player", fallbackIcon = SLOT_FALLBACK_ICON.player },
                }
            end

            local previousTab = selectedTab
            selectedTab = nil
            for _, tab in ipairs(tabs) do
                if tab.key == previousTab then
                    selectedTab = previousTab
                    break
                end
            end
            if not selectedTab then
                selectedTab = tabs[1].key
            end

            for i, tab in ipairs(tabs) do
                local btn = vgui.Create("DButton", card)
                btn:SetText("")
                btn:SetSize(tabW, tabH)
                btn:SetPos(tabX + (i - 1) * (tabW + tabGap), math.floor((res.tabStartY or 10) * uiScale))
                btn.Paint = function(self, w, h)
                    local active = selectedTab == tab.key
                    if active then
                        surface.SetDrawColor(res.colActiveTab or Color(142, 132, 121, 255))
                    else
                        surface.SetDrawColor(res.colInactiveTab or Color(72, 68, 64, 255))
                    end
                    surface.DrawRect(0, 0, w, h)

                    if active then
                        surface.SetDrawColor(res.colHoverTab or Color(241, 158, 81, 255))
                        surface.DrawOutlinedRect(0, 0, w, h, 1)
                        surface.SetDrawColor(255, 230, 185, 80)
                        surface.DrawRect(1, 1, w - 2, 1)
                    else
                        surface.SetDrawColor(35, 33, 31, 255)
                        surface.DrawOutlinedRect(0, 0, w, h, 1)
                        surface.SetDrawColor(0, 0, 0, 90)
                        surface.DrawRect(0, h - 2, w, 2)
                    end

                    surface.SetDrawColor(26, 24, 22, 150)
                    surface.DrawRect(w - 1, 0, 1, h)
                end
                btn.DoClick = function()
                    PlayUiClick(res.tabSoundDown)
                    PlayUiClick(res.tabSoundUp)
                    selectedTab = tab.key
                    if card.QueueUpgradeRebuild then
                        card:QueueUpgradeRebuild()
                    end
                end
                btn.OnCursorEntered = function()
                    PlayUiRollover()
                end

                local icon = vgui.Create("DImage", btn)
                icon:SetPos(math.floor((res.tabIconX or 4) * uiScale), math.floor((res.tabIconY or 3) * uiScale))
                icon:SetSize(math.floor((res.tabIconW or 30) * uiScale), math.floor((res.tabIconH or 30) * uiScale))
                SetAspectIcon(icon, tab.fallbackIcon)

                local label = vgui.Create("DLabel", btn)
                local tabTextX = math.floor((res.tabTextInsetX or 50) * uiScale)
                label:SetPos(tabTextX, math.floor((res.tabLabelY or 6) * uiScale))
                label:SetSize(math.max(1, tabW - tabTextX - math.floor(4 * uiScale)), math.floor((res.tabH or 50) * uiScale))
                label:SetText(tab.label)
                label:SetFont(res.tabFont or "HudFontSmallest")
                label:SetWrap(false)
                label:SetTextColor(res.tabTextColor or colTanLight)
                label:SetContentAlignment(4)

                tabButtons[#tabButtons + 1] = { tab = tab, button = btn, icon = icon, label = label, iconPath = tab.fallbackIcon }
            end

            local tabRight = tabX + (#tabs * tabW) + math.max(0, (#tabs - 1) * tabGap)
            tabSep = vgui.Create("DPanel", card)
            tabSep:SetPos(tabX, tabSepY)
            tabSep:SetSize(math.max(1, tabRight - tabX), tabSepH)
            tabSep:SetMouseInputEnabled(false)
            tabSep.Paint = function(self, w, h)
                surface.SetDrawColor(res.colInactiveSeparator or Color(0, 0, 0, 128))
                surface.DrawRect(0, 0, w, h)
            end

            return true
        end

        RebuildTabButtons(true)

        local infoPanel = vgui.Create("DPanel", card)
        local infoX = math.floor((res.infoX or (res.innerX or 10)) * uiScale)
        local infoY = math.floor((res.infoY or (res.innerBGY or 55)) * uiScale)
        local infoH = math.floor((res.infoH or ((res.innerH or 230) - 100)) * uiScale)
        infoPanel:SetPos(infoX, infoY)
        infoPanel:SetSize(infoW, infoH)
        infoPanel.Paint = function(self,w,h)
            surface.SetDrawColor(res.colDescBG or res.colListBG or Color(97, 94, 85, 255))
            surface.DrawRect(0,0,w,h)
            surface.SetDrawColor(res.colListHeader or Color(72, 68, 63, 255))
            surface.DrawRect(0, 0, w, math.floor((res.infoHeaderH or 20) * uiScale))
        end

        infoPanel.name = vgui.Create("DLabel", infoPanel)
        infoPanel.name:SetPos(math.floor(4 * uiScale), math.floor(4 * uiScale))
        infoPanel.name:SetSize(infoW - math.floor(8 * uiScale), math.floor(20 * uiScale))
        infoPanel.name:SetFont(res.itemHeaderFont or "HudFontSmallBold")
        infoPanel.name:SetTextColor(colListHeaderText)

        infoPanel.desc = vgui.Create("DLabel", infoPanel)
        local descX = math.max(0, math.floor(((res.infoDescX or 30) - (res.infoX or 25)) * uiScale))
        local descY = math.max(math.floor(24 * uiScale), math.floor(((res.infoDescY or 160) - (res.infoY or 135)) * uiScale))
        infoPanel.desc:SetPos(descX, descY)
        infoPanel.desc:SetSize(math.floor((res.infoDescW or 120) * uiScale), math.floor((res.infoDescH or 105) * uiScale))
        infoPanel.desc:SetFont(res.itemStatsFont or "HudFontSmallest")
        infoPanel.desc:SetWrap(true)
        infoPanel.desc:SetAutoStretchVertical(true)
        infoPanel.desc:SetTextColor(colAttribPositive)

        infoPanel.slotLabel = vgui.Create("DLabel", infoPanel)
        infoPanel.slotLabel:SetPos(math.floor(4 * uiScale), infoPanel:GetTall() - math.floor(32 * uiScale))
        infoPanel.slotLabel:SetSize(infoW - math.floor(8 * uiScale), math.floor(14 * uiScale))
        infoPanel.slotLabel:SetFont(res.itemStatsFont or "HudFontSmallestBold")
        infoPanel.slotLabel:SetTextColor(Color(252, 221, 118))
        infoPanel.slotLabel:SetText("")

        local selectedUpgradeByTab = {}
        local hoveredUpgradeByTab = {}

        local function FindUpgradeInTabById(tabKey, upId)
            if not isstring(upId) or upId == "" then return nil end
            for _, candidate in ipairs(payload.upgrades or {}) do
                if candidate.id == upId and UpgradeBelongsToTab(candidate, tabKey) then
                    return candidate
                end
            end
            return nil
        end

        local function GetPriorityUpgradeForCurrentTab()
            local hovered = FindUpgradeInTabById(selectedTab, hoveredUpgradeByTab[selectedTab] or "")
            if hovered then return hovered end
            return FindUpgradeInTabById(selectedTab, selectedUpgradeByTab[selectedTab] or "")
        end

        local function FormatAccumulatedStatLine(up, lvl)
            lvl = tonumber(lvl or 0) or 0
            if lvl <= 0 then return nil end

            local id = string.lower(tostring(up and up.id or ""))

            local function asIntOrTrim(v)
                if math.abs(v - math.floor(v)) < 0.001 then
                    return tostring(math.floor(v))
                end
                return tostring(math.floor(v * 100 + 0.5) / 100)
            end

            local templateById = {
                firerate_primary = "%s%% faster firing speed",
                firerate_secondary = "%s%% faster firing speed",
                reload_primary = "%s%% faster reload speed",
                reload_secondary = "%s%% faster reload speed",
                swing_melee = "%s%% faster swing speed",
                resist_fire = "%s%% fire damage resistance",
                resist_bullet = "%s%% bullet damage resistance",
                resist_blast = "%s%% blast damage resistance",
                resist_all = "%s%% damage resistance",
                move_speed = "%s%% movement speed",
                jump_height = "%s%% jump height",
                damage_primary = "%s%% damage bonus",
                damage_secondary = "%s%% damage bonus",
                damage_melee = "%s%% damage bonus",
                clip_primary = "%s%% clip size",
                clip_secondary = "%s%% clip size",
                ammo_primary = "%s%% ammo capacity",
                ammo_secondary = "%s%% ammo capacity",
                effectbar_secondary = "%s%% faster recharge rate",
                buff_duration_secondary = "%s%% buff duration",
                effectbar_primary = "%s%% faster recharge rate",
                effectbar_melee = "%s%% faster recharge rate",
                autoheal = "%s health regenerated per second",
                lifesteal_melee = "%s health on kill",
                max_health = "%s max health",
                canteen_capacity = "%s canteen capacity",
            }

            local perLevelById = {
                -- Percent upgrades
                firerate_primary = 10,
                firerate_secondary = 10,
                reload_primary = 20,
                reload_secondary = 20,
                swing_melee = 10,
                resist_fire = 10,
                resist_bullet = 10,
                resist_blast = 10,
                resist_all = 8,
                move_speed = 10,
                jump_height = 20,
                damage_primary = 20,
                damage_secondary = 20,
                damage_melee = 25,
                clip_primary = 50,
                clip_secondary = 50,
                ammo_primary = 50,
                ammo_secondary = 50,
                effectbar_secondary = 25,
                buff_duration_secondary = 25,
                effectbar_primary = 25,
                effectbar_melee = 25,
                -- Flat upgrades
                autoheal = 2,
                lifesteal_melee = 25,
                max_health = 25,
                canteen_capacity = 1,
            }

            if templateById[id] and perLevelById[id] then
                local total = (perLevelById[id] or 0) * lvl
                return "+" .. string.format(templateById[id], asIntOrTrim(total))
            end

            local raw = MaybeLocalize(up and up.name or "")
            if not isstring(raw) or raw == "" then
                raw = MaybeLocalize(up and up.description or "")
            end
            raw = string.Trim(tostring(raw or ""))
            if raw == "" then return nil end

            -- e.g. "+10% Firing Speed" -> "+30% Firing Speed" at level 3
            local pct, label = string.match(raw, "^%+?([%d%.]+)%%%s+(.+)$")
            if pct and label then
                local total = (tonumber(pct) or 0) * lvl
                if total ~= total then return raw end
                return string.format("+%s%% %s", asIntOrTrim(total), tostring(label))
            end

            -- e.g. "+1 Canteen Capacity" -> "+2 Canteen Capacity" at level 2
            local flat, flatLabel = string.match(raw, "^%+?([%d%.]+)%s+(.+)$")
            if flat and flatLabel then
                local total = (tonumber(flat) or 0) * lvl
                return string.format("+%s %s", asIntOrTrim(total), tostring(flatLabel))
            end

            return raw
        end

        local function BuildTabStatsText(tabKey)
            local lines = {}
            for _, candidate in ipairs(payload.upgrades or {}) do
                if UpgradeBelongsToTab(candidate, tabKey) then
                    local lvl = tonumber(candidate.level or 0) or 0
                    if lvl > 0 then
                        local line = FormatAccumulatedStatLine(candidate, lvl)
                        if isstring(line) and line ~= "" then
                            lines[#lines + 1] = line
                        end
                    end
                end
            end
            return table.concat(lines, "\n")
        end

        local function SetInfo(up)
            local activeTab
            for _, t in ipairs(tabs) do
                if t.key == selectedTab then
                    activeTab = t
                    break
                end
            end
            local displayName = activeTab and activeTab.label or "PLAYER"
            local itemName = nil
            if activeTab and activeTab.slot then
                itemName = select(1, GetSlotItemVisual(activeTab.slot, subjectPly))
            end
            local statsText = BuildTabStatsText(selectedTab)
            local selectedDesc = ""
            local selectedTitle = ""
            if up then
                selectedDesc = MaybeLocalize(up.description or TF_MVMShop.ScriptDescriptionById[up.id] or "")
                if not isstring(selectedDesc) then
                    selectedDesc = tostring(selectedDesc or "")
                end
                selectedDesc = string.Trim(selectedDesc)
                selectedTitle = MaybeLocalize(up.name or TF_MVMShop.DisplayNameById[up.id] or "")
                if not isstring(selectedTitle) then
                    selectedTitle = tostring(selectedTitle or "")
                end
                selectedTitle = string.Trim(selectedTitle)
            end

            infoPanel.name:SetText((up and selectedTitle ~= "") and selectedTitle or displayName)
            local bodyParts = {}
            if up then
                if selectedDesc == "" and selectedTitle ~= "" then
                    selectedDesc = selectedTitle
                end
                if selectedDesc ~= "" then
                    bodyParts[#bodyParts + 1] = selectedDesc
                end
                if isstring(itemName) and itemName ~= "" then
                    bodyParts[#bodyParts + 1] = itemName
                end
                if statsText ~= "" then
                    bodyParts[#bodyParts + 1] = statsText
                end
            else
                if isstring(itemName) and itemName ~= "" then
                    bodyParts[#bodyParts + 1] = itemName
                end
                if statsText ~= "" then
                    bodyParts[#bodyParts + 1] = statsText
                end
            end
            infoPanel.desc:SetText(table.concat(bodyParts, "\n\n"))

            if up then
                local nextCost = tonumber(up.nextCost or 0) or 0
                if nextCost > 0 then
                    infoPanel.slotLabel:SetText(FormatUpgradeCost(nextCost))
                    if (tonumber(payload.credits or 0) or 0) < nextCost then
                        infoPanel.slotLabel:SetTextColor(Color(223, 89, 71, 255))
                    else
                        infoPanel.slotLabel:SetTextColor(Color(252, 221, 118))
                    end
                else
                    infoPanel.slotLabel:SetText(txtMaxReached)
                    infoPanel.slotLabel:SetTextColor(Color(223, 89, 71, 255))
                end
            else
                infoPanel.slotLabel:SetText(txtSelectUpgrade ~= "" and txtSelectUpgrade or txtItemToUpgrade)
                infoPanel.slotLabel:SetTextColor(Color(252, 221, 118))
            end
        end

        local list = vgui.Create("DScrollPanel", card)
        card.UpgradeList = list
        local baseListX = res.upgradeListX or ((res.innerX or 10) + (res.infoW or 130) + (res.innerX or 10))
        local baseListY = res.upgradeListY or (res.innerBGY or 55)
        local listPosX = math.floor(baseListX * uiScale)
        local listPosY = math.floor(baseListY * uiScale)
        list:SetPos(listPosX, listPosY)
        local listY = listPosY
        local listH = bottomY - listY - math.floor(5 * uiScale)
        list:SetSize(cardW - listPosX - pad, listH)
        list:GetCanvas():DockPadding(0, 0, 0, 0)

        local rebuildRequested = false
        local nextRebuildAt = 0
        local function QueueRebuild()
            if not IsValid(list) then return end
            rebuildRequested = true
            nextRebuildAt = CurTime() + 0.05
        end
        card.QueueUpgradeRebuild = QueueRebuild

        function list:PopulateRows()
            self:Clear()
            local cols = 2
            local spacing = math.floor((res.upgradeDelta or 6) * uiScale)
            local areaW = self:GetWide()
            local upgradeCardW = math.floor((res.rowW or 155) * uiScale)
            local upgradeCardH = math.floor((res.rowH or 45) * uiScale)
            if areaW < (upgradeCardW * 2 + spacing) then
                upgradeCardW = math.floor((areaW - spacing * (cols - 1)) / cols)
            end

            local x = 0
            local y = 0
            local count = 0

            for _, up in ipairs(payload.upgrades or {}) do
                if not UpgradeBelongsToTab(up, selectedTab) then
                    continue
                end
                count = count + 1

                local row = self:Add("DPanel")
                row:SetSize(upgradeCardW, upgradeCardH)
                row:SetPos(x, y)
                row:SetMouseInputEnabled(true)
                row.hovered = false
                row.selected = false
                function row:OnCursorEntered()
                    self.hovered = true
                    hoveredUpgradeByTab[selectedTab] = up.id
                    PlayUiRollover()
                    SetInfo(up)
                end
                function row:OnCursorExited()
                    -- Ignore child transition exits; row:Think handles true leave.
                end
                function row:Think()
                    local mx, my = gui.MousePos()
                    if mx <= 0 and my <= 0 then return end
                    local sx, sy = self:LocalToScreen(0, 0)
                    local inside = mx >= sx and mx < (sx + self:GetWide()) and my >= sy and my < (sy + self:GetTall())
                    if inside then
                        if not self.hovered then
                            self.hovered = true
                            hoveredUpgradeByTab[selectedTab] = up.id
                            SetInfo(up)
                        end
                    elseif self.hovered then
                        self.hovered = false
                        if hoveredUpgradeByTab[selectedTab] == up.id then
                            hoveredUpgradeByTab[selectedTab] = nil
                        end
                        SetInfo(GetPriorityUpgradeForCurrentTab())
                    end
                end
                row.OnMousePressed = function(self, mc)
                    if mc ~= MOUSE_LEFT then return end
                    local cx, cy = self:LocalCursorPos()
                    local stripW = math.floor((res.rowRightW or 20) * uiScale)
                    -- Don't handle clicks on the right strip area (leave those to the buttons)
                    if (cx >= (self:GetWide() - stripW - math.floor(2 * uiScale))) then
                        return
                    end
                    self.selected = true
                    selectedUpgradeByTab[selectedTab] = up.id
                    hoveredUpgradeByTab[selectedTab] = up.id
                    SetInfo(up)
                    for _, child in ipairs(self:GetParent():GetChildren()) do
                        if child ~= self and child.selected ~= nil then
                            child.selected = false
                        end
                    end
                end
                row.Paint = function(self, w, h)
                    local rowRadius = math.max(3, math.floor(4 * uiScale))
                    draw.RoundedBox(
                        rowRadius,
                        0,
                        0,
                        w,
                        h,
                        res.colRowBG or Color(97, 94, 85, 255)
                    )
                    draw.RoundedBox(
                        math.max(2, math.floor(2 * uiScale)),
                        math.floor((res.rowIconBorderX or 2) * uiScale),
                        math.floor((res.rowIconBorderY or 2) * uiScale),
                        math.floor((res.rowIconW or 30) * uiScale),
                        math.floor((res.rowIconH or 30) * uiScale),
                        res.colRowIcon or Color(235, 226, 202, 255)
                    )
                    local stripW = math.floor((res.rowRightW or 20) * uiScale)
                    draw.RoundedBoxEx(
                        rowRadius,
                        w - stripW,
                        0,
                        stripW,
                        h,
                        res.colRowRight or Color(117, 114, 103, 255),
                        false,
                        true,
                        false,
                        true
                    )
                    surface.SetDrawColor(0, 0, 0, 70)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    if self.selected then
                        surface.SetDrawColor(242, 140, 74, 255)
                        surface.DrawOutlinedRect(0, 0, w, h, 2)
                    elseif self.hovered then
                        surface.SetDrawColor(res.colHoverUpgrade or Color(239, 128, 73, 255))
                        surface.DrawOutlinedRect(0, 0, w, h)
                    end
                end

                local icon = vgui.Create("DImage", row)
                icon:SetPos(math.floor((res.rowIconX or 4) * uiScale), math.floor((res.rowIconY or 4) * uiScale))
                icon:SetSize(math.floor((res.rowIconInnerW or 26) * uiScale), math.floor((res.rowIconInnerH or 26) * uiScale))
                icon:SetMouseInputEnabled(false)
                local upgradeIconPath = NormalizeIconPath(up.icon)
                if not IsValidIconPath(upgradeIconPath) then
                    upgradeIconPath = UPGRADE_ICON[up.id]
                end
                if not IsValidIconPath(upgradeIconPath) then
                    upgradeIconPath = "vgui/pve/upgrade_unowned"
                end
                SetAspectIcon(icon, upgradeIconPath)

                local price = vgui.Create("DPanel", row)
                local priceY = math.floor((res.priceY or 32) * uiScale)
                price:SetPos(math.floor((res.priceX or 2) * uiScale), priceY)
                price:SetSize(math.floor((res.priceW or 30) * uiScale), math.floor((res.priceH or 13) * uiScale))
                price:SetMouseInputEnabled(false)
                local rowCost = tonumber(up.nextCost or 0) or 0
                local rowCostText = (rowCost > 0) and tostring(rowCost) or ""
                price.Paint = function(self, w, h)
                    if rowCostText == "" then return end
                    draw.SimpleText(rowCostText, res.rowPriceFont or "HudFontSmallestBold", w * 0.5, h * 0.5, colTanLight, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                row.selected = selectedUpgradeByTab[selectedTab] == up.id

                local desc = vgui.Create("DPanel", row)
                local rowTextX = math.floor((res.textX or 37) * uiScale)
                local rowTextY = math.floor((res.textY or 4) * uiScale)
                local rowTextW = math.floor((res.textW or 97) * uiScale)
                local rowTextH = math.floor((res.textH or 22) * uiScale)
                desc:SetPos(rowTextX, rowTextY)
                desc:SetSize(rowTextW, rowTextH)
                desc:SetMouseInputEnabled(false)
                local rowName = MaybeLocalize(up.name or "")
                if not isstring(rowName) or rowName == "" then
                    rowName = TF_MVMShop.DisplayNameById[up.id] or tostring(up.id or "")
                end
                desc.Paint = function(self, w, h)
                    draw.SimpleText(rowName, res.rowNameFont or "HudFontSmallest", 0, h * 0.5, colTanLight, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end

                local plus = vgui.Create("DButton", row)
                plus:SetPos(math.floor((res.plusX or 137) * uiScale), math.floor((res.plusY or 4) * uiScale))
                plus:SetSize(math.floor((res.plusW or 16) * uiScale), math.floor((res.plusH or 16) * uiScale))
                plus:SetText("")
                plus:SetZPos(20)
                plus:SetMouseInputEnabled(true)
                plus:SetKeyboardInputEnabled(false)
                local upCost = tonumber(up.nextCost or 0) or 0
                local credits = tonumber(payload.credits or 0) or 0
                local canBuy = (not frame.SpectatorView) and (up.available ~= false) and up.classAllowed and (up.weaponAllowed ~= false) and upCost > 0 and credits >= upCost
                local canSell = (not frame.SpectatorView) and (up.available ~= false) and up.classAllowed and (up.weaponAllowed ~= false) and (tonumber(up.level or 0) or 0) > 0
                plus:SetEnabled(canBuy)
                if upCost <= 0 then
                    plus:SetTooltip(txtMaxReached)
                elseif credits < upCost then
                    plus:SetTooltip(txtNotEnough)
                else
                    plus:SetTooltip(FormatUpgradeCost(upCost))
                end
                plus.Paint = function(self, w, h)
                    local mat = matBuyDisabled
                    if canBuy then
                        if self:IsDown() or self:IsHovered() then
                            mat = matBuySelected
                        else
                            mat = matBuyEnabled
                        end
                    end
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(mat)
                    surface.DrawTexturedRect(0, 0, w, h)
                end
                plus.OnCursorEntered = function()
                    PlayUiRollover()
                    hoveredUpgradeByTab[selectedTab] = up.id
                    SetInfo(up)
                end
                plus.DoClick = function()
                    if frame.SpectatorView then return end
                    PlayUiClick(res.plusSoundDown)
                    PlayUiClick(res.plusSoundUp)
                    SendAction("buy_upgrade", up.id)
                end

                local minus = vgui.Create("DButton", row)
                minus:SetPos(math.floor((res.minusX or 137) * uiScale), math.floor((res.minusY or 24) * uiScale))
                minus:SetSize(math.floor((res.minusW or 16) * uiScale), math.floor((res.minusH or 16) * uiScale))
                minus:SetText("")
                minus:SetEnabled(canSell)
                minus:SetTooltip(canSell and LocalizeToken("TF_PVE_UpgradeSell") or "")
                minus.Paint = function(self, w, h)
                    local mat = matSellDisabled
                    if self:IsEnabled() then
                        if self:IsDown() or self:IsHovered() then
                            mat = matSellSelected
                        else
                            mat = matSellEnabled
                        end
                    end
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(mat)
                    surface.DrawTexturedRect(0, 0, w, h)
                end
                minus.OnCursorEntered = function()
                    if canSell then
                        PlayUiRollover()
                    end
                    hoveredUpgradeByTab[selectedTab] = up.id
                    SetInfo(up)
                end
                minus.DoClick = function()
                    if frame.SpectatorView or not canSell then return end
                    PlayUiClick(res.minusSoundDown)
                    PlayUiClick(res.minusSoundUp)
                    SendAction("sell_upgrade", up.id)
                end

                local pips = vgui.Create("DPanel", row)
                pips:SetPos(math.floor((res.textX or 37) * uiScale), math.floor((res.upgradeButtonY or 26) * uiScale))
                pips:SetSize(math.floor((res.pipW or 16) * uiScale * 6), math.floor((res.pipH or 16) * uiScale))
                pips:SetMouseInputEnabled(false)
                pips.Paint = function(self, w, h)
                    local maxLevel = math.max(1, tonumber(up.maxLevel or 1) or 1)
                    local level = math.Clamp(tonumber(up.level or 0) or 0, 0, maxLevel)
                    local step = math.floor((res.pipW or 16) * uiScale)
                    local radius = math.max(2, math.floor(((res.pipH or 16) * uiScale) * 0.3125))
                    local centerY = math.floor(h * 0.5)
                    for i = 1, maxLevel do
                        local xPos = (i - 1) * step + math.floor(1 * uiScale)
                        if matPipFilled and not matPipFilled:IsError() and matPipEmpty and not matPipEmpty:IsError() then
                            surface.SetDrawColor(255, 255, 255, 255)
                            surface.SetMaterial((i <= level) and matPipFilled or matPipEmpty)
                            surface.DrawTexturedRect(xPos, centerY - radius, radius * 2, radius * 2)
                        else
                            if i <= level then
                                surface.SetDrawColor(241, 158, 81, 255)
                            else
                                surface.SetDrawColor(58, 55, 52, 255)
                            end
                            draw.NoTexture()
                            surface.DrawPoly((function(cx, cy, r, seg)
                                local t = {}
                                for n = 0, seg do
                                    local a = math.rad((n / seg) * -360)
                                    t[#t + 1] = { x = cx + math.sin(a) * r, y = cy + math.cos(a) * r }
                                end
                                return t
                            end)(xPos + radius, centerY, radius, 18))
                        end
                    end
                end

                x = x + upgradeCardW + spacing
                if count % cols == 0 then
                    x = 0
                    y = y + upgradeCardH + spacing
                end
            end

            self:GetCanvas():SetTall(y + upgradeCardH + spacing)
            SetInfo(GetPriorityUpgradeForCurrentTab())

            local vbar = self:GetVBar()
            if IsValid(vbar) then
                vbar:SetWide(math.max(8, math.floor(8 * uiScale)))
                function vbar:Paint(w, h)
                    surface.SetDrawColor(58, 54, 51, 170)
                    surface.DrawRect(0, 0, w, h)
                end
                if IsValid(vbar.btnUp) then
                    function vbar.btnUp:Paint(w, h)
                        surface.SetDrawColor(95, 90, 84, 120)
                        surface.DrawRect(0, 0, w, h)
                    end
                end
                if IsValid(vbar.btnDown) then
                    function vbar.btnDown:Paint(w, h)
                        surface.SetDrawColor(95, 90, 84, 120)
                        surface.DrawRect(0, 0, w, h)
                    end
                end
                if IsValid(vbar.btnGrip) then
                    function vbar.btnGrip:Paint(w, h)
                        surface.SetDrawColor(133, 124, 112, 170)
                        surface.DrawRect(1, 0, math.max(1, w - 2), h)
                    end
                end
            end
        end

        QueueRebuild()

        local bottom = vgui.Create("DPanel", card)
        bottom:SetPos(pad, bottomY)
        bottom:SetSize(cardW - pad * 2, bottomBarH)
        bottom.Paint = function(self, w, h)
            surface.SetDrawColor(res.colListBG or Color(97, 94, 85, 255))
            surface.DrawRect(0, 0, w, h)

            local creditsColor = res.creditsColor or colCreditsGreen
            if (not creditsColor) or ((creditsColor.a or 255) <= 0) then
                creditsColor = colCreditsGreen
            end
            local creditsTextColor = res.creditsTextColor or colTanLight
            if (not creditsTextColor) or ((creditsTextColor.a or 255) <= 0) then
                creditsTextColor = colTanLight
            end

            local centerX = math.floor(w * 0.5)
            local centerY = math.floor(h * 0.5)
            local amount = tostring(payload.credits or 0)
            local amountFont = res.creditsFont or "HudFontMedium"
            local textFont = res.creditsTextFont or "HudFontSmallBold"

            surface.SetFont(amountFont)
            local amountW = select(1, surface.GetTextSize(amount))
            surface.SetFont(textFont)
            local textW = select(1, surface.GetTextSize(txtCredits))
            local gap = math.floor(8 * uiScale)
            local totalW = amountW + gap + textW
            local leftX = centerX - math.floor(totalW * 0.5)

            draw.SimpleText(amount, amountFont, leftX + amountW, centerY, creditsColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            draw.SimpleText(txtCredits, textFont, leftX + amountW + gap, centerY, creditsTextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local respecBtn = vgui.Create("DButton", bottom)
        local buttonPadY = math.max(0, math.floor((res.respecY or 285) * uiScale) - bottomY)
        local bottomXOffset = (res.innerX or 10)
        respecBtn:SetPos(math.floor(((res.respecX or 50) - bottomXOffset) * uiScale), buttonPadY)
        respecBtn:SetSize(math.floor((res.respecW or 120) * uiScale), math.floor((res.respecH or 17) * uiScale))
        respecBtn:SetText(txtRespec)
        SkinActionButton(respecBtn)
        respecBtn:SetEnabled(not frame.SpectatorView)
        respecBtn.DoClick = function()
            PlayUiClick(res.respecSoundDown)
            PlayUiClick(res.respecSoundUp)
            frame:Close()
            SendAction("respec", "")
        end

        local btnW = math.floor((res.cancelW or 75) * uiScale)
        local btnH = math.floor((res.cancelH or 17) * uiScale)
        local cancelBtn = vgui.Create("DButton", bottom)
        cancelBtn:SetSize(btnW, btnH)
        cancelBtn:SetText(txtCancel)
        SkinActionButton(cancelBtn)
        cancelBtn.DoClick = function()
            PlayUiClick(res.cancelSoundDown)
            PlayUiClick(res.cancelSoundUp)
            frame:Close()
        end

        local acceptBtn = vgui.Create("DButton", bottom)
        acceptBtn:SetSize(btnW, btnH)
        acceptBtn:SetText(txtAccept)
        SkinActionButton(acceptBtn)
        acceptBtn.DoClick = function()
            PlayUiClick(res.closeSoundDown)
            PlayUiClick(res.closeSoundUp)
            frame:Close()
        end

        local cancelPadY = math.max(0, math.floor((res.cancelY or 285) * uiScale) - bottomY)
        local closePadY = math.max(0, math.floor((res.closeY or 285) * uiScale) - bottomY)
        cancelBtn:SetPos(math.floor(((res.cancelX or 335) - bottomXOffset) * uiScale), cancelPadY)
        acceptBtn:SetPos(math.floor(((res.closeX or 415) - bottomXOffset) * uiScale), closePadY)

        local function RefreshTabIcons()
            local rebuilt = RebuildTabButtons(false)
            for _, entry in ipairs(tabButtons) do
                local tab = entry.tab
                local _, iconPath = GetSlotItemVisual(tab.slot, subjectPly)
                if not IsValidIconPath(iconPath) then
                    iconPath = tab.fallbackIcon
                end
                if entry.iconPath ~= iconPath then
                    SetAspectIcon(entry.icon, iconPath)
                    entry.iconPath = iconPath
                end
            end
            if rebuilt and card.QueueUpgradeRebuild then
                card:QueueUpgradeRebuild()
            end
            SetInfo(GetPriorityUpgradeForCurrentTab())
        end

        RefreshTabIcons()
        frame.NextIconRefresh = 0
        frame.EscapeLatch = false
        frame.Think = function(self)
            local escDown = input.IsKeyDown(KEY_ESCAPE)
            if escDown and not self.EscapeLatch then
                self.EscapeLatch = true
                self:Close()
                return
            elseif not escDown then
                self.EscapeLatch = false
            end

            if self.SpectatorView then
                if not IsStillSpectatingObserved(self.ObservedEntIndex) then
                    self:Close()
                    return
                end
            else
                if not IsNearUpgradeStationClient() then
                    self:Close()
                    return
                end
            end
            if CurTime() < (self.NextIconRefresh or 0) then return end
            self.NextIconRefresh = CurTime() + 0.25
            RefreshTabIcons()

            if rebuildRequested and CurTime() >= nextRebuildAt then
                rebuildRequested = false
                if IsValid(card.UpgradeList) and card.UpgradeList.PopulateRows then
                    card.UpgradeList:PopulateRows()
                end
            end
        end

        function frame:ApplyPayload(newPayload)
            if not istable(newPayload) then return end
            payload = newPayload
            self.SpectatorView = payload.spectatorView == true
            self.ObservedEntIndex = tonumber(payload.observedEntIndex or -1) or -1
            subjectPly = self.SpectatorView and Entity(self.ObservedEntIndex) or LocalPlayer()
            if IsValid(classIcon) then
                local cls = string.lower(tostring((IsValid(subjectPly) and subjectPly:GetPlayerClass()) or "scout"))
                SetAspectIcon(classIcon, ResolveClassPortraitIcon(subjectPly, cls))
            end

            upgradesById = {}
            for _, up in ipairs(payload.upgrades or {}) do
                if up.id then upgradesById[up.id] = up end
            end

            RebuildTabButtons(true)
            RefreshTabIcons()
            if card.QueueUpgradeRebuild then
                card:QueueUpgradeRebuild()
            end
        end
    end
    -- Prompt removed; panel opens automatically on touch.


    hook.Add("Think", "TF_MVMShop_ClientPromptThink", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        if not IsMvMMap() or not ply:Alive() or GetConVarNumber("cl_drawhud") == 0 then
            return
        end
        -- clear suppression once the player walks out of the station
        if lastCloseTime and not IsNearUpgradeStationClient() then
            lastCloseTime = nil
        end
    end)

    hook.Add("PlayerBindPress", "TF_MVMShop_ActionSlotBind", function(_, bind, pressed)
        if not pressed then return end
        local lower = string.lower(bind or "")
        if not string.find(lower, "+use_action_slot_item", 1, true) then return end
        if not IsMvMMap() then return end
        RunConsoleCommand("tf_mvm_use_canteen")
        return true
    end)

    concommand.Add("tf_mvm_shop", function()
        SendAction("request_open", "")
    end)

    concommand.Add("tf_mvm_use_canteen", function()
        net.Start("TF_MVM_CanteenUse")
        net.SendToServer()
    end)

    IsStillSpectatingObserved = function(entIndex)
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply.GetObserverTarget then return false end
        local observed = ply:GetObserverTarget()
        return IsValid(observed) and observed:EntIndex() == tonumber(entIndex or -1)
    end

    local function ShouldAcceptOpen(payload)
        if istable(payload) and payload.spectatorView then
            return IsStillSpectatingObserved(payload.observedEntIndex)
        end

        if IsNearUpgradeStationClient() then
            return true
        end

        -- ignore opens that come shortly after the user manually closed the panel
        if lastCloseTime and CurTime() < lastCloseTime + 0.5 then
            return false
        end
        return true
    end

    net.Receive("TF_MVM_UpgradeOpen", function()
        local payload = net.ReadTable() or {}
        if not ShouldAcceptOpen(payload) then return end
        -- refresh lookup so client-side helper functions remain accurate
        upgradesById = {}
        for _,up in ipairs(payload.upgrades or {}) do
            if up.id then upgradesById[up.id] = up end
        end
        BuildPanel(payload)
    end)

    net.Receive("TF_MVM_UpgradeClose", function()
        if IsValid(TF_MVMUpgradeFrame) then
            TF_MVMUpgradeFrame:Close()
        end
    end)
end

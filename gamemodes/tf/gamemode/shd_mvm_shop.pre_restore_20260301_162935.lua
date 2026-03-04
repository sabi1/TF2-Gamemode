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

    { id = "damage_secondary", name = "Secondary Damage", category = "Secondary", target = "secondary", description = "+12% damage", costs = { 150, 250, 350, 475 } },
    { id = "firerate_secondary", name = "Secondary Fire Rate", category = "Secondary", target = "secondary", description = "+8% fire speed", costs = { 150, 250, 350, 500 } },
    { id = "reload_secondary", name = "Secondary Reload", category = "Secondary", target = "secondary", description = "+10% reload speed", costs = { 125, 225, 325 } },
    { id = "clip_secondary", name = "Secondary Clip Size", category = "Secondary", target = "secondary", description = "+20% clip size", costs = { 100, 175, 250 } },
    { id = "ammo_secondary", name = "Secondary Ammo", category = "Secondary", target = "secondary", description = "+25% max ammo", costs = { 100, 200, 300 } },

    { id = "damage_melee", name = "Melee Damage", category = "Melee", target = "melee", description = "+15% melee damage", costs = { 125, 225, 325, 425 } },
    { id = "swing_melee", name = "Melee Swing Speed", category = "Melee", target = "melee", description = "+10% swing speed", costs = { 125, 225, 325 } },
    { id = "lifesteal_melee", name = "Melee Heal On Kill", category = "Melee", target = "melee", description = "+25 health on melee kill", costs = { 150, 275, 400 } },

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

    damage_secondary = "damage bonus",
    firerate_secondary = "fire rate bonus",
    reload_secondary = "faster reload rate",
    clip_secondary = "clip size bonus upgrade",
    ammo_secondary = "maxammo secondary increased",

    damage_melee = "damage bonus",
    swing_melee = "melee attack rate bonus",
    lifesteal_melee = "heal on kill",

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
    damage_primary = "+20% Damage",
    firerate_primary = "+10% Firing Speed",
    reload_primary = "+20% Reload Speed",
    clip_primary = "+50% Clip Size",
    ammo_primary = "+50% Ammo Capacity",
    damage_secondary = "+20% Damage",
    firerate_secondary = "+10% Firing Speed",
    reload_secondary = "+20% Reload Speed",
    clip_secondary = "+50% Clip Size",
    ammo_secondary = "+50% Ammo Capacity",
    damage_melee = "+25% Damage",
    swing_melee = "+10% Attack Speed",
    lifesteal_melee = "+25 Health On Kill",
    building_health = "+100% Building Health",
    building_rate = "+10% Sentry Fire Speed",
    canteen_capacity = "+1 Canteen Capacity",
}
TF_MVMShop.AttributeDisplayNameMap = {
    ["damage bonus"] = "+20% Damage",
    ["fire rate bonus"] = "+10% Firing Speed",
    ["faster reload rate"] = "+20% Reload Speed",
    ["clip size bonus upgrade"] = "+50% Clip Size",
    ["maxammo primary increased"] = "+50% Ammo Capacity",
    ["maxammo secondary increased"] = "+50% Ammo Capacity",
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

local function DeriveTierCountFromScript(increment, cap, fallback)
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

local function ApplyCustomUpgradeScriptData(dataByAttrib)
    if not istable(dataByAttrib) then return end
    for _, up in ipairs(TF_MVMShop.DefaultUpgrades) do
        if up.requiresScript then
            up.scriptAvailable = false
        end
        local attr = TF_MVMShop.CustomUpgradeAttributeMap[up.id]
        if attr then
            local byQuality = dataByAttrib[string.lower(attr)]
            local preferQuality = tonumber(TF_MVMShop.CustomUpgradeQualityById[up.id]) or 2
            local scriptData = byQuality and (byQuality[preferQuality] or byQuality[2] or byQuality[1] or byQuality[3]) or nil
            if scriptData then
                if up.requiresScript then
                    up.scriptAvailable = true
                end
                if scriptData.icon and scriptData.icon ~= "" then
                    up.icon = scriptData.icon
                end

                local tierCount = DeriveTierCountFromScript(scriptData.increment, scriptData.cap, #up.costs)
                local baseCost = tonumber(scriptData.cost) or 0
                if baseCost > 0 and tierCount > 0 then
                    up.costs = {}
                    for i = 1, tierCount do
                        up.costs[i] = baseCost
                    end
                end

                local attrLower = string.lower(tostring(scriptData.attribute or attr))
                up.name = TF_MVMShop.AttributeDisplayNameMap[attrLower]
                    or TF_MVMShop.DisplayNameById[up.id]
                    or PrettifyAttributeName(attrLower)
            end
        end
    end
end

local function GetPreferredScriptEntryForUpgrade(up, dataByAttrib)
    if not istable(up) or not istable(dataByAttrib) then return nil end
    local attr = tostring(up.attribute or TF_MVMShop.CustomUpgradeAttributeMap[up.id] or "")
    if attr == "" then return nil end
    local byQuality = dataByAttrib[string.lower(attr)]
    if not byQuality then return nil end
    local preferQuality = tonumber(TF_MVMShop.CustomUpgradeQualityById[up.id]) or 2
    return byQuality[preferQuality] or byQuality[2] or byQuality[1] or byQuality[3]
end

local function ApplyScriptDataToUpgradeList(list, dataByAttrib)
    if not istable(list) then return end
    for _, up in ipairs(list) do
        if up.requiresScript then
            up.scriptAvailable = false
        end

        local scriptData = GetPreferredScriptEntryForUpgrade(up, dataByAttrib)
        if scriptData then
            up.scriptAvailable = true
            up.attribute = tostring(scriptData.attribute or up.attribute or "")
            up.scriptIncrement = tonumber(scriptData.increment) or up.scriptIncrement
            up.scriptCap = tonumber(scriptData.cap) or up.scriptCap
            up.scriptQuality = tonumber(scriptData.quality) or up.scriptQuality
            if scriptData.icon and scriptData.icon ~= "" then
                up.icon = scriptData.icon
            end

            local tierCount = DeriveTierCountFromScript(scriptData.increment, scriptData.cap, #(up.costs or {}))
            local baseCost = tonumber(scriptData.cost) or 0
            if baseCost > 0 and tierCount > 0 then
                up.costs = {}
                for i = 1, tierCount do
                    up.costs[i] = baseCost
                end
            end

            local attrLower = string.lower(tostring(scriptData.attribute or up.attribute or ""))
            up.name = TF_MVMShop.AttributeDisplayNameMap[attrLower]
                or TF_MVMShop.DisplayNameById[up.id]
                or PrettifyAttributeName(attrLower)
        else
            local attrLower = string.lower(tostring(up.attribute or TF_MVMShop.CustomUpgradeAttributeMap[up.id] or ""))
            if (not isstring(up.name)) or up.name == "" then
                up.name = TF_MVMShop.AttributeDisplayNameMap[attrLower]
                    or TF_MVMShop.DisplayNameById[up.id]
                    or PrettifyAttributeName(attrLower ~= "" and attrLower or tostring(up.id or "upgrade"))
            end
            up.scriptIncrement = tonumber(up.scriptIncrement) or nil
            up.scriptCap = tonumber(up.scriptCap) or nil
            up.scriptQuality = tonumber(up.scriptQuality) or nil
        end
    end
end

function TF_MVMShop:LoadUpgrades()
    for _, up in ipairs(TF_MVMShop.DefaultUpgrades) do
        if up.requiresScript then
            up.scriptAvailable = false
        end
    end

    local paths = {}
    -- convar override
    if SERVER then
        local cv = GetConVar("tf_mvm_upgrades_file")
        if cv and cv:GetString() ~= "" then
            table.insert(paths, cv:GetString())
        end
    end

    -- map‑specific file
    local map = string.lower(game.GetMap() or "")
    if map ~= "" then
        table.insert(paths, string.format("maps/%s_upgrades.txt", map))
    end

    -- bundled stock copy extracted from Valve TF2 (fallback when loose files
    -- are unavailable through mounted GAME paths)
    table.insert(paths, "scripts/items/mvm_upgrades_tf2_stock.txt")

    -- default TF2 file(s)
    table.insert(paths, "scripts/items/mvm_upgrades.txt")
    table.insert(paths, "tf/scripts/items/mvm_upgrades.txt")

    for _,path in ipairs(paths) do
        local txt = file.Read(path, "GAME")
        if txt then
            local kv = util.KeyValuesToTable(txt)
            if kv then
                local scriptLookup = ParseUpgradeScriptLookupFromText(txt)
                if not next(scriptLookup) then
                    scriptLookup = ParseUpgradeScriptLookup(kv)
                end
                ApplyCustomUpgradeScriptData(scriptLookup)

                local parsed = parseUpgradesKV(kv)
                local supported = {}
                local known = {}
                local defaultById = {}
                for _, u in ipairs(TF_MVMShop.DefaultUpgrades) do
                    known[u.id] = true
                    defaultById[u.id] = u
                end
                for _, u in ipairs(parsed or {}) do
                    if known[u.id] then
                        local base = table.Copy(defaultById[u.id] or {})
                        if istable(u.costs) and #u.costs > 0 then base.costs = u.costs end
                        if isstring(u.description) and u.description ~= "" then base.description = u.description end
                        if isstring(u.icon) and u.icon ~= "" then base.icon = u.icon end
                        if isstring(u.name) and u.name ~= "" then base.name = u.name end
                        supported[#supported + 1] = base
                    end
                end

                if #supported > 0 then
                    TF_MVMShop.Upgrades = supported
                else
                    TF_MVMShop.Upgrades = table.Copy(TF_MVMShop.DefaultUpgrades)
                end

                ApplyScriptDataToUpgradeList(TF_MVMShop.Upgrades, scriptLookup)

                rebuildUpgradesById()
                if SERVER then
                    print("[MVMShop] loaded upgrades from ", path, " entries=", #TF_MVMShop.Upgrades)
                end
                return
            end
        end
    end
    -- if none found, leave empty and print warning
    if SERVER then
        print("[MVMShop] no compatible upgrade file found, using default list")
    end
    TF_MVMShop.Upgrades = table.Copy(TF_MVMShop.DefaultUpgrades)
    rebuildUpgradesById()
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
else
    -- client should refresh lookup when panel is opened
    hook.Add("NetworkEntityCreated", "TF_MVMShopRefreshLookup", function()
        -- no-op placeholder, kept for symmetry
    end)
end


-- construct lookup table from current Upgrades (will be filled during LoadUpgrades)
rebuildUpgradesById()

local function IsMvMMap()
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

function TF_MVMShop:GetPendingSession(ply, createIfMissing)
    if not IsValid(ply) then return nil end
    local state = self:GetState(ply)
    state.pending = state.pending or {
        active = false,
        deltas = {},
        creditDelta = 0,
    }
    if createIfMissing and not state.pending.active then
        state.pending.active = true
        state.pending.deltas = {}
        state.pending.creditDelta = 0
    end
    return state.pending
end

function TF_MVMShop:ClearPendingSession(ply)
    local pending = self:GetPendingSession(ply, false)
    if not pending then return end
    pending.active = false
    pending.deltas = {}
    pending.creditDelta = 0
end

function TF_MVMShop:GetPendingDelta(ply, id)
    local pending = self:GetPendingSession(ply, false)
    if not pending or not pending.active then return 0 end
    return math.floor(tonumber((pending.deltas and pending.deltas[id]) or 0) or 0)
end

function TF_MVMShop:GetEffectiveLevel(ply, id)
    local base = self:GetLevel(ply, id)
    local delta = self:GetPendingDelta(ply, id)
    return math.max(0, base + delta)
end

function TF_MVMShop:GetEffectiveCredits(ply)
    local base = self:GetCredits(ply)
    local pending = self:GetPendingSession(ply, false)
    if not pending or not pending.active then
        return base
    end
    local delta = math.floor(tonumber(pending.creditDelta or 0) or 0)
    return math.max(0, base + delta)
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
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) and self:GetWeaponSlotName(wep) == logicalSlot then
            return wep
        end
    end
    return nil
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

function TF_MVMShop:IsUpgradeAllowedForLoadout(ply, upgrade)
    local target = string.lower(tostring(upgrade.target or ""))
    local id = string.lower(tostring(upgrade.id or ""))

    if target == "primary" or target == "secondary" or target == "melee" then
        local wep = self:GetWeaponInLogicalSlot(ply, target)
        if not IsValid(wep) then
            return false, "missing_weapon"
        end

        if id == "clip_primary" or id == "clip_secondary" then
            if not self:WeaponSupportsClipUpgrade(wep) then
                return false, "weapon_no_clip"
            end
        elseif id == "reload_primary" or id == "reload_secondary" then
            if not self:WeaponSupportsClipUpgrade(wep) then
                return false, "weapon_no_reload"
            end
        elseif id == "ammo_primary" or id == "ammo_secondary" then
            if not self:WeaponSupportsReserveAmmoUpgrade(wep) then
                return false, "weapon_no_ammo"
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
    if not self:IsUpgradeEnabledByScript(upgrade) then return false, "script_disabled" end
    if not self:IsUpgradeAllowedForClass(ply, upgrade) then return false, "class_restricted" end
    local allowedForLoadout, loadoutReason = self:IsUpgradeAllowedForLoadout(ply, upgrade)
    if not allowedForLoadout then return false, loadoutReason or "weapon_restricted" end

    local level = self:GetEffectiveLevel(ply, id)
    if level >= #upgrade.costs then return false, "maxed" end
    local cost = upgrade.costs[level + 1]
    if self:GetEffectiveCredits(ply) < cost then return false, "no_credits" end

    return true
end

function TF_MVMShop:IsSellWindowOpen()
    local waveCurrent = TF_MVMState and ClampInt(TF_MVMState:Get("wave_current", 1)) or 1
    -- TF2 parity baseline: selling prior upgrades is allowed in wave 1.
    -- (Valve also allows undo of in-flight purchases later, but this UI applies immediately.)
    return waveCurrent <= 1
end

function TF_MVMShop:CanSellUpgrade(ply, id)
    if not self:IsEnabledFor(ply) then return false, "not_enabled" end
    if not self:IsSetupOpenForPurchases() then return false, "setup_only" end

    local upgrade = upgradesById[id]
    if not upgrade then return false, "invalid_upgrade" end
    if not self:IsUpgradeEnabledByScript(upgrade) then return false, "script_disabled" end
    if not self:IsUpgradeAllowedForClass(ply, upgrade) then return false, "class_restricted" end
    local allowedForLoadout, loadoutReason = self:IsUpgradeAllowedForLoadout(ply, upgrade)
    if not allowedForLoadout then return false, loadoutReason or "weapon_restricted" end

    local level = self:GetEffectiveLevel(ply, id)
    if level <= 0 then return false, "no_upgrade" end
    local pendingDelta = self:GetPendingDelta(ply, id)
    if (not self:IsSellWindowOpen()) and pendingDelta <= 0 then return false, "sell_locked" end

    return true
end

function TF_MVMShop:GetUpgradeCost(ply, id)
    local upgrade = upgradesById[id]
    if not upgrade then return nil end
    local level = self:GetEffectiveLevel(ply, id)
    return upgrade.costs[level + 1]
end

function TF_MVMShop:GetWeaponSlotName(wep)
    if not IsValid(wep) then return "" end
    if wep.GetItemData then
        local itemData = wep:GetItemData()
        if itemData and isstring(itemData.item_slot) then
            local slot = string.lower(itemData.item_slot)
            if slot == "primary" or slot == "secondary" or slot == "melee" then
                return slot
            end
        end
    end

    local slot = tonumber(wep.Slot or (wep.GetSlot and wep:GetSlot()) or -1) or -1
    if slot == 0 then return "primary" end
    if slot == 1 then return "secondary" end
    if slot == 2 then return "melee" end
    return ""
end

function TF_MVMShop:GetDamageMultiplier(ply, slot)
    if slot == "primary" then return 1 + (0.12 * self:GetLevel(ply, "damage_primary")) end
    if slot == "secondary" then return 1 + (0.12 * self:GetLevel(ply, "damage_secondary")) end
    if slot == "melee" then return 1 + (0.15 * self:GetLevel(ply, "damage_melee")) end
    return 1
end
function TF_MVMShop:ApplyWeaponStats(ply)
    ply.TF_MVM_BaseAmmoByType = ply.TF_MVM_BaseAmmoByType or {}
    for _, wep in ipairs(ply:GetWeapons()) do
        if not IsValid(wep) then continue end

        local slot = self:GetWeaponSlotName(wep)
        local fireLevel = 0
        local reloadLevel = 0
        local clipLevel = 0
        local ammoLevel = 0

        if slot == "primary" then
            fireLevel = self:GetLevel(ply, "firerate_primary")
            reloadLevel = self:GetLevel(ply, "reload_primary")
            clipLevel = self:GetLevel(ply, "clip_primary")
            ammoLevel = self:GetLevel(ply, "ammo_primary")
        elseif slot == "secondary" then
            fireLevel = self:GetLevel(ply, "firerate_secondary")
            reloadLevel = self:GetLevel(ply, "reload_secondary")
            clipLevel = self:GetLevel(ply, "clip_secondary")
            ammoLevel = self:GetLevel(ply, "ammo_secondary")
        elseif slot == "melee" then
            fireLevel = self:GetLevel(ply, "swing_melee")
        end

        if wep.Primary and isnumber(wep.Primary.Delay) then
            wep.TF_MVM_BasePrimaryDelay = wep.TF_MVM_BasePrimaryDelay or wep.Primary.Delay
            local mul = math.max(0.2, 1 - ((slot == "melee" and 0.1 or 0.08) * fireLevel))
            wep.Primary.Delay = wep.TF_MVM_BasePrimaryDelay * mul
        end

        if wep.Secondary and isnumber(wep.Secondary.Delay) and slot ~= "melee" then
            wep.TF_MVM_BaseSecondaryDelay = wep.TF_MVM_BaseSecondaryDelay or wep.Secondary.Delay
            local mul = math.max(0.2, 1 - (0.08 * fireLevel))
            wep.Secondary.Delay = wep.TF_MVM_BaseSecondaryDelay * mul
        end

        if isnumber(wep.ReloadTime) then
            wep.TF_MVM_BaseReloadTime = wep.TF_MVM_BaseReloadTime or wep.ReloadTime
            wep.ReloadTime = wep.TF_MVM_BaseReloadTime * math.max(0.2, 1 - (0.1 * reloadLevel))
        end

        if wep.Primary and isnumber(wep.Primary.ClipSize) and wep.Primary.ClipSize > 0 then
            wep.TF_MVM_BaseClipSize = wep.TF_MVM_BaseClipSize or wep.Primary.ClipSize
            local newClip = math.max(1, math.floor(wep.TF_MVM_BaseClipSize * (1 + (0.2 * clipLevel))))
            wep.Primary.ClipSize = newClip
            wep:SetClip1(math.min(wep:Clip1(), newClip))
        end

        if ammoLevel > 0 then
            local ammoType = wep.GetPrimaryAmmoType and wep:GetPrimaryAmmoType() or -1
            if isnumber(ammoType) and ammoType >= 0 then
                local currentAmmo = math.max(0, ply:GetAmmoCount(ammoType))
                local baseAmmo = ply.TF_MVM_BaseAmmoByType[ammoType]
                if baseAmmo == nil then
                    baseAmmo = currentAmmo
                    ply.TF_MVM_BaseAmmoByType[ammoType] = baseAmmo
                end
                local targetAmmo = math.max(currentAmmo, math.floor(baseAmmo * (1 + (0.25 * ammoLevel))))
                if targetAmmo > currentAmmo then
                    ply:SetAmmo(targetAmmo, ammoType)
                end
            end
        end
    end
end

function TF_MVMShop:ApplyPlayerStats(ply)
    if not self:IsEnabledFor(ply) then return end

    local hpBonus = 25 * self:GetLevel(ply, "max_health")
    local speedMul = 1 + (0.08 * self:GetLevel(ply, "move_speed"))
    local jumpMul = 1 + (0.1 * self:GetLevel(ply, "jump_height"))

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
    ply.TF_MVM_BaseJumpPower = baseJump
    local boostedJump = math.floor((baseJump * jumpMul) + 0.5)
    -- Some movement paths in this gamemode still reference PlayerJumpPower directly.
    ply.PlayerJumpPower = boostedJump
    ply:SetJumpPower(boostedJump)

    self:ApplyWeaponStats(ply)
end

function TF_MVMShop:GetUpgradeSellRefund(ply, id)
    local upgrade = upgradesById[id]
    if not upgrade then return nil end
    local level = self:GetEffectiveLevel(ply, id)
    if level <= 0 then return nil end
    return upgrade.costs[level]
end

function TF_MVMShop:GetMaxCanteenCharges(ply)
    return 1 + self:GetLevel(ply, "canteen_capacity")
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
    local sellWindowOpen = self:IsSellWindowOpen()
    for _, upgrade in ipairs(self.Upgrades) do
        local scriptAllowed = self:IsUpgradeEnabledByScript(upgrade)
        local classAllowed = self:IsUpgradeAllowedForClass(ply, upgrade)
        local weaponAllowed, restrictionReason = self:IsUpgradeAllowedForLoadout(ply, upgrade)
        local available = scriptAllowed and classAllowed and weaponAllowed
        if available then
            local level = self:GetEffectiveLevel(ply, upgrade.id)
            local costs = istable(upgrade.costs) and upgrade.costs or {}
            local maxLevel = math.max(1, #costs)
            local nextCost = tonumber(costs[level + 1]) or 0
            local pendingDelta = self:GetPendingDelta(ply, upgrade.id)
            local canSellNow = (level > 0) and (sellWindowOpen or pendingDelta > 0)
            local displayName = tostring(upgrade.name or "")
            if displayName == "" or #displayName <= 2 then
                displayName = TF_MVMShop.DisplayNameById[upgrade.id]
                    or PrettifyAttributeName(TF_MVMShop.CustomUpgradeAttributeMap[upgrade.id] or upgrade.id)
            end
            list[#list + 1] = {
                id = upgrade.id,
                name = displayName,
                description = upgrade.description,
                attribute = upgrade.attribute,
                scriptIncrement = upgrade.scriptIncrement,
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
                pendingDelta = pendingDelta,
                canSellNow = canSellNow,
            }
        end
    end

    return {
        credits = self:GetEffectiveCredits(ply),
        inSetup = TF_MVMState and TF_MVMState:Get("in_setup", false) or false,
        waveCurrent = TF_MVMState and TF_MVMState:Get("wave_current", 0) or 0,
        waveTotal = TF_MVMState and TF_MVMState:Get("wave_total", 0) or 0,
        sellWindowOpen = sellWindowOpen,
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

    local function SendPanelToViewer(subject, viewer, spectatorView, readOnly)
        if not IsValid(subject) or not IsValid(viewer) then return end
        local payload = TF_MVMShop:BuildPayload(subject)
        payload.spectatorView = spectatorView and true or false
        payload.readOnly = readOnly and true or false
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

    local function SendPanel(ply, opts)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        local readOnly = istable(opts) and opts.readOnly == true
        TF_MVMShop:GetPendingSession(ply, true)
        SendPanelToViewer(ply, ply, false, readOnly)
        for _, spec in ipairs(GetSpectatorsWatching(ply)) do
            SendPanelToViewer(ply, spec, true, readOnly)
            spec.TF_MVMShopWatching = ply
        end
        ply.TF_MVMUpgradePanelOpen = true
        ply.TF_MVMUpgradeReadOnly = readOnly or nil
        ply.TF_MVMUpgradePanelOpenedAt = CurTime()
    end

    local function IsDroppedPickupCandidate(ent)
        if not IsValid(ent) then return false end
        if not ent.PlayerTouched or not ent.CanPickup then return false end
        local className = string.lower(ent:GetClass() or "")
        return string.find(className, "item_dropped", 1, true) ~= nil
    end

    local function IsReachableFromPlayer(ply, ent, maxDist)
        if not IsValid(ply) or not IsValid(ent) then return false end
        local shootPos = ply:GetShootPos()
        local targetPos = ent.WorldSpaceCenter and ent:WorldSpaceCenter() or ent:GetPos()
        if shootPos:DistToSqr(targetPos) > (maxDist * maxDist) then return false end

        local tr = util.TraceLine({
            start = shootPos,
            endpos = targetPos,
            filter = { ply, ent },
            mask = MASK_SOLID,
        })
        return not tr.Hit
    end

    local function FindDroppedPickupInReach(ply, maxDist)
        local shootPos = ply:GetShootPos()
        local aimVec = ply:GetAimVector()
        local tr = util.TraceLine({
            start = shootPos,
            endpos = shootPos + aimVec * maxDist,
            filter = ply,
            mask = MASK_SOLID,
        })

        local candidates = {}
        if IsValid(tr.Entity) then
            candidates[#candidates + 1] = tr.Entity
        end

        for _, ent in ipairs(ents.FindInSphere(tr.HitPos, 36)) do
            candidates[#candidates + 1] = ent
        end

        local bestEnt = nil
        local bestDistSqr = math.huge
        for _, ent in ipairs(candidates) do
            if not IsDroppedPickupCandidate(ent) then continue end
            if not IsReachableFromPlayer(ply, ent, maxDist) then continue end
            if not ent:CanPickup(ply) then continue end
            local distSqr = ply:GetShootPos():DistToSqr(ent:GetPos())
            if distSqr < bestDistSqr then
                bestDistSqr = distSqr
                bestEnt = ent
            end
        end

        return bestEnt
    end

    local function TriggerQuickInspect(ply)
        if not IsValid(ply) then return end
        ply:SetNWString("inspect", "inspecting_start")
        timer.Simple(0.12, function()
            if not IsValid(ply) then return end
            ply:SetNWString("inspect", "inspecting_released")
            timer.Simple(0.02, function()
                if not IsValid(ply) then return end
                ply:SetNWString("inspect", "inspecting_done")
            end)
        end)
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
        state.pending = { active = false, deltas = {}, creditDelta = 0 }
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

    function TF_MVMShop:StageBuyUpgrade(ply, id)
        local pending = self:GetPendingSession(ply, true)
        local can, reason = self:CanBuyUpgrade(ply, id)
        if not can then return false, reason end
        local cost = self:GetUpgradeCost(ply, id)
        if not cost then return false, "invalid_upgrade" end
        pending.deltas[id] = ClampInt((pending.deltas[id] or 0) + 1)
        pending.creditDelta = math.floor(tonumber(pending.creditDelta or 0) or 0) - math.floor(tonumber(cost) or 0)
        return true
    end

    function TF_MVMShop:StageSellUpgrade(ply, id)
        local pending = self:GetPendingSession(ply, true)
        local can, reason = self:CanSellUpgrade(ply, id)
        if not can then return false, reason end
        local refund = self:GetUpgradeSellRefund(ply, id)
        if not refund then return false, "invalid_upgrade" end
        pending.deltas[id] = ClampInt((pending.deltas[id] or 0) - 1)
        pending.creditDelta = math.floor(tonumber(pending.creditDelta or 0) or 0) + math.floor(tonumber(refund) or 0)
        return true
    end

    function TF_MVMShop:CommitPendingUpgrades(ply)
        local pending = self:GetPendingSession(ply, false)
        if not pending or not pending.active then return true end
        local state = self:GetState(ply)
        local totalSpentDelta = 0

        for id, delta in pairs(pending.deltas or {}) do
            local n = ClampInt(delta)
            if n ~= 0 then
                local before = self:GetLevel(ply, id)
                local after = math.max(0, before + n)
                self:SetLevel(ply, id, after)

                if n > 0 then
                    local upgrade = upgradesById[id]
                    local costs = (upgrade and istable(upgrade.costs)) and upgrade.costs or {}
                    for i = 1, n do
                        totalSpentDelta = totalSpentDelta + (tonumber(costs[before + i] or 0) or 0)
                    end
                elseif n < 0 then
                    local upgrade = upgradesById[id]
                    local costs = (upgrade and istable(upgrade.costs)) and upgrade.costs or {}
                    for i = 0, (-n - 1) do
                        totalSpentDelta = totalSpentDelta - (tonumber(costs[before - i] or 0) or 0)
                    end
                end
            end
        end

        local pendingCreditDelta = math.floor(tonumber(pending.creditDelta or 0) or 0)
        self:AddCredits(ply, pendingCreditDelta)
        state.spent = math.max(0, ClampInt(state.spent) + totalSpentDelta)
        local didBuy = (pendingCreditDelta < 0)
        self:ClearPendingSession(ply)
        self:ApplyPlayerStats(ply)
        if didBuy then
            ply:EmitSound("MVM.PlayerUpgraded")
        end
        return true
    end

    function TF_MVMShop:CancelPendingUpgrades(ply)
        self:ClearPendingSession(ply)
        return true
    end

    function TF_MVMShop:BuyUpgrade(ply, id)
        return self:StageBuyUpgrade(ply, id)
    end

    function TF_MVMShop:SellUpgrade(ply, id)
        return self:StageSellUpgrade(ply, id)
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
        if ply.AddCond then
            ply:AddCond(TF_COND_INVULNERABLE, 5, ply)
        end
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
        TF_MVMShop:ApplyWeaponStats(ply)
    end)

    hook.Add("EntityTakeDamage", "TF_MVMShop_DamageHooks", function(target, dmginfo)
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() and TF_MVMShop:IsEnabledFor(attacker) then
            local slot = ""
            local weapon = attacker:GetActiveWeapon()
            if IsValid(weapon) then slot = TF_MVMShop:GetWeaponSlotName(weapon) end
            dmginfo:ScaleDamage(TF_MVMShop:GetDamageMultiplier(attacker, slot))
        end

        if IsValid(target) and target:IsPlayer() and TF_MVMShop:IsEnabledFor(target) then
            if (target.InCond and target:InCond(TF_COND_INVULNERABLE))
                or (target.InCond and target:InCond(TF_COND_INVULNERABLE_USER_BUFF))
                or (target.InCond and target:InCond(TF_COND_INVULNERABLE_CARD_EFFECT))
                or (target.InCond and target:InCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED)) then
                dmginfo:ScaleDamage(0)
                return
            end

            local resistAll = TF_MVMShop:GetLevel(target, "resist_all")
            if resistAll > 0 then
                dmginfo:ScaleDamage(math.max(0.2, 1 - (0.08 * resistAll)))
            end

            local damageType = dmginfo:GetDamageType()
            if bit.band(damageType, DMG_BULLET) ~= 0 then
                local v = TF_MVMShop:GetLevel(target, "resist_bullet")
                if v > 0 then dmginfo:ScaleDamage(math.max(0.15, 1 - (0.1 * v))) end
            end
            if bit.band(damageType, DMG_BLAST) ~= 0 then
                local v = TF_MVMShop:GetLevel(target, "resist_blast")
                if v > 0 then dmginfo:ScaleDamage(math.max(0.15, 1 - (0.1 * v))) end
            end
            if bit.band(damageType, DMG_BURN) ~= 0 then
                local v = TF_MVMShop:GetLevel(target, "resist_fire")
                if v > 0 then dmginfo:ScaleDamage(math.max(0.15, 1 - (0.12 * v))) end
            end
        end
    end)

    hook.Add("PlayerDeath", "TF_MVMShop_HealOnKill", function(victim, inflictor, attacker)
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
    end)

    hook.Add("Think", "TF_MVMShop_AutoHealRegen", function()
        TF_MVMShop._NextAutoHealTick = TF_MVMShop._NextAutoHealTick or 0
        if CurTime() < TF_MVMShop._NextAutoHealTick then return end
        TF_MVMShop._NextAutoHealTick = CurTime() + 1

        for _, ply in ipairs(player.GetAll()) do
            if not TF_MVMShop:IsEnabledFor(ply) then continue end
            if not ply:Alive() then continue end

            local level = TF_MVMShop:GetLevel(ply, "autoheal")
            if level <= 0 then continue end

            local hp = ply:Health()
            local maxHp = ply:GetMaxHealth()
            if hp >= maxHp then continue end

            local healPerSec = 2 * level
            ply:SetHealth(math.min(maxHp, hp + healPerSec))
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

    concommand.Add("tf_itempicker", function(ply, _, args)
        if not IsValid(ply) or not ply:IsPlayer() then return end

        local mode = string.lower(tostring(args and args[1] or ""))
        if mode == "hat" then
            ply:ConCommand("tf_hatpainter")
            return
        end

        local droppedPickup = FindDroppedPickupInReach(ply, 130)
        if IsValid(droppedPickup) then
            droppedPickup:PlayerTouched(ply)
            return
        end

        if TF_MVMShop:IsEnabledFor(ply) and TF_MVMShop:IsNearUpgradeStation(ply) then
            SendPanel(ply, { readOnly = true })
            return
        end

        TriggerQuickInspect(ply)
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
            ply.TF_MVMUpgradeReadOnly = nil
            TF_MVMShop:CancelPendingUpgrades(ply)
            SendCloseToSpectators(ply)
            return
        end

        local nearStation = TF_MVMShop:IsNearUpgradeStation(ply)
        local hasOpenContext = ply.TF_MVMUpgradePanelOpen
            and ((CurTime() - (tonumber(ply.TF_MVMUpgradePanelOpenedAt) or 0)) <= 30)

        if not nearStation and not hasOpenContext then
            ply.TF_MVMUpgradePanelOpen = nil
            ply.TF_MVMUpgradeReadOnly = nil
            TF_MVMShop:CancelPendingUpgrades(ply)
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
        elseif ply.TF_MVMUpgradeReadOnly and (
            action == "accept"
            or action == "cancel"
            or action == "buy_upgrade"
            or action == "sell_upgrade"
            or action == "respec"
            or action == "buy_canteen"
            or action == "select_canteen"
            or action == "buyback"
        ) then
            SendPanel(ply, { readOnly = true })
            return
        elseif action == "accept" then
            TF_MVMShop:CommitPendingUpgrades(ply)
            ply.TF_MVMUpgradePanelOpen = nil
            ply.TF_MVMUpgradeReadOnly = nil
            net.Start("TF_MVM_UpgradeClose")
            net.Send(ply)
            SendCloseToSpectators(ply)
            return
        elseif action == "cancel" then
            TF_MVMShop:CancelPendingUpgrades(ply)
            ply.TF_MVMUpgradePanelOpen = nil
            ply.TF_MVMUpgradeReadOnly = nil
            net.Start("TF_MVM_UpgradeClose")
            net.Send(ply)
            SendCloseToSpectators(ply)
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
            TF_MVMShop:CancelPendingUpgrades(ply)
            local ok, reason = TF_MVMShop:Respec(ply)
            if ok then
                ply.TF_MVMUpgradePanelOpen = nil
                ply.TF_MVMUpgradeReadOnly = nil
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
    if file.Exists("gamemodes/tf/gamemode/cl_tf2_res.lua", "LUA") then
        include("cl_tf2_res.lua")
    else
        include("vgui/vgui_tf2res.lua")
    end

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
        damage_secondary = "vgui/achievements/tf_demoman_kill_x_with_directpipe",
        firerate_secondary = "vgui/achievements/tf_scout_dodge_damage",
        reload_secondary = "vgui/achievements/tf_heavy_survive_crocket",
        clip_secondary = "vgui/achievements/tf_scout_destroy_sentry_with_pistol",
        ammo_secondary = "vgui/achievements/tf_heavy_assist_grind",
        damage_melee = "vgui/achievements/tf_demoman_kill_x_with_directpipe",
        swing_melee = "vgui/mvm/upgradeicons/upgrade_attackspeed",
        lifesteal_melee = "vgui/achievements/tf_medic_kill_healed_spy",
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
                if alpha == nil then alpha = 255 end
                out[string.lower(k)] = Color(tonumber(r), tonumber(g), tonumber(b), alpha)
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

        local selectPanel = hudTree and TF2Res.FindByFieldName(hudTree, "SelectWeaponPanel") or nil
        local bgGrayout = FindByFieldNames(hudTree, "BGGrayoutPanel")
        local hudPanelRoot = hudTree and TF2Res.FindByKey(hudTree, "HudUpgradePanel") or nil
        local outterPanelBG = FindByFieldNames(hudTree, "OutterPanelBG", "OuterPanelBG")
        local innerRim = hudTree and TF2Res.FindByFieldName(hudTree, "InnerPanelRim") or nil
        local innerBG = hudTree and TF2Res.FindByFieldName(hudTree, "InnerBGPanel") or nil
        local playerUpgradeButton = hudTree and TF2Res.FindByFieldName(hudTree, "PlayerUpgradeButton") or nil
        local activeTabPanel = hudTree and TF2Res.FindByFieldName(hudTree, "ActiveTabPanel") or nil
        local inactiveTabPanel = hudTree and TF2Res.FindByFieldName(hudTree, "InactiveTabPanel1") or nil
        local inactiveSeparatorPanel = FindByFieldNames(hudTree, "InactiveSeparatorPanel")
        local hoverTabPanel = hudTree and TF2Res.FindByFieldName(hudTree, "MouseOverTabPanel") or nil
        local hoverUpgradePanel = hudTree and TF2Res.FindByFieldName(hudTree, "MouseOverUpgradePanel") or nil
        local classImagePanel = hudTree and TF2Res.FindByFieldName(hudTree, "ClassImage") or nil
        local creditsLabel = hudTree and TF2Res.FindByFieldName(hudTree, "CreditsLabel") or nil
        local creditsTextLabel = hudTree and TF2Res.FindByFieldName(hudTree, "CreditsTextLabel") or nil
        local itemsDescBG = FindByFieldNames(hudTree, "UpgradeItemsDescriptionBG")
        local itemsDescLabel = FindByFieldNames(hudTree, "UpgradeItemsDescriptionLabel")
        local upgradeItemsBG = hudTree and TF2Res.FindByFieldName(hudTree, "UpgradeItemsBG") or nil
        local upgradeItemsHeaderBG = hudTree and TF2Res.FindByFieldName(hudTree, "UpgradeItemsHeaderBG") or nil
        local upgradeItemsLabel = hudTree and TF2Res.FindByFieldName(hudTree, "UpgradeItemsLabel") or nil
        local itemStatsLabel = hudTree and TF2Res.FindByFieldName(hudTree, "UpgradeItemStatsLabel") or nil
        local itemNameBG = hudTree and TF2Res.FindByFieldName(hudTree, "ItemNameBG") or nil
        local tipPanel = FindByFieldNames(hudTree, "TipPanel")
        local tipPanelBG = FindByFieldNames(hudTree, "TipPanelBG")
        local tipText = FindByFieldNames(hudTree, "TipText")
        local quickEquipButton = FindByFieldNames(hudTree, "QuickEquipButton")
        local loadoutButton = FindByFieldNames(hudTree, "LoadoutButton")
        local respecButton = hudTree and TF2Res.FindByFieldName(hudTree, "RespecButton") or nil
        local cancelButton = hudTree and TF2Res.FindByFieldName(hudTree, "CancelButton") or nil
        local closeButton = hudTree and TF2Res.FindByFieldName(hudTree, "CloseButton") or nil

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

        local function ResolveOverrideColor(node, key, fallback)
            local raw = TF2Res.GetString(node, key, nil)
            if not isstring(raw) or raw == "" then return fallback end
            local r, g, b, a = raw:match("^(%d+)%s+(%d+)%s+(%d+)%s*(%d*)$")
            if r and g and b then
                local alpha = tonumber(a)
                if alpha == nil then alpha = 255 end
                return Color(tonumber(r), tonumber(g), tonumber(b), alpha)
            end
            return GetSchemeColor(raw, fallback)
        end

        tf2UpgradeResCache = {
            selectW = TF2Res.GetNumber(selectPanel, "wide", 500),
            selectH = TF2Res.GetNumber(selectPanel, "tall", 350),
            panelY = TF2Res.GetNumber(selectPanel, "ypos", 85),
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
            tabTextAlignment = TF2Res.GetString(playerUpgradeButton, "textAlignment", "center"),
            tabTextInsetY = TF2Res.GetNumber(playerUpgradeButton, "textinsety", 6),
            tabTextColor = GetSchemeColor("TanLight", Color(231, 218, 186)),
            tabStartX = TF2Res.GetNumber(activeTabPanel, "xpos", 88),
            tabStartY = TF2Res.GetNumber(playerUpgradeButton, "ypos", 10),
            tabGap = TF2Res.GetNumber(hudPanelRoot, "itempanel_xdelta", 5),
            tabRowBottomY = TF2Res.GetNumber(inactiveSeparatorPanel, "ypos", 48),
            tabSeparatorH = TF2Res.GetNumber(inactiveSeparatorPanel, "tall", 5),
            infoW = TF2Res.GetNumber(itemNameBG, "wide", 130),
            infoX = TF2Res.GetNumber(upgradeItemsBG, "xpos", 25),
            infoY = TF2Res.GetNumber(upgradeItemsBG, "ypos", 135),
            infoH = TF2Res.GetNumber(upgradeItemsBG, "tall", 130),
            infoDescX = TF2Res.GetNumber(itemStatsLabel, "xpos", 30),
            infoDescY = TF2Res.GetNumber(itemStatsLabel, "ypos", 160),
            infoDescW = TF2Res.GetNumber(itemStatsLabel, "wide", 120),
            infoDescH = TF2Res.GetNumber(itemStatsLabel, "tall", 105),
            rowW = TF2Res.GetNumber(upgradeCard, "wide", 155),
            rowH = TF2Res.GetNumber(upgradeCard, "tall", 45),
            rowIconW = TF2Res.GetNumber(iconBorder, "wide", 30),
            rowIconH = TF2Res.GetNumber(iconBorder, "tall", 30),
            rowIconX = TF2Res.GetNumber(iconPanel, "xpos", 4),
            rowIconY = TF2Res.GetNumber(iconPanel, "ypos", 4),
            rowRightW = TF2Res.GetNumber(buySellBG, "wide", 20),
            priceY = TF2Res.GetNumber(priceLabel, "ypos", 32),
            priceX = TF2Res.GetNumber(priceLabel, "xpos", 2),
            priceW = TF2Res.GetNumber(priceLabel, "wide", 30),
            priceH = TF2Res.GetNumber(priceLabel, "tall", 13),
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
            -- CImageButton semantics in TF2:
            -- inactiveimage = idle image, activeimage = hovered/pressed image.
            buyActiveImage = TF2Res.GetString(incrementBtn, "activeimage", "vgui/pve/buy_selected"),
            buyInactiveImage = TF2Res.GetString(incrementBtn, "inactiveimage", "vgui/pve/buy_enabled"),
            sellActiveImage = TF2Res.GetString(decrementBtn, "activeimage", "vgui/pve/sell_selected"),
            sellInactiveImage = TF2Res.GetString(decrementBtn, "inactiveimage", "vgui/pve/sell_enabled"),
            plusSoundDown = TF2Res.GetString(incrementBtn, "sound_depressed", "ui/buttonclick.wav"),
            plusSoundUp = TF2Res.GetString(incrementBtn, "sound_released", "ui/buttonclickrelease.wav"),
            minusSoundDown = TF2Res.GetString(decrementBtn, "sound_depressed", "ui/buttonclick.wav"),
            minusSoundUp = TF2Res.GetString(decrementBtn, "sound_released", "ui/buttonclickrelease.wav"),
            plusDefaultBG = ResolveOverrideColor(incrementBtn, "defaultBgColor_override", Color(255, 255, 255, 0)),
            plusArmedBG = ResolveOverrideColor(incrementBtn, "armedBgColor_override", Color(255, 255, 255, 0)),
            plusDepressedBG = ResolveOverrideColor(incrementBtn, "depressedBgColor_override", Color(255, 255, 255, 0)),
            minusDefaultBG = ResolveOverrideColor(decrementBtn, "defaultBgColor_override", Color(255, 255, 255, 0)),
            minusArmedBG = ResolveOverrideColor(decrementBtn, "armedBgColor_override", Color(255, 255, 255, 0)),
            minusDepressedBG = ResolveOverrideColor(decrementBtn, "depressedBgColor_override", Color(255, 255, 255, 0)),
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
            classX = TF2Res.GetNumber(classImagePanel, "xpos", 30),
            classY = TF2Res.GetNumber(classImagePanel, "ypos", 15),
            classW = TF2Res.GetNumber(classImagePanel, "wide", 40),
            classH = TF2Res.GetNumber(classImagePanel, "tall", 40),
            cardBorderImage = TF2Res.GetString(outterPanelBG, "image", "../HUD/tournament_panel_brown"),
            cardCornerSrcW = TF2Res.GetNumber(outterPanelBG, "src_corner_width", 23),
            cardCornerSrcH = TF2Res.GetNumber(outterPanelBG, "src_corner_height", 23),
            cardCornerDrawW = TF2Res.GetNumber(outterPanelBG, "draw_corner_width", 8),
            cardCornerDrawH = TF2Res.GetNumber(outterPanelBG, "draw_corner_height", 8),
            backdropColor = TF2Res.GetColor(bgGrayout, "bgcolor_override", Color(0, 0, 0, 210)),
            colCardBG = TF2Res.GetColor(selectPanel, "bgcolor_override", Color(63, 59, 55, 250)),
            colActiveTab = TF2Res.GetColor(activeTabPanel, "bgcolor_override", Color(142, 132, 121, 255)),
            colInactiveTab = TF2Res.GetColor(inactiveTabPanel, "bgcolor_override", Color(77, 72, 68, 255)),
            colHoverTab = TF2Res.GetColor(hoverTabPanel, "bgcolor_override", Color(239, 128, 73, 255)),
            colHoverUpgrade = TF2Res.GetColor(hoverUpgradePanel, "bgcolor_override", Color(239, 128, 73, 255)),
            colInactiveSeparator = TF2Res.GetColor(inactiveSeparatorPanel, "bgcolor_override", Color(0, 0, 0, 128)),
            colDescBG = TF2Res.GetColor(itemsDescBG, "bgcolor_override", Color(52, 48, 45, 255)),
            colListBG = TF2Res.GetColor(upgradeItemsBG, "bgcolor_override", Color(97, 94, 85, 255)),
            colListHeader = TF2Res.GetColor(upgradeItemsHeaderBG, "bgcolor_override", Color(72, 68, 63, 255)),
            colRowBG = TF2Res.GetColor(TF2Res.FindByFieldName(buyTree, "InnerPanelRim"), "bgcolor_override", Color(97, 94, 85, 255)),
            colRowIcon = TF2Res.GetColor(iconBorder, "bgcolor_override", Color(235, 226, 202, 255)),
            colRowRight = TF2Res.GetColor(buySellBG, "bgcolor_override", Color(117, 114, 103, 255)),
            creditsFont = TF2Res.GetString(creditsLabel, "font", "HudFontMedium"),
            creditsTextFont = TF2Res.GetString(creditsTextLabel, "font", "HudFontSmallBold"),
            buttonFont = TF2Res.GetString(cancelButton, "font", "HudFontSmallestBold"),
            creditsTextToken = TF2Res.GetString(creditsTextLabel, "labelText", "#TF_PVE_UpgradeAmount"),
            cancelTextToken = TF2Res.GetString(cancelButton, "labelText", "#TF_PVE_UpgradeCancel"),
            closeTextToken = TF2Res.GetString(closeButton, "labelText", "#TF_PVE_UpgradeDone"),
            respecTextToken = TF2Res.GetString(respecButton, "labelText", "#TF_PVE_UpgradeRespec"),
            itemHeaderFont = TF2Res.GetString(upgradeItemsLabel, "font", "HudFontSmallBold"),
            itemStatsFont = TF2Res.GetString(itemStatsLabel, "font", "HudFontSmallest"),
            itemDescFont = TF2Res.GetString(itemsDescLabel, "font", "ItemFontAttribLarge"),
            rowNameFont = TF2Res.GetString(shortDesc, "font", "HudFontSmallest"),
            rowPriceFont = TF2Res.GetString(priceLabel, "font", "HudFontSmallestBold"),
            pipW = TF2Res.GetNumber(skillTreeKV, "wide", 16),
            pipH = TF2Res.GetNumber(skillTreeKV, "tall", 16),
            infoHeaderH = TF2Res.GetNumber(upgradeItemsHeaderBG, "tall", 20),
            titleFont = TF2Res.GetString(upgradeItemsLabel, "font", "HudFontSmallBold"),
            waveFont = TF2Res.GetString(creditsTextLabel, "font", "HudFontSmallestBold"),
            tipX = TF2Res.GetNumber(tipPanel, "xpos", 0),
            tipY = TF2Res.GetNumber(tipPanel, "ypos", 395),
            tipW = TF2Res.GetNumber(tipPanel, "wide", 500),
            tipH = TF2Res.GetNumber(tipPanel, "tall", 40),
            tipFont = TF2Res.GetString(tipText, "font", "HudFontSmallest"),
            tipTextToken = TF2Res.GetString(tipText, "labelText", "%tiptext%"),
            quickEquipX = TF2Res.GetNumber(quickEquipButton, "xpos", 250),
            quickEquipY = TF2Res.GetNumber(quickEquipButton, "ypos", 195),
            quickEquipW = TF2Res.GetNumber(quickEquipButton, "wide", 120),
            quickEquipH = TF2Res.GetNumber(quickEquipButton, "tall", 17),
            quickEquipTextToken = TF2Res.GetString(quickEquipButton, "labelText", "#TF_PVE_Quick_Equip_Bottle"),
            loadoutX = TF2Res.GetNumber(loadoutButton, "xpos", 250),
            loadoutY = TF2Res.GetNumber(loadoutButton, "ypos", 215),
            loadoutW = TF2Res.GetNumber(loadoutButton, "wide", 120),
            loadoutH = TF2Res.GetNumber(loadoutButton, "tall", 17),
            loadoutTextToken = TF2Res.GetString(loadoutButton, "labelText", "#OpenGeneralLoadout"),
            colInnerRim = TF2Res.GetColor(innerRim, "bgcolor_override", Color(142, 132, 121, 255)),
            colInnerBG = TF2Res.GetColor(innerBG, "bgcolor_override", Color(77, 72, 68, 255)),
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

        local tabs = {
            { key = "player", label = "PLAYER", slot = "player", fallbackIcon = SLOT_FALLBACK_ICON.player },
            { key = "primary", label = "PRIMARY", slot = "primary", fallbackIcon = SLOT_FALLBACK_ICON.primary },
            { key = "secondary", label = "SECONDARY", slot = "secondary", fallbackIcon = SLOT_FALLBACK_ICON.secondary },
            { key = "melee", label = "MELEE", slot = "melee", fallbackIcon = SLOT_FALLBACK_ICON.melee },
        }

        if className == "engineer" or className == "spy" then
            local slot = className == "engineer" and "pda" or "building"
            tabs[#tabs + 1] = { key = "special", label = className == "engineer" and "PDA" or "SAPPER", slot = slot, fallbackIcon = SLOT_FALLBACK_ICON[slot] }
        end

        tabs[#tabs + 1] = { key = "action", label = "CANTEEN", slot = "action", fallbackIcon = SLOT_FALLBACK_ICON.action }

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
            local wantsReadOnly = payload.readOnly == true
            if TF_MVMUpgradeFrame.ReadOnly ~= wantsReadOnly then
                TF_MVMUpgradeFrame:Close()
            else
                TF_MVMUpgradeFrame:ApplyPayload(payload)
                return
            end
        end

        local res = GetTF2UpgradeRes()
        local uiScale = math.Clamp(
            math.min(
                ScrW() / ((res.selectW or 500) + 90),
                ScrH() / ((res.selectH or 350) + 120)
            ),
            1.6,
            2.9
        )

        local cardW = math.floor((res.selectW or 500) * uiScale)
        local cardH = math.floor((res.selectH or 350) * uiScale)
        local pad = math.floor((res.innerX or 10) * uiScale)
        local infoW = math.floor((res.infoW or 130) * uiScale)
        local topBarH = math.floor((res.innerY or 50) * uiScale)
        local bottomBarH = math.floor((math.max(res.cancelH or 17, res.respecH or 17) + 12) * uiScale)
        local bottomY = math.floor(((res.innerY or 50) + (res.innerH or 230) + 5) * uiScale)
        local listTop = math.floor((res.innerBGY or 55) * uiScale)
        -- TF2 runtime parity: c_tf_upgrades.cpp overrides button images in code
        -- based on affordability/level, instead of trusting static .res defaults.
        local matBuyActive = Material("vgui/pve/buy_selected")
        local matBuyInactive = Material("vgui/pve/buy_enabled")
        local matBuyDisabled = Material("vgui/pve/buy_disabled")
        local matSellActive = Material("vgui/pve/sell_selected")
        local matSellInactive = Material("vgui/pve/sell_enabled")
        local matSellDisabled = Material("vgui/pve/sell_disabled")
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
        local txtCancel = (payload.readOnly == true) and "CLOSE" or LocalizeToken(res.cancelTextToken or "#TF_PVE_UpgradeCancel")
        local txtAccept = LocalizeToken(res.closeTextToken or "#TF_PVE_UpgradeDone")
        local txtRespec = LocalizeToken(res.respecTextToken or "#TF_PVE_UpgradeRespec")
        local txtItemToUpgrade = LocalizeToken("TF_PVE_UpgradeTitle")

        local function PlayUiRollover()
            surface.PlaySound("ui/buttonrollover.wav")
        end

        local function PlayUiClick(soundPath)
            if isstring(soundPath) and soundPath ~= "" then
                surface.PlaySound(soundPath)
                return
            end
            surface.PlaySound("ui/buttonclickrelease.wav")
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
        frame.ReadOnly = payload.readOnly == true
        frame.ObservedEntIndex = tonumber(payload.observedEntIndex or -1) or -1
        frame.OpenedAt = CurTime()
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
            local bg = res.backdropColor or Color(0, 0, 0, 210)
            surface.SetDrawColor(bg.r, bg.g, bg.b, bg.a)
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

            draw.SimpleText("UPGRADE STATION", res.titleFont or "HudFontSmallBold", pad + math.floor(8 * uiScale), math.floor(6 * uiScale), colTanLight, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            local creditY = bottomY + math.floor(10 * uiScale)
            draw.SimpleText(tostring(payload.credits or 0), res.creditsFont or "HudFontMedium", w * 0.5 - math.floor(24 * uiScale), creditY, colCreditsGreen, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            draw.SimpleText(txtCredits, res.creditsTextFont or "HudFontSmallBold", w * 0.5 - math.floor(18 * uiScale), creditY, colTanLight, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("WAVE " .. tostring(payload.waveCurrent or 0) .. " / " .. tostring(payload.waveTotal or 0), res.waveFont or "HudFontSmallestBold", w - pad - math.floor(8 * uiScale), math.floor(10 * uiScale), colTanLight, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            local sepY = math.floor((res.tabRowBottomY or 48) * uiScale)
            local sepH = math.max(1, math.floor((res.tabSeparatorH or 5) * uiScale))
            local sepCol = res.colInactiveSeparator or Color(0, 0, 0, 128)
            surface.SetDrawColor(sepCol.r, sepCol.g, sepCol.b, sepCol.a)
            surface.DrawRect(pad, sepY, w - (pad * 2), sepH)
        end

        local classIcon = nil

        local tabs = BuildTabsForPlayer(payload, subjectPly)
        local selectedTab = tabs[1] and tabs[1].key or "player"
        local tabButtons = {}

        local tabX = math.floor((res.tabStartX or 88) * uiScale)
        local tabW = math.floor((res.tabW or 70) * uiScale)
        local tabH = math.floor((res.tabH or 50) * uiScale)
        local tabGap = math.max(1, math.floor((res.tabGap or 5) * uiScale))

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
                PlayUiClick()
                selectedTab = tab.key
                if card.QueueUpgradeRebuild then
                    card:QueueUpgradeRebuild()
                end
            end
            btn.OnCursorEntered = function()
                PlayUiRollover()
            end

            local icon = vgui.Create("DImage", btn)
            icon:SetPos(math.floor(4 * uiScale), math.floor(3 * uiScale))
            icon:SetSize(math.floor(30 * uiScale), math.floor(30 * uiScale))
            icon:SetImage(tab.fallbackIcon)

            local label = vgui.Create("DLabel", btn)
            local tabTextX = math.floor((res.tabTextInsetX or 50) * uiScale)
            local tabPadR = math.floor(4 * uiScale)
            local tabTextY = math.floor(6 * uiScale)
            local tabLabelH = math.floor(40 * uiScale)
            label:SetText(tab.label)
            local tabFont = res.tabFont or "HudFontSmallest"
            label:SetFont(tabFont)
            label:SetWrap(false)
            label:SetTextColor(res.tabTextColor or colTanLight)
            label:SetContentAlignment(4)
            surface.SetFont(tabFont)
            local textW = select(1, surface.GetTextSize(tab.label or ""))
            local availW = tabW - tabTextX - tabPadR
            if textW > availW then
                -- Keep text in one line like TF2 by pulling the start left first.
                local minTextX = math.floor(34 * uiScale)
                tabTextX = math.max(minTextX, tabW - textW - tabPadR)
                availW = tabW - tabTextX - tabPadR
            end
            if textW > availW then
                -- Final fallback for GMOD font mismatch with TF2 font metrics.
                tabFont = "HudFontSmallest"
                label:SetFont(tabFont)
            end
            label:SetPos(tabTextX, tabTextY)
            label:SetSize(math.max(1, tabW - tabTextX - tabPadR), tabLabelH)

            tabButtons[#tabButtons + 1] = { tab = tab, button = btn, icon = icon, label = label, iconPath = tab.fallbackIcon }
        end

        local infoPanel = vgui.Create("DPanel", card)
        local infoX = math.floor((res.infoX or (res.innerX or 10)) * uiScale)
        local infoY = math.floor((res.infoY or (res.innerBGY or 55)) * uiScale)
        local infoH = math.floor((res.infoH or (cardH - infoY - bottomBarH - pad)) * uiScale)
        infoPanel:SetPos(infoX, infoY)
        infoPanel:SetSize(infoW, infoH)
        infoPanel.Paint = function(self,w,h)
            surface.SetDrawColor(res.colListBG or Color(97, 94, 85, 255))
            surface.DrawRect(0,0,w,h)
            local descCol = res.colDescBG or res.colListBG or Color(97, 94, 85, 255)
            surface.SetDrawColor(descCol.r, descCol.g, descCol.b, descCol.a)
            surface.DrawRect(0, math.floor((res.infoHeaderH or 20) * uiScale), w, math.max(0, h - math.floor((res.infoHeaderH or 20) * uiScale)))
            surface.SetDrawColor(res.colListHeader or Color(72, 68, 63, 255))
            surface.DrawRect(0, 0, w, math.floor((res.infoHeaderH or 20) * uiScale))
        end

        infoPanel.name = vgui.Create("DLabel", infoPanel)
        infoPanel.name:SetPos(math.floor(4 * uiScale), math.floor(4 * uiScale))
        infoPanel.name:SetSize(infoW - math.floor(8 * uiScale), math.floor(20 * uiScale))
        infoPanel.name:SetFont(res.itemHeaderFont or "HudFontSmallBold")
        infoPanel.name:SetTextColor(colListHeaderText)

        infoPanel.desc = vgui.Create("DLabel", infoPanel)
        local descX = math.floor(((res.infoDescX or 30) - (res.infoX or 25)) * uiScale)
        local descY = math.floor(((res.infoDescY or 160) - (res.infoY or 135)) * uiScale)
        local descW = math.floor((res.infoDescW or 120) * uiScale)
        local descH = math.floor((res.infoDescH or 105) * uiScale)
        infoPanel.desc:SetPos(descX, descY)
        infoPanel.desc:SetSize(descW, descH)
        infoPanel.desc:SetFont(res.itemStatsFont or res.itemDescFont or "HudFontSmallest")
        infoPanel.desc:SetWrap(true)
        infoPanel.desc:SetAutoStretchVertical(true)
        infoPanel.desc:SetTextColor(colAttribPositive)

        infoPanel.slotLabel = vgui.Create("DLabel", infoPanel)
        local slotLabelH = math.floor(14 * uiScale)
        local slotLabelY = infoPanel:GetTall() - slotLabelH - math.floor(8 * uiScale)
        infoPanel.slotLabel:SetPos(math.floor(4 * uiScale), slotLabelY)
        infoPanel.slotLabel:SetSize(infoW - math.floor(8 * uiScale), slotLabelH)
        infoPanel.slotLabel:SetFont("HudFontSmallestBold")
        infoPanel.slotLabel:SetTextColor(Color(252, 221, 118))
        infoPanel.slotLabel:SetText("")

        local function BuildTabStatsText(tabKey)
            local function FormatAccumulatedStatLine(up, lvl)
                local id = string.lower(tostring(up.id or ""))
                local attr = string.lower(tostring(up.attribute or ""))
                local name = MaybeLocalize(up.name or "")
                if not isstring(name) or name == "" then
                    name = tostring(up.id or "Upgrade")
                end
                local shortNameMap = {
                    ["Primary Damage"] = "Damage",
                    ["Secondary Damage"] = "Damage",
                    ["Melee Damage"] = "Damage",
                    ["Primary Fire Rate"] = "Firing Speed",
                    ["Secondary Fire Rate"] = "Firing Speed",
                    ["Primary Reload"] = "Reload Speed",
                    ["Secondary Reload"] = "Reload Speed",
                    ["Primary Clip Size"] = "Clip Size",
                    ["Secondary Clip Size"] = "Clip Size",
                    ["Primary Ammo"] = "Ammo Capacity",
                    ["Secondary Ammo"] = "Ammo Capacity",
                }
                name = shortNameMap[name] or name

                local inc = tonumber(up.scriptIncrement)
                if not inc then
                    local fallbackIncById = {
                        move_speed = 0.08,
                        jump_height = 0.10,
                        resist_all = -0.08,
                        resist_bullet = -0.10,
                        resist_blast = -0.10,
                        resist_fire = -0.12,
                        damage_primary = 0.12,
                        damage_secondary = 0.12,
                        damage_melee = 0.15,
                        firerate_primary = -0.10,
                        firerate_secondary = -0.10,
                        reload_primary = -0.10,
                        reload_secondary = -0.10,
                        clip_primary = 0.50,
                        clip_secondary = 0.50,
                        ammo_primary = 0.50,
                        ammo_secondary = 0.50,
                        swing_melee = -0.10,
                        max_health = 25,
                        autoheal = 2,
                        lifesteal_melee = 25,
                        canteen_capacity = 1,
                        building_health = 0.15,
                        building_rate = 0.10,
                    }
                    inc = fallbackIncById[id]
                    if not inc then
                        local fallbackIncByAttrib = {
                            ["melee attack rate bonus"] = -0.10,
                            ["fire rate bonus"] = -0.10,
                            ["faster reload rate"] = -0.10,
                            ["damage bonus"] = 0.12,
                            ["dmg taken from crit reduced"] = -0.08,
                            ["dmg taken from bullets reduced"] = -0.10,
                            ["dmg taken from blast reduced"] = -0.10,
                            ["dmg taken from fire reduced"] = -0.12,
                            ["move speed bonus"] = 0.08,
                            ["increased jump height"] = 0.10,
                            ["clip size bonus upgrade"] = 0.50,
                            ["maxammo primary increased"] = 0.50,
                            ["maxammo secondary increased"] = 0.50,
                            ["health regen"] = 2,
                            ["max health additive bonus"] = 25,
                            ["heal on kill"] = 25,
                            ["engy building health bonus"] = 0.15,
                            ["engy sentry fire rate increased"] = 0.10,
                            ["canteen specialist"] = 1,
                        }
                        inc = fallbackIncByAttrib[attr]
                    end
                end
                if inc and inc ~= 0 then
                    local total = inc * lvl
                    local absTotal = math.abs(total)

                    -- TF2 scripts store many bonuses as 0.xx fractions.
                    if math.abs(inc) < 1 then
                        local pct = math.floor((absTotal * 100) + 0.5)
                        local sign = total >= 0 and "+" or "-"
                        if string.find(attr, "attack rate", 1, true)
                            or string.find(attr, "fire rate", 1, true)
                            or string.find(attr, "reload", 1, true)
                            or string.find(attr, "dmg taken", 1, true)
                            or string.find(attr, "resistance", 1, true)
                        then
                            sign = "+"
                        elseif string.find(attr, "damage penalty", 1, true) then
                            sign = "-"
                        end
                        return string.format("%s%d%% %s", sign, pct, name)
                    end

                    local rounded = math.floor(absTotal + 0.5)
                    local sign = total >= 0 and "+" or "-"
                    if id == "autoheal" or string.find(attr, "regen", 1, true) then
                        return string.format("%s%d HP/s %s", sign, rounded, name)
                    end
                    return string.format("%s%d %s", sign, rounded, name)
                end

                return "+ " .. name
            end

            local lines = {}
            for _, candidate in ipairs(payload.upgrades or {}) do
                if not UpgradeBelongsToTab(candidate, tabKey) then
                    continue
                end
                local lvl = math.max(0, tonumber(candidate.level or 0) or 0)
                if lvl <= 0 then
                    continue
                end
                lines[#lines + 1] = FormatAccumulatedStatLine(candidate, lvl)
            end
            return table.concat(lines, "\n")
        end

        local function SetInfo(up)
            local statsText = BuildTabStatsText(selectedTab)
            if up then
                infoPanel.name:SetText(MaybeLocalize(up.name or ""))
                local descText = MaybeLocalize(up.description or "")
                if statsText ~= "" then
                    descText = (descText ~= "" and (descText .. "\n\n") or "") .. statsText
                end
                infoPanel.desc:SetText(descText)
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
                infoPanel.name:SetText(displayName)
                local text = itemName or ""
                if statsText ~= "" then
                    text = (text ~= "" and (text .. "\n\n") or "") .. statsText
                end
                infoPanel.desc:SetText(text)
                infoPanel.slotLabel:SetText(txtSelectUpgrade ~= "" and txtSelectUpgrade or txtItemToUpgrade)
                infoPanel.slotLabel:SetTextColor(Color(252, 221, 118))
            end
        end

        local list = vgui.Create("DScrollPanel", card)
        card.UpgradeList = list
        card.SelectedUpgradeByTab = card.SelectedUpgradeByTab or {}
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
            local selectedId = card.SelectedUpgradeByTab and card.SelectedUpgradeByTab[selectedTab]
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
                row.selected = (selectedId ~= nil and up.id == selectedId)
                function row:OnCursorEntered()
                    self.hovered = true
                    PlayUiRollover()
                    SetInfo(up)
                end
                function row:OnCursorExited()
                    self.hovered = false
                    if card.SelectedUpgradeByTab and card.SelectedUpgradeByTab[selectedTab] == up.id then
                        SetInfo(up)
                    else
                        SetInfo(nil)
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
                    card.SelectedUpgradeByTab[selectedTab] = up.id
                    SetInfo(up)
                    for _, child in ipairs(self:GetParent():GetChildren()) do
                        if child ~= self and child.selected ~= nil then
                            child.selected = false
                        end
                    end
                end
                row.Paint = function(self, w, h)
                    surface.SetDrawColor(res.colRowBG or Color(97, 94, 85, 255))
                    surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(res.colRowIcon or Color(235, 226, 202, 255))
                    surface.DrawRect(math.floor(2 * uiScale), math.floor(2 * uiScale), math.floor((res.rowIconW or 30) * uiScale), math.floor((res.rowIconH or 30) * uiScale))
                    local stripW = math.floor((res.rowRightW or 20) * uiScale)
                    surface.SetDrawColor(res.colRowRight or Color(117, 114, 103, 255))
                    surface.DrawRect(w - stripW, 0, stripW, h)
                    if self.selected then
                        surface.SetDrawColor(242, 140, 74, 255)
                        surface.DrawOutlinedRect(0, 0, w, h, 2)
                    elseif self.hovered then
                        surface.SetDrawColor(res.colHoverUpgrade or Color(239, 128, 73, 255))
                        surface.DrawOutlinedRect(0, 0, w, h)
                    end
                end

                local icon = vgui.Create("DImage", row)
                local iconX = math.floor((res.rowIconX or 4) * uiScale)
                local iconY = math.floor((res.rowIconY or 4) * uiScale)
                local iconW = math.max(1, math.floor((res.rowIconW or 30) * uiScale) - (iconX * 2))
                local iconH = math.max(1, math.floor((res.rowIconH or 30) * uiScale) - (iconY * 2))
                icon:SetPos(iconX, iconY)
                icon:SetSize(iconW, iconH)
                icon:SetMouseInputEnabled(false)
                local upgradeIconPath = NormalizeIconPath(up.icon)
                if not IsValidIconPath(upgradeIconPath) then
                    upgradeIconPath = UPGRADE_ICON[up.id]
                end
                if not IsValidIconPath(upgradeIconPath) then
                    upgradeIconPath = "vgui/pve/upgrade_unowned"
                end
                icon:SetImage(upgradeIconPath)

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
                local canBuy = (not frame.SpectatorView) and (not frame.ReadOnly) and (up.available ~= false) and up.classAllowed and (up.weaponAllowed ~= false) and upCost > 0 and credits >= upCost
                local sellWindowOpen = payload.sellWindowOpen ~= false
                local rowSellVisible = sellWindowOpen or ((tonumber(up.pendingDelta or 0) or 0) > 0)
                local canSell = (up.canSellNow == true) and (not frame.SpectatorView) and (not frame.ReadOnly) and (up.available ~= false) and up.classAllowed and (up.weaponAllowed ~= false) and (tonumber(up.level or 0) or 0) > 0
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
                    local bg = res.plusDefaultBG or Color(255, 255, 255, 0)
                    if canBuy then
                        if self:IsDown() then
                            mat = matBuyActive
                            bg = res.plusDepressedBG or bg
                        elseif self:IsHovered() then
                            mat = matBuyActive
                            bg = res.plusArmedBG or bg
                        else
                            mat = matBuyInactive
                            bg = res.plusDefaultBG or bg
                        end
                    end
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(mat)
                    surface.DrawTexturedRect(0, 0, w, h)
                    if bg.a > 0 then
                        surface.SetDrawColor(bg.r, bg.g, bg.b, bg.a)
                        surface.DrawRect(0, 0, w, h)
                    end
                end
                plus.OnCursorEntered = function()
                    PlayUiRollover()
                end
                plus.DoClick = function()
                    if frame.SpectatorView or not canBuy then return end
                    if isstring(res.plusSoundDown) and res.plusSoundDown ~= "" then
                        surface.PlaySound(res.plusSoundDown)
                    end
                    PlayUiClick(res.plusSoundUp)
                    SendAction("buy_upgrade", up.id)
                end

                local minus = vgui.Create("DButton", row)
                minus:SetPos(math.floor((res.minusX or 137) * uiScale), math.floor((res.minusY or 24) * uiScale))
                minus:SetSize(math.floor((res.minusW or 16) * uiScale), math.floor((res.minusH or 16) * uiScale))
                minus:SetText("")
                minus:SetVisible(rowSellVisible)
                minus:SetEnabled(canSell)
                minus:SetTooltip(canSell and LocalizeToken("TF_PVE_UpgradeSell") or "")
                minus.Paint = function(self, w, h)
                    local mat = matSellDisabled
                    local bg = res.minusDefaultBG or Color(255, 255, 255, 0)
                    if canSell then
                        if self:IsDown() then
                            mat = matSellActive
                            bg = res.minusDepressedBG or bg
                        elseif self:IsHovered() then
                            mat = matSellActive
                            bg = res.minusArmedBG or bg
                        else
                            mat = matSellInactive
                            bg = res.minusDefaultBG or bg
                        end
                    end
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(mat)
                    surface.DrawTexturedRect(0, 0, w, h)
                    if bg.a > 0 then
                        surface.SetDrawColor(bg.r, bg.g, bg.b, bg.a)
                        surface.DrawRect(0, 0, w, h)
                    end
                end
                minus.OnCursorEntered = function()
                    if canSell then
                        PlayUiRollover()
                    end
                end
                minus.DoClick = function()
                    if frame.SpectatorView or not canSell then return end
                    if isstring(res.minusSoundDown) and res.minusSoundDown ~= "" then
                        surface.PlaySound(res.minusSoundDown)
                    end
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

            local selectedUp = nil
            if selectedId then
                for _, up in ipairs(payload.upgrades or {}) do
                    if up.id == selectedId and UpgradeBelongsToTab(up, selectedTab) then
                        selectedUp = up
                        break
                    end
                end
            end
            SetInfo(selectedUp)

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
        end

        local respecBtn = vgui.Create("DButton", bottom)
        local buttonPadY = math.max(0, math.floor((res.respecY or 285) * uiScale) - bottomY)
        local bottomXOffset = (res.innerX or 10)
        respecBtn:SetPos(math.floor(((res.respecX or 50) - bottomXOffset) * uiScale), buttonPadY)
        respecBtn:SetSize(math.floor((res.respecW or 120) * uiScale), math.floor((res.respecH or 17) * uiScale))
        respecBtn:SetText(txtRespec)
        SkinActionButton(respecBtn)
        respecBtn:SetEnabled((not frame.SpectatorView) and (not frame.ReadOnly))
        respecBtn.DoClick = function()
            if frame.ReadOnly then return end
            PlayUiClick()
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
            PlayUiClick()
            if frame.ReadOnly then
                frame:Close()
                return
            end
            SendAction("cancel", "")
        end

        local acceptBtn = vgui.Create("DButton", bottom)
        acceptBtn:SetSize(btnW, btnH)
        acceptBtn:SetText(txtAccept)
        SkinActionButton(acceptBtn)
        acceptBtn:SetVisible(not frame.ReadOnly)
        acceptBtn.DoClick = function()
            if frame.ReadOnly then return end
            PlayUiClick()
            SendAction("accept", "")
        end

        local cancelPadY = math.max(0, math.floor((res.cancelY or 285) * uiScale) - bottomY)
        local closePadY = math.max(0, math.floor((res.closeY or 285) * uiScale) - bottomY)
        cancelBtn:SetPos(math.floor(((res.cancelX or 335) - bottomXOffset) * uiScale), cancelPadY)
        acceptBtn:SetPos(math.floor(((res.closeX or 415) - bottomXOffset) * uiScale), closePadY)

        local function RefreshTabIcons()
            for _, entry in ipairs(tabButtons) do
                local tab = entry.tab
                local _, iconPath = GetSlotItemVisual(tab.slot, subjectPly)
                if not IsValidIconPath(iconPath) then
                    iconPath = tab.fallbackIcon
                end
                if entry.iconPath ~= iconPath then
                    entry.icon:SetImage(iconPath)
                    entry.iconPath = iconPath
                end
            end
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
                -- Touch/network updates can arrive one frame late; avoid instantly closing a just-opened panel.
                if CurTime() > ((self.OpenedAt or 0) + 0.75) and not IsNearUpgradeStationClient() then
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
            self.ReadOnly = payload.readOnly == true
            self.ObservedEntIndex = tonumber(payload.observedEntIndex or -1) or -1
            subjectPly = self.SpectatorView and Entity(self.ObservedEntIndex) or LocalPlayer()
            -- ClassImage panel intentionally omitted to avoid duplicate class portrait.

            upgradesById = {}
            for _, up in ipairs(payload.upgrades or {}) do
                if up.id then upgradesById[up.id] = up end
            end

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
        local ok, err = pcall(BuildPanel, payload)
        if not ok then
            ErrorNoHalt("[TF2-Gamemode] Failed to build upgrade panel: " .. tostring(err) .. "\n")
        end
    end)

    net.Receive("TF_MVM_UpgradeClose", function()
        if IsValid(TF_MVMUpgradeFrame) then
            TF_MVMUpgradeFrame:Close()
        end
    end)
end

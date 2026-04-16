TF_MVM = TF_MVM or {}

local SPAWNER = {}
TF_MVM.Spawner = SPAWNER

local function ToArray(v)
    if v == nil then return {} end
    if istable(v) and v[1] ~= nil then return v end
    return { v }
end

local function IsArray(t)
    return istable(t) and t[1] ~= nil
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

local function BoolValue(v, fallback)
    local lower = string.lower(string.Trim(tostring(ScalarValue(v) or "")))
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

local function Merge(base, over)
    if over == nil then return DeepCopy(base) end
    if base == nil then return DeepCopy(over) end

    if type(base) ~= "table" or type(over) ~= "table" then
        return DeepCopy(over)
    end

    if IsArray(base) or IsArray(over) then
        local out = {}
        for _, v in ipairs(ToArray(base)) do
            out[#out + 1] = DeepCopy(v)
        end
        for _, v in ipairs(ToArray(over)) do
            out[#out + 1] = DeepCopy(v)
        end
        return out
    end

    local out = DeepCopy(base)
    for k, v in pairs(over) do
        out[k] = Merge(out[k], v)
    end

    return out
end

local CLASS_ALIAS = {
    heavyweapons = "heavy",
    heavy = "heavy",
    demoman = "demoman",
    demo = "demoman",
    engineer = "engineer",
    medic = "medic",
    soldier = "soldier",
    scout = "scout",
    pyro = "pyro",
    sniper = "sniper",
    spy = "spy",
    sentrybuster = "sentrybuster",
}

local DIFF_ALIAS = {
    easy = 0,
    normal = 1,
    hard = 2,
    expert = 3,
}

local OBJECTIVE_CLASS = {
    spy = "spy",
    sniper = "sniper",
    destroysentries = "sentrybuster",
    sentrybuster = "sentrybuster",
}

local ROMEVISION_PROVIDER_ITEM_ID = 30065 -- The Hardy Laurel

local ROME_PROMO_ITEM_IDS = {
    30143, -- tw_demobot_armor
    30144, -- tw_demobot_helmet
    30145, -- tw_engineerbot_armor
    30146, -- tw_engineerbot_helmet
    30147, -- tw_heavybot_armor
    30148, -- tw_heavybot_helmet
    30149, -- tw_medibot_chariot
    30150, -- tw_medibot_hat
    30151, -- tw_pyrobot_armor
    30152, -- tw_pyrobot_helmet
    30153, -- tw_scoutbot_armor
    30154, -- tw_scoutbot_hat
    30155, -- tw_sniperbot_armor
    30156, -- tw_sniperbot_helmet
    30157, -- tw_soldierbot_armor
    30158, -- tw_soldierbot_helmet
    30159, -- tw_spybot_armor
    30160, -- tw_spybot_hood
    30161, -- tw_sentrybuster
}

local ROME_PROMO_BY_CLASS = {
    scout = {30154, 30153},
    sniper = {30156, 30155},
    soldier = {30158, 30157},
    demoman = {30144, 30143},
    medic = {30150, 30149},
    heavy = {30148, 30147},
    pyro = {30152, 30151},
    spy = {30160, 30159},
    engineer = {30146, 30145},
    sentrybuster = {30161},
}

local function NormalizeItemNameToken(name)
    local text = string.lower(string.Trim(tostring(name or "")))
    text = string.gsub(text, "^the%s+", "")
    text = string.gsub(text, "%s+", " ")
    return text
end

local function EntityHasItemIndex(ent, wantedId)
    if not IsValid(ent) or not wantedId then return false end
    if not isfunction(ent.GetTFItems) then return false end

    for _, item in ipairs(ent:GetTFItems()) do
        if not IsValid(item) then continue end
        if item.ItemIndex and tonumber(item:ItemIndex()) == wantedId then
            return true
        end
    end

    return false
end

local function PlayerHasRomevisionProviderItem(ply)
    if not IsValid(ply) then return false end

    if EntityHasItemIndex(ply, ROMEVISION_PROVIDER_ITEM_ID) then
        return true
    end

    if isfunction(ply.GetTFItems) then
        for _, item in ipairs(ply:GetTFItems()) do
            if not IsValid(item) then continue end
            local data = item.GetItemData and item:GetItemData() or nil
            local name = NormalizeItemNameToken(data and data.name)
            if name == "hardy laurel" then
                return true
            end
        end
    end

    for _, itemName in ipairs(ToArray(ply.ItemLoadout)) do
        if NormalizeItemNameToken(itemName) == "hardy laurel" then
            return true
        end
    end

    return false
end

local function IsRomevisionAvailableForMvM()
    local map = string.lower(game.GetMap() or "")
    if not string.find(map, "mvm_", 1, true) then
        return false
    end

    for _, ply in ipairs(player.GetHumans()) do
        if IsValid(ply) and ply:Team() ~= TEAM_SPECTATOR and PlayerHasRomevisionProviderItem(ply) then
            return true
        end
    end

    return false
end

local function GetRomevisionProviderId(ply)
    if not IsValid(ply) then return "" end
    local steamId64 = ply.SteamID64 and ply:SteamID64() or nil
    if isstring(steamId64) and steamId64 ~= "" and steamId64 ~= "0" then
        return steamId64
    end
    return "ent:" .. tostring(ply:EntIndex())
end

local function GetRomevisionProviders()
    local out = {}
    local seen = {}

    for _, ply in ipairs(player.GetHumans()) do
        if not IsValid(ply) or ply:Team() == TEAM_SPECTATOR then continue end
        if not PlayerHasRomevisionProviderItem(ply) then continue end

        local id = GetRomevisionProviderId(ply)
        if id == "" or seen[id] then continue end
        seen[id] = true

        out[#out + 1] = {
            id = id,
            name = ply:Nick(),
            ent = ply,
        }
    end

    return out
end

local function SendRomevisionOffer(target, providerId, playerName)
    if not isstring(providerId) or providerId == "" then return end
    if not isstring(playerName) or playerName == "" then return end

    net.Start("TF_RomevisionOffer")
        net.WriteString(providerId)
        net.WriteString(playerName)
    if IsValid(target) then
        net.Send(target)
    else
        net.Broadcast()
    end
end

local function SendCurrentRomevisionOffersToPlayer(target)
    if not IsValid(target) then return end
    if not IsRomevisionAvailableForMvM() then return end

    for _, provider in ipairs(GetRomevisionProviders()) do
        SendRomevisionOffer(target, provider.id, provider.name)
    end
end

local function GetBotRomePromoItemIds(bot)
    if not IsValid(bot) then return nil end

    local objective = string.lower(tostring(bot.TF_MVM_Objective or ""))
    if objective == "destroysentries" or objective == "sentrybuster" then
        return ROME_PROMO_BY_CLASS.sentrybuster
    end

    return ROME_PROMO_BY_CLASS[NormalizeClass(bot:GetPlayerClass() or "")]
end

local function GiveBotPromoItem(bot, itemId)
    if not IsValid(bot) or not itemId then return false end
    if EntityHasItemIndex(bot, itemId) then return true end

    local itemIdKey = tostring(itemId)

    if bot.GiveItem then
        bot:GiveItem(itemIdKey)
        return EntityHasItemIndex(bot, itemId)
    end

    local itemData = tf_items and tf_items.ItemsByID and (tf_items.ItemsByID[itemId] or tf_items.ItemsByID[itemIdKey]) or nil
    if itemData and bot.EquipInLoadout and isstring(itemData.name) and itemData.name ~= "" then
        bot:EquipInLoadout(itemData.name)
        return true
    end

    return false
end

local function ApplyRomevisionPromoToBot(bot)
    if not IsValid(bot) or not bot.IsMVMRobot then return false end
    if not IsRomevisionAvailableForMvM() then return false end

    local itemIds = GetBotRomePromoItemIds(bot)
    if not istable(itemIds) or #itemIds == 0 then return false end

    local addedAny = false
    for _, itemId in ipairs(itemIds) do
        if GiveBotPromoItem(bot, itemId) then
            addedAny = true
        end
    end

    if addedAny then
        bot.TF_MVM_RomevisionEquipped = true
    end

    return addedAny
end

local function RefreshMvMRomevisionState()
    local available = IsRomevisionAvailableForMvM()
    local previous = TF_MVM._RomevisionAvailable
    local currentProviders = GetRomevisionProviders()
    local currentProviderSet = {}

    for _, provider in ipairs(currentProviders) do
        currentProviderSet[provider.id] = provider.name
    end

    TF_MVM._RomevisionAvailable = available
    SetGlobalBool("TF_MVM_RomevisionAvailable", available)

    local previousProviderSet = TF_MVM._RomevisionProviders or {}
    TF_MVM._RomevisionProviders = currentProviderSet

    for providerId, playerName in pairs(currentProviderSet) do
        if previousProviderSet[providerId] == nil then
            SendRomevisionOffer(nil, providerId, playerName)
        end
    end

    if available and previous ~= true and TF_MVM and TF_MVM.Runtime and TF_MVM.Runtime.ManagedBots then
        for bot, _ in pairs(TF_MVM.Runtime.ManagedBots) do
            ApplyRomevisionPromoToBot(bot)
        end
    end
end

local function IsPopStrictEnabled()
    local cv = GetConVar("tf_mvm_pop_strict")
    if not cv then return true end
    return cv:GetBool()
end

local function NormalizeClass(name)
    local lower = string.lower(tostring(ScalarValue(name) or "scout"))
    return CLASS_ALIAS[lower] or lower
end

local function NormalizeDisplayBotName(name)
    local text = string.Trim(tostring(ScalarValue(name) or "MvM Bot"))
    if text == "" then
        text = "MvM Bot"
    end
    text = string.Trim(string.gsub(text, "^%(%d+%)%s*", ""))
    text = string.Trim(string.gsub(text, "%s*%(%d+%)$", ""))
    return text
end

local function NormalizeDifficulty(name)
    local lower = string.lower(tostring(ScalarValue(name) or "normal"))
    return DIFF_ALIAS[lower] or 1
end

local function ResolveMissionClass(missionDef, rawBot)
    local explicitClass = NormalizeClass(ScalarValue(missionDef.Class or missionDef.class) or "")
    if explicitClass ~= "" then
        return explicitClass
    end

    if istable(rawBot) and rawBot.Class then
        local rawClass = NormalizeClass(rawBot.Class)
        if rawClass ~= "" then
            return rawClass
        end
    end

    local objective = string.lower(tostring(ScalarValue(missionDef.Objective or missionDef.objective) or ""))
    return OBJECTIVE_CLASS[objective]
end

local function SpawnWhereField(def, explicitWhere)
    if explicitWhere ~= nil then
        return explicitWhere
    end
    if not istable(def) then
        return nil
    end
    return def.ClosestPoint or def.closestpoint or def.Where or def.where
end

local function NormalizeNavAreaFilter(value)
    local lower = string.lower(string.Trim(tostring(ScalarValue(value) or "")))
    if lower == "sentry_spot" or lower == "sentryspot" then
        return "sentry_spot"
    end
    if lower == "sniper_spot" or lower == "sniperspot" then
        return "sniper_spot"
    end
    return lower ~= "" and lower or nil
end

local function ResolveTemplateRecursive(rawDef, templates, stack)
    if not istable(rawDef) then
        return rawDef
    end

    local out = DeepCopy(rawDef)
    local templateField = out.Template
    out.Template = nil

    local mergedTemplate = {}

    for _, templateName in ipairs(ToArray(templateField)) do
        if not isstring(templateName) then continue end

        local lookupKey = string.lower(templateName)
        if stack[lookupKey] then
            continue
        end

        local tpl = templates[lookupKey]
        if istable(tpl) then
            stack[lookupKey] = true
            local resolved = ResolveTemplateRecursive(tpl, templates, stack)
            mergedTemplate = Merge(mergedTemplate, resolved)
            stack[lookupKey] = nil
        end
    end

    return Merge(mergedTemplate, out)
end

function SPAWNER:BuildBotDef(runtime, rawDef)
    local templates = (runtime and runtime.Mission and runtime.Mission.Templates) or {}
    local resolved = ResolveTemplateRecursive(rawDef or {}, templates, {})
    return resolved
end

local function GetNamedSpawns(name)
    local list = {}
    if not isstring(name) or name == "" then return list end

    for _, ent in ipairs(ents.FindByName(name)) do
        if IsValid(ent) then
            list[#list + 1] = ent
        end
    end

    return list
end

local function BuildFallbackSpawnNames(whereName)
    local out = {}
    local seen = {}

    local function add(name)
        name = string.lower(string.Trim(tostring(name or "")))
        if name == "" then return end
        if seen[name] then return end
        seen[name] = true
        out[#out + 1] = name
    end

    local lower = string.lower(tostring(whereName or ""))
    if lower == "" then return out end

    local hasFront = string.find(lower, "front", 1, true) ~= nil
    local hasBack = string.find(lower, "back", 1, true) ~= nil
    local hasLeft = string.find(lower, "left", 1, true) ~= nil
    local hasRight = string.find(lower, "right", 1, true) ~= nil

    local hasMission = string.find(lower, "mission", 1, true) ~= nil
    local isSpy = string.find(lower, "spy", 1, true) ~= nil
    local isSniper = string.find(lower, "sniper", 1, true) ~= nil
    local isBuster = string.find(lower, "buster", 1, true) ~= nil or string.find(lower, "sentry", 1, true) ~= nil

    local function addDirectional(prefix)
        if hasFront and hasLeft then add(prefix .. "_front_left") end
        if hasFront and hasRight then add(prefix .. "_front_right") end
        if hasBack and hasLeft then add(prefix .. "_back_left") end
        if hasBack and hasRight then add(prefix .. "_back_right") end
        if hasFront then add(prefix .. "_front") end
        if hasBack then add(prefix .. "_back") end
        if hasLeft then add(prefix .. "_left") end
        if hasRight then add(prefix .. "_right") end
    end

    -- Mission specialists first.
    if hasMission then
        if isSpy then
            addDirectional("spawnbot_mission_spy")
            add("spawnbot_mission_spy")
        end
        if isSniper then
            addDirectional("spawnbot_mission_sniper")
            add("spawnbot_mission_sniper")
        end
        if isBuster then
            addDirectional("spawnbot_mission_buster")
            add("spawnbot_mission_buster")
            addDirectional("spawnbot_mission_sentrybuster")
            add("spawnbot_mission_sentrybuster")
        end
        addDirectional("spawnbot_mission")
        add("spawnbot_mission")
    end

    -- Generic spawn aliases.
    addDirectional("spawnbot")
    add("spawnbot_invasion")
    add("spawnbot")

    return out
end

local function GetDefaultSpawns()
    local out = {}

    local nameCandidates = {
        "spawnbot",
        "spawnbot_invasion",
        "spawnbot_left",
        "spawnbot_right",
    }

    for _, name in ipairs(nameCandidates) do
        local byName = GetNamedSpawns(name)
        for _, ent in ipairs(byName) do
            out[#out + 1] = ent
        end
    end

    if #out == 0 then
        for _, ent in ipairs(ents.FindByClass("info_player_teamspawn")) do
            if not IsValid(ent) then continue end
            if ent.IsAvailableForTeam and ent:IsAvailableForTeam(TEAM_BLU, false) then
                out[#out + 1] = ent
            end
        end
    end

    return out
end

local function GetNearestNavAnchor(pos, useClosestPoint)
    if not isvector(pos) then return nil end
    if not navmesh or not navmesh.IsLoaded or not navmesh.IsLoaded() or not navmesh.GetNearestNavArea then
        return nil
    end

    local area = navmesh.GetNearestNavArea(pos, true, 1500, true, true)
    if not IsValid(area) then
        return nil
    end

    if useClosestPoint and area.GetClosestPointOnArea then
        local ok, closest = pcall(area.GetClosestPointOnArea, area, pos)
        if ok and isvector(closest) then
            return closest
        end
    end

    if area.GetCenter then
        return area:GetCenter()
    end

    return nil
end

local function ResolveSafeSpawnPos(spawnEnt, useClosestPoint)
    local pos = IsValid(spawnEnt) and spawnEnt:GetPos() or Vector(0, 0, 32)

    -- Prefer nav area anchors to mirror bot-grounded spawn behavior.
    local navPoint = GetNearestNavAnchor(pos, useClosestPoint)
    if navPoint then
        pos = Vector(navPoint.x, navPoint.y, navPoint.z + 8)
    end

    -- Fallback/validation: project to floor.
    local tr = util.TraceLine({
        start = pos + Vector(0, 0, 128),
        endpos = pos - Vector(0, 0, 4096),
        mask = MASK_PLAYERSOLID,
        filter = spawnEnt,
    })
    if tr.Hit then
        pos = tr.HitPos + Vector(0, 0, 8)
    else
        pos = pos + Vector(0, 0, 16)
    end

    local function hullOpen(at)
        local chk = util.TraceHull({
            start = at,
            endpos = at,
            mins = Vector(-16, -16, 0),
            maxs = Vector(16, 16, 72),
            mask = MASK_PLAYERSOLID,
            filter = spawnEnt,
        })
        if chk.StartSolid then return false end
        for _, other in ipairs(ents.FindInSphere(at, 40)) do
            if not IsValid(other) then continue end
            if other == spawnEnt then continue end
            if (other:IsPlayer() or other.IsTFBotValveBase == true or other.TFBot == true) and other:GetPos():DistToSqr(at) < (36 * 36) then
                return false
            end
        end
        return true
    end

    if not hullOpen(pos) then
        -- Spread candidates around spawn so wave bots don't stack into vertical towers.
        local base = pos
        local found = nil
        for ring = 1, 4 do
            local r = ring * 28
            for step = 1, 10 do
                local a = math.rad((step - 1) * (360 / 10) + math.random(-8, 8))
                local tryPos = base + Vector(math.cos(a) * r, math.sin(a) * r, 0)
                local floor = util.TraceLine({
                    start = tryPos + Vector(0, 0, 96),
                    endpos = tryPos - Vector(0, 0, 1024),
                    mask = MASK_PLAYERSOLID,
                    filter = spawnEnt,
                })
                if floor.Hit then
                    tryPos = floor.HitPos + Vector(0, 0, 8)
                end
                if hullOpen(tryPos) then
                    found = tryPos
                    break
                end
            end
            if found then break end
        end
        if found then
            pos = found
        else
            for i = 1, 12 do
                local tryPos = pos + Vector(0, 0, i * 12)
                if hullOpen(tryPos) then
                    pos = tryPos
                    break
                end
            end
        end
    end

    return pos
end

function SPAWNER:ResolveSpawnEntities(whereField, classHint)
    local candidates = {}
    local seen = {}

    local function AddCandidate(ent)
        if not IsValid(ent) then return end
        local id = ent:EntIndex()
        if seen[id] then return end
        seen[id] = true
        candidates[#candidates + 1] = ent
    end

    for _, whereName in ipairs(ToArray(whereField)) do
        if not isstring(whereName) then continue end
        local list = GetNamedSpawns(whereName)
        if #list == 0 then
            for _, aliasName in ipairs(BuildFallbackSpawnNames(whereName)) do
                local aliasList = GetNamedSpawns(aliasName)
                if #aliasList > 0 then
                    list = aliasList
                    break
                end
            end
        end
        for _, ent in ipairs(list) do
            AddCandidate(ent)
        end
    end

    if #candidates == 0 then
        local lowerClass = string.lower(tostring(classHint or ""))
        if lowerClass == "sniper" then
            for _, ent in ipairs(GetNamedSpawns("spawnbot_mission_sniper")) do
                AddCandidate(ent)
            end
        elseif lowerClass == "spy" then
            for _, ent in ipairs(GetNamedSpawns("spawnbot_mission_spy")) do
                AddCandidate(ent)
            end
        elseif lowerClass == "sentrybuster" then
            for _, ent in ipairs(GetNamedSpawns("spawnbot_mission_buster")) do
                AddCandidate(ent)
            end
        end
    end

    if #candidates == 0 then
        for _, ent in ipairs(GetDefaultSpawns()) do
            AddCandidate(ent)
        end
    end

    return candidates
end

function SPAWNER:PickSpawnEntity(whereField, classHint, selectorState, randomSpawn)
    local candidates = self:ResolveSpawnEntities(whereField, classHint)

    if #candidates == 0 then
        return nil
    end

    if randomSpawn then
        return table.Random(candidates)
    end

    if not istable(selectorState) then
        return candidates[1]
    end

    selectorState.index = (tonumber(selectorState.index) or 0) + 1
    if selectorState.index > #candidates then
        selectorState.index = 1
    end
    return candidates[selectorState.index]
end

function SPAWNER:ResolveSpawnEntity(whereField, classHint)
    local candidates = self:ResolveSpawnEntities(whereField, classHint)
    if #candidates == 0 then
        return nil
    end
    return table.Random(candidates)
end

function SPAWNER:PickSeparatedSpawnEntities(whereField, classHint, count, minSeparation)
    local candidates = self:ResolveSpawnEntities(whereField, classHint)
    if #candidates <= 0 then
        return {}
    end

    local wanted = math.max(0, math.floor(tonumber(count) or 0))
    if wanted <= 0 then
        return {}
    end

    local minSepSqr = math.max(0, tonumber(minSeparation) or 0)
    minSepSqr = minSepSqr * minSepSqr

    local shuffled = table.Copy(candidates)
    table.Shuffle(shuffled)

    local picked = {}
    for _, ent in ipairs(shuffled) do
        if #picked >= wanted then
            break
        end

        local pos = IsValid(ent) and ent:GetPos() or nil
        local valid = true
        if pos and minSepSqr > 0 then
            for _, chosen in ipairs(picked) do
                if IsValid(chosen) and chosen:GetPos():DistToSqr(pos) < minSepSqr then
                    valid = false
                    break
                end
            end
        end

        if valid then
            picked[#picked + 1] = ent
        end
    end

    return picked
end

function SPAWNER:PickSeparatedNavAreaPositions(navAreaFilter, count, minSeparation)
    local attrName = NormalizeNavAreaFilter(navAreaFilter)
    if not attrName or not navmesh or not navmesh.GetAllNavAreas then
        return {}
    end

    local wanted = math.max(0, math.floor(tonumber(count) or 0))
    if wanted <= 0 then
        return {}
    end

    local minSepSqr = math.max(0, tonumber(minSeparation) or 0)
    minSepSqr = minSepSqr * minSepSqr

    local candidates = {}
    for _, area in ipairs(navmesh.GetAllNavAreas() or {}) do
        if IsValid(area) and area.HasTFAttribute and area:HasTFAttribute(attrName) then
            candidates[#candidates + 1] = area
        end
    end
    if #candidates <= 0 then
        return {}
    end

    table.Shuffle(candidates)

    local picked = {}
    for _, area in ipairs(candidates) do
        if #picked >= wanted then
            break
        end

        local center = area.GetCenter and area:GetCenter() or nil
        if not isvector(center) then
            continue
        end

        local valid = true
        if minSepSqr > 0 then
            for _, chosenPos in ipairs(picked) do
                if isvector(chosenPos) and chosenPos:DistToSqr(center) < minSepSqr then
                    valid = false
                    break
                end
            end
        end

        if valid then
            picked[#picked + 1] = center
        end
    end

    return picked
end

local function TrimLower(v)
    return string.lower(string.Trim(tostring(ScalarValue(v) or "")))
end

local function NormalizeAttrToken(token)
    token = TrimLower(token)
    token = string.gsub(token, "[%s_%-]", "")
    token = string.gsub(token, "[^%w]", "")
    return token
end

local function ApplyBehaviorModifiers(bot, value)
    for _, mod in ipairs(ToArray(value)) do
        local t = NormalizeAttrToken(mod)
        if t == "mobber" or t == "push" then
            bot.Aggressive = true
            bot.TF_MVM_Aggressive = true
        end
    end
end

local function ApplyBotAttributes(bot, attrs)
    for _, attr in ipairs(ToArray(attrs)) do
        local token = NormalizeAttrToken(attr)

        if token == "alwayscrit" then
            bot.AlwaysCrit = true
            bot.TF_MVM_AlwaysCrit = true
        elseif token == "disablejump" then
            if bot.SetJumpPower then
                bot:SetJumpPower(0)
            end
            bot.TF_MVM_DisableJump = true
        elseif token == "holdfireuntilclose" or token == "holdfireuntilfullreload" then
            bot.HoldFireUntilClose = true
            bot.TF_MVM_HoldFireUntilFullReload = true
        elseif token == "aggressive" then
            bot.Aggressive = true
            bot.TF_MVM_Aggressive = true
        elseif token == "noattack" or token == "suppressfire" then
            bot.NoAttack = true
            bot.TF_MVM_SuppressFire = true
        elseif token == "spawnwithfullcharge" then
            bot:SetNWInt("Ubercharge", 100)
            bot.TF_MVM_SpawnWithFullCharge = true
        elseif token == "mini-boss" or token == "miniboss" then
            bot:SetModelScale(1.75)
            bot.IsBoss = true
            bot:SetNWBool("IsBoss", true)
            bot.TF_MVM_MiniBoss = true
        elseif token == "removeondeath" then
            bot.TF_MVM_RemoveOnDeath = true
        elseif token == "disabledodge" then
            bot.TF_MVM_DisableDodge = true
        elseif token == "becomespectatorondeath" then
            bot.TF_MVM_BecomeSpectatorOnDeath = true
        elseif token == "retainbuildings" then
            bot.TF_MVM_RetainBuildings = true
        elseif token == "ignoreenemies" then
            bot.TF_MVM_IgnoreEnemies = true
            bot.TF_MVM_IgnoreCombat = true
        elseif token == "alwaysfireweapon" then
            bot.TF_MVM_AlwaysFireWeapon = true
        elseif token == "teleporttohint" then
            bot.TF_MVM_TeleportToHint = true
        elseif token == "usebosshealthbar" then
            bot.TF_MVM_UseBossHealthBar = true
        elseif token == "ignoreflag" then
            bot.TF_MVM_IgnoreFlag = true
        elseif token == "autojump" then
            bot.TF_MVM_AutoJump = true
        elseif token == "airchargeonly" then
            bot.TF_MVM_AirChargeOnly = true
        elseif token == "vaccinatorbullets" then
            bot.TF_MVM_PreferVaccinator = "bullets"
        elseif token == "vaccinatorblast" then
            bot.TF_MVM_PreferVaccinator = "blast"
        elseif token == "vaccinatorfire" then
            bot.TF_MVM_PreferVaccinator = "fire"
        elseif token == "bulletimmune" then
            bot.TF_MVM_BulletImmune = true
        elseif token == "blastimmune" then
            bot.TF_MVM_BlastImmune = true
        elseif token == "fireimmune" then
            bot.TF_MVM_FireImmune = true
        elseif token == "parachute" then
            bot.TF_MVM_Parachute = true
        elseif token == "projectileshield" then
            bot.TF_MVM_ProjectileShield = true
        end
    end
end

local BOSS_MODEL_BY_CLASS = {
    scout = "models/bots/scout_boss/bot_scout_boss.mdl",
    soldier = "models/bots/soldier_boss/bot_soldier_boss.mdl",
    demoman = "models/bots/demo_boss/bot_demo_boss.mdl",
    heavy = "models/bots/heavy_boss/bot_heavy_boss.mdl",
    pyro = "models/bots/pyro_boss/bot_pyro_boss.mdl",
}

local function IsMiniBossAttrList(attrs)
    for _, attr in ipairs(ToArray(attrs)) do
        local lower = string.lower(tostring(ScalarValue(attr) or ""))
        if lower == "mini-boss" or lower == "miniboss" then
            return true
        end
    end
    return false
end

local function NormalizeAttrKey(key)
    local lower = string.lower(string.Trim(tostring(key or "")))
    lower = string.gsub(lower, "[%s_%-]", "")
    return lower
end

local function ExtractMoveSpeedBonus(attrs)
    if not istable(attrs) then return nil end

    -- Handle map-style attributes tables directly.
    for k, v in pairs(attrs) do
        local nk = NormalizeAttrKey(k)
        if nk == "movespeedbonus" then
            local n = tonumber(ScalarValue(v))
            if n and n > 0 then
                return n
            end
        end
    end

    -- Handle array-like entries that may contain nested key/value tables.
    for _, attr in ipairs(ToArray(attrs)) do
        if istable(attr) then
            for k, v in pairs(attr) do
                local nk = NormalizeAttrKey(k)
                if nk == "movespeedbonus" then
                    local n = tonumber(ScalarValue(v))
                    if n and n > 0 then
                        return n
                    end
                end
            end
        elseif isstring(attr) then
            local lower = string.lower(attr)
            if string.find(lower, "move speed bonus", 1, true) then
                local n = tonumber(string.match(lower, "([%d%.%-]+)$"))
                if n and n > 0 then
                    return n
                end
            end
        end
    end

    return nil
end

local function ApplyMiniBossSpeedFromAttrs(bot, attrs)
    if not IsValid(bot) then return end
    if not IsMiniBossAttrList(attrs) then return end

    local speedBonus = ExtractMoveSpeedBonus(attrs)
    if not speedBonus then return end

    local classTable = bot.GetPlayerClassTable and bot:GetPlayerClassTable() or nil
    local baseSpeed = classTable and tonumber(classTable.Speed) or nil
    if not baseSpeed or baseSpeed <= 0 then
        baseSpeed = tonumber(bot.GetWalkSpeed and bot:GetWalkSpeed() or 300) or 300
    end

    local finalSpeed = math.max(1, baseSpeed * speedBonus)
    if isfunction(bot.SetClassSpeed) then
        bot:SetClassSpeed(finalSpeed)
    end
    if isfunction(bot.SetWalkSpeed) then
        bot:SetWalkSpeed(finalSpeed)
    end
    if isfunction(bot.SetRunSpeed) then
        bot:SetRunSpeed(finalSpeed)
    end
end

local function NormalizeWeaponRestriction(def)
    local value = ScalarValue(def.WeaponRestrictions or def.weaponrestrictions or "")
    local lower = string.lower(string.Trim(tostring(value or "")))
    if lower == "meleeonly" or lower == "melee_only" or lower == "melee only" then
        return "meleeonly"
    end
    if lower == "primaryonly" or lower == "primary_only" or lower == "primary only" then
        return "primaryonly"
    end
    if lower == "secondaryonly" or lower == "secondary_only" or lower == "secondary only" then
        return "secondaryonly"
    end
    return nil
end

local function GetBotClassBaseSpeed(bot)
    if not IsValid(bot) then return 300 end
    local classTable = bot.GetPlayerClassTable and bot:GetPlayerClassTable() or nil
    local speed = tonumber(classTable and classTable.Speed) or 0
    if speed <= 0 then
        speed = tonumber(bot.GetRunSpeed and bot:GetRunSpeed() or 0)
    end
    return math.max(1, speed > 0 and speed or 300)
end

local function GetBotClassBaseJump(bot)
    if not IsValid(bot) then return 200 end
    local classTable = bot.GetPlayerClassTable and bot:GetPlayerClassTable() or nil
    local jump = tonumber(classTable and classTable.JumpPower) or 0
    if jump <= 0 then
        jump = tonumber(bot.PlayerJumpPower) or tonumber(bot.GetJumpPower and bot:GetJumpPower() or 0)
    end
    return math.max(100, jump > 0 and jump or 200)
end

local function ClampDemoMvMMovement(bot)
    if not IsValid(bot) then return end
    local cls = string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
    if cls ~= "demoman" then return end

    local baseSpeed = GetBotClassBaseSpeed(bot)
    local maxSpeed = baseSpeed * 1.15
    local runSpeed = tonumber(bot.GetRunSpeed and bot:GetRunSpeed() or 0)
    if runSpeed > maxSpeed then
        if isfunction(bot.SetClassSpeed) then
            bot:SetClassSpeed(maxSpeed)
        end
        if isfunction(bot.SetWalkSpeed) then
            bot:SetWalkSpeed(maxSpeed)
        end
        if isfunction(bot.SetRunSpeed) then
            bot:SetRunSpeed(maxSpeed)
        end
        if isfunction(bot.SetMaxSpeed) then
            bot:SetMaxSpeed(maxSpeed)
        end
    end

    local baseJump = tonumber(bot.TF_MVM_BaseJumpPower) or GetBotClassBaseJump(bot)
    local maxJump = baseJump * 1.15
    local jump = tonumber(bot.GetJumpPower and bot:GetJumpPower() or 0)
    if jump > maxJump then
        bot.PlayerJumpPower = maxJump
        if isfunction(bot.SetJumpPower) then
            bot:SetJumpPower(maxJump)
        end
    end
end

local function ForceSelectMelee(bot)
    if not IsValid(bot) then return end
    for _, wep in ipairs(bot:GetWeapons()) do
        if IsValid(wep) and wep.IsMeleeWeapon then
            bot:SelectWeapon(wep:GetClass())
            return
        end
    end
end

local function ResolveAttributeID(nameOrID)
    local n = tonumber(ScalarValue(nameOrID))
    if n then
        return n
    end

    local key = string.lower(string.Trim(tostring(ScalarValue(nameOrID) or "")))
    if key == "" then return nil end
    if not tf_items or not tf_items.Attributes then return nil end

    local def = tf_items.Attributes[key]
    if def and def.id then
        return tonumber(def.id)
    end
    return nil
end

local function BuildExtraAttributes(attrSource, skipKeys)
    local out = {}
    if not istable(attrSource) then return out end

    for k, v in pairs(attrSource) do
        local keyLower = string.lower(string.Trim(tostring(k or "")))
        if not (skipKeys and skipKeys[keyLower]) then
            local attrID = ResolveAttributeID(k)
            local attrValue = tonumber(ScalarValue(v))
            if attrID and attrValue ~= nil then
                out[#out + 1] = { attrID, attrValue }
            end
        end
    end

    return out
end

local function MergeExtraAttributes(base, extra)
    local merged = {}
    local indexByID = {}

    local function PushPair(pair)
        local id = tonumber(pair and pair[1])
        local value = tonumber(pair and pair[2])
        if not id or value == nil then return end
        local existing = indexByID[id]
        if existing then
            merged[existing][2] = value
        else
            merged[#merged + 1] = { id, value }
            indexByID[id] = #merged
        end
    end

    for _, pair in ipairs(ToArray(base)) do
        PushPair(pair)
    end
    for _, pair in ipairs(ToArray(extra)) do
        PushPair(pair)
    end

    return merged
end

local function ApplyExtraAttributesToWeapon(wep, extra)
    if not IsValid(wep) or not wep.SetExtraAttributes then return end
    if not istable(extra) or #extra == 0 then return end

    local merged = MergeExtraAttributes(wep.ExtraAttributesTable or {}, extra)
    if #merged == 0 then return end
    wep:SetExtraAttributes(merged)
end

local function NormalizeItemToken(text)
    local s = string.lower(string.Trim(tostring(ScalarValue(text) or "")))
    if s == "" then return "" end
    s = string.gsub(s, "^tf_weapon_", "")
    s = string.gsub(s, "[^%w]", "")
    return s
end

local function WeaponMatchesItemToken(wep, token)
    if not IsValid(wep) then return false end
    if token == "" then return false end

    local classToken = NormalizeItemToken(wep:GetClass())
    if classToken == token then return true end
    if string.find(classToken, token, 1, true) then return true end

    if wep.GetItemData then
        local data = wep:GetItemData()
        if istable(data) then
            local dataName = NormalizeItemToken(data.name)
            local dataItemName = NormalizeItemToken(data.item_name)
            if dataName == token or dataItemName == token then return true end
            if dataName ~= "" and string.find(dataName, token, 1, true) then return true end
            if dataItemName ~= "" and string.find(dataItemName, token, 1, true) then return true end
        end
    end

    return false
end

local function ParseItemAttributeDefs(rawItemAttrs)
    local defs = {}

    for _, entry in ipairs(ToArray(rawItemAttrs)) do
        if not istable(entry) then continue end

        local selector = ScalarValue(entry.ItemName or entry.itemname or entry.Item or entry.item)
        local attrBlock = entry.Attributes or entry.attributes or entry
        local attrs = BuildExtraAttributes(attrBlock, {
            itemname = true,
            item = true,
            attributes = true,
        })
        if selector and selector ~= "" and #attrs > 0 then
            defs[#defs + 1] = {
                token = NormalizeItemToken(selector),
                attrs = attrs,
            }
        end

        -- Alternate format: ItemAttributes { "tf_weapon_x" { ... } }
        for k, v in pairs(entry) do
            local keyLower = string.lower(tostring(k or ""))
            if keyLower == "itemname" or keyLower == "item" or keyLower == "attributes" then continue end
            if istable(v) then
                local nested = BuildExtraAttributes(v.Attributes or v.attributes or v, nil)
                if #nested > 0 then
                    defs[#defs + 1] = {
                        token = NormalizeItemToken(k),
                        attrs = nested,
                    }
                end
            end
        end
    end

    return defs
end

local function ApplyCharacterAndItemAttributes(bot, def)
    if not IsValid(bot) or not istable(def) then return end

    local charRaw = def.CharacterAttributes or def.characterattributes
    local charExtra = BuildExtraAttributes(charRaw, nil)
    local itemDefs = ParseItemAttributeDefs(def.ItemAttributes or def.itemattributes)
    if #charExtra == 0 and #itemDefs == 0 then return end

    for _, wep in ipairs(bot:GetWeapons()) do
        if not IsValid(wep) then continue end

        if #charExtra > 0 then
            ApplyExtraAttributesToWeapon(wep, charExtra)
        end

        for _, itemDef in ipairs(itemDefs) do
            if WeaponMatchesItemToken(wep, itemDef.token) then
                ApplyExtraAttributesToWeapon(wep, itemDef.attrs)
            end
        end
    end
end

local function ApplyBotItems(bot, items)
    local function ResolveLoadoutItemName(raw)
        if not isstring(raw) then return nil end
        local text = string.Trim(raw)
        if text == "" then return nil end

        text = string.gsub(text, "^[Tt][Hh][Ee]%s+", "")
        local itemsDb = tf_items and tf_items.Items or nil
        if not istable(itemsDb) then
            return text
        end

        if itemsDb[text] then
            return text
        end

        local lower = string.lower(text)
        for key, item in pairs(itemsDb) do
            if not istable(item) then continue end
            local keyLower = string.lower(tostring(key or ""))
            local nameLower = string.lower(tostring(item.name or ""))
            local itemNameLower = string.lower(tostring(item.item_name or ""))
            if keyLower == lower or nameLower == lower or itemNameLower == lower then
                return tostring(key)
            end
        end

        return text
    end

    for _, item in ipairs(ToArray(items)) do
        if not IsValid(bot) then return end

        if bot.EquipInLoadout and isstring(item) then
            local itemName = ResolveLoadoutItemName(item)
            if isstring(itemName) and itemName ~= "" then
                bot:EquipInLoadout(itemName)
            end
        elseif isstring(item) then
            local weaponClass = item
            if not string.StartWith(weaponClass, "tf_weapon_") then
                weaponClass = "tf_weapon_" .. string.lower(weaponClass)
            end
            if bot.Give then
                bot:Give(weaponClass)
            end
        end
    end
end

local function ForceSelectWeaponSlot(bot, slot)
    if not IsValid(bot) then return end
    local wanted = tonumber(slot)
    if not wanted then return end

    for _, wep in ipairs(bot:GetWeapons()) do
        if not IsValid(wep) then continue end
        local wepSlot = tonumber(wep.Slot)
        if wepSlot == nil and wep.GetSlot then
            wepSlot = tonumber(wep:GetSlot())
        end
        if wepSlot == wanted then
            bot:SelectWeapon(wep:GetClass())
            return
        end
    end
end

local function ParseEventChangeAttributes(raw)
    local out = {}
    if not istable(raw) then return out end

    local function mergeEvent(name, block)
        name = TrimLower(name)
        if name == "" then return end
        if not istable(block) then
            if IsPopStrictEnabled() then
                print(string.format("[TF_MVM][POP] strict: EventChangeAttributes '%s' ignored because block is not a table", tostring(name)))
            end
            return
        end
        out[name] = Merge(out[name] or {}, block)
    end

    for k, v in pairs(raw) do
        if isstring(k) then
            if IsArray(v) then
                for _, entry in ipairs(ToArray(v)) do
                    mergeEvent(k, entry)
                end
            else
                mergeEvent(k, v)
            end
        elseif istable(v) then
            for eventName, eventBlock in pairs(v) do
                if isstring(eventName) then
                    mergeEvent(eventName, eventBlock)
                end
            end
        end
    end

    return out
end

local function HasDefinedItems(items)
    for _, item in ipairs(ToArray(items)) do
        if isstring(item) and string.Trim(item) ~= "" then
            return true
        end
    end
    return false
end

local NAME_CLASS_HINTS = {
    scout = "scout",
    soldier = "soldier",
    pyro = "pyro",
    demoman = "demoman",
    heavy = "heavy",
    engineer = "engineer",
    medic = "medic",
    sniper = "sniper",
    spy = "spy",
    sentrybuster = "sentrybuster",
}

local function GuessClassFromName(botName, fallbackClass)
    local lower = string.lower(tostring(botName or ""))
    for token, className in pairs(NAME_CLASS_HINTS) do
        if string.find(lower, token, 1, true) then
            return className
        end
    end
    return fallbackClass
end

local function ApplyDefaultWeaponsFromName(bot, botClass, botName)
    if not IsValid(bot) then return end
    local className = GuessClassFromName(botName, botClass)
    if isstring(className) and className ~= "" then
        -- Re-applying class gives stock weapons for that class when pop has no explicit items.
        bot:SetPlayerClass(className)
    end
end

local function HasGateBotToken(value)
    local lower = string.lower(tostring(ScalarValue(value) or ""))
    if lower == "" then return false end
    if string.find(lower, "gatebot", 1, true) then return true end
    if string.find(lower, "gate bot", 1, true) then return true end
    return false
end

local function IsGateBotDef(def)
    if not istable(def) then return false end

    if HasGateBotToken(def.Name) then return true end
    if HasGateBotToken(def.BotName) then return true end

    for _, item in ipairs(ToArray(def.Item)) do
        if HasGateBotToken(item) then
            return true
        end
    end

    for _, tag in ipairs(ToArray(def.Tag or def.Tags)) do
        if HasGateBotToken(tag) then
            return true
        end
    end

    return false
end

local function BuildTagSet(tags)
    local set = {}
    local list = {}
    for _, tag in ipairs(ToArray(tags)) do
        local key = TrimLower(tag)
        if key ~= "" and not set[key] then
            set[key] = true
            list[#list + 1] = key
        end
    end
    return set, list
end

local function ApplyHealthAndScale(bot, def)
    if not IsValid(bot) or not istable(def) then return end

    local health = tonumber(ScalarValue(def.Health))
    if health and health > 0 then
        health = math.floor(health)
        if bot.SetMaxHealth then
            bot:SetMaxHealth(health)
        end
        if bot.SetHealth then
            bot:SetHealth(math.max(1, health))
        end
    end

    local scale = tonumber(ScalarValue(def.Scale))
    if scale and scale > 0 and bot.SetModelScale then
        bot:SetModelScale(scale)
    end
end

local function ApplyViewAndMovementHints(bot, def)
    if not IsValid(bot) or not istable(def) then return end

    local maxVisionRange = tonumber(ScalarValue(def.MaxVisionRange))
    if maxVisionRange and maxVisionRange > 0 then
        bot.TF_MVM_MaxVisionRange = maxVisionRange
    end

    local autoJumpMin = tonumber(ScalarValue(def.AutoJumpMin))
    local autoJumpMax = tonumber(ScalarValue(def.AutoJumpMax))
    if autoJumpMin or autoJumpMax then
        bot.TF_MVM_AutoJumpMin = autoJumpMin
        bot.TF_MVM_AutoJumpMax = autoJumpMax
    end

    local teleportWhere = ToArray(def.TeleportWhere)
    if #teleportWhere > 0 then
        bot.TF_MVM_TeleportWhere = teleportWhere
    end
end

local function ApplyTeleportToHintIfRequested(bot)
    if not IsValid(bot) then return end
    if not bot.TF_MVM_TeleportToHint then return end
    if not istable(bot.TF_MVM_TeleportWhere) then return end

    local candidates = {}
    for _, hintName in ipairs(bot.TF_MVM_TeleportWhere) do
        if not isstring(hintName) then continue end
        for _, ent in ipairs(ents.FindByName(hintName)) do
            if IsValid(ent) then
                candidates[#candidates + 1] = ent
            end
        end
    end
    if #candidates <= 0 then return end

    local pick = table.Random(candidates)
    if not IsValid(pick) then return end
    bot:SetPos(pick:GetPos())
    bot:SetAngles(pick:GetAngles())
end

local function ApplyClassIcon(bot, def)
    if not IsValid(bot) or not istable(def) then return end
    local icon = string.Trim(tostring(ScalarValue(def.ClassIcon) or ""))
    if icon == "" then
        icon = string.Trim(tostring(ScalarValue(def.Icon) or ""))
    end
    if icon ~= "" then
        bot:SetNWString("TF_MVM_ClassIcon", icon)
        bot.TF_MVM_ClassIcon = icon
    end
end

local function ApplyWeaponRestrictionSelection(bot, restriction)
    if not IsValid(bot) then return end
    if restriction == "meleeonly" then
        ForceSelectMelee(bot)
        return
    end
    if restriction == "primaryonly" then
        ForceSelectWeaponSlot(bot, 0)
        return
    end
    if restriction == "secondaryonly" then
        ForceSelectWeaponSlot(bot, 1)
    end
end

local function BuildAppliedDef(baseDef, runtimeDefaultEventDef, popDefaultEventDef)
    if istable(runtimeDefaultEventDef) then
        return runtimeDefaultEventDef
    end
    if istable(popDefaultEventDef) then
        return popDefaultEventDef
    end
    return baseDef
end

local function GetValveAIBackend()
    local cv = GetConVar("tf_bot_valve_ai_backend")
    if not cv then return "player" end
    local v = string.lower(tostring(cv:GetString() or "player"))
    if v ~= "player" and v ~= "nextbot" and v ~= "hybrid" then
        v = "player"
    end
    return v
end

local function ShouldUseNextBotSpawner()
    local forcePlayer = GetConVar("tf_mvm_force_player_bots")
    if forcePlayer == nil then
        CreateConVar("tf_mvm_force_player_bots", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Force MvM spawner to use player bots instead of tf_bot_base_nextbot.")
        forcePlayer = GetConVar("tf_mvm_force_player_bots")
    end
    if forcePlayer and forcePlayer:GetBool() then
        return false
    end

    local enabled = GetConVar("tf_bot_valve_ai_enable")
    if enabled and not enabled:GetBool() then
        return false
    end
    local backend = GetValveAIBackend()
    return backend == "nextbot" or backend == "hybrid"
end

function SPAWNER:SpawnTFBot(runtime, rawDef, spawnState, whereOverride, missionId, fixedSpawnEnt, selectorState, randomSpawn, spawnPosOverride)
    local def = self:BuildBotDef(runtime, rawDef)
    local eventDefs = ParseEventChangeAttributes(def.EventChangeAttributes or def.eventchangeattributes)
    local runtimeDefaultEventName = runtime and runtime.GetDefaultEventChangeAttributesName and runtime:GetDefaultEventChangeAttributesName() or nil
    local runtimeDefaultEventDef = runtimeDefaultEventName and eventDefs[string.Trim(string.lower(tostring(runtimeDefaultEventName)))] or nil
    local appliedDef = BuildAppliedDef(def, runtimeDefaultEventDef, eventDefs["default"])

    local botClass = NormalizeClass(def.Class or "scout")
    local displayName = NormalizeDisplayBotName(def.Name or def.Class or "MvM Bot")
    local botName = displayName

    local spawnClassHint = def.SpawnClassHint and tostring(def.SpawnClassHint) or botClass
    local spawnEnt = fixedSpawnEnt
    if not IsValid(spawnEnt) then
        local useRandom = randomSpawn
        if useRandom == nil then
            useRandom = true
        end
        spawnEnt = self:PickSpawnEntity(SpawnWhereField(def, whereOverride), spawnClassHint, selectorState, useRandom)
    end
    if not IsValid(spawnEnt) and not isvector(spawnPosOverride) then
        return nil, "no_spawnpoint"
    end
    local spawnPos = isvector(spawnPosOverride)
        and Vector(spawnPosOverride.x, spawnPosOverride.y, spawnPosOverride.z + 8)
        or ResolveSafeSpawnPos(spawnEnt, BoolValue(def.ClosestPoint or def.closestpoint, false))
    local spawnAng = IsValid(spawnEnt) and spawnEnt:GetAngles() or Angle(0, 0, 0)

    local useNextBotBase = ShouldUseNextBotSpawner()
    local bot
    if useNextBotBase then
        bot = ents.Create("tf_bot_base_nextbot")
        if not IsValid(bot) then
            return nil, "failed_create_nextbot_base"
        end
        bot:SetPos(spawnPos)
        bot:SetAngles(spawnAng)
        bot:Spawn()
        bot:Activate()
    else
        bot = TF_CreateManagedMapBot(botName, TEAM_BLU, botClass, spawnPos, spawnAng, {
            useTeamSpawn = false,
            TFBotMapOwned = true,
        })
        if not IsValid(bot) then
            return nil, "player_limit"
        end
    end

    bot.TFBot = true
    bot.IsL4DZombie = false
    bot.IsMVMRobot = true
    -- Keep runtime team valid for all GMod systems.
    bot:SetTeam(TEAM_BLU)
    if bot.SetSkin then
        bot:SetSkin(1)
    end
    bot:SetPos(spawnPos)
    bot:SetAngles(spawnAng)
    bot:SetPlayerClass(botClass)
    bot.Difficulty = NormalizeDifficulty(appliedDef.Skill or def.Skill)
    bot.TF_MVM_IsGateBot = IsGateBotDef(def)
    bot:SetNWBool("TF_MVM_GateBot", bot.TF_MVM_IsGateBot and true or false)
    bot.TF_MVM_WeaponRestriction = NormalizeWeaponRestriction(appliedDef or def)
    bot.TF_MVM_Objective = TrimLower(def.Objective or "")
    bot.TF_MVM_MissionId = missionId
    bot:SetNWString("TF_MVM_Objective", bot.TF_MVM_Objective or "")
    bot:SetNWString("TF_BotDisplayName", displayName)
    bot.TF_MVM_EventChangeDefs = eventDefs
    bot.TF_MVM_DefaultDynamicDef = eventDefs["default"]
    bot.TF_MVM_ApplyEventChangeAttributes = function(ent, eventName)
        return SPAWNER:ApplyBotEventChange(ent, eventName)
    end

    local tagSet, tagList = BuildTagSet(appliedDef.Tag or appliedDef.Tags or def.Tag or def.Tags)
    bot.TF_MVM_Tags = tagSet
    bot.TF_MVM_TagList = tagList

    ApplyClassIcon(bot, appliedDef)
    ApplyHealthAndScale(bot, appliedDef)
    ApplyViewAndMovementHints(bot, appliedDef)

    if not useNextBotBase and not IsValid(bot.ControllerBot) then
        bot.ControllerBot = ents.Create("ctf_bot_navigator")
        if IsValid(bot.ControllerBot) then
            bot.ControllerBot:Spawn()
            bot.ControllerBot:SetOwner(bot)
        end
    end

    timer.Simple(0.15, function()
        if not IsValid(bot) then return end
        bot:SetPlayerClass(botClass)
        bot.Difficulty = NormalizeDifficulty(appliedDef.Skill or def.Skill)
        bot.TF_MVM_WeaponRestriction = NormalizeWeaponRestriction(appliedDef or def)
        ApplyBehaviorModifiers(bot, appliedDef.BehaviorModifiers)
        ApplyBotAttributes(bot, appliedDef.Attributes)
        if IsMiniBossAttrList(appliedDef.Attributes) then
            local bossModel = BOSS_MODEL_BY_CLASS[botClass]
            if bossModel then
                bot:SetModel(bossModel)
            end
        end
        ApplyMiniBossSpeedFromAttrs(bot, appliedDef.Attributes)
        if HasDefinedItems(appliedDef.Item) then
            ApplyBotItems(bot, appliedDef.Item)
            if bot.IsTFBotValveBase and bot.ApplyItemLoadout then
                bot:ApplyItemLoadout(ToArray(appliedDef.Item))
            end
        else
            ApplyDefaultWeaponsFromName(bot, botClass, displayName)
            if bot.IsTFBotValveBase and bot.BuildDefaultClassLoadout then
                bot:BuildDefaultClassLoadout()
                bot:RefreshWeaponAttachment()
            end
        end
        ApplyRomevisionPromoToBot(bot)
        ApplyWeaponRestrictionSelection(bot, bot.TF_MVM_WeaponRestriction)
        ApplyTeleportToHintIfRequested(bot)
        -- POP support: apply CharacterAttributes and ItemAttributes to spawned bot weapons.
        ApplyCharacterAndItemAttributes(bot, appliedDef)
        timer.Simple(0, function()
            if IsValid(bot) then
                ApplyRomevisionPromoToBot(bot)
                ApplyCharacterAndItemAttributes(bot, appliedDef)
                ApplyWeaponRestrictionSelection(bot, bot.TF_MVM_WeaponRestriction)
                ClampDemoMvMMovement(bot)
            end
        end)
        if bot.SetMaxSpeed then
            bot:SetMaxSpeed(GetBotClassBaseSpeed(bot))
        end
    end)

    if runtime and runtime.RegisterManagedBot then
        runtime:RegisterManagedBot(bot, spawnState, def, missionId)
    end

    return bot
end

function SPAWNER:ApplyBotEventChange(bot, eventName)
    if not IsValid(bot) then return false, "invalid_bot" end
    local defs = bot.TF_MVM_EventChangeDefs
    if not istable(defs) then return false, "no_event_defs" end

    local key = TrimLower(eventName)
    if key == "" then return false, "empty_event" end

    local eventDef = defs[key]
    if not istable(eventDef) then
        return false, "unknown_event"
    end

    if eventDef.Skill ~= nil then
        bot.Difficulty = NormalizeDifficulty(eventDef.Skill)
    elseif bot.Difficulty == nil then
        bot.Difficulty = NormalizeDifficulty("normal")
    end
    bot.TF_MVM_WeaponRestriction = NormalizeWeaponRestriction(eventDef) or bot.TF_MVM_WeaponRestriction

    ApplyBehaviorModifiers(bot, eventDef.BehaviorModifiers)
    ApplyBotAttributes(bot, eventDef.Attributes)
    ApplyHealthAndScale(bot, eventDef)
    ApplyViewAndMovementHints(bot, eventDef)
    ApplyClassIcon(bot, eventDef)

    local tagSet, tagList = BuildTagSet(eventDef.Tag or eventDef.Tags)
    if next(tagSet) ~= nil then
        bot.TF_MVM_Tags = tagSet
        bot.TF_MVM_TagList = tagList
    end

    if HasDefinedItems(eventDef.Item) then
        ApplyBotItems(bot, eventDef.Item)
        if bot.IsTFBotValveBase and bot.ApplyItemLoadout then
            bot:ApplyItemLoadout(ToArray(eventDef.Item))
        end
    end

    ApplyWeaponRestrictionSelection(bot, bot.TF_MVM_WeaponRestriction)
    ApplyCharacterAndItemAttributes(bot, eventDef)
    timer.Simple(0, function()
        if not IsValid(bot) then return end
        ApplyCharacterAndItemAttributes(bot, eventDef)
        ApplyWeaponRestrictionSelection(bot, bot.TF_MVM_WeaponRestriction)
        ApplyTeleportToHintIfRequested(bot)
        ClampDemoMvMMovement(bot)
    end)

    return true
end

function SPAWNER:SpawnTank(runtime, rawDef, spawnState, fixedSpawnEnt, selectorState, randomSpawn, spawnPosOverride)
    local def = self:BuildBotDef(runtime, rawDef)

    local spawnEnt = fixedSpawnEnt
    if not IsValid(spawnEnt) then
        local useRandom = randomSpawn
        if useRandom == nil then
            useRandom = true
        end
        spawnEnt = self:PickSpawnEntity(SpawnWhereField(def), "tank", selectorState, useRandom)
    end
    local tank = ents.Create("tank_boss")
    if not IsValid(tank) then
        return nil, "failed_create_tank"
    end

    tank.MvMManaged = true
    tank.MvMPathTrackName = tostring(ScalarValue(def.StartingPathTrackNode or def.PathTrack or def.path_track or def.PathTrackName) or "")
    tank.MvMTankHealth = NumValue(def.Health or def.MaxHealth, 10000)
    tank.MvMMoveSpeed = NumValue(def.Speed or def.MoveSpeed, 75)
    tank.MvMSkin = math.max(0, math.floor(NumValue(def.Skin, 0) or 0))
    tank.MvMOnSpawnOutput = def.OnSpawnOutput
    tank.MvMOnKilledOutput = def.OnKilledOutput
    tank.MvMOnBombDroppedOutput = def.OnBombDroppedOutput

    if IsValid(spawnEnt) then
        tank:SetPos(spawnEnt:GetPos())
        tank:SetAngles(spawnEnt:GetAngles())
    elseif isvector(spawnPosOverride) then
        tank:SetPos(spawnPosOverride)
        tank:SetAngles(Angle(0, 0, 0))
    end

    if runtime then
        tank.MvMOnDestroyed = function(ent, attacker)
            if runtime.OnManagedTankDestroyed then
                runtime:OnManagedTankDestroyed(spawnState, ent, attacker)
            end
        end

        tank.MvMOnDeploy = function(ent)
            if runtime.OnManagedTankDeployed then
                runtime:OnManagedTankDeployed(spawnState, ent)
            end
        end
    end

    tank:Spawn()

    if runtime and runtime.RegisterManagedTank then
        runtime:RegisterManagedTank(tank, spawnState, def)
    end

    return tank
end

function SPAWNER:SpawnSentryGun(runtime, rawDef, spawnState, fixedSpawnEnt, selectorState, randomSpawn, spawnPosOverride)
    local def = self:BuildBotDef(runtime, rawDef)

    local spawnEnt = fixedSpawnEnt
    if not IsValid(spawnEnt) then
        local useRandom = randomSpawn
        if useRandom == nil then
            useRandom = true
        end
        spawnEnt = self:PickSpawnEntity(SpawnWhereField(def), "sentrygun", selectorState, useRandom)
    end
    if not IsValid(spawnEnt) and not isvector(spawnPosOverride) then
        return nil, "no_spawnpoint"
    end

    local pos = isvector(spawnPosOverride)
        and Vector(spawnPosOverride.x, spawnPosOverride.y, spawnPosOverride.z + 8)
        or ResolveSafeSpawnPos(spawnEnt, BoolValue(def.ClosestPoint or def.closestpoint, false))
    local ang = IsValid(spawnEnt) and spawnEnt:GetAngles() or Angle(0, 0, 0)
    local sentry = ents.Create("obj_sentrygun")
    if not IsValid(sentry) then
        return nil, "failed_create_sentry"
    end

    sentry:SetPos(pos)
    sentry:SetAngles(ang)
    sentry:Spawn()
    if sentry.ChangeTeam then
        sentry:ChangeTeam(TEAM_RED)
    elseif sentry.SetTeam then
        sentry:SetTeam(TEAM_RED)
    end

    local level = math.max(0, math.floor(NumValue(def.Level, 0) or 0))
    if sentry.m_nDefaultUpgradeLevel ~= nil then
        sentry.m_nDefaultUpgradeLevel = level + 1
    end
    if sentry.InitializeMapPlacedObject then
        sentry:InitializeMapPlacedObject()
    end

    if runtime and runtime.RegisterManagedEntity then
        runtime:RegisterManagedEntity(sentry, spawnState, def, "sentrygun")
    end

    return sentry
end

function SPAWNER:SpawnMissionBot(runtime, missionDef, missionId)
    missionDef = missionDef or {}

    local rawBot = missionDef.TFBot and table.Random(ToArray(missionDef.TFBot)) or {}
    if not istable(rawBot) then
        rawBot = {}
    end

    local className = ResolveMissionClass(missionDef, rawBot)
    if not isstring(className) or className == "" then
        className = NormalizeClass(rawBot.Class or rawBot.class or missionDef.Class or missionDef.class or "scout")
    end
    local botDef = Merge(rawBot, {
        Name = missionDef.Name or missionDef.name or missionDef.Class or missionDef.class or className or rawBot.Class or rawBot.class or "MvM Bot",
        Skill = missionDef.Skill or rawBot.Skill or "expert",
        Objective = missionDef.Objective or missionDef.objective,
        Attributes = missionDef.Attributes or missionDef.attributes,
        BehaviorModifiers = missionDef.BehaviorModifiers,
        CharacterAttributes = missionDef.CharacterAttributes or missionDef.characterattributes,
        ItemAttributes = missionDef.ItemAttributes or missionDef.itemattributes,
        EventChangeAttributes = missionDef.EventChangeAttributes or missionDef.eventchangeattributes,
        WeaponRestrictions = missionDef.WeaponRestrictions,
        MaxVisionRange = missionDef.MaxVisionRange,
        TeleportWhere = missionDef.TeleportWhere,
        AutoJumpMin = missionDef.AutoJumpMin,
        AutoJumpMax = missionDef.AutoJumpMax,
        Scale = missionDef.Scale,
        Health = missionDef.Health,
        ClassIcon = missionDef.ClassIcon or missionDef.classicon or missionDef.Icon or missionDef.icon,
        Tag = missionDef.Tag or missionDef.Tags,
        Item = missionDef.Item,
        Where = missionDef.Where,
    })
    if className and className ~= "" then
        botDef.Class = className
    end
    local objective = string.lower(tostring(ScalarValue(missionDef.Objective or missionDef.objective) or ""))
    if objective == "destroysentries" or objective == "sentrybuster" then
        botDef.Class = "sentrybuster"
        botDef.Name = botDef.Name or "Sentry Buster"
        botDef.Objective = "DestroySentries"
        botDef.BehaviorModifiers = Merge(botDef.BehaviorModifiers or {}, {"Mobber"})
    end

    return self:SpawnTFBot(runtime, botDef, nil, missionDef.Where, missionId)
end

do
    local nextRefreshAt = 0

    hook.Add("Think", "TF_MVM_RomevisionSync", function()
        local now = CurTime()
        if now < nextRefreshAt then return end
        nextRefreshAt = now + 1
        RefreshMvMRomevisionState()
    end)

    hook.Add("PlayerInitialSpawn", "TF_MVM_RomevisionInitialOffer", function(ply)
        timer.Simple(2, function()
            if not IsValid(ply) then return end
            SendCurrentRomevisionOffersToPlayer(ply)
        end)
    end)
end

return SPAWNER

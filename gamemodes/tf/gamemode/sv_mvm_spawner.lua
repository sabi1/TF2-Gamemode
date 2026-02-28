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
    destroysentries = "demoman",
    sentrybuster = "demoman",
}

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
    local explicitClass = NormalizeClass(ScalarValue(missionDef.Class) or "")
    if explicitClass ~= "" then
        return explicitClass
    end

    if istable(rawBot) and rawBot.Class then
        local rawClass = NormalizeClass(rawBot.Class)
        if rawClass ~= "" then
            return rawClass
        end
    end

    local objective = string.lower(tostring(ScalarValue(missionDef.Objective) or ""))
    return OBJECTIVE_CLASS[objective]
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
            local kv = ent.GetKeyValues and ent:GetKeyValues() or nil
            local team = kv and tonumber(kv.TeamNum or kv.teamnum or 0) or 0
            if team == TEAM_BLU or team == TF_TEAM_PVE_INVADERS or team == 3 then
                out[#out + 1] = ent
            end
        end
    end

    return out
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

    return table.Random(candidates)
end

function SPAWNER:ResolveSpawnEntity(whereField, classHint)
    local candidates = self:ResolveSpawnEntities(whereField, classHint)
    if #candidates == 0 then
        return nil
    end
    return table.Random(candidates)
end

local function ApplyBotAttributes(bot, attrs)
    for _, attr in ipairs(ToArray(attrs)) do
        local lower = string.lower(tostring(attr))

        if lower == "alwayscrit" then
            bot.AlwaysCrit = true
        elseif lower == "disablejump" then
            bot:SetJumpPower(0)
        elseif lower == "holdfireuntilclose" then
            bot.HoldFireUntilClose = true
        elseif lower == "aggressive" then
            bot.Aggressive = true
        elseif lower == "noattack" then
            bot.NoAttack = true
        elseif lower == "spawnwithfullcharge" then
            bot:SetNWInt("Ubercharge", 100)
        elseif lower == "mini-boss" or lower == "miniboss" then
            bot:SetModelScale(1.75)
            bot.IsBoss = true
            bot:SetNWBool("IsBoss", true)
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
    return nil
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
    for _, item in ipairs(ToArray(items)) do
        if not IsValid(bot) then return end

        if bot.EquipInLoadout then
            bot:EquipInLoadout(string.Replace(item,"the ", ""))
        elseif isstring(item) then
            local weaponClass = item
            if not string.StartWith(weaponClass, "tf_weapon_") then
                weaponClass = "tf_weapon_" .. string.lower(weaponClass)
            end
            bot:Give(weaponClass)
        end
    end
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
    sentrybuster = "demoman",
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

function SPAWNER:SpawnTFBot(runtime, rawDef, spawnState, whereOverride, missionId, fixedSpawnEnt)
    local def = self:BuildBotDef(runtime, rawDef)

    local botClass = NormalizeClass(def.Class or "scout")
    local displayName = NormalizeDisplayBotName(def.Name or def.Class or "MvM Bot")
    local botName = displayName

    local spawnClassHint = def.SpawnClassHint and tostring(def.SpawnClassHint) or botClass
    local spawnEnt = fixedSpawnEnt
    if not IsValid(spawnEnt) then
        spawnEnt = self:PickSpawnEntity(whereOverride or def.Where, spawnClassHint, nil, true)
    end
    if not IsValid(spawnEnt) then
        return nil, "no_spawnpoint"
    end

    local bot = player.CreateNextBot(botName)
    if not IsValid(bot) then
        return nil, "player_limit"
    end

    bot.TFBot = true
    bot.IsL4DZombie = false
    bot.IsMVMRobot = true
    -- Keep runtime team valid for all GMod systems.
    bot:SetTeam(TEAM_BLU)
    bot:SetSkin(1)
    bot:SetPos(spawnEnt:GetPos())
    bot:SetAngles(spawnEnt:GetAngles())
    bot:SetPlayerClass(botClass)
    bot.Difficulty = NormalizeDifficulty(def.Skill)
    bot.TF_MVM_IsGateBot = IsGateBotDef(def)
    bot:SetNWBool("TF_MVM_GateBot", bot.TF_MVM_IsGateBot and true or false)
    bot.TF_MVM_WeaponRestriction = NormalizeWeaponRestriction(def)
    bot:SetNWString("TF_BotDisplayName", displayName)
    bot.ControllerBot = ents.Create("ctf_bot_navigator")
    if IsValid(bot.ControllerBot) then
        bot.ControllerBot:Spawn()
        bot.ControllerBot:SetOwner(bot)
    end

    timer.Simple(0.15, function()
        if not IsValid(bot) then return end
        bot:SetPlayerClass(botClass)
        ApplyBotAttributes(bot, def.Attributes)
        if IsMiniBossAttrList(def.Attributes) then
            local bossModel = BOSS_MODEL_BY_CLASS[botClass]
            if bossModel then
                bot:SetModel(bossModel)
            end
        end
        ApplyMiniBossSpeedFromAttrs(bot, def.Attributes)
        if HasDefinedItems(def.Item) then
            ApplyBotItems(bot, def.Item)
        else
            ApplyDefaultWeaponsFromName(bot, botClass, displayName)
        end
        -- POP support: apply CharacterAttributes and ItemAttributes to spawned bot weapons.
        ApplyCharacterAndItemAttributes(bot, def)
        timer.Simple(0, function()
            if IsValid(bot) then
                ApplyCharacterAndItemAttributes(bot, def)
            end
        end)
        if bot.TF_MVM_WeaponRestriction == "meleeonly" then
            ForceSelectMelee(bot)
        end
        bot:SetMaxSpeed(520)
    end)

    if runtime and runtime.RegisterManagedBot then
        runtime:RegisterManagedBot(bot, spawnState, def, missionId)
    end

    return bot
end

function SPAWNER:SpawnTank(runtime, rawDef, spawnState, fixedSpawnEnt)
    local def = self:BuildBotDef(runtime, rawDef)

    local spawnEnt = fixedSpawnEnt
    if not IsValid(spawnEnt) then
        spawnEnt = self:ResolveSpawnEntity(def.Where, "tank")
    end
    local tank = ents.Create("tank_boss")
    if not IsValid(tank) then
        return nil, "failed_create_tank"
    end

    tank.MvMManaged = true
    tank.MvMPathTrackName = tostring(ScalarValue(def.PathTrack or def.path_track or def.PathTrackName) or "")
    tank.MvMTankHealth = NumValue(def.Health or def.MaxHealth, 10000)
    tank.MvMMoveSpeed = NumValue(def.Speed or def.MoveSpeed, 75)
    tank.MvMOnKilledOutput = def.OnKilledOutput
    tank.MvMOnBombDroppedOutput = def.OnBombDroppedOutput

    if IsValid(spawnEnt) then
        tank:SetPos(spawnEnt:GetPos())
        tank:SetAngles(spawnEnt:GetAngles())
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

function SPAWNER:SpawnMissionBot(runtime, missionDef, missionId)
    missionDef = missionDef or {}

    local rawBot = missionDef.TFBot and table.Random(ToArray(missionDef.TFBot)) or {}
    if not istable(rawBot) then
        rawBot = {}
    end

    local className = ResolveMissionClass(missionDef, rawBot)
    if not isstring(className) or className == "" then
        className = NormalizeClass(rawBot.Class or missionDef.Class or "scout")
    end
    local botDef = Merge(rawBot, {
        Name = missionDef.Name or missionDef.Class or className or rawBot.Class or "MvM Bot",
        Skill = missionDef.Skill or rawBot.Skill or "expert",
        Attributes = missionDef.Attributes,
        CharacterAttributes = missionDef.CharacterAttributes or missionDef.characterattributes,
        ItemAttributes = missionDef.ItemAttributes or missionDef.itemattributes,
        WeaponRestrictions = missionDef.WeaponRestrictions,
        Item = missionDef.Item,
        Where = missionDef.Where,
    })
    if className and className ~= "" then
        botDef.Class = className
    end
    local objective = string.lower(tostring(ScalarValue(missionDef.Objective) or ""))
    if objective == "destroysentries" or objective == "sentrybuster" then
        return
    end

    return self:SpawnTFBot(runtime, botDef, nil, missionDef.Where, missionId)
end

return SPAWNER

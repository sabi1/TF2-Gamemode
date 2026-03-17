local meta = FindMetaTable("Player")

local LOADOUT_SLOT_COUNT = 7
local VALID_LOADOUT_CLASSES = {
    scout = true,
    soldier = true,
    pyro = true,
    demoman = true,
    heavy = true,
    engineer = true,
    medic = true,
    sniper = true,
    spy = true,
}

local function GetClassLoadoutSlotCount(className)
    className = string.lower(tostring(className or ""))
    if className == "engineer" or className == "spy" then
        return 8
    end
    return LOADOUT_SLOT_COUNT
end

if SERVER then
    util.AddNetworkString("TF_UpdateLoadoutProperties")
    CreateConVar("tf_debug_item_visuals", "0", {FCVAR_ARCHIVE}, "Debug Steam->loadout->item visual attribute flow.")
end

local function normalizeLoadout(split, className)
    local normalized = {}
    local slotCount = GetClassLoadoutSlotCount(className)
    for i = 1, slotCount do
        normalized[i] = split[i] or "-1"
    end
    return normalized
end

local function sanitizeAttributes(rawAttributes)
    if not istable(rawAttributes) then return nil end
    local out = {}
    for _, pair in ipairs(rawAttributes) do
        local id = tonumber(pair and pair[1])
        local value = tonumber(pair and pair[2])
        if id and value then
            out[#out + 1] = {id, value}
        end
    end
    if #out == 0 then return nil end
    return out
end

local function ItemVisualDebugEnabled()
    local c = GetConVar("tf_debug_item_visuals")
    return c and c:GetBool() or false
end

local function FindAttrInPairList(pairsList, attrId)
    if not istable(pairsList) then return nil end
    for _, pair in ipairs(pairsList) do
        if istable(pair) and tonumber(pair[1]) == tonumber(attrId) then
            return pair[2]
        end
    end
    return nil
end

local function sanitizeSlotProperties(raw)
    if not istable(raw) then return nil end
    local out = {}
    if raw.defindex ~= nil then
        local d = tonumber(raw.defindex)
        if d then out.defindex = d end
    end
    if raw.quality ~= nil then
        local q = tonumber(raw.quality)
        if q then out.quality = q end
    end
    if raw.level ~= nil then
        local l = tonumber(raw.level)
        if l then out.level = l end
    end
    if isstring(raw.custom_name) and raw.custom_name ~= "" then
        out.custom_name = string.sub(raw.custom_name, 1, 80)
    end
    if isstring(raw.custom_desc) and raw.custom_desc ~= "" then
        out.custom_desc = string.sub(raw.custom_desc, 1, 256)
    end
    local attrs = sanitizeAttributes(raw.attributes)
    if attrs then
        out.attributes = attrs
    end
    if next(out) == nil then return nil end
    return out
end

if SERVER then
    net.Receive("TF_UpdateLoadoutProperties", function(_, ply)
        if not IsValid(ply) then return end
        local payload = net.ReadTable()
        if not istable(payload) then return end

        local cleaned = {}
        for className, slots in pairs(payload) do
            if VALID_LOADOUT_CLASSES[className] and istable(slots) then
                cleaned[className] = {}
                local slotCount = GetClassLoadoutSlotCount(className)
                for i = 1, slotCount do
                    cleaned[className][i] = sanitizeSlotProperties(slots[i])
                    if ItemVisualDebugEnabled() and cleaned[className][i] and cleaned[className][i].attributes then
                        local attrs = cleaned[className][i].attributes
                        local paintkit = FindAttrInPairList(attrs, 834)
                        local wear = FindAttrInPairList(attrs, 725)
                        local festive = FindAttrInPairList(attrs, 2053)
                        if paintkit ~= nil or wear ~= nil or festive ~= nil then
                            print(string.format(
                                "[tf_debug_item_visuals] SVLoadoutReceive ply=%s class=%s slot=%d defindex=%s paintkit=%s wear=%s festive=%s",
                                tostring(IsValid(ply) and ply:Nick() or "nil"),
                                tostring(className),
                                i,
                                tostring(cleaned[className][i].defindex),
                                tostring(paintkit),
                                tostring(wear),
                                tostring(festive)
                            ))
                        end
                    end
                end
            end
        end
        ply.TFLoadoutProperties = cleaned
    end)
end

function meta:GiveLoadout()
    local playerClass = self:GetPlayerClass()
    local classTable = GAMEMODE and GAMEMODE.PlayerClasses and GAMEMODE.PlayerClasses[playerClass] or nil
    local convar = "loadout_" .. self:GetPlayerClass()
    local defaultLoadout = "-1,-1,-1,-1,-1,-1,-1"
    if playerClass == "engineer" or playerClass == "spy" then
        defaultLoadout = "-1,-1,-1,-1,-1,-1,-1,-1"
    end
    local split = normalizeLoadout(string.Split(self:GetInfo(convar, defaultLoadout), ","), playerClass)
    local classProperties = self.TFLoadoutProperties and self.TFLoadoutProperties[playerClass] or nil
    local playerModel = self.GetModel and self:GetModel() or ""

    -- Match TF2's equip flow: build desired loadout state first, then equip in one pass.
    if istable(classTable) and istable(classTable.DefaultLoadout) then
        self.ItemLoadout = table.Copy(classTable.DefaultLoadout)
        self.ItemProperties = {}
        for i = 1, #self.ItemLoadout do
            self.ItemProperties[i] = {}
        end
    else
        self.ItemLoadout = {}
        self.ItemProperties = {}
    end

	for slotIndex, id in ipairs(split) do
        id = tonumber(id)
        local itemname = nil
        local itemDef = id and tf_items.ItemsByID and tf_items.ItemsByID[id] or nil
        if istable(itemDef) then
            if not (isstring(playerModel) and string.find(playerModel, "/player/touhou/", 1, true) and itemDef.item_class == "tf_wearable_item") then
                itemname = itemDef.name
            end
        elseif id then
            -- Fallback for older schema states where ItemsByID is incomplete.
            for name, wep in pairs(tf_items.Items) do
                if istable(wep) and tonumber(wep.id) == id then
                    if not (isstring(playerModel) and string.find(playerModel, "/player/touhou/", 1, true) and wep.item_class == "tf_wearable_item") then
                        itemname = name
                    end
                    break
                end
            end
        end
        if itemname then
            local slotProps = classProperties and classProperties[slotIndex] or nil
            if slotProps and slotProps.defindex and slotProps.defindex ~= id then
                slotProps = nil
            end
            if ItemVisualDebugEnabled() and slotProps and slotProps.attributes then
                local paintkit = FindAttrInPairList(slotProps.attributes, 834)
                local wear = FindAttrInPairList(slotProps.attributes, 725)
                local festive = FindAttrInPairList(slotProps.attributes, 2053)
                if paintkit ~= nil or wear ~= nil or festive ~= nil then
                    print(string.format(
                        "[tf_debug_item_visuals] GiveLoadoutApply ply=%s class=%s slot=%d defindex=%s item=%s paintkit=%s wear=%s festive=%s",
                        tostring(self:Nick()),
                        tostring(playerClass),
                        slotIndex,
                        tostring(id),
                        tostring(itemname),
                        tostring(paintkit),
                        tostring(wear),
                        tostring(festive)
                    ))
                end
            end
            self:EquipInLoadout(itemname, slotProps, true)
            --tf_items.CC_GiveItem(self, _, {itemname})
            --self:ConCommand("__svgiveitem", itemname) --id)
        end
	end

	if playerClass == "spy" then
		self:SetNWFloat("SpyCloakMeter", 100)
		local invis = self:GetWeapon("tf_weapon_invis")
		if IsValid(invis) and invis.SetCloakMeter then
			invis:SetCloakMeter(100)
		end
	end

	if self:Alive() then
		self:SetPlayerClass(playerClass)
	end

    timer.Simple(0.3, function()
		if not IsValid(self) then return end
    
		if (!self:IsL4D()) then
		
			if (self:GetInfoNum("tf_give_hl2_weapons",0) == 1 && (!GetConVar("tf_competitive"):GetBool() || self:IsAdmin())) then
				self:Give("weapon_physgun")
                
				self:Give("weapon_physcannon")
				self:Give("gmod_tool")
				self:Give("gmod_camera")
			end
				
		end
    end)
end

concommand.Add("loadout_update", function(ply)
    ply:Spawn()
    return true

end) 

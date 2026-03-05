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

if SERVER then
    util.AddNetworkString("TF_UpdateLoadoutProperties")
end

local function normalizeLoadout(split)
    local normalized = {}
    for i = 1, LOADOUT_SLOT_COUNT do
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
                for i = 1, LOADOUT_SLOT_COUNT do
                    cleaned[className][i] = sanitizeSlotProperties(slots[i])
                end
            end
        end
        ply.TFLoadoutProperties = cleaned
    end)
end

function meta:GiveLoadout()
    local playerClass = self:GetPlayerClass()
    local convar = "loadout_" .. self:GetPlayerClass()
    local split = normalizeLoadout(string.Split(self:GetInfo(convar, "-1,-1,-1,-1,-1,-1,-1"), ","))
    local classProperties = self.TFLoadoutProperties and self.TFLoadoutProperties[playerClass] or nil

    for slotIndex, id in ipairs(split) do
        id = tonumber(id)
        local itemname = nil
        -- oh no
        for name, wep in pairs(tf_items.Items) do
            if istable(wep) and wep.id == id then     
                if (IsValid(self.Owner) and string.find(self.Owner:GetModel(),"/player/touhou/") and wep.item_class == "tf_wearable_item") then

                else
                    itemname = name
                end
            end
        end
        if itemname then
            local slotProps = classProperties and classProperties[slotIndex] or nil
            if slotProps and slotProps.defindex and slotProps.defindex ~= id then
                slotProps = nil
            end
            self:EquipInLoadout(itemname, slotProps)
            --tf_items.CC_GiveItem(self, _, {itemname})
            --self:ConCommand("__svgiveitem", itemname) --id)
        end
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

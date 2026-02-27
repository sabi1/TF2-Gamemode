local meta = FindMetaTable("Player")

local LOADOUT_SLOT_COUNT = 7

local function normalizeLoadout(split)
    local normalized = {}
    for i = 1, LOADOUT_SLOT_COUNT do
        normalized[i] = split[i] or "-1"
    end
    return normalized
end

function meta:GiveLoadout()
    local convar = "loadout_" .. self:GetPlayerClass()
    local split = normalizeLoadout(string.Split(self:GetInfo(convar, "-1,-1,-1,-1,-1,-1,-1"), ","))

    for _, id in ipairs(split) do
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
            self:EquipInLoadout(itemname)
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

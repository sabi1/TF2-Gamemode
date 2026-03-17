ENT.Type = "point"

local function updateHybridState()
	local enabled = false
	for _, logic in ipairs(ents.FindByClass("tf_logic_hybrid_ctf_cp")) do
		if IsValid(logic) and not logic.Disabled then
			enabled = true
			break
		end
	end

	if GAMEMODE then
		GAMEMODE.IsHybridCTFCPMap = enabled
	end
	SetGlobalBool("tf_hybrid_ctf_cp_map", enabled)
end

function TF_IsHybridCTFCPMap()
	return GetGlobalBool("tf_hybrid_ctf_cp_map", false)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	self:SetNWBool("TFHybridCTFCPEnabled", true)
	timer.Simple(0, updateHybridState)
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Disabled = false
		self:SetNWBool("TFHybridCTFCPEnabled", true)
		updateHybridState()
		return true
	elseif name == "disable" then
		self.Disabled = true
		self:SetNWBool("TFHybridCTFCPEnabled", false)
		updateHybridState()
		return true
	elseif name == "roundspawn" or name == "roundactivate" then
		updateHybridState()
		return true
	end

	return false
end

hook.Add("EntityRemoved", "TFHybridCTFCP_EntityRemoved", function(ent)
	if not IsValid(ent) or ent:GetClass() ~= "tf_logic_hybrid_ctf_cp" then return end
	timer.Simple(0, updateHybridState)
end)

ENT.Type = "point"

local function updateMultipleEscortState()
	local enabled = false
	for _, logic in ipairs(ents.FindByClass("tf_logic_multiple_escort")) do
		if IsValid(logic) and not logic.Disabled then
			enabled = true
			break
		end
	end

	if GAMEMODE then
		GAMEMODE.IsMultipleEscortMap = enabled
	end
	SetGlobalBool("tf_multiple_escort_map", enabled)
end

function TF_IsMultipleEscortMap()
	return GetGlobalBool("tf_multiple_escort_map", false)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	self:SetNWBool("TFMultipleEscortEnabled", true)
	timer.Simple(0, updateMultipleEscortState)
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
		self:SetNWBool("TFMultipleEscortEnabled", true)
		updateMultipleEscortState()
		return true
	elseif name == "disable" then
		self.Disabled = true
		self:SetNWBool("TFMultipleEscortEnabled", false)
		updateMultipleEscortState()
		return true
	elseif name == "roundspawn" or name == "roundactivate" then
		updateMultipleEscortState()
		return true
	end

	return false
end

hook.Add("EntityRemoved", "TFMultipleEscort_EntityRemoved", function(ent)
	if not IsValid(ent) or ent:GetClass() ~= "tf_logic_multiple_escort" then return end
	timer.Simple(0, updateMultipleEscortState)
end)

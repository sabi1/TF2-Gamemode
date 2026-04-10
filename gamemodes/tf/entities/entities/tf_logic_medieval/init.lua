ENT.Type = "point"

local function updateMedievalState()
	local enabled = false
	for _, logic in ipairs(ents.FindByClass("tf_logic_medieval")) do
		if IsValid(logic) and not logic.Disabled then
			enabled = true
			break
		end
	end

	if GAMEMODE then
		GAMEMODE.IsMedievalMode = enabled
	end

	SetGlobalBool("tf_medieval_mode", enabled)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	timer.Simple(0, updateMedievalState)
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:InputEnable()
	self.Disabled = false
	updateMedievalState()
end

function ENT:InputDisable()
	self.Disabled = true
	updateMedievalState()
end

function ENT:InputRoundActivate()
	updateMedievalState()
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input" .. tostring(name or "")] or self["Input_" .. tostring(name or "")]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
	return false
end

hook.Add("EntityRemoved", "TF_MedievalLogic_Removed", function(ent)
	if not IsValid(ent) or ent:GetClass() ~= "tf_logic_medieval" then return end
	timer.Simple(0, updateMedievalState)
end)

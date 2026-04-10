ENT.Type = "point"

local function updateMannVsMachineState()
	local enabled = false

	for _, logic in ipairs(ents.FindByClass("tf_logic_mann_vs_machine")) do
		if IsValid(logic) and not logic.Disabled then
			enabled = true
			break
		end
	end

	if GAMEMODE then
		GAMEMODE.IsMannVsMachineMap = enabled
	end

	SetGlobalBool("tf_mann_vs_machine_map", enabled)
	SetGlobalBool("tf_mvm_mode", enabled)
end

function TF_IsMvMMap()
	return GetGlobalBool("tf_mann_vs_machine_map", false)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	self.NextPopfile = ""
	timer.Simple(0, updateMannVsMachineState)
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
	updateMannVsMachineState()
end

function ENT:InputDisable()
	self.Disabled = true
	updateMannVsMachineState()
end

function ENT:InputRoundActivate()
	updateMannVsMachineState()
end

function ENT:InputSetNextPopfile(_, _, data)
	self.NextPopfile = tostring(data or "")
	SetGlobalString("tf_mvm_next_popfile", self.NextPopfile)
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input" .. tostring(name or "")] or self["Input_" .. tostring(name or "")]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
	return false
end

hook.Add("EntityRemoved", "TF_MvMLogic_Removed", function(ent)
	if not IsValid(ent) or ent:GetClass() ~= "tf_logic_mann_vs_machine" then return end
	timer.Simple(0, updateMannVsMachineState)
end)

ENT.Type = "point"

local function updateRaidState()
	local enabled = false
	for _, logic in ipairs(ents.FindByClass("tf_logic_raid")) do
		if IsValid(logic) and not logic.Disabled then
			enabled = true
			break
		end
	end

	if GAMEMODE then
		GAMEMODE.IsRaidMap = enabled
	end

	SetGlobalBool("tf_raid_map", enabled)
end

function TF_IsRaidMap()
	return GetGlobalBool("tf_raid_map", false)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	timer.Simple(0, updateRaidState)
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
	updateRaidState()
end

function ENT:InputDisable()
	self.Disabled = true
	updateRaidState()
end

function ENT:InputRoundActivate()
	updateRaidState()
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input" .. tostring(name or "")] or self["Input_" .. tostring(name or "")]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
	return false
end

hook.Add("EntityRemoved", "TF_RaidLogic_Removed", function(ent)
	if not IsValid(ent) or ent:GetClass() ~= "tf_logic_raid" then return end
	timer.Simple(0, updateRaidState)
end)

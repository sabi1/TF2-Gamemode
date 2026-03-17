ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	if GAMEMODE then
		GAMEMODE.IsRaidMap = true
	end
	SetGlobalBool("tf_raid_map", true)
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
	return false
end

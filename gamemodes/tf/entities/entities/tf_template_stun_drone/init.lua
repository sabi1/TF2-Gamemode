ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:Instantiate()
	local stored = scripted_ents.GetStored("bot_npc_minion")
	if not stored then
		return nil
	end

	return ents.Create("bot_npc_minion")
end

function ENT:AcceptInput(name, activator, caller, data)
	return false
end

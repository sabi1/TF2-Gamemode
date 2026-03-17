ENT.Type = "point"

local function GetBase()
	local stored = scripted_ents.GetStored("tf_halloween_minigame")
	return stored and stored.t or nil
end

function ENT:Initialize()
	local base = GetBase()
	if base and base.Initialize then
		base.Initialize(self)
	else
		self.Properties = self.Properties or {}
	end
end

function ENT:KeyValue(key, value)
	local base = GetBase()
	if base and base.KeyValue then
		base.KeyValue(self, key, value)
		return
	end

	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:AcceptInput(name, activator, caller, data)
	local base = GetBase()
	if base and base.AcceptInput then
		return base.AcceptInput(self, name, activator, caller, data)
	end
	return false
end

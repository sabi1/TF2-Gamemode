ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = tonumber((self.Properties or {}).startdisabled or 0) == 1
end

function ENT:KeyValue(key, value)
	if string.Left(key, 2) == "On" then
		self:StoreOutput(key, value)
	end

	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "startdisabled" then
		self.Disabled = tonumber(value) == 1
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Disabled = false
		return true
	elseif name == "disable" then
		self.Disabled = true
		return true
	end
	return false
end

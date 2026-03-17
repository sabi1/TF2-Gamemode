ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	self:RefreshStateFromProperties()
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:RefreshStateFromProperties()
	self.Disabled = tonumber((self.Properties or {}).startdisabled or 0) == 1
end

function ENT:InputEnable()
	self.Disabled = false
end

function ENT:InputDisable()
	self.Disabled = true
end

function ENT:IsDisabled()
	return self.Disabled and true or false
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input" .. name] or self["Input_" .. name]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
end

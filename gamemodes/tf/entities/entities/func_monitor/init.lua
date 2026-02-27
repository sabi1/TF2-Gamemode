ENT.Base = "base_brush"
ENT.Type = "brush"

function ENT:Initialize()
	self.Properties = self.Properties or {}
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:StartTouch(ent)
end

function ENT:EndTouch(ent)
end

function ENT:AcceptInput(name, activator, caller, data)
end
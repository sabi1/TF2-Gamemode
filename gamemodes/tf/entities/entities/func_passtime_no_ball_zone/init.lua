ENT.Base = "base_brush"
ENT.Type = "brush"

function TF_PasstimeEntityInNoBallZone(target)
	if not IsValid(target) then return false end
	for _, zone in ipairs(ents.FindByClass("func_passtime_no_ball_zone")) do
		if IsValid(zone) and zone.Touching and zone.Touching[target] then
			return true
		end
	end
	return false
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Touching = {}
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
	if IsValid(ent) then
		self.Touching[ent] = true
	end
end

function ENT:EndTouch(ent)
	self.Touching[ent] = nil
end

function ENT:AcceptInput(name, activator, caller, data)
end

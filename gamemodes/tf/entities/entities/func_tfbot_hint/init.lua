ENT.Base = "base_brush"
ENT.Type = "brush"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	self.TeamNum = tonumber(self.Properties.team or 0) or 0
	self.HintType = tonumber(self.Properties.hint or -1) or -1
	self:InitTrigger()
	self:AddEffects(EF_NODRAW)
	self:SetNotSolid(true)
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "team" then
		self.TeamNum = tonumber(value or 0) or 0
	elseif key == "hint" then
		self.HintType = tonumber(value or -1) or -1
	elseif key == "startdisabled" then
		self.Disabled = tonumber(value or 0) ~= 0 or tostring(value) == "true"
	end
end

function ENT:IsEnabled()
	return not self.Disabled
end

function ENT:IsFor(bot)
	if not (IsValid(bot) and bot:IsPlayer()) then
		return false
	end
	if not self:IsEnabled() then
		return false
	end
	if (self.TeamNum or 0) > 0 and bot:Team() ~= self.TeamNum then
		return false
	end
	return true
end

function ENT:AcceptInput(name)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Disabled = false
		return true
	end
	if name == "disable" then
		self.Disabled = true
		return true
	end
	return false
end

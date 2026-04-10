ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	self.TeamNum = tonumber(self.Properties.team or 0) or 0
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
	elseif key == "startdisabled" then
		self.Disabled = tonumber(value or 0) ~= 0 or tostring(value) == "true"
	end
end

function ENT:IsEnabled()
	return not self.Disabled
end

function ENT:IsForTeam(teamNum)
	return self.TeamNum <= 0 or self.TeamNum == teamNum
end

function ENT:OwnerObjectHasNoOwner()
	local owner = self:GetOwner()
	if IsValid(owner) and owner.GetBuilder then
		local builder = owner.GetBuilder and owner:GetBuilder() or nil
		return not IsValid(builder)
	end
	return false
end

function ENT:OwnerObjectFinishBuilding()
	local owner = self:GetOwner()
	if IsValid(owner) and owner.GetBuilder and owner.IsBuilding then
		return not owner:IsBuilding()
	end
	return false
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

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.Name = "Sentry Gun Bot Hint"
ENT.Category = "Team Fortress 2"
ENT.Spawnable			= true
ENT.AdminOnly		= true

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Disabled")
	self:NetworkVar("Bool", 1, "Sticky")
end

function ENT:IsEnabled()
	return not self:GetDisabled()
end

function ENT:IsInUse()
	return (self._tfbotUseCount or 0) ~= 0
end

function ENT:GetPlayerOwner()
	return self._tfbotOwner
end

function ENT:SetPlayerOwner(owner)
	self._tfbotOwner = owner
end

function ENT:IncrementUseCount()
	self._tfbotUseCount = (self._tfbotUseCount or 0) + 1
end

function ENT:DecrementUseCount()
	self._tfbotUseCount = math.max((self._tfbotUseCount or 1) - 1, 0)
end

function ENT:OwnerObjectHasNoOwner()
	local owner = self:GetOwner()
	if IsValid(owner) and owner.GetBuilder then
		local builder = owner.GetBuilder and owner:GetBuilder() or nil
		return not IsValid(builder)
	end
	return false
end

function ENT:IsAvailableForSelection(requestingPlayer)
	local owner = self:GetPlayerOwner()
	local ownerClass = IsValid(owner) and owner.GetPlayerClass and string.lower(tostring(owner:GetPlayerClass() or "")) or ""
	local sameTeam = not IsValid(requestingPlayer) or self.TeamNum == nil or self.TeamNum <= 0 or requestingPlayer:Team() == self.TeamNum
	return (not IsValid(owner) or ownerClass ~= "engineer") and self:IsEnabled() and not self:IsInUse() and sameTeam
end

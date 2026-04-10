local TempVector = {1.0, 1.0, 1.0}

function PROXY:Init(mat, kv)
	if not mat or not mat.FindVar then
		self.Factor = nil
		self.Tint = nil
		self.Refract = nil
		return false
	end

	self.Factor = mat:FindVar("$cloakfactor")
	self.Tint = mat:FindVar("$cloakcolortint")
	self.Refract = mat:FindVar("$refractamount")

	if not self.Factor or not self.Tint or not self.Refract then
		return false
	end

	return true
end

function PROXY:OnBind(ent)
	if not self.Factor or not self.Tint or not self.Refract then return end
	if not IsValid(ent) then return end

	local owner = ent:GetOwner()
	if not IsValid(owner) then
		owner = (IsValid(ent.Player) and ent.Player) or ent
	end

	self.Factor:SetFloatValue(ent:GetProxyVar("CloakLevel") or 0)
	self.Refract:SetFloatValue(ent:GetProxyVar("CloakRefract") or 0.5)

	local tint = ent:GetProxyVar("CloakTint")
	if tint then
		TempVector[1] = tint[1]
		TempVector[2] = tint[2]
		TempVector[3] = tint[3]
	else
		TempVector[1] = 1.0
		TempVector[2] = 1.0
		TempVector[3] = 1.0
	end

	self.Tint:SetVecValue(TempVector, 3)
end

function PROXY:GetMaterial()
	if not self.Factor then return end
	return self.Factor:GetOwningMaterial()
end

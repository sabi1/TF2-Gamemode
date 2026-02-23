
local function ResolveRagdoll(pl)
	if not IsValid(pl) then return nil end
	if IsValid(pl.DeathRagdoll) then return pl.DeathRagdoll end
	if IsValid(pl.RagdollEntity) then return pl.RagdollEntity end
	if pl.GetNWEntity then
		local nw = pl:GetNWEntity("RagdollEntity")
		if IsValid(nw) then return nw end
	end
	local rag = pl:GetRagdollEntity()
	if IsValid(rag) then return rag end
	return nil
end

function EFFECT:AttachToPlayerRagdoll(pl)
	local rag = ResolveRagdoll(pl)
	if not IsValid(rag) then return false end

	self.Parent = rag
	self:SetParent(rag)
	return true
end

function EFFECT:Init(data)
	local hat = data:GetEntity()
	if not IsValid(hat) then return end
	local pl = hat:GetOwner()
	if not IsValid(pl) then return end
	self.OwnerRef = pl
	self.Parent = nil
	self.RetryUntil = CurTime() + 2

	local mdl = hat.Model
	if not mdl then
		self.Parent = nil
		return
	end
	
	if hat.GetItemTint then
		self.ItemTint = hat:GetItemTint()
	else
		self.ItemTint = 0
	end
	
	self:SetModel(mdl)
	self:AddEffects(EF_BONEMERGE)
	
	self:CopyVisualOverrides(hat)
	hat.InitVisuals(self, pl, hat:GetVisuals())
	self:AttachToPlayerRagdoll(pl)
end

function EFFECT:Think()
	if IsValid(self.Parent) then
		return true
	end

	if CurTime() > (self.RetryUntil or 0) then
		return false
	end

	if IsValid(self.OwnerRef) then
		self:AttachToPlayerRagdoll(self.OwnerRef)
	end

	return true
end

function EFFECT:Render()
	if (file.Exists(self:GetModel(),"GAME")) then
		self:StartVisualOverrides()
		self:StartItemTint(self.ItemTint)
		self:DrawModel()
		self:EndItemTint()
		self:EndVisualOverrides()
	end
end

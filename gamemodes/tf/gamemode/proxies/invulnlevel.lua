print("=== Loading InvulnLevel Proxy ===")
print("Time:", CurTime())
print("matproxy available:", matproxy ~= nil)

local function IsInvulnerableLikeValve(ent)
	if not IsValid(ent) or not ent.InCond then return false end
	return ent:InCond(TF_COND_INVULNERABLE)
		or ent:InCond(TF_COND_INVULNERABLE_USER_BUFF)
		or ent:InCond(TF_COND_INVULNERABLE_CARD_EFFECT)
		or ent:InCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED)
end

local function ResolveOwner(ent)
	if not IsValid(ent) then return nil end
	if ent:IsPlayer() then return ent end

	if ent.GetOwner then
		local o = ent:GetOwner()
		if IsValid(o) and o:IsPlayer() then return o end
	end

	if ent.GetParent then
		local p = ent:GetParent()
		if IsValid(p) and p:IsPlayer() then return p end
	end

	return nil
end

matproxy.Add({
	name = "InvulnLevel",
	init = function(self, mat, values)
		self.Result = values.resultvar
		return self.Result ~= nil
	end,
	bind = function(self, mat, ent)
		local owner = ResolveOwner(ent)
		local result = 1.0
		if IsValid(owner) and IsInvulnerableLikeValve(owner) and owner:InCond(TF_COND_INVULNERABLE_WEARINGOFF) then
			result = 0.0
		end
		mat:SetFloat(self.Result, result)
	end,
})

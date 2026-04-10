ENT.Type = "point"

local TEAM_TRANSLATE = {
	[0] = TEAM_UNASSIGNED,
	[2] = TEAM_RED,
	[3] = TEAM_BLU,
}

local function to_bool(v, default)
	if v == nil then return default end
	if isbool(v) then return v end
	local s = string.lower(tostring(v))
	if s == "1" or s == "true" or s == "yes" then return true end
	if s == "0" or s == "false" or s == "no" then return false end
	return default
end

local function is_invulnerable_like_valve(ply)
	if not IsValid(ply) then return false end
	if ply.IsInvulnerable and ply:IsInvulnerable() then
		return true
	end
	if ply.InCond and TF_COND_INVULNERABLE_WEARINGOFF and ply:InCond(TF_COND_INVULNERABLE_WEARINGOFF) then
		return true
	end
	return false
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:GetFilterTeam()
	return TEAM_TRANSLATE[tonumber(self.Properties.teamnum) or 0] or TEAM_UNASSIGNED
end

function ENT:PassesFilter(ent)
	if not (IsValid(ent) and ent:IsPlayer()) then
		return false
	end

	if ent.InCond and ((TF_COND_DISGUISED and ent:InCond(TF_COND_DISGUISED)) or (TF_COND_DISGUISING and ent:InCond(TF_COND_DISGUISING))) then
		return false
	end

	if ent.IsStealthed and ent:IsStealthed() then
		return false
	end

	if is_invulnerable_like_valve(ent) then
		return false
	end

	local filterTeam = self:GetFilterTeam()
	local pass = (filterTeam == TEAM_UNASSIGNED) or (ent:Team() == filterTeam)
	if to_bool(self.Properties.negated, false) then
		pass = not pass
	end
	return pass
end

function ENT:AcceptInput(name, activator, caller)
	name = string.lower(tostring(name or ""))
	if name == "testactivator" then
		local target = IsValid(activator) and activator or caller
		if self:PassesFilter(target) then
			self:Fire("OnPass", "", 0, activator, caller)
			return true
		end
		self:Fire("OnFail", "", 0, activator, caller)
		return false
	end
	return false
end

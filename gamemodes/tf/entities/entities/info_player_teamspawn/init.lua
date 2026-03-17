ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	self.ControlPoint = NULL
	self.RoundBlueSpawn = NULL
	self.RoundRedSpawn = NULL
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
	local props = self.Properties or {}

	self.Disabled = tonumber(props.startdisabled or 0) == 1
	self.SpawnMode = tonumber(props.spawnmode or 0) or 0
	self.MatchSummaryType = tonumber(props.matchsummary or 0) or 0

	local teamNum = tonumber(props.teamnum or -1) or -1
	if teamNum == -1 then
		teamNum = tonumber((self:GetKeyValues() or {}).TeamNum or -1) or -1
	end
	self.TeamNum = teamNum
end

function ENT:ResolveLinkedEntities()
	local props = self.Properties or {}

	local controlPointName = tostring(props.controlpoint or "")
	local roundBlueName = tostring(props.round_bluespawn or "")
	local roundRedName = tostring(props.round_redspawn or "")

	self.ControlPoint = ents.FindByName(controlPointName)[1] or NULL
	self.RoundBlueSpawn = ents.FindByName(roundBlueName)[1] or NULL
	self.RoundRedSpawn = ents.FindByName(roundRedName)[1] or NULL
end

function ENT:InputEnable()
	self.Disabled = false
end

function ENT:InputDisable()
	self.Disabled = true
end

function ENT:InputRoundSpawn()
	self:RefreshStateFromProperties()
	self:ResolveLinkedEntities()
end

function ENT:IsDisabled()
	return self.Disabled and true or false
end

function ENT:GetSpawnTeamNum()
	return tonumber(self.TeamNum or -1) or -1
end

function ENT:IsTriggeredSpawn()
	return tonumber(self.SpawnMode or 0) == 1
end

function ENT:IsRoundEnabledForTeam(teamNum)
	local roundEnt = NULL
	if teamNum == TEAM_BLU then
		roundEnt = self.RoundBlueSpawn
	elseif teamNum == TEAM_RED then
		roundEnt = self.RoundRedSpawn
	end

	if not IsValid(roundEnt) then
		local hasNamedRound = false
		local props = self.Properties or {}
		if teamNum == TEAM_BLU then
			hasNamedRound = isstring(props.round_bluespawn) and props.round_bluespawn ~= ""
		elseif teamNum == TEAM_RED then
			hasNamedRound = isstring(props.round_redspawn) and props.round_redspawn ~= ""
		end
		return not hasNamedRound
	end

	if roundEnt.IsDisabled then
		return not roundEnt:IsDisabled()
	end

	return true
end

function ENT:IsControlPointEnabledForTeam(teamNum)
	if not IsValid(self.ControlPoint) then
		local props = self.Properties or {}
		return not (isstring(props.controlpoint) and props.controlpoint ~= "")
	end

	if not self.ControlPoint.GetOwnerTeam then
		return true
	end

	return tonumber(self.ControlPoint:GetOwnerTeam() or 0) == tonumber(teamNum or -1)
end

function ENT:IsAvailableForTeam(teamNum, allowTriggered)
	if self:IsDisabled() then return false end
	if self:GetSpawnTeamNum() ~= tonumber(teamNum or -1) then return false end
	if self:IsTriggeredSpawn() and not allowTriggered then return false end
	if not self:IsRoundEnabledForTeam(teamNum) then return false end
	if not self:IsControlPointEnabledForTeam(teamNum) then return false end
	return true
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input" .. name] or self["Input_" .. name]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
end

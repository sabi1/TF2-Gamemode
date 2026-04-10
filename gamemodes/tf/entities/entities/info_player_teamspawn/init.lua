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

	if key == "startdisabled"
		or key == "spawnmode"
		or key == "matchsummary"
		or key == "teamnum" then
		self:RefreshStateFromProperties()
	elseif key == "controlpoint"
		or key == "round_bluespawn"
		or key == "round_redspawn" then
		self:ResolveLinkedEntities()
	end
end

function ENT:Activate()
	self:RefreshStateFromProperties()
	self:ResolveLinkedEntities()
end

function ENT:RefreshStateFromProperties()
	local props = self.Properties or {}

	self.Disabled = tonumber(props.startdisabled or 0) == 1
	self.SpawnMode = tonumber(props.spawnmode or 0) or 0
	self.MatchSummaryType = tonumber(props.matchsummary or 0) or 0

	local teamNum = tonumber(props.teamnum or -1) or -1
	if teamNum == -1 then
		local kv = self.GetKeyValues and self:GetKeyValues() or {}
		teamNum = tonumber(kv.TeamNum or kv.teamnum or kv.TeamNum or -1) or -1
	end
	self.TeamNum = teamNum
end

function ENT:GetControlPointTargetName()
	local props = self.Properties or {}
	local controlPointName = props.controlpoint
	if controlPointName == nil then
		local kv = self.GetKeyValues and self:GetKeyValues() or {}
		controlPointName = kv.controlpoint or kv.ControlPoint
	end

	if isnumber(controlPointName) then
		if controlPointName <= 0 then
			return ""
		end
	end

	controlPointName = tostring(controlPointName or "")
	if controlPointName == "" or controlPointName == "0" or controlPointName == "-1" or controlPointName == "nil" then
		return ""
	end

	return controlPointName
end

function ENT:GetRoundSpawnTargetName(teamNum)
	local props = self.Properties or {}
	local key = teamNum == TEAM_BLU and "round_bluespawn" or "round_redspawn"
	local roundName = props[key]
	if roundName == nil then
		local kv = self.GetKeyValues and self:GetKeyValues() or {}
		roundName = kv[key] or kv[(teamNum == TEAM_BLU) and "RoundBlueSpawn" or "RoundRedSpawn"]
	end

	roundName = tostring(roundName or "")
	if roundName == "" or roundName == "0" or roundName == "-1" or roundName == "nil" then
		return ""
	end

	return roundName
end

function ENT:ResolveLinkedEntities()
	local controlPointName = self:GetControlPointTargetName()
	local roundBlueName = self:GetRoundSpawnTargetName(TEAM_BLU)
	local roundRedName = self:GetRoundSpawnTargetName(TEAM_RED)

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
	local teamNum = tonumber(self.TeamNum or -1) or -1
	if teamNum ~= -1 then
		return teamNum
	end

	local kv = self.GetKeyValues and self:GetKeyValues() or {}
	teamNum = tonumber(kv.TeamNum or kv.teamnum or self.teamnum or self.Team or -1) or -1
	return teamNum
end

function ENT:IsTriggeredSpawn()
	return tonumber(self.SpawnMode or 0) == 1
end

function ENT:IsRoundEnabledForTeam(teamNum)
	local expectsNamedRound = self:GetRoundSpawnTargetName(teamNum) ~= ""

	if expectsNamedRound then
		local roundEnt = (teamNum == TEAM_BLU and self.RoundBlueSpawn) or (teamNum == TEAM_RED and self.RoundRedSpawn) or NULL
		if not IsValid(roundEnt) then
			self:ResolveLinkedEntities()
		end
	end

	local roundEnt = NULL
	if teamNum == TEAM_BLU then
		roundEnt = self.RoundBlueSpawn
	elseif teamNum == TEAM_RED then
		roundEnt = self.RoundRedSpawn
	end

	if not IsValid(roundEnt) then
		return not expectsNamedRound
	end

	if roundEnt.IsDisabled then
		return not roundEnt:IsDisabled()
	end

	return true
end

function ENT:IsControlPointEnabledForTeam(teamNum)
	local controlPointName = self:GetControlPointTargetName()
	local expectsControlPoint = controlPointName ~= ""
	if not expectsControlPoint then
		self.ControlPoint = NULL
		return true
	end

	if not IsValid(self.ControlPoint) then
		self:ResolveLinkedEntities()
	end

	if not IsValid(self.ControlPoint) then
		return true
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

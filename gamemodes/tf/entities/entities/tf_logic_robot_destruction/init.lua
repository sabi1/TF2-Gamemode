ENT.Type = "point"

local TF_FLAGTYPE_ROBOT_DESTRUCTION_ID = rawget(_G, "TF_FLAGTYPE_ROBOT_DESTRUCTION") or 5

local TEAM_OUTPUTS = {
	[TEAM_RED] = {
		hitMax = "OnRedHitMaxPoints",
		leaveMax = "OnRedLeaveMaxPoints",
		hitZero = "OnRedHitZeroPoints",
		hasPoints = "OnRedHasPoints",
		finaleEnd = "OnRedFinalePeriodEnd",
		firstFlagStolen = "OnRedFirstFlagStolen",
		flagStolen = "OnRedFlagStolen",
		lastFlagReturned = "OnRedLastFlagReturned",
	},
	[TEAM_BLU] = {
		hitMax = "OnBlueHitMaxPoints",
		leaveMax = "OnBlueLeaveMaxPoints",
		hitZero = "OnBlueHitZeroPoints",
		hasPoints = "OnBlueHasPoints",
		finaleEnd = "OnBlueFinalePeriodEnd",
		firstFlagStolen = "OnBlueFirstFlagStolen",
		flagStolen = "OnBlueFlagStolen",
		lastFlagReturned = "OnBlueLastFlagReturned",
	},
}

local function ClampTeam(team)
	if team == TEAM_RED then return TEAM_RED end
	return TEAM_BLU
end

local function IsRobotDestructionFlag(flag)
	if not IsValid(flag) then return false end
	local gameType = flag.GetNWInt and flag:GetNWInt("FlagGameType", flag.GameType or 0) or (flag.GameType or 0)
	return tonumber(gameType) == TF_FLAGTYPE_ROBOT_DESTRUCTION_ID
end

local function UpdateGlobals(logic)
	SetGlobalBool("tf_robot_destruction_map", true)
	SetGlobalInt("tf_rd_red_score", logic.RedScore or 0)
	SetGlobalInt("tf_rd_blue_score", logic.BlueScore or 0)
	SetGlobalInt("tf_rd_max_points", logic.MaxPoints or 0)
	SetGlobalString("tf_rd_hud_res", tostring(logic.HudResFile or ""))
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.RedScore = 0
	self.BlueScore = 0
	self.RedStolenFlags = 0
	self.BlueStolenFlags = 0
	self:ReloadProperties()

	if GAMEMODE then
		GAMEMODE.IsRobotDestructionMap = true
	end

	UpdateGlobals(self)
end

function ENT:ReloadProperties()
	local props = self.Properties or {}
	self.ScoreInterval = tonumber(props.score_interval) or 1
	self.LoserRespawnBonusPerBot = tonumber(props.loser_respawn_bonus_per_bot) or 0
	self.RedRespawnTime = tonumber(props.red_respawn_time) or 10
	self.BlueRespawnTime = tonumber(props.blue_respawn_time) or 10
	self.MaxPoints = math.max(1, tonumber(props.max_points) or 200)
	self.FinaleLength = math.max(0, tonumber(props.finale_length) or 30)
	self.HudResFile = tostring(props.res_file or "resource/UI/HudObjectiveRobotDestruction.res")
end

function ENT:KeyValue(key, value)
	if string.Left(key, 2) == "On" then
		self:StoreOutput(key, value)
	end

	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:GetTeamScore(team)
	team = ClampTeam(team)
	return team == TEAM_RED and self.RedScore or self.BlueScore
end

function ENT:SetTeamScore(team, score, activator)
	team = ClampTeam(team)
	local outputs = TEAM_OUTPUTS[team]
	local oldScore = self:GetTeamScore(team)
	local newScore = math.Clamp(math.floor(tonumber(score) or 0), 0, self.MaxPoints)
	if oldScore == newScore then
		return
	end

	if team == TEAM_RED then
		self.RedScore = newScore
	else
		self.BlueScore = newScore
	end

	if newScore >= self.MaxPoints and oldScore < self.MaxPoints then
		self:TriggerOutput(outputs.hitMax, activator or self)
		if self.FinaleLength > 0 then
			timer.Create("tf_rd_finale_" .. self:EntIndex() .. "_" .. team, self.FinaleLength, 1, function()
				if not IsValid(self) then return end
				self:TriggerOutput(outputs.finaleEnd, self)
			end)
		else
			self:TriggerOutput(outputs.finaleEnd, self)
		end
	elseif oldScore >= self.MaxPoints and newScore < self.MaxPoints then
		self:TriggerOutput(outputs.leaveMax, activator or self)
		timer.Remove("tf_rd_finale_" .. self:EntIndex() .. "_" .. team)
	end

	if newScore == 0 and oldScore > 0 then
		self:TriggerOutput(outputs.hitZero, activator or self)
	elseif oldScore == 0 and newScore > 0 then
		self:TriggerOutput(outputs.hasPoints, activator or self)
	end

	UpdateGlobals(self)
end

function ENT:AddScore(team, delta, activator)
	self:SetTeamScore(team, self:GetTeamScore(team) + (tonumber(delta) or 0), activator)
end

function ENT:OnFlagStolen(team, activator)
	team = ClampTeam(team)
	local outputs = TEAM_OUTPUTS[team]
	local key = team == TEAM_RED and "RedStolenFlags" or "BlueStolenFlags"
	local oldCount = tonumber(self[key]) or 0
	local newCount = oldCount + 1
	self[key] = newCount
	if oldCount == 0 then
		self:TriggerOutput(outputs.firstFlagStolen, activator or self)
	end
	self:TriggerOutput(outputs.flagStolen, activator or self)
end

function ENT:OnFlagReturned(team, activator)
	team = ClampTeam(team)
	local outputs = TEAM_OUTPUTS[team]
	local key = team == TEAM_RED and "RedStolenFlags" or "BlueStolenFlags"
	local oldCount = tonumber(self[key]) or 0
	local newCount = math.max(oldCount - 1, 0)
	self[key] = newCount
	if oldCount > 0 and newCount == 0 then
		self:TriggerOutput(outputs.lastFlagReturned, activator or self)
	end
end

function ENT:OnRemove()
	timer.Remove("tf_rd_finale_" .. self:EntIndex() .. "_" .. TEAM_RED)
	timer.Remove("tf_rd_finale_" .. self:EntIndex() .. "_" .. TEAM_BLU)
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))

	if name == "roundactivate" then
		self:ReloadProperties()
		for _, group in ipairs(ents.FindByClass("tf_robot_destruction_spawn_group")) do
			if IsValid(group) and group.RespawnRobots then
				group:RespawnRobots()
			end
		end
		UpdateGlobals(self)
		return true
	end

	return false
end

hook.Add("TF_MapFlagPickedUp", "TF_RDLogic_FlagPickedUpOutputs", function(flag, carrier)
	if not IsValid(flag) or not IsValid(carrier) then return end
	if not IsRobotDestructionFlag(flag) then return end
	local ownerTeam = ClampTeam(flag.TeamNum)
	if carrier.Team and carrier:Team() == ownerTeam then return end

	for _, logic in ipairs(ents.FindByClass("tf_logic_robot_destruction")) do
		if IsValid(logic) then
			logic:OnFlagStolen(ownerTeam, carrier)
		end
	end
end)

hook.Add("TF_MapFlagReturned", "TF_RDLogic_FlagReturnedOutputs", function(flag)
	if not IsValid(flag) then return end
	if not IsRobotDestructionFlag(flag) then return end
	local ownerTeam = ClampTeam(flag.TeamNum)
	for _, logic in ipairs(ents.FindByClass("tf_logic_robot_destruction")) do
		if IsValid(logic) then
			logic:OnFlagReturned(ownerTeam, flag)
		end
	end
end)

hook.Add("TF_MapFlagCaptured", "TF_RDLogic_FlagCapturedOutputs", function(flag, activator)
	if not IsValid(flag) then return end
	if not IsRobotDestructionFlag(flag) then return end
	local ownerTeam = ClampTeam(flag.TeamNum)
	local capturedPoints = math.max(tonumber(flag.StoredVaultPoints) or 0, 0)
	for _, logic in ipairs(ents.FindByClass("tf_logic_robot_destruction")) do
		if IsValid(logic) then
			local activatorTeam = IsValid(activator) and activator:IsPlayer() and ClampTeam(activator:Team()) or nil
			if capturedPoints > 0 and activatorTeam then
				logic:AddScore(activatorTeam, capturedPoints, activator)
			end
			logic:OnFlagReturned(ownerTeam, activator or flag)
		end
	end
	flag.StoredVaultPoints = 0
end)

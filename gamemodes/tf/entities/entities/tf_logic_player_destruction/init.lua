ENT.Type = "point"

local TF_FLAGTYPE_PLAYER_DESTRUCTION_ID = rawget(_G, "TF_FLAGTYPE_PLAYER_DESTRUCTION") or 6

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
		scoreChanged = "OnRedScoreChanged",
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
		scoreChanged = "OnBlueScoreChanged",
	},
}

local function ClampTeam(team)
	if team == TEAM_RED then return TEAM_RED end
	return TEAM_BLU
end

local function IsPlayerDestructionFlag(flag)
	if not IsValid(flag) then return false end
	local gameType = flag.GetNWInt and flag:GetNWInt("FlagGameType", flag.GameType or 0) or (flag.GameType or 0)
	return tonumber(gameType) == TF_FLAGTYPE_PLAYER_DESTRUCTION_ID
end

local function UpdateGlobals(logic)
	SetGlobalBool("tf_player_destruction_map", true)
	SetGlobalInt("tf_pd_red_score", logic.RedScore or 0)
	SetGlobalInt("tf_pd_blue_score", logic.BlueScore or 0)
	SetGlobalInt("tf_pd_max_points", logic.MaxPoints or 0)
	SetGlobalInt("tf_pd_flag_reset_delay", logic.FlagResetDelay or 0)
	SetGlobalInt("tf_pd_points_on_player_death", logic.PointsOnPlayerDeath or 0)
	SetGlobalString("tf_pd_countdown_image", tostring(logic.CountdownImage or ""))
	SetGlobalString("tf_pd_hud_res", tostring(logic.HudResFile or ""))
end

local function GetPlayingPlayerCount()
	local count = 0
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:Team() ~= TEAM_SPECTATOR then
			count = count + 1
		end
	end
	return count
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.RedScore = 0
	self.BlueScore = 0
	self.RedStolenFlags = 0
	self.BlueStolenFlags = 0
	self:ReloadProperties()

	if GAMEMODE then
		GAMEMODE.IsPlayerDestructionMap = true
	end

	UpdateGlobals(self)
end

function ENT:ReloadProperties()
	local props = self.Properties or {}
	self.RedRespawnTime = tonumber(props.red_respawn_time) or 10
	self.BlueRespawnTime = tonumber(props.blue_respawn_time) or 10
	self.MinPoints = math.max(1, tonumber(props.min_points) or 10)
	self.PointsPerPlayer = math.max(0, tonumber(props.points_per_player) or 5)
	self.FinaleLength = math.max(0, tonumber(props.finale_length) or 30)
	self.HudResFile = tostring(props.res_file or "resource/UI/HudObjectivePlayerDestruction.res")
	self.FlagResetDelay = math.max(0, tonumber(props.flag_reset_delay) or 60)
	self.HealDistance = math.max(0, tonumber(props.heal_distance) or 450)
	self.PointsOnPlayerDeath = math.max(0, tonumber(props.pointsonplayerdeath or props.points_on_player_death) or 1)
	self.MaxScoreUpdatingAllowed = tonumber(props.disablemaxscoreupdating or 0) == 0
	self.CountdownImage = tostring(props.countdownimage or "")
	self.MaxPoints = math.max(self.MinPoints, self.PointsPerPlayer * math.max(GetPlayingPlayerCount(), 1))
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

function ENT:TriggerScoreChanged(team)
	local outputs = TEAM_OUTPUTS[ClampTeam(team)]
	local progress = 0
	if self.MaxPoints > 0 then
		progress = self:GetTeamScore(team) / self.MaxPoints
	end
	self:TriggerOutput(outputs.scoreChanged, self, self, tostring(math.Clamp(progress, 0, 1)))
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
			timer.Create("tf_pd_finale_" .. self:EntIndex() .. "_" .. team, self.FinaleLength, 1, function()
				if not IsValid(self) then return end
				self:TriggerOutput(outputs.finaleEnd, self)
			end)
		else
			self:TriggerOutput(outputs.finaleEnd, self)
		end
	elseif oldScore >= self.MaxPoints and newScore < self.MaxPoints then
		self:TriggerOutput(outputs.leaveMax, activator or self)
		timer.Remove("tf_pd_finale_" .. self:EntIndex() .. "_" .. team)
	end

	if newScore == 0 and oldScore > 0 then
		self:TriggerOutput(outputs.hitZero, activator or self)
	elseif oldScore == 0 and newScore > 0 then
		self:TriggerOutput(outputs.hasPoints, activator or self)
	end

	self:TriggerScoreChanged(team)
	UpdateGlobals(self)
end

function ENT:AddScore(team, delta, activator)
	self:SetTeamScore(team, self:GetTeamScore(team) + (tonumber(delta) or 0), activator)
end

function ENT:EvaluatePlayerCount()
	if not self.MaxScoreUpdatingAllowed then
		return
	end

	local oldMax = self.MaxPoints
	self.MaxPoints = math.max(self.MinPoints, self.PointsPerPlayer * math.max(GetPlayingPlayerCount(), 1))
	if oldMax ~= self.MaxPoints then
		self.RedScore = math.Clamp(self.RedScore, 0, self.MaxPoints)
		self.BlueScore = math.Clamp(self.BlueScore, 0, self.MaxPoints)
		self:TriggerScoreChanged(TEAM_RED)
		self:TriggerScoreChanged(TEAM_BLU)
		UpdateGlobals(self)
	end
end

function ENT:SetCountdownTimer(length)
	timer.Remove("tf_pd_countdown_" .. self:EntIndex())

	length = tonumber(length) or 0
	if length <= 0 then
		self.CountdownEndTime = nil
		SetGlobalFloat("tf_pd_countdown_endtime", 0)
		return
	end

	self.CountdownEndTime = CurTime() + length
	SetGlobalFloat("tf_pd_countdown_endtime", self.CountdownEndTime)
	timer.Create("tf_pd_countdown_" .. self:EntIndex(), length, 1, function()
		if not IsValid(self) then return end
		self.CountdownEndTime = nil
		SetGlobalFloat("tf_pd_countdown_endtime", 0)
		self:TriggerOutput("OnCountdownTimerExpired", self)
	end)
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
	timer.Remove("tf_pd_countdown_" .. self:EntIndex())
	timer.Remove("tf_pd_finale_" .. self:EntIndex() .. "_" .. TEAM_RED)
	timer.Remove("tf_pd_finale_" .. self:EntIndex() .. "_" .. TEAM_BLU)
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))

	if name == "scoreredpoints" then
		self:AddScore(TEAM_RED, 1, activator)
		return true
	elseif name == "scorebluepoints" then
		self:AddScore(TEAM_BLU, 1, activator)
		return true
	elseif name == "enablemaxscoreupdating" then
		self.MaxScoreUpdatingAllowed = true
		self:EvaluatePlayerCount()
		return true
	elseif name == "disablemaxscoreupdating" then
		self:EvaluatePlayerCount()
		self.MaxScoreUpdatingAllowed = false
		return true
	elseif name == "setcountdowntimer" then
		self:SetCountdownTimer(data)
		return true
	elseif name == "setcountdownimage" then
		self.CountdownImage = tostring(data or "")
		SetGlobalString("tf_pd_countdown_image", self.CountdownImage)
		return true
	elseif name == "setflagresetdelay" then
		self.FlagResetDelay = math.max(0, tonumber(data) or 0)
		SetGlobalInt("tf_pd_flag_reset_delay", self.FlagResetDelay)
		return true
	elseif name == "setpointsonplayerdeath" then
		self.PointsOnPlayerDeath = math.max(0, tonumber(data) or 0)
		SetGlobalInt("tf_pd_points_on_player_death", self.PointsOnPlayerDeath)
		return true
	end

	return false
end

hook.Add("PlayerInitialSpawn", "TF_PDLogic_EvaluatePlayerCount", function()
	for _, logic in ipairs(ents.FindByClass("tf_logic_player_destruction")) do
		if IsValid(logic) then
			logic:EvaluatePlayerCount()
		end
	end
end)

hook.Add("PlayerDisconnected", "TF_PDLogic_ReevaluatePlayerCount", function()
	timer.Simple(0, function()
		for _, logic in ipairs(ents.FindByClass("tf_logic_player_destruction")) do
			if IsValid(logic) then
				logic:EvaluatePlayerCount()
			end
		end
	end)
end)

hook.Add("TF_MapFlagPickedUp", "TF_PDLogic_FlagPickedUpOutputs", function(flag, carrier)
	if not IsValid(flag) or not IsValid(carrier) then return end
	if not IsPlayerDestructionFlag(flag) then return end
	local ownerTeam = ClampTeam(flag.TeamNum)
	if carrier.Team and carrier:Team() == ownerTeam then return end

	for _, logic in ipairs(ents.FindByClass("tf_logic_player_destruction")) do
		if IsValid(logic) then
			logic:OnFlagStolen(ownerTeam, carrier)
		end
	end
end)

hook.Add("TF_MapFlagReturned", "TF_PDLogic_FlagReturnedOutputs", function(flag)
	if not IsValid(flag) then return end
	if not IsPlayerDestructionFlag(flag) then return end
	local ownerTeam = ClampTeam(flag.TeamNum)
	for _, logic in ipairs(ents.FindByClass("tf_logic_player_destruction")) do
		if IsValid(logic) then
			logic:OnFlagReturned(ownerTeam, flag)
		end
	end
end)

hook.Add("TF_MapFlagCaptured", "TF_PDLogic_FlagCapturedOutputs", function(flag, activator)
	if not IsValid(flag) then return end
	if not IsPlayerDestructionFlag(flag) then return end
	local ownerTeam = ClampTeam(flag.TeamNum)
	for _, logic in ipairs(ents.FindByClass("tf_logic_player_destruction")) do
		if IsValid(logic) then
			logic:OnFlagReturned(ownerTeam, activator or flag)
		end
	end
end)

hook.Add("PlayerChangedTeam", "TF_PDLogic_PlayerChangedTeam", function()
	timer.Simple(0, function()
		for _, logic in ipairs(ents.FindByClass("tf_logic_player_destruction")) do
			if IsValid(logic) then
				logic:EvaluatePlayerCount()
			end
		end
	end)
end)

ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

local function GetRespawnWaveModule()
	return TF2 and TF2.RespawnWaves or nil
end

local function FindKothLogic()
	return ents.FindByClass("tf_logic_koth")[1]
end

local function TriggerOnAllGameRules(outputName, activator, caller, value)
	for _, ent in ipairs(ents.FindByClass("tf_gamerules")) do
		if IsValid(ent) and ent.TriggerOutput then
			ent:TriggerOutput(outputName, activator or ent, caller or ent, value)
		end
	end
end

hook.Add("OnPlayerChangedTeam", "TF_GameRules_PlayerCountChanged", function()
	timer.Simple(0, function()
		TriggerOnAllGameRules("Team1PlayersChanged", NULL, NULL, tostring(#team.GetPlayers(TEAM_RED)))
		TriggerOnAllGameRules("Team2PlayersChanged", NULL, NULL, tostring(#team.GetPlayers(TEAM_BLU)))
	end)
end)

hook.Add("TF_GameRules_RoundWinOutputs", "TF_GameRules_RoundWinOutputs", function(teamNum, activator)
	if teamNum == TEAM_RED then
		TriggerOnAllGameRules("OnWonByTeam1", activator)
	elseif teamNum == TEAM_BLU then
		TriggerOnAllGameRules("OnWonByTeam2", activator)
	end
end)

function ENT:Input_SetRedTeamRespawnWaveTime(_, _, data)
	local rw = GetRespawnWaveModule()
	if rw and rw.OverrideTeamWave then
		rw.OverrideTeamWave(TEAM_RED, tonumber(data))
	end
end

function ENT:Input_SetBlueTeamRespawnWaveTime(_, _, data)
	local rw = GetRespawnWaveModule()
	if rw and rw.OverrideTeamWave then
		rw.OverrideTeamWave(TEAM_BLU, tonumber(data))
	end
end

function ENT:Input_AddRedTeamRespawnWaveTime(_, _, data)
	local rw = GetRespawnWaveModule()
	if not (rw and rw.OverrideTeamWave) then return end
	local cur = rw.GetOverriddenTeamWave and rw.GetOverriddenTeamWave(TEAM_RED) or nil
	rw.OverrideTeamWave(TEAM_RED, (tonumber(cur) or 0) + (tonumber(data) or 0))
end

function ENT:Input_AddBlueTeamRespawnWaveTime(_, _, data)
	local rw = GetRespawnWaveModule()
	if not (rw and rw.OverrideTeamWave) then return end
	local cur = rw.GetOverriddenTeamWave and rw.GetOverriddenTeamWave(TEAM_BLU) or nil
	rw.OverrideTeamWave(TEAM_BLU, (tonumber(cur) or 0) + (tonumber(data) or 0))
end

function ENT:Input_SetRedTeamGoalString(_, _, data)
	SetGlobalString("TF_RedTeamGoalString", tostring(data or ""))
end

function ENT:Input_SetBlueTeamGoalString(_, _, data)
	SetGlobalString("TF_BluTeamGoalString", tostring(data or ""))
end

function ENT:Input_SetRedTeamRole(_, _, data)
	SetGlobalInt("TF_RedTeamRole", tonumber(data) or 0)
end

function ENT:Input_SetBlueTeamRole(_, _, data)
	SetGlobalInt("TF_BluTeamRole", tonumber(data) or 0)
end

function ENT:Input_SetRequiredObserverTarget(_, _, data)
	SetGlobalString("TF_RequiredObserverTarget", tostring(data or ""))
end

function ENT:Input_AddRedTeamScore(_, _, data)
	team.AddScore(TEAM_RED, tonumber(data) or 0)
end

function ENT:Input_AddBlueTeamScore(_, _, data)
	team.AddScore(TEAM_BLU, tonumber(data) or 0)
end

function ENT:Input_SetStalemateOnTimelimit(_, _, data)
	SetGlobalBool("TF_StalemateOnTimelimit", tonumber(data) == 1 or tostring(data) == "true")
end

function ENT:Input_SetRedKothClockActive(_, _, data)
	local logic = FindKothLogic()
	if IsValid(logic) and logic.AcceptInput then
		logic:AcceptInput("SetRedKothClockActive", self, self, data)
	end
end

function ENT:Input_SetBlueKothClockActive(_, _, data)
	local logic = FindKothLogic()
	if IsValid(logic) and logic.AcceptInput then
		logic:AcceptInput("SetBlueKothClockActive", self, self, data)
	end
end

function ENT:Input_SetCTFCaptureBonusTime(_, _, data)
	SetGlobalFloat("TF_CTFCaptureBonusTime", tonumber(data) or 0)
end

function ENT:Input_PlayVORed(_, _, data)
	for _, ply in ipairs(team.GetPlayers(TEAM_RED)) do
		umsg.Start("TF_PlayGlobalSound", ply)
			umsg.String(tostring(data or ""))
		umsg.End()
	end
end

function ENT:Input_PlayVOBlue(_, _, data)
	for _, ply in ipairs(team.GetPlayers(TEAM_BLU)) do
		umsg.Start("TF_PlayGlobalSound", ply)
			umsg.String(tostring(data or ""))
		umsg.End()
	end
end

function ENT:Input_PlayVO(_, _, data)
	umsg.Start("TF_PlayGlobalSound")
		umsg.String(tostring(data or ""))
	umsg.End()
end

function ENT:Input_HandleMapEvent(_, _, data)
	SetGlobalString("TF_LastMapEvent", tostring(data or ""))
end

function ENT:Input_SetCustomUpgradesFile(_, _, data)
	SetGlobalString("TF_CustomUpgradesFile", tostring(data or ""))
end

function ENT:Input_SetRoundRespawnFreezeEnabled(_, _, data)
	SetGlobalBool("TF_RoundRespawnFreezeEnabled", tonumber(data) ~= 0)
end

function ENT:Input_SetMapForcedTruceDuringBossFight(_, _, data)
	local active = tonumber(data) ~= 0
	GAMEMODE.HalloweenBossTruceActive = active
	if active then
		self:TriggerOutput("OnTruceStart", self, self)
	else
		self:TriggerOutput("OnTruceEnd", self, self)
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input_" .. tostring(name or "")]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
end

TFBotSource = TFBotSource or {}
TFBotSource.ScenarioMonitor = TFBotSource.ScenarioMonitor or {}

local M = TFBotSource.ScenarioMonitor

local cv_fetch_lost_flag_time = CreateConVar("tf_bot_fetch_lost_flag_time", "10", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How long source-shaped TFBots ignore a loose flag before interrupting for a fetch.")
local cv_ignore_lost_flag_time = CreateConVar("tf_bot_source_ignore_lost_flag_time", "20", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How long source-shaped TFBots ignore dropped flags after spawn, mirroring Valve's scenario monitor.")

local function get_flag()
	for _, cls in ipairs({"item_teamflag_mvm", "item_teamflag"}) do
		for _, ent in ipairs(ents.FindByClass(cls)) do
			if IsValid(ent) then
				return ent
			end
		end
	end
	return nil
end

local function get_flag_carrier(flag)
	if not IsValid(flag) then return nil end
	if IsValid(flag.Carrier) then
		return flag.Carrier
	end
	if flag.GetCarrier then
		local ok, carrier = pcall(flag.GetCarrier, flag)
		if ok and IsValid(carrier) then
			return carrier
		end
	end
	if flag.GetOwnerEntity then
		local ok, owner = pcall(flag.GetOwnerEntity, flag)
		if ok and IsValid(owner) then
			return owner
		end
	end
	if flag.GetOwner then
		local ok, owner = pcall(flag.GetOwner, flag)
		if ok and IsValid(owner) then
			return owner
		end
	end
	return nil
end

local function bot_has_flag(bot)
	local flag = get_flag()
	return IsValid(flag) and get_flag_carrier(flag) == bot
end

local function is_flag_dropped(flag)
	if not IsValid(flag) then return false end
	if flag.IsDropped then
		local ok, dropped = pcall(flag.IsDropped, flag)
		if ok then
			return dropped == true
		end
	end
	return get_flag_carrier(flag) == nil and tonumber(flag.State or -1) == 2
end

local function is_flag_pickup_allowed(bot, flag)
	if not (IsValid(bot) and IsValid(flag)) then return false end
	if flag.CanPickup then
		local ok, canPickup = pcall(flag.CanPickup, flag, bot)
		if ok then
			return canPickup == true
		end
	end
	return true
end

local function is_mvm_mode()
	return GAMEMODE and GAMEMODE.IsMannVsMachineMode and GAMEMODE:IsMannVsMachineMode()
end

local function is_payload_mode()
	if TF_IsPayloadHudMode then
		return TF_IsPayloadHudMode()
	end
	if TF_GetHudGameMode then
		return TF_GetHudGameMode() == "payload"
	end
	return #ents.FindByClass("team_train_watcher") > 0
end

local function is_cp_mode()
	if TF_IsControlPointHudMode then
		return TF_IsControlPointHudMode()
	end
	if TF_GetHudGameMode then
		local mode = TF_GetHudGameMode()
		return mode == "cp" or mode == "koth" or mode == "arena"
	end
	return #ents.FindByClass("trigger_capture_area") > 0
end

local function get_payload_watcher()
	if GAMEMODE and GAMEMODE.GetActivePayloadWatcher then
		local watcher = GAMEMODE:GetActivePayloadWatcher()
		if IsValid(watcher) then
			return watcher
		end
	end
	for _, watcher in ipairs(ents.FindByClass("team_train_watcher")) do
		if IsValid(watcher) then
			return watcher
		end
	end
	return nil
end

local function get_payload_state(watcher)
	if not IsValid(watcher) then return nil end
	if watcher.GetState then
		local ok, state = pcall(watcher.GetState, watcher)
		if ok and istable(state) then
			return state
		end
	end
	return watcher.PayloadState
end

local function get_payload_team(state, key, fallback)
	if not istable(state) then return fallback end
	local teamNum = tonumber(state[key] or fallback)
	if teamNum == TEAM_RED or teamNum == TEAM_BLU then
		return teamNum
	end
	return fallback
end

local function should_capture_control_point(bot)
	if not IsValid(bot) then return false end
	local teamNum = bot:Team()
	if teamNum ~= TEAM_RED and teamNum ~= TEAM_BLU then return false end
	for _, trigger in ipairs(ents.FindByClass("trigger_capture_area")) do
		local cp = IsValid(trigger) and trigger.CapturePoint or nil
		if not IsValid(cp) or cp.Locked == true then continue end
		local ownerTeam = tonumber((cp.GetOwnerTeam and cp:GetOwnerTeam()) or cp.OwnerTeam or (cp.Properties and cp.Properties.point_default_owner) or 0) or 0
		local canWeCap = true
		if istable(cp.TeamCanCap) and cp.TeamCanCap[teamNum] ~= nil then
			canWeCap = cp.TeamCanCap[teamNum] and true or false
		end
		if ownerTeam ~= teamNum and canWeCap then
			return true
		end
	end
	return false
end

local function should_defend_control_point(bot)
	if not IsValid(bot) then return false end
	local teamNum = bot:Team()
	local enemyTeam = (teamNum == TEAM_RED) and TEAM_BLU or TEAM_RED
	if teamNum ~= TEAM_RED and teamNum ~= TEAM_BLU then return false end
	for _, trigger in ipairs(ents.FindByClass("trigger_capture_area")) do
		local cp = IsValid(trigger) and trigger.CapturePoint or nil
		if not IsValid(cp) or cp.Locked == true then continue end
		local ownerTeam = tonumber((cp.GetOwnerTeam and cp:GetOwnerTeam()) or cp.OwnerTeam or (cp.Properties and cp.Properties.point_default_owner) or 0) or 0
		local canEnemyCap = ownerTeam ~= enemyTeam
		if istable(cp.TeamCanCap) and cp.TeamCanCap[enemyTeam] ~= nil then
			canEnemyCap = cp.TeamCanCap[enemyTeam] and true or false
		end
		if ownerTeam == teamNum and canEnemyCap then
			return true
		end
	end
	return false
end

local function is_bot_melee_only()
	if TFBots and TFBots.Config and TFBots.Config.IsMeleeOnly then
		return TFBots.Config:IsMeleeOnly()
	end
	local cv = GetConVar("tf_bot_melee_only")
	return cv and cv:GetBool() or false
end

local function is_being_healed_by_other_medic(bot)
	if not (IsValid(bot) and bot.GetNumHealers and bot.GetHealerByIndex) then
		return false
	end

	local healerCount = tonumber(bot:GetNumHealers()) or 0
	for i = 1, healerCount do
		local healer = bot:GetHealerByIndex(i - 1)
		if not (IsValid(healer) and healer:IsPlayer() and healer ~= bot) then continue end
		local className = string.lower(tostring((healer.GetPlayerClass and healer:GetPlayerClass()) or healer.playerclass or ""))
		if className == "medic" then
			return true
		end
	end

	return false
end

local function medic_has_active_patient(st)
	local patient = st and st.sourceMedic and st.sourceMedic.patient or nil
	return IsValid(patient) and patient:Alive()
end

local function has_attribute(bot, attr)
	return TFBotSource
		and TFBotSource.Core
		and TFBotSource.Core.HasAttribute
		and TFBotSource.Core:HasAttribute(bot, attr) == true
end

local function get_effective_mission(bot, profile)
	local mission = tostring(profile and profile.mission or "none")
	if mission ~= "none" then
		return mission
	end

	local objective = string.lower(string.Trim(tostring(IsValid(bot) and bot.TF_MVM_Objective or "")))
	if objective == "destroysentries" or objective == "missiondestroysentries" or objective == "sentrybuster" then
		return "destroy_sentries"
	end
	if objective == "sniper" or objective == "missionsniper" then
		return "sniper"
	end
	if objective == "seekanddestroy" or objective == "missionseekanddestroy" then
		return "seek_and_destroy"
	end

	return mission
end

local function should_interrupt_for_loose_flag(bot, st, profile, mission)
	if not (IsValid(bot) and st and profile) then return false end
	if mission ~= "none" then return false end

	local flag = get_flag()
	if not (IsValid(flag) and is_flag_pickup_allowed(bot, flag)) then
		st.sourceScenarioMonitor = st.sourceScenarioMonitor or {}
		st.sourceScenarioMonitor.lostFlagDeadline = nil
		return false
	end

	local scenario = st.sourceScenarioMonitor or {}
	st.sourceScenarioMonitor = scenario

	local spawnedAt = bot.GetSpawnTime and tonumber(bot:GetSpawnTime()) or nil
	local sinceSpawn = spawnedAt and (CurTime() - spawnedAt) or math.huge
	if sinceSpawn < math.max(0, cv_ignore_lost_flag_time:GetFloat()) then
		scenario.lostFlagDeadline = nil
		return false
	end

	if IsValid(get_flag_carrier(flag)) or not is_flag_dropped(flag) then
		scenario.lostFlagDeadline = nil
		return false
	end

	if medic_has_active_patient(st) then
		return false
	end

	if scenario.lostFlagDeadline == nil then
		scenario.lostFlagDeadline = CurTime() + math.max(0, cv_fetch_lost_flag_time:GetFloat())
		return false
	end

	if CurTime() >= scenario.lostFlagDeadline then
		scenario.lostFlagDeadline = nil
		return true
	end

	return false
end

function M:SelectAction(bot, st, profile)
	if not (IsValid(bot) and st and profile) then
		return "MainAction"
	end

	local className = string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
	local mission = get_effective_mission(bot, profile)
	local mvmMode = tostring(st.mvm and st.mvm.mode or "")

	if bot_has_flag(bot) then
		return "DeliverFlag"
	end

	if should_interrupt_for_loose_flag(bot, st, profile, mission) then
		return "FetchFlag"
	end

	if mission == "destroy_sentries" then
		return "MissionDestroySentries"
	end
	if mission == "escort_flag_carrier" then
		return "EscortFlagCarrier"
	end
	if mission == "seek_and_destroy" then
		return "SeekAndDestroy"
	end
	if mission == "sniper" then
		return "SniperLurk"
	end
	if mvmMode == "mvm_use_teleporter" then
		return "UseTeleporter"
	end

	if is_mvm_mode() then
		if className == "spy" then
			return "SpyLeaveSpawnRoom"
		end
		if className == "medic" then
			if not is_being_healed_by_other_medic(bot) then
				return "MedicHeal"
			end
		end
		if className == "engineer" then
			return "EngineerIdle"
		end

		if has_attribute(bot, TFBotSource.Core.AttributeType.AGGRESSIVE) then
			return "PushToCapturePoint"
		end

		return "FetchFlag"
	end

	if className == "spy" then
		return "SpyInfiltrate"
	end
	if not is_bot_melee_only() then
		if className == "sniper" then
			return "SniperLurk"
		end
		if className == "medic" then
			return "MedicHeal"
		end
		if className == "engineer" then
			return "EngineerIdle"
		end
	end

	if IsValid(get_flag()) then
		return "FetchFlag"
	end

	if is_payload_mode() then
		local watcher = get_payload_watcher()
		local state = get_payload_state(watcher)
		local attackTeam = get_payload_team(state, "attackTeam", TEAM_BLU)
		local defendTeam = get_payload_team(state, "defendTeam", TEAM_RED)
		if bot:Team() == attackTeam then
			return "PayloadPush"
		end
		if bot:Team() == defendTeam then
			return "PayloadGuard"
		end
	end

	if is_cp_mode() then
		if should_capture_control_point(bot) then
			return "CapturePoint"
		end
		if should_defend_control_point(bot) then
			return "DefendPoint"
		end
		return "CapturePoint"
	end

	return "SeekAndDestroy"
end

return M

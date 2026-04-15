TFBotSource = TFBotSource or {}
TFBotSource.ScenarioMonitor = TFBotSource.ScenarioMonitor or {}

local M = TFBotSource.ScenarioMonitor

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

function M:SelectAction(bot, st, profile)
	if not (IsValid(bot) and st and profile) then
		return "MainAction"
	end

	local className = string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
	local mission = tostring(profile.mission or "none")
	local threat = st.vision and st.vision.currentThreat or nil
	local mvmMode = tostring(st.mvm and st.mvm.mode or "")

	if mission == "destroy_sentries" then
		return "MissionDestroySentries"
	end
	if mission == "escort_flag_carrier" then
		return "EscortFlagCarrier"
	end
	if mission == "seek_and_destroy" then
		return "SeekAndDestroy"
	end
	if mission == "sniper" or className == "sniper" then
		return "SniperLurk"
	end
	if mvmMode == "mvm_use_teleporter" then
		return "UseTeleporter"
	end

	if GAMEMODE and GAMEMODE.IsMannVsMachineMode and GAMEMODE:IsMannVsMachineMode() then
		local flag = get_flag()
		local carrier = IsValid(flag) and ((flag.GetOwnerEntity and flag:GetOwnerEntity()) or (flag.GetOwner and flag:GetOwner()) or nil) or nil

		if className == "spy" then
			if (bot.GetCreationTime and (CurTime() - bot:GetCreationTime()) < 4) or (bot._spawnTime and (CurTime() - bot._spawnTime) < 4) then
				return "SpyLeaveSpawnRoom"
			end
			return "SpyInfiltrate"
		end
		if className == "medic" then
			return "MedicHeal"
		end
		if className == "sniper" then
			return "SniperLurk"
		end
		if className == "engineer" then
			return "EngineerIdle"
		end
		if IsValid(threat) or IsValid(carrier) then
			return "AttackFlagDefenders"
		end
		return "FetchFlag"
	end

	if className == "spy" then
		return "SpyInfiltrate"
	end
	if className == "medic" then
		return "MedicHeal"
	end

	return "SeekAndDestroy"
end

return M

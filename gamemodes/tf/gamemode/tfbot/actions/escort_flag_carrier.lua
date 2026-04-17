TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.EscortFlagCarrier = TFBotSource.Actions.EscortFlagCarrier or {}

local M = TFBotSource.Actions.EscortFlagCarrier

local cv_escort_range = CreateConVar("tf_bot_source_flag_escort_range", "500", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Preferred escort distance from the flag carrier.")
local cv_escort_giveup = CreateConVar("tf_bot_source_flag_escort_give_up_range", "1000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Distance where escorting gives up and switches back to defender pressure.")
local cv_escort_max = CreateConVar("tf_bot_source_flag_escort_max_count", "4", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Maximum number of TFBots that should escort a flag carrier at once.")

local function is_mvm_mode()
	return GAMEMODE and GAMEMODE.IsMannVsMachineMode and GAMEMODE:IsMannVsMachineMode()
end

local function get_flag_team(flag)
	if not IsValid(flag) then return TEAM_UNASSIGNED or 0 end
	if flag.GetNWInt then
		local teamNum = tonumber(flag:GetNWInt("FlagTeamNum", -1) or -1) or -1
		if teamNum >= 0 then
			return teamNum
		end
	end
	if flag.TeamNum ~= nil then
		return tonumber(flag.TeamNum) or TEAM_UNASSIGNED or 0
	end
	if flag.GetTeamNumber then
		local ok, teamNum = pcall(flag.GetTeamNumber, flag)
		if ok then
			return tonumber(teamNum) or TEAM_UNASSIGNED or 0
		end
	end
	return TEAM_UNASSIGNED or 0
end

local function get_flag(bot)
	if is_mvm_mode() then
		for _, ent in ipairs(ents.FindByClass("item_teamflag_mvm")) do
			if IsValid(ent) then
				return ent
			end
		end
		return nil
	end

	if not IsValid(bot) then return nil end
	for _, ent in ipairs(ents.FindByClass("item_teamflag")) do
		if IsValid(ent) and get_flag_team(ent) ~= bot:Team() then
			return ent
		end
	end
	return nil
end

local function world_center(ent)
	if not IsValid(ent) then return nil end
	if ent.WorldSpaceCenter then
		local ok, pos = pcall(ent.WorldSpaceCenter, ent)
		if ok and isvector(pos) then
			return pos
		end
	end
	return ent.GetPos and ent:GetPos() or nil
end

local function get_capture_zone(bot)
	for _, zone in ipairs(ents.FindByClass("func_capturezone")) do
		if not IsValid(zone) then continue end
		local teamNum = tonumber(zone.TeamNum or -1) or -1
		if teamNum == -1 and zone.GetTeamNumber then
			local ok, fetched = pcall(zone.GetTeamNumber, zone)
			if ok then
				teamNum = tonumber(fetched) or -1
			end
		end
		if teamNum == -1 or teamNum == 0 or teamNum == bot:Team() then
			return zone
		end
	end
	return nil
end

local function compute_support_spot(carrier, goal, bot)
	if not (IsValid(carrier) and IsValid(goal) and IsValid(bot)) then return world_center(carrier) end
	local carrierPos = world_center(carrier)
	local goalPos = world_center(goal)
	if not (isvector(carrierPos) and isvector(goalPos)) then return carrierPos end

	local toGoal = goalPos - carrierPos
	toGoal.z = 0
	if toGoal:LengthSqr() <= 1 then
		return carrierPos
	end

	local dir = toGoal:GetNormalized()
	local right = dir:Angle():Right()
	local side = (bot:EntIndex() % 2 == 0) and 1 or -1
	local lead = math.Clamp(toGoal:Length() * 0.35, 160, 540)
	local offset = math.Clamp(toGoal:Length() * 0.18, 80, 220)
	return carrierPos + dir * lead + right * offset * side
end

local function get_escort_count(teamNum)
	local count = 0
	for _, ply in ipairs(player.GetBots()) do
		if not IsValid(ply) or not ply:Alive() then continue end
		if ply:Team() ~= teamNum then continue end
		local st = rawget(ply, "_tfbot_ai")
		if st and st.objective and tostring(st.objective.mode or "") == "escort_flag_carrier" then
			count = count + 1
		end
	end
	for _, bot in ipairs(ents.FindByClass("tf_bot_base_nextbot")) do
		if not IsValid(bot) or not bot:Alive() then continue end
		if bot:Team() ~= teamNum then continue end
		local profile = rawget(bot, "_tfbotSource")
		if profile and tostring(profile.actionName or "") == "EscortFlagCarrier" then
			count = count + 1
		end
	end
	return count
end

function M:Update(bot, st)
	if not (IsValid(bot) and st) then return false end
	local flag = get_flag(bot)
	if not IsValid(flag) then
		return TFBotSource.Actions.FetchFlag:Update(bot, st)
	end

	local carrier = (flag.GetOwnerEntity and flag:GetOwnerEntity()) or (flag.GetOwner and flag:GetOwner()) or nil
	if not IsValid(carrier) then
		return TFBotSource.Actions.FetchFlag:Update(bot, st)
	end
	if carrier == bot then
		return TFBotSource.Actions.FetchFlag:Update(bot, st)
	end

	local carrierPos = world_center(carrier)
	if not isvector(carrierPos) then
		return false
	end

	if bot:GetPos():DistToSqr(carrierPos) > (cv_escort_giveup:GetFloat() * cv_escort_giveup:GetFloat()) then
		return TFBotSource.Actions.AttackFlagDefenders:Update(bot, st)
	end

	if get_escort_count(bot:Team()) > math.max(1, cv_escort_max:GetInt()) then
		return TFBotSource.Actions.AttackFlagDefenders:Update(bot, st)
	end

	local capZone = get_capture_zone(bot)
	local supportPos = IsValid(capZone) and compute_support_spot(carrier, capZone, bot) or carrierPos

	if bot:GetPos():DistToSqr(supportPos) <= ((cv_escort_range:GetFloat() * 0.4) ^ 2) then
		TFBotSource.Core:SetActionTarget(bot, st, "escort_flag_carrier_hold", carrier, supportPos)
		return true
	end

	TFBotSource.Core:SetActionTarget(bot, st, "escort_flag_carrier", carrier, supportPos)
	return true
end

return M

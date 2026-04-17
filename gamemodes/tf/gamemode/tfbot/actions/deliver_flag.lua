TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.DeliverFlag = TFBotSource.Actions.DeliverFlag or {}

local M = TFBotSource.Actions.DeliverFlag

local function is_mvm_mode()
	return GAMEMODE and GAMEMODE.IsMannVsMachineMode and GAMEMODE:IsMannVsMachineMode()
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

local function get_flag_to_deliver(bot)
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
		if IsValid(ent) and get_flag_carrier(ent) == bot then
			return ent
		end
	end
	return nil
end

local function zone_team_matches_bot(zone, bot)
	if not (IsValid(zone) and IsValid(bot)) then return false end
	local teamNum = tonumber(zone.TeamNum or zone.Team or -1) or -1
	if teamNum == -1 and zone.GetTeamNumber then
		local ok, fetched = pcall(zone.GetTeamNumber, zone)
		if ok then
			teamNum = tonumber(fetched) or -1
		end
	end
	if teamNum == -1 or teamNum == 0 then
		return true
	end
	return teamNum == bot:Team()
end

local function is_red_capture_zone(zone)
	if not IsValid(zone) then return false end
	local redTeam = rawget(_G, "TEAM_RED") or 2
	if zone.TeamNum ~= nil then
		return tonumber(zone.TeamNum) == redTeam
	end
	if zone.GetTeamNumber then
		local ok, teamNum = pcall(zone.GetTeamNumber, zone)
		if ok and tonumber(teamNum) then
			return tonumber(teamNum) == redTeam
		end
	end
	return true
end

local function get_capture_zone(bot, flag)
	local best, bestDist
	local anchorPos = world_center(flag) or (IsValid(bot) and bot:GetPos() or nil)

	for _, zone in ipairs(ents.FindByClass("func_capturezone")) do
		if not IsValid(zone) then continue end
		if is_mvm_mode() then
			if not is_red_capture_zone(zone) then continue end
		else
			if not zone_team_matches_bot(zone, bot) then continue end
		end

		local pos = world_center(zone)
		if not isvector(pos) then continue end

		if not isvector(anchorPos) then
			return zone, pos
		end

		local dist = anchorPos:DistToSqr(pos)
		if not bestDist or dist < bestDist then
			best = zone
			bestDist = dist
		end
	end

	return best, world_center(best)
end

function M:Update(bot, st, profile)
	if not (IsValid(bot) and st) then return false end

	local flag = get_flag_to_deliver(bot)
	if not IsValid(flag) then
		return TFBotSource.Actions.SeekAndDestroy:Update(bot, st, profile)
	end

	if get_flag_carrier(flag) ~= bot then
		return TFBotSource.Actions.FetchFlag:Update(bot, st, profile)
	end

	local zone, zonePos = get_capture_zone(bot, flag)
	if not (IsValid(zone) and isvector(zonePos)) then
		return TFBotSource.Actions.FetchFlag:Update(bot, st, profile)
	end

	TFBotSource.Core:SetActionTarget(bot, st, "deliver_flag", zone, zonePos)
	return true
end

return M

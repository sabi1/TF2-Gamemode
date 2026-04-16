TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.PushToCapturePoint = TFBotSource.Actions.PushToCapturePoint or {}

local M = TFBotSource.Actions.PushToCapturePoint

local cv_capture_reached = CreateConVar("tf_bot_source_capture_reached_range", "50", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How close a source-shaped TFBot must get to the capture zone before switching to its follow-up action.")

local function get_zone_pos(zone)
	if not IsValid(zone) then return nil end
	if zone.WorldSpaceCenter then
		local ok, pos = pcall(zone.WorldSpaceCenter, zone)
		if ok and isvector(pos) then
			return pos
		end
	end
	return zone.GetPos and zone:GetPos() or nil
end

local function is_red_capture_zone(zone)
	if not IsValid(zone) then return false end
	if zone.TeamNum ~= nil then
		return tonumber(zone.TeamNum) == (rawget(_G, "TEAM_RED") or 2)
	end
	if zone.GetTeamNumber then
		local ok, teamNum = pcall(zone.GetTeamNumber, zone)
		if ok and tonumber(teamNum) then
			return tonumber(teamNum) == (rawget(_G, "TEAM_RED") or 2)
		end
	end
	return true
end

local function get_capture_zone(anchorPos)
	local best, bestDist
	for _, zone in ipairs(ents.FindByClass("func_capturezone")) do
		if not IsValid(zone) then continue end
		if not is_red_capture_zone(zone) then continue end
		local zonePos = get_zone_pos(zone)
		if not isvector(zonePos) then continue end
		if not isvector(anchorPos) then
			return zone, zonePos
		end
		local dist = zonePos:DistToSqr(anchorPos)
		if not bestDist or dist < bestDist then
			best = zone
			bestDist = dist
		end
	end

	if IsValid(best) then
		return best, get_zone_pos(best)
	end

	for _, zone in ipairs(ents.FindByClass("func_capturezone")) do
		if IsValid(zone) then
			return zone, get_zone_pos(zone)
		end
	end

	return nil, nil
end

function M:Update(bot, st)
	if not (IsValid(bot) and st) then return false end

	local flag = nil
	for _, cls in ipairs({"item_teamflag_mvm", "item_teamflag"}) do
		for _, ent in ipairs(ents.FindByClass(cls)) do
			if IsValid(ent) then
				flag = ent
				break
			end
		end
		if IsValid(flag) then break end
	end

	local zone, zonePos = get_capture_zone(IsValid(flag) and flag:GetPos() or bot:GetPos())
	if not (IsValid(zone) and isvector(zonePos)) then
		return TFBotSource.Actions.FetchFlag:Update(bot, st)
	end

	local toZone = zonePos - bot:GetPos()
	toZone.z = 0
	if toZone:Length() <= math.max(16, cv_capture_reached:GetFloat()) then
		return TFBotSource.Actions.FetchFlag:Update(bot, st)
	end

	TFBotSource.Core:SetActionTarget(bot, st, "push_to_capture_point", zone, zonePos)
	return true
end

return M

TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.CapturePoint = TFBotSource.Actions.CapturePoint or {}

local M = TFBotSource.Actions.CapturePoint

local function get_objective_pos(ent)
	if not IsValid(ent) then return nil end
	local pos = ent.GetPos and ent:GetPos() or nil
	if not isvector(pos) then return nil end
	if navmesh and navmesh.GetNearestNavArea then
		local area = navmesh.GetNearestNavArea(pos)
		if IsValid(area) then
			return area:GetCenter()
		end
	end
	return pos
end

local function team_can_capture_control_point(cp, teamNum)
	if not IsValid(cp) or not teamNum then return false end
	if cp.Locked == true then return false end
	if istable(cp.TeamCanCap) and cp.TeamCanCap[teamNum] ~= nil then
		return cp.TeamCanCap[teamNum] and true or false
	end
	local owner = tonumber((cp.GetOwnerTeam and cp:GetOwnerTeam()) or cp.OwnerTeam or (cp.Properties and cp.Properties.point_default_owner) or 0) or 0
	return owner ~= teamNum
end

local function get_control_point_owner_team(cp)
	if not IsValid(cp) then return 0 end
	return tonumber((cp.GetOwnerTeam and cp:GetOwnerTeam()) or cp.OwnerTeam or (cp.Properties and cp.Properties.point_default_owner) or 0) or 0
end

function M:Update(bot, st, profile)
	if not (IsValid(bot) and st) then return false end

	local teamNum = bot:Team()
	if teamNum ~= TEAM_RED and teamNum ~= TEAM_BLU then
		return false
	end

	local best, bestScore
	for _, trigger in ipairs(ents.FindByClass("trigger_capture_area")) do
		if not IsValid(trigger) then continue end
		local cp = trigger.CapturePoint
		if not IsValid(cp) then continue end
		if cp.Locked == true then continue end

		local ownerTeam = get_control_point_owner_team(cp)
		local canWeCap = team_can_capture_control_point(cp, teamNum)
		if ownerTeam == teamNum or not canWeCap then continue end

		local objectivePos = get_objective_pos(cp) or get_objective_pos(trigger)
		if not isvector(objectivePos) then continue end

		local score = bot:GetPos():DistToSqr(objectivePos)
		if not bestScore or score < bestScore then
			bestScore = score
			best = {
				targetEnt = cp,
				targetPos = objectivePos,
			}
		end
	end

	if not best then
		return TFBotSource.Actions.SeekAndDestroy:Update(bot, st, profile)
	end

	TFBotSource.Core:SetActionTarget(bot, st, "capture_point", best.targetEnt, best.targetPos)
	return true
end

return M

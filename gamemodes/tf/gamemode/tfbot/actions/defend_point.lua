TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.DefendPoint = TFBotSource.Actions.DefendPoint or {}

local M = TFBotSource.Actions.DefendPoint

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

local function get_enemy_team(teamNum)
	if teamNum == TEAM_RED then return TEAM_BLU end
	if teamNum == TEAM_BLU then return TEAM_RED end
	return TEAM_RED
end

local function count_team_occupants_near(ent, teamNum, fallbackPos)
	if not IsValid(ent) then return 0 end
	if istable(ent.Occupants) then
		local count = 0
		for ply in pairs(ent.Occupants) do
			if IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply:Team() == teamNum then
				count = count + 1
			end
		end
		return count
	end

	local pos = fallbackPos or get_objective_pos(ent)
	if not isvector(pos) then return 0 end

	local count = 0
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply:Team() == teamNum then
			if ply:GetPos():DistToSqr(pos) <= (420 * 420) then
				count = count + 1
			end
		end
	end
	return count
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

local function is_point_threatened(trigger, cp, bot)
	if not (IsValid(trigger) and IsValid(cp) and IsValid(bot)) then return false end
	local enemyTeam = get_enemy_team(bot:Team())
	local objectivePos = get_objective_pos(cp) or get_objective_pos(trigger)
	if count_team_occupants_near(trigger, enemyTeam, objectivePos) > 0 then
		return true
	end
	if cp.LastContestedAt and (CurTime() - tonumber(cp:LastContestedAt() or 0)) < 5 then
		return true
	end
	if cp.HasBeenContested and cp:HasBeenContested() and cp.LastContestedAt and (CurTime() - tonumber(cp:LastContestedAt() or 0)) < 5 then
		return true
	end
	return false
end

function M:Update(bot, st, profile)
	if not (IsValid(bot) and st) then return false end

	local teamNum = bot:Team()
	if teamNum ~= TEAM_RED and teamNum ~= TEAM_BLU then
		return false
	end

	local enemyTeam = get_enemy_team(teamNum)
	local best, bestScore
	for _, trigger in ipairs(ents.FindByClass("trigger_capture_area")) do
		if not IsValid(trigger) then continue end
		local cp = trigger.CapturePoint
		if not IsValid(cp) then continue end
		if cp.Locked == true then continue end

		local ownerTeam = get_control_point_owner_team(cp)
		local canEnemyCap = team_can_capture_control_point(cp, enemyTeam)
		if ownerTeam ~= teamNum or not canEnemyCap then continue end

		local objectivePos = get_objective_pos(cp) or get_objective_pos(trigger)
		if not isvector(objectivePos) then continue end

		local threatened = is_point_threatened(trigger, cp, bot)
		local score = bot:GetPos():DistToSqr(objectivePos)
		score = threatened and (score * 0.25) or (score * 0.75)

		if not bestScore or score < bestScore then
			bestScore = score
			best = {
				mode = threatened and "block_capture_point" or "defend_point",
				targetEnt = cp,
				targetPos = objectivePos,
			}
		end
	end

	if not best then
		return TFBotSource.Actions.SeekAndDestroy:Update(bot, st, profile)
	end

	TFBotSource.Core:SetActionTarget(bot, st, best.mode, best.targetEnt, best.targetPos)
	return true
end

return M

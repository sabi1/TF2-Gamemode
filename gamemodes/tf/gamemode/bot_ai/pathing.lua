TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.Pathing = TFBotValveAI.Pathing or {}

local M = TFBotValveAI.Pathing

local cv_nav_budget_ms = CreateConVar("tf_bot_nav_budget_ms", "1.50", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_mvm_anchor_bias = CreateConVar("tf_bot_mvm_anchor_bias", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_hard_recover = CreateConVar("tf_bot_hard_recover_enable", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Deprecated. Teleport-based stuck recovery is disabled to avoid bots warping through walls.")
local cv_stuck_backoff = CreateConVar("tf_bot_stuck_backoff_time", "0.45", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How long bots use a gentle non-teleport unstuck shim after repeated wall/path stalls.")
local cv_no_route_probe_speed = CreateConVar("tf_bot_no_route_probe_speed", "140", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Forward speed used when a bot has no route and is probing for a valid path.")
local navBudget = {
	window = 0,
	used = 0,
}

local CONTENTS_WINDOW_MASK = rawget(_G, "CONTENTS_WINDOW") or 2
local PLAYER_SOLID_WITH_WINDOWS = bit.bor(rawget(_G, "MASK_PLAYERSOLID") or 0, CONTENTS_WINDOW_MASK)

local function fmtVec(v)
	if not isvector(v) then return "nil" end
	return string.format("(%.0f %.0f %.0f)", v.x, v.y, v.z)
end

local function isNearOrigin(v)
	if not isvector(v) then return true end
	return math.abs(v.x) <= 1 and math.abs(v.y) <= 1 and math.abs(v.z) <= 1
end

local function getEntGoalPos(ent, fallback)
	if not IsValid(ent) then return fallback end
	local pos = nil
	if ent.WorldSpaceCenter then
		local ok, v = pcall(ent.WorldSpaceCenter, ent)
		if ok and isvector(v) then
			pos = v
		end
	end
	if (not isvector(pos) or isNearOrigin(pos)) and ent.OBBCenter and ent.LocalToWorld then
		local okCenter, center = pcall(ent.OBBCenter, ent)
		if okCenter and isvector(center) then
			local okWorld, world = pcall(ent.LocalToWorld, ent, center)
			if okWorld and isvector(world) then
				pos = world
			end
		end
	end
	if (not isvector(pos) or isNearOrigin(pos)) and ent.GetPos then
		local ok, v = pcall(ent.GetPos, ent)
		if ok and isvector(v) then
			pos = v
		end
	end
	if isvector(pos) and not isNearOrigin(pos) then
		return pos
	end
	return fallback
end

local function debugLog(bot, key, interval, msg)
	local cfg = TFBotValveAI and TFBotValveAI.Config or nil
	if not (cfg and cfg.IsDebug and cfg:IsDebug()) then return end
	if not IsValid(bot) then return end
	bot._tfbotDbgNext = bot._tfbotDbgNext or {}
	local now = CurTime()
	local nextAt = tonumber(bot._tfbotDbgNext[key] or 0)
	if now < nextAt then return end
	bot._tfbotDbgNext[key] = now + (tonumber(interval) or 0.5)
	cfg:Debug(string.format(
		"bot=%s[%d] %s",
		tostring(bot:Nick()),
		bot:EntIndex(),
		tostring(msg)
	))
end

local function getFriendlySpawnAttributeForBot(bot)
	if not IsValid(bot) then return nil end
	if bot:Team() == TEAM_RED then
		return "spawn_room_red"
	end
	if bot:Team() == TEAM_BLU or bot:Team() == TF_TEAM_PVE_INVADERS then
		return "spawn_room_blue"
	end
	return nil
end

local function hasAreaTFAttribute(area, attrName)
	if not IsValid(area) or not isstring(attrName) or attrName == "" then return false end
	if not area.HasTFAttribute then return false end
	return area:HasTFAttribute(attrName) == true
end

local function getNearestAreaForTeam(pos, team)
	if not navmesh or not navmesh.GetNearestNavArea then return nil end
	local area = navmesh.GetNearestNavArea(pos, true, 10000, true, true, team)
	if IsValid(area) then return area end
	return navmesh.GetNearestNavArea(pos, true, 10000, true, true)
end

local function getAreaSteerPos(area, fromPos, fallbackPos)
	if not IsValid(area) then
		return fallbackPos or fromPos
	end

	local steerPos = area:GetCenter()
	if area.GetClosestPointOnArea and fromPos then
		local ok, closest = pcall(area.GetClosestPointOnArea, area, fromPos)
		if ok and isvector(closest) then
			steerPos = closest
		end
	end
	return steerPos
end

local function shouldForceJumpAtObstacle(bot, targetAng)
	if not IsValid(bot) or not bot:IsOnGround() then return false end
	local startPos = bot:GetPos() + Vector(0, 0, 8)
	local tr = util.TraceHull({
		start = startPos,
		endpos = startPos + targetAng:Forward() * 42,
		filter = bot,
		mask = PLAYER_SOLID_WITH_WINDOWS,
		mins = Vector(-16, -16, 0),
		maxs = Vector(16, 16, 48),
	})
	if not tr.Hit then return false end
	return tr.HitNormal.z <= 0.65
end

local function isDoorEntity(ent)
	if not IsValid(ent) then return false end
	local class = string.lower(tostring(ent:GetClass() or ""))
	return string.find(class, "prop_door", 1, true) ~= nil
		or string.find(class, "func_door", 1, true) ~= nil
end

local function isBreakableObstacle(ent)
	if not IsValid(ent) then return false end
	local class = string.lower(tostring(ent:GetClass() or ""))
	if class == "func_breakable" or class == "func_breakable_surf" then
		return true
	end
	if string.find(class, "breakable", 1, true) ~= nil then
		return true
	end
	if (string.find(class, "prop_physics", 1, true) ~= nil or string.find(class, "func_physbox", 1, true) ~= nil)
		and ent.Health and tonumber(ent:Health() or 0) > 0 then
		return true
	end
	return false
end

local function isDynamicBarricadeEntity(ent)
	if not IsValid(ent) then return false end
	local class = string.lower(tostring(ent:GetClass() or ""))
	if class == "func_brush" or class == "func_door" or class == "func_door_rotating" or class == "func_movelinear" then
		return true
	end
	if class == "prop_dynamic" or class == "prop_dynamic_override" then
		return true
	end
	if string.find(class, "barricade", 1, true) or string.find(class, "barrier", 1, true) then
		return true
	end
	return false
end

local function traceObstacleAhead(bot, targetAng, distance, height)
	if not IsValid(bot) then return nil end
	local tr = util.TraceHull({
		start = bot:GetPos() + Vector(0, 0, tonumber(height) or 18),
		endpos = bot:GetPos() + Vector(0, 0, tonumber(height) or 18) + targetAng:Forward() * (tonumber(distance) or 56),
		filter = bot,
		mask = PLAYER_SOLID_WITH_WINDOWS,
		mins = Vector(-16, -16, 0),
		maxs = Vector(16, 16, 56),
	})
	if not tr.Hit then return nil end

	local ent = tr.Entity
	if IsValid(ent) then
		if ent:IsPlayer() or ent:IsNPC() then
			return nil
		end
		if isDoorEntity(ent) then
			return {
				kind = "door",
				ent = ent,
				trace = tr,
			}
		end
		if isBreakableObstacle(ent) then
			return {
				kind = "breakable",
				ent = ent,
				trace = tr,
			}
		end
		if isDynamicBarricadeEntity(ent) then
			return {
				kind = "barricade",
				ent = ent,
				trace = tr,
			}
		end
	end

	return {
		kind = "solid",
		ent = ent,
		trace = tr,
	}
end

local function traceDynamicBarricadeAhead(bot, targetAng)
	local obstacle = traceObstacleAhead(bot, targetAng, 56, 18)
	if not obstacle or obstacle.kind ~= "barricade" then return nil end
	return obstacle.ent, obstacle.trace
end

local resetPathState

local function computeBarricadeHoldPos(bot, blocker, targetPos)
	if not IsValid(bot) or not IsValid(blocker) then return nil end
	local mins, maxs = blocker:WorldSpaceAABB()
	if not (isvector(mins) and isvector(maxs)) then return nil end

	local center = (mins + maxs) * 0.5
	local away = bot:GetPos() - center
	away.z = 0
	if away:LengthSqr() < 1 then
		away = isvector(targetPos) and (center - targetPos) or Vector(1, 0, 0)
		away.z = 0
	end
	if away:LengthSqr() < 1 then
		away = Vector(1, 0, 0)
	end
	away:Normalize()

	local lateral = Vector(-away.y, away.x, 0)
	local side = (bot:EntIndex() % 2 == 0) and 1 or -1
	local clearance = math.max(maxs.x - mins.x, maxs.y - mins.y, 48)

	local holdPos = center + away * (clearance * 0.65 + 96) + lateral * side * (clearance * 0.25 + 56)
	holdPos.z = bot:GetPos().z
	return holdPos
end

local function isPointInsideExpandedAABB(pos, mins, maxs, expand)
	expand = tonumber(expand) or 0
	return pos.x >= (mins.x - expand) and pos.x <= (maxs.x + expand)
		and pos.y >= (mins.y - expand) and pos.y <= (maxs.y + expand)
		and pos.z >= (mins.z - expand) and pos.z <= (maxs.z + expand)
end

local function traceHitsSpecificBlocker(bot, startPos, endPos, blocker)
	if not (IsValid(bot) and isvector(startPos) and isvector(endPos) and IsValid(blocker)) then
		return false
	end
	local tr = util.TraceHull({
		start = startPos,
		endpos = endPos,
		filter = bot,
		mask = PLAYER_SOLID_WITH_WINDOWS,
		mins = Vector(-16, -16, 0),
		maxs = Vector(16, 16, 56),
	})
	return tr.Hit and tr.Entity == blocker
end

local function getAreaListBetween(startArea, goalArea, parentsById)
	if not (IsValid(startArea) and IsValid(goalArea) and istable(parentsById)) then return nil end
	local path = {goalArea}
	local cursorId = goalArea:GetID()
	local guard = 0
	while cursorId ~= startArea:GetID() and guard < 512 do
		local parentId = parentsById[cursorId]
		if not parentId then return nil end
		local parentArea = navmesh.GetNavAreaByID and navmesh.GetNavAreaByID(parentId) or nil
		if not IsValid(parentArea) then return nil end
		table.insert(path, 1, parentArea)
		cursorId = parentId
		guard = guard + 1
	end
	return path
end

local function getWaypointFromAreaPath(bot, blocker, targetPos, areaPath)
	if not (IsValid(bot) and IsValid(blocker) and isvector(targetPos) and istable(areaPath) and #areaPath >= 2) then
		return nil
	end

	local origin = bot:GetPos()
	local originDist = origin:DistToSqr(targetPos)
	local startIndex = math.min(2, #areaPath)
	for i = startIndex, #areaPath do
		local area = areaPath[i]
		if not IsValid(area) then continue end
		local center = area:GetCenter()
		if origin:DistToSqr(center) <= (72 * 72) then continue end
		if center:DistToSqr(targetPos) >= (originDist - (96 * 96)) then continue end
		if not traceHitsSpecificBlocker(bot, center + Vector(0, 0, 18), targetPos + Vector(0, 0, 18), blocker) then
			return center
		end
	end

	local fallbackIndex = math.min(math.max(2, math.floor(#areaPath * 0.5)), #areaPath)
	local fallbackArea = areaPath[fallbackIndex]
	return IsValid(fallbackArea) and fallbackArea:GetCenter() or nil
end

local function computeBarricadeRouteDetourPos(bot, blocker, targetPos)
	if not (IsValid(bot) and IsValid(blocker) and isvector(targetPos)) then return nil end
	if not (navmesh and navmesh.GetNearestNavArea and navmesh.GetNavAreaByID) then return nil end

	local startArea = getNearestAreaForTeam(bot:GetPos(), bot:Team())
	local goalArea = getNearestAreaForTeam(targetPos, bot:Team())
	if not (IsValid(startArea) and IsValid(goalArea)) then return nil end
	if startArea == goalArea then return nil end

	local mins, maxs = blocker:WorldSpaceAABB()
	if not (isvector(mins) and isvector(maxs)) then return nil end

	local frontier = {startArea}
	local frontierScores = {[startArea:GetID()] = 0}
	local costSoFar = {[startArea:GetID()] = 0}
	local parentsById = {}
	local visited = {}
	local targetDir = targetPos - bot:GetPos()
	targetDir.z = 0
	local targetDirNorm = targetDir:LengthSqr() > 1 and targetDir:GetNormalized() or Vector(1, 0, 0)
	local expandedAABB = 72
	local maxVisited = (string.lower(game.GetMap() or "") == "mvm_rottenburg") and 420 or 260

	local function canUseArea(area)
		if not IsValid(area) then return false end
		local center = area:GetCenter()
		if math.abs(center.z - bot:GetPos().z) > 320 then return false end
		if isPointInsideExpandedAABB(center, mins, maxs, expandedAABB) then return false end
		local toArea = center - bot:GetPos()
		toArea.z = 0
		if toArea:LengthSqr() > 1 then
			local dot = toArea:GetNormalized():Dot(targetDirNorm)
			if dot < -0.25 then
				return false
			end
		end
		return true
	end

	local function edgeBlocked(fromArea, toArea)
		if not (IsValid(fromArea) and IsValid(toArea)) then return true end
		return traceHitsSpecificBlocker(bot, fromArea:GetCenter() + Vector(0, 0, 18), toArea:GetCenter() + Vector(0, 0, 18), blocker)
	end

	while #frontier > 0 and table.Count(visited) < maxVisited do
		table.sort(frontier, function(a, b)
			return (frontierScores[a:GetID()] or math.huge) < (frontierScores[b:GetID()] or math.huge)
		end)

		local current = table.remove(frontier, 1)
		local currentId = current:GetID()
		if not visited[currentId] then
			visited[currentId] = true

			if current == goalArea then
				local areaPath = getAreaListBetween(startArea, goalArea, parentsById)
				local waypoint = getWaypointFromAreaPath(bot, blocker, targetPos, areaPath)
				if isvector(waypoint) then
					return waypoint
				end
			end

			local adjacent = current.GetAdjacentAreas and current:GetAdjacentAreas() or nil
			if istable(adjacent) then
				for _, neighbor in ipairs(adjacent) do
					if not canUseArea(neighbor) then continue end
					if edgeBlocked(current, neighbor) then continue end

					local neighborId = neighbor:GetID()
					local stepCost = current:GetCenter():Distance(neighbor:GetCenter())
					local candidateCost = (costSoFar[currentId] or 0) + stepCost
					if candidateCost >= (costSoFar[neighborId] or math.huge) then continue end

					costSoFar[neighborId] = candidateCost
					parentsById[neighborId] = currentId

					local heuristic = neighbor:GetCenter():Distance(targetPos)
					local neighborCenter = neighbor:GetCenter()
					local progressBonus = math.max(0, bot:GetPos():Distance(targetPos) - neighborCenter:Distance(targetPos))
					frontierScores[neighborId] = candidateCost + heuristic - math.min(progressBonus * 0.35, 220)
					table.insert(frontier, neighbor)
				end
			end
		end
	end

	return nil
end

local function computeBarricadeDetourPos(bot, blocker, targetPos)
	if not (IsValid(bot) and IsValid(blocker) and isvector(targetPos)) then return nil end
	local routeDetour = computeBarricadeRouteDetourPos(bot, blocker, targetPos)
	if isvector(routeDetour) then
		return routeDetour
	end
	if not (navmesh and navmesh.GetAllNavAreas) then
		return computeBarricadeHoldPos(bot, blocker, targetPos)
	end

	local mins, maxs = blocker:WorldSpaceAABB()
	if not (isvector(mins) and isvector(maxs)) then
		return computeBarricadeHoldPos(bot, blocker, targetPos)
	end

	local origin = bot:GetPos()
	local blockerCenter = (mins + maxs) * 0.5
	local direct = targetPos - origin
	direct.z = 0
	local directNorm = direct:LengthSqr() > 1 and direct:GetNormalized() or Vector(1, 0, 0)
	local originTargetDist = origin:DistToSqr(targetPos)
	local forwardDotMin = (string.lower(game.GetMap() or "") == "mvm_rottenburg") and 0.20 or -0.10
	local minProgressGain = (string.lower(game.GetMap() or "") == "mvm_rottenburg") and (180 * 180) or (96 * 96)

	local bestPos, bestScore
	for _, area in ipairs(navmesh.GetAllNavAreas()) do
		if not IsValid(area) then continue end
		local center = area:GetCenter()
		if math.abs(center.z - origin.z) > 220 then continue end
		if origin:DistToSqr(center) > (1600 * 1600) then continue end
		if center:DistToSqr(blockerCenter) > (2200 * 2200) then continue end
		if isPointInsideExpandedAABB(center, mins, maxs, 56) then continue end

		local toCenter = center - origin
		toCenter.z = 0
		if toCenter:LengthSqr() <= (80 * 80) then continue end

		local forwardDot = toCenter:GetNormalized():Dot(directNorm)
		if forwardDot < forwardDotMin then continue end
		local progressGain = originTargetDist - center:DistToSqr(targetPos)
		if progressGain < minProgressGain then continue end
		if traceHitsSpecificBlocker(bot, origin + Vector(0, 0, 18), center + Vector(0, 0, 18), blocker) then continue end
		if traceHitsSpecificBlocker(bot, center + Vector(0, 0, 18), targetPos + Vector(0, 0, 18), blocker) then continue end

		local score = origin:DistToSqr(center) * 0.45 + center:DistToSqr(targetPos) * 0.75 - progressGain * 0.35 - math.max(0, forwardDot) * 50000
		if not bestScore or score < bestScore then
			bestScore = score
			bestPos = center
		end
	end

	return bestPos or computeBarricadeHoldPos(bot, blocker, targetPos)
end

local function clearBarricadeState(st)
	st.path.blockerEntIndex = -1
	st.path.blockerClass = nil
	st.path.blockerHits = 0
	st.path.blockedUntil = 0
	st.path.blockedTargetPos = nil
end

local function clearBreakableState(st)
	st.path.breakableEntIndex = -1
	st.path.breakableUntil = 0
	st.path.breakableTargetPos = nil
end

local function isBarricadeStillBlocking(bot, st, targetPos)
	if not (IsValid(bot) and st and st.path) then return false end
	local entIndex = tonumber(st.path.blockerEntIndex or -1)
	if entIndex < 0 then return false end
	local blocker = Entity(entIndex)
	if not IsValid(blocker) then return false end
	if not isDynamicBarricadeEntity(blocker) then return false end
	if not isvector(targetPos) then return false end

	return traceHitsSpecificBlocker(bot, bot:GetPos() + Vector(0, 0, 18), targetPos + Vector(0, 0, 18), blocker)
end

local function startBarricadeHold(bot, st, blocker, now, targetPos)
	st.path.blockerEntIndex = IsValid(blocker) and blocker:EntIndex() or -1
	st.path.blockerClass = IsValid(blocker) and tostring(blocker:GetClass() or "unknown") or "unknown"
	st.path.blockerHits = tonumber(st.path.blockerHits or 0) + 1
	st.path.blockedUntil = now + math.min(1.5 + (st.path.blockerHits * 0.6), 5.5)
	st.path.blockedTargetPos = computeBarricadeDetourPos(bot, blocker, targetPos) or bot:GetPos()
	st.path.nextRepath = math.max(tonumber(st.path.nextRepath or 0), st.path.blockedUntil)
	st.path.route = nil
	resetPathState(st)
	debugLog(bot, "path_blocked_barricade", 0.45, string.format(
		"blocked=dynamic_barricade class=%s hits=%d pos=%s detour=%s target=%s",
		tostring(st.path.blockerClass),
		tonumber(st.path.blockerHits) or 0,
		fmtVec(bot:GetPos()),
		fmtVec(st.path.blockedTargetPos),
		fmtVec(targetPos)
	))
end

local function applyBarricadeHold(bot, cmd, st, now)
	if now >= tonumber(st.path.blockedUntil or 0) then
		clearBarricadeState(st)
		return false
	end
	local detourPos = st.path.blockedTargetPos
	if not isvector(detourPos) then
		cmd:SetForwardMove(-40)
		cmd:SetSideMove(0)
		cmd:RemoveKey(IN_JUMP)
		return true
	end

	local dir = detourPos - bot:GetPos()
	dir.z = 0
	if dir:LengthSqr() <= (42 * 42) then
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		return true
	end

	local ang = dir:GetNormalized():Angle()
	cmd:SetViewAngles(ang)
	cmd:SetForwardMove(220)
	cmd:SetSideMove(0)
	cmd:RemoveKey(IN_JUMP)
	return true
end

local function startStaticObstacleAvoid(bot, st, trace, now, targetPos)
	if not (IsValid(bot) and st and st.path and trace and trace.HitNormal) then return end
	local normal = Vector(trace.HitNormal.x, trace.HitNormal.y, 0)
	if normal:LengthSqr() <= 0.001 then
		normal = -bot:GetForward()
		normal.z = 0
	end
	normal:Normalize()

	local lateral = Vector(-normal.y, normal.x, 0)
	local toTarget = isvector(targetPos) and (targetPos - bot:GetPos()) or bot:GetForward()
	toTarget.z = 0
	local sideSign = (toTarget:Dot(lateral) >= 0) and 1 or -1
	local detourPos = bot:GetPos() + normal * 42 + lateral * (sideSign * 96)
	detourPos.z = bot:GetPos().z

	st.path.blockerEntIndex = IsValid(trace.Entity) and trace.Entity:EntIndex() or -1
	st.path.blockerClass = trace.HitWorld and "world" or tostring(IsValid(trace.Entity) and trace.Entity:GetClass() or "solid")
	st.path.blockerHits = tonumber(st.path.blockerHits or 0) + 1
	st.path.blockedUntil = now + 0.55
	st.path.blockedTargetPos = detourPos
	st.path.nextRepath = 0
	st.path.route = nil
	resetPathState(st)
	debugLog(bot, "path_blocked_solid", 0.35, string.format(
		"blocked=solid class=%s hitpos=%s detour=%s target=%s",
		tostring(st.path.blockerClass),
		fmtVec(trace.HitPos),
		fmtVec(detourPos),
		fmtVec(targetPos)
	))
end

local function startBreakablePush(bot, st, obstacle, now)
	if not (IsValid(bot) and st and st.path and obstacle and IsValid(obstacle.ent)) then return end
	st.path.breakableEntIndex = obstacle.ent:EntIndex()
	st.path.breakableUntil = now + 1.2
	st.path.breakableTargetPos = getEntGoalPos(obstacle.ent, obstacle.trace and obstacle.trace.HitPos or obstacle.ent:GetPos())
end

local function applyBreakablePush(bot, cmd, st, now)
	if now >= tonumber(st.path.breakableUntil or 0) then
		clearBreakableState(st)
		return false
	end

	local entIndex = tonumber(st.path.breakableEntIndex or -1)
	if entIndex < 0 then
		clearBreakableState(st)
		return false
	end

	local blocker = Entity(entIndex)
	if not IsValid(blocker) then
		clearBreakableState(st)
		return false
	end

	local aimPos = getEntGoalPos(blocker, st.path.breakableTargetPos)
	if not isvector(aimPos) then
		clearBreakableState(st)
		return false
	end

	local dir = aimPos - bot:GetPos()
	dir.z = 0
	if dir:LengthSqr() <= (42 * 42) then
		cmd:SetForwardMove(0)
	else
		cmd:SetForwardMove(120)
	end
	cmd:SetSideMove(0)
	if dir:LengthSqr() > 0.001 then
		cmd:SetViewAngles(dir:GetNormalized():Angle())
	end
	return true
end

resetPathState = function(st)
	st.path.targetArea = nil
	st.path.segmentAreaId = nil
	st.path.segmentBestDist = nil
	st.path.segmentBestStamp = nil
	st.path.stuckSince = nil
end

local function startSoftStuckRecover(bot, st, now)
	st.path.unstuckUntil = now + math.max(0.1, cv_stuck_backoff:GetFloat())
	st.path.unstuckSide = (bot:EntIndex() % 2 == 0) and 1 or -1
end

local function applySoftStuckRecover(bot, cmd, st, now)
	if now >= tonumber(st.path.unstuckUntil or 0) then
		return false
	end

	local side = tonumber(st.path.unstuckSide or 1)
	local b = cmd:GetButtons()
	cmd:SetButtons(bit.bor(b, IN_JUMP))
	cmd:SetForwardMove(-120)
	cmd:SetSideMove(180 * side)
	return true
end

local function tryHardRecover(bot, st, targetPos, now)
	st.path.nextHardRecoverAt = tonumber(st.path.nextHardRecoverAt or 0)
	if now < st.path.nextHardRecoverAt then return false end

	st.path.route = nil
	resetPathState(st)
	st.path.nextRepath = 0
	st.path.nextHardRecoverAt = now + 1.25
	startSoftStuckRecover(bot, st, now)
	debugLog(bot, "path_hard_recover_disabled", 0.35, string.format(
		"hard_recover=disabled repath_only pos=%s target=%s routeType=%s convar=%s",
		fmtVec(bot:GetPos()),
		fmtVec(targetPos),
		tostring(bot.routeType),
		tostring(cv_hard_recover:GetBool())
	))
	return false
end

local function isMvMMap()
	return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

local function getBombIntel()
	local world = TFBotValveAI and TFBotValveAI.World or nil
	for _, intel in ipairs(world and world:GetEntitiesByClass("item_teamflag_mvm", 0.20) or ents.FindByClass("item_teamflag_mvm")) do
		if IsValid(intel) then return intel end
	end
	return nil
end

local function getDeployZonePos()
	local world = TFBotValveAI and TFBotValveAI.World or nil
	for _, zone in ipairs(world and world:GetEntitiesByClass("func_capturezone", 0.20) or ents.FindByClass("func_capturezone")) do
		if IsValid(zone) then
			local pos = getEntGoalPos(zone, nil)
			if isvector(pos) then
				return pos
			end
		end
	end
	return nil
end

local function getMvMNavObjectiveAnchor(bot)
	if not IsValid(bot) or not isMvMMap() then return nil end
	local now = CurTime()
	if bot._mvmNavAnchor and bot._mvmNavAnchorUntil and bot._mvmNavAnchorUntil > now then
		return bot._mvmNavAnchor
	end

	local anchor
	local deployPos = getDeployZonePos()
	local bombIntel = getBombIntel()
	local bombCarrier = IsValid(bombIntel) and bombIntel.Carrier or nil
	local isInvader = bot:Team() == TEAM_BLU or bot:Team() == TF_TEAM_PVE_INVADERS or bot.IsMVMRobot == true

	if isInvader then
		if IsValid(bombCarrier) then
			if bombCarrier:EntIndex() == bot:EntIndex() then
				anchor = deployPos
			else
				anchor = bombCarrier:GetPos()
			end
		elseif IsValid(bombIntel) then
			anchor = bombIntel:GetPos()
		else
			anchor = deployPos
		end
	elseif bot:Team() == TEAM_RED then
		if IsValid(bombCarrier) and not bombCarrier:IsFriendly(bot) then
			anchor = bombCarrier:GetPos()
		else
			anchor = deployPos
		end
	end

	if anchor and navmesh and navmesh.GetNearestNavArea then
		local navArea = navmesh.GetNearestNavArea(anchor)
		if IsValid(navArea) then
			anchor = navArea:GetCenter()
		end
	end

	bot._mvmNavAnchor = anchor
	bot._mvmNavAnchorUntil = now + 0.25
	return anchor
end

local function getSpawnExitTargetPos(bot)
	if not IsValid(bot) or not navmesh or not navmesh.GetAllNavAreas then return nil end
	local spawnAttr = getFriendlySpawnAttributeForBot(bot)
	if not spawnAttr then return nil end

	local now = CurTime()
	if bot._mvmSpawnExitPos and bot._mvmSpawnExitUntil and bot._mvmSpawnExitUntil > now then
		return bot._mvmSpawnExitPos
	end

	local origin = bot:GetPos()
	local bestPos, bestDist
	for _, area in ipairs(navmesh.GetAllNavAreas()) do
		if not IsValid(area) then continue end
		if hasAreaTFAttribute(area, spawnAttr) then continue end
		local center = area:GetCenter()
		local dz = math.abs(center.z - origin.z)
		if dz > 700 then continue end
		local d = origin:DistToSqr(center)
		if not bestDist or d < bestDist then
			bestDist = d
			bestPos = center
		end
	end

	bot._mvmSpawnExitPos = bestPos
	bot._mvmSpawnExitUntil = now + 0.8
	return bestPos
end

function M:ComputePathCost(bot, area, fromArea, ladder, length)
	if not fromArea then return 0 end
	local relaxCarrierBias = (bot.routeType == "mvm_bomb_carrier") and (CurTime() < tonumber(bot._tfbotMvmRelaxRouteBiasUntil or 0))
	local dist = length and length > 0 and length or (ladder and ladder:GetLength()) or area:GetCenter():Distance(fromArea:GetCenter())

	local deltaZ = fromArea:ComputeAdjacentConnectionHeightChange(area)
	if deltaZ >= 64 then return -1 end
	if deltaZ < -64 then return -1 end
	if deltaZ >= 16 then
		dist = dist * 2.0
	end

	local isBlueSide = (bot:Team() == TEAM_BLU or bot:Team() == TF_TEAM_PVE_INVADERS)
	if (bot:Team() == TEAM_RED and area.HasTFAttribute and area:HasTFAttribute("spawn_room_blue")) or
		(isBlueSide and area.HasTFAttribute and area:HasTFAttribute("spawn_room_red")) then
		return -1
	end

	if bot.routeType == "safest" then
		if area.GetCombatIntensity then
			dist = dist * math.max(1, area:GetCombatIntensity() * 4)
		end
	end

	if bot.routeType == "mvm_bomb_carrier" and area.GetCombatIntensity then
		local intensity = math.max(area:GetCombatIntensity(), 0)
		local mult = relaxCarrierBias and 1.15 or 2.05
		dist = dist * math.max(1.0, 1.0 + (intensity * mult))
	end

	if cv_mvm_anchor_bias:GetBool() and isMvMMap() and IsValid(fromArea) then
		local anchor = getMvMNavObjectiveAnchor(bot)
		if anchor then
			local areaDist = area:GetCenter():DistToSqr(anchor)
			local fromDist = fromArea:GetCenter():DistToSqr(anchor)
			if bot.routeType == "mvm_bomb_carrier" then
				if areaDist > fromDist then
					dist = dist * (relaxCarrierBias and 1.20 or 2.35)
				else
					dist = dist * (relaxCarrierBias and 0.90 or 0.72)
				end
			elseif bot.routeType == "mvm_push" or bot.routeType == "mvm_flank" then
				if areaDist > fromDist then
					dist = dist * 1.45
				else
					dist = dist * 0.92
				end
			end
		end
	end

	if area.HasAttributes and area:HasAttributes(NAV_MESH_FUNC_COST) and area.ComputeFuncNavCost then
		dist = dist * area:ComputeFuncNavCost(bot)
	end

	return dist + (fromArea.GetCostSoFar and fromArea:GetCostSoFar() or 0)
end

function M:ResolveTargetPos(bot, state)
	if not IsValid(bot) or not state then return nil end
	if state.path and tonumber(state.path.blockerEntIndex or -1) >= 0 then
		local now = CurTime and CurTime() or 0
		local realTarget = state.objective and state.objective.targetPos or nil
		if isBarricadeStillBlocking(bot, state, realTarget) then
			state.path.blockedUntil = math.max(tonumber(state.path.blockedUntil or 0), now + 1.0)
			if not isvector(state.path.blockedTargetPos) or bot:GetPos():DistToSqr(state.path.blockedTargetPos) <= (80 * 80) or now >= tonumber(state.path.blockedUntil or 0) - 0.2 then
				local blocker = Entity(tonumber(state.path.blockerEntIndex or -1))
				if IsValid(blocker) then
					state.path.blockedTargetPos = computeBarricadeDetourPos(bot, blocker, realTarget) or state.path.blockedTargetPos
				end
			end
			if isvector(state.path.blockedTargetPos) then
				return state.path.blockedTargetPos
			end
		else
			clearBarricadeState(state)
		end
	end
	local target = state.objective.targetPos
	if IsValid(state.objective.targetEnt) then
		target = getEntGoalPos(state.objective.targetEnt, target)
		state.objective.targetPos = target
	end
	if isNearOrigin(target) then
		target = nil
	end
	if not isvector(target) and isvector(state.objective.lastValidTargetPos) then
		target = state.objective.lastValidTargetPos
	end
	if isvector(target) then
		state.objective.lastValidTargetPos = target
	end
	return target
end

function M:NeedRepath(bot, state, now)
	if not IsValid(bot) or not state then return false end
	if not istable(state.path.route) then
		return true
	end

	local routeType = tostring(bot.routeType or "default")
	if tostring(state.path.lastRouteType or "") ~= routeType then
		return true
	end

	local targetPos = state.objective and state.objective.targetPos or nil
	local lastTargetPos = state.path.lastBuildTargetPos
	if isvector(targetPos) and isvector(lastTargetPos) then
		local shift2 = targetPos:DistToSqr(lastTargetPos)
		local threshold = (routeType == "fastest" and 80 or 140)
		if shift2 >= (threshold * threshold) then
			return true
		end
	elseif isvector(targetPos) ~= isvector(lastTargetPos) then
		return true
	end

	local targetEnt = state.objective and state.objective.targetEnt or nil
	local lastTargetEntIndex = tonumber(state.path.lastTargetEntIndex or -1)
	local targetEntIndex = IsValid(targetEnt) and targetEnt:EntIndex() or -1
	if targetEntIndex ~= lastTargetEntIndex then
		return true
	end

	return now >= (state.path.nextRepath or 0)
end

function M:RefreshRepathDeadline(state, now)
	state.path.nextRepath = now + TFBotValveAI.Perf:GetInterval("repath")
end

function M:BuildPath(bot, state, targetPos, now)
	if not IsValid(bot) or not state or not isvector(targetPos) then return false end
	if not isfunction(AstarVector) then
		return false
	end

	local budgetMs = math.max(cv_nav_budget_ms:GetFloat(), 0.25)
	local window = math.floor(now * 20)
	if navBudget.window ~= window then
		navBudget.window = window
		navBudget.used = 0
	end
	if navBudget.used >= budgetMs then
		return false
	end

	local t0 = SysTime()
	local route = AstarVector(bot, bot:GetPos(), targetPos)
	navBudget.used = navBudget.used + ((SysTime() - t0) * 1000)
	if not istable(route) or #route < 1 then
		state.path.consecutiveBuildFails = tonumber(state.path.consecutiveBuildFails or 0) + 1
		state.path.route = nil
		resetPathState(state)
		state.path.nextRepath = now + math.min(0.9 + (state.path.consecutiveBuildFails * 0.35), 2.5)
		return false
	end

	table.remove(route) -- remove the current area just like legacy movement
	state.path.route = route
	state.path.consecutiveBuildFails = 0
	state.path.lastRepath = now
	state.path.lastRepathTry = now
	state.path.lastBuildTargetPos = targetPos
	state.path.lastTargetEntIndex = IsValid(state.objective and state.objective.targetEnt or nil) and state.objective.targetEnt:EntIndex() or -1
	state.path.lastRouteType = tostring(bot.routeType or "default")
	resetPathState(state)
	return true
end

local function progressMonitor(bot, cmd, st, distToArea, targetPos)
	local areaId = st.path.targetArea:GetID()
	local now = CurTime()
	st.path.stuckEvents = tonumber(st.path.stuckEvents or 0)
	st.path.stuckEventWindowAt = tonumber(st.path.stuckEventWindowAt or 0)
	local blockerEnt, blockerTrace = traceDynamicBarricadeAhead(bot, bot:EyeAngles())
	if now - st.path.stuckEventWindowAt > 6.0 then
		st.path.stuckEvents = 0
	end

	if st.path.segmentAreaId ~= areaId then
		st.path.segmentAreaId = areaId
		st.path.segmentBestDist = distToArea
		st.path.segmentBestStamp = now
	elseif distToArea + 8 < (st.path.segmentBestDist or math.huge) then
		st.path.segmentBestDist = distToArea
		st.path.segmentBestStamp = now
	elseif now - (st.path.segmentBestStamp or now) > 0.85 and bot:IsOnGround() then
		if IsValid(blockerEnt) then
			startBarricadeHold(bot, st, blockerEnt, now, targetPos)
			if blockerTrace and blockerTrace.Normal then
				cmd:SetViewAngles((targetPos - bot:GetPos()):Angle())
			end
			return true
		end
		st.path.route = nil
		resetPathState(st)
		st.path.nextRepath = 0
		debugLog(bot, "path_stuck_segment", 0.45, string.format(
			"stuck=segment area=%s dist=%.1f routeType=%s",
			tostring(areaId),
			tonumber(distToArea) or -1,
			tostring(bot.routeType)
		))
		if bot.routeType == "mvm_bomb_carrier" then
			bot._tfbotMvmRelaxRouteBiasUntil = math.max(tonumber(bot._tfbotMvmRelaxRouteBiasUntil or 0), now + 2.5)
		end
		st.path.stuckEvents = st.path.stuckEvents + 1
		st.path.stuckEventWindowAt = now
		startSoftStuckRecover(bot, st, now)
		if st.path.stuckEvents >= 4 and tryHardRecover(bot, st, targetPos, now) then
			debugLog(bot, "path_stuck_escalate", 0.45, string.format(
				"stuck_escalate=hard_recover events=%d",
				tonumber(st.path.stuckEvents) or 0
			))
			st.path.stuckEvents = 0
			return true
		end
		local b = cmd:GetButtons()
		cmd:SetButtons(bit.bor(b, IN_JUMP))
		cmd:SetForwardMove(120)
		cmd:SetSideMove((bot:EntIndex() % 2 == 0) and 220 or -220)
		return true
	end

	local speed2D = bot:GetVelocity():Length2D()
	if bot:IsOnGround() and distToArea > 120 and speed2D < 28 then
		st.path.stuckSince = st.path.stuckSince or now
		if now - st.path.stuckSince > 0.9 then
			if IsValid(blockerEnt) then
				startBarricadeHold(bot, st, blockerEnt, now, targetPos)
				return true
			end
			st.path.route = nil
			resetPathState(st)
			st.path.nextRepath = 0
			debugLog(bot, "path_stuck_speed", 0.45, string.format(
				"stuck=low_speed speed=%.1f dist=%.1f routeType=%s",
				speed2D,
				tonumber(distToArea) or -1,
				tostring(bot.routeType)
			))
			if bot.routeType == "mvm_bomb_carrier" then
				bot._tfbotMvmRelaxRouteBiasUntil = math.max(tonumber(bot._tfbotMvmRelaxRouteBiasUntil or 0), now + 2.5)
			end
			st.path.stuckEvents = st.path.stuckEvents + 1
			st.path.stuckEventWindowAt = now
			startSoftStuckRecover(bot, st, now)
			if st.path.stuckEvents >= 4 and tryHardRecover(bot, st, targetPos, now) then
				debugLog(bot, "path_stuck_escalate", 0.45, string.format(
					"stuck_escalate=hard_recover events=%d",
					tonumber(st.path.stuckEvents) or 0
				))
				st.path.stuckEvents = 0
				return true
			end
			local b = cmd:GetButtons()
			cmd:SetButtons(bit.bor(b, IN_JUMP))
			cmd:SetForwardMove(120)
			cmd:SetSideMove((bot:EntIndex() % 2 == 0) and 220 or -220)
			return true
		end
	else
		st.path.stuckSince = nil
	end

	return false
end

function M:Drive(bot, cmd, state)
	local targetPos = self:ResolveTargetPos(bot, state)
	if not targetPos then
		debugLog(bot, "path_no_target", 1.0, string.format(
			"no_target routeType=%s mode=%s targetEnt=%s rawTarget=%s",
			tostring(bot.routeType),
			tostring(state and state.objective and state.objective.mode or "none"),
			tostring(IsValid(state and state.objective and state.objective.targetEnt) and state.objective.targetEnt:GetClass() or "nil"),
			fmtVec(state and state.objective and state.objective.targetPos or nil)
		))
		return
	end

	if isMvMMap() then
		local currentArea = getNearestAreaForTeam(bot:GetPos(), bot:Team())
		local spawnAttr = getFriendlySpawnAttributeForBot(bot)
		if spawnAttr and hasAreaTFAttribute(currentArea, spawnAttr) then
			local exitPos = getSpawnExitTargetPos(bot)
			if isvector(exitPos) and bot:GetPos():DistToSqr(exitPos) > (110 * 110) then
				targetPos = exitPos
				state.path.forceSpawnExit = true
			else
				state.path.forceSpawnExit = false
			end
		else
			state.path.forceSpawnExit = false
		end
	end

	bot.botPos = targetPos

	local now = CurTime()
	state.path.lastRepath = state.path.lastRepath or 0
	state.path.lastRepathTry = state.path.lastRepathTry or 0
	state.path.nextRepath = state.path.nextRepath or 0

	if applyBreakablePush(bot, cmd, state, now) then
		return
	end

	if applyBarricadeHold(bot, cmd, state, now) then
		return
	end

	if applySoftStuckRecover(bot, cmd, state, now) then
		return
	end

	if self:NeedRepath(bot, state, now) then
		self:RefreshRepathDeadline(state, now)
		self:BuildPath(bot, state, targetPos, now)
	end

	if not istable(state.path.route) or #state.path.route < 1 then
		debugLog(bot, "path_no_route", 1.2, string.format(
			"no_route direct_move routeType=%s target=%s",
			tostring(bot.routeType),
			fmtVec(targetPos)
		))
		local dir = targetPos - bot:GetPos()
		local ang = dir:GetNormalized():Angle()
		local failCount = tonumber(state.path.consecutiveBuildFails or 0)
		local probeSpeed = math.max(60, cv_no_route_probe_speed:GetFloat())
		local obstacle = traceObstacleAhead(bot, ang, 56, 18)
		if obstacle then
			if obstacle.kind == "barricade" and IsValid(obstacle.ent) then
				startBarricadeHold(bot, state, obstacle.ent, now, targetPos)
				cmd:SetForwardMove(-40)
				cmd:SetSideMove(0)
				cmd:RemoveKey(IN_JUMP)
				return
			end
			if obstacle.kind == "breakable" then
				startBreakablePush(bot, state, obstacle, now)
				cmd:SetForwardMove(80)
				cmd:SetSideMove(0)
				cmd:SetViewAngles(ang)
				return
			end
			if obstacle.kind == "solid" then
				startStaticObstacleAvoid(bot, state, obstacle.trace, now, targetPos)
				cmd:SetForwardMove(0)
				cmd:SetSideMove(0)
				cmd:RemoveKey(IN_JUMP)
				return
			end
		end
		cmd:SetForwardMove((failCount >= 2) and (probeSpeed * 0.5) or probeSpeed)
		if failCount >= 2 then
			cmd:SetSideMove((bot:EntIndex() % 2 == 0) and 120 or -120)
		end
		cmd:SetViewAngles(ang)
		if shouldForceJumpAtObstacle(bot, ang) then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
		end
		if not IsValid(state.vision.currentThreat) then
			bot:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, bot:EyeAngles(), ang))
		end
		return
	end

	local currentArea = getNearestAreaForTeam(bot:GetPos(), bot:Team())
	if not IsValid(state.path.targetArea) then
		state.path.targetArea = state.path.route[#state.path.route]
	end

	local areaAdvanceDist = math.max(28, 20 * bot:GetModelScale())
	while IsValid(state.path.targetArea) do
		local steerPos = getAreaSteerPos(state.path.targetArea, bot:GetPos(), targetPos)
		if state.path.targetArea ~= currentArea and bot:GetPos():DistToSqr(steerPos) > (areaAdvanceDist * areaAdvanceDist) then
			break
		end
		table.remove(state.path.route)
		state.path.targetArea = state.path.route[#state.path.route]
		state.path.segmentAreaId = nil
		if not state.path.route or #state.path.route < 1 then
			state.path.route = nil
			state.path.targetArea = nil
			return
		end
	end

	if not IsValid(state.path.targetArea) then
		state.path.route = nil
		return
	end

	local steerPos = getAreaSteerPos(state.path.targetArea, bot:GetPos(), targetPos)
	local toSteer = steerPos - bot:GetPos()
	local targetAng = toSteer:GetNormalized():Angle()
	local distToArea = toSteer:Length()

	local obstacle = traceObstacleAhead(bot, targetAng, 52, 18)
	if obstacle then
		if obstacle.kind == "breakable" then
			startBreakablePush(bot, state, obstacle, now)
			cmd:SetForwardMove(80)
			cmd:SetViewAngles(targetAng)
			return
		end
		if obstacle.kind == "solid" then
			startStaticObstacleAvoid(bot, state, obstacle.trace, now, targetPos)
			cmd:SetForwardMove(0)
			cmd:SetSideMove(0)
			return
		end
	end

	if progressMonitor(bot, cmd, state, distToArea, targetPos) then
		return
	end

	if bot:GetNWBool("Taunting", false) then
		cmd:SetForwardMove(0)
		return
	end

	cmd:SetForwardMove(1000)
	cmd:SetViewAngles(targetAng)
	if shouldForceJumpAtObstacle(bot, targetAng) then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
	end
	if not IsValid(state.vision.currentThreat) then
		bot:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, bot:EyeAngles(), targetAng))
	end
end

return M

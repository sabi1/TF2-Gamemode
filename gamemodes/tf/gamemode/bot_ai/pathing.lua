TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.Pathing = TFBotValveAI.Pathing or {}

local M = TFBotValveAI.Pathing

local cv_nav_budget_ms = CreateConVar("tf_bot_nav_budget_ms", "1.50", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_mvm_anchor_bias = CreateConVar("tf_bot_mvm_anchor_bias", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_hard_recover = CreateConVar("tf_bot_hard_recover_enable", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local navBudget = {
	window = 0,
	used = 0,
}

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

local function isInsideFriendlySpawnArea(bot)
	if not IsValid(bot) then return false end
	if bot.GetNWBool and bot:GetNWBool("InRespawnRoom", false) then
		return true
	end
	local attr = getFriendlySpawnAttributeForBot(bot)
	if not attr then return false end
	local area = getNearestAreaForTeam(bot:GetPos(), bot:Team())
	return hasAreaTFAttribute(area, attr)
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
		mask = MASK_PLAYERSOLID,
		mins = Vector(-16, -16, 0),
		maxs = Vector(16, 16, 48),
	})
	if not tr.Hit then return false end
	return tr.HitNormal.z <= 0.65
end

local function resetPathState(st)
	st.path.targetArea = nil
	st.path.segmentAreaId = nil
	st.path.segmentBestDist = nil
	st.path.segmentBestStamp = nil
	st.path.stuckSince = nil
end

local function findHardRecoverPos(bot, targetPos)
	if not IsValid(bot) or not isvector(targetPos) or not navmesh or not navmesh.GetAllNavAreas then return nil end
	local origin = bot:GetPos()
	local currentDist = origin:DistToSqr(targetPos)
	local bestPos, bestScore
	for _, area in ipairs(navmesh.GetAllNavAreas()) do
		if not IsValid(area) then continue end
		local center = area:GetCenter()
		local dz = math.abs(center.z - origin.z)
		if dz > 700 then continue end
		local fromDist = origin:DistToSqr(center)
		if fromDist < (120 * 120) or fromDist > (900 * 900) then continue end
		local towardDist = center:DistToSqr(targetPos)
		if towardDist >= (currentDist - (96 * 96)) then continue end

		local probe = center + Vector(0, 0, 8)
		local tr = util.TraceHull({
			start = probe,
			endpos = probe,
			filter = bot,
			mask = MASK_PLAYERSOLID,
			mins = Vector(-16, -16, 0),
			maxs = Vector(16, 16, 72),
		})
		if tr.StartSolid then continue end

		local score = (towardDist * 0.70) + (fromDist * 0.40)
		if not bestScore or score < bestScore then
			bestScore = score
			bestPos = probe
		end
	end
	return bestPos
end

local function tryHardRecover(bot, st, targetPos, now)
	if not cv_hard_recover:GetBool() then return false end
	st.path.nextHardRecoverAt = tonumber(st.path.nextHardRecoverAt or 0)
	if now < st.path.nextHardRecoverAt then return false end

	if isInsideFriendlySpawnArea(bot) or now < tonumber(bot._tfbotSpawnRecoverGraceUntil or 0) then
		st.path.nextHardRecoverAt = now + 0.8
		debugLog(bot, "path_hard_recover_blocked", 0.6, string.format(
			"hard_recover=blocked_in_spawn pos=%s target=%s graceUntil=%.2f",
			fmtVec(bot:GetPos()),
			fmtVec(targetPos),
			tonumber(bot._tfbotSpawnRecoverGraceUntil or 0)
		))
		return false
	end

	local recoverPos = findHardRecoverPos(bot, targetPos)
	if not isvector(recoverPos) then
		st.path.nextHardRecoverAt = now + 1.25
		debugLog(bot, "path_hard_recover_fail", 0.75, string.format(
			"hard_recover=no_candidate routeType=%s pos=%s target=%s",
			tostring(bot.routeType),
			fmtVec(bot:GetPos()),
			fmtVec(targetPos)
		))
		return false
	end
	local fromPos = bot:GetPos()
	bot:SetPos(recoverPos)
	if bot.SetLocalVelocity then
		bot:SetLocalVelocity(vector_origin)
	end
	st.path.route = nil
	resetPathState(st)
	st.path.nextRepath = 0
	st.path.nextHardRecoverAt = now + 2.5
	debugLog(bot, "path_hard_recover_ok", 0.35, string.format(
		"hard_recover=teleport from=%s to=%s target=%s routeType=%s",
		fmtVec(fromPos),
		fmtVec(recoverPos),
		fmtVec(targetPos),
		tostring(bot.routeType)
	))
	return true
end

local function isMvMMap()
	return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

local function getBombIntel()
	for _, intel in ipairs(ents.FindByClass("item_teamflag_mvm")) do
		if IsValid(intel) then return intel end
	end
	return nil
end

local function getDeployZonePos()
	for _, zone in ipairs(ents.FindByClass("func_capturezone")) do
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
	return now >= (state.path.nextRepath or 0) or not istable(state.path.route)
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
		state.path.route = nil
		resetPathState(state)
		return false
	end

	table.remove(route) -- remove the current area just like legacy movement
	state.path.route = route
	state.path.lastRepath = now
	state.path.lastRepathTry = now
	resetPathState(state)
	return true
end

local function progressMonitor(bot, cmd, st, distToArea, targetPos)
	local areaId = st.path.targetArea:GetID()
	local now = CurTime()
	st.path.stuckEvents = tonumber(st.path.stuckEvents or 0)
	st.path.stuckEventWindowAt = tonumber(st.path.stuckEventWindowAt or 0)
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
		cmd:SetForwardMove(280)
		cmd:SetSideMove((bot:EntIndex() % 2 == 0) and 220 or -220)
		return true
	end

	local speed2D = bot:GetVelocity():Length2D()
	if bot:IsOnGround() and distToArea > 120 and speed2D < 28 then
		st.path.stuckSince = st.path.stuckSince or now
		if now - st.path.stuckSince > 0.9 then
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
			cmd:SetForwardMove(280)
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
	if isInsideFriendlySpawnArea(bot) then
		bot._tfbotSpawnRecoverGraceUntil = now + 2.5
	end
	state.path.lastRepath = state.path.lastRepath or 0
	state.path.lastRepathTry = state.path.lastRepathTry or 0
	state.path.nextRepath = state.path.nextRepath or 0

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
		cmd:SetForwardMove(320)
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

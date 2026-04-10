TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.Objective = TFBotValveAI.Objective or {}

local M = TFBotValveAI.Objective
local cv_red_chase_blu = CreateConVar("tf_bot_red_chase_blu", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "When enabled, RED bots prioritize nearest BLU bot and otherwise wander toward BLU front.")
local cv_red_collect_currency = CreateConVar("tf_bot_red_collect_currency", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "When enabled, RED bots collect nearby MvM currency packs.")
local cv_red_collect_currency_range = CreateConVar("tf_bot_red_collect_currency_range", "2400", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max range RED bots search for MvM currency packs.")
local cv_red_respect_blu_spawn = CreateConVar("tf_bot_red_respect_blu_spawn", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "RED bots ignore BLU bots while they are still in BLU spawn areas.")

local function getPos(ent)
	if not IsValid(ent) then return nil end
	if ent.WorldSpaceCenter then
		local ok, center = pcall(ent.WorldSpaceCenter, ent)
		if ok and isvector(center) then
			return center
		end
	end
	if ent.GetPos then return ent:GetPos() end
	return nil
end

local function nearest(list, origin)
	local best, bestDist
	for _, ent in ipairs(list) do
		if IsValid(ent) then
			local d = origin:DistToSqr(ent:GetPos())
			if not bestDist or d < bestDist then
				bestDist = d
				best = ent
			end
		end
	end
	return best
end

local function inSpawnAreaForTeam(pos, team)
	if not navmesh or not navmesh.GetNearestNavArea or not isvector(pos) then return false end
	local area = navmesh.GetNearestNavArea(pos, true, 10000, true, true, team)
	if not IsValid(area) then
		area = navmesh.GetNearestNavArea(pos, true, 10000, true, true)
	end
	if not IsValid(area) or not area.HasTFAttribute then return false end
	if team == TEAM_BLU or team == TF_TEAM_PVE_INVADERS then
		return area:HasTFAttribute("spawn_room_blue") == true
	end
	if team == TEAM_RED then
		return area:HasTFAttribute("spawn_room_red") == true
	end
	return false
end

local function nearestEnemyBlueBot(bot)
	if not IsValid(bot) then return nil end
	local best, bestDist
	local origin = bot:GetPos()
	for _, p in ipairs(player.GetAll()) do
		if not IsValid(p) or not p:Alive() then continue end
		if p:Team() ~= TEAM_BLU and p:Team() ~= TF_TEAM_PVE_INVADERS then continue end
		if cv_red_respect_blu_spawn:GetBool() and inSpawnAreaForTeam(p:GetPos(), p:Team()) then continue end
		if p == bot then continue end
		local d = origin:DistToSqr(p:GetPos())
		if not bestDist or d < bestDist then
			bestDist = d
			best = p
		end
	end
	return best
end

local function pickBlueFrontAnchor(bot)
	local enemy = nearestEnemyBlueBot(bot)
	if IsValid(enemy) then
		return enemy:GetPos()
	end

	for _, intel in ipairs(ents.FindByClass("item_teamflag_mvm")) do
		if IsValid(intel) then
			local p = intel.HomePosition or getPos(intel)
			if isvector(p) then return p end
		end
	end

	local spawns = ents.FindByClass("info_player_bluspawn")
	local spawn = nearest(spawns, bot:GetPos())
	if IsValid(spawn) then
		local p = getPos(spawn)
		if isvector(p) then return p end
	end

	local blueFlag = nearest(ents.FindByClass("item_teamflag_blu"), bot:GetPos())
	if IsValid(blueFlag) then
		local p = getPos(blueFlag)
		if isvector(p) then return p end
	end

	return nil
end

local function pickFrontWanderPos(bot, state)
	local now = CurTime()
	if state.objective.redFrontPos and now < tonumber(state.objective.redFrontPosUntil or 0) then
		return state.objective.redFrontPos
	end

	local anchor = pickBlueFrontAnchor(bot)
	local pos = nil
	if isvector(anchor) and IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot then
		pos = bot.ControllerBot:FindSpot("random", { radius = 900, pos = anchor, type = "exposed" })
	end
	if not isvector(pos) then
		pos = anchor or bot:GetPos()
	end

	state.objective.redFrontPos = pos
	state.objective.redFrontPosUntil = now + math.Rand(2.0, 4.0)
	return pos
end

local function nearestCurrencyPack(bot)
	if not IsValid(bot) then return nil end
	local origin = bot:GetPos()
	local maxRange = math.max(256, cv_red_collect_currency_range:GetFloat())
	local maxRange2 = maxRange * maxRange
	local best, bestDist
	for _, cls in ipairs({"item_currencypack_small", "item_currencypack_medium", "item_currencypack_large"}) do
		for _, ent in ipairs(ents.FindByClass(cls)) do
			if not IsValid(ent) then continue end
			if ent.GetNoDraw and ent:GetNoDraw() then continue end
			local p = getPos(ent)
			if not isvector(p) then continue end
			local d2 = origin:DistToSqr(p)
			if d2 > maxRange2 then continue end
			if not bestDist or d2 < bestDist then
				bestDist = d2
				best = ent
			end
		end
	end
	return best
end

local function isPasstimeMap()
	return TF_IsPasstimeMap and TF_IsPasstimeMap() or false
end

local function getPasstimeLogic()
	for _, logic in ipairs(ents.FindByClass("passtime_logic")) do
		if IsValid(logic) and not logic.Disabled then
			return logic
		end
	end
	return nil
end

local function getManagedBots()
	local base = TFBotValveAI and TFBotValveAI.Base or nil
	if base and base.GetManagedAgents then
		return base:GetManagedAgents()
	end
	return player.GetBots()
end

local function isManagedAliveBot(ply)
	local base = TFBotValveAI and TFBotValveAI.Base or nil
	if base and base.IsAlive and base:IsManaged(ply) then
		return base:IsAlive(ply)
	end
	return IsValid(ply) and ply:IsPlayer() and ply:IsBot() and ply:Alive()
end

local function passtimeGoalPos(goal)
	return getPos(goal)
end

local function getObjectivePos(ent)
	local pos = getPos(ent)
	if not isvector(pos) then return nil end
	if navmesh and navmesh.GetNearestNavArea then
		local area = navmesh.GetNearestNavArea(pos)
		if IsValid(area) then
			return area:GetCenter()
		end
	end
	return pos
end

local function getEnemyTeam(teamNum)
	if teamNum == TEAM_RED then return TEAM_BLU end
	if teamNum == TEAM_BLU then return TEAM_RED end
	if teamNum == TF_TEAM_PVE_INVADERS then return TEAM_RED end
	return TEAM_RED
end

local function countTeamOccupantsNear(ent, teamNum, fallbackPos)
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

	local pos = fallbackPos or getObjectivePos(ent)
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

local function getPayloadWatcher()
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

local function getPayloadState(watcher)
	if not IsValid(watcher) then return nil end
	if watcher.GetState then
		local ok, state = pcall(watcher.GetState, watcher)
		if ok and istable(state) then
			return state
		end
	end
	return watcher.PayloadState
end

local function getPayloadTeam(state, key, fallback)
	if not istable(state) then return fallback end
	local teamNum = tonumber(state[key] or fallback)
	if teamNum == TEAM_RED or teamNum == TEAM_BLU then
		return teamNum
	end
	return fallback
end

local function getPayloadCart(watcher)
	if not IsValid(watcher) then return nil end
	if IsValid(watcher.Train) then
		return watcher.Train
	end
	if watcher.GetTrainEntity then
		local ok, cart = pcall(watcher.GetTrainEntity, watcher)
		if ok and IsValid(cart) then
			return cart
		end
	end
	return nil
end

local function getPayloadCartPosition(watcher)
	local cart = getPayloadCart(watcher)
	if IsValid(cart) then
		return getObjectivePos(cart)
	end
	if IsValid(watcher) and watcher.GetCartPosition then
		local ok, pos = pcall(watcher.GetCartPosition, watcher)
		if ok and isvector(pos) then
			return getObjectivePos(watcher) or pos
		end
	end
	return getObjectivePos(watcher)
end

local function getPayloadDefendPosition(watcher)
	if not IsValid(watcher) then return nil end
	if watcher.GetDefendPosition then
		local ok, pos = pcall(watcher.GetDefendPosition, watcher)
		if ok and isvector(pos) then
			if navmesh and navmesh.GetNearestNavArea then
				local area = navmesh.GetNearestNavArea(pos)
				if IsValid(area) then
					return area:GetCenter()
				end
			end
			return pos
		end
	end
	return getPayloadCartPosition(watcher)
end

local function getFlagCarrier(flag)
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
	if flag.GetOwner then
		local ok, owner = pcall(flag.GetOwner, flag)
		if ok and IsValid(owner) then
			return owner
		end
	end
	return nil
end

local function isFlagDropped(flag)
	if not IsValid(flag) then return false end
	if flag.IsDropped then
		local ok, dropped = pcall(flag.IsDropped, flag)
		if ok then return dropped == true end
	end
	return getFlagCarrier(flag) == nil and (flag.Dropped == true or tonumber(flag.State or -1) == 2)
end

local function isFlagHome(flag)
	if not IsValid(flag) then return false end
	if flag.IsHome then
		local ok, home = pcall(flag.IsHome, flag)
		if ok then return home == true end
	end
	return getFlagCarrier(flag) == nil and not isFlagDropped(flag)
end

local function getFriendlyCaptureZone(bot)
	if not IsValid(bot) then return nil end
	local best, bestDist
	for _, zone in ipairs(ents.FindByClass("func_capturezone")) do
		if not IsValid(zone) then continue end
		local teamNum = tonumber(zone.TeamNum or zone.Team or 0) or 0
		if teamNum ~= 0 and teamNum ~= bot:Team() then continue end
		local pos = getObjectivePos(zone)
		if not isvector(pos) then continue end
		local d2 = bot:GetPos():DistToSqr(pos)
		if not bestDist or d2 < bestDist then
			bestDist = d2
			best = zone
		end
	end
	return best
end

local function getTeamFlag(teamNum)
	for _, flag in ipairs(ents.FindByClass("item_teamflag")) do
		if IsValid(flag) and tonumber(flag.TeamNum or flag.Team or 0) == teamNum then
			return flag
		end
	end
	return nil
end

local function teamCanCaptureControlPoint(cp, teamNum)
	if not IsValid(cp) or not teamNum then return false end
	if cp.Locked == true then return false end
	if istable(cp.TeamCanCap) and cp.TeamCanCap[teamNum] ~= nil then
		return cp.TeamCanCap[teamNum] and true or false
	end
	local owner = tonumber((cp.GetOwnerTeam and cp:GetOwnerTeam()) or cp.OwnerTeam or (cp.Properties and cp.Properties.point_default_owner) or 0) or 0
	return owner ~= teamNum
end

local function getControlPointOwnerTeam(cp)
	if not IsValid(cp) then return 0 end
	return tonumber((cp.GetOwnerTeam and cp:GetOwnerTeam()) or cp.OwnerTeam or (cp.Properties and cp.Properties.point_default_owner) or 0) or 0
end

local function isPointThreatened(trigger, cp, bot)
	if not IsValid(trigger) or not IsValid(cp) or not IsValid(bot) then return false end
	local enemyTeam = getEnemyTeam(bot:Team())
	local objectivePos = getObjectivePos(cp) or getObjectivePos(trigger)
	if countTeamOccupantsNear(trigger, enemyTeam, objectivePos) > 0 then
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

local function selectControlPointDecision(bot)
	if not IsValid(bot) then return nil end

	local teamNum = bot:Team()
	if teamNum ~= TEAM_RED and teamNum ~= TEAM_BLU then
		return nil
	end

	local enemyTeam = getEnemyTeam(teamNum)
	local best, bestScore

	for _, trigger in ipairs(ents.FindByClass("trigger_capture_area")) do
		if not IsValid(trigger) then continue end
		local cp = trigger.CapturePoint
		if not IsValid(cp) then continue end
		if cp.Locked == true then continue end

		local ownerTeam = getControlPointOwnerTeam(cp)
		local canWeCap = teamCanCaptureControlPoint(cp, teamNum)
		local canEnemyCap = teamCanCaptureControlPoint(cp, enemyTeam)
		local objectivePos = getObjectivePos(cp) or getObjectivePos(trigger)
		if not isvector(objectivePos) then continue end

		local defend = ownerTeam == teamNum and canEnemyCap
		local attack = ownerTeam ~= teamNum and canWeCap
		if not defend and not attack then continue end

		local defenders = countTeamOccupantsNear(trigger, teamNum, objectivePos)
		local attackers = countTeamOccupantsNear(trigger, enemyTeam, objectivePos)
		local score = bot:GetPos():DistToSqr(objectivePos)

		if defend then
			if isPointThreatened(trigger, cp, bot) then
				score = score * 0.25
			else
				score = score * 0.75
			end
			score = score - (attackers * 90000)
		else
			score = score - (defenders * 20000)
		end

		if not bestScore or score < bestScore then
			bestScore = score
			best = {
				mode = defend and (isPointThreatened(trigger, cp, bot) and "block_capture_point" or "defend_point") or "capture_point",
				targetEnt = cp,
				targetPos = objectivePos,
				routeType = defend and "default" or "safest",
			}
		end
	end

	return best
end

local function selectPayloadDecision(bot)
	local watcher = getPayloadWatcher()
	if not IsValid(watcher) then return nil end

	local state = getPayloadState(watcher)
	if istable(state) and state.goalReached then return nil end

	local attackTeam = getPayloadTeam(state, "attackTeam", TEAM_BLU)
	local defendTeam = getPayloadTeam(state, "defendTeam", TEAM_RED)
	local cart = getPayloadCart(watcher)
	local cartPos = getPayloadCartPosition(watcher)
	if not isvector(cartPos) then return nil end

	if bot:Team() == attackTeam then
		local pushPos = cartPos
		if IsValid(cart) then
			local forward = cart:GetForward()
			if isvector(forward) and forward:LengthSqr() > 0 then
				pushPos = cartPos - forward:GetNormalized() * 60
			end
		end
		return {
			mode = "payload_push",
			targetEnt = cart,
			targetPos = pushPos,
			routeType = "default",
		}
	end

	if bot:Team() == defendTeam then
		local contested = false
		if istable(state) then
			local cappers = tonumber(state.cappers) or 0
			contested = cappers > 0 or state.blocked == true or tonumber(state.trainState or -1) == 1
		end
		return {
			mode = contested and "payload_block" or "payload_guard",
			targetEnt = cart,
			targetPos = contested and cartPos or (getPayloadDefendPosition(watcher) or cartPos),
			routeType = "default",
		}
	end

	return nil
end

local function selectCTFDecision(bot)
	if not IsValid(bot) then return nil end

	local enemyTeam = getEnemyTeam(bot:Team())
	local enemyFlag = getTeamFlag(enemyTeam)
	local myFlag = getTeamFlag(bot:Team())
	local capZone = getFriendlyCaptureZone(bot)
	local myCarrier = getFlagCarrier(enemyFlag)
	local enemyCarrier = getFlagCarrier(myFlag)

	if IsValid(myCarrier) and myCarrier == bot and IsValid(capZone) then
		return {
			mode = "deliver_flag",
			targetEnt = capZone,
			targetPos = getObjectivePos(capZone),
			routeType = "fastest",
		}
	end

	if IsValid(enemyCarrier) and enemyCarrier:Team() ~= bot:Team() then
		return {
			mode = "defend_flag",
			targetEnt = enemyCarrier,
			targetPos = enemyCarrier:GetPos(),
			routeType = "default",
		}
	end

	if IsValid(myCarrier) and myCarrier:Team() == bot:Team() then
		local supportPos = IsValid(capZone) and computeSupportSpot(myCarrier, capZone, bot) or myCarrier:GetPos()
		return {
			mode = "escort_flag_carrier",
			targetEnt = myCarrier,
			targetPos = supportPos,
			routeType = "default",
		}
	end

	if IsValid(enemyFlag) and (isFlagDropped(enemyFlag) or not isFlagHome(enemyFlag)) then
		return {
			mode = "fetch_flag",
			targetEnt = enemyFlag,
			targetPos = getObjectivePos(enemyFlag),
			routeType = "fastest",
		}
	end

	if IsValid(enemyFlag) then
		return {
			mode = "fetch_flag",
			targetEnt = enemyFlag,
			targetPos = getObjectivePos(enemyFlag),
			routeType = "fastest",
		}
	end

	return nil
end

local function getPasstimeGoalForTeam(bot, teamNum)
	if not IsValid(bot) then return nil end
	local best, bestDist
	local origin = bot:GetPos()
	for _, goal in ipairs(ents.FindByClass("func_passtime_goal")) do
		if not IsValid(goal) or goal.Disabled then continue end
		if goal.TeamNum ~= teamNum then continue end
		local pos = passtimeGoalPos(goal)
		if not isvector(pos) then continue end
		local d2 = origin:DistToSqr(pos)
		if not bestDist or d2 < bestDist then
			bestDist = d2
			best = goal
		end
	end
	return best
end

local function getFreePasstimeBall(logic)
	if not IsValid(logic) then return nil end
	if IsValid(logic.BallCarrier) then return nil end
	if IsValid(TF_GetPasstimeBallCarrier and TF_GetPasstimeBallCarrier() or nil) then return nil end
	if IsValid(logic.BallEntity) then
		return logic.BallEntity
	end
	return nil
end

local function hasDirectBallShot(bot, pos)
	if not IsValid(bot) or not isvector(pos) then return false end
	local tr = util.TraceLine({
		start = bot:GetShootPos(),
		endpos = pos,
		filter = bot,
		mask = MASK_SHOT,
	})
	return (not tr.Hit) or tr.Fraction >= 0.98
end

local function nearestEnemyToPos(bot, pos, maxDist)
	if not IsValid(bot) or not isvector(pos) then return nil, nil end
	local best, bestDist
	local maxDist2 = maxDist and (maxDist * maxDist) or nil
	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:Alive() then continue end
		if ply == bot or ply:IsFriendly(bot) then continue end
		local d2 = pos:DistToSqr(ply:GetPos())
		if maxDist2 and d2 > maxDist2 then continue end
		if not bestDist or d2 < bestDist then
			bestDist = d2
			best = ply
		end
	end
	return best, bestDist and math.sqrt(bestDist) or nil
end

local function nearestFriendlyBotToPos(teamNum, pos)
	if not isvector(pos) then return nil end
	local best, bestDist
	for _, ply in ipairs(getManagedBots()) do
		if not isManagedAliveBot(ply) then continue end
		if ply:Team() ~= teamNum then continue end
		local d2 = ply:GetPos():DistToSqr(pos)
		if not bestDist or d2 < bestDist then
			bestDist = d2
			best = ply
		end
	end
	return best
end

local function computeSupportSpot(carrier, goal, bot)
	if not IsValid(carrier) or not IsValid(goal) or not IsValid(bot) then return nil end
	local carrierPos = carrier:GetPos()
	local goalPos = passtimeGoalPos(goal)
	if not isvector(goalPos) then return nil end

	local toGoal = goalPos - carrierPos
	toGoal.z = 0
	if toGoal:LengthSqr() <= 1 then
		return goalPos
	end

	local dir = toGoal:GetNormalized()
	local right = dir:Angle():Right()
	local side = (bot:EntIndex() % 2 == 0) and 1 or -1
	local lead = math.Clamp(toGoal:Length() * 0.35, 180, 720)
	local offset = math.Clamp(toGoal:Length() * 0.16, 80, 220)
	return carrierPos + dir * lead + right * offset * side
end

local function selectPassReceiver(bot, carrier, goal, logic, maxPassRange)
	if not IsValid(bot) or not IsValid(carrier) or not IsValid(goal) then return nil end
	local carrierPos = carrier:GetPos()
	local goalPos = passtimeGoalPos(goal)
	if not isvector(goalPos) then return nil end

	local carrierGoalDist2 = carrierPos:DistToSqr(goalPos)
	local passRange2 = maxPassRange * maxPassRange
	local best, bestScore

	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then continue end
		if ply == carrier or ply:Team() ~= carrier:Team() then continue end
		if TF_PlayerHasPasstimeBall and TF_PlayerHasPasstimeBall(ply) then continue end
		if ply.InCond and (ply:InCond(TF_COND_DISGUISED) or ply:InCond(TF_COND_DISGUISING)) then continue end
		if ply.InCond and (ply:InCond(TF_COND_STEALTHED) or ply:InCond(TF_COND_STEALTHED_USER_BUFF)) then continue end
		if ply.IsStealthed and ply:IsStealthed() then continue end
		if IsValid(logic) and logic.CanPlayerCarryBall and not logic:CanPlayerCarryBall(ply) then continue end

		local pos = ply:GetPos()
		local d2 = carrierPos:DistToSqr(pos)
		if d2 > passRange2 then continue end

		local goalDist2 = pos:DistToSqr(goalPos)
		local progress = carrierGoalDist2 - goalDist2
		if progress <= (160 * 160) then continue end
		if not carrier:Visible(ply) then continue end

		local _, enemyDist = nearestEnemyToPos(bot, pos, 700)
		local enemyPenalty = enemyDist and math.Clamp((700 - enemyDist) * 1.5, 0, 500) or 0
		local score = progress - d2 - enemyPenalty

		if ply:GetNWFloat("TFPasstimeAskForBallUntil", 0) > CurTime() then
			score = score + 40000
			if ply:KeyDown(IN_ATTACK2) then
				score = score + 80000
			end
		end

		if not bestScore or score > bestScore then
			bestScore = score
			best = ply
		end
	end

	return best
end

local function selectPasstimeDecision(bot, state, logic)
	local carrier = TF_GetPasstimeBallCarrier and TF_GetPasstimeBallCarrier() or logic.BallCarrier
	local ballEnt = getFreePasstimeBall(logic)
	local myGoal = getPasstimeGoalForTeam(bot, bot:Team())
	local defendGoal = getPasstimeGoalForTeam(bot, (bot:Team() == TEAM_RED) and TEAM_BLU or TEAM_RED)
	local passRange = math.max(tonumber(logic.MaxPassRange) or 0, 900)

	if IsValid(carrier) and carrier == bot and TF_PlayerHasPasstimeBall and TF_PlayerHasPasstimeBall(bot) then
		if not IsValid(myGoal) then return nil end
		local goalPos = passtimeGoalPos(myGoal)
		local receiver = selectPassReceiver(bot, bot, myGoal, logic, passRange)
		local threat, threatDist = nearestEnemyToPos(bot, bot:GetPos(), 520)
		local goalDist = isvector(goalPos) and bot:GetPos():Distance(goalPos) or math.huge
		local hasShot = isvector(goalPos) and hasDirectBallShot(bot, goalPos + Vector(0, 0, 48))
		local shouldThrow = not myGoal:EnablePlayerScore() and hasShot and goalDist <= math.max(passRange * 0.85, 700)
		local pressured = IsValid(threat) and threatDist and threatDist <= 420

		if myGoal:EnablePlayerScore() and goalDist <= 200 then
			return {
				mode = "passtime_score_run",
				targetEnt = myGoal,
				targetPos = goalPos,
				routeType = "default",
			}
		end

		if shouldThrow then
			return {
				mode = "passtime_throw_goal",
				targetEnt = myGoal,
				targetPos = goalPos,
				routeType = "default",
			}
		end

		if IsValid(receiver) and (pressured or goalDist > passRange * 0.8) then
			return {
				mode = "passtime_pass",
				targetEnt = receiver,
				targetPos = receiver:GetPos(),
				routeType = "default",
			}
		end

		return {
			mode = "passtime_drive_goal",
			targetEnt = myGoal,
			targetPos = goalPos,
			routeType = "default",
		}
	end

	if IsValid(carrier) and carrier:Team() == bot:Team() then
		if not IsValid(myGoal) then return nil end
		return {
			mode = "passtime_support_carrier",
			targetEnt = nil,
			targetPos = computeSupportSpot(carrier, myGoal, bot) or carrier:GetPos(),
			routeType = "default",
		}
	end

	if IsValid(carrier) and carrier:Team() ~= bot:Team() then
		if not IsValid(defendGoal) then
			return {
				mode = "passtime_chase_carrier",
				targetEnt = carrier,
				targetPos = carrier:GetPos(),
				routeType = "default",
			}
		end

		local defendPos = passtimeGoalPos(defendGoal)
		local carrierPos = carrier:GetPos()
		local anchor = carrierPos
		if isvector(defendPos) then
			anchor = LerpVector(0.38, carrierPos, defendPos)
		end

		if nearestFriendlyBotToPos(bot:Team(), defendPos or carrierPos) == bot then
			anchor = defendPos or anchor
		end

		return {
			mode = "passtime_intercept_carrier",
			targetEnt = nil,
			targetPos = anchor,
			routeType = "default",
		}
	end

	if IsValid(ballEnt) then
		local ballPos = getPos(ballEnt)
		if nearestFriendlyBotToPos(bot:Team(), ballPos) == bot then
			return {
				mode = "passtime_fetch_ball",
				targetEnt = ballEnt,
				targetPos = ballPos,
				routeType = "default",
			}
		end

		local anchor = IsValid(myGoal) and computeSupportSpot(ballEnt, myGoal, bot) or ballPos
		return {
			mode = "passtime_open_lane",
			targetEnt = nil,
			targetPos = anchor,
			routeType = "default",
		}
	end

	if IsValid(myGoal) then
		return {
			mode = "passtime_midfield_hold",
			targetEnt = myGoal,
			targetPos = computeSupportSpot(bot, myGoal, bot) or passtimeGoalPos(myGoal),
			routeType = "default",
		}
	end

	return nil
end

function M:IsMvMMap()
	return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

function M:Select(bot, state)
	if not IsValid(bot) or not state then return end
	local now = CurTime()
	if now < (state.objective.nextUpdate or 0) and state.objective.targetPos then
		return
	end

	state.objective.nextUpdate = now + TFBotValveAI.Perf:GetInterval("objective")

	if isPasstimeMap() then
		local logic = getPasstimeLogic()
		if IsValid(logic) then
			local decision = selectPasstimeDecision(bot, state, logic)
			if decision then
				state.objective.mode = decision.mode
				state.objective.targetEnt = decision.targetEnt
				state.objective.targetPos = decision.targetPos
				bot.routeType = decision.routeType or "default"
				return
			end
		end
	end

	if cv_red_chase_blu:GetBool() and bot:Team() == TEAM_RED then
		if self:IsMvMMap() and cv_red_collect_currency:GetBool() then
			local money = nearestCurrencyPack(bot)
			if IsValid(money) then
				state.objective.mode = "red_collect_currency"
				state.objective.targetEnt = money
				state.objective.targetPos = getPos(money)
				return
			end
		end

		local enemy = nearestEnemyBlueBot(bot)
		if IsValid(enemy) then
			state.objective.mode = "red_chase_blu_bot"
			state.objective.targetEnt = enemy
			state.objective.targetPos = enemy:GetPos()
			return
		end

		state.objective.mode = "red_front_wander"
		state.objective.targetEnt = nil
		state.objective.targetPos = pickFrontWanderPos(bot, state)
		return
	end

	local mvm = TFBotValveAI.MvM
	if self:IsMvMMap() then
		local decision = mvm:SelectAction(bot, state)
		if decision then
			mvm:ApplyDecision(bot, state, decision)
			return
		end
	else
		state.mvm.mode = "none"
		state.mvm.ignoreCombat = false
		state.mvm.routeType = "default"
		bot.routeType = "default"
		bot.TF_MVM_IgnoreCombat = false
	end

	local payloadDecision = selectPayloadDecision(bot)
	if payloadDecision then
		state.objective.mode = payloadDecision.mode
		state.objective.targetEnt = payloadDecision.targetEnt
		state.objective.targetPos = payloadDecision.targetPos
		bot.routeType = payloadDecision.routeType or "default"
		return
	end

	if not bot.TF_MVM_IgnoreFlag then
		local ctfDecision = selectCTFDecision(bot)
		if ctfDecision then
			state.objective.mode = ctfDecision.mode
			state.objective.targetEnt = ctfDecision.targetEnt
			state.objective.targetPos = ctfDecision.targetPos
			bot.routeType = ctfDecision.routeType or "default"
			return
		end
	end

	local cpDecision = selectControlPointDecision(bot)
	if cpDecision then
		state.objective.mode = cpDecision.mode
		state.objective.targetEnt = cpDecision.targetEnt
		state.objective.targetPos = cpDecision.targetPos
		bot.routeType = cpDecision.routeType or "default"
		return
	end

	if IsValid(state.vision.currentThreat) then
		state.objective.mode = "chase_target"
		state.objective.targetEnt = state.vision.currentThreat
		state.objective.targetPos = state.vision.currentThreat:GetPos()
		bot.routeType = "default"
		return
	end

	state.objective.mode = "roam"
	if IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot then
		state.objective.targetPos = bot.ControllerBot:FindSpot("random", { radius = 2200, pos = bot:GetPos(), type = "exposed" }) or bot:GetPos()
	else
		state.objective.targetPos = bot:GetPos()
	end
	state.objective.targetEnt = nil
	bot.routeType = "default"
end

return M

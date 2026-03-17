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

local function selectPassReceiver(bot, carrier, goal, maxPassRange)
	if not IsValid(bot) or not IsValid(carrier) or not IsValid(goal) then return nil end
	local carrierPos = carrier:GetPos()
	local goalPos = passtimeGoalPos(goal)
	if not isvector(goalPos) then return nil end

	local carrierGoalDist2 = carrierPos:DistToSqr(goalPos)
	local passRange2 = maxPassRange * maxPassRange
	local best, bestScore

	for _, ply in ipairs(getManagedBots()) do
		if not isManagedAliveBot(ply) then continue end
		if ply == carrier or ply:Team() ~= carrier:Team() then continue end
		if TF_PlayerHasPasstimeBall and TF_PlayerHasPasstimeBall(ply) then continue end

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
		local receiver = selectPassReceiver(bot, bot, myGoal, passRange)
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

	local origin = bot:GetPos()
	local flagClass = (bot:Team() == TEAM_RED) and "item_teamflag_blu" or "item_teamflag_red"
	if not bot.TF_MVM_IgnoreFlag then
		local flags = ents.FindByClass(flagClass)
		local flag = nearest(flags, origin)
		if IsValid(flag) then
			state.objective.mode = "fetch_flag"
			state.objective.targetEnt = flag
			state.objective.targetPos = getPos(flag)
			return
		end
	end

	local capZones = ents.FindByClass("func_capturezone")
	local zone = nearest(capZones, origin)
	if IsValid(zone) then
		state.objective.mode = "capture_zone"
		state.objective.targetEnt = zone
		state.objective.targetPos = getPos(zone)
		return
	end

	if IsValid(state.vision.currentThreat) then
		state.objective.mode = "chase_target"
		state.objective.targetEnt = state.vision.currentThreat
		state.objective.targetPos = state.vision.currentThreat:GetPos()
		return
	end

	state.objective.mode = "roam"
	if IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot then
		state.objective.targetPos = bot.ControllerBot:FindSpot("random", { radius = 2200, pos = bot:GetPos(), type = "exposed" }) or bot:GetPos()
	else
		state.objective.targetPos = bot:GetPos()
	end
	state.objective.targetEnt = nil
end

return M

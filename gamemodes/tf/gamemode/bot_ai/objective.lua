TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.Objective = TFBotValveAI.Objective or {}

local M = TFBotValveAI.Objective
local cv_red_chase_blu = CreateConVar("tf_bot_red_chase_blu", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "When enabled, RED bots prioritize nearest BLU bot and otherwise wander toward BLU front.")
local cv_red_collect_currency = CreateConVar("tf_bot_red_collect_currency", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "When enabled, RED bots collect nearby MvM currency packs.")
local cv_red_collect_currency_range = CreateConVar("tf_bot_red_collect_currency_range", "2400", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max range RED bots search for MvM currency packs.")
local cv_red_respect_blu_spawn = CreateConVar("tf_bot_red_respect_blu_spawn", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "RED bots ignore BLU bots while they are still in BLU spawn areas.")

local function isBlueSideTeamNum(teamNum)
	return teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS
end

local function normalizeFlagTeamNum(rawTeam)
	local t = tonumber(rawTeam or -1) or -1
	if t == 3 then return TEAM_BLU end
	if t == 2 then return TEAM_RED end
	return t
end

local function hasClass(className)
	if not ents or not ents.FindByClass then return false end
	local list = ents.FindByClass(className)
	return istable(list) and #list > 0
end

local function detectHudModeFallback()
	local map = string.lower(game.GetMap() or "")
	if string.StartWith(map, "mvm_") then return "mvm" end
	if string.StartWith(map, "koth_") then return "koth" end
	if string.StartWith(map, "cp_") or string.StartWith(map, "tc_") then return "cp" end
	if string.StartWith(map, "ctf_") then return "ctf" end
	if string.StartWith(map, "pl_") or string.StartWith(map, "plr_") then return "payload" end
	if string.StartWith(map, "arena_") then return "arena" end
	if string.StartWith(map, "pass_") then return "passtime" end
	if string.StartWith(map, "pd_") then return "pd" end
	if string.StartWith(map, "rd_") then return "rd" end
	if string.StartWith(map, "sd_") then return "sd" end
	return "unknown"
end

local function detectHudMode()
	if TF_GetHudGameMode then
		local mode = TF_GetHudGameMode(false)
		if isstring(mode) and mode ~= "" and mode ~= "unknown" then
			return string.lower(mode)
		end
	end

	if hasClass("tf_logic_mann_vs_machine") or hasClass("info_populator") or hasClass("item_teamflag_mvm") then
		return "mvm"
	end
	if hasClass("tf_logic_koth") then
		return "koth"
	end
	if hasClass("passtime_logic") or hasClass("trigger_passtime_ball") or hasClass("info_passtime_ball_spawn") then
		return "passtime"
	end
	if hasClass("tf_logic_player_destruction") then
		return "pd"
	end
	if hasClass("tf_logic_robot_destruction") then
		return "rd"
	end
	if hasClass("team_train_watcher") or hasClass("tf_logic_multiple_escort") then
		return "payload"
	end
	if hasClass("tf_logic_arena") then
		return "arena"
	end
	if hasClass("tf_logic_hybrid_ctf_cp") then
		return "cp"
	end
	if hasClass("team_control_point_master") or hasClass("tf_logic_cp_timer") then
		return "cp"
	end
	if hasClass("item_teamflag") then
		return "ctf"
	end

	return detectHudModeFallback()
end

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

local function getCPTeamNumForBot(bot)
	if not IsValid(bot) then return nil end
	if bot:Team() == TEAM_RED then return 2 end
	if bot:Team() == TEAM_BLU or bot:Team() == TF_TEAM_PVE_INVADERS then return 3 end
	return nil
end

local function getCPOwnerTeam(cp)
	if not IsValid(cp) then return nil end
	if cp.GetOwnerTeam then
		local owner = tonumber(cp:GetOwnerTeam())
		if owner then return owner end
	end
	return tonumber(cp.OwnerTeam or (cp.Properties and cp.Properties.point_default_owner) or cp:GetNWInt("Team", 0)) or 0
end

local function canTeamCaptureCP(cp, teamNum)
	if not IsValid(cp) or not (teamNum == 2 or teamNum == 3) then return false end
	if istable(cp.TeamCanCap) and cp.TeamCanCap[teamNum] ~= nil then
		return cp.TeamCanCap[teamNum] and true or false
	end
	local props = cp.Properties or {}
	local raw = props["team_cancap_" .. tostring(teamNum)]
	if raw ~= nil then
		if isbool(raw) then return raw end
		if isnumber(raw) then return raw ~= 0 end
		if isstring(raw) then
			local v = string.Trim(string.lower(raw))
			return v == "1" or v == "true" or v == "yes"
		end
	end
	return true
end

local function getCPHudState(cp)
	if not IsValid(cp) then return nil end
	local trigger = cp.TriggerEntity
	if not IsValid(trigger) or not trigger.GetHudCapState then return nil end
	local ok, state = pcall(trigger.GetHudCapState, trigger)
	if not ok or not istable(state) then return nil end
	return state
end

local function nearestControlPointObjective(bot)
	if not IsValid(bot) then return nil, nil, nil end
	local origin = bot:GetPos()
	local myTeam = getCPTeamNumForBot(bot)
	local enemyTeam = (myTeam == 2) and 3 or 2
	local best, bestScore

	for _, className in ipairs({"team_control_point", "tf_team_control_point"}) do
		for _, point in ipairs(ents.FindByClass(className)) do
			if not IsValid(point) then continue end
			local pos = getPos(point)
			if not isvector(pos) then continue end
			local d = origin:DistToSqr(pos)
			local ownerTeam = getCPOwnerTeam(point)
			local isLocked = point.Locked and true or false
			local myCanCap = canTeamCaptureCP(point, myTeam)
			local enemyCanCap = canTeamCaptureCP(point, enemyTeam)
			local capState = getCPHudState(point)
			local isEnemyActivelyCapping = false
			if capState then
				local cappingTeam = tonumber(capState.cappingTeam or 0) or 0
				local cappers = tonumber(capState.cappers or 0) or 0
				isEnemyActivelyCapping = cappingTeam == enemyTeam and cappers > 0
				if capState.locked ~= nil then
					isLocked = capState.locked and true or false
				end
			end

			-- Priority order:
			-- 1) enemy points we can currently capture
			-- 2) our points currently under active enemy cap pressure
			-- 3) our points enemy can capture (frontline defend)
			-- 3) any other unlocked points
			-- 4) locked points (fallback only)
			local roleScore = 3000000
			if myTeam and ownerTeam ~= myTeam and (myCanCap or not isLocked) then
				roleScore = 0
			elseif myTeam and ownerTeam == myTeam and isEnemyActivelyCapping then
				roleScore = 350000
			elseif myTeam and ownerTeam == myTeam and enemyCanCap then
				roleScore = 1000000
			elseif not isLocked then
				roleScore = 2000000
			end

			-- Prevent post-cap dogpiling on the just-captured point when it's not contested.
			if myTeam and ownerTeam == myTeam and not isEnemyActivelyCapping and d < (420 * 420) then
				roleScore = roleScore + 750000
			end

			local lockPenalty = isLocked and 1000000000 or 0
			local score = lockPenalty + roleScore + d
			if not bestScore or score < bestScore then
				bestScore = score
				best = point
			end
		end
	end

	if IsValid(best) then
		return best, getPos(best), "capture_control_point"
	end

	local area = nearest(ents.FindByClass("trigger_capture_area"), origin)
	if IsValid(area) then
		return area, getPos(area), "capture_area"
	end

	return nil, nil, nil
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

local function nearestPasstimeObjective(bot)
	if not IsValid(bot) then return nil end
	local origin = bot:GetPos()
	local best, bestDist

	for _, className in ipairs({
		"tf_projectile_passtime_ball",
		"trigger_passtime_ball",
		"info_passtime_ball_spawn",
	}) do
		for _, ent in ipairs(ents.FindByClass(className)) do
			if not IsValid(ent) then continue end
			local pos = getPos(ent)
			if not isvector(pos) then continue end
			local d = origin:DistToSqr(pos)
			if not bestDist or d < bestDist then
				bestDist = d
				best = ent
			end
		end
	end

	return best
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
	if not IsValid(watcher) or not watcher.GetPayloadState then
		return {}
	end
	return watcher:GetPayloadState() or {}
end

local function getPayloadAttackTeam(state)
	local teamNum = tonumber(state.attackTeam)
	if teamNum == TEAM_RED or teamNum == TEAM_BLU then
		return teamNum
	end
	return TEAM_BLU
end

local function getPayloadDefendTeam(state)
	local teamNum = tonumber(state.defendTeam)
	if teamNum == TEAM_RED or teamNum == TEAM_BLU then
		return teamNum
	end
	return (getPayloadAttackTeam(state) == TEAM_RED) and TEAM_BLU or TEAM_RED
end

local function getPayloadCartPosition(watcher)
	if not IsValid(watcher) then return nil end
	if watcher.GetCartPosition then
		return watcher:GetCartPosition()
	end
	if IsValid(watcher.Train) then
		return watcher.Train:GetPos()
	end
	return watcher:GetPos()
end

local function getPayloadDefendPosition(watcher)
	if not IsValid(watcher) then return nil end
	if watcher.GetDefendPosition then
		return watcher:GetDefendPosition()
	end
	return getPayloadCartPosition(watcher)
end

local function getPayloadObjectivePosition(bot)
	if not IsValid(bot) then return nil end

	local watcher = getPayloadWatcher()
	if not IsValid(watcher) then return nil end

	local state = getPayloadState(watcher)
	if state.goalReached then return nil end
	if state.active == false and not IsValid(watcher.Train) then return nil end

	local attackTeam = getPayloadAttackTeam(state)
	local defendTeam = getPayloadDefendTeam(state)
	local cartPos = getPayloadCartPosition(watcher)
	if not isvector(cartPos) then return nil end

	if bot:Team() == attackTeam then
		return cartPos
	end

	if bot:Team() == defendTeam then
		local cappers = tonumber(state.cappers) or 0
		local contested = cappers > 0 or state.blocked or tonumber(state.trainState) == 1
		if contested then
			return cartPos
		end
		return getPayloadDefendPosition(watcher) or cartPos
	end

	return cartPos
end

local function nearestTeamFlagObjective(bot)
	if not IsValid(bot) then return nil end
	local origin = bot:GetPos()
	local best, bestDist
	local botTeam = bot:Team()
	local botBlueSide = isBlueSideTeamNum(botTeam)

	for _, flag in ipairs(ents.FindByClass("item_teamflag")) do
		if not IsValid(flag) then continue end

		local flagTeam = normalizeFlagTeamNum(flag.TeamNum or flag.Team or flag.te or (flag.GetNWInt and flag:GetNWInt("FlagTeamNum", -1) or -1))
		local neutralFlag = flagTeam == 0
		local sameTeam = (flagTeam == TEAM_RED and botTeam == TEAM_RED)
			or (flagTeam == TEAM_BLU and botBlueSide)
		if sameTeam then continue end
		if not neutralFlag and flagTeam ~= TEAM_RED and flagTeam ~= TEAM_BLU then continue end

		local pos = getPos(flag)
		if not isvector(pos) then continue end
		local d = origin:DistToSqr(pos)
		if not bestDist or d < bestDist then
			bestDist = d
			best = flag
		end
	end

	return best
end

local function getFlagCaptureZoneForBot(bot)
	if not IsValid(bot) then return nil end
	local botTeam = bot:Team()
	local botBlueSide = isBlueSideTeamNum(botTeam)
	local best, bestDist
	local origin = bot:GetPos()
	for _, zone in ipairs(ents.FindByClass("func_capturezone")) do
		if not IsValid(zone) then continue end
		local zoneTeam = normalizeFlagTeamNum(zone.TeamNum or zone.Team)
		local validZone = zoneTeam == 0
			or (zoneTeam == TEAM_RED and botTeam == TEAM_RED)
			or (zoneTeam == TEAM_BLU and botBlueSide)
		if not validZone then continue end
		local pos = getPos(zone)
		if not isvector(pos) then continue end
		local d = origin:DistToSqr(pos)
		if not bestDist or d < bestDist then
			bestDist = d
			best = zone
		end
	end
	return best
end

local function findCarriedTeamFlagByBot(bot)
	if not IsValid(bot) then return nil end
	for _, flag in ipairs(ents.FindByClass("item_teamflag")) do
		if not IsValid(flag) then continue end
		if IsValid(flag.Carrier) and flag.Carrier == bot then
			return flag
		end
	end
	return nil
end

function M:IsMvMMap()
	local mode = detectHudMode()
	return mode == "mvm"
end

function M:Select(bot, state)
	if not IsValid(bot) or not state then return end
	local now = CurTime()
	if now < (state.objective.nextUpdate or 0) and state.objective.targetPos then
		return
	end

	state.objective.nextUpdate = now + TFBotValveAI.Perf:GetInterval("objective")

	local hudMode = detectHudMode()
	local isMvM = hudMode == "mvm"

	if isMvM and cv_red_chase_blu:GetBool() and bot:Team() == TEAM_RED then
		if cv_red_collect_currency:GetBool() then
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
	if isMvM then
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

	if hudMode == "payload" then
		local payloadPos = getPayloadObjectivePosition(bot)
		if isvector(payloadPos) then
			state.objective.mode = "payload_objective"
			state.objective.targetEnt = nil
			state.objective.targetPos = payloadPos
			return
		end
	end

	if hudMode == "passtime" then
		local jack = nearestPasstimeObjective(bot)
		if IsValid(jack) then
			state.objective.mode = "passtime_seek_jack"
			state.objective.targetEnt = jack
			state.objective.targetPos = getPos(jack)
			return
		end
	end

	local carriedFlag = findCarriedTeamFlagByBot(bot)
	if IsValid(carriedFlag) then
		local capZone = getFlagCaptureZoneForBot(bot)
		if IsValid(capZone) then
			state.objective.mode = "carry_flag_to_capture"
			state.objective.targetEnt = capZone
			state.objective.targetPos = getPos(capZone)
			return
		end
	end

	local origin = bot:GetPos()
	local cpEnt, cpPos, cpMode = nearestControlPointObjective(bot)
	if IsValid(cpEnt) and isvector(cpPos) then
		state.objective.mode = cpMode
		state.objective.targetEnt = cpEnt
		state.objective.targetPos = cpPos
		return
	end

	if not bot.TF_MVM_IgnoreFlag then
		local flag = nearestTeamFlagObjective(bot)
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

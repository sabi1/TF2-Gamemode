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

TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.State = TFBotValveAI.State or {}

local M = TFBotValveAI.State

local function defaultState()
	return {
		vision = {
			memory = {},
			currentThreat = nil,
			nextTargetScan = 0,
		},
		objective = {
			mode = "idle",
			targetPos = nil,
			targetEnt = nil,
			nextUpdate = 0,
		},
		path = {
			segments = nil,
			index = 1,
			nextRepath = 0,
			stuckStart = 0,
			lastDist = nil,
		},
		class = {
			patient = nil,
			sniperHome = nil,
			spyLurkUntil = 0,
			spySapTarget = nil,
			reservedSentryHint = nil,
			reservedTeleExitHint = nil,
		},
		mvm = {
			mode = "none",
			routeType = "default",
			ignoreCombat = false,
			isCarrier = false,
			carrierSince = 0,
			carrierUpgradeLevel = 0,
			nextCarrierRegenAt = 0,
			sentryBusterFuseAt = 0,
			defendPatrolPos = nil,
			defendPatrolUntil = 0,
			deployState = "none",
			deployAnchor = nil,
			deployUntil = 0,
			teleUseUntil = 0,
			sniperLurkPos = nil,
			sniperLurkRefreshAt = 0,
		},
		perf = {
			nextSense = 0,
			nextMove = 0,
			nextThink = 0,
		},
	}
end

function M:Get(bot)
	if not IsValid(bot) then return nil end
	if not bot._tfbot_ai then
		bot._tfbot_ai = defaultState()
		local offset = (bot:EntIndex() % 7) * 0.03
		bot._tfbot_ai.perf.nextSense = (CurTime and CurTime() or 0) + offset
	end
	return bot._tfbot_ai
end

function M:Reset(bot)
	if not IsValid(bot) then return end
	bot._tfbot_ai = defaultState()
end

function M:ClearAll()
	for _, bot in ipairs(player.GetBots()) do
		if bot._tfbot_ai then
			bot._tfbot_ai = nil
		end
	end
	for _, bot in ipairs(ents.FindByClass("tf_bot_base_nextbot")) do
		if bot._tfbot_ai then
			bot._tfbot_ai = nil
		end
	end
end

return M

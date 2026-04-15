TFBots = TFBots or {}
TFBots.Runtime = TFBots.Runtime or {}

local M = TFBots.Runtime

local TIMER_ENFORCE = "TFBots_EnforceQuota"

local function get_red_team()
	return rawget(_G, "TEAM_RED") or 2
end

local function get_owned_bots()
	return (TFBots.Registry and TFBots.Registry:GetOwnedBots()) or {}
end

function M:EnforceQuota()
	local cfg = TFBots.Config
	local spawn = TFBots.Spawn
	if not (cfg and spawn and cfg:IsEnabled()) then return end

	local target = cfg:GetQuotaTarget()
	local ownedBots = get_owned_bots()
	local current = #ownedBots

	if current < target then
		local toSpawn = math.min(target - current, 2)
		for _ = 1, toSpawn do
			spawn:CreateBot(nil, get_red_team(), "scout", nil, nil, {
				TFBotQuotaOwned = true,
			})
		end
		return
	end

	if current <= target then return end

	for i = target + 1, current do
		local bot = ownedBots[i]
		if IsValid(bot) then
			spawn:RemoveBot(bot, "Quota reduced", true)
		end
	end
end

function M:HandleManagedBotRemoved(bot)
	if not bot then return end
	if TFBots.Registry then
		TFBots.Registry:Unregister(bot)
	end

	local silent = bot._tfbotManagerSilentRemove == true
	bot._tfbotManagerSilentRemove = nil

	local proxy = bot.BotProxyOwner
	if IsValid(proxy) and proxy.SpawnedBot == bot then
		proxy.SpawnedBot = nil
		if not silent and proxy.ScheduleRespawn then
			proxy:ScheduleRespawn()
		end
	end

	local controller = bot.BotControllerOwner
	if IsValid(controller) and controller.ManagedBot == bot then
		controller.ManagedBot = nil
	end

	local generator = bot.BotGeneratorOwner
	if IsValid(generator) then
		if generator.PruneBots then
			generator:PruneBots()
		end
		if not silent and generator.TriggerOutput then
			generator:TriggerOutput("OnBotKilled", bot, generator)
		end
	end
end

function M:Initialize()
	timer.Remove(TIMER_ENFORCE)
	timer.Create(TIMER_ENFORCE, 1, 0, function()
		if not TFBots or not TFBots.Runtime then return end
		TFBots.Runtime:EnforceQuota()
	end)

	hook.Add("EntityRemoved", "TFBots_RegistryCleanup", function(ent)
		if not ent or ent.TFBot ~= true then return end
		if not (ent.IsTFBotValveBase == true or (TFBots.Registry and TFBots.Registry:IsManaged(ent))) then return end
		TFBots.Runtime:HandleManagedBotRemoved(ent)
	end)

	hook.Add("PostCleanupMap", "TFBots_PostCleanup", function()
		if TFBots.Registry then
			TFBots.Registry:Clear()
		end
	end)
end

return M

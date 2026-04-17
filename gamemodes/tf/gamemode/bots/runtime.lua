TFBots = TFBots or {}
TFBots.Runtime = TFBots.Runtime or {}

local M = TFBots.Runtime

local TIMER_ENFORCE = "TFBots_EnforceQuota"

local function resetQuotaConVars()
	if TFBots and TFBots.Config and TFBots.Config.SetQuotaTarget then
		TFBots.Config:SetQuotaTarget(0)
	end
	RunConsoleCommand("tf_bot_quota", "0")
end

local function get_red_team()
	return rawget(_G, "TEAM_RED") or 2
end

local function get_blu_team()
	return rawget(_G, "TEAM_BLU") or 3
end

local AVAILABLE_CLASSES = {
	"scout",
	"sniper",
	"soldier",
	"demoman",
	"medic",
	"heavy",
	"pyro",
	"spy",
	"engineer",
}

local CLASS_NAMES = {
	scout = true,
	sniper = true,
	soldier = true,
	demoman = true,
	medic = true,
	heavy = true,
	pyro = true,
	spy = true,
	engineer = true,
	demo = "demoman",
	heavyweapons = "heavy",
}

local function normalize_class(className)
	local lower = string.lower(string.Trim(tostring(className or "scout")))
	local resolved = CLASS_NAMES[lower]
	if resolved == true then
		return lower
	end
	if isstring(resolved) then
		return resolved
	end
	return "scout"
end

local function pick_quota_team()
	local redCount = #team.GetPlayers(get_red_team())
	local bluCount = #team.GetPlayers(get_blu_team())
	if bluCount < redCount then
		return get_blu_team()
	end
	return get_red_team()
end

local function pick_quota_class()
	local forcedClass = GetConVar("tf_bot_force_class")
	if forcedClass then
		local forced = string.Trim(tostring(forcedClass:GetString() or ""))
		if forced ~= "" then
			return normalize_class(forced)
		end
	end
	return table.Random(AVAILABLE_CLASSES)
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
			spawn:CreateBot(nil, pick_quota_team(), pick_quota_class(), nil, nil, {
				useTeamSpawn = true,
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

	hook.Add("ShutDown", "TFBots_ResetQuotaOnShutdown", function()
		resetQuotaConVars()
	end)
end

return M

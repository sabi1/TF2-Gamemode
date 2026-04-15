TFBots = TFBots or {}
TFBots.Compat = TFBots.Compat or {}

local M = TFBots.Compat

function M:GetManagedBots()
	if TFBots.Registry then
		return TFBots.Registry:GetAllBots()
	end
	return player.GetBots()
end

function M:IsManagedBot(bot)
	if not IsValid(bot) then return false end
	if TFBots.Registry and TFBots.Registry:IsManaged(bot) then
		return true
	end
	return bot:IsPlayer() and bot:IsBot() and bot.TFBot == true
end

function M:CreateManagedMapBot(name, teamNum, className, spawnPos, spawnAng, options)
	local spawnOptions = {
		TFBotMapOwned = true,
	}

	if istable(options) then
		for key, value in pairs(options) do
			spawnOptions[key] = value
		end
	end

	return TFBots.Spawn and TFBots.Spawn:CreateBot(name, teamNum, className, spawnPos, spawnAng, spawnOptions) or nil
end

function M:RemoveManagedBot(bot, reason, silent)
	return TFBots.Spawn and TFBots.Spawn:RemoveBot(bot, reason, silent) or false
end

_G.TF_GetManagedBots = function()
	return M:GetManagedBots()
end

_G.TF_IsManagedBot = function(bot)
	return M:IsManagedBot(bot)
end

_G.TF_CreateManagedMapBot = function(name, teamNum, className, spawnPos, spawnAng, options)
	return M:CreateManagedMapBot(name, teamNum, className, spawnPos, spawnAng, options)
end

_G.TF_RemoveManagedBot = function(bot, reason, silent)
	return M:RemoveManagedBot(bot, reason, silent)
end

return M

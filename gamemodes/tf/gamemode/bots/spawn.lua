TFBots = TFBots or {}
TFBots.Spawn = TFBots.Spawn or {}

local M = TFBots.Spawn

local CLASS_ALIASES = {
	demo = "demoman",
	heavyweapons = "heavy",
}

local function normalize_class(className)
	local key = string.lower(string.Trim(tostring(className or "scout")))
	return CLASS_ALIASES[key] or key
end

local function get_red_team()
	return rawget(_G, "TEAM_RED") or 2
end

local function get_blu_team()
	return rawget(_G, "TEAM_BLU") or 3
end

local function normalize_team(teamNum)
	local text = string.lower(string.Trim(tostring(teamNum or "")))
	if text == "red" or text == "team_red" then return get_red_team() end
	if text == "blu" or text == "blue" or text == "team_blue" then return get_blu_team() end
	local num = tonumber(teamNum)
	if num == get_blu_team() or num == 3 then
		return get_blu_team()
	end
	return get_red_team()
end

function M:GetNextBotName()
	if isfunction(GetNextBotName) then
		local name = string.Trim(tostring(GetNextBotName() or ""))
		if name ~= "" then
			return name
		end
	end
	return "TFBot"
end

function M:CreateBot(name, teamNum, className, spawnPos, spawnAng, options)
	local cfg = TFBots.Config
	if not (cfg and cfg:IsEnabled()) then return nil end
	if not cfg:UseNextBotBackend() then
		cfg:Debug("player backend requested, but the clean manager only spawns nextbots right now")
		return nil
	end

	local botName = string.Trim(tostring(name or ""))
	if botName == "" then
		botName = self:GetNextBotName()
	end

	local bot = ents.Create("tf_bot_base_nextbot")
	if not IsValid(bot) then
		ErrorNoHalt("[TFBots] Failed to create tf_bot_base_nextbot.\n")
		return nil
	end

	if isvector(spawnPos) then
		bot:SetPos(spawnPos)
	end
	if isangle(spawnAng) then
		bot:SetAngles(spawnAng)
	end

	bot:Spawn()
	bot:Activate()
	bot.TFBot = true
	bot.TFBotManagerOwned = true
	bot._tfBotManagerName = botName
	bot:SetNWString("TF_BotDisplayName", botName)
	bot:SetTeam(normalize_team(teamNum))
	bot:SetPlayerClass(normalize_class(className))

	if TFBots.Registry then
		TFBots.Registry:Register(bot)
	end

	if istable(options) then
		for key, value in pairs(options) do
			bot[key] = value
		end
	end

	return bot
end

function M:RemoveBot(bot, reason, silent)
	if not IsValid(bot) then return false end
	if TFBots.Registry then
		TFBots.Registry:Unregister(bot)
	end
	bot._tfbotManagerSilentRemove = silent == true
	if bot.Kick then
		local ok = pcall(bot.Kick, bot, reason or "Removed by TFBots")
		if ok then
			return true
		end
	end
	bot:Remove()
	return true
end

function M:KillBot(bot)
	if not IsValid(bot) then return false end
	if bot.Kill then
		local ok = pcall(bot.Kill, bot)
		if ok then
			return true
		end
	end
	return self:RemoveBot(bot, "Killed by TFBots")
end

return M

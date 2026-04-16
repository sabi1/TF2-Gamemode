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

local function resolve_spawn_transform(bot, teamNum, className, spawnPos, spawnAng, options)
	local opts = istable(options) and options or nil
	local forceTeamSpawn = opts and opts.useTeamSpawn == true
	if isvector(spawnPos) and not forceTeamSpawn then
		return spawnPos, isangle(spawnAng) and spawnAng or angle_zero, nil
	end

	if not IsValid(bot) then
		return spawnPos, spawnAng, nil
	end

	if bot.SetTeam then
		bot:SetTeam(normalize_team(teamNum))
	end
	if bot.SetPlayerClass then
		bot:SetPlayerClass(normalize_class(className))
	end

	local gm = GAMEMODE or GM
	local chosen = nil
	if gm and gm.PlayerSelectSpawn then
		local ok, result = pcall(gm.PlayerSelectSpawn, gm, bot)
		if ok and IsValid(result) then
			chosen = result
		end
	end

	if not IsValid(chosen) then
		for _, candidate in ipairs(ents.FindByClass("info_player_teamspawn")) do
			if not IsValid(candidate) then continue end
			if candidate.IsAvailableForTeam and not candidate:IsAvailableForTeam(normalize_team(teamNum), false) then
				continue
			end
			chosen = candidate
			break
		end
	end

	if not IsValid(chosen) then
		return spawnPos, spawnAng, nil
	end

	local pos = chosen.GetPos and (chosen:GetPos() + Vector(0, 0, 8)) or spawnPos
	local ang = chosen.GetAngles and chosen:GetAngles() or spawnAng
	if isangle(ang) then
		ang = Angle(0, ang.y, 0)
	end
	return pos, ang, chosen
end

local function apply_spawn_transform(bot, teamNum, className, spawnPos, spawnAng, options)
	if not IsValid(bot) then return nil end
	local pos, ang, chosen = resolve_spawn_transform(bot, teamNum, className, spawnPos, spawnAng, options)
	if isvector(pos) then
		bot:SetPos(pos)
	end
	if isangle(ang) then
		if bot.SetEyeAngles then
			bot:SetEyeAngles(ang)
		else
			bot:SetAngles(ang)
		end
	end
	if bot.DropToFloor then
		bot:DropToFloor()
	end
	return chosen
end

local function reset_player_bot_state(bot)
	if not IsValid(bot) or not bot:IsPlayer() then return end

	if bot.RemoveAllConds then
		bot:RemoveAllConds()
	end

	if bot.SetNWBool then
		bot:SetNWBool("Invulnerable", false)
		bot:SetNWBool("SpawnGlows", false)
	end

	if bot.SetMaterial then
		bot:SetMaterial("")
	end

	if bot.SetColor then
		bot:SetColor(Color(255, 255, 255, 255))
	end
end

function M:CreateBot(name, teamNum, className, spawnPos, spawnAng, options)
	local cfg = TFBots.Config
	if not (cfg and cfg:IsEnabled()) then return nil end

	MsgN("[TFBots.Spawn] Creating bot: name=" .. tostring(name) .. ", team=" .. tostring(teamNum) .. ", class=" .. tostring(className))

	local botName = string.Trim(tostring(name or ""))
	if botName == "" then
		botName = self:GetNextBotName()
	end

	local requestedBackend = istable(options) and string.lower(tostring(options.backend or "")) or ""
	local usePlayerBackend = cfg:UsePlayerBackend()
	if requestedBackend == "nextbot" then
		usePlayerBackend = false
	elseif requestedBackend == "player" then
		usePlayerBackend = true
	end

	local bot
	if usePlayerBackend then
		if not (navmesh and navmesh.IsLoaded and navmesh.IsLoaded()) then
			ErrorNoHalt("[TFBots] Player bots require a loaded navmesh.\n")
			return nil
		end

		bot = player.CreateNextBot(botName)
		if not IsValid(bot) then
			ErrorNoHalt("[TFBots] Failed to create player bot.\n")
			return nil
		end

		if not IsValid(bot.ControllerBot) then
			bot.ControllerBot = ents.Create("ctf_bot_navigator")
			if IsValid(bot.ControllerBot) then
				bot.ControllerBot:Spawn()
				bot.ControllerBot:SetOwner(bot)
			end
		end

		bot.TFBot = true
		bot.TFBotManagerOwned = true
		bot._tfBotManagerName = botName
		bot:SetNWString("TF_BotDisplayName", botName)
		bot.LastPath = nil
		bot.CurSegment = 2
		reset_player_bot_state(bot)
		bot:SetTeam(normalize_team(teamNum))
		bot:SetPlayerClass(normalize_class(className))
		if isvector(spawnPos) then
			bot:SetPos(spawnPos)
		end
		if isangle(spawnAng) then
			bot:SetAngles(spawnAng)
		end
		apply_spawn_transform(bot, teamNum, className, spawnPos, spawnAng, options)

		timer.Simple(0.1, function()
			if not IsValid(bot) then return end
			bot.TFBot = true
			bot.TFBotManagerOwned = true
			bot._tfBotManagerName = botName
			bot:SetNWString("TF_BotDisplayName", botName)
			reset_player_bot_state(bot)
			bot:SetTeam(normalize_team(teamNum))
			bot:SetPlayerClass(normalize_class(className))
			apply_spawn_transform(bot, teamNum, className, spawnPos, spawnAng, options)
		end)
	else
		bot = ents.Create("tf_bot_base_nextbot")
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
		apply_spawn_transform(bot, teamNum, className, spawnPos, spawnAng, options)

		MsgN("[TFBots.Spawn] Created NextBot: " .. botName .. " - class=" .. tostring(bot:GetPlayerClass()) .. " (intended: " .. tostring(className) .. ")")
	end

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

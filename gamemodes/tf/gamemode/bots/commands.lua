TFBots = TFBots or {}
TFBots.Commands = TFBots.Commands or {}

local M = TFBots.Commands
M._registered = M._registered or false

local function register_command(name, fn)
	if concommand.Remove then
		pcall(concommand.Remove, name)
	end
	concommand.Add(name, fn)
end

local function get_bots()
	return (TF_GetManagedBots and TF_GetManagedBots()) or player.GetBots()
end

local function get_owned_bots()
	return (TFBots.Registry and TFBots.Registry:GetOwnedBots()) or {}
end

local function get_managed_bots()
	local registry = TFBots.Registry
	if registry and registry.GetAllBots then
		local out = {}
		for _, bot in ipairs(registry:GetAllBots()) do
			if TF_IsManagedBot and TF_IsManagedBot(bot) then
				out[#out + 1] = bot
			end
		end
		return out
	end
	return get_owned_bots()
end

local function is_admin(ply)
	return not IsValid(ply) or ply:IsAdmin() or ply:IsSuperAdmin()
end

local DIFFICULTY_STRINGS = {
	easy = "easy",
	normal = "normal",
	hard = "hard",
	expert = "expert",
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
	demo = "demoman",  -- alias
	heavyweapons = "heavy",  -- alias
}

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

local TEAM_STRINGS = {
	red = "red",
	blu = "blue",
	blue = "blue",
	auto = "auto",
}

local function get_red_team()
	return rawget(_G, "TEAM_RED") or 2
end

local function get_blu_team()
	return rawget(_G, "TEAM_BLU") or 3
end

local function is_difficulty(arg)
	return DIFFICULTY_STRINGS[string.lower(tostring(arg or ""))] ~= nil
end

local function is_classname(arg)
	local lower = string.lower(tostring(arg or ""))
	return CLASS_NAMES[lower] ~= nil
end

local function is_teamname(arg)
	local lower = string.lower(tostring(arg or ""))
	return TEAM_STRINGS[lower] ~= nil
end

local function is_noquota(arg)
	return string.lower(tostring(arg or "")) == "noquota"
end

local function is_positive_integer(arg)
	local num = tonumber(arg)
	return num and num > 0 and math.floor(num) == num
end

local function normalize_class(className)
	local lower = string.lower(string.Trim(tostring(className or "scout")))
	local resolved = CLASS_NAMES[lower]
	if resolved == true then
		return lower
	elseif isstring(resolved) then
		return resolved
	end
	return "scout"
end

local function normalize_team(teamStr)
	local lower = string.lower(string.Trim(tostring(teamStr or "auto")))
	if lower == "red" or lower == "team_red" then
		return get_red_team()
	end
	if lower == "blu" or lower == "blue" or lower == "team_blue" then
		return get_blu_team()
	end
	-- auto team selection - will be handled specially
	return "auto"
end

function M:Register()
	self._registered = true

	register_command("tf_bot_add", function(ply, _, args)
		if game.SinglePlayer() or not is_admin(ply) then return end

		-- Parse arguments (order-independent like Valve's)
		local botCount = 1
		local classname = nil
		local teamname = "auto"
		local difficulty = "normal"
		local bQuotaManaged = true
		local botName = nil

		for i = 1, #args do
			local arg = args[i]

			if is_positive_integer(arg) then
				botCount = math.floor(tonumber(arg))
				botName = nil  -- can't have custom name if spawning multiple
			elseif is_classname(arg) then
				classname = normalize_class(arg)
			elseif is_teamname(arg) then
				teamname = string.lower(arg)
			elseif is_difficulty(arg) then
				difficulty = string.lower(arg)
			elseif is_noquota(arg) then
				bQuotaManaged = false
			elseif botCount == 1 then
				-- If spawning only 1 bot and argument doesn't match other types, treat as custom name
				botName = arg
			end
		end

		-- Check tf_bot_force_class convar
		local forcedClass = GetConVar("tf_bot_force_class")
		if forcedClass and forcedClass:GetString() ~= "" then
			classname = normalize_class(forcedClass:GetString())
		end

		-- Set difficulty from convar if not overridden
		local difficultyVar = GetConVar("tf_bot_difficulty")
		if difficultyVar then
			local varDifficulty = string.lower(tostring(difficultyVar:GetString() or ""))
			if DIFFICULTY_STRINGS[varDifficulty] then
				difficulty = varDifficulty
			end
		end

		MsgN("[TFBots] Adding " .. botCount .. " bots, class=" .. tostring(classname or "random") .. ", team=" .. teamname .. ", difficulty=" .. difficulty)

		if bQuotaManaged and TFBots.Config and TFBots.Config.SetQuotaTarget and TFBots.Registry and TFBots.Registry.GetOwnedCount then
			local currentOwned = TFBots.Registry:GetOwnedCount()
			TFBots.Config:SetQuotaTarget(currentOwned + botCount)
		end

		-- Create bots
		for idx = 1, botCount do
			local resolvedTeam = teamname
			if teamname == "auto" then
				-- Auto team: pick team with fewer players
				resolvedTeam = get_red_team()
				local redCount = #team.GetPlayers(get_red_team())
				local bluCount = #team.GetPlayers(get_blu_team())
				if bluCount < redCount then
					resolvedTeam = get_blu_team()
				end
			else
				resolvedTeam = normalize_team(teamname)
			end

			-- If no class specified, pick a random one for this bot
			local botClass = classname or table.Random(AVAILABLE_CLASSES)
			MsgN("[TFBots] Bot " .. idx .. ": class=" .. botClass .. ", team=" .. resolvedTeam)

			local bot = TFBots.Spawn:CreateBot(botName, resolvedTeam, botClass, nil, nil, {
				useTeamSpawn = true,
				TFBotQuotaOwned = bQuotaManaged,
				difficulty = difficulty,
			})

			if IsValid(bot) and botName then
				-- Only use custom name for the first bot when spawning multiple
				botName = nil
			end
		end
	end)

	register_command("tf_bot_spawn", function(ply, _, args)
		if game.SinglePlayer() or not is_admin(ply) then return end
		RunConsoleCommand("tf_bot_add", args[1] or "1", args[2] or "scout", args[3] or "auto")
	end)

	register_command("tf_bot_quota", function(ply, _, args)
		if game.SinglePlayer() or not is_admin(ply) then return end
		local target = math.max(math.floor(tonumber(args[1] or 0) or 0), 0)
		TFBots.Config:SetQuotaTarget(target)
		TFBots.Runtime:EnforceQuota()
		MsgN("[TFBots] tf_bot_quota set to " .. tostring(target))
	end)

	register_command("tf_bot_kick_all", function(ply)
		if not is_admin(ply) then return end
		if TFBots.Config and TFBots.Config.SetQuotaTarget then
			TFBots.Config:SetQuotaTarget(0)
		end
		for _, bot in ipairs(get_managed_bots()) do
			TF_RemoveManagedBot(bot, "Kicked from server", true)
		end
	end)

	register_command("tf_bot_kill_all", function(ply)
		if not is_admin(ply) then return end
		if TFBots.Config and TFBots.Config.SetQuotaTarget then
			TFBots.Config:SetQuotaTarget(0)
		end
		for _, bot in ipairs(get_managed_bots()) do
			TFBots.Spawn:KillBot(bot)
		end
	end)

	register_command("tf_bot_kill_bots", function(ply)
		if not is_admin(ply) then return end
		if TFBots.Config and TFBots.Config.SetQuotaTarget then
			TFBots.Config:SetQuotaTarget(0)
		end
		for _, bot in ipairs(get_managed_bots()) do
			TFBots.Spawn:KillBot(bot)
		end
	end)

	register_command("tf_bot_bring_all", function(ply)
		local target = IsValid(ply) and ply or Entity(1)
		if not IsValid(target) then return end
		for _, bot in ipairs(get_bots()) do
			if IsValid(bot) then
				bot:SetPos(target:GetPos())
			end
		end
	end)

	register_command("tf_bot_goto", function(ply)
		if not IsValid(ply) then return end
		local bots = get_bots()
		if #bots == 0 then return end
		local bot = table.Random(bots)
		if IsValid(bot) then
			ply:SetPos(bot:GetPos())
		end
	end)

	register_command("tf_bot_bring", function(ply)
		local bots = get_bots()
		if #bots == 0 then return end
		local area = navmesh.GetNavArea(Entity(1):GetPos(), 5)
		if not IsValid(area) then return end
		local bot = table.Random(bots)
		if IsValid(bot) then
			bot:SetPos(area:GetRandomPoint())
		end
	end)

	register_command("tf_bot_scramble", function(ply)
		if not is_admin(ply) then return end
		for _, bot in ipairs(get_bots()) do
			if IsValid(bot) and bot.SetTeam then
				bot:SetTeam(math.random(2) == 1 and get_red_team() or get_blu_team())
			end
		end
	end)

	register_command("tf_spectate_bot", function(ply, _, args)
		if not IsValid(ply) then return end
		if args[1] == "2" then
			ply:Spectate(OBS_MODE_CHASE)
			return
		elseif args[1] == "1" then
			ply:Spectate(OBS_MODE_IN_EYE)
			return
		elseif args[1] == "3" then
			ply:Spectate(OBS_MODE_ROAMING)
			return
		end
		local bot = table.Random(get_bots())
		if not IsValid(bot) then return end
		ply:StripWeapons()
		ply:SpectateEntity(bot)
		ply:Spectate(OBS_MODE_IN_EYE)
	end)

	register_command("tf_unspectate_bot", function(ply)
		if not IsValid(ply) then return end
		ply:UnSpectate()
		ply:KillSilent()
		ply:Spawn()
	end)

	MsgN("[TFBots] registered bot console commands: tf_bot_add, tf_bot_spawn, tf_bot_quota, tf_bot_kick_all, tf_bot_kill_all")
end

return M

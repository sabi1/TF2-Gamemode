TFBots = TFBots or {}
TFBots.Commands = TFBots.Commands or {}

local M = TFBots.Commands

local function get_bots()
	return (TF_GetManagedBots and TF_GetManagedBots()) or player.GetBots()
end

local function get_owned_bots()
	return (TFBots.Registry and TFBots.Registry:GetOwnedBots()) or {}
end

local function is_admin(ply)
	return not IsValid(ply) or ply:IsAdmin() or ply:IsSuperAdmin()
end

local function parse_count(arg)
	return math.max(math.floor(tonumber(arg or 1) or 1), 1)
end

local function normalize_class(className)
	className = string.lower(string.Trim(tostring(className or "scout")))
	if className == "demo" then return "demoman" end
	if className == "heavyweapons" then return "heavy" end
	return className
end

local function get_red_team()
	return rawget(_G, "TEAM_RED") or 2
end

local function get_blu_team()
	return rawget(_G, "TEAM_BLU") or 3
end

local function normalize_team(teamNum)
	local text = string.lower(string.Trim(tostring(teamNum or "")))
	if text == "blu" or text == "blue" or text == "team_blue" then
		return get_blu_team()
	end
	local num = tonumber(teamNum)
	if num == get_blu_team() or num == 3 then
		return get_blu_team()
	end
	return get_red_team()
end

function M:Register()
	concommand.Add("tf_bot_add", function(ply, _, args)
		if game.SinglePlayer() or not is_admin(ply) then return end
		local count = parse_count(args[1])
		local className = normalize_class(args[2] or "scout")
		local teamNum = normalize_team(args[3] or get_red_team())
		for _ = 1, count do
			TFBots.Spawn:CreateBot(nil, teamNum, className)
		end
	end)

	concommand.Add("tf_bot_quota", function(ply, _, args)
		if game.SinglePlayer() or not is_admin(ply) then return end
		local target = math.max(math.floor(tonumber(args[1] or 0) or 0), 0)
		TFBots.Config:SetQuotaTarget(target)
		TFBots.Runtime:EnforceQuota()
		MsgN("[TFBots] tf_bot_quota set to " .. tostring(target))
	end)

	concommand.Add("tf_bot_kick_all", function(ply)
		if not is_admin(ply) then return end
		for _, bot in ipairs(get_owned_bots()) do
			TF_RemoveManagedBot(bot, "Kicked from server", true)
		end
	end)

	concommand.Add("tf_bot_kill_all", function(ply)
		if not is_admin(ply) then return end
		for _, bot in ipairs(get_owned_bots()) do
			TFBots.Spawn:KillBot(bot)
		end
	end)

	concommand.Add("tf_bot_kill_bots", function(ply)
		if not is_admin(ply) then return end
		for _, bot in ipairs(get_owned_bots()) do
			TFBots.Spawn:KillBot(bot)
		end
	end)

	concommand.Add("tf_bot_bring_all", function(ply)
		local target = IsValid(ply) and ply or Entity(1)
		if not IsValid(target) then return end
		for _, bot in ipairs(get_bots()) do
			if IsValid(bot) then
				bot:SetPos(target:GetPos())
			end
		end
	end)

	concommand.Add("tf_bot_goto", function(ply)
		if not IsValid(ply) then return end
		local bots = get_bots()
		if #bots == 0 then return end
		local bot = table.Random(bots)
		if IsValid(bot) then
			ply:SetPos(bot:GetPos())
		end
	end)

	concommand.Add("tf_bot_bring", function(ply)
		local bots = get_bots()
		if #bots == 0 then return end
		local area = navmesh.GetNavArea(Entity(1):GetPos(), 5)
		if not IsValid(area) then return end
		local bot = table.Random(bots)
		if IsValid(bot) then
			bot:SetPos(area:GetRandomPoint())
		end
	end)

	concommand.Add("tf_bot_scramble", function(ply)
		if not is_admin(ply) then return end
		for _, bot in ipairs(get_bots()) do
			if IsValid(bot) and bot.SetTeam then
				bot:SetTeam(math.random(2) == 1 and get_red_team() or get_blu_team())
			end
		end
	end)

	concommand.Add("tf_spectate_bot", function(ply, _, args)
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

	concommand.Add("tf_unspectate_bot", function(ply)
		if not IsValid(ply) then return end
		ply:UnSpectate()
		ply:KillSilent()
		ply:Spawn()
	end)
end

return M

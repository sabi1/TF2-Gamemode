ENT.Type = "point"

local CLASS_ALIASES = {
	demo = "demoman",
	heavyweapons = "heavy",
}

local TEAM_ALIASES = {
	red = TEAM_RED,
	team_red = TEAM_RED,
	blu = TEAM_BLU,
	blue = TEAM_BLU,
	team_blue = TEAM_BLU,
}

local function normalize_class(value)
	local className = string.lower(string.Trim(tostring(value or "scout")))
	return CLASS_ALIASES[className] or className
end

local function normalize_team(value)
	local text = string.lower(string.Trim(tostring(value or "")))
	if TEAM_ALIASES[text] then
		return TEAM_ALIASES[text]
	end
	local num = tonumber(value)
	if num == 2 then return TEAM_RED end
	if num == 3 then return TEAM_BLU end
	return TEAM_RED
end

local function boolify(value, default)
	if value == nil then return default end
	if isbool(value) then return value end
	local num = tonumber(value)
	if num ~= nil then
		return num ~= 0
	end
	local text = string.lower(string.Trim(tostring(value)))
	if text == "true" or text == "yes" or text == "on" then return true end
	if text == "false" or text == "no" or text == "off" then return false end
	return default
end

local function create_proxy_bot(proxy)
	local nickname = string.Trim(tostring(proxy.Properties.bot_name or ""))
	if nickname == "" and isfunction(GetNextBotName) then
		nickname = GetNextBotName()
	end
	if nickname == "" then
		nickname = "TFBotProxy"
	end

	local bot = TF_CreateManagedMapBot and TF_CreateManagedMapBot(nickname, proxy.TeamNum, proxy.ClassName, proxy:GetPos(), proxy:GetAngles()) or nil
	if not IsValid(bot) then return nil end

	bot.BotProxyOwner = proxy
	bot._botProxyLastHealth = bot:Health()

	timer.Simple(0.1, function()
		if not IsValid(bot) then return end
		bot.TFBot = true
		bot:SetTeam(proxy.TeamNum)
		bot:SetPlayerClass(proxy.ClassName)
		if IsValid(proxy.ActionPoint) then
			TF_BotAssignActionPoint(bot, proxy.ActionPoint)
		end
	end)

	return bot
end

function TF_CreateManagedMapBot(name, teamNum, className, spawnPos, spawnAng)
	if not (navmesh and navmesh.IsLoaded and navmesh.IsLoaded()) then
		ErrorNoHalt("Map bot entities require a loaded navmesh.\n")
		return nil
	end

	local botName = string.Trim(tostring(name or ""))
	if botName == "" and isfunction(GetNextBotName) then
		botName = GetNextBotName()
	end
	if botName == "" then
		botName = "TFMapBot"
	end

	local bot = player.CreateNextBot(botName)
	if not IsValid(bot) then
		ErrorNoHalt("[TF map bot] Player limit reached.\n")
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
	bot.LastPath = nil
	bot.CurSegment = 2
	bot:SetTeam(teamNum or TEAM_RED)
	bot:SetPlayerClass(className or "scout")
	if isvector(spawnPos) then
		bot:SetPos(spawnPos)
	end
	if isangle(spawnAng) then
		bot:SetAngles(spawnAng)
	end

	timer.Simple(0.1, function()
		if not IsValid(bot) then return end
		bot.TFBot = true
		bot:SetTeam(teamNum or TEAM_RED)
		bot:SetPlayerClass(className or "scout")
	end)

	return bot
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.TeamNum = normalize_team(self.Properties.team)
	self.ClassName = normalize_class(self.Properties.class)
	self.RespawnInterval = tonumber(self.Properties.respawn_interval) or 0
	self.SpawnOnStart = boolify(self.Properties.spawn_on_start, false)
	self.ActionPoint = nil
	self.SpawnedBot = nil
	if SERVER then
		timer.Simple(0, function()
			if not IsValid(self) then return end
			self:ResolveMovementGoal()
			if self.SpawnOnStart then
				self:SpawnProxyBot()
			end
		end)
	end
end

function ENT:OnRemove()
	if SERVER and self._respawnTimerId then
		timer.Remove(self._respawnTimerId)
	end
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if string.StartWith(key, "on") and self.StoreOutput then
		self:StoreOutput(key, value)
		return
	end
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if key == "team" then
		self.TeamNum = normalize_team(value)
	elseif key == "class" then
		self.ClassName = normalize_class(value)
	elseif key == "respawn_interval" then
		self.RespawnInterval = tonumber(value) or 0
	elseif key == "spawn_on_start" then
		self.SpawnOnStart = boolify(value, false)
	end
end

function ENT:ResolveMovementGoal()
	local goalName = tostring(self.Properties.action_point or "")
	self.ActionPoint = TF_BotActionPointResolve and TF_BotActionPointResolve(goalName) or nil
	return self.ActionPoint
end

function ENT:ScheduleRespawn()
	if self.RespawnInterval <= 0 then return end
	self._respawnTimerId = "TF_BotProxyRespawn_" .. self:EntIndex()
	timer.Remove(self._respawnTimerId)
	timer.Create(self._respawnTimerId, self.RespawnInterval, 1, function()
		if IsValid(self) and not IsValid(self.SpawnedBot) then
			self:SpawnProxyBot()
		end
	end)
end

function ENT:SpawnProxyBot()
	if IsValid(self.SpawnedBot) then
		return self.SpawnedBot
	end
	self:ResolveMovementGoal()
	local bot = create_proxy_bot(self)
	if not IsValid(bot) then
		return nil
	end
	self.SpawnedBot = bot
	if self.TriggerOutput then
		self:TriggerOutput("OnSpawned", bot, bot)
	end
	return bot
end

function ENT:DeleteProxyBot()
	if self._respawnTimerId then
		timer.Remove(self._respawnTimerId)
	end
	if IsValid(self.SpawnedBot) then
		local bot = self.SpawnedBot
		self.SpawnedBot = nil
		bot.BotProxyOwner = nil
		bot:Kick("Removed by bot_proxy")
		return true
	end
	return false
end

function ENT:Think()
	if IsValid(self.SpawnedBot) and IsValid(self.ActionPoint) then
		TF_BotAssignActionPoint(self.SpawnedBot, self.ActionPoint)
	end
	self:NextThink(CurTime() + 0.25)
	return true
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "setteam" then
		self.TeamNum = normalize_team(data)
		self.Properties.team = data
		if IsValid(self.SpawnedBot) then
			self.SpawnedBot:SetTeam(self.TeamNum)
		end
		return true
	end
	if name == "setclass" then
		self.ClassName = normalize_class(data)
		self.Properties.class = data
		if IsValid(self.SpawnedBot) then
			self.SpawnedBot:SetPlayerClass(self.ClassName)
		end
		return true
	end
	if name == "setmovementgoal" then
		self.Properties.action_point = tostring(data or "")
		self:ResolveMovementGoal()
		if IsValid(self.SpawnedBot) and IsValid(self.ActionPoint) then
			TF_BotAssignActionPoint(self.SpawnedBot, self.ActionPoint)
		end
		return true
	end
	if name == "spawn" then
		return IsValid(self:SpawnProxyBot())
	end
	if name == "delete" then
		return self:DeleteProxyBot()
	end
	return false
end

if SERVER then
	hook.Add("EntityTakeDamage", "TF_BotProxyDamageRelay", function(target, dmginfo)
		if IsValid(target) and target:IsPlayer() and target.TFBot and IsValid(target.BotProxyOwner) then
			local proxy = target.BotProxyOwner
			if dmginfo:GetDamage() > 0 and proxy.TriggerOutput then
				proxy:TriggerOutput("OnInjured", proxy, proxy)
			end
		end

		local attacker = dmginfo:GetAttacker()
		if IsValid(attacker) and attacker:IsPlayer() and attacker.TFBot and IsValid(attacker.BotProxyOwner) then
			local proxy = attacker.BotProxyOwner
			local now = CurTime()
			if proxy._nextAttackOutput == nil or proxy._nextAttackOutput <= now then
				proxy._nextAttackOutput = now + 0.5
				if proxy.TriggerOutput then
					proxy:TriggerOutput("OnAttackingEnemy", proxy, proxy)
				end
			end
		end
	end)

	hook.Add("PlayerDeath", "TF_BotProxyDeathRelay", function(victim, inflictor, attacker)
		if IsValid(victim) and victim.TFBot and IsValid(victim.BotProxyOwner) then
			local proxy = victim.BotProxyOwner
			if proxy.TriggerOutput then
				proxy:TriggerOutput("OnKilled", proxy, proxy)
			end
			if IsValid(proxy.SpawnedBot) and proxy.SpawnedBot == victim then
				proxy.SpawnedBot = nil
				proxy:ScheduleRespawn()
			end
		end

		if IsValid(attacker) and attacker:IsPlayer() and attacker.TFBot and IsValid(attacker.BotProxyOwner) then
			local proxy = attacker.BotProxyOwner
			if proxy.TriggerOutput then
				proxy:TriggerOutput("OnKilledEnemy", proxy, proxy)
			end
		end
	end)
end

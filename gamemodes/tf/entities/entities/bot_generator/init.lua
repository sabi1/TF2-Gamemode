ENT.Type = "point"

local CLASS_ALIASES = {
	demo = "demoman",
	heavyweapons = "heavy",
}

local function normalize_class(value)
	local className = string.lower(string.Trim(tostring(value or "scout")))
	return CLASS_ALIASES[className] or className
end

local function normalize_team(value)
	local text = string.lower(string.Trim(tostring(value or "")))
	if text == "red" or text == "team_red" then return TEAM_RED end
	if text == "blu" or text == "blue" or text == "team_blue" then return TEAM_BLU end
	local num = tonumber(value)
	if num == 3 then return TEAM_BLU end
	return TEAM_RED
end

local function boolify(value, default)
	if value == nil then return default end
	if isbool(value) then return value end
	local num = tonumber(value)
	if num ~= nil then return num ~= 0 end
	local text = string.lower(string.Trim(tostring(value)))
	if text == "true" or text == "yes" or text == "on" then return true end
	if text == "false" or text == "no" or text == "off" then return false end
	return default
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.SpawnedBots = self.SpawnedBots or {}
	self.Enabled = true
	self.TeamNum = normalize_team(self.Properties.team)
	self.ClassName = normalize_class(self.Properties.class)
	self.SpawnCountRemaining = tonumber(self.Properties.count) or 0
	self.MaxActive = math.max(tonumber(self.Properties.maxactive) or 1, 1)
	self.Interval = math.max(tonumber(self.Properties.interval) or 5, 0.1)
	self.SpawnOnlyWhenTriggered = boolify(self.Properties.spawnonlywhentriggered, false)
	self.SuppressFire = boolify(self.Properties.suppressfire, false)
	self.DisableDodge = boolify(self.Properties.disabledodge, false)
	self.Difficulty = tonumber(self.Properties.difficulty) or 0
	self.AttentionFocus = nil
	if SERVER then
		timer.Simple(0, function()
			if not IsValid(self) then return end
			self:ResolveActionPoint()
			self:SetNextThink(CurTime() + self.Interval)
		end)
	end
end

function ENT:OnRemove()
	self:RemoveBots()
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
	elseif key == "count" then
		self.SpawnCountRemaining = tonumber(value) or 0
	elseif key == "maxactive" then
		self.MaxActive = math.max(tonumber(value) or 1, 1)
	elseif key == "interval" then
		self.Interval = math.max(tonumber(value) or 5, 0.1)
	elseif key == "spawnonlywhentriggered" then
		self.SpawnOnlyWhenTriggered = boolify(value, false)
	elseif key == "suppressfire" then
		self.SuppressFire = boolify(value, false)
	elseif key == "disabledodge" then
		self.DisableDodge = boolify(value, false)
	elseif key == "difficulty" then
		self.Difficulty = tonumber(value) or 0
	end
end

function ENT:ResolveActionPoint()
	self.ActionPoint = TF_BotActionPointResolve and TF_BotActionPointResolve(tostring(self.Properties.action_point or "")) or nil
	return self.ActionPoint
end

function ENT:ResolveAttentionFocus()
	local name = tostring(self.Properties.attention_focus or "")
	if name == "" then
		self.AttentionFocus = nil
		return nil
	end
	for _, ent in ipairs(ents.FindByName(name)) do
		if IsValid(ent) then
			self.AttentionFocus = ent
			return ent
		end
	end
	self.AttentionFocus = nil
	return nil
end

function ENT:PruneBots()
	local alive = {}
	for _, bot in ipairs(self.SpawnedBots or {}) do
		if IsValid(bot) then
			alive[#alive + 1] = bot
		end
	end
	self.SpawnedBots = alive
	return alive
end

function ENT:ApplyBotSettings(bot)
	if not IsValid(bot) then return end
	bot.SuppressFire = self.SuppressFire
	bot.DisableDodge = self.DisableDodge
	bot.BotDifficulty = self.Difficulty
	bot.BotGeneratorOwner = self
	if IsValid(self.AttentionFocus) then
		bot.TargetEnt = self.AttentionFocus
		bot.botPos = self.AttentionFocus:GetPos()
	elseif IsValid(self.ActionPoint) then
		TF_BotAssignActionPoint(bot, self.ActionPoint)
	end
	if bot.OnCommandString and tostring(self.Properties.initial_command or "") ~= "" then
		pcall(bot.OnCommandString, bot, tostring(self.Properties.initial_command))
	end
end

function ENT:SpawnBot()
	if not self.Enabled then return nil end
	self:PruneBots()
	if #self.SpawnedBots >= self.MaxActive then return nil end
	if self.SpawnCountRemaining == 0 then return nil end
	if TF_BotRosterAllowsClass and not TF_BotRosterAllowsClass(self.TeamNum, self.ClassName) then
		return nil
	end

	self:ResolveActionPoint()
	self:ResolveAttentionFocus()

	local bot = TF_CreateManagedMapBot and TF_CreateManagedMapBot("", self.TeamNum, self.ClassName, self:GetPos(), self:GetAngles()) or nil
	if not IsValid(bot) then return nil end
	self:ApplyBotSettings(bot)
	self.SpawnedBots[#self.SpawnedBots + 1] = bot
	if self.SpawnCountRemaining > 0 then
		self.SpawnCountRemaining = self.SpawnCountRemaining - 1
		if self.SpawnCountRemaining == 0 and self.TriggerOutput then
			self:TriggerOutput("OnExpended", self, self)
		end
	end
	if self.TriggerOutput then
		self:TriggerOutput("OnSpawned", bot, self)
	end
	return bot
end

function ENT:RemoveBots()
	for _, bot in ipairs(self.SpawnedBots or {}) do
		if IsValid(bot) then
			bot.BotGeneratorOwner = nil
			bot:Kick("Removed by bot_generator")
		end
	end
	self.SpawnedBots = {}
end

function ENT:Think()
	if self.Enabled and not self.SpawnOnlyWhenTriggered then
		self:SpawnBot()
	end
	self:SetNextThink(CurTime() + self.Interval)
	return true
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Enabled = true
		return true
	elseif name == "disable" then
		self.Enabled = false
		return true
	elseif name == "setsuppressfire" then
		self.SuppressFire = boolify(data, false)
		for _, bot in ipairs(self.SpawnedBots or {}) do
			if IsValid(bot) then bot.SuppressFire = self.SuppressFire end
		end
		return true
	elseif name == "setdisabledodge" then
		self.DisableDodge = boolify(data, false)
		for _, bot in ipairs(self.SpawnedBots or {}) do
			if IsValid(bot) then bot.DisableDodge = self.DisableDodge end
		end
		return true
	elseif name == "setdifficulty" then
		self.Difficulty = tonumber(data) or 0
		for _, bot in ipairs(self.SpawnedBots or {}) do
			if IsValid(bot) then bot.BotDifficulty = self.Difficulty end
		end
		return true
	elseif name == "commandgotoactionpoint" then
		self.Properties.action_point = tostring(data or "")
		self:ResolveActionPoint()
		for _, bot in ipairs(self.SpawnedBots or {}) do
			if IsValid(bot) and IsValid(self.ActionPoint) then
				TF_BotAssignActionPoint(bot, self.ActionPoint)
			end
		end
		return true
	elseif name == "setattentionfocus" then
		self.Properties.attention_focus = tostring(data or "")
		self:ResolveAttentionFocus()
		for _, bot in ipairs(self.SpawnedBots or {}) do
			if IsValid(bot) and IsValid(self.AttentionFocus) then
				bot.TargetEnt = self.AttentionFocus
				bot.botPos = self.AttentionFocus:GetPos()
			end
		end
		return true
	elseif name == "clearattentionfocus" then
		self.Properties.attention_focus = ""
		self.AttentionFocus = nil
		for _, bot in ipairs(self.SpawnedBots or {}) do
			if IsValid(bot) then
				bot.TargetEnt = nil
				if IsValid(self.ActionPoint) then
					TF_BotAssignActionPoint(bot, self.ActionPoint)
				end
			end
		end
		return true
	elseif name == "spawnbot" then
		return IsValid(self:SpawnBot())
	elseif name == "removebots" then
		self:RemoveBots()
		return true
	end
	return false
end

if SERVER then
	hook.Add("PlayerDeath", "TF_BotGeneratorDeathRelay", function(victim)
		if not (IsValid(victim) and victim.TFBot and IsValid(victim.BotGeneratorOwner)) then return end
		local generator = victim.BotGeneratorOwner
		generator:PruneBots()
		if generator.TriggerOutput then
			generator:TriggerOutput("OnBotKilled", victim, generator)
		end
	end)
end

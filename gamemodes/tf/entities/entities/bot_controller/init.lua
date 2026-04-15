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

local function resolve_named_entity(name)
	if not isstring(name) or name == "" then return nil end
	for _, ent in ipairs(ents.FindByName(name)) do
		if IsValid(ent) then
			return ent
		end
	end
	return nil
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.CommandQueue = self.CommandQueue or {}
	self.TeamNum = normalize_team(self.Properties.teamnum or self.Properties.team)
	self.BotName = string.Trim(tostring(self.Properties.bot_name or ""))
	self.BotClass = normalize_class(self.Properties.bot_class or "scout")
	self.IgnoreHumans = false
	self.MovementPrevented = false
	self.ManagedBot = nil
	self:SetNextThink(CurTime() + 0.1)
end

function ENT:OnRemove()
	if IsValid(self.ManagedBot) then
		self.ManagedBot.BotControllerOwner = nil
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
	if key == "bot_name" then
		self.BotName = string.Trim(tostring(value or ""))
	elseif key == "bot_class" then
		self.BotClass = normalize_class(value)
	elseif key == "teamnum" or key == "team" then
		self.TeamNum = normalize_team(value)
	end
end

function ENT:SpawnControlledBot()
	if IsValid(self.ManagedBot) then
		return self.ManagedBot
	end
	local bot = TF_CreateManagedMapBot and TF_CreateManagedMapBot(self.BotName, self.TeamNum, self.BotClass, self:GetPos(), self:GetAngles()) or nil
	if not IsValid(bot) then return nil end
	bot.BotControllerOwner = self
	self.ManagedBot = bot
	return bot
end

function ENT:RespawnControlledBot()
	if IsValid(self.ManagedBot) then
		self.ManagedBot.BotControllerOwner = nil
		TF_RemoveManagedBot(self.ManagedBot, "Respawned by bot_controller", true)
		self.ManagedBot = nil
	end
	return self:SpawnControlledBot()
end

function ENT:QueueCommand(cmdType, data)
	self.CommandQueue = self.CommandQueue or {}
	self.CommandQueue[#self.CommandQueue + 1] = {
		type = cmdType,
		data = data,
		start = CurTime(),
	}
end

function ENT:FinishCurrentCommand()
	table.remove(self.CommandQueue, 1)
	if self.TriggerOutput then
		self:TriggerOutput("OnCommandFinished", self, self)
	end
end

function ENT:ProcessCurrentCommand(bot)
	local cmd = self.CommandQueue and self.CommandQueue[1] or nil
	if not cmd then return end

	if self.MovementPrevented then
		bot.botPos = bot:GetPos()
		return
	end

	if cmd.type == "move_entity" then
		local target = resolve_named_entity(cmd.data)
		if not IsValid(target) then
			self:FinishCurrentCommand()
			return
		end
		bot.botPos = target:GetPos()
		if bot:GetPos():DistToSqr(target:GetPos()) <= (64 * 64) then
			self:FinishCurrentCommand()
		end
	elseif cmd.type == "attack_entity" then
		local target = resolve_named_entity(cmd.data)
		if not IsValid(target) then
			self:FinishCurrentCommand()
			return
		end
		bot.TargetEnt = target
		bot.botPos = target:GetPos()
		if target.Health and target:Health() <= 0 then
			self:FinishCurrentCommand()
		end
	elseif cmd.type == "switch_weapon" then
		if bot.SelectWeapon then
			pcall(bot.SelectWeapon, bot, tostring(cmd.data or ""))
		end
		self:FinishCurrentCommand()
	elseif cmd.type == "defend" then
		local target = resolve_named_entity(cmd.data)
		bot.botPos = IsValid(target) and target:GetPos() or self:GetPos()
		if CurTime() >= (cmd.start + 1.0) then
			self:FinishCurrentCommand()
		end
	end
end

function ENT:Think()
	if IsValid(self.ManagedBot) then
		if self.IgnoreHumans then
			self.ManagedBot.TargetEnt = nil
		end
		self:ProcessCurrentCommand(self.ManagedBot)
	end
	self:SetNextThink(CurTime() + 0.1)
	return true
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "createbot" then
		return IsValid(self:SpawnControlledBot())
	elseif name == "respawnbot" then
		return IsValid(self:RespawnControlledBot())
	elseif name == "addcommandmovetoentity" then
		self:QueueCommand("move_entity", tostring(data or ""))
		return true
	elseif name == "addcommandattackentity" then
		self:QueueCommand("attack_entity", tostring(data or ""))
		return true
	elseif name == "addcommandswitchweapon" then
		self:QueueCommand("switch_weapon", tostring(data or ""))
		return true
	elseif name == "addcommanddefend" then
		self:QueueCommand("defend", tostring(data or ""))
		return true
	elseif name == "setignorehumans" then
		self.IgnoreHumans = boolify(data, false)
		return true
	elseif name == "preventmovement" then
		self.MovementPrevented = boolify(data, true)
		return true
	elseif name == "clearqueue" then
		self.CommandQueue = {}
		return true
	end
	return false
end

ENT.Type = "point"

local function get_goal_pos(ent)
	if not IsValid(ent) then return nil end
	if ent.GetPos then
		return ent:GetPos()
	end
	return nil
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.NextActionPoint = self.NextActionPoint or nil
	self.DesiredDistance = tonumber(self.Properties.desired_distance) or 0
	self.StayTime = tonumber(self.Properties.stay_time) or 0
	self.Command = tostring(self.Properties.command or "")
	if SERVER then
		timer.Simple(0, function()
			if IsValid(self) then
				self:ResolveTargets()
			end
		end)
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
	if key == "desired_distance" then
		self.DesiredDistance = tonumber(value) or 0
	elseif key == "stay_time" then
		self.StayTime = tonumber(value) or 0
	elseif key == "command" then
		self.Command = tostring(value or "")
	end
end

function ENT:ResolveTargets()
	local nextName = tostring(self.Properties.next_action_point or "")
	if nextName == "" then
		self.NextActionPoint = nil
		return
	end
	for _, ent in ipairs(ents.FindByName(nextName)) do
		if IsValid(ent) and ent:GetClass() == "bot_action_point" then
			self.NextActionPoint = ent
			return
		end
	end
	self.NextActionPoint = nil
end

function ENT:GetNextActionPoint()
	if not IsValid(self.NextActionPoint) then
		self:ResolveTargets()
	end
	return self.NextActionPoint
end

function ENT:GetDesiredDistance()
	return math.max(tonumber(self.DesiredDistance) or 0, 0)
end

function ENT:GetStayTime()
	return math.max(tonumber(self.StayTime) or 0, 0)
end

function ENT:IsWithinRange(ent)
	if not IsValid(ent) then return false end
	local goalPos = get_goal_pos(self)
	if not isvector(goalPos) then return false end
	local maxDist = self:GetDesiredDistance()
	return ent:GetPos():DistToSqr(goalPos) <= (maxDist * maxDist)
end

function ENT:ReachedActionPoint(bot)
	if not IsValid(bot) then return end
	local command = string.Trim(tostring(self.Command or ""))
	if command ~= "" and bot.OnCommandString then
		pcall(bot.OnCommandString, bot, command)
	end
	if self.TriggerOutput then
		self:TriggerOutput("OnBotReached", bot, self)
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "setnextactionpoint" then
		self.Properties.next_action_point = tostring(data or "")
		self:ResolveTargets()
		return true
	end
	return false
end

function TF_BotActionPointResolve(name)
	if not isstring(name) or name == "" then return nil end
	for _, ent in ipairs(ents.FindByName(name)) do
		if IsValid(ent) and ent:GetClass() == "bot_action_point" then
			return ent
		end
	end
	return nil
end

local function advance_bot_action_point(bot, point)
	if not IsValid(bot) or not IsValid(point) then return end
	local nextPoint = point:GetNextActionPoint()
	bot.TFBotActionPoint = nextPoint
	bot._tfBotActionStayUntil = nil
	if IsValid(nextPoint) then
		bot.botPos = nextPoint:GetPos()
	end
end

function TF_BotAssignActionPoint(bot, point)
	if not IsValid(bot) then return false end
	if isstring(point) then
		point = TF_BotActionPointResolve(point)
	end
	if not IsValid(point) then
		bot.TFBotActionPoint = nil
		bot._tfBotActionStayUntil = nil
		return false
	end
	bot.TFBotActionPoint = point
	bot._tfBotActionStayUntil = nil
	bot.botPos = point:GetPos()
	return true
end

if SERVER then
	hook.Add("Think", "TF_BotActionPointThink", function()
		for _, bot in ipairs(player.GetBots()) do
			local point = bot.TFBotActionPoint
			if not IsValid(point) then continue end
			bot.botPos = point:GetPos()
			if not point:IsWithinRange(bot) then
				bot._tfBotActionStayUntil = nil
				continue
			end
			local now = CurTime()
			if not bot._tfBotActionStayUntil then
				bot._tfBotActionStayUntil = now + point:GetStayTime()
			end
			if now < bot._tfBotActionStayUntil then
				continue
			end
			point:ReachedActionPoint(bot)
			advance_bot_action_point(bot, point)
		end
	end)
end

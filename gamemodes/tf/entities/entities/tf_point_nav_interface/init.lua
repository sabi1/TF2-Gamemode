ENT.Type = "point"

local function reset_bot_path_state(bot)
	if not IsValid(bot) then return end
	bot.path = nil
	bot.targetArea = nil
	bot.lastRePath = 0
	bot.lastRePath2 = 0
	bot._nextObjectiveRecover = 0
	bot._segmentAreaId = nil
	bot._segmentBestDist = nil
	bot._segmentBestStamp = nil
	if IsValid(bot.ControllerBot) then
		bot.ControllerBot.LastSegmented = 0
	end
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:RecomputeBlockers()
	for _, bot in ipairs(player.GetBots()) do
		if bot.TFBot or bot.IsTFBotValveBase then
			reset_bot_path_state(bot)
		end
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "recomputeblockers" then
		self:RecomputeBlockers()
		return true
	end
	return false
end

function TF_RecomputeBotNavBlockers()
	for _, ent in ipairs(ents.FindByClass("tf_point_nav_interface")) do
		if IsValid(ent) then
			ent:RecomputeBlockers()
		end
	end
end

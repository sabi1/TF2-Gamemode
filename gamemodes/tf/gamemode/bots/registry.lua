TFBots = TFBots or {}
TFBots.Registry = TFBots.Registry or {}

local M = TFBots.Registry

M._owned = M._owned or {}

local function add_unique(list, ent, seen)
	if not IsValid(ent) then return end
	local idx = ent:EntIndex()
	if seen[idx] then return end
	seen[idx] = true
	list[#list + 1] = ent
end

function M:Register(bot)
	if not IsValid(bot) then return false end
	self._owned[bot] = true
	return true
end

function M:Unregister(bot)
	if not bot then return false end
	self._owned[bot] = nil
	return true
end

function M:IsManaged(bot)
	if not IsValid(bot) then return false end
	if self._owned[bot] then
		return true
	end
	return bot.TFBot == true and bot.IsTFBotValveBase == true and bot.TFBotManagerOwned == true
end

function M:GetOwnedBots()
	local out = {}
	for bot in pairs(self._owned) do
		if IsValid(bot) then
			out[#out + 1] = bot
		else
			self._owned[bot] = nil
		end
	end
	return out
end

function M:GetAllBots()
	local out = {}
	local seen = {}
	for _, bot in ipairs(self:GetOwnedBots()) do
		add_unique(out, bot, seen)
	end
	for _, bot in ipairs(player.GetBots()) do
		add_unique(out, bot, seen)
	end
	return out
end

function M:GetOwnedCount()
	return #self:GetOwnedBots()
end

function M:Clear()
	self._owned = {}
end

return M


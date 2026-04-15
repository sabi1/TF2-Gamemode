TFBotSource = TFBotSource or {}
TFBotSource.Manager = TFBotSource.Manager or {}

local M = TFBotSource.Manager

function M:TrackBot(bot)
	self._bots = self._bots or {}
	if IsValid(bot) then
		self._bots[bot] = true
	end
end

function M:GetBots()
	local out = {}
	self._bots = self._bots or {}
	for bot in pairs(self._bots) do
		if IsValid(bot) then
			out[#out + 1] = bot
		else
			self._bots[bot] = nil
		end
	end
	return out
end

function M:Reset()
	self._bots = {}
end

return M


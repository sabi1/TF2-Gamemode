TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.Perf = TFBotValveAI.Perf or {}

local M = TFBotValveAI.Perf

local modeProfiles = {
	max = {
		sense = 0.35,
		objective = 1.0,
		move = 0.0,
		repath = 2.2,
	},
	balanced = {
		sense = 0.30,
		objective = 0.85,
		move = 0.0,
		repath = 1.9,
	},
	ultra = {
		sense = 0.45,
		objective = 1.25,
		move = 0.0,
		repath = 2.8,
	},
}

function M:GetAdaptiveScale()
	local base = TFBotValveAI and TFBotValveAI.Base or nil
	local botCount = base and base.GetManagedAgents and #base:GetManagedAgents() or #player.GetBots()
	botCount = math.max(botCount, 1)
	if botCount <= 8 then return 1 end
	if botCount <= 16 then return 1.3 end
	if botCount <= 24 then return 1.7 end
	return 2.2
end

function M:GetProfile()
	local cfg = TFBotValveAI.Config
	local mode = cfg and cfg:GetPerfMode() or "max"
	return modeProfiles[mode] or modeProfiles.max
end

function M:GetInterval(kind)
	local profile = self:GetProfile()
	local base = profile[kind] or 0.2
	if base <= 0 then
		return 0
	end
	return base * self:GetAdaptiveScale()
end

function M:CanRun(now, nextAt)
	return now >= (nextAt or 0)
end

return M

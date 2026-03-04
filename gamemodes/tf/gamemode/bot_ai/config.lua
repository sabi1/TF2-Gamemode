TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.Config = TFBotValveAI.Config or {}

local M = TFBotValveAI.Config

M.cv_enable = CreateConVar("tf_bot_valve_ai_enable", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable modular Valve-style bot AI controller.")
M.cv_debug = CreateConVar("tf_bot_valve_ai_debug", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable debug logs for modular Valve-style bot AI.")
M.cv_compat_legacy_path = CreateConVar("tf_bot_valve_ai_compat_legacy_path", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "When enabled, keep legacy path ownership while modular AI handles targeting/combat.")
M.cv_perf_mode = CreateConVar("tf_bot_valve_ai_perf_mode", "max", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Performance profile for modular bot AI: max|balanced|ultra.")
M.cv_backend = CreateConVar("tf_bot_valve_ai_backend", "player", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "AI backend: player|nextbot|hybrid")

local function clampPerfMode(value)
	local v = string.lower(tostring(value or "max"))
	if v ~= "max" and v ~= "balanced" and v ~= "ultra" then
		return "max"
	end
	return v
end

function M:IsEnabled()
	return self.cv_enable:GetBool()
end

function M:IsDebug()
	return self.cv_debug:GetBool()
end

function M:UseLegacyPathCompat()
	return self.cv_compat_legacy_path:GetBool()
end

function M:GetPerfMode()
	return clampPerfMode(self.cv_perf_mode:GetString())
end

function M:GetBackend()
	local v = string.lower(tostring(self.cv_backend:GetString() or "player"))
	if v ~= "player" and v ~= "nextbot" and v ~= "hybrid" then
		return "player"
	end
	return v
end

function M:UsePlayerBackend()
	local v = self:GetBackend()
	return v == "player" or v == "hybrid"
end

function M:UseNextBotBackend()
	local v = self:GetBackend()
	return v == "nextbot" or v == "hybrid"
end

function M:Debug(msg)
	if self:IsDebug() then
		MsgN("[tf_bot_valve_ai] " .. tostring(msg))
	end
end

return M

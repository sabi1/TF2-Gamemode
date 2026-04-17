TFBots = TFBots or {}
TFBots.Config = TFBots.Config or {}

local M = TFBots.Config

M.cv_enable = CreateConVar("tf_bot_manager_enable", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable the cleaned bot manager bootstrap.")
-- Keep manager-owned spawns on player.CreateNextBot by default so bots are
-- treated as player bots, with AI issuing commands behind the fake client.
M.cv_backend = CreateConVar("tf_bot_manager_backend", "player", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bot manager backend: nextbot|player|hybrid.")
M.cv_quota = CreateConVar("tf_bot_manager_quota_target", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Target number of manager-owned bots to keep alive.")
M.cv_debug = CreateConVar("tf_bot_manager_debug", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable debug logs for the cleaned bot manager.")
-- Matches TF2's tf_bot_melee_only server cvar so bot weapon code can safely
-- query melee-only restrictions even after the legacy bot module removal.
M.cv_melee_only = CreateConVar("tf_bot_melee_only", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "If nonzero, TFBots will only use melee weapons.")
M.cv_prefix_name_with_difficulty = CreateConVar("tf_bot_prefix_name_with_difficulty", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Append the skill level of the bot to the bot's name.")

function M:IsEnabled()
	return self.cv_enable:GetBool()
end

function M:IsDebug()
	return self.cv_debug:GetBool()
end

function M:GetBackend()
	local backend = string.lower(tostring(self.cv_backend:GetString() or "player"))
	if backend ~= "nextbot" and backend ~= "player" and backend ~= "hybrid" then
		return "player"
	end
	return backend
end

function M:UseNextBotBackend()
	local backend = self:GetBackend()
	return backend == "nextbot" or backend == "hybrid"
end

function M:UsePlayerBackend()
	local backend = self:GetBackend()
	return backend == "player" or backend == "hybrid"
end

function M:GetQuotaTarget()
	return math.max(math.floor(tonumber(self.cv_quota:GetString()) or 0), 0)
end

function M:IsMeleeOnly()
	return self.cv_melee_only:GetBool()
end

function M:ShouldPrefixNameWithDifficulty()
	return self.cv_prefix_name_with_difficulty:GetBool()
end

function M:SetQuotaTarget(value)
	RunConsoleCommand("tf_bot_manager_quota_target", tostring(math.max(math.floor(tonumber(value) or 0), 0)))
end

function M:Debug(msg)
	if self:IsDebug() then
		MsgN("[TFBots] " .. tostring(msg))
	end
end

return M

if CLIENT then return end

TFBots = TFBots or {}

include("bots/config.lua")
include("bots/registry.lua")
include("bots/spawn.lua")
include("bots/runtime.lua")
include("bots/compat.lua")
include("bots/commands.lua")

if TFBots.Runtime and TFBots.Runtime.Initialize then
	TFBots.Runtime:Initialize()
end

if TFBots.Commands and TFBots.Commands.Register then
	TFBots.Commands:Register()
end

local function safeInclude(path)
	local ok, err = pcall(include, path)
	if ok then
		return true
	end
	ErrorNoHalt(string.format("[TFBots] failed to include %s: %s\n", tostring(path), tostring(err)))
	return false
end

safeInclude("tfbot/init.lua")
safeInclude("bot_ai/init.lua")

local valveBackend = GetConVar("tf_bot_valve_ai_backend")
if valveBackend and string.lower(tostring(valveBackend:GetString() or "")) == "player" then
	RunConsoleCommand("tf_bot_valve_ai_backend", "nextbot")
	MsgN("[TFBots] switched tf_bot_valve_ai_backend to nextbot so the source-shaped TFBot brain runs on tf_bot_base_nextbot.")
end

timer.Simple(0, function()
	local forcePlayer = GetConVar("tf_mvm_force_player_bots")
	if forcePlayer and forcePlayer:GetBool() then
		RunConsoleCommand("tf_mvm_force_player_bots", "0")
		MsgN("[TFBots] switched tf_mvm_force_player_bots to 0 so MvM keeps using tf_bot_base_nextbot.")
	end
end)

_G.TFBOT_LEGACY_BOOTSTRAP_ACTIVE = false

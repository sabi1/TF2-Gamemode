if CLIENT then return end

TFBots = TFBots or {}

include("bots/config.lua")
include("bots/registry.lua")
include("bots/spawn.lua")
include("bots/runtime.lua")
include("bots/compat.lua")
include("bots/commands.lua")

include("bot_ai/init.lua")

local valveBackend = GetConVar("tf_bot_valve_ai_backend")
if valveBackend and string.lower(tostring(valveBackend:GetString() or "")) == "player" then
	RunConsoleCommand("tf_bot_valve_ai_backend", "nextbot")
	MsgN("[TFBots] switched tf_bot_valve_ai_backend to nextbot because the legacy player-bot bootstrap is disabled.")
end

if TFBots.Runtime and TFBots.Runtime.Initialize then
	TFBots.Runtime:Initialize()
end

if TFBots.Commands and TFBots.Commands.Register then
	TFBots.Commands:Register()
end

timer.Simple(0, function()
	local forcePlayer = GetConVar("tf_mvm_force_player_bots")
	if forcePlayer and forcePlayer:GetBool() then
		RunConsoleCommand("tf_mvm_force_player_bots", "0")
		MsgN("[TFBots] switched tf_mvm_force_player_bots to 0 because the legacy player-bot bootstrap is disabled.")
	end
end)

_G.TFBOT_LEGACY_BOOTSTRAP_ACTIVE = false

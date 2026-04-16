if CLIENT then return end

TFBots = TFBots or {}

include("config.lua")
include("registry.lua")
include("spawn.lua")
include("runtime.lua")
include("compat.lua")
include("commands.lua")

if TFBots.Runtime and TFBots.Runtime.Initialize then
	TFBots.Runtime:Initialize()
end

if TFBots.Commands and TFBots.Commands.Register then
	TFBots.Commands:Register()
end

_G.TFBOT_LEGACY_BOOTSTRAP_ACTIVE = false

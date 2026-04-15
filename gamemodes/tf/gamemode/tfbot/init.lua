if CLIENT then return end

TFBotSource = TFBotSource or {}

include("tfbot/core.lua")
include("tfbot/manager.lua")
include("tfbot/vision.lua")
include("tfbot/behavior.lua")
include("tfbot/tactical_monitor.lua")
include("tfbot/actions/attack.lua")
include("tfbot/actions/get_health.lua")
include("tfbot/actions/get_ammo.lua")
include("tfbot/actions/retreat_to_cover.lua")
include("tfbot/actions/melee_attack.lua")
include("tfbot/actions/use_teleporter.lua")
include("tfbot/actions/destroy_enemy_sentry.lua")
include("tfbot/actions/seek_and_destroy.lua")
include("tfbot/actions/medic_heal.lua")
include("tfbot/actions/sniper_lurk.lua")
include("tfbot/actions/fetch_flag.lua")
include("tfbot/actions/attack_flag_defenders.lua")
include("tfbot/actions/escort_flag_carrier.lua")
include("tfbot/actions/spy_attack.lua")
include("tfbot/actions/spy_sap.lua")
include("tfbot/actions/spy_infiltrate.lua")
include("tfbot/actions/engineer_idle.lua")
include("tfbot/main_action.lua")
include("tfbot/scenario_monitor.lua")

local Core = TFBotSource.Core
local Manager = TFBotSource.Manager
local Vision = TFBotSource.Vision
local Behavior = TFBotSource.Behavior
local TacticalMonitor = TFBotSource.TacticalMonitor
local ScenarioMonitor = TFBotSource.ScenarioMonitor
local MainAction = TFBotSource.MainAction

function TFBotSource:PreUpdate(bot, st)
	if not IsValid(bot) or bot.TFBot ~= true then return end
	Core:EnsureState(bot, st)
	Vision:Update(bot, st)
	Manager:TrackBot(bot)
end

function TFBotSource:PostUpdate(bot, st)
	if not IsValid(bot) or bot.TFBot ~= true then return end
	local profile = Core:EnsureState(bot, st)
	local actionName = ScenarioMonitor:SelectAction(bot, st, profile)
	if TacticalMonitor and TacticalMonitor.SelectAction then
		actionName = TacticalMonitor:SelectAction(bot, st, profile, actionName) or actionName
	end
	Behavior:SetAction(bot, st, actionName)
	MainAction:Update(bot, st, profile)
	bot:SetNWString("TFBot_SourceAction", tostring(actionName or "none"))
end

function TFBotSource:ApplyPlayerCommand(bot, cmd, st)
	if not IsValid(bot) or not st then return end
	local profile = Core:EnsureState(bot, st)
	MainAction:ApplyPlayerCommand(bot, cmd, st, profile)
end

hook.Add("PostCleanupMap", "TFBotSource_PostCleanupMap", function()
	if TFBotSource.Manager and TFBotSource.Manager.Reset then
		TFBotSource.Manager:Reset()
	end
end)

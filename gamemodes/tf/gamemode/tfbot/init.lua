if CLIENT then return end

TFBotSource = TFBotSource or {}

include("core.lua")
include("manager.lua")
include("vision.lua")
include("behavior.lua")
include("tactical_monitor.lua")
include("actions/attack.lua")
include("actions/get_health.lua")
include("actions/get_ammo.lua")
include("actions/retreat_to_cover.lua")
include("actions/melee_attack.lua")
include("actions/use_teleporter.lua")
include("actions/destroy_enemy_sentry.lua")
include("actions/seek_and_destroy.lua")
include("actions/payload_push.lua")
include("actions/payload_guard.lua")
include("actions/capture_point.lua")
include("actions/defend_point.lua")
include("actions/medic_heal.lua")
include("actions/sniper_lurk.lua")
include("actions/fetch_flag.lua")
include("actions/deliver_flag.lua")
include("actions/push_to_capture_point.lua")
include("actions/attack_flag_defenders.lua")
include("actions/escort_flag_carrier.lua")
include("actions/spy_attack.lua")
include("actions/spy_sap.lua")
include("actions/spy_infiltrate.lua")
include("actions/engineer_idle.lua")
include("main_action.lua")
include("scenario_monitor.lua")

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

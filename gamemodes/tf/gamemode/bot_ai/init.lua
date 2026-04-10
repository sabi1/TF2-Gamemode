TFBotValveAI = TFBotValveAI or {}

local function SafeInclude(path)
	local ok, err = pcall(include, path)
	if ok then
		return true
	end

	-- Fallback for include roots that are not this directory.
	local alt = "bot_ai/" .. tostring(path)
	local ok2, err2 = pcall(include, alt)
	if ok2 then
		return true
	end

	MsgN("[tf_bot_valve_ai] include failed: " .. tostring(path) .. " :: " .. tostring(err))
	MsgN("[tf_bot_valve_ai] include failed: " .. tostring(alt) .. " :: " .. tostring(err2))
	return false
end

-- Paths are relative to this folder.
SafeInclude("config.lua")
SafeInclude("base.lua")
SafeInclude("state.lua")
SafeInclude("perf.lua")
SafeInclude("vision.lua")
SafeInclude("threat.lua")
SafeInclude("mvm.lua")
SafeInclude("objective.lua")
SafeInclude("hints.lua")
SafeInclude("pathing.lua")
SafeInclude("movement.lua")
SafeInclude("combat.lua")
SafeInclude("class_medic.lua")
SafeInclude("class_spy.lua")
SafeInclude("class_sniper.lua")
SafeInclude("class_engineer.lua")

local cfg = TFBotValveAI.Config
local base = TFBotValveAI.Base
local state = TFBotValveAI.State
local perf = TFBotValveAI.Perf
local threat = TFBotValveAI.Threat
local objective = TFBotValveAI.Objective
local mvm = TFBotValveAI.MvM
local hints = TFBotValveAI.Hints
local movement = TFBotValveAI.Movement
local combat = TFBotValveAI.Combat

if not cfg or not base or not state or not perf or not threat or not objective or not mvm or not hints or not movement or not combat then
	_G.TFBOT_VALVE_AI_ACTIVE = false
	MsgN("[tf_bot_valve_ai] disabled due to missing modules")
	return
end

local clsHandlers = {
	TFBotValveAI.ClassMedic,
	TFBotValveAI.ClassSpy,
	TFBotValveAI.ClassSniper,
	TFBotValveAI.ClassEngineer,
}

local function runClassHandlers(bot, st)
	for _, h in ipairs(clsHandlers) do
		if h and h.Update and h:Update(bot, st) then
			return
		end
	end
end

local function syncLegacyPlayerBotFields(bot, st)
	if not base:IsPlayerAgent(bot) then return end
	bot.botPos = st.objective and st.objective.targetPos or nil
	bot._tfbotObjectiveEnt = st.objective and st.objective.targetEnt or nil
	bot.TargetEnt = st.vision and st.vision.currentThreat or nil
	bot._tfbotObjectiveMode = st.objective and st.objective.mode or "none"
end

local function aiThink()
	if not cfg:IsEnabled() then
		_G.TFBOT_VALVE_AI_ACTIVE = false
		return
	end
	-- This global is used by legacy player-bot hooks as an ownership switch.
	-- Only assert ownership for player bots when player backend is active.
	_G.TFBOT_VALVE_AI_ACTIVE = cfg:UsePlayerBackend()

	local now = CurTime()
	for _, bot in ipairs(base:GetManagedAgents()) do
		if not base:IsAlive(bot) then continue end
		local st = state:Get(bot)
		if not perf:CanRun(now, st.perf.nextSense) then continue end

		st.perf.nextSense = now + perf:GetInterval("sense")
		threat:SelectTarget(bot, st)
		objective:Select(bot, st)
		mvm:Tick(bot, st)
		hints:Apply(bot, st)
		runClassHandlers(bot, st)
		syncLegacyPlayerBotFields(bot, st)
		if base:IsNextBotAgent(bot) then
			base:ApplyNextBotModules(bot, st, movement, combat)
		end
	end
end

local function aiStartCommand(bot, cmd)
	if not cfg:IsEnabled() then return end
	if not cfg:UsePlayerBackend() then return end
	if not base:IsPlayerAgent(bot) or not bot:Alive() then return end

	local st = state:Get(bot)
	movement:Apply(bot, cmd, st)
	combat:Update(bot, cmd, st)
end

local function aiCleanup()
	state:ClearAll()
end

hook.Add("Think", "TFBot_ValveAI_Think", aiThink)
hook.Add("StartCommand", "TFBot_ValveAI_StartCommand", aiStartCommand)
hook.Add("PostCleanupMap", "TFBot_ValveAI_PostCleanupMap", aiCleanup)

concommand.Add("tf_bot_valve_ai_add_nextbot", function(ply, _, args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	local tr
	if IsValid(ply) then
		tr = ply:GetEyeTrace()
	end
	local spawnPos = nil
	if tr and tr.Hit and isvector(tr.HitPos) and isvector(tr.HitNormal) then
		spawnPos = tr.HitPos + tr.HitNormal * 20
	end
	if not isvector(spawnPos) then
		local host = Entity(1)
		spawnPos = IsValid(host) and (host:GetPos() + Vector(64, 0, 8)) or Vector(0, 0, 32)
	end

	local ent = ents.Create("tf_bot_base_nextbot")
	if not IsValid(ent) then return end
	ent:SetPos(spawnPos)
	ent:Spawn()
	ent:Activate()

	local cls = string.lower(tostring(args and args[1] or "scout"))
	local teamId = tonumber(args and args[2] or TEAM_RED) or TEAM_RED
	ent:SetPlayerClass(cls)
	ent:SetTeam(teamId)
	cfg:Debug("spawned tf_bot_base_nextbot class=" .. tostring(cls) .. " team=" .. tostring(teamId))
end, nil, "Spawn a modular-AI NextBot base bot. Usage: tf_bot_valve_ai_add_nextbot [class] [team]")

cvars.AddChangeCallback("tf_bot_valve_ai_enable", function(_, _, newVal)
	local enabled = tonumber(newVal) == 1
	_G.TFBOT_VALVE_AI_ACTIVE = enabled and cfg and cfg.UsePlayerBackend and cfg:UsePlayerBackend() or false
	if cfg and cfg.Debug then
		cfg:Debug("runtime toggle: tf_bot_valve_ai_enable=" .. tostring(newVal))
	end
	if not enabled then
		if state and state.ClearAll then
			state:ClearAll()
		end
	end
end, "TFBotValveAIToggle")

_G.TFBOT_VALVE_AI_ACTIVE = cfg:IsEnabled() and cfg:UsePlayerBackend()
cfg:Debug("modular bot AI initialized")

TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.ClassSniper = TFBotValveAI.ClassSniper or {}

local M = TFBotValveAI.ClassSniper

local cv_flee = CreateConVar("tf_bot_sniper_flee_range", "400", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_melee = CreateConVar("tf_bot_sniper_melee_range", "200", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_linger = CreateConVar("tf_bot_sniper_linger_time", "5", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_patience = CreateConVar("tf_bot_sniper_patience_duration", "10", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_target_linger = CreateConVar("tf_bot_sniper_target_linger_duration", "2", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_opportunistic = CreateConVar("tf_bot_sniper_allow_opportunistic", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY})

function M:Update(bot, state)
	local cls = string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
	if cls ~= "sniper" and cls ~= "giantsniper" then return false end

	if state and state.objective and state.objective.mode == "hint_sniper_spot" and isvector(state.objective.targetPos) then
		return true
	end

	local threat = state.vision.currentThreat
	if IsValid(threat) then
		local dist = bot:GetPos():Distance(threat:GetPos())
		state.class.sniperLastSeenAt = CurTime()
		if dist < cv_flee:GetFloat() and IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot then
			local retreat = bot.ControllerBot:FindSpot("far", { radius = 1400, pos = bot:GetPos(), type = "hiding" })
			if retreat then
				state.objective.mode = "sniper_retreat"
				state.objective.targetPos = retreat
				state.objective.targetEnt = nil
				state.class.sniperHome = retreat
				return true
			end
		end
		if dist < cv_melee:GetFloat() then
			state.objective.mode = "sniper_melee_pressure"
			state.objective.targetEnt = threat
			state.objective.targetPos = threat:GetPos()
			state.class.forceMeleeUntil = CurTime() + 1.2
			return true
		end
		state.class.sniperLingerUntil = CurTime() + cv_linger:GetFloat()
		if cv_opportunistic:GetBool() and not state.class.sniperHome then
			state.class.sniperHome = bot:GetPos()
			state.class.sniperPatienceUntil = CurTime() + cv_patience:GetFloat()
		end
		return true
	end

	local lastSeenAt = tonumber(state.class.sniperLastSeenAt or 0)
	if lastSeenAt > 0 and (CurTime() - lastSeenAt) < cv_target_linger:GetFloat() then
		-- Keep aiming at recent target area for a short linger window.
		if IsValid(state.objective.targetEnt) then
			state.objective.targetPos = state.objective.targetEnt:GetPos()
		end
		return true
	end

	if CurTime() > (state.class.sniperLingerUntil or 0) then
		if CurTime() > (state.class.sniperPatienceUntil or 0) and IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot then
			local home = bot.ControllerBot:FindSpot("far", { radius = 2400, pos = bot:GetPos(), type = "exposed" })
			if home then
				state.class.sniperHome = home
				state.class.sniperPatienceUntil = CurTime() + cv_patience:GetFloat()
			end
		end
	end

	if state.class.sniperHome then
		state.objective.mode = "sniper_home"
		state.objective.targetPos = state.class.sniperHome
		state.objective.targetEnt = nil
	end
	return true
end

return M

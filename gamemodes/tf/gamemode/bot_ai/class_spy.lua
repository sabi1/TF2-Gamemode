TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.ClassSpy = TFBotValveAI.ClassSpy or {}

local M = TFBotValveAI.ClassSpy

local cv_sap = CreateConVar("tf_bot_spy_sap_range", "80", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_backstab = CreateConVar("tf_bot_spy_backstab_range", "150", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_lurk_min = CreateConVar("tf_bot_spy_lurk_time_min", "3.0", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_lurk_max = CreateConVar("tf_bot_spy_lurk_time_max", "5.0", {FCVAR_ARCHIVE, FCVAR_NOTIFY})

function M:Update(bot, state)
	local cls = string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
	if cls ~= "spy" and cls ~= "giantspy" then return false end

	local threat = state.vision.currentThreat
	if IsValid(threat) and threat.IsPlayer and threat:IsPlayer() then
		local dist = bot:GetPos():Distance(threat:GetPos())
		if dist <= cv_backstab:GetFloat() then
			state.objective.mode = "spy_backstab"
			state.objective.targetEnt = threat
			state.objective.targetPos = threat:GetPos()
			return true
		end
	end

	local sentry = ents.FindByClass("obj_sentrygun")[1]
	if IsValid(sentry) and not sentry:IsFriendly(bot) then
		local dist = bot:GetPos():Distance(sentry:GetPos())
		if dist <= cv_sap:GetFloat() * 3 then
			state.class.spySapTarget = sentry
			state.objective.mode = "spy_sap"
			state.objective.targetEnt = sentry
			state.objective.targetPos = sentry:GetPos()
			return true
		end
	end

	if CurTime() > (state.class.spyLurkUntil or 0) then
		state.class.spyLurkUntil = CurTime() + math.Rand(cv_lurk_min:GetFloat(), cv_lurk_max:GetFloat())
		if IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot then
			local lurk = bot.ControllerBot:FindSpot("random", { radius = 1600, pos = bot:GetPos(), type = "hiding" })
			if lurk then
				state.objective.mode = "spy_lurk"
				state.objective.targetPos = lurk
				state.objective.targetEnt = nil
			end
		end
	end

	return true
end

return M

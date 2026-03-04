TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.ClassMedic = TFBotValveAI.ClassMedic or {}

local M = TFBotValveAI.ClassMedic

local cv_follow_start = CreateConVar("tf_bot_medic_start_follow_range", "250", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_follow_stop = CreateConVar("tf_bot_medic_stop_follow_range", "75", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_max_heal = CreateConVar("tf_bot_medic_max_heal_range", "600", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_call_range = CreateConVar("tf_bot_medic_max_call_response_range", "1000", {FCVAR_ARCHIVE, FCVAR_NOTIFY})

local CLASS_PREF = {
	heavy = 0,
	soldier = 0,
	pyro = 0,
	demoman = 1,
}

local function findPatient(bot)
	local best
	local bestScore = -math.huge
	local candidates
	local base = TFBotValveAI and TFBotValveAI.Base
	if base and base.GetManagedAgents then
		candidates = base:GetManagedAgents()
	else
		candidates = player.GetBots()
	end
	for _, ply in ipairs(candidates) do
		if not IsValid(ply) or not ply:Alive() then continue end
		if ply:EntIndex() == bot:EntIndex() then continue end
		if not ply:IsFriendly(bot) then continue end
		local cls = string.lower(tostring((ply.GetPlayerClass and ply:GetPlayerClass()) or ply.playerclass or ""))
		if cls == "medic" or cls == "sniper" or cls == "engineer" or cls == "spy" then continue end
		local ratio = ply:Health() / math.max(ply:GetMaxHealth(), 1)
		local dist = bot:GetPos():Distance(ply:GetPos())
		local pref = CLASS_PREF[cls] or 2
		local score = (1.0 - ratio) * 1200 - dist - (pref * 120)
		if ply.HasTheFlag and ply:HasTheFlag() then
			score = score + 1200
		end
		if ply.IsCallingForMedic and ply:IsCallingForMedic() and dist <= cv_call_range:GetFloat() then
			score = score + 900
		end
		if score > bestScore then
			bestScore = score
			best = ply
		end
	end
	return best
end

function M:Update(bot, state)
	local cls = string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
	if cls ~= "medic" and cls ~= "giantmedic" then return false end

	local patient = findPatient(bot)
	if not IsValid(patient) then
		return false
	end

	state.class.patient = patient
	local dist = bot:GetPos():Distance(patient:GetPos())
	state.class.medicInCombat = IsValid(state.vision.currentThreat)
	if state.class.medicInCombat and dist > cv_max_heal:GetFloat() then
		state.objective.mode = "medic_close_gap"
		state.objective.targetPos = patient:GetPos()
		state.objective.targetEnt = patient
		return true
	end
	if dist > cv_follow_start:GetFloat() then
		state.objective.targetPos = patient:GetPos()
		state.objective.targetEnt = patient
		state.objective.mode = "medic_follow"
	elseif dist < cv_follow_stop:GetFloat() then
		state.objective.targetPos = bot:GetPos()
	end
	return true
end

return M

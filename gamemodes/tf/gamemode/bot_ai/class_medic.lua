TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.ClassMedic = TFBotValveAI.ClassMedic or {}

local M = TFBotValveAI.ClassMedic

local cv_follow_start = CreateConVar("tf_bot_medic_start_follow_range", "250", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_follow_stop = CreateConVar("tf_bot_medic_stop_follow_range", "75", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_max_heal = CreateConVar("tf_bot_medic_max_heal_range", "600", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_call_range = CreateConVar("tf_bot_medic_max_call_response_range", "1000", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_stable_ratio = CreateConVar("tf_bot_medic_stable_ratio", "0.95", {FCVAR_ARCHIVE, FCVAR_NOTIFY})

local CLASS_PREF = {
	heavy = 0,
	soldier = 0,
	pyro = 0,
	demoman = 1,
}

local function getClassName(ply)
	return string.lower(tostring((ply.GetPlayerClass and ply:GetPlayerClass()) or ply.playerclass or ""))
end

local function getHealthRatio(ply, allowOverheal)
	if not IsValid(ply) then return 1 end
	local maxHealth = math.max(tonumber(ply:GetMaxHealth()) or 1, 1)
	if allowOverheal and ply.GetMaxBuffedHealth then
		maxHealth = math.max(maxHealth, tonumber(ply:GetMaxBuffedHealth()) or maxHealth)
	end
	return math.Clamp((tonumber(ply:Health()) or 0) / maxHealth, 0, 4)
end

local function countOtherHealers(patient, medic)
	if not IsValid(patient) or not patient.GetNumHealers then return 0 end
	local num = tonumber(patient:GetNumHealers()) or 0
	local count = 0
	for i = 1, num do
		local healer = patient.GetHealerByIndex and patient:GetHealerByIndex(i - 1) or nil
		if IsValid(healer) and healer ~= medic and healer:IsPlayer() then
			count = count + 1
		end
	end
	return count
end

local function isCallingForMedicRecent(ply)
	if not IsValid(ply) then return false end
	if ply.IsCallingForMedic and ply:IsCallingForMedic() then
		return true
	end
	local callTime = tonumber(ply:GetNW2Float("tf_medic_call_time", 0) or 0)
	return callTime > 0 and (CurTime() - callTime) <= 5.0
end

local function isGoodPrimaryPatientClass(cls)
	return cls ~= "medic" and cls ~= "sniper" and cls ~= "engineer" and cls ~= "spy"
end

local function patientPriorityScore(bot, ply, currentPatient)
	local bestScore = -math.huge
	local candidates
	local cls = getClassName(ply)
	local ratio = getHealthRatio(ply, false)
	local dist = bot:GetPos():Distance(ply:GetPos())
	local pref = CLASS_PREF[cls] or 2
	local score = (1.0 - ratio) * 1400 - dist - (pref * 120)

	if not isGoodPrimaryPatientClass(cls) then
		score = score - 600
	end
	if countOtherHealers(ply, bot) > 0 then
		score = score - 900
	end
	if currentPatient == ply then
		score = score + 150
	end
	if ply.HasTheFlag and ply:HasTheFlag() then
		score = score + 1400
	end
	if isCallingForMedicRecent(ply) and dist <= cv_call_range:GetFloat() then
		score = score + 1000
	end
	if ply.InCond and ply:InCond(TF_COND_BURNING) then
		score = score + 800
	end
	if ply.InCond and ply:InCond(TF_COND_BLEEDING) then
		score = score + 300
	end

	return score
end

local function findPatient(bot, currentPatient)
	local best = currentPatient
	local bestScore = IsValid(currentPatient) and patientPriorityScore(bot, currentPatient, currentPatient) or -math.huge
	local base = TFBotValveAI and TFBotValveAI.Base
	local candidates = (base and base.GetManagedAgents and base:GetManagedAgents()) or player.GetBots()
	for _, ply in ipairs(candidates) do
		if not IsValid(ply) or not ply:Alive() then continue end
		if ply:EntIndex() == bot:EntIndex() then continue end
		if not ply:IsFriendly(bot) then continue end
		local score = patientPriorityScore(bot, ply, currentPatient)
		if score > bestScore then
			bestScore = score
			best = ply
		end
	end
	return best
end

local function findNearbyInjuredFriendly(bot, primaryPatient, inCombat)
	local world = TFBotValveAI and TFBotValveAI.World or nil
	local best
	local bestRatio = 1.0
	local maxRange = cv_max_heal:GetFloat() * 0.9
	for _, ply in ipairs(world and world:GetAlivePlayers() or player.GetAll()) do
		if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then continue end
		if ply == bot or not ply:IsFriendly(bot) then continue end
		if bot:GetPos():Distance(ply:GetPos()) > maxRange then continue end
		local ratio = getHealthRatio(ply, not inCombat)
		local onFire = ply.InCond and ply:InCond(TF_COND_BURNING)
		if onFire then
			ratio = ratio - 0.35
		end
		if isCallingForMedicRecent(ply) then
			ratio = ratio - 0.10
		end
		if ply == primaryPatient then
			ratio = ratio - 0.05
		end
		if ratio < bestRatio then
			bestRatio = ratio
			best = ply
		end
	end
	return best
end

local function getMedicGun(bot)
	if not IsValid(bot) then return nil end
	local direct = bot:GetWeapon("tf_weapon_medigun")
		or bot:GetWeapon("tf_weapon_medigun_merc")
		or bot:GetWeapon("tf_weapon_medigun_qf")
		or bot:GetWeapon("tf_weapon_medigun_vaccinator")
		or bot:GetWeapon("tf_weapon_medigun_machinery")
	if IsValid(direct) then
		return direct
	end

	for _, wep in ipairs(bot:GetWeapons() or {}) do
		if IsValid(wep) and string.find(string.lower(wep:GetClass() or ""), "medigun", 1, true) then
			return wep
		end
	end
	return nil
end

local function isBotInSquad(bot)
	return bot.IsInASquad and bot:IsInASquad() or false
end

function M:Update(bot, state)
	local cls = getClassName(bot)
	if cls ~= "medic" and cls ~= "giantmedic" then return false end

	local patient = findPatient(bot, state.class.patient)
	if not IsValid(patient) then
		state.class.patient = nil
		state.class.healTarget = nil
		state.class.useMedigun = false
		return false
	end

	state.class.patient = patient
	state.class.useMedigun = true
	local medigun = getMedicGun(bot)
	if IsValid(medigun) then
		bot:SelectWeapon(medigun:GetClass())
	end

	local dist = bot:GetPos():Distance(patient:GetPos())
	local threat = state.vision.currentThreat
	state.class.medicInCombat = IsValid(threat)
	local healTarget = patient

	local patientStable = getHealthRatio(patient, false) >= cv_stable_ratio:GetFloat()
	if patientStable and not state.class.medicInCombat and not isBotInSquad(bot) then
		local neighbor = findNearbyInjuredFriendly(bot, patient, state.class.medicInCombat)
		if IsValid(neighbor) then
			healTarget = neighbor
		end
	end

	state.class.healTarget = healTarget

	if state.class.medicInCombat and dist > cv_max_heal:GetFloat() then
		state.objective.mode = "medic_close_gap"
		state.objective.targetPos = patient:GetPos()
		state.objective.targetEnt = patient
		bot.routeType = "default"
		return true
	end
	if dist > cv_follow_start:GetFloat() then
		state.objective.targetPos = patient:GetPos()
		state.objective.targetEnt = patient
		state.objective.mode = "medic_follow"
		bot.routeType = "default"
	elseif dist < cv_follow_stop:GetFloat() then
		state.objective.targetPos = bot:GetPos()
		state.objective.targetEnt = patient
		state.objective.mode = "medic_hold"
	end
	return true
end

return M

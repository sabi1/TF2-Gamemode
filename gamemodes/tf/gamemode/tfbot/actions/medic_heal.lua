TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.MedicHeal = TFBotSource.Actions.MedicHeal or {}

local M = TFBotSource.Actions.MedicHeal

local cv_medic_stop_follow = CreateConVar("tf_bot_source_medic_stop_follow_range", "75", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Medic stop-follow range based on TF2 TFBot medic logic.")
local cv_medic_start_follow = CreateConVar("tf_bot_source_medic_start_follow_range", "250", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Medic start-follow range based on TF2 TFBot medic logic.")
local cv_medic_patient_nearby = CreateConVar("tf_bot_source_medic_patient_nearby_range", "750", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Nearby threshold for keeping the current patient.")

local preferredOrder = {
	heavy = 0,
	soldier = 0,
	pyro = 0,
	demoman = 3,
}

local function get_team_members(teamNum)
	local merged = {}
	local seen = {}

	for _, ent in ipairs(player.GetAll()) do
		if IsValid(ent) and ent:Team() == teamNum then
			merged[#merged + 1] = ent
			seen[ent] = true
		end
	end

	for _, ent in ipairs(ents.FindByClass("tf_bot_base_nextbot")) do
		if IsValid(ent) and ent.TFBot == true and ent:Team() == teamNum and not seen[ent] then
			merged[#merged + 1] = ent
			seen[ent] = true
		end
	end

	return merged
end

local function world_center(ent)
	if not IsValid(ent) then return nil end
	if ent.WorldSpaceCenter then
		local ok, pos = pcall(ent.WorldSpaceCenter, ent)
		if ok and isvector(pos) then
			return pos
		end
	end
	return ent.GetPos and ent:GetPos() or nil
end

local function get_class_rank(ent)
	local cls = string.lower(tostring((ent.GetPlayerClass and ent:GetPlayerClass()) or ent.playerclass or ""))
	return preferredOrder[cls] or 999
end

function M:SelectPatient(bot, st)
	st.sourceMedic = st.sourceMedic or {}
	local medic = st.sourceMedic
	local current = IsValid(medic.patient) and medic.patient or nil
	local selected = current

	for _, ply in ipairs(get_team_members(bot:Team())) do
		if not IsValid(ply) or ply == bot then continue end
		if not (ply.Alive and ply:Alive()) then continue end

		local maxHp = tonumber(ply.GetMaxHealth and ply:GetMaxHealth() or ply:Health() or 0) or 0
		local hp = tonumber(ply:Health() or 0) or 0
		if maxHp <= 0 then continue end

		local rank = get_class_rank(ply)
		local currentRank = IsValid(selected) and get_class_rank(selected) or 999
		local dist = bot:GetPos():Distance(ply:GetPos())
		local currentDist = IsValid(selected) and bot:GetPos():Distance(selected:GetPos()) or 99999

		if ply.HasTheFlag and ply:HasTheFlag() then
			selected = ply
		elseif not IsValid(selected) then
			selected = ply
		elseif rank < currentRank and dist < cv_medic_patient_nearby:GetFloat() then
			selected = ply
		elseif rank == currentRank and hp < (selected:Health() or maxHp) and dist <= (currentDist + 300) then
			selected = ply
		end
	end

	medic.patient = selected
	return selected
end

function M:Update(bot, st)
	if not (IsValid(bot) and st) then return false end
	local patient = self:SelectPatient(bot, st)
	if not IsValid(patient) then return false end

	local dist2 = bot:GetPos():DistToSqr(patient:GetPos())
	if dist2 > (cv_medic_stop_follow:GetFloat() * cv_medic_stop_follow:GetFloat()) then
		TFBotSource.Core:SetActionTarget(bot, st, "medic_heal", patient, world_center(patient))
	else
		TFBotSource.Core:SetActionTarget(bot, st, "medic_hold", patient, bot:GetPos())
	end

	if st.vision and IsValid(st.vision.currentThreat) and dist2 <= (cv_medic_start_follow:GetFloat() * cv_medic_start_follow:GetFloat()) then
		st.vision.currentThreat = nil
	end
	return true
end

function M:ApplyPlayerCommand(bot, cmd, st)
	if not (IsValid(bot) and cmd and st) then return end
	local target = st.objective and st.objective.targetEnt or nil
	if not IsValid(target) then return end

	local ang = (target:GetShootPos() - bot:GetShootPos()):Angle()
	cmd:SetViewAngles(ang)
	bot:SetEyeAngles(ang)

	local weapon = bot.GetWeapon and bot:GetWeapon("tf_weapon_medigun") or nil
	if IsValid(weapon) and bot:GetActiveWeapon() ~= weapon then
		bot:SelectWeapon("tf_weapon_medigun")
	end
end

return M


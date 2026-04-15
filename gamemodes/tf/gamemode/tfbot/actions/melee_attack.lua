TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.MeleeAttack = TFBotSource.Actions.MeleeAttack or {}

local M = TFBotSource.Actions.MeleeAttack

local cv_abandon = CreateConVar("tf_bot_source_melee_attack_abandon_range", "500", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "If a melee target is farther away than this, stop forcing melee.")

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

function M:Update(bot, st)
	if not (IsValid(bot) and st) then return false end
	local threat = (st.vision and st.vision.currentThreat) or (st.objective and st.objective.targetEnt) or nil
	if not IsValid(threat) then return false end
	local pos = world_center(threat)
	if not isvector(pos) then return false end
	if bot:GetPos():DistToSqr(pos) > (cv_abandon:GetFloat() * cv_abandon:GetFloat()) then
		return false
	end
	TFBotSource.Core:SetActionTarget(bot, st, "melee_attack", threat, pos)
	return true
end

return M

TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.SpyAttack = TFBotSource.Actions.SpyAttack or {}

local M = TFBotSource.Actions.SpyAttack

local cv_knife_range = CreateConVar("tf_bot_source_spy_knife_range", "300", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "If the spy target is closer than this, prefer knife/backstab behavior.")
local cv_change_target_range = CreateConVar("tf_bot_source_spy_change_target_range_threshold", "300", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Switch to a closer spy target if it is meaningfully nearer.")

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

local function get_closest_enemy(bot, current)
	local best = current
	local bestDist = IsValid(current) and bot:GetPos():DistToSqr(current:GetPos()) or nil

	for _, enemy in ipairs(player.GetAll()) do
		if not IsValid(enemy) or enemy == bot or not enemy:Alive() or enemy:Team() == bot:Team() then continue end
		local d2 = bot:GetPos():DistToSqr(enemy:GetPos())
		if not bestDist or d2 < bestDist then
			best = enemy
			bestDist = d2
		end
	end

	for _, enemy in ipairs(ents.FindByClass("tf_bot_base_nextbot")) do
		if not IsValid(enemy) or enemy == bot or enemy.TFBot ~= true or not enemy:Alive() or enemy:Team() == bot:Team() then continue end
		local d2 = bot:GetPos():DistToSqr(enemy:GetPos())
		if not bestDist or d2 < bestDist then
			best = enemy
			bestDist = d2
		end
	end

	return best, bestDist
end

function M:Update(bot, st, target)
	if not (IsValid(bot) and st) then return false end
	st.sourceSpyAttack = st.sourceSpyAttack or {}
	local mem = st.sourceSpyAttack

	local victim = IsValid(target) and target or (st.objective and st.objective.targetEnt) or (st.vision and st.vision.currentThreat) or mem.victim
	local closest, closestDist = get_closest_enemy(bot, victim)
	if IsValid(victim) and IsValid(closest) and closest ~= victim then
		local currentDist = bot:GetPos():DistToSqr(victim:GetPos())
		if (currentDist - closestDist) > (cv_change_target_range:GetFloat() * cv_change_target_range:GetFloat()) then
			victim = closest
		end
	elseif IsValid(closest) then
		victim = closest
	end

	if not IsValid(victim) then
		return false
	end

	mem.victim = victim
	local victimPos = world_center(victim)
	if not isvector(victimPos) then
		return false
	end

	local mode = "spy_attack_pistol"
	if bot:GetPos():DistToSqr(victimPos) <= (cv_knife_range:GetFloat() * cv_knife_range:GetFloat()) then
		mode = "spy_attack_knife"
	end

	TFBotSource.Core:SetActionTarget(bot, st, mode, victim, victimPos)
	return true
end

return M

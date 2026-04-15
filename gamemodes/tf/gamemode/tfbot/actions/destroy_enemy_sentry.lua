TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.DestroyEnemySentry = TFBotSource.Actions.DestroyEnemySentry or {}

local M = TFBotSource.Actions.DestroyEnemySentry

local cv_range = CreateConVar("tf_bot_source_destroy_sentry_range", "1800", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max range to select or continue destroying an enemy sentry.")

local DISALLOWED_CLASSES = {
	heavy = true,
	sniper = true,
	medic = true,
	engineer = true,
	pyro = true,
	spy = true,
}

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

local function is_enemy_sentry(bot, ent)
	if not (IsValid(bot) and IsValid(ent)) then return false end
	if string.lower(tostring(ent.GetClass and ent:GetClass() or "")) ~= "obj_sentrygun" then
		return false
	end
	if ent.Health and ent:Health() <= 0 then
		return false
	end
	if ent.Team and ent:Team() == bot:Team() then
		return false
	end
	return true
end

local function can_destroy_sentry(bot)
	if not IsValid(bot) then return false end
	local cls = string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
	return DISALLOWED_CLASSES[cls] ~= true
end

function M:IsPossible(bot, sentry)
	if not can_destroy_sentry(bot) then return false end
	if IsValid(sentry) then
		return is_enemy_sentry(bot, sentry)
	end
	for _, ent in ipairs(ents.FindByClass("obj_sentrygun")) do
		if is_enemy_sentry(bot, ent) and bot:GetPos():DistToSqr(ent:GetPos()) <= (cv_range:GetFloat() * cv_range:GetFloat()) then
			return true
		end
	end
	return false
end

function M:FindTarget(bot, st)
	local threat = st and st.vision and st.vision.currentThreat or nil
	if is_enemy_sentry(bot, threat) then
		return threat
	end

	local best, bestDist
	for _, ent in ipairs(ents.FindByClass("obj_sentrygun")) do
		if not is_enemy_sentry(bot, ent) then continue end
		local d2 = bot:GetPos():DistToSqr(ent:GetPos())
		if d2 > (cv_range:GetFloat() * cv_range:GetFloat()) then continue end
		if not bestDist or d2 < bestDist then
			best = ent
			bestDist = d2
		end
	end
	return best
end

function M:Update(bot, st)
	if not (IsValid(bot) and st) then return false end
	if not can_destroy_sentry(bot) then return false end
	local sentry = self:FindTarget(bot, st)
	if not is_enemy_sentry(bot, sentry) then return false end
	local pos = world_center(sentry)
	if not isvector(pos) then return false end
	TFBotSource.Core:SetActionTarget(bot, st, "destroy_enemy_sentry", sentry, pos)
	return true
end

return M

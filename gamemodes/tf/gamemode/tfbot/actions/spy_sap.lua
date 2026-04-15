TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.SpySap = TFBotSource.Actions.SpySap or {}

local M = TFBotSource.Actions.SpySap

local cv_sap_range = CreateConVar("tf_bot_source_spy_sap_range", "40", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Distance where spy sap counts as in range.")

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

local function is_sappable_object(ent, bot)
	if not IsValid(ent) or not IsValid(bot) then return false end
	local cls = string.lower(tostring(ent.GetClass and ent:GetClass() or ""))
	return string.StartWith(cls, "obj_") and ent:Team() ~= bot:Team()
end

local function get_nearest_sappable(bot)
	local best, bestDist
	for _, ent in ipairs(ents.GetAll()) do
		if not is_sappable_object(ent, bot) then continue end
		local pos = ent:GetPos()
		local d2 = bot:GetPos():DistToSqr(pos)
		if not bestDist or d2 < bestDist then
			best = ent
			bestDist = d2
		end
	end
	return best
end

function M:Update(bot, st, sapTarget)
	if not (IsValid(bot) and st) then return false end
	local target = IsValid(sapTarget) and sapTarget or (st.objective and st.objective.targetEnt) or get_nearest_sappable(bot)
	if not is_sappable_object(target, bot) then
		return false
	end

	local pos = world_center(target)
	if not isvector(pos) then
		return false
	end

	local mode = "spy_sap_move"
	if bot:GetPos():DistToSqr(pos) <= ((cv_sap_range:GetFloat() * 2) ^ 2) then
		mode = "spy_sap"
	end

	TFBotSource.Core:SetActionTarget(bot, st, mode, target, pos)
	return true
end

return M

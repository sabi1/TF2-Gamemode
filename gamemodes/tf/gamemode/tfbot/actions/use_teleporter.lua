TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.UseTeleporter = TFBotSource.Actions.UseTeleporter or {}

local M = TFBotSource.Actions.UseTeleporter

local cv_use_range = CreateConVar("tf_bot_source_use_teleporter_range", "72", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How close a source-shaped TFBot must stand to use a teleporter.")

local function get_pos(ent)
	if not IsValid(ent) then return nil end
	return ent.GetPos and ent:GetPos() or nil
end

local function is_valid_teleporter(bot, tele)
	if not (IsValid(bot) and IsValid(tele)) then return false end
	if string.lower(tostring(tele.GetClass and tele:GetClass() or "")) ~= "obj_teleporter" then
		return false
	end
	if tele.Team and tele:Team() ~= bot:Team() then
		return false
	end
	if tele.IsEntrance and not tele:IsEntrance() and not tele.TF_MVM_BidirectionalTeleport then
		return false
	end
	if tele.IsReady and not tele:IsReady() then
		return false
	end
	local linked = tele.GetLinkedTeleporter and tele:GetLinkedTeleporter() or nil
	return IsValid(linked)
end

function M:IsPossible(bot, st)
	if not (IsValid(bot) and st and st.objective) then return false end
	local tele = st.objective.targetEnt
	return is_valid_teleporter(bot, tele)
end

function M:Update(bot, st)
	if not (IsValid(bot) and st and st.objective) then return false end
	st.sourceTeleporter = st.sourceTeleporter or {}
	local mem = st.sourceTeleporter
	local tele = st.objective.targetEnt
	if not is_valid_teleporter(bot, tele) then
		mem.useAt = 0
		return false
	end

	local linked = tele.GetLinkedTeleporter and tele:GetLinkedTeleporter() or nil
	local telePos = get_pos(tele)
	local exitPos = get_pos(linked)
	if not isvector(telePos) then return false end

	if IsValid(linked) and isvector(exitPos) and bot:GetPos():DistToSqr(exitPos) <= (96 * 96) then
		mem.useAt = 0
		TFBotSource.Core:SetActionTarget(bot, st, "use_teleporter_exit", linked, exitPos)
		return true
	end

	if bot:GetPos():DistToSqr(telePos) <= (cv_use_range:GetFloat() * cv_use_range:GetFloat()) then
		mem.useAt = tonumber(mem.useAt or 0)
		if mem.useAt <= 0 then
			mem.useAt = CurTime() + math.max(0.1, tonumber(tele.TeleportDelay) or 1)
		elseif CurTime() >= mem.useAt then
			mem.useAt = 0
			if tele.Teleport then
				pcall(tele.Teleport, tele, bot)
			end
		end
	else
		mem.useAt = 0
	end

	TFBotSource.Core:SetActionTarget(bot, st, "use_teleporter", tele, telePos)
	return true
end

return M

TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.Attack = TFBotSource.Actions.Attack or {}

local M = TFBotSource.Actions.Attack

local cv_attack_range = CreateConVar("tf_bot_source_attack_range", "1000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Threat range for the source-shaped TFBot attack action.")
local cv_attack_memory = CreateConVar("tf_bot_source_attack_memory", "3.5", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How long to chase the last seen target position before giving up.")

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
	if not (IsValid(bot) and st and st.objective) then return false end
	local threat = st.vision and st.vision.currentThreat or nil
	st.sourceAttack = st.sourceAttack or {}
	local mem = st.sourceAttack

	if IsValid(threat) then
		local pos = world_center(threat)
		if isvector(pos) then
			mem.lastThreat = threat
			mem.lastThreatPos = pos
			mem.lastSeenUntil = CurTime() + math.max(0.2, cv_attack_memory:GetFloat())
			TFBotSource.Core:SetActionTarget(bot, st, "attack", threat, pos)
			return true
		end
	end

	if isvector(mem.lastThreatPos) and CurTime() < tonumber(mem.lastSeenUntil or 0) then
		TFBotSource.Core:SetActionTarget(bot, st, "attack_last_known", mem.lastThreat, mem.lastThreatPos)
		return true
	end

	return false
end

return M


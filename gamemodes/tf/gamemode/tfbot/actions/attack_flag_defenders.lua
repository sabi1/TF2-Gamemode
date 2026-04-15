TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.AttackFlagDefenders = TFBotSource.Actions.AttackFlagDefenders or {}

local M = TFBotSource.Actions.AttackFlagDefenders

local cv_watch_interval = CreateConVar("tf_bot_source_flag_defender_watch_interval", "1.5", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How often flag-defender bots reevaluate between escorting and chasing.")
local cv_chase_range = CreateConVar("tf_bot_source_flag_defender_chase_range", "1800", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Range around the bomb carrier where defender pressure should stay focused.")

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

local function get_flag()
	for _, cls in ipairs({"item_teamflag_mvm", "item_teamflag"}) do
		for _, ent in ipairs(ents.FindByClass(cls)) do
			if IsValid(ent) then
				return ent
			end
		end
	end
	return nil
end

local function get_enemy_candidates(bot)
	local out = {}
	local seen = {}
	local myTeam = bot:Team()

	for _, ent in ipairs(player.GetAll()) do
		if IsValid(ent) and ent:Alive() and ent:Team() ~= myTeam then
			out[#out + 1] = ent
			seen[ent] = true
		end
	end

	for _, ent in ipairs(ents.FindByClass("tf_bot_base_nextbot")) do
		if IsValid(ent) and ent.TFBot == true and ent:Alive() and ent:Team() ~= myTeam and not seen[ent] then
			out[#out + 1] = ent
		end
	end

	return out
end

function M:SelectChaseTarget(bot, anchor)
	if not IsValid(anchor) then return nil end
	local best, bestDist
	local maxDist2 = cv_chase_range:GetFloat() * cv_chase_range:GetFloat()
	local anchorPos = anchor:GetPos()

	for _, enemy in ipairs(get_enemy_candidates(bot)) do
		local enemyPos = enemy:GetPos()
		local dist2 = anchorPos:DistToSqr(enemyPos)
		if dist2 <= maxDist2 and (not bestDist or dist2 < bestDist) then
			best = enemy
			bestDist = dist2
		end
	end

	return best
end

function M:Update(bot, st)
	if not (IsValid(bot) and st) then return false end

	local threat = st.vision and st.vision.currentThreat or nil
	if IsValid(threat) then
		return TFBotSource.Actions.Attack:Update(bot, st)
	end

	st.sourceFlagDefenders = st.sourceFlagDefenders or {}
	local mem = st.sourceFlagDefenders
	local flag = get_flag()
	if not IsValid(flag) then
		return TFBotSource.Actions.SeekAndDestroy:Update(bot, st)
	end

	local carrier = (flag.GetOwnerEntity and flag:GetOwnerEntity()) or (flag.GetOwner and flag:GetOwner()) or nil
	if not IsValid(carrier) or carrier == bot then
		return TFBotSource.Actions.FetchFlag:Update(bot, st)
	end

	if CurTime() >= tonumber(mem.nextWatchAt or 0) then
		mem.nextWatchAt = CurTime() + math.max(0.5, cv_watch_interval:GetFloat())
		mem.chaseTarget = self:SelectChaseTarget(bot, carrier)
	end

	if IsValid(mem.chaseTarget) then
		TFBotSource.Core:SetActionTarget(bot, st, "attack_flag_defenders", mem.chaseTarget, world_center(mem.chaseTarget))
		return true
	end

	return TFBotSource.Actions.EscortFlagCarrier:Update(bot, st)
end

return M

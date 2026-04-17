TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.AttackFlagDefenders = TFBotSource.Actions.AttackFlagDefenders or {}

local M = TFBotSource.Actions.AttackFlagDefenders

local cv_watch_interval = CreateConVar("tf_bot_source_flag_defender_watch_interval", "1.5", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How often flag-defender bots reevaluate between escorting and chasing.")
local cv_chase_range = CreateConVar("tf_bot_source_flag_defender_chase_range", "1800", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Range around the bomb carrier where defender pressure should stay focused.")
local cv_min_duration = CreateConVar("tf_bot_source_flag_defender_min_duration", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Optional minimum time to keep attacking defenders before switching back to escort.")

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

local function is_mvm_mode()
	return GAMEMODE and GAMEMODE.IsMannVsMachineMode and GAMEMODE:IsMannVsMachineMode()
end

local function get_flag_team(flag)
	if not IsValid(flag) then return TEAM_UNASSIGNED or 0 end
	if flag.GetNWInt then
		local teamNum = tonumber(flag:GetNWInt("FlagTeamNum", -1) or -1) or -1
		if teamNum >= 0 then
			return teamNum
		end
	end
	if flag.TeamNum ~= nil then
		return tonumber(flag.TeamNum) or TEAM_UNASSIGNED or 0
	end
	if flag.GetTeamNumber then
		local ok, teamNum = pcall(flag.GetTeamNumber, flag)
		if ok then
			return tonumber(teamNum) or TEAM_UNASSIGNED or 0
		end
	end
	return TEAM_UNASSIGNED or 0
end

local function get_flag(bot)
	if is_mvm_mode() then
		for _, ent in ipairs(ents.FindByClass("item_teamflag_mvm")) do
			if IsValid(ent) then
				return ent
			end
		end
		return nil
	end

	if not IsValid(bot) then return nil end
	for _, ent in ipairs(ents.FindByClass("item_teamflag")) do
		if IsValid(ent) and get_flag_team(ent) ~= bot:Team() then
			return ent
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

local function in_spawn_area_for_team(pos, team)
	if not navmesh or not navmesh.GetNearestNavArea or not isvector(pos) then return false end
	local area = navmesh.GetNearestNavArea(pos, true, 10000, true, true, team)
	if not IsValid(area) then
		area = navmesh.GetNearestNavArea(pos, true, 10000, true, true)
	end
	if not IsValid(area) or not area.HasTFAttribute then return false end
	if team == TEAM_BLU or team == TF_TEAM_PVE_INVADERS then
		return area:HasTFAttribute("spawn_room_blue") == true
	end
	if team == TEAM_RED then
		return area:HasTFAttribute("spawn_room_red") == true
	end
	return false
end

local function select_random_reachable_enemy(bot)
	local candidates = {}
	for _, enemy in ipairs(get_enemy_candidates(bot)) do
		if in_spawn_area_for_team(enemy:GetPos(), enemy:Team()) then continue end
		candidates[#candidates + 1] = enemy
	end
	if #candidates <= 0 then return nil end
	return table.Random(candidates)
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
	st.sourceFlagDefenders = st.sourceFlagDefenders or {}
	local mem = st.sourceFlagDefenders
	mem.startedAt = tonumber(mem.startedAt or 0)
	if mem.startedAt <= 0 then
		mem.startedAt = CurTime()
	end

	local threat = st.vision and st.vision.currentThreat or nil
	if IsValid(threat) then
		return TFBotSource.Actions.Attack:Update(bot, st)
	end

	local flag = get_flag(bot)
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

	if CurTime() >= (mem.nextRandomVictimAt or 0) then
		mem.nextRandomVictimAt = CurTime() + math.Rand(1.0, 3.0)
		mem.randomVictim = select_random_reachable_enemy(bot)
	end

	if IsValid(mem.randomVictim) and mem.randomVictim:Alive() then
		TFBotSource.Core:SetActionTarget(bot, st, "attack_flag_defenders_chase", mem.randomVictim, world_center(mem.randomVictim))
		return true
	end

	if tonumber(cv_min_duration:GetFloat() or 0) > 0 and (CurTime() - mem.startedAt) < cv_min_duration:GetFloat() then
		return TFBotSource.Actions.SeekAndDestroy:Update(bot, st)
	end

	return TFBotSource.Actions.EscortFlagCarrier:Update(bot, st)
end

return M

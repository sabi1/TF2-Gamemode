TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.Threat = TFBotValveAI.Threat or {}

local M = TFBotValveAI.Threat

local cv_unreach_z = CreateConVar("tf_bot_unreachable_target_z_diff", "240", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_unreach_xy = CreateConVar("tf_bot_unreachable_target_xy", "700", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_unreach_persist = CreateConVar("tf_bot_unreachable_target_persist", "1.0", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_red_respect_blu_spawn = CreateConVar("tf_bot_red_respect_blu_spawn", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "RED bots ignore BLU targets in BLU spawn areas.")
local cv_allow_carrier_fight = CreateConVar("tf_mvm_bot_allow_flag_carrier_to_fight", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY})

local function className(ply)
	return string.lower(tostring((ply.GetPlayerClass and ply:GetPlayerClass()) or ply.playerclass or ""))
end

local function dist2D(a, b)
	local dx = a.x - b.x
	local dy = a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
end

local function isUnreachableTarget(bot, target)
	if not IsValid(bot) or not IsValid(target) then return false end
	if target.IsPlayer and target:IsPlayer() and target.GetMoveType and target:GetMoveType() == MOVETYPE_NOCLIP then
		return true
	end
	local bp = bot:GetPos()
	local tp = target:GetPos()
	local zd = math.abs(tp.z - bp.z)
	if zd < cv_unreach_z:GetFloat() then
		return false
	end
	if dist2D(bp, tp) > cv_unreach_xy:GetFloat() then
		return false
	end
	if target.IsPlayer and target:IsPlayer() and target.OnGround and not target:OnGround() then
		return true
	end
	return false
end

local function inSpawnAreaForTeam(pos, team)
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

local function shouldIgnoreProtectedSpawnTarget(bot, target)
	if not cv_red_respect_blu_spawn:GetBool() then return false end
	if not IsValid(bot) or not IsValid(target) then return false end
	if bot:Team() ~= TEAM_RED then return false end
	if not (target:IsPlayer() and (target:Team() == TEAM_BLU or target:Team() == TF_TEAM_PVE_INVADERS)) then
		return false
	end
	return inSpawnAreaForTeam(target:GetPos(), target:Team())
end

function M:Score(bot, target)
	if not IsValid(bot) or not IsValid(target) then
		return -math.huge
	end
	local dist = bot:GetPos():Distance(target:GetPos())
	local score = 0
	local visible = bot:Visible(target)

	if target.GetClass and target:GetClass() == "obj_sentrygun" and dist <= 1100 then
		score = score + 5000
	end
	if visible then score = score + 1000 end
	if dist <= 500 then score = score + 1500 end
	score = score - dist

	if target.IsPlayer and target:IsPlayer() then
		local pclass = className(target)
		if pclass == "medic" and dist <= 1800 then
			score = score + 450
		elseif pclass == "sniper" and dist <= 3000 and visible then
			score = score + 600
		elseif pclass == "spy" and dist <= 1000 and (bot.IsMVMRobot or bot:Team() == TEAM_BLU) then
			score = score + 800
		end
	end

	return score
end

function M:SelectTarget(bot, state)
	if not IsValid(bot) or not state then return nil end
	if bot.TF_MVM_IgnoreEnemies then
		state.vision.currentThreat = nil
		return nil
	end
	local mvm = TFBotValveAI.MvM
	if mvm and mvm:IsCombatSuppressed(state) then
		local mvmState = state.mvm or {}
		local mode = tostring(mvmState.mode or "")
		local carrierCanFight = mvmState.isCarrier == true
			and mode == "mvm_deliver_bomb"
			and cv_allow_carrier_fight:GetBool()
		if carrierCanFight then
			-- Allow bomb-carrier threat acquisition while delivering the bomb.
		else
		state.vision.currentThreat = nil
		return nil
		end
	end
	local now = CurTime()
	state.vision.unreachableUntil = state.vision.unreachableUntil or {}

	if IsValid(state.vision.currentThreat) then
		if isUnreachableTarget(bot, state.vision.currentThreat) or shouldIgnoreProtectedSpawnTarget(bot, state.vision.currentThreat) then
			local id = state.vision.currentThreat:EntIndex()
			local untilAt = tonumber(state.vision.unreachableUntil[id] or 0)
			untilAt = math.max(untilAt, now + cv_unreach_persist:GetFloat())
			state.vision.unreachableUntil[id] = untilAt
			state.vision.currentThreat = nil
		end
	end

	if now < (state.vision.nextTargetScan or 0) and IsValid(state.vision.currentThreat) then
		return state.vision.currentThreat
	end

	local vision = TFBotValveAI.Vision
	state.vision.nextTargetScan = now + vision:GetChooseInterval(bot)

	local best
	local bestScore = -math.huge
	for _, ply in ipairs(player.GetAll()) do
		local id = ply:EntIndex()
		if now < tonumber(state.vision.unreachableUntil[id] or 0) then
			continue
		end
		if shouldIgnoreProtectedSpawnTarget(bot, ply) then
			continue
		end
		if isUnreachableTarget(bot, ply) then
			state.vision.unreachableUntil[id] = now + cv_unreach_persist:GetFloat()
			continue
		end
		if vision:CanTrack(bot, state, ply, now) then
			local score = self:Score(bot, ply)
			if score > bestScore then
				bestScore = score
				best = ply
			end
		end
	end

	for _, ent in ipairs(ents.FindByClass("obj_sentrygun")) do
		if vision:CanTrack(bot, state, ent, now) then
			local score = self:Score(bot, ent)
			if score > bestScore then
				bestScore = score
				best = ent
			end
		end
	end

	state.vision.currentThreat = best
	return best
end

return M

TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.MvM = TFBotValveAI.MvM or {}

local M = TFBotValveAI.MvM

local cv_allow_carrier_fight = CreateConVar("tf_mvm_bot_allow_flag_carrier_to_fight", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_escort_range = CreateConVar("tf_bot_flag_escort_range", "500", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_escort_giveup = CreateConVar("tf_bot_flag_escort_give_up_range", "1000", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_escort_max = CreateConVar("tf_bot_flag_escort_max_count", "4", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_mvm_flank_open_time = CreateConVar("tf_bot_mvm_flank_open_time", "18", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_bomb_regen = CreateConVar("tf_mvm_bot_flag_carrier_health_regen", "45", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_sentry_buster_range = CreateConVar("tf_bot_suicide_bomb_range", "300", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_sentry_buster_friendly = CreateConVar("tf_bot_suicide_bomb_friendly_fire", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_deploy_delay = CreateConVar("tf_deploying_bomb_delay_time", "0.7", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_deploy_time = CreateConVar("tf_deploying_bomb_time", "3.0", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local getBombIntel
local DEPLOY_ALERT_COOLDOWN = 5.0
TF_MVM_NextDeployingAlertAt = TF_MVM_NextDeployingAlertAt or 0

local function fmtVec(v)
	if not isvector(v) then return "nil" end
	return string.format("(%.0f %.0f %.0f)", v.x, v.y, v.z)
end

local function isNearOrigin(v)
	if not isvector(v) then return true end
	return math.abs(v.x) <= 1 and math.abs(v.y) <= 1 and math.abs(v.z) <= 1
end

local function getEntGoalPos(ent, fallback)
	if not IsValid(ent) then return fallback end
	local pos = nil
	if ent.WorldSpaceCenter then
		local ok, v = pcall(ent.WorldSpaceCenter, ent)
		if ok and isvector(v) then
			pos = v
		end
	end
	if (not isvector(pos) or isNearOrigin(pos)) and ent.OBBCenter and ent.LocalToWorld then
		local okCenter, center = pcall(ent.OBBCenter, ent)
		if okCenter and isvector(center) then
			local okWorld, world = pcall(ent.LocalToWorld, ent, center)
			if okWorld and isvector(world) then
				pos = world
			end
		end
	end
	if (not isvector(pos) or isNearOrigin(pos)) and ent.GetPos then
		local ok, v = pcall(ent.GetPos, ent)
		if ok and isvector(v) then
			pos = v
		end
	end
	if isvector(pos) and not isNearOrigin(pos) then
		return pos
	end
	return fallback
end

local function isPosInsideZone(zone, pos)
	if not IsValid(zone) or not isvector(pos) then return false end
	if zone.WorldSpaceAABB then
		local mins, maxs = zone:WorldSpaceAABB()
		if isvector(mins) and isvector(maxs) then
			local padXY, padZ = 24, 48
			return pos.x >= (mins.x - padXY) and pos.x <= (maxs.x + padXY)
				and pos.y >= (mins.y - padXY) and pos.y <= (maxs.y + padXY)
				and pos.z >= (mins.z - padZ) and pos.z <= (maxs.z + padZ)
		end
	end
	local center = getEntGoalPos(zone, nil)
	return isvector(center) and pos:DistToSqr(center) <= (170 * 170)
end

local function carrierCanDeployNow(bot, deployZone, deployPos)
	if not IsValid(bot) then return false end
	if IsValid(deployZone) and isPosInsideZone(deployZone, bot:GetPos()) then return true end
	return isvector(deployPos) and bot:GetPos():DistToSqr(deployPos) <= (150 * 150)
end

local function debugLog(bot, key, interval, msg)
	local cfg = TFBotValveAI and TFBotValveAI.Config or nil
	if not (cfg and cfg.IsDebug and cfg:IsDebug()) then return end
	if not IsValid(bot) then return end
	bot._tfbotDbgNext = bot._tfbotDbgNext or {}
	local now = CurTime()
	local nextAt = tonumber(bot._tfbotDbgNext[key] or 0)
	if now < nextAt then return end
	bot._tfbotDbgNext[key] = now + (tonumber(interval) or 0.5)
	cfg:Debug(string.format(
		"bot=%s[%d] %s",
		tostring(bot:Nick()),
		bot:EntIndex(),
		tostring(msg)
	))
end

local function PlayDeployingAlertThrottled()
	local now = CurTime()
	if now < (tonumber(TF_MVM_NextDeployingAlertAt) or 0) then
		return
	end
	TF_MVM_NextDeployingAlertAt = now + DEPLOY_ALERT_COOLDOWN
	for _, pl in ipairs(player.GetAll()) do
		if IsValid(pl) then
			pl:SendLua([[LocalPlayer():EmitSound("Announcer.MVM_Bomb_Alert_Deploying")]])
		end
	end
end

local function playDeployBombAnimation(bot)
	if not IsValid(bot) then return false end
	local played = false

	if bot.DoAnimationEvent and PLAYERANIMEVENT_CUSTOM_GESTURE then
		local ok = pcall(bot.DoAnimationEvent, bot, PLAYERANIMEVENT_CUSTOM_GESTURE, "primary_deploybomb")
		if ok then
			played = true
		end
	end

	if (not played) and bot.AddVCDSequenceToGestureSlot then
		local seq = bot:LookupSequence("primary_deploybomb")
		if seq and seq > 0 then
			bot:AddVCDSequenceToGestureSlot(GESTURE_SLOT_VCD, seq, 0, true)
			played = true
		end
	end

	if (not played) and bot.AnimRestartGesture then
		bot:AnimRestartGesture(GESTURE_SLOT_CUSTOM, ACT_MP_ATTACK_STAND_PRIMARY_DEPLOYED, true)
		played = true
	end

	return played
end

local function completeBombDeploy(bot, deployZone)
	if not IsValid(bot) then return false end
	local intel = getBombIntel()
	if not IsValid(intel) then return false end
	if intel.Carrier ~= bot then return false end

	local effectPos = getEntGoalPos(deployZone, bot:GetPos())
	if not isvector(effectPos) then
		effectPos = bot:GetPos()
	end

	intel.Deploying = true
	if IsValid(deployZone) and deployZone.Capture then
		deployZone:Capture(bot)
	elseif intel.Capture then
		intel:Capture(bot, deployZone)
	end

	ParticleEffect("fluidSmokeExpl_ring_mvm", effectPos + Vector(0, 0, 24), Angle(0, 0, 0))
	ParticleEffect("fireSmoke_Collumn_mvmAcres_sm", effectPos + Vector(0, 0, 24), Angle(0, 0, 0))
	util.ScreenShake(effectPos, 8, 180, 1.0, 1000)

	for _, pl in ipairs(player.GetAll()) do
		if IsValid(pl) and pl:Team() == TEAM_RED then
			pl:SendLua([[LocalPlayer():EmitSound("Announcer.MVM_Wave_Lose")]])
		end
	end

	if bot:Alive() then
		bot:Kill()
	end
	hook.Run("TF_MVM_BombDeployed", bot, deployZone, intel)
	local rt = TF_MVM and TF_MVM.Runtime or nil
	if rt and rt.IsManagedActive and rt:IsManagedActive() and rt.FailMission then
		rt:FailMission("bomb_deployed")
	else
		RunConsoleCommand("tf_mvm_wins")
	end
	intel.Deploying = false
	return true
end

local function isMvMMap()
	return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

local function isInvader(bot)
	return bot:Team() == TEAM_BLU or bot:Team() == TF_TEAM_PVE_INVADERS or bot.IsMVMRobot == true
end

getBombIntel = function()
	for _, intel in ipairs(ents.FindByClass("item_teamflag_mvm")) do
		if IsValid(intel) then
			return intel
		end
	end
	return nil
end

local function isRedCaptureZone(zone)
	if not IsValid(zone) then return false end
	local t = tonumber(zone.TeamNum or zone.Team or 0)
	if t == TEAM_RED or t == 2 then return true end
	if zone.GetKeyValues then
		local kv = zone:GetKeyValues() or {}
		local raw = tonumber(kv.TeamNum or kv.teamnum or kv.Team or 0) or 0
		if raw == 2 or raw == TEAM_RED then
			return true
		end
	end
	return false
end

local function getDeployZone(bot)
	local intel = getBombIntel()
	if IsValid(intel) then
		local linked = nil
		if intel.GetCaptureZone then
			linked = intel:GetCaptureZone()
		elseif intel.CaptureZone then
			linked = intel.CaptureZone
		end
		if IsValid(linked) and isRedCaptureZone(linked) then
			return linked
		end
	end
	local anchor = nil
	if IsValid(intel) then
		anchor = intel.HomePosition or intel:GetPos()
	end
	if not isvector(anchor) and IsValid(bot) then
		anchor = bot:GetPos()
	end
	local best, bestDist
	for _, zone in ipairs(ents.FindByClass("func_capturezone")) do
		if not IsValid(zone) then continue end
		if not isRedCaptureZone(zone) then continue end
		if not isvector(anchor) then
			return zone
		end
		local zonePos = getEntGoalPos(zone, nil)
		if not isvector(zonePos) then continue end
		local d = zonePos:DistToSqr(anchor)
		if not bestDist or d < bestDist then
			bestDist = d
			best = zone
		end
	end
	if IsValid(best) then return best end
	for _, zone in ipairs(ents.FindByClass("func_capturezone")) do
		if IsValid(zone) then
			return zone
		end
	end
	return nil
end

local function hasAreaTFAttribute(area, attrName)
	if not IsValid(area) or not isstring(attrName) or attrName == "" then return false end
	if not area.HasTFAttribute then return false end
	return area:HasTFAttribute(attrName) == true
end

local function getFriendlySpawnAttributeForBot(bot)
	if not IsValid(bot) then return nil end
	if bot:Team() == TEAM_RED then return "spawn_room_red" end
	if bot:Team() == TEAM_BLU or bot:Team() == TF_TEAM_PVE_INVADERS then return "spawn_room_blue" end
	return nil
end

local function isInsideFriendlySpawnArea(bot)
	if not IsValid(bot) or not navmesh or not navmesh.GetNearestNavArea then return false end
	local attr = getFriendlySpawnAttributeForBot(bot)
	if not attr then return false end
	local area = navmesh.GetNearestNavArea(bot:GetPos(), true, 10000, true, true, bot:Team())
	if not IsValid(area) then
		area = navmesh.GetNearestNavArea(bot:GetPos(), true, 10000, true, true)
	end
	return hasAreaTFAttribute(area, attr)
end

local function getSpawnExitTargetPos(bot)
	if not IsValid(bot) or not navmesh or not navmesh.GetAllNavAreas then return nil end
	local spawnAttr = getFriendlySpawnAttributeForBot(bot)
	if not spawnAttr then return nil end
	local now = CurTime()
	if bot._mvmSpawnExitPos and bot._mvmSpawnExitUntil and bot._mvmSpawnExitUntil > now then
		return bot._mvmSpawnExitPos
	end

	local origin = bot:GetPos()
	local bestPos, bestDist
	for _, area in ipairs(navmesh.GetAllNavAreas()) do
		if not IsValid(area) then continue end
		if hasAreaTFAttribute(area, spawnAttr) then continue end
		local center = area:GetCenter()
		if math.abs(center.z - origin.z) > 700 then continue end
		local d = origin:DistToSqr(center)
		if not bestDist or d < bestDist then
			bestDist = d
			bestPos = center
		end
	end
	bot._mvmSpawnExitPos = bestPos
	bot._mvmSpawnExitUntil = now + 0.9
	return bestPos
end

local function isBombAtHome(intel)
	if not IsValid(intel) then return false end
	if isfunction(intel.IsHome) then
		return intel:IsHome() == true
	end
	return tonumber(intel.State or -1) == 0
end

local function getEscortOffsetPos(bot, basePos)
	if not IsValid(bot) or not isvector(basePos) then return basePos end
	local t = bot:EntIndex() * 0.87
	local radius = 90 + ((bot:EntIndex() % 3) * 24)
	local yaw = math.rad((t * 57) % 360)
	return basePos + Vector(math.cos(yaw) * radius, math.sin(yaw) * radius, 0)
end

local function getEscortFollowPos(bot, carrier, deployPos)
	if not IsValid(bot) or not IsValid(carrier) then return nil end
	local cpos = carrier:GetPos()
	local dpos = isvector(deployPos) and deployPos or (cpos + carrier:GetForward() * 256)
	local dir = dpos - cpos
	dir.z = 0
	if dir:LengthSqr() < 1 then
		dir = carrier:GetForward()
		dir.z = 0
	end
	if dir:LengthSqr() < 1 then
		dir = Vector(1, 0, 0)
	end
	dir:Normalize()
	local right = Vector(-dir.y, dir.x, 0)
	local side = (bot:EntIndex() % 2 == 0) and 1 or -1
	local back = 150 + ((bot:EntIndex() % 3) * 34)
	local lateral = 90 + ((bot:EntIndex() % 4) * 20)
	return cpos - (dir * back) + (right * lateral * side)
end

local function getCarrierLaneClearPos(bot, carrier, deployPos)
	if not IsValid(bot) or not IsValid(carrier) then return nil end
	local cpos = carrier:GetPos()
	local dpos = isvector(deployPos) and deployPos or (cpos + carrier:GetForward() * 256)
	local dir = dpos - cpos
	dir.z = 0
	if dir:LengthSqr() < 1 then
		dir = carrier:GetForward()
		dir.z = 0
	end
	if dir:LengthSqr() < 1 then
		dir = Vector(1, 0, 0)
	end
	dir:Normalize()
	local right = Vector(-dir.y, dir.x, 0)
	local side = (bot:EntIndex() % 2 == 0) and 1 or -1
	local back = 110 + ((bot:EntIndex() % 3) * 22)
	local lateral = 130 + ((bot:EntIndex() % 4) * 18)
	return cpos - (dir * back) + (right * lateral * side)
end

local function pickCarrierBypassPos(bot, deployPos)
	if not IsValid(bot) or not isvector(deployPos) or not navmesh or not navmesh.GetAllNavAreas then return nil end
	local origin = bot:GetPos()
	local currentDist = origin:DistToSqr(deployPos)
	local spawnAttr = getFriendlySpawnAttributeForBot(bot)
	local bestPos, bestScore
	for _, area in ipairs(navmesh.GetAllNavAreas()) do
		if not IsValid(area) then continue end
		if spawnAttr and hasAreaTFAttribute(area, spawnAttr) then continue end
		local center = area:GetCenter()
		local dz = math.abs(center.z - origin.z)
		if dz > 700 then continue end
		local originDist = origin:DistToSqr(center)
		if originDist < (170 * 170) or originDist > (1800 * 1800) then continue end
		local deployDist = center:DistToSqr(deployPos)
		if deployDist >= (currentDist - (160 * 160)) then continue end
		local score = (originDist * 0.90) + (deployDist * 0.35)
		if not bestScore or score < bestScore then
			bestScore = score
			bestPos = center
		end
	end
	return bestPos
end

local normalizeObjective

local function isSentryBuster(bot)
	local className = string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
	if className == "sentrybuster" or className == "tf_bot_sentry_buster" then
		return true
	end
	local objective = normalizeObjective(IsValid(bot) and bot.TF_MVM_Objective or "")
	return objective == "destroysentries" or objective == "missiondestroysentries" or objective == "sentrybuster"
end

local function selectSentryBusterTarget(bot)
	local best, bestScore
	for _, ent in ipairs(ents.FindByClass("obj_sentrygun")) do
		if not IsValid(ent) or ent:IsFriendly(bot) then continue end
		local dist = bot:GetPos():DistToSqr(ent:GetPos())
		local score = -dist + ((ent.GetLevel and ent:GetLevel() or 1) * 5000)
		if not bestScore or score > bestScore then
			bestScore = score
			best = ent
		end
	end
	if IsValid(best) then return best end
	for _, ent in ipairs(ents.FindByClass("obj_dispenser")) do
		if IsValid(ent) and not ent:IsFriendly(bot) then
			return ent
		end
	end
	return nil
end

local function countEscorts(team)
	local n = 0
	local bots = player.GetBots()
	local base = TFBotValveAI and TFBotValveAI.Base
	if base and base.GetManagedAgents then
		bots = base:GetManagedAgents()
	end
	for _, ply in ipairs(bots) do
		if IsValid(ply) and ply:Alive() and ply:Team() == team then
			local st = ply._tfbot_ai
			if st and st.mvm and st.mvm.mode == "mvm_escort_carrier" then
				n = n + 1
			end
		end
	end
	return n
end

local function getClassName(bot)
	return string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
end

normalizeObjective = function(value)
	local s = string.lower(tostring(value or ""))
	s = string.gsub(s, "%s+", "")
	s = string.gsub(s, "_", "")
	s = string.gsub(s, "-", "")
	return s
end

local function getManagedObjective(bot)
	local rt = TF_MVM and TF_MVM.Runtime or nil
	if rt and rt.GetManagedBotObjective then
		local v = rt:GetManagedBotObjective(bot)
		if isstring(v) and v ~= "" then
			return normalizeObjective(v)
		end
	end
	return normalizeObjective(IsValid(bot) and bot.TF_MVM_Objective or "")
end

local function selectEnemyBuilding(bot)
	for _, class in ipairs({"obj_sentrygun", "obj_dispenser", "obj_teleporter"}) do
		local best, bestDist = nil, nil
		for _, ent in ipairs(ents.FindByClass(class)) do
			if not IsValid(ent) or ent:IsFriendly(bot) then continue end
			local d = bot:GetPos():DistToSqr(ent:GetPos())
			if not bestDist or d < bestDist then
				bestDist = d
				best = ent
			end
		end
		if IsValid(best) then
			return best
		end
	end
	return nil
end

local function isThreatNearCarrier(threat, carrier, radius)
	if not IsValid(threat) or not IsValid(carrier) then return false end
	local r = math.max(100, tonumber(radius) or 500)
	return threat:GetPos():DistToSqr(carrier:GetPos()) <= (r * r)
end

local function canUseTeleporterInMvM(bot, state)
	if not IsValid(bot) or not state or not isInvader(bot) then return nil end
	if state.mvm.isCarrier then return nil end
	local cls = getClassName(bot)
	if cls == "engineer" or cls == "giantengineer" or cls == "medic" or cls == "giantmedic" then
		return nil
	end

	local targetPos = state.objective.targetPos
	if not isvector(targetPos) then return nil end

	local myDist = bot:GetPos():DistToSqr(targetPos)
	local best, bestDist
	for _, tele in ipairs(ents.FindByClass("obj_teleporter")) do
		if not IsValid(tele) or not tele:IsFriendly(bot) then continue end
		if not tele.IsEntrance or not tele:IsEntrance() then continue end
		if not tele.IsReady or not tele:IsReady() then continue end
		local exit = tele.GetLinkedTeleporter and tele:GetLinkedTeleporter() or nil
		if not IsValid(exit) then continue end
		local exitDist = exit:GetPos():DistToSqr(targetPos)
		-- Approximate Valve's "ahead of us" check: tele exit must move us significantly toward objective.
		if exitDist + (350 * 350) >= myDist then continue end
		local nearDist = bot:GetPos():DistToSqr(tele:GetPos())
		if nearDist > (1100 * 1100) then continue end
		if not bestDist or nearDist < bestDist then
			bestDist = nearDist
			best = tele
		end
	end
	return best
end

local function setMode(state, mode, targetEnt, targetPos, routeType, ignoreCombat, isCarrier)
	state.mvm.mode = mode or "none"
	state.mvm.routeType = routeType or "default"
	state.mvm.ignoreCombat = ignoreCombat == true
	state.mvm.isCarrier = isCarrier == true
	state.objective.mode = state.mvm.mode
	state.objective.targetEnt = targetEnt
	state.objective.targetPos = targetPos
end

local function applyCarrierDefenseBuffPulse(bot)
	if not IsValid(bot) then return end
	if not isnumber(TF_COND_DEFENSEBUFF_NO_CRIT_BLOCK) or not bot.AddCond then return end
	local radius2 = 450 * 450
	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:Alive() then continue end
		if ply:Team() ~= bot:Team() then continue end
		if bot:GetPos():DistToSqr(ply:GetPos()) > radius2 then continue end
		ply:AddCond(TF_COND_DEFENSEBUFF_NO_CRIT_BLOCK, 1.2, bot)
	end
end

local function syncCarrierUpgradeLevel(bot, state, level, now)
	if not IsValid(bot) or not state then return end
	level = math.Clamp(tonumber(level) or 0, 0, 4)
	local current = tonumber(state.mvm.carrierUpgradeLevel or 0)
	if current == level then return end

	state.mvm.carrierUpgradeLevel = level
	bot.TF_MVM_BombUpgradeLevel = level
	bot:SetNWInt("TF_MVM_BombUpgradeLevel", level)

	if bot.SetMaxSpeed then
		local classTable = bot.GetPlayerClassTable and bot:GetPlayerClassTable() or nil
		local baseSpeed = tonumber((classTable and classTable.Speed) or 0)
		if baseSpeed <= 0 then
			baseSpeed = tonumber(bot.GetRunSpeed and bot:GetRunSpeed() or 0)
		end
		baseSpeed = math.max(220, baseSpeed > 0 and baseSpeed or 300)
		local mult = (level <= 0) and 1.00 or (level == 1 and 1.10 or (level == 2 and 1.20 or (level == 3 and 1.30 or 1.00)))
		bot:SetMaxSpeed(baseSpeed * mult)
	end
end

local function estimateCarrierTravelDistance(bot, state, fallbackPos)
	if not IsValid(bot) or not state then return nil end
	local total = 0
	local lastPos = bot:GetPos()
	if istable(state.path) and istable(state.path.route) and #state.path.route > 0 then
		for i = #state.path.route, 1, -1 do
			local area = state.path.route[i]
			if IsValid(area) and area.GetCenter then
				local c = area:GetCenter()
				total = total + lastPos:Distance(c)
				lastPos = c
			end
		end
	end
	if isvector(fallbackPos) then
		total = total + lastPos:Distance(fallbackPos)
	end
	return total
end

function M:IsMvMMap()
	return isMvMMap()
end

function M:SelectAction(bot, state)
	if not IsValid(bot) or not state or not isMvMMap() then return nil end

	local intel = getBombIntel()
	local deploy = getDeployZone(bot)
	local deployPos = getEntGoalPos(deploy, bot:GetPos())
	local carrier = IsValid(intel) and intel.Carrier or nil
	local missionObjective = getManagedObjective(bot)
	-- Only explicit external flags should force ignore-combat.
	-- Do not feed back state.mvm.ignoreCombat from previous decisions, otherwise
	-- carrier combat can get latched off after deploy/unstuck phases.
	local forceIgnoreCombat = bot.TF_MVM_ForceIgnoreCombat == true or bot.TF_MVM_IgnoreEnemies == true
	local now = CurTime()
	local setupEnd = state.mvm.setupEndAt or 0
	local flankWindowOpen = setupEnd > 0 and now <= (setupEnd + math.max(2, cv_mvm_flank_open_time:GetFloat()))

	if isSentryBuster(bot) then
		local target = selectSentryBusterTarget(bot)
		if IsValid(target) then
			return {
				mode = "mvm_sentry_buster",
				targetEnt = target,
				targetPos = target:GetPos(),
				routeType = "mvm_push",
				ignoreCombat = true,
				isCarrier = false,
			}
		end
	end

	-- Source mission objective support from POP definitions (DestroySentries/Spy/Sniper).
	if missionObjective == "destroysentries" or missionObjective == "missiondestroysentries" or missionObjective == "sentrybuster" then
		local target = selectEnemyBuilding(bot)
		if IsValid(target) then
			return {
				mode = "mvm_destroy_sentries",
				targetEnt = target,
				targetPos = target:GetPos(),
				routeType = "mvm_push",
				ignoreCombat = true,
				isCarrier = false,
			}
		end
	end

	if missionObjective == "spy" or missionObjective == "missionspy" then
		local building = selectEnemyBuilding(bot)
		if IsValid(building) then
			return {
				mode = "mvm_spy_sabotage",
				targetEnt = building,
				targetPos = building:GetPos(),
				routeType = "safest",
				ignoreCombat = false,
				isCarrier = false,
			}
		end
	end

	if (missionObjective == "sniper" or missionObjective == "missionsniper") and IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot then
		if CurTime() > tonumber(state.mvm.sniperLurkRefreshAt or 0) or not isvector(state.mvm.sniperLurkPos) then
			state.mvm.sniperLurkPos = bot.ControllerBot:FindSpot("far", { radius = 2200, pos = deployPos, type = "exposed" }) or deployPos
			state.mvm.sniperLurkRefreshAt = CurTime() + math.Rand(4.0, 7.5)
		end
		return {
			mode = "mvm_sniper_lurk",
			targetEnt = nil,
			targetPos = state.mvm.sniperLurkPos,
			routeType = "safest",
			ignoreCombat = false,
			isCarrier = false,
		}
	end

	if bot:Team() == TEAM_RED then
		if IsValid(carrier) and not carrier:IsFriendly(bot) then
			return {
				mode = "mvm_defend_bomb",
				targetEnt = carrier,
				targetPos = carrier:GetPos(),
				routeType = "safest",
				ignoreCombat = false,
				isCarrier = false,
			}
		end

		if CurTime() > (state.mvm.defendPatrolUntil or 0) or not isvector(state.mvm.defendPatrolPos) then
			if IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot then
				state.mvm.defendPatrolPos = bot.ControllerBot:FindSpot("random", { radius = 1600, pos = deployPos, type = "exposed" }) or deployPos
			else
				state.mvm.defendPatrolPos = deployPos
			end
			state.mvm.defendPatrolUntil = CurTime() + math.Rand(3, 6)
		end

		return {
			mode = "mvm_defend_hatch",
			targetEnt = deploy,
			targetPos = state.mvm.defendPatrolPos or deployPos,
			routeType = "safest",
			ignoreCombat = false,
			isCarrier = false,
		}
	end

	if not isInvader(bot) then return nil end

	if IsValid(carrier) then
		if carrier:EntIndex() == bot:EntIndex() then
			-- Do not allow objective selector to preempt active deploy once started.
			if state.mvm.mode == "mvm_deploy_bomb" and state.mvm.deployState and state.mvm.deployState ~= "none" then
				return {
					mode = "mvm_deploy_bomb",
					targetEnt = deploy,
					targetPos = deployPos,
					routeType = "mvm_bomb_carrier",
					ignoreCombat = true,
					isCarrier = true,
				}
			end

			local forceLeave = now < tonumber(state.mvm.forceLeaveSpawnUntil or 0)
			if (forceLeave or isInsideFriendlySpawnArea(bot)) and not carrierCanDeployNow(bot, deploy, deployPos) then
				local exitPos = getSpawnExitTargetPos(bot)
				if isvector(exitPos) then
					return {
						mode = "mvm_leave_spawn",
						targetEnt = nil,
						targetPos = exitPos,
						routeType = "mvm_flank",
						ignoreCombat = true,
						isCarrier = true,
					}
				end
			end
			local bypassUntil = tonumber(state.mvm.forceCarrierBypassUntil or 0)
			if now < bypassUntil and isvector(state.mvm.carrierBypassPos) then
				if bot:GetPos():DistToSqr(state.mvm.carrierBypassPos) <= (110 * 110) then
					state.mvm.forceCarrierBypassUntil = 0
					state.mvm.carrierBypassPos = nil
				else
					return {
						mode = "mvm_carrier_unstuck",
						targetEnt = nil,
						targetPos = state.mvm.carrierBypassPos,
						routeType = "mvm_push",
						ignoreCombat = true,
						isCarrier = true,
					}
				end
			end
			if IsValid(deploy) and carrierCanDeployNow(bot, deploy, deployPos) then
				return {
					mode = "mvm_deploy_bomb",
					targetEnt = deploy,
					targetPos = deployPos,
					routeType = "mvm_bomb_carrier",
					ignoreCombat = true,
					isCarrier = true,
				}
			end
			return {
				mode = "mvm_deliver_bomb",
				targetEnt = deploy,
				targetPos = deployPos,
				routeType = "mvm_bomb_carrier",
				ignoreCombat = forceIgnoreCombat or (not cv_allow_carrier_fight:GetBool()),
				isCarrier = true,
			}
		end

		local carrierInSpawn = isInsideFriendlySpawnArea(carrier)
		local dist = bot:GetPos():Distance(carrier:GetPos())
		if dist <= 165 and not carrierInSpawn then
			local laneClear = getCarrierLaneClearPos(bot, carrier, deployPos)
			if isvector(laneClear) then
				return {
					mode = "mvm_clear_carrier_lane",
					targetEnt = nil,
					targetPos = laneClear,
					routeType = "mvm_push",
					ignoreCombat = true,
					isCarrier = false,
				}
			end
		end
		if (not carrierInSpawn) and dist > cv_escort_giveup:GetFloat() then
			local catchupPos = getEscortFollowPos(bot, carrier, deployPos) or carrier:GetPos()
			return {
				mode = "mvm_catchup_carrier",
				targetEnt = nil,
				targetPos = catchupPos,
				routeType = "mvm_push",
				ignoreCombat = true,
				isCarrier = false,
			}
		end

		if (not carrierInSpawn) and countEscorts(bot:Team()) > cv_escort_max:GetInt() then
			local escortThreat = state.vision.currentThreat
			if isThreatNearCarrier(escortThreat, carrier, cv_escort_range:GetFloat() * 1.25) then
				return {
					mode = "mvm_attack_flag_defenders",
					targetEnt = escortThreat,
					targetPos = escortThreat:GetPos(),
					routeType = "default",
					ignoreCombat = forceIgnoreCombat,
					isCarrier = false,
				}
			end
			local holdPos = getEscortFollowPos(bot, carrier, deployPos) or carrier:GetPos()
			return {
				mode = "mvm_hold_escort_slot",
				targetEnt = nil,
				targetPos = holdPos,
				routeType = "mvm_push",
				ignoreCombat = forceIgnoreCombat,
				isCarrier = false,
			}
		end

		local desired = getEscortFollowPos(bot, carrier, deployPos) or carrier:GetPos()
		local escortThreat = state.vision.currentThreat
		if (not carrierInSpawn)
			and bot:GetPos():Distance(desired) <= cv_escort_range:GetFloat()
			and isThreatNearCarrier(escortThreat, carrier, cv_escort_range:GetFloat() * 1.35) then
			return {
				mode = "mvm_attack_flag_defenders",
				targetEnt = escortThreat,
				targetPos = escortThreat:GetPos(),
				routeType = "default",
				ignoreCombat = forceIgnoreCombat,
				isCarrier = false,
			}
		end

		return {
			mode = "mvm_escort_carrier",
			targetEnt = nil,
			targetPos = desired,
			routeType = "mvm_push",
			ignoreCombat = forceIgnoreCombat or carrierInSpawn,
			isCarrier = false,
		}
	end

	if IsValid(intel) then
		if bot.TF_MVM_IgnoreFlag then
			if IsValid(state.vision.currentThreat) then
				return {
					mode = "mvm_attack_flag_defenders",
					targetEnt = state.vision.currentThreat,
					targetPos = state.vision.currentThreat:GetPos(),
					routeType = "default",
					ignoreCombat = forceIgnoreCombat,
					isCarrier = false,
				}
			end
			return {
				mode = "mvm_push_hatch",
				targetEnt = deploy,
				targetPos = deployPos,
				routeType = "mvm_push",
				ignoreCombat = forceIgnoreCombat,
				isCarrier = false,
			}
		end
		-- Mirror Valve MvM: if bomb is at home and this bot just spawned, force pickup.
		if isBombAtHome(intel) then
			if (CurTime() - (bot.GetSpawnTime and bot:GetSpawnTime() or CurTime())) < 1.0 then
				if isfunction(intel.Pickup) then
					intel:Pickup(bot)
				end
			else
				if IsValid(state.vision.currentThreat) then
					return {
						mode = "mvm_attack_flag_defenders",
						targetEnt = state.vision.currentThreat,
						targetPos = state.vision.currentThreat:GetPos(),
						routeType = "default",
						ignoreCombat = forceIgnoreCombat,
						isCarrier = false,
					}
				end
			end
		end
		return {
			mode = "mvm_fetch_bomb",
			targetEnt = intel,
			targetPos = intel:GetPos(),
			routeType = "default",
			ignoreCombat = forceIgnoreCombat,
			isCarrier = false,
		}
	end

	local tele = canUseTeleporterInMvM(bot, state)
	if IsValid(tele) then
		return {
			mode = "mvm_use_teleporter",
			targetEnt = tele,
			targetPos = tele:GetPos(),
			routeType = flankWindowOpen and "mvm_flank" or "mvm_push",
			ignoreCombat = forceIgnoreCombat,
			isCarrier = false,
		}
	end

	return {
		mode = "mvm_push_hatch",
		targetEnt = deploy,
		targetPos = deployPos,
		routeType = flankWindowOpen and "mvm_flank" or "mvm_push",
		ignoreCombat = forceIgnoreCombat,
		isCarrier = false,
	}
end

function M:ApplyDecision(bot, state, decision)
	if not IsValid(bot) or not state or not decision then return end
	local prevMode = tostring(state.mvm and state.mvm.mode or "none")
	local prevTarget = getEntGoalPos(state.objective and state.objective.targetEnt, state.objective and state.objective.targetPos)
	setMode(state, decision.mode, decision.targetEnt, decision.targetPos, decision.routeType, decision.ignoreCombat, decision.isCarrier)
	bot.routeType = state.mvm.routeType
	bot.TF_MVM_IgnoreCombat = state.mvm.ignoreCombat
	local newMode = tostring(state.mvm and state.mvm.mode or "none")
	if prevMode ~= newMode then
		local newTargetPos = getEntGoalPos(decision.targetEnt, decision.targetPos)
		debugLog(bot, "mvm_mode_change", 0.05, string.format(
			"mode %s -> %s route=%s carrier=%s ignoreCombat=%s target=%s (prevTarget=%s)",
			prevMode,
			newMode,
			tostring(state.mvm.routeType),
			tostring(state.mvm.isCarrier == true),
			tostring(state.mvm.ignoreCombat == true),
			fmtVec(newTargetPos),
			fmtVec(prevTarget)
		))
	end
	if not state.mvm.isCarrier then
		state.mvm.carrierSince = 0
		state.mvm.carrierUpgradeLevel = 0
		state.mvm.nextCarrierRegenAt = 0
		state.mvm.nextCarrierBuffPulseAt = 0
		state.mvm.lastCarrierTravelDistance = -1
		bot:SetNWInt("TF_MVM_BombUpgradeLevel", 0)
	end
	if decision.mode ~= "mvm_deploy_bomb" then
		if state.mvm.deployFrozen and bot.Freeze then
			bot:Freeze(false)
		end
		state.mvm.deployFrozen = false
		state.mvm.deployState = "none"
		state.mvm.deployAnchor = nil
		state.mvm.deployUntil = 0
	end
	if decision.mode ~= "mvm_use_teleporter" then
		state.mvm.teleUseUntil = 0
	end
end

function M:IsCombatSuppressed(state)
	return state and state.mvm and state.mvm.ignoreCombat == true
end

function M:Tick(bot, state)
	if not IsValid(bot) or not state or not isMvMMap() then return end
	local now = CurTime()
	local rt = TF_MVM and TF_MVM.Runtime or nil
	if rt and rt.IsSetupPhase and rt:IsSetupPhase() then
		state.mvm.setupEndAt = now + 0.2
	end

	if state.mvm.isCarrier then
		local intel = getBombIntel()
		local miniBossCarrier = bot.IsMiniBoss and bot:IsMiniBoss()
		local externalLevel = 0
		if IsValid(intel) and intel.Carrier == bot then
			externalLevel = tonumber(intel.BombUpgradeLevel) or tonumber(intel:GetNWInt("MVM_BombUpgradeLevel", 0)) or 0
		end
		if miniBossCarrier then
			syncCarrierUpgradeLevel(bot, state, 4, now)
		else
			syncCarrierUpgradeLevel(bot, state, math.Clamp(externalLevel, 0, 3), now)
		end

		if state.mvm.carrierUpgradeLevel > 0 then
			state.mvm.nextCarrierBuffPulseAt = tonumber(state.mvm.nextCarrierBuffPulseAt or 0)
			if now >= state.mvm.nextCarrierBuffPulseAt then
				state.mvm.nextCarrierBuffPulseAt = now + 1.0
				applyCarrierDefenseBuffPulse(bot)
			end
		end

		state.mvm.nextCarrierRegenAt = tonumber(state.mvm.nextCarrierRegenAt or 0)
		if state.mvm.carrierUpgradeLevel >= 2 and now >= state.mvm.nextCarrierRegenAt then
			state.mvm.nextCarrierRegenAt = now + 1.0
			local regen = math.max(0, cv_bomb_regen:GetFloat())
			if regen > 0 and bot:Health() > 0 and bot:GetMaxHealth() > 0 then
				bot:SetHealth(math.min(bot:GetMaxHealth(), bot:Health() + math.floor(regen)))
			end
		end

		if state.mvm.carrierUpgradeLevel >= 3 and isnumber(TF_COND_CRITBOOSTED) and bot.AddCond then
			bot:AddCond(TF_COND_CRITBOOSTED, 0.3, bot)
		end

		local deploy = getDeployZone(bot)
		if IsValid(deploy) then
			local deployPos = getEntGoalPos(deploy, nil)
			local travelNow = estimateCarrierTravelDistance(bot, state, deployPos)
			local travelPrev = tonumber(state.mvm.lastCarrierTravelDistance or -1)
			if travelNow and travelPrev > 0 and (travelNow - travelPrev) > 2000 then
				sound.Play("Announcer.MVM_Bomb_Reset", bot:GetPos(), 75, 100, 1)
			end
			state.mvm.lastCarrierTravelDistance = travelNow or travelPrev

			if not isvector(deployPos) then
				deployPos = bot:GetPos()
			end
			local dist = bot:GetPos():DistToSqr(deployPos)
			local best = tonumber(state.mvm.carrierBestDist or 0)
			local bestAt = tonumber(state.mvm.carrierBestDistAt or 0)
			if best <= 0 or dist + (96 * 96) < best then
				state.mvm.carrierBestDist = dist
				state.mvm.carrierBestDistAt = now
			elseif now - bestAt > 3.0 and not (state.mvm.mode == "mvm_deploy_bomb" and state.mvm.deployState and state.mvm.deployState ~= "none") then
				-- Carrier appears stuck: force a repath/escape phase.
				local stuckCount = tonumber(state.mvm.carrierStuckCount or 0) + 1
				state.mvm.carrierStuckCount = stuckCount
				if not carrierCanDeployNow(bot, deploy, deployPos) then
					state.mvm.forceLeaveSpawnUntil = now + 2.5
				end
				state.mvm.forceCarrierBypassUntil = now + math.min(2.5 + (stuckCount * 0.8), 8.0)
				state.mvm.carrierBypassPos = pickCarrierBypassPos(bot, deployPos)
				bot._tfbotMvmRelaxRouteBiasUntil = now + math.min(3.0 + (stuckCount * 0.9), 10.0)
				state.mvm.carrierBestDist = dist
				state.mvm.carrierBestDistAt = now
				debugLog(bot, "mvm_carrier_stuck", 0.35, string.format(
					"carrier_stuck count=%d dist=%.0f best=%.0f deploy=%s bypass=%s relaxUntil=%.2f",
					stuckCount,
					math.sqrt(math.max(0, tonumber(dist) or 0)),
					math.sqrt(math.max(0, tonumber(best) or 0)),
					fmtVec(deployPos),
					fmtVec(state.mvm.carrierBypassPos),
					tonumber(bot._tfbotMvmRelaxRouteBiasUntil or 0)
				))
				if state.path then
					state.path.route = nil
					state.path.targetArea = nil
					state.path.nextRepath = 0
				end
			end
		end
	else
		state.mvm.carrierBestDist = 0
		state.mvm.carrierBestDistAt = 0
		state.mvm.carrierStuckCount = 0
		state.mvm.forceCarrierBypassUntil = 0
		state.mvm.carrierBypassPos = nil
		state.mvm.nextCarrierBuffPulseAt = 0
		state.mvm.nextCarrierRegenAt = 0
		state.mvm.lastCarrierTravelDistance = -1
		if tonumber(state.mvm.carrierUpgradeLevel or 0) ~= 0 then
			state.mvm.carrierUpgradeLevel = 0
			bot.TF_MVM_BombUpgradeLevel = 0
			bot:SetNWInt("TF_MVM_BombUpgradeLevel", 0)
		end
	end

	if state.mvm.mode == "mvm_sentry_buster" then
		if now >= tonumber(state.mvm.nextBusterTalkAt or 0) then
			bot:EmitSound("MVM.SentryBusterIntro")
			state.mvm.nextBusterTalkAt = now + 4.0
		end
	end

	if state.mvm.mode == "mvm_use_teleporter" then
		local tele = state.objective.targetEnt
		if IsValid(tele) and bot:GetPos():DistToSqr(tele:GetPos()) <= (72 * 72) then
			if state.mvm.teleUseUntil <= 0 then
				state.mvm.teleUseUntil = now + 1.6
			elseif now >= state.mvm.teleUseUntil then
				state.mvm.mode = "none"
				state.mvm.teleUseUntil = 0
			end
		else
			state.mvm.teleUseUntil = 0
		end
	end

	if state.mvm.mode ~= "mvm_deploy_bomb" then return end

	local deploy = state.objective.targetEnt
	if not IsValid(deploy) then
		debugLog(bot, "mvm_deploy_abort", 0.25, "deploy_abort invalid_target")
		state.mvm.mode = "none"
		state.mvm.deployState = "none"
		if state.mvm.deployFrozen and bot.Freeze then
			bot:Freeze(false)
		end
		state.mvm.deployFrozen = false
		return
	end

	if state.mvm.deployState == "none" then
		local deployPos = getEntGoalPos(deploy, bot:GetPos())
		debugLog(bot, "mvm_deploy_begin", 0.15, string.format(
			"deploy_state none->delay pos=%s deploy=%s",
			fmtVec(bot:GetPos()),
			fmtVec(deployPos)
		))
		state.mvm.deployState = "delay"
		state.mvm.deployAnchor = bot:GetPos()
		state.mvm.deployUntil = now + cv_deploy_delay:GetFloat()
		state.mvm.ignoreCombat = true
		bot.TF_MVM_IgnoreCombat = true
		if bot.Freeze then
			bot:Freeze(true)
			state.mvm.deployFrozen = true
		end
		bot:EmitSound((bot.IsMiniBoss and bot:IsMiniBoss()) and "MVM.DeployBombGiant" or "MVM.DeployBombSmall")
		local played = playDeployBombAnimation(bot)
		debugLog(bot, "mvm_deploy_anim_try", 0.15, "deploy_anim_played=" .. tostring(played))
		return
	end

	if isvector(state.mvm.deployAnchor)
		and bot:GetPos():DistToSqr(state.mvm.deployAnchor) > (20 * 20)
		and not isPosInsideZone(deploy, bot:GetPos()) then
		-- Mirror Valve deploy reset on push.
		debugLog(bot, "mvm_deploy_reset_push", 0.2, string.format(
			"deploy_reset moved_from_anchor anchor=%s now=%s",
			fmtVec(state.mvm.deployAnchor),
			fmtVec(bot:GetPos())
		))
		bot:EmitSound("Announcer.MVM_Bomb_Reset")
		state.mvm.mode = "mvm_deliver_bomb"
		state.mvm.deployState = "none"
		state.mvm.deployUntil = 0
		if state.mvm.deployFrozen and bot.Freeze then
			bot:Freeze(false)
		end
		state.mvm.deployFrozen = false
		return
	end

	if now >= (state.mvm.deployUntil or 0) then
		if state.mvm.deployState == "delay" then
			debugLog(bot, "mvm_deploy_anim_start", 0.15, "deploy_state delay->animating")
			state.mvm.deployState = "animating"
			state.mvm.deployUntil = now + cv_deploy_time:GetFloat()
			bot:SetNWBool("Taunting", true)
			PlayDeployingAlertThrottled()
		elseif state.mvm.deployState == "animating" then
			debugLog(bot, "mvm_deploy_complete", 0.15, "deploy_state animating->complete")
			state.mvm.deployState = "complete"
			state.mvm.deployUntil = now + 0.2
		elseif state.mvm.deployState == "complete" then
			debugLog(bot, "mvm_deploy_done", 0.15, "deploy_state complete->none")
			local captured = completeBombDeploy(bot, deploy)
			debugLog(bot, "mvm_deploy_capture", 0.15, "deploy_capture_ok=" .. tostring(captured))
			state.mvm.mode = "none"
			state.mvm.deployState = "none"
			state.mvm.deployUntil = 0
			if state.mvm.deployFrozen and bot.Freeze then
				bot:Freeze(false)
			end
			state.mvm.deployFrozen = false
			bot:SetNWBool("Taunting", false)
		end
	end
end

function M:TrySentryBusterDetonate(bot, state, cmd)
	if not IsValid(bot) or not state or state.mvm.mode ~= "mvm_sentry_buster" then return false end
	local target = state.objective.targetEnt
	if not IsValid(target) then
		state.mvm.sentryPathFailures = (state.mvm.sentryPathFailures or 0) + 1
		if state.mvm.sentryPathFailures >= 3 then
			state.mvm.sentryBusterFuseAt = CurTime() + 2.0
		end
		return false
	end
	state.mvm.sentryPathFailures = 0

	local range = math.max(cv_sentry_buster_range:GetFloat() / 3.0, 64.0)
	if bot:GetPos():Distance(target:GetPos()) <= range then
		if state.mvm.sentryBusterFuseAt <= 0 then
			state.mvm.sentryBusterFuseAt = CurTime() + 2.0
			bot:EmitSound("MvM.SentryBusterSpin")
			if isfunction(bot.Taunt) then
				bot:Taunt("1")
			end
			return true
		end
	end

	if state.mvm.sentryBusterFuseAt > 0 and CurTime() >= state.mvm.sentryBusterFuseAt then
		local blastRadius = cv_sentry_buster_range:GetFloat()
		local blastDamage = 500
		if cv_sentry_buster_friendly:GetBool() then
			util.BlastDamage(bot, bot, bot:GetPos(), blastRadius, blastDamage)
		else
			for _, victim in ipairs(ents.FindInSphere(bot:GetPos(), blastRadius)) do
				if not IsValid(victim) then continue end
				if victim == bot then continue end
				if victim.IsFriendly and victim:IsFriendly(bot) then continue end
				local dmg = DamageInfo()
				dmg:SetDamage(blastDamage)
				dmg:SetAttacker(bot)
				dmg:SetInflictor(bot)
				dmg:SetDamageType(DMG_BLAST)
				victim:TakeDamageInfo(dmg)
			end
		end
		util.ScreenShake(bot:GetPos(), 25.0, 5.0, 1.0, 900.0)
		bot:EmitSound("MVM.SentryBusterExplode")
		bot:Kill()
		state.mvm.sentryBusterFuseAt = 0
		return true
	end

	if state.mvm.sentryBusterFuseAt > 0 then
		cmd:SetForwardMove(0)
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_DUCK))
		return true
	end

	return false
end

return M

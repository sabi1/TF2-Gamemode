TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.Combat = TFBotValveAI.Combat or {}

local M = TFBotValveAI.Combat
local cv_melee_engage_dist = CreateConVar("tf_bot_melee_engage_dist", "130", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_ammo_seek_range = CreateConVar("tf_bot_ammo_seek_range", "2600", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_low_ammo_ratio = CreateConVar("tf_bot_low_ammo_ratio", "0.15", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_low_ammo_flee_dist = CreateConVar("tf_bot_low_ammo_flee_dist", "700", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_red_respect_blu_spawn = CreateConVar("tf_bot_red_respect_blu_spawn", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "RED bots do not fire at BLU still inside BLU spawn.")
local cv_allow_carrier_fight = CreateConVar("tf_mvm_bot_allow_flag_carrier_to_fight", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local PASSTIME_THROWSTATE_IDLE = 0
local PASSTIME_THROWSTATE_CHARGING = 1
local PASSTIME_THROWSTATE_CHARGED = 2

local function isPasstimeMap()
	return TF_IsPasstimeMap and TF_IsPasstimeMap() or false
end

local function wepValid(wep)
	return IsValid(wep) or (istable(wep) and wep.__isFakeWeapon == true)
end

local function wepClass(wep)
	if IsValid(wep) and wep.GetClass then
		return wep:GetClass()
	end
	if istable(wep) then
		if wep.GetClass then
			return wep:GetClass()
		end
		return wep.class
	end
	return nil
end

local function isCloseRangeWeapon(wep)
	local wc = string.lower(tostring(wepClass(wep) or ""))
	if wc == "tf_weapon_flamethrower" then return true end
	return wep and wep.IsMeleeWeapon == true
end

local function primaryAmmoType(wep)
	if not IsValid(wep) then return -1 end
	if wep.GetPrimaryAmmoType then
		return tonumber(wep:GetPrimaryAmmoType()) or -1
	end
	return -1
end

local function hasUsableAmmo(bot, wep)
	if not IsValid(bot) or not wepValid(wep) then return false end
	if wep.IsMeleeWeapon == true then return true end

	local clip = wep.Clip1 and tonumber(wep:Clip1()) or nil
	if clip and clip > 0 then
		return true
	end

	local am = primaryAmmoType(wep)
	if am >= 0 and bot.GetAmmoCount and bot:GetAmmoCount(am) > 0 then
		return true
	end

	-- Weapons with no explicit ammo pool/clip (e.g. medigun, some utility weapons).
	if (clip == nil or clip < 0) and am < 0 then
		return true
	end

	return false
end

local function isLowAmmo(bot, wep)
	if not IsValid(bot) or not IsValid(wep) then return false end
	if wep.IsMeleeWeapon == true then return false end
	local am = primaryAmmoType(wep)
	if am < 0 then return false end

	local reserve = tonumber(bot:GetAmmoCount(am) or 0) or 0
	local maxAmmo = tonumber(bot.AmmoMax and bot.AmmoMax[am] or 0) or 0
	if maxAmmo <= 0 then
		return reserve <= 4
	end

	if reserve <= 4 then return true end
	return (reserve / math.max(1, maxAmmo)) <= math.Clamp(cv_low_ammo_ratio:GetFloat(), 0.02, 0.95)
end

local function nearestAmmoPack(bot)
	if not IsValid(bot) then return nil end
	local world = TFBotValveAI and TFBotValveAI.World or nil
	local origin = bot:GetPos()
	local maxDist = math.max(256, cv_ammo_seek_range:GetFloat())
	local maxDist2 = maxDist * maxDist
	local best, bestDist

	for _, cls in ipairs({"item_ammopack_small", "item_ammopack_medium", "item_ammopack_full"}) do
		local entities = world and world:GetEntitiesByClass(cls, 0.15) or ents.FindByClass(cls)
		for _, ent in ipairs(entities) do
			if not IsValid(ent) then continue end
			if ent.GetNoDraw and ent:GetNoDraw() then continue end
			if ent.CanPickup and not ent:CanPickup(bot) then continue end
			local p = ent.GetPos and ent:GetPos() or nil
			if not isvector(p) then continue end
			local d2 = origin:DistToSqr(p)
			if d2 > maxDist2 then continue end
			if not bestDist or d2 < bestDist then
				bestDist = d2
				best = ent
			end
		end
	end

	return best
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

local function passtimeAimPos(ent, fallback)
	if IsValid(ent) then
		if ent.WorldSpaceCenter then
			local ok, pos = pcall(ent.WorldSpaceCenter, ent)
			if ok and isvector(pos) then
				return pos
			end
		end
		if ent.GetPos then
			return ent:GetPos()
		end
	end
	return fallback
end

local function syncPasstimePassTarget(ball, owner, passTarget)
	if not IsValid(ball) then return end
	ball.PassTarget = IsValid(passTarget) and passTarget or nil
	if SERVER and IsValid(owner) then
		if TF_PasstimeSetPassTarget then
			TF_PasstimeSetPassTarget(owner, passTarget)
		else
			owner:SetNWEntity("TFPasstimePassTarget", IsValid(passTarget) and passTarget or NULL)
		end
	end
end

local function handlePasstimeCarrier(bot, cmd, state)
	if not isPasstimeMap() then return false end
	if not (TF_PlayerHasPasstimeBall and TF_PlayerHasPasstimeBall(bot)) then return false end

	local ball = bot:GetWeapon("tf_weapon_passtime_gun")
	if not IsValid(ball) then return false end
	if bot:GetActiveWeapon() ~= ball then
		bot:SelectWeapon("tf_weapon_passtime_gun")
	end

	local mode = tostring(state.objective and state.objective.mode or "")
	local actionTarget = state.objective and state.objective.targetEnt or nil
	local targetPos = passtimeAimPos(actionTarget, state.objective and state.objective.targetPos or nil)
	local throwCtl = state.objective
	throwCtl.passtimeHoldStartedAt = tonumber(throwCtl.passtimeHoldStartedAt or 0)
	throwCtl.passtimeReleaseAt = tonumber(throwCtl.passtimeReleaseAt or 0)
	throwCtl.passtimeThrowMode = tostring(throwCtl.passtimeThrowMode or "")

	if not isvector(targetPos) then
		syncPasstimePassTarget(ball, bot, nil)
		throwCtl.passtimeHoldStartedAt = 0
		throwCtl.passtimeReleaseAt = 0
		throwCtl.passtimeThrowMode = ""
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
		return true
	end

	local lookAng = (targetPos - bot:GetShootPos()):Angle()
	cmd:SetViewAngles(lookAng)
	bot:SetEyeAngles(lookAng)

	if mode ~= "passtime_pass" and mode ~= "passtime_throw_goal" then
		syncPasstimePassTarget(ball, bot, nil)
		throwCtl.passtimeHoldStartedAt = 0
		throwCtl.passtimeReleaseAt = 0
		throwCtl.passtimeThrowMode = ""
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
		return true
	end

	local now = CurTime()
	local desiredPassTarget = (mode == "passtime_pass" and IsValid(actionTarget)) and actionTarget or nil
	syncPasstimePassTarget(ball, bot, desiredPassTarget)

	if throwCtl.passtimeThrowMode ~= mode then
		throwCtl.passtimeHoldStartedAt = 0
		throwCtl.passtimeReleaseAt = 0
		throwCtl.passtimeThrowMode = mode
	end

	local aimDot = bot:EyeAngles():Forward():Dot(lookAng:Forward())
	local dist = bot:GetShootPos():Distance(targetPos)
	local stableAim = aimDot >= 0.992 or dist <= 140
	local minHold = (mode == "passtime_pass") and 0.20 or 0.35
	local throwState = tonumber(ball.ThrowState or PASSTIME_THROWSTATE_IDLE) or PASSTIME_THROWSTATE_IDLE

	if throwState == PASSTIME_THROWSTATE_IDLE then
		if throwCtl.passtimeHoldStartedAt <= 0 then
			throwCtl.passtimeHoldStartedAt = now
		end
		throwCtl.passtimeReleaseAt = 0
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
		cmd:RemoveKey(IN_ATTACK2)
		return true
	end

	if throwState == PASSTIME_THROWSTATE_CHARGING or throwState == PASSTIME_THROWSTATE_CHARGED then
		local heldFor = now - math.max(throwCtl.passtimeHoldStartedAt, 0)
		if throwCtl.passtimeReleaseAt <= 0 and stableAim and heldFor >= minHold then
			throwCtl.passtimeReleaseAt = now
		end
		if throwCtl.passtimeReleaseAt <= 0 then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
		else
			cmd:RemoveKey(IN_ATTACK)
		end
		cmd:RemoveKey(IN_ATTACK2)
		return true
	end

	throwCtl.passtimeHoldStartedAt = 0
	throwCtl.passtimeReleaseAt = 0
	cmd:RemoveKey(IN_ATTACK2)
	return true
end

local function tryHandleMedicHealing(bot, cmd, state)
	local cls = string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
	if cls ~= "medic" and cls ~= "giantmedic" then return false end

	local healTarget = state and state.class and state.class.healTarget or nil
	if not IsValid(healTarget) or not healTarget:Alive() or healTarget:IsFriendly(bot) ~= true then
		return false
	end

	local medigun = bot:GetWeapon("tf_weapon_medigun")
		or bot:GetWeapon("tf_weapon_medigun_merc")
		or bot:GetWeapon("tf_weapon_medigun_qf")
		or bot:GetWeapon("tf_weapon_medigun_vaccinator")
		or bot:GetWeapon("tf_weapon_medigun_machinery")
	if not IsValid(medigun) then
		for _, wep in ipairs(bot:GetWeapons() or {}) do
			if IsValid(wep) and string.find(string.lower(wep:GetClass() or ""), "medigun", 1, true) then
				medigun = wep
				break
			end
		end
	end
	if not IsValid(medigun) then
		return false
	end

	if bot:GetActiveWeapon() ~= medigun then
		bot:SelectWeapon(medigun:GetClass())
	end

	local aimPos = healTarget.WorldSpaceCenter and healTarget:WorldSpaceCenter() or healTarget:GetPos()
	local lookAng = (aimPos - bot:GetShootPos()):Angle()
	cmd:SetViewAngles(lookAng)
	bot:SetEyeAngles(lookAng)

	local dist = bot:GetPos():Distance(healTarget:GetPos())
	local vision = TFBotValveAI and TFBotValveAI.Vision or nil
	local hasHealLOS = vision and vision.HasHealLineOfSight and vision:HasHealLineOfSight(bot, healTarget)
		or (vision and vision.HasLineOfSight and vision:HasLineOfSight(bot, healTarget, vision:GetMedicLOSModeMask()))
		or bot:Visible(healTarget)
	local medigunRange = math.max(tonumber(medigun.Range) or 0, 1)
	local engageRange = math.max(140, medigunRange - 64)
	local inRange = dist <= engageRange

	if inRange and hasHealLOS then
		if medigun.SetHealTarget and medigun.Target ~= healTarget then
			medigun:SetHealTarget(healTarget)
		end
	else
		if medigun.Target == healTarget and medigun.ClearHealTarget then
			medigun:ClearHealTarget()
		end
	end

	if inRange and hasHealLOS then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
	else
		cmd:RemoveKey(IN_ATTACK)
	end

	local threat = state and state.vision and state.vision.currentThreat or nil
	local patientLow = (tonumber(healTarget:Health()) or 0) / math.max(tonumber(healTarget:GetMaxHealth()) or 1, 1) <= 0.45
	local threatNear = IsValid(threat) and healTarget:GetPos():DistToSqr(threat:GetPos()) <= (550 * 550)
	local charge = tonumber(bot:GetNWInt("Ubercharge", 0) or 0)
	if charge >= 100 and (patientLow or threatNear) then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK2))
	end

	return true
end

local function chooseWeapon(bot, threat, state)
	if not IsValid(bot) then return nil, {} end
	local weapons = bot:GetWeapons()
	if not weapons or #weapons == 0 then return nil, {} end
	local dist = IsValid(threat) and bot:GetPos():Distance(threat:GetPos()) or 99999
	local restriction = string.lower(tostring(bot.TF_MVM_WeaponRestriction or ""))
	local objectiveMode = string.lower(tostring(state and state.objective and state.objective.mode or ""))
	local forceMelee = objectiveMode == "melee_attack"
		or objectiveMode == "spy_attack_knife"

	local medicTarget = state and state.class and state.class.healTarget or nil
	local botClass = string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
	if (botClass == "medic" or botClass == "giantmedic") and IsValid(medicTarget) then
		for _, wep in ipairs(weapons) do
			if not wepValid(wep) then continue end
			local wc = string.lower(tostring(wepClass(wep) or ""))
			if string.find(wc, "medigun", 1, true) then
				bot:SelectWeapon(wep:GetClass())
				return wep, {
					melee = nil,
					rangedWithAmmo = wep,
					rangedNoAmmo = nil,
					outOfRangedAmmo = false,
				}
			end
		end
	end

	local function allowed(wep)
		if not wepValid(wep) then return false end
		if restriction == "meleeonly" then
			return wep.IsMeleeWeapon == true
		end
		if restriction == "primaryonly" then
			return wep.IsPrimaryWeapon == true
		end
		if restriction == "secondaryonly" then
			return wep.IsSecondaryWeapon == true
		end
		return true
	end

	local preferred = nil
	local meleeWep = nil
	local rangedWithAmmo = nil
	local rangedNoAmmo = nil
	for _, wep in ipairs(weapons) do
		if not wepValid(wep) then continue end
		if not allowed(wep) then continue end
		if wep.IsMeleeWeapon then
			meleeWep = meleeWep or wep
		end
		if wep.IsMeleeWeapon ~= true then
			if hasUsableAmmo(bot, wep) then
				rangedWithAmmo = rangedWithAmmo or wep
			else
				rangedNoAmmo = rangedNoAmmo or wep
			end
		end
		preferred = preferred or wep
		if wep.IsMeleeWeapon and dist <= cv_melee_engage_dist:GetFloat() then
			preferred = wep
			break
		end
		if not hasUsableAmmo(bot, wep) and wep.IsMeleeWeapon ~= true then
			continue
		end
		if wep.ZoomStatus and dist > 700 then
			preferred = wep
		end
		local wc = string.lower(tostring(wepClass(wep) or ""))
		if string.find(wc, "medigun", 1, true) then
			preferred = wep
		end
	end

	local fallback = preferred
	if forceMelee and wepValid(meleeWep) then
		preferred = meleeWep
	elseif dist <= cv_melee_engage_dist:GetFloat() and wepValid(meleeWep) then
		preferred = meleeWep
	elseif wepValid(rangedWithAmmo) then
		preferred = rangedWithAmmo
	elseif wepValid(meleeWep) then
		preferred = meleeWep
	else
		preferred = fallback
	end

	if preferred then
		local wc = wepClass(preferred)
		if wc then
			bot:SelectWeapon(wc)
		end
	end
	return preferred, {
		melee = meleeWep,
		rangedWithAmmo = rangedWithAmmo,
		rangedNoAmmo = rangedNoAmmo,
		outOfRangedAmmo = (not wepValid(rangedWithAmmo)) and wepValid(rangedNoAmmo),
	}
end

local function clearBreakablePathTarget(state)
	if not state or not state.path then return end
	state.path.breakableEntIndex = -1
	state.path.breakableUntil = 0
	state.path.breakableTargetPos = nil
end

local function tryAttackPathBreakable(bot, cmd, state)
	if not (IsValid(bot) and state and state.path) then return false end

	local untilAt = tonumber(state.path.breakableUntil or 0)
	if untilAt <= 0 or CurTime() >= untilAt then
		clearBreakablePathTarget(state)
		return false
	end

	local entIndex = tonumber(state.path.breakableEntIndex or -1)
	if entIndex < 0 then
		clearBreakablePathTarget(state)
		return false
	end

	local obstacle = Entity(entIndex)
	if not IsValid(obstacle) then
		clearBreakablePathTarget(state)
		return false
	end

	local aimPos = obstacle.WorldSpaceCenter and obstacle:WorldSpaceCenter() or obstacle:GetPos()
	if not isvector(aimPos) then
		clearBreakablePathTarget(state)
		return false
	end

	local selected = chooseWeapon(bot, obstacle, state)
	local active = bot:GetActiveWeapon()
	if not IsValid(active) and wepValid(selected) then
		active = selected
	end

	local lookAng = (aimPos - bot:GetShootPos()):Angle()
	cmd:SetViewAngles(lookAng)
	bot:SetEyeAngles(lookAng)
	cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
	cmd:RemoveKey(IN_ATTACK2)
	return true
end

function M:Update(bot, cmd, state)
	if not IsValid(bot) or not state or not bot:Alive() then return end
	if handlePasstimeCarrier(bot, cmd, state) then
		return
	end
	if tryHandleMedicHealing(bot, cmd, state) then
		return
	end
	if bot.TF_MVM_IgnoreEnemies then
		return
	end
	if bot.TF_MVM_SuppressFire or bot.NoAttack then
		return
	end
	if tryAttackPathBreakable(bot, cmd, state) then
		return
	end
	local mvm = TFBotValveAI.MvM
	if mvm and mvm:TrySentryBusterDetonate(bot, state, cmd) then
		return
	end
	if mvm and mvm:IsCombatSuppressed(bot, state) then
		local mvmState = state.mvm or {}
		local mode = tostring(mvmState.mode or "")
		local carrierCanFight = mvmState.isCarrier == true
			and mode == "mvm_deliver_bomb"
			and cv_allow_carrier_fight:GetBool()
		if not carrierCanFight then
			return
		end
	end
	local threat = state.vision.currentThreat
	if not IsValid(threat) then return end
	if cv_red_respect_blu_spawn:GetBool()
		and bot:Team() == TEAM_RED
		and threat.IsPlayer and threat:IsPlayer()
		and (threat:Team() == TEAM_BLU or threat:Team() == TF_TEAM_PVE_INVADERS)
		and inSpawnAreaForTeam(threat:GetPos(), threat:Team()) then
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
		return
	end

	local selected, ctx = chooseWeapon(bot, threat, state)
	local active = bot:GetActiveWeapon()
	if not IsValid(active) and wepValid(selected) then
		active = selected
	end
	local aimPos = threat.WorldSpaceCenter and threat:WorldSpaceCenter() or threat:GetPos()
	local lookAng = (aimPos - bot:GetShootPos()):Angle()
	cmd:SetViewAngles(lookAng)
	bot:SetEyeAngles(lookAng)

	local dist = bot:GetPos():Distance(threat:GetPos())
	local objectiveMode = string.lower(tostring(state.objective and state.objective.mode or ""))
	local sourceManagedMode = objectiveMode == "retreat_to_cover"
		or objectiveMode == "get_health"
		or objectiveMode == "get_ammo"
		or objectiveMode == "melee_attack"
		or objectiveMode == "use_teleporter"
		or objectiveMode == "use_teleporter_exit"
		or objectiveMode == "destroy_enemy_sentry"
		or objectiveMode == "spy_attack_knife"
		or objectiveMode == "spy_attack_pistol"
		or objectiveMode == "spy_sap"
		or objectiveMode == "spy_sap_move"
	local desiredRange = (istable(active) and tonumber(active.range)) or (active and active.IsMeleeWeapon and 95) or 550
	local meleeUsable = wepValid(ctx and ctx.melee)
	local outOfRangedAmmo = ctx and ctx.outOfRangedAmmo == true
	local lowAmmoNow = wepValid(active) and isLowAmmo(bot, active)
	local isMvMCarrier = state and state.mvm and state.mvm.isCarrier == true

	if objectiveMode == "retreat_to_cover" then
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
		return
	end

	if objectiveMode == "use_teleporter" or objectiveMode == "use_teleporter_exit" then
		cmd:RemoveKey(IN_ATTACK2)
	end

	if (not isMvMCarrier) and outOfRangedAmmo and dist > cv_melee_engage_dist:GetFloat() then
		local ammo = nearestAmmoPack(bot)
		if IsValid(ammo) then
			state.objective.mode = "attack_seek_ammo"
			state.objective.targetEnt = ammo
			state.objective.targetPos = ammo:GetPos()
		else
			state.objective.mode = "attack_flee_no_ammo"
			state.objective.targetEnt = nil
			if IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot then
				state.objective.targetPos = bot.ControllerBot:FindSpot("random", { radius = 1100, pos = bot:GetPos(), type = "covered" }) or bot:GetPos()
			else
				state.objective.targetPos = bot:GetPos() - bot:GetForward() * 280
			end
		end
		state.objective.nextUpdate = CurTime() + 0.15
		bot.routeType = "safest"
		cmd:RemoveKey(IN_ATTACK)
		cmd:SetForwardMove(-240)
		return
	end

	if (not isMvMCarrier) and lowAmmoNow and dist <= cv_low_ammo_flee_dist:GetFloat() then
		local ammo = nearestAmmoPack(bot)
		if IsValid(ammo) then
			state.objective.mode = "attack_seek_ammo_low"
			state.objective.targetEnt = ammo
			state.objective.targetPos = ammo:GetPos()
		else
			state.objective.mode = "attack_flee_low_ammo"
			state.objective.targetEnt = nil
			if IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot then
				state.objective.targetPos = bot.ControllerBot:FindSpot("random", { radius = 1000, pos = bot:GetPos(), type = "covered" }) or bot:GetPos()
			else
				state.objective.targetPos = bot:GetPos() - bot:GetForward() * 260
			end
		end
		state.objective.nextUpdate = CurTime() + 0.20
		bot.routeType = "safest"
		cmd:SetForwardMove(-220)
		if not (meleeUsable and dist <= cv_melee_engage_dist:GetFloat()) then
			cmd:RemoveKey(IN_ATTACK)
		end
		return
	end

	local inRange = dist <= desiredRange * 1.1
	local vision = TFBotValveAI and TFBotValveAI.Vision or nil
	local los = vision and vision.HasLineOfSight and vision:HasLineOfSight(bot, threat) or bot:Visible(threat)

	-- Source-style pursuit: keep pushing to LOS/desired range while fighting.
	if ((not los) or (not inRange)) and not sourceManagedMode then
		state.objective.mode = "attack_pursue"
		state.objective.targetEnt = threat
		state.objective.targetPos = threat:GetPos()
		if isCloseRangeWeapon(active) and not (bot.IsMVMRobot or bot:Team() == TF_TEAM_PVE_INVADERS) then
			bot.routeType = "safest"
		else
			bot.routeType = "default"
		end
	end

	-- Source-style close-range circle movement.
	if isCloseRangeWeapon(active) and los and dist <= math.max(desiredRange * 1.1, 110) and objectiveMode ~= "retreat_to_cover" then
		local seed = math.floor(CurTime() * 2 + bot:EntIndex()) % 2
		cmd:SetSideMove(seed == 0 and 220 or -220)
	end

	local shouldAttack = dist <= 2200 and los
	if objectiveMode == "melee_attack" or objectiveMode == "spy_attack_knife" then
		shouldAttack = shouldAttack and dist <= math.max(cv_melee_engage_dist:GetFloat(), 115)
	end
	if bot.TF_MVM_HoldFireUntilFullReload then
		-- Source behavior is weapon-state based; in Lua we approximate by waiting for close engagement.
		shouldAttack = shouldAttack and dist <= 700
	end
	if bot.TF_MVM_AlwaysFireWeapon then
		shouldAttack = los
	end
	if shouldAttack then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
	end
end

return M

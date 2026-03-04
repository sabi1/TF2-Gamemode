TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.Combat = TFBotValveAI.Combat or {}

local M = TFBotValveAI.Combat
local cv_melee_engage_dist = CreateConVar("tf_bot_melee_engage_dist", "130", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_ammo_seek_range = CreateConVar("tf_bot_ammo_seek_range", "2600", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_low_ammo_ratio = CreateConVar("tf_bot_low_ammo_ratio", "0.15", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_low_ammo_flee_dist = CreateConVar("tf_bot_low_ammo_flee_dist", "700", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_red_respect_blu_spawn = CreateConVar("tf_bot_red_respect_blu_spawn", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "RED bots do not fire at BLU still inside BLU spawn.")

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
	local origin = bot:GetPos()
	local maxDist = math.max(256, cv_ammo_seek_range:GetFloat())
	local maxDist2 = maxDist * maxDist
	local best, bestDist

	for _, cls in ipairs({"item_ammopack_small", "item_ammopack_medium", "item_ammopack_full"}) do
		for _, ent in ipairs(ents.FindByClass(cls)) do
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

local function chooseWeapon(bot, threat)
	if not IsValid(bot) then return nil, {} end
	local weapons = bot:GetWeapons()
	if not weapons or #weapons == 0 then return nil, {} end
	local dist = IsValid(threat) and bot:GetPos():Distance(threat:GetPos()) or 99999
	local restriction = string.lower(tostring(bot.TF_MVM_WeaponRestriction or ""))

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
		if wepClass(wep) == "tf_weapon_medigun" then
			preferred = wep
		end
	end

	local fallback = preferred
	if dist <= cv_melee_engage_dist:GetFloat() and wepValid(meleeWep) then
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

function M:Update(bot, cmd, state)
	if not IsValid(bot) or not state or not bot:Alive() then return end
	if bot.TF_MVM_IgnoreEnemies then
		return
	end
	if bot.TF_MVM_SuppressFire or bot.NoAttack then
		return
	end
	local mvm = TFBotValveAI.MvM
	if mvm and mvm:TrySentryBusterDetonate(bot, state, cmd) then
		return
	end
	if mvm and mvm:IsCombatSuppressed(state) then
		return
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

	local selected, ctx = chooseWeapon(bot, threat)
	local active = bot:GetActiveWeapon()
	if not IsValid(active) and wepValid(selected) then
		active = selected
	end
	local aimPos = threat.WorldSpaceCenter and threat:WorldSpaceCenter() or threat:GetPos()
	local lookAng = (aimPos - bot:GetShootPos()):Angle()
	cmd:SetViewAngles(lookAng)
	bot:SetEyeAngles(lookAng)

	local dist = bot:GetPos():Distance(threat:GetPos())
	local desiredRange = (istable(active) and tonumber(active.range)) or (active and active.IsMeleeWeapon and 95) or 550
	local meleeUsable = wepValid(ctx and ctx.melee)
	local outOfRangedAmmo = ctx and ctx.outOfRangedAmmo == true
	local lowAmmoNow = IsValid(active) and isLowAmmo(bot, active)

	if outOfRangedAmmo and dist > cv_melee_engage_dist:GetFloat() then
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

	if lowAmmoNow and dist <= cv_low_ammo_flee_dist:GetFloat() then
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
	local los = bot:Visible(threat)

	-- Source-style pursuit: keep pushing to LOS/desired range while fighting.
	if (not los) or (not inRange) then
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
	if isCloseRangeWeapon(active) and los and dist <= math.max(desiredRange * 1.1, 110) then
		local seed = math.floor(CurTime() * 2 + bot:EntIndex()) % 2
		cmd:SetSideMove(seed == 0 and 220 or -220)
	end

	local shouldAttack = dist <= 2200 and bot:Visible(threat)
	if bot.TF_MVM_HoldFireUntilFullReload then
		-- Source behavior is weapon-state based; in Lua we approximate by waiting for close engagement.
		shouldAttack = shouldAttack and dist <= 700
	end
	if bot.TF_MVM_AlwaysFireWeapon then
		shouldAttack = bot:Visible(threat)
	end
	if shouldAttack then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
	end
end

return M

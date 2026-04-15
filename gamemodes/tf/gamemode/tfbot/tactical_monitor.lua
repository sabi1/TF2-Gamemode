TFBotSource = TFBotSource or {}
TFBotSource.TacticalMonitor = TFBotSource.TacticalMonitor or {}

local M = TFBotSource.TacticalMonitor

local cv_health_ok = CreateConVar("tf_bot_source_health_ok_ratio", "0.8", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Health ratio above which source-shaped TFBots stop looking for health.")
local cv_health_critical = CreateConVar("tf_bot_source_health_critical_ratio", "0.3", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Health ratio below which source-shaped TFBots prefer retreat/health.")
local cv_retreat_range = CreateConVar("tf_bot_source_retreat_to_cover_range", "1000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Search range for source-shaped retreat-to-cover.")
local cv_melee_abandon = CreateConVar("tf_bot_source_melee_attack_abandon_range", "500", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Range above which source-shaped melee attack gives up.")

local function is_enemy_sentry(bot, ent)
	if not (IsValid(bot) and IsValid(ent)) then return false end
	if string.lower(tostring(ent.GetClass and ent:GetClass() or "")) ~= "obj_sentrygun" then
		return false
	end
	if ent.Team and ent:Team() == bot:Team() then
		return false
	end
	return true
end

local function hasValidThreat(st)
	return st and st.vision and IsValid(st.vision.currentThreat)
end

local function healthRatio(bot)
	if not IsValid(bot) then return 1 end
	local maxHp = math.max(1, tonumber(bot.GetMaxHealth and bot:GetMaxHealth() or 0) or 1)
	return math.Clamp((tonumber(bot:Health()) or 0) / maxHp, 0, 2)
end

local function activeWeapon(bot)
	return IsValid(bot) and bot.GetActiveWeapon and bot:GetActiveWeapon() or nil
end

local function isMeleeWeapon(wep)
	if not IsValid(wep) then return false end
	if wep.IsMeleeWeapon == true then return true end
	local cls = string.lower(tostring(wep.GetClass and wep:GetClass() or ""))
	return string.find(cls, "knife", 1, true) ~= nil
		or string.find(cls, "bat", 1, true) ~= nil
		or string.find(cls, "shovel", 1, true) ~= nil
		or string.find(cls, "fists", 1, true) ~= nil
		or string.find(cls, "wrench", 1, true) ~= nil
end

local function primaryAmmoType(wep)
	if not IsValid(wep) or not wep.GetPrimaryAmmoType then return -1 end
	return tonumber(wep:GetPrimaryAmmoType()) or -1
end

local function isLowAmmo(bot, wep)
	if not (IsValid(bot) and IsValid(wep)) then return false end
	if isMeleeWeapon(wep) then return false end
	local clip = wep.Clip1 and tonumber(wep:Clip1()) or -1
	if clip > 0 then
		return false
	end
	local ammoType = primaryAmmoType(wep)
	if ammoType < 0 then return false end
	local reserve = tonumber(bot.GetAmmoCount and bot:GetAmmoCount(ammoType) or 0) or 0
	local maxAmmo = tonumber(bot.AmmoMax and bot.AmmoMax[ammoType] or 0) or 0
	if maxAmmo <= 0 then
		return reserve <= 4
	end
	return reserve <= 4 or (reserve / math.max(1, maxAmmo)) <= 0.15
end

function M:SelectAction(bot, st, profile, currentAction)
	if not (IsValid(bot) and st and profile) then
		return currentAction
	end

	local threat = hasValidThreat(st) and st.vision.currentThreat or nil
	local cls = string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
	local hp = healthRatio(bot)

	if cls == "sniper" and IsValid(threat) and bot:GetPos():DistToSqr(threat:GetPos()) <= (250 * 250) then
		return "MeleeAttack"
	end

	if is_enemy_sentry(bot, threat)
		and TFBotSource.Actions.DestroyEnemySentry
		and TFBotSource.Actions.DestroyEnemySentry.IsPossible
		and TFBotSource.Actions.DestroyEnemySentry:IsPossible(bot, threat) then
		return "DestroyEnemySentry"
	end

	if IsValid(threat) and hp <= cv_health_critical:GetFloat() then
		return "RetreatToCover"
	end

	if not (GAMEMODE and GAMEMODE.IsMannVsMachineMode and GAMEMODE:IsMannVsMachineMode()) then
		if hp < cv_health_ok:GetFloat() and TFBotSource.Actions.GetHealth and TFBotSource.Actions.GetHealth:IsPossible(bot, st) then
			return "GetHealth"
		end
	end

	local wep = activeWeapon(bot)
	if IsValid(wep) and isLowAmmo(bot, wep) and TFBotSource.Actions.GetAmmo and TFBotSource.Actions.GetAmmo:IsPossible(bot, st) then
		return "GetAmmo"
	end

	if currentAction == "MeleeAttack" and IsValid(threat) then
		if bot:GetPos():DistToSqr(threat:GetPos()) > (cv_melee_abandon:GetFloat() * cv_melee_abandon:GetFloat()) then
			return "SeekAndDestroy"
		end
	end

	return currentAction
end

return M

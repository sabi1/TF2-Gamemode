TF_MAPTYPES = TF_MAPTYPES or {}

local MAP_PREFIX_TO_MODE = {
	arena = "arena",
	cp = "cp",
	ctf = "ctf",
	koth = "koth",
	mvm = "mvm",
	pass = "passtime",
	pd = "pd",
	pl = "payload",
	plr = "payload",
	powerup = "mannpower",
	rd = "rd",
	sd = "sd",
	tc = "cp",
	tr = "training",
	vsh = "boss",
}

local function normalizeMapName(mapName)
	return string.lower(tostring(mapName or game.GetMap() or ""))
end

local function getMapPrefix(mapName)
	local map = normalizeMapName(mapName)
	return string.match(map, "^([%w]+)_")
end

local function modeFromPrefix(mapName)
	local prefix = getMapPrefix(mapName)
	return prefix and MAP_PREFIX_TO_MODE[prefix] or nil
end

function TF_MAPTYPES.GetMapPrefix(mapName)
	return getMapPrefix(mapName)
end

function TF_MAPTYPES.GetModeFromMapPrefix(mapName)
	return modeFromPrefix(mapName) or "unknown"
end

function TF_MAPTYPES.GetHudMode(forceRefresh)
	if TF_GetHudGameMode then
		return TF_GetHudGameMode(forceRefresh)
	end

	return TF_MAPTYPES.GetModeFromMapPrefix()
end

function TF_MAPTYPES.IsMode(mode, forceRefresh)
	return TF_MAPTYPES.GetHudMode(forceRefresh) == tostring(mode or "")
end

function TF_MAPTYPES.IsControlPoint(forceRefresh)
	local mode = TF_MAPTYPES.GetHudMode(forceRefresh)
	return mode == "cp" or mode == "koth" or mode == "arena"
end

function TF_MAPTYPES.IsCTF(forceRefresh)
	return TF_MAPTYPES.IsMode("ctf", forceRefresh)
end

function TF_MAPTYPES.IsPayload(forceRefresh)
	return TF_MAPTYPES.IsMode("payload", forceRefresh)
end

function TF_MAPTYPES.IsKoth(forceRefresh)
	return TF_MAPTYPES.IsMode("koth", forceRefresh)
end

function TF_MAPTYPES.IsArena(forceRefresh)
	return TF_MAPTYPES.IsMode("arena", forceRefresh)
end

function TF_MAPTYPES.IsMvM(forceRefresh)
	if TF_IsMvMMap then
		return TF_IsMvMMap(forceRefresh)
	end

	return TF_MAPTYPES.IsMode("mvm", forceRefresh)
end

function TF_MAPTYPES.IsPassTime(forceRefresh)
	if TF_IsPasstimeMap and TF_IsPasstimeMap() then
		return true
	end
	return TF_MAPTYPES.IsMode("passtime", forceRefresh)
end

function TF_MAPTYPES.IsMannpower(forceRefresh)
	if TF_IsMannpowerMode and TF_IsMannpowerMode() then
		return true
	end
	return TF_MAPTYPES.IsMode("mannpower", forceRefresh)
end

function TF_MAPTYPES.IsPlayerDestruction(forceRefresh)
	return TF_MAPTYPES.IsMode("pd", forceRefresh)
end

function TF_MAPTYPES.IsRobotDestruction(forceRefresh)
	return TF_MAPTYPES.IsMode("rd", forceRefresh)
end

function TF_MAPTYPES.IsSpecialDelivery(forceRefresh)
	return TF_MAPTYPES.IsMode("sd", forceRefresh)
end

function TF_MAPTYPES.IsTraining(forceRefresh)
	return TF_MAPTYPES.IsMode("training", forceRefresh)
end

function TF_MAPTYPES.IsBossMap(forceRefresh)
	return TF_MAPTYPES.IsMode("boss", forceRefresh)
end

function TF_MAPTYPES.IsMedieval()
	return GetGlobalBool("tf_medieval_mode", false)
end

function TF_MAPTYPES.IsHybridCTFCP()
	return GetGlobalBool("tf_hybrid_ctf_cp_map", false)
end

function TF_MAPTYPES.IsMultipleEscort()
	return GetGlobalBool("tf_multiple_escort_map", false)
end

function TF_MAPTYPES.IsSpecialDeliveryMap(forceRefresh)
	if TF_MAPTYPES.IsMode("sd", forceRefresh) then
		return true
	end

	for _, flag in ipairs(ents.FindByClass("item_teamflag")) do
		if IsValid(flag) and tonumber(flag.TeamNum or -1) == 0 then
			return true
		end
	end

	return false
end

function TF_GetMapPrefix(mapName)
	return TF_MAPTYPES.GetMapPrefix(mapName)
end

function TF_GetMapModeFromPrefix(mapName)
	return TF_MAPTYPES.GetModeFromMapPrefix(mapName)
end

function TF_IsSpecialDeliveryMap(forceRefresh)
	return TF_MAPTYPES.IsSpecialDeliveryMap(forceRefresh)
end

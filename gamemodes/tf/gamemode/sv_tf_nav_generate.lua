if CLIENT then return end

TFBotNavGen = TFBotNavGen or {}
local M = TFBotNavGen

local DATA_DIR = "tf/nav_landmarks"
local POLL_TIMER = "TFBotNavGen_Poll"
local META_VERSION = 2
local vectorUp = Vector(0, 0, 1)
local mapPrefix = string.lower((game.GetMap() or ""):match("^([a-z0-9]+)_") or "")

file.CreateDir("tf")
file.CreateDir(DATA_DIR)

M.Runtime = M.Runtime or {
	active = false,
	landmarks = {},
	areaMeta = {},
	mapMode = "generic",
}

local function debugLog(msg)
	MsgN("[tf_nav_generate] " .. tostring(msg))
end

local function notify(invoker, msg)
	debugLog(msg)
	if IsValid(invoker) then
		invoker:PrintMessage(HUD_PRINTTALK, "[TF Nav] " .. tostring(msg))
	end
end

local function hasNavmesh()
	return navmesh
		and navmesh.IsLoaded
		and navmesh.BeginGeneration
		and navmesh.AddWalkableSeed
		and navmesh.GetNearestNavArea
		and navmesh.GetAllNavAreas
end

local function getEntPos(ent)
	if not IsValid(ent) then return nil end
	if ent.WorldSpaceCenter then
		local ok, center = pcall(ent.WorldSpaceCenter, ent)
		if ok and isvector(center) then
			return center
		end
	end
	if ent.OBBCenter and ent.LocalToWorld then
		local okCenter, center = pcall(ent.OBBCenter, ent)
		if okCenter and isvector(center) then
			local okWorld, world = pcall(ent.LocalToWorld, ent, center)
			if okWorld and isvector(world) then
				return world
			end
		end
	end
	if ent.GetPos then
		local ok, pos = pcall(ent.GetPos, ent)
		if ok and isvector(pos) then
			return pos
		end
	end
	return nil
end

local function getTeamNum(ent)
	if not IsValid(ent) then return nil end
	if isfunction(ent.Team) then
		local ok, teamNum = pcall(ent.Team, ent)
		if ok and isnumber(teamNum) then
			return teamNum
		end
	end
	local direct = tonumber(ent.TeamNum or ent.teamnum or ent:GetNWInt("TeamNum", -1))
	if direct and direct >= 0 then
		return direct
	end
	if ent.GetInternalVariable then
		local ok, internal = pcall(ent.GetInternalVariable, ent, "TeamNum")
		if ok then
			internal = tonumber(internal)
			if internal then
				return internal
			end
		end
	end
	return nil
end

local function addPoint(list, dedupe, kind, pos, meta)
	if not isvector(pos) then return end
	local key = table.concat({
		tostring(kind or "unknown"),
		math.Round(pos.x / 48),
		math.Round(pos.y / 48),
		math.Round(pos.z / 48),
		tostring(meta and meta.team or 0),
	}, "|")
	if dedupe[key] then return end
	dedupe[key] = true

	list[#list + 1] = {
		kind = kind,
		pos = pos,
		team = meta and meta.team or nil,
		classname = meta and meta.classname or nil,
		name = meta and meta.name or nil,
	}
end

local function normalizeAttrName(name)
	name = string.lower(tostring(name or ""))
	name = string.gsub(name, "^tf_nav_", "")
	return name
end

local function getTeamControlPointNum(teamNum)
	if teamNum == TEAM_RED then return 2 end
	if teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS then return 3 end
	return nil
end

local function getWorldAABB(ent)
	if not IsValid(ent) then return nil, nil end
	if ent.WorldSpaceAABB then
		local ok, mins, maxs = pcall(ent.WorldSpaceAABB, ent)
		if ok and isvector(mins) and isvector(maxs) then
			return mins, maxs
		end
	end
	if ent.GetCollisionBounds and ent.LocalToWorld then
		local okBounds, mins, maxs = pcall(ent.GetCollisionBounds, ent)
		if okBounds and isvector(mins) and isvector(maxs) then
			local okWorldMin, worldMin = pcall(ent.LocalToWorld, ent, mins)
			local okWorldMax, worldMax = pcall(ent.LocalToWorld, ent, maxs)
			if okWorldMin and okWorldMax and isvector(worldMin) and isvector(worldMax) then
				return Vector(math.min(worldMin.x, worldMax.x), math.min(worldMin.y, worldMax.y), math.min(worldMin.z, worldMax.z)),
					Vector(math.max(worldMin.x, worldMax.x), math.max(worldMin.y, worldMax.y), math.max(worldMin.z, worldMax.z))
			end
		end
	end
	return nil, nil
end

local function pointWithinBounds(pos, mins, maxs, pad)
	if not (isvector(pos) and isvector(mins) and isvector(maxs)) then return false end
	pad = tonumber(pad) or 0
	return pos.x >= (mins.x - pad) and pos.x <= (maxs.x + pad)
		and pos.y >= (mins.y - pad) and pos.y <= (maxs.y + pad)
		and pos.z >= (mins.z - pad) and pos.z <= (maxs.z + pad)
end

local function getAllNavAreas()
	if not (navmesh and navmesh.GetAllNavAreas) then return {} end
	return navmesh.GetAllNavAreas() or {}
end

local function collectAreasInBounds(mins, maxs, out, seen, pad)
	for _, area in ipairs(getAllNavAreas()) do
		if not IsValid(area) then continue end
		local areaId = area.GetID and area:GetID() or nil
		if not areaId or (seen and seen[areaId]) then continue end
		if pointWithinBounds(area:GetCenter(), mins, maxs, pad or 32) then
			if seen then seen[areaId] = true end
			out[#out + 1] = area
		end
	end
end

local function getAreaById(areaId)
	if not areaId then return nil end
	if navmesh and navmesh.GetNavAreaByID then
		local area = navmesh.GetNavAreaByID(areaId)
		if IsValid(area) then
			return area
		end
	end
	for _, area in ipairs(getAllNavAreas()) do
		if IsValid(area) and area.GetID and area:GetID() == areaId then
			return area
		end
	end
	return nil
end

local function ensureAreaMetaEntry(areaMeta, area)
	if not IsValid(area) then return nil end
	local areaId = area:GetID()
	if not areaMeta[areaId] then
		areaMeta[areaId] = {
			attrs = {},
			place = nil,
			center = area:GetCenter(),
		}
	end
	return areaMeta[areaId]
end

local function addAreaAttr(areaMeta, area, attrName)
	local entry = ensureAreaMetaEntry(areaMeta, area)
	if not entry then return end
	entry.attrs[normalizeAttrName(attrName)] = true
end

local function setAreaPlace(areaMeta, area, placeName)
	local entry = ensureAreaMetaEntry(areaMeta, area)
	if not entry then return end
	entry.place = placeName or entry.place
end

local function getNavAreaMetaTable()
	if FindMetaTable then
		for _, name in ipairs({"CNavArea", "NavArea"}) do
			local meta = FindMetaTable(name)
			if istable(meta) then
				return meta
			end
		end
	end
	if debug and debug.getmetatable then
		for _, area in ipairs(getAllNavAreas()) do
			if IsValid(area) then
				local meta = debug.getmetatable(area)
				if istable(meta) then
					return meta
				end
			end
		end
	end
	return nil
end

function M:InstallNavAreaExtensions()
	if self._navAreaExtensionsInstalled then return end
	local meta = getNavAreaMetaTable()
	if not istable(meta) then return end
	self._navAreaExtensionsInstalled = true

	local originalHasTFAttribute = meta.HasTFAttribute
	if not meta._tfbotOriginalHasTFAttribute then
		meta._tfbotOriginalHasTFAttribute = originalHasTFAttribute
	end
	meta.HasTFAttribute = function(area, attr)
		if isstring(attr) then
			local runtime = TFBotNavGen and TFBotNavGen.Runtime or nil
			local areaId = area.GetID and area:GetID() or nil
			local entry = runtime and runtime.areaMeta and areaId and runtime.areaMeta[areaId] or nil
			if entry and entry.attrs and entry.attrs[normalizeAttrName(attr)] ~= nil then
				return entry.attrs[normalizeAttrName(attr)] == true
			end
		end
		if isfunction(meta._tfbotOriginalHasTFAttribute) then
			local ok, result = pcall(meta._tfbotOriginalHasTFAttribute, area, attr)
			if ok then
				return result
			end
		end
		return false
	end

	local originalGetPlace = meta.GetPlace
	if not meta._tfbotOriginalGetPlace then
		meta._tfbotOriginalGetPlace = originalGetPlace
	end
	meta.GetPlace = function(area)
		if isfunction(meta._tfbotOriginalGetPlace) then
			local ok, result = pcall(meta._tfbotOriginalGetPlace, area)
			if ok and result and result ~= "" then
				return result
			end
		end
		local runtime = TFBotNavGen and TFBotNavGen.Runtime or nil
		local areaId = area.GetID and area:GetID() or nil
		local entry = runtime and runtime.areaMeta and areaId and runtime.areaMeta[areaId] or nil
		return entry and entry.place or ""
	end
end

function M:ApplyAreaMetadata(areaMeta)
	self:SetRuntimeAreaMeta(areaMeta or {})
	self:InstallNavAreaExtensions()

	for areaId, meta in pairs(self:GetAreaMeta()) do
		local area = getAreaById(areaId)
		if not IsValid(area) then continue end
		if meta.place and area.SetPlace then
			pcall(area.SetPlace, area, meta.place)
		end
	end
end

local function collectClassPoints(list, dedupe, className, kind, opts)
	for _, ent in ipairs(ents.FindByClass(className)) do
		local pos = getEntPos(ent)
		if not isvector(pos) then continue end
		addPoint(list, dedupe, kind, pos, {
			team = opts and opts.teamResolver and opts.teamResolver(ent) or getTeamNum(ent),
			classname = className,
			name = ent.GetName and ent:GetName() or nil,
		})
	end
end

function M:CollectObjectivePoints()
	local points = {}
	local dedupe = {}

	collectClassPoints(points, dedupe, "info_player_teamspawn", "spawn", {})
	collectClassPoints(points, dedupe, "info_player_redspawn", "spawn_red", {
		teamResolver = function() return TEAM_RED end,
	})
	collectClassPoints(points, dedupe, "info_player_bluspawn", "spawn_blu", {
		teamResolver = function() return TEAM_BLU end,
	})
	collectClassPoints(points, dedupe, "team_control_point", "control_point", {})
	collectClassPoints(points, dedupe, "tf_team_control_point", "control_point", {})
	collectClassPoints(points, dedupe, "trigger_capture_area", "capture_area", {})
	collectClassPoints(points, dedupe, "func_capturezone", "capture_zone", {})
	collectClassPoints(points, dedupe, "item_teamflag", "flag", {})
	collectClassPoints(points, dedupe, "item_teamflag_mvm", "flag_mvm", {})
	collectClassPoints(points, dedupe, "func_passtime_goal", "passtime_goal", {})
	collectClassPoints(points, dedupe, "info_powerup_spawn", "powerup_spawn", {})
	collectClassPoints(points, dedupe, "bot_hint_sniper_spot", "sniper_spot", {})
	collectClassPoints(points, dedupe, "bot_hint_sentrygun", "sentry_spot", {})
	collectClassPoints(points, dedupe, "bot_hint_teleporter_exit", "tele_exit", {})
	collectClassPoints(points, dedupe, "item_healthkit_small", "health", {})
	collectClassPoints(points, dedupe, "item_healthkit_medium", "health", {})
	collectClassPoints(points, dedupe, "item_healthkit_full", "health", {})
	collectClassPoints(points, dedupe, "item_ammopack_small", "ammo", {})
	collectClassPoints(points, dedupe, "item_ammopack_medium", "ammo", {})
	collectClassPoints(points, dedupe, "item_ammopack_full", "ammo", {})

	local hasPayloadWatchers = #ents.FindByClass("team_train_watcher") > 0
	collectClassPoints(points, dedupe, "team_train_watcher", "payload", {})
	if hasPayloadWatchers then
		collectClassPoints(points, dedupe, "path_track", "payload_path", {})
	end

	return points
end

local placeNames = {
	spawn = "tf_spawn",
	spawn_red = "tf_spawn_red",
	spawn_blu = "tf_spawn_blu",
	control_point = "tf_control_point",
	capture_area = "tf_capture_area",
	capture_zone = "tf_capture_zone",
	flag = "tf_flag",
	flag_mvm = "tf_flag_mvm",
	passtime_goal = "tf_passtime_goal",
	powerup_spawn = "tf_powerup_spawn",
	payload = "tf_payload",
	payload_path = "tf_payload_path",
	sniper_spot = "tf_sniper_spot",
	sentry_spot = "tf_sentry_spot",
	tele_exit = "tf_tele_exit",
	health = "tf_health",
	ammo = "tf_ammo",
}

local placePriority = {
	spawn = 10,
	spawn_red = 15,
	spawn_blu = 15,
	tele_exit = 25,
	sniper_spot = 35,
	sentry_spot = 35,
	payload_path = 50,
	payload = 55,
	flag = 60,
	flag_mvm = 70,
	passtime_goal = 72,
	powerup_spawn = 73,
	capture_area = 75,
	capture_zone = 80,
	control_point = 90,
	health = 18,
	ammo = 18,
}

local hidingFlags = {
	sniper_spot = 4,
	sentry_spot = 2,
	tele_exit = 2,
	control_point = 1,
	capture_area = 1,
	capture_zone = 1,
	flag = 1,
	flag_mvm = 1,
	payload = 1,
	payload_path = 1,
	passtime_goal = 1,
	powerup_spawn = 1,
}

local function getMapMode(points)
	if mapPrefix == "mvm" then return "mvm" end
	if mapPrefix == "ctf" then return "ctf" end
	if mapPrefix == "pl" or mapPrefix == "plr" then return "payload" end
	if mapPrefix == "cp" or mapPrefix == "koth" or mapPrefix == "ad" or mapPrefix == "tc" then
		return "control_point"
	end

	local seen = {}
	for _, point in ipairs(points) do
		seen[point.kind] = true
	end
	if seen.flag_mvm then return "mvm" end
	if seen.payload or seen.payload_path then return "payload" end
	if seen.flag then return "ctf" end
	if seen.control_point or seen.capture_area then return "control_point" end
	return "generic"
end

local function scoreLandmarkForBot(bot, landmark, modeName, mapModeName)
	if not IsValid(bot) or not landmark or not isvector(landmark.pos) then
		return nil
	end

	local teamNum = bot:Team()
	local kind = landmark.kind
	local dist = bot:GetPos():DistToSqr(landmark.pos)
	local score = dist

	if kind == "sniper_spot" then
		local className = string.lower(tostring(bot:GetPlayerClass() or ""))
		score = score * ((className == "sniper" or className == "giantsniper") and 0.45 or 1.40)
	end

	if kind == "sentry_spot" or kind == "tele_exit" then
		local className = string.lower(tostring(bot:GetPlayerClass() or ""))
		score = score * ((className == "engineer" or className == "giantengineer") and 0.45 or 1.65)
	end

	if kind == "spawn" or kind == "spawn_red" or kind == "spawn_blu" then
		score = score * 2.2
	end

	if mapModeName == "payload" and (kind == "payload" or kind == "payload_path") then
		score = score * 0.50
	end
	if mapModeName == "ctf" and (kind == "flag" or kind == "capture_zone") then
		score = score * 0.52
	end
	if mapModeName == "mvm" and (kind == "flag_mvm" or kind == "capture_zone" or kind == "payload_path") then
		score = score * 0.48
	end
	if mapModeName == "control_point" and (kind == "control_point" or kind == "capture_area") then
		score = score * 0.48
	end

	if modeName == "recovery" then
		if kind == "spawn" or kind == "spawn_red" or kind == "spawn_blu" then
			score = score * 0.90
		else
			score = score * 0.72
		end
	elseif modeName == "frontline" then
		if kind == "spawn" or kind == "spawn_red" or kind == "spawn_blu" then
			score = score * 3.0
		end
	end

	if teamNum == TEAM_RED and landmark.team == TEAM_RED and (kind == "spawn_red" or kind == "capture_zone") then
		score = score * 1.15
	end
	if (teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS) and landmark.team == TEAM_BLU and (kind == "spawn_blu" or kind == "capture_zone") then
		score = score * 1.15
	end

	score = score + ((math.abs(bot:EntIndex() * 131 + (landmark.areaId or 0) * 17) % 100) / 1000)
	return score
end

local function inferKindFromPlaceName(placeName)
	local place = string.lower(tostring(placeName or ""))
	if place == "" then return nil end

	if string.find(place, "spawn", 1, true) then
		if string.find(place, "red", 1, true) then return "spawn_red" end
		if string.find(place, "blu", 1, true) or string.find(place, "blue", 1, true) then return "spawn_blu" end
		return "spawn"
	end
	if string.find(place, "intel", 1, true) or string.find(place, "flag", 1, true) then
		if string.find(place, "mvm", 1, true) or mapPrefix == "mvm" then
			return "flag_mvm"
		end
		return "flag"
	end
	if string.find(place, "control", 1, true) or string.find(place, "point", 1, true) or string.find(place, "cap", 1, true) then
		return "control_point"
	end
	if string.find(place, "payload", 1, true) or string.find(place, "cart", 1, true) or string.find(place, "track", 1, true) then
		return "payload_path"
	end
	if string.find(place, "passtime", 1, true) then
		return "passtime_goal"
	end
	if string.find(place, "powerup", 1, true) or string.find(place, "rune", 1, true) then
		return "powerup_spawn"
	end
	if string.find(place, "health", 1, true) or string.find(place, "med", 1, true) then
		return "health"
	end
	if string.find(place, "ammo", 1, true) then
		return "ammo"
	end
	if string.find(place, "sniper", 1, true) or string.find(place, "battlement", 1, true) then
		return "sniper_spot"
	end
	if string.find(place, "sentry", 1, true) or string.find(place, "nest", 1, true) then
		return "sentry_spot"
	end
	if string.find(place, "front", 1, true) or string.find(place, "mid", 1, true) then
		return "capture_area"
	end

	return nil
end

local function appendNativeHidingSpots(out, dedupe, area, kind)
	if not (IsValid(area) and area.GetHidingSpots) then return end
	local wantedType = (kind == "sniper_spot") and 4 or 1
	local ok, spots = pcall(area.GetHidingSpots, area, wantedType)
	if not ok or not istable(spots) then return end
	for _, pos in ipairs(spots) do
		addPoint(out, dedupe, kind, pos, {
			classname = "navmesh",
			name = "native_hiding_spot",
		})
	end
end

function M:CollectNativeNavHints()
	if not (navmesh and navmesh.IsLoaded and navmesh.IsLoaded() and navmesh.GetAllNavAreas) then
		return {}
	end

	local out = {}
	local dedupe = {}
	for _, area in ipairs(navmesh.GetAllNavAreas()) do
		if not IsValid(area) then continue end

		local placeName = area.GetPlace and area:GetPlace() or ""
		local kind = inferKindFromPlaceName(placeName)
		if kind then
			addPoint(out, dedupe, kind, area:GetCenter(), {
				classname = "navmesh",
				name = placeName,
			})
		end

		appendNativeHidingSpots(out, dedupe, area, "sniper_spot")
		appendNativeHidingSpots(out, dedupe, area, "capture_area")
	end

	return out
end

function M:SetRuntimeLandmarks(landmarks, modeName)
	self.Runtime.landmarks = landmarks or {}
	self.Runtime.mapMode = modeName or "generic"
end

function M:SetRuntimeAreaMeta(areaMeta)
	self.Runtime.areaMeta = areaMeta or {}
end

function M:GetLandmarks()
	return self.Runtime.landmarks or {}
end

function M:GetAreaMeta()
	return self.Runtime.areaMeta or {}
end

function M:GetMapMode()
	return self.Runtime.mapMode or "generic"
end

function M:PickLandmarkPosition(bot, modeName)
	if not IsValid(bot) then return nil end
	local landmarks = self:GetLandmarks()
	if #landmarks == 0 then return nil end

	local best, bestScore
	local mode = modeName or "frontline"
	local mapModeName = self:GetMapMode()
	for _, landmark in ipairs(landmarks) do
		local score = scoreLandmarkForBot(bot, landmark, mode, mapModeName)
		if score and (not bestScore or score < bestScore) then
			bestScore = score
			best = landmark
		end
	end

	return best and best.pos or nil
end

local function landmarksToJson(list)
	local out = {}
	for _, landmark in ipairs(list or {}) do
		out[#out + 1] = {
			kind = landmark.kind,
			team = landmark.team,
			areaId = landmark.areaId,
			place = landmark.place,
			pos = {
				x = landmark.pos.x,
				y = landmark.pos.y,
				z = landmark.pos.z,
			},
		}
	end
	return util.TableToJSON(out, true)
end

local function packLandmarks(list)
	local out = {}
	for _, landmark in ipairs(list or {}) do
		out[#out + 1] = {
			kind = landmark.kind,
			team = landmark.team,
			areaId = landmark.areaId,
			place = landmark.place,
			pos = {
				x = landmark.pos.x,
				y = landmark.pos.y,
				z = landmark.pos.z,
			},
		}
	end
	return out
end

local function unpackLandmarks(decoded)
	if not istable(decoded) then return {} end
	local out = {}
	for _, landmark in ipairs(decoded) do
		if not istable(landmark) or not istable(landmark.pos) then continue end
		local pos = Vector(
			tonumber(landmark.pos.x) or 0,
			tonumber(landmark.pos.y) or 0,
			tonumber(landmark.pos.z) or 0
		)
		out[#out + 1] = {
			kind = tostring(landmark.kind or "unknown"),
			team = tonumber(landmark.team),
			areaId = tonumber(landmark.areaId),
			place = isstring(landmark.place) and landmark.place or nil,
			pos = pos,
		}
	end
	return out
end

local function packAreaMeta(areaMeta)
	local out = {}
	for areaId, meta in pairs(areaMeta or {}) do
		if not istable(meta) then continue end
		out[#out + 1] = {
			id = tonumber(areaId),
			place = isstring(meta.place) and meta.place or nil,
			attrs = istable(meta.attrs) and table.GetKeys(meta.attrs) or {},
			center = meta.center and { x = meta.center.x, y = meta.center.y, z = meta.center.z } or nil,
		}
	end
	table.sort(out, function(a, b) return (a.id or 0) < (b.id or 0) end)
	return out
end

local function unpackAreaMeta(list)
	local out = {}
	for _, entry in ipairs(list or {}) do
		if not istable(entry) then continue end
		local areaId = tonumber(entry.id)
		if not areaId then continue end
		local attrs = {}
		for _, attrName in ipairs(entry.attrs or {}) do
			attrs[normalizeAttrName(attrName)] = true
		end
		out[areaId] = {
			place = isstring(entry.place) and entry.place or nil,
			attrs = attrs,
			center = istable(entry.center) and Vector(tonumber(entry.center.x) or 0, tonumber(entry.center.y) or 0, tonumber(entry.center.z) or 0) or nil,
		}
	end
	return out
end

local function serializeNavData(landmarks, areaMeta, modeName)
	return util.TableToJSON({
		version = META_VERSION,
		mapMode = modeName or "generic",
		landmarks = packLandmarks(landmarks),
		areas = packAreaMeta(areaMeta),
	}, true)
end

local function parseNavData(raw)
	local decoded = util.JSONToTable(raw or "")
	if not istable(decoded) then
		return {}, {}, nil
	end

	if decoded[1] then
		return unpackLandmarks(decoded), {}, nil
	end

	local landmarks = unpackLandmarks(decoded.landmarks or {})
	local areaMeta = unpackAreaMeta(decoded.areas or {})
	return landmarks, areaMeta, isstring(decoded.mapMode) and decoded.mapMode or nil
end

function M:GetDataPath()
	return string.format("%s/%s.json", DATA_DIR, string.lower(game.GetMap() or "unknown"))
end

function M:LoadLandmarks()
	local path = self:GetDataPath()
	local landmarks = {}
	local areaMeta = {}
	local modeName = nil
	if not file.Exists(path, "DATA") then
		landmarks = {}
	else
		local raw = file.Read(path, "DATA")
		landmarks, areaMeta, modeName = parseNavData(raw)
	end

	local nativePoints = self:CollectNativeNavHints()
	for _, point in ipairs(nativePoints) do
		landmarks[#landmarks + 1] = {
			kind = point.kind,
			team = point.team,
			areaId = nil,
			place = point.name,
			pos = point.pos,
		}
	end

	self:SetRuntimeLandmarks(landmarks, modeName or getMapMode(#landmarks > 0 and landmarks or nativePoints))
	self:ApplyAreaMetadata(areaMeta)
	return #landmarks > 0
end

function M:SaveLandmarks(landmarks, areaMeta, modeName)
	file.Write(self:GetDataPath(), serializeNavData(landmarks, areaMeta, modeName))
end

local function getSeedPos(pos)
	if not isvector(pos) then return nil end
	local tr = util.TraceLine({
		start = pos + Vector(0, 0, 64),
		endpos = pos - Vector(0, 0, 128),
		mask = MASK_PLAYERSOLID_BRUSHONLY,
	})
	if tr.Hit and isvector(tr.HitPos) then
		return tr.HitPos + Vector(0, 0, 4), isvector(tr.HitNormal) and tr.HitNormal or vectorUp
	end
	return pos + Vector(0, 0, 8), vectorUp
end

function M:PrepareSeeds(points)
	local seeds = {}
	local dedupe = {}
	for _, point in ipairs(points or {}) do
		local seedPos, normal = getSeedPos(point.pos)
		if not isvector(seedPos) then continue end
		local key = table.concat({
			math.Round(seedPos.x / 64),
			math.Round(seedPos.y / 64),
			math.Round(seedPos.z / 64),
		}, "|")
		if dedupe[key] then continue end
		dedupe[key] = true
		seeds[#seeds + 1] = {
			pos = seedPos,
			normal = normal or vectorUp,
		}
	end
	return seeds
end

function M:CollectAreaMetadata(points)
	local areaMeta = {}
	local allAreas = getAllNavAreas()

	local function nearestAreaFor(point)
		local teamNum = point and point.team or TEAM_ANY
		local area = navmesh.GetNearestNavArea(point.pos, true, 1500, true, true, teamNum or TEAM_ANY)
		if not IsValid(area) then
			area = navmesh.GetNearestNavArea(point.pos, true, 1500, true, true)
		end
		return area
	end

	for _, point in ipairs(points or {}) do
		local area = nearestAreaFor(point)
		if not IsValid(area) then continue end

		if point.kind == "control_point" or point.kind == "capture_area" or point.kind == "capture_zone" then
			addAreaAttr(areaMeta, area, "control_point")
		elseif point.kind == "sniper_spot" then
			addAreaAttr(areaMeta, area, "sniper_spot")
		elseif point.kind == "sentry_spot" then
			addAreaAttr(areaMeta, area, "sentry_spot")
		elseif point.kind == "health" then
			addAreaAttr(areaMeta, area, "has_health")
		elseif point.kind == "ammo" then
			addAreaAttr(areaMeta, area, "has_ammo")
		end

		local placeName = placeNames[point.kind]
		if placeName then
			setAreaPlace(areaMeta, area, placeName)
		end
	end

	for _, room in ipairs(ents.FindByClass("func_respawnroom")) do
		if not IsValid(room) then continue end
		local teamNum = getTeamNum(room)
		local attrName = (teamNum == TEAM_RED and "spawn_room_red") or ((teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS) and "spawn_room_blue") or nil
		if not attrName then continue end

		local mins, maxs = getWorldAABB(room)
		if not (isvector(mins) and isvector(maxs)) then continue end

		local roomAreas = {}
		local seen = {}
		collectAreasInBounds(mins, maxs, roomAreas, seen, 40)

		for _, area in ipairs(roomAreas) do
			addAreaAttr(areaMeta, area, attrName)
			setAreaPlace(areaMeta, area, teamNum == TEAM_RED and "tf_spawn_red" or "tf_spawn_blu")
		end

		for _, area in ipairs(roomAreas) do
			if not area.GetAdjacentAreas then continue end
			local ok, adjacent = pcall(area.GetAdjacentAreas, area)
			if not ok or not istable(adjacent) then continue end
			for _, adjArea in ipairs(adjacent) do
				if not IsValid(adjArea) then continue end
				local adjId = adjArea:GetID()
				local adjMeta = areaMeta[adjId]
				if adjMeta and adjMeta.attrs and adjMeta.attrs[attrName] then continue end
				addAreaAttr(areaMeta, adjArea, "spawn_room_exit")
			end
		end
	end

	for _, cpTriggerClass in ipairs({"trigger_capture_area", "func_capturezone", "func_passtime_goal"}) do
		for _, ent in ipairs(ents.FindByClass(cpTriggerClass)) do
			if not IsValid(ent) then continue end
			local mins, maxs = getWorldAABB(ent)
			if not (isvector(mins) and isvector(maxs)) then continue end
			local found = {}
			local seen = {}
			collectAreasInBounds(mins, maxs, found, seen, 32)
			for _, area in ipairs(found) do
				if cpTriggerClass ~= "func_passtime_goal" then
					addAreaAttr(areaMeta, area, "control_point")
				end
				local placeName = placeNames[cpTriggerClass == "func_passtime_goal" and "passtime_goal" or "capture_zone"]
				if placeName then
					setAreaPlace(areaMeta, area, placeName)
				end
			end
		end
	end

	for _, area in ipairs(allAreas) do
		if not IsValid(area) then continue end
		local placeName = area.GetPlace and area:GetPlace() or ""
		local inferred = inferKindFromPlaceName(placeName)
		if inferred == "control_point" then
			addAreaAttr(areaMeta, area, "control_point")
		elseif inferred == "sniper_spot" then
			addAreaAttr(areaMeta, area, "sniper_spot")
		elseif inferred == "sentry_spot" then
			addAreaAttr(areaMeta, area, "sentry_spot")
		end
		if isstring(placeName) and placeName ~= "" then
			setAreaPlace(areaMeta, area, placeName)
		end
	end

	return areaMeta
end

function M:Finalize(invoker)
	local points = self:CollectObjectivePoints()
	local areaMeta = self:CollectAreaMetadata(points)
	local perArea = {}
	local landmarks = {}

	for _, point in ipairs(points) do
		local area = navmesh.GetNearestNavArea(point.pos, true, 1500, true, true, point.team or TEAM_ANY)
		if not IsValid(area) then
			area = navmesh.GetNearestNavArea(point.pos, true, 1500, true, true)
		end
		if not IsValid(area) then continue end

		local areaId = area:GetID()
		local current = perArea[areaId]
		local newPriority = placePriority[point.kind] or 0
		if not current or newPriority >= current.priority then
			local placeName = placeNames[point.kind]
			if placeName and area.SetPlace then
				pcall(area.SetPlace, area, placeName)
			end
			perArea[areaId] = {
				priority = newPriority,
				place = placeName,
			}
		end

		local flags = hidingFlags[point.kind]
		if flags and area.AddHidingSpot then
			pcall(area.AddHidingSpot, area, point.pos, flags)
		end

		landmarks[#landmarks + 1] = {
			kind = point.kind,
			team = point.team,
			areaId = areaId,
			place = perArea[areaId] and perArea[areaId].place or nil,
			pos = area:GetCenter(),
		}
	end

	self:SetRuntimeLandmarks(landmarks, getMapMode(points))
	self:ApplyAreaMetadata(areaMeta)
	self:SaveLandmarks(landmarks, areaMeta, self:GetMapMode())

	if navmesh.Save then
		pcall(navmesh.Save)
	end

	self.Runtime.active = false
	timer.Remove(POLL_TIMER)
	notify(invoker, string.format("nav generation finished. saved %d landmarks and %d annotated nav areas for %s.", #landmarks, table.Count(areaMeta), game.GetMap()))
end

function M:Start(invoker)
	if not hasNavmesh() then
		notify(invoker, "navmesh API is not available in this branch.")
		return
	end
	if navmesh.IsGenerating and navmesh.IsGenerating() then
		notify(invoker, "nav generation is already running.")
		return
	end

	local points = self:CollectObjectivePoints()
	local seeds = self:PrepareSeeds(points)
	if #seeds == 0 then
		notify(invoker, "no TF objective seeds were found on this map.")
		return
	end

	if navmesh.ClearWalkableSeeds then
		pcall(navmesh.ClearWalkableSeeds)
	end
	if navmesh.SetPlayerSpawnName then
		pcall(navmesh.SetPlayerSpawnName, "info_player_teamspawn")
	end

	for _, seed in ipairs(seeds) do
		pcall(navmesh.AddWalkableSeed, seed.pos, seed.normal)
	end

	self.Runtime.active = true
	notify(invoker, string.format("starting nav generation with %d TF seeds.", #seeds))
	local ok, err = pcall(navmesh.BeginGeneration)
	if not ok then
		self.Runtime.active = false
		notify(invoker, "nav generation failed to start: " .. tostring(err))
		return
	end

	timer.Create(POLL_TIMER, 2, 0, function()
		if not self.Runtime.active then
			timer.Remove(POLL_TIMER)
			return
		end
		if navmesh.IsGenerating and navmesh.IsGenerating() then
			return
		end
		self:Finalize(invoker)
	end)
end

hook.Add("InitPostEntity", "TFBotNavGen_LoadLandmarks", function()
	timer.Simple(0, function()
		M:LoadLandmarks()
	end)
end)

hook.Add("PostCleanupMap", "TFBotNavGen_ReloadLandmarks", function()
	timer.Simple(0, function()
		M:LoadLandmarks()
	end)
end)

concommand.Add("tf_bot_nav_generate", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end
	M:Start(ply)
end, nil, "Generate a TF-aware navmesh and landmark set for player bots.")

concommand.Add("tf_bot_nav_landmarks_reload", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end
	local ok = M:LoadLandmarks()
	notify(ply, ok and string.format("reloaded %d landmarks and %d annotated nav areas.", #M:GetLandmarks(), table.Count(M:GetAreaMeta())) or "no stored landmarks were found for this map.")
end, nil, "Reload stored TF bot nav landmarks for the current map.")

_G.TFBot_GetNavLandmarks = function()
	return M:GetLandmarks()
end

_G.TFBot_GetNavAreaMeta = function()
	return M:GetAreaMeta()
end

_G.TFBot_PickNavLandmarkPosition = function(bot, modeName)
	return M:PickLandmarkPosition(bot, modeName)
end

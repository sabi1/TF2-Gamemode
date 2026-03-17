if CLIENT then return end

TFBotNavGen = TFBotNavGen or {}
local M = TFBotNavGen

local DATA_DIR = "tf/nav_landmarks"
local POLL_TIMER = "TFBotNavGen_Poll"
local vectorUp = Vector(0, 0, 1)
local mapPrefix = string.lower((game.GetMap() or ""):match("^([a-z0-9]+)_") or "")

file.CreateDir("tf")
file.CreateDir(DATA_DIR)

M.Runtime = M.Runtime or {
	active = false,
	landmarks = {},
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
	collectClassPoints(points, dedupe, "bot_hint_sniper_spot", "sniper_spot", {})
	collectClassPoints(points, dedupe, "bot_hint_sentrygun", "sentry_spot", {})
	collectClassPoints(points, dedupe, "bot_hint_teleporter_exit", "tele_exit", {})

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
	payload = "tf_payload",
	payload_path = "tf_payload_path",
	sniper_spot = "tf_sniper_spot",
	sentry_spot = "tf_sentry_spot",
	tele_exit = "tf_tele_exit",
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
	capture_area = 75,
	capture_zone = 80,
	control_point = 90,
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

function M:GetLandmarks()
	return self.Runtime.landmarks or {}
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

local function landmarksFromJson(raw)
	local decoded = util.JSONToTable(raw or "")
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

function M:GetDataPath()
	return string.format("%s/%s.json", DATA_DIR, string.lower(game.GetMap() or "unknown"))
end

function M:LoadLandmarks()
	local path = self:GetDataPath()
	local landmarks = {}
	if not file.Exists(path, "DATA") then
		landmarks = {}
	else
		local raw = file.Read(path, "DATA")
		landmarks = landmarksFromJson(raw)
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

	self:SetRuntimeLandmarks(landmarks, getMapMode(#landmarks > 0 and landmarks or nativePoints))
	return #landmarks > 0
end

function M:SaveLandmarks(landmarks)
	file.Write(self:GetDataPath(), landmarksToJson(landmarks))
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

function M:Finalize(invoker)
	local points = self:CollectObjectivePoints()
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
	self:SaveLandmarks(landmarks)

	if navmesh.Save then
		pcall(navmesh.Save)
	end

	self.Runtime.active = false
	timer.Remove(POLL_TIMER)
	notify(invoker, string.format("nav generation finished. saved %d landmarks for %s.", #landmarks, game.GetMap()))
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
	notify(ply, ok and string.format("reloaded %d landmarks.", #M:GetLandmarks()) or "no stored landmarks were found for this map.")
end, nil, "Reload stored TF bot nav landmarks for the current map.")

_G.TFBot_GetNavLandmarks = function()
	return M:GetLandmarks()
end

_G.TFBot_PickNavLandmarkPosition = function(bot, modeName)
	return M:PickLandmarkPosition(bot, modeName)
end

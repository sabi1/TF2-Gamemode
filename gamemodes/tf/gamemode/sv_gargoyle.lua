	local allowedtaunts = {
"1",
"2",
"3",
}
local ENT_ID_CURRENT = 1
local tf_ragdoll_gravity_boost = CreateConVar("tf_ragdoll_gravity_boost", "220", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Additional downward velocity for all player ragdolls.")
local tf_ragdoll_gravity_ticks = CreateConVar("tf_ragdoll_gravity_ticks", "12", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How many boost ticks are applied to each ragdoll.")
local tf_ragdoll_gravity_tick_interval = CreateConVar("tf_ragdoll_gravity_tick_interval", "0.05", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Delay between ragdoll gravity boost ticks.")
local TFIsHalloweenMapCached = false

local HALLOWEEN_MAP_HINTS = {
	"_event",
	"halloween",
	"hell",
	"haunt",
	"ghost",
	"mann_manor",
	"eyeaduct",
	"merasmus",
	"soul",
}

local NON_HALLOWEEN_EVENT_HINTS = {
	"xmas",
	"smissmas",
	"winter",
	"snow",
	"christmas",
}

local function IsHalloweenMapName(mapName)
	if not mapName or mapName == "" then return false end
	mapName = string.lower(mapName)

	for _, token in ipairs(HALLOWEEN_MAP_HINTS) do
		if string.find(mapName, token, 1, true) then
			for _, blocked in ipairs(NON_HALLOWEEN_EVENT_HINTS) do
				if string.find(mapName, blocked, 1, true) then
					return false
				end
			end
			return true
		end
	end

	return false
end

local function RefreshHalloweenMapCache()
	TFIsHalloweenMapCached = IsHalloweenMapName(game.GetMap())
end

hook.Add("InitPostEntity", "TF_HalloweenMapCache_Init", RefreshHalloweenMapCache)
hook.Add("PostCleanupMap", "TF_HalloweenMapCache_Cleanup", RefreshHalloweenMapCache)
timer.Simple(0, RefreshHalloweenMapCache)

local function SpawnDeathDrop(victim, dmginfo, className)
	local item = ents.Create(className)
	if not IsValid(item) then return end

	local a, b = victim:WorldSpaceAABB()
	item:SetPos((a + b) * 0.5)
	item.RespawnTime = -1
	item:Spawn()

	if dmginfo then
		local vel = dmginfo:GetDamageForce()
		local ang = vel:Angle()
		ang.p = math.min(ang.p, -20)
		vel = math.min(0.01 * vel:Length(), 400) * ang:Forward()
		item:DropWithGravity(vel)
	end
end

local function ResolveSoulCollector(victim, attacker)
	if not IsValid(attacker) then return nil end

	if attacker:IsWeapon() then
		attacker = attacker:GetOwner()
	end

	if IsValid(attacker) and attacker:IsVehicle() and IsValid(attacker:GetDriver()) then
		attacker = attacker:GetDriver()
	end

	if IsValid(attacker) and not attacker:IsPlayer() and attacker.GetOwner then
		local owner = attacker:GetOwner()
		if IsValid(owner) then
			attacker = owner
		end
	end

	if not IsValid(attacker) then return nil end
	if IsValid(victim) and attacker == victim then return nil end
	if not attacker:IsPlayer() then return nil end
	if attacker.IsTFPlayer and not attacker:IsTFPlayer() then return nil end

	return attacker
end

local function AwardHalloweenSoulToPlayer(collector, origin)
	if not IsValid(collector) or not collector:IsPlayer() then return false end
	if collector.IsTFPlayer and not collector:IsTFPlayer() then return false end

	net.Start("TF_HalloweenSoulBurst")
	net.WriteEntity(collector)
	net.WriteVector(origin or collector:GetPos())
	net.Broadcast()

	collector:EmitSound("Halloween.spell_pickup", 70, 125)
	collector:EmitSound("Halloween.spell_pickup_rare", 68, 128)
	collector:EmitSound("player/souls_receive" .. math.random(1, 3) .. ".wav", 75, math.random(98, 105), 1, CHAN_STATIC)
	collector:SetNWInt("HalloweenSouls", collector:GetNWInt("HalloweenSouls", 0) + 1)

	return true
end

local function AwardHalloweenSoulFromDeath(victim, attacker)
	if not TFIsHalloweenMapCached then return end

	local collector = ResolveSoulCollector(victim, attacker)
	if not IsValid(collector) then return end

	local origin = collector:GetPos()
	if IsValid(victim) and victim.WorldSpaceAABB then
		local a, b = victim:WorldSpaceAABB()
		origin = (a + b) * 0.5
	end

	AwardHalloweenSoulToPlayer(collector, origin)
end

local tf_halloween_map_gargoyle_enable = CreateConVar("tf_halloween_map_gargoyle_enable", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable random Soul Gargoyle map spawns on Halloween maps.")
local tf_halloween_map_gargoyle_min_time = CreateConVar("tf_halloween_map_gargoyle_min_time", "50", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Minimum seconds before the next random Soul Gargoyle spawn/move.")
local tf_halloween_map_gargoyle_max_time = CreateConVar("tf_halloween_map_gargoyle_max_time", "120", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Maximum seconds before the next random Soul Gargoyle spawn/move.")
local tf_halloween_map_gargoyle_lifetime = CreateConVar("tf_halloween_map_gargoyle_lifetime", "600", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Seconds a random Soul Gargoyle stays before disappearing.")
local tf_halloween_gargoyle_require_nav = CreateConVar("tf_halloween_gargoyle_require_nav", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Require Soul Gargoyle spawn positions to be near nav areas when navmesh is loaded.")
local tf_halloween_gargoyle_min_player_dist = CreateConVar("tf_halloween_gargoyle_min_player_dist", "220", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Minimum distance from alive players for random Soul Gargoyle positions.")
local tf_halloween_gargoyle_max_player_dist = CreateConVar("tf_halloween_gargoyle_max_player_dist", "1800", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Maximum distance from alive players for random Soul Gargoyle positions.")
local tf_halloween_gargoyle_debug = CreateConVar("tf_halloween_gargoyle_debug", "0", {FCVAR_ARCHIVE}, "Print Soul Gargoyle spawn rejection reasons.")

local TFActiveMapGargoyle = nil
local TFNextMapGargoyleAction = 0
local TFNextMapGargoyleTrackUpdate = 0

local function UpdateMapGargoyleTracking(ent)
	local active = IsValid(ent)
	local pos = active and ent:GetPos() or vector_origin

	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:IsPlayer() then
			ply:SetNWBool("TFHasMapGargoyle", active)
			ply:SetNWVector("TFMapGargoylePos", pos)
		end
	end
end

local function GetRandomGargoyleDelay()
	local minDelay = math.max(tf_halloween_map_gargoyle_min_time:GetFloat(), 5)
	local maxDelay = math.max(tf_halloween_map_gargoyle_max_time:GetFloat(), minDelay)
	return math.Rand(minDelay, maxDelay)
end

local function QueueNextGargoyleAction()
	TFNextMapGargoyleAction = CurTime() + GetRandomGargoyleDelay()
end

local function AnnounceGargoyleMessage(eventName, message, voice, spooky)
	net.Start("TF_HalloweenGargoyleNotify")
	net.WriteString(eventName or "")
	net.WriteString(message or "")
	net.WriteString(voice or "")
	net.WriteString(spooky or "")
	net.Broadcast()
end

function GM:AnnounceHalloweenGargoyle(eventName, overrideMessage)
	if not TFIsHalloweenMapCached then return end

	local voice = "sf15.Merasmus.Gargoyle.Spawn"
	local spooky = "ui/halloween_loot_spawn.wav"
	local message = overrideMessage or "A gargoyle is somewhere on the map!"

	if eventName == "moved" then
		voice = "sf15.Merasmus.Gargoyle.Moved"
		spooky = "ui/halloween_loot_spawn.wav"
		message = overrideMessage or "The Soul Gargoyle moved to a new location!"
	elseif eventName == "got" then
		voice = "sf15.Merasmus.Gargoyle.Got"
		spooky = "ui/halloween_loot_found.wav"
		message = overrideMessage or "Someone found the Soul Gargoyle!"
	elseif eventName == "gone" then
		voice = "sf15.Merasmus.Gargoyle.Gone"
		spooky = "ui/halloween_loot_found.wav"
		message = overrideMessage or "The Soul Gargoyle has disappeared."
	end

	AnnounceGargoyleMessage(eventName, message, voice, spooky)
end

local function BuildGargoyleSpawnPointList()
	local points = {}
	local classes = {
		"info_player_teamspawn",
		"info_player_start",
		"info_player_deathmatch",
		"info_observer_point",
	}

	for _, className in ipairs(classes) do
		for _, ent in ipairs(ents.FindByClass(className)) do
			if IsValid(ent) then
				points[#points + 1] = ent:GetPos()
			end
		end
	end

	if #points == 0 then
		for _, pl in ipairs(player.GetAll()) do
			if IsValid(pl) and pl:IsPlayer() and pl:Alive() then
				points[#points + 1] = pl:GetPos() + VectorRand() * math.Rand(200, 500)
			end
		end
	end

	return points
end

local function BuildGargoyleTeamSpawnPointList()
	local points = {}
	local classes = {
		"info_player_teamspawn",
		"info_player_start",
		"info_player_deathmatch",
	}

	for _, className in ipairs(classes) do
		for _, ent in ipairs(ents.FindByClass(className)) do
			if IsValid(ent) then
				points[#points + 1] = ent:GetPos()
			end
		end
	end

	return points
end

local function GargoyleDebug(msg)
	if not tf_halloween_gargoyle_debug:GetBool() then return end
	print("[TF2-Gamemode] [GargoyleSpawn] " .. tostring(msg))
end

local function GetAlivePlayers()
	local alivePlayers = {}
	for _, pl in ipairs(player.GetAll()) do
		if IsValid(pl) and pl:IsPlayer() and pl:Alive() then
			alivePlayers[#alivePlayers + 1] = pl
		end
	end
	return alivePlayers
end

local function BuildRespawnVolumeCache()
	local volumes = {}
	for _, className in ipairs({"func_respawnroomvisualizer", "func_respawnroom"}) do
		for _, room in ipairs(ents.FindByClass(className)) do
			if IsValid(room) then
				local mins, maxs = room:WorldSpaceAABB()
				volumes[#volumes + 1] = {
					mins = mins,
					maxs = maxs,
				}
			end
		end
	end
	return volumes
end

local function IsInsideRespawnVolumes(pos, volumes)
	volumes = volumes or BuildRespawnVolumeCache()
	for _, volume in ipairs(volumes) do
		local mins, maxs = volume.mins, volume.maxs
		if pos.x >= mins.x and pos.x <= maxs.x
		and pos.y >= mins.y and pos.y <= maxs.y
		and pos.z >= mins.z and pos.z <= maxs.z then
			return true
		end
	end
	return false
end

local function ProjectToGround(basePos)
	if not basePos then return nil end

	local tr = util.TraceLine({
		start = basePos + Vector(0, 0, 768),
		endpos = basePos - Vector(0, 0, 4096),
		mask = MASK_PLAYERSOLID_BRUSHONLY
	})

	if not tr.Hit then
		return nil
	end

	return tr.HitPos + Vector(0, 0, 12), tr
end

local function DistanceToNearestAlivePlayer(pos, alivePlayers)
	local nearest = math.huge
	for _, pl in ipairs(alivePlayers) do
		local d = pl:GetPos():Distance(pos)
		if d < nearest then
			nearest = d
		end
	end
	return nearest
end

local function NavDistanceAtPos(pos)
	if not navmesh or not navmesh.IsLoaded or not navmesh.GetNearestNavArea then return nil end
	if not navmesh.IsLoaded() then return nil end

	local ok, area = pcall(navmesh.GetNearestNavArea, pos, false, 2500, false, true)
	if not ok or not area then return math.huge end
	if not area.GetCenter then return 0 end

	local center = area:GetCenter()
	if not center then return 0 end
	return center:Distance(pos)
end

local function IsPlayableCandidate(pos, alivePlayers, volumes)
	if not pos then return false end
	if not util.IsInWorld(pos) then
		GargoyleDebug("reject: out of world")
		return false
	end

	if IsInsideRespawnVolumes(pos, volumes) then
		GargoyleDebug("reject: inside respawn volume")
		return false
	end

	local floor = util.TraceLine({
		start = pos + Vector(0, 0, 20),
		endpos = pos - Vector(0, 0, 80),
		mask = MASK_PLAYERSOLID_BRUSHONLY
	})

	if not floor.Hit then
		GargoyleDebug("reject: no floor hit")
		return false
	end

	if floor.HitNormal and floor.HitNormal.z < 0.6 then
		GargoyleDebug("reject: slope too steep")
		return false
	end

	local hull = util.TraceHull({
		start = pos + Vector(0, 0, 2),
		endpos = pos + Vector(0, 0, 2),
		mins = Vector(-16, -16, 0),
		maxs = Vector(16, 16, 72),
		mask = MASK_PLAYERSOLID_BRUSHONLY
	})
	if hull.Hit then
		GargoyleDebug("reject: hull blocked")
		return false
	end

	local headroom = util.TraceHull({
		start = pos + Vector(0, 0, 72),
		endpos = pos + Vector(0, 0, 80),
		mins = Vector(-14, -14, 0),
		maxs = Vector(14, 14, 8),
		mask = MASK_PLAYERSOLID_BRUSHONLY
	})
	if headroom.Hit then
		GargoyleDebug("reject: no headroom")
		return false
	end

	if tf_halloween_gargoyle_require_nav:GetBool() then
		local navDist = NavDistanceAtPos(pos)
		if navDist and navDist == math.huge then
			GargoyleDebug("reject: no nearby nav")
			return false
		end
		if navDist and navDist > 450 then
			GargoyleDebug("reject: nav too far")
			return false
		end
	end

	if not alivePlayers or #alivePlayers == 0 then
		GargoyleDebug("reject: no alive players")
		return false
	end

	local minDist = math.max(tf_halloween_gargoyle_min_player_dist:GetFloat(), 0)
	local maxDist = math.max(tf_halloween_gargoyle_max_player_dist:GetFloat(), minDist + 1)
	local nearest = DistanceToNearestAlivePlayer(pos, alivePlayers)
	if nearest < minDist then
		GargoyleDebug("reject: too close to player")
		return false
	end
	if nearest > maxDist then
		GargoyleDebug("reject: too far from players")
		return false
	end

	return true
end

local function TryFindValidCandidate(basePos, alivePlayers, volumes)
	local candidate = ProjectToGround(basePos)
	if not candidate then
		GargoyleDebug("reject: project-to-ground failed")
		return nil
	end

	if IsPlayableCandidate(candidate, alivePlayers, volumes) then
		return candidate
	end

	return nil
end

local function GetRandomGargoylePosFromPlayerFront(alivePlayers, volumes)
	if not alivePlayers or #alivePlayers == 0 then return nil end

	for _ = 1, 24 do
		local pl = table.Random(alivePlayers)
		if IsValid(pl) then
			local basePos = pl:GetPos() + pl:GetForward() * math.Rand(140, 420)
			local candidate = TryFindValidCandidate(basePos, alivePlayers, volumes)
			if candidate then
				return candidate
			end
		end
	end

	return nil
end

local function GetNearestValidTeamSpawnPos(alivePlayers, volumes)
	local spawnPoints = BuildGargoyleTeamSpawnPointList()
	if #spawnPoints == 0 then return nil end
	if not alivePlayers or #alivePlayers == 0 then return nil end

	table.sort(spawnPoints, function(a, b)
		return DistanceToNearestAlivePlayer(a, alivePlayers) < DistanceToNearestAlivePlayer(b, alivePlayers)
	end)

	for _, point in ipairs(spawnPoints) do
		local candidate = TryFindValidCandidate(point, alivePlayers, volumes)
		if candidate then
			return candidate
		end
	end

	return nil
end

local function FindNearbyValidPos(origin, alivePlayers, volumes)
	local direct = TryFindValidCandidate(origin, alivePlayers, volumes)
	if direct then return direct end

	local radii = {96, 144, 200, 280, 360}
	for _, radius in ipairs(radii) do
		for i = 1, 16 do
			local ang = (i / 16) * math.pi * 2
			local offset = Vector(math.cos(ang) * radius, math.sin(ang) * radius, 0)
			local candidate = TryFindValidCandidate(origin + offset, alivePlayers, volumes)
			if candidate then
				return candidate
			end
		end
	end

	return nil
end

local function GetRandomGargoylePos()
	local points = BuildGargoyleSpawnPointList()
	if #points == 0 then return nil end

	local alivePlayers = GetAlivePlayers()
	local volumes = BuildRespawnVolumeCache()

	for _ = 1, 80 do
		local basePos
		if #alivePlayers > 0 and math.random() < 0.65 then
			local pl = table.Random(alivePlayers)
			local ang = math.Rand(0, math.pi * 2)
			local dist = math.Rand(220, 700)
			basePos = pl:GetPos() + Vector(math.cos(ang) * dist, math.sin(ang) * dist, 0)
		else
			basePos = table.Random(points)
		end

		if basePos then
			local candidate = TryFindValidCandidate(basePos, alivePlayers, volumes)
			if candidate then
				return candidate
			end
		end
	end

	local fallbackFront = GetRandomGargoylePosFromPlayerFront(alivePlayers, volumes)
	if fallbackFront then
		GargoyleDebug("fallback: player-front")
		return fallbackFront
	end

	local fallbackSpawn = GetNearestValidTeamSpawnPos(alivePlayers, volumes)
	if fallbackSpawn then
		GargoyleDebug("fallback: teamspawn")
		return fallbackSpawn
	end

	GargoyleDebug("no valid random gargoyle position found this cycle")
	return nil
end

local function SpawnOrMoveMapGargoyle()
	if not TFIsHalloweenMapCached then return end
	if not tf_halloween_map_gargoyle_enable:GetBool() then return end

	local pos = GetRandomGargoylePos()
	if not pos then
		QueueNextGargoyleAction()
		return
	end

	local lifetime = math.max(tf_halloween_map_gargoyle_lifetime:GetFloat(), 8)

	if IsValid(TFActiveMapGargoyle) then
		TFActiveMapGargoyle:SetPos(pos)
		TFActiveMapGargoyle:SetAngles(Angle(0, math.random(0, 359), 0))
		TFActiveMapGargoyle.MapGargoyleExpires = CurTime() + lifetime
		UpdateMapGargoyleTracking(TFActiveMapGargoyle)
		GAMEMODE:AnnounceHalloweenGargoyle("moved", "A gargoyle is somewhere on the map!")
		QueueNextGargoyleAction()
		return
	end

	local garg = ents.Create("item_halloween_soul")
	if not IsValid(garg) then
		QueueNextGargoyleAction()
		return
	end

	garg:SetPos(pos)
	garg:SetAngles(Angle(0, math.random(0, 359), 0))
	garg.RespawnTime = -1
	garg.MapGargoyle = true
	garg.MapGargoyleExpires = CurTime() + lifetime
	garg:Spawn()

	TFActiveMapGargoyle = garg
	TFNextMapGargoyleTrackUpdate = 0
	UpdateMapGargoyleTracking(garg)
	GAMEMODE:AnnounceHalloweenGargoyle("spawn", "A gargoyle is somewhere on the map!")
	QueueNextGargoyleAction()
end

hook.Add("EntityRemoved", "TF_HalloweenMapGargoyleRemoved", function(ent)
	if ent ~= TFActiveMapGargoyle then return end
	TFActiveMapGargoyle = nil
	UpdateMapGargoyleTracking(nil)
	if not ent.GargoyleCollected and TFIsHalloweenMapCached and tf_halloween_map_gargoyle_enable:GetBool() then
		GAMEMODE:AnnounceHalloweenGargoyle("gone")
	end
	QueueNextGargoyleAction()
end)

local function ResetHalloweenMapGargoyleState()
	if IsValid(TFActiveMapGargoyle) then
		TFActiveMapGargoyle:Remove()
	end
	TFActiveMapGargoyle = nil
	UpdateMapGargoyleTracking(nil)
	QueueNextGargoyleAction()
end

hook.Add("InitPostEntity", "TF_HalloweenMapGargoyleInit", ResetHalloweenMapGargoyleState)
hook.Add("PostCleanupMap", "TF_HalloweenMapGargoyleCleanup", ResetHalloweenMapGargoyleState)

hook.Add("Think", "TF_HalloweenMapGargoyleThink", function()
	if not TFIsHalloweenMapCached then return end
	if not tf_halloween_map_gargoyle_enable:GetBool() then return end

	if IsValid(TFActiveMapGargoyle) then
		if TFActiveMapGargoyle.MapGargoyleExpires and CurTime() >= TFActiveMapGargoyle.MapGargoyleExpires then
			TFActiveMapGargoyle:Remove()
			return
		end

		if CurTime() >= TFNextMapGargoyleTrackUpdate then
			TFNextMapGargoyleTrackUpdate = CurTime() + 0.5
			UpdateMapGargoyleTracking(TFActiveMapGargoyle)
		end
		return
	end

	if TFNextMapGargoyleAction <= CurTime() then
		SpawnOrMoveMapGargoyle()
	end
end)

concommand.Add("tf_halloween_gargoyle_bring", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end
	if not TFIsHalloweenMapCached then return end

	local targetPos
	if IsValid(ply) and ply:IsPlayer() then
		targetPos = ply:GetPos() + ply:GetForward() * 140 + Vector(0, 0, 12)
	elseif #player.GetHumans() > 0 then
		local hp = player.GetHumans()[1]
		targetPos = hp:GetPos() + hp:GetForward() * 140 + Vector(0, 0, 12)
	end
	if not targetPos then return end

	local alivePlayers = GetAlivePlayers()
	local volumes = BuildRespawnVolumeCache()
	local safePos = FindNearbyValidPos(targetPos, alivePlayers, volumes)
	if not safePos then
		GargoyleDebug("admin bring: no valid nearby position")
		return
	end

	if IsValid(TFActiveMapGargoyle) then
		TFActiveMapGargoyle:SetPos(safePos)
		UpdateMapGargoyleTracking(TFActiveMapGargoyle)
		GAMEMODE:AnnounceHalloweenGargoyle("moved", "A gargoyle is somewhere on the map!")
	else
		local garg = ents.Create("item_halloween_soul")
		if not IsValid(garg) then return end
		garg:SetPos(safePos)
		garg:SetAngles(Angle(0, math.random(0, 359), 0))
		garg.RespawnTime = -1
		garg.MapGargoyle = true
		garg.MapGargoyleExpires = CurTime() + math.max(tf_halloween_map_gargoyle_lifetime:GetFloat(), 8)
		garg:Spawn()
		TFActiveMapGargoyle = garg
		UpdateMapGargoyleTracking(garg)
		GAMEMODE:AnnounceHalloweenGargoyle("spawn", "A gargoyle is somewhere on the map!")
	end

	QueueNextGargoyleAction()
end)

concommand.Add("tf_halloween_gargoyle_marker", function(ply, _, args)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:IsAdmin() then return end

	local enable = nil
	if args and args[1] ~= nil then
		enable = tonumber(args[1]) == 1
	end

	local newValue = (enable ~= nil) and enable or (not ply:GetNWBool("TFShowGargoyleLocator", false))
	ply:SetNWBool("TFShowGargoyleLocator", newValue)

	if newValue then
		ply:PrintMessage(HUD_PRINTTALK, "[TF2-Gamemode] Gargoyle marker enabled.")
	else
		ply:PrintMessage(HUD_PRINTTALK, "[TF2-Gamemode] Gargoyle marker disabled.")
	end
end)

local function ApplyRagdollGravityBoost(ragdoll)
	if not IsValid(ragdoll) then return end
	if ragdoll._tfGravityBoostApplied then return end

	local boost = math.max(tf_ragdoll_gravity_boost:GetFloat(), 0)
	if boost <= 0 then return end
	local ticks = math.max(math.floor(tf_ragdoll_gravity_ticks:GetInt()), 1)
	local interval = math.max(tf_ragdoll_gravity_tick_interval:GetFloat(), 0.01)

	ragdoll._tfGravityBoostApplied = true

	-- Keep this as a scale hint for engines that respect entity gravity on ragdolls.
	ragdoll:SetGravity(1.35)

	for step = 0, ticks - 1 do
		timer.Simple(step * interval, function()
			if not IsValid(ragdoll) then return end
			local down = Vector(0, 0, -boost)
			ragdoll:SetVelocity(down)
			for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
				local phys = ragdoll:GetPhysicsObjectNum(i)
				if IsValid(phys) then
					phys:AddVelocity(down)
				end
			end
		end)
	end
end

hook.Add("OnEntityCreated", "TF_DeathNoticeEntityID", function(ent)
	if IsValid(ent) then
		ent.DeathNoticeEntityID = ENT_ID_CURRENT
		ENT_ID_CURRENT = ENT_ID_CURRENT + 1
		if ENT_ID_CURRENT >= 16384 then
			ENT_ID_CURRENT = 1
		end
	end
end)

hook.Add("CreateEntityRagdoll", "TF_GlobalRagdollGravityBoost", function(ply, ragdoll)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	ApplyRagdollGravityBoost(ragdoll)
end)

hook.Add("PostPlayerDeath", "TF_GlobalRagdollGravityBoostFallback", function(ply)
	if not IsValid(ply) then return end
	timer.Simple(0, function()
		if not IsValid(ply) then return end
		ApplyRagdollGravityBoost(ply:GetRagdollEntity())
	end)
	timer.Simple(0.1, function()
		if not IsValid(ply) then return end
		ApplyRagdollGravityBoost(ply:GetRagdollEntity())
	end)
end)

function lookForNearestPlayer(bot)
	local npcs = {}
		for k,v in ipairs(ents.FindInSphere(bot:GetPos(), 2048)) do
			if ((v:IsTFPlayer()) and v:Health() > 1 and !v:IsFriendly(bot) and v:GetNoDraw() == false and v:EntIndex() != bot:EntIndex() and !v:IsFlagSet(FL_NOTARGET)) then
				table.insert(npcs, v)
			end
		end
		return table.Random(npcs)
end

function GM:DoTFPlayerDeath(ent, attacker, dmginfo)
	if not IsValid(attacker) then return end
	
	local inflictor = (dmginfo and dmginfo:GetInflictor()) or game.GetWorld()
	
	local shouldgib = false
	if (IsValid(ent.ShovedAnimation)) then
		ent.ShovedAnimation:Remove()
		ent:SetNoDraw(false)
	end
	for k,v in ipairs(player.GetAll()) do
		if (v.TargetEnt == ent) then
			v.TargetEnt = nil
		end
		if (v:GetObserverTarget() == ent) then
			timer.Simple(2.0, function()
				if (v:GetObserverTarget() == ent) then
					v:ConCommand("tf_spectate")
				end
			end)
		end
	end
	if (dmginfo and dmginfo:IsDamageType(DMG_DISSOLVE)) then
		ent:EmitSound("TFPlayer.Dissolve")
	end
	if (attacker:EntIndex() != ent:EntIndex()) then
		if (attacker:GetClass() == "npc_headcrab") then
			if (string.find(ent:GetModel(),"combine") and (IsMounted("episodic") or IsMounted("ep2"))) then
			
				local zombie = ents.Create("npc_zombine")
				zombie:SetPos(ent:GetPos())
				zombie:SetAngles(ent:GetAngles())
				zombie:SetKeyValue( "spawnflags", "646" )
				zombie:Spawn()
				zombie:Activate()
							
				local zombie_name = "sleeping_zomb" .. zombie:EntIndex()
				local seq = zombie_name .. "_wake_seq"

				zombie:SetName( zombie_name )
				zombie:Fire( "AddOutput", "OnDamaged " .. seq .. ":BeginSequence::0:1", 0 )
				zombie:Fire( "AddOutput", "OnHearPlayer " .. seq .. ":BeginSequence::0:1", 0 )
				
				local slumptype = "a"
				local waking_sequence = ents.Create( "scripted_sequence" )
				waking_sequence:SetName( seq )
				waking_sequence:SetKeyValue( "spawnflags", "624" )
				waking_sequence:SetKeyValue( "m_fMoveTo", "4" ) -- tp to start of sequence
				waking_sequence:SetKeyValue( "m_iszEntity", zombie_name )
				waking_sequence:SetKeyValue( "m_iszIdle", "slump_"..slumptype )
				waking_sequence:SetKeyValue( "m_iszPlay", "slumprise_"..slumptype )

				waking_sequence:SetPos( zombie:GetPos() )
				waking_sequence:Spawn()
				waking_sequence:Activate()
				waking_sequence:SetParent( zombie )

				timer.Simple( 0, function()
					waking_sequence:SetAngles( zombie:GetAngles() )
				end )


			else
				local zombie = ents.Create("npc_zombie")
				zombie:SetPos(ent:GetPos())
				zombie:SetAngles(ent:GetAngles())
				zombie:SetKeyValue( "spawnflags", "646" )
				zombie:Spawn()
				zombie:Activate()
				local zombie_name = "sleeping_zomb" .. zombie:EntIndex()
				local seq = zombie_name .. "_wake_seq"

				zombie:SetName( zombie_name )
				zombie:Fire( "AddOutput", "OnDamaged " .. seq .. ":BeginSequence::0:1", 0 )
				zombie:Fire( "AddOutput", "OnHearPlayer " .. seq .. ":BeginSequence::0:1", 0 )
				
				local slumptype = "a"
				local waking_sequence = ents.Create( "scripted_sequence" )
				waking_sequence:SetName( seq )
				waking_sequence:SetKeyValue( "spawnflags", "624" )
				waking_sequence:SetKeyValue( "m_fMoveTo", "4" ) -- tp to start of sequence
				waking_sequence:SetKeyValue( "m_iszEntity", zombie_name )
				waking_sequence:SetKeyValue( "m_iszIdle", "slump_"..slumptype )
				waking_sequence:SetKeyValue( "m_iszPlay", "slumprise_"..slumptype )

				waking_sequence:SetPos( zombie:GetPos() )
				waking_sequence:Spawn()
				waking_sequence:Activate()
				waking_sequence:SetParent( zombie )

				timer.Simple( 0, function()
					waking_sequence:SetAngles( zombie:GetAngles() )
				end )
			end
		elseif (attacker:GetClass() == "monster_headcrab") then
			local zombie = ents.Create("monster_zombie")
			zombie:SetPos(ent:GetPos())
			zombie:SetAngles(ent:GetAngles())
			zombie:Spawn()
			zombie:Activate()
		elseif (attacker:GetClass() == "npc_headcrab_fast") then
			local zombie = ents.Create("npc_fastzombie")
			zombie:SetPos(ent:GetPos())
			zombie:SetAngles(ent:GetAngles())
			zombie:SetKeyValue( "spawnflags", "646" )
			zombie:Spawn()
			zombie:Activate()
				
			local zombie_name = "sleeping_zomb" .. zombie:EntIndex()
			local seq = zombie_name .. "_wake_seq"

			zombie:SetName( zombie_name )
			zombie:Fire( "AddOutput", "OnDamaged " .. seq .. ":BeginSequence::0:1", 0 )
			zombie:Fire( "AddOutput", "OnHearPlayer " .. seq .. ":BeginSequence::0:1", 0 )
			
			local slumptype = table.Random({"a","b"})
			local waking_sequence = ents.Create( "scripted_sequence" )
			waking_sequence:SetName( seq )
			waking_sequence:SetKeyValue( "spawnflags", "624" )
			waking_sequence:SetKeyValue( "m_fMoveTo", "4" ) -- tp to start of sequence
			waking_sequence:SetKeyValue( "m_iszEntity", zombie_name )
			waking_sequence:SetKeyValue( "m_iszIdle", "slump_"..slumptype )
			waking_sequence:SetKeyValue( "m_iszPlay", "slumprise_"..slumptype )

			waking_sequence:SetPos( zombie:GetPos() )
			waking_sequence:Spawn()
			waking_sequence:Activate()
			waking_sequence:SetParent( zombie )

			timer.Simple( 0, function()
				waking_sequence:SetAngles( zombie:GetAngles() )
			end )
			
		elseif (attacker:GetClass() == "npc_headcrab_black" or attacker:GetClass() == "npc_headcrab_poison") then
			local zombie = ents.Create("npc_poisonzombie")
			zombie:SetPos(ent:GetPos())
			zombie:SetAngles(ent:GetAngles())
			zombie:SetKeyValue( "spawnflags", "646" )
			zombie:Spawn()
			zombie:Activate()
			local zombie_name = "sleeping_zomb" .. zombie:EntIndex()
			local seq = zombie_name .. "_wake_seq"

			zombie:SetName( zombie_name )
			zombie:Fire( "AddOutput", "OnDamaged " .. seq .. ":BeginSequence::0:1", 0 )
			zombie:Fire( "AddOutput", "OnHearPlayer " .. seq .. ":BeginSequence::0:1", 0 )
			
			local slumptype = "a"
			local waking_sequence = ents.Create( "scripted_sequence" )
			waking_sequence:SetName( seq )
			waking_sequence:SetKeyValue( "spawnflags", "624" )
			waking_sequence:SetKeyValue( "m_fMoveTo", "4" ) -- tp to start of sequence
			waking_sequence:SetKeyValue( "m_iszEntity", zombie_name )
			waking_sequence:SetKeyValue( "m_iszIdle", "slump_a" )
			waking_sequence:SetKeyValue( "m_iszPlay", "slumprise_a" )

			waking_sequence:SetPos( zombie:GetPos() )
			waking_sequence:Spawn()
			waking_sequence:Activate()
			waking_sequence:SetParent( zombie )

			timer.Simple( 0, function()
				waking_sequence:SetAngles( zombie:GetAngles() )
			end )
		end
	end
	if (attacker.TFBot) then
		attacker.botPos = nil
	end
	ent:StopSound("Weapon_Minifun.Fire")
	ent:StopSound("Weapon_Minigun.Fire")
	ent:StopSound("Weapon_Tomislav.ShootLoop")
	ent:StopSound("Weapon_Minifun.FireCrit")
	ent:StopSound("Weapon_Minigun.FireCrit")
	ent:StopSound("Weapon_Tomislav.FireCrit")
	if ent:IsNPC() and dmginfo and dmginfo:IsDamageType(DMG_BLAST) then
		umsg.Start("GibNPC")
			umsg.Entity(ent)
			umsg.Short(ent.DeathFlags)
		umsg.End()
		for _,v in pairs(ents.FindByClass("class C_ClientRagdoll")) do
			v:Fire("Kill", "", 0.1)
		end
	end

	if ent:IsPlayer() and ent:HasDeathFlag(DF_DECAP) then
		umsg.Start("GibPlayerHead")
			umsg.Entity(ent)
			umsg.Short(ent.DeathFlags)
		umsg.End()
	end
	if ent:IsPlayer() and ent:GetPlayerClass() == "l4d_zombie" then
		ent:EmitSound("vj_l4d_com/death/male/death_"..math.random(40,49)..".wav")
	end
	
	for k,v in ipairs(ents.FindByName("Spyragdoll"..ent:EntIndex())) do
		v:Fire("Kill", "", 0.1)
	end

	-- Remove all player states
	ent:SetPlayerState(0, true)
	if (ent:IsPlayer()) then
		if ent:GetNWBool("Taunting") == true then ent:SetNWBool("Taunting", false) ent:Freeze(false) ent:ConCommand("tf_firstperson") end
		if ent:GetNWBool("Bonked") == true then ent:SetNWBool("Bonked", false) ent:Freeze(false) ent:ConCommand("tf_firstperson") end
		ent:StopSound("Weapon_General.CritPower")
	end
	attacker.customdeath = ""
	local InflictorClass = gamemode.Call("GetInflictorClass", ent, attacker, inflictor)
	if (IsValid(InflictorClass)) then
		if string.find(InflictorClass, "headshot") then
			attacker.customdeath = "headshot"
			ent:SetNWBool("DeathByHeadshot", true)
		elseif string.find(InflictorClass, "backstab") then
			attacker.customdeath = "backstab"
			ent:SetNWBool("DeathByBackstab", true)
		end
	end

	
	if inflictor and inflictor.OnPlayerKilled then
		inflictor:OnPlayerKilled(ent)
	end
	
	ApplyAttributesFromEntity(inflictor, "on_kill", ent, inflictor, attacker)
	if attacker:IsPlayer() then
		ApplyGlobalAttributesFromPlayer(attacker, "on_kill", ent, inflictor, attacker)
	end
	
	self:ExtinguishEntity(ent)
	self:RemoveDamageCooperationsOnDeath(ent)
	
	if ent:IsPlayer() then
		ent:AddDeaths(1)
		ent:SetNWBool("Incapped", false)
	end
	
	if attacker:IsWeapon() then
		attacker = attacker:GetOwner()
	end
	
	if attacker:IsVehicle() and IsValid(attacker:GetDriver()) then
		attacker = attacker:GetDriver()
	end
	
	if attacker:IsPlayer() and attacker ~= ent then
		local score = inflictor.Score or 1
		if attacker.customdeath == "headshot" then
			attacker:AddHeadshots(1)
			score = score + (inflictor.HeadshotScore or 0.5)
		end
		if attacker.customdeath == "backstab" then
			attacker:AddBackstabs(1)
			score = score + 1
		end
		
		attacker:AddFrags(score * ent:GetScoreMultiplier())
		
		if ent:IsBuilding() then
			attacker:AddDestructions(1)
		else
			attacker:AddKills(1)
		end
	end
	
	local assistants = self:GetAllAssistants(ent, attacker)
	for a,v in pairs(assistants) do
		if a:IsPlayer() then
			a:AddAssists(1)
			a:AddFrags(0.5 * ent:GetScoreMultiplier())
			
			ApplyGlobalAttributesFromPlayer(a, "on_kill", ent, inflictor, attacker)
		end
		
		if v
			and isentity(v)
			and v.inflictor and
			v.inflictor:IsBuilding()
			and v.inflictor.AddAssists then
			v.inflictor:AddAssists(1)
		end
	end
	
	--[[
	--print(ent)
	--print("Global assist table")
	PrintTable(attacker.GlobalAssistants or {})
	--print("Assist table")
	PrintTable(ent.DamageCooperations or {})
	--print("Assistants")
	PrintTable(assistants)
	]]
	
	ent.KillerDominationInfo = 0
	
	if not ent.KillComboCounter then
		ent.KillComboCounter = {}
	end
	
	if not attacker.KillComboCounter then
		attacker.KillComboCounter = {}
	end
	
	ent.KillComboCounter[attacker] = 0
	attacker.KillComboCounter[ent] = (attacker.KillComboCounter[ent] or 0) + 1
	
	for a,_ in pairs(assistants) do
		if not a.KillComboCounter then
			a.KillComboCounter = {}
		end
		
		ent.KillComboCounter[a] = 0
		a.KillComboCounter[ent] = (a.KillComboCounter[ent] or 0) + 1
	end
	
	if attacker.KillComboCounter[ent] >= 4 then
		if self:PlayerIsNemesis(attacker, ent) then
			ent.KillerDominationInfo = 2 -- nemesis
		else
			self:TriggerDomination(ent, attacker)
			ent.KillerDominationInfo = 1 -- new nemesis
		end
	end
	
	for a,_ in pairs(assistants) do
		if a.KillComboCounter[ent] >= 4 then
			self:TriggerDomination(ent, a)
		end
	end
	
	if self:PlayerIsNemesis(ent, attacker) then
		self:TriggerRevenge(ent, attacker)
		ent.KillerDominationInfo = 3 -- revenge
	end
	
	for a,_ in pairs(assistants) do
		if self:PlayerIsNemesis(ent, a) then
			self:TriggerRevenge(ent, a)
		end
	end
	
	-- Voice responses
	if attacker:IsPlayer() and ent~=attacker then
		if ent:IsBuilding() then
			attacker:Speak("TLK_KILLED_OBJECT",false)
		else
			--self:AddKill(attacker)
			attacker.victimclass = ent.playerclass or ""
			attacker:Speak("TLK_KILLED_PLAYER",false)
		end
	end
	attacker.domination = ""
end

function GM:PostTFPlayerDeath(ent, attacker, inflictor)
	if GAMEMODE:EntityTeam(attacker) == TEAM_HIDDEN then
		return
	end
	ent.MarkedForDeath = false
	if IsValid(inflictor) and attacker == inflictor and inflictor:IsPlayer() then
		inflictor = inflictor:GetActiveWeapon()
		if not IsValid(inflictor) then inflictor = attacker end
	end
	
	local cooperator = self:GetDisplayedAssistant(ent, attacker) or NULL
	----print("Displayed assistant")
	----print(cooperator)

	if attacker:IsWeapon() then
		attacker = attacker:GetOwner()
	end
	
	if attacker:IsVehicle() and IsValid(attacker:GetDriver()) then
		attacker = attacker:GetDriver()
	end
	
	local killer = attacker
	
	--[[if inflictor.KillCreditAsInflictor then
		killer = inflictor
	end]]
	
	-- X fell to a clumsy, painful death
	if (attacker:IsTFPlayer()) then
		if ent.LastDamageInfo and ent.LastDamageInfo:IsFallDamage() then
			umsg.Start("Notice_EntityFell")
				umsg.String(GAMEMODE:EntityDeathnoticeName(ent))
				umsg.Short(GAMEMODE:EntityTeam(ent))
				umsg.Short(GAMEMODE:EntityID(ent))
			umsg.End()
		elseif attacker == ent then
			-- Suicide
			if IsValid(cooperator) and GAMEMODE:EntityTeam(cooperator)~=TEAM_HIDDEN then
				-- Y finished off X
				umsg.Start("Notice_EntityFinishedOffEntity")
					umsg.String(GAMEMODE:EntityDeathnoticeName(ent))
					umsg.Short(GAMEMODE:EntityTeam(ent))
					umsg.Short(GAMEMODE:EntityID(ent))
					
					umsg.String(GAMEMODE:EntityDeathnoticeName(cooperator))
					umsg.Short(GAMEMODE:EntityTeam(cooperator))
					umsg.Short(GAMEMODE:EntityID(cooperator))
				umsg.End()
			elseif attacker==inflictor then
				-- X bid farewell, cruel world!
				umsg.Start("Notice_EntitySuicided")
					umsg.String(GAMEMODE:EntityDeathnoticeName(ent))
					umsg.Short(GAMEMODE:EntityTeam(ent))
					umsg.Short(GAMEMODE:EntityID(ent))
				umsg.End()
			elseif (!ent.LastDamageInfo or (ent.LastDamageInfo and !ent.LastDamageInfo:IsFallDamage())) then
				local InflictorClass = gamemode.Call("GetInflictorClass", ent, attacker, inflictor)
				
				-- <killicon> X
				umsg.Start("Notice_EntityKilledEntity")
					umsg.String(GAMEMODE:EntityDeathnoticeName(ent))
					umsg.Short(GAMEMODE:EntityTeam(ent))
					umsg.Short(GAMEMODE:EntityID(ent))
					
					umsg.String(InflictorClass)
					
					umsg.String(GAMEMODE:EntityDeathnoticeName(ent))
					umsg.Short(GAMEMODE:EntityTeam(ent))
					umsg.Short(GAMEMODE:EntityID(ent))
					
					umsg.String(GAMEMODE:EntityDeathnoticeName(cooperator))
					umsg.Short(GAMEMODE:EntityTeam(cooperator))
					umsg.Short(GAMEMODE:EntityID(cooperator))
					
					umsg.Bool(ent.LastDamageWasCrit)
				umsg.End()
			end
		elseif (!ent.LastDamageInfo or (ent.LastDamageInfo and !ent.LastDamageInfo:IsFallDamage())) then
			local InflictorClass = gamemode.Call("GetInflictorClass", ent, attacker, inflictor)
			
			-- Y <killicon> X
			umsg.Start("Notice_EntityKilledEntity") 
				umsg.String(GAMEMODE:EntityDeathnoticeName(ent))
				umsg.Short(GAMEMODE:EntityTeam(ent)) 
				umsg.Short(GAMEMODE:EntityID(ent))
				
				umsg.String(InflictorClass)
				
				umsg.String(GAMEMODE:EntityDeathnoticeName(killer))
				umsg.Short(GAMEMODE:EntityTeam(killer))
				umsg.Short(GAMEMODE:EntityID(killer))
				
				umsg.String(GAMEMODE:EntityDeathnoticeName(cooperator))
				umsg.Short(GAMEMODE:EntityTeam(cooperator))
				umsg.Short(GAMEMODE:EntityID(cooperator))
				
				umsg.Bool(ent.LastDamageWasCrit)
			umsg.End()
		end
	end
	
	if ent.PendingNemesises then
		for _,v in ipairs(ent.PendingNemesises) do
			if IsValid(v) then
				umsg.Start("Notice_EntityDominatedEntity")
					umsg.String(GAMEMODE:EntityDeathnoticeName(ent))
					umsg.Short(GAMEMODE:EntityTeam(ent))
					umsg.Short(GAMEMODE:EntityID(ent))
					
					umsg.String(GAMEMODE:EntityDeathnoticeName(v))
					umsg.Short(GAMEMODE:EntityTeam(v))
					umsg.Short(GAMEMODE:EntityID(v))
				umsg.End()
				umsg.Start("PlayerDomination")
					umsg.Entity(ent)
					umsg.Entity(v)
				umsg.End()
			end
		end
		ent.PendingNemesises = nil
	end
	
	if ent.PendingRevenges then
		for _,v in ipairs(ent.PendingRevenges) do
			if IsValid(v) then
				umsg.Start("Notice_EntityRevengeEntity")
					umsg.String(GAMEMODE:EntityDeathnoticeName(ent))
					umsg.Short(GAMEMODE:EntityTeam(ent))
					umsg.Short(GAMEMODE:EntityID(ent))
					
					umsg.String(GAMEMODE:EntityDeathnoticeName(v))
					umsg.Short(GAMEMODE:EntityTeam(v))
					umsg.Short(GAMEMODE:EntityID(v))
				umsg.End()
				
				umsg.Start("PlayerRevenge")
					umsg.Entity(ent)
					umsg.Entity(v)
				umsg.End()
			end
		end
		ent.PendingRevenges = nil
	end
	
	ent.LastDamageWasCrit = false
end

function GM:OnTFPlayerDominated(ent, attacker)
	if attacker:IsPlayer() then
		attacker:AddDominations(1)
	end
	
	if not ent.PendingNemesises then
		ent.PendingNemesises = {}
	end
	table.insert(ent.PendingNemesises, attacker)
end

function GM:OnTFPlayerRevenge(ent, attacker)
	if attacker:IsPlayer() then
		attacker:AddRevenges(1)
		attacker:AddFrags(1)
	end
	
	if not ent.PendingRevenges then
		ent.PendingRevenges = {}
	end
	table.insert(ent.PendingRevenges, attacker)
end

local player_gib_probability = CreateConVar("player_gib_probability", 0.33)

local function TransferBones( base, ragdoll ) -- Transfers the bones of one entity to a ragdoll's physics bones (modified version of some of RobotBoy655's code)
	if !IsValid( base ) or !IsValid( ragdoll ) then return end
	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local bone = ragdoll:GetPhysicsObjectNum( i )
		if ( IsValid( bone ) ) then
			local pos, ang = base:GetBonePosition( ragdoll:TranslatePhysBoneToBone( i ) )
			if ( pos ) then bone:SetPos( pos ) end
			if ( ang ) then bone:SetAngles( ang ) end
		end
	end
end

local function SetEntityStuff( ent1, ent2 ) -- Transfer most of the set things on entity 2 to entity 1
	if !IsValid( ent1 ) or !IsValid( ent2 ) then return false end
	ent1:SetModel( ent2:GetModel() )
	ent1:SetPos( ent2:GetPos() )
	ent1:SetAngles( ent2:GetAngles() )
	ent1:SetColor( ent2:GetColor() )
	ent1:SetSkin( ent2:GetSkin() )
	ent1:SetFlexScale( ent2:GetFlexScale() )
	for i = 0, ent2:GetNumBodyGroups() - 1 do ent1:SetBodygroup( i, ent2:GetBodygroup( i ) ) end
	for i = 0, ent2:GetFlexNum() - 1 do ent1:SetFlexWeight( i, ent2:GetFlexWeight( i ) ) end
	for i = 0, ent2:GetBoneCount() do
		ent1:ManipulateBoneScale( i, ent2:GetManipulateBoneScale( i ) )
		ent1:ManipulateBoneAngles( i, ent2:GetManipulateBoneAngles( i ) )
		ent1:ManipulateBonePosition( i, ent2:GetManipulateBonePosition( i ) )
		ent1:ManipulateBoneJiggle( i, ent2:GetManipulateBoneJiggle( i ) )
	end
end

local function IsMvMMap()
	local map = string.lower(game.GetMap() or "")
	return string.find(map, "mvm_", 1, true) ~= nil
end

local function IsMvMRobotLike(ply)
	if not IsValid(ply) then return false end
	if not IsMvMMap() then return false end
	if ply:IsBot() then return true end
	return string.find(string.lower(ply:GetModel() or ""), "/bot_", 1, true) ~= nil
end

local function IsMiniBossLike(ply)
	if not IsValid(ply) then return false end
	return ply:IsMiniBoss() or ply:GetModelScale() > 1.0 or string.find(string.lower(ply:GetModel() or ""), "_boss.mdl", 1, true) ~= nil
end

local function ShouldGibLikeTF2(ply, dmginfo, inflictor, isBlastKill)
	if not IsValid(ply) or not dmginfo then return false end
	if ply:HasDeathFlag(DF_GIB) then return true end
	if dmginfo:IsDamageType(DMG_ALWAYSGIB) then return true end
	if not isBlastKill then return false end

	if IsMvMRobotLike(ply) and not IsMiniBossLike(ply) then
		return false
	end

	local p = math.Clamp(player_gib_probability:GetFloat(), 0, 1)
	return math.Rand(0, 1) <= p
end


function GM:DoPlayerDeath(ply, attacker, dmginfo)
	local shouldgib = false
	local inflictor = dmginfo:GetInflictor()
	local isBlastKill = dmginfo:IsDamageType(DMG_BLAST) or dmginfo:IsExplosionDamage() or (IsValid(inflictor) and inflictor.Explosive)
	local shouldGibLikeTF2 = ShouldGibLikeTF2(ply, dmginfo, inflictor, isBlastKill)

	if isBlastKill and not shouldGibLikeTF2 then
		local force = dmginfo:GetDamageForce()
		force.x = force.x * 2.5
		force.y = force.y * 2.5
		force.z = force.z * 2.0
		dmginfo:SetDamageForce(force)
	end
	for k,v in ipairs(player.GetBots()) do
		if (v.TFBot) then
			if (IsValid(v.TargetEnt)) then
				if (v.TargetEnt:EntIndex() == ply:EntIndex()) then
					v.TargetEnt = nil
				end
			end
		end
	end
	timer.Simple(0.2, function()
	
		for k,v in ipairs(player.GetAll()) do
			if (v.TargetEnt == ply) then
				v.TargetEnt = nil
			end
		end

	end)
	ply:SetNWBool("Taunting",false)
	--timer.Simple(0.02, function()
		--ply:SetMoveType(MOVETYPE_NONE)
		--ply:SetPos(ply:GetPos() - Vector(0,0,30))
	--end)
	ply:SetNWFloat("m_flDeathTime",CurTime())
	ply.LastDamageInfo = CopyDamageInfo(dmginfo)
	if (attacker.TFBot) then
		attacker.TargetEnt = lookForNearestPlayer(attacker)
	end
	if (string.find(ply:GetModel(),"/bot_")) then
		ParticleEffect("bot_death",ply:GetPos(),ply:GetAngles(),nil)
	end 
	
	if (attacker.TFBot and string.find(attacker:GetModel(),"/bot_")) then
		for k,v in ipairs(ents.GetAll()) do
			if (v.Bot ~= nil and v.Bot:EntIndex() == attacker:EntIndex()) then
				v:CustomOnKillEnemy(attacker)
			end
		end
	end
	net.Start("DeActivateTauntCamImmediate")
	net.Send(ply)
	ply.TargetEnt = nil
	if (IsValid(ply.ControllingPlayer)) then
		if (ply.ControllingPlayer.WasTFBot) then
			ply.ControllingPlayer.WasTFBot = false
			ply.ControllingPlayer.TFBot = true
		end
		ply.ControllingPlayer.BeingControlled = false
		ply.ControllingPlayer.BeingControlledBy = nil
		ply.ControllingPlayer = nil
	end
	if (string.find(dmginfo:GetAttacker():GetClass(),"tf_weapon")) then
		dmginfo:SetAttacker(dmginfo:GetAttacker().Owner)
	end
	local date = os.date("%b",os.time())
	if (ply ~= attacker) then
		if (date == "Dec") then
			SpawnDeathDrop(ply, dmginfo, "item_ammopack_gift")
		--[[elseif (date == "Oct") then
			local item = ents.Create("item_ammopack_gift")
			local a, b = ply:WorldSpaceAABB()
			item:SetPos((a+b) * 0.5)
			
			item.RespawnTime = -1
			item:Spawn()
			
			if dmginfo then
				local vel = dmginfo:GetDamageForce()
				local ang = vel:Angle()
				ang.p = math.min(ang.p, -20)
				vel = math.min(0.01 * vel:Length(), 400) * ang:Forward()
				item:DropWithGravity(vel)
			end]]
		end

		if TFIsHalloweenMapCached then
			AwardHalloweenSoulFromDeath(ply, attacker)
		end
	end
	timer.Simple(0.02, function()
	
		if (IsValid(ply.ShovedAnimation)) then
			ply.ShovedAnimation:Remove()
			ply:SetNoDraw(false)
		end

	end)
	if (!GetConVar("tf_use_client_ragdolls"):GetBool()) then
		if (ply:Team() == TEAM_YELLOW or ply:Team() == TEAM_GREEN) then
			if (!ply:IsHL2() and !ply:IsL4D()) then
				ply:SetModel(string.Replace(ply:GetModel(),"/player/","/lkskin/hwm/"))
			end
		end
		if (!ply:IsL4D() and !ply:IsHL2() and (!isBlastKill or string.find(ply:GetModel(),"bot_")) and !shouldGibLikeTF2 and ply:GetPlayerClass() != "boomer" && ply:GetPlayerClass() != "tank_l4d" and !(string.find(ply:GetModel(),"bot_") and string.find(ply:GetModel(),"_boss") or ply:GetModelScale() > 1.0)) then
			timer.Simple(0.02, function()
				if ply:GetRagdollEntity():IsValid() then
					ply:GetRagdollEntity():Remove()
				end
			end)
			local ragdoll = ents.Create("prop_ragdoll")
			ragdoll:SetModel(ply:GetModel())
			ragdoll:SetPos(ply:GetPos())
			ragdoll:SetAngles(ply:GetAngles())
			ragdoll:Spawn()
			ragdoll:Activate()
			ragdoll:SetSkin(ply:GetSkin())
			--ragdoll:SetBodyGroups(ply:GetBodyGroups())
			--ragdoll:SetOwner(ply)
			if (!GetConVar("ai_serverragdolls"):GetBool()) then
				ragdoll:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			end
			if (ply:HasDeathFlag(DF_FIRE) or ply:IsOnFire() or dmginfo:IsDamageType(DMG_BURN)) then
				GAMEMODE:IgniteEntity(ragdoll, ragdoll, ragdoll, 10)
			end
			TransferBones(ply,ragdoll)
			ply.RagdollEntity = ragdoll
			if (ply:HasDeathFlag(DF_DECAP)) then
				ragdoll:EmitSound("TFPlayer.Decapitated")
				local b1 = ragdoll:LookupBone("bip_head")
				local b2 = ragdoll:LookupBone("bip_neck")
				local b3 = ragdoll:LookupBone("prp_helmet")
				local b4 = ragdoll:LookupBone("jaw_bone")
			
				local m1 = ragdoll:GetBoneMatrix(b1)
				local m2 = ragdoll:GetBoneMatrix(b2)
				ragdoll:ManipulateBoneScale(b1, Vector(0,0,0))
				ragdoll:ManipulateBoneScale(b2, Vector(0,0,0))	
				if ragdoll:GetModel() == "models/player/engineer.mdl" then
					ragdoll:ManipulateBoneScale(b3, Vector(0,0,0))
				end
			end
			if (!GetConVar("ai_serverragdolls"):GetBool()) then
				ragdoll:Fire("FadeAndRemove","",math.random(5,30))
			end
			local phys = ragdoll:GetPhysicsObject()
			if (IsValid(phys)) then
				phys:AddVelocity(ply:GetVelocity() * 8 + dmginfo:GetDamageForce())
			end
			if (dmginfo:IsDamageType(DMG_DISSOLVE)) then
				timer.Simple(0.15, function()
					local dissolver = ents.Create( "env_entity_dissolver" )
					dissolver:SetPos( ragdoll:LocalToWorld(ragdoll:OBBCenter()) )
					dissolver:SetKeyValue( "dissolvetype", 0 )
					dissolver:Spawn()
					dissolver:Activate()
					local name = "Dissolving_"..math.random()
					ragdoll:SetName( name )
					dissolver:Fire( "Dissolve", name, 0 )
					dissolver:Fire( "Kill", name, 0.10 )
				end)
			end
		elseif ((ply:IsL4D() or ply:IsHL2()) and ply:GetPlayerClass() != "boomer" && ply:GetPlayerClass() != "tank_l4d") then
			timer.Simple(0.1, function()
				if ply:GetRagdollEntity():IsValid() then
					ply:GetRagdollEntity():Remove()
				end
			end)
			local ragdoll = ents.Create("prop_ragdoll")
			ragdoll:SetModel(ply:GetModel())
			ragdoll:SetPos(ply:GetPos())
			ragdoll:SetAngles(ply:GetAngles())
			ragdoll:Spawn()
			ragdoll:Activate()
			
			ragdoll:SetSkin(ply:GetSkin())
			--ragdoll:SetBodyGroups(ply:GetBodyGroups())
			--ragdoll:SetOwner(ply)
			if (!GetConVar("ai_serverragdolls"):GetBool()) then
				ragdoll:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			end
			if (ply:HasDeathFlag(DF_FIRE) or ply:IsOnFire() or dmginfo:IsDamageType(DMG_BURN)) then
				ragdoll:Ignite(30,70)
			end
			TransferBones(ply,ragdoll)
			ply.RagdollEntity = ragdoll
			if (!GetConVar("ai_serverragdolls"):GetBool()) then
				ragdoll:Fire("FadeAndRemove","",math.random(5,30))
			end
			local phys = ragdoll:GetPhysicsObject()
			if (IsValid(phys)) then
				phys:AddVelocity(ply:GetVelocity() * 8 + dmginfo:GetDamageForce() * 8)
			end
			if (dmginfo:IsDamageType(DMG_DISSOLVE)) then
				timer.Simple(0.15, function()
					local dissolver = ents.Create( "env_entity_dissolver" )
					dissolver:SetPos( ragdoll:LocalToWorld(ragdoll:OBBCenter()) )
					dissolver:SetKeyValue( "dissolvetype", 0 )
					dissolver:Spawn()
					dissolver:Activate()
					local name = "Dissolving_"..math.random()
					ragdoll:SetName( name )
					dissolver:Fire( "Dissolve", name, 0 )
					dissolver:Fire( "Kill", name, 0.10 )
				end)
			end
		elseif (ply:GetPlayerClass() == "tank_l4d") then
			
			if ply:GetPlayerClass() == "tank_l4d" then
				
				if (dmginfo:IsDamageType(DMG_DISSOLVE)) then
					timer.Simple(0.1, function()
						if ply:GetRagdollEntity():IsValid() then
							ply:GetRagdollEntity():Remove()
						end
					end)
					local ragdoll = ents.Create("prop_ragdoll")
					ragdoll:SetModel(ply:GetModel())
					ragdoll:SetPos(ply:GetPos())
					ragdoll:SetAngles(ply:GetAngles())
					ragdoll:Spawn()
					ragdoll:Activate()
					if (!GetConVar("ai_serverragdolls"):GetBool()) then
						ragdoll:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
					end
					if (ply:HasDeathFlag(DF_FIRE) or ply:IsOnFire() or dmginfo:IsDamageType(DMG_BURN)) then
						ragdoll:Ignite(30,70)
					end
					TransferBones(ply,ragdoll)
					ply.RagdollEntity = ragdoll
					ragdoll:Fire("FadeAndRemove","",math.random(5,30))
					local phys = ragdoll:GetPhysicsObject()
					if (IsValid(phys)) then
						phys:AddVelocity(ply:GetVelocity() * 8 + dmginfo:GetDamageForce() * 8)
					end
					timer.Simple(0.15, function()
						local dissolver = ents.Create( "env_entity_dissolver" )
						dissolver:SetPos( ragdoll:LocalToWorld(ragdoll:OBBCenter()) )
						dissolver:SetKeyValue( "dissolvetype", 0 )
						dissolver:Spawn()
						dissolver:Activate()
						local name = "Dissolving_"..math.random()
						ragdoll:SetName( name )
						dissolver:Fire( "Dissolve", name, 0 )
						dissolver:Fire( "Kill", name, 0.10 )
					end)
					return
				else
					timer.Simple(0.1, function()
						if ply:GetRagdollEntity():IsValid() then
							ply:GetRagdollEntity():Remove()
						end
					end)
					local animent = ents.Create( 'base_nextbot' )
					animent:SetSkin(ply:GetSkin())
					animent:SetPos(ply:GetPos())
					animent:SetAngles(ply:GetAngles())
					animent:Spawn()
					animent:SetHealth(4000)
					animent:SetModel(ply:GetModel())
					animent:SetVelocity(ply:GetVelocity())
					animent:Activate()
					animent:AddFlags(FL_GODMODE) -- The entity used for the death animation	
					ply.RagdollEntity = animent
					animent:SetCollisionGroup( COLLISION_GROUP_PLAYER )
					animent:SetOwner( ply )
					local seq = "Death"
					if (ply:KeyDown(IN_FORWARD)) then
						seq = "Death_Running_07"
					end
					animent:StartActivity( animent:GetSequenceActivity(animent:LookupSequence(seq)) )
					animent:MoveToPos(ply:GetEyeTrace().HitPos)
					animent:SetPlaybackRate( 1 )
					if (ply:HasDeathFlag(DF_FIRE) or ply:IsOnFire()) then
						animent:Ignite(30,70)
					end
					animent.AutomaticFrameAdvance = true
					function animent:Think() -- This makes the animation work
						self:NextThink( CurTime() )
						return true
					end
				
					timer.Simple( animent:SequenceDuration( seq ), function() -- After the sequence is done, spawn the ragdoll

						local ragdoll = ents.Create("prop_ragdoll")
						ragdoll:SetModel(animent:GetModel())
						ragdoll:SetPos(animent:GetPos())
						ragdoll:SetAngles(animent:GetAngles())
						ragdoll:Spawn()
						ragdoll:Activate()
						if (!GetConVar("ai_serverragdolls"):GetBool()) then
							ragdoll:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
						end
						if (ply:HasDeathFlag(DF_FIRE) or ply:IsOnFire() or dmginfo:IsDamageType(DMG_BURN)) then
							ragdoll:Ignite(30,70)
						end
						ply.RagdollEntity = ragdoll
						ragdoll:Fire("FadeAndRemove","",math.random(5,30))
						local phys = ragdoll:GetPhysicsObject()
						if (IsValid(phys)) then
							phys:AddVelocity(ply:GetVelocity() * 8 + dmginfo:GetDamageForce())
						end			
						local rag = ragdoll
						SetEntityStuff( rag, animent )
						TransferBones(animent,ragdoll)
						animent:Remove()
					end )
				end
			end	

		elseif (ply:GetPlayerClass() == "boomer") then

			if ply:GetPlayerClass() == "boomer" or ply:GetPlayerClass() == "boomette" then
				timer.Simple(0.1, function()
					if ply:GetRagdollEntity():IsValid() then
						ply:GetRagdollEntity():Remove()
					end
				end)
				if (string.find(ply:GetModel(),"boomette")) then
					ply:SetModel("models/infected/limbs/exploded_boomette.mdl")
				else
					ply:SetModel("models/infected/limbs/exploded_boomer.mdl")
				end
				ply:EmitSound("BoomerZombie.Detonate")
				local ragdoll = ents.Create("prop_ragdoll")
				ragdoll:SetModel(ply:GetModel())
				
			ragdoll:SetSkin(ply:GetSkin())
			--ragdoll:SetBodyGroups(ply:GetBodyGroups())
			--ragdoll:SetOwner(ply)
				ragdoll:SetPos(ply:GetPos())
				ragdoll:SetAngles(ply:GetAngles())
				ragdoll:Spawn()
				ragdoll:Activate()
				
				if (!GetConVar("ai_serverragdolls"):GetBool()) then
					ragdoll:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
				end
				if (ply:HasDeathFlag(DF_FIRE) or ply:IsOnFire() or dmginfo:IsDamageType(DMG_BURN)) then
					ragdoll:Ignite(30,70)
				end
				
				ply.RagdollEntity = ragdoll
				ragdoll:Fire("FadeAndRemove","",math.random(5,30))
				local phys = ragdoll:GetPhysicsObject()
				if (IsValid(phys)) then
					phys:AddVelocity(ply:GetVelocity() * 8 + dmginfo:GetDamageForce())
				end
				
				if (dmginfo:IsDamageType(DMG_DISSOLVE)) then
					timer.Simple(0.15, function()
						local dissolver = ents.Create( "env_entity_dissolver" )
						dissolver:SetPos( ragdoll:LocalToWorld(ragdoll:OBBCenter()) )
						dissolver:SetKeyValue( "dissolvetype", 0 )
						dissolver:Spawn()
						dissolver:Activate()
						local name = "Dissolving_"..math.random()
						ragdoll:SetName( name )
						dissolver:Fire( "Dissolve", name, 0 )
						dissolver:Fire( "Kill", name, 0.10 )
					end)
				end
				ParticleEffectAttach("boomer_explode", PATTACH_POINT_FOLLOW, ragdoll, 1 )
				util.BlastDamage(ply,ply,ply:GetPos(),300,25)
				for k,v in ipairs(ents.FindInSphere(ply:GetPos(), 300)) do
					if v:IsTFPlayer() and !v:IsFriendly(ply) and v != ply then
						if (!v:HasPlayerState(PLAYERSTATE_PUKEDON)) then
							if (v:IsPlayer()) then
								v:SendLua("LocalPlayer():EmitSound('Event.VomitInTheFace')")
							end
							v:EmitSound("Event.BoomerHit")
							v:AddPlayerState(PLAYERSTATE_PUKEDON, true)	
						end
						timer.Simple(10, function()
							if (v:HasPlayerState(PLAYERSTATE_PUKEDON)) then
								v:RemovePlayerState(PLAYERSTATE_PUKEDON, false)	
							end
						end)
						local ent = v
						if not (ent:IsTFPlayer() and ply:CanDamage(ent) and not ent:IsBuilding()) then return end
						
						local InflictorClass = gamemode.Call("GetInflictorClass", ent, ply, self)
						if v:IsPlayer() then
							v:Speak("TLK_JARATE_HIT")	
						end
						umsg.Start("Notice_EntityHumiliationCounter")
							umsg.String(GAMEMODE:EntityName(ent))
							umsg.Short(GAMEMODE:EntityTeam(ent))
							umsg.Short(GAMEMODE:EntityID(ent))
							
							umsg.String("deflect_acidball")
							
							umsg.String(GAMEMODE:EntityName(ply))
							umsg.Short(GAMEMODE:EntityTeam(ply))
							umsg.Short(GAMEMODE:EntityID(ply))
							
							--[[
							umsg.String(GAMEMODE:EntityName(cooperator))
							umsg.Short(GAMEMODE:EntityTeam(cooperator))
							umsg.Short(GAMEMODE:EntityID(cooperator))]]
							
							umsg.Bool(self.CurrentShotIsCrit)
						umsg.End()
						if (v:IsPlayer()) then
							if  v:GetPlayerClass() == "francis" then
								v:EmitSound("player/survivor/voice/biker/boomerreaction0"..math.random(1,9)..".wav", 85)
							end
							--v:EmitSound("music/terror/pukricide.wav", 55)
							if  v:GetPlayerClass() == "zoey" and  v:IsPlayer() then
								v:EmitSound("player/survivor/voice/teenangst/boomerreaction0"..math.random(1,9)..".wav", 85)
							end
							if  v:GetPlayerClass() == "louis" and  v:IsPlayer() then
								v:EmitSound("player/survivor/voice/manager/boomerreaction0"..math.random(1,9)..".wav", 85)
							end
			
							if  v:GetPlayerClass() == "coach" and  v:IsPlayer() then
								v:EmitSound("player/survivor/voice/coach/boomerreaction0"..math.random(1,9)..".wav", 85)
							end
								
							if v:GetPlayerClass() == "bill" and  v:IsPlayer() then
								v:EmitSound("player/survivor/voice/namvet/boomerreaction0"..math.random(1,9)..".wav", 85)
							end
						end
					end
				end
			end
		end
	else
		
		if (((!ply:IsHL2() and !ply:IsL4D() and !isBlastKill and !shouldGibLikeTF2 ) or (ply:IsHL2() || ply:IsL4D())) or string.find(ply:GetModel(),"/bot_") and ply:GetModelScale() == 1.0 and !string.find(ply:GetModel(),"_boss.mdl")) then
			if (GetConVar("tf_use_client_ragdolls"):GetBool()) then
				if ((string.find(ply:GetModel(),"bot_") and ply:GetModelScale() > 1.0) or ply:IsMiniBoss()) then
					
				else
					if (!dmginfo:IsDamageType(DMG_DISSOLVE) and !ply:HasDeathFlag(DF_FROZEN) and !ply:HasDeathFlag(DF_GOLDEN)) then
						net.Start("TFRagdollCreate")
							net.WriteEntity(ply)
							net.WriteVector(ply:GetAbsVelocity())
						net.Broadcast()
						
					else
						if (!ply:HasDeathFlag(DF_FROZEN) and !ply:HasDeathFlag(DF_GOLDEN)) then
							ply:CreateRagdoll()
						end
					end
					if (ply:HasDeathFlag(DF_DECAP)) then
						ply:EmitSound("TFPlayer.Decapitated")
					end
					/*
					timer.Simple(0.1, function()
						local ragdoll = ply:GetRagdollEntity()
						TransferBones(ply,ragdoll)
						ply.RagdollEntity = ragdoll
						ply:SetNWEntity("RagdollEntity",ply.RagdollEntity)
						local phys = ply:GetRagdollEntity():GetPhysicsObject()
						if (IsValid(phys)) then
							phys:SetVelocity(Vector(0,0,0))
							phys:AddVelocity(ply:GetVelocity() * 8 + dmginfo:GetDamageForce())
						end
					end)
					*/
				end
			end
		end

	end
	timer.Simple(0.02, function()
	
		if ply:HasDeathFlag(DF_GOLDEN) then
	
			timer.Simple(0.1, function()
				if ply:GetRagdollEntity():IsValid() then
					ply:GetRagdollEntity():Remove()
				end
			end)
			local engineer_golden_lines = {
				"scenes/Player/Engineer/low/3605.vcd",
				"scenes/Player/Engineer/low/3690.vcd",
				"scenes/Player/Engineer/low/3691.vcd",
			}
		
			if attacker:GetPlayerClass() == "engineer" then
				attacker:PlayScene(engineer_golden_lines[math.random( #engineer_golden_lines )])
			end
			
			local animent = ents.Create( 'prop_ragdoll' )
			local ragdoll = animent
			animent:AddFlags(FL_GODMODE) -- The entity used for the death animation	
			animent:SetModel(ply:GetModel())
			animent:SetSkin(ply:GetSkin())
			animent:Fire("FadeAndRemove","",15)
			animent:SetAngles(ply:GetAngles())
			animent:SetPos(ply:GetPos() - ply:GetViewOffset())
			animent:Spawn()
			animent:Activate()
			animent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			animent:SetMaterial("models/player/shared/gold_player")
			TransferBones(ply,ragdoll)
			local bones = ragdoll:GetPhysicsObjectCount()
			if ( bones < 2 ) then return end 
			for bone = 1, bones - 1 do
			
				local constraint = constraint.Weld( ragdoll, ragdoll, 0, bone, 0 )
			
			end
			timer.Simple(15, function()
				ragdoll:SetSaveValue( "m_bFadingOut", true )
			end)
		elseif ply:HasDeathFlag(DF_FROZEN) then
			timer.Simple(0.1, function()
				if ply:GetRagdollEntity():IsValid() then
					ply:GetRagdollEntity():Remove()
				end
			end)
			local animent = ents.Create( 'prop_ragdoll' )
			animent:AddFlags(FL_GODMODE) -- The entity used for the death animation	
			animent:SetModel(ply:GetModel())
			animent:SetSkin(ply:GetSkin())
			animent:SetPos(ply:GetPos() - Vector(0,0,40))
			animent:SetAngles(ply:GetAngles())
			animent:Spawn()
			animent:Activate()
			animent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			ply.RagdollEntity = animent
			ply:EmitSound("weapons/icicle_freeze_victim_01.wav", 95, 100)
			animent:SetMaterial("models/player/shared/ice_player")
			animent:Fire("FadeAndRemove","",15)
			local ragdoll = animent
			TransferBones(ply,ragdoll)
			timer.Simple(15, function()
				ragdoll:SetSaveValue( "m_bFadingOut", true )
			end)
			local bones = ragdoll:GetPhysicsObjectCount()
			if ( bones < 2 ) then return end 
			for bone = 1, bones - 1 do
			
				local constraint = constraint.Weld( ragdoll, ragdoll, 0, bone, 0 )
			
			end
			timer.Simple(15, function()
				ragdoll:SetSaveValue( "m_bFadingOut", true )
			end)
			
		end

	end)
	gamemode.Call("DoTFPlayerDeath", ply, attacker, dmginfo)
	ply:StopSound( "GrappledFlesh" )
	ply:StopSound("Grappling")
	local drop
	for _,v in pairs(ply:GetWeapons()) do
		if v.DropAsAmmo then
			if v.GetItemData and v:GetItemData().item_slot == "primary" then
				drop = v
			end
			
			if v == ply:GetActiveWeapon() and not v.DropPrimaryWeaponInstead then
				drop = v
				break
			end
		end
	end
	ply:Spectate(OBS_MODE_DEATHCAM)
	ply:SpectateEntity(nil)
	if (IsValid(attacker) and attacker:IsTFPlayer() and attacker:EntIndex() != ply:EntIndex() and !ply:Alive()) then
		ply:SpectateEntity(attacker)
		ply:SetFOV(attacker:GetFOV())
		timer.Simple(2.0, function()
			if (!ply:Alive() && IsValid(attacker)) then
				ply:SendLua("surface.PlaySound('misc/freeze_cam.wav')")
				ply:SetFOV(attacker:GetFOV())
			end
		end)
		timer.Simple(2.0, function()
			if (!ply:Alive() && IsValid(attacker)) then
				ply:Spectate(OBS_MODE_FREEZECAM)
				ply:SpectateEntity(attacker)
				ply:SetFOV(attacker:GetFOV())
			end
		end)
	end
	if IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() == "tf_weapon_builder" and IsValid(ply:GetActiveWeapon():GetItemData()) and ply:GetActiveWeapon():GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
		ply:EmitSound("Psap.Death")
	end
	
	ply:StopSound("MVM.GiantScoutLoop")
	ply:StopSound("MVM.SentryBusterLoop")
	ply:StopSound("MVM.GiantSoldierLoop")
	ply:StopSound("MVM.GiantPyroLoop")
	ply:StopSound("MVM.GiantDemomanLoop")
	ply:StopSound("MVM.GiantHeavyLoop")
	if (ply:IsMiniBoss()) then
		for k,v in ipairs(player.GetAll()) do
			if (!v:IsFriendly(ply)) then
				v:Speak("TLK_MVM_GIANT_KILLED")
			end
		end
	end
	if (attacker:IsMiniBoss()) then
		for k,v in ipairs(player.GetAll()) do
			if (!v:IsFriendly(attacker)) then
				v:Speak("TLK_MVM_GIANT_KILLED_TEAMMATE")
			end
		end
	end
	if ply:GetPlayerClass() == "merc_dm" then
		if dmginfo:GetInflictor().Critical and dmginfo:GetInflictor():Critical() then
			if not inflictor.IsSilentKiller then	
				ply:EmitSound("vo/mercenary_paincrticialdeath0"..math.random(1,4)..".wav")
			end
		elseif dmginfo:IsDamageType(DMG_CLUB) or dmginfo:IsDamageType(DMG_SLASH) or inflictor.HoldType=="MELEE" then
			if not inflictor.IsSilentKiller then	
				ply:EmitSound("vo/mercenary_paincrticialdeath0"..math.random(1,4)..".wav")
			end
		else
			if not inflictor.IsSilentKiller then
				ply:EmitSound("vo/mercenary_painsevere0"..math.random(1,6)..".wav")
			end
		end
	end
	
	if ply:GetPlayerClass() == "hunter" then
		ply:EmitSound("player/hunter/voice/death/hunter_death_0"..table.Random({"2","4","6","7","8"})..".wav", 95, 100, 1, CHAN_VOICE)
	end
	if ply:GetPlayerClass() == "smoker" then
		ply:EmitSound("SmokerZombie.Death")
		ply:EmitSound("SmokerZombie.Explode")
		ParticleEffect( "smoker_smokecloud", ply:GetPos(), ply:GetAngles() )
	end
	if ply:GetPlayerClass() == "spitter" then
		ply:EmitSound("SpitterZombie.Death")
	end
	if ply:GetPlayerClass() == "witch" then
		ply:EmitSound("vj_l4d/witch/voice/die/headshot_death_"..math.random(1,3)..".wav", 95, 100, 1, CHAN_VOICE)
	end
	if (attacker.LastPath) then
		attacker.LastPath = nil
	elseif (attacker.TargetEnt) then
		attacker.TargetEnt = nil
	end
	if (attacker.TFBot and !ply:IsBot()) then
		timer.Simple(0.25, function()
			if (math.random(1,2) == 1) then
				if (!string.find(attacker:GetModel(),"_boss.mdl")) then
					if (attacker:Team() == TEAM_RED and string.find(game.GetMap(),"mvm_")) then return end
					attacker:TFTaunt(tostring(attacker:GetActiveWeapon():GetSlot() + 1))
				end
			end
		end)
	end
	timer.Stop("VoiceL4d"..ply:EntIndex(), 2.5)
	if (attacker:IsPlayer() and (attacker:GetPlayerClass() == "demoknight" || attacker:GetPlayerClass() == "giantdemoknight")) then
		GAMEMODE:AddCritBoostTime(attacker, 3)
	end
	if (IsValid(ply.trail)) then
		ply.trail:Remove()
		ply.trail2:Remove()
		ply.trail3:Remove()
		ply.trail4:Remove()
		ply.trail5:Remove()
	end
	if (GetConVar("tf_use_client_ragdolls"):GetBool()) then
		if (ply:HasDeathFlag(DF_DECAP)) then
			ply:Decap()
			timer.Simple(0.1, function()
			
				ply:GetRagdollEntity():EmitSound("TFPlayer.Decapitated")
				if (!ply:IsHL2()) then
					local b1 = ply:GetRagdollEntity():LookupBone("bip_head")
					local b2 = ply:GetRagdollEntity():LookupBone("bip_neck")
					local b3 = ply:GetRagdollEntity():LookupBone("prp_helmet")
					local b4 = ply:GetRagdollEntity():LookupBone("jaw_bone")
				
					local m1 = ply:GetRagdollEntity():GetBoneMatrix(b1)
					local m2 = ply:GetRagdollEntity():GetBoneMatrix(b2)
					ply:GetRagdollEntity():ManipulateBoneScale(b1, Vector(0,0,0))
					ply:GetRagdollEntity():ManipulateBoneScale(b2, Vector(0,0,0))	
					if ply:GetRagdollEntity():GetModel() == "models/player/engineer.mdl" then
						ply:GetRagdollEntity():ManipulateBoneScale(b3, Vector(0,0,0))
					end
				end

			end)
		end
	else
		if (ply:HasDeathFlag(DF_DECAP)) then
			ply.RagdollEntity:EmitSound("TFPlayer.Decapitated")
			ply:Decap()
			if (!ply:IsHL2()) then
				local b1 = ply.RagdollEntity:LookupBone("bip_head")
				local b2 = ply.RagdollEntity:LookupBone("bip_neck")
				local b3 = ply.RagdollEntity:LookupBone("prp_helmet")
				local b4 = ply.RagdollEntity:LookupBone("jaw_bone")
			
				local m1 = ply.RagdollEntity:GetBoneMatrix(b1)
				local m2 = ply.RagdollEntity:GetBoneMatrix(b2)
				ply.RagdollEntity:ManipulateBoneScale(b1, Vector(0,0,0))
				ply.RagdollEntity:ManipulateBoneScale(b2, Vector(0,0,0))	
				if ply.RagdollEntity:GetModel() == "models/player/engineer.mdl" then
					ply.RagdollEntity:ManipulateBoneScale(b3, Vector(0,0,0))
				end
			end
		end
	end
	if (ply:IsOnFire()) then
		ply:GetRagdollEntity():Ignite(10)
	end
	if IsValid(drop) then
		drop:DropAsAmmo()
	end
	
	local killer = attacker
	if inflictor.KillCreditAsInflictor then
		killer = inflictor
	end
	
	if ply~=killer and not killer:IsWorld() and (killer:IsTFPlayer()) then
		umsg.Start("SetPlayerKiller", ply)
			umsg.Entity(killer)
			umsg.String(GAMEMODE:EntityDeathnoticeName(killer))
			umsg.Short(killer:EntityTeam())
			umsg.Char(ply.KillerDominationInfo)
			if killer ~= attacker then
				umsg.Entity(attacker)
			else
				umsg.Entity(NULL)
			end
		umsg.End()
	end
	
	timer.Simple(0.02, function()
		ply:SetPos(ply:GetPos() - ply:GetViewOffset())
		ply:SetMoveType(MOVETYPE_NONE)
	end)
	----print("DoPlayerDeath", dmginfo:GetInflictor(), dmginfo:GetAttacker(), dmginfo:GetDamage(), dmginfo:GetDamageType())
	
	if ((string.find(ply:GetModel(),"bot_") and ply:GetModelScale() > 1.0) or ply:IsMiniBoss()) then
		--ply:GibBreakServer( dmginfo:GetDamageForce() )
		local animent = ents.Create( 'prop_dynamic_override' )
		animent:SetSkin(ply:GetSkin())
		animent:SetPos(ply:GetPos())
		animent:SetAngles(ply:GetAngles())
		animent:SetModel(ply:GetModel())
		animent:SetVelocity(ply:GetVelocity())
		animent:Spawn()
		animent:SetHealth(4000)
		animent:Activate()
		animent:AddFlags(FL_GODMODE) -- The entity used for the death animation	
		animent:Fire("break","",0.01)
		if (ply:IsMiniBoss()) then
			ply:EmitSound("MVM.GiantCommonExplodes")
		end
	end
	if (ply:GetPlayerClass() == "spitter") then
		local spit = ents.Create("obj_vj_l4d_spit")
		spit:SetPos(ply:GetPos() +Vector(0,0,15))
		spit:Spawn()
		spit:SetCount(4)
	end
	if dmginfo:IsFallDamage() then -- Fall damage
		ply.FallDeath = true
		ply:EmitSound("player/pl_fleshbreak.wav", 70, math.random(92,96))
	elseif isBlastKill or shouldGibLikeTF2 then -- Explosion damage
	
		if ply:GetMaterial() == "models/shadertest/predator" then return end
		if (!ply:HasDeathFlag(DF_GIB)) then
			ply:RandomSentence("ExplosionDeath")
		else
			if dmginfo:IsDamageType(DMG_ACID) then -- Critical damage
				if not inflictor.IsSilentKiller then
					if (!ply:HasDeathFlag(DF_SILENCED) and !ply:IsMiniBoss()) then
						ply:RandomSentence("CritDeath")
					end
				end
			elseif dmginfo:IsDamageType(DMG_CLUB) then -- Melee damage
				if not inflictor.IsSilentKiller then	
					if ply:GetMaterial() == "models/shadertest/predator" then return end
						if (!ply:HasDeathFlag(DF_SILENCED) and !ply:IsMiniBoss()) then
							ply:RandomSentence("MeleeDeath")
						end
				end
			else -- Bullet/fire damage
				if not inflictor.IsSilentKiller then
					if ply:GetMaterial() == "models/shadertest/predator" then return end
					if (!ply:HasDeathFlag(DF_SILENCED) and !ply:IsMiniBoss()) then
						ply:RandomSentence("Death") 
					end
				end
			end
		end
		if (shouldGibLikeTF2 and dmginfo:IsDamageType(DMG_SHOCK)) then
			local effectName = (ply:Team() == TEAM_RED) and "electrocuted_gibbed_red" or "electrocuted_gibbed_blue"
			ParticleEffect(effectName, ply:GetPos(), Angle(0, 0, 0))
			ply:EmitSound("TFPlayer.MedicChargedDeath")
		end

		if (shouldGibLikeTF2) then
			ParticleEffect("tfc_sniper_mist",ply:GetPos(),ply:GetAngles(),nil)
		end
		
		if not ply:IsHL2() and !ply:IsL4D() then
			if (!(string.find(ply:GetModel(),"bot_"))) then
				if shouldGibLikeTF2 then
					ply:Explode(dmginfo)
					ply:EmitSound("BaseCombatCharacter.CorpseGib")
					shouldgib = true
				end
			end
		else
			if shouldGibLikeTF2 then
				ply:Explode(dmginfo)
				if (IsValid(ply:GetRagdollEntity())) then
					ply:GetRagdollEntity():Remove()
				end
			end
		end
	elseif dmginfo:IsDamageType(DMG_ACID) then -- Critical damage
		if not inflictor.IsSilentKiller then
			if (!ply:HasDeathFlag(DF_SILENCED) and !ply:IsMiniBoss()) then
				ply:RandomSentence("CritDeath")
			end
		end
	elseif dmginfo:IsDamageType(DMG_CLUB) then -- Melee damage
		if not inflictor.IsSilentKiller then	
			if ply:GetMaterial() == "models/shadertest/predator" then return end
				if (!ply:HasDeathFlag(DF_SILENCED) and !ply:IsMiniBoss()) then
					ply:RandomSentence("MeleeDeath")
				end
		end
	else -- Bullet/fire damage
		if not inflictor.IsSilentKiller then
			if ply:GetMaterial() == "models/shadertest/predator" then return end
			if (!ply:HasDeathFlag(DF_SILENCED) and !ply:IsMiniBoss()) then
				ply:RandomSentence("Death") 
			end
		end
	end
	if (ply:GetPlayerClass() == "headless_hatman" or ply:GetPlayerClass() == "merasmus" or ply:GetPlayerClass() == "sentrybuster") then
		ply:SetPlayerClass("gmodplayer")
	end
	if (ply:GetPlayerClass() == "headless_hatman") then
		ply:RandomSentence("CritDeath")
	end
	if ply:GetPlayerClass() == "zombie" then
		ply:EmitSound("Zombie.Die")
	end
	if ply:GetPlayerClass() == "zombine" then
		ply:EmitSound("Zombine.Die")
	end
	if ply:GetPlayerClass() == "fastzombie" then
		ply:EmitSound("NPC_FastZombie.Die")
	end
	if ply:GetPlayerClass() == "poisonzombie" then
		ply:EmitSound("NPC_PoisonZombie.Die")
	end
	if (ply:Team() == TEAM_YELLOW or ply:Team() == TEAM_GREEN) then
		if (!ply:IsHL2() and !ply:IsL4D()) then
			ply:SetModel(string.Replace(ply:GetModel(),"/player/","/lkskin/hwm/"))
		end
	end

	timer.Simple(0.015, function()
	
		if (IsValid(ply.RagdollEntity)) then
			ply.RagdollEntity.GetPlayerColor = ply:GetPlayerColor()
			ply:SetNWEntity("RagdollEntity",ply.RagdollEntity)
		end
	
	end)
	ply.LastDamageInfo = CopyDamageInfo(dmginfo)
end

function GM:OnNPCKilled(ent, attacker, inflictor)
	if inflictor.IsSilentKiller then
		umsg.Start("SilenceNPC")
			umsg.Entity(ent)
		umsg.End()
	end
	
	if inflictor and inflictor.OnPlayerKilled then
		inflictor:OnPlayerKilled(ent)
	end
	if (attacker.LastPath) then
		attacker.LastPath = nil
	elseif (attacker.TargetEnt) then
		attacker.TargetEnt = nil
	end
	if (ent:HasDeathFlag(DF_DECAP)) then
		ent:EmitSound("TFPlayer.Decapitated")
	end
	AwardHalloweenSoulFromDeath(ent, attacker)
	gamemode.Call("DoTFPlayerDeath", ent, attacker, ent.LastDamageInfo)
	
	-- for Gran <3
	-- NPCs should spawn silly gibs if killed by damage of type DMG_ALWAYSGIB+DMG_REMOVENORAGDOLL
	if ent.LastDamageInfo and ent.LastDamageInfo:IsDamageType(DMG_ALWAYSGIB) and ent.LastDamageInfo:IsDamageType(DMG_BLAST) and ent.LastDamageInfo:IsDamageType(DMG_REMOVENORAGDOLL) then
		umsg.Start("GibNPC")
			umsg.Entity(ent)
			umsg.Short(ent.DeathFlags)
		umsg.End()
	end
	
	gamemode.Call("PostTFPlayerDeath", ent, attacker, inflictor)
end

function GM:PlayerDeath(ent, inflictor, attacker)
	-- Don't spawn for at least 2 seconds
	if (ent:GetNWBool("Congaing")) then
		ent:ConCommand("tf_taunt_conga_stop")
	elseif (ent:GetNWBool("Russian")) then
		ent:ConCommand("tf_taunt_russian_stop")
	end
	if (!GAMEMODE.RoundHasWinner) then
		if (GetConVar("civ2_allow_respawn_with_key_press"):GetBool()) then
			ent.NextSpawnTime = CurTime() + 2.5
		else 
			ent.NextSpawnTime = CurTime() + 7
		end
	else
		ent.NextSpawnTime = CurTime() + 15
	end
	ent.DeathTime = CurTime()
	
	
	if GetConVar("tf_enable_revive_markers"):GetBool() then
		animent = ents.Create( 'reviver' ) -- The entity used for the death animation
		animent:SetPos(ent:GetPos())
		animent:SetAngles(ent:GetAngles())
		animent:Spawn()
		animent:Activate()
		ply.RagdollEntity = animent
		animent:SetOwner(ent)
		
		if ent:GetPlayerClass() == "soldier" then
			animent:SetBodygroup(1, 2)
		elseif ent:GetPlayerClass() == "pyro" then
			animent:SetBodygroup(1, 6)
		elseif ent:GetPlayerClass() == "demoman" then
			animent:SetBodygroup(1, 3)
		elseif ent:GetPlayerClass() == "heavy" then
			animent:SetBodygroup(1, 5)
		elseif ent:GetPlayerClass() == "engineer" then
			animent:SetBodygroup(1, 8)
		elseif ent:GetPlayerClass() == "medic" then
			animent:SetBodygroup(1, 4)
		elseif ent:GetPlayerClass() == "sniper" then
			animent:SetBodygroup(1, 1)
		elseif ent:GetPlayerClass() == "spy" then
			animent:SetBodygroup(1, 7)
		end
			
	end
	if (IsValid(ent.PuppetAnim)) then
		ent.PuppetAnim:Remove()
	end
	timer.Stop("Respawn"..ent:EntIndex())
	timer.Create("Respawn"..ent:EntIndex(), 6.5, 1, function()
		if (!GAMEMODE.RoundHasWinner) then
			if IsValid(animent) then
				animent:Fire("Kill", "", 0.1)
			end
			if IsValid(ent) then
				if !ent:Alive() and !ent.TFBot then
					ent:Spawn()
				end
			end
		end
	end)
	
	if (attacker:IsTFPlayer()) then
		gamemode.Call("PostTFPlayerDeath", ent, attacker, inflictor)
	else
		if (!ent.LastDamageInfo:IsFallDamage()) then
			gamemode.Call("PostTFPlayerDeath", ent, ent, inflictor)
		end
	end
end

-- No flatline sound
function GM:PlayerDeathSound()
	if GetConVar("gmod_suit"):GetBool() then
		return false
	else
		return true
	end 
end

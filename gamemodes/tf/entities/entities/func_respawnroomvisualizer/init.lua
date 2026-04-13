AddCSLuaFile()
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local VISUALIZER_REBIND_RECHECK = 1.0
local DEBUG_CVAR_NAME = "tf_debug_respawnrooms"

local debugCvar = SERVER and CreateConVar(DEBUG_CVAR_NAME, "0", FCVAR_ARCHIVE, "Enable respawn room / visualizer debug logging.") or nil

local function DebugEnabled()
	return SERVER and debugCvar and debugCvar:GetBool()
end

local function DebugLog(self, message)
	if not DebugEnabled() then return end

	local name = IsValid(self) and tostring(self:GetName() or "") or ""
	local entIndex = IsValid(self) and self:EntIndex() or -1
	local tag = string.format("[RespawnViz:%d:%s]", entIndex, name ~= "" and name or "unnamed")
	print(tag .. " " .. tostring(message))
end

local function IsBlueSideTeam(teamNum)
	return teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS
end

local function IsAllowedInVisualizer(playerTeam, visualizerTeam)
	if visualizerTeam == TEAM_RED then
		return playerTeam == TEAM_RED
	end
	if visualizerTeam == TEAM_BLU then
		return IsBlueSideTeam(playerTeam)
	end
	return true
end

local function ParseHammerTeamNum(value)
	local t = tonumber(value)
	if t == 2 then return TEAM_RED end
	if t == 3 then return TEAM_BLU end
	return TEAM_UNASSIGNED or 0
end

local function RawHammerTeamFromInternal(teamNum)
	if teamNum == TEAM_RED then return 2 end
	if teamNum == TEAM_BLU then return 3 end
	return 0
end

local function SetSolidState(self, active)
	if not IsValid(self) then return end

	self:SetNotSolid(true)
	self:SetSolid(SOLID_NONE)

	if self.SetTrigger then
		self:SetTrigger(false)
	end

	if self.AddSolidFlags and self.RemoveSolidFlags and FSOLID_TRIGGER and FSOLID_NOT_SOLID then
		self:AddSolidFlags(FSOLID_NOT_SOLID)
		self:RemoveSolidFlags(FSOLID_TRIGGER)
	end
end

local function RefreshTransmitState(self)
	if not SERVER or not IsValid(self) or not self.SetPreventTransmit then return end

	local hideForAll = GAMEMODE and GAMEMODE.RoundHasWinner
	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) then continue end

		local hide = hideForAll and true or false
		if not hide and self.TeamNum ~= (TEAM_UNASSIGNED or 0) then
			hide = IsAllowedInVisualizer(ply:Team(), self.TeamNum)
		end

		self:SetPreventTransmit(ply, hide)
	end
end

local function FindRespawnRoomByName(name)
	if not name or name == "" then return nil end

	for _, ent in ipairs(ents.FindByName(name)) do
		if IsValid(ent) and ent:GetClass() == "func_respawnroom" then
			return ent
		end
	end
end

local function IsPointInsideBrush(self, pos)
	local mins, maxs = self:WorldSpaceAABB()
	return pos.x >= mins.x and pos.x <= maxs.x
		and pos.y >= mins.y and pos.y <= maxs.y
		and pos.z >= mins.z and pos.z <= maxs.z
end

local function HullIntersectsBrush(self, origin, mins, maxs)
	local bMins, bMaxs = self:WorldSpaceAABB()
	local hMins = origin + mins
	local hMaxs = origin + maxs

	return hMaxs.x >= bMins.x and hMins.x <= bMaxs.x
		and hMaxs.y >= bMins.y and hMins.y <= bMaxs.y
		and hMaxs.z >= bMins.z and hMins.z <= bMaxs.z
end

local function SweptHullHitBrush(self, startPos, endPos, mins, maxs)
	local bMins, bMaxs = self:WorldSpaceAABB()
	local sweepMins = Vector(bMins.x - maxs.x, bMins.y - maxs.y, bMins.z - maxs.z)
	local sweepMaxs = Vector(bMaxs.x - mins.x, bMaxs.y - mins.y, bMaxs.z - mins.z)
	local delta = endPos - startPos
	local tMin, tMax = 0, 1
	local hitNormal = nil

	for _, axis in ipairs({"x", "y", "z"}) do
		local start = startPos[axis]
		local dir = delta[axis]
		local min = sweepMins[axis]
		local max = sweepMaxs[axis]

		if math.abs(dir) < 0.0001 then
			if start < min or start > max then
				return false
			end
		else
			local inv = 1 / dir
			local t1 = (min - start) * inv
			local t2 = (max - start) * inv
			local enterNormal = Vector(0, 0, 0)

			if t1 > t2 then
				t1, t2 = t2, t1
				enterNormal[axis] = 1
			else
				enterNormal[axis] = -1
			end

			if t1 > tMin then
				tMin = t1
				hitNormal = enterNormal
			end
			tMax = math.min(tMax, t2)
			if tMin > tMax then
				return false
			end
		end
	end

	if tMin < 0 or tMin > 1 then
		return false
	end

	return true, tMin, hitNormal or vector_origin
end

local function SegmentIntersectsBrush(self, startPos, endPos)
	local mins, maxs = self:WorldSpaceAABB()
	local dir = endPos - startPos
	local tMin, tMax = 0, 1

	for _, axis in ipairs({"x", "y", "z"}) do
		local start = startPos[axis]
		local delta = dir[axis]
		local min = mins[axis]
		local max = maxs[axis]

		if math.abs(delta) < 0.0001 then
			if start < min or start > max then
				return false
			end
		else
			local inv = 1 / delta
			local t1 = (min - start) * inv
			local t2 = (max - start) * inv
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tMin = math.max(tMin, t1)
			tMax = math.min(tMax, t2)
			if tMin > tMax then
				return false
			end
		end
	end

	return true
end

local function ExpandAABB(mins, maxs, amount)
	return mins - amount, maxs + amount
end

local function AABBsIntersect(minsA, maxsA, minsB, maxsB)
	return maxsA.x >= minsB.x and minsA.x <= maxsB.x
		and maxsA.y >= minsB.y and minsA.y <= maxsB.y
		and maxsA.z >= minsB.z and minsA.z <= maxsB.z
end

local function AABBDistanceSqr(minsA, maxsA, minsB, maxsB)
	local dx = math.max(0, minsA.x - maxsB.x, minsB.x - maxsA.x)
	local dy = math.max(0, minsA.y - maxsB.y, minsB.y - maxsA.y)
	local dz = math.max(0, minsA.z - maxsB.z, minsB.z - maxsA.z)
	return (dx * dx) + (dy * dy) + (dz * dz)
end

local function GetBrushBounds(ent)
	if not IsValid(ent) then return end
	local mins, maxs = ent:WorldSpaceAABB()
	return mins, maxs
end

local function IsDoorAllowedForTeam(playerTeam, doorTeam)
	return IsAllowedInVisualizer(playerTeam, doorTeam)
end

local function ShouldUseSpawnDoorGuard()
	local map = string.lower(game.GetMap() or "")
	return not string.StartWith(map, "mvm_")
end

local function ResolveSpawnDoorTeam(door)
	if not IsValid(door) then return nil end

	local doorMins, doorMaxs = GetBrushBounds(door)
	if not doorMins then return nil end

	local bestTeam, bestDist

	for _, className in ipairs({"func_respawnroomvisualizer", "func_respawnroom"}) do
		for _, ent in ipairs(ents.FindByClass(className)) do
			if not IsValid(ent) then continue end
			local teamNum = tonumber(ent.TeamNum)
			if not teamNum or teamNum == (TEAM_UNASSIGNED or 0) then continue end

			local entMins, entMaxs = GetBrushBounds(ent)
			local dist = AABBDistanceSqr(doorMins, doorMaxs, entMins, entMaxs)
			if bestDist == nil or dist < bestDist then
				bestDist = dist
				bestTeam = teamNum
			end
		end
	end

	if bestDist and bestDist <= (192 * 192) then
		return bestTeam
	end

	return nil
end

local function ScanSpawnDoors()
	if not ShouldUseSpawnDoorGuard() then
		return {}
	end

	local doors = {}

	for _, className in ipairs({"func_door", "func_door_rotating"}) do
		for _, door in ipairs(ents.FindByClass(className)) do
			if not IsValid(door) then continue end
			local teamNum = ResolveSpawnDoorTeam(door)
			if not teamNum then continue end

			door._tfSpawnDoorTeam = teamNum
			door._tfSpawnDoorLocked = nil
			table.insert(doors, door)
		end
	end

	return doors
end

local function IsFriendlyNearSpawnDoor(door)
	local teamNum = door._tfSpawnDoorTeam
	if not teamNum then return false end

	local mins, maxs = GetBrushBounds(door)
	if not mins then return false end
	mins, maxs = ExpandAABB(mins, maxs, Vector(96, 96, 64))

	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:Alive() then
			continue
		end
		if not IsDoorAllowedForTeam(ply:Team(), teamNum) then
			continue
		end

		local pos = ply:GetPos()
		if pos.x >= mins.x and pos.x <= maxs.x
			and pos.y >= mins.y and pos.y <= maxs.y
			and pos.z >= mins.z and pos.z <= maxs.z then
			return true
		end
	end

	return false
end

local function BindRespawnRoom(self)
	if not self.RespawnRoomName or self.RespawnRoomName == "" then return end

	local room = FindRespawnRoomByName(self.RespawnRoomName)
	if not IsValid(room) then
		DebugLog(self, "BindRespawnRoom failed for name=" .. tostring(self.RespawnRoomName))
		return
	end
	if self.RespawnRoom == room then return end

	self.RespawnRoom = room
	self:SetNWEntity("RespawnRoom", room)
	if room.AddVisualizer then
		room:AddVisualizer(self)
	end
	self:ChangeTeam(room.TeamNum)
	DebugLog(self, "bound to room=" .. tostring(room:GetName() or "") .. " roomTeam=" .. tostring(room.TeamNum))
end

local function RefreshVisualizerStateFromKeyValues(self)
	local kv = self.GetKeyValues and self:GetKeyValues() or {}
	local rawRespawnRoom = kv.respawnroomname or kv.RespawnRoomName
	if rawRespawnRoom ~= nil and tostring(rawRespawnRoom) ~= "" then
		self.RespawnRoomName = tostring(rawRespawnRoom)
		self:SetNWString("RespawnRoomName", self.RespawnRoomName)
	end

	local rawTeam = kv.TeamNum or kv.teamnum or kv.Team or kv.team
	if rawTeam ~= nil then
		self:ChangeTeam(ParseHammerTeamNum(rawTeam))
	end

	local rawSolid = kv.solid_to_enemies or kv.Solid_to_enemies or kv.SolidToEnemies
	if rawSolid ~= nil then
		self.SolidToEnemies = tobool(rawSolid) ~= false
		self:SetNWBool("SolidToEnemies", self.SolidToEnemies)
	end
end

function ENT:Initialize()
	local mins, maxs = self:WorldSpaceAABB()
	local pos = (mins + maxs) * 0.5
	local size = maxs - mins
	local localMins = Vector(-(size.x * 0.5), -(size.y * 0.5), -(size.z * 0.5))
	local localMaxs = Vector(size.x * 0.5, size.y * 0.5, size.z * 0.5)
	local model = self:GetModel()

	self.TeamNum = self.TeamNum or TEAM_UNASSIGNED or 0
	self.Team = self.Team or RawHammerTeamFromInternal(self.TeamNum)
	self.SolidToEnemies = self.SolidToEnemies ~= false
	self.Active = true
	self._tfUseBrushSolid = isstring(model) and string.StartWith(model, "*")

	if self._tfUseBrushSolid then
		self:SetMoveType(MOVETYPE_PUSH)
		self:SetSolid(SOLID_BSP)
	else
		self:SetPos(pos)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetCollisionBounds(localMins, localMaxs)
		self:SetSolid(SOLID_BBOX)
	end
	self:SetCollisionGroup(COLLISION_GROUP_WORLD)
	self:SetCustomCollisionCheck(true)
	self:SetRenderMode(RENDERMODE_TRANSCOLOR)
	self:SetColor(Color(255, 255, 255, 255))
	self:SetNoDraw(false)
	self:SetNWInt("TeamNum", self.TeamNum)
	self:SetNWInt("Team", self.Team)
	self:SetNWBool("Active", self.Active)
	self:SetNWBool("SolidToEnemies", self.SolidToEnemies)
	self:SetNWString("RespawnRoomName", self.RespawnRoomName or "")
	self:SetNWEntity("RespawnRoom", NULL)
	RefreshVisualizerStateFromKeyValues(self)
	DebugLog(self, "Initialize team=" .. tostring(self.TeamNum)
		.. " solidToEnemies=" .. tostring(self.SolidToEnemies)
		.. " model=" .. tostring(model)
		.. " useBrushSolid=" .. tostring(self._tfUseBrushSolid))

	timer.Simple(0, function()
		if not IsValid(self) then return end
		BindRespawnRoom(self)
		self:SetActive(self.SolidToEnemies)
	end)
end

function ENT:KeyValue(key, value)
	key = string.lower(key)

	if key == "respawnroomname" then
		self.RespawnRoomName = tostring(value)
		self:SetNWString("RespawnRoomName", self.RespawnRoomName)
	elseif key == "teamnum" then
		self:ChangeTeam(ParseHammerTeamNum(value))
	elseif key == "solid_to_enemies" then
		self.SolidToEnemies = tobool(value) ~= false
	end
end

function ENT:Activate()
	RefreshVisualizerStateFromKeyValues(self)
	BindRespawnRoom(self)
end

function ENT:ChangeTeam(teamNum)
	self.TeamNum = teamNum or TEAM_UNASSIGNED or 0
	self.Team = RawHammerTeamFromInternal(self.TeamNum)
	if self.SetTeam then
		self:SetTeam(self.TeamNum)
	end
	self:SetNWInt("TeamNum", self.TeamNum)
	self:SetNWInt("Team", self.Team)
	self:SetNWBool("SolidToEnemies", self.SolidToEnemies)
	RefreshTransmitState(self)
	DebugLog(self, "ChangeTeam -> " .. tostring(self.TeamNum))
end

function ENT:InputRoundActivate()
	DebugLog(self, "InputRoundActivate")
	BindRespawnRoom(self)
	self:SetActive(self.SolidToEnemies)
end

function ENT:InputSetSolid(_, _, data)
	self.SolidToEnemies = tobool(data) ~= false
	DebugLog(self, "InputSetSolid -> " .. tostring(self.SolidToEnemies))
	self:SetActive(self.SolidToEnemies)
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input" .. tostring(name or "")] or self["Input_" .. tostring(name or "")]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
end

function ENT:SetActive(active)
	self.Active = active ~= false
	SetSolidState(self, self.Active)
	RefreshTransmitState(self)
	self:SetNWBool("Active", self.Active)
	DebugLog(self, "SetActive -> " .. tostring(self.Active)
		.. " solid=" .. tostring(self:GetSolid())
		.. " trigger=" .. tostring(self:IsTrigger())
		.. " moveType=" .. tostring(self:GetMoveType()))
end

function ENT:ShouldCollide(ent)
	if not IsValid(ent) or not ent:IsPlayer() then return end
	if GAMEMODE and GAMEMODE.RoundHasWinner then return false end

	BindRespawnRoom(self)

	if not self.Active then return false end
	if self.TeamNum == (TEAM_UNASSIGNED or 0) then return false end

	local result = not IsAllowedInVisualizer(ent:Team(), self.TeamNum)
	if DebugEnabled() then
		local now = CurTime()
		if (self._tfNextCollideDebug or 0) <= now then
			self._tfNextCollideDebug = now + 1
			DebugLog(self, string.format("ShouldCollide player=%s playerTeam=%s roomTeam=%s active=%s -> %s",
				tostring(ent:Nick()), tostring(ent:Team()), tostring(self.TeamNum), tostring(self.Active), tostring(result)))
		end
	end

	return result
end

function ENT:TestCollision(startPos, delta, isSwept, traceData)
	return false
end

function ENT:Think()
	if not IsValid(self.RespawnRoom) and self.RespawnRoomName and self.RespawnRoomName ~= "" then
		BindRespawnRoom(self)
	end

	SetSolidState(self, self.Active)
	RefreshTransmitState(self)

	self:NextThink(CurTime() + VISUALIZER_REBIND_RECHECK)
	return true
end

function PointsCrossRespawnRoomVisualizer(startPos, endPos, teamToIgnore)
	for _, viz in ipairs(ents.FindByClass("func_respawnroomvisualizer")) do
		if not IsValid(viz) then continue end
		if not viz.Active then continue end
		if teamToIgnore and teamToIgnore ~= (TEAM_UNASSIGNED or 0) and viz.TeamNum == teamToIgnore then
			continue
		end

		if SegmentIntersectsBrush(viz, startPos, endPos) then
			return true
		end
	end

	return false
end

hook.Add("ShouldCollide", "TF_RespawnRoomVisualizerCollision", function(ent1, ent2)
	if not IsValid(ent1) or not IsValid(ent2) then return end

	if ent1:GetClass() == "func_respawnroomvisualizer" and ent1.ShouldCollide then
		local result = ent1:ShouldCollide(ent2)
		if result ~= nil then return result end
	end

	if ent2:GetClass() == "func_respawnroomvisualizer" and ent2.ShouldCollide then
		local result = ent2:ShouldCollide(ent1)
		if result ~= nil then return result end
	end
end)

if SERVER then
	local spawnDoors = nil

	hook.Add("InitPostEntity", "TF_RespawnRoomScanSpawnDoors", function()
		spawnDoors = ScanSpawnDoors()
	end)

	hook.Add("SetupMove", "TF_RespawnRoomVisualizerPlayerBlock", function(ply, mv)
		if not IsValid(ply) or not ply:Alive() then return end
		if GAMEMODE and GAMEMODE.RoundHasWinner then return end

		local startPos = mv:GetOrigin()
		local endPos = startPos + (mv:GetVelocity() * engine.TickInterval())
		local mins, maxs = ply:GetCollisionBounds()
		local lastSafePos = ply._tfRespawnVisualizerLastSafePos
		local earliestFrac = nil
		local hitViz = nil

		for _, viz in ipairs(ents.FindByClass("func_respawnroomvisualizer")) do
			if not IsValid(viz) or not viz.Active then
				continue
			end
			if viz.TeamNum == (TEAM_UNASSIGNED or 0) then
				continue
			end
			if IsAllowedInVisualizer(ply:Team(), viz.TeamNum) then
				continue
			end

			if HullIntersectsBrush(viz, startPos, mins, maxs) then
				hitViz = viz
				earliestFrac = 0
				break
			end

			local hit, frac, normal = SweptHullHitBrush(viz, startPos, endPos, mins, maxs)
			if not hit then
				continue
			end

			if earliestFrac == nil or frac < earliestFrac then
				earliestFrac = frac
				hitViz = viz
			end
		end

		if earliestFrac == nil then
			ply._tfRespawnVisualizerLastSafePos = startPos
			return
		end

		local newOrigin = startPos
		if earliestFrac > 0 then
			local safeFrac = math.max(0, earliestFrac - 0.02)
			newOrigin = startPos + ((endPos - startPos) * safeFrac)
		elseif lastSafePos then
			newOrigin = lastSafePos
		end

		mv:SetOrigin(newOrigin)
		mv:SetVelocity(vector_origin)
		if mv.SetForwardSpeed then mv:SetForwardSpeed(0) end
		if mv.SetSideSpeed then mv:SetSideSpeed(0) end
		if mv.SetUpSpeed then mv:SetUpSpeed(0) end

		if DebugEnabled() and IsValid(hitViz) then
			local now = CurTime()
			if (ply._tfNextRespawnVisualizerBlockDebug or 0) <= now then
				ply._tfNextRespawnVisualizerBlockDebug = now + 1
				DebugLog(hitViz, "movement hard-blocked for player=" .. tostring(ply:Nick()) .. " frac=" .. string.format("%.3f", earliestFrac))
			end
		end
	end)

	hook.Add("Think", "TF_RespawnRoomSpawnDoorGuard", function()
		if not ShouldUseSpawnDoorGuard() then
			return
		end

		if spawnDoors == nil then
			spawnDoors = ScanSpawnDoors()
		end

		for index = #spawnDoors, 1, -1 do
			local door = spawnDoors[index]
			if not IsValid(door) then
				table.remove(spawnDoors, index)
				continue
			end

			local shouldUnlock = false
			if GAMEMODE and GAMEMODE.RoundHasWinner and GAMEMODE.WinningTeam then
				shouldUnlock = GAMEMODE.WinningTeam == door._tfSpawnDoorTeam
			else
				shouldUnlock = IsFriendlyNearSpawnDoor(door)
			end

			if shouldUnlock then
				if door._tfSpawnDoorLocked ~= false then
					door:Fire("Unlock", "", 0)
					door._tfSpawnDoorLocked = false
				end
			else
				if door._tfSpawnDoorLocked ~= true then
					door:Fire("Lock", "", 0)
					door._tfSpawnDoorLocked = true
				end
				door:Fire("Close", "", 0)
			end
		end
	end)
end

if SERVER then
	concommand.Add("tf_dump_respawnrooms", function(ply)
		if IsValid(ply) and not ply:IsAdmin() then return end

		print("[RespawnDebug] func_respawnroom:")
		for _, room in ipairs(ents.FindByClass("func_respawnroom")) do
			print(string.format("  room #%d name=%s team=%s active=%s pos=%s",
				room:EntIndex(),
				tostring(room:GetName() or ""),
				tostring(room.TeamNum),
				tostring(room.GetActive and room:GetActive()),
				tostring(room:GetPos())))
		end

		print("[RespawnDebug] func_respawnroomvisualizer:")
		for _, viz in ipairs(ents.FindByClass("func_respawnroomvisualizer")) do
			print(string.format("  viz #%d name=%s team=%s active=%s solidToEnemies=%s solid=%s trigger=%s movetype=%s model=%s brushsolid=%s roomName=%s boundRoom=%s pos=%s",
				viz:EntIndex(),
				tostring(viz:GetName() or ""),
				tostring(viz.TeamNum),
				tostring(viz.Active),
				tostring(viz.SolidToEnemies),
				tostring(viz:GetSolid()),
				tostring(viz:IsTrigger()),
				tostring(viz:GetMoveType()),
				tostring(viz:GetModel()),
				tostring(viz._tfUseBrushSolid),
				tostring(viz.RespawnRoomName),
				IsValid(viz.RespawnRoom) and tostring(viz.RespawnRoom:GetName() or "") or "nil",
				tostring(viz:GetPos())))
		end
	end)
end

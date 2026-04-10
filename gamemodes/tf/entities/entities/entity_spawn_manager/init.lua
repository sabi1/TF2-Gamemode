ENT.Type = "point"

local MANAGERS_BY_NAME = MANAGERS_BY_NAME or {}
local SPAWN_POINTS_BY_MANAGER = SPAWN_POINTS_BY_MANAGER or {}

local function normalizeName(value)
	value = tostring(value or "")
	if value == "" or value == "nil" then
		return ""
	end
	return value
end

local function getBucket(name)
	name = normalizeName(name)
	if name == "" then
		return nil
	end

	SPAWN_POINTS_BY_MANAGER[name] = SPAWN_POINTS_BY_MANAGER[name] or {}
	return SPAWN_POINTS_BY_MANAGER[name]
end

function TF_GetEntitySpawnManagerByName(name)
	return MANAGERS_BY_NAME[normalizeName(name)]
end

function TF_RegisterEntitySpawnPoint(managerName, point)
	local bucket = getBucket(managerName)
	if not bucket or not IsValid(point) then
		return
	end

	for _, existing in ipairs(bucket) do
		if existing == point then
			return
		end
	end

	bucket[#bucket + 1] = point

	local manager = TF_GetEntitySpawnManagerByName(managerName)
	if IsValid(manager) and manager.RegisterSpawnPoint then
		manager:RegisterSpawnPoint(point)
	end
end

function TF_UnregisterEntitySpawnPoint(managerName, point)
	local bucket = getBucket(managerName)
	if not bucket then
		return
	end

	for i = #bucket, 1, -1 do
		local existing = bucket[i]
		if (not IsValid(existing)) or existing == point then
			table.remove(bucket, i)
		end
	end
end

local function cleanupPoints(tbl)
	local out = {}
	for _, point in ipairs(tbl or {}) do
		if IsValid(point) then
			out[#out + 1] = point
		end
	end
	return out
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.SpawnPoints = self.SpawnPoints or {}
	self:RefreshStateFromProperties()
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "entity_name"
		or key == "entity_count"
		or key == "respawn_time"
		or key == "drop_to_ground"
		or key == "random_rotation" then
		self:RefreshStateFromProperties()
	end
end

function ENT:RefreshStateFromProperties()
	local props = self.Properties or {}
	self.EntityName = normalizeName(props.entity_name)
	self.EntityCount = math.max(0, tonumber(props.entity_count or 0) or 0)
	self.RespawnTime = math.max(0, tonumber(props.respawn_time or 0) or 0)
	self.DropToGround = tobool(props.drop_to_ground)
	self.RandomRotation = tobool(props.random_rotation)
end

function ENT:RegisterSpawnPoint(point)
	if not IsValid(point) then
		return
	end

	self.SpawnPoints = cleanupPoints(self.SpawnPoints)
	for _, existing in ipairs(self.SpawnPoints) do
		if existing == point then
			return
		end
	end

	self.SpawnPoints[#self.SpawnPoints + 1] = point
end

function ENT:GetRespawnTime()
	return self.RespawnTime or 0
end

function ENT:GetManagedPoints()
	local name = normalizeName(self:GetName())
	self.SpawnPoints = cleanupPoints(self.SpawnPoints)

	local bucket = getBucket(name)
	for _, point in ipairs(cleanupPoints(bucket)) do
		self:RegisterSpawnPoint(point)
	end

	return self.SpawnPoints
end

function ENT:GetMaxSpawnedEntities()
	return math.min(#self:GetManagedPoints(), self.EntityCount or 0)
end

function ENT:GetUsedPointCount()
	local used = 0
	for _, point in ipairs(self:GetManagedPoints()) do
		if point.IsUsed and point:IsUsed() then
			used = used + 1
		end
	end
	return used
end

function ENT:GetRandomUnusedIndex()
	local points = self:GetManagedPoints()
	local count = #points
	if count <= 0 then
		return -1
	end

	local startIndex = math.random(count)
	for i = 0, count - 1 do
		local index = ((startIndex + i - 1) % count) + 1
		local point = points[index]
		if IsValid(point) and (not point.IsUsed or not point:IsUsed()) then
			return index
		end
	end

	return -1
end

local function isSpaceEmpty(pos, mins, maxs, ignore)
	local tr = util.TraceHull({
		start = pos,
		endpos = pos,
		mins = mins,
		maxs = maxs,
		mask = MASK_SOLID,
		filter = ignore
	})

	return not tr.Hit
end

function ENT:SpawnEntityAt(index)
	if normalizeName(self.EntityName) == "" then
		return false
	end

	local points = self:GetManagedPoints()
	local point = points[index]
	if not IsValid(point) then
		return false
	end

	local ent = ents.Create(self.EntityName)
	if not IsValid(ent) then
		return false
	end

	local origin = point:GetPos()
	local angles = self.RandomRotation and Angle(0, math.Rand(0, 360), 0) or point:GetAngles()

	ent:SetPos(origin)
	ent:SetAngles(angles)
	ent:Spawn()
	ent:Activate()

	local mins, maxs = ent:WorldSpaceAABB()
	local localMins = mins - ent:GetPos()
	local localMaxs = maxs - ent:GetPos()

	if self.DropToGround then
		local tr = util.TraceHull({
			start = origin,
			endpos = origin + Vector(0, 0, -500),
			mins = localMins,
			maxs = localMaxs,
			mask = MASK_SOLID,
			filter = ent
		})
		origin = tr.Hit and tr.HitPos or origin
		ent:SetPos(origin)
	end

	if not isSpaceEmpty(ent:GetPos(), localMins, localMaxs, ent) then
		ent:Remove()
		return false
	end

	if point.SetEntity then
		point:SetEntity(ent)
	end

	return true
end

function ENT:SpawnEntity()
	return self:SpawnEntityAt(self:GetRandomUnusedIndex())
end

function ENT:SpawnAllEntities()
	local numToSpawn = self:GetMaxSpawnedEntities() - self:GetUsedPointCount()
	while numToSpawn > 0 do
		if not self:SpawnEntity() then
			break
		end
		numToSpawn = numToSpawn - 1
	end
end

function ENT:Activate()
	self:RefreshStateFromProperties()

	local name = normalizeName(self:GetName())
	if name ~= "" then
		MANAGERS_BY_NAME[name] = self
		local bucket = getBucket(name)
		for _, point in ipairs(cleanupPoints(bucket)) do
			self:RegisterSpawnPoint(point)
		end
	end

	if self.EntityName ~= "" and self:GetMaxSpawnedEntities() > 0 then
		self:SpawnAllEntities()
	end
end

function ENT:OnRemove()
	local name = normalizeName(self:GetName())
	if name ~= "" and MANAGERS_BY_NAME[name] == self then
		MANAGERS_BY_NAME[name] = nil
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	name = tostring(name or "")
	if name == "SpawnEntity" then
		return self:SpawnEntity()
	elseif name == "SpawnAllEntities" then
		self:SpawnAllEntities()
		return true
	elseif name == "SetEntityName" then
		self.EntityName = normalizeName(data)
		return true
	elseif name == "SetEntityCount" then
		self.EntityCount = math.max(0, tonumber(data or 0) or 0)
		return true
	elseif name == "SetRespawnTime" then
		self.RespawnTime = math.max(0, tonumber(data or 0) or 0)
		return true
	end
end

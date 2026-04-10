ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.SpawnManagerName = self.SpawnManagerName or ""
	self.NextRespawnCheck = 0
	self:RefreshStateFromProperties()
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "spawn_manager_name" then
		self:RefreshStateFromProperties()
	end
end

function ENT:RefreshStateFromProperties()
	local props = self.Properties or {}
	self.SpawnManagerName = tostring(props.spawn_manager_name or self.SpawnManagerName or "")
	if self.SpawnManagerName == "nil" then
		self.SpawnManagerName = ""
	end
end

function ENT:ResolveManager()
	if IsValid(self.SpawnManager) then
		return self.SpawnManager
	end

	if self.SpawnManagerName == "" then
		return nil
	end

	local manager = TF_GetEntitySpawnManagerByName and TF_GetEntitySpawnManagerByName(self.SpawnManagerName) or nil
	if IsValid(manager) then
		self.SpawnManager = manager
		manager:RegisterSpawnPoint(self)
	end
	return self.SpawnManager
end

function ENT:SetEntity(ent)
	self.ManagedEntity = ent
	self.NextRespawnCheck = 0
end

function ENT:IsUsed()
	return IsValid(self.ManagedEntity)
end

function ENT:ScheduleRespawn(delay)
	delay = math.max(0, tonumber(delay or 0) or 0)
	self.ManagedEntity = nil
	self.NextRespawnCheck = CurTime() + delay
	self:NextThink(CurTime() + math.min(delay, 0.1))
end

function ENT:Think()
	self:ResolveManager()

	if IsValid(self.ManagedEntity) then
		self:NextThink(CurTime() + 1)
		return true
	end

	if (self.NextRespawnCheck or 0) <= 0 then
		self:NextThink(CurTime() + 1)
		return true
	end

	if CurTime() < self.NextRespawnCheck then
		self:NextThink(math.min(self.NextRespawnCheck, CurTime() + 1))
		return true
	end

	local manager = self:ResolveManager()
	if not IsValid(manager) then
		self:NextThink(CurTime() + 5)
		return true
	end

	local nodeFreeTime = (self.NodeFreedAt or 0) + 10
	if CurTime() < nodeFreeTime then
		self:NextThink(math.min(nodeFreeTime, CurTime() + 5))
		return true
	end

	if manager.SpawnEntity and manager:SpawnEntity() then
		self.NextRespawnCheck = 0
		self:NextThink(CurTime() + 1)
		return true
	end

	self:NextThink(CurTime() + 5)
	return true
end

function ENT:Activate()
	self:RefreshStateFromProperties()
	TF_RegisterEntitySpawnPoint(self.SpawnManagerName, self)
	self:ResolveManager()
end

function ENT:OnRemove()
	TF_UnregisterEntitySpawnPoint(self.SpawnManagerName, self)
end

hook.Add("EntityRemoved", "TF_EntitySpawnPointRemovedEntity", function(ent)
	for _, point in ipairs(ents.FindByClass("entity_spawn_point")) do
		if not IsValid(point) then continue end
		if point.ManagedEntity ~= ent then continue end

		local manager = point:ResolveManager()
		point.NodeFreedAt = CurTime()
		point.ManagedEntity = nil
		point.NextRespawnCheck = CurTime() + ((IsValid(manager) and manager.GetRespawnTime and manager:GetRespawnTime()) or 0)
		point:NextThink(CurTime() + 0.1)
	end
end)

function ENT:AcceptInput(name, activator, caller, data)
	name = tostring(name or "")
	if name == "SetSpawnManagerName" then
		TF_UnregisterEntitySpawnPoint(self.SpawnManagerName, self)
		self.SpawnManager = nil
		self.SpawnManagerName = tostring(data or "")
		TF_RegisterEntitySpawnPoint(self.SpawnManagerName, self)
		self:ResolveManager()
		return true
	end
end

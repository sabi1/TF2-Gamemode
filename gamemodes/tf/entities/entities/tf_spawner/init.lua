ENT.Type = "point"

local function hasWinningRoundState()
	return GAMEMODE and GAMEMODE.RoundHasWinner
end

local function isWaitingForPlayers()
	for _, timerEnt in ipairs(ents.FindByClass("team_round_timer")) do
		if IsValid(timerEnt) and timerEnt.WaitingForPlayers then
			return true
		end
	end
	return false
end

local function findTemplateByName(name)
	name = string.Trim(tostring(name or ""))
	if name == "" then
		return nil
	end

	for _, ent in ipairs(ents.FindByName(name)) do
		if IsValid(ent) and ent.Instantiate then
			return ent
		end
	end

	return nil
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.SpawnedEntities = self.SpawnedEntities or {}
	self:ResetSpawner()
	self:RefreshStateFromProperties()
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	self:RefreshStateFromProperties()
end

function ENT:RefreshStateFromProperties()
	local props = self.Properties or {}
	self.SpawnCount = math.max(0, tonumber(props.count or 0) or 0)
	self.MaxActiveCount = math.max(0, tonumber(props.maxactive or 0) or 0)
	self.SpawnInterval = math.max(0, tonumber(props.interval or 0) or 0)
	self.TemplateName = tostring(props.template or "")
end

function ENT:ResetSpawner()
	self.Expended = false
	self.SpawnCountRemaining = 0
	self.SpawnedEntities = {}
	self:SetNWBool("Enabled", false)
	self:SetNextThink(math.huge)
end

function ENT:CleanupSpawnedEntities()
	for i = #self.SpawnedEntities, 1, -1 do
		local child = self.SpawnedEntities[i]
		if not IsValid(child) then
			table.remove(self.SpawnedEntities, i)
			if self.TriggerOutput then
				self:TriggerOutput("OnKilled", self, self)
			end
		end
	end
end

function ENT:GetActiveSpawnCount()
	self:CleanupSpawnedEntities()
	return #self.SpawnedEntities
end

function ENT:CanSpawnNow()
	if hasWinningRoundState() then
		return false
	end
	if isWaitingForPlayers() then
		return false
	end
	return true
end

function ENT:SpawnFromTemplate()
	local template = findTemplateByName(self.TemplateName)
	if not IsValid(template) then
		return false
	end

	local child = template:Instantiate()
	if not IsValid(child) then
		return false
	end

	child:SetPos(self:GetPos())
	child:SetAngles(self:GetAngles())
	child:SetOwner(self)
	child:Spawn()
	child:Activate()

	table.insert(self.SpawnedEntities, child)
	if self.TriggerOutput then
		self:TriggerOutput("OnSpawned", child, self)
	end

	self.SpawnCountRemaining = math.max(0, (self.SpawnCountRemaining or 0) - 1)
	if self.SpawnCountRemaining <= 0 then
		self.Expended = true
		self:SetNWBool("Enabled", false)
		self:SetNextThink(math.huge)
		if self.TriggerOutput then
			self:TriggerOutput("OnExpended", self, self)
		end
	else
		self:SetNextThink(CurTime() + self.SpawnInterval)
	end

	return true
end

function ENT:Think()
	if not self:GetNWBool("Enabled", false) then
		return false
	end

	if not self:CanSpawnNow() then
		self:SetNextThink(CurTime() + 1)
		return true
	end

	if self.MaxActiveCount > 0 and self:GetActiveSpawnCount() >= self.MaxActiveCount then
		self:SetNextThink(CurTime() + 0.1)
		return true
	end

	if not self:SpawnFromTemplate() then
		self:SetNextThink(CurTime() + 1)
		return true
	end

	return true
end

function ENT:InputReset()
	self:ResetSpawner()
end

function ENT:InputEnable()
	if self.Expended then
		return
	end

	self:SetNWBool("Enabled", true)
	if (self.SpawnCountRemaining or 0) <= 0 then
		self.SpawnCountRemaining = self.SpawnCount
	end
	self:SetNextThink(CurTime())
end

function ENT:InputDisable()
	self:SetNWBool("Enabled", false)
	self:SetNextThink(math.huge)
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input" .. tostring(name or "")] or self["Input_" .. tostring(name or "")]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
	return false
end

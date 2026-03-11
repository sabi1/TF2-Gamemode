ENT.Type = "point"

local function to_num(v, fallback)
	local n = tonumber(v)
	if n == nil then return fallback end
	return n
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Active = false
	self.NextSpawn = 0
	self.Spawned = {}
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:CleanupSpawned()
	local alive = {}
	for _, ent in ipairs(self.Spawned or {}) do
		if IsValid(ent) then
			alive[#alive + 1] = ent
		end
	end
	self.Spawned = alive
end

function ENT:GetSpawnCap()
	return math.max(1, to_num(self.Properties.max_zombies, to_num(self.Properties.maxactive, 10)))
end

function ENT:GetSpawnRate()
	return math.max(0.05, to_num(self.Properties.spawnrate, to_num(self.Properties.spawn_interval, 1.0)))
end

function ENT:SpawnOne()
	self:CleanupSpawned()
	if #self.Spawned >= self:GetSpawnCap() then return end

	local spawnPos = self:GetPos()
	local z = ents.Create("tf_zombie")
	if not IsValid(z) then return end
	z:SetPos(spawnPos)
	z:SetAngles(Angle(0, math.random(0, 359), 0))
	z:SetOwner(self)
	z:Spawn()
	z:Activate()
	self.Spawned[#self.Spawned + 1] = z

	if self.TriggerOutput then
		self:TriggerOutput("OnSpawnZombie", self)
	end
end

function ENT:Think()
	if not self.Active then return end
	if CurTime() < (self.NextSpawn or 0) then return end

	self.NextSpawn = CurTime() + self:GetSpawnRate()
	self:SpawnOne()
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" or name == "startspawning" then
		self.Active = true
		self.NextSpawn = CurTime() + 0.01
	elseif name == "disable" or name == "stopspawning" then
		self.Active = false
	elseif name == "spawnzombie" or name == "forcespawn" then
		self:SpawnOne()
	elseif name == "killzombies" then
		for _, ent in ipairs(self.Spawned or {}) do
			if IsValid(ent) then
				ent:Remove()
			end
		end
		self.Spawned = {}
	elseif name == "setmaxactive" then
		local maxActive = tonumber(data)
		if maxActive then
			self.Properties.maxactive = maxActive
			self.Properties.max_zombies = maxActive
		end
	elseif name == "setspawnrate" then
		local spawnRate = tonumber(data)
		if spawnRate then
			self.Properties.spawnrate = spawnRate
		end
	end
end

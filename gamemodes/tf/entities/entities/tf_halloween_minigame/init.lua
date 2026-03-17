ENT.Type = "point"

local function GetBase()
	local stored = scripted_ents.GetStored("tf_base_minigame")
	return stored and stored.t or nil
end

function ENT:Initialize()
	local base = GetBase()
	if base and base.Initialize then
		base.Initialize(self)
	else
		self.Properties = self.Properties or {}
	end

	self.MinigameType = tonumber(self.Properties and self.Properties.minigametype) or 1
	self.BossSpawnTarget = tostring(self.Properties and self.Properties.enablespawnboss or "")
end

function ENT:KeyValue(key, value)
	local base = GetBase()
	if base and base.KeyValue then
		base.KeyValue(self, key, value)
	else
		key = string.lower(key)
		self.Properties = self.Properties or {}
		if tonumber(value) then
			value = tonumber(value)
		end
		self.Properties[key] = value
	end

	key = string.lower(key)
	if key == "minigametype" then
		self.MinigameType = tonumber(value) or 1
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "kartwinanimationred" or name == "kartwinanimationblue" or name == "kartloseanimationred" or name == "kartloseanimationblue" then
		return true
	elseif name == "enablespawnboss" then
		self.BossSpawnTarget = tostring(data or "")
		SetGlobalString("tf_halloween_minigame_boss_target", self.BossSpawnTarget)
		return true
	elseif name == "disablespawnboss" then
		self.BossSpawnTarget = ""
		SetGlobalString("tf_halloween_minigame_boss_target", "")
		return true
	end

	local base = GetBase()
	if base and base.AcceptInput then
		return base.AcceptInput(self, name, activator, caller, data)
	end
	return false
end

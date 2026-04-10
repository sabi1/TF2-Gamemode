ENT.Type = "point"

local TELEPORT_LOCATIONS_BY_NAME = TELEPORT_LOCATIONS_BY_NAME or {}

local function normalizeTeleportName(value)
	value = string.Trim(tostring(value or ""))
	if value == "" or value == "nil" then
		return ""
	end
	return value
end

local function cleanupTeleportBucket(name)
	local bucket = TELEPORT_LOCATIONS_BY_NAME[name]
	if not bucket then
		return nil
	end

	for i = #bucket, 1, -1 do
		if not IsValid(bucket[i]) then
			table.remove(bucket, i)
		end
	end

	return bucket
end

function TF_GetTeleportLocations(name)
	name = normalizeTeleportName(name)
	if name == "" then
		return {}
	end

	return cleanupTeleportBucket(name) or {}
end

function TF_GetRandomTeleportLocation(name)
	local locations = TF_GetTeleportLocations(name)
	if #locations <= 0 then
		return nil
	end

	return locations[math.random(#locations)]
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self:RefreshStateFromProperties()
	self:RegisterTeleportLocation()
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "teleport_name" or key == "name" or key == "targetname" then
		self:RefreshStateFromProperties()
	end
end

function ENT:RefreshStateFromProperties()
	local props = self.Properties or {}
	self.TeleportName = normalizeTeleportName(
		props.teleport_name or props.targetname or self:GetName()
	)
end

function ENT:RegisterTeleportLocation()
	if self.RegisteredTeleportName == self.TeleportName then
		return
	end

	self:UnregisterTeleportLocation()

	if self.TeleportName == "" then
		return
	end

	TELEPORT_LOCATIONS_BY_NAME[self.TeleportName] = cleanupTeleportBucket(self.TeleportName) or {}
	table.insert(TELEPORT_LOCATIONS_BY_NAME[self.TeleportName], self)
	self.RegisteredTeleportName = self.TeleportName
end

function ENT:UnregisterTeleportLocation()
	local name = normalizeTeleportName(self.RegisteredTeleportName)
	if name == "" then
		return
	end

	local bucket = cleanupTeleportBucket(name)
	if not bucket then
		self.RegisteredTeleportName = ""
		return
	end

	for i = #bucket, 1, -1 do
		if bucket[i] == self then
			table.remove(bucket, i)
		end
	end

	self.RegisteredTeleportName = ""
end

function ENT:Activate()
	self:RefreshStateFromProperties()
	self:RegisterTeleportLocation()
end

function ENT:OnRemove()
	self:UnregisterTeleportLocation()
end

function ENT:AcceptInput(name)
	name = string.lower(tostring(name or ""))

	if name == "enable" or name == "disable" then
		-- Kept for Hammer compatibility. Source locations are just markers.
		return true
	end

	return false
end

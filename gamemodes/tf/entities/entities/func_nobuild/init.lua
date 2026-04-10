ENT.Base = "base_brush"
ENT.Type = "brush"

local OBJ_SENTRY = OBJ_SENTRYGUN or 2
local OBJ_DISPENSER_ID = OBJ_DISPENSER or 0
local OBJ_TELEPORTER_ID = OBJ_TELEPORTER or 1

local function to_bool(value, default)
	if value == nil then return default end
	if isbool(value) then return value end
	if isnumber(value) then return value ~= 0 end
	if isstring(value) then
		value = string.Trim(string.lower(value))
		if value == "1" or value == "true" or value == "yes" then return true end
		if value == "0" or value == "false" or value == "no" then return false end
	end
	return default
end

local function ensure_registry()
	if not GAMEMODE then return end
	GAMEMODE.FuncNoBuildZones = GAMEMODE.FuncNoBuildZones or {}
end

local function object_center(ent)
	if not IsValid(ent) then return nil end
	local mins, maxs = ent:WorldSpaceAABB()
	return (mins + maxs) * 0.5
end

local function point_is_inside_zone(zone, point)
	if not IsValid(zone) or not isvector(point) then return false end
	if isfunction(zone.PointIsWithin) then
		return zone:PointIsWithin(point)
	end

	local mins, maxs = zone:OBBMins(), zone:OBBMaxs()
	local localPos = zone:WorldToLocal(point)
	return localPos.x >= mins.x and localPos.x <= maxs.x
		and localPos.y >= mins.y and localPos.y <= maxs.y
		and localPos.z >= mins.z and localPos.z <= maxs.z
end

function TF_PointInNoBuild(point, objectType, teamNum)
	if not isvector(point) then return false end
	local zones = GAMEMODE and GAMEMODE.FuncNoBuildZones or nil
	if not zones then return false end

	for zone in pairs(zones) do
		if not IsValid(zone) then
			zones[zone] = nil
			continue
		end
		if not zone:GetActive() then continue end
		if teamNum and teamNum ~= TEAM_UNASSIGNED and zone.TeamNum ~= TEAM_UNASSIGNED and zone.TeamNum ~= teamNum then continue end
		if not zone:PreventsBuildOf(objectType) then continue end
		if point_is_inside_zone(zone, point) then
			return true, zone
		end
	end

	return false
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self:SetNoDraw(true)
	self.TeamNum = TEAM_UNASSIGNED
	self.Active = true
	self.AllowSentry = false
	self.AllowDispenser = false
	self.AllowTeleporters = false
	self.DestroyBuildingsOnActive = false
	if self.SetTrigger then
		self:SetTrigger(true)
	end
	self:RefreshSettings()

	ensure_registry()
	if GAMEMODE and GAMEMODE.FuncNoBuildZones then
		GAMEMODE.FuncNoBuildZones[self] = true
	end
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "teamnum" then
		local teamNum = tonumber(value)
		if teamNum == 2 then
			self.TeamNum = TEAM_RED
		elseif teamNum == 3 then
			self.TeamNum = TEAM_BLU
		else
			self.TeamNum = TEAM_UNASSIGNED
		end
	else
		self:RefreshSettings()
	end
end

function ENT:RefreshSettings()
	self.AllowSentry = to_bool(self.Properties.allowsentry, false)
	self.AllowDispenser = to_bool(self.Properties.allowdispenser, false)
	self.AllowTeleporters = to_bool(self.Properties.allowteleporters, false)
	self.DestroyBuildingsOnActive = to_bool(self.Properties.destroybuildings, false)
	self.Active = not to_bool(self.Properties.startdisabled, false)
end

function ENT:SetActive(active)
	local wasActive = self.Active and true or false
	self.Active = active and true or false

	if self.Active and not wasActive and self.DestroyBuildingsOnActive then
		self:DestroyTouchingBuildings()
	end
end

function ENT:GetActive()
	return self.Active and true or false
end

function ENT:PreventsBuildOf(objectType)
	if objectType == OBJ_SENTRY and self.AllowSentry then
		return false
	end
	if objectType == OBJ_DISPENSER_ID and self.AllowDispenser then
		return false
	end
	if objectType == OBJ_TELEPORTER_ID and self.AllowTeleporters then
		return false
	end
	return true
end

function ENT:DestroyTouchingBuildings()
	for _, className in ipairs({"obj_sentrygun", "obj_dispenser", "obj_teleporter"}) do
		for _, ent in ipairs(ents.FindByClass(className)) do
			if not IsValid(ent) then continue end
			if ent.IsMapPlaced and ent:IsMapPlaced() then continue end
			if self.TeamNum ~= TEAM_UNASSIGNED and ent:Team() ~= self.TeamNum then continue end

			local origin = ent.GetPos and ent:GetPos() or nil
			local center = object_center(ent)
			local inside = (isvector(origin) and point_is_inside_zone(self, origin)) or (isvector(center) and point_is_inside_zone(self, center))
			if not inside then continue end

			if ent.DetonateObject then
				ent:DetonateObject()
			elseif ent.Explode then
				ent:Explode()
			else
				ent:Remove()
			end
		end
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "setactive" or name == "enable" then
		self:SetActive(true)
		return true
	elseif name == "setinactive" or name == "disable" then
		self:SetActive(false)
		return true
	elseif name == "toggleactive" or name == "toggle" then
		self:SetActive(not self:GetActive())
		return true
	end
	return false
end

function ENT:OnRemove()
	if GAMEMODE and GAMEMODE.FuncNoBuildZones then
		GAMEMODE.FuncNoBuildZones[self] = nil
	end
end

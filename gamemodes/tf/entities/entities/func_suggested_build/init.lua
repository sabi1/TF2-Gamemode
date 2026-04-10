ENT.Base = "base_brush"
ENT.Type = "brush"

local OBJECT_ANY = 0
local OBJECT_SENTRY = 1
local OBJECT_DISPENSER = 2
local OBJECT_TELE_ENTRANCE = 3
local OBJECT_TELE_EXIT = 4

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
	GAMEMODE.FuncSuggestedBuildZones = GAMEMODE.FuncSuggestedBuildZones or {}
end

local function resolve_ent(name)
	if not isstring(name) or name == "" then return NULL end
	return ents.FindByName(name)[1] or NULL
end

local function get_object_descriptor(ent)
	if not IsValid(ent) then return nil, nil end
	local className = ent:GetClass()
	if className == "obj_sentrygun" then
		return OBJECT_SENTRY, 0
	elseif className == "obj_dispenser" then
		return OBJECT_DISPENSER, 0
	elseif className == "obj_teleporter" then
		local mode = ent.GetBuildMode and ent:GetBuildMode() or 0
		if mode == 0 then
			return OBJECT_TELE_ENTRANCE, mode
		end
		return OBJECT_TELE_EXIT, mode
	end
	return nil, nil
end

local function is_point_inside_brush(brush, point)
	if not IsValid(brush) or not isvector(point) then return false end
	if isfunction(brush.PointIsWithin) then
		return brush:PointIsWithin(point)
	end

	local mins, maxs = brush:OBBMins(), brush:OBBMaxs()
	local localPos = brush:WorldToLocal(point)
	return localPos.x >= mins.x and localPos.x <= maxs.x
		and localPos.y >= mins.y and localPos.y <= maxs.y
		and localPos.z >= mins.z and localPos.z <= maxs.z
end

function TF_NotifyObjectBuiltInSuggestedArea(baseObject)
	local zones = GAMEMODE and GAMEMODE.FuncSuggestedBuildZones or nil
	if not zones or not IsValid(baseObject) then return false end

	local buildType = get_object_descriptor(baseObject)
	local origin = baseObject:GetPos()

	for zone in pairs(zones) do
		if not IsValid(zone) then
			zones[zone] = nil
			continue
		end
		if not zone:GetActive() then continue end
		if not zone:MatchesObject(baseObject, buildType) then continue end
		if not is_point_inside_brush(zone, origin) then continue end

		if not zone:IsFacingRequiredEntity(baseObject) then
			zone:TriggerOutput("OnBuildNotFacing", baseObject)
		else
			zone:TriggerOutput("OnBuildInsideArea", baseObject)
			if zone.NeverDies then
				baseObject.CannotDie = true
			end
		end
		return true
	end

	return false
end

function TF_NotifyObjectUpgradedInSuggestedArea(baseObject)
	local zones = GAMEMODE and GAMEMODE.FuncSuggestedBuildZones or nil
	if not zones or not IsValid(baseObject) then return false end

	local buildType = get_object_descriptor(baseObject)
	local origin = baseObject:GetPos()

	for zone in pairs(zones) do
		if not IsValid(zone) then
			zones[zone] = nil
			continue
		end
		if not zone:GetActive() then continue end
		if not zone:MatchesObject(baseObject, buildType) then continue end
		if not is_point_inside_brush(zone, origin) then continue end
		if not zone:IsFacingRequiredEntity(baseObject) then continue end

		zone:TriggerOutput("OnBuildingUpgraded", baseObject)
		return true
	end

	return false
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Active = true
	self.ObjectType = OBJECT_ANY
	self.FaceEntityName = ""
	self.FaceEntityFOV = -1
	self.FaceEntity = NULL
	self.NeverDies = false
	self:SetNoDraw(true)
	if self.SetTrigger then
		self:SetTrigger(true)
	end
	self:RefreshSettings()

	ensure_registry()
	if GAMEMODE and GAMEMODE.FuncSuggestedBuildZones then
		GAMEMODE.FuncSuggestedBuildZones[self] = true
	end
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}

	if string.StartWith(key, "on") then
		self:StoreOutput(key, value)
		return
	end

	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	self:RefreshSettings()
end

function ENT:RefreshSettings()
	self.ObjectType = tonumber(self.Properties.object_type) or OBJECT_ANY
	self.FaceEntityName = tostring(self.Properties.face_entity or "")
	local fov = tonumber(self.Properties.face_entity_fov)
	self.FaceEntityFOV = math.cos(math.rad(fov or 180))
	self.NeverDies = bit.band(self:GetSpawnFlags() or 0, 1) ~= 0
	self.Active = not to_bool(self.Properties.startdisabled, false)
	self.FaceEntity = resolve_ent(self.FaceEntityName)
end

function ENT:GetActive()
	return self.Active and true or false
end

function ENT:SetActive(active)
	self.Active = active and true or false
end

function ENT:MatchesObject(baseObject, objectType)
	objectType = objectType or select(1, get_object_descriptor(baseObject))
	if objectType == nil then return false end
	if self.ObjectType == OBJECT_ANY then return true end
	return self.ObjectType == objectType
end

function ENT:IsFacingRequiredEntity(baseObject)
	if not IsValid(self.FaceEntity) then
		self.FaceEntity = resolve_ent(self.FaceEntityName)
	end
	if not IsValid(self.FaceEntity) then
		return true
	end

	local facing = baseObject:GetAngles():Forward()
	local toEntity = self.FaceEntity:GetPos() - baseObject:GetPos()
	toEntity.z = 0
	facing.z = 0
	if toEntity:LengthSqr() <= 0 then return false end
	toEntity:Normalize()
	facing:Normalize()
	return toEntity:Dot(facing) > self.FaceEntityFOV
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
	if GAMEMODE and GAMEMODE.FuncSuggestedBuildZones then
		GAMEMODE.FuncSuggestedBuildZones[self] = nil
	end
end

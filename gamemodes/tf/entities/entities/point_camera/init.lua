AddCSLuaFile()

ENT.Type = "point"

local CAM_THINK_INTERVAL = 0.05

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

local function parse_color(value)
	local parts = string.Explode(" ", tostring(value or "0 0 0"), false)
	return Color(
		tonumber(parts[1]) or 0,
		tonumber(parts[2]) or 0,
		tonumber(parts[3]) or 0,
		255
	)
end

local function ensure_registry()
	if not GAMEMODE then return end
	GAMEMODE.PointCameras = GAMEMODE.PointCameras or {}
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.CameraEnabled = not to_bool(bit.band(self:GetSpawnFlags() or 0, 1) ~= 0, false)
	self.CameraActive = false
	self.CurrentFOV = tonumber(self.Properties.fov) or 90
	self.TargetFOV = self.CurrentFOV
	self.DegreesPerSecond = 0
	self.Resolution = tonumber(self.Properties.resolution) or 0
	self.UseScreenAspectRatio = to_bool(self.Properties.usescreenaspectratio, false)
	self.FogEnabled = to_bool(self.Properties.fogenable, false)
	self.FogColor = parse_color(self.Properties.fogcolor)
	self.FogStart = tonumber(self.Properties.fogstart) or 2048
	self.FogEnd = tonumber(self.Properties.fogend) or 4096
	self.FogMaxDensity = tonumber(self.Properties.fogmaxdensity) or 1
	self:SetNoDraw(true)

	ensure_registry()
	if GAMEMODE and GAMEMODE.PointCameras then
		GAMEMODE.PointCameras[self] = true
	end

	self:SetCameraActive(self.CameraEnabled)
	self:SyncNetworkState()
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:SyncNetworkState()
	self:SetNWBool("TFPointCameraActive", self.CameraActive and true or false)
	self:SetNWBool("TFPointCameraEnabled", self.CameraEnabled and true or false)
	self:SetNWFloat("TFPointCameraFOV", tonumber(self.CurrentFOV) or 90)
	self:SetNWFloat("TFPointCameraResolution", tonumber(self.Resolution) or 0)
	self:SetNWBool("TFPointCameraUseScreenAspectRatio", self.UseScreenAspectRatio and true or false)
	self:SetNWBool("TFPointCameraFogEnabled", self.FogEnabled and true or false)
	self:SetNWVector("TFPointCameraFogColor", Vector(self.FogColor.r, self.FogColor.g, self.FogColor.b))
	self:SetNWFloat("TFPointCameraFogStart", tonumber(self.FogStart) or 2048)
	self:SetNWFloat("TFPointCameraFogEnd", tonumber(self.FogEnd) or 4096)
	self:SetNWFloat("TFPointCameraFogMaxDensity", tonumber(self.FogMaxDensity) or 1)
end

function ENT:SetCameraActive(active)
	active = active and true or false
	self.CameraActive = active
	self.CameraEnabled = active
	self:SyncNetworkState()
end

function ENT:IsCameraActive()
	return self.CameraActive and true or false
end

function ENT:GetCameraFOV()
	return tonumber(self.CurrentFOV) or 90
end

function ENT:InputChangeFOV(_, _, data)
	local parse = string.Explode(" ", tostring(data or ""), false)
	local targetFOV = tonumber(parse[1]) or self.CurrentFOV
	local changeTime = tonumber(parse[2]) or 1
	if changeTime <= 0 then
		self.CurrentFOV = targetFOV
		self.TargetFOV = targetFOV
		self.DegreesPerSecond = 0
		self:SyncNetworkState()
		return
	end

	self.TargetFOV = targetFOV
	self.DegreesPerSecond = (self.TargetFOV - self.CurrentFOV) / changeTime
	self:NextThink(CurTime())
end

function ENT:InputSetOn()
	self:SetCameraActive(true)
end

function ENT:InputSetOff()
	self:SetCameraActive(false)
end

function ENT:InputSetOnAndTurnOthersOff()
	ensure_registry()
	if GAMEMODE and GAMEMODE.PointCameras then
		for ent in pairs(GAMEMODE.PointCameras) do
			if IsValid(ent) and ent ~= self and ent.InputSetOff then
				ent:InputSetOff()
			end
		end
	end
	self:SetCameraActive(true)
end

function ENT:Think()
	if self.DegreesPerSecond == 0 then
		return false
	end

	self:NextThink(CurTime() + CAM_THINK_INTERVAL)

	local newFOV = self.CurrentFOV + (self.DegreesPerSecond * CAM_THINK_INTERVAL)
	if self.DegreesPerSecond < 0 then
		if newFOV <= self.TargetFOV then
			newFOV = self.TargetFOV
			self.DegreesPerSecond = 0
		end
	else
		if newFOV >= self.TargetFOV then
			newFOV = self.TargetFOV
			self.DegreesPerSecond = 0
		end
	end

	self.CurrentFOV = newFOV
	self:SyncNetworkState()
	return true
end

function ENT:AcceptInput(name, activator, caller, data)
	name = tostring(name or "")
	local fn = self["Input" .. name]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
	return false
end

function ENT:OnRemove()
	if GAMEMODE and GAMEMODE.PointCameras then
		GAMEMODE.PointCameras[self] = nil
	end
end

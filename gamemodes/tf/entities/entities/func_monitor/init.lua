ENT.Base = "base_brush"
ENT.Type = "brush"

local function resolve_camera(name)
	if not isstring(name) or name == "" then
		return NULL
	end

	local matches = ents.FindByName(name)
	for _, ent in ipairs(matches) do
		if IsValid(ent) and ent:GetClass() == "point_camera" then
			return ent
		end
	end

	return NULL
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Enabled = true
	self.Camera = NULL
	self:SetNoDraw(true)

	timer.Simple(0, function()
		if not IsValid(self) then return end
		self:InitPostEntity()
		self.PostEntityDone = true
	end)
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:InitPostEntity()
	self.Camera = resolve_camera(self.Properties.target or "")
	self:SyncNetworkState()
end

function ENT:SyncNetworkState()
	self:SetNWBool("TFMonitorEnabled", self.Enabled and true or false)
	self:SetNWString("TFMonitorCameraName", tostring(self.Properties.target or ""))
	self:SetNWEntity("TFMonitorCamera", IsValid(self.Camera) and self.Camera or NULL)
end

function ENT:GetMonitorCamera()
	if IsValid(self.Camera) then
		return self.Camera
	end
	self.Camera = resolve_camera(self.Properties.target or "")
	self:SyncNetworkState()
	return self.Camera
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "toggle" then
		self.Enabled = not self.Enabled
		self:SyncNetworkState()
		return true
	end
	if name == "enable" then
		self.Enabled = true
		self:SyncNetworkState()
		return true
	end
	if name == "disable" then
		self.Enabled = false
		self:SyncNetworkState()
		return true
	end
	if name == "setcamera" then
		self.Properties.target = tostring(data or "")
		self.Camera = resolve_camera(self.Properties.target)
		self:SyncNetworkState()
		return true
	end
	return false
end

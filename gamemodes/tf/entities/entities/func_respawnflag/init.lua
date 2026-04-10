ENT.Base = "base_brush"
ENT.Type = "brush"

local function to_bool(value, default)
	if value == nil then return default end
	if isbool(value) then return value end
	local num = tonumber(value)
	if num ~= nil then return num ~= 0 end
	local text = string.lower(string.Trim(tostring(value)))
	if text == "true" or text == "yes" or text == "on" then return true end
	if text == "false" or text == "no" or text == "off" then return false end
	return default
end

local function point_inside_brush(ent, point)
	if not (IsValid(ent) and isvector(point)) then return false end
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	local localPos = ent:WorldToLocal(point)
	return localPos.x >= mins.x and localPos.x <= maxs.x
		and localPos.y >= mins.y and localPos.y <= maxs.y
		and localPos.z >= mins.z and localPos.z <= maxs.z
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	self:SetTrigger(true)
	if SERVER then
		GAMEMODE.RespawnFlagZones = GAMEMODE.RespawnFlagZones or {}
		GAMEMODE.RespawnFlagZones[self] = true
	end
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if key == "startdisabled" or key == "start_disabled" or key == "disabled" then
		self.Disabled = to_bool(value, false)
	end
end

function ENT:StartTouch(ent)
	if self.Disabled then return end
	if not (IsValid(ent) and ent:IsPlayer() and ent.HasTheFlag and ent:HasTheFlag()) then return end

	local flag = ent.GetItem and ent:GetItem() or nil
	if ent.DropFlag then
		ent:DropFlag()
	end
	if IsValid(flag) and flag.ResetFlag then
		flag:ResetFlag()
	end
end

function ENT:Touch(ent)
	self:StartTouch(ent)
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Disabled = false
		return true
	elseif name == "disable" then
		self.Disabled = true
		return true
	elseif name == "toggle" then
		self.Disabled = not self.Disabled
		return true
	end
	return false
end

function ENT:OnRemove()
	if SERVER and GAMEMODE.RespawnFlagZones then
		GAMEMODE.RespawnFlagZones[self] = nil
	end
end

function TF_PointInRespawnFlagZone(pos)
	if not (GAMEMODE and GAMEMODE.RespawnFlagZones and isvector(pos)) then return false end
	for zone in pairs(GAMEMODE.RespawnFlagZones) do
		if IsValid(zone) and not zone.Disabled and point_inside_brush(zone, pos) then
			return true
		end
	end
	return false
end

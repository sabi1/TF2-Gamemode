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
	self.TeamNum = TEAM_UNASSIGNED
	self:SetTrigger(true)
	if SERVER then
		GAMEMODE.NoGrenadeZones = GAMEMODE.NoGrenadeZones or {}
		GAMEMODE.NoGrenadeZones[self] = true
	end
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if key == "startdisabled" or key == "start_disabled" then
		self.Disabled = to_bool(value, false)
	elseif key == "teamnum" then
		local teamNum = tonumber(value)
		if teamNum == 2 then
			self.TeamNum = TEAM_RED
		elseif teamNum == 3 then
			self.TeamNum = TEAM_BLU
		else
			self.TeamNum = TEAM_UNASSIGNED
		end
	end
end

function ENT:StartTouch(ent)
end

function ENT:EndTouch(ent)
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
	if SERVER and GAMEMODE.NoGrenadeZones then
		GAMEMODE.NoGrenadeZones[self] = nil
	end
end

function ENT:IsDisabled()
	return self.Disabled == true
end

function ENT:ContainsPoint(pos)
	return point_inside_brush(self, pos)
end

function TF_InNoGrenadeZone(entOrPos)
	if not (GAMEMODE and GAMEMODE.NoGrenadeZones) then return false end
	local pos = isvector(entOrPos) and entOrPos or (IsValid(entOrPos) and entOrPos.GetPos and entOrPos:GetPos() or nil)
	local teamNum = IsValid(entOrPos) and entOrPos.Team and entOrPos:Team() or TEAM_UNASSIGNED
	if not isvector(pos) then return false end

	for zone in pairs(GAMEMODE.NoGrenadeZones) do
		if not IsValid(zone) or zone:IsDisabled() then continue end
		if zone:ContainsPoint(pos) then
			local zoneTeam = zone.TeamNum or TEAM_UNASSIGNED
			if zoneTeam == TEAM_UNASSIGNED or zoneTeam == teamNum then
				return true
			end
		end
	end
	return false
end

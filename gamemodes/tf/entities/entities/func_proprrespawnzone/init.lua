ENT.Base = "base_brush"
ENT.Type = "brush"

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
	if SERVER then
		GAMEMODE.PropRespawnZones = GAMEMODE.PropRespawnZones or {}
		GAMEMODE.PropRespawnZones[self] = true
	end
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:StartTouch(ent)
end

function ENT:EndTouch(ent)
end

function ENT:AcceptInput(name, activator, caller, data)
	return false
end

function ENT:OnRemove()
	if SERVER and GAMEMODE.PropRespawnZones then
		GAMEMODE.PropRespawnZones[self] = nil
	end
end

function ENT:ContainsPoint(pos)
	return point_inside_brush(self, pos)
end

function TF_FindPropRespawnZone(pos)
	if not (GAMEMODE and GAMEMODE.PropRespawnZones and isvector(pos)) then return nil end
	for zone in pairs(GAMEMODE.PropRespawnZones) do
		if IsValid(zone) and zone:ContainsPoint(pos) then
			return zone
		end
	end
	return nil
end

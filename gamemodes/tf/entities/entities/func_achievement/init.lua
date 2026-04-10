ENT.Base = "base_brush"
ENT.Type = "brush"

local ACHIEVEMENT_ZONES = ACHIEVEMENT_ZONES or {}

local function refreshAchievementZones()
	for i = #ACHIEVEMENT_ZONES, 1, -1 do
		if not IsValid(ACHIEVEMENT_ZONES[i]) then
			table.remove(ACHIEVEMENT_ZONES, i)
		end
	end
end

function InAchievementZone(ent)
	if not IsValid(ent) then
		return nil
	end

	refreshAchievementZones()

	local origin = ent.WorldSpaceCenter and ent:WorldSpaceCenter() or ent:GetPos()
	local entTeam = GAMEMODE and GAMEMODE.EntityTeam and GAMEMODE:EntityTeam(ent) or ent:Team()

	for _, zone in ipairs(ACHIEVEMENT_ZONES) do
		if IsValid(zone) and not zone:IsDisabled() and zone:PointIsWithin(origin) then
			local zoneTeam = zone.GetTeamNumber and zone:GetTeamNumber() or zone:Team()
			if not zoneTeam or zoneTeam == TEAM_UNASSIGNED or zoneTeam == 0 or zoneTeam == entTeam then
				return zone
			end
		end
	end

	return nil
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	self.ZoneID = tonumber(self.Properties.zone_id or 0) or 0

	self:InitTrigger()
	self:AddSpawnFlags(SF_TRIGGER_ALLOW_ALL)
	self:AddEffects(EF_NODRAW)

	refreshAchievementZones()
	table.insert(ACHIEVEMENT_ZONES, self)
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "zone_id" then
		self.ZoneID = tonumber(value or 0) or 0
	end
end

function ENT:IsDisabled()
	return self.Disabled == true
end

function ENT:SetDisabled(disabled)
	self.Disabled = disabled == true
end

function ENT:AcceptInput(name)
	name = string.lower(tostring(name or ""))

	if name == "enable" then
		self:SetDisabled(false)
		return true
	end

	if name == "disable" then
		self:SetDisabled(true)
		return true
	end

	if name == "toggle" then
		self:SetDisabled(not self:IsDisabled())
		return true
	end

	return false
end

function ENT:OnRemove()
	refreshAchievementZones()
end

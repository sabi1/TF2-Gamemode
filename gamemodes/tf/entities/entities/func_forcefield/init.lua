ENT.Base = "base_brush"
ENT.Type = "brush"

local function parse_team_num(value)
	local num = tonumber(value)
	if num == 2 then return TEAM_RED end
	if num == 3 then return TEAM_BLU end
	return TEAM_UNASSIGNED
end

local function point_inside_brush(ent, point)
	if not (IsValid(ent) and isvector(point)) then return false end
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	local localPos = ent:WorldToLocal(point)
	return localPos.x >= mins.x and localPos.x <= maxs.x
		and localPos.y >= mins.y and localPos.y <= maxs.y
		and localPos.z >= mins.z and localPos.z <= maxs.z
end

local function segment_hits_aabb(startPos, endPos, mins, maxs)
	local dir = endPos - startPos
	local tMin, tMax = 0, 1

	for _, axis in ipairs({ "x", "y", "z" }) do
		local s = startPos[axis]
		local d = dir[axis]
		local minB = mins[axis]
		local maxB = maxs[axis]

		if math.abs(d) < 0.0001 then
			if s < minB or s > maxB then
				return false
			end
		else
			local inv = 1 / d
			local t1 = (minB - s) * inv
			local t2 = (maxB - s) * inv
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tMin = math.max(tMin, t1)
			tMax = math.min(tMax, t2)
			if tMin > tMax then
				return false
			end
		end
	end

	return true
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Active = true
	self.TeamNum = parse_team_num(self.Properties.teamnum or self.Properties.team)
	self:SetNWBool("TF_ForceFieldActive", true)
	self:SetNWInt("TF_ForceFieldTeam", self.TeamNum or TEAM_UNASSIGNED)
	if SERVER then
		GAMEMODE.ForceFields = GAMEMODE.ForceFields or {}
		GAMEMODE.ForceFields[self] = true
	end
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if key == "teamnum" or key == "team" then
		self.TeamNum = parse_team_num(value)
		self:SetNWInt("TF_ForceFieldTeam", self.TeamNum or TEAM_UNASSIGNED)
	elseif key == "startdisabled" or key == "start_disabled" then
		self.Active = tonumber(value) ~= 1
		self:SetNWBool("TF_ForceFieldActive", self.Active)
	end
end

function ENT:StartTouch(ent)
end

function ENT:EndTouch(ent)
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" or name == "turnon" then
		self.Active = true
		self:SetNWBool("TF_ForceFieldActive", true)
		return true
	elseif name == "disable" or name == "turnoff" then
		self.Active = false
		self:SetNWBool("TF_ForceFieldActive", false)
		return true
	end
	return false
end

function ENT:OnRemove()
	if SERVER and GAMEMODE.ForceFields then
		GAMEMODE.ForceFields[self] = nil
	end
end

function ENT:IsActive()
	return self.Active ~= false
end

function ENT:BlocksTeam(teamNum)
	if not self:IsActive() then return false end
	if self.TeamNum == TEAM_UNASSIGNED then return false end
	return tonumber(teamNum) ~= tonumber(self.TeamNum)
end

function ENT:ContainsPoint(pos)
	return point_inside_brush(self, pos)
end

function TF_PointsCrossForceField(startPos, endPos, teamToIgnore)
	if not (GAMEMODE and GAMEMODE.ForceFields and isvector(startPos) and isvector(endPos)) then return false end
	for field in pairs(GAMEMODE.ForceFields) do
		if not IsValid(field) or not field:IsActive() then continue end
		if teamToIgnore ~= nil and field.TeamNum == teamToIgnore and teamToIgnore ~= TEAM_UNASSIGNED then
			continue
		end
		local mins, maxs = field:WorldSpaceAABB()
		if segment_hits_aabb(startPos, endPos, mins, maxs) then
			return true
		end
	end
	return false
end

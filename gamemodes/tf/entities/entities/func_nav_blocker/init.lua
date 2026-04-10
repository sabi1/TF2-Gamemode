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
	self.Blocked = false
	self.TeamToBlock = tonumber(self.Properties.teamtoblock) or -1
	self.AffectsFlow = (tonumber(self.Properties.affectsflow) or 0) ~= 0
	if SERVER then
		GAMEMODE.NavBlockers = GAMEMODE.NavBlockers or {}
		GAMEMODE.NavBlockers[self] = true
	end
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if key == "teamtoblock" then
		self.TeamToBlock = tonumber(value) or -1
	elseif key == "affectsflow" then
		self.AffectsFlow = (tonumber(value) or 0) ~= 0
	end
end

function ENT:StartTouch(ent)
end

function ENT:EndTouch(ent)
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "blocknav" then
		self.Blocked = true
		if self.AffectsFlow and TF_RecomputeBotNavBlockers then
			TF_RecomputeBotNavBlockers()
		end
		return true
	elseif name == "unblocknav" then
		self.Blocked = false
		if self.AffectsFlow and TF_RecomputeBotNavBlockers then
			TF_RecomputeBotNavBlockers()
		end
		return true
	end
	return false
end

function ENT:OnRemove()
	if SERVER and GAMEMODE.NavBlockers then
		GAMEMODE.NavBlockers[self] = nil
	end
end

function ENT:IsBlockingTeam(teamNum)
	if not self.Blocked then return false end
	if self.TeamToBlock == -1 then return true end
	return tonumber(teamNum) == self.TeamToBlock
end

function ENT:ContainsPoint(pos)
	return point_inside_brush(self, pos)
end

function TF_PointIsBlockedForBot(pos, teamNum)
	if not (GAMEMODE and GAMEMODE.NavBlockers) then return false end
	for blocker in pairs(GAMEMODE.NavBlockers) do
		if IsValid(blocker) and blocker:IsBlockingTeam(teamNum) and blocker:ContainsPoint(pos) then
			return true
		end
	end
	return false
end

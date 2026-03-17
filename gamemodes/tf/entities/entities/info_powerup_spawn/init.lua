ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = tonumber((self.Properties or {}).disabled or 0) == 1
	self.TeamNum = TEAM_UNASSIGNED

	local teamNum = tonumber((self.Properties or {}).team)
	if teamNum == 2 then
		self.TeamNum = TEAM_RED
	elseif teamNum == 3 then
		self.TeamNum = TEAM_BLU
	end
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "disabled" then
		self.Disabled = tonumber(value) == 1
	elseif key == "team" then
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

function ENT:AcceptInput(name)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Disabled = false
		return true
	elseif name == "disable" then
		self.Disabled = true
		return true
	end
	return false
end

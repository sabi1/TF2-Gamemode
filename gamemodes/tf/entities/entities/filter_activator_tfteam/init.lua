ENT.Type = "point"

local TEAM_TRANSLATE = {
	[0] = TEAM_NEUTRAL,
	[2] = TEAM_RED,
	[3] = TEAM_BLU,
}

local function to_bool(v, default)
	if v == nil then return default end
	if isbool(v) then return v end
	local s = string.lower(tostring(v))
	if s == "1" or s == "true" or s == "yes" then return true end
	if s == "0" or s == "false" or s == "no" then return false end
	return default
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if string.StartWith(key, "on") and self.StoreOutput then
		self:StoreOutput(key, value)
		return
	end
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:GetFilterTeam()
	return TEAM_TRANSLATE[tonumber(self.Properties.teamnum) or 0] or TEAM_NEUTRAL
end

function ENT:PassesFilter(ent)
	if not IsValid(ent) then
		return false
	end

	if GAMEMODE and GAMEMODE.RoundHasWinner and GAMEMODE.WinningTeam and GAMEMODE.WinningTeam == ent:Team() then
		return not to_bool(self.Properties.negated, false)
	end

	local team = ent.Team and ent:Team() or ent:GetInternalVariable("m_iTeamNum")
	local pass = tonumber(team) == tonumber(self:GetFilterTeam())
	if to_bool(self.Properties.negated, false) then
		pass = not pass
	end
	return pass
end

function ENT:InputRoundSpawn()
end

function ENT:InputRoundActivate()
	local controlPointName = tostring(self.Properties.controlpoint or "")
	if controlPointName == "" then
		return
	end

	for _, ent in ipairs(ents.FindByName(controlPointName)) do
		if IsValid(ent) and (ent:GetClass() == "team_control_point" or ent:GetClass() == "trigger_capture_area") then
			local teamNum = ent.GetTeamNumber and ent:GetTeamNumber() or ent:Team()
			if tonumber(teamNum) then
				self.Properties.teamnum = tonumber(teamNum) == TEAM_RED and 2 or (tonumber(teamNum) == TEAM_BLU and 3 or 0)
			end
			return
		end
	end
end

function ENT:AcceptInput(name, activator, caller)
	name = string.lower(tostring(name or ""))
	if name == "roundspawn" then
		self:InputRoundSpawn()
		return true
	elseif name == "roundactivate" then
		self:InputRoundActivate()
		return true
	end
	if name == "testactivator" then
		local target = IsValid(activator) and activator or caller
		if self:PassesFilter(target) then
			self:Fire("OnPass", "", 0, activator, caller)
			return true
		end
		self:Fire("OnFail", "", 0, activator, caller)
		return false
	end
	return false
end

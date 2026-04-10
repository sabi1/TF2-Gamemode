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

	if SERVER then
		GAMEMODE.PowerupSpawnPoints = GAMEMODE.PowerupSpawnPoints or {}
		GAMEMODE.PowerupSpawnPoints[self] = true
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

function ENT:OnRemove()
	if SERVER and GAMEMODE.PowerupSpawnPoints then
		GAMEMODE.PowerupSpawnPoints[self] = nil
	end
end

function ENT:IsDisabled()
	return self.Disabled and true or false
end

function ENT:GetTeamNumber()
	return self.TeamNum or TEAM_UNASSIGNED
end

function ENT:HasRune()
	return IsValid(self.ActiveRune)
end

function ENT:SetRune(rune)
	self.ActiveRune = IsValid(rune) and rune or nil
	if IsValid(rune) then
		rune.SpawnPoint = self
	end
end

function TF_GetPowerupSpawnPoints(teamNum)
	local out = {}
	for spawn in pairs(GAMEMODE.PowerupSpawnPoints or {}) do
		if IsValid(spawn) and not spawn:IsDisabled() then
			local ownerTeam = spawn:GetTeamNumber()
			if teamNum == nil or ownerTeam == TEAM_UNASSIGNED or ownerTeam == teamNum then
				out[#out + 1] = spawn
			end
		end
	end
	return out
end

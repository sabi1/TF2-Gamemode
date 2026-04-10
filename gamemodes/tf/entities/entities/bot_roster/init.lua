ENT.Type = "point"

local CLASS_KEY_TO_NAME = {
	allowscout = "scout",
	allowsniper = "sniper",
	allowsoldier = "soldier",
	allowdemoman = "demoman",
	allowmedic = "medic",
	allowheavy = "heavy",
	allowpyro = "pyro",
	allowspy = "spy",
	allowengineer = "engineer",
}

local function to_bool(value, default)
	if value == nil then return default end
	if isbool(value) then return value end
	local num = tonumber(value)
	if num ~= nil then
		return num ~= 0
	end
	local text = string.lower(string.Trim(tostring(value)))
	if text == "true" or text == "yes" or text == "on" then
		return true
	end
	if text == "false" or text == "no" or text == "off" then
		return false
	end
	return default
end

local function normalize_team(value)
	local text = string.lower(string.Trim(tostring(value or "")))
	if text == "red" or text == "team_red" then return TEAM_RED end
	if text == "blue" or text == "blu" or text == "team_blue" then return TEAM_BLU end
	local num = tonumber(value)
	if num == 2 then return TEAM_RED end
	if num == 3 then return TEAM_BLU end
	return nil
end

local function normalize_class_name(value)
	local className = string.lower(string.Trim(tostring(value or "")))
	if className == "demo" then return "demoman" end
	if className == "heavyweapons" then return "heavy" end
	return className
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.AllowedClasses = self.AllowedClasses or {}
	self.AllowClassChanges = to_bool(self.Properties.allowclasschanges, false)
	self.TeamNum = normalize_team(self.Properties.team)
	if SERVER then
		GAMEMODE.BotRosters = GAMEMODE.BotRosters or {}
		GAMEMODE.BotRosters[self] = true
	end
end

function ENT:OnRemove()
	if SERVER and GAMEMODE.BotRosters then
		GAMEMODE.BotRosters[self] = nil
	end
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "allowclasschanges" then
		self.AllowClassChanges = to_bool(value, false)
	elseif key == "team" then
		self.TeamNum = normalize_team(value)
	elseif CLASS_KEY_TO_NAME[key] then
		self.AllowedClasses = self.AllowedClasses or {}
		self.AllowedClasses[CLASS_KEY_TO_NAME[key]] = to_bool(value, false)
	end
end

function ENT:IsClassChangeAllowed()
	return self.AllowClassChanges == true
end

function ENT:GetConfiguredTeam()
	return self.TeamNum
end

function ENT:IsClassAllowed(className)
	className = normalize_class_name(className)
	if className == "" then return false end
	self.AllowedClasses = self.AllowedClasses or {}
	return self.AllowedClasses[className] == true
end

local function set_allow_class(self, className, value)
	self.AllowedClasses = self.AllowedClasses or {}
	self.AllowedClasses[className] = to_bool(value, false)
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))

	if name == "setteam" then
		self.TeamNum = normalize_team(data)
		self.Properties.team = data
		return true
	end

	local className = CLASS_KEY_TO_NAME[string.lower(string.gsub(name, "^set", "allow"))]
	if className then
		set_allow_class(self, className, data)
		return true
	end

	return false
end

function TF_GetBotRosters()
	GAMEMODE.BotRosters = GAMEMODE.BotRosters or {}
	return GAMEMODE.BotRosters
end

function TF_FindBotRosterForTeam(teamNum)
	for ent in pairs(TF_GetBotRosters()) do
		if IsValid(ent) and ent:GetConfiguredTeam() == teamNum then
			return ent
		end
	end
	return nil
end

function TF_BotRosterAllowsClass(teamNum, className)
	local roster = TF_FindBotRosterForTeam(teamNum)
	if not IsValid(roster) then
		return true
	end
	return roster:IsClassAllowed(className)
end

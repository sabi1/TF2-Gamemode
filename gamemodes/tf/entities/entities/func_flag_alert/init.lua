ENT.Base = "base_brush"
ENT.Type = "brush"

local function parse_team_num(value)
	local num = tonumber(value)
	if num == 2 then return TEAM_RED end
	if num == 3 then return TEAM_BLU end
	return TEAM_UNASSIGNED
end

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

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	self.TeamNum = TEAM_UNASSIGNED
	self.PlaySound = true
	self.AlertDelay = 10
	self.NextAlertTime = {
		[TEAM_RED] = 0,
		[TEAM_BLU] = 0,
	}
	self:SetTrigger(true)
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if string.StartWith(key, "on") and self.StoreOutput then
		self:StoreOutput(key, value)
		return
	end
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if key == "teamnum" then
		self.TeamNum = parse_team_num(value)
	elseif key == "playsound" then
		self.PlaySound = to_bool(value, true)
	elseif key == "alert_delay" then
		self.AlertDelay = math.max(tonumber(value) or 10, 0)
	elseif key == "startdisabled" or key == "start_disabled" then
		self.Disabled = to_bool(value, false)
	end
end

function ENT:StartTouch(ent)
	if self.Disabled then return end
	if not (IsValid(ent) and ent:IsPlayer()) then return end
	if self.TeamNum ~= TEAM_UNASSIGNED and ent:Team() == self.TeamNum then return end
	if not (ent.HasTheFlag and ent:HasTheFlag()) then return end

	local teamNum = ent:Team()
	local nextAt = self.NextAlertTime[teamNum] or 0
	if CurTime() < nextAt then return end
	self.NextAlertTime[teamNum] = CurTime() + self.AlertDelay

	if self.PlaySound then
		local broadcastTeam = (teamNum == TEAM_RED) and TEAM_BLU or TEAM_RED
		for _, ply in ipairs(player.GetAll()) do
			if IsValid(ply) and ply:Team() == broadcastTeam then
				ply:SendLua([[surface.PlaySound("Announcer.SecurityAlert")]])
			end
		end
	end

	if self.TriggerOutput then
		if teamNum == TEAM_RED then
			self:TriggerOutput("OnTriggeredByTeam1", self, self)
		elseif teamNum == TEAM_BLU then
			self:TriggerOutput("OnTriggeredByTeam2", self, self)
		end
	end
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

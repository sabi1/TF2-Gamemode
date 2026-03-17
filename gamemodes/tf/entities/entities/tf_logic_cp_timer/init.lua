ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.ControlPoint = NULL
	self.CountdownEndTime = nil
	self.Fired15Sec = false
	self.Fired10Sec = false
	self.Fired5Sec = false
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

local function GetOwnerTeam(point)
	if not IsValid(point) then return 0 end
	if point.GetOwnerTeam then
		return tonumber(point:GetOwnerTeam() or 0) or 0
	end
	return tonumber(point.OwnerTeam or (point.Properties and point.Properties.point_default_owner) or 0) or 0
end

function ENT:ResolveControlPoint()
	local targetName = tostring(self.Properties.controlpoint or "")
	if targetName == "" then
		self.ControlPoint = NULL
		return
	end

	self.ControlPoint = ents.FindByName(targetName)[1] or NULL
end

function ENT:IsPointBeingCaptured()
	if not IsValid(self.ControlPoint) then return false end
	for _, area in ipairs(ents.FindByClass("trigger_capture_area")) do
		if not IsValid(area) then continue end
		if area.CapturePoint ~= self.ControlPoint then continue end
		if tonumber(area.CappingTeam or 0) ~= 0 then
			return true
		end
	end
	return false
end

function ENT:CountdownMayRun()
	if not IsValid(self.ControlPoint) then
		self:ResolveControlPoint()
	end
	if not IsValid(self.ControlPoint) then return false end
	if self.ControlPoint.Locked then return false end

	local teamNum = tonumber(self.Properties.team_number or 0) or 0
	local owner = GetOwnerTeam(self.ControlPoint)
	if teamNum ~= 0 and owner == teamNum then
		return false
	end
	if self.ControlPoint.TeamCanCap and teamNum ~= 0 and self.ControlPoint.TeamCanCap[teamNum] == false then
		return false
	end

	return true
end

function ENT:ResetCountdown()
	self.CountdownEndTime = nil
	self.Fired15Sec = false
	self.Fired10Sec = false
	self.Fired5Sec = false
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "roundspawn" then
		self:ResolveControlPoint()
		self:ResetCountdown()
		return true
	end
end

function ENT:Think()
	if not self:CountdownMayRun() then
		self:ResetCountdown()
		self:NextThink(CurTime() + 0.1)
		return true
	end

	local timerLength = math.max(tonumber(self.Properties.timer_length or 60) or 60, 0)
	if not self.CountdownEndTime then
		self.CountdownEndTime = CurTime() + timerLength
		self.Fired15Sec = false
		self.Fired10Sec = false
		self.Fired5Sec = false
		self:TriggerOutput("OnCountdownStart", self)
	end

	local remaining = self.CountdownEndTime - CurTime()
	if remaining <= 15 and not self.Fired15Sec then
		self.Fired15Sec = true
		self:TriggerOutput("OnCountdown15SecRemain", self)
	end
	if remaining <= 10 and not self.Fired10Sec then
		self.Fired10Sec = true
		self:TriggerOutput("OnCountdown10SecRemain", self)
	end
	if remaining <= 5 and not self.Fired5Sec then
		self.Fired5Sec = true
		self:TriggerOutput("OnCountdown5SecRemain", self)
	end

	if remaining <= 0 and not self:IsPointBeingCaptured() then
		self:TriggerOutput("OnCountdownEnd", self)
		self:ResetCountdown()
	end

	self:NextThink(CurTime() + 0.1)
	return true
end

hook.Add("TF_RoundStarted", "TF_CPTimerLogicRoundReset", function()
	for _, logic in ipairs(ents.FindByClass("tf_logic_cp_timer")) do
		if not IsValid(logic) then continue end
		if logic.ResolveControlPoint then
			logic:ResolveControlPoint()
		end
		if logic.ResetCountdown then
			logic:ResetCountdown()
		end
	end
end)

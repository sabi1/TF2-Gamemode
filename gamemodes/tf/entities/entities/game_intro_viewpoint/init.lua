AddCSLuaFile()

ENT.Type = "point"

local function to_number(value, default)
	local n = tonumber(value)
	if n == nil then return default end
	return n
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.StepNumber = 1
	self.StepDelay = 12
	self.HintMessage = ""
	self.GameEventName = ""
	self.GameEventDelay = 3
	self.GameEventDataInt = 0
	self.CameraFOV = 0
	self.TeamNum = TEAM_UNASSIGNED
	self:SetNoDraw(true)
	self:RefreshState()
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:RefreshState()
	self.StepNumber = math.max(math.floor(to_number(self.Properties.step_number, 1)), 1)
	self.StepDelay = math.max(to_number(self.Properties.time_delay, 12), 0)
	self.HintMessage = tostring(self.Properties.hint_message or "")
	self.GameEventName = tostring(self.Properties.event_to_fire or "")
	self.GameEventDelay = math.max(to_number(self.Properties.event_delay, 3), 0)
	self.GameEventDataInt = math.floor(to_number(self.Properties.event_data_int, 0))
	self.CameraFOV = to_number(self.Properties.fov, 0)
	self.TeamNum = math.floor(to_number(self.Properties.teamnum, TEAM_UNASSIGNED))

	self:SetNWInt("TFIntroViewpointStep", self.StepNumber)
	self:SetNWFloat("TFIntroViewpointDelay", self.StepDelay)
	self:SetNWString("TFIntroViewpointHint", self.HintMessage)
	self:SetNWString("TFIntroViewpointEvent", self.GameEventName)
	self:SetNWFloat("TFIntroViewpointEventDelay", self.GameEventDelay)
	self:SetNWInt("TFIntroViewpointEventData", self.GameEventDataInt)
	self:SetNWFloat("TFIntroViewpointFOV", self.CameraFOV)
	self:SetNWInt("TFIntroViewpointTeam", self.TeamNum)
end

function ENT:GetIntroStep()
	return self.StepNumber
end

function ENT:GetStepDelay()
	return self.StepDelay
end

function ENT:GetHintMessage()
	return self.HintMessage
end

function ENT:GetGameEventName()
	return self.GameEventName
end

function ENT:GetGameEventDelay()
	return self.GameEventDelay
end

function ENT:GetGameEventDataInt()
	return self.GameEventDataInt
end

function ENT:GetCameraFOV()
	return self.CameraFOV
end

function ENT:GetIntroTeam()
	return self.TeamNum
end

function ENT:AcceptInput(name, activator, caller, data)
	return false
end

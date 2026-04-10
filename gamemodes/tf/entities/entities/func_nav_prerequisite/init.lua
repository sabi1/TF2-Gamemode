ENT.Base = "base_brush"
ENT.Type = "brush"

local TASK_NONE = 0
local TASK_DESTROY_ENTITY = 1
local TASK_MOVE_TO_ENTITY = 2
local TASK_WAIT = 3

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
	self.TaskType = tonumber(self.Properties.task) or TASK_NONE
	self.TaskValue = tonumber(self.Properties.value) or 0
	self.Disabled = to_bool(self.Properties.startdisabled or self.Properties.start_disabled, false)
	self.TaskEntity = nil
	if SERVER then
		GAMEMODE.NavPrerequisites = GAMEMODE.NavPrerequisites or {}
		GAMEMODE.NavPrerequisites[self] = true
		self:SetTrigger(true)
	end
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if key == "task" then
		self.TaskType = tonumber(value) or TASK_NONE
	elseif key == "value" then
		self.TaskValue = tonumber(value) or 0
	elseif key == "entity" then
		self.TaskEntity = nil
	elseif key == "startdisabled" or key == "start_disabled" then
		self.Disabled = to_bool(value, false)
	end
end

function ENT:StartTouch(ent)
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
	end
	return false
end

function ENT:OnRemove()
	if SERVER and GAMEMODE.NavPrerequisites then
		GAMEMODE.NavPrerequisites[self] = nil
	end
end

function ENT:IsEnabled()
	return self.Disabled ~= true
end

function ENT:ContainsPoint(pos)
	return point_inside_brush(self, pos)
end

function ENT:GetTaskEntity()
	if IsValid(self.TaskEntity) then return self.TaskEntity end
	local name = tostring(self.Properties.entity or "")
	if name == "" then return nil end
	for _, ent in ipairs(ents.FindByName(name)) do
		if IsValid(ent) then
			self.TaskEntity = ent
			return ent
		end
	end
	return nil
end

function TF_GetBotNavPrerequisite(bot, pos)
	if not (GAMEMODE and GAMEMODE.NavPrerequisites) then return nil end
	for prereq in pairs(GAMEMODE.NavPrerequisites) do
		if IsValid(prereq) and prereq:IsEnabled() and prereq:ContainsPoint(pos) then
			return prereq
		end
	end
	return nil
end

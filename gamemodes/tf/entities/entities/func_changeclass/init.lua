ENT.Base = "base_brush"
ENT.Type = "brush"

local CHANGECLASS_COOLDOWN = 10

local function to_team_num(raw)
	local teamNum = tonumber(raw)
	if teamNum == 2 then return TEAM_RED end
	if teamNum == 3 then return TEAM_BLU end
	return TEAM_UNASSIGNED
end

local PLAYER = FindMetaTable("Player")
if PLAYER and PLAYER.GetNextChangeClassTime == nil then
	function PLAYER:GetNextChangeClassTime()
		return tonumber(self._tfNextChangeClassTime) or 0
	end
end
if PLAYER and PLAYER.SetNextChangeClassTime == nil then
	function PLAYER:SetNextChangeClassTime(timeValue)
		self._tfNextChangeClassTime = tonumber(timeValue) or 0
	end
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	self.TeamNum = TEAM_UNASSIGNED
	self:SetNoDraw(true)
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "teamnum" then
		self.TeamNum = to_team_num(value)
	elseif key == "startdisabled" then
		self.Disabled = tonumber(value) == 1
	end
end

function ENT:IsDisabled()
	return self.Disabled and true or false
end

function ENT:SetDisabled(disabled)
	self.Disabled = disabled and true or false
end

function ENT:StartTouch(ent)
	if self:IsDisabled() then return end
	if not IsValid(ent) or not ent:IsPlayer() then return end
	if ent.GetNextChangeClassTime and ent:GetNextChangeClassTime() > CurTime() then return end
	if self.TeamNum ~= TEAM_UNASSIGNED and ent:Team() ~= self.TeamNum then return end

	ent:ConCommand("tf_changeclass")
	if ent.SetNextChangeClassTime then
		ent:SetNextChangeClassTime(CurTime() + CHANGECLASS_COOLDOWN)
	end
	ent:EmitSound("ChangeClass.Touch")
end

function ENT:EndTouch(ent)
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self:SetDisabled(false)
		return true
	elseif name == "disable" then
		self:SetDisabled(true)
		return true
	elseif name == "toggle" then
		self:SetDisabled(not self:IsDisabled())
		return true
	end
	return false
end

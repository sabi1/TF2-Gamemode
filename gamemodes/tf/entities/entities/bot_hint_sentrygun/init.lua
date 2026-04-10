
AddCSLuaFile( "shared.lua" )
include( 'shared.lua' )

function ENT:Initialize()
	self:SetModel("models/props_lab/huladoll.mdl")
	self:SetNoDraw(true)
	self:SetNotSolid(true)
	self:SetDisabled(false)
	self.TeamNum = tonumber((self.Properties or {}).team or 0) or 0
	self._tfbotUseCount = 0
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "team" then
		self.TeamNum = tonumber(value or 0) or 0
	elseif key == "startdisabled" then
		self:SetDisabled(tonumber(value or 0) ~= 0 or tostring(value) == "true")
	elseif key == "sticky" then
		self:SetSticky(tonumber(value or 0) ~= 0 or tostring(value) == "true")
	end
end

function ENT:OnSentryGunDestroyed(ent)
	if self.TriggerOutput then
		self:TriggerOutput("OnSentryGunDestroyed", ent or self, ent or self)
	end
end

function ENT:AcceptInput(name)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self:SetDisabled(false)
		return true
	end
	if name == "disable" then
		self:SetDisabled(true)
		return true
	end
	return false
end

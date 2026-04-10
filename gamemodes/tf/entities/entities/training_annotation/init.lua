if SERVER then
	AddCSLuaFile("cl_init.lua")
	util.AddNetworkString("TF_TrainingAnnotationShow")
	util.AddNetworkString("TF_TrainingAnnotationHide")
end

ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self:RefreshStateFromProperties()
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	self:RefreshStateFromProperties()
end

function ENT:RefreshStateFromProperties()
	local props = self.Properties or {}
	self.DisplayText = tostring(props.display_text or "")
	self.Lifetime = tonumber(props.lifetime or 1) or 1
	self.VerticalOffset = tonumber(props.offset or 0) or 0
end

function ENT:Show()
	if not SERVER then return end

	local pos = self:GetPos() + Vector(0, 0, self.VerticalOffset or 0)
	net.Start("TF_TrainingAnnotationShow")
		net.WriteUInt(self:EntIndex(), 16)
		net.WriteString(self.DisplayText or "")
		net.WriteVector(pos)
		net.WriteFloat(self.Lifetime or 1)
	net.Broadcast()
end

function ENT:Hide()
	if not SERVER then return end

	net.Start("TF_TrainingAnnotationHide")
		net.WriteUInt(self:EntIndex(), 16)
	net.Broadcast()
end

function ENT:AcceptInput(name)
	name = string.lower(tostring(name or ""))
	if name == "show" then
		self:Show()
		return true
	end
	if name == "hide" then
		self:Hide()
		return true
	end
	return false
end

function ENT:OnRemove()
	self:Hide()
end

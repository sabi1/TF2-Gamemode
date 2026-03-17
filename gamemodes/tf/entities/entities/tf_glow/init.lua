AddCSLuaFile()

ENT.Type = "point"

local function parse_color(value)
	if IsColor(value) then
		return value
	end
	local parts = string.Explode(" ", tostring(value or "255 0 0 255"), false)
	return Color(
		tonumber(parts[1]) or 255,
		tonumber(parts[2]) or 0,
		tonumber(parts[3]) or 0,
		tonumber(parts[4]) or 255
	)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = tobool(self.Properties.startdisabled)
	self.GlowColor = parse_color(self.Properties.glowcolor)
	self.Mode = tonumber(self.Properties.mode) or 0
	self.TargetEntity = nil
	self:SetNoDraw(true)
	self:ResolveTarget()
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:ResolveTarget()
	local targetName = self.Properties.target
	if not isstring(targetName) or targetName == "" then
		self.TargetEntity = nil
		return nil
	end
	self.TargetEntity = ents.FindByName(targetName)[1]
	return self.TargetEntity
end

function ENT:ApplyGlowState()
	local target = IsValid(self.TargetEntity) and self.TargetEntity or self:ResolveTarget()
	if not IsValid(target) then
		return
	end

	target:SetNWBool("TFGlowEnabled", not self.Disabled)
	target:SetNWVector("TFGlowColor", Vector(self.GlowColor.r, self.GlowColor.g, self.GlowColor.b))
	target:SetNWInt("TFGlowAlpha", self.GlowColor.a or 255)
	target:SetNWInt("TFGlowMode", self.Mode or 0)
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Disabled = false
		self:ApplyGlowState()
		return true
	end
	if name == "disable" then
		self.Disabled = true
		self:ApplyGlowState()
		return true
	end
	if name == "setglowcolor" then
		self.GlowColor = parse_color(data)
		self:ApplyGlowState()
		return true
	end
	return false
end

function ENT:Think()
	self:ApplyGlowState()
	self:NextThink(CurTime() + 1)
	return true
end

AddCSLuaFile()

ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	self.Properties[key] = value
end

local function teleportPlayerToPoint(ply, point)
	if not (IsValid(ply) and ply:IsPlayer() and IsValid(point)) then
		return
	end
	ply:SetPos(point:GetPos())
	if point.GetAngles then
		ply:SetEyeAngles(point:GetAngles())
	end
end

function ENT:TeleportTargets(activator, caller)
	local target = IsValid(activator) and activator:IsPlayer() and activator or (IsValid(caller) and caller:IsPlayer() and caller or nil)
	if IsValid(target) then
		teleportPlayerToPoint(target, self)
		return
	end

	for _, pl in ipairs(player.GetAll()) do
		teleportPlayerToPoint(pl, self)
	end
end

function ENT:AcceptInput(name, activator, caller)
	name = string.lower(tostring(name or ""))
	if name == "teleport" or name == "trigger" then
		self:TeleportTargets(activator, caller)
		return true
	end
	return false
end

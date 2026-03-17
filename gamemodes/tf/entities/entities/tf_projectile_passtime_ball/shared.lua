ENT.Type = "anim"
ENT.Base = "base_anim"

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end
	return
end

AddCSLuaFile("shared.lua")

ENT.Model = "models/passtime/ball/passtime_ball.mdl"
ENT.Mass = 1
ENT.PickupDist = 24
ENT.BlockDist = 18
ENT.ClearOwnerDist = 22
ENT.HomingStrengthStart = 0.01
ENT.Gravity = 800

local function dist_to_segment(point, segStart, segEnd)
	local segment = segEnd - segStart
	local lenSqr = segment:LengthSqr()
	if lenSqr <= 0 then
		return point:Distance(segStart)
	end

	local t = math.Clamp((point - segStart):Dot(segment) / lenSqr, 0, 1)
	local closest = segStart + segment * t
	return point:Distance(closest)
end

local function is_ground_collision(hitNormal)
	if not isvector(hitNormal) then
		return false
	end
	return hitNormal.z > 0.7
end

function ENT:Initialize()
	self:SetModel(self.Model)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetSolidFlags(FSOLID_NOT_STANDABLE)
	self:SetMoveCollide(MOVECOLLIDE_FLY_BOUNCE)

	self.CollisionCount = 0
	self.LeftOwner = false
	self.TouchedSinceSpawn = false
	self.HomingStrength = self.HomingStrengthStart
	self.LastPos = self:GetPos()
	self.AirtimeDistance = 0
	self.LastCollisionTime = CurTime()
	self.SpawnTime = CurTime()
	self.LastThinkTime = CurTime()
	self:SetNWEntity("TFPasstimeHomingTarget", self.Target or NULL)
	self:SetNWEntity("TFPasstimePrevCarrier", self.Thrower or self:GetOwner() or NULL)

	local team = GAMEMODE and GAMEMODE:EntityTeam(self:GetOwner()) or TEAM_RED
	if team == TEAM_BLU or team == TF_TEAM_PVE_INVADERS then
		self:SetSkin(1)
	end

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:SetMass(self.Mass)
		phys:EnableGravity(false)
		if phys.SetDamping then
			phys:SetDamping(0.01, 1.0)
		end
	end
end

function ENT:CanIgnorePlayer(ply)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then
		return true
	end

	local thrower = self.Thrower
	if not self.LeftOwner and IsValid(thrower) and ply == thrower then
		local mins, maxs = ply:WorldSpaceAABB()
		local center = self:GetPos()
		local dx = math.max(mins.x - center.x, 0, center.x - maxs.x)
		local dy = math.max(mins.y - center.y, 0, center.y - maxs.y)
		local dz = math.max(mins.z - center.z, 0, center.z - maxs.z)
		local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
		self.LeftOwner = dist > self.ClearOwnerDist
		return not self.LeftOwner
	end

	self.LeftOwner = true
	return false
end

function ENT:CanTouchPlayer(ply)
	local ballPos = self:GetPos()
	local feet = ply:GetPos()
	local head = feet + Vector(0, 0, (ply.BoundingRadius and ply:BoundingRadius() or 24) + 8)
	local dist = dist_to_segment(ballPos, feet, head)
	return dist <= self.PickupDist or dist <= self.BlockDist
end

function ENT:BlockReflect(ply, ballVel)
	local speed2D = Vector(ballVel.x, ballVel.y, 0):Length()
	local ballDir = Vector(ballVel.x, ballVel.y, 0)
	if ballDir:LengthSqr() <= 0 then
		return
	end
	ballDir:Normalize()

	local reflectDir = self:GetPos() - ply:GetPos()
	reflectDir.z = 0
	if reflectDir:LengthSqr() <= 0 then
		return
	end
	reflectDir:Normalize()
	reflectDir = reflectDir - ballDir
	if reflectDir:LengthSqr() <= 0 then
		return
	end
	reflectDir:Normalize()

	local newVel = reflectDir * (speed2D * 0.5) + ply:GetVelocity()
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(newVel)
	end
end

function ENT:TouchPlayer(ply)
	local thrower = self.Thrower
	local sameTeam = IsValid(thrower) and ply:Team() == thrower:Team()
	local canPickUp = TF_PasstimeProjectileTouchedPlayer and TF_PasstimeProjectileTouchedPlayer(self, ply) or false

	if canPickUp then
		self.TouchedSinceSpawn = true
		return true
	end

	if not sameTeam then
		local phys = self:GetPhysicsObject()
		local vel = IsValid(phys) and phys:GetVelocity() or self:GetVelocity()
		self:BlockReflect(ply, vel)
		self.CollisionCount = self.CollisionCount + 1
		self.Thrower = nil
		self.Target = nil
		self.Homing = nil
		self:SetNWEntity("TFPasstimeHomingTarget", NULL)
		self.AirtimeDistance = 0
		self.LastCollisionTime = CurTime()
	end

	return false
end

function ENT:Touch(ent)
	if not IsValid(ent) or not ent:IsPlayer() then
		return
	end
	if self:CanIgnorePlayer(ent) then
		return
	end
	if not self:CanTouchPlayer(ent) then
		return
	end
	self:TouchPlayer(ent)
end

function ENT:PhysicsCollide(data, physobj)
	if is_ground_collision(data.HitNormal) then
		self.CollisionCount = self.CollisionCount + 1
		self.Thrower = nil
		self.Target = nil
		self.Homing = nil
		self:SetNWEntity("TFPasstimeHomingTarget", NULL)
		self.AirtimeDistance = 0
		self.LastCollisionTime = CurTime()
	end

	if data.Speed > 50 and data.DeltaTime > 0.2 then
		self:EmitSound("Passtime.BallSmack", 75, 100)
	end
end

function ENT:ApplyHoming(phys)
	if not (self.Homing and IsValid(self.Target)) then
		self.HomingStrength = self.HomingStrengthStart
		self:SetNWEntity("TFPasstimeHomingTarget", NULL)
		return false
	end

	local targetVel = self.Target:EyePos() - self:GetPos()
	if targetVel:LengthSqr() <= 0 then
		return true
	end

	targetVel:Normalize()
	targetVel:Mul(self.HomingTargetSpeed or 1000)

	local currentVel = phys:GetVelocity()
	local steer = targetVel - currentVel
	phys:ApplyForceCenter(steer * self.HomingStrength)
	self.HomingStrength = math.Clamp(self.HomingStrength * 1.1, 0, 1)
	self:SetNWEntity("TFPasstimeHomingTarget", self.Target)
	return true
end

function ENT:Think()
	local phys = self:GetPhysicsObject()
	if not IsValid(phys) then
		self:NextThink(CurTime())
		return true
	end

	phys:Wake()
	local homing = self:ApplyHoming(phys)

	if not homing then
		local now = CurTime()
		local dt = math.Clamp(now - (self.LastThinkTime or now), 0, 0.05)
		if dt > 0 then
			local vel = phys:GetVelocity()
			vel.z = vel.z - self.Gravity * dt
			phys:SetVelocity(vel)
		end
	end

	local pos = self:GetPos()
	self.AirtimeDistance = self.AirtimeDistance + pos:Distance(self.LastPos or pos)
	self.LastPos = pos
	self.LastThinkTime = CurTime()

	for _, ply in ipairs(player.GetAll()) do
		if not self:CanIgnorePlayer(ply) and self:CanTouchPlayer(ply) then
			if self:TouchPlayer(ply) then
				break
			end
		end
	end

	local vel = phys:GetVelocity()
	if vel:LengthSqr() > 1 then
		self:SetAngles(vel:Angle())
	end

	self:NextThink(CurTime())
	return true
end

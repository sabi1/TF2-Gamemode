ENT.Base = "base_brush"
ENT.Type = "brush"

local DEFAULT_REFIRE = 0.5
local DEFAULT_AIR_SUPPRESS = 0.25
local RETRY_BOUNDS_SHRINK = 12

local function toBool(v, defaultValue)
	if v == nil then return defaultValue end
	if isbool(v) then return v end
	if isnumber(v) then return v ~= 0 end
	if isstring(v) then
		local t = string.Trim(string.lower(v))
		if t == "1" or t == "true" or t == "yes" or t == "on" then return true end
		if t == "0" or t == "false" or t == "no" or t == "off" then return false end
	end
	return defaultValue
end

local function parseAngle(value)
	if isangle(value) then return value end
	if not isstring(value) then return angle_zero end

	local parts = string.Explode(" ", string.Trim(value))
	return Angle(
		tonumber(parts[1] or "0") or 0,
		tonumber(parts[2] or "0") or 0,
		tonumber(parts[3] or "0") or 0
	)
end

local function chooseSpeed(ent, playerSpeed, physicsSpeed)
	if IsValid(ent) and ent:IsPlayer() then
		return playerSpeed
	end
	return physicsSpeed
end

local function getEntityVelocity(ent)
	if not IsValid(ent) then return vector_origin end
	return ent:GetVelocity()
end

local function getRefireIndex(ent)
	if IsValid(ent) and ent:IsPlayer() then
		return ent:EntIndex()
	end
	return 0
end

local function pointInsideAABB(point, mins, maxs)
	return point.x >= mins.x and point.x <= maxs.x
		and point.y >= mins.y and point.y <= maxs.y
		and point.z >= mins.z and point.z <= maxs.z
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.RefireDelay = {}
	self.AbortedLaunchees = {}
	self:SetTrigger(true)
	self:UseTriggerBounds(true, 8)
	self:ResolveConfig()
end

function ENT:EnsureRuntimeState()
	self.Properties = self.Properties or {}
	self.RefireDelay = self.RefireDelay or {}
	self.AbortedLaunchees = self.AbortedLaunchees or {}
	if self.PlayerSpeed == nil then
		self:ResolveConfig()
	end
end

function ENT:IsEntityWithinRetryBounds(ent)
	if not IsValid(ent) then return false end

	local worldMins, worldMaxs = self:WorldSpaceAABB()
	if not worldMins or not worldMaxs then
		return self:IsTouching(ent)
	end

	local shrink = Vector(RETRY_BOUNDS_SHRINK, RETRY_BOUNDS_SHRINK, RETRY_BOUNDS_SHRINK)
	local mins = worldMins + shrink
	local maxs = worldMaxs - shrink

	if mins.x > maxs.x or mins.y > maxs.y or mins.z > maxs.z then
		return self:IsTouching(ent)
	end

	local entMins, entMaxs = ent:WorldSpaceAABB()
	if not entMins or not entMaxs then
		return self:IsTouching(ent)
	end

	if pointInsideAABB(ent:WorldSpaceCenter(), mins, maxs) then
		return true
	end

	if pointInsideAABB(entMins, mins, maxs) or pointInsideAABB(entMaxs, mins, maxs) then
		return true
	end

	return false
end

function ENT:KeyValue(key, value)
	if string.Left(key, 2) == "On" then
		self:StoreOutput(key, value)
	end

	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) ~= nil then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if self.PlayerSpeed ~= nil then
		self:ResolveConfig()
	end
end

function ENT:ResolveConfig()
	local p = self.Properties or {}

	self.Enabled = not toBool(p.startdisabled, false)
	self.PlayerSpeed = tonumber(p.playerspeed or p.player_speed) or 450
	self.PhysicsSpeed = tonumber(p.physicsspeed or p.physics_speed) or 450
	self.UseThreshold = toBool(p.usethresholdcheck, false)
	self.OnlyVelocityCheck = toBool(p.onlyvelocitycheck, false)
	self.UseExactVelocity = toBool(p.useexactvelocity, false)
	self.ExactVelocityChoice = math.floor(tonumber(p.exactvelocitychoicetype) or 0)
	self.ApplyAngularImpulse = toBool(p.applyangularimpulse, true)
	self.DirectionSuppressAirControl = toBool(p.directionsuppressaircontrol, false)
	self.EntryAngleTolerance = math.Clamp(tonumber(p.entryangletolerance) or 0, -1, 1)
	self.LowerThreshold = math.Clamp(tonumber(p.lowerthreshold) or 0.15, 0, 1)
	self.UpperThreshold = math.Clamp(tonumber(p.upperthreshold) or 0.30, 0, 1)
	self.AirControlSuppressTime = tonumber(p.airctrlsupressiontime) or -1
	self.LaunchAngles = parseAngle(p.launchdirection or p.launch_direction or "0 0 0")
	self.LaunchTargetName = tostring(p.launchtarget or p.launch_target or "")
	self.LaunchTargetEnt = nil
	self.LaunchTargetNextResolve = 0
end

function ENT:ApplyAirControlSuppression(ent)
	if not IsValid(ent) or not ent:IsPlayer() then return end
	local suppress = self.AirControlSuppressTime
	if suppress == nil or suppress <= 0 then
		suppress = DEFAULT_AIR_SUPPRESS
	end
	ent.TFTriggerCatapultAirControlSuppressedUntil = CurTime() + suppress
end

function ENT:ResolveLaunchTarget()
	local now = CurTime()
	if self.LaunchTargetName == "" then
		self.LaunchTargetEnt = nil
		return nil
	end
	if now < (self.LaunchTargetNextResolve or 0) then
		return self.LaunchTargetEnt
	end

	self.LaunchTargetNextResolve = now + 1
	local target = ents.FindByName(self.LaunchTargetName)[1]
	self.LaunchTargetEnt = IsValid(target) and target or nil
	return self.LaunchTargetEnt
end

function ENT:GetCurrentGravity()
	local gravity = GetConVar("sv_gravity")
	return gravity and gravity:GetFloat() or 600
end

function ENT:CalculateLaunchVector(ent, target)
	local sourcePos = ent:GetPos()
	local targetPos = target:GetPos()

	if ent:IsPlayer() then
		targetPos = Vector(targetPos.x, targetPos.y, targetPos.z - 32)
	end

	local speed = chooseSpeed(ent, self.PlayerSpeed, self.PhysicsSpeed)
	local gravity = self:GetCurrentGravity()
	local velocity = targetPos - sourcePos
	local time = velocity:Length() / math.max(speed, 1)
	velocity = velocity * (1 / math.max(time, 0.001))
	velocity.z = velocity.z + gravity * time * 0.5
	return velocity
end

function ENT:CalculateLaunchVectorPreserve(initialVelocity, ent, target, forcePlayer)
	local sourcePos = ent:GetPos()
	local targetPos = target:GetPos()

	if ent:IsPlayer() or forcePlayer then
		targetPos = Vector(targetPos.x, targetPos.y, targetPos.z - 32)
	end

	local diff = targetPos - sourcePos
	local height = diff.z
	local dist = diff:Length2D()
	local speed = chooseSpeed(ent, self.PlayerSpeed, self.PhysicsSpeed)
	local gravity = -self:GetCurrentGravity()

	if dist == 0 then
		return self:CalculateLaunchVector(ent, target)
	end

	local radical = speed ^ 4 - gravity * (gravity * dist * dist - 2 * height * speed * speed)
	if radical <= 0 then
		return self:CalculateLaunchVector(ent, target)
	end

	radical = math.sqrt(radical)
	local angle1 = -math.atan((speed * speed + radical) / (gravity * dist))
	local angle2 = -math.atan((speed * speed - radical) / (gravity * dist))

	local flatDir = Vector(diff.x, diff.y, 0)
	flatDir:Normalize()

	local solution1 = flatDir * (speed * math.cos(angle1))
	solution1.z = speed * math.sin(angle1)

	local solution2 = flatDir * (speed * math.cos(angle2))
	solution2.z = speed * math.sin(angle2)

	local desired = initialVelocity:GetNormalized()
	if self.ExactVelocityChoice == 1 then
		return solution1
	elseif self.ExactVelocityChoice == 2 then
		return solution2
	end

	if desired:Dot(solution1) > desired:Dot(solution2) then
		return solution1
	end
	return solution2
end

function ENT:OnLaunchedVictim(ent)
	self:TriggerOutput("OnCatapulted", ent, self)
	self.RefireDelay[getRefireIndex(ent)] = CurTime() + DEFAULT_REFIRE
end

function ENT:LaunchByTarget(ent, target)
	local currentVelocity = getEntityVelocity(ent)
	local launchVelocity = self.UseExactVelocity
		and self:CalculateLaunchVectorPreserve(currentVelocity, ent, target)
		or self:CalculateLaunchVector(ent, target)

	if ent:IsPlayer() then
		if ent:IsOnGround() and ent.SetGroundEntity then
			ent:SetGroundEntity(NULL)
		end
		ent:SetLocalVelocity(launchVelocity)
		self:ApplyAirControlSuppression(ent)
		self:OnLaunchedVictim(ent)
		return
	end

	if ent:GetMoveType() == MOVETYPE_VPHYSICS then
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			local angImpulse = self.ApplyAngularImpulse and AngleRand(-150, 150) or angle_zero
			phys:SetVelocityInstantaneous(launchVelocity, Vector(angImpulse.p, angImpulse.y, angImpulse.r))
		else
			ent:SetVelocity(launchVelocity - currentVelocity)
		end
	end

	self:OnLaunchedVictim(ent)
end

function ENT:LaunchByDirection(ent)
	local forward = self.LaunchAngles:Forward()

	if ent:IsPlayer() then
		local push = forward * self.PlayerSpeed
		if math.abs(push.x) < 0.001 and math.abs(push.y) < 0.001 then
			push.z = self.PlayerSpeed * 1.5
		end
		if ent:IsOnGround() and ent.SetGroundEntity then
			ent:SetGroundEntity(NULL)
		end
		ent:SetLocalVelocity(push)
		if self.DirectionSuppressAirControl then
			self:ApplyAirControlSuppression(ent)
		end
		self:OnLaunchedVictim(ent)
		return
	end

	if ent:GetMoveType() == MOVETYPE_VPHYSICS then
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			local velocity = forward * self.PhysicsSpeed
			velocity.z = self.PhysicsSpeed
			local angImpulse = self.ApplyAngularImpulse and VectorRand() * 50 or vector_origin
			phys:SetVelocityInstantaneous(velocity, angImpulse)
			if phys.SetDragCoefficient then
				phys:SetDragCoefficient(0, 0)
			end
			if phys.SetDamping then
				phys:SetDamping(0, 0)
			end
		else
			ent:SetVelocity(forward * self.PhysicsSpeed)
		end
	end

	self:OnLaunchedVictim(ent)
end

function ENT:PassesEntityChecks(ent)
	if not self.Enabled then return false end
	if not IsValid(ent) then return false end
	if not (ent:IsPlayer() or ent:GetMoveType() == MOVETYPE_VPHYSICS) then return false end
	if ent:IsPlayer() and not ent:Alive() then return false end
	return true
end

function ENT:ShouldDelayLaunch(ent)
	local index = getRefireIndex(ent)
	return (self.RefireDelay[index] or 0) > CurTime()
end

function ENT:QueueRetry(ent)
	if not IsValid(ent) then return end
	self.AbortedLaunchees[ent] = true
	self:NextThink(CurTime() + 0.05)
end

function ENT:ThresholdAllowsLaunch(ent, target)
	local victimVelocity = getEntityVelocity(ent)

	if IsValid(target) then
		local launchVelocity = self.UseExactVelocity
			and self:CalculateLaunchVectorPreserve(victimVelocity, ent, target)
			or self:CalculateLaunchVector(ent, target)
		local launchSpeed = launchVelocity:Length()
		local victimSpeed = victimVelocity:Length()
		local direction = (target:GetPos() - ent:GetPos()):GetNormalized()
		local victimDir = victimVelocity:GetNormalized()
		local dot = victimDir:Dot(direction)

		if dot < self.EntryAngleTolerance then
			return false
		end

		local lower = launchSpeed - (launchSpeed * self.LowerThreshold)
		local upper = launchSpeed + (launchSpeed * self.UpperThreshold)
		return victimSpeed > lower and victimSpeed < upper
	end

	local forward = self.LaunchAngles:Forward()
	local dot = forward:Dot(victimVelocity)
	local lower = self.PlayerSpeed - (self.PlayerSpeed * self.LowerThreshold)
	local upper = self.PlayerSpeed + (self.PlayerSpeed * self.UpperThreshold)
	return dot >= lower and dot <= upper
end

function ENT:TryLaunch(ent)
	if not self:PassesEntityChecks(ent) then return false end

	if self:ShouldDelayLaunch(ent) then
		self:QueueRetry(ent)
		return false
	end

	if ent:GetMoveType() == MOVETYPE_VPHYSICS then
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) and phys:IsMotionEnabled() == false then
			self:QueueRetry(ent)
			return false
		end
	end

	local target = self:ResolveLaunchTarget()
	if self.UseThreshold and not self:ThresholdAllowsLaunch(ent, target) then
		self.RefireDelay[getRefireIndex(ent)] = CurTime() + DEFAULT_REFIRE
		return false
	end

	if self.OnlyVelocityCheck then
		self:OnLaunchedVictim(ent)
		return true
	end

	if IsValid(target) then
		self:LaunchByTarget(ent, target)
	else
		self:LaunchByDirection(ent)
	end

	return true
end

function ENT:StartTouch(ent)
	self:EnsureRuntimeState()
	if IsValid(ent) and ent:IsPlayer() then
		self.AbortedLaunchees[ent] = true
		self:NextThink(CurTime() + 0.05)
	end
	self:TryLaunch(ent)
end

function ENT:Touch(ent)
	return
end

function ENT:Think()
	self:EnsureRuntimeState()
	for ent in pairs(self.AbortedLaunchees) do
		if not IsValid(ent) then
			self.AbortedLaunchees[ent] = nil
		elseif not self:IsEntityWithinRetryBounds(ent) then
			self.AbortedLaunchees[ent] = nil
		elseif self:TryLaunch(ent) and not ent:IsPlayer() then
			self.AbortedLaunchees[ent] = nil
		end
	end

	if next(self.AbortedLaunchees) ~= nil then
		self:NextThink(CurTime() + 0.05)
		return true
	end
end

function ENT:EndTouch(ent)
	self:EnsureRuntimeState()
	if not IsValid(ent) then return end
	self.AbortedLaunchees[ent] = nil
end

function ENT:AcceptInput(name, activator, caller, data)
	self:EnsureRuntimeState()
	name = string.lower(tostring(name or ""))
	if name == "enable" or name == "start" then
		self.Enabled = true
		return true
	elseif name == "disable" or name == "stop" then
		self.Enabled = false
		return true
	elseif name == "toggle" then
		self.Enabled = not self.Enabled
		return true
	elseif name == "setlaunchtarget" then
		if isstring(data) and data ~= "" then
			self.LaunchTargetName = data
			self.Properties.launchtarget = data
			self.LaunchTargetEnt = nil
			self.LaunchTargetNextResolve = 0
		end
		return true
	elseif name == "setplayerspeed" then
		self.PlayerSpeed = tonumber(data) or self.PlayerSpeed
		self.Properties.playerspeed = self.PlayerSpeed
		return true
	elseif name == "setphysicsspeed" then
		self.PhysicsSpeed = tonumber(data) or self.PhysicsSpeed
		self.Properties.physicsspeed = self.PhysicsSpeed
		return true
	elseif name == "setexactvelocitychoicetype" then
		self.ExactVelocityChoice = math.floor(tonumber(data) or self.ExactVelocityChoice or 0)
		self.Properties.exactvelocitychoicetype = self.ExactVelocityChoice
		return true
	end
	return false
end

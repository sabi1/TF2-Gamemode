ENT.Base = "base_brush"
ENT.Type = "brush"

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

local function parseVecOrAng(value)
	if isvector(value) then return value end
	if not isstring(value) then return vector_origin end

	local parts = string.Explode(" ", string.Trim(value))
	local x = tonumber(parts[1] or "0") or 0
	local y = tonumber(parts[2] or "0") or 0
	local z = tonumber(parts[3] or "0") or 0

	-- Hammer can provide launch direction as either a vector or angles.
	local vec = Vector(x, y, z)
	if vec:LengthSqr() > 0 then
		return vec
	end

	local ang = Angle(x, y, z)
	return ang:Forward()
end

local function chooseSpeed(ent, playerSpeed, physicsSpeed)
	if IsValid(ent) and ent:IsPlayer() then
		return playerSpeed
	end
	return physicsSpeed
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Enabled = true
	self.TouchCooldown = {}
	self:SetTrigger(true)
	self:UseTriggerBounds(true, 8)
	self:ResolveConfig()
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) ~= nil then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:ResolveConfig()
	local p = self.Properties or {}

	self.Enabled = not toBool(p.startdisabled, false)
	self.PlayerSpeed = tonumber(p.playerspeed or p.player_speed) or 900
	self.PhysicsSpeed = tonumber(p.physicsspeed or p.physics_speed) or self.PlayerSpeed
	self.UseThreshold = toBool(p.usethresholdcheck, false)
	self.OnlyVelocityCheck = toBool(p.onlyvelocitycheck, false)
	self.LowerThreshold = tonumber(p.lowerthreshold) or 0
	self.UpperThreshold = tonumber(p.upperthreshold) or 0
	self.ExactVelocity = toBool(p.useexactvelocity, false)
	self.Cooldown = math.max(tonumber(p.reusetime) or 0.2, 0)
	self.LaunchDirection = parseVecOrAng(p.launchdirection or p.launch_direction or "")
	self.LaunchTargetName = tostring(p.launchtarget or p.launch_target or "")
	self.LaunchTargetEnt = nil
	self.LaunchTargetNextResolve = 0
end

function ENT:GetLaunchDirection(ent)
	local now = CurTime()
	if self.LaunchTargetName ~= "" and now >= (self.LaunchTargetNextResolve or 0) then
		self.LaunchTargetNextResolve = now + 1.0
		local target = ents.FindByName(self.LaunchTargetName)[1]
		self.LaunchTargetEnt = IsValid(target) and target or nil
	end

	if IsValid(self.LaunchTargetEnt) then
		local delta = (self.LaunchTargetEnt:GetPos() - ent:GetPos())
		if delta:LengthSqr() > 0 then
			return delta:GetNormalized()
		end
	end

	local dir = self.LaunchDirection
	if not isvector(dir) or dir:LengthSqr() <= 0 then
		dir = self:GetForward()
	end
	if dir:LengthSqr() <= 0 then
		dir = Vector(0, 0, 1)
	end
	return dir:GetNormalized()
end

function ENT:ShouldLaunch(ent)
	if not self.Enabled then return false end
	if not IsValid(ent) then return false end
	if not (ent:IsPlayer() or ent:GetMoveType() == MOVETYPE_VPHYSICS) then return false end
	if ent:IsPlayer() and not ent:Alive() then return false end

	local id = ent:EntIndex()
	local nextTouch = self.TouchCooldown[id] or 0
	if nextTouch > CurTime() then return false end

	if self.UseThreshold then
		local vel = ent:GetVelocity()
		local speed = self.OnlyVelocityCheck and math.abs(vel.z) or vel:Length()
		if speed < self.LowerThreshold then return false end
		if self.UpperThreshold > 0 and speed > self.UpperThreshold then return false end
	end

	return true
end

function ENT:LaunchEntity(ent)
	local speed = math.max(0, chooseSpeed(ent, self.PlayerSpeed, self.PhysicsSpeed))
	if speed <= 0 then return end

	local dir = self:GetLaunchDirection(ent)
	local desired = dir * speed
	local current = ent:GetVelocity()
	local delta = desired - current

	if self.ExactVelocity then
		-- Keep exact catapult velocity profile regardless of current movement.
		delta = desired - current
	end

	if ent.SetGroundEntity then
		ent:SetGroundEntity(NULL)
	end

	ent:SetVelocity(delta)
	self.TouchCooldown[ent:EntIndex()] = CurTime() + self.Cooldown
end

function ENT:StartTouch(ent)
	if not self.PlayerSpeed then
		self:ResolveConfig()
	end
	if not self:ShouldLaunch(ent) then return end
	self:LaunchEntity(ent)
end

function ENT:Touch(ent)
	-- If a player remains inside the brush, allow relaunch only after cooldown.
	if not self.PlayerSpeed then
		self:ResolveConfig()
	end
	if not self:ShouldLaunch(ent) then return end
	self:LaunchEntity(ent)
end

function ENT:EndTouch(ent)
	if not IsValid(ent) then return end
	self.TouchCooldown[ent:EntIndex()] = nil
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" or name == "start" then
		self.Enabled = true
		return true
	end
	if name == "disable" or name == "stop" then
		self.Enabled = false
		return true
	end
	if name == "toggle" then
		self.Enabled = not self.Enabled
		return true
	end
	if name == "setlaunchtarget" then
		if isstring(data) and data ~= "" then
			self.LaunchTargetName = data
			self.LaunchTargetEnt = nil
			self.LaunchTargetNextResolve = 0
		end
		return true
	end
	return false
end

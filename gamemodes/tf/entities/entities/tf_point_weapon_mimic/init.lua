ENT.Type = "point"

local WEAPON_STANDARD_ROCKET = 0
local WEAPON_STANDARD_GRENADE = 1
local WEAPON_STANDARD_ARROW = 2
local WEAPON_STICKY_GRENADE = 3

local ROCKET_COLLISION_GROUP = TFCOLLISION_GROUP_ROCKET_BUT_NOT_WITH_OTHER_ROCKETS or COLLISION_GROUP_PROJECTILE
local PIPE_COLLISION_GROUP = TFCOLLISION_GROUP_ROCKETS or COLLISION_GROUP_PROJECTILE

local function toBool(value, default)
	if value == nil then return default end
	if isbool(value) then return value end
	local text = string.lower(tostring(value))
	if text == "1" or text == "true" or text == "yes" then return true end
	if text == "0" or text == "false" or text == "no" then return false end
	return default
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.ActiveStickies = self.ActiveStickies or {}
	self:RefreshStateFromProperties()
	self:SetTeam(TEAM_BLU)
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
	self.WeaponType = math.Clamp(tonumber(props.weapontype or 0) or 0, 0, WEAPON_STICKY_GRENADE)
	self.FireSound = tostring(props.firesound or "")
	self.FireParticles = tostring(props.particleeffect or "")
	self.ModelOverride = tostring(props.modeloverride or "")
	self.ModelScale = tonumber(props.modelscale or 1) or 1
	self.SpeedMin = tonumber(props.speedmin or 1100) or 1100
	self.SpeedMax = tonumber(props.speedmax or self.SpeedMin) or self.SpeedMin
	self.Damage = tonumber(props.damage or 90) or 90
	self.SplashRadius = tonumber(props.splashradius or 146) or 146
	self.SpreadAngle = tonumber(props.spreadangle or 0) or 0
	self.Crits = toBool(props.crits, false)
end

function ENT:GetFiringAngles()
	local angles = self:GetAngles()
	local spread = tonumber(self.SpreadAngle or 0) or 0
	if spread <= 0 then
		return angles
	end

	local half = spread * 0.5
	angles = Angle(angles.p, angles.y, angles.r)
	angles:RotateAroundAxis(angles:Up(), math.Rand(-half, half))
	angles:RotateAroundAxis(angles:Forward(), math.Rand(-180, 180))
	return angles
end

function ENT:GetProjectileSpeed()
	local minSpeed = tonumber(self.SpeedMin or 0) or 0
	local maxSpeed = tonumber(self.SpeedMax or minSpeed) or minSpeed
	if maxSpeed < minSpeed then
		minSpeed, maxSpeed = maxSpeed, minSpeed
	end
	return math.Rand(minSpeed, maxSpeed)
end

function ENT:ApplyProjectileCommon(projectile)
	if not IsValid(projectile) then
		return nil
	end

	if self.ModelOverride ~= "" then
		projectile:SetModel(self.ModelOverride)
	end

	if projectile.SetModelScale then
		projectile:SetModelScale(self.ModelScale or 1, 0)
	end

	projectile:SetOwner(self)
	projectile:SetTeam(TEAM_BLU)
	if projectile.SetSkin then
		projectile:SetSkin(1)
	end

	projectile.critical = self.Crits == true
	projectile.BaseDamage = self.Damage
	projectile.ExplosionRadiusInit = self.SplashRadius
	projectile.DamageRadius = self.SplashRadius
	if projectile.SetDamage then
		projectile:SetDamage(self.Damage)
	end
	if projectile.SetFullDamage then
		projectile:SetFullDamage(self.Damage)
	end
	if projectile.SetDamageRadius then
		projectile:SetDamageRadius(self.SplashRadius)
	end

	return projectile
end

function ENT:EmitFireEffects()
	if self.FireSound ~= "" then
		self:EmitSound(self.FireSound)
	end

	if self.FireParticles ~= "" then
		ParticleEffect(self.FireParticles, self:GetPos(), self:GetAngles(), self)
	end
end

function ENT:FireRocket()
	local projectile = ents.Create("tf_projectile_rocket")
	if not IsValid(projectile) then
		return false
	end

	local angles = self:GetFiringAngles()
	projectile:SetPos(self:GetPos())
	projectile:SetAngles(angles)
	projectile:SetOwner(self)
	projectile.critical = self.Crits == true
	projectile.BaseDamage = self.Damage
	projectile.ExplosionRadiusInit = self.SplashRadius
	projectile:Spawn()
	projectile:Activate()

	self:ApplyProjectileCommon(projectile)

	local velocity = angles:Forward() * self:GetProjectileSpeed()
	projectile:SetLocalVelocity(velocity)
	if projectile.SetupInitialTransmittedGrenadeVelocity then
		projectile:SetupInitialTransmittedGrenadeVelocity(velocity)
	end
	projectile:SetCollisionGroup(ROCKET_COLLISION_GROUP)
	return true
end

function ENT:FireArrow()
	local projectile = ents.Create("tf_projectile_arrow")
	if not IsValid(projectile) then
		return false
	end

	local angles = self:GetFiringAngles()
	projectile:SetPos(self:GetPos())
	projectile:SetAngles(angles)
	projectile:SetOwner(self)
	projectile.critical = self.Crits == true
	projectile.BaseDamage = self.Damage
	projectile:Spawn()
	projectile:Activate()

	self:ApplyProjectileCommon(projectile)

	local velocity = angles:Forward() * self:GetProjectileSpeed()
	projectile:SetLocalVelocity(velocity)
	if projectile.SetupInitialTransmittedGrenadeVelocity then
		projectile:SetupInitialTransmittedGrenadeVelocity(velocity)
	end
	projectile:SetCollisionGroup(ROCKET_COLLISION_GROUP)
	return true
end

function ENT:FirePipe(isSticky)
	local projectile = ents.Create("tf_projectile_pipe")
	if not IsValid(projectile) then
		return false
	end

	local angles = self:GetFiringAngles()
	projectile:SetPos(self:GetPos())
	projectile:SetAngles(angles)
	projectile:SetOwner(self)
	projectile.critical = self.Crits == true
	projectile.BaseDamage = self.Damage
	projectile.ExplosionRadiusInit = self.SplashRadius
	projectile.GrenadeMode = isSticky and 1 or 0
	projectile:Spawn()
	projectile:Activate()

	self:ApplyProjectileCommon(projectile)
	projectile:SetCollisionGroup(PIPE_COLLISION_GROUP)

	local phys = projectile:GetPhysicsObject()
	if IsValid(phys) then
		local velocity = angles:Forward() * self:GetProjectileSpeed()
		phys:SetVelocity(velocity)
		phys:AddAngleVelocity(Vector(600, math.Rand(-1200, 1200), 0))
	end

	if isSticky then
		self.ActiveStickies = self.ActiveStickies or {}
		table.insert(self.ActiveStickies, projectile)
	end

	return true
end

function ENT:FireProjectile()
	if self.WeaponType == WEAPON_STANDARD_ROCKET then
		return self:FireRocket()
	end
	if self.WeaponType == WEAPON_STANDARD_GRENADE then
		return self:FirePipe(false)
	end
	if self.WeaponType == WEAPON_STANDARD_ARROW then
		return self:FireArrow()
	end
	if self.WeaponType == WEAPON_STICKY_GRENADE then
		return self:FirePipe(true)
	end
	return false
end

function ENT:DetonateActiveStickies()
	self.ActiveStickies = self.ActiveStickies or {}
	for i = #self.ActiveStickies, 1, -1 do
		local sticky = self.ActiveStickies[i]
		if not IsValid(sticky) then
			table.remove(self.ActiveStickies, i)
		else
			if sticky.DoExplosion then
				sticky:DoExplosion()
			else
				sticky:Remove()
			end
			table.remove(self.ActiveStickies, i)
		end
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))

	if name == "fireonce" then
		local fired = self:FireProjectile()
		if fired then
			self:EmitFireEffects()
		end
		return fired
	end

	if name == "firemultiple" then
		local count = math.max(1, math.abs(tonumber(data) or 1))
		local firedAny = false
		for _ = 1, count do
			firedAny = self:FireProjectile() or firedAny
		end
		if firedAny then
			self:EmitFireEffects()
		end
		return firedAny
	end

	if name == "detonatestickies" then
		self:DetonateActiveStickies()
		return true
	end

	return false
end

function ENT:OnRemove()
	self:DetonateActiveStickies()
end

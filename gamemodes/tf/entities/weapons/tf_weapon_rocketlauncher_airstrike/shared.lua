-- Real class name: tf_weapon_bet_rocketlauncher (see shd_items.lua)

if SERVER then
	AddCSLuaFile()
end

if CLIENT then

SWEP.PrintName			= "The Air Strike"
SWEP.Slot				= 0
SWEP.HasCModel = true

end

SWEP.Base				= "tf_weapon_gun_base"

SWEP.ViewModel			= "models/weapons/c_models/c_soldier_arms.mdl"
SWEP.WorldModel			= "models/workshop/weapons/c_models/c_atom_launcher/c_atom_launcher.mdl"
SWEP.Crosshair = "tf_crosshair3"

SWEP.MuzzleEffect = "muzzle_pipelauncher"

SWEP.ShootSound = Sound("Weapon_Airstrike.AltFire")
SWEP.ShootCritSound = Sound("Weapon_Airstrike.CritFire")
SWEP.CustomExplosionSound = Sound("Weapon_Airstrike.Explosion")
SWEP.ReloadSound = Sound("")

SWEP.Primary.ClipSize		= 8
SWEP.Primary.DefaultClip	= SWEP.Primary.ClipSize
SWEP.Primary.Ammo			= TF_PRIMARY
SWEP.Primary.Delay = 0.8
SWEP.ReloadTime = 0.8


SWEP.IsRapidFire = false
SWEP.ReloadSingle = true

SWEP.HoldType = "PRIMARY"

SWEP.ProjectileShootOffset = Vector(0, 13, -4)

SWEP.PunchView = Angle( 0, 0, 0 )

SWEP.Properties = {}

local function getAirborneTimerName(weapon)
	if not IsValid(weapon) then return nil end
	return "CheckIfPlayerIsAirborne_" .. weapon:EntIndex()
end

function SWEP:Deploy()
	self:CallBaseFunction("Deploy")
	local timerName = getAirborneTimerName(self)
	if not timerName then return end
	timer.Remove(timerName)
	timer.Create(timerName, 0.001, 0, function()
		if not IsValid(self) then
			timer.Remove(timerName)
			return
		end
		local owner = self.Owner
		if not IsValid(owner) or not owner:Alive() then
			timer.Remove(timerName)
			return
		end
		if owner:IsOnGround() != true then
			self.Primary.Delay          = 0.30
		else
			self.Primary.Delay          = 0.8
		end
	end)
end

function SWEP:Holster()
	local timerName = getAirborneTimerName(self)
	if timerName then
		timer.Remove(timerName)
	end
	return self:CallBaseFunction("Holster")
end

function SWEP:OnRemove()
	local timerName = getAirborneTimerName(self)
	if timerName then
		timer.Remove(timerName)
	end
end

function SWEP:ShootProjectile()
	self.ShootCritSound = Sound("Weapon_Airstrike.CritFire")
	if SERVER then
		local rocket = ents.Create("tf_projectile_rocket")
		rocket:SetPos(self:ProjectileShootPos())
		local ang = self.Owner:EyeAngles()
		
		if self.WeaponMode == 1 then
			local charge = (CurTime() - self.ChargeStartTime) / self.ChargeTime
			rocket.Gravity = Lerp(1 - charge, self.MinGravity, self.MaxGravity)
			rocket.BaseSpeed = Lerp(charge, self.MinForce, self.MaxForce)
			ang.p = ang.p + Lerp(1 - charge, self.MinAddPitch, self.MaxAddPitch)
		end
		
		rocket:SetAngles(ang)
		
		if self:Critical() then
			rocket.critical = true
		end
		
		for k,v in pairs(self.Properties) do
			rocket[k] = v
		end
		
		
		rocket:SetOwner(self.Owner)
		self:InitProjectileAttributes(rocket)
		rocket.ExplosionSound = self.CustomExplosionSound
		
		rocket:Spawn()
		rocket:SetModel("models/weapons/w_models/w_rocket_airstrike/w_rocket_airstrike.mdl")
		rocket:Activate()
	end
	
	self:ShootEffects()
end

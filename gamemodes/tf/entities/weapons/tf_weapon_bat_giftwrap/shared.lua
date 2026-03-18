if SERVER then
	AddCSLuaFile()
end

if CLIENT then
	SWEP.PrintName			= "Sandman"
end
SWEP.Base				= "tf_weapon_melee_base"

SWEP.Slot				= 2
SWEP.ViewModel			= "models/weapons/v_models/v_bat_scout.mdl"
SWEP.WorldModel			= "models/weapons/c_models/c_wooden_bat/c_wooden_bat.mdl"
SWEP.Crosshair = "tf_crosshair3"

SWEP.Swing = Sound("Weapon_Bat.Miss")
SWEP.SwingCrit = Sound("Weapon_Bat.MissCrit")
SWEP.HitFlesh = Sound("BallBuster.HitFlesh")
SWEP.HitRobot = Sound("BallBuster.HitWorld")
SWEP.HitWorld = Sound("BallBuster.HitWorld")

SWEP.BaseDamage = 11
SWEP.DamageRandomize = 0.1
SWEP.MaxDamageRampUp = 0
SWEP.MaxDamageFalloff = 0

SWEP.Primary.Automatic		= true
SWEP.Primary.Ammo			= "none"
SWEP.Primary.Delay          = 0.5
SWEP.Secondary.Automatic		= true
SWEP.Secondary.Ammo			= "none"
SWEP.Secondary.Delay          = 10
SWEP.GlobalCustomHUD = {
	HudItemEffectMeter = function(self)
		return CurTime() < (self:GetNextSecondaryFire() or 0)
	end
}

SWEP.HoldType = "MELEE"
SWEP.HasThirdpersonCritAnimation = false

SWEP.ProjectileShootOffset = Vector(0, 7, -6)
SWEP.Force = 1500
SWEP.AddPitch = 1
if CLIENT then
	SWEP.OffhandProjectileModel = "models/weapons/c_models/c_xms_festive_ornament.mdl"
	SWEP.OffhandProjectileAttachment = "effect_hand_L"
	SWEP.OffhandProjectileBone = "ValveBiped.Bip01_L_Hand"
	SWEP.OffhandProjectileOffset = Vector(1.2, 1.7, -1.0)
	SWEP.OffhandProjectileAngle = Angle(-10, 70, -100)
end

local function SendWBSequence(self, sequenceNames, fallbackAct)
	local vm = IsValid(self.Owner) and self.Owner:GetViewModel() or nil
	if not IsValid(vm) then
		if fallbackAct then
			self:SendWeaponAnim(fallbackAct)
		end
		return 0
	end

	if isstring(sequenceNames) then
		sequenceNames = {sequenceNames}
	end

	for _, sequenceName in ipairs(sequenceNames or {}) do
		local seq = vm:LookupSequence(sequenceName)
		if seq and seq >= 0 then
			self:SendWeaponAnimEx(sequenceName)
			return vm:SequenceDuration(seq) or 0
		end
	end

	if fallbackAct then
		self:SendWeaponAnim(fallbackAct)
		return self:SequenceDuration(self:SelectWeightedSequence(fallbackAct)) or 0
	end

	return 0
end

local function QueueWBIdle(self, delay)
	timer.Simple(math.max(0, delay or 0), function()
		if not IsValid(self) or not IsValid(self.Owner) then return end
		if self.Owner:GetActiveWeapon() ~= self then return end
		local idleSequence = self.VM_IDLE or "wb_idle"
		SendWBSequence(self, idleSequence, ACT_VM_IDLE_SPECIAL)
	end)
end

function SWEP:ApplyWBAnimations()
	self.VM_DRAW = ACT_VM_DRAW_SPECIAL
	self.VM_IDLE = self:OffhandProjectileReady() and "wb_grab" or "wb_idle"
	self.VM_HITCENTER = {"wb_swing_a", "wb_swing_b", "wb_swing_c"}
	self.VM_SWINGHARD = {"wb_swing_a", "wb_swing_b", "wb_swing_c"}
	self.VM_INSPECT_START = ACT_MELEE_VM_INSPECT_START
	self.VM_INSPECT_IDLE = ACT_MELEE_VM_INSPECT_IDLE
	self.VM_INSPECT_END = ACT_MELEE_VM_INSPECT_END
end

function SWEP:OffhandProjectileReady()
	return CurTime() >= (self:GetNextSecondaryFire() or 0)
end

function SWEP:GetHUDMeterName()
	return "#TF_Ball"
end

function SWEP:GetHUDMeterResFile()
	return "resource/ui/huditemeffectmeter_scout.res"
end

function SWEP:GetHUDMeterValue()
	local nextSecondary = self:GetNextSecondaryFire() or 0
	if CurTime() >= nextSecondary then
		return 1
	end

	local recharge = self.Secondary.Delay or 10
	if recharge <= 0 then return 0 end

	local elapsed = recharge - math.max(0, nextSecondary - CurTime())
	return math.Clamp(elapsed / recharge, 0, 1)
end

function SWEP:Think()
	self.BaseClass.Think(self)
	self:ApplyWBAnimations()
end

function SWEP:Deploy()
	local r = self:CallBaseFunction("Deploy")
	self:ApplyWBAnimations()
	local dur = SendWBSequence(self, {"wb_draw", "wb_grab"}, ACT_VM_DRAW_SPECIAL)
	if dur > 0 then
		self.NextIdle = CurTime() + dur
		QueueWBIdle(self, dur)
	end
	return r
end


function SWEP:SecondaryAttack()
	self.Owner:DoAnimationEvent(ACT_MP_ATTACK_STAND_MELEE_SECONDARY)
	local fireDur = SendWBSequence(self, "wb_fire", ACT_VM_PRIMARYATTACK_SPECIAL)
	self:SetNextSecondaryFire( CurTime() + self.Secondary.Delay )
	if SERVER then
		self.Owner:EmitSoundEx("BallBuster.HitBall")
		local grenade = ents.Create("tf_projectile_ornament")
		grenade:SetPos(self:ProjectileShootPos())
		grenade:SetAngles(self.Owner:EyeAngles())
		
		if self:Critical() then
			grenade.critical = true
		end
		
		
		self:InitProjectileAttributes(grenade)
		
		grenade.NameOverride = self:GetItemData().item_iconname
		grenade:SetOwner(self.Owner)	
		grenade:Spawn()
		
		local vel = self.Owner:GetAimVector():Angle()
		vel.p = vel.p + self.AddPitch
		vel = vel:Forward() * self.Force * (grenade.Mass or 10)
		
		if self.Owner.TempAttributes.ProjectileModelModifier == 1 then
			grenade:GetPhysicsObject():AddAngleVelocity(Vector(math.random(-800,800),math.random(-800,800),math.random(-800,800)))
		else
			grenade:GetPhysicsObject():AddAngleVelocity(Vector(math.random(-2000,2000),math.random(-2000,2000),math.random(-2000,2000)))
		end
		grenade:GetPhysicsObject():ApplyForceCenter(vel)
	end
	
	self.NextIdle = CurTime() + (fireDur > 0 and fireDur or self:SequenceDuration())
	QueueWBIdle(self, fireDur)
	self:StopTimers()
	self:ShootEffects()
end

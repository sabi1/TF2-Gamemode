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

SWEP.Spawnable = true
SWEP.Adminonly = true
SWEP.Category = "Team Fortress 2"

SWEP.Swing = Sound("Weapon_Bat.Miss")
SWEP.SwingCrit = Sound("Weapon_Bat.MissCrit")
SWEP.HitFlesh = Sound("Weapon_BaseballBat.HitFlesh")
SWEP.HitRobot = Sound("MVM_Weapon_BaseballBat.HitFlesh")
SWEP.HitWorld = Sound("Weapon_BaseballBat.HitWorld")

SWEP.BaseDamage = 45
SWEP.DamageRandomize = 0.1
SWEP.MaxDamageRampUp = 0
SWEP.MaxDamageFalloff = 0

SWEP.Primary.Automatic		= true
SWEP.Primary.ClipSize		= -1
SWEP.Primary.Ammo			= TF_GRENADES2
SWEP.Primary.Delay          = 0.5
SWEP.Secondary.Automatic		= true
SWEP.Secondary.Ammo			= TF_GRENADES2
SWEP.Secondary.Delay          = 10
SWEP.MaxCarry = 1
SWEP.CustomHUD = {HudBowCharge = function(self) return self:Ammo1() < (self.MaxCarry or 1) end}

SWEP.HoldType = "MELEE"
SWEP.HasThirdpersonCritAnimation = false

SWEP.ProjectileShootOffset = Vector(0, 7, -6)
SWEP.Force = 1500
SWEP.AddPitch = 1
if CLIENT then
	SWEP.OffhandProjectileModel = "models/weapons/w_models/w_baseball.mdl"
	SWEP.OffhandProjectileAttachment = "effect_hand_L"
	SWEP.OffhandProjectileBone = "ValveBiped.Bip01_L_Hand"
	SWEP.OffhandProjectileOffset = Vector(1.3, 1.9, -1.0)
	SWEP.OffhandProjectileAngle = Angle(-6, 78, -98)
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
		SendWBSequence(self, "wb_idle", ACT_VM_IDLE_SPECIAL)
	end)
end

function SWEP:ApplyWBAnimations()
	self.VM_DRAW = ACT_VM_DRAW_SPECIAL
	self.VM_IDLE = ACT_VM_IDLE_SPECIAL
	self.VM_HITCENTER = {"wb_swing_a", "wb_swing_b", "wb_swing_c"}
	self.VM_SWINGHARD = {"wb_swing_a", "wb_swing_b", "wb_swing_c"}
	self.VM_INSPECT_START = ACT_MELEE_VM_INSPECT_START
	self.VM_INSPECT_IDLE = ACT_MELEE_VM_INSPECT_IDLE
	self.VM_INSPECT_END = ACT_MELEE_VM_INSPECT_END
end

function SWEP:OffhandProjectileReady()
	return self:Ammo1() >= 1
end

function SWEP:PlayWBGrabSequence()
	if not CLIENT then return end
	if not IsValid(self.Owner) or self.Owner ~= LocalPlayer() then return end
	if self.Owner:GetActiveWeapon() ~= self then return end

	local vm = self.Owner:GetViewModel()
	if not IsValid(vm) then return end

	local dur = SendWBSequence(self, "wb_grab", ACT_VM_DRAW_SPECIAL)
	self.NextIdle = CurTime() + (dur > 0 and dur or 0.25)
	QueueWBIdle(self, dur)
end

function SWEP:Think()
	self.BaseClass.Think(self)
	self:ApplyWBAnimations()
	
	if SERVER then
		self:ProcessRechargeTimer()
		self:ClampAmmo()
	elseif CLIENT then
		self:UpdateRechargeBar()

		local ammo = self:Ammo1()
		if self.LastSandmanAmmo == nil then
			self.LastSandmanAmmo = ammo
		end
		if self.LastSandmanAmmo < 1 and ammo >= 1 then
			self:PlayWBGrabSequence()
		end
		self.LastSandmanAmmo = ammo
	end
end

function SWEP:SetSandmanRechargeEndTime(t)
	self.NextRechargeTime = t
	self:SetNWFloat("SandmanRechargeEnd", t or 0)
end

function SWEP:ClampAmmo()
	if not IsValid(self.Owner) then return end
	local maxcarry = self.MaxCarry or 1
	if self:Ammo1() > maxcarry then
		self.Owner:SetAmmoCount(maxcarry, self.Primary.Ammo)
	end
end

function SWEP:Equip()
	self:CallBaseFunction("Equip")
	if SERVER then
		self:ClampAmmo()
	end
end

function SWEP:Deploy()
	local r = self:CallBaseFunction("Deploy")
	self:ApplyWBAnimations()
	local drawSequence = self:Ammo1() >= 1 and {"wb_grab", "wb_draw"} or {"wb_draw", "wb_grab"}
	local dur = SendWBSequence(self, drawSequence, ACT_VM_DRAW_SPECIAL)
	if dur > 0 then
		self.NextIdle = CurTime() + dur
		QueueWBIdle(self, dur)
	end
	if SERVER then
		self:ClampAmmo()
	elseif CLIENT then
		self.LastSandmanAmmo = self:Ammo1()
		self:UpdateRechargeBar()
	end
	return r
end

function SWEP:ProcessRechargeTimer()
	if not IsValid(self.Owner) then return end
	local maxcarry = self.MaxCarry or 1
	if self:Ammo1() >= maxcarry then
		self:SetSandmanRechargeEndTime(nil)
		return
	end
	
	if not self.NextRechargeTime then
		self:SetSandmanRechargeEndTime(CurTime() + self.Secondary.Delay)
		return
	end
	
	if CurTime() < self.NextRechargeTime then return end
	
	local ammoid = game.GetAmmoID(self.Primary.Ammo)
	if ammoid and ammoid >= 0 then
		self.Owner:SetAmmo(math.min(self:Ammo1() + 1, maxcarry), ammoid)
	else
		self.Owner:GiveAmmo(1, self.Primary.Ammo)
	end
	self:SetSandmanRechargeEndTime(nil)
end

function SWEP:UpdateRechargeBar()
	if not IsValid(self.Owner) or self.Owner ~= LocalPlayer() or not IsValid(HudBowCharge) then return end
	if self.Owner:GetActiveWeapon() ~= self then return end
	
	if self:Ammo1() >= (self.MaxCarry or 1) then
		return
	end
	
	local progress = 0
	local recharge_end = self:GetNWFloat("SandmanRechargeEnd", 0)
	if recharge_end > 0 then
		local recharge = self.Secondary.Delay or 10
		local elapsed = recharge - math.max(0, recharge_end - CurTime())
		progress = math.Clamp(elapsed / recharge, 0, 1)
	end
	
	HudBowCharge:SetProgress(progress)
end


function SWEP:SecondaryAttack()
	if SERVER then
		self:ClampAmmo()
	end
	if self:Ammo1() < 1 then return end
	
	self.Owner:DoAnimationEvent(ACT_MP_ATTACK_STAND_MELEE_SECONDARY)
	local fireDur = SendWBSequence(self, "wb_fire", ACT_VM_PRIMARYATTACK_SPECIAL)
	self:SetNextPrimaryFire( CurTime() + 0.25 )
	self:SetNextSecondaryFire( CurTime() + self.Secondary.Delay )
	self:TakePrimaryAmmo(1)
	if SERVER then
		self:SetSandmanRechargeEndTime(CurTime() + self.Secondary.Delay)
	end
	if SERVER then
		self.Owner:EmitSoundEx("Weapon_BaseballBat.HitBall")
		local grenade = ents.Create("tf_projectile_ball")
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

function SWEP:Holster()
	if CLIENT and IsValid(HudBowCharge) then
		HudBowCharge:SetProgress(0)
		self.LastSandmanAmmo = nil
	end
	return self:CallBaseFunction("Holster")
end

if SERVER then
	AddCSLuaFile( "shared.lua" )
	
end

if CLIENT then

SWEP.PrintName			= "Gas Passer"
SWEP.HasCModel = true
SWEP.Slot				= 1

SWEP.RenderGroup 		= RENDERGROUP_BOTH

end

SWEP.Base				= "tf_weapon_melee_base"
SWEP.Slot				= 1

SWEP.ViewModel			= "models/weapons/c_models/c_pyro_arms.mdl"
SWEP.WorldModel			= "models/weapons/c_models/c_gascan/c_gascan.mdl"
SWEP.Crosshair = "tf_crosshair3"

SWEP.MuzzleEffect = ""

SWEP.ShootSound = "weapons/gas_can_throw.wav"
SWEP.ShootCritSound = "weapons/gas_can_throw.wav"

SWEP.Primary.ClipSize		= -1
SWEP.Primary.Ammo			= TF_GRENADES2
SWEP.Primary.Delay          = 1

SWEP.ReloadSingle = false

SWEP.HasCustomMeleeBehaviour = true
SWEP.IsMeleeWeapon = false

SWEP.HoldType = "ITEM2"
SWEP.GlobalCustomHUD = {HudItemEffectMeter = function(self) return self:Ammo1() < (self.MaxCarry or 1) end}

SWEP.ProjectileShootOffset = Vector(0, 0, 0)

SWEP.Force = 800
SWEP.AddPitch = -4
SWEP.RechargeTime = 180
SWEP.MaxCarry = 1

function SWEP:InspectAnimCheck()
self:CallBaseFunction("InspectAnimCheck")
self.VM_DRAW = ACT_ITEM2_VM_DRAW
self.VM_IDLE = ACT_ITEM2_VM_IDLE
self.VM_PRIMARYATTACK = ACT_ITEM2_VM_FIRE
self.VM_INSPECT_START = ACT_ITEM2_VM_INSPECT_START
self.VM_INSPECT_IDLE = ACT_ITEM2_VM_INSPECT_IDLE
self.VM_INSPECT_END = ACT_ITEM2_VM_INSPECT_END
end

function SWEP:Think()
	self.BaseClass.Think(self)
	self.Owner:SetPoseParameter("r_arm", 2.2)
	self.Owner:SetPoseParameter("r_hand_grip", 10.8)
	if CLIENT then
		self:UpdateRechargeBar()
	end
end

function SWEP:Equip()
	self:CallBaseFunction("Equip")
	if SERVER then
		if self.Owner.NextGiveAmmoType == self.Primary.Ammo then
			self.Owner.NextGiveAmmo = nil
			self.Owner.NextGiveAmmoType = nil
		end
		self:RestorePersistentCharge()
		self:ResetForCurrentLife()
		self:ClampAmmo()
	end
end

function SWEP:Deploy()
	local r = self:CallBaseFunction("Deploy")
	if CLIENT then
		self:UpdateRechargeBar()
	end
	return r
end

function SWEP:SetRechargeEndTime(t)
	self.NextRechargeTime = t
	self:SetNWFloat("GasRechargeEnd", t or 0)
end

function SWEP:ResetForCurrentLife()
	if not IsValid(self.Owner) then return end
	if self.LastTrackedAmmo == nil then
		self.LastTrackedAmmo = self:Ammo1()
	end
	
	if self:Ammo1() < (self.MaxCarry or 1) and not self.NextRechargeTime then
		self:SetRechargeEndTime(CurTime() + (self.RechargeTime or 20))
	end
end

function SWEP:GetPersistentChargeFraction()
	if not IsValid(self.Owner) then return 0 end
	return math.Clamp(self.Owner:GetNWFloat("GasPasserChargeFrac", 0), 0, 1)
end

function SWEP:SetPersistentChargeFraction(f)
	if not IsValid(self.Owner) then return end
	self.Owner:SetNWFloat("GasPasserChargeFrac", math.Clamp(f or 0, 0, 1))
end

function SWEP:GetCurrentChargeFraction()
	local maxcarry = self.MaxCarry or 1
	if self:Ammo1() >= maxcarry then
		return 1
	end
	
	local recharge = self.RechargeTime or 20
	local recharge_end = self.NextRechargeTime or self:GetNWFloat("GasRechargeEnd", 0)
	if recharge_end and recharge_end > CurTime() then
		local remaining = math.max(0, recharge_end - CurTime())
		return math.Clamp(1 - (remaining / recharge), 0, 1)
	end
	
	return 0
end

function SWEP:RestorePersistentCharge()
	if not IsValid(self.Owner) then return end
	local frac = self:GetPersistentChargeFraction()
	local maxcarry = self.MaxCarry or 1
	
	if frac >= 1 then
		self.Owner:SetAmmoCount(maxcarry, self.Primary.Ammo)
		self:SetRechargeEndTime(nil)
	else
		self.Owner:SetAmmoCount(0, self.Primary.Ammo)
		local remaining = (1 - frac) * (self.RechargeTime or 20)
		self:SetRechargeEndTime(CurTime() + math.max(0, remaining))
	end
	
	self.LastTrackedAmmo = self:Ammo1()
end

function SWEP:ClampAmmo()
	if not IsValid(self.Owner) then return end
	local maxcarry = self.MaxCarry or 1
	if self:Ammo1() > maxcarry then
		self.Owner:SetAmmoCount(maxcarry, self.Primary.Ammo)
	end
end

function SWEP:ProcessRechargeTimer()
	if not IsValid(self.Owner) then return end
	local maxcarry = self.MaxCarry or 1
	if self:Ammo1() >= maxcarry then
		self:SetRechargeEndTime(nil)
		return
	end
	
	if not self.NextRechargeTime then
		self:SetRechargeEndTime(CurTime() + (self.RechargeTime or 20))
		return
	end
	
	if CurTime() < self.NextRechargeTime then return end
	
	if self:Ammo1() < maxcarry then
		local ammoid = game.GetAmmoID(self.Primary.Ammo)
		if ammoid and ammoid >= 0 then
			self.Owner:SetAmmo(math.min(self:Ammo1() + 1, maxcarry), ammoid)
		else
			self.Owner:GiveAmmo(1, self.Primary.Ammo)
		end
		if self:Ammo1() >= maxcarry then
			self.Owner:EmitSoundEx("Recon.Ping", 75)
		end
	end
	
	self.LastTrackedAmmo = self:Ammo1()
	self:SetRechargeEndTime(nil)
end

function SWEP:BlockExternalAmmoGain()
	if not IsValid(self.Owner) then return end
	local current = self:Ammo1()
	if self.LastTrackedAmmo == nil then
		self.LastTrackedAmmo = current
		return
	end
	
	if current > self.LastTrackedAmmo then
		self.Owner:SetAmmoCount(self.LastTrackedAmmo, self.Primary.Ammo)
		current = self.LastTrackedAmmo
	end
	
	self.LastTrackedAmmo = current
end

function SWEP:ServerRechargeThink()
	if not IsValid(self.Owner) then return end
	self:ResetForCurrentLife()
	self:BlockExternalAmmoGain()
	self:ClampAmmo()
	self:ProcessRechargeTimer()
	self:SetPersistentChargeFraction(self:GetCurrentChargeFraction())
end

function SWEP:UpdateRechargeBar()
	-- Kept for compatibility with legacy callers; meter now uses HudItemEffectMeter.
	return
end

function SWEP:GetHUDMeterName()
	return "#TF_Gas"
end

function SWEP:GetHUDMeterResFile()
	return "resource/ui/huditemeffectmeter_pyro.res"
end

function SWEP:GetHUDMeterValue()
	local maxcarry = self.MaxCarry or 1
	if self:Ammo1() >= maxcarry then
		return 1
	end

	local recharge_end = self:GetNWFloat("GasRechargeEnd", 0)
	if recharge_end > 0 then
		local recharge = self.RechargeTime or 20
		if recharge <= 0 then return 0 end
		local elapsed = recharge - math.max(0, recharge_end - CurTime())
		return math.Clamp(elapsed / recharge, 0, 1)
	end

	return 0
end

function SWEP:PredictCriticalHit()
end

-- Pyro's ITEM2 locomotion can fail on some models; fall back to SECONDARY2 movement activities.
function SWEP:TranslateActivity(act)
	local translated = self.ActivityTranslate and self.ActivityTranslate[act]
	if translated and translated ~= ACT_INVALID then
		return translated
	end

	if IsValid(self.Owner) and self.Owner:GetPlayerClass() == "pyro" then
		local fallback
		if act == ACT_MP_STAND_IDLE then
			fallback = ACT_MP_STAND_SECONDARY2
		elseif act == ACT_MP_RUN or act == ACT_MP_WALK then
			fallback = ACT_MP_RUN_SECONDARY2
		elseif act == ACT_MP_CROUCH_IDLE then
			fallback = ACT_MP_CROUCH_SECONDARY2
		elseif act == ACT_MP_CROUCHWALK then
			fallback = ACT_MP_CROUCHWALK_SECONDARY2
		elseif act == ACT_MP_SWIM then
			fallback = ACT_MP_SWIM_SECONDARY2
		elseif act == ACT_MP_AIRWALK then
			fallback = ACT_MP_AIRWALK_SECONDARY2
		elseif act == ACT_MP_JUMP or act == ACT_MP_JUMP_START then
			fallback = ACT_MP_JUMP_START_SECONDARY2
		elseif act == ACT_MP_JUMP_FLOAT then
			fallback = ACT_MP_JUMP_FLOAT_SECONDARY2
		elseif act == ACT_MP_JUMP_LAND or act == ACT_LAND then
			fallback = ACT_MP_JUMP_LAND_SECONDARY2
		end

		if fallback then
			return fallback
		end
	end

	return self.BaseClass.TranslateActivity(self, act)
end

function SWEP:MeleeAttack()
	local pos = self.Owner:GetShootPos()
	
	local wmodel = self:GetItemData().model_player or self.WorldModel
	if SERVER then
		local grenade = ents.Create("tf_projectile_gas")
		grenade:SetPos(pos)
		grenade:SetAngles(self.Owner:EyeAngles())
		
		if self:Critical() then
			grenade.critical = true
		end
		
		grenade:SetOwner(self.Owner)
		self:InitProjectileAttributes(grenade)
		
		grenade:Spawn()
		grenade:SetModel(wmodel)
		if self.Owner:EntityTeam() == TEAM_BLU or self.Owner:EntityTeam() == TF_TEAM_PVE_INVADERS then
			grenade:SetSkin(1)
		end
		
		local vel = self.Owner:GetAimVector():Angle()
		vel.p = vel.p + self.AddPitch
		vel = vel:Forward() * self.Force * (grenade.Mass or 10)
		
		grenade:GetPhysicsObject():AddAngleVelocity(Vector(math.random(-900,900),math.random(-900,900),math.random(-900,900)))
		grenade:GetPhysicsObject():ApplyForceCenter(vel)
	end
end

function SWEP:PrimaryAttack()	
	if self:Ammo1() == 0 then
		return
	end
	
	if SERVER then
		self.Owner:Speak("TLK_JARATE_LAUNCH")
		//self.Owner:SelectWeapon("tf_weapon_club")
	end
	
	self:SendWeaponAnim(self.VM_PRIMARYATTACK)
	
	
	
	self:TakePrimaryAmmo(1)
	if SERVER then
		self:SetRechargeEndTime(CurTime() + (self.RechargeTime or 20))
		self.LastTrackedAmmo = self:Ammo1()
	end
	self:EmitSound("Weapon_GasCan.Throw")
	if CLIENT then
		self.Owner:DoTauntEvent("attackstand_gascan", true)
	end
	self:SetNextPrimaryFire(CurTime() + 0.8)
	self.NextIdle = CurTime() + self:SequenceDuration() - 0.2
	
	--self.NextMeleeAttack = CurTime() + 0.25
	if not self.NextMeleeAttack then
		self.NextMeleeAttack = {}
	end
	
	table.insert(self.NextMeleeAttack, CurTime() + 0.25)
end

if SERVER then
	hook.Add("Think", "TFGasPasser_RechargeThink", function()
		for _, ply in ipairs(player.GetAll()) do
			local wep = ply:GetWeapon("tf_weapon_jar_gas")
			if IsValid(wep) then
				wep:ServerRechargeThink()
			end
		end
	end)
end

function SWEP:Holster()
	return self:CallBaseFunction("Holster")
end

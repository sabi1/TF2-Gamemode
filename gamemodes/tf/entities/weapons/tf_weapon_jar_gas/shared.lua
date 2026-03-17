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
SWEP.MaxCarry = 1
SWEP.RechargeTime = 60

local TF_GAS_DAMAGE_FOR_FULL_CHARGE = 750
local TF_GAS_AFTERBURN_DURATION = 10
local TF_GAS_EXPLODE_ON_IGNITE_RADIUS = 200

local function IsInvulnerableLikeValve(ent)
	if not IsValid(ent) or not ent.InCond then return false end
	return ent:InCond(TF_COND_INVULNERABLE)
		or ent:InCond(TF_COND_INVULNERABLE_USER_BUFF)
		or ent:InCond(TF_COND_INVULNERABLE_CARD_EFFECT)
		or ent:InCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED)
end

local function CanGasAffectTarget(attacker, target)
	if not IsValid(attacker) or not IsValid(target) then return false end
	if not target.IsTFPlayer or not target:IsTFPlayer() then return false end
	if target == attacker then return false end
	if not attacker.IsValidEnemy or not attacker:IsValidEnemy(target) then return false end
	if target.InCond and (target:InCond(TF_COND_PHASE) or target:InCond(TF_COND_PASSTIME_INTERCEPTION)) then return false end
	if IsInvulnerableLikeValve(target) then return false end
	if target.CanReceiveCrits and not target:CanReceiveCrits() then return false end
	return true
end

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
	if SERVER then
		if self.Owner:GetActiveWeapon() == self then
			self:ResetForCurrentLife()
			self:BlockExternalAmmoGain()
			self:ClampAmmo()
		end
	else
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
	self:SetRechargeEndTime(nil)
	self:RestorePersistentCharge()
	self.LastTrackedAmmo = self:Ammo1()
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

	return self:GetPersistentChargeFraction()
end

function SWEP:AdvancePassiveRecharge()
	if not IsValid(self.Owner) then return end
	if self:Ammo1() >= (self.MaxCarry or 1) then return end

	local now = CurTime()
	local last = self._GasLastRechargeUpdate or now
	self._GasLastRechargeUpdate = now

	local recharge = tonumber(self.RechargeTime) or 180
	if recharge <= 0 then return end

	local frac = self:GetPersistentChargeFraction() + math.max(0, now - last) / recharge
	self:SetPersistentChargeFraction(math.Clamp(frac, 0, 1))

	if self:GetPersistentChargeFraction() >= 1 then
		self.Owner:SetAmmoCount(self.MaxCarry or 1, self.Primary.Ammo)
		self.LastTrackedAmmo = self:Ammo1()
		self.Owner:EmitSoundEx("Recon.Ping", 75)
	end
end

function SWEP:GetDamageForFullCharge()
	return tonumber(self:GetAttributeValue("item_meter_damage_for_full_charge", TF_GAS_DAMAGE_FOR_FULL_CHARGE)) or TF_GAS_DAMAGE_FOR_FULL_CHARGE
end

function SWEP:GetChargeRateMultiplier()
	return tonumber(self:GetAttributeValue("mult_item_meter_charge_rate", 1)) or 1
end

function SWEP:RestorePersistentCharge()
	if not IsValid(self.Owner) then return end
	local frac = self:GetPersistentChargeFraction()
	local maxcarry = self.MaxCarry or 1

	self:SetRechargeEndTime(nil)
	self.Owner:SetAmmoCount((frac >= 1) and maxcarry or 0, self.Primary.Ammo)
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
	return
end

function SWEP:BlockExternalAmmoGain()
	if not IsValid(self.Owner) then return end
	local current = self:Ammo1()
	if self.LastTrackedAmmo == nil then
		self.LastTrackedAmmo = current
		return
	end
	
	local maxcarry = self.MaxCarry or 1
	local expected = (self:GetPersistentChargeFraction() >= 1) and maxcarry or 0
	if current ~= expected then
		self.Owner:SetAmmoCount(expected, self.Primary.Ammo)
		current = expected
	end
	
	self.LastTrackedAmmo = current
end

function SWEP:ServerRechargeThink()
	return
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
	return self:GetCurrentChargeFraction()
end

function SWEP:CanAttack()
	if self:GetCurrentChargeFraction() < 1 then
		return false
	end

	return self.BaseClass.CanAttack(self)
end

function SWEP:ShouldUpdateMeter()
	return IsValid(self.Owner) and self.Owner:Alive()
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

function SWEP:SetChargeFraction(frac)
	if not IsValid(self.Owner) then return end

	local clamped = math.Clamp(tonumber(frac) or 0, 0, 1)
	local maxcarry = self.MaxCarry or 1

	self:SetRechargeEndTime(nil)
	self._GasLastRechargeUpdate = CurTime()
	self:SetPersistentChargeFraction(clamped)
	self.Owner:SetAmmoCount((clamped >= 1) and maxcarry or 0, self.Primary.Ammo)
	self.LastTrackedAmmo = self:Ammo1()

	if clamped >= 1 then
		self.Owner:EmitSoundEx("Recon.Ping", 75)
	end
end

function SWEP:AddChargeFromDamage(damage, dmginfo)
	if not IsValid(self.Owner) then return end
	if self:Ammo1() >= (self.MaxCarry or 1) then return end
	if not dmginfo or not IsValid(dmginfo:GetAttacker()) or dmginfo:GetDamage() <= 0 then return end

	local inflictor = dmginfo:GetInflictor()
	if IsValid(inflictor) and inflictor:GetClass() == "tf_entitybleed" and inflictor.TFGasPasserExplodeBleed and inflictor:GetOwner() == self.Owner then
		return
	end

	local damageToFull = self:GetDamageForFullCharge()
	if damageToFull <= 0 then return end

	damageToFull = damageToFull * self:GetChargeRateMultiplier()
	if damageToFull <= 0 then return end

	local nextFrac = self:GetPersistentChargeFraction() + (math.max(0, damage or 0) / damageToFull)
	local wasFull = self:GetPersistentChargeFraction() >= 1
	self:SetPersistentChargeFraction(math.Clamp(nextFrac, 0, 1))

	if self:GetPersistentChargeFraction() >= 1 then
		self.Owner:SetAmmoCount(self.MaxCarry or 1, self.Primary.Ammo)
		if not wasFull then
			self.Owner:EmitSoundEx("Recon.Ping", 75)
		end
	else
		self.Owner:SetAmmoCount(0, self.Primary.Ammo)
	end

	self.LastTrackedAmmo = self:Ammo1()
end

function SWEP:HandleExplodeOnIgnite(victim)
	if tonumber(self:GetAttributeValue("explode_on_ignite", 0)) == 0 then return end
	if not IsValid(self.Owner) or not IsValid(victim) then return end

	local exploded = false
	for _, ent in ipairs(ents.FindInSphere(victim:GetPos(), TF_GAS_EXPLODE_ON_IGNITE_RADIUS)) do
		if ent ~= victim and CanGasAffectTarget(self.Owner, ent) then
			local tr = util.TraceLine({
				start = victim:WorldSpaceCenter(),
				endpos = ent:WorldSpaceCenter(),
				filter = {victim, ent, self.Owner},
				mask = MASK_SHOT,
			})

			if not tr.Hit or tr.Entity == ent then
				ent:AddCond(TF_COND_BLEEDING, 0.1, self.Owner)
				if IsValid(ent.BleedEntity) then
					ent.BleedEntity.TFGasPasserExplodeBleed = true
				end
				exploded = true
			end
		end
	end

	if exploded then
		victim:EmitSound("Weapon_Grenade_Pipebomb.Explode", 75, 100)
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
		self:SetChargeFraction(0)
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
	hook.Add("Think", "TFGasPasser_PassiveRecharge", function()
		for _, ply in ipairs(player.GetAll()) do
			if not IsValid(ply) then continue end

			local gasWep = ply:GetWeapon("tf_weapon_jar_gas")
			if IsValid(gasWep) then
				gasWep:ResetForCurrentLife()
				gasWep:AdvancePassiveRecharge()
				gasWep:BlockExternalAmmoGain()
				gasWep:ClampAmmo()
			end
		end
	end)

	hook.Add("EntityTakeDamage", "TFGasPasser_SourceParity", function(target, dmginfo)
		local attacker = dmginfo:GetAttacker()

		if IsValid(attacker) and attacker:IsPlayer() and IsValid(target) and attacker ~= target and (target:IsPlayer() or target:IsNPC() or target:IsNextBot()) and attacker.CanDamage and attacker:CanDamage(target) then
			local gasWep = attacker:GetWeapon("tf_weapon_jar_gas")
			if IsValid(gasWep) then
				gasWep:AddChargeFromDamage(dmginfo:GetDamage(), dmginfo)
			end
		end

		if not IsValid(target) or not target.IsTFPlayer or not target:IsTFPlayer() or not target.InCond or not target:InCond(TF_COND_GAS) then return end
		if dmginfo:GetDamage() <= 0 then return end

		local douser = target.GetConditionProvider and target:GetConditionProvider(TF_COND_GAS) or nil
		if not IsValid(douser) or not douser:IsPlayer() then
			douser = target
		end

		local gasWep = IsValid(douser) and douser:GetWeapon("tf_weapon_jar_gas") or nil
		if target.GetPlayerClass and target:GetPlayerClass() == "pyro" then
			target:AddCond(TF_COND_BURNING_PYRO, TF_GAS_AFTERBURN_DURATION, douser)
		end
		target:AddCond(TF_COND_BURNING, TF_GAS_AFTERBURN_DURATION, douser)
		target:RemoveCond(TF_COND_GAS, true)

		if IsValid(gasWep) then
			gasWep:HandleExplodeOnIgnite(target)
		end
	end)
end

function SWEP:Holster()
	return self:CallBaseFunction("Holster")
end

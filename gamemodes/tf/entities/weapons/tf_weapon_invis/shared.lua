if SERVER then
	AddCSLuaFile()
end

SWEP.Base = "tf_weapon_base"

SWEP.ViewModel = "models/weapons/c_models/c_spy_arms.mdl"
SWEP.WorldModel = "models/weapons/w_models/w_invis.mdl"
SWEP.UseHands = false

SWEP.HoldType = "PDA"
SWEP.HoldTypeHL2 = "normal"

SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 0.1
SWEP.HasSecondaryFire = false

SWEP.Slot = 1
SWEP.DeployDuration = 0

SWEP.CritsEnabled = false
SWEP.Category = "Team Fortress 2"
SWEP.Spawnable = false
SWEP.AdminSpawnable = false

SWEP.GlobalCustomHUD = { HudSpyCloak = true }
SWEP.CustomHUD = { HudSpyCloak = true }

local INVIS_BASE = 0
local INVIS_FEIGN_DEATH = 1
local INVIS_MOTION_CLOAK = 2

local tf_spy_invis_unstealth_time = CreateConVar("tf_spy_invis_unstealth_time", "1.0", {FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE})
local tf_spy_cloak_consume_rate = CreateConVar("tf_spy_cloak_consume_rate", "10", {FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE})
local tf_spy_cloak_regen_rate = CreateConVar("tf_spy_cloak_regen_rate", "3.3", {FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE})
local tf_spy_cloak_no_attack_time = CreateConVar("tf_spy_cloak_no_attack_time", "2.0", {FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE})
local tf_feign_death_speed_duration = CreateConVar("tf_feign_death_speed_duration", "3.0", {FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE})

local function has_any_stealth_cond(owner)
	if not IsValid(owner) or not owner.InCond then return false end
	return owner:InCond(TF_COND_STEALTHED)
		or owner:InCond(TF_COND_STEALTHED_USER_BUFF)
		or owner:InCond(TF_COND_STEALTHED_USER_BUFF_FADING)
end

local function set_watch_idle_time(wep, when)
	if not IsValid(wep) then return end
	if wep.SetWeaponIdleTime then
		wep:SetWeaponIdleTime(when)
	else
		wep.NextIdle = when
	end
end

function SWEP:Initialize()
	self:CallBaseFunction("Initialize")
	self:SetWeaponHoldType(self.HoldType)
	self:SetNWFloat("SpyCloakMeter", 100)
	self.CloakConsumeRate = tf_spy_cloak_consume_rate:GetFloat()
	self.CloakRegenRate = tf_spy_cloak_regen_rate:GetFloat()
end

function SWEP:Equip()
	self:SetCloakMeter(100)
	return self:CallBaseFunction("Equip")
end

function SWEP:Deploy()
	-- Spawn parity: freshly given watch should start full, but swapping back to
	-- the watch later in the same life must not refill cloak.
	if not self._tfCloakInitializedThisLife then
		self:SetCloakMeter(100)
		self._tfCloakInitializedThisLife = true
	end
	local ok = self:CallBaseFunction("Deploy")
	-- Valve parity: watch deploy idles for 1.5s.
	set_watch_idle_time(self, CurTime() + 1.5)
	return ok
end

function SWEP:GetInvisType()
	return math.floor(tonumber(self.WeaponMode) or INVIS_BASE)
end

function SWEP:HasFeignDeath()
	return self:GetInvisType() == INVIS_FEIGN_DEATH
end

function SWEP:HasMotionCloak()
	return self:GetInvisType() == INVIS_MOTION_CLOAK
end

function SWEP:GetCloakMeter()
	local owner = self:GetOwner()
	if IsValid(owner) then
		return math.Clamp(owner:GetNWFloat("SpyCloakMeter", 100), 0, 100)
	end
	return math.Clamp(self:GetNWFloat("SpyCloakMeter", 100), 0, 100)
end

function SWEP:SetCloakMeter(v)
	local meter = math.Clamp(tonumber(v) or 0, 0, 100)
	self:SetNWFloat("SpyCloakMeter", meter)

	local owner = self:GetOwner()
	if IsValid(owner) then
		owner:SetNWFloat("SpyCloakMeter", meter)
	end
	return meter
end

function SWEP:IsFeignDeathReady()
	local owner = self:GetOwner()
	if not IsValid(owner) then return false end
	return owner:GetNWBool("TFFeignDeathReady", false)
end

function SWEP:SetFeignDeathState(enabled)
	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	if owner.InCond and owner:InCond(TF_COND_GRAPPLINGHOOK) then return end

	enabled = enabled == true
	owner:SetNWBool("TFFeignDeathReady", enabled)
	owner:SetNWFloat("TFNextStealthTime", CurTime() + (enabled and 0.5 or 0.1))

	-- Valve parity: disabling feign-ready while not currently stealthed applies
	-- a short primary-attack lockout on the active weapon.
	if not enabled and not (owner.InCond and owner:InCond(TF_COND_STEALTHED)) then
		local active = owner.GetActiveWeapon and owner:GetActiveWeapon() or nil
		if IsValid(active) and active ~= self and active.SetNextPrimaryFire then
			active:SetNextPrimaryFire(CurTime() + 0.1)
		end
	end
end

function SWEP:PlayWatchActivationAnim()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	if owner:GetActiveWeapon() ~= self then return end

	local act = self.VM_SECONDARYATTACK or self.VM_PRIMARYATTACK or ACT_VM_SECONDARYATTACK
	if act then
		self:SendWeaponAnimEx(act)
		local vm = owner.GetViewModel and owner:GetViewModel() or nil
		local duration = (IsValid(vm) and vm:SequenceDuration()) or self:SequenceDuration() or 0
		set_watch_idle_time(self, CurTime() + math.max(0.1, duration))
	end
end

function SWEP:SetCloakRates()
	local consumeRate = tf_spy_cloak_consume_rate:GetFloat()
	local consumeFactor = tonumber(self:GetAttributeValue("mult_cloak_meter_consume_rate", 1)) or 1
	if consumeFactor < 1 then
		consumeFactor = 1 / (2 - consumeFactor)
	end
	self.CloakConsumeRate = consumeRate * consumeFactor

	local regenRate = tf_spy_cloak_regen_rate:GetFloat()
	local regenFactor = tonumber(self:GetAttributeValue("mult_cloak_meter_regen_rate", 1)) or 1
	self.CloakRegenRate = regenRate * regenFactor
end

function SWEP:CanGoInvisible()
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:Alive() then return false end
	if owner.InCond and owner:InCond(TF_COND_GRAPPLINGHOOK) then return false end
	if owner.InCond and owner:InCond(TF_COND_TAUNTING) then return false end
	if owner.HasTheFlag and owner:HasTheFlag() then return false end
	return true
end

function SWEP:GetDecloakRateScale()
	local scale = tonumber(self:GetAttributeValue("mult_decloak_rate", 1)) or 1
	if scale <= 0 then
		scale = 1
	end
	return scale
end

function SWEP:DoDecloak()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local rateScale = self:GetDecloakRateScale()
	local fadeTime = math.max(0.15, tf_spy_invis_unstealth_time:GetFloat() * rateScale)

	if owner.InCond then
		owner:RemoveCond(TF_COND_STEALTHED, true)
	end
	owner:SetNWFloat("TFNextStealthTime", CurTime() + fadeTime)

	-- Valve parity: decloak blocks attacking for a short duration (except user-buff stealth).
	if not (owner.InCond and owner:InCond(TF_COND_STEALTHED_USER_BUFF)) then
		local noAttackExpire = CurTime() + (tf_spy_cloak_no_attack_time:GetFloat() * rateScale)
		owner:SetNWFloat("TFStealthNoAttackExpire", noAttackExpire)
	end
end

function SWEP:ActivateInvisibilityWatch()
	local owner = self:GetOwner()
	if not IsValid(owner) then return false end

	self:SetCloakRates()
	local changedState = false

	local doSkill = false
	if owner.InCond and owner:InCond(TF_COND_STEALTHED) then
		self:DoDecloak()
		changedState = true
	else
		if self:HasFeignDeath() then
			if self:IsFeignDeathReady() then
				self:SetFeignDeathState(false)
				changedState = true
			elseif self:GetCloakMeter() >= 100 then
				self:SetFeignDeathState(true)
				changedState = true
			end
		elseif self:CanGoInvisible() and self:GetCloakMeter() > 8 then
			owner:AddCond(TF_COND_STEALTHED, PERMANENT_CONDITION or -1, owner)
			owner:SetNWFloat("TFNextStealthTime", CurTime() + 0.5)
			doSkill = true
			changedState = true
		end
	end

	if changedState then
		self:PlayWatchActivationAnim()
	end

	if not doSkill then
		owner:SetNWFloat("TFNextStealthTime", CurTime() + 0.1)
	end

	return doSkill
end

function SWEP:CleanupInvisibilityWatch()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	owner:SetNWBool("TFFeignDeathReady", false)
	if owner.InCond and has_any_stealth_cond(owner) then
		self:DoDecloak()
	end
end

function SWEP:PrimaryAttack()
	-- Intentionally empty (TF2 behavior)
end

function SWEP:SecondaryAttack()
	self:ActivateInvisibilityWatch()
	self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)
end

function SWEP:GlobalSecondaryAttack()
	if not IsValid(self:GetOwner()) then return end
	if CurTime() < (self:GetNextSecondaryFire() or 0) then return end
	self:SecondaryAttack()
end

function SWEP:OnRemove()
	self:CleanupInvisibilityWatch()
	return self:CallBaseFunction("OnRemove")
end

function SWEP:Holster()
	self:SetNextPrimaryFire(CurTime() + 10)
	self:SetNextSecondaryFire(CurTime() + 10)
	-- Valve parity: holstered watch idles far in the future.
	set_watch_idle_time(self, CurTime() + 10)
	return self:CallBaseFunction("Holster")
end

function SWEP:Think()
	self:CallBaseFunction("Think")

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	self:SetCloakRates()

	local meter = self:GetCloakMeter()
	local ft = FrameTime()
	local stealthed = owner.InCond and owner:InCond(TF_COND_STEALTHED)

	if stealthed then
		if self:HasMotionCloak() then
			local speedSqr = owner:GetVelocity():LengthSqr()
			if speedSqr <= 1 and meter < 100 then
				meter = meter + ft * self.CloakRegenRate
			else
				local maxSpeed = math.max(owner.MaxSpeed and owner:MaxSpeed() or 300, 1)
				local factor = math.Clamp(math.sqrt(speedSqr) / maxSpeed, 0, 1)
				meter = meter - ft * self.CloakConsumeRate * factor * 1.5
			end
		else
			meter = meter - ft * self.CloakConsumeRate
		end

		meter = self:SetCloakMeter(meter)
		if meter <= 0 and not self:HasMotionCloak() then
			self:DoDecloak()
		end
	else
		meter = self:SetCloakMeter(meter + ft * self.CloakRegenRate)
	end

	if CLIENT and owner == LocalPlayer() and HudDemomanPipes then
		HudDemomanPipes:SetChargeStatus(0)
		HudDemomanPipes:SetProgress((meter or 0) / 100)
	end
end

function SWEP:GetFeignDeathSpeedDuration()
	return tf_feign_death_speed_duration:GetFloat()
end

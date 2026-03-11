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

local function has_any_stealth_cond(owner)
	if not IsValid(owner) or not owner.InCond then return false end
	return owner:InCond(TF_COND_STEALTHED)
		or owner:InCond(TF_COND_STEALTHED_USER_BUFF)
		or owner:InCond(TF_COND_STEALTHED_USER_BUFF_FADING)
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
	return true
end

function SWEP:DoDecloak()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	if owner.InCond then
		owner:RemoveCond(TF_COND_STEALTHED, true)
	end
	owner:SetNWFloat("TFNextStealthTime", CurTime() + tf_spy_invis_unstealth_time:GetFloat())
	owner:EmitSound("Player.Spy_UnCloak")
end

function SWEP:ActivateInvisibilityWatch()
	local owner = self:GetOwner()
	if not IsValid(owner) then return false end

	self:SetCloakRates()

	local doSkill = false
	if owner.InCond and owner:InCond(TF_COND_STEALTHED) then
		self:DoDecloak()
	else
		if self:HasFeignDeath() then
			if self:IsFeignDeathReady() then
				self:SetFeignDeathState(false)
			elseif self:GetCloakMeter() >= 100 then
				self:SetFeignDeathState(true)
			end
		elseif self:CanGoInvisible() and self:GetCloakMeter() > 8 then
			owner:AddCond(TF_COND_STEALTHED, PERMANENT_CONDITION or -1, owner)
			owner:SetNWFloat("TFNextStealthTime", CurTime() + 0.5)
			owner:EmitSound("Player.Spy_Cloak")
			doSkill = true
		end
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
			local speed = owner:GetVelocity():Length()
			local factor = math.Clamp(speed / 300, 0, 1)
			if factor < 0.5 and meter < 100 then
				meter = meter + ft * self.CloakRegenRate
			else
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

if SERVER then
	AddCSLuaFile()
end

SWEP.Base = "tf_weapon_base"

SWEP.PrintName = "Spellbook"
SWEP.Category = "Team Fortress 2"
SWEP.Spawnable = false
SWEP.AdminSpawnable = false

SWEP.ViewModel = "models/props_halloween/hwn_spellbook_upright.mdl"
SWEP.WorldModel = "models/props_halloween/hwn_spellbook_upright.mdl"
SWEP.UseHands = false

SWEP.HoldType = "PDA"
SWEP.HoldTypeHL2 = "normal"
SWEP.Hidden = true
SWEP.IsPDA = true

SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 0.1
SWEP.HasSecondaryFire = false

SWEP.Slot = 5
SWEP.DeployDuration = 0
SWEP.CritsEnabled = false

function SWEP:Initialize()
	self:CallBaseFunction("Initialize")
	self:SetWeaponHoldType(self.HoldType)
end

function SWEP:Deploy()
	return self:CallBaseFunction("Deploy")
end

function SWEP:CanDeploy()
	return true
end

function SWEP:HasUsableAmmoForSelection()
	return true
end

function SWEP:VisibleInWeaponSelection()
	return false
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

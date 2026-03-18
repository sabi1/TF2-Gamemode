	if SERVER then
	AddCSLuaFile()
end

if CLIENT then
	SWEP.PrintName			= "Horn"
SWEP.Slot				= 1
end


SWEP.Base				= "tf_weapon_melee_base"

SWEP.ViewModel			= "models/weapons/c_models/c_soldier_arms.mdl"
SWEP.WorldModel			= "models/weapons/c_models/c_sandwich/c_sandwich.mdl"
SWEP.Crosshair = "tf_crosshair3"

SWEP.Swing = Sound("weapons/buff_banner_horn_red.wav")
SWEP.SwingCrit = Sound("weapons/buff_banner_horn_blue.wav")
SWEP.Swing2 = Sound("weapons/battalions_backup_red.wav")
SWEP.SwingCrit2 = Sound("weapons/battalions_backup_blue.wav")
SWEP.HitFlesh = Sound("")
SWEP.HitWorld = Sound("weapons/buff_banner_flag.wav")

SWEP.BaseDamage = 45
SWEP.DamageRandomize = 0.1
SWEP.MaxDamageRampUp = 0
SWEP.MaxDamageFalloff = 0

SWEP.Primary.Automatic		= true
SWEP.Primary.Ammo			= "none"
SWEP.Primary.Delay          = 30
SWEP.Secondary.Automatic		= true
SWEP.Secondary.Ammo			= "none"
SWEP.Secondary.Delay          = 30
SWEP.RangedMinHealing = 45
SWEP.RangedMaxHealing = 85

SWEP.HoldType = "MELEE"
SWEP.GlobalCustomHUD = {HudItemEffectMeter = true}

local BOOST_METER_NWKEY = "TFBoostMeter"
local BOOST_METER_MAX = 100

local function GetOwnerBoostFraction(owner)
	if not IsValid(owner) then return 0 end
	local maxValue = 0
	for _, wep in ipairs(owner:GetWeapons() or {}) do
		if IsValid(wep) then
			maxValue = math.max(maxValue, wep:GetNWFloat(BOOST_METER_NWKEY, 0))
		end
	end
	return math.Clamp(maxValue / BOOST_METER_MAX, 0, 1)
end

local function IsOwnerBoostFull(owner)
	if not IsValid(owner) then return false end
	for _, wep in ipairs(owner:GetWeapons() or {}) do
		if IsValid(wep) and (wep:GetNWFloat(BOOST_METER_NWKEY, wep.BoostMeter or 0) >= BOOST_METER_MAX) then
			return true
		end
	end
	return false
end

local function ConsumeWeaponBoost(weapon, owner)
	if not IsValid(weapon) then return end
	local oldValue = weapon.BoostMeter or weapon:GetNWFloat(BOOST_METER_NWKEY, 0) or 0
	weapon.BoostMeter = 0
	weapon:SetNWFloat(BOOST_METER_NWKEY, 0)

	if SERVER and oldValue > 0 then
		local base = weapon.BoostBaseSpeedBonus
		if not base then
			base = (weapon.SpeedBonus or 1) - 0.4 * (oldValue / BOOST_METER_MAX)
		end
		weapon.BoostBaseSpeedBonus = base
		weapon.SpeedBonus = base
		if IsValid(owner) and owner:IsPlayer() and not owner:IsHL2() then
			owner:ResetClassSpeed()
		end
	end
end

function SWEP:GetHUDMeterName()
	return "#TF_Rage"
end

function SWEP:GetHUDMeterResFile()
	return "resource/ui/huditemeffectmeter.res"
end

function SWEP:GetHUDMeterValue()
	return GetOwnerBoostFraction(self.Owner)
end

function SWEP:InitAttributes(owner, attributes)
	local merged = attributes and table.Copy(attributes) or {}
	local hasBoostOnDamage = false
	for _, att in pairs(merged) do
		if att and att.attribute_class == "boost_on_damage" then
			hasBoostOnDamage = true
			break
		end
	end
	if not hasBoostOnDamage then
		table.insert(merged, {
			name = "boost on damage",
			attribute_class = "boost_on_damage",
			value = 1,
		})
	end

	self:CallBaseFunction("InitAttributes", owner, merged)
	self.OnlyProvideAttributesOnActive = nil
end

function SWEP:PrimaryAttack()
	if not IsOwnerBoostFull(self.Owner) then return end
	ConsumeWeaponBoost(self, self.Owner)
	local owner = self.Owner

	self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
	self:SendWeaponAnim(ACT_ITEM1_VM_SECONDARYATTACK)
		owner:DoAnimationEvent(ACT_MP_ATTACK_STAND_ITEM1, true)
		if self:GetItemData().model_player == "models/weapons/c_models/c_battalion_bugle/c_battalion_bugle.mdl" then
			if owner:Team() == TEAM_BLU then
				self:EmitSound(self.SwingCrit2, 85 )
			elseif owner:Team() == TF_TEAM_PVE_INADERS then
				self:EmitSound(self.SwingCrit2, 85 )
			else
				self:EmitSound(self.Swing2, 85 )
			end
		else
			if owner:Team() == TEAM_BLU then
				self:EmitSound(self.SwingCrit, 85 )
			elseif owner:Team() == TF_TEAM_PVE_INADERS then
				self:EmitSound(self.SwingCrit, 85 )
			else
				self:EmitSound(self.Swing, 85 )
			end
		end
	timer.Simple(3, function()
		if SERVER and IsValid(owner) then
		owner:EmitSoundEx( self.HitWorld, 85	 )
		owner:Speak("TLK_PLAYER_BATTLECRY")
		owner:SelectWeapon("tf_weapon_rocketlauncher")
		owner:SelectWeapon("tf_weapon_rocketlauncher_bbox")
		owner:SelectWeapon("tf_weapon_rocketlauncher_qrl")
		owner:SelectWeapon("tf_weapon_rocketlauncher_dh")
		owner:SelectWeapon("tf_weapon_rocketlauncher_dt")
		owner:SelectWeapon("tf_weapon_rocketlauncher_airstrike")
		owner:SelectWeapon("tf_weapon_particle_launcher")
		GAMEMODE:StartMiniCritBoost(owner)
		end
	end)
	local buffDuration = 20
	if IsValid(owner) then
		local mul = tonumber(owner:GetNWFloat("TF_MVM_BuffDurationMul", 1)) or 1
		if mul < 0.1 then mul = 0.1 end
		buffDuration = buffDuration * mul
	end
	timer.Simple(buffDuration, function()
		if not IsValid(owner) then return end
		GAMEMODE:StopCritBoost(owner)
	end)
end

function SWEP:Deploy()
	if SERVER then
		local attrs = (self.GetAttributes and self:GetAttributes()) or self.Attributes or {}
		local hasBoostOnDamage = false
		for _, att in pairs(attrs) do
			if att and att.attribute_class == "boost_on_damage" then
				hasBoostOnDamage = true
				break
			end
		end
		if not hasBoostOnDamage then
			local injected = {
				name = "boost on damage",
				attribute_class = "boost_on_damage",
				value = 1,
			}
			self.Attributes = self.Attributes or {}
			table.insert(self.Attributes, injected)
			if ApplyAttributes then
				ApplyAttributes({injected}, "equip", self, self.Owner)
			end
		end
		self.OnlyProvideAttributesOnActive = nil
	end

	self:SendWeaponAnim(ACT_ITEM1_VM_DRAW)
	
	return self:CallBaseFunction("Holster")
end

function SWEP:Holster()
	self.NextMeleeAttack = nil
	
	self:StopTimers()
	
	return self:CallBaseFunction("Holster")
end

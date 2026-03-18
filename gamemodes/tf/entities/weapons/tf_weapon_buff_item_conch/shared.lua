if SERVER then
	AddCSLuaFile()
end
game.AddParticles( "particles/soldierbuff.pcf" )
PrecacheParticleSystem( "soldierbuff_red_buffed" )
PrecacheParticleSystem( "soldierbuff_blue_buffed" )

if CLIENT then
	SWEP.PrintName			= "Concheror"
	SWEP.Slot				= 1
	SWEP.HasCModel			= true

	SWEP.RenderGroup 		= RENDERGROUP_BOTH
	
end


SWEP.Base				= "tf_weapon_melee_base"

SWEP.ViewModel			= "models/weapons/c_models/c_soldier_arms.mdl"
SWEP.WorldModel			= "models/weapons/c_models/c_shogun_warhorn/c_shogun_warhorn.mdl"
SWEP.Crosshair = "tf_crosshair3"

SWEP.Spawnable = true
SWEP.SpeedEnabled = false
SWEP.AdminSpawnable = false
SWEP.Category = "Team Fortress 2"

SWEP.Swing = Sound("weapons/samurai/tf_conch.wav")	
SWEP.HitFlesh = Sound("")
SWEP.HitWorld = Sound("weapons/buff_banner_flag.wav")

SWEP.BaseDamage = 45
SWEP.DamageRandomize = 0.1
SWEP.MaxDamageRampUp = 0
SWEP.MaxDamageFalloff = 0

SWEP.Primary.Automatic		= true
SWEP.Primary.Ammo			= "none"
SWEP.Primary.Delay          = 28
SWEP.Secondary.Automatic		= true
SWEP.Secondary.Ammo			= "none"
SWEP.Secondary.Delay          = 30
SWEP.RangedMinHealing = 45
SWEP.RangedMaxHealing = 85

SWEP.HoldType = "MELEE"
SWEP.GlobalCustomHUD = {HudItemEffectMeter = true}

local BOOST_METER_NWKEY = "TFBoostMeter"
local BOOST_METER_MAX = 100

local function getConchTimerName(prefix, suffix)
	return prefix .. "_" .. tostring(suffix)
end

local function stopConchTimersForOwner(owner)
	if not IsValid(owner) then return end
	local ownerId = owner:EntIndex()
	timer.Remove(getConchTimerName("SetFasterSpeed1", ownerId))
	timer.Remove(getConchTimerName("HealFor20SecsSelf", ownerId))
	timer.Remove(getConchTimerName("RemoveBanner", ownerId))
	for _, teammate in ipairs(team.GetPlayers(owner:Team())) do
		if IsValid(teammate) then
			timer.Remove(getConchTimerName("HealFor20Secs", teammate:EntIndex()))
		end
	end
end

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

SWEP.Ready = true
function SWEP:InspectAnimCheck()
	self:CallBaseFunction("InspectAnimCheck")
	self.VM_DRAW = ACT_ITEM2_VM_DRAW
	self.VM_IDLE = ACT_ITEM2_VM_IDLE
end

function SWEP:PrimaryAttack()
	if not IsOwnerBoostFull(self.Owner) then return end
	ConsumeWeaponBoost(self, self.Owner)
	local owner = self.Owner
	if not IsValid(owner) then return end
	local ownerId = owner:EntIndex()
	local speedTimerName = getConchTimerName("SetFasterSpeed1", ownerId)
	local selfHealTimerName = getConchTimerName("HealFor20SecsSelf", ownerId)
	local bannerTimerName = getConchTimerName("RemoveBanner", ownerId)

	self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )	
	owner:DoAnimationEvent(ACT_MP_ATTACK_STAND_ITEM2, true)
	self:SendWeaponAnim(ACT_ITEM2_VM_SECONDARYATTACK)
	self:EmitSound("items/samurai/tf_conch.wav", 90, 100)
	timer.Simple(3, function()
		if not SERVER or not IsValid(self) or not IsValid(owner) then return end
		timer.Remove(speedTimerName)
		timer.Create(speedTimerName, 1, 20, function()
			if not IsValid(owner) then
				timer.Remove(speedTimerName)
				return
			end
			owner:SetClassSpeed(owner:GetClassSpeed() * 1.003)	
		end)
		local animent3 = ents.Create('base_gmodentity')
		if not IsValid(animent3) then return end
		animent3:SetAngles(owner:GetAngles())
		animent3:SetPos(owner:GetPos())
		animent3:SetModel("models/workshop_partner/weapons/c_models/c_shogun_warbanner/c_shogun_warbanner.mdl")
		animent3:Spawn()
		animent3:Activate()
		animent3:SetParent(owner)
		animent3:AddEffects(EF_BONEMERGE)
		animent3:SetName("Cosmetic"..ownerId)
		
		timer.Remove(bannerTimerName)
		if owner:GetPlayerClass() == "soldierbuffed" then	
			timer.Create(bannerTimerName, 120, 1, function()
				if IsValid(animent3) then
					animent3:Remove()
				end
			end)
		else
			timer.Create(bannerTimerName, 20, 1, function()
				if IsValid(animent3) then
					animent3:Remove()
				end
			end)
		end
		self.Ready = false
		timer.Remove(selfHealTimerName)
		timer.Create(selfHealTimerName, 1, 20, function()
			if not IsValid(owner) then
				timer.Remove(selfHealTimerName)
				return
			end
			GAMEMODE:HealPlayer(owner, owner, 30, false, false)
			owner:SetArmor(120) 
		end)
		for k,v in ipairs(team.GetPlayers(owner:Team())) do
			GAMEMODE:StartMiniCritBoost(v)
			ParticleEffectAttach("soldierbuff_red_buffed", PATTACH_ABSORIGIN_FOLLOW, v, 0)
			local teamHealTimerName = getConchTimerName("HealFor20Secs", v:EntIndex())
			timer.Remove(teamHealTimerName)
			timer.Create(teamHealTimerName, 1, 20, function()
				if not IsValid(owner) or not IsValid(v) then
					timer.Remove(teamHealTimerName)
					return
				end
				GAMEMODE:HealPlayer(owner, v, 30, false, false)
				v:SetArmor(120)
				v:SetClassSpeed(v:GetClassSpeed() * 1.003)				
			end)
		end
		self.SpeedEnabled = true
		owner:Speak("TLK_PLAYER_BATTLECRY")
		owner:SelectWeapon("tf_weapon_rocketlauncher")
		owner:SelectWeapon("tf_weapon_rocketlauncher_bbox")
		owner:SelectWeapon("tf_weapon_rocketlauncher_qrl")
		owner:SelectWeapon("tf_weapon_rocketlauncher_dh")
		owner:SelectWeapon("tf_weapon_rocketlauncher_dt")
		owner:SelectWeapon("tf_weapon_rocketlauncher_airstrike")
		owner:SelectWeapon("tf_weapon_particle_launcher")
		GAMEMODE:StartMiniCritBoost(owner)
		ParticleEffectAttach("soldierbuff_red_buffed", PATTACH_ABSORIGIN_FOLLOW, owner, 0)
	end)
	if owner:GetPlayerClass() == "soldierbuffed" then
		timer.Simple(120, function()
			if SERVER and IsValid(owner) then
				for k,v in ipairs(team.GetPlayers(owner:Team())) do
					GAMEMODE:StopCritBoost(v) 
					v:ResetClassSpeed()
					v:StopParticles() 
				end
				stopConchTimersForOwner(owner)
				GAMEMODE:StopCritBoost(owner) 
				owner:ResetClassSpeed()	
			end
			if IsValid(owner) then
				owner:StopParticles()
			end
			if IsValid(self) then
				self.SpeedEnabled = false
				self.Ready = true
			end
		end)
	else
		timer.Simple(20, function()
			if SERVER and IsValid(owner) then
				for k,v in ipairs(team.GetPlayers(owner:Team())) do
					GAMEMODE:StopCritBoost(v) 
					v:ResetClassSpeed()
					v:StopParticles() 
				end
				stopConchTimersForOwner(owner)
				GAMEMODE:StopCritBoost(owner) 
				owner:ResetClassSpeed()	
			end
			if IsValid(owner) then
				owner:StopParticles()
			end
			if IsValid(self) then
				self.SpeedEnabled = false
				self.Ready = true
			end
		end)
	end
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

	self:SendWeaponAnim(ACT_ITEM2_VM_DRAW)
	--MsgFN("Deploy %s", tostring(self))
	self.BaseClass.Deploy(self)
end

function SWEP:Holster()
	self.NextMeleeAttack = nil
	return self:CallBaseFunction("Holster")
end

function SWEP:OnRemove()
	if SERVER and IsValid(self.Owner) then
		stopConchTimersForOwner(self.Owner)
	end
end

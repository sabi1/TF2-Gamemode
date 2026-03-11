if SERVER then
	AddCSLuaFile()
end



if CLIENT then

SWEP.PrintName			= "Revolver"


end

SWEP.Base				= "tf_weapon_gun_base"

SWEP.ViewModel			= "models/weapons/c_models/c_spy_arms.mdl"
SWEP.WorldModel			= "models/weapons/c_models/c_revolver/c_revolver.mdl"
SWEP.Crosshair = "tf_crosshair2"
SWEP.Slot				= 0
SWEP.MuzzleEffect = "muzzle_revolver"
SWEP.MuzzleOffset = Vector(20, 4, -2)

SWEP.ShootSound = Sound("Weapon_Revolver.Single")
SWEP.ShootCritSound = Sound("Weapon_Revolver.SingleCrit")
SWEP.ReloadSound = Sound("Weapon_Revolver.WorldReload")

SWEP.TracerEffect = "bullet_pistol_tracer01"
PrecacheParticleSystem("bullet_pistol_tracer01_red")
PrecacheParticleSystem("bullet_pistol_tracer01_blue")
PrecacheParticleSystem("bullet_pistol_tracer01_red_crit")
PrecacheParticleSystem("bullet_pistol_tracer01_blue_crit")
PrecacheParticleSystem("muzzle_revolver")

SWEP.BaseDamage = 40
SWEP.BulletsPerShot = 1
SWEP.BulletSpread = 0.0125 * 3
SWEP.Primary.ClipSize		= 6
SWEP.Primary.DefaultClip	= SWEP.Primary.ClipSize
SWEP.Primary.Ammo			= TF_PRIMARY
SWEP.Primary.Delay          = 0.5 
SWEP.ReloadTime = 1.2

SWEP.HoldType = "SECONDARY"
SWEP.HoldTypeHL2 = "revolver"

SWEP.DeploySound = Sound("weapons/draw_secondary.wav")

SWEP.AutoReloadTime = 0.10

SWEP.IsRapidFire = false

-- Ambassador properties
SWEP.AccuracyRecoveryStartDelay = 0.5
SWEP.AccuracyRecoveryDelay = 0.5

SWEP.Spawnable = true
SWEP.AdminSpawnable = false
SWEP.Category = "Team Fortress 2"

SWEP.MinSpread = 0
SWEP.MaxSpread = 0.06
SWEP.CrosshairMaxScale = 3

local function tf_spy_current_disguise_class(owner)
	if not IsValid(owner) or owner:GetPlayerClass() ~= "spy" then
		return nil
	end
	if not owner.InCond or not owner:InCond(TF_COND_DISGUISED) then
		return nil
	end
	local className = string.lower(owner:GetNWString("TFSpyDisguiseClass", ""))
	if className == "" then
		return nil
	end
	return className
end

function SWEP:Deploy()
	--MsgFN("Deploy %s", tostring(self))
	
		if tf_spy_current_disguise_class(self.Owner) then
			self:SetWeaponHoldType("PRIMARY")			
			self.HoldType = "PRIMARY"
		end
	return self:CallBaseFunction("Deploy")
end

function SWEP:Holster()
	if (IsValid(self.Owner)) then
		if self.Owner:GetPlayerClass() == "spy" then
			if tf_spy_current_disguise_class(self.Owner) then
				self:SetWeaponHoldType("PRIMARY")			
				self.HoldType = "PRIMARY"
			else
				self:SetWeaponHoldType("SECONDARY")			
				self.HoldType = "SECONDARY"
			end
		end
	else

		self:SetWeaponHoldType("SECONDARY")			
		self.HoldType = "SECONDARY"
		
	end
	self:StopTimers()
	if IsValid(self.Owner) then
		timer.Simple(0.1, function()
			if IsValid(self.CModel3) then
				self.CModel3:Remove()
			end
		end)
		if self:GetItemData().hide_bodygroups_deployed_only then
			local visuals = self:GetVisuals()
			local owner = self.Owner
			
			if visuals.hide_player_bodygroup_names then
				for _,group in ipairs(visuals.hide_player_bodygroup_names) do
					local b = PlayerNamedBodygroups[owner:GetPlayerClass()]
					if b and b[group] then
						owner:SetBodygroup(b[group], 0)
					end
					
					b = PlayerNamedViewmodelBodygroups[owner:GetPlayerClass()]
					if b and b[group] then
						if IsValid(owner:GetViewModel()) then
							owner:GetViewModel():SetBodygroup(b[group], 0)
						end
					end
				end
			end
		end
	
		for k,v in pairs(self:GetVisuals()) do
			if k=="hide_player_bodygroup" then
				self.Owner:SetBodygroup(v,0)
			end
		end
	end
	if IsValid(animent2) then
		animent2:Fire("Kill", "", 0.1)
	end
	self.NextIdle = nil
	self.NextReloadStart = nil
	self.NextReload = nil
	self.Reloading = nil
	self.RequestedReload = nil
	self.NextDeployed = nil
	self.IsDeployed = nil
	if SERVER then
		if IsValid(self.WModel2) then
			--self.WModel2:Remove()
		end
	end
	if IsValid(self.Owner) then
		self.Owner.LastWeapon = self:GetClass()
	end
	
	return true
end

if CLIENT then

	usermessage.Hook("AmbassadorFired", function(msg)
		local self = msg:ReadEntity()
		
		self.CrosshairScale = self.CrosshairMaxScale
		self.NextStartRecovery = CurTime() + self.AccuracyRecoveryStartDelay
		self.NextEndRecovery = nil
	end)

end

function SWEP:OnEquipAttribute(a, owner)
	if a.attribute_class == "set_weapon_mode" then
		if a.value == 1 then
			self.CriticalChance = 0
			self.CritsOnHeadshot = true
			self.BulletSpread = 0
			self.HeadshotName = "tf_weapon_sniperrifle_headshot"
			self.PredictCritServerside = true
			self.AutoReloadTime = 0.21
		end
	end
end

function SWEP:PrimaryAttack()
	if not self:CallBaseFunction("PrimaryAttack") then return false end
	

	if self.WeaponMode == 1 then
		self.CritsOnHeadshot = false
		self.NameOverride = nil
		
		self.BulletSpread = self.MaxSpread
		
		self.NextStartRecovery = CurTime() + self.AccuracyRecoveryStartDelay
		self.NextEndRecovery = nil
		
		if SERVER then
			umsg.Start("AmbassadorFired", self.Owner)
				umsg.Entity(self)
			umsg.End()
		end
	end
	
	return true
end

function SWEP:Think()
	if tf_spy_current_disguise_class(self.Owner) then
		self:SetWeaponHoldType("PRIMARY")			
		self.HoldType = "PRIMARY"
	end
	if self.WeaponMode == 1 then
		if self.NextStartRecovery and CurTime()>self.NextStartRecovery then
			self.NextStartRecovery = nil
			self.NextEndRecovery = CurTime() + self.AccuracyRecoveryDelay
		end
		
		if self.NextEndRecovery then
			local diff = self.NextEndRecovery - CurTime()
			local r = math.Clamp(diff/self.AccuracyRecoveryDelay, 0, 1)
			self.CrosshairScale = 1
			self.BulletSpread = Lerp(r, self.MinSpread, self.MaxSpread)
			
			if diff<=0 then
				self.CritsOnHeadshot = true
				self.NextEndRecovery = nil
			end
		end
	end
	return self:CallBaseFunction("Think")
end  

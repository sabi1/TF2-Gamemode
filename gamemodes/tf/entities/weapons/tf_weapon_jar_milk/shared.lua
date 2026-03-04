if SERVER then
	AddCSLuaFile( "shared.lua" )
	
end

if CLIENT then

SWEP.PrintName			= "Mad Milk"
SWEP.HasCModel = true
SWEP.Slot				= 1

SWEP.RenderGroup 		= RENDERGROUP_BOTH

local function FindAttachmentID(host, names)
	if not IsValid(host) then return nil end
	for _, name in ipairs(names or {}) do
		if isstring(name) and name ~= "" then
			local id = host:LookupAttachment(name)
			if id and id > 0 then
				return id
			end
		end
	end
end

local function ResolveMilkSplashTarget(self)
	local primary = self:GetViewModelEntity()
	local hosts = {}

	if IsValid(primary) then
		table.insert(hosts, primary)
	end

	if IsValid(self.Owner) then
		local vm = self.Owner:GetViewModel()
		if IsValid(vm) and vm ~= primary then
			table.insert(hosts, vm)
		end
		if IsValid(self.CModel) and self.CModel ~= primary and self.CModel ~= vm then
			table.insert(hosts, self.CModel)
		end
	end

	local preferredNames
	if isfunction(self.IsBreadMonsterMilk) and self:IsBreadMonsterMilk() then
		-- Mutated milk model can miss drink_spray, so prefer right-hand style attachments.
		preferredNames = {
			"drink_spray",
			"weapon_bone",
			"vm_weapon_bone",
			"effect_hand_R",
			"hand_R",
			"muzzle",
			"mouth",
			"effect_hand_L",
			"hand_L",
		}
	else
		preferredNames = {
			"drink_spray",
			"weapon_bone",
			"vm_weapon_bone",
			"muzzle",
			"effect_hand_R",
			"hand_R",
			"effect_hand_L",
			"hand_L",
		}
	end

	for _, host in ipairs(hosts) do
		local id = FindAttachmentID(host, preferredNames)
		if id then
			return host, id
		end
	end

	for _, host in ipairs(hosts) do
		local atts = host:GetAttachments()
		if istable(atts) and atts[1] and atts[1].id and atts[1].id > 0 then
			return host, atts[1].id
		end
	end

	if IsValid(primary) then
		return primary, 0
	end

	return nil, nil
end

function SWEP:ResetParticles(state_override)
	self:CallBaseFunction("ResetParticles", state_override)
	
	if not self.DoneDeployParticle then
		if self.Owner==LocalPlayer() and not LocalPlayer():ShouldDrawLocalPlayer() then
			local host, attachmentID = ResolveMilkSplashTarget(self)
			if IsValid(host) then
				if attachmentID and attachmentID > 0 then
					ParticleEffectAttach("energydrink_milk_splash", PATTACH_POINT_FOLLOW, host, attachmentID)
				else
					ParticleEffectAttach("energydrink_milk_splash", PATTACH_ABSORIGIN_FOLLOW, host, 0)
				end
			end
		end
		
		self.DoneDeployParticle = true
	end
end

end

PrecacheParticleSystem("energydrink_milk_splash")

SWEP.Base				= "tf_weapon_melee_base"

SWEP.ViewModel			= "models/weapons/c_models/c_scout_arms.mdl"
SWEP.WorldModel			= "models/weapons/c_models/c_madmilk/c_madmilk.mdl"
SWEP.Crosshair = "tf_crosshair3"

SWEP.MuzzleEffect = ""

SWEP.ShootSound = ""
SWEP.ShootCritSound = ""

SWEP.Primary.ClipSize		= -1
SWEP.Primary.Ammo			= TF_GRENADES1
SWEP.Primary.Delay          = 0.8

SWEP.ReloadSingle = false

SWEP.HasCustomMeleeBehaviour = true

SWEP.HoldType = "ITEM1"
SWEP.GlobalCustomHUD = {HudItemEffectMeter = function(self) return self:Ammo1() < (self.MaxCarry or 1) end}

SWEP.ProjectileShootOffset = Vector(0, 0, 0)

SWEP.Properties = {}
SWEP.Force = 800
SWEP.AddPitch = -4
SWEP.MaxCarry = 1

SWEP.VM_DRAW = ACT_ITEM1_VM_DRAW
SWEP.VM_IDLE = ACT_ITEM1_VM_IDLE
SWEP.VM_PRIMARYATTACK = ACT_ITEM1_VM_PRIMARYATTACK

local BREADMONSTER_MILK_MODEL = "models/weapons/c_models/c_breadmonster/c_breadmonster_milk.mdl"

function SWEP:IsBreadMonsterMilk()
	local item = self:GetItemData()
	return item and item.model_player == BREADMONSTER_MILK_MODEL
end

function SWEP:InspectAnimCheck()
	self:CallBaseFunction("InspectAnimCheck")

	if self:IsBreadMonsterMilk() then
		self:SetHoldType("MELEE_ALLCLASS")
		self.HoldType = "MELEE_ALLCLASS"
		self.VM_DRAW = _G["ACT_BREADMONSTER_VM_DRAW"] or ACT_ITEM1_VM_DRAW
		self.VM_IDLE = _G["ACT_BREADMONSTER_VM_IDLE"] or ACT_ITEM1_VM_IDLE
		self.VM_PRIMARYATTACK = _G["ACT_BREADMONSTER_VM_PRIMARYATTACK"] or ACT_ITEM1_VM_PRIMARYATTACK
		self.VM_HITCENTER = self.VM_PRIMARYATTACK
		self.VM_SWINGHARD = self.VM_PRIMARYATTACK
		self.ShootSound = Sound("Weapon_bm_throwable.throw")
		self.ShootCritSound = Sound("Weapon_bm_throwable.throw")
		if (IsValid(self.Owner)) then
			self.Owner:SetPoseParameter("r_hand_grip",13.0)
			self.Owner:SetPoseParameter("r_arm",0.0)
		end
	else
		self:SetHoldType("ITEM1")
		self.HoldType = "ITEM1"
	end
	self.VM_HITCENTER = self.VM_PRIMARYATTACK
	self.VM_SWINGHARD = self.VM_PRIMARYATTACK
end

function SWEP:PredictCriticalHit()
end

function SWEP:Think()
	self:CallBaseFunction("Think")
	if SERVER then
		self:ProcessRechargeTimer()
		self:ClampAmmo()
	elseif CLIENT then
		self:UpdateRechargeBar()
	end
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
	self:InspectAnimCheck()
	local r = self:CallBaseFunction("Deploy")

	-- Some item animation IDs can resolve late/invalid on re-equip; guarantee a short deploy window.
	if not self.NextDeployed then
		self.NextDeployed = CurTime() + 0.1
	end
	self.IsDeployed = nil

	if SERVER then
		self:ClampAmmo()
	elseif CLIENT then
		self:UpdateRechargeBar()
	end
	return r
end

function SWEP:ProcessRechargeTimer()
	if not IsValid(self.Owner) then return end
	if not self.Owner.NextGiveAmmo or self.Owner.NextGiveAmmoType ~= self.Primary.Ammo then return end
	if CurTime() < self.Owner.NextGiveAmmo then return end
	
	local maxcarry = self.MaxCarry or 1
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
	
	self.Owner.NextGiveAmmo = nil
	self.Owner.NextGiveAmmoType = nil
end

function SWEP:UpdateRechargeBar()
	-- Kept for compatibility with legacy callers; meter now uses HudItemEffectMeter.
	return
end

function SWEP:GetHUDMeterName()
	return "#TF_MadMilk"
end

function SWEP:GetHUDMeterResFile()
	return "resource/ui/huditemeffectmeter_scout.res"
end

function SWEP:GetHUDMeterValue()
	if not IsValid(self.Owner) then return 0 end

	local maxcarry = self.MaxCarry or 1
	if self:Ammo1() >= maxcarry then
		return 1
	end

	if self.Owner.NextGiveAmmo and self.Owner.NextGiveAmmoType == self.Primary.Ammo then
		local recharge = self.Properties.ReloadTime or 20
		if recharge <= 0 then return 0 end
		local elapsed = recharge - math.max(0, self.Owner.NextGiveAmmo - CurTime())
		return math.Clamp(elapsed / recharge, 0, 1)
	end

	return 0
end

function SWEP:MeleeAttack()
	local pos = self.Owner:GetShootPos()
	local wmodel = self:GetItemData().model_player or self.WorldModel
	if SERVER then
		local grenade = ents.Create("tf_projectile_jar")
		grenade:SetPos(pos)
		grenade:SetAngles(self.Owner:EyeAngles())
		
		local is_crit = (self:RollCritical() == true)
		grenade.critical = is_crit
		
		for k,v in pairs(self.Properties) do
			grenade[k] = v
		end
		
		grenade:SetOwner(self.Owner)
		grenade.JarType = 2
		self:InitProjectileAttributes(grenade)
		
		grenade:Spawn()
		grenade:EmitSound(self.ShootSound)
		grenade:SetModel(wmodel)
		if self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster/c_breadmonster_milk.mdl" then
			grenade.ExplosionSound = "Weapon_bm_throwable.smash"
		end
		
		local vel = self.Owner:GetAimVector():Angle()
		vel.p = vel.p + self.AddPitch
		vel = vel:Forward() * self.Force * (grenade.Mass or 10)
		
		grenade:GetPhysicsObject():AddAngleVelocity(Vector(math.random(-2000,2000),math.random(-2000,2000),math.random(-2000,2000)))
		grenade:GetPhysicsObject():ApplyForceCenter(vel)
		if self:IsBreadMonsterMilk() then
			grenade:SetModel("models/weapons/c_models/c_breadmonster/c_breadmonster_milk.mdl")
			self:SetHoldType("MELEE_ALLCLASS")
			self.Owner:DoAnimationEvent(ACT_DOD_PRIMARYATTACK_BOLT,true)
			self.ShootSound = Sound("Weapon_bm_throwable.throw")
			self.ShootCritSound = Sound("Weapon_bm_throwable.throw")
			self.Owner:EmitSoundEx(self.ShootSound)
		end
	end
end

function SWEP:PrimaryAttack()
	if not self.IsDeployed then return end

	if SERVER then
		self:ClampAmmo()
	end
	if (self:Ammo1() < 1) then return end
	
	if SERVER then
		self.Owner:Speak("TLK_JARATE_LAUNCH")
	end
	
	self:SetNextPrimaryFire(CurTime() + 0.8)
	self:SendWeaponAnim(self.VM_PRIMARYATTACK)
	if not self:IsBreadMonsterMilk() then
		self.Owner:SetAnimation(PLAYER_ATTACK1)
	else
		self.Owner:DoAnimationEvent(ACT_MP_THROW)
	end
	
	self:TakePrimaryAmmo(1)
	
	self.Owner.NextGiveAmmo = CurTime() + (self.Properties.ReloadTime or 20)
	self.Owner.NextGiveAmmoType = self.Primary.Ammo
	
	self.NextIdle = CurTime() + 0.8
	
	--self.NextMeleeAttack = CurTime() + 0.25
	if not self.NextMeleeAttack then
		self.NextMeleeAttack = {}
	end
	
	table.insert(self.NextMeleeAttack, CurTime() + 0.25)
	timer.Simple(0.8, function()
		if not IsValid(self) then return end
		if not IsValid(self.Owner) then return end
		if not IsValid(self.Owner:GetActiveWeapon()) then return end
		if self.Owner:GetActiveWeapon() ~= self then return end
		if not IsValid(self.Owner:GetViewModel()) then return end

		self:SendWeaponAnim(self.VM_DRAW)
		self.Owner:GetViewModel():SetPlaybackRate(1.3)
		self.NextIdle = CurTime() + self:SequenceDuration() * 0.7
	end)
end

function SWEP:Holster()
	if CLIENT then
		self.DoneDeployParticle = false
	end
	
	return self:CallBaseFunction("Holster")
end

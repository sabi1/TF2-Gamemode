if SERVER then
	AddCSLuaFile()
end

if CLIENT then
	SWEP.PrintName = "Thermal Thruster"
	SWEP.HasCModel = true
	SWEP.Slot = 1
end

SWEP.Base = "tf_weapon_base"

SWEP.ViewModel = "models/weapons/c_models/c_pyro_arms.mdl"
SWEP.WorldModel = "models/weapons/c_models/c_rocketpack/c_rocketpack.mdl"
SWEP.Crosshair = "tf_crosshair3"

SWEP.MuzzleEffect = ""
SWEP.ShootSound = ""
SWEP.ShootCritSound = ""

SWEP.Primary.ClipSize = 2
SWEP.Primary.DefaultClip = 2
SWEP.Primary.Ammo = TF_PRIMARY
SWEP.Primary.Delay = 1.2

SWEP.Secondary.Delay = 1.2

SWEP.ReloadSingle = true
SWEP.ReloadTime = 20
SWEP.ReloadSound = ""

SWEP.HasCustomMeleeBehaviour = true
SWEP.ProjectileShootOffset = Vector(0, 0, 0)
SWEP.HoldType = "ITEM4"

SWEP.GlobalCustomHUD = { HudItemEffectMeter = true }

local ROCKETPACK_LAUNCH_DELAY = 0.65
local ROCKETPACK_REFIRE_DELAY = 1.2
local ROCKETPACK_TOGGLE_DURATION = 1.0
local ROCKETPACK_LAUNCH_PUSH = 250
local ROCKETPACK_IMPACT_PUSH_MIN = 100
local ROCKETPACK_IMPACT_PUSH_MAX = 300
local ROCKETPACK_CHARGE_COST = 50
local ROCKETPACK_METER_MAX = 100
local ROCKETPACK_CHARGE_RATE = 30
local ROCKETPACK_AIRBORNE_PRESERVE_VELOCITY = false
local ROCKETPACK_GROUND_PRESERVE_VELOCITY = false
local ROCKETPACK_PASSENGER_DELAY_LAUNCH = 0.2
local ROCKETPACK_CHARGE_NWKEY = "TFRocketPackCharge"
local ROCKETPACK_ENABLED_NWKEY = "TFRocketPackEnabled"

local ROCKETPACK_LAUNCH_EFFECT = "rocketpack_exhaust_launch"
local ROCKETPACK_TRAIL_EFFECT = "rocketpack_exhaust"

local function canSeeEntity(owner, target)
	if not IsValid(owner) or not IsValid(target) then return false end

	local tr = util.TraceLine({
		start = owner:WorldSpaceCenter(),
		endpos = target:WorldSpaceCenter(),
		filter = { owner, target },
		mask = MASK_SHOT
	})

	return not tr.Hit
end

local function remapClamped(value, inMin, inMax, outMin, outMax)
	if inMax == inMin then return outMax end
	local frac = math.Clamp((value - inMin) / (inMax - inMin), 0, 1)
	return outMin + (outMax - outMin) * frac
end

function SWEP:InspectAnimCheck()
	self:CallBaseFunction("InspectAnimCheck")
	self.VM_DRAW = ACT_ITEM4_VM_DRAW
	self.VM_IDLE = ACT_ITEM4_VM_IDLE
	self.VM_PRIMARYATTACK = ACT_ITEM4_VM_PRIMARYATTACK
	self.VM_RELOAD_START = ACT_ITEM4_VM_HOLSTER
	self.VM_RELOAD_LOOP = ACT_ITEM4_VM_HOLSTER
	self.VM_RELOAD_END = ACT_ITEM4_VM_DRAW
	self.VM_INSPECT_START = ACT_ITEM4_VM_IDLE
	self.VM_INSPECT_IDLE = ACT_ITEM4_VM_IDLE
	self.VM_INSPECT_END = ACT_ITEM4_VM_IDLE
end

function SWEP:Initialize()
	self:CallBaseFunction("Initialize")
	self:ResetRocketPackState()
	self:SetRocketPackCharge((self:Clip1() > 0 and self:Clip1() * ROCKETPACK_CHARGE_COST) or ROCKETPACK_METER_MAX)
	self.LastTrackedAmmo = self:GetRocketPackCharge()
	if SERVER then
		self:SyncRocketPackAmmoFromCharge()
	end
end

function SWEP:ResetRocketPackState()
	self.RefireTime = 0
	self.InitLaunchTime = 0
	self.LaunchTime = 0
	self.ToggleEndTime = -1
	self.Enabled = false
	self.LaunchedFromGround = false
	self.IsFlying = false
	self.LastAirborneSpeed = 0
	self.LastFallSpeed = 0
	self.LastTrackedAmmo = ROCKETPACK_METER_MAX
	self.RocketPackCharge = ROCKETPACK_METER_MAX
	self.RocketPackChargeStart = ROCKETPACK_METER_MAX
	self.RocketPackChargeEnd = ROCKETPACK_METER_MAX
	self.RocketPackRechargeStart = 0
	self.RocketPackRechargeEnd = 0
	self.PassengerLaunchTime = 0
	self.LastLaunchForce = vector_origin
	self._RocketPackNextSecondaryFire = 0

	if IsValid(self.Owner) then
		self.LastTrackedAmmo = ROCKETPACK_METER_MAX
		if SERVER then
			self:SetNWFloat(ROCKETPACK_CHARGE_NWKEY, ROCKETPACK_METER_MAX)
			self:SetNWBool(ROCKETPACK_ENABLED_NWKEY, false)
		end
		if self.Owner.NextGiveAmmoType == self.Primary.Ammo then
			self.Owner.NextGiveAmmo = nil
			self.Owner.NextGiveAmmoType = nil
		end
		self:StopBoosterLoop()
		if self.Owner.InCond and self.Owner:InCond(TF_COND_PARACHUTE_ACTIVE) then
			self.Owner:RemoveCond(TF_COND_PARACHUTE_ACTIVE, true)
		end
		if self.Owner.InCond and self.Owner:InCond(TF_COND_ROCKETPACK) then
			self.Owner:RemoveCond(TF_COND_ROCKETPACK, true)
		end
	end
end

function SWEP:OnRemove()
	self:StopBoosterLoop()
	if CLIENT then
		self:CleanupRocketPackParticles()
	end
end

function SWEP:PredictCriticalHit()
end

function SWEP:CreateSounds(owner)
	if not IsValid(owner) then return end
	if self.BoosterLoop then return end

	self.BoosterLoop = CreateSound(owner, "Weapon_RocketPack.BoostersLoop")
end

function SWEP:StopBoosterLoop()
	if self.BoosterLoop then
		self.BoosterLoop:Stop()
	end
end

if CLIENT then
	function SWEP:GetRocketPackParticleModel()
		local owner = self.Owner
		if not IsValid(owner) then return nil end

		if owner == LocalPlayer() and self.DrawingViewModel then
			return self.ExtraCModel or self.CModel or owner:GetViewModel()
		end

		return self.ExtraWModel or self.WModel2 or self
	end

	function SWEP:ResetRocketPackWearableSequence(sequenceName)
		local model = self:GetRocketPackParticleModel()
		if not IsValid(model) or not model.LookupSequence or not model.ResetSequence then return end

		local sequence = model:LookupSequence(sequenceName)
		if sequence and sequence >= 0 then
			model:ResetSequence(sequence)
			if model.SetCycle then
				model:SetCycle(0)
			end
		end
	end

	function SWEP:CleanupRocketPackParticles()
		local model = self:GetRocketPackParticleModel()
		if IsValid(model) and model.StopParticles then
			model:StopParticles()
		end
		if self.StopParticles then
			self:StopParticles()
		end
	end

	function SWEP:AttachRocketPackEffect(effectName)
		local model = self:GetRocketPackParticleModel()
		if not IsValid(model) then return end

		for _, attachmentName in ipairs({"charge_LA", "charge_RA"}) do
			local attachment = model.LookupAttachment and model:LookupAttachment(attachmentName) or 0
			if attachment and attachment > 0 then
				ParticleEffectAttach(effectName, PATTACH_POINT_FOLLOW, model, attachment)
			end
		end
	end

	function SWEP:AttachRocketPackTrailParticles()
		self:AttachRocketPackEffect(ROCKETPACK_TRAIL_EFFECT)
	end

	function SWEP:AttachRocketPackBlastParticles()
		self:AttachRocketPackEffect(ROCKETPACK_LAUNCH_EFFECT)
	end

	function SWEP:UpdateRocketPackVisuals()
		local enabled = self:IsRocketPackEnabled()
		local initLaunchTime = self.InitLaunchTime or 0
		local launchTime = self.LaunchTime or 0

		if self._RocketPackOldInitLaunchTime ~= initLaunchTime then
			self:CleanupRocketPackParticles()
			if initLaunchTime > 0 then
				self:AttachRocketPackTrailParticles()
			elseif launchTime <= 0 and not self.IsFlying then
				self:CleanupRocketPackParticles()
			end
		end

		if self._RocketPackWasEnabled ~= enabled then
			self:ResetRocketPackWearableSequence(enabled and "deploy" or "undeploy")
		end

		self._RocketPackOldInitLaunchTime = initLaunchTime
		self._RocketPackWasEnabled = enabled
	end
end

function SWEP:StartTransition()
	self.ToggleEndTime = CurTime() + ROCKETPACK_TOGGLE_DURATION
end

function SWEP:ResetTransition()
	self.ToggleEndTime = -1
end

function SWEP:IsInTransition()
	return (self.ToggleEndTime or -1) >= 0
end

function SWEP:IsTransitionCompleted()
	return CurTime() >= (self.ToggleEndTime or -1)
end

function SWEP:IsRocketPackReady()
	return self:GetRocketPackCharge() >= ROCKETPACK_CHARGE_COST
end

function SWEP:GetRocketPackReloadDuration()
	local rate = tonumber(self.GetAttributeValue and self:GetAttributeValue("item_meter_charge_rate", ROCKETPACK_CHARGE_RATE) or ROCKETPACK_CHARGE_RATE) or ROCKETPACK_CHARGE_RATE
	local mult = tonumber(self.GetAttributeValue and self:GetAttributeValue("mult_item_meter_charge_rate", 1) or 1) or 1
	if mult <= 0 then mult = 1 end

	return rate / mult
end

function SWEP:GetRocketPackCharge()
	if SERVER then
		return math.Clamp(self.RocketPackCharge or ROCKETPACK_METER_MAX, 0, ROCKETPACK_METER_MAX)
	end

	local owner = self.Owner
	if IsValid(owner) and owner == LocalPlayer() then
		return math.Clamp(self.RocketPackCharge or ROCKETPACK_METER_MAX, 0, ROCKETPACK_METER_MAX)
	end

	return math.Clamp(self:GetNWFloat(ROCKETPACK_CHARGE_NWKEY, self.RocketPackCharge or ROCKETPACK_METER_MAX), 0, ROCKETPACK_METER_MAX)
end

function SWEP:SetRocketPackCharge(value)
	value = math.Clamp(tonumber(value) or 0, 0, ROCKETPACK_METER_MAX)
	self.RocketPackCharge = value

	if SERVER then
		self:SetNWFloat(ROCKETPACK_CHARGE_NWKEY, value)
	end
end

function SWEP:SyncRocketPackAmmoFromCharge()
	if not SERVER then return end

	local charges = math.floor((self:GetRocketPackCharge() + 0.001) / ROCKETPACK_CHARGE_COST)
	charges = math.Clamp(charges, 0, self.Primary.ClipSize or 2)
	if self:Clip1() ~= charges then
		self:SetClip1(charges)
	end
end

function SWEP:StartRocketPackRecharge()
	if self:GetRocketPackCharge() >= ROCKETPACK_METER_MAX then
		self.RocketPackRechargeStart = 0
		self.RocketPackRechargeEnd = 0
		self.RocketPackChargeStart = self:GetRocketPackCharge()
		self.RocketPackChargeEnd = self:GetRocketPackCharge()
		return
	end

	local now = CurTime()
	self.RocketPackChargeStart = self:GetRocketPackCharge()
	self.RocketPackChargeEnd = ROCKETPACK_METER_MAX
	self.RocketPackRechargeStart = now
	self.RocketPackRechargeEnd = now + self:GetRocketPackReloadDuration() * ((ROCKETPACK_METER_MAX - self.RocketPackChargeStart) / ROCKETPACK_METER_MAX)
end

function SWEP:UpdateRocketPackCharge()
	if self.RocketPackRechargeEnd and self.RocketPackRechargeEnd > 0 then
		local now = CurTime()
		local duration = math.max((self.RocketPackRechargeEnd or 0) - (self.RocketPackRechargeStart or 0), 0)
		local frac = duration <= 0 and 1 or math.Clamp((now - self.RocketPackRechargeStart) / duration, 0, 1)
		local value = Lerp(frac, self.RocketPackChargeStart or 0, self.RocketPackChargeEnd or ROCKETPACK_METER_MAX)
		self:SetRocketPackCharge(value)

		if frac >= 1 then
			self.RocketPackRechargeStart = 0
			self.RocketPackRechargeEnd = 0
			self.RocketPackChargeStart = ROCKETPACK_METER_MAX
			self.RocketPackChargeEnd = ROCKETPACK_METER_MAX
		end
	end

	if SERVER then
		self:SyncRocketPackAmmoFromCharge()
	end
end

function SWEP:IsRocketPackEnabled()
	if SERVER then
		return self.Enabled == true
	end

	local owner = self.Owner
	if IsValid(owner) and owner == LocalPlayer() then
		return self.Enabled == true
	end

	return self:GetNWBool(ROCKETPACK_ENABLED_NWKEY, self.Enabled == true)
end

function SWEP:SetRocketPackEnabled(enabled)
	self.Enabled = enabled == true
	if SERVER then
		self:SetNWBool(ROCKETPACK_ENABLED_NWKEY, self.Enabled)
	end
end

function SWEP:SetRocketPackNextSecondaryFire(time)
	self._RocketPackNextSecondaryFire = time or 0
	self:SetNextSecondaryFire(time or 0)
end

function SWEP:GetRocketPackNextSecondaryFire()
	return self._RocketPackNextSecondaryFire or 0
end

function SWEP:CanFire()
	local owner = self.Owner
	if not IsValid(owner) then return false end
	if not self:IsRocketPackEnabled() then return false end
	if owner.IsLoser and owner:IsLoser() then return false end
	if owner.InCond and owner:InCond(TF_COND_TAUNTING) then return false end
	if self:IsInTransition() and not self:IsTransitionCompleted() then return false end
	if (self.RefireTime or 0) > CurTime() then return false end
	if not self:IsRocketPackReady() then return false end
	if self:GetRocketPackNextSecondaryFire() > CurTime() then return false end

	if owner.InCond and owner:InCond(TF_COND_ROCKETPACK) then
		local airLaunch = tonumber(self.GetAttributeValue and self:GetAttributeValue("thermal_thruster_air_launch", 0) or 0) or 0
		if airLaunch <= 0 then
			return false
		end
	end

	return true
end

function SWEP:PrimaryAttack()
	return false
end

function SWEP:SecondaryAttack()
	return false
end

function SWEP:InitiateLaunch()
	local owner = self.Owner
	if not IsValid(owner) then return false end

	if self.InitLaunchTime and self.InitLaunchTime > 0 then
		self:SetNextPrimaryFire(CurTime() + 0.1)
		self:SetRocketPackNextSecondaryFire(CurTime() + 0.1)
		return false
	end

	if not self:CanFire() then
		if not self:IsRocketPackReady() then
			self:EmitSound("Weapon_RocketPack.BoostersNotReady", 85)
		end
		return false
	end

	self:EmitSound("Weapon_RocketPack.BoostersCharge", 85)
	self.InitLaunchTime = CurTime()
	return true
end

function SWEP:CalcRocketForceFromPlayer(owner)
	local bOnGround = self.LaunchedFromGround and math.abs(owner:EyeAngles().x) <= 15
	local angAim = owner:EyeAngles()
	local vecForward = angAim:Forward()
	local force = 450
	local pushScale = 1.8
	local vertPushScale = bOnGround and 0.7 or 0.25
	local buttons = owner:GetButtons()
	local noDirection = bit.band(buttons, IN_FORWARD) == 0 and bit.band(buttons, IN_BACK) == 0

	local vecDir = vecForward
	if noDirection or bit.band(buttons, IN_FORWARD) ~= 0 then
		vecDir = vecForward
	elseif bit.band(buttons, IN_BACK) ~= 0 then
		vecDir = -vecForward
	end

	if bOnGround and vecDir.z < 0 then
		vecDir.z = 0
	end

	vecDir:Normalize()

	local vecForce = vecDir * force * pushScale
	vecForce.z = vecForce.z + (force * vertPushScale)
	return vecForce
end

function SWEP:RocketLaunchPlayer(player, vecForce)
	if not IsValid(player) then return end

	if not (player.InCond and player:InCond(TF_COND_ROCKETPACK)) then
		player._tfNoForcedStunThirdpersonUntil = CurTime() + 0.5
		if player.SetNWFloat then
			player:SetNWFloat("TFNoForcedStunThirdpersonUntil", CurTime() + 0.5)
		end
		player:AddCond(TF_COND_ROCKETPACK, PERMANENT_CONDITION or 30, player)
		player:AddCond(TF_COND_STUNNED, 0.5, player)
	end

	local curVel = player:GetVelocity()
	local shouldPreserve = player:OnGround() and ROCKETPACK_GROUND_PRESERVE_VELOCITY or ((not player:OnGround()) and ROCKETPACK_AIRBORNE_PRESERVE_VELOCITY)
	if not shouldPreserve then
		player:SetVelocity(-curVel)
	end
	player:SetVelocity(vecForce)
end

local function isQuickFixMedigun(weapon)
	if not IsValid(weapon) then return false end

	local className = string.lower(tostring(weapon:GetClass() or ""))
	if className == "tf_weapon_medigun_qf" then
		return true
	end

	if weapon.GetItemData then
		local itemData = weapon:GetItemData()
		local itemClass = string.lower(tostring(itemData and itemData.item_class or ""))
		local itemName = string.lower(tostring(itemData and itemData.name or ""))
		if itemClass == "tf_weapon_medigun_qf" or itemName == "quick-fix" then
			return true
		end
	end

	return false
end

function SWEP:QueuePassengerLaunch(vecForce)
	if not SERVER then return end

	self.PassengerLaunchTime = CurTime() + ROCKETPACK_PASSENGER_DELAY_LAUNCH
	self.LastLaunchForce = vecForce or vector_origin
end

function SWEP:PassengerDelayLaunchThink()
	if not SERVER then return end

	local owner = self.Owner
	if not IsValid(owner) then return end

	for _, medic in ipairs(player.GetAll()) do
		if medic ~= owner and medic:IsTFPlayer() and medic:Alive() and medic:Team() == owner:Team() then
			local medigun = medic:GetActiveWeapon()
			if IsValid(medigun) and isQuickFixMedigun(medigun) and medigun.Target == owner then
				self:RocketLaunchPlayer(medic, self.LastLaunchForce or vector_origin)
			end
		end
	end

	self.PassengerLaunchTime = 0
end

function SWEP:PreLaunch()
	local owner = self.Owner
	if not IsValid(owner) then return false end

	owner:DoAnimationEvent(ACT_DOD_PRONE_ZOOMED, true)
	self:SendWeaponAnimEx(ACT_ITEM4_VM_PRIMARYATTACK)

	local vel = owner:GetVelocity()
	if vel.z < 0 then
		owner:SetVelocity(Vector(0, 0, -vel.z))
	end

	owner:SetVelocity(Vector(0, 0, 350))
	owner:AddCond(TF_COND_PARACHUTE_ACTIVE, 1, owner)

	ParticleEffect("heavy_ring_of_fire", owner:GetPos(), Angle(0, 0, 0))

	local footL = owner:LookupAttachment("foot_L")
	if footL and footL > 0 then
		ParticleEffectAttach("rocketjump_smoke", PATTACH_POINT_FOLLOW, owner, footL)
	end

	local footR = owner:LookupAttachment("foot_R")
	if footR and footR > 0 then
		ParticleEffectAttach("rocketjump_smoke", PATTACH_POINT_FOLLOW, owner, footR)
	end

	self.LaunchTime = CurTime() + ROCKETPACK_LAUNCH_DELAY
	return true
end

function SWEP:PushNearbyEnemies(radius, pushAmount)
	local owner = self.Owner
	if not IsValid(owner) then return end

	for _, ent in ipairs(ents.FindInSphere(owner:GetPos(), radius)) do
		if ent ~= owner and ent:IsTFPlayer() and ent:Alive() and not ent:IsFriendly(owner) then
			local dir = ent:WorldSpaceCenter() - owner:WorldSpaceCenter()
			dir.z = math.max(dir.z, 32)
			dir:Normalize()
			ent:SetVelocity(dir * pushAmount)

			if SERVER and gameeventmanager and gameeventmanager.CreateEvent then
				local event = gameeventmanager:CreateEvent("player_rocketpack_pushed")
				if event then
					event:SetInt("pusher", owner:UserID())
					event:SetInt("pushed", ent:UserID())
					gameeventmanager:FireEvent(event)
				end
			end
		end
	end
end

function SWEP:ExtinguishNearbyTeammates(radius)
	local owner = self.Owner
	if not IsValid(owner) then return end

	for _, ent in ipairs(ents.FindInSphere(owner:GetPos(), radius)) do
		if ent ~= owner and ent:IsTFPlayer() and ent:Alive() and ent:IsFriendly(owner) then
			if ent.InCond and ent:InCond(TF_COND_BURNING) and canSeeEntity(owner, ent) then
				ent:RemoveCond(TF_COND_BURNING, true)
				ent:EmitSoundEx("TFPlayer.FlameOut")
			end
		end
	end
end

function SWEP:BeginRechargeTimer()
	self:StartRocketPackRecharge()
end

function SWEP:Launch()
	local owner = self.Owner
	if not IsValid(owner) then return false end

	self.LaunchTime = 0
	owner:RemoveCond(TF_COND_PARACHUTE_ACTIVE, true)

	local vecForce = self:CalcRocketForceFromPlayer(owner)
	self:RocketLaunchPlayer(owner, vecForce)
	self:QueuePassengerLaunch(vecForce)

	self.RefireTime = CurTime() + 0.5
	self.IsFlying = true
	self.LastAirborneSpeed = owner:GetVelocity():Length()
	self.LastFallSpeed = 0

	self:SetRocketPackCharge(self:GetRocketPackCharge() - ROCKETPACK_CHARGE_COST)
	self:SyncRocketPackAmmoFromCharge()
	self:BeginRechargeTimer()
	self:PushNearbyEnemies(150, ROCKETPACK_LAUNCH_PUSH)
	self:ExtinguishNearbyTeammates(150)

	self:EmitSound("Weapon_RocketPack.BoostersFire", 85)
	self:CreateSounds(owner)
	if self.BoosterLoop then
		self.BoosterLoop:PlayEx(1, 100)
	end

	if SERVER and gameeventmanager and gameeventmanager.CreateEvent then
		local event = gameeventmanager:CreateEvent("rocketpack_launch")
		if event then
			event:SetInt("userid", owner:UserID())
			event:SetBool("playsound", true)
			gameeventmanager:FireEvent(event)
		end
	end

	if CLIENT then
		self:CleanupRocketPackParticles()
		self:AttachRocketPackBlastParticles()
	end

	return true
end

function SWEP:HandleImpactLanding()
	local owner = self.Owner
	if not IsValid(owner) then return end

	local impactPushback = tonumber(self.GetAttributeValue and self:GetAttributeValue("falling_impact_radius_pushback", 0) or 0) or 0
	if impactPushback <= 0 then return end

	local speed = math.max(self.LastFallSpeed or 0, 0)
	if speed < 100 then return end

	local pushAmount = remapClamped(speed, 100, 1000, ROCKETPACK_IMPACT_PUSH_MIN, ROCKETPACK_IMPACT_PUSH_MAX)
	local pushRadius = remapClamped(speed, 100, 1000, 150, 220)
	local impactStun = tonumber(self.GetAttributeValue and self:GetAttributeValue("falling_impact_radius_stun", 0) or 0) or 0
	local stunTime = 0

	if impactStun > 0 and speed >= 100 then
		stunTime = remapClamped(speed, 100, 1000, 1.5, 3.0)
	end

	for _, ent in ipairs(ents.FindInSphere(owner:GetPos(), pushRadius)) do
		if ent ~= owner and ent:IsTFPlayer() and ent:Alive() and not ent:IsFriendly(owner) then
			local dir = ent:WorldSpaceCenter() - owner:WorldSpaceCenter()
			dir.z = math.max(dir.z, 24)
			dir:Normalize()
			ent:SetVelocity(dir * pushAmount)

			if stunTime > 0 then
				ent:AddCond(TF_COND_STUNNED, stunTime, owner)
			end
		end
	end

	self:ExtinguishNearbyTeammates(pushRadius)
end

function SWEP:Land()
	local owner = self.Owner
	if not IsValid(owner) then return end

	self.IsFlying = false

	self:EmitSound("Weapon_RocketPack.BoostersShutdown", 85)
	owner:EmitSoundEx("Weapon_RocketPack.Land", 85)
	self:StopBoosterLoop()

	if owner.InCond and owner:InCond(TF_COND_ROCKETPACK) then
		owner:RemoveCond(TF_COND_ROCKETPACK, true)
	end

	self:HandleImpactLanding()

	if SERVER and gameeventmanager and gameeventmanager.CreateEvent then
		local event = gameeventmanager:CreateEvent("rocketpack_landed")
		if event then
			event:SetInt("userid", owner:UserID())
			gameeventmanager:FireEvent(event)
		end
	end

	self.LastFallSpeed = 0

	if CLIENT then
		self:CleanupRocketPackParticles()
	end
end

function SWEP:Deploy()
	self:CallBaseFunction("Deploy")
	self:CreateSounds(self.Owner)
	self.Owner:SetPoseParameter("r_arm", 0)
	self.Owner:SetPoseParameter("r_hand_grip", 0)
	self:SetRocketPackEnabled(true)
	self:StartTransition()
	self:EmitSound("Weapon_RocketPack.BoostersExtend", 85)
	return true
end

function SWEP:Holster()
	if self.LaunchTime and self.LaunchTime > 0 then
		return false
	end

	self:SetRocketPackEnabled(false)
	self:StartTransition()
	self:StopBoosterLoop()

	if IsValid(self.Owner) then
		if self.Owner.InCond and self.Owner:InCond(TF_COND_PARACHUTE_ACTIVE) then
			self.Owner:RemoveCond(TF_COND_PARACHUTE_ACTIVE, true)
		end
		if self.Owner.InCond and self.Owner:InCond(TF_COND_ROCKETPACK) then
			self.Owner:RemoveCond(TF_COND_ROCKETPACK, true)
		end
	end

	self:EmitSound("Weapon_RocketPack.BoostersRetract", 85)
	return self.BaseClass.Holster(self)
end

function SWEP:GetHUDMeterName()
	return self:IsRocketPackEnabled() and "#TF_RocketPack_Charges" or "#TF_RocketPack_Disabled"
end

function SWEP:GetHUDMeterResFile()
	return "resource/ui/hudrocketpack.res"
end

function SWEP:GetHUDMeterValue()
	return math.Clamp(self:GetRocketPackCharge() / ROCKETPACK_METER_MAX, 0, 1)
end

function SWEP:GetHUDMeterProgressBars()
	return 2
end

function SWEP:GetHUDMeterBarColor()
	if not self:IsRocketPackReady() then
		return Color(255, 0, 0, 255)
	end

	return Color(255, 255, 255, 255)
end

function SWEP:GetHUDMeterLabelColor()
	if self:IsRocketPackEnabled() then
		return Color(235, 235, 235, 255)
	end

	return Color(178, 178, 178, 255)
end

function SWEP:GetHUDMeterIcon()
	if self:IsRocketPackEnabled() then
		return "../hud/pyro_jetpack"
	end

	return "../hud/pyro_jetpack_off2"
end

function SWEP:HandleRocketPackFrame()
	local owner = self.Owner
	if not IsValid(owner) then return end

	if self:IsInTransition() then
		self.LaunchTime = 0

		if self:IsTransitionCompleted() then
			self:ResetTransition()
			if self:IsRocketPackEnabled() then
				owner:EmitSoundEx("Weapon_RocketPack.BoostersReady", 85)
			end
		elseif owner:KeyPressed(IN_ATTACK2) then
			owner:EmitSoundEx("Player.DenyWeaponSelection", 75)
		end
	end

	if self.InitLaunchTime and self.InitLaunchTime > 0 then
		if not self:IsRocketPackEnabled() or owner:KeyPressed(IN_JUMP) then
			self.InitLaunchTime = 0
			self.LaunchTime = 0
			owner:RemoveCond(TF_COND_PARACHUTE_ACTIVE, true)
			self:SetNextPrimaryFire(CurTime() + ROCKETPACK_LAUNCH_DELAY)
			self:SetRocketPackNextSecondaryFire(CurTime() + ROCKETPACK_LAUNCH_DELAY)
		else
			self.LaunchedFromGround = owner:OnGround()
			self:PreLaunch()
			self.InitLaunchTime = 0
			self:SetNextPrimaryFire(CurTime() + ROCKETPACK_REFIRE_DELAY)
			self:SetRocketPackNextSecondaryFire(CurTime() + ROCKETPACK_REFIRE_DELAY)
		end
	end

	if self.LaunchTime and self.LaunchTime > 0 and self.LaunchTime <= CurTime() then
		self:Launch()
	elseif owner:KeyPressed(IN_ATTACK) or owner:KeyPressed(IN_ATTACK2) then
		self:InitiateLaunch()
	else
		self:WeaponIdle()
	end

	if self.IsFlying then
		local velocity = owner:GetVelocity()
		self.LastAirborneSpeed = math.max(self.LastAirborneSpeed or 0, velocity:Length())
		if velocity.z < 0 then
			self.LastFallSpeed = math.max(self.LastFallSpeed or 0, -velocity.z)
		end

		if owner:OnGround() and CurTime() > (self.RefireTime or 0) then
			self:Land()
		end
	end
end

function SWEP:ItemPostFrame()
	self:HandleRocketPackFrame()
end

function SWEP:Think()
	self:CallBaseFunction("Think")

	local owner = self.Owner
	if not IsValid(owner) then return end

	self:UpdateRocketPackCharge()

	if CLIENT then
		self:UpdateRocketPackVisuals()
	end

	if SERVER and self.PassengerLaunchTime and self.PassengerLaunchTime > 0 and CurTime() >= self.PassengerLaunchTime then
		self:PassengerDelayLaunchThink()
	end

	local charge = self:GetRocketPackCharge()
	local last = self.LastTrackedAmmo or 0
	if charge ~= last then
		self.LastTrackedAmmo = charge
		if CLIENT and owner == LocalPlayer() and last < ROCKETPACK_METER_MAX and charge >= ROCKETPACK_METER_MAX then
			owner:EmitSound("TFPlayer.ReCharged")
		end
	end
end

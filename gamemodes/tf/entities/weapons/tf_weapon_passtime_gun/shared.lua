if SERVER then
	AddCSLuaFile()
end

if CLIENT then
	SWEP.PrintName			= "Jack"
SWEP.Slot				= 5
end

SWEP.Base				= "tf_weapon_gun_base"

SWEP.ViewModel			= "models/weapons/c_models/c_sniper_arms.mdl"
SWEP.WorldModel			= "models/passtime/ball/passtime_ball.mdl"
SWEP.Crosshair = "tf_crosshair3"

SWEP.Swing = Sound("Weapon_Shovel.Miss")
SWEP.SwingCrit = Sound("Weapon_Shovel.MissCrit")
SWEP.HitFlesh = Sound("Weapon_Shovel.HitFlesh")
SWEP.HitWorld = Sound("Weapon_Shovel.HitWorld")

local SpeedTable = {
{40, 1.6},
{80, 1.4},
{120, 1.2},
{160, 1.1},
}

SWEP.MinDamage = 0.5
SWEP.MaxDamage = 1.75

SWEP.BaseDamage = 65
SWEP.DamageRandomize = 0.1
SWEP.MaxDamageRampUp = 0
SWEP.MaxDamageFalloff = 0

SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo			= "none"
SWEP.Primary.Delay = 0.8
SWEP.ReloadTime = 0.8
SWEP.Ball					= 1

SWEP.CanInspect = false

SWEP.VM_DRAW = ACT_BALL_VM_PICKUP
SWEP.VM_IDLE = ACT_BALL_VM_IDLE
SWEP.VM_THROWBALL = ACT_BALL_VM_THROW_START
SWEP.VM_RELOAD = ACT_BALL_VM_CATCH

SWEP.AddPitch = 0
SWEP.ProjectileShootOffset = Vector(0, 7, -6)
SWEP.Force = 1100

SWEP.CriticalChance = 0

SWEP.HoldType = "ITEM1"

local cv_passtime_throw_strength_scale = CreateConVar("tf_passtime_throw_strength_scale", "1.08", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Extra PASSTIME throw strength scale applied on top of TF2 throw speeds.")

local THROWSTATE_IDLE = 0
local THROWSTATE_CHARGING = 1
local THROWSTATE_CHARGED = 2
local THROWSTATE_THROWN = 3

local PASSTIME_THROW_SPEEDS = {
	scout = 700,
	sniper = 900,
	soldier = 800,
	demoman = 850,
	medic = 900,
	heavy = 850,
	pyro = 750,
	spy = 900,
	engineer = 850,
}

local PASSTIME_THROW_ARCS = {
	scout = 0.1,
	sniper = 0.0,
	soldier = 0.1,
	demoman = 0.15,
	medic = 0.0,
	heavy = 0.175,
	pyro = 0.1,
	spy = 0.0,
	engineer = 0.2,
}

local function getPasstimeLogic()
	for _, logic in ipairs(ents.FindByClass("passtime_logic")) do
		if IsValid(logic) and not logic.Disabled then
			return logic
		end
	end
	return nil
end

local function canTargetPassRecipient(owner, target, logic)
	if not (IsValid(owner) and IsValid(target) and owner ~= target) then return false end
	if not (target:IsPlayer() and target:Alive()) then return false end
	if target:Team() ~= owner:Team() then return false end
	if target.InCond and (target:InCond(TF_COND_DISGUISED) or target:InCond(TF_COND_DISGUISING)) then return false end
	if target.InCond and (target:InCond(TF_COND_STEALTHED) or target:InCond(TF_COND_STEALTHED_USER_BUFF)) then return false end
	if target.IsStealthed and target:IsStealthed() then return false end
	if IsValid(logic) and logic.CanPlayerCarryBall and not logic:CanPlayerCarryBall(target) then return false end

	local maxRange = IsValid(logic) and tonumber(logic.MaxPassRange) or 0
	if maxRange and maxRange > 0 and owner:GetPos():DistToSqr(target:GetPos()) > (maxRange * maxRange) then
		return false
	end

	return true
end

local function findBestPassTarget(owner)
	if not IsValid(owner) then return nil end
	local logic = getPasstimeLogic()
	local eyePos = owner:EyePos()
	local eyeForward = owner:EyeAngles():Forward()
	local bestScore = 0.96
	local bestTarget = nil

	for _, ply in ipairs(player.GetAll()) do
		if not canTargetPassRecipient(owner, ply, logic) then
			continue
		end

		local toTarget = (ply:WorldSpaceCenter() - eyePos):GetNormalized()
		local score = eyeForward:Dot(toTarget)
		if score > bestScore then
			bestScore = score
			bestTarget = ply
		end
	end

	return bestTarget
end

local function passtimeChargeEnabled()
	local instapass = GetConVar("tf_passtime_experiment_instapass")
	local charge = GetConVar("tf_passtime_experiment_instapass_charge")
	return instapass and instapass:GetBool() and charge and charge:GetBool()
end

local function passtimeThrowLoopActivity()
	return _G.ACT_BALL_VM_THROW_LOOP or ACT_BALL_VM_IDLE
end

local function passtimePreviewColor(owner)
	if not IsValid(owner) then
		return Color(255, 255, 255, 180), Color(255, 255, 255, 255)
	end
	if owner:EntityTeam() == TEAM_BLU or owner:EntityTeam() == TF_TEAM_PVE_INVADERS then
		return Color(120, 190, 255, 180), Color(120, 190, 255, 255)
	end
	return Color(255, 150, 120, 180), Color(255, 150, 120, 255)
end

local function findWeaponByClass(owner, className)
	if not IsValid(owner) or not isstring(className) or className == "" then
		return nil
	end
	for _, wep in ipairs(owner:GetWeapons()) do
		if IsValid(wep) and wep:GetClass() == className then
			return wep
		end
	end
	return nil
end

local function getStoredWeaponClassForPasstime(owner)
	if not IsValid(owner) then
		return nil
	end

	local active = owner:GetActiveWeapon()
	if not IsValid(active) then
		return nil
	end

	local class = active.GetClass and active:GetClass() or nil
	if class == "tf_weapon_passtime_gun" then
		return nil
	end

	return class
end

local function passtimeConVarFloat(name, fallback)
	local cvar = GetConVar(name)
	if not cvar then
		return fallback
	end
	return cvar:GetFloat()
end

local function getPasstimeThrowParams(owner)
	if not IsValid(owner) then
		return 1000, 0.3
	end

	local className = string.lower(tostring(owner.GetPlayerClass and owner:GetPlayerClass() or ""))
	local speed = passtimeConVarFloat("tf_passtime_throwspeed_" .. className, PASSTIME_THROW_SPEEDS[className] or 1000)
	local arc = passtimeConVarFloat("tf_passtime_throwarc_" .. className, PASSTIME_THROW_ARCS[className] or 0.3)
	return speed, arc
end

local function calcPasstimeLaunch(owner, homing)
	if not IsValid(owner) then
		return vector_origin, vector_origin
	end

	local eyeAngles = owner:EyeAngles()
	local viewForward = eyeAngles:Forward()
	local startPos = owner:EyePos()
	local startVel

	if homing then
		local autopass = GetConVar("tf_passtime_experiment_autopass")
		if autopass and autopass:GetBool() then
			startVel = vector_origin
		else
			startVel = viewForward * passtimeConVarFloat("tf_passtime_mode_homing_speed", 1000)
		end
	else
		local speed, arc = getPasstimeThrowParams(owner)
		startVel = LerpVector(arc, viewForward, Vector(0, 0, 1))
		startVel:Normalize()
		startVel:Mul(speed)
	end

	local velocityScale = passtimeConVarFloat("tf_passtime_throwspeed_velocity_scale", 0.33)
	local ownerVelocity = owner.GetVelocity and owner:GetVelocity() or vector_origin
	startVel:Add(viewForward * (viewForward:Dot(ownerVelocity) * velocityScale))

	local strengthScale = math.max(cv_passtime_throw_strength_scale:GetFloat(), 0)
	if strengthScale > 0 and strengthScale ~= 1 then
		startVel:Mul(strengthScale)
	end

	return startPos, startVel
end

function SWEP:InspectAnimCheck()
	self:CallBaseFunction("InspectAnimCheck")
	self.VM_DRAW = ACT_BALL_VM_PICKUP
	self.VM_IDLE = ACT_BALL_VM_IDLE
	self.VM_HITCENTER = ACT_BALL_VM_THROW_START
	self.VM_SWINGHARD = ACT_BALL_VM_THROW_END
	self.VM_RELOAD = ACT_BALL_VM_CATCH
end

function SWEP:Deploy()
	self:InspectAnimCheck()
	local deployed = self:CallBaseFunction("Deploy")
	if IsValid(self.Owner) then
		self:SetHoldType(self.HoldType)
	end
	self.ThrowState = THROWSTATE_IDLE
	self.ThrowLoopStartTime = nil
	self.ChargeBeginTime = nil
	self.PassTarget = nil
	if SERVER and IsValid(self.Owner) then
		self.Owner:SetNWEntity("TFPasstimePassTarget", NULL)
	end
	return deployed
end

function SWEP:TryRestorePreviousWeapon()
	local owner = self.Owner
	if not IsValid(owner) or not owner:Alive() then
		return false
	end

	local previousWeapon = findWeaponByClass(owner, self.StoredLastWeaponClass)
	if IsValid(previousWeapon) and previousWeapon ~= self then
		owner:SelectWeapon(previousWeapon:GetClass())
		if owner:GetActiveWeapon() == previousWeapon then
			self.StoredLastWeaponClass = nil
			return true
		end
	end

	for _, wep in ipairs(owner:GetWeapons()) do
		if IsValid(wep) and wep ~= self and wep:GetClass() ~= "tf_weapon_passtime_gun" then
			owner:SelectWeapon(wep:GetClass())
			if owner:GetActiveWeapon() == wep then
				self.StoredLastWeaponClass = nil
				return true
			end
		end
	end

	return false
end

function SWEP:RemoveFromOwnerLoadout()
	local owner = self.Owner
	if not IsValid(owner) then
		return
	end

	self.SuppressPasstimeDrop = true

	if owner:GetActiveWeapon() == self then
		self:TryRestorePreviousWeapon()
	end

	timer.Simple(0, function()
		if not IsValid(owner) then
			return
		end
		if owner:HasWeapon("tf_weapon_passtime_gun") then
			owner:StripWeapon("tf_weapon_passtime_gun")
		end
	end)
end

function SWEP:GetChargeMaxTime()
	if passtimeChargeEnabled() then
		return 3.0
	end
	return 0.0
end

function SWEP:GetCurrentCharge()
	if self.ThrowState ~= THROWSTATE_CHARGING and self.ThrowState ~= THROWSTATE_CHARGED then
		return 0
	end
	local maxTime = self:GetChargeMaxTime()
	if maxTime <= 0 or not self.ChargeBeginTime then
		return 0
	end
	return math.Clamp((CurTime() - self.ChargeBeginTime) / maxTime, 0, 1)
end

function SWEP:StartThrowCharge()
	if self.ThrowState and self.ThrowState ~= THROWSTATE_IDLE then
		return false
	end

	self.ThrowState = THROWSTATE_CHARGING
	self.ChargeBeginTime = CurTime()
	self.ThrowLoopStartTime = CurTime() + self:SequenceDuration(self:SelectWeightedSequence(self.VM_HITCENTER))
	self:SendWeaponAnim(self.VM_HITCENTER)
	return true
end

function SWEP:FinishThrow(passTarget)
	if self.Ball == 0 then
		return false
	end

	local throwTarget = IsValid(passTarget) and passTarget or self.PassTarget

	local throwDuration = self:SequenceDuration(self:SelectWeightedSequence(self.VM_SWINGHARD))
	if not throwDuration or throwDuration <= 0 then
		throwDuration = 0
	end

	self.ThrowState = THROWSTATE_THROWN
	self.ThrowLoopStartTime = nil
	self.Owner:DoAttackEvent()
	self.Owner:SetAnimation(PLAYER_ATTACK1)
	self:SendWeaponAnim(self.VM_SWINGHARD)
	self.NextIdle = CurTime() + throwDuration
	self:SetNextPrimaryFire(CurTime() + throwDuration)
	self:SetNextSecondaryFire(self:GetNextPrimaryFire())
	self:ShootProjectile(throwTarget, throwDuration)
	self:StopTimers()
	self.Ball = 0
	self.PassTarget = nil
	if SERVER and IsValid(self.Owner) then
		self.Owner:SetNWEntity("TFPasstimePassTarget", NULL)
	end
	return true
end

function SWEP:Think()
	self:CallBaseFunction("Think")
	
	if self.Owner:GetPlayerClass() == "scout" then
		self.Primary.Delay = 0.5
	else
		self.Primary.Delay = 0.80
	end

	if IsValid(self.Owner) and self.Owner:GetActiveWeapon() == self and self.Ball == 1 then
		local activeClass = getStoredWeaponClassForPasstime(self.Owner)
		if activeClass then
			self.StoredLastWeaponClass = activeClass
		end
	end

	if self.Ball ~= 1 then
		if SERVER and IsValid(self.Owner) and self.Owner:GetActiveWeapon() == self then
			self:TryRestorePreviousWeapon()
		end
		if self.ThrowState == THROWSTATE_THROWN and CurTime() >= self:GetNextPrimaryFire() then
			self.ThrowState = THROWSTATE_IDLE
		end
		return
	end

	if self.ThrowState == THROWSTATE_CHARGING or self.ThrowState == THROWSTATE_CHARGED then
		if not self.Owner:KeyDown(IN_ATTACK) then
			self:FinishThrow()
			return
		end

		if self.ThrowLoopStartTime and CurTime() >= self.ThrowLoopStartTime then
			self:SendWeaponAnim(passtimeThrowLoopActivity())
			self.ThrowLoopStartTime = math.huge
		end

		local maxTime = self:GetChargeMaxTime()
		if self.ThrowState == THROWSTATE_CHARGING and (maxTime <= 0 or self:GetCurrentCharge() >= 1) then
			self.ThrowState = THROWSTATE_CHARGED
		end
	end
end

function SWEP:PrimaryAttack()
	if self.Ball == 0 then
		return
	end

	if self:GetNextPrimaryFire() > CurTime() then
		return false
	end

	return self:StartThrowCharge()
end

function SWEP:SecondaryAttack()
	if self.Ball == 0 then return end
	if self:GetNextSecondaryFire() > CurTime() then return false end
	if not IsValid(self.Owner) then return false end
	if self.ThrowState and self.ThrowState ~= THROWSTATE_IDLE then return false end

	local target = findBestPassTarget(self.Owner)
	if not IsValid(target) then
		self:SetNextSecondaryFire(CurTime() + 0.15)
		return false
	end

	self.PassTarget = target
	if SERVER then
		self.Owner:SetNWEntity("TFPasstimePassTarget", target)
	end
	return self:FinishThrow(target)
end

function SWEP:ShootProjectile(passTarget, delay)
	local target = IsValid(passTarget) and passTarget or nil
	delay = math.max(tonumber(delay) or 0, 0)

	timer.Simple(delay, function()
		if IsValid(self) then 
			if SERVER then
				local owner = self.Owner
				if not IsValid(owner) then
					return
				end
				if TF_PasstimeBallThrown then
					TF_PasstimeBallThrown(owner, nil)
				end
				local grenade = ents.Create("tf_projectile_passtime_ball")
				grenade:SetModel("models/passtime/ball/passtime_ball.mdl")
				local startPos, startVel = calcPasstimeLaunch(owner, IsValid(target))
				grenade:SetPos(startPos)
				grenade:SetAngles(angle_zero)

		
				self:InitProjectileAttributes(grenade)
				grenade:SetOwner(owner)
				grenade.Thrower = owner
				grenade.SpawnTime = CurTime()
				grenade.LeftOwner = false
		
				grenade.NameOverride = self:GetItemData().item_iconname
				grenade:Spawn()
				if IsValid(target) then
					grenade.Homing = true
					grenade.Target = target
					grenade.HomingTargetSpeed = passtimeConVarFloat("tf_passtime_mode_homing_speed", 1000)
					grenade:SetNWEntity("TFPasstimeHomingTarget", target)
				end
				grenade:SetNWEntity("TFPasstimePrevCarrier", owner)

				local phys = grenade:GetPhysicsObject()
				if IsValid(phys) then
					phys:SetVelocity(startVel)
					phys:AddAngleVelocity(Vector(0, 0, 1))
				end
				if TF_PasstimeBallThrown then
					TF_PasstimeBallThrown(owner, grenade)
				end
				self:RemoveFromOwnerLoadout()
			end
		end
	end)
end

function SWEP:OnDrop()
	self.Ball = 1
	if self.SuppressPasstimeDrop then
		return
	end
	if SERVER and TF_PasstimeBallDropped then
		TF_PasstimeBallDropped(self.Owner, self)
	end
	//self:Remove()
	
	//self:SetPos(self:ProjectileShootPos())
	//self:SetAngles(self.Owner:EyeAngles())
	
	//local vel = self.Owner:GetAimVector():Angle()
	//vel.p = vel.p + self.AddPitch
	//vel = vel:Forward() * self.Force * (grenade.Mass or 10)
	
	self:GetPhysicsObject():AddAngleVelocity(Vector(math.random(-2000,2000),math.random(-2000,2000),math.random(-2000,2000)))
		
	self:GetPhysicsObject():ApplyForceCenter(Vector(math.random(-2000,2000)))
	
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_CUSTOM)
	self:SetMoveCollide(MOVECOLLIDE_FLY_SLIDE)
end

function SWEP:Holster()
	-- Mirror TF2: block manual holstering while carrying, but allow restore once the ball is gone.
	return self.Ball ~= 1
end

function SWEP:OnRemove()
	self.PassTarget = nil
end

if CLIENT then
	function SWEP:DrawHUD()
		if not IsValid(self.Owner) or self.Owner ~= LocalPlayer() then return end
		if self.Owner:GetActiveWeapon() ~= self then return end
		if self.Ball ~= 1 then return end
		if self.ThrowState ~= THROWSTATE_CHARGING and self.ThrowState ~= THROWSTATE_CHARGED then return end
		if IsValid(self.PassTarget) then return end

		local currentPos, velocity = calcPasstimeLaunch(self.Owner, false)
		local gravity = Vector(0, 0, -800)
		local hull = Vector(4, 4, 4)
		local step = 1 / 32
		local maxSteps = 96
		local lineColor, impactColor = passtimePreviewColor(self.Owner)

		surface.SetDrawColor(lineColor.r, lineColor.g, lineColor.b, lineColor.a)

		for _ = 1, maxSteps do
			local nextPos = currentPos + velocity * step
			velocity = velocity + gravity * step

			local tr = util.TraceHull({
				start = currentPos,
				endpos = nextPos,
				mins = -hull,
				maxs = hull,
				filter = self.Owner,
				mask = MASK_PLAYERSOLID
			})

			local screenStart = currentPos:ToScreen()
			local screenEnd = tr.HitPos:ToScreen()
			if screenStart.visible and screenEnd.visible then
				surface.DrawLine(screenStart.x, screenStart.y, screenEnd.x, screenEnd.y)
			end

			if tr.Hit then
				local impact = tr.HitPos:ToScreen()
				if impact.visible then
					surface.SetDrawColor(impactColor.r, impactColor.g, impactColor.b, impactColor.a)
					surface.DrawLine(impact.x - 8, impact.y, impact.x + 8, impact.y)
					surface.DrawLine(impact.x, impact.y - 8, impact.x, impact.y + 8)
				end
				break
			end

			currentPos = nextPos
		end
	end
end

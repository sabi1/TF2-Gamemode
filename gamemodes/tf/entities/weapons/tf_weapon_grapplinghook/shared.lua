-- todo: rewrite this
-- this was shamelessly used from another addon with formerly no credit what so ever, i plan to rewrite this using leaked tf2 code and no longer base it off of kurome's weapon



-- credit to https://steamcommunity.com/sharedfiles/filedetails/?id=1696595790

if CLIENT then
	SWEP.PrintName			= "Grappling Hook"
end

SWEP.Slot				= 6
SWEP.Base				= "tf_weapon_melee_base"
SWEP.Crosshair = "tf_crosshair3"
 
SWEP.Category			= "Team Fortress 2"
SWEP.PrintName			= "Grappling Hook"
SWEP.ViewModel = "models/weapons/c_models/c_scout_arms.mdl"
SWEP.WorldModel = "models/weapons/c_models/c_grappling_hook/c_grappling_hook.mdl"

SWEP.Spawnable			= true
SWEP.AdminSpawnable		= false
SWEP.AdminOnly          = true
SWEP.jumped 			= false

SWEP.HoldType = "MELEE_ALLCLASS"
SWEP.HoldTypeHL2 = "slam"
local sndGrappleHitPlayer		= Sound("weapons/grappling_hook_impact_flesh.wav")
local sndGrappleHit		= Sound("weapons/grappling_hook_impact_default.wav")
local sndGrappleShoot	= Sound("weapons/grappling_hook_shoot.wav")
local sndGrappleReel	= Sound("weapons/grappling_hook_reel_start.wav")
local sndGrappleAbort	= Sound("weapons/grappling_hook_reel_stop.wav")
local sndGrappleShootScript = "WeaponGrapplingHook.Shoot"
local sndGrappleReelStartScript = "WeaponGrapplingHook.ReelStart"
local sndGrappleReelStopScript = "WeaponGrapplingHook.ReelStop"
local sndGrappleImpactDefaultScript = "WeaponGrapplingHook.ImpactDefault"
local sndGrappleImpactFleshScript = "WeaponGrapplingHook.ImpactFlesh"
local sndGrappleImpactFleshLoopScript = "WeaponGrapplingHook.ImpactFleshLoop"
local nextSupernovaDenyWarning = {}

local cv_grapple_projectile_speed = CreateConVar("tf_grapplinghook_projectile_speed", "1500", {FCVAR_REPLICATED, FCVAR_NOTIFY}, "How fast the grappling hook projectile travels.")
local cv_grapple_max_distance = CreateConVar("tf_grapplinghook_max_distance", "2000", {FCVAR_REPLICATED, FCVAR_NOTIFY}, "Maximum valid grappling hook latch distance.")
local cv_grapple_fire_delay = CreateConVar("tf_grapplinghook_fire_delay", "0.5", {FCVAR_REPLICATED, FCVAR_NOTIFY}, "Delay between grappling hook shots.")
local cv_grapple_jump_up_speed = CreateConVar("tf_grapplinghook_jump_up_speed", "450", {FCVAR_REPLICATED, FCVAR_NOTIFY}, "Extra upward speed added when detaching with jump.")

local PLAYER_HOOK_BLEED_INTERVAL = 1
local PLAYER_HOOK_BLEED_DAMAGE = 2
local PLAYER_HOOK_LOS_TIMEOUT = 1
local WORLD_HOOK_STANDOFF = 48
local WORLD_HOOK_SOFTEN_DISTANCE = 256
local WORLD_HOOK_RELEASE_DISTANCE = 72

local function grapplingHookTimerReady(wep)
	return IsValid(wep) and IsValid(wep.Owner) and wep.Owner:IsPlayer()
end

local function playerHasPoweredFlagPenalty(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return false end
	if not ply.HasTheFlag or not ply:HasTheFlag() then return false end
	return ply.GetCarryingRuneType and ply:GetCarryingRuneType() ~= TF_RUNE_NONE
end

local function getHookTravelSpeed(ply)
	local speed = cv_grapple_projectile_speed:GetFloat()
	if not IsValid(ply) or not ply:IsPlayer() then return speed end

	if ply.GetCarryingRuneType and ply:GetCarryingRuneType() == TF_RUNE_AGILITY then
		local className = ply.GetPlayerClass and ply:GetPlayerClass() or ""
		if className == "soldier" or className == "heavy" then
			return 2600
		end
		return 3000
	end

	return speed
end

local function getPullSpeedMultiplier(ply)
	local mult = 1
	if not IsValid(ply) or not ply:IsPlayer() then return mult end

	local className = ply.GetPlayerClass and ply:GetPlayerClass() or ""
	if className == "heavy" then
		mult = mult * 0.7
	end
	if playerHasPoweredFlagPenalty(ply) then
		mult = mult * 0.6
	end

	return mult
end

local function canUseGrapple(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return false end
	if ply.IsFeignDeathReady and ply:IsFeignDeathReady() then return false end
	return true
end

local function isSelfHookTarget(wep, ent)
	if not IsValid(wep) or not IsValid(ent) then return false end
	local owner = wep.Owner
	if not IsValid(owner) then return false end
	if ent == owner then return true end
	if owner.GetViewModel and ent == owner:GetViewModel() then return true end
	if owner.GetActiveWeapon and ent == owner:GetActiveWeapon() then return true end
	return false
end

local function getSupernovaTeamEffect(owner, suffix)
	local team = IsValid(owner) and owner:EntityTeam() or TEAM_RED
	local color = (team == TEAM_BLU or team == TF_TEAM_PVE_INVADERS) and "blue" or "red"
	return "powerup_supernova_" .. suffix .. "_" .. color
end

local function activateSupernova(owner)
	if not SERVER then return false end
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return false end
	if not owner.InCond or not owner:InCond(TF_COND_RUNE_SUPERNOVA) then return false end
	if not owner.IsRuneCharged or not owner:IsRuneCharged() then return false end
	if owner.IsStealthed and owner:IsStealthed() then return false end

	local origin = owner:WorldSpaceCenter()
	local victims = {}
	local effectRadiusSqr = 1500 * 1500
	local minPushForce = 200
	local maxPushForce = 500
	for _, other in ipairs(ents.FindInSphere(origin, 1500)) do
		if not IsValid(other) or not other:IsPlayer() or other == owner or not other:Alive() then continue end
		if owner.IsFriendly and owner:IsFriendly(other) then continue end
		local toPlayer = other:WorldSpaceCenter() - origin
		local distSqr = toPlayer:LengthSqr()
		if distSqr > effectRadiusSqr then continue end
		if PointInRespawnRoom and PointInRespawnRoom(other, other:WorldSpaceCenter()) then continue end
		if owner.IsLineOfSightClear and not owner:IsLineOfSightClear(other) then continue end
		victims[#victims + 1] = other
	end

	if #victims == 0 then
		local ownerIndex = owner:EntIndex()
		if (nextSupernovaDenyWarning[ownerIndex] or 0) <= CurTime() then
			nextSupernovaDenyWarning[ownerIndex] = CurTime() + 0.5
			owner:EmitSound("Player.UseDeny")
			local denyText = tf_lang and tf_lang.GetRaw and tf_lang.GetRaw("#TF_Powerup_Supernova_Deny", true) or "There are no valid enemy targets!"
			owner:PrintMessage(HUD_PRINTCENTER, denyText)
		end
		return false
	end

	local stunDuration = math.min(2 + math.max(#victims - 1, 0) * 0.5, 4)
	for _, victim in ipairs(victims) do
		ParticleEffect(getSupernovaTeamEffect(owner, "strike"), victim:WorldSpaceCenter(), Angle(0, 0, 0), victim)
		if victim.DropRune then
			victim:DropRune(false, owner:Team())
		end
		if victim.DropFlag then
			victim:DropFlag()
		end
		if victim.AddCond then
			victim:AddCond(TF_COND_STUNNED, stunDuration, owner)
		end
		local push = victim:WorldSpaceCenter() - origin
		local distSqr = push:LengthSqr()
		push.z = 0
		if push:LengthSqr() < 1 then
			push = owner:GetForward()
		end
		push = push:GetNormalized()
		push.z = 1
		local pushForce = math.Remap(math.Clamp(distSqr, 0, effectRadiusSqr), 0, effectRadiusSqr, maxPushForce, minPushForce)
		victim:SetVelocity(push * pushForce)
	end

	ParticleEffect(getSupernovaTeamEffect(owner, "explode"), owner:GetPos(), Angle(0, 0, 0), owner)
	owner:EmitSound("Powerup.PickUpSupernovaActivate")
	owner:SetCarryingRuneType(TF_RUNE_NONE)
	if TF_RepositionMannpowerRune then
		TF_RepositionMannpowerRune(TF_RUNE_SUPERNOVA, TEAM_UNASSIGNED)
	end
	return true
end


local VM_FIRESTART = ACT_GRAPPLE_FIRE_START
local VM_FIREIDLE = ACT_GRAPPLE_FIRE_IDLE
local VM_PULLSTART = ACT_GRAPPLE_PULL_START
local VM_PULLIDLE = ACT_GRAPPLE_PULL_IDLE
local VM_PULLEND = ACT_GRAPPLE_PULL_END 

local function weaponSequenceDuration(wep)
	if not IsValid(wep) or not wep.SequenceDuration then
		return 0
	end

	local duration = tonumber(wep:SequenceDuration())
	if not duration or duration <= 0 then
		return 0
	end

	return duration
end

function SWEP:GetHookTarget()
	if self.Tr and IsValid(self.Tr.Entity) and not isSelfHookTarget(self, self.Tr.Entity) then
		return self.Tr.Entity
	end

	return nil
end

function SWEP:IsLatchedToTargetPlayer()
	local target = self:GetHookTarget()
	return IsValid(target) and target:IsPlayer()
end

function SWEP:RemoveHookProjectile(force)
	if not force and self:IsLatchedToTargetPlayer() then
		return
	end

	if SERVER and IsValid(self.Beam) then
		self.Beam:Remove()
	end

	self.Beam = nil
	inRange = false
	self._tfPlayerHookLostLOSTime = nil
	self.Tr = nil
	endpos = nil
end

function SWEP:OnHookReleased(force)
	local hadLatchedPlayer = self:IsLatchedToTargetPlayer()
	self:StopImpactLoop()
	self:StopReelSound()
	self:RemoveHookProjectile(force)
	self.m_bReleasedAfterLatched = hadLatchedPlayer

	local activity = self.GetActivity and self:GetActivity() or ACT_INVALID
	if activity ~= ACT_GRAPPLE_DRAW and activity ~= ACT_GRAPPLE_IDLE then
		self:SendWeaponAnim(ACT_GRAPPLE_IDLE)
	end

	if force then
		self:SetNextPrimaryFire(CurTime() + cv_grapple_fire_delay:GetFloat())
	end
end

function SWEP:CanAttack()
	if not canUseGrapple(self.Owner) then
		return false
	end

	if IsValid(self.Owner) and self.Owner.InCond and self.Owner:InCond(TF_COND_STUNNED) then
		return false
	end

	if self.BaseClass.CanPrimaryAttack then
		return self.BaseClass.CanPrimaryAttack(self) ~= false
	end

	return true
end

function SWEP:PlayShootSound()
	if SERVER then
		self:EmitSound(sndGrappleShootScript)
	end
end

function SWEP:StartReelSound()
	if self._tfReelSoundActive then return end
	self._tfReelSoundActive = true

	if CLIENT and IsValid(self.Owner) and self.Owner == LocalPlayer() then
		self:EmitSound(sndGrappleReelStartScript)
	end
end

function SWEP:StopReelSound()
	if not self._tfReelSoundActive then return end
	self._tfReelSoundActive = false

	if CLIENT and IsValid(self.Owner) and self.Owner == LocalPlayer() then
		self:StopSound(sndGrappleReelStartScript)
		self:StopSound(sndGrappleReel)
		self:EmitSound(sndGrappleReelStopScript)
	end
end

function SWEP:StopImpactLoop()
	local traceEnt = self.Tr and self.Tr.Entity
	if IsValid(traceEnt) and traceEnt.StopSound then
		traceEnt:StopSound(sndGrappleImpactFleshLoopScript)
		traceEnt:StopSound("GrappledFlesh")
	end
	self._tfStartedFleshLoop = false
end

function SWEP:PerformJumpDetach(targetPos)
	if not SERVER then return end
	if not IsValid(self.Owner) then return end

	local owner = self.Owner
	local pull = (targetPos - owner:GetPos())
	if pull:LengthSqr() <= 1 then
		pull = owner:GetAimVector()
	end

	local forwardBoost = pull:GetNormalized() * 1000
	local currentVel = owner:GetVelocity()
	forwardBoost.z = forwardBoost.z + ((50 / 20) * 1.5)
	forwardBoost.z = forwardBoost.z + cv_grapple_jump_up_speed:GetFloat()

	if currentVel.z < 0 then
		forwardBoost.z = forwardBoost.z - (currentVel.z / 10)
	end

	owner:SetLocalVelocity(forwardBoost)
end

function SWEP:Think()

	if (!self.Owner || self.Owner == NULL) then return end
	
	
	if (self.Owner:IsHL2()) then
		self.Slot				= 5
	end
	nextshottime = CurTime()
	self.zoomed = false
	
	self.VM_DRAW = ACT_GRAPPLE_DRAW

	self.VM_IDLE = ACT_GRAPPLE_IDLE
		if self.Owner:GetPlayerClass() == "engineer" then
			self.HoldType = "SECONDARY"
		elseif (!self.Owner:IsHL2() and self.Owner:GetPlayerClass() != "engineer") then
			self.HoldType = "MELEE_ALLCLASS"
		else
			self.HoldTypeHL2 = "slam"
	end

	if self.Owner:KeyDown(IN_ATTACK) then
		if IsValid(self.Beam) then
			self:UpdateAttack()
		elseif self:GetNextPrimaryFire() <= CurTime() then
			self:StartAttack()
		end

		if self:GetHookTarget() then
			self:SendWeaponAnim(ACT_GRAPPLE_PULL_START)
		elseif IsValid(self.Beam) then
			self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
		else
			self:SendWeaponAnim(ACT_GRAPPLE_IDLE)
		end
	elseif IsValid(self.Beam) or self.Tr ~= nil then
		self:EndAttack(true)
	else
		local activity = self.GetActivity and self:GetActivity() or ACT_INVALID
		if activity == ACT_GRAPPLE_DRAW and (self._tfDrawAnimEnd or 0) <= CurTime() then
			self:SendWeaponAnim(ACT_GRAPPLE_IDLE)
		elseif activity ~= ACT_GRAPPLE_DRAW and activity ~= ACT_GRAPPLE_IDLE then
			self:SendWeaponAnim(ACT_GRAPPLE_IDLE)
		end
	end

end

function SWEP:ItemPostFrame()
	if self.BaseClass.ItemPostFrame then
		return self.BaseClass.ItemPostFrame(self)
	end
end

function SWEP:DoTrace( endpos )
	local filter = { self.Owner, self, self.Weapon }
	if IsValid(self.Beam) then
		filter[#filter + 1] = self.Beam
	end
	if IsValid(self.Owner) and self.Owner.GetViewModel then
		local vm = self.Owner:GetViewModel()
		if IsValid(vm) then
			filter[#filter + 1] = vm
		end
	end
	if IsValid(self.Owner) and self.Owner.GetActiveWeapon then
		local active = self.Owner:GetActiveWeapon()
		if IsValid(active) then
			filter[#filter + 1] = active
		end
	end
	local trace = {}
		trace.start = self.Owner:GetShootPos()
		trace.endpos = trace.start + (self.Owner:GetAimVector() * cv_grapple_max_distance:GetFloat())
		if(endpos) then trace.endpos = (endpos - self.Tr.HitNormal * 7) end
		trace.filter = filter
		
	self.Tr = nil
	self.Tr = util.TraceLine( trace )
end
function SWEP:CalcViewModelView(vm, oldpos, oldang, newpos, newang)
	if not self.VMMinOffset and self:GetItemData() then
		local data = self:GetItemData()
		if data.static_attrs and data.static_attrs.min_viewmodel_offset then
			self.VMMinOffset = Vector(data.static_attrs.min_viewmodel_offset)
		end
	end

	if GetConVar("tf_use_min_viewmodels"):GetBool() then -- TODO: Check for inspecting
		newpos = newpos + (newang:Forward() * 10)
		newpos = newpos + (newang:Right() * 0)
		newpos = newpos + (newang:Up() * -6)
	end

	return newpos, newang
end

function SWEP:Initialize()
	
	timer.Simple(0.2, function()
		if not IsValid(self) then return end

		local slot = tonumber(self.Slot)
		if slot and slot > 5 and IsValid(self.Owner) and self.Owner:IsHL2() then
			self.Slot = 5
		end

	end)

	self:CallBaseFunction("Initialize")
end

function SWEP:StartAttack()
	-- Get begining and end poins of trace.
	if (self:GetNextPrimaryFire() > CurTime()) then return end
	if not canUseGrapple(self.Owner) then return end
	local gunPos = self.Owner:GetShootPos() -- Start of distance trace.
	local disTrace = self.Owner:GetEyeTrace() -- Store all results of a trace in disTrace.
	local hitPos = disTrace.HitPos -- Stores Hit Position of disTrace.
	
	-- Calculate Distance
	-- Thanks to rgovostes for this code.
	local x = (gunPos.x - hitPos.x)^2;
	local y = (gunPos.y - hitPos.y)^2;
	local z = (gunPos.z - hitPos.z)^2;
	local distance = math.sqrt(x + y + z);
	
	-- Only latches if distance is less than distance CVAR, or CVAR negative
	local distanceCvar = cv_grapple_max_distance:GetFloat()
	inRange = false
	if distanceCvar < 0 or distance <= distanceCvar then
		inRange = true
	end 
	
	
	if inRange then
		if not disTrace.Hit or disTrace.HitSky then
			if SERVER then
				self.Owner:EmitSound("Player.DenyWeaponSelection")
			end
			return
		end

		if (SERVER) then
			
			if (!self.Beam) then -- If the beam does not exist, draw the beam.
				-- grapple_beam
				self.Beam = ents.Create( "trace2" )
					self.Beam:SetPos( self.Owner:GetShootPos() )
				self.Beam:Spawn()
				if CLIENT then
					if self.Owner:Team() == TEAM_BLU then
						self.Beam.matBeam = Material( "cable/cable_blue" )
					else
						self.Beam.matBeam = Material( "cable/cable_red" )
					end
				end
			end
			
			self.Beam:SetParent( self.Owner )
			self.Beam:SetOwner( self.Owner )
		
		end
		
		self:DoTrace()
		if isSelfHookTarget(self, self.Tr and self.Tr.Entity) then
			self.Tr = nil
			if SERVER then
				self.Owner:EmitSound("Player.DenyWeaponSelection")
			end
			if IsValid(self.Beam) then
				self.Beam:Remove()
				self.Beam = nil
			end
			return
		end
		self.speed = getHookTravelSpeed(self.Owner)
		self.startTime = CurTime()
		self.endTime = CurTime() + self.speed
		self.grappleData = -1
		self._tfPlayerHookLostLOSTime = nil
		self._tfPlayedImpactSound = false
		self._tfStartedFleshLoop = false
		
		if (SERVER && self.Beam) then
			self.Beam:GetTable():SetEndPos( self.Tr.HitPos )
		end
		
		self:UpdateAttack()
		self:PlayShootSound()
		self.Owner:SetAnimation(PLAYER_ATTACK1)
	end
end

function SWEP:UpdateAttack()

	--self.Owner:LagCompensation( true )
	
	if (self:GetNextPrimaryFire() > CurTime()) then return end
	if not self.Tr then
		self:EndAttack(true)
		return
	end
	if (!endpos) then
		endpos = self.Tr.HitPos
		local latchedTarget = self:GetHookTarget()
		if not IsValid(latchedTarget) and self.Tr.HitNormal then
			endpos = endpos + (self.Tr.HitNormal * WORLD_HOOK_STANDOFF)
		end
	end
	
	if (SERVER && self.Beam) then
		self.Beam:GetTable():SetEndPos( endpos )
	end

	lastpos = endpos
	
	
	if (!self.Beam) then

	-- Get begining and end poins of trace.
	local gunPos = self.Owner:GetShootPos() -- Start of distance trace.
	local disTrace = self.Owner:GetEyeTrace() -- Store all results of a trace in disTrace.
	local hitPos = disTrace.HitPos -- Stores Hit Position of disTrace.
	
	-- Calculate Distance
	-- Thanks to rgovostes for this code.
	local x = (gunPos.x - hitPos.x)^2;
	local y = (gunPos.y - hitPos.y)^2;
	local z = (gunPos.z - hitPos.z)^2;
	local distance = math.sqrt(x + y + z);
	
	-- Only latches if distance is less than distance CVAR, or CVAR negative
	local distanceCvar = cv_grapple_max_distance:GetFloat()
	inRange = false
	if distanceCvar < 0 or distance <= distanceCvar then
		inRange = true
	end 
	  
	end
				
			local movingTarget = self:GetHookTarget()
			if IsValid(movingTarget) then
				endpos = movingTarget:GetPos()
				if SERVER and IsValid(self.Beam) then
					self.Beam:GetTable():SetEndPos(endpos)
				end
			end
			
			local vVel = (endpos - self.Owner:GetPos())
			local Distance = endpos:Distance(self.Owner:GetPos())
			local hookTarget = self:GetHookTarget()
			local isWorldLatch = not IsValid(hookTarget)

			if self.Owner:KeyPressed(IN_JUMP) then
				self:PerformJumpDetach(endpos)
				self:EndAttack(true)
				self.jumped = true
				timer.Simple(cv_grapple_fire_delay:GetFloat() + 0.002, function()
					if not IsValid(self) then return end
					self.jumped = false
				end)
				self:SetNextPrimaryFire(CurTime() + cv_grapple_fire_delay:GetFloat())
				self.grappleData = -1
				self:SendWeaponAnim(ACT_GRAPPLE_IDLE)
				if SERVER then
					self.Owner:EmitSoundEx(sndGrappleImpactDefaultScript)
				end
				endpos = nil
				return
			end
			
			local et = (self.startTime + (Distance/self.speed))
			if(self.grappleData != 0) then
				self.grappleData = (et - CurTime()) / (et - self.startTime)
			end
			if(self.grappleData < 0) then
				local traceEnt = self.Tr and self.Tr.Entity
				if self:GetHookTarget() and not IsValid(traceEnt) then
					self:EndAttack(true)
					endpos = nil
					return
				end
				self:StartReelSound()
				if IsValid(traceEnt) and traceEnt:IsTFPlayer() then
					if not self._tfPlayedImpactSound then
						traceEnt:EmitSound(sndGrappleImpactFleshScript)
						self._tfPlayedImpactSound = true
					end
					if not self._tfStartedFleshLoop then
						traceEnt:EmitSound(sndGrappleImpactFleshLoopScript)
						self._tfStartedFleshLoop = true
					end
					if !traceEnt:IsFriendly(self.Owner) then
						traceEnt:TakeDamage(5, self.Owner, self)
					end
					timer.Create("Bleed"..self.Owner:EntIndex(), PLAYER_HOOK_BLEED_INTERVAL, 0, function()
						local bleedTarget = IsValid(self) and self.Tr and self.Tr.Entity or nil
						if not IsValid(self) or not IsValid(bleedTarget) then self:StopImpactLoop() timer.Stop("Bleed"..self.Owner:EntIndex()) return end
						if bleedTarget:Health() <= 1 then self:StopImpactLoop() timer.Stop("Bleed"..self.Owner:EntIndex()) return end
						if !self.Owner:Alive() then self:StopImpactLoop() timer.Stop("Bleed"..self.Owner:EntIndex()) return end
						if !self.Owner:KeyDown( IN_ATTACK ) || (self.jumped) then self:StopImpactLoop() timer.Stop("Bleed"..self.Owner:EntIndex()) return end
						local losTrace = util.TraceLine({
							start = self.Owner:WorldSpaceCenter(),
							endpos = bleedTarget:WorldSpaceCenter(),
							filter = { self.Owner, bleedTarget, self },
							mask = MASK_SOLID
						})
						if losTrace.Hit then
							self._tfPlayerHookLostLOSTime = self._tfPlayerHookLostLOSTime or CurTime()
							if CurTime() - self._tfPlayerHookLostLOSTime >= PLAYER_HOOK_LOS_TIMEOUT then
								self:StopImpactLoop()
								timer.Stop("Bleed"..self.Owner:EntIndex())
								if IsValid(self) then
									self:EndAttack(true)
								end
								return
							end
						else
							self._tfPlayerHookLostLOSTime = nil
						end
						if !bleedTarget:IsFriendly(self.Owner) then
							bleedTarget:TakeDamage(PLAYER_HOOK_BLEED_DAMAGE, self.Owner, self)
						end
					end)
				else
					if not self._tfPlayedImpactSound and IsValid(self.Beam) then
						self.Beam:EmitSound(sndGrappleImpactDefaultScript)
						self._tfPlayedImpactSound = true
					end
				end
				if (self.jumped) then return end
				timer.Create("AirWalkAnim"..self.Owner:EntIndex(), self.Owner:SequenceDuration(self.Owner:LookupSequence("a_grapple_pull_idle")), 0, function()
					local traceEnt = self.Tr and self.Tr.Entity
					if !self.Owner:KeyDown( IN_ATTACK ) or (self.jumped) then
						if IsValid(traceEnt) then
							traceEnt:StopSound("GrappledFlesh")
						end
						timer.Stop("AirWalkAnim"..self.Owner:EntIndex())
						return
					end
					if !IsValid(self) then
						if IsValid(traceEnt) then
							traceEnt:StopSound("GrappledFlesh")
						end
						timer.Stop("AirWalkAnim"..self.Owner:EntIndex())
						return
					end
					if not self.Tr or (self:GetHookTarget() and not IsValid(traceEnt)) then
						timer.Stop("AirWalkAnim"..self.Owner:EntIndex())
						return
					end
				end)
				if (self.jumped) then
					self.grappleData = 1
					return
				else
					self.grappleData = 0
					 
				end
			end
			
			if(self.grappleData == 0 and !self.jumped) then
				if isWorldLatch and Distance <= WORLD_HOOK_RELEASE_DISTANCE then
					self:EndAttack(false)
					endpos = nil
					return
				end

				zVel = self.Owner:GetVelocity().z
				vVel = vVel:GetNormalized()*1000
				if( SERVER ) then
				local gravity = GetConVarNumber("sv_Gravity")
				vVel:Add(Vector(0,0,(50/20)*1.65)) -- Player speed. DO NOT MESS WITH THIS VALUE!
				if(zVel < 0) then
					vVel:Sub(Vector(0,0,zVel/10))
				end

				local pullScale = getPullSpeedMultiplier(self.Owner)
				if isWorldLatch and Distance < WORLD_HOOK_SOFTEN_DISTANCE then
					local closeFrac = math.Clamp(Distance / WORLD_HOOK_SOFTEN_DISTANCE, 0, 1)
					pullScale = pullScale * math.Remap(closeFrac, 0, 1, 0.35, 1)
				end

				self.Owner:SetLocalVelocity(vVel * self.Owner:GetWalkSpeed() * 0.003 * pullScale)
				end
			end
	
	endpos = nil
	
	--self.Owner:LagCompensation( false )
	
end

function SWEP:EndAttack( shutdownsound )
	
	self.jumped = false
	self:OnHookReleased(shutdownsound)
end

function SWEP:Holster()
	self:OnHookReleased(false)
	self.jumped = false
	self.grappleData = 1
	self.m_bReleasedAfterLatched = self:IsLatchedToTargetPlayer()
	if SERVER then
		--self.WModel2:Remove()
	end
	self.BaseClass.Holster(self)
	return true
end
function SWEP:Deploy()
	self.BaseClass.Deploy(self)
	self:RemoveHookProjectile(true)
	self.jumped = false
	self.grappleData = 1
	self.m_bReleasedAfterLatched = self:IsLatchedToTargetPlayer()
	self:SendWeaponAnim(ACT_VM_DRAW)
	timer.Simple(0.03,function()
		if not IsValid(self) then return end
		self.IsDeployed = true 
	end)
	self:SetNextPrimaryFire(CurTime() + 0.01)
	return true
end

function SWEP:OnRemove()
	self:RemoveHookProjectile(true)
	self.jumped = false
	self.BaseClass.OnRemove(self)
	return true
end


function SWEP:PrimaryAttack()
	if self.m_bReleasedAfterLatched then
		self:RemoveHookProjectile(true)
		self.m_bReleasedAfterLatched = false
	end

	if IsValid(self.Beam) then
		return
	end

	if self:GetNextPrimaryFire() > CurTime() then
		return
	end

	if not self:CanAttack() then
		return
	end

	return self:StartAttack()
end

function SWEP:SendWeaponAnim(actBase)
	local owner = self.Owner
	if not IsValid(owner) then
		return self.BaseClass.SendWeaponAnim(self, actBase)
	end

	if actBase == ACT_VM_DRAW then
		actBase = ACT_GRAPPLE_DRAW
		local result = self.BaseClass.SendWeaponAnim(self, actBase)
		self._tfDrawAnimEnd = CurTime() + weaponSequenceDuration(self)
		return result
	else
		local hookTarget = self:GetHookTarget()
		local activity = self.GetActivity and self:GetActivity() or ACT_INVALID

		if hookTarget then
			if activity ~= ACT_GRAPPLE_PULL_START and activity ~= ACT_GRAPPLE_PULL_IDLE then
				local result = self.BaseClass.SendWeaponAnim(self, ACT_GRAPPLE_PULL_START)
				self._tfStartPullingAnimEnd = CurTime() + weaponSequenceDuration(self)
				return result
			end

			if activity == ACT_GRAPPLE_PULL_IDLE then
				return true
			end

			if activity == ACT_GRAPPLE_PULL_START and (self._tfStartPullingAnimEnd or 0) > CurTime() then
				return true
			end

			actBase = ACT_GRAPPLE_PULL_IDLE
			self._tfStartPullingAnimEnd = nil
		elseif actBase == ACT_VM_PRIMARYATTACK then
			if activity ~= ACT_GRAPPLE_FIRE_START and activity ~= ACT_GRAPPLE_FIRE_IDLE then
				local result = self.BaseClass.SendWeaponAnim(self, ACT_GRAPPLE_FIRE_START)
				self._tfStartFiringAnimEnd = CurTime() + weaponSequenceDuration(self)
				return result
			end

			if activity == ACT_GRAPPLE_FIRE_IDLE then
				return true
			end

			if activity == ACT_GRAPPLE_FIRE_START and (self._tfStartFiringAnimEnd or 0) > CurTime() then
				return true
			end

			actBase = ACT_GRAPPLE_FIRE_IDLE
			self._tfStartFiringAnimEnd = nil
		else
			if activity == ACT_GRAPPLE_PULL_IDLE then
				actBase = ACT_GRAPPLE_PULL_END
			elseif activity == ACT_GRAPPLE_IDLE then
				return true
			else
				actBase = ACT_GRAPPLE_IDLE
			end
		end
	end

	return self.BaseClass.SendWeaponAnim(self, actBase)
end

function SWEP:SecondaryAttack()
	if activateSupernova(self.Owner) then
		self:SetNextPrimaryFire(CurTime() + 0.5)
		self:SetNextSecondaryFire(CurTime() + 0.5)
		return
	end
end

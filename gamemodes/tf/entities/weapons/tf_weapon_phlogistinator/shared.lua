if SERVER then
AddCSLuaFile()

function SWEP:SetFlamethrowerEffect(i)
	if self.LastEffect==i then return end
	
	umsg.Start("SetFlamethrowerEffect")
		umsg.Entity(self)
		umsg.Char(i)
	umsg.End()
	
	self.LastEffect = i
end

end

if CLIENT then

SWEP.PrintName			= "Phlogistinator"
SWEP.Slot				= 0

function SWEP:SetFlamethrowerEffect(i)
	if self.LastEffect==i then return end
	if not IsValid(self.Owner) then return end
	
	local effect
	local t = GAMEMODE:EntityTeam(self.Owner)
	
	if i==1 then
		effect = "drg_phlo_stream"
	elseif i>1 then
		if t==2 then
			effect = "drg_phlo_stream_crit"
		else
			effect = "drg_phlo_stream_crit"
		end
	end
	
	if self.Owner==LocalPlayer() and IsValid(self.Owner:GetViewModel()) and self.DrawingViewModel then
		local vm = self.Owner:GetViewModel()
		if IsValid(self.CModel) then
			vm = self.CModel
		end
		
		vm:StopParticles()
		if effect then
			ParticleEffectAttach(effect, PATTACH_POINT_FOLLOW, vm, vm:LookupAttachment("muzzle"))
		end
	else
		self:StopParticles()
		if effect then
			ParticleEffectAttach(effect, PATTACH_POINT_FOLLOW, self, self:LookupAttachment("muzzle"))
		end
	end
	
	self.LastEffect = i
end

usermessage.Hook("SetFlamethrowerEffect", function(msg)
	local w = msg:ReadEntity()
	local i = msg:ReadChar()
	if IsValid(w) and w.SetFlamethrowerEffect then
		w:SetFlamethrowerEffect(i)
	end
end)

usermessage.Hook("TFAirblastImpact", function(msg)
	LocalPlayer():EmitSound("TFPlayer.AirBlastImpact")
end)

end

PrecacheParticleSystem("drg_phlo_stream")
PrecacheParticleSystem("drg_phlo_stream_crit")
PrecacheParticleSystem("new_flame_crit_blue")
PrecacheParticleSystem("medicgun_invulnstatus_fullcharge_red")
PrecacheParticleSystem("medicgun_invulnstatus_fullcharge_blue")
PrecacheParticleSystem("pyro_blast")
PrecacheParticleSystem("pyro_blast_flash")
PrecacheParticleSystem("pyro_blast_lines")
PrecacheParticleSystem("pyro_blast_warp")
PrecacheParticleSystem("pyro_blast_warp2")

SWEP.Base				= "tf_weapon_gun_base"

SWEP.ViewModel			= "models/weapons/c_models/c_pyro_arms.mdl"
SWEP.WorldModel			= "models/weapons/c_models/c_drg_phlogistinator/c_drg_phlogistinator.mdl"
SWEP.Crosshair = "tf_crosshair3"

SWEP.MuzzleEffect = "pyro_blast"

SWEP.ShootSound = Sound("Weapon_Phlog.Start")	
SWEP.SpecialSound1 = Sound("Weapon_Phlog.Fire")
SWEP.ShootCritSound = Sound("Weapon_Phlog.FireCrit")
SWEP.ShootSoundEnd = Sound("Weapon_phlogistinator.WindDown")
SWEP.FireHit = Sound("Weapon_FlameThrower.FireHit")
SWEP.PilotLoop = Sound("Weapon_FlameThrower.PilotLoop")

SWEP.AirblastSound = Sound("Weapon_FlameThrower.AirBurstAttack")
SWEP.AirblastDeflectSound = Sound("Weapon_FlameThrower.AirBurstAttackDeflect")

SWEP.Primary.ClipSize		= -1
SWEP.Primary.Ammo			= TF_PRIMARY
SWEP.Primary.Delay          = 0.04

SWEP.Secondary.Automatic	= true
SWEP.Secondary.Delay		= 0.8
SWEP.AirblastRadius = 80

SWEP.BulletSpread = 0.06
SWEP.CriticalChance = 0
SWEP.NoAirblast = true
SWEP.GlobalCustomHUD = {HudItemEffectMeter = true}

SWEP.MmmphMax = 300
SWEP.MmmphBuffTime = 10
SWEP.MmmphTauntTime = 2.8
SWEP.MmmphRobotScale = 0.25
SWEP.MmmphTankScale = 0.1

SWEP.IsRapidFire = true
SWEP.ReloadSingle = false

SWEP.HoldType = "PRIMARY"

SWEP.ProjectileShootOffset = Vector(3, 8, -5)

function SWEP:CreateSounds(owner)
	if not IsValid(owner) then return end
	
	self.SpinUpSound = CreateSound(owner, self.ShootSound)
	self.SpinDownSound = CreateSound(owner, self.ShootSoundEnd)
	self.FireSound = CreateSound(owner, self.SpecialSound1)
	self.FireCritSound = CreateSound(owner, self.ShootCritSound)
	self.PilotSound = CreateSound(owner, self.PilotLoop)
	
	self.SoundsCreated = true
end

function SWEP:EnsurePrimaryAmmoCap()
	if not SERVER or not IsValid(self.Owner) then return end
	if not self.Owner.AmmoMax then return end
	
	local class_tbl = self.Owner:GetPlayerClassTable()
	local class_primary = class_tbl and class_tbl.AmmoMax and class_tbl.AmmoMax[TF_PRIMARY] or 200
	class_primary = math.max(1, tonumber(class_primary) or 200)
	
	if (self.Owner.AmmoMax[TF_PRIMARY] or 0) < class_primary then
		self.Owner.AmmoMax[TF_PRIMARY] = class_primary
	end
	if self.Owner:GetAmmoCount(TF_PRIMARY) < class_primary then
		self.Owner:SetAmmoCount(class_primary, TF_PRIMARY)
	end
end

function SWEP:GetMmmph()
	if IsValid(self.Owner) then
		return self.Owner:GetNWFloat("PhlogMmmph", 0)
	end
	return self:GetNWFloat("PhlogMmmph", 0)
end

function SWEP:SetMmmph(v)
	local clamped = math.Clamp(v or 0, 0, self.MmmphMax)
	if IsValid(self.Owner) then
		self.Owner:SetNWFloat("PhlogMmmph", clamped)
	end
	self:SetNWFloat("PhlogMmmph", clamped)
end

function SWEP:GetMmmphFraction()
	return math.Clamp(self:GetMmmph() / self.MmmphMax, 0, 1)
end

function SWEP:IsMmmphFull()
	return self:GetMmmph() >= self.MmmphMax
end

function SWEP:UpdateMmmphHUD()
	-- Legacy compatibility no-op; MMMPH meter now uses HudItemEffectMeter.
end

function SWEP:GetHUDMeterName()
	return "#TF_PyroRage"
end

function SWEP:GetHUDMeterResFile()
	return "resource/ui/huditemeffectmeter_pyro.res"
end

function SWEP:GetHUDMeterValue()
	return self:GetMmmphFraction()
end

function SWEP:StopMmmphReadyEffect()
	if SERVER and IsValid(self.MmmphReadyParticle) then
		self.MmmphReadyParticle:Remove()
	end
	self.MmmphReadyParticle = nil
end

function SWEP:UpdateMmmphReadyEffect()
	if not SERVER then return end
	if not IsValid(self.Owner) then
		self:StopMmmphReadyEffect()
		return
	end
	
	local is_ready = self:IsMmmphFull()
	if is_ready then
		if IsValid(self.MmmphReadyParticle) then return end
		
		local effect = "medicgun_invulnstatus_fullcharge_red"
		if self.Owner:EntityTeam() == TEAM_BLU or self.Owner:EntityTeam() == TF_TEAM_PVE_INVADERS then
			effect = "medicgun_invulnstatus_fullcharge_blue"
		end
		
		local p = ents.Create("info_particle_system")
		if not IsValid(p) then return end
		p:SetPos(self:GetPos())
		p:SetParent(self)
		p:SetKeyValue("effect_name", effect)
		p:SetKeyValue("start_active", "1")
		p:Spawn()
		p:Activate()
		
		local att = self:LookupAttachment("muzzle")
		if att and att > 0 then
			p:SetParent(self, att)
		end
		
		self.MmmphReadyParticle = p
	else
		self:StopMmmphReadyEffect()
	end
end

function SWEP:PrimaryAttack()
	if not self.IsDeployed then return false end
	
	if self:Ammo1()<=0 then
		return
	end
	
	local Delay = self.Delay or -1
	if Delay>=0 and CurTime()<Delay then return end
	self.Delay = CurTime() + self.Primary.Delay
	
	if not self.Firing then
		self.Firing = true
		self:SetFlamethrowerEffect(1)
		--self.Owner:SetAnimation(PLAYER_PREFIRE)
		self.SpinDownSound:Stop()
		self.SpinUpSound:Play()
		if self.Primary.Delay == 0.015 then
			self.SpinUpSound:ChangePitch(120)
		end
		self.NextEndSpinUp = CurTime() + 3
	end
	
	if self.NextEndSpinUp and CurTime()>self.NextEndSpinUp then
		self.SpinUpSound:Stop()
		self.FireSound:Play()
		if self.Primary.Delay == 0.015 then
			self.FireSound:ChangePitch(120)
		end
		self.NextEndSpinUp = nil
	end
	
	if self:RollCritical() then
		if not self.Critting or not self.Firing then
			self.NextEndSpinUp = nil
			self:SetFlamethrowerEffect(2)
			self.FireSound:Stop()
			self.FireCritSound:Play()
			if self.Primary.Delay == 0.015 then
				self.FireCritSound:ChangePitch(120)
			end
			self.Firing = true
		end
		self.Critting = true
	elseif not self.NextEndSpinUp then
		if self.Critting or not self.Firing then
			self:SetFlamethrowerEffect(1)
			self.FireCritSound:Stop()
			self.FireSound:Play()
			if self.Primary.Delay == 0.015 then
				self.FireSound:ChangePitch(120)
			end
			self.Firing = true
		end
		self.Critting = false
	end
	
	self:SendWeaponAnim(self.VM_PRIMARYATTACK)
	self.Owner:SetAnimation(PLAYER_ATTACK1)
	
	-- Take one ammo every 2 projectiles fired
	if not self.ParticleCounter then self.ParticleCounter = 1 end
	self.ParticleCounter = self.ParticleCounter + 1
	if self.ParticleCounter>2 then
		self.ParticleCounter = 1
		self:TakePrimaryAmmo(1)
	end
	
	self:ShootProjectile()
end

function SWEP:ShootProjectile()
	if SERVER then
		local flame = ents.Create("tf_flame")
		local ang = self.Owner:EyeAngles()
		local vec = ang:Forward() + math.Rand(-self.BulletSpread,self.BulletSpread) * ang:Right() + math.Rand(-self.BulletSpread,self.BulletSpread) * ang:Up()
		
		flame:SetPos(self:ProjectileShootPos())
		flame:SetAngles(vec:Angle())
		if self:Critical() then
			flame.critical = true
		end
		if self.Force then
			flame.Force = self.Force
		end
		flame:SetOwner(self.Owner)
		self:InitProjectileAttributes(flame)
		
		local d = self:GetItemData()
		if d.item_iconname then
			flame.NameOverride = d.item_iconname
		end
		
		flame:Spawn()
		
		flame:SetVelocity(self.Owner:GetVelocity())	
	end
end

function SWEP:Reload()
end

function SWEP:CanActivateMmmph()
	if not IsValid(self.Owner) then return false end
	if not self:IsMmmphFull() then return false end
	if self.Owner:GetNWBool("Taunting") then return false end
	if not self.Owner:IsOnGround() then return false end
	if self.Owner:WaterLevel() > 0 then return false end
	if self.NextMmmphActivate and CurTime() < self.NextMmmphActivate then return false end
	return true
end

function SWEP:BeginMmmph()
	if not SERVER then return end
	if not self:CanActivateMmmph() then return false end
	
	self:StopFiring()
	self:SetMmmph(0)
	self.NextMmmphActivate = CurTime() + self.Secondary.Delay
	self:SetNextPrimaryFire(CurTime() + self.Secondary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)
	
	self.Owner:SetNWBool("Taunting", true)
	self.Owner:SetNWBool("NoWeapon", true)
	self.Owner:SetNWBool("Bonked", true)
	self.Owner:Freeze(true)
	self.Owner:DoTauntEvent("taunt02", true)
	
	net.Start("ActivateTauntCam")
	net.Send(self.Owner)
	
	timer.Simple(self.MmmphTauntTime, function()
		if not IsValid(self) or not IsValid(self.Owner) then return end
		
		self.Owner:Freeze(false)
		self.Owner:SetNWBool("Taunting", false)
		self.Owner:SetNWBool("NoWeapon", false)
		self.Owner:SetNWBool("Bonked", false)
		
		net.Start("DeActivateTauntCam")
		net.Send(self.Owner)
		
		local buff_time = math.max(0, (self.MmmphBuffTime or 10) - (self.MmmphTauntTime or 0))
		if buff_time > 0 then
			GAMEMODE:StartCritBoost(self.Owner, "primary")
			timer.Create("PhlogCritEnd" .. self.Owner:EntIndex(), buff_time, 1, function()
				if IsValid(self.Owner) then
					GAMEMODE:StopCritBoost(self.Owner)
				end
			end)
		end
	end)
	
	return true
end

function SWEP:SecondaryAttack()
	if not self.IsDeployed then return false end
	self:BeginMmmph()
end

function SWEP:TryActivateViaTaunt()
	return self:BeginMmmph()
end

function SWEP:AddMmmphDamage(dmg, victim)
	if not SERVER then return end
	if not IsValid(self.Owner) then return end
	if self.Owner:GetActiveWeapon() ~= self then return end
	if not IsValid(victim) or not victim:IsTFPlayer() or victim:IsBuilding() then return end
	if victim == self.Owner or victim:IsFriendly(self.Owner) then return end
	
	local scale = 1
	if string.find(string.lower(victim:GetClass()), "tank", 1, true) then
		scale = self.MmmphTankScale or 0.1
	elseif string.find(string.lower(victim:GetModel() or ""), "/bot_", 1, true) or victim.TFBot then
		scale = self.MmmphRobotScale or 0.25
	end
	
	self:SetMmmph(self:GetMmmph() + math.max(0, dmg) * scale)
end

function SWEP:StopFiring()
	self.Firing = false
	self.Critting = false
	self:SetFlamethrowerEffect(0)
	self.SpinUpSound:Stop()
	self.SpinDownSound:Play()
	if self.Primary.Delay == 0.06 then
		self.SpinDownSound:ChangePitch(120)
	end
	self.FireSound:Stop()
	self.FireCritSound:Stop()
	self.Owner:SetAnimation(ACT_MP_ATTACK_STAND_POSTFIRE)
	self.NextIdle = CurTime() + 0.04
end

function SWEP:Think()
	if SERVER and self.NextReplayDeployAnim then
		if CurTime() > self.NextReplayDeployAnim then
			--MsgFN("Replaying deploy animation %d", self.VM_DRAW)
			timer.Simple(0.1, function() self:SendWeaponAnim(self.VM_DRAW) end)
			self.NextReplayDeployAnim = nil
		end
	end
	
	if not self.IsDeployed and self.NextDeployed and CurTime()>=self.NextDeployed then
		self.IsDeployed = true
	end
	
	if not self.SoundsCreated then
		self:CreateSounds(self.Owner)
	end
	
	if self.NextIdle and CurTime()>=self.NextIdle then
		self:SendWeaponAnim(self.VM_IDLE)
		self.NextIdle = nil
	end
	
	if self.Firing and (not self.Owner:KeyDown(IN_ATTACK) or self:Ammo1()<=0) then
		self:StopFiring()
	end

	if CLIENT then
		self:UpdateMmmphHUD()
	end
	if SERVER then
		self:UpdateMmmphReadyEffect()
	end
	
	self:Inspect()
end

function SWEP:Deploy()
	if SERVER and IsValid(self.Owner) then
		local deaths = self.Owner:Deaths()
		local last = self.Owner:GetNWInt("PhlogLastDeathSeen", -1)
		if deaths ~= last then
			self:SetMmmph(0)
			self.Owner:SetNWInt("PhlogLastDeathSeen", deaths)
		end
		self:EnsurePrimaryAmmoCap()
	end
	
	if not self.SoundsCreated then
		self:CreateSounds(self.Owner)
	end
	
	if self.SoundsCreated then
		self.PilotSound:Play()
	end
	if CLIENT then
		self:UpdateMmmphHUD()
	end
	
	----MsgN(Format("Flamethrower Deploy %s",tostring(self)))
	return self:CallBaseFunction("Deploy")
end

function SWEP:Holster()
	self:StopMmmphReadyEffect()
	if self.SoundsCreated then
		self.SpinUpSound:Stop()
		self.SpinDownSound:Stop()
		self.FireSound:Stop()
		self.FireCritSound:Stop()
		self.PilotSound:Stop()
	end
	
	self.Firing = false
	self.Critting = false
	self:SetFlamethrowerEffect(0)
	
	return self:CallBaseFunction("Holster")
end

function SWEP:OnRemove()
	self:StopMmmphReadyEffect()
	self:Holster()
end

if SERVER then
	hook.Add("EntityTakeDamage", "TFPhlogistinator_MmmphGain", function(ent, dmginfo)
		if not IsValid(ent) or not ent:IsTFPlayer() or ent:IsBuilding() then return end
		
		local attacker = dmginfo:GetAttacker()
		if not IsValid(attacker) or not attacker:IsPlayer() or attacker == ent then return end
		
		local phlog = attacker:GetWeapon("tf_weapon_phlogistinator")
		if not IsValid(phlog) or attacker:GetActiveWeapon() ~= phlog then return end
		
		local inf = dmginfo:GetInflictor()
		local inf_class = IsValid(inf) and inf:GetClass() or ""
		local is_fire_damage = dmginfo:IsDamageType(DMG_BURN)
			or inf_class == "tf_flame"
			or inf_class == "tf_entityflame"
			or inf_class == "entityflame"
		
		if not is_fire_damage then return end
		if dmginfo:GetDamage() <= 0 then return end
		
		phlog:AddMmmphDamage(dmginfo:GetDamage(), ent)
	end)
end

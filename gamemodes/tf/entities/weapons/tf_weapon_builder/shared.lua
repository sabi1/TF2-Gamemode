if SERVER then

AddCSLuaFile("shared.lua")

end

if CLIENT then
 
SWEP.GlobalCustomHUD = {HudBuildingStatus = true}
	SWEP.PrintName			= "Builder"
	SWEP.Slot				= 999
end

SWEP.Base				= "tf_weapon_base"
 
SWEP.ViewModel			= "models/weapons/c_models/c_engineer_arms.mdl"
SWEP.WorldModel			= "models/weapons/c_models/c_sapper/c_sapper.mdl"
 
SWEP.HoldType = "BUILDING"
 
SWEP.Spawnable = true
SWEP.AdminSpawnable = false
SWEP.Category = "Team Fortress 2"

SWEP.HoldTypeHL2 = "rpg"

SWEP.Primary.Delay		= 0.1
SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo			= "none"
SWEP.DeploySound		= Sound("weapons/draw_Secondary.wav")

SWEP.Secondary.Delay		= 0.1
SWEP.Secondary.Automatic	= false
SWEP.HasSecondaryFire = true

SWEP.DeployDuration = 0.1

SWEP.Moving = false

SWEP.MovedBuildingLevel = 1

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

local function tf_spy_mark_sapper_attack(owner, duration)
	if not SERVER then return end
	if not IsValid(owner) or owner:GetPlayerClass() ~= "spy" then return end
	if not owner.InCond or not owner:InCond(TF_COND_DISGUISED) then return end
	owner:SetNWFloat("TFSpyDisguiseSapperAttackUntil", CurTime() + math.max(tonumber(duration) or 0.35, 0.1))
end

function SWEP:SetupDataTables()
	self:CallBaseFunction("SetupDataTables")
	self:DTVar("Int", 1, "BuildGroup")
	self:DTVar("Int", 2, "BuildMode")
end

function SWEP:GetBuildGroup()
	return self.dt.BuildGroup
end

function SWEP:GetBuildMode()
	return self.dt.BuildMode
end

function SWEP:GetBuilding()
	local group, mode = self.dt.BuildGroup, self.dt.BuildMode
	if self then
		if self.Owner and self.Owner:GetPlayerClass() != "spy" then
			if self.Owner.Buildings then
				if self.Owner.Buildings[group] and self.Owner.Buildings[group][mode] then
					return self.Owner.Buildings[group][mode]
				end
			end
		end
	end
end

function SWEP:HasUsableAmmoForSelection()
	local owner = self.Owner or self:GetOwner()
	if not IsValid(owner) then
		return false
	end
	if owner.GetPlayerClass and owner:GetPlayerClass() == "spy" then
		return true
	end

	local building = self:GetBuilding()
	if not building then
		return true
	end

	local cost = tonumber(building.cost or 0) or 0
	return owner:GetAmmoCount(TF_METAL) >= cost
end



function SWEP:SetupBuilding(obj)
	if obj.v_model and obj.w_model then
		self.ViewModelOverride = obj.v_model
		self.ViewModel = self.ViewModelOverride
		self:SetModel(self.ViewModelOverride)
		if IsValid(self.Owner:GetViewModel()) then
			self.Owner:GetViewModel():SetModel(self.ViewModelOverride)
		end
		self.WorldModelOverride = obj.w_model
		
		if CLIENT then
			self.WorldModelOverride2 = obj.w_model
			
			self:InitializeWModel2()

			self.HasCModel = false
			if IsValid(self.CModel) then
				self.CModel:Remove()
			end
		end
		
		self:SetupCModelActivities(nil, true)
	end
end

function SWEP:Inspect()
end

function SWEP:Equip()
	if SERVER then
		if self.Owner:GetPlayerClass() != "spy" then
		----print("Equip building", self.Owner)
		--PrintTable(self.Owner.Buildings)
		
		local group, mode = self.dt.BuildGroup, self.dt.BuildMode
		if not self.Owner.Buildings[group] or not self.Owner.Buildings[group][mode] then
			----print("Not a valid building, changing current building mode")
			for group=0,tf_objects.NumObjects()-1 do
				if self.Owner.Buildings[group] then
					self.dt.BuildGroup = group
					self.dt.BuildMode = 0
					break
				end
			end
		end
		local obj = self:GetBuilding()
		if obj then
			self:SetupBuilding(obj)
		end
		
			end
		----print("group",self.dt.BuildGroup,"mode",self.dt.BuildMode)
	end
	
	return self:CallBaseFunction("Equip")
end

function SWEP:CanPrimaryAttack()
	if self.Owner:GetPlayerClass() == "spy" then
		self.Slot				= 1
	else
		self.Slot				= 11
	end
	return true
end

function SWEP:CanSecondaryAttack()
	return true
end

function SWEP:PrimaryAttack()
	
	if self.Owner:GetPlayerClass() == "spy" then
		tf_spy_mark_sapper_attack(self.Owner, 0.45)
		for k,v in pairs(ents.FindInSphere(self.Owner:GetPos(), 120)) do
			if v:IsPlayer() and v:GetInfoNum("tf_robot", 0) == 1 and not v:IsFriendly(self.Owner) and v:GetInfoNum("tf_giant_robot",0) != 1 then
				self:SetNextPrimaryFire(CurTime() + 10)
				if SERVER then
				if v:GetNWBool("Taunting") == true then return end
				if not v:IsOnGround() then return end
				if v:WaterLevel() ~= 0 then return end
				self.Owner:DoAnimationEvent(ACT_MP_ATTACK_STAND_ITEM2)
				v:EmitSound("Weapon_Sapper.Plant") 
				local seq = v:SelectWeightedSequence( ACT_DOD_SECONDARYATTACK_BOLT )
				local len = v:SequenceDuration( seq )
				local seq2 = v:SelectWeightedSequence( ACT_MP_STUN_MIDDLE )
				local len2 = v:SequenceDuration( v:LookupSequence("primary_stun_middle") )
				timer.Create("StunRobot25"..v:EntIndex(), 0.001, 1, function()
					v:DoAnimationEvent(ACT_MP_STUN_BEGIN,2)
					timer.Create("StunRobotloop3"..v:EntIndex(), len, 0, function()
						if not v:Alive() then timer.Stop("StunRobotloop") v:Freeze(false) return end
						timer.Create("StunRobotloop4"..v:EntIndex(), len2,  0, function()
							if not v:Alive() then timer.Stop("StunRobotloop4") v:Freeze(false) return end
							v:DoAnimationEvent(ACT_MP_STUN_MIDDLE,2)
						end) 
					end)
				end)
				v:DoAnimationEvent(ACT_DOD_SECONDARYATTACK_BOLT, true)
				v:Freeze(true)
				v:EmitSound("SappedRobot")
				v:SetNWBool("Taunting", true)
				v:SetNWBool("NoWeapon", true)
				net.Start("ActivateTauntCam")
				net.Send(v)
				if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
				animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
				animent:SetModel("models/buildables/p2rec_placed.mdl")
				animent:SetSkin(v:GetSkin())
				animent:SetPos(v:GetBonePosition(v:LookupBone("bip_head")))
				animent:SetAngles(v:GetAngles())
				animent:Spawn()
				animent:Activate()
				animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
				animent:PhysicsInit( SOLID_OBB )
				animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
				animent:SetParent(v, v:LookupAttachment("head"))	
				animent:EmitSound("Psap.Hacking")
				elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
				animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
				animent:SetModel("models/buildables/breadmonster_sapper_placed.mdl")
				animent:SetSkin(v:GetSkin())
				animent:SetPos(v:GetBonePosition(v:LookupBone("bip_head")))
				animent:SetAngles(v:GetAngles())
				animent:Spawn()
				animent:Activate()
				animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
				animent:PhysicsInit( SOLID_OBB )
				animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
				animent:SetParent(v, v:LookupAttachment("head"))  
				else
				animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
				animent:SetModel("models/buildables/sapper_placed.mdl")
				animent:SetSkin(v:GetSkin())
				animent:SetPos(v:GetBonePosition(v:LookupBone("bip_head")))
				animent:SetAngles(v:GetAngles())
				animent:Spawn()
				animent:Activate()			
				animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
				animent:PhysicsInit( SOLID_OBB )
				animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
				animent:SetParent(v, v:LookupAttachment("head"))	
				end
				timer.Create("EndStunRobot"..v:EntIndex(), 7, 1, function()
					if not IsValid(v) or (v:Health() < 1 and v:GetNWBool("Taunting") != true) then v:Freeze(false) v:StopSound("SappedRobot") timer.Stop("EndStunRobot"..v:EntIndex()) timer.Stop("StunRobotloop3"..v:EntIndex()) timer.Stop("StunRobotloop4"..v:EntIndex()) return end
					timer.Stop("StunRobotloop3"..v:EntIndex())
					timer.Stop("StunRobotloop4"..v:EntIndex())
					v:StopSound("SappedRobot")
					v:EmitSound("Weapon_Sapper.Removed")
					net.Start("DeActivateTauntCam")
					net.Send(v)
					v:Freeze(false)
					v:SetNWBool("NoWeapon", false)
					v:SetNWBool("Taunting", false)
					animent:Remove()
				end)
				end
			end
			if v:IsPlayer() and not v:IsFriendly(self.Owner) and v:GetInfoNum("tf_giant_robot",0) == 1 then
				self:SetNextPrimaryFire(CurTime() + 10)
				if SERVER then
				if v:GetNWBool("Taunting") == true then return end
				if not v:IsOnGround() then return end
				if v:WaterLevel() ~= 0 then return end
				self.Owner:DoAnimationEvent(ACT_MP_ATTACK_STAND_ITEM2)
				v:EmitSound("Weapon_Sapper.Plant")
				local seq = v:SelectWeightedSequence( ACT_DOD_SECONDARYATTACK_BOLT )
				local len = v:SequenceDuration( seq )
				local seq2 = v:SelectWeightedSequence( ACT_MP_STUN_MIDDLE )
				local len2 = v:SequenceDuration( v:LookupSequence("primary_stun_middle") )
				timer.Create("StunRobot25"..v:EntIndex(), 0.001, 1, function()
					v:DoAnimationEvent(ACT_MP_STUN_BEGIN,2)
					timer.Create("StunRobotloop3"..v:EntIndex(), len, 0, function()
						if not v:Alive() then timer.Stop("StunRobotloop") v:Freeze(false) return end
						timer.Create("StunRobotloop4"..v:EntIndex(), len2, 0, function()
							if not v:Alive() then timer.Stop("StunRobotloop4") v:Freeze(false) return end
							v:DoAnimationEvent(ACT_MP_STUN_MIDDLE,2)
						end) 
					end)
				end)
				v:DoAnimationEvent(ACT_DOD_SECONDARYATTACK_BOLT, true)
				v:EmitSound("SappedRobot")
				v:SetClassSpeed(v:GetClassSpeed() * 0.5)
				net.Send(v)
				if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
				animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
				animent:SetModel("models/buildables/p2rec_placed.mdl")
				animent:SetSkin(v:GetSkin())
				animent:SetPos(v:GetBonePosition(v:LookupBone("bip_head")))
				animent:SetAngles(v:GetAngles())
				animent:Spawn()
				animent:Activate()
				animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
				animent:PhysicsInit( SOLID_OBB )
				animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
				animent:SetParent(v, v:LookupAttachment("head"))	
				self.Owner:EmitSoundEx("Psap.Hacking")
				elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
				animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
				animent:SetModel("models/buildables/breadmonster_sapper_placed.mdl")
				animent:SetSkin(v:GetSkin())
				animent:SetPos(v:GetBonePosition(v:LookupBone("bip_head")))
				animent:SetAngles(v:GetAngles())
				animent:Spawn()
				animent:Activate()
				animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
				animent:PhysicsInit( SOLID_OBB )
				animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
				animent:SetParent(v, v:LookupAttachment("head"))
				else
				animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
				animent:SetModel("models/buildables/sapper_placed.mdl")
				animent:SetSkin(v:GetSkin())
				animent:SetPos(v:GetBonePosition(v:LookupBone("bip_head")))
				animent:SetAngles(v:GetAngles())
				animent:Spawn()
				animent:Activate()			
				animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
				animent:PhysicsInit( SOLID_OBB )
				animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
				animent:SetParent(v, v:LookupAttachment("head"))	
				end
				timer.Create("EndStunRobot"..v:EntIndex(), 7, 1, function()
					if not IsValid(v) or (v:Health() < 1 and v:GetNWBool("Taunting") != true) then v:Freeze(false) v:StopSound("SappedRobot") timer.Stop("EndStunRobot"..v:EntIndex()) timer.Stop("StunRobotloop3"..v:EntIndex()) timer.Stop("StunRobotloop4"..v:EntIndex()) return end
					timer.Stop("StunRobotloop3"..v:EntIndex())
					timer.Stop("StunRobotloop4"..v:EntIndex())
					v:DoAnimationEvent(ACT_MP_STUN_END,2)
					v:StopSound("SappedRobot")
					v:EmitSound("Weapon_Sapper.Removed")
					net.Send(v)
					v:ResetClassSpeed()
					animent:Remove()
				end)
				end
			end 
			if string.find(game.GetMap(), "mvm_") and v:IsPlayer() and v:Team() == TEAM_BLU then
				self:SetNextPrimaryFire(CurTime() + 10)
				if SERVER then
				if v:GetNWBool("Taunting") == true then return end
				if not v:IsOnGround() then return end
				if v:WaterLevel() ~= 0 then return end
				self.Owner:DoAnimationEvent(ACT_MP_ATTACK_STAND_ITEM2)
				v:EmitSound("Weapon_Sapper.Plant")
				
				local seq = v:SelectWeightedSequence( ACT_MP_STUN_BEGIN )
				local len = v:SequenceDuration( seq )
				local seq2 = v:SelectWeightedSequence( ACT_MP_STUN_MIDDLE )
				local len2 = v:SequenceDuration( seq2 )
				timer.Create("StunRobot25"..v:EntIndex(), 0.001, 1, function()
					v:DoAnimationEvent(ACT_MP_STUN_BEGIN,true)
					timer.Create("StunRobotloop3"..v:EntIndex(), 0.7, 0, function()
						if not v:Alive() then timer.Stop("StunRobotloop") v:Freeze(false) return end
						timer.Create("StunRobotloop4"..v:EntIndex(), 0.13,  0, function()
							if not v:Alive() then timer.Stop("StunRobotloop4") v:Freeze(false) return end
							v:DoAnimationEvent(ACT_MP_STUN_MIDDLE,true)
						end) 
					end)
				end)
				v:Freeze(true)
				v:EmitSound("SappedRobot")
				v:SetNWBool("Taunting", true)
				v:SetNWBool("NoWeapon", true)
				net.Start("ActivateTauntCam")
				net.Send(v)
				if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
				animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
				animent:SetModel("models/buildables/p2rec_placed.mdl")
				animent:SetSkin(v:GetSkin())
				animent:SetPos(v:GetBonePosition(v:LookupBone("bip_head")))
				animent:SetAngles(v:GetAngles())
				animent:Spawn()
				animent:Activate()
				animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
				animent:PhysicsInit( SOLID_OBB )
				animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
				animent:SetParent(v, v:LookupAttachment("head")) 
				self.Owner:EmitSoundEx("Psap.Hacking")
				animent:SetName("SappedRobot"..v:EntIndex())	
				elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
				animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
				animent:SetModel("models/buildables/breadmonster_sapper_placed.mdl")
				animent:SetSkin(v:GetSkin())
				animent:SetPos(v:GetBonePosition(v:LookupBone("bip_head")))
				animent:SetAngles(v:GetAngles())
				animent:Spawn()
				animent:Activate()
				animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
				animent:PhysicsInit( SOLID_OBB )
				animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
				animent:SetParent(v, v:LookupAttachment("head"))
				animent:SetName("SappedRobot"..v:EntIndex())	
				else
				animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
				animent:SetModel("models/buildables/sapper_placed.mdl")
				animent:SetSkin(v:GetSkin())
				animent:SetPos(v:GetBonePosition(v:LookupBone("bip_head")))
				animent:SetAngles(v:GetAngles())
				animent:Spawn()
				animent:Activate()			
				animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
				animent:PhysicsInit( SOLID_OBB )
				animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
				animent:SetParent(v, v:LookupAttachment("head"))	
				animent:SetName("SappedRobot"..v:EntIndex())	
				end
				timer.Create("EndStunRobot"..v:EntIndex(), 7, 1, function()
					if not IsValid(v) or (v:Health() < 1 and v:GetNWBool("Taunting") != true) then v:Freeze(false) v:StopSound("SappedRobot") timer.Stop("EndStunRobot"..v:EntIndex()) timer.Stop("StunRobotloop3"..v:EntIndex()) timer.Stop("StunRobotloop4"..v:EntIndex()) return end
					timer.Stop("StunRobotloop3"..v:EntIndex())
					timer.Stop("StunRobotloop4"..v:EntIndex())
					v:DoAnimationEvent(ACT_MP_STUN_END,2)
					v:StopSound("SappedRobot")
					v:EmitSound("Weapon_Sapper.Removed")
					net.Start("DeActivateTauntCam")
					net.Send(v)
					v:Freeze(false)
					v:SetNWBool("NoWeapon", false)
					v:SetNWBool("Taunting", false)
					for k,v in ipairs(ents.FindByName("SappedRobot"..v:EntIndex())) do
						v:Remove()
					end
				end)
				end
			end
			if v:GetClass() == "prop_vehicle_jeep" then
				
				v:EmitSound("weapons/sapper_plant.wav") 
				if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					self.Owner:EmitSoundEx("Psap.Hacking")	
				end
				if SERVER then
					if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/p2rec_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetAttachment(1).Pos)
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:GetAttachment(1))	
					elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/breadmonster_sapper_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetAttachment(1).Pos)
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:GetAttachment(1))	
					else
						animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
						animent:SetModel("models/buildables/sapper_placed.mdl")
						animent:SetSkin(v:GetSkin())
						animent:SetPos(v:GetAttachment(1).Pos)
						animent:SetAngles(v:GetAngles())
						animent:Spawn()
						animent:Activate()			
						animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
						animent:PhysicsInit( SOLID_OBB )
						animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
						animent:SetParent(v, v:GetAttachment(1))	
					end
					v:Fire("AddOutput", "TurnOff")
					v:Fire("AddOutput", "Lock")
					v:Fire("Kill", "", 5)
				end
				timer.Simple(5, function()
					self.Owner:EmitSoundEx(table.Random({"PSap.Hacked","Psap.HackedFollowup","Psap.HackedLoud"})) 
				end)
			end
			if v:GetClass() == "npc_cpt_scp_173" then
				
				v:EmitSound("weapons/sapper_plant.wav") 
				if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					self.Owner:EmitSoundEx("Psap.Hacking")	
				end
				if SERVER then
					if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/p2rec_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetPos())
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:GetAttachment(1))	
					elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/breadmonster_sapper_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetPos())
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:GetAttachment(1))	
					else
						animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
						animent:SetModel("models/buildables/sapper_placed.mdl")
						animent:SetSkin(v:GetSkin())
						animent:SetPos(v:GetPos())
						animent:SetAngles(v:GetAngles())
						animent:Spawn()
						animent:Activate()			
						animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
						animent:PhysicsInit( SOLID_OBB )
						animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
						animent:SetParent(v, v:GetAttachment(1))	
					end
					timer.Simple(5, function()
						v:TakeDamage(v:Health(), self.Owner, self)
					end)
				end
				timer.Simple(5, function()
					self.Owner:EmitSoundEx(table.Random({"PSap.Hacked","Psap.HackedFollowup","Psap.HackedLoud"})) 
				end)
			end
			if v:GetClass() == "npc_cpt_scp_049" then
				
				v:EmitSound("weapons/sapper_plant.wav") 
				if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					self.Owner:EmitSoundEx("Psap.Hacking")	
				end
				if SERVER then
					if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/p2rec_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetPos())
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:GetAttachment(1))	
					elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/breadmonster_sapper_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetPos())
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:GetAttachment(1))	
					else
						animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
						animent:SetModel("models/buildables/sapper_placed.mdl")
						animent:SetSkin(v:GetSkin())
						animent:SetPos(v:GetPos())
						animent:SetAngles(v:GetAngles())
						animent:Spawn()
						animent:Activate()			
						animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
						animent:PhysicsInit( SOLID_OBB )
						animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
						animent:SetParent(v, v:GetAttachment(1))	
					end
					timer.Simple(5, function()
						v:TakeDamage(v:Health(), self.Owner, self)
					end)
				end
				timer.Simple(5, function()
					self.Owner:EmitSoundEx(table.Random({"PSap.Hacked","Psap.HackedFollowup","Psap.HackedLoud"})) 
				end)
			end
			if v:IsBuilding() and not v:IsFriendly(self.Owner) then
				if SERVER then
					if v:GetClass() == "obj_sentrygun" and v.Sapped == true then
						return
					end 
				self:SetNextPrimaryFire(CurTime() + 2)
				self.Owner:DoAnimationEvent(ACT_MP_ATTACK_STAND_ITEM2)
				v:EmitSound("weapons/sapper_plant.wav") 

				
					
				if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					self.Owner:EmitSoundEx("Psap.Hacking")	
				end
				if v:GetClass() == "obj_sentrygun" then
					v:GetBuilder():EmitSound("vo/engineer_autoattackedbyspy03.wav", 80, 100) 
				elseif v:GetClass() == "obj_dispenser" then
					v:GetBuilder():EmitSound("vo/engineer_autoattackedbyspy02.wav", 80, 100)
				elseif v:GetClass() == "obj_teleporter" then
					v:GetBuilder():EmitSound("vo/engineer_autoattackedbyspy01.wav", 80, 100)
				end
				if v:GetClass() == "npc_manhack" then
					
					if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/p2rec_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("manhack.mh_controlexhaust")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("eye"))	
					elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/breadmonster_sapper_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("manhack.mh_controlexhaust"))	)
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("eye"))	
					else
						animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
						animent:SetModel("models/buildables/sapper_placed.mdl")
						animent:SetSkin(v:GetSkin())
						animent:SetPos(v:GetBonePosition(v:LookupBone("manhack.mh_controlexhaust"))	)
						animent:SetAngles(v:GetAngles())
						animent:Spawn()
						animent:Activate()			
						animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
						animent:PhysicsInit( SOLID_OBB )
						animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
						animent:SetParent(v, v:LookupAttachment("eye"))	
					end
					
					for _,ent in ipairs(ents.GetAll()) do
						if ent:IsTFPlayer() then
							v:AddEntityRelationship(ent, D_ER, 999999)
						end
					end
					v:Fire("AddOutPut", "sleepstate 3")
					v:Fire("AddOutPut", "sleepstate 0", 10)
					timer.Simple(10, function()
						v:EmitSound("Weapon_Sapper.Removed")
						animent:Remove()
						for _,ent in ipairs(ents.GetAll()) do
							if ent:IsTFPlayer() then
								v:AddEntityRelationship(ent, D_HT, 999999)
							end
						end
					end)
				end
				if v:GetClass() == "npc_stalker" then
					
					if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/p2rec_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetAttachment(1).Pos)
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:GetAttachment(1))	
					elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/breadmonster_sapper_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetAttachment(1).Pos)
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:GetAttachment(1))	
					else
						animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
						animent:SetModel("models/buildables/sapper_placed.mdl")
						animent:SetSkin(v:GetSkin())
						animent:SetPos(v:GetAttachment(1).Pos)
						animent:SetAngles(v:GetAngles())
						animent:Spawn()
						animent:Activate()			
						animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
						animent:PhysicsInit( SOLID_OBB )
						animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
						animent:SetParent(v, v:GetAttachment(1))	
					end
					
					for _,ent in ipairs(ents.GetAll()) do
						if ent:IsTFPlayer() then
							v:AddEntityRelationship(ent, D_ER, 999999)
						end
					end
					v:Fire("AddOutPut", "sleepstate 3")
				end
				if v:GetClass() == "obj_sentrygun" and v:GetLevel() == 1 then

					if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/p2rec_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))	
					animent:SetName("sentrysapped"..v:EntIndex()) 
					elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/breadmonster_sapper_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))	
					animent:SetName("sentrysapped"..v:EntIndex()) 
					else
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/sapper_sentry1.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))	
					animent:SetName("sentrysapped"..v:EntIndex())
					end

				end 

				if v:GetClass() == "obj_sentrygun" and v:GetLevel() == 2 then

					if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/p2rec_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))
					animent:SetName("sentrysapped"..v:EntIndex())	 
					elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/breadmonster_sapper_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))	
					animent:SetName("sentrysapped"..v:EntIndex()) 
					else
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/sapper_sentry2.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))	
					animent:SetName("sentrysapped"..v:EntIndex())
					end

				end 


				if v:GetClass() == "obj_sentrygun" and v:GetLevel() == 3 then

					if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/p2rec_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))
					animent:SetName("sentrysapped"..v:EntIndex())
					elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/breadmonster_sapper_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))	
					animent:SetName("sentrysapped"..v:EntIndex())
					else
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/sapper_sentry3.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))	
					animent:SetName("sentrysapped"..v:EntIndex())
					end

				end 
				if v:GetClass() == "obj_dispenser" then

					if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/p2rec_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))
					animent:SetName("sentrysapped"..v:EntIndex())
					elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/breadmonster_sapper_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))	
					animent:SetName("sentrysapped"..v:EntIndex())
					else
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/sapper_dispenser.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))	
					animent:SetName("sentrysapped"..v:EntIndex())
					end

				end 
				if v:GetClass() == "obj_teleporter" then

					if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/p2rec_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))
					animent:SetName("sentrysapped"..v:EntIndex())
					elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/breadmonster_sapper_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))	
					animent:SetName("sentrysapped"..v:EntIndex())
					else
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/sapper_teleporter.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("weapon_bone")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v, v:LookupAttachment("sapper_attach"))	
					animent:SetName("sentrysapped"..v:EntIndex())
					end

				end 
				if v:GetClass() == "npc_turret_floor" then

					if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/p2rec_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("Barrel")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v)	 
					elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/breadmonster_sapper_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("Barrel")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:SetParent(v)	 
					else
					animent = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
					animent:SetModel("models/buildables/sapper_placed.mdl")
					animent:SetSkin(v:GetSkin())
					animent:SetPos(v:GetBonePosition(v:LookupBone("Barrel")))
					animent:SetAngles(v:GetAngles())
					animent:Spawn()
					animent:Activate()			
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:AddEffects( EF_BONEMERGE )
					animent:SetParent(v)	
					end
					

					if v:GetClass() == "npc_turret_floor" then
						v:Fire("SelfDestruct", "", 4)
					end

				end
				end
				if v:GetClass() == "obj_sentrygun" or v:GetClass() == "obj_dispenser" or v:GetClass() == "obj_teleporter" then
					v.Sapped = true
				end
				
				timer.Create("SapSentry2", 0.2, 0, function()
					if v:GetClass() != "obj_sentrygun" and v:GetClass() != "obj_dispenser" and v:GetClass() != "obj_teleporter" then
						if not v:IsValid() then
							if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
								self.Owner:EmitSoundEx(table.Random({"PSap.Hacked","Psap.HackedFollowup","Psap.HackedLoud"}))
							end
							timer.Stop("SapSentry2")
						end
					else
					if v.Sapped == true then 
						v.Target = nil
						if SERVER then
							v:TakeDamage(6, self.Owner, self)
						end	
						v.TurretPitch = -15
						v.TurretYaw = 0
						v.TargetPitch = 0
						v.TargetYaw = 0
						v.DPitch = 0
						v.DYaw = 0
						v.SappedBy = self.Owner
						v.IdlePitchSpeed = 0.3
						v.IdleYawSpeed = 0.75
						if not v:IsValid() then
							if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
								self.Owner:EmitSoundEx(table.Random({"PSap.Hacked","Psap.HackedFollowup","Psap.HackedLoud"}))
							end
							timer.Stop("SapSentry2")
						end
					else
						if animent:IsValid() then
							animent:Remove()
						end
						timer.Stop("SapSentry2")
					end
				end
				end)
				timer.Create("SapSentry", 0.1, 0, function()
					if SERVER then
						if v:GetClass() != "obj_sentrygun" and v:GetClass() != "obj_dispenser" and v:GetClass() != "obj_teleporter" then
							if v:GetClass() == "npc_dog" then
								v:TakeDamage(10, self.Owner, self)
							else
								if v:GetClass() != "npc_manhack" then
								v:TakeDamage(2, self.Owner, self)	
								end
							end
							if v:GetClass() == "npc_turret_floor" then
								v:Fire("Disable", "", 0.01)
							end
							if v:GetClass() == "npc_rollermine" then
							v:Fire("TurnOff", "", 0.01)
								v:Fire("Ignite", "", 4)
							end 
						else
							if v.Sapped == false then	
								if self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
									self.Owner:EmitSoundEx("PSap.Damage")
								elseif self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
									self.Owner:EmitSoundEx("Weapon_bm_sapper.scream")
								end
								v.Target = nil
			
								v.TurretPitch = 0
								v.TurretYaw = 0
								v.TargetPitch = 0
								v.TargetYaw = 0
								v.DPitch = 0
								v.DYaw = 0
								v.IdlePitchSpeed = 1
								if IsValid(animent) then
									animent:Remove()
								end
								timer.Stop("SapSentry")
								return
							end
						end 
						if not v:IsValid() then
							if IsValid(animent) then
								animent:Remove()
							end
							timer.Stop("SapSentry")
						end
					end
				end)
			end
		end
	end
		if SERVER then
			local function SelectOwnerMelee(owner)
				if not IsValid(owner) then return end
				local melee = owner:GetWeapon("tf_weapon_wrench")
				if not IsValid(melee) then
					for _, wep in ipairs(owner:GetWeapons()) do
						if not IsValid(wep) then continue end
						if wep.IsPDA then continue end
						local isMelee = (wep.IsMeleeWeapon == true) or (tonumber(wep.Slot or (wep.GetSlot and wep:GetSlot()) or -1) == 2)
						if not isMelee and wep.GetItemData then
							local item = wep:GetItemData()
							isMelee = istable(item) and item.item_slot == "melee"
						end
						if isMelee then
							melee = wep
							break
						end
					end
				end
				if IsValid(melee) then
					owner.ForgetLastWeapon = true
					owner:SelectWeapon(melee:GetClass())
				end
			end

			if IsValid(self.Blueprint) and self.Moving != true then
				local ammo = self.Owner:GetAmmoCount(TF_METAL)
				if self:GetBuilding().cost > ammo then
					return
				end
			
			if self.Blueprint:Build() then
				self.Owner.objtype = self:GetBuilding().objtype
				self.Owner:Speak("TLK_BUILDING_OBJECT")
				if !self.Owner:IsBot() then
					self.Owner:RemoveAmmo(self:GetBuilding().cost, TF_METAL)
					umsg.Start("PlayerMetalBonus", self.Owner)
						umsg.Short(-self:GetBuilding().cost)
					umsg.End() 
				end
					SelectOwnerMelee(self.Owner)
				end
			end
			if IsValid(self.Blueprint) and self.Moving != false then
				
				if self.Blueprint:Build() then
					self.Owner.objtype = self:GetBuilding().objtype
					
					SelectOwnerMelee(self.Owner)
					self.Moving = false
				end
			if SERVER then	
				if self.Owner:GetInfoNum("tf_robot", 0) == 1 then
					--self.Owner:EmitSoundEx("vo/mvm/norm/engineer_mvm_sentryplanting0"..math.random(1,3)..".wav", 80, 100)
				else
					--self.Owner:EmitSoundEx("vo/engineer_sentryplanting0"..math.random(1,3)..".wav", 80, 100)		
				end
			end

		end
	end
	
	return true
end


function SWEP:Deploy()
	--MsgFN("Deploy %s", tostring(self))
	local wmodel = self:GetItemData().model_player or self.WorldModel
		if (self.Owner:GetNWBool("NoWeapon")) then
		self.WorldModel = "models/empty.mdl"
	else
		self.WorldModel = wmodel;
	end;
	local vm = self.Owner:GetViewModel()
	if CLIENT then
		if IsValid(self.CModel) then
			self.CModel:SetModel(wmodel)
			self.CModel:SetNoDraw(true)
			self.CModel:SetParent(vm)
			self.CModel:AddEffects(bit.bor(EF_BONEMERGE,EF_BONEMERGE_FASTCULL))
			self.CModel:DrawModel()
		elseif IsValid(vm) and !IsValid(self.CModel) then
			self.CModel = ents.CreateClientside( "gmod_button" )
			if not IsValid(self.CModel) then return end
			self.CModel:SetModel(wmodel)
			self.CModel:SetNoDraw(true)
			self.CModel:SetParent(vm)
			self.CModel:AddEffects(bit.bor(EF_BONEMERGE,EF_BONEMERGE_FASTCULL))
			self.CModel:Spawn()
			self.CModel:Activate()
			self.CModel:DrawModel()
		end
	end
	if self.Owner:GetPlayerClass() == "spy" then
	
		self:InitializeWModel2()
		self:InitializeAttachedModels()
		if SERVER then
			if IsValid(self.WModel2) then
				--self.WModel2:SetSkin(self.WeaponSkin or self.Owner:GetSkin())
				--self.WModel2:SetMaterial(self.WeaponMaterial or 0)
			end
		end
		local disguiseClass = tf_spy_current_disguise_class(self.Owner)
		if disguiseClass then
			self:SetHoldType("ITEM2")
			if self.SetWeaponHoldType then
				self:SetWeaponHoldType("ITEM2")
			end
		else
			self:SetHoldType("BUILDING")
			if self.SetWeaponHoldType then
				self:SetWeaponHoldType("BUILDING")
			end
		end
		if self:GetItemData().model_player == "models/weapons/c_models/c_breadmonster_sapper/c_breadmonster_sapper.mdl" then
			self.VM_DRAW = ACT_BREADSAPPER_VM_DRAW
			self.VM_IDLE = ACT_BREADSAPPER_VM_IDLE
			self.VM_INSPECT_START = ACT_BREADMONSTER_VM_INSPECT_START
			self.VM_INSPECT_IDLE = ACT_BREADMONSTER_VM_INSPECT_IDLE
			self.VM_INSPECT_END = ACT_BREADMONSTER_VM_INSPECT_END
		end
	end
	if self.Owner:GetPlayerClass() == "spy" and self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
		self.Owner:EmitSoundEx("PSap.Deploy")
	end
	if self.Owner:GetPlayerClass() != "spy" then
		local result = self:CallBaseFunction("Deploy")
		
		if SERVER then
			if IsValid(self.Blueprint) then
				self.Blueprint:Remove()
			end
			self.Blueprint = ents.Create("tf_obj_blueprint")
			self.Blueprint:SetOwner(self)
			self.Blueprint:Spawn()
			
			if self:GetBuildGroup() == 2 and self.Owner.TempAttributes.BuildsMiniSentries then
				self.Blueprint.dt.Scale = 0.75
			elseif self:GetBuildGroup() == 1 and self.Owner.TempAttributes.BuildsMiniSentries then
				self.Blueprint.dt.Scale = 0.7
			elseif self:GetBuildGroup() == 2 and self.Owner.TempAttributes.BuildsMegaSentries then
				self.Blueprint.dt.Scale = 1.2
			end
		end
	
	end
	self:StopTimers()
	self.DeployPlayed = nil
	if self:GetItemData().hide_bodygroups_deployed_only then
		local visuals = self:GetVisuals()
		local owner = self.Owner
		
		if visuals.hide_player_bodygroup_names then
			for _,group in ipairs(visuals.hide_player_bodygroup_names) do
				local b = PlayerNamedBodygroups[owner:GetPlayerClass()]
				if b and b[group] then
					owner:SetBodygroup(b[group], 1)
				end
				
				b = PlayerNamedViewmodelBodygroups[owner:GetPlayerClass()]
				if b and b[group] then
					if IsValid(owner:GetViewModel()) then
						owner:GetViewModel():SetBodygroup(b[group], 1)
					end
				end
			end	
		end
	end
	
	for k,v in pairs(self:GetVisuals()) do
		if k=="hide_player_bodygroup" then
			self.Owner:SetBodygroup(v,1)
		end
	end
	if GetConVar("tf_righthand") and not self:GetClass() == "tf_weapon_compound_bow" then
	if GetConVar("tf_righthand"):GetInt() == 0	then
		self.ViewModelFlip = true
	else
		self.ViewModelFlip = false
	end
	end

	if GetConVar("tf_use_viewmodel_fov"):GetInt() > 0 then
		self.ViewModelFOV	= GetConVar( "viewmodel_fov_tf" ):GetInt()
	else
		self.ViewModelFOV	= GetConVar( "viewmodel_fov" )
	end

	if SERVER then
		----MsgN(Format("Deploy %s (owner:%s)",tostring(self),tostring(self:GetOwner())))
		
		--[[if IsValid(self.Owner) and self.Owner.WeaponItemIndex then
			self:SetItemIndex(self.Owner.WeaponItemIndex)
		end]]
		
		if not IsValid(self.Owner) then
			--MsgFN("Deployed before equip %s",tostring(self))
			self.DeployedBeforeEquip = true
			self.NextReplayDeployAnim = nil
			--self:SendWeaponAnim(ACT_INVALID)
			return true
		end
		
		if _G.TFWeaponItemIndex then
			self:SetItemIndex(_G.TFWeaponItemIndex)
		end
		self:CheckUpdateItem()
		
		self.Owner.weaponmode = string.lower(self.HoldType)
		
		if self.HasTeamColouredWModel then
			if GAMEMODE:EntityTeam(self.Owner)==TEAM_BLU then
				self:SetSkin(1)
			elseif GAMEMODE:EntityTeam(self.Owner)==TF_TEAM_PVE_INVADERS then
				self:SetSkin(1)
			else
				self:SetSkin(0)
			end
		else
			self:SetSkin(0)
		end
		
		self.Owner:ResetClassSpeed()
	end
	
	if CLIENT and not self.DoneFirstDeploy then
		self.RestartClientsideDeployAnim = true
		self.DoneFirstDeploy = true
	end
	
	--MsgFN("SendWeaponAnim %s %d", tostring(self), self.VM_DRAW)
	if SERVER then
		self:SendWeaponAnim(self.VM_DRAW)
	end
	
	local draw_duration = self:SequenceDuration()
	local deploy_duration = self.DeployDuration
	
	if self.Owner.TempAttributes and self.Owner.TempAttributes.DeployTimeMultiplier then
		draw_duration = draw_duration * self.Owner.TempAttributes.DeployTimeMultiplier
		deploy_duration = deploy_duration * self.Owner.TempAttributes.DeployTimeMultiplier
	end
	
	self.NextIdle = CurTime() + draw_duration
	self.NextDeployed = CurTime() + deploy_duration
	--[[
	if CLIENT and self.DeploySound and not self.DeployPlayed then
		self:EmitSound(self.DeploySound)
		self.DeployPlayed = true
	end]]
	
	--self.IsDeployed = false
	self:RollCritical()
	
	if self.Owner.ForgetLastWeapon then
		self.Owner.ForgetLastWeapon = nil
		return false
	end
	
	return true
end


function SWEP:SecondaryAttack()
	if not self:CallBaseFunction("SecondaryAttack") then return false end
	
	if SERVER then
		if IsValid(self.Blueprint) then
			self.Blueprint:RotateBlueprint()
		end
	end
	 
	return true
end

function SWEP:Reload()
end

if SERVER then

function SWEP:SetBuilding(group, mode)
	if self.Owner.Buildings[group] and self.Owner.Buildings[group][mode] then
		self.dt.BuildGroup = group
		self.dt.BuildMode = mode
		self:SetupBuilding(self.Owner.Buildings[group][mode])
		return true
	end
end

function SWEP:SetBuilding2(group, mode)
	if self.Owner.Buildings[group] and self.Owner.Buildings[group][mode] then
		self.dt.BuildGroup = group
		self.dt.BuildMode = mode
		self:SetupBuilding(self.Owner.Buildings[group][mode])
		return true
	end
end

local old_group_translate = {
	[0] = {0,0},
	[1] = {1,0},
	[2] = {1,1},
	[3] = {2,0},
	[4] = {3,0},
}

local function TF_FallbackSelectBuilder(pl, args, useDeployedMode)
	if not IsValid(pl) or not pl:IsPlayer() then return false end

	local group = tonumber(args and args[1])
	local sub = tonumber(args and args[2])
	if not group then return false end
	if not sub then
		local mapped = old_group_translate[group]
		if not mapped then return false end
		group, sub = mapped[1], mapped[2]
	end

	local builder = pl:GetWeapon("tf_weapon_builder")
	if not IsValid(builder) and isfunction(pl.GiveItem) then
		pl:GiveItem("TF_WEAPON_BUILDER")
		builder = pl:GetWeapon("tf_weapon_builder")
	end
	if not IsValid(builder) then return false end

	if useDeployedMode then
		builder:SetHoldType("BUILDING_DEPLOYED")
	else
		builder:SetHoldType("BUILDING")
	end

	local setOk = false
	if isfunction(builder.SetBuilding2) then
		setOk = builder:SetBuilding2(group, sub) and true or false
	elseif isfunction(builder.SetBuilding) then
		setOk = builder:SetBuilding(group, sub) and true or false
	end
	if not setOk then return false end

	local current = pl:GetActiveWeapon()
	if IsValid(current) and current ~= builder then
		if current.IsPDA then
			local last = pl:GetWeapon(pl.LastWeapon)
			if not IsValid(last) or last.IsPDA then
				last = pl:GetWeapons()[1]
			end
			if IsValid(last) then
				builder.LastWeapon = last:GetClass()
				pl:SelectWeapon(last:GetClass())
			end
		else
			builder.LastWeapon = current:GetClass()
		end
	end

	pl:SelectWeapon("tf_weapon_builder")
	builder.Moving = useDeployedMode and true or false
	return true
end

concommand.Add("build", function(pl, cmd, args)
	if not IsValid(pl) or not pl:IsPlayer() then return end
	if isfunction(pl.Build) then
		pl:Build(args[1], args[2])
		return
	end
	TF_FallbackSelectBuilder(pl, args, false)
end)

concommand.Add("move", function(pl, cmd, args)
	if not IsValid(pl) or not pl:IsPlayer() then return end
	if isfunction(pl.Move) then
		pl:Move(args[1], args[2])
		return
	end
	TF_FallbackSelectBuilder(pl, args, true)
end)

concommand.Add("destroy", function(pl, cmd, args)
	if not IsValid(pl) or not pl:IsPlayer() then return end
	if not isfunction(pl.DestroyBuilding) then return end
	pl:DestroyBuilding(args[1], args[2])
end)

function SWEP:Holster()
	if self:CallBaseFunction("Holster") == false then return false end
	
	local owner = self.Owner
	if IsValid(owner) and owner.GetPlayerClass and owner.GetPlayerClass(owner) == "spy" and self:GetItemData().model_player == "models/weapons/c_models/c_p2rec/c_p2rec.mdl" then
		owner:EmitSoundEx("PSap.Holster")
		

	end


	if SERVER then
		if IsValid(self.WModel2) then
			--self.WModel2:Remove()
		end
	end

	if IsValid(animent2) then
		animent2:Remove()
	end

	self:SetHoldType( "BUILDING" )	
	self.HoldType = "BUILDING"
	if SERVER then
		if IsValid(self.Blueprint) then
			self.Blueprint:Remove()
		end
	end
	
	return true
end

end

if CLIENT then

SWEP.PrintName			= "Builder"
SWEP.Crosshair = "tf_crosshair6"

function SWEP:InitializeBuildings(buildings)
	-- Change the slot of the weapon depending on which buildings are available
	for _,group in pairs(buildings) do
		for _,obj in pairs(group) do 
			self.Hidden = obj.hidden
		end
	end
	
	self.BuildingsInitialized = true
	HudWeaponSelection:UpdateLoadout()
end

hook.Add("Think", "TFBuilderInitialize", function()
	for _,v in pairs(ents.FindByClass("tf_weapon_builder")) do
		if not v.BuildingsInitialized and IsValid(v.Owner) and v.Owner:IsPlayer() then
			if v.Owner.BuilderInit then
				v:InitializeBuildings(v.Owner.BuilderInit)
				v.Owner.BuilderInit = nil
			end
		end
	end
end)

end

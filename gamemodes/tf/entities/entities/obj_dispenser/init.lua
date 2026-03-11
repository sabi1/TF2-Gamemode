
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

local tf_minidispenser_allow_upgrade = CreateConVar("tf_minidispenser_allow_upgrade", "0", {FCVAR_CHEAT})
local DISPENSER_DROP_METAL = 40

local DISPENSER_HEAL_RATES = {
	[1] = 10,
	[2] = 15,
	[3] = 20,
}

local DISPENSER_AMMO_RATES = {
	[1] = 0.2,
	[2] = 0.3,
	[3] = 0.4,
}

ENT.NPCCallRange = 512
ENT.NPCCallHealthFraction = 0.75
ENT.NPCCallProbability = 0.5

ENT.NumLevels = 3
ENT.Levels = {
{Model("models/buildables/dispenser.mdl"), Model("models/buildables/dispenser_light.mdl")},
{Model("models/buildables/dispenser_lvl2.mdl"), Model("models/buildables/dispenser_lvl2_light.mdl")},
{Model("models/buildables/dispenser_lvl3.mdl"), Model("models/buildables/dispenser_lvl3_light.mdl")},
}
ENT.IdleSequence = "ref"
ENT.DisableDuringUpgrade = false
ENT.NoUpgradedModel = false

ENT.Sound_Explode = Sound("Building_Dispenser.Explode")
ENT.Sound_Generate = Sound("Building_Dispenser.GenerateMetal")

ENT.Sound_DoneBuilding = Sound("Building_Sentrygun.Built")

ENT.Gibs = {
Model("models/buildables/Gibs/dispenser_gib1.mdl"),
Model("models/buildables/Gibs/dispenser_gib2.mdl"),
Model("models/buildables/Gibs/dispenser_gib3.mdl"),
Model("models/buildables/Gibs/dispenser_gib4.mdl"),
Model("models/buildables/Gibs/dispenser_gib5.mdl"),
}
ENT.Sound_Explode = Sound("Building_Dispenser.Explode")

ENT.Sapped = false

ENT.Range = 100

local function getPlayerDispenserTeam(pl)
	if not IsValid(pl) then return TEAM_UNASSIGNED end
	local t = pl:Team()
	if pl:GetNWBool("Disguised", false) then
		local disguiseTeam = pl:GetNWInt("TFSpyDisguiseTeam", -1)
		if disguiseTeam ~= -1 then
			t = disguiseTeam
		end
	end
	return t
end

local function hasDispenserLOS(ent, target)
	if not IsValid(ent) or not IsValid(target) then return false end
	local startPos = ent:WorldSpaceCenter()
	local endPos = target:WorldSpaceCenter()
	local tr = util.TraceLine({
		start = startPos,
		endpos = endPos,
		filter = {ent, ent.Model},
		mask = bit.bor(MASK_BLOCKLOS, CONTENTS_WINDOW),
	})
	return (not tr.Hit) or tr.Entity == target
end

function ENT:SpawnFunction(pl, tr)
	if not tr.Hit then return end
	if (!pl:IsAdmin()) then return end
	
	local pos = tr.HitPos
	
	local ent = ents.Create(self.ClassName)
	ent:SetPos(pos)
	ent:Spawn()
	ent:Activate()
	
	ent:SetPos(pos - Vector(0,0,ent:OBBMins().z))
	
	ent:SetTeam(pl:Team())
	ent:SetBuilder(pl) 
	
	return ent 
end

function ENT:StartSupply(pl)
	if self.Clients[pl] then return end
	self.NumClients = self.NumClients + 1
	
	local target = ents.Create("info_dummy")
	target:SetPos(pl:GetPos() + Vector(0,0,45))
	target:Spawn()
	target:SetParent(pl)
	target:AttachToEntity(pl)
	target:SetName(tostring(target))
	local e = ParticleSuffix(self:EntityTeam())
	local effect = ents.Create("info_particle_system")
	if self:GetBuildingType() == 2 then
		self:SetModel("models/buildables/dispenser_light.mdl")
		effect:SetKeyValue("effect_name", "medicgun_beam_"..e)
	else
		effect:SetKeyValue("effect_name", "dispenser_heal_"..e)
	end
	effect:SetKeyValue("cpoint1", target:GetName())
	effect:SetKeyValue("start_active", "1" )
	
	effect:SetParent(self)
	effect:Spawn()
	effect:Activate()
	
	effect:Fire("SetParentAttachment", "heal_origin")
	
	self.Clients[pl] = {effect, target}
	pl.BeingHealedByDispenser = true
end

function ENT:StopSupply(pl)
	local t = self.Clients[pl]
	if not t then return end
	self.NumClients = math.max(self.NumClients - 1, 0)
	
	if IsValid(t[1]) then t[1]:Remove() end
	if IsValid(t[2]) then t[2]:Remove() end
	
	self.Clients[pl] = nil
	pl.BeingHealedByDispenser = false
	pl.DoneWaitForHealingSchedule = false
end

function ENT:OnStartBuilding()
	if self:GetBuildingType() == 1 then
		self.BuildRate = 1.5
		self.NextAmmoSupply = CurTime() + 0.5
		self:SetModel("models/buildables/mdispenser.mdl")
		self.Model:SetModel("models/buildables/mdispenser.mdl")
		self.Levels = {
			{Model("models/buildables/mdispenser.mdl"), Model("models/buildables/mdispenser_light.mdl")},
			{Model("models/buildables/mdispenser.mdl"), Model("models/buildables/mdispenser_light.mdl")},
			{Model("models/buildables/mdispenser.mdl"), Model("models/buildables/mdispenser_light.mdl")}
		}
		self.Gibs = {
			Model("models/buildables/gibs/mdispenser_gib1.mdl"),
			Model("models/buildables/gibs/mdispenser_gib2.mdl"),
			Model("models/buildables/Gibs/mdispenser_gib3.mdl"),
			Model("models/buildables/Gibs/mdispenser_gib4.mdl"),
			Model("models/buildables/Gibs/mdispenser_gib5.mdl"),
		}
	end
	if self:GetBuildingType() == 2 then
		self.Model:SetModel("models/buildables/repair_level1.mdl")	
		self:SetModel("models/buildables/dispenser_light.mdl")
		self.Levels = {
			{Model("models/buildables/dispenser_light.mdl"), Model("models/buildables/repair_level1.mdl")},
			{Model("models/buildables/dispenser_light.mdl"), Model("models/buildables/repair_level2.mdl")},
			{Model("models/buildables/dispenser_light.mdl"), Model("models/buildables/repair_level3.mdl")}
		}
	end
end

function ENT:OnDoneBuilding()
	self:EmitSoundEx(self.Sound_DoneBuilding, 100, 100)
	
	self.MetalPerGeneration = 40
	self.HealRate = 0.1
	self.AmmoPerSupply = 40

	self.Clients = {}
	self.NumClients = 0
	
	self:SetNoDraw(false)
	
	self:SetMetalAmount(25)
	self.NextGenerate = CurTime() + 6
	if self:GetBuildingType() == 1 then
		self.NextAmmoSupply = CurTime() + 0.5
		
		self.BuildRate = 2
		self.InitialHealth = self:GetObjectHealth()
		self:SetMaxHealth(self:GetObjectHealth())
		
		if not tf_minidispenser_allow_upgrade:GetBool() then
			self.RepairRate = 0
			self.UpgradeRate = 0
		end
		timer.Simple(0.05, function()
			self:SetModel("models/buildables/mdispenser_light.mdl")
			self.Model:SetModel("models/buildables/mdispenser_light.mdl")
		end)
	elseif self:GetBuildingType() == 2 then 
		
		self.BuildRate = 2
		self.InitialHealth = self:GetObjectHealth()
		self:SetMaxHealth(self:GetObjectHealth())
		
		if not tf_minidispenser_allow_upgrade:GetBool() then
			self.RepairRate = 15
			self.UpgradeRate = 15
		end
		timer.Simple(0.05, function()
			self:SetModel("models/buildables/dispenser_light.mdl")
			self.Model:SetModel("models/buildables/repair_level1.mdl")
		end)
	end
	self._NextDispenseTick = CurTime() + 0.1
	self._NextAmmoSupplyTick = CurTime() + 0.5
end

function ENT:OnStartUpgrade()
	self:EmitSoundEx(self.Sound_DoneBuilding, 100, 100)
	
	if self.level==2 then
		self.MetalPerGeneration = 50
		self.HealRate = 0.066
		self.AmmoPerSupply = 50
		timer.Simple(0.2, function()
			self:SetModel("models/buildables/dispenser_light.mdl")
		end)
		timer.Simple(0.05, function()
			if self:GetBuildingType() == 2 then
			self.Model:SetModel("models/buildables/repair_level2.mdl")
			end
		end)
	else if self.level==3 then
		self.MetalPerGeneration = 60
		self.HealRate = 0.05
		self.AmmoPerSupply = 60
		timer.Simple(0.2, function()
			self:SetModel("models/buildables/dispenser_light.mdl")
		end)
		timer.Simple(0.05, function()
			if self:GetBuildingType() == 2 then
			self.Model:SetModel("models/buildables/repair_level3.mdl")
			end
		end)
		end
	end
end

function ENT:OnThinkActive()
	
	local rf = RecipientFilter()
	rf:AddAllPlayers()
		if !self.Idle_Sound and self:GetState()==3 || self.Idle_Sound and !self.Idle_Sound:IsPlaying() and self:GetState()==3 then
			self.Idle_Sound = CreateSound(self, self.Sound_Idle,rf)
			self.Idle_Sound:Play()
		end
		if !self.Heal_Sound and self:GetNWInt("NumClients",0) > 0 and self:GetState()==3 || self.Heal_Sound != nil and !self.Heal_Sound:IsPlaying() and self:GetNWInt("NumClients",0) > 0 and self:GetState()==3 then
			self.Heal_Sound = CreateSound(self, self.Sound_Heal,rf)
			self.Heal_Sound:Play()
		end
		if (self.Heal_Sound != nil and self.Heal_Sound:IsPlaying() and self:GetNWInt("NumClients",0) <= 0 and self:GetState()==3) then
			self.Heal_Sound:Stop()
		end
	self:SetNWInt("NumClients",self.NumClients)
	if self.NextGenerate and CurTime()>=self.NextGenerate then
		local color = self:GetColor()
		local level = math.Clamp(tonumber(self:GetLevel() or 1) or 1, 1, 3)
		local addMetal = 40 + ((level - 1) * 10)
		if self:AddMetalAmount(addMetal)>0 and color.a>0 then
			self:EmitSoundEx(self.Sound_Generate, 100, 100)
		end
		self.NextGenerate = CurTime() + 6
	end
	
	if not self.NextSearch or CurTime()>=self.NextSearch then
		local removedclients = table.Copy(self.Clients)
		for _,v in pairs(ents.FindInSphere(self:WorldSpaceCenter(), self.Range)) do
			if v:IsPlayer() and v:Alive() and not v:IsBuilding() then
				local teamOk = (self:Team()==TEAM_NEUTRAL) or (getPlayerDispenserTeam(v) == self:Team())
				local losOk = hasDispenserLOS(self, v)
				if teamOk and losOk then
					if self.Clients[v] then
						removedclients[v] = nil
					else
						self:StartSupply(v)
					end
				end
			end
			if (v.Base == "npc_tf2base") and not v:IsBuilding() and (self:Team()==TEAM_NEUTRAL or GAMEMODE:EntityTeam(v)==self:Team()) then
				if self.Clients[v] then
					removedclients[v] = nil
				else
					self:StartSupply(v)
				end
			end
			if (self:GetBuildingType() == 2) and v:IsBuilding() and (self:Team()==TEAM_NEUTRAL or GAMEMODE:EntityTeam(v)==self:Team()) then
				if self.Clients[v] then 
					removedclients[v] = nil
				else
					self:StartSupply(v)
				end
			end
		end
		
		for k,_ in pairs(removedclients) do
			self:StopSupply(k)
		end
		
		self.NextSearch = CurTime() + 0.1
	end
	
	if not self._NextAmmoSupplyTick or CurTime()>=self._NextAmmoSupplyTick then
		local metal_before = self:GetMetalAmount()
		local metal_after = metal_before
		local level = math.Clamp(tonumber(self:GetLevel() or 1) or 1, 1, 3)
		local ammoRate = DISPENSER_AMMO_RATES[level] or DISPENSER_AMMO_RATES[1]
		local metalPerGive = DISPENSER_DROP_METAL + ((level - 1) * 10)
		local anyAmmoGiven = false
		
		for k,_ in pairs(self.Clients) do
			if k:IsPlayer() then
				local gavePlayerAmmo = false
				local giveTypes = {TF_PRIMARY, TF_SECONDARY}
				for _, ammoType in ipairs(giveTypes) do
					local maxAmmo = k.AmmoMax and tonumber(k.AmmoMax[ammoType]) or 0
					if maxAmmo > 0 then
						local want = math.max(1, math.floor(maxAmmo * ammoRate))
						local before = tonumber(k:GetAmmoCount(ammoType) or 0) or 0
						local added = k:GiveAmmo(want, ammoType, false) or 0
						if added <= 0 then
							local after = tonumber(k:GetAmmoCount(ammoType) or 0) or 0
							added = math.max(0, after - before)
						end
						if added > 0 then
							gavePlayerAmmo = true
						end
					end
				end

				if metal_after > 0 then
					local ammo_before = k:GetAmmoCount(TF_METAL)
					if isfunction(k.GiveTFAmmo) then
						k:GiveTFAmmo(math.min(metalPerGive, metal_after), TF_METAL)
					else
						k:GiveAmmo(math.min(metalPerGive, metal_after), TF_METAL, false)
					end
					local ammo_after = k:GetAmmoCount(TF_METAL)
					local delta = math.max(0, ammo_after - ammo_before)
					if delta > 0 then
						gavePlayerAmmo = true
						metal_after = metal_after - delta
					end
				end

				if gavePlayerAmmo then
					anyAmmoGiven = true
				end
			end
		end
		self:AddMetalAmount(metal_after - metal_before)
		self._NextAmmoSupplyTick = CurTime() + (anyAmmoGiven and 1 or 0.1)
	end
	
	if not self.NextHeal or CurTime()>=self.NextHeal then
		local level = math.Clamp(tonumber(self:GetLevel() or 1) or 1, 1, 3)
		local healPerSecond = DISPENSER_HEAL_RATES[level] or DISPENSER_HEAL_RATES[1]
		local tickHeal = healPerSecond * 0.1
		for k,_ in pairs(self.Clients) do
			if self:GetBuildingType() == 2 then
				k:SetHealth(math.Clamp(k:Health() + 1.5, 0, k:GetMaxHealth() + 140))
			else
				k:SetHealth(math.Clamp(k:Health() + tickHeal, 0, k:GetMaxHealth()))
			end
			
			if k:IsNPC() and not k:IsCurrentSchedule(SCHED_FORCED_GO_RUN) and not k.DoneWaitForHealingSchedule then
				if IsValid(k:GetEnemy()) then
					k:SetSchedule(SCHED_SHOOT_ENEMY_COVER)
				else
					k:SetSchedule(SCHED_COWER)
				end
				k.DoneWaitForHealingSchedule = true
			end
		end
		self.NextHeal = CurTime() + 0.1
	end
	
	if not self.NextCallNPCs or CurTime()>=self.NextCallNPCs then
		for _,v in pairs(ents.FindInSphere(self:GetPos(), self.NPCCallRange)) do
			if not v.BeingHealedByDispenser and v:IsNPC() and v:IsFriendly(self) and not v:IsBuilding() and v:GetMoveType()==MOVETYPE_STEP then
				if v:GetMaxHealth() > 0 and v:Health() / v:GetMaxHealth() <= self.NPCCallHealthFraction then
					if math.random() < self.NPCCallProbability then
						v:SetLastPosition(self:NearestPoint(v:GetPos()))
						v:SetSchedule(SCHED_FORCED_GO_RUN)
					end
				end
			end
		end
		self.NextCallNPCs = CurTime() + 2
	end
end

function ENT:OnRemove()
	for ent,_ in pairs(self.Clients or {}) do
		self:StopSupply(ent)
	end
end

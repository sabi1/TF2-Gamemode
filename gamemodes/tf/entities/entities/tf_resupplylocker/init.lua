AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel( "models/props_gameplay/resupply_locker.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
 
    local phys = self:GetPhysicsObject()
	if (phys:IsValid(self.WModel2)) then
		phys:Wake()
	end

	self.Team = 0
	self.Players = {}
	self.Opened = false
end

local PreserveResupplyWeapons = {
	["tf_weapon_jar_gas"] = true,
}

local RefillResupplyWeapons = {
	["tf_weapon_jar_milk"] = true,
}

local function PreserveMeterAmmo(pl, fn)
	if not IsValid(pl) then return fn() end
	
	local saved = {}
	for class,_ in pairs(PreserveResupplyWeapons) do
		local wep = pl:GetWeapon(class)
		if IsValid(wep) and wep.Primary and wep.Primary.Ammo then
			local maxcarry = wep.MaxCarry or 1
			local authoritative = wep.LastTrackedAmmo
			if authoritative == nil then
				authoritative = wep:Ammo1()
			end
			authoritative = math.Clamp(authoritative or 0, 0, maxcarry)
			saved[class] = {
				ammo_type = wep.Primary.Ammo,
				ammo_count = authoritative,
				gas_frac = pl:GetNWFloat("GasPasserChargeFrac", 0),
			}
		end
	end
	
	fn()
	
	for class,data in pairs(saved) do
		pl:SetNWFloat("GasPasserChargeFrac", data.gas_frac or 0)
		pl:SetAmmoCount(((data.gas_frac or 0) >= 1) and data.ammo_count or 0, data.ammo_type)
		
		local wep = pl:GetWeapon(class)
		if IsValid(wep) then
			wep.LastTrackedAmmo = ((data.gas_frac or 0) >= 1) and data.ammo_count or 0
			if wep.RestorePersistentCharge then
				wep:RestorePersistentCharge()
			end
			if wep.ClampAmmo then
				wep:ClampAmmo()
			end
		end
	end
end

local function RefillResupplyThrowables(pl)
	if not IsValid(pl) then return end

	for class,_ in pairs(RefillResupplyWeapons) do
		local wep = pl:GetWeapon(class)
		if IsValid(wep) and wep.Primary and wep.Primary.Ammo then
			local maxcarry = math.max(0, wep.MaxCarry or 1)
			if maxcarry > 0 then
				pl:SetAmmoCount(maxcarry, wep.Primary.Ammo)
				wep.LastTrackedAmmo = maxcarry
			end

			if pl.NextGiveAmmoType == wep.Primary.Ammo then
				pl.NextGiveAmmo = nil
				pl.NextGiveAmmoType = nil
			end
		end
	end
end
 
function ENT:Use( activator, caller )
    return
end
 
function ENT:ResolveAnimationTarget()
	if IsValid(self.ResupplyLockerTarget) then
		return self.ResupplyLockerTarget
	end

	if self.ResupplyLockerName and self.ResupplyLockerName ~= "" then
		self.ResupplyLockerTarget = ents.FindByName(self.ResupplyLockerName)[1]
	end

	if IsValid(self.ResupplyLockerTarget) then
		return self.ResupplyLockerTarget
	end

	return self
end

function ENT:SetLockerAnimation(sequence)
	local target = self:ResolveAnimationTarget()
	if IsValid(target) then
		target:Fire("SetAnimation", sequence)
	end
end


function ENT:KeyValue(key,value)
	key = string.lower(key)
	
	if key=="teamnum" then
		self.Team = tonumber(value)
	elseif key=="associatedmodel" then
		self.ResupplyLockerName = value
	end
end

function ENT:StartTouch(ent)
	if ent:IsPlayer() then
		self.Players[ent] = -1
	end
end

function ENT:EndTouch(ent)
	if ent:IsPlayer() then
		self.Players[ent] = nil
	end
end

function ENT:Think()
	local resupplied
	
	for pl,last in pairs(self.Players) do
		if last==-1 or CurTime()-last>1 then
			resupplied = true
			PreserveMeterAmmo(pl, function()
				GAMEMODE:GiveHealthPercent(pl, 100)
				GAMEMODE:GiveAmmoPercent(pl, 100)
			end)
			RefillResupplyThrowables(pl)
			if self.Opened then
				self:EmitSound("AmmoPack.Touch", 100, 100)
			end
			self.Players[pl] = CurTime()
		end
	end
	
	if resupplied and not self.Opened then
		self:EmitSound("Regenerate.Touch", 100, 100)
		self:SetLockerAnimation("open")
		
		self.Opened = true
		self.NextClose = CurTime() + 1.5
	end
	
	if self.NextClose and CurTime()>=self.NextClose then
		self:SetLockerAnimation("close")
		self.NextIdle = CurTime() + 1.5
		self.NextClose = nil
	end
	
	if self.NextIdle and CurTime()>=self.NextIdle then
		--[[if self and self:IsValid(self.WModel2) then
			self:ResetSequence(self:LookupSequence("idle"))
		end]]
		
		self.NextIdle = nil
		self.Opened = false
	end
end

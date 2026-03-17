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
 
function ENT:Use( activator, caller )
    return
end
 

function ENT:KeyValue(key,value)
	key = string.lower(key)
	
	if key=="teamnum" then
		self.Team = tonumber(value)
	elseif key=="associatedmodel" then
		selfName = value
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
			if self.Opened then
				self:EmitSound("AmmoPack.Touch", 100, 100)
			end
			self.Players[pl] = CurTime()
		end
	end
	
	if resupplied and not self.Opened then
		self:EmitSound("Regenerate.Touch", 100, 100)
		
		if not self and selfName then
			self = ents.FindByName(selfName)[1]
			----print("associatedmodel : "..selfName.." : "..tostring(self))
		end
		
		if self and self:IsValid(self.WModel2) then
			--self:ResetSequence(self:LookupSequence("open"))
			self:Fire("SetAnimation", "open")
		end
		
		self.Opened = true
		self.NextClose = CurTime() + 1.5
	end
	
	if self.NextClose and CurTime()>=self.NextClose then
		if self and self:IsValid(self.WModel2) then
			--self:ResetSequence(self:LookupSequence("close"))
			--self.NextIdle = CurTime() + self:SequenceDuration() - 0.2
			self:Fire("SetAnimation", "close")
			self.NextIdle = CurTime() + 1.5
		else
			self.NextIdle = CurTime() + 1.5
		end
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

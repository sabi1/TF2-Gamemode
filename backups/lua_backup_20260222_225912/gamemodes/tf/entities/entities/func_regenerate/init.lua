ENT.Base = "base_brush"
ENT.Type = "brush"

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
				gas_end = pl:GetNWFloat("GasRechargeEnd", 0),
			}
		end
	end
	
	fn()
	
	for class,data in pairs(saved) do
		pl:SetAmmoCount(data.ammo_count, data.ammo_type)
		pl:SetNWFloat("GasPasserChargeFrac", data.gas_frac or 0)
		pl:SetNWFloat("GasRechargeEnd", data.gas_end or 0)
		
		local wep = pl:GetWeapon(class)
		if IsValid(wep) then
			wep.LastTrackedAmmo = data.ammo_count
			if wep.SetRechargeEndTime then
				wep:SetRechargeEndTime(data.gas_end and data.gas_end > 0 and data.gas_end or nil)
			end
			if wep.ClampAmmo then
				wep:ClampAmmo()
			end
		end
	end
end

function ENT:Initialize()
	self.Team = 0
	self.Players = {}
	self.Opened = false
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
		if (last==-1 or CurTime()-last>1) and IsValid(pl) and pl:IsPlayer() then
			resupplied = true
		end
	end
	
	if resupplied and not self.Opened then
		self:EmitSound("items/regenerate.wav", 100, 100)
		for pl,last in pairs(self.Players) do
			if (last==-1 or CurTime()-last>1) and IsValid(pl) and pl:IsPlayer() then
				PreserveMeterAmmo(pl, function()
					GAMEMODE:GiveHealthPercent(pl, 100)
					GAMEMODE:GiveAmmoPercent(pl, 100)
					local c = GAMEMODE.PlayerClasses[pl:GetPlayerClass()]
					pl.ItemLoadout = table.Copy(c.DefaultLoadout)
					pl.ItemProperties = {}
					pl:SetPlayerClass(pl:GetPlayerClass())		
					pl:GiveLoadout()
				end)
				self.Players[pl] = CurTime()
				self.NextClose = CurTime() + 1.5
				
			end
		end
		if not self.ResupplyLocker and self.ResupplyLockerName then
			self.ResupplyLocker = ents.FindByName(self.ResupplyLockerName)[1]
			----print("associatedmodel : "..self.ResupplyLockerName.." : "..tostring(self.ResupplyLocker))
		end
		
		if self.ResupplyLocker and self.ResupplyLocker:IsValid(self.WModel2) then
			--self.ResupplyLocker:ResetSequence(self.ResupplyLocker:LookupSequence("open"))
			self.ResupplyLocker:Fire("SetAnimation", "open")
		end
		
		self.Opened = true
		self.NextClose = CurTime() + 1.5
	end
	
	if self.NextClose and CurTime()>=self.NextClose then
		if self.ResupplyLocker and self.ResupplyLocker:IsValid(self.WModel2) then
			--self.ResupplyLocker:ResetSequence(self.ResupplyLocker:LookupSequence("close"))
			--self.NextIdle = CurTime() + self.ResupplyLocker:SequenceDuration()
			self.ResupplyLocker:Fire("SetAnimation", "close")
			self.NextIdle = CurTime() + 1.5
		else
			self.NextIdle = CurTime() + 1.5
		end
		self.NextClose = nil
	end
	
	if self.NextIdle and CurTime()>=self.NextIdle then
		--[[if self.ResupplyLocker and self.ResupplyLocker:IsValid(self.WModel2) then
			self.ResupplyLocker:ResetSequence(self.ResupplyLocker:LookupSequence("idle"))
		end]]
		
		self.NextIdle = nil
		self.Opened = false
	end
end

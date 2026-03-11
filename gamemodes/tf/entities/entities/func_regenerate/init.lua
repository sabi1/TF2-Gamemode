ENT.Base = "base_brush"
ENT.Type = "brush"

local TF_REGENERATE_SOUND = "Regenerate.Touch"
local TF_REGENERATE_NEXT_USE_TIME = 3.0
local TF_LOCKER_CLOSE_DELAY = TF_REGENERATE_NEXT_USE_TIME - 1.0

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
	self.Disabled = false
end

function ENT:KeyValue(key,value)
	key = string.lower(key)
	
	if key=="teamnum" then
		self.Team = tonumber(value)
	elseif key=="associatedmodel" then
		self.ResupplyLockerName = value
	elseif key=="startdisabled" then
		self.Disabled = tonumber(value) == 1
	end
end

function ENT:SetDisabled(disabled)
	self.Disabled = disabled and true or false
end

function ENT:IsDisabled()
	return self.Disabled == true
end

function ENT:AcceptInput(name)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self:SetDisabled(false)
		return true
	elseif name == "disable" then
		self:SetDisabled(true)
		return true
	elseif name == "toggle" then
		self:SetDisabled(not self:IsDisabled())
		return true
	end
	return false
end

function ENT:ResolveAssociatedLocker()
	if IsValid(self.ResupplyLocker) then return self.ResupplyLocker end
	if not self.ResupplyLockerName or self.ResupplyLockerName == "" then return nil end
	self.ResupplyLocker = ents.FindByName(self.ResupplyLockerName)[1]
	return self.ResupplyLocker
end

function ENT:CanRegeneratePlayer(pl)
	if self:IsDisabled() then return false end
	if not IsValid(pl) or not pl:IsPlayer() then return false end
	if not pl:Alive() then return false end
	if pl:GetNWBool("Taunting", false) then return false end
	if pl.IsPlayingTaunt and pl:IsPlayingTaunt() then return false end

	local nextRegen = pl.__TFNextRegenerateTime or 0
	if nextRegen > CurTime() then return false end

	if GAMEMODE and GAMEMODE.RoundHasWinner then
		local winning = GAMEMODE.WinningTeam
		if winning and pl:Team() ~= winning then
			return false
		end
	elseif self.Team and self.Team ~= 0 and pl:Team() ~= self.Team then
		return false
	end

	return true
end

function ENT:OpenLocker()
	if self.Opened then
		self.NextClose = CurTime() + TF_LOCKER_CLOSE_DELAY
		return
	end

	local locker = self:ResolveAssociatedLocker()
	if IsValid(locker) then
		locker:Fire("SetAnimation", "open")
	end

	self.Opened = true
	self.NextClose = CurTime() + TF_LOCKER_CLOSE_DELAY
end

function ENT:RegeneratePlayer(pl)
	if not self:CanRegeneratePlayer(pl) then return false end

	PreserveMeterAmmo(pl, function()
		GAMEMODE:GiveHealthPercent(pl, 100)
		GAMEMODE:GiveAmmoPercent(pl, 100)
	end)

	pl.__TFNextRegenerateTime = CurTime() + TF_REGENERATE_NEXT_USE_TIME
	pl:EmitSound(TF_REGENERATE_SOUND, 100, 100)
	self:OpenLocker()
	return true
end

function ENT:StartTouch(ent)
	if ent:IsPlayer() then
		self.Players[ent] = true
		self:RegeneratePlayer(ent)
	end
end

function ENT:EndTouch(ent)
	if ent:IsPlayer() then
		self.Players[ent] = nil
	end
end

function ENT:Think()
	for pl,_ in pairs(self.Players) do
		if not IsValid(pl) then
			self.Players[pl] = nil
		else
			self:RegeneratePlayer(pl)
		end
	end

	if self.NextClose and CurTime()>=self.NextClose then
		local locker = self:ResolveAssociatedLocker()
		if IsValid(locker) then
			locker:Fire("SetAnimation", "close")
		end
		self.NextIdle = CurTime() + 1.0
		self.NextClose = nil
	end
	
	if self.NextIdle and CurTime()>=self.NextIdle then
		self.NextIdle = nil
		self.Opened = false
	end

	self:NextThink(CurTime() + 0.05)
	return true
end

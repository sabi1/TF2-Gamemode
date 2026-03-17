
ENT.Type = "anim"  
ENT.Base = "item_base"    

ENT.Model = "models/items/ammopack_small.mdl"
ENT.AmmoPercentage = 1

if SERVER then

AddCSLuaFile("shared.lua")

local function IsTFStylePlayer(ply)
	return IsValid(ply) and ply.IsTFPlayer and ply:IsTFPlayer()
end

local function CollectAmmoTypesFromWeapons(pl)
	local seen = {}
	local ammoTypes = {}
	for _, wep in ipairs(pl:GetWeapons() or {}) do
		if not IsValid(wep) then continue end
		if wep.GetPrimaryAmmoType then
			local t = wep:GetPrimaryAmmoType()
			if isnumber(t) and t >= 0 and not seen[t] then
				seen[t] = true
				ammoTypes[#ammoTypes + 1] = t
			end
		end
		if wep.GetSecondaryAmmoType then
			local t = wep:GetSecondaryAmmoType()
			if isnumber(t) and t >= 0 and not seen[t] then
				seen[t] = true
				ammoTypes[#ammoTypes + 1] = t
			end
		end
	end
	return ammoTypes
end

local function HasFullAmmoGeneric(pl)
	local ammoTypes = CollectAmmoTypesFromWeapons(pl)
	if #ammoTypes == 0 then return true end
	for _, ammoType in ipairs(ammoTypes) do
		local maxAmmo = game.GetAmmoMax and game.GetAmmoMax(ammoType) or 0
		if isnumber(maxAmmo) and maxAmmo > 0 and pl:GetAmmoCount(ammoType) < maxAmmo then
			return false
		end
	end
	return true
end

local function GiveAmmoPercentGeneric(pl, percent)
	local ammoGiven = false
	local frac = math.max(0, tonumber(percent) or 0) * 0.01
	for _, ammoType in ipairs(CollectAmmoTypesFromWeapons(pl)) do
		local maxAmmo = game.GetAmmoMax and game.GetAmmoMax(ammoType) or 0
		if not (isnumber(maxAmmo) and maxAmmo > 0) then continue end
		local have = pl:GetAmmoCount(ammoType)
		local missing = math.max(0, maxAmmo - have)
		if missing <= 0 then continue end
		local grant = math.min(missing, math.max(1, math.ceil(maxAmmo * frac)))
		if grant > 0 then
			pl:GiveAmmo(grant, ammoType, false)
			ammoGiven = true
		end
	end
	return ammoGiven
end

function ENT:CanPickup(ply)
	if IsTFStylePlayer(ply) then
		if not ply:HasFullAmmo() then
			return true
		end
		if isfunction(TF_CanSpyGainCloakFromItems) and isfunction(TF_GetSpyCloakMeter) then
			if TF_CanSpyGainCloakFromItems(ply) and (TF_GetSpyCloakMeter(ply) or 100) < 100 then
				return true
			end
		end
		return false
	end
	return not HasFullAmmoGeneric(ply)
end

function ENT:PlayerTouched(pl)
	local a = self.AmmoPercentage
	if pl.TempAttributes and pl.TempAttributes.AmmoFromPacksMultiplier then
		a = a * pl.TempAttributes.AmmoFromPacksMultiplier
	end
	if pl:IsPlayer() then
		local gaveAmmo = false
		if IsTFStylePlayer(pl) then
			gaveAmmo = GAMEMODE:GiveAmmoPercent(pl, a, nil, true)
		else
			gaveAmmo = GiveAmmoPercentGeneric(pl, a)
		end
		if gaveAmmo then
			pl:EmitSound("AmmoPack.Touch", 100, 100)
			self:Hide()
		end
	end
end

function ENT:StartTouch(ent)
	if self.NextActive then return end
	if not IsValid(ent) or not ent:IsPlayer() then return end
	if ent == self:GetOwner() then return end
	if not self:CanPickup(ent) then return end
	self:PlayerTouched(ent)
end



end

ENT.PrintName = "Halloween Spell Pickup"
ENT.Author = "TF2-Gamemode"
ENT.Information = "Spell pickup used by Halloween events."
ENT.Category = "Team Fortress 2"
ENT.Spawnable = false
ENT.AdminSpawnable = true

ENT.Type = "anim"
ENT.Base = "item_base"
ENT.Model = "models/props_halloween/hwn_spellbook_upright.mdl"

if SERVER then
	AddCSLuaFile()
end

local function apply_buff_cond(ply, condId, duration)
	if not IsValid(ply) or not ply.AddCond then return false end
	if not isnumber(condId) then return false end
	ply:AddCond(condId, duration)
	return true
end

function ENT:Initialize()
	if SERVER then
		if not (util and util.IsValidModel and util.IsValidModel(self.Model)) then
			self.Model = "models/props_halloween/gargoyle_ghost.mdl"
		end
	end
	self.BaseClass.Initialize(self)
	self:SetNWBool("RareSpellPickup", false)
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	if key == "model" then
		self.Model = tostring(value)
		return
	end
	if key == "rare" then
		self:SetNWBool("RareSpellPickup", tonumber(value) == 1 or tostring(value) == "true")
		return
	end
	self.BaseClass.KeyValue(self, key, value)
end

function ENT:CanPickup(ply)
	return IsValid(ply) and ply:IsTFPlayer() and ply:Alive()
end

function ENT:GiveHalloweenSpellEffect(ply)
	-- Closest available approximation in this addon:
	-- give a short movement + crit style reward window on pickup.
	local duration = self:GetNWBool("RareSpellPickup", false) and 12 or 8
	local gaveAny = false

	gaveAny = apply_buff_cond(ply, TF_COND_SPEED_BOOST, duration) or gaveAny
	gaveAny = apply_buff_cond(ply, TF_COND_CRITBOOSTED, duration) or gaveAny
	gaveAny = apply_buff_cond(ply, TF_COND_CRITBOOSTED_PUMPKIN, duration) or gaveAny

	if not gaveAny then
		ply:SetNWFloat("HalloweenSpellBoostUntil", CurTime() + duration)
	end
end

function ENT:PlayerTouched(pl)
	if not IsValid(pl) then return end

	self:EmitSound("Halloween.spell_pickup", 70, 125)
	if self:GetNWBool("RareSpellPickup", false) then
		self:EmitSound("Halloween.spell_pickup_rare", 72, 128)
	end

	self:GiveHalloweenSpellEffect(pl)

	if self.TriggerOutput then
		self:TriggerOutput("OnPlayerTouch", pl)
		self:TriggerOutput("OnSpellPickup", pl)
	end

	self:Hide()
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self:SetTrigger(true)
		self:SetNoDraw(false)
		self:DrawShadow(true)
	elseif name == "disable" then
		self:SetTrigger(false)
		self:SetNoDraw(true)
		self:DrawShadow(false)
	elseif name == "forcespawn" then
		self:Show()
	elseif name == "forcerespawn" then
		self:Show()
	elseif name == "pickup" then
		if IsValid(activator) and activator:IsPlayer() then
			self:PlayerTouched(activator)
		end
	elseif name == "setrare" then
		self:SetNWBool("RareSpellPickup", tonumber(data) == 1 or tostring(data) == "true")
	end
end

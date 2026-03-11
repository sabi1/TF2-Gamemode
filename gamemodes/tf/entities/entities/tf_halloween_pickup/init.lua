ENT.PrintName = "Halloween Pickup"
ENT.Author = "TF2-Gamemode"
ENT.Information = "Generic Halloween pickup used by map logic."
ENT.Category = "Team Fortress 2"
ENT.Spawnable = false
ENT.AdminSpawnable = true

ENT.Type = "anim"
ENT.Base = "item_base"
ENT.Model = "models/props_halloween/halloween_gift.mdl"

if SERVER then
	AddCSLuaFile()
end

function ENT:Initialize()
	if SERVER and util and util.IsValidModel and not util.IsValidModel(self.Model) then
		self.Model = "models/props_halloween/gargoyle_ghost.mdl"
	end
	self.BaseClass.Initialize(self)
end

function ENT:CanPickup(ply)
	return IsValid(ply) and ply:IsTFPlayer() and ply:Alive()
end

function ENT:PlayerTouched(pl)
	if not IsValid(pl) then return end

	self:EmitSound("Halloween.spell_pickup", 70, 125)
	if self.TriggerOutput then
		self:TriggerOutput("OnPlayerTouch", pl)
		self:TriggerOutput("OnPickup", pl)
	end

	pl:SetNWInt("HalloweenPickups", pl:GetNWInt("HalloweenPickups", 0) + 1)
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
	elseif name == "pickup" then
		if IsValid(activator) and activator:IsPlayer() then
			self:PlayerTouched(activator)
		end
	elseif name == "forcespawn" or name == "forcerespawn" then
		self:Show()
	end
end

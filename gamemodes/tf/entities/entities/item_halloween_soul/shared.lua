ENT.PrintName = "Halloween Soul"
ENT.Author = "TF2-Gamemode"
ENT.Information = "A soul for the Soul Gargoyle."
ENT.Category = "Team Fortress 2"

ENT.Spawnable = true
ENT.AdminSpawnable = true

ENT.Type = "anim"
ENT.Base = "item_base"

ENT.Model = "models/props_halloween/gargoyle_ghost.mdl"

if SERVER then
	AddCSLuaFile("shared.lua")
end

function ENT:Initialize()
	if SERVER then
		self:SetSolid(SOLID_VPHYSICS)
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetTrigger(true)
		self:SetNotSolid(true)
		self:SetCollisionBounds(Vector(-36, -36, 0), Vector(36, 36, 96))
		self:UseTriggerBounds(true, 28)

		local sequence = self:SelectWeightedSequence(ACT_IDLE)
		self:ResetSequence(sequence)
		self:SetPlaybackRate(1)
		self:SetCycle(0)

		if self.ActivateDelay then
			self.NextActive = CurTime() + self.ActivateDelay
		end

		self:EmitSound("Item.Materialize", 75, 140)
	end

	-- Use the ghostly variant when the model provides an alternate skin.
	if self:SkinCount() > 1 then
		self:SetSkin(1)
	end

	if CLIENT then
		self:SetRenderMode(RENDERMODE_TRANSCOLOR)
		self:SetColor(Color(170, 255, 185, 230))
		self:SetRenderFX(kRenderFxGlowShell)
		self:SetRenderBounds(Vector(-48, -48, -16), Vector(48, 48, 80))
	end
end

function ENT:Think()
	if SERVER then
		-- Keep base pickup timers/activation behavior.
		if self.BaseClass and self.BaseClass.Think then
			self.BaseClass.Think(self)
		end

		-- Failsafe pickup for cases where trigger touches are unreliable.
		for _, ent in ipairs(ents.FindInSphere(self:GetPos() + Vector(0, 0, 32), 82)) do
			if IsValid(ent) and ent:IsPlayer() and self:CanPickup(ent) and ent ~= self:GetOwner() then
				self:PlayerTouched(ent)
				break
			end
		end

		self:NextThink(CurTime() + 0.05)
		return true
	end
end

function ENT:CanPickup(ply)
	return IsValid(ply) and ply:IsTFPlayer() and ply:Alive()
end

function ENT:DropWithGravity(vel)
	self:SetMoveType(MOVETYPE_FLYGRAVITY)
	self:SetMoveCollide(MOVECOLLIDE_FLY_BOUNCE)
	self:SetVelocity(vel)
	self:EmitSound("Halloween.PumpkinDrop", 85, 130)
end

function ENT:PhysicsCollide(data, phys)
	if data.Speed > 20 and data.DeltaTime > 0.1 then
		self:EmitSound("Halloween.PumpkinDrop", 65, 145)
	end
end

function ENT:Hide()
	self:Remove()
end

function ENT:PlayerTouched(pl)
	local pickupPos = self:GetPos()

	if SERVER and self.MapGargoyle then
		self.GargoyleCollected = true
		if GAMEMODE and GAMEMODE.AnnounceHalloweenGargoyle then
			GAMEMODE:AnnounceHalloweenGargoyle("got", "Someone found the Soul Gargoyle!")
		end
	end

	if SERVER then
		net.Start("TF_HalloweenSoulBurst")
		net.WriteEntity(pl)
		net.WriteVector(pickupPos)
		net.Broadcast()
	end

	self:EmitSound("Halloween.spell_pickup", 70, 125)
	self:EmitSound("Halloween.spell_pickup_rare", 68, 128)
	if IsValid(pl) then
		local soulReceive = "player/souls_receive" .. math.random(1, 3) .. ".wav"
		pl:EmitSound(soulReceive, 75, math.random(98, 105), 1, CHAN_STATIC)
	end
	self:Hide()

	if not IsValid(pl) or not pl:IsPlayer() then return end
	pl:SetNWInt("HalloweenSouls", pl:GetNWInt("HalloweenSouls", 0) + 1)
end

if CLIENT then
	ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

	local soulMat = Material("sprites/light_glow02_add")
	local coreMat = Material("sprites/physg_glow1")
	local soulColor = Color(120, 255, 140, 190)
	local coreColor = Color(150, 255, 170, 220)

	function ENT:Draw()
		-- Keep animations flowing without relying on AutomaticFrameAdvance.
		if self.LastDrawn then
			self:FrameAdvance(CurTime() - self.LastDrawn)
		end
		self.LastDrawn = CurTime()

		self:DrawModel()

		local center = self:GetPos() + Vector(0, 0, 42)
		local t = CurTime() * 1.8 + (self:EntIndex() * 0.37)

		render.SetMaterial(coreMat)
		render.DrawSprite(center, 20, 20, coreColor)

		render.SetMaterial(soulMat)
		for i = 1, 6 do
			local phase = t + (i * math.pi * 2 / 6)
			local radius = 11 + math.sin(t * 1.65 + i) * 4
			local wispPos = center + Vector(
				math.cos(phase) * radius,
				math.sin(phase) * radius,
				math.sin((t * 2.4) + (i * 1.7)) * 8
			)
			local size = 6 + math.sin((t * 3.2) + (i * 1.8)) * 2
			render.DrawSprite(wispPos, size, size * 1.4, soulColor)
		end

	end
end

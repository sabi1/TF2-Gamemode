include("shared.lua")

local CLIENT_RUNE_MODELS = {
	[TF_RUNE_STRENGTH] = "models/pickups/pickup_powerup_strength.mdl",
	[TF_RUNE_HASTE] = "models/pickups/pickup_powerup_haste.mdl",
	[TF_RUNE_REGEN] = "models/pickups/pickup_powerup_regen.mdl",
	[TF_RUNE_RESIST] = "models/pickups/pickup_powerup_defense.mdl",
	[TF_RUNE_VAMPIRE] = "models/pickups/pickup_powerup_vampire.mdl",
	[TF_RUNE_REFLECT] = "models/pickups/pickup_powerup_reflect.mdl",
	[TF_RUNE_PRECISION] = "models/pickups/pickup_powerup_precision.mdl",
	[TF_RUNE_AGILITY] = "models/pickups/pickup_powerup_agility.mdl",
	[TF_RUNE_KNOCKOUT] = "models/pickups/pickup_powerup_knockout.mdl",
	[TF_RUNE_KING] = "models/pickups/pickup_powerup_king.mdl",
	[TF_RUNE_PLAGUE] = "models/pickups/pickup_powerup_plague.mdl",
	[TF_RUNE_SUPERNOVA] = "models/pickups/pickup_powerup_supernova.mdl",
}

ENT.RenderGroup = RENDERGROUP_BOTH
ENT.AutomaticFrameAdvance = true

local function resetRuneSpinSequence(ent)
	if not IsValid(ent) then return end
	local seq = ent:LookupSequence("spin")
	if not seq or seq < 0 then
		seq = ent:LookupSequence("idle")
	end
	if seq and seq >= 0 then
		ent:ResetSequence(seq)
		ent:SetPlaybackRate(1)
		ent:SetCycle(0)
	end
end

function ENT:Initialize()
	local runeType = tonumber(self:GetNWInt("TFRuneType", TF_RUNE_STRENGTH)) or TF_RUNE_STRENGTH
	local model = CLIENT_RUNE_MODELS[runeType] or CLIENT_RUNE_MODELS[TF_RUNE_STRENGTH]
	if model and self:GetModel() ~= model then
		self:SetModel(model)
	end
	resetRuneSpinSequence(self)
end

function ENT:Think()
	local runeType = tonumber(self:GetNWInt("TFRuneType", TF_RUNE_STRENGTH)) or TF_RUNE_STRENGTH
	local model = CLIENT_RUNE_MODELS[runeType] or CLIENT_RUNE_MODELS[TF_RUNE_STRENGTH]
	if model and self:GetModel() ~= model then
		self:SetModel(model)
		resetRuneSpinSequence(self)
	end
end

function ENT:Draw()
	if self.LastDrawnAt then
		self:FrameAdvance(CurTime() - self.LastDrawnAt)
	end
	self.LastDrawnAt = CurTime()
	self:DrawModel()
end

function ENT:DrawTranslucent()
	self:Draw()
end

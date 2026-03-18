ENT.PrintName = "Mannpower Rune"
ENT.Author = "TF2-Gamemode"
ENT.Spawnable = false
ENT.AdminSpawnable = true

ENT.Type = "anim"
ENT.Base = "item_base"
ENT.Model = "models/pickups/pickup_powerup_strength.mdl"
ENT.RespawnTime = 90

local RUNE_DEFS = {
	[TF_RUNE_STRENGTH] = {
		model = "models/pickups/pickup_powerup_strength.mdl",
		sound = "Powerup.PickUpStrength",
		token = "#TF_Powerup_Pickup_Strength",
	},
	[TF_RUNE_HASTE] = {
		model = "models/pickups/pickup_powerup_haste.mdl",
		sound = "Powerup.PickUpHaste",
		token = "#TF_Powerup_Pickup_Haste",
	},
	[TF_RUNE_REGEN] = {
		model = "models/pickups/pickup_powerup_regen.mdl",
		sound = "Powerup.PickUpRegeneration",
		token = "#TF_Powerup_Pickup_Regen",
	},
	[TF_RUNE_RESIST] = {
		model = "models/pickups/pickup_powerup_defense.mdl",
		sound = "Powerup.PickUpResistance",
		token = "#TF_Powerup_Pickup_Resist",
	},
	[TF_RUNE_VAMPIRE] = {
		model = "models/pickups/pickup_powerup_vampire.mdl",
		sound = "Powerup.PickUpVampire",
		token = "#TF_Powerup_Pickup_Vampire",
	},
	[TF_RUNE_REFLECT] = {
		model = "models/pickups/pickup_powerup_reflect.mdl",
		sound = "Powerup.PickUpReflect",
		token = "#TF_Powerup_Pickup_Reflect",
	},
	[TF_RUNE_PRECISION] = {
		model = "models/pickups/pickup_powerup_precision.mdl",
		sound = "Powerup.PickUpPrecision",
		token = "#TF_Powerup_Pickup_Precision",
	},
	[TF_RUNE_AGILITY] = {
		model = "models/pickups/pickup_powerup_agility.mdl",
		sound = "Powerup.PickUpAgility",
		token = "#TF_Powerup_Pickup_Agility",
	},
	[TF_RUNE_KNOCKOUT] = {
		model = "models/pickups/pickup_powerup_knockout.mdl",
		sound = "Powerup.PickUpKnockout",
		token = "#TF_Powerup_Pickup_Knockout",
	},
	[TF_RUNE_KING] = {
		model = "models/pickups/pickup_powerup_king.mdl",
		sound = "Powerup.PickUpKing",
		token = "#TF_Powerup_Pickup_King",
	},
	[TF_RUNE_PLAGUE] = {
		model = "models/pickups/pickup_powerup_plague.mdl",
		sound = "Powerup.PickUpPlague",
		token = "#TF_Powerup_Pickup_Plague",
	},
	[TF_RUNE_SUPERNOVA] = {
		model = "models/pickups/pickup_powerup_supernova.mdl",
		sound = "Powerup.PickUpSupernova",
		token = "#TF_Powerup_Pickup_Supernova",
	},
}

function TF_GetMannpowerRuneDefs()
	return RUNE_DEFS
end

local function localize_rune_pickup(token, fallback)
	if tf_lang and tf_lang.GetRaw then
		local text = tf_lang.GetRaw(token, true)
		if isstring(text) and text ~= "" and text ~= token then
			return text
		end
	end
	return fallback
end

function ENT:Initialize()
	self.RuneType = self.RuneType or TF_RUNE_STRENGTH
	self.BaseClass.Initialize(self)
	self:SetRuneType(self.RuneType)
end

function ENT:KeyValue(key, value)
	if string.Left(key, 2) == "On" then
		self:StoreOutput(key, value)
		return
	end

	key = string.lower(tostring(key or ""))
	if key == "runetype" then
		self.RuneType = tonumber(value) or TF_RUNE_STRENGTH
		return
	end

	self.BaseClass.KeyValue(self, key, value)
end

function ENT:SetRuneType(runeType)
	runeType = tonumber(runeType) or TF_RUNE_STRENGTH
	self.RuneType = runeType

	local def = RUNE_DEFS[runeType] or RUNE_DEFS[TF_RUNE_STRENGTH]
	self.Model = def.model
	self:SetModel(def.model)
end

function ENT:CanPickup(ply)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
	if not TF_IsMannpowerMode or not TF_IsMannpowerMode() then return false end
	if ply:IsTaunting() then return false end
	if ply:InCond(TF_COND_RUNE_IMBALANCE) then return false end
	if ply:IsCarryingRune and ply:IsCarryingRune() then return false end
	return true
end

function ENT:PlayerTouched(pl)
	local runeType = self.RuneType or TF_RUNE_STRENGTH
	if pl.SetCarryingRuneType then
		pl:SetCarryingRuneType(runeType)
	end

	local def = RUNE_DEFS[runeType] or RUNE_DEFS[TF_RUNE_STRENGTH]
	if def.sound then
		pl:EmitSound(def.sound, 75, 100)
	end

	local centerText = localize_rune_pickup(def.token, "You got a powerup rune!")
	pl:PrintMessage(HUD_PRINTCENTER, centerText)

	self:SetOwner(pl)
	self:TriggerOutput("OnPlayerTouch", pl)
	self:Hide()
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self:Show()
		return true
	elseif name == "disable" then
		self:SetTrigger(false)
		self:SetNoDraw(true)
		self:DrawShadow(false)
		return true
	elseif name == "setrunetype" then
		self:SetRuneType(tonumber(data) or TF_RUNE_STRENGTH)
		return true
	end
	return false
end

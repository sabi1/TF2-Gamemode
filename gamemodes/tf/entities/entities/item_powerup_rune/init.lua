if SERVER then
	AddCSLuaFile("shared.lua")
	AddCSLuaFile("cl_init.lua")
end

ENT.PrintName = "Mannpower Rune"
ENT.Author = "TF2-Gamemode"
ENT.Spawnable = true
ENT.AdminSpawnable = true

ENT.Type = "anim"
ENT.Base = "item_base"
ENT.Model = "models/pickups/pickup_powerup_strength.mdl"
ENT.RespawnTime = -1

local RUNE_BLINK_TIME = 10
local RUNE_TOSS_SPEED = 350
local RUNE_REST_SPEED_SQR = 16

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

local function playerIsTaunting(ply)
	return ply.IsTaunting and ply:IsTaunting() or false
end

local function playerInvisibleEnoughToBlockRune(ply)
	if not IsValid(ply) then return false end
	if ply.IsStealthed and ply:IsStealthed() then
		return true
	end
	if isnumber(TF_COND_STEALTHED_BLINK) and ply.InCond and ply:InCond(TF_COND_STEALTHED_BLINK) then
		return true
	end
	return ply.GetPercentInvisible and ply:GetPercentInvisible() > 0.25 or false
end

local function playerCanTakeTeamRune(ply, runeTeam)
	if runeTeam == TEAM_ANY or runeTeam == TEAM_UNASSIGNED or runeTeam == TEAM_SPECTATOR then
		return true
	end
	if ply:Team() == runeTeam then
		return true
	end
	if ply.GetPlayerClass and ply:GetPlayerClass() == "spy" and ply.GetDisguiseTeam and ply:GetDisguiseTeam() == runeTeam then
		return true
	end
	return false
end

local function getRuneRepositionTime(runeTeam)
	if runeTeam ~= TEAM_ANY and runeTeam ~= TEAM_UNASSIGNED and runeTeam ~= TEAM_SPECTATOR then
		return 30
	end
	return 60
end

local function pointInsideBrushEntity(ent, pos)
	if not IsValid(ent) or not isvector(pos) then return false end
	local mins, maxs = ent:WorldSpaceAABB()
	return pos:WithinAABox(mins, maxs)
end

local function findTriggerHurtAtPos(pos)
	for _, hurt in ipairs(ents.FindByClass("trigger_hurt")) do
		if IsValid(hurt) and pointInsideBrushEntity(hurt, pos) then
			return hurt
		end
	end
	return nil
end

local function getEntityWaterLevel(ent)
	if not IsValid(ent) then return 0 end
	if ent.GetWaterLevel then
		local ok, level = pcall(ent.GetWaterLevel, ent)
		if ok and isnumber(level) then
			return level
		end
	end
	if ent.WaterLevel then
		local ok, level = pcall(ent.WaterLevel, ent)
		if ok and isnumber(level) then
			return level
		end
	end
	return 0
end

local function chooseAvailablePowerupSpawn(runeTeam)
	local preferred = {}
	local fallback = {}

	for _, spawn in ipairs(ents.FindByClass("info_powerup_spawn")) do
		if not IsValid(spawn) or spawn.Disabled or IsValid(spawn.ActiveRune) then
			continue
		end

		fallback[#fallback + 1] = spawn
		if runeTeam ~= TEAM_UNASSIGNED and runeTeam ~= TEAM_SPECTATOR and spawn.TeamNum == runeTeam then
			preferred[#preferred + 1] = spawn
		end
	end

	local pool = #preferred > 0 and preferred or fallback
	if #pool == 0 then return nil end
	return pool[math.random(#pool)]
end

local function spawnRuneAtPowerupSpawn(runeType, runeTeam)
	local spawn = chooseAvailablePowerupSpawn(runeTeam or TEAM_ANY or TEAM_UNASSIGNED)
	if not IsValid(spawn) then return nil end

	local replacement = ents.Create("item_powerup_rune")
	if not IsValid(replacement) then return nil end

	replacement:SetPos(spawn:GetPos() + Vector(0, 0, 48))
	replacement:SetAngles(Angle(0, 0, 0))
	replacement.ApplyForce = false
	replacement.ShouldReposition = false
	replacement.TeamNum = TEAM_ANY or TEAM_UNASSIGNED
	replacement:Spawn()
	replacement:Activate()
	replacement:SetRuneType(runeType or TF_RUNE_STRENGTH)
	replacement.SpawnPoint = spawn
	spawn.ActiveRune = replacement

	return replacement
end

function TF_RepositionMannpowerRune(runeType, runeTeam)
	if not TF_IsMannpowerMode or not TF_IsMannpowerMode() then return nil end
	return spawnRuneAtPowerupSpawn(runeType, runeTeam)
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
	self:SetNWInt("TFRuneType", self.RuneType)
	self.TeamNum = self.TeamNum or TEAM_ANY or TEAM_UNASSIGNED
	self.ApplyForce = self.ApplyForce == true
	self.ShouldReposition = self.ShouldReposition == true
	self.SpawnDirection = self.SpawnDirection or Vector(0, 0, 1)
	self.BlinkCount = 0
	self:ApplyTeamSkin()
	self:SetMoveCollide(MOVECOLLIDE_FLY_BOUNCE)
	self:SetSolid(SOLID_BBOX)
	self:SetTrigger(true)
	self:SetNotSolid(false)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	self:SetRenderMode(RENDERMODE_TRANSCOLOR)

	if self.ApplyForce then
		self:LaunchRune(self.SpawnDirection)
	else
		self:SetMoveType(MOVETYPE_NONE)
	end

	if self.ShouldReposition then
		local repositionTime = getRuneRepositionTime(self.TeamNum)
		self.BlinkStartTime = CurTime() + repositionTime
		self.KillTime = self.BlinkStartTime + RUNE_BLINK_TIME
	else
		self.BlinkStartTime = nil
		self.KillTime = nil
	end

	resetRuneSpinSequence(self)
end

function ENT:SpawnFunction(ply, tr, className)
	if not tr.Hit then return end

	local ent = ents.Create(className or "item_powerup_rune")
	if not IsValid(ent) then return end

	ent:SetPos(tr.HitPos + tr.HitNormal * 24)
	ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
	ent.TeamNum = TEAM_UNASSIGNED
	ent.RuneType = TF_RUNE_STRENGTH
	ent:Spawn()
	ent:Activate()

	return ent
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
	elseif key == "team" then
		local teamNum = tonumber(value)
		if teamNum == 2 then
			self.TeamNum = TEAM_RED
		elseif teamNum == 3 then
			self.TeamNum = TEAM_BLU
		else
			self.TeamNum = TEAM_UNASSIGNED
		end
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
	self:SetNWInt("TFRuneType", runeType)
	resetRuneSpinSequence(self)
end

function ENT:ApplyTeamSkin()
	if self.TeamNum == TEAM_RED then
		self:SetSkin(1)
	elseif self.TeamNum == TEAM_BLU then
		self:SetSkin(2)
	else
		self:SetSkin(0)
	end
end

function ENT:LaunchRune(direction)
	local dir = isvector(direction) and Vector(direction.x, direction.y, direction.z) or Vector(0, 0, 1)
	dir.z = 0.7
	if dir:LengthSqr() <= 0 then
		dir = Vector(0, 0, 1)
	end
	dir:Normalize()

	self.SpawnDirection = dir
	self:SetMoveType(MOVETYPE_FLYGRAVITY)
	self:SetMoveCollide(MOVECOLLIDE_FLY_BOUNCE)
	self:SetVelocity(dir * RUNE_TOSS_SPEED)
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:CanPickup(ply)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
	if not TF_IsMannpowerMode or not TF_IsMannpowerMode() then return false end
	if playerIsTaunting(ply) then return false end
	if playerInvisibleEnoughToBlockRune(ply) then return false end
	if ply:InCond(TF_COND_RUNE_IMBALANCE) then return false end
	if ply.IsCarryingRune and ply:IsCarryingRune() then
		local denyText = tf_lang and tf_lang.GetRaw and tf_lang.GetRaw("#TF_Powerup_Pickup_Deny", true) or "You already have a powerup rune."
		ply:PrintMessage(HUD_PRINTCENTER, denyText)
		return false
	end
	if ply:GetNWBool("InRespawnRoom", false) then return false end
	if not playerCanTakeTeamRune(ply, self.TeamNum or TEAM_UNASSIGNED) then return false end
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
	self:Remove()
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
	elseif name == "setteam" then
		local raw = tonumber(data)
		if raw == 2 then
			self.TeamNum = TEAM_RED
		elseif raw == 3 then
			self.TeamNum = TEAM_BLU
		elseif raw ~= nil then
			self.TeamNum = raw
		else
			self.TeamNum = TEAM_ANY or TEAM_UNASSIGNED
		end
		self:ApplyTeamSkin()
		return true
	end
	return false
end

function ENT:RepositionToPowerupSpawn()
	if not TF_IsMannpowerMode or not TF_IsMannpowerMode() then return false end

	local replacement = spawnRuneAtPowerupSpawn(self.RuneType or TF_RUNE_STRENGTH, self.TeamNum or TEAM_UNASSIGNED)
	if not IsValid(replacement) then return false end

	self:Remove()
	return true
end

function ENT:Think()
	self.BaseClass.Think(self)

	if not TF_IsMannpowerMode or not TF_IsMannpowerMode() then return end
	if not self.NextActive and IsValid(self:GetOwner()) then
		self:SetOwner(NULL)
	end
	if IsValid(self:GetOwner()) then return end

	if self.KillTime and CurTime() >= self.KillTime then
		self:RepositionToPowerupSpawn()
		return
	end

	if self.BlinkStartTime and CurTime() >= self.BlinkStartTime then
		local timeToKill = math.max(self.KillTime - CurTime(), 0)
		local blinkInterval = math.Clamp(timeToKill / RUNE_BLINK_TIME * 0.4 + 0.1, 0.1, 0.5)
		if not self.NextBlinkAt or CurTime() >= self.NextBlinkAt then
			self.BlinkCount = (self.BlinkCount or 0) + 1
			self:SetColor(Color(255, 255, 255, (self.BlinkCount % 2 == 0) and 25 or 255))
			self.NextBlinkAt = CurTime() + blinkInterval
		end
	end

	if self:GetMoveType() == MOVETYPE_FLYGRAVITY then
		if self:GetPos().z <= -16384 then
			self:RepositionToPowerupSpawn()
			return
		end

		if self:GetVelocity():LengthSqr() <= RUNE_REST_SPEED_SQR then
			self:SetMoveType(MOVETYPE_NONE)
			if getEntityWaterLevel(self) >= 3 or IsValid(findTriggerHurtAtPos(self:GetPos())) then
				self:RepositionToPowerupSpawn()
				return
			end
			for _, room in ipairs(ents.FindByClass("func_respawnroom")) do
				if IsValid(room) and pointInsideBrushEntity(room, self:GetPos()) then
					self:RepositionToPowerupSpawn()
					return
				end
			end
		end
	end
end

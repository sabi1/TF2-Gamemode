if SERVER then
	AddCSLuaFile()
end

ENT.Base = "base_nextbot"
ENT.Type = "nextbot"
ENT.PrintName = "TFBot Base NextBot"
ENT.Category = "TFBots"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.IsTFBotValveBase = true
ENT.TFBot = true

local CLASS_TO_MODEL = {
	scout = "models/bots/scout/bot_scout.mdl",
	soldier = "models/bots/soldier/bot_soldier.mdl",
	pyro = "models/bots/pyro/bot_pyro.mdl",
	demoman = "models/bots/demo/bot_demo.mdl",
	demo = "models/bots/demo/bot_demo.mdl",
	heavy = "models/bots/heavy/bot_heavy.mdl",
	heavyweapons = "models/bots/heavy/bot_heavy.mdl",
	engineer = "models/bots/engineer/bot_engineer.mdl",
	medic = "models/bots/medic/bot_medic.mdl",
	sniper = "models/bots/sniper/bot_sniper.mdl",
	spy = "models/bots/spy/bot_spy.mdl",
	sentrybuster = "models/bots/demo/bot_sentry_buster.mdl",
}

local CLASS_LOADOUTS = {
	scout = {
		{ class = "tf_weapon_scattergun", slot = 0, IsPrimaryWeapon = true, IsProjectileWeapon = false, damage = 8, fireRate = 0.14, range = 900 },
		{ class = "tf_weapon_pistol_scout", slot = 1, IsSecondaryWeapon = true, IsProjectileWeapon = false, damage = 6, fireRate = 0.12, range = 1100 },
		{ class = "tf_weapon_bat", slot = 2, IsMeleeWeapon = true, damage = 45, fireRate = 0.45, range = 95 },
	},
	soldier = {
		{ class = "tf_weapon_rocketlauncher", slot = 0, IsPrimaryWeapon = true, IsProjectileWeapon = true, damage = 90, fireRate = 0.8, range = 2000 },
		{ class = "tf_weapon_shotgun_soldier", slot = 1, IsSecondaryWeapon = true, IsProjectileWeapon = false, damage = 6, fireRate = 0.18, range = 800 },
		{ class = "tf_weapon_shovel", slot = 2, IsMeleeWeapon = true, damage = 65, fireRate = 0.6, range = 100 },
	},
	pyro = {
		{ class = "tf_weapon_flamethrower", slot = 0, IsPrimaryWeapon = true, IsProjectileWeapon = false, damage = 5, fireRate = 0.08, range = 280 },
		{ class = "tf_weapon_shotgun_pyro", slot = 1, IsSecondaryWeapon = true, IsProjectileWeapon = false, damage = 6, fireRate = 0.18, range = 800 },
		{ class = "tf_weapon_fireaxe", slot = 2, IsMeleeWeapon = true, damage = 65, fireRate = 0.6, range = 100 },
	},
	demoman = {
		{ class = "tf_weapon_grenadelauncher", slot = 0, IsPrimaryWeapon = true, IsProjectileWeapon = true, damage = 95, fireRate = 0.65, range = 1800 },
		{ class = "tf_weapon_pipebomblauncher", slot = 1, IsSecondaryWeapon = true, IsProjectileWeapon = true, damage = 110, fireRate = 0.8, range = 1400 },
		{ class = "tf_weapon_bottle", slot = 2, IsMeleeWeapon = true, damage = 65, fireRate = 0.6, range = 100 },
	},
	heavy = {
		{ class = "tf_weapon_minigun", slot = 0, IsPrimaryWeapon = true, IsProjectileWeapon = false, damage = 6, fireRate = 0.1, range = 1000 },
		{ class = "tf_weapon_shotgun_hwg", slot = 1, IsSecondaryWeapon = true, IsProjectileWeapon = false, damage = 6, fireRate = 0.2, range = 850 },
		{ class = "tf_weapon_fists", slot = 2, IsMeleeWeapon = true, damage = 65, fireRate = 0.6, range = 95 },
	},
	engineer = {
		{ class = "tf_weapon_shotgun_primary", slot = 0, IsPrimaryWeapon = true, IsProjectileWeapon = false, damage = 6, fireRate = 0.2, range = 850 },
		{ class = "tf_weapon_pistol", slot = 1, IsSecondaryWeapon = true, IsProjectileWeapon = false, damage = 6, fireRate = 0.12, range = 1100 },
		{ class = "tf_weapon_wrench", slot = 2, IsMeleeWeapon = true, damage = 65, fireRate = 0.6, range = 95 },
	},
	medic = {
		{ class = "tf_weapon_syringegun_medic", slot = 0, IsPrimaryWeapon = true, IsProjectileWeapon = true, damage = 11, fireRate = 0.14, range = 1200 },
		{ class = "tf_weapon_medigun", slot = 1, IsSecondaryWeapon = true, IsProjectileWeapon = false, damage = 0, fireRate = 0.2, range = 550 },
		{ class = "tf_weapon_bonesaw", slot = 2, IsMeleeWeapon = true, damage = 65, fireRate = 0.6, range = 95 },
	},
	sniper = {
		{ class = "tf_weapon_sniperrifle", slot = 0, IsPrimaryWeapon = true, IsProjectileWeapon = false, ZoomStatus = true, damage = 50, fireRate = 1.2, range = 4000 },
		{ class = "tf_weapon_smg", slot = 1, IsSecondaryWeapon = true, IsProjectileWeapon = false, damage = 8, fireRate = 0.1, range = 1200 },
		{ class = "tf_weapon_club", slot = 2, IsMeleeWeapon = true, damage = 65, fireRate = 0.6, range = 95 },
	},
	spy = {
		{ class = "tf_weapon_revolver", slot = 0, IsPrimaryWeapon = true, IsProjectileWeapon = false, damage = 34, fireRate = 0.5, range = 1300 },
		{ class = "tf_weapon_invis", slot = 1, IsSecondaryWeapon = true, IsProjectileWeapon = false, damage = 0, fireRate = 0.2, range = 0 },
		{ class = "tf_weapon_knife", slot = 2, IsMeleeWeapon = true, damage = 40, fireRate = 0.5, range = 95 },
	},
	sentrybuster = {
		{ class = "tf_weapon_stickbomb", slot = 2, IsMeleeWeapon = true, damage = 500, fireRate = 1.0, range = 140 },
	},
}

local WEAPON_WORLD_MODEL_BY_CLASS = {
	tf_weapon_scattergun = "models/weapons/c_models/c_scattergun/c_scattergun.mdl",
	tf_weapon_rocketlauncher = "models/weapons/c_models/c_rocketlauncher/c_rocketlauncher.mdl",
	tf_weapon_flamethrower = "models/weapons/c_models/c_flamethrower/c_flamethrower.mdl",
	tf_weapon_grenadelauncher = "models/weapons/c_models/c_grenadelauncher/c_grenadelauncher.mdl",
	tf_weapon_minigun = "models/weapons/c_models/c_minigun/c_minigun.mdl",
	tf_weapon_shotgun_primary = "models/weapons/c_models/c_shotgun/c_shotgun.mdl",
	tf_weapon_syringegun_medic = "models/weapons/c_models/c_syringegun/c_syringegun.mdl",
	tf_weapon_sniperrifle = "models/weapons/c_models/c_sniperrifle/c_sniperrifle.mdl",
	tf_weapon_revolver = "models/weapons/c_models/c_revolver/c_revolver.mdl",
	tf_weapon_bat = "models/weapons/c_models/c_bat/c_bat.mdl",
	tf_weapon_knife = "models/weapons/c_models/c_knife/c_knife.mdl",
	tf_weapon_wrench = "models/weapons/c_models/c_wrench/c_wrench.mdl",
}

local CLASS_WEARABLE_MODEL = {
	scout = "models/player/items/mvm_loot/scout/robo_cap.mdl",
	soldier = "models/player/items/mvm_loot/soldier/robot_helmet.mdl",
	pyro = "models/player/items/mvm_loot/pyro/pyrobo_backpack.mdl",
	demoman = "models/player/items/mvm_loot/demo/battery_grenade.mdl",
	heavy = "models/player/items/mvm_loot/heavy/robo_ushanka.mdl",
	engineer = "models/player/items/mvm_loot/engineer/robo_engy_hat.mdl",
	medic = "models/player/items/mvm_loot/medic/robo_backpack.mdl",
	sniper = "models/player/items/mvm_loot/sniper/robo_sniper_hat.mdl",
	spy = "models/player/items/mvm_loot/spy/robo_fedora.mdl",
}

local function normalizeClassToken(className)
	local c = string.lower(tostring(className or "scout"))
	if c == "heavyweapons" then return "heavy" end
	if c == "demo" then return "demoman" end
	return c
end

local function deepCopyLoadout(list)
	local out = {}
	for _, v in ipairs(list or {}) do
		out[#out + 1] = table.Copy(v)
	end
	return out
end

local function normalizeItemToken(text)
	local s = string.lower(string.Trim(tostring(text or "")))
	s = string.gsub(s, "^the%s+", "")
	s = string.gsub(s, "^tf_weapon_", "")
	s = string.gsub(s, "[^%w]", "")
	return s
end

local ITEM_TO_WEAPON_CLASS = {
	scattergun = "tf_weapon_scattergun",
	forceanature = "tf_weapon_scattergun",
	shortstop = "tf_weapon_scattergun",
	rocketlauncher = "tf_weapon_rocketlauncher",
	directhit = "tf_weapon_rocketlauncher",
	flamethrower = "tf_weapon_flamethrower",
	degreaser = "tf_weapon_flamethrower",
	grenadelauncher = "tf_weapon_grenadelauncher",
	stickybomblauncher = "tf_weapon_pipebomblauncher",
	minigun = "tf_weapon_minigun",
	shotgun = "tf_weapon_shotgun_primary",
	pistol = "tf_weapon_pistol",
	syringegun = "tf_weapon_syringegun_medic",
	medigun = "tf_weapon_medigun",
	sniperrifle = "tf_weapon_sniperrifle",
	revolver = "tf_weapon_revolver",
	knife = "tf_weapon_knife",
	bat = "tf_weapon_bat",
	bonesaw = "tf_weapon_bonesaw",
	wrench = "tf_weapon_wrench",
	fists = "tf_weapon_fists",
}

local function classFromItemToken(token)
	if token == "" then return nil end
	if string.find(token, "medigun", 1, true) then return "tf_weapon_medigun" end
	if string.find(token, "sniper", 1, true) and string.find(token, "rifle", 1, true) then return "tf_weapon_sniperrifle" end
	if string.find(token, "rocket", 1, true) then return "tf_weapon_rocketlauncher" end
	if string.find(token, "flame", 1, true) then return "tf_weapon_flamethrower" end
	if string.find(token, "grenade", 1, true) or string.find(token, "pipe", 1, true) then return "tf_weapon_grenadelauncher" end
	if string.find(token, "sticky", 1, true) then return "tf_weapon_pipebomblauncher" end
	if string.find(token, "mini", 1, true) then return "tf_weapon_minigun" end
	if string.find(token, "revolver", 1, true) then return "tf_weapon_revolver" end
	if string.find(token, "knife", 1, true) then return "tf_weapon_knife" end
	if string.find(token, "wrench", 1, true) then return "tf_weapon_wrench" end
	if string.find(token, "bat", 1, true) then return "tf_weapon_bat" end
	if string.find(token, "pistol", 1, true) then return "tf_weapon_pistol" end
	if string.find(token, "shotgun", 1, true) then return "tf_weapon_shotgun_primary" end
	return ITEM_TO_WEAPON_CLASS[token]
end

local function detectSlotForWeapon(className)
	className = string.lower(tostring(className or ""))
	if className == "tf_weapon_medigun" then return 1 end
	if string.find(className, "knife", 1, true) or string.find(className, "wrench", 1, true) or string.find(className, "bat", 1, true) or string.find(className, "fists", 1, true) or string.find(className, "shovel", 1, true) or string.find(className, "bottle", 1, true) or string.find(className, "club", 1, true) or string.find(className, "bonesaw", 1, true) then
		return 2
	end
	if string.find(className, "pistol", 1, true) or string.find(className, "smg", 1, true) or string.find(className, "shotgun", 1, true) or string.find(className, "invis", 1, true) then
		return 1
	end
	return 0
end

local function makeWeaponEntry(className)
	local slot = detectSlotForWeapon(className)
	return {
		__isFakeWeapon = true,
		class = className,
		slot = slot,
		IsMeleeWeapon = slot == 2,
		IsSecondaryWeapon = slot == 1,
		IsPrimaryWeapon = slot == 0,
		IsProjectileWeapon = string.find(className, "rocket", 1, true) ~= nil or string.find(className, "grenade", 1, true) ~= nil or string.find(className, "pipe", 1, true) ~= nil or string.find(className, "syringe", 1, true) ~= nil,
		ZoomStatus = string.find(className, "sniperrifle", 1, true) ~= nil,
		damage = (slot == 2) and 65 or 12,
		fireRate = (slot == 2) and 0.55 or 0.2,
		range = (slot == 2) and 95 or 1100,
		GetClass = function(self) return self.class end,
		GetSlot = function(self) return self.slot end,
	}
end

local function pickModelForClass(className, isMiniBoss)
	local cls = normalizeClassToken(className)
	if isMiniBoss and cls ~= "engineer" and cls ~= "medic" and cls ~= "sniper" and cls ~= "spy" and cls ~= "sentrybuster" then
		local bossAlias = (cls == "demoman") and "demo" or cls
		local bossModel = "models/bots/" .. bossAlias .. "_boss/bot_" .. bossAlias .. "_boss.mdl"
		if util.IsValidModel(bossModel) then
			return bossModel
		end
	end
	local m = CLASS_TO_MODEL[cls] or CLASS_TO_MODEL.scout
	if util.IsValidModel(m) then
		return m
	end
	return "models/player/scout.mdl"
end

local RUN_ACTS = {
	ACT_MP_RUN_PRIMARY,
	ACT_MP_RUN_MELEE,
	ACT_RUN,
	ACT_HL2MP_RUN,
}

local IDLE_ACTS = {
	ACT_MP_STAND_PRIMARY,
	ACT_MP_STAND_MELEE,
	ACT_IDLE,
	ACT_HL2MP_IDLE,
}

local function startBestActivity(ent, acts)
	for _, act in ipairs(acts) do
		if not act then continue end
		local seq = ent:SelectWeightedSequence(act)
		if isnumber(seq) and seq >= 0 then
			ent:StartActivity(act)
			return true
		end
	end
	return false
end

local TRIGGER_SCAN_INTERVAL = 0.12
local TRIGGER_CACHE_REFRESH = 1.0
local TRIGGER_EXTRA_CLASSES = {
	func_capturezone = true,
	func_flagdetectionzone = true,
	trigger_capture_area = true,
}
local g_triggerCache = g_triggerCache or { nextRefresh = 0, ents = {} }

local function isTriggerEntity(ent)
	if not IsValid(ent) then return false end
	local class = string.lower(tostring(ent:GetClass() or ""))
	if string.StartWith(class, "trigger_") then return true end
	return TRIGGER_EXTRA_CLASSES[class] == true
end

local function refreshTriggerCache(now)
	if now < (g_triggerCache.nextRefresh or 0) then
		return g_triggerCache.ents
	end
	g_triggerCache.nextRefresh = now + TRIGGER_CACHE_REFRESH
	local out = {}
	for _, ent in ipairs(ents.GetAll()) do
		if isTriggerEntity(ent) then
			out[#out + 1] = ent
		end
	end
	g_triggerCache.ents = out
	return out
end

local function pointInsideEntityOBB(ent, point)
	if not IsValid(ent) or not isvector(point) then return false end
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	local localPos = ent:WorldToLocal(point)
	return localPos.x >= mins.x and localPos.x <= maxs.x
		and localPos.y >= mins.y and localPos.y <= maxs.y
		and localPos.z >= mins.z and localPos.z <= maxs.z
end

function ENT:Initialize()
	if CLIENT then return end
	self:SetModel("models/bots/scout/bot_scout.mdl")
	self:SetHealth(125)
	self:SetMaxHealth(125)
	self:SetModelScale(1)
	self:SetSolid(SOLID_BBOX)
	self:SetMoveType(MOVETYPE_STEP)
	self:SetCollisionGroup(COLLISION_GROUP_PLAYER)
	self.loco:SetStepHeight(18)
	self.loco:SetAcceleration(900)
	self.loco:SetDeceleration(900)
	self.loco:SetDesiredSpeed(280)
	self._tfClass = "scout"
	self._tfTeam = TEAM_RED
	self._spawnTime = CurTime()
	self.routeType = "default"
	self:BuildDefaultClassLoadout()
	startBestActivity(self, IDLE_ACTS)
	self.ControllerBot = ents.Create("ctf_bot_navigator")
	if IsValid(self.ControllerBot) then
		self.ControllerBot:Spawn()
		self.ControllerBot:SetOwner(self)
	end
end

function ENT:OnRemove()
	if SERVER and IsValid(self.ControllerBot) then
		self.ControllerBot:Remove()
	end
	if SERVER and IsValid(self._weaponProp) then
		self._weaponProp:Remove()
	end
	if SERVER and IsValid(self._wearableProp) then
		self._wearableProp:Remove()
	end
end

function ENT:IsBot()
	return true
end

function ENT:Alive()
	return self:Health() > 0
end

function ENT:Team()
	return self._tfTeam or TEAM_RED
end

function ENT:SetTeam(teamId)
	self._tfTeam = tonumber(teamId) or TEAM_RED
	self:SetSkin((self:Team() == TEAM_BLU or self:Team() == TF_TEAM_PVE_INVADERS) and 1 or 0)
end

function ENT:IsFriendly(other)
	if not IsValid(other) then return false end
	if other.Team then
		return other:Team() == self:Team()
	end
	return false
end

function ENT:GetPlayerClass()
	return self._tfClass or "scout"
end

function ENT:SetPlayerClass(className)
	self._tfClass = string.lower(tostring(className or "scout"))
	self.playerclass = self._tfClass
	self:SetModel(pickModelForClass(self._tfClass, self:IsMiniBoss()))
	self:SetSkin((self:Team() == TEAM_BLU or self:Team() == TF_TEAM_PVE_INVADERS) and 1 or 0)
	self:BuildDefaultClassLoadout()
	self:RefreshWeaponAttachment()
	self:RefreshWearableAttachment()
end

function ENT:GetShootPos()
	return self:WorldSpaceCenter()
end

function ENT:GetSpawnTime()
	return self._spawnTime or CurTime()
end

function ENT:IsMiniBoss()
	return self.IsBoss == true or self.TF_MVM_MiniBoss == true
end

function ENT:SetEyeAngles(ang)
	if not isangle(ang) then return end
	self:SetAngles(Angle(0, ang.y, 0))
end

function ENT:Visible(target)
	if not IsValid(target) then return false end
	local tr = util.TraceLine({
		start = self:GetShootPos(),
		endpos = target.WorldSpaceCenter and target:WorldSpaceCenter() or target:GetPos(),
		filter = { self, self.ControllerBot },
		mask = MASK_SHOT,
	})
	return tr.Entity == target or not tr.Hit
end

function ENT:GetWeapons()
	return self._virtualWeapons or {}
end

function ENT:GetActiveWeapon()
	if istable(self._virtualWeapons) and istable(self._activeWeapon) then
		return self._activeWeapon
	end
	if istable(self._virtualWeapons) and self._virtualWeapons[1] then
		self._activeWeapon = self._virtualWeapons[1]
		return self._activeWeapon
	end
	return nil
end

function ENT:SelectWeapon(className)
	if not istable(self._virtualWeapons) then return false end
	className = string.lower(tostring(className or ""))
	for _, wep in ipairs(self._virtualWeapons) do
		local wc = string.lower(tostring((wep.GetClass and wep:GetClass()) or wep.class or ""))
		if wc == className then
			self._activeWeapon = wep
			self:RefreshWeaponAttachment()
			return true
		end
	end
	return false
end

function ENT:BuildDefaultClassLoadout()
	local cls = normalizeClassToken(self:GetPlayerClass())
	local base = CLASS_LOADOUTS[cls] or CLASS_LOADOUTS.scout
	self._virtualWeapons = deepCopyLoadout(base)
	for _, wep in ipairs(self._virtualWeapons) do
		wep.__isFakeWeapon = true
		wep.class = wep.class or "tf_weapon_scattergun"
		wep.slot = tonumber(wep.slot or detectSlotForWeapon(wep.class)) or 0
		wep.GetClass = wep.GetClass or function(self) return self.class end
		wep.GetSlot = wep.GetSlot or function(self) return self.slot end
	end
	self._activeWeapon = self._virtualWeapons[1]
end

function ENT:ApplyItemLoadout(items)
	if not istable(self._virtualWeapons) then
		self:BuildDefaultClassLoadout()
	end
	if not istable(items) then return end

	for _, raw in ipairs(items) do
		local token = normalizeItemToken(raw)
		local wc = classFromItemToken(token)
		if wc then
			local entry = makeWeaponEntry(wc)
			local replaced = false
			for i, existing in ipairs(self._virtualWeapons) do
				if tonumber(existing.slot) == tonumber(entry.slot) then
					self._virtualWeapons[i] = entry
					replaced = true
					break
				end
			end
			if not replaced then
				self._virtualWeapons[#self._virtualWeapons + 1] = entry
			end
		end
	end

	self._activeWeapon = self._virtualWeapons[1]
	self:RefreshWeaponAttachment()
end

function ENT:RefreshWeaponAttachment()
	local active = self:GetActiveWeapon()
	local weaponClass = active and ((active.GetClass and active:GetClass()) or active.class) or nil
	local model = WEAPON_WORLD_MODEL_BY_CLASS[string.lower(tostring(weaponClass or ""))]
	if not model or not util.IsValidModel(model) then
		if IsValid(self._weaponProp) then
			self._weaponProp:Remove()
			self._weaponProp = nil
		end
		return
	end

	if not IsValid(self._weaponProp) then
		local prop = ents.Create("prop_dynamic")
		if not IsValid(prop) then return end
		prop:SetModel(model)
		prop:SetSolid(SOLID_NONE)
		prop:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
		prop:SetOwner(self)
		prop:Spawn()
		prop:Activate()
		self._weaponProp = prop
	else
		self._weaponProp:SetModel(model)
	end

	local bone = self:LookupBone("bip_hand_r") or self:LookupBone("ValveBiped.Bip01_R_Hand")
	if bone and bone >= 0 then
		self._weaponProp:FollowBone(self, bone)
	end
	self._weaponProp:SetParent(self)
	self._weaponProp:SetLocalPos(Vector(4, 1, -2))
	self._weaponProp:SetLocalAngles(Angle(0, 0, 90))
end

function ENT:RefreshWearableAttachment()
	local cls = normalizeClassToken(self:GetPlayerClass())
	local model = CLASS_WEARABLE_MODEL[cls]
	if not model or not util.IsValidModel(model) then
		if IsValid(self._wearableProp) then
			self._wearableProp:Remove()
			self._wearableProp = nil
		end
		return
	end

	if not IsValid(self._wearableProp) then
		local prop = ents.Create("prop_dynamic")
		if not IsValid(prop) then return end
		prop:SetModel(model)
		prop:SetSolid(SOLID_NONE)
		prop:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
		prop:SetOwner(self)
		prop:Spawn()
		prop:Activate()
		self._wearableProp = prop
	else
		self._wearableProp:SetModel(model)
	end

	local bone = self:LookupBone("bip_head") or self:LookupBone("ValveBiped.Bip01_Head1")
	if bone and bone >= 0 then
		self._wearableProp:FollowBone(self, bone)
	end
	self._wearableProp:SetParent(self)
	self._wearableProp:SetLocalPos(Vector(0, 0, 0))
	self._wearableProp:SetLocalAngles(Angle(0, 0, 0))
end

function ENT:BodyUpdate()
	self:BodyMoveXY()
end

function ENT:GetSoftSeparationTarget(baseTarget)
	if not isvector(baseTarget) then return baseTarget end
	local away = Vector(0, 0, 0)
	local pos = self:GetPos()
	local radius = 64
	for _, other in ipairs(ents.FindInSphere(pos, radius)) do
		if other == self then continue end
		if not IsValid(other) then continue end
		local managed = (other.TFBot == true) or (other.IsTFBotValveBase == true)
		if not managed then continue end
		if self:IsFriendly(other) ~= true then continue end
		local diff = pos - other:GetPos()
		diff.z = 0
		local dist = math.max(diff:Length(), 1)
		if dist < radius then
			away = away + diff:GetNormalized() * ((radius - dist) / radius)
		end
	end
	if away:LengthSqr() <= 0 then
		return baseTarget
	end
	return baseTarget + away:GetNormalized() * 72
end

function ENT:TryFireAtThreat()
	local st = self._tfbot_ai
	if not st or not st.vision then return end
	local threat = st.vision.currentThreat
	if not IsValid(threat) then return end
	if not self:Visible(threat) then return end
	local active = self:GetActiveWeapon()
	local damage = 10
	local fireRate = 0.18
	local maxRange = 2200
	local melee = false
	if istable(active) then
		damage = tonumber(active.damage) or damage
		fireRate = tonumber(active.fireRate) or fireRate
		maxRange = tonumber(active.range) or maxRange
		melee = active.IsMeleeWeapon == true
	end

	local dist = self:GetPos():Distance(threat:GetPos())
	if dist > maxRange then return end
	if melee and dist > 115 then return end
	if CurTime() < (self._nextShot or 0) then return end

	self._nextShot = CurTime() + fireRate
	local src = self:GetShootPos()
	local dst = threat.WorldSpaceCenter and threat:WorldSpaceCenter() or threat:GetPos()
	local dir = (dst - src):GetNormalized()
	self:FireBullets({
		Attacker = self,
		Inflictor = self,
		Src = src,
		Dir = dir,
		Spread = Vector(0.02, 0.02, 0),
		Tracer = 1,
		Damage = damage,
		Force = 4,
		Num = 1,
	})
end

function ENT:RunModularAI()
	local ai = TFBotValveAI
	if not ai then return end
	local cfg = ai.Config
	if not cfg or not cfg.IsEnabled or not cfg:IsEnabled() then return end
	if not cfg.UseNextBotBackend or not cfg:UseNextBotBackend() then return end

	local stateMod = ai.State
	local perf = ai.Perf
	local base = ai.Base
	local threat = ai.Threat
	local objective = ai.Objective
	local mvm = ai.MvM
	local hints = ai.Hints
	local movement = ai.Movement
	local combat = ai.Combat
	if not stateMod or not perf or not base or not threat or not objective or not mvm or not hints or not movement or not combat then
		return
	end

	local st = stateMod:Get(self)
	if not st then return end

	local now = CurTime()
	if not perf:CanRun(now, st.perf.nextSense) then return end
	st.perf.nextSense = now + perf:GetInterval("sense")

	threat:SelectTarget(self, st)
	objective:Select(self, st)
	mvm:Tick(self, st)
	hints:Apply(self, st)

	if ai.ClassMedic and ai.ClassMedic.Update then ai.ClassMedic:Update(self, st) end
	if ai.ClassSpy and ai.ClassSpy.Update then ai.ClassSpy:Update(self, st) end
	if ai.ClassSniper and ai.ClassSniper.Update then ai.ClassSniper:Update(self, st) end
	if ai.ClassEngineer and ai.ClassEngineer.Update then ai.ClassEngineer:Update(self, st) end

	base:ApplyNextBotModules(self, st, movement, combat)
	self:SetNWString("TFBotValveAI_Objective", tostring(st.objective and st.objective.mode or "none"))
end

function ENT:ProcessTriggerVolumes()
	local now = CurTime()
	self._nextTriggerScan = tonumber(self._nextTriggerScan or 0)
	if now < self._nextTriggerScan then return end
	self._nextTriggerScan = now + TRIGGER_SCAN_INTERVAL

	self._activeTriggerTouches = self._activeTriggerTouches or {}
	local active = self._activeTriggerTouches
	local insideNow = {}
	local pos = self:GetPos()

	for _, trg in ipairs(refreshTriggerCache(now)) do
		if not IsValid(trg) then continue end
		if not pointInsideEntityOBB(trg, pos) then continue end
		local idx = trg:EntIndex()
		insideNow[idx] = trg
		if not active[idx] and trg.StartTouch then
			pcall(trg.StartTouch, trg, self)
		end
		if trg.Touch then
			pcall(trg.Touch, trg, self)
		end
	end

	for idx, trg in pairs(active) do
		if not IsValid(trg) then
			active[idx] = nil
		elseif not insideNow[idx] then
			if trg.EndTouch then
				pcall(trg.EndTouch, trg, self)
			end
			active[idx] = nil
		end
	end

	for idx, trg in pairs(insideNow) do
		active[idx] = trg
	end
end

function ENT:RunBehaviour()
	while true do
		if not self:Alive() then
			coroutine.wait(0.2)
			continue
		end

		self:RunModularAI()

		local targetPos = self._tfbotDesiredPos
		if not isvector(targetPos) or self:GetPos():DistToSqr(targetPos) <= (56 * 56) then
			if IsValid(self.ControllerBot) and self.ControllerBot.FindSpot then
				targetPos = self.ControllerBot:FindSpot("random", { radius = 1200, pos = self:GetPos(), type = "exposed" }) or targetPos
				self._tfbotDesiredPos = targetPos
			end
		end
		local desiredView = self._tfbotDesiredView
		if isangle(desiredView) then
			self.loco:FaceTowards(self:GetPos() + desiredView:Forward() * 120)
		end

		if self._tfbotWantsJump and self:IsOnGround() then
			self.loco:Jump()
		end
		if self._tfbotWantsAttack then
			self:TryFireAtThreat()
		end

		if isvector(targetPos) then
			local smoothTarget = self:GetSoftSeparationTarget(targetPos)
			self.loco:SetDesiredSpeed(math.Clamp(self._tfbotDesiredSpeed or 280, 120, 420))
			startBestActivity(self, RUN_ACTS)
			self.loco:Approach(smoothTarget, 1)
			if self:IsOnGround() and self:GetVelocity():Length2D() < 22 and self:GetPos():DistToSqr(smoothTarget) > (120 * 120) then
				self.loco:Jump()
			end
			coroutine.wait(0)
		else
			startBestActivity(self, IDLE_ACTS)
			coroutine.wait(0.05)
		end

		self:ProcessTriggerVolumes()

		coroutine.yield()
	end
end

function ENT:SpawnFunction(ply, tr, className)
	if not tr.Hit then return end
	local ent = ents.Create(className)
	ent:SetPos(tr.HitPos + tr.HitNormal * 16)
	ent:Spawn()
	ent:Activate()
	return ent
end

list.Set("NPC", "tf_bot_base_nextbot", {
	Name = ENT.PrintName,
	Class = "tf_bot_base_nextbot",
	Category = ENT.Category,
	AdminOnly = true
})

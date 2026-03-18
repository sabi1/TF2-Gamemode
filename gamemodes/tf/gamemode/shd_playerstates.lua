
local meta = FindMetaTable("Entity")
if not meta then return end 

PLAYERSTATE_ONFIRE		= 1
PLAYERSTATE_WATERDROPS	= 2
PLAYERSTATE_OVERHEALED	= 4
PLAYERSTATE_CRITBOOST	= 8
PLAYERSTATE_MINICRIT	= 16
PLAYERSTATE_JARATED		= 32
PLAYERSTATE_EYELANDER	= 64
PLAYERSTATE_BLEEDING	= 128
PLAYERSTATE_MILK		= 256
PLAYERSTATE_STUNNED		= 512
PLAYERSTATE_PUKEDON		= 1024
PLAYERSTATE_MARKED		= 2048
PLAYERSTATE_SPEED		= 4096
PLAYERSTATE_REPROGRAMMED = 8192
--[[
= 16384
= 32768
]]

TF_RUNE_NONE = TF_RUNE_NONE or -1
TF_RUNE_STRENGTH = TF_RUNE_STRENGTH or 0
TF_RUNE_HASTE = TF_RUNE_HASTE or 1
TF_RUNE_REGEN = TF_RUNE_REGEN or 2
TF_RUNE_RESIST = TF_RUNE_RESIST or 3
TF_RUNE_VAMPIRE = TF_RUNE_VAMPIRE or 4
TF_RUNE_REFLECT = TF_RUNE_REFLECT or 5
TF_RUNE_PRECISION = TF_RUNE_PRECISION or 6
TF_RUNE_AGILITY = TF_RUNE_AGILITY or 7
TF_RUNE_KNOCKOUT = TF_RUNE_KNOCKOUT or 8
TF_RUNE_KING = TF_RUNE_KING or 9
TF_RUNE_PLAGUE = TF_RUNE_PLAGUE or 10
TF_RUNE_SUPERNOVA = TF_RUNE_SUPERNOVA or 11

local function DefaultParticleNameFunc(v, p)
	return string.format(v.particle,ParticleSuffix(p:EntityTeam()))
end

local STATE_TO_PRIMARY_COND = {}
local function split_state_bits(state_bits)
	local bits = state_bits or 0
	local mapped_bits = 0
	local unmapped_bits = bits

	for bitmask, _ in pairs(STATE_TO_PRIMARY_COND) do
		if bit.band(bits, bitmask) ~= 0 then
			mapped_bits = bit.bor(mapped_bits, bitmask)
			unmapped_bits = bit.band(unmapped_bits, bit.bnot(bitmask))
		end
	end

	return mapped_bits, unmapped_bits
end

local function each_mapped_cond_for_state(state_bits, fn)
	for bitmask, cond in pairs(STATE_TO_PRIMARY_COND) do
		if bit.band(state_bits, bitmask) ~= 0 then
			fn(bitmask, cond)
		end
	end
end

local function bridge_state_to_condition(ent, state_bit, adding)
	if ent._tf_cond_to_state_bridge then return end
	if not ent.AddCond or not ent.RemoveCond then return end

	for bitmask, cond in pairs(STATE_TO_PRIMARY_COND) do
		if bit.band(state_bit, bitmask) ~= 0 then
			if adding then
				if not ent:InCond(cond) then
					ent:AddCond(cond, PERMANENT_CONDITION or -1, ent)
				end
			elseif ent:InCond(cond) then
				ent:RemoveCond(cond, true)
			end
		end
	end
end
 
function meta:GetPlayerState()
	return self:GetNWInt("PlayerState")
end

function meta:SetPlayerState(st, upd)
	local old = self:GetNWInt("PlayerState", st)
	
	if old~=st then
		self:SetNWInt("PlayerState", st)
		if upd then
			self:UpdateState()
		end
	end
end

function meta:AddPlayerState(st, upd)
	local mapped_bits, unmapped_bits = split_state_bits(st)
	if not self._tf_cond_to_state_bridge and mapped_bits ~= 0 and self.AddCond then
		each_mapped_cond_for_state(mapped_bits, function(_, cond)
			if not self:InCond(cond) then
				self:AddCond(cond, PERMANENT_CONDITION or -1, self)
			end
		end)

		-- Pure condition-backed state requests are handled by AddCond/OnConditionAdded.
		if unmapped_bits == 0 then
			if upd then
				self:UpdateState()
			end
			return
		end
	end

	local old = self:GetNWInt("PlayerState")
	local legacy_bits = self._tf_cond_to_state_bridge and st or unmapped_bits
	local state = bit.bor(old, legacy_bits)
	
	
	if old~=state then
		self:SetNWInt("PlayerState", state)
		bridge_state_to_condition(self, legacy_bits, true)
		if upd then
			self:UpdateState()
		end
	end
end

function meta:RemovePlayerState(st, upd)
	local mapped_bits, unmapped_bits = split_state_bits(st)
	if not self._tf_cond_to_state_bridge and mapped_bits ~= 0 and self.RemoveCond then
		each_mapped_cond_for_state(mapped_bits, function(_, cond)
			if self:InCond(cond) then
				self:RemoveCond(cond, true)
			end
		end)

		-- Pure condition-backed state requests are handled by RemoveCond/OnConditionRemoved.
		if unmapped_bits == 0 then
			if upd then
				self:UpdateState()
			end
			return
		end
	end

	local old = self:GetNWInt("PlayerState")
	local legacy_bits = self._tf_cond_to_state_bridge and st or unmapped_bits
	-- won't be using more than 16 bits anyway, so...
	local state = bit.band(old, (65535-legacy_bits))
	
	if self:HasPlayerState(PLAYERSTATE_ONFIRE) then
		self:SetNWInt("BurnLevel", 0)
	end
	if old~=state then
		self:SetNWInt("PlayerState", state)
		bridge_state_to_condition(self, legacy_bits, false)
		if upd then
			self:UpdateState()
		end
	end
end

function meta:HasPlayerState(st, state_override)
	-- For runtime checks, mapped playerstates should reflect the authoritative TF condition core.
	if state_override == nil and self.InCond then
		local remaining_unmapped = st

		each_mapped_cond_for_state(st, function(bitmask, cond)
			if not self:InCond(cond) then
				remaining_unmapped = nil
			else
				remaining_unmapped = bit.band(remaining_unmapped, bit.bnot(bitmask))
			end
		end)

		if remaining_unmapped == nil then
			return false
		end
		if remaining_unmapped == 0 then
			return true
		end

		local state = self:GetNWInt("PlayerState")
		return bit.band(state, remaining_unmapped) > 0
	end

	local state = state_override or self:GetNWInt("PlayerState")
	return bit.band(state, st) > 0
end

function meta:UpdateState(delay)
	if not IsValid(self) then return end
	if delay then
		timer.Simple(delay, function() self:UpdateState() end)
		return
	end
	self:UpdateStateProxies()
	self:UpdateStateColor()
	self:UpdateStateParticles()
end

function meta:UpdateStateProxies(state_override)
	if SERVER then return end
	
	self:ClearProxyVars()
	
	for k,v in pairs(PlayerStates) do
		if v.proxyvars and self:HasPlayerState(k, state_override) then
			for _,p in ipairs(v.proxyvars) do
				local f = p[2]
				if type(f) == "function" then
					self:SetProxyVar(p[1], f(self))
				else
					local wep = self:GetActiveWeapon()
					if CLIENT then
						if (IsValid(wep)) then
							if (IsValid(wep.CModel)) then
								wep.CModel:SetProxyVar(p[1], f)
							elseif (IsValid(wep.WModel)) then
								wep.WModel:SetProxyVar(p[1], f)
							end
						end
					end
					self:SetProxyVar(p[1], f)
				end
			end
		end
	end
end

function meta:UpdateStateParticles(state_override)
	if not IsValid(self) then return end

	if SERVER and self:IsPlayer() then
		umsg.Start("UpdatePlayerStateParticles")
			umsg.Entity(self)
			umsg.Long(self:GetPlayerState())
		umsg.End()
	else
		if CLIENT then
			self:UpdateStateProxies(state_override)
		end
		self:StopParticles()
		
		if self:IsPlayer() then
			local w = self:GetActiveWeapon()
			if w.ResetParticles then
				w:ResetParticles(state_override)
			end
			
			if self.PlayerItemList then
				for _,v in pairs(self.PlayerItemList) do
					if v.ResetParticles then
						v:ResetParticles(state_override)
					end
				end
			end
		end
		
		if CLIENT and self==LocalPlayer() then
			if not LocalPlayer():ShouldDrawLocalPlayer() and state_override != PLAYERSTATE_SPEED then
				return
			end
		end
		
		for k,v in pairs(PlayerStates) do
			local shouldSpawnPrimary = v.particle and self:HasPlayerState(k, state_override)
			if shouldSpawnPrimary and v.particlepredicate then
				shouldSpawnPrimary = v.particlepredicate(v, self, state_override) ~= false
			end
			if shouldSpawnPrimary then
				local f = v.particlenamefunc or DefaultParticleNameFunc
				local att = v.particleattachment or 0
				if type(att)=="string" then
					att = self:LookupAttachment(att)
				end
				
				ParticleEffectAttach(
					f(v, self),
					v.particleattachtype or PATTACH_ABSORIGIN_FOLLOW,
					self,
					att
				)
			end
			local shouldSpawnSecondary = v.particle2 and self:HasPlayerState(k, state_override) and TF2_IsPyrovisionEnabled(CLIENT and LocalPlayer() or self)
			if shouldSpawnSecondary and v.particle2predicate then
				shouldSpawnSecondary = v.particle2predicate(v, self, state_override) ~= false
			end
			if shouldSpawnSecondary then
				local f = v.particlenamefunc or DefaultParticleNameFunc
				local att = v.particleattachment or 0
				if type(att)=="string" then
					att = self:LookupAttachment(att)
				end
				
				ParticleEffectAttach(
					f(v, self),
					v.particleattachtype or PATTACH_ABSORIGIN_FOLLOW,
					self,
					att
				)
			end
		end
	end
end

function meta:UpdateStateColor()
	local col = {255, 255, 255, 255}
	
	for k,v in pairs(PlayerStates) do
		if v.color and self:HasPlayerState(k) then
			col[1] = math.Clamp(col[1] + v.color[1], 0, 255)
			col[2] = math.Clamp(col[2] + v.color[2], 0, 255)
			col[3] = math.Clamp(col[3] + v.color[3], 0, 255)
			col[4] = math.Clamp(col[4] + v.color[4], 0, 255)
		end
	end
	
	if self:IsPlayer() then
		if col[1]<255 or col[2]<255 or col[3]<255 or col[4]<255 then
			self:SetRenderMode(RENDERMODE_TRANSCOLOR)
		else
			self:SetRenderMode(RENDERMODE_NORMAL)
		end
	end
	
	-- Set the actual color now
	//self:SetColor(unpack(col))
end

if CLIENT then

function meta:DrawStateOverlay()
	for k,v in pairs(PlayerStates) do
		if type(v.overlay)=="string" then
			v.overlay = Material(v.overlay)
		end
		
		if v.overlay and self:HasPlayerState(k) then
			v.overlay:SetFloat("$burnlevel", 1)
			render.UpdateScreenEffectTexture()
			render.SetMaterial(v.overlay)
			render.DrawScreenQuad()
		end
	end
end

usermessage.Hook("SetPlayerState", function(msg)
	local ent = msg:ReadEntity()
	ent:SetPlayerState(msg:ReadLong())
end)

usermessage.Hook("UpdatePlayerStateParticles", function(msg)
	local ent = msg:ReadEntity()
	ent:UpdateStateParticles(msg:ReadLong())
end)

end

/*
hook.Add("OnEntityCreated","lo",function(e) if e:GetClass()=="entityflame" then local p=e:GetParent() if IsValid(p) then e:StopParticles() ParticleEffectAttach("burningplayer_red", PATTACH_ABSORIGIN_FOLLOW, p, 0) end end end)


*/

PlayerStates = {
	[PLAYERSTATE_ONFIRE] = {
		particle = "burningplayer_%s",
		particle2 = "burningplayer_rainbow_%s",
		overlay = "Effects/imcookin",
		proxyvars = {
			{"BurnLevel", 0.5},
		},
	},
	[PLAYERSTATE_WATERDROPS] = {
			particle = "peejar_drips",
		color = {0,0,-255,0},
	},
	[PLAYERSTATE_JARATED] = {
		particle = "peejar_drips",
		color = {0,0,-255,0},
		overlay = "Effects/jarate_overlay",
		proxyvars = {
			{"Jarated", true},
			{"YellowLevel", 1},
		},
	},
	[PLAYERSTATE_SPEED] = {
		particle = "speed_boost_trail",
	},
	[PLAYERSTATE_PUKEDON] = {
		particle = "gas_can_drips_%s",
		color = {0,0,-255,0},
		overlay = "effects/gas_overlay",
		particlepredicate = function(_, p)
			if p.InCond then
				return not (p:InCond(TF_COND_BURNING) or p:InCond(TF_COND_BURNING_PYRO))
			end
			return not p:HasPlayerState(PLAYERSTATE_ONFIRE)
		end,
		particlenamefunc = function(v, p)
			local suffix = (p:EntityTeam() == TEAM_BLU or p:EntityTeam() == TF_TEAM_PVE_INVADERS) and "red" or "blue"
			return string.format(v.particle, suffix)
		end,
		proxyvars = {
			{"Jarated", true},
			{"YellowLevel", 0.5},
		},
	},
	[PLAYERSTATE_STUNNED] = {
		--particle = "peejar_drips",
		color = {0,0,-255,0},
	},
	[PLAYERSTATE_MARKED] = {
		particle = "mark_for_death",
		particleattachtype = PATTACH_POINT_FOLLOW,
		particleattachment = "head"
	},
	[PLAYERSTATE_EYELANDER] = {
		particle = "eye_powerup_%s_lvl_%d",
		particleattachtype = PATTACH_POINT_FOLLOW,
		particleattachment = "righteye",
		particlenamefunc = function(v,p)
			return string.format(v.particle,ParticleSuffix(p:EntityTeam()),math.Clamp(p:GetNWInt("Heads"), 1, 4))
		end,
	},
	[PLAYERSTATE_BLEEDING] = {
		overlay = "Effects/bleed_overlay",
	},
	[PLAYERSTATE_CRITBOOST] = {
		proxyvars = {
			{"CritTeam", function(ent) return ((GAMEMODE:EntityTeam(ent)==TEAM_BLU or GAMEMODE:EntityTeam(ent)==TF_TEAM_PVE_INVADERS) and 3) or 2 end},
			{"CritStatus", 1},
		},
	},
	[PLAYERSTATE_MINICRIT] = {
		proxyvars = {
			{"CritTeam", function(ent) return ((GAMEMODE:EntityTeam(ent)==TEAM_BLU or GAMEMODE:EntityTeam(ent)==TF_TEAM_PVE_INVADERS) and 3) or 2 end},
			{"CritStatus", 2},
		},
	},
	[PLAYERSTATE_MILK] = {
		particle = "peejar_drips_milk",
	},
	[PLAYERSTATE_REPROGRAMMED] = {
		particle = "bot_radio_waves",
		particleattachtype = PATTACH_POINT_FOLLOW,
		particleattachment = "head",
	},
}

PrecacheParticleSystem("burningplayer_red")
PrecacheParticleSystem("burningplayer_blue")
PrecacheParticleSystem("burningplayer_corpse")

PrecacheParticleSystem("overhealedplayer_red_pluses")
PrecacheParticleSystem("overhealedplayer_blue_pluses")

PrecacheParticleSystem("blood_antlionguard_injured_heavy")
PrecacheParticleSystem("peejar_drips")
PrecacheParticleSystem("peejar_drips_milk")
PrecacheParticleSystem("gas_can_drips_red")
PrecacheParticleSystem("gas_can_drips_blue")

PrecacheParticleSystem("eye_powerup_red_lvl_1")
PrecacheParticleSystem("eye_powerup_blue_lvl_1")

PrecacheParticleSystem("eye_powerup_red_lvl_2")
PrecacheParticleSystem("eye_powerup_blue_lvl_2")

PrecacheParticleSystem("eye_powerup_red_lvl_3")
PrecacheParticleSystem("eye_powerup_blue_lvl_3")

PrecacheParticleSystem("eye_powerup_red_lvl_4")
PrecacheParticleSystem("eye_powerup_blue_lvl_4")
PrecacheParticleSystem("powerup_king_red")
PrecacheParticleSystem("powerup_king_blue")
PrecacheParticleSystem("powerup_supernova_ready")
PrecacheParticleSystem("powerup_supernova_strike_red")
PrecacheParticleSystem("powerup_supernova_strike_blue")
PrecacheParticleSystem("powerup_supernova_explode_red")
PrecacheParticleSystem("powerup_supernova_explode_blue")
PrecacheParticleSystem("powerup_plague_carrier")
PrecacheParticleSystem("mark_for_death")
PrecacheParticleSystem("speed_boost_trail")
PrecacheParticleSystem("bot_radio_waves")

-- TF2 condition API (Source SDK 2013 style): AddCond/RemoveCond/InCond.
PERMANENT_CONDITION = PERMANENT_CONDITION or -1

TF_COND = TF_COND or {
	TF_COND_INVALID = -1,
	TF_COND_AIMING = 0,
	TF_COND_ZOOMED = 1,
	TF_COND_DISGUISING = 2,
	TF_COND_DISGUISED = 3,
	TF_COND_STEALTHED = 4,
	TF_COND_INVULNERABLE = 5,
	TF_COND_TELEPORTED = 6,
	TF_COND_TAUNTING = 7,
	TF_COND_INVULNERABLE_WEARINGOFF = 8,
	TF_COND_STEALTHED_BLINK = 9,
	TF_COND_SELECTED_TO_TELEPORT = 10,
	TF_COND_CRITBOOSTED = 11,
	TF_COND_TMPDAMAGEBONUS = 12,
	TF_COND_FEIGN_DEATH = 13,
	TF_COND_PHASE = 14,
	TF_COND_STUNNED = 15,
	TF_COND_OFFENSEBUFF = 16,
	TF_COND_SHIELD_CHARGE = 17,
	TF_COND_DEMO_BUFF = 18,
	TF_COND_ENERGY_BUFF = 19,
	TF_COND_RADIUSHEAL = 20,
	TF_COND_HEALTH_BUFF = 21,
	TF_COND_BURNING = 22,
	TF_COND_HEALTH_OVERHEALED = 23,
	TF_COND_URINE = 24,
	TF_COND_BLEEDING = 25,
	TF_COND_DEFENSEBUFF = 26,
	TF_COND_MAD_MILK = 27,
	TF_COND_MEGAHEAL = 28,
	TF_COND_REGENONDAMAGEBUFF = 29,
	TF_COND_MARKEDFORDEATH = 30,
	TF_COND_NOHEALINGDAMAGEBUFF = 31,
	TF_COND_SPEED_BOOST = 32,
	TF_COND_CRITBOOSTED_PUMPKIN = 33,
	TF_COND_CRITBOOSTED_USER_BUFF = 34,
	TF_COND_CRITBOOSTED_DEMO_CHARGE = 35,
	TF_COND_SODAPOPPER_HYPE = 36,
	TF_COND_CRITBOOSTED_FIRST_BLOOD = 37,
	TF_COND_CRITBOOSTED_BONUS_TIME = 38,
	TF_COND_CRITBOOSTED_CTF_CAPTURE = 39,
	TF_COND_CRITBOOSTED_ON_KILL = 40,
	TF_COND_CANNOT_SWITCH_FROM_MELEE = 41,
	TF_COND_DEFENSEBUFF_NO_CRIT_BLOCK = 42,
	TF_COND_REPROGRAMMED = 43,
	TF_COND_CRITBOOSTED_RAGE_BUFF = 44,
	TF_COND_DEFENSEBUFF_HIGH = 45,
	TF_COND_SNIPERCHARGE_RAGE_BUFF = 46,
	TF_COND_DISGUISE_WEARINGOFF = 47,
	TF_COND_MARKEDFORDEATH_SILENT = 48,
	TF_COND_DISGUISED_AS_DISPENSER = 49,
	TF_COND_SAPPED = 50,
	TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED = 51,
	TF_COND_INVULNERABLE_USER_BUFF = 52,
	TF_COND_HALLOWEEN_BOMB_HEAD = 53,
	TF_COND_HALLOWEEN_THRILLER = 54,
	TF_COND_RADIUSHEAL_ON_DAMAGE = 55,
	TF_COND_CRITBOOSTED_CARD_EFFECT = 56,
	TF_COND_INVULNERABLE_CARD_EFFECT = 57,
	TF_COND_MEDIGUN_UBER_BULLET_RESIST = 58,
	TF_COND_MEDIGUN_UBER_BLAST_RESIST = 59,
	TF_COND_MEDIGUN_UBER_FIRE_RESIST = 60,
	TF_COND_MEDIGUN_SMALL_BULLET_RESIST = 61,
	TF_COND_MEDIGUN_SMALL_BLAST_RESIST = 62,
	TF_COND_MEDIGUN_SMALL_FIRE_RESIST = 63,
	TF_COND_STEALTHED_USER_BUFF = 64,
	TF_COND_MEDIGUN_DEBUFF = 65,
	TF_COND_STEALTHED_USER_BUFF_FADING = 66,
	TF_COND_BULLET_IMMUNE = 67,
	TF_COND_BLAST_IMMUNE = 68,
	TF_COND_FIRE_IMMUNE = 69,
	TF_COND_PREVENT_DEATH = 70,
	TF_COND_MVM_BOT_STUN_RADIOWAVE = 71,
	TF_COND_HALLOWEEN_SPEED_BOOST = 72,
	TF_COND_HALLOWEEN_QUICK_HEAL = 73,
	TF_COND_HALLOWEEN_GIANT = 74,
	TF_COND_HALLOWEEN_TINY = 75,
	TF_COND_HALLOWEEN_IN_HELL = 76,
	TF_COND_HALLOWEEN_GHOST_MODE = 77,
	TF_COND_MINICRITBOOSTED_ON_KILL = 78,
	TF_COND_OBSCURED_SMOKE = 79,
	TF_COND_PARACHUTE_ACTIVE = 80,
	TF_COND_BLASTJUMPING = 81,
	TF_COND_HALLOWEEN_KART = 82,
	TF_COND_HALLOWEEN_KART_DASH = 83,
	TF_COND_BALLOON_HEAD = 84,
	TF_COND_MELEE_ONLY = 85,
	TF_COND_SWIMMING_CURSE = 86,
	TF_COND_FREEZE_INPUT = 87,
	TF_COND_HALLOWEEN_KART_CAGE = 88,
	TF_COND_DONOTUSE_0 = 89,
	TF_COND_RUNE_STRENGTH = 90,
	TF_COND_RUNE_HASTE = 91,
	TF_COND_RUNE_REGEN = 92,
	TF_COND_RUNE_RESIST = 93,
	TF_COND_RUNE_VAMPIRE = 94,
	TF_COND_RUNE_REFLECT = 95,
	TF_COND_RUNE_PRECISION = 96,
	TF_COND_RUNE_AGILITY = 97,
	TF_COND_GRAPPLINGHOOK = 98,
	TF_COND_GRAPPLINGHOOK_SAFEFALL = 99,
	TF_COND_GRAPPLINGHOOK_LATCHED = 100,
	TF_COND_GRAPPLINGHOOK_BLEEDING = 101,
	TF_COND_AFTERBURN_IMMUNE = 102,
	TF_COND_RUNE_KNOCKOUT = 103,
	TF_COND_RUNE_IMBALANCE = 104,
	TF_COND_CRITBOOSTED_RUNE_TEMP = 105,
	TF_COND_PASSTIME_INTERCEPTION = 106,
	TF_COND_SWIMMING_NO_EFFECTS = 107,
	TF_COND_PURGATORY = 108,
	TF_COND_RUNE_KING = 109,
	TF_COND_RUNE_PLAGUE = 110,
	TF_COND_RUNE_SUPERNOVA = 111,
	TF_COND_PLAGUE = 112,
	TF_COND_KING_BUFFED = 113,
	TF_COND_TEAM_GLOWS = 114,
	TF_COND_KNOCKED_INTO_AIR = 115,
	TF_COND_COMPETITIVE_WINNER = 116,
	TF_COND_COMPETITIVE_LOSER = 117,
	TF_COND_HEALING_DEBUFF = 118,
	TF_COND_PASSTIME_PENALTY_DEBUFF = 119,
	TF_COND_GRAPPLED_TO_PLAYER = 120,
	TF_COND_GRAPPLED_BY_PLAYER = 121,
	TF_COND_PARACHUTE_DEPLOYED = 122,
	TF_COND_GAS = 123,
	TF_COND_BURNING_PYRO = 124,
	TF_COND_ROCKETPACK = 125,
	TF_COND_LOST_FOOTING = 126,
	TF_COND_AIR_CURRENT = 127,
	TF_COND_HALLOWEEN_HELL_HEAL = 128,
	TF_COND_POWERUPMODE_DOMINANT = 129,
	TF_COND_IMMUNE_TO_PUSHBACK = 130,
	TF_COND_LAST = 131,
}

for cond_name, cond_id in pairs(TF_COND) do
	if _G[cond_name] == nil then
		_G[cond_name] = cond_id
	end
end

TF_RUNE_COND_BY_TYPE = TF_RUNE_COND_BY_TYPE or {
	[TF_RUNE_STRENGTH] = TF_COND_RUNE_STRENGTH,
	[TF_RUNE_HASTE] = TF_COND_RUNE_HASTE,
	[TF_RUNE_REGEN] = TF_COND_RUNE_REGEN,
	[TF_RUNE_RESIST] = TF_COND_RUNE_RESIST,
	[TF_RUNE_VAMPIRE] = TF_COND_RUNE_VAMPIRE,
	[TF_RUNE_REFLECT] = TF_COND_RUNE_REFLECT,
	[TF_RUNE_PRECISION] = TF_COND_RUNE_PRECISION,
	[TF_RUNE_AGILITY] = TF_COND_RUNE_AGILITY,
	[TF_RUNE_KNOCKOUT] = TF_COND_RUNE_KNOCKOUT,
	[TF_RUNE_KING] = TF_COND_RUNE_KING,
	[TF_RUNE_PLAGUE] = TF_COND_RUNE_PLAGUE,
	[TF_RUNE_SUPERNOVA] = TF_COND_RUNE_SUPERNOVA,
}

TF_RUNE_TYPE_BY_COND = TF_RUNE_TYPE_BY_COND or {}
for runeType, cond in pairs(TF_RUNE_COND_BY_TYPE) do
	TF_RUNE_TYPE_BY_COND[cond] = runeType
end

STATE_TO_PRIMARY_COND[PLAYERSTATE_ONFIRE] = TF_COND_BURNING
STATE_TO_PRIMARY_COND[PLAYERSTATE_OVERHEALED] = TF_COND_HEALTH_OVERHEALED
STATE_TO_PRIMARY_COND[PLAYERSTATE_CRITBOOST] = TF_COND_CRITBOOSTED
STATE_TO_PRIMARY_COND[PLAYERSTATE_MINICRIT] = TF_COND_OFFENSEBUFF
STATE_TO_PRIMARY_COND[PLAYERSTATE_JARATED] = TF_COND_URINE
STATE_TO_PRIMARY_COND[PLAYERSTATE_BLEEDING] = TF_COND_BLEEDING
STATE_TO_PRIMARY_COND[PLAYERSTATE_MILK] = TF_COND_MAD_MILK
STATE_TO_PRIMARY_COND[PLAYERSTATE_STUNNED] = TF_COND_STUNNED
STATE_TO_PRIMARY_COND[PLAYERSTATE_PUKEDON] = TF_COND_GAS
STATE_TO_PRIMARY_COND[PLAYERSTATE_MARKED] = TF_COND_MARKEDFORDEATH
STATE_TO_PRIMARY_COND[PLAYERSTATE_SPEED] = TF_COND_SPEED_BOOST

local function resolve_cond(eCond)
	if isnumber(eCond) then return eCond end
	if isstring(eCond) then
		return TF_COND[eCond] or TF_COND[string.upper(eCond)]
	end
	return nil
end

local LIST_MANAGED_CONDS = {
	[TF_COND_CRITBOOSTED] = true,
}

local FAST_EXPIRE_CONDS = {
	[TF_COND_URINE] = true,
	[TF_COND_BLEEDING] = true,
	[TF_COND_MAD_MILK] = true,
	[TF_COND_GAS] = true,
	[TF_COND_PLAGUE] = true,
}

local function cond_word(cond)
	return math.floor(cond / 32)
end

local function cond_bit(cond)
	return bit.lshift(1, cond % 32)
end

local function get_cond_word_value(self, idx)
	if idx == 0 then return self.TFCondBits0 or 0 end
	if idx == 1 then return self.TFCondBits1 or 0 end
	if idx == 2 then return self.TFCondBits2 or 0 end
	if idx == 3 then return self.TFCondBits3 or 0 end
	if idx == 4 then return self.TFCondBits4 or 0 end
	return 0
end

local function set_cond_word_value(self, idx, value)
	if idx == 0 then self.TFCondBits0 = value return end
	if idx == 1 then self.TFCondBits1 = value return end
	if idx == 2 then self.TFCondBits2 = value return end
	if idx == 3 then self.TFCondBits3 = value return end
	if idx == 4 then self.TFCondBits4 = value return end
end

local function set_cond_bit(self, cond)
	local idx = cond_word(cond)
	local mask = cond_bit(cond)
	set_cond_word_value(self, idx, bit.bor(get_cond_word_value(self, idx), mask))
end

local function clear_cond_bit(self, cond)
	local idx = cond_word(cond)
	local mask = cond_bit(cond)
	set_cond_word_value(self, idx, bit.band(get_cond_word_value(self, idx), bit.bnot(mask)))
end

local function cond_bit_is_set(self, cond)
	local idx = cond_word(cond)
	local mask = cond_bit(cond)
	return bit.band(get_cond_word_value(self, idx), mask) ~= 0
end

local function sync_cond_bits_network(self)
	if not SERVER or not self.SetNW2Int then return end
	self:SetNW2Int("tf_cond_bits0", self.TFCondBits0 or 0)
	self:SetNW2Int("tf_cond_bits1", self.TFCondBits1 or 0)
	self:SetNW2Int("tf_cond_bits2", self.TFCondBits2 or 0)
	self:SetNW2Int("tf_cond_bits3", self.TFCondBits3 or 0)
	self:SetNW2Int("tf_cond_bits4", self.TFCondBits4 or 0)
	if self.TFConditionList then
		self:SetNW2Int("tf_cond_list_bits", self.TFConditionList._condition_bits or 0)
	end
end

local function sync_cond_bits_from_network(self)
	if not CLIENT or not self.GetNW2Int then return end
	local old0 = self.TFCondBits0 or 0
	local old1 = self.TFCondBits1 or 0
	local old2 = self.TFCondBits2 or 0
	local old3 = self.TFCondBits3 or 0
	local old4 = self.TFCondBits4 or 0
	self.TFCondBits0 = self:GetNW2Int("tf_cond_bits0", self.TFCondBits0 or 0)
	self.TFCondBits1 = self:GetNW2Int("tf_cond_bits1", self.TFCondBits1 or 0)
	self.TFCondBits2 = self:GetNW2Int("tf_cond_bits2", self.TFCondBits2 or 0)
	self.TFCondBits3 = self:GetNW2Int("tf_cond_bits3", self.TFCondBits3 or 0)
	self.TFCondBits4 = self:GetNW2Int("tf_cond_bits4", self.TFCondBits4 or 0)
	local old_list_bits = 0
	if self.TFConditionList then
		old_list_bits = self.TFConditionList._condition_bits or 0
		self.TFConditionList._condition_bits = self:GetNW2Int("tf_cond_list_bits", self.TFConditionList._condition_bits or 0)
	end

	-- Mirror CTFConditionList::UpdateClientConditions for list-managed conds.
	if self.TFConditionList then
		local new_list_bits = self.TFConditionList._condition_bits or 0
		if old_list_bits ~= new_list_bits then
			for i = 0, 31 do
				if LIST_MANAGED_CONDS[i] then
					local mask = bit.lshift(1, i)
					local was_on = bit.band(old_list_bits, mask) ~= 0
					local is_on = bit.band(new_list_bits, mask) ~= 0
					if was_on ~= is_on then
						if is_on then
							self.TFConditionList._conditions[i] = self.TFConditionList._conditions[i] or {
								max_duration = PERMANENT_CONDITION,
								min_duration = 0,
								provider = NULL,
							}
						else
							self.TFConditionList._conditions[i] = nil
						end

						local data = self.TFConditionData and self.TFConditionData[i]
						if data then
							data.active = is_on
							data.prev_active = was_on
							data.m_bPrevActive = was_on
						end

						self._tf_cond_to_state_bridge = true
						if is_on then
							self:OnConditionAdded(i)
						else
							self:OnConditionRemoved(i)
						end
						self._tf_cond_to_state_bridge = false
					end
				end
			end
		end
	end

	-- Mirror CTFConditionList::OnDataChanged behavior clientside:
	-- run add/remove callbacks when condition bits changed via network.
	local changed = (old0 ~= self.TFCondBits0) or (old1 ~= self.TFCondBits1) or (old2 ~= self.TFCondBits2) or (old3 ~= self.TFCondBits3) or (old4 ~= self.TFCondBits4)
	if not changed then return end

	for i = 0, (TF_COND_LAST or 0) - 1 do
		if not (i < 32 and LIST_MANAGED_CONDS[i]) then
			local old_on = false
			local idx = cond_word(i)
			local mask = cond_bit(i)
			if idx == 0 then old_on = bit.band(old0, mask) ~= 0
			elseif idx == 1 then old_on = bit.band(old1, mask) ~= 0
			elseif idx == 2 then old_on = bit.band(old2, mask) ~= 0
			elseif idx == 3 then old_on = bit.band(old3, mask) ~= 0
			elseif idx == 4 then old_on = bit.band(old4, mask) ~= 0 end

			local new_on = cond_bit_is_set(self, i)
			if old_on ~= new_on then
				local data = self.TFConditionData and self.TFConditionData[i]
				if data then
					data.active = new_on
					data.prev_active = old_on
					data.m_bPrevActive = old_on
				end
				self._tf_cond_to_state_bridge = true
				if new_on then
					self:OnConditionAdded(i)
				else
					self:OnConditionRemoved(i)
				end
				self._tf_cond_to_state_bridge = false
			end
		end
	end
end

local function ensure_condition_core(self)
	if self._tf_cond_core_init then
		self.TFConditionList = self.TFConditionList or { _conditions = {}, _condition_bits = 0, _old_condition_bits = 0 }
		self.TFConditionData = self.TFConditionData or {}
		return
	end

	if self.TFCondBits0 == nil then self.TFCondBits0 = 0 end
	if self.TFCondBits1 == nil then self.TFCondBits1 = 0 end
	if self.TFCondBits2 == nil then self.TFCondBits2 = 0 end
	if self.TFCondBits3 == nil then self.TFCondBits3 = 0 end
	if self.TFCondBits4 == nil then self.TFCondBits4 = 0 end

	local conditionData = istable(self.TFConditionData) and self.TFConditionData or {}
	self.TFConditionData = conditionData
	for i = 0, (TF_COND_LAST or 0) - 1 do
		local data = conditionData[i]
		if not data then
			conditionData[i] = {
				m_bPrevActive = false,
				m_flExpireTime = 0,
				m_pProvider = NULL,
				m_nPreventedDamageFromCondition = 0,
				active = false,
				prev_active = false,
				expire = 0,
				provider = NULL,
			}
		end
	end

	self.TFConditionList = self.TFConditionList or {
		_conditions = {},
		_condition_bits = 0,
		_old_condition_bits = 0,
	}
	self._tf_cond_core_init = true
end

local function cond_list_in_cond(self, cond)
	ensure_condition_core(self)
	return bit.band(self.TFConditionList._condition_bits or 0, bit.lshift(1, cond)) ~= 0
end

local function cond_list_add(self, cond, duration, provider)
	if not LIST_MANAGED_CONDS[cond] or cond >= 32 then return false, false end
	ensure_condition_core(self)
	local list = self.TFConditionList
	local entry = list._conditions[cond]
	if entry then
		if duration ~= PERMANENT_CONDITION then
			if entry.max_duration == PERMANENT_CONDITION or duration < entry.max_duration then
				if duration > entry.min_duration then
					entry.min_duration = duration
				end
			else
				entry.max_duration = duration
			end
		elseif entry.max_duration ~= PERMANENT_CONDITION then
			entry.min_duration = entry.max_duration
			entry.max_duration = duration
		end
		entry.provider = IsValid(provider) and provider or NULL
		return true, false
	end

	list._conditions[cond] = {
		max_duration = duration,
		min_duration = 0,
		provider = IsValid(provider) and provider or NULL,
	}
	list._condition_bits = bit.bor(list._condition_bits or 0, bit.lshift(1, cond))
	return true, true
end

local function cond_list_remove(self, cond, ignore_duration)
	if not LIST_MANAGED_CONDS[cond] or cond >= 32 then return false, false end
	ensure_condition_core(self)
	local list = self.TFConditionList
	local entry = list._conditions[cond]
	if not entry then return true, false end

	if not ignore_duration and entry.min_duration and entry.min_duration > 0 then
		entry.max_duration = entry.min_duration
		return true, false
	end

	list._conditions[cond] = nil
	list._condition_bits = bit.band(list._condition_bits or 0, bit.bnot(bit.lshift(1, cond)))
	return true, true
end

local function get_cond_data(self, cond)
	ensure_condition_core(self)
	return self.TFConditionData[cond]
end

function meta:InCond(eCond)
	local cond = resolve_cond(eCond)
	if cond == nil or cond < 0 or cond >= (TF_COND_LAST or 0) then return false end
	ensure_condition_core(self)
	if cond < 32 and cond_list_in_cond(self, cond) then return true end
	return cond_bit_is_set(self, cond)
end

function meta:GetConditionDuration(eCond)
	local cond = resolve_cond(eCond)
	if cond == nil then return 0 end
	ensure_condition_core(self)

	if cond < 32 and cond_list_in_cond(self, cond) then
		local entry = self.TFConditionList._conditions[cond]
		if not entry then return 0 end
		if entry.max_duration == PERMANENT_CONDITION then return PERMANENT_CONDITION end
		return math.max(0, entry.max_duration or 0)
	end

	local data = get_cond_data(self, cond)
	if not self:InCond(cond) then return 0 end
	if data.m_flExpireTime == PERMANENT_CONDITION then return PERMANENT_CONDITION end
	return math.max(0, data.m_flExpireTime or 0)
end

function meta:SetConditionDuration(eCond, flDuration)
	local cond = resolve_cond(eCond)
	if cond == nil or not self:InCond(cond) then return end
	ensure_condition_core(self)
	local duration = flDuration or 0

	if cond < 32 and cond_list_in_cond(self, cond) then
		local entry = self.TFConditionList._conditions[cond]
		if entry then
			entry.max_duration = duration
		end
		sync_cond_bits_network(self)
		return
	end

	local data = get_cond_data(self, cond)
	data.m_flExpireTime = duration
	data.expire = duration
	sync_cond_bits_network(self)
end

function meta:GetConditionProvider(eCond)
	local cond = resolve_cond(eCond)
	if cond == nil then return NULL end
	ensure_condition_core(self)

	if cond < 32 and cond_list_in_cond(self, cond) then
		local entry = self.TFConditionList._conditions[cond]
		return (entry and IsValid(entry.provider)) and entry.provider or NULL
	end

	local data = get_cond_data(self, cond)
	return (self:InCond(cond) and IsValid(data.m_pProvider)) and data.m_pProvider or NULL
end

local function tf_disguise_cond_debug_enabled()
	if not SERVER then return false end
	local cvar = GetConVar("tf_debug_spy_disguise")
	return cvar and cvar:GetBool() or false
end

local function tf_disguise_cond_name(cond)
	if cond == TF_COND_DISGUISED then return "TF_COND_DISGUISED" end
	if cond == TF_COND_DISGUISING then return "TF_COND_DISGUISING" end
	return tostring(cond)
end

local function tf_disguise_cond_should_log(ent, cond)
	if not tf_disguise_cond_debug_enabled() then return false end
	if cond ~= TF_COND_DISGUISED and cond ~= TF_COND_DISGUISING then return false end
	return IsValid(ent) and ent:IsPlayer()
end

local function tf_disguise_cond_debug(ent, cond, msg, includeTrace)
	if not tf_disguise_cond_should_log(ent, cond) then return end
	local nick = isfunction(ent.Nick) and ent:Nick() or "unknown"
	local className = isfunction(ent.GetPlayerClass) and ent:GetPlayerClass() or "?"
	print(string.format("[tf_debug_spy_disguise] t=%.3f ply=%s<%d> class=%s cond=%s %s",
		CurTime(),
		tostring(nick),
		ent:EntIndex(),
		tostring(className),
		tf_disguise_cond_name(cond),
		tostring(msg)
	))
	if includeTrace and debug and debug.traceback then
		print(debug.traceback("[tf_debug_spy_disguise] cond stack", 3))
	end
end

function meta:AddCond(eCond, flDuration, pProvider)
	local cond = resolve_cond(eCond)
	if cond == nil or cond < 0 or cond >= (TF_COND_LAST or 0) then return false end

	local providerStr = IsValid(pProvider) and string.format("%s<%d>", pProvider:GetClass(), pProvider:EntIndex()) or tostring(pProvider)
	tf_disguise_cond_debug(self, cond, string.format("AddCond called duration=%s provider=%s", tostring(flDuration), providerStr), false)

	-- Match TF2: dead players do not take new conditions.
	if self:IsPlayer() and not self:Alive() then
		tf_disguise_cond_debug(self, cond, "AddCond blocked: player is dead", true)
		return false
	end
	ensure_condition_core(self)

	local duration = flDuration
	if duration == nil then duration = PERMANENT_CONDITION end
	local was_active = self:InCond(cond)

	-- list-managed conditions (mirrors CTFConditionList behavior for selected conds)
	local list_handled, list_added_new = cond_list_add(self, cond, duration, pProvider)
	if list_handled then
		tf_disguise_cond_debug(
			self,
			cond,
			string.format("AddCond list-managed handled added_new=%s was_active=%s", tostring(list_added_new), tostring(was_active)),
			not list_added_new
		)
		if list_added_new then
			self._tf_cond_to_state_bridge = true
			self:OnConditionAdded(cond)
			self._tf_cond_to_state_bridge = false
		end
		sync_cond_bits_network(self)
		return true
	end

	local data = get_cond_data(self, cond)
	data.m_bPrevActive = was_active
	data.prev_active = was_active
	data.active = true

	if duration ~= PERMANENT_CONDITION then
		if data.m_flExpireTime == PERMANENT_CONDITION or duration < data.m_flExpireTime then
			duration = data.m_flExpireTime
		end
	end

	data.m_flExpireTime = duration
	data.expire = duration
	data.m_pProvider = IsValid(pProvider) and pProvider or NULL
	data.provider = data.m_pProvider
	data.m_nPreventedDamageFromCondition = 0

	set_cond_bit(self, cond)

	if not was_active then
		self._tf_cond_to_state_bridge = true
		self:OnConditionAdded(cond)
		self._tf_cond_to_state_bridge = false
		tf_disguise_cond_debug(self, cond, "AddCond applied (was inactive -> active)", false)
	else
		tf_disguise_cond_debug(self, cond, "AddCond refreshed (already active)", false)
	end

	sync_cond_bits_network(self)
	return true
end

function meta:RemoveCond(eCond, ignore_duration)
	local cond = resolve_cond(eCond)
	if cond == nil or cond < 0 or cond >= (TF_COND_LAST or 0) then return false end
	if not self:InCond(cond) then
		tf_disguise_cond_debug(self, cond, string.format("RemoveCond ignored: not active (ignore_duration=%s)", tostring(ignore_duration)), true)
		return false
	end

	ensure_condition_core(self)
	local list_handled, list_removed = cond_list_remove(self, cond, ignore_duration)
	if list_handled then
		tf_disguise_cond_debug(self, cond, string.format("RemoveCond list-managed handled removed=%s ignore_duration=%s", tostring(list_removed), tostring(ignore_duration)), not list_removed)
		if list_removed then
			self._tf_cond_to_state_bridge = true
			self:OnConditionRemoved(cond)
			self._tf_cond_to_state_bridge = false
		end
		sync_cond_bits_network(self)
		return true
	end

	local data = get_cond_data(self, cond)
	if not ignore_duration and data.m_flExpireTime and data.m_flExpireTime ~= PERMANENT_CONDITION and data.m_flExpireTime > 0 then
		tf_disguise_cond_debug(self, cond, string.format("RemoveCond blocked by duration expire=%s (use ignore_duration=true to force)", tostring(data.m_flExpireTime)), true)
		return false
	end

	clear_cond_bit(self, cond)

	self._tf_cond_to_state_bridge = true
	self:OnConditionRemoved(cond)
	self._tf_cond_to_state_bridge = false

	data.active = false
	data.prev_active = false
	data.provider = NULL
	data.expire = 0
	data.m_nPreventedDamageFromCondition = 0
	data.m_flExpireTime = 0
	data.m_pProvider = NULL
	data.m_bPrevActive = false

	tf_disguise_cond_debug(self, cond, string.format("RemoveCond applied ignore_duration=%s", tostring(ignore_duration)), true)

	sync_cond_bits_network(self)
	return true
end

function meta:RemoveAllConds()
	ensure_condition_core(self)
	for i = 0, (TF_COND_LAST or 0) - 1 do
		if self:InCond(i) then
			self:RemoveCond(i, true)
		end
	end
end

function meta:ConditionGameRulesThink()
	if not SERVER then return end
	ensure_condition_core(self)

	-- TF2 server think: spy with the dispenser crouch attribute continually refreshes this cond.
	if self:IsPlayer() and self:Alive() and self.GetPlayerClass and self:GetPlayerClass() == "spy" and self.Crouching and self:Crouching() then
		local ground = self.GetGroundEntity and self:GetGroundEntity() or NULL
		if ground ~= nil and ground ~= NULL then
			local has_dispenser_attr = false
			local function has_attr(ent)
				if not IsValid(ent) then return false end
				if ent.GetAttributeValue then
					local v = tonumber(ent:GetAttributeValue("disguise_as_dispenser_on_crouch", 0)) or 0
					if v ~= 0 then return true end
				end
				if ent.GetAttribute then
					local att = ent:GetAttribute("disguise_as_dispenser_on_crouch")
					if att and (tonumber(att.value) or 0) ~= 0 then
						return true
					end
				end
				return false
			end

			local active = self.GetActiveWeapon and self:GetActiveWeapon() or NULL
			has_dispenser_attr = has_attr(active)

			if not has_dispenser_attr and self.GetWeapons then
				for _, wep in ipairs(self:GetWeapons()) do
					if has_attr(wep) then
						has_dispenser_attr = true
						break
					end
				end
			end

			if not has_dispenser_attr and istable(self.PlayerItemList) then
				for _, item in pairs(self.PlayerItemList) do
					if has_attr(item) then
						has_dispenser_attr = true
						break
					end
				end
			end

			if has_dispenser_attr then
				self:AddCond(TF_COND_DISGUISED_AS_DISPENSER, 0.5, self)
			end
		end
	end

	local healer_count = 0
	if self.GetNumHealers then
		healer_count = self:GetNumHealers() or 0
	elseif istable(self.Healers) then
		healer_count = #self.Healers
	elseif istable(self.m_aHealers) then
		healer_count = #self.m_aHealers
	end

	-- Keep TF2 crit update cadence if host has the implementation.
	if self.UpdateCritMult then
		self._tf_next_crit_update = self._tf_next_crit_update or 0
		if self._tf_next_crit_update < CurTime() then
			self:UpdateCritMult()
			self._tf_next_crit_update = CurTime() + 0.5
		end
	end

	-- condition-list managed durations
	for cond, entry in pairs(self.TFConditionList._conditions) do
		if entry.max_duration > PERMANENT_CONDITION or entry.min_duration > PERMANENT_CONDITION then
			local reduction = FrameTime()
			if FAST_EXPIRE_CONDS[cond] and healer_count > 0 then
				if cond == TF_COND_URINE then
					reduction = reduction + (healer_count * reduction)
				else
					reduction = reduction + (healer_count * reduction * 4)
				end
			end

			if entry.min_duration > PERMANENT_CONDITION then
				entry.min_duration = math.max(entry.min_duration - reduction, 0)
			end
			if entry.max_duration > PERMANENT_CONDITION then
				entry.max_duration = math.max(entry.max_duration - reduction, 0)
				if entry.max_duration < entry.min_duration then
					entry.max_duration = entry.min_duration
				end
			end
			if entry.max_duration == 0 then
				self:RemoveCond(cond)
			end
		end
	end

	-- regular condition durations
	for i = 0, (TF_COND_LAST or 0) - 1 do
		if self:InCond(i) and (i >= 32 or not cond_list_in_cond(self, i)) then
			local data = get_cond_data(self, i)
			if data.m_flExpireTime ~= PERMANENT_CONDITION then
				local reduction = FrameTime()
				if FAST_EXPIRE_CONDS[i] and healer_count > 0 then
					if i == TF_COND_URINE then
						reduction = reduction + (healer_count * reduction)
					else
						reduction = reduction + (healer_count * reduction * 4)
					end
				end
				data.m_flExpireTime = math.max((data.m_flExpireTime or 0) - reduction, 0)
				data.expire = data.m_flExpireTime
				if data.m_flExpireTime == 0 then
					self:RemoveCond(i)
				end
			end
		end
	end
end

local function can_run_dispenser_disguise(owner)
	if not IsValid(owner) or not owner:Alive() then return false end
	if not owner.InCond or not owner:InCond(TF_COND_DISGUISED_AS_DISPENSER) then return false end
	if owner:InCond(TF_COND_STEALTHED) or owner:InCond(TF_COND_STEALTHED_USER_BUFF) or owner:InCond(TF_COND_STEALTHED_USER_BUFF_FADING) then
		return false
	end
	if not owner.Crouching or not owner:Crouching() then return false end
	local ground = owner.GetGroundEntity and owner:GetGroundEntity() or NULL
	if ground == nil or ground == NULL then return false end
	return true
end

local function each_dispenser_disguise_target(owner, fn)
	for _, target in ipairs(ents.FindInSphere(owner:GetPos(), 100)) do
		if not IsValid(target) or not target:IsPlayer() or not target:Alive() then continue end
		if target.IsBuilding and target:IsBuilding() then continue end
		if owner.IsFriendly and not owner:IsFriendly(target) then continue end
		fn(target)
	end
end

function meta:ConditionThink()
	ensure_condition_core(self)
	if CLIENT then
		sync_cond_bits_from_network(self)
	end
	if SERVER and self:IsPlayer() and self.InCond then
		if can_run_dispenser_disguise(self) then
			local now = CurTime()
			if (self._tfDispenserDisguiseNextHeal or 0) <= now then
				each_dispenser_disguise_target(self, function(target)
					local maxHp = tonumber(target:GetMaxHealth() or 0) or 0
					if maxHp > 0 then
						target:SetHealth(math.Clamp(target:Health() + 1, 0, maxHp))
					end
				end)
				self._tfDispenserDisguiseNextHeal = now + 0.1
			end

			if (self._tfDispenserDisguiseNextAmmo or 0) <= now then
				each_dispenser_disguise_target(self, function(target)
					if GAMEMODE and GAMEMODE.GiveAmmoPercentNoMetal then
						GAMEMODE:GiveAmmoPercentNoMetal(target, 20)
					end
					if isfunction(target.GiveTFAmmo) then
						target:GiveTFAmmo(40, TF_METAL)
					else
						target:GiveAmmo(40, TF_METAL, false)
					end
				end)
				self._tfDispenserDisguiseNextAmmo = now + 1
			end
		else
			self._tfDispenserDisguiseNextHeal = nil
			self._tfDispenserDisguiseNextAmmo = nil
		end
	end
end

local function spawn_status_entity(target, class_name, provider, duration)
	if not SERVER or not IsValid(target) then return end
	local ent = ents.Create(class_name)
	if not IsValid(ent) then return end
	ent.Target = target
	ent.Inflictor = IsValid(provider) and provider or target
	ent.LifeTime = duration
	ent:SetOwner(IsValid(provider) and provider or target)
	ent:Spawn()
end

function meta:SetFirstBloodBoosted(enabled)
	self.FirstBloodBoosted = enabled and true or false
end

local function has_any_cond(self, conds)
	for i = 1, #conds do
		if self:InCond(conds[i]) then
			return true
		end
	end
	return false
end

function meta:OnAddBurning()
	self:AddPlayerState(PLAYERSTATE_ONFIRE, true)
	if SERVER then
		local duration = self:GetConditionDuration(TF_COND_BURNING)
		if duration == PERMANENT_CONDITION or duration <= 0 then duration = 10 end
		spawn_status_entity(self, "tf_entityflame", self:GetConditionProvider(TF_COND_BURNING), duration)
	end
end

function meta:OnRemoveBurning()
	if SERVER and IsValid(self.FireEntity) then
		self.FireEntity:Remove()
	end
	self:RemovePlayerState(PLAYERSTATE_ONFIRE, true)
end

function meta:OnAddBleeding()
	self:AddPlayerState(PLAYERSTATE_BLEEDING, true)
	if SERVER then
		local duration = self:GetConditionDuration(TF_COND_BLEEDING)
		if duration == PERMANENT_CONDITION or duration <= 0 then duration = 8 end
		spawn_status_entity(self, "tf_entitybleed", self:GetConditionProvider(TF_COND_BLEEDING), duration)
	end
end

function meta:OnRemoveBleeding()
	if SERVER and IsValid(self.BleedEntity) then
		self.BleedEntity:Remove()
	end
	self:RemovePlayerState(PLAYERSTATE_BLEEDING, true)
end

function meta:OnAddUrine()
	self:AddPlayerState(PLAYERSTATE_JARATED, true)
end

function meta:OnRemoveUrine()
	self:RemovePlayerState(PLAYERSTATE_JARATED, true)
end

function meta:OnAddMadMilk()
	self:AddPlayerState(PLAYERSTATE_MILK, true)
end

function meta:OnRemoveMadMilk()
	self:RemovePlayerState(PLAYERSTATE_MILK, true)
end

function meta:OnAddCondGas()
	self:AddPlayerState(PLAYERSTATE_PUKEDON, true)
end

function meta:OnRemoveCondGas()
	self:RemovePlayerState(PLAYERSTATE_PUKEDON, true)
end

function meta:OnAddMarkedForDeath()
	self:AddPlayerState(PLAYERSTATE_MARKED, true)
end

function meta:OnRemoveMarkedForDeath()
	self:RemovePlayerState(PLAYERSTATE_MARKED, true)
end

function meta:OnAddMarkedForDeathSilent()
	self:AddPlayerState(PLAYERSTATE_MARKED, true)
end

function meta:OnRemoveMarkedForDeathSilent()
	self:RemovePlayerState(PLAYERSTATE_MARKED, true)
end

if CLIENT then
	function meta:_TFSetForcedStunThirdperson(enable)
		if self ~= LocalPlayer() then return end

		local count = self._tfForcedStunThirdpersonCount or 0
		if enable then
			count = count + 1
			self._tfForcedStunThirdpersonCount = count

			if count == 1 then
				self._tfForcedStunThirdpersonWasEnabled = self.IsThirdperson and true or false
				if not self._tfForcedStunThirdpersonWasEnabled then
					if StartThirdperson then
						StartThirdperson()
					else
						self.IsThirdperson = true
					end
				end
			end
			return
		end

		if count <= 0 then return end
		count = count - 1
		self._tfForcedStunThirdpersonCount = count

		if count == 0 then
			if not self._tfForcedStunThirdpersonWasEnabled then
				if EndThirdperson then
					EndThirdperson(true)
				else
					self.IsThirdperson = false
				end
			end
			self._tfForcedStunThirdpersonWasEnabled = nil
		end
	end
end

function meta:OnAddStunned()
	self:AddPlayerState(PLAYERSTATE_STUNNED, true)
	if CLIENT then
		local suppressUntil = tonumber(self._tfNoForcedStunThirdpersonUntil) or 0
		if self.GetNWFloat then
			suppressUntil = math.max(suppressUntil, tonumber(self:GetNWFloat("TFNoForcedStunThirdpersonUntil", 0)) or 0)
		end
		local suppressForcedTP = suppressUntil > CurTime()
		if not suppressForcedTP then
			self:_TFSetForcedStunThirdperson(true)
			self._tfForcedStunThirdpersonFromStunned = (self._tfForcedStunThirdpersonFromStunned or 0) + 1
		else
			self._tfSuppressedStunThirdpersonFromStunned = (self._tfSuppressedStunThirdpersonFromStunned or 0) + 1
		end
	end
end

function meta:OnRemoveStunned()
	self:RemovePlayerState(PLAYERSTATE_STUNNED, true)
	if CLIENT then
		local forcedCount = self._tfForcedStunThirdpersonFromStunned or 0
		if forcedCount > 0 then
			self._tfForcedStunThirdpersonFromStunned = forcedCount - 1
			self:_TFSetForcedStunThirdperson(false)
			return
		end

		local suppressedCount = self._tfSuppressedStunThirdpersonFromStunned or 0
		if suppressedCount > 0 then
			self._tfSuppressedStunThirdpersonFromStunned = suppressedCount - 1
		end
	end
end

function meta:OnAddOverhealed()
	self:AddPlayerState(PLAYERSTATE_OVERHEALED, true)
end

function meta:OnRemoveOverhealed()
	self:RemovePlayerState(PLAYERSTATE_OVERHEALED, true)
end

function meta:OnAddCritBoost()
	if SERVER and not self._tf_cond_to_state_bridge and GAMEMODE and GAMEMODE.StartCritBoost then
		GAMEMODE:StartCritBoost(self)
	end
	self:AddPlayerState(PLAYERSTATE_CRITBOOST, true)
end

function meta:OnRemoveCritBoost()
	if SERVER and not self._tf_cond_to_state_bridge and GAMEMODE and GAMEMODE.StopCritBoost then
		GAMEMODE:StopCritBoost(self)
	end
	self:RemovePlayerState(PLAYERSTATE_CRITBOOST, true)
end

function meta:OnAddOffenseBuff()
	if SERVER and not self._tf_cond_to_state_bridge and GAMEMODE and GAMEMODE.StartMiniCritBoost then
		GAMEMODE:StartMiniCritBoost(self)
	end
	self:AddPlayerState(PLAYERSTATE_MINICRIT, true)
end

function meta:OnRemoveOffenseBuff()
	if SERVER and not self._tf_cond_to_state_bridge and GAMEMODE and GAMEMODE.StopMiniCritBoost then
		GAMEMODE:StopMiniCritBoost(self)
	end
	self:RemovePlayerState(PLAYERSTATE_MINICRIT, true)
end

function meta:OnAddSpeedBoost()
	self:AddPlayerState(PLAYERSTATE_SPEED, true)
	if SERVER and self:IsPlayer() and self.ResetClassSpeed then
		self:ResetClassSpeed()
	end
end

function meta:OnRemoveSpeedBoost()
	self:RemovePlayerState(PLAYERSTATE_SPEED, true)
	if SERVER and self:IsPlayer() and self.ResetClassSpeed then
		self:ResetClassSpeed()
	end
end

function meta:OnAddHalloweenSpeedBoost()
	self:OnAddSpeedBoost()
end

function meta:OnRemoveHalloweenSpeedBoost()
	self:OnRemoveSpeedBoost()
end

local function get_invuln_fallback_material(ent)
	local t = ent:EntityTeam()
	if t == TEAM_BLU or t == TF_TEAM_PVE_INVADERS then
		return "models/effects/invulnfx_blue"
	end
	return "models/effects/invulnfx_red2"
end

local function has_full_invuln_cond(ent)
	return has_any_cond(ent, {
		TF_COND_INVULNERABLE,
		TF_COND_INVULNERABLE_USER_BUFF,
		TF_COND_INVULNERABLE_CARD_EFFECT,
	})
end

function meta:OnAddInvulnerable()
	if self.SetNWBool then
		self:SetNWBool("Invulnerable", true)
	end

	-- Fallback when gmcl_matproxy is not available: emulate basic uber look.
	if CLIENT and self:IsPlayer() and not matproxy and self.SetMaterial then
		self:SetMaterial(get_invuln_fallback_material(self))
	end

	self:RemoveCond(TF_COND_BURNING, true)
	self:RemoveCond(TF_COND_URINE, true)
	self:RemoveCond(TF_COND_BLEEDING, true)
	self:RemoveCond(TF_COND_MAD_MILK, true)
	self:RemoveCond(TF_COND_GAS, true)
	self:RemoveCond(TF_COND_PLAGUE, true)
end

-- Respawn-room visualizer protection should not force the full uber material.
function meta:OnAddInvulnerableHideUnlessDamaged()
	if has_full_invuln_cond(self) then
		if self.SetNWBool then
			self:SetNWBool("Invulnerable", true)
		end
		return
	end

	if self.SetNWBool then
		self:SetNWBool("Invulnerable", false)
	end
	if CLIENT and self:IsPlayer() and not matproxy and self.SetMaterial then
		self:SetMaterial("")
	end
end

function meta:OnRemoveInvulnerable()
	if has_any_cond(self, {
		TF_COND_INVULNERABLE,
		TF_COND_INVULNERABLE_USER_BUFF,
		TF_COND_INVULNERABLE_CARD_EFFECT,
		TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED,
	}) then
		return
	end

	if self.SetNWBool then
		self:SetNWBool("Invulnerable", false)
	end
	if CLIENT and self:IsPlayer() and not matproxy and self.SetMaterial then
		self:SetMaterial("")
	end
end

function meta:OnRemoveInvulnerableHideUnlessDamaged()
	if has_full_invuln_cond(self) then
		if self.SetNWBool then
			self:SetNWBool("Invulnerable", true)
		end
		return
	end

	if self.SetNWBool then
		self:SetNWBool("Invulnerable", false)
	end
	if CLIENT and self:IsPlayer() and not matproxy and self.SetMaterial then
		self:SetMaterial("")
	end
end

function meta:OnAddStealthed()
	if self.SetNWBool then
		self:SetNWBool("Stealthed", true)
		self:SetNWBool("Cloaked", true)
	end
	if SERVER and self:IsPlayer() and self.EmitSound then
		if not (self.InCond and self:InCond(TF_COND_FEIGN_DEATH)) then
			self:EmitSound("Player.Spy_Cloak")
		end
	end
	if SERVER and self.SetNoTarget then
		self:SetNoTarget(true)
	end
	if self.SetRenderMode and self.SetColor and self:IsPlayer() then
		self:SetRenderMode(RENDERMODE_TRANSALPHA)
		self:SetColor(Color(255, 255, 255, 40))
	end
end

function meta:OnRemoveStealthed()
	if has_any_cond(self, {
		TF_COND_STEALTHED,
		TF_COND_STEALTHED_USER_BUFF,
		TF_COND_STEALTHED_USER_BUFF_FADING,
	}) then
		return
	end

	if self.SetNWBool then
		self:SetNWBool("Stealthed", false)
		self:SetNWBool("Cloaked", false)
	end
	if SERVER and self:IsPlayer() and self.EmitSound then
		local soundName = "Player.Spy_UnCloak"
		local invis = self.GetWeapon and self:GetWeapon("tf_weapon_invis") or nil
		local quiet = IsValid(invis) and invis.GetAttributeValue and (tonumber(invis:GetAttributeValue("set_quiet_unstealth", 0)) or 0) > 0
		if quiet then
			soundName = "Player.Spy_UnCloakReduced"
		elseif IsValid(invis) and invis.HasFeignDeath and invis:HasFeignDeath() then
			soundName = "Player.Spy_UnCloakFeignDeath"
		end
		self:EmitSound(soundName)
	end
	if SERVER and self.SetNoTarget then
		self:SetNoTarget(false)
	end
	if self.SetColor and self:IsPlayer() then
		self:SetColor(Color(255, 255, 255, 255))
	end
	if self.SetRenderMode and self:IsPlayer() then
		self:SetRenderMode(RENDERMODE_NORMAL)
	end
end

function meta:OnAddPhase()
	if SERVER and self.SetNoTarget then
		self:SetNoTarget(true)
	end
	if self.SetRenderMode and self.SetColor and self:IsPlayer() then
		self:SetRenderMode(RENDERMODE_TRANSALPHA)
		self:SetColor(Color(255, 255, 255, 80))
	end
end

function meta:OnRemovePhase()
	if self:InCond(TF_COND_PHASE) or self:InCond(TF_COND_PASSTIME_INTERCEPTION) then
		return
	end
	if SERVER and self.SetNoTarget then
		self:SetNoTarget(false)
	end
	if self.SetColor and self:IsPlayer() then
		self:SetColor(Color(255, 255, 255, 255))
	end
	if self.SetRenderMode and self:IsPlayer() then
		self:SetRenderMode(RENDERMODE_NORMAL)
	end
end

local function cond_stack_add(self, key)
	self._tf_cond_stacks = self._tf_cond_stacks or {}
	self._tf_cond_stacks[key] = (self._tf_cond_stacks[key] or 0) + 1
	return self._tf_cond_stacks[key]
end

local function cond_stack_remove(self, key)
	self._tf_cond_stacks = self._tf_cond_stacks or {}
	self._tf_cond_stacks[key] = math.max(0, (self._tf_cond_stacks[key] or 0) - 1)
	return self._tf_cond_stacks[key]
end

local function cond_stack_count(self, key)
	return (self._tf_cond_stacks and self._tf_cond_stacks[key]) or 0
end

local function is_melee_weapon(wep)
	if not IsValid(wep) then return false end
	if wep.GetItemData then
		local data = wep:GetItemData()
		if data and isstring(data.item_slot) and string.lower(data.item_slot) == "melee" then
			return true
		end
	end
	if isstring(wep.item_slot) and string.upper(wep.item_slot) == "MELEE" then
		return true
	end
	return wep.GetSlot and wep:GetSlot() == 2
end

local function force_select_melee(self)
	if not SERVER or not self:IsPlayer() then return end
	local active = self:GetActiveWeapon()
	if is_melee_weapon(active) then return end
	for _, wep in ipairs(self:GetWeapons()) do
		if is_melee_weapon(wep) then
			self:SelectWeapon(wep:GetClass())
			return
		end
	end
end

local function update_no_weapon(self)
	if not self.SetNWBool then return end
	local should = cond_stack_count(self, "no_weapon") > 0
	self:SetNWBool("NoWeapon", should)
end

local function update_taunting(self)
	if not self.SetNWBool then return end
	self:SetNWBool("Taunting", cond_stack_count(self, "taunting") > 0)
end

local function update_speed_mult(self)
	self._tf_cond_speed = self._tf_cond_speed or {}
	local mult = 1
	for _, v in pairs(self._tf_cond_speed) do
		mult = mult * (tonumber(v) or 1)
	end
	self:SetNWFloat("TFCondSpeedMult", mult)
end

local function set_speed_mult(self, key, mult)
	self._tf_cond_speed = self._tf_cond_speed or {}
	self._tf_cond_speed[key] = mult
	update_speed_mult(self)
end

local function clear_speed_mult(self, key)
	if not self._tf_cond_speed then return end
	self._tf_cond_speed[key] = nil
	update_speed_mult(self)
end

local function update_cond_model_scale(self)
	if not SERVER or not self:IsPlayer() then return end
	if self._tf_cond_base_model_scale == nil then
		self._tf_cond_base_model_scale = self:GetModelScale()
	end

	local target = self._tf_cond_base_model_scale or 1
	if cond_stack_count(self, "giant") > 0 then
		target = target * 1.75
	elseif cond_stack_count(self, "tiny") > 0 then
		target = target * 0.65
	end
	self:SetModelScale(target, 0)
end

local function cond_regen_tick(self)
	if not IsValid(self) or not self:Alive() then return end
	if not GAMEMODE or not GAMEMODE.HealPlayer then return end

	local heal = 0
	if self:InCond(TF_COND_MEGAHEAL) then heal = math.max(heal, 16) end
	if self:InCond(TF_COND_HALLOWEEN_QUICK_HEAL) then heal = math.max(heal, 12) end
	if self:InCond(TF_COND_RUNE_REGEN) then heal = math.max(heal, 8) end
	if self:InCond(TF_COND_RUNE_KING) or self:InCond(TF_COND_KING_BUFFED) then heal = math.max(heal, 6) end
	if self:InCond(TF_COND_RADIUSHEAL) or self:InCond(TF_COND_RADIUSHEAL_ON_DAMAGE) then heal = math.max(heal, 4) end
	if heal > 0 then
		GAMEMODE:HealPlayer(nil, self, heal, true, false)
	end
end

local function update_regen_timer(self)
	if not SERVER then return end
	local timer_name = "TFCondRegen_" .. self:EntIndex()
	local should_regen = self:InCond(TF_COND_MEGAHEAL)
		or self:InCond(TF_COND_HALLOWEEN_QUICK_HEAL)
		or self:InCond(TF_COND_RUNE_REGEN)
		or self:InCond(TF_COND_RUNE_KING)
		or self:InCond(TF_COND_KING_BUFFED)
		or self:InCond(TF_COND_RADIUSHEAL)
		or self:InCond(TF_COND_RADIUSHEAL_ON_DAMAGE)

	if should_regen then
		timer.Create(timer_name, 1, 0, function()
			if not IsValid(self) then
				timer.Remove(timer_name)
				return
			end
			cond_regen_tick(self)
		end)
	else
		timer.Remove(timer_name)
	end
end

function meta:OnAddZoomed()
	self:SetNWBool("Zoomed", true)
end

function meta:OnRemoveZoomed()
	self:SetNWBool("Zoomed", false)
end

function meta:OnAddTaunting()
	cond_stack_add(self, "taunting")
	cond_stack_add(self, "no_weapon")
	cond_stack_add(self, "freeze_input")
	update_taunting(self)
	update_no_weapon(self)
end

function meta:OnRemoveTaunting()
	cond_stack_remove(self, "taunting")
	cond_stack_remove(self, "no_weapon")
	cond_stack_remove(self, "freeze_input")
	update_taunting(self)
	update_no_weapon(self)
end

function meta:OnAddSodaPopperHype()
	set_speed_mult(self, "hype", 1.2)
	self:OnAddSpeedBoost()
end

function meta:OnRemoveSodaPopperHype()
	clear_speed_mult(self, "hype")
	self:OnRemoveSpeedBoost()
end

function meta:OnAddShieldCharge()
	set_speed_mult(self, "shield_charge", 1.35)
	cond_stack_add(self, "melee_only")
	force_select_melee(self)
end

function meta:OnRemoveShieldCharge()
	clear_speed_mult(self, "shield_charge")
	cond_stack_remove(self, "melee_only")
end

function meta:OnAddDemoCharge()
	self:OnAddShieldCharge()
end

function meta:OnRemoveDemoCharge()
	self:OnRemoveShieldCharge()
end

function meta:OnAddEnergyDrinkBuff()
	set_speed_mult(self, "energy", 1.25)
end

function meta:OnRemoveEnergyDrinkBuff()
	clear_speed_mult(self, "energy")
end

function meta:OnAddDefenseBuff()
	self:SetNWBool("DefenseBuff", true)
end

function meta:OnRemoveDefenseBuff()
	if self:InCond(TF_COND_DEFENSEBUFF) or self:InCond(TF_COND_DEFENSEBUFF_NO_CRIT_BLOCK) or self:InCond(TF_COND_DEFENSEBUFF_HIGH) then
		return
	end
	self:SetNWBool("DefenseBuff", false)
end

function meta:OnAddOffenseHealthRegenBuff()
	update_regen_timer(self)
end

function meta:OnRemoveOffenseHealthRegenBuff()
	update_regen_timer(self)
end

function meta:OnAddNoHealingDamageBuff()
	self:SetNWBool("NoHealing", true)
end

function meta:OnRemoveNoHealingDamageBuff()
	self:SetNWBool("NoHealing", false)
end

function meta:OnAddRadiusHeal()
	update_regen_timer(self)
end

function meta:OnRemoveRadiusHeal()
	update_regen_timer(self)
end

function meta:OnAddRadiusHealOnDamage()
	update_regen_timer(self)
end

function meta:OnRemoveRadiusHealOnDamage()
	update_regen_timer(self)
end

function meta:OnAddMegaHeal()
	update_regen_timer(self)
end

function meta:OnRemoveMegaHeal()
	update_regen_timer(self)
end

function meta:OnAddMedEffectUberBulletResist()
	self:SetNWBool("BulletResistUber", true)
end

function meta:OnRemoveMedEffectUberBulletResist()
	self:SetNWBool("BulletResistUber", false)
end

function meta:OnAddMedEffectUberBlastResist()
	self:SetNWBool("BlastResistUber", true)
end

function meta:OnRemoveMedEffectUberBlastResist()
	self:SetNWBool("BlastResistUber", false)
end

function meta:OnAddMedEffectUberFireResist()
	self:SetNWBool("FireResistUber", true)
end

function meta:OnRemoveMedEffectUberFireResist()
	self:SetNWBool("FireResistUber", false)
end

function meta:OnAddMedEffectSmallBulletResist()
	self:SetNWBool("BulletResistSmall", true)
end

function meta:OnRemoveMedEffectSmallBulletResist()
	self:SetNWBool("BulletResistSmall", false)
end

function meta:OnAddMedEffectSmallBlastResist()
	self:SetNWBool("BlastResistSmall", true)
end

function meta:OnRemoveMedEffectSmallBlastResist()
	self:SetNWBool("BlastResistSmall", false)
end

function meta:OnAddMedEffectSmallFireResist()
	self:SetNWBool("FireResistSmall", true)
end

function meta:OnRemoveMedEffectSmallFireResist()
	self:SetNWBool("FireResistSmall", false)
end

function meta:OnAddStealthedUserBuffFade()
	self:OnAddStealthed()
end

function meta:OnRemoveStealthedUserBuffFade()
	self:OnRemoveStealthed()
end

function meta:OnAddBulletImmune()
	self:SetNWBool("BulletImmune", true)
end

function meta:OnRemoveBulletImmune()
	self:SetNWBool("BulletImmune", false)
end

function meta:OnAddBlastImmune()
	self:SetNWBool("BlastImmune", true)
end

function meta:OnRemoveBlastImmune()
	self:SetNWBool("BlastImmune", false)
end

function meta:OnAddFireImmune()
	self:SetNWBool("FireImmune", true)
end

function meta:OnRemoveFireImmune()
	self:SetNWBool("FireImmune", false)
end

function meta:OnAddHalloweenQuickHeal()
	update_regen_timer(self)
end

function meta:OnRemoveHalloweenQuickHeal()
	update_regen_timer(self)
end

function meta:OnAddHalloweenGiant()
	cond_stack_add(self, "giant")
	set_speed_mult(self, "giant", 0.85)
	update_cond_model_scale(self)
end

function meta:OnRemoveHalloweenGiant()
	cond_stack_remove(self, "giant")
	clear_speed_mult(self, "giant")
	update_cond_model_scale(self)
end

function meta:OnAddHalloweenTiny()
	cond_stack_add(self, "tiny")
	set_speed_mult(self, "tiny", 1.2)
	update_cond_model_scale(self)
end

function meta:OnRemoveHalloweenTiny()
	cond_stack_remove(self, "tiny")
	clear_speed_mult(self, "tiny")
	update_cond_model_scale(self)
end

function meta:OnAddCondParachute()
	set_speed_mult(self, "parachute", 0.75)
end

function meta:OnRemoveCondParachute()
	clear_speed_mult(self, "parachute")
end

function meta:OnAddHalloweenKart()
	cond_stack_add(self, "no_weapon")
	if self.SetNWBool then
		self:SetNWBool("HalloweenKart", true)
	end
	if CLIENT then
		self:_TFSetForcedStunThirdperson(true)
	end
	if SERVER and self:IsPlayer() then
		local entId = self:EntIndex()
		self.__TFKartTurnInput = 0
		self.__TFKartDriveInput = 0
		self.__TFKartHornWasDown = false
		self.__TFKartBoostWasDown = false
		self:SetNWFloat("TFKartBoostEndTime", 0)
		self:SetNWFloat("TFKartBoostCooldownEndTime", 0)

		local kartModelName = "TFCondKartModel" .. entId
		for _, ent in ipairs(ents.FindByName(kartModelName)) do
			ent:Remove()
		end

		local kart = ents.Create("base_gmodentity")
		if IsValid(kart) then
			kart:SetModel("models/player/items/taunts/bumpercar/parts/bumpercar.mdl")
			kart:SetAngles(self:GetAngles())
			kart:SetPos(self:GetPos())
			kart:Spawn()
			kart:Activate()
			kart:SetParent(self)
			kart:AddEffects(EF_BONEMERGE)
			kart:SetName(kartModelName)
		end

		self:EmitSound("BumperCar.Spawn")
		timer.Create("TFKartLoopStart_" .. entId, 0.35, 1, function()
			if not IsValid(self) or not self:InCond(TF_COND_HALLOWEEN_KART) then return end
			self:EmitSound("BumperCar.GoLoop")
		end)
	end
	update_no_weapon(self)
end

function meta:OnRemoveHalloweenKart()
	cond_stack_remove(self, "no_weapon")
	if self.SetNWBool then
		self:SetNWBool("HalloweenKart", false)
	end
	if CLIENT then
		self:_TFSetForcedStunThirdperson(false)
	end
	if SERVER and self:IsPlayer() then
		local entId = self:EntIndex()
		self.__TFKartTurnInput = 0
		self.__TFKartDriveInput = 0
		self.__TFKartHornWasDown = false
		self.__TFKartBoostWasDown = false
		self:SetNWFloat("TFKartBoostEndTime", 0)
		self:SetNWFloat("TFKartBoostCooldownEndTime", 0)
		self:RemoveCond(TF_COND_HALLOWEEN_KART_DASH, true)

		timer.Remove("TFKartLoopStart_" .. entId)
		local kartModelName = "TFCondKartModel" .. entId
		for _, ent in ipairs(ents.FindByName(kartModelName)) do
			ent:Remove()
		end

		self:StopSound("BumperCar.GoLoop")
		self:StopSound("Taunt.BumperCarGoLoop")
		self:EmitSound("Taunt.BumperCarQuit")
	end
	update_no_weapon(self)
end

function meta:OnAddMeleeOnly()
	cond_stack_add(self, "melee_only")
	force_select_melee(self)
end

function meta:OnRemoveMeleeOnly()
	cond_stack_remove(self, "melee_only")
end

function meta:OnAddFreezeInput()
	cond_stack_add(self, "freeze_input")
end

function meta:OnRemoveFreezeInput()
	cond_stack_remove(self, "freeze_input")
end

function meta:OnAddCannotSwitchFromMelee()
	cond_stack_add(self, "cant_switch_melee")
	force_select_melee(self)
end

function meta:OnRemoveCannotSwitchFromMelee()
	cond_stack_remove(self, "cant_switch_melee")
end

function meta:GetCarryingRuneType()
	if not self.InCond then
		return TF_RUNE_NONE
	end

	for runeType = TF_RUNE_STRENGTH, TF_RUNE_SUPERNOVA do
		local cond = TF_RUNE_COND_BY_TYPE[runeType]
		if cond and self:InCond(cond) then
			return runeType
		end
	end

	return TF_RUNE_NONE
end

function meta:IsCarryingRune()
	return self:GetCarryingRuneType() ~= TF_RUNE_NONE
end

function meta:SetRuneCharge(value)
	value = math.Clamp(tonumber(value) or 0, 0, 100)
	self:SetNWFloat("TFRuneCharge", value)
	self:SetNWBool("TFRuneCharged", value >= 100)
end

function meta:GetRuneCharge()
	return math.Clamp(tonumber(self:GetNWFloat("TFRuneCharge", 0)) or 0, 0, 100)
end

function meta:IsRuneCharged()
	return self:GetRuneCharge() >= 100
end

function meta:CanRuneCharge()
	return self.InCond and self:InCond(TF_COND_RUNE_SUPERNOVA) or false
end

function meta:SetCarryingRuneType(runeType)
	if not self.AddCond or not self.RemoveCond then return end

	local wanted = tonumber(runeType)
	if wanted == nil then
		wanted = TF_RUNE_NONE
	end

	if wanted == self:GetCarryingRuneType() then return end

	self:SetRuneCharge(0)

	for candidate, cond in pairs(TF_RUNE_COND_BY_TYPE) do
		if candidate == wanted then
			self:AddCond(cond, PERMANENT_CONDITION or -1, self)
		elseif self:InCond(cond) then
			self:RemoveCond(cond, true)
		end
	end

	if wanted == TF_RUNE_NONE then
		self:SetNWInt("TFCarryingRuneType", TF_RUNE_NONE)
	end
end

function meta:DropRune()
	if not SERVER then return nil end

	local runeType = self:GetCarryingRuneType()
	if runeType == TF_RUNE_NONE then return nil end

	self:SetCarryingRuneType(TF_RUNE_NONE)

	local dropped = ents.Create("item_powerup_rune")
	if not IsValid(dropped) then return nil end

	dropped:SetPos(self:GetPos() + Vector(0, 0, 48))
	dropped:SetAngles(Angle(0, self:EyeAngles().y, 0))
	dropped:Spawn()
	dropped:Activate()
	if dropped.SetRuneType then
		dropped:SetRuneType(runeType)
	end
	if dropped.DropWithGravity then
		dropped:DropWithGravity(self:GetVelocity() + self:GetAimVector() * 150)
	end
	dropped:SetOwner(self)
	dropped.NextActive = CurTime() + 0.4
	return dropped
end

local function sync_carrying_rune_network(self, preferredType)
	if not IsValid(self) then return end
	local runeType = preferredType
	if runeType == nil then
		runeType = self.GetCarryingRuneType and self:GetCarryingRuneType() or TF_RUNE_NONE
	end
	self:SetNWInt("TFCarryingRuneType", runeType or TF_RUNE_NONE)
end

function meta:OnAddRuneResist()
	self:OnAddDefenseBuff()
	sync_carrying_rune_network(self, TF_RUNE_RESIST)
end

function meta:OnRemoveRuneResist()
	self:OnRemoveDefenseBuff()
	sync_carrying_rune_network(self)
end

function meta:OnAddRuneStrength()
	self:OnAddCritBoost()
	sync_carrying_rune_network(self, TF_RUNE_STRENGTH)
end

function meta:OnRemoveRuneStrength()
	self:OnRemoveCritBoost()
	sync_carrying_rune_network(self)
end

function meta:OnAddRuneHaste()
	set_speed_mult(self, "rune_haste", 1.25)
	sync_carrying_rune_network(self, TF_RUNE_HASTE)
end

function meta:OnRemoveRuneHaste()
	clear_speed_mult(self, "rune_haste")
	sync_carrying_rune_network(self)
end

function meta:OnAddRuneRegen()
	update_regen_timer(self)
	sync_carrying_rune_network(self, TF_RUNE_REGEN)
end

function meta:OnRemoveRuneRegen()
	update_regen_timer(self)
	sync_carrying_rune_network(self)
end

function meta:OnAddRuneVampire()
	self:SetNWBool("RuneVampire", true)
	sync_carrying_rune_network(self, TF_RUNE_VAMPIRE)
end

function meta:OnRemoveRuneVampire()
	self:SetNWBool("RuneVampire", false)
	sync_carrying_rune_network(self)
end

function meta:OnAddRuneReflect()
	self:SetNWBool("RuneReflect", true)
	sync_carrying_rune_network(self, TF_RUNE_REFLECT)
end

function meta:OnRemoveRuneReflect()
	self:SetNWBool("RuneReflect", false)
	sync_carrying_rune_network(self)
end

function meta:OnAddRunePrecision()
	self:OnAddCritBoost()
	sync_carrying_rune_network(self, TF_RUNE_PRECISION)
end

function meta:OnRemoveRunePrecision()
	self:OnRemoveCritBoost()
	sync_carrying_rune_network(self)
end

function meta:OnAddRuneAgility()
	set_speed_mult(self, "rune_agility", 1.15)
	sync_carrying_rune_network(self, TF_RUNE_AGILITY)
end

function meta:OnRemoveRuneAgility()
	clear_speed_mult(self, "rune_agility")
	sync_carrying_rune_network(self)
end

function meta:OnAddRuneKnockout()
	self:OnAddOffenseBuff()
	sync_carrying_rune_network(self, TF_RUNE_KNOCKOUT)
end

function meta:OnRemoveRuneKnockout()
	self:OnRemoveOffenseBuff()
	sync_carrying_rune_network(self)
end

function meta:OnAddRuneImbalance()
	self:SetNWBool("RuneImbalance", true)
end

function meta:OnRemoveRuneImbalance()
	self:SetNWBool("RuneImbalance", false)
end

function meta:OnAddRuneKing()
	self:OnAddOffenseBuff()
	self:OnAddDefenseBuff()
	set_speed_mult(self, "rune_king", 1.1)
	update_regen_timer(self)
	sync_carrying_rune_network(self, TF_RUNE_KING)
end

function meta:OnRemoveRuneKing()
	self:OnRemoveOffenseBuff()
	self:OnRemoveDefenseBuff()
	clear_speed_mult(self, "rune_king")
	update_regen_timer(self)
	sync_carrying_rune_network(self)
end

function meta:OnAddKingBuff()
	self:OnAddOffenseBuff()
	update_regen_timer(self)
end

function meta:OnRemoveKingBuff()
	self:OnRemoveOffenseBuff()
	update_regen_timer(self)
end

function meta:OnAddRuneSupernova()
	self:OnAddCritBoost()
	self:OnAddInvulnerable()
	self:SetRuneCharge(0)
	sync_carrying_rune_network(self, TF_RUNE_SUPERNOVA)
end

function meta:OnRemoveRuneSupernova()
	self:OnRemoveCritBoost()
	self:OnRemoveInvulnerable()
	self:SetRuneCharge(0)
	sync_carrying_rune_network(self)
end

function meta:OnAddPasstimeInterception()
	self:OnAddPhase()
end

function meta:OnRemovePasstimeInterception()
	self:OnRemovePhase()
end

function meta:OnAddPlague()
	self:OnAddCondGas()
end

function meta:OnRemovePlague()
	self:OnRemoveCondGas()
end

function meta:OnAddRunePlague()
	self:OnAddCondGas()
	sync_carrying_rune_network(self, TF_RUNE_PLAGUE)
end

function meta:OnRemoveRunePlague()
	self:OnRemoveCondGas()
	sync_carrying_rune_network(self)
end

function meta:OnAddCompetitiveWinner()
	self:OnAddCritBoost()
end

function meta:OnRemoveCompetitiveWinner()
	self:OnRemoveCritBoost()
end

function meta:OnAddCompetitiveLoser()
	self:OnAddMarkedForDeathSilent()
	if CLIENT then
		self:_TFSetForcedStunThirdperson(true)
	end
end

function meta:OnRemoveCompetitiveLoser()
	self:OnRemoveMarkedForDeathSilent()
	if CLIENT then
		self:_TFSetForcedStunThirdperson(false)
	end
end

function meta:OnAddBurningPyro()
	self:OnAddBurning()
end

function meta:OnRemoveBurningPyro()
	self:OnRemoveBurning()
end

function meta:OnAddRocketPack()
	set_speed_mult(self, "rocketpack", 1.15)
end

function meta:OnRemoveRocketPack()
	clear_speed_mult(self, "rocketpack")
end

function meta:OnAddHalloweenHellHeal()
	update_regen_timer(self)
end

function meta:OnRemoveHalloweenHellHeal()
	update_regen_timer(self)
end

function meta:OnAddTmpDamageBonus()
	self:OnAddOffenseBuff()
end

function meta:OnRemoveTmpDamageBonus()
	self:OnRemoveOffenseBuff()
end

local function refresh_speed_from_conditions(self)
	if self.TeamFortress_SetSpeed then
		self:TeamFortress_SetSpeed()
		return
	end
	if SERVER and self.ResetClassSpeed then
		self:ResetClassSpeed()
	end
end

function meta:OnAddReprogrammed()
	self:AddPlayerState(PLAYERSTATE_REPROGRAMMED, true)
	if self.SetNWBool then
		self:SetNWBool("Reprogrammed", true)
	end
end

function meta:OnRemoveReprogrammed()
	self:RemovePlayerState(PLAYERSTATE_REPROGRAMMED, true)
	if self.SetNWBool then
		self:SetNWBool("Reprogrammed", false)
	end
end

function meta:OnAddDisguisedAsDispenser()
	refresh_speed_from_conditions(self)
	if self.SetNWBool then
		self:SetNWBool("DisguisedAsDispenser", true)
	end
	if SERVER and self.SetNWInt then
		local myTeam = self:Team()
		local disguiseTeam = TEAM_BLU
		if myTeam == TEAM_BLU or myTeam == TF_TEAM_PVE_INVADERS then
			disguiseTeam = TEAM_RED
		elseif myTeam == TEAM_RED then
			disguiseTeam = TEAM_BLU
		end
		self:SetNWInt("TFDispenserDisguiseTeam", disguiseTeam)
	end
end

function meta:OnRemoveDisguisedAsDispenser()
	refresh_speed_from_conditions(self)
	if self.SetNWBool then
		self:SetNWBool("DisguisedAsDispenser", false)
	end
	if SERVER and self.SetNWInt then
		self:SetNWInt("TFDispenserDisguiseTeam", -1)
	end
end

local function set_cond_flag(self, name, enabled)
	if self.SetNWBool then
		self:SetNWBool(name, enabled and true or false)
	end
end

local function update_healing_received_mult(self)
	if not self.SetNWFloat or not self.InCond then return end

	local mult = 1
	if TF_COND_MEDIGUN_DEBUFF and self:InCond(TF_COND_MEDIGUN_DEBUFF) then
		mult = mult * 0.75
	end
	if TF_COND_HEALING_DEBUFF and self:InCond(TF_COND_HEALING_DEBUFF) then
		mult = mult * 0.5
	end

	self:SetNWFloat("TFCondHealingMult", mult)
end

function meta:OnAddAiming()
	set_cond_flag(self, "Aiming", true)
	refresh_speed_from_conditions(self)
end

function meta:OnRemoveAiming()
	set_cond_flag(self, "Aiming", false)
	refresh_speed_from_conditions(self)
end

function meta:OnAddStealthedBlink() set_cond_flag(self, "StealthedBlink", true) end
function meta:OnRemoveStealthedBlink() set_cond_flag(self, "StealthedBlink", false) end
function meta:OnAddSelectedToTeleport() set_cond_flag(self, "SelectedToTeleport", true) end
function meta:OnRemoveSelectedToTeleport() set_cond_flag(self, "SelectedToTeleport", false) end
function meta:OnAddHealthBuff() set_cond_flag(self, "HealthBuff", true) end
function meta:OnRemoveHealthBuff() set_cond_flag(self, "HealthBuff", false) end
function meta:OnAddInvulnerableWearingOff() set_cond_flag(self, "InvulnerableWearingOff", true) end
function meta:OnRemoveInvulnerableWearingOff() set_cond_flag(self, "InvulnerableWearingOff", false) end
function meta:OnAddDisguiseWearingOff() set_cond_flag(self, "DisguiseWearingOff", true) end
function meta:OnRemoveDisguiseWearingOff() set_cond_flag(self, "DisguiseWearingOff", false) end
function meta:OnAddMedigunDebuff()
	set_cond_flag(self, "MedigunDebuff", true)
	update_healing_received_mult(self)
end
function meta:OnRemoveMedigunDebuff()
	set_cond_flag(self, "MedigunDebuff", false)
	update_healing_received_mult(self)
end
function meta:OnAddPreventDeath() set_cond_flag(self, "PreventDeath", true) end
function meta:OnRemovePreventDeath() set_cond_flag(self, "PreventDeath", false) end
function meta:OnAddHalloweenInHell() set_cond_flag(self, "HalloweenInHell", true) end
function meta:OnRemoveHalloweenInHell() set_cond_flag(self, "HalloweenInHell", false) end
function meta:OnAddObscuredSmoke() set_cond_flag(self, "ObscuredSmoke", true) end
function meta:OnRemoveObscuredSmoke() set_cond_flag(self, "ObscuredSmoke", false) end
function meta:OnAddBlastJumping() set_cond_flag(self, "BlastJumping", true) end
function meta:OnRemoveBlastJumping() set_cond_flag(self, "BlastJumping", false) end
function meta:OnAddGrapplingHook() set_cond_flag(self, "GrapplingHook", true) end
function meta:OnRemoveGrapplingHook() set_cond_flag(self, "GrapplingHook", false) end
function meta:OnAddGrapplingHookSafeFall() set_cond_flag(self, "GrapplingHookSafeFall", true) end
function meta:OnRemoveGrapplingHookSafeFall() set_cond_flag(self, "GrapplingHookSafeFall", false) end
function meta:OnAddGrapplingHookBleeding()
	set_cond_flag(self, "GrapplingHookBleeding", true)
	self:OnAddBleeding()
end
function meta:OnRemoveGrapplingHookBleeding()
	set_cond_flag(self, "GrapplingHookBleeding", false)
	if not self:InCond(TF_COND_BLEEDING) then
		self:OnRemoveBleeding()
	end
end
function meta:OnAddAfterburnImmune() set_cond_flag(self, "AfterburnImmune", true) end
function meta:OnRemoveAfterburnImmune() set_cond_flag(self, "AfterburnImmune", false) end
function meta:OnAddSwimmingNoEffects() set_cond_flag(self, "SwimmingNoEffects", true) end
function meta:OnRemoveSwimmingNoEffects() set_cond_flag(self, "SwimmingNoEffects", false) end
function meta:OnAddTeamGlows() set_cond_flag(self, "TeamGlows", true) end
function meta:OnRemoveTeamGlows() set_cond_flag(self, "TeamGlows", false) end
function meta:OnAddKnockedIntoAir() set_cond_flag(self, "KnockedIntoAir", true) end
function meta:OnRemoveKnockedIntoAir() set_cond_flag(self, "KnockedIntoAir", false) end
function meta:OnAddHealingDebuff()
	set_cond_flag(self, "HealingDebuff", true)
	update_healing_received_mult(self)
end
function meta:OnRemoveHealingDebuff()
	set_cond_flag(self, "HealingDebuff", false)
	update_healing_received_mult(self)
end
function meta:OnAddGrappledToPlayer() set_cond_flag(self, "GrappledToPlayer", true) end
function meta:OnRemoveGrappledToPlayer() set_cond_flag(self, "GrappledToPlayer", false) end
function meta:OnAddGrappledByPlayer() set_cond_flag(self, "GrappledByPlayer", true) end
function meta:OnRemoveGrappledByPlayer() set_cond_flag(self, "GrappledByPlayer", false) end
function meta:OnAddLostFooting() set_cond_flag(self, "LostFooting", true) end
function meta:OnRemoveLostFooting() set_cond_flag(self, "LostFooting", false) end
function meta:OnAddAirCurrent() set_cond_flag(self, "AirCurrent", true) end
function meta:OnRemoveAirCurrent() set_cond_flag(self, "AirCurrent", false) end
function meta:OnAddPowerupModeDominant() set_cond_flag(self, "PowerupDominant", true) end
function meta:OnRemovePowerupModeDominant() set_cond_flag(self, "PowerupDominant", false) end
function meta:OnAddImmuneToPushback() set_cond_flag(self, "ImmuneToPushback", true) end
function meta:OnRemoveImmuneToPushback() set_cond_flag(self, "ImmuneToPushback", false) end
function meta:OnAddDoNotUse0() end
function meta:OnRemoveDoNotUse0() end

function meta:OnAddFeignDeath()
	set_cond_flag(self, "FeignDeath", true)
	if not self:InCond(TF_COND_STEALTHED) then
		self:AddCond(TF_COND_STEALTHED, PERMANENT_CONDITION or -1, self)
	end
	local duration = 3.0
	local invis = self.GetWeapon and self:GetWeapon("tf_weapon_invis") or nil
	if IsValid(invis) and invis.GetFeignDeathSpeedDuration then
		duration = tonumber(invis:GetFeignDeathSpeedDuration()) or duration
	end
	if TF_COND_SPEED_BOOST then
		self:AddCond(TF_COND_SPEED_BOOST, duration, self)
	end
	if TF_COND_AFTERBURN_IMMUNE then
		self:AddCond(TF_COND_AFTERBURN_IMMUNE, duration, self)
	end
end

function meta:OnRemoveFeignDeath() set_cond_flag(self, "FeignDeath", false) end
function meta:OnAddDisguising() set_cond_flag(self, "Disguising", true) end
function meta:OnRemoveDisguising() set_cond_flag(self, "Disguising", false) end
function meta:OnAddDisguised() set_cond_flag(self, "Disguised", true) end
function meta:OnRemoveDisguised() set_cond_flag(self, "Disguised", false) end
function meta:OnAddDemoBuff() set_cond_flag(self, "DemoBuff", true) end
function meta:OnRemoveDemoBuff() set_cond_flag(self, "DemoBuff", false) end
function meta:OnAddSapped() set_cond_flag(self, "Sapped", true) end
function meta:OnRemoveSapped() set_cond_flag(self, "Sapped", false) end
function meta:OnAddHalloweenBombHead() set_cond_flag(self, "HalloweenBombHead", true) end
function meta:OnRemoveHalloweenBombHead() set_cond_flag(self, "HalloweenBombHead", false) end
function meta:OnAddHalloweenThriller() set_cond_flag(self, "HalloweenThriller", true) end
function meta:OnRemoveHalloweenThriller() set_cond_flag(self, "HalloweenThriller", false) end
function meta:OnAddMVMBotRadiowave() self:OnAddStunned() end
function meta:OnRemoveMVMBotRadiowave() self:OnRemoveStunned() end
function meta:OnAddHalloweenGhostMode() set_cond_flag(self, "HalloweenGhostMode", true) end
function meta:OnRemoveHalloweenGhostMode() set_cond_flag(self, "HalloweenGhostMode", false) end
function meta:OnAddHalloweenKartDash() set_cond_flag(self, "HalloweenKartDash", true) end
function meta:OnRemoveHalloweenKartDash() set_cond_flag(self, "HalloweenKartDash", false) end
function meta:OnAddBalloonHead() set_cond_flag(self, "BalloonHead", true) end
function meta:OnRemoveBalloonHead() set_cond_flag(self, "BalloonHead", false) end
function meta:OnAddSwimmingCurse() set_cond_flag(self, "SwimmingCurse", true) end
function meta:OnRemoveSwimmingCurse() set_cond_flag(self, "SwimmingCurse", false) end
function meta:OnAddHalloweenKartCage() set_cond_flag(self, "HalloweenKartCage", true) end
function meta:OnRemoveHalloweenKartCage() set_cond_flag(self, "HalloweenKartCage", false) end
function meta:OnAddGrapplingHookLatched() set_cond_flag(self, "GrapplingHookLatched", true) end
function meta:OnRemoveGrapplingHookLatched() set_cond_flag(self, "GrapplingHookLatched", false) end
function meta:OnAddInPurgatory() set_cond_flag(self, "InPurgatory", true) end
function meta:OnRemoveInPurgatory() set_cond_flag(self, "InPurgatory", false) end

local noop = function() end
for _, fn in ipairs({
	"OnAddFeignDeath", "OnRemoveFeignDeath",
	"OnAddDisguising", "OnRemoveDisguising",
	"OnAddDisguised", "OnRemoveDisguised", "OnAddDemoBuff", "OnRemoveDemoBuff", "OnAddSapped",
	"OnRemoveSapped", "OnAddReprogrammed", "OnRemoveReprogrammed",
	"OnAddDisguisedAsDispenser", "OnRemoveDisguisedAsDispenser",
	"OnAddHalloweenBombHead", "OnRemoveHalloweenBombHead", "OnAddHalloweenThriller",
	"OnRemoveHalloweenThriller",
	"OnAddMVMBotRadiowave", "OnRemoveMVMBotRadiowave", "OnAddHalloweenQuickHeal",
	"OnRemoveHalloweenQuickHeal", "OnAddHalloweenGhostMode", "OnRemoveHalloweenGhostMode",
	"OnAddHalloweenKartDash", "OnRemoveHalloweenKartDash", "OnAddHalloweenKart",
	"OnRemoveHalloweenKart", "OnAddBalloonHead", "OnRemoveBalloonHead", "OnAddSwimmingCurse",
	"OnRemoveSwimmingCurse", "OnAddHalloweenKartCage", "OnRemoveHalloweenKartCage",
	"OnAddGrapplingHookLatched", "OnRemoveGrapplingHookLatched", "OnAddInPurgatory", "OnRemoveInPurgatory",
	"OnRemoveInvulnerableWearingOff",
}) do
	if not meta[fn] then
		meta[fn] = noop
	end
end

function meta:OnConditionAdded(eCond)
	if eCond == TF_COND_CRITBOOSTED_FIRST_BLOOD then
		self:SetFirstBloodBoosted(true)
		self:OnAddCritBoost()
		return
	end

	local cond_handlers = {
		[TF_COND_AIMING] = "OnAddAiming",
		[TF_COND_ZOOMED] = "OnAddZoomed",
		[TF_COND_TMPDAMAGEBONUS] = "OnAddTmpDamageBonus",
		[TF_COND_HEALTH_OVERHEALED] = "OnAddOverhealed",
		[TF_COND_FEIGN_DEATH] = "OnAddFeignDeath",
		[TF_COND_STEALTHED] = "OnAddStealthed",
		[TF_COND_STEALTHED_BLINK] = "OnAddStealthedBlink",
		[TF_COND_STEALTHED_USER_BUFF] = "OnAddStealthed",
		[TF_COND_SELECTED_TO_TELEPORT] = "OnAddSelectedToTeleport",
		[TF_COND_INVULNERABLE] = "OnAddInvulnerable",
		[TF_COND_INVULNERABLE_WEARINGOFF] = "OnAddInvulnerableWearingOff",
		[TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED] = "OnAddInvulnerableHideUnlessDamaged",
		[TF_COND_INVULNERABLE_USER_BUFF] = "OnAddInvulnerable",
		[TF_COND_INVULNERABLE_CARD_EFFECT] = "OnAddInvulnerable",
		[TF_COND_TELEPORTED] = "OnAddTeleported",
		[TF_COND_BURNING] = "OnAddBurning",
		[TF_COND_CRITBOOSTED] = "OnAddCritBoost",
		[TF_COND_CRITBOOSTED_DEMO_CHARGE] = "OnAddDemoCharge",
		[TF_COND_CRITBOOSTED_PUMPKIN] = "OnAddCritBoost",
		[TF_COND_CRITBOOSTED_USER_BUFF] = "OnAddCritBoost",
		[TF_COND_CRITBOOSTED_BONUS_TIME] = "OnAddCritBoost",
		[TF_COND_CRITBOOSTED_CTF_CAPTURE] = "OnAddCritBoost",
		[TF_COND_CRITBOOSTED_ON_KILL] = "OnAddCritBoost",
		[TF_COND_CRITBOOSTED_RAGE_BUFF] = "OnAddCritBoost",
		[TF_COND_SNIPERCHARGE_RAGE_BUFF] = "OnAddCritBoost",
		[TF_COND_CRITBOOSTED_CARD_EFFECT] = "OnAddCritBoost",
		[TF_COND_CRITBOOSTED_RUNE_TEMP] = "OnAddCritBoost",
		[TF_COND_SODAPOPPER_HYPE] = "OnAddSodaPopperHype",
		[TF_COND_DISGUISING] = "OnAddDisguising",
		[TF_COND_DISGUISED] = "OnAddDisguised",
		[TF_COND_URINE] = "OnAddUrine",
		[TF_COND_MARKEDFORDEATH] = "OnAddMarkedForDeath",
		[TF_COND_BLEEDING] = "OnAddBleeding",
		[TF_COND_TAUNTING] = "OnAddTaunting",
		[TF_COND_STUNNED] = "OnAddStunned",
		[TF_COND_PHASE] = "OnAddPhase",
		[TF_COND_OFFENSEBUFF] = "OnAddOffenseBuff",
		[TF_COND_DEFENSEBUFF] = "OnAddDefenseBuff",
		[TF_COND_DEFENSEBUFF_NO_CRIT_BLOCK] = "OnAddDefenseBuff",
		[TF_COND_DEFENSEBUFF_HIGH] = "OnAddDefenseBuff",
		[TF_COND_REGENONDAMAGEBUFF] = "OnAddOffenseHealthRegenBuff",
		[TF_COND_HEALTH_BUFF] = "OnAddHealthBuff",
		[TF_COND_NOHEALINGDAMAGEBUFF] = "OnAddNoHealingDamageBuff",
		[TF_COND_SHIELD_CHARGE] = "OnAddShieldCharge",
		[TF_COND_DEMO_BUFF] = "OnAddDemoBuff",
		[TF_COND_ENERGY_BUFF] = "OnAddEnergyDrinkBuff",
		[TF_COND_RADIUSHEAL] = "OnAddRadiusHeal",
		[TF_COND_MEGAHEAL] = "OnAddMegaHeal",
		[TF_COND_MAD_MILK] = "OnAddMadMilk",
		[TF_COND_SPEED_BOOST] = "OnAddSpeedBoost",
		[TF_COND_SAPPED] = "OnAddSapped",
		[TF_COND_REPROGRAMMED] = "OnAddReprogrammed",
		[TF_COND_DISGUISE_WEARINGOFF] = "OnAddDisguiseWearingOff",
		[TF_COND_PASSTIME_PENALTY_DEBUFF] = "OnAddMarkedForDeathSilent",
		[TF_COND_MARKEDFORDEATH_SILENT] = "OnAddMarkedForDeathSilent",
		[TF_COND_DISGUISED_AS_DISPENSER] = "OnAddDisguisedAsDispenser",
		[TF_COND_HALLOWEEN_BOMB_HEAD] = "OnAddHalloweenBombHead",
		[TF_COND_HALLOWEEN_THRILLER] = "OnAddHalloweenThriller",
		[TF_COND_RADIUSHEAL_ON_DAMAGE] = "OnAddRadiusHealOnDamage",
		[TF_COND_MEDIGUN_UBER_BULLET_RESIST] = "OnAddMedEffectUberBulletResist",
		[TF_COND_MEDIGUN_UBER_BLAST_RESIST] = "OnAddMedEffectUberBlastResist",
		[TF_COND_MEDIGUN_UBER_FIRE_RESIST] = "OnAddMedEffectUberFireResist",
		[TF_COND_MEDIGUN_SMALL_BULLET_RESIST] = "OnAddMedEffectSmallBulletResist",
		[TF_COND_MEDIGUN_SMALL_BLAST_RESIST] = "OnAddMedEffectSmallBlastResist",
		[TF_COND_MEDIGUN_SMALL_FIRE_RESIST] = "OnAddMedEffectSmallFireResist",
		[TF_COND_MEDIGUN_DEBUFF] = "OnAddMedigunDebuff",
		[TF_COND_STEALTHED_USER_BUFF_FADING] = "OnAddStealthedUserBuffFade",
		[TF_COND_BULLET_IMMUNE] = "OnAddBulletImmune",
		[TF_COND_BLAST_IMMUNE] = "OnAddBlastImmune",
		[TF_COND_FIRE_IMMUNE] = "OnAddFireImmune",
		[TF_COND_AFTERBURN_IMMUNE] = "OnAddAfterburnImmune",
		[TF_COND_PREVENT_DEATH] = "OnAddPreventDeath",
		[TF_COND_MVM_BOT_STUN_RADIOWAVE] = "OnAddMVMBotRadiowave",
		[TF_COND_HALLOWEEN_SPEED_BOOST] = "OnAddHalloweenSpeedBoost",
		[TF_COND_HALLOWEEN_QUICK_HEAL] = "OnAddHalloweenQuickHeal",
		[TF_COND_HALLOWEEN_GIANT] = "OnAddHalloweenGiant",
		[TF_COND_HALLOWEEN_TINY] = "OnAddHalloweenTiny",
		[TF_COND_HALLOWEEN_GHOST_MODE] = "OnAddHalloweenGhostMode",
		[TF_COND_HALLOWEEN_IN_HELL] = "OnAddHalloweenInHell",
		[TF_COND_OBSCURED_SMOKE] = "OnAddObscuredSmoke",
		[TF_COND_PARACHUTE_ACTIVE] = "OnAddCondParachute",
		[TF_COND_PARACHUTE_DEPLOYED] = "OnAddCondParachute",
		[TF_COND_BLASTJUMPING] = "OnAddBlastJumping",
		[TF_COND_HALLOWEEN_KART_DASH] = "OnAddHalloweenKartDash",
		[TF_COND_HALLOWEEN_KART] = "OnAddHalloweenKart",
		[TF_COND_BALLOON_HEAD] = "OnAddBalloonHead",
		[TF_COND_MELEE_ONLY] = "OnAddMeleeOnly",
		[TF_COND_CANNOT_SWITCH_FROM_MELEE] = "OnAddCannotSwitchFromMelee",
		[TF_COND_FREEZE_INPUT] = "OnAddFreezeInput",
		[TF_COND_SWIMMING_CURSE] = "OnAddSwimmingCurse",
		[TF_COND_HALLOWEEN_KART_CAGE] = "OnAddHalloweenKartCage",
		[TF_COND_RUNE_STRENGTH] = "OnAddRuneStrength",
		[TF_COND_RUNE_HASTE] = "OnAddRuneHaste",
		[TF_COND_RUNE_REGEN] = "OnAddRuneRegen",
		[TF_COND_RUNE_RESIST] = "OnAddRuneResist",
		[TF_COND_RUNE_VAMPIRE] = "OnAddRuneVampire",
		[TF_COND_RUNE_REFLECT] = "OnAddRuneReflect",
		[TF_COND_RUNE_PRECISION] = "OnAddRunePrecision",
		[TF_COND_RUNE_AGILITY] = "OnAddRuneAgility",
		[TF_COND_RUNE_KNOCKOUT] = "OnAddRuneKnockout",
		[TF_COND_RUNE_IMBALANCE] = "OnAddRuneImbalance",
		[TF_COND_GRAPPLINGHOOK_LATCHED] = "OnAddGrapplingHookLatched",
		[TF_COND_GRAPPLINGHOOK] = "OnAddGrapplingHook",
		[TF_COND_GRAPPLINGHOOK_SAFEFALL] = "OnAddGrapplingHookSafeFall",
		[TF_COND_GRAPPLINGHOOK_BLEEDING] = "OnAddGrapplingHookBleeding",
		[TF_COND_PASSTIME_INTERCEPTION] = "OnAddPasstimeInterception",
		[TF_COND_RUNE_KING] = "OnAddRuneKing",
		[TF_COND_KING_BUFFED] = "OnAddKingBuff",
		[TF_COND_RUNE_SUPERNOVA] = "OnAddRuneSupernova",
		[TF_COND_RUNE_PLAGUE] = "OnAddRunePlague",
		[TF_COND_PLAGUE] = "OnAddPlague",
		[TF_COND_PURGATORY] = "OnAddInPurgatory",
		[TF_COND_SWIMMING_NO_EFFECTS] = "OnAddSwimmingNoEffects",
		[TF_COND_TEAM_GLOWS] = "OnAddTeamGlows",
		[TF_COND_KNOCKED_INTO_AIR] = "OnAddKnockedIntoAir",
		[TF_COND_HEALING_DEBUFF] = "OnAddHealingDebuff",
		[TF_COND_GRAPPLED_TO_PLAYER] = "OnAddGrappledToPlayer",
		[TF_COND_GRAPPLED_BY_PLAYER] = "OnAddGrappledByPlayer",
		[TF_COND_COMPETITIVE_WINNER] = "OnAddCompetitiveWinner",
		[TF_COND_COMPETITIVE_LOSER] = "OnAddCompetitiveLoser",
		[TF_COND_GAS] = "OnAddCondGas",
		[TF_COND_BURNING_PYRO] = "OnAddBurningPyro",
		[TF_COND_MINICRITBOOSTED_ON_KILL] = "OnAddOffenseBuff",
		[TF_COND_ROCKETPACK] = "OnAddRocketPack",
		[TF_COND_LOST_FOOTING] = "OnAddLostFooting",
		[TF_COND_AIR_CURRENT] = "OnAddAirCurrent",
		[TF_COND_HALLOWEEN_HELL_HEAL] = "OnAddHalloweenHellHeal",
		[TF_COND_POWERUPMODE_DOMINANT] = "OnAddPowerupModeDominant",
		[TF_COND_IMMUNE_TO_PUSHBACK] = "OnAddImmuneToPushback",
		[TF_COND_DONOTUSE_0] = "OnAddDoNotUse0",
	}
	local fn = cond_handlers[eCond]
	if fn and self[fn] then
		self[fn](self)
	end
end

function meta:OnConditionRemoved(eCond)
	if eCond == TF_COND_CRITBOOSTED_FIRST_BLOOD then
		self:SetFirstBloodBoosted(false)
		self:OnRemoveCritBoost()
		return
	end

	local cond_handlers = {
		[TF_COND_AIMING] = "OnRemoveAiming",
		[TF_COND_ZOOMED] = "OnRemoveZoomed",
		[TF_COND_BURNING] = "OnRemoveBurning",
		[TF_COND_CRITBOOSTED] = "OnRemoveCritBoost",
		[TF_COND_CRITBOOSTED_DEMO_CHARGE] = "OnRemoveDemoCharge",
		[TF_COND_CRITBOOSTED_PUMPKIN] = "OnRemoveCritBoost",
		[TF_COND_CRITBOOSTED_USER_BUFF] = "OnRemoveCritBoost",
		[TF_COND_CRITBOOSTED_BONUS_TIME] = "OnRemoveCritBoost",
		[TF_COND_CRITBOOSTED_CTF_CAPTURE] = "OnRemoveCritBoost",
		[TF_COND_CRITBOOSTED_ON_KILL] = "OnRemoveCritBoost",
		[TF_COND_CRITBOOSTED_RAGE_BUFF] = "OnRemoveCritBoost",
		[TF_COND_SNIPERCHARGE_RAGE_BUFF] = "OnRemoveCritBoost",
		[TF_COND_CRITBOOSTED_CARD_EFFECT] = "OnRemoveCritBoost",
		[TF_COND_CRITBOOSTED_RUNE_TEMP] = "OnRemoveCritBoost",
		[TF_COND_SODAPOPPER_HYPE] = "OnRemoveSodaPopperHype",
		[TF_COND_TMPDAMAGEBONUS] = "OnRemoveTmpDamageBonus",
		[TF_COND_HEALTH_OVERHEALED] = "OnRemoveOverhealed",
		[TF_COND_FEIGN_DEATH] = "OnRemoveFeignDeath",
		[TF_COND_STEALTHED] = "OnRemoveStealthed",
		[TF_COND_STEALTHED_BLINK] = "OnRemoveStealthedBlink",
		[TF_COND_STEALTHED_USER_BUFF] = "OnRemoveStealthed",
		[TF_COND_SELECTED_TO_TELEPORT] = "OnRemoveSelectedToTeleport",
		[TF_COND_DISGUISED] = "OnRemoveDisguised",
		[TF_COND_DISGUISING] = "OnRemoveDisguising",
		[TF_COND_INVULNERABLE] = "OnRemoveInvulnerable",
		[TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED] = "OnRemoveInvulnerableHideUnlessDamaged",
		[TF_COND_INVULNERABLE_USER_BUFF] = "OnRemoveInvulnerable",
		[TF_COND_INVULNERABLE_CARD_EFFECT] = "OnRemoveInvulnerable",
		[TF_COND_INVULNERABLE_WEARINGOFF] = "OnRemoveInvulnerableWearingOff",
		[TF_COND_TELEPORTED] = "OnRemoveTeleported",
		[TF_COND_STUNNED] = "OnRemoveStunned",
		[TF_COND_PHASE] = "OnRemovePhase",
		[TF_COND_URINE] = "OnRemoveUrine",
		[TF_COND_MARKEDFORDEATH] = "OnRemoveMarkedForDeath",
		[TF_COND_BLEEDING] = "OnRemoveBleeding",
		[TF_COND_INVULNERABLE_WEARINGOFF] = "OnRemoveInvulnerableWearingOff",
		[TF_COND_OFFENSEBUFF] = "OnRemoveOffenseBuff",
		[TF_COND_DEFENSEBUFF] = "OnRemoveDefenseBuff",
		[TF_COND_DEFENSEBUFF_NO_CRIT_BLOCK] = "OnRemoveDefenseBuff",
		[TF_COND_DEFENSEBUFF_HIGH] = "OnRemoveDefenseBuff",
		[TF_COND_REGENONDAMAGEBUFF] = "OnRemoveOffenseHealthRegenBuff",
		[TF_COND_HEALTH_BUFF] = "OnRemoveHealthBuff",
		[TF_COND_NOHEALINGDAMAGEBUFF] = "OnRemoveNoHealingDamageBuff",
		[TF_COND_SHIELD_CHARGE] = "OnRemoveShieldCharge",
		[TF_COND_DEMO_BUFF] = "OnRemoveDemoBuff",
		[TF_COND_ENERGY_BUFF] = "OnRemoveEnergyDrinkBuff",
		[TF_COND_RADIUSHEAL] = "OnRemoveRadiusHeal",
		[TF_COND_MEGAHEAL] = "OnRemoveMegaHeal",
		[TF_COND_MAD_MILK] = "OnRemoveMadMilk",
		[TF_COND_TAUNTING] = "OnRemoveTaunting",
		[TF_COND_SPEED_BOOST] = "OnRemoveSpeedBoost",
		[TF_COND_SAPPED] = "OnRemoveSapped",
		[TF_COND_REPROGRAMMED] = "OnRemoveReprogrammed",
		[TF_COND_DISGUISE_WEARINGOFF] = "OnRemoveDisguiseWearingOff",
		[TF_COND_PASSTIME_PENALTY_DEBUFF] = "OnRemoveMarkedForDeathSilent",
		[TF_COND_MARKEDFORDEATH_SILENT] = "OnRemoveMarkedForDeathSilent",
		[TF_COND_DISGUISED_AS_DISPENSER] = "OnRemoveDisguisedAsDispenser",
		[TF_COND_HALLOWEEN_BOMB_HEAD] = "OnRemoveHalloweenBombHead",
		[TF_COND_HALLOWEEN_THRILLER] = "OnRemoveHalloweenThriller",
		[TF_COND_RADIUSHEAL_ON_DAMAGE] = "OnRemoveRadiusHealOnDamage",
		[TF_COND_MEDIGUN_UBER_BULLET_RESIST] = "OnRemoveMedEffectUberBulletResist",
		[TF_COND_MEDIGUN_UBER_BLAST_RESIST] = "OnRemoveMedEffectUberBlastResist",
		[TF_COND_MEDIGUN_UBER_FIRE_RESIST] = "OnRemoveMedEffectUberFireResist",
		[TF_COND_MEDIGUN_SMALL_BULLET_RESIST] = "OnRemoveMedEffectSmallBulletResist",
		[TF_COND_MEDIGUN_SMALL_BLAST_RESIST] = "OnRemoveMedEffectSmallBlastResist",
		[TF_COND_MEDIGUN_SMALL_FIRE_RESIST] = "OnRemoveMedEffectSmallFireResist",
		[TF_COND_MEDIGUN_DEBUFF] = "OnRemoveMedigunDebuff",
		[TF_COND_STEALTHED_USER_BUFF_FADING] = "OnRemoveStealthedUserBuffFade",
		[TF_COND_BULLET_IMMUNE] = "OnRemoveBulletImmune",
		[TF_COND_BLAST_IMMUNE] = "OnRemoveBlastImmune",
		[TF_COND_FIRE_IMMUNE] = "OnRemoveFireImmune",
		[TF_COND_AFTERBURN_IMMUNE] = "OnRemoveAfterburnImmune",
		[TF_COND_PREVENT_DEATH] = "OnRemovePreventDeath",
		[TF_COND_MVM_BOT_STUN_RADIOWAVE] = "OnRemoveMVMBotRadiowave",
		[TF_COND_HALLOWEEN_SPEED_BOOST] = "OnRemoveHalloweenSpeedBoost",
		[TF_COND_HALLOWEEN_QUICK_HEAL] = "OnRemoveHalloweenQuickHeal",
		[TF_COND_HALLOWEEN_GIANT] = "OnRemoveHalloweenGiant",
		[TF_COND_HALLOWEEN_TINY] = "OnRemoveHalloweenTiny",
		[TF_COND_HALLOWEEN_GHOST_MODE] = "OnRemoveHalloweenGhostMode",
		[TF_COND_HALLOWEEN_IN_HELL] = "OnRemoveHalloweenInHell",
		[TF_COND_OBSCURED_SMOKE] = "OnRemoveObscuredSmoke",
		[TF_COND_PARACHUTE_ACTIVE] = "OnRemoveCondParachute",
		[TF_COND_PARACHUTE_DEPLOYED] = "OnRemoveCondParachute",
		[TF_COND_BLASTJUMPING] = "OnRemoveBlastJumping",
		[TF_COND_HALLOWEEN_KART_DASH] = "OnRemoveHalloweenKartDash",
		[TF_COND_HALLOWEEN_KART] = "OnRemoveHalloweenKart",
		[TF_COND_BALLOON_HEAD] = "OnRemoveBalloonHead",
		[TF_COND_MELEE_ONLY] = "OnRemoveMeleeOnly",
		[TF_COND_CANNOT_SWITCH_FROM_MELEE] = "OnRemoveCannotSwitchFromMelee",
		[TF_COND_FREEZE_INPUT] = "OnRemoveFreezeInput",
		[TF_COND_SWIMMING_CURSE] = "OnRemoveSwimmingCurse",
		[TF_COND_HALLOWEEN_KART_CAGE] = "OnRemoveHalloweenKartCage",
		[TF_COND_RUNE_STRENGTH] = "OnRemoveRuneStrength",
		[TF_COND_RUNE_HASTE] = "OnRemoveRuneHaste",
		[TF_COND_RUNE_REGEN] = "OnRemoveRuneRegen",
		[TF_COND_RUNE_RESIST] = "OnRemoveRuneResist",
		[TF_COND_RUNE_VAMPIRE] = "OnRemoveRuneVampire",
		[TF_COND_RUNE_REFLECT] = "OnRemoveRuneReflect",
		[TF_COND_RUNE_PRECISION] = "OnRemoveRunePrecision",
		[TF_COND_RUNE_AGILITY] = "OnRemoveRuneAgility",
		[TF_COND_RUNE_KNOCKOUT] = "OnRemoveRuneKnockout",
		[TF_COND_RUNE_IMBALANCE] = "OnRemoveRuneImbalance",
		[TF_COND_GRAPPLINGHOOK_LATCHED] = "OnRemoveGrapplingHookLatched",
		[TF_COND_GRAPPLINGHOOK] = "OnRemoveGrapplingHook",
		[TF_COND_GRAPPLINGHOOK_SAFEFALL] = "OnRemoveGrapplingHookSafeFall",
		[TF_COND_GRAPPLINGHOOK_BLEEDING] = "OnRemoveGrapplingHookBleeding",
		[TF_COND_PASSTIME_INTERCEPTION] = "OnRemovePasstimeInterception",
		[TF_COND_RUNE_PLAGUE] = "OnRemoveRunePlague",
		[TF_COND_PLAGUE] = "OnRemovePlague",
		[TF_COND_PURGATORY] = "OnRemoveInPurgatory",
		[TF_COND_SWIMMING_NO_EFFECTS] = "OnRemoveSwimmingNoEffects",
		[TF_COND_TEAM_GLOWS] = "OnRemoveTeamGlows",
		[TF_COND_KNOCKED_INTO_AIR] = "OnRemoveKnockedIntoAir",
		[TF_COND_HEALING_DEBUFF] = "OnRemoveHealingDebuff",
		[TF_COND_GRAPPLED_TO_PLAYER] = "OnRemoveGrappledToPlayer",
		[TF_COND_GRAPPLED_BY_PLAYER] = "OnRemoveGrappledByPlayer",
		[TF_COND_RUNE_KING] = "OnRemoveRuneKing",
		[TF_COND_KING_BUFFED] = "OnRemoveKingBuff",
		[TF_COND_RUNE_SUPERNOVA] = "OnRemoveRuneSupernova",
		[TF_COND_COMPETITIVE_WINNER] = "OnRemoveCompetitiveWinner",
		[TF_COND_COMPETITIVE_LOSER] = "OnRemoveCompetitiveLoser",
		[TF_COND_GAS] = "OnRemoveCondGas",
		[TF_COND_ROCKETPACK] = "OnRemoveRocketPack",
		[TF_COND_BURNING_PYRO] = "OnRemoveBurningPyro",
		[TF_COND_MINICRITBOOSTED_ON_KILL] = "OnRemoveOffenseBuff",
		[TF_COND_LOST_FOOTING] = "OnRemoveLostFooting",
		[TF_COND_AIR_CURRENT] = "OnRemoveAirCurrent",
		[TF_COND_HALLOWEEN_HELL_HEAL] = "OnRemoveHalloweenHellHeal",
		[TF_COND_POWERUPMODE_DOMINANT] = "OnRemovePowerupModeDominant",
		[TF_COND_IMMUNE_TO_PUSHBACK] = "OnRemoveImmuneToPushback",
		[TF_COND_DONOTUSE_0] = "OnRemoveDoNotUse0",
	}
	local fn = cond_handlers[eCond]
	if fn and self[fn] then
		self[fn](self)
	end
end

if SERVER then
	hook.Add("Think", "TFCondCoreServerThink", function()
		for _, pl in ipairs(player.GetAll()) do
			if IsValid(pl) and pl.ConditionGameRulesThink and pl.ConditionThink then
				pl:ConditionGameRulesThink()
				pl:ConditionThink()

				if pl.CanRuneCharge and pl:CanRuneCharge() and not pl:IsRuneCharged() then
					local now = CurTime()
					local lastUpdate = pl._tfLastRuneChargeUpdate or now
					local dt = math.max(now - lastUpdate, 0)
					local chargeCvar = GetConVar("tf_powerup_max_charge_time")
					local maxChargeTime = chargeCvar and math.max(chargeCvar:GetFloat(), 0.1) or 20
					pl:SetRuneCharge(pl:GetRuneCharge() + (dt * 100 / maxChargeTime))

					if pl:IsRuneCharged() then
						local deployHint = tf_lang and tf_lang.GetRaw and tf_lang.GetRaw("#TF_Powerup_Supernova_Deploy", true) or "Grapple SECONDARY FIRE to deploy Supernova attack!"
						pl:PrintMessage(HUD_PRINTCENTER, deployHint)
					end
				end
				pl._tfLastRuneChargeUpdate = CurTime()

				if pl.InCond and pl:InCond(TF_COND_RUNE_KING) then
					if (pl._tfNextKingBuffCheck or 0) <= CurTime() then
						local active = false
						for _, target in ipairs(ents.FindInSphere(pl:GetPos(), 450)) do
							if not IsValid(target) or target == pl or not target:IsPlayer() or not target:Alive() then continue end
							if not target.IsFriendly or not target:IsFriendly(pl) then continue end
							target:AddCond(TF_COND_KING_BUFFED, 1, pl)
							active = true
						end
						pl:SetNWBool("TFKingRuneBuffActive", active)
						pl._tfNextKingBuffCheck = CurTime() + 0.5
					end
				else
					pl:SetNWBool("TFKingRuneBuffActive", false)
				end
			end
		end
	end)
else
	hook.Add("Think", "TFCondCoreClientThink", function()
		for _, pl in ipairs(player.GetAll()) do
			if IsValid(pl) and pl.ConditionThink then
				pl:ConditionThink()
			end
		end
	end)

	local mannpowerFxState = {}

	local function attach_mannpower_effects(pl, state)
		if not IsValid(pl) then return end

		if state.plague then
			ParticleEffectAttach("powerup_plague_carrier", PATTACH_ABSORIGIN_FOLLOW, pl, 0)
		end

		if state.king then
			local team = pl:EntityTeam()
			local effect = (team == TEAM_BLU or team == TF_TEAM_PVE_INVADERS) and "powerup_king_blue" or "powerup_king_red"
			ParticleEffectAttach(effect, PATTACH_ABSORIGIN_FOLLOW, pl, 0)
		end

		if state.supernovaReady then
			ParticleEffectAttach("powerup_supernova_ready", PATTACH_ABSORIGIN_FOLLOW, pl, 0)
		end
	end

	hook.Add("Think", "TFMannpowerVisualEffects", function()
		for _, pl in ipairs(player.GetAll()) do
			if not IsValid(pl) then continue end

			local idx = pl:EntIndex()
			local wants = {
				plague = pl.InCond and pl:InCond(TF_COND_RUNE_PLAGUE) or false,
				king = pl:GetNWBool("TFKingRuneBuffActive", false) and not (pl.InCond and pl:InCond(TF_COND_PLAGUE)),
				supernovaReady = pl:GetNWBool("TFRuneCharged", false) and pl.InCond and pl:InCond(TF_COND_RUNE_SUPERNOVA) or false,
			}
			local prev = mannpowerFxState[idx]

			if not prev
				or prev.plague ~= wants.plague
				or prev.king ~= wants.king
				or prev.supernovaReady ~= wants.supernovaReady
			then
				pl:StopParticles()
				if pl.UpdateStateParticles then
					pl:UpdateStateParticles(pl:GetPlayerState())
				end
				attach_mannpower_effects(pl, wants)
				mannpowerFxState[idx] = wants
			end
		end
	end)
end

hook.Add("Move", "TFCondMoveAdjust", function(pl, move)
	if not IsValid(pl) or not pl.InCond then return end
	local allowTauntMotion = pl:GetNWBool("TauntingMoped", false) or pl:GetNWBool("TauntingSchemaMove", false)

	-- TF2 speed logic: dispenser disguise locks movement unless cloaked.
	if can_run_dispenser_disguise(pl) then
		move:SetForwardSpeed(0)
		move:SetSideSpeed(0)
		move:SetUpSpeed(0)
		return
	end

	if pl:InCond(TF_COND_FREEZE_INPUT) or (pl:InCond(TF_COND_TAUNTING) and not allowTauntMotion) then
		move:SetForwardSpeed(0)
		move:SetSideSpeed(0)
		move:SetUpSpeed(0)
		return
	end

	local mult = pl:GetNWFloat("TFCondSpeedMult", 1)
	if mult ~= 1 then
		local max = move:GetMaxSpeed()
		local max_client = move:GetMaxClientSpeed()
		move:SetMaxSpeed(max * mult)
		move:SetMaxClientSpeed(max_client * mult)
	end
end)

if SERVER then
	hook.Add("StartCommand", "TFCondCommandAdjust", function(pl, cmd)
		if not IsValid(pl) or not pl.InCond then return end

		if pl:GetNWBool("TauntingMoped", false) then
			local steer = 0
			if cmd:KeyDown(IN_MOVERIGHT) then
				steer = 1
			elseif cmd:KeyDown(IN_MOVELEFT) then
				steer = -1
			end
			pl.__MopedTurnInput = steer

			local jumpDown = cmd:KeyDown(IN_JUMP)
			local jumpPressed = jumpDown and not pl.__MopedJumpWasDown
			pl.__MopedJumpWasDown = jumpDown
			if jumpPressed then
				if TF_EndMopedTaunt then
					TF_EndMopedTaunt(pl)
				else
					pl:ConCommand("tf_taunt_moped_stop")
				end
			end

			local attackDown = cmd:KeyDown(IN_ATTACK)
			local attackPressed = attackDown and not pl.__MopedAttackWasDown
			pl.__MopedAttackWasDown = attackDown
			if attackPressed and TF_MopedWheelie then
				TF_MopedWheelie(pl)
			end

			cmd:RemoveKey(IN_JUMP)
			cmd:RemoveKey(IN_ATTACK)
			cmd:RemoveKey(IN_ATTACK2)
			cmd:RemoveKey(IN_RELOAD)
		else
			pl.__MopedJumpWasDown = false
			pl.__MopedAttackWasDown = false
			pl.__MopedTurnInput = 0
		end

		if pl:InCond(TF_COND_HALLOWEEN_KART) then
			local steer = 0
			if cmd:KeyDown(IN_MOVERIGHT) then
				steer = 1
			elseif cmd:KeyDown(IN_MOVELEFT) then
				steer = -1
			end
			pl.__TFKartTurnInput = steer

			local drive = 0
			if cmd:KeyDown(IN_FORWARD) then
				drive = 1
			elseif cmd:KeyDown(IN_BACK) then
				drive = -1
			end
			pl.__TFKartDriveInput = drive

			local hornDown = cmd:KeyDown(IN_ATTACK)
			local hornPressed = hornDown and not pl.__TFKartHornWasDown
			pl.__TFKartHornWasDown = hornDown
			if hornPressed then
				pl:EmitSound("Taunt.BumperCarHorn")
			end

			local boostDown = cmd:KeyDown(IN_ATTACK2)
			local boostPressed = boostDown and not pl.__TFKartBoostWasDown
			pl.__TFKartBoostWasDown = boostDown
			if boostPressed then
				local now = CurTime()
				local cooldownEnd = pl:GetNWFloat("TFKartBoostCooldownEndTime", 0)
				if now >= cooldownEnd then
					local boostDuration = 0.8
					local cooldownDuration = 2.5
					pl:SetNWFloat("TFKartBoostEndTime", now + boostDuration)
					pl:SetNWFloat("TFKartBoostCooldownEndTime", now + cooldownDuration)
					pl:AddCond(TF_COND_HALLOWEEN_KART_DASH, boostDuration, pl)
					pl:EmitSound("BumperCar.SpeedBoostStart")
					timer.Create("TFKartBoostStop_" .. pl:EntIndex(), boostDuration, 1, function()
						if not IsValid(pl) then return end
						pl:EmitSound("BumperCar.SpeedBoostStop")
					end)
				end
			end

			cmd:RemoveKey(IN_JUMP)
			cmd:RemoveKey(IN_ATTACK)
			cmd:RemoveKey(IN_RELOAD)
		else
			pl.__TFKartTurnInput = 0
			pl.__TFKartDriveInput = 0
			pl.__TFKartHornWasDown = false
			pl.__TFKartBoostWasDown = false
		end

		local schemaState = pl.__SchemaTauntState
		if istable(schemaState) and schemaState.active then
			local wantsDirectionalMove = cmd:KeyDown(IN_FORWARD) or cmd:KeyDown(IN_BACK) or cmd:KeyDown(IN_MOVERIGHT) or cmd:KeyDown(IN_MOVELEFT)
			local steer = 0
			if cmd:KeyDown(IN_MOVERIGHT) then
				steer = 1
			elseif cmd:KeyDown(IN_MOVELEFT) then
				steer = -1
			end
			pl.__SchemaTauntMoveInput = steer
			local drive = 0
			if cmd:KeyDown(IN_FORWARD) then
				drive = 1
			elseif cmd:KeyDown(IN_BACK) then
				drive = -1
			end
			pl.__SchemaTauntDriveInput = drive

			if schemaState.stopIfMoved and wantsDirectionalMove and TF_EndSchemaTaunt then
				TF_EndSchemaTaunt(pl)
			end

			local jumpDown = cmd:KeyDown(IN_JUMP)
			local jumpPressed = jumpDown and not pl.__SchemaTauntJumpWasDown
			pl.__SchemaTauntJumpWasDown = jumpDown
			if jumpPressed and TF_EndSchemaTaunt then
				TF_EndSchemaTaunt(pl)
			end

			local attackDown = cmd:KeyDown(IN_ATTACK)
			local attackPressed = attackDown and not pl.__SchemaTauntAttackWasDown
			pl.__SchemaTauntAttackWasDown = attackDown
			if attackPressed and TF_TriggerSchemaTauntInput then
				TF_TriggerSchemaTauntInput(pl, "IN_ATTACK")
			end

			local attack2Down = cmd:KeyDown(IN_ATTACK2)
			local attack2Pressed = attack2Down and not pl.__SchemaTauntAttack2WasDown
			pl.__SchemaTauntAttack2WasDown = attack2Down
			if attack2Pressed and TF_TriggerSchemaTauntInput then
				TF_TriggerSchemaTauntInput(pl, "IN_ATTACK2")
			end

			cmd:RemoveKey(IN_JUMP)
			cmd:RemoveKey(IN_ATTACK)
			cmd:RemoveKey(IN_ATTACK2)
			cmd:RemoveKey(IN_RELOAD)
		else
			pl.__SchemaTauntJumpWasDown = false
			pl.__SchemaTauntAttackWasDown = false
			pl.__SchemaTauntAttack2WasDown = false
			pl.__SchemaTauntMoveInput = 0
			pl.__SchemaTauntDriveInput = 0
		end

		local allowTauntMotion = pl:GetNWBool("TauntingMoped", false) or pl:GetNWBool("TauntingSchemaMove", false)
		if pl:InCond(TF_COND_FREEZE_INPUT) or (pl:InCond(TF_COND_TAUNTING) and not allowTauntMotion) then
			cmd:ClearMovement()
			cmd:RemoveKey(IN_ATTACK)
			cmd:RemoveKey(IN_ATTACK2)
			cmd:RemoveKey(IN_RELOAD)
		else
			local allowDisguisedSpyAttack = pl:GetPlayerClass() == "spy" and pl:InCond(TF_COND_DISGUISED)
			if pl:GetNWBool("NoWeapon", false) and not allowTauntMotion and not allowDisguisedSpyAttack then
				cmd:RemoveKey(IN_ATTACK)
				-- TF2 kart: no weapon use, but keep +attack2 available for kart boost input.
				if not pl:InCond(TF_COND_HALLOWEEN_KART) then
					cmd:RemoveKey(IN_ATTACK2)
				end
				cmd:RemoveKey(IN_RELOAD)
			end
		end
	end)

	hook.Add("PlayerSwitchWeapon", "TFCondWeaponRestrictions", function(pl, oldWep, newWep)
		if not IsValid(pl) or not pl.InCond or not IsValid(newWep) then return end

		if isfunction(newWep.HasUsableAmmoForSelection) and not newWep:HasUsableAmmoForSelection() then
			local fallbackClass = nil
			if IsValid(oldWep) and isfunction(oldWep.HasUsableAmmoForSelection) and oldWep:HasUsableAmmoForSelection() then
				fallbackClass = oldWep:GetClass()
			elseif isfunction(newWep.FindNextWeaponWithAmmo) then
				local nextWep = newWep:FindNextWeaponWithAmmo()
				if IsValid(nextWep) then
					fallbackClass = nextWep:GetClass()
				end
			end
			if fallbackClass then
				timer.Simple(0, function()
					if IsValid(pl) and pl:Alive() then
						pl:SelectWeapon(fallbackClass)
					end
				end)
				return true
			end
		end

		if pl:InCond(TF_COND_MELEE_ONLY)
			and not is_melee_weapon(newWep)
			and not (TF_IsWeaponAllowedInMedievalMode and TF_IsWeaponAllowedInMedievalMode(newWep))
		then
			force_select_melee(pl)
			return true
		end

		if pl:InCond(TF_COND_CANNOT_SWITCH_FROM_MELEE) and IsValid(oldWep) and is_melee_weapon(oldWep) and not is_melee_weapon(newWep) then
			force_select_melee(pl)
			return true
		end
	end)

	hook.Add("PlayerDeath", "TFCondCleanup", function(pl)
		if not IsValid(pl) then return end
		timer.Remove("TFCondRegen_" .. pl:EntIndex())
		timer.Remove("TFKartLoopStart_" .. pl:EntIndex())
		timer.Remove("TFKartBoostStop_" .. pl:EntIndex())
		for _, ent in ipairs(ents.FindByName("TFCondKartModel" .. pl:EntIndex())) do
			ent:Remove()
		end
		pl:StopSound("BumperCar.GoLoop")
		pl:StopSound("Taunt.BumperCarGoLoop")
		pl._tf_cond_stacks = nil
		pl._tf_cond_speed = nil
		pl:SetNWFloat("TFCondSpeedMult", 1)
		pl:SetNWFloat("TFKartBoostEndTime", 0)
		pl:SetNWFloat("TFKartBoostCooldownEndTime", 0)
		pl:SetNWBool("HalloweenKart", false)
	end)
end

if CLIENT then
	CreateClientConVar("tf_debug_spy_disguise_local", "0", true, false, "Force local client to render Spy disguise enemy-view model for debugging.")

	local dispenserModelByEnt = {}
	local dispenserDialStateByEnt = {}
	local spyDisguiseModelByEnt = {}
	local spyDisguiseWeaponModelByEnt = {}
	local spyDisguiseCosmeticModelsByEnt = {}
	local spyDisguiseMaskModelByEnt = {}
	local DispenserScreenTexture = {
		[0] = surface.GetTextureID("vgui/dispenser_meter_bg_red"),
		[1] = surface.GetTextureID("vgui/dispenser_meter_bg_blue"),
	}
	local DispenserArrowTexture = surface.GetTextureID("vgui/dispenser_meter_arrow")
	local DispenserPanelOffset = Vector(-1.1, -11, -0.6)
	local DispenserPanelScale = 0.0465
	local DispenserAngleStart = 85
	local DispenserAngleEnd = -85
	local DISGUISE_MODEL_BY_CLASS = {
		scout = "models/player/scout.mdl",
		soldier = "models/player/soldier.mdl",
		pyro = "models/player/pyro.mdl",
		demo = "models/player/demo.mdl",
		demoman = "models/player/demo.mdl",
		heavy = "models/player/heavy.mdl",
		engineer = "models/player/engineer.mdl",
		medic = "models/player/medic.mdl",
		sniper = "models/player/sniper.mdl",
		spy = "models/player/spy.mdl",
	}
	local DISGUISE_PRIMARY_WEAPON_BY_CLASS = {
		scout = "models/weapons/c_models/c_scattergun.mdl",
		soldier = "models/weapons/w_models/w_rocketlauncher.mdl",
		pyro = "models/weapons/c_models/c_flamethrower/c_flamethrower.mdl",
		demo = "models/weapons/w_models/w_stickybomb_launcher.mdl",
		demoman = "models/weapons/w_models/w_stickybomb_launcher.mdl",
		heavy = "models/weapons/c_models/c_minigun/c_minigun.mdl",
		engineer = "models/weapons/c_models/c_shotgun/c_shotgun.mdl",
		medic = "models/weapons/c_models/c_syringegun/c_syringegun.mdl",
		sniper = "models/weapons/c_models/c_sniperrifle/c_sniperrifle.mdl",
		spy = "models/weapons/c_models/c_revolver/c_revolver.mdl",
	}
	local DISGUISE_SECONDARY_WEAPON_BY_CLASS = {
		scout = "models/weapons/c_models/c_pistol/c_pistol.mdl",
		soldier = "models/weapons/c_models/c_shotgun/c_shotgun.mdl",
		pyro = "models/weapons/c_models/c_shotgun/c_shotgun.mdl",
		demo = "models/weapons/w_models/w_grenadelauncher.mdl",
		demoman = "models/weapons/w_models/w_grenadelauncher.mdl",
		heavy = "models/weapons/c_models/c_shotgun/c_shotgun.mdl",
		engineer = "models/weapons/c_models/c_pistol/c_pistol.mdl",
		medic = "models/weapons/c_models/c_medigun/c_medigun.mdl",
		sniper = "models/weapons/c_models/c_smg/c_smg.mdl",
		spy = "models/weapons/c_models/c_revolver/c_revolver.mdl",
	}
	local DISGUISE_MELEE_WEAPON_BY_CLASS = {
		scout = "models/weapons/c_models/c_bat.mdl",
		soldier = "models/weapons/c_models/c_shovel/c_shovel.mdl",
		pyro = "models/weapons/w_models/w_fireaxe.mdl",
		demo = "models/weapons/w_models/w_bottle.mdl",
		demoman = "models/weapons/w_models/w_bottle.mdl",
		heavy = "models/weapons/c_models/c_fists/c_fists.mdl",
		engineer = "models/weapons/c_models/c_wrench/c_wrench.mdl",
		medic = "models/weapons/c_models/c_bonesaw/c_bonesaw.mdl",
		sniper = "models/weapons/c_models/c_machete/c_machete.mdl",
		spy = "models/weapons/c_models/c_knife/c_knife.mdl",
	}
	local SPY_DISGUISE_MASK_MODEL = "models/player/items/spy/fwk_spy_disguisedhat.mdl"
	local MASK_CLASS_INDEX_BY_NAME = {
		scout = 1,
		sniper = 2,
		soldier = 3,
		demo = 4,
		demoman = 4,
		medic = 5,
		heavy = 6,
		pyro = 7,
		spy = 8,
		engineer = 9,
	}

	local function get_disguise_weapon_model_from_weapon(wep)
		if not IsValid(wep) then return "" end
		if wep.IsTFWeapon and wep.GetItemData then
			local item = wep:GetItemData()
			if istable(item) then
				local mdl = item.model_world or item.model_player
				if isstring(mdl) and mdl ~= "" and util.IsValidModel(mdl) then
					return mdl
				end
			end
		end
		if wep.GetWeaponWorldModel then
			local mdl = wep:GetWeaponWorldModel()
			if isstring(mdl) and mdl ~= "" and util.IsValidModel(mdl) then
				return mdl
			end
		end
		local mdl = wep:GetModel()
		if isstring(mdl) and mdl ~= "" and util.IsValidModel(mdl) then
			return mdl
		end
		return ""
	end

	local function is_melee_weapon(wep)
		if not IsValid(wep) then return false end
		if wep.IsMeleeWeapon == true then return true end
		local slot = tonumber(wep.Slot or (wep.GetSlot and wep:GetSlot()) or -1)
		if slot == 2 then return true end
		if wep.GetItemData then
			local item = wep:GetItemData()
			if istable(item) and item.item_slot == "melee" then
				return true
			end
		end
		return false
	end

	local function find_model_for_slot(ply, desiredSlotNum, desiredItemSlotName)
		if not IsValid(ply) or not ply.GetWeapons then return "" end
		for _, wep in ipairs(ply:GetWeapons()) do
			if not IsValid(wep) then continue end
			local ok = false
			local slot = tonumber(wep.Slot or (wep.GetSlot and wep:GetSlot()) or -1)
			if desiredSlotNum ~= nil and slot == desiredSlotNum then
				ok = true
			end
			if not ok and desiredItemSlotName and wep.GetItemData then
				local item = wep:GetItemData()
				ok = istable(item) and item.item_slot == desiredItemSlotName
			end
			if ok then
				local mdl = get_disguise_weapon_model_from_weapon(wep)
				if mdl ~= "" then
					return mdl
				end
			end
		end
		return ""
	end

	local function get_disguise_slot_kind(ply, overrideSlot)
		local forced = tonumber(overrideSlot)
		if forced == 0 then return "primary" end
		if forced == 1 then return "secondary" end
		if forced == 2 then return "melee" end
		if forced == 3 then return "sapper" end

		local wep = IsValid(ply) and ply:GetActiveWeapon() or nil
		if not IsValid(wep) then return "primary" end
		if wep:GetClass() == "tf_weapon_builder" then return "sapper" end
		if is_melee_weapon(wep) then return "melee" end
		local slot = tonumber(wep.Slot or (wep.GetSlot and wep:GetSlot()) or -1)
		if slot == 1 then return "secondary" end
		if wep.GetItemData then
			local item = wep:GetItemData()
			if istable(item) and item.item_slot == "secondary" then
				return "secondary"
			end
		end
		return "primary"
	end

	local function resolve_disguise_weapon_model(ply, className)
		local slotKind = get_disguise_slot_kind(ply, IsValid(ply) and ply:GetNWInt("TFSpyDisguiseWeaponSlotOverride", -1) or -1)
		if slotKind == "sapper" then
			local sapperWep = IsValid(ply) and ply:GetActiveWeapon() or nil
			local sapperModel = get_disguise_weapon_model_from_weapon(sapperWep)
			if sapperModel == "" and IsValid(ply) and ply.GetWeapon then
				sapperModel = get_disguise_weapon_model_from_weapon(ply:GetWeapon("tf_weapon_builder"))
			end
			return sapperModel, slotKind
		end

		local target = IsValid(ply) and ply:GetNWEntity("TFSpyDisguiseTarget") or nil
		if IsValid(target) and target:IsPlayer() then
			if slotKind == "melee" then
				local mdl = find_model_for_slot(target, 2, "melee")
				if mdl ~= "" then return mdl, slotKind end
			elseif slotKind == "secondary" then
				local mdl = find_model_for_slot(target, 1, "secondary")
				if mdl ~= "" then return mdl, slotKind end
			else
				local mdl = find_model_for_slot(target, 0, "primary")
				if mdl ~= "" then return mdl, slotKind end
			end
		end

		local fallback
		if slotKind == "melee" then
			fallback = DISGUISE_MELEE_WEAPON_BY_CLASS[className]
		elseif slotKind == "secondary" then
			fallback = DISGUISE_SECONDARY_WEAPON_BY_CLASS[className] or DISGUISE_PRIMARY_WEAPON_BY_CLASS[className]
		else
			fallback = DISGUISE_PRIMARY_WEAPON_BY_CLASS[className]
		end
		if isstring(fallback) and fallback ~= "" and util.IsValidModel(fallback) then
			return fallback, slotKind
		end
		return "", slotKind
	end

	local function resolve_friendly_spy_weapon_model(ply)
		local slotKind = get_disguise_slot_kind(ply)
		if slotKind == "sapper" then
			local sapperWep = IsValid(ply) and ply:GetActiveWeapon() or nil
			local sapperModel = get_disguise_weapon_model_from_weapon(sapperWep)
			if sapperModel == "" and IsValid(ply) and ply.GetWeapon then
				sapperModel = get_disguise_weapon_model_from_weapon(ply:GetWeapon("tf_weapon_builder"))
			end
			return sapperModel, slotKind
		end

		if slotKind == "melee" then
			local meleeModel = find_model_for_slot(ply, 2, "melee")
			if meleeModel ~= "" then
				return meleeModel, slotKind
			end
			return DISGUISE_MELEE_WEAPON_BY_CLASS.spy or "", slotKind
		end

		local primaryModel = find_model_for_slot(ply, 0, "primary")
		if primaryModel ~= "" then
			return primaryModel, slotKind
		end
		return DISGUISE_PRIMARY_WEAPON_BY_CLASS.spy or "", slotKind
	end

	local function split_disguise_model_list(raw)
		local out = {}
		if not isstring(raw) or raw == "" then return out end
		for token in string.gmatch(raw, "([^|]+)") do
			local mdl = string.Trim(token or "")
			if mdl ~= "" and util.IsValidModel(mdl) then
				out[#out + 1] = mdl
			end
		end
		return out
	end

	local function cleanup_dispenser_model(ply)
		if not ply or not ply.EntIndex then return end
		local idx = ply:EntIndex()
		local mdl = dispenserModelByEnt[idx]
		if IsValid(mdl) then
			mdl:Remove()
		end
		dispenserModelByEnt[idx] = nil
		dispenserDialStateByEnt[idx] = nil
	end

	local function cleanup_spy_disguise_models(ply)
		if not ply or not ply.EntIndex then return end
		local idx = ply:EntIndex()

		local mdl = spyDisguiseModelByEnt[idx]
		if IsValid(mdl) then mdl:Remove() end
		spyDisguiseModelByEnt[idx] = nil

		local wmdl = spyDisguiseWeaponModelByEnt[idx]
		if IsValid(wmdl) then wmdl:Remove() end
		spyDisguiseWeaponModelByEnt[idx] = nil

		local mmdl = spyDisguiseMaskModelByEnt[idx]
		if IsValid(mmdl) then mmdl:Remove() end
		spyDisguiseMaskModelByEnt[idx] = nil

		local cosmetics = spyDisguiseCosmeticModelsByEnt[idx]
		if istable(cosmetics) then
			for _, cmdl in ipairs(cosmetics) do
				if IsValid(cmdl) then cmdl:Remove() end
			end
		end
		spyDisguiseCosmeticModelsByEnt[idx] = nil
	end

	local function should_draw_dispenser_disguise(ply)
		if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
		if not ply.InCond or not ply:InCond(TF_COND_DISGUISED_AS_DISPENSER) then return false end
		if not ply.Crouching or not ply:Crouching() then return false end
		local ground = ply.GetGroundEntity and ply:GetGroundEntity() or NULL
		if ground == nil or ground == NULL then return false end

		local lp = LocalPlayer()
		if not IsValid(lp) then return false end
		if lp == ply and not lp:ShouldDrawLocalPlayer() then return false end
		return true
	end

	local function get_dispenser_disguise_team(ply)
		if not IsValid(ply) then return TEAM_RED end
		local t = tonumber(ply:GetNWInt("TFDispenserDisguiseTeam", -1)) or -1
		if t ~= -1 then return t end

		-- Fallback for any path that sets cond 49 without running add-handler state.
		local myTeam = ply:Team()
		if myTeam == TEAM_BLU or myTeam == TF_TEAM_PVE_INVADERS then
			return TEAM_RED
		end
		return TEAM_BLU
	end

	local function calc_dispenser_dial_angle(frac)
		return Lerp(math.Clamp(tonumber(frac) or 0, 0, 1), DispenserAngleStart, DispenserAngleEnd)
	end

	local function resolve_attach(ent, name)
		if not IsValid(ent) then return nil end
		local id = ent:LookupAttachment(name)
		if not isnumber(id) or id <= 0 then return nil end
		return ent:GetAttachment(id)
	end

	local function resolve_attach_with_fallback(ent, names, fallbackPos, fallbackAng)
		if not IsValid(ent) then return nil end
		for _, name in ipairs(names) do
			local att = resolve_attach(ent, name)
			if att then return att end
		end
		return {
			Pos = ent:LocalToWorld(fallbackPos),
			Ang = ent:LocalToWorldAngles(fallbackAng),
		}
	end

	local function draw_dispenser_panel_screen(team, angle)
		local teamTex = (team == TEAM_BLU or team == TF_TEAM_PVE_INVADERS) and DispenserScreenTexture[1] or DispenserScreenTexture[0]
		if isnumber(teamTex) and teamTex > 0 then
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetTexture(teamTex)
			surface.DrawTexturedRect(0, 0, 480, 240)
		else
			surface.SetDrawColor(30, 40, 50, 235)
			surface.DrawRect(0, 0, 480, 240)
			surface.SetDrawColor(140, 180, 220, 255)
			surface.DrawOutlinedRect(0, 0, 480, 240)
		end

		local a = tonumber(angle) or calc_dispenser_dial_angle(0)
		local r = math.rad(a)
		local s, c = math.sin(r), math.cos(r)
		if isnumber(DispenserArrowTexture) and DispenserArrowTexture > 0 then
			surface.SetTexture(DispenserArrowTexture)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRectRotated(480 * 0.5 - math.floor(81 * s), 240 * 0.90625 - math.floor(81 * c), 50, 200, a)
		end
	end

	local function draw_dispenser_disguise_screen_for_model(mdl, team, frac, idx)
		if not IsValid(mdl) then return end
		local state = dispenserDialStateByEnt[idx] or {}
		local target = calc_dispenser_dial_angle(frac)
		local current = state.angle
		if current == nil then
			current = target
		else
			current = current + math.Clamp(target - current, -4, 4)
		end
		state.angle = current
		dispenserDialStateByEnt[idx] = state

		local cp0 = resolve_attach_with_fallback(
			mdl,
			{"controlpanel0_ll", "control_panel0_ll", "controlpanel0_l", "controlpanel0"},
			Vector(-10.5, -8.5, 49),
			Angle(0, 90, 90)
		)
		local cp1 = resolve_attach_with_fallback(
			mdl,
			{"controlpanel1_ll", "control_panel1_ll", "controlpanel1_l", "controlpanel1"},
			Vector(-10.5, 8.5, 49),
			Angle(0, 90, 90)
		)
		if not cp0 or not cp1 then return end

		cam.Start3D2D(
			cp0.Pos + DispenserPanelOffset.x * cp0.Ang:Forward() + DispenserPanelOffset.y * cp0.Ang:Right() + DispenserPanelOffset.z * cp0.Ang:Up(),
			cp0.Ang,
			DispenserPanelScale
		)
			draw_dispenser_panel_screen(team, current)
		cam.End3D2D()

		cam.Start3D2D(
			cp1.Pos + DispenserPanelOffset.x * cp1.Ang:Forward() + DispenserPanelOffset.y * cp1.Ang:Right() + DispenserPanelOffset.z * cp1.Ang:Up(),
			cp1.Ang,
			DispenserPanelScale
		)
			draw_dispenser_panel_screen(team, current)
		cam.End3D2D()
	end

	local function get_disguised_dispenser_metal_frac(idx)
		local state = dispenserDialStateByEnt[idx] or {}
		local now = CurTime()
		if state.fake_metal == nil then
			state.fake_metal = 25
			state.fake_next_regen = now + 6
		end
		if now >= (state.fake_next_regen or 0) then
			state.fake_metal = math.min(400, (state.fake_metal or 0) + 40)
			state.fake_next_regen = now + 6
		end
		dispenserDialStateByEnt[idx] = state
		return math.Clamp((state.fake_metal or 0) / 400, 0, 1)
	end

	local function get_spy_disguise_draw_info(ply)
		if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return nil end
		if not ply.InCond or not ply:InCond(TF_COND_DISGUISED) then return nil end
		if ply:InCond(TF_COND_DISGUISED_AS_DISPENSER) then return nil end
		if ply:GetNWBool("Cloaked", false) then return nil end

		local className = string.lower(ply:GetNWString("TFSpyDisguiseClass", ""))
		if className == "" then return nil end

		local disguiseTeam = ply:GetNWInt("TFSpyDisguiseTeam", -1)
		if disguiseTeam < 0 then return nil end

		local lp = LocalPlayer()
		if not IsValid(lp) then return nil end
		local forceLocal = GetConVar("tf_debug_spy_disguise_local") and GetConVar("tf_debug_spy_disguise_local"):GetBool() or false
		if lp == ply and not lp:ShouldDrawLocalPlayer() and not forceLocal then return nil end
		local viewerTeam = lp:Team()
		local ownerTeam = ply:Team()
		local isEnemyView = (viewerTeam == disguiseTeam)
		local isFriendlyView = (viewerTeam == ownerTeam)
		if not isEnemyView and not isFriendlyView then return nil end

		local model = DISGUISE_MODEL_BY_CLASS[className]
		local skin = (disguiseTeam == TEAM_BLU or disguiseTeam == TF_TEAM_PVE_INVADERS) and 1 or 0
		local weaponModel, slotKind
		local cosmeticModels = {}
		local maskModel = ""
		local maskClassIndex = nil
		if isEnemyView then
			if not isstring(model) or model == "" then return nil end
			weaponModel, slotKind = resolve_disguise_weapon_model(ply, className)
			cosmeticModels = split_disguise_model_list(ply:GetNWString("TFSpyDisguiseFallbackCosmeticModels", ""))
		else
			model = DISGUISE_MODEL_BY_CLASS.spy
			if not isstring(model) or model == "" then return nil end
			skin = (ownerTeam == TEAM_BLU or ownerTeam == TF_TEAM_PVE_INVADERS) and 1 or 0
			weaponModel, slotKind = resolve_friendly_spy_weapon_model(ply)
			if util.IsValidModel(SPY_DISGUISE_MASK_MODEL) then
				maskModel = SPY_DISGUISE_MASK_MODEL
				maskClassIndex = MASK_CLASS_INDEX_BY_NAME[className]
			end
		end

		local sapperAttackUntil = tonumber(ply:GetNWFloat("TFSpyDisguiseSapperAttackUntil", 0)) or 0
		return {
			model = model,
			skin = skin,
			weaponModel = weaponModel,
			slotKind = slotKind,
			sapperAttackUntil = sapperAttackUntil,
			cosmeticModels = cosmeticModels,
			maskModel = maskModel,
			maskClassIndex = maskClassIndex,
		}
	end

	local DISGUISE_STAND_ACTIVITY_BY_SLOT = {
		primary = ACT_MP_STAND_PRIMARY,
		secondary = ACT_MP_STAND_SECONDARY,
		melee = ACT_MP_STAND_MELEE,
		sapper = ACT_MP_STAND_ITEM2,
	}

	local function apply_disguise_activity_sequence(mdl, ply, slotKind, forceSapperPose, sapperAttackUntil)
		if not IsValid(mdl) or not IsValid(ply) then return end

		if forceSapperPose then
			local attack = CurTime() < (sapperAttackUntil or 0)
			local act = attack and ACT_MP_ATTACK_STAND_ITEM2 or ACT_MP_STAND_ITEM2
			local seq = mdl:SelectWeightedSequence(act)
			if seq and seq >= 0 then
				mdl:SetSequence(seq)
				mdl:SetPlaybackRate(1)
				mdl:SetCycle(attack and ply:GetCycle() or 0)
				return
			end
		end

		-- 1:1 parity direction: resolve by shared ACT first, never by raw sequence index across different models.
		local sourceSeq = ply:GetSequence()
		local srcAct = (ply.GetSequenceActivity and ply:GetSequenceActivity(sourceSeq)) or -1
		if srcAct and srcAct >= 0 then
			local seq = mdl:SelectWeightedSequence(srcAct)
			if seq and seq >= 0 then
				mdl:SetSequence(seq)
				mdl:SetCycle(ply:GetCycle())
				mdl:SetPlaybackRate(ply:GetPlaybackRate())
				return
			end
		end

		local standAct = DISGUISE_STAND_ACTIVITY_BY_SLOT[slotKind] or ACT_MP_STAND_PRIMARY
		local standSeq = mdl:SelectWeightedSequence(standAct)
		if standSeq and standSeq >= 0 then
			mdl:SetSequence(standSeq)
			mdl:SetCycle(0)
			mdl:SetPlaybackRate(1)
			return
		end

		local fallback = mdl:LookupSequence("idle")
		if fallback and fallback >= 0 then
			mdl:SetSequence(fallback)
			mdl:SetCycle(0)
			mdl:SetPlaybackRate(1)
		end
	end

	function TF_ShouldHideOwnerWearablesForViewer(owner, viewer)
		if not IsValid(owner) or not owner:IsPlayer() then return false end
		if not IsValid(viewer) or not viewer:IsPlayer() then return false end
		local forceLocal = GetConVar("tf_debug_spy_disguise_local") and GetConVar("tf_debug_spy_disguise_local"):GetBool() or false
		if owner == viewer and not viewer:ShouldDrawLocalPlayer() and not forceLocal then return false end
		local disguiseTeam = owner:GetNWInt("TFSpyDisguiseTeam", -1)
		if disguiseTeam < 0 then return false end
		if not owner:GetNWBool("Disguised", false) then return false end
		if owner:GetNWBool("Cloaked", false) then return false end
		if owner:InCond(TF_COND_DISGUISED_AS_DISPENSER) then return false end
		local viewerTeam = viewer:Team()
		if viewerTeam == disguiseTeam then return true end
		if viewerTeam == owner:Team() then return true end
		return false
	end

	hook.Add("PrePlayerDraw", "TFCondDispenserDisguiseDraw", function(ply)
		if not should_draw_dispenser_disguise(ply) then
			cleanup_dispenser_model(ply)
			return
		end

		local idx = ply:EntIndex()
		local mdl = dispenserModelByEnt[idx]
		if not IsValid(mdl) then
			mdl = ClientsideModel("models/buildables/dispenser_light.mdl", RENDERGROUP_OPAQUE)
			if not IsValid(mdl) then return end
			mdl:SetNoDraw(true)
			dispenserModelByEnt[idx] = mdl
		end

		mdl:SetPos(ply:GetPos())
		mdl:SetAngles(Angle(0, ply:EyeAngles().y, 0))
		local disguiseTeam = get_dispenser_disguise_team(ply)
		local skin = ((disguiseTeam == TEAM_BLU or disguiseTeam == TF_TEAM_PVE_INVADERS) and 1) or 0
		mdl:SetSkin(skin)
		mdl:SetupBones()
		mdl:DrawModel()
		local metalFrac = get_disguised_dispenser_metal_frac(idx)
		draw_dispenser_disguise_screen_for_model(mdl, disguiseTeam, metalFrac, idx)

		return true
	end)

	hook.Add("PrePlayerDraw", "TFCondSpyDisguiseDraw", function(ply)
		local info = get_spy_disguise_draw_info(ply)
		if not info then
			cleanup_spy_disguise_models(ply)
			return
		end

		local idx = ply:EntIndex()
		local mdl = spyDisguiseModelByEnt[idx]
		if not IsValid(mdl) then
			mdl = ClientsideModel(info.model, RENDERGROUP_OPAQUE)
			if not IsValid(mdl) then return end
			mdl:SetNoDraw(true)
			spyDisguiseModelByEnt[idx] = mdl
		elseif mdl:GetModel() ~= info.model then
			mdl:SetModel(info.model)
		end

		mdl:SetPos(ply:GetPos())
		mdl:SetAngles(ply:GetAngles())
		mdl:SetSkin(info.skin)
		local forceSapperPose = info.slotKind == "sapper"
		apply_disguise_activity_sequence(mdl, ply, info.slotKind, forceSapperPose, info.sapperAttackUntil)
		mdl:SetupBones()
		mdl:DrawModel()

		local weaponModel = (isstring(info.weaponModel) and util.IsValidModel(info.weaponModel)) and info.weaponModel or ""
		if weaponModel ~= "" then
			local wmdl = spyDisguiseWeaponModelByEnt[idx]
			if not IsValid(wmdl) then
				wmdl = ClientsideModel(weaponModel, RENDERGROUP_OPAQUE)
				if IsValid(wmdl) then
					wmdl:SetNoDraw(true)
					wmdl:SetParent(mdl)
					wmdl:AddEffects(bit.bor(EF_BONEMERGE, EF_BONEMERGE_FASTCULL))
					spyDisguiseWeaponModelByEnt[idx] = wmdl
				end
			elseif wmdl:GetModel() ~= weaponModel then
				wmdl:SetModel(weaponModel)
			end
			wmdl = spyDisguiseWeaponModelByEnt[idx]
			if IsValid(wmdl) then
				wmdl:SetSkin(info.skin)
				wmdl:SetupBones()
				wmdl:DrawModel()
			end
		else
			local staleWep = spyDisguiseWeaponModelByEnt[idx]
			if IsValid(staleWep) then staleWep:Remove() end
			spyDisguiseWeaponModelByEnt[idx] = nil
		end

		local desiredCosmetics = info.cosmeticModels or {}
		local cosmeticModels = spyDisguiseCosmeticModelsByEnt[idx]
		if not istable(cosmeticModels) then
			cosmeticModels = {}
			spyDisguiseCosmeticModelsByEnt[idx] = cosmeticModels
		end
		for i = 1, #desiredCosmetics do
			local desiredModel = desiredCosmetics[i]
			local cmdl = cosmeticModels[i]
			if not IsValid(cmdl) then
				cmdl = ClientsideModel(desiredModel, RENDERGROUP_OPAQUE)
				if IsValid(cmdl) then
					cmdl:SetNoDraw(true)
					cmdl:SetParent(mdl)
					cmdl:AddEffects(bit.bor(EF_BONEMERGE, EF_BONEMERGE_FASTCULL))
					cosmeticModels[i] = cmdl
				end
			elseif cmdl:GetModel() ~= desiredModel then
				cmdl:SetModel(desiredModel)
			end
			cmdl = cosmeticModels[i]
			if IsValid(cmdl) then
				cmdl:SetSkin(info.skin)
				cmdl:SetupBones()
				cmdl:DrawModel()
			end
		end
		for i = #desiredCosmetics + 1, #cosmeticModels do
			local stale = cosmeticModels[i]
			if IsValid(stale) then stale:Remove() end
			cosmeticModels[i] = nil
		end

		local maskModel = (isstring(info.maskModel) and util.IsValidModel(info.maskModel)) and info.maskModel or ""
		if maskModel ~= "" then
			local mmdl = spyDisguiseMaskModelByEnt[idx]
			if not IsValid(mmdl) then
				mmdl = ClientsideModel(maskModel, RENDERGROUP_OPAQUE)
				if IsValid(mmdl) then
					mmdl:SetNoDraw(true)
					mmdl:SetParent(mdl)
					mmdl:AddEffects(bit.bor(EF_BONEMERGE, EF_BONEMERGE_FASTCULL))
					spyDisguiseMaskModelByEnt[idx] = mmdl
				end
			elseif mmdl:GetModel() ~= maskModel then
				mmdl:SetModel(maskModel)
			end
			mmdl = spyDisguiseMaskModelByEnt[idx]
			if IsValid(mmdl) then
				local classGroup = mmdl:FindBodygroupByName("class")
				if classGroup and classGroup >= 0 and info.maskClassIndex then
					mmdl:SetBodygroup(classGroup, math.max(0, tonumber(info.maskClassIndex) or 0))
				end
				mmdl:SetSkin(info.skin)
				mmdl:SetupBones()
				mmdl:DrawModel()
			end
		else
			local staleMask = spyDisguiseMaskModelByEnt[idx]
			if IsValid(staleMask) then staleMask:Remove() end
			spyDisguiseMaskModelByEnt[idx] = nil
		end

		return true
	end)

	hook.Add("EntityRemoved", "TFCondDispenserDisguiseCleanup", function(ent)
		if not ent or not ent.IsPlayer or not ent:IsPlayer() then return end
		cleanup_dispenser_model(ent)
		cleanup_spy_disguise_models(ent)
	end)

	hook.Add("ShutDown", "TFCondDispenserDisguiseShutdown", function()
		for _, mdl in pairs(dispenserModelByEnt) do
			if IsValid(mdl) then
				mdl:Remove()
			end
		end
		dispenserModelByEnt = {}
		for _, mdl in pairs(spyDisguiseModelByEnt) do
			if IsValid(mdl) then mdl:Remove() end
		end
		for _, mdl in pairs(spyDisguiseWeaponModelByEnt) do
			if IsValid(mdl) then mdl:Remove() end
		end
		for _, mdl in pairs(spyDisguiseMaskModelByEnt) do
			if IsValid(mdl) then mdl:Remove() end
		end
		for _, t in pairs(spyDisguiseCosmeticModelsByEnt) do
			if istable(t) then
				for _, mdl in ipairs(t) do
					if IsValid(mdl) then mdl:Remove() end
				end
			end
		end
		spyDisguiseModelByEnt = {}
		spyDisguiseWeaponModelByEnt = {}
		spyDisguiseMaskModelByEnt = {}
		spyDisguiseCosmeticModelsByEnt = {}
	end)
end

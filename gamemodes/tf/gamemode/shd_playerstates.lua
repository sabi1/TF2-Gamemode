
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
--[[
= 8192
= 16384
= 32768
]]

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
			if v.particle and self:HasPlayerState(k, state_override) then
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
			if v.particle2 and self:HasPlayerState(k, state_override) and GetConVar("tf_pyrovision"):GetBool() then
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
		color = {0,0,-255,0},
		overlay = "effects/gas_overlay",
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
}

PrecacheParticleSystem("burningplayer_red")
PrecacheParticleSystem("burningplayer_blue")
PrecacheParticleSystem("burningplayer_corpse")

PrecacheParticleSystem("overhealedplayer_red_pluses")
PrecacheParticleSystem("overhealedplayer_blue_pluses")

PrecacheParticleSystem("blood_antlionguard_injured_heavy")
PrecacheParticleSystem("peejar_drips")
PrecacheParticleSystem("peejar_drips_milk")

PrecacheParticleSystem("eye_powerup_red_lvl_1")
PrecacheParticleSystem("eye_powerup_blue_lvl_1")

PrecacheParticleSystem("eye_powerup_red_lvl_2")
PrecacheParticleSystem("eye_powerup_blue_lvl_2")

PrecacheParticleSystem("eye_powerup_red_lvl_3")
PrecacheParticleSystem("eye_powerup_blue_lvl_3")

PrecacheParticleSystem("eye_powerup_red_lvl_4")
PrecacheParticleSystem("eye_powerup_blue_lvl_4")
PrecacheParticleSystem("mark_for_death")
PrecacheParticleSystem("speed_boost_trail")

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

	self.TFConditionData = self.TFConditionData or {}
	for i = 0, (TF_COND_LAST or 0) - 1 do
		local data = self.TFConditionData[i]
		if not data then
			self.TFConditionData[i] = {
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

function meta:AddCond(eCond, flDuration, pProvider)
	local cond = resolve_cond(eCond)
	if cond == nil or cond < 0 or cond >= (TF_COND_LAST or 0) then return false end

	-- Match TF2: dead players do not take new conditions.
	if self:IsPlayer() and not self:Alive() then
		return false
	end

	ensure_condition_core(self)

	local duration = flDuration
	if duration == nil then duration = PERMANENT_CONDITION end
	local was_active = self:InCond(cond)

	-- list-managed conditions (mirrors CTFConditionList behavior for selected conds)
	local list_handled, list_added_new = cond_list_add(self, cond, duration, pProvider)
	if list_handled then
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
	end

	sync_cond_bits_network(self)
	return true
end

function meta:RemoveCond(eCond, ignore_duration)
	local cond = resolve_cond(eCond)
	if cond == nil or cond < 0 or cond >= (TF_COND_LAST or 0) then return false end
	if not self:InCond(cond) then return false end

	ensure_condition_core(self)
	local list_handled, list_removed = cond_list_remove(self, cond, ignore_duration)
	if list_handled then
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

function meta:ConditionThink()
	ensure_condition_core(self)
	if CLIENT then
		sync_cond_bits_from_network(self)
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

function meta:OnAddStunned()
	self:AddPlayerState(PLAYERSTATE_STUNNED, true)
end

function meta:OnRemoveStunned()
	self:RemovePlayerState(PLAYERSTATE_STUNNED, true)
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

function meta:OnAddStealthed()
	if self.SetNWBool then
		self:SetNWBool("Stealthed", true)
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
	cond_stack_add(self, "freeze_input")
	cond_stack_add(self, "no_weapon")
	update_no_weapon(self)
end

function meta:OnRemoveHalloweenKart()
	cond_stack_remove(self, "freeze_input")
	cond_stack_remove(self, "no_weapon")
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

function meta:OnAddRuneResist()
	self:OnAddDefenseBuff()
end

function meta:OnRemoveRuneResist()
	self:OnRemoveDefenseBuff()
end

function meta:OnAddRuneStrength()
	self:OnAddCritBoost()
end

function meta:OnRemoveRuneStrength()
	self:OnRemoveCritBoost()
end

function meta:OnAddRuneHaste()
	set_speed_mult(self, "rune_haste", 1.25)
end

function meta:OnRemoveRuneHaste()
	clear_speed_mult(self, "rune_haste")
end

function meta:OnAddRuneRegen()
	update_regen_timer(self)
end

function meta:OnRemoveRuneRegen()
	update_regen_timer(self)
end

function meta:OnAddRuneVampire()
	self:SetNWBool("RuneVampire", true)
end

function meta:OnRemoveRuneVampire()
	self:SetNWBool("RuneVampire", false)
end

function meta:OnAddRuneReflect()
	self:SetNWBool("RuneReflect", true)
end

function meta:OnRemoveRuneReflect()
	self:SetNWBool("RuneReflect", false)
end

function meta:OnAddRunePrecision()
	self:OnAddCritBoost()
end

function meta:OnRemoveRunePrecision()
	self:OnRemoveCritBoost()
end

function meta:OnAddRuneAgility()
	set_speed_mult(self, "rune_agility", 1.15)
end

function meta:OnRemoveRuneAgility()
	clear_speed_mult(self, "rune_agility")
end

function meta:OnAddRuneKnockout()
	self:OnAddOffenseBuff()
end

function meta:OnRemoveRuneKnockout()
	self:OnRemoveOffenseBuff()
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
end

function meta:OnRemoveRuneKing()
	self:OnRemoveOffenseBuff()
	self:OnRemoveDefenseBuff()
	clear_speed_mult(self, "rune_king")
	update_regen_timer(self)
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
end

function meta:OnRemoveRuneSupernova()
	self:OnRemoveCritBoost()
	self:OnRemoveInvulnerable()
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
end

function meta:OnRemoveRunePlague()
	self:OnRemoveCondGas()
end

function meta:OnAddCompetitiveWinner()
	self:OnAddCritBoost()
end

function meta:OnRemoveCompetitiveWinner()
	self:OnRemoveCritBoost()
end

function meta:OnAddCompetitiveLoser()
	self:OnAddMarkedForDeathSilent()
end

function meta:OnRemoveCompetitiveLoser()
	self:OnRemoveMarkedForDeathSilent()
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
	if eCond == TF_COND_HEALTH_BUFF then return end
	if eCond == TF_COND_CRITBOOSTED_FIRST_BLOOD then
		self:SetFirstBloodBoosted(true)
		self:OnAddCritBoost()
		return
	end

	local cond_handlers = {
		[TF_COND_ZOOMED] = "OnAddZoomed",
		[TF_COND_TMPDAMAGEBONUS] = "OnAddTmpDamageBonus",
		[TF_COND_HEALTH_OVERHEALED] = "OnAddOverhealed",
		[TF_COND_FEIGN_DEATH] = "OnAddFeignDeath",
		[TF_COND_STEALTHED] = "OnAddStealthed",
		[TF_COND_STEALTHED_USER_BUFF] = "OnAddStealthed",
		[TF_COND_INVULNERABLE] = "OnAddInvulnerable",
		[TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED] = "OnAddInvulnerable",
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
		[TF_COND_STEALTHED_USER_BUFF_FADING] = "OnAddStealthedUserBuffFade",
		[TF_COND_BULLET_IMMUNE] = "OnAddBulletImmune",
		[TF_COND_BLAST_IMMUNE] = "OnAddBlastImmune",
		[TF_COND_FIRE_IMMUNE] = "OnAddFireImmune",
		[TF_COND_MVM_BOT_STUN_RADIOWAVE] = "OnAddMVMBotRadiowave",
		[TF_COND_HALLOWEEN_SPEED_BOOST] = "OnAddHalloweenSpeedBoost",
		[TF_COND_HALLOWEEN_QUICK_HEAL] = "OnAddHalloweenQuickHeal",
		[TF_COND_HALLOWEEN_GIANT] = "OnAddHalloweenGiant",
		[TF_COND_HALLOWEEN_TINY] = "OnAddHalloweenTiny",
		[TF_COND_HALLOWEEN_GHOST_MODE] = "OnAddHalloweenGhostMode",
		[TF_COND_PARACHUTE_ACTIVE] = "OnAddCondParachute",
		[TF_COND_PARACHUTE_DEPLOYED] = "OnAddCondParachute",
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
		[TF_COND_PASSTIME_INTERCEPTION] = "OnAddPasstimeInterception",
		[TF_COND_RUNE_KING] = "OnAddRuneKing",
		[TF_COND_KING_BUFFED] = "OnAddKingBuff",
		[TF_COND_RUNE_SUPERNOVA] = "OnAddRuneSupernova",
		[TF_COND_RUNE_PLAGUE] = "OnAddRunePlague",
		[TF_COND_PLAGUE] = "OnAddPlague",
		[TF_COND_PURGATORY] = "OnAddInPurgatory",
		[TF_COND_COMPETITIVE_WINNER] = "OnAddCompetitiveWinner",
		[TF_COND_COMPETITIVE_LOSER] = "OnAddCompetitiveLoser",
		[TF_COND_GAS] = "OnAddCondGas",
		[TF_COND_BURNING_PYRO] = "OnAddBurningPyro",
		[TF_COND_MINICRITBOOSTED_ON_KILL] = "OnAddOffenseBuff",
		[TF_COND_ROCKETPACK] = "OnAddRocketPack",
		[TF_COND_HALLOWEEN_HELL_HEAL] = "OnAddHalloweenHellHeal",
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
		[TF_COND_STEALTHED_USER_BUFF] = "OnRemoveStealthed",
		[TF_COND_DISGUISED] = "OnRemoveDisguised",
		[TF_COND_DISGUISING] = "OnRemoveDisguising",
		[TF_COND_INVULNERABLE] = "OnRemoveInvulnerable",
		[TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED] = "OnRemoveInvulnerable",
		[TF_COND_INVULNERABLE_USER_BUFF] = "OnRemoveInvulnerable",
		[TF_COND_INVULNERABLE_CARD_EFFECT] = "OnRemoveInvulnerable",
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
		[TF_COND_STEALTHED_USER_BUFF_FADING] = "OnRemoveStealthedUserBuffFade",
		[TF_COND_BULLET_IMMUNE] = "OnRemoveBulletImmune",
		[TF_COND_BLAST_IMMUNE] = "OnRemoveBlastImmune",
		[TF_COND_FIRE_IMMUNE] = "OnRemoveFireImmune",
		[TF_COND_MVM_BOT_STUN_RADIOWAVE] = "OnRemoveMVMBotRadiowave",
		[TF_COND_HALLOWEEN_SPEED_BOOST] = "OnRemoveHalloweenSpeedBoost",
		[TF_COND_HALLOWEEN_QUICK_HEAL] = "OnRemoveHalloweenQuickHeal",
		[TF_COND_HALLOWEEN_GIANT] = "OnRemoveHalloweenGiant",
		[TF_COND_HALLOWEEN_TINY] = "OnRemoveHalloweenTiny",
		[TF_COND_HALLOWEEN_GHOST_MODE] = "OnRemoveHalloweenGhostMode",
		[TF_COND_PARACHUTE_ACTIVE] = "OnRemoveCondParachute",
		[TF_COND_PARACHUTE_DEPLOYED] = "OnRemoveCondParachute",
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
		[TF_COND_PASSTIME_INTERCEPTION] = "OnRemovePasstimeInterception",
		[TF_COND_RUNE_PLAGUE] = "OnRemoveRunePlague",
		[TF_COND_PLAGUE] = "OnRemovePlague",
		[TF_COND_PURGATORY] = "OnRemoveInPurgatory",
		[TF_COND_RUNE_KING] = "OnRemoveRuneKing",
		[TF_COND_KING_BUFFED] = "OnRemoveKingBuff",
		[TF_COND_RUNE_SUPERNOVA] = "OnRemoveRuneSupernova",
		[TF_COND_COMPETITIVE_WINNER] = "OnRemoveCompetitiveWinner",
		[TF_COND_COMPETITIVE_LOSER] = "OnRemoveCompetitiveLoser",
		[TF_COND_GAS] = "OnRemoveCondGas",
		[TF_COND_ROCKETPACK] = "OnRemoveRocketPack",
		[TF_COND_BURNING_PYRO] = "OnRemoveBurningPyro",
		[TF_COND_MINICRITBOOSTED_ON_KILL] = "OnRemoveOffenseBuff",
		[TF_COND_HALLOWEEN_HELL_HEAL] = "OnRemoveHalloweenHellHeal",
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
end

hook.Add("Move", "TFCondMoveAdjust", function(pl, move)
	if not IsValid(pl) or not pl.InCond then return end

	if pl:InCond(TF_COND_FREEZE_INPUT) or (pl:InCond(TF_COND_TAUNTING) and not pl:GetNWBool("TauntingMoped", false)) then
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

		if pl:InCond(TF_COND_FREEZE_INPUT) or (pl:InCond(TF_COND_TAUNTING) and not pl:GetNWBool("TauntingMoped", false)) then
			cmd:ClearMovement()
			cmd:RemoveKey(IN_ATTACK)
			cmd:RemoveKey(IN_ATTACK2)
			cmd:RemoveKey(IN_RELOAD)
		elseif pl:GetNWBool("NoWeapon", false) and not pl:GetNWBool("TauntingMoped", false) then
			cmd:RemoveKey(IN_ATTACK)
			cmd:RemoveKey(IN_ATTACK2)
			cmd:RemoveKey(IN_RELOAD)
		end
	end)

	hook.Add("PlayerSwitchWeapon", "TFCondWeaponRestrictions", function(pl, oldWep, newWep)
		if not IsValid(pl) or not pl.InCond or not IsValid(newWep) then return end

		if pl:InCond(TF_COND_MELEE_ONLY) and not is_melee_weapon(newWep) then
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
		pl._tf_cond_stacks = nil
		pl._tf_cond_speed = nil
		pl:SetNWFloat("TFCondSpeedMult", 1)
	end)
end

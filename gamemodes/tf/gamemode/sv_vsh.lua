CreateConVar("tf_vsh_enabled", "1", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Enable Versus Saxton Hale mode.")
CreateConVar("tf_vsh_force", "0", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Force VSH mode even on non-VSH maps.")
CreateConVar("tf_vsh_autostart", "1", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Automatically start VSH rounds.")
CreateConVar("tf_vsh_min_players", "2", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Minimum player count to start VSH.")
CreateConVar("tf_vsh_round_restart_delay", "8", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Round restart delay.")
CreateConVar("tf_vsh_allow_boss_bots", "1", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Allow bots to become boss.")
CreateConVar("tf_vsh_allow_fighter_bots", "1", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Allow bots as BLU fighters.")
CreateConVar("tf_vsh_boss_rage_from_damage", "0.12", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Rage gained per damage point received.")
CreateConVar("tf_vsh_boss_melee_mult", "3.8", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Boss melee damage multiplier.")
CreateConVar("tf_vsh_debug", "0", { FCVAR_ARCHIVE }, "Enable VSH debug output.")

TF_VSH = TF_VSH or {}
TF_VSH.State = TF_VSH.State or {
	Active = false,
	RoundActive = false,
	RoundEnding = false,
	RoundStartTime = 0,
	NextRoundAt = 0,
	Boss = nil,
	BossId = nil,
}
TF_VSH.Bosses = TF_VSH.Bosses or {}
TF_VSH.Abilities = TF_VSH.Abilities or {}
TF_VSH.PlayerState = TF_VSH.PlayerState or {}

local STATE = TF_VSH.State

local DEFAULT_FIGHTER_CLASSES = {
	"scout",
	"soldier",
	"pyro",
	"demoman",
	"heavy",
	"engineer",
	"medic",
	"sniper",
	"spy",
}

local function VSHDebug(msg)
	local cv = GetConVar("tf_vsh_debug")
	if cv and cv:GetBool() then
		print("[TF_VSH] " .. tostring(msg))
	end
end

local function GetPlayerKey(ply)
	if not IsValid(ply) then return nil end
	return ply:SteamID64() or ("ent_" .. ply:EntIndex())
end

local function GetStateForPlayer(ply)
	if not IsValid(ply) then return nil end
	local key = GetPlayerKey(ply)
	if not key then return nil end

	TF_VSH.PlayerState[key] = TF_VSH.PlayerState[key] or {
		bossPriority = 0,
		rage = 0,
		rageReady = false,
		lastButtons = 0,
		lastRageAt = 0,
		invulnUntil = 0,
		stunnedUntil = 0,
		stunReason = "",
		ability = {},
	}
	return TF_VSH.PlayerState[key]
end

function TF_IsVSHMap()
	local mapName = string.lower(game.GetMap() or "")
	if string.StartWith(mapName, "vsh_") then return true end
	if string.StartWith(mapName, "arena_vsh_") then return true end
	if string.find(mapName, "_vsh_", 1, true) then return true end
	if string.find(mapName, "saxton", 1, true) then return true end
	if string.find(mapName, "hale", 1, true) then return true end
	return false
end

local function IsEnabled()
	local enabled = GetConVar("tf_vsh_enabled")
	if enabled and not enabled:GetBool() then return false end
	local forced = GetConVar("tf_vsh_force")
	if forced and forced:GetBool() then return true end
	return TF_IsVSHMap()
end

local function IsParticipant(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return false end
	if ply:Team() == TEAM_SPECTATOR then return false end
	return true
end

local function FighterBotAllowed()
	return GetConVar("tf_vsh_allow_fighter_bots"):GetBool()
end

local function BossBotAllowed()
	return GetConVar("tf_vsh_allow_boss_bots"):GetBool()
end

local function IsBoss(ply)
	return IsValid(STATE.Boss) and IsValid(ply) and STATE.Boss == ply
end

local function ClearBossFlags()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) then
			ply:SetNWBool("TF_VSH_Boss", false)
			ply:SetNWString("TF_VSH_BossId", "")
			ply:SetNWFloat("TF_VSH_Rage", 0)
			ply:SetNWFloat("TF_VSH_AbilityCharge", 0)
		end
	end
end

local function UpdateGlobalHudState()
	local boss = STATE.Boss
	local bossName = ""
	local bossHp = 0
	local bossMax = 0
	local bossRage = 0
	local bluAlive = 0

	if IsValid(boss) then
		bossName = boss:Nick()
		bossHp = math.max(0, boss:Health())
		bossMax = math.max(1, boss:GetMaxHealth())
		local st = GetStateForPlayer(boss)
		bossRage = st and st.rage or 0
	end

	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:Team() == TEAM_BLU and ply:Alive() then
			bluAlive = bluAlive + 1
		end
	end

	SetGlobalBool("TF_VSH_Active", STATE.Active)
	SetGlobalBool("TF_VSH_RoundActive", STATE.RoundActive)
	SetGlobalString("TF_VSH_BossName", bossName)
	SetGlobalString("TF_VSH_BossId", tostring(STATE.BossId or ""))
	SetGlobalInt("TF_VSH_BossHP", bossHp)
	SetGlobalInt("TF_VSH_BossMaxHP", bossMax)
	SetGlobalFloat("TF_VSH_BossRage", bossRage)
	SetGlobalInt("TF_VSH_BluAlive", bluAlive)
	SetGlobalFloat("TF_VSH_RoundStart", STATE.RoundStartTime or 0)
	SetGlobalFloat("TF_VSH_NextRoundAt", STATE.NextRoundAt or 0)
end

function TF_VSH.RegisterAbility(id, data)
	if not isstring(id) or id == "" then return end
	if not istable(data) then return end
	data.id = id
	TF_VSH.Abilities[id] = data
end

function TF_VSH.RegisterBoss(id, data)
	if not isstring(id) or id == "" then return end
	if not istable(data) then return end
	data.id = id
	data.weight = tonumber(data.weight) or 1
	data.abilities = data.abilities or {}
	TF_VSH.Bosses[id] = data
end

local function ModelUsable(path)
	if not isstring(path) or path == "" then return false end
	return util.IsValidModel(path) and util.IsValidProp(path)
end

local function EnsureValidBossModel(def)
	if not def then return "models/player/saxton_hale.mdl" end
	if ModelUsable(def.model) then
		return def.model
	end
	return "models/player/saxton_hale.mdl"
end

local function GetBossList()
	local out = {}
	for id, def in pairs(TF_VSH.Bosses) do
		if istable(def) then
			out[#out + 1] = { id = id, def = def }
		end
	end
	return out
end

local function PickBossDefinition()
	local list = GetBossList()
	if #list == 0 then return nil, nil end

	local total = 0
	for _, entry in ipairs(list) do
		total = total + math.max(1, tonumber(entry.def.weight) or 1)
	end
	local pick = math.Rand(0, total)
	local accum = 0
	for _, entry in ipairs(list) do
		accum = accum + math.max(1, tonumber(entry.def.weight) or 1)
		if pick <= accum then
			return entry.id, entry.def
		end
	end
	return list[1].id, list[1].def
end

local function CollectParticipants()
	local out = {}
	for _, ply in ipairs(player.GetAll()) do
		if IsParticipant(ply) then
			if ply:IsBot() and not FighterBotAllowed() then
				continue
			end
			out[#out + 1] = ply
		end
	end
	return out
end

local function EligibleForBoss(ply)
	if not IsParticipant(ply) then return false end
	if ply:IsBot() and not BossBotAllowed() then return false end
	return true
end

local function SelectBossPlayer(players)
	local winner, best = nil, -math.huge
	for _, ply in ipairs(players) do
		if EligibleForBoss(ply) then
			local st = GetStateForPlayer(ply)
			local priority = (st and st.bossPriority or 0) + math.Rand(0, 0.01)
			if priority > best then
				best = priority
				winner = ply
			end
		end
	end
	if not IsValid(winner) then return nil end

	for _, ply in ipairs(players) do
		local st = GetStateForPlayer(ply)
		if st then
			if ply == winner then
				st.bossPriority = 0
			else
				st.bossPriority = st.bossPriority + 1
			end
		end
	end

	return winner
end

local function GetRandomFighterClass()
	return table.Random(DEFAULT_FIGHTER_CLASSES)
end

local function GetAbilityState(st, abilityId)
	st.ability = st.ability or {}
	st.ability[abilityId] = st.ability[abilityId] or {}
	return st.ability[abilityId]
end

local function InitBossAbilities(boss, bossDef)
	if not IsValid(boss) or not istable(bossDef) then return end
	local st = GetStateForPlayer(boss)
	if not st then return end

	st.ability = {}
	st.rage = 0
	st.rageReady = false
	st.lastRageAt = 0
	st.invulnUntil = 0
	st.stunnedUntil = 0
	st.stunReason = ""

	for _, ab in ipairs(bossDef.abilities or {}) do
		local abId = isstring(ab) and ab or (istable(ab) and ab.id) or nil
		local abilityDef = abId and TF_VSH.Abilities[abId] or nil
		if abilityDef and abilityDef.OnInit then
			local abilityState = GetAbilityState(st, abId)
			abilityDef:OnInit(boss, st, abilityState, ab.params or {})
		end
	end
end

local function ApplyBossProfile(boss, bossId, bossDef)
	if not IsValid(boss) then return end
	if not istable(bossDef) then return end

	local enemyCount = 0
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:IsPlayer() and ply ~= boss and ply:Team() == TEAM_BLU then
			enemyCount = enemyCount + 1
		end
	end

	local baseHp = tonumber(bossDef.baseHealth) or 1800
	local hpPerEnemy = tonumber(bossDef.healthPerEnemy) or 650
	local hp = math.floor(math.max(1, baseHp + (enemyCount * hpPerEnemy)))
	local speed = tonumber(bossDef.speed) or 520
	local jump = tonumber(bossDef.jumpPower) or 300
	local modelPath = EnsureValidBossModel(bossDef)
	local scale = tonumber(bossDef.scale) or 1

	boss:SetNWBool("TF_VSH_Boss", true)
	boss:SetNWString("TF_VSH_BossId", bossId)
	boss:SetTeam(TEAM_RED)
	boss:SetMaxHealth(hp)
	boss:SetHealth(hp)
	boss:SetArmor(0)
	if boss.SetClassSpeed then
		boss:SetClassSpeed(speed)
	end
	if boss.SetJumpPower then
		boss:SetJumpPower(jump)
	end

	if boss:GetPlayerClass() ~= "saxton" then
		boss:SetPlayerClass("saxton")
	end
	boss:SetModel(modelPath)
	if boss.SetModelScale then
		boss:SetModelScale(scale, 0)
	end

	boss:StripWeapons()
	boss:StripAmmo()
	boss:Give("tf_weapon_fists")
	boss:SelectWeapon("tf_weapon_fists")

	InitBossAbilities(boss, bossDef)
end

local function IsRoundRunning()
	return STATE.Active and STATE.RoundActive and not STATE.RoundEnding
end

local function EndRound(winner, reason)
	if not IsRoundRunning() then return end
	STATE.RoundEnding = true
	STATE.RoundActive = false
	STATE.NextRoundAt = CurTime() + math.max(2, GetConVar("tf_vsh_round_restart_delay"):GetFloat())

	PrintMessage(HUD_PRINTTALK, string.format("[VSH] %s wins (%s)", team.GetName(winner) or tostring(winner), tostring(reason or "end")))
	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:IsPlayer() then continue end
		if ply:Team() == winner then
			ply:SendLua([[surface.PlaySound("misc/your_team_won.wav")]])
		else
			ply:SendLua([[surface.PlaySound("misc/your_team_lost.wav")]])
		end
	end

	timer.Create("TF_VSH_NextRound", math.max(2, GetConVar("tf_vsh_round_restart_delay"):GetFloat()), 1, function()
		if not STATE.Active then
			STATE.RoundEnding = false
			STATE.Boss = nil
			STATE.BossId = nil
			ClearBossFlags()
			UpdateGlobalHudState()
			return
		end
		STATE.RoundEnding = false
		STATE.Boss = nil
		STATE.BossId = nil
		ClearBossFlags()
		for _, ply in ipairs(player.GetAll()) do
			if not IsValid(ply) or not ply:IsPlayer() then continue end
			if ply:Team() == TEAM_SPECTATOR then continue end
			if ply:Alive() then
				ply:KillSilent()
			end
			ply:Spawn()
		end
		timer.Simple(0.1, function()
			if STATE.Active then
				TF_VSH.TryStartRound()
			end
		end)
	end)
end

local function CheckRoundWin()
	if not IsRoundRunning() then return end

	local boss = STATE.Boss
	if not IsValid(boss) or not boss:Alive() or boss:Team() ~= TEAM_RED then
		EndRound(TEAM_BLU, "boss_dead")
		return
	end

	local bluAlive = 0
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply:Team() == TEAM_BLU then
			bluAlive = bluAlive + 1
		end
	end
	if bluAlive <= 0 then
		EndRound(TEAM_RED, "fighters_dead")
	end
end

function TF_VSH.TryStartRound()
	if not STATE.Active then return false end
	if STATE.RoundActive or STATE.RoundEnding then return false end

	local minPlayers = math.max(2, GetConVar("tf_vsh_min_players"):GetInt())
	local players = CollectParticipants()
	if #players < minPlayers then return false end

	local bossPlayer = SelectBossPlayer(players)
	if not IsValid(bossPlayer) then return false end

	local bossId, bossDef
	if isstring(STATE.BossId) and STATE.BossId ~= "" and TF_VSH.Bosses[STATE.BossId] then
		bossId = STATE.BossId
		bossDef = TF_VSH.Bosses[bossId]
	else
		bossId, bossDef = PickBossDefinition()
	end
	if not bossId or not bossDef then
		bossId = "hale"
		bossDef = TF_VSH.Bosses.hale
	end
	if not bossDef then return false end

	STATE.Boss = bossPlayer
	STATE.BossId = bossId
	STATE.RoundActive = true
	STATE.RoundEnding = false
	STATE.RoundStartTime = CurTime()
	STATE.NextRoundAt = 0
	GAMEMODE.round_active = true

	ClearBossFlags()

	for _, ply in ipairs(players) do
		if ply == bossPlayer then
			ply:SetTeam(TEAM_RED)
			ply:SetPlayerClass("saxton")
		else
			ply:SetTeam(TEAM_BLU)
			if ply:GetPlayerClass() == "saxton" then
				ply:SetPlayerClass(GetRandomFighterClass())
			end
		end
		if ply:Alive() then
			ply:KillSilent()
		end
		ply:Spawn()
	end

	timer.Simple(0.1, function()
		if not IsRoundRunning() then return end
		if not IsValid(STATE.Boss) then return end
		ApplyBossProfile(STATE.Boss, bossId, bossDef)
		PrintMessage(HUD_PRINTTALK, string.format("[VSH] Boss is %s (%s)", STATE.Boss:Nick(), tostring(bossDef.name or bossId)))
		UpdateGlobalHudState()
	end)

	return true
end

local function UpdateRageHudForBoss(boss, st)
	if not IsValid(boss) or not st then return end
	boss:SetNWFloat("TF_VSH_Rage", math.Clamp(st.rage or 0, 0, 100))
end

local function TriggerBossRage(boss)
	if not IsRoundRunning() or not IsBoss(boss) then return false end
	local bossDef = TF_VSH.Bosses[STATE.BossId or ""]
	local st = GetStateForPlayer(boss)
	if not bossDef or not st then return false end
	if (st.rage or 0) < 100 then return false end

	st.rage = 0
	st.rageReady = false
	st.lastRageAt = CurTime()
	UpdateRageHudForBoss(boss, st)

	local fired = false
	for _, ab in ipairs(bossDef.abilities or {}) do
		local abId = isstring(ab) and ab or (istable(ab) and ab.id) or nil
		local params = istable(ab) and ab.params or {}
		local def = abId and TF_VSH.Abilities[abId] or nil
		if def and def.OnRage then
			local abilityState = GetAbilityState(st, abId)
			if def:OnRage(boss, st, abilityState, params) ~= false then
				fired = true
			end
		end
	end
	if fired then
		boss:EmitSound("misc/halloween/spell_spawn_boss.wav", 90, 100, 1)
		ParticleEffectAttach("halloween_boss_summon", PATTACH_ABSORIGIN_FOLLOW, boss, 0)
	end
	return fired
end

local function NearestEnemy(fromPly, range)
	if not IsValid(fromPly) then return nil end
	local best, bestDist = nil, math.huge
	local maxDist = tonumber(range) or 3000
	local myPos = fromPly:GetPos()
	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then continue end
		if ply:Team() == fromPly:Team() then continue end
		local d = myPos:DistToSqr(ply:GetPos())
		if d < (maxDist * maxDist) and d < bestDist then
			bestDist = d
			best = ply
		end
	end
	return best, math.sqrt(bestDist)
end

local function ApplyStun(victim, duration, reason)
	if not IsValid(victim) or not victim:IsPlayer() then return end
	local st = GetStateForPlayer(victim)
	if not st then return end
	st.stunnedUntil = math.max(st.stunnedUntil or 0, CurTime() + math.max(0.1, duration or 1))
	st.stunReason = reason or "stunned"
	victim:ScreenFade(SCREENFADE.IN, Color(180, 200, 255, 80), 0.2, 0.1)
	victim:EmitSound("player/pl_impact_stun.wav", 70, 105, 0.8)
end

TF_VSH.RegisterAbility("brave_jump", {
	OnInit = function(self, boss, st, abilityState, params)
		abilityState.charge = 0
		abilityState.lastRelease = 0
	end,
	OnTick = function(self, boss, st, abilityState, params, dt)
		boss:SetNWFloat("TF_VSH_AbilityCharge", math.Clamp(abilityState.charge or 0, 0, 1))
	end,
	OnCommand = function(self, boss, st, abilityState, params, cmd, buttons, changed)
		local maxCharge = tonumber(params.maxCharge) or 2.4
		local minCharge = tonumber(params.minCharge) or 0.25
		local upMin = tonumber(params.upMin) or 280
		local upMax = tonumber(params.upMax) or 760
		local fwdMax = tonumber(params.fwdMax) or 560
		local isCharging = bit.band(buttons, IN_RELOAD) ~= 0 and boss:OnGround()
		local now = CurTime()
		local dt = FrameTime()

		if isCharging then
			abilityState.charge = math.Clamp((abilityState.charge or 0) + dt, 0, maxCharge)
			cmd:ClearMovement()
		elseif (abilityState.charge or 0) >= minCharge and now - (abilityState.lastRelease or 0) > 0.2 then
			local t = math.Clamp((abilityState.charge or 0) / maxCharge, 0, 1)
			local up = Lerp(t, upMin, upMax)
			local fwd = Lerp(t, 120, fwdMax)
			local vel = boss:GetForward() * fwd
			vel.z = up
			boss:SetVelocity(vel)
			boss:EmitSound("saxton.LaugherBigSnort01", 90, math.random(95, 105), 0.8)
			ParticleEffectAttach("rocketjump_smoke", PATTACH_ABSORIGIN_FOLLOW, boss, 0)
			abilityState.charge = 0
			abilityState.lastRelease = now
		end
	end,
})

TF_VSH.RegisterAbility("weighdown", {
	OnInit = function(self, boss, st, abilityState, params)
		abilityState.hold = 0
	end,
	OnTick = function() end,
	OnCommand = function(self, boss, st, abilityState, params, cmd, buttons)
		if boss:OnGround() then
			abilityState.hold = 0
			return
		end
		if bit.band(buttons, IN_DUCK) ~= 0 then
			abilityState.hold = (abilityState.hold or 0) + FrameTime()
			if abilityState.hold >= (tonumber(params.holdTime) or 0.6) then
				local v = boss:GetVelocity()
				v.z = -(tonumber(params.downSpeed) or 850)
				local delta = v - boss:GetVelocity()
				boss:SetVelocity(delta)
				abilityState.hold = 0
			end
		else
			abilityState.hold = 0
		end
	end,
})

TF_VSH.RegisterAbility("rage_stun", {
	OnRage = function(self, boss, st, abilityState, params)
		local radius = tonumber(params.radius) or 460
		local dur = tonumber(params.duration) or 3
		local count = 0
		for _, ply in ipairs(player.GetAll()) do
			if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then continue end
			if ply:Team() == boss:Team() then continue end
			if ply:GetPos():DistToSqr(boss:GetPos()) <= (radius * radius) then
				ApplyStun(ply, dur, "rage_stun")
				count = count + 1
			end
		end
		if count > 0 then
			boss:EmitSound("misc/halloween/spell_skeleton_horde_rise.wav", 90, 100, 1)
		end
		return count > 0
	end,
})

TF_VSH.RegisterAbility("rage_uber", {
	OnRage = function(self, boss, st, abilityState, params)
		st.invulnUntil = CurTime() + (tonumber(params.duration) or 4.5)
		boss:EmitSound("misc/your_team_won.wav", 90, 100, 0.7)
		ParticleEffectAttach("critgun_weaponmodel_red_glow", PATTACH_ABSORIGIN_FOLLOW, boss, 0)
		return true
	end,
})

TF_VSH.RegisterAbility("rage_teleport_swap", {
	OnRage = function(self, boss, st, abilityState, params)
		local target = NearestEnemy(boss, tonumber(params.range) or 3000)
		if not IsValid(target) then return false end
		local bossPos = boss:GetPos()
		local targetPos = target:GetPos()
		boss:SetPos(targetPos + Vector(0, 0, 8))
		target:SetPos(bossPos + Vector(0, 0, 8))
		boss:EmitSound("Halloween.Merasmus_TP_In", 90, 100, 1)
		target:EmitSound("Halloween.Merasmus_TP_In", 90, 100, 1)
		ParticleEffectAttach("merasmus_tp", PATTACH_ABSORIGIN_FOLLOW, boss, 0)
		ParticleEffectAttach("merasmus_tp", PATTACH_ABSORIGIN_FOLLOW, target, 0)
		return true
	end,
})

TF_VSH.RegisterAbility("rage_shockwave", {
	OnRage = function(self, boss, st, abilityState, params)
		local radius = tonumber(params.radius) or 540
		local dmg = tonumber(params.damage) or 45
		local push = tonumber(params.push) or 460
		local hit = 0
		for _, ply in ipairs(player.GetAll()) do
			if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then continue end
			if ply:Team() == boss:Team() then continue end
			local delta = ply:GetPos() - boss:GetPos()
			local dist = delta:Length()
			if dist <= radius then
				local dir = delta:GetNormalized()
				ply:SetVelocity(dir * push + Vector(0, 0, 220))
				local info = DamageInfo()
				info:SetAttacker(boss)
				info:SetInflictor(boss)
				info:SetDamageType(DMG_BLAST)
				info:SetDamage(dmg)
				ply:TakeDamageInfo(info)
				hit = hit + 1
			end
		end
		if hit > 0 then
			boss:EmitSound("weapons/explode3.wav", 90, 95, 1)
			ParticleEffectAttach("asplode_hoodoo_shockwave", PATTACH_ABSORIGIN_FOLLOW, boss, 0)
		end
		return hit > 0
	end,
})

TF_VSH.RegisterBoss("hale", {
	name = "Saxton Hale",
	model = "models/player/saxton_hale.mdl",
	baseHealth = 2200,
	healthPerEnemy = 700,
	speed = 525,
	jumpPower = 320,
	scale = 1.0,
	weight = 8,
	abilities = {
		{ id = "brave_jump", params = { maxCharge = 2.4, upMax = 780, fwdMax = 580 } },
		{ id = "weighdown", params = { holdTime = 0.55, downSpeed = 900 } },
		{ id = "rage_stun", params = { radius = 500, duration = 3.5 } },
	},
})

TF_VSH.RegisterBoss("vagineer", {
	name = "Vagineer",
	model = "models/player/saxton_hale/vagineer_v150.mdl",
	baseHealth = 2100,
	healthPerEnemy = 690,
	speed = 520,
	jumpPower = 315,
	scale = 1.0,
	weight = 3,
	abilities = {
		{ id = "brave_jump", params = { maxCharge = 2.2, upMax = 760, fwdMax = 560 } },
		{ id = "weighdown", params = { holdTime = 0.55, downSpeed = 860 } },
		{ id = "rage_uber", params = { duration = 4.8 } },
	},
})

TF_VSH.RegisterBoss("hhh", {
	name = "Horseless Headless Horsemann",
	model = "models/bots/headless_hatman.mdl",
	baseHealth = 2500,
	healthPerEnemy = 760,
	speed = 510,
	jumpPower = 300,
	scale = 1.05,
	weight = 3,
	abilities = {
		{ id = "brave_jump", params = { maxCharge = 2.8, upMax = 820, fwdMax = 520 } },
		{ id = "weighdown", params = { holdTime = 0.50, downSpeed = 980 } },
		{ id = "rage_shockwave", params = { radius = 560, damage = 55, push = 520 } },
	},
})

TF_VSH.RegisterBoss("merasmus", {
	name = "Merasmus",
	model = "models/bots/merasmus/merasmus.mdl",
	baseHealth = 2300,
	healthPerEnemy = 700,
	speed = 515,
	jumpPower = 305,
	scale = 1.0,
	weight = 2,
	abilities = {
		{ id = "brave_jump", params = { maxCharge = 2.4, upMax = 760, fwdMax = 550 } },
		{ id = "weighdown", params = { holdTime = 0.55, downSpeed = 860 } },
		{ id = "rage_teleport_swap", params = { range = 3200 } },
	},
})

TF_VSH.RegisterBoss("yeti", {
	name = "Yeti",
	model = "models/player/yeti.mdl",
	baseHealth = 2800,
	healthPerEnemy = 820,
	speed = 500,
	jumpPower = 330,
	scale = 1.08,
	weight = 2,
	abilities = {
		{ id = "brave_jump", params = { maxCharge = 2.0, upMax = 840, fwdMax = 620 } },
		{ id = "weighdown", params = { holdTime = 0.45, downSpeed = 1080 } },
		{ id = "rage_shockwave", params = { radius = 620, damage = 60, push = 600 } },
	},
})

TF_VSH.RegisterBoss("cbs", {
	name = "Christian Brutal Sniper",
	model = "models/player/saxton_hale/cbs_v4.mdl",
	baseHealth = 2150,
	healthPerEnemy = 680,
	speed = 530,
	jumpPower = 315,
	scale = 1.0,
	weight = 2,
	abilities = {
		{ id = "brave_jump", params = { maxCharge = 2.1, upMax = 760, fwdMax = 610 } },
		{ id = "weighdown", params = { holdTime = 0.55, downSpeed = 840 } },
		{ id = "rage_stun", params = { radius = 420, duration = 2.8 } },
	},
})

local function TickBossAbilities()
	if not IsRoundRunning() then return end
	local boss = STATE.Boss
	if not IsValid(boss) then return end
	local bossDef = TF_VSH.Bosses[STATE.BossId or ""]
	local st = GetStateForPlayer(boss)
	if not bossDef or not st then return end

	for _, ab in ipairs(bossDef.abilities or {}) do
		local abId = isstring(ab) and ab or (istable(ab) and ab.id) or nil
		local params = istable(ab) and ab.params or {}
		local def = abId and TF_VSH.Abilities[abId] or nil
		if def and def.OnTick then
			local ast = GetAbilityState(st, abId)
			def:OnTick(boss, st, ast, params, FrameTime())
		end
	end
	UpdateRageHudForBoss(boss, st)
end

local function ProcessBossInput(boss, cmd)
	if not IsRoundRunning() then return end
	if not IsBoss(boss) then return end
	local bossDef = TF_VSH.Bosses[STATE.BossId or ""]
	local st = GetStateForPlayer(boss)
	if not bossDef or not st then return end

	local buttons = cmd:GetButtons()
	local changed = bit.bxor(st.lastButtons or 0, buttons)
	local pressedAttack2 = bit.band(changed, IN_ATTACK2) ~= 0 and bit.band(buttons, IN_ATTACK2) ~= 0

	if pressedAttack2 and st.rage >= 100 then
		TriggerBossRage(boss)
	end

	for _, ab in ipairs(bossDef.abilities or {}) do
		local abId = isstring(ab) and ab or (istable(ab) and ab.id) or nil
		local params = istable(ab) and ab.params or {}
		local def = abId and TF_VSH.Abilities[abId] or nil
		if def and def.OnCommand then
			local ast = GetAbilityState(st, abId)
			def:OnCommand(boss, st, ast, params, cmd, buttons, changed)
		end
	end

	st.lastButtons = buttons
end

local function ProcessStun(ply, cmd)
	local st = GetStateForPlayer(ply)
	if not st then return false end
	if (st.stunnedUntil or 0) <= CurTime() then return false end
	cmd:ClearButtons()
	cmd:ClearMovement()
	return true
end

local function ProcessBossBotAI(ply, cmd)
	if not IsRoundRunning() then return end
	if not IsBoss(ply) then return end
	if not ply:IsBot() then return end

	local target, dist = NearestEnemy(ply, 5000)
	if not IsValid(target) then return end

	local dir = (target:GetPos() - ply:GetPos()):Angle()
	cmd:SetViewAngles(Angle(0, dir.y, 0))
	ply:SetEyeAngles(Angle(0, dir.y, 0))
	cmd:SetForwardMove(10000)
	cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_SPEED))

	if dist and dist <= 125 then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
	end

	local st = GetStateForPlayer(ply)
	if st and st.rage >= 100 and dist and dist <= 600 then
		TriggerBossRage(ply)
	end

	if ply:OnGround() and dist and dist >= 450 and math.random(1, 22) == 1 then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_RELOAD))
	end
end

hook.Add("Initialize", "TF_VSH_Init", function()
	STATE.Active = IsEnabled()
	if STATE.Active then
		VSHDebug("Mode enabled")
	end
	UpdateGlobalHudState()
end)

hook.Add("InitPostEntity", "TF_VSH_Autostart", function()
	STATE.Active = IsEnabled()
	UpdateGlobalHudState()
	if not STATE.Active then return end
	if not GetConVar("tf_vsh_autostart"):GetBool() then return end
	timer.Create("TF_VSH_AutostartPoll", 1, 0, function()
		if not STATE.Active then return end
		if STATE.RoundActive or STATE.RoundEnding then return end
		TF_VSH.TryStartRound()
	end)
end)

hook.Add("Think", "TF_VSH_Think", function()
	if not STATE.Active then return end
	TickBossAbilities()
	CheckRoundWin()
	UpdateGlobalHudState()
end)

hook.Add("StartCommand", "TF_VSH_StartCommand", function(ply, cmd)
	if not STATE.Active then return end
	if not IsValid(ply) or not ply:IsPlayer() then return end
	if ProcessStun(ply, cmd) then return end
	ProcessBossInput(ply, cmd)
	ProcessBossBotAI(ply, cmd)
end)

hook.Add("PlayerInitialSpawn", "TF_VSH_PlayerInitialSpawn", function(ply)
	if not STATE.Active then return end
	if not IsValid(ply) or not ply:IsPlayer() then return end
	GetStateForPlayer(ply)
	timer.Simple(0.1, function()
		if not IsValid(ply) or not STATE.Active then return end
		if STATE.RoundActive then
			ply:SetTeam(TEAM_SPECTATOR)
			ply:ChatPrint("[VSH] Round in progress. You join next round.")
		elseif ply:Team() == TEAM_SPECTATOR then
			ply:SetTeam(TEAM_BLU)
		end
	end)
end)

hook.Add("PlayerSpawn", "TF_VSH_PlayerSpawn", function(ply)
	if not STATE.Active then return end
	if not IsValid(ply) or not ply:IsPlayer() then return end
	local st = GetStateForPlayer(ply)
	if st then
		st.lastButtons = 0
	end
	if ply:Team() == TEAM_SPECTATOR then return end
	if not IsRoundRunning() then
		if ply:GetPlayerClass() == "saxton" and not IsBoss(ply) then
			ply:SetPlayerClass(GetRandomFighterClass())
		end
		return
	end

	if IsBoss(ply) then
		timer.Simple(0, function()
			if not IsValid(ply) or not IsBoss(ply) then return end
			local bossDef = TF_VSH.Bosses[STATE.BossId or ""]
			if bossDef then
				ApplyBossProfile(ply, STATE.BossId, bossDef)
			end
		end)
	else
		ply:SetTeam(TEAM_BLU)
		ply:SetNWBool("TF_VSH_Boss", false)
		ply:SetNWString("TF_VSH_BossId", "")
		if ply:GetPlayerClass() == "saxton" then
			ply:SetPlayerClass(GetRandomFighterClass())
		end
	end
end)

hook.Add("PlayerDeath", "TF_VSH_PlayerDeath", function(victim, attacker)
	if not STATE.Active then return end
	if not IsRoundRunning() then return end
	if not IsValid(victim) or not victim:IsPlayer() then return end
	if IsBoss(victim) then
		EndRound(TEAM_BLU, "boss_death")
		return
	end
	timer.Simple(0, CheckRoundWin)
end)

hook.Add("PlayerDisconnected", "TF_VSH_PlayerDisconnect", function(ply)
	if not STATE.Active then return end
	local key = GetPlayerKey(ply)
	if key then
		TF_VSH.PlayerState[key] = nil
	end
	if IsRoundRunning() and IsBoss(ply) then
		EndRound(TEAM_BLU, "boss_left")
		return
	end
	timer.Simple(0, CheckRoundWin)
end)

hook.Add("EntityTakeDamage", "TF_VSH_Damage", function(target, dmginfo)
	if not STATE.Active or not IsRoundRunning() then return end
	local attacker = dmginfo:GetAttacker()

	if IsValid(target) and target:IsPlayer() and IsBoss(target) then
		local st = GetStateForPlayer(target)
		if st and (st.invulnUntil or 0) > CurTime() then
			dmginfo:SetDamage(0)
			return true
		end

		if dmginfo:IsFallDamage() then
			dmginfo:SetDamage(0)
			return true
		end

		local gain = math.max(0, dmginfo:GetDamage() * math.max(0, GetConVar("tf_vsh_boss_rage_from_damage"):GetFloat()))
		if st and gain > 0 then
			st.rage = math.Clamp((st.rage or 0) + gain, 0, 100)
			st.rageReady = st.rage >= 100
			UpdateRageHudForBoss(target, st)
		end
	end

	if IsValid(attacker) and attacker:IsPlayer() and IsBoss(attacker) and IsValid(target) and target:IsPlayer() and target ~= attacker then
		local mult = math.max(1, GetConVar("tf_vsh_boss_melee_mult"):GetFloat())
		local inf = dmginfo:GetInflictor()
		local infClass = IsValid(inf) and inf:GetClass() or ""
		if inf == attacker or infClass == "tf_weapon_fists" or infClass == "tf_weapon_bat_wood" then
			dmginfo:ScaleDamage(mult)
		end
	end
end)

hook.Add("ShutDown", "TF_VSH_Shutdown", function()
	if timer.Exists("TF_VSH_AutostartPoll") then timer.Remove("TF_VSH_AutostartPoll") end
	if timer.Exists("TF_VSH_NextRound") then timer.Remove("TF_VSH_NextRound") end
end)

concommand.Add("tf_vsh_start", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end
	STATE.Active = true
	STATE.RoundActive = false
	STATE.RoundEnding = false
	STATE.Boss = nil
	STATE.BossId = nil
	ClearBossFlags()
	UpdateGlobalHudState()
	TF_VSH.TryStartRound()
end)

concommand.Add("tf_vsh_stop", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end
	STATE.Active = false
	STATE.RoundActive = false
	STATE.RoundEnding = false
	STATE.Boss = nil
	STATE.BossId = nil
	ClearBossFlags()
	UpdateGlobalHudState()
	PrintMessage(HUD_PRINTTALK, "[VSH] Mode stopped.")
end)

concommand.Add("tf_vsh_status", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end
	local line = string.format(
		"[VSH] active=%s round=%s ending=%s boss=%s bossId=%s",
		tostring(STATE.Active),
		tostring(STATE.RoundActive),
		tostring(STATE.RoundEnding),
		IsValid(STATE.Boss) and STATE.Boss:Nick() or "<none>",
		tostring(STATE.BossId or "")
	)
	print(line)
	if IsValid(ply) then ply:ChatPrint(line) end
end)

concommand.Add("tf_vsh_setboss", function(ply, _, args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	local id = string.lower(tostring(args and args[1] or ""))
	if id == "" or not TF_VSH.Bosses[id] then
		local names = {}
		for bossId in pairs(TF_VSH.Bosses) do names[#names + 1] = bossId end
		table.sort(names)
		local msg = "[VSH] Bosses: " .. table.concat(names, ", ")
		print(msg)
		if IsValid(ply) then ply:ChatPrint(msg) end
		return
	end
	STATE.BossId = id
	local msg = "[VSH] Next boss set to: " .. id
	print(msg)
	if IsValid(ply) then ply:ChatPrint(msg) end
end)

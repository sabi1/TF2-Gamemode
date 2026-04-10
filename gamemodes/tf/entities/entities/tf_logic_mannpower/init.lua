ENT.Type = "point"

if SERVER and not ConVarExists("tf_powerup_mode") then
	CreateConVar("tf_powerup_mode", "0", { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Enable Mannpower mode rules.")
end
if SERVER and not ConVarExists("tf_powerup_max_charge_time") then
	CreateConVar("tf_powerup_max_charge_time", "20", { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Seconds needed to fully charge the Supernova rune.")
end

local function setGrapplingHookEnabled(enabled)
	local hookCvar = GetConVar("tf_grapplinghook_enable")
	if hookCvar then
		hookCvar:SetBool(enabled and true or false)
	end
end

local function getEligibleRuneSpawns()
	local spawns = {}
	for _, spawn in ipairs(ents.FindByClass("info_powerup_spawn")) do
		local disabled = spawn.IsDisabled and spawn:IsDisabled() or spawn.Disabled
		if IsValid(spawn) and not disabled then
			spawns[#spawns + 1] = spawn
		end
	end
	return spawns
end

local function shuffleInPlace(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

local function clearMapRunes()
	for _, rune in ipairs(ents.FindByClass("item_powerup_rune")) do
		if not IsValid(rune) then continue end
		if IsValid(rune:GetOwner()) then continue end
		rune:Remove()
	end
	for _, spawn in ipairs(ents.FindByClass("info_powerup_spawn")) do
		if IsValid(spawn) then
			spawn.ActiveRune = nil
			spawn.InitialRuneType = nil
		end
	end
end

local function ensureMapRunes()
	if not TF_IsMannpowerMode or not TF_IsMannpowerMode() then return end
	local defs = TF_GetMannpowerRuneDefs and TF_GetMannpowerRuneDefs() or nil
	if not istable(defs) then return end

	local runeTypes = {}
	for runeType, _ in pairs(defs) do
		runeTypes[#runeTypes + 1] = runeType
	end
	if #runeTypes == 0 then return end

	local spawns = getEligibleRuneSpawns()
	if #spawns == 0 then return end

	shuffleInPlace(spawns)
	shuffleInPlace(runeTypes)

	local runeCount = math.min(#spawns, #runeTypes)
	for idx = 1, runeCount do
		local spawn = spawns[idx]
		if not IsValid(spawn) or IsValid(spawn.ActiveRune) then continue end

		local runeType = spawn.InitialRuneType
		if runeType == nil then
			runeType = runeTypes[idx]
			spawn.InitialRuneType = runeType
		end

		local rune = ents.Create("item_powerup_rune")
		if not IsValid(rune) then continue end
		rune:SetPos(spawn:GetPos() + Vector(0, 0, 48))
		rune:SetAngles(Angle(0, 0, 0))
		rune.ApplyForce = false
		rune.ShouldReposition = false
		rune.TeamNum = TEAM_ANY or TEAM_UNASSIGNED
		rune:Spawn()
		rune:Activate()
		rune:SetRuneType(runeType)
		if spawn.SetRune then
			spawn:SetRune(rune)
		else
			rune.SpawnPoint = spawn
			spawn.ActiveRune = rune
		end
	end
end

local function updateMannpowerState()
	local enabled = false
	for _, logic in ipairs(ents.FindByClass("tf_logic_mannpower")) do
		if IsValid(logic) and not logic.Disabled then
			enabled = true
			break
		end
	end

	if GAMEMODE then
		GAMEMODE.IsMannpowerMode = enabled
	end

	SetGlobalBool("tf_mannpower_mode", enabled)
	SetGlobalBool("tf_powerup_mode", enabled)

	local powerupCvar = GetConVar("tf_powerup_mode")
	if powerupCvar then
		powerupCvar:SetBool(enabled and true or false)
	end

	if enabled then
		setGrapplingHookEnabled(true)
	end

	if enabled then
		timer.Simple(0, ensureMapRunes)
	end

	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:IsPlayer() then continue end
		if TF_IsGrapplingHookEnabled and TF_IsGrapplingHookEnabled() then
			if not ply:HasWeapon("tf_weapon_grapplinghook") then
				ply:Give("tf_weapon_grapplinghook")
			end
			timer.Simple(0, function()
				if not IsValid(ply) or not ply:IsPlayer() or not TF_IsMannpowerMode() then return end
				if ply:HasWeapon("tf_weapon_grapplinghook") then
					ply:SelectWeapon("tf_weapon_grapplinghook")
				end
			end)
		elseif ply:HasWeapon("tf_weapon_grapplinghook") then
			ply:StripWeapon("tf_weapon_grapplinghook")
		end
	end
end

function TF_IsMannpowerMode()
	return GetGlobalBool("tf_mannpower_mode", false)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = tonumber((self.Properties or {}).startdisabled or 0) == 1
	timer.Simple(0, updateMannpowerState)
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "startdisabled" then
		self.Disabled = tonumber(value) == 1
	end
end

function ENT:AcceptInput(name)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Disabled = false
		updateMannpowerState()
		return true
	elseif name == "disable" then
		self.Disabled = true
		updateMannpowerState()
		return true
	elseif name == "roundspawn" or name == "roundactivate" then
		clearMapRunes()
		updateMannpowerState()
		return true
	end
	return false
end

hook.Add("PlayerSpawn", "TF_Mannpower_GiveGrapplingHook", function(ply)
	if not TF_IsGrapplingHookEnabled or not TF_IsGrapplingHookEnabled() then return end
	timer.Simple(0, function()
		if not IsValid(ply) or not ply:IsPlayer() then return end
		if not ply:HasWeapon("tf_weapon_grapplinghook") then
			ply:Give("tf_weapon_grapplinghook")
		end
		if TF_IsMannpowerMode() and ply:HasWeapon("tf_weapon_grapplinghook") then
			ply:SelectWeapon("tf_weapon_grapplinghook")
		end
	end)
end)

cvars.AddChangeCallback("tf_grapplinghook_enable", function(_, _, newValue)
	local enabled = tobool(newValue)
	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:IsPlayer() then continue end
		if enabled or TF_IsMannpowerMode() then
			if not ply:HasWeapon("tf_weapon_grapplinghook") then
				ply:Give("tf_weapon_grapplinghook")
			end
		elseif ply:HasWeapon("tf_weapon_grapplinghook") then
			ply:StripWeapon("tf_weapon_grapplinghook")
		end
	end
end, "TF_GrapplingHook_EnableSync")

hook.Add("PlayerDeath", "TF_Mannpower_DropRuneOnDeath", function(ply)
	if not TF_IsMannpowerMode() or not IsValid(ply) or not ply.DropRune then return end
	ply:SetNWBool("TFKingRuneBuffActive", false)
	ply:SetNWBool("TFRuneCharged", false)
	local enemyTeam = ply:Team() == TEAM_RED and TEAM_BLU or TEAM_RED
	ply:DropRune(false, enemyTeam)
end)

hook.Add("PlayerDisconnected", "TF_Mannpower_DropRuneOnDisconnect", function(ply)
	if not TF_IsMannpowerMode() or not IsValid(ply) or not ply.DropRune then return end
	ply:SetNWBool("TFKingRuneBuffActive", false)
	ply:SetNWBool("TFRuneCharged", false)
	ply:DropRune(false, TEAM_ANY or TEAM_UNASSIGNED)
end)

hook.Add("EntityRemoved", "TF_Mannpower_RefreshState", function(ent)
	if not IsValid(ent) then return end
	if ent:GetClass() == "tf_logic_mannpower" then
		timer.Simple(0, updateMannpowerState)
		return
	end
	if ent:GetClass() == "item_powerup_rune" and IsValid(ent.SpawnPoint) then
		ent.SpawnPoint.ActiveRune = nil
	end
end)

hook.Add("InitPostEntity", "TF_Mannpower_EnsureMapRunes", function()
	timer.Simple(0, function()
		clearMapRunes()
		updateMannpowerState()
		ensureMapRunes()
	end)
end)

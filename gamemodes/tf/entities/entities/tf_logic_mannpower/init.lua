ENT.Type = "point"

if SERVER and not ConVarExists("tf_powerup_mode") then
	CreateConVar("tf_powerup_mode", "0", { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Enable Mannpower mode rules.")
end

local function setGrapplingHookEnabled(enabled)
	local hookCvar = GetConVar("tf_grapplinghook_enable")
	if hookCvar then
		hookCvar:SetBool(enabled and true or false)
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

	setGrapplingHookEnabled(enabled)

	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:IsPlayer() then continue end
		if enabled then
			if not ply:HasWeapon("tf_weapon_grapplinghook") then
				ply:Give("tf_weapon_grapplinghook")
			end
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
		updateMannpowerState()
		return true
	end
	return false
end

hook.Add("PlayerSpawn", "TF_Mannpower_GiveGrapplingHook", function(ply)
	if not TF_IsMannpowerMode() then return end
	timer.Simple(0, function()
		if not IsValid(ply) or not ply:IsPlayer() then return end
		if not ply:HasWeapon("tf_weapon_grapplinghook") then
			ply:Give("tf_weapon_grapplinghook")
		end
	end)
end)

hook.Add("EntityRemoved", "TF_Mannpower_RefreshState", function(ent)
	if not IsValid(ent) or ent:GetClass() ~= "tf_logic_mannpower" then return end
	timer.Simple(0, updateMannpowerState)
end)

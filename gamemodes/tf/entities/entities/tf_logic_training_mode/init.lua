ENT.Type = "point"

local TRAINING_CLASS_OUTPUTS = {
	scout = "OnPlayerSpawnAsScout",
	sniper = "OnPlayerSpawnAsSniper",
	soldier = "OnPlayerSpawnAsSoldier",
	demoman = "OnPlayerSpawnAsDemoman",
	medic = "OnPlayerSpawnAsMedic",
	heavy = "OnPlayerSpawnAsHeavy",
	pyro = "OnPlayerSpawnAsPyro",
	spy = "OnPlayerSpawnAsSpy",
	engineer = "OnPlayerSpawnAsEngineer",
}

local TRAINING_WEAPON_OUTPUTS = {
	[0] = "OnPlayerSwappedToPrimary",
	[1] = "OnPlayerSwappedToSecondary",
	[2] = "OnPlayerSwappedToMelee",
	[3] = "OnPlayerSwappedToBuilding",
	[4] = "OnPlayerSwappedToPDA",
	[5] = "OnPlayerSwappedToPDA",
}

local function GetTrainingLogicEntities()
	return ents.FindByClass("tf_logic_training_mode")
end

local function GetPrimaryHumanPlayer()
	for _, ply in ipairs(player.GetHumans()) do
		if IsValid(ply) and not ply:IsBot() then
			return ply
		end
	end
	return NULL
end

local function EmitTrainingClassOutput(logic, ply)
	if not IsValid(logic) or not IsValid(ply) or ply:IsBot() then return end
	local className = string.lower(tostring((ply.GetPlayerClass and ply:GetPlayerClass()) or ""))
	local output = TRAINING_CLASS_OUTPUTS[className]
	if output then
		logic:TriggerOutput(output, ply)
	end
end

local function EmitTrainingWeaponOutput(logic, ply, weapon)
	if not IsValid(logic) or not IsValid(ply) or ply:IsBot() then return end
	if not IsValid(weapon) then return end
	local output = TRAINING_WEAPON_OUTPUTS[weapon:GetSlot()]
	if output then
		logic:TriggerOutput(output, ply)
	end
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.NextMap = tostring(self.Properties.nextmap or "")
	self.TrainingMessage = ""
	self.TrainingObjective = ""
	self.TrainingHudVisible = false
	self.WaitingForTimerOrKeypress = nil
	self.EndTrainingText = ""
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if key == "nextmap" then
		self.NextMap = tostring(value or "")
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))

	if name == "showtrainingmsg" then
		self.TrainingMessage = tostring(data or "")
		SetGlobalString("tf_training_message", self.TrainingMessage)
		for _, ply in ipairs(player.GetHumans()) do
			if IsValid(ply) then
				ply:PrintMessage(HUD_PRINTCENTER, self.TrainingMessage)
			end
		end
		return true
	elseif name == "showtrainingobjective" then
		self.TrainingObjective = tostring(data or "")
		SetGlobalString("tf_training_objective", self.TrainingObjective)
		return true
	elseif name == "forceplayerspawnasclassoutput" then
		for _, ply in ipairs(player.GetHumans()) do
			EmitTrainingClassOutput(self, ply)
		end
		return true
	elseif name == "kickbots" then
		for _, ply in ipairs(player.GetBots()) do
			if IsValid(ply) then
				game.ConsoleCommand(string.format("kickid %d\n", ply:UserID()))
			end
		end
		return true
	elseif name == "showtraininghud" then
		self.TrainingHudVisible = true
		SetGlobalBool("tf_training_hud_visible", true)
		return true
	elseif name == "hidetraininghud" then
		self.TrainingHudVisible = false
		SetGlobalBool("tf_training_hud_visible", false)
		return true
	elseif name == "endtraining" then
		self.EndTrainingText = tostring(data or "")
		SetGlobalString("tf_training_end_text", self.EndTrainingText)
		local human = GetPrimaryHumanPlayer()
		if IsValid(human) then
			GAMEMODE:RoundWin(human:Team())
		end
		return true
	elseif name == "playsoundonplayer" then
		local human = GetPrimaryHumanPlayer()
		if IsValid(human) then
			human:EmitSound(tostring(data or ""))
		end
		return true
	elseif name == "waitfortimerorkeypress" then
		self.WaitingForTimerOrKeypress = ents.FindByName(tostring(data or ""))[1] or NULL
		GAMEMODE.TrainingWaitingForContinue = IsValid(self.WaitingForTimerOrKeypress)
		return true
	elseif name == "setnextmap" then
		self.NextMap = tostring(data or "")
		SetGlobalString("tf_training_next_map", self.NextMap)
		return true
	elseif name == "forceplayerswaptoweapon" then
		local human = GetPrimaryHumanPlayer()
		if not IsValid(human) then
			return false
		end

		local desired = string.lower(tostring(data or ""))
		local slotByName = {
			primary = 0,
			secondary = 1,
			melee = 2,
			building = 3,
			pda = 4,
			grenade = 5,
			item1 = 6,
			item2 = 7,
		}
		local slot = slotByName[desired]
		if slot == nil then
			return false
		end

		for _, wep in ipairs(human:GetWeapons()) do
			if IsValid(wep) and wep:GetSlot() == slot then
				human:SelectWeapon(wep:GetClass())
				return true
			end
		end

		return false
	end
end

concommand.Add("training_continue", function(ply)
	if IsValid(ply) and not ply:IsPlayer() then return end

	for _, logic in ipairs(GetTrainingLogicEntities()) do
		if not IsValid(logic) then continue end
		if not IsValid(logic.WaitingForTimerOrKeypress) then continue end

		logic.WaitingForTimerOrKeypress:Fire("FireTimer", "", 0)
		logic.WaitingForTimerOrKeypress = nil
	end

	GAMEMODE.TrainingWaitingForContinue = false
end)

hook.Add("PlayerSpawn", "TF_TrainingMode_PlayerSpawnOutputs", function(ply)
	if not IsValid(ply) or ply:IsBot() then return end
	for _, logic in ipairs(GetTrainingLogicEntities()) do
		EmitTrainingClassOutput(logic, ply)
	end
end)

hook.Add("PlayerDeath", "TF_TrainingMode_PlayerDeathOutputs", function(victim, inflictor, attacker)
	if not IsValid(victim) then return end
	for _, logic in ipairs(GetTrainingLogicEntities()) do
		if not IsValid(logic) then continue end
		if victim:IsBot() then
			logic:TriggerOutput("OnBotDied", IsValid(attacker) and attacker or victim)
		else
			logic:TriggerOutput("OnPlayerDied", IsValid(attacker) and attacker or victim)
		end
	end
end)

hook.Add("PlayerSwitchWeapon", "TF_TrainingMode_PlayerWeaponOutputs", function(ply, oldWep, newWep)
	if not IsValid(ply) or ply:IsBot() then return end
	for _, logic in ipairs(GetTrainingLogicEntities()) do
		EmitTrainingWeaponOutput(logic, ply, newWep)
	end
end)

ENT.Type = "point"

local function GetWinningTeamFromInput(value)
	return string.lower(tostring(value or "")) == "red" and TEAM_RED or TEAM_BLU
end

local function TeleportTeamToLootSpawn(teamNum, winnerTeam)
	local suffix = teamNum == winnerTeam and "winner" or "loser"
	local targetName = "spawn_loot_" .. suffix

	for _, dest in ipairs(ents.FindByName(targetName)) do
		if not IsValid(dest) then continue end
		for _, ply in ipairs(player.GetAll()) do
			if not IsValid(ply) or not ply:Alive() then continue end
			if ply:Team() ~= teamNum then continue end

			local pos = dest:GetPos() + Vector(math.Rand(-24, 24), math.Rand(-24, 24), 8)
			ply:SetPos(pos)
			ply:SetEyeAngles(dest:GetAngles())
			if tonumber(GAMEMODE.HalloweenTauntInHell or 0) ~= 0 and ply.TFTaunt and IsValid(ply:GetActiveWeapon()) then
				ply:TFTaunt(tostring(ply:GetActiveWeapon():GetSlot() + 1))
			end
		end
		break
	end
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.HolidayType = tonumber(self.Properties.holiday_type) or 1
	self.TauntInHell = tonumber(self.Properties.tauntinhell) or 0
	self.AllowHaunting = tonumber(self.Properties.allowhaunting) or 0
	self.PendingWinningTeam = nil
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if key == "holiday_type" then
		self.HolidayType = tonumber(value) or 1
	elseif key == "tauntinhell" then
		self.TauntInHell = tonumber(value) or 0
	elseif key == "allowhaunting" then
		self.AllowHaunting = tonumber(value) or 0
	end
end

function ENT:ApplyHolidayGlobals()
	if not GAMEMODE then
		return
	end
	GAMEMODE.HalloweenHolidayType = tonumber(self.HolidayType) or 1
	GAMEMODE.HalloweenTauntInHell = tonumber(self.TauntInHell) or 0
	GAMEMODE.HalloweenAllowHaunting = tonumber(self.AllowHaunting) or 0
	SetGlobalInt("tf_holiday_type", GAMEMODE.HalloweenHolidayType)
	SetGlobalInt("tf_halloween_taunt_in_hell", GAMEMODE.HalloweenTauntInHell)
	SetGlobalInt("tf_halloween_allow_haunting", GAMEMODE.HalloweenAllowHaunting)
end

function ENT:TeleportPlayersToHell()
	local winningTeam = self.PendingWinningTeam or TEAM_BLU
	TeleportTeamToLootSpawn(TEAM_RED, winningTeam)
	TeleportTeamToLootSpawn(TEAM_BLU, winningTeam)
	self.PendingWinningTeam = nil
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "halloweensetusingspells" then
		local enabled = (tonumber(data) or 0) ~= 0
		GAMEMODE.HalloweenUsingSpells = enabled
		SetGlobalBool("tf_halloween_using_spells", enabled)
		return true
	elseif name == "halloween2013teleporttohell" then
		self.PendingWinningTeam = GetWinningTeamFromInput(data)
		for _, ply in ipairs(player.GetAll()) do
			if not IsValid(ply) or not ply:Alive() then continue end
			if ply:Team() == TEAM_SPECTATOR then continue end

			ply:ScreenFade(SCREENFADE.OUT, color_white, 2, 0.5)
			if ply.SetFOV then
				ply:SetFOV(10, 2.5)
			end
		end

		for _, ply in ipairs(player.GetAll()) do
			if IsValid(ply) and ply:Team() ~= TEAM_SPECTATOR then
				ply:EmitSound("Halloween.hellride", 75, 100)
			end
		end

		timer.Remove("tf_holiday_teleport_hell_" .. self:EntIndex())
		timer.Create("tf_holiday_teleport_hell_" .. self:EntIndex(), 2.5, 1, function()
			if not IsValid(self) then return end
			self:TeleportPlayersToHell()
		end)
		return true
	end

	return false
end

function ENT:OnRemove()
	timer.Remove("tf_holiday_teleport_hell_" .. self:EntIndex())
end

hook.Add("InitPostEntity", "TF_HolidayLogicApplyGlobals", function()
	for _, logic in ipairs(ents.FindByClass("tf_logic_holiday")) do
		if not IsValid(logic) then continue end
		logic:ApplyHolidayGlobals()
	end
end)

ENT.Type = "point"

local function FindHalloweenDestination(nameHint)
	local normalizedHint = string.lower(tostring(nameHint or ""))
	if normalizedHint ~= "" then
		local exact = ents.FindByName(nameHint)
		if #exact > 0 then
			return exact[1]
		end
	end

	local best, bestScore = nil, -1
	for _, ent in ipairs(ents.GetAll()) do
		if not IsValid(ent) then continue end
		local name = string.lower(ent:GetName() or "")
		if name == "" then continue end

		local score = 0
		if string.find(name, "underworld", 1, true) then score = score + 10 end
		if string.find(name, "hell", 1, true) then score = score + 8 end
		if string.find(name, "teleport", 1, true) then score = score + 3 end
		if normalizedHint ~= "" and string.find(name, normalizedHint, 1, true) then
			score = score + 20
		end

		if score > bestScore then
			bestScore = score
			best = ent
		end
	end

	return best
end

local function GetTeleportPosition(ent)
	if not IsValid(ent) then return nil end
	if ent.GetPos then
		return ent:GetPos()
	end
	return nil
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.HolidayType = tonumber(self.Properties.holiday_type) or 1
	self.TauntInHell = tonumber(self.Properties.tauntinhell) or 0
	self.AllowHaunting = tonumber(self.Properties.allowhaunting) or 0
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

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "halloweensetusingspells" then
		local enabled = (tonumber(data) or 0) ~= 0
		GAMEMODE.HalloweenUsingSpells = enabled
		SetGlobalBool("tf_halloween_using_spells", enabled)
		return true
	elseif name == "halloween2013teleporttohell" then
		local destEnt = FindHalloweenDestination(data)
		local destPos = GetTeleportPosition(destEnt)
		if not isvector(destPos) then
			return false
		end

		for _, ply in ipairs(player.GetAll()) do
			if not IsValid(ply) or not ply:Alive() then continue end
			if ply:Team() == TEAM_SPECTATOR then continue end

			local pos = destPos + Vector(math.Rand(-24, 24), math.Rand(-24, 24), 16)
			ply:SetPos(pos)
			if tonumber(self.TauntInHell or 0) ~= 0 and ply.TFTaunt and IsValid(ply:GetActiveWeapon()) then
				ply:TFTaunt(tostring(ply:GetActiveWeapon():GetSlot() + 1))
			end
		end

		return true
	end
end

hook.Add("InitPostEntity", "TF_HolidayLogicApplyGlobals", function()
	for _, logic in ipairs(ents.FindByClass("tf_logic_holiday")) do
		if not IsValid(logic) then continue end
		GAMEMODE.HalloweenHolidayType = tonumber(logic.HolidayType) or 1
		GAMEMODE.HalloweenTauntInHell = tonumber(logic.TauntInHell) or 0
		GAMEMODE.HalloweenAllowHaunting = tonumber(logic.AllowHaunting) or 0
	end
end)

ENT.Type = "point"

local function GetMiniGames()
	local list = {}
	for _, ent in ipairs(ents.GetAll()) do
		if not IsValid(ent) then continue end
		local class = ent:GetClass()
		if class == "tf_base_minigame" or class == "tf_halloween_minigame" or class == "tf_halloween_minigame_falling_platforms" then
			table.insert(list, ent)
		end
	end

	table.sort(list, function(a, b)
		return a:EntIndex() < b:EntIndex()
	end)
	return list
end

local function ApplyGlobals(logic)
	SetGlobalBool("tf_minigames_mode", true)
	SetGlobalInt("tf_active_minigame_entindex", IsValid(logic.ActiveMiniGame) and logic.ActiveMiniGame:EntIndex() or -1)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.ActiveMiniGame = nil
	self.AdvantageTeam = -1
	ApplyGlobals(self)
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:TeleportToMiniGame(index)
	local games = GetMiniGames()
	local minigame = games[index + 1]
	if not IsValid(minigame) then
		return false
	end

	if IsValid(self.ActiveMiniGame) then
		self.ActiveMiniGame:ReturnAllPlayers()
	end

	minigame.AdvantageTeam = self.AdvantageTeam
	minigame:TeleportAllPlayers()
	self.ActiveMiniGame = minigame
	self.AdvantageTeam = -1
	ApplyGlobals(self)
	return true
end

function ENT:ReturnFromMiniGame()
	if IsValid(self.ActiveMiniGame) then
		self.ActiveMiniGame:ReturnAllPlayers()
	end
	self.ActiveMiniGame = nil
	ApplyGlobals(self)
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))

	if name == "teleporttominigame" then
		return self:TeleportToMiniGame(math.max(0, tonumber(data) or 0))
	elseif name == "teleporttorandomminigame" then
		local candidates = {}
		for _, minigame in ipairs(GetMiniGames()) do
			if minigame.AllowedInRandomPool ~= false then
				table.insert(candidates, minigame)
			end
		end

		if #candidates == 0 then
			return false
		end

		if IsValid(self.ActiveMiniGame) and #candidates > 1 then
			for i = #candidates, 1, -1 do
				if candidates[i] == self.ActiveMiniGame then
					table.remove(candidates, i)
				end
			end
		end

		local chosen = candidates[math.random(#candidates)]
		if not IsValid(chosen) then
			return false
		end

		if IsValid(self.ActiveMiniGame) then
			self.ActiveMiniGame:ReturnAllPlayers()
		end

		chosen.AdvantageTeam = self.AdvantageTeam
		chosen:TeleportAllPlayers()
		self.ActiveMiniGame = chosen
		self.AdvantageTeam = -1
		ApplyGlobals(self)
		return true
	elseif name == "setadvantageteam" then
		local teamName = string.lower(tostring(data or ""))
		self.AdvantageTeam = teamName == "red" and TEAM_RED or TEAM_BLU
		return true
	elseif name == "returnfromminigame" then
		self:ReturnFromMiniGame()
		return true
	end

	return false
end

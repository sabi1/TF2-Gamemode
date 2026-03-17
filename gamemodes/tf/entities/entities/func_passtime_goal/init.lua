ENT.Base = "base_brush"
ENT.Type = "brush"

local WIN_ON_SCORE = 1
local DISABLE_BALL_SCORE = 2
local ENABLE_PLAYER_SCORE = 4
local TYPE_TOWER_GOAL = 8

local function rawSpawnFlags(ent)
	return tonumber(ent.SpawnFlags or (ent.Properties or {}).spawnflags) or 0
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = tonumber((self.Properties or {}).startdisabled or 0) == 1
	self.Points = tonumber((self.Properties or {}).points) or 1
	self.TeamNum = self.TeamNum or TEAM_RED
	self.SpawnFlags = tonumber((self.Properties or {}).spawnflags) or 0
	self.TouchingPlayers = {}
	self:NextThink(CurTime())
end

function ENT:KeyValue(key, value)
	if string.Left(key, 2) == "On" then
		self:StoreOutput(key, value)
	end

	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "points" then
		local points = tonumber(value)
		if points == -1 then
			self.Points = -1
		else
			self.Points = math.max(1, points or 1)
		end
	elseif key == "teamnum" then
		local teamNum = tonumber(value)
		if teamNum == 2 then
			self.TeamNum = TEAM_RED
		elseif teamNum == 3 then
			self.TeamNum = TEAM_BLU
		end
	elseif key == "startdisabled" then
		self.Disabled = tonumber(value) == 1
	elseif key == "spawnflags" then
		self.SpawnFlags = tonumber(value) or 0
	end
end

function ENT:GetPoints()
	if tonumber(self.Points) == -1 then
		return -1
	end
	return math.max(1, tonumber(self.Points) or 1)
end

function ENT:HasGoalFlag(flagBit)
	local flags = rawSpawnFlags(self)
	return bit.band(flags, flagBit) ~= 0 or bit.band(flags, flagBit * 16777216) ~= 0
end

function ENT:EnablePlayerScore()
	return self:HasGoalFlag(ENABLE_PLAYER_SCORE)
end

function ENT:DisableBallScore()
	return self:HasGoalFlag(DISABLE_BALL_SCORE)
end

function ENT:WinOnScore()
	return self:HasGoalFlag(WIN_ON_SCORE)
end

function ENT:TriggerScoreOutput(team, activator)
	if team == TEAM_RED then
		self:TriggerOutput("OnScoreRed", activator or self)
	elseif team == TEAM_BLU then
		self:TriggerOutput("OnScoreBlu", activator or self)
	end
end

function ENT:StartTouch(ent)
	if self.Disabled then return end
	if IsValid(ent) and ent:IsPlayer() then
		self.TouchingPlayers[ent] = true
	end
	local logic = nil
	for _, candidate in ipairs(ents.FindByClass("passtime_logic")) do
		if IsValid(candidate) and not candidate.Disabled then
			logic = candidate
			break
		end
	end
	if not IsValid(logic) then return end
	logic:OnEnterGoal(ent, self)
end

function ENT:EndTouch(ent)
	if IsValid(ent) and ent:IsPlayer() then
		self.TouchingPlayers[ent] = nil
	end
end

function ENT:Think()
	if not self.Disabled then
		local logic = nil
		for _, candidate in ipairs(ents.FindByClass("passtime_logic")) do
			if IsValid(candidate) and not candidate.Disabled then
				logic = candidate
				break
			end
		end

		if IsValid(logic) then
			for ply in pairs(self.TouchingPlayers) do
				if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
					logic:OnStayInGoal(ply, self)
				else
					self.TouchingPlayers[ply] = nil
				end
			end
		end
	end

	self:NextThink(CurTime())
	return true
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Disabled = false
		return true
	elseif name == "disable" then
		self.Disabled = true
		return true
	end
	return false
end

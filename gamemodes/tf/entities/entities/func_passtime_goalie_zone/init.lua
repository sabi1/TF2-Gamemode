ENT.Base = "base_brush"
ENT.Type = "brush"

local function convertTeamNum(raw)
	if raw == 2 then return TEAM_RED end
	if raw == 3 then return TEAM_BLU end
	return TEAM_UNASSIGNED
end

local function playerInZones(ply, predicate)
	if not IsValid(ply) then return false end
	for _, zone in ipairs(ents.FindByClass("func_passtime_goalie_zone")) do
		if IsValid(zone) and zone.TouchingPlayers and zone.TouchingPlayers[ply] and predicate(zone, ply) then
			return true
		end
	end
	return false
end

function TF_PasstimePlayerInAnyGoalieZone(ply)
	return playerInZones(ply, function()
		return true
	end)
end

function TF_PasstimePlayerInFriendlyGoalieZone(ply)
	return playerInZones(ply, function(zone, player)
		return zone.TeamNum == player:Team()
	end)
end

function TF_PasstimePlayerInEnemyGoalieZone(ply)
	return playerInZones(ply, function(zone, player)
		return zone.TeamNum ~= TEAM_UNASSIGNED and zone.TeamNum ~= player:Team()
	end)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.TouchingPlayers = {}
	self.TeamNum = convertTeamNum(tonumber((self.Properties or {}).teamnum))
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "teamnum" then
		self.TeamNum = convertTeamNum(tonumber(value))
	end
end

function ENT:StartTouch(ent)
	if IsValid(ent) and ent:IsPlayer() then
		self.TouchingPlayers[ent] = true
	end
end

function ENT:EndTouch(ent)
	self.TouchingPlayers[ent] = nil
end

function ENT:AcceptInput(name, activator, caller, data)
end

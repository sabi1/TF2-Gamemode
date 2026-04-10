if SERVER then
	AddCSLuaFile()
end

-- Define the entity
DEFINE_BASECLASS("base_entity")

ENT.Type = "point"
ENT.Base = "base_entity"
ENT.PrintName = "Game Round Win"
ENT.Category = "TF2"
ENT.Spawnable = false

local WINREASON_DEFEND_UNTIL_TIME_LIMIT = 4

local function to_bool(v, default)
	if v == nil then return default end
	if isbool(v) then return v end
	local s = string.lower(tostring(v))
	if s == "1" or s == "true" or s == "yes" then return true end
	if s == "0" or s == "false" or s == "no" then return false end
	return default
end

function ENT:Initialize()
	self.ForceMapReset = true
	self.SwitchTeamsOnWin = false
	self.WinReason = WINREASON_DEFEND_UNTIL_TIME_LIMIT
end

-- Setup data tables for keyvalues
function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))

	if string.StartWith(key, "on") then
		self:StoreOutput(key, value)
		return
	end

	if key == "teamnum" then
		self.WinningTeam = tonumber(value)
	elseif key == "force_map_reset" then
		self.ForceMapReset = to_bool(value, true)
	elseif key == "switch_teams" then
		self.SwitchTeamsOnWin = to_bool(value, false)
	elseif key == "win_reason" then
		self.WinReason = tonumber(value)
	end
end

-- Trigger win
function ENT:AcceptInput(name, activator, caller, data)
	name = tostring(name or "")
	if name == "RoundWin" then
		self:TriggerRoundWin()
		return true
	elseif name == "SetTeam" then
		self.WinningTeam = tonumber(data) or TEAM_UNASSIGNED
		return true
	end
	return false
end

function ENT:TriggerStalemate()
	if GAMEMODE and GAMEMODE.RoundStalemate then
		GAMEMODE:RoundStalemate(self.ForceMapReset, self.SwitchTeamsOnWin, self)
	else
		if GAMEMODE then
			GAMEMODE.RoundHasWinner = true
			GAMEMODE.WinningTeam = TEAM_UNASSIGNED
		end

		for _, pl in ipairs(player.GetAll()) do
			if IsValid(pl) then
				pl:PrintMessage(HUD_PRINTCENTER, tf_lang and tf_lang.GetRaw and (tf_lang.GetRaw("EnterStalemate") or "Sudden Death Mode!") or "Sudden Death Mode!")
				pl:SendLua([[surface.PlaySound("Game.Stalemate")]])
			end
		end
	end

	self:TriggerOutput("OnRoundWin", self)
end

-- Simulated round win
function ENT:TriggerRoundWin()
	local teamID = self.WinningTeam or TEAM_UNASSIGNED
	if teamID == TEAM_RED or teamID == TEAM_BLU then
		if GM and GM.RoundWin then
			GM:RoundWin(teamID, self.WinReason, self.ForceMapReset, self.SwitchTeamsOnWin, self)
		end
		self:TriggerOutput("OnRoundWin", self)
	else
		self:TriggerStalemate()
	end
end

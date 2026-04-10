AddCSLuaFile()

ENT.Type = "anim"

local OBS_ALLOW_TEAM = 1
local FIRST_GAME_TEAM = TEAM_RED

local function to_bool(v, default)
	if v == nil then return default end
	if isbool(v) then return v end
	local s = string.lower(tostring(v))
	if s == "1" or s == "true" or s == "yes" then return true end
	if s == "0" or s == "false" or s == "no" then return false end
	return default
end

local function resolve_ent_by_name(name)
	if not isstring(name) or name == "" then
		return NULL
	end

	local found = ents.FindByName(name)
	if not found or #found == 0 then
		return NULL
	end

	return found[1]
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self:SetModel("models/editor/camera.mdl")
	self:SetNoDraw(true)
	self.Disabled = to_bool(self.Properties.startdisabled, false)
	self.DefaultWelcome = to_bool(self.Properties.defaultwelcome, false)
	self.MatchSummary = to_bool(self.Properties.match_summary, false)
	self.ObserverFOV = tonumber(self.Properties.fov) or 0
	self.AssociatedTeamEntityName = tostring(self.Properties.associated_team_entity or "")
	self.AssociatedTeamEntity = NULL
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:Activate()
	self.Disabled = to_bool(self.Properties.startdisabled, self.Disabled)
	self.DefaultWelcome = to_bool(self.Properties.defaultwelcome, self.DefaultWelcome)
	self.MatchSummary = to_bool(self.Properties.match_summary, self.MatchSummary)
	self.ObserverFOV = tonumber(self.Properties.fov) or self.ObserverFOV or 0
	self.AssociatedTeamEntityName = tostring(self.Properties.associated_team_entity or self.AssociatedTeamEntityName or "")
	self.AssociatedTeamEntity = resolve_ent_by_name(self.AssociatedTeamEntityName)
	if self.MatchSummary then
		self.Disabled = true
	end
end

function ENT:IsDefaultWelcome()
	return self.DefaultWelcome and true or false
end

function ENT:IsMatchSummary()
	return self.MatchSummary and true or false
end

function ENT:GetObserverFOV()
	return tonumber(self.ObserverFOV) or 0
end

function ENT:CanUseObserverPoint(ply)
	if self.Disabled then
		return false
	end

	if not (IsValid(ply) and ply:IsPlayer()) then
		return false
	end

	local associated = IsValid(self.AssociatedTeamEntity) and self.AssociatedTeamEntity or resolve_ent_by_name(self.AssociatedTeamEntityName)
	if IsValid(associated) then
		self.AssociatedTeamEntity = associated
		local forceCam = GetConVar("mp_forcecamera")
		if forceCam and forceCam:GetInt() == OBS_ALLOW_TEAM then
			local playerTeam = tonumber(ply:Team()) or TEAM_UNASSIGNED
			local ownerTeam = tonumber(associated:Team()) or TEAM_UNASSIGNED
			if playerTeam >= FIRST_GAME_TEAM and ownerTeam ~= playerTeam then
				return false
			end
		end
	end

	return true
end

function ENT:Input_Enable()
	self.Disabled = false
end

function ENT:Input_Disable()
	self.Disabled = true
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input_" .. tostring(name or "")]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
	return false
end

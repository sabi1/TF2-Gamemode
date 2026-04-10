include("shared.lua")

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.AutomaticFrameAdvance = true

local function IsBlueSideTeam(teamNum)
	return teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS
end

local function IsFriendlyTeam(playerTeam, visualizerTeam)
	if visualizerTeam == TEAM_RED then
		return playerTeam == TEAM_RED
	end
	if visualizerTeam == TEAM_BLU then
		return IsBlueSideTeam(playerTeam)
	end
	return false
end

local function ParseHammerTeamNum(value)
	local t = tonumber(value)
	if t == 2 then return TEAM_RED end
	if t == 3 then return TEAM_BLU end
	return TEAM_UNASSIGNED or 0
end

local function GetVisualizerTeamNum(ent)
	local room = ent.GetNWEntity and ent:GetNWEntity("RespawnRoom")
	if IsValid(room) then
		local roomTeam = room.GetNWInt and room:GetNWInt("TeamNum", TEAM_UNASSIGNED or 0) or (TEAM_UNASSIGNED or 0)
		if roomTeam ~= (TEAM_UNASSIGNED or 0) then
			return roomTeam
		end
	end

	local teamNum = ent.GetNWInt and ent:GetNWInt("TeamNum", TEAM_UNASSIGNED or 0) or (TEAM_UNASSIGNED or 0)
	if teamNum ~= (TEAM_UNASSIGNED or 0) then
		return teamNum
	end

	local rawTeam = ent.GetNWInt and ent:GetNWInt("Team", 0) or 0
	local parsedRawTeam = ParseHammerTeamNum(rawTeam)
	if parsedRawTeam ~= (TEAM_UNASSIGNED or 0) then
		return parsedRawTeam
	end

	if ent.TeamNum and ent.TeamNum ~= (TEAM_UNASSIGNED or 0) then
		return ent.TeamNum
	end

	local roomName = ent.GetNWString and string.lower(ent:GetNWString("RespawnRoomName", "")) or ""
	if roomName ~= "" then
		if string.find(roomName, "blu", 1, true) then
			return TEAM_BLU
		end
		if string.find(roomName, "red", 1, true) then
			return TEAM_RED
		end
	end

	return ent.Team and ent:Team() or (TEAM_UNASSIGNED or 0)
end

local function InWinningRoundState()
	return GAMEMODE and GAMEMODE.RoundHasWinner
end

local function GetVisualizerAlpha(ent)
	local teamNum = GetVisualizerTeamNum(ent)
	local localPlayer = LocalPlayer()
	if IsValid(localPlayer) and IsFriendlyTeam(localPlayer:Team(), teamNum) then
		return 0
	end

	return 255
end

local function DrawVisualizer(ent)
	if InWinningRoundState() then
		ent:SetNoDraw(true)
		return
	end

	local alpha = GetVisualizerAlpha(ent)
	if alpha <= 0 then
		ent:SetNoDraw(true)
		return
	end

	ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
	ent:SetColor(Color(255, 255, 255, alpha))
	ent:SetNoDraw(false)
	ent:DrawModel()
end

function ENT:Draw()
	DrawVisualizer(self)
end

function ENT:DrawTranslucent()
	DrawVisualizer(self)
end

function ENT:Initialize()
	self:SetRenderMode(RENDERMODE_TRANSCOLOR)
	self:SetColor(Color(255, 255, 255, 255))
end

function ENT:Think()
	local hide = InWinningRoundState() or GetVisualizerAlpha(self) <= 0
	self:SetNoDraw(hide)
	self:SetNextClientThink(CurTime())
	return true
end

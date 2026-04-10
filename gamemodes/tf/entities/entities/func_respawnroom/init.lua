ENT.Base = "base_brush"
ENT.Type = "brush"

local RESPAWNROOM_TOUCH_RECHECK = 0.25

local function ParseHammerTeamNum(value)
	local t = tonumber(value)
	if t == 2 then return TEAM_RED end
	if t == 3 then return TEAM_BLU end
	return TEAM_UNASSIGNED or 0
end

local function RawHammerTeamFromInternal(teamNum)
	if teamNum == TEAM_RED then return 2 end
	if teamNum == TEAM_BLU then return 3 end
	return 0
end

local function IsPointInsideBrush(self, pos)
	local mins, maxs = self:WorldSpaceAABB()
	return pos.x >= mins.x and pos.x <= maxs.x
		and pos.y >= mins.y and pos.y <= maxs.y
		and pos.z >= mins.z and pos.z <= maxs.z
end

local function IsEntityInsideBrush(self, ent)
	if not IsValid(ent) then return false end
	local pos = ent.WorldSpaceCenter and ent:WorldSpaceCenter() or ent:GetPos()
	return IsPointInsideBrush(self, pos)
end

local function SetPlayerRespawnTouchCount(ply, count)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	count = math.max(0, tonumber(count) or 0)
	ply._tfRespawnRoomTouchCount = count

	local inside = count > 0
	ply:SetNWBool("InRespawnRoom", inside)

	if inside then
		ply:GodEnable()
	else
		ply:GodDisable()
	end
end

local function AdjustPlayerRespawnTouchCount(ply, delta)
	SetPlayerRespawnTouchCount(ply, (ply._tfRespawnRoomTouchCount or 0) + delta)
end

local function FindSpawnTeamInsideRoom(self)
	for _, spawn in ipairs(ents.FindByClass("info_player_teamspawn")) do
		if not IsValid(spawn) then continue end
		if spawn.IsDisabled and spawn:IsDisabled() then continue end
		if not IsPointInsideBrush(self, spawn:GetPos()) then continue end

		local teamNum = nil
		if spawn.GetSpawnTeamNum then
			teamNum = spawn:GetSpawnTeamNum()
		else
			teamNum = tonumber(spawn.TeamNum or (spawn.GetNWInt and spawn:GetNWInt("TeamNum", -1)) or -1) or -1
		end

		if teamNum == TEAM_RED or teamNum == TEAM_BLU then
			return teamNum
		end
	end
end

local function RefreshRoomStateFromKeyValues(self)
	local kv = self.GetKeyValues and self:GetKeyValues() or {}
	local rawTeam = kv.TeamNum or kv.teamnum or kv.Team or kv.team
	if rawTeam ~= nil then
		self.TeamNum = ParseHammerTeamNum(rawTeam)
		self.Team = tonumber(rawTeam) or RawHammerTeamFromInternal(self.TeamNum)
		self.OriginalTeamNum = self.TeamNum
		self:SetNWInt("TeamNum", self.TeamNum)
		self:SetNWInt("Team", self.Team)
	end

	local rawDisabled = kv.StartDisabled or kv.startdisabled
	if rawDisabled ~= nil then
		self.Active = tonumber(rawDisabled) ~= 1
	end
end

local function PruneTrackedPlayers(self)
	self.TouchingPlayers = self.TouchingPlayers or {}

	for ply in pairs(self.TouchingPlayers) do
		if (not IsValid(ply))
			or (not self:GetActive())
			or (not IsEntityInsideBrush(self, ply)) then
			self.TouchingPlayers[ply] = nil
			AdjustPlayerRespawnTouchCount(ply, -1)
		end
	end
end

function ENT:Initialize()
	local mins, maxs = self:WorldSpaceAABB()

	self.Pos = (mins + maxs) * 0.5
	self.TeamNum = self.TeamNum or TEAM_UNASSIGNED or 0
	self.Team = self.Team or RawHammerTeamFromInternal(self.TeamNum)
	self.OriginalTeamNum = self.TeamNum
	self.Active = true
	self.TouchingPlayers = self.TouchingPlayers or {}
	self.Visualizers = self.Visualizers or {}

	self:SetNWInt("TeamNum", self.TeamNum)
	self:SetNWInt("Team", self.Team)

	RefreshRoomStateFromKeyValues(self)
end

function ENT:KeyValue(key, value)
	key = string.lower(key)

	if key == "teamnum" then
		self.TeamNum = ParseHammerTeamNum(value)
		self.Team = tonumber(value) or RawHammerTeamFromInternal(self.TeamNum)
		self.OriginalTeamNum = self.TeamNum
		self:SetNWInt("TeamNum", self.TeamNum)
		self:SetNWInt("Team", self.Team)
	elseif key == "startdisabled" then
		self.Active = tonumber(value) ~= 1
	end
end

function ENT:Activate()
	RefreshRoomStateFromKeyValues(self)
end

function ENT:AddVisualizer(viz)
	if not IsValid(viz) then return end

	self.Visualizers = self.Visualizers or {}
	for _, existing in ipairs(self.Visualizers) do
		if existing == viz then
			return
		end
	end

	table.insert(self.Visualizers, viz)
end

function ENT:ChangeTeam(teamNum)
	self.TeamNum = teamNum or TEAM_UNASSIGNED or 0
	self.Team = RawHammerTeamFromInternal(self.TeamNum)
	if self.SetTeam then
		self:SetTeam(self.TeamNum)
	end
	self:SetNWInt("TeamNum", self.TeamNum)
	self:SetNWInt("Team", self.Team)

	for i = #self.Visualizers, 1, -1 do
		local viz = self.Visualizers[i]
		if not IsValid(viz) then
			table.remove(self.Visualizers, i)
		elseif viz.ChangeTeam then
			viz:ChangeTeam(self.TeamNum)
		end
	end
end

function ENT:SetActive(active)
	self.Active = active ~= false

	if not self.Active then
		PruneTrackedPlayers(self)
	end

	for i = #self.Visualizers, 1, -1 do
		local viz = self.Visualizers[i]
		if not IsValid(viz) then
			table.remove(self.Visualizers, i)
		elseif viz.SetActive then
			viz:SetActive(self.Active)
		end
	end
end

function ENT:GetActive()
	return self.Active ~= false
end

function ENT:InputSetActive()
	self:SetActive(true)
end

function ENT:InputEnable()
	self:SetActive(true)
end

function ENT:InputSetInactive()
	self:SetActive(false)
end

function ENT:InputDisable()
	self:SetActive(false)
end

function ENT:InputToggleActive()
	self:SetActive(not self:GetActive())
end

function ENT:InputToggle()
	self:SetActive(not self:GetActive())
end

function ENT:InputSetTeam(_, _, _, value)
	local raw = tonumber(value)
	if raw == nil then return end

	if raw == 2 or raw == 3 then
		self:ChangeTeam(ParseHammerTeamNum(raw))
	else
		self:ChangeTeam(raw)
	end
end

function ENT:InputRoundActivate()
	local unassigned = TEAM_UNASSIGNED or 0
	if self.OriginalTeamNum ~= unassigned then return end

	self:ChangeTeam(unassigned)

	local foundTeam = FindSpawnTeamInsideRoom(self)
	if foundTeam then
		self:ChangeTeam(foundTeam)
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input" .. tostring(name or "")] or self["Input_" .. tostring(name or "")]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
end

function ENT:RespawnRoomTouch(ent)
	if not self:GetActive() then return end
	if not IsValid(ent) or not ent:IsPlayer() then return end
	if self.TeamNum ~= (TEAM_UNASSIGNED or 0) and ent.IsFriendly and not ent:IsFriendly(self) then return end

	if ent.HasTheFlag and ent.DropFlag and ent:HasTheFlag() then
		ent:DropFlag()
	end

	if ent.DropRune then
		ent:DropRune(false)
	end
end

function ENT:StartTouch(ent)
	if not self:GetActive() then return end
	if not IsValid(ent) or not ent:IsPlayer() then return end
	self.TouchingPlayers = self.TouchingPlayers or {}
	if self.TouchingPlayers[ent] then return end

	self.TouchingPlayers[ent] = true
	AdjustPlayerRespawnTouchCount(ent, 1)
	self:RespawnRoomTouch(ent)
end

function ENT:Touch(ent)
	self:RespawnRoomTouch(ent)
end

function ENT:EndTouch(ent)
	if not IsValid(ent) or not ent:IsPlayer() then return end
	self.TouchingPlayers = self.TouchingPlayers or {}
	if not self.TouchingPlayers[ent] then return end

	self.TouchingPlayers[ent] = nil
	AdjustPlayerRespawnTouchCount(ent, -1)
end

function ENT:Think()
	PruneTrackedPlayers(self)

	if self:GetActive() then
		for _, ply in ipairs(player.GetAll()) do
			if IsValid(ply) and not self.TouchingPlayers[ply] and IsEntityInsideBrush(self, ply) then
				self:StartTouch(ply)
			end
		end
	end

	self:NextThink(CurTime() + RESPAWNROOM_TOUCH_RECHECK)
	return true
end

function ENT:OnRemove()
	self.TouchingPlayers = self.TouchingPlayers or {}

	for ply in pairs(self.TouchingPlayers) do
		if IsValid(ply) then
			AdjustPlayerRespawnTouchCount(ply, -1)
		end
	end
end

function PointInRespawnRoom(target, origin, sameTeamOnly)
	for _, room in ipairs(ents.FindByClass("func_respawnroom")) do
		if not IsValid(room) or not room.GetActive or not room:GetActive() then continue end

		if IsPointInsideBrush(room, origin) then
			if not target or room.TeamNum == (TEAM_UNASSIGNED or 0) then
				return true
			end
			if not sameTeamOnly or (target.IsFriendly and target:IsFriendly(room)) then
				return true
			end
		elseif target and IsPointInsideBrush(room, target:GetPos()) then
			room.TouchingPlayers = room.TouchingPlayers or {}
			if target and room.TouchingPlayers[target] then
				if not sameTeamOnly or room.TeamNum == (TEAM_UNASSIGNED or 0) or (target.IsFriendly and target:IsFriendly(room)) then
					return true
				end
			end
		end
	end

	return false
end

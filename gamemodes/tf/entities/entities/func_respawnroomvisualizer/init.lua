ENT.Base = "base_brush"
ENT.Type = "brush"

local function IsBlueSideTeam(teamNum)
	return teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS
end

local function IsAllowedInVisualizer(playerTeam, visualizerTeam)
	if visualizerTeam == TEAM_RED then
		return playerTeam == TEAM_RED
	end
	if visualizerTeam == TEAM_BLU then
		return IsBlueSideTeam(playerTeam)
	end
	-- Unknown team mapping should never hard-block movement.
	return true
end

local function ParseHammerTeamNum(value)
	local t = tonumber(value)
	if t == 2 then return TEAM_RED end
	if t == 3 then return TEAM_BLU end
	return nil
end

local function IsPlayableVisualizerTeam(teamNum)
	return teamNum == TEAM_RED or teamNum == TEAM_BLU
end

local function IsEnemyVisualizerTouch(ent, visualizerTeam)
	return IsValid(ent) and ent:IsPlayer() and not IsAllowedInVisualizer(ent:Team(), visualizerTeam)
end

local function RawHammerTeamFromInternal(teamNum)
	if teamNum == TEAM_RED then return 2 end
	if teamNum == TEAM_BLU then return 3 end
	return 0
end

local function IsMvMMap()
	local map = string.lower(game.GetMap() or "")
	return string.find(map, "mvm_", 1, true) ~= nil
end

local function ShouldApplyMvMVisualizerInvuln(ent, visualizerTeam)
	if not IsValid(ent) or not ent:IsPlayer() then return false end
	if not IsMvMMap() then return false end
	if not ent:IsBot() then return false end
	if not IsBlueSideTeam(ent:Team()) then return false end
	return IsAllowedInVisualizer(ent:Team(), visualizerTeam)
end

local function IsEntityInsideVisualizer(self, ent)
	if not IsValid(self) or not IsValid(ent) then return false end
	local mins, maxs = self:WorldSpaceAABB()
	local pos = ent:WorldSpaceCenter()
	return pos.x >= mins.x and pos.y >= mins.y and pos.z >= mins.z
		and pos.x <= maxs.x and pos.y <= maxs.y and pos.z <= maxs.z
end

local function RefreshVisualizerTeamBinding(self)
	if not IsValid(self) then return end

	if IsValid(self.RespawnRoom) and IsPlayableVisualizerTeam(self.RespawnRoom.TeamNum) then
		self.TeamNum = self.RespawnRoom.TeamNum
		self.Team = RawHammerTeamFromInternal(self.TeamNum)
		self:SetNWInt("TeamNum", self.TeamNum)
		self:SetNWInt("Team", self.Team)
		return
	end

	if not self.RespawnRoomName or self.RespawnRoomName == "" then return end

	for _, ent in ipairs(ents.FindByName(self.RespawnRoomName)) do
		if IsValid(ent) and ent:GetClass() == "func_respawnroom" and IsPlayableVisualizerTeam(ent.TeamNum) then
			self.RespawnRoom = ent
			self.TeamNum = ent.TeamNum
			self.Team = RawHammerTeamFromInternal(self.TeamNum)
			self:SetNWInt("TeamNum", self.TeamNum)
			self:SetNWInt("Team", self.Team)
			return
		end
	end
end

local function AddVisualizerInvuln(ent)
	if not IsValid(ent) or not ent.AddCond then return end
	if not TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED then return end

	ent._tfRespawnVisualizerCondRefs = (ent._tfRespawnVisualizerCondRefs or 0) + 1
	if ent._tfRespawnVisualizerCondRefs == 1 and not ent:InCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED) then
		ent:AddCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED, PERMANENT_CONDITION or -1, ent)
	end
end

local function RemoveVisualizerInvuln(ent)
	if not IsValid(ent) or not ent.RemoveCond then return end
	if not TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED then return end

	local refs = math.max(0, (ent._tfRespawnVisualizerCondRefs or 0) - 1)
	ent._tfRespawnVisualizerCondRefs = refs
	if refs == 0 and ent:InCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED) then
		ent:RemoveCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED, true)
	end
end

local function TrackTouch(self, ent)
	if not ShouldApplyMvMVisualizerInvuln(ent, self.TeamNum) then return end
	if self.Players[ent] then return end

	self.Players[ent] = true
	AddVisualizerInvuln(ent)
end

local function UntrackTouch(self, ent)
	if not self.Players[ent] then return end
	self.Players[ent] = nil
	RemoveVisualizerInvuln(ent)
end

local function SetVisualizerSolidState(self, shouldBeSolid)
	if not IsValid(self) then return end

	if self.SetTrigger then
		self:SetTrigger(not shouldBeSolid)
	end

	if self.AddSolidFlags and self.RemoveSolidFlags and FSOLID_TRIGGER and FSOLID_NOT_SOLID then
		if shouldBeSolid then
			self:RemoveSolidFlags(FSOLID_TRIGGER)
			self:RemoveSolidFlags(FSOLID_NOT_SOLID)
		else
			self:AddSolidFlags(FSOLID_TRIGGER)
			self:AddSolidFlags(FSOLID_NOT_SOLID)
		end
	end
end

local function NotifyBlockedPlayer(ent)
	if not IsValid(ent) or not ent:IsPlayer() then return end

	local now = CurTime()
	if (ent._tfNextRespawnRoomBlockNotice or 0) > now then return end

	ent._tfNextRespawnRoomBlockNotice = now + 1
	ent:PrintMessage(HUD_PRINTCENTER, "You are not allowed to enter enemy spawnrooms.")
end


function ENT:Initialize()
	local pos = self:GetPos()
	local mins, maxs = self:WorldSpaceAABB() -- https://forum.facepunch.com/gmoddev/lmcw/Brush-entitys-ent-GetPos/1/#postdwfmq
	pos = (mins + maxs) * 0.5

	self.Team = self.Team or 0		
	self.TeamNum = self.TeamNum or 0
	self.Pos = pos 
	self.Players = {}
	self:SetNWInt("TeamNum", self.TeamNum)
	self:SetNWInt("Team", self.Team)
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionGroup(COLLISION_GROUP_WORLD)
	self:SetCustomCollisionCheck( true ) 
	SetVisualizerSolidState(self, true)
end 

function ENT:KeyValue(key,value)
	key = string.lower(key)
	if key =="respawnroomname" then
		self.RespawnRoomName = tostring(value)
		RefreshVisualizerTeamBinding(self)
	elseif key == "teamnum" then
		local parsed = ParseHammerTeamNum(value)
		if parsed then
			self.TeamNum = parsed
			self.Team = tonumber(value) or RawHammerTeamFromInternal(parsed)
			self:SetNWInt("TeamNum", self.TeamNum)
			self:SetNWInt("Team", self.Team)
		end
	elseif key == "solid_to_enemies" then
		local enabled = tobool(value)
		self.SolidToEnemies = enabled
		SetVisualizerSolidState(self, enabled ~= false)
	end
	--print(key, value, tostring(value), self.RespawnRoom)
end

function ENT:StartTouch(ent)
	TrackTouch(self, ent)
	if IsEnemyVisualizerTouch(ent, self.TeamNum) then
		NotifyBlockedPlayer(ent)
	end
end

function ENT:Touch(ent)
	TrackTouch(self, ent)
	if IsEnemyVisualizerTouch(ent, self.TeamNum) then
		NotifyBlockedPlayer(ent)
	end
end

function ENT:EndTouch(ent)
	UntrackTouch(self, ent)
end

function ENT:OnRemove()
	for ply, _ in pairs(self.Players or {}) do
		UntrackTouch(self, ply)
	end
end

function ENT:Think()
	RefreshVisualizerTeamBinding(self)

	if IsMvMMap() then
		-- Prune stale tracked players (death/teleport/respawn or brush transitions missing EndTouch).
		for ply, _ in pairs(self.Players or {}) do
			if (not IsValid(ply))
				or (not ShouldApplyMvMVisualizerInvuln(ply, self.TeamNum))
				or (not IsEntityInsideVisualizer(self, ply)) then
				UntrackTouch(self, ply)
			end
		end

		-- Catch players that spawn inside or skip StartTouch events.
		for _, ply in ipairs(player.GetBots()) do
			if ShouldApplyMvMVisualizerInvuln(ply, self.TeamNum) and IsEntityInsideVisualizer(self, ply) then
				TrackTouch(self, ply)
			end
		end
	end

	self:NextThink(CurTime() + 0.2)
	return true
end
 
hook.Add( "ShouldCollide", "RespawnRoomVisualizerCollision", function( ent1, ent2 )

    -- If players are about to collide with each other, then they won't collide.
    if ( ent1:GetClass() == "func_respawnroomvisualizer" and ent2:IsPlayer() ) then 
		RefreshVisualizerTeamBinding(ent1)
		if ent1.SolidToEnemies == false then return false end
		return not IsAllowedInVisualizer(ent2:Team(), ent1.TeamNum)
    elseif ( ent2:GetClass() == "func_respawnroomvisualizer" and ent1:IsPlayer() ) then 
		RefreshVisualizerTeamBinding(ent2)
		if ent2.SolidToEnemies == false then return false end
		return not IsAllowedInVisualizer(ent1:Team(), ent2.TeamNum)
	end

end )

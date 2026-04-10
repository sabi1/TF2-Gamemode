ENT.Type = "point"

local TRAIN_STATE_STOPPED = 0
local TRAIN_STATE_FORWARD = 1
local TRAIN_STATE_BLOCKED = 2
local TRAIN_STATE_RECEDING = 3

local DEFAULT_RECEDE_TIME = 30
local MAX_LINKED_POINTS = 8
local PROGRESS_OUTPUT_THRESHOLDS = {
	0.25,
	0.50,
	0.75,
	1.00,
}

local function ToBool(value, default)
	if value == nil then return default end
	if isbool(value) then return value end
	if isnumber(value) then return value ~= 0 end
	if isstring(value) then
		value = string.Trim(string.lower(value))
		if value == "1" or value == "true" or value == "yes" then return true end
		if value == "0" or value == "false" or value == "no" then return false end
	end
	return default
end

local function ResolveEntByName(name)
	if not isstring(name) or name == "" then
		return NULL
	end

	local list = ents.FindByName(name)
	if not list or #list == 0 then
		return NULL
	end

	return list[1]
end

local function DistPointToSegment(point, a, b)
	local ab = b - a
	local lenSqr = ab:LengthSqr()
	if lenSqr <= 0 then
		return point:Distance(a), 0
	end

	local t = math.Clamp((point - a):Dot(ab) / lenSqr, 0, 1)
	local proj = a + ab * t
	return point:Distance(proj), t
end

local function EnsurePayloadRegistry()
	if not GAMEMODE then return end
	GAMEMODE.PayloadWatchers = GAMEMODE.PayloadWatchers or {}
end

local function WritePayloadSnapshot(snapshot)
	net.WriteUInt(math.Clamp(tonumber(snapshot.watcher) or 0, 0, 65535), 16)
	net.WriteBool(snapshot.active and true or false)
	net.WriteInt(tonumber(snapshot.attackTeam) or TEAM_BLU, 8)
	net.WriteInt(tonumber(snapshot.cappers) or 0, 8)
	net.WriteBool(snapshot.blocked and true or false)
	net.WriteFloat(math.Clamp(tonumber(snapshot.progress) or 0, 0, 1))

	local checkpoints = snapshot.checkpointProgress or {}
	local count = math.min(#checkpoints, MAX_LINKED_POINTS)
	net.WriteUInt(count, 4)
	for i = 1, count do
		net.WriteFloat(math.Clamp(tonumber(checkpoints[i]) or 0, 0, 1))
	end

	net.WriteFloat(math.max(tonumber(snapshot.recedeRemaining) or 0, 0))
	net.WriteBool(snapshot.canRecede and true or false)
	net.WriteUInt(math.Clamp(tonumber(snapshot.trainState) or TRAIN_STATE_STOPPED, 0, 7), 3)
	net.WriteBool(snapshot.inOvertime and true or false)
	net.WriteBool(snapshot.goal and true or false)
end

local function SortPayloadSnapshots(a, b)
	local aAttack = tonumber(a.attackTeam) or TEAM_BLU
	local bAttack = tonumber(b.attackTeam) or TEAM_BLU
	if aAttack ~= bAttack then
		if aAttack == TEAM_BLU then return true end
		if bAttack == TEAM_BLU then return false end
		return aAttack < bAttack
	end

	local aActive = a.active and 1 or 0
	local bActive = b.active and 1 or 0
	if aActive ~= bActive then
		return aActive > bActive
	end

	local aGoal = a.goal and 1 or 0
	local bGoal = b.goal and 1 or 0
	if aGoal ~= bGoal then
		return aGoal < bGoal
	end

	local aProgress = tonumber(a.progress) or 0
	local bProgress = tonumber(b.progress) or 0
	if aProgress ~= bProgress then
		return aProgress > bProgress
	end

	return (tonumber(a.watcher) or 0) < (tonumber(b.watcher) or 0)
end

local function GetGameModeTable()
	if GAMEMODE then return GAMEMODE end
	if GM then return GM end
	return nil
end

local function GM_RegisterPayloadWatcher(self, watcher)
	if not IsValid(watcher) then return end
	EnsurePayloadRegistry()
	self.PayloadWatchers[watcher] = true
	self:RecomputeActivePayloadWatcher()
end

local function GM_UnregisterPayloadWatcher(self, watcher)
	if not self.PayloadWatchers then return end
	self.PayloadWatchers[watcher] = nil
	if self.ActivePayloadWatcher == watcher then
		self.ActivePayloadWatcher = nil
	end
	self:RecomputeActivePayloadWatcher()
end

local function GM_RecomputeActivePayloadWatcher(self)
	if not self.PayloadWatchers then
		self.ActivePayloadWatcher = nil
		return nil
	end

	local bestWatcher = nil
	local bestProgress = -1

	for watcher in pairs(self.PayloadWatchers) do
		if not IsValid(watcher) then
			self.PayloadWatchers[watcher] = nil
		else
			local state = watcher:GetPayloadState()
			if state and state.active then
				local progress = tonumber(state.progress) or 0
				if progress > bestProgress then
					bestProgress = progress
					bestWatcher = watcher
				end
			end
		end
	end

	self.ActivePayloadWatcher = bestWatcher
	return bestWatcher
end

local function GM_GetActivePayloadWatcher(self)
	if not IsValid(self.ActivePayloadWatcher) then
		return self:RecomputeActivePayloadWatcher()
	end
	return self.ActivePayloadWatcher
end

local function GM_BuildPayloadSnapshot(self, watcher)
	local defaultState = {
		watcher = 0,
		active = false,
		attackTeam = TEAM_BLU,
		cappers = 0,
		blocked = false,
		progress = 0,
		checkpointProgress = {},
		recedeRemaining = 0,
		canRecede = true,
		trainState = TRAIN_STATE_STOPPED,
		inOvertime = false,
		goal = false,
	}

	if not IsValid(watcher) then
		return defaultState
	end

	local state = watcher:GetPayloadState() or {}
	defaultState.watcher = watcher:EntIndex()
	defaultState.active = state.active and true or false
	defaultState.attackTeam = tonumber(state.attackTeam) or TEAM_BLU
	defaultState.cappers = tonumber(state.cappers) or 0
	defaultState.blocked = state.blocked and true or false
	defaultState.progress = math.Clamp(tonumber(state.progress) or 0, 0, 1)
	defaultState.checkpointProgress = table.Copy(state.checkpointProgress or {})
	defaultState.recedeRemaining = math.max(tonumber(state.recedeRemaining) or 0, 0)
	defaultState.canRecede = state.canRecede and true or false
	defaultState.trainState = tonumber(state.trainState) or TRAIN_STATE_STOPPED
	defaultState.inOvertime = state.inOvertime and true or false
	defaultState.goal = state.goalReached and true or false

	return defaultState
end

local function GM_BuildPayloadSnapshots(self)
	local snapshots = {}

	if not self.PayloadWatchers then
		return snapshots
	end

	for watcher in pairs(self.PayloadWatchers) do
		if not IsValid(watcher) then
			self.PayloadWatchers[watcher] = nil
		else
			table.insert(snapshots, self:BuildPayloadSnapshot(watcher))
		end
	end

	table.sort(snapshots, SortPayloadSnapshots)
	return snapshots
end

local function GM_SyncPayloadState(self, forceFull, target)
	local snapshots = self:BuildPayloadSnapshots()

	net.Start(forceFull and "TF_PayloadSyncFull" or "TF_PayloadSyncDelta")
	net.WriteUInt(math.min(#snapshots, 15), 4)
	for i = 1, math.min(#snapshots, 15) do
		WritePayloadSnapshot(snapshots[i])
	end

	if target then
		net.Send(target)
	else
		net.Broadcast()
	end
end

local function InstallPayloadGMMethods()
	local gm = GetGameModeTable()
	if not gm then return end

	gm.RegisterPayloadWatcher = GM_RegisterPayloadWatcher
	gm.UnregisterPayloadWatcher = GM_UnregisterPayloadWatcher
	gm.RecomputeActivePayloadWatcher = GM_RecomputeActivePayloadWatcher
	gm.GetActivePayloadWatcher = GM_GetActivePayloadWatcher
	gm.BuildPayloadSnapshot = GM_BuildPayloadSnapshot
	gm.BuildPayloadSnapshots = GM_BuildPayloadSnapshots
	gm.SyncPayloadState = GM_SyncPayloadState
end

InstallPayloadGMMethods()
hook.Add("Initialize", "TFPayloadInstallMethods", InstallPayloadGMMethods)

hook.Add("PlayerInitialSpawn", "TFPayloadInitialSync", function(ply)
	InstallPayloadGMMethods()

	timer.Simple(1, function()
		if not IsValid(ply) then return end
		if GAMEMODE and GAMEMODE.SyncPayloadState then
			GAMEMODE:SyncPayloadState(true, ply)
		end
	end)
end)

function ENT:Initialize()
	InstallPayloadGMMethods()

	self.Properties = self.Properties or {}
	self.LinkedPathTracks = {}
	self.LinkedCPs = {}
	self.PathNodes = {}
	self.PathDistances = {}
	self.PathTotalDistance = 0
	self.CheckpointData = {}
	self.CheckpointReached = {}
	self.ProgressOutputFired = {}
	self.PathDistanceProgress = 0
	self.StateDirty = true
	self.LastCapperUpdate = 0
	self.LastProgressSync = 0
	self.NextTrainCommand = 0
	self.PendingFallbackWin = false
	self.PostEntityDone = false

	self.PayloadState = {
		active = false,
		attackTeam = TEAM_BLU,
		defendTeam = TEAM_RED,
		cappers = 0,
		blocked = false,
		trainState = TRAIN_STATE_STOPPED,
		progress = 0,
		checkpointProgress = {},
		canRecede = true,
		recedeDelay = DEFAULT_RECEDE_TIME,
		recedeRemaining = 0,
		inOvertime = false,
		goalReached = false,
	}

	EnsurePayloadRegistry()
	if GAMEMODE and GAMEMODE.RegisterPayloadWatcher then
		GAMEMODE:RegisterPayloadWatcher(self)
	end
end

function ENT:GetPayloadState()
	return self.PayloadState
end

function ENT:IsPayloadObjectiveActive()
	local state = self.PayloadState
	if not state then return false end
	return state.active and not state.goalReached
end

function ENT:IsPayloadContested()
	local state = self.PayloadState
	if not state then return false end
	return (tonumber(state.cappers) or 0) > 0 or (state.blocked and true or false)
end

function ENT:GetCartPosition()
	if IsValid(self.Train) then
		return self.Train:GetPos()
	end
	return self:GetPos()
end

function ENT:GetDefendPosition()
	local curDist = self.PathDistanceProgress or 0
	for _, checkpoint in ipairs(self.CheckpointData) do
		if checkpoint.distance > curDist + 32 then
			local ent = checkpoint.cp
			if not IsValid(ent) then
				ent = checkpoint.pathtrack
			end
			if IsValid(ent) then
				return ent:GetPos()
			end
		end
	end

	if IsValid(self.Goal) then
		return self.Goal:GetPos()
	end
	if IsValid(self.Train) then
		return self.Train:GetPos()
	end
	return self:GetPos()
end

function ENT:KeyValue(key, value)
	if string.Left(key, 2) == "On" then
		self:StoreOutput(key, value)
	end

	key = string.lower(key)
	if tonumber(value) then value = tonumber(value) end

	self.Properties = self.Properties or {}
	self.Properties[key] = value
end

function ENT:BuildCheckpointData()
	self.CheckpointData = {}
	self.CheckpointReached = {}

	if self.PathTotalDistance <= 0 then
		self.PayloadState.checkpointProgress = {}
		return
	end

	for i = 1, MAX_LINKED_POINTS do
		local pathtrack = self.LinkedPathTracks[i]
		local cp = self.LinkedCPs[i]
		local source = pathtrack
		if not IsValid(source) then
			source = cp
		end

		if IsValid(source) then
			local dist, frac = self:DistanceAlongPath(source:GetPos())
			table.insert(self.CheckpointData, {
				index = i,
				pathtrack = pathtrack,
				cp = cp,
				distance = dist,
				fraction = frac,
			})
		end
	end

	table.sort(self.CheckpointData, function(a, b)
		return (a.distance or 0) < (b.distance or 0)
	end)

	local fractions = {}
	for i, checkpoint in ipairs(self.CheckpointData) do
		self.CheckpointReached[i] = false
		fractions[i] = checkpoint.fraction or 0
	end

	self.PayloadState.checkpointProgress = fractions
end

function ENT:BuildPathData()
	self.PathNodes = {}
	self.PathDistances = {}
	self.PathTotalDistance = 0

	local visited = {}
	local function appendNode(node)
		if not IsValid(node) then return false end
		local index = node:EntIndex()
		if visited[index] then return false end
		visited[index] = true
		table.insert(self.PathNodes, node)
		return true
	end

	local node = self.StartNode
	local guard = 0
	while IsValid(node) and guard < 512 do
		guard = guard + 1
		if not appendNode(node) then break end
		if IsValid(self.Goal) and node == self.Goal then break end

		local nextNode = node:GetInternalVariable("m_pNext")
		if not IsValid(nextNode) then break end
		node = nextNode
	end

	if #self.PathNodes < 2 then
		self.PathNodes = {}
		visited = {}
		appendNode(self.StartNode)
		for i = 1, MAX_LINKED_POINTS do
			appendNode(self.LinkedPathTracks[i])
		end
		appendNode(self.Goal)
	end

	if #self.PathNodes >= 2 then
		self.PathDistances[1] = 0
		for i = 2, #self.PathNodes do
			local segLen = self.PathNodes[i - 1]:GetPos():Distance(self.PathNodes[i]:GetPos())
			self.PathTotalDistance = self.PathTotalDistance + segLen
			self.PathDistances[i] = self.PathTotalDistance
		end
	end

	self.FallbackStartPos = IsValid(self.Train) and self.Train:GetPos() or nil
	self:BuildCheckpointData()
end

function ENT:DistanceAlongPath(position)
	if #self.PathNodes >= 2 and self.PathTotalDistance > 0 then
		local bestDist
		local bestAlong = 0

		for i = 1, #self.PathNodes - 1 do
			local a = self.PathNodes[i]:GetPos()
			local b = self.PathNodes[i + 1]:GetPos()
			local dist, segT = DistPointToSegment(position, a, b)
			if not bestDist or dist < bestDist then
				bestDist = dist
				local segLen = a:Distance(b)
				bestAlong = (self.PathDistances[i] or 0) + (segLen * segT)
			end
		end

		local frac = math.Clamp(bestAlong / self.PathTotalDistance, 0, 1)
		return bestAlong, frac
	end

	if self.FallbackStartPos and IsValid(self.Goal) then
		local total = self.FallbackStartPos:Distance(self.Goal:GetPos())
		if total > 0 and IsValid(self.Train) then
			local remaining = self.Train:GetPos():Distance(self.Goal:GetPos())
			local progress = math.Clamp(1 - (remaining / total), 0, 1)
			return progress * total, progress
		end
	end

	return 0, 0
end

function ENT:SetStateDirty()
	self.StateDirty = true
end

function ENT:SafeTriggerOutput(name, activator, value)
	if not self.TriggerOutput then return end
	if value ~= nil then
		self:TriggerOutput(name, activator or self, self, tostring(value))
	else
		self:TriggerOutput(name, activator or self)
	end
end

function ENT:GetRollbackDistance()
	local rollbackDist = 0
	for i, checkpoint in ipairs(self.CheckpointData) do
		if self.CheckpointReached[i] then
			rollbackDist = math.max(rollbackDist, checkpoint.distance or 0)
		end
	end
	return rollbackDist
end

function ENT:GetForwardSpeed()
	local cappers = math.max(math.floor(self.PayloadState.cappers or 0), 1)
	local level = math.Clamp(cappers, 1, 3)
	local speed = 0.3 * level
	speed = speed * math.Clamp(self.SpeedForwardModifier or 1, 0, 2)
	return speed
end

function ENT:ApplyTrainMotion(force)
	if not IsValid(self.Train) or not self.ShouldHandleTrainMovement then
		return
	end

	if not force and CurTime() < self.NextTrainCommand then
		return
	end
	self.NextTrainCommand = CurTime() + 0.25

	if self.PayloadState.trainState == TRAIN_STATE_FORWARD then
		self.Train:Fire("SetSpeedDirAccel", tostring(self:GetForwardSpeed()), 0)
	elseif self.PayloadState.trainState == TRAIN_STATE_RECEDING then
		self.Train:Fire("SetSpeedDirAccel", tostring(-0.05), 0)
	else
		self.Train:Fire("Stop", "", 0)
	end
end

function ENT:SetTrainState(newState)
	newState = tonumber(newState) or TRAIN_STATE_STOPPED
	if self.PayloadState.trainState == newState then
		self:ApplyTrainMotion(false)
		return
	end

	local oldState = self.PayloadState.trainState
	self.PayloadState.trainState = newState
	self:SetStateDirty()

	if newState == TRAIN_STATE_RECEDING then
		self:SafeTriggerOutput("OnTrainStartRecede", self)
	elseif newState == TRAIN_STATE_FORWARD then
		self:SafeTriggerOutput("OnTrainStartForward", self)
	elseif oldState == TRAIN_STATE_FORWARD or oldState == TRAIN_STATE_RECEDING then
		self:SafeTriggerOutput("OnTrainStop", self)
	end

	self:ApplyTrainMotion(true)
end

function ENT:UpdateCheckpointReached(curDist)
	for i, checkpoint in ipairs(self.CheckpointData) do
		if not self.CheckpointReached[i] and curDist >= (checkpoint.distance or math.huge) then
			self.CheckpointReached[i] = true
		end
	end
end

function ENT:MarkProgressOutputs(progress)
	for i, threshold in ipairs(PROGRESS_OUTPUT_THRESHOLDS) do
		if (not self.ProgressOutputFired[i]) and progress >= threshold then
			self.ProgressOutputFired[i] = true
			self:SafeTriggerOutput("OnTrainProgress" .. i, self)
		end
	end
end

function ENT:ScheduleFallbackWin()
	if self.PendingFallbackWin then return end
	self.PendingFallbackWin = true

	local timerName = "TFPayloadFallbackWin" .. self:EntIndex()
	timer.Create(timerName, 2, 1, function()
		if not IsValid(self) then return end
		if GAMEMODE.RoundHasWinner then return end
		if self.PayloadState.goalReached then
			GAMEMODE:RoundWin(self.PayloadState.attackTeam or TEAM_BLU)
		end
	end)
end

function ENT:UpdateProgress()
	if not IsValid(self.Train) then
		if self.PayloadState.active then
			self.PayloadState.active = false
			self:SetStateDirty()
		end
		return
	end

	if not self.PayloadState.active then
		self.PayloadState.active = true
		self:SetStateDirty()
	end

	local dist, progress = self:DistanceAlongPath(self.Train:GetPos())
	dist = math.max(dist or 0, 0)
	progress = math.Clamp(progress or 0, 0, 1)

	self.PathDistanceProgress = dist
	if math.abs((self.PayloadState.progress or 0) - progress) > 0.0005 then
		self.PayloadState.progress = progress
		self:SetStateDirty()
	end

	self:UpdateCheckpointReached(dist)
	self:MarkProgressOutputs(progress)

	if (not self.PayloadState.goalReached) and progress >= 0.999 then
		self.PayloadState.goalReached = true
		self:SetStateDirty()
		self:SetTrainState(TRAIN_STATE_STOPPED)
		self:ScheduleFallbackWin()
	end
end

function ENT:RefreshCapperStaleness()
	if CurTime() - (self.LastCapperUpdate or 0) <= 0.4 then return end
	if self.PayloadState.cappers ~= 0 or self.PayloadState.blocked then
		self.PayloadState.cappers = 0
		self.PayloadState.blocked = false
		self:SetStateDirty()
	end
end

function ENT:UpdateMovementState()
	if self.PayloadState.goalReached then
		self.PayloadState.recedeRemaining = 0
		self:SetTrainState(TRAIN_STATE_STOPPED)
		return
	end

	self:RefreshCapperStaleness()

	local state = self.PayloadState
	local cappers = tonumber(state.cappers) or 0

	if state.blocked or cappers < 0 then
		self.RecedeStartTime = nil
		if state.recedeRemaining ~= 0 then
			state.recedeRemaining = 0
			self:SetStateDirty()
		end
		self:SetTrainState(TRAIN_STATE_BLOCKED)
		return
	end

	if cappers > 0 then
		self.RecedeStartTime = nil
		if state.recedeRemaining ~= 0 then
			state.recedeRemaining = 0
			self:SetStateDirty()
		end
		self:SetTrainState(TRAIN_STATE_FORWARD)
		return
	end

	local rollbackDist = self:GetRollbackDistance()
	local curDist = self.PathDistanceProgress or 0
	if state.canRecede and curDist > rollbackDist + 1 then
		if not self.RecedeStartTime then
			self.RecedeStartTime = CurTime() + (state.recedeDelay or DEFAULT_RECEDE_TIME)
		end

		local remaining = math.max(self.RecedeStartTime - CurTime(), 0)
		if math.abs((state.recedeRemaining or 0) - remaining) > 0.05 then
			state.recedeRemaining = remaining
			self:SetStateDirty()
		end

		if CurTime() >= self.RecedeStartTime then
			if curDist <= rollbackDist + 1 then
				self.RecedeStartTime = nil
				state.recedeRemaining = 0
				self:SetStateDirty()
				self:SetTrainState(TRAIN_STATE_STOPPED)
			else
				self:SetTrainState(TRAIN_STATE_RECEDING)
			end
		else
			self:SetTrainState(TRAIN_STATE_STOPPED)
		end
	else
		self.RecedeStartTime = nil
		if state.recedeRemaining ~= 0 then
			state.recedeRemaining = 0
			self:SetStateDirty()
		end
		self:SetTrainState(TRAIN_STATE_STOPPED)
	end
end

function ENT:ResolveTeamsFromMapDefaults()
	if self.PayloadState.attackTeam and self.PayloadState.defendTeam then return end
	self.PayloadState.attackTeam = TEAM_BLU
	self.PayloadState.defendTeam = TEAM_RED
end

function ENT:SetPayloadTeams(attackTeam, defendTeam)
	attackTeam = tonumber(attackTeam) or TEAM_BLU
	defendTeam = tonumber(defendTeam) or TEAM_RED

	if self.PayloadState.attackTeam ~= attackTeam or self.PayloadState.defendTeam ~= defendTeam then
		self.PayloadState.attackTeam = attackTeam
		self.PayloadState.defendTeam = defendTeam
		self:SetStateDirty()
	end
end

function ENT:SetNumTrainCappers(num, source)
	num = tonumber(num) or 0
	num = math.floor(num)

	local blocked = num < 0
	if blocked then
		num = -1
	else
		num = math.max(num, 0)
	end

	if self.PayloadState.cappers ~= num or self.PayloadState.blocked ~= blocked then
		self.PayloadState.cappers = num
		self.PayloadState.blocked = blocked
		self:SetStateDirty()
	end

	if source and source.AttackTeam and source.DefendTeam then
		self:SetPayloadTeams(source.AttackTeam, source.DefendTeam)
	end

	self.LastCapperUpdate = CurTime()
end

function ENT:MaybeSyncPayloadState()
	if not GAMEMODE or not GAMEMODE.SyncPayloadState then return end

	local now = CurTime()
	if self.StateDirty then
		GAMEMODE:SyncPayloadState(false)
		self.StateDirty = false
		self.LastProgressSync = now
		return
	end

	if now - (self.LastProgressSync or 0) >= 0.2 then
		GAMEMODE:SyncPayloadState(false)
		self.LastProgressSync = now
	end
end

function ENT:InitPostEntity()
	self.Train = ResolveEntByName(self.Properties.train or "")
	self.StartNode = ResolveEntByName(self.Properties.start_node or "")
	self.Goal = ResolveEntByName(self.Properties.goal_node or "")

	for i = 1, MAX_LINKED_POINTS do
		self.LinkedPathTracks[i] = ResolveEntByName(self.Properties["linked_pathtrack_" .. i] or "")
		self.LinkedCPs[i] = ResolveEntByName(self.Properties["linked_cp_" .. i] or "")
	end

	self.PayloadState.canRecede = ToBool(self.Properties.train_can_recede, true)
	local recedeDelay = tonumber(self.Properties.train_recede_time) or 0
	if recedeDelay <= 0 then
		recedeDelay = DEFAULT_RECEDE_TIME
	end
	self.PayloadState.recedeDelay = recedeDelay
	self.PayloadState.recedeRemaining = 0

	self.SpeedForwardModifier = tonumber(self.Properties.speed_forward_modifier) or 1
	self.HudMinSpeed = {
		tonumber(self.Properties.hud_min_speed_level_1) or 30,
		tonumber(self.Properties.hud_min_speed_level_2) or 60,
		tonumber(self.Properties.hud_min_speed_level_3) or 90,
	}

	self.ShouldHandleTrainMovement = ToBool(self.Properties.handle_train_movement, false)
	if not self.ShouldHandleTrainMovement then
		-- Keep payload functional on maps that don't explicitly wire train movement through I/O.
		self.ShouldHandleTrainMovement = true
	end

	self:ResolveTeamsFromMapDefaults()
	self:BuildPathData()

	self.PayloadState.active = IsValid(self.Train)
	self:SetStateDirty()

	if GAMEMODE and GAMEMODE.RecomputeActivePayloadWatcher then
		GAMEMODE:RecomputeActivePayloadWatcher()
	end
	if GAMEMODE and GAMEMODE.SyncPayloadState then
		GAMEMODE:SyncPayloadState(true)
	end
end

function ENT:Think()
	if not GAMEMODE.PostEntityDone then return end
	if not self.PostEntityDone then
		self:InitPostEntity()
		self.PostEntityDone = true
	end

	self:UpdateProgress()
	self:UpdateMovementState()

	if GAMEMODE and GAMEMODE.RecomputeActivePayloadWatcher then
		GAMEMODE:RecomputeActivePayloadWatcher()
	end

	self:MaybeSyncPayloadState()

	self:NextThink(CurTime())
	return true
end

function ENT:Input_SetNumTrainCappers(_, _, data)
	self:SetNumTrainCappers(tonumber(data) or 0)
end

function ENT:Input_SetSpeedForwardModifier(_, _, data)
	self.SpeedForwardModifier = math.Clamp(tonumber(data) or 1, 0, 2)
	self:SetStateDirty()
end

function ENT:Input_SetTrainRecedeTime(_, _, data)
	local delay = tonumber(data) or DEFAULT_RECEDE_TIME
	if delay <= 0 then
		delay = DEFAULT_RECEDE_TIME
	end
	self.PayloadState.recedeDelay = delay
	self:SetStateDirty()
end

function ENT:Input_SetTrainCanRecede(_, _, data)
	self.PayloadState.canRecede = ToBool(data, true)
	if not self.PayloadState.canRecede then
		self.RecedeStartTime = nil
		self.PayloadState.recedeRemaining = 0
		self:SetTrainState(TRAIN_STATE_STOPPED)
	end
	self:SetStateDirty()
end

function ENT:Input_SetTrainRecedeTimeAndUpdate(_, _, data)
	self:Input_SetTrainRecedeTime(nil, nil, data)
	if self.PayloadState.cappers == 0 and not self.PayloadState.blocked then
		self.RecedeStartTime = CurTime() + (self.PayloadState.recedeDelay or DEFAULT_RECEDE_TIME)
	end
end

function ENT:Input_OnStartOvertime()
	if not self.PayloadState.inOvertime then
		self.PayloadState.inOvertime = true
		self:SetStateDirty()
	end
end

function ENT:Input_OnStopOvertime()
	if self.PayloadState.inOvertime then
		self.PayloadState.inOvertime = false
		self:SetStateDirty()
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input_" .. name]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
end

function ENT:OnRemove()
	timer.Remove("TFPayloadFallbackWin" .. self:EntIndex())
	if GAMEMODE and GAMEMODE.UnregisterPayloadWatcher then
		GAMEMODE:UnregisterPayloadWatcher(self)
	end
	if GAMEMODE and GAMEMODE.SyncPayloadState then
		GAMEMODE:SyncPayloadState(true)
	end
end

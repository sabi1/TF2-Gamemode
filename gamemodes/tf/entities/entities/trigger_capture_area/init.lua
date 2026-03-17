ENT.Base = "base_brush"
ENT.Type = "brush"

local MAX_LINKED_POINTS = 8
util.AddNetworkString("TF_ControlPointCapState")
local TEAM_CONTROL_POINT_CLASS = "team_control_point"
local TF_TEAM_CONTROL_POINT_CLASS = "tf_team_control_point"

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

	local found = ents.FindByName(name)
	if not found or #found == 0 then
		return NULL
	end

	return found[1]
end

local function GetPlayerControlPointTeam(ply)
	if not IsValid(ply) or not ply:IsPlayer() then
		return nil
	end

	if ply:Team() == TEAM_RED then
		return 2
	end
	if ply:Team() == TEAM_BLU then
		return 3
	end

	return nil
end

local function SendGlobalSoundToPlayer(ply, soundName)
	if not (IsValid(ply) and ply:IsPlayer()) then
		return
	end
	umsg.Start("TF_PlayGlobalSound", ply)
		umsg.String(soundName)
	umsg.End()
end

local function GetControlPointOwnerTeam(cp)
	if not IsValid(cp) then
		return nil
	end

	if cp.GetOwnerTeam then
		return tonumber(cp:GetOwnerTeam())
	end

	return tonumber(cp.OwnerTeam or (cp.Properties and cp.Properties.point_default_owner))
end

local function TeamCanCapturePoint(triggerEnt, teamNum)
	if not (teamNum == 2 or teamNum == 3) then
		return false
	end
	if not IsValid(triggerEnt) or not IsValid(triggerEnt.CapturePoint) then
		return false
	end

	-- Dynamic rule from control-point master/logic (preferred when present).
	if istable(triggerEnt.CapturePoint.TeamCanCap) and triggerEnt.CapturePoint.TeamCanCap[teamNum] ~= nil then
		return triggerEnt.CapturePoint.TeamCanCap[teamNum] and true or false
	end

	-- Fallback to trigger keyvalues.
	return ToBool(triggerEnt.Properties and triggerEnt.Properties["team_cancap_" .. tostring(teamNum)], true)
end

local function GetAllControlPoints()
	local points = {}
	for _, cp in ipairs(ents.FindByClass(TEAM_CONTROL_POINT_CLASS)) do
		points[#points + 1] = cp
	end
	for _, cp in ipairs(ents.FindByClass(TF_TEAM_CONTROL_POINT_CLASS)) do
		points[#points + 1] = cp
	end
	return points
end

local function NormalizeControlPointIDs()
	local points = GetAllControlPoints()
	table.sort(points, function(a, b)
		local aID = tonumber(a.ID or (a.Properties and a.Properties.point_index))
		local bID = tonumber(b.ID or (b.Properties and b.Properties.point_index))
		if aID == nil and bID == nil then
			return a:EntIndex() < b:EntIndex()
		end
		if aID == nil then
			return false
		end
		if bID == nil then
			return true
		end
		if aID == bID then
			return a:EntIndex() < b:EntIndex()
		end
		return aID < bID
	end)

	for index, cp in ipairs(points) do
		local pointID = index - 1
		cp.ID = pointID
		cp.Properties = cp.Properties or {}
		cp.Properties.point_index = pointID
	end
end

local function GetControlPointID(cp)
	if not IsValid(cp) then
		return nil
	end

	local pointID = tonumber(cp.ID or (cp.Properties and cp.Properties.point_index))
	if pointID ~= nil then
		return pointID
	end

	NormalizeControlPointIDs()
	return tonumber(cp.ID or (cp.Properties and cp.Properties.point_index))
end

local function IsHalloweenBossTruceActive()
	return GAMEMODE and GAMEMODE.HalloweenBossTruceActive and true or false
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	self.Occupants = {}
	self.PostEntityDone = false
	self.PayloadWatcher = NULL
	self.TrainCleanupDone = false
	self.AttackTeam = TEAM_BLU
	self.DefendTeam = TEAM_RED
	self.LastNumCappers = nil
	self.LastNumCappers2 = nil
	self.Pos = self:GetPos()
	self.CappingTeam = nil
	self.CaptureStartedAt = nil
	self.CaptureEndsAt = nil
	self.CaptureBaseProgress = 0
	self.DecayStartedAt = nil
	self.DecayStartProgress = 0
	self.NextContestedAnnounce = 0
	self.NextHudStateUpdate = 0
	self.LastHudStateKey = nil
end

function ENT:GetCurrentCaptureProgress()
	local progress = tonumber(self.CaptureBaseProgress) or 0
	progress = math.Clamp(progress, 0, 1)

	if self.CappingTeam and self.CaptureStartedAt and self.CaptureEndsAt and self.CaptureEndsAt > self.CaptureStartedAt then
		local frac = math.Clamp((CurTime() - self.CaptureStartedAt) / (self.CaptureEndsAt - self.CaptureStartedAt), 0, 1)
		progress = math.Clamp((tonumber(self.CaptureBaseProgress) or 0) + (1 - (tonumber(self.CaptureBaseProgress) or 0)) * frac, 0, 1)
	elseif self.DecayStartedAt then
		local decayed = (tonumber(self.DecayStartProgress) or progress) - (CurTime() - self.DecayStartedAt) / 10
		progress = math.Clamp(decayed, 0, 1)
	end

	return progress
end

function ENT:BroadcastContestedAnnouncer(ownerTeam, cappingTeam)
	local now = CurTime()
	if now < (self.NextContestedAnnounce or 0) then
		return
	end
	self.NextContestedAnnounce = now + 2.5

	if ownerTeam == 2 or ownerTeam == 3 then
		for _, pl in ipairs(player.GetAll()) do
			if GetPlayerControlPointTeam(pl) == ownerTeam then
				SendGlobalSoundToPlayer(pl, "Announcer.ControlPointContested")
			end
		end
		return
	end

	-- Neutral point: warn both game teams except the active capping team.
	for _, pl in ipairs(player.GetAll()) do
		local teamNum = GetPlayerControlPointTeam(pl)
		if (teamNum == 2 or teamNum == 3) and teamNum ~= cappingTeam then
			SendGlobalSoundToPlayer(pl, "Announcer.ControlPointContested_Neutral")
		end
	end
end

function ENT:IsPayloadPushTrigger()
	local watcher = self:ResolvePayloadWatcher(false)
	if not IsValid(watcher) then
		return false
	end

	local train = watcher.Train
	local parent = self:GetParent()
	if IsValid(train) and IsValid(parent) and parent == train then
		return true
	end

	if IsValid(train) and self.GetMoveParent then
		local moveParent = self:GetMoveParent()
		if IsValid(moveParent) and moveParent == train then
			return true
		end
	end

	-- Fallback for some custom payload maps where the moving area isn't parented.
	if string.find(game.GetMap(), "pl_", 1, true) and not IsValid(self.CapturePoint) then
		return true
	end
	if string.find(game.GetMap(), "pl_", 1, true) then
		local areas = ents.FindByClass("trigger_capture_area")
		if #areas == 1 then
			return true
		end
	end

	return false
end

function ENT:RefreshControlPointLocks()
	local master = ents.FindByClass("team_control_point_master")[1]
	if IsValid(master) and master.UpdateControlPoints then
		master:UpdateControlPoints()
		return
	end

	local points = ents.FindByClass("team_control_point")
	if #points == 0 then
		points = ents.FindByClass("tf_team_control_point")
	end

	for _, point in ipairs(points) do
		if point.UpdateLockStatus then
			point:UpdateLockStatus()
		end
	end
end

function ENT:DerivePayloadTeamsFromProperties()
	local canCapRed = TeamCanCapturePoint(self, 2)
	local canCapBlu = TeamCanCapturePoint(self, 3)

	if canCapRed and not canCapBlu then
		self.AttackTeam = TEAM_RED
		self.DefendTeam = TEAM_BLU
	elseif canCapBlu and not canCapRed then
		self.AttackTeam = TEAM_BLU
		self.DefendTeam = TEAM_RED
	else
		self.AttackTeam = TEAM_BLU
		self.DefendTeam = TEAM_RED
	end
end

function ENT:UpdatePayloadTeamsFromWatcher()
	if not IsValid(self.PayloadWatcher) or not self.PayloadWatcher.GetPayloadState then
		self:DerivePayloadTeamsFromProperties()
		return
	end

	local state = self.PayloadWatcher:GetPayloadState() or {}
	local attackTeam = tonumber(state.attackTeam)
	local defendTeam = tonumber(state.defendTeam)

	if attackTeam == TEAM_RED or attackTeam == TEAM_BLU then
		self.AttackTeam = attackTeam
	else
		self.AttackTeam = TEAM_BLU
	end

	if defendTeam == TEAM_RED or defendTeam == TEAM_BLU then
		self.DefendTeam = defendTeam
	else
		self.DefendTeam = (self.AttackTeam == TEAM_RED) and TEAM_BLU or TEAM_RED
	end
end

function ENT:ResolvePayloadWatcher(force)
	if IsValid(self.PayloadWatcher) and not force then
		return self.PayloadWatcher
	end

	local best = NULL
	for _, watcher in ipairs(ents.FindByClass("team_train_watcher")) do
		if not IsValid(watcher) then continue end

		if IsValid(self.CapturePoint) and watcher.LinkedCPs then
			for i = 1, MAX_LINKED_POINTS do
				if watcher.LinkedCPs[i] == self.CapturePoint then
					best = watcher
					break
				end
			end
		end

		if IsValid(best) then break end
		if not IsValid(best) and IsValid(watcher.Train) then
			best = watcher
		end
	end

	if not IsValid(best) and GAMEMODE and GAMEMODE.GetActivePayloadWatcher then
		best = GAMEMODE:GetActivePayloadWatcher() or NULL
	end

	self.PayloadWatcher = best
	self:UpdatePayloadTeamsFromWatcher()

	return self.PayloadWatcher
end

function ENT:IsPayloadMode()
	return self:IsPayloadPushTrigger()
end

function ENT:GetOccupants()
	local list = {}
	for ply in pairs(self.Occupants or {}) do
		if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
			list[#list + 1] = ply
		end
	end
	return list
end

function ENT:SetPayloadCapOutputs(numCappers, numCappers2)
	if not self.TriggerOutput then return end

	if self.LastNumCappers ~= numCappers then
		self.LastNumCappers = numCappers
		self:TriggerOutput("OnNumCappersChanged", self, self, tostring(numCappers))
	end

	if self.LastNumCappers2 ~= numCappers2 then
		self.LastNumCappers2 = numCappers2
		self:TriggerOutput("OnNumCappersChanged2", self, self, tostring(numCappers2))
	end
end

function ENT:ComputePayloadCapState()
	local attackers = 0
	local defenders = 0

	for ply in pairs(self.Occupants) do
		if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
			if ply:Team() == self.AttackTeam then
				attackers = attackers + 1
			elseif ply:Team() == self.DefendTeam then
				defenders = defenders + 1
			end
		end
	end

	local blocked = attackers > 0 and defenders > 0
	local cappedValue = blocked and -1 or attackers
	return attackers, defenders, blocked, cappedValue
end

function ENT:ForwardPayloadCapperState(capperValue)
	local watcher = self:ResolvePayloadWatcher(false)
	if not IsValid(watcher) then return end

	if watcher.SetPayloadTeams then
		watcher:SetPayloadTeams(self.AttackTeam, self.DefendTeam)
	end
	if watcher.SetNumTrainCappers then
		watcher:SetNumTrainCappers(capperValue, self)
	end
end

function ENT:UpdatePayloadCapperState()
	local attackers, _, _, capperValue = self:ComputePayloadCapState()
	self:SetPayloadCapOutputs(attackers, capperValue)
	self:ForwardPayloadCapperState(capperValue)
end

function ENT:CleanupPayloadTrainHurts()
	if self.TrainCleanupDone then return end
	if not self:IsPayloadMode() then return end

	local watcher = self:ResolvePayloadWatcher(true)
	if not IsValid(watcher) or not IsValid(watcher.Train) then return end

	for _, hurt in ipairs(ents.FindByClass("trigger_hurt")) do
		if hurt:GetParent() == watcher.Train then
			hurt:Remove()
		end
	end

	self.TrainCleanupDone = true
end

function ENT:InitPostEntity()
	self.Disabled = ToBool(self.Properties.startdisabled, false)
	self.CapturePoint = ResolveEntByName(self.Properties.area_cap_point or "")

	if IsValid(self.CapturePoint) then
		GetControlPointID(self.CapturePoint)
		self.CapturePoint.TriggerEntity = self
		self.CapturePoint.TeamCanCap = {
			[2] = (tonumber(self.Properties.team_cancap_2) ~= 0),
			[3] = (tonumber(self.Properties.team_cancap_3) ~= 0),
		}
	end

	self:ResolvePayloadWatcher(true)
	self:CleanupPayloadTrainHurts()
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

function ENT:PruneOccupants()
	local mins, maxs = self:WorldSpaceAABB()
	local padding = Vector(18, 18, 28)
	mins = mins - padding
	maxs = maxs + padding

	local newOccupants = {}
	for _, ent in ipairs(ents.FindInBox(mins, maxs)) do
		if IsValid(ent) and ent:IsPlayer() and ent:Alive() then
			newOccupants[ent] = true
		end
	end

	self.Occupants = newOccupants
end

function ENT:GetHudCapState()
	if not IsValid(self.CapturePoint) then
		return nil
	end
	local pointID = GetControlPointID(self.CapturePoint)
	if pointID == nil then
		return nil
	end

	local ownerTeam = GetControlPointOwnerTeam(self.CapturePoint) or 0
	local isLocked = self.CapturePoint.Locked and true or false
	local attackersByTeam = {
		[2] = 0,
		[3] = 0,
	}
	local defenders = 0

	for ply in pairs(self.Occupants or {}) do
		if not (IsValid(ply) and ply:IsPlayer() and ply:Alive()) then
			continue
		end

		local teamNum = GetPlayerControlPointTeam(ply)
		if teamNum == ownerTeam then
			defenders = defenders + 1
		elseif teamNum and teamNum >= 2 and TeamCanCapturePoint(self, teamNum) then
			attackersByTeam[teamNum] = (attackersByTeam[teamNum] or 0) + 1
		end
	end

	local cappingTeam = tonumber(self.CappingTeam) or 0
	if isLocked then
		cappingTeam = 0
	elseif cappingTeam == 0 or (attackersByTeam[cappingTeam] or 0) <= 0 then
		if attackersByTeam[2] > 0 and attackersByTeam[2] >= attackersByTeam[3] then
			cappingTeam = 2
		elseif attackersByTeam[3] > 0 then
			cappingTeam = 3
		else
			cappingTeam = 0
		end
	end

	local numCappers = attackersByTeam[cappingTeam] or 0
	local blocked = (not isLocked) and numCappers > 0 and defenders > 0
	local progress = isLocked and 0 or self:GetCurrentCaptureProgress()

	local requiredPlayers = 1
	if cappingTeam == 2 or cappingTeam == 3 then
		requiredPlayers = tonumber(self.Properties["team_numcap_" .. tostring(cappingTeam)]) or 1
	end
	requiredPlayers = math.max(math.floor(requiredPlayers), 1)

	local canCapRed = ToBool(self.Properties.team_cancap_2, true)
	local canCapBlu = ToBool(self.Properties.team_cancap_3, true)

	return {
		id = pointID,
		ownerTeam = ownerTeam,
		cappingTeam = cappingTeam,
		cappers = numCappers,
		enemies = defenders,
		requiredPlayers = requiredPlayers,
		canCapRed = canCapRed and true or false,
		canCapBlu = canCapBlu and true or false,
		blocked = blocked,
		progress = progress,
		locked = isLocked,
	}
end

function ENT:BroadcastHudCapState(force)
	if self:IsPayloadMode() then return end

	local state = self:GetHudCapState()
	if not state or state.id < 0 then return end

	local key = table.concat({
		state.id,
		state.ownerTeam,
		state.cappingTeam,
		state.cappers,
		state.enemies,
		state.requiredPlayers,
		state.canCapRed and 1 or 0,
		state.canCapBlu and 1 or 0,
		state.blocked and 1 or 0,
		math.floor((state.progress or 0) * 100),
		state.locked and 1 or 0,
	}, ":")

	if not force and self.LastHudStateKey == key and CurTime() < (self.NextHudStateUpdate or 0) then
		return
	end

	self.LastHudStateKey = key
	self.NextHudStateUpdate = CurTime() + 0.15

	net.Start("TF_ControlPointCapState")
		net.WriteInt(state.id, 8)
		net.WriteInt(state.ownerTeam or 0, 8)
		net.WriteInt(state.cappingTeam or 0, 8)
		net.WriteUInt(math.max(state.cappers or 0, 0), 4)
		net.WriteUInt(math.max(state.enemies or 0, 0), 4)
		net.WriteUInt(math.max(state.requiredPlayers or 1, 1), 4)
		net.WriteBool(state.canCapRed and true or false)
		net.WriteBool(state.canCapBlu and true or false)
		net.WriteBool(state.blocked and true or false)
		net.WriteFloat(state.progress or 0)
		net.WriteBool(state.locked and true or false)
	net.Broadcast()
end

function ENT:StartControlPointCapture(ply)
	if self.Disabled then return end
	if not IsValid(self.CapturePoint) then return end
	local pointID = GetControlPointID(self.CapturePoint)
	if pointID == nil then return end
	if IsHalloweenBossTruceActive() then return end

	local capTeam = GetPlayerControlPointTeam(ply)
	if not capTeam then return end

	if ply.CurrentControlPoint ~= pointID then
		ply.CurrentControlPoint = pointID
		umsg.Start("TF_EnterControlPoint", ply)
			umsg.Char(ply.CurrentControlPoint)
		umsg.End()

		local ownerTeam = GetControlPointOwnerTeam(self.CapturePoint)
		if ownerTeam ~= capTeam and not self.CapturePoint.Locked and TeamCanCapturePoint(self, capTeam) then
			local currentProgress = self:GetCurrentCaptureProgress()
			local switchingTeams = self.CappingTeam and self.CappingTeam ~= capTeam
			if switchingTeams then
				currentProgress = 0
			end

			self.CappingTeam = capTeam
			self.CaptureStartedAt = CurTime()
			self.CaptureBaseProgress = math.Clamp(currentProgress, 0, 1)
			self.DecayStartedAt = nil
			self.DecayStartProgress = 0
			local remaining = math.max((1 - self.CaptureBaseProgress) * 10, 0.05)
			self.CaptureEndsAt = CurTime() + remaining
			self:BroadcastHudCapState(true)
			self:BroadcastContestedAnnouncer(ownerTeam, capTeam)
			self.CapturePoint:EmitSound("ControlPoint.Start", 80, 100)
			self.CapturePoint:EmitSound("ControlPoint.Move", 80, 100)

			timer.Create("CapPoint" .. tostring(pointID), remaining, 1, function()
				if not IsValid(self) or not IsValid(self.CapturePoint) or not IsValid(ply) then
					return
				end
				if ply.CurrentControlPoint ~= pointID then
					return
				end
				if self.CapturePoint.Locked then
					return
				end

				local captureTeam = GetPlayerControlPointTeam(ply)
				if not captureTeam then
					return
				end
				if not TeamCanCapturePoint(self, captureTeam) then
					return
				end
				if GetControlPointOwnerTeam(self.CapturePoint) == captureTeam then
					return
				end

				self.CapturePoint:SetOwnerTeam(captureTeam, ply, true)
				self.CappingTeam = nil
				self.CaptureStartedAt = nil
				self.CaptureEndsAt = nil
				self.CaptureBaseProgress = 0
				self.DecayStartedAt = nil
				self.DecayStartProgress = 0
				self.CapturePoint:StopSound("ControlPoint.Move")
				self.CapturePoint:EmitSound("ControlPoint.Stop")
				self:TriggerOutput("OnCapture", ply, self.CapturePoint)
				if captureTeam == 2 then
					self:TriggerOutput("OnCapTeam1", ply, self.CapturePoint)
				elseif captureTeam == 3 then
					self:TriggerOutput("OnCapTeam2", ply, self.CapturePoint)
				end
				self:RefreshControlPointLocks()
				self:BroadcastHudCapState(true)
			end)
		end

		-- Defenders entering their own point should block capture, not reset enemy capture
		-- progress or force malfunction state.
		if ownerTeam == capTeam then
			self:BroadcastHudCapState(true)
		end
	end
end

function ENT:EndControlPointCapture(ply)
	if self.Disabled then return end
	if not IsValid(self.CapturePoint) then return end
	local pointID = GetControlPointID(self.CapturePoint)
	if pointID == nil or ply.CurrentControlPoint ~= pointID then return end

	timer.Stop("CapPoint" .. tostring(pointID))
	ply.CurrentControlPoint = -1
	umsg.Start("TF_ExitControlPoint", ply)
	umsg.End()

	local remainingAttackers = 0
	for other in pairs(self.Occupants or {}) do
		if IsValid(other) and other:IsPlayer() and other:Alive() then
			local teamNum = GetPlayerControlPointTeam(other)
			if teamNum and teamNum ~= GetControlPointOwnerTeam(self.CapturePoint) and TeamCanCapturePoint(self, teamNum) then
				remainingAttackers = remainingAttackers + 1
			end
		end
	end

	if remainingAttackers <= 0 then
		local currentProgress = self:GetCurrentCaptureProgress()
		self.CappingTeam = nil
		self.CaptureStartedAt = nil
		self.CaptureEndsAt = nil
		self.CaptureBaseProgress = math.Clamp(currentProgress, 0, 1)
		if self.CaptureBaseProgress > 0 then
			self.DecayStartedAt = CurTime()
			self.DecayStartProgress = self.CaptureBaseProgress
		else
			self.DecayStartedAt = nil
			self.DecayStartProgress = 0
		end
	end

	local capTeam = GetPlayerControlPointTeam(ply)
	if capTeam and GetControlPointOwnerTeam(self.CapturePoint) ~= capTeam then
		timer.Create("CapPoint" .. tostring(pointID), 20, 1, function()
			if not IsValid(self) or not IsValid(self.CapturePoint) then return end
			self.CapturePoint:StopSound("ControlPoint.Move")
			self.CapturePoint:StopSound("ControlPoint.Malfunction")
			self.CapturePoint:EmitSound("ControlPoint.Stop")
		end)
	end

	self:BroadcastHudCapState(true)
end

function ENT:Input_Enable()
	self.Disabled = false
end

function ENT:Input_Disable()
	self.Disabled = true
	self.Occupants = {}
	self:AbortControlPointCaptureForTruce()
	if self:IsPayloadMode() then
		self:UpdatePayloadCapperState()
	end
end

function ENT:Input_CaptureCurrentCP(_, _, data)
	if self.Disabled then return end
	if not IsValid(self.CapturePoint) or not self.CappingTeam then return end

	local ownerTeam = GetControlPointOwnerTeam(self.CapturePoint)
	local captureTeam = tonumber(self.CappingTeam)
	if not captureTeam or captureTeam == ownerTeam then return end
	if not TeamCanCapturePoint(self, captureTeam) then return end

	local activator = NULL
	for ply in pairs(self.Occupants or {}) do
		if IsValid(ply) and ply:IsPlayer() and GetPlayerControlPointTeam(ply) == captureTeam then
			activator = ply
			break
		end
	end

	local pointID = GetControlPointID(self.CapturePoint)
	if pointID ~= nil then
		timer.Stop("CapPoint" .. tostring(pointID))
	end

	self.CapturePoint:SetOwnerTeam(captureTeam, activator, true)
	self.CappingTeam = nil
	self.CaptureStartedAt = nil
	self.CaptureEndsAt = nil
	self.CaptureBaseProgress = 0
	self.DecayStartedAt = nil
	self.DecayStartProgress = 0
	self.CapturePoint:StopSound("ControlPoint.Move")
	self.CapturePoint:EmitSound("ControlPoint.Stop")
	self:TriggerOutput("OnCapture", activator, self.CapturePoint)
	if captureTeam == 2 then
		self:TriggerOutput("OnCapTeam1", activator, self.CapturePoint)
	elseif captureTeam == 3 then
		self:TriggerOutput("OnCapTeam2", activator, self.CapturePoint)
	end
	self:RefreshControlPointLocks()
	self:BroadcastHudCapState(true)
end

function ENT:AbortControlPointCaptureForTruce()
	if self:IsPayloadMode() then return end
	if not IsValid(self.CapturePoint) then return end

	local pointID = GetControlPointID(self.CapturePoint)
	if pointID == nil then return end

	timer.Stop("CapPoint" .. tostring(pointID))
	self.CappingTeam = nil
	self.CaptureStartedAt = nil
	self.CaptureEndsAt = nil
	self.CaptureBaseProgress = 0
	self.DecayStartedAt = nil
	self.DecayStartProgress = 0
	self.CapturePoint:StopSound("ControlPoint.Move")
	self.CapturePoint:StopSound("ControlPoint.Malfunction")

	for ply in pairs(self.Occupants or {}) do
		if not (IsValid(ply) and ply:IsPlayer()) then continue end
		if ply.CurrentControlPoint ~= pointID then continue end
		ply.CurrentControlPoint = -1
		umsg.Start("TF_ExitControlPoint", ply)
		umsg.End()
	end

	self:BroadcastHudCapState(true)
end

function ENT:Think()
	local mins, maxs = self:WorldSpaceAABB()
	self.Pos = (mins + maxs) * 0.5

	if GAMEMODE.PostEntityDone and not self.PostEntityDone then
		self:InitPostEntity()
		self.PostEntityDone = true
	end

	if self.PostEntityDone then
		self:ResolvePayloadWatcher(false)
		self:PruneOccupants()
		if self:IsPayloadMode() then
			self:UpdatePayloadCapperState()
			self:CleanupPayloadTrainHurts()
		elseif IsHalloweenBossTruceActive() then
			self:AbortControlPointCaptureForTruce()
		else
			if not self.CappingTeam and self.DecayStartedAt then
				local p = self:GetCurrentCaptureProgress()
				self.CaptureBaseProgress = p
				if p <= 0 then
					self.DecayStartedAt = nil
					self.DecayStartProgress = 0
					self.CaptureBaseProgress = 0
				end
			end
			self:BroadcastHudCapState(false)
		end
	end

	self:NextThink(CurTime())
	return true
end

function ENT:Input_SetTeamCanCap(_, _, data)
	if not isstring(data) then return end
	local teamNum, canCap = string.match(data, "(%S+)%s+(%S+)")
	teamNum = tonumber(teamNum)
	canCap = tonumber(canCap)
	if not teamNum or not canCap then return end

	if teamNum == 2 then
		self.Properties.team_cancap_2 = canCap
	elseif teamNum == 3 then
		self.Properties.team_cancap_3 = canCap
	else
		return
	end

	if IsValid(self.CapturePoint) then
		self.CapturePoint.TeamCanCap = self.CapturePoint.TeamCanCap or {}
		self.CapturePoint.TeamCanCap[teamNum] = (canCap ~= 0)
	end

	self:UpdatePayloadTeamsFromWatcher()
end

function ENT:Input_SetControlPoint(_, _, data)
	self.Properties.area_cap_point = tostring(data or "")
	self.CapturePoint = ResolveEntByName(self.Properties.area_cap_point)
	if IsValid(self.CapturePoint) then
		GetControlPointID(self.CapturePoint)
		self.CapturePoint.TriggerEntity = self
	end
	self:ResolvePayloadWatcher(true)
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input_" .. name]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
end

function ENT:StartTouch(ent)
	if self.Disabled then return end
	if not (IsValid(ent) and ent:IsPlayer()) then return end
	self.Occupants[ent] = true

	if self:IsPayloadMode() then
		self:UpdatePayloadCapperState()
		return
	end

	self:StartControlPointCapture(ent)
end

function ENT:EndTouch(ent)
	if self.Disabled then return end
	if not (IsValid(ent) and ent:IsPlayer()) then return end
	self.Occupants[ent] = nil

	if self:IsPayloadMode() then
		self:UpdatePayloadCapperState()
		return
	end

	self:EndControlPointCapture(ent)
end

function ENT:OnRemove()
	if self:IsPayloadMode() and IsValid(self.PayloadWatcher) and self.PayloadWatcher.SetNumTrainCappers then
		self.PayloadWatcher:SetNumTrainCappers(0, self)
	end
end

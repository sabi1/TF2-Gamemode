ENT.Base = "base_brush"
ENT.Type = "brush"

local MAX_LINKED_POINTS = 8

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

local function GetControlPointOwnerTeam(cp)
	if not IsValid(cp) then
		return nil
	end

	if cp.GetOwnerTeam then
		return tonumber(cp:GetOwnerTeam())
	end

	return tonumber(cp.OwnerTeam or (cp.Properties and cp.Properties.point_default_owner))
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Occupants = {}
	self.PostEntityDone = false
	self.PayloadWatcher = NULL
	self.TrainCleanupDone = false
	self.AttackTeam = TEAM_BLU
	self.DefendTeam = TEAM_RED
	self.LastNumCappers = nil
	self.LastNumCappers2 = nil
	self.Pos = self:GetPos()
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
	local canCapRed = ToBool(self.Properties.team_cancap_2, true)
	local canCapBlu = ToBool(self.Properties.team_cancap_3, true)

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
	self.CapturePoint = ResolveEntByName(self.Properties.area_cap_point or "")

	if IsValid(self.CapturePoint) then
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

function ENT:StartControlPointCapture(ply)
	if not IsValid(self.CapturePoint) then return end

	local capTeam = GetPlayerControlPointTeam(ply)
	if not capTeam then return end

	if ply.CurrentControlPoint ~= self.CapturePoint.ID then
		ply.CurrentControlPoint = self.CapturePoint.ID
		umsg.Start("TF_EnterControlPoint", ply)
			umsg.Char(ply.CurrentControlPoint)
		umsg.End()

		local ownerTeam = GetControlPointOwnerTeam(self.CapturePoint)
		if ownerTeam ~= capTeam and not self.CapturePoint.Locked then
			umsg.Start("TF_PlayGlobalSound", ply)
				umsg.String("Announcer.ControlPointContested")
			umsg.End()
			self.CapturePoint:EmitSound("ControlPoint.Start", 80, 100)
			self.CapturePoint:EmitSound("ControlPoint.Move", 80, 100)

			timer.Create("CapPoint" .. tostring(ply.CurrentControlPoint), 10, 1, function()
				if not IsValid(self) or not IsValid(self.CapturePoint) or not IsValid(ply) then
					return
				end
				if ply.CurrentControlPoint ~= self.CapturePoint.ID then
					return
				end
				if self.CapturePoint.Locked then
					return
				end

				local captureTeam = GetPlayerControlPointTeam(ply)
				if not captureTeam then
					return
				end
				if GetControlPointOwnerTeam(self.CapturePoint) == captureTeam then
					return
				end

				self.CapturePoint:SetOwnerTeam(captureTeam)
				self.CapturePoint:StopSound("ControlPoint.Move")
				self.CapturePoint:EmitSound("ControlPoint.Stop")
				self:RefreshControlPointLocks()
			end)
		end

		if ownerTeam == capTeam then
			timer.Stop("CapPoint" .. tostring(ply.CurrentControlPoint))
			self.CapturePoint:StopSound("ControlPoint.Move")
			self.CapturePoint:EmitSound("ControlPoint.Malfunction")
			timer.Create("CapPoint" .. tostring(ply.CurrentControlPoint), 20, 1, function()
				if not IsValid(self) or not IsValid(self.CapturePoint) then return end
				self.CapturePoint:StopSound("ControlPoint.Malfunction")
				self.CapturePoint:EmitSound("ControlPoint.Stop")
			end)
		end
	end
end

function ENT:EndControlPointCapture(ply)
	if not IsValid(self.CapturePoint) then return end
	if ply.CurrentControlPoint ~= self.CapturePoint.ID then return end

	timer.Stop("CapPoint" .. tostring(ply.CurrentControlPoint))
	ply.CurrentControlPoint = -1
	umsg.Start("TF_ExitControlPoint", ply)
	umsg.End()

	local capTeam = GetPlayerControlPointTeam(ply)
	if capTeam and GetControlPointOwnerTeam(self.CapturePoint) ~= capTeam then
		timer.Create("CapPoint" .. tostring(self.CapturePoint.ID), 20, 1, function()
			if not IsValid(self) or not IsValid(self.CapturePoint) then return end
			self.CapturePoint:StopSound("ControlPoint.Move")
			self.CapturePoint:StopSound("ControlPoint.Malfunction")
			self.CapturePoint:EmitSound("ControlPoint.Stop")
		end)
	end
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
	if not (IsValid(ent) and ent:IsPlayer()) then return end
	self.Occupants[ent] = true

	if self:IsPayloadMode() then
		self:UpdatePayloadCapperState()
		return
	end

	self:StartControlPointCapture(ent)
end

function ENT:EndTouch(ent)
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

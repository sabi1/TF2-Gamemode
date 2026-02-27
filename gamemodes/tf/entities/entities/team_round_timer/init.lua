ENT.Type = "point"

local TRAIN_STATE_FORWARD = 1

local TimeRemainingToOutput = {
{1	, "On1SecRemain"	, Sound("Announcer.RoundBegins1Seconds")	, Sound("Announcer.RoundEnds1seconds")},
{2	, "On2SecRemain"	, Sound("Announcer.RoundBegins2Seconds")	, Sound("Announcer.RoundEnds2seconds")},
{3	, "On3SecRemain"	, Sound("Announcer.RoundBegins3Seconds")	, Sound("Announcer.RoundEnds3seconds")},
{4	, "On4SecRemain"	, Sound("Announcer.RoundBegins4Seconds")	, Sound("Announcer.RoundEnds4seconds")},
{5	, "On5SecRemain"	, Sound("Announcer.RoundBegins5Seconds")	, Sound("Announcer.RoundEnds5seconds")},
{6	, "On6SecRemain"	, nil	, nil},
{7	, "On7SecRemain"	, nil	, nil},
{8	, "On8SecRemain"	, nil	, nil},
{9	, "On9SecRemain"	, nil	, nil},
{10	, "On10SecRemain"	, Sound("Announcer.RoundBegins10Seconds")	, Sound("Announcer.RoundEnds10seconds")},
{20	, "On20SecRemain"	, nil	, nil},
{30	, "On30SecRemain"	, Sound("Announcer.RoundBegins30Seconds")	, Sound("Announcer.RoundEnds30seconds")},
{60	, "On1MinRemain"	, Sound("Announcer.RoundBegins60Seconds")	, Sound("Announcer.RoundEnds60seconds")},
{120, "On2MinRemain"	, nil										, nil},
{180, "On3MinRemain"	, nil										, nil},
{240, "On4MinRemain"	, nil										, nil},
{300, "On5MinRemain"	, nil										, Sound("Announcer.RoundEnds5minutes")},
}


local TimeRemainingToOutputMVM = {
	{1	, "On1SecRemain"	, Sound("Announcer.RoundBegins1Seconds")	, Sound("Announcer.RoundEnds1seconds")},
	{2	, "On2SecRemain"	, Sound("Announcer.RoundBegins2Seconds")	, Sound("Announcer.RoundEnds2seconds")},
	{3	, "On3SecRemain"	, Sound("Announcer.RoundBegins3Seconds")	, Sound("Announcer.RoundEnds3seconds")},
	{4	, "On4SecRemain"	, Sound("Announcer.RoundBegins4Seconds")	, Sound("Announcer.RoundEnds4seconds")},
	{5	, "On5SecRemain"	, Sound("Announcer.RoundBegins5Seconds")	, Sound("Announcer.RoundEnds5seconds")},
	{6	, "On6SecRemain"	, nil	, nil},
	{7	, "On7SecRemain"	, nil	, nil},
	{8	, "On8SecRemain"	, nil	, nil},
	{9	, "On9SecRemain"	, nil	, nil},
	{10	, "On10SecRemain"	, "Announcer.MVM_Wave_Start", nil},
	{20	, "On20SecRemain"	, nil	, nil},
	{30	, "On30SecRemain"	, nil, nil},
	{60	, "On1MinRemain"	, nil, nil},
	{120, "On2MinRemain"	, nil										, nil},
	{180, "On3MinRemain"	, nil										, nil},
	{240, "On4MinRemain"	, nil										, nil},
	{300, "On5MinRemain"	, nil										, Sound("Announcer.RoundEnds5minutes")},
	}
function ENT:Initialize()
end

function ENT:InitPostEntity()
	--print(self)
	PrintTable(self.Properties or {})
	
	self.StartPaused = (self.Properties.start_paused == 1)
	self.SetupLength = self.Properties.setup_length or 0
	self.TimerLength = self.Properties.timer_length
	self.MaxLength = self.Properties.max_length or 0
	self.AutoCountdown = (self.Properties.auto_countdown == 1)
	self.ShowInHUD = (self.Properties.show_in_hud == 1)
	
	if self.MaxLength == 0 then self.MaxLength = math.huge end
	
	if self.ShowInHUD then
		GAMEMODE.CurrentHUDTimer = self
	end
	
	self:RestartTimer()
end

function ENT:RestartTimer(endsetup)
	self.LastPlayedTimeSignal = nil
	self.RoundFinished = false
	
	if not endsetup and self.SetupLength>0 then
		self.IsSetupPhase = true
		if self.StartPaused then
			self:SetAndPauseTimer(self.SetupLength, true)
		else
			self:SetAndResumeTimer(self.SetupLength, true)
		end
		self:TriggerOutput("OnSetupStart",self)
	else
		
		timer.Simple(1, function()
			if not IsValid(self) then
				return
			end

			self.IsSetupPhase = false
			if (string.find(game.GetMap(),"mvm")) then
				umsg.Start("TF_PlayGlobalSound")
					umsg.String("Ambient.Siren")
				umsg.End()
			else
				if (!self.WaitingForPlayers) then
					umsg.Start("TF_PlayGlobalSound")
						umsg.String("Ambient.Siren")
					umsg.End()
				end 
			end
			if self.StartPaused then
				self:SetAndPauseTimer(self.TimerLength, true)
			else
				self:SetAndResumeTimer(self.TimerLength, true)
			end
			if (string.find(game.GetMap(),"mvm")) then
				self.StartPaused = true 
				self:SetAndPauseTimer(0,true)
				for k,v in ipairs(ents.FindByClass("func_door")) do
					if (v:GetName() == "cave_door") then
						v:Fire("Open","",0)
					end
				end
			end
			self:TriggerOutput("OnRoundStart",self)
			self:TriggerOutput("OnSetupFinished",self)
		end)
	end
end

function ENT:RestartTimer2(endsetup)
	self.LastPlayedTimeSignal = nil
	self.RoundFinished = false
	
	if not endsetup and self.SetupLength>0 then
		self.IsSetupPhase = true
		if self.StartPaused then
			self:SetAndPauseTimer(self.SetupLength, true)
		else
			self:SetAndResumeTimer(self.SetupLength, true)
		end
		self:TriggerOutput("OnSetupStart")
	else
		
		self.IsSetupPhase = false
		if (string.find(game.GetMap(),"mvm")) then
			umsg.Start("TF_PlayGlobalSound")
				umsg.String("MVM.Siren")
			umsg.End()
		else
			umsg.Start("TF_PlayGlobalSound")
				umsg.String("Ambient.Siren")
			umsg.End()
		end
		if self.StartPaused then
			self:SetAndPauseTimer(self.TimerLength, true)
		else
			self:SetAndResumeTimer2(self.TimerLength, true)
		end
			if (string.find(game.GetMap(),"mvm")) then
				self.StartPaused = true
				self:SetAndPauseTimer(0,true)
				for k,v in ipairs(ents.FindByClass("func_door")) do
					if (v:GetName() == "cave_door") then
						v:Fire("Open","",0)
					end
				end
			end
			self:TriggerOutput("OnRoundStart",self)
			self:TriggerOutput("OnSetupFinished",self)
		
	end
end

function ENT:GetTime()
	if not self.TimerReference or not self.TimerLastUpdated then
		return 0
	end
	
	if self.TimerPaused then
		return math.Clamp(self.TimerPaused, 0, math.huge)
	else
		return math.Clamp(self.TimerReference - (CurTime() - self.TimerLastUpdated), 0, math.huge)
	end
end

function ENT:SetTime(sec)
	sec = tonumber(sec) or 0
	local maxLen = tonumber(self.MaxLength)
	if maxLen == nil then
		maxLen = math.huge
		self.MaxLength = maxLen
	end
	sec = math.Clamp(sec, 0, maxLen)
	
	if self.TimerPaused then
		self:SetAndPauseTimer(sec)
	else
		self:SetAndResumeTimer(sec)
	end
end

function ENT:SetAndResumeTimer(sec, setmax)
	sec = tonumber(sec) or 0
	local maxLen = tonumber(self.MaxLength)
	if maxLen == nil then
		maxLen = math.huge
		self.MaxLength = maxLen
	end
	sec = math.Clamp(sec, 0, maxLen)
	
	self.TimerReference = sec
	self.TimerLastUpdated = CurTime()
	self.TimerPaused = nil
	
	if self==GAMEMODE.CurrentHUDTimer then
		umsg.Start("TF_SetAndResumeTimer")
			umsg.Float(sec)
			umsg.Float((setmax and sec) or 0)
			umsg.Bool(self.IsSetupPhase)
		umsg.End()
	end
end
function ENT:SetAndResumeTimer2(sec, setmax)
	sec = tonumber(sec) or 0
	local maxLen = tonumber(self.MaxLength)
	if maxLen == nil then
		maxLen = math.huge
		self.MaxLength = maxLen
	end
	sec = math.Clamp(sec, 0, maxLen)
	
	self.TimerReference = sec
	self.TimerLastUpdated = CurTime()
	self.TimerPaused = nil
	
	if self==GAMEMODE.CurrentHUDTimer then
		umsg.Start("TF_SetAndResumeTimerWaiting")
			umsg.Float(sec)
			umsg.Float((setmax and sec) or 0)
			umsg.Bool(true)
		umsg.End()
	end
end

function ENT:SetAndPauseTimer(sec, setmax)
	sec = tonumber(sec) or 0
	local maxLen = tonumber(self.MaxLength)
	if maxLen == nil then
		maxLen = math.huge
		self.MaxLength = maxLen
	end
	sec = math.Clamp(sec, 0, maxLen)
	
	self.TimerPaused = sec
	
	if self==GAMEMODE.CurrentHUDTimer then
		umsg.Start("TF_SetAndPauseTimer")
			umsg.Float(sec)
			umsg.Float((setmax and sec) or 0)
			umsg.Bool(self.IsSetupPhase)
		umsg.End()
	end
end

function ENT:ResumeTimer()
	self:SetAndResumeTimer(self:GetTime())
end

function ENT:PauseTimer()
	self:SetAndPauseTimer(self:GetTime())
end

function ENT:KeyValue(key,value)
	if ( string.Left( key, 2 ) == "On" ) then
		self:StoreOutput( key, value )
	end
	
	key = string.lower(key)
	
	if not self.Properties then
		self.Properties = {}
	end
	if tonumber(value) then value=tonumber(value) end
	self.Properties[key] = value
end

function ENT:GetPayloadWatcher()
	if GAMEMODE and GAMEMODE.GetActivePayloadWatcher then
		local watcher = GAMEMODE:GetActivePayloadWatcher()
		if IsValid(watcher) then
			return watcher
		end
	end

	for _, watcher in ipairs(ents.FindByClass("team_train_watcher")) do
		if IsValid(watcher) then
			return watcher
		end
	end

	return NULL
end

function ENT:GetPayloadWatcherState()
	local watcher = self:GetPayloadWatcher()
	if not IsValid(watcher) or not watcher.GetPayloadState then
		return NULL, nil
	end
	return watcher, watcher:GetPayloadState() or {}
end

function ENT:IsPayloadContestedOrPushed(state)
	if not istable(state) then return false end
	if (tonumber(state.cappers) or 0) > 0 then return true end
	if state.blocked then return true end
	if tonumber(state.trainState) == TRAIN_STATE_FORWARD then return true end
	return false
end

function ENT:GetPayloadDefenderTeam(state)
	if istable(state) then
		local defend = tonumber(state.defendTeam)
		if defend == TEAM_RED or defend == TEAM_BLU then
			return defend
		end

		local attack = tonumber(state.attackTeam)
		if attack == TEAM_RED then
			return TEAM_BLU
		end
	end
	return TEAM_RED
end

function ENT:TryStartPayloadOvertime()
	if self.PayloadOvertime then return true end

	local watcher, state = self:GetPayloadWatcherState()
	if not IsValid(watcher) or not istable(state) then return false end
	if not state.active or state.goalReached then return false end
	if not self:IsPayloadContestedOrPushed(state) then return false end

	self.PayloadOvertime = true
	self:SetAndPauseTimer(0)

	if watcher.Input_OnStartOvertime then
		watcher:Input_OnStartOvertime(self, self, "")
	elseif watcher.AcceptInput then
		watcher:AcceptInput("OnStartOvertime", self, self, "")
	end

	return true
end

function ENT:StopPayloadOvertime()
	if not self.PayloadOvertime then return end
	self.PayloadOvertime = false

	local watcher = self:GetPayloadWatcher()
	if not IsValid(watcher) then return end

	if watcher.Input_OnStopOvertime then
		watcher:Input_OnStopOvertime(self, self, "")
	elseif watcher.AcceptInput then
		watcher:AcceptInput("OnStopOvertime", self, self, "")
	end
end

function ENT:Think()
	if not GAMEMODE.PostEntityDone then return end
	if GAMEMODE.PostEntityDone and not self.PostEntityDone then
		self:InitPostEntity()
		self.PostEntityDone = true
		
		-- return (I want you to start thinking, immediately)
	end
	GAMEMODE.IsSetupPhase = self.IsSetupPhase
	local t = self:GetTime()

	if self.PayloadOvertime and GAMEMODE.RoundHasWinner then
		self:StopPayloadOvertime()
	end

	if t<=0 then
		if self.IsSetupPhase then
			self:RestartTimer(true)
		elseif self.PayloadOvertime then
			local _, state = self:GetPayloadWatcherState()
			if state and state.goalReached then
				self:StopPayloadOvertime()
				self.RoundFinished = true
				return
			end

			if self:IsPayloadContestedOrPushed(state) and not GAMEMODE.RoundHasWinner and not (state and state.goalReached) then
				return
			end

			self:StopPayloadOvertime()
			self.RoundFinished = true
			self:TriggerOutput("OnFinished")

			if not GAMEMODE.RoundHasWinner then
				GAMEMODE:RoundWin(self:GetPayloadDefenderTeam(state))
			end
		elseif not self.RoundFinished then
			if self:TryStartPayloadOvertime() then
				return
			end

			self.RoundFinished = true
			self:TriggerOutput("OnFinished")
			if !self.IsSetupPhase then
				if (string.find(game.GetMap(),"pl_")) then
					GAMEMODE:RoundWin(2)
				end
			end
		end
		return
	end
	if (string.find(game.GetMap(),"mvm_")) then

		for k,v in ipairs(TimeRemainingToOutputMVM) do
			if k == self.LastPlayedTimeSignal then
				break
			end
			
			if t <= v[1] then
				self:TriggerOutput(v[2])
				self.LastPlayedTimeSignal = k
				if (!self.WaitingForPlayers) then
					if self.IsSetupPhase and v[3] then
						umsg.Start("TF_PlayGlobalSound")
							umsg.String(v[3])
						umsg.End()
					elseif not self.IsSetupPhase and self.AutoCountdown and v[4] then
						umsg.Start("TF_PlayGlobalSound")
							umsg.String(v[4])
						umsg.End()
					end
				end
				break
			end
		end

	else
		for k,v in ipairs(TimeRemainingToOutput) do
			if k == self.LastPlayedTimeSignal then
				break
			end
			
			if t <= v[1] then
				self:TriggerOutput(v[2])
				self.LastPlayedTimeSignal = k
				if (!self.WaitingForPlayers) then
					if self.IsSetupPhase and v[3] then
						umsg.Start("TF_PlayGlobalSound")
							umsg.String(v[3])
						umsg.End()
					elseif not self.IsSetupPhase and self.AutoCountdown and v[4] then
						umsg.Start("TF_PlayGlobalSound")
							umsg.String(v[4])
						umsg.End()
					end
				end
				break
			end
		end
	end
end

function ENT:Input_Pause(activator, caller, data)
	self:PauseTimer()
end

function ENT:Input_Resume(activator, caller, data)
	self:ResumeTimer()
end

function ENT:Input_SetTime(activator, caller, data)
	local sec = tonumber(data)
	if sec then
		self:SetTime(sec)
	end
end

function ENT:Input_AddTime(activator, caller, data)
	local sec = tonumber(data)
	if sec then
		self:SetTime(self:GetTime() + sec)
	end
end

function ENT:Input_AddTeamTime(activator, caller, data)
	local t, sec = string.match(data,"(.*)%s+(.*)")
	t, sec = tonumber(t), tonumber(sec)
	for k,v in ipairs(player.GetAll()) do
		if (v:Team() == t) then
			v:SendLua([[surface.PlaySound("Announcer.TimeAwardedForTeam")]])
		else
			v:SendLua([[surface.PlaySound("Announcer.TimeAddedForEnemy")]])
		end
			v:SendLua([[surface.PlaySound("Hud.PointCaptured")]])
	end
	if t and sec then
		--print(Format("Added %d seconds due to team %d", sec, t))
		self:SetTime(self:GetTime() + sec)
	end
end

function ENT:Input_Restart(activator, caller, data)
	self:RestartTimer()
end

function ENT:Input_ShowInHUD(activator, caller, data)
	if tonumber(data)==1 then
		self.ShowInHUD = true
		GAMEMODE.CurrentHUDTimer = self
	else
		self.ShowInHUD = false
		if GAMEMODE.CurrentHUDTimer == self then
			GAMEMODE.CurrentHUDTimer = nil
			for _,v in pairs(ents.FindByClass("team_round_timer")) do
				if v.ShowInHUD then
					GAMEMODE.CurrentHUDTimer = v
					break
				end
			end
		end
	end
end

function ENT:Input_SetMaxTime(activator, caller, data)
	local sec = tonumber(data)
	if sec then
		self.MaxLength = sec
		if self.MaxLength <= 0 then self.MaxLength = math.huge end
		
		if self:GetTime()>self.MaxLength then
			self:SetTime(self.MaxLength)
		end
	end
end

function ENT:OnRemove()
	umsg.Start("TF_RemoveTimer")
	umsg.End()
end
function ENT:Input_AutoCountdown(activator, caller, data)
	self.AutoCountdown = (tonumber(data)==1)
end

function ENT:Input_SetSetupTime(activator, caller, data)
	local sec = tonumber(data)
	if sec then
		self.SetupLength = sec
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	--print(self, "received input", name)
	local f = self["Input_"..name]
	if f then
		f(self, activator, caller, data)
	end
end

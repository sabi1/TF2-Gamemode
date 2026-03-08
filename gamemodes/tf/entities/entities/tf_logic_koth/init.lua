ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.TimerInitialLength = tonumber(self.Properties.timer_length) or 180
	self.TimeToUnlockPoint = tonumber(self.Properties.unlock_point) or 30
	self.RedTimer = NULL
	self.BlueTimer = NULL
	self.ActiveTeam = 0
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

local function IsKothMap()
	return string.StartWith(string.lower(game.GetMap() or ""), "koth_")
end

local function ToNumber(value, fallback)
	local n = tonumber(value)
	if n == nil then return fallback end
	return n
end

function ENT:FindExistingTimer(name)
	for _, timerEnt in ipairs(ents.FindByClass("team_round_timer")) do
		if IsValid(timerEnt) and string.lower(timerEnt:GetName() or "") == string.lower(name) then
			return timerEnt
		end
	end
	return NULL
end

function ENT:CreateKothTimer(teamNum, name)
	local timerEnt = self:FindExistingTimer(name)
	if not IsValid(timerEnt) then
		timerEnt = ents.Create("team_round_timer")
		if not IsValid(timerEnt) then
			return NULL
		end

		timerEnt:SetName(name)
		timerEnt:Spawn()
		timerEnt:Activate()
	end

	local duration = math.max(1, ToNumber(self.TimerInitialLength, 180))
	timerEnt.Properties = timerEnt.Properties or {}
	timerEnt.Properties.start_paused = 1
	timerEnt.Properties.setup_length = 0
	timerEnt.Properties.timer_length = duration
	timerEnt.Properties.max_length = duration
	timerEnt.Properties.auto_countdown = 1
	timerEnt.Properties.show_in_hud = 1
	timerEnt.Properties.teamnum = teamNum

	if timerEnt.SetAndPauseTimer then
		timerEnt:SetAndPauseTimer(duration, true)
	elseif timerEnt.SetTime then
		timerEnt:SetTime(duration)
	end
	timerEnt.ShowInHUD = false
	if timerEnt == GAMEMODE.CurrentHUDTimer then
		GAMEMODE.CurrentHUDTimer = nil
	end

	return timerEnt
end

function ENT:EnsureTeamTimers()
	if not IsKothMap() then return end

	if not IsValid(self.BlueTimer) then
		self.BlueTimer = self:CreateKothTimer(TEAM_BLU, "zz_blue_koth_timer")
	end
	if not IsValid(self.RedTimer) then
		self.RedTimer = self:CreateKothTimer(TEAM_RED, "zz_red_koth_timer")
	end
end

function ENT:SetActiveTeamClock(teamNum)
	self:EnsureTeamTimers()
	if not IsValid(self.RedTimer) or not IsValid(self.BlueTimer) then return end
	if self.ActiveTeam == teamNum then return end

	self.ActiveTeam = teamNum or 0

	if teamNum == TEAM_RED then
		self.BlueTimer:PauseTimer()
		self.RedTimer:ResumeTimer()
	elseif teamNum == TEAM_BLU then
		self.RedTimer:PauseTimer()
		self.BlueTimer:ResumeTimer()
	else
		self.RedTimer:PauseTimer()
		self.BlueTimer:PauseTimer()
	end
end

function ENT:GetPrimaryControlPoint()
	local points = ents.FindByClass("team_control_point")
	if #points == 0 then
		points = ents.FindByClass("tf_team_control_point")
	end
	if #points == 0 then return NULL end

	table.sort(points, function(a, b)
		local ai = tonumber(a.ID or (a.Properties and a.Properties.point_index) or 0) or 0
		local bi = tonumber(b.ID or (b.Properties and b.Properties.point_index) or 0) or 0
		return ai < bi
	end)

	return points[1]
end

function ENT:Input_RoundSpawn()
	self.TimerInitialLength = math.max(1, ToNumber(self.Properties.timer_length, self.TimerInitialLength or 180))
	self.TimeToUnlockPoint = math.max(0, ToNumber(self.Properties.unlock_point, self.TimeToUnlockPoint or 30))
	self:EnsureTeamTimers()
	self:SetActiveTeamClock(0)
end

function ENT:Input_RoundActivate()
	local points = ents.FindByClass("team_control_point")
	if #points == 0 then
		points = ents.FindByClass("tf_team_control_point")
	end

	for _, point in ipairs(points) do
		if IsValid(point) and point.SetLocked then
			point:SetLocked(true)
			if self.TimeToUnlockPoint <= 0 then
				point:SetLocked(false)
			else
				timer.Simple(self.TimeToUnlockPoint, function()
					if IsValid(point) then
						point:SetLocked(false)
					end
				end)
			end
		end
	end
end

function ENT:Input_SetRedTimer(_, _, data)
	self:EnsureTeamTimers()
	if IsValid(self.RedTimer) then
		self.RedTimer:SetTime(ToNumber(data, self.RedTimer:GetTime()))
	end
end

function ENT:Input_SetBlueTimer(_, _, data)
	self:EnsureTeamTimers()
	if IsValid(self.BlueTimer) then
		self.BlueTimer:SetTime(ToNumber(data, self.BlueTimer:GetTime()))
	end
end

function ENT:Input_AddRedTimer(_, _, data)
	self:EnsureTeamTimers()
	if IsValid(self.RedTimer) then
		self.RedTimer:SetTime(self.RedTimer:GetTime() + ToNumber(data, 0))
	end
end

function ENT:Input_AddBlueTimer(_, _, data)
	self:EnsureTeamTimers()
	if IsValid(self.BlueTimer) then
		self.BlueTimer:SetTime(self.BlueTimer:GetTime() + ToNumber(data, 0))
	end
end

function ENT:Input_SetRedKothClockActive()
	self:SetActiveTeamClock(TEAM_RED)
end

function ENT:Input_SetBlueKothClockActive()
	self:SetActiveTeamClock(TEAM_BLU)
end

function ENT:Think()
	if not IsKothMap() then return end

	self:EnsureTeamTimers()

	local cp = self:GetPrimaryControlPoint()
	local owner = 0
	if IsValid(cp) and cp.GetOwnerTeam then
		owner = tonumber(cp:GetOwnerTeam() or 0) or 0
	end

	if owner ~= self.ActiveTeam then
		self:SetActiveTeamClock(owner)
	end

	self:NextThink(CurTime() + 0.1)
	return true
end

concommand.Add("tf_debug_koth_timers", function(ply)
	if IsValid(ply) and not (ply:IsAdmin() or ply:IsListenServerHost()) then return end

	print("[TF2-Gamemode] KOTH timer debug for map:", game.GetMap())
	local logic = ents.FindByClass("tf_logic_koth")[1]
	if IsValid(logic) then
		print("[TF2-Gamemode] tf_logic_koth activeTeam:", logic.ActiveTeam or 0)
	end

	for _, timerEnt in ipairs(ents.FindByClass("team_round_timer")) do
		local props = timerEnt.Properties or {}
		local n = timerEnt:GetName() or "<unnamed>"
		local teamNum = tonumber(props.teamnum or props.team) or 0
		local t = timerEnt.GetTime and timerEnt:GetTime() or -1
		print(string.format("[TF2-Gamemode] timer=%s team=%d paused=%s time=%.2f", n, teamNum, tostring(timerEnt.TimerPaused ~= nil), tonumber(t) or -1))
	end
end)

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input_" .. tostring(name or "")]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
end

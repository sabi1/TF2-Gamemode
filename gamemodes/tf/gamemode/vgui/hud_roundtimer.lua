local PANEL = {}

local W = ScrW()
local H = ScrH()
local Scale = H / 480
local TEAM_RED_ID = rawget(_G, "TEAM_RED") or 2
local TEAM_BLU_ID = rawget(_G, "TEAM_BLU") or 3
local TEAM_UNASSIGNED_ID = rawget(_G, "TEAM_UNASSIGNED") or 0

local objectives_timepanel_bg = {
	surface.GetTextureID("hud/objectives_timepanel_blue_bg"),
	surface.GetTextureID("hud/objectives_timepanel_red_bg"),
	surface.GetTextureID("hud/objectives_timepanel_blue_bg")
}
local objectives_timepanel_progressbar = surface.GetTextureID("hud/objectives_timepanel_progressbar")
local objectives_timepanel_suddendeath = surface.GetTextureID("hud/objectives_timepanel_suddendeath")
local objectives_timepanel_active_bg = surface.GetTextureID("hud/objectives_timepanel_active_bg")

local TimerRes = {
	bgX = 16,
	bgY = 9,
	bgW = 78,
	bgH = 33,
	progressX = 67,
	progressY = 16,
	progressW = 20,
	progressH = 20,
	stateX = 16,
	stateY = 31,
	stateW = 78,
	stateH = 20,
	timeX = 45.2,
	timeY = 26.5,
}

local KOTHRes = {
	blueX = 0,
	redX = 90,
	activeY = 9,
	activeW = 78,
	activeH = 33,
}

local RoundTimerState = {
	Reference = nil,
	LastUpdated = nil,
	Max = nil,
	IsSetup = nil,
	IsWaiting = nil,
	Paused = nil,
	HooksRegistered = false,
}

local KothTimerState = {
	[TEAM_RED_ID] = {},
	[TEAM_BLU_ID] = {},
}

local KothHudAnim = {
	ActiveTeam = TEAM_UNASSIGNED_ID,
	PulseStart = 0,
}

do
	local timerResPath = (TF_GetHudResPath and TF_GetHudResPath((TF_GetHudGameMode and TF_GetHudGameMode()) or "cp", "roundTimer", "resource/ui/hudobjectivetimepanel.res")) or "resource/ui/hudobjectivetimepanel.res"
	local kothResPath = (TF_GetHudResPath and TF_GetHudResPath("koth", "kothTimer", "resource/ui/hudobjectivekothtimepanel.res")) or "resource/ui/hudobjectivekothtimepanel.res"

	local tree = TF2Res and TF2Res.Load and TF2Res.Load(timerResPath)
	local bg = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "TimePanelBG")
	local progress = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "TimePanelProgressBar")
	local setupBg = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "SetupBG")
	local setupLabel = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "SetupLabel")
	if bg and TF2Res.GetNumber then
		TimerRes.bgX = TF2Res.GetNumber(bg, "xpos", TimerRes.bgX)
		TimerRes.bgY = TF2Res.GetNumber(bg, "ypos", TimerRes.bgY)
		TimerRes.bgW = TF2Res.GetNumber(bg, "wide", TimerRes.bgW)
		TimerRes.bgH = TF2Res.GetNumber(bg, "tall", TimerRes.bgH)
		objectives_timepanel_bg[1] = TF2Res.GetTextureID(bg, "image", "hud/objectives_timepanel_blue_bg")
	end
	if progress and TF2Res.GetNumber then
		TimerRes.progressX = TF2Res.GetNumber(progress, "xpos", TimerRes.progressX)
		TimerRes.progressY = TF2Res.GetNumber(progress, "ypos", TimerRes.progressY)
		TimerRes.progressW = TF2Res.GetNumber(progress, "wide", TimerRes.progressW)
		TimerRes.progressH = TF2Res.GetNumber(progress, "tall", TimerRes.progressH)
		objectives_timepanel_progressbar = TF2Res.GetTextureID(progress, "image", "hud/objectives_timepanel_progressbar")
	end
	if setupBg and TF2Res.GetNumber then
		TimerRes.stateX = TF2Res.GetNumber(setupBg, "xpos", TimerRes.stateX)
		TimerRes.stateY = TF2Res.GetNumber(setupBg, "ypos", TimerRes.stateY)
		TimerRes.stateW = TF2Res.GetNumber(setupBg, "wide", TimerRes.stateW)
		TimerRes.stateH = TF2Res.GetNumber(setupBg, "tall", TimerRes.stateH)
		objectives_timepanel_suddendeath = TF2Res.GetTextureID(setupBg, "image", "hud/objectives_timepanel_suddendeath")
	end
	if setupLabel and TF2Res.GetNumber then
		TimerRes.timeX = TF2Res.GetNumber(bg or setupLabel, "xpos", 23) + 22.2
		TimerRes.timeY = TF2Res.GetNumber(bg or setupLabel, "ypos", 11) + 15.5
	end

	local kothTree = TF2Res and TF2Res.Load and TF2Res.Load(kothResPath)
	local bluePanel = kothTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(kothTree, "BlueTimer")
	local redPanel = kothTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(kothTree, "RedTimer")
	local activeBg = kothTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(kothTree, "ActiveTimerBG")

	if bluePanel and TF2Res.GetNumber then
		KOTHRes.blueX = TF2Res.GetNumber(bluePanel, "xpos", KOTHRes.blueX)
	end
	if redPanel and TF2Res.GetNumber then
		KOTHRes.redX = TF2Res.GetNumber(redPanel, "xpos", KOTHRes.redX)
	end
	if activeBg and TF2Res.GetNumber then
		KOTHRes.activeY = TF2Res.GetNumber(activeBg, "ypos", KOTHRes.activeY)
		KOTHRes.activeW = TF2Res.GetNumber(activeBg, "wide", KOTHRes.activeW)
		KOTHRes.activeH = TF2Res.GetNumber(activeBg, "tall", KOTHRes.activeH)
		objectives_timepanel_active_bg = TF2Res.GetTextureID(activeBg, "image", "hud/objectives_timepanel_active_bg")
	end
end

local function IsMvMMap()
	if TF_IsMvMMap then
		return TF_IsMvMMap()
	end
	return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

local function IsKothMap()
	if TF_GetHudGameMode then
		return TF_GetHudGameMode() == "koth"
	end
	return string.StartWith(string.lower(game.GetMap() or ""), "koth_")
end

local function ShouldSuppressTimerHUD()
	local lp = LocalPlayer()
	if not IsValid(lp) then
		return true
	end

	if gui.IsGameUIVisible() then
		return true
	end

	if lp.GetObserverMode and lp:GetObserverMode() == OBS_MODE_FREEZECAM then
		return true
	end

	return false
end

local function applyRoundTimerState(msg, waitingMode, pausedMode)
	local t = msg:ReadFloat()
	RoundTimerState.Reference = t
	RoundTimerState.LastUpdated = CurTime()

	local maxTime = msg:ReadFloat()
	if maxTime > 0 then
		RoundTimerState.Max = maxTime
	end

	if waitingMode then
		RoundTimerState.IsWaiting = msg:ReadBool()
		RoundTimerState.IsSetup = nil
		RoundTimerState.Paused = nil
		return
	end

	RoundTimerState.IsSetup = msg:ReadBool()
	RoundTimerState.IsWaiting = nil

	if pausedMode then
		RoundTimerState.Paused = t
	else
		RoundTimerState.Paused = nil
	end
end

local function applyKothTimerState(msg)
	local team = msg:ReadChar()
	if team ~= TEAM_RED_ID and team ~= TEAM_BLU_ID then return end

	local state = KothTimerState[team] or {}
	state.Reference = msg:ReadFloat()
	state.LastUpdated = CurTime()

	local maxTime = msg:ReadFloat()
	if maxTime > 0 then
		state.Max = maxTime
	end

	state.Paused = msg:ReadBool()
	state.IsSetup = msg:ReadBool()
	state.IsWaiting = msg:ReadBool()

	KothTimerState[team] = state
end

if not RoundTimerState.HooksRegistered then
	RoundTimerState.HooksRegistered = true
	usermessage.Hook("TF_SetAndResumeTimer", function(msg)
		applyRoundTimerState(msg, false, false)
	end)

	usermessage.Hook("TF_SetAndResumeTimerWaiting", function(msg)
		applyRoundTimerState(msg, true, false)
	end)

	usermessage.Hook("TF_SetAndPauseTimer", function(msg)
		applyRoundTimerState(msg, false, true)
	end)

	usermessage.Hook("TF_KothTimerState", function(msg)
		applyKothTimerState(msg)
	end)

	usermessage.Hook("TF_KothTimerRemoved", function(msg)
		local team = msg:ReadChar()
		if team == TEAM_RED_ID or team == TEAM_BLU_ID then
			KothTimerState[team] = {}
		end
	end)

	usermessage.Hook("TF_RemoveTimer", function()
		RoundTimerState.Reference = nil
		RoundTimerState.LastUpdated = nil
		RoundTimerState.Paused = nil
		RoundTimerState.IsSetup = nil
		RoundTimerState.IsWaiting = nil
	end)
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
end

function PANEL:PerformLayout()
	if not IsValid(LocalPlayer()) then return end

	if IsMvMMap() then
		self:SetPos(W / 2 - 55 * Scale, H - 40 * Scale)
		self:SetSize((TimerRes.bgX + TimerRes.bgW + 16) * Scale, 150 * Scale)
		return
	end

	if IsKothMap() then
		self:SetPos(W / 2 - 95 * Scale, 0)
		self:SetSize(190 * Scale, 150 * Scale)
		return
	end

	self:SetPos(W / 2 - 55 * Scale, 0)
	self:SetSize((TimerRes.bgX + TimerRes.bgW + 16) * Scale, 150 * Scale)
end

function PANEL:GetStateTime(state)
	if not state then return 0 end
	if state.Paused then
		return tonumber(state.Reference or 0) or 0
	end

	local ref = tonumber(state.Reference or 0) or 0
	local updated = tonumber(state.LastUpdated or CurTime()) or CurTime()
	return math.Clamp(ref - (CurTime() - updated), 0, math.huge)
end

function PANEL:GetTime()
	return self:GetStateTime(RoundTimerState)
end

function PANEL:GetFormattedTimeFromState(state)
	local sec = math.ceil(self:GetStateTime(state))
	local min = math.floor(sec / 60)
	sec = sec - 60 * min

	if sec < 10 then sec = "0" .. sec end
	return min .. ":" .. sec
end

function PANEL:GetFormattedTime()
	local sec = math.ceil(self:GetTime())

	if IsMvMMap() then
		return tostring(math.max(0, sec))
	end

	local min = math.floor(sec / 60)
	sec = sec - 60 * min

	if sec < 10 then sec = "0" .. sec end
	return min .. ":" .. sec
end

function PANEL:DrawTimerStateLabel(state, xOffset, allowOvertime)
	if state.IsSetup then
		surface.SetTexture(objectives_timepanel_suddendeath)
		surface.DrawTexturedRect((xOffset + TimerRes.stateX) * Scale, TimerRes.stateY * Scale, TimerRes.stateW * Scale, TimerRes.stateH * Scale)

		draw.Text{
			text = "Setup",
			font = "ClockSubText",
			pos = {(xOffset + TimerRes.stateX + TimerRes.stateW * 0.5) * Scale, (TimerRes.stateY + TimerRes.stateH * 0.5 + 1) * Scale},
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		}
	elseif state.IsWaiting then
		surface.SetTexture(objectives_timepanel_suddendeath)
		surface.DrawTexturedRect((xOffset + TimerRes.stateX) * Scale, TimerRes.stateY * Scale, TimerRes.stateW * Scale, TimerRes.stateH * Scale)

		draw.Text{
			text = "Waiting For Players",
			font = "ClockSubTextTiny",
			pos = {(xOffset + TimerRes.stateX + TimerRes.stateW * 0.5) * Scale, (TimerRes.stateY + TimerRes.stateH * 0.5 + 1) * Scale},
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		}
	elseif allowOvertime and not state.Paused and self:GetStateTime(state) <= 0 then
		surface.SetTexture(objectives_timepanel_suddendeath)
		surface.DrawTexturedRect((xOffset + TimerRes.stateX) * Scale, TimerRes.stateY * Scale, TimerRes.stateW * Scale, TimerRes.stateH * Scale)

		draw.Text{
			text = "OVERTIME",
			font = "ClockSubText",
			pos = {(xOffset + TimerRes.stateX + TimerRes.stateW * 0.5) * Scale, (TimerRes.stateY + TimerRes.stateH * 0.5 + 1) * Scale},
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		}
	end
end

function PANEL:DrawSingleTimer(state, teamIndex, xOffset, active)
	if not state or state.Reference == nil then return end

	local stateTime = self:GetStateTime(state)
	local lowTimePulse = 1
	if not state.IsSetup and not state.IsWaiting and stateTime > 0 and stateTime <= 10 then
		lowTimePulse = 0.72 + math.abs(math.sin(CurTime() * 8)) * 0.28
	end

	surface.SetDrawColor(255, 255, 255, 255)

	if active then
		local pulseElapsed = CurTime() - (KothHudAnim.PulseStart or 0)
		local pulseAlpha = 210 + math.max(0, 1 - math.min(pulseElapsed / 0.45, 1)) * 45
		surface.SetTexture(objectives_timepanel_active_bg)
		surface.SetDrawColor(255, 255, 255, pulseAlpha)
		surface.DrawTexturedRect(xOffset * Scale, KOTHRes.activeY * Scale, KOTHRes.activeW * Scale, KOTHRes.activeH * Scale)
		surface.SetDrawColor(255, 255, 255, 255)
	end

	self:DrawTimerStateLabel(state, xOffset, active or not IsKothMap())

	local tex = objectives_timepanel_bg[teamIndex] or objectives_timepanel_bg[1]
	surface.SetTexture(tex)
	surface.DrawTexturedRect((xOffset + TimerRes.bgX) * Scale, TimerRes.bgY * Scale, TimerRes.bgW * Scale, TimerRes.bgH * Scale)

	draw.Text{
		text = self:GetFormattedTimeFromState(state),
		font = "HudFontMediumSmall",
		pos = {(xOffset + TimerRes.timeX) * Scale, TimerRes.timeY * Scale},
		color = Color(Colors.TanLight.r, Colors.TanLight.g, Colors.TanLight.b, math.floor(255 * lowTimePulse)),
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}

	local progress = 1
	if state.Max and state.Max > 0 then
		progress = math.Clamp(math.ceil(self:GetStateTime(state)) / state.Max, 0, 1)
	end

	local bgcolor = Colors.HudTimerProgressInActive
	local fgcolor = Colors.HudTimerProgressActive
	if progress < 0.25 then
		fgcolor = Colors.HudTimerProgressWarning
	end
	fgcolor = Color(fgcolor.r, fgcolor.g, fgcolor.b, math.floor(255 * lowTimePulse))

	tf_draw.CircularProgressBar((xOffset + TimerRes.progressX) * Scale, TimerRes.progressY * Scale, TimerRes.progressW * Scale, TimerRes.progressH * Scale,
		objectives_timepanel_progressbar, objectives_timepanel_progressbar,
		fgcolor, bgcolor,
		progress
	)
end

function PANEL:Paint()
	if ShouldSuppressTimerHUD() then return end

	if IsKothMap() and not IsMvMMap() then
		local red = KothTimerState[TEAM_RED_ID]
		local blu = KothTimerState[TEAM_BLU_ID]
		local hasRed = red and red.Reference ~= nil
		local hasBlu = blu and blu.Reference ~= nil

		if hasRed or hasBlu then
			local activeTeam = TEAM_UNASSIGNED_ID
			if hasBlu and not blu.Paused then
				activeTeam = TEAM_BLU_ID
			end
			if hasRed and not red.Paused then
				activeTeam = TEAM_RED_ID
			end
			if activeTeam ~= KothHudAnim.ActiveTeam then
				KothHudAnim.ActiveTeam = activeTeam
				KothHudAnim.PulseStart = CurTime()
			end

			self:DrawSingleTimer(blu, TEAM_BLU_ID, KOTHRes.blueX, activeTeam == TEAM_BLU_ID)
			self:DrawSingleTimer(red, TEAM_RED_ID, KOTHRes.redX, activeTeam == TEAM_RED_ID)
			return
		end
	end

	if not RoundTimerState.Reference and not RoundTimerState.Paused then return end

	surface.SetDrawColor(255, 255, 255, 255)
	if RoundTimerState.IsSetup then
		surface.SetTexture(objectives_timepanel_suddendeath)
		surface.DrawTexturedRect(TimerRes.stateX * Scale, TimerRes.stateY * Scale, TimerRes.stateW * Scale, TimerRes.stateH * Scale)

		draw.Text{
			text = "Setup",
			font = "ClockSubText",
			pos = {(TimerRes.stateX + TimerRes.stateW * 0.5) * Scale, (TimerRes.stateY + TimerRes.stateH * 0.5 + 1) * Scale},
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		}
	elseif RoundTimerState.IsWaiting then
		surface.SetTexture(objectives_timepanel_suddendeath)
		surface.DrawTexturedRect(TimerRes.stateX * Scale, TimerRes.stateY * Scale, TimerRes.stateW * Scale, TimerRes.stateH * Scale)

		draw.Text{
			text = "Waiting For Players",
			font = "ClockSubTextTiny",
			pos = {(TimerRes.stateX + TimerRes.stateW * 0.5) * Scale, (TimerRes.stateY + TimerRes.stateH * 0.5 + 1) * Scale},
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		}
	end

	local t = LocalPlayer():Team()
	local tex = objectives_timepanel_bg[t] or objectives_timepanel_bg[1]

	surface.SetTexture(tex)
	surface.DrawTexturedRect(TimerRes.bgX * Scale, TimerRes.bgY * Scale, TimerRes.bgW * Scale, TimerRes.bgH * Scale)

	draw.Text{
		text = self:GetFormattedTime(),
		font = "HudFontMediumSmall",
		pos = {TimerRes.timeX * Scale, TimerRes.timeY * Scale},
		color = Colors.TanLight,
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}

	local progress = 1
	if RoundTimerState.Max and RoundTimerState.Max > 0 then
		progress = math.Clamp(math.ceil(self:GetTime()) / RoundTimerState.Max, 0, 1)
	end

	local bgcolor = Colors.HudTimerProgressInActive
	local fgcolor = Colors.HudTimerProgressActive

	if progress < 0.25 then
		fgcolor = Colors.HudTimerProgressWarning
	end

	tf_draw.CircularProgressBar(TimerRes.progressX * Scale, TimerRes.progressY * Scale, TimerRes.progressW * Scale, TimerRes.progressH * Scale,
		objectives_timepanel_progressbar, objectives_timepanel_progressbar,
		fgcolor, bgcolor,
		progress
	)
end

local HUD_OBJECTIVE_TIME_PANEL_CLASS = "TFHudObjectiveTimePanel"
vgui.Register(HUD_OBJECTIVE_TIME_PANEL_CLASS, PANEL, "DPanel")

local function EnsureHudObjectiveTimePanel()
	if IsValid(HudObjectiveTimePanel) then
		return HudObjectiveTimePanel
	end

	HudObjectiveTimePanel = vgui.Create(HUD_OBJECTIVE_TIME_PANEL_CLASS)
	return HudObjectiveTimePanel
end

if HudObjectiveTimePanel then HudObjectiveTimePanel:Remove() end
EnsureHudObjectiveTimePanel()

hook.Add("InitPostEntity", "TF_HudObjectiveTimePanel_InitPostEntity", function()
	EnsureHudObjectiveTimePanel()
end)

hook.Add("PostCleanupMap", "TF_HudObjectiveTimePanel_PostCleanupMap", function()
	timer.Simple(0, function()
		EnsureHudObjectiveTimePanel()
	end)
end)

hook.Add("Think", "TF_HudObjectiveTimePanel_EnsureAlive", function()
	if GetConVarNumber("cl_drawhud") == 0 then return end
	EnsureHudObjectiveTimePanel()
end)

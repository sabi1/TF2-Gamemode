
local PANEL = {}

local W = ScrW()
local H = ScrH()
local Scale = H/480

local objectives_timepanel_bg = {
	surface.GetTextureID("hud/objectives_timepanel_blue_bg"),
	surface.GetTextureID("hud/objectives_timepanel_red_bg"),
	surface.GetTextureID("hud/objectives_timepanel_blue_bg")
}
local objectives_timepanel_progressbar = surface.GetTextureID("hud/objectives_timepanel_progressbar")
local objectives_timepanel_suddendeath = surface.GetTextureID("hud/objectives_timepanel_suddendeath")

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

local RoundTimerState = {
	Reference = nil,
	LastUpdated = nil,
	Max = nil,
	IsSetup = nil,
	IsWaiting = nil,
	Paused = nil,
	HooksRegistered = false,
}

do
	local tree = TF2Res and TF2Res.Load and TF2Res.Load("resource/ui/hudobjectivetimepanel.res")
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
end
local function IsMvMMap()
	if TF_IsMvMMap then
		return TF_IsMvMMap()
	end
	return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
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
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
end

function PANEL:PerformLayout()
	if not IsValid(LocalPlayer()) then return end

	if IsMvMMap() then
		self:SetPos(W/2-55*Scale, H-40*Scale)
	else
		self:SetPos(W/2-55*Scale,0*Scale)
	end
	self:SetSize((TimerRes.bgX + TimerRes.bgW + 16)*Scale,150*Scale)
end

function PANEL:GetTime()
	if RoundTimerState.Paused then
		return RoundTimerState.Paused
	else
		local ref = RoundTimerState.Reference or 0
		local updated = RoundTimerState.LastUpdated or CurTime()
		return math.Clamp(ref - (CurTime() - updated), 0, math.huge)
	end
end

function PANEL:GetFormattedTime()
	local sec = math.ceil(self:GetTime())

	if IsMvMMap() then
		return tostring(math.max(0, sec))
	end

	local min = math.floor(sec/60)
	sec = sec - 60*min
	
	if sec<10 then sec = "0"..sec end
	return min..":"..sec
end

function PANEL:Paint()
	if not RoundTimerState.Reference and not RoundTimerState.Paused then return end
	
	surface.SetDrawColor(255,255,255,255)
	if RoundTimerState.IsSetup then
		surface.SetTexture(objectives_timepanel_suddendeath)
		surface.DrawTexturedRect(TimerRes.stateX*Scale, TimerRes.stateY*Scale, TimerRes.stateW*Scale, TimerRes.stateH*Scale)
		
		draw.Text{
			text="Setup",
			font="ClockSubText",
			pos={(TimerRes.stateX + TimerRes.stateW * 0.5)*Scale, (TimerRes.stateY + TimerRes.stateH * 0.5 + 1)*Scale},
			xalign=TEXT_ALIGN_CENTER,
			yalign=TEXT_ALIGN_CENTER,
		}
	elseif RoundTimerState.IsWaiting then
		surface.SetTexture(objectives_timepanel_suddendeath)
		surface.DrawTexturedRect(TimerRes.stateX*Scale, TimerRes.stateY*Scale, TimerRes.stateW*Scale, TimerRes.stateH*Scale)
		
		draw.Text{
			text="Waiting For Players",
			font="ClockSubTextTiny",
			pos={(TimerRes.stateX + TimerRes.stateW * 0.5)*Scale, (TimerRes.stateY + TimerRes.stateH * 0.5 + 1)*Scale},
			xalign=TEXT_ALIGN_CENTER,
			yalign=TEXT_ALIGN_CENTER,
		}
	end
	
	local t = LocalPlayer():Team()
	local tex = objectives_timepanel_bg[t] or objectives_timepanel_bg[1]
	
	surface.SetTexture(tex)
	surface.DrawTexturedRect(TimerRes.bgX*Scale, TimerRes.bgY*Scale, TimerRes.bgW*Scale, TimerRes.bgH*Scale)
	
	draw.Text{
		text=self:GetFormattedTime(),
		font="HudFontMediumSmall",
		pos={TimerRes.timeX*Scale, TimerRes.timeY*Scale},
		color=Colors.TanLight,
		xalign=TEXT_ALIGN_CENTER,
		yalign=TEXT_ALIGN_CENTER,
	}
	
	local progress = 1
	if RoundTimerState.Max and RoundTimerState.Max > 0 then
		progress = math.Clamp(math.ceil(self:GetTime()) / RoundTimerState.Max, 0, 1)
	end
	
	local bgcolor = Colors.HudTimerProgressInActive
	local fgcolor = Colors.HudTimerProgressActive
	
	if progress<0.25 then
		fgcolor = Colors.HudTimerProgressWarning
	end
	
	tf_draw.CircularProgressBar(TimerRes.progressX*Scale, TimerRes.progressY*Scale, TimerRes.progressW*Scale, TimerRes.progressH*Scale,
		objectives_timepanel_progressbar, objectives_timepanel_progressbar,
		fgcolor, bgcolor,
		progress
	)
end

if HudObjectiveTimePanel then HudObjectiveTimePanel:Remove() end
HudObjectiveTimePanel = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

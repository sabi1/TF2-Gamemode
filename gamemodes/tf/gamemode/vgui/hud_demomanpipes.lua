local PANEL = {}

local W = ScrW()
local H = ScrH()
local Scale = H/480

local ChargeMeterHigh = Color(155,221,149,255)
local ChargeMeterMedium = Color(244,175,11,255)
local ChargeMeterLow = Color(255,67,16,255)

local misc_ammo_area = {
	surface.GetTextureID("hud/misc_ammo_area_blue"),
	surface.GetTextureID("hud/misc_ammo_area_red"),
	surface.GetTextureID("hud/misc_ammo_area_blue"),
}

local ico_stickybomb = {
	surface.GetTextureID("hud/ico_stickybomb_blue"),
	surface.GetTextureID("hud/ico_stickybomb_red"),
	surface.GetTextureID("hud/ico_stickybomb_blue"),
}

local ico_stickybomb_faded = {
	surface.GetTextureID("hud/ico_stickybomb_blue_faded"),
	surface.GetTextureID("hud/ico_stickybomb_red_faded"),
	surface.GetTextureID("hud/ico_stickybomb_blue_faded"),
}

local ChargeLabel = {
	text="",
	font="TFFontSmall",
	pos={45.5*Scale, 34.5*Scale},
	xalign=TEXT_ALIGN_CENTER,
	yalign=TEXT_ALIGN_CENTER,
}

local NumPipes = {
	text="",
	font="HudFontMedium",
	pos={50*Scale, 28*Scale},
	color=Colors.TanLight,
	xalign=TEXT_ALIGN_LEFT,
	yalign=TEXT_ALIGN_CENTER,
}

local DemoRes = {
	panelX = 12,
	panelY = 6,
	panelW = 76,
	panelH = 38,
	chargeLabelX = 45.5,
	chargeLabelY = 34.5,
	chargeBarX = 25,
	chargeBarY = 23,
	chargeBarW = 40,
	chargeBarH = 6,
	iconX = 26,
	iconY = 16,
	iconW = 20,
	iconH = 20,
	numX = 50,
	numY = 28,
}

do
	local tree = TF2Res and TF2Res.Load and TF2Res.Load("resource/ui/huddemomanpipes.res")
	local bg = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "background")
	local chargeLabel = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "ChargeLabel")
	local chargeMeter = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "ChargeMeter")
	local pipeIcon = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "PipeIcon")
	local numPipes = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "NumPipesLabel")
	if bg and TF2Res.GetNumber then
		DemoRes.panelX = TF2Res.GetNumber(bg, "xpos", DemoRes.panelX)
		DemoRes.panelY = TF2Res.GetNumber(bg, "ypos", DemoRes.panelY)
		DemoRes.panelW = TF2Res.GetNumber(bg, "wide", DemoRes.panelW)
		DemoRes.panelH = TF2Res.GetNumber(bg, "tall", DemoRes.panelH)
		misc_ammo_area[1] = TF2Res.GetTextureID(bg, "image", "hud/misc_ammo_area_blue")
		misc_ammo_area[2] = TF2Res.GetTextureID(bg, "teambg_2", "hud/misc_ammo_area_red")
		misc_ammo_area[3] = TF2Res.GetTextureID(bg, "teambg_3", "hud/misc_ammo_area_blue")
	end
	if chargeLabel and TF2Res.GetNumber then
		DemoRes.chargeLabelX = TF2Res.GetNumber(chargeLabel, "xpos", 25) + TF2Res.GetNumber(chargeLabel, "wide", 41) * 0.5
		DemoRes.chargeLabelY = TF2Res.GetNumber(chargeLabel, "ypos", 27) + TF2Res.GetNumber(chargeLabel, "tall", 15) * 0.5
	end
	if chargeMeter and TF2Res.GetNumber then
		DemoRes.chargeBarX = TF2Res.GetNumber(chargeMeter, "xpos", DemoRes.chargeBarX)
		DemoRes.chargeBarY = TF2Res.GetNumber(chargeMeter, "ypos", DemoRes.chargeBarY)
		DemoRes.chargeBarW = TF2Res.GetNumber(chargeMeter, "wide", DemoRes.chargeBarW)
		DemoRes.chargeBarH = TF2Res.GetNumber(chargeMeter, "tall", DemoRes.chargeBarH)
	end
	if pipeIcon and TF2Res.GetNumber then
		DemoRes.iconX = TF2Res.GetNumber(pipeIcon, "xpos", DemoRes.iconX)
		DemoRes.iconY = TF2Res.GetNumber(pipeIcon, "ypos", DemoRes.iconY)
		DemoRes.iconW = TF2Res.GetNumber(pipeIcon, "wide", DemoRes.iconW)
		DemoRes.iconH = TF2Res.GetNumber(pipeIcon, "tall", DemoRes.iconH)
	end
	if numPipes and TF2Res.GetNumber then
		DemoRes.numX = TF2Res.GetNumber(numPipes, "xpos", DemoRes.numX)
		DemoRes.numY = TF2Res.GetNumber(numPipes, "ypos", DemoRes.numY) + TF2Res.GetNumber(numPipes, "tall", 20) * 0.5
	end

	ChargeLabel.pos = {DemoRes.chargeLabelX*Scale, DemoRes.chargeLabelY*Scale}
	NumPipes.pos = {DemoRes.numX*Scale, DemoRes.numY*Scale}
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
	self.Progress = 0
	self.MeterColor = Colors.Yellow
end

function PANEL:PerformLayout()
	self:SetPos(W-162*Scale,H-52*Scale)
	self:SetSize((DemoRes.panelX + DemoRes.panelW + 12)*Scale,(DemoRes.panelY + DemoRes.panelH + 6)*Scale)
end

function PANEL:SetChargeStatus(s)
	if s==1 then
		self.MeterColor = ChargeMeterHigh
	elseif s==2 then
		self.MeterColor = ChargeMeterMedium
	elseif s==3 then
		self.MeterColor = ChargeMeterLow
	else
		self.MeterColor = Colors.Yellow
	end
end

function PANEL:SetProgress(p)
	self.Progress = math.Clamp(p, 0, 1)
end

function PANEL:Paint()
	if not LocalPlayer():Alive() or GetConVar("tf_forcehl2hud"):GetBool() or GetConVarNumber("cl_drawhud")==0 then return end
	
	local vis_pipes = IsCustomHUDVisible("HudDemomanPipes")
	local vis_charge = IsCustomHUDVisible("HudDemomanCharge")
	local vis_cloak = IsCustomHUDVisible("HudSpyCloak")
	
	if not vis_pipes and not vis_charge and not vis_cloak then return end
	
	local t = LocalPlayer():Team()
	
	local tex = misc_ammo_area[t] or misc_ammo_area[1]
	surface.SetDrawColor(255,255,255,255)
	
	surface.SetTexture(tex)
	surface.DrawTexturedRect(DemoRes.panelX*Scale, DemoRes.panelY*Scale, DemoRes.panelW*Scale, DemoRes.panelH*Scale)
	
	if vis_pipes then
		local n = LocalPlayer():GetNWInt("NumBombs") or 0
		
		if n==0 then
			tex = ico_stickybomb_faded[t] or ico_stickybomb_faded[1]
			surface.SetTexture(tex)
		else
			tex = ico_stickybomb[t] or ico_stickybomb[1]
			surface.SetTexture(tex)
		end
		surface.DrawTexturedRect(DemoRes.iconX*Scale, DemoRes.iconY*Scale, DemoRes.iconW*Scale, DemoRes.iconH*Scale)
		
		NumPipes.text = n
		tf_draw.ShadedText(NumPipes)
	elseif vis_charge then
		ChargeLabel.text = tf_lang.GetRaw("#TF_Charge")
		draw.Text(ChargeLabel)
		
		surface.SetDrawColor(Colors.TransparentYellow)
		surface.DrawRect(DemoRes.chargeBarX*Scale, DemoRes.chargeBarY*Scale, DemoRes.chargeBarW*Scale, DemoRes.chargeBarH*Scale)
		
		if self.Progress > 0 then
			surface.SetDrawColor(self.MeterColor)
			surface.DrawRect(DemoRes.chargeBarX*Scale, DemoRes.chargeBarY*Scale, DemoRes.chargeBarW*Scale*self.Progress, DemoRes.chargeBarH*Scale)
		end
	elseif vis_cloak then
		ChargeLabel.text = "CLOAK"
		draw.Text(ChargeLabel)
		
		surface.SetDrawColor(Colors.TransparentYellow)
		surface.DrawRect(DemoRes.chargeBarX*Scale, DemoRes.chargeBarY*Scale, DemoRes.chargeBarW*Scale, DemoRes.chargeBarH*Scale)
		
		if self.Progress > 0 then
			surface.SetDrawColor(self.MeterColor)
			surface.DrawRect(DemoRes.chargeBarX*Scale, DemoRes.chargeBarY*Scale, DemoRes.chargeBarW*Scale*self.Progress, DemoRes.chargeBarH*Scale)
		end
	end
end

if HudDemomanPipes then HudDemomanPipes:Remove() end
HudDemomanPipes = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

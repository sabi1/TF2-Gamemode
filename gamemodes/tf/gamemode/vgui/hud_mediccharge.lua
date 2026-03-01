local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local medic_charge_bg = {
	surface.GetTextureID("hud/medic_charge_blue_bg"),
	surface.GetTextureID("hud/medic_charge_red_bg"),
	surface.GetTextureID("hud/medic_charge_blue_bg"),
}

local ico_health_cluster = surface.GetTextureID("hud/ico_health_cluster")

local MedicRes = {
	panelW = 130,
	panelH = 65,
	labelX = 30,
	labelY = 31,
	barX = 30,
	barY = 38,
	barW = 86,
	barH = 8,
	iconX = 2,
	iconY = 17,
	iconW = 36,
	iconH = 36,
}

do
	local tree = TF2Res and TF2Res.Load and TF2Res.Load("resource/ui/hudmediccharge.res")
	local bg = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "Background")
	local label = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "ChargeLabel")
	local meter = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "ChargeMeter")
	local icon = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "HealthClusterIcon")
	if bg and TF2Res.GetNumber then
		MedicRes.panelW = TF2Res.GetNumber(bg, "wide", MedicRes.panelW)
		MedicRes.panelH = TF2Res.GetNumber(bg, "tall", MedicRes.panelH)
		medic_charge_bg[1] = TF2Res.GetTextureID(bg, "image", "hud/medic_charge_blue_bg")
		medic_charge_bg[2] = TF2Res.GetTextureID(bg, "teambg_2", "hud/medic_charge_red_bg")
		medic_charge_bg[3] = TF2Res.GetTextureID(bg, "teambg_3", "hud/medic_charge_blue_bg")
	end
	if label and TF2Res.GetNumber then
		MedicRes.labelX = TF2Res.GetNumber(label, "xpos", MedicRes.labelX)
		MedicRes.labelY = TF2Res.GetNumber(label, "ypos", 24) + 7
	end
	if meter and TF2Res.GetNumber then
		MedicRes.barX = TF2Res.GetNumber(meter, "xpos", MedicRes.barX)
		MedicRes.barY = TF2Res.GetNumber(meter, "ypos", MedicRes.barY)
		MedicRes.barW = TF2Res.GetNumber(meter, "wide", MedicRes.barW)
		MedicRes.barH = TF2Res.GetNumber(meter, "tall", MedicRes.barH)
	end
	if icon and TF2Res.GetNumber then
		MedicRes.iconX = TF2Res.GetNumber(icon, "xpos", MedicRes.iconX)
		MedicRes.iconY = TF2Res.GetNumber(icon, "ypos", MedicRes.iconY)
		MedicRes.iconW = TF2Res.GetNumber(icon, "wide", MedicRes.iconW)
		MedicRes.iconH = TF2Res.GetNumber(icon, "tall", MedicRes.iconH)
		ico_health_cluster = TF2Res.GetTextureID(icon, "image", "hud/ico_health_cluster")
	end
end

local function LerpColor(r,a,b)
	return Color(
		Lerp(r,a.r,b.r),
		Lerp(r,a.g,b.g),
		Lerp(r,a.b,b.b),
		Lerp(r,a.a,b.a)
	)
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
end

function PANEL:PerformLayout()
	self:SetPos(W-138*Scale,H-69*Scale)
	self:SetSize((MedicRes.panelW + 70)*Scale,(MedicRes.panelH + 35)*Scale)
end

function PANEL:Paint()
	if not LocalPlayer():Alive() or GetConVar("tf_forcehl2hud"):GetBool() or GetConVarNumber("cl_drawhud")==0 then return end
	if not IsCustomHUDVisible("HudMedicCharge") then
		return
	end
	
	local n = LocalPlayer():GetNWInt("Ubercharge") or 0
	local t = LocalPlayer():Team()
	
	local tex = medic_charge_bg[t] or medic_charge_bg[1]
	surface.SetDrawColor(255,255,255,255)
	
	surface.SetTexture(tex)
	surface.DrawTexturedRect(0, 0, MedicRes.panelW*Scale, MedicRes.panelH*Scale)
	
	surface.SetTexture(ico_health_cluster)
	surface.DrawTexturedRect(MedicRes.iconX*Scale, MedicRes.iconY*Scale, MedicRes.iconW*Scale, MedicRes.iconH*Scale)
	
	local ubercolor
	if n>=100 then
		if not self.FullChargeTime then
			self.FullChargeTime = CurTime()
		end
		ubercolor = LerpColor(math.abs(math.cos(6*(CurTime()-self.FullChargeTime))), Colors.Black, Colors.Yellow)
	else
		self.FullChargeTime = nil
	end
	
	tf_lang.SetGlobal("charge", n)
	
	local param = {
		text=tf_lang.GetFormatted("TF_Ubercharge"),
		font="HudFontSmallest",
		pos={MedicRes.labelX*Scale, MedicRes.labelY*Scale},
		color=ubercolor or Colors.Yellow,
		xalign=TEXT_ALIGN_LEFT,
		yalign=TEXT_ALIGN_CENTER,
	}
	draw.Text(param)
	
	if ubercolor then
		surface.SetDrawColor(ubercolor)
		surface.DrawRect(30*Scale, 38*Scale, 86*Scale, 8*Scale)
	else
		surface.SetDrawColor(Colors.TransparentYellow)
		surface.DrawRect(MedicRes.barX*Scale, MedicRes.barY*Scale, MedicRes.barW*Scale, MedicRes.barH*Scale)
		
		surface.SetDrawColor(Colors.Yellow)
		surface.DrawRect(MedicRes.barX*Scale, MedicRes.barY*Scale, Lerp(n/100,0,MedicRes.barW)*Scale, MedicRes.barH*Scale)
	end
end

if HudMedicCharge then HudMedicCharge:Remove() end
HudMedicCharge = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

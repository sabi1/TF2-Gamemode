local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local BowRes = {
	x = 10,
	y = 0,
	w = 53,
	h = 6,
}

do
	local tree = TF2Res and TF2Res.Load and TF2Res.Load("resource/ui/hudbowcharge.res")
	local charge = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "ChargeMeter")
	if charge and TF2Res.GetNumber then
		BowRes.x = TF2Res.GetNumber(charge, "xpos", BowRes.x)
		BowRes.y = TF2Res.GetNumber(charge, "ypos", BowRes.y)
		BowRes.w = TF2Res.GetNumber(charge, "wide", BowRes.w)
		BowRes.h = TF2Res.GetNumber(charge, "tall", BowRes.h)
	end
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
	self.Progress = 0
end

function PANEL:PerformLayout()
	self:SetPos(W-(BowRes.w + 27)*Scale,H-(BowRes.h + 15)*Scale)
	self:SetSize((BowRes.w + 7)*Scale,(BowRes.h + 2)*Scale)
end

function PANEL:SetProgress(p)
	self.Progress = math.Clamp(p, 0, 1)
end

function PANEL:Paint()
	if not LocalPlayer():Alive() or GetConVar("tf_forcehl2hud"):GetBool() or GetConVarNumber("cl_drawhud")==0 then return end
	
	if not IsCustomHUDVisible("HudBowCharge") then
		return
	end
	
	surface.SetDrawColor(Colors.TransparentYellow)
	surface.DrawRect(BowRes.x*Scale, BowRes.y*Scale, BowRes.w*Scale, BowRes.h*Scale)
	
	if self.Progress > 0 then
		surface.SetDrawColor(Colors.Yellow)
		surface.DrawRect(BowRes.x*Scale, BowRes.y*Scale, BowRes.w*Scale*self.Progress, BowRes.h*Scale)
	end
end

if HudBowCharge then HudBowCharge:Remove() end
HudBowCharge = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

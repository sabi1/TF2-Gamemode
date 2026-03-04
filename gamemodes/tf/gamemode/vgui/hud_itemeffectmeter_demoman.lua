local PANEL = {}

local W = ScrW()
local H = ScrH()
local Scale = H/480

local misc_ammo_area = {
	surface.GetTextureID("hud/misc_ammo_area_blue"),
	surface.GetTextureID("hud/misc_ammo_area_red"),
	surface.GetTextureID("hud/misc_ammo_area_blue"),
}

local DemoRes = {
	panelX = "r162",
	panelY = "r92",
	panelW = 100,
	panelH = 50,
	bgX = 12,
	bgY = 0,
	bgW = 76,
	bgH = 42,
	labelX = 45.5,
	labelY = 34.5,
	countX = 45,
	countY = 15,
}

do
	local tree = TF2Res and TF2Res.Load and TF2Res.Load("resource/ui/huditemeffectmeter_demoman.res")
	local root = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "HudItemEffectMeter")
	local bg = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "ItemEffectMeterBG")
	local label = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "ItemEffectMeterLabel")
	local count = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "ItemEffectMeterCount")
	if root and TF2Res.GetString and TF2Res.GetNumber then
		DemoRes.panelX = TF2Res.GetString(root, "xpos", DemoRes.panelX)
		DemoRes.panelY = TF2Res.GetString(root, "ypos", DemoRes.panelY)
		DemoRes.panelW = TF2Res.GetNumber(root, "wide", DemoRes.panelW)
		DemoRes.panelH = TF2Res.GetNumber(root, "tall", DemoRes.panelH)
	end
	if bg and TF2Res.GetNumber then
		DemoRes.bgX = TF2Res.GetNumber(bg, "xpos", DemoRes.bgX)
		DemoRes.bgY = TF2Res.GetNumber(bg, "ypos", DemoRes.bgY)
		DemoRes.bgW = TF2Res.GetNumber(bg, "wide", DemoRes.bgW)
		DemoRes.bgH = TF2Res.GetNumber(bg, "tall", DemoRes.bgH)
		misc_ammo_area[1] = TF2Res.GetTextureID(bg, "image", "hud/misc_ammo_area_blue")
		misc_ammo_area[2] = TF2Res.GetTextureID(bg, "teambg_2", "hud/misc_ammo_area_red")
		misc_ammo_area[3] = TF2Res.GetTextureID(bg, "teambg_3", "hud/misc_ammo_area_blue")
	end
	if label and TF2Res.GetNumber then
		DemoRes.labelX = TF2Res.GetNumber(label, "xpos", 25) + TF2Res.GetNumber(label, "wide", 41) * 0.5
		DemoRes.labelY = TF2Res.GetNumber(label, "ypos", 22) + TF2Res.GetNumber(label, "tall", 15) * 0.5
	end
	if count and TF2Res.GetNumber then
		DemoRes.countX = TF2Res.GetNumber(count, "xpos", 25) + TF2Res.GetNumber(count, "wide", 40) * 0.5
		DemoRes.countY = TF2Res.GetNumber(count, "ypos", 5)
	end
end

local function resolveHudCoord(raw, axisSize, axisScale, fallback)
	if not isstring(raw) then
		return fallback
	end
	local v = string.Trim(raw)
	if v == "" then return fallback end
	local n = tonumber(v)
	if n ~= nil then
		return n * axisScale
	end
	local r = string.match(v, "^r([%+%-]?%d*%.?%d*)$")
	if r ~= nil then
		local offs = tonumber(r)
		if r == "" or offs == nil then offs = 0 end
		return axisSize - offs * axisScale
	end
	local c = string.match(v, "^c([%+%-]?%d*%.?%d*)$")
	if c ~= nil then
		local offs = tonumber(c)
		if c == "" or offs == nil then offs = 0 end
		return axisSize * 0.5 + offs * axisScale
	end
	return fallback
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
end

function PANEL:PerformLayout()
	W = ScrW()
	H = ScrH()
	Scale = H/480
	local x = resolveHudCoord(DemoRes.panelX, W, Scale, W-162*Scale)
	local y = resolveHudCoord(DemoRes.panelY, H, Scale, H-92*Scale)
	self:SetPos(x, y)
	self:SetSize(DemoRes.panelW*Scale, DemoRes.panelH*Scale)
end

function PANEL:Paint()
	if not LocalPlayer():Alive() or GetConVar("tf_forcehl2hud"):GetBool() or GetConVarNumber("cl_drawhud")==0 then return end
	
	if not IsCustomHUDVisible("HudItemEffectMeter_Demoman") then
		return
	end
	
	local n = LocalPlayer():GetNWInt("Heads")
	local t = LocalPlayer():Team()
	
	local tex = misc_ammo_area[t] or misc_ammo_area[1]
	surface.SetDrawColor(255,255,255,255)
	
	surface.SetTexture(tex)
	surface.DrawTexturedRect(DemoRes.bgX*Scale, DemoRes.bgY*Scale, DemoRes.bgW*Scale, DemoRes.bgH*Scale)
	
	draw.Text{
		text="HEADS",
		font="TFFontSmall",
		color=Colors.TanLight,
		pos={DemoRes.labelX*Scale, DemoRes.labelY*Scale},
		xalign=TEXT_ALIGN_CENTER,
		yalign=TEXT_ALIGN_CENTER,
	}
	
	draw.Text{
		text=n,
		font="HudFontMedium",
		color=Colors.TanLight,
		pos={DemoRes.countX*Scale, DemoRes.countY*Scale},
		xalign=TEXT_ALIGN_CENTER,
		yalign=TEXT_ALIGN_TOP,
	}
end

if HudItemEffectMeter_Demoman then HudItemEffectMeter_Demoman:Remove() end
HudItemEffectMeter_Demoman = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

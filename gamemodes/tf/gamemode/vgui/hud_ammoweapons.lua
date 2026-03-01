local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local ammo_bg = {
	surface.GetTextureID("hud/ammo_blue_bg"),
	surface.GetTextureID("hud/ammo_red_bg"),
	surface.GetTextureID("hud/ammo_blue_bg"),
}

local AmmoRes = {
	panelX = 0,
	panelY = 0,
	panelW = 90,
	panelH = 45,
	bgX = 2,
	bgY = 2,
	clipX = 58,
	clipY = 42,
	reserveX = 58,
	reserveY = 37,
	noClipX = 80,
	noClipY = 42,
}

do
	local tree = TF2Res and TF2Res.Load and TF2Res.Load("resource/ui/hudammoweapons.res")
	local bg = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "HudWeaponAmmoBG")
	local clip = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "AmmoInClip")
	local reserve = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "AmmoInReserve")
	local noclip = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "AmmoNoClip")
	if bg and TF2Res.GetNumber then
		AmmoRes.bgX = TF2Res.GetNumber(bg, "xpos", AmmoRes.bgX)
		AmmoRes.bgY = TF2Res.GetNumber(bg, "ypos", AmmoRes.bgY)
		AmmoRes.panelW = TF2Res.GetNumber(bg, "wide", AmmoRes.panelW)
		AmmoRes.panelH = TF2Res.GetNumber(bg, "tall", AmmoRes.panelH)
		ammo_bg[1] = TF2Res.GetTextureID(bg, "image", "hud/ammo_blue_bg")
		ammo_bg[2] = TF2Res.GetTextureID(bg, "teambg_2", "hud/ammo_red_bg")
		ammo_bg[3] = TF2Res.GetTextureID(bg, "teambg_3", "hud/ammo_blue_bg")
	end
	if clip and TF2Res.GetNumber then
		AmmoRes.clipX = TF2Res.GetNumber(clip, "xpos", AmmoRes.clipX) + TF2Res.GetNumber(clip, "wide", 55) - 1
		AmmoRes.clipY = TF2Res.GetNumber(clip, "ypos", 0) + TF2Res.GetNumber(clip, "tall", 40) + 2
	end
	if reserve and TF2Res.GetNumber then
		AmmoRes.reserveX = TF2Res.GetNumber(reserve, "xpos", AmmoRes.reserveX) - 1
		AmmoRes.reserveY = TF2Res.GetNumber(reserve, "ypos", 8) + TF2Res.GetNumber(reserve, "tall", 27) + 2
	end
	if noclip and TF2Res.GetNumber then
		AmmoRes.noClipX = TF2Res.GetNumber(noclip, "xpos", 0) + TF2Res.GetNumber(noclip, "wide", 84) - 4
		AmmoRes.noClipY = TF2Res.GetNumber(noclip, "ypos", 2) + TF2Res.GetNumber(noclip, "tall", 40)
	end
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
end

function PANEL:PerformLayout()
	self:SetPos(W-99*Scale,H-55*Scale)
	self:SetSize(AmmoRes.panelW * Scale, AmmoRes.panelH * Scale)
end

function PANEL:Paint()
	local w = LocalPlayer():GetActiveWeapon()
	
	if not LocalPlayer():Alive() or LocalPlayer():IsHL2() or GetConVar("tf_forcehl2hud"):GetBool() or GetConVarNumber("cl_drawhud")==0 or GAMEMODE.ShowScoreboard or not IsValid(w) or not w.Primary or string.lower(w.Primary.Ammo)=="none" then
		return
	end
	
	local ammo = w:Clip1()
	local reserve = w:Ammo1()
	
	local t = LocalPlayer():Team()
	local tbl = LocalPlayer():GetPlayerClassTable()

	if IsValid(LocalPlayer():GetObserverTarget()) and LocalPlayer():GetObserverTarget():IsPlayer() then
		local pl = LocalPlayer():GetObserverTarget()
		w = pl:GetActiveWeapon()
		ammo = w:Clip1()
		reserve = w:Ammo1()
		t = pl:Team()
		tbl = pl:GetPlayerClassTable()
	end
	
	local tex = ammo_bg[t] or ammo_bg[1]
	surface.SetTexture(tex)
	surface.SetDrawColor(255,255,255,255)
	surface.DrawTexturedRect(AmmoRes.bgX * Scale, AmmoRes.bgY * Scale, (AmmoRes.panelW-2)*Scale, (AmmoRes.panelH-2)*Scale)
	
	if w.Primary.ClipSize<0 then
		local param = {
			text=reserve,
			font="HudFontGiantBold",
			pos={AmmoRes.noClipX*Scale, AmmoRes.noClipY*Scale},
			color=Colors.Black,
			xalign=TEXT_ALIGN_RIGHT,
			yalign=TEXT_ALIGN_BOTTOM,
		}
		draw.Text(param)
		param.pos[1] = param.pos[1]-Scale
		param.pos[2] = param.pos[2]-Scale
		param.color=Colors.TanLight
		draw.Text(param)
	else
		local param = {
			text=ammo,
			font="HudFontGiantBold",
			pos={AmmoRes.clipX*Scale, AmmoRes.clipY*Scale},
			color=Colors.Black,
			xalign=TEXT_ALIGN_RIGHT,
			yalign=TEXT_ALIGN_BOTTOM,
		}
		draw.Text(param)
		param.pos[1] = param.pos[1]-Scale
		param.pos[2] = param.pos[2]-Scale
		param.color=Colors.TanLight
		draw.Text(param)
		
		param = {
			text=reserve,
			font="HudFontMediumSmall",
			pos={AmmoRes.reserveX*Scale, AmmoRes.reserveY*Scale},
			color=Colors.Black,
			xalign=TEXT_ALIGN_LEFT,
			yalign=TEXT_ALIGN_BOTTOM,
		}
		draw.Text(param)
		param.pos[1] = param.pos[1]-Scale
		param.pos[2] = param.pos[2]-Scale
		param.color=Colors.TanLight
		draw.Text(param)
	end
end

if HudAmmoWeapons then HudAmmoWeapons:Remove() end
HudAmmoWeapons = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

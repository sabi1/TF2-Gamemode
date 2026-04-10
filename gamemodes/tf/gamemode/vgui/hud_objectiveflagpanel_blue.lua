local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local objectives_flagpanel_bg_left = surface.GetTextureID("hud/objectives_flagpanel_bg_left")
local objectives_flagpanel_bg_right = surface.GetTextureID("hud/objectives_flagpanel_bg_right")
local objectives_flagpanel_bg_outline = surface.GetTextureID("hud/objectives_flagpanel_bg_outline")
local objectives_flagpanel_carried_outline = surface.GetTextureID("hud/objectives_flagpanel_carried_outline")
local objectives_flagpanel_carried_red = surface.GetTextureID("hud/objectives_flagpanel_carried_red")
local objectives_flagpanel_carried_blue = surface.GetTextureID("hud/objectives_flagpanel_carried_blue")
local objectives_flagpanel_bg_playingto = surface.GetTextureID("hud/objectives_flagpanel_bg_playingto")
local objectives_flagpanel_bg_mvm_bombcompass = surface.GetTextureID("hud/objectives_flagpanel_compass_grey")
local objectives_flagpanel_bg_mvm_bombdropped = surface.GetTextureID("hud/bomb_dropped")
local objectives_flagpanel_bg_mvm_bombcarried = surface.GetTextureID("hud/bomb_carried")

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
end

function PANEL:PerformLayout()
	self:SetPos(0,0)
	self:SetSize(W,H) 
end

function PANEL:Paint()
	-- Kept as a compatibility stub: the main CTF panel now draws both flag slots.
	return
end

if HudObjectiveFlagPanelBlue then HudObjectiveFlagPanelBlue:Remove() end
HudObjectiveFlagPanelBlue = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

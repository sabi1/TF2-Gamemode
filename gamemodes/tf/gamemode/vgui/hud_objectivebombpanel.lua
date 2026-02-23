local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

CreateConVar("hud_show_mvm_as_hl2", "1", {FCVAR_ARCHIVE}, "Show MVM hud as GMod Player")

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

local function IsMvMMap()
	return string.find(game.GetMap(), "mvm_", 1, true) ~= nil
end

local function GetBombEnt()
	local list = ents.FindByClass("item_teamflag_mvm")
	if not list or #list == 0 then return nil end
	return list[1]
end

local function GetBombTargetPos(bomb)
	if not IsValid(bomb) then return nil end

	local carrier = bomb:GetNWEntity("carrier")
	if IsValid(carrier) then
		return carrier:WorldSpaceCenter()
	end

	return bomb:WorldSpaceCenter()
end

local function GetNearestCaptureZone(pos)
	local best, bestDist
	for _, ent in ipairs(ents.FindByClass("func_capturezone")) do
		if IsValid(ent) then
			local dist = ent:GetPos():DistToSqr(pos)
			if not bestDist or dist < bestDist then
				best = ent
				bestDist = dist
			end
		end
	end
	return best
end

local function DrawSimpleBar(x, y, w, h, frac, bg, fg)
	frac = math.Clamp(frac or 0, 0, 1)
	surface.SetDrawColor(bg.r, bg.g, bg.b, bg.a)
	surface.DrawRect(x, y, w, h)

	surface.SetDrawColor(fg.r, fg.g, fg.b, fg.a)
	surface.DrawRect(x + 2, y + 2, math.max(0, (w - 4) * frac), h - 4)
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
	self.BombStartPos = nil
	self.BombTargetPos = nil
	self.BombStartDist = nil
end

function PANEL:PerformLayout()
	self:SetPos(0,0)
	self:SetSize(W,H)
end

function PANEL:Paint()
	local param

	if not LocalPlayer():Alive() or (LocalPlayer():IsHL2() and not GetConVar("hud_show_mvm_as_hl2"):GetBool()) or GetConVar("tf_forcehl2hud"):GetBool() or GetConVarNumber("cl_drawhud")==0 or GAMEMODE.ShowScoreboard or not IsMvMMap() then return end
	
	surface.SetDrawColor(255,255,255,255)
	
	surface.SetTexture(objectives_flagpanel_bg_left)
	surface.DrawTexturedRect(320*WScale-140*Scale, (480-75)*Scale, 280*Scale, 80*Scale)
	
	surface.SetTexture(objectives_flagpanel_bg_right)
	surface.DrawTexturedRect(320*WScale-140*Scale, (480-75)*Scale, 280*Scale, 80*Scale)
	
	surface.SetTexture(objectives_flagpanel_bg_outline)
	surface.DrawTexturedRect(320*WScale-140*Scale, (480-75)*Scale, 280*Scale, 80*Scale)
	
	surface.SetTexture(objectives_flagpanel_bg_playingto)
	surface.DrawTexturedRect(320*WScale-75*Scale, (480-31)*Scale, 150*Scale, 38*Scale)
	
	local compassAngle = 0
	local compassCenterX = (340 * WScale) - (6 * Scale)
	local compassCenterY = (485 - 68) * Scale

	
	for k,v in pairs(ents.FindByClass("item_teamflag_mvm")) do
		if IsValid(v:GetNWEntity("carrier")) then
			surface.SetTexture(objectives_flagpanel_bg_mvm_bombcarried)
			surface.DrawTexturedRect(340*WScale-50*Scale, (480-89)*Scale, 52*Scale, 52*Scale)
		else
			surface.SetTexture(objectives_flagpanel_bg_mvm_bombdropped)
			surface.DrawTexturedRect(340*WScale-50*Scale, (480-89)*Scale, 52*Scale, 52*Scale)
		end
	end
				
	param = {
		text = "BOMB STATUS",
		font = "HudFontSmall",
		pos = {320*WScale, (480-28+15)*Scale},
		color = Colors.TanLight,
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}
	draw.Text(param)

	local bomb = GetBombEnt()
	if IsValid(bomb) then
		local bombPos = bomb:GetPos()
		local bombTargetPos = GetBombTargetPos(bomb)

		if bombTargetPos then
			local vecBomb = bombTargetPos - LocalPlayer():GetPos()
			vecBomb.z = 0
			if vecBomb:LengthSqr() > 0 then
				vecBomb:Normalize()
				local forward = LocalPlayer():EyeAngles():Forward()
				local right = LocalPlayer():EyeAngles():Right()
				forward.z = 0
				right.z = 0
				forward:Normalize()
				right:Normalize()

				local dot = math.Clamp(vecBomb:Dot(forward), -1, 1)
				local angleBetween = math.acos(dot)
				dot = vecBomb:Dot(right)
				if dot < 0.0 then
					angleBetween = angleBetween * -1
				end

				compassAngle = -1 * (math.deg(angleBetween) or 0)
			end
		end

		if not self.BombStartPos then
			self.BombStartPos = bombPos
		end

		if not self.BombTargetPos then
			local zone = GetNearestCaptureZone(self.BombStartPos)
			if IsValid(zone) then
				self.BombTargetPos = zone:GetPos()
				self.BombStartDist = math.max(1, self.BombStartPos:Distance(self.BombTargetPos))
			end
		end

		local progress = 0
		if self.BombTargetPos and self.BombStartDist then
			local remaining = bombPos:Distance(self.BombTargetPos)
			progress = 1 - math.Clamp(remaining / self.BombStartDist, 0, 1)
		end

		local barW = 260 * Scale
		local barH = 20 * Scale
		local barX = (W / 2) - (barW / 2)
		local barY = 12 * Scale
		DrawSimpleBar(barX, barY, barW, barH, progress, Color(40, 40, 40, 220), Color(111, 161, 197, 245))
	end

	surface.SetTexture(objectives_flagpanel_bg_mvm_bombcompass)
	surface.DrawTexturedRectRotated(compassCenterX, compassCenterY, 104 * Scale, 104 * Scale, compassAngle)
end

if HudObjectiveBombPanel then HudObjectiveBombPanel:Remove() end
HudObjectiveBombPanel = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

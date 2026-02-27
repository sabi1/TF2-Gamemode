local PANEL = {}

local TRAIN_STATE_STOPPED = 0
local TRAIN_STATE_FORWARD = 1
local TRAIN_STATE_BLOCKED = 2
local TRAIN_STATE_RECEDING = 3

CreateConVar("tf_payload_hud_override", "0", {FCVAR_ARCHIVE}, "Allow payload objective HUD while tf_forcehl2hud is enabled.")

local COLOR_WHITE_FALLBACK = Color(255, 255, 255, 255)

local TEX = {
	track_neutral = surface.GetTextureID("hud/cart_track"),
	track_neutral_opaque = surface.GetTextureID("hud/cart_track_neutral_opaque"),
	track_blue = surface.GetTextureID("hud/cart_track_blue"),
	track_blue_opaque = surface.GetTextureID("hud/cart_track_blue_opaque"),
	track_red = surface.GetTextureID("hud/cart_track_red"),
	track_red_opaque = surface.GetTextureID("hud/cart_track_red_opaque"),

	cart_blue = surface.GetTextureID("hud/cart_blue"),
	cart_blue_bottom = surface.GetTextureID("hud/cart_blue_bottom"),
	cart_red = surface.GetTextureID("hud/cart_red"),
	cart_red_bottom = surface.GetTextureID("hud/cart_red_bottom"),
	cart_neutral = surface.GetTextureID("hud/cart_neutral"),
	cart_neutral_bottom = surface.GetTextureID("hud/cart_neutral_bottom"),

	point_blue = surface.GetTextureID("hud/cart_point_blue"),
	point_blue_opaque = surface.GetTextureID("hud/cart_point_blue_opaque"),
	point_red = surface.GetTextureID("hud/cart_point_red"),
	point_red_opaque = surface.GetTextureID("hud/cart_point_red_opaque"),
	point_neutral = surface.GetTextureID("hud/cart_point_neutral"),
	point_neutral_opaque = surface.GetTextureID("hud/cart_point_neutral_opaque"),

	home_blue = surface.GetTextureID("hud/cart_home_blue_square"),
	home_red = surface.GetTextureID("hud/cart_home_red_square"),

	arrow_left = surface.GetTextureID("hud/cart_arrow_left"),
	arrow_right = surface.GetTextureID("hud/cart_arrow_right"),
	blocked = surface.GetTextureID("hud/cart_blocked"),
	alert = surface.GetTextureID("hud/cart_alert"),
	cart_icon = surface.GetTextureID("hud/cart_icon"),
}

local function DrawTexture(tex, x, y, w, h, color)
	if not tex or tex <= 0 then return false end

	local c = color
	if not c or not istable(c) then
		c = COLOR_WHITE_FALLBACK
	end

	surface.SetDrawColor(
		tonumber(c.r) or tonumber(c[1]) or 255,
		tonumber(c.g) or tonumber(c[2]) or 255,
		tonumber(c.b) or tonumber(c[3]) or 255,
		tonumber(c.a) or tonumber(c[4]) or 255
	)
	surface.SetTexture(tex)
	surface.DrawTexturedRect(x, y, w, h)
	return true
end

local function ShouldDrawPayloadHUD()
	if not GAMEMODE then return false end
	if GetConVarNumber("cl_drawhud") == 0 then return false end
	if GAMEMODE.ShowScoreboard then return false end

	local forceHL2 = GetConVar("tf_forcehl2hud")
	local override = GetConVar("tf_payload_hud_override")
	if forceHL2 and forceHL2:GetBool() and not (override and override:GetBool()) then
		return false
	end

	return GAMEMODE.PayloadHUDActive and GAMEMODE.PayloadState ~= nil
end

local function TeamTrackTexture(teamNum, opaque)
	if teamNum == (TEAM_BLU or 3) then
		return opaque and TEX.track_blue_opaque or TEX.track_blue
	end
	if teamNum == (TEAM_RED or 2) then
		return opaque and TEX.track_red_opaque or TEX.track_red
	end
	return opaque and TEX.track_neutral_opaque or TEX.track_neutral
end

local function TeamPointTexture(teamNum, opaque)
	if teamNum == (TEAM_BLU or 3) then
		return opaque and TEX.point_blue_opaque or TEX.point_blue
	end
	if teamNum == (TEAM_RED or 2) then
		return opaque and TEX.point_red_opaque or TEX.point_red
	end
	return opaque and TEX.point_neutral_opaque or TEX.point_neutral
end

local function TeamHomeTexture(teamNum)
	if teamNum == (TEAM_BLU or 3) then return TEX.home_blue end
	if teamNum == (TEAM_RED or 2) then return TEX.home_red end
	return TEX.point_neutral
end

local function TeamCartTexture(teamNum)
	if teamNum == (TEAM_BLU or 3) then return TEX.cart_blue, TEX.cart_blue_bottom end
	if teamNum == (TEAM_RED or 2) then return TEX.cart_red, TEX.cart_red_bottom end
	return TEX.cart_neutral, TEX.cart_neutral_bottom
end

local function DefenderTeam(attackTeam)
	local blu = TEAM_BLU or 3
	local red = TEAM_RED or 2
	if attackTeam == red then return blu end
	return red
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
end

function PANEL:PerformLayout()
	self:SetPos(0, 0)
	self:SetSize(ScrW(), ScrH())
end

function PANEL:GetStatusText(state)
	if state.goal then
		return "DELIVERED", Color(230, 210, 130, 255)
	end
	if state.inOvertime then
		return "OVERTIME", Color(255, 150, 80, 255)
	end
	if state.blocked or state.trainState == TRAIN_STATE_BLOCKED then
		return "BLOCKED", Color(245, 105, 95, 255)
	end
	if state.trainState == TRAIN_STATE_RECEDING then
		return "RECEDING", Color(228, 182, 110, 255)
	end
	if state.trainState == TRAIN_STATE_FORWARD then
		return "PUSHING", Color(132, 194, 255, 255)
	end
	return "STOPPED", Color(220, 220, 220, 255)
end

function PANEL:DrawPayloadTrack(state, x, y, w, h, scale)
	local attackTeam = tonumber(state.attackTeam) or TEAM_BLU or 3
	local defendTeam = DefenderTeam(attackTeam)
	local progress = math.Clamp(tonumber(state.progress) or 0, 0, 1)

	if not DrawTexture(TeamTrackTexture(0, true), x, y, w, h) then
		draw.RoundedBox(6 * scale, x, y + 6 * scale, w, h - 12 * scale, Color(72, 66, 58, 220))
	end

	local attackTrack = TeamTrackTexture(attackTeam, false)
	if attackTrack and attackTrack > 0 and progress > 0 then
		local clipLeft = math.floor(x)
		local clipRight = math.floor(x + w * progress)
		if clipRight > clipLeft then
			render.SetScissorRect(clipLeft, math.floor(y), clipRight, math.floor(y + h), true)
			DrawTexture(attackTrack, x, y, w, h)
			render.SetScissorRect(0, 0, 0, 0, false)
		end
	end

	local iconSize = 18 * scale
	local pointSize = 18 * scale
	local markerY = y + (h * 0.5) - (pointSize * 0.5)

	DrawTexture(TeamHomeTexture(attackTeam), x - (iconSize * 0.70), y + (h * 0.5) - (iconSize * 0.5), iconSize, iconSize)
	DrawTexture(TeamPointTexture(defendTeam, true), x + w - (iconSize * 0.30), y + (h * 0.5) - (iconSize * 0.5), iconSize, iconSize)

	for _, frac in ipairs(state.checkpointProgress or {}) do
		frac = math.Clamp(tonumber(frac) or 0, 0, 1)
		local markerX = x + frac * w - (pointSize * 0.5)
		local markerTeam = (progress >= frac) and attackTeam or 0
		if not DrawTexture(TeamPointTexture(markerTeam, true), markerX, markerY, pointSize, pointSize) then
			draw.RoundedBox(pointSize * 0.5, markerX, markerY, pointSize, pointSize, Color(220, 220, 220, 240))
		end
	end

	local cartTex, cartBottomTex = TeamCartTexture(attackTeam)
	local cartSize = 22 * scale
	local cartX = x + (w * progress) - (cartSize * 0.5)
	local cartY = y + (h * 0.5) - (cartSize * 0.5)

	DrawTexture(cartBottomTex, cartX, cartY + 2 * scale, cartSize, cartSize)
	if not DrawTexture(cartTex, cartX, cartY, cartSize, cartSize) then
		draw.RoundedBox(4 * scale, cartX, cartY, cartSize, cartSize, Color(141, 189, 255, 255))
	end

	if state.blocked or state.trainState == TRAIN_STATE_BLOCKED then
		DrawTexture(TEX.blocked, cartX + cartSize * 0.15, cartY - 12 * scale, 12 * scale, 12 * scale)
	elseif state.trainState == TRAIN_STATE_RECEDING then
		DrawTexture(TEX.arrow_left, cartX - 10 * scale, cartY + 2 * scale, 10 * scale, 10 * scale)
	elseif state.trainState == TRAIN_STATE_FORWARD then
		DrawTexture(TEX.arrow_right, cartX + cartSize, cartY + 2 * scale, 10 * scale, 10 * scale)
	end

	if state.inOvertime and math.floor(CurTime() * 3) % 2 == 0 then
		DrawTexture(TEX.alert, x + w * 0.5 - 7 * scale, y - 14 * scale, 14 * scale, 14 * scale)
	end
end

function PANEL:Paint()
	if not ShouldDrawPayloadHUD() then return end

	local state = GAMEMODE.PayloadState or {}
	local w, h = ScrW(), ScrH()
	local scale = h / 480

	local trackW = 250 * scale
	local trackH = 16 * scale
	local trackX = (w - trackW) * 0.5
	local trackY = h - (32 * scale)

	self:DrawPayloadTrack(state, trackX, trackY, trackW, trackH, scale)

	local statusText, statusColor = self:GetStatusText(state)
	draw.Text({
		text = statusText,
		font = "HudFontSmall",
		pos = {w * 0.5, trackY - 11 * scale},
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
		color = statusColor,
	})

	local cappers = math.max(tonumber(state.cappers) or 0, 0)
	draw.Text({
		text = tostring(cappers),
		font = "HudFontSmall",
		pos = {trackX + trackW + 14 * scale, trackY + 8 * scale},
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
		color = Color(235, 235, 235, 255),
	})

	if state.canRecede and not state.blocked and cappers <= 0 and (state.recedeRemaining or 0) > 0 then
		draw.Text({
			text = string.format("%.1f", math.max(tonumber(state.recedeRemaining) or 0, 0)),
			font = "HudFontSmall",
			pos = {trackX - 10 * scale, trackY + 8 * scale},
			xalign = TEXT_ALIGN_RIGHT,
			yalign = TEXT_ALIGN_CENTER,
			color = Color(230, 200, 140, 255),
		})
	end
end

if HudPayloadPanel then HudPayloadPanel:Remove() end
HudPayloadPanel = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

local PANEL = {}

local TRAIN_STATE_STOPPED = 0
local TRAIN_STATE_FORWARD = 1
local TRAIN_STATE_BLOCKED = 2
local TRAIN_STATE_RECEDING = 3

CreateConVar("tf_payload_hud_override", "0", {FCVAR_ARCHIVE}, "Allow payload objective HUD while tf_forcehl2hud is enabled.")

local COLOR_WHITE = Color(255, 255, 255, 255)
local COLOR_TRACK_EDGE = Color(245, 229, 196, 210)
local COLOR_TEXT = Color(235, 235, 235, 255)
local COLOR_BLOCKED = Color(245, 105, 95, 255)
local COLOR_OVERTIME = Color(255, 150, 80, 255)
local COLOR_RECEDE = Color(228, 182, 110, 255)

local TEX = {
	track_neutral = surface.GetTextureID("hud/cart_track"),
	track_neutral_opaque = surface.GetTextureID("hud/cart_track_neutral_opaque"),
	track_blue = surface.GetTextureID("hud/cart_track_blue"),
	track_blue_opaque = surface.GetTextureID("hud/cart_track_blue_opaque"),
	track_red = surface.GetTextureID("hud/cart_track_red"),
	track_red_opaque = surface.GetTextureID("hud/cart_track_red_opaque"),
	point_blue = surface.GetTextureID("hud/cart_point_blue"),
	point_blue_opaque = surface.GetTextureID("hud/cart_point_blue_opaque"),
	point_red = surface.GetTextureID("hud/cart_point_red"),
	point_red_opaque = surface.GetTextureID("hud/cart_point_red_opaque"),
	point_neutral = surface.GetTextureID("hud/cart_point_neutral"),
	point_neutral_opaque = surface.GetTextureID("hud/cart_point_neutral_opaque"),
	home_blue = surface.GetTextureID("hud/cart_home_blue"),
	home_blue_square = surface.GetTextureID("hud/cart_home_blue_square"),
	home_red = surface.GetTextureID("hud/cart_home_red"),
	home_red_square = surface.GetTextureID("hud/cart_home_red_square"),
	cart_blue = surface.GetTextureID("hud/cart_blue"),
	cart_blue_bottom = surface.GetTextureID("hud/cart_blue_bottom"),
	cart_red = surface.GetTextureID("hud/cart_red"),
	cart_red_bottom = surface.GetTextureID("hud/cart_red_bottom"),
	cart_neutral = surface.GetTextureID("hud/cart_neutral"),
	cart_neutral_bottom = surface.GetTextureID("hud/cart_neutral_bottom"),
	arrow_left = surface.GetTextureID("hud/cart_arrow_left"),
	track_arrow = surface.GetTextureID("hud/cart_track_arrow"),
	blocked = surface.GetTextureID("hud/cart_blocked"),
	alert = surface.GetTextureID("hud/cart_alert"),
	cap_player = surface.GetTextureID("capture_icon_white"),
}

local EscortResCache = nil

local function DrawTexture(tex, x, y, w, h, color)
	if not tex or tex <= 0 then return false end
	color = color or COLOR_WHITE
	surface.SetDrawColor(color.r or 255, color.g or 255, color.b or 255, color.a or 255)
	surface.SetTexture(tex)
	surface.DrawTexturedRect(x, y, w, h)
	return true
end

local function DrawTextureUV(tex, x, y, w, h, u0, v0, u1, v1, color)
	if not tex or tex <= 0 then return false end
	color = color or COLOR_WHITE
	surface.SetDrawColor(color.r or 255, color.g or 255, color.b or 255, color.a or 255)
	surface.SetTexture(tex)
	surface.DrawTexturedRectUV(x, y, w, h, u0, v0, u1, v1)
	return true
end

local function ResolveToken(token)
	if not isstring(token) then return "" end
	if language and language.GetPhrase and string.StartWith(token, "#") then
		local phrase = language.GetPhrase(string.sub(token, 2))
		if phrase and phrase ~= "" and phrase ~= token then
			return phrase
		end
	end
	return token
end

local function ResolveTokenWithFallback(token, fallback)
	local resolved = ResolveToken(token)
	if resolved == token and string.StartWith(token or "", "#") then
		return fallback or ""
	end
	return resolved
end

local function GetNodeChildByKey(node, keyName)
	if not istable(node) or not istable(node.children) then return nil end
	local needle = string.lower(tostring(keyName or ""))
	for _, child in ipairs(node.children) do
		if isstring(child.key) and string.lower(child.key) == needle then
			return child
		end
	end
	return nil
end

local function BuildEscortLayout()
	if not (TF2Res and TF2Res.Load and TF2Res.GetRect and TF2Res.FindByFieldName and TF2Res.FindByKey) then
		return nil
	end

	local escortTree = TF2Res.Load("resource/ui/objectivestatusescort.res")
	local multiTree = TF2Res.Load("resource/ui/objectivestatusmultipleescort.res")
	if not escortTree or not multiTree then
		return nil
	end

	local escortRoot = TF2Res.FindByFieldName(escortTree, "ObjectiveStatusEscort")
	local multiRoot = TF2Res.FindByFieldName(multiTree, "ObjectiveStatusMultipleEscort")
	local bluePanel = TF2Res.FindByFieldName(multiTree, "BlueEscortPanel")
	local redPanel = TF2Res.FindByFieldName(multiTree, "RedEscortPanel")
	local levelBar = TF2Res.FindByFieldName(escortTree, "LevelBar")
	local progressBar = TF2Res.FindByFieldName(escortTree, "ProgressBar")
	local homeIcon = TF2Res.FindByFieldName(escortTree, "HomeCPIcon")
	local cpTemplate = TF2Res.FindByFieldName(escortTree, "SimpleControlPointTemplate")
	local itemPanel = TF2Res.FindByFieldName(escortTree, "EscortItemPanel")
	local recedeTime = TF2Res.FindByFieldName(escortTree, "RecedeTime")
	local escortImage = TF2Res.FindByFieldName(escortTree, "EscortItemImage")
	local escortImageBottom = TF2Res.FindByFieldName(escortTree, "EscortItemImageBottom")
	local escortAlert = TF2Res.FindByFieldName(escortTree, "EscortItemImageAlert")
	local speedBack = TF2Res.FindByFieldName(escortTree, "Speed_Backwards")
	local capPlayer = TF2Res.FindByFieldName(escortTree, "CapPlayerImage")
	local capNum = TF2Res.FindByFieldName(escortTree, "CapNumPlayers")
	local blocked = TF2Res.FindByFieldName(escortTree, "Blocked")

	local ifMultipleEscortRoot = escortRoot and GetNodeChildByKey(escortRoot, "if_multiple_trains") or nil
	local ifBlueTop = bluePanel and GetNodeChildByKey(bluePanel, "if_blue_is_top") or nil
	local ifRedTop = redPanel and GetNodeChildByKey(redPanel, "if_red_is_top") or nil

	local ifMultipleLevelBar = levelBar and GetNodeChildByKey(levelBar, "if_multiple_trains") or nil
	local ifMultipleHome = homeIcon and GetNodeChildByKey(homeIcon, "if_multiple_trains") or nil
	local ifMultipleCP = cpTemplate and GetNodeChildByKey(cpTemplate, "if_multiple_trains") or nil
	local ifMultipleItemPanel = itemPanel and GetNodeChildByKey(itemPanel, "if_multiple_trains") or nil
	local ifMultipleRecede = recedeTime and GetNodeChildByKey(recedeTime, "if_multiple_trains") or nil
	local ifMultipleRecedeTop = recedeTime and GetNodeChildByKey(recedeTime, "if_multiple_trains_top") or nil
	local ifMultipleRecedeBottom = recedeTime and GetNodeChildByKey(recedeTime, "if_multiple_trains_bottom") or nil
	local ifMultipleEscortImage = escortImage and GetNodeChildByKey(escortImage, "if_multiple_trains") or nil
	local ifMultipleEscortImageBottom = escortImageBottom and GetNodeChildByKey(escortImageBottom, "if_multiple_trains") or nil
	local ifMultipleAlertBottom = escortAlert and GetNodeChildByKey(escortAlert, "if_multiple_trains_bottom") or nil
	local ifMultipleSpeed = speedBack and GetNodeChildByKey(speedBack, "if_multiple_trains") or nil
	local ifMultipleSpeedTop = speedBack and GetNodeChildByKey(speedBack, "if_multiple_trains_top") or nil
	local ifMultipleSpeedBottom = speedBack and GetNodeChildByKey(speedBack, "if_multiple_trains_bottom") or nil
	local ifMultipleCapPlayer = capPlayer and GetNodeChildByKey(capPlayer, "if_multiple_trains") or nil
	local ifMultipleCapPlayerTop = capPlayer and GetNodeChildByKey(capPlayer, "if_multiple_trains_top") or nil
	local ifMultipleCapPlayerBottom = capPlayer and GetNodeChildByKey(capPlayer, "if_multiple_trains_bottom") or nil
	local ifMultipleCapNum = capNum and GetNodeChildByKey(capNum, "if_multiple_trains") or nil
	local ifMultipleCapNumTop = capNum and GetNodeChildByKey(capNum, "if_multiple_trains_top") or nil
	local ifMultipleCapNumBottom = capNum and GetNodeChildByKey(capNum, "if_multiple_trains_bottom") or nil
	local ifMultipleBlocked = blocked and GetNodeChildByKey(blocked, "if_multiple_trains") or nil
	local ifMultipleBlockedTop = blocked and GetNodeChildByKey(blocked, "if_multiple_trains_top") or nil
	local ifMultipleBlockedBottom = blocked and GetNodeChildByKey(blocked, "if_multiple_trains_bottom") or nil

	return {
		escortRoot = escortRoot,
		multiRoot = multiRoot,
		bluePanel = bluePanel,
		redPanel = redPanel,
		levelBar = levelBar,
		progressBar = progressBar,
		homeIcon = homeIcon,
		cpTemplate = cpTemplate,
		itemPanel = itemPanel,
		recedeTime = recedeTime,
		escortImage = escortImage,
		escortImageBottom = escortImageBottom,
		escortAlert = escortAlert,
		speedBack = speedBack,
		capPlayer = capPlayer,
		capNum = capNum,
		blocked = blocked,
		ifMultipleEscortRoot = ifMultipleEscortRoot,
		ifBlueTop = ifBlueTop,
		ifRedTop = ifRedTop,
		ifMultipleLevelBar = ifMultipleLevelBar,
		ifMultipleHome = ifMultipleHome,
		ifMultipleCP = ifMultipleCP,
		ifMultipleItemPanel = ifMultipleItemPanel,
		ifMultipleRecede = ifMultipleRecede,
		ifMultipleRecedeTop = ifMultipleRecedeTop,
		ifMultipleRecedeBottom = ifMultipleRecedeBottom,
		ifMultipleEscortImage = ifMultipleEscortImage,
		ifMultipleEscortImageBottom = ifMultipleEscortImageBottom,
		ifMultipleAlertBottom = ifMultipleAlertBottom,
		ifMultipleSpeed = ifMultipleSpeed,
		ifMultipleSpeedTop = ifMultipleSpeedTop,
		ifMultipleSpeedBottom = ifMultipleSpeedBottom,
		ifMultipleCapPlayer = ifMultipleCapPlayer,
		ifMultipleCapPlayerTop = ifMultipleCapPlayerTop,
		ifMultipleCapPlayerBottom = ifMultipleCapPlayerBottom,
		ifMultipleCapNum = ifMultipleCapNum,
		ifMultipleCapNumTop = ifMultipleCapNumTop,
		ifMultipleCapNumBottom = ifMultipleCapNumBottom,
		ifMultipleBlocked = ifMultipleBlocked,
		ifMultipleBlockedTop = ifMultipleBlockedTop,
		ifMultipleBlockedBottom = ifMultipleBlockedBottom,
	}
end

local function GetEscortResLayout()
	if EscortResCache == nil then
		EscortResCache = BuildEscortLayout() or false
	end
	return EscortResCache ~= false and EscortResCache or nil
end

local function GetNodeRect(node, parentW, parentH, defaults)
	if not (node and TF2Res and TF2Res.GetRect) then
		return table.Copy(defaults or { x = 0, y = 0, w = 0, h = 0 })
	end
	return TF2Res.GetRect(node, parentW, parentH, defaults or { x = 0, y = 0, w = 0, h = 0 })
end

local function PulseAlpha(minAlpha, maxAlpha, cycleSeconds)
	local duration = math.max(tonumber(cycleSeconds) or 0.75, 0.01)
	local t = (CurTime() % duration) / duration
	local wave = 0.5 + 0.5 * math.sin(t * math.pi * 2)
	return math.floor(Lerp(wave, minAlpha or 32, maxAlpha or 96))
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

local function TeamHomeTexture(teamNum, square)
	if teamNum == (TEAM_BLU or 3) then
		return square and TEX.home_blue_square or TEX.home_blue
	end
	if teamNum == (TEAM_RED or 2) then
		return square and TEX.home_red_square or TEX.home_red
	end
	return TeamPointTexture(0, square and true or false)
end

local function TeamCartTexture(teamNum)
	if teamNum == (TEAM_BLU or 3) then return TEX.cart_blue, TEX.cart_blue_bottom end
	if teamNum == (TEAM_RED or 2) then return TEX.cart_red, TEX.cart_red_bottom end
	return TEX.cart_neutral, TEX.cart_neutral_bottom
end

local function ShouldDrawPayloadHUD()
	if not GAMEMODE then return false end
	if GetConVarNumber("cl_drawhud") == 0 then return false end
	if GAMEMODE.ShowScoreboard then return false end
	if TF_IsPayloadHudMode and not TF_IsPayloadHudMode() then return false end

	local forceHL2 = GetConVar("tf_forcehl2hud")
	local override = GetConVar("tf_payload_hud_override")
	if forceHL2 and forceHL2:GetBool() and not (override and override:GetBool()) then
		return false
	end

	return TF_HasActivePayloadHudState and TF_HasActivePayloadHudState() or false
end

local function GetStatusText(state)
	if state.goal then
		return ResolveTokenWithFallback("#HudCart_Delivered", "DELIVERED"), Color(230, 210, 130, 255)
	end
	if state.inOvertime then
		return ResolveToken("#game_Overtime"), COLOR_OVERTIME
	end
	if state.blocked or state.trainState == TRAIN_STATE_BLOCKED then
		return ResolveToken("#Team_Progress_Blocked"), COLOR_BLOCKED
	end
	if state.trainState == TRAIN_STATE_RECEDING then
		return ResolveTokenWithFallback("#HudCart_Recede", "RECEDING"), COLOR_RECEDE
	end
	return "", COLOR_TEXT
end

local function FormatCapperText(count)
	local token = ResolveToken("#ControlPointIconCappers")
	token = string.gsub(token, "%%numcappers%%", tostring(math.max(tonumber(count) or 0, 0)))
	return token
end

local function DrawEscortTrack(state, displayProgress, x, y, w, h, attackTeam, multiple, scale)
	local progress = math.Clamp(displayProgress or tonumber(state.progress) or 0, 0, 1)

	if not DrawTexture(TEX.track_neutral_opaque, x, y, w, h) then
		draw.RoundedBox(0, x, y, w, h, Color(72, 66, 58, 220))
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

	if progress > 0 and progress < 1 then
		surface.SetDrawColor(COLOR_TRACK_EDGE.r, COLOR_TRACK_EDGE.g, COLOR_TRACK_EDGE.b, COLOR_TRACK_EDGE.a)
		surface.DrawRect(x + w * progress - math.max(scale, 1), y, math.max(scale, 1), h)
	end

	if state.trainState == TRAIN_STATE_FORWARD and TEX.track_arrow and TEX.track_arrow > 0 then
		local arrowW = multiple and 12 * scale or 18 * scale
		local startX = x + math.max(w * progress - 36 * scale, 0)
		local endX = x + math.min(w * progress + 48 * scale, w - arrowW)
		local scroll = (CurTime() * 0.45) % 1
		local alpha = PulseAlpha(32, 96, 0.75)
		for arrowX = startX, endX, math.max(arrowW * 0.9, 1) do
			DrawTextureUV(TEX.track_arrow, arrowX, y, arrowW, h, scroll, 0, scroll + 1, 1, Color(255, 255, 255, alpha))
		end
	end
end

local function DrawEscortMarkers(state, displayProgress, x, y, w, h, attackTeam, multiple, scale)
	local progress = math.Clamp(displayProgress or tonumber(state.progress) or 0, 0, 1)
	local iconSize = multiple and 14 * scale or 28 * scale
	local pointSize = multiple and 12 * scale or 28 * scale
	local square = multiple and true or false
	local markerY = y + (h * 0.5) - (pointSize * 0.5)

	DrawTexture(TeamHomeTexture(attackTeam, square), x - (multiple and 14 * scale or iconSize * 0.5), y + (h * 0.5) - (iconSize * 0.5), iconSize, iconSize)

	for _, frac in ipairs(state.checkpointProgress or {}) do
		frac = math.Clamp(tonumber(frac) or 0, 0, 1)
		local markerX = x + frac * w - (pointSize * 0.5)
		local markerTeam = (progress >= frac) and attackTeam or 0
		DrawTexture(TeamPointTexture(markerTeam, multiple), markerX, markerY, pointSize, pointSize)
	end
end

local function DrawEscortItemPanel(state, x, y, attackTeam, scale, multiple)
	local cappers = math.max(tonumber(state.cappers) or 0, 0)
	local cartTex, cartBottomTex = TeamCartTexture(attackTeam)

	local res = GetEscortResLayout()
	local itemPanelNode = multiple and (res and (res.ifMultipleItemPanel or res.itemPanel)) or (res and res.itemPanel)
	local panelRect = GetNodeRect(itemPanelNode, multiple and 400 or 400, multiple and 200 or 150, { x = 0, y = multiple and 48 or 8, w = multiple and 52 or 80, h = multiple and 170 or 115 })
	local escortImageNode = multiple and (res and (res.ifMultipleEscortImage or res.escortImage)) or (res and res.escortImage)
	local escortImageBottomNode = multiple and (res and (res.ifMultipleEscortImageBottom or res.escortImageBottom)) or (res and res.escortImageBottom)
	local alertNode = multiple and (res and (res.ifMultipleAlertBottom or res.escortAlert)) or (res and res.escortAlert)
	local recedeNode = multiple and (res and (((state.trainState == TRAIN_STATE_RECEDING or (state.canRecede and not state.blocked and cappers <= 0 and (state.recedeRemaining or 0) > 0)) and res.ifMultipleRecedeBottom) or res.ifMultipleRecedeTop or res.ifMultipleRecede or res.recedeTime)) or (res and res.recedeTime)
	local speedNode = multiple and (res and ((state.trainState == TRAIN_STATE_RECEDING and (res.ifMultipleSpeedBottom or res.ifMultipleSpeedTop or res.ifMultipleSpeed)) or res.ifMultipleSpeed or res.speedBack)) or (res and res.speedBack)
	local capPlayerNode = multiple and (res and (((cappers > 0) and (res.ifMultipleCapPlayerBottom or res.ifMultipleCapPlayerTop or res.ifMultipleCapPlayer)) or res.ifMultipleCapPlayer or res.capPlayer)) or (res and res.capPlayer)
	local capNumNode = multiple and (res and (((cappers > 0) and (res.ifMultipleCapNumBottom or res.ifMultipleCapNumTop or res.ifMultipleCapNum)) or res.ifMultipleCapNum or res.capNum)) or (res and res.capNum)
	local blockedNode = multiple and (res and (((state.blocked or state.trainState == TRAIN_STATE_BLOCKED) and (res.ifMultipleBlockedBottom or res.ifMultipleBlockedTop or res.ifMultipleBlocked)) or res.ifMultipleBlocked or res.blocked)) or (res and res.blocked)

	local escortImageRect = GetNodeRect(escortImageNode, panelRect.w, panelRect.h, { x = multiple and 11 or 20, y = multiple and 43 or 77, w = multiple and 30 or 40, h = multiple and 30 or 40 })
	local escortImageBottomRect = GetNodeRect(escortImageBottomNode, panelRect.w, panelRect.h, { x = multiple and 11 or 20, y = multiple and 71 or 117, w = multiple and 30 or 40, h = multiple and 30 or 40 })
	local alertRect = GetNodeRect(alertNode, panelRect.w, panelRect.h, { x = multiple and -5 or -4, y = multiple and 75 or 38, w = 60, h = 30 })
	local recedeRect = GetNodeRect(recedeNode, panelRect.w, panelRect.h, { x = multiple and 21 or 35, y = multiple and 82 or 82, w = 11, h = 10 })
	local speedRect = GetNodeRect(speedNode, panelRect.w, panelRect.h, { x = multiple and 22 or 35, y = multiple and 83 or 82, w = multiple and 8 or 10, h = multiple and 8 or 10 })
	local capPlayerRect = GetNodeRect(capPlayerNode, panelRect.w, panelRect.h, { x = multiple and 20 or 33, y = multiple and 81 or 80, w = multiple and 5 or 6, h = multiple and 10 or 12 })
	local capNumRect = GetNodeRect(capNumNode, panelRect.w, panelRect.h, { x = multiple and 25 or 39, y = multiple and 82 or 82, w = 30, h = 10 })
	local blockedRect = GetNodeRect(blockedNode, panelRect.w, panelRect.h, { x = multiple and 22 or 35, y = multiple and 83 or 82, w = multiple and 8 or 10, h = multiple and 8 or 10 })

	if state.inOvertime and (math.floor(CurTime() * 3) % 2 == 0) then
		DrawTexture(TEX.alert, x + alertRect.x, y + alertRect.y, alertRect.w, alertRect.h)
	end

	DrawTexture(cartBottomTex, x + escortImageBottomRect.x, y + escortImageBottomRect.y, escortImageBottomRect.w, escortImageBottomRect.h)
	DrawTexture(cartTex, x + escortImageRect.x, y + escortImageRect.y, escortImageRect.w, escortImageRect.h)

	if state.canRecede and not state.blocked and cappers <= 0 and (state.recedeRemaining or 0) > 0 then
		draw.Text({
			text = tostring(math.floor(math.max(tonumber(state.recedeRemaining) or 0, 0) + 0.999)),
			font = "HudFontSmallest",
			pos = {x + recedeRect.x + recedeRect.w * 0.5, y + recedeRect.y + recedeRect.h * 0.5},
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
			color = COLOR_TEXT,
		})
		return
	end

	if state.trainState == TRAIN_STATE_RECEDING then
		DrawTexture(TEX.arrow_left, x + speedRect.x, y + speedRect.y, speedRect.w, speedRect.h)
		return
	end

	if state.blocked or state.trainState == TRAIN_STATE_BLOCKED then
		DrawTexture(TEX.blocked, x + blockedRect.x, y + blockedRect.y, blockedRect.w, blockedRect.h)
		return
	end

	if cappers > 0 then
		DrawTexture(TEX.cap_player, x + capPlayerRect.x, y + capPlayerRect.y, capPlayerRect.w, capPlayerRect.h)
		draw.Text({
			text = FormatCapperText(cappers),
			font = "HudFontSmallest",
			pos = {x + capNumRect.x, y + capNumRect.y + capNumRect.h * 0.5},
			xalign = TEXT_ALIGN_LEFT,
			yalign = TEXT_ALIGN_CENTER,
			color = COLOR_TEXT,
		})
	end
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
	self.DisplayProgress = {}
end

function PANEL:PerformLayout()
	self:SetPos(0, 0)
	self:SetSize(ScrW(), ScrH())
end

function PANEL:GetDisplayProgress(state)
	local key = tonumber(state.watcher) or 0
	local target = math.Clamp(tonumber(state.progress) or 0, 0, 1)
	local current = self.DisplayProgress[key]
	if current == nil then
		current = target
	end
	current = Lerp(math.Clamp(FrameTime() / 0.2, 0, 1), current, target)
	self.DisplayProgress[key] = current
	return current
end

function PANEL:PaintEscortPanel(state, panelX, panelY, multiple)
	if not state or not state.active then return end

	local attackTeam = tonumber(state.attackTeam) or TEAM_BLU or 3
	local displayProgress = self:GetDisplayProgress(state)
	local res = GetEscortResLayout()
	local panelW = 400
	local panelH = multiple and 200 or 150

	local trackNode = multiple and (res and (res.ifMultipleLevelBar or res.levelBar)) or (res and res.levelBar)
	local homeNode = multiple and (res and (res.ifMultipleHome or res.homeIcon)) or (res and res.homeIcon)
	local cpNode = multiple and (res and (res.ifMultipleCP or res.cpTemplate)) or (res and res.cpTemplate)
	local itemPanelNode = multiple and (res and (res.ifMultipleItemPanel or res.itemPanel)) or (res and res.itemPanel)
	local trackRect = GetNodeRect(trackNode, panelW, panelH, { x = 73, y = multiple and 114 or 123, w = 254, h = multiple and 12 or 4 })
	local homeRect = GetNodeRect(homeNode, panelW, panelH, { x = 59, y = 113, w = multiple and 14 or 28, h = multiple and 14 or 28 })
	local cpRect = GetNodeRect(cpNode, panelW, panelH, { x = 61, y = multiple and 114 or 111, w = multiple and 12 or 28, h = multiple and 12 or 28 })
	local itemPanelRect = GetNodeRect(itemPanelNode, panelW, panelH, { x = 0, y = multiple and 48 or 8, w = multiple and 52 or 80, h = multiple and 170 or 115 })

	local trackX = panelX + trackRect.x
	local trackY = panelY + trackRect.y
	local trackW = trackRect.w
	local trackH = trackRect.h

	DrawEscortTrack(state, displayProgress, trackX, trackY, trackW, trackH, attackTeam, multiple, 1)
	DrawEscortMarkers(state, displayProgress, trackX + ((homeRect.x or 59) - 59), trackY + ((cpRect.y or trackRect.y) - trackRect.y), trackW, trackH, attackTeam, multiple, 1)

	local statusText, statusColor = GetStatusText(state)
	if statusText ~= "" then
		draw.Text({
			text = statusText,
			font = "HudFontSmall",
			pos = {panelX + panelW * 0.5, trackY - (multiple and 12 or 11)},
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
			color = statusColor,
		})
	end

	local cartCenterX = trackX + trackW * displayProgress
	if multiple then
		DrawEscortItemPanel(state, cartCenterX - itemPanelRect.w * 0.5, panelY + itemPanelRect.y, attackTeam, 1, true)
	else
		DrawEscortItemPanel(state, cartCenterX - itemPanelRect.w * 0.5, panelY + itemPanelRect.y, attackTeam, 1, false)
	end
end

function PANEL:Paint()
	if not ShouldDrawPayloadHUD() then return end

	local scaleX = ScrW() / 640
	local scaleY = ScrH() / 480
	local res = GetEscortResLayout()
	local multipleState = TF_GetPayloadRaceHudState and TF_GetPayloadRaceHudState() or nil
	if multipleState and multipleState.multiple then
		local blueNode = res and res.bluePanel or nil
		local redNode = res and res.redPanel or nil
		local topNode = multipleState.topTeam == (TEAM_RED or 2) and (res and (res.ifRedTop or redNode) or nil) or (res and (res.ifBlueTop or blueNode) or nil)
		local bottomNode = multipleState.topTeam == (TEAM_RED or 2) and blueNode or redNode
		local topRect = GetNodeRect(topNode or blueNode, ScrW(), ScrH(), { x = ScrW() * 0.5 - 200, y = ScrH() - 304, w = 400, h = 200 })
		local bottomRect = GetNodeRect(bottomNode or redNode, ScrW(), ScrH(), { x = ScrW() * 0.5 - 200, y = ScrH() - 320, w = 400, h = 200 })
		local topState = multipleState.topTeam == (TEAM_RED or 2) and multipleState.red or multipleState.blue
		local bottomState = multipleState.bottomTeam == (TEAM_RED or 2) and multipleState.red or multipleState.blue

		self:PaintEscortPanel(topState, topRect.x, topRect.y, true)
		self:PaintEscortPanel(bottomState, bottomRect.x, bottomRect.y, true)
		return
	end

	local state = TF_GetPayloadHudState and TF_GetPayloadHudState() or nil
	if not state or not state.active then return end

	local rootRect = GetNodeRect(res and res.escortRoot or nil, ScrW(), ScrH(), { x = ScrW() * 0.5 - 200, y = ScrH() - 150, w = 400, h = 150 })
	self:PaintEscortPanel(state, rootRect.x, rootRect.y, false)
end

if HudPayloadPanel then HudPayloadPanel:Remove() end
HudPayloadPanel = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

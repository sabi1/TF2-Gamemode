local PANEL = {}

local progress_bar_noCap = surface.GetTextureID("vgui/progress_bar_noCap")
local progress_bar_blocked = surface.GetTextureID("vgui/progress_bar")
local progress_bar_red = surface.GetTextureID("vgui/progress_bar_red")
local progress_bar_blu = surface.GetTextureID("vgui/progress_bar_blu")
local progress_bar_pointer = surface.GetTextureID("vgui/progress_bar_pointer")
local progress_bar_pointer_left = surface.GetTextureID("vgui/progress_bar_pointer_left")
local progress_bar_pointer_right = surface.GetTextureID("vgui/progress_bar_pointer_right")

local cp_hbar_red = Material("sprites/obj_icons/icon_obj_cap_red")
cp_hbar_red:SetInt("$separatedetailuvs", 0)
cp_hbar_red:SetInt("$detailscale", 1)
local cp_hbar_blu = Material("sprites/obj_icons/icon_obj_cap_blu")
cp_hbar_blu:SetInt("$separatedetailuvs", 0)
cp_hbar_blu:SetInt("$detailscale", 1)
local cp_vbar_red = Material("sprites/obj_icons/icon_obj_cap_red_up")
cp_vbar_red:SetInt("$separatedetailuvs", 0)
cp_vbar_red:SetInt("$detailscale", 1)
local cp_vbar_blu = Material("sprites/obj_icons/icon_obj_cap_blu_up")
cp_vbar_blu:SetInt("$separatedetailuvs", 0)
cp_vbar_blu:SetInt("$detailscale", 1)
local cvParityCPDebug = CreateClientConVar("tf_parity_cp_overlay", "0", true, false, "Show CP/KOTH objective debug overlay text.")

local CPRes = {
	iconW = 33,
	iconH = 33,
	overlayX = 19,
	overlayY = 0,
	overlayW = 14,
	overlayH = 14,
	capPlayerX = 0,
	capPlayerY = 0,
	capPlayerW = 10,
	capPlayerH = 20,
	capNumX = 15,
	capNumY = 4,
	gridGapX = 7,
	gridGapY = 7,
	stripBottomOffset = 64,
	kothStripTop = 50,
	progressW = 100,
	progressH = 65,
	progressBarX = 28,
	progressBarY = 5,
	progressBarW = 45,
	progressBarH = 45,
	progressTextX = 14,
	progressTextY = 8,
	progressTextW = 75,
	progressTextH = 40,
	progressTextFont = "TFDefaultVerySmall",
	progressTextAlign = "center",
	progressDropX = 24,
	progressDropY = 0,
	blockedX = 26,
	blockedY = 3,
	blockedW = 50,
	blockedH = 50,
	teardropW = 54,
	teardropH = 65,
	teardropSideW = 54,
	teardropSideH = 54,
	texProgressFgBlu = progress_bar_blu,
	texProgressBg = progress_bar_noCap,
	texBlocked = progress_bar_blocked,
	texTeardrop = progress_bar_pointer,
	texTeardropSide = progress_bar_pointer_left,
}

local function Localize(token)
	if not isstring(token) then
		return ""
	end
	if tf_lang and tf_lang.GetRaw then
		return tf_lang.GetRaw(token, true)
	end
	if language and language.GetPhrase and string.StartWith(token, "#") then
		return language.GetPhrase(string.sub(token, 2))
	end
	return token
end

local function TeamCanCapFromState(state, teamNum)
	if teamNum == 2 then
		return state.canCapRed ~= false
	end
	if teamNum == 3 then
		return state.canCapBlu ~= false
	end
	return false
end

local function ToCPIndex(rawId)
	return (tonumber(rawId) or 0) + 1
end

local function ResolveResIconTextureID(node, key, fallback)
	local raw = TF2Res and TF2Res.GetString and TF2Res.GetString(node, key, nil) or nil
	local normalized = TF2Res and TF2Res.NormalizeImagePath and TF2Res.NormalizeImagePath(raw or "")
	if not normalized or normalized == "" then
		return surface.GetTextureID(fallback)
	end

	-- TF2 RES tokens used by CP HUD sometimes map poorly in GMod material lookup.
	-- Force known-good equivalents for parity rendering.
	if normalized == "cappoint_progressbar_teardrop" then
		return surface.GetTextureID(fallback)
	end
	if normalized == "cappoint_progressbar_blocked" then
		return surface.GetTextureID("vgui/progress_bar")
	end

	local function texturePathExists(path)
		return file.Exists("materials/" .. path .. ".vmt", "GAME")
			or file.Exists("materials/" .. path .. ".vtf", "GAME")
	end

	local candidates = {
		normalized,
		"hud/" .. normalized,
		"vgui/" .. normalized,
	}

	for _, path in ipairs(candidates) do
		if texturePathExists(path) then
			local tex = surface.GetTextureID(path)
			if tex and tex > 0 then
				return tex
			end
		end
	end

	return surface.GetTextureID(fallback)
end

local function MaterialExists(path)
	if not isstring(path) or path == "" then
		return false
	end
	local mat = Material(path)
	return mat ~= nil and mat.IsError and (not mat:IsError())
end

local function ResolveResTextureID(node, key, fallback)
	local raw = TF2Res and TF2Res.GetString and TF2Res.GetString(node, key, nil) or nil
	local normalized = TF2Res and TF2Res.NormalizeImagePath and TF2Res.NormalizeImagePath(raw or "")
	if not normalized or normalized == "" then
		return surface.GetTextureID(fallback)
	end

	-- TF2 token; mounted content may not expose this exact material path in GMod.
	-- Prefer known-good VGUI variants to avoid fallback checkerboard.
	if normalized == "progress_bar_blu" then
		if MaterialExists("vgui/progress_bar_blu") then
			return surface.GetTextureID("vgui/progress_bar_blu")
		end
		return surface.GetTextureID("vgui/progress_bar")
	end

	local function texturePathExists(path)
		return file.Exists("materials/" .. path .. ".vmt", "GAME")
			or file.Exists("materials/" .. path .. ".vtf", "GAME")
	end

	local candidates = {
		normalized,
		"vgui/" .. normalized,
		"hud/" .. normalized,
	}

	for _, path in ipairs(candidates) do
		if texturePathExists(path) or MaterialExists(path) then
			local tex = surface.GetTextureID(path)
			if tex and tex > 0 then
				return tex
			end
		end
	end

	return surface.GetTextureID(fallback)
end

local function ReadRes()
	local mode = (TF_GetHudGameMode and TF_GetHudGameMode()) or "cp"
	local iconResPath = (TF_GetHudResPath and TF_GetHudResPath(mode, "controlPointIcon", "resource/ui/controlpointicon.res")) or "resource/ui/controlpointicon.res"
	local progressResPath = (TF_GetHudResPath and TF_GetHudResPath(mode, "controlPointProgress", "resource/ui/controlpointprogressbar.res")) or "resource/ui/controlpointprogressbar.res"
	local kothResPath = (TF_GetHudResPath and TF_GetHudResPath("koth", "kothTimer", "resource/ui/hudobjectivekothtimepanel.res")) or "resource/ui/hudobjectivekothtimepanel.res"

	local iconTree = TF2Res and TF2Res.Load and TF2Res.Load(iconResPath)
	local iconRoot = iconTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(iconTree, "ControlPointIcon")
	local overlay = iconTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(iconTree, "OverlayImage")
	local capPlayer = iconTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(iconTree, "CapPlayerImage")
	local capNum = iconTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(iconTree, "CapNumPlayers")
	if iconRoot and TF2Res.GetNumber then
		CPRes.iconW = TF2Res.GetNumber(iconRoot, "wide", CPRes.iconW)
		CPRes.iconH = TF2Res.GetNumber(iconRoot, "tall", CPRes.iconH)
	end
	if overlay and TF2Res.GetNumber then
		CPRes.overlayX = TF2Res.GetNumber(overlay, "xpos", CPRes.overlayX)
		CPRes.overlayY = TF2Res.GetNumber(overlay, "ypos", CPRes.overlayY)
		CPRes.overlayW = TF2Res.GetNumber(overlay, "wide", CPRes.overlayW)
		CPRes.overlayH = TF2Res.GetNumber(overlay, "tall", CPRes.overlayH)
	end
	if capPlayer and TF2Res.GetNumber then
		CPRes.capPlayerX = TF2Res.GetNumber(capPlayer, "xpos", CPRes.capPlayerX)
		CPRes.capPlayerY = TF2Res.GetNumber(capPlayer, "ypos", CPRes.capPlayerY)
		CPRes.capPlayerW = TF2Res.GetNumber(capPlayer, "wide", CPRes.capPlayerW)
		CPRes.capPlayerH = TF2Res.GetNumber(capPlayer, "tall", CPRes.capPlayerH)
	end
	if capNum and TF2Res.GetNumber then
		CPRes.capNumX = TF2Res.GetNumber(capNum, "xpos", CPRes.capNumX)
		CPRes.capNumY = TF2Res.GetNumber(capNum, "ypos", CPRes.capNumY)
	end

	local progressTree = TF2Res and TF2Res.Load and TF2Res.Load(progressResPath)
	local progressRoot = progressTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(progressTree, "ControlPointProgressBar")
	local progressBar = progressTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(progressTree, "ProgressBar")
	local teardrop = progressTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(progressTree, "Teardrop")
	local teardropSide = progressTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(progressTree, "TeardropSide")
	local progressText = progressTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(progressTree, "ProgressText")
	local blocked = progressTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(progressTree, "Blocked")
	if progressRoot and TF2Res.GetNumber then
		CPRes.progressW = TF2Res.GetNumber(progressRoot, "wide", CPRes.progressW)
		CPRes.progressH = TF2Res.GetNumber(progressRoot, "tall", CPRes.progressH)
	end
	if progressBar and TF2Res.GetNumber then
		CPRes.progressBarX = TF2Res.GetNumber(progressBar, "xpos", CPRes.progressBarX)
		CPRes.progressBarY = TF2Res.GetNumber(progressBar, "ypos", CPRes.progressBarY)
		CPRes.progressBarW = TF2Res.GetNumber(progressBar, "wide", CPRes.progressBarW)
		CPRes.progressBarH = TF2Res.GetNumber(progressBar, "tall", CPRes.progressBarH)
		CPRes.texProgressFgBlu = ResolveResTextureID(progressBar, "fg_image", "vgui/progress_bar_blu")
		CPRes.texProgressBg = ResolveResTextureID(progressBar, "bg_image", "vgui/progress_bar_noCap")
	end
	if teardrop and TF2Res.GetNumber then
		CPRes.progressDropX = TF2Res.GetNumber(teardrop, "xpos", CPRes.progressDropX)
		CPRes.progressDropY = TF2Res.GetNumber(teardrop, "ypos", CPRes.progressDropY)
		CPRes.teardropW = TF2Res.GetNumber(teardrop, "wide", CPRes.teardropW)
		CPRes.teardropH = TF2Res.GetNumber(teardrop, "tall", CPRes.teardropH)
		CPRes.texTeardrop = ResolveResIconTextureID(teardrop, "icon", "vgui/progress_bar_pointer")
	end
	if teardropSide and TF2Res.GetNumber then
		CPRes.teardropSideW = TF2Res.GetNumber(teardropSide, "wide", CPRes.teardropSideW)
		CPRes.teardropSideH = TF2Res.GetNumber(teardropSide, "tall", CPRes.teardropSideH)
		CPRes.texTeardropSide = ResolveResIconTextureID(teardropSide, "icon", "vgui/progress_bar_pointer_left")
	end
	if progressText and TF2Res.GetNumber then
		CPRes.progressTextX = TF2Res.GetNumber(progressText, "xpos", CPRes.progressTextX)
		CPRes.progressTextY = TF2Res.GetNumber(progressText, "ypos", CPRes.progressTextY)
		CPRes.progressTextW = TF2Res.GetNumber(progressText, "wide", CPRes.progressTextW)
		CPRes.progressTextH = TF2Res.GetNumber(progressText, "tall", CPRes.progressTextH)
		if TF2Res.GetString then
			CPRes.progressTextFont = TF2Res.GetString(progressText, "font", CPRes.progressTextFont) or CPRes.progressTextFont
			CPRes.progressTextAlign = string.lower(TF2Res.GetString(progressText, "textAlignment", CPRes.progressTextAlign) or CPRes.progressTextAlign)
		end
	end
	if blocked and TF2Res.GetNumber then
		CPRes.blockedX = TF2Res.GetNumber(blocked, "xpos", CPRes.blockedX)
		CPRes.blockedY = TF2Res.GetNumber(blocked, "ypos", CPRes.blockedY)
		CPRes.blockedW = TF2Res.GetNumber(blocked, "wide", CPRes.blockedW)
		CPRes.blockedH = TF2Res.GetNumber(blocked, "tall", CPRes.blockedH)
		CPRes.texBlocked = ResolveResIconTextureID(blocked, "icon", "vgui/progress_bar")
	end

	local kothTree = TF2Res and TF2Res.Load and TF2Res.Load(kothResPath)
	local activeBg = kothTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(kothTree, "ActiveTimerBG")
	if activeBg and TF2Res.GetNumber then
		CPRes.kothStripTop = TF2Res.GetNumber(activeBg, "ypos", 9) + TF2Res.GetNumber(activeBg, "tall", 33) + 8
	end
end
ReadRes()

local ControlPointCapStateFallback = {}

local function GetControlPointCapStateTable()
	local gm = rawget(_G, "GAMEMODE")
	if istable(gm) then
		gm.ControlPointCapState = gm.ControlPointCapState or {}
		return gm.ControlPointCapState
	end
	return ControlPointCapStateFallback
end

local function GetControlPointsTable()
	local gm = rawget(_G, "GAMEMODE")
	if istable(gm) then
		gm.ControlPoints = gm.ControlPoints or {}
		return gm.ControlPoints
	end
	return {}
end

local function GetControlPointLayout()
	local gm = rawget(_G, "GAMEMODE")
	if istable(gm) then
		return gm.ControlPointLayout
	end
	return nil
end

net.Receive("TF_ControlPointCapState", function()
	local capStateTable = GetControlPointCapStateTable()
	local id = ToCPIndex(net.ReadInt(8))
	local previous = capStateTable[id]
	local incoming = {
		ownerTeam = net.ReadInt(8),
		cappingTeam = net.ReadInt(8),
		cappers = net.ReadUInt(4),
		enemies = net.ReadUInt(4),
		requiredPlayers = net.ReadUInt(4),
		canCapRed = net.ReadBool(),
		canCapBlu = net.ReadBool(),
		blocked = net.ReadBool(),
		progress = net.ReadFloat(),
		locked = net.ReadBool(),
	}
	if incoming.locked then
		incoming.cappers = 0
		incoming.enemies = 0
		incoming.blocked = false
		incoming.progress = 0
	end
	incoming.lastCappingTeam = incoming.cappingTeam ~= 0 and incoming.cappingTeam
		or (previous and (previous.lastCappingTeam or previous.cappingTeam) or 0)
	local resetDisplay = false
	if previous then
		if (previous.cappingTeam or 0) ~= (incoming.cappingTeam or 0) then
			resetDisplay = true
		elseif (previous.ownerTeam or 0) ~= (incoming.ownerTeam or 0) then
			resetDisplay = true
		elseif (previous.locked and true or false) ~= (incoming.locked and true or false) then
			resetDisplay = true
		elseif (previous.progress or 0) > ((incoming.progress or 0) + 0.05) then
			resetDisplay = true
		end
	end
	incoming.displayProgress = (not previous or resetDisplay) and incoming.progress or (previous.displayProgress or incoming.progress)
	capStateTable[id] = incoming
end)

local function GetLayoutRows()
	local layout = GetControlPointLayout()
	if istable(layout) and #layout > 0 then
		return layout
	end

	local rows = {{}}
	for id in pairs(GetControlPointsTable()) do
		rows[1][#rows[1] + 1] = id
	end
	table.sort(rows[1])
	return rows
end

local function FindCPLayoutPosition(cpIndex)
	for rowIndex, row in ipairs(GetLayoutRows()) do
		for colIndex, value in ipairs(row) do
			if value == cpIndex then
				return rowIndex, colIndex
			end
		end
	end
end

local function GetCapState(cpIndex, cp)
	local state = GetControlPointCapStateTable()[cpIndex]
	if not state then
		return {
			ownerTeam = cp and cp.owner or 0,
			cappingTeam = 0,
			cappers = 0,
			enemies = 0,
			requiredPlayers = 1,
			canCapRed = true,
			canCapBlu = true,
			blocked = false,
			progress = 0,
			displayProgress = 0,
			locked = cp and cp.locked or false,
		}
	end
	return state
end

local function GetProgressMessage(cp, state, localTeam)
	if not cp then
		return nil
	end

	if state.locked then
		return "#Team_Capture_NotNow"
	end

	local blockStyle = GetConVar("mp_blockstyle")
	local capStyle = GetConVar("mp_capstyle")
	local blockStyleValue = blockStyle and blockStyle:GetInt() or 0
	local capStyleValue = capStyle and capStyle:GetInt() or 0
	local requiredPlayers = math.max(state.requiredPlayers or 1, 1)
	local hasRequiredPlayers = capStyleValue == 1 or ((state.cappers or 0) >= requiredPlayers)
	local enemyTeam = (localTeam == 2) and 3 or 2
	local localCanCap = TeamCanCapFromState(state, localTeam)
	local enemyCanCap = TeamCanCapFromState(state, enemyTeam)

	if blockStyleValue == 1 and state.cappingTeam ~= 0 and state.cappingTeam ~= localTeam then
		if state.blocked or (state.enemies or 0) > 0 then
			return "#Team_Blocking_Capture"
		end
		if state.ownerTeam == 0 then
			return "#Team_Reverting_Capture"
		end
	end

	if state.ownerTeam == localTeam then
		if not enemyCanCap then
			return "#Team_Capture_Owned"
		end
		return "#Team_Capture_OwnPoint"
	end

	if not localCanCap then
		local mode = (TF_GetHudGameMode and TF_GetHudGameMode()) or "cp"
		if mode == "arena" then
			return "#Team_Capture_NotNow"
		end
		return "#Team_Capture_Linear"
	end

	if state.cappingTeam == localTeam then
		if hasRequiredPlayers then
			return "#Team_Capture_Blocked"
		end
	end

	if not localCanCap then
		return "#Team_Cannot_Capture"
	end

	return "#Team_Waiting_for_teammate"
end

local function GetProgressTextures(cappingTeam, ownerTeam)
	local bgTex = (cappingTeam == 2 and progress_bar_red) or progress_bar_blu
	local fgTex
	if ownerTeam == 2 then
		fgTex = progress_bar_red
	elseif ownerTeam == 3 then
		fgTex = progress_bar_blu
	else
		fgTex = progress_bar_blocked
	end
	return fgTex, bgTex
end

local function GetProgressTextureForTeam(teamNum, fallback)
	if teamNum == 2 then
		return progress_bar_red
	end
	if teamNum == 3 then
		return progress_bar_blu
	end
	return fallback
end

local function DrawCapSwipeArrow(x, y, w, h, mat, swipeUp, cappingTeam, capPercentage)
	if not mat or (mat.IsError and mat:IsError()) then
		return
	end

	local flXa, flXb = 0, 1
	local flYa, flYb = 0, 1
	local flArrowHeadPixelWidth = 15.0
	local flArrowBodyPixelWidth = 54.0
	local flBoxSize = 33.0
	local flImageSize = flArrowHeadPixelWidth + flArrowBodyPixelWidth
	local flMovementInTextureSpace = (flBoxSize + flArrowHeadPixelWidth) / flImageSize
	local flArrowSizeInTextureSpace = flArrowHeadPixelWidth / flImageSize
	local flIndent = 0.07

	if swipeUp then
		flYa = math.Remap(capPercentage, 0.0, 1.0, -flMovementInTextureSpace - flIndent, flArrowSizeInTextureSpace - flIndent)
		flYb = math.Remap(capPercentage, 0.0, 1.0, flIndent, flMovementInTextureSpace - flIndent)
	else
		flIndent = 0.1
		local flStart = 1.0 - flIndent
		local flEnd = 1.0 + flIndent
		local bSwipeLeftToRight = (cappingTeam % 2) == 0
		if bSwipeLeftToRight then
			flXa = math.Remap(capPercentage, 0.0, 1.0, flStart + flMovementInTextureSpace, flEnd - flArrowSizeInTextureSpace)
			flXb = math.Remap(capPercentage, 0.0, 1.0, flStart, 0.0)
		else
			flXa = math.Remap(capPercentage, 0.0, 1.0, flStart, 0.0)
			flXb = math.Remap(capPercentage, 0.0, 1.0, flStart + flMovementInTextureSpace, flEnd - flArrowSizeInTextureSpace)
		end
	end

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(mat)
	surface.DrawTexturedRectUV(x, y, w, h, flXa, flYa, flXb, flYb)
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

function PANEL:DrawControlPoint(cpIndex, x, y, swipeUp)
	local cp = GetControlPointsTable()[cpIndex]
	if not cp then return end

	local scale = ScrH() / 480
	local iconW = CPRes.iconW * scale
	local iconH = CPRes.iconH * scale
	local state = GetCapState(cpIndex, cp)

	surface.SetDrawColor(255, 255, 255, 255)
	if cp.tex_icon and cp.tex_icon >= 0 then
		surface.SetTexture(cp.tex_icon)
		surface.DrawTexturedRect(x, y, iconW, iconH)
	end

	if state.cappingTeam == 2 or state.cappingTeam == 3 then
		local capPercentage = math.Clamp(state.progress or 0, 0, 1)
		DrawCapSwipeArrow(
			x,
			y,
			iconW,
			iconH,
			swipeUp and (state.cappingTeam == 2 and cp_vbar_red or cp_vbar_blu) or (state.cappingTeam == 2 and cp_hbar_red or cp_hbar_blu),
			swipeUp,
			state.cappingTeam,
			capPercentage
		)
	end

	if cp.tex_overlay and cp.tex_overlay >= 0 then
		surface.SetTexture(cp.tex_overlay)
		surface.DrawTexturedRect(
			x + CPRes.overlayX * scale,
			y + CPRes.overlayY * scale,
			CPRes.overlayW * scale,
			CPRes.overlayH * scale
		)
	end

	local lp = LocalPlayer()
	local localTeam = IsValid(lp) and (lp:Team() == TEAM_RED and 2 or (lp:Team() == TEAM_BLU and 3 or 0)) or 0
	local showCapperCount = state.cappers and state.cappers > 1
		and state.cappingTeam ~= 0
		and not state.locked
		and state.cappingTeam == localTeam
		and state.cappingTeam ~= state.ownerTeam

	if showCapperCount then
		surface.SetDrawColor(255, 255, 255, 255)
		draw.SimpleText(tostring(state.cappers), "TFDefaultSmall", x + CPRes.capNumX * scale, y + CPRes.capNumY * scale, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
end

function PANEL:DrawProgressBubble(cpIndex, iconX, iconY)
	local cp = GetControlPointsTable()[cpIndex]
	if not cp then return end

	local state = GetCapState(cpIndex, cp)
	local localPlayer = LocalPlayer()
	if not IsValid(localPlayer) then return end
	local localTeam = localPlayer:Team() == TEAM_RED and 2 or (localPlayer:Team() == TEAM_BLU and 3 or 0)
	if localTeam == 0 then return end
	local message = GetProgressMessage(cp, state, localTeam)
	local scale = ScrH() / 480

	local rowIndex, colIndex = FindCPLayoutPosition(cpIndex)
	local pos = 0
	if rowIndex and GetLayoutRows()[rowIndex - 1] then
		pos = 1
		if GetLayoutRows()[rowIndex][(colIndex or 0) + 1] then
			pos = -1
		end
	end

	-- Default orientation: center the progress bubble directly above the CP icon.
	local bubbleX = iconX + ((CPRes.iconW - CPRes.progressW) * 0.5) * scale
	local bubbleY = iconY + (CPRes.progressDropY - CPRes.progressH) * scale
	local pointerTex = CPRes.texTeardrop or progress_bar_pointer
	local pointerW = CPRes.teardropW
	local pointerH = CPRes.teardropH
	if pos < 0 then
		bubbleX = iconX - (CPRes.progressW - CPRes.iconW - 23) * scale
		bubbleY = iconY - 54 * scale
		pointerTex = CPRes.texTeardropSide or progress_bar_pointer_left
		pointerW = CPRes.teardropSideW
		pointerH = CPRes.teardropSideH
	elseif pos > 0 then
		bubbleX = iconX + 10 * scale
		bubbleY = iconY - 54 * scale
		pointerTex = CPRes.texTeardropSide or progress_bar_pointer_right
		pointerW = CPRes.teardropSideW
		pointerH = CPRes.teardropSideH
	end

	local progressValue = math.Clamp(state.progress or 0, 0, 1)
	local showAnimatedProgress = (not state.locked)
		and (not state.blocked)
		and state.cappingTeam ~= 0
		and state.cappingTeam ~= state.ownerTeam
		and state.cappingTeam == localTeam
	local showBubble = showAnimatedProgress or message ~= nil
	if not showBubble then
		return
	end
	local drawBubbleX = bubbleX
	local drawBubbleY = bubbleY
	local drawBubbleW = CPRes.progressW * scale
	local drawBubbleH = CPRes.progressH * scale

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetTexture(pointerTex)
	surface.DrawTexturedRect(drawBubbleX + CPRes.progressDropX * scale, drawBubbleY, pointerW * scale, pointerH * scale)

	if showAnimatedProgress then
		local progressTeam = state.cappingTeam ~= 0 and state.cappingTeam or (state.lastCappingTeam or 0)
		local fgTex, bgTex = GetProgressTextures(progressTeam, state.ownerTeam)
		tf_draw.CircularProgressBar(
			drawBubbleX + CPRes.progressBarX * scale,
			drawBubbleY + CPRes.progressBarY * scale,
			CPRes.progressBarW * scale,
			CPRes.progressBarH * scale,
			fgTex,
			bgTex,
			Color(255, 255, 255, 255),
			Color(255, 255, 255, 255),
			progressValue
		)
		message = nil
	else
		state.displayProgress = progressValue
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetTexture(state.blocked and (CPRes.texBlocked or progress_bar_blocked) or GetProgressTextureForTeam(state.ownerTeam, progress_bar_noCap))
		surface.DrawTexturedRect(drawBubbleX + CPRes.blockedX * scale, drawBubbleY + CPRes.blockedY * scale, CPRes.blockedW * scale, CPRes.blockedH * scale)
	end

	if message then
		local align = CPRes.progressTextAlign
		if align ~= "center" and align ~= "north" and align ~= "south" and align ~= "east" and align ~= "west" then
			align = "center"
		end
		tf_draw.LabelTextWrap{
			x = drawBubbleX + CPRes.progressTextX * scale,
			y = drawBubbleY + CPRes.progressTextY * scale,
			w = CPRes.progressTextW * scale,
			h = CPRes.progressTextH * scale,
			font = CPRes.progressTextFont,
			text = Localize(message),
			align = align,
			yspace = 0.05,
			col = color_white,
		}
	end
end

function PANEL:Paint()
	if TF_IsControlPointHudMode then
		if not TF_IsControlPointHudMode() then return end
	else
		local mode = (TF_GetHudGameMode and TF_GetHudGameMode()) or "unknown"
		if mode == "mvm" then return end
		if not (mode == "cp" or mode == "koth" or mode == "arena") then return end
	end
	local gm = rawget(_G, "GAMEMODE")
	if not istable(gm) then return end
	if TF_HasActivePayloadHudState then
		if TF_HasActivePayloadHudState() then return end
	elseif gm.PayloadHUDActive then
		return
	end
	if not gm.ControlPoints then return end

	local rows = GetLayoutRows()
	if not rows or #rows == 0 or #(rows[1] or {}) == 0 then return end

	local scale = ScrH() / 480
	local screenW = ScrW()
	local screenH = ScrH()
	local totalHeight = (#rows * CPRes.iconH + math.max(#rows - 1, 0) * CPRes.gridGapY) * scale
	local widestRow = 0
	for _, row in ipairs(rows) do
		local width = (#row * CPRes.iconW + math.max(#row - 1, 0) * CPRes.gridGapX) * scale
		if width > widestRow then
			widestRow = width
		end
	end

	local startY = screenH - totalHeight - CPRes.stripBottomOffset * scale

	local activeX, activeY, activeIndex
	for rowIndex, row in ipairs(rows) do
		local rowWidth = (#row * CPRes.iconW + math.max(#row - 1, 0) * CPRes.gridGapX) * scale
		local x = (screenW - rowWidth) * 0.5
		local y = startY + (rowIndex - 1) * (CPRes.iconH + CPRes.gridGapY) * scale
		for _, cpIndex in ipairs(row) do
			self:DrawControlPoint(cpIndex, x, y, #rows > 1)
			if cvParityCPDebug and cvParityCPDebug:GetBool() then
				local st = GetCapState(cpIndex, gm.ControlPoints[cpIndex])
				local dbg = string.format(
					"#%d O:%d C:%d P:%d%% B:%s",
					cpIndex - 1,
					tonumber(st.ownerTeam) or 0,
					tonumber(st.cappingTeam) or 0,
					math.floor(math.Clamp((tonumber(st.progress) or 0) * 100, 0, 100)),
					st.blocked and "1" or "0"
				)
				draw.SimpleText(dbg, "TFDefaultVerySmall", x + 2 * scale, y - 9 * scale, Color(255, 255, 255, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			end
			if IsValid(LocalPlayer()) and cpIndex == LocalPlayer().CurrentControlPoint then
				activeX, activeY, activeIndex = x, y, cpIndex
			end
			x = x + (CPRes.iconW + CPRes.gridGapX) * scale
		end
	end

	if activeIndex then
		self:DrawProgressBubble(activeIndex, activeX, activeY)
	end
end

if ControlPointTest then ControlPointTest:Remove() end
ControlPointTest = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

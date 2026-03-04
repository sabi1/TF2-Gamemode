local PANEL = {}

local loadout_header = surface.GetTextureID("vgui/loadout_header")
local loadout_bottom_gradient = surface.GetTextureID("vgui/loadout_bottom_gradient")
local loadout_solid_line = surface.GetTextureID("vgui/loadout_solid_line")
local gradient_down = Material("vgui/gradient_down")
local dbg = GetConVar("tf_teamselect_debug") or CreateClientConVar("tf_teamselect_debug", "1", true, false, "Enable TF2 team select debug logging.")
local uiRolloverSound = "ui/buttonrollover.wav"
local uiClickSound = "ui/buttonclick.wav"
local uiClickReleaseSound = "ui/buttonclickrelease.wav"
local TFUI_BASE_W = 640
local TFUI_BASE_H = 480

local cardStyle = {
	auto = {
		base = Color(97, 89, 79, 240),
		hover = Color(125, 114, 101, 248),
		edge = Color(56, 50, 44, 255),
		shine = Color(255, 255, 255, 22),
		title = "AUTO-ASSIGN",
		key = "1",
	},
	red = {
		base = Color(116, 52, 45, 245),
		hover = Color(151, 68, 59, 250),
		edge = Color(53, 27, 24, 255),
		shine = Color(255, 210, 190, 36),
		title = "RED TEAM",
		key = "4",
	},
	blu = {
		base = Color(59, 86, 112, 245),
		hover = Color(79, 112, 147, 250),
		edge = Color(30, 46, 63, 255),
		shine = Color(206, 234, 255, 34),
		title = "BLU TEAM",
		key = "3",
	},
	spec = {
		base = Color(110, 100, 89, 240),
		hover = Color(142, 129, 113, 245),
		edge = Color(59, 53, 45, 255),
		shine = Color(255, 255, 255, 26),
		title = "SPECTATOR",
		key = "2",
	},
	neutral = {
		base = Color(117, 107, 94, 255),
		hover = Color(145, 73, 59, 255),
		edge = Color(70, 63, 55, 255),
		shine = Color(255, 255, 255, 24),
	},
}

local function tsLog(msg)
	if dbg and dbg:GetBool() then
		MsgN("[TFTeamSelect] " .. tostring(msg))
	end
end

local function playButtonClick()
	surface.PlaySound(uiClickSound)
	timer.Simple(0.1, function()
		surface.PlaySound(uiClickReleaseSound)
	end)
end

local function getMapSubtitle()
	local map = game.GetMap() or "unknown"
	if string.find(map, "mvm_") then
		return "MANN VS MACHINE - CHOOSE A SIDE"
	end
	return "JOIN A TEAM"
end

local function modelExists(path)
	return (util and util.IsValidModel and util.IsValidModel(path)) or file.Exists(path, "GAME")
end

local function findModelPath(candidates)
	for _, path in ipairs(candidates) do
		if modelExists(path) then
			return path
		end
	end
	return nil
end

local function applyTeamMenuModelPose(panel, resLayout)
	local mdl = (resLayout and resLayout.menuModel) or {}
	panel.LayoutEntity = function(_, ent)
		if not IsValid(ent) then return end
		ent:SetPos(Vector(mdl.originX or 290, mdl.originY or 0, mdl.originZ or -34))
		ent:SetAngles(Angle(mdl.anglesX or 0, mdl.anglesY or 180, mdl.anglesZ or 0))
	end
end

local function drawVerticalGradient(x, y, w, h, topColor, bottomColor)
	surface.SetDrawColor(topColor.r, topColor.g, topColor.b, topColor.a)
	surface.DrawRect(x, y, w, h)
	surface.SetMaterial(gradient_down)
	surface.SetDrawColor(bottomColor.r, bottomColor.g, bottomColor.b, bottomColor.a)
	surface.DrawTexturedRect(x, y, w, h)
end

local function resolveResLabel(token, fallback)
	if not isstring(token) or token == "" then
		return fallback
	end
	if tf_lang and tf_lang.GetRaw then
		local txt = tf_lang.GetRaw(token, true)
		if isstring(txt) and txt ~= "" then
			return txt
		end
	end
	if language and language.GetPhrase and string.StartWith(token, "#") then
		local key = string.sub(token, 2)
		local txt = language.GetPhrase(key)
		if isstring(txt) and txt ~= "" and txt ~= key then
			return txt
		end
	end
	return fallback or token
end

local function parseResCoord(rawValue, axisLength)
	if isnumber(rawValue) then
		return rawValue
	end
	if not isstring(rawValue) then
		return nil
	end
	local raw = string.Trim(rawValue)
	local num = tonumber(raw)
	if num then
		return num
	end
	if raw == "c" then
		return axisLength * 0.5
	end
	local centerOffset = string.match(raw, "^c([%+%-]?%d+%.?%d*)$")
	if centerOffset then
		return (axisLength * 0.5) + tonumber(centerOffset)
	end
	local rightOffset = string.match(raw, "^r([%+%-]?%d+%.?%d*)$")
	if rightOffset then
		return axisLength - tonumber(rightOffset)
	end
	return nil
end

local function parseResSize(rawValue, axisLength)
	if isnumber(rawValue) then
		return rawValue
	end
	if not isstring(rawValue) then
		return nil
	end
	local raw = string.Trim(rawValue)
	local num = tonumber(raw)
	if num then
		return num
	end
	local fillOffset = string.match(raw, "^f([%+%-]?%d+%.?%d*)$")
	if fillOffset then
		return axisLength + tonumber(fillOffset)
	end
	return nil
end

local function loadTeamMenuResLayout()
	if not TF2Res or not TF2Res.Load then return nil end

	local tree = TF2Res.Load("resource/ui/teammenu.res") or TF2Res.Load("resource/ui/TeamMenu.res") or TF2Res.Load("resource/ui/teammenu_sc.res")
	if not tree then return nil end

	local teambutton0 = TF2Res.FindByFieldName(tree, "teambutton0") -- blue
	local teambutton1 = TF2Res.FindByFieldName(tree, "teambutton1") -- red
	local teambutton2 = TF2Res.FindByFieldName(tree, "teambutton2") -- auto
	local teambutton3 = TF2Res.FindByFieldName(tree, "teambutton3") -- spectate
	local cancelButton = TF2Res.FindByFieldName(tree, "CancelButton")
	local teamMenuSelect = TF2Res.FindByFieldName(tree, "TeamMenuSelect")
	local teamMenuAuto = TF2Res.FindByFieldName(tree, "TeamMenuAuto")
	local teamMenuBlu = TF2Res.FindByFieldName(tree, "TeamMenuBlu")
	local teamMenuRed = TF2Res.FindByFieldName(tree, "TeamMenuRed")
	local teamMenuSpectate = TF2Res.FindByFieldName(tree, "TeamMenuSpectate")
	local menuBG = TF2Res.FindByFieldName(tree, "MenuBG")
	local menuModel = menuBG and TF2Res.FindByKey(menuBG, "model")

	local function readRect(node, defaultX, defaultY, defaultW, defaultH)
		if not node then
			return {x = defaultX, y = defaultY, w = defaultW, h = defaultH}
		end
		return {
			x = parseResCoord(TF2Res.GetString(node, "xpos", tostring(defaultX)), TFUI_BASE_W) or defaultX,
			y = parseResCoord(TF2Res.GetString(node, "ypos", tostring(defaultY)), TFUI_BASE_H) or defaultY,
			w = parseResSize(TF2Res.GetString(node, "wide", tostring(defaultW)), TFUI_BASE_W) or defaultW,
			h = parseResSize(TF2Res.GetString(node, "tall", tostring(defaultH)), TFUI_BASE_H) or defaultH,
		}
	end

	local function readLabel(node, fallbackText, defaultX, defaultY, defaultW, defaultH, defaultFont)
		return {
			x = parseResCoord(TF2Res.GetString(node, "xpos", tostring(defaultX)), TFUI_BASE_W) or defaultX,
			y = parseResCoord(TF2Res.GetString(node, "ypos", tostring(defaultY)), TFUI_BASE_H) or defaultY,
			w = parseResSize(TF2Res.GetString(node, "wide", tostring(defaultW)), TFUI_BASE_W) or defaultW,
			h = parseResSize(TF2Res.GetString(node, "tall", tostring(defaultH)), TFUI_BASE_H) or defaultH,
			font = TF2Res.GetString(node, "font", defaultFont),
			text = resolveResLabel(TF2Res.GetString(node, "labelText", fallbackText), fallbackText),
			align = string.lower(TF2Res.GetString(node, "textAlignment", "center")),
		}
	end

	return {
		auto = readRect(teambutton2, 30, 101, 124, 310),
		red = readRect(teambutton1, 479, 101, 124, 310),
		blu = readRect(teambutton0, 291, 101, 124, 310),
		spec = readRect(teambutton3, 180, 232, 82, 57),
		cancel = readRect(cancelButton, 450, 440, 150, 30),
		title = {
			x = parseResCoord(TF2Res.GetString(teamMenuSelect, "xpos", "30"), TFUI_BASE_W) or 30,
			y = parseResCoord(TF2Res.GetString(teamMenuSelect, "ypos", "r40"), TFUI_BASE_H) or 440,
			font = TF2Res.GetString(teamMenuSelect, "font", "HudFontMediumBold"),
			text = resolveResLabel(TF2Res.GetString(teamMenuSelect, "labelText", "#TF_SelectATeam"), "TEAM SELECT"),
		},
		autoLabel = readLabel(teamMenuAuto, "#TF_Random", 40, 55, 102, 24, "MenuSmallFont"),
		bluLabel = readLabel(teamMenuBlu, "#TF_BlueTeam_Name", 345, 55, 90, 24, "MenuSmallFont"),
		redLabel = readLabel(teamMenuRed, "#TF_RedTeam_Name", 525, 55, 90, 24, "MenuSmallFont"),
		specLabel = readLabel(teamMenuSpectate, "#TF_Spectate", 208, 255, 70, 20, "MenuSmallestFont"),
		labelAuto = resolveResLabel(TF2Res.GetString(teamMenuAuto, "labelText", "#TF_Random"), "AUTO-ASSIGN"),
		labelBlu = resolveResLabel(TF2Res.GetString(teamMenuBlu, "labelText", "#TF_BlueTeam_Name"), "BLU TEAM"),
		labelRed = resolveResLabel(TF2Res.GetString(teamMenuRed, "labelText", "#TF_RedTeam_Name"), "RED TEAM"),
		labelSpec = resolveResLabel(TF2Res.GetString(teamMenuSpectate, "labelText", "#TF_Spectate"), "SPECTATE"),
		closeLabel = resolveResLabel(TF2Res.GetString(cancelButton, "labelText", "#TF_Cancel"), "CLOSE"),
		closeFont = TF2Res.GetString(cancelButton, "font", "HudFontSmallBold"),
		menuBG = readRect(menuBG, 0, 0, TFUI_BASE_W, TFUI_BASE_H),
		menuFov = TF2Res.GetNumber(menuBG, "fov", 20),
		menuModel = {
			modelName = TF2Res.GetString(menuModel, "modelname", "models/vgui/UI_team01.mdl"),
			originX = TF2Res.GetNumber(menuModel, "origin_x", 290),
			originY = TF2Res.GetNumber(menuModel, "origin_y", 0),
			originZ = TF2Res.GetNumber(menuModel, "origin_z", -34),
			anglesX = TF2Res.GetNumber(menuModel, "angles_x", 0),
			anglesY = TF2Res.GetNumber(menuModel, "angles_y", 180),
			anglesZ = TF2Res.GetNumber(menuModel, "angles_z", 0),
		},
	}
end

local function applyActionButtonStyle(button, style)
	button.Hover = false
	button.disabled = false
	button:SetText("")

	function button:Paint(w, h)
		if self.UseResHotspot then
			if self.Hover then
				surface.SetDrawColor(style.base.r, style.base.g, style.base.b, 52)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(style.edge.r, style.edge.g, style.edge.b, 220)
				surface.DrawOutlinedRect(0, 0, w, h, 2)
			end
			return
		end

		local bg = self.Hover and style.hover or style.base
		draw.RoundedBox(4, 0, 0, w, h, bg)
		surface.SetDrawColor(style.edge.r, style.edge.g, style.edge.b, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
		surface.SetDrawColor(style.shine.r, style.shine.g, style.shine.b, style.shine.a)
		surface.DrawRect(2, 2, w - 4, math.max(3, math.floor(h * 0.24)))

		if self.labelText then
			draw.Text{
				text = self.labelText,
				font = self.font or "HudFontSmallBold",
				pos = {w * 0.5, h * 0.5},
				color = Color(235, 226, 202, 255),
				xalign = TEXT_ALIGN_CENTER,
				yalign = TEXT_ALIGN_CENTER,
			}
		end
	end

	function button:OnCursorEntered()
		if self.disabled then return end
		if not self.Hover then
			surface.PlaySound(uiRolloverSound)
		end
		self.Hover = true
		if IsValid(self:GetParent()) and self.teamKey then
			self:GetParent().ActiveCard = self.teamKey
		end
	end

	function button:OnCursorExited()
		if self.disabled then return end
		self.Hover = false
	end

	function button:OnMousePressed(mouseCode)
		if self.disabled then return end
		if mouseCode ~= MOUSE_LEFT then return end
		playButtonClick()
		self:DoClick()
	end
end

function PANEL:JoinTeam(teamID)
	local lp = LocalPlayer()
	if IsValid(lp) and lp:Team() == teamID then
		surface.PlaySound("buttons/button10.wav")
		tsLog("JoinTeam ignored, already in team " .. tostring(teamID))
		return
	end

	if TFJoinFlow then
		TFJoinFlow.PendingTeamJoinUntil = CurTime() + 2
	end

	local teamToken = tostring(teamID)
	if teamID == TEAM_UNASSIGNED then
		teamToken = "auto"
	elseif teamID == TEAM_RED then
		teamToken = "red"
	elseif teamID == TEAM_BLU then
		teamToken = "blu"
	elseif teamID == TEAM_SPECTATOR then
		teamToken = "spectator"
	end

	RunConsoleCommand("changeteam", teamToken)
	self:ClosePanel("join_team_" .. tostring(teamID))
end

function PANEL:SetInitialFlow(state)
	self.InitialFlow = state and true or false
	if IsValid(self.CloseButton) then
		self.CloseButton:SetVisible(not self.InitialFlow)
		self.CloseButton:SetEnabled(not self.InitialFlow)
	end
end

function PANEL:Init()
	self:SetSize(ScrW(), ScrH())
	self:SetVisible(false)
	self:SetKeyboardInputEnabled(true)
	self:SetMouseInputEnabled(true)
	self:SetPaintBackgroundEnabled(false)
	self.InitialFlow = false
	self.OpenedAt = 0
	self.ActiveCard = nil
	self.ResLayout = loadTeamMenuResLayout()
	self.MenuX, self.MenuY = 0, 0
	self.MenuW, self.MenuH = ScrW(), ScrH()
	self.HeaderH, self.FooterH = 75, 60

	local teamModelCandidates = {}
	local resModelName = self.ResLayout and self.ResLayout.menuModel and self.ResLayout.menuModel.modelName
	if isstring(resModelName) and resModelName ~= "" then
		teamModelCandidates[#teamModelCandidates + 1] = resModelName
	end
	teamModelCandidates[#teamModelCandidates + 1] = "models/vgui/ui_team01.mdl"
	teamModelCandidates[#teamModelCandidates + 1] = "models/vgui/UI_team01.mdl"
	local teamModelPath = findModelPath(teamModelCandidates)
	self.Has3D = teamModelPath ~= nil
	tsLog("Init: teamModelPath=" .. tostring(teamModelPath) .. " Has3D=" .. tostring(self.Has3D))

	if self.Has3D then
		local modelLower = string.lower(tostring(teamModelPath or ""))
		local isTeamSceneModel = string.find(modelLower, "ui_team01", 1, true) ~= nil
		-- ui_team01 behaves like a scene model; use DModelPanel with bounds framing.
		-- Other models keep the same ClassModelPanel path as class select.
		if isTeamSceneModel then
			self.TeamMenuBG = vgui.Create("DModelPanel", self)
			self.TeamMenuBG:SetModel(teamModelPath)
			self.TeamMenuBG:SetFOV(35)
			self.TeamMenuBG.LayoutEntity = function(_, ent)
				if not IsValid(ent) then return end
				ent:SetPos(vector_origin)
				ent:SetAngles(Angle(0, 180, 0))
			end
			self.TeamMenuBG.Paint = function(pnl, w, h)
				surface.SetDrawColor(0, 0, 0, 255)
				surface.DrawRect(0, 0, w, h)
				if not IsValid(pnl.Entity) then return end
				pnl:DrawModel()
			end
		else
			self.TeamMenuBG = vgui.Create("ClassModelPanel", self)
			self.TeamMenuBG.FOV = 50
			self.TeamMenuBG.spotlight = true
			self.TeamMenuBG.disable_manipulation = true
		end
		self.TeamMenuBG:SetMouseInputEnabled(false)
		self.TeamMenuBG:SetKeyboardInputEnabled(false)

		local mdl = (self.ResLayout and self.ResLayout.menuModel) or {}
		if isTeamSceneModel then
			timer.Simple(0, function()
				if not IsValid(self) or not IsValid(self.TeamMenuBG) or not IsValid(self.TeamMenuBG.Entity) then return end
				local ent = self.TeamMenuBG.Entity
				local mn, mx = ent:GetRenderBounds()
				local center = (mn + mx) * 0.5
				local size = 0
				size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
				size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
				size = math.max(size, math.abs(mn.z) + math.abs(mx.z))
				local dist = math.max(200, size * 1.1)
				self.TeamMenuBG:SetLookAt(center)
				self.TeamMenuBG:SetCamPos(center + Vector(dist, dist * 0.08, dist * 0.04))
				tsLog(string.format("Team scene camera framed size=%.2f dist=%.2f", size, dist))
			end)
			tsLog("Team scene model renderer active: " .. tostring(teamModelPath))
		else
			local addedEnt = self.TeamMenuBG:AddModel(1, teamModelPath, {
				Pos = Vector(mdl.originX or 190, mdl.originY or 0, mdl.originZ or -36),
				Ang = Angle(mdl.anglesX or 0, mdl.anglesY or 200, mdl.anglesZ or 0),
			})
			tsLog("ClassModelPanel team background active: " .. tostring(teamModelPath) .. " valid=" .. tostring(IsValid(addedEnt)))
		end
	end

	self.RedButton = vgui.Create("TFButton", self)
	self.RedButton.teamKey = "red"
	self.RedButton.teamID = TEAM_RED
	self.RedButton.UseResHotspot = true
	applyActionButtonStyle(self.RedButton, cardStyle.red)
	self.RedButton.DoClick = function()
		self:JoinTeam(TEAM_RED)
	end

	self.AutoButton = vgui.Create("TFButton", self)
	self.AutoButton.teamKey = "auto"
	self.AutoButton.teamID = TEAM_UNASSIGNED
	self.AutoButton.UseResHotspot = true
	applyActionButtonStyle(self.AutoButton, cardStyle.auto)
	self.AutoButton.DoClick = function()
		self:JoinTeam(TEAM_UNASSIGNED)
	end

	self.SpecButton = vgui.Create("TFButton", self)
	self.SpecButton.teamKey = "spec"
	self.SpecButton.teamID = TEAM_SPECTATOR
	self.SpecButton.UseResHotspot = true
	applyActionButtonStyle(self.SpecButton, cardStyle.spec)
	self.SpecButton.DoClick = function()
		self:JoinTeam(TEAM_SPECTATOR)
	end

	self.BluButton = vgui.Create("TFButton", self)
	self.BluButton.teamKey = "blu"
	self.BluButton.teamID = TEAM_BLU
	self.BluButton.UseResHotspot = true
	applyActionButtonStyle(self.BluButton, cardStyle.blu)
	self.BluButton.DoClick = function()
		self:JoinTeam(TEAM_BLU)
	end

	self.CloseButton = vgui.Create("TFButton", self)
	self.CloseButton.labelText = (self.ResLayout and self.ResLayout.closeLabel) or "CLOSE"
	self.CloseButton.font = (self.ResLayout and self.ResLayout.closeFont) or "HudFontSmallBold"
	applyActionButtonStyle(self.CloseButton, cardStyle.neutral)
	self.CloseButton.DoClick = function()
		if self.InitialFlow then return end
		self:ClosePanel("close_button")
	end
end

function PANEL:OpenPanel()
	self:SetSize(ScrW(), ScrH())
	self:SetVisible(true)
	self:MakePopup()
	self:SetKeyboardInputEnabled(true)
	self:SetMouseInputEnabled(true)
	gui.EnableScreenClicker(true)
	self.OpenedAt = CurTime()
	self.ActiveCard = nil
	tsLog("OpenPanel: visible=true Has3D=" .. tostring(self.Has3D))
end

function PANEL:ClosePanel(reason)
	self:SetVisible(false)
	self:SetKeyboardInputEnabled(false)
	self:SetMouseInputEnabled(false)
	gui.EnableScreenClicker(false)
	tsLog("ClosePanel reason=" .. tostring(reason))
end

function PANEL:OnKeyCodePressed(key)
	if key == KEY_ESCAPE then
		if self.InitialFlow then return end
		self:ClosePanel("esc")
		return
	end

	-- TF2 TeamMenu parity: 1=Auto, 2=Spectate, 3=BLU, 4=RED
	if key == KEY_1 or key == KEY_PAD_1 then
		playButtonClick()
		self:JoinTeam(TEAM_UNASSIGNED)
	elseif key == KEY_2 or key == KEY_PAD_2 then
		playButtonClick()
		self:JoinTeam(TEAM_SPECTATOR)
	elseif key == KEY_3 or key == KEY_PAD_3 then
		playButtonClick()
		self:JoinTeam(TEAM_BLU)
	elseif key == KEY_4 or key == KEY_PAD_4 then
		playButtonClick()
		self:JoinTeam(TEAM_RED)
	end
end

function PANEL:PerformLayout()
	local w, h = ScrW(), ScrH()
	self:SetSize(w, h)

	local menuH = h
	local menuW = math.floor(menuH * (4 / 3))
	local menuX = math.floor((w - menuW) * 0.5)
	local menuY = 0
	local uiScale = menuH / TFUI_BASE_H

	self.MenuX, self.MenuY = menuX, menuY
	self.MenuW, self.MenuH = menuW, menuH
	self.ContentY, self.ContentH = menuY, menuH
	self.HeaderH, self.FooterH = math.floor(75 * uiScale), math.floor(60 * uiScale)

	if IsValid(self.TeamMenuBG) then
		local bgRect = self.ResLayout and self.ResLayout.menuBG or {x = 0, y = 0, w = TFUI_BASE_W, h = TFUI_BASE_H}
		self.TeamMenuBG:SetPos(menuX + math.floor(bgRect.x * uiScale), menuY + math.floor(bgRect.y * uiScale))
		self.TeamMenuBG:SetSize(math.floor(bgRect.w * uiScale), math.floor(bgRect.h * uiScale))
	end

	local autoRect = self.ResLayout and self.ResLayout.auto or {x = 30, y = 101, w = 124, h = 310}
	local redRect = self.ResLayout and self.ResLayout.red or {x = 479, y = 101, w = 124, h = 310}
	local bluRect = self.ResLayout and self.ResLayout.blu or {x = 291, y = 101, w = 124, h = 310}
	local specRect = self.ResLayout and self.ResLayout.spec or {x = 180, y = 232, w = 82, h = 57}
	local closeRect = self.ResLayout and self.ResLayout.cancel or {x = 450, y = 440, w = 150, h = 30}

	self.AutoButton:SetPos(menuX + math.floor(autoRect.x * uiScale), menuY + math.floor(autoRect.y * uiScale))
	self.AutoButton:SetSize(math.floor(autoRect.w * uiScale), math.floor(autoRect.h * uiScale))

	self.RedButton:SetPos(menuX + math.floor(redRect.x * uiScale), menuY + math.floor(redRect.y * uiScale))
	self.RedButton:SetSize(math.floor(redRect.w * uiScale), math.floor(redRect.h * uiScale))

	self.BluButton:SetPos(menuX + math.floor(bluRect.x * uiScale), menuY + math.floor(bluRect.y * uiScale))
	self.BluButton:SetSize(math.floor(bluRect.w * uiScale), math.floor(bluRect.h * uiScale))

	self.SpecButton:SetPos(menuX + math.floor(specRect.x * uiScale), menuY + math.floor(specRect.y * uiScale))
	self.SpecButton:SetSize(math.floor(specRect.w * uiScale), math.floor(specRect.h * uiScale))

	self.CloseButton:SetPos(menuX + math.floor(closeRect.x * uiScale), menuY + math.floor(closeRect.y * uiScale))
	self.CloseButton:SetSize(math.floor(closeRect.w * uiScale), math.floor(closeRect.h * uiScale))

	self.CardW = math.floor(redRect.w * uiScale)
	self.CardH = math.floor(redRect.h * uiScale)
	tsLog("PerformLayout: res-driven menu=" .. tostring(menuW) .. "x" .. tostring(menuH) .. " at " .. tostring(menuX) .. "," .. tostring(menuY))
end

function PANEL:DrawCardText(button, style, label, countText)
	if not IsValid(button) then return end
	local x, y = button:GetPos()
	local w, h = button:GetSize()
	local titleY = y + math.floor(h * 0.08)
	local countY = y + math.floor(h * 0.17)
	local hintY = y + h - math.floor(h * 0.08)

	local titleCol = Color(235, 226, 202, 255)
	if self.ActiveCard == button.teamKey then
		titleCol = Color(255, 245, 220, 255)
	end

	draw.Text{
		text = label,
		font = "HudFontMediumBold",
		pos = {x + w * 0.5, titleY},
		color = titleCol,
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}
	draw.Text{
		text = countText,
		font = "HudFontSmall",
		pos = {x + w * 0.5, countY},
		color = Color(230, 220, 202, 255),
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}
	draw.Text{
		text = "[" .. style.key .. "]",
		font = "HudFontSmallBold",
		pos = {x + w * 0.5, hintY},
		color = Color(225, 218, 205, 220),
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}
end

function PANEL:Paint(w, h)
	surface.SetDrawColor(20, 19, 19, 240)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(255, 255, 255, 255)
	tf_draw.TexturedQuadTiled(loadout_header, 0, 0, w, self.HeaderH or 75)
	surface.SetTexture(loadout_solid_line)
	surface.DrawTexturedRect(0, self.HeaderH or 75, w, 10)

	local contentY = self.ContentY or 75
	local contentH = self.ContentH or (h - 135)
	surface.SetDrawColor(19, 18, 17, 90)
	surface.DrawRect(0, contentY, w, contentH)

	local menuX = self.MenuX or 0
	local menuY = self.MenuY or contentY
	local menuW = self.MenuW or w
	local menuH = self.MenuH or contentH

	local leftBarW = math.max(0, menuX)
	local rightBarX = math.max(0, menuX + menuW)
	local rightBarW = math.max(0, w - rightBarX)
	surface.SetDrawColor(10, 10, 10, 255)
	if leftBarW > 0 then
		surface.DrawRect(0, contentY, leftBarW, contentH)
	end
	if rightBarW > 0 then
		surface.DrawRect(rightBarX, contentY, rightBarW, contentH)
	end

	if not self.Has3D then
		drawVerticalGradient(
			menuX,
			menuY,
			menuW,
			menuH,
			Color(58, 52, 45, 255),
			Color(23, 21, 20, 255)
		)
		surface.SetDrawColor(90, 80, 68, 255)
		surface.DrawOutlinedRect(menuX, menuY, menuW, menuH, 2)
	end

	tf_draw.TexturedQuadTiled(loadout_bottom_gradient, 0, h - (self.FooterH or 60), w, self.FooterH or 60)
	surface.SetTexture(loadout_solid_line)
	surface.DrawTexturedRect(0, h - (self.FooterH or 60), w, 10)

	local uiScale = (menuH or h) / TFUI_BASE_H
	local title = self.ResLayout and self.ResLayout.title or {x = 30, y = 440, font = "HudFontMediumBold", text = "TEAM SELECT"}

	draw.Text{
		text = title.text or "TEAM SELECT",
		font = title.font or "HudFontMediumBold",
		pos = {menuX + math.floor((title.x or 30) * uiScale), menuY + math.floor((title.y or 440) * uiScale)},
		color = Color(235, 226, 202, 255),
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}
	draw.Text{
		text = getMapSubtitle(),
		font = "HudFontSmallBold",
		pos = {menuX + math.floor((title.x or 30) * uiScale), menuY + math.floor(((title.y or 440) - 26) * uiScale)},
		color = Color(235, 226, 202, 255),
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_TOP,
	}

	local res = self.ResLayout or {}
	local function drawResLabel(lbl, color)
		if not lbl then return end
		local lx = (self.MenuX or 0) + math.floor((lbl.x or 0) * uiScale)
		local ly = (self.MenuY or 0) + math.floor((lbl.y or 0) * uiScale)
		local lw = math.floor((lbl.w or 80) * uiScale)
		local lh = math.floor((lbl.h or 20) * uiScale)
		local ax = TEXT_ALIGN_CENTER
		if lbl.align == "west" or lbl.align == "northwest" or lbl.align == "southwest" then
			ax = TEXT_ALIGN_LEFT
		elseif lbl.align == "east" or lbl.align == "northeast" or lbl.align == "southeast" then
			ax = TEXT_ALIGN_RIGHT
		end
		local tx = lx + (ax == TEXT_ALIGN_LEFT and 0 or (ax == TEXT_ALIGN_RIGHT and lw or lw * 0.5))
		draw.Text{
			text = string.upper(lbl.text or ""),
			font = lbl.font or "MenuSmallFont",
			pos = {tx, ly + lh * 0.5},
			color = color or Color(235, 226, 202, 255),
			xalign = ax,
			yalign = TEXT_ALIGN_CENTER,
		}
	end

	drawResLabel(res.autoLabel, Color(220, 216, 208, 255))
	drawResLabel(res.specLabel, Color(230, 226, 216, 255))
	drawResLabel(res.bluLabel, Color(208, 225, 247, 255))
	drawResLabel(res.redLabel, Color(242, 205, 194, 255))

	draw.Text{
		text = string.format("1. AUTO    2. SPECTATE    3. BLU (%d)    4. RED (%d)", team.NumPlayers(TEAM_BLU), team.NumPlayers(TEAM_RED)),
		font = "MenuClassBuckets",
		pos = {w * 0.5, h - 36},
		color = Color(230, 225, 214, 255),
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}
end

function PANEL:OnRemove()
	gui.EnableScreenClicker(false)
end

vgui.Register("TFTeamSelectPanel", PANEL, "EditablePanel")

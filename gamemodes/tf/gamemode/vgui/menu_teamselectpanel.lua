local PANEL = {}

local loadout_header = surface.GetTextureID("vgui/loadout_header")
local loadout_bottom_gradient = surface.GetTextureID("vgui/loadout_bottom_gradient")
local loadout_solid_line = surface.GetTextureID("vgui/loadout_solid_line")
local gradient_down = Material("vgui/gradient_down")
local dbg = GetConVar("tf_teamselect_debug") or CreateClientConVar("tf_teamselect_debug", "1", true, false, "Enable TF2 team select debug logging.")
local uiRolloverSound = "ui/buttonrollover.wav"
local uiClickSound = "ui/buttonclick.wav"
local uiClickReleaseSound = "ui/buttonclickrelease.wav"

local cardStyle = {
	red = {
		base = Color(116, 52, 45, 245),
		hover = Color(151, 68, 59, 250),
		edge = Color(53, 27, 24, 255),
		shine = Color(255, 210, 190, 36),
		title = "RED TEAM",
		key = "1",
	},
	blu = {
		base = Color(59, 86, 112, 245),
		hover = Color(79, 112, 147, 250),
		edge = Color(30, 46, 63, 255),
		shine = Color(206, 234, 255, 34),
		title = "BLU TEAM",
		key = "2",
	},
	spec = {
		base = Color(110, 100, 89, 240),
		hover = Color(142, 129, 113, 245),
		edge = Color(59, 53, 45, 255),
		shine = Color(255, 255, 255, 26),
		title = "SPECTATOR",
		key = "3",
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

local function drawVerticalGradient(x, y, w, h, topColor, bottomColor)
	surface.SetDrawColor(topColor.r, topColor.g, topColor.b, topColor.a)
	surface.DrawRect(x, y, w, h)
	surface.SetMaterial(gradient_down)
	surface.SetDrawColor(bottomColor.r, bottomColor.g, bottomColor.b, bottomColor.a)
	surface.DrawTexturedRect(x, y, w, h)
end

local function applyActionButtonStyle(button, style)
	button.Hover = false
	button.disabled = false
	button:SetText("")

	function button:Paint(w, h)
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

	RunConsoleCommand("changeteam", tostring(teamID))
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

	local teamModelPath = findModelPath({
		"models/vgui/ui_team01.mdl",
		"models/vgui/UI_team01.mdl",
	})
	self.Has3D = teamModelPath ~= nil
	tsLog("Init: teamModelPath=" .. tostring(teamModelPath) .. " Has3D=" .. tostring(self.Has3D))

	if self.Has3D then
		self.TeamMenuBG = vgui.Create("DModelPanel", self)
		self.TeamMenuBG:SetModel(teamModelPath)
		self.TeamMenuBG:SetFOV(35)
		self.TeamMenuBG:SetCamPos(Vector(0, 0, -34))
		self.TeamMenuBG:SetLookAt(Vector(0, 0, 0))
		self.TeamMenuBG:SetAmbientLight(Color(180, 180, 180))
		self.TeamMenuBG:SetDirectionalLight(BOX_TOP, Color(255, 255, 255))
		self.TeamMenuBG:SetDirectionalLight(BOX_FRONT, Color(255, 255, 255))
		self.TeamMenuBG:SetDirectionalLight(BOX_RIGHT, Color(180, 180, 180))
		self.TeamMenuBG:SetMouseInputEnabled(false)
		self.TeamMenuBG:SetKeyboardInputEnabled(false)
		self.TeamMenuBG.LayoutEntity = function(_, ent)
			if not IsValid(ent) then return end
			ent:SetPos(Vector(290, 0, 0))
			ent:SetAngles(Angle(0, 180, 0))
		end
		self.TeamMenuBG.Paint = function(pnl, w, h)
			derma.SkinHook("Paint", "ModelPanel", pnl, w, h)
			if not IsValid(pnl.Entity) then return end
			pnl:DrawModel()
		end
	end

	self.RedButton = vgui.Create("TFButton", self)
	self.RedButton.teamKey = "red"
	self.RedButton.teamID = TEAM_RED
	applyActionButtonStyle(self.RedButton, cardStyle.red)
	self.RedButton.DoClick = function()
		self:JoinTeam(TEAM_RED)
	end

	self.SpecButton = vgui.Create("TFButton", self)
	self.SpecButton.teamKey = "spec"
	self.SpecButton.teamID = TEAM_SPECTATOR
	applyActionButtonStyle(self.SpecButton, cardStyle.spec)
	self.SpecButton.DoClick = function()
		self:JoinTeam(TEAM_SPECTATOR)
	end

	self.BluButton = vgui.Create("TFButton", self)
	self.BluButton.teamKey = "blu"
	self.BluButton.teamID = TEAM_BLU
	applyActionButtonStyle(self.BluButton, cardStyle.blu)
	self.BluButton.DoClick = function()
		self:JoinTeam(TEAM_BLU)
	end

	self.CloseButton = vgui.Create("TFButton", self)
	self.CloseButton.labelText = "CLOSE"
	self.CloseButton.font = "HudFontSmallBold"
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

	if key == KEY_1 or key == KEY_PAD_1 then
		playButtonClick()
		self:JoinTeam(TEAM_RED)
	elseif key == KEY_2 or key == KEY_PAD_2 then
		playButtonClick()
		self:JoinTeam(TEAM_BLU)
	elseif key == KEY_3 or key == KEY_PAD_3 then
		playButtonClick()
		self:JoinTeam(TEAM_SPECTATOR)
	end
end

function PANEL:PerformLayout()
	local w, h = ScrW(), ScrH()
	self:SetSize(w, h)

	local headerH = 75
	local footerH = 60
	local contentY = headerH
	local contentH = h - headerH - footerH
	local menuH = contentH
	local menuW = math.floor(menuH * (4 / 3))
	if menuW > w then
		menuW = w
		menuH = math.floor(menuW * (3 / 4))
	end
	local menuX = math.floor((w - menuW) * 0.5)
	local menuY = contentY + math.floor((contentH - menuH) * 0.5)

	self.MenuX, self.MenuY = menuX, menuY
	self.MenuW, self.MenuH = menuW, menuH
	self.ContentY, self.ContentH = contentY, contentH
	self.HeaderH, self.FooterH = headerH, footerH

	if IsValid(self.TeamMenuBG) then
		self.TeamMenuBG:SetPos(menuX, menuY)
		self.TeamMenuBG:SetSize(menuW, menuH)
	end

	local boardTop = menuY + math.floor(menuH * 0.17)
	local boardBottom = menuY + math.floor(menuH * 0.89)
	local cardH = math.max(100, boardBottom - boardTop)
	local edgePad = math.floor(menuW * 0.04)
	local gap = math.floor(menuW * 0.03)
	local cardW = math.floor((menuW - (edgePad * 2) - (gap * 2)) / 3)
	local startX = menuX + edgePad

	self.RedButton:SetPos(startX, boardTop)
	self.RedButton:SetSize(cardW, cardH)

	self.SpecButton:SetPos(startX + cardW + gap, boardTop)
	self.SpecButton:SetSize(cardW, cardH)

	self.BluButton:SetPos(startX + (cardW + gap) * 2, boardTop)
	self.BluButton:SetSize(cardW, cardH)

	self.CloseButton:SetPos(w - 136, h - 50)
	self.CloseButton:SetSize(120, 30)

	self.CardW = cardW
	self.CardH = cardH
	tsLog("PerformLayout: use3D=" .. tostring(self.Has3D) .. " menu=" .. tostring(menuW) .. "x" .. tostring(menuH) .. " at " .. tostring(menuX) .. "," .. tostring(menuY))
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
	surface.SetDrawColor(19, 18, 17, 245)
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

	draw.Text{
		text = "TEAM SELECT",
		font = "HudFontMediumBold",
		pos = {w * 0.07, 28},
		color = Color(235, 226, 202, 255),
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}
	draw.Text{
		text = getMapSubtitle(),
		font = "HudFontSmallBold",
		pos = {w * 0.07, 84},
		color = Color(235, 226, 202, 255),
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_TOP,
	}

	self:DrawCardText(self.RedButton, cardStyle.red, cardStyle.red.title, string.format("%d PLAYERS", team.NumPlayers(TEAM_RED)))
	self:DrawCardText(self.SpecButton, cardStyle.spec, cardStyle.spec.title, "WATCH THE MATCH")
	self:DrawCardText(self.BluButton, cardStyle.blu, cardStyle.blu.title, string.format("%d PLAYERS", team.NumPlayers(TEAM_BLU)))

	draw.Text{
		text = string.format("1. RED (%d)    2. BLU (%d)    3. SPECTATE", team.NumPlayers(TEAM_RED), team.NumPlayers(TEAM_BLU)),
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

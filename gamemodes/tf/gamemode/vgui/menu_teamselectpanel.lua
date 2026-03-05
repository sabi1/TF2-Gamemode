local PANEL = {}

local dbg = GetConVar("tf_teamselect_debug") or CreateClientConVar("tf_teamselect_debug", "1", true, false, "Enable TF2 team select debug logging.")

local loadout_header = surface.GetTextureID("vgui/loadout_header")
local loadout_bottom_gradient = surface.GetTextureID("vgui/loadout_bottom_gradient")
local loadout_solid_line = surface.GetTextureID("vgui/loadout_solid_line")

local function tsLog(msg)
	if dbg and dbg:GetBool() then
		MsgN("[TFTeamSelect] " .. tostring(msg))
	end
end

local function uiScale()
	return ScrH() / 480
end

local function getMapSubtitle()
	local map = string.lower(game.GetMap() or "unknown")
	if string.StartWith(map, "mvm_") then
		return "MANN VS MACHINE - CHOOSE A SIDE"
	end
	return "JOIN A TEAM"
end

local function createTeamSceneModelPanel(parent, modelPath, zpos)
	local pnl = vgui.Create("DModelPanel", parent)
	pnl:SetModel(modelPath)
	pnl:SetCamPos(Vector(90, 0, 40))
	pnl:SetPos(0, 0)
	pnl:SetFOV(70)
	pnl:SetZPos(zpos or -2)
	pnl:SetMouseInputEnabled(false)
	pnl:SetKeyboardInputEnabled(false)
	function pnl:LayoutEntity(_) return end
	function pnl:Paint(w, h)
		if not IsValid(self.Entity) then return end

		local x, y = self:LocalToScreen(0, 0)
		local ang = self.aLookAngle
		if not ang then
			ang = (self.vLookatPos - self.vCamPos):Angle()
		end

		cam.Start3D(self.vCamPos, ang, self.fFOV, x, y, w, h, 5, self.FarZ)
		render.SuppressEngineLighting(true)
		if TF2LightwarpApplyModelLighting then
			TF2LightwarpApplyModelLighting(self.Entity:GetPos() + Vector(0, 0, 68))
		else
			render.SetLightingOrigin(self.Entity:GetPos())
			render.ResetModelLighting(self.colAmbientLight.r / 255, self.colAmbientLight.g / 255, self.colAmbientLight.b / 255)
		end
		render.SetColorModulation(self.colColor.r / 255, self.colColor.g / 255, self.colColor.b / 255)
		render.SetBlend((self:GetAlpha() / 255) * (self.colColor.a / 255))

		if not TF2LightwarpApplyModelLighting then
			for i = 0, 6 do
				local col = self.DirectionalLight[i]
				if col then
					render.SetModelLighting(i, col.r / 255, col.g / 255, col.b / 255)
				end
			end
		end

		self:DrawModel()
		render.SuppressEngineLighting(false)
		cam.End3D()
	end
	return pnl
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

local function setupActionButton(btn, clickFn)
	btn.font = "HudFontMediumBold"
	function btn:OnCursorEntered()
		surface.PlaySound("ui/buttonrollover.wav")
	end
	function btn:DoClick()
		surface.PlaySound("ui/buttonclick.wav")
		timer.Simple(0.1, function()
			surface.PlaySound("ui/buttonclickrelease.wav")
		end)
		clickFn()
	end
	btn.Paint = function(self, w, h)
		if self:IsHovered() then
			surface.SetDrawColor(245, 240, 225, 24)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(245, 240, 225, 120)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end
	end
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:SetVisible(false)
	self:SetKeyboardInputEnabled(true)
	self:SetMouseInputEnabled(true)
	self.InitialFlow = false
	self.SceneModelPanels = {}

	local found = {}
	local seen = {}
	local patterns = {"models/vgui/ui_team01*.mdl", "models/vgui/UI_team01*.mdl"}
	for _, pattern in ipairs(patterns) do
		local files = file.Find(pattern, "GAME")
		for _, fname in ipairs(files or {}) do
			local full = "models/vgui/" .. fname
			local key = string.lower(full)
			if not seen[key] then
				seen[key] = true
				found[#found + 1] = full
			end
		end
	end

	table.sort(found, function(a, b)
		local al = string.lower(a)
		local bl = string.lower(b)
		if al == "models/vgui/ui_team01.mdl" then return true end
		if bl == "models/vgui/ui_team01.mdl" then return false end
		return al < bl
	end)

	if #found == 0 then
		found = {"models/vgui/ui_team01.mdl"}
	end

	for i, modelPath in ipairs(found) do
		local pnl = createTeamSceneModelPanel(self, modelPath, -2 + (i - 1))
		self.SceneModelPanels[#self.SceneModelPanels + 1] = pnl
		if i == 1 then
			self.ModelBG = pnl
		end
		tsLog("Team scene model layer: " .. tostring(modelPath))
	end

	self.AutoButton = vgui.Create("TFButton", self)
	self.AutoButton.labelText = "RANDOM"
	setupActionButton(self.AutoButton, function()
		self:JoinTeam(TEAM_UNASSIGNED)
	end)

	self.SpecButton = vgui.Create("TFButton", self)
	self.SpecButton.labelText = "SPECTATE"
	setupActionButton(self.SpecButton, function()
		self:JoinTeam(TEAM_SPECTATOR)
	end)

	self.BluButton = vgui.Create("TFButton", self)
	self.BluButton.labelText = "BLU"
	setupActionButton(self.BluButton, function()
		self:JoinTeam(TEAM_BLU)
	end)

	self.RedButton = vgui.Create("TFButton", self)
	self.RedButton.labelText = "RED"
	setupActionButton(self.RedButton, function()
		self:JoinTeam(TEAM_RED)
	end)

	self.CloseButton = vgui.Create("TFButton", self)
	self.CloseButton.labelText = "CLOSE"
	self.CloseButton.font = "HudFontSmallBold"
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
	tsLog("OpenPanel: visible=true")
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
		self:JoinTeam(TEAM_UNASSIGNED)
	elseif key == KEY_2 or key == KEY_PAD_2 then
		self:JoinTeam(TEAM_SPECTATOR)
	elseif key == KEY_3 or key == KEY_PAD_3 then
		self:JoinTeam(TEAM_BLU)
	elseif key == KEY_4 or key == KEY_PAD_4 then
		self:JoinTeam(TEAM_RED)
	end
end

function PANEL:PerformLayout()
	local w, h = ScrW(), ScrH()
	local s = uiScale()

	self:SetPos(0, 0)
	self:SetSize(w, h)

	if IsValid(self.ModelBG) then
		for _, pnl in ipairs(self.SceneModelPanels or {}) do
			if IsValid(pnl) then
				pnl:SetPos(0, 0)
				pnl:SetSize(w, h)
			end
		end
	end

	-- Team buttons at class-select column positions.
	local btnW = math.floor(124 * s)
	local btnH = math.floor(310 * s)
	local specW = math.floor(82 * s)
	local specH = math.floor(57 * s)
	local cx = w * 0.5
	local yTop = math.floor(101 * s)

	self.AutoButton:SetPos(math.floor(cx - 290 * s), yTop)
	self.AutoButton:SetSize(btnW, btnH)
	self.SpecButton:SetPos(math.floor(cx - 140 * s), math.floor(232 * s))
	self.SpecButton:SetSize(specW, specH)
	self.BluButton:SetPos(math.floor(cx - 29 * s), yTop)
	self.BluButton:SetSize(btnW, btnH)
	self.RedButton:SetPos(math.floor(cx + 159 * s), yTop)
	self.RedButton:SetSize(btnW, btnH)

	self.CloseButton:SetSize(math.floor(150 * s), math.floor(30 * s))
	self.CloseButton:SetPos(w - math.floor(190 * s), h - math.floor(40 * s))
end

function PANEL:Paint(w, h)
	local s = uiScale()

	-- Class-select style top and bottom bands.
	surface.SetDrawColor(255, 255, 255, 255)
	tf_draw.TexturedQuadTiled(loadout_header, 0, 0, w, math.floor(65 * s))
	surface.SetTexture(loadout_solid_line)
	surface.DrawTexturedRect(0, math.floor(65 * s), w, math.floor(10 * s))

	tf_draw.TexturedQuadTiled(loadout_bottom_gradient, 0, h - math.floor(60 * s), w, math.floor(60 * s))
	surface.SetTexture(loadout_solid_line)
	surface.DrawTexturedRect(0, h - math.floor(60 * s), w, math.floor(10 * s))

	draw.Text{
		text = ">>",
		font = "HudFontSmallestBold",
		pos = {math.floor(85 * s), math.floor(18 * s)},
		color = Color(200, 80, 60, 255),
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}

	draw.Text{
		text = getMapSubtitle(),
		font = "HudFontSmallestBold",
		pos = {math.floor(100 * s), math.floor(18 * s)},
		color = Color(117, 107, 94, 255),
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}

	draw.Text{
		text = "SELECT A TEAM",
		font = "HudFontMediumBold",
		pos = {math.floor(85 * s), h - math.floor(34 * s)},
		color = Color(235, 226, 202, 255),
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}

	draw.Text{
		text = string.format("1. AUTO    2. SPECTATE    3. BLU (%d)    4. RED (%d)", team.NumPlayers(TEAM_BLU), team.NumPlayers(TEAM_RED)),
		font = "MenuClassBuckets",
		pos = {w * 0.5, h - math.floor(18 * s)},
		color = Color(230, 225, 214, 255),
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}
end

function PANEL:OnRemove()
	gui.EnableScreenClicker(false)
end

vgui.Register("TFTeamSelectPanel", PANEL, "EditablePanel")

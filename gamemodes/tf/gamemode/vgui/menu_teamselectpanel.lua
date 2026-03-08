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

local function playClickSounds()
	surface.PlaySound("ui/buttonclick.wav")
	timer.Simple(0.1, function()
		surface.PlaySound("ui/buttonclickrelease.wav")
	end)
end

local function getDirectChildByKey(node, key)
	if not node or not node.children then return nil end
	for _, child in ipairs(node.children) do
		if child.key == key then
			return child
		end
	end
	return nil
end

local function getDirectChildrenByKey(node, key)
	local out = {}
	if not node or not node.children then return out end
	for _, child in ipairs(node.children) do
		if child.key == key then
			out[#out + 1] = child
		end
	end
	return out
end

local function fieldNameForModelPath(path)
	local p = string.lower(tostring(path or ""))
	if string.find(p, "ui_team01_random", 1, true) then return "autodoor" end
	if string.find(p, "ui_team01_spectate", 1, true) then return "spectate" end
	if string.find(p, "ui_team01_blue", 1, true) then return "bluedoor" end
	if string.find(p, "ui_team01_red", 1, true) then return "reddoor" end
	if string.find(p, "ui_team01.mdl", 1, true) then return "menubg" end
	return nil
end

local function loadTeamMenuResAnimations()
	local out = {
		fields = {},
		buttonModels = {
			auto = "autodoor",
			spec = "spectate",
			blu = "bluedoor",
			red = "reddoor",
		},
	}
	if not TF2Res or not TF2Res.Load then return out end

	local tree = TF2Res.Load("resource/ui/teammenu.res") or TF2Res.Load("resource/ui/TeamMenu.res") or TF2Res.Load("resource/ui/teammenu_sc.res")
	if not tree then return out end

	local function readButtonModel(fieldName, role)
		local node = TF2Res.FindByFieldName(tree, fieldName)
		if not node then return end
		local assoc = string.lower(TF2Res.GetString(node, "associated_model", out.buttonModels[role] or ""))
		if assoc ~= "" then
			out.buttonModels[role] = assoc
		end
	end

	readButtonModel("teambutton2", "auto")
	readButtonModel("teambutton3", "spec")
	readButtonModel("teambutton0", "blu")
	readButtonModel("teambutton1", "red")

	for _, fieldName in ipairs({"MenuBG", "autodoor", "spectate", "bluedoor", "reddoor"}) do
		local node = TF2Res.FindByFieldName(tree, fieldName)
		if node then
			local modelNode = getDirectChildByKey(node, "model") or TF2Res.FindByKey(node, "model")
			if modelNode then
				local animMap = {}
				local defaultSequence = nil
				for _, animNode in ipairs(getDirectChildrenByKey(modelNode, "animation")) do
					local name = string.lower(TF2Res.GetString(animNode, "name", ""))
					local sequence = TF2Res.GetString(animNode, "sequence", "")
					if name ~= "" and sequence ~= "" then
						animMap[name] = sequence
						if TF2Res.GetString(animNode, "default", "0") == "1" then
							defaultSequence = sequence
						end
					end
				end

				local key = string.lower(fieldName)
				out.fields[key] = {
					animations = animMap,
					defaultSequence = defaultSequence,
				}
			end
		end
	end

	return out
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
		render.SetLightingOrigin(self.Entity:GetPos())
		render.ResetModelLighting(self.colAmbientLight.r / 255, self.colAmbientLight.g / 255, self.colAmbientLight.b / 255)
		render.SetColorModulation(self.colColor.r / 255, self.colColor.g / 255, self.colColor.b / 255)
		render.SetBlend((self:GetAlpha() / 255) * (self.colColor.a / 255))

		for i = 0, 6 do
			local col = self.DirectionalLight[i]
			if col then
				render.SetModelLighting(i, col.r / 255, col.g / 255, col.b / 255)
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
		if IsValid(self:GetParent()) and self.RoleKey then
			self:GetParent():SetHoveredRole(self.RoleKey)
		end
	end
	function btn:OnCursorExited()
		if IsValid(self:GetParent()) and self.RoleKey then
			self:GetParent():ClearHoveredRole(self.RoleKey)
		end
	end
	function btn:DoClick()
		playClickSounds()
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
	self.ActiveHoverRole = nil
	self.SceneModelPanels = {}
	self.ModelPanelsByField = {}
	self.ResAnimations = loadTeamMenuResAnimations()

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
		local fieldName = fieldNameForModelPath(modelPath)
		if fieldName then
			pnl.FieldName = fieldName
			pnl.AnimData = self.ResAnimations and self.ResAnimations.fields and self.ResAnimations.fields[fieldName] or nil
			pnl.AllowPassiveAnim = fieldName ~= "menubg"
			self.ModelPanelsByField[fieldName] = pnl
		end
		self.SceneModelPanels[#self.SceneModelPanels + 1] = pnl
		if i == 1 or fieldName == "menubg" then
			self.ModelBG = pnl
		end
		tsLog("Team scene model layer: " .. tostring(modelPath))
	end

	self.AutoButton = vgui.Create("TFButton", self)
	self.AutoButton.labelText = "RANDOM"
	self.AutoButton.RoleKey = "auto"
	setupActionButton(self.AutoButton, function()
		self:JoinTeam(TEAM_UNASSIGNED)
	end)

	self.SpecButton = vgui.Create("TFButton", self)
	self.SpecButton.labelText = "SPECTATE"
	self.SpecButton.RoleKey = "spec"
	setupActionButton(self.SpecButton, function()
		self:JoinTeam(TEAM_SPECTATOR)
	end)

	self.BluButton = vgui.Create("TFButton", self)
	self.BluButton.labelText = "BLU"
	self.BluButton.RoleKey = "blu"
	setupActionButton(self.BluButton, function()
		self:JoinTeam(TEAM_BLU)
	end)

	self.RedButton = vgui.Create("TFButton", self)
	self.RedButton.labelText = "RED"
	self.RedButton.RoleKey = "red"
	setupActionButton(self.RedButton, function()
		self:JoinTeam(TEAM_RED)
	end)

	self.CloseButton = vgui.Create("TFButton", self)
	self.CloseButton.labelText = "CLOSE"
	self.CloseButton.font = "HudFontSmallBold"
	self.CloseButton.OnCursorEntered = function()
		surface.PlaySound("ui/buttonrollover.wav")
	end
	self.CloseButton.DoClick = function()
		if self.InitialFlow then return end
		playClickSounds()
		self:ClosePanel("close_button")
	end
end

function PANEL:SetModelStateByField(fieldName, phase)
	local panel = self.ModelPanelsByField and self.ModelPanelsByField[string.lower(fieldName or "")]
	if not IsValid(panel) then return end

	local animData = panel.AnimData or {}
	local anim = animData.animations or {}
	local idle = anim.idle_enabled or anim.idle or animData.defaultSequence or "idle"
	local hover = anim.hover_enabled or anim.hover or anim.hover_disabled or nil

	local function setAnim(seqName, queueName, holdLast)
		panel.DesiredSequence = seqName
		panel.QueuedSequence = queueName
		panel.SequenceDeadline = nil
		panel.PendingReset = true
		panel.HoldLastFrame = holdLast and true or false
		panel.HoldDeadline = nil
		panel.FrozenAtEnd = false
	end

	if phase == "tv_hover" then
		setAnim(anim.hover or "hover", nil, true)
		return
	elseif phase == "tv_idle" then
		panel.DesiredSequence = nil
		panel.QueuedSequence = nil
		panel.SequenceDeadline = nil
		panel.HoldDeadline = nil
		panel.HoldLastFrame = false
		panel.PendingReset = false
		panel.FrozenAtEnd = true
		if IsValid(panel.Entity) then
			panel.Entity:SetPlaybackRate(0)
		end
		return
	end

	if phase == "enter" then
		local enter = anim.enter_enabled or anim.enter
		if enter then
			setAnim(enter, nil, true)
		else
			setAnim(hover or idle, nil, false)
		end
	elseif phase == "exit" then
		local exit = anim.exit_enabled or anim.exit
		if exit and exit ~= idle then
			setAnim(exit, idle, false)
		else
			setAnim(idle, nil, false)
		end
	else
		setAnim(idle, nil, false)
	end
end

function PANEL:SetHoveredRole(roleKey)
	if self.ActiveHoverRole == roleKey then return end

	if self.ActiveHoverRole then
		local prevField = self.ResAnimations and self.ResAnimations.buttonModels and self.ResAnimations.buttonModels[self.ActiveHoverRole]
		if prevField then
			self:SetModelStateByField(prevField, "exit")
		end
	end

	self.ActiveHoverRole = roleKey
	local fieldName = self.ResAnimations and self.ResAnimations.buttonModels and self.ResAnimations.buttonModels[roleKey]
	if fieldName then
		self:SetModelStateByField(fieldName, "enter")
	end
	self:SetModelStateByField("menubg", "tv_hover")
end

function PANEL:ClearHoveredRole(roleKey)
	if self.ActiveHoverRole ~= roleKey then return end
	local fieldName = self.ResAnimations and self.ResAnimations.buttonModels and self.ResAnimations.buttonModels[roleKey]
	if fieldName then
		self:SetModelStateByField(fieldName, "exit")
	end
	self.ActiveHoverRole = nil
	self:SetModelStateByField("menubg", "tv_idle")
end

function PANEL:ResetAllModelStates()
	if not self.ResAnimations or not self.ResAnimations.buttonModels then return end
	for _, fieldName in pairs(self.ResAnimations.buttonModels) do
		self:SetModelStateByField(fieldName, "idle")
	end
end

function PANEL:OpenPanel()
	self:SetSize(ScrW(), ScrH())
	self:SetVisible(true)
	self:MakePopup()
	self:SetKeyboardInputEnabled(true)
	self:SetMouseInputEnabled(true)
	gui.EnableScreenClicker(true)
	self.ActiveHoverRole = nil
	self:ResetAllModelStates()
	tsLog("OpenPanel: visible=true")
end

function PANEL:Think()
	for _, panel in ipairs(self.SceneModelPanels or {}) do
		if IsValid(panel) and IsValid(panel.Entity) then
			local ent = panel.Entity
			local animData = panel.AnimData or {}
			local anim = animData.animations or {}

			if not panel.BootSequenceApplied then
				local boot = animData.defaultSequence or anim.idle_enabled or anim.idle or "idle"
				local bootIdx = ent:LookupSequence(boot)
				if bootIdx and bootIdx >= 0 then
					ent:ResetSequence(bootIdx)
				else
					ent:ResetSequence(0)
				end

				local tvGlowIdx = ent:FindBodygroupByName("tvglow")
				if isnumber(tvGlowIdx) and tvGlowIdx >= 0 then
					ent:SetBodygroup(tvGlowIdx, 1)
				end

				ent:SetPlaybackRate(panel.AllowPassiveAnim and 1 or 0)
				panel.BootSequenceApplied = true
			end

			if panel.DesiredSequence then
				if panel.HoldLastFrame and panel.HoldDeadline and CurTime() >= panel.HoldDeadline then
					ent:SetCycle(1)
					ent:SetPlaybackRate(0)
					panel.FrozenAtEnd = true
				end

				if panel.SequenceDeadline and CurTime() >= panel.SequenceDeadline then
					panel.DesiredSequence = panel.QueuedSequence
					panel.QueuedSequence = nil
					panel.SequenceDeadline = nil
					panel.PendingReset = true
				end

				local seqIndex = ent:LookupSequence(panel.DesiredSequence)
				if seqIndex and seqIndex >= 0 then
					if panel.PendingReset or panel.ActiveSequence ~= panel.DesiredSequence then
						ent:ResetSequence(seqIndex)
						ent:SetCycle(0)
						ent:SetPlaybackRate(1)
						panel.ActiveSequence = panel.DesiredSequence
						panel.PendingReset = false
						panel.FrozenAtEnd = false

						if panel.HoldLastFrame then
							local holdDur = ent:SequenceDuration(seqIndex)
							panel.HoldDeadline = CurTime() + (holdDur > 0 and holdDur or 0.2)
						else
							panel.HoldDeadline = nil
						end

						if panel.QueuedSequence then
							local dur = ent:SequenceDuration(seqIndex)
							panel.SequenceDeadline = CurTime() + (dur > 0 and dur or 0.2)
						end
					end
				end
			end

			if not panel.FrozenAtEnd and (panel.DesiredSequence or panel.AllowPassiveAnim) then
				ent:FrameAdvance(RealFrameTime())
			end
		end
	end
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
		playClickSounds()
		self:ClosePanel("esc")
		return
	end

	if key == KEY_1 or key == KEY_PAD_1 then
		playClickSounds()
		self:JoinTeam(TEAM_UNASSIGNED)
	elseif key == KEY_2 or key == KEY_PAD_2 then
		playClickSounds()
		self:JoinTeam(TEAM_SPECTATOR)
	elseif key == KEY_3 or key == KEY_PAD_3 then
		playClickSounds()
		self:JoinTeam(TEAM_BLU)
	elseif key == KEY_4 or key == KEY_PAD_4 then
		playClickSounds()
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

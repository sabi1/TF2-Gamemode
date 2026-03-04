local PANEL = {}

local dbg = GetConVar("tf_teamselect_debug") or CreateClientConVar("tf_teamselect_debug", "1", true, false, "Enable TF2 team select debug logging.")

local loadout_header = surface.GetTextureID("vgui/loadout_header")
local loadout_bottom_gradient = surface.GetTextureID("vgui/loadout_bottom_gradient")
local loadout_solid_line = surface.GetTextureID("vgui/loadout_solid_line")

local TFUI_BASE_W = 640
local TFUI_BASE_H = 480

local SND_ROLLOVER = "ui/buttonrollover.wav"
local SND_CLICK = "ui/buttonclick.wav"
local SND_CLICK_RELEASE = "ui/buttonclickrelease.wav"

local function tsLog(msg)
	if dbg and dbg:GetBool() then
		MsgN("[TFTeamSelect] " .. tostring(msg))
	end
end

local function playClickSounds()
	surface.PlaySound(SND_CLICK)
	timer.Simple(0.1, function()
		surface.PlaySound(SND_CLICK_RELEASE)
	end)
end

local function getMapSubtitle()
	local map = string.lower(game.GetMap() or "unknown")
	if string.StartWith(map, "mvm_") then
		return "MANN VS MACHINE - CHOOSE A SIDE"
	end
	return "JOIN A TEAM"
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

local function parseHotkeyLabel(text)
	if not isstring(text) or text == "" then return nil end
	return string.match(text, "&(%d)")
end

local function parseTeamFromCommand(command)
	local cmd = string.lower(command or "")
	if string.find(cmd, "spect", 1, true) then return TEAM_SPECTATOR end
	if string.find(cmd, "auto", 1, true) then return TEAM_UNASSIGNED end
	if string.find(cmd, "blue", 1, true) or string.find(cmd, "blu", 1, true) then return TEAM_BLU end
	if string.find(cmd, "red", 1, true) then return TEAM_RED end
	return nil
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

local function parseModelLayer(tree, fieldName, defaults)
	local node = TF2Res.FindByFieldName(tree, fieldName)
	if not node then return nil end

	local modelNode = getDirectChildByKey(node, "model") or TF2Res.FindByKey(node, "model")
	if not modelNode then return nil end

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

	local modelPath = TF2Res.GetString(modelNode, "modelname", defaults.modelPath)
	if not isstring(modelPath) or modelPath == "" then
		return nil
	end

	return {
		fieldName = fieldName,
		zpos = TF2Res.GetNumber(node, "zpos", defaults.zpos or 0),
		rect = readRect(node, defaults.x or 0, defaults.y or 0, defaults.w or TFUI_BASE_W, defaults.h or TFUI_BASE_H),
		fov = TF2Res.GetNumber(node, "fov", defaults.fov or 20),
		modelPath = modelPath,
		origin = Vector(
			TF2Res.GetNumber(modelNode, "origin_x", defaults.originX or 290),
			TF2Res.GetNumber(modelNode, "origin_y", defaults.originY or 0),
			TF2Res.GetNumber(modelNode, "origin_z", defaults.originZ or -34)
		),
		angles = Angle(
			TF2Res.GetNumber(modelNode, "angles_x", defaults.anglesX or 0),
			TF2Res.GetNumber(modelNode, "angles_y", defaults.anglesY or 180),
			TF2Res.GetNumber(modelNode, "angles_z", defaults.anglesZ or 0)
		),
		animations = animMap,
		defaultSequence = defaultSequence,
	}
end

local function loadTeamMenuResLayout()
	if not TF2Res or not TF2Res.Load then return nil end

	local tree = TF2Res.Load("resource/ui/teammenu.res") or TF2Res.Load("resource/ui/TeamMenu.res") or TF2Res.Load("resource/ui/teammenu_sc.res")
	if not tree then return nil end

	local btnBlue = TF2Res.FindByFieldName(tree, "teambutton0")
	local btnRed = TF2Res.FindByFieldName(tree, "teambutton1")
	local btnAuto = TF2Res.FindByFieldName(tree, "teambutton2")
	local btnSpec = TF2Res.FindByFieldName(tree, "teambutton3")
	local cancelNode = TF2Res.FindByFieldName(tree, "CancelButton")
	local titleNode = TF2Res.FindByFieldName(tree, "TeamMenuSelect")
	local autoLabelNode = TF2Res.FindByFieldName(tree, "TeamMenuAuto")
	local bluLabelNode = TF2Res.FindByFieldName(tree, "TeamMenuBlu")
	local redLabelNode = TF2Res.FindByFieldName(tree, "TeamMenuRed")
	local specLabelNode = TF2Res.FindByFieldName(tree, "TeamMenuSpectate")
	local blueCountNode = TF2Res.FindByFieldName(tree, "BlueCount")
	local redCountNode = TF2Res.FindByFieldName(tree, "RedCount")

	local function readButton(node, defaults, fallbackName)
		if not node then
			return {
				rect = {x = defaults.x, y = defaults.y, w = defaults.w, h = defaults.h},
				command = defaults.command,
				teamID = defaults.teamID,
				associatedModel = defaults.associatedModel,
				tabPosition = defaults.tabPosition,
				hotkey = defaults.hotkey,
				title = fallbackName,
			}
		end

		local command = TF2Res.GetString(node, "command", defaults.command)
		local hotkey = parseHotkeyLabel(TF2Res.GetString(node, "labelText", "")) or defaults.hotkey
		return {
			rect = readRect(node, defaults.x, defaults.y, defaults.w, defaults.h),
			command = command,
			teamID = parseTeamFromCommand(command) or defaults.teamID,
			associatedModel = TF2Res.GetString(node, "associated_model", defaults.associatedModel),
			tabPosition = TF2Res.GetNumber(node, "tabPosition", defaults.tabPosition),
			hotkey = hotkey,
			title = fallbackName,
		}
	end

	local layers = {}
	local function addLayer(fieldName, defaults)
		local layer = parseModelLayer(tree, fieldName, defaults)
		if layer then
			layers[#layers + 1] = layer
		end
	end

	addLayer("MenuBG", {modelPath = "models/vgui/UI_team01.mdl", zpos = 0, fov = 40})
	addLayer("autodoor", {modelPath = "models/vgui/UI_team01_random.mdl", zpos = 2, fov = 20})
	addLayer("spectate", {modelPath = "models/vgui/UI_team01_spectate.mdl", zpos = 2, fov = 20})
	addLayer("bluedoor", {modelPath = "models/vgui/UI_team01_blue.mdl", zpos = 2, fov = 20})
	addLayer("reddoor", {modelPath = "models/vgui/UI_team01_red.mdl", zpos = 2, fov = 20})

	table.sort(layers, function(a, b)
		if a.zpos == b.zpos then
			return tostring(a.fieldName) < tostring(b.fieldName)
		end
		return a.zpos < b.zpos
	end)

	local modelByField = {}
	for _, layer in ipairs(layers) do
		modelByField[string.lower(layer.fieldName)] = layer
	end

	return {
		menuRect = readRect(TF2Res.FindByFieldName(tree, "team"), 0, 0, TFUI_BASE_W, TFUI_BASE_H),
		title = {
			x = parseResCoord(TF2Res.GetString(titleNode, "xpos", "30"), TFUI_BASE_W) or 30,
			y = parseResCoord(TF2Res.GetString(titleNode, "ypos", "r40"), TFUI_BASE_H) or 440,
			font = TF2Res.GetString(titleNode, "font", "HudFontMediumBold"),
			text = resolveResLabel(TF2Res.GetString(titleNode, "labelText", "#TF_SelectATeam"), "SELECT A TEAM"),
		},
		cancel = {
			rect = readRect(cancelNode, 450, 440, 150, 30),
			text = resolveResLabel(TF2Res.GetString(cancelNode, "labelText", "#TF_Cancel"), "CANCEL"),
			font = TF2Res.GetString(cancelNode, "font", "MenuSmallFont"),
		},
		buttons = {
			auto = readButton(btnAuto, {x = 30, y = 101, w = 124, h = 310, command = "jointeam auto", teamID = TEAM_UNASSIGNED, associatedModel = "autodoor", tabPosition = 1, hotkey = "1"}, resolveResLabel("#TF_Random", "RANDOM")),
			spec = readButton(btnSpec, {x = 180, y = 232, w = 82, h = 57, command = "jointeam spectate", teamID = TEAM_SPECTATOR, associatedModel = "spectate", tabPosition = 2, hotkey = "2"}, resolveResLabel("#TF_Spectate", "SPECTATE")),
			blu = readButton(btnBlue, {x = 291, y = 101, w = 124, h = 310, command = "jointeam blue", teamID = TEAM_BLU, associatedModel = "bluedoor", tabPosition = 3, hotkey = "3"}, resolveResLabel("#TF_BlueTeam_Name", "BLU")),
			red = readButton(btnRed, {x = 479, y = 101, w = 124, h = 310, command = "jointeam red", teamID = TEAM_RED, associatedModel = "reddoor", tabPosition = 4, hotkey = "4"}, resolveResLabel("#TF_RedTeam_Name", "RED")),
		},
		labels = {
			auto = {
				rect = readRect(autoLabelNode, 40, 55, 102, 24),
				text = resolveResLabel(TF2Res.GetString(autoLabelNode, "labelText", "#TF_Random"), "RANDOM"),
				font = TF2Res.GetString(autoLabelNode, "font", "MenuSmallFont"),
				align = string.lower(TF2Res.GetString(autoLabelNode, "textAlignment", "center")),
			},
			spec = {
				rect = readRect(specLabelNode, 208, 255, 70, 20),
				text = resolveResLabel(TF2Res.GetString(specLabelNode, "labelText", "#TF_Spectate"), "SPECTATE"),
				font = TF2Res.GetString(specLabelNode, "font", "MenuSmallestFont"),
				align = string.lower(TF2Res.GetString(specLabelNode, "textAlignment", "center")),
			},
			blu = {
				rect = readRect(bluLabelNode, 325, 55, 90, 24),
				text = resolveResLabel(TF2Res.GetString(bluLabelNode, "labelText", "#TF_BlueTeam_Name"), "BLU"),
				font = TF2Res.GetString(bluLabelNode, "font", "MenuSmallFont"),
				align = string.lower(TF2Res.GetString(bluLabelNode, "textAlignment", "center")),
			},
			red = {
				rect = readRect(redLabelNode, 513, 55, 90, 24),
				text = resolveResLabel(TF2Res.GetString(redLabelNode, "labelText", "#TF_RedTeam_Name"), "RED"),
				font = TF2Res.GetString(redLabelNode, "font", "MenuSmallFont"),
				align = string.lower(TF2Res.GetString(redLabelNode, "textAlignment", "center")),
			},
			blueCount = {
				rect = readRect(blueCountNode, 325, 53, 90, 30),
				font = TF2Res.GetString(blueCountNode, "font", "TeamMenuBold"),
				align = string.lower(TF2Res.GetString(blueCountNode, "textAlignment", "center")),
			},
			redCount = {
				rect = readRect(redCountNode, 513, 53, 90, 30),
				font = TF2Res.GetString(redCountNode, "font", "TeamMenuBold"),
				align = string.lower(TF2Res.GetString(redCountNode, "textAlignment", "center")),
			},
		},
		layers = layers,
		modelByField = modelByField,
	}
end

local function createTeamSceneModelPanel(parent, layerData)
	local pnl = vgui.Create("DModelPanel", parent)
	pnl.LayerData = layerData
	pnl.AllowPassiveAnim = string.lower(tostring(layerData.fieldName or "")) ~= "menubg"
	pnl:SetModel(layerData.modelPath)
	pnl:SetCamPos(Vector(90, 0, 40))
	pnl:SetFOV(60)
	pnl:SetMouseInputEnabled(false)
	pnl:SetKeyboardInputEnabled(false)

	function pnl:SetAnimSequence(seqName, queueName, opts)
		self.DesiredSequence = seqName
		self.QueuedSequence = queueName
		self.SequenceDeadline = nil
		self.PendingReset = true
		self.HoldLastFrame = istable(opts) and opts.hold_last or false
		self.HoldDeadline = nil
		self.FrozenAtEnd = false
	end

	function pnl:LayoutEntity(ent)
		if not IsValid(ent) then return end

		-- Ensure scene models continuously animate (e.g. TV/static props) even
		-- when there is no explicit .res animation state transition.
		if not self.BootSequenceApplied then
			local layer = self.LayerData or {}
			local boot = layer.defaultSequence or "idle"
			local bootIdx = ent:LookupSequence(boot)
			if bootIdx and bootIdx >= 0 then
				ent:ResetSequence(bootIdx)
			else
				ent:ResetSequence(0)
			end

			-- TF team-menu scene model: enable TV glow if the bodygroup exists.
			local tvGlowIdx = ent:FindBodygroupByName("tvglow")
			if isnumber(tvGlowIdx) and tvGlowIdx >= 0 then
				ent:SetBodygroup(tvGlowIdx, 1)
			end

			ent:SetPlaybackRate(self.AllowPassiveAnim and 1 or 0)
			self.BootSequenceApplied = true
		end

		if self.DesiredSequence then
			-- Hold on last frame of transition/hover sequence when requested.
			if self.HoldLastFrame and self.HoldDeadline and CurTime() >= self.HoldDeadline then
				ent:SetCycle(1)
				ent:SetPlaybackRate(0)
				self.FrozenAtEnd = true
			end

			if self.SequenceDeadline and CurTime() >= self.SequenceDeadline then
				self.DesiredSequence = self.QueuedSequence
				self.QueuedSequence = nil
				self.SequenceDeadline = nil
				self.PendingReset = true
			end

			local seqIndex = ent:LookupSequence(self.DesiredSequence)
			if seqIndex and seqIndex >= 0 then
				if self.PendingReset or self.ActiveSequence ~= self.DesiredSequence then
					ent:ResetSequence(seqIndex)
					ent:SetCycle(0)
					ent:SetPlaybackRate(1)
					self.ActiveSequence = self.DesiredSequence
					self.PendingReset = false
					self.FrozenAtEnd = false

					if self.HoldLastFrame then
						local holdDur = ent:SequenceDuration(seqIndex)
						self.HoldDeadline = CurTime() + (holdDur > 0 and holdDur or 0.2)
					else
						self.HoldDeadline = nil
					end

					if self.QueuedSequence then
						local dur = ent:SequenceDuration(seqIndex)
						self.SequenceDeadline = CurTime() + (dur > 0 and dur or 0.2)
					end
				end
			end
		end

		if not self.FrozenAtEnd and (self.DesiredSequence or self.AllowPassiveAnim) then
			ent:FrameAdvance(RealFrameTime())
		end
	end

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

		self:LayoutEntity(self.Entity)
		self:DrawModel()

		render.SuppressEngineLighting(false)
		cam.End3D()
	end

	return pnl
end

local function setupActionButton(btn)
	btn:SetText("")
	if btn.SetPaintBackgroundEnabled then
		btn:SetPaintBackgroundEnabled(false)
	end
	if btn.SetPaintBorderEnabled then
		btn:SetPaintBorderEnabled(false)
	end
	btn.font = "HudFontMediumBold"
	btn.Hover = false

	function btn:OnCursorEntered()
		self.Hover = true
		surface.PlaySound(SND_ROLLOVER)
		if IsValid(self:GetParent()) and self.RoleKey then
			self:GetParent():SetHoveredRole(self.RoleKey)
		end
	end

	function btn:OnCursorExited()
		self.Hover = false
		if IsValid(self:GetParent()) and self.RoleKey then
			self:GetParent():ClearHoveredRole(self.RoleKey)
		end
	end

	btn.Paint = function(self, w, h)
		if self.Hover then
			surface.SetDrawColor(245, 240, 225, 24)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(245, 240, 225, 120)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end
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

function PANEL:RunTeamCommand(command)
	local teamID = parseTeamFromCommand(command)
	if teamID then
		self:JoinTeam(teamID)
		return
	end
	local raw = string.Trim(command or "")
	if raw == "" then return end
	local args = string.Explode(" ", raw)
	local cmd = table.remove(args, 1)
	if not isstring(cmd) or cmd == "" then return end
	RunConsoleCommand(cmd, unpack(args))
	self:ClosePanel("command")
end

function PANEL:SetModelStateByField(fieldName, phase)
	if not isstring(fieldName) or fieldName == "" then return end
	local panel = self.ModelPanelsByField and self.ModelPanelsByField[string.lower(fieldName)]
	if not IsValid(panel) then return end

	local layer = panel.LayerData or {}
	local anim = layer.animations or {}
	local idle = anim.idle_enabled or anim.idle or layer.defaultSequence or "idle"
	local hover = anim.hover_enabled or anim.hover or anim.hover_disabled or nil

	if phase == "tv_hover" then
		panel:SetAnimSequence(anim.hover or "hover", nil, {hold_last = true})
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
		-- Keep the door open while hovered by freezing the end frame of hoveropen.
		if enter then
			panel:SetAnimSequence(enter, nil, {hold_last = true})
		else
			panel:SetAnimSequence(hover or idle, nil)
		end
	elseif phase == "hover" then
		panel:SetAnimSequence(hover or idle, nil)
	elseif phase == "exit" then
		local exit = anim.exit_enabled or anim.exit
		-- hoverclose -> idle when leaving hover.
		if exit and exit ~= idle then
			panel:SetAnimSequence(exit, idle)
		else
			panel:SetAnimSequence(idle, nil)
		end
	else
		panel:SetAnimSequence(idle, nil)
	end
end

function PANEL:SetHoveredRole(roleKey)
	if self.ActiveHoverRole == roleKey then return end

	if self.ActiveHoverRole and self.ButtonOrder and self.ButtonsByRole then
		local prevCfg = self.ButtonsByRole[self.ActiveHoverRole]
		if prevCfg and prevCfg.associatedModel then
			self:SetModelStateByField(prevCfg.associatedModel, "exit")
		end
	end

	self.ActiveHoverRole = roleKey
	local cfg = self.ButtonsByRole and self.ButtonsByRole[roleKey]
	if cfg and cfg.associatedModel then
		self:SetModelStateByField(cfg.associatedModel, "enter")
	end
	self:SetModelStateByField("MenuBG", "tv_hover")
end

function PANEL:ClearHoveredRole(roleKey)
	if self.ActiveHoverRole ~= roleKey then return end
	local cfg = self.ButtonsByRole and self.ButtonsByRole[roleKey]
	if cfg and cfg.associatedModel then
		self:SetModelStateByField(cfg.associatedModel, "exit")
	end
	self.ActiveHoverRole = nil
	self:SetModelStateByField("MenuBG", "tv_idle")
end

function PANEL:ResetAllModelStates()
	if not self.ModelPanelsByField then return end
	for _, cfg in pairs(self.ButtonsByRole or {}) do
		if cfg.associatedModel then
			self:SetModelStateByField(cfg.associatedModel, "idle")
		end
	end
end

function PANEL:SetInitialFlow(state)
	self.InitialFlow = state and true or false
	if IsValid(self.CloseButton) then
		self.CloseButton:SetVisible(not self.InitialFlow)
		self.CloseButton:SetEnabled(not self.InitialFlow)
	end
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:SetVisible(false)
	self:SetKeyboardInputEnabled(true)
	self:SetMouseInputEnabled(true)
	self.InitialFlow = false
	self.ActiveHoverRole = nil

	self.ResLayout = loadTeamMenuResLayout() or {
		menuRect = {x = 0, y = 0, w = TFUI_BASE_W, h = TFUI_BASE_H},
		title = {x = 30, y = 440, font = "HudFontMediumBold", text = "SELECT A TEAM"},
		cancel = {rect = {x = 450, y = 440, w = 150, h = 30}, text = "CANCEL", font = "MenuSmallFont"},
		buttons = {
			auto = {rect = {x = 30, y = 101, w = 124, h = 310}, command = "jointeam auto", teamID = TEAM_UNASSIGNED, associatedModel = "autodoor", hotkey = "1", title = "RANDOM"},
			spec = {rect = {x = 180, y = 232, w = 82, h = 57}, command = "jointeam spectate", teamID = TEAM_SPECTATOR, associatedModel = "spectate", hotkey = "2", title = "SPECTATE"},
			blu = {rect = {x = 291, y = 101, w = 124, h = 310}, command = "jointeam blue", teamID = TEAM_BLU, associatedModel = "bluedoor", hotkey = "3", title = "BLU"},
			red = {rect = {x = 479, y = 101, w = 124, h = 310}, command = "jointeam red", teamID = TEAM_RED, associatedModel = "reddoor", hotkey = "4", title = "RED"},
		},
		labels = {},
		layers = {
			{
				fieldName = "MenuBG",
				zpos = 0,
				rect = {x = 0, y = 0, w = TFUI_BASE_W, h = TFUI_BASE_H},
				fov = 20,
				modelPath = "models/vgui/UI_team01.mdl",
				origin = Vector(290, 0, -34),
				angles = Angle(0, 180, 0),
				animations = {},
			},
		},
		modelByField = {},
	}

	self.ButtonOrder = {"auto", "spec", "blu", "red"}
	self.ButtonsByRole = self.ResLayout.buttons or {}

	self.SceneModelPanels = {}
	self.ModelPanelsByField = {}
	for _, layer in ipairs(self.ResLayout.layers or {}) do
		local validModel = isstring(layer.modelPath) and layer.modelPath ~= "" and (
			(util and util.IsValidModel and util.IsValidModel(layer.modelPath)) or file.Exists(layer.modelPath, "GAME")
		)
		if validModel then
			local modelPanel = createTeamSceneModelPanel(self, layer)
			local field = string.lower(tostring(layer.fieldName or ""))
			if field == "menubg" then
				modelPanel:SetZPos(-40)
			else
				-- Keep doors/overlay props in front of MenuBG, but still behind UI.
				modelPanel:SetZPos(-20 + (layer.zpos or 0))
			end
			self.SceneModelPanels[#self.SceneModelPanels + 1] = modelPanel
			self.ModelPanelsByField[string.lower(layer.fieldName)] = modelPanel
			if string.lower(layer.fieldName) == "menubg" then
				self.MenuBGPanel = modelPanel
			end
			tsLog("Model layer active: " .. tostring(layer.fieldName) .. " model=" .. tostring(layer.modelPath))
		end
	end

	-- Keep the same fixed camera used by the working backup path.

	self.AutoButton = vgui.Create("TFButton", self)
	self.AutoButton.RoleKey = "auto"
	setupActionButton(self.AutoButton)
	self.AutoButton.DoClick = function()
		playClickSounds()
		local cfg = self.ButtonsByRole.auto
		self:RunTeamCommand(cfg and cfg.command or "jointeam auto")
	end

	self.SpecButton = vgui.Create("TFButton", self)
	self.SpecButton.RoleKey = "spec"
	setupActionButton(self.SpecButton)
	self.SpecButton.DoClick = function()
		playClickSounds()
		local cfg = self.ButtonsByRole.spec
		self:RunTeamCommand(cfg and cfg.command or "jointeam spectate")
	end

	self.BluButton = vgui.Create("TFButton", self)
	self.BluButton.RoleKey = "blu"
	setupActionButton(self.BluButton)
	self.BluButton.DoClick = function()
		playClickSounds()
		local cfg = self.ButtonsByRole.blu
		self:RunTeamCommand(cfg and cfg.command or "jointeam blue")
	end

	self.RedButton = vgui.Create("TFButton", self)
	self.RedButton.RoleKey = "red"
	setupActionButton(self.RedButton)
	self.RedButton.DoClick = function()
		playClickSounds()
		local cfg = self.ButtonsByRole.red
		self:RunTeamCommand(cfg and cfg.command or "jointeam red")
	end

	self.CloseButton = vgui.Create("TFButton", self)
	self.CloseButton.labelText = (self.ResLayout.cancel and self.ResLayout.cancel.text) or "CANCEL"
	self.CloseButton.font = (self.ResLayout.cancel and self.ResLayout.cancel.font) or "MenuSmallFont"
	self.CloseButton:SetText("")
	self.CloseButton.DoClick = function()
		if self.InitialFlow then return end
		playClickSounds()
		self:ClosePanel("close_button")
	end
	self.CloseButton.Paint = function(btn, w, h)
		surface.SetDrawColor(255, 255, 255, 14)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(200, 190, 170, 120)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.Text{
			text = string.upper(btn.labelText or "CANCEL"),
			font = btn.font or "MenuSmallFont",
			pos = {w * 0.5, h * 0.5},
			color = Color(235, 226, 202, 255),
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		}
	end

	tsLog("Init: layers=" .. tostring(#(self.SceneModelPanels or {})) .. " hasRes=" .. tostring(self.ResLayout ~= nil))
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

	local mapping = {
		["1"] = self.ButtonsByRole and self.ButtonsByRole.auto,
		["2"] = self.ButtonsByRole and self.ButtonsByRole.spec,
		["3"] = self.ButtonsByRole and self.ButtonsByRole.blu,
		["4"] = self.ButtonsByRole and self.ButtonsByRole.red,
	}

	local keyIndex = nil
	if key == KEY_1 or key == KEY_PAD_1 then keyIndex = "1" end
	if key == KEY_2 or key == KEY_PAD_2 then keyIndex = "2" end
	if key == KEY_3 or key == KEY_PAD_3 then keyIndex = "3" end
	if key == KEY_4 or key == KEY_PAD_4 then keyIndex = "4" end

	if keyIndex and mapping[keyIndex] then
		playClickSounds()
		self:RunTeamCommand(mapping[keyIndex].command)
	end
end

function PANEL:PerformLayout()
	local w, h = ScrW(), ScrH()
	self:SetPos(0, 0)
	self:SetSize(w, h)

	local menuH = h
	local menuW = math.floor(menuH * (4 / 3))
	local menuX = math.floor((w - menuW) * 0.5)
	local menuY = 0
	local uiScale = menuH / TFUI_BASE_H

	self.MenuX = menuX
	self.MenuY = menuY
	self.MenuW = menuW
	self.MenuH = menuH
	self.HeaderH = math.floor(65 * uiScale)
	self.FooterH = math.floor(60 * uiScale)

	for _, panel in ipairs(self.SceneModelPanels or {}) do
		if IsValid(panel) then
			local layer = panel.LayerData or {}
			local rect = layer.rect or {x = 0, y = 0, w = TFUI_BASE_W, h = TFUI_BASE_H}
			panel:SetPos(menuX + math.floor((rect.x or 0) * uiScale), menuY + math.floor((rect.y or 0) * uiScale))
			panel:SetSize(math.floor((rect.w or TFUI_BASE_W) * uiScale), math.floor((rect.h or TFUI_BASE_H) * uiScale))
		end
	end

	local function layoutButton(btn, role)
		local cfg = self.ButtonsByRole and self.ButtonsByRole[role]
		if not IsValid(btn) or not cfg then return end
		local r = cfg.rect or {x = 0, y = 0, w = 0, h = 0}
		btn:SetPos(menuX + math.floor((r.x or 0) * uiScale), menuY + math.floor((r.y or 0) * uiScale))
		btn:SetSize(math.max(1, math.floor((r.w or 1) * uiScale)), math.max(1, math.floor((r.h or 1) * uiScale)))
	end

	layoutButton(self.AutoButton, "auto")
	layoutButton(self.SpecButton, "spec")
	layoutButton(self.BluButton, "blu")
	layoutButton(self.RedButton, "red")

	local closeRect = (self.ResLayout.cancel and self.ResLayout.cancel.rect) or {x = 450, y = 440, w = 150, h = 30}
	self.CloseButton:SetPos(menuX + math.floor((closeRect.x or 450) * uiScale), menuY + math.floor((closeRect.y or 440) * uiScale))
	self.CloseButton:SetSize(math.floor((closeRect.w or 150) * uiScale), math.floor((closeRect.h or 30) * uiScale))

	tsLog(string.format("PerformLayout: res-driven menu=%dx%d at %d,%d", menuW, menuH, menuX, menuY))
end

local function drawResLabel(label, menuX, menuY, uiScale, colorOverride)
	if not label then return end
	local rect = label.rect or {x = 0, y = 0, w = 80, h = 20}
	local lx = menuX + math.floor((rect.x or 0) * uiScale)
	local ly = menuY + math.floor((rect.y or 0) * uiScale)
	local lw = math.floor((rect.w or 80) * uiScale)
	local lh = math.floor((rect.h or 20) * uiScale)

	local align = string.lower(label.align or "center")
	local ax = TEXT_ALIGN_CENTER
	if align == "west" or align == "northwest" or align == "southwest" then
		ax = TEXT_ALIGN_LEFT
	elseif align == "east" or align == "northeast" or align == "southeast" then
		ax = TEXT_ALIGN_RIGHT
	end

	local tx = lx + (ax == TEXT_ALIGN_LEFT and 0 or (ax == TEXT_ALIGN_RIGHT and lw or lw * 0.5))
	draw.Text{
		text = string.upper(label.text or ""),
		font = label.font or "MenuSmallFont",
		pos = {tx, ly + lh * 0.5},
		color = colorOverride or Color(235, 226, 202, 255),
		xalign = ax,
		yalign = TEXT_ALIGN_CENTER,
	}
end

function PANEL:Paint(w, h)
	local menuX = self.MenuX or 0
	local menuY = self.MenuY or 0
	local menuW = self.MenuW or w
	local menuH = self.MenuH or h
	local uiScale = menuH / TFUI_BASE_H

	surface.SetDrawColor(20, 19, 19, 240)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(255, 255, 255, 255)
	tf_draw.TexturedQuadTiled(loadout_header, 0, 0, w, self.HeaderH or 65)
	surface.SetTexture(loadout_solid_line)
	surface.DrawTexturedRect(0, self.HeaderH or 65, w, math.floor(10 * uiScale))

	tf_draw.TexturedQuadTiled(loadout_bottom_gradient, 0, h - (self.FooterH or 60), w, self.FooterH or 60)
	surface.SetTexture(loadout_solid_line)
	surface.DrawTexturedRect(0, h - (self.FooterH or 60), w, math.floor(10 * uiScale))

	local leftW = math.max(0, menuX)
	local rightX = math.max(0, menuX + menuW)
	local rightW = math.max(0, w - rightX)
	surface.SetDrawColor(0, 0, 0, 255)
	if leftW > 0 then surface.DrawRect(0, 0, leftW, h) end
	if rightW > 0 then surface.DrawRect(rightX, 0, rightW, h) end

	local title = self.ResLayout.title or {x = 30, y = 440, font = "HudFontMediumBold", text = "SELECT A TEAM"}
	draw.Text{
		text = string.upper(title.text or "SELECT A TEAM"),
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
		yalign = TEXT_ALIGN_CENTER,
	}

	local labels = self.ResLayout.labels or {}
	drawResLabel(labels.auto, menuX, menuY, uiScale, Color(220, 216, 208, 255))
	drawResLabel(labels.spec, menuX, menuY, uiScale, Color(230, 226, 216, 255))
	drawResLabel(labels.blu, menuX, menuY, uiScale, Color(208, 225, 247, 255))
	drawResLabel(labels.red, menuX, menuY, uiScale, Color(242, 205, 194, 255))

	if labels.blueCount then
		labels.blueCount.text = tostring(team.NumPlayers(TEAM_BLU))
		drawResLabel(labels.blueCount, menuX, menuY, uiScale, Color(20, 20, 20, 255))
	end
	if labels.redCount then
		labels.redCount.text = tostring(team.NumPlayers(TEAM_RED))
		drawResLabel(labels.redCount, menuX, menuY, uiScale, Color(20, 20, 20, 255))
	end

	local autoHK = (self.ButtonsByRole.auto and self.ButtonsByRole.auto.hotkey) or "1"
	local specHK = (self.ButtonsByRole.spec and self.ButtonsByRole.spec.hotkey) or "2"
	local bluHK = (self.ButtonsByRole.blu and self.ButtonsByRole.blu.hotkey) or "3"
	local redHK = (self.ButtonsByRole.red and self.ButtonsByRole.red.hotkey) or "4"
	draw.Text{
		text = string.format("%s. AUTO    %s. SPECTATE    %s. BLU (%d)    %s. RED (%d)", autoHK, specHK, bluHK, team.NumPlayers(TEAM_BLU), redHK, team.NumPlayers(TEAM_RED)),
		font = "MenuClassBuckets",
		pos = {w * 0.5, h - math.floor(18 * uiScale)},
		color = Color(230, 225, 214, 255),
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}
end

function PANEL:OnRemove()
	gui.EnableScreenClicker(false)
end

vgui.Register("TFTeamSelectPanel", PANEL, "EditablePanel")


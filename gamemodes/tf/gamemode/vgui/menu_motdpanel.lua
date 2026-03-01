local PANEL = {}

local loadout_header = surface.GetTextureID("vgui/loadout_header")
local loadout_solid_line = surface.GetTextureID("vgui/loadout_solid_line")
local loadout_bottom_gradient = surface.GetTextureID("vgui/loadout_bottom_gradient")

local function getConVarString(name)
	local cvar = GetConVar(name)
	if not cvar then return "" end
	return cvar:GetString() or ""
end

local function withMapPlaceholder(value)
	if not isstring(value) or value == "" then return "" end
	return string.Replace(value, "{map}", game.GetMap() or "")
end

local function htmlEscape(value)
	value = tostring(value or "")
	value = string.Replace(value, "&", "&amp;")
	value = string.Replace(value, "<", "&lt;")
	value = string.Replace(value, ">", "&gt;")
	return value
end

local function normalizeDescriptionText(raw)
	raw = tostring(raw or "")
	raw = string.Replace(raw, "\r\n", "\n")
	raw = string.Replace(raw, "\r", "\n")
	raw = string.Replace(raw, "\\n", "\n")
	raw = string.Replace(raw, "", "")
	raw = string.Replace(raw, "", "")
	if string.sub(raw, 1, 3) == "\239\187\191" then
		raw = string.sub(raw, 4)
	end
	return string.Trim(raw)
end

local function getMapModeInfo(map)
	map = string.lower(map or "")
	if string.StartWith(map, "ctf_") then
		return "Capture the Flag"
	elseif string.StartWith(map, "cp_") then
		return "Control Points"
	elseif string.StartWith(map, "koth_") then
		return "King of the Hill"
	elseif string.StartWith(map, "plr_") then
		return "Payload Race"
	elseif string.StartWith(map, "pl_") then
		return "Payload"
	elseif string.StartWith(map, "mvm_") then
		return "Mann vs Machine"
	elseif string.StartWith(map, "arena_") then
		return "Arena"
	elseif string.StartWith(map, "rd_") then
		return "Robot Destruction"
	elseif string.StartWith(map, "pd_") then
		return "Player Destruction"
	elseif string.StartWith(map, "pass_") then
		return "PASS Time"
	end
	return "Team Fortress"
end

local function getDefaultDescriptionKeyForMap(map)
	map = string.lower(map or "")
	if string.StartWith(map, "vsh_") then return "default_vsh_description" end
	if string.StartWith(map, "zi_") then return "default_zi_description" end
	if string.StartWith(map, "mvm_") then return "default_mvm_description" end
	if string.StartWith(map, "ctf_") then return "default_ctf_description" end
	if string.StartWith(map, "koth_") then return "default_koth_description" end
	if string.StartWith(map, "cp_") then return "default_cp_description" end
	if string.StartWith(map, "plr_") then return "default_payload_race_description" end
	if string.StartWith(map, "pl_") then return "default_payload_description" end
	if string.StartWith(map, "arena_") then return "default_arena_description" end
	if string.StartWith(map, "rd_") then return "default_rd_description" end
	if string.StartWith(map, "pass_") then return "default_passtime_description" end
	if string.StartWith(map, "pd_") then return "default_pd_description" end
	return nil
end

local function getLocalizedRaw(key)
	if not tf_lang or not tf_lang.GetRaw then return nil end
	local v = tf_lang.GetRaw(key, true)
	if isstring(v) and v ~= "" then return v end
	v = tf_lang.GetRaw("#" .. key, true)
	if isstring(v) and v ~= "" then return v end
	return nil
end

local function readMapBriefingFile(map)
	map = string.lower(map or "")
	if map == "" then return nil end

	local lang = string.lower(getConVarString("gmod_language"))
	if lang == "" then lang = "english" end

	local candidates = {
		string.format("maps/%s_%s.txt", map, lang),
		string.format("maps/%s_english.txt", map),
		string.format("maps/%s.txt", map),
	}

	for _, path in ipairs(candidates) do
		if file.Exists(path, "GAME") then
			local raw = file.Read(path, "GAME")
			if isstring(raw) and raw ~= "" then
				return normalizeDescriptionText(raw)
			end
		end
	end

	return nil
end

local function getMapDescriptionText(map)
	map = string.lower(map or "")
	if map == "" then return "" end

	local locDescription = getLocalizedRaw(map .. "_description")
	if isstring(locDescription) and locDescription ~= "" then
		return normalizeDescriptionText(locDescription)
	end

	local fileText = readMapBriefingFile(map)
	if isstring(fileText) and fileText ~= "" then
		return fileText
	end

	local defaultKey = getDefaultDescriptionKeyForMap(map)
	if defaultKey then
		local defaultText = getLocalizedRaw(defaultKey)
		if isstring(defaultText) and defaultText ~= "" then
			return normalizeDescriptionText(defaultText)
		end
	end

	return ""
end

local function resolveMapImagePath(map)
	map = string.lower(map or "")
	if map == "" then return nil end

	local path = "maps/menu_photos_" .. map
	local mat = Material(path)
	if mat and not mat:IsError() then
		return path
	end

	return nil
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

	return token
end

local function loadMapInfoResLayout()
	if not TF2Res or not TF2Res.Load then return nil end

	local tree = TF2Res.Load("resource/ui/mapinfomenu.res") or TF2Res.Load("resource/ui/MapInfoMenu.res")
	if not tree then return nil end

	local titleNode = TF2Res.FindByFieldName(tree, "MapInfoTitle")
	local textNode = TF2Res.FindByFieldName(tree, "MapInfoText")
	local imageNode = TF2Res.FindByFieldName(tree, "MapImage")
	local continueNode = TF2Res.FindByFieldName(tree, "MapInfoContinue")
	local backNode = TF2Res.FindByFieldName(tree, "MapInfoBack")

	return {
		titleX = TF2Res.GetNumber(titleNode, "xpos", 70),
		titleY = TF2Res.GetNumber(titleNode, "ypos", 28),
		titleFont = TF2Res.GetString(titleNode, "font", "HudFontMediumBold"),
		titleText = resolveResLabel(TF2Res.GetString(titleNode, "labelText", "MISSION BRIEFING"), "MISSION BRIEFING"),
		textX = TF2Res.GetNumber(textNode, "xpos", 70),
		textY = TF2Res.GetNumber(textNode, "ypos", 95),
		textW = TF2Res.GetNumber(textNode, "wide", 820),
		textH = TF2Res.GetNumber(textNode, "tall", 520),
		imageX = TF2Res.GetNumber(imageNode, "xpos", 905),
		imageY = TF2Res.GetNumber(imageNode, "ypos", 95),
		imageW = TF2Res.GetNumber(imageNode, "wide", 300),
		imageH = TF2Res.GetNumber(imageNode, "tall", 230),
		continueX = TF2Res.GetNumber(continueNode, "xpos", -280),
		continueY = TF2Res.GetNumber(continueNode, "ypos", -52),
		continueW = TF2Res.GetNumber(continueNode, "wide", 120),
		continueH = TF2Res.GetNumber(continueNode, "tall", 30),
		continueLabel = resolveResLabel(TF2Res.GetString(continueNode, "labelText", "#TF_Continue"), "CONTINUE"),
		continueFont = TF2Res.GetString(continueNode, "font", "HudFontSmallBold"),
		backX = TF2Res.GetNumber(backNode, "xpos", -145),
		backY = TF2Res.GetNumber(backNode, "ypos", -52),
		backW = TF2Res.GetNumber(backNode, "wide", 120),
		backH = TF2Res.GetNumber(backNode, "tall", 30),
		backLabel = resolveResLabel(TF2Res.GetString(backNode, "labelText", "#TF_Back"), "SKIP"),
		backFont = TF2Res.GetString(backNode, "font", "HudFontSmallBold"),
	}
end

local function buildLocalIntroHTML()
	local map = string.lower(game.GetMap() or "unknown_map")
	local modeName = getMapModeInfo(map)
	local description = getMapDescriptionText(map)
	if description == "" then
		description = "No briefing text available for this map."
	end

	local videoURL = withMapPlaceholder(getConVarString("tf_mapintro_video_url"))
	local videoBlock = ""
	if videoURL ~= "" then
		videoBlock = [[
			<div class="video-wrap">
				<video controls playsinline style="width:100%;max-height:32vh;background:#111;border:1px solid #4d463d;">
					<source src="]] .. htmlEscape(videoURL) .. [[" type="video/mp4">
					<source src="]] .. htmlEscape(videoURL) .. [[" type="video/webm">
				</video>
			</div>
		]]
	end

	return [[
	<html>
	<head>
		<meta charset="utf-8">
		<style>
			body{margin:0;background:#171615;color:#efe7ce;font-family:Tahoma,Arial,sans-serif;}
			.wrap{padding:16px 18px;}
			h1{margin:0 0 6px 0;font-size:28px;letter-spacing:.8px;}
			h2{margin:0 0 12px 0;font-size:18px;color:#d8ccb2;}
			.board{background:#211f1d;border:1px solid #4d463d;padding:12px 14px;}
			.text{white-space:pre-wrap;line-height:1.35;font-size:16px;}
			.tip{color:#b4ab98;margin-top:10px;font-size:13px;}
			.video-wrap{margin:0 0 12px 0;}
		</style>
	</head>
	<body>
		<div class="wrap">
			<h1>MISSION BRIEFING</h1>
			<h2>]] .. htmlEscape(string.upper(map)) .. [[ - ]] .. htmlEscape(modeName) .. [[</h2>
			<div class="board">
				]] .. videoBlock .. [[
				<div class="text">]] .. htmlEscape(description) .. [[</div>
				<div class="tip">Press SKIP to continue to Team Select.</div>
			</div>
		</div>
	</body>
	</html>
	]]
end

function PANEL:Init()
	self:SetSize(ScrW(), ScrH())
	self:Center()
	self:SetVisible(false)
	self:SetKeyboardInputEnabled(true)
	self:SetMouseInputEnabled(true)
	self:SetPaintBackgroundEnabled(false)

	self.InitialFlow = false
	self.NextCallback = nil
	self.SkipCallback = nil
	self.MapImagePath = nil
	self.ResLayout = loadMapInfoResLayout()

	self.HTML = vgui.Create("DHTML", self)

	self.MapImage = vgui.Create("DImage", self)
	self.MapImage:SetVisible(false)

	self.Fallback = vgui.Create("DLabel", self)
	self.Fallback:SetWrap(true)
	self.Fallback:SetContentAlignment(7)
	self.Fallback:SetFont("HudFontSmallBold")
	self.Fallback:SetTextColor(Color(235, 226, 202, 255))
	self.Fallback:SetText("Mission briefing could not be loaded.\nYou can still press SKIP to continue.")
	self.Fallback:SetVisible(false)

	self.ContinueButton = vgui.Create("TFButton", self)
	self.ContinueButton.labelText = (self.ResLayout and self.ResLayout.continueLabel) or "CONTINUE"
	self.ContinueButton.font = (self.ResLayout and self.ResLayout.continueFont) or "HudFontSmallBold"
	self.ContinueButton.DoClick = function()
		local callback = self.NextCallback or self.SkipCallback
		self:ClosePanel()
		if isfunction(callback) then callback() end
	end

	self.SkipButton = vgui.Create("TFButton", self)
	self.SkipButton.labelText = (self.ResLayout and self.ResLayout.backLabel) or "SKIP"
	self.SkipButton.font = (self.ResLayout and self.ResLayout.backFont) or "HudFontSmallBold"
	self.SkipButton.DoClick = function()
		local callback = self.SkipCallback or self.NextCallback
		self:ClosePanel()
		if isfunction(callback) then callback() end
	end

	self.CloseButton = vgui.Create("TFButton", self)
	self.CloseButton.labelText = "CLOSE"
	self.CloseButton.font = "HudFontSmallBold"
	self.CloseButton.DoClick = function()
		if self.InitialFlow then return end
		self:ClosePanel()
	end
end

function PANEL:SetInitialFlow(state)
	self.InitialFlow = state and true or false
	if IsValid(self.CloseButton) then
		self.CloseButton:SetVisible(not self.InitialFlow)
		self.CloseButton:SetEnabled(not self.InitialFlow)
	end
end

function PANEL:SetNextCallback(fn)
	self.NextCallback = fn
end

function PANEL:SetSkipCallback(fn)
	self.SkipCallback = fn
end

function PANEL:OpenPanel()
	self:SetSize(ScrW(), ScrH())
	self:SetVisible(true)
	self:MakePopup()
	self:SetKeyboardInputEnabled(true)
	self:SetMouseInputEnabled(true)
	gui.EnableScreenClicker(true)
	self:LoadIntro()
end

function PANEL:ClosePanel()
	self:SetVisible(false)
	self:SetKeyboardInputEnabled(false)
	self:SetMouseInputEnabled(false)
	gui.EnableScreenClicker(false)
end

function PANEL:LoadIntro()
	if not IsValid(self.HTML) then return end

	local map = string.lower(game.GetMap() or "")
	self.MapImagePath = resolveMapImagePath(map)
	if self.MapImagePath then
		self.MapImage:SetImage(self.MapImagePath)
		self.MapImage:SetVisible(true)
	else
		self.MapImage:SetVisible(false)
	end

	self.Fallback:SetVisible(false)

	-- TF2 map briefing behavior: always load local map text/loc content, not web MOTD.
	local ok, html = pcall(buildLocalIntroHTML)
	if not ok or not isstring(html) or html == "" then
		self.Fallback:SetVisible(true)
		return
	end

	self.HTML:SetHTML(html)
end

function PANEL:OnKeyCodePressed(key)
	if key ~= KEY_ESCAPE then return end
	if self.InitialFlow then
		if isfunction(self.SkipCallback) then
			self.SkipCallback()
		elseif isfunction(self.NextCallback) then
			self.NextCallback()
		end
		self:ClosePanel()
		return
	end
	self:ClosePanel()
end

function PANEL:PerformLayout()
	local w, h = ScrW(), ScrH()
	self:SetSize(w, h)

	local layout = self.ResLayout
	if layout then
		self.HTML:SetPos(layout.textX, layout.textY)
		self.HTML:SetSize(layout.textW, layout.textH)
		self.MapImage:SetPos(layout.imageX, layout.imageY)
		self.MapImage:SetSize(layout.imageW, layout.imageH)
	else
		local contentX = math.floor(w * 0.07)
		local contentY = 95
		local contentW = math.floor(w * 0.86)
		local contentH = math.max(100, h - 190)

		if self.MapImage:IsVisible() then
			local imageW = math.floor(contentW * 0.34)
			local textW = contentW - imageW - 10
			self.HTML:SetPos(contentX, contentY)
			self.HTML:SetSize(textW, contentH)
			self.MapImage:SetPos(contentX + textW + 10, contentY)
			self.MapImage:SetSize(imageW, contentH)
		else
			self.HTML:SetPos(contentX, contentY)
			self.HTML:SetSize(contentW, contentH)
		end
	end

	self.Fallback:SetPos(math.floor(w * 0.08), math.floor(h * 0.35))
	self.Fallback:SetSize(math.floor(w * 0.84), 80)

	if layout then
		self.ContinueButton:SetSize(layout.continueW, layout.continueH)
		self.ContinueButton:SetPos(w + layout.continueX, h + layout.continueY)

		self.SkipButton:SetSize(layout.backW, layout.backH)
		self.SkipButton:SetPos(w + layout.backX, h + layout.backY)
	else
		local buttonY = h - 52
		self.ContinueButton:SetSize(120, 30)
		self.ContinueButton:SetPos(w - 280, buttonY)

		self.SkipButton:SetSize(120, 30)
		self.SkipButton:SetPos(w - 145, buttonY)
	end

	self.CloseButton:SetSize(120, 30)
	self.CloseButton:SetPos(w - 415, h - 52)
end

function PANEL:Paint(w, h)
	surface.SetDrawColor(255, 255, 255, 255)
	tf_draw.TexturedQuadTiled(loadout_header, 0, 0, w, 65)

	surface.SetTexture(loadout_solid_line)
	surface.DrawTexturedRect(0, 65, w, 10)

	surface.SetDrawColor(20, 19, 19, 235)
	surface.DrawRect(0, 75, w, h - 75)

	tf_draw.TexturedQuadTiled(loadout_bottom_gradient, 0, h - 60, w, 60)
	surface.SetTexture(loadout_solid_line)
	surface.DrawTexturedRect(0, h - 60, w, 10)

	draw.Text{
		text = (self.ResLayout and self.ResLayout.titleText) or "MISSION BRIEFING",
		font = (self.ResLayout and self.ResLayout.titleFont) or "HudFontMediumBold",
		pos = {
			(self.ResLayout and self.ResLayout.titleX) or (w * 0.07),
			(self.ResLayout and self.ResLayout.titleY) or 28,
		},
		color = Color(235, 226, 202, 255),
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}
end

function PANEL:OnRemove()
	gui.EnableScreenClicker(false)
end

vgui.Register("TFMOTDPanel", PANEL, "EditablePanel")

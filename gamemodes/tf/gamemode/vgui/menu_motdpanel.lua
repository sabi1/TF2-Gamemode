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

local function getMapModeInfo(map)
	map = string.lower(map or "")
	if string.StartWith(map, "ctf_") then
		return "Capture the Flag", "Steal the enemy intelligence and defend your own."
	elseif string.StartWith(map, "cp_") then
		return "Control Points", "Capture control points in sequence and push the front line."
	elseif string.StartWith(map, "koth_") then
		return "King of the Hill", "Control the central point to drain the enemy timer."
	elseif string.StartWith(map, "pl_") then
		return "Payload", "Escort the cart to the enemy base while BLU attacks and RED defends."
	elseif string.StartWith(map, "mvm_") then
		return "Mann vs Machine", "Defend the bomb hatch against waves of robots."
	end
	return "Team Fortress", "Pick a team, choose a class, and fight for the objective."
end

local function buildLocalIntroHTML()
	local map = game.GetMap() or "unknown_map"
	local modeName, objective = getMapModeInfo(map)
	local videoURL = withMapPlaceholder(getConVarString("tf_mapintro_video_url"))
	local videoBlock = ""
	if videoURL ~= "" then
		videoBlock = [[
			<video controls autoplay muted playsinline style="width:100%;max-height:50vh;background:#111;border:1px solid #4d463d;">
				<source src="]] .. videoURL .. [[" type="video/mp4">
				<source src="]] .. videoURL .. [[" type="video/webm">
			</video>
		]]
	end

	return [[
	<html>
	<head>
		<meta charset="utf-8">
		<style>
			body{margin:0;background:#171615;color:#efe7ce;font-family:Tahoma,Arial,sans-serif;}
			.wrap{padding:18px 22px;}
			h1{margin:0 0 8px 0;font-size:28px;}
			h2{margin:0 0 12px 0;font-size:20px;color:#d8ccb2;}
			.card{background:#211f1d;border:1px solid #4d463d;padding:12px 14px;}
			.obj{font-size:16px;line-height:1.4;margin-top:8px;}
			.tip{color:#b4ab98;margin-top:10px;font-size:13px;}
		</style>
	</head>
	<body>
		<div class="wrap">
			<h1>MAP INTRODUCTION</h1>
			<h2>]] .. string.upper(map) .. [[ - ]] .. modeName .. [[</h2>
			<div class="card">
				]] .. videoBlock .. [[
				<div class="obj"><b>Objective:</b> ]] .. objective .. [[</div>
				<div class="tip">Press SKIP to go directly to Team Select.</div>
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
	self.FinishLoadingSeen = false
	self.NextCallback = nil
	self.SkipCallback = nil

	self.HTML = vgui.Create("DHTML", self)
	self.Fallback = vgui.Create("DLabel", self)
	self.Fallback:SetWrap(true)
	self.Fallback:SetContentAlignment(7)
	self.Fallback:SetFont("HudFontSmallBold")
	self.Fallback:SetTextColor(Color(235, 226, 202, 255))
	self.Fallback:SetText("Map intro could not be loaded.\nYou can still press SKIP to continue.")
	self.Fallback:SetVisible(false)

	self.ContinueButton = vgui.Create("TFButton", self)
	self.ContinueButton.labelText = "CONTINUE"
	self.ContinueButton.font = "HudFontSmallBold"
	self.ContinueButton.DoClick = function()
		local callback = self.NextCallback or self.SkipCallback
		self:ClosePanel()
		if isfunction(callback) then
			callback()
		end
	end

	self.SkipButton = vgui.Create("TFButton", self)
	self.SkipButton.labelText = "SKIP"
	self.SkipButton.font = "HudFontSmallBold"
	self.SkipButton.DoClick = function()
		local callback = self.SkipCallback or self.NextCallback
		self:ClosePanel()
		if isfunction(callback) then
			callback()
		end
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

	local url = withMapPlaceholder(getConVarString("tf_mapintro_url"))
	if url == "" then
		url = withMapPlaceholder(getConVarString("tf_motd_url"))
	end

	self.FinishLoadingSeen = false
	self.Fallback:SetVisible(false)

	if url == "" or url == "https://example.com/tf2gm-motd" then
		self.HTML:SetHTML(buildLocalIntroHTML())
		return
	end

	self.HTML.OnFinishLoadingDocument = function()
		if not IsValid(self) then return end
		self.FinishLoadingSeen = true
	end
	self.HTML:OpenURL(url)

	timer.Simple(4, function()
		if not IsValid(self) then return end
		if not self.FinishLoadingSeen then
			self.Fallback:SetVisible(true)
		end
	end)
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

	self.HTML:SetPos(math.floor(w * 0.07), 95)
	self.HTML:SetSize(math.floor(w * 0.86), math.max(100, h - 190))

	self.Fallback:SetPos(math.floor(w * 0.08), math.floor(h * 0.35))
	self.Fallback:SetSize(math.floor(w * 0.84), 80)

	local buttonY = h - 52
	self.ContinueButton:SetSize(120, 30)
	self.ContinueButton:SetPos(w - 280, buttonY)

	self.SkipButton:SetSize(120, 30)
	self.SkipButton:SetPos(w - 145, buttonY)

	self.CloseButton:SetSize(120, 30)
	self.CloseButton:SetPos(w - 415, buttonY)
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
		text = "MAP INTRODUCTION",
		font = "HudFontMediumBold",
		pos = {w * 0.07, 28},
		color = Color(235, 226, 202, 255),
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}
end

function PANEL:OnRemove()
	gui.EnableScreenClicker(false)
end

vgui.Register("TFMOTDPanel", PANEL, "EditablePanel")

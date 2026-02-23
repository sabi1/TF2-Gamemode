local PANEL = {}

local loadout_header = surface.GetTextureID("vgui/loadout_header")
local loadout_solid_line = surface.GetTextureID("vgui/loadout_solid_line")
local loadout_bottom_gradient = surface.GetTextureID("vgui/loadout_bottom_gradient")
local backpack_01 = surface.GetTextureID("hud/backpack_01")
local backpack_01_grey = surface.GetTextureID("hud/backpack_01_grey")
local menuMusicDelay = 10
local menuMusicVolume = 0.6
local menuMusicFadeIn = 2.0

local menuMusicCandidates = {}
for i = 1, 31 do
	menuMusicCandidates[#menuMusicCandidates + 1] = "ui/gamestartup" .. i .. ".mp3"
end

local function safeCommand(cmd, arg)
	if cmd == "toggleconsole" then
		gui.HideGameUI()
		if IsValid(LocalPlayer()) then
			LocalPlayer():ConCommand("toggleconsole")
		end
		return
	end

	if arg ~= nil then
		RunConsoleCommand(cmd, arg)
	else
		RunConsoleCommand(cmd)
	end
end

function PANEL:Init()
	self:SetSize(ScrW(), ScrH())
	self:Center()
	self:SetVisible(false)
	self:SetKeyboardInputEnabled(true)
	self:SetMouseInputEnabled(true)
	self:SetPaintBackgroundEnabled(false)
	self.Buttons = {}
	self.MenuMusic = nil
	self.OpenedAt = 0
	self.DidStartMenuMusic = false
	self.MenuMusicFadeTimer = nil
end

function PANEL:Open()
	self:SetSize(ScrW(), ScrH())
	self:SetVisible(true)
	self:MakePopup()
	self:SetKeyboardInputEnabled(true)
	self:SetMouseInputEnabled(true)
	gui.EnableScreenClicker(true)
	self:BuildButtons()
	self.OpenedAt = RealTime()
	self.DidStartMenuMusic = false
end

function PANEL:OpenVanillaGameUIMenu()
	self:SetVisible(false)
	self:SetKeyboardInputEnabled(false)
	self:SetMouseInputEnabled(false)
	gui.EnableScreenClicker(false)
	self.SuppressOpenUntil = RealTime() + 0.2
	self.AllowVanillaUntil = RealTime() + 1.0
	self:StopMenuMusic()
	timer.Simple(0, function()
		gui.ActivateGameUI()
	end)
end

function PANEL:StopMenuMusic()
	if self.MenuMusicFadeTimer then
		timer.Remove(self.MenuMusicFadeTimer)
		self.MenuMusicFadeTimer = nil
	end

	if self.MenuMusic then
		self.MenuMusic:Stop()
		self.MenuMusic = nil
	end
end

function PANEL:FadeInMenuMusic(snd)
	if not snd then return end

	if self.MenuMusicFadeTimer then
		timer.Remove(self.MenuMusicFadeTimer)
	end

	local timerName = "TFCustomEscapeMenuMusicFadeIn_" .. tostring(self)
	self.MenuMusicFadeTimer = timerName
	local startTime = RealTime()
	local endTime = startTime + menuMusicFadeIn

	local function setVolume(value)
		if snd.ChangeVolume then
			snd:ChangeVolume(value, 0)
		elseif snd.SetVolume then
			snd:SetVolume(value)
		end
	end

	setVolume(0)
	timer.Create(timerName, 0.05, 0, function()
		if not IsValid(self) or self.MenuMusic ~= snd then
			timer.Remove(timerName)
			if IsValid(self) then
				self.MenuMusicFadeTimer = nil
			end
			return
		end

		local now = RealTime()
		if now >= endTime then
			setVolume(menuMusicVolume)
			timer.Remove(timerName)
			self.MenuMusicFadeTimer = nil
			return
		end

		local frac = math.TimeFraction(startTime, endTime, now)
		setVolume(Lerp(frac, 0, menuMusicVolume))
	end)
end

function PANEL:StartRandomMenuMusic()
	if self.MenuMusic or not IsValid(LocalPlayer()) then return end

	local available = {}
	for i = 1, #menuMusicCandidates do
		local path = menuMusicCandidates[i]
		if file.Exists("sound/" .. path, "GAME") then
			available[#available + 1] = path
		end
	end

	if #available == 0 then
		available = table.Copy(menuMusicCandidates)
	end

	local selected = available[math.random(#available)]
	local snd = CreateSound(LocalPlayer(), selected)
	if snd then
		snd:PlayEx(0, 100)
		self.MenuMusic = snd
		self:FadeInMenuMusic(snd)
		return
	end

	sound.PlayFile("sound/" .. selected, "noblock", function(channel)
		if not IsValid(self) or not channel then return end
		channel:SetVolume(0)
		channel:Play()
		self.MenuMusic = channel
		self:FadeInMenuMusic(channel)
	end)
end

function PANEL:CloseMenu()
	self:SetVisible(false)
	self:SetKeyboardInputEnabled(false)
	self:SetMouseInputEnabled(false)
	gui.EnableScreenClicker(false)
	gui.HideGameUI()
	self.SuppressOpenUntil = RealTime() + 0.2
	self:StopMenuMusic()
end

function PANEL:OnRemove()
	gui.EnableScreenClicker(false)
	self:StopMenuMusic()
end

function PANEL:OnKeyCodePressed(key)
	if key == KEY_ESCAPE then
		self:CloseMenu()
		return
	end

	if key == KEY_BACKQUOTE or key == KEY_GRAVE then
		self:CloseMenu()
		timer.Simple(0, function()
			safeCommand("toggleconsole")
		end)
	end
end

function PANEL:Think()
	if gui.IsConsoleVisible and gui.IsConsoleVisible() then
		if self:IsVisible() then
			self:SetVisible(false)
			self:SetKeyboardInputEnabled(false)
			self:SetMouseInputEnabled(false)
			gui.EnableScreenClicker(false)
			self.SuppressOpenUntil = RealTime() + 0.2
			self:StopMenuMusic()
		end
		return
	end

	if not self:IsVisible() then return end
	if self.DidStartMenuMusic then return end
	if self.OpenedAt <= 0 then return end

	if RealTime() - self.OpenedAt >= menuMusicDelay then
		self.DidStartMenuMusic = true
		self:StartRandomMenuMusic()
	end
end

function PANEL:AddTextButton(name, y, callback, isPrimary)
	local t = vgui.Create("TFButton", self)
	t:SetSize(300, 34)
	t:SetPos(ScrW() * 0.12, y)
	t.labelText = name
	t.font = "HudFontSmallBold"
	t.DoClick = callback
	if isPrimary then
		t.activeImage = nil
		t.inactiveImage = nil
	end

	self.Buttons[#self.Buttons + 1] = t
	return t
end

function PANEL:AddImageButton(y, callback)
	local t = vgui.Create("TFButton", self)
	t:SetSize(60, 60)
	t:SetPos(ScrW() * 0.12, y)
	t.activeImage = backpack_01
	t.inactiveImage = backpack_01_grey
	t.DoClick = callback

	self.Buttons[#self.Buttons + 1] = t
	return t
end

function PANEL:BuildButtons()
	for i = 1, #self.Buttons do
		if IsValid(self.Buttons[i]) then
			self.Buttons[i]:Remove()
		end
	end
	self.Buttons = {}

	local y = math.floor(ScrH() * 0.22)
	local step = 40

	self:AddTextButton("RESUME GAME", y, function() self:CloseMenu() end, true)
	y = y + step
	self:AddTextButton("CHANGE CLASS", y, function()
		self:CloseMenu()
		safeCommand("tf_changeclass")
	end)
	y = y + step
	self:AddTextButton("CHANGE TEAM", y, function()
		self:CloseMenu()
		safeCommand("tf_changeteam")
	end)
	y = y + step
	self:AddTextButton("LOADOUT", y, function()
		self:CloseMenu()
		safeCommand("open_charinfo_direct")
	end)
	y = y + step
	self:AddTextButton("MERGE TF2 LOADOUT", y, function()
		self:CloseMenu()
		safeCommand("tf_merge_loadout_ask")
	end)
	y = y + step + 8

	local backpackButton = self:AddImageButton(y, function()
		self:CloseMenu()
		safeCommand("tf_open_backpack")
	end)
	backpackButton:SetTooltip("Backpack")
	y = y + 74

	self:AddTextButton("SPAWNMENU", y, function()
		self:CloseMenu()
		safeCommand("spawnmenu_toggle")
	end)
	y = y + step
	self:AddTextButton("DEFAULT GMOD MENU", y, function()
		self:OpenVanillaGameUIMenu()
	end)
	y = y + step
	self:AddTextButton("CONSOLE", y, function()
		self:CloseMenu()
		timer.Simple(0, function()
			safeCommand("toggleconsole")
		end)
	end)
	y = y + step
	self:AddTextButton("OPTIONS", y, function()
		self:CloseMenu()
		safeCommand("gamemenucommand", "OpenOptionsDialog")
	end)
	y = y + step
	self:AddTextButton("FIND SERVERS", y, function()
		self:CloseMenu()
		safeCommand("gamemenucommand", "OpenServerBrowser")
	end)
	y = y + step
	self:AddTextButton("DISCONNECT", y, function()
		self:CloseMenu()
		safeCommand("disconnect")
	end)
	y = y + step
	self:AddTextButton("QUIT", y, function()
		self:CloseMenu()
		safeCommand("quit")
	end)
end

function PANEL:PerformLayout()
	if not self:IsVisible() then return end
	local w, h = ScrW(), ScrH()
	self:SetSize(w, h)
	if self.LastLayoutW ~= w or self.LastLayoutH ~= h then
		self.LastLayoutW = w
		self.LastLayoutH = h
		self:BuildButtons()
	end
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
		text = "TEAM FORTRESS 2 MENU",
		font = "HudFontMediumBold",
		pos = {ScrW() * 0.12, 28},
		color = Color(235, 226, 202, 255),
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}

	draw.Text{
		text = game.GetMap() or "unknown_map",
		font = "HudFontSmallBold",
		pos = {ScrW() * 0.88, 30},
		color = Color(117, 107, 94, 255),
		xalign = TEXT_ALIGN_RIGHT,
		yalign = TEXT_ALIGN_CENTER,
	}
end

vgui.Register("TFCustomEscapeMenu", PANEL, "EditablePanel")

if IsValid(TFCustomEscapeMenuPanel) then
	TFCustomEscapeMenuPanel:Remove()
end

TFCustomEscapeMenuPanel = vgui.Create("TFCustomEscapeMenu")

hook.Add("Think", "TFCustomEscapeMenuThink", function()
	if not IsValid(TFCustomEscapeMenuPanel) then return end

	if gui.IsConsoleVisible and gui.IsConsoleVisible() then
		return
	end

	if TFCustomEscapeMenuPanel.AllowVanillaUntil and RealTime() < TFCustomEscapeMenuPanel.AllowVanillaUntil then
		return
	end

	if TFCustomEscapeMenuPanel.SuppressOpenUntil and RealTime() < TFCustomEscapeMenuPanel.SuppressOpenUntil then
		return
	end

	if gui.IsGameUIVisible() and not TFCustomEscapeMenuPanel:IsVisible() then
		gui.HideGameUI()
		TFCustomEscapeMenuPanel:Open()
	end
end)

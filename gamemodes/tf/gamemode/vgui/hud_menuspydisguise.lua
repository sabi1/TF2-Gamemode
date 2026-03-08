local PANEL = {}

local TFUI_BASE_W = 640
local TFUI_BASE_H = 480
local MENU_RES = "resource/ui/disguise_menu/hudmenuspydisguise.res"

local CLASS_ORDER = {
	"scout",
	"soldier",
	"pyro",
	"demoman",
	"heavy",
	"engineer",
	"medic",
	"sniper",
	"spy",
}

local DefaultMenuLayout = {
	panelSize = { w = 470, h = 190 },
	background = { x = 0, y = 15, w = 470, h = 170, texture = surface.GetTextureID("hud/eng_build_bg") },
	divider = { x = 8, y = 65, w = 456, h = 2, color = Color(255, 222, 208, 255) },
	spyIcon = { x = 10, y = -2, w = 45, h = 45, texture = surface.GetTextureID("hud/hud_spy_disguise_menu_icon") },
	title = { x = 55, y = 5, w = 360, h = 38, text = "#Hud_Menu_Disguise_Title", font = "HudFontGiantBold" },
	titleShadow = { x = 55, y = 6, w = 360, h = 38, text = "#Hud_Menu_Disguise_Title", font = "HudFontGiantBold" },
	toggle = { x = 20, y = 49, w = 200, h = 13, text = "#Hud_Menu_Spy_Minus_Toggle", font = "Default" },
	cancel = { x = 250, y = 49, w = 200, h = 13, text = "#Hud_Menu_Build_Cancel", font = "Default" },
	items = {},
}

for i = 1, 9 do
	local x = 20 + (i - 1) * 48
	DefaultMenuLayout.items[i] = { x = x, y = 50, w = 45, h = 120 }
end

local DefaultItemLayout = {
	classIcon = { x = 0, y = 0, w = 45, h = 90, texture = 0 },
	numberBg = { x = 15, y = 90, w = 15, h = 15, texture = surface.GetTextureID("hud/ico_key_blank") },
	number = { x = 15, y = 90, w = 15, h = 15, text = "", font = "Default" },
}

local MenuLayoutCache
local ItemLayoutCache = { [0] = {}, [1] = {} }

TFSpyDisguiseMenu = TFSpyDisguiseMenu or {}
TFSpyDisguiseMenu.SelectedTeam = TFSpyDisguiseMenu.SelectedTeam or nil

local function scaleX(value)
	return value * (ScrW() / TFUI_BASE_W)
end

local function scaleY(value)
	return value * (ScrH() / TFUI_BASE_H)
end

local function resolveLabel(text, fallback)
	if isstring(text) and text ~= "" and tf_lang and tf_lang.GetRaw then
		return tf_lang.GetRaw(text) or fallback or text
	end
	return fallback or text or ""
end

function TFSpyDisguiseMenu.GetDefaultTeamIndex()
	local ply = LocalPlayer()
	if not IsValid(ply) then return 0 end
	return ply:Team() == TEAM_RED and 1 or 0
end

function TFSpyDisguiseMenu.GetSelectedTeamIndex()
	if TFSpyDisguiseMenu.SelectedTeam ~= 0 and TFSpyDisguiseMenu.SelectedTeam ~= 1 then
		TFSpyDisguiseMenu.SelectedTeam = TFSpyDisguiseMenu.GetDefaultTeamIndex()
	end
	return TFSpyDisguiseMenu.SelectedTeam
end

function TFSpyDisguiseMenu.SetSelectedTeamIndex(teamIndex)
	TFSpyDisguiseMenu.SelectedTeam = teamIndex == 1 and 1 or 0
end

function TFSpyDisguiseMenu.ToggleSelectedTeam()
	TFSpyDisguiseMenu.SetSelectedTeamIndex(TFSpyDisguiseMenu.GetSelectedTeamIndex() == 1 and 0 or 1)
end

function TFSpyDisguiseMenu.ResetSelectedTeam()
	TFSpyDisguiseMenu.SelectedTeam = TFSpyDisguiseMenu.GetDefaultTeamIndex()
end

local function readRectByField(tree, fieldName, defaults)
	local node = tree and TF2Res and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, fieldName)
	if not node or not TF2Res or not TF2Res.GetRect then
		return table.Copy(defaults)
	end
	return TF2Res.GetRect(node, TFUI_BASE_W, TFUI_BASE_H, defaults)
end

local function readRectByKey(tree, keyName, defaults)
	local node = tree and TF2Res and TF2Res.FindByKey and TF2Res.FindByKey(tree, keyName)
	if not node or not TF2Res or not TF2Res.GetRect then
		return table.Copy(defaults)
	end
	return TF2Res.GetRect(node, TFUI_BASE_W, TFUI_BASE_H, defaults)
end

local function readLabel(tree, fieldName, defaults)
	local node = tree and TF2Res and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, fieldName)
	local out = table.Copy(defaults)
	if not node then return out end

	out.x = TF2Res.ParseCoord(TF2Res.GetString(node, "xpos", nil), TFUI_BASE_W, out.x)
	out.y = TF2Res.ParseCoord(TF2Res.GetString(node, "ypos", nil), TFUI_BASE_H, out.y)
	out.w = TF2Res.ParseCoord(TF2Res.GetString(node, "wide", nil), TFUI_BASE_W, out.w)
	out.h = TF2Res.ParseCoord(TF2Res.GetString(node, "tall", nil), TFUI_BASE_H, out.h)
	out.font = TF2Res.GetString(node, "font", out.font)
	out.text = TF2Res.GetString(node, "labelText", out.text)
	return out
end

local function resolveIconTexture(iconName, fallback)
	local function materialExists(path)
		if not isstring(path) or path == "" then return false end
		local mat = Material(path)
		return mat and not mat:IsError()
	end

	local function addDisguiseClassFallback(candidates, rawIconName)
		if not isstring(rawIconName) then return end
		local className, teamSuffix = string.match(string.lower(rawIconName), "^hud_menu_([%w_]+)_(red|blu)$")
		if not className then return end

		local portraitClass = className
		if portraitClass == "demoman" then portraitClass = "demo" end
		if portraitClass == "engineer" then portraitClass = "engi" end
		if portraitClass == "heavyweapons" then portraitClass = "heavy" end

		local portraitTeam = (teamSuffix == "blu") and "blue" or "red"
		candidates[#candidates + 1] = "hud/class_" .. portraitClass .. portraitTeam

		local lbClass = portraitClass
		if lbClass == "engi" then lbClass = "engineer" end
		candidates[#candidates + 1] = "hud/leaderboard_class_" .. lbClass
	end

	local candidates = {}
	local function add(path)
		if not isstring(path) or path == "" then return end
		path = TF2Res.NormalizeImagePath(path) or path
		candidates[#candidates + 1] = path
	end

	add(iconName)
	if isstring(iconName) and not string.find(iconName, "/", 1, true) then
		add("hud/" .. iconName)
		add("vgui/" .. iconName)
	end
	addDisguiseClassFallback(candidates, iconName)
	add(fallback)

	for _, candidate in ipairs(candidates) do
		if materialExists(candidate) then
			return surface.GetTextureID(candidate)
		end
	end

	local normalizedFallback = TF2Res.NormalizeImagePath(fallback or "") or ""
	if materialExists(normalizedFallback) then
		return surface.GetTextureID(normalizedFallback)
	end
	return 0
end

local function loadMenuLayout()
	local layout = table.Copy(DefaultMenuLayout)
	local tree = TF2Res and TF2Res.Load and TF2Res.Load(MENU_RES)
	if not tree then return layout end

	layout.background = readRectByField(tree, "MainBackground", layout.background)
	layout.divider = readRectByField(tree, "Divider", layout.divider)
	layout.spyIcon = readRectByField(tree, "SpyIcon", layout.spyIcon)
	layout.title = readLabel(tree, "TitleLabel", layout.title)
	layout.titleShadow = readLabel(tree, "TitleLabelDropshadow", layout.titleShadow)
	layout.toggle = readLabel(tree, "ToggleLabel", layout.toggle)
	layout.cancel = readLabel(tree, "CancelLabel", layout.cancel)

	local bgNode = TF2Res.FindByFieldName(tree, "MainBackground")
	if bgNode then
		layout.background.texture = resolveIconTexture(TF2Res.GetString(bgNode, "icon", ""), "hud/eng_build_bg")
	end

	local dividerNode = TF2Res.FindByFieldName(tree, "Divider")
	if dividerNode then
		layout.divider.color = TF2Res.GetColor(dividerNode, "fillcolor", layout.divider.color)
	end

	local spyNode = TF2Res.FindByFieldName(tree, "SpyIcon")
	if spyNode then
		layout.spyIcon.texture = resolveIconTexture(TF2Res.GetString(spyNode, "icon", ""), "hud/hud_spy_disguise_menu_icon")
	end

	for i = 1, 9 do
		layout.items[i] = readRectByField(tree, "class_item_red_" .. i, layout.items[i])
	end

	return layout
end

local function getMenuLayout()
	if not MenuLayoutCache then
		MenuLayoutCache = loadMenuLayout()
	end
	return MenuLayoutCache
end

local function loadItemLayout(teamIndex, slot)
	local className = CLASS_ORDER[slot]
	local teamName = teamIndex == 1 and "blue" or "red"
	local classMaterialName = className
	if classMaterialName == "demoman" then classMaterialName = "demo" end
	if classMaterialName == "engineer" then classMaterialName = "engi" end
	if classMaterialName == "heavyweapons" then classMaterialName = "heavy" end
	local resPath = ("resource/ui/disguise_menu/%s_%s.res"):format(className, teamName)
	local layout = table.Copy(DefaultItemLayout)
	local tree = TF2Res and TF2Res.Load and TF2Res.Load(resPath)
	if not tree then return layout end

	layout.classIcon = readRectByKey(tree, "ClassIcon", layout.classIcon)
	layout.numberBg = readRectByKey(tree, "NumberBg", layout.numberBg)

	local iconNode = TF2Res.FindByKey(tree, "ClassIcon")
	if iconNode then
		layout.classIcon.texture = resolveIconTexture(TF2Res.GetString(iconNode, "icon", ""), "")
	end
	if not layout.classIcon.texture or layout.classIcon.texture <= 0 then
		layout.classIcon.texture = resolveIconTexture("hud/class_" .. classMaterialName .. teamName, "hud/leaderboard_class_" .. classMaterialName)
	end

	local keyNode = TF2Res.FindByKey(tree, "NumberBg")
	if keyNode then
		layout.numberBg.texture = resolveIconTexture(TF2Res.GetString(keyNode, "icon", ""), "hud/ico_key_blank")
	end

	local numberNode = TF2Res.FindByKey(tree, "NumberLabel")
	if numberNode then
		layout.number = readRectByKey(tree, "NumberLabel", layout.number)
		layout.number.text = TF2Res.GetString(numberNode, "labelText", tostring(slot))
		layout.number.font = TF2Res.GetString(numberNode, "font", layout.number.font)
	end

	return layout
end

local function getItemLayout(teamIndex, slot)
	if not ItemLayoutCache[teamIndex][slot] then
		ItemLayoutCache[teamIndex][slot] = loadItemLayout(teamIndex, slot)
	end
	return ItemLayoutCache[teamIndex][slot]
end

function PANEL:Init()
	self:SetVisible(true)
	self:SetPaintBackgroundEnabled(false)
end

function PANEL:PerformLayout()
end

function PANEL:Paint()
	if not IsCustomHUDVisible("HudSpyMenuDisguise") then
		return
	end

	if LocalPlayer():GetNWBool("Taunting") then
		return
	end

	local slot = self.slot or 1
	local teamIndex = TFSpyDisguiseMenu.GetSelectedTeamIndex()
	local layout = getItemLayout(teamIndex, slot)

	surface.SetDrawColor(255, 255, 255, 255)
	if layout.classIcon.texture and layout.classIcon.texture > 0 then
		surface.SetTexture(layout.classIcon.texture)
		surface.DrawTexturedRect(scaleX(layout.classIcon.x), scaleY(layout.classIcon.y), scaleX(layout.classIcon.w), scaleY(layout.classIcon.h))
	end

	if layout.numberBg.texture and layout.numberBg.texture > 0 then
		surface.SetTexture(layout.numberBg.texture)
		surface.DrawTexturedRect(scaleX(layout.numberBg.x), scaleY(layout.numberBg.y), scaleX(layout.numberBg.w), scaleY(layout.numberBg.h))
	end

	draw.Text{
		text = layout.number.text ~= "" and layout.number.text or tostring(slot),
		font = layout.number.font,
		pos = { scaleX(layout.number.x + layout.number.w * 0.5), scaleY(layout.number.y + layout.number.h * 0.5) },
		color = (Colors and Colors.Black) or Color(0, 0, 0, 255),
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}
end

vgui.Register("HudSpyMenuDisguiseItem", PANEL)

PANEL = {}

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)

	self.Panels = {}
	for i = 1, 9 do
		local t = vgui.Create("HudSpyMenuDisguiseItem", self)
		t.slot = i
		self.Panels[i] = t
	end
end

function PANEL:PerformLayout()
	local layout = getMenuLayout()
	local panelW = scaleX(layout.panelSize.w)
	local panelH = scaleY(layout.panelSize.h)

	self:SetPos(ScrW() * 0.5 - panelW * 0.5, ScrH() * 0.5 - panelH * 0.5)
	self:SetSize(panelW, panelH)

	for i = 1, 9 do
		local item = layout.items[i]
		self.Panels[i]:SetPos(scaleX(item.x), scaleY(item.y))
		self.Panels[i]:SetSize(scaleX(item.w), scaleY(item.h))
	end
end

function PANEL:Paint()
	if not IsCustomHUDVisible("HudSpyMenuDisguise") then
		return
	end

	if LocalPlayer():GetNWBool("Taunting") then
		return
	end

	local layout = getMenuLayout()

	surface.SetDrawColor(255, 255, 255, 255)
	if layout.background.texture and layout.background.texture > 0 then
		tf_draw.TexturedQuadPart(
			layout.background.texture,
			scaleX(layout.background.x - 16),
			scaleY(layout.background.y - 16),
			scaleX(layout.background.w + 32),
			scaleY(layout.background.h + 32),
			0,
			0,
			32,
			13
		)
	end

	surface.SetDrawColor(layout.divider.color)
	surface.DrawRect(scaleX(layout.divider.x), scaleY(layout.divider.y), scaleX(layout.divider.w), scaleY(layout.divider.h))

	if layout.spyIcon.texture and layout.spyIcon.texture > 0 then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetTexture(layout.spyIcon.texture)
		surface.DrawTexturedRect(scaleX(layout.spyIcon.x), scaleY(layout.spyIcon.y), scaleX(layout.spyIcon.w), scaleY(layout.spyIcon.h))
	end

	draw.Text{
		text = resolveLabel(layout.titleShadow.text, "#Hud_Menu_Disguise_Title"),
		font = layout.titleShadow.font,
		pos = { scaleX(layout.titleShadow.x), scaleY(layout.titleShadow.y + layout.titleShadow.h * 0.5) },
		color = (Colors and Colors.Black) or Color(0, 0, 0, 255),
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}

	draw.Text{
		text = resolveLabel(layout.title.text, "#Hud_Menu_Disguise_Title"),
		font = layout.title.font,
		pos = { scaleX(layout.title.x), scaleY(layout.title.y + layout.title.h * 0.5) },
		color = (Colors and Colors.TanLight) or Color(255, 222, 208, 255),
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}

	local toggleText = resolveLabel(layout.toggle.text, "#Hud_Menu_Spy_Minus_Toggle")
	local disguiseTeamBind = input.LookupBinding("disguiseteam") or "UNBOUND"
	local reloadBind = input.LookupBinding("+reload") or input.LookupBinding("reload") or "UNBOUND"
	toggleText = string.Replace(toggleText, "%disguiseteam%", disguiseTeamBind)
	toggleText = string.Replace(toggleText, "%reload%", reloadBind)
	toggleText = string.Replace(toggleText, "''", "'UNBOUND'")

	draw.Text{
		text = toggleText,
		font = layout.toggle.font,
		pos = { scaleX(layout.toggle.x), scaleY(layout.toggle.y + layout.toggle.h * 0.5) },
		color = (Colors and Colors.TanLight) or Color(255, 222, 208, 255),
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}

	local cancelText = resolveLabel(layout.cancel.text, "#Hud_Menu_Build_Cancel")
	local competitive = GetConVar("tf_competitive"):GetBool()
	if competitive then
		cancelText = string.Replace(cancelText, "%lastinv%", input.LookupBinding("+menu") or "UNBOUND")
	else
		cancelText = string.Replace(cancelText, "%lastinv%", input.LookupBinding("lastinv") or "UNBOUND")
	end
	cancelText = string.Replace(cancelText, "''", "'UNBOUND'")

	draw.Text{
		text = cancelText,
		font = layout.cancel.font,
		pos = { scaleX(layout.cancel.x + layout.cancel.w), scaleY(layout.cancel.y + layout.cancel.h * 0.5) },
		color = (Colors and Colors.TanLight) or Color(255, 222, 208, 255),
		xalign = TEXT_ALIGN_RIGHT,
		yalign = TEXT_ALIGN_CENTER,
	}
end

if HudSpyMenuDisguise then HudSpyMenuDisguise:Remove() end
HudSpyMenuDisguise = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

local PANEL = {}

local TFUI_BASE_W = 640
local TFUI_BASE_H = 480
local MENU_RES = "resource/ui/build_menu/hudmenuengybuild.res"

local hud_menu_bg = surface.GetTextureID("hud/eng_build_bg")
local hud_menu_item_bg = surface.GetTextureID("hud/eng_build_item")
local ico_build = surface.GetTextureID("hud/ico_build")
local ico_metal = surface.GetTextureID("hud/ico_metal_mask")
local ico_key_blank = surface.GetTextureID("hud/ico_key_blank")

local hud_menu_sentry_build = surface.GetTextureID("hud/eng_build_sentry_blueprint")
local hud_menu_dispenser_build = surface.GetTextureID("hud/eng_build_dispenser_blueprint")
local hud_menu_tele_entrance_build = surface.GetTextureID("hud/eng_build_tele_entrance_blueprint")
local hud_menu_tele_exit_build = surface.GetTextureID("hud/eng_build_tele_exit_blueprint")

local BUILDINGS = {
	{
		name = "#TF_Object_Sentry",
		texture = hud_menu_sentry_build,
		res = "resource/ui/build_menu/sentry_selectable.res",
	},
	{
		name = "#TF_Object_Dispenser",
		texture = hud_menu_dispenser_build,
		res = "resource/ui/build_menu/dispenser_selectable.res",
	},
	{
		name = "#TF_Object_Tele_Entrance_360",
		texture = hud_menu_tele_entrance_build,
		res = "resource/ui/build_menu/tele_selectable.res",
	},
	{
		name = "#TF_Object_Tele_Exit_360",
		texture = hud_menu_tele_exit_build,
		res = "resource/ui/build_menu/tele_selectable.res",
	},
}

local DefaultMenuLayout = {
	background = { x = 0, y = 10, w = 450, h = 170, texture = hud_menu_bg },
	panelSize = { w = 450, h = 195 },
	buildIcon = { x = 15, y = -8, w = 48, h = 48, texture = ico_build },
	buildIconShadow = { x = 16, y = -7, w = 48, h = 48, texture = ico_build },
	title = { x = 68, y = 0, w = 300, h = 38, text = "#Hud_menu_build_title", font = "HudFontGiantBold" },
	titleShadow = { x = 69, y = 1, w = 300, h = 38, text = "#Hud_menu_build_title", font = "HudFontGiantBold" },
	cancel = { x = 218, y = 35, w = 200, h = 13, text = "#Hud_Menu_Build_Cancel", font = "SpectatorKeyHints" },
	items = {
		{ x = 25, y = 47, w = 100, h = 124 },
		{ x = 125, y = 47, w = 100, h = 124 },
		{ x = 225, y = 47, w = 100, h = 124 },
		{ x = 325, y = 47, w = 100, h = 124 },
	},
}

local DefaultItemLayout = {
	name = { x = 6, y = 0, w = 84, h = 15, font = "TFDefault" },
	bg = { x = 4, y = 14, w = 98, h = 105, texture = hud_menu_item_bg },
	icon = { x = 22, y = 33, w = 56, h = 56 },
	metal = { x = 10, y = 18, w = 10, h = 10, texture = ico_metal },
	cost = { x = 23, y = 17, w = 84, h = 13, font = "HudFontSmall" },
	numberBg = { x = 41, y = 99, w = 18, h = 18, texture = ico_key_blank },
	number = { x = 0, y = 98, w = 100, h = 18, font = "TFDefault" },
}

local MenuLayoutCache
local ItemLayoutCache = {}

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

local function readRect(tree, fieldName, defaults)
	local node = tree and TF2Res and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, fieldName)
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

local function loadMenuLayout()
	local layout = table.Copy(DefaultMenuLayout)
	local tree = TF2Res and TF2Res.Load and TF2Res.Load(MENU_RES)
	if not tree then return layout end

	layout.background = readRect(tree, "MainBackground", layout.background)
	layout.buildIcon = readRect(tree, "BuildIcon", layout.buildIcon)
	layout.buildIconShadow = readRect(tree, "BuildIconShadow", layout.buildIconShadow)
	layout.title = readLabel(tree, "TitleLabel", layout.title)
	layout.titleShadow = readLabel(tree, "TitleLabelDropshadow", layout.titleShadow)
	layout.cancel = readLabel(tree, "CancelLabel", layout.cancel)

	for i = 1, 4 do
		layout.items[i] = readRect(tree, "active_item_" .. i, layout.items[i])
	end

	return layout
end

local function getMenuLayout()
	if not MenuLayoutCache then
		MenuLayoutCache = loadMenuLayout()
	end
	return MenuLayoutCache
end

local function loadItemLayout(slot)
	local data = BUILDINGS[slot]
	local layout = table.Copy(DefaultItemLayout)
	local tree = data and TF2Res and TF2Res.Load and TF2Res.Load(data.res)
	if not tree then return layout end

	layout.name = readLabel(tree, "ItemNameLabel", layout.name)
	layout.bg = readRect(tree, "ItemBackground", layout.bg)
	layout.icon = readRect(tree, "BuildingIcon", layout.icon)
	layout.metal = readRect(tree, "MetalIcon", layout.metal)
	layout.cost = readLabel(tree, "CostLabel", layout.cost)
	return layout
end

local function getItemLayout(slot)
	if not ItemLayoutCache[slot] then
		ItemLayoutCache[slot] = loadItemLayout(slot)
	end
	return ItemLayoutCache[slot]
end

function PANEL:Init()
	self:SetVisible(true)
	self:SetPaintBackgroundEnabled(false)
end

function PANEL:PerformLayout()
end

function PANEL:Paint()
	if not IsCustomHUDVisible("HudEngyMenuBuild") then
		return
	end

	if LocalPlayer():GetNWBool("Taunting") then
		return
	end

	local slot = self.slot or 1
	local building = BUILDINGS[slot]
	local layout = getItemLayout(slot)

	draw.Text{
		text = resolveLabel(building.name, building.name),
		font = layout.name.font,
		pos = { scaleX(layout.name.x), scaleY(layout.name.y + layout.name.h * 0.5) },
		color = Colors.TanLight,
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}

	surface.SetDrawColor(Colors.ProgressOffWhite)
	tf_draw.TexturedQuadPart(
		layout.bg.texture,
		scaleX(layout.bg.x - 8),
		scaleY(layout.bg.y - 8),
		scaleX(layout.bg.w + 16),
		scaleY(layout.bg.h + 16),
		1,
		1,
		14,
		15
	)

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetTexture(building.texture)
	surface.DrawTexturedRect(scaleX(layout.icon.x), scaleY(layout.icon.y), scaleX(layout.icon.w), scaleY(layout.icon.h))

	surface.SetDrawColor(Colors.TanDarker)
	surface.SetTexture(layout.metal.texture)
	surface.DrawTexturedRect(scaleX(layout.metal.x), scaleY(layout.metal.y), scaleX(layout.metal.w), scaleY(layout.metal.h))

	draw.Text{
		text = 150,
		font = layout.cost.font,
		pos = { scaleX(layout.cost.x), scaleY(layout.cost.y + layout.cost.h * 0.5) },
		color = Colors.TanDarker,
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetTexture(DefaultItemLayout.numberBg.texture)
	surface.DrawTexturedRect(
		scaleX(DefaultItemLayout.numberBg.x),
		scaleY(DefaultItemLayout.numberBg.y),
		scaleX(DefaultItemLayout.numberBg.w),
		scaleY(DefaultItemLayout.numberBg.h)
	)

	draw.Text{
		text = slot,
		font = DefaultItemLayout.number.font,
		pos = { scaleX(DefaultItemLayout.number.x + DefaultItemLayout.number.w * 0.5), scaleY(DefaultItemLayout.number.y + DefaultItemLayout.number.h * 0.5) },
		color = Colors.Black,
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}
end

vgui.Register("HudEngyMenuBuildItem", PANEL)

PANEL = {}

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)

	self.Panels = {}
	for i = 1, 4 do
		local t = vgui.Create("HudEngyMenuBuildItem", self)
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

	for i = 1, 4 do
		local item = layout.items[i]
		self.Panels[i]:SetPos(scaleX(item.x), scaleY(item.y))
		self.Panels[i]:SetSize(scaleX(item.w), scaleY(item.h))
	end
end

function PANEL:Paint()
	if not IsCustomHUDVisible("HudEngyMenuBuild") then
		return
	end

	if LocalPlayer():GetNWBool("Taunting") then
		return
	end

	local layout = getMenuLayout()

	surface.SetDrawColor(255, 255, 255, 255)
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

	surface.SetTexture(layout.buildIconShadow.texture)
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawTexturedRect(
		scaleX(layout.buildIconShadow.x),
		scaleY(layout.buildIconShadow.y),
		scaleX(layout.buildIconShadow.w),
		scaleY(layout.buildIconShadow.h)
	)

	surface.SetTexture(layout.buildIcon.texture)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(
		scaleX(layout.buildIcon.x),
		scaleY(layout.buildIcon.y),
		scaleX(layout.buildIcon.w),
		scaleY(layout.buildIcon.h)
	)

	draw.Text{
		text = resolveLabel(layout.titleShadow.text, "#Hud_menu_build_title"),
		font = layout.titleShadow.font,
		pos = { scaleX(layout.titleShadow.x), scaleY(layout.titleShadow.y + layout.titleShadow.h * 0.5) },
		color = Colors.Black,
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}

	draw.Text{
		text = resolveLabel(layout.title.text, "#Hud_menu_build_title"),
		font = layout.title.font,
		pos = { scaleX(layout.title.x), scaleY(layout.title.y + layout.title.h * 0.5) },
		color = Colors.TanLight,
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}

	local cantext = resolveLabel(layout.cancel.text, "#Hud_Menu_Build_Cancel")
	local competitive = GetConVar("tf_competitive"):GetBool()
	if competitive then
		cantext = string.Replace(cantext, "%lastinv%", input.LookupBinding("+menu"))
	else
		cantext = string.Replace(string.Replace(cantext, "%lastinv%", input.LookupBinding("lastinv")), "''", "'UNBOUND'")
	end

	draw.Text{
		text = cantext,
		font = layout.cancel.font,
		pos = { scaleX(layout.cancel.x + layout.cancel.w), scaleY(layout.cancel.y + layout.cancel.h * 0.5) },
		xalign = TEXT_ALIGN_RIGHT,
		yalign = TEXT_ALIGN_CENTER,
	}
end

if HudEngyMenuBuild then HudEngyMenuBuild:Remove() end
HudEngyMenuBuild = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

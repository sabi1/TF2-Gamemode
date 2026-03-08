local PANEL = {}

local TFUI_BASE_W = 640
local TFUI_BASE_H = 480
local MENU_RES = "resource/ui/destroy_menu/hudmenuengydestroy.res"

local hud_menu_bg = surface.GetTextureID("hud/eng_build_bg")
local hud_menu_item_bg = surface.GetTextureID("hud/eng_sel_item_active")
local ico_build = surface.GetTextureID("hud/ico_demolish")
local ico_key_blank = surface.GetTextureID("hud/ico_key_blank")

local hud_menu_sentry_build = surface.GetTextureID("hud/hud_obj_status_sentry_1")
local hud_menu_dispenser_build = surface.GetTextureID("hud/hud_obj_status_dispenser")
local hud_menu_tele_entrance_build = surface.GetTextureID("hud/hud_obj_status_tele_entrance")
local hud_menu_tele_exit_build = surface.GetTextureID("hud/hud_obj_status_tele_exit")

local BUILDINGS = {
	{
		name = "#TF_Object_Sentry",
		texture = hud_menu_sentry_build,
		activeRes = "resource/ui/destroy_menu/sentry_active.res",
		inactiveRes = "resource/ui/destroy_menu/sentry_inactive.res",
	},
	{
		name = "#TF_Object_Dispenser",
		texture = hud_menu_dispenser_build,
		activeRes = "resource/ui/destroy_menu/dispenser_active.res",
		inactiveRes = "resource/ui/destroy_menu/dispenser_inactive.res",
	},
	{
		name = "#TF_Object_Tele_Entrance_360",
		texture = hud_menu_tele_entrance_build,
		activeRes = "resource/ui/destroy_menu/tele_entrance_active.res",
		inactiveRes = "resource/ui/destroy_menu/tele_entrance_inactive.res",
	},
	{
		name = "#TF_Object_Tele_Exit_360",
		texture = hud_menu_tele_exit_build,
		activeRes = "resource/ui/destroy_menu/tele_exit_active.res",
		inactiveRes = "resource/ui/destroy_menu/tele_exit_inactive.res",
	},
}

local DefaultMenuLayout = {
	background = { x = 0, y = 14, w = 450, h = 170, texture = hud_menu_bg },
	panelSize = { w = 450, h = 195 },
	destroyIcon = { x = 0, y = -2, w = 64, h = 64, texture = ico_build },
	title = { x = 31, y = 4, w = 300, h = 38, text = "#Hud_menu_demolish_title", font = "HudFontGiantBold" },
	titleShadow = { x = 32, y = 7, w = 300, h = 35, text = "#Hud_menu_demolish_title", font = "HudFontGiantBold" },
	cancel = { x = 218, y = 39, w = 200, h = 13, text = "#Hud_Menu_Build_Cancel", font = "SpectatorKeyHints" },
	items = {
		{ x = 25, y = 51, w = 100, h = 124 },
		{ x = 125, y = 51, w = 100, h = 124 },
		{ x = 225, y = 51, w = 100, h = 124 },
		{ x = 325, y = 51, w = 100, h = 124 },
	},
}

local DefaultItemLayout = {
	name = { x = 6, y = 0, w = 84, h = 15, font = "TFDefault" },
	bg = { x = 4, y = 14, w = 98, h = 105, texture = hud_menu_item_bg },
	destroyIcon = { x = 13, y = 18, w = 70, h = 70, texture = ico_build },
	icon = { x = 10, y = 8, w = 80, h = 80 },
	notBuilt = { x = 10, y = 48, w = 80, h = 18, text = "#TF_NotBuilt", font = "TFDefault" },
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
	layout.destroyIcon = readRect(tree, "DestroyIcon", layout.destroyIcon)
	layout.title = readLabel(tree, "TitleLabel", layout.title)
	layout.titleShadow = readLabel(tree, "TitleLabelDropshadow", layout.titleShadow)
	layout.cancel = readLabel(tree, "CancelLabel", layout.cancel)

	for i = 1, 4 do
		layout.items[i] = readRect(tree, "inactive_item_" .. i, layout.items[i])
	end

	return layout
end

local function getMenuLayout()
	if not MenuLayoutCache then
		MenuLayoutCache = loadMenuLayout()
	end
	return MenuLayoutCache
end

local function loadItemLayout(slot, isBuilt)
	local data = BUILDINGS[slot]
	local layout = table.Copy(DefaultItemLayout)
	local resPath = isBuilt and data.activeRes or data.inactiveRes
	local tree = resPath and TF2Res and TF2Res.Load and TF2Res.Load(resPath)
	if not tree then return layout end

	layout.name = readLabel(tree, "ItemNameLabel", layout.name)
	layout.bg = readRect(tree, "ItemBackground", layout.bg)
	layout.destroyIcon = readRect(tree, "DestroyIcon", layout.destroyIcon)
	layout.icon = readRect(tree, "BuildingIcon", layout.icon)
	layout.notBuilt = readLabel(tree, "NotBuiltLabel", layout.notBuilt)
	layout.numberBg = readRect(tree, "NumberBg", layout.numberBg)
	layout.number = readLabel(tree, "NumberLabel", layout.number)
	return layout
end

local function getBuildingState()
	local built = {
		[1] = false,
		[2] = false,
		[3] = false,
		[4] = false,
	}

	for _, ent in pairs(ents.FindByClass("obj_*")) do
		if ent:GetBuilder() == LocalPlayer() then
			if ent:GetClass() == "obj_sentrygun" then
				built[1] = true
			elseif ent:GetClass() == "obj_dispenser" then
				built[2] = true
			elseif ent:GetClass() == "obj_teleporter" and ent:IsEntrance() then
				built[3] = true
			elseif ent:GetClass() == "obj_teleporter" and ent:IsExit() then
				built[4] = true
			end
		end
	end

	return built
end

local function getItemLayout(slot, isBuilt)
	ItemLayoutCache[slot] = ItemLayoutCache[slot] or {}
	if not ItemLayoutCache[slot][isBuilt] then
		ItemLayoutCache[slot][isBuilt] = loadItemLayout(slot, isBuilt)
	end
	return ItemLayoutCache[slot][isBuilt]
end

function PANEL:Init()
	self:SetVisible(true)
	self:SetPaintBackgroundEnabled(false)
end

function PANEL:PerformLayout()
end

function PANEL:Paint()
	if not IsCustomHUDVisible("HudEngyMenuDestroy") then
		return
	end

	if LocalPlayer():GetNWBool("Taunting") then
		return
	end

	local slot = self.slot or 1
	local built = getBuildingState()
	local isBuilt = built[slot] == true
	local building = BUILDINGS[slot]
	local layout = getItemLayout(slot, isBuilt)

	draw.Text{
		text = resolveLabel(building.name, building.name),
		font = layout.name.font,
		pos = { scaleX(layout.name.x), scaleY(layout.name.y + layout.name.h * 0.5) },
		color = Colors.TanLight,
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}

	surface.SetDrawColor(isBuilt and Colors.ProgressOffWhite or Colors.ProgressOffWhiteTransparent)
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

	if isBuilt then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetTexture(layout.destroyIcon.texture)
		surface.DrawTexturedRect(
			scaleX(layout.destroyIcon.x),
			scaleY(layout.destroyIcon.y),
			scaleX(layout.destroyIcon.w),
			scaleY(layout.destroyIcon.h)
		)

		surface.SetTexture(building.texture)
		surface.DrawTexturedRect(
			scaleX(layout.icon.x),
			scaleY(layout.icon.y),
			scaleX(layout.icon.w),
			scaleY(layout.icon.h)
		)
	else
		draw.Text{
			text = resolveLabel(layout.notBuilt.text, "#TF_NotBuilt"),
			font = layout.notBuilt.font,
			pos = { scaleX(layout.notBuilt.x + layout.notBuilt.w * 0.5), scaleY(layout.notBuilt.y + layout.notBuilt.h * 0.5) },
			color = Colors.ProgressOffWhite,
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		}
	end

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetTexture(layout.numberBg.texture)
	surface.DrawTexturedRect(
		scaleX(layout.numberBg.x),
		scaleY(layout.numberBg.y),
		scaleX(layout.numberBg.w),
		scaleY(layout.numberBg.h)
	)

	draw.Text{
		text = slot,
		font = layout.number.font,
		pos = { scaleX(layout.number.x + layout.number.w * 0.5), scaleY(layout.number.y + layout.number.h * 0.5) },
		color = Colors.Black,
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}
end

vgui.Register("HudEngyMenuDestroyItem", PANEL)

PANEL = {}

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)

	self.Panels = {}
	for i = 1, 4 do
		local t = vgui.Create("HudEngyMenuDestroyItem", self)
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
	if not IsCustomHUDVisible("HudEngyMenuDestroy") then
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

	surface.SetTexture(layout.destroyIcon.texture)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(
		scaleX(layout.destroyIcon.x),
		scaleY(layout.destroyIcon.y),
		scaleX(layout.destroyIcon.w),
		scaleY(layout.destroyIcon.h)
	)

	draw.Text{
		text = resolveLabel(layout.titleShadow.text, "#Hud_menu_demolish_title"),
		font = layout.titleShadow.font,
		pos = { scaleX(layout.titleShadow.x), scaleY(layout.titleShadow.y + layout.titleShadow.h * 0.5) },
		color = Colors.Black,
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}

	draw.Text{
		text = resolveLabel(layout.title.text, "#Hud_menu_demolish_title"),
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

if HudEngyMenuDestroy then HudEngyMenuDestroy:Remove() end
HudEngyMenuDestroy = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

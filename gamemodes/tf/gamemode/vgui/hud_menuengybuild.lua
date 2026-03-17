local PANEL = {}

local TFUI_BASE_W = 640
local TFUI_BASE_H = 480
local MENU_DIR_DEFAULT = "resource/ui/build_menu"
local MENU_DIR_PIPBOY = "resource/ui/build_menu/pipboy"
local MENU_DIR_360 = "resource/ui/build_menu_360"
local MENU_DIR_SC = "resource/ui/build_menu_sc"
local MENU_FILE = "hudmenuengybuild.res"
local CUSTOM_BUILDMENU_DEFAULT = 0
local CUSTOM_BUILDMENU_PIPBOY = 1

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
		group = 2,
		mode = 0,
		activeRes = "sentry_active.res",
		selectableFallbackRes = "sentry_selectable.res",
		alreadyBuiltRes = "sentry_already_built.res",
		cantAffordRes = "sentry_cant_afford.res",
		unavailableRes = "sentry_unavailable.res",
		fallbackCost = 130,
	},
	{
		name = "#TF_Object_Dispenser",
		texture = hud_menu_dispenser_build,
		group = 0,
		mode = 0,
		activeRes = "dispenser_active.res",
		selectableFallbackRes = "dispenser_selectable.res",
		alreadyBuiltRes = "dispenser_already_built.res",
		cantAffordRes = "dispenser_cant_afford.res",
		unavailableRes = "dispenser_unavailable.res",
		fallbackCost = 100,
	},
	{
		name = "#TF_Object_Tele_Entrance_360",
		texture = hud_menu_tele_entrance_build,
		group = 1,
		mode = 0,
		activeRes = "tele_entrance_active.res",
		selectableFallbackRes = "tele_selectable.res",
		alreadyBuiltRes = "tele_entrance_already_built.res",
		cantAffordRes = "tele_entrance_cant_afford.res",
		unavailableRes = "tele_entrance_unavailable.res",
		fallbackCost = 75,
	},
	{
		name = "#TF_Object_Tele_Exit_360",
		texture = hud_menu_tele_exit_build,
		group = 1,
		mode = 1,
		activeRes = "tele_exit_active.res",
		selectableFallbackRes = "tele_selectable.res",
		alreadyBuiltRes = "tele_exit_already_built.res",
		cantAffordRes = "tele_exit_cant_afford.res",
		unavailableRes = "tele_exit_unavailable.res",
		fallbackCost = 75,
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
local CurrentMenuVariant = nil
local SLOT_STATE_SELECTABLE = 1
local SLOT_STATE_ALREADY_BUILT = 2
local SLOT_STATE_CANT_AFFORD = 3
local SLOT_STATE_UNAVAILABLE = 4
local cvarBuildMenuControllerMode = GetConVar("tf_build_menu_controller_mode") or CreateClientConVar("tf_build_menu_controller_mode", "0", true, false, "Use console controller build menus.")

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

local function pathJoin(a, b)
	if not isstring(a) or not isstring(b) then return nil end
	return string.Trim(a, "/\\") .. "/" .. string.Trim(b, "/\\")
end

local function fileExists(path)
	return isstring(path) and file.Exists(path, "GAME")
end

local function readCustomBuildMenuAttr(ply)
	if not IsValid(ply) then return CUSTOM_BUILDMENU_DEFAULT end

	if isfunction(ply.GetAttributeValue) then
		local v = tonumber(ply:GetAttributeValue("set_custom_buildmenu", CUSTOM_BUILDMENU_DEFAULT)) or CUSTOM_BUILDMENU_DEFAULT
		if v ~= CUSTOM_BUILDMENU_DEFAULT then
			return math.floor(v)
		end
	end

	for _, wep in ipairs(ply.GetWeapons and ply:GetWeapons() or {}) do
		if IsValid(wep) and isfunction(wep.GetAttributeValue) then
			local v = tonumber(wep:GetAttributeValue("set_custom_buildmenu", CUSTOM_BUILDMENU_DEFAULT)) or CUSTOM_BUILDMENU_DEFAULT
			if v ~= CUSTOM_BUILDMENU_DEFAULT then
				return math.floor(v)
			end
		end
	end

	return CUSTOM_BUILDMENU_DEFAULT
end

local function isSteamControllerActive()
	return input and isfunction(input.IsSteamControllerActive) and input.IsSteamControllerActive() or false
end

local function getMenuVariant()
	local steamController = isSteamControllerActive()
	local controllerMode = cvarBuildMenuControllerMode and cvarBuildMenuControllerMode:GetBool() or false
	if steamController then
		return "sc"
	end
	if controllerMode then
		return "x360"
	end

	local ply = LocalPlayer()
	local customBuildmenu = readCustomBuildMenuAttr(ply)
	if customBuildmenu == CUSTOM_BUILDMENU_PIPBOY then
		return "pipboy"
	end

	return "default"
end

local function getMenuDir(variant)
	variant = variant or getMenuVariant()
	if variant == "sc" then return MENU_DIR_SC end
	if variant == "x360" then return MENU_DIR_360 end
	if variant == "pipboy" then return MENU_DIR_PIPBOY end
	return MENU_DIR_DEFAULT
end

local function clearLayoutCaches()
	MenuLayoutCache = nil
	ItemLayoutCache = {}
end

local function ensureLayoutVariant()
	local variant = getMenuVariant()
	if variant ~= CurrentMenuVariant then
		CurrentMenuVariant = variant
		clearLayoutCaches()
	end
	return variant
end

local function resolveResPath(filename, forceDefaultDir)
	if not isstring(filename) or filename == "" then return nil end

	local variant = ensureLayoutVariant()
	local dirs = {}
	if forceDefaultDir then
		dirs[#dirs + 1] = MENU_DIR_DEFAULT
	else
		dirs[#dirs + 1] = getMenuDir(variant)
		dirs[#dirs + 1] = MENU_DIR_DEFAULT
	end

	for _, dir in ipairs(dirs) do
		local candidate = pathJoin(dir, filename)
		if fileExists(candidate) then
			return candidate
		end
	end
	return nil
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
	if out.font == "HudMenuNumberFont" then
		out.font = defaults.font or "TFDefault"
	end
	out.text = TF2Res.GetString(node, "labelText", out.text)
	return out
end

local function loadMenuLayout()
	local layout = table.Copy(DefaultMenuLayout)
	local menuPath = resolveResPath(MENU_FILE, false)
	local tree = menuPath and TF2Res and TF2Res.Load and TF2Res.Load(menuPath)
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
	ensureLayoutVariant()
	if not MenuLayoutCache then
		MenuLayoutCache = loadMenuLayout()
	end
	return MenuLayoutCache
end

local function getPlayerBuildablesTable()
	local ply = LocalPlayer()
	if not IsValid(ply) then return nil end
	if istable(ply.Buildings) then return ply.Buildings end
	local builder = ply.GetWeapon and ply:GetWeapon("tf_weapon_builder")
	if IsValid(builder) and IsValid(builder.Owner) and istable(builder.Owner.Buildings) then
		return builder.Owner.Buildings
	end
	return nil
end

local function getSlotBuildDef(slot)
	local data = BUILDINGS[slot]
	if not data then return nil end
	local buildables = getPlayerBuildablesTable()
	if buildables and buildables[data.group] and buildables[data.group][data.mode] then
		return buildables[data.group][data.mode]
	end
	return nil
end

local function countOwnedSentries(ply)
	local regular = 0
	local disposable = 0
	for _, ent in ipairs(ents.FindByClass("obj_sentrygun")) do
		if not IsValid(ent) then continue end
		if ent:GetOwner() ~= ply and ent:GetBuilder() ~= ply and ent.Player ~= ply then continue end
		if ent.TF_MVM_DisposableSentry then
			disposable = disposable + 1
		else
			regular = regular + 1
		end
	end
	return regular, disposable
end

local function getSlotState(slot)
	local data = BUILDINGS[slot]
	if not data then return SLOT_STATE_UNAVAILABLE, 0 end

	local ply = LocalPlayer()
	if not IsValid(ply) then return SLOT_STATE_UNAVAILABLE, data.fallbackCost or 0 end

	local def = getSlotBuildDef(slot)
	local cost = math.max(0, math.floor(tonumber((def and def.cost) or data.fallbackCost or 0) or 0))
	local metal = tonumber(ply:GetAmmoCount(TF_METAL) or 0) or 0

	if not def then
		return SLOT_STATE_UNAVAILABLE, cost
	end
	if def.enabled == false or def.disabled == true then
		return SLOT_STATE_UNAVAILABLE, cost
	end

	local alreadyBuilt = false
	if data.group == 2 then
		local regularCount, disposableCount = countOwnedSentries(ply)
		local disposableLimit = 0
		if ply.TF_MVM_Dynamic then
			disposableLimit = math.max(0, math.floor(tonumber(ply.TF_MVM_Dynamic.DisposableSentryCount) or 0))
		end
		local allowDisposable = disposableLimit > 0 and regularCount >= 1 and disposableCount < disposableLimit
		alreadyBuilt = regularCount >= 1 and not allowDisposable
	elseif data.group == 0 then
		for _, ent in ipairs(ents.FindByClass("obj_dispenser")) do
			if IsValid(ent) and (ent:GetOwner() == ply or ent:GetBuilder() == ply or ent.Player == ply) then
				alreadyBuilt = true
				break
			end
		end
	elseif data.group == 1 then
		for _, ent in ipairs(ents.FindByClass("obj_teleporter")) do
			if not IsValid(ent) then continue end
			if ent:GetOwner() ~= ply and ent:GetBuilder() ~= ply and ent.Player ~= ply then continue end
			if data.mode == 0 and ent.IsEntrance and ent:IsEntrance() then
				alreadyBuilt = true
				break
			elseif data.mode == 1 and ent.IsExit and ent:IsExit() then
				alreadyBuilt = true
				break
			end
		end
	end

	local canBuildByRules = true
	if isfunction(TF_CanPlayerBuildObject) then
		canBuildByRules = TF_CanPlayerBuildObject(ply, data.group, data.mode, false)
	end

	if alreadyBuilt then
		return SLOT_STATE_ALREADY_BUILT, cost
	end
	if not canBuildByRules then
		return SLOT_STATE_UNAVAILABLE, cost
	end
	if metal < cost then
		return SLOT_STATE_CANT_AFFORD, cost
	end
	return SLOT_STATE_SELECTABLE, cost
end

local function getSlotResPath(slot, state)
	local data = BUILDINGS[slot]
	if not data then return nil end
	local fileName
	local forceDefaultDir = false

	if state == SLOT_STATE_ALREADY_BUILT then
		fileName = data.alreadyBuiltRes
	elseif state == SLOT_STATE_CANT_AFFORD then
		fileName = data.cantAffordRes
	elseif state == SLOT_STATE_UNAVAILABLE then
		fileName = data.unavailableRes
		forceDefaultDir = true
	else
		fileName = data.activeRes
	end

	local resolved = resolveResPath(fileName, forceDefaultDir)
	if resolved then
		return resolved
	end

	if state == SLOT_STATE_SELECTABLE and isstring(data.selectableFallbackRes) then
		return resolveResPath(data.selectableFallbackRes, false)
	end

	return nil
end

local function loadItemLayout(slot, state)
	local data = BUILDINGS[slot]
	local layout = table.Copy(DefaultItemLayout)
	local resPath = getSlotResPath(slot, state)
	local tree = resPath and TF2Res and TF2Res.Load and TF2Res.Load(resPath)
	if not tree then return layout end

	layout.name = readLabel(tree, "ItemNameLabel", layout.name)
	layout.bg = readRect(tree, "ItemBackground", layout.bg)
	layout.icon = readRect(tree, "BuildingIcon", layout.icon)
	layout.metal = readRect(tree, "MetalIcon", layout.metal)
	layout.cost = readLabel(tree, "CostLabel", layout.cost)
	local numberBgNode = TF2Res and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "NumberBg")
	local numberLabelNode = TF2Res and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "NumberLabel")
	if numberBgNode and numberLabelNode then
		layout.numberBg = readRect(tree, "NumberBg", layout.numberBg)
		layout.number = readLabel(tree, "NumberLabel", layout.number)
		layout.showNumber = true
	else
		layout.showNumber = false
	end
	return layout
end

local function getItemLayout(slot, state)
	ensureLayoutVariant()
	ItemLayoutCache[slot] = ItemLayoutCache[slot] or {}
	if not ItemLayoutCache[slot][state] then
		ItemLayoutCache[slot][state] = loadItemLayout(slot, state)
	end
	return ItemLayoutCache[slot][state]
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
	if not building then return end
	local state, cost = getSlotState(slot)
	local layout = getItemLayout(slot, state)

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
		text = cost,
		font = layout.cost.font,
		pos = { scaleX(layout.cost.x), scaleY(layout.cost.y + layout.cost.h * 0.5) },
		color = Colors.TanDarker,
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	}

	if layout.showNumber ~= false then
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

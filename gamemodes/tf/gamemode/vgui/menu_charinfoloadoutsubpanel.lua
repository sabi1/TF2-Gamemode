local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local loadout_rect = surface.GetTextureID("vgui/loadout_rect")
local loadout_rect_mouseover = surface.GetTextureID("vgui/loadout_rect_mouseover")
local loadout_dotted_line = surface.GetTextureID("vgui/loadout_dotted_line")

local loadout_round_rect = surface.GetTextureID("vgui/loadout_round_rect")
local loadout_round_rect_selected = surface.GetTextureID("vgui/loadout_round_rect_selected")

local w_machete_large = surface.GetTextureID("backpack/weapons/w_models/w_machete_large")
local w_cigarette_case = surface.GetTextureID("backpack/weapons/w_models/w_cigarette_case_large")
local c_leather_watch = surface.GetTextureID("backpack/weapons/c_models/c_leather_watch/parts/c_leather_watch_large")
local w_knife = surface.GetTextureID("backpack/weapons/w_models/w_knife_large")
local w_revolver = surface.GetTextureID("backpack/weapons/w_models/w_revolver_large")
local all_halo = surface.GetTextureID("backpack/player/items/all_class/all_halo_large")

local item_center_xoffset1 = -310
local item_center_xoffset2 = 165
local attributes_xoffset1 = 140
local attributes_xoffset2 = -168
local attributes_yoffset = 10

--[[
local ATT_TEST = {
{"Level 0 Cigarette Case", 1},
{"+900% health", 3},
{"No weapon when equipped", 4},
{"-66% speed", 4},
}]]

local ATT1 = {
{"Level 1 Revolver", 1},
}

local ATT2 = {
{"Level 5 Invisibility Watch", 1},
{"Cloak Type: Motion Sensitive", 2},
}

local ATT3 = {
{"Level 0 Cigarette Case", 1},
{"It will change your skeleton!", 2},
{"Excrutiatingly painful . . .", 4},
{". . . but worth it", 3},
}

local ATT4 = {
{"Level 42 Shitstorm Generator", 1},
}

local LOADOUT_SLOT_COUNT = 7
local TAUNT_SLOT_COUNT = 8
local TAUNT_FORCED_SLOT_BASE = 100
local ActiveTauntLoadoutPanel
local getResolvedItemImagePath
local getDecoratedDisplayName

local function getClassLoadoutSlotCount(className)
	className = string.lower(tostring(className or ""))
	if className == "engineer" or className == "spy" then
		return 8
	end
	return LOADOUT_SLOT_COUNT
end

local function normalizeTauntLoadoutSplit(split)
	local out = {}
	for i = 1, TAUNT_SLOT_COUNT do
		out[i] = tostring(tonumber(split and split[i]) or -1)
	end
	return out
end

local function getTauntLoadoutConVarName(className)
	return "loadout_taunts_" .. tostring(className or "scout")
end

local function getTauntLoadout(className)
	local convar = GetConVar(getTauntLoadoutConVarName(className))
	if not convar then
		return normalizeTauntLoadoutSplit(nil)
	end
	return normalizeTauntLoadoutSplit(string.Split(convar:GetString() or "", ","))
end

local function updateTauntLoadout(slot, id, className)
	local convar = GetConVar(getTauntLoadoutConVarName(className))
	local index = tonumber(slot)
	if not convar or not index or index < 1 or index > TAUNT_SLOT_COUNT then return end
	local split = normalizeTauntLoadoutSplit(string.Split(convar:GetString() or "", ","))
	split[index] = tostring(tonumber(id) or -1)
	convar:SetString(table.concat(split, ","))
end

local function isTauntItem(item)
	if not istable(item) then return false end
	if item.item_slot == "taunt" then return true end
	if isstring(item.item_class) and string.find(string.lower(item.item_class), "taunt", 1, true) then return true end

	local itemType = string.lower(tostring(tf_lang.GetRaw(item.item_type_name) or item.item_type_name or ""))
	if itemType ~= "" and string.find(itemType, "taunt", 1, true) then
		return true
	end

	local itemName = string.lower(tostring(tf_lang.GetRaw(item.item_name) or item.item_name or item.name or ""))
	return itemName ~= "" and string.find(itemName, "taunt", 1, true) ~= nil
end

local isActionSlotItem

local function itemUsableByClass(item, className)
	if not istable(item) or not isstring(className) or className == "" then return false end
	if isActionSlotItem(item) then return true end
	if isTauntItem(item) then
		if not istable(item.used_by_classes) then return true end
	end
	if not istable(item.used_by_classes) then return false end
	if item.used_by_classes[className] == true or item.used_by_classes[className] == 1 then
		return true
	end
	if item.used_by_classes.all_class == true or item.used_by_classes.all_class == 1 then
		return true
	end
	if item.used_by_classes.all_classes == true or item.used_by_classes.all_classes == 1 then
		return true
	end
	return false
end

local function tauntSlotToForcedSlot(slotIndex)
	local i = math.Clamp(tonumber(slotIndex) or 1, 1, TAUNT_SLOT_COUNT)
	return TAUNT_FORCED_SLOT_BASE + i
end

local function forcedSlotToTauntSlot(forcedSlot)
	local f = tonumber(forcedSlot)
	if not f then return nil end
	if f >= (TAUNT_FORCED_SLOT_BASE + 1) and f <= (TAUNT_FORCED_SLOT_BASE + TAUNT_SLOT_COUNT) then
		return f - TAUNT_FORCED_SLOT_BASE
	end
	return nil
end

local function forceCloseLoadoutPanels()
	if IsValid(ActiveTauntLoadoutPanel) then
		ActiveTauntLoadoutPanel:Remove()
	end
	if IsValid(FullLoadoutPanel) then
		FullLoadoutPanel:Remove()
	end
	if IsValid(CharInfoLoadoutSubPanel) and isfunction(CharInfoLoadoutSubPanel.SelectClassLoadout) then
		CharInfoLoadoutSubPanel:SelectClassLoadout(0)
	end
	if IsValid(CharInfoPanel) and isfunction(CharInfoPanel.Close) then
		CharInfoPanel:Close()
	end
	gui.EnableScreenClicker(false)
	RunConsoleCommand("hud_showloadout", "0")
end

local function closeTauntLoadoutPanel()
	if IsValid(ActiveTauntLoadoutPanel) then
		ActiveTauntLoadoutPanel:Remove()
	end
	ActiveTauntLoadoutPanel = nil
end

local function openTauntLoadoutPanel(parent)
	closeTauntLoadoutPanel()

	local classIndex = GetConVar("tf_hud_loadout_class") and GetConVar("tf_hud_loadout_class"):GetInt() or 1
	local classMap = {
		[1] = "scout",
		[2] = "soldier",
		[3] = "pyro",
		[4] = "demoman",
		[5] = "heavy",
		[6] = "engineer",
		[7] = "medic",
		[8] = "sniper",
		[9] = "spy",
	}
	local className = classMap[classIndex] or "scout"

	local itemsById = {}
	for _, item in pairs(tf_items.Items or {}) do
		if istable(item) and isnumber(item.id) then
			itemsById[tonumber(item.id)] = item
		end
	end

	local panelParent = IsValid(parent) and parent or (IsValid(CharInfoPanel) and CharInfoPanel or nil)
	local panel = vgui.Create("EditablePanel", panelParent)
	panel:SetSize(math.floor(ScrW() * 0.58), math.floor(ScrH() * 0.46))
	panel:Center()
	panel:MakePopup()
	panel:SetKeyboardInputEnabled(true)
	panel:SetMouseInputEnabled(true)
	panel:SetZPos(10000)
	ActiveTauntLoadoutPanel = panel

	function panel:Paint(w, h)
		surface.SetDrawColor(18, 17, 16, 245)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(90, 83, 72, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 2)

		draw.Text{
			text = "TAUNTS",
			font = "HudFontMediumBold",
			pos = {20, 12},
			color = Color(235, 226, 202, 255),
			xalign = TEXT_ALIGN_LEFT,
			yalign = TEXT_ALIGN_TOP,
		}
	end

	local closeBtn = vgui.Create("TFButton", panel)
	closeBtn:SetSize(100 * Scale, 25 * Scale)
	closeBtn:SetPos(panel:GetWide() - 120 * Scale, 12 * Scale)
	closeBtn.labelText = "CLOSE"
	closeBtn.font = "HudFontSmallBold"
	function closeBtn:DoClick()
		closeTauntLoadoutPanel()
	end

	local info = vgui.Create("DLabel", panel)
	info:SetPos(18 * Scale, 42 * Scale)
	info:SetSize(panel:GetWide() - 36 * Scale, 20 * Scale)
	info:SetText("Class: " .. string.upper(className) .. "  |  Equip taunts from your synced backpack")
	info:SetTextColor(Color(214, 202, 178, 255))
	info:SetFont("HudFontSmall")

	local scroll = vgui.Create("DScrollPanel", panel)
	scroll:SetPos(18 * Scale, 64 * Scale)
	scroll:SetSize(panel:GetWide() - 36 * Scale, panel:GetTall() - 82 * Scale)

	local grid = vgui.Create("DIconLayout", scroll)
	grid:Dock(FILL)
	grid:SetSpaceX(8)
	grid:SetSpaceY(8)

	local function buildSlotCards()
		for _, child in ipairs(grid:GetChildren()) do
			child:Remove()
		end

		local tauntLoadout = getTauntLoadout(className)
		for i = 1, TAUNT_SLOT_COUNT do
			local itemId = tonumber(tauntLoadout[i])
			local item = itemId and itemsById[itemId] or nil
			local displayName = item and getDecoratedDisplayName(item, item.SteamProperties) or (tf_lang.GetRaw("Hud_Menu_Taunt_NoItem") or "No Item")
			local imagePath = item and getResolvedItemImagePath(item, item.SteamProperties) or nil

			local itemTex = surface.GetTextureID(imagePath or "")
			if not imagePath or imagePath == "" then
				itemTex = surface.GetTextureID("vgui/avatar_default")
			end

			local btn = vgui.Create("DButton", grid)
			btn:SetSize(math.floor(172 * Scale), math.floor(122 * Scale))
			btn:SetText("")
			btn:SetTooltip("Taunt Slot " .. tostring(i))
			btn.Paint = function(self, w, h)
				draw.RoundedBox(4, 0, 0, w, h, Color(50, 44, 39, 245))
				surface.SetDrawColor(110, 102, 92, 255)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				draw.SimpleText("Slot " .. tostring(i), "HudFontSmallBold", 8, 8, Color(238, 131, 84, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				draw.SimpleText(displayName or "No Item", "HudFontSmall", 8, h - 8, Color(235, 226, 202, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.SetTexture(itemTex)
				surface.DrawTexturedRect(8, 28, w - 16, h - 56)
			end
			btn.DoClick = function()
				TF_OpenStandaloneBackpack(className, classIndex, tauntSlotToForcedSlot(i))
				closeTauntLoadoutPanel()
			end
			btn.DoRightClick = function()
				updateTauntLoadout(i, -1, className)
				surface.PlaySound("ui/buttonclickrelease.wav")
				buildSlotCards()
			end
			grid:Add(btn)
		end
	end

	buildSlotCards()

	panel.OnRemove = function()
		if ActiveTauntLoadoutPanel == panel then
			ActiveTauntLoadoutPanel = nil
		end
	end
end

local attributeDefsByClass

local function getAttributeDefByClass(attributeClass)
	if not isstring(attributeClass) or attributeClass == "" then return nil end
	if not istable(tf_items) or not istable(tf_items.AttributesByID) then return nil end

	if not attributeDefsByClass then
		attributeDefsByClass = {}
		for _, def in pairs(tf_items.AttributesByID) do
			if istable(def) and isstring(def.attribute_class) and def.attribute_class ~= "" and not attributeDefsByClass[def.attribute_class] then
				attributeDefsByClass[def.attribute_class] = def
			end
		end
	end

	return attributeDefsByClass[attributeClass]
end

local function getAttributeEffectIndex(effectType)
	if effectType == "positive" then return 3 end
	if effectType == "negative" then return 4 end
	return 2
end

local function formatAttributeValue(att, def)
	local value = tonumber(att and att.value)
	if not value then return nil end

	local formatType = isstring(def and def.description_format) and def.description_format or ""
	if formatType == "value_is_percentage" then
		return string.format("%+.0f%%", (value - 1) * 100)
	elseif formatType == "value_is_inverted_percentage" then
		return string.format("%+.0f%%", (1 - value) * 100)
	elseif formatType == "value_is_additive_percentage" then
		return string.format("%+.0f%%", value * 100)
	elseif formatType == "value_is_additive" then
		if math.abs(value - math.floor(value)) < 0.001 then
			return string.format("%+d", math.floor(value))
		end
		return string.format("%+.2f", value)
	end

	if value ~= 0 and value ~= 1 then
		if math.abs(value - math.floor(value)) < 0.001 then
			return string.format("%+d", math.floor(value))
		end
		return string.format("%+.2f", value)
	end

	return nil
end

local function buildItemTooltipAttributes(item)
	local lines = {}
	if not istable(item) then return lines end

	local function addFromContainer(container)
		if not istable(container) then return end
		for _, att in pairs(container) do
			if istable(att) then
				local def = getAttributeDefByClass(att.attribute_class)
				local baseText
				if def and isstring(def.description_string) and def.description_string ~= "" then
					baseText = tf_lang.GetRaw(def.description_string)
					if string.sub(def.description_string, 1, 1) == "#" and isstring(baseText) and string.sub(baseText, 1, 1) == "#" then
						baseText = nil
					end
				end
				baseText = baseText or (def and def.name) or att.name or att.attribute_class
				if isstring(baseText) and baseText ~= "" then
					local valueText = formatAttributeValue(att, def)
					local fullText = baseText
					if valueText then
						local replacedCount
						fullText, replacedCount = string.gsub(fullText, "%%s%d*", valueText)
						if replacedCount == 0 then
							fullText = valueText .. " " .. fullText
						end
					end
					fullText = string.Trim(string.gsub(fullText, "%%s%d*", ""))
					lines[#lines + 1] = {
						name = fullText,
						[2] = getAttributeEffectIndex(def and def.effect_type),
					}
				end
			end
		end
	end

	addFromContainer(item.attributes)
	addFromContainer(item.static_attrs)

	if #lines == 0 then
		lines[1] = { name = "No special attributes", [2] = 2 }
	end

	return lines
end

local function getLocalizedTokenText(token)
	if not isstring(token) or token == "" then return nil end
	local resolved = tf_lang.GetRaw(token)
	if not isstring(resolved) or resolved == "" then return nil end
	if string.sub(token, 1, 1) == "#" and string.sub(resolved, 1, 1) == "#" then
		return nil
	end
	return resolved
end

local function findPropertyAttributeByID(properties, attrID, fallback)
	if not istable(properties) or not istable(properties.attributes) then return fallback end
	local want = tonumber(attrID)
	if not want then return fallback end

	for _, pair in ipairs(properties.attributes) do
		if istable(pair) and tonumber(pair[1]) == want then
			return pair[2]
		end
	end

	return fallback
end

getResolvedItemImagePath = function(item, properties)
	if not istable(item) then return nil end
	if tf_item and tf_item.ResolveInventoryImageForItemData then
		local resolved = tf_item.ResolveInventoryImageForItemData(item, properties)
		if isstring(resolved) and resolved ~= "" then
			return resolved
		end
	end
	if isstring(item.image_inventory) and item.image_inventory ~= "" then
		return item.image_inventory
	end
	return nil
end

getDecoratedDisplayName = function(item, properties)
	if not istable(item) then return "UNKNOWN ITEM" end
	if istable(properties) and isstring(properties.custom_name) and properties.custom_name ~= "" then
		return properties.custom_name
	end

	local baseName = getLocalizedTokenText(item.item_name) or item.name or "UNKNOWN ITEM"
	local isWeapon = isstring(item.item_class) and string.StartWith(item.item_class, "tf_weapon_")
	if not isWeapon then
		return baseName
	end

	local paintkitID = tonumber(findPropertyAttributeByID(properties, 834, item.static_attrs and item.static_attrs.paintkit_proto_def_index))
	local festive = tonumber(findPropertyAttributeByID(properties, 2053, 0)) or 0
	local fullName = baseName

	if paintkitID then
		local paintName = nil
		if tf_item and tf_item.GetPaintkitDisplayNameForItemData then
			paintName = tf_item.GetPaintkitDisplayNameForItemData(item, properties)
		end
		if not isstring(paintName) or paintName == "" then
			paintName = "Paintkit " .. tostring(paintkitID)
		end
		fullName = paintName .. " " .. fullName
	end

	if festive > 0 then
		local festivePrefix = (tf_lang and tf_lang.GetRaw and tf_lang.GetRaw("ItemNameFestive", true)) or "Festivized "
		if not isstring(festivePrefix) or festivePrefix == "" then
			festivePrefix = "Festivized "
		end
		fullName = festivePrefix .. fullName
	end

	return fullName
end

local function getTooltipDisplayName(item)
	if not istable(item) then return "UNKNOWN ITEM" end
	return getDecoratedDisplayName(item, item.SteamProperties)
end

local function getTooltipQuality(item)
	local q = istable(item) and item.item_quality or nil
	if not isstring(q) or q == "" then
		return "Unique"
	end
	return string.upper(string.sub(q, 1, 1)) .. string.sub(q, 2)
end

local function getTooltipLevelText(item)
	if not istable(item) then return nil end
	local level = tonumber(item.SteamProperties and item.SteamProperties.level) or tonumber(item.min_ilevel) or tonumber(item.item_level) or tonumber(item.max_ilevel) or 1
	local typeName = getLocalizedTokenText(item.item_type_name) or (isstring(item.item_slot) and string.upper(string.sub(item.item_slot, 1, 1)) .. string.sub(item.item_slot, 2) .. " Item") or "Item"
	return string.format("Level %d %s", math.floor(level), typeName)
end

local function getTooltipDescription(item)
	if not istable(item) then return nil end
	if item.SteamProperties and isstring(item.SteamProperties.custom_desc) and item.SteamProperties.custom_desc ~= "" then
		return item.SteamProperties.custom_desc
	end
	return getLocalizedTokenText(item.item_description)
end

local function makeLoadoutItemEntry(item)
	if not istable(item) then
		return {"NONE", "Normal", surface.GetTextureID(""), {}, nil, nil, nil, nil}
	end

	local tex = surface.GetTextureID(getResolvedItemImagePath(item, item.SteamProperties) or "")
	return {
		getTooltipDisplayName(item),
		getTooltipQuality(item),
		tex,
		buildItemTooltipAttributes(item),
		item,
		getTooltipLevelText(item),
		getTooltipDescription(item),
		nil,
	}
end

local function getClientLoadoutSlotProperties(className, displaySlot)
	if not istable(TFClientLoadoutProperties) or not isstring(className) then return nil end

	local classProps = TFClientLoadoutProperties[className]
	if not istable(classProps) then return nil end

	local slotIndex = tonumber(displaySlot)
	if className == "spy" then
		if slotIndex == 1 then
			slotIndex = 2
		elseif slotIndex == 2 then
			slotIndex = 1
		end
	end

	return classProps[slotIndex]
end

local function getClientLoadoutSlotPropertiesRaw(className, slotIndex)
	if not istable(TFClientLoadoutProperties) or not isstring(className) then return nil end
	local classProps = TFClientLoadoutProperties[className]
	if not istable(classProps) then return nil end
	return classProps[tonumber(slotIndex)]
end

local function getPropertyAttributeByClass(properties, className, fallback)
	if not istable(properties) or not istable(properties.attributes) or not isstring(className) then
		return fallback
	end

	for _, pair in ipairs(properties.attributes) do
		local attrID = istable(pair) and tonumber(pair[1]) or nil
		if attrID and tf_items and tf_items.AttributesByID and istable(tf_items.AttributesByID[attrID]) then
			local def = tf_items.AttributesByID[attrID]
			if def.attribute_class == className then
				return pair[2]
			end
		end
	end

	return fallback
end

local function decodePackedFloat32Integer(raw)
	local n = tonumber(raw)
	if not n then return nil end

	n = bit.band(math.floor(n), 0xFFFFFFFF)

	local sign = bit.band(bit.rshift(n, 31), 0x1)
	local exponent = bit.band(bit.rshift(n, 23), 0xFF)
	local mantissa = bit.band(n, 0x7FFFFF)

	if exponent == 0xFF then
		return nil
	end

	local value
	if exponent == 0 then
		if mantissa == 0 then
			value = 0
		else
			value = (mantissa / 8388608) * (2 ^ -126)
		end
	else
		value = (1 + mantissa / 8388608) * (2 ^ (exponent - 127))
	end

	if sign == 1 then
		value = -value
	end

	return value
end

local function normalizeItemTintValue(raw)
	local n = tonumber(raw)
	if not n or n <= 0 then return nil end

	n = math.floor(n)
	if n <= 0xFFFFFF then
		return n
	end

	local decoded = decodePackedFloat32Integer(n)
	if decoded and decoded > 0 and decoded <= 0xFFFFFF then
		local rounded = math.floor(decoded + 0.5)
		if rounded > 0 and rounded <= 0xFFFFFF then
			return rounded
		end
	end

	return bit.band(n, 0xFFFFFF)
end

local function isTintAttributeClass(attrClass)
	return attrClass == "set_item_tint_rgb"
		or attrClass == "set_item_tint_rgb_2"
		or attrClass == "set_item_tint_rgb_override"
end

local function decodeItemTintColor(raw)
	local n = normalizeItemTintValue(raw)
	if not n then return nil end

	local r = bit.band(bit.rshift(n, 16), 0xFF)
	local g = bit.band(bit.rshift(n, 8), 0xFF)
	local b = bit.band(n, 0xFF)
	return Color(r, g, b, 255)
end

local function getUnusualParticleSystemFromProperties(properties)
	if not istable(properties) then return nil end
	local idx = tonumber(getPropertyAttributeByClass(properties, "set_attached_particle_static", nil))
	if not idx then
		idx = tonumber(getPropertyAttributeByClass(properties, "attach particle effect static", nil))
	end
	if not idx then return nil end
	local def = tf_items and tf_items.Particles and tf_items.Particles[idx] or nil
	if istable(def) and isstring(def.system) and def.system ~= "" then
		return def.system
	end
	return nil
end

local function getFestiveAttachedModelForPreview(item, properties)
	if not istable(item) or not istable(properties) then return nil end

	local festive = tonumber(getPropertyAttributeByClass(properties, "is_festivized", 0)) or 0
	if festive <= 0 then return nil end

	local festiveModels = item.visuals and item.visuals.attached_models_festive or nil
	if (not istable(festiveModels)) and tf_item and tf_item.ResolvePaintkitVisualsForData then
		local paintkitVisuals = tf_item.ResolvePaintkitVisualsForData(item, properties)
		festiveModels = paintkitVisuals and paintkitVisuals.attached_models_festive or nil
	end
	if not istable(festiveModels) then return nil end

	local festiveEntry = festiveModels[0] or festiveModels["0"]
	if not istable(festiveEntry) then
		for _, candidate in pairs(festiveModels) do
			if istable(candidate) and isstring(candidate.model) and candidate.model ~= "" then
				festiveEntry = candidate
				break
			end
		end
	end

	if istable(festiveEntry) and isstring(festiveEntry.model) and festiveEntry.model ~= "" then
		return festiveEntry.model
	end
	return nil
end

local function applyDecoratedPanelVisual(panel, item, properties)
	if not IsValid(panel) then return end

	panel.FallbackModel = nil
	panel.overridematerial = nil

	if not istable(item) then return end

	local resolvedImage = getResolvedItemImagePath(item, properties)
	local hasResolvedIcon = false
	if isstring(resolvedImage) and resolvedImage ~= "" then
		local mat = Material(resolvedImage)
		hasResolvedIcon = mat and not mat:IsError()
	end

	local materialOverride = nil
	if tf_item and tf_item.ResolveMaterialOverrideForItemData then
		materialOverride = tf_item.ResolveMaterialOverrideForItemData(item, properties, LocalPlayer())
	end

	local paintkitID = tonumber(getPropertyAttributeByClass(properties, "paintkit_proto_def_index", item.static_attrs and item.static_attrs.paintkit_proto_def_index))
	local festive = tonumber(getPropertyAttributeByClass(properties, "is_festivized", 0)) or 0
	local needsDecoratedHandling = (paintkitID and paintkitID > 0) or festive > 0 or (isstring(materialOverride) and materialOverride ~= "")

	if not needsDecoratedHandling then return end
	if hasResolvedIcon then return end

	panel.FallbackModel = item.model_player or item.model_world
	if isstring(materialOverride) and materialOverride ~= "" then
		panel.overridematerial = materialOverride
	end
	panel.itemImage = surface.GetTextureID("backpack/weapons/c_models/c_bat")
	panel.tooltip_image = panel.itemImage
end

local function makeLoadoutPlaceholder(label)
	return {
		label or "NONE",
		"Normal",
		surface.GetTextureID(""),
		{},
		nil,
		nil,
		nil,
		nil,
	}
end

local function normalizeLoadoutSplit(split, className)
	local out = {}
	local slotCount = getClassLoadoutSlotCount(className)
	for i = 1, slotCount do
		out[i] = tostring(tonumber(split and split[i]) or -1)
	end
	return out
end

isActionSlotItem = function(item)
	if not istable(item) then return false end
	if item.item_slot == "action" then return true end
	if item.item_class == "tf_powerup_bottle" then return true end
	if isstring(item.prefab) and string.find(string.lower(item.prefab), "powerup_bottle", 1, true) then
		return true
	end
	if istable(item.tool) and item.tool.type == "powerup_bottle" then
		return true
	end

	local itemTypeLocalized = ""
	if tf_lang and tf_lang.GetRaw then
		itemTypeLocalized = string.lower(tostring(tf_lang.GetRaw(item.item_type_name) or ""))
	end
	if itemTypeLocalized ~= "" and string.find(itemTypeLocalized, "usable", 1, true) then
		local name = string.lower(tostring(item.name or ""))
		local localized = ""
		if tf_lang and tf_lang.GetRaw then
			localized = string.lower(tostring(tf_lang.GetRaw(item.item_name) or ""))
		end
		if string.find(name, "power up canteen", 1, true) or string.find(localized, "canteen", 1, true) then
			return true
		end
	end

	if isstring(item.item_name) and item.item_name == "#TF_Usable_PowerupBottle" then
		return true
	end

	return false
end

local function buildLoadoutItemStatsLines(className, loadoutSplit)
	local neutralCol = Color(214, 202, 178, 255)
	local negativeCol = (Colors and Colors.ItemAttribNegative) or Color(235, 80, 80, 255)

	if not isstring(className) or not istable(loadoutSplit) then
		return {
			{ text = "Item stats unavailable.", col = neutralCol },
		}
	end

	local byId = {}
	for _, item in pairs(tf_items.Items or {}) do
		if istable(item) then
			local id = tonumber(item.id)
			if id and not byId[id] then
				byId[id] = item
			end
		end
	end

	local function getSlotLabel(slot)
		local swapped = className == "spy"
		if slot == 1 then return swapped and "Secondary" or "Primary" end
		if slot == 2 then return swapped and "Primary" or "Secondary" end
		if slot == 3 then return "Melee" end
		if slot == 4 then return "Cosmetic 1" end
		if slot == 5 then return "Cosmetic 2" end
		if slot == 6 then return "Cosmetic 3" end
		if slot == 7 then return "Action" end
		if slot == 8 then
			if className == "engineer" then return "PDA" end
			if className == "spy" then return "Watch" end
		end
		return "Slot " .. tostring(slot)
	end

	local function getItemDisplayName(item)
		return getTooltipDisplayName(item)
	end

	local function getItemStatSummary(item)
		if not istable(item) then return nil end
		local attrs = buildItemTooltipAttributes(item)
		local out = {}
		for _, line in ipairs(attrs) do
			if istable(line) and line[2] == 4 and isstring(line.name) and line.name ~= "" and line.name ~= "No special attributes" then
				out[#out + 1] = line.name
			end
		end
		if #out == 0 then
			return nil
		end
		if #out > 3 then
			local trimmed = { out[1], out[2], out[3] }
			return table.concat(trimmed, ", ") .. " ..."
		end
		return table.concat(out, ", ")
	end

	local lines = {
		{ text = "EQUIPPED ITEM STATS", col = neutralCol },
	}

	local classSlotCount = getClassLoadoutSlotCount(className)
	for slot = 1, classSlotCount do
		local itemId = tonumber(loadoutSplit[slot])
		if itemId and itemId > 0 then
			local item = byId[itemId]
			if istable(item) then
				local negativeSummary = getItemStatSummary(item)
				if negativeSummary then
					lines[#lines + 1] = {
						text = getSlotLabel(slot) .. ": " .. getItemDisplayName(item),
						col = neutralCol,
					}
					lines[#lines + 1] = {
						text = "  " .. negativeSummary,
						col = negativeCol,
					}
				end
			end
		end
	end

	if #lines <= 1 then
		lines[#lines + 1] = { text = "No negative equipped item stats.", col = neutralCol }
	end

	return lines
end


function PANEL:Init()
	self:SetPaintBackgroundEnabled(true)
	self:SetVisible(false)
	self:SetParent(CharInfoPanel)
end

local function updateLoadout(type, id, update, class)
	local convar = GetConVar("loadout_" .. class)
	if not convar then return end
	local slot = tonumber(type)
	local slotCount = getClassLoadoutSlotCount(class)
	if not slot or slot < 1 or slot > slotCount then return end

	local split = normalizeLoadoutSplit(string.Split(convar:GetString(), ","), class)
	split[slot] = tostring(tonumber(id) or -1)
	convar:SetString(table.concat(split, ","))
	if update then
		timer.Simple(0.3, function()
			RunConsoleCommand("loadout_update")
		end)
	end
end

function PANEL:PerformLayout()
	self:SetPos(0, 67*Scale)
	self:SetSize(W, H)
	
	local ply = LocalPlayer()
	local oldclass = "scout"
	if (GetConVar("tf_hud_loadout_class"):GetInt() == 1) then
		oldclass = "scout"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 2) then
		oldclass = "soldier"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 3) then
		oldclass = "pyro"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 4) then
		oldclass = "demoman"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 5) then
		oldclass = "heavy"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 6) then
		oldclass = "engineer"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 7) then
		oldclass = "medic"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 8) then
		oldclass = "sniper"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 9) then
		oldclass = "spy"
	end
	local convar = GetConVar("loadout_" .. oldclass)
	if not convar then return end

	local screenW, screenH = ScrW(), ScrH()
	local layoutScale = math.Clamp(math.min(screenW / 1920, screenH / 1080), 0.78, 1.30)
	local slotWide = math.floor(306 * layoutScale)
	local slotTall = math.floor(150 * layoutScale)
	local slotGapY = math.floor(14 * layoutScale)
	local slotStartY = math.floor(130 * layoutScale)
	local leftColumnX = math.floor(screenW * 0.13)
	local rightColumnX = screenW - leftColumnX - slotWide
	local tooltipOffsetLeft = math.floor((slotWide / Scale) + 12)
	local tooltipOffsetRight = -math.floor((slotWide / Scale) + 14)
	local tooltipOffsetY = math.floor(6 * layoutScale)
	local classPanelW = math.floor(390 * layoutScale)
	local classPanelH = math.floor(640 * layoutScale)
	local classPanelX = math.floor((screenW - classPanelW) * 0.5)
	local classPanelY = math.floor(74 * layoutScale)
	
	local weapons = {{}, {}, {}, {}, {}, {}}

	for id, item in pairs(tf_items.Items) do
		if istable(item) and itemUsableByClass(item, oldclass) then
			if item.item_slot == "primary" then
				weapons[1][id] = item -- table.insert(weapons[1], ) --id) -- weapon1:AddChoice(item.name, item.id)
			elseif item.item_slot == "secondary" then
				weapons[2][id] = item -- weapon2:AddChoice(item.name, item.id)
			elseif item.item_slot == "melee" then
				weapons[3][id] = item -- weapon3:AddChoice(item.name, item.id)
			elseif item.item_slot == "head" or item.item_slot == "misc" then
				weapons[4][id] = item -- weapon3:AddChoice(item.name, item.id)
			elseif isActionSlotItem(item) then
				weapons[5][id] = item
			end

			if oldclass == "engineer" and item.item_slot == "pda" then
				weapons[6][id] = item
			elseif oldclass == "spy" and item.item_slot == "pda2" then
				weapons[6][id] = item
			end
		end
	end
	
	local loadout = normalizeLoadoutSplit(string.Split(convar:GetString(), ","), oldclass)

	-- The attribute panel, which displays the name and attributes of each item
	if not self.AttributePanel then
		local t = vgui.Create("ItemAttributePanel")
		t:SetParent(self)
		t:SetSize(236*Scale,252*Scale)
		t.text_ypos = 20
		
		self.AttributePanel = t
	end
	
		
	local Items = {
		makeLoadoutPlaceholder("PRIMARY"),
		makeLoadoutPlaceholder("SECONDARY"),
		makeLoadoutPlaceholder("MELEE"),
		makeLoadoutPlaceholder("COSMETIC"),
		makeLoadoutPlaceholder("COSMETIC"),
		makeLoadoutPlaceholder("COSMETIC"),
		makeLoadoutPlaceholder("ACTION"),
	}
	if oldclass == "engineer" then
		Items[#Items + 1] = makeLoadoutPlaceholder("PDA")
	elseif oldclass == "spy" then
		Items[#Items + 1] = makeLoadoutPlaceholder("WATCH")
	end

	for name, wep in pairs(tf_items.Items) do
		if istable(wep) then	
			if wep.id == tonumber(loadout[1]) then
				Items[1] = makeLoadoutItemEntry(wep)
			elseif wep.id == tonumber(loadout[2]) then
				Items[2] = makeLoadoutItemEntry(wep)
			elseif wep.id == tonumber(loadout[3]) then
				Items[3] = makeLoadoutItemEntry(wep)
			elseif wep.id == tonumber(loadout[4]) then
				Items[4] = makeLoadoutItemEntry(wep)
			elseif wep.id == tonumber(loadout[5]) then
				Items[5] = makeLoadoutItemEntry(wep)
			elseif wep.id == tonumber(loadout[6]) then
				Items[6] = makeLoadoutItemEntry(wep)
			elseif wep.id == tonumber(loadout[7]) then
				Items[7] = makeLoadoutItemEntry(wep)
			elseif wep.id == tonumber(loadout[8]) then
				Items[8] = makeLoadoutItemEntry(wep)
			end
		end
	end
	local function getSlotPanelLayout(slotIndex)
		local useEvenColumns = (oldclass == "engineer" or oldclass == "spy") and #Items >= 8
		if useEvenColumns then
			local leftColumnRows = {
				[1] = 0,
				[2] = 1,
				[3] = 2,
				[8] = 3,
			}

			local leftRow = leftColumnRows[slotIndex]
			if leftRow ~= nil then
				return leftColumnX, slotStartY + leftRow * (slotTall + slotGapY), tooltipOffsetLeft
			end

			local rightRow = math.max(0, slotIndex - 4)
			return rightColumnX, slotStartY + rightRow * (slotTall + slotGapY), tooltipOffsetRight
		end

		if slotIndex <= 3 then
			local row = slotIndex - 1
			return leftColumnX, slotStartY + row * (slotTall + slotGapY), tooltipOffsetLeft
		end
		local row = slotIndex - 4
		return rightColumnX, slotStartY + row * (slotTall + slotGapY), tooltipOffsetRight
	end

	-- The item panels, with the name and a picture of each item currently equipped
	if self.ItemPanels and #self.ItemPanels ~= #Items then
		for _, panel in ipairs(self.ItemPanels) do
			if IsValid(panel) then
				panel:Remove()
			end
		end
		self.ItemPanels = nil
	end

	if not self.ItemPanels then
		self.ItemPanels = {}
		for k = 1, #Items do
			local t = vgui.Create("ItemModelPanel")
			t:SetParent(self)
			t.activeImage = loadout_rect_mouseover
			t.inactiveImage = loadout_rect
			self.ItemPanels[k] = t
		end
	end

	for k, v in ipairs(Items) do
		local t = self.ItemPanels[k]
		if IsValid(t) then
			local slotProperties = getClientLoadoutSlotProperties(oldclass, k)
			local slotItem = v[5]
			local slotImagePath = getResolvedItemImagePath(slotItem, slotProperties or (slotItem and slotItem.SteamProperties))
			local slotImage = surface.GetTextureID(slotImagePath or "")
			local slotName = slotItem and getDecoratedDisplayName(slotItem, slotProperties or slotItem.SteamProperties) or nil
			local x, y, xoffset = getSlotPanelLayout(k)
			local unscaledTall = math.max(40, math.floor(slotTall / Scale))

			t:SetPos(x, y)
			t:SetSize(slotWide, slotTall)
			t.model_ypos = 5
			t.model_tall = math.max(30, math.floor(unscaledTall * 0.62))
			t.text_ypos = math.max(32, math.floor(unscaledTall * 0.78))
			t.text_xpos = 0
			t.text_wide = math.max(80, math.floor(slotWide / Scale))
			t.itemImage = (slotImagePath and slotImage) or v[3]
			t.text = slotName or v[1]
			t.attributes = nil
			t.tooltip_attributes = v[4]
			t.tooltip_name = slotName or v[1]
			t.tooltip_image = (slotImagePath and slotImage) or v[3]
			t.tooltip_leveltext = v[6]
			t.tooltip_description = v[7]
			t.tooltip_flavor = v[8]
			t.number = nil
			t:SetQuality(v[2])
			t:SetAttributePanel(self.AttributePanel, xoffset, tooltipOffsetY)
			applyDecoratedPanelVisual(t, slotItem, slotProperties)

			if (k == 1) then
				t.DoClick = function() itemSelector(1, weapons[1], self:GetParent(), GetConVar("tf_hud_loadout_class"):GetInt(), oldclass) end
			elseif (k == 2) then
				t.DoClick = function() itemSelector(2, weapons[2], self:GetParent(), GetConVar("tf_hud_loadout_class"):GetInt(), oldclass) end
			elseif (k == 3) then
				t.DoClick = function() itemSelector(3, weapons[3], self:GetParent(), GetConVar("tf_hud_loadout_class"):GetInt(), oldclass) end
			elseif (k == 4) then
				t.DoClick = function() hatSelector("hat",4,oldclass,weapons[4]) end
			elseif (k == 5) then
				t.DoClick = function() hatSelector("hat",5,oldclass,weapons[4]) end
			elseif (k == 6) then
				t.DoClick = function() hatSelector("hat",6,oldclass,weapons[4]) end
			elseif (k == 7) then
				t.DoClick = function() actionSelector(7, oldclass, weapons[5]) end
			elseif (k == 8) then
				t.DoClick = function() itemSelector(8, weapons[6], self:GetParent(), GetConVar("tf_hud_loadout_class"):GetInt(), oldclass) end
			end
		end
	end
	
	
	-- Move the attribute panel in front of everything
	self.AttributePanel:MoveToFront()
	
	-- And finally, the button to go back to the main loadout menu
	if not self.BackButton then
		self.BackButton = vgui.Create("TFButton")
		self.BackButton:SetParent(self)
		self.BackButton.labelText = "<< BACK"
		self.BackButton.font = "HudFontSmallBold"
		function self.BackButton:DoClick()
			CharInfoLoadoutSubPanel:SelectClassLoadout(0)
		end
	end
	self.BackButton:SetSize(100 * Scale, 25 * Scale)
	self.BackButton:SetPos(W/2 - 310*Scale, 320*Scale)
	self.BackButton:MoveToFront()

	if not self.CloseLoadoutButton then
		self.CloseLoadoutButton = vgui.Create("TFButton")
		self.CloseLoadoutButton:SetParent(self)
		self.CloseLoadoutButton.labelText = "CLOSE"
		self.CloseLoadoutButton.font = "HudFontSmallBold"
		function self.CloseLoadoutButton:DoClick()
			forceCloseLoadoutPanels()
		end
	end
	self.CloseLoadoutButton:SetSize(100 * Scale, 25 * Scale)
	self.CloseLoadoutButton:SetPos(W/2 + 200*Scale, math.floor(H - self.CloseLoadoutButton:GetTall() - (H * 0.03)))
	self.CloseLoadoutButton:MoveToFront()

	if not self.TauntLoadoutButton then
		self.TauntLoadoutButton = vgui.Create("DImageButton")
		self.TauntLoadoutButton:SetParent(self)
		self.TauntLoadoutButton:SetImage("hud/ico_reel")
		self.TauntLoadoutButton:SetTooltip("Taunt Loadout")
		function self.TauntLoadoutButton:DoClick()
			openTauntLoadoutPanel(CharInfoPanel)
		end
	end
	local tauntBtnSize = math.floor(25 * Scale)
	self.TauntLoadoutButton:SetSize(tauntBtnSize, tauntBtnSize)
	self.TauntLoadoutButton:SetPos(math.floor(W * 0.5 + 2 * Scale), math.floor(H * 0.5 + 90 * Scale))
	self.TauntLoadoutButton:MoveToFront()
	local t
	-- The class panel, shows the current class selected holding the last weapon equipped
	if not self.ClassPanel then
		t = vgui.Create("ClassModelPanel")
		t:SetParent(self)
		t:SetPos(classPanelX, classPanelY)
		t:SetSize(classPanelW, classPanelH)
		t.FOV = 50
		t.spotlight = true
		self.ClassPanel = t
		
			
		-- oh no
		--print(":O")
		if ply:GetPlayerClass() != "demoman" then

			--[[
			for name, wep in pairs(tf_items.Items) do
				if istable(wep) then
					if wep.id == tonumber(loadout[1]) then
						weapon1.text = name
						if wep.image_inventory then
							weapon1.icon = surface.GetTextureID(wep.image_inventory)
						end
					elseif wep.id == tonumber(loadout[2]) then
						weapon2.text = name
						if wep.image_inventory then
							weapon2.icon = surface.GetTextureID(wep.image_inventory)
						end
					elseif wep.id == tonumber(loadout[3]) then
						weapon3.text = name
						if wep.image_inventory then
							weapon3.icon = surface.GetTextureID(wep.image_inventory)
						end
					end
				end
			end]]
		else
			--[[
			for name, wep in pairs(tf_items.Items) do
				if istable(wep) then
					if wep.id == tonumber(loadout[2]) then
						weapon1.text = name
						if wep.image_inventory then
							weapon1.icon = surface.GetTextureID(wep.image_inventory)
						end
					elseif wep.id == tonumber(loadout[1]) then
						weapon2.text = name
						if wep.image_inventory then
							weapon2.icon = surface.GetTextureID(wep.image_inventory)
						end
					elseif wep.id == tonumber(loadout[3]) then
						weapon3.text = name
						if wep.image_inventory then
							weapon3.icon = surface.GetTextureID(wep.image_inventory)
						end
					end
				end
			end
			]]
		end

		if (GetConVar("tf_hud_loadout_class"):GetInt() == 1) then
			t:AddModel(1,"models/player/scout.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 2) then
			t:AddModel(1,"models/player/soldier.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 3) then
			t:AddModel(1,"models/player/pyro.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 4) then
			t:AddModel(1,"models/player/demo.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 5) then
			t:AddModel(1,"models/player/heavy.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 6) then
			t:AddModel(1,"models/player/engineer.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 7) then
			t:AddModel(1,"models/player/medic.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 8) then
			t:AddModel(1,"models/player/sniper.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 9) then
			t:AddModel(1,"models/player/spy.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		end

		local function getWearablePreviewModel(item, className)
			if not istable(item) then return nil end

			local perClass = item.model_player_per_class
			if istable(perClass) then
				local resolved = perClass[className] or perClass[(className == "demoman" and "demo" or className)] or perClass.basename
				if isstring(resolved) and resolved ~= "" then
					resolved = string.Replace(resolved, "%s", className)
					if className == "demoman" and not file.Exists(resolved, "GAME") then
						local demoResolved = string.Replace(resolved, "demoman", "demo")
						if file.Exists(demoResolved, "GAME") then
							resolved = demoResolved
						end
					end
					return resolved
				end
			elseif isstring(perClass) and perClass ~= "" then
				local resolved = string.Replace(perClass, "%s", className)
				if className == "demoman" and not file.Exists(resolved, "GAME") then
					local demoResolved = string.Replace(perClass, "%s", "demo")
					if file.Exists(demoResolved, "GAME") then
						resolved = demoResolved
					end
				end
				return resolved
			end
			if isstring(item.model_player) and item.model_player ~= "" then
				return item.model_player
			end
			if isstring(item.model_world) and item.model_world ~= "" then
				return item.model_world
			end
			return nil
		end

		for name, wep in pairs(tf_items.Items) do
			if istable(wep) then
				if wep.id == tonumber(loadout[4]) then
					local slotProps = getClientLoadoutSlotPropertiesRaw(oldclass, 4)
					local wearableModel = getWearablePreviewModel(wep, oldclass)
					if isstring(wearableModel) then
						local modelKeys = {
							Parent = 1,
						}
						local tint = decodeItemTintColor(slotProps and getPropertyAttributeByClass(slotProps, "set_item_tint_rgb", nil) or nil)
						if tint then
							modelKeys.TintColor = tint
						end
						local unusual = getUnusualParticleSystemFromProperties(slotProps)
						if unusual then
							modelKeys.ParticleSystem = unusual
						end
						t:AddModel(3, wearableModel, modelKeys)
					end

				elseif wep.id == tonumber(loadout[5]) then
					local slotProps = getClientLoadoutSlotPropertiesRaw(oldclass, 5)
					local wearableModel = getWearablePreviewModel(wep, oldclass)
					if isstring(wearableModel) then
						local modelKeys = {
							Parent = 1,
						}
						local tint = decodeItemTintColor(slotProps and getPropertyAttributeByClass(slotProps, "set_item_tint_rgb", nil) or nil)
						if tint then
							modelKeys.TintColor = tint
						end
						local unusual = getUnusualParticleSystemFromProperties(slotProps)
						if unusual then
							modelKeys.ParticleSystem = unusual
						end
						t:AddModel(4, wearableModel, modelKeys)
					end

				elseif wep.id == tonumber(loadout[6]) then
					local slotProps = getClientLoadoutSlotPropertiesRaw(oldclass, 6)
					local wearableModel = getWearablePreviewModel(wep, oldclass)
					if isstring(wearableModel) then
						local modelKeys = {
							Parent = 1,
						}
						local tint = decodeItemTintColor(slotProps and getPropertyAttributeByClass(slotProps, "set_item_tint_rgb", nil) or nil)
						if tint then
							modelKeys.TintColor = tint
						end
						local unusual = getUnusualParticleSystemFromProperties(slotProps)
						if unusual then
							modelKeys.ParticleSystem = unusual
						end
						t:AddModel(5, wearableModel, modelKeys)
					end

				end
				local oldclass2 = oldclass
				if (oldclass == "spy") then
					if wep.id == tonumber(loadout[2]) then
						local weaponProps = getClientLoadoutSlotPropertiesRaw(oldclass, 2)
						local weaponKeys = {
							Parent = 1,
						}
						if tf_item and tf_item.ResolveMaterialOverrideForItemData then
							local matOverride = tf_item.ResolveMaterialOverrideForItemData(wep, weaponProps, LocalPlayer())
							if isstring(matOverride) and matOverride ~= "" then
								weaponKeys.MaterialOverride = matOverride
							end
						end
						local unusual = getUnusualParticleSystemFromProperties(weaponProps)
						if unusual then
							weaponKeys.ParticleSystem = unusual
						end
						t:AddModel(2, wep.model_world or wep.model_player, weaponKeys)
						local festiveModel = getFestiveAttachedModelForPreview(wep, weaponProps)
						if isstring(festiveModel) and festiveModel ~= "" then
							t:AddModel(6, festiveModel, {
								Parent = 2,
							})
						end
						t:StartAnimation(1,ACT_MP_STAND_SECONDARY)
					end
				else
					if wep.id == tonumber(loadout[1]) then
						local weaponProps = getClientLoadoutSlotPropertiesRaw(oldclass, 1)
						local weaponKeys = {
							Parent = 1,
						}
						if tf_item and tf_item.ResolveMaterialOverrideForItemData then
							local matOverride = tf_item.ResolveMaterialOverrideForItemData(wep, weaponProps, LocalPlayer())
							if isstring(matOverride) and matOverride ~= "" then
								weaponKeys.MaterialOverride = matOverride
							end
						end
						local unusual = getUnusualParticleSystemFromProperties(weaponProps)
						if unusual then
							weaponKeys.ParticleSystem = unusual
						end
						t:AddModel(2, wep.model_world or wep.model_player, weaponKeys)
						local festiveModel = getFestiveAttachedModelForPreview(wep, weaponProps)
						if isstring(festiveModel) and festiveModel ~= "" then
							t:AddModel(6, festiveModel, {
								Parent = 2,
							})
						end
						if (oldclass == "spy") then
							t:StartAnimation(1,ACT_MP_STAND_BUILDING)
						else
							t:StartAnimation(1,ACT_MP_STAND_PRIMARY)
						end
					end
				end
			end
		end
	end

	if IsValid(self.ClassPanel) then
		self.ClassPanel:SetPos(classPanelX, classPanelY)
		self.ClassPanel:SetSize(classPanelW, classPanelH)
	end

	if IsValid(self.ItemStatsLabel) then
		self.ItemStatsLabel:Remove()
		self.ItemStatsLabel = nil
	end

	if not self.ItemStatsPanel then
		self.ItemStatsPanel = vgui.Create("DPanel")
		self.ItemStatsPanel:SetParent(self)
		self.ItemStatsPanel:SetPos(classPanelX + math.floor(22 * layoutScale), classPanelY + classPanelH - math.floor(126 * layoutScale))
		self.ItemStatsPanel:SetSize(classPanelW - math.floor(44 * layoutScale), math.floor(120 * layoutScale))
		self.ItemStatsPanel:SetPaintBackground(false)
		self.ItemStatsPanel.Lines = {}
		self.ItemStatsPanel.Paint = function(pnl, w, h)
			local y = 0
			for _, line in ipairs(pnl.Lines or {}) do
				local text = line and line.text or ""
				if isstring(text) and text ~= "" then
					local tab = {
						x = 0,
						y = y,
						w = w,
						h = h - y,
						font = "ItemFontAttribSmall",
						text = text,
						col = line.col or Color(214, 202, 178, 255),
						align = "north",
						yspace = 1,
					}
					local th = tf_draw.LabelTextWrap(tab, true)
					if y + th > h then break end
					tf_draw.LabelTextWrap(tab)
					y = y + th + 1
				end
			end
		end
	end
	self.ItemStatsPanel:SetPos(classPanelX + math.floor(22 * layoutScale), classPanelY + classPanelH - math.floor(126 * layoutScale))
	self.ItemStatsPanel:SetSize(classPanelW - math.floor(44 * layoutScale), math.floor(120 * layoutScale))
	self.ItemStatsPanel.Lines = buildLoadoutItemStatsLines(oldclass, loadout)
end



function PANEL:Paint()
	-- Header lines
	
	surface.SetDrawColor(255,255,255,255)	
	tf_draw.TexturedQuadTiled(loadout_dotted_line, W/2-305*Scale, 40*Scale, 610*Scale, 10*Scale, {y=false})
	
	-- Labels
	tf_draw.LabelText(
		W/2-300*Scale,
		20*Scale,
		20*Scale,
		15*Scale,
		">>",
		Color(200, 80, 60, 255),
		"HudFontSmallestBold",
		"west"
	)
	if (GetConVar("tf_hud_loadout_class"):GetInt() == 1) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"SCOUT",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 2) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"SOLDIER",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 3) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"PYRO",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 4) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"DEMOMAN",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 5) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"HEAVY",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 6) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"ENGINEER",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 7) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"MEDIC",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 8) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"SNIPER",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 9) then

		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"SPY",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	end
	
	tf_draw.LabelText(
		W/2-55*Scale,
		22*Scale,
		180*Scale,
		15*Scale,
		"CURRENTLY EQUIPPED:",
		"TanLight",
		"HudFontSmallestBold",
		"south-west"
	)

	tf_draw.LabelText(
		W/2-150*Scale,
		20*Scale,
		20*Scale,
		15*Scale,
		">>",
		Color(200, 80, 60, 255),
		"HudFontSmallestBold",
		"west"
	)
	tf_draw.LabelText(
		W/2-130*Scale,
		15*Scale,
		120*Scale,
		25*Scale,
		tf_lang.GetRaw("TF_Taunt") or "TAUNTS",
		"TanLight",
		"HudFontMediumBold",
		"west"
	)
	tf_draw.LabelText(
		W/2+90*Scale,
		20*Scale,
		250*Scale,
		25*Scale,
		tf_lang.GetRaw("TF_ClassLoadoutTauntInputHint") or "Hit your taunt key for the in-game taunt HUD",
		Color(214, 202, 178, 220),
		"HudFontSmall",
		"east"
	)
end
local OLDPANEL = PANEL
local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local class_sel_sm = {}
local classes = {"scout", "soldier", "pyro", "demo", "heavy", "engineer", "medic", "sniper", "spy"}
local classnames = {"SCOUT", "SOLDIER", "PYRO", "DEMOMAN", "HEAVY", "ENGINEER", "MEDIC", "SNIPER", "SPY"}

local class_ypos = 40
local class_xdelta = 5
local class_wide_min = 60
local class_wide_max = 100
local class_tall_min = 120
local class_tall_max = 200
local class_distance_min = 7
local class_distance_max = 100

local class_size_speed = 10

do
	local tree = TF2Res and TF2Res.Load and TF2Res.Load("resource/ui/charinfoloadoutsubpanel.res")
	local root = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "CharInfoLoadoutSubPanel")
	if root and TF2Res.GetNumber then
		class_ypos = TF2Res.GetNumber(root, "class_ypos", class_ypos)
		class_xdelta = TF2Res.GetNumber(root, "class_xdelta", class_xdelta)
		class_wide_min = TF2Res.GetNumber(root, "class_wide_min", class_wide_min)
		class_wide_max = TF2Res.GetNumber(root, "class_wide_max", class_wide_max)
		class_tall_min = TF2Res.GetNumber(root, "class_tall_min", class_tall_min)
		class_tall_max = TF2Res.GetNumber(root, "class_tall_max", class_tall_max)
		class_distance_min = TF2Res.GetNumber(root, "class_distance_min", class_distance_min)
		class_distance_max = TF2Res.GetNumber(root, "class_distance_max", class_distance_max)
	end
end

for k,v in ipairs(classes) do
	class_sel_sm[k] = {
		surface.GetTextureID("vgui/class_sel_sm_"..v.."_red"),
		surface.GetTextureID("vgui/class_sel_sm_"..v.."_inactive")
	}
end

local backpack_01 = surface.GetTextureID("hud/backpack_01")
local backpack_01_grey = surface.GetTextureID("hud/backpack_01_grey")

function PANEL:SelectClassLoadout(c)
	if c>=1 and c<=10 then
		FullLoadoutPanel:SetVisible(true)
		self:ResetButtons()
		self:SetVisible(false)
	else
		FullLoadoutPanel:SetVisible(false)
		self:SetVisible(true)
	end
end

function PANEL:SelectClassLoadout2(c) 
	if c>=1 and c<=10 then
		if FullLoadoutPanel then FullLoadoutPanel:Remove() end
		FullLoadoutPanel = vgui.CreateFromTable(vgui.RegisterTable(OLDPANEL, "DPanel"))
		FullLoadoutPanel:SetVisible(true)
		self:ResetButtons()
		self:SetVisible(false)
	else
		FullLoadoutPanel:SetVisible(false)
		self:SetVisible(true)
	end
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:SetVisible(true)
	self:SetParent(CharInfoPanel)
	
	-- Class loadout buttons
	self.ClassButtons = {}
	local x = (W/2)/Scale - (4.5 * class_wide_min + 4 * class_xdelta)
	for k,_ in ipairs(classes) do
		local t = vgui.Create("TFButton")
		t:SetParent(self)
		t:SetPos(x*Scale, (28+class_ypos)*Scale)
		t:SetSize(class_wide_min*Scale,class_tall_min*Scale)
		t.activeImage = class_sel_sm[k][1]
		t.inactiveImage = class_sel_sm[k][2]
		
		t.xcenter = Scale * (x+class_wide_min/2)
		t.ycenter = Scale * (28+class_ypos+class_tall_min/2)
		
		function t:DoClick()
			RunConsoleCommand("tf_hud_loadout_class",""..k)
			timer.Simple(0.1, function()
			
				if FullLoadoutPanel then FullLoadoutPanel:Remove() end
				FullLoadoutPanel = vgui.CreateFromTable(vgui.RegisterTable(OLDPANEL, "DPanel"))
				self:GetParent():SelectClassLoadout(k)
				self:GetParent().char_model = "models/player/medic.mdl"
				
			end)
		end
		
		self.ClassButtons[k] = t
		
		x = x + class_wide_min + class_xdelta
	end
	
	-- Backpack
	local t = vgui.Create("TFButton")
	t:SetParent(self)
	t:SetPos(W/2-60*Scale, 254*Scale)
	t:SetSize(60*Scale,60*Scale)
	t.activeImage = surface.GetTextureID("overlays/no_entry")
	t.inactiveImage = surface.GetTextureID("overlays/no_entry")
	
	function t:DoClick()

		local conflict_help_frame = vgui.Create( "DFrame" )
		conflict_help_frame:SetSize(200, 200)
		conflict_help_frame:Center()
		conflict_help_frame:SetTitle("Oh no!")
		conflict_help_frame:ShowCloseButton(true)
		conflict_help_frame:SetBackgroundBlur(true)
		conflict_help_frame:MakePopup()

		local conflicttext = vgui.Create("RichText", conflict_help_frame)
		conflicttext:Dock(FILL)
		conflicttext:InsertColorChange(255, 255, 255, 255)
		conflicttext:CenterHorizontal(0.5)
		conflicttext:SetVerticalScrollbarEnabled(false)
		conflicttext:AppendText("Are you sure? This action is irreversible and all of your items in this gamemode will be reset to default!")
			local conflictbut2 = vgui.Create("DButton", conflict_help_frame)
			conflictbut2:SetSize(100, 30)
			conflictbut2:SetPos(0, 125)
			conflictbut2:CenterHorizontal(0.5)
			conflictbut2:SetText("I'm 100% sure.") 

			function conflictbut2.DoClick()
				conflict_help_frame:Close()
				RunConsoleCommand("loadout_scout","-1,-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_soldier","-1,-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_pyro","-1,-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_demoman","-1,-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_heavy","-1,-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_engineer","-1,-1,-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_medic","-1,-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_sniper","-1,-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_spy","-1,-1,-1,-1,-1,-1,-1,-1")
				forceCloseLoadoutPanels()
				timer.Simple(5, function()
					forceCloseLoadoutPanels()
				end)
			end
	end
	
	local t = vgui.Create("TFButton")
	t:SetParent(self)
	t:SetPos(W/2+30*Scale, 254*Scale)
	t:SetSize(60*Scale,60*Scale)
	t.activeImage = backpack_01
	t.inactiveImage = backpack_01_grey
	
	function t:DoClick()
		local classMap = {
			[1] = "scout",
			[2] = "soldier",
			[3] = "pyro",
			[4] = "demoman",
			[5] = "heavy",
			[6] = "engineer",
			[7] = "medic",
			[8] = "sniper",
			[9] = "spy",
		}
		local classIndex = GetConVar("tf_hud_loadout_class"):GetInt()
		local className = classMap[classIndex] or "scout"
		if isfunction(TF_OpenStandaloneBackpack) then
			TF_OpenStandaloneBackpack(className, classIndex)
		end
	end

end

function PANEL:ResetButtons()
	local w, h = Scale*class_wide_min, Scale*class_tall_min
	for k,v in ipairs(self.ClassButtons) do
		v:SetPos(v.xcenter-w/2, v.ycenter-h/2)
		v:SetSize(w, h)
	end
end

function PANEL:PerformLayout()
	self:SetPos(0, 40*Scale)
	self:SetSize(W, H)
	
	if not self.ClassButtons then return end
	
	local active = false
	for _,v in ipairs(self.ClassButtons) do
		if v.Hover then
			active = true
			break
		end
	end
	
	if active then
		local x, y = self:CursorPos()
		for k,v in ipairs(self.ClassButtons) do
			local dist = math.Clamp(math.abs(v.xcenter - x) / Scale, class_distance_min, class_distance_max)
			local r = 1 - (dist - class_distance_min) / (class_distance_max - class_distance_min)
			
			local w, h = Scale*Lerp(r, class_wide_min, class_wide_max), Scale*Lerp(r, class_tall_min, class_tall_max)
			v.TargetSize = Vector(w, h, 0)
		end
	else
		for k,v in ipairs(self.ClassButtons) do
			local w, h = Scale*class_wide_min, Scale*class_tall_min
			v.TargetSize = Vector(w, h, 0)
		end
	end
	
	for k,v in ipairs(self.ClassButtons) do
		if v.TargetSize then
			local w0, h0 = v:GetSize()
			local dw, dh = (v.TargetSize.x - w0) * RealFrameTime() * class_size_speed, (v.TargetSize.y - h0) * RealFrameTime() * class_size_speed
			local w, h = w0 + dw, h0 + dh
			
			v:SetPos(v.xcenter-w/2, v.ycenter-h/2)
			v:SetSize(w, h)
		end
	end
end

function PANEL:Think()
	self:InvalidateLayout()
end

function PANEL:Paint()
	draw.Text{
		text="SELECT A CLASS TO MODIFY LOADOUT",
		font="HudFontSmallBold",
		pos={W/2, 330*Scale},
		color=Color(117, 107, 94, 255),
		xalign=TEXT_ALIGN_CENTER,
		yalign=TEXT_ALIGN_TOP,
	}
	
	draw.Text{
		text="CLICK THE NO ENTRY ICON TO RESET YOUR LOADOUT",
		font="HudFontSmallBold",
		pos={W/2, 360*Scale},
		color=Color(117, 107, 94, 255),
		xalign=TEXT_ALIGN_CENTER,
		yalign=TEXT_ALIGN_TOP,
	}
	for k,v in ipairs(self.ClassButtons) do
		if v.Hover then
			draw.Text{
				text=classnames[k],
				font="HudFontSmallBold",
				pos={v.xcenter, 226*Scale},
				color=Color(235, 226, 202, 255),
				xalign=TEXT_ALIGN_CENTER,
				yalign=TEXT_ALIGN_TOP,
			}
			
			draw.Text{
				text="(∞ ITEMS IN INVENTORY)",
				font="HudFontSmall",
				pos={v.xcenter, 242*Scale},
				color=Color(200, 80, 60, 255),
				xalign=TEXT_ALIGN_CENTER,
				yalign=TEXT_ALIGN_TOP,
			}
		end
	end
end

if CharInfoLoadoutSubPanel then CharInfoLoadoutSubPanel:Remove() end
CharInfoLoadoutSubPanel = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))


local BackpackPickerPanel

local function classCanUseItem(item, className)
	return itemUsableByClass(item, className)
end

local function isWearableLoadoutItem(item)
	if not istable(item) then return false end
	local class = string.lower(tostring(item.item_class or ""))
	if class == "tf_wearable_item" or class == "tf_wearable" then
		return true
	end
	return string.StartWith(class, "tf_wearable_")
end

local function createBackpackPicker(title, oldclass, canEquipFn, onEquipFn)
	if IsValid(BackpackPickerPanel) then
		BackpackPickerPanel:Remove()
	end

	local loadout_rect = surface.GetTextureID("vgui/loadout_rect")
	local loadout_rect_mouseover = surface.GetTextureID("vgui/loadout_rect_mouseover")

	local parent = IsValid(CharInfoPanel) and CharInfoPanel or nil
	local panel = vgui.Create("EditablePanel", parent)
	panel:SetSize(ScrW() - 100 * Scale, ScrH() - 110 * Scale)
	panel:Center()
	panel:MakePopup()
	panel:SetKeyboardInputEnabled(true)
	panel:SetMouseInputEnabled(true)
	panel:SetZPos(9999)
	BackpackPickerPanel = panel

	function panel:Paint(w, h)
		surface.SetDrawColor(18, 17, 16, 245)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(90, 83, 72, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 2)

		draw.Text{
			text = title or "BACKPACK",
			font = "HudFontMediumBold",
			pos = {20, 18},
			color = Color(235, 226, 202, 255),
			xalign = TEXT_ALIGN_LEFT,
			yalign = TEXT_ALIGN_TOP,
		}

		draw.Text{
			text = "All items are shown. Unusable items are dimmed.",
			font = "HudFontSmall",
			pos = {20, 48},
			color = Color(170, 160, 146, 255),
			xalign = TEXT_ALIGN_LEFT,
			yalign = TEXT_ALIGN_TOP,
		}
	end

	local closeBtn = vgui.Create("TFButton", panel)
	closeBtn:SetSize(100 * Scale, 25 * Scale)
	closeBtn:SetPos(panel:GetWide() - 120 * Scale, 15 * Scale)
	closeBtn.labelText = "CLOSE"
	closeBtn.font = "HudFontSmallBold"
	function closeBtn:DoClick()
		if IsValid(panel) then panel:Remove() end
	end

	local scroll = vgui.Create("DScrollPanel", panel)
	scroll:SetPos(18 * Scale, 78 * Scale)
	scroll:SetSize(panel:GetWide() - 36 * Scale, panel:GetTall() - 96 * Scale)

	local itemicons = vgui.Create("DIconLayout", scroll)
	itemicons:Dock(FILL)
	itemicons:SetSpaceX(6)
	itemicons:SetSpaceY(6)

	local allItems = {}
	for _, item in pairs(tf_items.Items or {}) do
		if istable(item) and isnumber(item.id) and isstring(item.item_slot) then
			allItems[#allItems + 1] = item
		end
	end
	table.sort(allItems, function(a, b) return (a.id or 0) < (b.id or 0) end)

	for _, item in ipairs(allItems) do
		local model = vgui.Create("ItemModelPanel", itemicons)
		model:SetSize(140 * Scale, 75 * Scale)
		itemicons:Add(model)

		model.activeImage = loadout_rect_mouseover
		model.inactiveImage = loadout_rect
		model.model_xpos = 0
		model.model_ypos = 5
		model.model_tall = 55
		model.text_xpos = -5
		model.text_wide = 150
		model.text_ypos = 60
		model.itemImage_low = nil
		model.text = getDecoratedDisplayName(item, item.SteamProperties)
		model.centerytext = true

		local quality = 0
		if item.item_quality then
			quality = string.upper(string.sub(item.item_quality, 1, 1)) .. string.sub(item.item_quality, 2)
		end
		model:SetQuality(quality)

		local resolvedImage = getResolvedItemImagePath(item, item.SteamProperties)
		local invMat
		if isstring(resolvedImage) and resolvedImage ~= "" then
			invMat = Material(resolvedImage)
		end
		if (not invMat) or invMat:IsError() then
			model.FallbackModel = item.model_player
			model.itemImage = surface.GetTextureID("backpack/weapons/c_models/c_bat")
		else
			model.itemImage = surface.GetTextureID(resolvedImage)
		end
		applyDecoratedPanelVisual(model, item, item.SteamProperties)

		if istable(item.attributes) then
			model.attributes = item.attributes
		end

		local canEquip = classCanUseItem(item, oldclass) and canEquipFn(item)
		model.disabled = not canEquip
		if not canEquip then
			model:SetAlpha(95)
		end

		model.DoClick = function()
			if not canEquip then return end
			onEquipFn(item)
			if IsValid(panel) then panel:Remove() end
		end
	end
end

local function getTargetWeaponSlot(type, className)
	local swapped = className == "spy"
	if type == 1 then
		return swapped and "secondary" or "primary"
	elseif type == 2 then
		return swapped and "primary" or "secondary"
	elseif type == 3 then
		return "melee"
	end
	return nil
end

local function mapItemToLoadoutSlot(item, className)
	if not istable(item) then return nil end

	if isTauntItem(item) then
		return tauntSlotToForcedSlot(1)
	end

	if isActionSlotItem(item) then
		return 7
	end

	if className == "engineer" and item.item_slot == "pda" then
		return 8
	end
	if className == "spy" and item.item_slot == "pda2" then
		return 8
	end

	if isWearableLoadoutItem(item) then
		return 4
	end

	if item.item_slot == "melee" then
		return 3
	end

	if item.item_slot == "primary" then
		return 1
	elseif item.item_slot == "secondary" then
		return 2
	end

	return nil
end

function TF_OpenClassBackpack(className, classIndex)
	local cls = className or "scout"
	local classId = classIndex or GetConVar("tf_hud_loadout_class"):GetInt()
	TF_OpenStandaloneBackpack(cls, classId)
end

local TFStandaloneBackpackPanel

local classIndexToName = {
	[1] = "scout",
	[2] = "soldier",
	[3] = "pyro",
	[4] = "demoman",
	[5] = "heavy",
	[6] = "engineer",
	[7] = "medic",
	[8] = "sniper",
	[9] = "spy",
}

local function getSteamInventorySet()
	local raw = file.Read("tf_loadout.json", "DATA")
	if not isstring(raw) or raw == "" then return nil, "missing_file" end
	raw = string.gsub(raw, "^\239\187\191", "")
	raw = string.Trim(raw)

	local parsed = util.JSONToTable(raw)
	if not istable(parsed) then
		local wrapped = string.match(raw, "(%b{})")
		if isstring(wrapped) and wrapped ~= "" then
			parsed = util.JSONToTable(wrapped)
		end
	end
	if not istable(parsed) then
		return nil, "invalid_json"
	end

	local container = parsed.result
	if not istable(container) then
		container = parsed.response
	end
	if not istable(container) then
		container = parsed
	end

	local items = container and container.items
	if not istable(items) then
		return nil, "missing_items", tonumber(container and container.status)
	end

	local set = {}
	for _, invItem in pairs(items) do
		if istable(invItem) then
			local defindex = tonumber(invItem.defindex or invItem.itemdefid or invItem.item_def_index)
			if defindex then
				set[defindex] = true
			end
		end
	end

	return set, nil, tonumber(container and container.status)
end

local QualityNameByID = nil

local function getQualityNameFromID(id)
	local n = tonumber(id)
	if not n then return nil end

	if not istable(QualityNameByID) then
		QualityNameByID = {}
		for name, value in pairs(tf_items and tf_items.Qualities or {}) do
			if isstring(name) and tonumber(value) then
				QualityNameByID[tonumber(value)] = name
			end
		end
	end

	return QualityNameByID[n]
end

local function buildSteamItemPropertiesForMenu(itemData)
	if not istable(itemData) then return nil end

	local props = {}
	local defindex = tonumber(itemData.defindex)
	if defindex then props.defindex = defindex end

	local quality = tonumber(itemData.quality)
	if quality then props.quality = quality end

	local level = tonumber(itemData.level)
	if level then props.level = level end

	if isstring(itemData.custom_name) and itemData.custom_name ~= "" then
		props.custom_name = itemData.custom_name
	end
	if isstring(itemData.custom_desc) and itemData.custom_desc ~= "" then
		props.custom_desc = itemData.custom_desc
	end

	for _, key in ipairs({"pickup_method", "acquisition_method", "item_origin", "origin"}) do
		local value = itemData[key]
		if value ~= nil then
			props[key] = value
		end
	end

	if istable(itemData.attributes) then
		local attrs = {}
		for _, att in ipairs(itemData.attributes) do
			if istable(att) then
				local id = tonumber(att.defindex or att.attribute_class or att.id or att[1])
				local attrDef = id and tf_items and tf_items.AttributesByID and tf_items.AttributesByID[id] or nil
				local rawFloat = tonumber(att.float_value)
				local rawValue = tonumber(att.value)
				local value = nil

				if rawValue == nil and att.value == nil then
					rawValue = tonumber(att[2])
				end
				if rawFloat == nil and att.float_value == nil then
					rawFloat = tonumber(att[2])
				end

				if attrDef and isTintAttributeClass(attrDef.attribute_class) then
					value = normalizeItemTintValue(rawValue or rawFloat)
				elseif attrDef and tonumber(attrDef.stored_as_integer) == 1 then
					value = rawValue
				elseif attrDef and attrDef.attribute_type == "string" then
					value = att.value ~= nil and att.value or att[2]
				elseif rawFloat ~= nil and (rawFloat == 0 or math.abs(rawFloat) > 0.000001) then
					value = rawFloat
				else
					value = rawValue or rawFloat
				end

				if id and value ~= nil then
					attrs[#attrs + 1] = { id, value }
				end
			end
		end

		if #attrs > 0 then
			props.attributes = attrs
		end
	end

	if next(props) == nil then return nil end
	return props
end

local function getSteamInventoryInstances()
	local raw = file.Read("tf_loadout.json", "DATA")
	if not isstring(raw) or raw == "" then return nil, "missing_file" end
	raw = string.gsub(raw, "^\239\187\191", "")
	raw = string.Trim(raw)

	local parsed = util.JSONToTable(raw)
	if not istable(parsed) then
		local wrapped = string.match(raw, "(%b{})")
		if isstring(wrapped) and wrapped ~= "" then
			parsed = util.JSONToTable(wrapped)
		end
	end
	if not istable(parsed) then
		return nil, "invalid_json"
	end

	local container = parsed.result
	if not istable(container) then
		container = parsed.response
	end
	if not istable(container) then
		container = parsed
	end

	local items = container and container.items
	if not istable(items) then
		return nil, "missing_items", tonumber(container and container.status)
	end

	local instances = {}
	for _, invItem in ipairs(items) do
		if istable(invItem) then
			local defindex = tonumber(invItem.defindex or invItem.itemdefid or invItem.item_def_index)
			local baseItem = defindex and tf_items and tf_items.ItemsByID and tf_items.ItemsByID[defindex] or nil
			if istable(baseItem) then
				local item = table.Copy(baseItem)
				item.InventoryInstanceID = tonumber(invItem.id or invItem.original_id)
				item.SchemaID = tonumber(baseItem.id) or defindex
				item.SteamItemData = invItem
				item.SteamProperties = buildSteamItemPropertiesForMenu(invItem)

				local qualityName = getQualityNameFromID(invItem.quality)
				if isstring(qualityName) and qualityName ~= "" then
					item.item_quality = qualityName
				end

				if item.SteamProperties and isstring(item.SteamProperties.custom_name) and item.SteamProperties.custom_name ~= "" then
					item.item_name = item.SteamProperties.custom_name
				end
				if item.SteamProperties and isstring(item.SteamProperties.custom_desc) and item.SteamProperties.custom_desc ~= "" then
					item.item_description = item.SteamProperties.custom_desc
				end

				instances[#instances + 1] = item
			end
		end
	end

	return instances, nil, tonumber(container and container.status)
end

local function syncClientLoadoutProperties(className, slot, properties)
	if not isstring(className) then return end
	local slotIndex = tonumber(slot)
	if not slotIndex then return end

	TFClientLoadoutProperties = TFClientLoadoutProperties or {}
	TFClientLoadoutProperties[className] = TFClientLoadoutProperties[className] or {}
	TFClientLoadoutProperties[className][slotIndex] = properties

	net.Start("TF_UpdateLoadoutProperties")
		net.WriteTable(TFClientLoadoutProperties)
	net.SendToServer()
end

local function getWearableTargetSlot(className, itemId)
	local convar = GetConVar("loadout_" .. className)
	if not convar then return 4 end

	local split = string.Split(convar:GetString(), ",")
	for i = 4, 6 do
		if tonumber(split[i]) == itemId then
			return i
		end
	end
	for i = 4, 6 do
		if tonumber(split[i]) == -1 then
			return i
		end
	end
	return 4
end

local function collectEquipRegions(item)
	if not istable(item) then return {} end

	local regions = {}
	local function addRegion(regionValue)
		if not isstring(regionValue) then return end
		local trimmed = string.Trim(string.lower(regionValue))
		if trimmed == "" then return end
		for token in string.gmatch(trimmed, "[^,%s;|]+") do
			if token ~= "" then
				regions[token] = true
			end
		end
	end
	local function walkRegions(value)
		if isstring(value) then
			addRegion(value)
		elseif istable(value) then
			for k, v in pairs(value) do
				if isstring(k) then
					addRegion(k)
				end
				walkRegions(v)
			end
		end
	end

	walkRegions(item.equip_region)
	walkRegions(item.equip_regions)

	return regions
end

local function buildItemsById()
	local byId = {}
	for _, item in pairs(tf_items.Items or {}) do
		if istable(item) then
			local id = tonumber(item.id)
			if id and not byId[id] then
				byId[id] = item
			end
		end
	end
	return byId
end

local function hasCosmeticEquipRegionConflict(item, equippedLoadout, itemsById, forcedSlot)
	if not istable(item) or not istable(equippedLoadout) then return false end
	if not (isWearableLoadoutItem(item) and (item.item_slot == "head" or item.item_slot == "misc")) then
		return false
	end

	local candidateRegions = collectEquipRegions(item)
	if next(candidateRegions) == nil then
		return false
	end

	for slot = 4, 6 do
		if slot ~= forcedSlot then
			local equippedId = tonumber(equippedLoadout[slot])
			if equippedId and equippedId > 0 then
				local equippedItem = itemsById[equippedId]
				if istable(equippedItem) then
					local equippedRegions = collectEquipRegions(equippedItem)
					for regionName in pairs(candidateRegions) do
						if equippedRegions[regionName] then
							return true
						end
					end
				end
			end
		end
	end

	return false
end

function TF_OpenStandaloneBackpack(initialClassName, initialClassIndex, forcedLoadoutSlot)
	if IsValid(TFStandaloneBackpackPanel) then
		TFStandaloneBackpackPanel:Remove()
	end

	local Scale = ScrH() / 480
	local loadout_rect = surface.GetTextureID("vgui/loadout_rect")
	local loadout_rect_mouseover = surface.GetTextureID("vgui/loadout_rect_mouseover")
	local activeClass = initialClassName or classIndexToName[initialClassIndex or 1] or "scout"
	local steamInstances
	local steamErr
	local steamStatus
	local currentPage = 1
	local pageSize = 50
	local columns = 10
	local rows = 5
	local itemsById = buildItemsById()
	local showStockItems = false
	local showQualityBorders = true
	local sortMode = "default"
	local backpackResTree = TF2Res and TF2Res.Load and TF2Res.Load("resource/ui/econ/backpackpanel.res")
	local backpackResRoot = backpackResTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(backpackResTree, "backpack_panel")
	local backpackPageButtonsNode = backpackResRoot and TF2Res.FindByKey and TF2Res.FindByKey(backpackResRoot, "pagebuttons_kv")
	local backpackPageButtonNode = backpackPageButtonsNode and TF2Res.FindByFieldName and TF2Res.FindByFieldName(backpackPageButtonsNode, "Button")
	local backpackModelPanelsNode = backpackResRoot and TF2Res.FindByKey and TF2Res.FindByKey(backpackResRoot, "modelpanels_kv")
	local backpackQualityNode = backpackResTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(backpackResTree, "ShowRarityComboBox")
	local backpackStockNode = backpackResTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(backpackResTree, "ShowBaseItemsCheckbox")
	local backpackNameLabelNode = backpackResTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(backpackResTree, "NameFilterLabel")
	local backpackNameEntryNode = backpackResTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(backpackResTree, "NameFilterTextEntry")
	local backpackSortNode = backpackResTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(backpackResTree, "SortByComboBox")

	local function getResString(node, key, defaultValue)
		if TF2Res and TF2Res.GetString then
			return TF2Res.GetString(node, key, defaultValue)
		end
		return defaultValue
	end

	local function getResLabel(rawValue, fallbackValue)
		if not isstring(rawValue) or rawValue == "" then
			return fallbackValue
		end
		if string.StartWith(rawValue, "#") then
			local key = string.sub(rawValue, 2)
			local localized = language and language.GetPhrase and language.GetPhrase(key)
			if isstring(localized) and localized ~= "" and localized ~= key then
				return string.upper(localized)
			end
			local tfLocalized = tf_lang and tf_lang.GetRaw and tf_lang.GetRaw(rawValue)
			if isstring(tfLocalized) and tfLocalized ~= "" then
				return string.upper(tfLocalized)
			end
			return fallbackValue
		end
		return string.upper(rawValue)
	end

	local function parseResCoord(rawValue, baseLength)
		if isnumber(rawValue) then
			return rawValue
		end
		if not isstring(rawValue) then
			return nil
		end
		local raw = string.Trim(rawValue)
		local numeric = tonumber(raw)
		if numeric then
			return numeric
		end
		if raw == "c" then
			return baseLength * 0.5
		end
		local centerOffset = string.match(raw, "^c([%+%-]?%d+%.?%d*)$")
		if centerOffset then
			return (baseLength * 0.5) + tonumber(centerOffset)
		end
		local rightOffset = string.match(raw, "^r([%+%-]?%d+%.?%d*)$")
		if rightOffset then
			return baseLength + tonumber(rightOffset)
		end
		return nil
	end

	local function parseResLength(rawValue, baseLength)
		if isnumber(rawValue) then
			return rawValue
		end
		if not isstring(rawValue) then
			return nil
		end
		local raw = string.Trim(rawValue)
		local numeric = tonumber(raw)
		if numeric then
			return numeric
		end
		local fillOffset = string.match(raw, "^f([%+%-]?%d+%.?%d*)$")
		if fillOffset then
			return baseLength + tonumber(fillOffset)
		end
		return nil
	end

	local function resToFrame(rawValue, baseLength, frameLength, fallbackValue)
		local basePos = parseResCoord(rawValue, baseLength)
		if not basePos then
			return fallbackValue
		end
		return math.floor((basePos / baseLength) * frameLength)
	end

	local function resLengthToScreen(rawValue, baseLength, screenLength, fallbackValue)
		local baseLen = parseResLength(rawValue, baseLength)
		if not baseLen then
			return fallbackValue
		end
		return math.max(1, math.floor((baseLen / baseLength) * screenLength))
	end

	local backpackLayout = {
		pageButtonsPerRow = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackResRoot, "page_button_per_row", 20) or 20,
		pageButtonGapX = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackResRoot, "page_button_x_delta", 5) or 5,
		pageButtonGapY = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackResRoot, "page_button_y_delta", 5) or 5,
		pageButtonY = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackResRoot, "page_button_y", 288) or 288,
		pageButtonHeight = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackResRoot, "page_button_height", 13) or 13,
		pageButtonWidth = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackPageButtonNode, "wide", 25) or 25,
		itemDeltaX = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackResRoot, "item_backpack_xdelta", 4) or 4,
		itemDeltaY = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackResRoot, "item_backpack_ydelta", 3) or 3,
		tileWide = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackModelPanelsNode, "wide", 54) or 54,
		tileTall = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackModelPanelsNode, "tall", 42) or 42,
		modelX = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackModelPanelsNode, "model_xpos", 0) or 0,
		modelY = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackModelPanelsNode, "model_ypos", 1) or 1,
		modelTall = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackModelPanelsNode, "model_tall", 20) or 20,
		textX = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackModelPanelsNode, "text_xpos", -5) or -5,
		textY = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackModelPanelsNode, "text_ypos", 30) or 30,
		textWide = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackModelPanelsNode, "text_wide", 62) or 62,
	}

	local sw, sh = ScrW(), ScrH()
	local frameX = resToFrame(getResString(backpackResRoot, "xpos", "0"), 640, sw, math.max(18, math.floor(sw * 0.015)))
	local frameY = resToFrame(getResString(backpackResRoot, "ypos", "0"), 480, sh, math.max(48, math.floor(sh * 0.105)))
	local frameW = resLengthToScreen(getResString(backpackResRoot, "wide", "f0"), 640, sw, sw - (frameX * 2))
	local frameH = resLengthToScreen(getResString(backpackResRoot, "tall", ""), 480, sh, sh - frameY - math.max(18, math.floor(sh * 0.06)))
	local gridPadding = math.max(6, math.floor(4 * Scale))
	local gridSpacingX = math.max(1, math.floor(backpackLayout.itemDeltaX * Scale))
	local gridSpacingY = math.max(1, math.floor(backpackLayout.itemDeltaY * Scale))
	local itemOffsetX = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackResRoot, "item_backpack_offcenter_x", -288) or -288
	local itemStartX = 0
	local itemStartY = 0
	local tileW = 0
	local tileH = 0
	local gridInnerW = 0
	local gridInnerH = 0

	local panel = vgui.Create("EditablePanel")
	panel:SetSize(sw, sh)
	panel:SetPos(0, 0)
	panel:MakePopup()
	panel:SetKeyboardInputEnabled(true)
	panel:SetMouseInputEnabled(true)
	panel.ForcedLoadoutSlot = tonumber(forcedLoadoutSlot)
	panel.LoadoutMode = panel.ForcedLoadoutSlot ~= nil
	TFStandaloneBackpackPanel = panel

	local classPanelsToRestore = {}
	local function hideClassPanelFrom(panelRef)
		if IsValid(panelRef) and IsValid(panelRef.ClassPanel) then
			classPanelsToRestore[#classPanelsToRestore + 1] = {
				panel = panelRef.ClassPanel,
				visible = panelRef.ClassPanel:IsVisible(),
			}
			panelRef.ClassPanel:SetVisible(false)
		end
	end
	hideClassPanelFrom(CharInfoLoadoutSubPanel)
	hideClassPanelFrom(FullLoadoutPanel)

	function panel:OnKeyCodePressed(key)
		if key == KEY_ESCAPE and IsValid(self) then
			self:Remove()
		end
	end

	function panel:Paint(w, h)
		surface.SetDrawColor(14, 12, 11, 232)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(39, 34, 31, 248)
		surface.DrawRect(frameX, frameY, frameW, frameH)

		surface.SetDrawColor(124, 112, 96, 255)
		surface.DrawOutlinedRect(frameX, frameY, frameW, frameH, 1)
		draw.SimpleText(">>", "HudFontSmallBold", frameX + 76, frameY + 36, Color(200, 80, 60, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("BACKPACK", "HudFontMediumBold", frameX + 112, frameY + 36, Color(235, 226, 202, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local searchLabel = vgui.Create("DLabel", panel)
	searchLabel:SetText(getResLabel(getResString(backpackNameLabelNode, "labelText", "#Store_NameFilterLabel"), "SEARCH:"))
	searchLabel:SetTextColor(Color(205, 193, 167, 255))
	searchLabel:SetFont("HudFontSmallBold")

	local searchEntry = vgui.Create("DTextEntry", panel)
	searchEntry:SetFont("HudFontSmallBold")
	searchEntry:SetUpdateOnType(true)
	searchEntry:SetTextColor(Color(34, 31, 26, 255))
	searchEntry:SetDrawBackground(false)
	searchEntry.Paint = function(self, w, h)
		draw.RoundedBox(4, 0, 0, w, h, Color(228, 219, 191, 255))
		surface.SetDrawColor(85, 75, 63, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		self:DrawTextEntryText(Color(37, 34, 28, 255), Color(37, 34, 28, 255), Color(37, 34, 28, 255))
	end

	local stockCheckbox = vgui.Create("DCheckBoxLabel", panel)
	stockCheckbox:SetText(getResLabel(getResString(backpackStockNode, "labelText", "#ShowBaseItemsCheckBox"), "SHOW STOCK ITEMS"))
	stockCheckbox:SetFont("HudFontSmallBold")
	stockCheckbox:SetTextColor(Color(224, 214, 186, 255))
	stockCheckbox:SetValue(0)
	stockCheckbox:SizeToContents()
	if IsValid(stockCheckbox.Button) then
		stockCheckbox.Button:SetSize(26, 26)
		stockCheckbox.Button.Paint = function(btn, w, h)
			draw.RoundedBox(0, 0, 0, w, h, Color(26, 23, 20, 255))
			surface.SetDrawColor(232, 222, 196, 255)
			surface.DrawOutlinedRect(0, 0, w, h, 2)
			if stockCheckbox:GetChecked() then
				surface.SetDrawColor(238, 228, 203, 255)
				surface.DrawRect(6, 6, w - 12, h - 12)
			end
		end
	end
	stockCheckbox.OnChange = function(_, val)
		showStockItems = val == true
		currentPage = 1
		panel:BuildItems()
	end

	local function styleCombo(combo)
		combo:SetTextColor(Color(233, 223, 198, 255))
		combo:SetFont("HudFontSmallBold")
		combo.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, Color(45, 40, 35, 255))
			surface.SetDrawColor(208, 196, 168, 255)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(self:GetValue() or "", "HudFontSmallBold", 8, h * 0.5, Color(234, 224, 201, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			local cx, cy = w - 18, h * 0.5 + 1
			draw.NoTexture()
			surface.SetDrawColor(232, 222, 195, 255)
			surface.DrawPoly({
				{x = cx - 7, y = cy - 4},
				{x = cx + 7, y = cy - 4},
				{x = cx, y = cy + 5},
			})
		end
		if IsValid(combo.DropButton) then
			combo.DropButton:SetText("")
			combo.DropButton.Paint = function() end
		end
	end

	local qualityDropdown = vgui.Create("DComboBox", panel)
	styleCombo(qualityDropdown)
	qualityDropdown:AddChoice(getResLabel("#TF_Backpack_ShowNoBorders", "NO ITEM BORDERS"), "none")
	qualityDropdown:AddChoice(getResLabel("#TF_Backpack_ShowQualityBorders", "SHOW QUALITY COLOR BORDERS"), "quality")
	qualityDropdown:AddChoice(getResLabel("#TF_Backpack_ShowMarketableBorders", "SHOW MARKETABLE BORDERS ONLY"), "marketable")
	qualityDropdown:SetValue(getResLabel("#TF_Backpack_ShowQualityBorders", "SHOW QUALITY COLOR BORDERS"))
	qualityDropdown.OnSelect = function(_, _, _, data)
		showQualityBorders = data ~= "none"
		panel:BuildItems()
	end

	local sortDropdown = vgui.Create("DComboBox", panel)
	styleCombo(sortDropdown)
	sortDropdown:AddChoice(getResLabel("#Backpack_SortBy_Header", "SORT BACKPACK"), "default")
	sortDropdown:AddChoice(getResLabel("#Backpack_SortBy_Rarity", "SORT BY QUALITY"), "quality")
	sortDropdown:AddChoice(getResLabel("#Backpack_SortBy_Type", "SORT BY TYPE"), "type")
	sortDropdown:AddChoice(getResLabel("#Backpack_SortBy_Class", "SORT BY CLASS"), "class")
	sortDropdown:AddChoice(getResLabel("#Backpack_SortBy_Slot", "SORT BY LOADOUT SLOT"), "slot")
	sortDropdown:AddChoice(getResLabel("#Backpack_SortBy_Date", "SORT BY DATE"), "date")
	sortDropdown:SetValue(getResLabel("#Backpack_SortBy_Header", "SORT BACKPACK"))
	sortDropdown.OnSelect = function(_, _, _, data)
		sortMode = isstring(data) and data or "default"
		currentPage = 1
		panel:BuildItems()
	end

	local infoLabel = vgui.Create("DLabel", panel)
	infoLabel:SetTextColor(Color(190, 178, 155, 255))
	infoLabel:SetFont("HudFontSmall")

	local backpackAttributePanel = vgui.Create("ItemAttributePanel")
	backpackAttributePanel:SetParent(panel)
	backpackAttributePanel:SetSize(320 * Scale, 340 * Scale)
	backpackAttributePanel.text_ypos = 24
	backpackAttributePanel:SetMouseInputEnabled(false)

	local gridPanel = vgui.Create("EditablePanel", panel)
	function gridPanel:Paint(w, h)
		surface.SetDrawColor(36, 31, 28, 255)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(112, 99, 85, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	local itemLayer = vgui.Create("EditablePanel", panel)
	itemLayer:SetMouseInputEnabled(true)
	function itemLayer:Paint() end

	local pageBar = vgui.Create("EditablePanel", panel)
	function pageBar:Paint() end

	local backBtn = vgui.Create("TFButton", panel)
	backBtn:SetSize(200, 36)
	backBtn.labelText = "<< BACK"
	backBtn.font = "HudFontSmallBold"
	function backBtn:DoClick()
		if IsValid(panel) then panel:Remove() end
	end

	local closeBtn = vgui.Create("TFButton", panel)
	closeBtn:SetSize(170, 36)
	closeBtn.labelText = "CLOSE"
	closeBtn.font = "HudFontSmallBold"
	function closeBtn:DoClick()
		if IsValid(panel) then panel:Remove() end
	end

	local function layoutBackpackUI()
		local searchLabelX = frameX + resToFrame(getResString(backpackNameLabelNode, "xpos", "c+137"), 640, frameW, math.floor(frameW * 0.74))
		local searchLabelY = frameY + resToFrame(getResString(backpackNameLabelNode, "ypos", "0"), 480, frameH, 0)
		local searchLabelW = math.max(72, resToFrame(getResString(backpackNameLabelNode, "wide", "90"), 640, frameW, 90))
		local searchLabelH = math.max(18, resToFrame(getResString(backpackNameLabelNode, "tall", "20"), 480, frameH, 20))
		searchLabel:SetPos(searchLabelX, searchLabelY)
		searchLabel:SetSize(searchLabelW, searchLabelH)

		local searchEntryX = frameX + resToFrame(getResString(backpackNameEntryNode, "xpos", "c+137"), 640, frameW, searchLabelX - frameX)
		local searchEntryY = frameY + resToFrame(getResString(backpackNameEntryNode, "ypos", "15"), 480, frameH, 15)
		local searchEntryW = math.max(84, resToFrame(getResString(backpackNameEntryNode, "wide", "90"), 640, frameW, 120))
		local searchEntryH = math.max(18, resToFrame(getResString(backpackNameEntryNode, "tall", "19"), 480, frameH, 24))
		searchEntry:SetPos(searchEntryX, searchEntryY)
		searchEntry:SetSize(searchEntryW, searchEntryH)

		local stockX = frameX + resToFrame(getResString(backpackStockNode, "xpos", "c-70"), 640, frameW, math.floor(frameW * 0.42))
		local stockY = frameY + resToFrame(getResString(backpackStockNode, "ypos", "15"), 480, frameH, 15)
		stockCheckbox:SetPos(stockX, stockY)
		stockCheckbox:SizeToContents()

		local qualityX = frameX + resToFrame(getResString(backpackQualityNode, "xpos", "c-85"), 640, frameW, math.floor(frameW * 0.35))
		local qualityY = frameY + resToFrame(getResString(backpackQualityNode, "ypos", "37"), 480, frameH, 56)
		local qualityW = math.max(180, resToFrame(getResString(backpackQualityNode, "wide", "205"), 640, frameW, 260))
		local qualityH = math.max(20, resToFrame(getResString(backpackQualityNode, "tall", "15"), 480, frameH, 24))
		qualityDropdown:SetPos(qualityX, qualityY)
		qualityDropdown:SetSize(qualityW, qualityH)

		local sortX = frameX + resToFrame(getResString(backpackSortNode, "xpos", "c+137"), 640, frameW, searchEntryX - frameX)
		local sortY = frameY + resToFrame(getResString(backpackSortNode, "ypos", "37"), 480, frameH, 56)
		local sortW = math.max(140, resToFrame(getResString(backpackSortNode, "wide", "150"), 640, frameW, 180))
		local sortH = math.max(20, resToFrame(getResString(backpackSortNode, "tall", "15"), 480, frameH, 24))
		sortDropdown:SetPos(sortX, sortY)
		sortDropdown:SetSize(sortW, sortH)

		tileW = math.max(42, resToFrame(tostring(backpackLayout.tileWide or 54), 640, frameW, 54))
		tileH = math.max(34, resToFrame(tostring(backpackLayout.tileTall or 42), 480, frameH, 42))
		gridInnerW = (columns * tileW) + ((columns - 1) * gridSpacingX)
		gridInnerH = (rows * tileH) + ((rows - 1) * gridSpacingY)
		itemStartX = frameX + math.floor((frameW * 0.5) + ((itemOffsetX / 640) * frameW))
		itemStartY = frameY + resToFrame(tostring(TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(backpackResRoot, "item_ypos", 60) or 60), 480, frameH, 60)

		infoLabel:SetPos(frameX + 20, itemStartY - math.max(26, math.floor(18 * Scale)))
		infoLabel:SetSize(frameW - 40, 24)

		gridPanel:SetPos(itemStartX - gridPadding, itemStartY - gridPadding)
		gridPanel:SetSize(gridInnerW + (gridPadding * 2), gridInnerH + (gridPadding * 2))
		itemLayer:SetPos(itemStartX, itemStartY)
		itemLayer:SetSize(gridInnerW, gridInnerH)

		local buttonY = frameY + frameH - backBtn:GetTall() - math.max(18, math.floor(14 * Scale))
		backBtn:SetPos(frameX + 16, buttonY)
		closeBtn:SetPos(frameX + frameW - closeBtn:GetWide() - 16, buttonY)

		local resPageY = frameY + resToFrame(tostring(backpackLayout.pageButtonY), 480, frameH, 288)
		local pageBarW = math.max(gridInnerW, math.floor((math.abs(itemOffsetX) * 2 / 640) * frameW))
		pageBar:SetPos(itemStartX, resPageY)
		pageBar:SetSize(pageBarW, math.max(16, frameY + frameH - resPageY - math.max(52, math.floor(42 * Scale))))
	end

	layoutBackpackUI()
	panel.OnSizeChanged = function()
		layoutBackpackUI()
	end

	local function getItemDisplayName(item)
		return getTooltipDisplayName(item)
	end

	local function refreshLoadoutViewNow()
		local mappedIndex = (istable(loadoutClassToIndex) and loadoutClassToIndex[activeClass]) or nil
		local classIndex = initialClassIndex or mappedIndex or GetConVar("tf_hud_loadout_class"):GetInt() or 1
		timer.Simple(0, function()
			if IsValid(CharInfoLoadoutSubPanel) and CharInfoLoadoutSubPanel.SelectClassLoadout2 then
				CharInfoLoadoutSubPanel:SelectClassLoadout2(classIndex)
			elseif IsValid(CharInfoLoadoutSubPanel) and CharInfoLoadoutSubPanel.PerformLayout then
				CharInfoLoadoutSubPanel:PerformLayout()
			end
		end)
	end

	local function getInspectModelPath(item, className)
		if not istable(item) then return nil end

		local perClass = item.model_player_per_class
		if istable(perClass) then
			local resolved = perClass[className] or perClass[(className == "demoman" and "demo" or className)] or perClass.basename
			if isstring(resolved) and resolved ~= "" then
				resolved = string.Replace(resolved, "%s", className)
				if className == "demoman" and not file.Exists(resolved, "GAME") then
					local demoResolved = string.Replace(resolved, "demoman", "demo")
					if file.Exists(demoResolved, "GAME") then
						resolved = demoResolved
					end
				end
				return resolved
			end
		elseif isstring(perClass) and perClass ~= "" then
			local resolved = string.Replace(perClass, "%s", className)
			if className == "demoman" and not file.Exists(resolved, "GAME") then
				local demoResolved = string.Replace(perClass, "%s", "demo")
				if file.Exists(demoResolved, "GAME") then
					resolved = demoResolved
				end
			end
			return resolved
		end

		if isstring(item.model_player) and item.model_player ~= "" then
			return string.Replace(item.model_player, "%s", className)
		end
		if isstring(item.model_world) and item.model_world ~= "" then
			return item.model_world
		end

		return nil
	end

	local function openBackpackInspect(item, className)
		local mdl = getInspectModelPath(item, className)
		if not isstring(mdl) or mdl == "" or not util.IsValidModel(mdl) then
			chat.AddText(Color(220, 120, 80), "[TF2-Gamemode] Inspect preview unavailable for this item.")
			return
		end

		local frame = vgui.Create("DFrame")
		frame:SetSize(math.floor(ScrW() * 0.46), math.floor(ScrH() * 0.62))
		frame:Center()
		frame:SetTitle("Inspect: " .. getItemDisplayName(item))
		frame:ShowCloseButton(true)
		frame:SetDraggable(true)
		frame:MakePopup()

		local modelPanel = vgui.Create("DModelPanel", frame)
		modelPanel:Dock(FILL)
		modelPanel:SetModel(mdl)
		modelPanel:SetFOV(42)
		modelPanel:SetCamPos(Vector(82, 18, 44))
		modelPanel:SetLookAt(Vector(0, 0, 40))
		modelPanel.LayoutEntity = function(self, ent)
			if IsValid(ent) then
				ent:SetAngles(Angle(0, RealTime() * 18 % 360, 0))
			end
		end
		local inspectMaterial = tf_item and tf_item.ResolveMaterialOverrideForItemData and tf_item.ResolveMaterialOverrideForItemData(item, item.SteamProperties, LocalPlayer()) or nil
		if isstring(inspectMaterial) and inspectMaterial ~= "" and IsValid(modelPanel.Entity) then
			modelPanel.Entity:SetMaterial(inspectMaterial)
		end
	end

	local slotOrder = {
		primary = 1,
		secondary = 2,
		melee = 3,
		head = 4,
		misc = 4,
		action = 5,
		taunt = 6,
	}

	local function sortSlotName(item)
		if isTauntItem(item) then
			return "taunt"
		end
		if isActionSlotItem(item) then
			return "action"
		end
		return item and item.item_slot or nil
	end

	local qualitySortRank = {
		normal = 1,
		unique = 2,
		paintkitweapon = 2,
		vintage = 3,
		genuine = 4,
		strange = 5,
		haunted = 6,
		collectors = 7,
		unusual = 8,
	}

	local function isStockItem(item)
		if not istable(item) then return false end
		local q = string.lower(tostring(item.item_quality or ""))
		if q == "normal" then return true end
		return item.baseitem == true or item.default == true
	end

	local function qualityName(item)
		local q = string.lower(tostring(item and item.item_quality or ""))
		if q == "" then
			q = "unique"
		end
		return q
	end

	local function qualityRank(item)
		return qualitySortRank[qualityName(item)] or 0
	end

	local function getQualityDisplayName(item)
		local q = qualityName(item)
		return string.upper(string.sub(q, 1, 1)) .. string.sub(q, 2)
	end

	local function getQualityBorderColor(item)
		if not showQualityBorders then
			return Color(141, 130, 112, 255)
		end

		local function tryQualityColor(suffix)
			if not Colors or not isstring(suffix) or suffix == "" then return nil end
			local exact = "QualityColor" .. suffix
			if Colors[exact] then return Colors[exact] end
			local lower = "QualityColor" .. string.lower(suffix)
			if Colors[lower] then return Colors[lower] end
			local upperFirst = "QualityColor" .. string.upper(string.sub(suffix, 1, 1)) .. string.sub(suffix, 2)
			if Colors[upperFirst] then return Colors[upperFirst] end
			return nil
		end

		local qualityColor = tryQualityColor(getQualityDisplayName(item))
		if qualityColor then
			return qualityColor
		end

		local rarity = string.lower(tostring(item and item.item_rarity or ""))
		local rarityToQuality = {
			common = "rarity1",
			uncommon = "rarity2",
			rare = "rarity3",
			mythical = "rarity4",
			legendary = "rarity4",
			ancient = "rarity4",
		}
		local rarityQuality = rarityToQuality[rarity]
		if rarityQuality then
			local rarityColor = tryQualityColor(rarityQuality)
			if rarityColor then
				return rarityColor
			end
		end
		return Color(238, 210, 68, 255)
	end

	searchEntry.OnValueChange = function()
		currentPage = 1
		panel:BuildItems()
	end

	if TFDebugBridge and TFDebugBridge.Emit then
		TFDebugBridge.Emit("backpack_open", {
			class = activeClass,
			slot = panel.ForcedLoadoutSlot,
			page = currentPage,
			query = searchEntry:GetValue() or "",
		}, false)
	end

	function panel:BuildItems()
		steamInstances, steamErr, steamStatus = getSteamInventoryInstances()

		for _, child in ipairs(itemLayer:GetChildren()) do
			child:Remove()
		end
		for _, child in ipairs(pageBar:GetChildren()) do
			child:Remove()
		end

		local rawCandidates = {}
		for _, item in ipairs(steamInstances or {}) do
			if istable(item) then
				if item.item_slot == "primary" or item.item_slot == "secondary" or item.item_slot == "melee" or item.item_slot == "pda" or item.item_slot == "pda2" or item.item_slot == "head" or item.item_slot == "misc" or item.item_slot == "action" or item.item_slot == "taunt" or isActionSlotItem(item) or isTauntItem(item) then
					rawCandidates[#rawCandidates + 1] = item
				end
			end
		end
		if showStockItems then
			for _, item in pairs(tf_items.Items or {}) do
				local defindex = istable(item) and tonumber(item.id) or nil
				if istable(item) and defindex and isStockItem(item) then
					rawCandidates[#rawCandidates + 1] = item
				end
			end
		end

		if not steamInstances then
			local detail = ""
			if steamErr == "missing_file" then
				detail = "No Steam inventory cache found. Run 'tf_merge_loadout' first."
			elseif steamErr == "invalid_json" then
				detail = "Steam inventory cache is invalid JSON. Run 'tf_merge_loadout' again. Raw response is in data/tf_loadout_last_response.txt."
			elseif steamErr == "missing_items" then
				if steamStatus then
					detail = "Steam inventory response had no item list (status " .. tostring(steamStatus) .. "). Check privacy/API response, then run 'tf_merge_loadout' again."
				else
					detail = "Steam inventory response had no item list. Run 'tf_merge_loadout' again."
				end
			else
				detail = "Steam inventory unavailable. Run 'tf_merge_loadout' first."
			end
			infoLabel:SetText(detail)
			if TFDebugBridge and TFDebugBridge.SetBackpackState then
				local snapshot = {
					event = "backpack_state_error",
					class = activeClass,
					slot = panel.ForcedLoadoutSlot,
					page = currentPage,
					query = searchEntry:GetValue() or "",
					error = steamErr or "unknown",
					status = steamStatus,
					owned_count = 0,
					dedup_count = 0,
					visible_count = 0,
				}
				TFDebugBridge.SetBackpackState(snapshot)
				if TFDebugBridge.Emit then
					TFDebugBridge.Emit("backpack_rebuild", snapshot, false)
				end
			end
			return
		end

		local sourceItems = rawCandidates
		local ownedCount = #rawCandidates
		local dedupCount = ownedCount

		table.sort(sourceItems, function(a, b)
			if sortMode == "quality" then
				local qa = qualityRank(a)
				local qb = qualityRank(b)
				if qa ~= qb then return qa > qb end
			elseif sortMode == "type" then
				local ta = string.lower(tf_lang.GetRaw(a.item_type_name) or a.item_slot or "")
				local tb = string.lower(tf_lang.GetRaw(b.item_type_name) or b.item_slot or "")
				if ta ~= tb then return ta < tb end
			elseif sortMode == "class" then
				local ca = classCanUseItem(a, activeClass) and 0 or 1
				local cb = classCanUseItem(b, activeClass) and 0 or 1
				if ca ~= cb then return ca < cb end
			elseif sortMode == "slot" then
				local sa = slotOrder[sortSlotName(a)] or 99
				local sb = slotOrder[sortSlotName(b)] or 99
				if sa ~= sb then return sa < sb end
			elseif sortMode == "date" then
				local ida = tonumber(a.id) or 0
				local idb = tonumber(b.id) or 0
				if ida ~= idb then return ida > idb end
			end

			local sa = slotOrder[sortSlotName(a)] or 99
			local sb = slotOrder[sortSlotName(b)] or 99
			if sa ~= sb then return sa < sb end

			local na = string.lower(getItemDisplayName(a))
			local nb = string.lower(getItemDisplayName(b))
			if na ~= nb then return na < nb end

			return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
		end)

		local query = string.Trim(string.lower(searchEntry:GetValue() or ""))
		if query ~= "" then
			local filtered = {}
			for _, item in ipairs(sourceItems) do
				local name = string.lower(getItemDisplayName(item))
				local rawName = string.lower(item.name or "")
				if string.find(name, query, 1, true) or string.find(rawName, query, 1, true) then
					filtered[#filtered + 1] = item
				end
			end
			sourceItems = filtered
		end

		local forcedSlot = panel.ForcedLoadoutSlot
		local slotText = ""
		if forcedSlot then
			local tauntSlot = forcedSlotToTauntSlot(forcedSlot)
			if tauntSlot then
				slotText = "  |  Taunt Slot: " .. tostring(tauntSlot)
			else
				slotText = "  |  Slot: " .. tostring(forcedSlot)
			end
		end
		if forcedSlot then
			local slotFiltered = {}
			for _, item in ipairs(sourceItems) do
				local slotCompatible = true
				local tauntSlot = forcedSlotToTauntSlot(forcedSlot)
				if tauntSlot then
					slotCompatible = isTauntItem(item)
				elseif forcedSlot >= 4 and forcedSlot <= 6 then
					slotCompatible = isWearableLoadoutItem(item) and (item.item_slot == "head" or item.item_slot == "misc")
				elseif forcedSlot == 7 then
					slotCompatible = mapItemToLoadoutSlot(item, activeClass) == 7
				else
					slotCompatible = mapItemToLoadoutSlot(item, activeClass) == forcedSlot
				end
				local classCompatible = classCanUseItem(item, activeClass)
				if slotCompatible and classCompatible then
					slotFiltered[#slotFiltered + 1] = item
				end
			end
			sourceItems = slotFiltered
		end

		local visibleCount = #sourceItems
		local totalPages = math.max(1, math.ceil(visibleCount / pageSize))
		currentPage = math.Clamp(currentPage, 1, totalPages)

		infoLabel:SetText("Owned: " .. tostring(visibleCount) .. "  |  Class: " .. string.upper(activeClass) .. slotText .. "  |  Page " .. tostring(currentPage) .. "/" .. tostring(totalPages))

		if TFDebugBridge and TFDebugBridge.SetBackpackState then
			local snapshot = {
				event = "backpack_state",
				class = activeClass,
				slot = panel.ForcedLoadoutSlot,
				page = currentPage,
				query = searchEntry:GetValue() or "",
				owned_count = ownedCount,
				dedup_count = dedupCount,
				visible_count = visibleCount,
			}
			TFDebugBridge.SetBackpackState(snapshot)
			if TFDebugBridge.Emit then
				TFDebugBridge.Emit("backpack_rebuild", snapshot, false)
			end
		end

		local pageButtonsPerRow = math.max(1, math.floor(backpackLayout.pageButtonsPerRow or 20))
		local pageGapX = math.max(1, math.floor(backpackLayout.pageButtonGapX * Scale))
		local pageGapY = math.max(1, math.floor(backpackLayout.pageButtonGapY * Scale))
		local preferredPageBtnW = math.max(20, resToFrame(tostring(backpackLayout.pageButtonWidth or 25), 640, frameW, 25))
		local preferredPageBtnH = math.max(14, resToFrame(tostring(backpackLayout.pageButtonHeight or 13), 480, frameH, 13))
		local pageRows = math.max(1, math.ceil(totalPages / pageButtonsPerRow))
		local fitPageBtnW = math.max(20, math.floor((pageBar:GetWide() - ((pageButtonsPerRow - 1) * pageGapX)) / pageButtonsPerRow))
		local fitPageBtnH = math.max(14, math.floor((pageBar:GetTall() - ((pageRows - 1) * pageGapY)) / pageRows))
		local pageBtnW = math.min(preferredPageBtnW, fitPageBtnW)
		local pageBtnH = math.min(preferredPageBtnH, fitPageBtnH)

		for p = 1, totalPages do
			local btn = vgui.Create("DButton", pageBar)
			btn:SetSize(pageBtnW, pageBtnH)
			local pageRow = math.floor((p - 1) / pageButtonsPerRow)
			local pageCol = (p - 1) % pageButtonsPerRow
			btn:SetPos(pageCol * (pageBtnW + pageGapX), pageRow * (pageBtnH + pageGapY))
			btn:SetText("")
			btn.Paint = function(self, w, h)
				if p == currentPage then
					draw.RoundedBox(0, 0, 0, w, h, Color(160, 88, 68, 255))
				else
					draw.RoundedBox(0, 0, 0, w, h, Color(131, 122, 108, 228))
				end
				surface.SetDrawColor(90, 84, 76, 255)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				draw.SimpleText(tostring(p), "HudFontSmallBold", w * 0.5, h * 0.5, Color(245, 236, 214, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			btn.DoClick = function()
				currentPage = p
				panel:BuildItems()
			end
		end

		local startIndex = ((currentPage - 1) * pageSize) + 1
		local endIndex = math.min(#sourceItems, startIndex + pageSize - 1)
		local split = {}
		local convar = GetConVar("loadout_" .. activeClass)
		if convar then
			split = string.Split(convar:GetString(), ",")
		end
		local tauntSplit = getTauntLoadout(activeClass)

		for idx = startIndex, endIndex do
			local item = sourceItems[idx]
			local model = vgui.Create("ItemModelPanel", itemLayer)
			model:SetSize(tileW, tileH)
			local localIndex = idx - startIndex
			local col = localIndex % columns
			local row = math.floor(localIndex / columns)
			model:SetPos(col * (tileW + gridSpacingX), row * (tileH + gridSpacingY))

			model.activeImage = loadout_rect_mouseover
			model.inactiveImage = loadout_rect
			model.model_xpos = backpackLayout.modelX or 0
			model.model_ypos = backpackLayout.modelY or 1
			model.model_tall = math.Clamp(backpackLayout.modelTall or math.floor((tileH / Scale) * 0.30), 14, 50)
			model.text_xpos = backpackLayout.textX or -5
			model.text_wide = backpackLayout.textWide or (tileW + 10)
			model.text_ypos = backpackLayout.textY or (tileH - 13)
			model.itemImage_low = nil
			model.text = nil
			model.centerytext = false
			model.attributes = nil
			model.tooltip_attributes = buildItemTooltipAttributes(item)
			model.tooltip_name = getItemDisplayName(item)
			model.tooltip_image = nil
			model.tooltip_leveltext = getTooltipLevelText(item)
			model.tooltip_description = getTooltipDescription(item)
			model.tooltip_flavor = nil
			model.number = nil
			model:SetAttributePanel(backpackAttributePanel, 0, 0)

			model:SetQuality(getQualityDisplayName(item))

			local resolvedImage = getResolvedItemImagePath(item, item.SteamProperties)
			local invMat
			if isstring(resolvedImage) and resolvedImage ~= "" then
				invMat = Material(resolvedImage)
			end
			if (not invMat) or invMat:IsError() then
				model.FallbackModel = item.model_player
				model.itemImage = surface.GetTextureID("backpack/weapons/c_models/c_bat")
				model.tooltip_image = model.itemImage
			else
				model.itemImage = surface.GetTextureID(resolvedImage)
				model.tooltip_image = model.itemImage
			end
			applyDecoratedPanelVisual(model, item, item.SteamProperties)

			local compatible = true
			local slotCompatible = forcedSlot == nil or forcedSlot == false
			if forcedSlot then
				compatible = classCanUseItem(item, activeClass)
				local tauntSlot = forcedSlotToTauntSlot(forcedSlot)
				if tauntSlot then
					slotCompatible = isTauntItem(item)
				elseif forcedSlot >= 4 and forcedSlot <= 6 then
					slotCompatible = isWearableLoadoutItem(item) and (item.item_slot == "head" or item.item_slot == "misc")
				elseif forcedSlot == 7 then
					slotCompatible = mapItemToLoadoutSlot(item, activeClass) == 7
				else
					slotCompatible = mapItemToLoadoutSlot(item, activeClass) == forcedSlot
				end
			end
			local equipRegionCompatible = true
			if forcedSlot and forcedSlot >= 4 and forcedSlot <= 6 then
				equipRegionCompatible = not hasCosmeticEquipRegionConflict(item, split, itemsById, forcedSlot)
			end
			compatible = compatible and slotCompatible and equipRegionCompatible
			model.disabled = panel.LoadoutMode and (not compatible)
			model:SetAlpha((panel.LoadoutMode and not compatible) and 108 or 255)

			local equipped = false
			local itemId = tonumber(item.id)
			local classSlotCount = getClassLoadoutSlotCount(activeClass)
			if itemId and #split >= classSlotCount then
				local tauntSlot = forcedSlotToTauntSlot(forcedSlot)
				if tauntSlot then
					equipped = tonumber(tauntSplit[tauntSlot]) == itemId
				elseif forcedSlot then
					equipped = tonumber(split[forcedSlot]) == itemId
				else
					for s = 1, classSlotCount do
						if tonumber(split[s]) == itemId then
							equipped = true
							break
						end
					end
				end
			end
			local qualityBorder = getQualityBorderColor(item)
			model.PaintOver = function(self, w, h)
				local borderAlpha = (panel.LoadoutMode and not compatible) and 128 or 255
				surface.SetDrawColor(qualityBorder.r, qualityBorder.g, qualityBorder.b, borderAlpha)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				if panel.LoadoutMode and not compatible then
					surface.SetDrawColor(8, 8, 8, 110)
					surface.DrawRect(1, 1, w - 2, h - 2)
				end
				if equipped then
					draw.SimpleText("EQUIPPED", "HudFontSmallBold", 6, h - 4, Color(238, 131, 84, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				end
			end

			model.DoClick = function()
				if not compatible then return end

				local slot = mapItemToLoadoutSlot(item, activeClass)
				local tauntForcedSlot = forcedSlotToTauntSlot(forcedSlot)
				if forcedSlot then
					slot = forcedSlot
				end
				if isWearableLoadoutItem(item) then
					slot = forcedSlot or getWearableTargetSlot(activeClass, item.id)
				end
				if not slot and not tauntForcedSlot then return end

				if tauntForcedSlot then
					updateTauntLoadout(tauntForcedSlot, item.id, activeClass)
				else
					updateLoadout(slot, item.SchemaID or item.id, true, activeClass)
					syncClientLoadoutProperties(activeClass, slot, item.SteamProperties)
				end
				surface.PlaySound(item.mouse_pressed_sound or "ui/item_hat_pickup.wav")
				refreshLoadoutViewNow()
				if panel.LoadoutMode and IsValid(panel) then
					panel:Remove()
				end
				closeTauntLoadoutPanel()
				if TFDebugBridge and TFDebugBridge.Emit then
					TFDebugBridge.Emit("backpack_select_item", {
						class = activeClass,
						slot = tauntForcedSlot or slot,
						item_id = tonumber(item.id),
						item_name = getItemDisplayName(item),
						page = currentPage,
						query = searchEntry:GetValue() or "",
					}, false)
				end
			end

			model.DoRightClick = function()
				local menu = DermaMenu()
				menu:AddOption("Inspect", function()
					openBackpackInspect(item, activeClass)
					if TFDebugBridge and TFDebugBridge.Emit then
						TFDebugBridge.Emit("backpack_inspect_item", {
							class = activeClass,
							item_id = tonumber(item.id),
							item_name = getItemDisplayName(item),
							page = currentPage,
						}, false)
					end
				end):SetIcon("icon16/magnifier.png")
				menu:Open()
			end
		end

		backpackAttributePanel:MoveToFront()
	end

	panel:BuildItems()

	local refreshHookId = "TFStandaloneBackpackRefresh_" .. tostring(panel)
	hook.Add("TFInventoryCacheUpdated", refreshHookId, function()
		if IsValid(panel) then
			panel:BuildItems()
		else
			hook.Remove("TFInventoryCacheUpdated", refreshHookId)
		end
	end)

	panel.OnRemove = function()
		hook.Remove("TFInventoryCacheUpdated", refreshHookId)
		for _, restoreData in ipairs(classPanelsToRestore) do
			if restoreData and IsValid(restoreData.panel) then
				restoreData.panel:SetVisible(restoreData.visible ~= false)
			end
		end
		if TFDebugBridge and TFDebugBridge.Emit then
			TFDebugBridge.Emit("backpack_close", {
				class = activeClass,
				slot = panel.ForcedLoadoutSlot,
			}, false)
		end
	end
end

function itemSelector(type, weapons, parent, classid, oldclass)
	local classIndex = classid or GetConVar("tf_hud_loadout_class"):GetInt()
	local className = oldclass or classIndexToName[classIndex] or "scout"
	TF_OpenStandaloneBackpack(className, classIndex, type)
end

function hatSelector(type, slot, oldclass, weapons)
	local classIndex = GetConVar("tf_hud_loadout_class"):GetInt()
	local className = oldclass or classIndexToName[classIndex] or "scout"
	TF_OpenStandaloneBackpack(className, classIndex, slot)
end

function actionSelector(slot, oldclass, weapons)
	local classIndex = GetConVar("tf_hud_loadout_class"):GetInt()
	local className = oldclass or classIndexToName[classIndex] or "scout"
	TF_OpenStandaloneBackpack(className, classIndex, slot or 7)
end

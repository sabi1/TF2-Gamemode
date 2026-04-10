local ITEMPICKUP_METHOD_TOKENS = {
	[1] = "#NewItemMethod_Dropped",
	[2] = "#NewItemMethod_Crafted",
	[3] = "#NewItemMethod_Traded",
	[4] = "#NewItemMethod_Purchased",
	[5] = "#NewItemMethod_FoundInCrate",
	[6] = "#NewItemMethod_Gifted",
	[7] = "#NewItemMethod_Support",
	[8] = "#NewItemMethod_Promotion",
	[9] = "#NewItemMethod_Earned",
	[10] = "#NewItemMethod_Refunded",
	[11] = "#NewItemMethod_GiftWrapped",
	[12] = "#NewItemMethod_Foreign",
	[13] = "#NewItemMethod_CollectionReward",
	[14] = "#NewItemMethod_PreviewItem",
	[15] = "#NewItemMethod_PreviewItemPurchased",
	[16] = "#NewItemMethod_PeriodicScoreReward",
	[17] = "#NewItemMethod_MvMBadgeCompletionReward",
	[18] = "#NewItemMethod_MvMSquadSurplusReward",
	[19] = "#NewItemMethod_HolidayGift",
	[20] = "#NewItemMethod_CommunityMarketPurchase",
	[21] = "#NewItemMethod_RecipeOutput",
	[23] = "#NewItemMethod_QuestOutput",
	[24] = "#NewItemMethod_QuestLoaner",
	[25] = "#NewItemMethod_TradeUp",
	[26] = "#NewItemMethod_QuestMerasmissionOutput",
	[27] = "#NewItemMethod_ViralCompetitiveBetaPassSpread",
	[28] = "#NewItemMethod_BloodMoneyPurchase",
	[29] = "#NewItemMethod_PaintKit",
}

local ITEMPICKUP_METHOD_ALIASES = {
	drop = 1,
	dropped = 1,
	find = 1,
	found = 1,
	random_drop = 1,
	item_drop = 1,
	craft = 2,
	crafted = 2,
	trade = 3,
	traded = 3,
	purchase = 4,
	purchased = 4,
	bought = 4,
	crate = 5,
	crate_drop = 5,
	found_in_crate = 5,
	unboxed = 5,
	gift = 6,
	gifted = 6,
	support = 7,
	customer_support = 7,
	customer_support_granted = 7,
	support_granted = 7,
	admin_granted = 7,
	service_granted = 7,
	custom = 7,
	custom_item = 7,
	promotion = 8,
	promo = 8,
	earned = 9,
	achievement = 9,
	refund = 10,
	refunded = 10,
	giftwrapped = 11,
	gift_wrapped = 11,
	foreign = 12,
	collection_reward = 13,
	preview_item = 14,
	preview_purchase = 15,
	preview_item_purchased = 15,
	periodic_score_reward = 16,
	mvm_badge_completion_reward = 17,
	mvm_squad_surplus_reward = 18,
	holiday_gift = 19,
	community_market_purchase = 20,
	recipe_output = 21,
	quest_output = 23,
	quest_loaner = 24,
	trade_up = 25,
	quest_merasmission_output = 26,
	viral_competitive_beta_pass_spread = 27,
	blood_money_purchase = 28,
	paint_kit = 29,
	paintkit = 29,
}

local LOADOUT_CLASS_TO_INDEX = {
	scout = 1,
	soldier = 2,
	pyro = 3,
	demoman = 4,
	heavy = 5,
	engineer = 6,
	medic = 7,
	sniper = 8,
	spy = 9,
}
local LOADOUT_CLASS_LOCALIZE = {
	scout = "#TF_Class_Name_Scout",
	soldier = "#TF_Class_Name_Soldier",
	pyro = "#TF_Class_Name_Pyro",
	demoman = "#TF_Class_Name_DemoMan",
	heavy = "#TF_Class_Name_Heavy",
	engineer = "#TF_Class_Name_Engineer",
	medic = "#TF_Class_Name_Medic",
	sniper = "#TF_Class_Name_Sniper",
	spy = "#TF_Class_Name_Spy",
}
local ITEM_PICKUP_CLASS_IMAGES_RED = {
	scout = "vgui/class_sel_sm_scout_red",
	soldier = "vgui/class_sel_sm_soldier_red",
	pyro = "vgui/class_sel_sm_pyro_red",
	demoman = "vgui/class_sel_sm_demo_red",
	heavy = "vgui/class_sel_sm_heavy_red",
	engineer = "vgui/class_sel_sm_engineer_red",
	medic = "vgui/class_sel_sm_medic_red",
	sniper = "vgui/class_sel_sm_sniper_red",
	spy = "vgui/class_sel_sm_spy_red",
	all = "vgui/class_sel_sm_random_red",
}

local ITEM_PICKUP_RES_PATH = "resource/ui/econ/itempickuppanel.res"
surface.CreateFont("TF2ItemPickup_HudFontMediumBigBold", {
	font = "TF2 Build",
	size = 30,
	weight = 500,
	antialias = true,
})
surface.CreateFont("TF2ItemPickup_HudFontMediumSmallBold", {
	font = "TF2 Build",
	size = 18,
	weight = 500,
	antialias = true,
})
surface.CreateFont("TF2ItemPickup_HudFontMediumBold", {
	font = "TF2 Build",
	size = 24,
	weight = 500,
	antialias = true,
})
surface.CreateFont("TF2ItemPickup_HudFontSmallBold", {
	font = "TF2 Build",
	size = 14,
	weight = 500,
	antialias = true,
})
surface.CreateFont("TF2ItemPickup_HudFontSmallestBold", {
	font = "TF2 Build",
	size = 11,
	weight = 500,
	antialias = true,
})
local ITEM_PICKUP_FONT_REMAP = {
	HudFontMediumBigBold = "TF2ItemPickup_HudFontMediumBigBold",
	HudFontMediumSmallBold = "TF2ItemPickup_HudFontMediumSmallBold",
	HudFontMediumBold = "TF2ItemPickup_HudFontMediumBold",
	HudFontSmallestBold = "TF2ItemPickup_HudFontSmallestBold",
	HudFontSmallBold = "TF2ItemPickup_HudFontSmallBold",
}

local function tfItemPickupScale()
	return ScrH() / 480
end

local function tfItemPickupLocalize(token, fallback)
	if tf_lang and tf_lang.GetRaw then
		local text = tf_lang.GetRaw(token, true)
		if isstring(text) and text ~= "" and text ~= token then
			return text
		end
	end
	return fallback
end

local function tfItemPickupResolveFont(fontName, fallback)
	local resolved = ITEM_PICKUP_FONT_REMAP[tostring(fontName or "")] or fontName or fallback or "HudFontSmallBold"
	return tostring(resolved)
end

local function tfItemPickupGetResTree()
	if not (TF2Res and TF2Res.Load) then return nil end
	return TF2Res.Load(ITEM_PICKUP_RES_PATH)
end

local function tfItemPickupParseCoord(raw, axisSize, default, axisScale)
	if raw == nil then return default end
	if isnumber(raw) then return raw end
	if not isstring(raw) then return default end

	raw = string.Trim(raw)
	if raw == "" then return default end

	axisScale = axisScale or 1

	local numeric = tonumber(raw)
	if numeric ~= nil then
		return numeric * axisScale
	end

	local anchor, offset = string.match(raw, "^([crf])([%+%-]?%d*%.?%d*)$")
	if not anchor then
		return default
	end

	offset = tonumber(offset) or 0
	if anchor == "c" then
		return axisSize * 0.5 + offset * axisScale
	end
	if anchor == "r" or anchor == "f" then
		return axisSize - offset * axisScale
	end

	return default
end

local function tfItemPickupFindNode(fieldName)
	local tree = tfItemPickupGetResTree()
	if not tree then return nil end
	if TF2Res.FindByFieldName then
		local node = TF2Res.FindByFieldName(tree, fieldName)
		if node then return node end
	end
	if TF2Res.FindByKey then
		return TF2Res.FindByKey(tree, fieldName)
	end
	return nil
end

local function tfItemPickupGetRect(fieldName, defaults)
	local node = tfItemPickupFindNode(fieldName)
	local fallback = defaults or {x = 0, y = 0, w = 0, h = 0}
	if not (node and TF2Res and TF2Res.GetString) then
		return table.Copy(fallback)
	end
	local scale = tfItemPickupScale()
	return {
		x = tfItemPickupParseCoord(TF2Res.GetString(node, "xpos", nil), ScrW(), fallback.x, scale),
		y = tfItemPickupParseCoord(TF2Res.GetString(node, "ypos", nil), ScrH(), fallback.y, scale),
		w = tfItemPickupParseCoord(TF2Res.GetString(node, "wide", nil), ScrW(), fallback.w, scale),
		h = tfItemPickupParseCoord(TF2Res.GetString(node, "tall", nil), ScrH(), fallback.h, scale),
	}
end

local function tfItemPickupGetStringProp(fieldName, key, default)
	local node = tfItemPickupFindNode(fieldName)
	if not (node and TF2Res and TF2Res.GetString) then return default end
	return TF2Res.GetString(node, key, default)
end

local function tfItemPickupDrawLabel(text, fieldName, fallbackFont, fallbackColor)
	local rect = tfItemPickupGetRect(fieldName, {x = 0, y = 0, w = ScrW(), h = 24})
	local font = tfItemPickupResolveFont(tfItemPickupGetStringProp(fieldName, "font", fallbackFont), fallbackFont)
	local align = string.lower(tostring(tfItemPickupGetStringProp(fieldName, "textAlignment", "north-west")))
	local color = fallbackColor or Color(243, 241, 232, 255)

	local x = rect.x
	local y = rect.y
	local textAlignX = TEXT_ALIGN_LEFT
	local textAlignY = TEXT_ALIGN_TOP

	if string.find(align, "center", 1, true) then
		x = rect.x + rect.w * 0.5
		textAlignX = TEXT_ALIGN_CENTER
	elseif string.find(align, "east", 1, true) then
		x = rect.x + rect.w
		textAlignX = TEXT_ALIGN_RIGHT
	end

	if string.find(align, "south", 1, true) then
		y = rect.y + rect.h
		textAlignY = TEXT_ALIGN_BOTTOM
	elseif string.find(align, "center", 1, true) then
		y = rect.y + rect.h * 0.5
		textAlignY = TEXT_ALIGN_CENTER
	end

	draw.SimpleText(text or "", font, x, y, color, textAlignX, textAlignY)
end

local function tfItemPickupApplyLabelControl(panel, fieldName, fallbackFont, fallbackColor)
	if not IsValid(panel) then return end

	local rect = tfItemPickupGetRect(fieldName, {x = 0, y = 0, w = 0, h = 0})
	panel:SetPos(math.floor(rect.x), math.floor(rect.y))
	panel:SetSize(math.floor(rect.w), math.floor(rect.h))
	panel.font = tfItemPickupResolveFont(tfItemPickupGetStringProp(fieldName, "font", fallbackFont), fallbackFont)
	panel.textAlignment = tfItemPickupGetStringProp(fieldName, "textAlignment", "north-west")
	panel.fgcolor = fallbackColor or Color(243, 241, 232, 255)
end

local function tfItemPickupCreateLabel(parent)
	local panel = vgui.Create("DPanel", parent)
	panel:SetPaintBackground(false)
	panel.labelText = ""
	panel.font = "TF2ItemPickup_HudFontSmallBold"
	panel.textAlignment = "north-west"
	panel.fgcolor = Color(243, 241, 232, 255)
	panel.Paint = function(self, w, h)
		local text = self.labelText
		if type(text) == "function" then
			text = text()
		end
		tf_draw.LabelText(
			0,
			0,
			w,
			h,
			text or "",
			self.fgcolor or "TanLight",
			self.font or "Default",
			self.textAlignment or "north-west"
		)
	end
	return panel
end

local function tfItemPickupClassImage(className)
	className = string.lower(tostring(className or ""))
	if className == "" then
		return ITEM_PICKUP_CLASS_IMAGES_RED.all
	end
	return ITEM_PICKUP_CLASS_IMAGES_RED[className] or ITEM_PICKUP_CLASS_IMAGES_RED.all
end

local function tfItemPickupCurrentClass()
	local lp = LocalPlayer()
	if IsValid(lp) and lp.GetPlayerClass then
		local className = tostring(lp:GetPlayerClass() or "")
		if className ~= "" then
			return className
		end
	end
	return "scout"
end

local function tfItemPickupReplaceDialogVars(text, vars)
	text = tostring(text or "")
	vars = vars or {}
	for key, value in pairs(vars) do
		text = string.gsub(text, "%%" .. tostring(key) .. "%%", tostring(value))
	end
	text = string.gsub(text, "[%c]", "")
	return text
end

local function tfItemPickupFormatLocalized(text, ...)
	text = tostring(text or "")
	local args = {...}
	for i, value in ipairs(args) do
		text = string.gsub(text, "%%s" .. tostring(i), tostring(value or ""))
	end
	text = string.gsub(text, "[%c]", "")
	return text
end

local function tfItemPickupDeepCopy(tbl)
	if not istable(tbl) then
		return tbl
	end

	local out = {}
	for k, v in pairs(tbl) do
		out[k] = istable(v) and tfItemPickupDeepCopy(v) or v
	end
	return out
end

local function tfItemPickupQualityNameFromID(id)
	local n = tonumber(id)
	if not n then return nil end
	for name, value in pairs(tf_items and tf_items.Qualities or {}) do
		if tonumber(value) == n then
			return name
		end
	end
	return nil
end

local function tfItemPickupQualityDisplay(item)
	local q = string.lower(tostring(item and item.item_quality or "unique"))
	if q == "" then
		q = "unique"
	end
	return string.upper(string.sub(q, 1, 1)) .. string.sub(q, 2)
end

local function tfItemPickupQualityColor(item)
	local key = "QualityColor" .. tfItemPickupQualityDisplay(item)
	return (Colors and Colors[key]) or (Colors and Colors.QualityColorUnique) or Color(238, 210, 68, 255)
end

local function tfItemPickupLevelText(item)
	local level = tonumber(item and item.SteamProperties and item.SteamProperties.level)
		or tonumber(item and item.item_level)
		or tonumber(item and item.min_ilevel)
		or tonumber(item and item.max_ilevel)
		or 1
	local typeName = tfItemPickupLocalize(item and item.item_type_name, nil)
	if not isstring(typeName) or typeName == "" then
		local slot = tostring(item and item.item_slot or "item")
		typeName = string.upper(string.sub(slot, 1, 1)) .. string.sub(slot, 2) .. " Item"
	end
	return string.format("Level %d %s", math.floor(level), typeName)
end

local function tfItemPickupDescription(item)
	if item and item.SteamProperties and isstring(item.SteamProperties.custom_desc) and item.SteamProperties.custom_desc ~= "" then
		return item.SteamProperties.custom_desc
	end
	return tfItemPickupLocalize(item and item.item_description, "")
end

local function tfItemPickupDisplayName(item)
	if isfunction(getDecoratedDisplayName) then
		return getDecoratedDisplayName(item, item and item.SteamProperties)
	end
	if item and item.item_name then
		return tfItemPickupLocalize(item.item_name, item.name or "UNKNOWN ITEM")
	end
	return item and item.name or "UNKNOWN ITEM"
end

local function tfItemPickupImage(item)
	local path = nil
	if isfunction(getResolvedItemImagePath) then
		path = getResolvedItemImagePath(item, item and item.SteamProperties)
	end
	if not isstring(path) or path == "" then
		path = item and item.image_inventory or ""
	end
	return surface.GetTextureID(path or "")
end

local function tfItemPickupModelPath(item, className)
	if not istable(item) then return nil end

	className = string.lower(tostring(className or ""))
	if className == "" then
		className = string.lower(tfItemPickupCurrentClass())
	end

	local perClass = item.model_player_per_class
	if istable(perClass) then
		local resolved = perClass[className] or perClass[(className == "demoman" and "demo" or className)] or perClass.basename
		if isstring(resolved) and resolved ~= "" then
			resolved = string.Replace(resolved, "%s", className)
			if util.IsValidModel(resolved) then
				return resolved
			end
		end
	end

	if isstring(item.model_player) and item.model_player ~= "" then
		local resolved = string.Replace(item.model_player, "%s", className)
		if util.IsValidModel(resolved) then
			return resolved
		end
	end

	if isstring(item.model_world) and item.model_world ~= "" and util.IsValidModel(item.model_world) then
		return item.model_world
	end

	return nil
end

local function tfItemPickupFindClass(item)
	if not istable(item) then
		return tfItemPickupCurrentClass()
	end
	if item.used_by_classes and item.used_by_classes.all then
		return ""
	end
	for _, className in ipairs({"scout", "soldier", "pyro", "demoman", "heavy", "engineer", "medic", "sniper", "spy"}) do
		if item.used_by_classes and item.used_by_classes[className] then
			return className
		end
	end
	return tfItemPickupCurrentClass()
end

local function tfItemPickupCanUseByAllClasses(item)
	return istable(item) and istable(item.used_by_classes) and item.used_by_classes.all == true
end

local function tfItemPickupLocalizedClassName(className)
	local token = LOADOUT_CLASS_LOCALIZE[string.lower(tostring(className or ""))]
	if not token then
		return nil
	end
	return tfItemPickupLocalize(token, className)
end

local function tfItemPickupMethodText(method, itemCount)
	local token = ITEMPICKUP_METHOD_TOKENS[tonumber(method) or 1] or "#NewItemMethod_Dropped"
	return tfItemPickupReplaceDialogVars(tfItemPickupLocalize(token, token), {
		numitems = itemCount or 1,
		selecteditem = 1,
	})
end

local function tfItemPickupNormalizeMethodValue(value)
	if value == nil then return nil end

	local numeric = tonumber(value)
	if numeric and ITEMPICKUP_METHOD_TOKENS[numeric] then
		return numeric
	end

	if not isstring(value) then
		return nil
	end

	local key = string.Trim(string.lower(value))
	if key == "" then
		return nil
	end

	key = string.gsub(key, "^#newitemmethod_", "")
	key = string.gsub(key, "[%s%-]+", "_")
	return ITEMPICKUP_METHOD_ALIASES[key]
end

local function tfItemPickupResolveMethodFromItem(item, fallback)
	local candidates = {
		fallback,
		item and item.pickup_method,
		item and item.acquisition_method,
		item and item.item_origin,
		item and item.origin,
		item and item.SteamProperties and item.SteamProperties.pickup_method,
		item and item.SteamProperties and item.SteamProperties.acquisition_method,
		item and item.SteamProperties and item.SteamProperties.item_origin,
		item and item.SteamProperties and item.SteamProperties.origin,
		item and item.SteamItemData and item.SteamItemData.pickup_method,
		item and item.SteamItemData and item.SteamItemData.acquisition_method,
		item and item.SteamItemData and item.SteamItemData.item_origin,
		item and item.SteamItemData and item.SteamItemData.origin,
	}

	for _, candidate in ipairs(candidates) do
		local resolved = tfItemPickupNormalizeMethodValue(candidate)
		if resolved then
			return resolved
		end
	end

	return 1
end

local function tfItemPickupBuildTestItem(defindex, qualityName, className)
	local def = tonumber(defindex) and tf_items and tf_items.ItemsByID and tf_items.ItemsByID[tonumber(defindex)] or nil
	if not istable(def) then
		className = string.lower(tostring(className or tfItemPickupCurrentClass()))
		for _, candidate in pairs(tf_items and tf_items.Items or {}) do
			if istable(candidate)
				and candidate.used_by_classes
				and candidate.used_by_classes[className]
				and candidate.item_slot
				and candidate.baseitem ~= true
			then
				def = candidate
				break
			end
		end
	end
	if not istable(def) then return nil end

	local item = tfItemPickupDeepCopy(def)
	item.SteamProperties = {
		defindex = tonumber(item.id),
		level = tonumber(item.item_level) or tonumber(item.min_ilevel) or tonumber(item.max_ilevel) or 10,
		origin = 1,
	}

	local quality = string.lower(tostring(qualityName or item.item_quality or "unique"))
	if quality == "" then
		quality = "unique"
	end
	item.item_quality = quality
	item.SteamProperties.quality = tonumber(tf_items and tf_items.Qualities and tf_items.Qualities[quality]) or 6

	return item
end

local function tfItemPickupBuildItemFromInventoryData(invItem)
	if not istable(invItem) then return nil end

	local defindex = tonumber(invItem.defindex or (invItem.properties and invItem.properties.defindex))
	local baseItem = defindex and tf_items and tf_items.ItemsByID and tf_items.ItemsByID[defindex] or nil
	local item = istable(baseItem) and tfItemPickupDeepCopy(baseItem) or {}

	if defindex and item.id == nil then
		item.id = defindex
	end

	item.SteamItemData = invItem
	item.InventoryInstanceID = tonumber(invItem.id or invItem.original_id)
	item.SteamProperties = tfItemPickupDeepCopy(invItem.properties or {})

	for _, key in ipairs({"defindex", "quality", "level", "custom_name", "custom_desc", "pickup_method", "acquisition_method", "item_origin", "origin", "attributes"}) do
		if item.SteamProperties[key] == nil and invItem[key] ~= nil then
			item.SteamProperties[key] = tfItemPickupDeepCopy(invItem[key])
		end
	end

	if not isstring(item.image_inventory) or item.image_inventory == "" then
		item.image_inventory = invItem.image_inventory or item.image_inventory
	end
	if not isstring(item.item_name) or item.item_name == "" then
		item.item_name = invItem.item_name or invItem.display_name or ("Defindex " .. tostring(defindex or 0))
	end
	if not isstring(item.item_description) or item.item_description == "" then
		item.item_description = invItem.custom_desc or invItem.item_description or ""
	end
	if not istable(item.used_by_classes) and istable(invItem.used_by_classes) then
		item.used_by_classes = tfItemPickupDeepCopy(invItem.used_by_classes)
	end

	local qualityName = tfItemPickupQualityNameFromID(item.SteamProperties.quality or invItem.quality)
		or (isstring(invItem.item_quality) and invItem.item_quality)
		or (isstring(item.item_quality) and item.item_quality)
		or "unique"
	item.item_quality = string.lower(tostring(qualityName))

	if isstring(item.SteamProperties.custom_name) and item.SteamProperties.custom_name ~= "" then
		item.item_name = item.SteamProperties.custom_name
	end
	if isstring(item.SteamProperties.custom_desc) and item.SteamProperties.custom_desc ~= "" then
		item.item_description = item.SteamProperties.custom_desc
	end

	return item
end

local PANEL = {}

function PANEL:Init()
	self:SetSize(ScrW(), ScrH())
	self:MakePopup()
	self:SetKeyboardInputEnabled(true)
	self:SetMouseInputEnabled(true)
	self:SetPaintBackgroundEnabled(false)
	self:SetVisible(false)

	self.SelectedIndex = 1
	self.Items = {}
	self.Options = {}
	self.ResolvedLayout = nil

	self.AttributePanel = vgui.Create("ItemAttributePanel", self)
	self.AttributePanel:SetVisible(false)

	self.HeaderLabel = tfItemPickupCreateLabel(self)
	self.MethodLabel = tfItemPickupCreateLabel(self)
	self.ItemCountLabel = tfItemPickupCreateLabel(self)
	self.SelectedItemNumberLabel = tfItemPickupCreateLabel(self)
	self.DiscardedLabel = tfItemPickupCreateLabel(self)
	self.ClassImageOutline = vgui.Create("DPanel", self)
	self.ClassImageOutline:SetPaintBackground(true)
	self.ClassImage = vgui.Create("DImage", self)

	self.ItemPanels = {}
	for i = 1, 3 do
		local model = vgui.Create("ItemModelPanel", self)
		model:SetPaintBackgroundEnabled(false)
		model.model_tall = 112
		model.model_ypos = 18
		model.text_ypos = 112
		model.text_wide = 180
		model.text_xpos = 10
		model.centertext = false
		model:SetAttributePanel(self.AttributePanel, 0, 0)
		self.ItemPanels[i] = model
	end

	self.PrevButton = vgui.Create("TFButton", self)
	self.PrevButton.DoClick = function()
		self:OnCommand("previtem")
	end

	self.NextButton = vgui.Create("TFButton", self)
	self.NextButton.DoClick = function()
		self:OnCommand("nextitem")
	end

	self.CloseButton = vgui.Create("TFButton", self)
	self.CloseButton.DoClick = function()
		self:OnCommand("vguicancel")
	end

	self.LoadoutButton = vgui.Create("TFButton", self)
	self.LoadoutButton.DoClick = function()
		self:OnCommand("changeloadout")
	end
end

function PANEL:ClosePanel()
	self.AttributePanel:SetVisible(false)
	self:SetVisible(false)
	gui.EnableScreenClicker(false)
end

function PANEL:OpenLoadoutForSelected()
	local item = self.Items[self.SelectedIndex]
	if not istable(item) then
		self:ClosePanel()
		return
	end

	local className = tfItemPickupFindClass(item)
	if className == "" then
		className = tfItemPickupCurrentClass()
	end
	local classIndex = LOADOUT_CLASS_TO_INDEX[className] or LOADOUT_CLASS_TO_INDEX[tfItemPickupCurrentClass()] or 1

	self:ClosePanel()
	RunConsoleCommand("tf_hud_loadout_class", tostring(classIndex))
	RunConsoleCommand("open_charinfo_direct")

	timer.Simple(0.08, function()
		if IsValid(CharInfoLoadoutSubPanel) and CharInfoLoadoutSubPanel.SelectClassLoadout2 then
			CharInfoLoadoutSubPanel:SelectClassLoadout2(classIndex)
		elseif isfunction(TF_OpenStandaloneBackpack) then
			TF_OpenStandaloneBackpack(className, classIndex)
		end
	end)
end

function PANEL:OnCommand(command)
	if command == "vguicancel" then
		self:ClosePanel()
		return
	end
	if command == "changeloadout" then
		self:OpenLoadoutForSelected()
		return
	end
	if command == "nextitem" then
		if self.SelectedIndex < #self.Items then
			self.SelectedIndex = math.Clamp(self.SelectedIndex + 1, 1, #self.Items)
			self:UpdateModelPanels()
		end
		return
	end
	if command == "previtem" then
		if self.SelectedIndex > 1 then
			self.SelectedIndex = math.Clamp(self.SelectedIndex - 1, 1, #self.Items)
			self:UpdateModelPanels()
		end
		return
	end
end

function PANEL:ApplyItemPanel(model, item, selected)
	if not IsValid(model) then return end
	if not istable(item) then
		model:SetVisible(false)
		model.itemImage = nil
		model.text = nil
		return
	end

	local layout = self.ResolvedLayout or {}
	local panelCfg = selected and layout.modelCenter or layout.modelSide or {}

	model:SetVisible(true)
	model:SetSize(panelCfg.w or (selected and 500 or 500), panelCfg.h or (selected and 260 or 260))
	model.text = tfItemPickupDisplayName(item)
	model.tooltip_name = model.text
	model.tooltip_attributes = {}
	model.tooltip_leveltext = tfItemPickupLevelText(item)
	model.tooltip_description = tfItemPickupDescription(item)
	model.tooltip_flavor = tfItemPickupLocalize(item.item_logname, "")
	model.itemImage = tfItemPickupImage(item)
	model.tooltip_image = model.itemImage
	model.textcolor = tfItemPickupQualityColor(item)
	model:SetQuality(tfItemPickupQualityDisplay(item))
	model.FallbackModel = tfItemPickupModelPath(item, tfItemPickupFindClass(item))
	model.model_tall = panelCfg.model_tall or 160
	model.model_ypos = panelCfg.model_ypos or 14
	model.model_xpos = panelCfg.model_xpos or 0
	model.text_ypos = panelCfg.text_ypos or 120
	model.text_wide = panelCfg.text_wide or 230
	model.text_xpos = panelCfg.text_xpos or 245
	model.centertext = panelCfg.text_center == true
end

function PANEL:UpdateModelPanels()
	local itemCount = #self.Items
	if itemCount <= 0 then
		self:ClosePanel()
		return
	end

	self.SelectedIndex = math.Clamp(self.SelectedIndex, 1, itemCount)

	local selectedItem = self.Items[self.SelectedIndex]
	local headerToken = itemCount > 1 and "#NewItemsAcquired" or "#NewItemAcquired"
	self.HeaderText = tfItemPickupReplaceDialogVars(tfItemPickupLocalize(headerToken, "NEW ITEM ACQUIRED!"), {
		numitems = itemCount,
		selecteditem = self.SelectedIndex,
	})
	self.MethodText = tfItemPickupMethodText(tfItemPickupResolveMethodFromItem(selectedItem, self.Options.method), itemCount)
	self.SelectedNumberText = tfItemPickupReplaceDialogVars(tfItemPickupLocalize("#SelectedItemNumber", "#%selecteditem%"), {
		selecteditem = self.SelectedIndex,
	})
	local loadoutText = tfItemPickupLocalize("#OpenGeneralLoadout", "OPEN LOADOUT...")
	if istable(selectedItem) then
		if tfItemPickupCanUseByAllClasses(selectedItem) then
			loadoutText = tfItemPickupLocalize("#OpenGeneralLoadout", "OPEN LOADOUT...")
		else
			local className = tfItemPickupFindClass(selectedItem)
			if LOADOUT_CLASS_TO_INDEX[className] then
				local localizedClass = tfItemPickupLocalizedClassName(className) or className
				local template = tfItemPickupLocalize("#OpenSpecificLoadout", "OPEN %s1 LOADOUT...")
				loadoutText = tfItemPickupFormatLocalized(template, string.upper(tostring(localizedClass)))
			else
				loadoutText = tfItemPickupLocalize("#OpenBackpack", "OPEN BACKPACK")
			end
		end
	end

	self.LoadoutButton.labelText = loadoutText
	self.LoadoutButton.font = tfItemPickupResolveFont(tfItemPickupGetStringProp("OpenLoadoutButton", "font", "HudFontSmallBold"), "HudFontSmallBold")
	self.CloseButton.labelText = tfItemPickupLocalize("#CloseItemPanel", "OK, RESUME GAME")
	self.CloseButton.font = tfItemPickupResolveFont(tfItemPickupGetStringProp("CloseButton", "font", "HudFontSmallBold"), "HudFontSmallBold")
	self.PrevButton.labelText = tfItemPickupLocalize("#PreviousItem", "VIEW\n< PREV")
	self.PrevButton.font = tfItemPickupResolveFont(tfItemPickupGetStringProp("PrevButton", "font", "HudFontSmallestBold"), "HudFontSmallestBold")
	self.NextButton.labelText = tfItemPickupLocalize("#NextItem", "VIEW\nNEXT >")
	self.NextButton.font = tfItemPickupResolveFont(tfItemPickupGetStringProp("NextButton", "font", "HudFontSmallestBold"), "HudFontSmallestBold")

	self:ApplyItemPanel(self.ItemPanels[1], self.Items[self.SelectedIndex - 1], false)
	self:ApplyItemPanel(self.ItemPanels[2], selectedItem, true)
	self:ApplyItemPanel(self.ItemPanels[3], self.Items[self.SelectedIndex + 1], false)

	self.PrevButton.disabled = self.SelectedIndex <= 1
	self.NextButton.disabled = self.SelectedIndex >= itemCount
	self.PrevButton:SetVisible(itemCount > 1 and self.SelectedIndex > 1)
	self.NextButton:SetVisible(itemCount > 1 and self.SelectedIndex < itemCount)
	self.LoadoutButton:SetVisible(true)

	self.HeaderLabel.labelText = self.HeaderText or ""
	self.MethodLabel.labelText = self.MethodText or ""
	self.ItemCountLabel.labelText = tfItemPickupLocalize("#Item", "ITEM")
	self.SelectedItemNumberLabel.labelText = self.SelectedNumberText or ""
	self.DiscardedLabel.labelText = tfItemPickupLocalize("#Discarded", "DISCARDED")
	self.HeaderLabel:SetVisible(true)
	self.MethodLabel:SetVisible(true)
	self.ItemCountLabel:SetVisible(true)
	self.SelectedItemNumberLabel:SetVisible(true)
	self.DiscardedLabel:SetVisible(false)

	local classImagePath = nil
	if istable(selectedItem) then
		if tfItemPickupCanUseByAllClasses(selectedItem) then
			classImagePath = tfItemPickupClassImage("")
		else
			classImagePath = tfItemPickupClassImage(tfItemPickupFindClass(selectedItem))
		end
	end
	if isstring(classImagePath) and classImagePath ~= "" then
		self.ClassImage:SetImage(classImagePath)
		self.ClassImage:SetVisible(true)
		self.ClassImageOutline:SetVisible(true)
	else
		self.ClassImage:SetVisible(false)
		self.ClassImageOutline:SetVisible(false)
	end

	self:InvalidateLayout(true)
end

function PANEL:SetPickupItems(items, options)
	self.Items = {}
	for _, item in ipairs(items or {}) do
		if istable(item) then
			self.Items[#self.Items + 1] = item
		end
	end
	self.Options = options or {}
	self.SelectedIndex = 1
	gui.EnableScreenClicker(true)
	self:SetVisible(true)
	self:MakePopup()
	self:UpdateModelPanels()
end

function PANEL:PerformLayout()
	self:SetSize(ScrW(), ScrH())

	local rootNode = tfItemPickupFindNode("item_pickup")
	local scale = tfItemPickupScale()
	local panelW = ScrW()
	local panelH = ScrH()
	local modelSpacing = 40 * scale
	local modelW = 500 * scale
	local modelH = 260 * scale
	local modelY = 110 * scale
	local centerX = panelW * 0.5

	if rootNode and TF2Res and TF2Res.GetNumber then
		modelSpacing = TF2Res.GetNumber(rootNode, "modelpanels_spacing", 40) * scale
		modelW = TF2Res.GetNumber(rootNode, "modelpanels_width", 500) * scale
		modelH = TF2Res.GetNumber(rootNode, "modelpanels_height", 260) * scale
		modelY = TF2Res.GetNumber(rootNode, "modelpanels_ypos", 110) * scale
	end

	local modelKV = tfItemPickupFindNode("modelpanelskv")
	local modelTextX = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(modelKV, "text_xpos", 245) * scale or 245 * scale
	local modelTextW = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(modelKV, "text_wide", 230) * scale or 230 * scale
	local modelTall = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(modelKV, "model_tall", 160) * scale or 160 * scale
	local modelX = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(modelKV, "model_xpos", 0) * scale or 0
	local modelTextCentered = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(modelKV, "text_center", 1) ~= 0 or true

	self.ResolvedLayout = {
		modelCenter = {
			w = modelW,
			h = modelH,
			model_tall = modelTall,
			model_ypos = 0,
			model_xpos = modelX,
			text_ypos = modelH * 0.5 - 18 * scale,
			text_wide = modelTextW,
			text_xpos = modelTextX,
			text_center = modelTextCentered,
		},
		modelSide = {
			w = modelW,
			h = modelH,
			model_tall = modelTall,
			model_ypos = 0,
			model_xpos = modelX,
			text_ypos = modelH * 0.5 - 18 * scale,
			text_wide = modelTextW,
			text_xpos = modelTextX,
			text_center = modelTextCentered,
		},
	}

	for i = 1, 3 do
		local iPos = i - 2
		local x = centerX + (iPos * modelSpacing) + (iPos * modelW) - (modelW * 0.5)
		self.ItemPanels[i]:SetSize(modelW, modelH)
		self.ItemPanels[i]:SetPos(math.floor(x), math.floor(modelY))
	end

	local prevRect = tfItemPickupGetRect("PrevButton", {x = centerX - 265 * scale, y = 350 * scale, w = 70 * scale, h = 30 * scale})
	self.PrevButton:SetPos(math.floor(prevRect.x), math.floor(prevRect.y))
	self.PrevButton:SetSize(math.floor(prevRect.w), math.floor(prevRect.h))

	local nextRect = tfItemPickupGetRect("NextButton", {x = centerX + 195 * scale, y = 350 * scale, w = 70 * scale, h = 30 * scale})
	self.NextButton:SetPos(math.floor(nextRect.x), math.floor(nextRect.y))
	self.NextButton:SetSize(math.floor(nextRect.w), math.floor(nextRect.h))

	local loadoutRect = tfItemPickupGetRect("OpenLoadoutButton", {x = centerX - 300 * scale, y = 420 * scale, w = 250 * scale, h = 30 * scale})
	self.LoadoutButton:SetPos(math.floor(loadoutRect.x), math.floor(loadoutRect.y))
	self.LoadoutButton:SetSize(math.floor(loadoutRect.w), math.floor(loadoutRect.h))

	local closeRect = tfItemPickupGetRect("CloseButton", {x = centerX + 50 * scale, y = 420 * scale, w = 250 * scale, h = 30 * scale})
	self.CloseButton:SetPos(math.floor(closeRect.x), math.floor(closeRect.y))
	self.CloseButton:SetSize(math.floor(closeRect.w), math.floor(closeRect.h))

	tfItemPickupApplyLabelControl(self.HeaderLabel, "ItemsFoundLabel", "HudFontMediumBigBold", Color(243, 241, 232, 255))
	tfItemPickupApplyLabelControl(self.MethodLabel, "SelectedItemFoundMethodLabel", "HudFontMediumSmallBold", Color(219, 214, 199, 255))
	tfItemPickupApplyLabelControl(self.ItemCountLabel, "ItemCountLabel", "HudFontSmallestBold", Color(214, 204, 186, 255))
	tfItemPickupApplyLabelControl(self.SelectedItemNumberLabel, "SelectedItemNumberLabel", "HudFontMediumBigBold", Color(243, 241, 232, 255))
	tfItemPickupApplyLabelControl(self.DiscardedLabel, "DiscardedLabel", "HudFontMediumBold", Color(200, 80, 60, 255))

	local classOutlineRect = tfItemPickupGetRect("classimageoutline", {x = centerX + 208 * scale, y = 115 * scale, w = 36 * scale, h = 36 * scale})
	self.ClassImageOutline:SetPos(math.floor(classOutlineRect.x), math.floor(classOutlineRect.y))
	self.ClassImageOutline:SetSize(math.floor(classOutlineRect.w), math.floor(classOutlineRect.h))
	self.ClassImageOutline:SetBackgroundColor(Color(0, 0, 0, 255))

	local classImageRect = tfItemPickupGetRect("classimage", {x = centerX + 211 * scale, y = 118 * scale, w = 30 * scale, h = 30 * scale})
	self.ClassImage:SetPos(math.floor(classImageRect.x), math.floor(classImageRect.y))
	self.ClassImage:SetSize(math.floor(classImageRect.w), math.floor(classImageRect.h))
end

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, Color(46, 43, 42, 250))

	tfItemPickupDrawLabel(self.HeaderText or "", "ItemsFoundLabel", "HudFontMediumBigBold", Color(243, 241, 232, 255))
	tfItemPickupDrawLabel(self.MethodText or "", "SelectedItemFoundMethodLabel", "HudFontMediumSmallBold", Color(219, 214, 199, 255))
end

function PANEL:OnKeyCodePressed(code)
	if code == KEY_ESCAPE or code == KEY_ENTER then
		self:OnCommand("vguicancel")
		return
	end
	if code == KEY_LEFT then
		self:OnCommand("previtem")
		return
	end
	if code == KEY_RIGHT then
		self:OnCommand("nextitem")
		return
	end
end

vgui.Register("TFItemPickupPanel", PANEL, "EditablePanel")

local TFItemPickupPanelHandle = TFItemPickupPanelHandle or nil

function TF2GM_OpenItemPickupPanel(items, options)
	if not IsValid(TFItemPickupPanelHandle) then
		TFItemPickupPanelHandle = vgui.Create("TFItemPickupPanel")
	end
	TFItemPickupPanelHandle:SetPickupItems(items, options)
	return TFItemPickupPanelHandle
end

function TF2GM_BuildPickupItemFromInventoryData(invItem)
	return tfItemPickupBuildItemFromInventoryData(invItem)
end

function TF2GM_ShowNewItemsNotification(items, options)
	local pickupItems = {}
	for _, item in ipairs(items or {}) do
		local resolved = TF2GM_BuildPickupItemFromInventoryData(item) or item
		if istable(resolved) then
			pickupItems[#pickupItems + 1] = resolved
		end
	end

	if #pickupItems <= 0 then
		return false
	end

	NotificationQueue_Remove(function(notification)
		return notification.key == "tf_inventory_new_items"
	end)

	NotificationQueue_Add({
		key = "tf_inventory_new_items",
		title = "",
		text = tfItemPickupLocalize("#TF_HasNewItems", "You have new items!"),
		lifetime = 7,
		type = "trigger",
		uiStyle = "econ_toast",
		resPath = "resource/ui/econ/genericnotificationtoast.res",
		controlResPath = "resource/ui/econ/notificationtoastcontrol.res",
		OnTrigger = function()
			TF2GM_OpenItemPickupPanel(pickupItems, options or {})
		end,
	})

	return true
end

local function TF2GM_RunTestItemDrop()
	local defindex = GetConVar("tf_test_item_drop_defindex")
	local quality = GetConVar("tf_test_item_drop_quality")
	local className = GetConVar("tf_test_item_drop_class")
	local method = GetConVar("tf_test_item_drop_method")

	local item = tfItemPickupBuildTestItem(
		defindex and defindex:GetInt() or 13,
		quality and quality:GetString() or "unique",
		className and className:GetString() or tfItemPickupCurrentClass()
	)
	if not item then
		chat.AddText(Color(220, 120, 80), "[TF2-Gamemode] Test item drop could not find a valid item definition.")
		return
	end

	NotificationQueue_Remove(function(notification)
		return notification.key == "tf_test_item_drop"
	end)

	TF2GM_ShowNewItemsNotification({item}, {
		method = method and method:GetInt() or 1,
	})
end

local function TF2GM_RunTestItemDropDirect()
	local defindex = GetConVar("tf_test_item_drop_defindex")
	local quality = GetConVar("tf_test_item_drop_quality")
	local className = GetConVar("tf_test_item_drop_class")
	local method = GetConVar("tf_test_item_drop_method")

	local item = tfItemPickupBuildTestItem(
		defindex and defindex:GetInt() or 13,
		quality and quality:GetString() or "unique",
		className and className:GetString() or tfItemPickupCurrentClass()
	)
	if not item then return end

	TF2GM_OpenItemPickupPanel({item}, {
		method = method and method:GetInt() or 1,
	})
end

CreateClientConVar("tf_test_item_drop_notice", "0", true, false, "Set to 1 to trigger a test new-item notification.")
CreateClientConVar("tf_test_item_drop_defindex", "13", true, false, "Defindex used for the test item drop notification.")
CreateClientConVar("tf_test_item_drop_quality", "unique", true, false, "Quality name used for the test item drop notification.")
CreateClientConVar("tf_test_item_drop_class", "scout", true, false, "Class name used to resolve the test item drop preview model.")
CreateClientConVar("tf_test_item_drop_method", "1", true, false, "Pickup method used for the test item drop screen.")

concommand.Add("tf_test_item_drop_notification", function()
	TF2GM_RunTestItemDrop()
end)

concommand.Add("tf_test_item_drop_screen", function()
	TF2GM_RunTestItemDropDirect()
end)

hook.Add("Think", "TF2GM_TestItemDropNotificationThink", function()
	local cv = GetConVar("tf_test_item_drop_notice")
	if not cv or not cv:GetBool() then return end
	RunConsoleCommand("tf_test_item_drop_notice", "0")
	TF2GM_RunTestItemDrop()
end)

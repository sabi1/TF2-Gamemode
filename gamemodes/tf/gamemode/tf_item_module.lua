	
local ExtraAttributesPending = {}
local month_name = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}

module("tf_item", package.seeall)

-----------------------------------
-- BASE ITEM SHARED FUNCTIONS

local function ItemVisualDebugEnabled()
	local c = GetConVar and GetConVar("tf_debug_item_visuals") or nil
	return c and c.GetBool and c:GetBool() or false
end

local function AttrValueForDebug(attList, className)
	if not istable(attList) then return nil end
	for _, a in ipairs(attList) do
		if istable(a) and a.attribute_class == className then
			return a.value
		end
	end
	return nil
end

local ITEM = {}

ITEM.IsTFItem = true

-- Should be called in ENT:Initialize on both client and server, should never be used on weapons, only on equippable SENTs
function ITEM:AddToPlayerItems()
	if not IsValid(self:GetOwner()) then return end
	
	if not self:GetOwner().PlayerItemList then
		self:GetOwner().PlayerItemList = {}
	end
	
	table.insert(self:GetOwner().PlayerItemList, self)
end

-- Should be called in ENT:OnRemove on both client and server, SENTs only
function ITEM:RemoveFromPlayerItems()
	if not IsValid(self:GetOwner()) then return end
	
	if not self:GetOwner().PlayerItemList then
		self:GetOwner().PlayerItemList = {}
	end
	
	for k,v in ipairs(self:GetOwner().PlayerItemList) do
		if self == v then
			table.remove(self:GetOwner().PlayerItemList, k)
			break
		end
	end
end

function ITEM:SetupDataTables()
	self:DTVar("Int", 0, "ItemID")
	if SERVER then self.dt.ItemID = -1 end
end

function ITEM:SetQuality(q)
	self:SetNWInt("Quality", q)
end

function ITEM:GetQuality()
	return self:GetNWInt("Quality")
end

function ITEM:SetLevel(l)
	self:SetNWInt("Level", l)
end

function ITEM:GetLevel()
	return self:GetNWInt("Level")
end

function ITEM:SetCustomName(n)
	self:SetNWString("CustomName", n)
end

function ITEM:GetCustomName()
	return self:GetNWString("CustomName")
end

function ITEM:SetCustomDescription(d)
	self:SetNWString("CustomDescription", d)
end

function ITEM:GetCustomDescription()
	return self:GetNWString("CustomDescription")
end

function ITEM:SetItemIndex(i)
	self.dt.ItemID = i
end

function ITEM:ItemIndex()
	return self.dt.ItemID or 0
end

function ITEM:GetItemData()
	local item = tf_items.ItemsByID[self:ItemIndex()]
	return item or {}
end

function ITEM:GetAttributes()
	return self.Attributes or self:GetItemData().attributes or {}
end

function ITEM:GetAttribute(class)
	for _,a in pairs(self.Attributes or self:GetItemData().attributes or {}) do
		if a.attribute_class == class then return a end
	end
end

function ITEM:GetAttributeValue(class, fallback)
	local att = self:GetAttribute(class)
	if not att then return fallback end
	if att.value == nil then return fallback end
	return att.value
end

function ITEM:IsAttributeEnabled(class)
	local att = self:GetAttribute(class)
	return att and att.value~=0
end

function ITEM:GetVisuals()
	return self:GetItemData().visuals or {}
end

local function GetSchemaAttributeValue(item, attributeClass)
	if not istable(item) or not isstring(attributeClass) or attributeClass == "" then return nil end

	local attrs = item.attributes_by_id or item.attributes
	if not istable(attrs) then return nil end

	for _, attr in pairs(attrs) do
		if istable(attr) and attr.attribute_class == attributeClass and attr.value ~= nil then
			return tonumber(attr.value) or attr.value
		end
	end

	return nil
end

function ITEM:GetVisionFilterFlags()
	return tonumber(self:GetItemData().vision_filter_flags) or 0
end

function ITEM:GetVisionOptInFlags()
	local flags = tonumber(self:GetAttributeValue("vision_opt_in_flags", 0)) or 0
	if flags ~= 0 then
		return flags
	end

	return tonumber(GetSchemaAttributeValue(self:GetItemData(), "vision_opt_in_flags")) or 0
end

function ITEM:IsHiddenByVision(viewer)
	local itemFlags = tonumber(self:GetVisionFilterFlags()) or 0
	if itemFlags == 0 then return false end

	local viewerFlags = TF2_GetVisionFilterFlags and TF2_GetVisionFilterFlags(viewer) or 0
	return bit.band(itemFlags, viewerFlags) == 0
end

function ITEM:GetVisionFilteredModel(viewer)
	local item = self:GetItemData()
	if not istable(item) then return nil end
	if not isstring(item.model_vision_filtered) or item.model_vision_filtered == "" then return nil end

	local viewerFlags = TF2_GetVisionFilterFlags and TF2_GetVisionFilterFlags(viewer) or 0
	if bit.band(viewerFlags, TF_VISION_FILTER_PYRO or 0x01) == 0 then return nil end

	local model = item.model_vision_filtered
	if IsValid(self.Owner) and self.Owner.GetPlayerClass then
		model = string.Replace(model, "%s", self.Owner:GetPlayerClass())
	end
	return string.Replace(model, "demoman", "demo")
end

function ITEM:GetEffectiveDisplayModel(viewer, fallbackModel)
	if self:IsHiddenByVision(viewer) then
		return nil
	end

	return self:GetVisionFilteredModel(viewer) or fallbackModel
end

function ITEM:GetPaintkitID()
	return tonumber(self:GetAttributeValue("paintkit_proto_def_index", self:GetItemData().static_attrs and self:GetItemData().static_attrs.paintkit_proto_def_index))
end

local PaintkitDisplayNameByID = nil

local function IsGenericPaintkitName(name, id)
	if not isstring(name) then return true end
	local n = string.Trim(name)
	if n == "" then return true end
	local l = string.lower(n)
	if l == "paintkit" then return true end
	if tonumber(id) and l == ("paintkit " .. tostring(tonumber(id))) then
		return true
	end
	return false
end

local function GetLocalizedTokenIfAny(token)
	if not isstring(token) or token == "" then return nil end
	if not tf_lang or not tf_lang.GetRaw then return nil end
	local resolved = tf_lang.GetRaw(token)
	if not isstring(resolved) or resolved == "" then return nil end
	if string.sub(token, 1, 1) == "#" and string.sub(resolved, 1, 1) == "#" then
		return nil
	end
	return resolved
end

local function BuildPaintkitDisplayNameLookup()
	local byID = {}

	local function maybeSet(protoID, candidate)
		local id = tonumber(protoID)
		if not id then return end
		if not isstring(candidate) then return end
		local value = string.Trim(candidate)
		if value == "" then return end

		local current = byID[id]
		if current == nil or IsGenericPaintkitName(current, id) then
			byID[id] = value
		end
	end

	for _, item in pairs(tf_items.ItemsByID or {}) do
		if istable(item) and istable(item.static_attrs) then
			local proto = tonumber(item.static_attrs.paintkit_proto_def_index)
			if proto then
				maybeSet(proto, GetLocalizedTokenIfAny(item.item_name))
				maybeSet(proto, item.name)
			end
		end
	end

	for prefabName, prefab in pairs(tf_items.PrefabsByName or {}) do
		if isstring(prefabName) then
			local proto = tonumber(string.match(prefabName, "^paintkit_(%d+)$"))
			if proto and istable(prefab) then
				maybeSet(proto, GetLocalizedTokenIfAny(prefab.item_name))
				maybeSet(proto, prefab.name)
			end
		end
	end

	return byID
end

local function GetPaintkitDisplayNameByID(id)
	local proto = tonumber(id)
	if not proto then return nil end
	if not PaintkitDisplayNameByID then
		PaintkitDisplayNameByID = BuildPaintkitDisplayNameLookup()
	end

	local name = PaintkitDisplayNameByID[proto]
	if isstring(name) and name ~= "" then
		return name
	end
	return "Paintkit " .. tostring(proto)
end

function ITEM:GetPaintkitDisplayName()
	local id = self:GetPaintkitID()
	if not id then return nil end
	return GetPaintkitDisplayNameByID(id)
end

function GetPaintkitDisplayNameForItemData(itemData, properties)
	local id = nil
	if istable(properties) and istable(properties.attributes) then
		for _, att in ipairs(properties.attributes) do
			if istable(att) then
				local rawID = tonumber(att.id or att.attribute_id or att.defindex or att[1])
				if rawID == 834 then
					id = tonumber(att.value or att[2])
					break
				end
			end
		end
	end
	if not id then
		id = tonumber(itemData and itemData.static_attrs and itemData.static_attrs.paintkit_proto_def_index)
	end
	if not id then return nil end
	return GetPaintkitDisplayNameByID(id)
end

function ITEM:GetTextureWear()
	local wear = self:GetAttributeValue("set_item_texture_wear", nil)
	if wear == nil then
		wear = self:GetAttributeValue("texture_wear_default", self:GetItemData().static_attrs and self:GetItemData().static_attrs.texture_wear_default)
	end
	return tonumber(wear)
end

function ITEM:IsFestivized()
	return (tonumber(self:GetAttributeValue("is_festivized", 0)) or 0) > 0
end

local WEAR_SUFFIXES = {
	"_factory_new",
	"_minimal_wear",
	"_field_tested",
	"_feild_tested",
	"_well_worn",
	"_battle_scarred",
}

local function GetPaintkitClassFromItem(item)
	if not istable(item) then return nil end
	local prefab = item.prefab
	if isstring(prefab) and prefab ~= "" then
		local paintkitPrefab = string.match(prefab, "(paintkit_weapon_[%w_]+)")
		if paintkitPrefab then
			if tf_items.PrefabsByName and tf_items.PrefabsByName[paintkitPrefab] then
				local map = tf_items.PrefabsByName[paintkitPrefab].xifier_class_remap
				if isstring(map) and map ~= "" then
					return map
				end
			end
			local fromPrefab = string.gsub(paintkitPrefab, "^paintkit_weapon_", "")
			if fromPrefab == "shotgun" then
				return "weapon_shotgun"
			end
			return fromPrefab
		end
	end

	if isstring(item.item_class) and item.item_class ~= "" then
		local cls = string.gsub(item.item_class, "^tf_weapon_", "")
		if cls == "shotgun_multiclass" then
			return "weapon_shotgun"
		end
		return cls
	end
end

local function BuildPaintkitVisualLookup()
	local byProto = {}
	for _, item in pairs(tf_items.ItemsByID or {}) do
		if istable(item) and istable(item.static_attrs) then
			local proto = tonumber(item.static_attrs.paintkit_proto_def_index)
			if proto then
				local paintkitClass = GetPaintkitClassFromItem(item)
				if paintkitClass then
					byProto[proto] = byProto[proto] or {}
					local visuals = item.visuals or {}
					local current = byProto[proto][paintkitClass] or {}

					if isstring(visuals.material_override) and visuals.material_override ~= "" then
						current.material_override = visuals.material_override
					end
					if isstring(visuals.image_inventory) and visuals.image_inventory ~= "" then
						current.image_inventory = visuals.image_inventory
					elseif isstring(item.image_inventory) and item.image_inventory ~= "" then
						current.image_inventory = item.image_inventory
					end
					if istable(visuals.attached_models_festive) then
						current.attached_models_festive = visuals.attached_models_festive
					end

					byProto[proto][paintkitClass] = current
				end
			end
		end
	end
	return byProto
end

local PaintkitVisualLookup = nil

local function GetAttributeValueFromPropertyTable(properties, class, fallback)
	if not istable(properties) then return fallback end

	local attrs = properties.attributes
	if not istable(attrs) then return fallback end

	for _, att in ipairs(attrs) do
		if istable(att) then
			if att.attribute_class == class then
				return att.value ~= nil and att.value or fallback
			end

			local id = tonumber(att.id or att.attribute_id or att.defindex)
			local def = id and tf_items and tf_items.AttributesByID and tf_items.AttributesByID[id] or nil
			if def and def.attribute_class == class then
				return att.value ~= nil and att.value or fallback
			end
		end
	end

	return fallback
end

function ITEM:GetResolvedPaintkitVisuals()
	local paintkitID = self:GetPaintkitID()
	if not paintkitID then return nil end
	if not PaintkitVisualLookup then
		PaintkitVisualLookup = BuildPaintkitVisualLookup()
	end

	local defs = PaintkitVisualLookup[paintkitID]
	if not defs then return nil end

	local itemClass = GetPaintkitClassFromItem(self:GetItemData())
	if itemClass and defs[itemClass] then
		return defs[itemClass]
	end

	if isstring(self:GetClass()) then
		local classFromSWEP = string.gsub(self:GetClass(), "^tf_weapon_", "")
		if defs[classFromSWEP] then
			return defs[classFromSWEP]
		end
	end

	for _, def in pairs(defs) do
		return def
	end
end

function ResolvePaintkitVisualsForData(itemData, properties)
	local paintkitID = tonumber(GetAttributeValueFromPropertyTable(properties, "paintkit_proto_def_index", itemData and itemData.static_attrs and itemData.static_attrs.paintkit_proto_def_index))
	if not paintkitID then return nil end
	if not PaintkitVisualLookup then
		PaintkitVisualLookup = BuildPaintkitVisualLookup()
	end

	local defs = PaintkitVisualLookup[paintkitID]
	if not defs then return nil end

	local itemClass = GetPaintkitClassFromItem(itemData)
	if itemClass and defs[itemClass] then
		return defs[itemClass]
	end

	for _, def in pairs(defs) do
		return def
	end
end

local function ResolvePaintkitMaterialPath(baseMaterial, owner, wearValue)
	if not isstring(baseMaterial) or baseMaterial == "" then return nil end
	if string.find(baseMaterial, "_factory_new", 1, true)
		or string.find(baseMaterial, "_minimal_wear", 1, true)
		or string.find(baseMaterial, "_field_tested", 1, true)
		or string.find(baseMaterial, "_feild_tested", 1, true)
		or string.find(baseMaterial, "_well_worn", 1, true)
		or string.find(baseMaterial, "_battle_scarred", 1, true) then
		return baseMaterial
	end

	local teamSuffix = "_red"
	if IsValid(owner) and owner.EntityTeam and (owner:EntityTeam() == TEAM_BLU or owner:EntityTeam() == TF_TEAM_PVE_INVADERS) then
		teamSuffix = "_blue"
	end

	local wearSuffix = nil
	if wearValue ~= nil then
		local wearIndex = math.Clamp(math.floor((tonumber(wearValue) or 0) * 5), 0, 4) + 1
		wearSuffix = WEAR_SUFFIXES[wearIndex]
	end

	if wearSuffix then
		return baseMaterial .. wearSuffix .. teamSuffix
	end
	return baseMaterial .. teamSuffix
end

local function ValidateMaterialOverridePath(candidate, fallbackBase)
	if not CLIENT then
		return candidate
	end
	if not isstring(candidate) or candidate == "" then
		return nil
	end
	local mat = Material(candidate)
	if mat and not mat:IsError() then
		return candidate
	end
	if isstring(fallbackBase) and fallbackBase ~= "" then
		local fallback = Material(fallbackBase)
		if fallback and not fallback:IsError() then
			return fallbackBase
		end
	end
	return nil
end

if CLIENT then
	local ProtoPaintkitApprox = {
		[279] = {
			layers = {
				"patterns/workshop/smissmas_2020/1558054217/1558054217_a",
				"patterns/workshop/smissmas_2020/1558054217/1558054217_c",
				"patterns/workshop/smissmas_2020/1558054217/1558054217_b",
			},
			layer1Scale = "2.5",
			weapons = {
				scattergun = {
					albedo = "models/weapons/c_models/c_scattergun/p_scattergun_albedo",
				},
			},
		},
	}

	local ProtoPaintkitMaterialCache = {}

	local function CreateApproxProtoPaintkitMaterial(paintkitID, itemClass)
		local paintkit = ProtoPaintkitApprox[paintkitID]
		local weapon = paintkit and paintkit.weapons and paintkit.weapons[itemClass] or nil
		if not weapon or not isstring(weapon.albedo) or weapon.albedo == "" then return nil end

		local key = tostring(paintkitID) .. ":" .. tostring(itemClass)
		if ProtoPaintkitMaterialCache[key] then
			return ProtoPaintkitMaterialCache[key]
		end

		local name = "tf2_warpaint_" .. tostring(paintkitID) .. "_" .. tostring(itemClass)
		CreateMaterial(name, "VertexLitGeneric", {
			["$basetexture"] = weapon.albedo,
			["$detail"] = paintkit.layers[1],
			["$detailscale"] = paintkit.layer1Scale or "1",
			["$detailblendfactor"] = "1",
			["$detailblendmode"] = "0",
			["$model"] = "1",
			["$vertexcolor"] = "1",
			["$vertexalpha"] = "1",
			["$phong"] = "1",
			["$phongboost"] = "0.15",
		})

		ProtoPaintkitMaterialCache[key] = name
		return name
	end

	function ResolveMaterialOverrideForItemData(itemData, properties, owner)
		local visuals = ResolvePaintkitVisualsForData(itemData, properties)
		local materialSource = visuals and visuals.material_override or nil
		if isstring(materialSource) and materialSource ~= "" then
			local materialBase = string.match(materialSource, "(.-)%.vmt") or materialSource
			local wear = GetAttributeValueFromPropertyTable(properties, "set_item_texture_wear", itemData and itemData.static_attrs and itemData.static_attrs.texture_wear_default)
			local resolved = ResolvePaintkitMaterialPath(materialBase, owner, wear) or materialBase
			return ValidateMaterialOverridePath(resolved, materialBase)
		end

		return nil
	end
end

function ITEM:GetKillIconName()
	local d = self:GetItemData()
	if d.item_iconname then
		return d.item_iconname
	else
		return self:GetClass()
	end
end

function ITEM:FindItemSet()
	local name = self:GetItemData().name
	if not name then return end
	
	for k,v in pairs(tf_items.ItemSets) do
		for _,n in ipairs(v.items or {}) do
			if n == name then
				return v
			end
		end
	end
end

function ITEM:CheckUpdateItem()
	local id = self:ItemIndex()
	if id>-1 and id~=self.CurrentItemID then
		local item = tf_items.ItemsByID[id]
		if item then
			----MsgN(Format("SetupItem [%d] %s", id, tostring(self)))
			self:SetupItem(tf_items.ItemsByID[id])
		else
			----MsgN(Format("WARNING: From '%s': Item #%d not found!", self:GetClass(), id))
		end
		self.CurrentItemID = id
	end
end

function ITEM:SendExtraAttributes(pl)
	if SERVER and self.ExtraAttributes then
		umsg.Start("TF_SetExtraAttributes", pl)
			--umsg.Entity(self)
			umsg.Long(self:EntIndex())
			umsg.Char(#self.ExtraAttributes)
			for _,v in ipairs(self.ExtraAttributes) do
				umsg.Short(v.id)
				umsg.Float(v.value)
			end
		umsg.End()
	end
end

local function ExtraAttributesInputEqual(a, b)
	if not istable(a) or not istable(b) then return false end
	if #a ~= #b then return false end
	for i = 1, #a do
		local av = a[i]
		local bv = b[i]
		if not istable(av) or not istable(bv) then return false end
		if tonumber(av[1]) ~= tonumber(bv[1]) then return false end
		if tonumber(av[2]) ~= tonumber(bv[2]) then return false end
	end
	return true
end

function ITEM:SetExtraAttributes(att)
	if not istable(att) then return end
	if self._ApplyingExtraAttributes then return end
	if istable(self.ExtraAttributesTable) and ExtraAttributesInputEqual(self.ExtraAttributesTable, att) then
		return
	end

	self._ApplyingExtraAttributes = true
	self.ExtraAttributes = {}
	
	for _,v in ipairs(att) do
		local a = tf_items.AttributesByID[v[1]]
		
		if a then
			table.insert(self.ExtraAttributes, {
				id = v[1],
				name = a.name,
				attribute_class = a.attribute_class,
				value = v[2],
			})
		end
	end
	
	if #self.ExtraAttributes == 0 then
		self._ApplyingExtraAttributes = nil
		return
	end
	
	self.ExtraAttributesTable = table.Copy(att)
	
	self:SendExtraAttributes()
	
	if self.Attributes then
		table.Add(self.Attributes, self.ExtraAttributes)
		--self.ExtraAttributes = nil
		ApplyAttributes(self.ExtraAttributes, "equip", self, self.Owner)
	end

	if ItemVisualDebugEnabled() then
		local paintkit = AttrValueForDebug(self.ExtraAttributes, "paintkit_proto_def_index")
		local wear = AttrValueForDebug(self.ExtraAttributes, "set_item_texture_wear")
		local festive = AttrValueForDebug(self.ExtraAttributes, "is_festivized")
		print(string.format(
			"[tf_debug_item_visuals] SetExtraAttributes ent=%d class=%s item=%s attrs=%d paintkit=%s wear=%s festive=%s",
			self:EntIndex(),
			tostring(self.GetClass and self:GetClass() or "nil"),
			tostring(self.GetItemData and self:GetItemData() and self:GetItemData().name or "nil"),
			#self.ExtraAttributes,
			tostring(paintkit),
			tostring(wear),
			tostring(festive)
		))
	end

	-- Extra attrs from Steam inventory (paintkit/festivized/etc.) can arrive after
	-- initial item setup on client. Re-apply visuals so model/material overrides update.
	if self.CheckUpdateItem and not self._InSetupItem then
		self:CheckUpdateItem()
	end
	if self.InitVisuals and IsValid(self.Owner) then
		local itemData = self:GetItemData()
		if istable(itemData) then
			local visuals
			if self.Owner:EntityTeam() == TEAM_BLU or self.Owner:EntityTeam() == TF_TEAM_PVE_INVADERS then
				visuals = itemData.visuals_blu or itemData.visuals
			else
				visuals = itemData.visuals_red or itemData.visuals
			end
			self:InitVisuals(self.Owner, visuals)
			if CLIENT and self.InitializeAttachedModels then
				self:InitializeAttachedModels()
			end
		end
	end
	
	if CLIENT then
		self.FormattedAttributes = nil
		if (IsValid(self.Owner:GetActiveWeapon())) then 
			if not self:IsWeapon() or self==self.Owner:GetActiveWeapon() then
				self:ResetParticles()
			end
		end
	end
	self._ApplyingExtraAttributes = nil
end

function ITEM:OnEquipAttribute(att, owner)
	
end

function ITEM:InitAttributes(owner, attributes)
	--MsgFN("InitAttributes (%s) %s",tostring(self),tostring(owner))
	
	if not attributes then
		self.Attributes = {}
	else
		self.Attributes = table.Copy(attributes)
	end
	
	if self.ExtraAttributes then
		table.Add(self.Attributes, self.ExtraAttributes)
	end
	
	ApplyAttributes(self.Attributes, "equip", self, owner)
	
	if CLIENT then
		HudInspectPanel:Update()
		self.FormattedAttributes = nil
		if (IsValid(self.Owner:GetActiveWeapon())) then
			if not self:IsWeapon() or self==self.Owner:GetActiveWeapon() then
				self:ResetParticles()
			end
		end
	end
end

function ITEM:InitVisuals(owner, visuals)
	--MsgFN("InitVisuals (%s) %s",tostring(self),tostring(owner))
	visuals = visuals or {}
	
	if not IsValid(self) then return end
	if not isfunction(self.GetItemData) then return end
	if not self:GetItemData() then return end
	-- Skin and material
	self.WeaponSkin = visuals.skin

	-- Some weapon variants only expose team skins through visuals.styles.
	local styles = visuals.styles
	if istable(styles) then
		local style = styles[0] or styles["0"]
		if not istable(style) then
			for _, candidate in pairs(styles) do
				if istable(candidate) then
					style = candidate
					break
				end
			end
		end

		if istable(style) then
			local team = IsValid(owner) and owner.EntityTeam and owner:EntityTeam() or nil
			if team == TEAM_BLU or team == TF_TEAM_PVE_INVADERS then
				self.WeaponSkin = style.skin_blu or style.skin_blue or style.skin or self.WeaponSkin
			else
				self.WeaponSkin = style.skin_red or style.skin or self.WeaponSkin
			end
			if isstring(style.image_inventory) and style.image_inventory ~= "" then
				self.RuntimeImageInventory = style.image_inventory
			end
		end
	end

	if not self.WeaponSkin then
		if self.HasTeamColouredVModel or not self:IsWeapon() then
			self.WeaponSkin = (((owner:EntityTeam() == TEAM_BLU or owner:EntityTeam() == TF_TEAM_PVE_INVADERS) and 1) or 0)
		else
			self.WeaponSkin = 0
		end
	end

	local paintkitVisuals = self:GetResolvedPaintkitVisuals()
	local materialSource = visuals.material_override
	if (not isstring(materialSource) or materialSource == "") and paintkitVisuals and isstring(paintkitVisuals.material_override) then
		materialSource = paintkitVisuals.material_override
	end
	if isstring(materialSource) and materialSource ~= "" then
		local materialBase = string.match(materialSource, "(.-)%.vmt") or materialSource
		local resolved = ResolvePaintkitMaterialPath(materialBase, owner, self:GetTextureWear()) or materialBase
		resolved = ValidateMaterialOverridePath(resolved, materialBase)
		self.MaterialOverride = resolved
		self.WeaponMaterial = resolved
		self.CustomMaterialOverride2 = resolved
		if CLIENT and resolved and resolved ~= "" then
			self.CustomMaterialOverride = Material(resolved)
		end
	elseif CLIENT and ResolveMaterialOverrideForItemData then
		local resolved = ResolveMaterialOverrideForItemData(self:GetItemData(), {
			attributes = self:GetAttributes(),
		}, owner)
		if isstring(resolved) and resolved ~= "" then
			self.MaterialOverride = resolved
			self.WeaponMaterial = resolved
			self.CustomMaterialOverride2 = resolved
			self.CustomMaterialOverride = Material(resolved)
		end
	end

	if (not self.RuntimeImageInventory or self.RuntimeImageInventory == "") and paintkitVisuals and isstring(paintkitVisuals.image_inventory) and paintkitVisuals.image_inventory ~= "" then
		self.RuntimeImageInventory = paintkitVisuals.image_inventory
	end
	
	if self:IsWeapon() then
		self:SetSkin(self.WeaponSkin)
		if IsValid(owner) and IsValid(owner:GetViewModel()) then
			owner:GetViewModel():SetSkin(self.WeaponSkin)
		end
	end
	
	--self:SetMaterial(self.MaterialOverride)
	if self:IsWeapon() then
		if IsValid(owner) and IsValid(owner:GetViewModel()) then
			--owner:GetViewModel():SetMaterial(self.MaterialOvveride)
		end
	end
	
	-- Attached models
	if CLIENT then
		if visuals.attached_model_world and visuals.attached_model_world.model then
			self.AttachedWorldModel = visuals.attached_model_world.model
		elseif visuals.attached_model and visuals.attached_model.model then
			self.AttachedWorldModel = visuals.attached_model.model
		end
		
		if visuals.attached_model_view and visuals.attached_model_view.model then
			self.AttachedViewModel = visuals.attached_model_view.model
		elseif visuals.attached_model and visuals.attached_model.model then
			self.AttachedViewModel = visuals.attached_model.model
		end

		-- Festivized weapons use a dedicated attached model payload in schema.
		local festiveModels = visuals.attached_models_festive
		if (not istable(festiveModels)) and paintkitVisuals and istable(paintkitVisuals.attached_models_festive) then
			festiveModels = paintkitVisuals.attached_models_festive
		end
		if self:IsFestivized() and istable(festiveModels) then
			local function extractFestiveModelFromEntry(entry, wantView)
				if not istable(entry) then return nil end
				local keys = wantView and {
					"view_model",
					"model_view",
					"attached_model_view",
					"model",
				} or {
					"world_model",
					"model_world",
					"attached_model_world",
					"model",
				}
				for _, key in ipairs(keys) do
					local v = entry[key]
					if istable(v) then
						v = v.model or v.view_model or v.world_model
					end
					if isstring(v) and v ~= "" then
						return v
					end
				end
				return nil
			end

			local function resolveFestiveModel(wantView)
				local first = festiveModels[0] or festiveModels["0"]
				local resolved = extractFestiveModelFromEntry(first, wantView)
				if resolved then return resolved end

				resolved = extractFestiveModelFromEntry(festiveModels, wantView)
				if resolved then return resolved end

				for _, candidate in ipairs(festiveModels) do
					resolved = extractFestiveModelFromEntry(candidate, wantView)
					if resolved then return resolved end
				end

				for _, candidate in pairs(festiveModels) do
					resolved = extractFestiveModelFromEntry(candidate, wantView)
					if resolved then return resolved end
				end

				return nil
			end

			local festiveWorld = resolveFestiveModel(false)
			local festiveView = resolveFestiveModel(true)
			if isstring(festiveWorld) and festiveWorld ~= "" then
				self.AttachedWorldModel = festiveWorld
			end
			if isstring(festiveView) and festiveView ~= "" then
				self.AttachedViewModel = festiveView
			end
		end
	end

	if ItemVisualDebugEnabled() then
		print(string.format(
			"[tf_debug_item_visuals] InitVisuals ent=%d class=%s item=%s paintkit=%s wear=%s festive=%s skin=%s mat=%s awm=%s avm=%s",
			self:EntIndex(),
			tostring(self.GetClass and self:GetClass() or "nil"),
			tostring(self:GetItemData() and self:GetItemData().name or "nil"),
			tostring(self:GetPaintkitID()),
			tostring(self:GetTextureWear()),
			tostring(self:IsFestivized()),
			tostring(self.WeaponSkin),
			tostring(self.CustomMaterialOverride2 or self.MaterialOverride or self.WeaponMaterial or ""),
			tostring(self.AttachedWorldModel or ""),
			tostring(self.AttachedViewModel or "")
		))
	end
	
	-- Bodygroups
	--[[
	if not self:GetItemData().hide_bodygroups_deployed_only then
		if visuals.player_bodygroups then
			for _,group in ipairs(visuals.player_bodygroups) do
				--MsgFN("Setting bodygroup '%s' for player %s", group, tostring(owner))
				local b = PlayerNamedBodygroups[owner:GetPlayerClass()]
				if (visuals.player_bodygroups.hat) then
					owner:SetBodygroup(owner:FindBodygroupByName("hat"), 1)
				end
				if b and b[group] then
					owner:SetBodygroup(b[group], 1)
				end
				
				b = PlayerNamedViewmodelBodygroups[owner:GetPlayerClass()]
				if b and b[group] then
					if IsValid(owner:GetViewModel()) then
						owner:GetViewModel():SetBodygroup(b[group], 1)
					end
				end
			end
		end
	end]]
	
	
	-- Muzzles, tracers, sound effects
	for k,v in pairs(visuals) do
		if k=="muzzle_flash" then
			self.MuzzleEffect = v
			PrecacheParticleSystem(v)
		elseif k=="tracer_effect" then
			self.TracerEffect = v
			PrecacheParticleSystem(v.."_red")
			PrecacheParticleSystem(v.."_blue")
			PrecacheParticleSystem(v.."_red_crit")
			PrecacheParticleSystem(v.."_blue_crit")
		--elseif string.find(k, "sound") then
		--	self:ModifySound(k, v)
		end
	end
	
	if self.CreateSounds then
		self:CreateSounds(owner)
	end
	
	-- Thirdperson animations
	if visuals.animations then
		for act,rep in pairs(visuals.animations) do
			if debug.getregistry()[act] and self.ActivityTranslate[debug.getregistry()[act]] then
				self.ActivityTranslate[debug.getregistry()[act]] = debug.getregistry()[rep]
			end
		end
	end
end

if CLIENT then
	local WEAR_SUFFIXES = {
		"_factory_new",
		"_minimal_wear",
		"_field_tested",
		"_feild_tested",
		"_well_worn",
		"_battle_scarred",
	}

	local function MaterialPathExists(path)
		if not isstring(path) or path == "" then return false end
		local mat = Material(path)
		return mat and not mat:IsError()
	end

	function ResolveInventoryImageForItemData(itemData, properties)
		local visuals = ResolvePaintkitVisualsForData(itemData, properties)
		local base = (visuals and visuals.image_inventory) or (itemData and itemData.image_inventory) or nil
		local candidates = {}
		if isstring(base) and base ~= "" then
			candidates[#candidates + 1] = base
		end

		local paintkitID = tonumber(GetAttributeValueFromPropertyTable(properties, "paintkit_proto_def_index", itemData and itemData.static_attrs and itemData.static_attrs.paintkit_proto_def_index))
		local remappedDef = tonumber(itemData and (itemData.remapped_item_def_index or itemData.remapped_defindex or itemData.remap_item_def_index))
		if not remappedDef then
			remappedDef = tonumber(itemData and itemData.id)
		end
		local wear = tonumber(GetAttributeValueFromPropertyTable(properties, "set_item_texture_wear", itemData and itemData.static_attrs and itemData.static_attrs.texture_wear_default))
		local wearCategory = math.Clamp(math.floor((wear or 0) * 5), 0, 4)

		local isFestivized = tonumber(GetAttributeValueFromPropertyTable(properties, "is_festivized", 0)) or 0
		if paintkitID and remappedDef then
			local festiveSuffix = isFestivized > 0 and "_festive" or ""
			candidates[#candidates + 1] = string.format("backpack/generated/paintkit%d_item%d_wear%d%s", paintkitID, remappedDef, wearCategory, festiveSuffix)
			candidates[#candidates + 1] = string.format("paintkit%d_item%d_wear%d%s", paintkitID, remappedDef, wearCategory, festiveSuffix)
		end

		if isFestivized > 0 and isstring(base) and base ~= "" then
			candidates[#candidates + 1] = base .. "_xmas"
			candidates[#candidates + 1] = base .. "_festive"
			candidates[#candidates + 1] = base .. "_festivized"
		end

		if wear ~= nil and isstring(base) and base ~= "" then
			local wearIndex = math.Clamp(math.floor((wear * 5)), 0, 4) + 1
			local wearSuffix = WEAR_SUFFIXES[wearIndex]
			if wearSuffix then
				candidates[#candidates + 1] = base .. wearSuffix
			end
		end

		for _, candidate in ipairs(candidates) do
			if MaterialPathExists(candidate) then
				return candidate
			end
		end

		return (isstring(base) and base ~= "") and base or nil
	end

	function ITEM:GetResolvedInventoryImage()
		local item = self:GetItemData() or {}
		local resolved = ResolveInventoryImageForItemData(item, { attributes = self.ExtraAttributes or {} })
		if isstring(resolved) and resolved ~= "" then
			return resolved
		end

		local base = self.RuntimeImageInventory or item.image_inventory
		if isstring(base) and base ~= "" then
			return base
		end
		return nil
	end
end

function GlobalApplyBodygroups(ent, owner, itemdata)
	if not itemdata.hide_bodygroups_deployed_only then
		local visuals = itemdata.visuals or {}

		local function applyGroup(groupName, value)
			if not isstring(groupName) or groupName == "" then return end

			local idx
			local named = PlayerNamedBodygroups[owner:GetPlayerClass()]
			if named and named[groupName] then
				idx = named[groupName]
			elseif ent.FindBodygroupByName then
				idx = ent:FindBodygroupByName(groupName)
			end

			if idx and idx >= 0 then
				ent:SetBodygroup(idx, value or 1)
			end
		end

		if visuals.player_bodygroups then
			for _,group in ipairs(visuals.player_bodygroups) do
				applyGroup(group, 1)
			end
			for group, value in pairs(visuals.player_bodygroups) do
				if isstring(group) then
					applyGroup(group, tonumber(value) or 1)
				end
			end
		end

		if istable(visuals.hide_player_bodygroup_names) then
			for _,group in ipairs(visuals.hide_player_bodygroup_names) do
				applyGroup(group, 1)
			end
		end

		if istable(visuals.show_player_bodygroup_names) then
			for _,group in ipairs(visuals.show_player_bodygroup_names) do
				applyGroup(group, 0)
			end
		end

		if ent:IsPlayer() then
			local b = PlayerNamedViewmodelBodygroups[owner:GetPlayerClass()]
			if b and visuals.player_bodygroups then
				for _,group in ipairs(visuals.player_bodygroups) do
					if b[group] and IsValid(ent:GetViewModel()) then
						ent:GetViewModel():SetBodygroup(b[group], 1)
					end
				end
			end
		end
	end
end

function ITEM:ApplyPlayerBodygroups(ent)
	GlobalApplyBodygroups(ent or self.Owner, self.Owner, self:GetItemData())
end

function ITEM:InitProjectileAttributes(proj)
	proj.Attributes = self:GetAttributes()
	ApplyAttributesFromEntity(self, "projectile_fired", proj, self, self.Owner)
end

local function ResolveHandsViewModelForOwner(owner)
	if not IsValid(owner) then return nil end

	local tried = {}
	local function tryClassName(className)
		if not isstring(className) or className == "" then return nil end
		if className == "demoman" then
			className = "demo"
		end
		if tried[className] then return nil end
		tried[className] = true

		local mdl = Format("models/weapons/c_models/c_%s_arms.mdl", className)
		if file.Exists(mdl, "GAME") then
			return mdl
		end
		return nil
	end

	local classTbl = owner.GetPlayerClassTable and owner:GetPlayerClassTable() or nil
	local className = owner.GetPlayerClass and owner:GetPlayerClass() or nil

	return
		tryClassName(classTbl and classTbl.ModelName) or
		tryClassName(className) or
		tryClassName("soldier") or
		tryClassName("demo") or
		tryClassName("heavy") or
		"models/weapons/c_models/c_sniper_arms.mdl"
end

function ITEM:SetupItem(item)
	self._InSetupItem = true
	if istable(item) then
		if isstring(item.model_player) and item.model_player ~= "" then
			util.PrecacheModel(item.model_player)
		end
		if isstring(item.model_world) and item.model_world ~= "" then
			util.PrecacheModel(item.model_world)
		end
	end

	if SERVER then
		if self:IsWeapon() and self.SetupCModelActivities then
			if item.attach_to_hands==1 then
				local handsViewModel = ResolveHandsViewModelForOwner(self.Owner)
				if handsViewModel then
					self.ViewModelOverride = handsViewModel
					self.ViewModel = self.ViewModelOverride
					self:SetModel(self.ViewModelOverride)
					if IsValid(self.Owner:GetViewModel()) then
						self.Owner:GetViewModel():SetModel(self.ViewModelOverride)
					end
					self:SetupCModelActivities(item)
				end
			else
				self:SetupCModelActivities()
				self.ViewModelOverride = nil
			end
		end
	else
		local pendingAttrs = ExtraAttributesPending[self:EntIndex()]
		if pendingAttrs then
			--MsgFN("Processing extra attributes for pending item %s", tostring(self))
			ExtraAttributesPending[self:EntIndex()] = nil
			self:SetExtraAttributes(pendingAttrs)
			
			if self:IsWeapon() and self == self.Owner:GetActiveWeapon() then
				HudInspectPanel:Update()
			end
		end
		
		self:InitAttributes(self.Owner, item.attributes_by_id)
		
		if self.Owner:EntityTeam() == TEAM_BLU then
			self:InitVisuals(self.Owner, item.visuals_blu or item.visuals)
		else
			self:InitVisuals(self.Owner, item.visuals_red or item.visuals)
		end
		
		if self:IsWeapon() and self.SetupCModelActivities then
			if item.attach_to_hands==1 then
				local handsViewModel = ResolveHandsViewModelForOwner(self.Owner)
				if handsViewModel then
					self.ViewModelOverride = handsViewModel
					self:SetModel(self.ViewModelOverride)
					self:SetupCModelActivities(item)
				end
				
				if item.model_player then
					self.HasCModel = true
					self.WorldModelOverride = item.model_player
				end
			else
				self:SetupCModelActivities()
				self.HasCModel = false
				
				-- won't be using the original worldmodel anymore, since it tends to randomly disappear when the player is near NPCs
				if self.WorldModel ~= "" then
					self.WorldModelOverride = self.WorldModel
				end
			end
			
			self.WorldModelOverride2 = item.model_world
		
			-- todo: optimize clientside models, certainly don't need to create up to 4 clientside entities for each weapon
			--self:InitializeCModel()
			self:InitializeWModel2()
			self:InitializeAttachedModels()
		end
	end
	self._InSetupItem = nil
end

-----------------------------------
-- BASE ITEM CLIENTSIDE FUNCTIONS
 
if CLIENT then

function ITEM:ClearParticles()
	self:StopParticles()
	if IsValid(self.RootLocator) then self.RootLocator:StopParticles() end
	
	if self:IsWeapon() then
		if IsValid(self.Owner) and IsValid(self.Owner:GetViewModel()) then
			self.Owner:GetViewModel():StopParticles()
			if IsValid(self.Owner:GetViewModel().RootLocator) then self.Owner:GetViewModel().RootLocator:StopParticles() end
		end
		
		if IsValid(self.WModel2) then
			--self.WModel2:StopParticles()
			if IsValid(self.WModel2.RootLocator) then self.WModel2.RootLocator:StopParticles() end
		end
		
		if IsValid(self.CModel) then
			self.CModel:StopParticles()
			if IsValid(self.CModel.RootLocator) then self.CModel.RootLocator:StopParticles() end
		end
	end
end

local function UpdateRootLocator(self)
	if IsValid(self.RootLocator) then
		local mat = self:GetBoneMatrix(0)
		if mat then
			self.RootLocator:SetPos(mat:GetTranslation())
			self.RootLocator:SetAngles(mat:GetAngles())
		end
	end
end

local function ParticleEffectAttachToRoot(system, ent)
	if not IsValid(ent.RootLocator) then
		ent.RootLocator = ClientsideModel("models/props_junk/watermelon01.mdl")
		ent.RootLocator:SetPos(ent:GetPos())
		ent.RootLocator:SetNoDraw(true)
		ent.RootLocator:SetParent(ent)
		ent.RootLocator.Owner = ent
		ent.RootLocator.IsRootLocator = true
		--ent.BuildBonePositions = UpdateRootLocator
		ent:AddBuildBoneHook("UpdateRootLocator", UpdateRootLocator)
	end
	ParticleEffectAttach(system, PATTACH_ABSORIGIN_FOLLOW, ent.RootLocator, 0)
end

function ITEM:ResetParticles(state_override)
	--MsgFN("ResetParticles %s %s",tostring(self),state_override or -1)
	
	self:ClearParticles()
	
	if not self:IsWeapon() and (self.Owner == LocalPlayer() and not LocalPlayer():ShouldDrawLocalPlayer()) then
		return
	end
	
	local ent
	if not self:IsWeapon() then
		ent = self
	elseif self.Owner==LocalPlayer() and not LocalPlayer():ShouldDrawLocalPlayer() then
		ent = self:GetViewModelEntity()
	else
		ent = self:GetWorldModelEntity()
	end
	
	-- Attached particles
	for _,p in ipairs(self:GetVisuals().attached_particlesystems or {}) do
		local att
		if p.attachment then
			att = ent:LookupAttachment(p.attachment)
		end
		
		if att and att ~= 0 then
			ParticleEffectAttach(p.system, PATTACH_POINT_FOLLOW, ent, att)
		else
			ParticleEffectAttachToRoot(p.system, ent)
		end
	end
	
	-- Attribute-controlled attached particles
	if self.AttachedParticle then
		--MsgFN("Attaching particle effect '%s' to %s",self.AttachedParticle.system, tostring(ent))
		
		local att
		if self.AttachedParticle.attachment then
			att = ent:LookupAttachment(self.AttachedParticle.attachment)
		end
		
		if att and att ~= 0 then
			ParticleEffectAttach(self.AttachedParticle.system, PATTACH_POINT_FOLLOW, ent, att)
		else
			if self.AttachedParticle.attach_to_rootbone then
				ParticleEffectAttachToRoot(self.AttachedParticle.system, ent)
			else
				ParticleEffectAttach(self.AttachedParticle.system, PATTACH_ABSORIGIN_FOLLOW, ent, 0)
			end
		end
	end
	
	-- Critical boost effect
	if self:IsWeapon() and (self.Owner:HasPlayerState(PLAYERSTATE_CRITBOOST, state_override) || self.Owner:HasPlayerState(PLAYERSTATE_MINICRIT, state_override)) then
		local effect
		local effect2
		local t = self.Owner:EntityTeam()
		
		if t==3 then
			effect = "critgun_weaponmodel_blu"
		else
			effect = "critgun_weaponmodel_red"
		end
		
		if t==3 then
			effect2 = "critgun_weaponmodel_blu_glow"
		else
			effect2 = "critgun_weaponmodel_red_glow"
		end
		
		ParticleEffectAttach(effect, PATTACH_ABSORIGIN_FOLLOW, ent, 0)
		ParticleEffectAttach(effect2, PATTACH_ABSORIGIN_FOLLOW, ent, 0)
	end
end

local function AddFormattedAttribute(a, fa)
	local d = tf_items.Attributes[a.name]
	
	if d and d.hidden == 0 then
		local s
		local effect = d.effect_type
		
		if tf_lang.Exists(d.description_string) then
			if d.description_format == "value_is_percentage" then
				s = math.Round((a.value - 1) * 100)
			elseif d.description_format == "value_is_inverted_percentage" then
				--s = math.Round(((1/a.value) - 1) * 100)
				s = math.Round((1 - a.value) * 100)
				if effect=="negative" then s = -s end
			elseif d.description_format == "value_is_additive" then
				s = math.Round(a.value * 1000) * 0.001
			elseif d.description_format == "value_is_or" then
				s = ""
			elseif d.description_format == "value_is_additive_percentage" then
				s = math.Round(a.value * 100)
			elseif d.description_format == "value_is_date" then
				local dt = os.date("!*t", a.value)
				s = Format("%s %d, %d (%02d:%02d:%02d GMT)", month_name[dt.month], dt.day, dt.year, dt.hour, dt.min, dt.sec)
			elseif d.description_format == "value_is_particle_index" then
				s = tf_lang.GetRaw(Format("#Attrib_Particle%d", a.value))
			end
			
			s = tf_lang.GetFormatted(d.description_string, s)
		else
			s = a.name
		end
		
		if d.attribute_class and IsAttributeUnimplemented(d.attribute_class) then
			if effect == "positive" then
				table.insert(fa, {-3, s})
			elseif effect == "negative" then
				table.insert(fa, {-4, s})
			else
				table.insert(fa, {-2, s})
			end
		else
			if effect == "positive" then
				table.insert(fa, {3, s})
			elseif effect == "negative" then
				table.insert(fa, {4, s})
			else
				table.insert(fa, {2, s})
			end
		end
	end
end

function ITEM:GetFormattedAttributes()
	if self.FormattedAttributes then
		return self.FormattedAttributes
	end
	
	local fa = {raw = ""}
	
	local item = self:GetItemData()
	if item.item_type_name and tf_lang.Exists(item.item_type_name) then
		table.insert(fa, {1, tf_lang.GetFormatted("ItemTypeDesc", self:GetLevel(), tf_lang.GetRaw(item.item_type_name))})
	end
	
	local desc = self:GetCustomDescription()
	
	if desc and desc ~= "" then
		table.insert(fa, {2, Format("\"%s\"", desc)})
	elseif item.item_description and tf_lang.Exists(item.item_description) then
		table.insert(fa, {2, tf_lang.GetRaw(item.item_description)})
	end
	
	if self.Attributes then
		for _,a in ipairs(self.Attributes) do
			AddFormattedAttribute(a, fa)
		end
	end
	
	local set = self:FindItemSet()
	if set then
		local complete_set = true
		for _,n in ipairs(set.items or {}) do
			if not self.Owner:HasTFItem(n) then
				complete_set = false
			end
		end
		
		if complete_set or tonumber(set.secret) ~= 1 then
			table.insert(fa, {1, ""})
			table.insert(fa, {5, tf_lang.GetRaw(set.name)})
			for _,n in ipairs(set.items or {}) do
				local item = tf_items.Items[n]
				if item then
					local name = tf_items.GetItemFullName(item)
					if self.Owner:HasTFItem(n) then
						table.insert(fa, {7, name})
					else
						table.insert(fa, {6, name})
					end
				end
			end
			
			if complete_set and set.attributes then
				table.insert(fa, {1, ""})
				table.insert(fa, {5, tf_lang.GetRaw("#TF_Set_Bonus")})
				for _,a in ipairs(set.attributes) do
					AddFormattedAttribute(a, fa)
				end
			end
		end
	end
	
	local raw = ""
	for i=1,#fa do
		if i>1 then
			raw = raw.."\n"
		end
		raw = raw..fa[i][2]
	end
	
	fa.raw = raw
	self.FormattedAttributes = fa
	return fa
end

usermessage.Hook("TF_SetExtraAttributes", function(msg)
	local entid, wep, num, att, id, value
	
	--wep = msg:ReadEntity()
	entid = msg:ReadLong()
	wep = Entity(entid)
	num = msg:ReadChar()
	
	--MsgFN("Received %d extra attribute(s) for %s (%d)", num, tostring(wep), entid)
	
	--MsgFN("%d attributes to read", num)
	if num <= 0 then return end
	
	att = {}
	for i=1,num do
		id = msg:ReadShort()
		value = msg:ReadFloat()
		--MsgFN("\"%d\" = %f", id, value)
		table.insert(att, {id,value})
	end
	
	if not IsValid(wep) or not wep.SetExtraAttributes then
		ExtraAttributesPending[entid] = att
		----MsgN("Weapon not initialized, adding to pending list")
		return
	end
	
	wep:SetExtraAttributes(att)
end)

hook.Add("Think", "TFCheckUpdateItems", function()
	
		for _,v in pairs(ents.GetAll()) do
			if v.IsRootLocator and not IsValid(v:GetParent()) then
				v:Remove()
			elseif v.CheckUpdateItem then
				local ok, err = pcall(v.CheckUpdateItem, v)
				if not ok then
					ErrorNoHalt(Format("%s:CheckUpdateItem failed: %s", tostring(v), err))
				end
			end
		end
end)

end

-----------------------------------
-- END OF BASE ITEM TABLE

function InitializeAsBaseItem(tbl)
	-- Add all base TF item functions to the entity's metatable
	table.Merge(tbl, ITEM)
end

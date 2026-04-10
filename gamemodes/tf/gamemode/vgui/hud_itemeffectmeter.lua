local W = ScrW()
local H = ScrH()
local Scale = H / 480

local DEFAULT_METER_RES = "resource/ui/huditemeffectmeter.res"
local RUNE_METER_RES = "resource/ui/hudpowerupeffectmeter.res"
local MAX_VISIBLE_METER_SLOTS = 3
local REFRESH_INTERVAL = 0.15

local DEFAULT_METER_BG = {
	surface.GetTextureID("hud/misc_ammo_area_horiz1_blue"),
	surface.GetTextureID("hud/misc_ammo_area_horiz1_red"),
	surface.GetTextureID("hud/misc_ammo_area_horiz1_blue"),
}

local METER_RES_BY_CLASS = {
	tf_weapon_jar_milk = "resource/ui/huditemeffectmeter_scout.res",
	tf_weapon_bat_wood = "resource/ui/huditemeffectmeter_scout.res",
	tf_weapon_cleaver = "resource/ui/huditemeffectmeter_cleaver.res",
	tf_weapon_jar_gas = "resource/ui/huditemeffectmeter_pyro.res",
	tf_weapon_phlogistinator = "resource/ui/huditemeffectmeter_pyro.res",
}

local MeterLabel = {
	text = "",
	font = "TFFontSmall",
	pos = {0, 0},
	xalign = TEXT_ALIGN_CENTER,
	yalign = TEXT_ALIGN_CENTER,
}

local MeterResCache = {}
local RUNE_METER_LABELS = {
	[TF_RUNE_STRENGTH] = "Strength",
	[TF_RUNE_HASTE] = "Haste",
	[TF_RUNE_REGEN] = "Regen",
	[TF_RUNE_RESIST] = "Resist",
	[TF_RUNE_VAMPIRE] = "Vampire",
	[TF_RUNE_REFLECT] = "Reflect",
	[TF_RUNE_PRECISION] = "Precision",
	[TF_RUNE_AGILITY] = "Agility",
	[TF_RUNE_KNOCKOUT] = "Knockout",
	[TF_RUNE_KING] = "King",
	[TF_RUNE_PLAGUE] = "Plague",
	[TF_RUNE_SUPERNOVA] = "Supernova",
}
local RUNE_METER_ICONS = {
	[TF_RUNE_STRENGTH] = "effects/powerup_strength_hud",
	[TF_RUNE_HASTE] = "effects/powerup_haste_hud",
	[TF_RUNE_REGEN] = "effects/powerup_regen_hud",
	[TF_RUNE_RESIST] = "effects/powerup_resist_hud",
	[TF_RUNE_VAMPIRE] = "effects/powerup_vampire_hud",
	[TF_RUNE_REFLECT] = "effects/powerup_reflect_hud",
	[TF_RUNE_PRECISION] = "effects/powerup_precision_hud",
	[TF_RUNE_AGILITY] = "effects/powerup_agility_hud",
	[TF_RUNE_KNOCKOUT] = "effects/powerup_knockout_hud",
	[TF_RUNE_KING] = "effects/powerup_king_hud",
	[TF_RUNE_PLAGUE] = "effects/powerup_plague_hud",
	[TF_RUNE_SUPERNOVA] = "effects/powerup_supernova_hud",
}

local function isMeterSourceValid(item)
	return IsValid(item) or (istable(item) and item.IsVirtualHUDMeter == true)
end

local function createRuneMeterSource(pl)
	return {
		IsVirtualHUDMeter = true,
		GlobalCustomHUD = { HudItemEffectMeter = true },
		Slot = 99,
		SlotPos = 0,
		EntIndex = function()
			return -1000
		end,
		GetClass = function()
			return "tf_mannpower_rune"
		end,
		GetHUDMeterName = function()
			local runeType = pl.GetCarryingRuneType and pl:GetCarryingRuneType() or TF_RUNE_NONE
			return RUNE_METER_LABELS[runeType] or "Rune"
		end,
		GetHUDMeterValue = function()
			local charge = pl.GetRuneCharge and pl:GetRuneCharge() or 0
			return math.Clamp((tonumber(charge) or 0) / 100, 0, 1)
		end,
		GetHUDMeterShouldFlash = function()
			return pl.IsRuneCharged and pl:IsRuneCharged() or false
		end,
		GetHUDMeterResFile = function()
			return RUNE_METER_RES
		end,
		GetHUDMeterIcon = function()
			local runeType = pl.GetCarryingRuneType and pl:GetCarryingRuneType() or TF_RUNE_NONE
			return RUNE_METER_ICONS[runeType] or ""
		end,
		GetHUDMeterBarColor = function()
			return Colors.Yellow
		end,
	}
end

local function resolveHudCoord(raw, axisSize, axisScale, fallback)
	if not isstring(raw) then
		return fallback
	end
	local v = string.Trim(raw)
	if v == "" then return fallback end

	local n = tonumber(v)
	if n ~= nil then
		return n * axisScale
	end

	local right = string.match(v, "^r([%+%-]?%d*%.?%d*)$")
	if right ~= nil then
		local offs = tonumber(right)
		if right == "" or offs == nil then offs = 0 end
		return axisSize - offs * axisScale
	end

	local center = string.match(v, "^c([%+%-]?%d*%.?%d*)$")
	if center ~= nil then
		local offs = tonumber(center)
		if center == "" or offs == nil then offs = 0 end
		return axisSize * 0.5 + offs * axisScale
	end

	return fallback
end

local function loadMeterRes(path)
	local parsed = {
		panelX = "r174",
		panelY = "r62",
		panelW = 100,
		panelH = 50,
		bgX = 12,
		bgY = 6,
		bgW = 100,
		bgH = 50,
		labelX = 62.5,
		labelY = 37.5,
		labelColor = Color(255, 255, 255, 255),
		iconX = 0,
		iconY = 0,
		iconW = 0,
		iconH = 0,
		iconTexture = nil,
		barX = 47,
		barY = 28,
		barW = 30,
		barH = 5,
		bar2X = 0,
		bar2Y = 0,
		bar2W = 0,
		bar2H = 0,
		xOffset = 40,
		teamBG = {
			DEFAULT_METER_BG[1],
			DEFAULT_METER_BG[2],
			DEFAULT_METER_BG[3],
		},
	}

	local tree = TF2Res and TF2Res.Load and TF2Res.Load(path)
	local root = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "HudItemEffectMeter")
	local bg = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "ItemEffectMeterBG")
	local label = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "ItemEffectMeterLabel")
	local icon = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "ItemEffectIcon")
	local meter = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "ItemEffectMeter")
	local meter2 = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "ItemEffectMeter2")

	if root and TF2Res.GetString and TF2Res.GetNumber then
		parsed.panelX = TF2Res.GetString(root, "xpos", parsed.panelX)
		parsed.panelY = TF2Res.GetString(root, "ypos", parsed.panelY)
		parsed.panelW = TF2Res.GetNumber(root, "wide", parsed.panelW)
		parsed.panelH = TF2Res.GetNumber(root, "tall", parsed.panelH)
		parsed.xOffset = TF2Res.GetNumber(root, "x_offset", parsed.xOffset)
	end
	if bg and TF2Res.GetNumber then
		parsed.bgX = TF2Res.GetNumber(bg, "xpos", parsed.bgX)
		parsed.bgY = TF2Res.GetNumber(bg, "ypos", parsed.bgY)
		parsed.bgW = TF2Res.GetNumber(bg, "wide", parsed.bgW)
		parsed.bgH = TF2Res.GetNumber(bg, "tall", parsed.bgH)
		parsed.teamBG[1] = TF2Res.GetTextureID(bg, "image", "hud/misc_ammo_area_horiz1_blue")
		parsed.teamBG[2] = TF2Res.GetTextureID(bg, "teambg_2", "hud/misc_ammo_area_horiz1_red")
		parsed.teamBG[3] = TF2Res.GetTextureID(bg, "teambg_3", "hud/misc_ammo_area_horiz1_blue")
	end
	if label and TF2Res.GetNumber then
		parsed.labelX = TF2Res.GetNumber(label, "xpos", 42) + TF2Res.GetNumber(label, "wide", 41) * 0.5
		parsed.labelY = TF2Res.GetNumber(label, "ypos", 30) + TF2Res.GetNumber(label, "tall", 15) * 0.5
		if TF2Res.GetColor then
			parsed.labelColor = TF2Res.GetColor(label, "fgcolor", parsed.labelColor)
		end
	end
	if icon and TF2Res.GetNumber then
		parsed.iconX = TF2Res.GetNumber(icon, "xpos", 0)
		parsed.iconY = TF2Res.GetNumber(icon, "ypos", 0)
		parsed.iconW = TF2Res.GetNumber(icon, "wide", 0)
		parsed.iconH = TF2Res.GetNumber(icon, "tall", 0)
		parsed.iconTexture = TF2Res.GetTextureID(icon, "image", "")
	end
	if meter and TF2Res.GetNumber then
		parsed.barX = TF2Res.GetNumber(meter, "xpos", parsed.barX)
		parsed.barY = TF2Res.GetNumber(meter, "ypos", parsed.barY)
		parsed.barW = TF2Res.GetNumber(meter, "wide", parsed.barW)
		parsed.barH = TF2Res.GetNumber(meter, "tall", parsed.barH)
	end
	if meter2 and TF2Res.GetNumber then
		parsed.bar2X = TF2Res.GetNumber(meter2, "xpos", parsed.bar2X)
		parsed.bar2Y = TF2Res.GetNumber(meter2, "ypos", parsed.bar2Y)
		parsed.bar2W = TF2Res.GetNumber(meter2, "wide", parsed.bar2W)
		parsed.bar2H = TF2Res.GetNumber(meter2, "tall", parsed.bar2H)
	end

	return parsed
end

local function getMeterRes(path)
	path = path or DEFAULT_METER_RES
	if not MeterResCache[path] then
		MeterResCache[path] = loadMeterRes(path)
	end
	return MeterResCache[path]
end

local function evalHudFlag(item, name, active)
	local gch = item.GlobalCustomHUD and item.GlobalCustomHUD[name]
	if gch ~= nil then
		if isfunction(gch) then gch = gch(item) end
		if gch then return true end
	end

	if item == active then
		local ch = item.CustomHUD and item.CustomHUD[name]
		if ch ~= nil then
			if isfunction(ch) then ch = ch(item) end
			if ch then return true end
		end
	end

	return false
end

local function getItemMeterRes(item)
	if not isMeterSourceValid(item) then
		return DEFAULT_METER_RES
	end
	if item.GetHUDMeterResFile then
		local custom = item:GetHUDMeterResFile()
		if isstring(custom) and custom ~= "" then
			return string.lower(custom)
		end
	end
	return METER_RES_BY_CLASS[item:GetClass()] or DEFAULT_METER_RES
end

local function getMeterFlashColor()
	local colorOffset = math.floor(RealTime() * 10) % 10
	local red = 160 + (colorOffset * 10)
	return Color(red, 0, 0, 255)
end

local function shouldFlashMeter(item, progress)
	if not isMeterSourceValid(item) then return false end
	if (progress or 0) < 0.999 then return false end

	if isfunction(item.GetHUDMeterShouldFlash) then
		return item:GetHUDMeterShouldFlash() == true
	end

	local name = item.GetHUDMeterName and item:GetHUDMeterName() or ""
	return name == "#TF_Rage" or name == "#TF_PyroRage"
end

local function getWeaponSlot(item)
	if not isMeterSourceValid(item) then return 99 end
	if isnumber(item.Slot) then return item.Slot end
	if isfunction(item.GetSlot) then
		local v = item:GetSlot()
		if isnumber(v) then return v end
	end
	return 99
end

local function getWeaponSlotPos(item)
	if not isMeterSourceValid(item) then return 99 end
	if isnumber(item.SlotPos) then return item.SlotPos end
	if isfunction(item.GetSlotPos) then
		local v = item:GetSlotPos()
		if isnumber(v) then return v end
	end
	return 99
end

local METER = {}

function METER:Init()
	self:SetPaintBackgroundEnabled(false)
	self.Item = nil
	self.ResPath = DEFAULT_METER_RES
	self.Res = getMeterRes(DEFAULT_METER_RES)
	self.Progress = 0
	self.ProgressBars = 1
	self.Team = TEAM_BLUE or 3
	self:SetVisible(false)
end

function METER:SetSource(item)
	self.Item = item
	self.ResPath = getItemMeterRes(item)
	self.Res = getMeterRes(self.ResPath)
end

function METER:IsEnabledForPlayer(pl, active)
	if not IsValid(pl) or not isMeterSourceValid(self.Item) then
		return false
	end
	if not self.Item.GetHUDMeterName or not self.Item.GetHUDMeterValue then
		return false
	end
	return evalHudFlag(self.Item, "HudItemEffectMeter", active)
end

local function getMeterLabelText(item)
	if not isMeterSourceValid(item) then return "" end

	-- TF2 quirk: Mutated Milk meter title is shown as "Jar".
	local className = string.lower(tostring(item.GetClass and item:GetClass() or ""))
	if className == "tf_weapon_jar_milk" and item.GetItemData then
		local itemData = item:GetItemData()
		local modelPlayer = string.lower(tostring(itemData and itemData.model_player or ""))
		if string.find(modelPlayer, "breadmonster_milk", 1, true) then
			return "Jar"
		end
	end

	local meterName = item.GetHUDMeterName and item:GetHUDMeterName() or ""
	if isstring(meterName) and tf_lang and tf_lang.GetRaw then
		return tf_lang.GetRaw(meterName) or meterName
	end
	return meterName or ""
end

function METER:GetSortData(active)
	local item = self.Item
	return {
		panel = self,
		item = item,
		slot = getWeaponSlot(item),
		slotPos = getWeaponSlotPos(item),
		isActive = (item == active),
		entIndex = isMeterSourceValid(item) and item:EntIndex() or 0,
	}
end

function METER:SetMeterLayout(x, y, scale, team)
	if not self.Res then return end
	self.Team = team or self.Team
	self:SetPos(x, y)
	local drawW = math.max(self.Res.panelW or 0, (self.Res.bgX or 0) + (self.Res.bgW or 0))
	local drawH = math.max(self.Res.panelH or 0, (self.Res.bgY or 0) + (self.Res.bgH or 0))
	self:SetSize(drawW * scale, drawH * scale)
end

function METER:Think()
	if not isMeterSourceValid(self.Item) then
		self:SetVisible(false)
		return
	end
	self.Progress = math.Clamp(tonumber(self.Item:GetHUDMeterValue()) or 0, 0, 1)
	self.ProgressBars = math.max(1, math.floor(tonumber(self.Item.GetHUDMeterProgressBars and self.Item:GetHUDMeterProgressBars()) or 1))
end

local function getMeterBarColor(item)
	if isMeterSourceValid(item) and isfunction(item.GetHUDMeterBarColor) then
		return item:GetHUDMeterBarColor() or Colors.Yellow
	end
	return Colors.Yellow
end

local function getMeterLabelColor(item, res)
	if isMeterSourceValid(item) and isfunction(item.GetHUDMeterLabelColor) then
		return item:GetHUDMeterLabelColor() or (res and res.labelColor) or color_white
	end
	return (res and res.labelColor) or color_white
end

local function getMeterIconTexture(item, res)
	if isMeterSourceValid(item) and isfunction(item.GetHUDMeterIcon) then
		local path = item:GetHUDMeterIcon()
		if isstring(path) and path ~= "" then
			local normalized = TF2Res and TF2Res.NormalizeImagePath and TF2Res.NormalizeImagePath(path) or path
			return surface.GetTextureID(normalized)
		end
	end
	return res and res.iconTexture or nil
end

local function drawMeterBar(x, y, w, h, color, fill)
	surface.SetDrawColor(Colors.TransparentYellow)
	surface.DrawRect(x, y, w, h)

	if fill <= 0 then return end

	surface.SetDrawColor(color)
	surface.DrawRect(x, y, w * math.Clamp(fill, 0, 1), h)
end

function METER:Paint(w, h)
	if not isMeterSourceValid(self.Item) or not self.Res then return end

	local scale = Scale
	local res = self.Res
	local teamBG = res.teamBG or DEFAULT_METER_BG
	local tex = teamBG[self.Team] or teamBG[1] or DEFAULT_METER_BG[1]

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetTexture(tex)
	surface.DrawTexturedRect(
		res.bgX * scale,
		res.bgY * scale,
		res.bgW * scale,
		res.bgH * scale
	)

	local iconTexture = getMeterIconTexture(self.Item, res)
	if iconTexture and iconTexture > 0 and res.iconW > 0 and res.iconH > 0 then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetTexture(iconTexture)
		surface.DrawTexturedRect(
			res.iconX * scale,
			res.iconY * scale,
			res.iconW * scale,
			res.iconH * scale
		)
	end

	MeterLabel.text = getMeterLabelText(self.Item)
	MeterLabel.pos = {
		res.labelX * scale,
		res.labelY * scale,
	}
	MeterLabel.color = getMeterLabelColor(self.Item, res)
	draw.Text(MeterLabel)

	local barColor = shouldFlashMeter(self.Item, self.Progress) and getMeterFlashColor() or getMeterBarColor(self.Item)
	local bars = self.ProgressBars or 1
	local barProgress = self.Progress

	drawMeterBar(res.barX * scale, res.barY * scale, res.barW * scale, res.barH * scale, barColor, math.min(1, barProgress * bars))

	if bars > 1 and res.bar2W > 0 and res.bar2H > 0 then
		drawMeterBar(
			res.bar2X * scale,
			res.bar2Y * scale,
			res.bar2W * scale,
			res.bar2H * scale,
			barColor,
			math.Clamp(barProgress * bars - 1, 0, 1)
		)
	end
end

local MANAGER = {}

function MANAGER:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
	self.MeterPanels = {}
	self.LastSignature = ""
	self.NextRefresh = 0
end

function MANAGER:PerformLayout()
	W = ScrW()
	H = ScrH()
	Scale = H / 480
	self:SetPos(0, 0)
	self:SetSize(W, H)
end

function MANAGER:ShouldDrawMeters(pl)
	if not IsValid(pl) then return false end
	if not pl:Alive() then return false end
	if GetConVar("tf_forcehl2hud"):GetBool() then return false end
	if GetConVarNumber("cl_drawhud") == 0 then return false end
	if not IsCustomHUDVisible("HudItemEffectMeter") then return false end
	return true
end

function MANAGER:BuildInventorySignature(pl)
	local items = pl.GetTFItems and pl:GetTFItems() or nil
	items = istable(items) and items or {}

	local parts = {}
	for _, item in pairs(items) do
		if IsValid(item) and item.GetHUDMeterName and item.GetHUDMeterValue then
			parts[#parts + 1] = tostring(item:EntIndex()) .. ":" .. tostring(item:GetClass())
		end
	end
	if pl.CanRuneCharge and pl:CanRuneCharge() then
		local runeType = pl.GetCarryingRuneType and pl:GetCarryingRuneType() or TF_RUNE_NONE
		parts[#parts + 1] = "rune:" .. tostring(runeType)
	end
	table.sort(parts)

	local active = pl:GetActiveWeapon()
	local activeID = IsValid(active) and active:EntIndex() or 0
	return tostring(activeID) .. "|" .. table.concat(parts, ",")
end

function MANAGER:RefreshMeters(pl)
	local active = pl:GetActiveWeapon()
	local items = pl.GetTFItems and pl:GetTFItems() or nil
	items = istable(items) and items or {}

	local seen = {}
	for _, item in pairs(items) do
		if IsValid(item) and item.GetHUDMeterName and item.GetHUDMeterValue then
			local entIndex = item:EntIndex()
			seen[entIndex] = true
			local panel = self.MeterPanels[entIndex]
			if not IsValid(panel) then
				panel = vgui.Create("TFHudItemEffectMeterPanel", self)
				self.MeterPanels[entIndex] = panel
			end
			panel:SetSource(item)
		end
	end

	if pl.CanRuneCharge and pl:CanRuneCharge() then
		seen.rune = true
		local panel = self.MeterPanels.rune
		if not IsValid(panel) then
			panel = vgui.Create("TFHudItemEffectMeterPanel", self)
			self.MeterPanels.rune = panel
		end
		panel:SetSource(createRuneMeterSource(pl))
	end

	for entIndex, panel in pairs(self.MeterPanels) do
		if (not seen[entIndex]) or (not IsValid(panel)) then
			if IsValid(panel) then panel:Remove() end
			self.MeterPanels[entIndex] = nil
		end
	end

	local drawList = {}
	for _, panel in pairs(self.MeterPanels) do
		if IsValid(panel) and panel:IsEnabledForPlayer(pl, active) then
			drawList[#drawList + 1] = panel:GetSortData(active)
		else
			if IsValid(panel) then panel:SetVisible(false) end
		end
	end

	table.sort(drawList, function(a, b)
		if a.slot ~= b.slot then return a.slot < b.slot end
		if a.slotPos ~= b.slotPos then return a.slotPos < b.slotPos end
		if a.isActive ~= b.isActive then return a.isActive end
		return a.entIndex < b.entIndex
	end)

	if #drawList < 1 then
		return
	end

	local team = pl:Team()
	local firstRes = drawList[1].panel.Res or getMeterRes(DEFAULT_METER_RES)
	local baseX = resolveHudCoord(firstRes.panelX, W, Scale, W - 174 * Scale)
	local baseY = resolveHudCoord(firstRes.panelY, H, Scale, H - 62 * Scale)

	for i, data in ipairs(drawList) do
		local panel = data.panel
		if i > MAX_VISIBLE_METER_SLOTS then
			panel:SetVisible(false)
		else
			local res = panel.Res or firstRes
			local x = baseX - ((i - 1) * (res.xOffset or 40) * Scale)
			panel:SetMeterLayout(x, baseY, Scale, team)
			panel:SetVisible(true)
		end
	end
end

function MANAGER:Think()
	local pl = LocalPlayer()
	local shouldDraw = self:ShouldDrawMeters(pl)
	if not shouldDraw then
		for _, panel in pairs(self.MeterPanels) do
			if IsValid(panel) then panel:SetVisible(false) end
		end
		return
	end

	local now = CurTime()
	local signature = self:BuildInventorySignature(pl)
	local needsRefresh = signature ~= self.LastSignature or now >= self.NextRefresh
	if needsRefresh then
		self.LastSignature = signature
		self.NextRefresh = now + REFRESH_INTERVAL
		self:RefreshMeters(pl)
	end
end

function MANAGER:Paint()
end

vgui.Register("TFHudItemEffectMeterPanel", METER, "DPanel")
vgui.Register("TFHudItemEffectMeterManager", MANAGER, "DPanel")

if HudItemEffectMeter then HudItemEffectMeter:Remove() end
HudItemEffectMeter = vgui.Create("TFHudItemEffectMeterManager")

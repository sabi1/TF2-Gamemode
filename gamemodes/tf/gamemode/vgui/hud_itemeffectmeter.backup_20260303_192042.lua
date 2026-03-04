local PANEL = {}

local W = ScrW()
local H = ScrH()
local Scale = H / 480

local DEFAULT_METER_RES = "resource/ui/huditemeffectmeter.res"
local MAX_VISIBLE_METER_SLOTS = 3

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
	pos = {62.5 * Scale, 37.5 * Scale},
	xalign = TEXT_ALIGN_CENTER,
	yalign = TEXT_ALIGN_CENTER,
}

local function resolveHudCoord(raw, axisSize, axisScale, fallback)
	if not isstring(raw) then
		return fallback
	end

	local v = string.Trim(raw)
	if v == "" then
		return fallback
	end

	local n = tonumber(v)
	if n ~= nil then
		return n * axisScale
	end

	local right = string.match(v, "^r([%+%-]?%d*%.?%d*)$")
	if right ~= nil then
		local offs = tonumber(right)
		if right == "" or offs == nil then
			offs = 0
		end
		return axisSize - offs * axisScale
	end

	local center = string.match(v, "^c([%+%-]?%d*%.?%d*)$")
	if center ~= nil then
		local offs = tonumber(center)
		if center == "" or offs == nil then
			offs = 0
		end
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
		barX = 47,
		barY = 28,
		barW = 30,
		barH = 5,
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
	local meter = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "ItemEffectMeter")

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
	end

	if meter and TF2Res.GetNumber then
		parsed.barX = TF2Res.GetNumber(meter, "xpos", parsed.barX)
		parsed.barY = TF2Res.GetNumber(meter, "ypos", parsed.barY)
		parsed.barW = TF2Res.GetNumber(meter, "wide", parsed.barW)
		parsed.barH = TF2Res.GetNumber(meter, "tall", parsed.barH)
	end

	return parsed
end

local MeterResCache = {}
local function getMeterRes(path)
	path = path or DEFAULT_METER_RES
	if not MeterResCache[path] then
		MeterResCache[path] = loadMeterRes(path)
	end
	return MeterResCache[path]
end

local function evalHudFlag(item, name, active)
	local globalValue = item.GlobalCustomHUD and item.GlobalCustomHUD[name]
	if globalValue ~= nil then
		if isfunction(globalValue) then
			globalValue = globalValue(item)
		end
		if globalValue then
			return true
		end
	end

	if item == active then
		local activeValue = item.CustomHUD and item.CustomHUD[name]
		if activeValue ~= nil then
			if isfunction(activeValue) then
				activeValue = activeValue(item)
			end
			if activeValue then
				return true
			end
		end
	end

	return false
end

local function getItemMeterRes(item)
	if not IsValid(item) then
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
	if not IsValid(item) then return false end
	if (progress or 0) < 0.999 then return false end

	if isfunction(item.GetHUDMeterShouldFlash) then
		return item:GetHUDMeterShouldFlash() == true
	end

	local name = item.GetHUDMeterName and item:GetHUDMeterName() or ""
	return name == "#TF_Rage" or name == "#TF_PyroRage"
end

local function getWeaponSlot(item)
	if not IsValid(item) then return 99 end
	local slot = item.Slot
	if isnumber(slot) then
		return slot
	end
	if isfunction(item.GetSlot) then
		local value = item:GetSlot()
		if isnumber(value) then
			return value
		end
	end
	return 99
end

local function getWeaponSlotPos(item)
	if not IsValid(item) then return 99 end
	local slotPos = item.SlotPos
	if isnumber(slotPos) then
		return slotPos
	end
	if isfunction(item.GetSlotPos) then
		local value = item:GetSlotPos()
		if isnumber(value) then
			return value
		end
	end
	return 99
end

local function buildMeterEntries(pl)
	if not IsValid(pl) then
		return {}
	end

	local active = pl:GetActiveWeapon()
	local items = pl.GetTFItems and pl:GetTFItems() or nil
	if not istable(items) then
		return {}
	end

	local entries = {}
	for _, item in pairs(items) do
		if IsValid(item) and item.GetHUDMeterName and item.GetHUDMeterValue then
			if evalHudFlag(item, "HudItemEffectMeter", active) then
				entries[#entries + 1] = {
					item = item,
					progress = math.Clamp(tonumber(item:GetHUDMeterValue()) or 0, 0, 1),
					slot = getWeaponSlot(item),
					slotPos = getWeaponSlotPos(item),
					isActive = item == active,
					entIndex = item:EntIndex(),
				}
			end
		end
	end

	table.sort(entries, function(a, b)
		if a.slot ~= b.slot then return a.slot < b.slot end
		if a.slotPos ~= b.slotPos then return a.slotPos < b.slotPos end
		if a.isActive ~= b.isActive then return a.isActive end
		return a.entIndex < b.entIndex
	end)

	return entries
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
end

function PANEL:PerformLayout()
	W = ScrW()
	H = ScrH()
	Scale = H / 480
	self:SetPos(0, 0)
	self:SetSize(W, H)
end

function PANEL:Paint()
	local pl = LocalPlayer()
	if not IsValid(pl) then return end
	if not pl:Alive() then return end
	if GetConVar("tf_forcehl2hud"):GetBool() then return end
	if GetConVarNumber("cl_drawhud") == 0 then return end
	if not IsCustomHUDVisible("HudItemEffectMeter") then return end

	local entries = buildMeterEntries(pl)
	if #entries < 1 then
		return
	end

	local team = pl:Team()
	local firstRes = getMeterRes(getItemMeterRes(entries[1].item))
	local baseX = resolveHudCoord(firstRes.panelX, W, Scale, W - 174 * Scale)
	local baseY = resolveHudCoord(firstRes.panelY, H, Scale, H - 62 * Scale)

	for i = 1, math.min(#entries, MAX_VISIBLE_METER_SLOTS) do
		local entry = entries[i]
		local item = entry.item
		local res = getMeterRes(getItemMeterRes(item))
		local stackOffset = ((i - 1) * (res.xOffset or 40)) * Scale
		local meterX = baseX - stackOffset
		local meterY = baseY

		local teamBG = res.teamBG or DEFAULT_METER_BG
		local tex = teamBG[team] or teamBG[1] or DEFAULT_METER_BG[1]

		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetTexture(tex)
		surface.DrawTexturedRect(
			meterX + res.bgX * Scale,
			meterY + res.bgY * Scale,
			res.bgW * Scale,
			res.bgH * Scale
		)

		local meterName = item:GetHUDMeterName()
		local localized = meterName
		if isstring(meterName) and tf_lang and tf_lang.GetRaw then
			localized = tf_lang.GetRaw(meterName) or meterName
		end

		MeterLabel.text = localized or ""
		MeterLabel.pos = {
			meterX + res.labelX * Scale,
			meterY + res.labelY * Scale,
		}
		draw.Text(MeterLabel)

		local progress = math.Clamp(entry.progress or 0, 0, 1)
		surface.SetDrawColor(Colors.TransparentYellow)
		surface.DrawRect(
			meterX + res.barX * Scale,
			meterY + res.barY * Scale,
			res.barW * Scale,
			res.barH * Scale
		)

		if progress > 0 then
			if shouldFlashMeter(item, progress) then
				surface.SetDrawColor(getMeterFlashColor())
			else
				surface.SetDrawColor(Colors.Yellow)
			end
			surface.DrawRect(
				meterX + res.barX * Scale,
				meterY + res.barY * Scale,
				res.barW * Scale * progress,
				res.barH * Scale
			)
		end
	end
end

if HudItemEffectMeter then HudItemEffectMeter:Remove() end
HudItemEffectMeter = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

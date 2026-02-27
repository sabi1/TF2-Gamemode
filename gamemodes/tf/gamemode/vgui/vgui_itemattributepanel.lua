local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local loadout_popup = surface.GetTextureID("vgui/loadout_popup")
local bordersize = 26

local attribcolors = {
	"ItemAttribLevel",
	"ItemAttribNeutral",
	"ItemAttribPositive",
	"ItemAttribNegative",
	"ItemSetName",
	"ItemSetItemMissing",
	"ItemSetItemEquipped",
}

function PANEL:Init()
	self:SetVisible(false)
	self:NoClipping(true)
	self:SetPaintBackgroundEnabled(false)
end

function PANEL:SetQuality(q)
	q = "QualityColor"..q
	if Colors[q] then
		self.qualitycolor = q
	end
end

function PANEL:Paint()
	if self.invisible then return end

	local function estimateLineCount(text, charsPerLine)
		if not isstring(text) or text == "" then return 0 end
		return math.max(1, math.ceil(string.len(text) / math.max(1, charsPerLine)))
	end

	local title = tostring(self.text or "ITEM")
	local subtitle = isstring(self.levelText) and self.levelText or ""
	local description = isstring(self.description) and self.description or ""
	local flavor = isstring(self.flavorText) and self.flavorText or ""

	local maxLen = string.len(title)
	maxLen = math.max(maxLen, string.len(subtitle))
	maxLen = math.max(maxLen, string.len(description))
	maxLen = math.max(maxLen, string.len(flavor))
	for _, v in pairs(self.attributes or {}) do
		local statText = istable(v) and tostring(v.name or "") or ""
		maxLen = math.max(maxLen, string.len(statText))
	end

	local targetW = math.Clamp((156 + maxLen * 1.25) * Scale, 220 * Scale, 380 * Scale)
	local charsPerLine = math.max(18, math.floor((targetW / Scale - 24) / 5.8))
	local attrLineCount = 0
	for _, v in pairs(self.attributes or {}) do
		local statText = istable(v) and tostring(v.name or "") or ""
		attrLineCount = attrLineCount + estimateLineCount(statText, charsPerLine)
	end

	local targetH = (88 + attrLineCount * 11 + estimateLineCount(description, charsPerLine) * 11 + estimateLineCount(flavor, charsPerLine) * 11) * Scale
	targetH = math.Clamp(targetH, 170 * Scale, 440 * Scale)

	targetW = math.floor(targetW)
	targetH = math.floor(targetH)
	local w, h = self:GetSize()
	if w ~= targetW or h ~= targetH then
		self:SetSize(targetW, targetH)
		w, h = self:GetSize()
	end

	local pad = 10 * Scale
	local mouseOffsetX = 14 * Scale
	local mouseOffsetY = 14 * Scale
	local mx, my = gui.MouseX(), gui.MouseY()

	local x = mx + mouseOffsetX
	if x + w > ScrW() - 4 then
		x = mx - w - mouseOffsetX
	end
	if x < 4 then
		x = math.Clamp(x, 4, ScrW() - w - 4)
	end

	local y = my + mouseOffsetY
	if y + h > ScrH() - 4 then
		y = my - h - mouseOffsetY
	end
	if y < 4 then
		y = math.Clamp(y, 4, ScrH() - h - 4)
	end

	self:SetPos(x, y)

	draw.RoundedBox(7 * Scale, 0, 0, w, h, Color(23, 20, 18, 248))
	surface.SetDrawColor(110, 98, 84, 255)
	surface.DrawOutlinedRect(0, 0, w, h, 1)

	local iconW = 84 * Scale
	local iconH = 58 * Scale
	local iconX = (w - iconW) * 0.5
	local iconY = pad
	draw.RoundedBox(5 * Scale, iconX, iconY, iconW, iconH, Color(49, 41, 35, 255))

	if isnumber(self.itemImage) and self.itemImage > 0 then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetTexture(self.itemImage)
		local tw, th = surface.GetTextureSize(self.itemImage)
		if tw > 0 and th > 0 then
			local dw = iconW - 8 * Scale
			local dh = iconH - 8 * Scale
			local fit = math.min(dw / tw, dh / th)
			local rw, rh = tw * fit, th * fit
			surface.DrawTexturedRect(iconX + (iconW - rw) * 0.5, iconY + (iconH - rh) * 0.5, rw, rh)
		end
	end

	local titleColor = (Colors and Colors[self.qualitycolor or "QualityColorUnique"]) or Color(240, 214, 78, 255)
	draw.SimpleText(string.upper(self.text or "ITEM"), "HudFontSmallBold", w * 0.5, iconY + iconH + 9 * Scale, titleColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

	if isstring(subtitle) and subtitle ~= "" then
		draw.SimpleText(subtitle, "HudFontSmall", w * 0.5, iconY + iconH + 25 * Scale, Color(182, 176, 162, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end

	local rowY = iconY + iconH + 40 * Scale
	local function drawWrap(text, color)
		if not isstring(text) or text == "" then return 0 end
		local tab = {
			x = 12 * Scale,
			y = rowY,
			w = w - 24 * Scale,
			h = h - rowY - 8 * Scale,
			font = "ItemFontAttribSmall",
			text = text,
			col = color,
			align = "north",
			yspace = 1,
		}
		local th = tf_draw.LabelTextWrap(tab, true)
		tf_draw.LabelTextWrap(tab)
		rowY = rowY + th + 2 * Scale
		return th
	end

	for _, v in pairs(self.attributes or {}) do
		local statText = (v and v.name) or ""
		if statText ~= "" then
			local c = (Colors and Colors[attribcolors[v[2] or 2] or "ItemAttribNeutral"]) or Color(196, 194, 188, 255)
			if rowY > h - 48 * Scale then break end
			drawWrap(statText, c)
		end
	end

	if rowY < h - 28 * Scale then
		if isstring(self.description) and self.description ~= "" then
			drawWrap(self.description, Color(136, 188, 234, 255))
		end
		if isstring(self.flavorText) and self.flavorText ~= "" and rowY < h - 16 * Scale then
			drawWrap(self.flavorText, Color(196, 190, 178, 255))
		end
	end
end

vgui.Register("ItemAttributePanel", PANEL)

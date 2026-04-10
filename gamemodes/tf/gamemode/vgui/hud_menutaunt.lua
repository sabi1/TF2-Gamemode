local PANEL = {}

local W = ScrW()
local H = ScrH()
local Scale = H / 480

local function getTauntLoadoutClassName()
	local ply = LocalPlayer()
	if not IsValid(ply) then return "scout" end
	return tostring(ply:GetPlayerClass() or "scout")
end

local function getTauntLoadoutItems()
	local className = getTauntLoadoutClassName()
	local cv = GetConVar("loadout_taunts_" .. className)
	local raw = cv and cv:GetString() or ""
	local split = string.Split(raw, ",")
	local out = {}
	for i = 1, 8 do
		out[i] = tonumber(split[i]) or -1
	end
	return out
end

local function getItemNameById(itemId)
	if not itemId or itemId <= 0 then
		return tf_lang.GetRaw("Hud_Menu_Taunt_NoItem") or "No Item"
	end

	local item = tf_items and tf_items.ItemsByID and tf_items.ItemsByID[itemId] or nil
	if not item and tf_items and tf_items.Items then
		for _, v in pairs(tf_items.Items) do
			if istable(v) and tonumber(v.id) == itemId then
				item = v
				break
			end
		end
	end

	if not item then
		return tf_lang.GetRaw("Hud_Menu_Taunt_NoItem") or "No Item"
	end

	return tf_lang.GetRaw(item.item_name) or item.name or ("Item " .. tostring(itemId))
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(false)
	self.MenuOpen = false
	self.TauntItems = {}
	self.LastRefresh = 0
end

function PANEL:IsOpen()
	return self.MenuOpen == true
end

function PANEL:RefreshItems(force)
	if not force and self.LastRefresh > CurTime() then return end
	self.LastRefresh = CurTime() + 0.15
	self.TauntItems = getTauntLoadoutItems()
end

function PANEL:HasAnyEquippedTaunt()
	self:RefreshItems(true)
	for i = 1, 8 do
		if (tonumber(self.TauntItems[i]) or -1) > 0 then
			return true
		end
	end
	return false
end

function PANEL:Open()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return false end
	if ply:GetNWBool("Taunting") then return false end
	if ply.InCond and ply:InCond(TF_COND_HALLOWEEN_KART) then return false end
	if not self:HasAnyEquippedTaunt() then return false end

	self:RefreshItems(true)
	self.MenuOpen = true
	self:SetVisible(true)
	surface.PlaySound("ui/buttonclickrelease.wav")
	return true
end

function PANEL:Close()
	if not self.MenuOpen then return end
	self.MenuOpen = false
	self:SetVisible(false)
end

function PANEL:DoWeaponTaunt()
	RunConsoleCommand("taunt")
	self:Close()
end

function PANEL:SelectSlot(slot)
	local s = tonumber(slot)
	if not s or s < 1 or s > 8 then return false end

	self:RefreshItems()
	local itemId = tonumber(self.TauntItems[s]) or -1
	if itemId <= 0 then
		surface.PlaySound("buttons/button11.wav")
		return false
	end

	RunConsoleCommand("tf_taunt_item", tostring(itemId), tostring(s))
	self:Close()
	return true
end

function PANEL:Think()
	if not self.MenuOpen then return end

	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() or ply:GetNWBool("Taunting") then
		self:Close()
		return
	end

	self:RefreshItems(false)
end

function PANEL:PerformLayout()
	W = ScrW()
	H = ScrH()
	Scale = H / 480
	self:SetSize(560 * Scale, 230 * Scale)
	self:SetPos(W * 0.5 - self:GetWide() * 0.5, H * 0.5 - self:GetTall() * 0.5)
end

local function makeBoundText(token, bindName, fallback)
	local text = tf_lang.GetRaw(token) or fallback
	local bind = input.LookupBinding(bindName) or fallback
	bind = string.upper(bind or fallback)
	text = string.Replace(text, "%" .. string.gsub(bindName, "^%+", "") .. "%", bind)
	text = string.Replace(text, "%lastinv%", string.upper(input.LookupBinding("lastinv") or "UNBOUND"))
	return string.Replace(text, "''", "'UNBOUND'")
end

function PANEL:Paint(w, h)
	if not self.MenuOpen then return end

	draw.RoundedBox(8, 0, 0, w, h, Color(22, 17, 14, 220))
	draw.RoundedBox(8, 2 * Scale, 2 * Scale, w - 4 * Scale, h - 4 * Scale, Color(54, 45, 37, 220))

	draw.SimpleText(
		tf_lang.GetRaw("Hud_Menu_Taunt_Title") or "Taunt",
		"HudFontGiantBold",
		18 * Scale,
		18 * Scale,
		Colors and Colors.TanLight or Color(236, 227, 203, 255),
		TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP
	)

	local weaponText = makeBoundText("Hud_Menu_Taunt_Weapon", "+taunt", "Weapon Taunt")
	draw.SimpleText(
		weaponText,
		"HudFontSmall",
		w - 16 * Scale,
		22 * Scale,
		Color(224, 214, 190, 245),
		TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_TOP
	)

	local x0 = 16 * Scale
	local y0 = 56 * Scale
	local cellW = 130 * Scale
	local cellH = 66 * Scale
	local gapX = 8 * Scale
	local gapY = 8 * Scale

	for i = 1, 8 do
		local col = (i - 1) % 4
		local row = math.floor((i - 1) / 4)
		local x = x0 + col * (cellW + gapX)
		local y = y0 + row * (cellH + gapY)

		local itemId = tonumber(self.TauntItems[i]) or -1
		local isEmpty = itemId <= 0
		local bg = isEmpty and Color(52, 48, 44, 210) or Color(86, 73, 61, 220)
		draw.RoundedBox(4, x, y, cellW, cellH, bg)

		draw.SimpleText(
			tostring(i) .. ".",
			"HudFontSmallestBold",
			x + 6 * Scale,
			y + 6 * Scale,
			Color(241, 236, 222, 250),
			TEXT_ALIGN_LEFT,
			TEXT_ALIGN_TOP
		)

		local name = getItemNameById(itemId)
		draw.SimpleText(
			string.upper(name),
			"HudFontSmall",
			x + 20 * Scale,
			y + cellH * 0.5,
			isEmpty and Color(166, 156, 141, 230) or Color(235, 223, 197, 250),
			TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER
		)
	end

	local cancelText = makeBoundText("Hud_Menu_Taunt_Cancel", "lastinv", "Hit 'LASTINV' to Cancel")
	draw.SimpleText(
		cancelText,
		"SpectatorKeyHints",
		w - 16 * Scale,
		h - 16 * Scale,
		Color(240, 232, 212, 240),
		TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_BOTTOM
	)
end

if HudTauntMenu then
	HudTauntMenu:Remove()
end
HudTauntMenu = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

local PANEL = {}

local W = ScrW()
local H = ScrH()
local Scale = H/480

local delta_item_x = 28
local delta_item_start_y = 90
local delta_item_end_y = 70
local PositiveColor = Color(0, 255, 0, 255)
local NegativeColor = Color(255, 0, 0, 255)
local delta_lifetime = 1.5
local delta_item_font = "HudFontMedium"

local misc_ammo_area = {
	surface.GetTextureID("hud/misc_ammo_area_blue"),
	surface.GetTextureID("hud/misc_ammo_area_red"),
	surface.GetTextureID("hud/misc_ammo_area_blue"),
}
local ico_metal = surface.GetTextureID("hud/ico_metal_mask")

local AccountValue = {
	pos = {47.5*Scale, 125*Scale},
	font = "HudFontMediumSmall",
	color = Colors.TanLight,
	xalign = TEXT_ALIGN_CENTER,
	yalign = TEXT_ALIGN_CENTER,
}

local AccountRes = {
	delta_item_x = delta_item_x,
	delta_item_start_y = delta_item_start_y,
	delta_item_end_y = delta_item_end_y,
	delta_lifetime = delta_lifetime,
	delta_item_font = delta_item_font,
	bgX = 5,
	bgY = 103,
	bgW = 84,
	bgH = 42,
	iconX = 19,
	iconY = 116,
	iconW = 10,
	iconH = 10,
	labelX = 47.5,
	labelY = 125,
}

do
	local tree = TF2Res and TF2Res.Load and TF2Res.Load("resource/ui/hudaccountpanel.res")
	local root = tree and TF2Res.FindByKey and TF2Res.FindByKey(tree, "CHudAccountPanel")
	local bg = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "AccountBG")
	local icon = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "MetalIcon")
	local label = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "AccountValue")
	if root and TF2Res.GetNumber then
		AccountRes.delta_item_x = TF2Res.GetNumber(root, "delta_item_x", AccountRes.delta_item_x)
		AccountRes.delta_item_start_y = TF2Res.GetNumber(root, "delta_item_start_y", AccountRes.delta_item_start_y)
		AccountRes.delta_item_end_y = TF2Res.GetNumber(root, "delta_item_end_y", AccountRes.delta_item_end_y)
		AccountRes.delta_lifetime = TF2Res.GetNumber(root, "delta_lifetime", AccountRes.delta_lifetime)
		AccountRes.delta_item_font = TF2Res.GetString(root, "delta_item_font", AccountRes.delta_item_font)
		PositiveColor = TF2Res.GetColor(root, "PositiveColor", PositiveColor)
		NegativeColor = TF2Res.GetColor(root, "NegativeColor", NegativeColor)
	end
	if bg and TF2Res.GetNumber then
		AccountRes.bgX = TF2Res.GetNumber(bg, "xpos", AccountRes.bgX)
		AccountRes.bgY = TF2Res.GetNumber(bg, "ypos", AccountRes.bgY)
		AccountRes.bgW = TF2Res.GetNumber(bg, "wide", AccountRes.bgW)
		AccountRes.bgH = TF2Res.GetNumber(bg, "tall", AccountRes.bgH)
		misc_ammo_area[1] = TF2Res.GetTextureID(bg, "image", "hud/misc_ammo_area_blue")
		misc_ammo_area[2] = TF2Res.GetTextureID(bg, "teambg_2", "hud/misc_ammo_area_red")
		misc_ammo_area[3] = TF2Res.GetTextureID(bg, "teambg_3", "hud/misc_ammo_area_blue")
	end
	if icon and TF2Res.GetNumber then
		AccountRes.iconX = TF2Res.GetNumber(icon, "xpos", AccountRes.iconX)
		AccountRes.iconY = TF2Res.GetNumber(icon, "ypos", AccountRes.iconY)
		AccountRes.iconW = TF2Res.GetNumber(icon, "wide", AccountRes.iconW)
		AccountRes.iconH = TF2Res.GetNumber(icon, "tall", AccountRes.iconH)
	end
	if label and TF2Res.GetNumber then
		AccountRes.labelX = TF2Res.GetNumber(label, "xpos", 20) + TF2Res.GetNumber(label, "wide", 55) * 0.5
		AccountRes.labelY = TF2Res.GetNumber(label, "ypos", 112) + TF2Res.GetNumber(label, "tall", 26) * 0.5
		AccountValue.font = TF2Res.GetString(label, "font", AccountValue.font)
	end

	delta_item_x = AccountRes.delta_item_x
	delta_item_start_y = AccountRes.delta_item_start_y
	delta_item_end_y = AccountRes.delta_item_end_y
	delta_lifetime = AccountRes.delta_lifetime
	delta_item_font = AccountRes.delta_item_font
	AccountValue.pos = {AccountRes.labelX*Scale, AccountRes.labelY*Scale}
end

local function TFCanDrawAccountPanel()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then
		return false
	end

	if GetConVarNumber("cl_drawhud") == 0 then
		return false
	end

	if not IsCustomHUDVisible("HudAccountPanel") then
		return false
	end

	if ply.GetPlayerClass and ply:GetPlayerClass() ~= "engineer" then
		return false
	end

	if ply.InCond and TF_COND_HALLOWEEN_GHOST_MODE and ply:InCond(TF_COND_HALLOWEEN_GHOST_MODE) then
		return false
	end

	return true
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(false)
	self.Items = {}
end

function PANEL:AddItem(value)
	if value == 0 then return end

	if self.Items[1] and CurTime() + delta_lifetime - self.Items[1][2] < 0.001 then
		self.Items[1][1] = self.Items[1][1] + value
	else
		table.insert(self.Items, 1, {value, CurTime() + delta_lifetime})
	end

	self:SetVisible(true)
end

function PANEL:PerformLayout()
	self:SetPos(W-162*Scale,H-152*Scale)
	self:SetSize(116*Scale,180*Scale)
end

function PANEL:PruneExpiredItems()
	local now = CurTime()

	for i = #self.Items, 1, -1 do
		if self.Items[i][2] <= now then
			table.remove(self.Items, i)
		end
	end
end

function PANEL:Paint()
	self:PruneExpiredItems()

	if not TFCanDrawAccountPanel() then
		self.Items = {}
		self:SetVisible(false)
		return
	end

	self:SetVisible(true)

	local n = LocalPlayer():GetAmmoCount(TF_METAL)
	local t = LocalPlayer():Team()

	local tex = misc_ammo_area[t] or misc_ammo_area[1]
	surface.SetDrawColor(color_white)

	surface.SetTexture(tex)
	surface.DrawTexturedRect(AccountRes.bgX*Scale, AccountRes.bgY*Scale, AccountRes.bgW*Scale, AccountRes.bgH*Scale)

	surface.SetTexture(ico_metal)
	surface.SetDrawColor(Colors.ProgressOffWhite)
	surface.DrawTexturedRect(AccountRes.iconX*Scale, AccountRes.iconY*Scale, AccountRes.iconW*Scale, AccountRes.iconH*Scale)
	surface.SetDrawColor(color_white)

	AccountValue.text = n
	draw.Text(AccountValue)

	for i = 1, #self.Items do
		local item = self.Items[i]
		local diff = item[2] - CurTime()
		local ratio = math.Clamp(diff / delta_lifetime, 0, 1)
		local alpha = Lerp(ratio, 0, 255)
		local y = Lerp(ratio, delta_item_end_y, delta_item_start_y)
		local col, txt

		if item[1] > 0 then
			txt = "+"..tostring(item[1])
			col = Color(PositiveColor.r, PositiveColor.g, PositiveColor.b, alpha)
		else
			txt = tostring(item[1])
			col = Color(NegativeColor.r, NegativeColor.g, NegativeColor.b, alpha)
		end

		draw.Text{
			text=txt,
			font=delta_item_font,
			pos={delta_item_x*Scale, y*Scale},
			color=col,
			xalign=TEXT_ALIGN_LEFT,
			yalign=TEXT_ALIGN_TOP,
		}
	end
end

if HudAccountPanel then HudAccountPanel:Remove() end
HudAccountPanel = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

usermessage.Hook("PlayerMetalBonus", function(msg)
	HudAccountPanel:AddItem(msg:ReadShort())
end)

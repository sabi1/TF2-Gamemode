local W = ScrW()
local H = ScrH()
local Scale = H/480

local health_bg = surface.GetTextureID("hud/health_bg")
local health_color = surface.GetTextureID("hud/health_color")
local health_over_bg = surface.GetTextureID("hud/health_over_bg")
local health_dead = surface.GetTextureID("hud/health_dead")

local delta_item_x = 13
local delta_item_start_y = 50
local delta_item_end_y = 0
local PositiveColor = Color(0, 255, 0, 255)
local NegativeColor = Color(255, 0, 0, 255)
local delta_lifetime = 1.5
local delta_item_font = "HudFontMedium"

do
	local tree = TF2Res and TF2Res.Load and TF2Res.Load("resource/ui/hudhealthaccount.res")
	local root = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "CHealthAccountPanel")
	if root and TF2Res.GetNumber then
		delta_item_x = TF2Res.GetNumber(root, "delta_item_x", delta_item_x)
		delta_item_start_y = TF2Res.GetNumber(root, "delta_item_start_y", delta_item_start_y)
		delta_item_end_y = TF2Res.GetNumber(root, "delta_item_end_y", delta_item_end_y)
		delta_lifetime = TF2Res.GetNumber(root, "delta_lifetime", delta_lifetime)
		delta_item_font = TF2Res.GetString(root, "delta_item_font", delta_item_font)
		PositiveColor = TF2Res.GetColor(root, "PositiveColor", PositiveColor)
		NegativeColor = TF2Res.GetColor(root, "NegativeColor", NegativeColor)
	end
end
		
local PANEL = {}

local function TFCanDrawHealthAccount()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() or ply:Team() == TEAM_SPECTATOR then
		return false
	end

	if GetConVarNumber("cl_drawhud") == 0 then
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
	self:SetPos(76*Scale,(480-152)*Scale)
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

	if not TFCanDrawHealthAccount() then
		self.Items = {}
		self:SetVisible(false)
		return
	end

	if #self.Items == 0 then
		self:SetVisible(false)
		return
	end

	self:SetVisible(true)

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

if HudHealthAccount then HudHealthAccount:Remove() end
HudHealthAccount = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

usermessage.Hook("PlayerHealthBonus", function(msg)
	HudHealthAccount:AddItem(msg:ReadShort())
end)

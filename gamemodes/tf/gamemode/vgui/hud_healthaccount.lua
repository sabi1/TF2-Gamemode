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

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
	self.Items = {}
end

function PANEL:AddItem(value)
	if value~=0 then
		if self.Items[1] and CurTime() + delta_lifetime - self.Items[1][2] < 0.001 then
			self.Items[1][1] = self.Items[1][1] + value
		else
			table.insert(self.Items, 1, {value, CurTime() + delta_lifetime})
		end
	end
end

function PANEL:PerformLayout()
	self:SetPos(76*Scale,(480-152)*Scale)
	self:SetSize(116*Scale,180*Scale)
end

function PANEL:Paint()
	if not LocalPlayer():Alive() or GetConVarNumber("cl_drawhud")==0 or LocalPlayer():Team() == TEAM_SPECTATOR then return end
	
	for k,v in ipairs(self.Items) do
		local diff = v[2] - CurTime()
		if diff<=0 then
			self.Items[k] = nil
		else
			local ratio = math.Clamp(diff / delta_lifetime, 0, 1)
			local alpha = Lerp(ratio, 0, 255)
			local y = Lerp(ratio, delta_item_end_y, delta_item_start_y)
			local col, txt
			
			if v[1]>0 then
				txt = "+"..tostring(v[1])
				col = Color(PositiveColor.r, PositiveColor.g, PositiveColor.b, alpha)
			else
				txt = tostring(v[1])
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
end

if HudHealthAccount then HudHealthAccount:Remove() end
HudHealthAccount = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

usermessage.Hook("PlayerHealthBonus", function(msg)
	HudHealthAccount:AddItem(msg:ReadShort())
end)

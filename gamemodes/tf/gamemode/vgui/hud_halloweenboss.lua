local PANEL = {}

local BossHudState = {
	active = false,
	entIndex = -1,
	scenario = "",
	health = 0,
	maxHealth = 0,
	truceActive = false,
}

local BossHudRes = {
	x = 170,
	y = 22,
	w = 200,
	h = 50,
	labelGap = 4,
	barX = 15,
	barY = 16,
	barW = 168,
	barH = 18,
	stunX = 50,
	stunY = 19,
	stunW = 100,
	stunH = 8,
	borderTex = -1,
	barTex = -1,
}

local function LocalizeBossName(scenario)
	if scenario == "mann_manor" then
		return "Horseless Headless Horsemann"
	end
	if scenario == "viaduct" then
		return "MONOCULUS!"
	end
	if scenario == "lakeside" then
		return "MERASMUS!"
	end
	if scenario == "hightower" then
		return "SKELETON KING"
	end
	return "Boss"
end

do
	local tree = TF2Res and TF2Res.Load and TF2Res.Load("resource/ui/hudbosshealth.res")
	local border = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "BorderImage")
	local healthBar = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "HealthBarPanel")
	local barImage = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "BarImage")
	local stun = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "StunMeter")
	if border and TF2Res.GetNumber then
		BossHudRes.w = TF2Res.GetNumber(border, "wide", BossHudRes.w)
		BossHudRes.h = TF2Res.GetNumber(border, "tall", BossHudRes.h)
	end
	if healthBar and TF2Res.GetNumber then
		BossHudRes.barX = TF2Res.GetNumber(healthBar, "xpos", BossHudRes.barX)
		BossHudRes.barY = TF2Res.GetNumber(healthBar, "ypos", BossHudRes.barY)
		BossHudRes.barW = TF2Res.GetNumber(healthBar, "wide", BossHudRes.barW)
		BossHudRes.barH = TF2Res.GetNumber(healthBar, "tall", BossHudRes.barH)
	end
	if stun and TF2Res.GetNumber then
		BossHudRes.stunX = TF2Res.GetNumber(stun, "xpos", BossHudRes.stunX)
		BossHudRes.stunY = TF2Res.GetNumber(stun, "ypos", BossHudRes.stunY)
		BossHudRes.stunW = TF2Res.GetNumber(stun, "wide", BossHudRes.stunW)
		BossHudRes.stunH = TF2Res.GetNumber(stun, "tall", BossHudRes.stunH)
	end
	if border and TF2Res.GetTextureID then
		BossHudRes.borderTex = TF2Res.GetTextureID(border, "image", "")
	end
	if barImage and TF2Res.GetTextureID then
		BossHudRes.barTex = TF2Res.GetTextureID(barImage, "image", "")
	end
end

net.Receive("TF_HalloweenBossHudState", function()
	BossHudState.active = net.ReadBool()
	BossHudState.entIndex = net.ReadInt(16)
	BossHudState.scenario = net.ReadString()
	BossHudState.health = math.max(0, net.ReadInt(32))
	BossHudState.maxHealth = math.max(0, net.ReadInt(32))
	BossHudState.truceActive = net.ReadBool()
end)

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
end

function PANEL:PerformLayout()
	local scale = ScrH() / 480
	local w = BossHudRes.w * scale
	local h = (BossHudRes.h + 28) * scale
	local x = (ScrW() - w) * 0.5
	self:SetPos(x, BossHudRes.y * scale)
	self:SetSize(w, h)
end

function PANEL:Paint()
	if not BossHudState.active then return end
	if BossHudState.maxHealth <= 0 then return end
	if GetConVar("cl_drawhud") and GetConVar("cl_drawhud"):GetInt() == 0 then return end

	local scale = ScrH() / 480
	local x = 0
	local y = 0
	local w = BossHudRes.w * scale
	local h = BossHudRes.h * scale
	local barX = BossHudRes.barX * scale
	local barY = BossHudRes.barY * scale
	local barW = BossHudRes.barW * scale
	local barH = BossHudRes.barH * scale
	local frac = math.Clamp(BossHudState.health / math.max(BossHudState.maxHealth, 1), 0, 1)
	local name = LocalizeBossName(BossHudState.scenario)

	if BossHudRes.barTex and BossHudRes.barTex >= 0 then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetTexture(BossHudRes.barTex)
		surface.DrawTexturedRectUV(x + barX, y + barY, barW * frac, barH, 0, 0, frac, 1)
	end

	if BossHudRes.borderTex and BossHudRes.borderTex >= 0 then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetTexture(BossHudRes.borderTex)
		surface.DrawTexturedRect(x, y, w, h)
	end

	draw.Text{
		text = name,
		font = "HudFontSmallestBold",
		pos = {x + w * 0.5, y - BossHudRes.labelGap * scale},
		color = Colors.TanLight,
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_BOTTOM,
	}

	draw.Text{
		text = string.format("%d / %d", BossHudState.health, BossHudState.maxHealth),
		font = "TFDefaultSmall",
		pos = {x + barX + barW * 0.5, y + barY + barH * 0.5},
		color = color_white,
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	}

	if BossHudState.truceActive then
		draw.Text{
			text = "TRUCE ACTIVE",
			font = "ClockSubTextTiny",
			pos = {x + w * 0.5, y + h + 2 * scale},
			color = Color(255, 220, 120, 255),
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_TOP,
		}
	end
end

if HudHalloweenBoss then HudHalloweenBoss:Remove() end
HudHalloweenBoss = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

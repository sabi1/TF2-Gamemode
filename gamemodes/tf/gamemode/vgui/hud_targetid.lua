local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local hud_targetid_numerichealth = CreateConVar("hud_targetid_numerichealth", "1")

local color_panel = {
	surface.GetTextureID("hud/color_panel_brown"),
	surface.GetTextureID("hud/color_panel_red"),
	surface.GetTextureID("hud/color_panel_blu"),
	surface.GetTextureID("hud/color_panel_ylw"),
	surface.GetTextureID("hud/color_panel_grn"),
}

local TargetRes = {
	panelW = 252,
	panelH = 50,
	baseX = 0,
	baseY = 250,
	bgTall = 35,
	bgCorner = 23,
	bgDrawCorner = 5,
	healthX = 3,
	healthY = 2,
	nameX = 34,
	nameY = 4,
	dataX = 34,
	dataY = 20.5,
}

local function localize_token(token, fallback)
	local text = language.GetPhrase(token or "")
	if not isstring(text) or text == "" or text == token then
		return fallback or ""
	end
	return text
end

local function build_disguise_status_text(target, viewer, disguisedEnemy, disguisedAsEnemy)
	local classDisplay = string.Trim(target:GetNWString("TFSpyDisguiseClassDisplay", ""))
	if classDisplay == "" then
		classDisplay = string.Trim(target:GetNWString("TFSpyDisguiseClass", ""))
	end
	if classDisplay == "" then return nil end

	local alignmentToken = "TF_enemy"
	if not disguisedEnemy then
		alignmentToken = disguisedAsEnemy and "TF_enemy" or "TF_friendly"
	end

	local formatText = localize_token("TF_playerid_friendlyspy_disguise", "Disguised as %s1 %s2")
	local alignmentText = localize_token(alignmentToken, alignmentToken == "TF_friendly" and "friendly" or "enemy")
	local out = string.Replace(formatText, "%s1", alignmentText)
	out = string.Replace(out, "%s2", classDisplay)
	return out
end

local function get_disguise_targetid_info(target, viewer)
	if not IsValid(target) or not target:IsPlayer() then return nil end
	if not IsValid(viewer) or not viewer:IsPlayer() then return nil end
	if not target:GetNWBool("Disguised", false) or target:GetNWBool("Cloaked", false) then return nil end

	local disguiseTeam = tonumber(target:GetNWInt("TFSpyDisguiseTeam", -1)) or -1
	if disguiseTeam < 0 then return nil end

	local disguisedEnemy = target:Team() ~= viewer:Team()
	if disguisedEnemy and disguiseTeam ~= viewer:Team() then
		return nil
	end

	local disguisedAsEnemy = (disguiseTeam ~= target:Team())
	local dataText = nil
	if not disguisedEnemy then
		dataText = build_disguise_status_text(target, viewer, false, disguisedAsEnemy)
	elseif string.lower(string.Trim(target:GetNWString("TFSpyDisguiseClass", ""))) == "spy" then
		dataText = build_disguise_status_text(target, viewer, true, true)
	end

	local health = target:Health()
	local maxhealth = target:GetMaxHealth()
	if disguisedEnemy then
		local fakeHealth = tonumber(target:GetNWInt("TFSpyDisguiseHealth", 0)) or 0
		local fakeMaxHealth = tonumber(target:GetNWInt("TFSpyDisguiseMaxHealth", 0)) or 0
		if fakeMaxHealth > 0 then
			health = math.max(fakeHealth, 0)
			maxhealth = fakeMaxHealth
		end
	end

	return {
		health = health,
		maxhealth = math.max(maxhealth, 1),
		dataText = dataText,
	}
end

do
	local tree = TF2Res and TF2Res.Load and TF2Res.Load("resource/ui/targetid.res")
	local bg = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "TargetIDBG")
	local name = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "TargetNameLabel")
	local data = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "TargetDataLabel")
	local health = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "SpectatorGUIHealth")
	if bg and TF2Res.GetNumber then
		TargetRes.panelW = TF2Res.GetNumber(bg, "wide", TargetRes.panelW)
		TargetRes.panelH = math.max(TargetRes.panelH, TF2Res.GetNumber(bg, "tall", TargetRes.panelH))
		TargetRes.bgTall = TF2Res.GetNumber(bg, "tall", TargetRes.bgTall)
		TargetRes.bgCorner = TF2Res.GetNumber(bg, "src_corner_width", TargetRes.bgCorner)
		TargetRes.bgDrawCorner = TF2Res.GetNumber(bg, "draw_corner_width", TargetRes.bgDrawCorner)
		color_panel[1] = TF2Res.GetTextureID(bg, "teambg_1", "hud/color_panel_brown")
		color_panel[2] = TF2Res.GetTextureID(bg, "teambg_2", "hud/color_panel_red")
		color_panel[3] = TF2Res.GetTextureID(bg, "teambg_3", "hud/color_panel_blu")
	end
	if name and TF2Res.GetNumber then
		TargetRes.nameX = TF2Res.GetNumber(name, "xpos", 8) + 26
		TargetRes.nameY = TF2Res.GetNumber(name, "ypos", 5) - 1
	end
	if data and TF2Res.GetNumber then
		TargetRes.dataX = TF2Res.GetNumber(data, "xpos", 8) + 26
		TargetRes.dataY = TF2Res.GetNumber(data, "ypos", 17) + 3.5
	end
	if health and TF2Res.GetNumber then
		TargetRes.healthX = TF2Res.GetNumber(health, "xpos", TargetRes.healthX)
		TargetRes.healthY = TF2Res.GetNumber(health, "ypos", TargetRes.healthY)
	end
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(false)
end

function PANEL:PerformLayout()
	if not IsValid(self.Target) then
		self:SetPos(W/2-(TargetRes.panelW*WScale)/2,TargetRes.baseY*Scale)
		self:SetSize(TargetRes.panelW*WScale,TargetRes.panelH*Scale)
	else
		local slot = self.Slot
			while HudTargetIDs[slot-1] and not HudTargetIDs[slot-1]:IsVisible() do
				slot = slot - 1
			end
		surface.SetFont("HudFontMediumSmallSecondary")
		local w = surface.GetTextSize(GAMEMODE:EntityTargetIDName(self.Target)) + 44*Scale
		if self.Text then
			w = w + surface.GetTextSize(self.Text)
		end
		
		self:SetSize(w, TargetRes.panelH*Scale)
		self:SetPos((W-w)/2, (TargetRes.baseY + TargetRes.panelH * (slot-1))*Scale)
	end
end

function PANEL:SetTargetEntity(e)
	self.Target = e
	
	if not self.HealthCounter then
		self.HealthCounter = vgui.Create("SpectatorGUIHealth")
		self.HealthCounter:SetParent(self)
		self.HealthCounter:SetPos(TargetRes.healthX*Scale,TargetRes.healthY*Scale)

	end
	
	for _,v in ipairs(HudTargetIDs) do v:InvalidateLayout() end
	local viewer = LocalPlayer()
	local disguiseInfo = get_disguise_targetid_info(e, viewer)
	if disguiseInfo then
		self.HealthCounter:SetTargetEntity(e, false, disguiseInfo.health, disguiseInfo.maxhealth, e.IsTFBuilding)
	else
		self.HealthCounter:SetTargetEntity(e)
	end
end

function PANEL:Paint()
	if GetConVarNumber("cl_drawhud")==0 then return end
	
	if not IsValid(self.Target) then
		return
	end

	local viewer = LocalPlayer()
	local disguiseInfo = get_disguise_targetid_info(self.Target, viewer)
	local health = disguiseInfo and disguiseInfo.health or self.Target:Health()
	local maxhealth = disguiseInfo and disguiseInfo.maxhealth or self.Target:GetMaxHealth()
	local dataText = disguiseInfo and disguiseInfo.dataText or nil
	if IsValid(self.HealthCounter) then
		if disguiseInfo then
			self.HealthCounter:SetTargetEntity(self.Target, false, health, maxhealth, self.Target.IsTFBuilding)
		else
			self.HealthCounter:SetTargetEntity(self.Target)
		end
	end

	local panelTeam = GAMEMODE.GetEntityVisibleTeamForViewer and GAMEMODE:GetEntityVisibleTeamForViewer(self.Target, viewer) or self.Target:EntityTeam()
	surface.SetDrawColor(255,255,255,255)
		tf_draw.BorderPanel(color_panel[panelTeam] or color_panel[0],0,0,self:GetWide(),TargetRes.bgTall*Scale,TargetRes.bgCorner,TargetRes.bgCorner,TargetRes.bgDrawCorner*Scale,TargetRes.bgDrawCorner*Scale)
	
	local tbl = {
		font="HudFontMediumSmallSecondary",
		pos={TargetRes.nameX*Scale, TargetRes.nameY*Scale},
		color=Colors.TanLight,
		x_align=TEXT_ALIGN_LEFT,
		y_align=TEXT_ALIGN_TOP,
	}
	if self.Text then
		tbl.text = self.Text
		draw.Text(tbl)
		
		surface.SetFont(tbl.font)
		tbl.pos[1] = tbl.pos[1] + surface.GetTextSize(self.Text)
	end
	
	--tbl.text = GAMEMODE:EntityName(self.Target)
	if self.Target:GetClass() == "reviver" then
		tbl.text = GAMEMODE:EntityTargetIDName(self.Target:GetOwner())
		draw.Text(tbl)
	elseif self.Target:IsNextBot() then
		tbl.text = GAMEMODE:EntityTargetIDName(self.Target)
		draw.Text(tbl)	
	else
		tbl.text = GAMEMODE:EntityTargetIDName(self.Target)
		draw.Text(tbl)	
	end
	if self.Target.IsTFBuilding then
		draw.Text{
			text=tostring(self.Target:GetTargetIDSubText() or ""),
			font="TFFontMedium",
			pos={TargetRes.dataX*Scale, TargetRes.dataY*Scale},
			color=Colors.TanLight,
			x_align=TEXT_ALIGN_LEFT,
			y_align=TEXT_ALIGN_CENTER,
		}
	elseif isstring(dataText) and dataText ~= "" then
		draw.Text{
			text=dataText,
			font="TFFontMedium",
			pos={TargetRes.dataX*Scale, TargetRes.dataY*Scale},
			color=Colors.TanLight,
			x_align=TEXT_ALIGN_LEFT,
			y_align=TEXT_ALIGN_CENTER,
		}
	elseif hud_targetid_numerichealth:GetBool() then
		draw.Text{
			text=health.."/"..maxhealth,
			font="TFFontMedium",
			pos={TargetRes.dataX*Scale, TargetRes.dataY*Scale},
			color=Colors.TanLight,
			x_align=TEXT_ALIGN_LEFT,
			y_align=TEXT_ALIGN_CENTER,
			
		}
	end
end

if HudTargetID then HudTargetID:Remove() end
HudTargetID = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))
HudTargetID.Slot = 1

if HudHealingTargetID then HudHealingTargetID:Remove() end
HudHealingTargetID = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))
HudHealingTargetID.Text = "Healing : "
HudHealingTargetID.Slot = 2

if HudHealerTargetID then HudHealerTargetID:Remove() end
HudHealerTargetID = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))
HudHealerTargetID.Text = "Healer : "
HudHealerTargetID.Slot = 3

HudTargetIDs = {HudTargetID, HudHealingTargetID, HudHealerTargetID}

local W = ScrW()
local H = ScrH()
local Scale = H/480

local health_bg = surface.GetTextureID("hud/health_bg")
local health_color = surface.GetTextureID("hud/health_color")
local health_over_bg = surface.GetTextureID("hud/health_over_bg")
local health_dead = surface.GetTextureID("hud/health_dead")
local bleed_drop = surface.GetTextureID("vgui/bleed_drop")
local marked_for_death = surface.GetTextureID("vgui/marked_for_death")
local slowed = surface.GetTextureID("vgui/slowed")

local HealthRes = {
	panelX = 0,
	panelY = 360,
	panelW = 250,
	panelH = 120,
	deathWarning = 0.49,
	bgX = 73,
	bgY = 33,
	bgW = 55,
	bgH = 55,
	fillX = 75,
	fillY = 35,
	fillW = 51,
	fillH = 51,
	valueX = 101,
	valueY = 61,
	maxX = 101,
	maxY = 29,
	statusX = 101,
	statusY = 27,
	statusW = 32,
	statusH = 32,
}

do
	local tree = TF2Res and TF2Res.Load and TF2Res.Load("resource/ui/hudplayerhealth.res")
	local root = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "HudPlayerHealth")
	local bg = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "PlayerStatusHealthImageBG")
	local fill = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "PlayerStatusHealthImage")
	local bonus = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "PlayerStatusHealthBonusImage")
	local value = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "PlayerStatusHealthValue")
	local maxValue = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "PlayerStatusMaxHealthValue")
	local status = tree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(tree, "PlayerStatusBleedImage")
	if root and TF2Res.GetNumber then
		HealthRes.panelX = TF2Res.GetNumber(root, "xpos", HealthRes.panelX)
		HealthRes.panelY = 480 - TF2Res.GetNumber(root, "tall", HealthRes.panelH)
		HealthRes.panelW = TF2Res.GetNumber(root, "wide", HealthRes.panelW)
		HealthRes.panelH = TF2Res.GetNumber(root, "tall", HealthRes.panelH)
		HealthRes.deathWarning = TF2Res.GetNumber(root, "HealthDeathWarning", HealthRes.deathWarning)
	end
	if bg and TF2Res.GetNumber then
		HealthRes.bgX = TF2Res.GetNumber(bg, "xpos", HealthRes.bgX)
		HealthRes.bgY = TF2Res.GetNumber(bg, "ypos", HealthRes.bgY)
		HealthRes.bgW = TF2Res.GetNumber(bg, "wide", HealthRes.bgW)
		HealthRes.bgH = TF2Res.GetNumber(bg, "tall", HealthRes.bgH)
		health_bg = TF2Res.GetTextureID(bg, "image", "hud/health_bg")
	end
	if fill and TF2Res.GetNumber then
		HealthRes.fillX = TF2Res.GetNumber(fill, "xpos", HealthRes.fillX)
		HealthRes.fillY = TF2Res.GetNumber(fill, "ypos", HealthRes.fillY)
		HealthRes.fillW = TF2Res.GetNumber(fill, "wide", HealthRes.fillW)
		HealthRes.fillH = TF2Res.GetNumber(fill, "tall", HealthRes.fillH)
	end
	if bonus and TF2Res.GetNumber then
		health_over_bg = TF2Res.GetTextureID(bonus, "image", "hud/health_over_bg")
	end
	if value and TF2Res.GetNumber then
		HealthRes.valueX = TF2Res.GetNumber(value, "xpos", 76) + TF2Res.GetNumber(value, "wide", 50) * 0.5
		HealthRes.valueY = TF2Res.GetNumber(value, "ypos", 52) + 9
	end
	if maxValue and TF2Res.GetNumber then
		HealthRes.maxX = TF2Res.GetNumber(maxValue, "xpos", 76) + TF2Res.GetNumber(maxValue, "wide", 50) * 0.5
		HealthRes.maxY = TF2Res.GetNumber(maxValue, "ypos", 20) + 9
	end
	if status and TF2Res.GetNumber then
		HealthRes.statusX = TF2Res.GetNumber(status, "xpos", 85) + 16
		HealthRes.statusY = TF2Res.GetNumber(status, "ypos", 0) + 16
		HealthRes.statusW = TF2Res.GetNumber(status, "wide", 32)
		HealthRes.statusH = TF2Res.GetNumber(status, "tall", 32)
		bleed_drop = TF2Res.GetTextureID(status, "image", "vgui/bleed_drop")
	end
end

local PANEL = {}

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
end

function PANEL:PerformLayout()
	self:SetPos(HealthRes.panelX*Scale,HealthRes.panelY*Scale)
	self:SetSize(HealthRes.panelW*Scale,HealthRes.panelH*Scale)
end

function PANEL:Paint()
	if not LocalPlayer():Alive() or LocalPlayer():IsHL2() or GetConVar("tf_forcehl2hud"):GetBool() or GAMEMODE.ShowScoreboard or GetConVarNumber("cl_drawhud")==0 or LocalPlayer():Team() == TEAM_SPECTATOR or LocalPlayer():GetPlayerClass()=="" then return end
	
	local size, amplitude, frequency
	local healthOwner = LocalPlayer()
	local health = healthOwner:Health()

	if LocalPlayer():GetObserverTarget() and LocalPlayer():GetObserverTarget():IsPlayer() then
		healthOwner = LocalPlayer():GetObserverTarget()
		health = healthOwner:Health()
	end
	
	if health<=0 then
		surface.SetTexture(health_dead)
		surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(73*Scale, 33*Scale, 55*Scale, 55*Scale)
		return
	end
	
	--[[local tbl = LocalPlayer():GetPlayerClassTable()
	local maxhealth = 100
	
	if tbl and tbl.Health then
		maxhealth = tbl.Health
	end
	
	maxhealth = maxhealth + LocalPlayer():GetNWInt("PlayerMaxHealthBuff")]]
	local maxhealth = healthOwner:GetMaxHealth()
	
	local ratio = math.Clamp(health/maxhealth,0,1)
	
	--local tbl = LocalPlayer():GetPlayerClassTable()
	
	if (1 - HealthRes.deathWarning) * health < HealthRes.deathWarning * maxhealth then -- Low health warning
		size = (maxhealth - 2*health)/maxhealth
		frequency = 20
		amplitude = math.Clamp(size*127, 0, 127)
		
		surface.SetTexture(health_over_bg)
		surface.SetDrawColor(255,0,0,128+amplitude*math.sin(frequency*CurTime()))
		surface.DrawTexturedRect((73-size*27.5)*Scale, (33-size*27.5)*Scale, (1+size)*55*Scale, (1+size)*55*Scale)
	elseif health>maxhealth then -- Overheal
		size = (health-maxhealth)/maxhealth
		frequency = 20
		amplitude = math.Clamp(size*127, 0, 127)
		
		surface.SetTexture(health_over_bg)
		surface.SetDrawColor(255,255,255,128+amplitude*math.sin(frequency*CurTime()))
		surface.DrawTexturedRect((73-size*27.5)*Scale, (33-size*27.5)*Scale, (1+size)*55*Scale, (1+size)*55*Scale)
	end
	
	surface.SetTexture(health_bg)
	surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(HealthRes.bgX*Scale, HealthRes.bgY*Scale, HealthRes.bgW*Scale, HealthRes.bgH*Scale)
	
	local x,y,w,h = math.floor(HealthRes.fillX*Scale), math.floor(HealthRes.fillY*Scale), math.floor(HealthRes.fillW*Scale), math.floor(HealthRes.fillH*Scale)
	surface.SetTexture(health_color)
	
	if (1 - HealthRes.deathWarning) * health < HealthRes.deathWarning * maxhealth then
		surface.SetDrawColor(255,0,0,255)
	else
		surface.SetDrawColor(255,255,255,255)
	end
	
	local y2 = y+h*(1-ratio)
	
	tf_draw.TexturedQuadPart(health_color, x, y2, w, (y+h)-y2, 0, 128*(1-ratio), 128, 128*ratio)
	
	--[[
	render.SetViewPort(x0+x,y0+y2,w,(y+h)-y2)
	cam.Start2D()
		surface.DrawTexturedRect(0,y-y2,w,h)
	cam.End2D()
	render.SetViewPort(0,0,W,H)]]
	
	draw.Text{
		text=health,
		font="HudClassHealth",
		pos={HealthRes.valueX*Scale, HealthRes.valueY*Scale},
		color=Colors.TanDark,
		xalign=TEXT_ALIGN_CENTER,
		yalign=TEXT_ALIGN_CENTER,
	}
	if health and maxhealth then
	----print(health-maxhealth)
		if (maxhealth - health) >= 5 and GetConVar("tf_maxhealth_hud"):GetInt() ~= 0 then
		--	--print(health-maxhealth+5)
		--	--print(health)
		--	--print(maxhealth)
			draw.Text{
				text=maxhealth,
				font="HudClassHealthMax",
				pos={HealthRes.maxX*Scale, HealthRes.maxY*Scale},
				color=Colors.TanDark,
				xalign=TEXT_ALIGN_CENTER,
				yalign=TEXT_ALIGN_CENTER,
			}
		end
	end

	local droplet_x = (HealthRes.statusX - 16) * Scale
	
	if healthOwner:HasPlayerState(PLAYERSTATE_MARKED) then
		surface.SetTexture(marked_for_death)
		surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(droplet_x, (HealthRes.statusY)*Scale, HealthRes.statusW*Scale, HealthRes.statusH*Scale)
		droplet_x = droplet_x + 30 * Scale
	end
	if healthOwner:HasPlayerState(PLAYERSTATE_BLEEDING) then
		surface.SetTexture(bleed_drop)
		surface.SetDrawColor(255,0,0,255)
		surface.DrawTexturedRect(droplet_x, (HealthRes.statusY)*Scale, HealthRes.statusW*Scale, HealthRes.statusH*Scale)
		droplet_x = droplet_x + 30 * Scale
	end
	
	if healthOwner:HasPlayerState(PLAYERSTATE_MILK) then
		surface.SetTexture(bleed_drop)
		surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(droplet_x, (HealthRes.statusY)*Scale, HealthRes.statusW*Scale, HealthRes.statusH*Scale)
		droplet_x = droplet_x + 30 * Scale
	end
	if healthOwner:HasPlayerState(PLAYERSTATE_JARATED) then
		surface.SetTexture(bleed_drop)
		surface.SetDrawColor(255,255,0,255)
		surface.DrawTexturedRect(droplet_x, (HealthRes.statusY)*Scale, HealthRes.statusW*Scale, HealthRes.statusH*Scale)
		droplet_x = droplet_x + 30 * Scale
	end
	if healthOwner:HasPlayerState(PLAYERSTATE_PUKEDON) then
		surface.SetTexture(bleed_drop)
		surface.SetDrawColor(0,100,0,255)
		surface.DrawTexturedRect(droplet_x, (HealthRes.statusY)*Scale, HealthRes.statusW*Scale, HealthRes.statusH*Scale)
		droplet_x = droplet_x + 30 * Scale
	end
	if healthOwner:HasPlayerState(PLAYERSTATE_STUNNED) then
		surface.SetTexture(slowed)
		surface.SetDrawColor(255,255,0,255)
		surface.DrawTexturedRect(droplet_x, (HealthRes.statusY)*Scale, HealthRes.statusW*Scale, HealthRes.statusH*Scale)
		droplet_x = droplet_x + 30 * Scale
	end
end

if HudPlayerHealth then HudPlayerHealth:Remove() end
HudPlayerHealth = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

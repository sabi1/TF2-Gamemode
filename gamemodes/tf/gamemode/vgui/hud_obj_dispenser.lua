
local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local obj_status_ammo = surface.GetTextureID("hud/hud_obj_status_ammo_64")
local ico_metal = surface.GetTextureID("hud/ico_metal_mask")

local PANEL = {}

PANEL.PanelType = 1
PANEL.BuildingClass = "obj_dispenser"
PANEL.ObjectIcon = {
	surface.GetTextureID("hud/hud_obj_status_dispenser");
}

PANEL.Lang_NotBuilt = "#Building_hud_dispenser_not_built"

function PANEL:PaintActive()
	local level = self.TargetEntity:GetLevel()
	
	-- active
	surface.SetDrawColor(Colors.TransparentYellow)
	surface.DrawRect(72*Scale, 6*Scale, 38*Scale, 8*Scale)
	surface.DrawRect(72*Scale, 17*Scale, 38*Scale, 8*Scale)
	
	-- Dispenser stored metal (separate from building upgrade metal).
	local maxMetal = tonumber(self.TargetEntity.MaxMetal) or 400
	local storedMetal = 0
	if self.TargetEntity.GetMetalAmount then
		storedMetal = tonumber(self.TargetEntity:GetMetalAmount() or 0) or 0
	end
	local storedProgress = math.Clamp(storedMetal / maxMetal, 0, 1)
	if storedProgress > 0 then
		surface.SetDrawColor(Colors.Yellow)
		surface.DrawRect(72*Scale, 6*Scale, 38*Scale*storedProgress, 8*Scale)
	end
	
	-- Building upgrade progress.
	local upgradeCost = tonumber(self.TargetEntity.UpgradeCost) or 200
	local upgradeMetal = tonumber(self.TargetEntity:GetMetal() or 0) or 0
	local upgradeProgress = 0
	if level >= (tonumber(self.TargetEntity.NumLevels) or 3) then
		upgradeProgress = 1
	elseif upgradeCost > 0 then
		upgradeProgress = math.Clamp(upgradeMetal / upgradeCost, 0, 1)
	end
	if upgradeProgress > 0 then
		surface.SetDrawColor(Colors.Yellow)
		surface.DrawRect(72*Scale, 17*Scale, 38*Scale*upgradeProgress, 8*Scale)
	end
	
	surface.SetDrawColor(Colors.ProgressOffWhite)
	
	surface.SetTexture(obj_status_ammo)
	surface.DrawTexturedRect(60*Scale, 5*Scale, 10*Scale, 10*Scale)
	
	surface.SetTexture(ico_metal)
	surface.DrawTexturedRect(60*Scale, 16*Scale, 10*Scale, 10*Scale)
end

if HudObjDispenser then HudObjDispenser:Remove() end
HudObjDispenser = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "HudObjBase"))

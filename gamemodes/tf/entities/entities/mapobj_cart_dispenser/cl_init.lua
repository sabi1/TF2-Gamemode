
include("shared.lua")

ENT.RenderGroup = RENDERGROUP_BOTH

local ScreenTexture = {
	[0]=surface.GetTextureID("vgui/dispenser_meter_bg_red"),
	[1]=surface.GetTextureID("vgui/dispenser_meter_bg_blue"),
}
local ArrowTexture = surface.GetTextureID("vgui/dispenser_meter_arrow")
local Offset = Vector(-1.1, -11, -0.6)
local Scale=0.0465
local AngleStart = 85
local AngleEnd = -85

function ENT:CalcAngle(m)
	return Lerp(math.Clamp(tonumber(m) or 0, 0, 1), AngleStart, AngleEnd)
end

local function ResolveControlPanelAttachment(ent, name)
	if not IsValid(ent) then return nil end
	local id = ent:LookupAttachment(name)
	if not isnumber(id) or id <= 0 then return nil end
	return ent:GetAttachment(id)
end

local function ResolveControlPanelWithFallback(ent, names, fallbackPos, fallbackAng)
	if IsValid(ent) then
		for _, name in ipairs(names) do
			local att = ResolveControlPanelAttachment(ent, name)
			if att then return att end
		end
		return {
			Pos = ent:LocalToWorld(fallbackPos),
			Ang = ent:LocalToWorldAngles(fallbackAng),
		}
	end
	return nil
end

local function ResolveDispenserModel(ent)
	if IsValid(ent.Model) and ent.Model:GetParent() == ent then
		return ent.Model
	end
	for _, v in ipairs(ents.FindByClass("obj_anim")) do
		if IsValid(v) and v:GetParent() == ent then
			ent.Model = v
			return v
		end
	end
	return nil
end

local function IsTextureValid(id)
	return isnumber(id) and id > 0
end

local function AlphaOf(ent)
	if not IsValid(ent) then return 255 end
	local c = ent:GetColor()
	return (c and c.a) or 255
end

function ENT:ShouldDrawDispenserPanels(modelEnt)
	return true
end

local function HideCartDispenserModel(ent)
	if not IsValid(ent) then return end
	ent:SetNoDraw(true)
	ent:DrawShadow(false)

	local modelEnt = ResolveDispenserModel(ent)
	if IsValid(modelEnt) then
		modelEnt:SetNoDraw(true)
		modelEnt:DrawShadow(false)
	end
end

function ENT:DrawDispenserPanels()
	HideCartDispenserModel(self)
end

function ENT:Draw()
	HideCartDispenserModel(self)
end

function ENT:DrawScreen()
	local teamTex = (self:Team() == TEAM_BLU or self:Team() == TF_TEAM_PVE_INVADERS) and ScreenTexture[1] or ScreenTexture[0]
	local validTeamTex = IsTextureValid(teamTex)
	local validArrowTex = IsTextureValid(ArrowTexture)
	if not validTeamTex or not validArrowTex then return end
	surface.SetDrawColor(255,255,255,255)
	surface.SetTexture(teamTex)
	surface.DrawTexturedRect(0, 0, 480, 240)
	
	local a = self.Ang or self:CalcAngle(0)
	local r = math.rad(a)
	local s, c = math.sin(r), math.cos(r)
	surface.SetTexture(ArrowTexture)
	surface.SetDrawColor(255,255,255,255)
	surface.DrawTexturedRectRotated(480*0.5 - math.floor(81*s), 240*0.90625 - math.floor(81*c), 50, 200, a)
end

hook.Add("PostDrawOpaqueRenderables", "TF_DrawCartDispenserPanels", function()
	for _, ent in ipairs(ents.FindByClass("mapobj_cart_dispenser")) do
		if IsValid(ent) and ent.DrawDispenserPanels then
			ent:DrawDispenserPanels()
		end
	end
end)

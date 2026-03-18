local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local mat_MotionBlur	= Material("pp/motionblur")
local tex_MotionBlur	= render.GetMoBlurTex0()
local mat_white = Material("models/debug/debugwhite")
local pp_motionblur = surface.GetTextureID("pp/motionblur")

local function ClearPreviewParticle(ent)
	if not IsValid(ent) then return end
	if ent.StopParticles then
		ent:StopParticles()
	end
	ent.PreviewParticleSystem = nil
end

local function SetupTF2Lighting(ent, spotlight)
	if TF2LightwarpApplyModelLighting then
		TF2LightwarpApplyModelLighting(ent:GetPos() + Vector(0, 0, 68))
		if spotlight then
			render.SetModelLighting(BOX_TOP, 1, 1, 1)
		end
		return
	end

	render.SetLightingOrigin(ent:GetPos() + Vector(0, 0, 68))
	render.ResetModelLighting(0.07, 0.07, 0.07)

	-- TF2-like key/fill setup so $lightwarptexture produces readable toon ramps.
	render.SetModelLighting(BOX_TOP, 0.78, 0.76, 0.72)
	render.SetModelLighting(BOX_FRONT, 0.60, 0.58, 0.54)
	render.SetModelLighting(BOX_RIGHT, 0.24, 0.25, 0.28)
	render.SetModelLighting(BOX_LEFT, 0.15, 0.13, 0.11)
	render.SetModelLighting(BOX_BACK, 0.06, 0.06, 0.06)
	render.SetModelLighting(BOX_BOTTOM, 0.02, 0.02, 0.02)

	if spotlight then
		render.SetModelLighting(BOX_TOP, 1, 1, 1)
	end
end

local function SetupLegacyLighting(ent, spotlight)
	render.SetLightingOrigin(ent:GetPos() + Vector(0, 0, 68))
	render.ResetModelLighting(0.5, 0.5, 0.5)

	if spotlight then
		render.SetModelLighting(BOX_TOP, 1, 1, 1)
	end
end

function PANEL:Init()
	self:SetVisible(true)
	self.Entities = {}
	
	self.LastPaint = 0
	self.FOV = 70
	self.UseTF2Lightwarp = true
end

function PANEL:AddModel(id, mdl, keys)
	local ent = ClientsideModel(mdl)
	if not IsValid(ent) then return end
	
	ent:SetNoDraw(true)
	ent:SetPos(keys.Pos or Vector(0,0,0))
	ent:SetAngles(keys.Ang or Angle(0,0,0))
	
	if keys.Parent then
		if IsValid(self.Entities[keys.Parent]) then
			ent:SetParent(self.Entities[keys.Parent])
			ent:AddEffects(EF_BONEMERGE)
		end
	end

	if keys.Color then
		ent.ColorType = keys.Color
		--print("Yes!")
	end

	if isnumber(keys.Skin) then
		ent:SetSkin(math.max(0, math.floor(keys.Skin)))
	end

	if isstring(keys.MaterialOverride) and keys.MaterialOverride ~= "" then
		ent:SetMaterial(keys.MaterialOverride)
	end

	if istable(keys.TintColor) then
		if ent.SetPreviewCosmeticTint then
			ent:SetPreviewCosmeticTint(keys.TintColor)
		else
			ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
			ent:SetColor(Color(
				math.Clamp(tonumber(keys.TintColor.r) or 255, 0, 255),
				math.Clamp(tonumber(keys.TintColor.g) or 255, 0, 255),
				math.Clamp(tonumber(keys.TintColor.b) or 255, 0, 255),
				math.Clamp(tonumber(keys.TintColor.a) or 255, 0, 255)
			))
		end
	end

	if isstring(keys.ParticleSystem) and keys.ParticleSystem ~= "" then
		ParticleEffectAttach(keys.ParticleSystem, PATTACH_ABSORIGIN_FOLLOW, ent, 0)
		ent.PreviewParticleSystem = keys.ParticleSystem
	end
	
	if keys.LayoutEntity then
		ent.LayoutEntity = keys.LayoutEntity
	end
	
	if IsValid(self.Entities[id]) then
		ClearPreviewParticle(self.Entities[id])
		self.Entities[id]:Remove()
	end
	
	self.Entities[id] = ent
	return ent
end

function PANEL:OnRemove()
	for _, ent in pairs(self.Entities or {}) do
		if IsValid(ent) then
			ClearPreviewParticle(ent)
			ent:Remove()
		end
	end
	self.Entities = {}
end

function PANEL:GetModelEntity(id)
	return self.Entities[id]
end

function PANEL:Paint()
	if table.Count(self.Entities)==0 then return end
	
	local x, y = self:LocalToScreen(0, 0)
	local w, h = self:GetSize()
	
	local fov = self.FOV
	
	if h<w then
		y = y + (h-w)/2
		h = w
	elseif w<h then
		x = x + (w-h)/2
		w = h
	end
	
	self:RunAnimation()
	for _,v in pairs(self.Entities) do
		if v.ColorType == "hat" and v.SetPreviewCosmeticTint then
			v:SetPreviewCosmeticTint(string.ToColor(LocalPlayer():GetInfo("tf_hatcolor")))
		elseif v.ColorType == "person" and IsValid(LocalPlayer().NeutralModel) then
			v:SetColor(LocalPlayer().NeutralModel:GetColor())
		end

		if v.LayoutEntity then
			v:LayoutEntity()
		else
			v:SetAngles(v:GetAngles())
		end
	end
	
	cam.Start3D(Vector(0,0,0), Angle(0,0,0), fov, x, y, w, h)
	
	render.SuppressEngineLighting(true)
	if self.UseTF2Lightwarp and IsValid(self.Entities[1]) then
		SetupTF2Lighting(self.Entities[1], self.spotlight)
	elseif IsValid(self.Entities[1]) then
		SetupLegacyLighting(self.Entities[1], self.spotlight)
	end
	
	for _,v in pairs(self.Entities) do
		v:DrawModel()
	end
	
	render.SuppressEngineLighting(false)
	cam.End3D()
	
	self.LastPaint = RealTime()
end

function PANEL:RunAnimation()
	for _,v in pairs(self.Entities) do
		if v.animated then
			v:FrameAdvance(RealTime()-self.LastPaint)
		end
	end
end

function PANEL:StartAnimation(id, act)
	local ent = self.Entities[id]
	if not IsValid(ent) then return end
	
	local seq = ent:SelectWeightedSequence(act)
	if seq<=0 then return end
	
	ent:ResetSequence(seq)
	--ent:SetPoseParameter("move_x", 1)
	ent.animated = true
end

function PANEL:StopAnimation(id)
	local ent = self.Entities[id]
	if not IsValid(ent) then return end
	
	ent.animated = false
end

function PANEL:OnMousePressed(b)
	if self.disable_manipulation then return end
	if b==MOUSE_LEFT then
		self:MouseCapture(true)
		self.Drag = true
		self.LastX, self.LastY = self:CursorPos()
	end
end

function PANEL:OnMouseReleased(b)
	if b==MOUSE_LEFT then
		self:MouseCapture(false)
		self.Drag = false
	end
end

function PANEL:OnCursorMoved(x, y)
	if self.Drag and self.LastX and self.LastY then
		local dx, dy = x - self.LastX, y - self.LastY
		self.Entities[1]:SetAngles(self.Entities[1]:GetAngles() + Angle(0,dx/5,0))
		
		self.LastX, self.LastY = x, y
	end
end

vgui.Register("ClassModelPanel", PANEL, "EditablePanel")

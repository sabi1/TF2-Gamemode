include('shared.lua')

include("shd_util.lua")
include("shd_anim.lua")
include("shd_sound.lua")
include("shd_crits.lua")

local debugWorldModels = CreateClientConVar("tf_debug_worldmodels", "0", true, false)
local forceWorldModelDraw = CreateClientConVar("tf_force_worldmodel_draw", "0", true, false)
local nextWorldModelDebug = 0

local function DebugWorldModelState(tag, pl, wep)
	if not debugWorldModels:GetBool() then return end
	if CurTime() < nextWorldModelDebug then return end
	nextWorldModelDebug = CurTime() + 1
	local ownerText = IsValid(pl) and (pl:Nick() .. " [" .. pl:EntIndex() .. "]") or "nil"
	local wepClass = IsValid(wep) and wep:GetClass() or "nil"
	local itemName = IsValid(wep) and wep.GetItemData and wep:GetItemData() and wep:GetItemData().name or "nil"
	local model = IsValid(wep) and wep.WModel and wep.WModel.GetModel and wep.WModel:GetModel() or "nil"
	local nodraw = IsValid(wep) and IsValid(wep.WModel) and wep.WModel:GetNoDraw() or false
	print(string.format("[tf_debug_worldmodels] %s owner=%s wep=%s item=%s wmodel_valid=%s nodraw=%s model=%s",
		tag,
		ownerText,
		tostring(wepClass),
		tostring(itemName),
		tostring(IsValid(wep) and IsValid(wep.WModel)),
		tostring(nodraw),
		tostring(model)
	))
end


SWEP.PrintName			= "Scripted Weapon"

SWEP.Slot				= 0
SWEP.SlotPos			= 10
SWEP.DrawAmmo			= true
SWEP.DrawCrosshair		= true
SWEP.DrawWeaponInfoBox	= false
SWEP.BounceWeaponIcon   = false
SWEP.WepSelectIcon = surface.GetTextureID( "weapons/swep" )
SWEP.SwayScale			= 0 -- 0.5
SWEP.BobScale			= 0 -- formerly 0.35, no more viewbobbing until we port cstrike's viewbob
 
--[[
hook.Add("HUDPaint", "testlol", function()
	draw.Text{text="Current sequence = "..LocalPlayer():GetViewModel():GetSequence(),pos={10, 10}}
	draw.Text{text="Cycle = "..LocalPlayer():GetViewModel():GetCycle(),pos={10, 40}}
end)]]

hook.Add("Think", "TFCheckWeaponChanged", function()
	local v = LocalPlayer()
	if not IsValid(v) then return end
	local active = v:GetActiveWeapon()
	local last = v.LastActiveWeapon
	if not IsValid(active) then
		active = last
	end
	if active ~= last then
		if IsValid(v.LastActiveWeapon) and v.LastActiveWeapon.ClearParticles then
			v.LastActiveWeapon:ClearParticles()
		end
		
		--MsgFN("Old weapon : %s", tostring(v.LastActiveWeapon))
		if IsValid(v.LastActiveWeapon) and v.LastActiveWeapon.NextDeployed and v.LastActiveWeapon.Holster then
			v.LastActiveWeapon:Holster()
		end
		v.LastActiveWeapon = active
		if IsValid(v.LastActiveWeapon) and not v.LastActiveWeapon.NextDeployed and v.LastActiveWeapon.Deploy then
			v.LastActiveWeapon:Deploy()
		end
		--MsgFN("New weapon : %s", tostring(v.LastActiveWeapon))
		
		if IsValid(v.LastActiveWeapon) and v.LastActiveWeapon.ResetParticles then
			v.LastActiveWeapon:ResetParticles()
		end
	end
end)

function SWEP:InitializeCModel()
end

function SWEP:InitializeWModel2()
--Msg("InitializeWModel2\n")
	local wmodel = self.WorldModelOverride2 or self.WorldModelOverride or self.WorldModel
	if (not isstring(wmodel)) or wmodel == "" then
		local item = self.GetItemData and self:GetItemData() or nil
		wmodel = (item and item.model_world) or (item and item.model_player) or self.WorldModel
	end
	if (not isstring(wmodel)) or wmodel == "" then return end
	local mergeEffects = bit.bor(EF_BONEMERGE, EF_BONEMERGE_FASTCULL, EF_PARENT_ANIMATES)
	
	if IsValid(self.WModel2) then
		if self.WModel2:GetModel() ~= wmodel then
			self.WModel2:SetModel(wmodel)
		end
	else
		self.WModel2 = ClientsideModel(wmodel)
		if not IsValid(self.WModel2) then return end
		if self.WModel2.SetAutomaticFrameAdvance then
			self.WModel2:SetAutomaticFrameAdvance(true)
		end
	end
	
	if IsValid(self.WModel2) then
		local parent = IsValid(self.Owner) and self.Owner or self
		if self.WModel2:GetParent() ~= parent then
			self.WModel2:SetParent(parent)
		end
		self.WModel2:AddEffects(mergeEffects)
		self.WModel2:SetNoDraw(true)
		self.WModel2.Player = self.Owner
		self.WModel2.Weapon = self
		
		if self.MaterialOverride then
			self.WModel2:SetMaterial(self.MaterialOverride)
		end
	end
end

function SWEP:InitializeAttachedModels()
--Msg("InitializeAttachedModels\n")
	local mergeEffects = bit.bor(EF_BONEMERGE, EF_BONEMERGE_FASTCULL, EF_PARENT_ANIMATES)
	local appliedMat = self.CustomMaterialOverride2 or self.MaterialOverride or self.WeaponMaterial or ""
	if isstring(appliedMat) and appliedMat ~= "" then
		local test = Material(appliedMat)
		if not test or test:IsError() then
			appliedMat = ""
		end
	end
	if IsValid(self.AttachedWModel) then
		if self.AttachedWorldModel then
			self.AttachedWModel:SetModel(self.AttachedWorldModel)
		else
			self.AttachedWModel:Remove()
		end
	elseif self.AttachedWorldModel then
		local ent = (IsValid(self.WModel2) and self.WModel2) or (IsValid(self.WModel) and self.WModel) or self
		
		self.AttachedWModel = ClientsideModel(self.AttachedWorldModel)
		if self.AttachedWModel.SetAutomaticFrameAdvance then
			self.AttachedWModel:SetAutomaticFrameAdvance(true)
		end
		self.AttachedWModel:SetPos(ent:GetPos())
		self.AttachedWModel:SetAngles(ent:GetAngles())
		self.AttachedWModel:AddEffects(mergeEffects)
		self.AttachedWModel:SetParent(ent)
		self.AttachedWModel:SetNoDraw(true)
	end
	
	if IsValid(self.AttachedWModel) then
		local worldParent = (IsValid(self.WModel2) and self.WModel2) or (IsValid(self.WModel) and self.WModel) or self
		if self.AttachedWModel:GetParent() ~= worldParent then
			self.AttachedWModel:SetParent(worldParent)
		end
		self.AttachedWModel:AddEffects(mergeEffects)
		self.AttachedWModel.Player = self.Owner
		self.AttachedWModel.Weapon = self
		
		self.AttachedWModel:SetMaterial(appliedMat)
	end
	
	if IsValid(self.AttachedVModel) then
		if self.AttachedViewModel then
			self.AttachedVModel:SetModel(self.AttachedViewModel)
		else
			self.AttachedVModel:Remove()
		end
	elseif self.AttachedViewModel then
		local ent = (IsValid(self.CModel) and self.CModel) or self.Owner:GetViewModel()
		
		if not IsValid(ent) then return end
		
		self.AttachedVModel = ClientsideModel(self.AttachedViewModel)
		if self.AttachedVModel.SetAutomaticFrameAdvance then
			self.AttachedVModel:SetAutomaticFrameAdvance(true)
		end
		self.AttachedVModel:SetPos(ent:GetPos())
		self.AttachedVModel:SetAngles(ent:GetAngles())
		self.AttachedVModel:AddEffects(mergeEffects)
		self.AttachedVModel:SetParent(ent)
		self.AttachedVModel:SetNoDraw(true)
	end
	
	if IsValid(self.AttachedVModel) then
		local viewParent = (IsValid(self.CModel) and self.CModel) or (IsValid(self.Owner) and IsValid(self.Owner:GetViewModel()) and self.Owner:GetViewModel()) or nil
		if IsValid(viewParent) and self.AttachedVModel:GetParent() ~= viewParent then
			self.AttachedVModel:SetParent(viewParent)
		end
		self.AttachedVModel:AddEffects(mergeEffects)
		self.AttachedVModel.Player = self.Owner
		self.AttachedVModel.Weapon = self
		
		self.AttachedVModel:SetMaterial(appliedMat)
	end
end

-- Attached viewmodels seem to lose their parent when the player exits a vehicle, we'll force ViewModelDrawn to re-parent them to the player's viewmodel if the player has entered a vehicle
local LastVehicle = NULL
hook.Add("Think", "TFCheckPlayerInVehicle", function()
	local v = LocalPlayer():GetVehicle()
	
	if v ~= LastVehicle then
		if IsValid(v) then
			for _,w in pairs(LocalPlayer():GetWeapons()) do
				w.FixViewModel = true
			end
		end
		LastVehicle = v
	end
end)

function SWEP:RenderCModel()
	if IsValid(self.CModel) then
		self.CModel:DrawModel()
	end
	
	if IsValid(self.ExtraCModel) then
		self.ExtraCModel:DrawModel()
	end
	
	if IsValid(self.AttachedVModel) then
		self.AttachedVModel:DrawModel()
	end
end

function SWEP:RenderWModel()
	if IsValid(self.WModel2) then
		----self.WModel2:CreateShadow()
		--self.WModel2:DrawModel()
	end
	
	if IsValid(self.AttachedWModel) then
		--self.AttachedWModel:CreateShadow()
		self.AttachedWModel:DrawModel()
	end
end

function SWEP:DrawWeaponSelection(x, y, w, h, alpha)
	surface.SetDrawColor(255, 255, 255, alpha)
	local tex = self:GetIconTextureID() or nil
	if tex == nil then
		draw.SimpleText(self.PrintName, "TFHudSelectionText", x + w / 2, y + h * 0.4, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
		return
	end
	surface.SetTexture(tex)
	local rx, ry = surface.GetTextureSize(tex)

	-- Borders
	y = y - 10
	x = x + 50
	w = w - 20

	-- Draw that mother
	surface.DrawTexturedRect( x, y,  w * 0.6 , ( w / 1.2 ) )

	-- Draw weapon info box
	self:PrintWeaponInfo( x + w + 20, y + h * 0.95, alpha )
end

function SWEP:ViewModelDrawn()

	//deployspeed = math.Round(GetConVar("tf_weapon_deploy_speed"):GetFloat(),2)
	local vm = self.Owner:GetViewModel()
	vm.Player = self.Owner
	
	if not self.IsDeployed then
		local seq = vm:GetSequence()
		if vm:GetSequenceActivity(seq) == self.VM_DRAW then
			self.DeploySequence = seq
		end
		
		if self.Owner.TempAttributes and self.Owner.TempAttributes.DeployTimeMultiplier then
			vm:SetPlaybackRate(1 / self.Owner.TempAttributes.DeployTimeMultiplier)
		else
			vm:SetPlaybackRate(1)
		end
	else
		if self.DeploySequence ~= true and vm:GetSequence() ~= self.DeploySequence then
			vm:SetPlaybackRate(1)
			self.DeploySequence = true
		end
	end	
	
	if self.FixViewModel then
		if IsValid(self.CModel) then
			self.CModel:SetParent(vm)
		end
		self.FixViewModel = false
	end
	
	if self.ViewModelOverride --[[and self:GetModel()~=self.ViewModelOverride]] then
		self.ViewModel = self.ViewModelOverride
		self:SetModel(self.ViewModelOverride)
		vm:SetModel(self.ViewModelOverride)
	end
	
	if self.HasCModel and not IsValid(self.CModel) then
		return
	end
	
	self.DrawingViewModel = true
	if IsValid(self.CModel) then
		self.CModel:SetSkin(self.WeaponSkin or 0)
		//self.CModel:SetMaterial(self.WeaponMaterial or 0)
	end
	if IsValid(self.AttachedVModel) then
		self.AttachedVModel:SetSkin(self.WeaponSkin or 0)
		//self.AttachedVModel:SetMaterial(self.WeaponMaterial or 0)
	end
	self.Owner:GetViewModel():SetSkin(self.WeaponSkin or 0)
	//self.Owner:GetViewModel():SetMaterial(self.WeaponMaterial or 0)
	
	if self.ViewModelFlip then
		render.CullMode(MATERIAL_CULLMODE_CW)
	end

	if IsValid(self.ShieldEntity) and IsValid(self.ShieldEntity.CModel) then
		self.ShieldEntity:StartVisualOverrides()
		self.ShieldEntity.CModel:DrawModel()
		self.ShieldEntity:EndVisualOverrides()
	end

	self:StartVisualOverrides()
	
	self:CalcViewModelBobHelper(self.Owner)
	self:RenderCModel()
	
	self:EndVisualOverrides()
	if self.ViewModelFlip then
		render.CullMode(MATERIAL_CULLMODE_CCW)
	end
	
	self:ModelDrawn(true)
end


-- Instead of using using DrawWorldModel to render the world model, do it here (at least it guarantees that it will be always drawn if the player is visible)
-- any potential problem with this?
hook.Add("PostPlayerDraw", "ForceDrawTFWorldModel", function(pl)
	if not forceWorldModelDraw:GetBool() then return end
	if pl.RenderingWorldModel then
		render.SetBlend(1)
		return
	end

	if not IsValid(pl) then return end
	local wep = pl:GetActiveWeapon()
	if not IsValid(wep) or not wep.IsTFWeapon or not isfunction(wep.DrawWorldModel) then return end
	if pl == LocalPlayer() and not pl:ShouldDrawLocalPlayer() then return end
	if pl:GetNWBool("NoWeapon", false) then return end
	DebugWorldModelState("postplayerdraw", pl, wep)
	pl.RenderingWorldModel = true
	local ok, err = pcall(function()
		wep:DrawWorldModel()
	end)
	pl.RenderingWorldModel = false
	if not ok then
		ErrorNoHalt(string.format("ForceDrawTFWorldModel failed for %s: %s\n", tostring(wep), tostring(err)))
	end
end)

-- Drawing the world model seems to redraw the player as well, this is quite annoying when a material is forced on the world model
-- as the player will be redrawn using that material as well
-- Just make players invisible if their world model is being rendered
hook.Add("PrePlayerDraw", "TFWorldModelHidePlayer", function(pl)
	if not forceWorldModelDraw:GetBool() then return end
	if pl.RenderingWorldModel then
		render.SetBlend(0)
	end
end)

function SWEP:ModelDrawn(viewmode)
	
end

function SWEP:DoMuzzleFlash()
	local betaeffect = self.BetaMuzzle
	local ent
	
	if self.Owner==LocalPlayer() and not LocalPlayer():ShouldDrawLocalPlayer() then
		ent = self.CModel
	else
		ent = self:GetWorldModelEntity()
	end
	
	self:ResetParticles()
	
	if betaeffect then
		local effectdata = EffectData()
			effectdata:SetEntity(self)
		util.Effect(betaeffect, effectdata)
	else
		--ent:MuzzleFlash()
		ParticleEffectAttach(self.MuzzleEffect, PATTACH_POINT_FOLLOW, ent, ent:LookupAttachment("muzzle"))
	end
end

function SWEP:Draw()
end

usermessage.Hook("DoMuzzleFlash", function(msg)
	local w = msg:ReadEntity()
	if IsValid(w) and w.DoMuzzleFlash then
		w:DoMuzzleFlash()
	end
end)

usermessage.Hook("CallTFWeaponFunction", function(msg)
	local w = msg:ReadEntity()
	local f = msg:ReadString()
	local p = msg:ReadString()
	
	if IsValid(w) and w[f] then
		w[f](w, p)
	end
end)

usermessage.Hook("TF2ShellEject", function(msg)
	local w = msg:ReadEntity()
	
	if IsValid(w) then
		if (string.find(w:GetClass(),"smg") or string.find(w:GetClass(),"pistol") or string.find(w:GetClass(),"revolver")) then 
			--PrintTable(self.CModel:GetAttachments())
			if (IsValid(w.CModel)) then
				if (w.CModel:GetAttachment(w.CModel:LookupAttachment("eject_brass"))) then
					local effectdata = EffectData()
					if (LocalPlayer():ShouldDrawLocalPlayer()) then

						effectdata:SetEntity( w.Owner:GetViewModel() )
						effectdata:SetOrigin( w:GetAttachment(w:LookupAttachment("eject_brass")).Pos )
						effectdata:SetAngles( Angle(w:GetAttachment(w:LookupAttachment("eject_brass")).Ang.x,w:GetAttachment(w:LookupAttachment("eject_brass")).Ang.y,w.WModel:GetAttachment(w.CModel:LookupAttachment("eject_brass")).Ang.z) )

					else

						effectdata:SetEntity( w.Owner:GetViewModel() )
						effectdata:SetOrigin( w.CModel:GetAttachment(w.CModel:LookupAttachment("eject_brass")).Pos )
						effectdata:SetAngles( Angle(w.CModel:GetAttachment(w.CModel:LookupAttachment("eject_brass")).Ang.x,w.CModel:GetAttachment(w.CModel:LookupAttachment("eject_brass")).Ang.y,w.CModel:GetAttachment(w.CModel:LookupAttachment("eject_brass")).Ang.z) )

					end
					util.Effect( "ShellEject", effectdata )
				end
			end 
		end
	end
end)
usermessage.Hook("PlayTFWeaponWorldReload", function(msg)
	local w = msg:ReadEntity()
	
	if IsValid(w) and w.ReloadSound and (w.Owner ~= LocalPlayer() or LocalPlayer():ShouldDrawLocalPlayer()) then
		w:StopSound(w.ReloadSound)
		w:EmitSound(w.ReloadSound)
	end
end)
usermessage.Hook("PlayTFWeaponWorldReloadFinish", function(msg)
	local w = msg:ReadEntity()
	
	if IsValid(w) and w.ReloadSoundFinish and (w.Owner ~= LocalPlayer() or LocalPlayer():ShouldDrawLocalPlayer()) then
		w:StopSound(w.ReloadSoundFinish)
		w:EmitSound(w.ReloadSoundFinish)
	end
end)

hook.Add("EntityRemoved", "TFWeaponRemoved", function(ent)
	if ent.IsTFWeapon then
		if IsValid(ent.CModel) then ent.CModel:Remove() end
		if IsValid(ent.WModel) then ent.WModel:Remove() end
		if IsValid(ent.WModel2) then ent.WModel2:Remove() end
		if IsValid(ent.AttachedVModel) then ent.AttachedVModel:Remove() end
		if IsValid(ent.AttachedWModel) then ent.AttachedWModel:Remove() end
		if IsValid(ent.ExtraCModel) then ent.ExtraCModel:Remove() end
		if IsValid(ent.ExtraWModel) then ent.ExtraWModel:Remove() end
		if IsValid(ent.OffhandProjectileCModel) then ent.OffhandProjectileCModel:Remove() end
	end
end)

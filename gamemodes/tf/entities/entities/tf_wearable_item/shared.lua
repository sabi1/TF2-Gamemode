
DEFINE_BASECLASS( "base_gmodentity" )

ENT.IsTFWearableItem = true
local ResolveWearableDisplayModel

tf_item.InitializeAsBaseItem(ENT)
ENT.SetupDataTables0 = ENT.SetupDataTables

function ENT:SetupDataTables()
	self:SetupDataTables0()
	self:DTVar("Int", 1, "ItemTint")
	self:NetworkVar("Vector", 1, "CosmeticTint")
end

function ENT:GetItemTint(t)
	return self.dt.ItemTint
end

if SERVER then

AddCSLuaFile("shared.lua")

function ENT:SetItemTint(t)
	self.dt.ItemTint = t
end

end

if CLIENT then

CreateClientConVar( "tf_hatcolor", "0 0 0 255", true, true )
CreateClientConVar( "tf_misccolor", "0 0 0 255", true, true )
CreateClientConVar( "tf_hatcolor_rainbow", "0", true, true )
CreateClientConVar( "tf_misccolor_rainbow", "0", true, true )

function ENT:Draw()
	if self.IsHiddenByVision and self:IsHiddenByVision(LocalPlayer()) then return end
	if TF_ShouldHideOwnerWearablesForViewer and TF_ShouldHideOwnerWearablesForViewer(self:GetOwner(), LocalPlayer()) then return end
	if (IsMounted("tf")) then
		if self:GetOwner() ~= LocalPlayer() or LocalPlayer():ShouldDrawLocalPlayer() then
			self:StartVisualOverrides()
			self:StartItemTint(self:GetItemTint())
			self:GetOwner().RenderingWorldModel = true
			self:DrawModel()
			self:GetOwner().RenderingWorldModel = false
			self:EndItemTint()
			self:EndVisualOverrides()
		end
	else
		self:SetModel("models/empty.mdl")
		self:DrawModel()
	end
end

-- Called when the player is ragdolled or gibbed (if gibbed, rag = NULL)
function ENT:SetupPlayerRagdoll(rag)
		local item = self:GetItemData()
		
		self.CheckUpdateItem = nil
		self:ClearParticles()
		
		if not self.Model or not util.IsValidModel(self.Model) then return end
		
		local effectdata = EffectData()
		effectdata:SetEntity(self)
		if IsValid(rag) then
			-- Keep equipped cosmetics on the death ragdoll.
			util.Effect("tf_hat_attached", effectdata)
			return
		end

		-- Gibbed without a ragdoll: preserve legacy hat gib behavior.
		if item and item.drop_type == "drop" then
			local mat = self:GetBoneMatrix(0)
			effectdata:SetMagnitude(GIB_HAT)
			if mat then
				effectdata:SetOrigin(mat:GetTranslation())
				effectdata:SetAngles(mat:GetAngles())
			else
				local owner = self:GetOwner()
				if IsValid(owner) then
					effectdata:SetOrigin(owner:GetPos())
					effectdata:SetAngles(owner:GetAngles())
				end
			end
			effectdata:SetNormal(Vector(0,0,0.8))
			effectdata:SetRadius(0.8)
			util.Effect("tf_gib", effectdata)
		end
end

function ENT:Think()
	if CLIENT then
		local model = ResolveWearableDisplayModel(self, LocalPlayer())
		if model and self:GetModel() ~= model then
			self:SetModel(model)
		end
	end
	
	if self:GetOwner() ~= LocalPlayer() or LocalPlayer():ShouldDrawLocalPlayer() then
		if self.ShadowCreated ~= true then
			self.ShadowCreated = true
			self:CreateShadow()
		end
	else
		if self.ShadowCreated ~= false then
			self.ShadowCreated = false
			self:DestroyShadow()
		end
	end


	if CLIENT then
		if self:GetOwner() ~= LocalPlayer() or LocalPlayer():ShouldDrawLocalPlayer() then
			if self.ShadowCreated ~= true then
				self.ShadowCreated = true
				self:CreateShadow()
			end
		else
			if self.ShadowCreated ~= false then
				self.ShadowCreated = false
				self:DestroyShadow()
			end
		end
	elseif SERVER then
		if self:GetOwner():GetNoDraw() == true then
			self:SetNoDraw(true)
		else
			self:SetNoDraw(false)
		end
		local item = self:GetItemData()
		if self:GetItemData()["item_slot"] == "head" then
			if self:GetOwner():GetInfoNum("tf_hatcolor_rainbow", 0) == 1 then 
				self:SetCosmeticTint(Vector(math.random(5, 255)/255, math.random(5, 255)/255, math.random(5, 255)/255))
			else
				self:SetCosmeticTint(Vector(string.ToColor(self:GetOwner():GetInfo("tf_hatcolor")).r/255, string.ToColor(self:GetOwner():GetInfo("tf_hatcolor")).g/255, string.ToColor(self:GetOwner():GetInfo("tf_hatcolor")).b/255))
			end
		elseif self:GetItemData()["item_slot"] == "misc" then
			if self:GetOwner():GetInfoNum("tf_hatcolor_rainbow", 0) == 1 then
				self:SetCosmeticTint(Vector(math.random(5, 255)/255, math.random(5, 255)/255, math.random(5, 255)/255))
			else
				self:SetCosmeticTint(Vector(string.ToColor(self:GetOwner():GetInfo("tf_misccolor")).r/255, string.ToColor(self:GetOwner():GetInfo("tf_misccolor")).g/255, string.ToColor(self:GetOwner():GetInfo("tf_misccolor")).b/255))
			end
		end
	end

	if (IsValid(self.Owner) and string.find(self.Owner:GetModel(),"/player/touhou/")) then
		if SERVER then
			self:Remove()
		end
		return
	end

	if (file.Exists(self:GetModel(),"GAME")) then
		local item = self:GetItemData()
		if (IsValid(self.Owner)) then
			if (item.visuals) then
				if item.visuals.player_bodygroups then
					local bodygroups = item.visuals.player_bodygroups
					if (bodygroups.hat) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("hat"),1)
					elseif (bodygroups.head) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("head"),1)
					elseif (bodygroups.headphones) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("headphones"),1)
					elseif (bodygroups.medal) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("medal"),1)
					elseif (bodygroups.grenades) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("grenades"),1)
					elseif (bodygroups.bullets) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("bullets"),1)
					elseif (bodygroups.arrows) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("arrows"),1)
					elseif (bodygroups.rightarm) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("rightarm"),1)
					elseif (bodygroups.shoes_socks) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("shoes_socks"),1)
					end
				end
			end
			if (item and item.visuals) then
				if item.visuals.player_bodygroups then
					local bodygroups = item.visuals.player_bodygroups
					if (bodygroups.hat) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("hat"),1)
					elseif (bodygroups.head) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("head"),1)
					elseif (bodygroups.headphones) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("headphones"),1)
					elseif (bodygroups.medal) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("medal"),1)
					elseif (bodygroups.grenades) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("grenades"),1)
					elseif (bodygroups.bullets) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("bullets"),1)
					elseif (bodygroups.arrows) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("arrows"),1)
					elseif (bodygroups.rightarm) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("rightarm"),1)
					elseif (bodygroups.shoes_socks) then
						self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("shoes_socks"),1)
					end
				end
			end
		end
		if self.Model and string.find(self.Model,"_zombie") then
			if (IsValid(self.Owner)) then
				if (self.Owner:GetPlayerClass() == "spy") then
					if (self.Owner:Team() == TEAM_BLU) then
						self.Owner:SetSkin(23)
						self:SetSkin(1)
					else
						self.Owner:SetSkin(22)
						self:SetSkin(0)
					end
				else
					if (self.Owner:Team() == TEAM_BLU) then
						self.Owner:SetSkin(5)
						self:SetSkin(1)
					else
						self.Owner:SetSkin(4)
						self:SetSkin(0)
					end
				end
			end
		else
			if (IsValid(self.Owner)) then
				if (self.Owner:GetPlayerClass() == "spy") then
					if (self.Owner:Team() == TEAM_BLU) then
						self:SetSkin(1)
					else
						self:SetSkin(0)
					end
				else
					if (self.Owner:Team() == TEAM_BLU) then
						self:SetSkin(1)
					else
						self:SetSkin(0)
					end
				end
			end
		end

	else
		self.Model = "models/empty.mdl"
		self:SetModel(self.Model)
	end

end

end

ResolveWearableDisplayModel = function(self, viewer)
	local item = self:GetItemData()
	if not istable(item) or not IsValid(self.Owner) then return nil end

	local model
	if item.model_player then
		model = string.Replace(string.Replace(item.model_player, "%s", self.Owner:GetPlayerClass()), "demoman", "demo")
	elseif item.model_player_per_class then
		if item.model_player_per_class[self.Owner:GetPlayerClass()] then
			model = item.model_player_per_class[self.Owner:GetPlayerClass()]
		else
			model = tostring(item.model_player_per_class.basename)
		end

		model = string.Replace(string.Replace(model or "", "%s", self.Owner:GetPlayerClass()), "demoman", "demo")
	end

	if self.GetEffectiveDisplayModel then
		return self:GetEffectiveDisplayModel(viewer, model)
	end

	return model
end

function ENT:Initialize()
	self.Owner = self:GetOwner()
	self:DrawShadow(false)
	self:AddEFlags(EFL_KEEP_ON_RECREATE_ENTITIES)

	if (file.Exists(self:GetModel(),"GAME")) then
		self:AddToPlayerItems()
		self.ProxyentPaintColor = self
			
		local item = self:GetItemData()
		self.Model = ResolveWearableDisplayModel(self, CLIENT and LocalPlayer() or nil)
		
		if SERVER then
			self:SetMoveType(MOVETYPE_NONE)
			self:SetSolid(SOLID_NONE)
			self:SetParent(self:GetOwner())
			
			if self.Model then
				self:SetModel(self.Model)
				self:SetKeyValue("effects", "1") 
				
				if item.set_sequence_to_class then
					self:AddEffects(EF_NOINTERP)
					self:ResetSequence(self:LookupSequence(self.Owner:GetPlayerClass()))
				end
			else
				self:SetNoDraw(true)
				self:DrawShadow(false)
			end
		end
	end
end

function ENT:OnRemove()
	self:RemoveFromPlayerItems()
end

function ENT:OnOwnerDeath()
	self.Dead = true
	self:SetNoDraw(true)
	self:DrawShadow(false)
	SafeRemoveEntityDelayed(self, 1)
end


hook.Add("PlayerHurt", "TFHatDisable2", function(pl)
	for k,dringer in pairs(ents.FindByClass("tf_weapon_invis_dringer")) do
		if dringer.Owner == pl and dringer.dt.Ready == true then
			for _,v in pairs(ents.FindByClass("tf_wearable_item")) do
				if v:GetOwner()==pl then
					vself.WModel2:SetNoDraw(true)
					v:DrawShadow(false)
					timer.Create("Decloak", 0.001, 0, function()
						if dringer.dt.Charging == false then
							vself.WModel2:SetNoDraw(false)
							v:DrawShadow(true)	
							v:SetMaterial("models/shadertest/predator")  
							timer.Simple(1, function() 
								v:SetMaterial("")
								timer.Stop("Decloak")
							end)
						end
					end)
				end
			end
		end
	end
end)


hook.Add("DoPlayerDeath", "DetachPlayerHat", function(pl)
	for _,v in pairs(pl:GetTFItems()) do
		if v.OnOwnerDeath then
			v:OnOwnerDeath()
		end
	end
end)

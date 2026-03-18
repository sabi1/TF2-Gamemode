
DEFINE_BASECLASS( "base_gmodentity" )

ENT.IsTFWearableItem = true

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

local function DecodeItemTintVector(raw)
	local n = tonumber(raw)
	if not n or n <= 0 then return nil end

	n = math.floor(n)
	if n > 0xFFFFFF then
		n = bit.band(n, 0xFFFFFF)
	end

	return Vector(
		bit.band(bit.rshift(n, 16), 0xFF) / 255,
		bit.band(bit.rshift(n, 8), 0xFF) / 255,
		bit.band(n, 0xFF) / 255
	)
end

local function EncodeItemTintInt(col)
	if not istable(col) then return 0 end
	local r = math.Clamp(math.floor(tonumber(col.r) or tonumber(col[1]) or 0), 0, 255)
	local g = math.Clamp(math.floor(tonumber(col.g) or tonumber(col[2]) or 0), 0, 255)
	local b = math.Clamp(math.floor(tonumber(col.b) or tonumber(col[3]) or 0), 0, 255)
	return bit.bor(bit.lshift(r, 16), bit.lshift(g, 8), b)
end

local function ColorFromTintVector(vec)
	if not isvector(vec) then
		return Color(0, 0, 0, 255)
	end
	return Color(
		math.Clamp(math.Round(vec.x * 255), 0, 255),
		math.Clamp(math.Round(vec.y * 255), 0, 255),
		math.Clamp(math.Round(vec.z * 255), 0, 255),
		255
	)
end

function ENT:GetConfiguredPaintData()
	local attrRaw = self.GetAttributeValue and self:GetAttributeValue("set_item_tint_rgb", nil) or nil
	local attrTint = DecodeItemTintVector(attrRaw)
	if attrTint then
		return tonumber(attrRaw) or 0, attrTint
	end

	local owner = self:GetOwner()
	if not IsValid(owner) then return 0, vector_origin end

	local item = self:GetItemData()
	local slot = item and item.item_slot or nil
	local color = nil

	if slot == "head" then
		color = string.ToColor(owner:GetInfo("tf_hatcolor"))
	elseif slot == "misc" then
		color = string.ToColor(owner:GetInfo("tf_misccolor"))
	end

	if not color then
		return 0, vector_origin
	end

	local encoded = EncodeItemTintInt(color)
	return encoded, DecodeItemTintVector(encoded) or vector_origin
end

function ENT:GetConfiguredCosmeticTint()
	local _, tint = self:GetConfiguredPaintData()
	return tint
end

if SERVER then

AddCSLuaFile("shared.lua")

function ENT:SetItemTint(t)
	self.dt.ItemTint = t
end

end

if CLIENT then

local function IsOwnerStealthed(owner)
	if not IsValid(owner) then return false end
	if owner.InCond then
		if owner:InCond(TF_COND_STEALTHED) or owner:InCond(TF_COND_STEALTHED_USER_BUFF) or owner:InCond(TF_COND_STEALTHED_USER_BUFF_FADING) then
			return true
		end
	end
	return owner:GetNWBool("Cloaked", false)
end

local function SyncStealthFromOwner(self)
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	if IsOwnerStealthed(owner) then
		local ownerColor = owner:GetColor()
		self:SetRenderMode(RENDERMODE_TRANSALPHA)
		self:SetColor(Color(ownerColor.r, ownerColor.g, ownerColor.b, ownerColor.a))
		self:SetMaterial(owner:GetMaterial() or "")
		return
	end

	self:SetRenderMode(RENDERMODE_NORMAL)
	self:SetColor(Color(255, 255, 255, 255))
	if self:GetMaterial() ~= "" then
		self:SetMaterial("")
	end
end

function ENT:Draw()
	if self.IsHiddenByVision and self:IsHiddenByVision(LocalPlayer()) then return end
	if TF_ShouldHideOwnerWearablesForViewer and TF_ShouldHideOwnerWearablesForViewer(self:GetOwner(), LocalPlayer()) then return end
	if self:GetOwner() ~= LocalPlayer() or LocalPlayer():ShouldDrawLocalPlayer() then
		SyncStealthFromOwner(self)
		if CLIENT then
			local tint = self.GetCosmeticTint and self:GetCosmeticTint() or nil
			if isvector(tint) then
				self.ProxyCosmeticTint = Vector(tint.x, tint.y, tint.z)
				self.ProxyentPaintColor = self
			end
		end
		self:StartVisualOverrides()
		self:StartItemTint(self:GetItemTint())
		self:GetOwner().RenderingWorldModel = true
		self:DrawModel()
		self:GetOwner().RenderingWorldModel = false
		self:EndItemTint()
		self:EndVisualOverrides()
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

end

local function ResolveWearableDisplayModel(self, viewer)
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

function ENT:Think()
	if CLIENT then
		SyncStealthFromOwner(self)
		local model = ResolveWearableDisplayModel(self, LocalPlayer())
		if model and self:GetModel() ~= model then
			self:SetModel(model)
		end
		local tint = self.GetCosmeticTint and self:GetCosmeticTint() or nil
		if isvector(tint) then
			self.ProxyCosmeticTint = Vector(tint.x, tint.y, tint.z)
			self.ProxyentPaintColor = self
		end
	elseif SERVER then
		local itemTint, cosmeticTint = self:GetConfiguredPaintData()
		self:SetItemTint(itemTint)
		self:SetCosmeticTint(cosmeticTint)
	end
	
	local item = self:GetItemData()
	if (IsValid(self.Owner)) then
		if (item.visuals) then
			if item.visuals.player_bodygroups then
				local bodygroups = item.visuals.player_bodygroups
				if (bodygroups.hat) then
					self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("hat"),1)
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
					self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("hat"),bodygroups.hat)
				elseif (bodygroups.headphones) then
					self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("headphones"),bodygroups.headphones)
				elseif (bodygroups.medal) then
					self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("medal"),bodygroups.medal)
				elseif (bodygroups.grenades) then
					self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("grenades"),bodygroups.grenades)
				elseif (bodygroups.bullets) then
					self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("bullets"),bodygroups.bullets)
				elseif (bodygroups.arrows) then
					self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("arrows"),bodygroups.arrows)
				elseif (bodygroups.rightarm) then
					self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("rightarm"),bodygroups.rightarm)
				elseif (bodygroups.shoes_socks) then
					self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("shoes_socks"),bodygroups.shoe_socks)
				end
			end
		end
	end	
	if IsValid(self.Owner) and self.Model and string.find(self.Model,"_zombie") then
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
	elseif IsValid(self.Owner) and self.Model then
		if (self.Owner:Team() == TEAM_BLU) then
			self:SetSkin(1)
		else
			self:SetSkin(0)
		end
	end
	if CLIENT then
		self:SetPredictable( true )
			
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
	end
end
function ENT:Initialize()
	self.Owner = self:GetOwner()
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
			self:AddEffects(EF_BONEMERGE)
			
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

function ENT:OnRemove()
	self:RemoveFromPlayerItems()
	
	local item = self:GetItemData()

	if (item.visuals) then
		if item.visuals.player_bodygroups then
			local bodygroups = item.visuals.player_bodygroups
			if (bodygroups.hat) then
				self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("hat"),0)
			elseif (bodygroups.headphones) then
				self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("headphones"),0)
			elseif (bodygroups.headphones) then
				self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("headphones"),0)
			elseif (bodygroups.medal) then
				self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("medal"),0)
			elseif (bodygroups.grenades) then
				self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("grenades"),0)
			elseif (bodygroups.bullets) then
				self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("bullets"),0)
			elseif (bodygroups.arrows) then
				self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("arrows"),0)
			elseif (bodygroups.rightarm) then
				self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("rightarm"),0)
			elseif (bodygroups.shoes_socks) then
				self.Owner:SetBodygroup(self.Owner:FindBodygroupByName("shoes_socks"),0)
			end
		end
	end
end

function ENT:OnOwnerDeath()
	self.Dead = true
	self:SetNoDraw(true)
	self:DrawShadow(false)
	SafeRemoveEntityDelayed(self, 1)
end

hook.Add("DoPlayerDeath", "DetachPlayerHat", function(pl)
	for _,v in pairs(pl:GetTFItems()) do
		if v.OnOwnerDeath then
			v:OnOwnerDeath()
		end
	end
end)

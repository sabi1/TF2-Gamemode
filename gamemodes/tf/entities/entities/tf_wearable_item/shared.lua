
DEFINE_BASECLASS( "base_gmodentity" )

ENT.IsTFWearableItem = true
local ResolveWearableDisplayModel

tf_item.InitializeAsBaseItem(ENT)
ENT.SetupDataTables0 = ENT.SetupDataTables

function ENT:SetupDataTables()
	self:SetupDataTables0()
	self:DTVar("Int", 1, "ItemTint")
	self:NetworkVar("Vector", 1, "CosmeticTintColor")

	if CLIENT then
		self:NetworkVarNotify("CosmeticTintColor", self.OnCosmeticTintColorChanged)
	end
end

if CLIENT then
	function ENT:OnCosmeticTintColorChanged()
		timer.Simple(0, function()
			self.ProxyCosmeticTint = nil
			self.ProxyentPaintColor = nil
		end)
	end
end

function ENT:GetItemTint(t)
	return self.dt.ItemTint
end

local function DecodePackedFloat32Integer(raw)
	local n = tonumber(raw)
	if not n then return nil end

	n = bit.band(math.floor(n), 0xFFFFFFFF)

	local sign = bit.band(bit.rshift(n, 31), 0x1)
	local exponent = bit.band(bit.rshift(n, 23), 0xFF)
	local mantissa = bit.band(n, 0x7FFFFF)

	if exponent == 0xFF then
		return nil
	end

	local value
	if exponent == 0 then
		if mantissa == 0 then
			value = 0
		else
			value = (mantissa / 8388608) * (2 ^ -126)
		end
	else
		value = (1 + mantissa / 8388608) * (2 ^ (exponent - 127))
	end

	if sign == 1 then
		value = -value
	end

	return value
end

local function NormalizeItemTintValue(raw)
	local n = tonumber(raw)
	if not n or n <= 0 then return nil end

	n = math.floor(n)
	if n <= 0xFFFFFF then
		return n
	end

	local decoded = DecodePackedFloat32Integer(n)
	if decoded and decoded > 0 and decoded <= 0xFFFFFF then
		local rounded = math.floor(decoded + 0.5)
		if rounded > 0 and rounded <= 0xFFFFFF then
			return rounded
		end
	end

	return bit.band(n, 0xFFFFFF)
end

local function DecodeItemTintVector(raw)
	local n = NormalizeItemTintValue(raw)
	if not n then return nil end

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

function ENT:GetConfiguredPaintData()
	local att = self:GetSkin() == 1 and "set_item_tint_rgb_2" or "set_item_tint_rgb"
	local attrRaw = self.GetAttributeValue and self:GetAttributeValue(att, nil) or nil
	local attrTint = DecodeItemTintVector(attrRaw)
	if attrTint then
		return NormalizeItemTintValue(attrRaw) or 0, attrTint
	end

	local owner = self:GetOwner()
	if not IsValid(owner) then return 0, vector_origin end

	local item = self:GetItemData()
	local slot = item and item.item_slot or nil
	local color = nil

	if slot == "head" then
		if owner:GetInfoNum("tf_hatcolor_rainbow", 0) == 1 then
			local tint = Vector(math.random(5, 255) / 255, math.random(5, 255) / 255, math.random(5, 255) / 255)
			return EncodeItemTintInt({
				r = tint.x * 255,
				g = tint.y * 255,
				b = tint.z * 255,
			}), tint
		end
		color = string.ToColor(owner:GetInfo("tf_hatcolor"))
	elseif slot == "misc" then
		if owner:GetInfoNum("tf_misccolor_rainbow", 0) == 1 then
			local tint = Vector(math.random(5, 255) / 255, math.random(5, 255) / 255, math.random(5, 255) / 255)
			return EncodeItemTintInt({
				r = tint.x * 255,
				g = tint.y * 255,
				b = tint.z * 255,
			}), tint
		end
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
	self.dt.ItemTint = NormalizeItemTintValue(t) or 0
end

end

if CLIENT then

CreateClientConVar( "tf_hatcolor", "0 0 0 255", true, true )
CreateClientConVar( "tf_misccolor", "0 0 0 255", true, true )
CreateClientConVar( "tf_hatcolor_rainbow", "0", true, true )
CreateClientConVar( "tf_misccolor_rainbow", "0", true, true )

local function IsOwnerStealthed(owner)
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
		self:SetRenderMode(RENDERMODE_TRANSALPHA)
		self:SetColor(owner:GetColor())
		self:SetMaterial(owner:GetMaterial() or "")
		return
	end

	self:SetRenderMode(RENDERMODE_NORMAL)
	self:SetColor(color_white)
	self:SetMaterial("")
end

local isMountedCached = IsMounted("tf")

function ENT:Draw()
	local ply = LocalPlayer()
	if self.IsHiddenByVision and self:IsHiddenByVision(ply) then return end

	local getOwner = self:GetOwner()
	if TF_ShouldHideOwnerWearablesForViewer(getOwner, ply) then return end

	if isMountedCached then
		if getOwner ~= ply or ply:ShouldDrawLocalPlayer() then
			SyncStealthFromOwner(self)

			self:StartVisualOverrides()
			self:StartItemTint(self:GetItemTint())
			getOwner.RenderingWorldModel = true
			self:DrawModel()
			getOwner.RenderingWorldModel = false
			self:EndItemTint()
			self:EndVisualOverrides()
		end
	else
		self.Model = "models/empty.mdl"
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

hook.Add("NotifyShouldTransmit", "UpdateCosmeticsTransmitState", function(ent, shouldTransmit)
	if ent:GetClass() ~= "tf_wearable_item" then return end

	if not shouldTransmit then
		ent:DestroyShadow()
		ent:StopParticleEmission()
		ent:StopAndDestroyParticles()
		ent.ShadowCreated = false
	end
end)

end

function ENT:Think()
	local getOwner = self:GetOwner()
	if not IsValid(getOwner) then return end

	if CLIENT then
		local ply = LocalPlayer()

		if (getOwner ~= ply or ply:ShouldDrawLocalPlayer()) and not self:IsDormant() then
			if not self.ShadowCreated then
				self.ShadowCreated = true
				self:CreateShadow()

				timer.Simple(0, function()
					if IsValid(self) then
						local attachment

						for _, p in ipairs(self:GetVisuals().attached_particlesystems or {}) do
							attachment = ent:LookupAttachment(p.attachment) or 0
							ParticleEffectAttach(p.system, PATTACH_POINT_FOLLOW, self, attachment)
						end

						if self.AttachedParticle then
							attachment = self:LookupAttachment("unusual") or 0
							ParticleEffectAttach(self.AttachedParticle.system, PATTACH_POINT_FOLLOW, self, attachment)
						end
					end
				end)
			end
		else
			if self.ShadowCreated then
				self.ShadowCreated = false
				self:DestroyShadow()
				self:StopParticleEmission()
				self:StopAndDestroyParticles()
			end
		end

		local tint = self:GetCosmeticTintColor()
		if isvector(tint) then
			self.ProxyCosmeticTint = tint
			self.ProxyentPaintColor = self
		end
	else
		if getOwner:GetNoDraw() or self:GetNoDraw() then
			self:SetNoDraw(true)
		else
			self:SetNoDraw(false)
		end

		local itemTint, cosmeticTint = self:GetConfiguredPaintData()
		self:SetItemTint(itemTint)
		self:SetCosmeticTintColor(cosmeticTint)
	end
end

ResolveWearableDisplayModel = function(self, item)
	local getOwner = self:GetOwner()
	if not istable(item) or not IsValid(getOwner) then return nil end

	local model
	if item.model_player then
		model = string.Replace(string.Replace(item.model_player, "%s", getOwner:GetPlayerClass()), "demoman", "demo")
	elseif item.model_player_per_class then
		if item.model_player_per_class[getOwner:GetPlayerClass()] then
			model = item.model_player_per_class[getOwner:GetPlayerClass()]
		else
			model = tostring(item.model_player_per_class.basename)
		end

		model = string.Replace(string.Replace(model or "", "%s", getOwner:GetPlayerClass()), "demoman", "demo")
	end

	return model
end

function ENT:Initialize()
	local getOwner = self:GetOwner()
	self.Owner = getOwner

	local item = self:GetItemData()
	local getModel = ResolveWearableDisplayModel(self, item)

	if not getModel then
		if SERVER then self:Remove() return end
		getModel = "models/empty.mdl"
	end

	self:AddEFlags(EFL_KEEP_ON_RECREATE_ENTITIES)

	self:AddToPlayerItems()
	self.ProxyentPaintColor = self

	self.Model = getModel

	if SERVER then
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)
		self:SetParent(getOwner)

		self:SetModel(self.Model)
		self:SetKeyValue("effects", "1")

		if item.set_sequence_to_class then
			self:AddEffects(EF_NOINTERP)
			self:ResetSequence(self:LookupSequence(getOwner:GetPlayerClass()))
		end
	end

	self:DrawShadow(false)

	if not IsValid(getOwner) then return end

	if item and item.visuals then -- todo: This is not looking good
		local bodygroups = item.visuals.player_bodygroups

		if bodygroups then
			if (bodygroups.hat) then
				getOwner:SetBodygroup(getOwner:FindBodygroupByName("hat"), 1)
			elseif (bodygroups.head) then
				getOwner:SetBodygroup(getOwner:FindBodygroupByName("head"), 1)
			elseif (bodygroups.headphones) then
				getOwner:SetBodygroup(getOwner:FindBodygroupByName("headphones"), 1)
			elseif (bodygroups.medal) then
				getOwner:SetBodygroup(getOwner:FindBodygroupByName("medal"), 1)
			elseif (bodygroups.grenades) then
				getOwner:SetBodygroup(getOwner:FindBodygroupByName("grenades"), 1)
			elseif (bodygroups.bullets) then
				getOwner:SetBodygroup(getOwner:FindBodygroupByName("bullets"), 1)
			elseif (bodygroups.arrows) then
				getOwner:SetBodygroup(getOwner:FindBodygroupByName("arrows"), 1)
			elseif (bodygroups.rightarm) then
				getOwner:SetBodygroup(getOwner:FindBodygroupByName("rightarm"), 1)
			elseif (bodygroups.shoes_socks) then
				getOwner:SetBodygroup(getOwner:FindBodygroupByName("shoes_socks"), 1)
			end
		end
	end

	if string.find(self:GetModel(), "_zombie") then
		if getOwner:GetPlayerClass() == "spy" then
			if getOwner:Team() == TEAM_BLU then
				getOwner:SetSkin(23)
				self:SetSkin(1)
			else
				getOwner:SetSkin(22)
				self:SetSkin(0)
			end
		else
			if getOwner:Team() == TEAM_BLU then
				getOwner:SetSkin(5)
				self:SetSkin(1)
			else
				getOwner:SetSkin(4)
				self:SetSkin(0)
			end
		end
	else
		if getOwner:Team() == TEAM_BLU or getOwner:Team() == TF_TEAM_PVE_INVADERS then
			self:SetSkin(1)
		else
			self:SetSkin(0)
		end
	end
end

function ENT:OnRemove()
	self:RemoveFromPlayerItems()
	self:StopParticles()

	if CLIENT then
		self:StopAndDestroyParticles()
	end
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

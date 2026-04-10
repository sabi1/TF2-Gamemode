ENT.PrintName = "Temporary Uber Powerup"
ENT.Author = "TF2-Gamemode"
ENT.Spawnable = false
ENT.AdminSpawnable = true

ENT.Type = "anim"
ENT.Base = "item_base"
ENT.Model = "models/pickups/pickup_powerup_uber.mdl"
ENT.RespawnTime = 180

local function playerBlockedFromTempPowerup(ply)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return true end
	if not TF_IsMannpowerMode or not TF_IsMannpowerMode() then return true end
	if ply.IsTaunting and ply:IsTaunting() then return true end
	if ply.IsStealthed and ply:IsStealthed() then return true end
	if isnumber(TF_COND_STEALTHED_BLINK) and ply.InCond and ply:InCond(TF_COND_STEALTHED_BLINK) then return true end
	if ply.GetPercentInvisible and ply:GetPercentInvisible() > 0.25 then return true end
	if ply:InCond(TF_COND_RUNE_IMBALANCE) then return true end
	if ply:InCond(TF_COND_INVULNERABLE_USER_BUFF) then return true end
	if ply:InCond(TF_COND_CRITBOOSTED_RUNE_TEMP) then return true end
	if ply:GetNWBool("InRespawnRoom", false) then return true end
	return ply.HasTheFlag and ply:HasTheFlag() or false
end

function ENT:KeyValue(key, value)
	if string.Left(key, 2) == "On" then
		self:StoreOutput(key, value)
		return
	end
	self.BaseClass.KeyValue(self, key, value)
end

function ENT:CanPickup(ply)
	return not playerBlockedFromTempPowerup(ply)
end

function ENT:PlayerTouched(pl)
	pl:AddCond(TF_COND_INVULNERABLE_USER_BUFF, 20, pl)
	pl:EmitSound("Powerup.PickUpTemp.Uber", 75, 100)
	self:TriggerOutput("OnPlayerTouch", pl)
	self:Hide()
end

function ENT:AcceptInput(name)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self:Show()
		return true
	elseif name == "disable" then
		self:SetTrigger(false)
		self:SetNoDraw(true)
		self:DrawShadow(false)
		return true
	end
	return false
end

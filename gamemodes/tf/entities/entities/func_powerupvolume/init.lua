ENT.Base = "base_brush"
ENT.Type = "brush"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = tonumber((self.Properties or {}).startdisabled or 0) == 1
	self.TeamNum = self.TeamNum or TEAM_UNASSIGNED
	self.NumberOfTimesUsed = 0
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "startdisabled" then
		self.Disabled = tonumber(value) == 1
	elseif key == "teamnum" then
		local teamNum = tonumber(value)
		if teamNum == 2 then
			self.TeamNum = TEAM_RED
		elseif teamNum == 3 then
			self.TeamNum = TEAM_BLU
		else
			self.TeamNum = TEAM_UNASSIGNED
		end
	end
end

function ENT:StartTouch(ent)
	if self.Disabled then return end
	if not TF_IsMannpowerMode or not TF_IsMannpowerMode() then return end
	if not IsValid(ent) or not ent:IsTFPlayer() or not ent:Alive() then return end
	if ent:IsTaunting() then return end
	if ent:InCond(TF_COND_RUNE_IMBALANCE) then return end
	if GAMEMODE and GAMEMODE.RoundHasWinner then return end
	if self.TeamNum ~= TEAM_UNASSIGNED and ent:Team() ~= self.TeamNum then return end

	ent:AddCond(TF_COND_RUNE_IMBALANCE, 20, ent)
	ent:AddCond(TF_COND_CRITBOOSTED_RUNE_TEMP, 20, ent)
	ent:EmitSound("Powerup.Volume.Use", 75, 100)
	self.NumberOfTimesUsed = self.NumberOfTimesUsed + 1
end

function ENT:EndTouch(ent)
end

function ENT:AcceptInput(name)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Disabled = false
		return true
	elseif name == "disable" then
		self.Disabled = true
		return true
	end
	return false
end

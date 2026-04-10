ENT.Base = "base_brush"
ENT.Type = "brush"

local function apply_stun_like_valve(ply, duration, moveReduction, stunType, stunEffects, inflictor)
	duration = math.max(tonumber(duration) or 0, 0)
	moveReduction = math.Clamp(tonumber(moveReduction) or 0, 0, 1)
	stunType = tonumber(stunType) or 0

	if ply.StunPlayer then
		local flags = 0
		if stunType == 1 then
			flags = bit.bor(flags, TF_STUN_CONTROLS or 0)
		elseif stunType == 2 then
			flags = bit.bor(flags, TF_STUN_LOSER_STATE or 0, TF_STUN_CONTROLS or 0)
		end
		if not stunEffects then
			flags = bit.bor(flags, TF_STUN_NO_EFFECTS or 0)
		end
		flags = bit.bor(flags, TF_STUN_BY_TRIGGER or 0, TF_STUN_MOVEMENT or 0)
		return pcall(ply.StunPlayer, ply, duration, moveReduction, flags, inflictor)
	end

	ply:AddCond(TF_COND_STUNNED, duration, inflictor)
	if stunType >= 1 then
		ply:AddCond(TF_COND_FREEZE_INPUT, duration, inflictor)
	end
	ply._tfTriggerStunMoveScale = 1 - moveReduction
	timer.Create("TFTriggerStunEnd" .. ply:EntIndex(), duration, 1, function()
		if not IsValid(ply) then return end
		ply._tfTriggerStunMoveScale = nil
		if ply.InCond and ply:InCond(TF_COND_FREEZE_INPUT) then
			ply:RemoveCond(TF_COND_FREEZE_INPUT, true)
		end
	end)
	return true
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.TriggerDelay = 0
	self.StunDuration = 0
	self.MoveSpeedReduction = 0
	self.StunType = 0
	self.StunEffects = false
	self.PendingTouchers = {}
	self.StunnedTouchers = {}
	self:SetNoDraw(true)
	self:RefreshSettings()
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if string.StartWith(key, "on") then
		self:StoreOutput(key, value)
		return
	end

	self:RefreshSettings()
end

function ENT:RefreshSettings()
	self.TriggerDelay = tonumber(self.Properties.trigger_delay) or 0
	self.StunDuration = tonumber(self.Properties.stun_duration) or 0
	self.MoveSpeedReduction = tonumber(self.Properties.move_speed_reduction) or 0
	self.StunType = tonumber(self.Properties.stun_type) or 0
	self.StunEffects = tonumber(self.Properties.stun_effects) == 1
end

function ENT:CanStun(ent)
	if not IsValid(ent) or not ent:IsPlayer() then return false end
	if not ent:Alive() then return false end
	if self.PassesTriggerFilters and not self:PassesTriggerFilters(ent) then return false end
	return true
end

function ENT:StunEntity(ent)
	if not self:CanStun(ent) then return false end
	local ok = apply_stun_like_valve(ent, self.StunDuration, self.MoveSpeedReduction, self.StunType, self.StunEffects, self)
	if ok then
		self.StunnedTouchers[ent] = true
		self:TriggerOutput("OnStunPlayer", ent)
	end
	return ok and true or false
end

function ENT:StunAllTouchers()
	local count = 0
	self.StunnedTouchers = {}
	local mins, maxs = self:WorldSpaceAABB()

	for _, ent in ipairs(ents.FindInBox(mins, maxs)) do
		if self:CanStun(ent) and self:PointIsWithin(ent:WorldSpaceCenter()) then
			if self:StunEntity(ent) then
				count = count + 1
			end
		end
	end

	return count
end

function ENT:Think()
	local now = CurTime()
	for ent, dueAt in pairs(self.PendingTouchers) do
		if not IsValid(ent) then
			self.PendingTouchers[ent] = nil
		elseif now >= dueAt then
			self.PendingTouchers[ent] = nil
			self:StunEntity(ent)
		end
	end

	if next(self.StunnedTouchers) ~= nil then
		if self:StunAllTouchers() <= 0 then
			self.StunnedTouchers = {}
		end
	end

	self:NextThink(now + 0.5)
	return true
end

function ENT:StartTouch(ent)
	if not self:CanStun(ent) then return end
	if self.TriggerDelay <= 0 then
		self:StunEntity(ent)
	else
		self.PendingTouchers[ent] = CurTime() + self.TriggerDelay
	end
	self:NextThink(CurTime() + 0.01)
end

function ENT:EndTouch(ent)
	self.PendingTouchers[ent] = nil
	if not self.StunnedTouchers[ent] then
		self:StunEntity(ent)
	end
	self.StunnedTouchers[ent] = nil
end

function ENT:AcceptInput(name, activator, caller, data)
	return false
end

ENT.Base = "base_brush"
ENT.Type = "brush"

local function getActivePasstimeTarget()
	for _, logic in ipairs(ents.FindByClass("passtime_logic")) do
		if not (IsValid(logic) and not logic.Disabled) then continue end

		local carrier = TF_GetPasstimeBallCarrier and TF_GetPasstimeBallCarrier() or logic.BallCarrier
		if IsValid(carrier) then
			return carrier
		end

		if IsValid(logic.BallEntity) then
			return logic.BallEntity
		end
	end

	return nil
end

function TF_PasstimeEntityInNoBallZone(target)
	if not IsValid(target) then return false end
	for _, zone in ipairs(ents.FindByClass("func_passtime_no_ball_zone")) do
		if IsValid(zone) and not zone.Disabled and zone.Touching and zone.Touching[target] then
			return true
		end
	end
	return false
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = tonumber((self.Properties or {}).startdisabled or 0) == 1
	self.Touching = {}
	self.BallPresent = false
	self.CurrentBall = NULL
	self:NextThink(CurTime())
end

function ENT:KeyValue(key, value)
	if string.Left(key, 2) == "On" then
		self:StoreOutput(key, value)
	end

	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:StartTouch(ent)
	if IsValid(ent) then
		self.Touching[ent] = true
	end
end

function ENT:EndTouch(ent)
	self.Touching[ent] = nil
end

function ENT:Think()
	local tracked = getActivePasstimeTarget()
	local presentNow = IsValid(tracked) and self.Touching and self.Touching[tracked] and not self.Disabled

	if presentNow and not self.BallPresent then
		self.CurrentBall = tracked
		self:TriggerOutput("OnBallEnter", tracked)
	elseif not presentNow and self.BallPresent then
		self:TriggerOutput("OnBallExit", IsValid(self.CurrentBall) and self.CurrentBall or self)
		self.CurrentBall = NULL
	end

	self.BallPresent = presentNow
	self:NextThink(CurTime())
	return true
end

function ENT:AcceptInput(name, activator, caller, data)
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

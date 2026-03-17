ENT.Base = "base_brush"
ENT.Type = "brush"

local function getActivePasstimeBallEntity()
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

local function isInsideBrush(brush, ent)
	if not (IsValid(brush) and IsValid(ent)) then return false end
	local mins, maxs = brush:WorldSpaceAABB()
	local pos = ent.WorldSpaceCenter and ent:WorldSpaceCenter() or ent:GetPos()
	return pos.x >= mins.x and pos.x <= maxs.x
		and pos.y >= mins.y and pos.y <= maxs.y
		and pos.z >= mins.z and pos.z <= maxs.z
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.CurrentBall = NULL
	self.BallPresent = false
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

function ENT:Think()
	local tracked = getActivePasstimeBallEntity()
	local presentNow = IsValid(tracked) and isInsideBrush(self, tracked)

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
	return false
end

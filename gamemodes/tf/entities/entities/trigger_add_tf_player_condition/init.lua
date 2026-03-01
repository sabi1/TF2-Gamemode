ENT.Base = "base_brush"
ENT.Type = "brush"

local function to_bool(v, default)
	if v == nil then return default end
	if isbool(v) then return v end
	local s = string.lower(tostring(v))
	if s == "1" or s == "true" or s == "yes" then return true end
	if s == "0" or s == "false" or s == "no" then return false end
	return default
end

local function resolve_cond(v)
	if v == nil then return nil end
	local n = tonumber(v)
	if n ~= nil then return math.floor(n) end
	local name = string.upper(tostring(v))
	if not string.StartWith(name, "TF_COND_") then
		name = "TF_COND_" .. name
	end
	return TF_COND and TF_COND[name] or nil
end

local function target_ok(ent)
	return IsValid(ent) and ent:IsPlayer() and ent.AddCond ~= nil
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self:SetTrigger(true)
	self.Enabled = not to_bool(self.Properties.startdisabled, false)
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if key == "startdisabled" then
		self.Enabled = not to_bool(value, false)
	end
end

function ENT:GetConditionId()
	return resolve_cond(self.Properties.condition or self.Properties.cond or self.Properties.playercondition or self.Properties.addcondition)
end

function ENT:GetDuration()
	local d = tonumber(self.Properties.duration or self.Properties.condduration or self.Properties.addduration)
	if d == nil then
		return PERMANENT_CONDITION or -1
	end
	return d
end

function ENT:ShouldRemoveOnEndTouch()
	if to_bool(self.Properties.removeonendtouch, false) then
		return true
	end
	return self:GetDuration() == (PERMANENT_CONDITION or -1)
end

function ENT:ApplyAdd(ent, provider)
	if not self.Enabled or not target_ok(ent) then return end
	local cond = self:GetConditionId()
	if cond == nil then return end
	ent:AddCond(cond, self:GetDuration(), IsValid(provider) and provider or ent)
end

function ENT:StartTouch(ent)
	self:ApplyAdd(ent, ent)
end

function ENT:EndTouch(ent)
	if not self.Enabled or not target_ok(ent) then return end
	local cond = self:GetConditionId()
	if cond == nil then return end
	if self:ShouldRemoveOnEndTouch() then
		ent:RemoveCond(cond, true)
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Enabled = true
		return true
	end
	if name == "disable" then
		self.Enabled = false
		return true
	end
	if name == "toggle" then
		self.Enabled = not self.Enabled
		return true
	end
	if name == "addcond" or name == "applycondition" then
		local target = IsValid(activator) and activator or caller
		self:ApplyAdd(target, caller or activator)
		return true
	end
	return false
end

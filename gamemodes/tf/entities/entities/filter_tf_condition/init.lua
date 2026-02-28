ENT.Type = "point"

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

function ENT:Initialize()
	self.Properties = self.Properties or {}
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:GetConditionId()
	return resolve_cond(self.Properties.condition or self.Properties.cond or self.Properties.playercondition)
end

function ENT:PassesFilter(ent)
	if not IsValid(ent) or not ent.InCond then
		return false
	end

	local cond = self:GetConditionId()
	if cond == nil then
		return false
	end

	local in_cond = ent:InCond(cond)
	if to_bool(self.Properties.negated or self.Properties.inverted or self.Properties.exclude, false) then
		in_cond = not in_cond
	end
	return in_cond
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "testactivator" then
		local target = IsValid(activator) and activator or caller
		if self:PassesFilter(target) then
			self:Fire("OnPass", "", 0, activator, caller)
			return true
		end
		self:Fire("OnFail", "", 0, activator, caller)
		return false
	end
	return false
end

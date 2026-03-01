ENT.Base = "base_brush"
ENT.Type = "brush"

local function to_bool(v, default)
	if v == nil then return default end
	if isbool(v) then return v end
	local s = string.lower(tostring(v))
	if s == "1" or s == "true" or s == "yes" or s == "on" then return true end
	if s == "0" or s == "false" or s == "no" or s == "off" then return false end
	return default
end

local function to_num(v, default)
	local n = tonumber(v)
	if n == nil then return default end
	return n
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
	return IsValid(ent) and ent:IsPlayer()
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.PlayerAttribBackup = self.PlayerAttribBackup or {}
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
	return resolve_cond(
		self.Properties.condition
		or self.Properties.cond
		or self.Properties.playercondition
		or self.Properties.addcondition
		or self.Properties.removecondition
	)
end

function ENT:GetDuration()
	local d = to_num(self.Properties.duration or self.Properties.condduration or self.Properties.addduration, nil)
	if d == nil then
		return PERMANENT_CONDITION or -1
	end
	return d
end

function ENT:GetMode()
	if to_bool(self.Properties.remove, false) then return "remove" end
	if to_bool(self.Properties.add, false) then return "add" end

	local mode = string.lower(tostring(self.Properties.mode or self.Properties.action or self.Properties.addorremove or ""))
	if mode == "remove" or mode == "1" then return "remove" end
	if mode == "add" or mode == "0" then return "add" end

	return "add"
end

function ENT:GetAttributeName()
	return tostring(self.Properties.attribute_name or self.Properties.attributename or self.Properties.attribute or "")
end

function ENT:GetAttributeValue()
	local v = self.Properties.attribute_value
	if v == nil then v = self.Properties.attributevalue end
	if v == nil then v = self.Properties.value end
	if v == nil then v = 1 end
	if tonumber(v) ~= nil then return tonumber(v) end
	if isbool(v) then return v end
	return tostring(v)
end

function ENT:ApplyTempAttribute(ent)
	local name = self:GetAttributeName()
	if name == "" or not ent.TempAttributes then return end

	self.PlayerAttribBackup = self.PlayerAttribBackup or {}
	self.PlayerAttribBackup[ent] = self.PlayerAttribBackup[ent] or {}
	if self.PlayerAttribBackup[ent][name] == nil then
		self.PlayerAttribBackup[ent][name] = ent.TempAttributes[name]
	end

	ent.TempAttributes[name] = self:GetAttributeValue()
end

function ENT:RestoreTempAttribute(ent)
	local name = self:GetAttributeName()
	if name == "" or not ent.TempAttributes then return end
	if not self.PlayerAttribBackup or not self.PlayerAttribBackup[ent] then return end

	local old = self.PlayerAttribBackup[ent][name]
	if old == nil then
		ent.TempAttributes[name] = nil
	else
		ent.TempAttributes[name] = old
	end

	self.PlayerAttribBackup[ent][name] = nil
	if next(self.PlayerAttribBackup[ent]) == nil then
		self.PlayerAttribBackup[ent] = nil
	end
end

function ENT:ApplyTo(ent, forcedMode)
	if not self.Enabled or not target_ok(ent) then return end

	local cond = self:GetConditionId()
	local mode = forcedMode or self:GetMode()

	if cond ~= nil and ent.AddCond and ent.RemoveCond then
		if mode == "remove" then
			ent:RemoveCond(cond, true)
		else
			ent:AddCond(cond, self:GetDuration(), ent)
		end
	end

	if mode == "remove" then
		self:RestoreTempAttribute(ent)
	else
		self:ApplyTempAttribute(ent)
	end
end

function ENT:StartTouch(ent)
	self:ApplyTo(ent)
end

function ENT:EndTouch(ent)
	if not self.Enabled or not target_ok(ent) then return end

	if to_bool(self.Properties.removeonendtouch, false) then
		self:ApplyTo(ent, "remove")
	elseif to_bool(self.Properties.addonendtouch, false) then
		self:ApplyTo(ent, "add")
	else
		-- Default Source behavior is to undo temporary effects when leaving the trigger.
		self:RestoreTempAttribute(ent)
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

	local target = IsValid(activator) and activator or caller
	if name == "add" or name == "addcond" or name == "addcondition" then
		self:ApplyTo(target, "add")
		return true
	end
	if name == "remove" or name == "removecond" or name == "removecondition" then
		self:ApplyTo(target, "remove")
		return true
	end
	if name == "apply" or name == "applytoactivator" then
		self:ApplyTo(target)
		return true
	end
	return false
end
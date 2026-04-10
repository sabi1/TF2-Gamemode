ENT.Type = "point"

local TF_CLASS_BY_ID = {
	[1] = "scout",
	[2] = "sniper",
	[3] = "soldier",
	[4] = "demoman",
	[5] = "medic",
	[6] = "heavy",
	[7] = "pyro",
	[8] = "spy",
	[9] = "engineer",
}

local CLASS_ALIASES = {
	["demo"] = "demoman",
}

local function to_bool(v, default)
	if v == nil then return default end
	if isbool(v) then return v end
	local s = string.lower(tostring(v))
	if s == "1" or s == "true" or s == "yes" then return true end
	if s == "0" or s == "false" or s == "no" then return false end
	return default
end

local function get_canonical_class_name(ply)
	if not (IsValid(ply) and ply:IsPlayer()) then
		return ""
	end

	local className = ""
	if ply.GetPlayerClass then
		className = string.lower(string.Trim(tostring(ply:GetPlayerClass() or "")))
	end

	local classTable = ply.GetPlayerClassTable and ply:GetPlayerClassTable() or nil
	if istable(classTable) and isstring(classTable.ModelName) and classTable.ModelName ~= "" then
		className = string.lower(string.Trim(classTable.ModelName))
	end

	className = CLASS_ALIASES[className] or className
	return className
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:GetFilteredClassName()
	local raw = self.Properties.tfclass or self.Properties.class or self.Properties.playerclass
	if raw == nil then
		return ""
	end

	local classId = tonumber(raw)
	if classId ~= nil then
		return TF_CLASS_BY_ID[classId] or ""
	end

	return CLASS_ALIASES[string.lower(string.Trim(tostring(raw)))] or string.lower(string.Trim(tostring(raw)))
end

function ENT:PassesFilter(ent)
	if not (IsValid(ent) and ent:IsPlayer()) then
		return false
	end

	if ent.GetObserverMode and ent:GetObserverMode() ~= OBS_MODE_NONE then
		return false
	end

	local wanted = self:GetFilteredClassName()
	if wanted == "" then
		return false
	end

	local pass = get_canonical_class_name(ent) == wanted
	if to_bool(self.Properties.negated, false) then
		pass = not pass
	end
	return pass
end

function ENT:AcceptInput(name, activator, caller)
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

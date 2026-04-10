ENT.Type = "point"

local function split_tags(raw)
	local out = {}
	for token in string.gmatch(tostring(raw or ""), "%S+") do
		out[#out + 1] = string.lower(token)
	end
	return out
end

local function bot_has_tag(ent, tag)
	if not IsValid(ent) then return false end
	if ent.HasTag then
		local ok, result = pcall(ent.HasTag, ent, tag)
		if ok then
			return result and true or false
		end
	end

	local tags = rawget(ent, "Tags") or rawget(ent, "tags") or rawget(ent, "TFBotTags")
	if istable(tags) then
		for k, v in pairs(tags) do
			if string.lower(tostring(k)) == tag and v then
				return true
			end
			if string.lower(tostring(v)) == tag then
				return true
			end
		end
	end

	local tagString = ent.GetNWString and ent:GetNWString("TFBotTags", "") or ""
	if tagString ~= "" then
		for _, v in ipairs(split_tags(tagString)) do
			if v == tag then
				return true
			end
		end
	end

	return false
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.RequiredTags = split_tags(self.Properties.tags)
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if key == "tags" then
		self.RequiredTags = split_tags(value)
	end
end

function ENT:PassesFilter(ent)
	if not (IsValid(ent) and ent:IsPlayer() and ent:IsBot()) then
		return false
	end

	local tags = self.RequiredTags or split_tags(self.Properties.tags)
	if #tags == 0 then
		return false
	end

	local requireAll = tonumber(self.Properties.require_all_tags)
	requireAll = (requireAll == nil) and true or (requireAll ~= 0)

	local anyMatched = false
	for _, tag in ipairs(tags) do
		local hasTag = bot_has_tag(ent, tag)
		if hasTag then
			anyMatched = true
			if not requireAll then
				return true
			end
		elseif requireAll then
			return false
		end
	end

	return anyMatched
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

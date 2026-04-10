ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.LinkedSentryHints = {}
	self.LinkedTeleporterHints = {}
	self:SetNWBool("HasActiveTeleporter", false)
	self:NextThink(CurTime() + 0.1)
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

local function sameName(a, b)
	if not (IsValid(a) and IsValid(b)) then return false end
	local an = tostring((a.GetName and a:GetName()) or "")
	local bn = tostring((b.GetName and b:GetName()) or "")
	return an ~= "" and an == bn
end

local function cleanupHintList(list)
	local out = {}
	for _, hint in ipairs(list or {}) do
		if IsValid(hint) then
			out[#out + 1] = hint
		end
	end
	return out
end

function ENT:RefreshLinkedHints()
	self.LinkedSentryHints = {}
	self.LinkedTeleporterHints = {}

	for _, hint in ipairs(ents.FindByClass("bot_hint_sentrygun")) do
		if sameName(self, hint) then
			self.LinkedSentryHints[#self.LinkedSentryHints + 1] = hint
		end
	end

	for _, hint in ipairs(ents.FindByClass("bot_hint_teleporter_exit")) do
		if sameName(self, hint) then
			self.LinkedTeleporterHints[#self.LinkedTeleporterHints + 1] = hint
		end
	end
end

function ENT:IsStaleNest()
	self.LinkedSentryHints = cleanupHintList(self.LinkedSentryHints)
	self.LinkedTeleporterHints = cleanupHintList(self.LinkedTeleporterHints)

	for _, hint in ipairs(self.LinkedSentryHints) do
		if hint.OwnerObjectHasNoOwner and hint:OwnerObjectHasNoOwner() then
			return true
		end
	end

	for _, hint in ipairs(self.LinkedTeleporterHints) do
		if hint.OwnerObjectHasNoOwner and hint:OwnerObjectHasNoOwner() then
			return true
		end
	end

	return false
end

function ENT:DetonateStaleNest()
	self.LinkedSentryHints = cleanupHintList(self.LinkedSentryHints)
	self.LinkedTeleporterHints = cleanupHintList(self.LinkedTeleporterHints)

	local function detonateFromHints(list)
		for _, hint in ipairs(list) do
			if hint.OwnerObjectHasNoOwner and hint:OwnerObjectHasNoOwner() then
				local owner = hint:GetOwner()
				if IsValid(owner) and owner.DetonateObject then
					owner:DetonateObject()
				end
			end
		end
	end

	detonateFromHints(self.LinkedSentryHints)
	detonateFromHints(self.LinkedTeleporterHints)
end

local function getHint(list)
	list = cleanupHintList(list)
	if #list <= 0 then
		return nil
	end

	for _, hint in ipairs(list) do
		if hint.OwnerObjectHasNoOwner and hint:OwnerObjectHasNoOwner() then
			return hint
		end
	end

	return list[math.random(#list)]
end

function ENT:GetSentryHint()
	return getHint(self.LinkedSentryHints)
end

function ENT:GetTeleporterHint()
	return getHint(self.LinkedTeleporterHints)
end

function ENT:Think()
	self:RefreshLinkedHints()

	local hasActiveTeleporter = false
	for _, hint in ipairs(self.LinkedTeleporterHints) do
		local owner = hint:GetOwner()
		if IsValid(owner) and owner.GetBuilder and owner.IsBuilding and not owner:IsBuilding() then
			hasActiveTeleporter = true
			break
		end
	end

	self:SetNWBool("HasActiveTeleporter", hasActiveTeleporter)
	self:NextThink(CurTime() + 0.1)
	return true
end

function ENT:AcceptInput(name)
	name = string.lower(tostring(name or ""))
	if name == "detonatestalenest" then
		self:DetonateStaleNest()
		return true
	end
	return false
end

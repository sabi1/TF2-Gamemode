ENT.Type = "point"

local FILTERS = FILTERS or {}

local function refreshFilters()
	for i = #FILTERS, 1, -1 do
		if not IsValid(FILTERS[i]) then
			table.remove(FILTERS, i)
		end
	end
end

function TF_PassesDamageFilter(filterEnt, dmginfo)
	if not (IsValid(filterEnt) and dmginfo) then
		return false
	end
	return filterEnt:PassesDamageFilter(dmginfo)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.WeaponSlot = tonumber(self.Properties.weaponslot or 0) or 0
	refreshFilters()
	table.insert(FILTERS, self)
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value

	if key == "weaponslot" then
		self.WeaponSlot = tonumber(value or 0) or 0
	end
end

function ENT:PassesDamageFilter(dmginfo)
	if not dmginfo then
		return false
	end

	local weapon = dmginfo.GetWeapon and dmginfo:GetWeapon() or nil
	if not IsValid(weapon) then
		return false
	end

	local slot = weapon.GetSlot and weapon:GetSlot()
	return tonumber(slot) == tonumber(self.WeaponSlot or 0)
end

function ENT:AcceptInput(name)
	name = string.lower(tostring(name or ""))
	if name == "testactivator" then
		return false
	end
	return false
end

function ENT:OnRemove()
	refreshFilters()
end

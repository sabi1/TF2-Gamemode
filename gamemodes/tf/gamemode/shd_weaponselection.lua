function TF_NormalizeWeaponAmmoType(ammoType)
	if ammoType == nil then return nil end
	if isstring(ammoType) then
		local lowered = string.lower(ammoType)
		if lowered == "" or lowered == "none" then
			return nil
		end
	end
	return ammoType
end

function TF_WeaponSlotIndex(wep)
	if not IsValid(wep) then return 0 end
	local slot = wep.Slot
	if slot == nil and isfunction(wep.GetSlot) then
		slot = wep:GetSlot()
	end
	return tonumber(slot) or 0
end

function TF_WeaponIsMedigunForSelection(wep)
	if not IsValid(wep) then return false end
	local class = wep:GetClass()
	if not isstring(class) then return false end
	return class == "tf_weapon_ampgun"
		or class == "tf_weapon_builder"
		or string.find(class, "tf_weapon_medigun", 1, true) == 1
end

function TF_WeaponHasUsableAmmoForSelection(wep, ownerOverride)
	if not IsValid(wep) then return false end

	local class = wep:GetClass()
	if class == "tf_weapon_passtime_gun" then
		return true
	end

	if class == "tf_weapon_invis" or class == "tf_weapon_invis_dringer"
		or class == "tf_weapon_builder" or class == "tf_weapon_sapper" or class == "tf_weapon_rtr"
	then
		return true
	end

	if string.find(class, "tf_weapon_pda_engineer", 1, true) == 1 then
		return true
	end

	if wep.Hidden or wep.IsPDA then
		return true
	end

	if TF_WeaponIsMedigunForSelection(wep) then
		return true
	end

	local primary = wep.Primary or {}
	local clipSize = tonumber(primary.ClipSize or -1) or -1
	local clip = tonumber((wep.Clip1 and wep:Clip1()) or -1) or -1
	local ammoType = TF_NormalizeWeaponAmmoType(primary.Ammo)
	local reserve = tonumber((wep.Ammo1 and wep:Ammo1()) or -1) or -1
	local owner = ownerOverride
	if not IsValid(owner) and wep.GetOwner then
		owner = wep:GetOwner()
	end

	-- Some throwables while holstered can report stale Ammo1().
	-- Resolve reserve ammo from all known pools and use the max.
	if IsValid(owner) and owner.GetAmmoCount then
		if ammoType ~= nil then
			local ownerReserveByName = tonumber(owner:GetAmmoCount(ammoType) or -1) or -1
			if ownerReserveByName > reserve then
				reserve = ownerReserveByName
			end
		end
		if isfunction(wep.GetPrimaryAmmoType) then
			local primaryAmmoType = wep:GetPrimaryAmmoType()
			if isnumber(primaryAmmoType) and primaryAmmoType >= 0 then
				local ownerReserveById = tonumber(owner:GetAmmoCount(primaryAmmoType) or -1) or -1
				if ownerReserveById > reserve then
					reserve = ownerReserveById
				end
			end
		end
	end

	-- Throwables can be readiness-driven; trust full meter as usable.
	if wep.HasCustomMeleeBehaviour and isfunction(wep.GetHUDMeterValue) then
		local meter = tonumber(wep:GetHUDMeterValue() or 0) or 0
		if meter >= 0.999 then
			return true
		end
	end

	if wep.IsMeleeWeapon and ammoType == nil then
		return true
	end

	if clipSize < 0 and ammoType == nil and clip < 0 and reserve < 0 then
		return true
	end

	if clip > 0 then
		return true
	end

	if reserve > 0 then
		return true
	end

	return false
end

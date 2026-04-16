TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.FetchFlag = TFBotSource.Actions.FetchFlag or {}

local M = TFBotSource.Actions.FetchFlag

local function is_mvm_mode()
	return GAMEMODE and GAMEMODE.IsMannVsMachineMode and GAMEMODE:IsMannVsMachineMode()
end

local function get_flag_to_fetch()
	for _, cls in ipairs({"item_teamflag_mvm", "item_teamflag"}) do
		for _, ent in ipairs(ents.FindByClass(cls)) do
			if IsValid(ent) then
				return ent
			end
		end
	end
	return nil
end

local function get_flag_carrier(flag)
	if not IsValid(flag) then return nil end
	if IsValid(flag.Carrier) then
		return flag.Carrier
	end
	if flag.GetCarrier then
		local ok, carrier = pcall(flag.GetCarrier, flag)
		if ok and IsValid(carrier) then
			return carrier
		end
	end
	if flag.GetOwnerEntity then
		local ok, owner = pcall(flag.GetOwnerEntity, flag)
		if ok and IsValid(owner) then
			return owner
		end
	end
	if flag.GetOwner then
		local ok, owner = pcall(flag.GetOwner, flag)
		if ok and IsValid(owner) then
			return owner
		end
	end
	return nil
end

local function is_flag_dropped(flag)
	if not IsValid(flag) then return false end
	if flag.IsDropped then
		local ok, dropped = pcall(flag.IsDropped, flag)
		if ok then
			return dropped == true
		end
	end
	return get_flag_carrier(flag) == nil and tonumber(flag.State or -1) == 2
end

local function is_flag_home(flag)
	if not IsValid(flag) then return false end
	if flag.IsHome then
		local ok, home = pcall(flag.IsHome, flag)
		if ok then
			return home == true
		end
	end
	return get_flag_carrier(flag) == nil and not is_flag_dropped(flag)
end

local function world_center(ent)
	if not IsValid(ent) then return nil end
	if ent.WorldSpaceCenter then
		local ok, pos = pcall(ent.WorldSpaceCenter, ent)
		if ok and isvector(pos) then
			return pos
		end
	end
	return ent.GetPos and ent:GetPos() or nil
end

local function should_autopickup_home_flag(bot)
	if not IsValid(bot) or not bot.GetSpawnTime then return false end
	return (CurTime() - (tonumber(bot:GetSpawnTime()) or CurTime())) < 1.0
end

local function try_pickup_flag(flag, bot)
	if not (IsValid(flag) and IsValid(bot) and flag.Pickup) then
		return false
	end
	if flag.CanPickup then
		local ok, canPickup = pcall(flag.CanPickup, flag, bot)
		if ok and canPickup == false then
			return false
		end
	end
	local ok = pcall(flag.Pickup, flag, bot)
	if not ok then
		return false
	end
	return get_flag_carrier(flag) == bot
end

function M:Update(bot, st, profile)
	if not (IsValid(bot) and st) then return false end
	local flag = get_flag_to_fetch()
	if not IsValid(flag) then
		if is_mvm_mode() and TFBotSource.Actions.AttackFlagDefenders and TFBotSource.Actions.AttackFlagDefenders.Update then
			return TFBotSource.Actions.AttackFlagDefenders:Update(bot, st, profile)
		end
		return TFBotSource.Actions.SeekAndDestroy:Update(bot, st, profile)
	end

	local carrier = get_flag_carrier(flag)
	if carrier == bot and TFBotSource.Actions.DeliverFlag and TFBotSource.Actions.DeliverFlag.Update then
		return TFBotSource.Actions.DeliverFlag:Update(bot, st, profile)
	end

	if is_mvm_mode() and is_flag_home(flag) then
		if should_autopickup_home_flag(bot) and bot:Team() ~= TEAM_SPECTATOR and try_pickup_flag(flag, bot) then
			if TFBotSource.Actions.DeliverFlag and TFBotSource.Actions.DeliverFlag.Update then
				return TFBotSource.Actions.DeliverFlag:Update(bot, st, profile)
			end
			TFBotSource.Core:SetActionTarget(bot, st, "fetch_flag", flag, world_center(flag))
			return true
		end
		if TFBotSource.Actions.AttackFlagDefenders and TFBotSource.Actions.AttackFlagDefenders.Update then
			return TFBotSource.Actions.AttackFlagDefenders:Update(bot, st, profile)
		end
	end

	if IsValid(carrier) and carrier ~= bot then
		if TFBotSource.Actions.AttackFlagDefenders and TFBotSource.Actions.AttackFlagDefenders.Update then
			return TFBotSource.Actions.AttackFlagDefenders:Update(bot, st, profile)
		end
		TFBotSource.Core:SetActionTarget(bot, st, "attack_flag_defenders", carrier, world_center(carrier))
		return true
	end

	TFBotSource.Core:SetActionTarget(bot, st, "fetch_flag", flag, world_center(flag))
	return true
end

return M

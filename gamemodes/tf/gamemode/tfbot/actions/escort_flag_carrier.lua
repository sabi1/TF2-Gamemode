TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.EscortFlagCarrier = TFBotSource.Actions.EscortFlagCarrier or {}

local M = TFBotSource.Actions.EscortFlagCarrier

local cv_escort_range = CreateConVar("tf_bot_source_flag_escort_range", "500", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Preferred escort distance from the flag carrier.")
local cv_escort_giveup = CreateConVar("tf_bot_source_flag_escort_give_up_range", "1000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Distance where escorting gives up and switches back to defender pressure.")

local function get_flag()
	for _, cls in ipairs({"item_teamflag_mvm", "item_teamflag"}) do
		for _, ent in ipairs(ents.FindByClass(cls)) do
			if IsValid(ent) then
				return ent
			end
		end
	end
	return nil
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

function M:Update(bot, st)
	if not (IsValid(bot) and st) then return false end
	local flag = get_flag()
	if not IsValid(flag) then
		return TFBotSource.Actions.FetchFlag:Update(bot, st)
	end

	local carrier = (flag.GetOwnerEntity and flag:GetOwnerEntity()) or (flag.GetOwner and flag:GetOwner()) or nil
	if not IsValid(carrier) then
		return TFBotSource.Actions.FetchFlag:Update(bot, st)
	end
	if carrier == bot then
		return TFBotSource.Actions.FetchFlag:Update(bot, st)
	end

	local carrierPos = world_center(carrier)
	if not isvector(carrierPos) then
		return false
	end

	if bot:GetPos():DistToSqr(carrierPos) > (cv_escort_giveup:GetFloat() * cv_escort_giveup:GetFloat()) then
		return TFBotSource.Actions.AttackFlagDefenders:Update(bot, st)
	end

	if bot:GetPos():DistToSqr(carrierPos) <= ((cv_escort_range:GetFloat() * 0.5) ^ 2) then
		TFBotSource.Core:SetActionTarget(bot, st, "escort_flag_carrier_hold", carrier, carrierPos)
		return true
	end

	TFBotSource.Core:SetActionTarget(bot, st, "escort_flag_carrier", carrier, carrierPos)
	return true
end

return M

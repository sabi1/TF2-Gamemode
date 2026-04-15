TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.FetchFlag = TFBotSource.Actions.FetchFlag or {}

local M = TFBotSource.Actions.FetchFlag

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
	local flag = get_flag_to_fetch()
	if not IsValid(flag) then
		return TFBotSource.Actions.Attack:Update(bot, st)
	end

	local owner = (flag.GetOwnerEntity and flag:GetOwnerEntity()) or (flag.GetOwner and flag:GetOwner()) or nil
	if IsValid(owner) and owner ~= bot then
		TFBotSource.Core:SetActionTarget(bot, st, "attack_flag_defenders", owner, world_center(owner))
		return true
	end

	TFBotSource.Core:SetActionTarget(bot, st, "fetch_flag", flag, world_center(flag))
	return true
end

return M

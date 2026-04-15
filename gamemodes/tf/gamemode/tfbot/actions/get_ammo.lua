TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.GetAmmo = TFBotSource.Actions.GetAmmo or {}

local M = TFBotSource.Actions.GetAmmo

local cv_search = CreateConVar("tf_bot_source_ammo_search_range", "5000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Search range for ammo.")

local AMMO_CLASSES = {
	"tf_ammo_pack",
	"item_ammopack_small",
	"item_ammopack_medium",
	"item_ammopack_full",
	"obj_dispenser",
	"func_regenerate",
}

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

local function isAmmoUsable(bot, ent)
	if not (IsValid(bot) and IsValid(ent)) then return false end
	local cls = string.lower(tostring(ent.GetClass and ent:GetClass() or ""))
	if cls == "obj_dispenser" then
		return ent:Team() == bot:Team()
	end
	return true
end

function M:FindTarget(bot)
	local maxDist2 = cv_search:GetFloat() * cv_search:GetFloat()
	local best, bestDist

	for _, cls in ipairs(AMMO_CLASSES) do
		for _, ent in ipairs(ents.FindByClass(cls)) do
			if not isAmmoUsable(bot, ent) then continue end
			local pos = world_center(ent)
			if not isvector(pos) then continue end
			local d2 = bot:GetPos():DistToSqr(pos)
			if d2 <= maxDist2 and (not bestDist or d2 < bestDist) then
				best = ent
				bestDist = d2
			end
		end
	end

	return best
end

function M:IsPossible(bot)
	return IsValid(self:FindTarget(bot))
end

function M:Update(bot, st)
	if not (IsValid(bot) and st) then return false end
	local target = self:FindTarget(bot)
	if not IsValid(target) then return false end
	TFBotSource.Core:SetActionTarget(bot, st, "get_ammo", target, world_center(target))
	return true
end

return M

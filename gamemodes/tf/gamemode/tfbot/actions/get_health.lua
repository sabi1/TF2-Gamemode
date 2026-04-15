TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.GetHealth = TFBotSource.Actions.GetHealth or {}

local M = TFBotSource.Actions.GetHealth

local cv_near = CreateConVar("tf_bot_source_health_search_near_range", "1000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Near search range for health.")
local cv_far = CreateConVar("tf_bot_source_health_search_far_range", "2000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Far search range for health.")

local HEALTH_CLASSES = {
	"item_healthkit_small",
	"item_healthkit_medium",
	"item_healthkit_full",
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

local function isHealthUsable(bot, ent)
	if not (IsValid(bot) and IsValid(ent)) then return false end
	local cls = string.lower(tostring(ent.GetClass and ent:GetClass() or ""))
	if cls == "obj_dispenser" then
		return ent:Team() == bot:Team()
	end
	return true
end

function M:FindTarget(bot)
	local ratio = 1
	local maxHp = math.max(1, tonumber(bot.GetMaxHealth and bot:GetMaxHealth() or 0) or 1)
	ratio = math.Clamp((tonumber(bot:Health()) or 0) / maxHp, 0, 1)
	local searchRange = cv_far:GetFloat() + ratio * (cv_near:GetFloat() - cv_far:GetFloat())
	local maxDist2 = searchRange * searchRange
	local best, bestDist

	for _, cls in ipairs(HEALTH_CLASSES) do
		for _, ent in ipairs(ents.FindByClass(cls)) do
			if not isHealthUsable(bot, ent) then continue end
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
	TFBotSource.Core:SetActionTarget(bot, st, "get_health", target, world_center(target))
	return true
end

return M

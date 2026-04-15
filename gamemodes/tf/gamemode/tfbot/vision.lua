TFBotSource = TFBotSource or {}
TFBotSource.Vision = TFBotSource.Vision or {}

local M = TFBotSource.Vision

local cv_range = CreateConVar("tf_bot_source_vision_range", "3000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Max vision range for the source-shaped TFBot player brain.")
local cv_notice = CreateConVar("tf_bot_source_notice_delay", "0.2", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Recognition delay for the source-shaped TFBot player brain.")

local function get_potential_targets()
	local merged = {}
	local seen = {}

	for _, ent in ipairs(player.GetAll()) do
		if IsValid(ent) then
			merged[#merged + 1] = ent
			seen[ent] = true
		end
	end

	for _, ent in ipairs(ents.FindByClass("tf_bot_base_nextbot")) do
		if IsValid(ent) and ent.TFBot == true and not seen[ent] then
			merged[#merged + 1] = ent
			seen[ent] = true
		end
	end

	return merged
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

function M:CollectPotentiallyVisibleEntities(bot)
	local out = {}
	if not IsValid(bot) then return out end
	local maxDist2 = math.max(256, cv_range:GetFloat()) ^ 2
	local myPos = bot:GetPos()
	for _, ent in ipairs(get_potential_targets()) do
		if not IsValid(ent) or ent == bot then continue end
		if not (ent.Alive and ent:Alive()) then continue end
		if ent:Team() == bot:Team() then continue end
		if myPos:DistToSqr(ent:GetPos()) > maxDist2 then continue end
		out[#out + 1] = ent
	end
	return out
end

function M:Update(bot, st)
	if not (IsValid(bot) and st) then return end
	st.sourceVision = st.sourceVision or {}
	local data = st.sourceVision
	data.visible = {}
	data.primaryThreat = nil
	data.nextNoticeAt = tonumber(data.nextNoticeAt or 0)

	local visible = self:CollectPotentiallyVisibleEntities(bot)
	for _, ent in ipairs(visible) do
		local pos = world_center(ent)
		if not isvector(pos) then continue end
		local tr = util.TraceLine({
			start = bot:GetShootPos(),
			endpos = pos,
			filter = {bot, bot:GetActiveWeapon()},
			mask = MASK_SHOT,
		})
		if tr.Hit and tr.Entity ~= ent then continue end
		data.visible[#data.visible + 1] = ent
	end

	if CurTime() < data.nextNoticeAt then
		return
	end
	data.nextNoticeAt = CurTime() + math.max(0.05, cv_notice:GetFloat())

	local best, bestDist
	for _, ent in ipairs(data.visible) do
		local d2 = bot:GetPos():DistToSqr(ent:GetPos())
		if not bestDist or d2 < bestDist then
			bestDist = d2
			best = ent
		end
	end
	data.primaryThreat = best
	if IsValid(best) and st.vision then
		st.vision.currentThreat = best
	end
end

return M

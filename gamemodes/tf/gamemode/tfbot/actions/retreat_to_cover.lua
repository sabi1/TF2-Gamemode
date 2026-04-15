TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.RetreatToCover = TFBotSource.Actions.RetreatToCover or {}

local M = TFBotSource.Actions.RetreatToCover

local cv_cover_range = CreateConVar("tf_bot_source_retreat_cover_range", "1000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Search range for retreat cover.")
local cv_hide_min = CreateConVar("tf_bot_source_wait_in_cover_min_time", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Minimum wait in cover time.")
local cv_hide_max = CreateConVar("tf_bot_source_wait_in_cover_max_time", "2", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Maximum wait in cover time.")

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

function M:FindCover(bot, threat)
	if not IsValid(bot) then return nil end
	local threatPos = world_center(threat)
	if not isvector(threatPos) then return nil end

	local away = bot:GetPos() - threatPos
	away.z = 0
	if away:LengthSqr() <= 1 then
		away = bot:GetForward() * -1
	end
	away:Normalize()

	if IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot then
		local spot = bot.ControllerBot:FindSpot("random", {
			pos = bot:GetPos() + away * math.min(cv_cover_range:GetFloat(), 500),
			radius = cv_cover_range:GetFloat(),
			type = "hidden",
		})
		if isvector(spot) then
			return spot
		end
	end

	return bot:GetPos() + away * math.min(cv_cover_range:GetFloat(), 400)
end

function M:Update(bot, st)
	if not (IsValid(bot) and st) then return false end
	st.sourceRetreat = st.sourceRetreat or {}
	local mem = st.sourceRetreat
	local threat = st.vision and st.vision.currentThreat or nil
	if not IsValid(threat) then return false end

	if not isvector(mem.coverPos) or CurTime() >= tonumber(mem.coverUntil or 0) then
		mem.coverPos = self:FindCover(bot, threat)
		mem.coverUntil = CurTime() + math.Rand(cv_hide_min:GetFloat(), cv_hide_max:GetFloat())
	end
	if not isvector(mem.coverPos) then return false end

	TFBotSource.Core:SetActionTarget(bot, st, "retreat_to_cover", nil, mem.coverPos)
	return true
end

return M

TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.EngineerIdle = TFBotSource.Actions.EngineerIdle or {}

local M = TFBotSource.Actions.EngineerIdle

local cv_nest_refresh = CreateConVar("tf_bot_source_engineer_nest_refresh", "5.0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How often engineer idle reevaluates its nest spot.")
local cv_nest_hold_range = CreateConVar("tf_bot_source_engineer_hold_range", "150", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Distance where the engineer counts as settled into its nest.")

local function pick_nest_hint(bot)
	for _, cls in ipairs({"bot_hint_sentry", "bot_hint_engineer_nest", "info_target"}) do
		for _, ent in ipairs(ents.FindByClass(cls)) do
			if IsValid(ent) then
				local name = string.lower(tostring(ent.GetName and ent:GetName() or ""))
				if string.find(name, "engineer", 1, true) or string.find(name, "sentry", 1, true) or cls ~= "info_target" then
					return ent:GetPos()
				end
			end
		end
	end
	return nil
end

local function pick_fallback_nest(bot)
	if not (IsValid(bot) and IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot) then
		return bot:GetPos()
	end

	local spot = bot.ControllerBot:FindSpot("random", {
		pos = bot:GetPos(),
		radius = 1800,
		type = "sentry",
	})

	return isvector(spot) and spot or bot:GetPos()
end

function M:RefreshNest(bot, st)
	st.sourceEngineer = st.sourceEngineer or {}
	local eng = st.sourceEngineer
	eng.nestPos = pick_nest_hint(bot) or pick_fallback_nest(bot)
	eng.nestUntil = CurTime() + math.max(1, cv_nest_refresh:GetFloat())
	return eng.nestPos
end

function M:Update(bot, st)
	if not (IsValid(bot) and st) then return false end
	st.sourceEngineer = st.sourceEngineer or {}
	local eng = st.sourceEngineer
	local threat = st.vision and st.vision.currentThreat or nil

	if not isvector(eng.nestPos) or CurTime() >= tonumber(eng.nestUntil or 0) then
		self:RefreshNest(bot, st)
	end

	if IsValid(threat) and bot:GetPos():DistToSqr(eng.nestPos) <= (cv_nest_hold_range:GetFloat() * cv_nest_hold_range:GetFloat()) then
		return TFBotSource.Actions.Attack:Update(bot, st)
	end

	TFBotSource.Core:SetActionTarget(bot, st, "engineer_idle", nil, eng.nestPos)
	return true
end

return M

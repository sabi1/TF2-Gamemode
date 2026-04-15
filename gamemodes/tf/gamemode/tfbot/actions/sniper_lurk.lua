TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.SniperLurk = TFBotSource.Actions.SniperLurk or {}

local M = TFBotSource.Actions.SniperLurk

local cv_sniper_patience = CreateConVar("tf_bot_source_sniper_patience_duration", "10", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How long a sniper bot waits before picking a new spot.")
local cv_sniper_melee_range = CreateConVar("tf_bot_source_sniper_melee_range", "200", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Distance where sniper lurk turns into close attack.")
local cv_sniper_target_linger = CreateConVar("tf_bot_source_sniper_target_linger_duration", "2", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How long sniper bots keep attention on a recently seen threat.")

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

local function random_vantage(bot)
	if not (IsValid(bot) and IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot) then return nil end
	return bot.ControllerBot:FindSpot("random", {
		radius = 900,
		pos = bot:GetPos(),
		type = "sniper",
	})
end

function M:FindNewHome(bot, st)
	st.sourceSniper = st.sourceSniper or {}
	local sniper = st.sourceSniper
	sniper.homePos = random_vantage(bot) or bot:GetPos()
	sniper.homeUntil = CurTime() + math.max(1, cv_sniper_patience:GetFloat())
	return sniper.homePos
end

function M:Update(bot, st)
	if not (IsValid(bot) and st) then return false end
	st.sourceSniper = st.sourceSniper or {}
	local sniper = st.sourceSniper
	local threat = st.vision and st.vision.currentThreat or nil

	if not isvector(sniper.homePos) or CurTime() >= tonumber(sniper.homeUntil or 0) then
		self:FindNewHome(bot, st)
	end

	if IsValid(threat) then
		local pos = world_center(threat)
		if isvector(pos) then
			sniper.lastSeenPos = pos
			sniper.lastSeenUntil = CurTime() + math.max(0.2, cv_sniper_target_linger:GetFloat())
			if bot:GetPos():DistToSqr(pos) <= (cv_sniper_melee_range:GetFloat() * cv_sniper_melee_range:GetFloat()) then
				return TFBotSource.Actions.Attack:Update(bot, st)
			end
			TFBotSource.Core:SetActionTarget(bot, st, "sniper_lurk", threat, sniper.homePos)
			return true
		end
	end

	TFBotSource.Core:SetActionTarget(bot, st, "sniper_lurk", nil, sniper.homePos)
	return true
end

function M:ApplyPlayerCommand(bot, cmd, st)
	if not (IsValid(bot) and cmd and st) then return end
	local threat = st.vision and st.vision.currentThreat or nil
	if not IsValid(threat) then return end
	local ang = (threat:GetShootPos() - bot:GetShootPos()):Angle()
	cmd:SetViewAngles(ang)
	bot:SetEyeAngles(ang)
end

return M


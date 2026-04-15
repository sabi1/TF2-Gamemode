TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.SeekAndDestroy = TFBotSource.Actions.SeekAndDestroy or {}

local M = TFBotSource.Actions.SeekAndDestroy

local cv_seek_duration = CreateConVar("tf_bot_source_seek_duration", "6", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How long seek-and-destroy keeps a picked roam goal before refreshing it.")
local cv_seek_engage_range = CreateConVar("tf_bot_source_seek_engage_range", "1000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How close a visible enemy must be before seek-and-destroy turns into attack.")

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

local function pick_enemy_spawn_anchor(bot)
	local enemyTeam = TEAM_RED
	if bot.Team and bot:Team() == TEAM_RED then
		enemyTeam = TEAM_BLU
	end

	local spawnClasses = enemyTeam == TEAM_BLU and {"info_player_bluspawn", "info_player_teamspawn"} or {"info_player_teamspawn"}
	for _, cls in ipairs(spawnClasses) do
		for _, ent in ipairs(ents.FindByClass(cls)) do
			if IsValid(ent) then
				return ent:GetPos()
			end
		end
	end

	return nil
end

function M:RefreshGoal(bot, st)
	st.sourceSeek = st.sourceSeek or {}
	local seek = st.sourceSeek
	if isvector(seek.goalPos) and CurTime() < tonumber(seek.goalUntil or 0) then
		return seek.goalPos
	end

	local goal = pick_enemy_spawn_anchor(bot)
	if not isvector(goal) and IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot then
		goal = bot.ControllerBot:FindSpot("random", {
			radius = 1400,
			pos = bot:GetPos(),
			type = "exposed",
		})
	end
	if not isvector(goal) then
		goal = bot:GetPos()
	end

	seek.goalPos = goal
	seek.goalUntil = CurTime() + math.max(1, cv_seek_duration:GetFloat())
	return goal
end

function M:Update(bot, st)
	if not (IsValid(bot) and st) then return false end
	local threat = st.vision and st.vision.currentThreat or nil
	if IsValid(threat) then
		local pos = world_center(threat)
		if isvector(pos) and bot:GetPos():DistToSqr(pos) <= (cv_seek_engage_range:GetFloat() * cv_seek_engage_range:GetFloat()) then
			return TFBotSource.Actions.Attack:Update(bot, st)
		end
	end

	local goal = self:RefreshGoal(bot, st)
	TFBotSource.Core:SetActionTarget(bot, st, "seek_and_destroy", nil, goal)
	return true
end

return M


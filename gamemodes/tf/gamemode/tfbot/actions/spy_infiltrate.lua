TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.SpyInfiltrate = TFBotSource.Actions.SpyInfiltrate or {}

local M = TFBotSource.Actions.SpyInfiltrate

local cv_hide_refresh = CreateConVar("tf_bot_source_spy_hide_refresh", "3.0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How often spy infiltrate looks for a fresh hiding spot.")
local cv_hide_wait_min = CreateConVar("tf_bot_source_spy_hide_wait_min", "5.0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Minimum time a spy waits at an infiltrated hiding spot.")
local cv_hide_wait_max = CreateConVar("tf_bot_source_spy_hide_wait_max", "10.0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Maximum time a spy waits at an infiltrated hiding spot.")
local cv_backstab_range = CreateConVar("tf_bot_source_spy_backstab_seek_range", "325", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Range where spy infiltrate will convert into direct attack.")

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

local function is_enemy_object(ent, bot)
	if not IsValid(ent) or not IsValid(bot) then return false end
	local className = string.lower(tostring(ent.GetClass and ent:GetClass() or ""))
	if string.StartWith(className, "obj_") then
		return ent.Team == nil or ent:Team() ~= bot:Team()
	end
	return false
end

local function pick_enemy_anchor(bot)
	local teamNum = bot:Team()
	local spawnClass = (teamNum == TEAM_RED) and "info_player_bluspawn" or "info_player_teamspawn"
	for _, ent in ipairs(ents.FindByClass(spawnClass)) do
		if IsValid(ent) then
			return ent:GetPos()
		end
	end
	return nil
end

function M:FindHidingSpot(bot, st)
	st.sourceSpy = st.sourceSpy or {}
	local spy = st.sourceSpy
	local anchor = pick_enemy_anchor(bot) or bot:GetPos()
	local spot = nil

	if IsValid(bot.ControllerBot) and bot.ControllerBot.FindSpot then
		spot = bot.ControllerBot:FindSpot("random", {
			pos = anchor,
			radius = 2200,
			type = "hidden",
		})
	end

	spy.hidePos = isvector(spot) and spot or anchor
	spy.hideUntil = CurTime() + math.Rand(cv_hide_wait_min:GetFloat(), cv_hide_wait_max:GetFloat())
	spy.nextHideSearch = CurTime() + math.max(1, cv_hide_refresh:GetFloat())
	return spy.hidePos
end

function M:Update(bot, st, profile)
	if not (IsValid(bot) and st) then return false end
	st.sourceSpy = st.sourceSpy or {}
	local spy = st.sourceSpy
	local threat = st.vision and st.vision.currentThreat or nil

	if IsValid(threat) and is_enemy_object(threat, bot) then
		return TFBotSource.Actions.SpySap:Update(bot, st, threat)
	end

	if IsValid(threat) then
		local pos = world_center(threat)
		if isvector(pos) and bot:GetPos():DistToSqr(pos) <= (cv_backstab_range:GetFloat() * cv_backstab_range:GetFloat()) then
			return TFBotSource.Actions.SpyAttack:Update(bot, st, threat)
		end
	end

	local mode = tostring(profile and profile.actionName or "SpyInfiltrate")
	if mode == "SpyLeaveSpawnRoom" then
		if not isvector(spy.hidePos) or CurTime() >= tonumber(spy.nextHideSearch or 0) then
			self:FindHidingSpot(bot, st)
		end
		TFBotSource.Core:SetActionTarget(bot, st, "spy_leave_spawn_room", nil, spy.hidePos)
		return true
	end

	if not isvector(spy.hidePos) or CurTime() >= tonumber(spy.hideUntil or 0) then
		self:FindHidingSpot(bot, st)
	end

	TFBotSource.Core:SetActionTarget(bot, st, "spy_infiltrate", nil, spy.hidePos)
	return true
end

return M

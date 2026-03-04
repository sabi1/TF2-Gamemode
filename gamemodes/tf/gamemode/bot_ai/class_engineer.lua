TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.ClassEngineer = TFBotValveAI.ClassEngineer or {}

local M = TFBotValveAI.ClassEngineer

local function findMySentry(bot)
	for _, sentry in ipairs(ents.FindByClass("obj_sentrygun")) do
		if IsValid(sentry) and IsValid(sentry:GetBuilder()) and sentry:GetBuilder():EntIndex() == bot:EntIndex() then
			return sentry
		end
	end
	return nil
end

local function findMyTeleExit(bot)
	for _, tele in ipairs(ents.FindByClass("obj_teleporter")) do
		if IsValid(tele) and IsValid(tele:GetBuilder()) and tele:GetBuilder():EntIndex() == bot:EntIndex() then
			if tele.GetObjectMode and tele:GetObjectMode() == MODE_TELEPORTER_EXIT then
				return tele
			end
		end
	end
	return nil
end

local function canBuildNow(state, key, cd)
	state.class._buildCd = state.class._buildCd or {}
	local now = CurTime()
	local at = tonumber(state.class._buildCd[key] or 0)
	if now < at then return false end
	state.class._buildCd[key] = now + cd
	return true
end

local function tryBuildAtHint(bot, hint, kind)
	if not IsValid(bot) or not IsValid(hint) then return false end
	if not isfunction(ents.Create) then return false end
	local pos = hint:GetPos()
	local ang = hint:GetAngles()
	if kind == "sentry" then
		local sentry = ents.Create("obj_sentrygun")
		if not IsValid(sentry) then return false end
		sentry:SetPos(pos)
		sentry:SetAngles(Angle(0, ang.y, 0))
		sentry:Spawn()
		if sentry.SetBuilder then sentry:SetBuilder(bot) end
		if sentry.SetOwnerEntity then sentry:SetOwnerEntity(bot) end
		return true
	elseif kind == "tele_exit" then
		local tele = ents.Create("obj_teleporter")
		if not IsValid(tele) then return false end
		tele:SetPos(pos)
		tele:SetAngles(Angle(0, ang.y, 0))
		if tele.SetObjectMode then tele:SetObjectMode(MODE_TELEPORTER_EXIT) end
		tele:Spawn()
		if tele.SetBuilder then tele:SetBuilder(bot) end
		if tele.SetOwnerEntity then tele:SetOwnerEntity(bot) end
		return true
	end
	return false
end

function M:Update(bot, state)
	local cls = string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
	if cls ~= "engineer" and cls ~= "giantengineer" then return false end

	if state and state.objective and state.objective.mode == "hint_sentry_spot" and IsValid(state.objective.targetEnt) then
		return true
	end

	if state and IsValid(state.class.reservedTeleExitHint) and not IsValid(state.class.reservedSentryHint) then
		state.objective.mode = "hint_tele_exit_spot"
		state.objective.targetEnt = state.class.reservedTeleExitHint
		state.objective.targetPos = state.class.reservedTeleExitHint:GetPos()
		return true
	end

	local mySentry = findMySentry(bot)
	local myTele = findMyTeleExit(bot)

	-- Source-style MvM engineer sequencing:
	-- 1) secure sentry hint and build sentry
	-- 2) when sentry is safe, build tele exit
	-- 3) maintain/repair
	if IsValid(state.class.reservedSentryHint) and not IsValid(mySentry) then
		state.objective.mode = "engineer_build_sentry"
		state.objective.targetEnt = state.class.reservedSentryHint
		state.objective.targetPos = state.class.reservedSentryHint:GetPos()
		if bot:GetPos():DistToSqr(state.objective.targetPos) <= (80 * 80) and canBuildNow(state, "sentry", 2.0) then
			tryBuildAtHint(bot, state.class.reservedSentryHint, "sentry")
		end
		return true
	end

	if IsValid(mySentry) and IsValid(state.class.reservedTeleExitHint) and not IsValid(myTele) then
		state.objective.mode = "engineer_build_tele_exit"
		state.objective.targetEnt = state.class.reservedTeleExitHint
		state.objective.targetPos = state.class.reservedTeleExitHint:GetPos()
		if bot:GetPos():DistToSqr(state.objective.targetPos) <= (80 * 80) and canBuildNow(state, "tele", 2.0) then
			tryBuildAtHint(bot, state.class.reservedTeleExitHint, "tele_exit")
		end
		return true
	end

	if IsValid(myTele) then
		state.objective.mode = "engineer_maintain_tele"
		state.objective.targetEnt = myTele
		state.objective.targetPos = myTele:GetPos()
		return true
	end

	if IsValid(mySentry) then
		state.objective.mode = "engineer_maintain_sentry"
		state.objective.targetEnt = mySentry
		state.objective.targetPos = mySentry:GetPos()
		return true
	end

	if IsValid(bot.SentryGunHint) then
		state.objective.mode = "engineer_build_hint"
		state.objective.targetEnt = bot.SentryGunHint
		state.objective.targetPos = bot.SentryGunHint:GetPos()
		return true
	end

	local hint = ents.FindByClass("bot_hint_sentrygun")[1]
	if IsValid(hint) then
		bot.SentryGunHint = hint
		state.objective.mode = "engineer_seek_hint"
		state.objective.targetEnt = hint
		state.objective.targetPos = hint:GetPos()
		return true
	end

	return false
end

return M

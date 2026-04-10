TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.Hints = TFBotValveAI.Hints or {}

local M = TFBotValveAI.Hints

M.HINT_SNIPER_SPOT = 0
M.HINT_SENTRY_SPOT = 1

local function getProp(ent, key, fallback)
	if not IsValid(ent) then return fallback end
	local props = ent.Properties
	if istable(props) then
		local v = props[string.lower(key)]
		if v ~= nil then return v end
	end
	return fallback
end

local function boolProp(ent, key, fallback)
	local v = getProp(ent, key, fallback)
	if isbool(v) then return v end
	if isnumber(v) then return v ~= 0 end
	if isstring(v) then
		v = string.lower(v)
		return v == "1" or v == "true" or v == "yes"
	end
	return fallback
end

local function numProp(ent, key, fallback)
	local v = getProp(ent, key, fallback)
	return tonumber(v) or fallback
end

local function isHintEnabled(ent)
	if not IsValid(ent) then return false end
	if ent.IsEnabled then
		return ent:IsEnabled()
	end
	return not boolProp(ent, "startdisabled", false)
end

local function inTeam(ent, bot)
	if ent.IsForTeam then
		return ent:IsForTeam(bot:Team())
	end
	local hintTeam = numProp(ent, "team", 0)
	if hintTeam <= 0 then return true end
	return bot:Team() == hintTeam
end

local function isInsideBrush(ent, pos)
	if not IsValid(ent) or not isvector(pos) then return false end
	local mins, maxs = ent:WorldSpaceAABB()
	return pos.x >= mins.x and pos.x <= maxs.x and
		pos.y >= mins.y and pos.y <= maxs.y and
		pos.z >= mins.z and pos.z <= maxs.z
end

local function cls(bot)
	return string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
end

function M:GetActiveFuncHintsForBot(bot)
	if not IsValid(bot) then return {} end
	local out = {}
	for _, hint in ipairs(ents.FindByClass("func_tfbot_hint")) do
		if not IsValid(hint) then continue end
		if not isHintEnabled(hint) then continue end
		if not inTeam(hint, bot) then continue end
		if not isInsideBrush(hint, bot:GetPos()) then continue end
		table.insert(out, hint)
	end
	return out
end

function M:GetNearestHint(classname, bot, maxRange)
	if not IsValid(bot) then return nil end
	local best, bestDist
	local maxSqr = (maxRange or 6000) ^ 2
	for _, hint in ipairs(ents.FindByClass(classname)) do
		if not IsValid(hint) then continue end
		if not isHintEnabled(hint) then continue end
		if not inTeam(hint, bot) then continue end
		local dist = bot:GetPos():DistToSqr(hint:GetPos())
		if dist > maxSqr then continue end
		if not bestDist or dist < bestDist then
			bestDist = dist
			best = hint
		end
	end
	return best
end

function M:IsSentryHintAvailable(hint, bot)
	if not IsValid(hint) or not IsValid(bot) then return false end
	if not isHintEnabled(hint) then return false end
	if not inTeam(hint, bot) then return false end

	-- Mirror the C++ rule loosely: available if no effective owner and not in use.
	local owner = hint._tfbotOwner
	if hint.GetPlayerOwner then
		owner = hint:GetPlayerOwner()
	end
	if IsValid(owner) and owner ~= bot then
		local ownerClass = string.lower(tostring((owner.GetPlayerClass and owner:GetPlayerClass()) or owner.playerclass or ""))
		if ownerClass == "engineer" or ownerClass == "giantengineer" then
			return false
		end
	end
	local inUse = hint.IsInUse and hint:IsInUse() or (hint._tfbotUseCount or 0) > 0
	return not inUse
end

function M:ReserveSentryHint(hint, bot)
	if not IsValid(hint) or not IsValid(bot) then return end
	if hint.SetPlayerOwner then
		hint:SetPlayerOwner(bot)
	else
		hint._tfbotOwner = bot
	end
	if hint.IncrementUseCount then
		hint:IncrementUseCount()
	else
		hint._tfbotUseCount = (hint._tfbotUseCount or 0) + 1
	end
end

function M:ReleaseSentryHint(hint, bot)
	if not IsValid(hint) then return end
	if hint.GetPlayerOwner and hint:SetPlayerOwner and hint:GetPlayerOwner() == bot then
		hint:SetPlayerOwner(nil)
	elseif hint._tfbotOwner == bot then
		hint._tfbotOwner = nil
	end
	if hint.DecrementUseCount then
		hint:DecrementUseCount()
	else
		hint._tfbotUseCount = math.max((hint._tfbotUseCount or 1) - 1, 0)
	end
end

function M:SelectEngineerSentryHint(bot)
	if not IsValid(bot) then return nil end
	local best, bestDist
	for _, hint in ipairs(ents.FindByClass("bot_hint_sentrygun")) do
		if not self:IsSentryHintAvailable(hint, bot) then continue end
		local dist = bot:GetPos():DistToSqr(hint:GetPos())
		if not bestDist or dist < bestDist then
			bestDist = dist
			best = hint
		end
	end
	return best
end

local function sameName(a, b)
	if not IsValid(a) or not IsValid(b) then return false end
	local an = tostring((a.GetName and a:GetName()) or "")
	local bn = tostring((b.GetName and b:GetName()) or "")
	if an == "" or bn == "" then return false end
	return an == bn
end

function M:SelectEngineerTeleExitHint(bot, sentryHint)
	local best, bestDist
	for _, hint in ipairs(ents.FindByClass("bot_hint_teleporter_exit")) do
		if not IsValid(hint) then continue end
		if not isHintEnabled(hint) then continue end
		if not inTeam(hint, bot) then continue end
		if IsValid(sentryHint) and not sameName(hint, sentryHint) then
			-- Mirror engineer nest grouping by entity name when available.
			continue
		end
		local dist = bot:GetPos():DistToSqr(hint:GetPos())
		if not bestDist or dist < bestDist then
			bestDist = dist
			best = hint
		end
	end
	return best
end

function M:Apply(bot, state)
	if not IsValid(bot) or not state then return end
	state.hints = state.hints or {}
	state.hints.active = self:GetActiveFuncHintsForBot(bot)
	state.hints.wantSentrySpot = false
	state.hints.wantSniperSpot = false

	for _, hint in ipairs(state.hints.active) do
		local h = numProp(hint, "hint", -1)
		if h == self.HINT_SENTRY_SPOT then
			state.hints.wantSentrySpot = true
		elseif h == self.HINT_SNIPER_SPOT then
			state.hints.wantSniperSpot = true
		end
	end

	local class = cls(bot)
	if (class == "sniper" or class == "giantsniper") and state.hints.wantSniperSpot then
		local sniperSpot = self:GetNearestHint("bot_hint_sniper_spot", bot, 4000)
		if IsValid(sniperSpot) then
			state.class.sniperHome = sniperSpot:GetPos()
			state.objective.mode = "hint_sniper_spot"
			state.objective.targetEnt = sniperSpot
			state.objective.targetPos = sniperSpot:GetPos()
			bot.routeType = "safest"
		end
	end

	if (class == "engineer" or class == "giantengineer") and state.hints.wantSentrySpot then
		local sentryHint = self:SelectEngineerSentryHint(bot)
		if IsValid(sentryHint) then
			if state.class.reservedSentryHint ~= sentryHint then
				if IsValid(state.class.reservedSentryHint) then
					self:ReleaseSentryHint(state.class.reservedSentryHint, bot)
				end
				self:ReserveSentryHint(sentryHint, bot)
				state.class.reservedSentryHint = sentryHint
			end
			state.objective.mode = "hint_sentry_spot"
			state.objective.targetEnt = sentryHint
			state.objective.targetPos = sentryHint:GetPos()

			local teleHint = self:SelectEngineerTeleExitHint(bot, sentryHint)
			if IsValid(teleHint) then
				state.class.reservedTeleExitHint = teleHint
			end
		end
	end
end

hook.Add("EntityRemoved", "TFBotValveAI_Hints_ReleaseOwners", function(ent)
	if not IsValid(ent) then return end
	local isManagedPlayerBot = ent:IsPlayer() and ent:IsBot() and ent.TFBot == true
	local isManagedNextBotBase = ent.IsTFBotValveBase == true
	if not isManagedPlayerBot and not isManagedNextBotBase then return end
	local st = ent._tfbot_ai
	if not st or not st.class then return end
	if IsValid(st.class.reservedSentryHint) then
		TFBotValveAI.Hints:ReleaseSentryHint(st.class.reservedSentryHint, ent)
		st.class.reservedSentryHint = nil
	end
	st.class.reservedTeleExitHint = nil
end)

return M

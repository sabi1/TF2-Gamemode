TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.PayloadGuard = TFBotSource.Actions.PayloadGuard or {}

local M = TFBotSource.Actions.PayloadGuard

local function get_objective_pos(ent)
	if not IsValid(ent) then return nil end
	local pos = ent.GetPos and ent:GetPos() or nil
	if not isvector(pos) then return nil end
	if navmesh and navmesh.GetNearestNavArea then
		local area = navmesh.GetNearestNavArea(pos)
		if IsValid(area) then
			return area:GetCenter()
		end
	end
	return pos
end

local function get_payload_watcher()
	if GAMEMODE and GAMEMODE.GetActivePayloadWatcher then
		local watcher = GAMEMODE:GetActivePayloadWatcher()
		if IsValid(watcher) then
			return watcher
		end
	end
	for _, watcher in ipairs(ents.FindByClass("team_train_watcher")) do
		if IsValid(watcher) then
			return watcher
		end
	end
	return nil
end

local function get_payload_state(watcher)
	if not IsValid(watcher) then return nil end
	if watcher.GetState then
		local ok, state = pcall(watcher.GetState, watcher)
		if ok and istable(state) then
			return state
		end
	end
	return watcher.PayloadState
end

local function get_payload_team(state, key, fallback)
	if not istable(state) then return fallback end
	local teamNum = tonumber(state[key] or fallback)
	if teamNum == TEAM_RED or teamNum == TEAM_BLU then
		return teamNum
	end
	return fallback
end

local function get_payload_cart(watcher)
	if not IsValid(watcher) then return nil end
	if IsValid(watcher.Train) then
		return watcher.Train
	end
	if watcher.GetTrainEntity then
		local ok, cart = pcall(watcher.GetTrainEntity, watcher)
		if ok and IsValid(cart) then
			return cart
		end
	end
	return nil
end

local function get_payload_cart_position(watcher)
	local cart = get_payload_cart(watcher)
	if IsValid(cart) then
		return get_objective_pos(cart)
	end
	if IsValid(watcher) and watcher.GetCartPosition then
		local ok, pos = pcall(watcher.GetCartPosition, watcher)
		if ok and isvector(pos) then
			return get_objective_pos(watcher) or pos
		end
	end
	return get_objective_pos(watcher)
end

local function get_payload_defend_position(watcher)
	if not IsValid(watcher) then return nil end
	if watcher.GetDefendPosition then
		local ok, pos = pcall(watcher.GetDefendPosition, watcher)
		if ok and isvector(pos) then
			if navmesh and navmesh.GetNearestNavArea then
				local area = navmesh.GetNearestNavArea(pos)
				if IsValid(area) then
					return area:GetCenter()
				end
			end
			return pos
		end
	end
	return get_payload_cart_position(watcher)
end

function M:Update(bot, st, profile)
	if not (IsValid(bot) and st) then return false end

	local watcher = get_payload_watcher()
	if not IsValid(watcher) then
		return TFBotSource.Actions.SeekAndDestroy:Update(bot, st, profile)
	end

	local state = get_payload_state(watcher)
	if istable(state) and state.goalReached then
		return TFBotSource.Actions.SeekAndDestroy:Update(bot, st, profile)
	end

	local defendTeam = get_payload_team(state, "defendTeam", TEAM_RED)
	if bot:Team() ~= defendTeam then
		return false
	end

	local cart = get_payload_cart(watcher)
	local cartPos = get_payload_cart_position(watcher)
	if not isvector(cartPos) then
		return false
	end

	local contested = false
	if istable(state) then
		local cappers = tonumber(state.cappers) or 0
		contested = cappers > 0 or state.blocked == true or tonumber(state.trainState or -1) == 1
	end

	TFBotSource.Core:SetActionTarget(
		bot,
		st,
		contested and "payload_block" or "payload_guard",
		cart,
		contested and cartPos or (get_payload_defend_position(watcher) or cartPos)
	)
	return true
end

return M

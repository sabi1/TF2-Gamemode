TFBotSource = TFBotSource or {}
TFBotSource.Actions = TFBotSource.Actions or {}
TFBotSource.Actions.PayloadPush = TFBotSource.Actions.PayloadPush or {}

local M = TFBotSource.Actions.PayloadPush

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

	local attackTeam = get_payload_team(state, "attackTeam", TEAM_BLU)
	if bot:Team() ~= attackTeam then
		return false
	end

	local cart = get_payload_cart(watcher)
	local cartPos = get_payload_cart_position(watcher)
	if not isvector(cartPos) then
		return false
	end

	local pushPos = cartPos
	if IsValid(cart) then
		local forward = cart:GetForward()
		if isvector(forward) and forward:LengthSqr() > 0 then
			pushPos = cartPos - forward:GetNormalized() * 60
		end
	end

	TFBotSource.Core:SetActionTarget(bot, st, "payload_push", cart, pushPos)
	return true
end

return M

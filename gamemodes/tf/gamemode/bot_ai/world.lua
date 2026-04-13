TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.World = TFBotValveAI.World or {}

local M = TFBotValveAI.World

local state = {
	players = {
		nextRefreshAt = 0,
		all = {},
		alive = {},
		aliveByTeam = {},
	},
	classes = {},
}

local function nowTime()
	return CurTime and CurTime() or 0
end

local function refreshPlayers(now)
	local all = player.GetAll()
	local alive = {}
	local aliveByTeam = {}

	for _, ply in ipairs(all) do
		if IsValid(ply) and ply:Alive() then
			alive[#alive + 1] = ply
			local teamNum = tonumber(ply:Team() or TEAM_UNASSIGNED) or TEAM_UNASSIGNED
			local bucket = aliveByTeam[teamNum]
			if not bucket then
				bucket = {}
				aliveByTeam[teamNum] = bucket
			end
			bucket[#bucket + 1] = ply
		end
	end

	state.players.all = all
	state.players.alive = alive
	state.players.aliveByTeam = aliveByTeam
	state.players.nextRefreshAt = now + 0.10
end

function M:GetPlayers()
	local now = nowTime()
	if now >= state.players.nextRefreshAt then
		refreshPlayers(now)
	end
	return state.players.all
end

function M:GetAlivePlayers()
	local now = nowTime()
	if now >= state.players.nextRefreshAt then
		refreshPlayers(now)
	end
	return state.players.alive
end

function M:GetAlivePlayersForTeam(teamNum)
	local now = nowTime()
	if now >= state.players.nextRefreshAt then
		refreshPlayers(now)
	end
	return state.players.aliveByTeam[teamNum] or {}
end

function M:GetEntitiesByClass(classname, ttl)
	local now = nowTime()
	local entry = state.classes[classname]
	if not entry then
		entry = {
			nextRefreshAt = 0,
			list = {},
		}
		state.classes[classname] = entry
	end

	if now >= entry.nextRefreshAt then
		entry.list = ents.FindByClass(classname)
		entry.nextRefreshAt = now + math.max(tonumber(ttl) or 0.15, 0.01)
	end

	return entry.list
end

function M:GetFirstEntityByClass(classname, ttl)
	for _, ent in ipairs(self:GetEntitiesByClass(classname, ttl)) do
		if IsValid(ent) then
			return ent
		end
	end
	return nil
end

function M:InvalidateClass(classname)
	if state.classes[classname] then
		state.classes[classname].nextRefreshAt = 0
	end
end

return M

TFDebugBridgeServer = TFDebugBridgeServer or {}

local M = TFDebugBridgeServer

local ROOT_DIR = "tf_debug"
local STATE_FILE = ROOT_DIR .. "/server_state.json"
local EVENTS_FILE = ROOT_DIR .. "/server_events.jsonl"
local COMMANDS_FILE = ROOT_DIR .. "/commands.txt"
local COMMANDS_HISTORY_FILE = ROOT_DIR .. "/commands_history.log"

file.CreateDir(ROOT_DIR)

M.cv_enable = CreateConVar("tf_debug_bridge_server", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable server debug bridge file output.")
M.cv_exec = CreateConVar("tf_debug_bridge_server_exec", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Allow command queue execution from data/tf_debug/commands.txt.")
M.cv_poll = CreateConVar("tf_debug_bridge_server_poll", "0.25", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Server debug bridge polling interval (seconds).")
M.cv_unsafe = CreateConVar("tf_debug_bridge_server_unsafe", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Allow raw game.ConsoleCommand from queue (unsafe).")
M.cv_max_events = CreateConVar("tf_debug_bridge_server_event_limit", "4000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Maximum number of server debug events to keep.")

local function isEnabled()
	return M.cv_enable:GetBool()
end

local function isExecEnabled()
	return isEnabled() and M.cv_exec:GetBool()
end

local function nowStamp()
	return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function vecToTable(v)
	if not isvector(v) then return nil end
	return {
		x = math.Round(v.x, 2),
		y = math.Round(v.y, 2),
		z = math.Round(v.z, 2),
	}
end

local function trimEventsIfNeeded()
	local raw = file.Read(EVENTS_FILE, "DATA")
	if not isstring(raw) or raw == "" then return end

	local lines = string.Explode("\n", raw, false)
	local nonEmpty = {}
	for _, line in ipairs(lines) do
		if isstring(line) and line ~= "" then
			nonEmpty[#nonEmpty + 1] = line
		end
	end

	local limit = math.Clamp(M.cv_max_events:GetInt(), 200, 50000)
	if #nonEmpty <= limit then return end

	local startIdx = (#nonEmpty - limit) + 1
	local out = {}
	for i = startIdx, #nonEmpty do
		out[#out + 1] = nonEmpty[i]
	end
	file.Write(EVENTS_FILE, table.concat(out, "\n") .. "\n")
end

local function emit(eventName, payload)
	if not isEnabled() then return end
	local evt = {
		ts = os.time(),
		stamp = nowStamp(),
		event = eventName or "unknown",
		map = game.GetMap() or "unknown",
	}
	if istable(payload) then
		for k, v in pairs(payload) do
			evt[k] = v
		end
	end
	local json = util.TableToJSON(evt, false)
	if not isstring(json) then return end
	file.Append(EVENTS_FILE, json .. "\n")
	trimEventsIfNeeded()
end

local function collectBombState()
	local bomb = nil
	for _, ent in ipairs(ents.FindByClass("item_teamflag_mvm")) do
		if IsValid(ent) then
			bomb = ent
			break
		end
	end
	if not IsValid(bomb) then return nil end

	local carrier = bomb.Carrier
	return {
		valid = true,
		pos = vecToTable(bomb:GetPos()),
		state = tonumber(bomb.State or -1) or -1,
		upgrade = tonumber(bomb.BombUpgradeLevel or bomb:GetNWInt("MVM_BombUpgradeLevel", 0)) or 0,
		carrier_entindex = IsValid(carrier) and carrier:EntIndex() or -1,
		carrier_name = IsValid(carrier) and carrier:Nick() or "",
	}
end

local function collectState()
	local players = player.GetAll()
	local bots = player.GetBots()
	local humans = {}
	for _, p in ipairs(players) do
		if IsValid(p) and not p:IsBot() then
			humans[#humans + 1] = p
		end
	end

	local state = {
		ts = os.time(),
		stamp = nowStamp(),
		map = game.GetMap() or "unknown",
		players_total = #players,
		players_human = #humans,
		players_bot = #bots,
		tf_bot_valve_ai_enable = GetConVar("tf_bot_valve_ai_enable") and GetConVar("tf_bot_valve_ai_enable"):GetBool() or false,
		tf_bot_valve_ai_backend = GetConVar("tf_bot_valve_ai_backend") and GetConVar("tf_bot_valve_ai_backend"):GetString() or "unknown",
		tf_bot_valve_ai_debug = GetConVar("tf_bot_valve_ai_debug") and GetConVar("tf_bot_valve_ai_debug"):GetBool() or false,
		mvm = nil,
		bomb = collectBombState(),
	}

	if TF_MVM and TF_MVM.Runtime then
		local rt = TF_MVM.Runtime
		state.mvm = {
			enabled = rt.Enabled == true,
			active = rt.Active == true,
			setup = rt.Setup == true,
			wave_active = rt.WaveActive == true,
			wave_index = tonumber(rt.WaveIndex or 0) or 0,
		}
	end

	return state
end

local function writeState(force)
	if (not force) and (not isEnabled()) then return end
	local state = collectState()
	local json = util.TableToJSON(state, true)
	if not isstring(json) then return end
	file.Write(STATE_FILE, json)
end

local function splitArgs(line)
	local out = {}
	local i = 1
	local n = #line
	while i <= n do
		while i <= n and string.sub(line, i, i):match("%s") do
			i = i + 1
		end
		if i > n then break end

		local c = string.sub(line, i, i)
		if c == "\"" then
			local j = i + 1
			while j <= n and string.sub(line, j, j) ~= "\"" do
				j = j + 1
			end
			out[#out + 1] = string.sub(line, i + 1, j - 1)
			i = j + 1
		else
			local j = i
			while j <= n and (not string.sub(line, j, j):match("%s")) do
				j = j + 1
			end
			out[#out + 1] = string.sub(line, i, j - 1)
			i = j
		end
	end
	return out
end

local ALLOWED_PREFIXES = {
	"tf_bot_",
	"tf_mvm_",
	"bot_",
	"nb_",
	"sv_",
	"developer",
	"status",
	"changelevel",
	"map",
	"mp_",
}

local function isAllowedCommand(cmd)
	if not isstring(cmd) or cmd == "" then return false end
	local lower = string.lower(cmd)
	for _, prefix in ipairs(ALLOWED_PREFIXES) do
		if string.StartWith(lower, prefix) then
			return true
		end
	end
	return false
end

local function runQueueCommand(raw)
	local line = string.Trim(tostring(raw or ""))
	if line == "" then return end
	if string.StartWith(line, "#") then return end

	file.Append(COMMANDS_HISTORY_FILE, string.format("%s | %s\n", nowStamp(), line))

	if line == "dump_state" then
		writeState(true)
		emit("cmd_ok", { cmd = line, note = "state_dumped" })
		return
	end

	if line == "clear_events" then
		file.Write(EVENTS_FILE, "")
		emit("cmd_ok", { cmd = line, note = "events_cleared" })
		return
	end

	if not isExecEnabled() then
		emit("cmd_reject", { cmd = line, reason = "exec_disabled" })
		return
	end

	if M.cv_unsafe:GetBool() then
		game.ConsoleCommand(line .. "\n")
		emit("cmd_ok", { cmd = line, mode = "unsafe_consolecommand" })
		return
	end

	local args = splitArgs(line)
	local cmd = args[1]
	if not isAllowedCommand(cmd) then
		emit("cmd_reject", { cmd = line, reason = "not_allowed" })
		return
	end

	table.remove(args, 1)
	local unpackFn = unpack or table.unpack
	RunConsoleCommand(cmd, unpackFn(args))
	emit("cmd_ok", { cmd = line, mode = "runconsolecommand" })
end

local function processQueue()
	if not isEnabled() then return end
	local raw = file.Read(COMMANDS_FILE, "DATA")
	if not isstring(raw) or raw == "" then return end

	file.Write(COMMANDS_FILE, "")
	local lines = string.Explode("\n", raw, false)
	for _, line in ipairs(lines) do
		runQueueCommand(line)
	end
end

function M.DumpNow()
	writeState(true)
	emit("manual_dump", {})
end

local function tick()
	if not isEnabled() then return end
	writeState(false)
	processQueue()
end

concommand.Add("tf_debug_bridge_server_dump", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end
	M.DumpNow()
end)

concommand.Add("tf_debug_bridge_server_run", function(ply, _, args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	local line = string.Trim(table.concat(args or {}, " "))
	if line == "" then return end
	runQueueCommand(line)
end)

timer.Create("TFDebugBridgeServer_Tick", math.max(M.cv_poll:GetFloat(), 0.05), 0, tick)

emit("bridge_init", { enabled = isEnabled() })

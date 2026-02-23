TFDebugBridge = TFDebugBridge or {}

local STATE_FILE = "tf_debug_state.json"
local EVENTS_FILE = "tf_debug_events.jsonl"

CreateClientConVar("tf_debug_bridge", "1", true, false, "Enable TF2-Gamemode debug bridge JSON output.")
CreateClientConVar("tf_debug_bridge_verbose", "0", true, false, "Enable verbose TF2-Gamemode debug bridge events.")
CreateClientConVar("tf_debug_bridge_limit", "2000", true, false, "Maximum TF2-Gamemode debug events to keep.")

local function bridgeEnabled()
	local c = GetConVar("tf_debug_bridge")
	return c and c:GetBool()
end

local function verboseEnabled()
	local c = GetConVar("tf_debug_bridge_verbose")
	return c and c:GetBool()
end

local function getEventLimit()
	local c = GetConVar("tf_debug_bridge_limit")
	return math.Clamp((c and c:GetInt()) or 2000, 100, 20000)
end

local function compactEventFileIfNeeded()
	local raw = file.Read(EVENTS_FILE, "DATA")
	if not isstring(raw) or raw == "" then return end

	local lines = string.Explode("\n", raw, false)
	local nonEmpty = {}
	for _, line in ipairs(lines) do
		if isstring(line) and line ~= "" then
			nonEmpty[#nonEmpty + 1] = line
		end
	end

	local limit = getEventLimit()
	if #nonEmpty <= limit then return end

	local trimmed = {}
	local startIdx = (#nonEmpty - limit) + 1
	for i = startIdx, #nonEmpty do
		trimmed[#trimmed + 1] = nonEmpty[i]
	end

	file.Write(EVENTS_FILE, table.concat(trimmed, "\n") .. "\n")
end

function TFDebugBridge.Emit(eventName, payload, force)
	if (not force) and (not bridgeEnabled()) then return end

	local evt = {
		ts = os.time(),
		event = eventName or "unknown",
		map = game.GetMap() or "unknown",
	}
	if istable(payload) then
		for k, v in pairs(payload) do
			evt[k] = v
		end
	end

	local encoded = util.TableToJSON(evt, false)
	if not isstring(encoded) then return end

	file.Append(EVENTS_FILE, encoded .. "\n")
	compactEventFileIfNeeded()
end

function TFDebugBridge.WriteState(state, force)
	if (not force) and (not bridgeEnabled()) then return end
	if not istable(state) then return end

	local out = table.Copy(state)
	out.ts = os.time()
	out.map = out.map or game.GetMap() or "unknown"

	local encoded = util.TableToJSON(out, true)
	if not isstring(encoded) then return end
	file.Write(STATE_FILE, encoded)
end

TFDebugBridge.LastBackpackState = TFDebugBridge.LastBackpackState or nil

function TFDebugBridge.SetBackpackState(state)
	if not istable(state) then return end
	TFDebugBridge.LastBackpackState = table.Copy(state)
	TFDebugBridge.WriteState(state, false)
end

concommand.Add("tf_debug_dump_backpack", function()
	local state = TFDebugBridge.LastBackpackState or {
		error = "no_backpack_snapshot",
	}
	TFDebugBridge.WriteState(state, true)
	TFDebugBridge.Emit("debug_dump_backpack", state, true)
	chat.AddText(Color(120, 220, 140), "[TF2-Gamemode] Wrote debug snapshot to data/" .. STATE_FILE)
end)

concommand.Add("tf_debug_clear_events", function()
	file.Write(EVENTS_FILE, "")
	chat.AddText(Color(120, 220, 140), "[TF2-Gamemode] Cleared debug events at data/" .. EVENTS_FILE)
end)

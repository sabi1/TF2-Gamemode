TF_PARITY = TF_PARITY or {}

CreateConVar(
	"tf_parity_debug_objectives",
	"0",
	{ FCVAR_ARCHIVE, FCVAR_REPLICATED },
	"Enable objective parity debug data collection and overlays."
)

local function canUseAdminDebug(ply)
	if not IsValid(ply) then
		return true
	end
	return ply:IsAdmin() or ply:IsListenServerHost()
end

local function round2(v)
	return math.Round(tonumber(v) or 0, 2)
end

local function collectServerObjectiveSnapshot()
	local out = {
		ts = os.time(),
		map = game.GetMap() or "unknown",
		hudMode = TF_GetHudGameMode and TF_GetHudGameMode(true) or "unknown",
		controlPoints = {},
		koth = {
			activeTeam = 0,
			red = nil,
			blu = nil,
		},
	}

	for _, capArea in ipairs(ents.FindByClass("trigger_capture_area")) do
		if not IsValid(capArea) or capArea.IsPayloadMode and capArea:IsPayloadMode() then
			continue
		end

		local state = capArea.GetHudCapState and capArea:GetHudCapState() or nil
		if state then
			out.controlPoints[#out.controlPoints + 1] = {
				id = tonumber(state.id) or -1,
				ownerTeam = tonumber(state.ownerTeam) or 0,
				cappingTeam = tonumber(state.cappingTeam) or 0,
				cappers = tonumber(state.cappers) or 0,
				enemies = tonumber(state.enemies) or 0,
				requiredPlayers = tonumber(state.requiredPlayers) or 1,
				blocked = state.blocked and true or false,
				locked = state.locked and true or false,
				progress = round2(state.progress),
			}
		end
	end
	table.sort(out.controlPoints, function(a, b) return (a.id or 0) < (b.id or 0) end)

	local koth = ents.FindByClass("tf_logic_koth")[1]
	if IsValid(koth) then
		out.koth.activeTeam = tonumber(koth.ActiveTeam) or 0
		local redTimer = koth.RedTimer
		local bluTimer = koth.BlueTimer
		if IsValid(redTimer) then
			out.koth.red = {
				time = round2(redTimer.GetTime and redTimer:GetTime() or 0),
				paused = redTimer.TimerPaused ~= nil,
			}
		end
		if IsValid(bluTimer) then
			out.koth.blu = {
				time = round2(bluTimer.GetTime and bluTimer:GetTime() or 0),
				paused = bluTimer.TimerPaused ~= nil,
			}
		end
	end

	return out
end

function TF_PARITY.CollectObjectiveSnapshot()
	if SERVER then
		return collectServerObjectiveSnapshot()
	end

	local out = {
		ts = os.time(),
		map = game.GetMap() or "unknown",
		hudMode = TF_GetHudGameMode and TF_GetHudGameMode(true) or "unknown",
		controlPointLayout = GAMEMODE.ControlPointLayout or {},
		controlPointState = GAMEMODE.ControlPointCapState or {},
	}
	return out
end

if SERVER then
	concommand.Add("tf_parity_dump_objectives", function(ply)
		if not canUseAdminDebug(ply) then return end

		local state = collectServerObjectiveSnapshot()
		print("[TF2-Gamemode][PARITY] Objective snapshot map=" .. tostring(state.map) .. " mode=" .. tostring(state.hudMode))
		print(util.TableToJSON(state, true) or "{}")

		if TFDebugBridgeServer and TFDebugBridgeServer.DumpNow then
			TFDebugBridgeServer.DumpNow()
		end
	end)
else
	concommand.Add("tf_parity_dump_hud_state", function()
		local state = TF_PARITY.CollectObjectiveSnapshot()
		if TFDebugBridge and TFDebugBridge.WriteState then
			TFDebugBridge.WriteState(state, true)
			TFDebugBridge.Emit("parity_dump_hud_state", state, true)
		end
		chat.AddText(Color(120, 220, 140), "[TF2-Gamemode] Parity HUD state dumped to debug bridge.")
	end)
end

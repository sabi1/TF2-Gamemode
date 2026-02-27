local TRAIN_STATE_STOPPED = 0
local PENDING_SNAPSHOT = nil

local function BuildDefaultPayloadState()
	return {
		watcher = 0,
		active = false,
		attackTeam = TEAM_BLU or 3,
		cappers = 0,
		blocked = false,
		progress = 0,
		checkpointProgress = {},
		recedeRemaining = 0,
		canRecede = true,
		trainState = TRAIN_STATE_STOPPED,
		inOvertime = false,
		goal = false,
	}
end

local function GetGamemodeTable()
	return rawget(_G, "GAMEMODE") or rawget(_G, "GM")
end

local function EnsurePayloadClientState()
	local gm = GetGamemodeTable()
	if not gm then return nil end

	gm.PayloadState = gm.PayloadState or BuildDefaultPayloadState()
	if gm.PayloadHUDActive == nil then
		gm.PayloadHUDActive = false
	end

	return gm
end

local function ReadPayloadSnapshot()
	local snapshot = BuildDefaultPayloadState()

	snapshot.watcher = net.ReadUInt(16)
	snapshot.active = net.ReadBool()
	snapshot.attackTeam = net.ReadInt(8)
	snapshot.cappers = net.ReadInt(8)
	snapshot.blocked = net.ReadBool()
	snapshot.progress = math.Clamp(net.ReadFloat() or 0, 0, 1)

	local cpCount = net.ReadUInt(4)
	snapshot.checkpointProgress = {}
	for i = 1, cpCount do
		snapshot.checkpointProgress[i] = math.Clamp(net.ReadFloat() or 0, 0, 1)
	end

	snapshot.recedeRemaining = math.max(net.ReadFloat() or 0, 0)
	snapshot.canRecede = net.ReadBool()
	snapshot.trainState = net.ReadUInt(3)
	snapshot.inOvertime = net.ReadBool()
	snapshot.goal = net.ReadBool()

	return snapshot
end

local function ApplyPayloadSnapshot(snapshot)
	local gm = EnsurePayloadClientState()
	if not gm then
		PENDING_SNAPSHOT = snapshot
		return
	end

	gm.PayloadState = snapshot
	gm.PayloadHUDActive = snapshot.active and true or false
	gm.PayloadStateLastUpdate = CurTime()
end

EnsurePayloadClientState()

hook.Add("Think", "TF_PayloadClientBootstrap", function()
	if not PENDING_SNAPSHOT then
		if EnsurePayloadClientState() then
			hook.Remove("Think", "TF_PayloadClientBootstrap")
		end
		return
	end

	if not EnsurePayloadClientState() then return end
	ApplyPayloadSnapshot(PENDING_SNAPSHOT)
	PENDING_SNAPSHOT = nil
	hook.Remove("Think", "TF_PayloadClientBootstrap")
end)

net.Receive("TF_PayloadSyncFull", function()
	ApplyPayloadSnapshot(ReadPayloadSnapshot())
end)

net.Receive("TF_PayloadSyncDelta", function()
	ApplyPayloadSnapshot(ReadPayloadSnapshot())
end)

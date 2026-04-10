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

local function BuildDefaultPayloadStateCollection()
	return {
		list = {},
		byAttackTeam = {},
		primary = BuildDefaultPayloadState(),
		multiple = false,
	}
end

local function GetGamemodeTable()
	return rawget(_G, "GAMEMODE") or rawget(_G, "GM")
end

local function EnsurePayloadClientState()
	local gm = GetGamemodeTable()
	if not gm then return nil end

	gm.PayloadState = gm.PayloadState or BuildDefaultPayloadState()
	gm.PayloadStates = gm.PayloadStates or BuildDefaultPayloadStateCollection()
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

local function ReadPayloadSnapshotCollection()
	local snapshots = BuildDefaultPayloadStateCollection()
	local count = net.ReadUInt(4)

	for i = 1, count do
		local snapshot = ReadPayloadSnapshot()
		table.insert(snapshots.list, snapshot)
		snapshots.byAttackTeam[tonumber(snapshot.attackTeam) or 0] = snapshot
	end

	snapshots.multiple = #snapshots.list > 1
	snapshots.primary = snapshots.list[1] or BuildDefaultPayloadState()
	return snapshots
end

local function ApplyPayloadSnapshotCollection(snapshots)
	local gm = EnsurePayloadClientState()
	if not gm then
		PENDING_SNAPSHOT = snapshots
		return
	end

	gm.PayloadStates = snapshots
	gm.PayloadState = snapshots.primary or BuildDefaultPayloadState()
	gm.PayloadHUDActive = false
	for _, snapshot in ipairs(snapshots.list or {}) do
		if snapshot.active then
			gm.PayloadHUDActive = true
			break
		end
	end
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
	ApplyPayloadSnapshotCollection(PENDING_SNAPSHOT)
	PENDING_SNAPSHOT = nil
	hook.Remove("Think", "TF_PayloadClientBootstrap")
end)

net.Receive("TF_PayloadSyncFull", function()
	ApplyPayloadSnapshotCollection(ReadPayloadSnapshotCollection())
end)

net.Receive("TF_PayloadSyncDelta", function()
	ApplyPayloadSnapshotCollection(ReadPayloadSnapshotCollection())
end)

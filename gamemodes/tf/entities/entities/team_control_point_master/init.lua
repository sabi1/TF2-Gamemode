ENT.Type = "point"

local team_control_point = "team_control_point"
local tf_team_control_point = "tf_team_control_point"

local function GetPointID(cp)
	if not IsValid(cp) then return nil end
	return tonumber(cp.ID or (cp.Properties and cp.Properties.point_index))
end

local function GetAllControlPoints()
	local points = {}
	for _, cp in ipairs(ents.FindByClass(team_control_point)) do
		points[#points + 1] = cp
	end
	for _, cp in ipairs(ents.FindByClass(tf_team_control_point)) do
		points[#points + 1] = cp
	end
	return points
end

local function SortControlPoints(points)
	table.sort(points, function(a, b)
		local aID = GetPointID(a)
		local bID = GetPointID(b)
		if aID == nil and bID == nil then
			return a:EntIndex() < b:EntIndex()
		end
		if aID == nil then
			return false
		end
		if bID == nil then
			return true
		end
		if aID == bID then
			return a:EntIndex() < b:EntIndex()
		end
		return aID < bID
	end)
	return points
end

local function NormalizeControlPointIDs(points)
	SortControlPoints(points)
	for index, cp in ipairs(points) do
		local pointID = index - 1
		cp.ID = pointID
		cp.Properties = cp.Properties or {}
		cp.Properties.point_index = pointID
	end
	return points
end

function ENT:Initialize()
end

function ENT:InitPostEntity()
	self:SyncObjectiveHud()
end

function ENT:SendData(pl)
	local layout = self.Properties and self.Properties.caplayout
	
	if not layout then
		layout = ""
		local tab = NormalizeControlPointIDs(GetAllControlPoints())
		for _, v in ipairs(tab) do
			local id = GetPointID(v)
			if id then
				layout = layout .. id .. " "
			end
		end
	end
	
	umsg.Start("TF_SetControlPointLayout", pl)
		umsg.String(layout)
	umsg.End()
end

function ENT:SyncObjectiveHud(pl)
	local points = NormalizeControlPointIDs(GetAllControlPoints())

	self:SendData(pl)

	for _, cp in ipairs(points) do
		if not IsValid(cp) then continue end
		if cp.SendData then
			cp:SendData(pl)
		end

		local id = GetPointID(cp)
		local owner = tonumber((cp.GetOwnerTeam and cp:GetOwnerTeam()) or cp.OwnerTeam or (cp.Properties and cp.Properties.point_default_owner) or 0) or 0
		if id then
			umsg.Start("TF_SetControlPointTeam", pl)
				umsg.Char(id)
				umsg.Char(owner)
			umsg.End()

			local locked = cp.Locked and true or false
			umsg.Start(locked and "TF_LockControlPoint" or "TF_OpenControlPoint", pl)
				umsg.Char(id)
			umsg.End()
		end
	end
end

function ENT:UpdateControlPoints()
	local pts = NormalizeControlPointIDs(GetAllControlPoints())
	for _,v in pairs(pts) do
		if not v.Ready then return end
	end
	
	for _,v in pairs(pts) do
		v:UpdateLockStatus()
	end
	
	self.ControlPointsReady = true
end

function ENT:KeyValue(key,value)
	key = string.lower(key)
	
	if not self.Properties then
		self.Properties = {}
	end
	if tonumber(value) then value=tonumber(value) end
	self.Properties[key] = value
end

function ENT:Think() 

	if not GAMEMODE.PostEntityDone then return end
	if GAMEMODE.PostEntityDone and not self.PostEntityDone then
		self:InitPostEntity()
		self.PostEntityDone = true
		return
	end
	
	if not self.ControlPointsReady then
		self:UpdateControlPoints()
	end
end

local function SyncObjectiveHudToPlayer(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	local master = ents.FindByClass("team_control_point_master")[1]
	if IsValid(master) and master.SyncObjectiveHud then
		master:SyncObjectiveHud(ply)
	end
end

hook.Add("PlayerInitialSpawn", "TF_ObjectiveHUDSync_InitialSpawn", function(ply)
	timer.Simple(1.0, function()
		SyncObjectiveHudToPlayer(ply)
	end)
end)

hook.Add("PlayerSpawn", "TF_ObjectiveHUDSync_Spawn", function(ply)
	timer.Simple(0.25, function()
		SyncObjectiveHudToPlayer(ply)
	end)
end)

hook.Add("OnPlayerChangedTeam", "TF_ObjectiveHUDSync_TeamChange", function(ply)
	timer.Simple(0.25, function()
		SyncObjectiveHudToPlayer(ply)
	end)
end)

function ENT:AcceptInput(name, activator, caller, data)
	
end

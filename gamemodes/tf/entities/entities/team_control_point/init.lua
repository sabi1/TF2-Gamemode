include("shared.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

local DEFAULT_CP_MODEL = "models/props_gameplay/cap_point_base.mdl"

local function GetPointID(ent)
	return tonumber(ent.ID or (ent.Properties and ent.Properties.point_index))
end

local function GetOwnerTeam(ent)
	return tonumber(ent.OwnerTeam or (ent.Properties and ent.Properties.point_default_owner) or 0) or 0
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.ID = GetPointID(self)
	self.OwnerTeam = GetOwnerTeam(self)
	self.Locked = false
	self:SetNWInt("Team", self.OwnerTeam)
	self:UpdateModel()
end

function ENT:UpdateModel()
	local model = self.Properties and self.Properties["team_model_" .. tostring(self.OwnerTeam)]
	if not isstring(model) or model == "" then
		model = self:GetModel()
	end
	if not isstring(model) or model == "" or model == "models/error.mdl" then
		model = DEFAULT_CP_MODEL
	end

	self:SetModel(model)

	local bodygroupCount = self:GetNumBodyGroups() or 0
	if bodygroupCount > 0 then
		local maxValue = math.max(0, self:GetBodygroupCount(0) - 1)
		self:SetBodygroup(0, math.Clamp(self.OwnerTeam, 0, maxValue))
	end
	self:ResetSequence(self:SelectWeightedSequence(ACT_IDLE))
	self:DrawShadow(false)
end

function ENT:InitPostEntity()
	if not IsValid(self.TriggerEntity) then
		return
	end
	
	self.Properties.team_previouspoint_2_0 = ents.FindByName(self.Properties.team_previouspoint_2_0 or "")[1] or NULL
	self.Properties.team_previouspoint_2_1 = ents.FindByName(self.Properties.team_previouspoint_2_1 or "")[1] or NULL
	self.Properties.team_previouspoint_2_2 = ents.FindByName(self.Properties.team_previouspoint_2_2 or "")[1] or NULL
	self.Properties.team_previouspoint_3_0 = ents.FindByName(self.Properties.team_previouspoint_3_0 or "")[1] or NULL
	self.Properties.team_previouspoint_3_1 = ents.FindByName(self.Properties.team_previouspoint_3_1 or "")[1] or NULL
	self.Properties.team_previouspoint_3_2 = ents.FindByName(self.Properties.team_previouspoint_3_2 or "")[1] or NULL
	
	self:SendData()
	self.Ready = true
end

function ENT:SendData(pl)
	local pointID = GetPointID(self)
	if not pointID then return end

	umsg.Start("TF_AddControlPoint", pl)
		umsg.Char(pointID)
		umsg.String(self.Properties.point_printname or "")
		
		umsg.String(self.Properties.team_icon_0 or "")
		umsg.String(self.Properties.team_icon_2 or "")
		umsg.String(self.Properties.team_icon_3 or "")
		
		umsg.String(self.Properties.team_overlay_0 or "")
		umsg.String(self.Properties.team_overlay_2 or "")
		umsg.String(self.Properties.team_overlay_3 or "")
		
		umsg.Char(GetOwnerTeam(self))
	umsg.End()
end

function ENT:SetOwnerTeam(o)
	self.OwnerTeam = o
	self:SetNWInt("Team", self.OwnerTeam)
	self.ID = GetPointID(self)
	if self.ID then
		umsg.Start("TF_SetControlPointTeam")
			umsg.Char(self.ID)
			umsg.Char(self.OwnerTeam)
		umsg.End()
	end
	self:UpdateModel()
end
function ENT:GetOwnerTeam()
	return self.OwnerTeam
end

function ENT:Open()
	self.Locked = false
	self.ID = GetPointID(self)
	if self.ID then
		umsg.Start("TF_OpenControlPoint")
			umsg.Char(self.ID)
		umsg.End()
	end
end

function ENT:Lock()
	self.Locked = true
	self.ID = GetPointID(self)
	if self.ID then
		umsg.Start("TF_LockControlPoint")
			umsg.Char(self.ID)
		umsg.End()
	end
end

function ENT:SetLocked(b)
	if b then
		self:Lock()
	else
		self:Open()
	end
end

function ENT:GetAllControlPoints()
	local points = ents.FindByClass("team_control_point")
	if #points == 0 then
		points = ents.FindByClass("tf_team_control_point")
	end
	return points
end

-- Should this control point be locked or not?
function ENT:ComputeLockStatus()
	local selfID = tonumber(self.ID or (self.Properties and self.Properties.point_index))
	local function getPointID(point)
		return tonumber(point.ID or (point.Properties and point.Properties.point_index))
	end
	local function getPointOwnerTeam(point)
		return tonumber(point.OwnerTeam or (point.Properties and point.Properties.point_default_owner))
	end

	if self.TeamCanCap then
		-- If this point cannot be captured by any team other than its owner, it's definitely locked
		local lock = true
		for t=2,3 do
			if t~=self.OwnerTeam and self.TeamCanCap[t] then
				lock = false
				break
			end
		end
		if lock then
			return true
		end
	end
	
	local pt
	local lock = true
	for t=2,3 do
		if self.OwnerTeam ~= t then
			local cancap = true
			
			if self.TeamCanCap and not self.TeamCanCap[t] then
				cancap = false
			else
				for i=0,2 do
					pt = self.Properties["team_previouspoint_"..t.."_"..i]
					if not IsValid(pt) then
						if i==0 then
							local cannotcap = false
							for _,pt in pairs(self:GetAllControlPoints()) do
								if pt ~= self and selfID then
									local ptID = getPointID(pt)
									if ptID and ((t==2 and ptID>selfID) or (t==3 and ptID<selfID)) then
										local ownerTeam = getPointOwnerTeam(pt)
										if ownerTeam~=t then
											cannotcap = true
											break
										end
									end
								end
							end
							if cannotcap then
								cancap = false
								break
							end
						end
					else
						if pt~=self then
							local ownerTeam = getPointOwnerTeam(pt)
							if ownerTeam~=t then
								cancap = false
								break
							end
						end
					end
				end
			end
			
			if cancap then
				lock = false
				break
			end
		end
	end
	return lock
end

function ENT:UpdateLockStatus()
	local l = self:ComputeLockStatus()
	--print("Control point "..self.ID.." lock status : "..tostring(l))
	self:SetLocked(l)
end

function ENT:KeyValue(key,value)
	key = string.lower(key)
	
	if not self.Properties then
		self.Properties = {}
	end
	if (key == "point_index") then
		if (tonumber(value)) then
			self.ID = tonumber(value)
		end
	elseif (key == "point_default_owner") then
		if (tonumber(value)) then
			if (tonumber(value) == 2) then
				self.TeamNum = TEAM_RED
			elseif (tonumber(value) == 3) then
				self.TeamNum = TEAM_BLU
			else
				self.TeamNum = tonumber(value)
			end
		end
	end
	if tonumber(value) then value=tonumber(value) end
	self.Properties[key] = value
end

function ENT:Think()
	if not GAMEMODE.PostEntityDone then return end
	if GAMEMODE.PostEntityDone and not self.Ready then
		self:InitPostEntity()
		return
	end
	
	
end
function ENT:AcceptInput(name, activator, caller, data)
	if name == "SetOwner" then
		local teamNum = tonumber(data)
		if teamNum then
			self:SetOwnerTeam(teamNum)

			local master = ents.FindByClass("team_control_point_master")[1]
			if IsValid(master) and master.UpdateControlPoints then
				master:UpdateControlPoints()
			else
				for _,point in ipairs(self:GetAllControlPoints()) do
					if point.UpdateLockStatus then
						point:UpdateLockStatus()
					end
				end
			end

			return true
		end
	end
end

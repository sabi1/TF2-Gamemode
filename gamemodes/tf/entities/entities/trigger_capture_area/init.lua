ENT.Base = "base_brush"
ENT.Type = "brush"


function ENT:Initialize()
	self.Players = 0 
end

local function GetPlayerControlPointTeam(ply)
	if not IsValid(ply) or not ply:IsPlayer() then
		return nil
	end

	if ply:Team() == TEAM_RED then
		return 2
	end
	if ply:Team() == TEAM_BLU then
		return 3
	end

	return nil
end

local function GetControlPointOwnerTeam(cp)
	if not IsValid(cp) then
		return nil
	end

	if cp.GetOwnerTeam then
		return tonumber(cp:GetOwnerTeam())
	end

	return tonumber(cp.OwnerTeam or (cp.Properties and cp.Properties.point_default_owner))
end

function ENT:RefreshControlPointLocks()
	local master = ents.FindByClass("team_control_point_master")[1]
	if IsValid(master) and master.UpdateControlPoints then
		master:UpdateControlPoints()
		return
	end

	local points = ents.FindByClass("team_control_point")
	if #points == 0 then
		points = ents.FindByClass("tf_team_control_point")
	end

	for _, point in ipairs(points) do
		if point.UpdateLockStatus then
			point:UpdateLockStatus()
		end
	end
end

function ENT:InitPostEntity()
	--print(self)
	self.CapturePoint = ents.FindByName(self.Properties.area_cap_point or "")[1] or NULL
	
	if IsValid(self.CapturePoint) then
		self.CapturePoint.TriggerEntity = self
		self.CapturePoint.TeamCanCap = {
			[2]=(self.Properties.team_cancap_2==1),
			[3]=(self.Properties.team_cancap_3==1),
		}
	end
	
	PrintTable(self.Properties or {})
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
	
	local pos = self:GetPos()
	local mins, maxs = self:WorldSpaceAABB() -- https://forum.facepunch.com/gmoddev/lmcw/Brush-entitys-ent-GetPos/1/#postdwfmq
	pos = (mins + maxs) * 0.5
	if (self.Pos ~= pos) then
		self.Pos = pos
	end
	
		for _,train in ipairs(ents.FindByClass("func_tracktrain")) do
			if (string.find(game.GetMap(),"pl_")) then
				self.Train = train
						
				for _,hurt in ipairs(ents.FindByClass("trigger_hurt")) do
					if (hurt:GetParent() == train) then
						hurt:Remove()
					end
				end
			end
		end
	if GAMEMODE.PostEntityDone and not self.PostEntityDone then
		self:InitPostEntity()
		self.PostEntityDone = true
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	
end

function ENT:StartTouch(ent)
	if (ent:IsPlayer()) then 
		if (ent:Team() == TEAM_BLU) then
			self.Players = self.Players + 1
		end
	end
	if (IsValid(self.Train)) then
		if (ent:IsPlayer()) then  
			timer.Stop("CartGoesBackwards"..self:EntIndex())
			if (ent:Team() == TEAM_BLU) then
				self.Train:Fire("SetSpeedDirAccel",tostring(0.3 * self.Players),0.01)
				ent:Speak("TLK_CART_MOVING_FORWARD")
			else
				self.Train:Fire("Stop","",0.01)
				for k,v in ipairs(player.GetAll()) do
					v:Speak("TLK_CART_STOP")
				end
			end
		end
	else
		if IsValid(self.CapturePoint) and ent:IsPlayer() then
			local capTeam = GetPlayerControlPointTeam(ent)
			if not capTeam then
				return
			end

			if ent.CurrentControlPoint ~= self.CapturePoint.ID then
				ent.CurrentControlPoint = self.CapturePoint.ID
				umsg.Start("TF_EnterControlPoint", ent)
					umsg.Char(ent.CurrentControlPoint)
				umsg.End()

				local ownerTeam = GetControlPointOwnerTeam(self.CapturePoint)
				if ownerTeam ~= capTeam and not self.CapturePoint.Locked then
					umsg.Start("TF_PlayGlobalSound", ent)
						umsg.String("Announcer.ControlPointContested")
					umsg.End()
					self.CapturePoint:EmitSound("ControlPoint.Start", 80, 100)
					self.CapturePoint:EmitSound("ControlPoint.Move", 80, 100)
					timer.Create("CapPoint"..ent.CurrentControlPoint, 10, 1, function()
						if not IsValid(self) or not IsValid(self.CapturePoint) or not IsValid(ent) then
							return
						end
						if ent.CurrentControlPoint ~= self.CapturePoint.ID then
							return
						end
						if self.CapturePoint.Locked then
							return
						end

						local captureTeam = GetPlayerControlPointTeam(ent)
						if not captureTeam then
							return
						end
						if GetControlPointOwnerTeam(self.CapturePoint) == captureTeam then
							return
						end

						self.CapturePoint:SetOwnerTeam(captureTeam)
						self.CapturePoint:StopSound("ControlPoint.Move")
						self.CapturePoint:EmitSound("ControlPoint.Stop")
						self:RefreshControlPointLocks()
					end)
				end  
				if ownerTeam == capTeam then
					timer.Stop("CapPoint"..ent.CurrentControlPoint)
					self.CapturePoint:StopSound("ControlPoint.Move")
					self.CapturePoint:EmitSound("ControlPoint.Malfunction")
					timer.Create("CapPoint"..ent.CurrentControlPoint, 20, 1, function()
						self.CapturePoint:StopSound("ControlPoint.Malfunction")
						self.CapturePoint:EmitSound("ControlPoint.Stop")
					end)
					
				end
			end
		end
	end
end

function ENT:EndTouch(ent)
	if (ent:IsPlayer()) then 
		if (ent:Team() == TEAM_BLU) then
			self.Players = self.Players - 1
		end
	end
	if (IsValid(self.Train)) then
		if (ent:IsPlayer()) then 
			if (self.Players == 0) then
				self.Train:Fire("Stop","",0.01)
				for k,v in ipairs(player.GetAll()) do
					v:Speak("TLK_CART_STOP")
				end
						
				timer.Create("CartGoesBackwards"..self:EntIndex(), 30, 1, function()
					self.Train:Fire("SetSpeedDirAccel",tostring(-0.05),0.01)
					for k,v in ipairs(player.GetAll()) do
						v:Speak("TLK_CART_MOVING_BACKWARD")
					end
				end)
			else
				self.Train:Fire("SetSpeedDirAccel",tostring(0.3 * self.Players),0.01)
			end
		end
	else
		if IsValid(self.CapturePoint) and ent:IsPlayer() then
			if ent.CurrentControlPoint == self.CapturePoint.ID then
				timer.Stop("CapPoint"..ent.CurrentControlPoint)
				ent.CurrentControlPoint = -1
				umsg.Start("TF_ExitControlPoint", ent)
				umsg.End()
				
				local capTeam = GetPlayerControlPointTeam(ent)
				if capTeam and GetControlPointOwnerTeam(self.CapturePoint) ~= capTeam then
					
					timer.Create("CapPoint"..self.CapturePoint.ID, 20, 1, function()
						self.CapturePoint:StopSound("ControlPoint.Move")
						self.CapturePoint:StopSound("ControlPoint.Malfunction")
						self.CapturePoint:EmitSound("ControlPoint.Stop")
					end)
					
				end
			end
		end
	end
end

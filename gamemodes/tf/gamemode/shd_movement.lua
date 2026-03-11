local cv_tf_clamp_back_speed = CreateConVar("tf_clamp_back_speed", "0.9", {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "TF2 backpedal speed clamp multiplier.")
local cv_tf_clamp_back_speed_min = CreateConVar("tf_clamp_back_speed_min", "100", {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Minimum speed before TF2 backpedal clamp is enforced.")

local function TFIsHL2Player(pl)
	if not IsValid(pl) then return false end
	if pl.IsHL2 then
		return pl:IsHL2()
	end
	return pl:GetNWBool("IsHL2", false)
end

hook.Add("Move", "TFMove", function(pl, move)
	if CLIENT and not pl.TempAttributes then
		pl.TempAttributes = {}
	end
	
	if TFIsHL2Player(pl) then return end

	if pl:GetNWBool("TauntingMoped", false) then
		local forward = pl:GetForward()
		forward.z = 0
		forward:Normalize()

		local driveSpeed = 95
		local turnSpeed = 60
		local turnAccelTime = 0.2
		local dt = engine.TickInterval()
		local input = math.Clamp(tonumber(pl.__MopedTurnInput) or 0, -1, 1)

		local targetTurn = input * turnSpeed
		pl.__MopedTurnRate = pl.__MopedTurnRate or 0
		local turnDelta = (turnSpeed / math.max(turnAccelTime, 0.01)) * dt
		pl.__MopedTurnRate = math.Approach(pl.__MopedTurnRate, targetTurn, turnDelta)

		local ea = pl:EyeAngles()
		ea.y = math.NormalizeAngle(ea.y + pl.__MopedTurnRate * dt)
		pl:SetEyeAngles(ea)

		local vel = move:GetVelocity()
		local planar = forward * driveSpeed
		vel.x = planar.x
		vel.y = planar.y
		move:SetVelocity(vel)
		move:SetForwardSpeed(driveSpeed)
		move:SetSideSpeed(0)
		move:SetUpSpeed(0)
		move:SetMaxSpeed(math.max(move:GetMaxSpeed(), driveSpeed))
		move:SetMaxClientSpeed(math.max(move:GetMaxClientSpeed(), driveSpeed))
		return
	end

	if pl:GetNWBool("HalloweenKart", false) then
		local moveSpeed = 200
		local boostSpeed = 320
		local turnSpeed = 90
		local turnAccelTime = 0.2
		local driveAccelTime = 0.25
		local dt = engine.TickInterval()
		local steerInput = math.Clamp(tonumber(pl.__TFKartTurnInput) or 0, -1, 1)
		local driveInput = math.Clamp(tonumber(pl.__TFKartDriveInput) or 0, -1, 1)

		pl.__TFKartTurnRate = pl.__TFKartTurnRate or 0
		pl.__TFKartDriveRate = pl.__TFKartDriveRate or 0

		local targetTurn = steerInput * turnSpeed
		local turnDelta = (turnSpeed / math.max(turnAccelTime, 0.01)) * dt
		pl.__TFKartTurnRate = math.Approach(pl.__TFKartTurnRate, targetTurn, turnDelta)

		local ea = pl:EyeAngles()
		ea.y = math.NormalizeAngle(ea.y + pl.__TFKartTurnRate * dt)
		pl:SetEyeAngles(ea)

		local speedTarget = moveSpeed
		if CurTime() < pl:GetNWFloat("TFKartBoostEndTime", 0) then
			speedTarget = boostSpeed
		end

		local targetDrive = driveInput * speedTarget
		local driveDelta = (speedTarget / math.max(driveAccelTime, 0.01)) * dt
		pl.__TFKartDriveRate = math.Approach(pl.__TFKartDriveRate, targetDrive, driveDelta)

		local forward = pl:GetForward()
		forward.z = 0
		forward:Normalize()

		local vel = move:GetVelocity()
		local planar = forward * pl.__TFKartDriveRate
		vel.x = planar.x
		vel.y = planar.y
		move:SetVelocity(vel)
		move:SetForwardSpeed(pl.__TFKartDriveRate)
		move:SetSideSpeed(0)
		move:SetUpSpeed(0)
		move:SetMaxSpeed(math.max(move:GetMaxSpeed(), math.abs(pl.__TFKartDriveRate)))
		move:SetMaxClientSpeed(math.max(move:GetMaxClientSpeed(), math.abs(pl.__TFKartDriveRate)))
		return
	end

	local schemaState = pl.__SchemaTauntState
	if istable(schemaState) and schemaState.active and (pl:GetNWBool("TauntingSchemaMove", false) or schemaState.moveSpeed > 0 or schemaState.turnSpeed > 0 or schemaState.forceForward) then
		local moveSpeed = math.max(tonumber(schemaState.moveSpeed) or 0, 0)
		local turnSpeed = math.max(tonumber(schemaState.turnSpeed) or 0, 0)
		local turnAccelTime = math.max(tonumber(schemaState.turnAccel) or 0.2, 0.01)
		local steerInput = math.Clamp(tonumber(pl.__SchemaTauntMoveInput) or 0, -1, 1)
		local driveInput = math.Clamp(tonumber(pl.__SchemaTauntDriveInput) or 0, -1, 1)
		local dt = engine.TickInterval()

		pl.__SchemaTauntTurnRate = pl.__SchemaTauntTurnRate or 0
		pl.__SchemaTauntDriveRate = pl.__SchemaTauntDriveRate or 0

		if turnSpeed > 0 then
			local targetTurn = steerInput * turnSpeed
			local turnDelta = (turnSpeed / turnAccelTime) * dt
			pl.__SchemaTauntTurnRate = math.Approach(pl.__SchemaTauntTurnRate, targetTurn, turnDelta)

			local ea = pl:EyeAngles()
			ea.y = math.NormalizeAngle(ea.y + pl.__SchemaTauntTurnRate * dt)
			pl:SetEyeAngles(ea)
		else
			pl.__SchemaTauntTurnRate = 0
		end

		local targetDrive = 0
		if schemaState.forceForward then
			targetDrive = moveSpeed
		elseif moveSpeed > 0 then
			targetDrive = driveInput * moveSpeed
		end

		if moveSpeed > 0 then
			local driveDelta = (moveSpeed / turnAccelTime) * dt
			pl.__SchemaTauntDriveRate = math.Approach(pl.__SchemaTauntDriveRate, targetDrive, driveDelta)
		else
			pl.__SchemaTauntDriveRate = 0
		end

		local forward = pl:GetForward()
		forward.z = 0
		forward:Normalize()

		local vel = move:GetVelocity()
		local planar = forward * pl.__SchemaTauntDriveRate
		vel.x = planar.x
		vel.y = planar.y
		move:SetVelocity(vel)
		move:SetForwardSpeed(pl.__SchemaTauntDriveRate)
		move:SetSideSpeed(0)
		move:SetUpSpeed(0)
		move:SetMaxSpeed(math.max(move:GetMaxSpeed(), math.abs(pl.__SchemaTauntDriveRate)))
		move:SetMaxClientSpeed(math.max(move:GetMaxClientSpeed(), math.abs(pl.__SchemaTauntDriveRate)))
		return
	end

	pl.__SchemaTauntTurnRate = 0
	pl.__SchemaTauntDriveRate = 0
	pl.__TFKartTurnRate = 0
	pl.__TFKartDriveRate = 0
	
	-- Mirror TF2 tf_clamp_back_speed / tf_clamp_back_speed_min behavior.
	local fwd = move:GetForwardSpeed()
	if fwd < 0 and not TFIsHL2Player(pl) then
		local clampScale = cv_tf_clamp_back_speed:GetFloat()
		local clampMin = cv_tf_clamp_back_speed_min:GetFloat()
		if clampScale < 1 and move:GetVelocity():Length() > clampMin then
			local maxBackSpeed = pl:GetRunSpeed() * clampScale
			if math.abs(fwd) > maxBackSpeed and not pl:Crouching() then
				move:SetMaxSpeed(maxBackSpeed)
				move:SetMaxClientSpeed(maxBackSpeed)
			end
		end
	end
	
	if pl:OnGround() then
		pl.Jumps=0
		pl.DoubleJumping = nil
	end
	
	if pl:KeyPressed(IN_JUMP) and pl.playerclass == "Scout" and pl:GetPlayerClass() != "spy" and not pl.TempAttributes.DisableDoubleJump then
		local vel = move:GetVelocity()
		if not pl:OnGround() then
			if not pl.Jumps then pl.Jumps = 0 end
			if pl.Jumps < 1 then
				local forward = pl:GetForward()
				forward.z = 0
				forward:Normalize()
				
				local right = pl:GetRight()
				right.z = 0
				right:Normalize()
				
				local vel = Vector(0, 0, 0)
				--vel = vel + pl.PlayerJumpPower * vector_up -- Add vertical force
				vel = vel + pl:GetJumpPower() * vector_up -- Add vertical force
				
				local spd = pl:GetRealClassSpeed()
				
				if pl:KeyDown(IN_FORWARD) then
					vel = vel + forward * spd
				elseif pl:KeyDown(IN_BACK) then
					vel = vel - forward * spd
				end
		
				if pl:KeyDown(IN_MOVERIGHT) then
					vel = vel + right * spd
				elseif pl:KeyDown(IN_MOVELEFT) then
					vel = vel - right * spd
				end

				move:SetVelocity(vel)
								
				--pl:SetAnimation(10002)
				pl:DoAnimationEvent(ACT_MP_DOUBLEJUMP, true)
				
				pl.Jumps = pl.Jumps + 1
				pl.DoubleJumping = true
				
				if SERVER then
					ApplyGlobalAttributesFromPlayer(pl, "double_jump", pl)
				end
			end
		end
		
		--MsgFN("Velocity : %f %f %f", vel.x, vel.y, vel.z)
		--MsgFN("On ground : %s", tostring(pl:OnGround()))
	end
end)

hook.Add("SetupMove", "TFSetupMove", function(pl, move)
	if TFIsHL2Player(pl) then return end

	-- Can't move when crouched in the loser state
	if pl:Crouching() then
		if pl:IsLoser() then
			move:SetForwardSpeed(0)
			move:SetSideSpeed(0)
		end
	end
	
	-- Fixes the 50% speed boost when jumping (probably residual code from HL2)
	if pl:OnGround() then
		pl.__JumpFixDone = false
	elseif not pl.__JumpFixDone then
		local vel = move:GetVelocity()
		
		local length = vel:Length2D()
		local max = pl:GetRealClassSpeed()
		
		if length > max then
			local r = max / length
			vel.x = vel.x * r
			vel.y = vel.y * r
			
			move:SetVelocity(vel)
		end
		
		pl.__JumpFixDone = true
	end
end)

--[[
local function GetAdditionalJumpCount(pl)
	local t = pl:GetPlayerClassTable()
	local j = 0
	
	if t and t.AdditionalJumpCount then
		j = t.AdditionalJumpCount
	end
	
	j = math.max(0, j
end]]

--[[
hook.Add("KeyPress", "TFMultipleJump", function(pl, k)
	if not pl or not pl:IsValid() or pl:GetPlayerClass()~="scout" or k~=IN_JUMP then
		return
	end
	
	if pl.TempAttributes and pl.TempAttributes.DisableDoubleJump then
		return
	end
	
	if not pl.Jumps or pl:IsOnGround() then
		pl.Jumps=0
	end

	if pl.Jumps==0 and not pl:IsOnGround() then
		pl.Jumps = 1
	end
	
	if pl.Jumps>=2 then return end
	
	pl.Jumps = pl.Jumps + 1
	if pl.Jumps>1 then
		local forward = pl:GetForward()
		forward.z = 0
		forward:Normalize()
		
		local right = pl:GetRight()
		right.z = 0
		right:Normalize()
		
		local vel = -1 * pl:GetVelocity() -- Nullify current velocity
		vel = vel + pl.PlayerJumpPower * vector_up -- Add vertical force
		
		local spd = pl:GetRealClassSpeed()
		
		if pl:KeyDown(IN_FORWARD) then
			vel = vel + forward * spd
		elseif pl:KeyDown(IN_BACK) then
			vel = vel - forward * spd
		end
		
		if pl:KeyDown(IN_MOVERIGHT) then
			vel = vel + right * spd
		elseif pl:KeyDown(IN_MOVELEFT) then
			vel = vel - right * spd
		end
		
		pl:SetVelocity(vel)
		
		--pl:SetAnimation(10002)
		pl:DoAnimationEvent(ACT_MP_DOUBLEJUMP, true)
		
		pl.DoubleJumping = 1
	end
end)
]]

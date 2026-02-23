ENT.Base = "base_brush"
ENT.Type = "brush"

function ENT:Initialize()
	local pos = self:GetPos()
	local mins, maxs = self:WorldSpaceAABB() -- https://forum.facepunch.com/gmoddev/lmcw/Brush-entitys-ent-GetPos/1/#postdwfmq
	pos = (mins + maxs) * 0.5

	self.Team = self.Team or 0		
	self.TeamNum = self.TeamNum or 0
	self.Pos = pos
	SetGlobalFloat("tf_ctf_red", 0)
	SetGlobalFloat("tf_ctf_blu", 0)
	--SetGlobalFloat("tf_ctf_red_lastcap", CurTime() - 120)
	--SetGlobalFloat("tf_ctf_blu_lastcap", CurTime() - 120)
end

function ENT:KeyValue(key,value)
	key = string.lower(key)
	
	if key=="teamnum" then
		local t = tonumber(value)
		
		if t==0 then
			self.TeamNum = 0
		elseif t==2 then
			self.TeamNum = TEAM_RED
		elseif t==3 then
			self.TeamNum = TEAM_BLU
		end

		self.Team = tonumber(value)
	end
	--print(key, value, tonumber(value), self.Team)
end

function ENT:StartTouch(ply)
	if not IsValid(ply) then return end

	if ply:GetClass() == "npc_mvm_tank" then
		ply:DeployBomb()
		timer.Create("Tank", 0.001, 0, function()
			ply:SetThrottle(0)
		end)
		timer.Simple(7.5, function()
			ply:Explode()
			RunConsoleCommand("tf_mvm_wins")
		end)
	end
	
	if not ply:IsPlayer() then return end

	for _,v in pairs(ents.FindByClass("item_teamflag")) do
		----print(self.Team, v.te, self.Pos:Distance(ply) <= 50)
		----print(self.Team ~= v.te, v.Carrier == ply, v:GetPos():Distance(ply:GetPos()) <= 50)
		if v.Carrier==ply and self.Team ~= v.te and v.Prop:GetPos():Distance(ply:GetPos()) <= 100 then
			if game.GetMap() == "mvm_terroristmission_v7_1" then
				RunConsoleCommand("tf_red_wins")
			end
			
			ply:Speak("TLK_FLAGCAPTURED")
			v:Capture()
			--team.AddScore(v.TeamNum, 1)
			if v.TeamNum == TEAM_RED then
				team.AddScore(TEAM_BLU, 1)
				if (team.GetScore(TEAM_BLU) > GetConVarNumber("tf_flag_caps_per_round") - 1 and !GAMEMODE.RoundHasWinner) then
					GAMEMODE:RoundWin(TEAM_BLU)
					return
				end
				--SetGlobalFloat("tf_ctf_blu", GetGlobalFloat("tf_ctf_blu") + 1)
			else
				team.AddScore(TEAM_RED, 1)
				if (team.GetScore(TEAM_RED) > GetConVarNumber("tf_flag_caps_per_round") - 1 and !GAMEMODE.RoundHasWinner) then
					GAMEMODE:RoundWin(TEAM_RED)
					return
				end
				--SetGlobalFloat("tf_ctf_red", GetGlobalFloat("tf_ctf_red") + 1)
			end

			--SetGlobalFloat("tf_ctf_red_lastcap", CurTime())
			--SetGlobalFloat("tf_ctf_blu_lastcap", CurTime())

			for _, ply in pairs(player.GetAll()) do
				if ply:Team() ~= v.TeamNum then
					ply:SendLua([[surface.PlaySound("vo/intel_teamcaptured.mp3")]])
					GAMEMODE:StartCritBoost(ply)
					if (!GAMEMODE.RoundHasWinner) then
						timer.Simple(10, function()
							if IsValid(ply) then
								GAMEMODE:StopCritBoost(ply)
							end
						end)
					end
				else
					ply:SendLua([[surface.PlaySound("vo/intel_enemycaptured.mp3")]])
				end
			end
		end
	end
	for _,v in pairs(ents.FindByClass("item_teamflag_mvm")) do
		if not IsValid(v) then continue end
		if v.Deploying then continue end
		if not IsValid(v.Carrier) then continue end
		if v.Carrier ~= ply then continue end
		if ply:Team() ~= TEAM_BLU then continue end
		if self.TeamNum ~= TEAM_RED then continue end

		v.Deploying = true
		local carrier = ply
		local captureZone = self
		local deployDuration = 3
		local hadGodMode = carrier:HasGodMode()

		if string.find(carrier:GetModel() or "", "_boss.mdl", 1, true) then
			v:EmitSound("mvm/mvm_deploy_giant.wav", 95, 100)
		else
			v:EmitSound("mvm/mvm_deploy_small.wav", 95, 100)
		end

		for _, player in ipairs(player.GetAll()) do
			player:SendLua([[LocalPlayer():EmitSound("Announcer.MVM_Bomb_Alert_Deploying")]])
		end

		carrier:SetNWBool("Taunting", true)
		carrier:Freeze(true)
		carrier:GodEnable()

		local playedDeployAnim = false
		if carrier.DoAnimationEvent and PLAYERANIMEVENT_CUSTOM then
			carrier:DoAnimationEvent(PLAYERANIMEVENT_CUSTOM, "primary_deploybomb")
			playedDeployAnim = true
		end

		if not playedDeployAnim and carrier.AddVCDSequenceToGestureSlot then
			local seq = carrier:LookupSequence("primary_deploybomb")
			if seq and seq > 0 then
				carrier:AddVCDSequenceToGestureSlot(GESTURE_SLOT_VCD, seq, 0, true)
				playedDeployAnim = true
			end
		end

		if not playedDeployAnim and carrier.AnimRestartGesture then
			carrier:AnimRestartGesture(GESTURE_SLOT_CUSTOM, ACT_MP_ATTACK_STAND_PRIMARY_DEPLOYED, true)
		end

		timer.Simple(deployDuration, function()
			if not IsValid(v) then return end
			if not IsValid(carrier) then
				v.Deploying = false
				return
			end
			if v.Carrier ~= carrier then
				v.Deploying = false
				return
			end

			local effectPos
			if IsValid(captureZone) and captureZone.Pos then
				effectPos = captureZone.Pos
			else
				effectPos = carrier:GetPos()
			end

			v:Capture(carrier, captureZone)

			ParticleEffect("fluidSmokeExpl_ring_mvm", effectPos + Vector(0, 0, 24), Angle(0, 0, 0))
			ParticleEffect("fireSmoke_Collumn_mvmAcres_sm", effectPos + Vector(0, 0, 24), Angle(0, 0, 0))
			util.ScreenShake(effectPos, 8, 180, 1.0, 1000)

			for _,pl in pairs(player.GetAll()) do
				if pl:Team() == TEAM_RED then
					pl:SendLua([[LocalPlayer():EmitSound("Announcer.MVM_Wave_Lose")]])
				end
			end

			carrier:SetNWBool("Taunting", false)
			carrier:Freeze(false)
			if not hadGodMode and carrier:HasGodMode() then
				carrier:GodDisable()
			end

			if carrier:Alive() then
				carrier:Kill()
			end

			RunConsoleCommand("tf_mvm_wins")
			v.Deploying = false
		end)
		return
	end
end

function ENT:EndTouch(ent)
end

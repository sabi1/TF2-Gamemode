local allowedtaunts = {
"1",
"2",
"3",
}

rockpaperscissors = {
	"taunt_rps_scissors_win",
	"taunt_rps_scissors_lose",
	"taunt_rps_paper_win",
	"taunt_rps_paper_lose",
	"taunt_rps_rock_win",
	"taunt_rps_rock_lose",
}
rockpaperscissors2 = {
	"taunt_rps_scissors_lose",
	"taunt_rps_scissors_win",
	"taunt_rps_paper_lose",
	"taunt_rps_paper_win",
	"taunt_rps_rock_lose",
	"taunt_rps_rock_win",
}
rockpaperscissorsact = {
	ACT_DOD_SPRINT_IDLE_BAR,
	ACT_DOD_PRONEWALK_IDLE_BAR,
	ACT_DOD_ZOOMLOAD_BAZOOKA,
	ACT_DOD_RELOAD_PSCHRECK,
	ACT_DOD_ZOOMLOAD_PSCHRECK,
	ACT_DOD_RELOAD_DEPLOYED_FG42,
}

local class_hidewep = {
"scout",
"soldier",
"pyro",
"engineer",
"medic",
}

local wep = {
"tf_weapon_medigun",
"tf_weapon_pistol_scout",
"tf_weapon_rocketlauncher",
"tf_weapon_shotgun_pyro",
"tf_weapon_shotgun_primary",
"tf_weapon_syringegun_medic",
}

local function BlockLegacyMvMCommands(ply)
	if not TF_MVM or not TF_MVM.Runtime then return false end
	if not TF_MVM.Runtime:IsManagedActive() then return false end
	if IsValid(ply) then
		ply:ChatPrint("Legacy MvM wave commands are disabled while POP runtime is active.")
	end
	return true
end


concommand.Add("tf_red_wins", function(ply, cmd)
	GAMEMODE:RoundWin(2)
end)
concommand.Add("tf_neutral_nope", function(ply, cmd)
		for k,v in pairs( player.GetAll() ) do
			if v:Team() == TEAM_NEUTRAL then
				v:EmitSound("vo/engineer_no01.wav", 1, 100)
				timer.Simple(10, function() 
					v:EmitSound("vo/engineer_laughlong01.wav", 1, 100)
				end)
			end
		end
end)

concommand.Add("tf_blue_wins", function(ply, cmd)
	GAMEMODE:RoundWin(3)
end)
concommand.Add("tf_no_one_wins", function(ply, cmd)
end) 
concommand.Add("tf_mvm_wins", function(ply, cmd)
	if BlockLegacyMvMCommands(ply) then return end
	for k,v in pairs( player.GetAll() ) do
		if v:Team() != TEAM_BLU then
			if v:Team() == TEAM_SPECTATOR then
				v:SendLua([[surface.PlaySound("misc/your_team_lost.wav")]])
				v:PrintMessage( HUD_PRINTCENTER, "The robots deployed the bomb! Game over for Mann Co!" )
			else
				v:SendLua([[surface.PlaySound("music/mvm_lost_wave.wav")]])
				v:StripWeapons()	
				timer.Simple(5.5, function() 
					v:Spawn()
	 

					v:SendLua([[surface.PlaySound("vo/mvm_get_to_upgrade01.wav")]])
				end)
				for k,v in pairs(ents.FindByName("gate1_spawn_door")) do
					v:Fire("SetSpeed", "80")
					v:Fire("Close")
				end
				for k,v in pairs(ents.FindByName("gate2_spawn_door")) do
					v:Fire("SetSpeed", "80")
					v:Fire("Close")
				end
				for k,v in pairs(ents.FindByName("gate0_entrance_door")) do
					v:Fire("SetSpeed", "80")
					v:Fire("Open")
				end
				for k,v in pairs(ents.FindByClass("info_player_bluspawn")) do
					v:Fire("Kill")
				end
			end
		end
		if v:Team() == TEAM_BLU then 
			v:SendLua([[surface.PlaySound("misc/your_team_won.wav")]])
			timer.Simple(5, function() 
				v:Spawn() 
			end) 
		end
		if v:GetObserverMode() == OBS_MODE_ROAMING then 
			v:SendLua([[surface.PlaySound("misc/your_team_lost.wav")]])
			v:PrintMessage( HUD_PRINTCENTER, "The robots deployed the bomb! Game over for Mann Co!" )
		end
		timer.Simple(4.9, function() 
			RunConsoleCommand("gmod_admin_cleanup")
		end)
	end
end)

concommand.Add("tf_mvm_wave_end_bonus", function(ply, cmd)
	if BlockLegacyMvMCommands(ply) then return end
	if !ply:IsAdmin() then return end
	ply:EmitSound("vo/mvm_wave_end0"..math.random(1,8)..".wav", 0, 100)
	ply:EmitSound("music/mvm_end_wave.wav", 0, 100)
	timer.Create("HaveABonus", 4, 1, function()
		ply:EmitSound("vo/mvm_bonus0"..math.random(1,3)..".wav", 0, 100)
	end)
	RunConsoleCommand("tf_bot_kick_all")
end)
concommand.Add("tf_help_cap_flag", function(ply, cmd)
	local HelpMeCapture = CurTime() + 3
	if HelpMeCapture or CurTime()>HelpMeCapture then
		if ply:GetPlayerClass() == "scout" then
			ply:EmitSound("vo/scout_helpmecapture0"..math.random(1,3)..".wav", 80, 100)
		elseif ply:GetPlayerClass() == "soldier" then
			ply:EmitSound("vo/soldier_helpmecapture0"..math.random(1,3)..".wav", 80, 100)
		elseif ply:GetPlayerClass() == "pyro" then
			ply:EmitSound("vo/pyro_standonthepoint01.wav", 80, 100)
		elseif ply:GetPlayerClass() == "demoman" then
			ply:EmitSound("vo/demoman_helpmecapture0"..math.random(1,3)..".wav", 80, 100)
		elseif ply:GetPlayerClass() == "heavy" then
			ply:EmitSound("vo/heavy_helpmecapture0"..math.random(1,3)..".wav", 80, 100)
		elseif ply:GetPlayerClass() == "engineer" then
			ply:EmitSound("vo/engineer_helpmecapture0"..math.random(1,3)..".wav", 80, 100)
		elseif ply:GetPlayerClass() == "medic" then
			ply:EmitSound("vo/medic_helpmecapture0"..math.random(1,2)..".wav", 80, 100)
		elseif ply:GetPlayerClass() == "sniper" then
			ply:EmitSound("vo/sniper_helpmecapture0"..math.random(1,3)..".wav", 80, 100)
		elseif ply:GetPlayerClass() == "spy" then
			ply:EmitSound("vo/spy_helpmecapture0"..math.random(1,3)..".wav", 80, 100)
		end
	end
end)
concommand.Add("tf_mvm_wave_end", function(ply, cmd)
	if BlockLegacyMvMCommands(ply) then return end
	if !ply:IsAdmin() then return end
	ply:EmitSound("vo/mvm_wave_end0"..math.random(1,8)..".wav", 0, 100)
	ply:EmitSound("music/mvm_end_wave.wav", 0, 100)
	RunConsoleCommand("tf_bot_kick_all")
end)
concommand.Add("tf_mvm_wave_mid_end", function(ply, cmd)
	if BlockLegacyMvMCommands(ply) then return end
	if !ply:IsAdmin() then return end
	ply:EmitSound("vo/mvm_wave_end0"..math.random(1,8)..".wav", 0, 100)
	ply:EmitSound("music/mvm_end_mid_wave.wav", 0, 100)
	RunConsoleCommand("tf_bot_kick_all")
end)
concommand.Add("tf_mvm_wave_end_tank", function(ply, cmd)
	if BlockLegacyMvMCommands(ply) then return end
	if !ply:IsAdmin() then return end
	ply:EmitSound("vo/mvm_wave_end0"..math.random(1,8)..".wav", 0, 100)
	ply:EmitSound("music/mvm_end_tank_wave.wav", 0, 100)
	RunConsoleCommand("tf_bot_kick_all")
end)
concommand.Add("tf_mvm_wave_end_final", function(ply, cmd)
	if BlockLegacyMvMCommands(ply) then return end
	if !ply:IsAdmin() then return end
	ply:EmitSound("vo/mvm_final_wave_end0"..math.random(1,6)..".wav", 0, 100)
	ply:EmitSound("music/mvm_end_last_wave.wav", 0, 100)
	RunConsoleCommand("tf_bot_kick_all")
end)
concommand.Add("tf_mvm_wave_start", function(ply, cmd)
	if BlockLegacyMvMCommands(ply) then return end
	if !ply:IsAdmin() then return end
	ply:EmitSound("vo/mvm_wave_start0"..math.random(1,9)..".wav", 0, 100)
	ply:EmitSound("music/mvm_start_wave.wav", 0, 100)

	timer.Create("WaveStart1", 4, 1, function() ply:EmitSound("vo/announcer_begins_5sec.wav", 0, 100) end )
	timer.Create("WaveStart2", 5, 1, function() ply:EmitSound("vo/announcer_begins_4sec.wav", 0, 100) end )
	timer.Create("WaveStart3", 6, 1, function() ply:EmitSound("vo/announcer_begins_3sec.wav", 0, 100) end )
	timer.Create("WaveStart4", 7, 1, function() ply:EmitSound("vo/announcer_begins_2sec.wav", 0, 100) end )
	timer.Create("WaveStart5", 8, 1, function() ply:EmitSound("vo/announcer_begins_1sec.wav", 0, 100) end )
	timer.Create("WaveStart6", 10, 1, function() RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add")  end )
end)


concommand.Add("tf_mvm_wave_666_start", function(ply, cmd)
	if BlockLegacyMvMCommands(ply) then return end
	if !ply:IsAdmin() then return end
	ply:EmitSound("vo/mvm_wave_start0"..math.random(1,9)..".wav", 0, 100)
	ply:EmitSound("music/mvm_start_wave.wav", 0, 80)

	timer.Create("WaveStart1", 4, 1, function() ply:EmitSound("vo/announcer_begins_5sec.wav", 0, 100) end )
	timer.Create("WaveStart2", 5, 1, function() ply:EmitSound("vo/announcer_begins_4sec.wav", 0, 100) end )
	timer.Create("WaveStart3", 6, 1, function() ply:EmitSound("vo/announcer_begins_3sec.wav", 0, 100) end )
	timer.Create("WaveStart4", 7, 1, function() ply:EmitSound("vo/announcer_begins_2sec.wav", 0, 100) end )
	timer.Create("WaveStart5", 8, 1, function() ply:EmitSound("vo/announcer_begins_1sec.wav", 0, 100) end )
	timer.Create("WaveStart6", 10, 1, function() RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add")  end )
end)

concommand.Add("tf_mvm_wave_start_mid", function(ply, cmd)
	if BlockLegacyMvMCommands(ply) then return end
	if !ply:IsAdmin() then return end
	ply:EmitSound("vo/mvm_wave_start0"..math.random(1,9)..".wav", 0, 100)
	ply:EmitSound("music/mvm_start_mid_wave.wav", 0, 100)

	timer.Create("WaveStart1", 4, 1, function() ply:EmitSound("vo/announcer_begins_5sec.wav", 0, 100) end )
	timer.Create("WaveStart2", 5, 1, function() ply:EmitSound("vo/announcer_begins_4sec.wav", 0, 100) end )
	timer.Create("WaveStart3", 6, 1, function() ply:EmitSound("vo/announcer_begins_3sec.wav", 0, 100) end )
	timer.Create("WaveStart4", 7, 1, function() ply:EmitSound("vo/announcer_begins_2sec.wav", 0, 100) end )
	timer.Create("WaveStart5", 8, 1, function() ply:EmitSound("vo/announcer_begins_1sec.wav", 0, 100) end )
	timer.Create("WaveStart6", 10, 1, function() RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add")  end )
end)
concommand.Add("tf_mvm_wave_start_tank", function(ply, cmd)
	if BlockLegacyMvMCommands(ply) then return end
	if !ply:IsAdmin() then return end
	ply:EmitSound("vo/mvm_wave_start0"..math.random(1,9)..".wav", 0, 100)
	ply:EmitSound("music/mvm_start_tank_wave.wav", 0, 100)

	timer.Create("WaveStart1", 4, 1, function() ply:EmitSound("vo/announcer_begins_5sec.wav", 0, 100) end )
	timer.Create("WaveStart2", 5, 1, function() ply:EmitSound("vo/announcer_begins_4sec.wav", 0, 100) end )
	timer.Create("WaveStart3", 6, 1, function() ply:EmitSound("vo/announcer_begins_3sec.wav", 0, 100) end )
	timer.Create("WaveStart4", 7, 1, function() ply:EmitSound("vo/announcer_begins_2sec.wav", 0, 100) end )
	timer.Create("WaveStart5", 8, 1, function() ply:EmitSound("vo/announcer_begins_1sec.wav", 0, 100) end ) 
	timer.Create("WaveStart55", 10, 1, function() local tank = ents.Create("npc_mvm_tank") tank:SetPos(Vector(75.86, 2707.76, 256.04)) tank:Spawn()  end )

	timer.Create("WaveStart6", 30, 1, function() RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add")  end )
end)
concommand.Add("tf_mvm_wave_start_final", function(ply, cmd)
	if BlockLegacyMvMCommands(ply) then return end
	if !ply:IsAdmin() then return end
	ply:EmitSound("vo/mvm_final_wave_start0"..math.random(1,9)..".wav", 0, 100)
	ply:EmitSound("music/mvm_start_last_wave.wav", 0, 100)

	timer.Create("WaveStart1", 4, 1, function() ply:EmitSound("vo/announcer_begins_5sec.wav", 0, 100) end )
	timer.Create("WaveStart2", 5, 1, function() ply:EmitSound("vo/announcer_begins_4sec.wav", 0, 100) end )
	timer.Create("WaveStart3", 6, 1, function() ply:EmitSound("vo/announcer_begins_3sec.wav", 0, 100) end )
	timer.Create("WaveStart4", 7, 1, function() ply:EmitSound("vo/announcer_begins_2sec.wav", 0, 100) end )
	timer.Create("WaveStart5", 8, 1, function() ply:EmitSound("vo/announcer_begins_1sec.wav", 0, 100) end )
	timer.Create("WaveStart6", 10, 1, function() RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add") RunConsoleCommand("tf_bot_add")  end )
end)

concommand.Add("tf_taunt_laugh", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local laughByClass = {
		scout = "Scout.LaughLong01",
		soldier = "Soldier.LaughLong01",
		pyro = "Pyro.LaughLong01",
		demoman = "Demoman.LaughLong01",
		heavy = "Heavy.LaughLong01",
		engineer = "Engineer.LaughLong01",
		medic = "Medic.LaughLong01",
		sniper = "Sniper.LaughLong01",
		spy = "Spy.LaughLong01",
	}
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_laugh.vcd", 0)
	ply:DoTauntEvent("taunt_laugh",true)
	ply:SetNWBool("TauntingSchemaMove", false)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	if ply:GetPlayerClass() == "merc_dm" then
		ply:EmitSound("vo/mercenary_laughevil01.wav", 80, 100)
		timer.Create("Laugh" .. ply:EntIndex(), 2, 1, function()
			if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
			ply:SetNWBool("Taunting", false)
			ply:SetNWBool("NoWeapon", false)
			ply:SetNWBool("TauntingSchemaMove", false)
			net.Start("DeActivateTauntCam")
			net.Send(ply)
		end)
	else
		local laughSound = laughByClass[ply:GetPlayerClass()]
		if laughSound then
			ply:EmitSound(laughSound)
		end
		timer.Create("Laugh" .. ply:EntIndex(), time, 1, function()
			if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
			ply:SetNWBool("Taunting", false)
			ply:SetNWBool("NoWeapon", false)
			ply:SetNWBool("TauntingSchemaMove", false)
			net.Start("DeActivateTauntCam")
			net.Send(ply)
		end)
	end
end)
concommand.Add("tf_taunt_woohoo", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end
	if ply:GetPlayerClass() != "demoman" then ply:ChatPrint("You're not demoman!") return end
	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end	
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/woohoo.vcd", 0)	
	ply:DoAnimationEvent(ACT_SIGNAL_GROUP, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	local animent2 = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
	animent2:SetModel("models/player/items/taunts/beer_crate/beer_crate.mdl") 
	animent2:SetAngles(ply:GetAngles())
	animent2:SetPos(ply:GetPos())
	animent2:Spawn()
	animent2:Activate()
	animent2:SetParent(ply)
	animent2:AddEffects(EF_BONEMERGE)
	animent2:SetName("BanjoModel"..ply:EntIndex())
	if ply:GetPlayerClass() == "merc_dm" then
		ply:EmitSound("vo/mercenary_laughevil01.wav", 80, 100)
		timer.Create("Laugh", 2, 1, function()
			if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
			ply:SetNWBool("Taunting", false)
			ply:SetNWBool("NoWeapon", false)
			net.Start("DeActivateTauntCam")
			net.Send(ply)
		end)
	else
		timer.Create("Laugh", time, 1, function()
			if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
			ply:SetNWBool("Taunting", false)
			ply:SetNWBool("NoWeapon", false)
			net.Start("DeActivateTauntCam")
			net.Send(ply)
			animent2:Fire("Kill", "", 0.01)
		end)
	end
end)
concommand.Add("tf_taunt_rip_rick_may_you_will_be_forever_missed", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end
	if ply:GetPlayerClass() != "soldier" then ply:ChatPrint("You're not Soldier!") return end
	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end	
	local time = ply:PlayScene("scenes/workshop/player/"..ply:GetPlayerClass().."/low/taunt_maggots_condolence.vcd", 0)	
	ply:DoAnimationEvent(ACT_BARNACLE_HIT, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	local animent2 = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
	animent2:SetModel("models/workshop/player/items/soldier/taunt_maggots_condolence/taunt_maggots_condolence.mdl") 
	animent2:SetAngles(ply:GetAngles())
	animent2:SetPos(ply:GetPos())
	animent2:Spawn()
	animent2:Activate()
	animent2:SetParent(ply)
	animent2:AddEffects(EF_BONEMERGE)
	animent2:SetName("BanjoModel"..ply:EntIndex())
	if ply:GetPlayerClass() == "merc_dm" then
		ply:EmitSound("vo/mercenary_laughevil01.wav", 80, 100)
		timer.Create("Laugh", 2, 1, function()
			if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
			ply:SetNWBool("Taunting", false)
			ply:SetNWBool("NoWeapon", false)
			net.Start("DeActivateTauntCam")
			net.Send(ply)
		end)
	else
		timer.Create("Laugh", time, 1, function()
			if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
			ply:SetNWBool("Taunting", false)
			ply:SetNWBool("NoWeapon", false)
			net.Start("DeActivateTauntCam")
			net.Send(ply)
			animent2:Fire("Kill", "", 0.01)
		end)
	end
end)
concommand.Add("tf_taunt_disco", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end	
	local time = ply:SequenceDuration(ACT_DOD_DEPLOYED)	
	ply:DoAnimationEvent(ACT_DOD_DEPLOYED, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	ply:EmitSound("player/taunt_disco.wav")
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Create("LoopAnimConga"..ply:EntIndex(), ply:SequenceDuration(ply:LookupSequence("disco_fever")), 1, function()
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end)
concommand.Add("tf_taunt_conga_start", function(ply)
	if ply:GetNWBool("NoWeapon") == true then return end
	
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
		if (!ply:IsHL2()) then
			ply:DoAnimationEvent(ACT_DOD_CROUCHWALK_IDLE_PISTOL, false)
		else
			ply:DoAnimationEvent(ACT_GMOD_TAUNT_DANCE, false)
		end
	ply:EmitSound("music.conga_loop")	
	if (!ply:IsHL2()) then
		ParticleEffectAttach("speech_taunt_all", PATTACH_POINT_FOLLOW,ply,ply:LookupAttachment("head"))
	end
	local time 
	if ply:IsHL2() then
		time = ply:PlayScene("scenes/player/sniper/low/conga.vcd", 0)		
	else
		time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/conga.vcd", 0)		
	end 
	timer.Create("LoopSlowTauntSpeed"..ply:EntIndex(), 0.01, 0, function()
		ply:SetClassSpeed(3 * 25)
	end)
	timer.Create("LoopTauntSpeakingConga"..ply:EntIndex(), 5, 0, function()
		if ply:GetNWBool("NoWeapon") == false then timer.Stop("LoopAnimConga"..ply:EntIndex()) timer.Stop("LoopSlowTauntSpeed"..ply:EntIndex()) timer.Stop("LoopTauntSpeakingConga"..ply:EntIndex()) return end
	end)
	ply:SetNWBool("NoWeapon", true)
	ply:SetNWBool("Bonked", true)
	ply:SetNWBool("Congaing", true)
	ply:ConCommand("tf_tp_simulation_toggle ")
	net.Send(ply)
	
	timer.Create("LoopAnimCongaHL2"..ply:EntIndex(), ply:SequenceDuration(ply:SelectWeightedSequence(ACT_GMOD_TAUNT_DANCE)), 0, function()
	
		if (ply:IsHL2()) then
			ply:DoAnimationEvent(ACT_GMOD_TAUNT_DANCE, false)
		end
		
	end)
	timer.Create("LoopAnimConga"..ply:EntIndex(), time, 0, function()
		if (!ply:IsHL2()) then
			ply:DoAnimationEvent(ACT_DOD_CROUCHWALK_IDLE_PISTOL, false)
		end
		ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/conga.vcd", 0)	
		if ply:IsHL2() then
			ply:PlayScene("scenes/player/sniper/low/conga.vcd", 0)		
		else
			ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/conga.vcd", 0)		
		end
	end)
end)
concommand.Add("tf_taunt_conga_stop", function(ply)
	if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("NoWeapon")) then return end
	ply:SetNWBool("NoWeapon", false)
	ply:SetNWBool("Bonked", false)
	ply:SetNWBool("Congaing", false)
	ply:StopSound("music.conga_loop")	
	ply:DoTauntEvent("a_flinch01", true)
	ply:StopParticles()
	timer.Stop("LoopAnimConga"..ply:EntIndex()) 
	timer.Stop("LoopAnimCongaHL2"..ply:EntIndex()) 
	timer.Stop("LoopSlowTauntSpeed"..ply:EntIndex()) 
	timer.Stop("LoopTauntSpeakingConga"..ply:EntIndex())
	ply:ConCommand("tf_firstperson")
	ply:ResetClassSpeed()
	net.Send(ply)
	ply:SetColor( Color( 255, 255, 255, 0 ) ) 
end)
concommand.Add("tf_taunt_russian_start", function(ply)
	if ply:GetNWBool("Taunting2") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	ply:DoAnimationEvent(ACT_DI_ALYX_ZOMBIE_TORSO_MELEE, false)
	ply:EmitSound("music.russian")
	ParticleEffectAttach("speech_taunt_all", PATTACH_POINT_FOLLOW,ply,ply:LookupAttachment("head")) 
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_russian.vcd", 0)
	timer.Create("LoopSlowTauntSpeed2"..ply:EntIndex(), 0.01, 0, function()
		ply:SetClassSpeed(50)
	end)
	timer.Create("LoopTauntSpeakingConga2"..ply:EntIndex(), 0.001, 0, function()
		if ply:GetNWBool("NoWeapon") == false then timer.Stop("LoopAnimRussian"..ply:EntIndex()) timer.Stop("LoopSlowTauntSpeed2"..ply:EntIndex()) timer.Stop("LoopTauntSpeakingConga2"..ply:EntIndex()) timer.Stop("LoopMusic"..ply:EntIndex()) return end
	end)
	ply:SetNWBool("NoWeapon", true)
	ply:SetNWBool("Bonked", true)
	ply:SetNWBool("Taunting2", true)
	ply:SetNWBool("Russian", true)
	ply:ConCommand("tf_tp_simulation_toggle")
	net.Send(ply)
	timer.Create("LoopMusic"..ply:EntIndex(), 66.24, 0, function()
	end)
	timer.Create("LoopAnimRussian"..ply:EntIndex(), ply:SequenceDuration(ply:LookupSequence("taunt_russian")) - 0.1, 0, function()
		ply:DoAnimationEvent(ACT_DI_ALYX_ZOMBIE_TORSO_MELEE, false)
		ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_russian.vcd", 0)
	end)
end)
concommand.Add("tf_taunt_russian_stop", function(ply)
	if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("NoWeapon")) then return end
	ply:SetNWBool("NoWeapon", false)
	ply:SetNWBool("Bonked", false)
	ply:SetNWBool("Taunting2", false)
	ply:SetNWBool("Russian", false)
	ply:StopSound("music.russian")
	ply:DoTauntEvent("a_flinch01", true)
	ply:StopParticles()
	ply:ResetClassSpeed()
	ply:ConCommand("tf_firstperson")
	timer.Stop("LoopAnimRussian"..ply:EntIndex())
	timer.Stop("LoopSlowTauntSpeed2"..ply:EntIndex())
	timer.Stop("LoopTauntSpeakingConga2"..ply:EntIndex())
	timer.Stop("LoopMusic"..ply:EntIndex())

	net.Send(ply)
end)
concommand.Add("tf_taunt_banjo_start", function(ply)
	ply:ConCommand("tf_taunt_schema 30842")
end)
concommand.Add("tf_taunt_chair", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:GetNWBool("Taunting2") == true then return end
	if ply:GetPlayerClass() != "spy" then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	ply:DoAnimationEvent(ACT_WALK_CROUCH_AIM, false)
	ply:DoAnimationEvent(ACT_WALK_CROUCH_AIM, false)
	local time = ply:SequenceDuration(ply:LookupSequence("taunt_luxury_lounge"))
	timer.Create("LoopAnimBanjo2"..ply:EntIndex(), 0.001, 0, function()
		if ply:GetNWBool("Taunting") == false then timer.Stop("LoopAnimBook"..ply:EntIndex()) timer.Stop("LoopAnimBanjo2"..ply:EntIndex()) timer.Stop("LoopTauntSpeakingConga2"..ply:EntIndex()) timer.Stop("LoopMusic"..ply:EntIndex()) return end
	end)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	ply:SetNWBool("Taunting2", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	local animent2 = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
	animent2:SetModel("models/workshop/player/items/spy/taunt_luxury_lounge/taunt_luxury_lounge.mdl") 
	animent2:SetAngles(ply:GetAngles())
	animent2:SetPos(ply:GetPos())
	animent2:Spawn()
	animent2:SetSkin(ply:GetSkin())
	animent2:Activate()
	animent2:SetParent(ply)
	animent2:AddEffects(EF_BONEMERGE)
	animent2:SetName("BanjoModel"..ply:EntIndex())
	timer.Create("LoopAnimBook"..ply:EntIndex(), 27, 0, function()
		ply:DoAnimationEvent(ACT_WALK_CROUCH_AIM, false)
	end)
end)
concommand.Add("tf_taunt_weight", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:GetNWBool("Taunting2") == true then return end
	if ply:GetPlayerClass() != "heavy" then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local npc = ents.Create("base_entity")
	npc:SetPos(ply:GetPos())
	npc:SetAngles(ply:GetAngles())
	npc:Spawn()
	npc:Activate()
	npc:SetName("Heavy")
	npc:ResetSequence("taunt_soviet_strongarm_intro_loop")
	npc:SetModel("models/player/heavy.mdl")
	local time = npc:PlayScene("scenes/workshop/player/heavy/low/taunt_soviet_strongarm.vcd", 0)
	timer.Create("LoopAnimBanjo2"..ply:EntIndex(), 0.001, 0, function()
		if ply:GetNWBool("Taunting") == false then timer.Stop("LoopAnimBook"..ply:EntIndex()) timer.Stop("LoopAnimBanjo2"..ply:EntIndex()) timer.Stop("LoopTauntSpeakingConga2"..ply:EntIndex()) timer.Stop("LoopMusic"..ply:EntIndex()) return end
	end)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("Taunting2", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)

	local animent2 = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
	animent2:SetModel("models/workshop/player/items/heavy/taunt_soviet_strongarm/taunt_soviet_strongarm.mdl") 
	animent2:SetAngles(npc:GetAngles())
	animent2:SetPos(npc:GetPos())
	animent2:Spawn()
	animent2:SetSkin(npc:GetSkin())
	animent2:Activate()
	animent2:SetParent(npc)
	animent2:AddEffects(EF_BONEMERGE)
	animent2:SetName("BanjoModel"..ply:EntIndex())
	timer.Create("LoopAnimBook"..ply:EntIndex(), time, 0, function()
		ply:DoAnimationEvent(ACT_WALK_CROUCH_AIM, false)
	end)
end)
concommand.Add("tf_taunt_chair2", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:GetNWBool("Taunting2") == true then return end
	if ply:GetPlayerClass() != "engineer" then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	ply:DoAnimationEvent(ACT_FLY, false)
	local time = ply:SequenceDuration(ply:LookupSequence("taunt_luxury_lounge"))
	timer.Create("LoopAnimBanjo2"..ply:EntIndex(), 0.001, 0, function()
		if ply:GetNWBool("Taunting") == false then timer.Stop("LoopAnimBook"..ply:EntIndex()) timer.Stop("LoopAnimBanjo2"..ply:EntIndex()) timer.Stop("LoopTauntSpeakingConga2"..ply:EntIndex()) timer.Stop("LoopMusic"..ply:EntIndex()) return end
	end)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("Taunting2", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	local animent2 = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
	animent2:SetModel("models/player/items/taunts/engys_new_chair/engys_new_chair_articlulated.mdl") 
	animent2:SetAngles(ply:GetAngles())
	animent2:SetPos(ply:GetPos())
	animent2:SetSkin(ply:GetSkin())
	animent2:Spawn()
	animent2:Activate()
	animent2:ResetSequence("chair_intro_qcistyle")
	animent2.AutomaticFrameAdvance = true
	animent2:SetPlaybackRate(1)
	animent2:SetName("BanjoModel"..ply:EntIndex()) 
	function animent2:Think() -- This makes the animation work
		self:NextThink( CurTime() )
		return true
	end
		ply:EmitSound("vo/taunts/engy/taunt_engineer_lounge_button_press.mp3")
		timer.Simple(0.2, function()
			ply:EmitSound("vo/taunts/engy/taunt_engineer_lounge_toolbox_open.mp3")
		end)
		timer.Simple(4.3, function()
			ply:EmitSound("engy_taunt_killertime_4_drink")
		end)
		timer.Simple(11.5, function()
			ply:EmitSound("engy_taunt_killertime_4_2_drink_long")
		end)
		timer.Simple(23, function()
			ply:EmitSound("vo/taunts/demo/taunt_demo_burp_03.mp3")
		end)
		timer.Simple(24.3, function()
			ply:EmitSound("vo/taunts/engy/eng_guzzle_05.wav")
		end)
	animent2:SetName("BanjoModel"..ply:EntIndex())
	timer.Create("LoopAnimBook"..ply:EntIndex(), 28, 0, function()
		ply:DoAnimationEvent(ACT_FLY, false)
		animent2:SetCycle(0)
		ply:EmitSound("vo/taunts/engy/taunt_engineer_lounge_button_press.mp3")
		timer.Simple(0.2, function()
			ply:EmitSound("vo/taunts/engy/taunt_engineer_lounge_toolbox_open.mp3")
		end)
		timer.Simple(4.3, function()
			ply:EmitSound("vo/taunts/engy/eng_guzzle_02.wav")
		end)
		timer.Simple(11.5, function()
			ply:EmitSound("vo/taunts/engy/eng_guzzle_06.wav")
		end)
		timer.Simple(23, function()
			ply:EmitSound("vo/taunts/demo/taunt_demo_burp_03.mp3")
		end)
		timer.Simple(24.3, function()
			ply:EmitSound("vo/taunts/engy/eng_guzzle_05.wav")
		end)
	end)
end)


concommand.Add("tf_taunt_pyro_partytrick", function(ply)
	if ply:GetNWBool("Taunting2") == true then return end
	if ply:GetNWBool("Taunting2") == true then return end
	if ply:GetPlayerClass() != "pyro" then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	ply:DoAnimationEvent(ACT_WALK_SCARED, false)
	local time = ply:PlayScene("scenes/player/pyro/low/taunt_party_trick.vcd", 0)
	timer.Simple(1.5, function()
		ply:EmitSound("player/taunt_party_trick.wav", 80, 100)
	end)
	timer.Create("LoopAnimBanjo2"..ply:EntIndex(), 0.001, 0, function()
		if ply:GetNWBool("NoWeapon") == false then timer.Stop("LoopAnimBanjo"..ply:EntIndex()) timer.Stop("LoopAnimBanjo2"..ply:EntIndex()) timer.Stop("LoopTauntSpeakingConga2"..ply:EntIndex()) timer.Stop("LoopMusic"..ply:EntIndex()) return end
	end)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	local animent2 = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
	animent2:SetModel("models/player/items/taunts/balloon_animal_pyro/balloon_animal_pyro.mdl") 
	animent2:SetAngles(ply:GetAngles())
	animent2:SetPos(ply:GetPos())
	animent2:Spawn()
	animent2:Activate()
	animent2:SetParent(ply)
	animent2:AddEffects(EF_BONEMERGE)
	animent2:SetName("BanjoModel"..ply:EntIndex())
	timer.Create("LoopAnimBanjo"..ply:EntIndex(), time - 0.5, 1, function()
		for k,v in ipairs(ents.FindByName("BanjoModel"..ply:EntIndex())) do
			v:Remove()
			ply:SetNWBool("NoWeapon", false)
			ply:SetNWBool("Taunting", false)
			net.Start("DeActivateTauntCam")
			net.Send(ply)	
		end
	end)
end)


concommand.Add("tf_taunt_introduction", function(ply)
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	if ply:GetPlayerClass() == "soldier" then
		ply:DoAnimationEvent(ACT_DOD_PRIMARYATTACK_BOLT, false)
		ply:SetNWBool("Taunting", true)
		net.Start("ActivateTauntCam")
		net.Send(ply)
		timer.Create("LoopAnimBanjo"..ply:EntIndex(), ply:SequenceDuration(ply:LookupSequence("selectionMenu_Anim0l")), 1, function()
			ply:SetNWBool("Taunting", false)
			net.Start("DeActivateTauntCam")
			net.Send(ply)	
		end)
	else
		ply:DoAnimationEvent(ACT_DOD_RELOAD_PRONE_DEPLOYED, false)
		ply:SetNWBool("Taunting", true)
		net.Start("ActivateTauntCam")
		net.Send(ply)
		timer.Create("LoopAnimBanjo"..ply:EntIndex(), ply:SequenceDuration(ply:LookupSequence("selectionMenu_Anim01")), 1, function()
			ply:SetNWBool("Taunting", false)
			net.Start("DeActivateTauntCam")
			net.Send(ply)	
		end)
	end
end)
concommand.Add("tf_taunt_banjo_stop", function(ply)
	if TF_EndSchemaTaunt then
		TF_EndSchemaTaunt(ply)
	end
end)
concommand.Add("tf_taunt_chair_stop", function(ply)
	if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("NoWeapon")) then return end
	ply:ResetClassSpeed()
	ply:DoAnimationEvent(ACT_RUN_CROUCH_AIM)
	ply:SetNWBool("Taunting2", false)
	timer.Simple(3.2, function()
		for k,v in ipairs(ents.FindByName("BanjoModel"..ply:EntIndex())) do
			v:Remove()
			ply:SetNWBool("NoWeapon", false)
			ply:SetNWBool("Taunting", false)
			net.Start("DeActivateTauntCam")
			net.Send(ply)	
		end
	end)
end)
concommand.Add("tf_taunt_weight_stop", function(ply)
	if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("NoWeapon")) then return end
	ply:ResetClassSpeed()
	ply:SetNWBool("Taunting2", false)
		for k,v in ipairs(ents.FindByName("BanjoModel"..ply:EntIndex())) do
			v:Remove()
			ply:SetNWBool("NoWeapon", false)
			ply:SetNWBool("Taunting", false)
			net.Start("DeActivateTauntCam")
			net.Send(ply)	
		end
		for k,v in ipairs(ents.FindByName("Heavy")) do
			v:Remove()
		end
end)
concommand.Add("tf_taunt_chair2_stop", function(ply)
	if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("NoWeapon")) then return end
	ply:ResetClassSpeed()
	ply:SetNWBool("Taunting2", false)
		for k,v in ipairs(ents.FindByName("BanjoModel"..ply:EntIndex())) do
			v:Remove()
			ply:SetNWBool("NoWeapon", false)
			ply:SetNWBool("Taunting", false)
			net.Start("DeActivateTauntCam")
			net.Send(ply)	
		end
end)
concommand.Add("tf_taunt_thriller", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt06.vcd", 0)
	ply:DoAnimationEvent(ACT_DOD_CROUCH_IDLE_TOMMY, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end)
concommand.Add("tf_taunt_gimme20", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end
	if ply:GetPlayerClass() != "soldier" then ply:ChatPrint("You're not Soldier!") return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:SequenceDuration(ply:LookupSequence("taunt_gimmie20"))
	timer.Simple(0.5, function()
		ply:EmitSound("Soldier.Jeers08")
	end)
	ply:DoTauntEvent("taunt_gimmie20")
	ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
	ply:SetNWBool("Taunting", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end)
concommand.Add("tf_taunt_slit_throat", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end
	if ply:GetPlayerClass() != "soldier" then ply:ChatPrint("You're not Soldier!") return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:SequenceDuration(ply:LookupSequence("taunt_slit_throat"))
	timer.Simple(1.4, function()
		ply:EmitSound("Selection.HeavyClothesRustle")
	end)
	ply:DoTauntEvent("taunt_slit_throat")
	ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
	ply:SetNWBool("Taunting", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end)
concommand.Add("tf_taunt_come_and_get_me", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end
	if ply:GetPlayerClass() != "scout" then ply:ChatPrint("You're not Scout!") return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:SequenceDuration(ply:LookupSequence("taunt_come_and_get_me"))
	ply:PlayScene("scenes/player/scout/low/taunt07_vocal0"..math.random(1,5)..".vcd", 0)
	ply:DoTauntEvent("taunt_come_and_get_me")
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end)
concommand.Add("tf_taunt_directors_vision", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end
	local act = ACT_BARNACLE_PULL
	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_replay.vcd", 0)
	if (ply:GetPlayerClass() == "pyro") then
		if (math.random(1,3) == 2) then
			time = ply:PlayScene("scenes/player/pyro/low/taunt_replay2.vcd", 0)
			ply:DoTauntEvent("pyro_taunt_replay2")
		else
			ply:DoTauntEvent("pyro_taunt_replay")
		end
	else
		if (ply:LookupSequence(ply:GetPlayerClass().."_taunt_replay") == -1) then
			ply:DoTauntEvent("taunt_replay")
		else
			ply:DoTauntEvent(ply:GetPlayerClass().."_taunt_replay")
		end
	end
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end)
concommand.Add("tf_taunt_yeti", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/yeti_taunt.vcd", 0)
	ply:DoAnimationEvent(ACT_RUN_PROTECTED, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	local animent2 = ents.Create( 'base_gmodentity' ) -- The entity used for the taunt
	animent2:SetModel("models/player/items/taunts/yeti/yeti.mdl") 
	animent2:SetModelScale(ply:GetModelScale())
	animent2:SetAngles(Angle(ply:GetAngles().x, ply:GetAngles().y, 0))
	animent2:SetPos(ply:GetPos())
	animent2:Spawn()
	animent2:Activate()
	animent2.AutomaticFrameAdvance = true
	animent2:ResetSequence("taunt_yeti")
	animent2:SetPlaybackRate(1)
	animent2:SetName("BanjoModel"..ply:EntIndex()) 
	function animent2:Think() -- This makes the animation work
		self:NextThink( CurTime() )
		return true
	end
	ply:SetColor( Color( 255, 255, 255, 0 ) ) 
	ply:SetRenderMode( RENDERMODE_TRANSALPHA ) 
	timer.Simple(0.8, function()
		timer.Create("ChestThump", 0.01, 5, function()
			local mad = animent2:GetFlexIDByName("AH")
			animent2:SetFlexWeight(mad, animent2:GetFlexWeight(mad) + 0.08/1)
				local mad2 = animent2:GetFlexIDByName("mad")
				animent2:SetFlexWeight(mad2, animent2:GetFlexWeight(mad2) + 0.2/1)
		end)
		timer.Simple(0.5, function()
			timer.Create("ChestThump", 0.01, 5, function()
				local mad = animent2:GetFlexIDByName("AH")
				animent2:SetFlexWeight(mad, animent2:GetFlexWeight(mad) - 0.1/1)
				local mad2 = animent2:GetFlexIDByName("mad")
				animent2:SetFlexWeight(mad2, animent2:GetFlexWeight(mad2) /1)
			end)
		end)
	end)
	timer.Simple(1.8, function()
		timer.Create("ChestThump2", 0.01, 20, function()
			local mad = animent2:GetFlexIDByName("mad")
			animent2:SetFlexWeight(mad, animent2:GetFlexWeight(mad) + 0.08/1)
		end)
		timer.Create("ChestThump", 0.01, 5, function()
			local mad = animent2:GetFlexIDByName("AH")
			animent2:SetFlexWeight(mad, animent2:GetFlexWeight(mad) + 0.08/1)
		end)
		timer.Simple(1.5, function()
			timer.Create("ChestThump", 0.01, 5, function()
				local mad = animent2:GetFlexIDByName("AH")
				animent2:SetFlexWeight(mad, animent2:GetFlexWeight(mad) - 0.1/1)
			end)
		end)
	end)
	timer.Simple(4, function()
		timer.Create("ChestThump3", 0.01, 20, function()
			local mad = animent2:GetFlexIDByName("mad")
			animent2:SetFlexWeight(mad, animent2:GetFlexWeight(mad) - 0.1/1)
			local roar = animent2:GetFlexIDByName("actionfire02")
			animent2:SetFlexWeight(roar, animent2:GetFlexWeight(roar) + 0.1/1)
		end)
	end)
	timer.Simple(5.4, function()
		animent2:Remove()
		ply:SetColor( Color( 255, 255, 255, 255 ) ) 
		ply:SetRenderMode( RENDERMODE_NORMAL ) 
	end)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end)
concommand.Add("tf_taunt_yetipunch", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_yetipunch.vcd", 0)
	ply:DoAnimationEvent(ACT_BARNACLE_CHOMP, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end)
concommand.Add("tf_taunt_highfive", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_highfivesuccess.vcd", 0)	
	if not ply:GetPlayerClass() == "spy" or ply:GetPlayerClass() == "engineer" then
		ply:DoAnimationEvent(ACT_DOD_STAND_ZOOM_BOLT, true)
	else
		ply:DoAnimationEvent(ACT_DOD_CROUCH_ZOOM_BOLT, true)
	end
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	ply:EmitSound("misc/high_five.wav")
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
	for k,v in pairs(ents.FindInSphere(ply:GetPos(), 120) ) do 
		if v:IsPlayer() then
			if v:GetNWBool("Taunting") == true then return end
			if v:IsHL2() then v:ConCommand("act laugh") return end
			if not v:IsOnGround() then return end
			if v:WaterLevel() ~= 0 then return end
			if v:GetInfoNum("tf_robot", 0) == 1 then v:ChatPrint("You can't taunt as a robot!") return end
			if v:GetInfoNum("tf_giantrobot", 0) == 1 then v:ChatPrint("You can't taunt as a mighty robot!") return end
			local time = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/taunt_highfivesuccess.vcd", 0)
			v:DoAnimationEvent(ACT_DOD_STAND_ZOOM_BOLT, true)
			v:SetNWBool("Taunting", true)
			v:SetNWBool("NoWeapon", true)
			net.Start("ActivateTauntCam")
			net.Send(v)
			timer.Simple(time, function()
				if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
				v:SetNWBool("Taunting", false)
				v:SetNWBool("NoWeapon", false)
				net.Start("DeActivateTauntCam")
				net.Send(v)
			end)
		end
		if v:IsBot() then
			if v:GetNWBool("Taunting") == true then return end
			if v:IsHL2() then v:ConCommand("act laugh") return end
			if not v:IsOnGround() then return end
			if v:WaterLevel() ~= 0 then return end
			if v:GetInfoNum("tf_robot", 0) == 1 then v:ChatPrint("You can't taunt as a robot!") return end
			if v:GetInfoNum("tf_giantrobot", 0) == 1 then v:ChatPrint("You can't taunt as a mighty robot!") return end
			local time = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/taunt_highfivesuccess.vcd", 0)
			v:DoAnimationEvent(ACT_DOD_STAND_ZOOM_BOLT, true)
			v:SetNWBool("Taunting", true)
			v:SetNWBool("NoWeapon", true)
			net.Start("ActivateTauntCam")
			net.Send(v)
			timer.Simple(time, function()
				if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
				v:SetNWBool("Taunting", false)
				v:SetNWBool("NoWeapon", false)
				net.Start("DeActivateTauntCam")
				net.Send(v)
			end)
		end
		if v.Base == "npc_tf2base" or v.Base == "npc_soldier_red" or v.Base == "npc_hwg_red" or v.Base == "npc_pyro_red" or v.Base == "npc_scout_red" then
			if v:GetNWBool("Taunting") == true then return end
			local time = v:PlayScene("scenes/player/"..v.TF2Class.."/low/taunt_highfivesuccess.vcd", 0)
			v:SetCycle(0)
			v:ResetSequence("taunt_hifivesuccess")
			v:SetNWBool("Taunting", true)
			v:SetNWBool("NoWeapon", true)
			timer.Simple(time, function()
				if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
				v:SetNWBool("Taunting", false)
				v:SetNWBool("NoWeapon", false)
				net.Start("DeActivateTauntCam")
				net.Send(v)
			end)
		end
	end
end)
concommand.Add("tf_taunt_highfive_fail", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_hifivefailfull.vcd", 0)	
	if not ply:GetPlayerClass() == "spy" or ply:GetPlayerClass() == "engineer" then
		ply:DoAnimationEvent(ACT_DOD_STAND_ZOOM_BOLT, true)
	else
		ply:DoAnimationEvent(ACT_DOD_CROUCH_ZOOM_BOLT, true)
	end
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	ply:EmitSound("misc/high_five.wav")
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
	for k,v in pairs(ents.FindInSphere(ply:GetPos(), 120) ) do 
		if v:IsPlayer() then
			if v:GetNWBool("Taunting") == true then return end
			if v:IsHL2() then v:ConCommand("act laugh") return end
			if not v:IsOnGround() then return end
			if v:WaterLevel() ~= 0 then return end
			if v:GetInfoNum("tf_robot", 0) == 1 then v:ChatPrint("You can't taunt as a robot!") return end
			if v:GetInfoNum("tf_giantrobot", 0) == 1 then v:ChatPrint("You can't taunt as a mighty robot!") return end
			local time = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/taunt_highfivefailfull.vcd", 0)
			v:DoAnimationEvent(ACT_DOD_STAND_ZOOM_BOLT, true)
			v:SetNWBool("Taunting", true)
			v:SetNWBool("NoWeapon", true)
			net.Start("ActivateTauntCam")
			net.Send(v)
			timer.Simple(time, function()
				if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
				v:SetNWBool("Taunting", false)
				v:SetNWBool("NoWeapon", false)
				net.Start("DeActivateTauntCam")
				net.Send(v)
			end)
		end
		if v:IsBot() then
			if v:GetNWBool("Taunting") == true then return end
			if v:IsHL2() then v:ConCommand("act laugh") return end
			if not v:IsOnGround() then return end
			if v:WaterLevel() ~= 0 then return end
			if v:GetInfoNum("tf_robot", 0) == 1 then v:ChatPrint("You can't taunt as a robot!") return end
			if v:GetInfoNum("tf_giantrobot", 0) == 1 then v:ChatPrint("You can't taunt as a mighty robot!") return end
			local time = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/taunt_highfivefailfull.vcd", 0)
			v:DoAnimationEvent(ACT_DOD_STAND_ZOOM_BOLT, true)
			v:SetNWBool("Taunting", true)
			v:SetNWBool("NoWeapon", true)
			net.Start("ActivateTauntCam")
			net.Send(v)
			timer.Simple(time, function()
				if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
				v:SetNWBool("Taunting", false)
				v:SetNWBool("NoWeapon", false)
				net.Start("DeActivateTauntCam")
				net.Send(v)
			end)
		end
		if v.Base == "npc_tf2base" or v.Base == "npc_soldier_red" or v.Base == "npc_hwg_red" or v.Base == "npc_pyro_red" or v.Base == "npc_scout_red" then
			if v:GetNWBool("Taunting") == true then return end
			local time = v:PlayScene("scenes/player/"..v.TF2Class.."/low/taunt_highfivefailfull.vcd", 0)
			v:SetCycle(0)
			v:ResetSequence("taunt_hifivesuccess")
			v:SetNWBool("Taunting", true)
			v:SetNWBool("NoWeapon", true)
			timer.Simple(time, function()
				if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
				v:SetNWBool("Taunting", false)
				v:SetNWBool("NoWeapon", false)
				net.Start("DeActivateTauntCam")
				net.Send(v)
			end)
		end
	end
end)
concommand.Add("tf_taunt_skullcracker", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_headbutt_success.vcd", 0)
	ply:DoAnimationEvent(ACT_DOD_RUN_IDLE_MG, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
	for k,v in pairs(ents.FindInSphere(ply:GetPos(), 120) ) do 
		if v:IsPlayer() then
			if v:IsHL2() then v:ConCommand("act laugh") return end
			if not v:IsOnGround() then return end
			if v:WaterLevel() ~= 0 then return end
			if v:GetInfoNum("tf_robot", 0) == 1 then v:ChatPrint("You can't taunt as a robot!") return end
			if v:GetInfoNum("tf_giantrobot", 0) == 1 then v:ChatPrint("You can't taunt as a mighty robot!") return end
			local time = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/taunt_headbutt_success.vcd", 0)
			v:DoAnimationEvent(ACT_DOD_RUN_IDLE_MG, true)
			v:SetNWBool("Taunting", true)
			v:SetNWBool("NoWeapon", true)
			net.Start("ActivateTauntCam")
			net.Send(v)
			timer.Simple(time, function()
				if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
				v:SetNWBool("Taunting", false)
				v:SetNWBool("NoWeapon", false)
				net.Start("DeActivateTauntCam")
				net.Send(v)
			end)
		end
	end
end)
concommand.Add("tf_taunt_robot_stun", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end
	if ply:GetInfoNum("tf_robot", 0) == 0 and ply:GetInfoNum("tf_giantrobot", 0) == 0 then ply:ChatPrint("You can't use this command as a human!") return end
	ply:EmitSound("mvm/mvm_robo_stun.wav", 95, 100)
	timer.Create("StunRobot25", 0.001, 1, function()
		ply:DoAnimationEvent(ACT_MP_STUN_BEGIN,2)
		timer.Create("StunRobotloop3", 0.5, 0, function()
			if not ply:Alive() then timer.Stop("StunRobotloop") return end
			timer.Create("StunRobotloop4", 0.22, 0, function()
				if not ply:Alive() then timer.Stop("StunRobotloop4") return end
				ply:DoAnimationEvent(ACT_MP_STUN_MIDDLE,2)
			end)
		end)
	end)
	ply:DoAnimationEvent(ACT_DOD_SECONDARYATTACK_BOLT, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(23, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:EmitSound("misc/cp_harbor_red_whistle.wav", 95, 100)
		timer.Stop("StunRobotloop3")
		timer.Stop("StunRobotloop4")
		ply:DoAnimationEvent(ACT_MP_STUN_END,2)
		timer.Simple(1, function()
			ply:SetNWBool("Taunting", false)
			ply:SetNWBool("NoWeapon", false)
			net.Start("DeActivateTauntCam")
			net.Send(ply)
		end)
	end)
	for k,v in pairs(ents.FindInSphere(ply:GetPos(), 200) ) do	
		if v:GetNWBool("Taunting") == true then return end
		if v:IsHL2() then v:ConCommand("act laugh") return end
		if not v:IsOnGround() then return end
		if v:WaterLevel() ~= 0 then return end
		if v:GetInfoNum("tf_robot", 0) == 0 and v:GetInfoNum("tf_giantrobot", 0) == 0 then v:ChatPrint("You can't use this command as a human!") return end
		v:EmitSound("mvm/mvm_robo_stun.wav", 95, 100)
		timer.Create("StunRobot4", 0.001, 1, function()
			v:DoAnimationEvent(ACT_MP_STUN_BEGIN,2)
			timer.Create("StunRobotloop5", 0.5, 0, function()
				if not v:Alive() then timer.Stop("StunRobotloop") return end
				timer.Create("StunRobotloop6", 0.22, 0, function()
					if not v:Alive() then timer.Stop("StunRobotloop4") return end
					v:DoAnimationEvent(ACT_MP_STUN_MIDDLE,2)
				end)
			end)
		end)
		v:DoAnimationEvent(ACT_DOD_SECONDARYATTACK_BOLT, true)
		v:SetNWBool("Taunting", true)
		v:SetNWBool("NoWeapon", true)
		net.Start("ActivateTauntCam")
		net.Send(v)
		timer.Simple(23, function()
			if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
			v:EmitSound("misc/cp_harbor_red_whistle.wav", 95, 100)
			timer.Stop("StunRobotloop3")
			timer.Stop("StunRobotloop4")
			v:DoAnimationEvent(ACT_MP_STUN_END,2)
			timer.Simple(1, function()
				v:SetNWBool("Taunting", false)
				v:SetNWBool("NoWeapon", false)
				net.Start("DeActivateTauntCam")
				net.Send(v)
			end)
		end)
	end
end)
concommand.Add("tf_stun_me", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end
	ply:EmitSound("TFPlayer.StunImpact")
	timer.Create("StunRobot25"..ply:EntIndex(), 0.001, 1, function()
		ply:DoAnimationEvent(ACT_MP_STUN_BEGIN,2)
			timer.Create("StunRobotloop4"..ply:EntIndex(), 0.8, 6, function()
				ply:DoAnimationEvent(ACT_MP_STUN_MIDDLE,2)
			end)
	end) 
	ply:DoAnimationEvent(ACT_DOD_SECONDARYATTACK_BOLT, true)
	ply:SetNWBool("Taunting", true)  
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(5, function()
		if not IsValid(ply) then return end
		timer.Stop("StunRobotloop3"..ply:EntIndex())
		timer.Stop("StunRobotloop4"..ply:EntIndex())
		ply:DoAnimationEvent(ACT_MP_STUN_END,2)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
	end)
end)
concommand.Add("tf_taunt_flipping_start", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/flip_success_initiator0.vcd", 0)
	ply:DoAnimationEvent(ACT_DOD_SECONDARYATTACK_BOLT, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
	timer.Simple(0.1, function()
	for k,v in pairs(ents.FindInSphere(ply:GetPos(), 120) ) do 
		if v:IsPlayer() and v:Nick() != ply:Nick() then
			if v:GetInfoNum("tf_robot", 0) == 1 then v:ChatPrint("You can't taunt as a robot!") return end
			if v:GetInfoNum("tf_giantrobot", 0) == 1 then v:ChatPrint("You can't taunt as a mighty robot!") return end
			local time = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/flip_success_receiver0.vcd", 0)
			v:DoAnimationEvent(ACT_DOD_PRIMARYATTACK_PRONE_BOLT, true)
			v:SetNWBool("Taunting", true)
			v:SetNWBool("NoWeapon", true)
			net.Start("ActivateTauntCam")
			net.Send(v)
			timer.Simple(time, function()
				if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
				v:SetNWBool("Taunting", false)
				v:SetNWBool("NoWeapon", false)
				net.Start("DeActivateTauntCam")
				net.Send(v)
			end)
		end
	end
	end)
end)
concommand.Add("tf_taunt_heroric", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end
	if ply:GetPlayerClass() != "medic" then 
		ply:ChatPrint("You're not medic!")
		return 
	end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/medic/low/taunt09.vcd", 0)
	ply:DoAnimationEvent(ACT_DOD_STAND_AIM_KNIFE, true)
	ply:EmitSound("player/taunt_medic_heroic.wav", 90, 100)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end)
concommand.Add("tf_taunt_highfive_success", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_highfivesuccessfull.vcd", 0)
	if ply:GetPlayerClass() != "spy" and ply:GetPlayerClass() != "engineer" then
		ply:DoAnimationEvent(ACT_DOD_CROUCHWALK_ZOOM_BOLT, true) 
	else
		ply:DoAnimationEvent(ACT_DOD_WALK_ZOOM_BOLT, true)
	end
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	ply:EmitSound("misc/high_five.wav")
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
	for k,v in pairs(ents.FindInSphere(ply:GetPos(), 120) ) do 
		if v:IsPlayer() and v:Nick() != ply:Nick() then
			if v:IsHL2() then v:ConCommand("act laugh") return end
			if v:WaterLevel() ~= 0 then return end
			if v:GetInfoNum("tf_robot", 0) == 1 then v:ChatPrint("You can't taunt as a robot!") return end
			if v:GetInfoNum("tf_giantrobot", 0) == 1 then v:ChatPrint("You can't taunt as a mighty robot!") return end
			local time = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/taunt_highfivesuccessfull.vcd", 0)
			if not v:GetPlayerClass() != "spy" and ply:GetPlayerClass() != "engineer" then
				v:DoAnimationEvent(ACT_DOD_CROUCHWALK_ZOOM_BOLT, true)
			else
				v:DoAnimationEvent(ACT_DOD_WALK_ZOOM_BOLT, true)
			end
			v:SetNWBool("Taunting", true)
			v:SetNWBool("NoWeapon", true)
			net.Start("ActivateTauntCam")
			net.Send(v)
			timer.Simple(time, function()
				if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
				v:SetNWBool("Taunting", false)
				v:SetNWBool("NoWeapon", false)
				net.Start("DeActivateTauntCam")
				net.Send(v)
			end)
		end
		if v.Base == "npc_tf2base" or v.Base == "npc_soldier_red" or v.Base == "npc_hwg_red" or v.Base == "npc_pyro_red" or v.Base == "npc_scout_red" then
			if v:GetNWBool("Taunting") == true then return end

			local time = v:PlayScene("scenes/player/"..v.TF2Class.."/low/taunt_highfivesuccessfull.vcd", 0)
			v:SetCycle(0)
			v:ResetSequence("taunt_hifivesuccessfull")
			v:SetNWBool("Taunting", true)
			v:SetNWBool("NoWeapon", true)
			timer.Simple(time, function()
				if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
				v:SetNWBool("Taunting", false)
				v:SetNWBool("NoWeapon", false)
				net.Start("DeActivateTauntCam")
				net.Send(v)
			end)
		end
	end
end)
concommand.Add("tf_taunt_squaredance", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_dosido_dance00.vcd", 0)
	ply:DoAnimationEvent(ACT_DOD_SECONDARYATTACK_PRONE_BOLT, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	ply:EmitSound("music/fortress_reel.wav")
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(9, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
	for k,v in pairs(ents.FindInSphere(ply:GetPos(), 120) ) do 
		if v:IsPlayer() then
			if v:IsHL2() then v:ConCommand("act laugh") return end
			if v:GetInfoNum("tf_robot", 0) == 1 then v:ChatPrint("You can't taunt as a robot!") return end
			if v:GetInfoNum("tf_giantrobot", 0) == 1 then v:ChatPrint("You can't taunt as a mighty robot!") return end
			local time = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/taunt_dosido_dance01.vcd", 0)
			v:DoAnimationEvent(ACT_DOD_SECONDARYATTACK_PRONE_BOLT, true)
			v:SetNWBool("Taunting", true)
			v:SetNWBool("NoWeapon", true)
			net.Start("ActivateTauntCam")
			net.Send(v)
			timer.Simple(9, function()
				if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
				v:SetNWBool("Taunting", false)
				v:SetNWBool("NoWeapon", false)
				net.Start("DeActivateTauntCam")
				net.Send(v)
			end)
		end
	end
end)
concommand.Add("tf_taunt_squaredance_intro", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:SequenceDuration("taunt_dosido_intro")
	ply:DoAnimationEvent(ACT_RUN_AIM, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	ply:EmitSound("DosidoIntro")
	net.Start("ActivateTauntCam")
	net.Send(ply)
	ply:EmitSound(""..ply:GetPlayerClass().."_taunt_dosido_intro_rand")
	timer.Create("squaredancewaiting"..ply:EntIndex(), 2, 0, function()
		ply:EmitSound(""..ply:GetPlayerClass().."_taunt_dosido_intro_wait_rand")
	end)
	timer.Create("squaredanceintro"..ply:EntIndex(), 3, 0, function()
		ply:DoAnimationEvent(ACT_RUN_AIM, true)
	end)
	timer.Create("squaredancestart"..ply:EntIndex(), 0.1, 0, function()
		if ply:KeyDown(IN_USE) then
			ply:ConCommand("tf_taunt_squaredance_intro_stop")
		end
		for k,v in ipairs(ents.FindInSphere(ply:GetPos(), 80)) do
			if v:IsPlayer() and v:Nick() != ply:Nick() then
				ply:StopSound("DosidoIntro")
				local sceusermessageime = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_dosido_dance00.vcd", 0)
				local sceusermessageime2 = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/taunt_dosido_dance00.vcd", 0)
				ply:DoAnimationEvent(ACT_DOD_SECONDARYATTACK_PRONE_BOLT, true)
				v:DoAnimationEvent(ACT_DOD_SECONDARYATTACK_PRONE_BOLT, true)
				ply:SetNWBool("Taunting", true)
				ply:SetNWBool("NoWeapon", true)
				v:SetNWBool("Taunting", true)
				v:SetNWBool("NoWeapon", true)
				ply:EmitSound("music/fortress_reel.wav")
				net.Start("ActivateTauntCam")
				net.Send(ply)
				net.Start("ActivateTauntCam")
				net.Send(v)
				timer.Simple(sceusermessageime, function()
					if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
					ply:SetNWBool("Taunting", false)
					ply:SetNWBool("NoWeapon", false)
					net.Start("DeActivateTauntCam")
					net.Send(ply)
				end)
				timer.Simple(sceusermessageime2, function()
					if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
					v:SetNWBool("Taunting", false)
					v:SetNWBool("NoWeapon", false)
					net.Start("DeActivateTauntCam")
					net.Send(v)
				end)
				timer.Stop("squaredanceintro"..ply:EntIndex())
				timer.Stop("squaredancewaiting"..ply:EntIndex())
				timer.Stop("squaredancestart"..ply:EntIndex())
			end
		end
	end)
end)
concommand.Add("tf_taunt_flipping_intro", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:SequenceDuration(ply:LookupSequence("taunt_flip_start"))
	ply:DoAnimationEvent(ACT_COVER, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply) 
	timer.Create("squaredanceintro"..ply:EntIndex(), time, 0, function()
		ply:DoAnimationEvent(ACT_COVER, true)
	end)
	timer.Create("squaredancestart"..ply:EntIndex(), 0.1, 0, function()
		if ply:KeyDown(IN_USE) then
			ply:ConCommand("tf_taunt_squaredance_intro_stop")
		end
		for k,v in ipairs(ents.FindInSphere(ply:GetPos(), 80)) do
			if v:IsPlayer() and v:Nick() != ply:Nick() then 
				local time2 = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/flip_success_initiator0.vcd", 0)
				local time3 = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/flip_success_receiver0.vcd", 0)
				ply:DoAnimationEvent(ACT_DOD_SECONDARYATTACK_BOLT, true)
				v:DoAnimationEvent(ACT_DOD_PRIMARYATTACK_PRONE_BOLT, true)
				ply:SetNWBool("Taunting", true)
				ply:SetNWBool("NoWeapon", true)
				v:SetNWBool("Taunting", true)
				v:SetNWBool("NoWeapon", true)
				net.Start("ActivateTauntCam")
				net.Send(ply)
				net.Start("ActivateTauntCam")
				net.Send(v)
				timer.Simple(time2, function()
					if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
					ply:SetNWBool("Taunting", false)
					ply:SetNWBool("NoWeapon", false)
					net.Start("DeActivateTauntCam")
					net.Send(ply)
				end)
				timer.Simple(time3, function()
					if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
					v:SetNWBool("Taunting", false)
					v:SetNWBool("NoWeapon", false)
					net.Start("DeActivateTauntCam")
					net.Send(v)
				end)
				timer.Stop("squaredanceintro"..ply:EntIndex())
				timer.Stop("squaredancewaiting"..ply:EntIndex())
				timer.Stop("squaredancestart"..ply:EntIndex())
			end
			if v.Base == "npc_tf2base" or v.Base == "npc_soldier_red" or v.Base == "npc_hwg_red" or v.Base == "npc_pyro_red" or v.Base == "npc_scout_red" then
				local time2 = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/flip_success_initiator0.vcd", 0)
				local time3 = v:PlayScene("scenes/player/"..v.TF2Class.."/low/flip_success_receiver0.vcd", 0)
				ply:DoAnimationEvent(ACT_DOD_SECONDARYATTACK_BOLT, true)
				v:SetCycle(0)
				v:ResetSequence("taunt_flip_success_receiver")
				ply:SetNWBool("Taunting", true)
				ply:SetNWBool("NoWeapon", true)
				timer.Simple(time2, function()
					if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
					ply:SetNWBool("Taunting", false)
					ply:SetNWBool("NoWeapon", false)
					net.Start("DeActivateTauntCam")
					net.Send(ply)
				end)
				timer.Stop("squaredanceintro"..ply:EntIndex())
				timer.Stop("squaredancewaiting"..ply:EntIndex())
				timer.Stop("squaredancestart"..ply:EntIndex())
			end
		end
	end)
end)
concommand.Add("tf_taunt_squaredance_intro", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:SequenceDuration("taunt_dosido_intro")
	ply:DoAnimationEvent(ACT_RUN_AIM, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	ply:EmitSound("DosidoIntro")
	net.Start("ActivateTauntCam")
	net.Send(ply)
	ply:EmitSound(""..ply:GetPlayerClass().."_taunt_dosido_intro_rand")
	timer.Create("squaredancewaiting"..ply:EntIndex(), 2, 0, function()
		ply:EmitSound(""..ply:GetPlayerClass().."_taunt_dosido_intro_wait_rand")
	end)
	timer.Create("squaredanceintro"..ply:EntIndex(), 3, 0, function()
		ply:DoAnimationEvent(ACT_RUN_AIM, true)
	end)
	timer.Create("squaredancestart"..ply:EntIndex(), 0.1, 0, function()
		if ply:KeyDown(IN_USE) then
			ply:ConCommand("tf_taunt_squaredance_intro_stop")
		end
		for k,v in ipairs(ents.FindInSphere(ply:GetPos(), 80)) do
			if v:IsPlayer() and v:Nick() != ply:Nick() then
				ply:StopSound("DosidoIntro")
				local sceusermessageime = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_dosido_dance00.vcd", 0)
				local sceusermessageime2 = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/taunt_dosido_dance00.vcd", 0)
				ply:DoAnimationEvent(ACT_DOD_SECONDARYATTACK_PRONE_BOLT, true)
				v:DoAnimationEvent(ACT_DOD_SECONDARYATTACK_PRONE_BOLT, true)
				ply:SetNWBool("Taunting", true)
				ply:SetNWBool("NoWeapon", true)
				v:SetNWBool("Taunting", true)
				v:SetNWBool("NoWeapon", true)
				ply:EmitSound("music/fortress_reel.wav")
				net.Start("ActivateTauntCam")
				net.Send(ply)
				net.Start("ActivateTauntCam")
				net.Send(v)
				timer.Simple(sceusermessageime, function()
					if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
					ply:SetNWBool("Taunting", false)
					ply:SetNWBool("NoWeapon", false)
					net.Start("DeActivateTauntCam")
					net.Send(ply)
				end)
				timer.Simple(sceusermessageime2, function()
					if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
					v:SetNWBool("Taunting", false)
					v:SetNWBool("NoWeapon", false)
					net.Start("DeActivateTauntCam")
					net.Send(v)
				end)
				timer.Stop("squaredanceintro"..ply:EntIndex())
				timer.Stop("squaredancewaiting"..ply:EntIndex())
				timer.Stop("squaredancestart"..ply:EntIndex())
			end
		end
	end)
end)
concommand.Add("tf_derp_aim", function(ply)
	if (ply:IsAdmin()) then
		ply:SetNWBool("IsDerpAim",true)
	end
end)
concommand.Add("tf_taunt_rockpaperscissors_intro", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	ply:DoAnimationEvent(ACT_RUN_CROUCH, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("IWantToTaunt", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	ply:EmitSound(""..ply:GetPlayerClass().."_taunt_rps_start_rand")
	timer.Create("rpsintro"..ply:EntIndex(), 5, 0, function()
		ply:DoAnimationEvent(ACT_RUN_CROUCH, true)
	end)
	timer.Create("rpswaiting"..ply:EntIndex(), 3, 0, function()
		ply:EmitSound(""..ply:GetPlayerClass().."_taunt_rps_intro_wait_rand")
	end)
	timer.Create("rpsstart"..ply:EntIndex(), 0.1, 0, function()
		for k,v in ipairs(ents.FindInSphere(ply:GetPos(), 80)) do
			if v:IsPlayer() and v:Nick() != ply:Nick() then
				if math.random(1,4) == 1 then
					local sceusermessageime = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_rps_paper_lose.vcd", 0)
					ply:DoTauntEvent("taunt_rps_paper_lose")
					ply:SetNWBool("Taunting", true)
					ply:SetNWBool("NoWeapon", true)
					net.Start("ActivateTauntCam")
					net.Send(ply)
					ply:SetNWBool("IWantToTaunt", false)
					v:SetNWBool("IWantToTauntToo", false)
					local sceusermessageime2 = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/taunt_rps_scissors_win.vcd", 0)
					v:DoTauntEvent("taunt_rps_scissors_win")
					v:SetNWBool("Taunting", true)
					v:SetNWBool("NoWeapon", true)
					net.Start("ActivateTauntCam")
					net.Send(v)
					timer.Simple(sceusermessageime, function()
						if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
						ply:SetNWBool("Taunting", false)
						ply:SetNWBool("NoWeapon", false)
						net.Start("DeActivateTauntCam")
						net.Send(ply)
					end)
					timer.Simple(sceusermessageime2, function()
						if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
						v:SetNWBool("Taunting", false)
						v:SetNWBool("NoWeapon", false)
						net.Start("DeActivateTauntCam")
						net.Send(v)
					end)
					timer.Stop("rpsintro"..ply:EntIndex())
					timer.Stop("rpsstart"..ply:EntIndex())
					timer.Stop("rpswaiting"..ply:EntIndex())
				end
				if math.random(1,4) == 2 then
					local sceusermessageime = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_rps_scissors_win.vcd", 0)
					ply:DoTauntEvent("taunt_rps_scissors_win")
					ply:SetNWBool("Taunting", true)
					ply:SetNWBool("NoWeapon", true)
					net.Start("ActivateTauntCam")
					net.Send(ply)
					ply:SetNWBool("IWantToTaunt", false)
					v:SetNWBool("IWantToTauntToo", false)
					local sceusermessageime2 = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/taunt_rps_paper_lose.vcd", 0)
					v:DoTauntEvent("taunt_rps_paper_lose")
					v:SetNWBool("Taunting", true)
					v:SetNWBool("NoWeapon", true)
					net.Start("ActivateTauntCam")
					net.Send(v)
					timer.Simple(sceusermessageime, function()
						if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
						ply:SetNWBool("Taunting", false)
						ply:SetNWBool("NoWeapon", false)
						net.Start("DeActivateTauntCam")
						net.Send(ply)
						if !v:IsFriendly(ply) then
							v:Explode()
						end
					end)
					timer.Simple(sceusermessageime2, function()
						if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
						v:SetNWBool("Taunting", false)
						v:SetNWBool("NoWeapon", false)
						net.Start("DeActivateTauntCam")
						net.Send(v)
					end)
					timer.Stop("rpsintro"..ply:EntIndex())
					timer.Stop("rpsstart"..ply:EntIndex())
					timer.Stop("rpswaiting"..ply:EntIndex())
				end
				if math.random(1,4) == 3 then
					local sceusermessageime = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_rps_rock_lose.vcd", 0)
					ply:DoTauntEvent("taunt_rps_rock_lose")
					ply:SetNWBool("Taunting", true)
					ply:SetNWBool("NoWeapon", true)
					net.Start("ActivateTauntCam")
					net.Send(ply)
					ply:SetNWBool("IWantToTaunt", false)
					v:SetNWBool("IWantToTauntToo", false)
					local sceusermessageime2 = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/taunt_rps_paper_win.vcd", 0)
					v:DoTauntEvent("taunt_rps_paper_win")
					v:SetNWBool("Taunting", true)
					v:SetNWBool("NoWeapon", true)
					net.Start("ActivateTauntCam")
					net.Send(v)
					timer.Simple(sceusermessageime, function()
						if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
						ply:SetNWBool("Taunting", false)
						ply:SetNWBool("NoWeapon", false)
						net.Start("DeActivateTauntCam")
						net.Send(ply)
						if !ply:IsFriendly(v) then
							ply:Explode()
						end
					end)
					timer.Simple(sceusermessageime2, function()
						if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
						v:SetNWBool("Taunting", false)
						v:SetNWBool("NoWeapon", false)
						net.Start("DeActivateTauntCam")
						net.Send(v)
					end)
					timer.Stop("rpsintro"..ply:EntIndex())
					timer.Stop("rpsstart"..ply:EntIndex())
					timer.Stop("rpswaiting"..ply:EntIndex())
				end
			end
			if v.Base == "npc_tf2base" or v.Base == "npc_soldier_red" or v.Base == "npc_hwg_red" or v.Base == "npc_pyro_red" or v.Base == "npc_scout_red" then
				if math.random(1,4) == 1 then
					local sceusermessageime = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_rps_paper_lose.vcd", 0) 
					ply:DoAnimationEvent(ACT_DOD_RELOAD_DEPLOYED_FG42, true)
					ply:SetNWBool("Taunting", true)
					ply:SetNWBool("NoWeapon", true)
					net.Start("ActivateTauntCam")
					net.Send(ply)
					ply:SetNWBool("IWantToTaunt", false)
					v:SetNWBool("IWantToTauntToo", false)
					local sceusermessageime2 = v:PlayScene("scenes/player/"..v.TF2Class.."/low/taunt_rps_scissors_win.vcd", 0)
					v:SetCycle(0)
					v:ResetSequence("taunt_rps_scissors_win")
					timer.Simple(sceusermessageime, function()
						if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
						ply:SetNWBool("Taunting", false)
						ply:SetNWBool("NoWeapon", false)
						net.Start("DeActivateTauntCam")
						net.Send(ply)
					end)
					timer.Simple(sceusermessageime2, function()
						if !v:IsFriendly(ply) then
							ply:Explode()
						end
					end)
					timer.Stop("rpsintro"..ply:EntIndex()) 
					timer.Stop("rpsstart"..ply:EntIndex())
					timer.Stop("rpswaiting"..ply:EntIndex())
				end
				if math.random(1,4) == 2 then
					local sceusermessageime = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_rps_scissors_win.vcd", 0)
					ply:DoAnimationEvent(ACT_DOD_RELOAD_DEPLOYED_FG42, true)
					ply:SetNWBool("Taunting", true)
					ply:SetNWBool("NoWeapon", true)
					net.Start("ActivateTauntCam")
					net.Send(ply)
					ply:SetNWBool("IWantToTaunt", false)
					v:SetNWBool("IWantToTauntToo", false)
					local sceusermessageime2 = v:PlayScene("scenes/player/"..v.TF2Class.."/low/taunt_rps_paper_lose.vcd", 0)
					v:ResetSequence("taunt_rps_scissors_win")
					v:SetCycle(0)
					timer.Simple(sceusermessageime, function()
						if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
						ply:SetNWBool("Taunting", false)
						ply:SetNWBool("NoWeapon", false)
						net.Start("DeActivateTauntCam")
						net.Send(ply)
					end)
					timer.Simple(sceusermessageime2, function()
						if !ply:IsFriendly(v) then
							v:Splatter()
						end
					end)
					timer.Stop("rpsintro"..ply:EntIndex())
					timer.Stop("rpsstart"..ply:EntIndex())
					timer.Stop("rpswaiting"..ply:EntIndex())
				end
				if math.random(1,4) == 3 then
					local sceusermessageime = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_rps_rock_lose.vcd", 0)
					ply:DoAnimationEvent(ACT_DOD_RELOAD_DEPLOYED_FG42, true)
					ply:SetNWBool("Taunting", true)
					ply:SetNWBool("NoWeapon", true)
					net.Start("ActivateTauntCam")
					net.Send(ply)
					ply:SetNWBool("IWantToTaunt", false)
					v:SetNWBool("IWantToTauntToo", false)
					local sceusermessageime2 = v:PlayScene("scenes/player/"..v.TF2Class.."/low/taunt_rps_paper_win.vcd", 0)
					v:ResetSequence("taunt_rps_scissors_win")
					v:SetCycle(0)
					timer.Simple(sceusermessageime, function()
						if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
						ply:SetNWBool("Taunting", false)
						ply:SetNWBool("NoWeapon", false)
						net.Start("DeActivateTauntCam")
						net.Send(ply)
					end)
					timer.Simple(sceusermessageime2, function()
						if !v:IsFriendly(ply) then
							ply:Explode()
						end
					end)
					timer.Stop("rpsintro"..ply:EntIndex())
					timer.Stop("rpsstart"..ply:EntIndex())
					timer.Stop("rpswaiting"..ply:EntIndex())
				end
			end
		end
	end)
end)
concommand.Add("tf_taunt_squaredance_intro_stop", function(ply)
	if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
	ply:SetNWBool("Taunting", false)
	ply:SetNWBool("NoWeapon", false)
	net.Start("DeActivateTauntCam")
	ply:StopSound("DosidoIntro")
	net.Send(ply)
	timer.Stop("squaredanceintro"..ply:EntIndex())
	timer.Stop("squaredancestart"..ply:EntIndex())
	timer.Stop("squaredancewaiting"..ply:EntIndex())
end)
concommand.Add("tf_taunt_rockpaperscissors_intro_stop", function(ply)
	if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
	ply:SetNWBool("Taunting", false)
	ply:SetNWBool("NoWeapon", false)
	net.Start("DeActivateTauntCam")
	ply:StopSound("DosidoIntro")
	net.Send(ply)
	timer.Stop("rpsintro"..ply:EntIndex())
	timer.Stop("rpswaiting"..ply:EntIndex())
	timer.Stop("rpsstart"..ply:EntIndex())
end)
concommand.Add("tf_taunt_rockpaperscissors", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giant_robot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/"..table.Random(rockpaperscissors)..".vcd", 0)
	ply:DoAnimationEvent(table.Random(rockpaperscissorsact), true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(7, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
	for k,v in pairs(ents.FindInSphere(ply:GetPos(), 120) ) do 
		if v:IsPlayer() and v:Nick() != ply:Nick() then
			if v:IsHL2() then v:ConCommand("act laugh") return end
			if v:GetInfoNum("tf_robot", 0) == 1 then v:ChatPrint("You can't taunt as a robot!") return end
			if v:GetInfoNum("tf_giantrobot", 0) == 1 then v:ChatPrint("You can't taunt as a mighty robot!") return end
			local time = v:PlayScene("scenes/player/"..v:GetPlayerClass().."/low/"..table.Random(rockpaperscissors)..".vcd", 0)
			v:DoAnimationEvent(table.Random(rockpaperscissorsact), true)
			v:SetNWBool("Taunting", true)
			v:SetNWBool("NoWeapon", true)
			net.Start("ActivateTauntCam")
			net.Send(v)
			timer.Simple(7, function()
				if not IsValid(v) or (not v:Alive() and not v:GetNWBool("Taunting")) then return end
				v:SetNWBool("Taunting", false)
				v:SetNWBool("NoWeapon", false)
				net.Start("DeActivateTauntCam")
				net.Send(v)
			end)
		end
	end
end)

concommand.Add("tf_taunt", function(ply,cmd,args)
	local slot = tonumber(args and args[1])
	if slot and slot >= 1 and slot <= 8 and ply.TryExecuteEquippedTauntSlot then
		if ply:TryExecuteEquippedTauntSlot(slot) then
			return
		end
	end
	ply:TFTaunt(args and args[1])
end)
local function getTauntItemByID(itemId)
	local defindex = tonumber(itemId)
	if not defindex or not tf_items or not tf_items.ItemsByID then return nil end
	return tf_items.ItemsByID[defindex]
end

local function schemaPickPerClass(tbl, className)
	if not istable(tbl) then return nil end
	return tbl[className] or tbl[string.lower(className or "")] or nil
end

local function schemaNormalizeChoiceList(value)
	if isstring(value) then
		return {value}
	end
	if not istable(value) then
		return {}
	end

	local numeric = {}
	for k, v in pairs(value) do
		if isstring(v) and v ~= "" then
			numeric[#numeric + 1] = {idx = tonumber(k) or (#numeric + 1), value = v}
		end
	end
	table.sort(numeric, function(a, b) return a.idx < b.idx end)

	local out = {}
	for _, entry in ipairs(numeric) do
		out[#out + 1] = entry.value
	end
	return out
end

local function schemaPickScene(tbl, className)
	local entry = schemaPickPerClass(tbl, className)
	local list = schemaNormalizeChoiceList(entry)
	if #list == 0 then return nil end
	return list[math.random(#list)]
end

local function schemaSceneToSequence(scenePath)
	if not isstring(scenePath) or scenePath == "" then return nil end
	local normalized = string.Replace(scenePath, "\\", "/")
	local basename = string.match(normalized, "([^/]+)%.vcd$")
	return basename
end

local function schemaResolveSequence(ent, scenePath)
	local basename = schemaSceneToSequence(scenePath)
	if not IsValid(ent) or not isstring(basename) or basename == "" then return basename end

	local candidates = {basename}
	if string.EndsWith(basename, "_allclass") then
		candidates[#candidates + 1] = string.sub(basename, 1, #basename - #"_allclass")
	end

	local seen = {}
	for _, candidate in ipairs(candidates) do
		if isstring(candidate) and candidate ~= "" and not seen[candidate] then
			seen[candidate] = true
			local idx = ent:LookupSequence(candidate)
			if idx and idx >= 0 then
				return candidate
			end
		end
	end

	return basename
end

local function schemaSequenceDuration(ent, seq)
	if not IsValid(ent) or not isstring(seq) or seq == "" then return 0 end
	local idx = ent:LookupSequence(seq)
	if not idx or idx < 0 then return 0 end
	return tonumber(ent:SequenceDuration(idx)) or 0
end

local function schemaGetAttribute(item, attrClass)
	if not istable(item) then return nil end
	for _, bucket in ipairs({item.attributes, item.static_attrs}) do
		if istable(bucket) then
			for _, attr in pairs(bucket) do
				if istable(attr) and attr.attribute_class == attrClass then
					return attr.value
				end
			end
		end
	end
	return nil
end

local function schemaGetVisual(item, key)
	if not istable(item) or not istable(item.visuals) then return nil end
	return item.visuals[key]
end

local function schemaStartAnimatedProp(ent)
	if not IsValid(ent) then return end
	ent.AutomaticFrameAdvance = true
	ent:SetPlaybackRate(1)
	function ent:Think()
		self:NextThink(CurTime())
		return true
	end
end

local function schemaPlayPropSequence(ent, scenePath)
	if not IsValid(ent) then return 0 end
	local seq = schemaSceneToSequence(scenePath)
	if not isstring(seq) or seq == "" then return 0 end
	local idx = ent:LookupSequence(seq)
	if not idx or idx < 0 then return 0 end
	ent:ResetSequence(seq)
	ent:SetCycle(0)
	schemaStartAnimatedProp(ent)
	return tonumber(ent:SequenceDuration(idx)) or 0
end

local function schemaCreateProp(ply, state)
	if not IsValid(ply) or not istable(state) or not isstring(state.propModel) or state.propModel == "" then return end
	local prop = ents.Create("base_gmodentity")
	if not IsValid(prop) then return end

	prop:SetModel(state.propModel)
	prop:SetAngles(ply:GetAngles())
	prop:SetPos(ply:GetPos())
	prop:Spawn()
	prop:Activate()
	prop:SetSkin(ply:GetSkin())
	prop:SetParent(ply)
	prop:AddEffects(EF_BONEMERGE)
	prop:SetName(state.propName)
	state.propEnt = prop

	if isstring(state.propIntroScene) and state.propIntroScene ~= "" then
		schemaPlayPropSequence(prop, state.propIntroScene)
	end
end

local function schemaRemoveProp(state)
	local prop = istable(state) and state.propEnt or nil
	if IsValid(prop) then
		prop:Remove()
		return
	end
	if istable(state) and isstring(state.propName) and state.propName ~= "" then
		for _, v in ipairs(ents.FindByName(state.propName)) do
			v:Remove()
		end
	end
end

local function schemaSetTauntFlags(ply, enabled)
	if not IsValid(ply) then return end
	ply:SetNWBool("Taunting", enabled)
	ply:SetNWBool("NoWeapon", enabled)
	if enabled then
		net.Start("ActivateTauntCam")
	else
		net.Start("DeActivateTauntCam")
	end
	net.Send(ply)
end

local function schemaIsBanjoTaunt(state)
	return istable(state) and tonumber(state.itemId) == 30842
end

local function schemaIsVictoryLap(state)
	return istable(state) and tonumber(state.itemId) == 1172
end

local function schemaStopBanjoEffects(ply)
	if not IsValid(ply) then return end
	timer.Remove("SchemaBanjoLoop_" .. ply:EntIndex())
	timer.Remove("SchemaBanjoVoice_" .. ply:EntIndex())
	ply:StopSound("Taunt.BumpkinsBanjoMusic")
	ply:StopSound("Taunt.BumpkinsBanjoMusicFast")
	ply:StopSound("BanjoSong")
	ply:StopParticles()
end

local function schemaRefreshBanjoLoop(ply, state)
	if not IsValid(ply) or not schemaIsBanjoTaunt(state) then return end
	local entId = ply:EntIndex()
	local fast = state.banjoMode == "fast"
	local loopSound = fast and "Taunt.BumpkinsBanjoMusicFast" or "Taunt.BumpkinsBanjoMusic"
	local interval = fast and 3.6 or 5.2

	timer.Remove("SchemaBanjoLoop_" .. entId)
	ply:StopSound("Taunt.BumpkinsBanjoMusic")
	ply:StopSound("Taunt.BumpkinsBanjoMusicFast")
	ply:EmitSound(loopSound)
	timer.Create("SchemaBanjoLoop_" .. entId, interval, 0, function()
		local st = IsValid(ply) and ply.__SchemaTauntState or nil
		if not IsValid(ply) or not istable(st) or not st.active or not schemaIsBanjoTaunt(st) then
			timer.Remove("SchemaBanjoLoop_" .. entId)
			return
		end
		local currentSound = st.banjoMode == "fast" and "Taunt.BumpkinsBanjoMusicFast" or "Taunt.BumpkinsBanjoMusic"
		ply:EmitSound(currentSound)
	end)

	timer.Remove("SchemaBanjoVoice_" .. entId)
	timer.Create("SchemaBanjoVoice_" .. entId, 8, 0, function()
		local st = IsValid(ply) and ply.__SchemaTauntState or nil
		if not IsValid(ply) or not istable(st) or not st.active or not schemaIsBanjoTaunt(st) then
			timer.Remove("SchemaBanjoVoice_" .. entId)
			return
		end
		ply:EmitSound("engineer_taunt_bumpkins_banjo_yells")
	end)

	if fast then
		local left = ply:LookupAttachment("hand_L")
		local right = ply:LookupAttachment("hand_R")
		if left and left > 0 then
			ParticleEffectAttach("cig_smoke", PATTACH_POINT_FOLLOW, ply, left)
		end
		if right and right > 0 then
			ParticleEffectAttach("cig_smoke", PATTACH_POINT_FOLLOW, ply, right)
		end
	else
		ply:StopParticles()
	end
end

local function schemaDoTrickshotAttack(ply, state)
	if not IsValid(ply) or not istable(state) or tonumber(state.itemId) ~= 31520 then return end

	ply:EmitSound("Weapon_Pistol.TF_Single")

	local tr = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + ply:EyeAngles():Forward() * 500,
		filter = ply,
		mask = bit.bor(MASK_SOLID, CONTENTS_HITBOX),
	})

	local ent = tr.Entity
	if not IsValid(ent) or not ent:IsPlayer() then return end
	if ent:Team() <= 0 or ent:Team() == ply:Team() then return end

	local launchDir = Angle(-45, ply:EyeAngles().y, 0):Forward()
	local dmg = DamageInfo()
	dmg:SetAttacker(ply)
	dmg:SetInflictor(IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon() or ply)
	dmg:SetDamage(500)
	dmg:SetDamageType(DMG_BULLET)
	dmg:SetDamageForce(launchDir * 25000)
	dmg:SetDamagePosition(ent:WorldSpaceCenter())
	ent:TakeDamageInfo(dmg)
end

local function schemaStartTexasTwirlSounds(ply, state)
	if not IsValid(ply) or not istable(state) or tonumber(state.itemId) ~= 31286 then return end
	local entId = ply:EntIndex()
	timer.Remove("SchemaTexasTwirl_" .. entId)
	timer.Remove("SchemaTexasTwirl_" .. entId .. "_2")
	timer.Create("SchemaTexasTwirl_" .. entId, 0.01, 1, function()
		if not IsValid(ply) then return end
		ply:EmitSound("Weapon_Pistol.TF_Single")
	end)
	timer.Create("SchemaTexasTwirl_" .. entId .. "_2", 0.38, 1, function()
		if not IsValid(ply) then return end
		ply:EmitSound("Selection.ScoutShotgunTwirl")
	end)
end

local function schemaStartVictoryLapEffects(ply, state)
	if not IsValid(ply) or not schemaIsVictoryLap(state) then return end
	local entId = ply:EntIndex()
	timer.Remove("SchemaVictoryLapLoop_" .. entId)
	ply:EmitSound("BumperCar.Spawn")
	timer.Create("SchemaVictoryLapLoop_" .. entId, 0.35, 1, function()
		if not IsValid(ply) then return end
		local st = ply.__SchemaTauntState
		if not istable(st) or not st.active or not schemaIsVictoryLap(st) then return end
		ply:EmitSound("BumperCar.GoLoop")
	end)
end

local function schemaStopVictoryLapEffects(ply, state, skipOutro)
	if not IsValid(ply) or not schemaIsVictoryLap(state) then return end
	local entId = ply:EntIndex()
	timer.Remove("SchemaVictoryLapLoop_" .. entId)
	ply:StopSound("BumperCar.GoLoop")
	ply:StopSound("Taunt.BumperCarGoLoop")
	if not skipOutro then
		ply:EmitSound("Taunt.BumperCarQuit")
	end
end

local function schemaFinishPartnerTaunt(players)
	for _, ent in ipairs(players or {}) do
		if IsValid(ent) then
			ent.__SchemaTauntPartnerState = nil
			schemaSetTauntFlags(ent, false)
		end
	end
end

local function schemaFindPartnerTarget(ply, item)
	if not IsValid(ply) or not istable(item) or not istable(item.taunt) then return nil end
	local forwardDist = tonumber(item.taunt.taunt_separation_forward_distance) or 60
	local searchRadius = math.max(tonumber(item.taunt.taunt_separation_forward_distance) or 60, 96) + 48
	local nearest, nearestDist

	for _, other in ipairs(ents.FindInSphere(ply:GetPos(), searchRadius)) do
		if other == ply then continue end
		if not IsValid(other) or not other:IsPlayer() then continue end
		if other:GetNWBool("Taunting", false) then continue end
		if not other:Alive() or not other:IsOnGround() or other:WaterLevel() ~= 0 then continue end
		local dist = ply:GetPos():DistToSqr(other:GetPos())
		if not nearestDist or dist < nearestDist then
			nearest = other
			nearestDist = dist
		end
	end

	return nearest
end

local function schemaChoosePartnerScenes(item, initiatorClass, receiverClass)
	local t = item and item.taunt
	if not istable(t) then return nil, nil end

	local initiatorChoices = schemaNormalizeChoiceList(schemaPickPerClass(t.custom_partner_taunt_initiator_per_class, initiatorClass))
	local receiverChoices = schemaNormalizeChoiceList(schemaPickPerClass(t.custom_partner_taunt_receiver_per_class, receiverClass))

	if #initiatorChoices > 0 and #receiverChoices > 0 then
		local idx = math.random(math.min(#initiatorChoices, #receiverChoices))
		return initiatorChoices[idx], receiverChoices[idx]
	end

	local sharedInitiator = schemaNormalizeChoiceList(schemaPickPerClass(t.custom_partner_taunt_per_class, initiatorClass))
	local sharedReceiver = schemaNormalizeChoiceList(schemaPickPerClass(t.custom_partner_taunt_per_class, receiverClass))
	if #sharedInitiator == 0 or #sharedReceiver == 0 then
		return nil, nil
	end

	if #sharedInitiator >= 2 and #sharedReceiver >= 2 then
		local swap = math.random(2) == 1
		return sharedInitiator[swap and 1 or 2], sharedReceiver[swap and 2 or 1]
	end

	return sharedInitiator[1], sharedReceiver[math.min(#sharedReceiver, 1)]
end

local function startSchemaPartnerTaunt(ply, item)
	local partner = schemaFindPartnerTarget(ply, item)
	local className = tostring(ply:GetPlayerClass() or "")
	local introScene = schemaPickScene(item.taunt.custom_taunt_scene_per_class, className)
	local introSeq = schemaResolveSequence(ply, introScene)

	if not IsValid(partner) then
		if not isstring(introSeq) or introSeq == "" then return false end
		local introDur = schemaSequenceDuration(ply, introSeq)
		ply:DoTauntEvent(introSeq, true)
		schemaSetTauntFlags(ply, true)
		timer.Create("SchemaPartnerWait_" .. ply:EntIndex(), math.max(introDur, 2), 1, function()
			if IsValid(ply) then
				schemaSetTauntFlags(ply, false)
			end
		end)
		return true
	end

	local partnerClass = tostring(partner:GetPlayerClass() or "")
	local initScene, recvScene = schemaChoosePartnerScenes(item, className, partnerClass)
	local initSeq = schemaResolveSequence(ply, initScene)
	local recvSeq = schemaResolveSequence(partner, recvScene)
	if not isstring(initSeq) or initSeq == "" or not isstring(recvSeq) or recvSeq == "" then
		return false
	end

	local forward = ply:GetForward()
	forward.z = 0
	forward:Normalize()
	local right = ply:GetRight()
	right.z = 0
	right:Normalize()

	local forwardDist = tonumber(item.taunt.taunt_separation_forward_distance) or 60
	local rightDist = tonumber(item.taunt.taunt_separation_right_distance) or 0
	local partnerPos = ply:GetPos() + forward * forwardDist + right * rightDist
	partner:SetPos(partnerPos)
	local look = (ply:GetPos() - partner:GetPos()):Angle()
	look.p = 0
	look.r = 0
	partner:SetEyeAngles(look)
	partner:SetAngles(Angle(0, look.y, 0))

	ply:DoTauntEvent(initSeq, true)
	partner:DoTauntEvent(recvSeq, true)
	schemaSetTauntFlags(ply, true)
	schemaSetTauntFlags(partner, true)
	ply.__SchemaTauntPartnerState = {partner = partner, itemId = tonumber(item.id)}
	partner.__SchemaTauntPartnerState = {partner = ply, itemId = tonumber(item.id)}

	local dur = math.max(schemaSequenceDuration(ply, initSeq), schemaSequenceDuration(partner, recvSeq), 1)
	timer.Create("SchemaPartnerDone_" .. ply:EntIndex(), dur, 1, function()
		schemaFinishPartnerTaunt({ply, partner})
	end)

	return true
end

local function stopSchemaTaunt(ply, skipOutro)
	if not IsValid(ply) then return end
	local state = ply.__SchemaTauntState
	if not istable(state) or not state.active then return end

	local entId = ply:EntIndex()
	timer.Remove("SchemaTauntAutoStop_" .. entId)
	timer.Remove("SchemaTauntInputReset_" .. entId)
	timer.Remove("SchemaTauntAttack_" .. entId)
	timer.Remove("SchemaPartnerWait_" .. entId)
	timer.Remove("SchemaTexasTwirl_" .. entId)
	timer.Remove("SchemaTexasTwirl_" .. entId .. "_2")
	timer.Remove("SchemaVictoryLapLoop_" .. entId)
	if schemaIsBanjoTaunt(state) and not skipOutro then
		ply:EmitSound("Taunt.BumpkinsBanjoMusicStop")
		ply:EmitSound("engineer_taunt_bumpkins_banjo_engineer_outro")
	end
	schemaStopVictoryLapEffects(ply, state, skipOutro)
	schemaStopBanjoEffects(ply)

	if isstring(state.loopSound) and state.loopSound ~= "" then
		ply:StopSound(state.loopSound)
	end

	local outroDur = 0
	if not skipOutro and isstring(state.outroSeq) and state.outroSeq ~= "" then
		ply:DoTauntEvent(state.outroSeq, true)
		outroDur = tonumber(state.outroDur) or 0
	end

	if not skipOutro and IsValid(state.propEnt) and isstring(state.propOutroScene) and state.propOutroScene ~= "" then
		local propOutroDur = schemaPlayPropSequence(state.propEnt, state.propOutroScene)
		outroDur = math.max(outroDur, propOutroDur)
	end

	if skipOutro or outroDur <= 0 then
		schemaRemoveProp(state)
	else
		timer.Simple(math.max(outroDur, 0.1), function()
			schemaRemoveProp(state)
		end)
	end

	ply.__SchemaTauntMoveInput = 0
	ply.__SchemaTauntDriveInput = 0
	ply.__SchemaTauntTurnRate = 0
	ply.__SchemaTauntDriveRate = 0
	ply.__SchemaTauntState = nil
	ply:SetNWBool("TauntingSchemaMove", false)

	timer.Simple(math.max(outroDur, 0.1), function()
		if not IsValid(ply) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end

function TF_EndSchemaTaunt(ply)
	local state = IsValid(ply) and ply.__SchemaTauntState or nil
	if istable(state) and state.active then
		local minEndTime = (tonumber(state.startTime) or 0) + (tonumber(state.minTauntTime) or 0)
		if CurTime() < minEndTime then return end
	end
	stopSchemaTaunt(ply, false)
end

function TF_TriggerSchemaTauntInput(ply, inputName)
	if not IsValid(ply) then return end
	local state = ply.__SchemaTauntState
	if not istable(state) or not state.active then return end
	local remap = state.inputRemaps and state.inputRemaps[inputName]
	if not isstring(remap) or remap == "" then return end

	local entId = ply:EntIndex()
	local seq = remap
	if not isstring(seq) or seq == "" then return end

	local dur = schemaSequenceDuration(ply, seq)
	timer.Remove("SchemaTauntInputReset_" .. entId)
	ply:DoTauntEvent(seq, true)
	if schemaIsBanjoTaunt(state) then
		state.mainSeq = seq
		if inputName == "IN_ATTACK2" then
			state.banjoMode = "fast"
		elseif inputName == "IN_ATTACK" then
			state.banjoMode = "slow"
		end
		schemaRefreshBanjoLoop(ply, state)
		local propRemap = state.propInputRemaps and state.propInputRemaps[inputName]
		if IsValid(state.propEnt) and isstring(propRemap) and propRemap ~= "" then
			schemaPlayPropSequence(state.propEnt, propRemap)
		end
		return
	end
	if schemaIsVictoryLap(state) and inputName == "IN_ATTACK" then
		ply:EmitSound("Taunt.BumperCarHorn")
	end
	local propRemap = state.propInputRemaps and state.propInputRemaps[inputName]
	if IsValid(state.propEnt) and isstring(propRemap) and propRemap ~= "" then
		dur = math.max(dur, schemaPlayPropSequence(state.propEnt, propRemap))
	end
	timer.Create("SchemaTauntInputReset_" .. entId, math.max(dur, 0.5), 1, function()
		if not IsValid(ply) then return end
		local st = ply.__SchemaTauntState
		if not istable(st) or not st.active then return end
		if isstring(st.mainSeq) and st.mainSeq ~= "" then
			ply:DoTauntEvent(st.mainSeq, true)
		end
	end)
end

local function startSchemaTaunt(ply, item)
	if not IsValid(ply) or not istable(item) or not istable(item.taunt) then return false end
	if ply:GetNWBool("Taunting") == true then return false end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return true end
	if not ply:IsOnGround() then return false end
	if ply:WaterLevel() ~= 0 then return false end
	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then
		ply:ChatPrint("You can't taunt as a mighty robot!")
		return true
	end

	local className = tostring(ply:GetPlayerClass() or "")
	if tonumber(item.taunt.is_partner_taunt) == 1 or item.taunt.is_partner_taunt == "1" or item.taunt.is_partner_taunt == true then
		return startSchemaPartnerTaunt(ply, item)
	end

	local scenePath = schemaPickScene(item.taunt.custom_taunt_scene_per_class, className)
	local mainSeq = schemaResolveSequence(ply, scenePath)
	if not isstring(mainSeq) or mainSeq == "" then return false end

	local mainDur = schemaSequenceDuration(ply, mainSeq)
	local outroScene = schemaPickScene(item.taunt.custom_taunt_outro_scene_per_class, className)
	local outroSeq = schemaResolveSequence(ply, outroScene)
	local outroDur = schemaSequenceDuration(ply, outroSeq)
	local propModel = schemaPickScene(item.taunt.custom_taunt_prop_per_class, className)
	local propIntroScene = schemaPickScene(item.taunt.custom_taunt_prop_scene_per_class, className)
	local propOutroScene = schemaPickScene(item.taunt.custom_taunt_prop_outro_scene_per_class, className)
	local inputRemaps = {}
	if istable(item.taunt.custom_taunt_input_remap) then
		for keyName, keyData in pairs(item.taunt.custom_taunt_input_remap) do
			if istable(keyData) and istable(keyData.pressed) then
				inputRemaps[keyName] = schemaResolveSequence(ply, schemaPickScene(keyData.pressed, className))
			end
		end
	end
	local propInputRemaps = {}
	if istable(item.taunt.custom_taunt_prop_input_remap) then
		for keyName, keyData in pairs(item.taunt.custom_taunt_prop_input_remap) do
			if istable(keyData) and istable(keyData.pressed) then
				propInputRemaps[keyName] = schemaPickScene(keyData.pressed, className)
			end
		end
	end

	local moveSpeed = tonumber(schemaGetAttribute(item, "taunt_move_speed")) or 0
	local forceForward = (tonumber(schemaGetAttribute(item, "taunt_force_move_forward")) or 0) ~= 0
	local turnSpeed = tonumber(schemaGetAttribute(item, "taunt_turn_speed")) or 0
	local turnAccel = tonumber(schemaGetAttribute(item, "taunt_turn_acceleration_time")) or 0.2
	local hold = (tonumber(schemaGetAttribute(item, "enable_misc2_holdtaunt")) or 0) ~= 0
	local tauntAttackName = schemaGetAttribute(item, "taunt_attack_name")
	local tauntAttackTime = tonumber(schemaGetAttribute(item, "taunt_attack_time")) or 0
	local minTauntTime = tonumber(item.taunt.min_taunt_time) or 0
	local stopIfMoved = tonumber(item.taunt.stop_taunt_if_moved) == 1 or item.taunt.stop_taunt_if_moved == "1" or item.taunt.stop_taunt_if_moved == true
	local controlled = moveSpeed > 0 or turnSpeed > 0 or forceForward

	local state = {
		active = true,
		itemId = tonumber(item.id),
		startTime = CurTime(),
		mainSeq = mainSeq,
		mainDur = mainDur,
		outroSeq = outroSeq,
		outroDur = outroDur,
		propModel = propModel,
		propIntroScene = propIntroScene,
		propOutroScene = propOutroScene,
		propName = "SchemaTauntProp" .. ply:EntIndex(),
		moveSpeed = moveSpeed,
		forceForward = forceForward,
		turnSpeed = turnSpeed,
		turnAccel = turnAccel,
		hold = hold,
		tauntAttackName = tauntAttackName,
		tauntAttackTime = tauntAttackTime,
		minTauntTime = minTauntTime,
		stopIfMoved = stopIfMoved,
		loopSound = tonumber(item.id) == 1172 and nil or (schemaGetAttribute(item, "taunt_success_sound_loop") or schemaGetAttribute(item, "taunt_success_sound") or schemaGetVisual(item, "custom_sound0") or schemaGetVisual(item, "custom_sound1")),
		inputRemaps = inputRemaps,
		propInputRemaps = propInputRemaps,
	}
	ply.__SchemaTauntState = state
	ply.__SchemaTauntMoveInput = 0
	ply.__SchemaTauntDriveInput = 0
	ply.__SchemaTauntTurnRate = 0
	ply.__SchemaTauntDriveRate = 0

	ply:DoTauntEvent(mainSeq, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	ply:SetNWBool("TauntingSchemaMove", controlled)
	net.Start("ActivateTauntCam")
	net.Send(ply)

	schemaCreateProp(ply, state)

	if isstring(state.loopSound) and state.loopSound ~= "" then
		ply:EmitSound(state.loopSound)
	end
	if schemaIsBanjoTaunt(state) then
		state.banjoMode = "slow"
		schemaRefreshBanjoLoop(ply, state)
		ply:EmitSound("engineer_taunt_bumpkins_banjo_intro")
	end
	if schemaIsVictoryLap(state) then
		schemaStartVictoryLapEffects(ply, state)
	end
	schemaStartTexasTwirlSounds(ply, state)
	if isstring(state.tauntAttackName) and state.tauntAttackName ~= "" and state.tauntAttackTime > 0 then
		timer.Create("SchemaTauntAttack_" .. ply:EntIndex(), state.tauntAttackTime, 1, function()
			local st = IsValid(ply) and ply.__SchemaTauntState or nil
			if not IsValid(ply) or not istable(st) or not st.active then return end
			if st.tauntAttackName == "TAUNTATK_ENGINEER_TRICKSHOT" then
				schemaDoTrickshotAttack(ply, st)
			end
		end)
	end

	local autoStopDelay = hold and math.max(minTauntTime, 600) or (controlled and math.max(minTauntTime, 30) or math.max(mainDur, minTauntTime, 1))
	timer.Create("SchemaTauntAutoStop_" .. ply:EntIndex(), autoStopDelay, 1, function()
		if not IsValid(ply) then return end
		stopSchemaTaunt(ply, false)
	end)

	return true
end

concommand.Add("tf_taunt_schema", function(ply, cmd, args)
	local item = getTauntItemByID(args and args[1])
	if not istable(item) then return end
	startSchemaTaunt(ply, item)
end)
concommand.Add("tf_taunt_item", function(ply, cmd, args)
	local itemId = tonumber(args and args[1])
	local slot = tonumber(args and args[2])

	if itemId and itemId > 0 and ply.TryExecuteTauntItemByID then
		if ply:TryExecuteTauntItemByID(itemId, slot) then
			return
		end
	end

	if slot and slot >= 1 and slot <= 8 and ply.TryExecuteEquippedTauntSlot then
		if ply:TryExecuteEquippedTauntSlot(slot) then
			return
		end
	end

	ply:TFTaunt(slot and tostring(slot) or nil)
end)
local function StartTokenTaunt(ply, rawToken)
	if not IsValid(ply) or not ply:IsPlayer() then return false end
	if ply:GetNWBool("Taunting") == true then return false end
	if ply:IsHL2() then
		ply:SendLua("RunConsoleCommand('act','laugh')")
		return true
	end
	if not ply:IsOnGround() then return false end
	if ply:WaterLevel() ~= 0 then return false end
	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then
		ply:ChatPrint("You can't taunt as a mighty robot!")
		return true
	end

	local token = string.lower(tostring(rawToken or ""))
	token = string.gsub(token, "[^a-z0-9_]+", "_")
	token = string.gsub(token, "_+", "_")
	token = string.gsub(token, "^_+", "")
	token = string.gsub(token, "_+$", "")
	if token == "" then return false end

	local sequenceCandidates = {
		"taunt_" .. token,
		token,
		"taunt_" .. string.gsub(token, "_", ""),
	}

	local sequenceName = nil
	local sequenceDuration = 0
	for _, candidate in ipairs(sequenceCandidates) do
		local idx = ply:LookupSequence(candidate)
		if idx and idx >= 0 then
			local dur = tonumber(ply:SequenceDuration(idx)) or 0
			if dur > 0 then
				sequenceName = candidate
				sequenceDuration = dur
				break
			end
		end
	end
	if not sequenceName then
		return false
	end

	ply:DoTauntEvent(sequenceName, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)

	timer.Simple(math.max(sequenceDuration, 1), function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)

	return true
end

concommand.Add("tf_taunt_token", function(ply, cmd, args)
	local token = tostring(args and args[1] or "")
	StartTokenTaunt(ply, token)
end)
local function findBestSequence(ply, candidates)
	for _, seqName in ipairs(candidates) do
		local idx = ply:LookupSequence(seqName)
		if idx and idx >= 0 then
			local dur = tonumber(ply:SequenceDuration(idx)) or 0
			if dur > 0 then
				return seqName, dur
			end
		end
	end
	return nil, 0
end

local function startMopedLoop(ply)
	if not IsValid(ply) or not ply:GetNWBool("TauntingMoped") then return end
	local entId = ply:EntIndex()
	local loopSeq = ply.__MopedLoopSeq
	local loopDur = tonumber(ply.__MopedLoopDur) or 0
	timer.Remove("MopedLoop_" .. entId)
	if not loopSeq or loopDur <= 0 then return end
	timer.Create("MopedLoop_" .. entId, math.max(loopDur, 0.4), 0, function()
		if not IsValid(ply) or not ply:GetNWBool("TauntingMoped") then
			timer.Remove("MopedLoop_" .. entId)
			return
		end
		ply:DoTauntEvent(loopSeq, true)
	end)
end

local function endMopedTaunt(ply)
	if not IsValid(ply) then return end
	local entId = ply:EntIndex()
	timer.Remove("MopedLoop_" .. entId)
	timer.Remove("MopedAutoStop_" .. entId)
	timer.Remove("MopedVoice_" .. entId)
	ply.__MopedTurnRate = 0
	ply.__MopedTurnInput = 0
	ply.__MopedLoopSeq = nil
	ply.__MopedLoopDur = 0

	local endSeq, endDur = findBestSequence(ply, {
		"layer_tuant_vehicle_moped_end",
		"layer_taunt_vehicle_moped_end",
		"taunt_vehicle_moped_end",
	})

	ply:SetNWBool("TauntingMoped", false)
	for _, v in ipairs(ents.FindByName("MopedModel" .. entId)) do
		v:Remove()
	end
	ply:StopSound("Taunt.MopedForward")
	ply:EmitSound("Taunt.MopedEndEngineOff")
	ply:EmitSound(table.Random({"Taunt.MopedEndScoutFoot1", "Taunt.MopedEndScoutFoot2"}))
	if ply:GetPlayerClass() == "scout" then
		ply:EmitSound("scout_taunt_flip_random_flipFinish")
	end
	if endSeq then
		ply:DoTauntEvent(endSeq, true)
	end

	timer.Simple(math.max(endDur, 0.5), function()
		if not IsValid(ply) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end

function TF_EndMopedTaunt(ply)
	if not IsValid(ply) then return end
	if not ply:GetNWBool("TauntingMoped") then return end
	endMopedTaunt(ply)
end

function TF_MopedWheelie(ply)
	if not IsValid(ply) or not ply:GetNWBool("TauntingMoped") then return end
	local entId = ply:EntIndex()
	local wheelieSeq, wheelieDur = findBestSequence(ply, {"taunt_vehicle_moped_wheely"})
	if not wheelieSeq then return end
	timer.Remove("MopedLoop_" .. entId)
	ply:DoTauntEvent(wheelieSeq, true)
	ply:EmitSound("Taunt.MopedWheelieEngineRev")
	timer.Simple(math.max(wheelieDur * 0.6, 0.3), function()
		if not IsValid(ply) or not ply:GetNWBool("TauntingMoped") then return end
		ply:EmitSound(table.Random({"Taunt.MopedWheelieLand1", "Taunt.MopedWheelieLand2"}))
		if ply:GetPlayerClass() == "scout" then
			ply:EmitSound("scout_taunt_bos_exert_01")
		end
	end)
	timer.Simple(math.max(wheelieDur, 0.6), function()
		if not IsValid(ply) or not ply:GetNWBool("TauntingMoped") then return end
		if ply.__MopedLoopSeq then
			ply:DoTauntEvent(ply.__MopedLoopSeq, true)
			startMopedLoop(ply)
		end
	end)
end

concommand.Add("tf_taunt_moped_stop", function(ply)
	if not IsValid(ply) then return end
	if not ply:GetNWBool("TauntingMoped") then return end
	endMopedTaunt(ply)
end)

concommand.Add("tf_taunt_moped", function(ply)
	if ply:GetNWBool("TauntingMoped") then
		endMopedTaunt(ply)
		return
	end
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end
	if ply:GetPlayerClass() ~= "scout" then return end
	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end

	local startSeq, startDur = findBestSequence(ply, {
		"taunt_vehicle_moped_start",
		"taunt_vehicle_moped_start_layer",
		"taunt_vehicle_moped_spawn_layer",
		"taunt_vehicle_moped",
	})
	local loopSeq, loopDur = findBestSequence(ply, {
		"a_steer_matrix_moped",
		"taunt_vehicle_moped_wheely",
		"taunt_vehicle_moped",
	})
	if not startSeq then return end

	ply:DoTauntEvent(startSeq, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("TauntingMoped", true)
	ply:SetNWBool("NoWeapon", true)
	ply.__MopedTurnRate = 0
	ply.__MopedTurnInput = 0
	ply.__MopedLoopSeq = loopSeq
	ply.__MopedLoopDur = loopDur
	net.Start("ActivateTauntCam")
	net.Send(ply)
	local entId = ply:EntIndex()
	ply:EmitSound("Taunt.MopedStartHandleGrab")
	ply:EmitSound("Taunt.MopedStartShake")
	timer.Simple(0.22, function()
		if IsValid(ply) and ply:GetNWBool("TauntingMoped") then
			ply:EmitSound("Taunt.MopedStartLand")
			ply:EmitSound("Taunt.MopedStartSwoosh1")
		end
	end)
	timer.Simple(0.5, function()
		if IsValid(ply) and ply:GetNWBool("TauntingMoped") then
			ply:EmitSound("Taunt.MopedForward")
		end
	end)
	if ply:GetPlayerClass() == "scout" then
		timer.Simple(0.35, function()
			if IsValid(ply) and ply:GetNWBool("TauntingMoped") then
				ply:EmitSound("scout_taunt_flip_random_intro")
			end
		end)
	end

	local scooter = ents.Create("base_gmodentity")
	if IsValid(scooter) then
		scooter:SetModel("models/player/items/taunts/scooter/scooter.mdl")
		scooter:SetAngles(ply:GetAngles())
		scooter:SetPos(ply:GetPos())
		scooter:Spawn()
		scooter:Activate()
		scooter:SetParent(ply)
		scooter:AddEffects(EF_BONEMERGE)
		scooter:SetName("MopedModel" .. entId)
	end

	timer.Simple(math.max(startDur, 0.2), function()
		if not IsValid(ply) or not ply:GetNWBool("TauntingMoped") then return end
		if ply.__MopedLoopSeq then
			ply:DoTauntEvent(ply.__MopedLoopSeq, true)
			startMopedLoop(ply)
		end
	end)
	if ply:GetPlayerClass() == "scout" then
		timer.Create("MopedVoice_" .. entId, 7, 0, function()
			if not IsValid(ply) or not ply:GetNWBool("TauntingMoped") then
				timer.Remove("MopedVoice_" .. entId)
				return
			end
			if math.random(1, 100) <= 45 then
				ply:EmitSound("scout_taunt_flip_random_waiting2")
			end
		end)
	end

	-- Hard safety timeout so players do not get stuck in taunt state.
	timer.Create("MopedAutoStop_" .. entId, 30, 1, function()
		if not IsValid(ply) or not ply:GetNWBool("TauntingMoped") then return end
		endMopedTaunt(ply)
	end)
end)
concommand.Add("tf_taunt_scary", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/heavy/low/taunt07_halloween.vcd", 0)
	ply:DoTauntEvent("taunt07_halloween")
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end)
concommand.Add("tf_taunt_drg", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end
	local time = CurTime() + 3.5
	ply:DoAnimationEvent(ACT_DOD_PRIMARYATTACK_BOLT, true)
	ply:SetNWBool("Taunting", true)
	ply:SelectWeapon(ply:GetWeapons()[3])
	net.Start("ActivateTauntCam")
	net.Send(ply)
	ply:EmitSound("weapons/drg_wrench_teleport.wav", 100, 100)
	timer.Simple(2, function()
		ParticleEffect("teleportedin_red", ply:GetPos(), ply:GetAngles(), ply)
		ply:SetFOV(50)		
		ply:ScreenFade( SCREENFADE.IN, Color( 255, 255, 255, 150 ), 0.8, 0.65 )
		ply:EmitSound("weapons/teleporter_send.wav", 100, 100)
	end)
	timer.Simple(2.02, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		for k,v in ipairs(ents.FindByClass("obj_teleporter")) do
			if string.find(game.GetMap(), "mvm_") then
				if v:GetOwner() == ply then
					ply:SetPos(v:GetPos() + Vector(0, 30, 0))
					ply:SetFOV(0, 0.3)
				end
			else
				if v:IsExit() and v:GetOwner() == ply then
					ply:SetPos(v:GetPos() + Vector(0, 30, 0))
					ply:SetFOV(0, 0.3)
				end
			end
		end
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end)
concommand.Add("tf_taunt_drg_spawn", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end
	local time = CurTime() + 3.5
	ply:DoAnimationEvent(ACT_DOD_PRIMARYATTACK_BOLT, true)
	ply:SetNWBool("Taunting", true)
	ply:SelectWeapon(ply:GetWeapons()[3])
	net.Start("ActivateTauntCam")
	net.Send(ply)
	ply:EmitSound("weapons/drg_wrench_teleport.wav", 100, 100)
	timer.Simple(2, function()
		ParticleEffect("teleportedin_red", ply:GetPos(), ply:GetAngles(), ply)
		ply:SetFOV(50)		
		ply:ScreenFade( SCREENFADE.IN, Color( 255, 255, 255, 150 ), 0.8, 0.65 )
		ply:EmitSound("weapons/teleporter_send.wav", 100, 100)
	end)
	timer.Simple(2.02, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		ply:SetFOV(0, 0.3)
		for k,v in ipairs(ents.FindByClass("info_player_teamspawn")) do
			if ply:Team() == TEAM_BLU then
				if v:GetKeyValues()["TeamNum"] == 3 then
					ply:SetPos(v:GetPos())
				end
			elseif ply:Team() == TEAM_RED then
				if v:GetKeyValues()["TeamNum"] == 2 then
					ply:SetPos(v:GetPos())
				end
			elseif ply:Team() == TEAM_NEUTRAL then
				if v:GetKeyValues()["TeamNum"] == 2 then
					ply:SetPos(v:GetPos())
				end
			else
				if v:GetKeyValues()["TeamNum"] == 3 then
					ply:SetPos(v:GetPos())
				end
			end
		end
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end)
concommand.Add("tf_taunt_scary_demo", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/demoman/low/taunt11.vcd", 0)
	ply:DoAnimationEvent(ACT_DOD_WALK_IDLE_MP44, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	timer.Simple(time, function()
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end)
concommand.Add("tf_taunt_brutallegend", function(ply)
	if ply:GetNWBool("Taunting") == true then return end
	if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','laugh')") return end
	if not ply:IsOnGround() then return end
	if ply:WaterLevel() ~= 0 then return end

	if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end
	local time = ply:PlayScene("scenes/player/"..ply:GetPlayerClass().."/low/taunt_brutallegend.vcd", 0)
	ply:DoAnimationEvent(ACT_DOD_WALK_AIM_PSCHRECK, true)
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	ply:EmitSound("player/brutal_legend_taunt.wav")
	net.Start("ActivateTauntCam")
	net.Send(ply)
	local animent2 = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
	if ply:GetPlayerClass() == "heavy" then
	animent2:SetModel("models/player/items/heavy/brutal_guitar_xl.mdl") 
	else
	animent2:SetModel("models/workshop_partner/player/items/taunts/brutal_guitar/brutal_guitar.mdl") 	
	end
	animent2:SetAngles(ply:GetAngles())
	animent2:SetPos(ply:GetPos())
	animent2:Spawn()
	animent2:Activate()
	animent2:SetParent(ply)
	animent2:AddEffects(EF_BONEMERGE)
	animent2:SetName("BanjoModel"..ply:EntIndex())
	timer.Simple(time, function()
		for k,v in ipairs(ents.FindByName("BanjoModel"..ply:EntIndex())) do
			v:Remove()
		end
		if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
	end)
end)


concommand.Add("tf_taunt1_var", function(ply,cmd,args)
	if ply:IsHL2() then return end
	if SERVER and ply:IsSuperAdmin() then
	ply:Taunt("TLK_PLAYER_TAUNT")
	end
end)

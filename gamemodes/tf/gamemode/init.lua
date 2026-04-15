include("sv_clientfiles.lua")
include("sv_resource.lua")
include("sv_response_rules.lua")
include("bots/init.lua")
include("sv_tf_nav_generate.lua")
include("shared.lua")
include("sv_gamelogic.lua")
include("sv_hl2replace.lua")
include("sv_damage.lua")
include("sv_gargoyle.lua")
include("sv_halloween_boss.lua")
include("shd_gravitygun.lua")
include("sv_chat.lua")  
include("sv_loadout.lua")   
include("sv_mvm.lua")   
include("sv_vsh.lua")
include("shd_taunts.lua") 
include("sv_debug_bridge.lua")
AddCSLuaFile("cl_vsh_hud.lua")

local function TF_RegisterSWEPFromShared(className)
	if not isstring(className) or className == "" then return false end
	if weapons.GetStored(className) then return true end

	local function registerSWEPData(swepData)
		if not istable(swepData) or next(swepData) == nil then return false end
		swepData.ClassName = swepData.ClassName or className
		local regOk, regErr = pcall(weapons.Register, swepData, className)
		if not regOk then
			print(string.format("[TF2-Gamemode] weapons.Register failed for '%s': %s", tostring(className), tostring(regErr)))
			return false
		end
		if weapons.GetStored(className) then
			return true
		end
		print(string.format("[TF2-Gamemode] weapons.Register returned but class '%s' is still missing", tostring(className)))
		return false
	end

	local candidates = {}
	local seen = {}
	local function addCandidate(path)
		path = string.Replace(tostring(path or ""), "\\", "/")
		if path == "" or seen[path] then return end
		seen[path] = true
		candidates[#candidates + 1] = path
	end

	local gmFolder = string.Replace(tostring((GM and GM.Folder) or ""), "\\", "/")
	if gmFolder ~= "" then
		addCandidate(gmFolder .. "/entities/weapons/" .. className .. "/shared.lua")
		if not string.StartWith(gmFolder, "gamemodes/") then
			addCandidate("gamemodes/" .. gmFolder .. "/entities/weapons/" .. className .. "/shared.lua")
		end
	end

	addCandidate("gamemodes/tf/entities/weapons/" .. className .. "/shared.lua")
	addCandidate("entities/weapons/" .. className .. "/shared.lua")
	addCandidate("../entities/weapons/" .. className .. "/shared.lua")
	addCandidate("addons/tf2-gamemode/gamemodes/tf/entities/weapons/" .. className .. "/shared.lua")
	addCandidate("addons/TF2-Gamemode/gamemodes/tf/entities/weapons/" .. className .. "/shared.lua")

	local addonDirs = select(2, file.Find("addons/*", "GAME")) or {}
	for _, addonDir in ipairs(addonDirs) do
		addCandidate("addons/" .. addonDir .. "/gamemodes/tf/entities/weapons/" .. className .. "/shared.lua")
		addCandidate("addons/" .. addonDir .. "/gamemodes/TF/entities/weapons/" .. className .. "/shared.lua")
	end

	for _, path in ipairs(candidates) do
		if file.Exists(path, "LUA") then
			if className == "tf_weapon_builder" then
				print(string.format("[TF2-Gamemode] Trying builder SWEP path: %s", tostring(path)))
			end
			AddCSLuaFile(path)
			local prevSWEP = _G.SWEP
			_G.SWEP = {}
			local ok, err = pcall(include, path)
			local swepData = _G.SWEP
			_G.SWEP = prevSWEP
			if ok and registerSWEPData(swepData) then
				return true
			elseif not ok then
				print(string.format("[TF2-Gamemode] Failed loading SWEP '%s' from '%s': %s", tostring(className), tostring(path), tostring(err)))
			end
		end
	end

	-- Hard fallback: compile/register directly from source if include path resolution fails.
	for _, path in ipairs(candidates) do
		local src = file.Read(path, "LUA") or file.Read(path, "GAME")
		if isstring(src) and src ~= "" then
			local fn = CompileString(src, path, false)
			if isfunction(fn) then
				local prevSWEP = _G.SWEP
				_G.SWEP = {}
				local ok, err = pcall(fn)
				local swepData = _G.SWEP
				_G.SWEP = prevSWEP
				if ok and registerSWEPData(swepData) then
					return true
				else
					print(string.format("[TF2-Gamemode] Compile fallback failed for '%s' from '%s': %s", tostring(className), tostring(path), tostring(err)))
				end
			elseif isstring(fn) then
				print(string.format("[TF2-Gamemode] CompileString error for '%s' from '%s': %s", tostring(className), tostring(path), tostring(fn)))
			end
		end
	end

	return false
end

local function TF_RegisterCoreEngineerSWEPs()
	-- Order matters: base first, then derived classes.
	TF_RegisterSWEPFromShared("tf_weapon_base")
	TF_RegisterSWEPFromShared("tf_weapon_builder")
	TF_RegisterSWEPFromShared("tf_weapon_pda_engineer_build")
	TF_RegisterSWEPFromShared("tf_weapon_pda_engineer_destroy")
	TF_RegisterSWEPFromShared("tf_weapon_sapper")
end
TF_RegisterCoreEngineerSWEPs()

resource.AddWorkshop( "1932936017" )

local LOGFILE = "tf/log_server.txt" 
file.Delete(LOGFILE) 
file.Append(LOGFILE, "Loading serverside script\n")
local load_time = SysTime() 

include("sv_npc_relationship.lua")    
include("sv_ent_substitute.lua")  

CreateConVar("grapple_distance", -1, false)  
response_rules.Load("talker/tf_response_rules.lua") 

util.AddNetworkString("TFRagdollCreate")
util.AddNetworkString("TauntAnim")
util.AddNetworkString("TFGestureAnim")
util.AddNetworkString("UpdatePhonemes")
util.AddNetworkString("TF_PayloadSyncFull")
util.AddNetworkString("TF_PayloadSyncDelta")
util.AddNetworkString("TF_RomevisionOffer")

-- Quickfix for Valve's typo in tf_reponse_rules.txt 

--concommand.Add("lua_pick", function(pl, cmd, args)
--	getfenv()[args[1]] = pl:GetEyeTrace().Entity	
--end) 


concommand.Add("voicemenu_gesture", function(pl, cmd, args)
	local a, b = tonumber(args[1]), tonumber(args[2])
	if not a or not b then return end
		if a == 0 and b == 0 then
			if (pl:GetPlayerClass() == "hl1scientist") then
				EmitSentence( "SC_PHELLO" .. math.random( 0, 6 ), pl:GetPos(), pl:EntIndex()	, CHAN_AUTO, 1, 75, 0, 100 )
			end
		elseif a == 0 and b == 1 then
			if (pl:GetPlayerClass() == "hl1scientist") then
				EmitSentence( table.Random({"SC_GOODWORK","SC_HARDLYNOTICE"}), pl:GetPos(), pl:EntIndex()	, CHAN_AUTO, 1, 75, 0, 100 )
			end
		elseif a == 0 and b == 2 then
			if (pl:GetPlayerClass() == "hl1scientist") then
				EmitSentence( table.Random({"SC_ZOMBIE1A","SC_GETAWAY"}), pl:GetPos(), pl:EntIndex()	, CHAN_AUTO, 1, 75, 0, 100 )
			end
		elseif a == 0 and b == 3 then
			if (pl:GetPlayerClass() == "hl1scientist") then
				EmitSentence( table.Random({"SC_ZOMBIE1A"}), pl:GetPos(), pl:EntIndex(), CHAN_VOICE, 1, 75, 0, 100 )
			end
		elseif a == 0 and b == 6 then
			if (pl:GetPlayerClass() == "hl1scientist") then
				EmitSentence( table.Random({"SC_ANSWER10","SC_ANSWER16","SC_ANSWER14","SC_ANSWER8","SC_ANSWER9"}), pl:GetPos(), pl:EntIndex(), CHAN_VOICE, 1, 75, 0, 100 )
			end
		elseif a == 0 and b == 7 then
			if (pl:GetPlayerClass() == "hl1scientist") then
				EmitSentence( table.Random({"SC_ANSWER19","SC_ANSWER17","SC_ANSWER18","SC_ANSWER20","SC_ANSWER25"}), pl:GetPos(), pl:EntIndex(), CHAN_VOICE, 1, 75, 0, 100 )
			end
		elseif a == 2 and b == 8 then
			NextSpeak = CurTime() + 1.5
			if not NextSpeak and CurTime()>=NextSpeak then
				if pl:GetPlayerClass() == "heavy" or pl:GetPlayerClass() == "scout" then
					pl:EmitSound("vo/"..pl:GetPlayerClass().."_mvm_loot_godlike0"..math.random(1,3)..".wav")
				else
					pl:EmitSound("vo/"..pl:GetPlayerClass().."_mvm_loot_godlike0"..math.random(1,3)..".wav")
				end
			end
		elseif a == 1 and b == 0 then
			if (pl:GetPlayerClass() == "hl1scientist") then
				EmitSentence( "SC_HEAR"..math.random(0,2), pl:GetPos(), pl:EntIndex(), CHAN_VOICE, 1, 75, 0, 100 )
			end
		elseif a == 1 and b == 1 then
			if (pl:GetPlayerClass() == "hl1scientist") then
				EmitSentence( "SC_QUESTION"..math.random(0,26), pl:GetPos(), pl:EntIndex(), CHAN_VOICE, 1, 75, 0, 100 )
			end
		elseif a == 1 and b == 2 then
			if (pl:GetPlayerClass() == "hl1scientist") then
				EmitSentence( "SC_ANSWER"..math.random(0,29), pl:GetPos(), pl:EntIndex(), CHAN_VOICE, 1, 75, 0, 100 )
			end
		end
		if pl:GetPlayerClass() == "zombie" then
			pl:EmitSound("Zombie.Alert")
		end
end)

local function tfcc_print(ply, msg)
	if IsValid(ply) then
		ply:PrintMessage(HUD_PRINTTALK, "[TF2-Gamemode] " .. msg)
	else
		print("[TF2-Gamemode] " .. msg)
	end
end

local function tfcc_find_player(invoker, token)
	if not token or token == "" or token == "me" then
		return IsValid(invoker) and invoker or nil
	end

	local n = tonumber(token)
	if n then
		local ent = Entity(n)
		if IsValid(ent) and ent:IsPlayer() then
			return ent
		end
	end

	token = string.lower(token)
	for _, p in ipairs(player.GetAll()) do
		if string.find(string.lower(p:Nick()), token, 1, true) then
			return p
		end
	end

	return nil
end

concommand.Add("addcond", function(pl, cmd, args)
	if not GetConVar("sv_cheats"):GetBool() then
		tfcc_print(pl, "sv_cheats must be enabled.")
		return
	end

	if #args < 1 then
		tfcc_print(pl, "Usage: addcond <cond> [duration] [target]  OR  addcond <target> <cond> [duration]")
		return
	end

	local target, cond, duration
	local first_num = tonumber(args[1])
	local second_num = tonumber(args[2])

	if first_num then
		target = IsValid(pl) and pl or nil
		cond = first_num
		duration = tonumber(args[2])
		if args[3] then
			target = tfcc_find_player(pl, args[3])
		end
	else
		target = tfcc_find_player(pl, args[1])
		cond = second_num
		duration = tonumber(args[3])
	end

	if not IsValid(target) then
		tfcc_print(pl, "Target player not found.")
		return
	end

	if not cond then
		tfcc_print(pl, "Invalid condition. Example: addcond 11 5 me")
		return
	end

	if cond < 0 or (TF_COND_LAST and cond >= TF_COND_LAST) then
		tfcc_print(pl, "Condition out of range.")
		return
	end

	if duration == nil then
		duration = PERMANENT_CONDITION or -1
	end

	local provider = IsValid(pl) and pl or target
	target:AddCond(cond, duration, provider)

	local label = "TF_COND_" .. tostring(cond)
	for k, v in pairs(TF_COND or {}) do
		if v == cond then
			label = k
			break
		end
	end

	if duration == (PERMANENT_CONDITION or -1) then
		tfcc_print(pl, string.format("Added %s to %s permanently.", label, target:Nick()))
	else
		tfcc_print(pl, string.format("Added %s to %s for %.2fs.", label, target:Nick(), duration))
	end
end)

concommand.Add("removecond", function(pl, cmd, args)
	if not GetConVar("sv_cheats"):GetBool() then
		tfcc_print(pl, "sv_cheats must be enabled.")
		return
	end

	if #args < 1 then
		tfcc_print(pl, "Usage: removecond <cond> [target]  OR  removecond <target> <cond>")
		return
	end

	local target, cond
	local first_num = tonumber(args[1])
	local second_num = tonumber(args[2])

	if first_num then
		target = IsValid(pl) and pl or nil
		cond = first_num
		if args[2] then
			target = tfcc_find_player(pl, args[2])
		end
	else
		target = tfcc_find_player(pl, args[1])
		cond = second_num
	end

	if not IsValid(target) then
		tfcc_print(pl, "Target player not found.")
		return
	end

	if not cond then
		tfcc_print(pl, "Invalid condition.")
		return
	end

	target:RemoveCond(cond, true)
	tfcc_print(pl, string.format("Removed condition %d from %s.", cond, target:Nick()))
end)
concommand.Add("taunt", function(pl)
	if not IsValid(pl) then return end
	if not pl.TFTaunt then return end

	-- Route through shared taunt logic so +taunt, HUD taunt, and console taunt
	-- all honor the same checks/weapon-specific behavior.
	local slot = "1"
	local w = pl:GetActiveWeapon()
	if IsValid(w) and w.GetSlot then
		slot = tostring((w:GetSlot() or 0) + 1)
	end

	pl:TFTaunt(slot)
end)

concommand.Add("weapon_taunt", function(pl)
	if not IsValid(pl) then return end
	if not pl.TFTaunt then return end

	local slot = "1"
	local w = pl:GetActiveWeapon()
	if IsValid(w) and w.GetSlot then
		slot = tostring((w:GetSlot() or 0) + 1)
	end

	pl:TFTaunt(slot)
end)

concommand.Add("select_slot", function(pl, cmd, args)
	local n = tonumber(args[1] or "")
	local w = pl:GetActiveWeapon()
	if n and w and w:IsValid() and w.OnSlotSelected then
		w:OnSlotSelected(n)
	end
end)

concommand.Add("decapme", function(pl, cmd, args)
--	pl:SetNWBool("ShouldDropDecapitatedRagdoll", true)
	pl:AddDeathFlag(DF_DECAP)
	pl:Kill()
end)

concommand.Add("tf_stripme", function(pl, cmd, args)
	pl:StripWeapons()
end) 

 
hook.Add("PlayerSelectSpawn", "PlayerSelectTeamSpawn", function(pl)
	local hasTFTeamSpawns = ents.FindByClass("info_player_teamspawn")[1] ~= nil
	if hasTFTeamSpawns then return end

	local redSpawns = ents.FindByClass("info_player_redspawn")
	local bluSpawns = ents.FindByClass("info_player_bluspawn")
	if #redSpawns == 0 and #bluSpawns == 0 then return end

	if pl:Team() == TEAM_RED or pl:Team() == TEAM_NEUTRAL then
		if #redSpawns > 0 then
			return redSpawns[math.random(#redSpawns)]
		end
	elseif pl:Team() == TEAM_BLU or pl:Team() == TF_TEAM_PVE_INVADERS then
		if #bluSpawns > 0 then
			return bluSpawns[math.random(#bluSpawns)]
		end
	end
end)

hook.Add("PlayerHurt", "RoboIsHurt", function( ply, pos, foot, sound, volume, rf )
	local dmginfo = DamageInfo()
	if ply:Alive() and ply:GetModel() == "models/l4d2/survivor_mechanic.mdl" then
		if ply:Health() >= 50 then
			ply:EmitSound("player/survivor/voice/mechanic/hurtminor0"..math.random(1,7)..".wav")
		else
			ply:EmitSound("player/survivor/voice/mechanic/hurtcritical0"..math.random(2,5)..".wav")
		end 
	end
	if ply:GetPlayerClass() == "combinesoldier" then
		EmitSentence( "COMBINE_PAIN" .. math.random( 0, 3 ), ply:GetPos(), 1, CHAN_AUTO, 1, 75, 0, 100 )
	end
	if ply:GetPlayerClass() == "metrocop" then
		EmitSentence( "METROPOLICE_PAIN" .. math.random( 0, 3 ), ply:GetPos(), 1, CHAN_AUTO, 1, 75, 0, 100 )
	end
	
	if not ply:IsHL2() and ply:GetInfoNum("tf_hhh", 0) == 1 then
		ply:EmitSound( "Halloween.HeadlessBossPain" ) -- Play the footsteps hunter is using
	end

	if ply:GetPlayerClass() == "merc_dm" then
		if ( shouldOccur ) then
			if ply:Health() <= 50 then
				ply:EmitSound("vo/mercenary_painsevere0"..math.random(1,6)..".wav")
			elseif dmginfo:IsFallDamage() then
				ply:EmitSound("vo/mercenary_painsevere0"..math.random(1,6)..".wav")
			else
				ply:EmitSound("vo/mercenary_painsharp0"..math.random(1,8)..".wav")
			end
			shouldOccur = false
			timer.Simple( hurtdelay, function() shouldOccur = true end )
		end
	end
	
	
	if not ply:IsHL2() and ply:GetInfoNum("jakey_antlionfbii", 0) == 1 then
		ply:EmitSound("npc/antlion/shell_impact"..math.random(1,4)..".wav", 80, 100)
		if ( shouldOccur ) then
			ply:EmitSound( "npc/antlion_guard/antlion_guard_pain"..math.random(1,2)..".wav", 150, math.random(87, 103) )
			shouldOccur = false
			timer.Simple( hurtdelay, function() shouldOccur = true end )
		end
	end
	if ply:GetInfoNum("dylan_rageheavy", 0) == 1 then
		ply:EmitSound("vo/heavy_paincrticialdeath0"..math.random(1,3)..".wav", 150, 100)
		if ply:GetInfoNum("tf_giant_robot", 0) == 1 then
				ply:SetModelScale(6) 
				ply:EmitSound("music/stingers/hl1_stinger_song28.wav", 0, 80)
				ply:EmitSound("music/stingers/hl1_stinger_song28.wav", 0, 75)
		 end
	end
	if (ply:IsHL2()) then
		ply:GetViewModel():SetMaterial("")
	else
		ply:GetViewModel():SetMaterial("color")
	end
	if not ply:IsHL2() and ply:GetInfoNum("tf_robot", 0) == 1 then
		ply:EmitSound( "MVM_Giant.BulletImpact" )
	end 
	if not ply:IsHL2() and ply:GetInfoNum("tf_mvm_giant_voodoo", 0) == 1 then
		ply:EmitSound( "MVM_Giant.BulletImpact" )
	end	
	if ply:GetPlayerClass() == "spy" then
		for k,v in pairs(ents.FindByClass("tf_weapon_invis_dringer")) do
			if v.Owner == ply and v.dt.Ready == true then
				v:StartCloaking()
				ply:CreateRagdoll()
			end
		end
	end
end)


concommand.Add("voicemenu_combine", function(pl, cmd, args)
	local a, b = tonumber(args[1]), tonumber(args[2])
	if not a or not b then return end

	if a == 0 and b == 6 then
		if pl:GetPlayerClass() == "combinesoldier" then
			EmitSentence( "COMBINE_ANSWER" .. math.random( 0, 4 ), pl:GetPos(), 1, CHAN_AUTO, 1, 95, 0, 100 )
		end
	end
	if a == 0 and b == 2 then
		if pl:GetPlayerClass() == "combinesoldier" then
			EmitSentence( "METROPOLICE_IDLE_HARASS_PLAYER1", pl:GetPos(), 1, CHAN_AUTO, 1, 95, 0, 100 )
		end
	end
	if a == 0 and b == 3 then
		if pl:GetPlayerClass() == "combinesoldier" then
			EmitSentence( "METROPOLICE_IDLE_HARASS_PLAYER0", pl:GetPos(), 1, CHAN_AUTO, 1, 95, 0, 100 )
		end
	end
	if a == 2 and b == 5 then
		if pl:GetPlayerClass() == "combinesoldier" then
			EmitSentence( "COMBINE_LAST_OF_SQUAD" .. math.random( 0, 7 ), pl:GetPos(), 1, CHAN_AUTO, 1, 95, 0, 100 )
		end
	end
	if a == 1 and b == 0 then
		if pl:GetPlayerClass() == "combinesoldier" then
			EmitSentence( "COMBINE_ALERT" .. math.random( 0, 9 ), pl:GetPos(), 1, CHAN_AUTO, 1, 95, 0, 100 )
		end
	end
	if a == 1 and b == 1 then
		if pl:GetPlayerClass() == "combinesoldier" then
			EmitSentence( "COMBINE_TAUNT" .. math.random( 0, 2 ), pl:GetPos(), 1, CHAN_AUTO, 1, 95, 0, 100 )
		end
	end
	if a == 1 and b == 2 then
		if pl:GetPlayerClass() == "combinesoldier" then
			EmitSentence( "COMBINE_QUEST" .. math.random( 0, 5 ), pl:GetPos(), 1, CHAN_AUTO, 1, 95, 0, 100 )
		end
	end
end)


hook.Add("PlayerDeath", "PlayerRobotDeath", function( ply, attacker, inflictor)
	local dmginfo = DamageInfo()
	ply:SetParent()
	for k,v in pairs(ents.FindInSphere(ply:GetPos(), 110)) do
		if v:IsPlayer() then
			v:SetParent()
		end
	end
	
	if attacker:IsPlayer() and !attacker:IsFriendly(ply) and attacker:GetPlayerClass() == "combinesoldier" then
		EmitSentence( "COMBINE_PLAYER_DEAD" .. math.random( 0, 6 ), attacker:GetPos(), 1, CHAN_AUTO, 1, 75, 0, 100 )
	end
	
	for k,v in ipairs(team.GetPlayers(ply:Team())) do
		if v:Alive() and v:Nick() != ply:Nick() and v:GetPlayerClass() == "combinesoldier" then
			EmitSentence( "COMBINE_MAN_DOWN" .. math.random( 0, 4 ), v:GetPos(), 1, CHAN_AUTO, 1, 75, 0, 100 )
		end
	end	
	
	for k,v in ipairs(team.GetPlayers(ply:Team())) do
		if v:Alive() and v:Nick() != ply:Nick() and v:GetPlayerClass() == "metrocop" then
			EmitSentence( "METROPOLICE_MAN_DOWN" .. math.random( 0, 3 ), v:GetPos(), 1, CHAN_AUTO, 1, 75, 0, 100 )
		end
	end

	if ply:IsHL2() then
		if ply:GetPlayerClass() == "gmodplayer" then
			if ply:GetModel() == "models/l4d2/survivor_mechanic.mdl" then
				ply:EmitSound("player/survivor/voice/mechanic/deathscream0"..math.random(1,6)..".wav")
			elseif ply:GetModel() == "models/l4d2/survivor_namvet.mdl" then
				ply:EmitSound("player/survivor/voice/namvet/deathscream0"..math.random(1,8)..".wav")
			elseif ply:GetModel() == "models/l4d2/survivor_manager.mdl" then
				ply:EmitSound("player/survivor/voice/manager/deathscream0"..math.random(1,9)..".wav")
			elseif ply:GetModel() == "models/l4d2/survivor_biker.mdl" then
				ply:EmitSound("player/survivor/voice/biker/deathscream0"..math.random(1,9)..".wav")
			end
		end
	end
	if ply:GetPlayerClass() == "charger" then
		ply:EmitSound("ChargerZombie.Death")
	end
	if ply:GetPlayerClass() == "combinesoldier" then
		EmitSentence( "COMBINE_DIE" .. math.random( 0, 3 ), ply:GetPos(), 1, CHAN_AUTO, 1, 75, 0, 100 )
	end
 
	if ply:GetPlayerClass() == "metrocop" then
		EmitSentence( "METROPOLICE_DIE" .. math.random( 0, 4 ), ply:GetPos(), 1, CHAN_AUTO, 1, 75, 0, 100 )
	end
	
	if ply:GetPlayerClass() == "tank_l4d" then
		for k,v in ipairs(player.GetAll()) do
			v:StopSound("TankMusicLoop")
			v:StopSound("TankMidnightMusicLoop")
		end
		
		if (string.find(ply:GetModel(),"l4d1")) then
			ply:EmitSound("L4D1_HulkZombie.Death")
		else
			ply:EmitSound("HulkZombie.Death")
		end
	end
	if ply:GetPlayerClass() == "jockey" then
		ply:EmitSound("JockeyZombie.Death")
	end
	if not ply:IsHL2() and ply:GetInfoNum("tf_sentrybuster", 0) == 1 then			
		for k,v in pairs(player.GetAll()) do
			if not v:IsFriendly(ply) and v:Alive() and not v:IsHL2() then
				if v:GetPlayerClass() == "heavy" then
					v:EmitSound("vo/heavy_mvm_sentry_buster02.wav", 85, 100, 1, CHAN_REPLACE)
				elseif v:GetPlayerClass() == "medic" then
					v:EmitSound("vo/medic_mvm_sentry_buster02.wav", 85, 100, 1, CHAN_REPLACE)
				elseif v:GetPlayerClass() == "soldier" then
					v:EmitSound("vo/soldier_mvm_sentry_buster02.wav", 85, 100, 1, CHAN_REPLACE)
				elseif v:GetPlayerClass() == "engineer" then
					v:EmitSound("vo/engineer_mvm_sentry_buster02.wav", 85, 100, 1, CHAN_REPLACE)
				end
			end
		end
	end
	if not ply:IsHL2() and ply:GetInfoNum("jakey_antlionfbii", 0) == 1 then			
		ply:EmitSound("npc/antlion_guard/antlion_guard_die"..math.random(1,2)..".wav", 120, 100)
	end
	if not ply:IsHL2() and ply:GetInfoNum("tf_merasmus", 0) == 1 then
		ply:EmitSound("Halloween.MerasmusBanish")
		ply:EmitSound("Halloween.HeadlessBossDeath")
		ply:PrecacheGibs()
		ply:GibBreakClient( Vector(math.random(1,4), math.random(1,4), math.random(1,4)) )
		ply:GetRagdollEntity():Remove()
	end
	if attacker:IsPlayer() and victim ~= attacker and attacker:GetInfoNum("tf_merasmus", 0) == 1 then
		attacker:EmitSound("Halloween.MerasmusBombTaunt")
	end
	if attacker:IsPlayer() and victim ~= attacker and attacker:GetInfoNum("tf_saxxy", 0) == 1 then
		attacker:EmitSound("SaxtonHale.KillVictim")
	end
	if attacker:IsPlayer() and victim ~= attacker and attacker:GetInfoNum("tf_merasmus", 0) == 1 and victim:IsNPC() then
		attacker:EmitSound("Halloween.MerasmusBombTaunt")
	end
	if not ply:IsHL2() and ply:GetInfoNum("tf_robot", 0) == 1 then
		if eyeparticle1:IsValid() then
			eyeparticle1:Fire("kill", 0.001)
		end
		if eyeparticle2:IsValid() then
			eyeparticle2:Fire("kill", 0.001)
		end
		if ply:GetPlayerClass() == "scout" then
			ply:EmitSound("vo/mvm/norm/scout_mvm_painsevere0"..math.random(1,6)..".mp3", 95, 100, 1, CHAN_VOICE)
		elseif ply:GetPlayerClass() == "soldier" then
			ply:EmitSound("vo/mvm/norm/soldier_mvm_painsevere0"..math.random(1,6)..".mp3", 95, 100, 1, CHAN_VOICE)
		elseif ply:GetPlayerClass() == "pyro" then
			ply:EmitSound("vo/mvm/norm/pyro_mvm_painsevere0"..math.random(1,6)..".mp3", 95, 100, 1, CHAN_VOICE)
		elseif ply:GetPlayerClass() == "demoman" then
			ply:EmitSound("vo/mvm/norm/demoman_mvm_painsevere0"..math.random(1,4)..".mp3", 95, 100, 1, CHAN_VOICE)
		elseif ply:GetPlayerClass() == "heavy" then
			ply:EmitSound("vo/mvm/norm/heavy_mvm_painsevere0"..math.random(1,3)..".mp3", 95, 100, 1, CHAN_VOICE)
		elseif ply:GetPlayerClass() == "engineer" then
			ply:EmitSound("vo/mvm/norm/engineer_mvm_painsevere0"..math.random(1,7)..".mp3", 95, 100, 1, CHAN_VOICE)
		elseif ply:GetPlayerClass() == "medic" then
			ply:EmitSound("vo/mvm/norm/medic_mvm_painsevere0"..math.random(1,4)..".mp3", 95, 100, 1, CHAN_VOICE)
		elseif ply:GetPlayerClass() == "sniper" then
			ply:EmitSound("vo/mvm/norm/sniper_mvm_painsevere0"..math.random(1,4)..".mp3", 95, 100, 1, CHAN_VOICE)
		elseif ply:GetPlayerClass() == "spy" then
			ply:EmitSound("vo/mvm/norm/spy_mvm_painsevere0"..math.random(1,5)..".mp3", 95, 100, 1, CHAN_VOICE)
		end
	end
	ply:StopSound("BusterLoop")
	if not ply:IsHL2() and ply:GetPlayerClass() == "sentrybuster" then
		ply:EmitSound("MVM.SentryBusterExplode")
	end
	if not ply:IsHL2() and ply:GetInfoNum("tf_sentrybuster", 0) == 1 then
		ply:EmitSound("MVM.SentryBusterExplode")
	end
	if ply:GetPlayerClass() == "giantheavyheater" and ply:GetPlayerClass() == "giantheavyshotgun" and ply:GetPlayerClass() == "giantsoldierrapidfire" and ply:GetPlayerClass() == "giantsoldiercharged" then
		ply:EmitSound( "MVM.GiantCommonExplodes" ) -- Play the footsteps hunter is using
		ply:EmitSound( "MVM.GiantCommonExplodes" ) -- Play the footsteps hunter is using
		ply:PrecacheGibs()
		ply:GibBreakClient( Vector(math.random(1,4), math.random(1,4), math.random(1,4)) )
		ply:GetRagdollEntity():Remove()	
		for k,v in pairs(player.GetAll()) do
			if not v:IsFriendly(ply) and v:Alive() and not v:IsHL2() then
				if v:GetPlayerClass() == "heavy" then
					v:EmitSound("vo/heavy_mvm_giant_robot02.wav", 85, 100, 1, CHAN_REPLACE)
				elseif v:GetPlayerClass() == "medic" then
					v:EmitSound("vo/medic_mvm_giant_robot02.wav", 85, 100, 1, CHAN_REPLACE)
				end
			end
		end
	end
	if not ply:IsHL2() and ply:GetInfoNum("tf_mvm_giant_voodoo", 0) == 1 then
		ply:EmitSound( "MVM.GiantCommonExplodes" ) -- Play the footsteps hunter is using
		ply:PrecacheGibs()
		ply:GibBreakClient( Vector(math.random(1,4), math.random(1,4), math.random(1,4)) )
		ply:GetRagdollEntity():Remove()	
		for k,v in pairs(player.GetAll()) do
			if not v:IsFriendly(ply) and v:Alive() and not v:IsHL2() then
				if ply:GetPlayerClass() == "heavy" then
					ply:EmitSound("vo/heavy_mvm_giant_robot02.wav", 85, 100, 1, CHAN_REPLACE)
				elseif ply:GetPlayerClass() == "medic" then
					ply:EmitSound("vo/medic_mvm_giant_robot02.wav", 85, 100, 1, CHAN_REPLACE)
				end
			end
		end
	end
end)



hook.Remove("PlayerFootstep", "TA:Paint_Footsteps")

local function CopyPoseParams(pEntityFrom, pEntityTo)
	if (SERVER) then
		for i = 0, pEntityFrom:GetNumPoseParameters() - 1 do
			local sPose = pEntityFrom:GetPoseParameterName(i)
			pEntityTo:SetPoseParameter(sPose, pEntityFrom:GetPoseParameter(sPose))
		end
	else
		for i = 0, pEntityFrom:GetNumPoseParameters() - 1 do
			local flMin, flMax = pEntityFrom:GetPoseParameterRange(i)
			local sPose = pEntityFrom:GetPoseParameterName(i)
			pEntityTo:SetPoseParameter(sPose, math.Remap(pEntityFrom:GetPoseParameter(sPose), 0, 1, flMin, flMax))
		end
	end
end

concommand.Add( "tf_sentrybuster_explode", function( ply, cmd )

	if (ply:GetPlayerClass() == "sentrybuster") then
	ply:SetNoDraw(true)
	ply:EmitSound("MVM.SentryBusterSpin")
	ply:SetNWBool("Taunting", true)
	ply:SetNWBool("NoWeapon", true)
	net.Start("ActivateTauntCam")
	net.Send(ply)
	local animent = ents.Create( 'base_gmodentity' ) -- The entity used as a reference for the bone positioning
	animent:SetModel( ply:GetModel() )
	animent:SetModelScale( ply:GetModelScale() )
	timer.Create("SetAnimPos", 0.01, 0, function()
		if not animent:IsValid() then timer.Stop("SetAnimPos") return end
		animent:SetPos( ply:GetPos() )
		animent:SetAngles( ply:GetAngles() )
	end )
	animent:SetNoDraw( false ) -- The ragdoll is the thing getting seen
	animent:Spawn()
	
	animent:SetSequence( "sentry_buster_preexplode" ) -- If the sequence isn't valid, the sequence length is 0, so the timer takes care of things
	animent:SetPlaybackRate( 1 )
	animent.AutomaticFrameAdvance = true
	
	animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
	animent:PhysicsInit( SOLID_OBB )
	animent:SetMoveType( MOVETYPE_FLYGRAVITY )
	animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
	animent:PhysWake()
	
	function animent:Think() -- This makes the animation work
		self:NextThink( CurTime() )
		return true
	end
	timer.Simple(2.5, function()
		ParticleEffect("asplode_hoodoo_shockwave", ply:GetPos() + Vector(0,0,35), ply:GetAngles())
		ParticleEffect("asplode_hoodoo_shockwave", ply:GetPos() + Vector(0,0,35), ply:GetAngles())
		ParticleEffect("asplode_hoodoo_shockwave", ply:GetPos() + Vector(0,0,35), ply:GetAngles())
		ParticleEffect("asplode_hoodoo_shockwave", ply:GetPos() + Vector(0,0,35), ply:GetAngles())
	
		ParticleEffect("cinefx_goldrush_flash", ply:GetPos(), ply:GetAngles())
		ParticleEffect("fireSmoke_Collumn_mvmAcres", ply:GetPos(), Angle())
		ParticleEffect("fluidSmokeExpl_ring_mvm", ply:GetPos() + Vector(50,50,25), ply:GetAngles())
		ParticleEffect("fluidSmokeExpl_ring_mvm", ply:GetPos() + Vector(-50,-50,25), ply:GetAngles())
		ParticleEffect("fluidSmokeExpl_ring_mvm", ply:GetPos() + Vector(-50,50,25), ply:GetAngles())
		ParticleEffect("fluidSmokeExpl_ring_mvm", ply:GetPos() + Vector(50,-50,25), ply:GetAngles())

		ParticleEffect("fireSmoke_Collumn_mvmAcres_sm", ply:GetPos() + Vector(50,50,25), ply:GetAngles())
		ParticleEffect("fireSmoke_Collumn_mvmAcres_sm", ply:GetPos() + Vector(-50,-50,25), ply:GetAngles())
		ParticleEffect("fireSmoke_Collumn_mvmAcres_sm", ply:GetPos() + Vector(-50,50,25), ply:GetAngles())
		ParticleEffect("fireSmoke_Collumn_mvmAcres_sm", ply:GetPos() + Vector(50,-50,25), ply:GetAngles())

		if animent:IsValid() then
			animent:Remove() 
		end
	
		ply:EmitSound("MvM.SentryBusterExplode")
		ply:SetNoDraw(false)

		ply:SetNWBool("Taunting", false)
		ply:SetNWBool("NoWeapon", false)
		net.Start("DeActivateTauntCam")
		net.Send(ply)
		if ply:GetRagdollEntity():IsValid() then
			ply:GetRagdollEntity():Remove()
		end
		for k,v in pairs(ents.FindInSphere(ply:GetPos(), 800)) do 
			if !v:IsPlayer() and v:Health() >= 0 and not v:IsFriendly(ply) then
				v:TakeDamage( v:Health(), ply, ply:GetActiveWeapon() )
			elseif v:IsPlayer() and not v:IsFriendly(ply) and v:Alive() and v:Nick() != ply:Nick() then
				v:TakeDamage( v:Health(), ply, ply:GetActiveWeapon() )
			end
		end
		ply:TakeDamage( ply:Health(), ply, ply:GetActiveWeapon() )
	end)
	end
end)


hook.Add( "DoAnimationEvent" , "AnimEventTest" , function( ply , event , data )
	if event == PLAYERANIMEVENT_ATTACK_GRENADE then
		if data == 123 then
			ply:AnimRestartGesture( GESTURE_SLOT_GRENADE, ACT_GMOD_GESTURE_ITEM_THROW, true )
			return ACT_INVALID
		end

		if data == 321 then
			ply:AnimRestartGesture( GESTURE_SLOT_GRENADE, ACT_GMOD_GESTURE_ITEM_DROP, true )
			return ACT_INVALID
		end
	end
end )

concommand.Add("merc_impulse101", function(ply)
	if ply:GetPlayerClass() == "merc_dm" then
		ply:Give("tf_weapon_pistol_merc")
		ply:Give("tf_weapon_shotgun_merc")
		ply:Give("tf_weapon_rocketlauncher_merc")
		ply:Give("tf_weapon_rocketlauncher_rapidfire") 
		ply:Give("tf_weapon_nailgun_merc")
		ply:Give("tf_weapon_revolver_merc")
		ply:Give("tf_weapon_grenadelauncher_merc")
		ply:Give("tf_weapon_smg_dm_merc")
		ply:Give("tf_weapon_smg_merc")
		ply:Give("tf_weapon_gatlinggun")
		ply:Give("tf_weapon_supershotgun_merc")
		ply:Give("tf_weapon_sniperrifle_merc")
		ply:Give("tf_weapon_medigun_merc")
		ply:Give("tf_weapon_flamethrower_merc")
		ply:Give("tf_weapon_knife_merc")
		ply:Give("tf_weapon_railgun_merc")
		ply:Give("tf_weapon_minigun_merc")
		ply:Give("tf_weapon_pda_engineer_destroy_merc")
		ply:Give("tf_weapon_pda_engineer_build_merc")
		ply:Give("tf_weapon_wrench_merc")
		ply:Give("tf_weapon_scattergun_merc")
		ply:Give("tf_weapon_pipebomblauncher_merc")
		ply:GiveItem("TF_WEAPON_BUILDER")
		ply:EmitSound("items/spawn_item.wav")
	end
end)

concommand.Add("tf_givegravitygun", function(ply) 
	if not ply:IsHL2() then
		ply:Give("tf_weapon_physcannon") 
		ply:EmitSound("weapons/physcannon/physcannon_charge.wav")
	end
end)



concommand.Add("tf_givemegagravitygun", function(ply) 
	if not ply:IsHL2() then
		ply:Give("tf_weapon_superphyscannon") 
		ply:EmitSound("weapons/physcannon/superphys_chargeup.wav")
	end
end)


local function PlayerGiantBotSpawn( ply, mv )
	if (!IsValid(ply)) then return end
	-- dun dun dun dun dun dun dun dun DO THE LOSKY ~ seamusmario
	-- oh hell no boy, don't you be mentioning that leafer ~ future seamusmario
	--[[
	if ply:GetModel() == "models/player/loskybasics/losky_pm.mdl" then
		ply:EmitSound("vo/losky_respawn01.wav")
	end]]
	timer.Simple(0.4, function()
		if not IsValid(ply) then return end
		if ply:GetInfoNum("tf_lazyzombie", 0) == 1 then
			if ply:GetPlayerClass() != "demoman" then
				ply:SetModel("models/lazy_zombies_v2/"..ply:GetPlayerClass()..".mdl")
			else
				ply:SetModel("models/lazy_zombies_v2/demo.mdl")
			end
		end
		if GetConVar("tf_muselk_zombies"):GetBool() then
			if ply:Team() == TEAM_RED then
				ply:SetPlayerClass("engineer")
				
				ply:PrintMessage(HUD_PRINTCENTER, "You are now defending! You must find a place to hide! If the zombies team doesn't do it in the next 5 minutes, YOU WIN!")
					
			elseif ply:Team() == TEAM_NEUTRAL then
				ply:SetTeam(TEAM_RED)
				ply:SetPlayerClass("engineer")
				
				ply:PrintMessage(HUD_PRINTCENTER, "You are now defending! You must find a place to hide! If the zombies team doesn't do it in the next 5 minutes, YOU WIN!")
			elseif ply:Team() == TEAM_BLU then
				ply:GetWeapons()[1]:Remove()
				ply:GetWeapons()[2]:Remove()
				ply:SetPos(Vector(9086.43, 10060.49, -10786.25)) 
				ply:PrintMessage(HUD_PRINTCENTER, "You are now attacking! You must find the engineers and infect them! If your team doesn't do it in the next 5 minutes, YOU LOSE!")
				timer.Simple(0.4, function()
					if ply:GetPlayerClass() != "demoman" then
						ply:SetModel("models/lazy_zombies_v2/"..ply:GetPlayerClass()..".mdl")
					else
						ply:SetModel("models/lazy_zombies_v2/demo.mdl")
					end
				end)
			end
		end
	end)
	timer.Simple(0.3, function()
		if (IsValid(ply)) then
			if not ply:IsHL2() and ply:GetInfoNum("tf_sentrybuster", 0) == 1 then
				if ply:GetPlayerClass() != "demoman" then ply:SetPlayerClass("demoman") end
				for k,v in pairs(player.GetAll()) do
					if not v:IsFriendly(ply) and v:Alive() and not v:IsHL2() then
						if v:GetPlayerClass() == "heavy" then
							v:EmitSound("vo/heavy_mvm_sentry_buster01.wav", 85, 100, 1, CHAN_REPLACE)
						elseif v:GetPlayerClass() == "medic" then
							v:EmitSound("vo/medic_mvm_sentry_buster01.wav", 85, 100, 1, CHAN_REPLACE)
						elseif v:GetPlayerClass() == "soldier" then
							v:EmitSound("vo/soldier_mvm_sentry_buster01.wav", 85, 100, 1, CHAN_REPLACE)
						elseif v:GetPlayerClass() == "engineer" then
							v:EmitSound("vo/engineer_mvm_sentry_buster01.wav", 85, 100, 1, CHAN_REPLACE)
						end
					end
				end
				for k,v in ipairs(player.GetAll()) do
					v:EmitSound("Announcer.MVM_Sentry_Buster_Alert")
				end
				ply:EmitSound("MVM.SentryBusterIntro")
				ply:EmitSound("BusterLoop")
				ply:SetModel("models/bots/demo/bot_sentry_buster.mdl")
				ply:SetHealth(3600)
				ply:StripWeapon("tf_weapon_grenadelauncher")
				ply:StripWeapon("tf_weapon_pipebomblauncher")
				ply:SetModelScale(1.75)
				ply:SetClassSpeed(400)

				timer.Create("SentryBusterIntroLoop", 4, 0, function()
					if not ply:Alive() then timer.Stop("HHHSpeed2") return end
					if ply:GetInfoNum("tf_sentrybuster", 0) == 0 then timer.Stop("HHHSpeed2") return end
					ply:EmitSound("MVM.SentryBusterIntro")
				end)
			
				timer.Create("SentryBusterExplodeNearSentry"..ply:EntIndex(), 0.1, 0, function()
					if !ply:Alive() then timer.Stop("SentryBusterExplodeNearSentry"..ply:EntIndex()) return end
					if ply:GetInfoNum("tf_sentrybuster",0) != 1 then timer.Stop("SentryBusterExplodeNearSentry"..ply:EntIndex()) return end
					if ply:GetInfoNum("tf_sentrybuster",0) != 1 then return end
					for _,building in pairs(ents.FindInSphere(ply:GetPos(), 80)) do
						if building:GetClass() == "obj_sentrygun" then	
						ply:SetNoDraw(true)
						ply:EmitSound("MVM.SentryBusterSpin")
						ply:SetNWBool("Taunting", true)
						ply:SetNWBool("NoWeapon", true)
						net.Start("ActivateTauntCam")
						net.Send(ply)
						local animent = ents.Create( 'base_gmodentity' ) -- The entity used as a reference for the bone positioning
						animent:SetModel( ply:GetModel() )
						animent:SetModelScale( ply:GetModelScale() )
						timer.Create("SetAnimPos", 0.01, 0, function()
							if not animent:IsValid() then timer.Stop("SetAnimPos") return end
							animent:SetPos( ply:GetPos() )
							animent:SetAngles( ply:GetAngles() )
						end )
						animent:SetNoDraw( false ) -- The ragdoll is the thing getting seen
						animent:Spawn()
											
						animent:SetSequence( "sentry_buster_preexplode" ) -- If the sequence isn't valid, the sequence length is 0, so the timer takes care of things
						animent:SetPlaybackRate( 1 )
						animent.AutomaticFrameAdvance = true
												
						animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
						animent:PhysicsInit( SOLID_OBB )
						animent:SetMoveType( MOVETYPE_FLYGRAVITY )
						animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
						animent:PhysWake()
											
						function animent:Think() -- This makes the animation work
							self:NextThink( CurTime() )
							return true
						end
						timer.Simple(2.5, function()
							ParticleEffect("asplode_hoodoo_shockwave", ply:GetPos() + Vector(0,0,35), ply:GetAngles())
							ParticleEffect("asplode_hoodoo_shockwave", ply:GetPos() + Vector(0,0,35), ply:GetAngles())
							ParticleEffect("asplode_hoodoo_shockwave", ply:GetPos() + Vector(0,0,35), ply:GetAngles())
							ParticleEffect("asplode_hoodoo_shockwave", ply:GetPos() + Vector(0,0,35), ply:GetAngles())
											
							ParticleEffect("cinefx_goldrush_flash", ply:GetPos(), ply:GetAngles())
								ParticleEffect("fireSmoke_Collumn_mvmAcres", ply:GetPos(), Angle())
							ParticleEffect("fluidSmokeExpl_ring_mvm", ply:GetPos() + Vector(50,50,25), ply:GetAngles())
							ParticleEffect("fluidSmokeExpl_ring_mvm", ply:GetPos() + Vector(-50,-50,25), ply:GetAngles())
							ParticleEffect("fluidSmokeExpl_ring_mvm", ply:GetPos() + Vector(-50,50,25), ply:GetAngles())
							ParticleEffect("fluidSmokeExpl_ring_mvm", ply:GetPos() + Vector(50,-50,25), ply:GetAngles())

							ParticleEffect("fireSmoke_Collumn_mvmAcres_sm", ply:GetPos() + Vector(50,50,25), ply:GetAngles())
							ParticleEffect("fireSmoke_Collumn_mvmAcres_sm", ply:GetPos() + Vector(-50,-50,25), ply:GetAngles())
							ParticleEffect("fireSmoke_Collumn_mvmAcres_sm", ply:GetPos() + Vector(-50,50,25), ply:GetAngles())
							ParticleEffect("fireSmoke_Collumn_mvmAcres_sm", ply:GetPos() + Vector(50,-50,25), ply:GetAngles())

							if animent:IsValid() then
								animent:Remove() 
							end

							ply:EmitSound("MvM.SentryBusterExplode")
							ply:EmitSound("MvM.SentryBusterExplode")
							ply:EmitSound("MvM.SentryBusterExplode")
							ply:SetNoDraw(false)

							ply:SetNWBool("Taunting", false)
							ply:SetNWBool("NoWeapon", false)
							net.Start("DeActivateTauntCam")
							net.Send(ply)
							if ply:GetRagdollEntity():IsValid() then
								ply:GetRagdollEntity():Remove()
							end
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 800)) do 
								if !v:IsPlayer() and v:Health() >= 0 and not v:IsFriendly(ply) then
									v:TakeDamage( v:Health(), ply, ply:GetActiveWeapon() )
								elseif v:IsPlayer() and not v:IsFriendly(ply) and v:Alive() and v:Nick() != ply:Nick() then
									v:TakeDamage( v:Health(), ply, ply:GetActiveWeapon() )
								end
							end
							ply:TakeDamage( ply:Health(), ply, ply:GetActiveWeapon() )
						end)
						timer.Stop("SentryBusterExplodeNearSentry"..ply:EntIndex())
						end
					end
				end)
				timer.Create("SentryBusterExplodeOnDeath", 0.1, 0, function()
					if !ply:Alive() then timer.Stop("SentryBusterExplodeOnDeath"..ply:EntIndex()) return end
					if ply:GetInfoNum("tf_sentrybuster",0) != 1 then timer.Stop("SentryBusterExplodeOnDeath"..ply:EntIndex()) return end
					if ply:GetInfoNum("tf_sentrybuster",0) != 1 then return end
					if ply:Health() <= 30 then
					ply:EmitSound("MVM.SentryBusterSpin")
					timer.Simple(0.1, function()
					ply:GodEnable()
					ply:SetNoDraw(true)
					ply:SetNWBool("Taunting", true)
					ply:SetNWBool("NoWeapon", true)
					net.Start("ActivateTauntCam")
					local animent = ents.Create( 'base_gmodentity' ) -- The entity used as a reference for the bone positioning
					animent:SetModel( ply:GetModel() )
					animent:SetModelScale( ply:GetModelScale() )
					timer.Create("SetAnimPos", 0.01, 0, function()
						if not animent:IsValid() then timer.Stop("SetAnimPos") return end
						animent:SetPos( ply:GetPos() )
						animent:SetAngles( ply:GetAngles() )
					end )
					animent:SetNoDraw( false ) -- The ragdoll is the thing getting seen
					animent:Spawn()
		
					animent:SetSequence( "sentry_buster_preexplode" ) -- If the sequence isn't valid, the sequence length is 0, so the timer takes care of things
					animent:SetPlaybackRate( 1 )
					animent.AutomaticFrameAdvance = true
		
					animent:SetSolid( SOLID_OBB ) -- This stuff isn't really needed, but just for physics
					animent:PhysicsInit( SOLID_OBB )
					animent:SetMoveType( MOVETYPE_FLYGRAVITY )
					animent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
					animent:PhysWake()
		
					function animent:Think() -- This makes the animation work
						self:NextThink( CurTime() - 5 )
						return true
					end
					timer.Simple(2, function()
						ParticleEffect("asplode_hoodoo_shockwave", ply:GetPos() + Vector(0,0,35), ply:GetAngles())
						ParticleEffect("asplode_hoodoo_shockwave", ply:GetPos() + Vector(0,0,35), ply:GetAngles())
						ParticleEffect("asplode_hoodoo_shockwave", ply:GetPos() + Vector(0,0,35), ply:GetAngles())
						ParticleEffect("asplode_hoodoo_shockwave", ply:GetPos() + Vector(0,0,35), ply:GetAngles())
		
						ParticleEffect("cinefx_goldrush_flash", ply:GetPos(), ply:GetAngles())
						ParticleEffect("fireSmoke_Collumn_mvmAcres", ply:GetPos(), Angle())
						ParticleEffect("fluidSmokeExpl_ring_mvm", ply:GetPos() + Vector(50,50,25), ply:GetAngles())
						ParticleEffect("fluidSmokeExpl_ring_mvm", ply:GetPos() + Vector(-50,-50,25), ply:GetAngles())
						ParticleEffect("fluidSmokeExpl_ring_mvm", ply:GetPos() + Vector(-50,50,25), ply:GetAngles())
						ParticleEffect("fluidSmokeExpl_ring_mvm", ply:GetPos() + Vector(50,-50,25), ply:GetAngles())

						ParticleEffect("fireSmoke_Collumn_mvmAcres_sm", ply:GetPos() + Vector(50,50,25), ply:GetAngles())
						ParticleEffect("fireSmoke_Collumn_mvmAcres_sm", ply:GetPos() + Vector(-50,-50,25), ply:GetAngles())
						ParticleEffect("fireSmoke_Collumn_mvmAcres_sm", ply:GetPos() + Vector(-50,50,25), ply:GetAngles())
						ParticleEffect("fireSmoke_Collumn_mvmAcres_sm", ply:GetPos() + Vector(50,-50,25), ply:GetAngles())
			
						if animent:IsValid() then
							animent:Remove()
						end
		
						ply:EmitSound("MvM.SentryBusterExplode")
						ply:SetNoDraw(false)
						ply:GodDisable()

						ply:SetNWBool("Taunting", false)
						ply:SetNWBool("NoWeapon", false)
						net.Start("DeActivateTauntCam")
						if ply:GetRagdollEntity():IsValid() then
							ply:GetRagdollEntity():Remove()
						end
						for k,v in pairs(ents.FindInSphere(ply:GetPos(), 800)) do 
							if v:IsNPC() and not v:IsFriendly(ply) then
								v:TakeDamage( v:Health(), ply, ply:GetActiveWeapon() )
							elseif v:IsPlayer() and not v:IsFriendly(ply) and ply:Alive() then
								v:TakeDamage( v:Health(), ply, ply:GetActiveWeapon() )
							end
						end
						ply:Kill()
					end)
					end)
					timer.Stop("SentryBusterExplodeOnDeath")
					end
				end)
			end
			if not ply:IsHL2() and ply:GetInfoNum("tf_robot", 0) == 1 then
				local ID = ply:LookupAttachment( "eye_1" )
				local Attachment = ply:GetAttachment( ID )
				if (Attachment == nil) then return end

				eyeparticle1 = ents.Create( "info_particle_system" )
				eyeparticle1:SetPos( Attachment.Pos )
				eyeparticle1:SetAngles( Attachment.Ang )
				eyeparticle1:SetName("eyeparticle1")
				eyeparticle1:SetOwner(ply)
				ply:DeleteOnRemove(eyeparticle1)

				PrecacheParticleSystem("bot_eye_glow")
				eyeparticle1:SetKeyValue( "effect_name", "bot_eye_glow" )
				eyeparticle1:SetKeyValue( "start_active", "1")

				local colorcontrol = ents.Create( "info_particle_system" )
				if (ply.Difficulty == 3) then
					colorcontrol:SetPos( Vector(255,180,36) )
				else
					if ply:Team() == TEAM_RED then
						colorcontrol:SetPos( Vector(204,0,0) )
					elseif ply:Team() == TEAM_BLU then
						colorcontrol:SetPos( Vector(51,255,255) )
					end
				end
				eyeparticle1:DeleteOnRemove(colorcontrol)
				colorcontrol:SetKeyValue( "effect_name", "bot_eye_glow" )
				--colorcontrol:SetKeyValue( "globalname", "colorcontrol_".. eyeparticle1:EntIndex())
				colorcontrol:SetName("colorcontrol_".. eyeparticle1:EntIndex())
				colorcontrol:Spawn()

				eyeparticle1:SetParent(ply)
				eyeparticle1:Fire("setparentattachment", "eye_1", 0.01)
				eyeparticle1:SetKeyValue( "cpoint1", "colorcontrol_".. eyeparticle1:EntIndex() ) --the color is controlled by the position of this entity - 
															--if the colorcontroller's position is 255, 255, 255, 
															--the color of the particle becomes white (255 255 255)
				eyeparticle1:Spawn()
				eyeparticle1:Activate()
				--now for eye two
				local ID = ply:LookupAttachment( "eye_2" )
				local Attachment = ply:GetAttachment( ID )
				if (Attachment != nil) then 
					eyeparticle2 = ents.Create( "info_particle_system" )
					eyeparticle2:SetPos( Attachment.Pos )
					eyeparticle2:SetAngles( Attachment.Ang )
					eyeparticle1:DeleteOnRemove(eyeparticle2)
					eyeparticle2:SetKeyValue( "effect_name", "bot_eye_glow" )
					eyeparticle2:SetKeyValue( "start_active", "1")
					eyeparticle2:SetParent(ply)
					eyeparticle2:SetName("eyeparticle2")
					eyeparticle2:Fire("setparentattachment", "eye_2", 0.01)
					eyeparticle2:SetKeyValue( "cpoint1", "colorcontrol_".. eyeparticle1:EntIndex() )
					eyeparticle2:Spawn()
					eyeparticle2:Activate()							

				end
				timer.Create("KillParticlesOnDeath", 0.001, 0, function()
					if ply:Alive() then
						return true
					else
						for k,v in pairs(ents.FindByName("eyeparticle1")) do 
							if v:GetOwner() == ply then
								v:Remove()
							end
						end
						timer.Stop("KillParticlesOnDeath")
						return false
					end
				end)
			end
			
			if not ply:IsHL2() and ply:GetInfoNum("tf_giant_robot", 0) == 1 then

				for k,v in pairs(player.GetAll()) do
					if not v:IsFriendly(ply) and v:Alive() and not v:IsHL2() then
						if v:GetPlayerClass() == "heavy" then
							v:EmitSound("vo/heavy_mvm_giant_robot04.wav", 85, 100, 1, CHAN_REPLACE)
						elseif v:GetPlayerClass() == "medic" then
							v:EmitSound("vo/medic_mvm_giant_robot01.wav", 85, 100, 1, CHAN_REPLACE)
						elseif v:GetPlayerClass() == "soldier" then
							v:EmitSound("vo/soldier_mvm_giant_robot0"..math.random(1,2)..".wav", 85, 100, 1, CHAN_REPLACE)
						elseif v:GetPlayerClass() == "engineer" then
							v:EmitSound("vo/engineer_mvm_giant_robot0"..math.random(1,2)..".wav", 85, 100, 1, CHAN_REPLACE)
						end
					end
				end
				if ply:GetPlayerClass() == "scout" then
					timer.Create("GiantRobotSpeed"..ply:EntIndex(), 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
					end)
					ply:SetModel("models/bots/scout_boss/bot_scout_boss.mdl")
					ply:SetModelScale(1.75)
					ply:SetHealth(1600)
					ply:SetMaxHealth(1600)
				elseif ply:GetPlayerClass() == "soldier" then
					timer.Create("GiantRobotSpeed"..ply:EntIndex(), 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						if ply:GetInfoNum("tf_giant_robot", 0) == 0 then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
					end)
					ply:SetModel("models/bots/soldier_boss/bot_soldier_boss.mdl")
					ply:SetModelScale(1.75)
					ply:SetHealth(3600)
					ply:SetMaxHealth(3600)
				elseif ply:GetPlayerClass() == "demoman" then
					timer.Create("GiantRobotSpeed"..ply:EntIndex(), 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						if ply:GetInfoNum("tf_giant_robot", 0) == 0 then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						//ply:SetPoseParameter("move_x", 1)
					end)
					ply:SetModel("models/bots/demo_boss/bot_demo_boss.mdl")
					ply:SetModelScale(1.75)
					ply:SetHealth(3600)
					ply:SetMaxHealth(3600)
				elseif ply:GetPlayerClass() == "heavy" then
					timer.Create("GiantRobotSpeed"..ply:EntIndex(), 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						if ply:GetInfoNum("tf_giant_robot", 0) == 0 then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						//ply:SetPoseParameter("move_x", 1)
					end)
					ply:EmitSound("MVM.GiantHeavyEntrance")
					ply:SetModel("models/bots/heavy_boss/bot_heavy_boss.mdl")
					ply:SetModelScale(1.75)
					ply:SetHealth(5000)
				elseif ply:GetPlayerClass() == "pyro" then
					timer.Create("GiantRobotSpeed"..ply:EntIndex(), 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						if ply:GetInfoNum("tf_giant_robot", 0) == 0 then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						//ply:SetPoseParameter("move_x", 1)
					end)
					ply:SetModel("models/bots/pyro_boss/bot_pyro_boss.mdl")
					ply:SetModelScale(1.75)
					ply:SetHealth(3600)
					ply:SetMaxHealth(3600)
				elseif ply:GetPlayerClass() == "medic" then
					timer.Create("GiantRobotSpeed"..ply:EntIndex(), 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						if ply:GetInfoNum("tf_giant_robot", 0) == 0 then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						//ply:SetPoseParameter("move_x", 1)
					end)
					ply:SetModel("models/bots/medic/bot_medic.mdl")
					ply:SetModelScale(1.75)
					ply:SetHealth(3600)
					ply:SetMaxHealth(3600)
				elseif ply:GetPlayerClass() == "engineer" then
					timer.Create("GiantRobotSpeed"..ply:EntIndex(), 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						if ply:GetInfoNum("tf_giant_robot", 0) == 0 then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						//ply:SetPoseParameter("move_x", 1)
					end)
					ply:SetModel("models/bots/engineer/bot_engineer.mdl")
					ply:SetModelScale(1.75)
					ply:SetHealth(1600)
					ply:SetMaxHealth(1600)
				elseif ply:GetPlayerClass() == "sniper" then
					timer.Create("GiantRobotSpeed"..ply:EntIndex(), 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						if ply:GetInfoNum("tf_giant_robot", 0) == 0 then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						//ply:SetPoseParameter("move_x", 1)
					end)
					ply:SetModel("models/bots/sniper/bot_sniper.mdl")
					ply:SetModelScale(1.75)
					ply:SetHealth(1800)
					ply:SetMaxHealth(1800)
				elseif ply:GetPlayerClass() == "spy" then
					timer.Create("GiantRobotSpeed"..ply:EntIndex(), 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						if ply:GetInfoNum("tf_giant_robot", 0) == 0 then timer.Stop("GiantRobotSpeed"..ply:EntIndex()) return end
						//ply:SetPoseParameter("move_x", 1)
					end)
					ply:SetModel("models/bots/spy/bot_spy.mdl")
					ply:SetModelScale(1.75)
					ply:SetHealth(1200)
					ply:SetMaxHealth(1200)
				end
			end
			if ply:GetInfoNum("tf_zombie", 0) == 1 then
				if ply:GetPlayerClass() == "scout" then
					ply:SetModel("models/lazy_zombies_v2/scout.mdl")
					ply:StripWeapon("tf_weapon_scattergun")
					ply:StripWeapon("tf_weapon_pistol_scout")
				elseif ply:GetPlayerClass() == "gmodplayer" then
					timer.Create("GiantRobotSpeed2", 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed2") return end
						if ply:GetInfoNum("tf_zombie", 0) == 0 then timer.Stop("GiantRobotSpeed2") return end
						ply:SetWalkSpeed(65)
						ply:SetRunSpeed(105)
					end)
					ply:SetModel( table.Random(zombiemodel) )
					ply:StripWeapons()
					ply:Give("weapon_fists")	
				elseif ply:GetPlayerClass() == "soldier" then
					ply:SetModel("models/lazy_zombies_v2/soldier.mdl")
					ply:StripWeapon("tf_weapon_rocketlauncher")
					ply:StripWeapon("tf_weapon_shotgun_soldier")
				elseif ply:GetPlayerClass() == "demoman" then
					ply:SetModel("models/lazy_zombies_v2/demo.mdl")
					ply:StripWeapon("tf_weapon_grenadelauncher")
					ply:StripWeapon("tf_weapon_pipebomblauncher")
				elseif ply:GetPlayerClass() == "heavy" then
					ply:SetModel("models/lazy_zombies_v2/heavy.mdl")
					ply:StripWeapon("tf_weapon_minigun")
					ply:StripWeapon("tf_weapon_shotgun_heavy")
				elseif ply:GetPlayerClass() == "pyro" then
					ply:SetModel("models/lazy_zombies_v2/pyro.mdl")
					ply:StripWeapon("tf_weapon_flamethrower")
					ply:StripWeapon("tf_weapon_shotgun_pyro")
				elseif ply:GetPlayerClass() == "medic" then
					ply:SetModel("models/lazy_zombies_v2/medic.mdl")
					ply:StripWeapon("tf_weapon_syringegun")
					ply:StripWeapon("tf_weapon_medigun")
				elseif ply:GetPlayerClass() == "engineer" then
					ply:SetModel("models/lazy_zombies_v2/engineer.mdl")
					ply:StripWeapon("tf_weapon_shotgun_primary")
					ply:StripWeapon("tf_weapon_pistol")
				elseif ply:GetPlayerClass() == "sniper" then
					ply:SetModel("models/lazy_zombies_v2/sniper.mdl")
					ply:StripWeapon("tf_weapon_sniperrifle")
					ply:StripWeapon("tf_weapon_smg")
				elseif ply:GetPlayerClass() == "spy" then
					ply:SetModel("models/lazy_zombies_v2/spy.mdl")
					ply:StripWeapon("tf_weapon_revolver")
					ply:StripWeapon("tf_weapon_builder")
					ply:StripWeapon("tf_weapon_pda_spy")
				end
			end
			if not ply:IsHL2() and ply:GetInfoNum("tf_voodoo", 0) == 1 then
				if ply:GetPlayerClass() == "scout" then
					ply:SetModel("models/lazy_zombies_v2/scout.mdl")	
				elseif ply:GetPlayerClass() == "soldier" then
					ply:SetModel("models/lazy_zombies_v2/soldier.mdl")
				elseif ply:GetPlayerClass() == "demoman" then
					ply:SetModel("models/lazy_zombies_v2/demo.mdl")
				elseif ply:GetPlayerClass() == "heavy" then
					ply:SetModel("models/lazy_zombies_v2/heavy.mdl")
				elseif ply:GetPlayerClass() == "pyro" then
					ply:SetModel("models/lazy_zombies_v2/pyro.mdl")
				elseif ply:GetPlayerClass() == "medic" then
					ply:SetModel("models/lazy_zombies_v2/medic.mdl")
				elseif ply:GetPlayerClass() == "engineer" then
					ply:SetModel("models/lazy_zombies_v2/engineer.mdl")
					ply:StripWeapon("tf_weapon_pistol")
				elseif ply:GetPlayerClass() == "sniper" then
					ply:SetModel("models/lazy_zombies_v2/sniper.mdl")
				elseif ply:GetPlayerClass() == "spy" then
					ply:SetModel("models/lazy_zombies_v2/spy.mdl")
				end
			end
			if not ply:IsHL2() and ply:GetInfoNum("tf_bigzombie", 0) == 1 then
				ply:SetModelScale(1.85)
				if ply:GetPlayerClass() == "scout" then
					ply:SetModel("models/lazy_zombies_v2/scout.mdl")
					ply:StripWeapon("tf_weapon_scattergun")
					ply:StripWeapon("tf_weapon_pistol_scout")
				elseif ply:GetPlayerClass() == "soldier" then
					ply:SetModel("models/lazy_zombies_v2/soldier.mdl")
					ply:StripWeapon("tf_weapon_rocketlauncher")
					ply:StripWeapon("tf_weapon_shotgun_soldier")
				elseif ply:GetPlayerClass() == "demoman" then
					ply:SetModel("models/lazy_zombies_v2/demo.mdl")
					ply:StripWeapon("tf_weapon_grenadelauncher")
					ply:StripWeapon("tf_weapon_pipebomblauncher")
				elseif ply:GetPlayerClass() == "heavy" then
					ply:SetModel("models/lazy_zombies_v2/heavy.mdl")
					ply:StripWeapon("tf_weapon_minigun")
					ply:StripWeapon("tf_weapon_shotgun_heavy")
				elseif ply:GetPlayerClass() == "pyro" then
					ply:SetModel("models/lazy_zombies_v2/pyro.mdl")
					ply:StripWeapon("tf_weapon_flamethrower")
					ply:StripWeapon("tf_weapon_shotgun_pyro")
				elseif ply:GetPlayerClass() == "medic" then
					ply:SetModel("models/lazy_zombies_v2/medic.mdl")
					ply:StripWeapon("tf_weapon_syringegun")
					ply:StripWeapon("tf_weapon_medigun")
				elseif ply:GetPlayerClass() == "engineer" then
					ply:SetModel("models/lazy_zombies_v2/engineer.mdl")
					ply:StripWeapon("tf_weapon_shotgun_primary")
					ply:StripWeapon("tf_weapon_pistol")
				elseif ply:GetPlayerClass() == "sniper" then
					ply:SetModel("models/lazy_zombies_v2/sniper.mdl")
					ply:StripWeapon("tf_weapon_sniperrifle")
					ply:StripWeapon("tf_weapon_smg")
				elseif ply:GetPlayerClass() == "spy" then
					ply:SetModel("models/lazy_zombies_v2/spy.mdl")
					ply:StripWeapon("tf_weapon_revolver")
					ply:StripWeapon("tf_weapon_builder")
					ply:StripWeapon("tf_weapon_pda_spy")
				end
			end
		
			if not ply:IsHL2() and ply:GetInfoNum("jakey_antlionfbii", 0) == 1 then
				if ply:GetPlayerClass() != "heavy" then ply:SetPlayerClass("heavy") end
				ply:SetModel("models/player/antlion_fbi/antlion_guard.mdl")
				ply:SetHealth(5200)
				ply:SetMaxHealth(5000)
				ply:StripWeapon("tf_weapon_minigun")
				ply:StripWeapon("tf_weapon_shotgun_hwg") 
				ply:SetWalkSpeed(600)
				ply:SetRunSpeed(600)
			end
			if ply:GetInfoNum("dylan_rageheavy", 0) == 1 then
				if !ply:IsAdmin() then return end
				if ply:GetPlayerClass() != "heavy" then ply:SetPlayerClass("heavy") end
				ply:SetHealth(1000000000000)
				ply:SetMaxHealth(1000000000000) 
				timer.Create("GiantRobotSpeed", 0.01, 0, function()
					if not ply:Alive() then timer.Stop("GiantRobotSpeed") return end
					if ply:GetInfoNum("dylan_rageheavy", 0) == 0 then timer.Stop("GiantRobotSpeed") return end
					ply:SetWalkSpeed(1250)
					ply:SetMaxSpeed(1250) 
					ply:SetRunSpeed(1250)
				end)
			end
			if ply:GetInfoNum("hahahahahahahahaowneronly_ragespy", 0) == 1 then
				if !ply:IsAdmin() then return end
				if ply:GetPlayerClass() != "spy" then ply:SetPlayerClass("spy") end
				ply:SetHealth(1000000000000)
				ply:SetMaxHealth(1000000000000)
				timer.Create("GiantRobotSpeed", 0.01, 0, function()
					if not ply:Alive() then timer.Stop("GiantRobotSpeed") return end
					if ply:GetInfoNum("hahahahahahahahaowneronly_ragespy", 0) == 0 then timer.Stop("GiantRobotSpeed") return end
					ply:SetWalkSpeed(1250)
					ply:SetMaxSpeed(1250)
					ply:SetRunSpeed(1250)
				end)
			end

			if not ply:IsHL2() and ply:GetPlayerClass() == "sniper" and ply:GetInfoNum("tf_skeleton", 0) == 1 then
				ply:SetModel("models/bots/skeleton_sniper/skeleton_sniper.mdl")
			elseif not ply:IsHL2() and ply:GetPlayerClass() == "heavy" and ply:GetInfoNum("tf_yeti", 0) == 1 then
				ply:SetModel("models/player/yeti.mdl")
			elseif not ply:IsHL2() and ply:GetPlayerClass() == "demoman" and ply:GetInfoNum("tf_hhh", 0) == 1 then
				ply:SetModel("models/bots/small_headless_hatman.mdl")
			elseif not ply:IsHL2() and ply:GetPlayerClass() == "heavy" and ply:GetInfoNum("civ2_bootleg_charger", 0) == 1 then
				ply:SetModel("models/infected/not_a_charger.mdl")
			end
			if not ply:IsHL2() and ply:GetInfoNum("tf_mvm_giant_voodoo", 0) == 1 then
				ply:SetModelScale(1.75)
				if ply:GetPlayerClass() == "scout" then
					timer.Create("GiantRobotSpeed", 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed") return end
						if ply:GetInfoNum("tf_mvm_giant_voodoo", 0) == 0 then timer.Stop("GiantRobotSpeed") return end
						ply:SetWalkSpeed(500)
						ply:SetMaxSpeed(500)
						ply:SetRunSpeed(500)
					end)
					ply:SetModel("models/lazy_zombies_v2/scout.mdl")
				elseif ply:GetPlayerClass() == "soldier" then
					timer.Create("GiantRobotSpeed", 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed") return end
						if ply:GetInfoNum("tf_mvm_giant_voodoo", 0) == 0 then timer.Stop("GiantRobotSpeed") return end
						ply:SetWalkSpeed(150)
						ply:SetMaxSpeed(150)
						ply:SetRunSpeed(150)
					end)
					ply:SetModel("models/lazy_zombies_v2/soldier.mdl")
				elseif ply:GetPlayerClass() == "demoman" then
					timer.Create("GiantRobotSpeed", 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed") return end
						if ply:GetInfoNum("tf_mvm_giant_voodoo", 0) == 0 then timer.Stop("GiantRobotSpeed") return end
						ply:SetWalkSpeed(150)
						ply:SetMaxSpeed(150)
						ply:SetRunSpeed(150)
					end)
					ply:SetModel("models/lazy_zombies_v2/demo.mdl")
				elseif ply:GetPlayerClass() == "heavy" then
					timer.Create("GiantRobotSpeed", 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed") return end
						if ply:GetInfoNum("tf_mvm_giant_voodoo", 0) == 0 then timer.Stop("GiantRobotSpeed") return end
						ply:SetWalkSpeed(150)
						ply:SetMaxSpeed(150)
						ply:SetRunSpeed(150)
					end)
					ply:SetModel("models/lazy_zombies_v2/heavy.mdl")
				elseif ply:GetPlayerClass() == "pyro" then
					timer.Create("GiantRobotSpeed", 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed") return end
						if ply:GetInfoNum("tf_mvm_giant_voodoo", 0) == 0 then timer.Stop("GiantRobotSpeed") return end
						ply:SetWalkSpeed(150)
						ply:SetMaxSpeed(150)
						ply:SetRunSpeed(150)
					end)
					ply:SetModel("models/lazy_zombies_v2/pyro.mdl")
				elseif ply:GetPlayerClass() == "medic" then
					timer.Create("GiantRobotSpeed", 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed") return end
						if ply:GetInfoNum("tf_mvm_giant_voodoo", 0) == 0 then timer.Stop("GiantRobotSpeed") return end
						ply:SetWalkSpeed(150)
						ply:SetMaxSpeed(150)
						ply:SetRunSpeed(150)
					end)
					ply:SetModel("models/lazy_zombies_v2/medic.mdl")
				elseif ply:GetPlayerClass() == "engineer" then
					timer.Create("GiantRobotSpeed", 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed") return end
						if ply:GetInfoNum("tf_mvm_giant_voodoo", 0) == 0 then timer.Stop("GiantRobotSpeed") return end
						ply:SetWalkSpeed(150)
						ply:SetMaxSpeed(150)
						ply:SetRunSpeed(150)
					end)
					ply:SetModel("models/lazy_zombies_v2/engineer.mdl")
				elseif ply:GetPlayerClass() == "sniper" then
					timer.Create("GiantRobotSpeed", 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed") return end
						if ply:GetInfoNum("tf_mvm_giant_voodoo", 0) == 0 then timer.Stop("GiantRobotSpeed") return end
						ply:SetWalkSpeed(150)
						ply:SetMaxSpeed(150)
						ply:SetRunSpeed(150)
					end)
					ply:SetModel("models/lazy_zombies_v2/sniper.mdl")
				elseif ply:GetPlayerClass() == "spy" then
					timer.Create("GiantRobotSpeed", 0.01, 0, function()
						if not ply:Alive() then timer.Stop("GiantRobotSpeed") return end
						if ply:GetInfoNum("tf_mvm_giant_voodoo", 0) == 0 then timer.Stop("GiantRobotSpeed") return end
						ply:SetWalkSpeed(150)
						ply:SetMaxSpeed(150)
						ply:SetRunSpeed(150)
					end) 
					ply:SetModel("models/lazy_zombies_v2/spy.mdl")
				end
			end
			if not ply:IsHL2() and ply:GetInfoNum("tf_mvm_voodoo", 0) == 1 then
				if ply:GetPlayerClass() == "scout" then
					ply:SetModel("models/lazy_zombies_v2/scout.mdl")
				elseif ply:GetPlayerClass() == "soldier" then
					ply:SetModel("models/lazy_zombies_v2/soldier.mdl")
				elseif ply:GetPlayerClass() == "demoman" then
					ply:SetModel("models/lazy_zombies_v2/demo.mdl")
				elseif ply:GetPlayerClass() == "heavy" then
					ply:SetModel("models/lazy_zombies_v2/heavy.mdl")
				elseif ply:GetPlayerClass() == "pyro" then
					ply:SetModel("models/lazy_zombies_v2/pyro.mdl")
				elseif ply:GetPlayerClass() == "medic" then
					ply:SetModel("models/lazy_zombies_v2/medic.mdl")
				elseif ply:GetPlayerClass() == "engineer" then
					ply:SetModel("models/lazy_zombies_v2/engineer.mdl")
				elseif ply:GetPlayerClass() == "sniper" then
					ply:SetModel("models/lazy_zombies_v2/sniper.mdl")
				elseif ply:GetPlayerClass() == "spy" then
					ply:SetModel("models/lazy_zombies_v2/spy.mdl")
				end
			end
		end
	end)
end 
hook.Add( "PlayerSpawn", "PlayerGiantRoBotSpawn", PlayerGiantBotSpawn)

concommand.Add("check_save_table_for_entity", function(ply)
	PrintTable(ply:GetEyeTrace().Entity:GetSaveTable())
end)

local drowning = {}
hook.Add("OnEntityWaterLevelChanged", "UnderwaterAmbience", function(ent, old, new)
	if not ent:IsPlayer() then return end

	if new > 0 and old == 0 then
		ent:EmitSound("Physics.WaterSplash")
	end

	if new > 2 then
		ent:SetDSP(14)
		ent:SendLua('LocalPlayer():StopSound("Player.AmbientUnderWater")')
		ent:SendLua('LocalPlayer():EmitSound("Player.AmbientUnderWater")')

		drowning[ent] = {
			start = CurTime() + 12,
			nextTick = 0
		}
	else
		if drowning[ent] then
			if ent.IsDrowning then
				ent:SetHealth(math.min(ent:Health() + ent:GetMaxHealth() * 0.5, ent:GetMaxHealth()))
				ent:EmitSound("Player.DrownStart")
			end

			drowning[ent] = nil
			ent.IsDrowning = false

			ParticleEffectAttach("water_playeremerge", PATTACH_ABSORIGIN_FOLLOW, ent, 0)
		end

		ent:SetDSP(0)
		ent:SendLua('LocalPlayer():StopSound("Player.AmbientUnderWater")')
	end
end)

hook.Add("Tick", "DrowningSystem_Tick", function()
	local ct = CurTime()

	for ent, data in pairs(drowning) do
		if not IsValid(ent) or not ent:Alive() then
			drowning[ent] = nil
			continue
		end

		if ent:WaterLevel() <= 2 or ent:HasGodMode() then
			drowning[ent] = nil
			ent.IsDrowning = false
			continue
		end

		if not ent.IsDrowning then
			ent.IsDrowning = data.start <= ct
			continue
		end

		if data.nextTick <= ct then
			data.nextTick = ct + 1

			ent:TakeDamage(8)
			ent:EmitSound("Player.DrownContinue")
			ent:ScreenFade(SCREENFADE.IN, Color(0, 0, 100, 128), 1, 0)
		end
	end
end)

concommand.Add( "random_team", function( ply, cmd, args )

	local nDiffBetweenTeams = 0;
	local m_iLightestTeam = 0;
	local m_iHeaviestTeam = 0;
	local iMostPlayers = 0;
	local iLeastPlayers = game.MaxPlayers() + 1;
	local i = 1; 
	for k,v in ipairs(team.GetAllTeams()) do
			local iNumPlayers = team.NumPlayers(v);

			if ( iNumPlayers < iLeastPlayers ) then
				iLeastPlayers = iNumPlayers;
				m_iLightestTeam = k; 
			end

			if ( iNumPlayers > iMostPlayers ) then
				iMostPlayers = iNumPlayers;
				m_iHeaviestTeam = k; 
			end
	end 

	nDiffBetweenTeams = ( iMostPlayers - iLeastPlayers );
	if (team.NumPlayers(TEAM_RED) > team.NumPlayers(TEAM_BLU)) then
		ply:SetTeam(TEAM_BLU)	
	elseif (team.NumPlayers(TEAM_RED) < team.NumPlayers(TEAM_BLU)) then
		ply:SetTeam(TEAM_RED)	
	else
		ply:SetTeam(table.Random({TEAM_RED,TEAM_BLU}))	
	end
	if ply:Alive() and ply:Team() != TEAM_SPECTATOR then ply:Kill() end 

end)

local function TFEnsureCanonicalTeams()
	local redName = string.upper(team.GetName(TEAM_RED) or "")
	local bluName = string.upper(team.GetName(TEAM_BLU) or "")
	local specName = string.upper(team.GetName(TEAM_SPECTATOR) or "")

	if redName ~= "RED" or bluName ~= "BLU" or specName ~= "SPECTATOR" then
		if GAMEMODE and GAMEMODE.CreateTeams then
			GAMEMODE:CreateTeams()
		end
	end
end

local function ShouldSuppressBlueBotAnnounce(ply, teamId)
	if not IsValid(ply) or not ply:IsBot() then return false end
	local t = tonumber(teamId) or ply:Team()
	return t == TEAM_BLU or t == TF_TEAM_PVE_INVADERS
end

local function IsMvMMap()
	if TF_IsMvMMap then
		return TF_IsMvMMap()
	end
	return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

concommand.Add( "changeteam", function( pl, cmd, args )
	TFEnsureCanonicalTeams()

	local rawTeamArg = args[1]
	local requestedTeam = tonumber(rawTeamArg)
	if requestedTeam == nil and isstring(rawTeamArg) then
		local token = string.Trim(string.lower(rawTeamArg))
		if token == "red" then
			requestedTeam = TEAM_RED
		elseif token == "blu" or token == "blue" then
			requestedTeam = TEAM_BLU
		elseif token == "spec" or token == "spectator" then
			requestedTeam = TEAM_SPECTATOR
		elseif token == "yellow" or token == "ylw" then
			requestedTeam = TEAM_YELLOW
		elseif token == "green" or token == "grn" then
			requestedTeam = TEAM_GREEN
		elseif token == "neutral" then
			requestedTeam = TEAM_NEUTRAL
		elseif token == "friendly" then
			requestedTeam = TEAM_FRIENDLY
		end
	end
	local requestedIsGameplayTeam = requestedTeam == TEAM_RED
		or requestedTeam == TEAM_BLU
		or requestedTeam == TEAM_YELLOW
		or requestedTeam == TEAM_GREEN
		or requestedTeam == TEAM_NEUTRAL
		or requestedTeam == TEAM_FRIENDLY
	local requestedIsSpectator = requestedTeam == TEAM_SPECTATOR and not requestedIsGameplayTeam
	--if ( tonumber( args[ 1 ] ) >= 5 and args[ 1 ] ~= 1002 ) then return end
	if requestedTeam == nil then
		pl:ChatPrint("Invalid Team!")
		return
	end
	if not requestedIsGameplayTeam and not requestedIsSpectator then
		pl:ChatPrint("Invalid Team!")
		return
	end
	if requestedIsSpectator and pl:Team() == TEAM_SPECTATOR then
		-- Allow re-selecting spectator to refresh spectate target/mode without chat spam.
		timer.Simple(0, function()
			if IsValid(pl) and pl:Team() == TEAM_SPECTATOR then
				pl:ConCommand("tf_spectate")
			end
		end)
		return
	end
	if ( !GetConVar("tf_competitive"):GetBool() and pl:Team() == requestedTeam ) then pl:PrintMessage(HUD_PRINTTALK,"You are already in this team!") return false end
	if ( GetConVar("tf_competitive"):GetBool() and requestedTeam == 4 ) then pl:ChatPrint("Competitive mode is on!") return end
	if ( string.find(game.GetMap(), "mvm_") and requestedTeam == 6 and !pl:IsAdmin() ) then pl:ChatPrint("Friendly Team is disabled!") return end
	if ( string.find(game.GetMap(), "mvm_") and !pl:IsAdmin() and requestedTeam == 5 and !pl:IsAdmin() ) then pl:ChatPrint("Neutral Team is disabled!") return end
	if ( GetConVar("tf_competitive"):GetBool() and requestedTeam == 6 and !pl:IsAdmin() ) then pl:ChatPrint("Friendly Team is disabled!") return end
	if ( GetConVar("tf_competitive"):GetBool() and requestedTeam == 5 and !pl:IsAdmin() ) then pl:ChatPrint("Neutral Team is disabled!") return end
	if ( GetConVar("tf_competitive"):GetBool() and requestedTeam == 4 and !pl:IsAdmin() ) then pl:ChatPrint("Green Team is disabled!") return end
	if ( GetConVar("tf_competitive"):GetBool() and requestedTeam == 3 and !pl:IsAdmin() ) then pl:ChatPrint("Yellow Team is disabled!") return end

	if requestedIsSpectator then
		if pl:Alive() then
			pl:Kill() -- Team switch should always produce a death ragdoll.
		end
		pl:StripWeapons()
		pl:StripAmmo()
		pl:SetTeam(TEAM_SPECTATOR)
		pl:Spectate(OBS_MODE_ROAMING)
		timer.Simple(0, function()
			if IsValid(pl) and pl:Team() == TEAM_SPECTATOR then
				pl:ConCommand("tf_spectate")
			end
		end)
		timer.Simple(0.3, function()
			if !IsValid(pl) then return end
			if ShouldSuppressBlueBotAnnounce(pl, pl:Team()) then return end
			PrintMessage(HUD_PRINTTALK, 'Player ' .. pl:Nick() .. ' joined team ' .. team.GetName(pl:Team()))
		end)
		return
	end

	if ( GetConVar("tf_competitive"):GetBool() ) then
		local theteam = requestedTeam
		local nDiffBetweenTeams = 0;
		local m_iLightestTeam = 0;
		local m_iHeaviestTeam = 0;
		local iMostPlayers = 0;
		local iLeastPlayers = game.MaxPlayers() + 1;
		local i = 1; 
		for k,v in ipairs(team.GetAllTeams()) do
				local iNumPlayers = team.NumPlayers(v);

				if ( iNumPlayers < iLeastPlayers ) then
					iLeastPlayers = iNumPlayers;
					m_iLightestTeam = k; 
				end

				if ( iNumPlayers > iMostPlayers ) then
					iMostPlayers = iNumPlayers;
					m_iHeaviestTeam = k; 
				end
		end 

		nDiffBetweenTeams = ( iMostPlayers - iLeastPlayers );
		if (IsMvMMap()) then
			if (theteam != TF_TEAM_RED) then
				pl:PrintMessage(HUD_PRINTTALK,"The team is full. Press the dot key to change teams again.")
				return false
			end
			if (pl:Team() == theteam) then
				pl:PrintMessage(HUD_PRINTTALK,"You are already in this team!")
				return false
			else
				if pl:Alive() then
					pl:Kill() -- Team switch should always produce a death ragdoll.
				end
				pl:SetTeam(theteam)
			end
		else
			if (team.NumPlayers(TEAM_RED) > team.NumPlayers(TEAM_BLU) and theteam == TEAM_RED) then
				pl:PrintMessage(HUD_PRINTTALK,"The team is full. Press the dot key to change teams again.")
				return false
			elseif (team.NumPlayers(TEAM_BLU) < team.NumPlayers(TEAM_) and theteam == 2) then
				pl:PrintMessage(HUD_PRINTTALK,"The team is full. Press the dot key to change teams again.")
				return false
			else
				if (pl:Team() == theteam) then
					pl:PrintMessage(HUD_PRINTTALK,"You are already in this team!")
					return false
				else
					if pl:Alive() then
						pl:Kill() -- Team switch should always produce a death ragdoll.
					end
					pl:SetTeam(theteam)
				end
			end
		end
	else
		if pl:Alive() then
			pl:Kill() -- Team switch should always produce a death ragdoll.
		end
		pl:SetTeam(requestedTeam)
	end

	if requestedIsSpectator then
		timer.Simple(0.1, function()
			if IsValid(pl) and pl:Team() == TEAM_SPECTATOR then
				pl:ConCommand("tf_spectate")
			end
		end)
	else
		pl.TFPreventSpectatorUntil = CurTime() + 1.5
		pl.IsSpectating = false
		if pl:GetObserverMode() ~= OBS_MODE_NONE then
			pl:UnSpectate()
		end
		pl:ConCommand("tf_changeclass")
	end
	timer.Simple(0.3, function()
		if !IsValid(pl) then return end
		if ShouldSuppressBlueBotAnnounce(pl, pl:Team()) then return end
		PrintMessage(HUD_PRINTTALK, 'Player '.. pl:Nick() ..	' joined team '.. team.GetName(pl:Team()) )
	end) 
end )


local SpawnableItems = {
	"item_ammopack_small",
	"item_ammopack_medium",
	"item_ammopack_full",
	"item_healthkit_small",
	"item_healthkit_medium",
	"item_healthkit_full",
	"item_duck",
}

hook.Add("InitPostEntity", "TF_InitSpawnables", function()
	local base = scripted_ents.GetStored("item_base")
	if not base or not base.t or not base.t.SpawnFunction then return end
	
	for _,v in ipairs(SpawnableItems) do
		local ent = scripted_ents.GetStored(v)
		if ent and ent.t then
			ent.t.SpawnFunction = base.t.SpawnFunction
		end
	end
end) 
local function GetFirstObserverPoint()
	local tbl = {}
	for k,v in ipairs(ents.FindByClass("info_observer_point")) do
		if (IsValid(v)) then
			table.insert(tbl, v)
		end
	end
	return table.Random(tbl)
end
function GM:PlayerInitialSpawn(ply)
	if (!ply:IsBot()) then
		--ply:ConCommand("tf_merge_loadout_ask")
		ply:SetTeam(TEAM_SPECTATOR)	
		if (GetFirstObserverPoint() != nil) then
			ply:Spectate(OBS_MODE_IN_EYE)
			ply:SpectateEntity(GetFirstObserverPoint())
		end
		ply:ConCommand("tf_changeteam")
		ply:PrintMessage(HUD_PRINTTALK,"To start the mission, type \"tf_mvm_start\" in console.")
	else
		-- Keep bots on the MvM invader side; do not run generic team balancer there.
		if string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) then
			-- Use BLU as runtime team; -1 pseudo-team can fall into invalid/unassigned states in GMod.
			ply:SetTeam(TEAM_BLU)
		else
	
		local nDiffBetweenTeams = 0;
		local m_iLightestTeam = 0;
		local m_iHeaviestTeam = 0;
		local iMostPlayers = 0;
		local iLeastPlayers = game.MaxPlayers() + 1;
		local i = 1; 
		for k,v in ipairs(team.GetAllTeams()) do
				local iNumPlayers = team.NumPlayers(v);

				if ( iNumPlayers < iLeastPlayers ) then
					iLeastPlayers = iNumPlayers;
					m_iLightestTeam = k; 
				end

				if ( iNumPlayers > iMostPlayers ) then
					iMostPlayers = iNumPlayers;
					m_iHeaviestTeam = k; 
				end
		end 

		nDiffBetweenTeams = ( iMostPlayers - iLeastPlayers );
		if (team.NumPlayers(TEAM_RED) > team.NumPlayers(TEAM_BLU)) then
			ply:SetTeam(TEAM_BLU)	
		elseif (team.NumPlayers(TEAM_RED) < team.NumPlayers(TEAM_BLU)) then
			ply:SetTeam(TEAM_RED)	
		else
			ply:SetTeam(table.Random({TEAM_RED,TEAM_BLU}))	
		end
		end
		
	end
	-- Wait until InitPostEntity has been called
	if not self.PostEntityDone then
		timer.Simple(0.05, function() self:PlayerInitialSpawn(ply) end)
		return
	end
	
	-- Msg("PlayerInitialSpawn : "..ply:GetName().." "..tostring(self.Landmark).."\n")
	if self.Landmark then--and self.Landmark:IsValidMap() then
		--self.Landmark:LoadPlayerData(ply)
	end

	if IsValid(ply) and not ply:IsBot() and not ply.TFInitialJoinFlowSent then
		ply.TFInitialJoinFlowSent = true
		net.Start("TF_OpenInitialJoinFlow")
		net.Send(ply)
	end
end

function GM:OnPlayerChangedTeam(ply, oldteam, newteam)
	if newteam == TEAM_SPECTATOR then
		local Pos = ply:EyePos()
		ply:Spawn()
		ply:SetPos( Pos )
	elseif oldteam == TEAM_SPECTATOR then
		ply:Spawn()
	end
 
	if not ShouldSuppressBlueBotAnnounce(ply, newteam) then
		PrintMessage(HUD_PRINTTALK, Format("%s joined '%s'", ply:Nick(), team.GetName(newteam)))
	end
	
	self:ClearDominations(ply)
	self:UpdateEntityRelationship(ply)
end

local function CanSpawn(ply) if (ply:Team() == TEAM_SPECTATOR && !ply:IsAdmin()) or GetConVar("tf_competitive"):GetBool() && !ply:IsAdmin() then return false end return true end

function GM:CanPlayerSuicide(ply)
	if ply:Team() == TEAM_SPECTATOR then return false end
	return true
end

function GM:PlayerSpawnSWEP(ply)
	return CanSpawn(ply)
end
hook.Add("CanArmDupe","ArmDupe?",function(ply)
	return CanSpawn(ply)
end)

function GM:PlayerSpawnVehicle(ply)
	return CanSpawn(ply)
end

function GM:PlayerSpawnNPC(ply)
	return CanSpawn(ply)
end

function GM:PlayerSpawnSENT(ply)
	return CanSpawn(ply)
end

function GM:PlayerSpawnObject(ply)
	return CanSpawn(ply)
end

function GM:PlayerSpawnProp(ply)
	return CanSpawn(ply)
end

function GM:PlayerSpawnRagdoll(ply)
	return CanSpawn(ply)
end

function GM:PlayerSpawnEffect(ply)
	return CanSpawn(ply)
end

function RandomWeapon(ply, wepslot)
	local weps = tf_items.ReturnItems()
	local validweapons = {}
	for k, v in pairs(weps) do
		if v and istable(v) and isstring(wepslot) and v["name"] and v["item_slot"] == wepslot and !string.StartWith(v["name"], "Australium") and v["craft_class"] == "weapon" then
			PrintTable(v)
			table.insert(validweapons, v["name"])
		end
	end

	local wep = table.Random(validweapons)

	ply:PrintMessage(HUD_PRINTTALK, "You were given " .. wep .. "!")
	ply:EquipInLoadout(wep)
end

-- by hl2 campaign https:--github.com/daunknownfox2010/half-life-2-campaign/blob/master/gamemode/init.lua but edited
local ParticleSystemKeyvalueRemap = {
	env_leak_drip_1024 = "env_rain_gutterdrip",
	env_leak_dripsplash_ripples = "env_rain_ripples",
}

function GM:EntityKeyValue( ent, key, value )
	if ent:GetClass() == "info_particle_system" and string.lower(tostring(key or "")) == "effect_name" then
		local replacement = ParticleSystemKeyvalueRemap[string.lower(tostring(value or ""))]
		if replacement then
			return replacement
		end
	end

	if ( ( ent:GetClass() == "trigger_changelevel" ) && ( key == "map" ) ) then
	
		ent.map = value
	
	end

	if ( ( ent:GetClass() == "npc_combine_s" ) && ( key == "additionalequipment" ) && ( value == "weapon_shotgun" ) ) then
	
		ent:SetSkin( 1 )
	 
	end

end

concommand.Add("changelevel2", function(ply,com,arg) 
    if ply:IsValid() then return end --only let server console access this command
    RunConsoleCommand("changelevel", arg[1])
end)

concommand.Add("tf_reload_addon_server", function(ply)
	if IsValid(ply) and not (ply:IsListenServerHost() or ply:IsAdmin()) then
		ply:PrintMessage(HUD_PRINTTALK, "[TF2-Gamemode] You need to be host or admin to reload server scripts.")
		return
	end

	local currentMap = game.GetMap()
	if not currentMap or currentMap == "" then return end

	for _, v in ipairs(player.GetAll()) do
		v:PrintMessage(HUD_PRINTTALK, "[TF2-Gamemode] Reloading server/shared scripts by changing level to " .. currentMap .. "...")
	end

	timer.Simple(0.1, function()
		RunConsoleCommand("changelevel", currentMap)
	end)
end)


if ( file.Exists( "tf/gamemode/maps/"..game.GetMap()..".lua", "LUA" ) ) then

	include( "maps/"..game.GetMap()..".lua" )

end
  
-- Called by GoToNextLevel
function GM:GrabAndSwitch()

	changingLevel = true

	game.ConsoleCommand( "changelevel "..NEXT_MAP.."\n" )
 
end


hook.Add( "PlayerButtonDown", "PlayerButtonDownTF", function( pl, key )
	if key == KEY_F4 then
		local map = string.lower(game.GetMap() or "")
		if string.find(map, "mvm_", 1, true) and TF_MVM and TF_MVM.Runtime and TF_MVM.Runtime.Active and TF_MVM.Runtime.Setup then
			pl:ConCommand("player_ready_toggle")
			return
		end
	end
	if key == KEY_G then 
		if (pl:GetPlayerClass() == "sentrybuster") then
			pl:ConCommand("tf_sentrybuster_explode")         
		else
			for k,v in ipairs(ents.FindInSphere(pl:GetPos(), 300)) do
				if (v:IsPlayer() and v:GetNWBool("Congaing") and !pl:GetNWBool("Congaing",false)) then
					pl:ConCommand("tf_taunt_conga_start")
					return
				elseif (v:IsPlayer() and v:GetNWBool("Russian") and !pl:GetNWBool("Russian",false)) then
					pl:ConCommand("tf_taunt_russian_start")
					return
				end
			end
			timer.Simple(0.05, function() 
			
				if (pl:GetNWBool("Congaing",false)) then
					pl:ConCommand("tf_taunt_conga_stop")
					return
				end
				if (pl:GetNWBool("Russian",false)) then
					pl:ConCommand("tf_taunt_russian_stop")
					return
				end

				if (pl:GetActiveWeapon():GetClass() == "weapon_physcannon") then
					if (pl:GetPlayerClass() == "scout") then
						pl:ConCommand("tf_taunt_come_and_get_me")
					else
						pl:ConCommand("tf_taunt_laugh")
					end
				elseif (pl:GetActiveWeapon():GetClass() == "weapon_physgun") then
					pl:ConCommand("tf_taunt_directors_vision")
				else
					local date = os.date("%b",os.time())
					if (date == "Oct" and math.random(1,2) == 1) then
						pl:ConCommand("tf_taunt_thriller")
					else
						pl:ConCommand("tf_taunt "..pl:GetActiveWeapon():GetSlot() + 1)         
					end
				end
				--print("taunt")
				--print(pl:GetWeapon(pl:GetActiveWeapon():GetClass()):GetSlot() + 1)

			end)
		end
	end
	if key == KEY_SPACE then
		if (!pl:Alive() and pl:GetObserverMode() != OBS_MODE_DEATHCAM and pl:Team() != TEAM_SPECTATOR and !pl.IsSpectating) then
			pl:SetObserverMode(OBS_MODE_CHASE)
			pl:ConCommand("tf_spectate_respawn")
		end
	end
	if key == KEY_H and TF_IsGrapplingHookEnabled and TF_IsGrapplingHookEnabled() then
		pl:SelectWeapon("tf_weapon_grapplinghook")
		timer.Simple(0.1, function()
			if (pl:GetActiveWeapon():GetClass() == "tf_weapon_grapplinghook") then
				pl:ConCommand("+attack") 
			end
		end)
	end
	if key == KEY_Z then 
		if pl:Team() ~= TEAM_SPECTATOR then
			pl:ConCommand("voice_menu_1")
		end
	end
	if pl:GetPlayerClass() == "fastzombie" then
		if key == KEY_SPACE and pl:OnGround() then 
			pl:EmitSound("NPC_FastZombie.Scream") 
			pl:SetJumpPower(600) 
		end
	end
	if key == KEY_X then  
		if pl:Team() ~= TEAM_SPECTATOR then
			pl:ConCommand("voice_menu_2")
		end
	end
	if key == KEY_L then
		pl:ConCommand("gmod_undo")   
	end
	if key == KEY_C then
		if pl:Team() ~= TEAM_SPECTATOR then
			pl:ConCommand("voice_menu_3")
		end
	end
	if key == KEY_COMMA then
		if pl:Team() == TEAM_SPECTATOR then
			pl:ConCommand("tf_changeteam")
		else
			pl:ConCommand("tf_changeclass")
		end
	end
	if key == KEY_M then
		pl:ConCommand("hud_showloadout 1")
	end  	
	if key == KEY_N then
		pl:ConCommand("gm_showspare1")
	end
	if key == KEY_PERIOD then
		pl:ConCommand("tf_changeteam")
	end
		
end)

hook.Add("PlayerInitialSpawn", "TF_MVM_ReadyBindF4", function(pl)
	local map = string.lower(game.GetMap() or "")
	if not string.find(map, "mvm_", 1, true) then return end

	timer.Simple(1, function()
		if not IsValid(pl) then return end
		-- Server-triggered "bind" is blocked in modern GMod; provide guidance instead.
		pl:PrintMessage(HUD_PRINTTALK, "[TF2-Gamemode] Tip: bind F4 \"player_ready_toggle\"")
	end)
end)

hook.Add( "PlayerButtonUp", "PlayerButtonUpTF", function( pl, key )
	if key == KEY_H and TF_IsGrapplingHookEnabled and TF_IsGrapplingHookEnabled() then
		if (pl:GetActiveWeapon():GetClass() == "tf_weapon_grapplinghook") then
			pl:GetActiveWeapon():EndAttack(true)
		end
		pl:ConCommand("-attack")
		pl:ConCommand("lastinv") 
		pl:StopSound("Grappling")
	end  
end)	 
 
  
concommand.Add("changeclass", function(pl, cmd, args)
	if SERVER then
		if not args[1] then return end
		if pl:Team()==TEAM_SPECTATOR then return end
		if pl:GetObserverMode() ~= OBS_MODE_NONE then pl:Spectate(OBS_MODE_NONE) end
		if pl:Alive() and pl:GetNWBool("InRespawnRoom", false) then
			pl:SetPlayerClass(args[1])
			pl:KillSilent()
			pl:Spawn()
			return
		end
		if (!pl:Alive()) then 
			timer.Simple(0.1, function() 
				pl:Spawn() 
			end) 
		end
		if pl:Alive() and GetConVar("tf_kill_on_change_class"):GetInt() ~= 0 then pl:Kill() end	
		--if GetConVar("tf_kill_on_change_class"):GetInt() ~= 0 then pl:SetPlayerClass("gmodplayer") end
		pl:SetPlayerClass(args[1])
	end
end, function() return GAMEMODE.PlayerClassesAutoComplete end)

concommand.Add("join_class", function(pl, cmd, args)
	if SERVER then
		if not args[1] then return end
		if pl:Team()==TEAM_SPECTATOR then return end
		if pl:GetObserverMode() ~= OBS_MODE_NONE then pl:Spectate(OBS_MODE_NONE) end
		if pl:Alive() and pl:GetNWBool("InRespawnRoom", false) then
			pl:SetPlayerClass(args[1])
			pl:KillSilent()
			pl:Spawn()
			return
		end
		if pl:Alive() and GetConVar("tf_kill_on_change_class"):GetInt() ~= 0 then pl:Kill() end	
		--if GetConVar("tf_kill_on_change_class"):GetInt() ~= 0 then pl:SetPlayerClass("gmodplayer") end
		pl:SetPlayerClass(args[1])
	end
end, function() return GAMEMODE.PlayerClassesAutoComplete end)	

function RandomWeapon2(ply, wepslot)
	local weps = tf_items.ReturnItems()
	local class = ply:GetPlayerClass()
	local validweapons = {}
	for k, v in pairs(weps) do
		if v and istable(v) and isstring(wepslot) and v["name"] and v["item_slot"] == wepslot and v["used_by_classes"] and v["used_by_classes"][class] and !string.StartWith(v["name"], "Australium") and v["craft_class"] == "weapon" then
			table.insert(validweapons, v["name"])
		end 
	end

	local wep = table.Random(validweapons)
	ply:EquipInLoadout(wep)
end 

function RandomCosmetic(ply, wepslot)
	local weps = tf_items.ReturnItems()
	local class = ply:GetPlayerClass()
	local validweapons = {}
	for k, v in pairs(weps) do
		if v and istable(v) and isstring(wepslot) and v["name"] and v["item_slot"] == wepslot and v["used_by_classes"] and v["used_by_classes"][class] and !string.StartWith(v["name"], "Australium") and (v["item_class"] == "tf_wearable" || !IsValid(v["item_class"]) ) then
			table.insert(validweapons, v["name"])
		end
	end

	local wep = table.Random(validweapons)
	ply:EquipInLoadout(wep)
end

function RandomWeapon(ply, wepslot)
	local weps = tf_items.ReturnItems()
	local validweapons = {}
	for k, v in pairs(weps) do
		if v and istable(v) and isstring(wepslot) and v["name"] and v["item_slot"] == wepslot and !string.StartWith(v["name"], "Australium") and v["craft_class"] == "weapon" then
			PrintTable(v)
			table.insert(validweapons, v["name"])
		end 
	end

	local wep = table.Random(validweapons)  

	ply:PrintMessage(HUD_PRINTTALK, "You were given " .. wep .. "!")
	ply:ConCommand("giveitem " .. wep)
end
 
concommand.Add("randomweapon", function(ply, _, args)
	if !args[1] then
		local random = math.random(1, 3)
		if random == 1 then
			RandomWeapon(ply, "primary")
		elseif random == 2 then
			RandomWeapon(ply, "secondary")
		elseif random == 3 then
			RandomWeapon(ply, "melee")
		end 
	else
		RandomWeapon(ply, args[1])
	end
end)
  
function GM:PlayerSpawn(ply)
	ply.TFRespawnOverrideTime = nil
	ply.TFRespawnOverrideName = nil
	ply.TFRespawnOverrideEntity = nil
	
	if (ply:GetPlayerClass() != "") then
		local c = GAMEMODE.PlayerClasses[ply:GetPlayerClass()]
		ply.ItemLoadout = table.Copy(c.DefaultLoadout)
		ply.ItemProperties = {}
	end

	-- Hard spectator path: never run normal spawn/class/hud setup for spectator team.
	if ply:Team() == TEAM_SPECTATOR then
		ply:StripWeapons()
		ply:StripAmmo()
		ply.IsSpectating = true
		ply:SetNWBool("SpawnGlows", false)
		ply:UnSpectate()
		ply:Spectate(OBS_MODE_ROAMING)
		self:PlayerSpawnAsSpectator(ply)
		timer.Simple(0, function()
			if IsValid(ply) and ply:Team() == TEAM_SPECTATOR then
				ply:ConCommand("tf_spectate")
			end
		end)
		return
	end

	ply:SetNWBool("SpawnGlows",true)
	timer.Simple(10, function()
		if not IsValid(ply) then return end
		ply:SetNWBool("SpawnGlows",false)
	end)
	--[[
	if (string.StartWith(game.GetMap(),"c1m") or string.StartWith(game.GetMap(),"c2m") or string.StartWith(game.GetMap(),"c3m") or string.StartWith(game.GetMap(),"c4m") 
	or string.StartWith(game.GetMap(),"c5m") or string.StartWith(game.GetMap(),"c6m") or string.StartWith(game.GetMap(),"c7m") or string.StartWith(game.GetMap(),"c8m")
	or string.StartWith(game.GetMap(),"c9m") or string.StartWith(game.GetMap(),"c10m") or string.StartWith(game.GetMap(),"c11m") or string.StartWith(game.GetMap(),"c12m")
	or string.StartWith(game.GetMap(),"c13m") or string.StartWith(game.GetMap(),"c14m")) then
		if (!IsValid(GAMEMODE.Director)) then
			local director = ents.Create("ai_director")
			director:SetPos(ply:GetPos())
			director:SetAngles(ply:EyeAngles())
			director:Spawn()
			director:Activate()
			GAMEMODE.Director = director
		end
	end]]
	for k,v in ipairs(ents.GetAll()) do
		if (v:IsNPC()) then
			GAMEMODE:UpdateEntityRelationship(v)
		end
	end
	-- engage a rare chance of getting the hacker bot's fake aim (derp)
	if (ply:IsBot() and math.random(1,1000) == 1) then
		ply:SetNWBool("IsDerpAim",false)
	else
		ply:SetNWBool("IsDerpAim",false)
	end

		if (player.GetCount() == 1) then

			if (!GAMEMODE.round_active and ply:Team() != TEAM_SPECTATOR and not string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true)) then
				RunConsoleCommand("gmod_admin_cleanup")
				GAMEMODE.round_active = true
				timer.Simple(0.1, function()
						local roundtimer = ents.Create("team_round_timer")
						roundtimer.Properties = {
							start_paused = 0,
							timer_length = 15,
							max_length = 15,
							auto_countdown = 1, 
							show_in_hud = 1,
							setup_length = 0,
						}
						roundtimer:Spawn()
						roundtimer:Activate()
						timer.Simple(1, function()
							roundtimer:SetAndResumeTimer2(15,false)
							roundtimer.WaitingForPlayers = true
						end)
					
					for k,v in ipairs(player.GetAll()) do
						v:Spawn()
						v:SetNWBool("Taunting",true)
						timer.Create("SlowGuydown"..v:EntIndex(), 0.1, 48, function()
							v:SetWalkSpeed(1)
							v:SetRunSpeed(1)
						end)
						timer.Simple(5, function()
							v:SetNWBool("Taunting",false)
							v:ResetClassSpeed()
						end)
					end
					timer.Stop("WaitingForPlayers",18,1)
					timer.Create("WaitingForPlayers",18,1,function()
						timer.Simple(0.1, function()
						
							GAMEMODE.round_active = true
							RunConsoleCommand("gmod_admin_cleanup") 
							for k,v in ipairs(player.GetAll()) do
								v:Spawn()
								v:SetNWBool("Taunting",true)
								timer.Create("SlowGuydown"..v:EntIndex(), 0.1, 48, function()
									v:SetWalkSpeed(1)
									v:SetRunSpeed(1)
								end) 
								timer.Simple(5, function()
									v:SetNWBool("Taunting",false)
									v:ResetClassSpeed()
									v:Speak("TLK_ROUND_START")
								end)
							end
		  
						end)
					end) 
				end)  
			end 

		end

	ply:PrecacheGibs()
	
	ply:DoAnimationEvent(ACT_MP_ATTACK_STAND_POSTFIRE, true)
	--ply:ScreenFade( SCREENFADE.IN, Color( 0, 0, 0, 255 ), 0.01, 0 ) 

	-- Fix the blackness glitch in TSP maps 
	if (game.GetMap() == "map1") then
		for k,v in ipairs(ents.GetAll()) do
			if (v:GetName() == "cam_black") then
				v:Fire("Disable","",0)
			end
		end 
	end
	ply:SetGravity(0) 
	if ply.CPPos and ply.CPAng then
		ply:SetPos(ply.CPPos) 
		ply:SetEyeAngles(ply.CPAng)
	end 
	ply.anim_Deployed = false
	if (ply:Team() != TEAM_NEUTRAL && ply:Team() != TEAM_FRIENDLY) then
		ply:SetNoCollideWithTeammates(true)
	else
		ply:SetNoCollideWithTeammates(false)
	end
	if string.find(game.GetMap(), "mvm_") then
		
            
				if ply:Team() == TEAM_BLU then
                    for _,flag in ipairs(ents.FindByClass("item_teamflag_mvm")) do
                        if (!IsValid(flag.Carrier) and !flag.NextReturn) then
                            if (ply:GetPlayerClass() != "engineer" and ply:GetPlayerClass() != "medic" and ply:GetPlayerClass() != "sentrybuster") then
                                flag:Pickup(ply)
                            end
                        end
                    end
				end
		timer.Simple(0.4, function()
			for k,v in ipairs(ents.FindByClass("obj_teleporter")) do
				if GAMEMODE:EntityTeam(v) == TEAM_BLU then
					if ply:Team() == TEAM_BLU then
						ply:SetPos(v:GetPos())
						v:Teleport(ply)
						v:EmitSound("MVM.Robot_Teleporter_Deliver")
					end
				end
			end
		end)
	end 	 
	if ply:GetPlayerClass() == "engineer" and ply.TFBot then 
		for k,v in ipairs(ents.FindByClass("bot_hint_sentrygun")) do
			if (IsValid(v)) then
				timer.Simple(0.1, function()
					ply:SelectWeapon("tf_weapon_wrench")
				end) 
				timer.Simple(0.8, function() 
					ply:Build(2,0)
				end)
			end
		end
	end
	timer.Simple(0.5, function()
		if not IsValid(ply) then return end
		if ply:GetPlayerClass() == "engineer" and (string.find(ply:GetModel(),"/bot_") or (ply.TFBot and ply:Team() == TEAM_BLU and string.find(game.GetMap(),"mvm_"))) then 
			ply:EmitSound("MVM.Robot_Engineer_Spawn")
			
			umsg.Start("TF_PlayGlobalSound")
				umsg.String("Announcer.MVM_First_Engineer_Teleport_Spawned")
			umsg.End()
		end
	end)
	ply:ShouldDropWeapon(false)
	--[[ply:SetNWBool("ShouldDropBurningRagdoll", false)
	ply:SetNWBool("ShouldDropDecapitatedRagdoll", false)
	ply:SetNWBool("DeathByHeadshot", false)]]
	ply:ResetDeathFlags()
	ply:SetNoCollideWithTeammates( true ) 
	ply.LastWeapon = nil
	timer.Create("ItsHealing"..ply:EntIndex(), 1, 0, function()
		if not IsValid(ply) then
			timer.Remove("ItsHealing"..ply:EntIndex())
			return
		end
		if (ply:GetPlayerClass() != "medic") then return end
		if (!ply:Alive()) then return end
		if (ply:Health() < ply:GetMaxHealth()) then
			GAMEMODE:HealPlayer(ply, ply, 2, false, false)
		end
	end)
	if GetConVar("tf_crossover_mode"):GetBool() then
		if ply:IsHL2() then
			if ply:Team() == TEAM_RED then
				ply:SetPlayerClass(table.Random({"bill","louis","zoey","francis","nick","coach"}))
			else
				ply:SetPlayerClass(table.Random({"charger","hunter","boomer","smoker","tank"}))
			end
		elseif !ply:IsHL2() then
			if ply:IsL4D() then return end
			if ply:Team() == TEAM_RED then
				ply:SetPlayerClass(table.Random({"bill","louis","zoey","francis","nick","coach"}))
			else
				ply:SetPlayerClass(table.Random({"charger","hunter","boomer","smoker","tank"})) 
			end
		end
	end
	self:ResetKills(ply)
	self:ResetDamageCounter(ply)
	self:ResetCooperations(ply)
	self:StopCritBoost(ply)
	for k,v in ipairs(ents.FindByClass("trigger_weapon_strip")) do
		if IsValid(v) then
			v:Fire("Kill", "", 0.1)
		end
	end
	for k,v in ipairs(ents.FindByClass("player_weaponstrip")) do
		if IsValid(v) then
			v:Fire("Kill", "", 0.1)
		end
	end
	ply:UnSpectate()
	-- Reinitialize class
	if ply:GetPlayerClass()=="" and ply:Team() != TEAM_SPECTATOR then
		ply:ConCommand("tf_changeclass")
		ply:SetPlayerClass("gmodplayer")
		--ply:Spectate(OBS_MODE_FIXED)
		--ply:StripWeapons()
	--[[elseif ply:GetPlayerClass()=="sniper" then -- dumb hack wtf??
		ply:SetPlayerClass("scout")
		timer.Simple(0.1, function()
			if IsValid(ply) then
				ply:SetPlayerClass("sniper")
			end
		end)
		if ply:GetObserverMode() ~= OBS_MODE_NONE then
			ply:UnSpectate()
		end]]	
	elseif ply:GetPlayerClass()=="" and ply:Team() == TEAM_SPECTATOR then
		-- Do not reopen team select for established spectators; joinflow handles initial team selection.
		ply:ConCommand("tf_spectate","2")
		--ply:Spectate(OBS_MODE_FIXED)
		--ply:StripWeapons()
	--[[elseif ply:GetPlayerClass()=="sniper" then -- dumb hack wtf??
		ply:SetPlayerClass("scout")
		timer.Simple(0.1, function()
			if IsValid(ply) then
				ply:SetPlayerClass("sniper")
			end
		end)
		if ply:GetObserverMode() ~= OBS_MODE_NONE then
			ply:UnSpectate()
		end]]	
	elseif ply:GetPlayerClass()=="sniper" then
		ply:SetPlayerClass("scout")
		ply:SetPlayerClass("sniper")
		timer.Simple(0.1, function()

			if ply:GetInfoNum("tf_skeleton", 0) == 1 then
				ply:SetModel("models/bots/skeleton_sniper/skeleton_sniper.mdl")
			end
			ply:SetPlayerClass("sniper")
		end)
	elseif ply:GetPlayerClass()=="heavy" then
		timer.Simple(0.1, function()

			if ply:GetInfoNum("tf_yeti", 0) == 1 then
				ply:SetModel("models/player/yeti.mdl")
			end
		end)
	end

	timer.Simple(0.0, function() -- god i'm such a timer whore
		if not IsValid(ply) or not ply.SetPlayerClass then return end
		-- are you sure about that
		ply:SetPlayerClass(ply:GetPlayerClass())
		
	end)
	if ply:GetObserverMode() ~= OBS_MODE_NONE then
		ply:UnSpectate()
	end

	if ply:Team()==TEAM_SPECTATOR then
		GAMEMODE:PlayerSpawnAsSpectator( ply )
	end
	ply:SetupHands()
	
	if ply:IsHL2() then
		ply:EquipSuit()
		ply:AllowFlashlight(true)
		local cl_playermodel = ply:GetInfo("cl_playermodel")
		local modelname = player_manager.TranslatePlayerModel(cl_playermodel)
		util.PrecacheModel(modelname)
		ply:SetModel(modelname)
	end
	
	if !ply:IsHL2() then
		ply:RemoveSuit()	
		ply:AllowFlashlight(GetConVar("tf_flashlight"):GetBool())

		if ply:Team()==TEAM_BLU or ply:Team()==TEAM_GREEN then
			ply:SetSkin(1)
		else
			ply:SetSkin(0)
		end

		for k, v in pairs(ents.FindByClass('tf_wearable_item')) do
			if v:GetClass() == 'tf_wearable_item' then
				if v:GetOwner() == ply and string.find(v:GetModel(), "zombie") then
					if ply:Team()==TEAM_BLU then
						ply:SetSkin(5)
					else
						ply:SetSkin(4)
					end
				end
			end
		end
	end
	if (TF_IsGrapplingHookEnabled and TF_IsGrapplingHookEnabled()) then
		ply:GiveItem("Grappling Hook")
	end
	ply:Speak("TLK_PLAYER_EXPRESSION", true)  
	ply.Warned = false
	
	local playercolorconv = ply:GetInfo("cl_playercolor") 
	local weaponcolorconv = ply:GetInfo("cl_weaponcolor") 
	local playercolor = Vector(string.sub(playercolorconv, 1, 8), string.sub(playercolorconv, 10, 17), string.sub(playercolorconv, 19, 26))
	local weaponcolor = Vector(string.sub(weaponcolorconv, 1, 8), string.sub(weaponcolorconv, 10, 17), string.sub(weaponcolorconv, 19, 26))

	local groups = ply:GetInfo( "cl_playerbodygroups" )
	if ( groups == nil ) then groups = "" end
	local groups = string.Explode( " ", groups )
	ply:SetCustomCollisionCheck(true)
	if (ply:Team() != TEAM_NEUTRAL and ply:Team() != TEAM_FRIENDLY) then

		ply:SetPlayerColor(Vector(team.GetColor(ply:Team()).r / 255,team.GetColor(ply:Team()).g / 255,team.GetColor(ply:Team()).b / 255))
		ply:SetWeaponColor(Vector(team.GetColor(ply:Team()).r / 255,team.GetColor(ply:Team()).g / 255,team.GetColor(ply:Team()).b / 255))
		for k = 0, ply:GetNumBodyGroups() - 1 do
			ply:SetBodygroup( k, tonumber( groups[ k + 1 ] ) or 0 )
		end

	else
		for k = 0, ply:GetNumBodyGroups() - 1 do
			ply:SetBodygroup( k, tonumber( groups[ k + 1 ] ) or 0 )
		end
		ply:SetPlayerColor(playercolor)
		ply:SetWeaponColor(weaponcolor)
	end
	if (ply:Team() == TEAM_FRIENDLY) then
		ply:SetAvoidPlayers(false)  
		ply:SetCollisionGroup(COLLISION_GROUP_WORLD)
	else
		ply:SetAvoidPlayers(true)  
	end
	
	if !ply:IsHL2() then
		timer.Simple(0.05, function()
			if not IsValid(ply) or not ply.GiveLoadout then return end
			ply:GiveLoadout()
		end)
	end

	timer.Simple(0.3, function()
	
		if (ply:IsBot() and !ply.TFBot) then
			ply:SetPlayerClass(table.Random({"scout","soldier","pyro","demoman","heavy","engineer","medic","sniper","spy"}))
		end
		for k,v in ipairs(team.GetPlayers(TEAM_RED)) do
			if ply:IsMiniBoss() then
				v:Speak("TLK_MVM_GIANT_CALLOUT")
			end
		end

	end)
	umsg.Start("ExitFreezecam", ply)
	umsg.End()

	net.Start("TF_PlayerSpawn")
	net.WriteEntity(ply)
	net.Broadcast()
	ply:SetMaterial("")
	--[[
	timer.Simple(0.5, function()
		if (ply:IsBot()) then
			if (ply:GetWeapons()[2]:GetClass() == "tf_weapon_lunchbox_drink" or ply:GetWeapons()[1]:GetClass() == "tf_weapon_lunchbox_drink") then

					ply:SelectWeapon("tf_weapon_lunchbox_drink")
					timer.Simple(0.8, function()
						ply:GetActiveWeapon():PrimaryAttack()
						timer.Simple(0.95, function()
							ply:SelectWeapon("tf_weapon_bat")	
						end)
					end)
			end
		end 
	end)]]
	
	umsg.Start("PlayerClassChanged")
		umsg.Long(ply:EntIndex()) 
		umsg.String(ply:GetPlayerClass())
		umsg.String(ply:GetPlayerClass())
	umsg.End()
	if (ply:GetInfoNum("civ2_playermodel_reference_pose_prevention",0) == 1) then
		if (!ply:IsHL2()) then

			local axe = ents.Create("prop_animated")
			local cl_playermodel = ply:GetInfo("cl_playermodel")
			local modelname = player_manager.TranslatePlayerModel(cl_playermodel)
			util.PrecacheModel(modelname)
			axe:SetModel(modelname)
			axe:SetParent(ply)
			axe:SetPos(ply:GetPos())
			axe:SetAngles(ply:GetAngles())
			axe:Spawn()
			axe:SetPuppeteerModel(ply:GetModel())
			axe:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			axe:GetPuppeteer():SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			ply.PuppetAnim = axe
			ply:SetNWEntity("PuppetAnim",axe)
			ply:SetMaterial("color")
			timer.Simple(0.3, function()
				axe:SetPuppeteerModel(ply:GetModel())
			end)
		end
	end
end

function GM:PlayerSetHandsModel( ply, ent )
	local simplemodel = player_manager.TranslateToPlayerModelName( ply:GetModel() )
	local info = player_manager.TranslatePlayerHands( simplemodel )
	if (!IsValid(ent)) then return end
	if ( info ) then
		if ply:IsHL2() then
			ent:SetModel( info.model )
			ent:SetSkin( info.skin )
			ent:SetBodyGroups( info.body )
		else
				if (ply.IsL4DZombie and !ply:IsL4D()) then
					local class = ply.playerclass
					if (string.find(class,"demoman")) then
						class = "demo"
					elseif (string.find(class,"Demoman")) then
						class = "demo"
					elseif (string.find(class,"demoknight")) then
						class = "demo"
					end
					ent:SetModel("models/weapons/c_models/c_"..class.."_arms.mdl")
				elseif (ply:GetPlayerClass() == "demoman") then
					if ((IsValid(ply:GetActiveWeapon()) and string.find(ply:GetActiveWeapon():GetClass(),"tf_weapon")) or !IsValid(ply:GetActiveWeapon())) then

						ent:SetModel( "models/weapons/c_models/c_demo_arms.mdl" )

					else
						
						if (file.Exists("models/player/demomanplayer/demonstrationman_hands.mdl", "WORKSHOP")) then
							ent:SetModel( "models/player/demomanplayer/demonstrationman_hands.mdl" )
						else
							ent:SetModel("models/weapons/v_hands.mdl")
						end

					end
				elseif (ply:GetPlayerClass() == "mercenary") then
					if ((IsValid(ply:GetActiveWeapon()) and string.find(ply:GetActiveWeapon():GetClass(),"tf_weapon")) or !IsValid(ply:GetActiveWeapon())) then

						ent:SetModel( "models/weapons/c_models/c_merc_arms.mdl" )

					else
						
						ent:SetModel("models/weapons/v_hands.mdl")

					end
				elseif (ply:GetPlayerClass() == "civilian_") then
					ent:SetModel( "models/weapons/c_models/c_civilian_arms.mdl" )
				elseif (ply:GetPlayerClass() == "civilian") then
					ent:SetModel( "models/weapons/c_models/c_scout_arms.mdl" )
				elseif (ply:GetPlayerClass() == "medicshotgun") then
					ent:SetModel( "models/weapons/c_models/c_medic_arms.mdl" )
				else
					local t = ply:GetPlayerClassTable()
					if (ply:IsL4D()) then
						if (ply:GetPlayerClass() == "charger" or ply:GetPlayerClass() == "jockey" or ply:GetPlayerClass() == "spitter") then
							ent:SetModel( "models/weapons/arms/v_"..ply:GetPlayerClass().."_arms.mdl" )
						else
							local class = ply:GetPlayerClass()
							if (ply:GetPlayerClass() == "tank_l4d") then
								class = "hulk"
							end
							if (string.find(ply:GetModel(),"l4d1")) then
								ent:SetModel( "models/v_models/weapons/v_claw_"..class.."_l4d1.mdl" )
							elseif (string.find(ply:GetModel(),"dlc3")) then
								ent:SetModel( "models/v_models/weapons/v_claw_"..class.."_dlc3.mdl" )
							else
								ent:SetModel( "models/v_models/weapons/v_claw_"..class..".mdl" )
							end
						end
					else 
						
						if ((IsValid(ply:GetActiveWeapon()) and string.find(ply:GetActiveWeapon():GetClass(),"tf_weapon")) or !IsValid(ply:GetActiveWeapon())) then
							local armClass = (t and t.ModelName) or ply:GetPlayerClass()
							if armClass == "demoman" then
								armClass = "demo"
							end
							local armModel = "models/weapons/c_models/c_"..armClass.."_arms.mdl"

							if (file.Exists(armModel, "GAME")) then
								ent:SetModel(armModel)
							else
								ent:SetModel( "models/weapons/c_models/c_sniper_arms.mdl" )
							end

						else

							ent:SetModel("models/weapons/v_hands.mdl")

						end
					end
				end
				if (ply:Team() == TEAM_BLU or ply:Team() == TEAM_GREEN) then
					ent:SetSkin( 1 )
				else
					ent:SetSkin( 0 )
				end
		end
	end
end

-- Fixing spawning at the wrong spawnpoint on HL2 maps
function GM:PlayerSelectSpawn(pl)
	if self.MasterSpawn==nil then
		self.MasterSpawn = false
		for _,v in pairs(ents.FindByClass("info_player_start")) do
			if v.IsMasterSpawn then
				self.MasterSpawn = v
				break
			end
		end
	end
	
	local overrideName = tostring(pl.TFRespawnOverrideName or "")
	if overrideName ~= "" then
		local overrideSpawns = {}
		for _, spawn in ipairs(ents.FindByName(overrideName)) do
			if not IsValid(spawn) then continue end
			if spawn:GetClass() ~= "info_player_teamspawn" then continue end
			if spawn.IsAvailableForTeam and not spawn:IsAvailableForTeam(pl:Team(), true) then
				continue
			end
			overrideSpawns[#overrideSpawns + 1] = spawn
		end

		if IsValid(overrideSpawns[1]) then
			return table.Random(overrideSpawns)
		end
	end

	local spawnsred = {}
	local spawnsblu = {}
	local preferredRed = {}
	local preferredBlu = {}

	for k, v in pairs(ents.FindByClass("info_player_teamspawn")) do
		if not IsValid(v) then continue end
		if not v.IsAvailableForTeam then continue end

		if v:IsAvailableForTeam(TEAM_BLU, false) then
			table.insert(spawnsblu, v)
			if PointInRespawnRoom and PointInRespawnRoom(pl, v:GetPos(), true) then
				table.insert(preferredBlu, v)
			end
		end
		if v:IsAvailableForTeam(TEAM_RED, false) then
			table.insert(spawnsred, v)
			if PointInRespawnRoom and PointInRespawnRoom(pl, v:GetPos(), true) then
				table.insert(preferredRed, v)
			end
		end
	end

	for k, v in pairs(ents.FindByClass("info_player_counterterrorist")) do
		----print(v, "says")
		table.insert(spawnsblu, v)
	end

	for k, v in pairs(ents.FindByClass("info_player_terrorist")) do
		----print(v, "says")
		table.insert(spawnsred, v)
	end

	for k, v in pairs(ents.FindByClass("info_player_allies")) do
		----print(v, "says")
		table.insert(spawnsblu, v)
	end

	for k, v in pairs(ents.FindByClass("info_player_axis")) do
		----print(v, "says")
		table.insert(spawnsred, v)
	end


	if pl:Team() == TEAM_RED and IsValid(preferredRed[1]) then
		return table.Random(preferredRed)
	elseif pl:Team() == TEAM_RED and IsValid(spawnsred[1]) then
		return table.Random(spawnsred)
	elseif pl:Team() == TEAM_BLU and IsValid(preferredBlu[1]) then
		return table.Random(preferredBlu)
	elseif pl:Team() == TEAM_BLU and IsValid(spawnsblu[1]) then
		return table.Random(spawnsblu)
	elseif pl:Team() == TF_TEAM_PVE_INVADERS and IsValid(preferredBlu[1]) then
		return table.Random(preferredBlu)
	elseif pl:Team() == TF_TEAM_PVE_INVADERS and IsValid(spawnsblu[1]) then
		return table.Random(spawnsblu)
	end

	if self.MasterSpawn then
		return self.MasterSpawn
	end
	
	return self.BaseClass:PlayerSelectSpawn(pl)
end
hook.Add( "PlayerGiveSWEP", "BlockPlayerSWEPs", function( ply, class, swep )
	if ( GetConVar("tf_competitive"):GetBool() and not ply:IsAdmin() ) then
		return false
	end
	if ( ply:Team() == TEAM_BLU and string.find(game.GetMap(), "mvm_") ) then
		return false
	end
end )   

if SERVER then
	concommand.Add("tf_dump_spawnstate", function(ply)
		if IsValid(ply) and not ply:IsAdmin() then return end

		print("[SpawnDebug] info_player_teamspawn:")
		for _, spawn in ipairs(ents.FindByClass("info_player_teamspawn")) do
			local kv = spawn.GetKeyValues and spawn:GetKeyValues() or {}
			local teamNum = spawn.GetSpawnTeamNum and spawn:GetSpawnTeamNum() or tonumber(spawn.TeamNum or kv.TeamNum or kv.teamnum or -1) or -1
			local redAvail = spawn.IsAvailableForTeam and spawn:IsAvailableForTeam(TEAM_RED, false)
			local bluAvail = spawn.IsAvailableForTeam and spawn:IsAvailableForTeam(TEAM_BLU, false)
			local triggered = spawn.IsTriggeredSpawn and spawn:IsTriggeredSpawn() or false
			local roundRed = spawn.IsRoundEnabledForTeam and spawn:IsRoundEnabledForTeam(TEAM_RED)
			local roundBlu = spawn.IsRoundEnabledForTeam and spawn:IsRoundEnabledForTeam(TEAM_BLU)
			local cpRed = spawn.IsControlPointEnabledForTeam and spawn:IsControlPointEnabledForTeam(TEAM_RED)
			local cpBlu = spawn.IsControlPointEnabledForTeam and spawn:IsControlPointEnabledForTeam(TEAM_BLU)
			print(string.format(
				"  spawn #%d name=%s pos=%s team=%s disabled=%s spawnmode=%s triggered=%s redAvail=%s bluAvail=%s roundRed=%s roundBlu=%s cpRed=%s cpBlu=%s controlpoint=%s roundRedName=%s roundBluName=%s rawTeamNum=%s rawteamnum=%s",
				spawn:EntIndex(),
				tostring(spawn:GetName() or ""),
				tostring(spawn:GetPos()),
				tostring(teamNum),
				tostring(spawn.IsDisabled and spawn:IsDisabled() or false),
				tostring(spawn.SpawnMode),
				tostring(triggered),
				tostring(redAvail),
				tostring(bluAvail),
				tostring(roundRed),
				tostring(roundBlu),
				tostring(cpRed),
				tostring(cpBlu),
				tostring(kv.controlpoint or kv.ControlPoint),
				tostring(kv.round_redspawn or kv.RoundRedSpawn),
				tostring(kv.round_bluespawn or kv.RoundBlueSpawn),
				tostring(kv.TeamNum),
				tostring(kv.teamnum)
			))
		end

		print("[SpawnDebug] func_respawnroom:")
		for _, room in ipairs(ents.FindByClass("func_respawnroom")) do
			local kv = room.GetKeyValues and room:GetKeyValues() or {}
			print(string.format(
				"  room #%d name=%s team=%s active=%s rawTeamNum=%s rawteamnum=%s",
				room:EntIndex(),
				tostring(room:GetName() or ""),
				tostring(room.TeamNum),
				tostring(room.GetActive and room:GetActive() or room.Active),
				tostring(kv.TeamNum),
				tostring(kv.teamnum)
			))
		end

		print("[SpawnDebug] func_respawnroomvisualizer:")
		for _, viz in ipairs(ents.FindByClass("func_respawnroomvisualizer")) do
			local kv = viz.GetKeyValues and viz:GetKeyValues() or {}
			print(string.format(
				"  viz #%d name=%s team=%s active=%s roomName=%s boundRoom=%s rawTeamNum=%s rawteamnum=%s",
				viz:EntIndex(),
				tostring(viz:GetName() or ""),
				tostring(viz.TeamNum),
				tostring(viz.Active),
				tostring(viz.RespawnRoomName or kv.respawnroomname or ""),
				IsValid(viz.RespawnRoom) and tostring(viz.RespawnRoom:GetName() or "") or "nil",
				tostring(kv.TeamNum),
				tostring(kv.teamnum)
			))
		end
	end)
end

local function EnsureEngineerCommandBindings()
	local old_group_translate = {
		[0] = {0,0},
		[1] = {1,0},
		[2] = {1,1},
		[3] = {2,0},
		[4] = {3,0},
	}
	local class_by_group = {
		[0] = "obj_dispenser",
		[1] = "obj_teleporter",
		[2] = "obj_sentrygun",
	}

	local function normalizeGroupSub(args)
		local group = tonumber(args and args[1])
		local sub = tonumber(args and args[2])
		if not group then return nil, nil end
		if sub == nil then
			local mapped = old_group_translate[group]
			if not mapped then return nil, nil end
			group, sub = mapped[1], mapped[2]
		end
		return group, sub
	end

	local function isOwnedBuilding(ent, pl)
		return IsValid(ent) and IsValid(pl) and (ent.Player == pl or ent:GetBuilder() == pl or ent:GetOwner() == pl)
	end

	local function countOwnedSentries(pl)
		local regular = 0
		local disposable = 0
		for _, ent in ipairs(ents.FindByClass("obj_sentrygun")) do
			if not isOwnedBuilding(ent, pl) then continue end
			if ent.TF_MVM_DisposableSentry then
				disposable = disposable + 1
			else
				regular = regular + 1
			end
		end
		return regular, disposable
	end

	local function canBuildByLimit(pl, group, sub)
		if isfunction(TF_CanPlayerBuildObject) then
			return TF_CanPlayerBuildObject(pl, group, sub, false)
		end

		local cv = GetConVar("tf_unlimited_buildings")
		if cv and cv:GetBool() then return true end

		local className = class_by_group[group]
		if not className then return true end

		if className == "obj_sentrygun" then
			local disposableLimit = 0
			if pl.TF_MVM_Dynamic then
				disposableLimit = math.max(0, math.floor(tonumber(pl.TF_MVM_Dynamic.DisposableSentryCount) or 0))
			end
			local regular, disposable = countOwnedSentries(pl)
			local allowDisposable = disposableLimit > 0 and regular >= 1 and disposable < disposableLimit
			return regular < 1 or allowDisposable
		end

		if className == "obj_teleporter" then
			for _, ent in ipairs(ents.FindByClass(className)) do
				if not isOwnedBuilding(ent, pl) then continue end
				if (sub == 0 and ent.IsEntrance and ent:IsEntrance()) or (sub == 1 and ent.IsExit and ent:IsExit()) then
					return false
				end
			end
			return true
		end

		for _, ent in ipairs(ents.FindByClass(className)) do
			if isOwnedBuilding(ent, pl) then
				return false
			end
		end
		return true
	end

	local function fallbackSelectBuilder(pl, args, useDeployedMode)
		if not IsValid(pl) or not pl:IsPlayer() then return false end
		local group, sub = normalizeGroupSub(args)
		if group == nil then return false end

		local builder = pl:GetWeapon("tf_weapon_builder")
		if not IsValid(builder) and isfunction(pl.GiveItem) then
			pl:GiveItem("TF_WEAPON_BUILDER")
			builder = pl:GetWeapon("tf_weapon_builder")
		end
		if not IsValid(builder) then return false end

		if useDeployedMode then
			builder:SetHoldType("BUILDING_DEPLOYED")
		else
			builder:SetHoldType("BUILDING")
		end

		local setOk = false
		if isfunction(builder.SetBuilding2) then
			setOk = builder:SetBuilding2(group, sub) and true or false
		elseif isfunction(builder.SetBuilding) then
			setOk = builder:SetBuilding(group, sub) and true or false
		end
		if not setOk then return false end

		pl:SelectWeapon("tf_weapon_builder")
		builder.Moving = useDeployedMode and true or false
		return true
	end

	concommand.Add("build", function(pl, _, args)
		if not IsValid(pl) or not pl:IsPlayer() then return end

		local group, sub = normalizeGroupSub(args)
		if group == nil then return end

		if isfunction(pl.Build) then
			pl:Build(group, sub)
			return
		end

		if not canBuildByLimit(pl, group, sub) then
			pl:EmitSound("Player.DenyWeaponSelection")
			return
		end
		if not fallbackSelectBuilder(pl, {group, sub}, false) then
			pl:EmitSound("Player.DenyWeaponSelection")
		end
	end)

	concommand.Add("move", function(pl, _, args)
		if not IsValid(pl) or not pl:IsPlayer() then return end

		local group, sub = normalizeGroupSub(args)
		if group == nil then return end

		if isfunction(pl.Move) then
			pl:Move(group, sub)
			return
		end
		if not fallbackSelectBuilder(pl, {group, sub}, true) then
			pl:EmitSound("Player.DenyWeaponSelection")
		end
	end)

	concommand.Add("destroy", function(pl, _, args)
		if not IsValid(pl) or not pl:IsPlayer() then return end

		local group, sub = normalizeGroupSub(args)
		if group == nil then return end

		if isfunction(pl.DestroyBuilding) then
			pl:DestroyBuilding(group, sub)
			return
		end

		local destroyed = false
		if group == 2 and sub == 0 then
			for _, ent in ipairs(ents.FindByClass("obj_sentrygun")) do
				if isOwnedBuilding(ent, pl) and isfunction(ent.Explode) then
					ent:Explode()
					destroyed = true
				end
			end
		elseif group == 0 and sub == 0 then
			for _, ent in ipairs(ents.FindByClass("obj_dispenser")) do
				if isOwnedBuilding(ent, pl) and isfunction(ent.Explode) then
					ent:Explode()
					destroyed = true
				end
			end
		elseif group == 1 and sub == 0 then
			for _, ent in ipairs(ents.FindByClass("obj_teleporter")) do
				if isOwnedBuilding(ent, pl) and ent.IsEntrance and ent:IsEntrance() and isfunction(ent.Explode) then
					ent:Explode()
					destroyed = true
				end
			end
		elseif group == 1 and sub == 1 then
			for _, ent in ipairs(ents.FindByClass("obj_teleporter")) do
				if isOwnedBuilding(ent, pl) and ent.IsExit and ent:IsExit() and isfunction(ent.Explode) then
					ent:Explode()
					destroyed = true
				end
			end
		end

		if not destroyed then
			pl:EmitSound("Player.DenyWeaponSelection")
		end
	end)
end
EnsureEngineerCommandBindings()

local PlayerGiveAmmoTypes = {TF_PRIMARY, TF_SECONDARY, TF_METAL}
function GM:GiveAmmoPercent(pl, pc, nometal, fromItems)
	--Msg("Giving "..pc.."% ammo to "..pl:GetName().." : ")
	local ammo_given = false 
	
	for _,v in ipairs(PlayerGiveAmmoTypes) do 
		if not nometal or v ~= TF_METAL then
			if isfunction(pl.GiveTFAmmo) then
				if pl:GiveTFAmmo(pc * 0.01, v, true) then
					ammo_given = true
				end
			else
				local maxAmmo = pl.AmmoMax and pl.AmmoMax[v] or nil
				if isnumber(maxAmmo) and maxAmmo > 0 and not pl:IsHL2() then
					local target = math.min(maxAmmo, math.ceil(maxAmmo * (pc * 0.01)))
					local current = tonumber(pl:GetAmmoCount(v) or 0) or 0
					if target > current then
						pl:GiveAmmo(target - current, v)
						ammo_given = true
					end
				end
			end
		end
	end
	
	--Msg("\n")
	local cloakAdded = 0
	if isfunction(TF_AddSpyCloakPercent) then
		cloakAdded = TF_AddSpyCloakPercent(pl, pc, fromItems == true)
	end

	if ammo_given then
		if pl:GetActiveWeapon().CheckAutoReload then
			pl:GetActiveWeapon():CheckAutoReload()
		end
	end
	
	return ammo_given or cloakAdded > 0
end

function GM:GiveAmmoPercentNoMetal(pl, pc)
	return self:GiveAmmoPercent(pl, pc, true)
end

function GM:GiveHealthPercent(pl, pc)
		if pl:IsPlayer() then
			umsg.Start("PlayerHealthBonus", pl)
				umsg.Short(pc)
			umsg.End()
			
			umsg.Start("PlayerHealthBonusEffect")
				umsg.Long(pl:UserID())
				umsg.Bool(pc>0)
				umsg.Bool(pc>100)
			umsg.End()
		else
			umsg.Start("EntityHealthBonusEffect")
				umsg.Entity(pl)
				umsg.Bool(pc>0)
				umsg.Bool(pc>100)
			umsg.End()
		end
	return pl:GiveHealth(pc * 0.01, true)
end

function GM:ShowHelp(ply)
	ply:ConCommand("tf_hatpainter")
end

function GM:ShowTeam(ply)
	ply:ConCommand("tf_menu")
end

function GM:ShowSpare1(ply)
	ply:ConCommand("tf_itempicker hat")
end

function GM:ShowSpare2(ply)
	if string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true)
		and TF_MVM and TF_MVM.Runtime and TF_MVM.Runtime:IsManagedActive()
		and IsValid(ply) and ply:IsPlayer() and not ply:IsBot() and not ply.TFBot and ply:Team() == TEAM_RED
	then
		ply:ConCommand("use_action_slot_item")
		return
	end
	ply:ConCommand("open_charinfo_direct")
end

function GM:HealPlayer(healer, pl, h, effect, allowoverheal)
	local heal_amount = h
	if heal_amount > 0 and IsValid(pl) and pl.InCond then
		local heal_mult = 1
		if TF_COND_MEDIGUN_DEBUFF and pl:InCond(TF_COND_MEDIGUN_DEBUFF) then
			heal_mult = heal_mult * 0.75
		end
		if TF_COND_HEALING_DEBUFF and pl:InCond(TF_COND_HEALING_DEBUFF) then
			heal_mult = heal_mult * 0.5
		end
		heal_amount = heal_amount * heal_mult
	end

	local health_given = pl:GiveHealth(heal_amount, false, allowoverheal)
	----print(health_given)
	if effect then
		if pl:IsPlayer() then
			umsg.Start("PlayerHealthBonus", pl)
				umsg.Short(h)
			umsg.End()
			
			umsg.Start("PlayerHealthBonusEffect")
				umsg.Long(pl:UserID())
				umsg.Bool(h>0)
				umsg.Bool(h>100)
			umsg.End()
		else
			umsg.Start("EntityHealthBonusEffect")
				umsg.Entity(pl)
				umsg.Bool(h>0)
				umsg.Bool(h>100)
			umsg.End()
		end
	end
	
	if health_given <= 0 then return end
	if not healer or not healer:IsPlayer() then return end
	
	healer.AddedHealing = (healer.AddedHealing or 0) + health_given
	healer.HealingScoreProgress = (healer.HealingScoreProgress or 0) + health_given
end

-- Deprecated, use HealPlayer instead
function GM:GiveHealthBonus(pl, h, allowoverheal)
	pl:GiveHealth(h, false, allowoverheal)
	
	if pl:IsPlayer() then
		umsg.Start("PlayerHealthBonus", pl)
			umsg.Short(h)
		umsg.End()
		
		umsg.Start("PlayerHealthBonusEffect")
			umsg.Long(pl:UserID())
			umsg.Bool(h>0)
		umsg.End()
	else
		umsg.Start("EntityHealthBonusEffect")
			umsg.Entity(pl)
			umsg.Bool(h>0)
		umsg.End()
	end
	
	return true
end

file.Append(LOGFILE, Format("Done loading, time = %f\n", SysTime() - load_time))
local load_time = SysTime()

--Half-Life 2 Campaign

-- Include the configuration for this map
function GM:GrabAndSwitch()
	for _, pl in pairs(player.GetAll()) do
		local plInfo = {}
		local plWeapons = pl:GetWeapons()
		
		plInfo.predicted_map = NEXT_MAP
		plInfo.health = pl:Health()
		plInfo.armor = pl:Armor()
		plInfo.score = pl:Frags()
		plInfo.deaths = pl:Deaths()
		plInfo.model = pl.modelName
		
		if plWeapons && #plWeapons > 0 then
			plInfo.loadout = {}
			
			for _, wep in pairs(plWeapons) do
				plInfo.loadout[wep:GetClass()] = {pl:GetAmmoCount(wep:GetPrimaryAmmoType()), pl:GetAmmoCount(wep:GetSecondaryAmmoType())}
			end
		end
		
		file.Write("tf2_userid_info/tf2_userid_info_"..pl:UniqueID()..".txt", util.TableToKeyValues(plInfo))
	end
	
	-- Crash Recovery --
	if game.IsDedicated(true) then
		local savedMap = {}
		
		savedMap.predicted_crash = NEXT_MAP
		
		file.Write("tf2_data/tf2_crash_recovery.txt", util.TableToKeyValues(savedMap))
	end
	-- End --
	
	-- Switch maps
	game.ConsoleCommand("changelevel "..NEXT_MAP.."\n")
end 

if file.Exists("tf2/maps/"..game.GetMap()..".lua", "LUA") then
	include("tf2/maps/"..game.GetMap()..".lua")
elseif file.Exists("maps/"..game.GetMap()..".lua", "LUA") then
	include("maps/"..game.GetMap()..".lua")
end

RunConsoleCommand("sk_player_head", "1")
RunConsoleCommand("sv_friction", "4")
RunConsoleCommand("sv_stopspeed", "100")
RunConsoleCommand("sv_accelerate", "10")
RunConsoleCommand("sv_airaccelerate", "10")
--Disables use key on objects (Can Be Re-enabled)
-- WHAT WERE YOU THINKING
RunConsoleCommand("sv_playerpickupallowed", "1")
-- Mirror TF2 movement/physics defaults from Source.
RunConsoleCommand("sv_gravity", "800")
RunConsoleCommand("phys_impactforcescale", "1.0")
RunConsoleCommand("phys_pushscale", "1.0")

function GM:PlayerNoClip( pl )
	if GetConVar("sbox_noclip"):GetInt() <= 0 then 
		return
	end

	if pl:Team() == TEAM_SPECTATOR then
		return false
	else
		return true
	end
end

function GM:EntityRemoved(ent, ply)
	if ent:GetClass() == "item_battery" then
		ent:Remove("item_battery")
	end
end

function GM:PlayerRequestTeam( ply, teamid )
	-- This team isn't joinable
	if ( !team.Joinable( teamid ) or teamid == 0 or teamid == 3 ) then
		ply:ChatPrint( "You can't join that team" )
	return end

	-- This team isn't joinable
	if ( !GAMEMODE:PlayerCanJoinTeam( ply, teamid ) ) then
		-- Messages here should be outputted by this function
	return end

	GAMEMODE:PlayerJoinTeam( ply, teamid )
end

function GM:PlayerCanJoinTeam( ply, teamid )
	----print("Requested "..teamid.." for "..ply:GetName().."!".." (aka team "..team.GetName(teamid).."!)")
	local TimeBetweenSwitches = GAMEMODE.SecondsBetweenTeamSwitches or 5
	if ( ply.LastTeamSwitch && RealTime()-ply.LastTeamSwitch < TimeBetweenSwitches ) then
		ply.LastTeamSwitch = ply.LastTeamSwitch + 1
		ply:ChatPrint( Format( "Please wait %i more seconds before trying to change team again!", ( TimeBetweenSwitches - ( RealTime() - ply.LastTeamSwitch ) ) + 1 ) )
		return false
	end

	-- Already on this team!
	if ( ply:Team() == teamid ) then
		ply:ChatPrint( "You're already on that team" )
		return false
	end

	return true
end

-- Networking
util.AddNetworkString("UpdateLoadout")
util.AddNetworkString("TF_PlayerSpawn")
util.AddNetworkString("TF_OpenInitialJoinFlow")
util.AddNetworkString("TF_HalloweenGargoyleNotify")
util.AddNetworkString("TF_HalloweenSoulBurst")

function GM:PlayerDroppedWeapon(ply)
	if IsValid(ply) and ply:IsPlayer() and !ply:IsHL2() then
		net.Start("UpdateLoadout")
		net.Send(ply)
	end
end

hook.Add("DoPlayerDeath", "TF2_DeathCam_Initialize", function(ply, attacker, dmginfo)
    ply:SetNWFloat("DeathTime",CurTime())
    ply:SetNWFloat("ChaseDistance",40)
end)

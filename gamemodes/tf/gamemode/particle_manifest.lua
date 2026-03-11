util.PrecacheSound( "vox/deeoo.wav" )
if SERVER then
    EmitSound("replay/downloadcomplete.wav",Vector(0,0,0),0,CHAN_REPLACE,1,0,0,100,0,nil)
    PrintMessage(HUD_PRINTTALK, "SERVER IS RELOADING THE GAMEMODE DUE TO AN EDIT IN THE GAMEMODE'S CODE - GRAPHICAL OR GAME-BREAKING GLITCHES MAY OCCUR")
    PrintMessage(HUD_PRINTCENTER, "SERVER IS RELOADING THE GAMEMODE DUE TO AN EDIT IN THE GAMEMODE'S CODE - GRAPHICAL OR GAME-BREAKING GLITCHES MAY OCCUR")
end
--print("Including TF2 Particles")
AddCSLuaFile() 

if SERVER and not ConVarExists("tf_particles_vsh_enable") then
	-- -1: auto by map name, 0: always disabled, 1: always enabled
	CreateConVar("tf_particles_vsh_enable", "-1", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED), "VSH particle loading override (-1 auto, 0 off, 1 on).")
elseif CLIENT and not ConVarExists("tf_particles_vsh_enable") then
	-- Client fallback for singleplayer/listen edge cases.
	CreateClientConVar("tf_particles_vsh_enable", "-1", true, false)
end

local function ShouldLoadVshParticles()
	local cv = GetConVar("tf_particles_vsh_enable")
	local mode = cv and math.floor(cv:GetFloat()) or -1

	if mode == 0 then return false end
	if mode == 1 then return true end

	local mapName = string.lower(game.GetMap() or "")
	return string.StartWith(mapName, "vsh_")
		or string.StartWith(mapName, "arena_vsh_")
		or string.find(mapName, "_vsh_", 1, true) ~= nil
		or string.find(mapName, "saxton", 1, true) ~= nil
end

local function IsVshParticleFileName(lowerName)
	if lowerName == "particles_vsh.pcf" then return true end
	return string.find(lowerName, "vsh", 1, true) ~= nil
		or string.find(lowerName, "saxton", 1, true) ~= nil
		or string.find(lowerName, "hale", 1, true) ~= nil
end

local function AddTF2ParticlesFile(path)
	if not isstring(path) or path == "" then return end

	-- Preferred path when files are mounted as normal game content.
	if file.Exists(path, "GAME") then
		game.AddParticles(path)
		return
	end

	-- Fallback path for this addon layout (gamemode content folder).
	local fallback = "gamemodes/tf/content/" .. path
	if file.Exists(fallback, "GAME") then
		game.AddParticles(fallback)
	end
end

local function AddAllAddonParticlePcfs()
	local seen = {}
	local allowVshParticles = ShouldLoadVshParticles()
	MsgN(string.format("[TF Particles] VSH particle mode=%s allow=%s map=%s", tostring(GetConVar("tf_particles_vsh_enable") and GetConVar("tf_particles_vsh_enable"):GetString() or "nil"), tostring(allowVshParticles), tostring(game.GetMap() or "unknown")))
	local searchGlobs = {
		"particles/*.pcf",
		"gamemodes/tf/content/particles/*.pcf",
	}
	for _, glob in ipairs(searchGlobs) do
		local files = file.Find(glob, "GAME") or {}
		for _, name in ipairs(files) do
			local lowerName = string.lower(tostring(name or ""))
			local shouldSkip = (IsVshParticleFileName(lowerName) and not allowVshParticles)
			if not shouldSkip and not seen[name] then
				seen[name] = true
				AddTF2ParticlesFile("particles/" .. name)
			end
		end
	end
end

local baseParticlePcfs = {
	"particles/bigboom.pcf",
	"particles/blood_impact.pcf",
	"particles/blood_trail.pcf",
	"particles/bl_killtaunt.pcf",
	"particles/bombinomicon.pcf",
	"particles/buildingdamage.pcf",
	"particles/bullet_tracers.pcf",
	"particles/burningplayer.pcf",
	"particles/cig_smoke.pcf",
	"particles/cinefx.pcf",
	"particles/class_fx.pcf",
	"particles/coin_spin.pcf",
	"particles/conc_stars.pcf",
	"particles/crit.pcf",
	"particles/dirty_explode.pcf",
	"particles/disguise.pcf",
	"particles/doomsday_fx.pcf",
	"particles/drg_bison.pcf",
	"particles/drg_cowmangler.pcf",
	"particles/drg_engineer.pcf",
	"particles/drg_pyro.pcf",
	"particles/dxhr_fx.pcf",
	"particles/explosion.pcf",
	"particles/eyeboss.pcf",
	"particles/flag_particles.pcf",
	"particles/flamethrower.pcf",
	"particles/flamethrower_mvm.pcf",
	"particles/halloween.pcf",
	"particles/harbor_fx.pcf",
	"particles/highfive.pcf",
	"particles/impact_fx.pcf",
	"particles/items_demo.pcf",
	"particles/items_engineer.pcf",
	"particles/item_fx.pcf",
	"particles/level_fx.pcf",
	"particles/medicgun_attrib.pcf",
	"particles/medicgun_beam.pcf",
	"particles/muzzle_flash.pcf",
	"particles/mvm.pcf",
	"particles/nailtrails.pcf",
	"particles/nemesis.pcf",
	"particles/npc_fx.pcf",
	"particles/player_recent_teleport.pcf",
	"particles/rain_custom.pcf",
	"particles/rocketbackblast.pcf",
	"particles/rocketjumptrail.pcf",
	"particles/rockettrail.pcf",
	"particles/scary_ghost.pcf",
	"particles/shellejection.pcf",
	"particles/smoke_blackbillow.pcf",
	"particles/smoke_blackbillow_hoodoo.pcf",
	"particles/soldierbuff.pcf",
	"particles/sparks.pcf",
	"particles/speechbubbles.pcf",
	"particles/stamp_spin.pcf",
	"particles/stickybomb.pcf",
	"particles/stormfront.pcf",
	"particles/teleported_fx.pcf",
	"particles/teleport_status.pcf",
	"particles/training.pcf",
	"particles/water.pcf",
	"particles/xms.pcf",
	"particles/firstperson_weapon_fx.pcf",
}

for _, pcfPath in ipairs(baseParticlePcfs) do
	AddTF2ParticlesFile(pcfPath)
end

-- Also load every particle PCF currently shipped in this addon folder
-- (including newly imported TF2 VPK particle files).
AddAllAddonParticlePcfs()

-- Keep Valve crit weapon effects authoritative even if optional packs
-- (e.g. particles_vsh.pcf) also define the same system names.
AddTF2ParticlesFile("particles/crit.pcf")
AddTF2ParticlesFile("particles/firstperson_weapon_fx.pcf")
AddTF2ParticlesFile("particles/firstperson_weapon_fx_dx80.pcf")

-- Explicit fallback loads for core TF2 PCFs used by HHH and gameplay FX.
AddTF2ParticlesFile("particles/halloween.pcf")
AddTF2ParticlesFile("particles/eyeboss.pcf")
AddTF2ParticlesFile("particles/explosion.pcf")
AddTF2ParticlesFile("particles/impact_fx.pcf")
AddTF2ParticlesFile("particles/speechbubbles.pcf")

-- Extra systems observed in runtime/debug traces that are used by the gamemode
-- but were not always explicitly precached in this branch.
local extraParticleSystems = {
	"asplode_hoodoo_shockwave",
	"bonk_text",
	"boomer_explode",
	"bot_death",
	"bot_impact_heavy",
	"bot_impact_light",
	"bullet_impact1_blue_crit",
	"bullet_impact1_red_crit",
	"cig_smoke",
	"cinefx_goldrush_flash",
	"doubledonk_text",
	"drg_cow_explosioncore_charged",
	"drg_cow_explosioncore_charged_blue",
	"energydrink_splash",
	"Explosion_ShockWave_01",
	"eyeboss_tp_normal",
	"fireSmoke_Collumn_mvmAcres",
	"fireSmoke_Collumn_mvmAcres_sm",
	"ghost_pumpkin",
	"halloween_boss_axe_hit_world",
	"halloween_boss_death",
	"halloween_boss_eye_glow",
	"halloween_boss_foot_impact",
	"halloween_boss_injured",
	"halloween_boss_summon",
	"merasmus_ambient_body",
	"merasmus_dazed",
	"merasmus_dazed_explosion",
	"merasmus_shoot",
	"merasmus_spawn",
	"merasmus_tp",
	"merasmus_zap",
	"projectile_fireball",
	"soldierbuff_red_buffed",
	"speech_mediccall",
	"speech_revivecall",
	"speech_taunt_all",
	"spell_fireball_small_red",
	"spy_start_disguise_blue",
	"spy_start_disguise_red",
	"tank_rock_throw_impact_chunks",
	"tfc_sniper_mist",
	"water_playeremerge",

	-- Team-colored/dynamic suffix families used in code.
	"critical_rocket_red",
	"critical_rocket_blue",
	"healthgained_red",
	"healthgained_blue",
	"healthlost_red",
	"healthlost_blue",
	"teleported_blue",
	"teleported_red",
	"teleported_flash",
	"teleportedin_blue",
	"teleportedin_red",
}

for _, systemName in ipairs(extraParticleSystems) do
	pcall(PrecacheParticleSystem, systemName)
end

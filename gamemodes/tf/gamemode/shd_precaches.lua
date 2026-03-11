
local function PrecacheTFContent()
	--MsgN("Precaching TF2 models")
	for _,v in pairs(HumanGibs) do
		util.PrecacheModel0(v)
	end
	
	for _,v in pairs(RobotGibs) do
		util.PrecacheModel0(v)
	end
	
	for _,v in pairs(RobotBossGibs) do
		util.PrecacheModel0(v)
	end

	for _,v in pairs(PlayerModels) do
		util.PrecacheModel0(v)
	end

	for _,v in pairs(AnimationModels) do
		util.PrecacheModel0(v)
	end
end

if SERVER and game.SinglePlayer() then
	hook.Add("PostGamemodeLoaded", "PrecacheTFContent", function()
		PrecacheTFContent()
	end)
else
	PrecacheTFContent()
end

PrecacheParticleSystem("crit_text")
PrecacheParticleSystem("minicrit_text")
PrecacheParticleSystem("healthgained_red")
PrecacheParticleSystem("healthgained_blu")
PrecacheParticleSystem("healthgained_red_large")
PrecacheParticleSystem("healthgained_blu_large")
PrecacheParticleSystem("healthgained_red_giant")
PrecacheParticleSystem("healthgained_blu_giant")
PrecacheParticleSystem("healthlost_red")
PrecacheParticleSystem("healthlost_blu")

PrecacheParticleSystem("blood_decap")
PrecacheParticleSystem("blood_decap_arterial_spray")
PrecacheParticleSystem("blood_decap_fountain")
PrecacheParticleSystem("blood_decap_streaks")

PrecacheParticleSystem("rocketjump_smoke")
PrecacheParticleSystem("burningplayer_flyingbits")
PrecacheParticleSystem("particle_nemesis_red")
PrecacheParticleSystem("particle_nemesis_blue")

PrecacheParticleSystem("muzzle_raygun_red")
PrecacheParticleSystem("bullet_tracer_raygun_red")
PrecacheParticleSystem( "bot_impact_heavy" )
PrecacheParticleSystem( "bot_impact_light" )
PrecacheParticleSystem( "bot_death" )
PrecacheParticleSystem( "water_playerdive" )
PrecacheParticleSystem( "water_playeremerge" )
PrecacheParticleSystem( "critgun_weaponmodel_blu" )
PrecacheParticleSystem( "critgun_weaponmodel_red" )
PrecacheParticleSystem( "critgun_weaponmodel_blu_glow" )
PrecacheParticleSystem( "critgun_weaponmodel_red_glow" )

-- Additional stock TF2 particle systems frequently used on VSH maps/events.
local vshStockParticles = {
	"player_recent_teleport_blue",
	"player_recent_teleport_red",
	"teleported_blue",
	"teleported_red",
	"teleportedin_blue",
	"teleportedin_red",
	"crit_text",
	"minicrit_text",
	"doubledonk_text",
	"bonk_text",
	"spell_cast_wheel_blue",
	"spell_cast_wheel_red",
	"merasmus_tp",
	"merasmus_spawn",
	"halloween_boss_summon",
	"halloween_boss_axe_hit_world",
	"halloween_boss_injured",
	"halloween_boss_death",
}

for _, particleName in ipairs(vshStockParticles) do
	pcall(PrecacheParticleSystem, particleName)
end

-- Halloween Skeleton King + skeleton minion models.
if util and util.PrecacheModel0 then
	pcall(util.PrecacheModel0, "models/bots/skeleton_sniper/skeleton_sniper.mdl")
	pcall(util.PrecacheModel0, "models/bots/skeleton_sniper_boss/skeleton_sniper_boss.mdl")
end

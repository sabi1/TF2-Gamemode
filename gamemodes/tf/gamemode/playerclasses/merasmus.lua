CLASS.Name = "Merasmus"
CLASS.Speed = 520
CLASS.Health = 1000

if CLIENT then
	CLASS.CharacterImage = {
		surface.GetTextureID("hud/class_demored"),
		surface.GetTextureID("hud/class_demoblue")
	}
	CLASS.ScoreboardImage = {
		surface.GetTextureID("hud/leaderboard_class_demoknight"),
		surface.GetTextureID("hud/leaderboard_class_demoknight")
	}
end

CLASS.Loadout = {}
CLASS.DefaultLoadout = {}
CLASS.ModelName = "merasmus"

CLASS.Gibs = {
	[GIB_LEFTLEG]		= GIBS_SNIPER_START,
	[GIB_RIGHTLEG]		= GIBS_SNIPER_START+1,
	[GIB_LEFTARM]		= GIBS_SNIPER_START+2,
	[GIB_RIGHTARM]		= GIBS_SNIPER_START+3,
	[GIB_TORSO]			= GIBS_SNIPER_START+4,
	[GIB_HEAD]			= GIBS_SNIPER_START+5,
	[GIB_ORGAN]			= GIBS_ORGANS_START,
}

CLASS.Sounds = {
	paincrticialdeath = {
		Sound("Halloween.MerasmusBanish"),
	},
	painsevere = {
		Sound("Halloween.MerasmusBanish"),
	},
	painsharp = {
		Sound("Halloween.MerasmusBanish"),
	},
}

CLASS.AmmoMax = {
	[TF_PRIMARY]	= 0,		-- primary
	[TF_SECONDARY]	= 0,		-- secondary
	[TF_METAL]		= 100,		-- metal
	[TF_GRENADES1]	= 0,		-- grenades1
	[TF_GRENADES2]	= 0,		-- grenades2
}

if SERVER then

	function CLASS:Initialize()
		self:SetModel("models/bots/merasmus/merasmus.mdl")
		self:SetSkin(1)
		self:EmitSound("vo/halloween_boss/knight_spawn.mp3",0,100)
		self:EmitSound("Halloween.MerasmusAppears",0,100)
		ParticleEffectAttach("halloween_boss_summon", PATTACH_ABSORIGIN_FOLLOW, self, 0)
		ParticleEffectAttach("ghost_pumpkin", PATTACH_ABSORIGIN_FOLLOW, self, 0)
	end

end

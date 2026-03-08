CLASS.Name = "Horseless Headless Horsemann"
CLASS.Speed = 520
CLASS.Health = 920

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
CLASS.ModelName = "headless_hatman"

CLASS.Gibs = {
	[GIB_LEFTLEG]		= GIBS_DEMOMAN_START,
	[GIB_RIGHTLEG]		= GIBS_DEMOMAN_START+1,
	[GIB_LEFTARM]		= GIBS_DEMOMAN_START+2,
	[GIB_RIGHTARM]		= GIBS_DEMOMAN_START+3,
	[GIB_TORSO]			= GIBS_DEMOMAN_START+4,
	[GIB_HEAD]			= GIBS_DEMOMAN_START+5,
	[GIB_ORGAN]			= GIBS_ORGANS_START,
}

CLASS.Sounds = {
	paincrticialdeath = {
		Sound("Halloween.HeadlessBossPain"),
	},
	painsevere = {
		Sound("Halloween.HeadlessBossPain"),
	},
	painsharp = {
		Sound("Halloween.HeadlessBossPain"),
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
		self:SetModel("models/bots/headless_hatman.mdl")
		self:EmitSound("vo/halloween_boss/knight_spawn.mp3",0,100)
		ParticleEffectAttach("halloween_boss_summon", PATTACH_ABSORIGIN_FOLLOW, self, 0)
		ParticleEffectAttach("ghost_pumpkin", PATTACH_ABSORIGIN_FOLLOW, self, 0)
	end

end

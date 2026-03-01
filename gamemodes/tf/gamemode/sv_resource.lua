-- Fonts

resource.AddFile("resource/fonts/tf2.ttf")
resource.AddFile("resource/fonts/tf2build.ttf")
resource.AddFile("resource/fonts/tf2professor.ttf")
resource.AddFile("resource/fonts/tf2secondary.ttf")

-- TF2 panel scheme and .res files (non-MvM)
resource.AddFile("resource/clientscheme.res")

local function AddResourceFilesRecursive(baseDir, pattern)
	local files, dirs = file.Find(baseDir .. "/*", "GAME")
	for _, name in ipairs(files) do
		if string.match(string.lower(name), pattern) then
			resource.AddFile(baseDir .. "/" .. name)
		end
	end
	for _, dir in ipairs(dirs) do
		AddResourceFilesRecursive(baseDir .. "/" .. dir, pattern)
	end
end

-- Distribute every bundled non-MvM TF2 .res file.
AddResourceFilesRecursive("resource/ui", "%.res$")

-- Send needed materials to the client

resource.AddFile("materials/HUD/d_images_hl2.vmt")
resource.AddFile("materials/HUD/d_images_hl2.vtf")
resource.AddFile("materials/HUD/dneg_images_hl2.vmt")
resource.AddFile("materials/HUD/dneg_images_hl2.vtf")

resource.AddFile("materials/HUD/d_images_custom.vmt")
resource.AddFile("materials/HUD/d_images_custom.vtf")
resource.AddFile("materials/HUD/dneg_images_custom.vmt")
resource.AddFile("materials/HUD/dneg_images_custom.vtf")

resource.AddFile("gamemodes/tf/content/materials/sprites/tf_crosshairs.vmt")
resource.AddFile("gamemodes/tf/content/materials/sprites/tf_crosshairs.vtf")

resource.AddFile("materials/Effects/imcookin_2.vmt")

resource.AddFile("materials/vgui/av_default.vmt")
resource.AddFile("materials/vgui/av_default.vtf")

resource.AddFile("materials/models/weapons/w_shotgun_tf/w_shotgun_tf.vmt")
resource.AddFile("materials/models/effects/invulnfx_red2.vmt")
resource.AddFile("materials/effects/tfred.vtf")
resource.AddFile("materials/effects/tfred_dx8.vtf")

-- Language

resource.AddFile("data/tf/resource/tfgm_english.txt")

-- Scripts

resource.AddFile("data/scripts/game_sounds_weapons_tf.txt")

-- Fonts

resource.AddFile("resource/fonts/tf2.ttf")
resource.AddFile("resource/fonts/tf2build.ttf")
resource.AddFile("resource/fonts/tf2professor.ttf")
resource.AddFile("resource/fonts/tf2secondary.ttf")

local function ShouldDistributeResourceFile(name, pattern)
	local lowerName = string.lower(name or "")
	if not string.match(lowerName, pattern) then
		return false
	end

	-- Keep editor backups out of the live client resource set.
	if string.find(lowerName, ".backup.", 1, true) or string.find(lowerName, "_backup", 1, true) then
		return false
	end

	return true
end

local function AddResourceFilesRecursive(baseDir, pattern)
	local files, dirs = file.Find(baseDir .. "/*", "GAME")
	for _, name in ipairs(files) do
		if ShouldDistributeResourceFile(name, pattern) then
			resource.AddFile(baseDir .. "/" .. name)
		end
	end
	for _, dir in ipairs(dirs) do
		AddResourceFilesRecursive(baseDir .. "/" .. dir, pattern)
	end
end

-- Distribute the full bundled TF2 .res tree so top-level, roundinfo, and
-- MvM-specific panels resolve the same way Valve ships them.
AddResourceFilesRecursive("resource", "%.res$")

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

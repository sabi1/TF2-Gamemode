-- Include all clientside or shared gamemode files

local gmFolder = string.Replace(tostring((GM and GM.Folder) or "gamemodes/tf"), "\\", "/")
if not string.StartWith(gmFolder, "gamemodes/") then
	gmFolder = "gamemodes/" .. gmFolder
end
local basepath = gmFolder .. "/gamemode/"
local shortFolder = string.Replace(gmFolder, "gamemodes/", "")

local function add_cs_file(relPath)
	relPath = string.Replace(relPath or "", "\\", "/")
	if relPath == "" then return end

	local sent = {}
	local candidates = {
		relPath,
		basepath .. relPath,
		shortFolder .. "/gamemode/" .. relPath,
	}

	for _, candidate in ipairs(candidates) do
		if not sent[candidate] and file.Exists(candidate, "LUA") then
			AddCSLuaFile(candidate)
			sent[candidate] = true
		end
	end
end

local function find_lua_files(relDir)
	relDir = relDir or ""
	local seen = {}
	local out = {}
	local roots = {
		relDir,
		basepath .. relDir,
		shortFolder .. "/gamemode/" .. relDir,
	}

	for _, root in ipairs(roots) do
		for _, f in pairs(file.Find(root .. "*.lua", "LUA")) do
			if not seen[f] then
				seen[f] = true
				out[#out + 1] = f
			end
		end
	end

	return out
end

add_cs_file("ent_extension.lua")
add_cs_file("ply_extension.lua")
add_cs_file("vmatrix_extension.lua")
add_cs_file("tf_draw_module.lua")
add_cs_file("tf_util_module.lua")
add_cs_file("tf_item_module.lua")
add_cs_file("tf_timer_module.lua")
add_cs_file("tf_lang_module.lua")
add_cs_file("tf_soundscript_module.lua")
add_cs_file("particle_manifest.lua")

-- Critical runtime includes that can be called from callbacks/commands.
add_cs_file("shd_items.lua")
add_cs_file("cl_joinflow.lua")
add_cs_file("vgui/menu_teamselectpanel.lua")
add_cs_file("vgui/menu_motdpanel.lua")

for _,f in pairs(find_lua_files("")) do
	if string.find(f, "^cl_")
	or string.find(f, "^shd_")
	or string.find(f, "^shared") then
		add_cs_file(f)
	end
end

-- Include VGUI files

for _,f in pairs(find_lua_files("vgui/")) do
	add_cs_file("vgui/" .. f)
end

-- Include proxies

for _,f in pairs(find_lua_files("proxies/")) do
	add_cs_file("proxies/" .. f)
end

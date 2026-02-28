-- autorun loader for TF2 condition system
-- makes sure all condition files are included and sent to clients

-- shared files to send/exec
local sharedFiles = {
    "tf2_conditions/sh_tfcond_enum.lua",
    "tf2_conditions/sh_player_shared.lua",
    "tf2_conditions/sh_visuals.lua",
}

-- server-only files
local serverFiles = {
    "tf2_conditions/sv_player_shared.lua",
    "tf2_conditions/sv_commands.lua",
}

-- client-only files
local clientFiles = {
    "tf2_conditions/cl_player_shared.lua",
    "tf2_conditions/cl_commands.lua",
}

-- helper for adding and including
local function addcs(f)
    if SERVER then AddCSLuaFile(f) end
end
local function inc(f)
    if SERVER then
        include(f)
    elseif CLIENT then
        include(f)
    end
end

for _,f in ipairs(sharedFiles) do
    addcs(f)
    inc(f)
end

for _,f in ipairs(serverFiles) do
    if SERVER then
        include(f)
    end
end

for _,f in ipairs(clientFiles) do
    addcs(f)
    if CLIENT then
        include(f)
    end
end

-- include all condition definitions
local condFiles = file.Find("tf2_conditions/conditions/*.lua","LUA")
for _,f in ipairs(condFiles) do
    local path = "tf2_conditions/conditions/"..f
    addcs(path)
    inc(path)
end

if SERVER then
    print("[TF2_Cond] loader executed SERVER, conditions registered")
else
    print("[TF2_Cond] loader executed CLIENT, conditions registered")
end

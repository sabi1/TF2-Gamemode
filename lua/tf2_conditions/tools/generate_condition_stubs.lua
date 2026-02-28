-- tool: generate stub condition files for every ETFCond not yet implemented
-- each stub references the corresponding C++ switch/case in tf_player_shared.cpp

local ENUM = include("../sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond
local fs = file

for name, idx in pairs(ETFCond) do
    if idx >= 0 then
        local fname = "lua/tf2_conditions/conditions/" .. name:lower() .. ".lua"
        if not fs.Exists(fname, "GAME") then
            local f = fs.Open(fname, "w", "GAME")
            if f then
                f:Write("-- " .. name .. " condition\n")
                f:Write("-- map to ETFCond value " .. idx .. "\n")
                f:Write("-- see tf_player_shared.cpp for logic around 'case " .. name .. ":'\n\n")
                f:Write("local ENUM = include(\"tf2_conditions/sh_tfcond_enum.lua\")\n")
                f:Write("local ETFCond = ENUM.ETFCond\n\n")
                f:Write("local cond = {}\n")
                f:Write("cond.Type = ETFCond." .. name .. "\n\n")
                f:Write("function cond.OnAdded(ply, provider)\n")
                f:Write("    -- TODO: replicate C++ OnAdded behaviour\n")
                f:Write("end\n\n")
                f:Write("function cond.OnRemoved(ply)\n")
                f:Write("    -- TODO: replicate C++ OnRemoved behaviour\n")
                f:Write("end\n\n")
                f:Write("function cond.OnThink(ply)\n")
                f:Write("    -- optional periodic logic\n")
                f:Write("end\n\n")
                f:Write("-- additional hooks (ModifyDamage, ModifyMove, etc.) may be defined here\n\n")
                f:Write("return cond\n")
                f:Close()
            end
        end
    end
end

print("Condition stubs generated.")

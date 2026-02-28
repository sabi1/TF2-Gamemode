-- speed boost condition (TF_COND_SPEED_BOOST)
-- applied by sandvich, buff banner, etc. increases run/move speed
-- see tf_player_shared.cpp for attribute modifications and OnAdded/Removed

local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond

local cond = {}
cond.Type = ETFCond.TF_COND_SPEED_BOOST

function cond.OnAdded(ply, provider)
    ply.TF_SpeedBoost = true
    ply:EmitSound("Powerup.Speed")
    if CLIENT then
        -- optional visual cue
    end
end

function cond.OnRemoved(ply)
    ply.TF_SpeedBoost = nil
end

function cond.ModifyMove(ply, mv)
    if ply.TF_SpeedBoost then
        local mul = 1.3 -- example buff
        mv:SetMaxSpeed(mv:GetMaxSpeed() * mul)
        mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mul)
    end
end

return cond

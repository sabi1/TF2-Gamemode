-- spy cloak condition
-- TF_COND_DISGUISED, TF_COND_DISGUISING, TF_COND_STEALTHED
local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond

local cond = {}
cond.Type = ETFCond.TF_COND_STEALTHED

function cond.OnAdded(ply, provider)
    ply:SetNoDraw(true)
    ply:SetRenderMode(RENDERMODE_TRANSALPHA)
    ply:SetColor(Color(255,255,255,50))
    -- play cloak sound
    ply:EmitSound("Player.CloakStart")
end

function cond.OnRemoved(ply)
    ply:SetNoDraw(false)
    ply:SetColor(Color(255,255,255,255))
    ply:EmitSound("Player.CloakEnd")
end

function cond.OnThink(ply)
    -- cloak drain or move speed apply
    if SERVER and ply:InCond(ETFCond.TF_COND_STEALTHED) then
        -- if attacked or velocity > threshold, remove
    end
end

return cond

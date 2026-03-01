-- generic stun condition (TF_COND_STUNNED)
-- multiple stun flavors use flags stored in provider or duration
local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond

local cond = {}
cond.Type = ETFCond.TF_COND_STUNNED

function cond.OnAdded(ply, provider)
    ply:TFClearMovementInputs()
    ply:EmitSound("Player.StunStart")
end

function cond.OnRemoved(ply)
    ply:EmitSound("Player.StunEnd")
end

function cond.ModifyMove(ply, mv)
    if ply:InCond(cond.Type) then
        mv:SetMaxSpeed(0)
        mv:SetVelocity(vector_origin)
    end
end

return cond

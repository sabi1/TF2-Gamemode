-- vaccinator shields grant temporary resistance to damage types depending on shield type.
-- TF_COND_MEDIGUN_*_RESIST and TF_COND_MEDIGUN_SMALL_*_RESIST

local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond

local cond = {}
cond.Type = ETFCond.TF_COND_MEDIGUN_UBER_BULLET_RESIST -- example

function cond.OnAdded(ply, provider)
    ply.VaccinatorType = cond.Type
    ply:EmitSound("Medic.VaccinatorStart")
    if SERVER then
        ply:SetNW2Int("tf_vacc_type", cond.Type)
    end
end

function cond.OnRemoved(ply)
    ply.VaccinatorType = nil
    ply:EmitSound("Medic.VaccinatorEnd")
    if SERVER then
        ply:SetNW2Int("tf_vacc_type", 0)
    end
end

function cond.ModifyDamage(ply, dmg)
    if ply:InCond(cond.Type) then
        -- reduce appropriate damage type
        local d = dmg:GetDamageType()
        if cond.Type == ETFCond.TF_COND_MEDIGUN_UBER_BULLET_RESIST and bit.band(d, DMG_BULLET) ~= 0 then
            dmg:ScaleDamage(0.2)
        end
    end
end

return cond

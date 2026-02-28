-- jarate spray condition (TF_COND_JARATED)
local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond

local cond = {}
cond.Type = ETFCond.TF_COND_JARATED

function cond.OnAdded(ply, provider)
    -- lower fire damage, apply visible drips
    ply.TF_JarateNext = CurTime()
    ply.TF_JarateProvider = provider
    ply.TF_Jarated = true
    -- cancel any persistent burn effects (TF2 removes fire when jarated)
    if SERVER and ply:InCond(ETFCond.TF_COND_BURNING) then
        ply:RemoveCond(ETFCond.TF_COND_BURNING)
    end
    if CLIENT then
        ply:AttachParticleEffect("jarate_drips")
        -- head mark effect (skull)
        ply.TF_JarateHead = ply:AttachParticleEffect("jarate_skull", PATTACH_POINT_FOLLOW, "head")
    end
    ply:EmitSound("Jarate.Hit")
end

function cond.OnRemoved(ply)
    ply:EmitSound("Jarate.End")
    ply.TF_Jarated = nil
    ply.TF_JarateProvider = nil
    if CLIENT and IsValid(ply.TF_JarateHead) then
        ply.TF_JarateHead:StopEmission()
        ply.TF_JarateHead = nil
    end
end

function cond.OnThink(ply)
    -- maybe apply healing debuff or mark head
end

function cond.ModifyDamage(ply, dmg)
    -- damage from weapons is mini-crit
    if ply:InCond(cond.Type) then
        dmg:ScaleDamage(1.35)
        -- jarated targets also take extra burn damage? handled by skin removal above
    end
end

return cond

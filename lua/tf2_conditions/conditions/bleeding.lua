-- bleeding condition (TF_COND_BLEEDING) replicates SDK logic
-- after a hit with certain weapons, player takes periodic damage and bleeding particles
-- see tf_player_shared.cpp case TF_COND_BLEEDING and CTFCondition_Bleeding.

local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond

local cond = {}
cond.Type = ETFCond.TF_COND_BLEEDING

local BLEED_INTERVAL = 0.8
local BLEED_DAMAGE = 5 -- placeholder; actual dmg scaled by attributes

function cond.OnAdded(ply, provider)
    ply.tf_bleed_next = CurTime() + BLEED_INTERVAL
    if CLIENT then
        ply.TF_BleedEffect = ply:AttachParticleEffect("bleed")
        -- overlay
        ply.TF_BleedOverlay = TF_SCREEN_OVERLAY_MATERIAL_BLEED
    end
    ply:EmitSound("Player.Bleed")
end

function cond.OnRemoved(ply)
    if CLIENT then
        if IsValid(ply.TF_BleedEffect) then
            ply.TF_BleedEffect:StopEmission()
            ply.TF_BleedEffect = nil
        end
        ply.TF_BleedOverlay = nil
    end
    ply:StopSound("Player.Bleed")
end

function cond.OnThink(ply)
    if CurTime() >= (ply.tf_bleed_next or 0) then
        ply.tf_bleed_next = CurTime() + BLEED_INTERVAL
        local dmg = DamageInfo()
        dmg:SetAttacker(ply:GetCondProvider(cond.Type) or ply)
        dmg:SetInflictor(ply)
        dmg:SetDamage(BLEED_DAMAGE)
        dmg:SetDamageType(DMG_SLASH)
        ply:TakeDamageInfo(dmg)
    end
end

return cond

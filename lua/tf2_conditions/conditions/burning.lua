-- burning condition replicates TF_COND_BURNING behaviour
-- see tf_player_shared.cpp: CTFPlayerShared::OnConditionAdded, CTFCondition_Burning etc.

local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond

local cond = {}

cond.Type = ETFCond.TF_COND_BURNING

-- afterburn ticks every TF_BURNING_FLAME_INTERVAL (0.5 s normally)
local BURN_INTERVAL = 0.5
local DAMAGE_PER_TICK = 0 -- computed per player on add

function cond.OnAdded(ply, provider)
    -- store next tick time
    ply.tf_burn_next = CurTime() + BURN_INTERVAL
    -- play start sound (matches TF2 General.BurningFlesh)
    ply:EmitSound("General.BurningFlesh", 75, 100, 1, CHAN_BODY)
    -- attach particle effect exactly as c_fire_smoke.cpp
    if CLIENT then
        ply.TF_BurningEffect = ply:AttachParticleEffect("burning_character")
        -- screen overlay (fade-in/out logic mimics TF2)
        ply.TF_BurnOverlay = TF_SCREEN_OVERLAY_MATERIAL_BURNING
        ply.TF_BurnOverlayAlpha = 0
    end
    -- compute damage per tick based on health and attribute buffs
    DAMAGE_PER_TICK = ply:GetMaxHealth() * 0.03 -- matches TF2 afterburn 3% max health
    -- record provider in networked var already handled by shared Add
end

function cond.OnRemoved(ply)
    ply:StopSound("General.BurningFlesh")
    if CLIENT and IsValid(ply.TF_BurningEffect) then
        ply.TF_BurningEffect:StopEmission()
        ply.TF_BurningEffect = nil
    end
    if CLIENT then
        ply.TF_BurnOverlay = nil
    end
end

function cond.OnThink(ply)
    if CurTime() >= (ply.tf_burn_next or 0) then
        ply.tf_burn_next = CurTime() + BURN_INTERVAL
        local dmg = DamageInfo()
        dmg:SetAttacker(ply:GetCondProvider(ETFCond.TF_COND_BURNING) or ply)
        dmg:SetInflictor(ply)
        dmg:SetDamage(DAMAGE_PER_TICK)
        dmg:SetDamageType(DMG_BURN)
        ply:TakeDamageInfo(dmg)
        -- apply extinguish in water
        if ply:WaterLevel() >= 3 then
            ply:RemoveCond(ETFCond.TF_COND_BURNING)
        end
    end
end

-- other hooks (client side overlay, sound loop etc) would be implemented here

return cond

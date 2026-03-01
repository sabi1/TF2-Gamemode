-- ubercharged/ invulnerable condition similar to TF_COND_INVULNERABLE and related.
-- shared between TF_COND_UBERCHARGED, TF_COND_INVULNERABLE, etc.

local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond

local cond = {}
cond.Type = ETFCond.TF_COND_INVULNERABLE -- placeholder, files may be symlinked

function cond.OnAdded(ply, provider)
    -- start uber sound, animation override, modifier float
    ply.TF_UberEnd = CurTime() + (ply.tf_cond_list._conds[ETFCond.TF_COND_INVULNERABLE].duration or 0)
    -- ubercharged/ invulnerable condition similar to TF_COND_INVULNERABLE and related.
    -- shared between TF_COND_UBERCHARGED, TF_COND_INVULNERABLE, etc.

    local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
    local ETFCond = ENUM.ETFCond

    local cond = {}
    cond.Type = ETFCond.TF_COND_INVULNERABLE -- placeholder, files may be symlinked

    local function ApplySkinToEntity(ent, skin)
        if not IsValid(ent) then return end
        if ent.SetSkin then
            ent:SetSkin(skin)
        end
    end

    function cond.OnAdded(ply, provider)
        print("[TF2_Cond][Uber] OnAdded called for", ply)
        ply.TF_UberEnd = CurTime() + (ply.tf_cond_list._conds[ETFCond.TF_COND_INVULNERABLE].duration or 0)
        ply:EmitSound("Medic.UberchargeReady")

        if CLIENT then
            GAMEMODE:StartUberOverlay(ply)
        end

        local team = ply:Team()
        local uberSkin = (team == TEAM_RED) and 2 or 3

        -- set player skin (server->clients will see worldmodel skin)
        ApplySkinToEntity(ply, uberSkin)

        -- weapons/wearables
        for _, wep in ipairs(ply:GetWeapons() or {}) do
            ApplySkinToEntity(wep, uberSkin)
        end
        if ply.GetChildren then
            for _, child in ipairs(ply:GetChildren() or {}) do
                ApplySkinToEntity(child, uberSkin)
            end
        end

        -- viewmodel skin for local player (may not be valid immediately)
        if CLIENT and ply == LocalPlayer() then
            timer.Simple(0, function()
                local vm = ply:GetViewModel()
                if IsValid(vm) then
                    ApplySkinToEntity(vm, uberSkin)
                    print("[TF2_Cond][Uber] viewmodel skin applied")
                else
                    print("[TF2_Cond][Uber] viewmodel not valid yet")
                end
            end)
        end
    end

    function cond.OnRemoved(ply)
        print("[TF2_Cond][Uber] OnRemoved called for", ply)
        if CLIENT then
            GAMEMODE:StopUberOverlay(ply)
        end

        local team = ply:Team()
        local normalSkin = (team == TEAM_RED) and 0 or 1

        ApplySkinToEntity(ply, normalSkin)
        for _, wep in ipairs(ply:GetWeapons() or {}) do
            ApplySkinToEntity(wep, normalSkin)
        end
        if ply.GetChildren then
            for _, child in ipairs(ply:GetChildren() or {}) do
                ApplySkinToEntity(child, normalSkin)
            end
        end

        if CLIENT and ply == LocalPlayer() then
            timer.Simple(0, function()
                local vm = ply:GetViewModel()
                if IsValid(vm) then
                    ApplySkinToEntity(vm, normalSkin)
                end
            end)
        end

        ply:EmitSound("Medic.UberchargeOff")
    end

    function cond.OnThink(ply)
        -- keep client skin updated for hide-unless-damaged behaviour and team changes
        if CLIENT then
            local isinv = ply:InCond(cond.Type)
            local hide = ply:InCond(ETFCond.TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED)
            local shouldSkin = isinv
            if hide and not isinv then
                shouldSkin = ply.TF_LastDamageTime and (CurTime() < ply.TF_LastDamageTime + 2)
            end
            local team = ply:Team()
            local skin = shouldSkin and ((team == TEAM_RED) and 2 or 3) or ((team == TEAM_RED) and 0 or 1)
            ApplySkinToEntity(ply, skin)
            for _, wep in ipairs(ply:GetWeapons() or {}) do ApplySkinToEntity(wep, skin) end
            if ply.GetChildren then for _, child in ipairs(ply:GetChildren() or {}) do ApplySkinToEntity(child, skin) end end
            if ply == LocalPlayer() then
                local vm = ply:GetViewModel()
                if IsValid(vm) then ApplySkinToEntity(vm, skin) end
            end
        end
    end

    function cond.ModifyDamage(ply, dmg)
        if ply:InCond(ETFCond.TF_COND_INVULNERABLE) then
            dmg:SetDamage(0)
        end
    end

    return cond

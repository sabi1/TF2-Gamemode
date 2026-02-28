-- rune conditions (TF_COND_RUNE_*)
-- behavior is very similar – apply attribute modifiers via hooks
-- this file will contain helpers and individual rune definitions.

local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond

local Runes = {}

-- example strength rune
Runes[ETFCond.TF_COND_RUNE_STRENGTH] = {
    OnAdded = function(ply)
        ply.TF_RuneStrength = true
        if SERVER then ply:SetNWBool("tf_rune_strength", true) end
    end,
    OnRemoved = function(ply)
        ply.TF_RuneStrength = false
        if SERVER then ply:SetNWBool("tf_rune_strength", false) end
    end,
    ModifyDamage = function(ply, dmg)
        if ply.TF_RuneStrength then
            dmg:ScaleDamage(1.25)
        end
    end,
}

-- TODO: replicate each rune exactly as in SDK, see tf_player_shared.cpp ConditionOnAddedRRunes etc.

return Runes

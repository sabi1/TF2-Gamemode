-- server-side extensions to the shared TF2 condition system
-- handles networking, authoritative logic and game-rules think
-- references: CTFPlayerShared::ConditionGameRulesThink(), CTFConditionList::ServerThink()

if CLIENT then return end

util.AddNetworkString("TF2_Cond_Add")
util.AddNetworkString("TF2_Cond_Remove")

local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond
local ETFCondName = ENUM.ETFCondName

local PLAYER = FindMetaTable("Player")

local function RunModuleConditionAdded(ply, cond, dur, provider)
    local def = tf2_conditions[ETFCondName[cond]]
    if def and def.OnConditionAdded then
        def.OnConditionAdded(ply, dur, provider)
    end
end

local function RunModuleConditionRemoved(ply, cond)
    local def = tf2_conditions[ETFCondName[cond]]
    if def and def.OnConditionRemoved then
        def.OnConditionRemoved(ply)
    end
end

-- module-scoped methods: do not override gamemode AddCond/RemoveCond
function PLAYER:TF2AddCond(cond, dur, provider)
    local added = self:TFCondInit():Add(cond, dur, provider)
    if added then
        -- debug
        print("[TF2_Cond] Server AddCond ->", self, cond, dur, provider)
        -- tell client for prediction/visuals
        net.Start("TF2_Cond_Add")
            net.WriteInt(cond, 16)
            net.WriteFloat(dur or 0)
            net.WriteEntity(provider or NULL)
        net.Send(self)
        RunModuleConditionAdded(self, cond, dur, provider)
    end
    return added
end

function PLAYER:TF2RemoveCond(cond)
    local removed = self:TFCondInit():Remove(cond)
    if removed then
        print("[TF2_Cond] Server RemoveCond ->", self, cond)
        net.Start("TF2_Cond_Remove")
            net.WriteInt(cond, 16)
        net.Send(self)
        RunModuleConditionRemoved(self, cond)
    end
    return removed
end

-- Game rules think is run every frame in TF2 to update certain global condition interactions.
-- We'll mirror it via a Hook.
hook.Add("Think", "TF2_ConditionGameRulesThink", function()
    -- place game-specific global condition evaluation here, e.g. weather, round reset, resupply
    for _, ply in ipairs(player.GetAll()) do
        if ply:Alive() then
            -- example: remove disguise if burning
            if ply.TF2InCond and ply:TF2InCond(ETFCond.TF_COND_BURNING) and ply:TF2InCond(ETFCond.TF_COND_DISGUISED) then
                ply:TF2RemoveCond(ETFCond.TF_COND_DISGUISED)
            end
        end
    end
end)

-- server-side derivative of ConditionList think if needed
-- not used now but placeholder

return true

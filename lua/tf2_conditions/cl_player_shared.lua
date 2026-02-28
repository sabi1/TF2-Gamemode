-- client-side logic for TF2 condition system
-- prediction-safe visuals, sound, overlay handling
-- references: CTFConditionList::OnDataChanged, CTFPlayerShared client prediction

if SERVER then return end

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

-- mirror server networking
net.Receive("TF2_Cond_Add", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local cond = net.ReadInt(16)
    local dur = net.ReadFloat()
    local prov = net.ReadEntity()
    print("[TF2_Cond] Client received Add ->", cond, dur, prov)
    -- call the shared system to add condition locally
    ply:TFCondInit():Add(cond, dur, prov)
    RunModuleConditionAdded(ply, cond, dur, prov)
end)

net.Receive("TF2_Cond_Remove", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local cond = net.ReadInt(16)
    print("[TF2_Cond] Client received Remove ->", cond)
    ply:TFCondInit():Remove(cond)
    RunModuleConditionRemoved(ply, cond)
end)

-- override GetCondProvider to read NW var cached on server
function PLAYER:GetCondProvider(cond)
    if SERVER then return self:TFCondInit():GetProvider(cond) end
    local ent = self:GetNW2Entity("tf_cond_prov_"..cond, NULL)
    return IsValid(ent) and ent or nil
end

-- optional client-side think hook for condition-specific effects like overlay
hook.Add("Think", "TF2_ConditionClientThink", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply.tf_cond_list then
        for cond,entry in pairs(ply.tf_cond_list._conds or {}) do
            if entry.def.OnThink then
                entry.def.OnThink(ply)
            end
        end
    end
end)

-- draw overlays specified by conditions
hook.Add("HUDPaint","TF2_ConditionOverlays",function()
    local ply=LocalPlayer()
    if not IsValid(ply) then return end
    if ply.TF_BurnOverlay then
        surface.SetDrawColor(255,255,255,150)
        surface.SetMaterial(Material(ply.TF_BurnOverlay))
        surface.DrawTexturedRect(0,0,ScrW(),ScrH())
    end
    -- other overlay flags may be handled here
end)


return true

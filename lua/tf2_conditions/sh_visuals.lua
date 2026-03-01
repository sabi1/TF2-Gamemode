-- Shared visuals and skin handling for TF2-like behavior
-- Mirrors CTFPlayer::UpdatePlayerSkin(), UpdateWearables(), UpdateViewModelSkin(), UpdateModel(), UpdateBodygroups() logic

local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond

local PLAYER = FindMetaTable("Player")
if not PLAYER then return end

-- utility: base team skin mapping from TF2
local function TeamBaseSkin(ply)
    if not IsValid(ply) then return 0 end
    local team = ply:Team()
    if team == TEAM_RED then return 2 end
    if team == TEAM_BLUE or team == TEAM_BLU then return 3 end
    return 0
end

-- networked keys
local NW_SKIN_KEY = "tf_skin_index"
local NW_CURSED_ENT = "tf_cursed_cosmetic_ent"
local NW_CURSED_ACTIVE = "tf_cursed_cosmetic_active"

-- Resolve visual priority similar to TF2 layering
local function ResolveVisualPriority(ply)
    -- priority: Cloak (invis override) > Cursed Cosmetic (bodygroup/material overrides) > Condition overlays (uber emissive/burning)
    -- return table describing final visual state: skin, bodygroups, materialOverrides, particles
    local state = {}
    state.baseSkin = TeamBaseSkin(ply)
    state.skin = state.baseSkin
    state.bodygroups = {}
    state.materials = {}
    state.particles = {}

    -- cursed cosmetic entity if any
    local cursed = ply:GetNW2Entity(NW_CURSED_ENT, NULL)
    if IsValid(cursed) and ply:GetNW2Bool(NW_CURSED_ACTIVE, false) then
        -- expect cursed to expose fields via GetNWString/GetNWInt or classname/subtype
        -- best-effort: support common patterns: wearable with NW strings
        local ctype = cursed:GetNWString("cursed_type", "")
        local skinOverride = cursed:GetNWInt("cursed_skin", -1)
        if skinOverride >= 0 then
            -- some cursed cosmetics map to special skins (zombie: 6/7)
            if skinOverride == 6 or skinOverride == 7 then
                state.skin = (ply:Team() == TEAM_RED) and 6 or 7
            else
                state.skin = skinOverride
            end
        end
        -- bodygroups stored as CSV "bg0:1,bg2:3" in NW string
        local bgcsv = cursed:GetNWString("cursed_bodygroups", "")
        if bgcsv and bgcsv ~= "" then
            for token in string.gmatch(bgcsv, "([^,]+)") do
                local k,v = string.match(token, "(%d+):(%d+)")
                if k and v then state.bodygroups[tonumber(k)] = tonumber(v) end
            end
        end
        -- material override name
        local mat = cursed:GetNWString("cursed_material", "")
        if mat and mat ~= "" then state.materials[1] = mat end
        -- particles
        local p = cursed:GetNWString("cursed_particle", "")
        if p and p ~= "" then table.insert(state.particles, {name=p, attach=cursed:GetNWInt("cursed_attach", 0)}) end
    end

    -- special condition overrides (cloak, burn, uber)
    if ply:InCond(ETFCond.TF_COND_CLOAKED) then
        -- Cloak hides player model (clientside alpha/material swap). We do not change skin index but may change material.
        state.cloaked = true
    end
    if ply:InCond(ETFCond.TF_COND_BURNING) then
        table.insert(state.particles, {name="burning_player", attach=ply:LookupAttachment("chest") or 0})
    end
    if ply:InCond(ETFCond.TF_COND_INVULNERABLE) then
        state.uber = true
    end

    return state
end

-- Apply resolved visuals server-side (and network skin index).
function PLAYER:UpdatePlayerSkin()
    if not IsValid(self) then return end
    local state = ResolveVisualPriority(self)
    -- network chosen skin index
    self:SetNW2Int(NW_SKIN_KEY, state.skin or 0)
    -- apply skin server-side for worldmodel
    if self.SetSkin then
        self:SetSkin(state.skin or 0)
    end
    -- apply bodygroups server-side
    for id, val in pairs(state.bodygroups or {}) do
        if self.SetBodygroup then self:SetBodygroup(id, val) end
    end
    -- material overrides are applied clientside; store marker on player as NWString if present
    if state.materials and state.materials[1] then
        self:SetNW2String("tf_material_override", state.materials[1])
    else
        self:SetNW2String("tf_material_override", "")
    end
    -- network cursed active flag
    self:SetNW2Bool(NW_CURSED_ACTIVE, self:GetNW2Entity(NW_CURSED_ENT, NULL) ~= NULL)

    -- update wearables and weapons on server (skins on worldmodels)
    self:UpdateWearables()
end

-- Update weapons/wearables server-side skin/bodygroup states
function PLAYER:UpdateWearables()
    if not IsValid(self) then return end
    -- set skin on world weapons
    for _, wep in ipairs(self:GetWeapons() or {}) do
        if IsValid(wep) and wep.SetSkin then
            local skin = self:GetNW2Int(NW_SKIN_KEY, 0)
            wep:SetSkin(skin)
        end
    end
    -- children (wearables) usually appear as child entities
    if self.GetChildren then
        for _, child in ipairs(self:GetChildren() or {}) do
            if IsValid(child) then
                -- attempt to apply bodygroups/materials via NWs on wearer
                local skin = self:GetNW2Int(NW_SKIN_KEY, 0)
                if child.SetSkin then child:SetSkin(skin) end
                local mat = self:GetNW2String("tf_material_override", "")
                if mat and mat ~= "" and child.SetMaterial then child:SetMaterial(mat) end
                -- apply bodygroups if server kept them on player
            end
        end
    end
end

-- Client-side: apply viewmodel skin, wearables materials, bodygroups and particles
if CLIENT then
    local function ApplyClientVisuals(ply)
        if not IsValid(ply) then return end
        local skin = ply:GetNW2Int(NW_SKIN_KEY, 0)
        -- apply player skin to local client model (worldmodel preview is automatic)
        if ply.SetSkin then ply:SetSkin(skin) end
        -- apply viewmodel skin for local player
        if ply == LocalPlayer() then
            local vm = ply:GetViewModel()
            if IsValid(vm) then
                if vm.SetSkin then vm:SetSkin(skin) end
            end
        end
        -- apply material override
        local mat = ply:GetNW2String("tf_material_override", "")
        if mat and mat ~= "" then
            -- apply to player model only clientside when appropriate
            if ply.SetMaterial then ply:SetMaterial(mat) end
        else
            -- restore original material by clearing it
            if ply.SetMaterial then ply:SetMaterial("") end
        end
        -- bodygroups: try to mirror player bodygroups if server set them
        -- server may not have sent explicit bodygroup mapping; we expect wearables to follow server's child entities
        -- particles: request from cursed wearable entity
        local cursed = ply:GetNW2Entity(NW_CURSED_ENT, NULL)
        if IsValid(cursed) then
            local p = cursed:GetNWString("cursed_particle", "")
            if p and p ~= "" then
                local attach = cursed:GetNWInt("cursed_attach", 0)
                ParticleEffectAttach(p, PATTACH_POINT_FOLLOW, ply, attach)
            end
        end
    end

    -- periodic application to cover late joins and viewmodel recreation
    hook.Add("Think", "TF2_Visuals_ClientThink", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        ApplyClientVisuals(ply)
    end)

    -- ensure viewmodel gets skin applied when it is created
    hook.Add("OnEntityCreated", "TF2_Visuals_ViewmodelCreate", function(ent)
        timer.Simple(0, function()
            if not IsValid(ent) then return end
            if ent:GetClass() == "viewmodel" then
                local owner = ent:GetOwner()
                if IsValid(owner) and owner == LocalPlayer() then
                    local skin = owner:GetNW2Int(NW_SKIN_KEY, 0)
                    if ent.SetSkin then ent:SetSkin(skin) end
                end
            end
        end)
    end)
end

-- API helpers: server-side application/removal of cursed cosmetic
function PLAYER:ApplyCursedCosmetic(cosmeticEnt)
    if not SERVER then return end
    if not IsValid(cosmeticEnt) then return end
    self:SetNW2Entity(NW_CURSED_ENT, cosmeticEnt)
    self:SetNW2Bool(NW_CURSED_ACTIVE, true)
    -- copy cosmetic parameters from cosmetic entity into NWs so clients can render
    local p = cosmeticEnt:GetNWString("cursed_particle", "")
    local mat = cosmeticEnt:GetNWString("cursed_material", "")
    local bg = cosmeticEnt:GetNWString("cursed_bodygroups", "")
    local sk = cosmeticEnt:GetNWInt("cursed_skin", -1)
    local attach = cosmeticEnt:GetNWInt("cursed_attach", 0)
    -- duplicate onto wearable owner (already on entity) just in case
    self:UpdatePlayerSkin()
end

function PLAYER:RemoveCursedCosmetic()
    if not SERVER then return end
    self:SetNW2Entity(NW_CURSED_ENT, NULL)
    self:SetNW2Bool(NW_CURSED_ACTIVE, false)
    self:SetNW2String("tf_material_override", "")
    self:UpdatePlayerSkin()
end

-- Convenience: UpdateViewModelSkin (apply on client)
function PLAYER:UpdateViewModelSkin()
    if CLIENT and self == LocalPlayer() then
        local vm = self:GetViewModel()
        if IsValid(vm) then
            local skin = self:GetNW2Int(NW_SKIN_KEY, 0)
            if vm.SetSkin then vm:SetSkin(skin) end
        end
    end
end

-- Hooks: ensure skins/wearables update on spawn/team/class change
hook.Add("PlayerSpawn", "TF2_Visuals_OnSpawn", function(ply)
    if IsValid(ply) then
        ply:UpdatePlayerSkin()
    end
end)

-- fallback: ensure updates when team changes (gamemode may call this hook)
hook.Add("PlayerTeamChanged", "TF2_Visuals_OnTeamChanged", function(ply, old, new)
    if IsValid(ply) then
        ply:UpdatePlayerSkin()
    end
end)

-- Export API
_G.TF2Visuals = _G.TF2Visuals or {}
_G.TF2Visuals.ResolveVisualPriority = ResolveVisualPriority

return true

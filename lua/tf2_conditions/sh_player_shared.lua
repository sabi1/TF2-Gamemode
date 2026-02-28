-- shared portion of the TF2 condition system
-- mirrors CTFPlayerShared / CTFConditionList from Source SDK 2013
-- references: tf_condition.h, tf_player_shared.cpp/h

local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond
local ETFCondName = ENUM.ETFCondName

-- GMod LuaJIT exposes bit ops via `bit`, not `bit32`.
local bitlib = bit or bit32
local bit_bor = bitlib and bitlib.bor or function(a, b) return a + b end
local bit_band = bitlib and bitlib.band or function(a, b)
    local res, bitv = 0, 1
    while a > 0 or b > 0 do
        local abit = a % 2
        local bbit = b % 2
        if abit == 1 and bbit == 1 then res = res + bitv end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bitv = bitv * 2
    end
    return res
end
local bit_bnot = bitlib and bitlib.bnot or function(a) return -1 - a end
local bit_lshift = bitlib and bitlib.lshift or function(a, b) return a * (2 ^ b) end

-- container class that holds a player's conditions, times, providers, etc.
local ConditionList = {}
ConditionList.__index = ConditionList

function ConditionList.New(outer)
    local self = setmetatable({}, ConditionList)
    self.outer = outer -- the player
    -- storage: map cond -> {duration=number, provider=entity}
    self._conds = {}
    -- bitfield stored in NW2Ints (32 bits each)
    self._bits = {0,0,0,0,0} -- covers up to TF_COND_LAST (~131 bits)
    return self
end

local function SetBit(bits, idx, val)
    local word = math.floor(idx / 32) + 1
    local bitidx = idx % 32
    if val then
        bits[word] = bit_bor(bits[word], bit_lshift(1, bitidx))
    else
        bits[word] = bit_band(bits[word], bit_bnot(bit_lshift(1, bitidx)))
    end
end

local function GetBit(bits, idx)
    local word = math.floor(idx / 32) + 1
    local bitidx = idx % 32
    return bit_band(bits[word], bit_lshift(1, bitidx)) ~= 0
end

-- network helpers (server only)
if SERVER then
    local function UpdateNetBits(ply, bits)
        -- send each 32-bit chunk as a separate NW var
        for i=1, #bits do
            ply:SetNW2Int("tf_cond_bits_"..i, bits[i])
        end
    end
    
    function ConditionList:SetConditionFlag(cond, enabled)
        SetBit(self._bits, cond, enabled)
        UpdateNetBits(self.outer, self._bits)
    end
else
    -- client-side local bit cache update used by net-driven Add/Remove
    function ConditionList:SetConditionFlag(cond, enabled)
        SetBit(self._bits, cond, enabled)
    end

    -- client cache read from NW vars
    function ConditionList:RefreshBits()
        for i=1,5 do
            self._bits[i] = self.outer:GetNW2Int("tf_cond_bits_"..i,0)
        end
    end
    
    function ConditionList:InCond(cond)
        self:RefreshBits()
        return GetBit(self._bits, cond)
    end
end

function ConditionList:Add(cond, duration, provider)
    cond = cond or ETFCond.TF_COND_INVALID
    if cond == ETFCond.TF_COND_INVALID then return false end
    local entry = self._conds[cond]
    if entry then
        -- existing condition; extensible.
        entry.duration = math.max(entry.duration, duration or 0)
        entry.provider = provider or entry.provider
        -- update networked provider as well
        if SERVER then
            self.outer:SetNW2Entity("tf_cond_prov_"..cond, entry.provider or NULL)
        end
        return false
    end
    -- create new condition object; each condition file returns a factory table
    local condDef = tf2_conditions and tf2_conditions[ETFCondName[cond]]
    if not condDef then
        -- fallback: generic placeholder
        condDef = {
            OnAdded = function() end,
            OnRemoved = function() end,
            OnThink = function() end,
        }
    end
    entry = {
        duration = duration or 0,
        provider = provider,
        def = condDef,
        start = CurTime(),
    }
    self._conds[cond] = entry
    self:SetConditionFlag(cond, true)
    if SERVER then
        self.outer:SetNW2Entity("tf_cond_prov_"..cond, provider or NULL)
    end
    entry.def.OnAdded(self.outer, provider)
    return true
end

function ConditionList:Remove(cond)
    local entry = self._conds[cond]
    if not entry then return false end
    entry.def.OnRemoved(self.outer)
    self._conds[cond] = nil
    self:SetConditionFlag(cond,false)
    if SERVER then
        self.outer:SetNW2Entity("tf_cond_prov_"..cond, NULL)
    end
    return true
end

function ConditionList:InCond(cond)
    return self._conds[cond] ~= nil
end

function ConditionList:GetProvider(cond)
    local entry = self._conds[cond]
    return entry and entry.provider
end

function ConditionList:Think()
    local now = CurTime()
    for cond, entry in pairs(self._conds) do
        -- provider validity
        if entry.provider and IsValid(entry.provider) == false then
            -- provider died/disappeared, mirror TF2 behaviour: some conditions drop
            self:Remove(cond)
            continue
        end
        -- expiration check
        if entry.duration > 0 and now - entry.start >= entry.duration then
            self:Remove(cond)
        else
            entry.def.OnThink(self.outer)
        end
    end
end

-- mixin into player metatable
local PLAYER = FindMetaTable("Player")

function PLAYER:TFCondInit()
    if not self.tf_cond_list then
        self.tf_cond_list = ConditionList.New(self)
    end
    return self.tf_cond_list
end

-- support hooks for damage, movement, attributes, visibility, etc.
-- called from global hooks below
local function RunConditionHook(ply, hookName, ...)
    if not ply or not ply.tf_cond_list then return end
    for cond, entry in pairs(ply.tf_cond_list._conds or {}) do
        local fn = entry.def[hookName]
        if fn then
            fn(ply, ...)
        end
    end
end

-- damage modification ------------------------------------------------------
hook.Add("EntityTakeDamage","TF2_Cond_ModifyDamage",function(ent,dmg)
    if ent:IsPlayer() then
        -- record time of being hurt for hide‑unless‑damaged logic
        ent.TF_LastDamageTime = CurTime()
        RunConditionHook(ent, "ModifyDamage", dmg)
    end
end)

-- movement modification ----------------------------------------------------
hook.Add("SetupMove","TF2_Cond_ModifyMove",function(ply,mv,cmd)
    RunConditionHook(ply, "ModifyMove", mv)
end)

hook.Add("Move","TF2_Cond_ModifyMove2",function(ply,mv)
    RunConditionHook(ply, "ModifyMove", mv)
end)

-- attribute modification (called from inside gamemode's attribute system) --
-- placeholder example
-- hook.Add("TF2_ModifyAttributes","TF2_Cond_ModifyAttributes",function(ply)
--     RunConditionHook(ply,"ModifyAttributes")
-- end)

-- visibility flags (player:IsVisibleTo()) modification (?) would be similar


function PLAYER:TF2AddCond(cond, dur, provider)
    return self:TFCondInit():Add(cond, dur, provider)
end

function PLAYER:TF2RemoveCond(cond)
    return self:TFCondInit():Remove(cond)
end

function PLAYER:TF2InCond(cond)
    return self:TFCondInit():InCond(cond)
end

function PLAYER:TF2GetCondProvider(cond)
    return self:TFCondInit():GetProvider(cond)
end

-- If an older module version already aliased global player condition methods,
-- clear those aliases so the gamemode's native Entity:AddCond path is used.
if PLAYER.AddCond == PLAYER.TF2AddCond then
    PLAYER.AddCond = nil
end
if PLAYER.RemoveCond == PLAYER.TF2RemoveCond then
    PLAYER.RemoveCond = nil
end
if PLAYER.InCond == PLAYER.TF2InCond then
    PLAYER.InCond = nil
end
if PLAYER.GetCondProvider == PLAYER.TF2GetCondProvider then
    PLAYER.GetCondProvider = nil
end

-- global think hook to tick player conditions
hook.Add("Think", "TF2_ConditionThink_shared", function()
    for _, ply in ipairs(player.GetAll()) do
        if ply.tf_cond_list then
            ply.tf_cond_list:Think()
        end
    end
end)

-- expose for require
tf2_conditions = tf2_conditions or {}
tf2_conditions.ConditionList = ConditionList

return tf2_conditions

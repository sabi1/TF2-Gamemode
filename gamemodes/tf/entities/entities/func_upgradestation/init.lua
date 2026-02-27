AddCSLuaFile("shared.lua")

ENT.Base = "base_brush"
ENT.Type = "brush"

local function IsUpgradePlayer(ent)
    return IsValid(ent) and ent:IsPlayer() and ent:Team() == TEAM_RED
end

function ENT:Initialize()
    self.Team = 0
    self.Players = {}
    self:SetTrigger(true)
end

function ENT:KeyValue(key, value)
    key = string.lower(tostring(key or ""))
    if key == "teamnum" then
        self.Team = tonumber(value) or 0
    end
end

function ENT:StartTouch(ent)
    if not IsUpgradePlayer(ent) then return end
    self.Players[ent] = true
    ent:SetNWBool("TF_MVM_InUpgradeStation", true)
end

function ENT:Touch(ent)
    if not IsUpgradePlayer(ent) then return end
    if self.Players[ent] then return end
    self.Players[ent] = true
    ent:SetNWBool("TF_MVM_InUpgradeStation", true)
end

function ENT:EndTouch(ent)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    self.Players[ent] = nil
    ent:SetNWBool("TF_MVM_InUpgradeStation", false)
end

function ENT:OnRemove()
    for ply in pairs(self.Players) do
        if IsValid(ply) then
            ply:SetNWBool("TF_MVM_InUpgradeStation", false)
        end
    end
    self.Players = {}
end
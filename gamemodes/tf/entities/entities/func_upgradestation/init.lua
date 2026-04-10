AddCSLuaFile("shared.lua")

ENT.Base = "base_brush"
ENT.Type = "brush"

local function IsUpgradePlayer(ent)
    return IsValid(ent) and ent:IsPlayer() and ent:Team() == TEAM_RED
end

local function TryOpenUpgradePanel(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not TF_MVMShop or not TF_MVMShop.IsEnabledFor or not TF_MVMShop.BuildPayload then return end
    if not TF_MVMShop:IsEnabledFor(ply) then return end

    -- one-shot while inside trigger; reopen only after re-entering like TF2 flow.
    if ply.TF_MVMUpgradePanelOpen then return end

    local now = CurTime()
    if (ply.TF_MVMUpgradeTouchOpenAt or 0) > now then return end
    ply.TF_MVMUpgradeTouchOpenAt = now + 0.4

    net.Start("TF_MVM_UpgradeOpen")
    net.WriteTable(TF_MVMShop:BuildPayload(ply))
    net.Send(ply)

    ply.TF_MVMUpgradePanelOpen = true
    ply.TF_MVMUpgradePanelOpenedAt = CurTime()
end

function ENT:Initialize()
    self.Team = 0
    self.Disabled = false
    self.Players = {}
    self:SetTrigger(true)
end

function ENT:KeyValue(key, value)
    key = string.lower(tostring(key or ""))
    if key == "teamnum" then
        self.Team = tonumber(value) or 0
    elseif key == "startdisabled" or key == "start_disabled" then
        self.Disabled = tonumber(value) == 1
    end
end

function ENT:StartTouch(ent)
    if self.Disabled then return end
    if not IsUpgradePlayer(ent) then return end
    if self.Team ~= 0 and ent:Team() ~= self.Team then return end
    self.Players[ent] = true
    ent:SetNWBool("TF_MVM_InUpgradeStation", true)
    TryOpenUpgradePanel(ent)
end

function ENT:Touch(ent)
    if self.Disabled then return end
    if not IsUpgradePlayer(ent) then return end
    if self.Team ~= 0 and ent:Team() ~= self.Team then return end
    if self.Players[ent] then return end
    self.Players[ent] = true
    ent:SetNWBool("TF_MVM_InUpgradeStation", true)
    TryOpenUpgradePanel(ent)
end

function ENT:EndTouch(ent)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    self.Players[ent] = nil
    ent:SetNWBool("TF_MVM_InUpgradeStation", false)
    ent.TF_MVMUpgradePanelOpen = nil
    if util.NetworkStringToID("TF_MVM_UpgradeClose") ~= 0 then
        net.Start("TF_MVM_UpgradeClose")
        net.Send(ent)
    end
end

function ENT:OnRemove()
    for ply in pairs(self.Players) do
        if IsValid(ply) then
            ply:SetNWBool("TF_MVM_InUpgradeStation", false)
            ply.TF_MVMUpgradePanelOpen = nil
            if util.NetworkStringToID("TF_MVM_UpgradeClose") ~= 0 then
                net.Start("TF_MVM_UpgradeClose")
                net.Send(ply)
            end
        end
    end
    self.Players = {}
end

function ENT:AcceptInput(name)
    name = string.lower(tostring(name or ""))
    if name == "enable" then
        self.Disabled = false
        return true
    elseif name == "disable" then
        self.Disabled = true
        for ply in pairs(self.Players) do
            self:EndTouch(ply)
        end
        self.Players = {}
        return true
    end
    return false
end

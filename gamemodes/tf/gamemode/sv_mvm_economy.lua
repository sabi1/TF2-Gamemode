TF_MVM = TF_MVM or {}

local ECON = {}
TF_MVM.Economy = ECON

local function IsMvMPlayer(ply)
    return IsValid(ply) and ply:IsPlayer() and not ply.TFBot and ply:Team() == TEAM_RED
end

function ECON:GetCredits(ply)
    if not IsValid(ply) then return 0 end
    if TF_MVMShop and TF_MVMShop.GetCredits then
        return math.max(0, TF_MVMShop:GetCredits(ply))
    end
    return math.max(0, ply:GetNWInt("TF_MVM_Credits", 0))
end

function ECON:SetCredits(ply, amount)
    if not IsValid(ply) then return end
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if TF_MVMShop and TF_MVMShop.SetCredits then
        TF_MVMShop:SetCredits(ply, amount)
        return
    end
    ply:SetNWInt("TF_MVM_Credits", amount)
end

function ECON:AddCredits(ply, amount)
    if not IsValid(ply) then return end
    self:SetCredits(ply, self:GetCredits(ply) + (tonumber(amount) or 0))
end

function ECON:ResetAll(starting)
    local start = math.max(0, math.floor(tonumber(starting) or 0))
    if TF_MVMShop and TF_MVMShop.ResetAllPlayers then
        TF_MVMShop:ResetAllPlayers(start)
        return
    end
    for _, ply in ipairs(player.GetAll()) do
        if IsMvMPlayer(ply) then
            self:SetCredits(ply, start)
        end
    end
end

function ECON:Distribute(amount, killer)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then return end

    if IsMvMPlayer(killer) then
        self:AddCredits(killer, amount)
        return
    end

    local teamPlayers = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsMvMPlayer(ply) then
            teamPlayers[#teamPlayers + 1] = ply
        end
    end

    if #teamPlayers == 0 then
        return
    end

    local perPlayer = math.floor(amount / #teamPlayers)
    local remainder = amount % #teamPlayers

    for i, ply in ipairs(teamPlayers) do
        local give = perPlayer
        if i <= remainder then
            give = give + 1
        end
        if give > 0 then
            self:AddCredits(ply, give)
        end
    end
end

return ECON

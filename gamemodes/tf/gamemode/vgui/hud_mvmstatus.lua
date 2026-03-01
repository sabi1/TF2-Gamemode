local PANEL = {}

local function IsMvMMap()
    return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

local function DrawPanel(x, y, w, h)
    surface.SetDrawColor(23, 20, 17, 220)
    surface.DrawRect(x, y, w, h)
    surface.SetDrawColor(179, 153, 111, 240)
    surface.DrawOutlinedRect(x, y, w, h, 2)
end

function PANEL:Init()
    self:SetPaintBackgroundEnabled(false)
    self:ParentToHUD()
    self:SetVisible(true)
end

function PANEL:PerformLayout()
    local w = math.floor(280 * (ScrH() / 480))
    local h = math.floor(72 * (ScrH() / 480))
    self:SetSize(w, h)
    self:SetPos(math.floor((ScrW() - w) * 0.5), math.floor(8 * (ScrH() / 480)))
end

function PANEL:Paint(w, h)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if not IsMvMMap() then return end
    if GetConVarNumber("cl_drawhud") == 0 then return end
    if GAMEMODE and GAMEMODE.ShowScoreboard == true then return end

    DrawPanel(0, 0, w, h)

    local waveCurrent = 1
    local waveTotal = 1
    local inSetup = false
    local setupEnd = 0
    local readyCount = 0
    local readyTotal = 0

    if TF_MVMState and TF_MVMState.Get then
        waveCurrent = math.max(1, tonumber(TF_MVMState:Get("wave_current", 1)) or 1)
        waveTotal = math.max(waveCurrent, tonumber(TF_MVMState:Get("wave_total", waveCurrent)) or waveCurrent)
        inSetup = TF_MVMState:Get("in_setup", false) and true or false
        setupEnd = tonumber(TF_MVMState:Get("setup_end_time", 0)) or 0
        readyCount = math.max(0, tonumber(TF_MVMState:Get("ready_count", 0)) or 0)
        readyTotal = math.max(0, tonumber(TF_MVMState:Get("ready_total", 0)) or 0)
    end

    local setupText = "ACTIVE"
    if inSetup then
        if setupEnd and setupEnd > CurTime() then
            local left = math.max(0, math.ceil(setupEnd - CurTime()))
            setupText = "SETUP " .. tostring(left)
        else
            setupText = "SETUP WAITING"
        end
    end

    local credits = ply:GetNWInt("TF_MVM_Credits", 0)
    local selected = ply:GetNWString("TF_MVM_CanteenSelected", "crit")
    local selectedCharges = ply:GetNWInt("TF_MVM_Canteen_" .. selected, 0)

    draw.SimpleText("WAVE " .. tostring(waveCurrent) .. " / " .. tostring(waveTotal), "Trebuchet24", 10, 8, Color(231, 218, 186), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(setupText, "DermaDefaultBold", w - 10, 10, Color(225, 207, 164), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    draw.SimpleText("Credits: " .. tostring(credits), "DermaDefaultBold", 10, 36, Color(252, 221, 118), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local canteenText = string.upper(selected) .. ": " .. tostring(selectedCharges)
    if inSetup then
        local spare2Bind = "F4"
        local isReady = ply:GetNWBool("TF_MVM_Ready", false)
        local waitingForReady = not (setupEnd and setupEnd > CurTime())
        local readyText
        if waitingForReady then
            readyText = string.format("PRESS %s TO READY UP (%d/%d)%s", spare2Bind, readyCount, readyTotal, isReady and " - READY" or "")
        else
            readyText = string.format("%s READY (%d/%d)%s", spare2Bind, readyCount, readyTotal, isReady and " - READY" or "")
        end
        draw.SimpleText(readyText, "DermaDefaultBold", w - 10, 36, Color(212, 198, 170), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    else
        draw.SimpleText("Canteen " .. canteenText, "DermaDefaultBold", w - 10, 36, Color(212, 198, 170), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end
end

if HudMvMStatus then
    HudMvMStatus:Remove()
end
HudMvMStatus = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

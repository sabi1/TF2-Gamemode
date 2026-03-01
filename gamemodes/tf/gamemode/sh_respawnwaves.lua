
if SERVER then AddCSLuaFile() end

TF2 = TF2 or {}
TF2.RespawnWaves = TF2.RespawnWaves or {}
local RW = TF2.RespawnWaves

-- Teams (rely on your gamemode's TEAM_RED / TEAM_BLU constants)
RW.TEAM_RED = TEAM_RED or 2
RW.TEAM_BLU = TEAM_BLU or 3

-- Game mode kinds we special-case (expand as you add logic)
RW.MODE = {
  DEFAULT = 0,     -- CTF / PLR stage defaults
  KOTH    = 1,     -- King of the Hill
  CP_5CP  = 2,     -- 5CP push (Granary/Badlands)
  AD_CP   = 3,     -- Attack/Defend (Dustbowl, Gravel Pit, etc.)
  PL      = 4,     -- Payload single-stage
  PLR     = 5,     -- Payload Race
  SD      = 6,     -- Special Delivery
  PASS    = 7,     -- PASS Time
}

-- Networking hooks (if you later want HUDs). For now it's server-driven only.

if CLIENT then
    -- cl_respawnwaves.lua

    local respawnTime = 0

    net.Receive("tf2_respawnwaves_time", function()
        respawnTime = net.ReadFloat() -- time when you respawn
    end)

    hook.Add("HUDPaint", "TF2_RespawnWaveHUD", function()
        if respawnTime <= 0 then return end

        local remain = math.ceil(respawnTime - CurTime())
        if remain <= 0 then return end

        -- Team color
        local ply = LocalPlayer()
        local teamcol = team.GetColor(ply:Team()) or Color(200, 200, 200)

        -- Box properties
        local boxW, boxH = 220, 40
        local x, y = ScrW()/2, ScrH() - 150

        draw.RoundedBox(8, x - boxW/2, y, boxW, boxH, Color(teamcol.r, teamcol.g, teamcol.b, 180))

        draw.SimpleText("Respawn in " .. remain .. "s", "Trebuchet24",
            x, y + boxH/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)

end

return RW
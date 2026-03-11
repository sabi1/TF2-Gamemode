if SERVER then return end

local bg = Color(18, 22, 30, 210)
local fg = Color(235, 239, 246, 255)
local red = Color(220, 76, 76, 255)
local blu = Color(106, 174, 232, 255)
local gold = Color(235, 198, 86, 255)
local dim = Color(170, 178, 194, 255)

local function DrawBar(x, y, w, h, frac, fill, outline)
	frac = math.Clamp(tonumber(frac) or 0, 0, 1)
	surface.SetDrawColor(0, 0, 0, 180)
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(fill.r, fill.g, fill.b, fill.a)
	surface.DrawRect(x + 2, y + 2, math.max(0, (w - 4) * frac), h - 4)
	surface.SetDrawColor(outline.r, outline.g, outline.b, outline.a)
	surface.DrawOutlinedRect(x, y, w, h, 1)
end

hook.Add("HUDPaint", "TF_VSH_HUD", function()
	if not GetGlobalBool("TF_VSH_Active", false) then return end
	if not GetGlobalBool("TF_VSH_RoundActive", false) then return end

	local lp = LocalPlayer()
	if not IsValid(lp) then return end
	if lp:Team() == TEAM_SPECTATOR then return end

	local sw, sh = ScrW(), ScrH()
	local topW = math.floor(sw * 0.42)
	local topH = 70
	local topX = math.floor((sw - topW) * 0.5)
	local topY = 18

	local bossName = GetGlobalString("TF_VSH_BossName", "")
	local bossId = GetGlobalString("TF_VSH_BossId", "")
	local hp = math.max(0, GetGlobalInt("TF_VSH_BossHP", 0))
	local maxHp = math.max(1, GetGlobalInt("TF_VSH_BossMaxHP", 1))
	local rage = math.Clamp(GetGlobalFloat("TF_VSH_BossRage", 0), 0, 100)
	local aliveBlu = math.max(0, GetGlobalInt("TF_VSH_BluAlive", 0))

	draw.RoundedBox(8, topX, topY, topW, topH, bg)
	draw.SimpleText("VERSUS SAXTON HALE", "Trebuchet24", topX + 12, topY + 7, fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText(string.format("%s (%s)", bossName ~= "" and bossName or "Unknown Boss", bossId ~= "" and string.upper(bossId) or "BOSS"), "Trebuchet18", topX + 12, topY + 29, dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	DrawBar(topX + 12, topY + 49, topW - 24, 14, hp / maxHp, red, Color(255, 255, 255, 35))

	draw.SimpleText(string.format("%d / %d", hp, maxHp), "Trebuchet18", topX + topW - 12, topY + 29, fg, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	draw.SimpleText(string.format("BLU Alive: %d", aliveBlu), "Trebuchet18", topX + topW - 12, topY + 7, blu, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

	local isBoss = lp:GetNWBool("TF_VSH_Boss", false)
	local panelW = 290
	local panelH = 76
	local panelX = 20
	local panelY = sh - panelH - 26
	draw.RoundedBox(8, panelX, panelY, panelW, panelH, bg)

	if isBoss then
		local myRage = math.Clamp(lp:GetNWFloat("TF_VSH_Rage", 0), 0, 100)
		local charge = math.Clamp(lp:GetNWFloat("TF_VSH_AbilityCharge", 0), 0, 1)
		draw.SimpleText("BOSS PANEL", "Trebuchet24", panelX + 10, panelY + 6, red, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(string.format("Rage: %d%%  (M2 to cast)", math.floor(myRage + 0.5)), "Trebuchet18", panelX + 10, panelY + 30, fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		DrawBar(panelX + 10, panelY + 52, panelW - 20, 12, myRage / 100, gold, Color(255, 255, 255, 35))
		draw.SimpleText(string.format("Jump Charge: %d%% (RELOAD hold)", math.floor(charge * 100)), "Trebuchet18", panelX + panelW + 8, panelY + 6, fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	else
		draw.SimpleText("FIGHTER PANEL", "Trebuchet24", panelX + 10, panelY + 6, blu, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("Kill the boss before BLU is wiped.", "Trebuchet18", panelX + 10, panelY + 30, fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(string.format("Boss Rage: %d%%", math.floor(rage + 0.5)), "Trebuchet18", panelX + 10, panelY + 50, dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
end)


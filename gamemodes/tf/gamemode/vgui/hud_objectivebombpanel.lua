local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W / 640
local Scale = H / 480

CreateConVar("hud_show_mvm_as_hl2", "1", { FCVAR_ARCHIVE }, "Show MVM hud as GMod Player")
CreateClientConVar("cl_mvm_wave_status_visible_during_wave", "0", true, false, "Display full wave contents while a wave is active in MvM.")

local tex_compass = surface.GetTextureID("hud/objectives_flagpanel_compass_grey")
local tex_bomb_dropped = surface.GetTextureID("hud/bomb_dropped")
local tex_bomb_carried = surface.GetTextureID("hud/bomb_carried")
local tex_wave_bg = surface.GetTextureID("hud/tournament_panel_brown")
local tex_wave_prog = surface.GetTextureID("hud/tournament_panel_blu")
local tex_wave_prog_bg = surface.GetTextureID("hud/tournament_panel_tan")
local tex_bomb_upgrade_base = surface.GetTextureID("hud/bomb_carrier_upgrade_base")
local tex_bomb_upgrade_meter = surface.GetTextureID("hud/bomb_carrier_upgrade_meter")
local tex_bomb_upgrade_frame = surface.GetTextureID("hud/bomb_carrier_upgrade_frame")
local tex_bomb_lvl1 = surface.GetTextureID("hud/hud_mvm_bomb_upgrade_1")
local tex_bomb_lvl1_dis = surface.GetTextureID("hud/hud_mvm_bomb_upgrade_1_disabled")
local tex_bomb_lvl2 = surface.GetTextureID("hud/hud_mvm_bomb_upgrade_2")
local tex_bomb_lvl2_dis = surface.GetTextureID("hud/hud_mvm_bomb_upgrade_2_disabled")
local tex_bomb_lvl3 = surface.GetTextureID("hud/hud_mvm_bomb_upgrade_3")
local tex_bomb_lvl3_dis = surface.GetTextureID("hud/hud_mvm_bomb_upgrade_3_disabled")

local ICON_PATH = {
	["scout"] = "hud/leaderboard_class_scout",
	["scout giant fast"] = "hud/leaderboard_class_scout_giant_fast",
	["scout stun"] = "hud/leaderboard_class_scout_stun",
	["scout bonk"] = "hud/leaderboard_class_scout_bonk",
	["scout fan"] = "hud/leaderboard_class_scout_fan",
	["scout shortstop"] = "hud/leaderboard_class_scout_shortstop",
	["soldier"] = "hud/leaderboard_class_soldier",
	["soldier spammer"] = "hud/leaderboard_class_soldier_spammer",
	["soldier barrage"] = "hud/leaderboard_class_soldier_barrage",
	["soldier crit"] = "hud/leaderboard_class_soldier_crit",
	["soldier blackbox"] = "hud/leaderboard_class_soldier_blackbox",
	["pyro"] = "hud/leaderboard_class_pyro",
	["pyro flare"] = "hud/leaderboard_class_pyro_flare",
	["demoman"] = "hud/leaderboard_class_demo",
	["demo"] = "hud/leaderboard_class_demo",
	["demoknight"] = "hud/leaderboard_class_demoknight",
	["demoknight samurai"] = "hud/leaderboard_class_demoknight_samurai",
	["heavy"] = "hud/leaderboard_class_heavy",
	["heavy champ"] = "hud/leaderboard_class_heavy_champ",
	["heavy deflector"] = "hud/leaderboard_class_heavy_deflector",
	["heavy shotgun"] = "hud/leaderboard_class_heavy_shotgun",
	["heavy heater"] = "hud/leaderboard_class_heavy_heater",
	["heavy steelfist"] = "hud/leaderboard_class_heavy_steelfist",
	["heavy gru"] = "hud/leaderboard_class_heavy_gru",
	["engineer"] = "hud/leaderboard_class_engineer",
	["teleporter"] = "hud/leaderboard_class_teleporter",
	["medic"] = "hud/leaderboard_class_medic",
	["medic uber"] = "hud/leaderboard_class_medic_uber",
	["sniper"] = "hud/leaderboard_class_sniper",
	["sniper bow"] = "hud/leaderboard_class_sniper_bow",
	["spy"] = "hud/leaderboard_class_spy",
	["sentry buster"] = "hud/leaderboard_class_sentry_buster",
	["sentrybuster"] = "hud/leaderboard_class_sentry_buster",
	["sentry_buster"] = "hud/leaderboard_class_sentry_buster",
	["tank"] = "hud/leaderboard_class_tank",
}

local function IsMvMMap()
	return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

local function InSetup()
	return TF_MVMState and TF_MVMState.Get and TF_MVMState:Get("in_setup", false) or false
end

local function GetWaveText()
	local waveCurrent = 1
	local waveTotal = 1
	if TF_MVMState and TF_MVMState.Get then
		waveCurrent = math.max(1, tonumber(TF_MVMState:Get("wave_current", 1)) or 1)
		waveTotal = math.max(waveCurrent, tonumber(TF_MVMState:Get("wave_total", waveCurrent)) or waveCurrent)
	end
	return "WAVE " .. tostring(waveCurrent) .. " / " .. tostring(waveTotal)
end

local function GetBombEnt()
	local list = ents.FindByClass("item_teamflag_mvm")
	if not list or #list == 0 then return nil end
	return list[1]
end

local function GetBombTargetPos(bomb)
	if not IsValid(bomb) then return nil end
	local carrier = bomb:GetNWEntity("carrier")
	if IsValid(carrier) then return carrier:WorldSpaceCenter() end
	return bomb:WorldSpaceCenter()
end

local function GetBombUpgradeState(bomb)
	if not IsValid(bomb) then
		return 0, 0
	end

	local level = math.Clamp(tonumber(bomb:GetNWInt("MVM_BombUpgradeLevel", 0)) or 0, 0, 3)
	local startedAt = tonumber(bomb:GetNWFloat("MVM_BombUpgradeStartedAt", 0)) or 0
	if startedAt <= 0 then
		return level, 0
	end

	local elapsed = math.max(0, CurTime() - startedAt)
	local thresholds = { 10, 45, 65 }

	if level >= 3 then
		return level, 1
	end

	local prev = 0
	local nextThreshold = thresholds[level + 1] or thresholds[#thresholds]
	if level >= 1 then
		prev = thresholds[level] or 0
	end

	local span = math.max(1, nextThreshold - prev)
	local progress = math.Clamp((elapsed - prev) / span, 0, 1)
	return level, progress
end

local function GetWaveStatusEntries()
	if not TF_MVMState or not TF_MVMState.Get then return {} end
	local entries = TF_MVMState:Get("wave_status", {})
	if not istable(entries) then return {} end
	return entries
end

local function GetRobotIconPath(rawClass, giant)
	local cls = string.lower(string.Trim(tostring(rawClass or "scout")))
	if cls == "" then cls = "scout" end
	if cls == "heavyweapons" then cls = "heavy" end
	if giant then
		local giantKey = cls .. " giant"
		if ICON_PATH[giantKey] then return ICON_PATH[giantKey] end
		if cls == "scout" and ICON_PATH["scout giant fast"] then
			return ICON_PATH["scout giant fast"]
		end
	end
	return ICON_PATH[cls] or ICON_PATH["scout"]
end

local function DrawSimpleBar(x, y, w, h, frac, bgTex, fillTex)
	frac = math.Clamp(frac or 0, 0, 1)
	surface.SetDrawColor(255, 255, 255, 255)
	if tf_draw and tf_draw.BorderPanel then
		tf_draw.BorderPanel(bgTex, x, y, w, h, 23, 23, 5 * Scale, 5 * Scale)
	else
		surface.SetTexture(bgTex)
		surface.DrawTexturedRect(x, y, w, h)
	end
	if frac > 0 then
		local fillW = math.max(0, (w - 2) * frac)
		if tf_draw and tf_draw.BorderPanel and fillW > (8 * Scale) then
			tf_draw.BorderPanel(fillTex, x + 1, y + 1, fillW, h - 2, 23, 23, 4 * Scale, 4 * Scale)
		else
			surface.SetTexture(fillTex)
			surface.DrawTexturedRect(x + 1, y + 1, fillW, h - 2)
		end
	end
end

local function ClassifyWaveEntries(entries)
	local miniboss, normal, support = {}, {}, {}
	for _, e in ipairs(entries or {}) do
		if e.support then
			support[#support + 1] = e
		elseif e.giant or e.tank then
			miniboss[#miniboss + 1] = e
		else
			normal[#normal + 1] = e
		end
	end
	return miniboss, normal, support
end

local function IsMiniBossEntry(e)
	if not istable(e) then return false end
	return e.giant == true or e.tank == true
end

function PANEL:DrawWaveStatus(lp)
	local entries = GetWaveStatusEntries()
	local setup = InSetup()
	local showVerbose = setup or lp:Team() == TEAM_SPECTATOR or GetConVar("cl_mvm_wave_status_visible_during_wave"):GetBool()

	local remainingNoSupport = 0
	for _, e in ipairs(entries) do
		if not e.support then
			remainingNoSupport = remainingNoSupport + math.max(0, tonumber(e.count) or 0)
		end
	end

	local waveCurrent = 1
	if TF_MVMState and TF_MVMState.Get then
		waveCurrent = math.max(1, tonumber(TF_MVMState:Get("wave_current", 1)) or 1)
	end
	if self.WaveEnemyWave ~= waveCurrent then
		self.WaveEnemyWave = waveCurrent
		self.WaveEnemyMax = math.max(remainingNoSupport, 1)
	else
		self.WaveEnemyMax = math.max(self.WaveEnemyMax or 1, remainingNoSupport)
	end

	local progressFrac = 0
	if (self.WaveEnemyMax or 0) > 0 then
		progressFrac = math.Clamp(remainingNoSupport / self.WaveEnemyMax, 0, 1)
	end

	local panelW = math.floor(600 * Scale)
	local panelH = math.floor(67 * Scale)
	local px = math.floor((ScrW() - panelW) * 0.5)
	-- TF2 WaveStatusPanel sits at the very top (y = 0 in HudMannVsMachineStatus.res).
	local py = math.floor(0 * Scale)

	local baseW = math.floor(200 * Scale)
	local enemyW = math.floor(20 * Scale)
	local enemyGap = math.floor(5 * Scale)
	local iconsToDraw = {}
	local miniboss, normal, support = ClassifyWaveEntries(entries)
	local hasSupport = #support > 0
	for _, e in ipairs(miniboss) do iconsToDraw[#iconsToDraw + 1] = e end
	for _, e in ipairs(normal) do iconsToDraw[#iconsToDraw + 1] = e end
	if showVerbose then
		for _, e in ipairs(support) do iconsToDraw[#iconsToDraw + 1] = e end
	end

	local supportLabelW = hasSupport and math.floor(56 * Scale) or 0
	local supportGap = hasSupport and math.floor(8 * Scale) or 0
	local contentW = 0
	if #iconsToDraw > 0 then
		contentW = (#iconsToDraw * enemyW) + ((#iconsToDraw - 1) * enemyGap)
	end
	local bgW = math.max(baseW, contentW + supportGap + supportLabelW + math.floor(24 * Scale))
	local bgH = (#iconsToDraw > 0 and showVerbose) and math.floor(65 * Scale) or math.floor(35 * Scale)
	local bgX = px + math.floor((panelW - bgW) * 0.5)
	local bgY = py + math.floor(2 * Scale)

	surface.SetDrawColor(255, 255, 255, 255)
	if tf_draw and tf_draw.BorderPanel then
		tf_draw.BorderPanel(tex_wave_bg, bgX, bgY, bgW, bgH, 23, 23, 5 * Scale, 5 * Scale)
	else
		surface.SetTexture(tex_wave_bg)
		surface.DrawTexturedRect(bgX, bgY, bgW, bgH)
	end

	draw.Text({
		text = GetWaveText(),
		font = "HudFontSmallestBold",
		pos = {px + math.floor(panelW * 0.5), py + math.floor(6 * Scale)},
		color = Colors.TanLight,
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_TOP,
	})

	DrawSimpleBar(
		bgX + math.floor((bgW - (180 * Scale)) * 0.5),
		py + math.floor(19 * Scale),
		math.floor(180 * Scale),
		math.floor(12 * Scale),
		progressFrac,
		tex_wave_prog_bg,
		tex_wave_prog
	)

	if #iconsToDraw > 0 and showVerbose then
		local totalContentW = contentW + supportGap + supportLabelW
		local sx = px + math.floor((panelW - totalContentW) * 0.5)
		local y = py + math.floor(32 * Scale)
		for i, e in ipairs(iconsToDraw) do
			local ex = sx + (i - 1) * (enemyW + enemyGap)
			local iconTex = surface.GetTextureID(GetRobotIconPath(e.class, e.giant))

			local mini = IsMiniBossEntry(e)
			surface.SetDrawColor(mini and 200 or 231, mini and 90 or 226, mini and 80 or 206, 235)
			surface.DrawRect(ex + math.floor(2 * Scale), y + math.floor(1 * Scale), math.floor(16 * Scale), math.floor(16 * Scale))
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetTexture(iconTex)
			surface.DrawTexturedRect(ex + math.floor(3 * Scale), y + math.floor(2 * Scale), math.floor(14 * Scale), math.floor(14 * Scale))

			if not e.support then
				draw.Text({
					text = tostring(math.max(0, tonumber(e.count) or 0)),
					font = "HudFontSmall",
					pos = {ex + math.floor(10 * Scale), y + math.floor(18 * Scale)},
					color = Colors.TanLight,
					xalign = TEXT_ALIGN_CENTER,
					yalign = TEXT_ALIGN_TOP,
				})
			end
		end

		if hasSupport then
			draw.Text({
				text = "SUPPORT",
				font = "HudFontSmallestBold",
				pos = {sx + contentW + supportGap, y + math.floor(18 * Scale)},
				color = Colors.TanLight,
				xalign = TEXT_ALIGN_LEFT,
				yalign = TEXT_ALIGN_TOP,
			})
		end
	end
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
	self.WaveEnemyMax = 1
	self.WaveEnemyWave = 0
end

function PANEL:PerformLayout()
	self:SetPos(0, 0)
	self:SetSize(W, H)
end

function PANEL:Paint()
	local lp = LocalPlayer()
	if not IsValid(lp)
		or lp:Team() == TEAM_SPECTATOR
		or (lp:IsHL2() and not GetConVar("hud_show_mvm_as_hl2"):GetBool())
		or GetConVar("tf_forcehl2hud"):GetBool()
		or GetConVarNumber("cl_drawhud") == 0
		or GAMEMODE.ShowScoreboard
		or not IsMvMMap()
	then
		return
	end

	self:DrawWaveStatus(lp)

	-- TF2 behavior: carrier panel is hidden during setup, wave status panel is separate.
	if InSetup() then return end

	local compassAngle = 0
	local compassCenterX = ScrW() * 0.5
	local compassCenterY = ScrH() - (68 * Scale)

	local bomb = GetBombEnt()
	if IsValid(bomb) then
		local bombTargetPos = GetBombTargetPos(bomb)
		if bombTargetPos then
			local vecBomb = bombTargetPos - lp:GetPos()
			vecBomb.z = 0
			if vecBomb:LengthSqr() > 0 then
				vecBomb:Normalize()
				local forward = lp:EyeAngles():Forward()
				local right = lp:EyeAngles():Right()
				forward.z = 0
				right.z = 0
				forward:Normalize()
				right:Normalize()
				local dot = math.Clamp(vecBomb:Dot(forward), -1, 1)
				local angleBetween = math.acos(dot)
				dot = vecBomb:Dot(right)
				if dot < 0 then
					angleBetween = angleBetween * -1
				end
				compassAngle = -1 * (math.deg(angleBetween) or 0)
			end
		end
	end

	local credits = lp:GetNWInt("TF_MVM_Credits", 0)
	local canteenType = string.upper(lp:GetNWString("TF_MVM_CanteenSelected", "crit"))
	local canteenCharges = lp:GetNWInt("TF_MVM_Canteen_" .. string.lower(canteenType), 0)

	draw.Text({
		text = "CREDITS: " .. tostring(credits),
		font = "HudFontSmallestBold",
		pos = {320 * WScale - 135 * Scale, (480 - 62) * Scale},
		color = Colors.TanLight,
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	})
	draw.Text({
		text = canteenType .. ": " .. tostring(canteenCharges),
		font = "HudFontSmallestBold",
		pos = {320 * WScale + 135 * Scale, (480 - 62) * Scale},
		color = Colors.TanLight,
		xalign = TEXT_ALIGN_RIGHT,
		yalign = TEXT_ALIGN_CENTER,
	})

	local level, upgradeProgress = GetBombUpgradeState(bomb)
	local trackW = math.floor(100 * Scale)
	local trackH = math.floor(30 * Scale)
	local trackX = math.floor((ScrW() * 0.5) - (50 * Scale))
	local trackY = math.floor(ScrH() - (35 * Scale))
	local fillW = math.floor(trackW * math.Clamp(upgradeProgress, 0, 1))

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetTexture(tex_bomb_upgrade_base)
	surface.DrawTexturedRect(trackX, trackY, trackW, trackH)
	if fillW > 0 then
		surface.SetTexture(tex_bomb_upgrade_meter)
		surface.DrawTexturedRectUV(trackX, trackY, fillW, trackH, 0, 0, fillW / trackW, 1)
	end
	surface.SetTexture(tex_bomb_upgrade_frame)
	surface.DrawTexturedRect(trackX, trackY, trackW, trackH)

	local iconX = math.floor((ScrW() * 0.5) + (32 * Scale))
	local iconSize = math.floor(20 * Scale)
	local iconY = {
		math.floor(ScrH() - (24 * Scale)),
		math.floor(ScrH() - (42 * Scale)),
		math.floor(ScrH() - (60 * Scale)),
	}
	local iconTex = {
		(level >= 1) and tex_bomb_lvl1 or tex_bomb_lvl1_dis,
		(level >= 2) and tex_bomb_lvl2 or tex_bomb_lvl2_dis,
		(level >= 3) and tex_bomb_lvl3 or tex_bomb_lvl3_dis,
	}
	for i = 1, 3 do
		surface.SetTexture(iconTex[i])
		surface.DrawTexturedRect(iconX, iconY[i], iconSize, iconSize)
	end

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetTexture(tex_compass)
	surface.DrawTexturedRectRotated(compassCenterX, compassCenterY, 96 * Scale, 96 * Scale, compassAngle)
	surface.SetTexture(IsValid(bomb) and IsValid(bomb:GetNWEntity("carrier")) and tex_bomb_carried or tex_bomb_dropped)
	surface.DrawTexturedRect(compassCenterX - (24 * Scale), compassCenterY - (24 * Scale), 48 * Scale, 48 * Scale)
end

if HudObjectiveBombPanel then HudObjectiveBombPanel:Remove() end
HudObjectiveBombPanel = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

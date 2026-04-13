local PANEL = {}
local WAVE_PANEL = {}

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
local tex_ready_card_bg = surface.GetTextureID("hud/tournament_panel_red")
local tex_ready_check = surface.GetTextureID("vgui/hud/checkmark")
if not tex_ready_check or tex_ready_check <= 0 then
	tex_ready_check = surface.GetTextureID("hud/checkmark")
end
local tex_ready_square_bg = surface.GetTextureID("hud/tournament_panel_brown")
local cachedReadyNameFont = nil
local cachedReadyPromptFont = nil
local readyNameFontCandidates = {
	"HudFontSmallestBold",
	"HudFontSmallBold",
	"DermaDefaultBold",
	"TF_MVM_ReadyNameFallback",
}
local readyPromptFontCandidates = {
	"HudFontSmallBold",
	"HudFontSmallestBold",
	"DermaDefaultBold",
	"TF_MVM_ReadyNameFallback",
}

surface.CreateFont("TF_MVM_ReadyNameFallback", {
	font = "Tahoma",
	size = 12,
	weight = 700,
	antialias = true,
})

local function IsUsableFont(fontName)
	if not isstring(fontName) or fontName == "" then
		return false
	end
	return pcall(function()
		surface.SetFont(fontName)
		local w, h = surface.GetTextSize("W")
		if not isnumber(w) or not isnumber(h) then
			error("font text size unavailable")
		end
	end)
end

local function GetReadyNameFont()
	if cachedReadyNameFont then
		return cachedReadyNameFont
	end
	for _, fontName in ipairs(readyNameFontCandidates) do
		if IsUsableFont(fontName) then
			cachedReadyNameFont = fontName
			break
		end
	end
	cachedReadyNameFont = cachedReadyNameFont or "TF_MVM_ReadyNameFallback"
	return cachedReadyNameFont
end

local function GetReadyPromptFont()
	if cachedReadyPromptFont then
		return cachedReadyPromptFont
	end
	local preferred = MvMRes and MvMRes.readyPromptFont or nil
	if IsUsableFont(preferred) then
		cachedReadyPromptFont = preferred
	else
		for _, fontName in ipairs(readyPromptFontCandidates) do
			if IsUsableFont(fontName) then
				cachedReadyPromptFont = fontName
				break
			end
		end
	end
	cachedReadyPromptFont = cachedReadyPromptFont or "TF_MVM_ReadyNameFallback"
	return cachedReadyPromptFont
end

local function DrawRoundedTexturedRect(texId, x, y, w, h, corner)
	if not texId or texId <= 0 then return end
	corner = math.floor(tonumber(corner) or 0)
	if corner <= 0 then
		surface.SetTexture(texId)
		surface.DrawTexturedRect(x, y, w, h)
		return
	end

	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(0xFF)
	render.SetStencilTestMask(0xFF)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)

	draw.RoundedBox(corner, x, y, w, h, Color(255, 255, 255, 255))

	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.SetStencilPassOperation(STENCIL_KEEP)
	surface.SetTexture(texId)
	surface.DrawTexturedRect(x, y, w, h)
	render.SetStencilEnable(false)
end

local function DrawRoundedBackplate(x, y, w, h, corner, color)
	corner = math.floor(tonumber(corner) or 0)
	if corner <= 0 then
		surface.SetDrawColor(color.r, color.g, color.b, color.a)
		surface.DrawRect(x, y, w, h)
		return
	end
	draw.RoundedBox(corner, x, y, w, h, color)
end

local MvMRes = {
	readySlot = 20,
	readyGap = 3,
	readyPad = 4,
	readyPromptY = 3,
	readyOffset = 14,
	readyCardsY = nil,
	readyPromptAbsY = nil,
	readyPromptFont = "HudFontSmallishBold",
	setupPanelW = 180,
	setupPanelH = 65,
	setupLabelX = 8,
	setupLabelY = 0,
	setupLabelW = 180,
	setupLabelH = 35,
	setupNotReadyX = 8,
	setupNotReadyY = 46,
	setupNotReadyW = 70,
	setupNotReadyH = 14,
	setupReadyX = 96,
	setupReadyY = 46,
	setupReadyW = 70,
	setupReadyH = 14,
	setupLabelText = "SETUP",
	setupReadyText = "READY",
	setupNotReadyText = "NOT READY",
	readyCardW = 55,
	readyCardH = 35,
	readyNameX = 4,
	readyNameY = 25,
	readyNameW = 48,
	readyNameH = 8,
	readyClassX = 5,
	readyClassY = 4,
	readyClassW = 20,
	readyClassH = 20,
	readySquareX = 30,
	readySquareY = 6,
	readySquareW = 16,
	readySquareH = 16,
	readyCheckX = 32,
	readyCheckY = 8,
	readyCheckW = 12,
	readyCheckH = 12,
	readySquareCorner = 3,
	readyColorReady = Color(0, 255, 0, 220),
	readyColorNotReady = Color(0, 0, 0, 220),
	wavePanelW = 600,
	wavePanelH = 67,
	wavePanelY = 0,
	waveBgInsetY = 2,
	baseW = 200,
	enemyW = 20,
	enemyGap = 5,
	supportLabelW = 56,
	supportGap = 8,
	bgPadding = 24,
	expandedBGH = 65,
	compactBGH = 35,
	titleY = 6,
	progressW = 180,
	progressH = 12,
	progressY = 19,
	iconsY = 32,
	iconCountY = 18,
	supportLabelY = 18,
}

do
	local function FindByFieldNames(tree, ...)
		if not tree or not TF2Res or not TF2Res.FindByFieldName then return nil end
		for i = 1, select("#", ...) do
			local name = select(i, ...)
			local n = TF2Res.FindByFieldName(tree, name)
			if n then return n end
		end
		return nil
	end

	local function FindByKeys(tree, ...)
		if not tree or not TF2Res or not TF2Res.FindByKey then return nil end
		for i = 1, select("#", ...) do
			local key = select(i, ...)
			local n = TF2Res.FindByKey(tree, key)
			if n then return n end
		end
		return nil
	end

	local waveResPath = (TF_GetHudResPath and TF_GetHudResPath("mvm", "wave", "resource/ui/wavestatuspanel.res")) or "resource/ui/wavestatuspanel.res"
	local statusResPath = (TF_GetHudResPath and TF_GetHudResPath("mvm", "status", "resource/ui/hudmannvsmachinestatus.res")) or "resource/ui/hudmannvsmachinestatus.res"
	local tournamentSetupResPath = (TF_GetHudResPath and TF_GetHudResPath("mvm", "tournamentSetup", "resource/ui/hudtournamentsetup.res")) or "resource/ui/hudtournamentsetup.res"
	local tournamentResPath = (TF_GetHudResPath and TF_GetHudResPath("mvm", "tournament", "resource/ui/hudtournament.res")) or "resource/ui/hudtournament.res"

	local waveTree = TF2Res and TF2Res.Load and TF2Res.Load(waveResPath)
	local statusTree = TF2Res and TF2Res.Load and TF2Res.Load(statusResPath)
	local tournamentSetupTree = TF2Res and TF2Res.Load and TF2Res.Load(tournamentSetupResPath)
	local tournamentTree = TF2Res and TF2Res.Load and TF2Res.Load(tournamentResPath)

	local wavePanel = FindByFieldNames(waveTree, "WaveStatusPanel")
	if not wavePanel then
		wavePanel = FindByKeys(waveTree, "WaveStatusPanel")
	end
	local waveCountBG = FindByFieldNames(waveTree, "WaveCountBG")
	local waveProgressBG = FindByFieldNames(waveTree, "EnemyCountProgressBarBG", "EnemyCountBG")
	local waveProgressFG = FindByFieldNames(waveTree, "EnemyCountProgressBar", "EnemyCountProgress")
	local waveEnemyIcon = FindByFieldNames(waveTree, "EnemyCountImage")
	local waveCountLabel = FindByFieldNames(waveTree, "WaveCountLabel")
	local waveEnemyCountLabel = FindByFieldNames(waveTree, "EnemyCountLabel")
	local waveSupportLabel = FindByFieldNames(waveTree, "SupportLabel")

	local statusPanel = FindByFieldNames(statusTree, "HudMannVsMachineStatus", "MannVsMachineStatus")
	if not statusPanel then
		statusPanel = FindByKeys(statusTree, "HudMannVsMachineStatus", "CHudMannVsMachineStatus")
	end
	local statusBG = FindByFieldNames(statusTree, "PlayerStatusBG", "PlayerListBG")
	local statusClassImage = FindByFieldNames(statusTree, "PlayerClassImage", "PlayerClass")
	local statusReadyLabel = FindByFieldNames(statusTree, "ToggleReadyLabel", "ReadyLabel")
	local setupBG = FindByFieldNames(tournamentSetupTree, "HudTournamentSetupBG")
	local setupLabel = FindByFieldNames(tournamentSetupTree, "TournamentLabel", "TournamentSetupLabel")
	local setupNotReady = FindByFieldNames(tournamentSetupTree, "TournamentNotReadyButton")
	local setupReady = FindByFieldNames(tournamentSetupTree, "TournamentReadyButton")
	local readyPanelKV = FindByKeys(tournamentTree, "playerpanels_kv")
	local tournamentPanel = FindByFieldNames(tournamentTree, "HudTournament")
	local tournamentInstructionsLabel = FindByFieldNames(tournamentTree, "TournamentInstructionsLabel")

	local function GetNode(node, key)
		if not istable(node) then return nil end
		local v = node[key]
		if v ~= nil then return v end
		local needle = string.lower(tostring(key))
		for k, val in pairs(node) do
			if string.lower(tostring(k)) == needle then
				return val
			end
		end
		return nil
	end

	local function GetMvMString(node, key, default)
		local ifMvm = GetNode(node, "if_mvm")
		if istable(ifMvm) then
			local v = TF2Res.GetString(ifMvm, key, nil)
			if v ~= nil then return v end
		end
		return TF2Res.GetString(node, key, default)
	end

	local function GetMvMNumber(node, key, default)
		local ifMvm = GetNode(node, "if_mvm")
		if istable(ifMvm) then
			local v = TF2Res.GetNumber(ifMvm, key, nil)
			if v ~= nil then return v end
		end
		return TF2Res.GetNumber(node, key, default)
	end

	if TF2Res and TF2Res.GetNumber then
		if wavePanel then
			MvMRes.wavePanelW = TF2Res.GetNumber(wavePanel, "wide", MvMRes.wavePanelW)
			MvMRes.wavePanelH = TF2Res.GetNumber(wavePanel, "tall", MvMRes.wavePanelH)
			MvMRes.wavePanelY = TF2Res.GetNumber(wavePanel, "ypos", MvMRes.wavePanelY)
		end
		if waveCountBG then
			MvMRes.baseW = TF2Res.GetNumber(waveCountBG, "wide", MvMRes.baseW)
			MvMRes.waveBgInsetY = TF2Res.GetNumber(waveCountBG, "ypos", MvMRes.waveBgInsetY)
			MvMRes.bgPadding = math.max(8, TF2Res.GetNumber(waveCountBG, "draw_corner_width", 8) * 3)
			tex_wave_bg = TF2Res.GetTextureID(waveCountBG, "image", "hud/tournament_panel_brown")
		end
		if waveProgressBG then
			MvMRes.progressW = TF2Res.GetNumber(waveProgressBG, "wide", MvMRes.progressW)
			MvMRes.progressH = TF2Res.GetNumber(waveProgressBG, "tall", MvMRes.progressH)
			MvMRes.progressY = TF2Res.GetNumber(waveProgressBG, "ypos", MvMRes.progressY)
			tex_wave_prog_bg = TF2Res.GetTextureID(waveProgressBG, "image", "hud/tournament_panel_tan")
		end
		if waveProgressFG then
			tex_wave_prog = TF2Res.GetTextureID(waveProgressFG, "image", "hud/tournament_panel_blu")
		end
		if waveEnemyIcon then
			MvMRes.enemyW = TF2Res.GetNumber(waveEnemyIcon, "wide", MvMRes.enemyW)
			MvMRes.enemyGap = math.max(2, TF2Res.GetNumber(waveEnemyIcon, "xdelta", MvMRes.enemyGap))
			MvMRes.iconsY = TF2Res.GetNumber(waveEnemyIcon, "ypos", MvMRes.iconsY)
		end
		if waveCountLabel then
			MvMRes.titleY = TF2Res.GetNumber(waveCountLabel, "ypos", MvMRes.titleY)
		end
		if waveEnemyCountLabel then
			MvMRes.iconCountY = TF2Res.GetNumber(waveEnemyCountLabel, "ypos", MvMRes.iconCountY)
		end
		if waveSupportLabel then
			MvMRes.supportLabelW = TF2Res.GetNumber(waveSupportLabel, "wide", MvMRes.supportLabelW)
			MvMRes.supportLabelY = TF2Res.GetNumber(waveSupportLabel, "ypos", MvMRes.supportLabelY)
		end
		if statusPanel then
			MvMRes.readyOffset = math.Clamp(TF2Res.GetNumber(statusPanel, "tall", MvMRes.readyOffset), 8, 32)
		end
		if statusBG then
			MvMRes.readySlot = math.max(16, TF2Res.GetNumber(statusBG, "tall", MvMRes.readySlot))
			tex_wave_bg = TF2Res.GetTextureID(statusBG, "image", "hud/tournament_panel_brown")
		end
		if statusClassImage then
			MvMRes.readyPad = math.Clamp(TF2Res.GetNumber(statusClassImage, "xpos", MvMRes.readyPad), 2, 8)
		end
		if statusReadyLabel then
			MvMRes.readyPromptY = TF2Res.GetNumber(statusReadyLabel, "ypos", MvMRes.readyPromptY)
		end
		if setupBG then
			MvMRes.setupPanelW = TF2Res.GetNumber(setupBG, "wide", MvMRes.setupPanelW)
			MvMRes.setupPanelH = TF2Res.GetNumber(setupBG, "tall", MvMRes.setupPanelH)
			tex_wave_bg = TF2Res.GetTextureID(setupBG, "image", "hud/tournament_panel_brown")
		end
		if setupLabel then
			MvMRes.setupLabelX = TF2Res.GetNumber(setupLabel, "xpos", MvMRes.setupLabelX)
			MvMRes.setupLabelY = TF2Res.GetNumber(setupLabel, "ypos", MvMRes.setupLabelY)
			MvMRes.setupLabelW = TF2Res.GetNumber(setupLabel, "wide", MvMRes.setupLabelW)
			MvMRes.setupLabelH = TF2Res.GetNumber(setupLabel, "tall", MvMRes.setupLabelH)
			local labelText = TF2Res.GetString(setupLabel, "labelText", MvMRes.setupLabelText)
			if isstring(labelText) and labelText ~= "" and not string.find(labelText, "%%", 1, true) then
				MvMRes.setupLabelText = string.upper(labelText)
			end
		end
		if setupNotReady then
			MvMRes.setupNotReadyX = TF2Res.GetNumber(setupNotReady, "xpos", MvMRes.setupNotReadyX)
			MvMRes.setupNotReadyY = TF2Res.GetNumber(setupNotReady, "ypos", MvMRes.setupNotReadyY)
			MvMRes.setupNotReadyW = TF2Res.GetNumber(setupNotReady, "wide", MvMRes.setupNotReadyW)
			MvMRes.setupNotReadyH = TF2Res.GetNumber(setupNotReady, "tall", MvMRes.setupNotReadyH)
			local notReadyText = TF2Res.GetString(setupNotReady, "labelText", MvMRes.setupNotReadyText)
			if isstring(notReadyText) and notReadyText ~= "" then
				MvMRes.setupNotReadyText = string.upper(notReadyText)
			end
		end
		if setupReady then
			MvMRes.setupReadyX = TF2Res.GetNumber(setupReady, "xpos", MvMRes.setupReadyX)
			MvMRes.setupReadyY = TF2Res.GetNumber(setupReady, "ypos", MvMRes.setupReadyY)
			MvMRes.setupReadyW = TF2Res.GetNumber(setupReady, "wide", MvMRes.setupReadyW)
			MvMRes.setupReadyH = TF2Res.GetNumber(setupReady, "tall", MvMRes.setupReadyH)
			local readyText = TF2Res.GetString(setupReady, "labelText", MvMRes.setupReadyText)
			if isstring(readyText) and readyText ~= "" then
				MvMRes.setupReadyText = string.upper(readyText)
			end
		end
		if readyPanelKV then
			MvMRes.readyCardW = GetMvMNumber(readyPanelKV, "wide", MvMRes.readyCardW)
			MvMRes.readyCardH = GetMvMNumber(readyPanelKV, "tall", MvMRes.readyCardH)
			local cReady = TF2Res.GetColor(readyPanelKV, "color_ready", MvMRes.readyColorReady)
			local cNotReady = TF2Res.GetColor(readyPanelKV, "color_notready", MvMRes.readyColorNotReady)
			if cReady then MvMRes.readyColorReady = cReady end
			if cNotReady then MvMRes.readyColorNotReady = cNotReady end

			local playername = GetNode(readyPanelKV, "playername")
			local classimage = GetNode(readyPanelKV, "classimage")
			local readybg = GetNode(readyPanelKV, "ReadyBG")
			local readyimage = GetNode(readyPanelKV, "ReadyImage")

			if playername then
				MvMRes.readyNameX = GetMvMNumber(playername, "xpos", MvMRes.readyNameX)
				MvMRes.readyNameY = GetMvMNumber(playername, "ypos", MvMRes.readyNameY)
				MvMRes.readyNameW = GetMvMNumber(playername, "wide", MvMRes.readyNameW)
				MvMRes.readyNameH = GetMvMNumber(playername, "tall", MvMRes.readyNameH)
			end
			if classimage then
				MvMRes.readyClassX = GetMvMNumber(classimage, "xpos", MvMRes.readyClassX)
				MvMRes.readyClassY = GetMvMNumber(classimage, "ypos", MvMRes.readyClassY)
				MvMRes.readyClassW = GetMvMNumber(classimage, "wide", MvMRes.readyClassW)
				MvMRes.readyClassH = GetMvMNumber(classimage, "tall", MvMRes.readyClassH)
			end
			if readybg then
				MvMRes.readySquareX = GetMvMNumber(readybg, "xpos", MvMRes.readySquareX)
				MvMRes.readySquareY = GetMvMNumber(readybg, "ypos", MvMRes.readySquareY)
				MvMRes.readySquareW = GetMvMNumber(readybg, "wide", MvMRes.readySquareW)
				MvMRes.readySquareH = GetMvMNumber(readybg, "tall", MvMRes.readySquareH)
				MvMRes.readySquareCorner = math.max(2, TF2Res.GetNumber(readybg, "draw_corner_width", MvMRes.readySquareCorner))
				tex_ready_square_bg = TF2Res.GetTextureID(readybg, "image", "hud/tournament_panel_brown")
			end
			if readyimage then
				MvMRes.readyCheckX = GetMvMNumber(readyimage, "xpos", MvMRes.readyCheckX)
				MvMRes.readyCheckY = GetMvMNumber(readyimage, "ypos", MvMRes.readyCheckY)
				MvMRes.readyCheckW = GetMvMNumber(readyimage, "wide", MvMRes.readyCheckW)
				MvMRes.readyCheckH = GetMvMNumber(readyimage, "tall", MvMRes.readyCheckH)
				local checkImage = GetMvMString(readyimage, "image", "vgui/hud/checkmark")
				tex_ready_check = surface.GetTextureID(TF2Res.NormalizeImagePath(checkImage) or "vgui/hud/checkmark")
				if not tex_ready_check or tex_ready_check <= 0 then
					tex_ready_check = surface.GetTextureID("hud/checkmark")
				end
			end
		end
		if tournamentPanel then
			-- TF2 puts MvM player cards on team2_player_base_y in HudTournament if_mvm.
			local cardsY = GetMvMNumber(tournamentPanel, "team2_player_base_y", nil)
			if cardsY == nil then
				cardsY = GetMvMNumber(tournamentPanel, "team1_player_base_y", nil)
			end
			if isnumber(cardsY) then
				MvMRes.readyCardsY = cardsY
			end
		end
		if tournamentInstructionsLabel then
			local promptY = GetMvMNumber(tournamentInstructionsLabel, "ypos", nil)
			if isnumber(promptY) then
				MvMRes.readyPromptAbsY = promptY
			end
			local promptFont = GetMvMString(tournamentInstructionsLabel, "font", nil)
			if isstring(promptFont) and promptFont ~= "" and IsUsableFont(promptFont) then
				MvMRes.readyPromptFont = promptFont
				cachedReadyPromptFont = nil
			end
		end
	end
end

local function IsMvMMap()
	if TF_IsMvMMap then
		return TF_IsMvMMap()
	end
	return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

local function InSetup()
	return TF_MVMState and TF_MVMState.Get and TF_MVMState:Get("in_setup", false) or false
end

local function IsWaveRunning()
	if not (TF_MVMState and TF_MVMState.Get) then
		return false
	end
	return TF_MVMState:Get("wave_active", false) and true or false
end

local function IsBetweenWaves()
	return InSetup() or (not IsWaveRunning())
end

local function IsReadyEligiblePlayer(ply)
	return IsValid(ply)
		and ply:IsPlayer()
		and not ply:IsBot()
		and not ply.TFBot
		and ply:Team() == TEAM_RED
end

local MaterialExistsForHUDIcon

local PLAYER_CLASS_PORTRAIT = {
	scout = "scout",
	soldier = "soldier",
	pyro = "pyro",
	demoman = "demoman",
	demo = "demoman",
	heavy = "heavy",
	heavyweapons = "heavy",
	engineer = "engineer",
	engi = "engineer",
	medic = "medic",
	sniper = "sniper",
	spy = "spy",
}

local PLAYER_CLASS_LEADERBOARD_FALLBACK = {
	scout = "hud/leaderboard_class_scout",
	soldier = "hud/leaderboard_class_soldier",
	pyro = "hud/leaderboard_class_pyro",
	demoman = "hud/leaderboard_class_demo",
	demo = "hud/leaderboard_class_demo",
	heavy = "hud/leaderboard_class_heavy",
	heavyweapons = "hud/leaderboard_class_heavy",
	engineer = "hud/leaderboard_class_engineer",
	engi = "hud/leaderboard_class_engineer",
	medic = "hud/leaderboard_class_medic",
	sniper = "hud/leaderboard_class_sniper",
	spy = "hud/leaderboard_class_spy",
}

local function GetPlayerClassIcon(ply)
	local cls = string.lower(tostring(IsValid(ply) and ply.GetPlayerClass and ply:GetPlayerClass() or "scout"))
	local portraitClass = PLAYER_CLASS_PORTRAIT[cls] or "scout"
	local hudClass = PLAYER_CLASS_PORTRAIT[cls] or "scout"
	if hudClass == "demoman" then hudClass = "demo" end
	if hudClass == "engineer" then hudClass = "engi" end
	local teamSuffix = "red"
	if IsValid(ply) and ply.Team and ply:Team() == TEAM_BLU then
		teamSuffix = "blue"
	end

	local classPortraitPath = "vgui/class_portraits/" .. portraitClass
	if MaterialExistsForHUDIcon(classPortraitPath) then
		return surface.GetTextureID(classPortraitPath)
	end

	local classPortraitTeamPath = classPortraitPath .. "_" .. teamSuffix
	if MaterialExistsForHUDIcon(classPortraitTeamPath) then
		return surface.GetTextureID(classPortraitTeamPath)
	end

	local portraitPath = "hud/class_" .. hudClass .. teamSuffix
	if MaterialExistsForHUDIcon(portraitPath) then
		return surface.GetTextureID(portraitPath)
	end

	local fallback = PLAYER_CLASS_LEADERBOARD_FALLBACK[cls] or PLAYER_CLASS_LEADERBOARD_FALLBACK.scout
	return surface.GetTextureID(fallback)
end

local function GetWaveText()
	local waveCurrent = 1
	local waveTotal = 1
	local isEndless = false
	if TF_MVMState and TF_MVMState.Get then
		waveCurrent = math.max(1, tonumber(TF_MVMState:Get("wave_current", 1)) or 1)
		waveTotal = math.max(0, tonumber(TF_MVMState:Get("wave_total", waveCurrent)) or waveCurrent)
		isEndless = TF_MVMState:Get("is_endless", false) and true or false
	end
	if isEndless then
		return "WAVE " .. tostring(waveCurrent) .. " / ENDLESS"
	end
	waveTotal = math.max(waveCurrent, waveTotal)
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

local function NormalizeRobotIconPath(rawIcon)
	local icon = string.Trim(tostring(rawIcon or ""))
	if icon == "" then return nil end
	local lower = string.lower(icon)
	if string.sub(lower, 1, 22) == "hud/leaderboard_class_" then
		return icon
	end
	if string.sub(lower, 1, 18) == "leaderboard_class_" then
		return "hud/" .. icon
	end
	if string.find(lower, "/", 1, true) then
		return icon
	end
	return "hud/leaderboard_class_" .. icon
end

MaterialExistsForHUDIcon = function(path)
	if not isstring(path) or path == "" then return false end
	local matPath = "materials/" .. TF2Res.NormalizeImagePath(path) .. ".vmt"
	return file.Exists(matPath, "GAME")
end

local function GetRobotIconPath(rawClass, giant, rawIcon)
	local iconOverride = NormalizeRobotIconPath(rawIcon)
	if iconOverride and MaterialExistsForHUDIcon(iconOverride) then
		return iconOverride
	end

	local cls = string.lower(string.Trim(tostring(rawClass or "scout")))
	if cls == "" then cls = "scout" end
	if cls == "sentrybuster" then cls = "sentry_buster" end
	if cls == "heavyweapons" then cls = "heavy" end
	if cls == "demoman" then cls = "demo" end

	if giant then
		local giantCandidates = {
			"hud/leaderboard_class_" .. cls .. "_giant",
			"hud/leaderboard_class_" .. cls .. " giant",
		}
		for _, candidate in ipairs(giantCandidates) do
			if MaterialExistsForHUDIcon(candidate) then
				return candidate
			end
		end
	end

	local classCandidate = "hud/leaderboard_class_" .. cls
	if MaterialExistsForHUDIcon(classCandidate) then
		return classCandidate
	end

	return "hud/leaderboard_class_scout"
end

local function IsWaveEntryVisible(e)
	if not istable(e) then return false end
	return (tonumber(e.count) or 0) > 0
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
	local miniboss, normal, support, mission = {}, {}, {}, {}
	local nNumEnemyRemaining = 0
	local nNumEnemyTypes = 0
	local nNumNonVerboseTypes = 0
	local betweenWaves = IsBetweenWaves()

	for _, src in ipairs(entries or {}) do
		if istable(src) then
			local e = table.Copy(src)
			e.count = math.max(0, tonumber(e.count) or 0)
			e.class = string.lower(string.Trim(tostring(e.class or "")))
			e.active = (e.active == nil) and true or (e.active and true or false)
			e.support_limited = (e.support_limited == true) or (e.supportlimited == true) or (e.limited == true)
			e.always_crit = (e.always_crit == true) or (e.alwayscrit == true) or (e.crit == true)
			e.miniboss = (e.giant == true) or (e.tank == true) or (e.miniboss == true)

			if e.class ~= "" then
				if e.mission then
					local includeMission = ((not IsWaveRunning()) and (e.class ~= "sentry_buster" and e.class ~= "sentrybuster" and e.class ~= "teleporter")) or (e.count > 0)
					if includeMission then
						mission[#mission + 1] = e
						nNumEnemyTypes = nNumEnemyTypes + 1
						nNumNonVerboseTypes = nNumNonVerboseTypes + 1
					end
				elseif e.support then
					support[#support + 1] = e
					nNumEnemyTypes = nNumEnemyTypes + 1
					if e.support_limited and e.active then
						nNumNonVerboseTypes = nNumNonVerboseTypes + 1
					end
				elseif e.miniboss then
					if e.count > 0 then
						miniboss[#miniboss + 1] = e
						nNumEnemyTypes = nNumEnemyTypes + 1
						nNumEnemyRemaining = nNumEnemyRemaining + e.count
					end
				else
					if e.count > 0 then
						normal[#normal + 1] = e
						nNumEnemyTypes = nNumEnemyTypes + 1
						nNumEnemyRemaining = nNumEnemyRemaining + e.count
						if e.class == "spy" then
							nNumNonVerboseTypes = nNumNonVerboseTypes + 1
						end
					end
				end
			end
		end
	end

	if betweenWaves then
		nNumEnemyRemaining = 0
	end

	return miniboss, normal, support, mission, nNumEnemyRemaining, nNumEnemyTypes, nNumNonVerboseTypes
end

local function IsMiniBossEntry(e)
	if not istable(e) then return false end
	return e.giant == true or e.tank == true
end

function PANEL:DrawWaveStatus(lp)
	local entries = GetWaveStatusEntries()
	local setup = InSetup()
	local betweenWaves = IsBetweenWaves()
	local showVerbose = setup or lp:Team() == TEAM_SPECTATOR or GetConVar("cl_mvm_wave_status_visible_during_wave"):GetBool()
	local topOffset = 0
	local setupPlayers = nil

	if setup then
		setupPlayers = {}
		for _, ply in ipairs(player.GetAll()) do
			if IsReadyEligiblePlayer(ply) then
				setupPlayers[#setupPlayers + 1] = ply
			end
		end
		table.sort(setupPlayers, function(a, b)
			return a:EntIndex() < b:EntIndex()
		end)
	end

	local miniboss, normal, support, mission, remainingNoSupport, nNumEnemyTypes, nNumNonVerboseTypes = ClassifyWaveEntries(entries)

	local waveCurrent = 1
	if TF_MVMState and TF_MVMState.Get then
		waveCurrent = math.max(1, tonumber(TF_MVMState:Get("wave_current", 1)) or 1)
	end
	if self.WaveEnemyWave ~= waveCurrent then
		self.WaveEnemyWave = waveCurrent
		self.WaveEnemyMax = math.max(remainingNoSupport, 1)
		self.WaveSawEnemies = remainingNoSupport > 0
	else
		self.WaveEnemyMax = math.max(self.WaveEnemyMax or 1, remainingNoSupport)
		if remainingNoSupport > 0 then
			self.WaveSawEnemies = true
		end
	end

	local progressFrac = 0
	if remainingNoSupport <= 0 and not self.WaveSawEnemies then
		-- TF2-like behavior: at wave start (before first spawn updates), bar appears full.
		progressFrac = 1
	elseif (self.WaveEnemyMax or 0) > 0 then
		progressFrac = math.Clamp(remainingNoSupport / self.WaveEnemyMax, 0, 1)
	end

	local panelW = math.floor(MvMRes.wavePanelW * Scale)
	local panelH = math.floor(MvMRes.wavePanelH * Scale)
	local px = math.floor((ScrW() - panelW) * 0.5)
	local py = math.floor(MvMRes.wavePanelY * Scale + topOffset)

	local baseW = math.floor(MvMRes.baseW * Scale)
	local enemyW = math.floor(MvMRes.enemyW * Scale)
	local enemyGap = math.floor(MvMRes.enemyGap * Scale)
	local displayedTypes = showVerbose and nNumEnemyTypes or nNumNonVerboseTypes
	local hasSupportOrMission = (#support > 0) or (#mission > 0)
	local separatorW = hasSupportOrMission and math.floor((MvMRes.separatorW or 6) * Scale) or 0
	local separatorGap = hasSupportOrMission and math.floor((MvMRes.separatorGap or 6) * Scale) or 0
	local contentW = 0
	if displayedTypes > 0 then
		contentW = (displayedTypes * enemyW) + ((displayedTypes - 1) * enemyGap)
		if hasSupportOrMission then
			contentW = contentW + separatorW + separatorGap
		end
	end

	local supportLabelW = (showVerbose and hasSupportOrMission) and math.floor(MvMRes.supportLabelW * Scale) or 0
	local supportGap = (showVerbose and hasSupportOrMission) and math.floor(MvMRes.supportGap * Scale) or 0
	local bgW = math.max(baseW, contentW + supportGap + supportLabelW + math.floor(MvMRes.bgPadding * Scale))
	local bgH = (displayedTypes > 0) and ((not showVerbose) and math.floor(MvMRes.expandedBGH * Scale) or math.floor(MvMRes.expandedBGH * Scale)) or math.floor(MvMRes.compactBGH * Scale)
	local bgX = px + math.floor((panelW - bgW) * 0.5)
	local bgY = py + math.floor(MvMRes.waveBgInsetY * Scale)

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
		pos = {px + math.floor(panelW * 0.5), py + math.floor(MvMRes.titleY * Scale)},
		color = Colors.TanLight,
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_TOP,
	})

	DrawSimpleBar(
		bgX + math.floor((bgW - (MvMRes.progressW * Scale)) * 0.5),
		py + math.floor(MvMRes.progressY * Scale),
		math.floor(MvMRes.progressW * Scale),
		math.floor(MvMRes.progressH * Scale),
		progressFrac,
		tex_wave_prog_bg,
		tex_wave_prog
	)

	if displayedTypes > 0 then
		local y = py + math.floor(MvMRes.iconsY * Scale)
		local drawItems = {}

		if showVerbose then
			for _, e in ipairs(miniboss) do
				drawItems[#drawItems + 1] = { entry = e, showCount = true, bgMiniBoss = true, flash = false }
			end
		end

		for _, e in ipairs(normal) do
			local nonVerboseSpy = (not showVerbose) and e.class == "spy"
			if showVerbose or nonVerboseSpy then
				drawItems[#drawItems + 1] = { entry = e, showCount = not nonVerboseSpy, bgMiniBoss = false, flash = nonVerboseSpy }
			end
		end

		local usedIcons = {}
		local function iconUsed(iconName)
			return iconName and usedIcons[iconName] == true
		end
		local function markIcon(iconName)
			if iconName and iconName ~= "" then
				usedIcons[iconName] = true
			end
		end

		for _, e in ipairs(support) do
			local bActive = (not showVerbose) and e.active and e.support_limited
			if showVerbose or bActive then
				local key = tostring(e.icon or e.class or "")
				if not iconUsed(key) then
					drawItems[#drawItems + 1] = {
						entry = e,
						showCount = false,
						bgMiniBoss = e.miniboss == true,
						flash = false,
					}
					markIcon(key)
				end
			end
		end

		for _, e in ipairs(mission) do
			local key = tostring(e.icon or e.class or "")
			if not iconUsed(key) then
				local mclass = e.class
				local flashMission = (not betweenWaves) and (mclass == "spy" or mclass == "sentry_buster" or mclass == "engineer")
				drawItems[#drawItems + 1] = {
					entry = e,
					showCount = false,
					bgMiniBoss = false,
					flash = flashMission,
				}
				markIcon(key)
			end
		end

		local sx = px + math.floor((panelW - (contentW + supportGap + supportLabelW)) * 0.5)
		for i, d in ipairs(drawItems) do
			local ex = sx + (i - 1) * (enemyW + enemyGap)
			if showVerbose and hasSupportOrMission and i > (#(showVerbose and miniboss or {}) + #normal) then
				ex = ex + separatorW + separatorGap
			end

			local e = d.entry
			local iconTex = surface.GetTextureID(GetRobotIconPath(e.class, e.giant, e.icon))

			local bgInset = math.floor(1 * Scale)
			local bgSize = math.floor(18 * Scale)
			local fgInset = math.floor(2 * Scale)
			local fgSize = math.floor(16 * Scale)
			-- Keep parent/backplate rounding matched to icon rounding.
			local iconInnerCorner = math.max(1, math.floor(1.5 * Scale))
			local iconCorner = math.max(iconInnerCorner, iconInnerCorner + bgInset)
			if d.flash then
				local pulse = 160 + ((math.floor(RealTime() * 10) % 10) * 10)
				DrawRoundedBackplate(
					ex + bgInset,
					y + bgInset,
					bgSize,
					bgSize,
					iconCorner,
					Color(pulse, 0, 0, 235)
				)
			else
				DrawRoundedBackplate(
					ex + bgInset,
					y + bgInset,
					bgSize,
					bgSize,
					iconCorner,
					Color(d.bgMiniBoss and 200 or 231, d.bgMiniBoss and 90 or 226, d.bgMiniBoss and 80 or 206, 235)
				)
			end
			surface.SetDrawColor(255, 255, 255, 255)
			DrawRoundedTexturedRect(
				iconTex,
				ex + fgInset,
				y + fgInset,
				fgSize,
				fgSize,
				iconInnerCorner
			)

			if d.showCount then
				draw.Text({
					text = tostring(math.max(0, tonumber(e.count) or 0)),
					font = "HudFontSmall",
					pos = {ex + math.floor(10 * Scale), y + math.floor(MvMRes.iconCountY * Scale)},
					color = Colors.TanLight,
					xalign = TEXT_ALIGN_CENTER,
					yalign = TEXT_ALIGN_TOP,
				})
			end
		end

		if showVerbose and hasSupportOrMission then
			draw.Text({
				text = "SUPPORT",
				font = "HudFontSmallestBold",
				pos = {sx + contentW + supportGap, y + math.floor(MvMRes.supportLabelY * Scale)},
				color = Colors.TanLight,
				xalign = TEXT_ALIGN_LEFT,
				yalign = TEXT_ALIGN_TOP,
			})
		end
	end

	if setup and istable(setupPlayers) then
		local cardW = math.floor(MvMRes.readyCardW * Scale)
		local cardH = math.floor(MvMRes.readyCardH * Scale)
		local gap = math.floor(MvMRes.readyGap * Scale)
		local cardsW = (#setupPlayers > 0) and ((#setupPlayers * cardW) + ((#setupPlayers - 1) * gap)) or cardW
		local cardsX = math.floor((ScrW() - cardsW) * 0.5)
		local cardsY
		if isnumber(MvMRes.readyCardsY) then
			cardsY = math.floor(MvMRes.readyCardsY * Scale)
		else
			cardsY = py + panelH + math.floor(math.max(6, MvMRes.readyOffset) * Scale)
		end
		local allReady = true

		for i, ply in ipairs(setupPlayers) do
			local x = cardsX + ((i - 1) * (cardW + gap))
			local y = cardsY
			local ready = ply:GetNWBool("TF_MVM_Ready", false)
			if not ready then
				allReady = false
			end

			local corner = math.max(2, math.floor(4 * Scale))
			draw.RoundedBox(corner, x, y, cardW, cardH, Color(246, 226, 192, 255))
			draw.RoundedBox(corner, x + 1, y + 1, math.max(1, cardW - 2), math.max(1, cardH - 2), Color(172, 102, 113, 245))

			local classX = x + math.floor(MvMRes.readyClassX * Scale)
			local classY = y + math.floor(MvMRes.readyClassY * Scale)
			local classW = math.floor(MvMRes.readyClassW * Scale)
			local classH = math.floor(MvMRes.readyClassH * Scale)
			DrawRoundedBackplate(
				classX - 1,
				classY - 1,
				classW + 2,
				classH + 2,
				math.max(1, math.floor(1 * Scale)),
				Color(0, 0, 0, 210)
			)
			surface.SetDrawColor(255, 255, 255, 255)
			DrawRoundedTexturedRect(
				GetPlayerClassIcon(ply),
				classX,
				classY,
				classW,
				classH,
				math.max(1, math.floor(1 * Scale))
			)

			local sqX = x + math.floor(MvMRes.readySquareX * Scale)
			local sqY = y + math.floor(MvMRes.readySquareY * Scale)
			local sqW = math.floor(MvMRes.readySquareW * Scale)
			local sqH = math.floor(MvMRes.readySquareH * Scale)
			local sqColor = ready and (MvMRes.readyColorReady or Color(121, 170, 106, 235)) or (MvMRes.readyColorNotReady or Color(86, 67, 67, 230))
			draw.RoundedBox(math.max(1, math.floor(MvMRes.readySquareCorner * Scale)), sqX, sqY, sqW, sqH, sqColor)
			surface.SetDrawColor(236, 214, 181, 170)
			surface.DrawOutlinedRect(sqX, sqY, sqW, sqH, 1)
			if ready then
				surface.SetDrawColor(255, 255, 255, 255)
				surface.SetTexture(tex_ready_check)
				surface.DrawTexturedRect(
					x + math.floor(MvMRes.readyCheckX * Scale),
					y + math.floor(MvMRes.readyCheckY * Scale),
					math.floor(MvMRes.readyCheckW * Scale),
					math.floor(MvMRes.readyCheckH * Scale)
				)
			end

			draw.SimpleText(
				tostring(ply:Nick() or ""),
				GetReadyNameFont(),
				x + math.floor((MvMRes.readyNameX + (MvMRes.readyNameW * 0.5)) * Scale),
				y + math.floor(MvMRes.readyNameY * Scale),
				Color(245, 232, 208, 255),
				TEXT_ALIGN_CENTER,
				TEXT_ALIGN_TOP
			)
		end

		local promptY
		if isnumber(MvMRes.readyPromptAbsY) then
			promptY = math.floor(MvMRes.readyPromptAbsY * Scale)
		else
			promptY = cardsY + cardH + math.floor(MvMRes.readyPromptY * Scale)
		end

		local promptBase = Color(255, 242, 214, 245)
		local promptWarn = Color(255, 162, 78, 250)
		local promptColor = promptBase
		if not allReady then
			local t = (math.sin(RealTime() * 6.5) + 1) * 0.5
			promptColor = Color(
				math.floor(Lerp(t, promptBase.r, promptWarn.r)),
				math.floor(Lerp(t, promptBase.g, promptWarn.g)),
				math.floor(Lerp(t, promptBase.b, promptWarn.b)),
				math.floor(Lerp(t, promptBase.a, promptWarn.a))
			)
		end

		draw.SimpleText(
			"F4 = TOGGLE READY",
			GetReadyPromptFont(),
			ScrW() * 0.5 + math.floor(1 * Scale),
			promptY + math.floor(1 * Scale),
			Color(0, 0, 0, 210),
			TEXT_ALIGN_CENTER,
			TEXT_ALIGN_TOP
		)
		draw.SimpleText(
			"F4 = TOGGLE READY",
			GetReadyPromptFont(),
			ScrW() * 0.5,
			promptY,
			promptColor,
			TEXT_ALIGN_CENTER,
			TEXT_ALIGN_TOP
		)
	end
end

function WAVE_PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:SetVisible(true)
	self.ParentStatus = self:GetParent()
	self.WaveEnemyMax = 1
	self.WaveEnemyWave = 0
	self._nextTick = 0
	self._waveCount = -1
	self._maxWaveCount = -1
	self._panelDirty = true
end

function WAVE_PANEL:PerformLayout()
	self:SetPos(0, 0)
	self:SetSize(ScrW(), ScrH())
end

function WAVE_PANEL:ShouldDrawWave()
	local lp = LocalPlayer()
	if not IsValid(lp) then return false end
	if not IsMvMMap() then return false end
	if lp:IsHL2() and not GetConVar("hud_show_mvm_as_hl2"):GetBool() then return false end
	if GetConVar("tf_forcehl2hud"):GetBool() then return false end
	if GetConVarNumber("cl_drawhud") == 0 then return false end
	if GAMEMODE and GAMEMODE.ShowScoreboard == true then return false end
	return true
end

function WAVE_PANEL:Think()
	local now = CurTime()
	if now < (self._nextTick or 0) then return end
	self._nextTick = now + 0.1

	local lp = LocalPlayer()
	if not self:ShouldDrawWave() or not IsValid(lp) then return end

	local waveCurrent = 1
	local waveTotal = 1
	local isEndless = false
	if TF_MVMState and TF_MVMState.Get then
		waveCurrent = math.max(1, tonumber(TF_MVMState:Get("wave_current", 1)) or 1)
		waveTotal = math.max(0, tonumber(TF_MVMState:Get("wave_total", waveCurrent)) or waveCurrent)
		isEndless = TF_MVMState:Get("is_endless", false) and true or false
	end
	if not isEndless then
		waveTotal = math.max(waveCurrent, waveTotal)
	end

	if self._waveCount ~= waveCurrent or self._maxWaveCount ~= waveTotal then
		self._waveCount = waveCurrent
		self._maxWaveCount = waveTotal
		self._panelDirty = true
	end
end

function WAVE_PANEL:Paint()
	if not self:ShouldDrawWave() then return end
	local parent = self.ParentStatus
	if not IsValid(parent) then return end
	local lp = LocalPlayer()
	if not IsValid(lp) then return end
	parent:DrawWaveStatus(lp)
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
	self.WaveEnemyMax = 1
	self.WaveEnemyWave = 0
	self.WaveSawEnemies = false
	self.WaveStatusPanel = vgui.Create("TFMvMWaveStatusPanel", self)
end

function PANEL:PerformLayout()
	W = ScrW()
	H = ScrH()
	Scale = H / 480
	WScale = W / 640
	self:SetPos(0, 0)
	self:SetSize(W, H)
	if IsValid(self.WaveStatusPanel) then
		self.WaveStatusPanel:SetPos(0, 0)
		self.WaveStatusPanel:SetSize(W, H)
	end
end

function PANEL:Paint()
	local lp = LocalPlayer()
	if not IsValid(lp)
		or (lp:IsHL2() and not GetConVar("hud_show_mvm_as_hl2"):GetBool())
		or GetConVar("tf_forcehl2hud"):GetBool()
		or GetConVarNumber("cl_drawhud") == 0
		or (GAMEMODE and GAMEMODE.ShowScoreboard == true)
		or not IsMvMMap()
		or lp:Team() == TEAM_SPECTATOR
	then
		return
	end

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

vgui.Register("TFMvMWaveStatusPanel", WAVE_PANEL, "DPanel")
if HudObjectiveBombPanel then HudObjectiveBombPanel:Remove() end
HudObjectiveBombPanel = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

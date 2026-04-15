
local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local score_panel_red_bg = surface.GetTextureID("hud/score_panel_red_bg")
local score_panel_blue_bg = surface.GetTextureID("hud/score_panel_blue_bg")
local tournament_panel_brown = surface.GetTextureID("hud/tournament_panel_brown")

local BlueTeamName = {
	text="",
	font="ScoreboardTeamNameLarge",
	pos={10*Scale, 40*Scale},
	color=Colors.TanLight,
	xalign=TEXT_ALIGN_LEFT,
	yalign=TEXT_ALIGN_CENTER,
}
local BlueTeamScore = {
	text="0",
	font="ScoreboardTeamScore",
	pos={290*Scale, 35.5*Scale},
	color=Colors.TanLight,
	xalign=TEXT_ALIGN_RIGHT,
	yalign=TEXT_ALIGN_CENTER,
}
local BlueTeamScoreShadow = {
	text="0",
	font="ScoreboardTeamScore",
	pos={291*Scale, 36.5*Scale},
	color=Colors.Black,
	xalign=TEXT_ALIGN_RIGHT,
	yalign=TEXT_ALIGN_CENTER,
}
local BlueTeamPlayerCount = {
	text="",
	font="ScoreboardMedium",
	pos={150*Scale, 47.5*Scale},
	color=Colors.TanLight,
	xalign=TEXT_ALIGN_LEFT,
	yalign=TEXT_ALIGN_CENTER,
}

local RedTeamName = {
	text="",
	font="ScoreboardTeamNameLarge",
	pos={590*Scale, 40*Scale},
	color=Colors.TanLight,
	xalign=TEXT_ALIGN_RIGHT,
	yalign=TEXT_ALIGN_CENTER,
}
local RedTeamScore = {
	text="0",
	font="ScoreboardTeamScore",
	pos={310*Scale, 35.5*Scale},
	color=Colors.TanLight,
	xalign=TEXT_ALIGN_LEFT,
	yalign=TEXT_ALIGN_CENTER,
}
local RedTeamScoreShadow = {
	text="0",
	font="ScoreboardTeamScore",
	pos={311*Scale, 36.5*Scale},
	color=Colors.Black,
	xalign=TEXT_ALIGN_LEFT,
	yalign=TEXT_ALIGN_CENTER,
}
local RedTeamPlayerCount = {
	text="",
	font="ScoreboardMedium",
	pos={450*Scale, 47.5*Scale},
	color=Colors.TanLight,
	xalign=TEXT_ALIGN_RIGHT,
	yalign=TEXT_ALIGN_CENTER,
}

local ServerName = {
	text="",
	font="ScoreboardVerySmall",
	pos={11*Scale, 70*Scale},
	color=Colors.TanLight,
	xalign=TEXT_ALIGN_LEFT,
	yalign=TEXT_ALIGN_CENTER,
}
local ServerTimeLeft = {
	text="",
	font="ScoreboardVerySmall",
	pos={585*Scale, 70*Scale},
	color=Colors.TanLight,
	xalign=TEXT_ALIGN_RIGHT,
	yalign=TEXT_ALIGN_CENTER,
}

local Spectators = {
	text="",
	font="ScoreboardVerySmall",
	pos={115*Scale, 367*Scale},
	xalign=TEXT_ALIGN_LEFT,
	yalign=TEXT_ALIGN_CENTER,
}
local SpectatorsInQueue = {
	text="",
	font="ScoreboardVerySmall",
	pos={115*Scale, 358*Scale},
	xalign=TEXT_ALIGN_LEFT,
	yalign=TEXT_ALIGN_CENTER,
}
local SpectatorsInQueue2 = {
	text="",
	font="ScoreboardVerySmall",
	pos={115*Scale, 347*Scale},
	xalign=TEXT_ALIGN_LEFT,
	yalign=TEXT_ALIGN_CENTER,
}
local PlayerName = {
	text="",
	font="ScoreboardMedium",
	pos={115*Scale, 387*Scale},
	xalign=TEXT_ALIGN_LEFT,
	yalign=TEXT_ALIGN_CENTER,
}
local PlayerScore = {
	text="",
	font="ScoreboardMedium",
	pos={580*Scale, 387*Scale},
	color=Colors.TanLight,
	xalign=TEXT_ALIGN_RIGHT,
	yalign=TEXT_ALIGN_CENTER,
}

local MvMTitle = {
	text="MANN VS MACHINE",
	font="ScoreboardTeamNameLarge",
	pos={300*Scale, 26*Scale},
	color=Colors.TanLight,
	xalign=TEXT_ALIGN_CENTER,
	yalign=TEXT_ALIGN_CENTER,
}

local MvMWave = {
	text="WAVE 1 / 1",
	font="ScoreboardMedium",
	pos={300*Scale, 43*Scale},
	color=Colors.TanLight,
	xalign=TEXT_ALIGN_CENTER,
	yalign=TEXT_ALIGN_CENTER,
}

local MvMDifficulty = {
	text="DIFFICULTY: ADVANCED",
	font="ScoreboardVerySmall",
	pos={300*Scale, 57*Scale},
	color=Colors.TanLight,
	xalign=TEXT_ALIGN_CENTER,
	yalign=TEXT_ALIGN_CENTER,
}

local MvMDefenders = {
	text="DEFENDERS",
	font="ScoreboardSmallest",
	pos={300*Scale, 79*Scale},
	color=Colors.TanLight,
	xalign=TEXT_ALIGN_CENTER,
	yalign=TEXT_ALIGN_CENTER,
}

local MvMScoreboardRes = {
	panelX = "cs-0.5",
	panelY = 16,
	panelW = 600,
	panelH = 448,
	mainX = 1.5,
	mainY = 8,
	mainW = 595.5,
	mainH = 375,
	listX = 8,
	listY = 86,
	listW = 584,
	listH = 260,
	localStatsY = 395,
	serverLeftX = 11,
	serverLeftY = 18,
	serverRightX = 585,
	serverRightY = 18,
	creditsX = 16,
	creditsY = 369,
}

local function getResValue(node, key)
	if not istable(node) then return nil end
	local ifMvm = istable(node.if_mvm) and node.if_mvm or nil
	if ifMvm and ifMvm[key] ~= nil then
		return ifMvm[key]
	end
	return node[key]
end

local function getResNumber(node, key, default)
	local raw = getResValue(node, key)
	if isnumber(raw) then return raw end
	if not isstring(raw) then return default end
	return tonumber(raw) or default
end

local function getResString(node, key, default)
	local raw = getResValue(node, key)
	if isstring(raw) and raw ~= "" then
		return raw
	end
	return default
end

local function resolveCoord(raw, axisSize, scale, fallback)
	if isnumber(raw) then
		return raw * scale
	end
	if not isstring(raw) then
		return fallback
	end

	local value = string.Trim(raw)
	local n = tonumber(value)
	if n ~= nil then
		return n * scale
	end

	local r = string.match(value, "^r([%+%-]?%d*%.?%d*)$")
	if r ~= nil then
		local offs = tonumber(r)
		if r == "" or offs == nil then offs = 0 end
		return axisSize - offs * scale
	end

	local c = string.match(value, "^c([%+%-]?%d*%.?%d*)$")
	if c ~= nil then
		local offs = tonumber(c)
		if c == "" or offs == nil then offs = 0 end
		return axisSize * 0.5 + offs * scale
	end

	return fallback
end

local function resolveScoreboardX(raw, axisSize, panelWide, scale, fallback)
	if not isstring(raw) then
		return resolveCoord(raw, axisSize, scale, fallback)
	end
	local value = string.Trim(raw)
	local cs = string.match(value, "^cs([%+%-]?%d*%.?%d*)$")
	if cs ~= nil then
		local offs = tonumber(cs)
		if cs == "" or offs == nil then offs = 0 end
		return axisSize * 0.5 - panelWide * 0.5 + offs * scale
	end
	return resolveCoord(value, axisSize, scale, fallback)
end

local function loadMvMScoreboardRes()
	if not (TF2Res and TF2Res.Load and TF2Res.FindByFieldName) then return end

	local tree = TF2Res.Load("resource/ui/mvmscoreboard.res")
	if not tree then
		tree = TF2Res.Load("resource/ui/scoreboard.res")
	end
	if not tree then return end

	local function findNode(fieldName, ...)
		local node = TF2Res.FindByFieldName(tree, fieldName)
		if node then return node end
		if TF2Res.FindByKey then
			for _, keyName in ipairs({...}) do
				node = TF2Res.FindByKey(tree, keyName)
				if node then return node end
			end
		end
		return nil
	end

	local scoreInfo = findNode("scoreinfo", "scores", "MvMScoreboard")
	local mainBG = findNode("MainBG", "MainBG", "Background", "BG")
	local serverLabel = findNode("ServerLabel", "ServerLabel", "ServerLabelNew")
	local serverTime = findNode("ServerTimeLeft", "ServerTimeLeft")
	local localStats = findNode("LocalPlayerStatsPanel", "LocalPlayerStatsPanel")
	local spectatorLabel = findNode("Spectators", "Spectators")

	if scoreInfo then
		MvMScoreboardRes.panelX = getResString(scoreInfo, "xpos", MvMScoreboardRes.panelX)
		MvMScoreboardRes.panelY = getResNumber(scoreInfo, "ypos", MvMScoreboardRes.panelY)
		MvMScoreboardRes.panelW = getResNumber(scoreInfo, "wide", MvMScoreboardRes.panelW)
		MvMScoreboardRes.panelH = getResNumber(scoreInfo, "tall", MvMScoreboardRes.panelH)
	end

	if mainBG then
		MvMScoreboardRes.mainX = getResNumber(mainBG, "xpos", MvMScoreboardRes.mainX)
		MvMScoreboardRes.mainY = getResNumber(mainBG, "ypos", MvMScoreboardRes.mainY)
		MvMScoreboardRes.mainW = getResNumber(mainBG, "wide", MvMScoreboardRes.mainW)
		MvMScoreboardRes.mainH = getResNumber(mainBG, "tall", MvMScoreboardRes.mainH)
	end

	if serverLabel then
		MvMScoreboardRes.serverLeftX = getResNumber(serverLabel, "xpos", MvMScoreboardRes.serverLeftX)
		MvMScoreboardRes.serverLeftY = getResNumber(serverLabel, "ypos", MvMScoreboardRes.serverLeftY)
	end

	if serverTime then
		MvMScoreboardRes.serverRightX = getResNumber(serverTime, "xpos", MvMScoreboardRes.serverRightX)
		MvMScoreboardRes.serverRightY = getResNumber(serverTime, "ypos", MvMScoreboardRes.serverRightY)
	end

	if localStats then
		MvMScoreboardRes.localStatsY = getResNumber(localStats, "ypos", MvMScoreboardRes.localStatsY)
	end

	if spectatorLabel then
		MvMScoreboardRes.creditsX = getResNumber(spectatorLabel, "xpos", MvMScoreboardRes.creditsX)
		MvMScoreboardRes.creditsY = getResNumber(spectatorLabel, "ypos", MvMScoreboardRes.creditsY)
	end

end

loadMvMScoreboardRes()

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:SetVisible(false)
	self.IsMvM = string.find(game.GetMap(), "mvm_", 1, true) ~= nil
	self.LegacyInfectedEnabled = TF_LegacyL4DEnabled and TF_LegacyL4DEnabled() or false
	if self.IsMvM then
		self.BluePlayerList = vgui.Create("TFMVMScoreboardPlayerList", self)
		self.BluePlayerList:SetTeam(TEAM_RED)
		self.RedPlayerList = vgui.Create("TFMVMScoreboardPlayerList", self)
		self.RedPlayerList:SetTeam(TEAM_BLU)
		self.RedPlayerList:SetVisible(false)
	else
		self.BluePlayerList = vgui.Create("TFScoreboardPlayerList", self)
		self.BluePlayerList:SetTeam(TEAM_BLU)
		self.RedPlayerList = vgui.Create("TFScoreboardPlayerList", self)
		self.RedPlayerList:SetTeam(TEAM_RED)
	end
	if self.LegacyInfectedEnabled then
		self.InfectedPlayerList = vgui.Create("TFScoreboardPlayerList", self)
		self.InfectedPlayerList:SetTeam(TEAM_INFECTED)
	end
	
	self.LocalStats = vgui.Create("TFScoreboardLocalStats", self)
end

function PANEL:PerformLayout()
	W = ScrW()
	H = ScrH()
	Scale = H/480
	WScale = W/640

	if not IsValid(LocalPlayer()) then return end

	local panelW = MvMScoreboardRes.panelW * Scale
	local panelH = MvMScoreboardRes.panelH * Scale
	local panelX = resolveScoreboardX(MvMScoreboardRes.panelX, W, panelW, Scale, W*0.5 - 300*Scale)
	local panelY = resolveCoord(MvMScoreboardRes.panelY, H, Scale, 16*Scale)

	self:SetPos(panelX, panelY)
	self:SetSize(panelW, panelH)

	if self.IsMvM then
		self.BluePlayerList:SetPos(MvMScoreboardRes.listX * Scale, MvMScoreboardRes.listY * Scale)
		self.BluePlayerList:SetSize(MvMScoreboardRes.listW * Scale, MvMScoreboardRes.listH * Scale)
		self.RedPlayerList:SetVisible(false)
		if IsValid(self.InfectedPlayerList) then
			self.InfectedPlayerList:SetVisible(false)
		end
	else
		self.BluePlayerList:SetPos(5*Scale, 72*Scale)
		self.BluePlayerList:SetSize(290*Scale, 280*Scale)
		if IsValid(self.InfectedPlayerList) then
			self.InfectedPlayerList:SetPos(5*Scale, 72*Scale)
			self.InfectedPlayerList:SetSize(290*Scale, 280*Scale)
		end
		self.RedPlayerList:SetPos(305*Scale, 72*Scale)
		self.RedPlayerList:SetSize(290*Scale, 280*Scale)
	end
	
	self.LocalStats:SetPos(0, MvMScoreboardRes.localStatsY * Scale)
	self.LocalStats:SetSize(panelW, panelH)
end

function PANEL:Paint()
	if self.IsMvM then
		local mainX = MvMScoreboardRes.mainX * Scale
		local mainY = MvMScoreboardRes.mainY * Scale
		local mainW = MvMScoreboardRes.mainW * Scale
		local mainH = MvMScoreboardRes.mainH * Scale
		local centerX = (MvMScoreboardRes.panelW * 0.5) * Scale

		local humanCount = #team.GetPlayers(TEAM_RED)
		local credits = LocalPlayer():GetNWInt("TF_MVM_Credits", 0)

		surface.SetDrawColor(255, 255, 255, 255)
		tf_draw.BorderPanel(tournament_panel_brown, mainX, mainY, mainW, mainH, 23, 23, 8*Scale, 8*Scale)
		surface.SetDrawColor(0, 0, 0, 153)
		surface.DrawRect(mainX + 7.5*Scale, MvMScoreboardRes.listY * Scale - 12*Scale, mainW - 13.5*Scale, 1*Scale)
		surface.DrawRect(mainX + 8.5*Scale, (MvMScoreboardRes.listY + MvMScoreboardRes.listH + 9) * Scale, mainW - 15.5*Scale, 1*Scale)

		local missionName = TF_MVMState and TF_MVMState.Get and tostring(TF_MVMState:Get("mission_name", "")) or ""
		local missionLower = string.lower(missionName)
		local difficulty = "NORMAL"
		if string.find(missionLower, "_intermediate", 1, true) then
			difficulty = "INTERMEDIATE"
		elseif string.find(missionLower, "_advanced", 1, true) then
			difficulty = "ADVANCED"
		elseif string.find(missionLower, "_expert", 1, true) then
			difficulty = "EXPERT"
		end
		MvMDifficulty.text = "DIFFICULTY: " .. difficulty
		MvMTitle.pos = {centerX, 26*Scale}
		MvMWave.pos = {centerX, 43*Scale}
		MvMDifficulty.pos = {centerX, 57*Scale}
		MvMDefenders.pos = {centerX, 79*Scale}

		draw.Text(MvMTitle)
		draw.Text(MvMDifficulty)
		draw.Text(MvMDefenders)

		local waveCurrent = 1
		local waveTotal = 1
		local isEndless = false
		if TF_MVMState and TF_MVMState.Get then
			waveCurrent = math.max(1, tonumber(TF_MVMState:Get("wave_current", 1)) or 1)
			waveTotal = math.max(0, tonumber(TF_MVMState:Get("wave_total", waveCurrent)) or waveCurrent)
			isEndless = TF_MVMState:Get("is_endless", false) and true or false
		end
		MvMWave.text = isEndless
			and ("WAVE " .. tostring(waveCurrent) .. " / ENDLESS")
			or ("WAVE " .. tostring(waveCurrent) .. " / " .. tostring(math.max(waveCurrent, waveTotal)))
		draw.Text(MvMWave)

		ServerName.text = tf_lang.GetFormatted("#Scoreboard_Server", GetHostName())
		ServerName.pos = {MvMScoreboardRes.serverLeftX * Scale, MvMScoreboardRes.serverLeftY * Scale}
		draw.Text(ServerName)

		ServerTimeLeft.text = "PLAYERS: " .. tostring(humanCount)
		ServerTimeLeft.pos = {MvMScoreboardRes.serverRightX * Scale, MvMScoreboardRes.serverRightY * Scale}
		draw.Text(ServerTimeLeft)

		Spectators.text = "Credits: " .. tostring(credits)
		Spectators.pos = {MvMScoreboardRes.creditsX * Scale, MvMScoreboardRes.creditsY * Scale}
		Spectators.color = Colors.TanLight
		draw.Text(Spectators)
		return
	end

	local num, tab, tex
	local playerteam = LocalPlayer():Team()
	local playerclass = LocalPlayer():GetPlayerClassTable()
	
	surface.SetDrawColor(255, 255, 255, 255)
	
	-- BLU score panel
	surface.SetTexture(score_panel_blue_bg)
	surface.DrawTexturedRect(-2*Scale, 9*Scale, 304*Scale, 71*Scale)
	
	BlueTeamName.text = tf_lang.GetRaw("#TF_ScoreBoard_Blue")
	draw.Text(BlueTeamName)
	
	BlueTeamScoreShadow.text = team.GetScore(TEAM_BLU)
	draw.Text(BlueTeamScoreShadow)
	
	BlueTeamScore.text = team.GetScore(TEAM_BLU)
	draw.Text(BlueTeamScore)
	
	num = #team.GetPlayers(TEAM_BLU)
	if num > 0 then
		if num == 1 then
			BlueTeamPlayerCount.text = tf_lang.GetFormatted("#TF_ScoreBoard_Player", num)
		else
			BlueTeamPlayerCount.text = tf_lang.GetFormatted("#TF_ScoreBoard_Players", num)
		end
			
		draw.Text(BlueTeamPlayerCount)
	end
	
	-- RED score panel
	surface.SetTexture(score_panel_red_bg)
	surface.DrawTexturedRect(296*Scale, 9*Scale, 304*Scale, 71*Scale)
	
	RedTeamName.text = tf_lang.GetRaw("#TF_ScoreBoard_Red")
	draw.Text(RedTeamName)
	
	RedTeamScoreShadow.text = team.GetScore(TEAM_RED)
	draw.Text(RedTeamScoreShadow)
	
	RedTeamScore.text = team.GetScore(TEAM_RED)
	draw.Text(RedTeamScore)
	
	num = #team.GetPlayers(TEAM_RED)
	if num > 0 then
		if num == 1 then
			RedTeamPlayerCount.text = tf_lang.GetFormatted("#TF_ScoreBoard_Player", num)
		else
			RedTeamPlayerCount.text = tf_lang.GetFormatted("#TF_ScoreBoard_Players", num)
		end
			
		draw.Text(RedTeamPlayerCount)
	end
	
	-- Main panel
	tf_draw.BorderPanel(tournament_panel_brown, 1.5*Scale, 60*Scale, 595.5*Scale, 385*Scale, 23, 23, 8*Scale, 8*Scale)
	
	surface.SetDrawColor(0, 0, 0, 153)
	surface.DrawRect(299*Scale, 70*Scale, 2*Scale, 292*Scale)
	surface.DrawRect(10*Scale, 372*Scale, 580*Scale, 70*Scale)
	
	surface.SetDrawColor(team.GetColor(playerteam))
	surface.DrawRect(115*Scale, 397*Scale, 465*Scale, 1*Scale)
	
	ServerName.text = tf_lang.GetFormatted("#Scoreboard_Server", GetHostName())
	draw.Text(ServerName)
	
	--"#Scoreboard_TimeLeft"
	--"#Scoreboard_TimeLeftNoHours"
	--"#Scoreboard_NoTimeLimit"
	ServerTimeLeft.text = tf_lang.GetRaw("#Scoreboard_NoTimeLimit")
	draw.Text(ServerTimeLeft)
	
	tab = team.GetPlayers(TEAM_SPECTATOR)
	local tab2 = team.GetPlayers(TEAM_NEUTRAL)
	-- table.Add(tab, team.GetPlayers(TEAM_NEUTRAL))
	num = #tab
	if num > 0 then
		local t = {}
		for k,v in ipairs(tab) do
			t[k] = v:GetName()
		end
		t = string.Implode(", ", t)
		
		if num == 1 then
			Spectators.text = tf_lang.GetFormatted("#ScoreBoard_Spectator", num, t)
		else
			Spectators.text = tf_lang.GetFormatted("#ScoreBoard_Spectators", num, t)
		end
		
		draw.Text(Spectators)
	end
	
	
	tab2 = team.GetPlayers(TEAM_NEUTRAL)
	num2 = #tab2
	tab3 = team.GetPlayers(TEAM_FRIENDLY)
	num3 = #tab3
	tab4 = team.GetPlayers(TEAM_GREEN)
	num4 = #tab4
	tab5 = team.GetPlayers(TEAM_YELLOW)
	num5 = #tab5

	if num > 0 then
		SpectatorsInQueue.pos = {115*Scale, 358*Scale}
	else
		SpectatorsInQueue.pos = {111*Scale, 367*Scale}
	end

	if num2 > 0 then
		local t = {}
		for k,v in ipairs(tab2) do
			t[k] = v:GetName()
		end
		t = string.Implode(", ", t) 
		
		--[[if num == 1 then
			SpectatorsInQueue.text = tf_lang.GetFormatted("#TF_Arena_ScoreBoard_Spectator", num, t)
		else
			SpectatorsInQueue.text = tf_lang.GetFormatted("#TF_Arena_ScoreBoard_Spectators", num, t)
		end]]

		if num2 == 1 then
			SpectatorsInQueue.text = "1 neutral: "..t
		else
			SpectatorsInQueue.text = "Neutral: "..t
		end
		draw.Text(SpectatorsInQueue)
	end
	if num3 > 0 then
		local t = {}
		for k,v in ipairs(tab3) do
			t[k] = v:GetName()
		end
		t = string.Implode(", ", t) 
		
		--[[if num == 1 then
			SpectatorsInQueue.text = tf_lang.GetFormatted("#TF_Arena_ScoreBoard_Spectator", num, t)
		else
			SpectatorsInQueue.text = tf_lang.GetFormatted("#TF_Arena_ScoreBoard_Spectators", num, t)
		end]]

		if num3 == 1 then
			SpectatorsInQueue2.text = "1 friendly: "..t
		else
			SpectatorsInQueue2.text = "Friendly: "..t
		end
		draw.Text(SpectatorsInQueue2)
	end
	
	PlayerName.color = team.GetColor(playerteam)
	PlayerName.text = LocalPlayer():GetName()
	draw.Text(PlayerName)
	
	local num = LocalPlayer():Frags()
	if num <= 1 then
		PlayerScore.text = tf_lang.GetFormatted("#TF_ScoreBoard_Point", LocalPlayer():Frags())
	else
		PlayerScore.text = tf_lang.GetFormatted("#TF_ScoreBoard_Points", LocalPlayer():Frags())
	end
	draw.Text(PlayerScore)
end

function PANEL:UpdateScoreboard()
	
end

vgui.Register("TFScoreboard", PANEL)

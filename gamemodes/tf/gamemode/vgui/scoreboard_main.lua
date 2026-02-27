
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

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:SetVisible(false)
	self.IsMvM = string.find(game.GetMap(), "mvm_", 1, true) ~= nil
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
	self.InfectedPlayerList = vgui.Create("TFScoreboardPlayerList", self)
	self.InfectedPlayerList:SetTeam(TEAM_INFECTED)	
	
	self.LocalStats = vgui.Create("TFScoreboardLocalStats", self)
end

function PANEL:PerformLayout()
	if not IsValid(LocalPlayer()) then return end
	
	self:SetPos(W*0.5 - 300*Scale, 16*Scale)
	self:SetSize(600*Scale, 448*Scale)

	if self.IsMvM then
		self.BluePlayerList:SetPos(8*Scale, 86*Scale)
		self.BluePlayerList:SetSize(584*Scale, 260*Scale)
		self.RedPlayerList:SetVisible(false)
		self.InfectedPlayerList:SetVisible(false)
	else
		self.BluePlayerList:SetPos(5*Scale, 72*Scale)
		self.BluePlayerList:SetSize(290*Scale, 280*Scale)
		self.InfectedPlayerList:SetPos(5*Scale, 72*Scale)
		self.InfectedPlayerList:SetSize(290*Scale, 280*Scale)
		self.RedPlayerList:SetPos(305*Scale, 72*Scale)
		self.RedPlayerList:SetSize(290*Scale, 280*Scale)
	end
	
	self.LocalStats:SetPos(0, 395*Scale)
	self.LocalStats:SetSize(600*Scale, 448*Scale)
end

function PANEL:Paint()
	if self.IsMvM then
		local humanCount = #team.GetPlayers(TEAM_RED)
		local credits = LocalPlayer():GetNWInt("TF_MVM_Credits", 0)

		surface.SetDrawColor(255, 255, 255, 255)
		tf_draw.BorderPanel(tournament_panel_brown, 1.5*Scale, 8*Scale, 595.5*Scale, 375*Scale, 23, 23, 8*Scale, 8*Scale)
		surface.SetDrawColor(0, 0, 0, 153)
		surface.DrawRect(9*Scale, 74*Scale, 582*Scale, 1*Scale)
		surface.DrawRect(10*Scale, 355*Scale, 580*Scale, 1*Scale)

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

		draw.Text(MvMTitle)
		draw.Text(MvMDifficulty)
		draw.Text(MvMDefenders)

		local waveCurrent = 1
		local waveTotal = 1
		if TF_MVMState and TF_MVMState.Get then
			waveCurrent = math.max(1, tonumber(TF_MVMState:Get("wave_current", 1)) or 1)
			waveTotal = math.max(waveCurrent, tonumber(TF_MVMState:Get("wave_total", waveCurrent)) or waveCurrent)
		end
		MvMWave.text = "WAVE " .. tostring(waveCurrent) .. " / " .. tostring(waveTotal)
		draw.Text(MvMWave)

		ServerName.text = tf_lang.GetFormatted("#Scoreboard_Server", GetHostName())
		ServerName.pos = {11*Scale, 18*Scale}
		draw.Text(ServerName)

		ServerTimeLeft.text = "PLAYERS: " .. tostring(humanCount)
		ServerTimeLeft.pos = {585*Scale, 18*Scale}
		draw.Text(ServerTimeLeft)

		Spectators.text = "Credits: " .. tostring(credits)
		Spectators.pos = {16*Scale, 369*Scale}
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

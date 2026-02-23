
local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local NameLabel = {
	text="Name",
	font="ScoreboardSmallest",
	pos={26*Scale, 7*Scale},
	xalign=TEXT_ALIGN_LEFT,
	yalign=TEXT_ALIGN_CENTER,
}

local ClassLabel = {
	text="Class",
	font="ScoreboardSmallest",
	pos={122*Scale, 7*Scale},
	xalign=TEXT_ALIGN_LEFT,
	yalign=TEXT_ALIGN_CENTER,
}

local ScoreLabel = {
	text="Score",
	font="ScoreboardSmallest",
	pos={190*Scale, 7*Scale},
	xalign=TEXT_ALIGN_RIGHT,
	yalign=TEXT_ALIGN_CENTER,
}

local DamageLabel = {
	text="Damage",
	font="ScoreboardSmallest",
	pos={232*Scale, 7*Scale},
	xalign=TEXT_ALIGN_RIGHT,
	yalign=TEXT_ALIGN_CENTER,
}

local MoneyLabel = {
	text="Money",
	font="ScoreboardSmallest",
	pos={266*Scale, 7*Scale},
	xalign=TEXT_ALIGN_RIGHT,
	yalign=TEXT_ALIGN_CENTER,
}

local PingLabel = {
	text="Ping",
	font="ScoreboardSmallest",
	pos={296*Scale, 7*Scale},
	xalign=TEXT_ALIGN_RIGHT,
	yalign=TEXT_ALIGN_CENTER,
}

local PlayerName = {
	text="",
	font="TFDefault",
	pos={26*Scale, 7*Scale},
	xalign=TEXT_ALIGN_LEFT,
	yalign=TEXT_ALIGN_CENTER,
}
local PlayerClass = {
	text="",
	font="TFDefault",
	pos={122*Scale, 7*Scale},
	xalign=TEXT_ALIGN_LEFT,
	yalign=TEXT_ALIGN_CENTER,
}
local PlayerScore = {
	text="",
	font="TFDefault",
	pos={190*Scale, 7*Scale},
	xalign=TEXT_ALIGN_RIGHT,
	yalign=TEXT_ALIGN_CENTER,
}
local PlayerDamage = {
	text="",
	font="TFDefault",
	pos={232*Scale, 7*Scale},
	xalign=TEXT_ALIGN_RIGHT,
	yalign=TEXT_ALIGN_CENTER,
}
local PlayerMoney = {
	text="",
	font="TFDefault",
	pos={266*Scale, 7*Scale},
	xalign=TEXT_ALIGN_RIGHT,
	yalign=TEXT_ALIGN_CENTER,
}
local PlayerPing = {
	text="",
	font="TFDefault",
	pos={296*Scale, 7*Scale},
	xalign=TEXT_ALIGN_RIGHT,
	yalign=TEXT_ALIGN_CENTER,
}

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:SetVisible(true)
	
	self.PlayerTeam = TEAM_RED
end

function PANEL:SetTeam(t)
	self.PlayerTeam = t
end

function PANEL:PerformLayout()
	local ypos = math.floor(23*Scale)
end

function PANEL:Paint()
	local w, h = self:GetSize()
	surface.SetDrawColor(255, 255, 255, 255)
	
	surface.DrawLine(3*Scale, 11.25*Scale, w-3.5*Scale, 11.25*Scale)
	draw.Text(NameLabel)
	draw.Text(ClassLabel)
	draw.Text(ScoreLabel)
	draw.Text(DamageLabel)
	draw.Text(MoneyLabel)
	draw.Text(PingLabel)
	
	local ypos = math.floor(23*Scale)
	
	local col = team.GetColor(self.PlayerTeam)
	local players = team.GetPlayers(self.PlayerTeam)
	
	table.sort(players, function(a, b) return a:Frags() > b:Frags() end)
	
	for i,pl in ipairs(players) do
		local c = pl:GetPlayerClassTable()
		local d = not pl:Alive()
		
		if pl == LocalPlayer() then
			surface.SetDrawColor(Colors.HudPanelBorder)
			surface.DrawRect(3*Scale, ypos-math.floor(11*Scale), w-math.floor(6*Scale), math.floor(21*Scale))
			surface.SetDrawColor(255, 255, 255, 255)
		end
		if d then
			col.a = 127
		else
			col.a = 255
		end
		PlayerName.text = pl:GetName()
		PlayerName.color = col
		PlayerName.pos[2] = ypos
		draw.Text(PlayerName)

		PlayerClass.text = string.upper((pl:GetPlayerClass() or "?"):sub(1, 8))
		PlayerClass.color = col
		PlayerClass.pos[2] = ypos
		draw.Text(PlayerClass)

		PlayerScore.text = tostring(pl:Frags())
		PlayerScore.color = col
		PlayerScore.pos[2] = ypos
		draw.Text(PlayerScore)

		PlayerDamage.text = tostring(pl:Frags() * 100)
		PlayerDamage.color = col
		PlayerDamage.pos[2] = ypos
		draw.Text(PlayerDamage)

		PlayerMoney.text = tostring(pl:GetNWInt("TF_MVM_Credits", 0))
		PlayerMoney.color = col
		PlayerMoney.pos[2] = ypos
		draw.Text(PlayerMoney)

		PlayerPing.text = pl:IsBot() and "BOT" or tostring(pl:Ping())
		PlayerPing.color = col
		PlayerPing.pos[2] = ypos
		draw.Text(PlayerPing)
		
		ypos = ypos + math.floor(22*Scale) 
	end
	
end
 
vgui.Register("TFMVMScoreboardPlayerList", PANEL)

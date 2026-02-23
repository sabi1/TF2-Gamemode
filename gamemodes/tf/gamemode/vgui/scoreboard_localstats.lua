
local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local KillsLabel = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={175*Scale, 10*Scale},
}
local DeathsLabel = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={175*Scale, 20*Scale},
}
local AssistsLabel = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={175*Scale, 30*Scale},
}
local DestructionLabel = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={175*Scale, 40*Scale},
}
local CapturesLabel = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={300*Scale, 10*Scale},
}
local DefensesLabel = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={300*Scale, 20*Scale},
}
local DominationLabel = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={300*Scale, 30*Scale},
}
local RevengeLabel = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={300*Scale, 40*Scale},
}
local HealingLabel = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={421*Scale, 10*Scale},
}
local InvulnLabel = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={421*Scale, 20*Scale},
}
local TeleportsLabel = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={421*Scale, 30*Scale},
}
local HeadshotsLabel = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={421*Scale, 40*Scale},
}
local BackstabsLabel = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={555*Scale, 10*Scale},
}
local BonusLabel = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={555*Scale, 20*Scale},
}

local Kills = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_LEFT,yalign=TEXT_ALIGN_CENTER,
	pos={180*Scale, 10*Scale},
}
local Deaths = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_LEFT,yalign=TEXT_ALIGN_CENTER,
	pos={180*Scale, 20*Scale},
}
local Assists = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_LEFT,yalign=TEXT_ALIGN_CENTER,
	pos={180*Scale, 30*Scale},
}
local Destruction = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_LEFT,yalign=TEXT_ALIGN_CENTER,
	pos={180*Scale, 40*Scale},
}
local Captures = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_LEFT,yalign=TEXT_ALIGN_CENTER,
	pos={305*Scale, 10*Scale},
}
local Defenses = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_LEFT,yalign=TEXT_ALIGN_CENTER,
	pos={305*Scale, 20*Scale},
}
local Domination = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_LEFT,yalign=TEXT_ALIGN_CENTER,
	pos={305*Scale, 30*Scale},
}
local Revenge = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_LEFT,yalign=TEXT_ALIGN_CENTER,
	pos={305*Scale, 40*Scale},
}
local Healing = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_LEFT,yalign=TEXT_ALIGN_CENTER,
	pos={425*Scale, 10*Scale},
}
local Invuln = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_LEFT,yalign=TEXT_ALIGN_CENTER,
	pos={425*Scale, 20*Scale},
}
local Teleports = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_LEFT,yalign=TEXT_ALIGN_CENTER,
	pos={425*Scale, 30*Scale},
}
local Headshots = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_LEFT,yalign=TEXT_ALIGN_CENTER,
	pos={425*Scale, 40*Scale},
}
local Backstabs = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_LEFT,yalign=TEXT_ALIGN_CENTER,
	pos={560*Scale, 10*Scale},
}
local Bonus = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_LEFT,yalign=TEXT_ALIGN_CENTER,
	pos={560*Scale, 20*Scale},
}

local MapName = {
	text="",font="ScoreboardMedium",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={580*Scale, 32*Scale},
}
local GameType = {
	text="",font="ScoreboardVerySmall",color=Colors.TanLight,xalign=TEXT_ALIGN_RIGHT,yalign=TEXT_ALIGN_CENTER,
	pos={580*Scale, 42*Scale},
}

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:SetVisible(true)
end

function PANEL:Paint()
	local w, h = self:GetSize()
	local isMvM = string.find(game.GetMap(), "mvm_", 1, true) ~= nil
	
	if isMvM then
		KillsLabel.text = "Kills"
		DeathsLabel.text = "Deaths"
		AssistsLabel.text = "Assists"
		DestructionLabel.text = "Damage"
		CapturesLabel.text = "Credits"
		DefensesLabel.text = "Support"
		DominationLabel.text = "Revives"
		RevengeLabel.text = "Wave"
		HealingLabel.text = "Healing"
		InvulnLabel.text = "Buybacks"
		TeleportsLabel.text = "Upgrades"
		HeadshotsLabel.text = "Headshots"
		BackstabsLabel.text = "Backstabs"
		BonusLabel.text = "Bonus"
	else
		KillsLabel.text = tf_lang.GetRaw("#TF_ScoreBoard_KillsLabel")
		DeathsLabel.text = tf_lang.GetRaw("#TF_ScoreBoard_DeathsLabel")
		AssistsLabel.text = tf_lang.GetRaw("#TF_ScoreBoard_AssistsLabel")
		DestructionLabel.text = tf_lang.GetRaw("#TF_ScoreBoard_DestructionLabel")
		CapturesLabel.text = tf_lang.GetRaw("#TF_ScoreBoard_CapturesLabel")
		DefensesLabel.text = tf_lang.GetRaw("#TF_ScoreBoard_DefensesLabel")
		DominationLabel.text = tf_lang.GetRaw("#TF_ScoreBoard_DominationLabel")
		RevengeLabel.text = tf_lang.GetRaw("#TF_ScoreBoard_RevengeLabel")
		HealingLabel.text = tf_lang.GetRaw("#TF_ScoreBoard_HealingLabel")
		InvulnLabel.text = tf_lang.GetRaw("#TF_ScoreBoard_InvulnLabel")
		TeleportsLabel.text = tf_lang.GetRaw("#TF_ScoreBoard_TeleportsLabel")
		HeadshotsLabel.text = tf_lang.GetRaw("#TF_ScoreBoard_HeadshotsLabel")
		BackstabsLabel.text = tf_lang.GetRaw("#TF_ScoreBoard_BackstabsLabel")
		BonusLabel.text = tf_lang.GetRaw("#TF_ScoreBoard_BonusLabel")
	end
	
	draw.Text(KillsLabel)
	draw.Text(DeathsLabel)
	draw.Text(AssistsLabel)
	draw.Text(DestructionLabel)
	draw.Text(CapturesLabel)
	draw.Text(DefensesLabel)
	draw.Text(DominationLabel)
	draw.Text(RevengeLabel)
	draw.Text(HealingLabel)
	draw.Text(InvulnLabel)
	draw.Text(TeleportsLabel)
	draw.Text(HeadshotsLabel)
	draw.Text(BackstabsLabel)
	draw.Text(BonusLabel)
	
	Kills.text = LocalPlayer():Kills()
	Deaths.text = LocalPlayer():Deaths()
	Assists.text = LocalPlayer():Assists()
	if isMvM then
		Destruction.text = LocalPlayer():Frags() * 100
		Captures.text = LocalPlayer():GetNWInt("TF_MVM_Credits", 0)
		Defenses.text = LocalPlayer():Assists()
		Domination.text = LocalPlayer():Revenges()
		local wave = 1
		if WaveManager and WaveManager.CurrentWave then
			wave = math.max(1, tonumber(WaveManager.CurrentWave) or 1)
		end
		Revenge.text = wave
	else
		Destruction.text = LocalPlayer():Destructions()
		Captures.text = LocalPlayer():Captures()
		Defenses.text = LocalPlayer():Defenses()
		Domination.text = LocalPlayer():Dominations()
		Revenge.text = LocalPlayer():Revenges()
	end
	Healing.text = LocalPlayer():Healing()
	if isMvM then
		Invuln.text = 0
		Teleports.text = 0
	else
		Invuln.text = LocalPlayer():Invulns()
		Teleports.text = LocalPlayer():Teleports()
	end
	Headshots.text = LocalPlayer():Headshots()
	Backstabs.text = LocalPlayer():Backstabs()
	Bonus.text = LocalPlayer():Bonus()
	
	draw.Text(Kills)
	draw.Text(Deaths)
	draw.Text(Assists)
	draw.Text(Destruction)
	draw.Text(Captures)
	draw.Text(Defenses)
	draw.Text(Domination)
	draw.Text(Revenge)
	draw.Text(Healing)
	draw.Text(Invuln)
	draw.Text(Teleports)
	draw.Text(Headshots)
	draw.Text(Backstabs)
	draw.Text(Bonus)
	
	MapName.text = game.GetMap()
	if isMvM then
		GameType.text = "Mann vs Machine"
	else
		GameType.text = ""
	end
	draw.Text(MapName)
	draw.Text(GameType)
end

vgui.Register("TFScoreboardLocalStats", PANEL)

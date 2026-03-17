
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
	
	local lp = LocalPlayer()
	if not IsValid(lp) then return end
	local function safeStat(methodName, fallback)
		local fn = lp[methodName]
		if isfunction(fn) then
			local ok, value = pcall(fn, lp)
			if ok and value ~= nil then
				return value
			end
		end
		return fallback or 0
	end

	Kills.text = safeStat("Kills", safeStat("Frags", 0))
	Deaths.text = safeStat("Deaths", 0)
	Assists.text = safeStat("Assists", 0)
	if isMvM then
		Destruction.text = safeStat("Frags", 0) * 100
		Captures.text = lp:GetNWInt("TF_MVM_Credits", 0)
		Defenses.text = safeStat("Assists", 0)
		Domination.text = safeStat("Revenges", 0)
		local wave = 1
		if TF_MVMState and TF_MVMState.Get then
			wave = math.max(1, tonumber(TF_MVMState:Get("wave_current", 1)) or 1)
		end
		Revenge.text = wave
	else
		Destruction.text = safeStat("Destructions", 0)
		Captures.text = safeStat("Captures", 0)
		Defenses.text = safeStat("Defenses", 0)
		Domination.text = safeStat("Dominations", 0)
		Revenge.text = safeStat("Revenges", 0)
	end
	Healing.text = safeStat("Healing", 0)
	if isMvM then
		Invuln.text = 0
		Teleports.text = 0
	else
		Invuln.text = safeStat("Invulns", 0)
		Teleports.text = safeStat("Teleports", 0)
	end
	Headshots.text = safeStat("Headshots", 0)
	Backstabs.text = safeStat("Backstabs", 0)
	Bonus.text = safeStat("Bonus", 0)
	
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

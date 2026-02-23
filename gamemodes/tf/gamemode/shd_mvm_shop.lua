if SERVER then
	AddCSLuaFile()
	util.AddNetworkString("TF_MVMShop_Open")
	util.AddNetworkString("TF_MVMShop_Buy")
	util.AddNetworkString("TF_MVMShop_Respec")
	util.AddNetworkString("TF_MVMShop_RequestOpen")
end

TF_MVMShop = TF_MVMShop or {}

TF_MVMShop.StartingCredits = 600
TF_MVMShop.KillCredits = 25

TF_MVMShop.Upgrades = {
	{
		id = "max_health",
		name = "Max Health",
		description = "+25 max HP per level",
		costs = { 150, 250, 400, 600 }
	},
	{
		id = "move_speed",
		name = "Move Speed",
		description = "+10% speed per level",
		costs = { 200, 350, 500 }
	},
	{
		id = "damage_bonus",
		name = "Damage Bonus",
		description = "+15% outgoing damage per level",
		costs = { 200, 325, 500 }
	},
	{
		id = "resistance",
		name = "Damage Resistance",
		description = "-10% incoming damage per level",
		costs = { 250, 400, 600 }
	},
	{
		id = "fire_rate",
		name = "Fire Rate",
		description = "+10% fire speed per level",
		costs = { 200, 350, 550 }
	},
	{
		id = "heal_on_kill",
		name = "Heal On Kill",
		description = "Restore 15 HP per level on kill",
		costs = { 150, 275, 450 }
	}
}

local upgradesById = {}
for _, upgrade in ipairs(TF_MVMShop.Upgrades) do
	upgradesById[upgrade.id] = upgrade
end

local function IsMvMMap()
	return string.find(game.GetMap(), "mvm_", 1, true) ~= nil
end

function TF_MVMShop:IsEnabledFor(ply)
	return IsMvMMap() and IsValid(ply) and ply:IsPlayer() and not ply.TFBot
end

function TF_MVMShop:GetLevels(ply)
	ply.TF_MVMShopLevels = ply.TF_MVMShopLevels or {}
	return ply.TF_MVMShopLevels
end

function TF_MVMShop:GetLevel(ply, id)
	local levels = self:GetLevels(ply)
	return tonumber(levels[id] or 0) or 0
end

function TF_MVMShop:SetLevel(ply, id, level)
	local levels = self:GetLevels(ply)
	levels[id] = math.max(0, tonumber(level) or 0)
end

function TF_MVMShop:GetCredits(ply)
	return math.max(0, ply:GetNWInt("TF_MVM_Credits", 0))
end

function TF_MVMShop:SetCredits(ply, amount)
	ply:SetNWInt("TF_MVM_Credits", math.max(0, math.floor(tonumber(amount) or 0)))
end

function TF_MVMShop:AddCredits(ply, amount)
	self:SetCredits(ply, self:GetCredits(ply) + (tonumber(amount) or 0))
end

function TF_MVMShop:GetMaxLevel(id)
	local upgrade = upgradesById[id]
	return upgrade and #upgrade.costs or 0
end

function TF_MVMShop:GetNextCost(ply, id)
	local upgrade = upgradesById[id]
	if not upgrade then return nil end
	local level = self:GetLevel(ply, id)
	return upgrade.costs[level + 1]
end

function TF_MVMShop:CanBuy(ply, id)
	if not self:IsEnabledFor(ply) then
		return false, "not_available"
	end

	local upgrade = upgradesById[id]
	if not upgrade then
		return false, "invalid_upgrade"
	end

	local level = self:GetLevel(ply, id)
	if level >= #upgrade.costs then
		return false, "maxed"
	end

	local cost = upgrade.costs[level + 1]
	if self:GetCredits(ply) < cost then
		return false, "no_credits"
	end

	return true
end

local function GetBaseClassSpeed(ply)
	local classTable = ply.GetPlayerClassTable and ply:GetPlayerClassTable() or nil
	local speed = classTable and classTable.Speed or nil
	return tonumber(speed) or 300
end

local function GetBaseClassHealth(ply)
	local classTable = ply.GetPlayerClassTable and ply:GetPlayerClassTable() or nil
	local hp = classTable and classTable.MaxHealth or nil
	return tonumber(hp) or 125
end

function TF_MVMShop:ApplyFireRate(ply)
	local level = self:GetLevel(ply, "fire_rate")
	local mult = math.max(0.25, 1 - (0.1 * level))

	for _, wep in ipairs(ply:GetWeapons()) do
		if IsValid(wep) and wep.Primary and isnumber(wep.Primary.Delay) then
			if not wep.TF_MVMShopBaseDelay then
				wep.TF_MVMShopBaseDelay = wep.Primary.Delay
			end
			wep.Primary.Delay = math.max(0.02, wep.TF_MVMShopBaseDelay * mult)
		end
	end
end

function TF_MVMShop:ApplyUpgrades(ply)
	if not self:IsEnabledFor(ply) then return end

	local speedLevel = self:GetLevel(ply, "move_speed")
	local healthLevel = self:GetLevel(ply, "max_health")

	local speedMul = 1 + (0.1 * speedLevel)
	local newSpeed = math.floor(GetBaseClassSpeed(ply) * speedMul)
	if ply.SetClassSpeed then
		ply:SetClassSpeed(newSpeed)
	else
		ply:SetWalkSpeed(newSpeed)
		ply:SetRunSpeed(newSpeed)
	end

	local newMaxHealth = GetBaseClassHealth(ply) + (25 * healthLevel)
	ply:SetMaxHealth(newMaxHealth)
	if ply:Health() > newMaxHealth then
		ply:SetHealth(newMaxHealth)
	end

	self:ApplyFireRate(ply)
end

function TF_MVMShop:BuildSyncPayload(ply)
	local list = {}
	for _, upgrade in ipairs(self.Upgrades) do
		local level = self:GetLevel(ply, upgrade.id)
		list[#list + 1] = {
			id = upgrade.id,
			name = upgrade.name,
			description = upgrade.description,
			level = level,
			maxLevel = #upgrade.costs,
			nextCost = upgrade.costs[level + 1] or 0
		}
	end

	return {
		credits = self:GetCredits(ply),
		upgrades = list
	}
end

if SERVER then
	local function OpenShopFor(ply)
		if not TF_MVMShop:IsEnabledFor(ply) then return end

		net.Start("TF_MVMShop_Open")
		net.WriteTable(TF_MVMShop:BuildSyncPayload(ply))
		net.Send(ply)
	end

	function TF_MVMShop:ResetPlayer(ply)
		ply.TF_MVMShopLevels = {}
		ply.TF_MVMShopSpent = 0
		self:SetCredits(ply, self.StartingCredits)
		self:ApplyUpgrades(ply)
	end

	hook.Add("PlayerInitialSpawn", "TF_MVMShop_InitialSpawn", function(ply)
		if not TF_MVMShop:IsEnabledFor(ply) then return end
		TF_MVMShop:ResetPlayer(ply)
	end)

	hook.Add("PlayerSpawn", "TF_MVMShop_PlayerSpawn", function(ply)
		if not TF_MVMShop:IsEnabledFor(ply) then return end
		timer.Simple(0, function()
			if not IsValid(ply) then return end
			if ply.TF_MVMShopSpent == nil then
				TF_MVMShop:ResetPlayer(ply)
				return
			end
			TF_MVMShop:ApplyUpgrades(ply)
		end)
	end)

	hook.Add("PlayerSwitchWeapon", "TF_MVMShop_WeaponSwitch", function(ply)
		if not TF_MVMShop:IsEnabledFor(ply) then return end
		TF_MVMShop:ApplyFireRate(ply)
	end)

	hook.Add("EntityTakeDamage", "TF_MVMShop_DamageHooks", function(target, dmginfo)
		local attacker = dmginfo:GetAttacker()
		if IsValid(attacker) and attacker:IsPlayer() and TF_MVMShop:IsEnabledFor(attacker) then
			local level = TF_MVMShop:GetLevel(attacker, "damage_bonus")
			if level > 0 then
				dmginfo:ScaleDamage(1 + (0.15 * level))
			end
		end

		if IsValid(target) and target:IsPlayer() and TF_MVMShop:IsEnabledFor(target) then
			local level = TF_MVMShop:GetLevel(target, "resistance")
			if level > 0 then
				dmginfo:ScaleDamage(math.max(0.15, 1 - (0.1 * level)))
			end
		end
	end)

	hook.Add("PlayerDeath", "TF_MVMShop_KillRewardsAndHeal", function(victim, _, attacker)
		if not IsValid(victim) then return end
		if not victim.TFBot and victim:Team() ~= TEAM_BLU then return end

		if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim and TF_MVMShop:IsEnabledFor(attacker) then
			TF_MVMShop:AddCredits(attacker, TF_MVMShop.KillCredits)

			local healLevel = TF_MVMShop:GetLevel(attacker, "heal_on_kill")
			if healLevel > 0 and attacker:Alive() then
				local heal = healLevel * 15
				attacker:SetHealth(math.min(attacker:Health() + heal, attacker:GetMaxHealth()))
			end
		end
	end)

	hook.Add("OnNPCKilled", "TF_MVMShop_NPCKillRewards", function(_, attacker)
		if IsValid(attacker) and attacker:IsPlayer() and TF_MVMShop:IsEnabledFor(attacker) then
			TF_MVMShop:AddCredits(attacker, TF_MVMShop.KillCredits)
		end
	end)

	local function IsUpgradeStationNearby(ply)
		local eyePos = ply:EyePos()
		for _, ent in ipairs(ents.FindInSphere(eyePos, 160)) do
			if IsValid(ent) then
				local class = ""
				local name = ""
				if ent.GetClass then
					class = string.lower(ent:GetClass() or "")
				end
				if ent.GetName then
					name = string.lower(ent:GetName() or "")
				end
				if string.find(class, "upgrade", 1, true) or string.find(name, "upgrade", 1, true) then
					return true
				end
			end
		end
		return false
	end

	hook.Add("KeyPress", "TF_MVMShop_OpenOnUse", function(ply, key)
		if key ~= IN_USE then return end
		if not TF_MVMShop:IsEnabledFor(ply) then return end
		if not IsUpgradeStationNearby(ply) then return end
		OpenShopFor(ply)
	end)

	concommand.Add("tf_mvm_shop", function(ply)
		if not TF_MVMShop:IsEnabledFor(ply) then return end
		OpenShopFor(ply)
	end)

	net.Receive("TF_MVMShop_RequestOpen", function(_, ply)
		if not TF_MVMShop:IsEnabledFor(ply) then return end
		OpenShopFor(ply)
	end)

	net.Receive("TF_MVMShop_Buy", function(_, ply)
		if not TF_MVMShop:IsEnabledFor(ply) then return end

		local id = net.ReadString()
		local canBuy, reason = TF_MVMShop:CanBuy(ply, id)
		if not canBuy then
			if reason == "no_credits" then
				ply:ChatPrint("[MvM Shop] Not enough credits.")
			elseif reason == "maxed" then
				ply:ChatPrint("[MvM Shop] Upgrade is already maxed.")
			end
			OpenShopFor(ply)
			return
		end

		local cost = TF_MVMShop:GetNextCost(ply, id)
		if not cost then return end

		TF_MVMShop:AddCredits(ply, -cost)
		TF_MVMShop:SetLevel(ply, id, TF_MVMShop:GetLevel(ply, id) + 1)
		ply.TF_MVMShopSpent = (ply.TF_MVMShopSpent or 0) + cost

		TF_MVMShop:ApplyUpgrades(ply)
		OpenShopFor(ply)
	end)

	net.Receive("TF_MVMShop_Respec", function(_, ply)
		if not TF_MVMShop:IsEnabledFor(ply) then return end

		local spent = math.max(0, math.floor(tonumber(ply.TF_MVMShopSpent) or 0))
		ply.TF_MVMShopLevels = {}
		ply.TF_MVMShopSpent = 0
		TF_MVMShop:AddCredits(ply, spent)
		TF_MVMShop:ApplyUpgrades(ply)
		OpenShopFor(ply)
	end)
end

if CLIENT then
	local function IsMvMMap()
		return string.find(game.GetMap(), "mvm_", 1, true) ~= nil
	end

	local function IsNearUpgradeStationClient()
		local lp = LocalPlayer()
		if not IsValid(lp) then return false end

		local eyePos = lp:EyePos()
		for _, ent in ipairs(ents.FindInSphere(eyePos, 170)) do
			if IsValid(ent) then
				local class = ""
				local name = ""
				if ent.GetClass then
					class = string.lower(ent:GetClass() or "")
				end
				if ent.GetName then
					name = string.lower(ent:GetName() or "")
				end
				if string.find(class, "upgrade", 1, true) or string.find(name, "upgrade", 1, true) then
					return true
				end
			end
		end
		return false
	end

	local function CloseUpgradePrompt()
		if IsValid(TF_MVMShopPrompt) then
			TF_MVMShopPrompt:Remove()
			TF_MVMShopPrompt = nil
		end
	end

	local function OpenUpgradePrompt()
		if IsValid(TF_MVMShopPrompt) then return end

		local frame = vgui.Create("DFrame")
		TF_MVMShopPrompt = frame
		frame:SetTitle("")
		frame:SetSize(300, 76)
		frame:Center()
		frame:SetDraggable(false)
		frame:ShowCloseButton(false)
		frame:SetDeleteOnClose(true)
		frame:SetKeyboardInputEnabled(false)
		frame:SetMouseInputEnabled(false)
		frame.Paint = function(self, w, h)
			surface.SetDrawColor(24, 22, 19, 230)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(196, 176, 134, 255)
			surface.DrawOutlinedRect(0, 0, w, h, 2)
			draw.SimpleText("UPGRADE STATION", "Trebuchet24", w * 0.5, 24, Color(236, 221, 178), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("Press E to Upgrade", "DermaDefaultBold", w * 0.5, 50, Color(235, 220, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	hook.Add("Think", "TF_MVMShop_UpgradePromptThink", function()
		local lp = LocalPlayer()
		if not IsValid(lp) then return end

		if not IsMvMMap() or not lp:Alive() or GetConVarNumber("cl_drawhud") == 0 then
			CloseUpgradePrompt()
			return
		end

		if IsNearUpgradeStationClient() then
			OpenUpgradePrompt()
		else
			CloseUpgradePrompt()
		end
	end)

	hook.Add("ShutDown", "TF_MVMShop_UpgradePromptShutdown", function()
		CloseUpgradePrompt()
	end)

	local function OpenShop(data)
		if not istable(data) then return end
		if not data.upgrades then return end

		CloseUpgradePrompt()

		if IsValid(TF_MVMShopFrame) then
			TF_MVMShopFrame:Remove()
		end

		local frame = vgui.Create("DFrame")
		TF_MVMShopFrame = frame
		frame:SetTitle("MvM Upgrade Shop")
		frame:SetSize(720, 520)
		frame:Center()
		frame:MakePopup()
		frame:SetSizable(true)

		local creditsLabel = vgui.Create("DLabel", frame)
		creditsLabel:Dock(TOP)
		creditsLabel:DockMargin(10, 8, 10, 8)
		creditsLabel:SetFont("Trebuchet24")
		creditsLabel:SetTextColor(Color(245, 220, 120))
		creditsLabel:SetText("Credits: " .. tostring(data.credits or 0))
		creditsLabel:SetTall(30)

		local scroll = vgui.Create("DScrollPanel", frame)
		scroll:Dock(FILL)
		scroll:DockMargin(8, 0, 8, 8)

		for _, entry in ipairs(data.upgrades) do
			local pnl = scroll:Add("DPanel")
			pnl:Dock(TOP)
			pnl:DockMargin(0, 0, 0, 8)
			pnl:SetTall(76)

			local title = vgui.Create("DLabel", pnl)
			title:SetFont("DermaLarge")
			title:SetText(entry.name .. "  (" .. tostring(entry.level) .. "/" .. tostring(entry.maxLevel) .. ")")
			title:Dock(TOP)
			title:DockMargin(8, 6, 8, 0)
			title:SizeToContentsY()

			local desc = vgui.Create("DLabel", pnl)
			desc:SetFont("DermaDefault")
			desc:SetText(entry.description)
			desc:Dock(TOP)
			desc:DockMargin(8, 2, 8, 0)
			desc:SizeToContentsY()

			local buy = vgui.Create("DButton", pnl)
			buy:Dock(RIGHT)
			buy:DockMargin(8, 18, 8, 18)
			buy:SetWide(180)
			if (entry.nextCost or 0) > 0 then
				buy:SetText("Buy (" .. tostring(entry.nextCost) .. " cr)")
				buy:SetEnabled(true)
			else
				buy:SetText("MAXED")
				buy:SetEnabled(false)
			end
			buy.DoClick = function()
				net.Start("TF_MVMShop_Buy")
				net.WriteString(entry.id)
				net.SendToServer()
			end
		end

		local bottom = vgui.Create("DPanel", frame)
		bottom:Dock(BOTTOM)
		bottom:SetTall(44)
		bottom.Paint = nil

		local refresh = vgui.Create("DButton", bottom)
		refresh:Dock(LEFT)
		refresh:DockMargin(8, 6, 8, 6)
		refresh:SetWide(170)
		refresh:SetText("Refresh")
		refresh.DoClick = function()
			net.Start("TF_MVMShop_RequestOpen")
			net.SendToServer()
		end

		local respec = vgui.Create("DButton", bottom)
		respec:Dock(LEFT)
		respec:DockMargin(0, 6, 8, 6)
		respec:SetWide(170)
		respec:SetText("Respec (Refund)")
		respec.DoClick = function()
			net.Start("TF_MVMShop_Respec")
			net.SendToServer()
		end
	end

	net.Receive("TF_MVMShop_Open", function()
		local data = net.ReadTable()
		OpenShop(data)
	end)

	concommand.Add("tf_mvm_shop", function()
		net.Start("TF_MVMShop_RequestOpen")
		net.SendToServer()
	end)
end

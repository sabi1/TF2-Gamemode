local PANEL = {}

local W = ScrW()
local H = ScrH()
local Scale = H/480

local character_bg = {
	surface.GetTextureID("hud/character_blue_bg"),
	surface.GetTextureID("hud/character_red_bg"),
	surface.GetTextureID("hud/character_blue_bg"),
	surface.GetTextureID("hud/character_yellow_bg"),
	surface.GetTextureID("hud/character_green_bg"),
}
local character_default = surface.GetTextureID("hud/class_scoutred")
local character3d_default = "models/player/spy.mdl"
local convar = CreateClientConVar("cl_hud_playerclass_use_playermodel", "1", true, false)
local confirmConvar = CreateClientConVar("cl_hud_playerclass_playermodel_showed_confirm_dialog", "0", true, false)
local playermodelConfirmDialog
local classTextureCache = {}
local DISGUISE_PRIMARY_WEAPON_BY_CLASS = {
	scout = "models/weapons/c_models/c_scattergun.mdl",
	soldier = "models/weapons/w_models/w_rocketlauncher.mdl",
	pyro = "models/weapons/c_models/c_flamethrower/c_flamethrower.mdl",
	demo = "models/weapons/w_models/w_stickybomb_launcher.mdl",
	demoman = "models/weapons/w_models/w_stickybomb_launcher.mdl",
	heavy = "models/weapons/c_models/c_minigun/c_minigun.mdl",
	engineer = "models/weapons/c_models/c_shotgun/c_shotgun.mdl",
	medic = "models/weapons/c_models/c_syringegun/c_syringegun.mdl",
	sniper = "models/weapons/c_models/c_sniperrifle/c_sniperrifle.mdl",
	spy = "models/weapons/c_models/c_revolver/c_revolver.mdl",
}
local DISGUISE_SECONDARY_WEAPON_BY_CLASS = {
	scout = "models/weapons/c_models/c_pistol/c_pistol.mdl",
	soldier = "models/weapons/c_models/c_shotgun/c_shotgun.mdl",
	pyro = "models/weapons/c_models/c_shotgun/c_shotgun.mdl",
	demo = "models/weapons/w_models/w_grenadelauncher.mdl",
	demoman = "models/weapons/w_models/w_grenadelauncher.mdl",
	heavy = "models/weapons/c_models/c_shotgun/c_shotgun.mdl",
	engineer = "models/weapons/c_models/c_pistol/c_pistol.mdl",
	medic = "models/weapons/c_models/c_medigun/c_medigun.mdl",
	sniper = "models/weapons/c_models/c_smg/c_smg.mdl",
	spy = "models/weapons/c_models/c_revolver/c_revolver.mdl",
}
local DISGUISE_MELEE_WEAPON_BY_CLASS = {
	scout = "models/weapons/c_models/c_bat.mdl",
	soldier = "models/weapons/c_models/c_shovel/c_shovel.mdl",
	pyro = "models/weapons/w_models/w_fireaxe.mdl",
	demo = "models/weapons/w_models/w_bottle.mdl",
	demoman = "models/weapons/w_models/w_bottle.mdl",
	heavy = "models/weapons/c_models/c_fists/c_fists.mdl",
	engineer = "models/weapons/c_models/c_wrench/c_wrench.mdl",
	medic = "models/weapons/c_models/c_bonesaw/c_bonesaw.mdl",
	sniper = "models/weapons/c_models/c_machete/c_machete.mdl",
	spy = "models/weapons/c_models/c_knife/c_knife.mdl",
}

local function TeamToClassImageIndex(teamNum)
	if teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS then
		return 2
	end
	return 1
end

local function TeamToClassImageSuffix(teamNum)
	if teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS then
		return "blue"
	end
	return "red"
end

local function NormalizeClassImageKey(className)
	local normalized = string.lower(string.Trim(tostring(className or "")))
	if normalized == "demoman" then
		return "demo"
	end
	if normalized == "engineer" then
		return "engi"
	end
	if normalized == "civilian" then
		return "civ"
	end
	return normalized
end

local function GetSpyPortraitCloakSuffix(classPly)
	if not IsValid(classPly) or string.lower(tostring(classPly:GetPlayerClass() or "")) ~= "spy" then
		return ""
	end

	if classPly:GetNWBool("Cloaked", false) then
		return "_cloak"
	end

	local nextStealthTime = tonumber(classPly:GetNWFloat("TFNextStealthTime", 0)) or 0
	if nextStealthTime > CurTime() then
		return "_halfcloak"
	end

	return ""
end

local function GetClassPortraitTextureId(className, teamNum, cloakSuffix)
	local imageKey = NormalizeClassImageKey(className)
	if imageKey == "" then
		return nil
	end

	local suffix = TeamToClassImageSuffix(teamNum)
	local path = "hud/class_" .. imageKey .. suffix .. tostring(cloakSuffix or "")
	local cached = classTextureCache[path]
	if cached ~= nil then
		return cached > 0 and cached or nil
	end

	local textureId = surface.GetTextureID(path)
	classTextureCache[path] = textureId
	return textureId > 0 and textureId or nil
end

local function ClassNameToModelPath(className)
	local normalized = string.lower(string.Trim(tostring(className or "")))
	if normalized == "" then
		return character3d_default
	end
	if normalized == "demoman" then
		normalized = "demo"
	end
	return "models/player/" .. normalized .. ".mdl"
end

local function GetDisplayClassInfo(basePly, baseTeam, baseTbl)
	if not IsValid(basePly) then
		return baseTeam, baseTbl
	end

	if basePly ~= LocalPlayer() then
		return baseTeam, baseTbl
	end

	if string.lower(tostring(basePly:GetPlayerClass() or "")) ~= "spy" then
		return baseTeam, baseTbl
	end

	if not basePly:GetNWBool("Disguised", false) or basePly:GetNWBool("Disguising", false) then
		return baseTeam, baseTbl
	end

	local disguiseClass = string.lower(string.Trim(basePly:GetNWString("TFSpyDisguiseClass", "")))
	if disguiseClass == "" then
		return baseTeam, baseTbl
	end

	local displayTeam = baseTeam
	local disguiseTeam = tonumber(basePly:GetNWInt("TFSpyDisguiseTeam", -1)) or -1
	if disguiseTeam > 0 then
		displayTeam = disguiseTeam
	end

	local displayTbl = baseTbl
	if GAMEMODE and GAMEMODE.PlayerClasses and GAMEMODE.PlayerClasses[disguiseClass] then
		displayTbl = GAMEMODE.PlayerClasses[disguiseClass]
	end

	return displayTeam, displayTbl
end

local function GetHUDModelPath(displayTbl, classPly)
	if istable(displayTbl) and isstring(displayTbl.ModelName) and displayTbl.ModelName ~= "" then
		return ClassNameToModelPath(displayTbl.ModelName)
	end

	if IsValid(classPly) and isfunction(classPly.GetPlayerClass) then
		return ClassNameToModelPath(classPly:GetPlayerClass())
	end

	return character3d_default
end

local function GetHUDWeaponModel(classPly)
	if not IsValid(classPly) then return nil end

	local function getWorldModelFromWeapon(wep)
		if not IsValid(wep) then return nil end
		if wep.IsTFWeapon and wep.GetItemData then
			local itemData = wep:GetItemData()
			if istable(itemData) then
				local mdl = itemData.model_world or itemData.model_player
				if isstring(mdl) and mdl ~= "" and util.IsValidModel(mdl) then
					return mdl
				end
			end
		end
		if wep.GetWeaponWorldModel then
			local mdl = wep:GetWeaponWorldModel()
			if isstring(mdl) and mdl ~= "" and util.IsValidModel(mdl) then
				return mdl
			end
		end
		local mdl = wep:GetModel()
		if isstring(mdl) and mdl ~= "" and util.IsValidModel(mdl) then
			return mdl
		end
		return nil
	end

	local function isMeleeWeapon(wep)
		if not IsValid(wep) then return false end
		if wep.IsMeleeWeapon == true then return true end
		local slot = tonumber(wep.Slot or (wep.GetSlot and wep:GetSlot()) or -1)
		if slot == 2 then return true end
		if wep.GetItemData then
			local itemData = wep:GetItemData()
			if istable(itemData) and itemData.item_slot == "melee" then
				return true
			end
		end
		return false
	end

	local function getDisguiseSlotKind(overrideSlot)
		local forced = tonumber(overrideSlot)
		if forced == 0 then return "primary" end
		if forced == 1 then return "secondary" end
		if forced == 2 then return "melee" end
		if forced == 3 then return "sapper" end

		local active = classPly:GetActiveWeapon()
		if not IsValid(active) then return "primary" end
		if active:GetClass() == "tf_weapon_builder" then return "sapper" end
		if isMeleeWeapon(active) then return "melee" end
		local slot = tonumber(active.Slot or (active.GetSlot and active:GetSlot()) or -1)
		if slot == 1 then return "secondary" end
		if active.GetItemData then
			local itemData = active:GetItemData()
			if istable(itemData) and itemData.item_slot == "secondary" then
				return "secondary"
			end
		end
		return "primary"
	end

	local function findTargetWeaponModel(target, wantSlotNum, wantItemSlot)
		if not IsValid(target) or not target.GetWeapons then return nil end
		for _, wep in ipairs(target:GetWeapons()) do
			if not IsValid(wep) then continue end
			local slot = tonumber(wep.Slot or (wep.GetSlot and wep:GetSlot()) or -1)
			local ok = wantSlotNum ~= nil and slot == wantSlotNum
			if not ok and wantItemSlot and wep.GetItemData then
				local itemData = wep:GetItemData()
				ok = istable(itemData) and itemData.item_slot == wantItemSlot
			end
			if ok then
				local mdl = getWorldModelFromWeapon(wep)
				if mdl then return mdl end
			end
		end
		return nil
	end

	if classPly == LocalPlayer()
		and string.lower(tostring(classPly:GetPlayerClass() or "")) == "spy"
		and classPly:GetNWBool("Disguised", false)
	then
		local disguiseClass = string.lower(string.Trim(classPly:GetNWString("TFSpyDisguiseClass", "")))
		local target = classPly:GetNWEntity("TFSpyDisguiseTarget")
		local slotKind = getDisguiseSlotKind(classPly:GetNWInt("TFSpyDisguiseWeaponSlotOverride", -1))

		if slotKind == "sapper" then
			local sapper = getWorldModelFromWeapon(classPly:GetActiveWeapon())
			if sapper then return sapper end
			local sapperWep = classPly.GetWeapon and classPly:GetWeapon("tf_weapon_builder") or nil
			local sapperFallback = getWorldModelFromWeapon(sapperWep)
			if sapperFallback then return sapperFallback end
		elseif slotKind == "melee" then
			local targetMelee = findTargetWeaponModel(target, 2, "melee")
			if targetMelee then return targetMelee end
			local fallbackMelee = DISGUISE_MELEE_WEAPON_BY_CLASS[disguiseClass]
			if isstring(fallbackMelee) and fallbackMelee ~= "" and util.IsValidModel(fallbackMelee) then
				return fallbackMelee
			end
		elseif slotKind == "secondary" then
			local targetSecondary = findTargetWeaponModel(target, 1, "secondary")
			if targetSecondary then return targetSecondary end
			local fallbackSecondary = DISGUISE_SECONDARY_WEAPON_BY_CLASS[disguiseClass] or DISGUISE_PRIMARY_WEAPON_BY_CLASS[disguiseClass]
			if isstring(fallbackSecondary) and fallbackSecondary ~= "" and util.IsValidModel(fallbackSecondary) then
				return fallbackSecondary
			end
		else
			local targetPrimary = findTargetWeaponModel(target, 0, "primary")
			if targetPrimary then return targetPrimary end
			local fallbackPrimary = DISGUISE_PRIMARY_WEAPON_BY_CLASS[disguiseClass]
			if isstring(fallbackPrimary) and fallbackPrimary ~= "" and util.IsValidModel(fallbackPrimary) then
				return fallbackPrimary
			end
		end

		local nwFallback = classPly:GetNWString("TFSpyDisguiseFallbackWeaponModel", "")
		if isstring(nwFallback) and nwFallback ~= "" and util.IsValidModel(nwFallback) then
			return nwFallback
		end
	end

	local wep = classPly:GetActiveWeapon()
	return getWorldModelFromWeapon(wep)
end

local function SplitDisguiseModelList(raw)
	local out = {}
	if not isstring(raw) or raw == "" then return out end

	for token in string.gmatch(raw, "([^|]+)") do
		local mdl = string.Trim(token or "")
		if mdl ~= "" and util.IsValidModel(mdl) then
			out[#out + 1] = mdl
		end
	end

	return out
end

local function GetHUDWearableOwner(classPly)
	if not IsValid(classPly) then return nil end

	if classPly == LocalPlayer()
		and string.lower(tostring(classPly:GetPlayerClass() or "")) == "spy"
		and classPly:GetNWBool("Disguised", false)
	then
		local target = classPly:GetNWEntity("TFSpyDisguiseTarget")
		if IsValid(target) and target:IsPlayer() then
			return target
		end
	end

	return classPly
end

local function IterateOwnerWearables(owner, fn)
	if not IsValid(owner) then return end
	if not isfunction(fn) then return end

	local function scanClass(className)
		for _, ent in ipairs(ents.FindByClass(className)) do
			if not IsValid(ent) then continue end
			if ent:GetOwner() ~= owner then continue end

			local itemData = isfunction(ent.GetItemData) and ent:GetItemData() or nil
			fn(ent, itemData)
		end
	end

	scanClass("tf_wearable_item")
	scanClass("tf_wearable")
end

local function CollectWearableModels(owner)
	if not IsValid(owner) then return {} end

	local entries = {}
	IterateOwnerWearables(owner, function(ent, itemData)
		local mdl = ent:GetModel()
		if not isstring(mdl) or mdl == "" or mdl == "models/empty.mdl" or not util.IsValidModel(mdl) then
			return
		end

		local slot = string.lower(tostring(itemData and itemData.item_slot or ""))
		-- Respect cosmetic slot restrictions (head/misc only).
		if slot ~= "head" and slot ~= "misc" then
			return
		end

		entries[#entries + 1] = {
			model = mdl,
			idx = ent:EntIndex(),
			slot = slot,
			tint = ent.GetCosmeticTint and ent:GetCosmeticTint() or nil,
			itemTint = ent.GetItemTint and ent:GetItemTint() or nil,
		}
	end)
	table.sort(entries, function(a, b) return a.idx < b.idx end)

	local pickedHead = 0
	local pickedMisc = 0
	local result = {}
	local seen = {}
	for _, entry in ipairs(entries) do
		if #result >= 3 then break end

		if entry.slot == "head" then
			if pickedHead >= 1 then continue end
		elseif entry.slot == "misc" then
			if pickedMisc >= 2 then continue end
		end

		if seen[entry.model] then continue end
		seen[entry.model] = true
		result[#result + 1] = {
			model = entry.model,
			tint = isvector(entry.tint) and Vector(entry.tint.x, entry.tint.y, entry.tint.z) or nil,
			itemTint = tonumber(entry.itemTint) or 0,
		}
		if entry.slot == "head" then pickedHead = pickedHead + 1 end
		if entry.slot == "misc" then pickedMisc = pickedMisc + 1 end
	end

	return result
end

local function GetHUDDisplayClassName(displayTbl, classPly)
	if istable(displayTbl) and isstring(displayTbl.ModelName) and displayTbl.ModelName ~= "" then
		return string.lower(string.Trim(displayTbl.ModelName))
	end
	if IsValid(classPly) and isfunction(classPly.GetPlayerClass) then
		return string.lower(string.Trim(classPly:GetPlayerClass()))
	end
	return "spy"
end

local function ApplyHUDWearableBodygroups(baseEnt, owner, teamNum, className)
	if not IsValid(baseEnt) then return end

	for i = 0, (baseEnt:GetNumBodyGroups() or 0) - 1 do
		baseEnt:SetBodygroup(i, 0)
	end

	if not IsValid(owner) then return end
	local classKey = string.lower(string.Trim(tostring(className or "")))
	if classKey == "" then classKey = string.lower(string.Trim(tostring(owner:GetPlayerClass() or ""))) end
	local named = PlayerNamedBodygroups and PlayerNamedBodygroups[classKey] or nil

	local function applyGroup(groupName, state)
		if not isstring(groupName) or groupName == "" then return end
		local idx = named and named[groupName] or nil
		if not idx and baseEnt.FindBodygroupByName then
			local found = baseEnt:FindBodygroupByName(groupName)
			if found and found >= 0 then
				idx = found
			end
		end
		if idx and idx >= 0 then
			baseEnt:SetBodygroup(idx, state)
		end
	end

	IterateOwnerWearables(owner, function(_, itemData)
		if not istable(itemData) then return end
		local slot = string.lower(tostring(itemData.item_slot or ""))
		if slot ~= "head" and slot ~= "misc" then return end

		local vis = itemData.visuals
		if teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS then
			vis = itemData.visuals_blu or vis
		else
			vis = itemData.visuals_red or vis
		end
		if not istable(vis) then return end

		local hideNames = {}
		local showNames = {}

		if istable(vis.player_bodygroups) then
			for _, g in ipairs(vis.player_bodygroups) do
				if isstring(g) then
					hideNames[#hideNames + 1] = g
				end
			end
			for g, value in pairs(vis.player_bodygroups) do
				if isstring(g) then
					local n = tonumber(value)
					if n and n <= 0 then
						showNames[#showNames + 1] = g
					else
						hideNames[#hideNames + 1] = g
					end
				end
			end
		end
		if istable(vis.hide_player_bodygroup_names) then
			for _, g in ipairs(vis.hide_player_bodygroup_names) do
				if isstring(g) then
					hideNames[#hideNames + 1] = g
				end
			end
		end
		if istable(vis.show_player_bodygroup_names) then
			for _, g in ipairs(vis.show_player_bodygroup_names) do
				if isstring(g) then
					showNames[#showNames + 1] = g
				end
			end
		end

		for _, g in ipairs(hideNames) do
			applyGroup(g, 1)
		end
		for _, g in ipairs(showNames) do
			applyGroup(g, 0)
		end
	end)
end

local function GetHUDCosmeticModels(classPly)
	if not IsValid(classPly) then return {} end

	if classPly == LocalPlayer()
		and string.lower(tostring(classPly:GetPlayerClass() or "")) == "spy"
		and classPly:GetNWBool("Disguised", false)
	then
		local target = classPly:GetNWEntity("TFSpyDisguiseTarget")
		if IsValid(target) and target:IsPlayer() then
			local fromTarget = CollectWearableModels(target)
			if #fromTarget > 0 then
				return fromTarget
			end
		end

		local fallback = SplitDisguiseModelList(classPly:GetNWString("TFSpyDisguiseFallbackCosmeticModels", ""))
		if #fallback > 3 then
			return {
				{ model = fallback[1] },
				{ model = fallback[2] },
				{ model = fallback[3] },
			}
		end
		local out = {}
		for i, mdl in ipairs(fallback) do
			out[i] = { model = mdl }
		end
		return out
	end

	local owner = GetHUDWearableOwner(classPly)
	return CollectWearableModels(owner)
end

local function ApplyTeamSkin(ent, teamNum)
	if not IsValid(ent) then return end
	local skin = (teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS) and 1 or 0
	if ent.SetSkin and ent:GetSkin() ~= skin then
		ent:SetSkin(skin)
	end
end

local function EnsureBonemergedChild(parentEnt, childEnt, modelPath, teamNum, tint, itemTint)
	if not IsValid(parentEnt) then return nil end

	if not isstring(modelPath) or modelPath == "" or not util.IsValidModel(modelPath) then
		if IsValid(childEnt) then
			childEnt:Remove()
		end
		return nil
	end

	if not IsValid(childEnt) then
		childEnt = ClientsideModel(modelPath)
	else
		childEnt:SetModel(modelPath)
	end

	if not IsValid(childEnt) then
		return nil
	end

	childEnt:SetParent(parentEnt)
	childEnt:AddEffects(EF_BONEMERGE)
	childEnt:AddEffects(EF_PARENT_ANIMATES)
	childEnt:SetNoDraw(false)
	ApplyTeamSkin(childEnt, teamNum)
	if childEnt.SetPreviewCosmeticTint then
		childEnt:SetPreviewCosmeticTint(tint)
	end
	childEnt.PreviewItemTint = tonumber(itemTint) or 0

	return childEnt
end

local function RemoveHUDAttachments(ent)
	if not IsValid(ent) then return end
	if IsValid(ent.Weapon) then
		ent.Weapon:Remove()
		ent.Weapon = nil
	end
	if istable(ent.Cosmetics) then
		for _, cosmetic in ipairs(ent.Cosmetics) do
			if IsValid(cosmetic) then
				cosmetic:Remove()
			end
		end
	end
	ent.Cosmetics = {}
end

local function GetPhraseOrFallback(key, fallback)
	local phrase = language.GetPhrase(key)
	if isstring(phrase) and phrase ~= "" and phrase ~= key then
		return phrase
	end

	return fallback
end

local function EnsurePlayerModelConfirmDialog()
	if not convar:GetBool() or confirmConvar:GetBool() or IsValid(playermodelConfirmDialog) then
		return
	end

	RunConsoleCommand("cl_hud_playerclass_playermodel_showed_confirm_dialog", "1")

	playermodelConfirmDialog = Derma_Query(
		GetPhraseOrFallback("GameUI_HudPlayerClassUsePlayerModelDialogMessage", "This feature is not recommended for older machines and can be toggled in Advanced Options.\n\nKeep the feature enabled?"),
		GetPhraseOrFallback("GameUI_HudPlayerClassUsePlayerModelDialogTitle", "HUD 3D Character"),
		GetPhraseOrFallback("GameUI_HudPlayerClassUsePlayerModelDialogConfirm", "Yes"),
		function()
			RunConsoleCommand("cl_hud_playerclass_use_playermodel", "1")
			playermodelConfirmDialog = nil
		end,
		GetPhraseOrFallback("GameUI_HudPlayerClassUsePlayerModelDialogCancel", "No"),
		function()
			RunConsoleCommand("cl_hud_playerclass_use_playermodel", "0")
			playermodelConfirmDialog = nil
		end
	)

	if IsValid(playermodelConfirmDialog) then
		playermodelConfirmDialog.OnClose = function()
			playermodelConfirmDialog = nil
		end
	end
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
end

function PANEL:PerformLayout()
	self:SetPos(0,0)
	self:SetSize(W,H)
end

function PANEL:OnRemove()
	if self.ClassModel then
		self.ClassModel:Remove()
	end
end

function PANEL:Paint()
	if not LocalPlayer():Alive() or GetConVar("tf_forcehl2hud"):GetBool() or gmod.GetGamemode() == "tf_darkrp" or LocalPlayer():IsHL2() or GAMEMODE.ShowScoreboard or GetConVarNumber("cl_drawhud")==0 or LocalPlayer():Team() == TEAM_SPECTATOR or LocalPlayer():GetPlayerClass()=="" then
		if self.ClassPanel then
			self.ClassPanel:Remove()
			self.ClassPanel = nil
		end
		if IsValid(self.ClassModel) then
			self.ClassModel:Remove()
			self.ClassModel = nil
		end
		return
	end
		local t = LocalPlayer():Team()
		local hudBgTeam = t
		local tbl = LocalPlayer():GetPlayerClassTable()
		local classPly = LocalPlayer()

		if LocalPlayer():GetObserverTarget() and LocalPlayer():GetObserverTarget():IsPlayer() then
			classPly = LocalPlayer():GetObserverTarget()
			t = classPly:Team()
			hudBgTeam = t
			tbl = classPly:GetPlayerClassTable()
		end
		t, tbl = GetDisplayClassInfo(classPly, t, tbl)

		--ht = ACT_MP_STAND_..LocalPlayer():GetActiveWeapon().HoldType
		--[[model = LocalPlayer():GetPlayerClass()

		if not self.ClassPanel then
			p = vgui.Create("ClassModelPanel")

			p:SetParent(self)
			p:SetPos(W/2-100*Scale, 20*Scale)
			p:SetSize(200*Scale, 360*Scale)
			p.FOV = 50
			p.spotlight = true

			--t:AddModel(3,"models/player/items/all_class/all_halo.mdl",{
				--Parent = 1,
			--})
		end

		if not LocalPlayer():GetPlayerClass() == model then
			self.ModelSet = false
		end

		if self.ClassPanel and not self.ModelSet then
			p:SetSkin( LocalPlayer():GetSkin() )

			if LocalPlayer():GetPlayerClass() == "demoman" then
				model = "demo"
			end
			
			p:AddModel(1, "models/player/"..model..".mdl",{
				Pos = Vector(220, 0, -36),
				Ang = Angle(0, 220, 0),
			})

			if model == LocalPlayer():GetPlayerClass() then
				self.ModelSet = true
			end
		end

			p:StartAnimation(1, LocalPlayer():GetSequenceActivity( LocalPlayer():GetSequence() ))

			--t:GetModelEntity(1):SetPoseParameter("move_x",1)
			--t:GetModelEntity(1):SetPoseParameter("body_pitch",90)
			self.ClassPanel = p

			----print("ACT_MP_STAND_"..LocalPlayer():GetActiveWeapon().HoldType)]]
		local w, h = self:LocalToScreen( self:GetWide(), self:GetTall() - 30 )
		local tex = character_bg[hudBgTeam] or character_bg[1]
		if (LocalPlayer():IsL4D()) then
			tex = surface.GetTextureID("vgui/hud/pz_charge_bg")
		end
			surface.SetTexture(tex)
			surface.SetDrawColor(255,255,255,255)
			if (LocalPlayer():IsL4D()) then
				surface.DrawTexturedRect(25*Scale, (480-88)*Scale-20, 75*Scale+30, 75*Scale+30)
			else
				surface.DrawTexturedRect(9*Scale, (480-60)*Scale, 100*Scale, 50*Scale)
			end
	if convar:GetBool() then
		EnsurePlayerModelConfirmDialog()

		local ply = classPly
		if (ply:Health() < 0 or ply:IsHL2()) then
			if self.ClassModel then
				self.ClassModel:Remove()
			end
		else
			if !IsValid(self.ClassModel) then
				self.ClassModel = vgui.Create("DModelPanel", self, "TF_3DClassModel")
				self.ClassModel.PreDrawModel = function() render.SetScissorRect(0, 0, w, h, true) end
				self.ClassModel.PostDrawModel = function() render.SetScissorRect(0, 0, 0, 0, false) end
				self.ClassModel:SetAnimated(true)
				self.ClassModel.oldDrawModel = self.ClassModel.DrawModel
			end
			self.ClassModel:SetPos(9*Scale, (480-100)*Scale)
			self.ClassModel:SetSize(130*Scale, 100*Scale)
			-- Keep the legacy HUD+ framing so the portrait sits in the original slot.
			self.ClassModel:SetFOV(54)
			self.ClassModel:SetLookAng(Angle(180, -30, 180))
			self.ClassModel:SetCamPos(Vector(75, -30, 55))
			local modelPath = GetHUDModelPath(tbl, ply)
			if (self.ClassModel:GetModel() != modelPath) then
				RemoveHUDAttachments(self.ClassModel:GetEntity())
				self.ClassModel:SetModel(modelPath)
			end
			local ent = self.ClassModel:GetEntity()
			if not IsValid(ent) then return end
			ApplyTeamSkin(ent, t)
			local displayClassName = GetHUDDisplayClassName(tbl, ply)
			local wearableOwner = GetHUDWearableOwner(ply)
			ApplyHUDWearableBodygroups(ent, wearableOwner, t, displayClassName)
			local activeWep = ply:GetActiveWeapon()
			local holdtype = IsValid(activeWep) and (activeWep.HoldType or activeWep:GetHoldType()) or "normal"
			local seqName = "stand_" .. tostring(holdtype or "normal")
			local seq = ent:LookupSequence(seqName)
			if not seq or seq < 0 then
				seq = ent:LookupSequence("idle")
			end
			if seq and seq >= 0 and ent:GetSequence() ~= seq then
				ent:ResetSequence(seq)
				ent:SetCycle(0)
			end
			ent:SetPlaybackRate(1)
			local wmodel = GetHUDWeaponModel(ply)
			ent.Weapon = EnsureBonemergedChild(ent, ent.Weapon, wmodel, t)

			local cosmetics = GetHUDCosmeticModels(ply)
			ent.Cosmetics = ent.Cosmetics or {}
			for i = 1, 3 do
				local cosmetic = cosmetics[i]
				local mdl = istable(cosmetic) and cosmetic.model or cosmetic
				local tint = istable(cosmetic) and cosmetic.tint or nil
				local itemTint = istable(cosmetic) and cosmetic.itemTint or 0
				ent.Cosmetics[i] = EnsureBonemergedChild(ent, ent.Cosmetics[i], mdl, t, tint, itemTint)
			end
			for i = 4, #ent.Cosmetics do
				if IsValid(ent.Cosmetics[i]) then
					ent.Cosmetics[i]:Remove()
				end
				ent.Cosmetics[i] = nil
			end

			self.ClassModel.DrawModel = function(self)
				self:oldDrawModel()
				local ent = self:GetEntity()
				if IsValid(ent.Weapon) then
					ent.Weapon:DrawModel()
				end

				if istable(ent.Cosmetics) then
					for _, cosmetic in ipairs(ent.Cosmetics) do
						if IsValid(cosmetic) then
							cosmetic:StartItemTint(cosmetic.PreviewItemTint)
							cosmetic:DrawModel()
							cosmetic:EndItemTint()
						end
					end
				end
			end
			self.ClassModel.OnClose = function(self)
				local ent = self:GetEntity()
				RemoveHUDAttachments(ent)
			end
			self.ClassModel.OnRemove = self.ClassModel.OnClose
			self.ClassModel.LayoutEntity = function() 
				self.ClassModel:RunAnimation()
				ent:FrameAdvance()
				-- --print(self.ClassModel:GetCamPos(), self.ClassModel:GetFOV(), self.ClassModel:GetLookAt(), self.ClassModel:GetLookAng())
			end
		end
	else
		if self.ClassModel then self.ClassModel:Remove() end
		tex = character_default
		if tbl and tbl.CharacterImage and tbl.CharacterImage[1] then
			tex = tbl.CharacterImage[TeamToClassImageIndex(t)] or tbl.CharacterImage[1]
		end
		local cloakSuffix = GetSpyPortraitCloakSuffix(classPly)
		if cloakSuffix ~= "" then
			local cloakTexture = GetClassPortraitTextureId(tbl and tbl.ModelName or nil, t, cloakSuffix)
			if cloakTexture then
				tex = cloakTexture
			end
		end
		surface.SetTexture(tex)
		surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(25*Scale, (480-88)*Scale, 75*Scale, 75*Scale)
	end
end

if HudPlayerClass then HudPlayerClass:Remove() end
HudPlayerClass = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

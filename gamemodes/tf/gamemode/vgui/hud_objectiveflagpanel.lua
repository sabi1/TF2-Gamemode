local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W / 640
local Scale = H / 480

CreateConVar("hud_show_ctf_as_hl2", "1", { FCVAR_ARCHIVE }, "Show CTF hud as GMod Player")

local TEAM_RED_ID = rawget(_G, "TEAM_RED") or 2
local TEAM_BLU_ID = rawget(_G, "TEAM_BLU") or 3
local TEAM_UNASSIGNED_ID = rawget(_G, "TEAM_UNASSIGNED") or 0
local TF_FLAGTYPE_CTF_ID = rawget(_G, "TF_FLAGTYPE_CTF") or 0
local TF_FLAGTYPE_ATTACK_DEFEND_ID = rawget(_G, "TF_FLAGTYPE_ATTACK_DEFEND") or 1
local TF_FLAGTYPE_TERRITORY_CONTROL_ID = rawget(_G, "TF_FLAGTYPE_TERRITORY_CONTROL") or 2
local TF_FLAGTYPE_INVADE_ID = rawget(_G, "TF_FLAGTYPE_INVADE") or 3
local TF_FLAGTYPE_RESOURCE_CONTROL_ID = rawget(_G, "TF_FLAGTYPE_RESOURCE_CONTROL") or 4
local TF_FLAGTYPE_ROBOT_DESTRUCTION_ID = rawget(_G, "TF_FLAGTYPE_ROBOT_DESTRUCTION") or 5

local RES_PATH = "resource/ui/hudobjectiveflagpanel.res"
local FLAG_STATUS_RES_PATH = "resource/ui/flagstatus.res"

local TEX = {
	bg_left = surface.GetTextureID("hud/objectives_flagpanel_bg_left"),
	bg_right = surface.GetTextureID("hud/objectives_flagpanel_bg_right"),
	bg_outline = surface.GetTextureID("hud/objectives_flagpanel_bg_outline"),
	bg_playingto = surface.GetTextureID("hud/objectives_flagpanel_bg_playingto"),
	carried_outline = surface.GetTextureID("hud/objectives_flagpanel_carried_outline"),
	carried_red = surface.GetTextureID("hud/objectives_flagpanel_carried_red"),
	carried_blue = surface.GetTextureID("hud/objectives_flagpanel_carried_blue"),
	compass_red = surface.GetTextureID("hud/objectives_flagpanel_compass_red"),
	compass_blue = surface.GetTextureID("hud/objectives_flagpanel_compass_blue"),
	compass_grey = surface.GetTextureID("hud/objectives_flagpanel_compass_grey"),
	compass_grey_with_red = surface.GetTextureID("hud/objectives_flagpanel_compass_grey_with_red"),
	compass_red_no_arrow = surface.GetTextureID("hud/objectives_flagpanel_compass_red_noArrow"),
	compass_blue_no_arrow = surface.GetTextureID("hud/objectives_flagpanel_compass_blue_noArrow"),
	briefcase = surface.GetTextureID("hud/objectives_flagpanel_briefcase"),
	status_home = surface.GetTextureID("hud/objectives_flagpanel_ico_flag_home"),
	status_dropped = surface.GetTextureID("hud/objectives_flagpanel_ico_flag_dropped"),
	status_moving = surface.GetTextureID("hud/objectives_flagpanel_ico_flag_moving"),
}

local Layout = {
	leftBg = { x = 320 * WScale - 140 * Scale, y = (480 - 75) * Scale, w = 280 * Scale, h = 80 * Scale },
	rightBg = { x = 320 * WScale - 140 * Scale, y = (480 - 75) * Scale, w = 280 * Scale, h = 80 * Scale },
	outlineBg = { x = 320 * WScale - 140 * Scale, y = (480 - 75) * Scale, w = 280 * Scale, h = 80 * Scale },
	playingToBg = { x = 320 * WScale - 75 * Scale, y = (480 - 31) * Scale, w = 150 * Scale, h = 38 * Scale },
	playingTo = { x = 320 * WScale - 70 * Scale, y = (480 - 28) * Scale, w = 140 * Scale, h = 30 * Scale, font = "HudFontSmall", align = TEXT_ALIGN_CENTER },
	blueScore = { x = 320 * WScale - 130 * Scale, y = (480 - 47) * Scale, w = 75 * Scale, h = 35 * Scale, font = "HudFontBig", align = TEXT_ALIGN_LEFT, color = Colors.TanLight },
	blueScoreShadow = { x = 320 * WScale - 128 * Scale, y = (480 - 46) * Scale, w = 75 * Scale, h = 35 * Scale, font = "HudFontBig", align = TEXT_ALIGN_LEFT, color = Colors.Black },
	redScore = { x = 320 * WScale + 57 * Scale, y = (480 - 47) * Scale, w = 75 * Scale, h = 35 * Scale, font = "HudFontBig", align = TEXT_ALIGN_RIGHT, color = Colors.TanLight },
	redScoreShadow = { x = 320 * WScale + 59 * Scale, y = (480 - 46) * Scale, w = 75 * Scale, h = 35 * Scale, font = "HudFontBig", align = TEXT_ALIGN_RIGHT, color = Colors.Black },
	outlineImage = { x = 320 * WScale - 50 * Scale, y = (480 - 127) * Scale, w = 100 * Scale, h = 50 * Scale },
	carriedImage = { x = 320 * WScale - 50 * Scale, y = (480 - 137) * Scale, w = 100 * Scale, h = 100 * Scale },
	specCarriedImage = { x = 320 * WScale - 50 * Scale, y = (480 - 137) * Scale, w = 100 * Scale, h = 100 * Scale },
	captureFlag = { x = 320 * WScale - 40 * Scale, y = (480 - 95) * Scale, w = 80 * Scale, h = 80 * Scale },
	poisonIcon = { x = 320 * WScale - 20 * Scale, y = (480 - 75) * Scale, w = 40 * Scale, h = 40 * Scale },
	poisonTimeLabel = { x = 320 * WScale - 20 * Scale, y = (480 - 65) * Scale, w = 40 * Scale, h = 20 * Scale, font = "HudFontMediumBold", align = TEXT_ALIGN_CENTER, color = Colors.TanLight },
	blueFlag = { x = 320 * WScale - 135 * Scale, y = (480 - 95) * Scale, w = 160 * Scale, h = 90 * Scale },
	redFlag = { x = 320 * WScale - 25 * Scale, y = (480 - 95) * Scale, w = 160 * Scale, h = 90 * Scale },
	singleFlag = { x = 320 * WScale - 80 * Scale, y = (480 - 95) * Scale, w = 160 * Scale, h = 90 * Scale },
	flagArrow = { x = 40 * Scale, y = 0, w = 80 * Scale, h = 80 * Scale },
	flagBriefcase = { x = 65 * Scale, y = 28 * Scale, w = 30 * Scale, h = 30 * Scale },
	flagStatus = { x = 75 * Scale, y = 26 * Scale, w = 30 * Scale, h = 30 * Scale },
}

local function ResolveConditionalNode(node, activeConditions)
	if not node then return nil end

	local merged = {
		key = node.key,
		props = table.Copy(node.props or {}),
		children = node.children,
	}

	for _, child in ipairs(node.children or {}) do
		if activeConditions and activeConditions[string.lower(child.key or "")] then
			for key, value in pairs(child.props or {}) do
				merged.props[key] = value
			end
		end
	end

	return merged
end

local function ResolveTextAlign(raw, fallback)
	raw = string.lower(tostring(raw or ""))
	if raw == "west" then return TEXT_ALIGN_LEFT end
	if raw == "east" then return TEXT_ALIGN_RIGHT end
	return fallback or TEXT_ALIGN_CENTER
end

local function BuildHudLayoutConditions(assignments)
	assignments = assignments or BuildFlagAssignments()

	local conditions = {}
	local hybrid = AnyAssignedFlag(assignments, function(flag) return IsHybridFlagType(GetFlagGameType(flag)) end)
		or (TF_IsHybridCTFCPMap and TF_IsHybridCTFCPMap() or false)
	local mvm = AnyAssignedFlag(assignments, function(flag) return IsMvMFlagType(GetFlagGameType(flag)) end)
		or (TF_IsMvMMap and TF_IsMvMMap() or false)
	local specialDelivery = AnyAssignedFlag(assignments, function(flag) return IsSpecialDeliveryFlagType(GetFlagGameType(flag)) end)
		or (TF_IsSpecialDeliveryMap and TF_IsSpecialDeliveryMap() or false)
	local numFlags = assignments.uniqueFlags or 0

	if numFlags == 0 then
		conditions.if_no_flags = true
		if specialDelivery then
			conditions.if_specialdelivery = true
		end
	else
		if hybrid or numFlags == 1 or mvm or specialDelivery then
			if hybrid then
				conditions.if_hybrid = true
			end
			if numFlags == 1 or specialDelivery then
				conditions.if_hybrid_single = true
			elseif numFlags == 2 then
				conditions.if_hybrid_double = true
			end
			if mvm then
				conditions.if_mvm = true
			end
			if specialDelivery then
				conditions.if_specialdelivery = true
			end
		end
	end

	return conditions
end

local function LoadHudLayout(assignments)
	if not TF2Res or not TF2Res.Load or not TF2Res.FindByFieldName or not TF2Res.GetRect then
		return
	end

	local path = RES_PATH
	if TF_GetHudResPath then
		path = TF_GetHudResPath((TF_GetHudGameMode and TF_GetHudGameMode()) or "ctf", "flagPanel", RES_PATH)
	end

	local tree = TF2Res.Load(path)
	local flagTree = TF2Res.Load(FLAG_STATUS_RES_PATH)
	if not tree then return end
	local activeConditions = BuildHudLayoutConditions(assignments)
	local flagConditions = {
		if_mvm = activeConditions.if_mvm or false,
	}

	local function applyRect(targetKey, fieldName, defaults)
		local node = ResolveConditionalNode(TF2Res.FindByFieldName(tree, fieldName), activeConditions)
		if not node then return end
		Layout[targetKey] = TF2Res.GetRect(node, W, H, defaults or Layout[targetKey], WScale, Scale)
	end

	local function applyFont(targetKey, fieldName, defaultFont, defaultAlign, colorKey)
		local node = ResolveConditionalNode(TF2Res.FindByFieldName(tree, fieldName), activeConditions)
		if not node then return end
		Layout[targetKey] = Layout[targetKey] or {}
		Layout[targetKey].font = TF2Res.GetString(node, "font", defaultFont or Layout[targetKey].font)
		Layout[targetKey].align = ResolveTextAlign(TF2Res.GetString(node, "textAlignment", nil), defaultAlign or Layout[targetKey].align)
		if colorKey and Colors and Colors[colorKey] then
			Layout[targetKey].color = Colors[colorKey]
		end
	end

	applyRect("leftBg", "LeftSideBG")
	applyRect("rightBg", "RightSideBG")
	applyRect("outlineBg", "OutlineBG")
	applyRect("playingToBg", "PlayingToBG")
	applyRect("playingTo", "PlayingTo")
	applyRect("blueScore", "BlueScore")
	applyRect("blueScoreShadow", "BlueScoreShadow")
	applyRect("redScore", "RedScore")
	applyRect("redScoreShadow", "RedScoreShadow")
	applyRect("outlineImage", "OutlineImage")
	applyRect("carriedImage", "CarriedImage")
	applyRect("specCarriedImage", "SpecCarriedImage")
	applyRect("captureFlag", "CaptureFlag")
	applyRect("poisonIcon", "PoisonIcon")
	applyRect("poisonTimeLabel", "PoisonTimeLabel")
	applyRect("blueFlag", "BlueFlag")
	applyRect("redFlag", "RedFlag")

	Layout.leftBg.tex = TF2Res.GetTextureID(ResolveConditionalNode(TF2Res.FindByFieldName(tree, "LeftSideBG"), activeConditions), "image", "hud/objectives_flagpanel_bg_left")
	Layout.rightBg.tex = TF2Res.GetTextureID(ResolveConditionalNode(TF2Res.FindByFieldName(tree, "RightSideBG"), activeConditions), "image", "hud/objectives_flagpanel_bg_right")
	Layout.outlineBg.tex = TF2Res.GetTextureID(ResolveConditionalNode(TF2Res.FindByFieldName(tree, "OutlineBG"), activeConditions), "image", "hud/objectives_flagpanel_bg_outline")
	Layout.playingToBg.tex = TF2Res.GetTextureID(ResolveConditionalNode(TF2Res.FindByFieldName(tree, "PlayingToBG"), activeConditions), "image", "hud/objectives_flagpanel_bg_playingto")
	Layout.outlineImage.tex = TF2Res.GetTextureID(ResolveConditionalNode(TF2Res.FindByFieldName(tree, "OutlineImage"), activeConditions), "image", "hud/objectives_flagpanel_carried_outline")
	Layout.carriedImage.tex = TF2Res.GetTextureID(ResolveConditionalNode(TF2Res.FindByFieldName(tree, "CarriedImage"), activeConditions), "image", "hud/objectives_flagpanel_carried_red")
	Layout.specCarriedImage.tex = TF2Res.GetTextureID(ResolveConditionalNode(TF2Res.FindByFieldName(tree, "SpecCarriedImage"), activeConditions), "image", "hud/objectives_flagpanel_carried_red")
	Layout.poisonIcon.tex = TF2Res.GetTextureID(ResolveConditionalNode(TF2Res.FindByFieldName(tree, "PoisonIcon"), activeConditions), "image", "marked_for_death")

	if Layout.blueFlag then
		Layout.singleFlag = table.Copy(Layout.blueFlag)
		Layout.singleFlag.x = 320 * WScale - 80 * Scale
	end

	applyFont("playingTo", "PlayingTo", "HudFontSmall", TEXT_ALIGN_CENTER)
	applyFont("blueScore", "BlueScore", "HudFontBig", TEXT_ALIGN_LEFT, "TanLight")
	applyFont("blueScoreShadow", "BlueScoreShadow", "HudFontBig", TEXT_ALIGN_LEFT, "Black")
	applyFont("redScore", "RedScore", "HudFontBig", TEXT_ALIGN_RIGHT, "TanLight")
	applyFont("redScoreShadow", "RedScoreShadow", "HudFontBig", TEXT_ALIGN_RIGHT, "Black")
	applyFont("poisonTimeLabel", "PoisonTimeLabel", "HudFontMediumBold", TEXT_ALIGN_CENTER, "TanLight")

	if flagTree then
		local function applyFlagRect(targetKey, fieldName)
			local node = ResolveConditionalNode(TF2Res.FindByFieldName(flagTree, fieldName), flagConditions)
			if not node then return end
			Layout[targetKey] = TF2Res.GetRect(node, 160 * Scale, 90 * Scale, Layout[targetKey], Scale, Scale)
		end

		applyFlagRect("flagArrow", "Arrow")
		applyFlagRect("flagBriefcase", "Briefcase")
		applyFlagRect("flagStatus", "StatusIcon")
	end
end

local function IsUnresolvedToken(raw, token)
	if not isstring(raw) or raw == "" then
		return true
	end

	if not isstring(token) or token == "" then
		return false
	end

	local bareToken = string.TrimLeft(token, "#")
	return raw == token
		or raw == bareToken
		or raw == "#" .. bareToken
		or string.find(raw, "^[A-Za-z0-9_]+$") ~= nil
end

local function LocalizeAndFormat(token, fallback, substitutions)
	local text = fallback or token or ""
	if tf_lang and tf_lang.Exists and tf_lang.Exists(token) then
		local raw = tf_lang.GetRaw(token, true)
		if not IsUnresolvedToken(raw, token) then
			text = raw
		end
	elseif language and language.GetPhrase and isstring(token) and string.StartWith(token, "#") then
		local phrase = language.GetPhrase(string.sub(token, 2))
		if isstring(phrase) and phrase ~= "" and not IsUnresolvedToken(phrase, token) then
			text = phrase
		end
	end

	for key, value in pairs(substitutions or {}) do
		text = string.gsub(text, "%%" .. tostring(key) .. "%%", tostring(value))
		text = string.gsub(text, "%%" .. tostring(key), tostring(value))
	end

	return text
end

local function ShouldDrawCtfHUD()
	local lp = LocalPlayer()
	if not IsValid(lp) then return false end
	if not lp:Alive() and (not lp.GetObserverMode or lp:GetObserverMode() == OBS_MODE_NONE) then return false end
	if gui.IsGameUIVisible() then return false end
	if lp.GetObserverMode and lp:GetObserverMode() == OBS_MODE_FREEZECAM then return false end
	if lp.IsHL2 and lp:IsHL2() and not GetConVar("hud_show_ctf_as_hl2"):GetBool() then return false end
	if GetConVar("tf_forcehl2hud"):GetBool() then return false end
	if GetConVarNumber("cl_drawhud") == 0 then return false end
	if GAMEMODE.ShowScoreboard then return false end
	if TF_IsCtfHudMode then
		if not TF_IsCtfHudMode() then return false end
	elseif not string.find(string.lower(game.GetMap() or ""), "ctf_", 1, true) then
		return false
	end
	return true
end

local function IsFlagDisabled(flag)
	if not IsValid(flag) then return true end
	return flag:GetNWBool("FlagDisabled", flag.Disabled or false)
end

local function IsFlagVisibleWhenDisabled(flag)
	if not IsValid(flag) then return false end
	return flag:GetNWBool("FlagVisibleWhenDisabled", flag.VisibleWhenDisabled or false)
end

local function IsFlagValidForHud(flag)
	if not IsValid(flag) then return false end
	return not IsFlagDisabled(flag) or IsFlagVisibleWhenDisabled(flag)
end

local function CountUniqueFlags(flags)
	local count = 0
	local seen = {}
	for _, flag in ipairs(flags) do
		if IsValid(flag) and not seen[flag] then
			seen[flag] = true
			count = count + 1
		end
	end
	return count
end

local function BuildFlagAssignments()
	if TF_BuildFlagHudAssignments then
		return TF_BuildFlagHudAssignments()
	end

	local state = {
		redFlag = nil,
		blueFlag = nil,
		neutralFlags = {},
		numValidFlags = 0,
	}

	for _, flag in ipairs(ents.FindByClass("item_teamflag")) do
		if not IsFlagValidForHud(flag) then continue end

		state.numValidFlags = state.numValidFlags + 1

		local teamNum = flag:GetNWInt("FlagTeamNum", TEAM_UNASSIGNED_ID)
		if teamNum == TEAM_RED_ID then
			state.redFlag = flag
		elseif teamNum == TEAM_BLU_ID then
			state.blueFlag = flag
		elseif teamNum == TEAM_UNASSIGNED_ID then
			table.insert(state.neutralFlags, flag)
			if not IsValid(state.blueFlag) then
				state.blueFlag = flag
			elseif not IsValid(state.redFlag) and state.blueFlag ~= flag then
				state.redFlag = flag
			end
		end
	end

	state.uniqueFlags = CountUniqueFlags({ state.redFlag, state.blueFlag })
	state.singleFlag = nil
	if state.uniqueFlags == 1 then
		state.singleFlag = state.blueFlag or state.redFlag
	end

	return state
end

local function GetFlagGameType(flag)
	if not IsValid(flag) then
		return TF_FLAGTYPE_CTF_ID
	end

	return flag:GetNWInt("FlagGameType", flag.GameType or TF_FLAGTYPE_CTF_ID)
end

local function AnyAssignedFlag(state, predicate)
	if not state then return false end

	local seen = {}
	for _, flag in ipairs({ state.redFlag, state.blueFlag }) do
		if IsValid(flag) and not seen[flag] then
			seen[flag] = true
			if predicate(flag) then
				return true
			end
		end
	end

	for _, flag in ipairs(state.neutralFlags or {}) do
		if IsValid(flag) and not seen[flag] then
			seen[flag] = true
			if predicate(flag) then
				return true
			end
		end
	end

	return false
end

local function IsHybridFlagType(gameType)
	return gameType == TF_FLAGTYPE_ATTACK_DEFEND_ID
		or gameType == TF_FLAGTYPE_TERRITORY_CONTROL_ID
		or gameType == TF_FLAGTYPE_RESOURCE_CONTROL_ID
end

local function IsSpecialDeliveryFlagType(gameType)
	return gameType == TF_FLAGTYPE_INVADE_ID
end

local function IsMvMFlagType(gameType)
	return gameType == TF_FLAGTYPE_ROBOT_DESTRUCTION_ID
end

local function IsHybridHudMode()
	local state = HudObjectiveFlagPanel and HudObjectiveFlagPanel.State or nil
	if TF_GetFlagHudModeState then
		return TF_GetFlagHudModeState(state).hybrid and true or false
	end
	if AnyAssignedFlag(state, function(flag) return IsHybridFlagType(GetFlagGameType(flag)) end) then
		return true
	end
	return TF_IsHybridCTFCPMap and TF_IsHybridCTFCPMap() or false
end

local function IsSpecialDeliveryHudMode()
	local state = HudObjectiveFlagPanel and HudObjectiveFlagPanel.State or nil
	if TF_GetFlagHudModeState then
		return TF_GetFlagHudModeState(state).specialDelivery and true or false
	end
	if AnyAssignedFlag(state, function(flag) return IsSpecialDeliveryFlagType(GetFlagGameType(flag)) end) then
		return true
	end
	return TF_IsSpecialDeliveryMap and TF_IsSpecialDeliveryMap() or false
end

local function IsMvMHudMode()
	local state = HudObjectiveFlagPanel and HudObjectiveFlagPanel.State or nil
	if TF_GetFlagHudModeState then
		return TF_GetFlagHudModeState(state).mvm and true or false
	end
	if AnyAssignedFlag(state, function(flag) return IsMvMFlagType(GetFlagGameType(flag)) end) then
		return true
	end
	return TF_IsMvMMap and TF_IsMvMMap() or false
end

local function GetPoisonTime(flag)
	if not IsValid(flag) then return 0 end
	return tonumber(flag:GetNWFloat("FlagPoisonTime", 0)) or 0
end

local function IsPoisonous(flag)
	local poisonTime = GetPoisonTime(flag)
	return poisonTime > 0 and CurTime() >= poisonTime
end

local function FindCaptureZoneByTeam(teamNum)
	for _, zone in ipairs(ents.FindByClass("func_capturezone")) do
		local zoneTeam = zone.TeamNum or zone:GetNWInt("TeamNum", 0)
		local disabled = zone.Disabled or zone:GetNWBool("Disabled", false)
		if zoneTeam == teamNum and not disabled then
			return zone
		end
	end
	return nil
end

local function GetFlagStatusTexture(flag)
	if not IsValid(flag) then
		return TEX.status_home
	end

	local status = flag:GetNWInt("FlagStatus", 0)
	if status == 2 then
		return TEX.status_dropped
	end
	if status == 1 then
		return TEX.status_moving
	end
	return TEX.status_home
end

local function GetCompassRotation(worldEnt)
	local lp = LocalPlayer()
	if not IsValid(lp) or not IsValid(worldEnt) then return 0 end

	local eyeOrigin = lp.EyePos and lp:EyePos() or lp:GetPos()
	local vecTarget = worldEnt:WorldSpaceCenter() - eyeOrigin
	vecTarget.z = 0
	if vecTarget:LengthSqr() <= 0 then
		return 0
	end
	vecTarget:Normalize()

	local forward = lp:EyeAngles():Forward()
	local right = lp:EyeAngles():Right()
	forward.z = 0
	right.z = 0
	forward:Normalize()
	right:Normalize()

	local dot = math.Clamp(vecTarget:Dot(forward), -1, 1)
	local angleBetween = math.acos(dot)
	if vecTarget:Dot(right) < 0 then
		angleBetween = -angleBetween
	end

	return -math.deg(angleBetween)
end

local function DrawResText(text, rect, colorOverride)
	if not rect then return end
	local x = rect.x + rect.w * 0.5
	if rect.align == TEXT_ALIGN_LEFT then
		x = rect.x
	elseif rect.align == TEXT_ALIGN_RIGHT then
		x = rect.x + rect.w
	end

	draw.Text({
		text = tostring(text or ""),
		font = rect.font or "HudFontSmall",
		pos = { x, rect.y + rect.h * 0.5 },
		color = colorOverride or rect.color or Colors.TanLight,
		xalign = rect.align or TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	})
end

local function DrawTexturedRect(rect, texOverride)
	if not rect then return end
	local tex = texOverride or rect.tex
	if not tex or tex <= 0 then return end
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetTexture(tex)
	surface.DrawTexturedRect(rect.x, rect.y, rect.w, rect.h)
end

local function GetFlagCompassTexture(teamNum)
	if teamNum == TEAM_RED_ID then
		return TEX.compass_red
	end
	if teamNum == TEAM_BLU_ID then
		return TEX.compass_blue
	end
	return TEX.compass_grey
end

local ARROW_PANEL = {}

function ARROW_PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self.Entity = nil
	self.Texture = TEX.compass_grey
	self.UseRed = false
	self.NextTextureUpdate = 0
end

function ARROW_PANEL:SetEntity(ent)
	self.Entity = ent
	self:UpdateTexture(true)
end

function ARROW_PANEL:GetEntity()
	return self.Entity
end

function ARROW_PANEL:UpdateTexture(force)
	if not force and self.NextTextureUpdate > CurTime() then
		return
	end

	self.NextTextureUpdate = CurTime() + 0.1

	local ent = self.Entity
	if not IsValid(ent) then
		self.Texture = TEX.compass_grey
		return
	end

	if IsMvMHudMode() then
		local alarmActive = GetGlobalBool("tf_mvm_alarm_status", false)
		if alarmActive and ent:GetNWInt("FlagStatus", 0) == 1 then
			if CurTime() >= (self.NextColorSwitch or 0) then
				self.NextColorSwitch = CurTime() + 0.2
				self.UseRed = not self.UseRed
			end
			self.Texture = self.UseRed and TEX.compass_grey_with_red or TEX.compass_grey
			return
		end

		self.UseRed = false
		self.Texture = TEX.compass_grey
		return
	end

	local teamNum = ent:GetNWInt("FlagTeamNum", TEAM_UNASSIGNED_ID)
	local texture = GetFlagCompassTexture(teamNum)
	local lp = LocalPlayer()
	if IsValid(lp) and lp.GetObserverMode and lp:GetObserverMode() == OBS_MODE_IN_EYE then
		local target = lp:GetObserverTarget()
		if IsValid(target) and target:IsPlayer() and ent:GetNWEntity("carrier") == target then
			if teamNum == TEAM_RED_ID and TEX.compass_red_no_arrow > 0 then
				texture = TEX.compass_red_no_arrow
			elseif teamNum == TEAM_BLU_ID and TEX.compass_blue_no_arrow > 0 then
				texture = TEX.compass_blue_no_arrow
			end
		end
	end

	self.Texture = texture
end

function ARROW_PANEL:Think()
	self:UpdateTexture(false)
end

function ARROW_PANEL:Paint(w, h)
	if not IsValid(self.Entity) then return end

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetTexture(self.Texture or TEX.compass_grey)
	surface.DrawTexturedRectRotated(w * 0.5, h * 0.5, w, h, GetCompassRotation(self.Entity))
end

local CTFArrowPanelClass = vgui.RegisterTable(ARROW_PANEL, "DPanel")

local FLAG_STATUS_PANEL = {}

function FLAG_STATUS_PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self.Entity = nil
	self.StatusTexture = TEX.status_home
	self.BriefcaseTexture = TEX.briefcase
	self.Arrow = vgui.CreateFromTable(CTFArrowPanelClass, self)
	self.Arrow:SetPaintedManually(true)
end

function FLAG_STATUS_PANEL:SetEntity(ent)
	self.Entity = ent
	self.Arrow:SetEntity(ent)
	self:UpdateStatus()
end

function FLAG_STATUS_PANEL:GetEntity()
	return self.Entity
end

function FLAG_STATUS_PANEL:ApplyLayout(rect)
	if not rect then return end
	self:SetPos(rect.x, rect.y)
	self:SetSize(rect.w, rect.h)

	local arrow = Layout.flagArrow or {}
	self.Arrow:SetPos(arrow.x, arrow.y)
	self.Arrow:SetSize(arrow.w, arrow.h)
end

function FLAG_STATUS_PANEL:UpdateStatus()
	local flag = self.Entity
	if not IsValid(flag) then
		self.StatusTexture = TEX.status_home
		self.BriefcaseTexture = TEX.briefcase
		return
	end

	self.StatusTexture = GetFlagStatusTexture(flag)
	self.BriefcaseTexture = TEX.briefcase
	if IsMvMHudMode() then
		self.BriefcaseTexture = flag:GetNWInt("FlagStatus", 0) == 1 and surface.GetTextureID("hud/bomb_carried") or surface.GetTextureID("hud/bomb_dropped")
	end
end

function FLAG_STATUS_PANEL:Think()
	self:UpdateStatus()
end

function FLAG_STATUS_PANEL:Paint()
	if not IsValid(self.Entity) then return end
	local parent = self:GetParent()
	if IsValid(parent) and parent.ShouldDrawHud == false then return end
	local lp = LocalPlayer()
	if IsValid(lp) and lp.GetObserverMode and lp:GetObserverMode() == OBS_MODE_FREEZECAM then return end

	self.Arrow:PaintManual()

	local briefcase = Layout.flagBriefcase or {}
	local status = Layout.flagStatus or {}

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetTexture(self.BriefcaseTexture or TEX.briefcase)
	surface.DrawTexturedRect(briefcase.x, briefcase.y, briefcase.w, briefcase.h)

	surface.SetTexture(self.StatusTexture or TEX.status_home)
	surface.DrawTexturedRect(status.x, status.y, status.w, status.h)
end

local CTFFlagStatusClass = vgui.RegisterTable(FLAG_STATUS_PANEL, "DPanel")

local function IsUsingRoundCapsScore()
	local state = HudObjectiveFlagPanel and HudObjectiveFlagPanel.State or BuildFlagAssignments()
	if TF_GetFlagHudModeState then
		return TF_GetFlagHudModeState(state).usingRoundCapsScore and true or false
	end
	if AnyAssignedFlag(state, function(flag) return IsHybridFlagType(GetFlagGameType(flag)) end) then
		return false
	end
	if AnyAssignedFlag(state, function(flag) return IsSpecialDeliveryFlagType(GetFlagGameType(flag)) end) then
		return false
	end
	if AnyAssignedFlag(state, function(flag) return IsMvMFlagType(GetFlagGameType(flag)) end) then
		return false
	end
	return GetConVar("tf_flag_caps_per_round"):GetInt() > 0
end

local function ShouldShowPlayingTo()
	return IsUsingRoundCapsScore()
end

local function DrawPlayingTo()
	local rounds = GetConVar("tf_flag_caps_per_round"):GetInt()
	if rounds <= 0 then return end
	DrawResText(LocalizeAndFormat("#TF_PlayingTo", "Playing to: %rounds%", {
		rounds = rounds,
	}), Layout.playingTo)
end

local function GetScoreValue(teamNum)
	if IsUsingRoundCapsScore() then
		return team.GetScore(teamNum)
	end
	return team.GetScore(teamNum)
end

local function GetObserverCarriedFlag()
	local lp = LocalPlayer()
	if not IsValid(lp) or not lp.GetObserverMode or lp:GetObserverMode() ~= OBS_MODE_IN_EYE then
		return nil
	end

	local target = lp:GetObserverTarget()
	if not IsValid(target) or not target:IsPlayer() then
		return nil
	end

	for _, flag in ipairs(ents.FindByClass("item_teamflag")) do
		if IsFlagValidForHud(flag) and flag:GetNWEntity("carrier") == target then
			return flag
		end
	end

	return nil
end

local function FindPlayerCarriedFlag(lp, assignments)
	if not IsValid(lp) then return nil end
	for _, flag in ipairs({ assignments.redFlag, assignments.blueFlag }) do
		if IsValid(flag) and flag:GetNWEntity("carrier") == lp then
			return flag
		end
	end
	for _, flag in ipairs(assignments.neutralFlags or {}) do
		if IsValid(flag) and flag:GetNWEntity("carrier") == lp then
			return flag
		end
	end
	return nil
end

local function UsesFriendlyCarriedIcon(flag)
	if not IsValid(flag) then return false end
	if flag:GetNWInt("FlagTeamNum", TEAM_UNASSIGNED_ID) == TEAM_UNASSIGNED_ID then
		return true
	end
	local gameType = GetFlagGameType(flag)
	if gameType == TF_FLAGTYPE_ATTACK_DEFEND_ID
		or gameType == TF_FLAGTYPE_TERRITORY_CONTROL_ID
		or gameType == TF_FLAGTYPE_INVADE_ID
		or gameType == TF_FLAGTYPE_RESOURCE_CONTROL_ID
		or gameType == TF_FLAGTYPE_ROBOT_DESTRUCTION_ID then
		return true
	end
	return false
end

local function GetCarriedTextureForPlayer(flag, viewerTeam)
	if not IsValid(flag) then
		return TEX.carried_red
	end

	local iconTeam
	if UsesFriendlyCarriedIcon(flag) then
		iconTeam = viewerTeam
	else
		iconTeam = viewerTeam == TEAM_RED_ID and TEAM_BLU_ID or TEAM_RED_ID
	end

	return iconTeam == TEAM_BLU_ID and TEX.carried_blue or TEX.carried_red
end

local function GetCarriedTextureForObserver(flag, observerTarget)
	if not IsValid(flag) then
		return TEX.carried_red
	end

	local carrierTeam = IsValid(observerTarget) and observerTarget:Team() or TEAM_RED_ID
	if UsesFriendlyCarriedIcon(flag) then
		return carrierTeam == TEAM_BLU_ID and TEX.carried_blue or TEX.carried_red
	end
	return carrierTeam == TEAM_RED_ID and TEX.carried_blue or TEX.carried_red
end

local function ShouldDrawScoreBackdrop(state)
	if not state or state.numValidFlags <= 0 then
		return false
	end
	if AnyAssignedFlag(state, function(flag) return IsHybridFlagType(GetFlagGameType(flag)) end) then
		return false
	end
	if AnyAssignedFlag(state, function(flag) return IsSpecialDeliveryFlagType(GetFlagGameType(flag)) end) then
		return false
	end
	if AnyAssignedFlag(state, function(flag) return IsMvMFlagType(GetFlagGameType(flag)) end) then
		return false
	end
	return true
end

local function DrawScoreArea(state, panel)
	if not ShouldDrawScoreBackdrop(state) then return end

	DrawTexturedRect(Layout.leftBg, Layout.leftBg.tex or TEX.bg_left)
	DrawTexturedRect(Layout.rightBg, Layout.rightBg.tex or TEX.bg_right)
	DrawTexturedRect(Layout.outlineBg, Layout.outlineBg.tex or TEX.bg_outline)

	if panel and panel.ShowPlayingTo then
		DrawTexturedRect(Layout.playingToBg, Layout.playingToBg.tex or TEX.bg_playingto)
	end

	local bluScore = GetScoreValue(TEAM_BLU_ID)
	local redScore = GetScoreValue(TEAM_RED_ID)
	DrawResText(bluScore, Layout.blueScoreShadow)
	DrawResText(bluScore, Layout.blueScore)
	DrawResText(redScore, Layout.redScoreShadow)
	DrawResText(redScore, Layout.redScore)

	if panel and panel.ShowPlayingTo then
		DrawPlayingTo()
	end
end

local function DrawCarriedState(playerFlag, assignments, texture)
	local lp = LocalPlayer()
	if not IsValid(lp) or not IsValid(playerFlag) then return false end

	local captureTarget = FindCaptureZoneByTeam(lp:Team())
	if not IsValid(captureTarget) then
		captureTarget = lp:Team() == TEAM_RED_ID and assignments.redFlag or assignments.blueFlag
	end

	DrawTexturedRect(Layout.carriedImage, texture or GetCarriedTextureForPlayer(playerFlag, lp:Team()))

	if IsValid(captureTarget) then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetTexture(GetFlagCompassTexture(lp:Team()))
		surface.DrawTexturedRectRotated(
			Layout.captureFlag.x + Layout.captureFlag.w * 0.5,
			Layout.captureFlag.y + Layout.captureFlag.h * 0.5,
			Layout.captureFlag.w,
			Layout.captureFlag.h,
			GetCompassRotation(captureTarget)
		)
	end

	return true
end

local function DrawObserverCarriedState(observerFlag, texture)
	local lp = LocalPlayer()
	if not IsValid(lp) or not IsValid(observerFlag) then return false end

	DrawTexturedRect(Layout.specCarriedImage, texture or GetCarriedTextureForObserver(observerFlag, lp:GetObserverTarget()))
	return true
end

local function DrawPoisonState(flag)
	if not IsValid(flag) then return end

	local poisonTime = GetPoisonTime(flag)
	if poisonTime <= 0 then return end

	if IsPoisonous(flag) then
		DrawTexturedRect(Layout.poisonIcon, Layout.poisonIcon.tex)
		return
	end

	local seconds = math.max(0, math.ceil(poisonTime - CurTime()))
	DrawResText(seconds, Layout.poisonTimeLabel)
end

local OUTLINE_ANIM = {
	hide_duration = 0.1,
	expand_start = 0.1,
	expand_duration = 0.2,
	shrink_start = 0.7,
	shrink_duration = 0.2,
	fade_start = 0.9,
	fade_duration = 0.1,
	expanded = {
		x = 320 * WScale - 200 * Scale,
		y = 140 * Scale,
		w = 400 * Scale,
		h = 200 * Scale,
	},
}

local function CopyRect(rect)
	return {
		x = rect.x,
		y = rect.y,
		w = rect.w,
		h = rect.h,
		tex = rect.tex,
		font = rect.font,
		align = rect.align,
		color = rect.color,
	}
end

local function LerpRect(frac, fromRect, toRect)
	return {
		x = Lerp(frac, fromRect.x, toRect.x),
		y = Lerp(frac, fromRect.y, toRect.y),
		w = Lerp(frac, fromRect.w, toRect.w),
		h = Lerp(frac, fromRect.h, toRect.h),
		tex = fromRect.tex or toRect.tex,
	}
end

function PANEL:StartOutlineAnimation()
	self.OutlineAnimStart = CurTime()
end

function PANEL:HideOutlineAnimation()
	self.OutlineAnimStart = nil
end

function PANEL:GetOutlineAnimatedRect()
	local baseRect = CopyRect(Layout.outlineImage)
	local expandedRect = CopyRect(OUTLINE_ANIM.expanded)
	expandedRect.tex = baseRect.tex

	if not self.OutlineAnimStart then
		return nil, 0
	end

	local elapsed = CurTime() - self.OutlineAnimStart
	if elapsed < 0 then
		return baseRect, 0
	end

	if elapsed < OUTLINE_ANIM.expand_start then
		return baseRect, 0
	end

	if elapsed < OUTLINE_ANIM.expand_start + OUTLINE_ANIM.expand_duration then
		local frac = math.TimeFraction(OUTLINE_ANIM.expand_start, OUTLINE_ANIM.expand_start + OUTLINE_ANIM.expand_duration, elapsed)
		return LerpRect(frac, baseRect, expandedRect), 255 * math.Clamp(math.TimeFraction(OUTLINE_ANIM.expand_start, OUTLINE_ANIM.expand_start + OUTLINE_ANIM.expand_duration, elapsed), 0, 1)
	end

	if elapsed < OUTLINE_ANIM.shrink_start then
		return expandedRect, 255
	end

	if elapsed < OUTLINE_ANIM.shrink_start + OUTLINE_ANIM.shrink_duration then
		local frac = math.TimeFraction(OUTLINE_ANIM.shrink_start, OUTLINE_ANIM.shrink_start + OUTLINE_ANIM.shrink_duration, elapsed)
		return LerpRect(frac, expandedRect, baseRect), 255
	end

	if elapsed < OUTLINE_ANIM.fade_start + OUTLINE_ANIM.fade_duration then
		local frac = math.TimeFraction(OUTLINE_ANIM.fade_start, OUTLINE_ANIM.fade_start + OUTLINE_ANIM.fade_duration, elapsed)
		return baseRect, 255 * (1 - math.Clamp(frac, 0, 1))
	end

	self:HideOutlineAnimation()
	return nil, 0
end

function PANEL:DrawOutlineAnimation()
	local rect, alpha = self:GetOutlineAnimatedRect()
	if not rect or alpha <= 0 then return end

	surface.SetDrawColor(255, 255, 255, alpha)
	surface.SetTexture(rect.tex or TEX.carried_outline)
	surface.DrawTexturedRect(rect.x, rect.y, rect.w, rect.h)
end

function PANEL:Reset()
	self.CarryingFlag = false
	self.FlagAnimationPlayed = false
	self:HideOutlineAnimation()
	self.PlayerFlag = nil
	self.ObserverFlag = nil
	self.PoisonFlag = nil
	self.CarriedImageTexture = Layout.carriedImage.tex or TEX.carried_red
	self.SpecCarriedImageTexture = Layout.specCarriedImage.tex or TEX.carried_red
	self.ShowPlayingTo = false
end

function PANEL:SetPlayingToLabelVisible(visible)
	self.ShowPlayingTo = visible and true or false
end

function PANEL:SetCarriedImage(texture)
	self.CarriedImageTexture = texture or Layout.carriedImage.tex or TEX.carried_red
end

function PANEL:SetSpecCarriedImage(texture)
	self.SpecCarriedImageTexture = texture or Layout.specCarriedImage.tex or TEX.carried_red
end

function PANEL:UpdateFlagPanels()
	local state = self.State or BuildFlagAssignments()
	local shouldDrawHud = ShouldDrawCtfHUD()
	local hideFlagPanels = not shouldDrawHud or IsValid(self.PlayerFlag)
	self.ShouldDrawHud = shouldDrawHud

	if not IsValid(self.BlueFlagPanel) or not IsValid(self.RedFlagPanel) then
		return
	end

	if hideFlagPanels then
		self.BlueFlagPanel:SetVisible(false)
		self.RedFlagPanel:SetVisible(false)
		return
	end

	if state.uniqueFlags == 1 and IsValid(state.singleFlag) then
		self.BlueFlagPanel:SetEntity(state.singleFlag)
		self.BlueFlagPanel:ApplyLayout(Layout.singleFlag)
		self.BlueFlagPanel:SetVisible(true)
		self.RedFlagPanel:SetEntity(nil)
		self.RedFlagPanel:SetVisible(false)
		return
	end

	self.BlueFlagPanel:SetEntity(state.blueFlag)
	self.BlueFlagPanel:ApplyLayout(Layout.blueFlag)
	self.BlueFlagPanel:SetVisible(IsValid(state.blueFlag))

	self.RedFlagPanel:SetEntity(state.redFlag)
	self.RedFlagPanel:ApplyLayout(Layout.redFlag)
	self.RedFlagPanel:SetVisible(IsValid(state.redFlag))
end

function PANEL:UpdateScoreState()
	self:SetPlayingToLabelVisible(ShouldShowPlayingTo())
end

function PANEL:InvalidateHudLayout()
	self.State = BuildFlagAssignments()
	LoadHudLayout(self.State)
	self:PerformLayout()
	self:UpdateStatus()
	self:UpdateScoreState()
	self:UpdateFlagPanels()
end

function PANEL:UpdateModeState()
	local hybrid = IsHybridHudMode()
	local specialDelivery = IsSpecialDeliveryHudMode()
	local mvm = IsMvMHudMode()

	if self.PlayingHybridCTFCP ~= hybrid
		or self.PlayingSpecialDeliveryMode ~= specialDelivery
		or self.PlayingMvM ~= mvm then
		self.PlayingHybridCTFCP = hybrid
		self.PlayingSpecialDeliveryMode = specialDelivery
		self.PlayingMvM = mvm
		self:InvalidateHudLayout()
		return true
	end

	return false
end

function PANEL:UpdateAssignments()
	local oldNumValidFlags = self.NumValidFlags or -1
	self.State = BuildFlagAssignments()
	self.NumValidFlags = self.State.numValidFlags or 0

	if oldNumValidFlags ~= self.NumValidFlags then
		self:InvalidateHudLayout()
		return true
	end

	self:UpdateScoreState()
	self:UpdateFlagPanels()

	return false
end

function PANEL:UpdateStatus(newOwner, flagEntity)
	local lp = LocalPlayer()
	local state = self.State or BuildFlagAssignments()
	local playerFlag = nil

	if IsValid(lp) then
		playerFlag = FindPlayerCarriedFlag(lp, state)
		if not IsValid(playerFlag) and IsValid(newOwner) and newOwner == lp and IsValid(flagEntity) then
			playerFlag = flagEntity
		end
	end

	if IsValid(playerFlag) then
		self.CarryingFlag = true
		self.PlayerFlag = playerFlag
		self:SetCarriedImage(GetCarriedTextureForPlayer(playerFlag, IsValid(lp) and lp:Team() or TEAM_RED_ID))

		if not self.FlagAnimationPlayed then
			self.FlagAnimationPlayed = true
			self:StartOutlineAnimation()
		end
	else
		if self.CarryingFlag then
			self.CarryingFlag = false
			self:StartOutlineAnimation()
		end

		self.FlagAnimationPlayed = false
		self.PlayerFlag = nil
	end

	self.ObserverFlag = GetObserverCarriedFlag()
	if IsValid(self.ObserverFlag) then
		local target = IsValid(lp) and lp.GetObserverTarget and lp:GetObserverTarget() or nil
		self:SetSpecCarriedImage(GetCarriedTextureForObserver(self.ObserverFlag, target))
	end

	local poisonFlag = nil
	if TF_IsMannpowerMode and TF_IsMannpowerMode() and IsValid(self.PlayerFlag) then
		poisonFlag = self.PlayerFlag
	end
	self.PoisonFlag = poisonFlag
	self:UpdateFlagPanels()
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
	self.State = {
		numValidFlags = 0,
		redFlag = nil,
		blueFlag = nil,
		singleFlag = nil,
		uniqueFlags = 0,
	}
	self.PlayerFlag = nil
	self.ObserverFlag = nil
	self.PoisonFlag = nil
	self.OutlineAnimStart = nil
	self.CarryingFlag = false
	self.FlagAnimationPlayed = false
	self.NumValidFlags = -1
	self.PlayingHybridCTFCP = nil
	self.PlayingSpecialDeliveryMode = nil
	self.PlayingMvM = nil
	self.CarriedImageTexture = Layout.carriedImage.tex or TEX.carried_red
	self.SpecCarriedImageTexture = Layout.specCarriedImage.tex or TEX.carried_red
	self.ShowPlayingTo = false
	self.ShouldDrawHud = false
	self.BlueFlagPanel = vgui.CreateFromTable(CTFFlagStatusClass, self)
	self.RedFlagPanel = vgui.CreateFromTable(CTFFlagStatusClass, self)
	self.BlueFlagPanel:SetVisible(false)
	self.RedFlagPanel:SetVisible(false)
	self:UpdateModeState()
end

function PANEL:PerformLayout()
	self:SetPos(0, 0)
	self:SetSize(W, H)
	self:UpdateFlagPanels()
end

function PANEL:Think()
	if self:UpdateModeState() then
		return
	end

	if self:UpdateAssignments() then
		return
	end

	self:UpdateStatus()
end

function PANEL:Paint()
	if not ShouldDrawCtfHUD() then return end

	local lp = LocalPlayer()
	local state = self.State or BuildFlagAssignments()
	local playerFlag = self.PlayerFlag or FindPlayerCarriedFlag(lp, state)
	local observerFlag = self.ObserverFlag or GetObserverCarriedFlag()

	if state.numValidFlags <= 0 and not IsValid(playerFlag) and not IsValid(observerFlag) then
		return
	end

	DrawScoreArea(state, self)
	self:DrawOutlineAnimation()

	if DrawCarriedState(playerFlag, state, self.CarriedImageTexture) then
		DrawPoisonState(self.PoisonFlag)
		return
	end

	DrawObserverCarriedState(observerFlag, self.SpecCarriedImageTexture)
end

if HudObjectiveFlagPanel then HudObjectiveFlagPanel:Remove() end
HudObjectiveFlagPanel = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

hook.Add("TF_FlagStatusUpdate", "TF_HudObjectiveFlagPanel_FlagStatusUpdate", function(flag, owner)
	if not IsValid(HudObjectiveFlagPanel) then return end
	HudObjectiveFlagPanel:UpdateAssignments()
	HudObjectiveFlagPanel:UpdateStatus(owner, flag)
end)

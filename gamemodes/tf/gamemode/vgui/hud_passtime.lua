local PANEL = {}

local cv_passtime_player_reticles_friends = CreateClientConVar("tf_passtime_player_reticles_friends", "2", true, false, "Controls HUD reticles for teammates. 0 = never, 1 = when carrying ball, 2 = always.")
local cv_passtime_player_reticles_enemies = CreateClientConVar("tf_passtime_player_reticles_enemies", "1", true, false, "Controls HUD reticles for enemies. 0 = never, 1 = when carrying ball, 2 = always.")
local cv_passtime_ball_sphere_radius = CreateClientConVar("tf_passtime_ball_sphere_radius", "7.2", true, false, "PASSTIME ball sphere radius used for HUD sizing.")

local W = ScrW()
local H = ScrH()
local WScale = W / 640
local Scale = H / 480

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

local function Localize(token, fallback)
	if not isstring(token) or token == "" then
		return fallback or ""
	end
	if tf_lang and tf_lang.Exists and tf_lang.Exists(token) then
		local raw = tf_lang.GetRaw(token, true)
		if not IsUnresolvedToken(raw, token) then
			return raw
		end
	end
	if language and language.GetPhrase and string.StartWith(token, "#") then
		local phrase = language.GetPhrase(string.sub(token, 2))
		if isstring(phrase) and phrase ~= "" and not IsUnresolvedToken(phrase, token) then
			return phrase
		end
	end
	return fallback or token
end

local function LocalizeStrict(token)
	if not isstring(token) or token == "" then
		return ""
	end
	if tf_lang and tf_lang.Exists and tf_lang.Exists(token) then
		local raw = tf_lang.GetRaw(token, true)
		if not IsUnresolvedToken(raw, token) then
			return raw
		end
		return ""
	end
	if language and language.GetPhrase and string.StartWith(token, "#") then
		local phrase = language.GetPhrase(string.sub(token, 2))
		if isstring(phrase) and phrase ~= "" and not IsUnresolvedToken(phrase, token) then
			return phrase
		end
		return ""
	end
	return IsUnresolvedToken(token, token) and "" or token
end

local function LocalizeAndSubstitute(token, fallback, substitutions)
	local text
	if tf_lang and tf_lang.Exists and tf_lang.Exists(token) then
		local raw = tf_lang.GetRaw(token, true)
		if not IsUnresolvedToken(raw, token) then
			text = raw
		else
			text = Localize(token, fallback)
		end
	else
		text = Localize(token, fallback)
	end
	if not istable(substitutions) then
		return text
	end
	for key, value in pairs(substitutions) do
		text = string.gsub(text, "%%" .. tostring(key) .. "%%", tostring(value))
		text = string.gsub(text, "%%" .. tostring(key), tostring(value))
	end
	return text
end

local function TFLocalizeFormatted(token, fallback, ...)
	local args = { ... }
	local substitutions = {
		s1 = args[1],
		s2 = args[2],
		s3 = args[3],
		s4 = args[4],
		rounds = args[1],
	}

	if tf_lang and tf_lang.Exists and tf_lang.Exists(token) then
		local text = tf_lang.GetRaw(token, true)
		if IsUnresolvedToken(text, token) then
			return LocalizeAndSubstitute(token, fallback, substitutions)
		end
		for key, value in pairs(substitutions) do
			text = string.gsub(text, "%%" .. tostring(key) .. "%%", tostring(value or ""))
		end
		for i = 1, 4 do
			text = string.gsub(text, "%%s" .. tostring(i), tostring(args[i] or ""))
		end
		text = string.gsub(text, "%%%%", "%%")
		return text
	end

	return LocalizeAndSubstitute(token, fallback, substitutions)
end

local function LocalizeAndSubstituteStrict(token, substitutions)
	local text
	if tf_lang and tf_lang.Exists and tf_lang.Exists(token) then
		text = tf_lang.GetRaw(token, true)
		if IsUnresolvedToken(text, token) then
			text = ""
		end
	else
		text = LocalizeStrict(token)
	end
	if text == "" or not istable(substitutions) then
		return text
	end
	for key, value in pairs(substitutions) do
		text = string.gsub(text, "%%" .. tostring(key) .. "%%", tostring(value))
		text = string.gsub(text, "%%" .. tostring(key), tostring(value))
	end
	return text
end

local FontFallbackCache = {}
local function ResolveFont(...)
	local key = table.concat({...}, "|")
	if FontFallbackCache[key] then
		return FontFallbackCache[key]
	end

	for i = 1, select("#", ...) do
		local fontName = select(i, ...)
		if isstring(fontName) and fontName ~= "" then
			local ok = pcall(function()
				surface.SetFont(fontName)
				local w, h = surface.GetTextSize("W")
				if not isnumber(w) or not isnumber(h) then
					error("font unavailable")
				end
			end)
			if ok then
				FontFallbackCache[key] = fontName
				return fontName
			end
		end
	end

	FontFallbackCache[key] = "DermaDefault"
	return "DermaDefault"
end

local TextureIdCache = {}
local function GetSafeTextureID(...)
	local key = table.concat({...}, "|")
	if TextureIdCache[key] ~= nil then
		return TextureIdCache[key]
	end

	for i = 1, select("#", ...) do
		local path = select(i, ...)
		if isstring(path) and path ~= "" then
			local mat = Material(path, "smooth")
			if mat and not mat:IsError() then
				local tex = surface.GetTextureID(path)
				if tex and tex > 0 then
					TextureIdCache[key] = tex
					return tex
				end
			end
		end
	end

	TextureIdCache[key] = 0
	return 0
end

local function GetCarrier()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:IsPlayer() and ply:GetNWBool("TFHasPasstimeBall", false) then
			return ply
		end
	end
	return nil
end

local function GetProjectileBall()
	local balls = ents.FindByClass("tf_projectile_passtime_ball")
	for _, ent in ipairs(balls) do
		if IsValid(ent) then
			return ent
		end
	end
	return nil
end

local function GetLooseBallWeapon()
	local balls = ents.FindByClass("tf_weapon_passtime_gun")
	for _, ent in ipairs(balls) do
		if IsValid(ent) and not IsValid(ent:GetOwner()) then
			return ent
		end
	end
	return nil
end

local function GetBallTargetEntity()
	local carrier = GetCarrier()
	if IsValid(carrier) then
		return carrier
	end
	local projectile = GetProjectileBall()
	if IsValid(projectile) then
		return projectile
	end
	return GetLooseBallWeapon()
end

local function CanSeeTarget(from, to, filter)
	local tr = util.TraceLine({
		start = from,
		endpos = to,
		filter = filter,
		mask = MASK_PLAYERSOLID,
	})
	return tr.Fraction >= 0.99
end

local function ComputeEdgeIndicator(pos, padding)
	local centerX, centerY = ScrW() * 0.5, ScrH() * 0.5
	local screen = pos:ToScreen()
	local dx = screen.x - centerX
	local dy = screen.y - centerY
	local angle = math.atan2(dy, dx)
	local maxX = centerX - padding
	local maxY = centerY - padding
	local scale = math.max(math.abs(dx) / math.max(maxX, 1), math.abs(dy) / math.max(maxY, 1), 1)
	return centerX + dx / scale, centerY + dy / scale, math.deg(angle)
end

local function ShouldDrawPasstimeHUD()
	local lp = LocalPlayer()
	if not IsValid(lp) then return false end
	if GetConVarNumber("cl_drawhud") == 0 then return false end
	if gui.IsGameUIVisible() then return false end
	if GAMEMODE and GAMEMODE.ShowScoreboard then return false end
	if GetConVar("tf_forcehl2hud"):GetBool() then return false end
	if TF_GetHudGameMode and TF_GetHudGameMode() ~= "passtime" then return false end
	return GetGlobalBool("tf_passtime_map", false)
end

local PasstimeRes = {
	root = { x = 0, y = 0, w = W, h = H },
	teamScore = { x = 0, y = 25 * Scale, w = W, h = H, playingTo = 5 },
	leftSideBG = { x = W * 0.5 - 140 * Scale, y = H - 95 * Scale, w = 280 * Scale, h = 80 * Scale, tex = 0 },
	rightSideBG = { x = W * 0.5 - 140 * Scale, y = H - 95 * Scale, w = 280 * Scale, h = 80 * Scale, tex = 0 },
	outlineBG = { x = W * 0.5 - 140 * Scale, y = H - 95 * Scale, w = 280 * Scale, h = 80 * Scale, tex = 0 },
	blueScore = { x = W * 0.5 - 120 * Scale, y = H - 67 * Scale, w = 80 * Scale, h = 35 * Scale, font = ResolveFont("HudFontBig", "HudFontMediumSmall", "DermaLarge") },
	blueScoreShadow = { x = W * 0.5 - 118 * Scale, y = H - 66 * Scale, w = 80 * Scale, h = 35 * Scale, font = ResolveFont("HudFontBig", "HudFontMediumSmall", "DermaLarge") },
	redScore = { x = W * 0.5 + 42 * Scale, y = H - 67 * Scale, w = 80 * Scale, h = 35 * Scale, font = ResolveFont("HudFontBig", "HudFontMediumSmall", "DermaLarge") },
	redScoreShadow = { x = W * 0.5 + 44 * Scale, y = H - 66 * Scale, w = 80 * Scale, h = 35 * Scale, font = ResolveFont("HudFontBig", "HudFontMediumSmall", "DermaLarge") },
	playingToBG = { x = W * 0.5 - 75 * Scale, y = H - 60 * Scale, w = 150 * Scale, h = 38 * Scale, tex = 0 },
	playingTo = { x = W * 0.5 - 70 * Scale, y = H - 57 * Scale, w = 140 * Scale, h = 30 * Scale, font = ResolveFont("HudFontSmall", "TFDefaultSmall", "DermaDefault") },
	passNotifyRoot = { x = 0, y = 16 * Scale, w = W, h = H },
	passNotifyBox = { x = W * 0.5 - 150 * Scale, y = H * 0.5 - 180 * Scale, w = 300 * Scale, h = 56 * Scale },
	passTextMain = { x = W * 0.5 - 150 * Scale, y = H * 0.5 - 180 * Scale, w = 300 * Scale, h = 32 * Scale, font = ResolveFont("HudFontMediumSmallBold", "HudFontSmallBold", "DermaDefaultBold") },
	passTextPlayer = { x = W * 0.5 - 150 * Scale, y = H * 0.5 - 140 * Scale, w = 300 * Scale, h = 16 * Scale, font = ResolveFont("HudFontSmall", "TFDefaultSmall", "DermaDefault") },
	passLockIndicator = { x = W * 0.5 - 158 * Scale, y = H * 0.5 - 166 * Scale, w = 64 * Scale, h = 64 * Scale, tex = 0 },
	speechIndicator = { x = W * 0.5 + 102 * Scale, y = H * 0.5 - 172 * Scale, w = 48 * Scale, h = 48 * Scale, tex = 0 },
	offscreenArrow = { w = 30 * Scale, h = 30 * Scale, tex = 0 },
	ballReticlePiece1 = { tex = 0 },
	ballReticlePiece2 = { tex = 0 },
	ballReticlePassLock = { tex = 0 },
	playerReticleRed = { tex = 0 },
	playerReticleBlue = { tex = 0 },
	offscreenArrowRed = { tex = 0 },
	offscreenArrowBlue = { tex = 0 },
	offscreenArrowNeutral = { tex = 0 },
	eventTitle = { x = 0, y = H * 0.2, w = W, h = 25 * Scale, font = ResolveFont("HudFontBiggerBold", "HudFontBig", "HudFontMediumSmallBold", "DermaDefaultBold") },
	eventBonus = { x = 0, y = H * 0.2 + 24 * Scale, w = W, h = 20 * Scale, font = ResolveFont("HudFontMediumSmallBold", "HudFontSmallBold", "DermaDefaultBold") },
	eventDetail = { x = 0, y = H * 0.2 + 48 * Scale, w = W, h = 24 * Scale, font = ResolveFont("HudFontMediumSmallBold", "HudFontSmallBold", "DermaDefaultBold") },
	progressBar = { x = W * 0.5 - 190 * Scale, y = H - 88 * Scale, w = 380 * Scale, h = 48 * Scale, tex = 0 },
	blueEnd = { x = W * 0.5 - 152 * Scale, y = H - 64 * Scale },
	redEnd = { x = W * 0.5 + 152 * Scale, y = H - 64 * Scale },
	progressBallIcon = { x = 0, y = 0, w = 42 * Scale, h = 42 * Scale, tex = 0 },
	progressSelfPlayerIcon = { x = 0, y = 0, w = 42 * Scale, h = 42 * Scale, tex = 0 },
	ballCarrierName = { x = W * 0.5 - 75 * Scale, y = H - 26 * Scale, w = 150 * Scale, h = 16 * Scale, font = ResolveFont("TargetID", "HudFontSmall", "DermaDefault") },
	ballPowerCluster = { x = 0, y = 32 * Scale, w = W, h = 50 * Scale },
	ballPowerFrame = { x = W * 0.5 - 100 * Scale, y = 32 * Scale, w = 200 * Scale, h = 50 * Scale, tex = 0 },
	ballPowerFill = { x = W * 0.5 - 85 * Scale, y = 48 * Scale, w = 168 * Scale, h = 18 * Scale },
	ballPowerFinal = { x = W * 0.5 - 85 * Scale, y = 48 * Scale, w = 168 * Scale, h = 18 * Scale },
	goalBlue = {},
	goalRed = {},
	playerIcons = {},
}

local PasstimeHudState = {
	lastCarrier = nil,
	lastProjectileThrower = nil,
	lastProjectileTarget = nil,
	lastRedScore = 0,
	lastBluScore = 0,
	lastPower = 0,
	event = nil,
	eventUntil = 0,
}

local function SetHudEvent(titleToken, detailToken, bonusToken, substitutions)
	PasstimeHudState.event = {
		title = LocalizeAndSubstituteStrict(titleToken, substitutions),
		detail = LocalizeAndSubstituteStrict(detailToken, substitutions),
		bonus = LocalizeAndSubstituteStrict(bonusToken, substitutions),
	}
	PasstimeHudState.eventUntil = CurTime() + 3.0
end

local function GetPasstimeTeamColor(teamNum)
	if teamNum == TEAM_RED then
		return Color(255, 81, 81)
	elseif teamNum == TEAM_BLU then
		return Color(165, 222, 255)
	end
	return Color(245, 231, 222)
end

local function DrawTexturedMarker(tex, x, y, w, h, color, rot)
	if not tex or tex <= 0 then
		return
	end

	color = color or Color(255, 255, 255, 255)
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	surface.SetTexture(tex)
	surface.DrawTexturedRectRotated(x, y, w, h, rot or 0)
end

local function ShouldShowWorldMarker(screen)
	if not screen then
		return false
	end

	return screen.visible
		and screen.x >= 0
		and screen.x <= ScrW()
		and screen.y >= 0
		and screen.y <= ScrH()
end

local function GetProjectedWorldDiameter(worldPos, worldRadius)
	if not isvector(worldPos) then
		return 0
	end

	worldRadius = math.max(tonumber(worldRadius) or 0, 0)
	if worldRadius <= 0 then
		return 0
	end

	local center = worldPos:ToScreen()
	local edge = (worldPos + EyeAngles():Right() * worldRadius):ToScreen()
	if not (center and edge and center.visible and edge.visible) then
		return 0
	end

	return math.max(center.x - edge.x, edge.x - center.x) * 2
end

local function CanTargetPassRecipient(owner, target)
	if not (IsValid(owner) and IsValid(target) and owner ~= target) then return false end
	if not (target:IsPlayer() and target:Alive()) then return false end
	if target:Team() ~= owner:Team() then return false end
	if target.InCond and (target:InCond(TF_COND_DISGUISED) or target:InCond(TF_COND_DISGUISING)) then return false end
	if target.InCond and (target:InCond(TF_COND_STEALTHED) or target:InCond(TF_COND_STEALTHED_USER_BUFF)) then return false end
	if target.IsStealthed and target:IsStealthed() then return false end

	local maxRange = GetGlobalFloat("tf_passtime_max_pass_range", 0)
	if maxRange > 0 and owner:GetPos():DistToSqr(target:GetPos()) > (maxRange * maxRange) then
		return false
	end

	return true
end

local function FindBestPassHintTarget(owner)
	if not IsValid(owner) then
		return nil
	end

	local eyePos = owner:EyePos()
	local eyeForward = owner:EyeAngles():Forward()
	local bestScore = 0.96
	local bestTarget = nil

	for _, ply in ipairs(player.GetAll()) do
		if not CanTargetPassRecipient(owner, ply) then
			continue
		end

		local toTarget = (ply:WorldSpaceCenter() - eyePos):GetNormalized()
		local score = eyeForward:Dot(toTarget)
		if score > bestScore and CanSeeTarget(eyePos, ply:WorldSpaceCenter(), { owner, ply }) then
			bestScore = score
			bestTarget = ply
		end
	end

	return bestTarget
end

local function LoadPasstimeRes()
	local rootResPath = (TF_GetHudResPath and TF_GetHudResPath("passtime", "objective", "resource/ui/hudpasstime.res")) or "resource/ui/hudpasstime.res"
	local teamScoreResPath = (TF_GetHudResPath and TF_GetHudResPath("passtime", "teamScore", "resource/ui/hudpasstimeteamscore.res")) or "resource/ui/hudpasstimeteamscore.res"
	local statusResPath = (TF_GetHudResPath and TF_GetHudResPath("passtime", "ballStatus", "resource/ui/hudpasstimeballstatus.res")) or "resource/ui/hudpasstimeballstatus.res"
	local passNotifyResPath = (TF_GetHudResPath and TF_GetHudResPath("passtime", "passNotify", "resource/ui/hudpasstimepassnotify.res")) or "resource/ui/hudpasstimepassnotify.res"
	local offscreenArrowResPath = (TF_GetHudResPath and TF_GetHudResPath("passtime", "offscreenArrow", "resource/ui/hudpasstimeoffscreenarrow.res")) or "resource/ui/hudpasstimeoffscreenarrow.res"

	local rootTree = TF2Res and TF2Res.Load and TF2Res.Load(rootResPath)
	local teamScoreTree = TF2Res and TF2Res.Load and TF2Res.Load(teamScoreResPath)
	local statusTree = TF2Res and TF2Res.Load and TF2Res.Load(statusResPath)
	local passNotifyTree = TF2Res and TF2Res.Load and TF2Res.Load(passNotifyResPath)
	local offscreenArrowTree = TF2Res and TF2Res.Load and TF2Res.Load(offscreenArrowResPath)

	local function applyRect(dst, node, defaults)
		if not node or not TF2Res or not TF2Res.GetRect then return end
		local rect = TF2Res.GetRect(node, W, H, defaults or dst, WScale, Scale)
		dst.x = rect.x or dst.x
		dst.y = rect.y or dst.y
		dst.w = rect.w or dst.w
		dst.h = rect.h or dst.h
	end

	local rootNode = rootTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(rootTree, "HudPasstime")
	local teamScoreNode = teamScoreTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(teamScoreTree, "HudPasstimeTeamScore")
	local statusNode = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "HudPasstimeBallStatus")
	applyRect(PasstimeRes.root, rootNode, PasstimeRes.root)
	applyRect(PasstimeRes.teamScore, teamScoreNode, PasstimeRes.teamScore)
	applyRect(PasstimeRes.root, statusNode, PasstimeRes.root)

	local leftSideBG = teamScoreTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(teamScoreTree, "LeftSideBG")
	local rightSideBG = teamScoreTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(teamScoreTree, "RightSideBG")
	local outlineBG = teamScoreTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(teamScoreTree, "OutlineBG")
	local blueScore = teamScoreTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(teamScoreTree, "BlueScore")
	local blueScoreShadow = teamScoreTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(teamScoreTree, "BlueScoreShadow")
	local redScore = teamScoreTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(teamScoreTree, "RedScore")
	local redScoreShadow = teamScoreTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(teamScoreTree, "RedScoreShadow")
	local playingToBG = teamScoreTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(teamScoreTree, "PlayingToBG")
	local playingTo = teamScoreTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(teamScoreTree, "PlayingTo")

	applyRect(PasstimeRes.leftSideBG, leftSideBG, PasstimeRes.leftSideBG)
	applyRect(PasstimeRes.rightSideBG, rightSideBG, PasstimeRes.rightSideBG)
	applyRect(PasstimeRes.outlineBG, outlineBG, PasstimeRes.outlineBG)
	applyRect(PasstimeRes.blueScore, blueScore, PasstimeRes.blueScore)
	applyRect(PasstimeRes.blueScoreShadow, blueScoreShadow, PasstimeRes.blueScoreShadow)
	applyRect(PasstimeRes.redScore, redScore, PasstimeRes.redScore)
	applyRect(PasstimeRes.redScoreShadow, redScoreShadow, PasstimeRes.redScoreShadow)
	applyRect(PasstimeRes.playingToBG, playingToBG, PasstimeRes.playingToBG)
	applyRect(PasstimeRes.playingTo, playingTo, PasstimeRes.playingTo)

	if leftSideBG and TF2Res.GetTextureID then
		PasstimeRes.leftSideBG.tex = TF2Res.GetTextureID(leftSideBG, "image", "../hud/objectives_flagpanel_bg_left")
	end
	if rightSideBG and TF2Res.GetTextureID then
		PasstimeRes.rightSideBG.tex = TF2Res.GetTextureID(rightSideBG, "image", "../hud/objectives_flagpanel_bg_right")
	end
	if outlineBG and TF2Res.GetTextureID then
		PasstimeRes.outlineBG.tex = TF2Res.GetTextureID(outlineBG, "image", "../hud/objectives_flagpanel_bg_outline")
	end
	if playingToBG and TF2Res.GetTextureID then
		PasstimeRes.playingToBG.tex = TF2Res.GetTextureID(playingToBG, "image", "../hud/objectives_flagpanel_bg_playingto")
	end

	local eventTitle = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "EventTitleLabel")
	local eventBonus = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "EventBonusLabel")
	local eventDetail = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "EventDetailLabel")
	local progressBar = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "ProgressLevelBar")
	local blueEnd = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "BlueProgressEnd")
	local redEnd = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "RedProgressEnd")
	local ballIcon = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "ProgressBallIcon")
	local selfIcon = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "ProgressSelfPlayerIcon")
	local carrierName = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "ProgressBallCarrierName")
	local powerCluster = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "BallPowerCluster")
	local powerFrame = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "BallPowerMeterFrame")
	local powerFill = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "BallPowerMeterFillContainer")
	local powerFinal = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "BallPowerMeterFinalSectionContainer")
	local passNotifyRoot = passNotifyTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(passNotifyTree, "HudPasstimePassNotify")
	local textBox = passNotifyTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(passNotifyTree, "TextBox")
	local textMain = passNotifyTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(passNotifyTree, "TextInPassRange")
	local textPlayer = passNotifyTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(passNotifyTree, "TextPlayerName")
	local passLockIndicator = passNotifyTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(passNotifyTree, "PassLockIndicator")
	local speechIndicator = passNotifyTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(passNotifyTree, "SpeechIndicator")
	local offscreenImage = offscreenArrowTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(offscreenArrowTree, "Image")

	applyRect(PasstimeRes.eventTitle, eventTitle, PasstimeRes.eventTitle)
	applyRect(PasstimeRes.eventBonus, eventBonus, PasstimeRes.eventBonus)
	applyRect(PasstimeRes.eventDetail, eventDetail, PasstimeRes.eventDetail)
	applyRect(PasstimeRes.progressBar, progressBar, PasstimeRes.progressBar)
	applyRect(PasstimeRes.blueEnd, blueEnd, PasstimeRes.blueEnd)
	applyRect(PasstimeRes.redEnd, redEnd, PasstimeRes.redEnd)
	applyRect(PasstimeRes.progressBallIcon, ballIcon, PasstimeRes.progressBallIcon)
	applyRect(PasstimeRes.progressSelfPlayerIcon, selfIcon, PasstimeRes.progressSelfPlayerIcon)
	applyRect(PasstimeRes.ballCarrierName, carrierName, PasstimeRes.ballCarrierName)
	applyRect(PasstimeRes.ballPowerCluster, powerCluster, PasstimeRes.ballPowerCluster)
	applyRect(PasstimeRes.ballPowerFrame, powerFrame, PasstimeRes.ballPowerFrame)
	applyRect(PasstimeRes.ballPowerFill, powerFill, PasstimeRes.ballPowerFill)
	applyRect(PasstimeRes.ballPowerFinal, powerFinal, PasstimeRes.ballPowerFinal)
	applyRect(PasstimeRes.passNotifyRoot, passNotifyRoot, PasstimeRes.passNotifyRoot)
	applyRect(PasstimeRes.passNotifyBox, textBox, PasstimeRes.passNotifyBox)
	applyRect(PasstimeRes.passTextMain, textMain, PasstimeRes.passTextMain)
	applyRect(PasstimeRes.passTextPlayer, textPlayer, PasstimeRes.passTextPlayer)
	applyRect(PasstimeRes.passLockIndicator, passLockIndicator, PasstimeRes.passLockIndicator)
	applyRect(PasstimeRes.speechIndicator, speechIndicator, PasstimeRes.speechIndicator)
	applyRect(PasstimeRes.offscreenArrow, offscreenImage, PasstimeRes.offscreenArrow)

	if progressBar and TF2Res.GetTextureID then
		PasstimeRes.progressBar.tex = TF2Res.GetTextureID(progressBar, "image", "../passtime/hud/passtime_ballcontrol_bar")
	end
	if ballIcon and TF2Res.GetTextureID then
		PasstimeRes.progressBallIcon.tex = TF2Res.GetTextureID(ballIcon, "image", "../passtime/hud/passtime_ball")
	end
	if selfIcon and TF2Res.GetTextureID then
		PasstimeRes.progressSelfPlayerIcon.tex = TF2Res.GetTextureID(selfIcon, "image", "../passtime/hud/portrait_scout_red")
	end
	if powerFrame and TF2Res.GetTextureID then
		PasstimeRes.ballPowerFrame.tex = TF2Res.GetTextureID(powerFrame, "image", "../passtime/hud/passtime_powerball_meter_frame")
	end
	if passLockIndicator and TF2Res.GetTextureID then
		PasstimeRes.passLockIndicator.tex = TF2Res.GetTextureID(passLockIndicator, "image", "../passtime/hud/passtime_ball_reticle_incomingpass")
	end
	if speechIndicator and TF2Res.GetTextureID then
		PasstimeRes.speechIndicator.tex = TF2Res.GetTextureID(speechIndicator, "image", "../passtime/hud/passtime_pass_to_me_prompt")
	end
	PasstimeRes.ballReticlePiece1.tex = GetSafeTextureID("passtime/hud/passtime_ball_reticle_piece_1", "../passtime/hud/passtime_ball_reticle_piece_1")
	PasstimeRes.ballReticlePiece2.tex = GetSafeTextureID("passtime/hud/passtime_ball_reticle_piece_2", "../passtime/hud/passtime_ball_reticle_piece_2")
	PasstimeRes.ballReticlePassLock.tex = GetSafeTextureID("passtime/hud/passtime_ball_reticle_passlock", "../passtime/hud/passtime_ball_reticle_passlock")
	PasstimeRes.playerReticleRed.tex = GetSafeTextureID("passtime/hud/passtime_teamicon_red", "../passtime/hud/passtime_teamicon_red")
	PasstimeRes.playerReticleBlue.tex = GetSafeTextureID("passtime/hud/passtime_teamicon_blue", "../passtime/hud/passtime_teamicon_blue")
	PasstimeRes.offscreenArrowBlue.tex = GetSafeTextureID("passtime/hud/passtime_ball_offscreen_blue", "../passtime/hud/passtime_ball_offscreen_blue")
	PasstimeRes.offscreenArrowRed.tex = GetSafeTextureID("passtime/hud/passtime_ball_offscreen_red", "../passtime/hud/passtime_ball_offscreen_red")
	PasstimeRes.offscreenArrowNeutral.tex = GetSafeTextureID("passtime/hud/passtime_ball", "../passtime/hud/passtime_ball")
	PasstimeRes.offscreenArrow.tex = PasstimeRes.offscreenArrowNeutral.tex

	for i = 0, 2 do
		local blueNode = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "GoalBlue" .. i)
		local redNode = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "GoalRed" .. i)
		local blueRect = { x = W * 0.5 - (162 - (i * 30)) * Scale, y = H - 72 * Scale, w = 17 * Scale, h = 17 * Scale, tex = 0 }
		local redRect = { x = W * 0.5 + (146 - (i * 30)) * Scale, y = H - 72 * Scale, w = 17 * Scale, h = 17 * Scale, tex = 0 }
		applyRect(blueRect, blueNode, blueRect)
		applyRect(redRect, redNode, redRect)
		if blueNode and TF2Res.GetTextureID then
			blueRect.tex = TF2Res.GetTextureID(blueNode, "image", "../passtime/hud/passtime_goal_blue_icon")
		end
		if redNode and TF2Res.GetTextureID then
			redRect.tex = TF2Res.GetTextureID(redNode, "image", "../passtime/hud/passtime_goal_red_icon")
		end
		PasstimeRes.goalBlue[i + 1] = blueRect
		PasstimeRes.goalRed[i + 1] = redRect
	end

	PasstimeRes.playerIcons = {}
	for i = 0, 32 do
		local iconNode = statusTree and TF2Res.FindByFieldName and TF2Res.FindByFieldName(statusTree, "playericon" .. i)
		local iconRect = { x = 0, y = 0, w = 12 * Scale, h = 12 * Scale, tex = 0 }
		applyRect(iconRect, iconNode, iconRect)
		PasstimeRes.playerIcons[i + 1] = iconRect
	end
end

LoadPasstimeRes()

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
end

function PANEL:PerformLayout()
	W = ScrW()
	H = ScrH()
	WScale = W / 640
	Scale = H / 480
	LoadPasstimeRes()
	self:SetPos(PasstimeRes.root.x or 0, PasstimeRes.root.y or 0)
	self:SetSize(PasstimeRes.root.w or W, PasstimeRes.root.h or H)
end

function PANEL:DrawScoreIcons()
	local redScore = math.max(0, GetGlobalInt("tf_passtime_red_score", 0))
	local bluScore = math.max(0, GetGlobalInt("tf_passtime_blue_score", 0))
	local playingTo = GetConVar("tf_passtime_scores_per_round")

	surface.SetDrawColor(255, 255, 255, 255)
	if PasstimeRes.leftSideBG.tex and PasstimeRes.leftSideBG.tex > 0 then
		surface.SetTexture(PasstimeRes.leftSideBG.tex)
		surface.DrawTexturedRect(PasstimeRes.leftSideBG.x, PasstimeRes.leftSideBG.y, PasstimeRes.leftSideBG.w, PasstimeRes.leftSideBG.h)
	end
	if PasstimeRes.rightSideBG.tex and PasstimeRes.rightSideBG.tex > 0 then
		surface.SetTexture(PasstimeRes.rightSideBG.tex)
		surface.DrawTexturedRect(PasstimeRes.rightSideBG.x, PasstimeRes.rightSideBG.y, PasstimeRes.rightSideBG.w, PasstimeRes.rightSideBG.h)
	end
	if PasstimeRes.outlineBG.tex and PasstimeRes.outlineBG.tex > 0 then
		surface.SetTexture(PasstimeRes.outlineBG.tex)
		surface.DrawTexturedRect(PasstimeRes.outlineBG.x, PasstimeRes.outlineBG.y, PasstimeRes.outlineBG.w, PasstimeRes.outlineBG.h)
	end
	if PasstimeRes.playingToBG.tex and PasstimeRes.playingToBG.tex > 0 then
		surface.SetTexture(PasstimeRes.playingToBG.tex)
		surface.DrawTexturedRect(PasstimeRes.playingToBG.x, PasstimeRes.playingToBG.y, PasstimeRes.playingToBG.w, PasstimeRes.playingToBG.h)
	end

	draw.Text({
		text = tostring(bluScore),
		font = PasstimeRes.blueScoreShadow.font or "HudFontBig",
		pos = { PasstimeRes.blueScoreShadow.x, PasstimeRes.blueScoreShadow.y + (PasstimeRes.blueScoreShadow.h * 0.5) },
		color = Colors.Black,
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	})
	draw.Text({
		text = tostring(bluScore),
		font = PasstimeRes.blueScore.font or "HudFontBig",
		pos = { PasstimeRes.blueScore.x, PasstimeRes.blueScore.y + (PasstimeRes.blueScore.h * 0.5) },
		color = Colors.TanLight,
		xalign = TEXT_ALIGN_LEFT,
		yalign = TEXT_ALIGN_CENTER,
	})
	draw.Text({
		text = tostring(redScore),
		font = PasstimeRes.redScoreShadow.font or "HudFontBig",
		pos = { PasstimeRes.redScoreShadow.x + PasstimeRes.redScoreShadow.w, PasstimeRes.redScoreShadow.y + (PasstimeRes.redScoreShadow.h * 0.5) },
		color = Colors.Black,
		xalign = TEXT_ALIGN_RIGHT,
		yalign = TEXT_ALIGN_CENTER,
	})
	draw.Text({
		text = tostring(redScore),
		font = PasstimeRes.redScore.font or "HudFontBig",
		pos = { PasstimeRes.redScore.x + PasstimeRes.redScore.w, PasstimeRes.redScore.y + (PasstimeRes.redScore.h * 0.5) },
		color = Colors.TanLight,
		xalign = TEXT_ALIGN_RIGHT,
		yalign = TEXT_ALIGN_CENTER,
	})
	draw.Text({
		text = TFLocalizeFormatted("#TF_PlayingTo", "Playing to %rounds%", playingTo and playingTo:GetInt() or PasstimeRes.teamScore.playingTo or 5),
		font = PasstimeRes.playingTo.font or "HudFontSmall",
		pos = { PasstimeRes.playingTo.x + (PasstimeRes.playingTo.w * 0.5), PasstimeRes.playingTo.y + (PasstimeRes.playingTo.h * 0.5) },
		color = Colors.TanLight,
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER,
	})

end

local function GetProgressBallTexture(teamNum)
	if teamNum == TEAM_RED then
		return GetSafeTextureID("passtime/hud/passtime_ballcontrol_red", "../passtime/hud/passtime_ballcontrol_red")
	elseif teamNum == TEAM_BLU then
		return GetSafeTextureID("passtime/hud/passtime_ballcontrol_blue", "../passtime/hud/passtime_ballcontrol_blue")
	end
	return GetSafeTextureID("passtime/hud/passtime_ballcontrol_none", "../passtime/hud/passtime_ballcontrol_none", "passtime/hud/passtime_ball", "../passtime/hud/passtime_ball")
end

local PasstimeTrackCache = {
	logic = nil,
	points = nil,
	expires = 0,
}

local function ClosestPointOnSegment(point, segStart, segEnd)
	local delta = segEnd - segStart
	local lengthSqr = delta:LengthSqr()
	if lengthSqr <= 0.0001 then
		return segStart, 0
	end

	local frac = math.Clamp((point - segStart):Dot(delta) / lengthSqr, 0, 1)
	return segStart + delta * frac, frac
end

local function BuildPasstimeTrackPoints()
	local logic = ents.FindByClass("passtime_logic")[1]
	if IsValid(logic) and istable(logic.TrackPoints) then
		local startTrack = logic.TrackPoints.start
		local endTrack = logic.TrackPoints.finish
		if IsValid(startTrack) and IsValid(endTrack) then
			local points = {}
			local seen = {}
			local node = startTrack
			for _ = 1, 16 do
				if not IsValid(node) or seen[node] then
					break
				end
				seen[node] = true
				points[#points + 1] = node:GetPos()
				if node == endTrack then
					break
				end
				node = node.GetInternalVariable and node:GetInternalVariable("m_pNext") or nil
			end
			if #points >= 2 and points[#points] == endTrack:GetPos() then
				return logic, points
			end
			if #points >= 1 then
				points[#points + 1] = endTrack:GetPos()
				return logic, points
			end
		end
	end

	local goals = ents.FindByClass("func_passtime_goal")
	if #goals >= 2 then
		table.sort(goals, function(a, b)
			return a:GetPos().x < b:GetPos().x
		end)
		return logic, { goals[1]:GetPos(), goals[#goals]:GetPos() }
	end

	return logic, nil
end

local function GetPasstimeTrackPoints()
	local logic = ents.FindByClass("passtime_logic")[1]
	local now = CurTime()
	if PasstimeTrackCache.logic == logic and PasstimeTrackCache.points and now < PasstimeTrackCache.expires then
		return PasstimeTrackCache.points
	end

	local builtLogic, points = BuildPasstimeTrackPoints()
	PasstimeTrackCache.logic = builtLogic
	PasstimeTrackCache.points = points
	PasstimeTrackCache.expires = now + 0.5
	return points
end

local function CalcProgressFrac(vecOrigin)
	local trackPoints = GetPasstimeTrackPoints()
	if not istable(trackPoints) or #trackPoints < 2 then
		local numSections = math.max(0, GetGlobalInt("tf_passtime_num_sections", 0))
		local currentSection = math.Clamp(GetGlobalInt("tf_passtime_current_section", 0), 0, math.max(numSections, 1))
		if numSections > 0 then
			return math.Clamp(currentSection / numSections, 0, 1)
		end
		return 0.5
	end

	local bestDist = math.huge
	local bestLen = 0
	local totalLen = 1
	local prevPoint = trackPoints[1]

	for i = 2, #trackPoints do
		local thisPoint = trackPoints[i]
		if not isvector(thisPoint) then
			break
		end

		local segLen = prevPoint:Distance(thisPoint)
		totalLen = totalLen + segLen
		local pointOnLine, segFrac = ClosestPointOnSegment(vecOrigin, prevPoint, thisPoint)
		local dist = pointOnLine:Distance(vecOrigin)
		if dist < bestDist then
			bestDist = dist
			bestLen = totalLen - (segLen * (1 - segFrac))
		end
		prevPoint = thisPoint
	end

	return math.Clamp(bestLen / totalLen, 0, 1)
end

local function GetBallProgressFraction()
	local networkedFrac = GetGlobalFloat("tf_passtime_ball_progress_frac", -1)
	if isnumber(networkedFrac) and networkedFrac >= 0 then
		return math.Clamp(networkedFrac, 0, 1)
	end

	local carrier = GetCarrier()
	if IsValid(carrier) then
		return CalcProgressFrac(carrier:GetPos())
	end
	local projectile = GetProjectileBall()
	if IsValid(projectile) then
		return CalcProgressFrac(projectile:GetPos())
	end
	local looseBall = GetLooseBallWeapon()
	if IsValid(looseBall) then
		return CalcProgressFrac(looseBall:GetPos())
	end
	return CalcProgressFrac(vector_origin)
end

local function DrawProgressGoalIcons()
	surface.SetDrawColor(255, 255, 255, 255)
	for _, rect in ipairs(PasstimeRes.goalBlue) do
		if rect.tex and rect.tex > 0 then
			surface.SetTexture(rect.tex)
			surface.DrawTexturedRect(rect.x, rect.y, rect.w, rect.h)
		end
	end
	for _, rect in ipairs(PasstimeRes.goalRed) do
		if rect.tex and rect.tex > 0 then
			surface.SetTexture(rect.tex)
			surface.DrawTexturedRect(rect.x, rect.y, rect.w, rect.h)
		end
	end
end

function PANEL:DrawProgressBar()
	local carrier = GetCarrier()
	local ballEntity = GetBallTargetEntity()
	local fraction = GetBallProgressFraction()

	surface.SetDrawColor(255, 255, 255, 255)
	if PasstimeRes.progressBar.tex and PasstimeRes.progressBar.tex > 0 then
		surface.SetTexture(PasstimeRes.progressBar.tex)
		surface.DrawTexturedRect(PasstimeRes.progressBar.x, PasstimeRes.progressBar.y, PasstimeRes.progressBar.w, PasstimeRes.progressBar.h)
	end

	DrawProgressGoalIcons()

	local startX = PasstimeRes.blueEnd.x
	local endX = PasstimeRes.redEnd.x
	local centerY = PasstimeRes.progressBar.y + (PasstimeRes.progressBar.h * 0.5) - (PasstimeRes.progressBallIcon.h * 0.5)
	local ballX = Lerp(fraction, startX, endX) - (PasstimeRes.progressBallIcon.w * 0.5)
	local ballTeam = IsValid(carrier) and carrier:Team() or nil
	if not ballTeam and IsValid(ballEntity) then
		if ballEntity.Team then
			ballTeam = ballEntity:Team()
		elseif ballEntity.GetNWEntity then
			local prevCarrier = ballEntity:GetNWEntity("TFPasstimePrevCarrier")
			if IsValid(prevCarrier) then
				ballTeam = prevCarrier:Team()
			end
		end
	end
	local ballTex = GetProgressBallTexture(ballTeam)
	if ballTex and ballTex > 0 then
		surface.SetTexture(ballTex)
		surface.DrawTexturedRect(ballX, centerY, PasstimeRes.progressBallIcon.w, PasstimeRes.progressBallIcon.h)
	end

	if IsValid(carrier) then
		draw.Text({
			text = TFLocalizeFormatted("#TF_Passtime_CarrierName", "Carrier: %s1", carrier:Nick()),
			font = PasstimeRes.ballCarrierName.font or "TargetID",
			pos = {
				PasstimeRes.ballCarrierName.x + (PasstimeRes.ballCarrierName.w * 0.5),
				PasstimeRes.ballCarrierName.y + (PasstimeRes.ballCarrierName.h * 0.5),
			},
			color = carrier:Team() == TEAM_RED and team.GetColor(TEAM_RED) or team.GetColor(TEAM_BLU),
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		})
	elseif GetGlobalInt("tf_passtime_ball_spawn_countdown", 0) > 0 and not GetGlobalBool("tf_passtime_ball_free", false) then
		local countdown = GetGlobalInt("tf_passtime_ball_spawn_countdown", 0)
		draw.Text({
			text = TFLocalizeFormatted("#TF_Passtime_BallSpawnsIn", "JACK SPAWNS IN %s1", countdown),
			font = PasstimeRes.ballCarrierName.font or "TargetID",
			pos = {
				PasstimeRes.ballCarrierName.x + (PasstimeRes.ballCarrierName.w * 0.5),
				PasstimeRes.ballCarrierName.y + (PasstimeRes.ballCarrierName.h * 0.5),
			},
			color = Color(224, 217, 197, 255),
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		})
	end
end

function PANEL:DrawPowerMeter()
	local power = math.Clamp(GetGlobalInt("tf_passtime_ball_power", 0), 0, 100)
	if power <= 0 then
		return
	end

	local fillW = math.floor(PasstimeRes.ballPowerFill.w * (power / 100))
	if fillW > 0 then
		draw.RoundedBox(0,
			PasstimeRes.ballPowerFill.x,
			PasstimeRes.ballPowerFill.y,
			fillW,
			PasstimeRes.ballPowerFill.h,
			Color(255, 210, 80, 220)
		)
	end

	if power >= 100 then
		draw.RoundedBox(0,
			PasstimeRes.ballPowerFinal.x,
			PasstimeRes.ballPowerFinal.y,
			PasstimeRes.ballPowerFinal.w,
			PasstimeRes.ballPowerFinal.h,
			Color(255, 255, 255, 50)
		)
	end

	surface.SetDrawColor(255, 255, 255, 255)
	if PasstimeRes.ballPowerFrame.tex and PasstimeRes.ballPowerFrame.tex > 0 then
		surface.SetTexture(PasstimeRes.ballPowerFrame.tex)
		surface.DrawTexturedRect(
			PasstimeRes.ballPowerFrame.x,
			PasstimeRes.ballPowerFrame.y,
			PasstimeRes.ballPowerFrame.w,
			PasstimeRes.ballPowerFrame.h
		)
	end
end

function PANEL:UpdateState()
	local carrier = GetCarrier()
	local projectile = GetProjectileBall()
	local redScore = math.max(0, GetGlobalInt("tf_passtime_red_score", 0))
	local bluScore = math.max(0, GetGlobalInt("tf_passtime_blue_score", 0))
	local power = math.Clamp(GetGlobalInt("tf_passtime_ball_power", 0), 0, 100)
	local projectileThrower = IsValid(projectile) and projectile:GetNWEntity("TFPasstimePrevCarrier") or nil
	local projectileTarget = IsValid(projectile) and projectile:GetNWEntity("TFPasstimeHomingTarget") or nil

	if IsValid(carrier) and carrier ~= PasstimeHudState.lastCarrier then
		local substitutions = {
			team = carrier:Team() == TEAM_RED and "RED" or "BLU",
			subject = carrier:Nick(),
			source = IsValid(PasstimeHudState.lastCarrier) and PasstimeHudState.lastCarrier:Nick() or "",
		}
		if IsValid(projectileThrower) and projectileThrower ~= carrier then
			substitutions.source = projectileThrower:Nick()
			if projectileThrower:Team() == carrier:Team() then
				SetHudEvent("#Msg_PasstimeEventPassTitle", "#Msg_PasstimeEventPassDetail", "#Msg_PasstimeEventPassBonus", substitutions)
			else
				SetHudEvent("#Msg_PasstimeEventInterceptTitle", "#Msg_PasstimeEventInterceptDetail", "#Msg_PasstimeEventInterceptBonus", substitutions)
			end
		elseif IsValid(PasstimeHudState.lastCarrier) and PasstimeHudState.lastCarrier ~= carrier and PasstimeHudState.lastCarrier:Team() ~= carrier:Team() then
			SetHudEvent("#Msg_PasstimeEventStealTitle", "#Msg_PasstimeEventStealDetail", "#Msg_PasstimeEventStealBonus", substitutions)
		end
	end

	if redScore > PasstimeHudState.lastRedScore or bluScore > PasstimeHudState.lastBluScore then
		local scorer = carrier or projectileThrower
		SetHudEvent(
			"#Msg_PasstimeEventScoreTitle",
			"#Msg_PasstimeEventScoreDetail_NoAssist",
			"#Msg_PasstimeEventScoreBonus",
			{
				team = redScore > PasstimeHudState.lastRedScore and "RED" or "BLU",
				subject = IsValid(scorer) and scorer:Nick() or Localize("#TF_Passtime_Goal", "GOAL"),
			}
		)
	end

	if power > 80 and PasstimeHudState.lastPower <= 80 then
		SetHudEvent("#Msg_PasstimeEventPowerUpTitle", "#Msg_PasstimeEventPowerUpDetail", "#Msg_PasstimeEventPowerUpBonus")
	elseif power <= 80 and PasstimeHudState.lastPower > 80 then
		SetHudEvent("#Msg_PasstimeEventPowerDownTitle", "#Msg_PasstimeEventPowerDownDetail", "#Msg_PasstimeEventPowerDownBonus")
	end

	PasstimeHudState.lastCarrier = carrier
	PasstimeHudState.lastProjectileThrower = projectileThrower
	PasstimeHudState.lastProjectileTarget = projectileTarget
	PasstimeHudState.lastRedScore = redScore
	PasstimeHudState.lastBluScore = bluScore
	PasstimeHudState.lastPower = power
end

function PANEL:DrawEventText()
	if not PasstimeHudState.event or CurTime() > PasstimeHudState.eventUntil then
		return
	end

	local event = PasstimeHudState.event
	if isstring(event.title) and event.title ~= "" then
		draw.Text({
			text = event.title,
			font = PasstimeRes.eventTitle.font or "HudFontBiggerBold",
			pos = { PasstimeRes.eventTitle.x + (PasstimeRes.eventTitle.w * 0.5), PasstimeRes.eventTitle.y + (PasstimeRes.eventTitle.h * 0.5) },
			color = Color(224, 217, 197, 255),
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		})
	end
	if isstring(event.detail) and event.detail ~= "" then
		draw.Text({
			text = event.detail,
			font = PasstimeRes.eventDetail.font or "HudFontMediumSmallBold",
			pos = { PasstimeRes.eventDetail.x + (PasstimeRes.eventDetail.w * 0.5), PasstimeRes.eventDetail.y + (PasstimeRes.eventDetail.h * 0.5) },
			color = Color(224, 217, 197, 255),
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		})
	end
	if event.bonus and event.bonus ~= "" then
		draw.Text({
			text = event.bonus,
			font = PasstimeRes.eventBonus.font or "HudFontMediumSmallBold",
			pos = { PasstimeRes.eventBonus.x + (PasstimeRes.eventBonus.w * 0.5), PasstimeRes.eventBonus.y + (PasstimeRes.eventBonus.h * 0.5) },
			color = Color(255, 235, 35, 200),
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		})
	end
end

function PANEL:DrawPassNotify()
	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:Alive() then
		return
	end

	local projectile = GetProjectileBall()
	local incomingTarget = IsValid(projectile) and projectile:GetNWEntity("TFPasstimeHomingTarget") or nil
	local incomingThrower = IsValid(projectile) and projectile:GetNWEntity("TFPasstimePrevCarrier") or nil
	local carrier = GetCarrier()
	local mainText = nil
	local playerName = nil
	local borderColor = Color(224, 217, 197, 220)
	local showLock = false
	local showSpeech = lp:GetNWFloat("TFPasstimeAskForBallUntil", 0) > CurTime()

	if incomingTarget == lp then
		mainText = Localize("#Msg_PasstimePassIncoming", "PASS INCOMING")
		playerName = IsValid(incomingThrower) and incomingThrower:Nick() or ""
		borderColor = lp:Team() == TEAM_RED and Color(159, 55, 34, 220) or Color(76, 109, 128, 220)
	elseif IsValid(carrier) and carrier ~= lp and carrier:Team() == lp:Team() then
		local maxPassRange = GetGlobalFloat("tf_passtime_max_pass_range", 0)
		local inRange = maxPassRange <= 0 or carrier:EyePos():DistToSqr(lp:EyePos()) <= (maxPassRange * maxPassRange)
		if inRange and CanSeeTarget(carrier:EyePos(), lp:EyePos(), { carrier, lp }) then
			local targeted = carrier:GetNWEntity("TFPasstimePassTarget") == lp
			mainText = targeted and Localize("#Msg_PasstimeLockedOn", "LOCKED ON") or Localize("#Msg_PasstimeInPassRange", "IN PASS RANGE")
			playerName = carrier:Nick()
			showLock = targeted
		end
	end

	if not mainText and not showSpeech then
		return
	end

	draw.RoundedBox(6, PasstimeRes.passNotifyBox.x, PasstimeRes.passNotifyBox.y, PasstimeRes.passNotifyBox.w, PasstimeRes.passNotifyBox.h, Color(32, 28, 24, 220))
	surface.SetDrawColor(borderColor)
	surface.DrawOutlinedRect(PasstimeRes.passNotifyBox.x, PasstimeRes.passNotifyBox.y, PasstimeRes.passNotifyBox.w, PasstimeRes.passNotifyBox.h, 2)

	if mainText then
		draw.Text({
			text = mainText,
			font = PasstimeRes.passTextMain.font or "HudFontMediumSmallBold",
			pos = { PasstimeRes.passTextMain.x + (PasstimeRes.passTextMain.w * 0.5), PasstimeRes.passTextMain.y + (PasstimeRes.passTextMain.h * 0.5) },
			color = Color(224, 217, 197, 180),
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		})
	end
	if playerName then
		draw.Text({
			text = playerName,
			font = PasstimeRes.passTextPlayer.font or "HudFontSmall",
			pos = { PasstimeRes.passTextPlayer.x + (PasstimeRes.passTextPlayer.w * 0.5), PasstimeRes.passTextPlayer.y + (PasstimeRes.passTextPlayer.h * 0.5) },
			color = Color(224, 217, 197, 180),
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		})
	end

	surface.SetDrawColor(255, 255, 255, 255)
	if showLock and PasstimeRes.passLockIndicator.tex and PasstimeRes.passLockIndicator.tex > 0 then
		surface.SetTexture(PasstimeRes.passLockIndicator.tex)
		surface.DrawTexturedRect(PasstimeRes.passLockIndicator.x, PasstimeRes.passLockIndicator.y, PasstimeRes.passLockIndicator.w, PasstimeRes.passLockIndicator.h)
	end
	if showSpeech and PasstimeRes.speechIndicator.tex and PasstimeRes.speechIndicator.tex > 0 then
		surface.SetTexture(PasstimeRes.speechIndicator.tex)
		surface.DrawTexturedRect(PasstimeRes.speechIndicator.x, PasstimeRes.speechIndicator.y, PasstimeRes.speechIndicator.w, PasstimeRes.speechIndicator.h)
	end
end

function PANEL:DrawBallReticle()
	local lp = LocalPlayer()
	if not IsValid(lp) then
		return
	end

	local carrier = GetCarrier()
	local projectile = GetProjectileBall()
	local target = IsValid(carrier) and carrier or (IsValid(projectile) and projectile or GetLooseBallWeapon())
	if not IsValid(target) or target == lp then
		return
	end

	local teamNum = TEAM_UNASSIGNED
	if IsValid(carrier) then
		teamNum = carrier:Team()
	elseif IsValid(projectile) then
		local prevCarrier = projectile:GetNWEntity("TFPasstimePrevCarrier")
		if IsValid(prevCarrier) then
			teamNum = prevCarrier:Team()
		end
	end

	if teamNum ~= TEAM_UNASSIGNED and teamNum ~= lp:Team() then
		return
	end

	local pos = target:WorldSpaceCenter()
	local screen = pos:ToScreen()
	if not ShouldShowWorldMarker(screen) then
		return
	end

	local homingActive = IsValid(projectile) and IsValid(projectile:GetNWEntity("TFPasstimeHomingTarget"))
	local targeted = lp:GetNWBool("TFPasstimeIsTargeted", false)
	local alpha = (homingActive or targeted) and math.floor((math.fmod(CurTime() * 3.0, 1.0)) * 255) or 180
	local dist = pos:Distance(EyePos())
	local scale = math.Remap(math.Clamp(dist, 768, 4096), 768, 4096, 64, 192)
	local projectedBallDiameter = GetProjectedWorldDiameter(pos, cv_passtime_ball_sphere_radius:GetFloat())
	if projectedBallDiameter > 0 then
		scale = math.max(scale, projectedBallDiameter * 1.1)
	end
	if homingActive or targeted then
		scale = scale * 2
	end

	local teamColor = GetPasstimeTeamColor(teamNum)
	teamColor.a = alpha
	DrawTexturedMarker(PasstimeRes.ballReticlePiece1.tex, screen.x, screen.y, scale, scale, teamColor, 0)
	DrawTexturedMarker(PasstimeRes.ballReticlePiece2.tex, screen.x, screen.y, scale, scale, teamColor, 0)
end

function PANEL:DrawGoalReticles()
	local lp = LocalPlayer()
	local carrier = GetCarrier()
	if not (IsValid(lp) and carrier == lp) then
		return
	end

	for _, goal in ipairs(ents.FindByClass("func_passtime_goal")) do
		if not IsValid(goal) or goal.Disabled or goal.TeamNum ~= lp:Team() then
			continue
		end

		local vec = goal:WorldSpaceCenter()
		local facingFrac = EyeAngles():Forward():Dot((vec - EyePos()):GetNormalized())
		if facingFrac < 0.6 then
			continue
		end

		local screen = vec:ToScreen()
		if not ShouldShowWorldMarker(screen) then
			continue
		end

		local color = GetPasstimeTeamColor(lp:Team())
		local ringAlpha = math.Clamp(math.cos(CurTime() * 10.0), 0, 1) * (120 * math.Remap(math.Clamp(facingFrac, 0.8, 1.0), 0.8, 1.0, 1.0, 0.3))
		local arrowFrac = 1.0 - (CurTime() % 1.0)
		local arrowScreen = (vec + Vector(0, 0, arrowFrac * 64)):ToScreen()

		DrawTexturedMarker(PasstimeRes.ballReticlePiece1.tex, screen.x, screen.y, 256, 256, Color(color.r, color.g, color.b, ringAlpha), 0)
		if ShouldShowWorldMarker(arrowScreen) then
			DrawTexturedMarker(PasstimeRes.ballReticlePiece2.tex, arrowScreen.x, arrowScreen.y, 128, 128, Color(color.r, color.g, color.b, arrowFrac * (255 * math.Remap(math.Clamp(facingFrac, 0.8, 1.0), 0.8, 1.0, 1.0, 0.3))), 0)
		end
	end
end

function PANEL:DrawPassReticle()
	local lp = LocalPlayer()
	local carrier = GetCarrier()
	if not (IsValid(lp) and carrier == lp) then
		return
	end

	local passTarget = lp:GetNWEntity("TFPasstimePassTarget")
	local hintedTarget = nil
	local alpha = 0
	local baseScale = 64

	if IsValid(passTarget) then
		hintedTarget = passTarget
		alpha = math.floor((math.fmod(CurTime() * 3.0, 1.0)) * 255)
	else
		hintedTarget = FindBestPassHintTarget(lp)
		if not IsValid(hintedTarget) then
			return
		end
		alpha = 200 * math.Clamp(math.cos(CurTime() * 20.0), 0.3, 1.0)
		baseScale = 48
	end

	local pos = hintedTarget:WorldSpaceCenter()
	local screen = pos:ToScreen()
	if not ShouldShowWorldMarker(screen) then
		return
	end

	local dist = pos:Distance(EyePos())
	local scale = math.Remap(math.Clamp(dist, 768, 8192), 768, 8192, 1.0, 8.0) * baseScale
	local teamColor = IsValid(passTarget) and GetPasstimeTeamColor(lp:Team()) or GetPasstimeTeamColor(TEAM_UNASSIGNED)
	local neutralColor = GetPasstimeTeamColor(TEAM_UNASSIGNED)

	if IsValid(passTarget) then
		DrawTexturedMarker(PasstimeRes.ballReticlePassLock.tex, screen.x, screen.y, scale * 2, scale * 2, Color(teamColor.r, teamColor.g, teamColor.b, alpha), 0)
	end
	DrawTexturedMarker(PasstimeRes.ballReticlePiece1.tex, screen.x, screen.y, scale * 2, scale * 2, Color(neutralColor.r, neutralColor.g, neutralColor.b, IsValid(passTarget) and 255 or 80), 0)
	DrawTexturedMarker(PasstimeRes.ballReticlePiece2.tex, screen.x, screen.y, scale * 2, scale * 2, Color(teamColor.r, teamColor.g, teamColor.b, alpha), 0)
end

function PANEL:DrawAskForBallReticles()
	local lp = LocalPlayer()
	if not IsValid(lp) then
		return
	end

	for _, ply in ipairs(player.GetAll()) do
		if not (IsValid(ply) and ply ~= lp and ply:Alive() and ply:Team() == lp:Team()) then
			continue
		end
		if ply:GetNWFloat("TFPasstimeAskForBallUntil", 0) <= CurTime() then
			continue
		end

		local pos = ply:WorldSpaceCenter() + Vector(0, 0, 18)
		local screen = pos:ToScreen()
		if not ShouldShowWorldMarker(screen) then
			continue
		end

		DrawTexturedMarker(PasstimeRes.speechIndicator.tex, screen.x, screen.y, 32 * Scale, 32 * Scale, Color(255, 255, 255, 220), 0)
	end
end

function PANEL:DrawPlayerReticles()
	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:Alive() then
		return
	end

	local friendsDetail = cv_passtime_player_reticles_friends:GetInt()
	local enemiesDetail = cv_passtime_player_reticles_enemies:GetInt()
	local localHasBall = lp:GetNWBool("TFHasPasstimeBall", false)

	for _, ply in ipairs(player.GetAll()) do
		if not (IsValid(ply) and ply ~= lp and ply:Alive()) then
			continue
		end

		if ply.GetPercentInvisible and ply:GetPercentInvisible() > 0 then
			continue
		end

		local disguisedEnemy = false
		if ply.InCond and ply:InCond(TF_COND_DISGUISED) and ply.GetDisguiseTeam and ply:GetDisguiseTeam() == lp:Team() then
			disguisedEnemy = true
		end

		local isFriend = ply:Team() == lp:Team() or disguisedEnemy
		local detail = isFriend and friendsDetail or enemiesDetail
		if detail <= 0 then
			continue
		end
		if detail == 1 and not localHasBall then
			continue
		end

		local vecTarget = ply:EyePos()
		local screen = vecTarget:ToScreen()
		if not ShouldShowWorldMarker(screen) then
			continue
		end

		local tr = util.TraceLine({
			start = EyePos(),
			endpos = vecTarget,
			filter = lp,
			mask = MASK_PLAYERSOLID
		})

		if tr.Fraction >= 1 or tr.Entity == ply then
			continue
		end

		local teamNum = ply:Team()
		if disguisedEnemy and ply:Team() ~= lp:Team() then
			teamNum = lp:Team()
		end

		local tex = teamNum == TEAM_RED and PasstimeRes.playerReticleRed.tex or PasstimeRes.playerReticleBlue.tex
		if not tex or tex <= 0 then
			continue
		end

		local dist = vecTarget:Distance(EyePos())
		local scale = math.Remap(math.Clamp(dist, 1024, 4096), 1024, 4096, 80, 128)
		DrawTexturedMarker(tex, screen.x, screen.y, scale, scale, Color(255, 255, 255, 100), 0)
	end
end

function PANEL:DrawOffscreenArrow()
	local target = GetBallTargetEntity()
	local lp = LocalPlayer()
	if not (IsValid(target) and IsValid(lp)) then
		return
	end
	if target == lp then
		return
	end

	local worldPos = target:WorldSpaceCenter()
	local screen = worldPos:ToScreen()
	if ShouldShowWorldMarker(screen) then
		return
	end

	local iconTex = PasstimeRes.offscreenArrowNeutral.tex
	local teamNum = TEAM_UNASSIGNED
	if target:IsPlayer() then
		teamNum = target:Team()
	else
		local prevCarrier = target.GetNWEntity and target:GetNWEntity("TFPasstimePrevCarrier") or nil
		if IsValid(prevCarrier) then
			teamNum = prevCarrier:Team()
		end
	end

	if teamNum == TEAM_RED then
		iconTex = PasstimeRes.offscreenArrowRed.tex
	elseif teamNum == TEAM_BLU then
		iconTex = PasstimeRes.offscreenArrowBlue.tex
	end

	local x, y, angle = ComputeEdgeIndicator(worldPos, math.max(PasstimeRes.offscreenArrow.w, PasstimeRes.offscreenArrow.h) + 48)
	DrawTexturedMarker(iconTex, x, y, PasstimeRes.offscreenArrow.w, PasstimeRes.offscreenArrow.h, Color(255, 255, 255, 255), 0)

	local radians = math.rad(angle)
	local arrowLength = 18 * Scale
	local arrowWidth = 10 * Scale
	local tip = { x = x + math.cos(radians) * arrowLength, y = y + math.sin(radians) * arrowLength }
	local left = { x = x + math.cos(radians + 2.5) * arrowWidth, y = y + math.sin(radians + 2.5) * arrowWidth }
	local right = { x = x + math.cos(radians - 2.5) * arrowWidth, y = y + math.sin(radians - 2.5) * arrowWidth }

	draw.NoTexture()
	surface.SetDrawColor(255, 255, 255, 220)
	surface.DrawPoly({
		{ x = tip.x, y = tip.y },
		{ x = left.x, y = left.y },
		{ x = right.x, y = right.y },
	})
end

function PANEL:Paint()
	if not ShouldDrawPasstimeHUD() then return end

	self:UpdateState()
	self:DrawScoreIcons()
	self:DrawProgressBar()
	self:DrawPowerMeter()
	self:DrawEventText()
	self:DrawPassNotify()
	self:DrawBallReticle()
	self:DrawGoalReticles()
	self:DrawPassReticle()
	self:DrawAskForBallReticles()
	self:DrawPlayerReticles()
	self:DrawOffscreenArrow()
end

if HudPasstime then HudPasstime:Remove() end
HudPasstime = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))

CreateClientConVar("cl_trigger_first_notification", tostring(KEY_J), true, false, "Key code used to accept the topmost in-game notification.")
CreateClientConVar("cl_decline_first_notification", tostring(KEY_K), true, false, "Key code used to decline the topmost in-game notification.")
CreateClientConVar("cl_notifications_show_ingame", "1", true, false, "Whether notifications should show up in-game.")

local TFNotificationQueue = TFNotificationQueue or {}
local TFNotificationNextID = TFNotificationNextID or 1
local TFNotificationPanel = TFNotificationPanel or nil
local TFNotificationAcceptDown = false
local TFNotificationDeclineDown = false

local TYPE_BASIC = "basic"
local TYPE_ACCEPT_DECLINE = "accept_decline"
local TYPE_ACCEPT = "accept"
local TYPE_TRIGGER = "trigger"
local TYPE_MUST_TRIGGER = "must_trigger"
local NOTIFY_WIDTH = 430
local NOTIFY_HEIGHT = 124
local defaultNotificationResPath = "resource/ui/notifications/base_notification.res"
local defaultNotificationSound = "ui/notification_alert.wav"
local econToastResPath = "resource/ui/econ/genericnotificationtoast.res"
local econToastControlResPath = "resource/ui/econ/notificationtoastcontrol.res"
local econToastContainerResPath = "resource/ui/econ/notificationtoastcontainer.res"
local notificationFontRemap = {
	TFFontSmall = "TFFontSmall",
	HudFontSmallestBold = "HudFontSmallestBold",
	HudFontSmallBold = "HudFontSmallBold",
}
local measureTextBlock
local wrapTextToWidth
local resolveNotificationType

local function resolveNotificationFont(fontName, fallback)
	local resolved = notificationFontRemap[tostring(fontName or "")] or fontName or fallback or "HudFontSmallBold"
	return tostring(resolved)
end

local function resolveNotificationColor(raw, fallback)
	if IsColor(raw) then
		return raw
	end

	if isstring(raw) then
		local named = Colors and Colors[raw]
		if IsColor(named) then
			return named
		end
	end

	return fallback
end

local function getNotificationResColor(node, key, fallback)
	if not (node and TF2Res and TF2Res.GetString) then
		return fallback
	end

	local raw = TF2Res.GetString(node, key, nil)
	local named = resolveNotificationColor(raw, nil)
	if IsColor(named) then
		return named
	end

	if TF2Res.GetColor then
		return TF2Res.GetColor(node, key, fallback)
	end

	return fallback
end

local function getNotificationTextureID(path)
	local normalized = TF2Res and TF2Res.NormalizeImagePath and TF2Res.NormalizeImagePath(path) or nil
	if not normalized or normalized == "" then
		return nil
	end

	local materialPath = "materials/" .. normalized .. ".vmt"
	if not file.Exists(materialPath, "GAME") then
		return nil
	end

	return surface.GetTextureID(normalized)
end

local function getNotificationResTree(resPath)
	if not TF2Res or not TF2Res.Load then
		return nil
	end

	return TF2Res.Load(tostring(resPath or defaultNotificationResPath))
end

local function getNotificationResFieldNode(resPath, fieldName)
	local tree = getNotificationResTree(resPath)
	if not tree then
		return nil
	end

	if TF2Res.FindByKey then
		local byKey = TF2Res.FindByKey(tree, fieldName)
		if byKey then
			return byKey
		end
	end

	if TF2Res.FindByFieldName then
		return TF2Res.FindByFieldName(tree, fieldName)
	end

	return nil
end

local function getNotificationResRect(resPath, fieldName, defaults, parentW, parentH)
	local node = getNotificationResFieldNode(resPath, fieldName)
	local fallback = defaults or {x = 0, y = 0, w = 0, h = 0}
	if not (node and TF2Res and TF2Res.GetRect) then
		return table.Copy(fallback)
	end

	return TF2Res.GetRect(node, parentW or ScrW(), parentH or ScrH(), fallback)
end

local function isEconToastNotification(notification)
	if not istable(notification) then
		return false
	end

	if notification.uiStyle == "econ_toast" then
		return true
	end

	local resPath = string.lower(tostring(notification.resPath or ""))
	return string.find(resPath, "resource/ui/econ/genericnotificationtoast.res", 1, true) ~= nil
end

local function getNotificationResNode(notification, fieldName)
	local resPath = tostring((notification and notification.resPath) or defaultNotificationResPath)
	local tree = getNotificationResTree(resPath)
	if not tree then
		tree = getNotificationResTree(defaultNotificationResPath)
	end
	if not tree then
		return nil
	end

	if TF2Res.FindByKey then
		local byKey = TF2Res.FindByKey(tree, fieldName)
		if byKey then
			return byKey
		end
	end

	if TF2Res.FindByFieldName then
		return TF2Res.FindByFieldName(tree, fieldName)
	end

	return nil
end

local function localizeNotificationText(token, fallback)
	if tf_lang and tf_lang.GetRaw then
		local text = tf_lang.GetRaw(token, true)
		if isstring(text) and text ~= "" and text ~= token then
			return text
		end
	end
	return fallback
end

local function getNotificationKeyCode(cvarName, fallback)
	local cv = GetConVar(cvarName)
	if not cv then return fallback end
	local keyCode = math.max(0, math.floor(tonumber(cv:GetString()) or fallback or KEY_NONE))
	if keyCode == KEY_NONE then
		return fallback
	end
	return keyCode
end

local function getNotificationKeyLabel(cvarName, fallback)
	local keyCode = getNotificationKeyCode(cvarName, fallback)
	local name = input.GetKeyName(keyCode)
	if not isstring(name) or name == "" then
		return "?"
	end
	return string.upper(name)
end

local function formatNotificationLocalizedText(text)
	if not isstring(text) or text == "" then
		return ""
	end

	local triggerKey = getNotificationKeyLabel("cl_trigger_first_notification", KEY_J)
	local declineKey = getNotificationKeyLabel("cl_decline_first_notification", KEY_K)

	text = string.gsub(text, "%%cl_trigger_first_notification%%", triggerKey)
	text = string.gsub(text, "%%cl_decline_first_notification%%", declineKey)
	text = string.gsub(text, "[%c]", "")

	return text
end

local function getHelpText(notificationType)
	local notification = istable(notificationType) and notificationType or nil
	if notification then
		if notification.hideHelp then
			return ""
		end
		if isstring(notification.helpText) and notification.helpText ~= "" then
			return notification.helpText
		end
		if isstring(notification.helpTextToken) and notification.helpTextToken ~= "" then
			return formatNotificationLocalizedText(localizeNotificationText(notification.helpTextToken, notification.helpTextToken))
		end
		notificationType = notification.type
	end

	local helpToken = "#Notification_Remove_Help"

	if notificationType == TYPE_ACCEPT_DECLINE then
		helpToken = "#Notification_AcceptOrDecline_Help"
	elseif notificationType == TYPE_ACCEPT then
		helpToken = "#Notification_Accept_Help"
	elseif notificationType == TYPE_TRIGGER or notificationType == TYPE_MUST_TRIGGER then
		helpToken = "#Notification_CanTrigger_Help"
	end

	return formatNotificationLocalizedText(localizeNotificationText(helpToken, helpToken))
end

local function getNotificationLabelText(notification)
	local labelNode = getNotificationResNode(notification, "Notification_Label")
	if not (labelNode and TF2Res and TF2Res.GetString) then
		return nil
	end

	local labelText = TF2Res.GetString(labelNode, "labelText", "")
	if not isstring(labelText) or labelText == "" then
		return nil
	end

	if string.StartWith(labelText, "#") then
		return localizeNotificationText(labelText, labelText)
	end

	return labelText
end

local function getNotificationLayout(notification)
	local bgNode = getNotificationResNode(notification, "Notification_Background")
	local titleNode = getNotificationResNode(notification, "Notification_Title")
	local bodyNode = getNotificationResNode(notification, "Notification_Body")
	local helpNode = getNotificationResNode(notification, "Notification_Help")
	local labelNode = getNotificationResNode(notification, "Notification_Label")
	local iconNode = getNotificationResNode(notification, "Notification_Icon")

	local layout = {
		width = NOTIFY_WIDTH,
		height = NOTIFY_HEIGHT,
		background = surface.GetTextureID("hud/notification_black"),
		titleX = 14,
		titleY = 10,
		titleW = NOTIFY_WIDTH - 28,
		titleH = 22,
		titleFont = "HudFontSmallBold",
		textX = 14,
		textY = 38,
		textW = NOTIFY_WIDTH - 28,
		textH = 42,
		textFont = "Trebuchet18",
		helpX = 14,
		helpY = NOTIFY_HEIGHT - 42,
		helpW = NOTIFY_WIDTH - 28,
		helpH = 30,
		helpFont = "Trebuchet18",
	}

	if bgNode and TF2Res.GetNumber then
		layout.width = TF2Res.GetNumber(bgNode, "wide", layout.width)
		layout.height = TF2Res.GetNumber(bgNode, "tall", layout.height)
		layout.background = TF2Res.GetTextureID(bgNode, "image", "hud/notification_black")
	end

	local titleLayoutNode = titleNode or labelNode
	if titleLayoutNode and TF2Res.GetNumber then
		layout.titleX = TF2Res.GetNumber(titleLayoutNode, "xpos", layout.titleX)
		layout.titleY = TF2Res.GetNumber(titleLayoutNode, "ypos", layout.titleY)
		layout.titleW = TF2Res.GetNumber(titleLayoutNode, "wide", layout.titleW)
		layout.titleH = TF2Res.GetNumber(titleLayoutNode, "tall", layout.titleH)
		layout.titleFont = TF2Res.GetString and TF2Res.GetString(titleLayoutNode, "font", layout.titleFont) or layout.titleFont
		layout.textX = layout.titleX
		layout.textY = layout.titleY + layout.titleH + 6
		layout.textW = layout.titleW
		layout.helpX = layout.titleX
		layout.helpW = layout.titleW
		layout.helpY = math.max(layout.textY + layout.textH + 4, layout.height - 36)
	end

	if bodyNode and TF2Res.GetNumber then
		layout.textX = TF2Res.GetNumber(bodyNode, "xpos", layout.textX)
		layout.textY = TF2Res.GetNumber(bodyNode, "ypos", layout.textY)
		layout.textW = TF2Res.GetNumber(bodyNode, "wide", layout.textW)
		layout.textH = TF2Res.GetNumber(bodyNode, "tall", layout.textH)
		layout.textFont = TF2Res.GetString and TF2Res.GetString(bodyNode, "font", layout.textFont) or layout.textFont
	end

	if helpNode and TF2Res.GetNumber then
		layout.helpX = TF2Res.GetNumber(helpNode, "xpos", layout.helpX)
		layout.helpY = TF2Res.GetNumber(helpNode, "ypos", layout.helpY)
		layout.helpW = TF2Res.GetNumber(helpNode, "wide", layout.helpW)
		layout.helpH = TF2Res.GetNumber(helpNode, "tall", layout.helpH)
		layout.helpFont = TF2Res.GetString and TF2Res.GetString(helpNode, "font", layout.helpFont) or layout.helpFont
	elseif titleLayoutNode and TF2Res.GetNumber then
		layout.textX = layout.titleX
		layout.textY = layout.titleY + layout.titleH + 6
		layout.textW = layout.titleW
		layout.helpX = layout.titleX
		layout.helpW = layout.titleW
		layout.helpY = math.max(layout.textY + layout.textH + 4, layout.height - 36)
	end

	if iconNode and TF2Res.GetNumber then
		local iconVisible = TF2Res.GetNumber(iconNode, "visible", 1) ~= 0
		local iconEnabled = TF2Res.GetNumber(iconNode, "enabled", 1) ~= 0
		if iconVisible and iconEnabled then
			local iconX = TF2Res.GetNumber(iconNode, "xpos", 0)
			local iconW = TF2Res.GetNumber(iconNode, "wide", 0)
			local iconPad = math.max(0, iconX + iconW + 4)
			layout.titleX = math.max(layout.titleX, iconPad)
			layout.textX = math.max(layout.textX, iconPad)
			layout.helpX = math.max(layout.helpX, iconPad)
			layout.titleW = math.max(32, layout.width - layout.titleX - 12)
			layout.textW = math.max(32, layout.width - layout.textX - 12)
			layout.helpW = math.max(32, layout.width - layout.helpX - 12)
		end
	end

	return layout
end

local function getEconToastButtonRect(node, parentW, parentH, oneButton)
	local rect = {x = 0, y = 0, w = 20, h = 20}
	if not (node and TF2Res and TF2Res.GetRect) then
		return rect
	end

	rect = TF2Res.GetRect(node, parentW, parentH, rect)
	if oneButton and TF2Res.FindByKey then
		local oneButtonNode = TF2Res.FindByKey(node, "if_one_button")
		if oneButtonNode then
			rect.x = TF2Res.ParseCoord(TF2Res.GetString(oneButtonNode, "xpos", nil), parentW, rect.x)
		end
	end

	return rect
end

local function getNotificationButtonVisual(node, fallbackTexture)
	if not node then
		return {
			bgColor = Color(100, 90, 85, 255),
			fgColor = Color(255, 255, 255, 255),
			texture = getNotificationTextureID(fallbackTexture or ""),
			subRect = {x = 2, y = 2, w = 16, h = 16},
		}
	end

	local subImageNode = TF2Res and TF2Res.FindByFieldName and TF2Res.FindByFieldName(node, "SubImage") or nil
	local imagePath = subImageNode and TF2Res and TF2Res.GetString and TF2Res.GetString(subImageNode, "image", fallbackTexture or "") or fallbackTexture or ""
	return {
		bgColor = getNotificationResColor(node, "defaultBgColor_override", Color(100, 90, 85, 255)),
		fgColor = getNotificationResColor(node, "defaultFgColor_override", Color(255, 255, 255, 255)),
		texture = getNotificationTextureID(imagePath),
		subRect = subImageNode and TF2Res and TF2Res.GetRect and TF2Res.GetRect(subImageNode, 20, 20, {x = 2, y = 2, w = 16, h = 16}) or {x = 2, y = 2, w = 16, h = 16},
	}
end

local function getEconToastLayout(notification)
	local notifyType = resolveNotificationType(notification)
	local oneButton = notifyType == TYPE_BASIC or notifyType == TYPE_ACCEPT or notifyType == TYPE_MUST_TRIGGER
	local canDelete = notifyType == TYPE_BASIC or notifyType == TYPE_TRIGGER
	local canTrigger = notifyType == TYPE_TRIGGER or notifyType == TYPE_MUST_TRIGGER
	local canAcceptDecline = notifyType == TYPE_ACCEPT_DECLINE
	local canAccept = notifyType == TYPE_ACCEPT

	local controlPath = tostring(notification.controlResPath or econToastControlResPath)
	local containerNode = getNotificationResFieldNode(controlPath, "NotificationToastControl")
	local toastNode = getNotificationResFieldNode(notification.resPath or econToastResPath, "GenericNotificationToast")
	local textNode = getNotificationResFieldNode(notification.resPath or econToastResPath, "TextLabel")
	local helpNode = getNotificationResFieldNode(econToastContainerResPath, "HelpTextLabel")
	local triggerNode = getNotificationResFieldNode(controlPath, "TriggerButton")
	local deleteNode = getNotificationResFieldNode(controlPath, "DeleteButton")
	local acceptNode = getNotificationResFieldNode(controlPath, "AcceptButton")
	local declineNode = getNotificationResFieldNode(controlPath, "DeclineButton")

	local layout = {
		width = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(containerNode, "wide", 190) or 190,
		height = TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(containerNode, "tall", 50) or 50,
		toastRect = getNotificationResRect(notification.resPath or econToastResPath, "GenericNotificationToast", {x = 0, y = 0, w = 150, h = 50}, 190, 50),
		textRect = getNotificationResRect(notification.resPath or econToastResPath, "TextLabel", {x = 7, y = 7, w = 138, h = 38}, 150, 50),
		helpRect = getNotificationResRect(econToastContainerResPath, "HelpTextLabel", {x = 5, y = 0, w = 140, h = 20}, 150, 50),
		textFont = resolveNotificationFont(TF2Res and TF2Res.GetString and TF2Res.GetString(textNode, "font", "TFFontSmall") or "TFFontSmall", "TFFontSmall"),
		helpFont = resolveNotificationFont(TF2Res and TF2Res.GetString and TF2Res.GetString(helpNode, "font", "TFFontSmall") or "TFFontSmall", "TFFontSmall"),
		textColor = getNotificationResColor(textNode, "fgcolor", Color(235, 226, 202, 255)),
		helpColor = getNotificationResColor(helpNode, "fgcolor", Color(192, 28, 0, 255)),
		containerBorder = getNotificationResColor(containerNode, "defaultbgcolor_override", Color(208, 193, 162, 255)),
		toastBg = resolveNotificationColor("Black", Color(46, 43, 42, 240)),
		toastOutline = resolveNotificationColor("TanDark", Color(117, 107, 94, 255)),
		buttons = {},
	}

	local bodyText = wrapTextToWidth(layout.textFont, tostring(notification.text or ""), layout.textRect.w)
	local _, bodyHeight = measureTextBlock(layout.textFont, bodyText, layout.textRect.w, layout.textRect.h)
	local bottomPadding = math.max(5, layout.toastRect.h - (layout.textRect.y + layout.textRect.h))
	layout.toastRect.h = math.max(layout.toastRect.h, layout.textRect.y + bodyHeight + bottomPadding)
	layout.textRect.h = math.max(layout.textRect.h, bodyHeight)

	local helpText = wrapTextToWidth(layout.helpFont, getHelpText(notification), layout.helpRect.w)
	local _, helpHeight = measureTextBlock(layout.helpFont, helpText, layout.helpRect.w, layout.helpRect.h)
	layout.helpRect.y = layout.toastRect.h - (TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(helpNode, "textinsety", 7) or 7)
	layout.helpRect.h = math.max(layout.helpRect.h, helpHeight + (TF2Res and TF2Res.GetNumber and TF2Res.GetNumber(helpNode, "textinsety", 7) or 7))
	layout.height = math.max(layout.height, layout.toastRect.h + helpHeight + 7)

	if canTrigger then
		layout.buttons[#layout.buttons + 1] = {
			rect = getEconToastButtonRect(triggerNode, layout.width, layout.height, oneButton),
			visual = getNotificationButtonVisual(triggerNode, "glyph_view"),
		}
	end
	if canAccept then
		layout.buttons[#layout.buttons + 1] = {
			rect = getEconToastButtonRect(acceptNode, layout.width, layout.height, true),
			visual = getNotificationButtonVisual(acceptNode, "glyph_view"),
		}
	end
	if canAcceptDecline then
		layout.buttons[#layout.buttons + 1] = {
			rect = getEconToastButtonRect(acceptNode, layout.width, layout.height, false),
			visual = getNotificationButtonVisual(acceptNode, "glyph_view"),
		}
		layout.buttons[#layout.buttons + 1] = {
			rect = getEconToastButtonRect(declineNode, layout.width, layout.height, false),
			visual = getNotificationButtonVisual(declineNode, "glyph_close_X"),
		}
	end
	if canDelete then
		layout.buttons[#layout.buttons + 1] = {
			rect = getEconToastButtonRect(deleteNode, layout.width, layout.height, oneButton),
			visual = getNotificationButtonVisual(deleteNode, "glyph_close_X"),
		}
	end

	return layout
end

measureTextBlock = function(fontName, text, width, lineHeightFallback)
	if not isstring(text) or text == "" then
		return 0, 0
	end

	surface.SetFont(fontName)

	local maxWidth = math.max(1, math.floor(tonumber(width) or 1))
	local lineHeight = select(2, surface.GetTextSize("W"))
	if not isnumber(lineHeight) or lineHeight <= 0 then
		lineHeight = tonumber(lineHeightFallback) or 16
	end

	local lines = string.Explode("\n", text, false)
	local wrappedLineCount = 0
	local widest = 0

	for _, rawLine in ipairs(lines) do
		local line = tostring(rawLine or "")
		if line == "" then
			wrappedLineCount = wrappedLineCount + 1
		else
			local current = ""
			for word in string.gmatch(line, "%S+") do
				local candidate = current == "" and word or (current .. " " .. word)
				local candidateWidth = surface.GetTextSize(candidate)
				if candidateWidth > maxWidth and current ~= "" then
					local currentWidth = surface.GetTextSize(current)
					widest = math.max(widest, currentWidth)
					wrappedLineCount = wrappedLineCount + 1
					current = word
				else
					current = candidate
				end
			end

			if current ~= "" then
				local currentWidth = surface.GetTextSize(current)
				widest = math.max(widest, math.min(currentWidth, maxWidth))
				wrappedLineCount = wrappedLineCount + 1
			end
		end
	end

	wrappedLineCount = math.max(wrappedLineCount, 1)
	return widest, wrappedLineCount * lineHeight
end

wrapTextToWidth = function(fontName, text, width)
	if not isstring(text) or text == "" then
		return ""
	end

	surface.SetFont(fontName)

	local maxWidth = math.max(1, math.floor(tonumber(width) or 1))
	local outLines = {}
	local lines = string.Explode("\n", text, false)

	for _, rawLine in ipairs(lines) do
		local line = tostring(rawLine or "")
		if line == "" then
			outLines[#outLines + 1] = ""
		else
			local current = ""
			for word in string.gmatch(line, "%S+") do
				local candidate = current == "" and word or (current .. " " .. word)
				local candidateWidth = surface.GetTextSize(candidate)
				if candidateWidth > maxWidth and current ~= "" then
					outLines[#outLines + 1] = current
					current = word
				else
					current = candidate
				end
			end

			if current ~= "" then
				outLines[#outLines + 1] = current
			end
		end
	end

	return table.concat(outLines, "\n")
end

local function getSizedNotificationLayout(notification)
	local layout = getNotificationLayout(notification)

	local titleFont = layout.titleFont or "HudFontSmallBold"
	local bodyFont = layout.textFont or "Trebuchet18"
	local helpFont = layout.helpFont or "Trebuchet18"

	local titleText = tostring(notification and notification.title or "")
	if titleText == "" then
		titleText = tostring(getNotificationLabelText(notification) or "")
	end
	local bodyText = tostring(notification and notification.text or "")
	local helpText = getHelpText(notification)

	local _, titleHeight = measureTextBlock(titleFont, titleText, layout.titleW, layout.titleH)
	local _, bodyHeight = measureTextBlock(bodyFont, bodyText, layout.textW, 18)
	local _, helpHeight = measureTextBlock(helpFont, helpText, layout.helpW, 18)

	layout.titleH = math.max(layout.titleH, titleHeight)
	layout.textY = layout.titleY + layout.titleH + 6
	layout.textH = math.max(layout.textH, bodyHeight)
	layout.helpY = layout.textY + layout.textH + 8
	layout.helpH = math.max(layout.helpH, helpHeight)

	local minHeight = layout.helpY + layout.helpH + 12
	layout.height = math.max(layout.height, minHeight)

	return layout
end

resolveNotificationType = function(notification)
	local notifyType = tostring(notification.type or TYPE_BASIC)
	if notifyType ~= TYPE_ACCEPT_DECLINE
		and notifyType ~= TYPE_ACCEPT
		and notifyType ~= TYPE_TRIGGER
		and notifyType ~= TYPE_MUST_TRIGGER
	then
		return TYPE_BASIC
	end
	return notifyType
end

local function findNotificationIndex(target)
	if isnumber(target) then
		for i, notification in ipairs(TFNotificationQueue) do
			if notification.id == target then
				return i
			end
		end
	elseif istable(target) then
		local id = tonumber(target.id)
		if id then
			return findNotificationIndex(id)
		end
	end
	return nil
end

local function removeNotificationAt(index)
	local notification = TFNotificationQueue[index]
	if not notification then return nil end
	table.remove(TFNotificationQueue, index)
	return notification
end

local function invokeNotificationCallback(notification, reason)
	if not istable(notification) then return end

	local callback = notification.OnRemove
	if reason == "expired" and isfunction(notification.OnExpire) then
		callback = notification.OnExpire
	end

	if isfunction(callback) then
		callback(notification, reason)
	end
end

function NotificationQueue_Add(notification)
	if not istable(notification) then return nil end

	if notification.key ~= nil then
		for _, existing in ipairs(TFNotificationQueue) do
			if existing.key == notification.key then
				return existing.id
			end
		end
	end

	notification.id = TFNotificationNextID
	TFNotificationNextID = TFNotificationNextID + 1
	notification.type = resolveNotificationType(notification)
	notification.addedAt = CurTime()
	notification.expireAt = notification.expireAt or (CurTime() + (tonumber(notification.lifetime) or 10))
	TFNotificationQueue[#TFNotificationQueue + 1] = notification

	local soundPath = notification.sound
	if soundPath ~= false then
		soundPath = tostring(soundPath or defaultNotificationSound)
	end
	if isstring(soundPath) and soundPath ~= "" then
		surface.PlaySound(soundPath)
	end

	return notification.id
end

function NotificationQueue_Remove(target)
	if isfunction(target) then
		for i = #TFNotificationQueue, 1, -1 do
			if target(TFNotificationQueue[i]) then
				local notification = removeNotificationAt(i)
				invokeNotificationCallback(notification, "removed")
			end
		end
		return
	end

	local index = findNotificationIndex(target)
	if index then
		local notification = removeNotificationAt(index)
		invokeNotificationCallback(notification, "removed")
	end
end

function NotificationQueue_Count(predicate)
	local count = 0
	if not isfunction(predicate) then
		return #TFNotificationQueue
	end
	for _, notification in ipairs(TFNotificationQueue) do
		if predicate(notification) then
			count = count + 1
		end
	end
	return count
end

function NotificationQueue_GetNumNotifications()
	return #TFNotificationQueue
end

function NotificationQueue_Get(id)
	for _, notification in ipairs(TFNotificationQueue) do
		if notification.id == id then
			return notification
		end
	end
	return nil
end

function NotificationQueue_GetByIndex(index)
	index = tonumber(index) or 0
	return TFNotificationQueue[index + 1] or TFNotificationQueue[index]
end

function NotificationQueue_Update()
	local now = CurTime()
	for i = #TFNotificationQueue, 1, -1 do
		local notification = TFNotificationQueue[i]
		if (tonumber(notification.expireAt) or math.huge) <= now then
			notification = removeNotificationAt(i)
			invokeNotificationCallback(notification, "expired")
		end
	end
end

local PANEL = {}

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetVisible(true)
	self.NotificationID = nil
end

function PANEL:PerformLayout()
	local notification = self.NotificationID and NotificationQueue_Get(self.NotificationID) or nil
	local layout = isEconToastNotification(notification) and getEconToastLayout(notification) or getSizedNotificationLayout(notification)
	self:SetSize(layout.width, layout.height)
	self:SetPos(ScrW() - layout.width - 22, math.floor((ScrH() * 0.5) - (layout.height * 0.5)))
end

function PANEL:Paint(w, h)
	local notification = self.NotificationID and NotificationQueue_Get(self.NotificationID) or nil
	if not notification then return end

	if isEconToastNotification(notification) then
		local layout = getEconToastLayout(notification)
		local bodyText = wrapTextToWidth(layout.textFont, tostring(notification.text or ""), layout.textRect.w)
		local helpText = wrapTextToWidth(layout.helpFont, getHelpText(notification), layout.helpRect.w)

		draw.RoundedBox(4, layout.toastRect.x, layout.toastRect.y, layout.toastRect.w, layout.toastRect.h, layout.toastBg)
		surface.SetDrawColor(layout.toastOutline.r, layout.toastOutline.g, layout.toastOutline.b, layout.toastOutline.a)
		surface.DrawOutlinedRect(layout.toastRect.x, layout.toastRect.y, layout.toastRect.w, layout.toastRect.h, 1)

		for _, button in ipairs(layout.buttons) do
			local rect = button.rect
			local visual = button.visual
			draw.RoundedBox(2, rect.x, rect.y, rect.w, rect.h, visual.bgColor)
			surface.SetDrawColor(layout.containerBorder.r, layout.containerBorder.g, layout.containerBorder.b, layout.containerBorder.a)
			surface.DrawOutlinedRect(rect.x, rect.y, rect.w, rect.h, 1)

			if visual.texture and visual.texture > 0 then
				surface.SetDrawColor(visual.fgColor.r, visual.fgColor.g, visual.fgColor.b, visual.fgColor.a)
				surface.SetTexture(visual.texture)
				surface.DrawTexturedRect(rect.x + visual.subRect.x, rect.y + visual.subRect.y, visual.subRect.w, visual.subRect.h)
			end
		end

		draw.DrawText(bodyText, layout.textFont, layout.textRect.x, layout.textRect.y, layout.textColor, TEXT_ALIGN_LEFT)
		draw.DrawText(helpText, layout.helpFont, layout.helpRect.x, layout.toastRect.h, layout.helpColor, TEXT_ALIGN_LEFT)
		return
	end

	local layout = getSizedNotificationLayout(notification)
	local titleText = tostring(notification.title or "")
	if titleText == "" then
		titleText = tostring(getNotificationLabelText(notification) or "")
	end
	titleText = wrapTextToWidth(layout.titleFont or "HudFontSmallBold", titleText, layout.titleW)
	local bodyText = wrapTextToWidth(layout.textFont or "Trebuchet18", tostring(notification.text or ""), layout.textW)
	local helpText = wrapTextToWidth(layout.helpFont or "Trebuchet18", getHelpText(notification), layout.helpW)

	if layout.background and layout.background > 0 then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetTexture(layout.background)
		surface.DrawTexturedRect(0, 0, w, h)
	else
		draw.RoundedBox(8, 0, 0, w, h, Color(36, 32, 30, 240))
		surface.SetDrawColor(246, 231, 193, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
	end

	draw.DrawText(titleText, layout.titleFont or "HudFontSmallBold", layout.titleX, layout.titleY, Color(243, 241, 232, 255), TEXT_ALIGN_LEFT)
	draw.DrawText(bodyText, layout.textFont or "Trebuchet18", layout.textX, layout.textY, Color(243, 241, 232, 255), TEXT_ALIGN_LEFT)
	draw.DrawText(helpText, layout.helpFont or "Trebuchet18", layout.helpX, layout.helpY, Color(243, 241, 232, 255), TEXT_ALIGN_LEFT)
end

vgui.Register("TFNotificationPanel", PANEL, "DPanel")

local function ensureNotificationPanel()
	if not IsValid(TFNotificationPanel) then
		TFNotificationPanel = vgui.Create("TFNotificationPanel")
	end
	return TFNotificationPanel
end

local function acceptTopNotification()
	local notification = NotificationQueue_GetByIndex(0)
	if not notification then return end
	local notifyType = resolveNotificationType(notification)
	local callback = nil

	if notifyType == TYPE_ACCEPT_DECLINE or notifyType == TYPE_ACCEPT then
		callback = notification.OnAccept or notification.Accept
	elseif notifyType == TYPE_TRIGGER or notifyType == TYPE_MUST_TRIGGER then
		callback = notification.OnTrigger or notification.Trigger
	end

	NotificationQueue_Remove(notification.id)
	if isfunction(callback) then
		callback(notification)
	end
end

local function declineTopNotification()
	local notification = NotificationQueue_GetByIndex(0)
	if not notification then return end
	local notifyType = resolveNotificationType(notification)
	if notifyType == TYPE_MUST_TRIGGER then
		return
	end

	local callback = nil
	if notifyType == TYPE_ACCEPT_DECLINE then
		callback = notification.OnDecline or notification.Decline
	elseif notifyType == TYPE_BASIC or notifyType == TYPE_TRIGGER then
		callback = notification.OnDelete or notification.Deleted
	end

	NotificationQueue_Remove(notification.id)
	if isfunction(callback) then
		callback(notification)
	end
end

hook.Add("Think", "TF2GM_NotificationQueueThink", function()
	NotificationQueue_Update()

	local showInGame = GetConVar("cl_notifications_show_ingame")
	if showInGame and not showInGame:GetBool() then
		if IsValid(TFNotificationPanel) then
			TFNotificationPanel:SetVisible(false)
			TFNotificationPanel.NotificationID = nil
		end
		return
	end

	local notification = NotificationQueue_GetByIndex(0)
	if notification then
		local panel = ensureNotificationPanel()
		panel.NotificationID = notification.id
		panel:SetVisible(true)
	else
		if IsValid(TFNotificationPanel) then
			TFNotificationPanel:SetVisible(false)
			TFNotificationPanel.NotificationID = nil
		end
	end

	local acceptKey = getNotificationKeyCode("cl_trigger_first_notification", KEY_J)
	local declineKey = getNotificationKeyCode("cl_decline_first_notification", KEY_K)
	local acceptDown = input.IsKeyDown(acceptKey)
	local declineDown = input.IsKeyDown(declineKey)

	if notification then
		if acceptDown and not TFNotificationAcceptDown then
			local notifyType = resolveNotificationType(notification)
			if notifyType == TYPE_ACCEPT_DECLINE
				or notifyType == TYPE_ACCEPT
				or notifyType == TYPE_TRIGGER
				or notifyType == TYPE_MUST_TRIGGER
			then
				acceptTopNotification()
				TFNotificationAcceptDown = acceptDown
				TFNotificationDeclineDown = declineDown
				return
			end
		end

		if declineDown and not TFNotificationDeclineDown then
			declineTopNotification()
			TFNotificationAcceptDown = acceptDown
			TFNotificationDeclineDown = declineDown
			return
		end
	end

	TFNotificationAcceptDown = acceptDown
	TFNotificationDeclineDown = declineDown
end)

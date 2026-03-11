local function LocalizeBossToken(token, fallback)
    if tf_lang and tf_lang.GetRaw then
        local raw = tf_lang.GetRaw(token, true)
        if isstring(raw) and raw ~= "" then
            return raw
        end
    end
    return fallback or token or ""
end

local function SanitizeBossText(text)
    text = tostring(text or "")
    text = string.gsub(text, "[%c]", "")
    return string.Trim(text)
end

local function BuildFallbackText(eventName, scenario, playerName, secondsRemaining)
    playerName = tostring(playerName or "")
    if eventName == "appeared" then
        if scenario == "viaduct" then
            return "MONOCULUS! has appeared!"
        elseif scenario == "lakeside" then
            return "MERASMUS! has appeared!"
        elseif scenario == "hightower" then
            return "The Skeleton King has appeared!"
        end
        return "The Horseless Headless Horsemann has appeared!"
    end

    if eventName == "killed" then
        if scenario == "viaduct" then
            return "MONOCULUS! has been defeated!"
        elseif scenario == "lakeside" then
            return "MERASMUS! has been defeated!"
        elseif scenario == "hightower" then
            return "The Skeleton King has been defeated!"
        end
        return "The Horseless Headless Horsemann has been defeated!"
    end

    if eventName == "killer" and playerName ~= "" then
        return playerName .. " defeated the boss!"
    end

    if eventName == "stun" and playerName ~= "" then
        if scenario == "viaduct" then
            return playerName .. " has stunned MONOCULUS!"
        end
    end

    if eventName == "escaped" then
        if scenario == "viaduct" then
            return "MONOCULUS! has left to haunt another realm!"
        elseif scenario == "lakeside" then
            return "MERASMUS! has gone home!"
        elseif scenario == "hightower" then
            return "The Skeleton King has returned to the underworld!"
        end
        return "The boss has disappeared!"
    end

    if eventName == "warning" then
        local secs = math.max(0, math.floor(tonumber(secondsRemaining) or 0))
        if scenario == "viaduct" then
            return "MONOCULUS! is leaving in " .. secs .. " seconds..."
        elseif scenario == "lakeside" then
            return "MERASMUS! is leaving in " .. secs .. " seconds..."
        elseif scenario == "hightower" then
            return "The Skeleton King leaves in " .. secs .. " seconds..."
        end
    end

    return ""
end

local function ResolveBossMessage(eventName, scenario, token, playerName, secondsRemaining)
    local fallback = BuildFallbackText(eventName, scenario, playerName, secondsRemaining)
    local message = LocalizeBossToken(token, fallback)
    message = string.gsub(message, "%%player%%", tostring(playerName or ""))
    message = string.gsub(message, "%%s1%%", tostring(playerName or ""))
    message = string.gsub(message, "%%s2%%", "")
    message = string.gsub(message, "%%time%%", tostring(math.max(0, math.floor(tonumber(secondsRemaining) or 0))))
    return SanitizeBossText(message)
end

net.Receive("TF_HalloweenBossEvent", function()
    local eventName = net.ReadString()
    local scenario = net.ReadString()
    local token = net.ReadString()
    local playerName = net.ReadString()
    local secondsRemaining = net.ReadUInt(16)

    local message = ResolveBossMessage(eventName, scenario, token, playerName, secondsRemaining)
    if message == "" then return end

    chat.AddText(Color(255, 160, 60), "[Halloween] ", Color(245, 245, 245), message)
    notification.AddLegacy(message, NOTIFY_GENERIC, 5)
    surface.PlaySound("ui/halloween_loot_spawn.wav")
end)

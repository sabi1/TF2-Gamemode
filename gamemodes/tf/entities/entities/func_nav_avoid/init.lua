ENT.Base = "base_brush"
ENT.Type = "brush"

local function to_bool(value, default)
	if value == nil then return default end
	if isbool(value) then return value end
	local num = tonumber(value)
	if num ~= nil then return num ~= 0 end
	local text = string.lower(string.Trim(tostring(value)))
	if text == "true" or text == "yes" or text == "on" then return true end
	if text == "false" or text == "no" or text == "off" then return false end
	return default
end

local function split_tags(raw)
	local out = {}
	for token in string.gmatch(tostring(raw or ""), "%S+") do
		out[#out + 1] = string.lower(token)
	end
	return out
end

local function point_inside_brush(ent, point)
	if not (IsValid(ent) and isvector(point)) then return false end
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	local localPos = ent:WorldToLocal(point)
	return localPos.x >= mins.x and localPos.x <= maxs.x
		and localPos.y >= mins.y and localPos.y <= maxs.y
		and localPos.z >= mins.z and localPos.z <= maxs.z
end

local function zone_matches_team(zone, bot)
	local teamNum = tonumber(zone.Properties.team) or -2
	if teamNum == -2 or teamNum == -1 then
		return true
	end
	if not IsValid(bot) or not bot.Team then return false end
	return bot:Team() == teamNum
end

local function zone_matches_tags(zone, bot)
	local tags = zone.Tags or split_tags(zone.Properties.tags)
	if #tags == 0 then
		return true
	end
	if not IsValid(bot) then return false end

	local botClass = bot.GetPlayerClass and string.lower(tostring(bot:GetPlayerClass() or "")) or ""
	for _, tag in ipairs(tags) do
		if tag == "common" then
			return true
		end
		if tag == botClass then
			return true
		end
		if tag == "bomb_carrier" and bot.HasTheFlag and bot:HasTheFlag() then
			return true
		end
		if bot.HasTag then
			local ok, has = pcall(bot.HasTag, bot, tag)
			if ok and has then
				return true
			end
		end
		local nwTags = bot.GetNWString and string.lower(bot:GetNWString("TFBotTags", "")) or ""
		if nwTags ~= "" and string.find(" " .. nwTags .. " ", " " .. tag .. " ", 1, true) then
			return true
		end
	end
	return false
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Tags = split_tags(self.Properties.tags)
	self.Enabled = not to_bool(self.Properties.start_disabled, false)
	if SERVER then
		GAMEMODE.NavAvoidZones = GAMEMODE.NavAvoidZones or {}
		GAMEMODE.NavAvoidZones[self] = true
	end
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if key == "tags" then
		self.Tags = split_tags(value)
	elseif key == "start_disabled" then
		self.Enabled = not to_bool(value, false)
	end
end

function ENT:StartTouch(ent)
end

function ENT:EndTouch(ent)
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Enabled = true
		return true
	elseif name == "disable" then
		self.Enabled = false
		return true
	elseif name == "toggle" then
		self.Enabled = not self.Enabled
		return true
	end
	return false
end

function ENT:OnRemove()
	if SERVER and GAMEMODE.NavAvoidZones then
		GAMEMODE.NavAvoidZones[self] = nil
	end
end

function ENT:IsApplicableTo(bot)
	return self.Enabled == true and zone_matches_team(self, bot) and zone_matches_tags(self, bot)
end

function ENT:ContainsPoint(pos)
	return point_inside_brush(self, pos)
end

function TF_IsPointInNavAvoidZone(bot, pos)
	if not (GAMEMODE and GAMEMODE.NavAvoidZones) then return false end
	for zone in pairs(GAMEMODE.NavAvoidZones) do
		if IsValid(zone) and zone:IsApplicableTo(bot) and zone:ContainsPoint(pos) then
			return true
		end
	end
	return false
end

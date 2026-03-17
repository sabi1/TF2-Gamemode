ENT.Type = "point"

local HOLIDAY_TFBIRTHDAY = 1
local HOLIDAY_HALLOWEEN = 2
local HOLIDAY_CHRISTMAS = 3
local HOLIDAY_VALENTINES = 6
local HOLIDAY_FULLMOON = 8
local HOLIDAY_HALLOWEEN_OR_FULLMOON = 9
local HOLIDAY_HALLOWEEN_OR_FULLMOON_OR_VALENTINES = 10
local HOLIDAY_APRILFOOLS = 11

local function IsDateInWindow(month, day, startMonth, startDay, endMonth, endDay)
	local current = month * 100 + day
	local startDate = startMonth * 100 + startDay
	local endDate = endMonth * 100 + endDay

	if startDate <= endDate then
		return current >= startDate and current <= endDate
	end

	return current >= startDate or current <= endDate
end

local function IsFullMoonDate(year, month, day)
	local base = os.time({
		year = 2025,
		month = 10,
		day = 6,
		hour = 12,
		min = 0,
		sec = 0,
	})
	local current = os.time({
		year = year,
		month = month,
		day = day,
		hour = 12,
		min = 0,
		sec = 0,
	})
	if not base or not current then
		return false
	end

	local cycle = 29.53 * 24 * 60 * 60
	local offset = math.abs(current - base)
	local remainder = offset % cycle
	local distance = math.min(remainder, cycle - remainder)
	return distance <= 24 * 60 * 60
end

local function GetHolidayMask()
	local now = os.date("*t")
	local month = tonumber(now.month) or 1
	local day = tonumber(now.day) or 1
	local year = tonumber(now.year) or 2026
	local forcedHoliday = tonumber((GetConVar("tf_forced_holiday") and GetConVar("tf_forced_holiday"):GetInt()) or 0) or 0
	local mapHoliday = tonumber(GAMEMODE and GAMEMODE.HalloweenHolidayType) or 0
	local mask = {
		tfBirthday = false,
		halloween = false,
		smissmas = false,
		valentines = false,
		fullMoon = false,
		aprilFools = false,
	}

	mask.tfBirthday = forcedHoliday == HOLIDAY_TFBIRTHDAY or IsDateInWindow(month, day, 8, 23, 8, 25)
	mask.halloween = forcedHoliday == HOLIDAY_HALLOWEEN
		or forcedHoliday == HOLIDAY_HALLOWEEN_OR_FULLMOON
		or forcedHoliday == HOLIDAY_HALLOWEEN_OR_FULLMOON_OR_VALENTINES
		or mapHoliday == HOLIDAY_HALLOWEEN
		or mapHoliday == HOLIDAY_HALLOWEEN_OR_FULLMOON
		or mapHoliday == HOLIDAY_HALLOWEEN_OR_FULLMOON_OR_VALENTINES
		or IsDateInWindow(month, day, 10, 1, 11, 8)
	mask.smissmas = forcedHoliday == HOLIDAY_CHRISTMAS or IsDateInWindow(month, day, 12, 1, 1, 8)
	mask.valentines = forcedHoliday == HOLIDAY_VALENTINES
		or forcedHoliday == HOLIDAY_HALLOWEEN_OR_FULLMOON_OR_VALENTINES
		or mapHoliday == HOLIDAY_VALENTINES
		or mapHoliday == HOLIDAY_HALLOWEEN_OR_FULLMOON_OR_VALENTINES
		or IsDateInWindow(month, day, 2, 13, 2, 15)
	mask.fullMoon = forcedHoliday == HOLIDAY_FULLMOON
		or forcedHoliday == HOLIDAY_HALLOWEEN_OR_FULLMOON
		or forcedHoliday == HOLIDAY_HALLOWEEN_OR_FULLMOON_OR_VALENTINES
		or mapHoliday == HOLIDAY_FULLMOON
		or mapHoliday == HOLIDAY_HALLOWEEN_OR_FULLMOON
		or mapHoliday == HOLIDAY_HALLOWEEN_OR_FULLMOON_OR_VALENTINES
		or IsFullMoonDate(year, month, day)
	mask.aprilFools = forcedHoliday == HOLIDAY_APRILFOOLS or IsDateInWindow(month, day, 3, 31, 4, 2)

	return mask
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
end

function ENT:KeyValue(key, value)
	if string.Left(key, 2) == "On" then
		self:StoreOutput(key, value)
	end

	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name ~= "fire" then
		return false
	end

	local holidays = GetHolidayMask()
	local fired = false

	if holidays.aprilFools then
		self:TriggerOutput("IsAprilFools", self)
		fired = true
	end
	if holidays.fullMoon then
		self:TriggerOutput("IsFullMoon", self)
		fired = true
	end
	if holidays.halloween then
		self:TriggerOutput("IsHalloween", self)
		fired = true
	end
	if holidays.smissmas then
		self:TriggerOutput("IsSmissmas", self)
		fired = true
	end
	if holidays.tfBirthday then
		self:TriggerOutput("IsTFBirthday", self)
		fired = true
	end
	if holidays.valentines then
		self:TriggerOutput("IsValentines", self)
		fired = true
	end

	if not fired then
		self:TriggerOutput("IsNothing", self)
	end

	return true
end

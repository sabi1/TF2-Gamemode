TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.Vision = TFBotValveAI.Vision or {}

local M = TFBotValveAI.Vision

local cv_choose = CreateConVar("tf_bot_choose_target_interval", "0.30", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How often, in seconds, a bot can reselect its target.")
local cv_sniper_choose = CreateConVar("tf_bot_sniper_choose_target_interval", "3.0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How often a zoomed sniper can reselect its target.")
local cv_range = CreateConVar("tf_bot_vision_range", "6000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Maximum vision range for bot target acquisition.")
local cv_lost = CreateConVar("tf_bot_target_lost_time", "1.25", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How long bots remember a target after LOS loss.")
local cv_mvm_scan_min = CreateConVar("tf_bot_mvm_scan_interval_min", "0.90", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Minimum MvM scan interval (mirrors TF2 perf-throttled robot vision cadence).")
local cv_mvm_scan_max = CreateConVar("tf_bot_mvm_scan_interval_max", "1.10", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Maximum MvM scan interval (mirrors TF2 perf-throttled robot vision cadence).")

local function isValidTarget(bot, target)
	if not IsValid(bot) or not IsValid(target) then return false end
	if target:EntIndex() == bot:EntIndex() then return false end
	if target.IsPlayer and target:IsPlayer() then
		if not target:Alive() then return false end
		if target:IsFriendly(bot) then return false end
		return true
	end
	if target.GetClass then
		local class = string.lower(target:GetClass() or "")
		if class == "obj_sentrygun" or class == "obj_dispenser" or class == "obj_teleporter" then
			return not target:IsFriendly(bot)
		end
	end
	return false
end

function M:GetChooseInterval(bot)
	local base = math.max(cv_choose:GetFloat(), 0.05)
	if IsValid(bot) and bot.IsMVMRobot then
		local lo = math.max(cv_mvm_scan_min:GetFloat(), 0.1)
		local hi = math.max(cv_mvm_scan_max:GetFloat(), lo)
		base = math.max(base, math.Rand(lo, hi))
	end
	if IsValid(bot) and bot.playerclass == "Sniper" then
		local wep = bot:GetActiveWeapon()
		if IsValid(wep) and wep.ZoomStatus then
			return math.max(cv_sniper_choose:GetFloat(), base)
		end
	end
	return base
end

function M:UpdateMemory(bot, state, target, visible, now)
	local id = target:EntIndex()
	local info = state.vision.memory[id]
	if not info then
		info = { firstSeen = now, lastSeen = 0, recognized = false }
		state.vision.memory[id] = info
	end

	if visible then
		info.lastSeen = now
		local recognizeTime = 0.5
		local diff = tonumber(bot and bot.Difficulty) or 1
		if diff <= 0 then recognizeTime = 1.0
		elseif diff >= 2 then recognizeTime = 0.3 end
		if diff >= 3 then recognizeTime = 0.2 end
		if (now - info.firstSeen) >= recognizeTime then
			info.recognized = true
		end
	end

	return info
end

function M:CanTrack(bot, state, target, now)
	if not isValidTarget(bot, target) then return false end
	local distance = bot:GetPos():Distance(target:GetPos())
	local limit = math.max(cv_range:GetFloat(), 256)
	if IsValid(bot) then
		local fromDef = tonumber(bot.TF_MVM_MaxVisionRange or bot.VisionLimits)
		if fromDef and fromDef > 0 then
			limit = math.max(fromDef, 256)
		end
	end
	if distance > limit then return false end
	local visible = bot:Visible(target)
	local info = self:UpdateMemory(bot, state, target, visible, now)
	if visible then
		return info.recognized == true
	end
	if info.recognized and info.lastSeen and (now - info.lastSeen) <= math.max(cv_lost:GetFloat(), 0.1) then
		return true
	end
	return false
end

return M

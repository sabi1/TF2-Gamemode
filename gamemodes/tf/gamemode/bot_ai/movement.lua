TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.Movement = TFBotValveAI.Movement or {}

local M = TFBotValveAI.Movement

local cv_sep_range = CreateConVar("tf_bot_teammate_separation_range", "72", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local cv_sep_push = CreateConVar("tf_bot_teammate_separation_push", "220", {FCVAR_ARCHIVE, FCVAR_NOTIFY})

local function getBotRunSpeed(bot)
	if not IsValid(bot) then return 300 end
	local classSpeed = tonumber(bot.GetClassSpeed and bot:GetClassSpeed() or 0) or 0
	if classSpeed > 0 then
		return classSpeed
	end
	local runSpeed = tonumber(bot.GetRunSpeed and bot:GetRunSpeed() or 0) or 0
	if runSpeed > 0 then
		return runSpeed
	end
	local classTable = bot.GetPlayerClassTable and bot:GetPlayerClassTable() or nil
	local tableSpeed = tonumber(classTable and classTable.Speed or 0) or 0
	if tableSpeed > 0 then
		return tableSpeed
	end
	return 300
end

local function ensureBotMoveSpeed(bot)
	if not IsValid(bot) or not bot:IsPlayer() then return end
	local desired = getBotRunSpeed(bot)
	if desired <= 0 then return end

	if bot.SetClassSpeed and math.abs((tonumber(bot.GetClassSpeed and bot:GetClassSpeed() or 0) or 0) - desired) > 1 then
		bot:SetClassSpeed(desired)
	end
	if bot.SetRunSpeed and math.abs((tonumber(bot.GetRunSpeed and bot:GetRunSpeed() or 0) or 0) - desired) > 1 then
		bot:SetRunSpeed(desired)
	end
	if bot.SetWalkSpeed and math.abs((tonumber(bot.GetWalkSpeed and bot:GetWalkSpeed() or 0) or 0) - desired) > 1 then
		bot:SetWalkSpeed(desired)
	end
end

local function autoJumpIfNeeded(bot, cmd)
	if not IsValid(bot) or not bot:IsOnGround() then return end
	local mins = tonumber(bot.TF_MVM_AutoJumpMin or 24) or 24
	local maxs = tonumber(bot.TF_MVM_AutoJumpMax or 60) or 60
	local forward = bot:GetForward()
	local startPos = bot:GetPos() + Vector(0, 0, math.max(6, mins * 0.15))
	local tr = util.TraceHull({
		start = startPos,
		endpos = startPos + forward * 46,
		filter = bot,
		mask = MASK_PLAYERSOLID,
		mins = Vector(-14, -14, 0),
		maxs = Vector(14, 14, math.max(mins, maxs)),
	})
	if tr.Hit and tr.HitNormal.z < 0.7 then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
	end
end

local function applyTeamSeparation(bot, cmd, state)
	if not IsValid(bot) then return end
	local base = TFBotValveAI and TFBotValveAI.Base or nil
	local mates = (base and base.GetManagedAgents and base:GetManagedAgents()) or player.GetBots()
	local range = math.max(24, cv_sep_range:GetFloat())
	local range2 = range * range
	local myPos = bot:GetPos()
	local repel = Vector(0, 0, 0)
	local closeCount = 0

	for _, other in ipairs(mates) do
		if not IsValid(other) or other == bot then continue end
		if base and base.IsAlive then
			if not base:IsAlive(other) then continue end
		else
			if not other.Alive or not other:Alive() then continue end
		end
		if other:Team() ~= bot:Team() then continue end
		local delta = myPos - other:GetPos()
		delta.z = 0
		local d2 = delta:LengthSqr()
		if d2 <= 1 or d2 > range2 then continue end
		local w = 1.0 - math.sqrt(d2) / range
		repel:Add(delta:GetNormalized() * w)
		closeCount = closeCount + 1
	end

	if closeCount <= 0 or repel:LengthSqr() <= 0.01 then
		return
	end

	local push = cv_sep_push:GetFloat()
	local runSpeed = getBotRunSpeed(bot)
	local right = bot:GetRight()
	local sideSign = (repel:Dot(right) >= 0) and 1 or -1
	local sideMove = (cmd.GetSideMove and cmd:GetSideMove()) or 0
	cmd:SetSideMove(sideMove + (sideSign * math.min(push, runSpeed)))

	-- Keep bomb carrier pace stable while still adding side separation.
	local isCarrier = state and state.mvm and state.mvm.isCarrier == true
	-- Preserve class run speed unless a heavily compressed non-carrier pack is
	-- already overdriving; don't turn congestion into a permanent slow walk.
	if closeCount >= 3 and not isCarrier then
		local fwd = (cmd.GetForwardMove and cmd:GetForwardMove()) or 0
		if math.abs(fwd) > runSpeed then
			cmd:SetForwardMove((fwd >= 0 and 1 or -1) * runSpeed)
		end
	end
end

function M:Apply(bot, cmd, state)
	if not IsValid(bot) or not state then return end
	if not bot:Alive() then return end

	ensureBotMoveSpeed(bot)

	local cfg = TFBotValveAI.Config
	if cfg and cfg:UseLegacyPathCompat() then
		return
	end

	local pathing = TFBotValveAI.Pathing
	local mvm = state.mvm
	cmd:ClearMovement()
	cmd:RemoveKey(IN_DUCK)
	if bot:GetNWBool("Taunting", false) then
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		cmd:SetUpMove(0)
		cmd:RemoveKey(IN_JUMP)
		cmd:RemoveKey(IN_DUCK)
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
		return
	end

	if mvm and mvm.mode == "mvm_deploy_bomb" and (mvm.deployState == "delay" or mvm.deployState == "animating" or mvm.deployState == "complete") then
		local zone = state.objective.targetEnt
		if IsValid(zone) then
			local ang = (zone:GetPos() - bot:GetShootPos()):Angle()
			cmd:SetViewAngles(ang)
			bot:SetEyeAngles(ang)
		end
		cmd:SetForwardMove(0)
		return
	end

	pathing:Drive(bot, cmd, state)
	applyTeamSeparation(bot, cmd, state)
	if bot.TF_MVM_AutoJump then
		autoJumpIfNeeded(bot, cmd)
	end
end

return M

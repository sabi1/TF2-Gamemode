TFBotValveAI = TFBotValveAI or {}
TFBotValveAI.Base = TFBotValveAI.Base or {}

local M = TFBotValveAI.Base

local BUTTON_BITS = {
	IN_ATTACK = IN_ATTACK or 1,
	IN_JUMP = IN_JUMP or 2,
	IN_DUCK = IN_DUCK or 4,
}

local function aliveNextBot(ent)
	if not IsValid(ent) then return false end
	if ent.Health then
		return ent:Health() > 0
	end
	return true
end

function M:IsPlayerAgent(ent)
	return IsValid(ent) and ent:IsPlayer() and ent:IsBot() and ent.TFBot == true
end

function M:IsNextBotAgent(ent)
	return IsValid(ent) and ent.IsTFBotValveBase == true
end

function M:IsManaged(ent)
	return self:IsPlayerAgent(ent) or self:IsNextBotAgent(ent)
end

function M:IsAlive(ent)
	if self:IsPlayerAgent(ent) then
		return ent:Alive()
	end
	if self:IsNextBotAgent(ent) then
		return aliveNextBot(ent)
	end
	return false
end

function M:GetManagedAgents()
	local cfg = TFBotValveAI.Config
	local agents = {}
	if cfg and cfg:UsePlayerBackend() then
		for _, bot in ipairs(player.GetBots()) do
			if self:IsPlayerAgent(bot) then
				table.insert(agents, bot)
			end
		end
	end
	if cfg and cfg:UseNextBotBackend() then
		for _, bot in ipairs(ents.FindByClass("tf_bot_base_nextbot")) do
			if self:IsNextBotAgent(bot) then
				table.insert(agents, bot)
			end
		end
	end
	return agents
end

function M:MakeFakeCmd()
	local cmd = {
		_buttons = 0,
		_forward = 0,
		_side = 0,
		_view = nil,
	}
	function cmd:ClearMovement()
		self._forward = 0
		self._side = 0
	end
	function cmd:RemoveKey(bitv)
		self._buttons = bit.band(self._buttons, bit.bnot(bitv))
	end
	function cmd:SetForwardMove(v)
		self._forward = tonumber(v) or 0
	end
	function cmd:SetSideMove(v)
		self._side = tonumber(v) or 0
	end
	function cmd:SetViewAngles(v)
		self._view = v
	end
	function cmd:GetButtons()
		return self._buttons
	end
	function cmd:SetButtons(v)
		self._buttons = tonumber(v) or 0
	end
	function cmd:GetViewAngles()
		return self._view
	end
	return cmd
end

function M:ApplyNextBotModules(bot, state, movement, combat)
	if not IsValid(bot) or not state then return end
	local cmd = self:MakeFakeCmd()
	movement:Apply(bot, cmd, state)
	combat:Update(bot, cmd, state)

	bot._tfbotFakeCmd = cmd
	bot._tfbotDesiredPos = state.objective and state.objective.targetPos or nil
	bot._tfbotDesiredView = cmd:GetViewAngles()
	bot._tfbotDesiredSpeed = math.max(math.abs(cmd._forward or 0), 80)
	bot._tfbotWantsJump = bit.band(cmd:GetButtons(), BUTTON_BITS.IN_JUMP) ~= 0
	bot._tfbotWantsAttack = bit.band(cmd:GetButtons(), BUTTON_BITS.IN_ATTACK) ~= 0
end

return M

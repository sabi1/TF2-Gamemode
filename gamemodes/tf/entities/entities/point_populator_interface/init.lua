ENT.Type = "point"

local function get_mvm_runtime()
	if not TF_MVM or not TF_MVM.Runtime then
		return nil
	end
	return TF_MVM.Runtime
end

local function get_living_invader_bots()
	local rt = get_mvm_runtime()
	if not rt or not rt.ManagedBots then
		return {}
	end

	local out = {}
	for bot in pairs(rt.ManagedBots) do
		if IsValid(bot) and bot:Health() > 0 and bot:Team() == TEAM_BLU then
			out[#out + 1] = bot
		end
	end
	return out
end

local function populatorDebugEnabled()
	local cvar = GetConVar("tf_populator_debug")
	return cvar and cvar:GetBool() or false
end

local function hasEventChangeAttributes(runtime, eventName)
	eventName = string.Trim(string.lower(tostring(eventName or "")))
	if eventName == "" then
		return false
	end

	local mission = runtime and runtime.Mission
	if not istable(mission) then
		return false
	end

	local found = false
	local function scan(node)
		if found or not istable(node) then
			return
		end

		for key, value in pairs(node) do
			if string.lower(tostring(key or "")) == "eventchangeattributes" and istable(value) then
				for eventKey in pairs(value) do
					if string.Trim(string.lower(tostring(eventKey or ""))) == eventName then
						found = true
						return
					end
				end
			end

			if istable(value) then
				scan(value)
				if found then
					return
				end
			end
		end
	end

	scan(mission)
	return found
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:Input_PauseBotSpawning()
	local rt = get_mvm_runtime()
	if rt and rt.PauseSpawning then
		rt:PauseSpawning()
	end
end

function ENT:Input_UnpauseBotSpawning()
	local rt = get_mvm_runtime()
	if rt and rt.UnpauseSpawning then
		rt:UnpauseSpawning()
	end
end

function ENT:Input_ChangeBotAttributes(_, _, data)
	local eventName = string.Trim(string.lower(tostring(data or "")))
	if eventName == "" then
		return
	end

	local rt = get_mvm_runtime()
	if populatorDebugEnabled() and rt and not hasEventChangeAttributes(rt, eventName) then
		Warning(string.format("ChangeBotAttributes: Failed to find event [%s] in the pop file\n", tostring(eventName)))
		return
	end

	for _, bot in ipairs(get_living_invader_bots()) do
		if bot.TF_MVM_ApplyEventChangeAttributes then
			bot:TF_MVM_ApplyEventChangeAttributes(eventName)
		end
	end
end

function ENT:Input_ChangeDefaultEventAttributes(_, _, data)
	local eventName = string.Trim(string.lower(tostring(data or "")))
	local rt = get_mvm_runtime()
	if populatorDebugEnabled() and rt and eventName ~= "" and not hasEventChangeAttributes(rt, eventName) then
		Warning(string.format("ChangeDefaultEventAttributes: Failed to find event [%s] in the pop file\n", tostring(eventName)))
		return
	end
	if rt and rt.SetDefaultEventChangeAttributesName then
		rt:SetDefaultEventChangeAttributesName(eventName)
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input_" .. tostring(name or "")]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
	return false
end

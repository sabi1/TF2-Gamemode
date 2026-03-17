ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	self.CapEnableDelay = tonumber(self.Properties.capenabledelay) or 0
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if key == "capenabledelay" then
		self.CapEnableDelay = tonumber(value) or 0
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Disabled = false
		return true
	elseif name == "disable" then
		self.Disabled = true
		return true
	elseif name == "roundspawn" then
		self.CapEnableDelay = tonumber(self.Properties.capenabledelay) or self.CapEnableDelay or 0
		return true
	end
end

local function ArenaCapTimerName(ent)
	return "TF_ArenaCapEnable_" .. tostring(ent:EntIndex())
end

hook.Add("TF_RoundStarted", "TF_ArenaLogicRoundStartOutputs", function(roundTimer)
	for _, logic in ipairs(ents.FindByClass("tf_logic_arena")) do
		if not IsValid(logic) or logic.Disabled then continue end

		logic:TriggerOutput("OnArenaRoundStart", roundTimer or logic)

		timer.Remove(ArenaCapTimerName(logic))
		local delay = math.max(tonumber(logic.CapEnableDelay or logic.Properties.capenabledelay or 0) or 0, 0)
		timer.Create(ArenaCapTimerName(logic), delay, 1, function()
			if IsValid(logic) and not logic.Disabled then
				logic:TriggerOutput("OnCapEnabled", logic)
			end
		end)
	end
end)

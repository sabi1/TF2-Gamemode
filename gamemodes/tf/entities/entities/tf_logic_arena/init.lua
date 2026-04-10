ENT.Type = "point"

local tf_arena_override_cap_enable_time = CreateConVar(
	"tf_arena_override_cap_enable_time",
	"-1",
	{FCVAR_REPLICATED, FCVAR_NOTIFY},
	"Overrides the time it takes for Arena capture points to become enabled. -1 uses the map value."
)

local function updateArenaState()
	local enabled = false
	for _, logic in ipairs(ents.FindByClass("tf_logic_arena")) do
		if IsValid(logic) and not logic.Disabled then
			enabled = true
			break
		end
	end

	if GAMEMODE then
		GAMEMODE.IsArenaMap = enabled
	end

	SetGlobalBool("tf_gamemode_arena", enabled)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	self.CapEnableDelay = tonumber(self.Properties.capenabledelay) or 0
	self.FiredCapEnabled = false
	self.NextCapEnableTime = nil
	self:SetNWBool("TFArenaEnabled", true)
	self:NextThink(CurTime() + 0.1)
	timer.Simple(0, updateArenaState)
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

function ENT:Think()
	self:NextThink(CurTime() + 0.1)

	if self.Disabled then
		self.FiredCapEnabled = false
		return true
	end

	local enableTime = tonumber(self.NextCapEnableTime)
	if enableTime and CurTime() >= enableTime then
		if not self.FiredCapEnabled then
			self.FiredCapEnabled = true
			self:TriggerOutput("OnCapEnabled", self)
		end
	else
		self.FiredCapEnabled = false
	end

	return true
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Disabled = false
		self:SetNWBool("TFArenaEnabled", true)
		updateArenaState()
		return true
	elseif name == "disable" then
		self.Disabled = true
		self:SetNWBool("TFArenaEnabled", false)
		updateArenaState()
		return true
	elseif name == "roundspawn" then
		self.CapEnableDelay = tonumber(self.Properties.capenabledelay) or self.CapEnableDelay or 0
		self.FiredCapEnabled = false
		return true
	elseif name == "roundactivate" then
		self.FiredCapEnabled = false
		updateArenaState()
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

		local overrideDelay = tf_arena_override_cap_enable_time and tf_arena_override_cap_enable_time:GetFloat() or -1
		local delay = overrideDelay and overrideDelay > 0
			and overrideDelay
			or math.max(tonumber(logic.CapEnableDelay or logic.Properties.capenabledelay or 0) or 0, 0)

		logic.NextCapEnableTime = CurTime() + delay
		logic.FiredCapEnabled = false
	end
end)

hook.Add("EntityRemoved", "TF_ArenaLogicEntityRemoved", function(ent)
	if not IsValid(ent) or ent:GetClass() ~= "tf_logic_arena" then return end
	timer.Simple(0, updateArenaState)
end)

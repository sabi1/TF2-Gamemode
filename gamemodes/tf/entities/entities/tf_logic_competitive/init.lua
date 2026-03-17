ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Disabled = false
		return true
	elseif name == "disable" then
		self.Disabled = true
		return true
	end
end

local function IsCompetitiveModeEnabled()
	local cv = GetConVar("tf_competitive")
	return cv and cv:GetBool() or false
end

local function FireCompetitiveOutput(outputName)
	if not IsCompetitiveModeEnabled() then return end

	for _, logic in ipairs(ents.FindByClass("tf_logic_competitive")) do
		if not IsValid(logic) or logic.Disabled then continue end
		logic:TriggerOutput(outputName, logic)
	end
end

hook.Add("TF_PreRoundStarted", "TF_CompetitiveLogicLockSpawnDoors", function()
	FireCompetitiveOutput("OnSpawnRoomDoorsShouldLock")
end)

hook.Add("TF_RoundStarted", "TF_CompetitiveLogicUnlockSpawnDoors", function()
	FireCompetitiveOutput("OnSpawnRoomDoorsShouldUnlock")
end)

hook.Add("TF_GameRules_RoundWinOutputs", "TF_CompetitiveLogicUnlockSpawnDoorsRoundEnd", function()
	FireCompetitiveOutput("OnSpawnRoomDoorsShouldUnlock")
end)

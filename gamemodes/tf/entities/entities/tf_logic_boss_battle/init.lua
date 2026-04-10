ENT.Type = "point"

local function updateBossBattleState()
	local enabled = false
	for _, logic in ipairs(ents.FindByClass("tf_logic_boss_battle")) do
		if IsValid(logic) and not logic.Disabled then
			enabled = true
			break
		end
	end

	if GAMEMODE then
		GAMEMODE.IsBossBattleMap = enabled
	end

	SetGlobalBool("tf_boss_battle_map", enabled)
end

function TF_IsBossBattleMap()
	return GetGlobalBool("tf_boss_battle_map", false)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Disabled = false
	timer.Simple(0, updateBossBattleState)
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:InputEnable()
	self.Disabled = false
	updateBossBattleState()
end

function ENT:InputDisable()
	self.Disabled = true
	updateBossBattleState()
end

function ENT:InputRoundActivate()
	updateBossBattleState()
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input" .. tostring(name or "")] or self["Input_" .. tostring(name or "")]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
	return false
end

hook.Add("EntityRemoved", "TF_BossBattleLogic_Removed", function(ent)
	if not IsValid(ent) or ent:GetClass() ~= "tf_logic_boss_battle" then return end
	timer.Simple(0, updateBossBattleState)
end)

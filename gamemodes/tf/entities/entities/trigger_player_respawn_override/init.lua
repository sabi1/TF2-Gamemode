ENT.Base = "base_brush"
ENT.Type = "brush"

local function ToBool(value, default)
	if value == nil then return default end
	if isbool(value) then return value end
	if isnumber(value) then return value ~= 0 end
	if isstring(value) then
		value = string.Trim(string.lower(value))
		if value == "1" or value == "true" or value == "yes" then return true end
		if value == "0" or value == "false" or value == "no" then return false end
	end
	return default
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.TouchingPlayers = {}
	self.Enabled = true
	self.RespawnTime = -1
	self.RespawnName = ""
	self:ReloadProperties()
end

function ENT:ReloadProperties()
	local props = self.Properties or {}
	self.Enabled = not ToBool(props.startdisabled, false)
	self.RespawnTime = tonumber(props.respawntime) or -1
	self.RespawnName = tostring(props.respawnname or "")
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

	if key == "respawntime" or key == "respawnname" or key == "startdisabled" then
		self:ReloadProperties()
	end
end

function ENT:IsEntityInside(ent)
	if not IsValid(ent) then return false end
	if self.TouchingPlayers[ent] then return true end

	local mins, maxs = self:WorldSpaceAABB()
	local pos = ent.WorldSpaceCenter and ent:WorldSpaceCenter() or ent:GetPos()
	return pos.x >= mins.x and pos.x <= maxs.x
		and pos.y >= mins.y and pos.y <= maxs.y
		and pos.z >= mins.z and pos.z <= maxs.z
end

function ENT:StartTouch(ent)
	if not (self.Enabled and IsValid(ent) and ent:IsPlayer()) then return end
	self.TouchingPlayers[ent] = true
end

function ENT:EndTouch(ent)
	if not (IsValid(ent) and ent:IsPlayer()) then return end
	self.TouchingPlayers[ent] = nil
end

function ENT:InputEnable()
	self.Enabled = true
end

function ENT:InputDisable()
	self.Enabled = false
	self.TouchingPlayers = {}
end

function ENT:InputToggle()
	self.Enabled = not self.Enabled
	if not self.Enabled then
		self.TouchingPlayers = {}
	end
end

function ENT:InputSetRespawnTime(_, _, data)
	local value = tonumber(data)
	if value == nil then return end
	self.RespawnTime = value
	self.Properties = self.Properties or {}
	self.Properties.respawntime = value
end

function ENT:InputSetRespawnName(_, _, data)
	local value = tostring(data or "")
	self.RespawnName = value
	self.Properties = self.Properties or {}
	self.Properties.respawnname = value
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input" .. name] or self["Input_" .. name]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
end

function TF_FindPlayerRespawnOverride(ply)
	if not (IsValid(ply) and ply:IsPlayer()) then
		return nil
	end

	for _, trigger in ipairs(ents.FindByClass("trigger_player_respawn_override")) do
		if not IsValid(trigger) or not trigger.Enabled then
			continue
		end
		if not trigger:IsEntityInside(ply) then
			continue
		end

		return {
			time = tonumber(trigger.RespawnTime) or -1,
			name = tostring(trigger.RespawnName or ""),
			entity = trigger,
		}
	end

	return nil
end

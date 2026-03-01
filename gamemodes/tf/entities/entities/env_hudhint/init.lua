ENT.Type = "point"

local function push_hint(target, msg)
	if not IsValid(target) or not target:IsPlayer() then return end
	if msg == "" then return end
	target:PrintMessage(HUD_PRINTCENTER, msg)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.Enabled = true
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:GetMessage()
	return tostring(self.Properties.message or self.Properties.hinttext or self.Properties.text or "")
end

function ENT:ShowHint(activator)
	local msg = self:GetMessage()
	if msg == "" then return end

	if IsValid(activator) and activator:IsPlayer() then
		push_hint(activator, msg)
		return
	end

	for _, ply in ipairs(player.GetAll()) do
		push_hint(ply, msg)
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "enable" then
		self.Enabled = true
		return true
	end
	if name == "disable" then
		self.Enabled = false
		return true
	end
	if not self.Enabled then
		return false
	end

	if name == "showhudhint" or name == "showmessage" or name == "display" then
		self:ShowHint(IsValid(activator) and activator or caller)
		return true
	end
	return false
end
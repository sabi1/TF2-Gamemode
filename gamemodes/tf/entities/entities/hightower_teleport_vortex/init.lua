ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.ActiveVortex = NULL
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
	if name == "createvortex" or name == "enable" then
		if IsValid(self.ActiveVortex) then return end
		local vortex = ents.Create("teleport_vortex")
		if not IsValid(vortex) then return end
		vortex:SetPos(self:GetPos())
		vortex:SetAngles(self:GetAngles())
		vortex:Spawn()
		vortex:Activate()
		self.ActiveVortex = vortex
		return
	end

	if name == "removevortex" or name == "disable" then
		if IsValid(self.ActiveVortex) then
			self.ActiveVortex:Remove()
		end
		self.ActiveVortex = NULL
		return
	end

	if name == "setdestination" then
		if IsValid(self.ActiveVortex) and isstring(data) then
			local x, y, z = string.match(data, "([%-%d%.]+)%s+([%-%d%.]+)%s+([%-%d%.]+)")
			if x and y and z then
				self.ActiveVortex.DestinationPos = Vector(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
			end
		end
		return
	end
end

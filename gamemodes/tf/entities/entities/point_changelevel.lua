AddCSLuaFile()

ENT.Type = "point"

function ENT:Initialize()
	self.Properties = self.Properties or {}
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	self.Properties[key] = value
	if key == "map" then
		self.map = tostring(value or "")
	elseif key == "landmark" then
		self.landmark = tostring(value or "")
	end
end

function ENT:GetNextMapName()
	local configured = string.Trim(tostring(self.map or self.Properties.map or NEXT_MAP or ""))
	if configured == "" then
		return nil
	end
	return configured
end

function ENT:TriggerLandmarkSave(nextMap)
	if not (GAMEMODE and IsValid(GAMEMODE.Landmark) and GAMEMODE.Landmark.SaveLevelData) then
		return
	end
	local landmarkName = string.Trim(tostring(self.landmark or self.Properties.landmark or ""))
	if landmarkName == "" then
		return
	end
	GAMEMODE.Landmark:SaveLevelData({
		map = nextMap,
		landmark = landmarkName,
	})
end

function ENT:DoChangeLevel()
	local nextMap = self:GetNextMapName()
	if nextMap then
		NEXT_MAP = nextMap
	end

	self:TriggerLandmarkSave(nextMap or NEXT_MAP)

	if GAMEMODE and GAMEMODE.GrabAndSwitch then
		GAMEMODE:GrabAndSwitch()
	end
end

function ENT:AcceptInput(name)
	name = string.lower(tostring(name or ""))
	if name == "changelevel" or name == "trigger" or name == "use" then
		self:DoChangeLevel()
		return true
	end
	return false
end

ENT.Base = "base_brush"
ENT.Type = "brush"

function ENT:Initialize()
	self.Triggered = false
end

local function getWrappedChangelevel(ent)
	local wrapped = ent.Changelevel
	if IsValid(wrapped) then
		return wrapped
	end
	return NULL
end

local function saveWrappedLandmark(ent, changelevel)
	local landmark = ent.Landmark
	if not (IsValid(landmark) and landmark.SaveLevelData) then
		return
	end

	landmark:SaveLevelData({
		map = changelevel and changelevel.map or nil,
		landmark = changelevel and changelevel.landmark or nil,
	})
end

function ENT:TriggerChangelevel(activator)
	if self.Triggered then
		return
	end

	local changelevel = getWrappedChangelevel(self)
	if not IsValid(changelevel) then
		return
	end

	self.Triggered = true

	local nextMap = string.Trim(tostring(changelevel.map or NEXT_MAP or ""))
	if nextMap ~= "" then
		NEXT_MAP = nextMap
	end

	saveWrappedLandmark(self, changelevel)

	if GAMEMODE and GAMEMODE.GrabAndSwitch then
		GAMEMODE:GrabAndSwitch()
	end
end

function ENT:StartTouch(ent)
	if not (IsValid(ent) and ent:IsPlayer()) then
		return
	end

	self:TriggerChangelevel(ent)
end

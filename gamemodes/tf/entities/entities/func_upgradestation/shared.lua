ENT.Base = "base_brush"
ENT.Type = "brush"
ENT.PrintName = "Upgrade Station"
ENT.Spawnable = false

function ENT:Initialize()
    self.Team = self.Team or 0
end

function ENT:KeyValue(key, value)
    key = string.lower(tostring(key or ""))
    if key == "teamnum" then
        self.Team = tonumber(value) or 0
    end
end
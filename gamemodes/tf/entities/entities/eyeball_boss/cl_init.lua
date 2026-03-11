include('shared.lua')

ENT.RenderGroup = RENDERGROUP_BOTH

language.Add("eyeball_boss", "MONOCULUS!")

local EYEBALL_CALM = 0
local EYEBALL_GRUMPY = 1
local EYEBALL_ANGRY = 2
local EYEBALL_STUNNED = 3

local function aura_for_attitude(ent, attitude)
    local teamNum = ent.GetNWInt and ent:GetNWInt("Team", TEAM_NEUTRAL) or TEAM_NEUTRAL
    if teamNum == TEAM_RED then return "eyeboss_team_red" end
    if teamNum == TEAM_BLU then return "eyeboss_team_blue" end

    if attitude == EYEBALL_ANGRY then return "eyeboss_aura_angry" end
    if attitude == EYEBALL_GRUMPY then return "eyeboss_aura_grumpy" end
    if attitude == EYEBALL_STUNNED then return "eyeboss_aura_stunned" end
    return "eyeboss_aura_calm"
end

function ENT:Initialize()
    self._eyeAuraName = nil
    self._eyeGhostAttached = false
    self._eyeLookAngles = Angle(0, self:GetAngles().y, 0)
    self._eyePoseLookupDone = false
    self._eyeLeftRightPose = -1
    self._eyeUpDownPose = -1
    self:SetNextClientThink(CurTime())
end

function ENT:EnsureAmbientEffects()
    if not IsValid(self) or not ParticleEffectAttach then return end

    if not self._eyeGhostAttached then
        ParticleEffectAttach("ghost_pumpkin", PATTACH_ABSORIGIN_FOLLOW, self, 0)
        self._eyeGhostAttached = true
    end

    local attitude = self.GetNWInt and self:GetNWInt("EyeballAttitude", EYEBALL_CALM) or EYEBALL_CALM
    local wantedAura = aura_for_attitude(self, attitude)
    if self._eyeAuraName ~= wantedAura then
        if self.StopParticles then
            self:StopParticles()
        end
        ParticleEffectAttach("ghost_pumpkin", PATTACH_ABSORIGIN_FOLLOW, self, 0)
        ParticleEffectAttach(wantedAura, PATTACH_ABSORIGIN_FOLLOW, self, 0)
        self._eyeGhostAttached = true
        self._eyeAuraName = wantedAura
    end
end

function ENT:UpdateEyePose()
    if not IsValid(self) then return end
    if not self.SetPoseParameter or not self.LookupPoseParameter then return end

    if not self._eyePoseLookupDone then
        local leftRight = self:LookupPoseParameter("left_right")
        local upDown = self:LookupPoseParameter("up_down")
        self._eyeLeftRightPose = isnumber(leftRight) and leftRight or -1
        self._eyeUpDownPose = isnumber(upDown) and upDown or -1
        self._eyePoseLookupDone = true
    end

    if self._eyeLeftRightPose < 0 and self._eyeUpDownPose < 0 then
        return
    end

    local lookAtSpot = self.GetNWVector and self:GetNWVector("EyeballLookAtSpot", self:WorldSpaceCenter() + self:GetForward() * 300) or (self:WorldSpaceCenter() + self:GetForward() * 300)
    local toTarget = lookAtSpot - self:WorldSpaceCenter()
    if toTarget:LengthSqr() <= 1 then return end
    toTarget:Normalize()

    local myAngles = self._eyeLookAngles or Angle(0, self:GetAngles().y, 0)
    local myForward = myAngles:Forward()
    myForward = (myForward + toTarget * 3.0 * FrameTime()):GetNormalized()
    local newAngles = myForward:Angle()
    self._eyeLookAngles = Angle(newAngles.p, newAngles.y, 0)

    local myRight = self._eyeLookAngles:Right()
    local myUp = self._eyeLookAngles:Up()
    local toTargetRight = myRight:Dot(toTarget)
    local toTargetUp = myUp:Dot(toTarget)

    if self._eyeLeftRightPose >= 0 then
        self:SetPoseParameter("left_right", -50 * toTargetRight)
    end
    if self._eyeUpDownPose >= 0 then
        self:SetPoseParameter("up_down", -50 * toTargetUp)
    end
end

function ENT:Think()
    self:EnsureAmbientEffects()
    self:UpdateEyePose()
    self:SetNextClientThink(CurTime())
    return true
end

function ENT:OnRemove()
    if self.StopParticles then
        self:StopParticles()
    end
end

function ENT:GetRenderAngles()
    return self._eyeLookAngles or self:GetAngles()
end

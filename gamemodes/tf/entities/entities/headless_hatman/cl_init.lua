include("shared.lua")

ENT.RenderGroup = RENDERGROUP_BOTH
language.Add("headless_hatman", "Horseless Headless Horsemann")

local function attach_ambient_hhh_fx(ent)
    if not IsValid(ent) or not ParticleEffectAttach then return false end
    local attached = false

    if ent.LookupAttachment then
        local left = ent:LookupAttachment("lefteye")
        if left and left > 0 then
            ParticleEffectAttach("halloween_boss_eye_glow", PATTACH_POINT_FOLLOW, ent, left)
            attached = true
        end

        local right = ent:LookupAttachment("righteye")
        if right and right > 0 then
            ParticleEffectAttach("halloween_boss_eye_glow", PATTACH_POINT_FOLLOW, ent, right)
            attached = true
        end
    end

    -- Match TF2 C_HeadlessHatman: persistent body aura.
    ParticleEffectAttach("ghost_pumpkin", PATTACH_ABSORIGIN_FOLLOW, ent, 0)
    attached = true
    return attached
end

function ENT:Initialize()
    self._hhhAmbientAttached = false
    self:SetNextClientThink(CurTime())
end

function ENT:Think()
    if not self._hhhAmbientAttached then
        self._hhhAmbientAttached = attach_ambient_hhh_fx(self)
    end
    self:SetNextClientThink(CurTime() + 0.5)
    return true
end

function ENT:OnRemove()
    if self.StopParticles then
        self:StopParticles()
    end
end

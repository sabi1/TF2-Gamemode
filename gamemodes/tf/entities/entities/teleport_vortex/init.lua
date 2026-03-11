AddCSLuaFile("shared.lua")
include("shared.lua")

local VORTEX_TOUCH_HALF_EXTENTS = Vector(64, 64, 80)
local UNDERWORLD_RETURN_BUFF_TIME = 5.0
local UNDERWORLD_RETURN_QUICKHEAL_TIME = 5.0
local VORTEX_DEBUG_CVAR = "tf_halloween_vortex_debug"

if SERVER and not ConVarExists(VORTEX_DEBUG_CVAR) then
    CreateConVar(VORTEX_DEBUG_CVAR, "0", FCVAR_ARCHIVE, "Enable Monoculus vortex teleport debug logging.")
end

local function vortex_debug(fmt, ...)
    local cv = GetConVar(VORTEX_DEBUG_CVAR)
    if not (cv and cv:GetBool()) then return end
    MsgN(string.format("[Vortex Debug] " .. tostring(fmt), ...))
end

local vortex_particles_loaded = false
local function ensure_vortex_particles()
    if vortex_particles_loaded then return end
    vortex_particles_loaded = true

    if game and game.AddParticles then
        pcall(game.AddParticles, "particles/eyeboss.pcf")
        pcall(game.AddParticles, "gamemodes/tf/content/particles/eyeboss.pcf")
    end

    if PrecacheParticleSystem then
        pcall(PrecacheParticleSystem, "eyeboss_tp_escape")
        pcall(PrecacheParticleSystem, "eyeboss_tp_vortex")
        pcall(PrecacheParticleSystem, "eyeboss_doorway_vortex")
    end
end

local function dispatch_vortex_particle(name, pos, ang, parent)
    if not isstring(name) or name == "" then return end
    local p = isvector(pos) and pos or vector_origin
    local a = isangle(ang) and ang or angle_zero

    if DispatchParticleEffect then
        if IsValid(parent) then
            pcall(DispatchParticleEffect, name, p, a, parent)
        else
            pcall(DispatchParticleEffect, name, p, a)
        end
        return
    end

    if ParticleEffect then
        if IsValid(parent) then
            pcall(ParticleEffect, name, p, a, parent)
        else
            pcall(ParticleEffect, name, p, a)
        end
    end
end

local function player_is_looking_towards(ply, worldPos)
    if not IsValid(ply) or not isvector(worldPos) then return false end
    local eyePos = ply.EyePos and ply:EyePos() or ply:WorldSpaceCenter()
    local toTarget = worldPos - eyePos
    if toTarget:LengthSqr() <= 1 then return true end
    toTarget:Normalize()

    local aim = ply.GetAimVector and ply:GetAimVector() or ply:GetForward()
    return aim:Dot(toTarget) > 0.5
end

local function player_has_vortex_los(ply, worldPos, vortexEnt)
    if not IsValid(ply) or not isvector(worldPos) then return false end
    local startPos = ply.EyePos and ply:EyePos() or ply:WorldSpaceCenter()
    local tr = util.TraceLine({
        start = startPos,
        endpos = worldPos,
        filter = { ply, vortexEnt },
        mask = MASK_SOLID_BRUSHONLY,
    })
    return not tr.Hit
end

local function player_in_vortex_touch_volume(vortex, ply)
    if not IsValid(vortex) or not IsValid(ply) then return false end
    local center = vortex:WorldSpaceCenter()
    local pos = ply:WorldSpaceCenter()
    local delta = pos - center

    local ex = VORTEX_TOUCH_HALF_EXTENTS
    if math.abs(delta.x) > ex.x or math.abs(delta.y) > ex.y or math.abs(delta.z) > ex.z then
        return false
    end

    return true
end

local function is_returning_from_underworld(ply, dest)
    if not IsValid(ply) or not isvector(dest) then return false end

    if isnumber(TF_COND_HALLOWEEN_IN_HELL) and ply.InCond and ply:InCond(TF_COND_HALLOWEEN_IN_HELL) then
        return true
    end

    -- Map fallback for viaduct_event when condition triggers are bypassed by scripted teleport.
    local mapName = string.lower(game.GetMap() or "")
    if mapName == "koth_viaduct_event" then
        local fromZ = ply:GetPos().z
        local toZ = dest.z
        if fromZ < -10000 and toZ > -10000 then
            return true
        end
    end

    return false
end

local function apply_underworld_return_boost(ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    if not ply.AddCond then return end

    if isnumber(TF_COND_HALLOWEEN_IN_HELL) and ply.RemoveCond then
        ply:RemoveCond(TF_COND_HALLOWEEN_IN_HELL, true)
    end

    if isnumber(TF_COND_INVULNERABLE) then
        ply:AddCond(TF_COND_INVULNERABLE, UNDERWORLD_RETURN_BUFF_TIME, ply)
    end
    if isnumber(TF_COND_CRITBOOSTED) then
        ply:AddCond(TF_COND_CRITBOOSTED, UNDERWORLD_RETURN_BUFF_TIME, ply)
    end
    if isnumber(TF_COND_HALLOWEEN_SPEED_BOOST) then
        ply:AddCond(TF_COND_HALLOWEEN_SPEED_BOOST, UNDERWORLD_RETURN_BUFF_TIME, ply)
    end
    if isnumber(TF_COND_HALLOWEEN_QUICK_HEAL) then
        ply:AddCond(TF_COND_HALLOWEEN_QUICK_HEAL, UNDERWORLD_RETURN_QUICKHEAL_TIME, ply)
    end

    -- TF2 return portal grants strong overheal (up to 200%).
    if ply.Health and ply.SetHealth and ply.GetMaxHealth then
        local maxHealth = math.max(1, tonumber(ply:GetMaxHealth()) or 1)
        local boosted = math.floor(maxHealth * 2.0)
        if ply:Health() < boosted then
            ply:SetHealth(boosted)
        end
    end
end

function ENT:Initialize()
    ensure_vortex_particles()
    self:SetNoDraw(true)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_BBOX)
    if self.AddSolidFlags and FSOLID_TRIGGER then
        self:AddSolidFlags(FSOLID_TRIGGER)
    end
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    self:SetCollisionBounds(-VORTEX_TOUCH_HALF_EXTENTS, VORTEX_TOUCH_HALF_EXTENTS)
    self:SetTrigger(true)

    self.TouchCooldown = 1.0
    self.TeleportRadius = 140
    self.DestinationPos = self:GetPos()
    self.LinkedVortex = nil
    self.ExpiresAt = 0
    self.SuctionRadius = 500
    self.SuctionStrength = 30

    if ParticleEffectAttach and not self.DisablePurpleVortex then
        pcall(ParticleEffectAttach, "eyeboss_tp_vortex", PATTACH_ABSORIGIN_FOLLOW, self, 0)
    end
    if ParticleEffectAttach then
        pcall(ParticleEffectAttach, "eyeboss_doorway_vortex", PATTACH_ABSORIGIN_FOLLOW, self, 0)
    end
    dispatch_vortex_particle("eyeboss_tp_escape", self:GetPos(), self:GetAngles(), self)
    self:EmitSound("Halloween.TeleportVortex.BookSpawn", 90, 100)
    self:NextThink(CurTime())
end

function ENT:SetLifetime(seconds)
    local s = tonumber(seconds) or 0
    if s > 0 then
        self.ExpiresAt = CurTime() + s
        local timerName = "tf_vortex_expire_" .. self:EntIndex()
        timer.Remove(timerName)
        timer.Create(timerName, s, 1, function()
            if IsValid(self) then
                self:Remove()
            end
        end)
    else
        self.ExpiresAt = 0
        timer.Remove("tf_vortex_expire_" .. self:EntIndex())
    end
end

function ENT:SetDestinationPos(pos)
    if isvector(pos) then
        self.DestinationPos = pos
    end
end

function ENT:SetLinkedVortex(ent)
    if IsValid(ent) then
        self.LinkedVortex = ent
        self:SetDestinationPos(ent:GetPos())
    end
end

function ENT:GetTeleportExitPos()
    local base = self.DestinationPos
    if IsValid(self.LinkedVortex) then
        base = self.LinkedVortex:GetPos()
    end

    local tr = util.TraceHull({
        start = base + Vector(0, 0, 64),
        endpos = base + Vector(0, 0, 64),
        mins = Vector(-16, -16, 0),
        maxs = Vector(16, 16, 72),
        mask = MASK_PLAYERSOLID_BRUSHONLY,
    })

    if tr.StartSolid then
        return base + Vector(0, 0, 96)
    end

    return tr.HitPos
end

function ENT:TeleportPlayer(ply, forceNear)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then
        vortex_debug("reject invalid/alive check")
        return
    end
    if isnumber(FL_FROZEN) and ply.IsFlagSet and ply:IsFlagSet(FL_FROZEN) then return end
    if ply:InVehicle() then return end
    if forceNear then
        local near = tonumber(self.TeleportRadius) or 140
        local d2 = ply:WorldSpaceCenter():DistToSqr(self:WorldSpaceCenter())
        if d2 > (near * near) then
            return
        end
    else
        if not player_in_vortex_touch_volume(self, ply) then
            vortex_debug("reject %s: outside touch volume", tostring(ply))
            return
        end
    end

    local now = CurTime()
    ply._tfVortexCooldownUntil = ply._tfVortexCooldownUntil or 0
    if now < ply._tfVortexCooldownUntil then
        vortex_debug("reject %s: cooldown %.2f", tostring(ply), ply._tfVortexCooldownUntil - now)
        return
    end

    local dest = self:GetTeleportExitPos()
    if not isvector(dest) then
        vortex_debug("reject %s: invalid destination", tostring(ply))
        return
    end
    local returningFromUnderworld = is_returning_from_underworld(ply, dest)
    local vel = ply.GetVelocity and ply:GetVelocity() or vector_origin

    ply._tfVortexCooldownUntil = now + (tonumber(self.TouchCooldown) or 1.0)
    ply:SetPos(dest)
    if ply:GetPos():DistToSqr(dest) > (32 * 32) then
        ply:SetPos(dest + Vector(0, 0, 16))
    end
    ply:SetGroundEntity(NULL)

    if ply.SetLocalVelocity then
        ply:SetLocalVelocity(Vector(vel.x * 0.35, vel.y * 0.35, math.max(vel.z, 120)))
    elseif ply.SetVelocity then
        ply:SetVelocity(Vector(0, 0, 120))
    end

    if returningFromUnderworld then
        apply_underworld_return_boost(ply)
    end

    dispatch_vortex_particle("eyeboss_tp_escape", self:GetPos(), self:GetAngles())
    dispatch_vortex_particle("eyeboss_tp_escape", dest, self:GetAngles())
    self:EmitSound("Halloween.TeleportVortex.EyeballMovedVortex", 90, 100)
    vortex_debug("teleport %s to %.1f %.1f %.1f", tostring(ply), dest.x, dest.y, dest.z)
end

function ENT:StartTouch(ent)
    self:TeleportPlayer(ent)
end

function ENT:Touch(ent)
    self:TeleportPlayer(ent)
end

function ENT:Think()
    local center = self:GetPos()
    local pullRadius = tonumber(self.SuctionRadius) or 500
    local impulse = tonumber(self.SuctionStrength) or 30
    local teleportRadius = tonumber(self.TeleportRadius) or 140

    -- Reliability pass: keep attempting teleport while players are within the
    -- trigger region, instead of relying solely on a single StartTouch event.
    for _, ply in ipairs(ents.FindInSphere(center, teleportRadius)) do
        self:TeleportPlayer(ply, true)
    end

    for _, ply in ipairs(ents.FindInSphere(center, pullRadius)) do
        if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
            if ply.IsOnGround and ply:IsOnGround() then
                continue
            end

            if not player_is_looking_towards(ply, center) then
                continue
            end

            if not player_has_vortex_los(ply, center, self) then
                continue
            end

            local delta = center - ply:WorldSpaceCenter()
            local dist = delta:Length()
            if dist > 1 and dist <= pullRadius then
                ply:SetVelocity(delta:GetNormalized() * impulse)
            end
        end
    end

    if self.ExpiresAt > 0 and CurTime() >= self.ExpiresAt then
        self:Remove()
        return
    end

    self:NextThink(CurTime())
    return true
end

function ENT:OnRemove()
    timer.Remove("tf_vortex_expire_" .. self:EntIndex())
    if self.StopParticles then
        self:StopParticles()
    end
    self:EmitSound("Halloween.TeleportVortex.BookExit", 90, 100)
end

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local DEFAULT_MODEL = "models/bots/skeleton_sniper/skeleton_sniper.mdl"
local FALLBACK_MODEL = "models/zombie/classic.mdl"

local function is_valid_target(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not ply:Alive() then return false end
    if ply:IsFlagSet(FL_NOTARGET) then return false end
    local teamNum = GAMEMODE and GAMEMODE.EntityTeam and GAMEMODE:EntityTeam(ply) or TEAM_NEUTRAL
    return teamNum == TEAM_RED or teamNum == TEAM_BLU
end

local function resolve_model()
    if util and util.IsValidModel and util.IsValidModel(DEFAULT_MODEL) then
        return DEFAULT_MODEL
    end
    return FALLBACK_MODEL
end

function ENT:Initialize()
    self:SetModel(resolve_model())
    self:SetHealth(120)
    if self.SetMaxHealth then
        self:SetMaxHealth(120)
    end
    self:SetNWInt("Team", TEAM_NEUTRAL)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    self:SetBloodColor(BLOOD_COLOR_RED)

    self.NextAttack = 0
    self.NextTargetSearch = 0
    self.Target = nil

    if self.loco then
        self.loco:SetStepHeight(18)
        self.loco:SetAcceleration(900)
        self.loco:SetDeceleration(900)
        self.loco:SetDesiredSpeed(300)
        self.loco:SetDeathDropHeight(300)
        self.loco:SetJumpHeight(0)
    end
end

local function try_set_sequence(ent, names)
    if not IsValid(ent) or not ent.LookupSequence or not ent.SetSequence then return false end
    for _, name in ipairs(names or {}) do
        local seq = ent:LookupSequence(name)
        if seq and seq > 0 then
            ent:SetSequence(seq)
            ent:SetCycle(0)
            ent:SetPlaybackRate(1)
            if ent.ResetSequenceInfo then
                ent:ResetSequenceInfo()
            end
            return true
        end
    end
    return false
end

function ENT:Team()
    return TEAM_NEUTRAL
end

function ENT:GetTeamNumber()
    return TEAM_NEUTRAL
end

function ENT:BodyUpdate()
    self:BodyMoveXY()
end

function ENT:PickTarget()
    if CurTime() < self.NextTargetSearch and is_valid_target(self.Target) then
        return self.Target
    end

    self.NextTargetSearch = CurTime() + 0.25

    local best, bestDist = nil, math.huge
    for _, ply in ipairs(player.GetAll()) do
        if is_valid_target(ply) then
            local dist = self:GetRangeTo(ply:GetPos())
            if dist < bestDist then
                best = ply
                bestDist = dist
            end
        end
    end

    self.Target = best
    return best
end

function ENT:TryMelee(target)
    if not IsValid(target) then return end
    if CurTime() < self.NextAttack then return end
    if self:GetRangeTo(target:GetPos()) > 90 then return end

    self.NextAttack = CurTime() + 1.0
    try_set_sequence(self, { "attack", "attack_melee", "melee_attack01" })
    self:RestartGesture(ACT_GESTURE_RANGE_ATTACK_MELEE2)
    self:EmitSound("Halloween.skeleton_laugh_small", 85, math.random(95, 110))

    timer.Simple(0.22, function()
        if not IsValid(self) or not IsValid(target) then return end
        if self:GetRangeTo(target:GetPos()) > 110 then return end

        local dmg = DamageInfo()
        dmg:SetAttacker(IsValid(self:GetOwner()) and self:GetOwner() or self)
        dmg:SetInflictor(self)
        dmg:SetDamage(35)
        dmg:SetDamageType(DMG_SLASH)
        target:TakeDamageInfo(dmg)
    end)
end

function ENT:DirectChase(target)
    if not self.loco or not IsValid(target) then return end
    local targetPos = target:WorldSpaceCenter()
    local toTarget = targetPos - self:GetPos()
    local dist2d = toTarget:Length2D()
    if dist2d <= 1 then return end

    self.loco:FaceTowards(targetPos)
    self.loco:SetDesiredSpeed(300)
    self.loco:Approach(targetPos, 1)

    if self.GetVelocity and self:GetVelocity():Length2D() < 5 then
        local n = toTarget:GetNormalized()
        self:SetPos(self:GetPos() + Vector(n.x, n.y, 0) * math.min(6, dist2d))
    end
end

function ENT:TryUnstick()
    local origin = self:GetPos()
    local samples = {
        Vector(32, 0, 0), Vector(-32, 0, 0), Vector(0, 32, 0), Vector(0, -32, 0),
        Vector(48, 48, 0), Vector(-48, 48, 0), Vector(48, -48, 0), Vector(-48, -48, 0),
    }
    for _, off in ipairs(samples) do
        local candidate = origin + off + Vector(0, 0, 2)
        local tr = util.TraceHull({
            start = candidate + Vector(0, 0, 8),
            endpos = candidate + Vector(0, 0, 8),
            mins = Vector(-16, -16, 0),
            maxs = Vector(16, 16, 72),
            mask = MASK_NPCSOLID,
            filter = self,
        })
        if not tr.Hit then
            self:SetPos(candidate)
            return true
        end
    end
    return false
end

function ENT:HandleStuck()
    self:TryUnstick()
    if self.loco and self.loco.ClearStuck then
        self.loco:ClearStuck()
    end
end

function ENT:RunBehaviour()
    while true do
        local target = self:PickTarget()
        if IsValid(target) then
            self:StartActivity(ACT_MP_RUN_MELEE)
            if not try_set_sequence(self, { "run_melee", "run", "walk_melee", "walk" }) then
                self:StartActivity(ACT_RUN)
            end
            self:DirectChase(target)
            self:TryMelee(target)
            coroutine.wait(0.01)
        else
            self:StartActivity(ACT_IDLE)
            try_set_sequence(self, { "idle", "stand_melee" })
            coroutine.wait(0.2)
        end
        coroutine.yield()
    end
end

function ENT:OnTakeDamage(dmginfo)
    if not dmginfo then return 0 end
    local dmg = math.max(0, dmginfo:GetDamage() or 0)
    if dmg <= 0 then return 0 end

    local newHp = self:Health() - dmg
    self:SetHealth(newHp)

    local att = dmginfo:GetAttacker()
    if is_valid_target(att) then
        self.Target = att
    end

    if newHp <= 0 then
        self:EmitSound("Halloween.skeleton_break", 90, 100)
        if math.random() <= 0.08 then
            local soul = ents.Create("item_halloween_soul")
            if IsValid(soul) then
                soul:SetPos(self:GetPos() + Vector(0, 0, 6))
                soul:SetAngles(Angle(0, math.random(0, 359), 0))
                soul:Spawn()
                soul:Activate()
                soul:DropWithGravity(VectorRand() * 90 + Vector(0, 0, 180))
                timer.Simple(10, function()
                    if IsValid(soul) then soul:Remove() end
                end)
            end
        end
        self:Remove()
    end
    return dmg
end

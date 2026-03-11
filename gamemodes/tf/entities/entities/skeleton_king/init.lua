AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local DEFAULT_CFG = {
    health_base = 5000,
    health_per_player = 320,
    health_max = 12500,
    min_players = 0,
    speed = 280,
    chase_range = 2200,
    attack_range = 120,
    attack_damage = 95,
    attack_cooldown = 1.15,
    spawn_lock_time = 2.2,
    summon_interval = 10.0,
    summon_count = 3,
    summon_cap = 14,
    summon_radius = 160,
    stomp_cooldown = 7.5,
    stomp_range = 280,
    stomp_damage = 70,
    rage_threshold = 0.5,
    rage_speed_mult = 1.28,
    rage_attack_mult = 1.2,
}

local KING_MODEL = "models/bots/skeleton_sniper_boss/skeleton_sniper_boss.mdl"
local NORMAL_MODEL = "models/bots/skeleton_sniper/skeleton_sniper.mdl"
local FALLBACK_MODEL = "models/zombie/classic.mdl"

local function resolve_model()
    if util and util.IsValidModel and util.IsValidModel(KING_MODEL) then
        return KING_MODEL, 1.35
    end
    if util and util.IsValidModel and util.IsValidModel(NORMAL_MODEL) then
        return NORMAL_MODEL, 2.5
    end
    return FALLBACK_MODEL, 2.5
end

local function is_valid_target(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not ply:Alive() then return false end
    if ply:IsFlagSet(FL_NOTARGET) then return false end
    local teamNum = GAMEMODE and GAMEMODE.EntityTeam and GAMEMODE:EntityTeam(ply) or TEAM_NEUTRAL
    return teamNum == TEAM_RED or teamNum == TEAM_BLU
end

local function living_human_count()
    local c = 0
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsPlayer() and ply:Alive() and not ply:IsBot() then
            local t = GAMEMODE and GAMEMODE.EntityTeam and GAMEMODE:EntityTeam(ply) or TEAM_NEUTRAL
            if t == TEAM_RED or t == TEAM_BLU then
                c = c + 1
            end
        end
    end
    return c
end

local function safe_ground(pos)
    local tr = util.TraceHull({
        start = pos + Vector(0, 0, 64),
        endpos = pos - Vector(0, 0, 1024),
        mins = Vector(-36, -36, 0),
        maxs = Vector(36, 36, 120),
        mask = MASK_NPCSOLID_BRUSHONLY,
    })
    if tr.Hit then
        return tr.HitPos
    end
    return pos
end

function ENT:Initialize()
    self.Config = table.Copy(DEFAULT_CFG)

    local mdl, scale = resolve_model()
    self._forcedScale = scale
    self:SetModel(mdl)
    if scale ~= 1 and self.SetModelScale then
        self:SetModelScale(scale, 0)
    end

    local hp = self.Config.health_base
    local n = living_human_count()
    if n > self.Config.min_players then
        hp = hp + (n - self.Config.min_players) * self.Config.health_per_player
    end
    hp = math.Clamp(math.floor(hp), 1, self.Config.health_max)

    self:SetHealth(hp)
    if self.SetMaxHealth then
        self:SetMaxHealth(hp)
    end
    self:SetNWInt("Team", TEAM_NEUTRAL)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-36, -36, 0), Vector(36, 36, 120))
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    self:SetBloodColor(BLOOD_COLOR_RED)

    self.Target = nil
    self.NextAttack = 0
    self.NextSummon = CurTime() + self.Config.summon_interval
    self.SpawnLockedUntil = CurTime() + self.Config.spawn_lock_time
    self.Summons = {}
    self.NextTargetSearch = 0
    self.NextStomp = CurTime() + self.Config.stomp_cooldown
    self.IsRaging = false
    self.LastFootstepFxAt = 0

    if self.loco then
        self.loco:SetStepHeight(24)
        self.loco:SetAcceleration(800)
        self.loco:SetDeceleration(900)
        self.loco:SetDesiredSpeed(self.Config.speed)
        self.loco:SetDeathDropHeight(300)
        self.loco:SetJumpHeight(0)
    end

    self:StartActivity(ACT_IDLE)
    self:EmitSound("Halloween.skeleton_laugh_giant", 95, 100)
    if DispatchParticleEffect then
        DispatchParticleEffect("halloween_boss_summon", self:GetPos(), self:GetAngles(), self)
    end

    if self._forcedScale and self._forcedScale ~= 1 then
        timer.Simple(0, function()
            if not IsValid(self) or not self.SetModelScale then return end
            self:SetModelScale(self._forcedScale, 0)
        end)
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

function ENT:CleanSummons()
    local keep = {}
    for _, ent in ipairs(self.Summons) do
        if IsValid(ent) then
            keep[#keep + 1] = ent
        end
    end
    self.Summons = keep
end

function ENT:SummonSkeletons()
    self:CleanSummons()
    if #self.Summons >= self.Config.summon_cap then return end

    local canSpawn = math.min(self.Config.summon_count, self.Config.summon_cap - #self.Summons)
    if canSpawn <= 0 then return end

    self:EmitSound("Halloween.spell_skeleton_horde_cast", 95, 100)
    for i = 1, canSpawn do
        local offset = VectorRand() * self.Config.summon_radius
        offset.z = 0
        local pos = safe_ground(self:GetPos() + offset) + Vector(0, 0, 2)
        local z = ents.Create("tf_zombie")
        if IsValid(z) then
            z:SetPos(pos)
            z:SetAngles(Angle(0, math.random(0, 359), 0))
            z:SetOwner(self)
            z:Spawn()
            z:Activate()
            self.Summons[#self.Summons + 1] = z
            if DispatchParticleEffect then
                DispatchParticleEffect("ghost_pumpkin", pos, angle_zero)
            end
            z:EmitSound("Halloween.spell_skeleton_horde_rise", 90, 100)
        end
    end
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
            if dist < bestDist and dist <= self.Config.chase_range then
                best = ply
                bestDist = dist
            end
        end
    end

    self.Target = best
    return best
end

function ENT:DoAttack(target)
    if not IsValid(target) then return end
    if CurTime() < self.NextAttack then return end
    if self:GetRangeTo(target:GetPos()) > self.Config.attack_range then return end

    self.NextAttack = CurTime() + self.Config.attack_cooldown
    try_set_sequence(self, { "attack", "attack_melee", "melee_attack01", "taunt06" })
    self:RestartGesture(ACT_GESTURE_RANGE_ATTACK_MELEE)
    self:EmitSound("Halloween.skeleton_laugh_giant", 95, math.random(92, 108))

    timer.Simple(0.24, function()
        if not IsValid(self) or not IsValid(target) then return end
        if self:GetRangeTo(target:GetPos()) > self.Config.attack_range + 35 then return end

        local dmg = DamageInfo()
        dmg:SetAttacker(self)
        dmg:SetInflictor(self)
        dmg:SetDamage(self.Config.attack_damage)
        dmg:SetDamageType(bit.bor(DMG_CLUB, DMG_SLASH))
        target:TakeDamageInfo(dmg)
    end)
end

function ENT:EnterRage()
    if self.IsRaging then return end
    self.IsRaging = true
    self:SetSkin(1)
    self:EmitSound("Halloween.skeleton_laugh_giant", 100, 80)
    if DispatchParticleEffect then
        DispatchParticleEffect("halloween_boss_injured", self:GetPos() + Vector(0, 0, 40), self:GetAngles(), self)
    end
end

function ENT:TryFootstepFx()
    if not DispatchParticleEffect then return end
    if CurTime() < (self.LastFootstepFxAt or 0) then return end
    if not self.GetVelocity or self:GetVelocity():Length2D() < 140 then return end
    self.LastFootstepFxAt = CurTime() + 0.35
    DispatchParticleEffect("halloween_boss_foot_impact", self:GetPos(), self:GetAngles(), self)
end

function ENT:TryStomp(target)
    if not IsValid(target) then return end
    if CurTime() < (self.NextStomp or 0) then return end
    if self:GetRangeTo(target:GetPos()) > self.Config.stomp_range then return end

    self.NextStomp = CurTime() + self.Config.stomp_cooldown
    self:EmitSound("Halloween.skeleton_laugh_medium", 95, math.random(95, 105))
    if DispatchParticleEffect then
        DispatchParticleEffect("halloween_boss_foot_impact", self:GetPos(), self:GetAngles(), self)
    end

    for _, ply in ipairs(player.GetAll()) do
        if is_valid_target(ply) then
            local dist = self:GetRangeTo(ply:GetPos())
            if dist <= self.Config.stomp_range then
                local dmg = DamageInfo()
                dmg:SetAttacker(self)
                dmg:SetInflictor(self)
                dmg:SetDamage(self.Config.stomp_damage)
                dmg:SetDamageType(bit.bor(DMG_CLUB, DMG_SONIC))
                ply:TakeDamageInfo(dmg)

                local dir = (ply:GetPos() - self:GetPos())
                dir.z = math.max(0.2, dir.z)
                dir:Normalize()
                ply:SetVelocity(dir * (250 + (self.Config.stomp_range - dist) * 0.3))
            end
        end
    end
end

function ENT:DirectChase(target)
    if not self.loco or not IsValid(target) then return end
    local targetPos = target:WorldSpaceCenter()
    local toTarget = targetPos - self:GetPos()
    local dist2d = toTarget:Length2D()
    if dist2d <= 1 then return end

    self.loco:FaceTowards(targetPos)
    self.loco:SetDesiredSpeed(self.Config.speed)
    self.loco:Approach(targetPos, 1)

    if self.GetVelocity and self:GetVelocity():Length2D() < 5 then
        local n = toTarget:GetNormalized()
        self:SetPos(self:GetPos() + Vector(n.x, n.y, 0) * math.min(6, dist2d))
    end
end

function ENT:TryUnstick()
    local origin = self:GetPos()
    local samples = {
        Vector(48, 0, 0), Vector(-48, 0, 0), Vector(0, 48, 0), Vector(0, -48, 0),
        Vector(64, 64, 0), Vector(-64, 64, 0), Vector(64, -64, 0), Vector(-64, -64, 0),
    }
    for _, off in ipairs(samples) do
        local candidate = safe_ground(origin + off) + Vector(0, 0, 2)
        local tr = util.TraceHull({
            start = candidate + Vector(0, 0, 16),
            endpos = candidate + Vector(0, 0, 16),
            mins = Vector(-36, -36, 0),
            maxs = Vector(36, 36, 120),
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
        if CurTime() < self.SpawnLockedUntil then
            self:StartActivity(ACT_IDLE)
            coroutine.wait(0.05)
            coroutine.yield()
        else
            if CurTime() >= self.NextSummon then
                self.NextSummon = CurTime() + self.Config.summon_interval
                self:SummonSkeletons()
            end

            local target = self:PickTarget()
            if IsValid(target) then
                if not self.IsRaging and self:Health() <= math.max(1, math.floor(self:GetMaxHealth() * self.Config.rage_threshold)) then
                    self:EnterRage()
                end

                self:StartActivity(ACT_MP_RUN_MELEE)
                if not try_set_sequence(self, { "run_melee", "run", "walk_melee", "walk" }) then
                    self:StartActivity(ACT_RUN)
                end
                self:TryFootstepFx()
                self:DirectChase(target)
                self:DoAttack(target)
                self:TryStomp(target)
                coroutine.wait(0.01)
            else
                self:StartActivity(ACT_IDLE)
                try_set_sequence(self, { "idle", "stand_melee" })
                coroutine.wait(0.2)
            end
        end

        coroutine.yield()
    end
end

function ENT:OnTakeDamage(dmginfo)
    if not dmginfo then return 0 end
    local damage = math.max(0, dmginfo:GetDamage() or 0)
    if damage <= 0 then return 0 end

    local hp = self:Health() - damage
    self:SetHealth(hp)

    local att = dmginfo:GetAttacker()
    if is_valid_target(att) then
        self.Target = att
    end

    if hp <= 0 then
        self:OnKilled(att)
    end
    return damage
end

function ENT:OnKilled(attacker)
    if self.Dead then return end
    self.Dead = true

    self:EmitSound("Halloween.skeleton_break", 95, 100)
    if DispatchParticleEffect then
        DispatchParticleEffect("halloween_boss_death", self:GetPos(), self:GetAngles(), self)
    end

    for _, z in ipairs(self.Summons or {}) do
        if IsValid(z) then
            z:Remove()
        end
    end

    -- Valve-style reward signal: guaranteed spell pickup + soul at boss death.
    do
        local dropPos = self:GetPos() + Vector(0, 0, 8)
        local spell = ents.Create("tf_spell_pickup")
        if IsValid(spell) then
            spell:SetPos(dropPos + Vector(0, 0, 6))
            spell:SetAngles(Angle(0, math.random(0, 359), 0))
            spell:Spawn()
            spell:Activate()
            spell:SetNWBool("RareSpellPickup", true)
            spell:DropWithGravity(VectorRand() * 140 + Vector(0, 0, 240))
            timer.Simple(20, function()
                if IsValid(spell) then spell:Remove() end
            end)
        end

        local soul = ents.Create("item_halloween_soul")
        if IsValid(soul) then
            soul:SetPos(dropPos)
            soul:SetAngles(Angle(0, math.random(0, 359), 0))
            soul:Spawn()
            soul:Activate()
            soul:DropWithGravity(VectorRand() * 120 + Vector(0, 0, 220))
            timer.Simple(20, function()
                if IsValid(soul) then soul:Remove() end
            end)
        end
    end

    if IsValid(attacker) then
        self.LastHitBy = attacker
    end

    self:Remove()
end

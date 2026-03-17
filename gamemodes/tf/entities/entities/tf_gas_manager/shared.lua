ENT.Type = "anim"
ENT.Base = "base_anim"

PrecacheParticleSystem("gas_can_red")
PrecacheParticleSystem("gas_can_blue")

local TF_GAS_LIFETIME = 5
local TF_GAS_POINT_RADIUS = 25
local TF_GAS_FALLRATE = 5
local TF_GAS_MOVE_DISTANCE = 10
local TF_GAS_POINT_COUNT = 20
local TF_GAS_UPDATE_INTERVAL = 0.05

if CLIENT then
	function ENT:Draw()
	end
end

if SERVER then
	AddCSLuaFile("shared.lua")

	local function IsInvulnerableLikeValve(ent)
		if not IsValid(ent) or not ent.InCond then return false end
		return ent:InCond(TF_COND_INVULNERABLE)
			or ent:InCond(TF_COND_INVULNERABLE_USER_BUFF)
			or ent:InCond(TF_COND_INVULNERABLE_CARD_EFFECT)
			or ent:InCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED)
	end

	local function CanGetWetLikeValve(target)
		if not IsValid(target) then return false end
		if target.CanGetWet then
			return target:CanGetWet()
		end

		return true
	end

	local function IsTruceActiveLikeValve()
		return GAMEMODE and GAMEMODE.HalloweenBossTruceActive and true or false
	end

	local function ClosestPointOnSegment(startPos, endPos, point)
		local delta = endPos - startPos
		local lengthSqr = delta:Dot(delta)
		if lengthSqr <= 0.0001 then
			return startPos
		end

		local t = math.Clamp((point - startPos):Dot(delta) / lengthSqr, 0, 1)
		return startPos + (delta * t)
	end

	local function PointTouchesTarget(point, target)
		if not point or not IsValid(target) then return false end

		local center = target:WorldSpaceCenter()
		local hitRadius = TF_GAS_POINT_RADIUS + math.max(target:BoundingRadius() * 0.35, 18)
		local closest = ClosestPointOnSegment(point.prev or point.pos, point.pos, center)
		return center:DistToSqr(closest) <= (hitRadius * hitRadius)
	end

	local function CanGasAffectTarget(owner, target)
		if not IsValid(owner) or not IsValid(target) then return false end
		if not target.IsTFPlayer or not target:IsTFPlayer() then return false end
		if target == owner then return false end
		if not owner.IsValidEnemy or not owner:IsValidEnemy(target) then return false end
		if IsTruceActiveLikeValve() then return false end
		if target.InCond and (target:InCond(TF_COND_PHASE) or target:InCond(TF_COND_PASSTIME_INTERCEPTION)) then return false end
		if IsInvulnerableLikeValve(target) then return false end
		if target.CanReceiveCrits and not target:CanReceiveCrits() then return false end
		if not CanGetWetLikeValve(target) then return false end
		return true
	end

	function ENT:Initialize()
		self:SetNoDraw(true)
		self:SetNotSolid(true)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)

		self.SpawnTime = CurTime()
		self.Points = {}
		self.Particles = {}
		self.Touched = {}
		self.KeepMovingPoints = true
		self.LastMoveUpdate = CurTime()
		self.NextUpdate = CurTime()
		local owner = self:GetOwner()
		local teamNum = IsValid(owner) and owner.EntityTeam and owner:EntityTeam() or self:Team()
		self.GasEffectName = (teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS) and "gas_can_blue" or "gas_can_red"

		for i = 1, TF_GAS_POINT_COUNT do
			self:AddGasPoint(i)
		end
	end

	function ENT:AddGasPoint(index)
		local origin = self:GetPos()
		local pos = origin + Vector(math.Rand(-TF_GAS_POINT_RADIUS, TF_GAS_POINT_RADIUS), math.Rand(-TF_GAS_POINT_RADIUS, TF_GAS_POINT_RADIUS), 0)
		local tr = util.TraceLine({
			start = origin,
			endpos = pos,
			mask = MASK_SOLID_BRUSHONLY,
			filter = self,
		})
		if tr.Hit then
			pos = tr.HitPos + (tr.HitNormal * (TF_GAS_POINT_RADIUS + 5))
		end

		self.Points[index] = {
			pos = pos,
			prev = pos,
			spawn = CurTime(),
		}

		local particle = ents.Create("info_particle_system")
		if IsValid(particle) then
			particle:SetPos(pos)
			particle:SetKeyValue("effect_name", self.GasEffectName)
			particle:SetKeyValue("start_active", "1")
			particle:Spawn()
			particle:Activate()
			self.Particles[index] = particle
		end
	end

	function ENT:ShouldRemovePoint(point)
		if not point then return true end
		if CurTime() > point.spawn + TF_GAS_LIFETIME then
			return true
		end

		local contents = util.PointContents(point.pos)
		if bit.band(contents, MASK_WATER) ~= 0 then
			return true
		end

		return false
	end

	function ENT:UpdatePointMotion()
		local minDistanceApart = TF_GAS_POINT_RADIUS * 1.9
		local now = CurTime()
		local dt = math.max(0, now - (self.LastMoveUpdate or now))
		self.LastMoveUpdate = now

		local anyoneMoved = false
		if self.KeepMovingPoints then
			for _, point in ipairs(self.Points) do
				if point then
					local vecDownDir = Vector(0, 0, -TF_GAS_POINT_RADIUS * dt)
					local startPos = point.pos + Vector(0, 0, -TF_GAS_POINT_RADIUS)
					local tr = util.TraceLine({
						start = startPos,
						endpos = startPos + vecDownDir,
						mask = MASK_SOLID_BRUSHONLY,
						filter = self,
					})

					if not tr.Hit then
						point.pos = point.pos + (vecDownDir * TF_GAS_FALLRATE)
						anyoneMoved = true
					end
				end
			end

			for i, point1 in ipairs(self.Points) do
				if point1 then
					local neighborCount = 0
					local result = Vector(0, 0, 0)

					for j, point2 in ipairs(self.Points) do
						if i ~= j and point2 then
							local dist = point2.pos - point1.pos
							if dist:Length() < minDistanceApart then
								result = result + dist
								neighborCount = neighborCount + 1
							end
						end
					end

					if neighborCount > 0 then
						result = result / neighborCount
						local newDir = result:GetNormalized() * -TF_GAS_MOVE_DISTANCE
						local tr = util.TraceLine({
							start = point1.pos,
							endpos = point1.pos + newDir,
							mask = MASK_SOLID_BRUSHONLY,
							filter = self,
						})

						if not tr.Hit then
							point1.pos = point1.pos + newDir
							anyoneMoved = true
						end
					end
				end
			end
		end

		self.KeepMovingPoints = anyoneMoved
	end

	function ENT:UpdateParticles()
		for i, point in ipairs(self.Points) do
			local particle = self.Particles[i]
			if IsValid(particle) and point then
				particle:SetPos(point.pos)
			end
		end
	end

	function ENT:ApplyGasToPlayers()
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		for _, target in ipairs(player.GetAll()) do
			if CanGasAffectTarget(owner, target) and not self.Touched[target] then
				for _, point in ipairs(self.Points) do
					if point and PointTouchesTarget(point, target) then
						target:AddCond(TF_COND_GAS, 10, owner)
						self.Touched[target] = true
						break
					end
				end
			end
		end
	end

	function ENT:Think()
		if CurTime() < (self.NextUpdate or 0) then
			self:NextThink(self.NextUpdate)
			return true
		end
		self.NextUpdate = CurTime() + TF_GAS_UPDATE_INTERVAL

		local anyPoints = false
		for i = #self.Points, 1, -1 do
			local point = self.Points[i]
			if self:ShouldRemovePoint(point) then
				local particle = self.Particles[i]
				if IsValid(particle) then
					particle:Remove()
				end
				table.remove(self.Points, i)
				table.remove(self.Particles, i)
			else
				point.prev = point.pos
				anyPoints = true
			end
		end

		if not anyPoints then
			self:Remove()
			return false
		end

		self:UpdatePointMotion()
		self:UpdateParticles()
		self:ApplyGasToPlayers()

		self:NextThink(self.NextUpdate)
		return true
	end

	function ENT:OnRemove()
		for _, particle in ipairs(self.Particles or {}) do
			if IsValid(particle) then
				particle:Remove()
			end
		end
	end
end

AddCSLuaFile()
ENT.PrintName		= "Bomb"
ENT.Information		= "A Bomb."
ENT.Category		= "Team Fortress 2"

ENT.Spawnable			= true
ENT.AdminSpawnable		= true
ENT.Type = "anim"  
ENT.Base = "item_base"    

ENT.Model = "models/flag/briefcase.mdl"
ENT.Model2 = "models/props_td/atom_bomb.mdl"

game.AddParticles( "particles/mvm.pcf" )
PrecacheParticleSystem( "mvm_levelup1" )
PrecacheParticleSystem( "mvm_levelup2" )
PrecacheParticleSystem( "mvm_levelup3" )  

local FlagReturnTime = 60

local function CarrierTimerName(flag, suffix)
	return "MVMFlag_" .. tostring(flag:EntIndex()) .. "_" .. tostring(suffix)
end

local function RoomTeamMatchesCarrier(room, ply)
	if not IsValid(room) or not IsValid(ply) then return false end
	if not room.GetKeyValues then return true end
	local kv = room:GetKeyValues() or {}
	local rawTeam = tonumber(kv.TeamNum or kv.teamnum or kv.Team or 0) or 0
	if rawTeam <= 0 then return true end
	local mapped = rawTeam
	if rawTeam == 2 then mapped = TEAM_RED end
	if rawTeam == 3 then mapped = TEAM_BLU end
	return mapped == ply:Team()
end

local function IsCarrierInsideRespawnRoom(ply)
	if not IsValid(ply) then return false end
	local p = ply:GetPos()
	for _, room in ipairs(ents.FindByClass("func_respawnroom")) do
		if not IsValid(room) then continue end
		if not RoomTeamMatchesCarrier(room, ply) then continue end
		local mins, maxs = room:WorldSpaceAABB()
		if p.x >= (mins.x - 8) and p.x <= (maxs.x + 8) and
			p.y >= (mins.y - 8) and p.y <= (maxs.y + 8) and
			p.z >= (mins.z - 16) and p.z <= (maxs.z + 16) then
			return true
		end
	end
	return false
end

local function IsRedCaptureZone(zone)
	if not IsValid(zone) then return false end
	local t = tonumber(zone.TeamNum or zone.Team or 0)
	if t == TEAM_RED or t == 2 then return true end
	if zone.GetKeyValues then
		local kv = zone:GetKeyValues() or {}
		local raw = tonumber(kv.TeamNum or kv.teamnum or kv.Team or 0) or 0
		if raw == 2 or raw == TEAM_RED then
			return true
		end
	end
	return false
end

local function IsNearOrigin(v)
	if not isvector(v) then return true end
	return math.abs(v.x) <= 1 and math.abs(v.y) <= 1 and math.abs(v.z) <= 1
end

local function GetEntGoalPos(ent, fallback)
	if not IsValid(ent) then return fallback end
	local pos = nil
	if ent.WorldSpaceCenter then
		local ok, v = pcall(ent.WorldSpaceCenter, ent)
		if ok and isvector(v) then
			pos = v
		end
	end
	if (not isvector(pos) or IsNearOrigin(pos)) and ent.OBBCenter and ent.LocalToWorld then
		local okCenter, center = pcall(ent.OBBCenter, ent)
		if okCenter and isvector(center) then
			local okWorld, world = pcall(ent.LocalToWorld, ent, center)
			if okWorld and isvector(world) then
				pos = world
			end
		end
	end
	if (not isvector(pos) or IsNearOrigin(pos)) and ent.GetPos then
		local ok, v = pcall(ent.GetPos, ent)
		if ok and isvector(v) then
			pos = v
		end
	end
	if isvector(pos) and not IsNearOrigin(pos) then
		return pos
	end
	return fallback
end

local function PickPreferredMvMCaptureZone(anchorPos)
	local best, bestDist
	for _, zone in ipairs(ents.FindByClass("func_capturezone")) do
		if not IsValid(zone) then continue end
		if not IsRedCaptureZone(zone) then continue end
		if not isvector(anchorPos) then
			return zone
		end
		local zonePos = GetEntGoalPos(zone, nil)
		if not isvector(zonePos) then continue end
		local d = zonePos:DistToSqr(anchorPos)
		if not bestDist or d < bestDist then
			bestDist = d
			best = zone
		end
	end
	if IsValid(best) then return best end
	for _, zone in ipairs(ents.FindByClass("func_capturezone")) do
		if IsValid(zone) then return zone end
	end
	return nil
end

if SERVER then

function ENT:SetBombUpgradeLevel(level)
	local lvl = math.Clamp(tonumber(level) or 0, 0, 3)
	self.BombUpgradeLevel = lvl
	self:SetNWInt("MVM_BombUpgradeLevel", lvl)
end

function ENT:ResetBombUpgradeState()
	self.BombUpgradeStartTime = nil
	self:SetNWFloat("MVM_BombUpgradeStartedAt", 0)
	self:SetBombUpgradeLevel(0)
end

function ENT:StartBombUpgradeState()
	self.BombUpgradeStartTime = CurTime()
	self:SetNWFloat("MVM_BombUpgradeStartedAt", self.BombUpgradeStartTime)
	self:SetBombUpgradeLevel(0)
end

function ENT:BeginBombCarrierUpgradeTimers(ply, warn1Timer, warn2Timer, warn3Timer, warnEnd3Timer, healTimer, resistTimer)
	if not IsValid(self) or not IsValid(ply) then return end
	self:StartBombUpgradeState()
	timer.Create(warn1Timer, 10, 1, function()
		if not IsValid(self) or not IsValid(ply) or self.Carrier ~= ply then return end
		self:SetBombUpgradeLevel(1)
		ParticleEffectAttach( "mvm_levelup1", PATTACH_POINT_FOLLOW, ply, ply:LookupAttachment("head") )
		ply:EmitSound("mvm/mvm_warning.wav", 0, 100)
		if (!ply:IsMiniBoss()) then
			ply:TFTaunt(tostring(ply:GetActiveWeapon():GetSlot() + 1))
		end
		timer.Create(healTimer, 5.0, 0, function()
			--ply:SetArmor( 50 )
		end)
	end)

	timer.Create(warn2Timer, 45, 1, function()
		if not IsValid(self) or not IsValid(ply) or self.Carrier ~= ply then return end
		self:SetBombUpgradeLevel(2)
		ParticleEffectAttach( "mvm_levelup2", PATTACH_POINT_FOLLOW, ply, ply:LookupAttachment("head") )
		ply:EmitSound("mvm/mvm_warning.wav", 0, 100)
		if (!ply:IsMiniBoss()) then
			ply:TFTaunt(tostring(ply:GetActiveWeapon():GetSlot() + 1))
		end
		timer.Create(resistTimer, 2, 0, function()
			if not IsValid(self) or not IsValid(self.Carrier) then return end
			GAMEMODE:HealPlayer(self.Carrier, self.Carrier, 5, true, false)
		end)
		for k,v in pairs(player.GetAll()) do
			if not v:IsFriendly(ply) then
				if v:GetPlayerClass() == "heavy" then
					v:EmitSound("vo/heavy_mvm_bomb_upgrade0"..math.random(1,2)..".wav", 80, 100, 1, CHAN_VOICE)
				elseif v:GetPlayerClass() == "soldier" then
					v:EmitSound("vo/soldier_mvm_bomb_upgrade0"..math.random(1,3)..".wav", 80, 100, 1, CHAN_VOICE)
				elseif v:GetPlayerClass() == "medic" then
					v:EmitSound("vo/medic_mvm_bomb_upgrade0"..math.random(1,3)..".wav", 80, 100, 1, CHAN_VOICE)
				elseif v:GetPlayerClass() == "engineer" then
					v:EmitSound("vo/engineer_mvm_bomb_upgrade0"..math.random(1,3)..".wav", 80, 100, 1, CHAN_VOICE)
				end
			end
		end
	end)

	timer.Create(warn3Timer, 65, 1, function()
		if not IsValid(self) or not IsValid(ply) or self.Carrier ~= ply then return end
		self:SetBombUpgradeLevel(3)
		ParticleEffectAttach( "mvm_levelup3", PATTACH_POINT_FOLLOW, ply, ply:LookupAttachment("head") )
		ply:EmitSound("mvm/mvm_warning.wav", 0, 100)
		if (!ply:IsMiniBoss()) then
			ply:TFTaunt(tostring(ply:GetActiveWeapon():GetSlot() + 1))
		end
		for _,pl in pairs(player.GetAll()) do
			if not pl:IsFriendly(ply) then
				if pl:GetPlayerClass() == "heavy" then
					pl:EmitSound("vo/heavy_mvm_bomb_upgrade0"..math.random(1,2)..".wav", 80, 100, 1, CHAN_VOICE)
				elseif pl:GetPlayerClass() == "soldier" then
					pl:EmitSound("vo/soldier_mvm_bomb_upgrade0"..math.random(1,3)..".wav", 80, 100, 1, CHAN_VOICE)
				elseif pl:GetPlayerClass() == "medic" then
					pl:EmitSound("vo/medic_mvm_bomb_upgrade0"..math.random(1,3)..".wav", 80, 100, 1, CHAN_VOICE)
				elseif pl:GetPlayerClass() == "engineer" then
					pl:EmitSound("vo/engineer_mvm_bomb_upgrade0"..math.random(1,3)..".wav", 80, 100, 1, CHAN_VOICE)
				end
			end
		end
	end)

	timer.Create(warnEnd3Timer, 65 + ply:SequenceDuration(ply:LookupSequence("taunt01")), 1, function()
		if not IsValid(ply) then return end
		ply:ConCommand("tf_firstperson")
		ply:Freeze(false)
	end)
end

hook.Add("DoPlayerDeath", "IntelSafeHelp2", function(ply)
	for _,v in pairs(ents.FindByClass("item_teamflag_mvm")) do
		if v.Carrier==ply then
			if v.Deploying then return end
			v:Drop()
		end
	end
end)

concommand.Add("drop_flag_mvm", function(pl)
	for _,v in pairs(ents.FindByClass("item_teamflag_mvm")) do
		if v.Carrier==pl then
			v:Drop()
		end
	end
end)


function ENT:SpawnFunction( ply, tr, ClassName )

	if ( !tr.Hit ) then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 16

	local ent = ents.Create( "item_teamflag_mvm" )
	ent:SetPos( SpawnPos )
	ent.TeamNum = TEAM_RED
	ent:Spawn()
	ent:Activate()

	return ent

end

function ENT:Initialize()
	self:SetSolid(SOLID_VPHYSICS)
	self:SetModel(self.Model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:DrawShadow(false)
	--self:SetNoDraw(true)
	
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:SetTrigger(true)
	self:SetNoDraw(true)
	
	self.Prop = ents.Create("prop_dynamic")
	self.Prop:SetMoveType(MOVETYPE_NONE)
	self.Prop:SetSolid(SOLID_NONE)
	self.Prop:SetModel(self.Model)
	self.Prop:SetPos(self:GetPos())
	self.Prop:SetAngles(self:GetAngles())
	self.Prop:Spawn()
	self.Prop:SetNoDraw(true)	
	

	self.Prop2 = ents.Create("prop_dynamic")
	self.Prop2:SetMoveType(MOVETYPE_NONE)
	self.Prop2:SetSolid(SOLID_NONE)
	self.Prop2:SetModel("models/props_td/atom_bomb.mdl")
	self.Prop2:SetPos(self:GetPos())
	self.Prop2:SetAngles(self:GetAngles())
	self.Prop2:Spawn()
	self.Prop2:SetParent(self.Prop)
	ParticleEffectAttach( "cart_flashinglight", PATTACH_POINT_FOLLOW, self.Prop2, self.Prop2:LookupAttachment("siren") )
	self:SetNWEntity("prop2", self.Prop2)
	self:SetNWEntity("prop", self.Prop)
	
	self.Prop:SetParent(self)
	
	local sequence = self.Prop:LookupSequence("spin")
	self.Prop:ResetSequence(sequence)
	self.Prop:SetPlaybackRate(1)
	self.Prop:SetCycle(1)
	
	if self.TeamNum==0 then
		self:SetSkin(2)
		self.Prop:SetSkin(2)
	elseif self.TeamNum==TEAM_RED then
		self:SetSkin(0)
		self.Prop:SetSkin(0)
	elseif self.TeamNum==TEAM_BLU then
		self:SetSkin(1)
		self.Prop:SetSkin(1)
	end
	
	self.State = 0
	
	
	self.Trail = ents.Create("info_particle_system")
	self.Trail:SetPos(self:GetPos())
	self.Trail:SetAngles(self:GetAngles())
	self.Trail:SetKeyValue("effect_name", "player_intel_trail_"..ParticleSuffix(self.TeamNum))
	self.Trail:Spawn()
	self.Trail:SetParent(self)
	
	self.PickupLock = {}
	self:ResetBombUpgradeState()
	--[[
	0 : home
	1 : carried
	2 : dropped
	]]
	
	--effectdata = EffectData()
	--	effectdata:SetEntity(self)
	--util.Effect("tf_flagtimer", effectdata)
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	
	if key=="gametype" then
		self.GameType = tonumber(value)
	elseif key=="teamnum" then
		self.te = tonumber(value)
		local t = tonumber(value)
		
		if t==0 then
			self.TeamNum = 0
		elseif t==2 then
			self.TeamNum = TEAM_RED
		elseif t==3 then
			self.TeamNum = TEAM_BLU
		end
	end
end

function ENT:Think()
	self:SetNWEntity("carrier", self.Carrier)

	for k, v in pairs(player.GetAll()) do
				local trace = util.QuickTrace(self:GetPos(), v:EyePos() - self:GetPos(), self.Prop)
		if self:GetSkin() == 1 and v:IsBot() and !v:IsHL2() then
			local color = Color(255, 0, 0) 
			if trace.Entity == v then
				color = Color(0, 255, 255)
			end
			debugoverlay.Line(trace.StartPos, trace.HitPos, 1.1, color, true)
			----print(trace.Entity)
		end

		if v:GetPos():Distance(self:GetPos()) <= 80 and self:CanPickup(v) and util.QuickTrace(self:GetPos(), v:EyePos() - self:GetPos(), self.Prop).Entity == v then
			self:PlayerTouched(v)
		end

		----print(self.PickupLock[v])
		if (self.PickupLock) then
			if v:GetPos():Distance(self:GetPos()) >= 80 and self.PickupLock[v] then
				self.PickupLock[v] = nil
			end
		end
	end

	if self.NextReturn then
		if not self.NextClientUpdateTimer or CurTime()>self.NextClientUpdateTimer then
			self:SetNWFloat("TimeRemaining", self.NextReturn - CurTime())
			self.NextClientUpdateTimer = CurTime() + 0.5
		end
		
		if CurTime()>self.NextReturn then
			self:Return()
		end
	else
		self.NextClientUpdateTimer = nil
	end
end

function ENT:CanPickup(ply)
	return ply:Team()~=self.TeamNum and not self.PickupLock[ply]
end

function ENT:StartTouch(ent)
	if ent:IsPlayer() and self:CanPickup(ent) and not self.PickupLock[ent] then
		self:PlayerTouched(ent)
	end
end

function ENT:EndTouch(ent)
	if self.PickupLock[ent] then
		self.PickupLock[ent] = nil
	end
end
 
function ENT:PlayerTouched(pl)
	self:Pickup(pl)
end

function ENT:Capture(activator, captureZone)
	local outputActivator = activator
	if not IsValid(outputActivator) then
		outputActivator = self.Carrier
	end
	if not IsValid(outputActivator) then
		outputActivator = self
	end

	self:TriggerOutput("OnCapture", outputActivator)
	if IsValid(captureZone) and captureZone.TriggerOutput then
		captureZone:TriggerOutput("OnCapture", outputActivator)
	end

	self:Return(true)
	self.Prop2:SetNoDraw(false)
	self.Prop2:SetNoDraw(true)
end

function ENT:Return(nosound)
	if self.State~=0 then
		timer.Remove(CarrierTimerName(self, "DropIfCarrierNotAlive"))
		timer.Remove(CarrierTimerName(self, "Warning1"))
		timer.Remove(CarrierTimerName(self, "Warning2"))
		timer.Remove(CarrierTimerName(self, "Warning3"))
		timer.Remove(CarrierTimerName(self, "WarningEnd3"))
		timer.Remove(CarrierTimerName(self, "CarrierGetsHealed"))
		timer.Remove(CarrierTimerName(self, "CarrierGetsResistance"))
		timer.Remove(CarrierTimerName(self, "UpgradeGate"))
		self:Drop(true)
		self.State = 0
		self:SetNWBool("TimerActive", false)
		self.NextReturn = nil
		self:SetPos(self.HomePosition)
		self:SetAngles(self.HomeAngles)
		--print(self.HomePosition)
		self:TriggerOutput("OnReturn")

		--ParticleEffectAttach( "cart_flashinglight", PATTACH_POINT_FOLLOW, self.Prop2, self.Prop2:LookupAttachment("siren") )
		if nosound then
			return
		end

		for _, ply in pairs(player.GetAll()) do
			ply:SendLua([[LocalPlayer():EmitSound("MVM.AttackDefend.EnemyReturned")]])
		end
	end
end

function ENT:Pickup(ply)
	if self.State~=1 and not IsValid(self.Carrier) then
		local dropTimer = CarrierTimerName(self, "DropIfCarrierNotAlive")
		local warn1Timer = CarrierTimerName(self, "Warning1")
		local warn2Timer = CarrierTimerName(self, "Warning2")
		local warn3Timer = CarrierTimerName(self, "Warning3")
		local warnEnd3Timer = CarrierTimerName(self, "WarningEnd3")
		local healTimer = CarrierTimerName(self, "CarrierGetsHealed")
		local resistTimer = CarrierTimerName(self, "CarrierGetsResistance")
		local upgradeGateTimer = CarrierTimerName(self, "UpgradeGate")

		timer.Remove(dropTimer)
		timer.Remove(warn1Timer)
		timer.Remove(warn2Timer)
		timer.Remove(warn3Timer)
		timer.Remove(warnEnd3Timer)
		timer.Remove(healTimer)
		timer.Remove(resistTimer)
		timer.Remove(upgradeGateTimer)

		if not self.HomePosition or not self.HomeAngles then
			self.HomePosition = self:GetPos()
			self.HomeAngles = self:GetAngles()
		end
		self.isCarryingIntel = true
		
		self:SetNWBool("TimerActive", false)
		self.NextReturn = nil
	
		local cap = PickPreferredMvMCaptureZone(self:GetPos())
		if IsValid(cap) then
			ply.botPos = cap.Pos or GetEntGoalPos(cap, cap:GetPos())
		end
		self.State = 1
		self.Carrier = ply
		self:ResetBombUpgradeState()
		self.Prop:ResetSequence(self.Prop:LookupSequence("idle"))
		self.Prop:SetPlaybackRate(1)
		self.Prop:SetCycle(1)
		self:SetNotSolid(true)
		self:SetTrigger(false)
		self:SetParent(ply)
		self:Fire("SetParentAttachment", "flag", 0)
		if ply:IsHL2() then
			self:Fire("SetParentAttachment", "chest", 0)
		end
		self:TriggerOutput("OnPickup", ply)
		hook.Run("TF_MVM_BombPickedUp", ply, self)

		for _, ply in pairs(player.GetAll()) do
			if ply:Team() == self.TeamNum then
				ply:Speak("TLK_MVM_BOMB_PICKUP") 
			end
		end  
	
			timer.Create(dropTimer, 0.1, 0, function()
				if not IsValid(self) or not IsValid(ply) then
					timer.Remove(dropTimer)
					return
				end
				if ply:Alive() then
				if !string.find(ply:GetModel(),"_boss.mdl") then
					ply:SetClassSpeed(ply:GetPlayerClassTable().Speed * 0.5)		
				end  
				if ply:HasGodMode() then
					self.Prop2:SetMaterial("models/effects/invulnfx_blue")
				else
					self.Prop2:SetMaterial("")
				end
			end
	
				if not ply:Alive() then
					if self.Deploying then return end
					ply:Freeze(false)
					ply:SetNoDraw(false)
				self:SetNoDraw(false)
				timer.Remove(warn1Timer)
				timer.Remove(warn2Timer)
				timer.Remove(warn3Timer)
				timer.Remove(warnEnd3Timer)
				timer.Remove(healTimer)
				timer.Remove(resistTimer)
				for k,v in pairs(player.GetAll()) do 
					if not ply:IsFriendly(v) then
						v:Speak("TLK_MVM_BOMB_DROPPED")
					end
				end
				self:Drop()
				self.Carrier = nil
				timer.Remove(dropTimer)
			end
		end)
		timer.Create(upgradeGateTimer, 0.1, 0, function()
			if not IsValid(self) or not IsValid(ply) or self.Carrier ~= ply then
				timer.Remove(upgradeGateTimer)
				return
			end
			if IsCarrierInsideRespawnRoom(ply) then
				return
			end
			timer.Remove(upgradeGateTimer)
			self:BeginBombCarrierUpgradeTimers(ply, warn1Timer, warn2Timer, warn3Timer, warnEnd3Timer, healTimer, resistTimer)
		end)
	end
end

function ENT:Drop(nosound)
	if self.State==1 and IsValid(self.Carrier) then
		timer.Remove(CarrierTimerName(self, "DropIfCarrierNotAlive"))
		timer.Remove(CarrierTimerName(self, "Warning1"))
		timer.Remove(CarrierTimerName(self, "Warning2"))
		timer.Remove(CarrierTimerName(self, "Warning3"))
		timer.Remove(CarrierTimerName(self, "WarningEnd3"))
		timer.Remove(CarrierTimerName(self, "CarrierGetsHealed"))
		timer.Remove(CarrierTimerName(self, "CarrierGetsResistance"))
		timer.Remove(CarrierTimerName(self, "UpgradeGate"))
		self:SetNWBool("TimerActive", true)
		self:SetNWFloat("TimeRemaining", FlagReturnTime)
		self.NextReturn = CurTime() + FlagReturnTime
		
		local ply = self.Carrier
		self.PickupLock[ply] = 1 -- Prevent the player who dropped it to pick it up immediately again
		self.State = 2
		self.Carrier = nil
		self:ResetBombUpgradeState()
		self.Prop:ResetSequence(self.Prop:LookupSequence("spin"))
		self.Prop:SetPlaybackRate(1)
		self.Prop:SetCycle(1)
		self.Prop2:SetPlaybackRate(1)
		self.Prop2:SetCycle(1)
		self:SetNotSolid(false)
		self:SetTrigger(true)
		self:SetParent()
		self:SetAngles(Angle(0, self:GetAngles().y, 0))
		self:DropToFloor()
		self:TriggerOutput("OnDrop", ply)

		self:SetMoveType(MOVETYPE_FLYGRAVITY)
		self:SetMoveCollide(MOVECOLLIDE_FLY_BOUNCE)
		
		--ParticleEffectAttach( "cart_flashinglight", PATTACH_POINT_FOLLOW, self.Prop2, self.Prop2:LookupAttachment("siren") )
		if nosound then
			return
		end
		self:GetNWEntity("prop2", self):SetNoDraw(false)
		for _, ply in pairs(player.GetAll()) do
			if ply:Team() == self.TeamNum then
				ply:Speak("TLK_MVM_BOMB_DROPPED")
			end
		end
	end
end

function ENT:AcceptInput(name, activator, caller, value)
	name = string.lower(name)
	if name=="skin" then
		self:SetSkin(tonumber(value) or 0)
	elseif name=="setteam" then
		local t = tonumber(value)
		
		if t==0 then
			self.TeamNum = 0
			self:SetSkin(2)
			self.Prop:SetSkin(2)
		elseif t==2 then
			self.TeamNum = TEAM_RED
			self:SetSkin(0)
			self.Prop:SetSkin(0)
		elseif t==3 then
			self.TeamNum = TEAM_BLU
			self:SetSkin(1)
			self.Prop:SetSkin(1)
		end
	end
end

end

if CLIENT then

ENT.RenderGroup = RENDERGROUP_BOTH

local colors = {
	[0]=Color(255,0,0,255),
	[1]=Color(0,0,255,255),
	[2]=Color(255,255,255,255),
}

function ENT:Initialize()
	self.Progress = vgui.Create("CircularProgressBar")
	self.Progress:SetSize(128, 128)
	self.Progress:SetBackgroundTexture("vgui/flagtime_empty")
	self.Progress:SetForegroundTexture("vgui/flagtime_full")
	self.Progress:SetProgress(0)
	self.Progress:SetCentered(true)
	self.Progress:SetVisible(false)
	
	local min, max = self:GetRenderBounds()
	max.z = max.z + 100
	self:SetRenderBounds(min, max)
end

function ENT:Draw()
	if IsValid(self:GetNWEntity("prop", self)) and IsValid(self:GetParent()) then
		if self:GetParent() == LocalPlayer() and !LocalPlayer():ShouldDrawLocalPlayer() then
			self:GetNWEntity("prop", self):SetNoDraw(true) -- true)
		end

		if self:GetParent():IsHL2() and self:GetParent():LookupAttachment("chest") > 0 then
			local att = self:GetParent():GetAttachment(self:GetParent():LookupAttachment("chest"))
			local ang = att.Ang
			local pos = att.Pos
			local pos2, ang2 = LocalToWorld(ang:Forward() * 10, Angle(90, 0, 180), pos, ang)
			self:GetNWEntity("prop", self):SetAngles(ang2)
			self:GetNWEntity("prop", self):SetPos(pos - ang:Forward() * 10)
			--self:Fire("SetParentAttachment", "chest", 0)
		end
	end

	if not self:GetNWBool("TimerActive") then return end
	
	local s = 1
	if self.OldSkin~=s then
		self.Progress:SetBackgroundColor(colors[s])
		self.Progress:SetForegroundColor(colors[s])
		self.OldSkin = s
	end
	
	local ang = EyeAngles()
	ang:RotateAroundAxis(ang:Right(), 90)
	ang:RotateAroundAxis(ang:Up(), -90)
	
	local W,H = ScrW(), ScrH()
	
	cam.Start3D2D(self:GetPos()+Vector(0,0,70), ang, 0.3)
		self.Progress:Paint()
	cam.End3D2D()
end

function ENT:Think()
	if self:GetNWBool("TimerActive") then
		if not self.NextReturn or self.OldTimeRemaining~=self:GetNWFloat("TimeRemaining") then
			self.OldTimeRemaining = self:GetNWFloat("TimeRemaining")
			self.NextReturn = CurTime() + self.OldTimeRemaining
		end
	end
	
	if self.NextReturn then
		self.Progress:SetProgress((self.NextReturn - CurTime())/FlagReturnTime)
	end
	if (self.Carrier and self.Carrier.TFBot) then

		for _,capturezone in ipairs(ents.FindByClass("func_capturezone")) do
			self.Carrier.botPos = capturezone.Pos
		end

	end
	self:NextThink(CurTime())
end

end

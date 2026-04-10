ENT.Type = "point"

local function is_active_team(teamNum)
	return teamNum == TEAM_RED or teamNum == TEAM_BLU
end

local function allow_instant_spawn(ply)
	if not IsValid(ply) then return end
	if ply.AllowInstantSpawn then
		ply:AllowInstantSpawn()
	else
		ply.NextSpawnTime = CurTime()
	end
end

local function player_has_defined_class(ply)
	if not (IsValid(ply) and ply:IsPlayer()) then
		return false
	end
	local className = ply.GetPlayerClass and string.Trim(tostring(ply:GetPlayerClass() or "")) or ""
	return className ~= ""
end

local function cleanup_world_entities(removeEverything)
	if not removeEverything then
		return
	end

	for _, ent in ipairs(ents.GetAll()) do
		if not IsValid(ent) then continue end
		local className = string.lower(tostring(ent:GetClass() or ""))

		if ent.IsBuilding and ent:IsBuilding() then
			ent:Remove()
		elseif string.StartWith(className, "tf_projectile_")
			or string.find(className, "grenade", 1, true)
			or className == "tf_ammo_pack"
			or string.find(className, "item_ammopack", 1, true)
		then
			ent:Remove()
		end
	end
end

local function switch_player_team(ply)
	if not (IsValid(ply) and ply:IsPlayer()) then return end
	if ply:Team() == TEAM_RED then
		ply:SetTeam(TEAM_BLU)
	elseif ply:Team() == TEAM_BLU then
		ply:SetTeam(TEAM_RED)
	end
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
	if string.StartWith(key, "on") then
		self:StoreOutput(key, value)
	end
end

function ENT:ForceRespawnPlayers(switchTeams, teamNum, removeEverything)
	cleanup_world_entities(removeEverything)

	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) then continue end

		if not is_active_team(ply:Team()) then
			allow_instant_spawn(ply)
			continue
		end

		if switchTeams then
			switch_player_team(ply)
		end

		if not player_has_defined_class(ply) then
			allow_instant_spawn(ply)
			continue
		end

		if teamNum ~= nil and teamNum ~= TEAM_UNASSIGNED then
			if ply:Team() ~= teamNum then
				continue
			end
			if ply:Alive() then
				continue
			end
		end

		if ply.UnSpectate then
			ply:UnSpectate()
		end
		if ply.TF2_ForceRespawn then
			ply:TF2_ForceRespawn()
		else
			ply:Spawn()
		end
	end

	self:TriggerOutput("OnForceRespawn", self)
end

function ENT:Input_ForceRespawn()
	self:ForceRespawnPlayers(false, nil, true)
end

function ENT:Input_ForceRespawnSwitchTeams()
	self:ForceRespawnPlayers(true, nil, true)
end

function ENT:Input_ForceTeamRespawn(_, _, data)
	local teamNum = tonumber(data)
	if not teamNum then return end
	self:ForceRespawnPlayers(false, teamNum, false)
end

function ENT:AcceptInput(name, activator, caller, data)
	local fn = self["Input_" .. tostring(name or "")]
	if fn then
		fn(self, activator, caller, data)
		return true
	end
	return false
end

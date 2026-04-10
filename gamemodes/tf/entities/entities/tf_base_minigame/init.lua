ENT.Type = "point"

local SCORETYPE_POINTS = 0
local SCORETYPE_PLAYERS_ALIVE = 1

local function ClampTeam(team)
	if team == TEAM_RED then return TEAM_RED end
	return TEAM_BLU
end

local function GetRegistry()
	GAMEMODE.TFMiniGames = GAMEMODE.TFMiniGames or {}
	return GAMEMODE.TFMiniGames
end

local function GetPlayingTeamPlayers(team)
	local players = {}
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:Team() == team then
			table.insert(players, ply)
		end
	end
	return players
end

local function FindSpawnTarget(name)
	if not isstring(name) or name == "" then
		return NULL
	end
	return ents.FindByName(name)[1] or NULL
end

local function EmitMiniGameScoreSounds(minigame, scoringTeam)
	if not IsValid(minigame) then
		return
	end

	local yourSound = string.Trim(tostring(minigame.YourTeamScoreSound or ""))
	local enemySound = string.Trim(tostring(minigame.EnemyTeamScoreSound or ""))
	if yourSound == "" or enemySound == "" then
		return
	end

	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or ply:Team() == TEAM_SPECTATOR then
			continue
		end

		if ply:Team() == scoringTeam then
			ply:EmitSound(yourSound, 75, 100)
		else
			ply:EmitSound(enemySound, 75, 100)
		end
	end
end

local function ApplyGlobals(minigame)
	SetGlobalString("tf_minigame_hud_res", tostring(minigame.HudResFile or ""))
	SetGlobalInt("tf_minigame_red_score", minigame.RedScore or 0)
	SetGlobalInt("tf_minigame_blue_score", minigame.BlueScore or 0)
	SetGlobalInt("tf_minigame_max_score", minigame.MaxScore or 0)
	SetGlobalBool("tf_minigame_active", minigame.IsActive and true or false)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.RedScore = 0
	self.BlueScore = 0
	self.IsActive = false
	self.AdvantageTeam = -1
	self.SuddenDeathActive = false
	self:ReloadProperties()
	GetRegistry()[self] = true
	ApplyGlobals(self)
end

function ENT:ReloadProperties()
	local props = self.Properties or {}
	self.RedSpawnName = tostring(props.redspawn or "")
	self.BlueSpawnName = tostring(props.bluespawn or "")
	self.AllowedInRandomPool = tonumber(props.inrandompool) ~= 0
	self.MaxScore = math.max(1, tonumber(props.maxscore) or 5)
	self.HudResFile = tostring(props.hud_res_file or "")
	self.YourTeamScoreSound = tostring(props.your_team_score_sound or "")
	self.EnemyTeamScoreSound = tostring(props.enemy_team_score_sound or "")
	self.ScoreType = tonumber(props.scoretype) or SCORETYPE_POINTS
	self.SuddenDeathTime = tonumber(props.suddendeathtime) or -1
end

function ENT:OnRemove()
	GetRegistry()[self] = nil
	timer.Remove("tf_minigame_suddendeath_" .. self:EntIndex())
end

function ENT:KeyValue(key, value)
	if string.Left(key, 2) == "On" then
		self:StoreOutput(key, value)
	end

	key = string.lower(key)
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

function ENT:GetScore(team)
	team = ClampTeam(team)
	return team == TEAM_RED and self.RedScore or self.BlueScore
end

function ENT:SetScore(team, score, activator)
	team = ClampTeam(team)
	local previous = self:GetScore(team)
	local clamped = math.Clamp(math.floor(tonumber(score) or 0), 0, self.MaxScore)
	if team == TEAM_RED then
		self.RedScore = clamped
	else
		self.BlueScore = clamped
	end

	ApplyGlobals(self)

	if clamped > previous then
		EmitMiniGameScoreSounds(self, team)
	end

	if clamped >= self.MaxScore or self.SuddenDeathActive then
		if team == TEAM_RED then
			self:TriggerOutput("OnRedHitMaxScore", activator or self)
		else
			self:TriggerOutput("OnBlueHitMaxScore", activator or self)
		end
	end
end

function ENT:AddScore(team, delta, activator)
	if not self.IsActive then
		return
	end
	self:SetScore(team, self:GetScore(team) + (tonumber(delta) or 0), activator)
end

function ENT:TeleportTeamPlayers(team, targetName)
	local dest = FindSpawnTarget(targetName)
	if not IsValid(dest) then
		return
	end

	for _, ply in ipairs(GetPlayingTeamPlayers(team)) do
		if not IsValid(ply) then continue end
		local offset = Vector(math.Rand(-24, 24), math.Rand(-24, 24), 8)
		if not ply:Alive() and ply.Spawn then
			ply:Spawn()
		end
		ply:SetPos(dest:GetPos() + offset)
	end
end

function ENT:TeleportAllPlayers()
	self:TeleportTeamPlayers(TEAM_RED, self.RedSpawnName)
	self:TeleportTeamPlayers(TEAM_BLU, self.BlueSpawnName)
	self.IsActive = true
	self.SuddenDeathActive = false
	self.RedScore = 0
	self.BlueScore = 0
	self:TriggerOutput("OnTeleportToMinigame", self)
	ApplyGlobals(self)

	timer.Remove("tf_minigame_suddendeath_" .. self:EntIndex())
	local override = GetConVar("tf_minigame_suddendeath_time")
	local suddenDeathTime = self.SuddenDeathTime
	if override and override:GetFloat() ~= -1 then
		suddenDeathTime = override:GetFloat()
	end
	if suddenDeathTime and suddenDeathTime >= 0 then
		timer.Create("tf_minigame_suddendeath_" .. self:EntIndex(), suddenDeathTime, 1, function()
			if not IsValid(self) or not self.IsActive then return end
			self.SuddenDeathActive = true
			self:TriggerOutput("OnSuddenDeathStart", self)
		end)
	end
end

function ENT:ReturnAllPlayers()
	timer.Remove("tf_minigame_suddendeath_" .. self:EntIndex())
	self.IsActive = false
	self.SuddenDeathActive = false
	self.RedScore = 0
	self.BlueScore = 0
	self:TriggerOutput("OnReturnFromMinigame", self)
	ApplyGlobals(self)

	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:Team() ~= TEAM_SPECTATOR and ply.Spawn then
			ply:Spawn()
		end
	end
end

function ENT:UpdateDeathState()
	if not self.IsActive then
		return
	end

	local function teamAliveCount(team)
		local total = 0
		local alive = 0
		for _, ply in ipairs(GetPlayingTeamPlayers(team)) do
			total = total + 1
			if ply:Alive() then
				alive = alive + 1
			end
		end
		return total, alive
	end

	local redTotal, redAlive = teamAliveCount(TEAM_RED)
	local bluTotal, bluAlive = teamAliveCount(TEAM_BLU)

	if self.ScoreType == SCORETYPE_PLAYERS_ALIVE then
		self.RedScore = redAlive
		self.BlueScore = bluAlive
		ApplyGlobals(self)
	end

	if redTotal > 0 and redAlive == 0 then
		self.IsActive = false
		self:TriggerOutput("OnAllRedDead", self)
		if self.ScoreType == SCORETYPE_PLAYERS_ALIVE then
			self:TriggerOutput("OnBlueHitMaxScore", self)
		end
	end

	if bluTotal > 0 and bluAlive == 0 then
		self.IsActive = false
		self:TriggerOutput("OnAllBlueDead", self)
		if self.ScoreType == SCORETYPE_PLAYERS_ALIVE then
			self:TriggerOutput("OnRedHitMaxScore", self)
		end
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))

	if name == "scoreteamred" then
		self:AddScore(TEAM_RED, tonumber(data) or 0, activator)
		return true
	elseif name == "scoreteamblue" then
		self:AddScore(TEAM_BLU, tonumber(data) or 0, activator)
		return true
	elseif name == "returnfromminigame" then
		self:ReturnAllPlayers()
		return true
	elseif name == "changehudresfile" then
		self.HudResFile = tostring(data or "")
		ApplyGlobals(self)
		return true
	end

	return false
end

hook.Add("PlayerDeath", "TF_Minigame_PlayerDeath", function()
	for minigame in pairs(GetRegistry()) do
		if IsValid(minigame) then
			minigame:UpdateDeathState()
		end
	end
end)

hook.Add("PlayerSpawn", "TF_Minigame_PlayerSpawn", function()
	for minigame in pairs(GetRegistry()) do
		if IsValid(minigame) then
			minigame:UpdateDeathState()
		end
	end
end)

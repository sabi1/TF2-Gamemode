ENT.Type = "point"

util.AddNetworkString("TFPasstimeAskForBall")
util.AddNetworkString("TF_PasstimeNotify")

local PASSTIME_SCORE_LIMIT = CreateConVar(
	"tf_passtime_scores_per_round",
	"5",
	{ FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED },
	"Number of scores required to win a PASSTIME round."
)
local PASSTIME_BALL_RESET_TIME = CreateConVar(
	"tf_passtime_ball_reset_time",
	"15",
	{ FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED },
	"How long a loose PASSTIME ball may remain grounded/idle before it respawns."
)

local activeCarrier

local function resolvePasstimeText(token, fallback)
	if not token or token == "" then
		return fallback
	end

	if tf_lang and tf_lang.GetRaw then
		local text = tf_lang.GetRaw(token, true)
		if isstring(text) and text ~= "" and text ~= token and text ~= string.Trim(token, "#") then
			return text
		end
	end

	return fallback or token
end

local function getPasstimeNotificationResPath(token)
	local map = {
		["#TF_Passtime_No_Tele"] = "resource/ui/notifications/notify_passtime_no_tele.res",
		["#TF_Passtime_No_Carry"] = "resource/ui/notifications/notify_passtime_no_carry.res",
		["#TF_Passtime_No_Invuln"] = "resource/ui/notifications/notify_passtime_no_invuln.res",
		["#TF_Passtime_No_Disguise"] = "resource/ui/notifications/notify_passtime_no_disguise.res",
		["#TF_Passtime_No_Cloak"] = "resource/ui/notifications/notify_passtime_no_cloak.res",
		["#TF_Passtime_No_Oob"] = "resource/ui/notifications/notify_passtime_no_oob.res",
		["#TF_Passtime_No_Holster"] = "resource/ui/notifications/notify_passtime_no_holster.res",
		["#TF_Passtime_No_Taunt"] = "resource/ui/notifications/notify_passtime_no_taunt.res",
	}

	return map[token]
end

local function notifyPasstimeCarryDenied(ply, token)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	local now = CurTime()
	ply._tfPasstimeDeniedNotifyAt = ply._tfPasstimeDeniedNotifyAt or {}
	local nextAllowedAt = tonumber(ply._tfPasstimeDeniedNotifyAt[token]) or 0
	if nextAllowedAt > now then
		return
	end
	ply._tfPasstimeDeniedNotifyAt[token] = now + 1.0

	local message = resolvePasstimeText(token, nil)
	local resPath = getPasstimeNotificationResPath(token)
	if SERVER and isstring(resPath) and resPath ~= "" then
		net.Start("TF_PasstimeNotify")
		net.WriteString(token or "")
		net.WriteString(resPath)
		net.Send(ply)
	elseif isstring(message) and message ~= "" then
		ply:PrintMessage(HUD_PRINTCENTER, message)
	end
	ply:EmitSound("Player.DenyWeaponSelection")
end

function TF_PasstimeNotifyDenied(ply, token)
	notifyPasstimeCarryDenied(ply, token)
end

local function playAskForBallCue(requester, carrier)
	if not (IsValid(requester) and IsValid(carrier)) then return end

	local props = sound.GetProperties and sound.GetProperties("Passtime.AskForBall") or nil
	if not props then return end

	local rf = RecipientFilter()
	rf:AddPlayer(requester)
	if carrier ~= requester then
		rf:AddPlayer(carrier)
	end

	EmitSound(
		"Passtime.AskForBall",
		requester:GetPos(),
		requester:EntIndex(),
		CHAN_AUTO,
		1,
		props.level or 75,
		0,
		100,
		0,
		rf
	)
end

local function firePasstimeGameEvent(eventName, fields)
	if not (SERVER and gameeventmanager and gameeventmanager.CreateEvent and isstring(eventName) and eventName ~= "") then
		return
	end

	local event = gameeventmanager:CreateEvent(eventName)
	if not event then
		return
	end

	for key, value in pairs(fields or {}) do
		if isnumber(value) then
			if math.floor(value) == value then
				event:SetInt(key, value)
			else
				event:SetFloat(key, value)
			end
		elseif isstring(value) then
			event:SetString(key, value)
		elseif isbool(value) then
			event:SetBool(key, value)
		end
	end

	gameeventmanager:FireEvent(event)
end

local function getActiveLogic()
	for _, logic in ipairs(ents.FindByClass("passtime_logic")) do
		if IsValid(logic) and not logic.Disabled then
			return logic
		end
	end
end

local function clampTeam(team)
	if team == TEAM_RED then return TEAM_RED end
	return TEAM_BLU
end

local function findPathTrackByName(name)
	if not isstring(name) or name == "" then return nil end
	for _, ent in ipairs(ents.FindByName(name)) do
		if IsValid(ent) and ent:GetClass() == "path_track" then
			return ent
		end
	end
	return nil
end

local function getTeamScore(logic, team)
	team = clampTeam(team)
	return team == TEAM_RED and (logic.RedScore or 0) or (logic.BlueScore or 0)
end

local function setCarrierState(ply, hasBall)
	if not IsValid(ply) then return end
	ply:SetNWBool("TFHasPasstimeBall", hasBall and true or false)
end

local function panicRespawnBall(logic, ballEntity, activator)
	if not IsValid(logic) then
		return false
	end

	if IsValid(ballEntity) and logic.BallEntity == ballEntity then
		logic.BallEntity = nil
	end

	if IsValid(ballEntity) then
		ballEntity.TFPasstimeSuppressRemovedRespawn = true
		ballEntity:Remove()
	end

	logic.BallState = "removed"
	logic:TriggerOutput("OnBallRemoved", activator or ballEntity or logic)
	logic:ScheduleRespawnBall()
	updateGlobals(logic)
	return true
end

function TF_PasstimePanicRespawnBall(ballEntity, activator)
	return panicRespawnBall(getActiveLogic(), ballEntity, activator)
end

function TF_PasstimeSetPassTarget(owner, target)
	if not IsValid(owner) or not owner:IsPlayer() then
		return
	end

	local previousTarget = owner:GetNWEntity("TFPasstimePassTarget")
	if IsValid(previousTarget) and previousTarget:IsPlayer() and previousTarget ~= target then
		previousTarget:SetNWBool("TFPasstimeIsTargeted", false)
	end

	if IsValid(target) and target:IsPlayer() and target ~= owner then
		target:SetNWBool("TFPasstimeIsTargeted", true)
		owner:SetNWEntity("TFPasstimePassTarget", target)
	else
		owner:SetNWEntity("TFPasstimePassTarget", NULL)
	end
end

local function closestPointOnSegment(point, segStart, segEnd)
	local delta = segEnd - segStart
	local lengthSqr = delta:LengthSqr()
	if lengthSqr <= 0.0001 then
		return segStart, 0
	end

	local frac = math.Clamp((point - segStart):Dot(delta) / lengthSqr, 0, 1)
	return segStart + delta * frac, frac
end

local function buildTrackPoints(logic)
	if not IsValid(logic) or not istable(logic.TrackPoints) then
		return nil
	end

	local startTrack = logic.TrackPoints.start
	local endTrack = logic.TrackPoints.finish
	if not IsValid(startTrack) or not IsValid(endTrack) then
		return nil
	end

	local points = {}
	local seen = {}
	local node = startTrack
	for _ = 1, 16 do
		if not IsValid(node) or seen[node] then
			break
		end
		seen[node] = true
		points[#points + 1] = node:GetPos()
		if node == endTrack then
			break
		end
		node = node.GetInternalVariable and node:GetInternalVariable("m_pNext") or nil
	end

	if #points == 0 then
		return nil
	end
	if points[#points] ~= endTrack:GetPos() then
		points[#points + 1] = endTrack:GetPos()
	end

	return #points >= 2 and points or nil
end

local function calcProgressFracFromTrackPoints(trackPoints, vecOrigin)
	if not istable(trackPoints) or #trackPoints < 2 or not isvector(vecOrigin) then
		return 0.5
	end

	local bestDist = math.huge
	local bestLen = 0
	local totalLen = 1
	local prevPoint = trackPoints[1]

	for i = 2, #trackPoints do
		local thisPoint = trackPoints[i]
		if not isvector(thisPoint) then
			break
		end

		local segLen = prevPoint:Distance(thisPoint)
		totalLen = totalLen + segLen
		local pointOnLine, segFrac = closestPointOnSegment(vecOrigin, prevPoint, thisPoint)
		local dist = pointOnLine:Distance(vecOrigin)
		if dist < bestDist then
			bestDist = dist
			bestLen = totalLen - (segLen * (1 - segFrac))
		end
		prevPoint = thisPoint
	end

	return math.Clamp(bestLen / totalLen, 0, 1)
end

local function calcBallProgressFrac(logic)
	if not IsValid(logic) then
		return 0.5
	end

	local origin = nil
	if IsValid(logic.BallCarrier) then
		origin = logic.BallCarrier:GetPos()
	elseif IsValid(logic.BallEntity) then
		origin = logic.BallEntity:GetPos()
	end

	if not isvector(origin) then
		return 0.5
	end

	local trackPoints = buildTrackPoints(logic)
	if trackPoints then
		return calcProgressFracFromTrackPoints(trackPoints, origin)
	end

	local numSections = math.max(0, tonumber(logic.NumSections) or 0)
	local currentSection = math.Clamp(tonumber(logic.CurrentSection) or 0, 0, math.max(numSections, 1))
	if numSections > 0 then
		return math.Clamp(currentSection / numSections, 0, 1)
	end

	return 0.5
end

local function getRespawnCountdownRemaining(logic)
	if not IsValid(logic) then
		return 0
	end

	local endTime = tonumber(logic.BallRespawnAt) or 0
	if endTime <= CurTime() then
		return 0
	end

	return math.max(0, math.ceil(endTime - CurTime()))
end

local function updateGlobals(logic)
	SetGlobalBool("tf_passtime_map", IsValid(logic) and not logic.Disabled or false)
	SetGlobalInt("tf_passtime_red_score", IsValid(logic) and (logic.RedScore or 0) or 0)
	SetGlobalInt("tf_passtime_blue_score", IsValid(logic) and (logic.BlueScore or 0) or 0)
	SetGlobalInt("tf_passtime_num_sections", IsValid(logic) and (logic.NumSections or 0) or 0)
	SetGlobalInt("tf_passtime_current_section", IsValid(logic) and (logic.CurrentSection or 0) or 0)
	SetGlobalInt("tf_passtime_ball_spawn_countdown", IsValid(logic) and getRespawnCountdownRemaining(logic) or 0)
	SetGlobalFloat("tf_passtime_max_pass_range", IsValid(logic) and (logic.MaxPassRange or 0) or 0)
	SetGlobalFloat("tf_passtime_ball_progress_frac", IsValid(logic) and calcBallProgressFrac(logic) or 0.5)
	SetGlobalInt("tf_passtime_ball_power", IsValid(logic) and (logic.BallPower or 0) or 0)
	SetGlobalBool("tf_passtime_ball_free", IsValid(logic) and logic.BallState == "free" or false)
end

function TF_PlayerHasPasstimeBall(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return false end
	if ply:GetNWBool("TFHasPasstimeBall", false) then return true end
	return ply:HasWeapon("tf_weapon_passtime_gun")
end

function TF_GetPasstimeBallCarrier()
	if IsValid(activeCarrier) and TF_PlayerHasPasstimeBall(activeCarrier) then
		return activeCarrier
	end
	return nil
end

local function selectSpawner()
	local enabled = {}
	local all = ents.FindByClass("info_passtime_ball_spawn")
	for _, spawner in ipairs(all) do
		if IsValid(spawner) and not spawner.Disabled then
			enabled[#enabled + 1] = spawner
		end
	end

	if #enabled > 0 then
		return enabled[math.random(#enabled)]
	end

	return all[1]
end

local function getPasstimeBallSkin(ent, fallback)
	if IsValid(ent) and ent.GetSkin then
		return math.max(0, math.floor(tonumber(ent:GetSkin()) or 0))
	end
	return math.max(0, math.floor(tonumber(fallback) or 0))
end

local function clearExistingBallEntity(logic)
	if IsValid(logic.BallEntity) then
		logic.BallEntity:Remove()
	end
	logic.BallEntity = nil
end

local function clearCarrier(logic, ply)
	local carrier = ply or logic.BallCarrier or activeCarrier
	if IsValid(carrier) then
		setCarrierState(carrier, false)
		TF_PasstimeSetPassTarget(carrier, nil)
	end
	if carrier == activeCarrier then
		activeCarrier = nil
	end
	logic.BallCarrier = nil
end

local function triggerBallGetOutputs(logic, carrier)
	logic:TriggerOutput("OnBallGetAny", carrier)
	if carrier:Team() == TEAM_RED then
		logic:TriggerOutput("OnBallGetRed", carrier)
	elseif carrier:Team() == TEAM_BLU then
		logic:TriggerOutput("OnBallGetBlu", carrier)
	end
	firePasstimeGameEvent("pass_get", {
		owner = carrier:EntIndex(),
		team = carrier:Team(),
	})
end

local function gameplayActive()
	return GAMEMODE and not GAMEMODE.RoundHasWinner
end

local function playerHasCond(ply, cond)
	return cond ~= nil and ply.InCond and ply:InCond(cond)
end

local function getStoredWeaponClassForPasstime(ply)
	if not IsValid(ply) then return nil end
	local active = ply:GetActiveWeapon()
	if not IsValid(active) then return nil end
	local class = active.GetClass and active:GetClass() or nil
	if class == "tf_weapon_passtime_gun" then
		return nil
	end
	return class
end

function TF_PasstimeBallPickedUp(ply, weapon)
	local logic = getActiveLogic()
	if not IsValid(logic) or not IsValid(ply) then return end
	if TF_PasstimeEntityInNoBallZone and (TF_PasstimeEntityInNoBallZone(ply) or TF_PasstimeEntityInNoBallZone(weapon)) then
		notifyPasstimeCarryDenied(ply, "#TF_Passtime_No_Oob")
		if IsValid(weapon) then
			weapon:Remove()
		end
		logic:ScheduleRespawnBall()
		return
	end
	local canCarry, denyReason = logic:CanPlayerCarryBall(ply, true)
	if not canCarry then
		notifyPasstimeCarryDenied(ply, denyReason)
		if IsValid(weapon) then
			weapon:Remove()
		end
		logic:ScheduleRespawnBall()
		return
	end

	if IsValid(activeCarrier) and activeCarrier ~= ply then
		setCarrierState(activeCarrier, false)
	end

	activeCarrier = ply
	logic.BallCarrier = ply
	logic.BallEntity = weapon
	logic.BallState = "carried"
	setCarrierState(ply, true)
	if IsValid(weapon) then
		weapon.StoredLastWeaponClass = getStoredWeaponClassForPasstime(ply)
		if weapon.ApplyPasstimeSkin then
			weapon:ApplyPasstimeSkin(weapon:GetSkin())
		end
	end
	if SERVER then
		ply:SelectWeapon("tf_weapon_passtime_gun")
		timer.Simple(0, function()
			if not IsValid(ply) then return end
			local ballWeapon = ply:GetWeapon("tf_weapon_passtime_gun")
			if not IsValid(ballWeapon) then return end
			if not ballWeapon.StoredLastWeaponClass then
				ballWeapon.StoredLastWeaponClass = getStoredWeaponClassForPasstime(ply)
			end
			if ply:GetActiveWeapon() ~= ballWeapon then
				ply:SelectWeapon("tf_weapon_passtime_gun")
			end
			if ballWeapon.Deploy then
				ballWeapon:Deploy()
			end
		end)
	end
	triggerBallGetOutputs(logic, ply)
	updateGlobals(logic)
end

function TF_PasstimeProjectileTouchedPlayer(projectile, ply)
	local logic = getActiveLogic()
	if not IsValid(logic) or not IsValid(projectile) or not IsValid(ply) then return false end
	if projectile:GetClass() ~= "tf_projectile_passtime_ball" then return false end
	if not ply:IsPlayer() then return false end
	local canCarry, denyReason = logic:CanPlayerCarryBall(ply, true)
	if not canCarry then
		notifyPasstimeCarryDenied(ply, denyReason)
		return false
	end
	if TF_PasstimeEntityInNoBallZone and (TF_PasstimeEntityInNoBallZone(projectile) or TF_PasstimeEntityInNoBallZone(ply)) then
		notifyPasstimeCarryDenied(ply, "#TF_Passtime_No_Oob")
		return false
	end
	if ply:HasWeapon("tf_weapon_passtime_gun") then return false end

	projectile:Remove()
	local previousWeaponClass = getStoredWeaponClassForPasstime(ply)
	local projectileSkin = getPasstimeBallSkin(projectile, 0)
	local previousCarrier = IsValid(projectile.Thrower) and projectile.Thrower or projectile:GetNWEntity("TFPasstimePrevCarrier")
	if IsValid(previousCarrier) and previousCarrier:IsPlayer() and previousCarrier ~= ply then
		if previousCarrier:Team() == ply:Team() then
			firePasstimeGameEvent("pass_pass_caught", {
				passer = previousCarrier:EntIndex(),
				catcher = ply:EntIndex(),
				dist = previousCarrier:GetPos():Distance(ply:GetPos()),
				duration = math.max(CurTime() - (projectile.SpawnTime or CurTime()), 0),
			})
		else
			firePasstimeGameEvent("pass_ball_stolen", {
				victim = previousCarrier:EntIndex(),
				attacker = ply:EntIndex(),
			})
		end
	end
	ply:Give("tf_weapon_passtime_gun")
	timer.Simple(0, function()
		if not IsValid(ply) then return end
		local wep = ply:GetWeapon("tf_weapon_passtime_gun")
		if not IsValid(wep) then return end
		if logic.BallCarrier ~= ply and activeCarrier ~= ply then
			TF_PasstimeBallPickedUp(ply, wep)
		end
		wep.StoredLastWeaponClass = previousWeaponClass
		if wep.ApplyPasstimeSkin then
			wep:ApplyPasstimeSkin(projectileSkin)
		else
			wep.WeaponSkin = projectileSkin
			wep:SetSkin(projectileSkin)
		end
		if ply:GetActiveWeapon() ~= wep then
			ply:SelectWeapon("tf_weapon_passtime_gun")
		end
		if wep.Deploy then
			wep:Deploy()
		end
	end)
	return true
end

function TF_PasstimeBallThrown(ply, projectile)
	local logic = getActiveLogic()
	if not IsValid(logic) then return end

	clearCarrier(logic, ply)
	logic.BallEntity = projectile
	logic.BallState = "projectile"
	logic:TriggerOutput("OnBallFree", IsValid(projectile) and projectile or ply)
	firePasstimeGameEvent("pass_free", {
		owner = IsValid(ply) and ply:EntIndex() or -1,
		attacker = -1,
	})
	updateGlobals(logic)
end

function TF_PasstimeBallDropped(ply, ballEntity)
	local logic = getActiveLogic()
	if not IsValid(logic) then return end

	clearCarrier(logic, ply)
	logic.BallEntity = ballEntity
	logic.BallState = IsValid(ballEntity) and "free" or "removed"
	if IsValid(ballEntity) then
		logic:TriggerOutput("OnBallFree", ballEntity)
	end
	firePasstimeGameEvent("pass_free", {
		owner = IsValid(ply) and ply:EntIndex() or -1,
		attacker = -1,
	})
	if not IsValid(ballEntity) then
		logic:ScheduleRespawnBall()
	end
	updateGlobals(logic)
end

function TF_PasstimeBallBlocked(projectile, blocker)
	local owner = IsValid(projectile) and (IsValid(projectile.Thrower) and projectile.Thrower or projectile:GetNWEntity("TFPasstimePrevCarrier")) or nil
	if not (IsValid(owner) and owner:IsPlayer() and IsValid(blocker) and blocker:IsPlayer()) then
		return
	end

	firePasstimeGameEvent("pass_ball_blocked", {
		owner = owner:EntIndex(),
		blocker = blocker:EntIndex(),
	})
end

function TF_IsPasstimeMap()
	return GetGlobalBool("tf_passtime_map", false)
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.RedScore = 0
	self.BlueScore = 0
	self.Disabled = false
	self.NumSections = 0
	self.CurrentSection = 0
	self.BallSpawnCountdownSec = 15
	self.MaxPassRange = 0
	self.BallPower = 0
	self.BallPowerThreshold = 80
	self.BallState = "removed"
	self.TrackPoints = {}
	self:ReloadProperties()

	if GAMEMODE then
		GAMEMODE.IsPassTimeMap = true
	end

	timer.Simple(0, function()
		if IsValid(self) then
			updateGlobals(self)
			self:SpawnBallAtRandomSpawner()
		end
	end)
end

function ENT:CanPlayerCarryBall(ply, wantReason)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then
		return false, nil
	end
	if not gameplayActive() then
		return false, nil
	end
	if ply.IsTaunting and ply:IsTaunting() then
		return false, wantReason and "#TF_Passtime_No_Taunt" or nil
	end
	if playerHasCond(ply, TF_COND_HALLOWEEN_GHOST_MODE) or playerHasCond(ply, TF_COND_PHASE) then
		return false, wantReason and "#TF_Passtime_No_Oob" or nil
	end
	if playerHasCond(ply, TF_COND_INVULNERABLE) or playerHasCond(ply, TF_COND_INVULNERABLE_WEARINGOFF) then
		return false, wantReason and "#TF_Passtime_No_Invuln" or nil
	end
	if playerHasCond(ply, TF_COND_DISGUISED) or playerHasCond(ply, TF_COND_DISGUISING) then
		return false, wantReason and "#TF_Passtime_No_Disguise" or nil
	end
	if playerHasCond(ply, TF_COND_STEALTHED) or playerHasCond(ply, TF_COND_STEALTHED_USER_BUFF) then
		return false, wantReason and "#TF_Passtime_No_Cloak" or nil
	end
	if ply.IsStealthed and ply:IsStealthed() then
		return false, wantReason and "#TF_Passtime_No_Cloak" or nil
	end
	if TF_PasstimeEntityInNoBallZone and TF_PasstimeEntityInNoBallZone(ply) then
		return false, wantReason and "#TF_Passtime_No_Oob" or nil
	end

	local wep = ply:GetActiveWeapon()
	if IsValid(wep)
		and wep.GetClass
		and wep:GetClass() ~= "tf_weapon_passtime_gun"
		and wep.CanHolster
		and not wep:CanHolster()
		and not ply:IsBot()
	then
		return false, wantReason and "#TF_Passtime_No_Holster" or nil
	end

	return true, nil
end

function ENT:ReloadProperties()
	local props = self.Properties or {}
	self.NumSections = math.max(0, tonumber(props.num_sections) or 0)
	self.CurrentSection = math.Clamp(tonumber(props.section) or self.CurrentSection or 0, 0, self.NumSections)
	self.BallSpawnCountdownSec = math.max(1, tonumber(props.ball_spawn_countdown) or 15)
	self.MaxPassRange = tonumber(props.max_pass_range) or 0
	self.BallPowerThreshold = math.Clamp(tonumber(props.powerball_threshold) or self.BallPowerThreshold or 80, 0, 100)
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

function ENT:GetTeamScore(team)
	return getTeamScore(self, team)
end

function ENT:SetTeamScore(team, score)
	team = clampTeam(team)
	score = math.max(0, math.floor(tonumber(score) or 0))

	if team == TEAM_RED then
		self.RedScore = score
	else
		self.BlueScore = score
	end

	updateGlobals(self)
end

function ENT:AddScore(teamNum, points, activator, forceWin)
	teamNum = clampTeam(teamNum)
	points = math.max(1, math.floor(tonumber(points) or 1))

	if forceWin then
		points = math.max(points, PASSTIME_SCORE_LIMIT:GetInt() - self:GetTeamScore(teamNum))
	end

	self:SetTeamScore(teamNum, self:GetTeamScore(teamNum) + points)
	team.AddScore(teamNum, points)
	self:ClearBallPower(activator)

	self:TriggerOutput("OnScoreAny", activator or self)
	if teamNum == TEAM_RED then
		self:TriggerOutput("OnScoreRed", activator or self)
	else
		self:TriggerOutput("OnScoreBlu", activator or self)
	end
	firePasstimeGameEvent("pass_score", {
		scorer = IsValid(activator) and activator:IsPlayer() and activator:EntIndex() or -1,
		assister = -1,
		points = points,
	})

	if self:GetTeamScore(teamNum) >= PASSTIME_SCORE_LIMIT:GetInt() and GAMEMODE and not GAMEMODE.RoundHasWinner then
		GAMEMODE:RoundWin(teamNum)
		return
	end

	self:ScheduleRespawnBall()
end

function ENT:AddBallPower(amount, activator)
	local oldPower = tonumber(self.BallPower) or 0
	local newPower = math.Clamp(oldPower + (tonumber(amount) or 0), 0, 100)
	if oldPower == newPower then
		return false
	end

	self.BallPower = newPower
	local threshold = tonumber(self.BallPowerThreshold) or 80
	local wasPowered = oldPower > threshold
	local isPowered = newPower > threshold

	if wasPowered and not isPowered then
		self:TriggerOutput("OnBallPowerDown", activator or self)
	elseif not wasPowered and isPowered then
		self:TriggerOutput("OnBallPowerUp", activator or self)
	end

	updateGlobals(self)
	return true
end

function ENT:ClearBallPower(activator)
	return self:AddBallPower(-(tonumber(self.BallPower) or 0), activator)
end

function ENT:ScheduleRespawnBall()
	timer.Remove("tf_passtime_spawn_" .. self:EntIndex())
	self.BallRespawnAt = CurTime() + self.BallSpawnCountdownSec
	updateGlobals(self)
	timer.Create("tf_passtime_spawn_" .. self:EntIndex(), self.BallSpawnCountdownSec, 1, function()
		if not IsValid(self) or self.Disabled then return end
		self.BallRespawnAt = 0
		self:SpawnBallAtRandomSpawner()
	end)
end

function ENT:SpawnBallAtSpawner(spawner)
	timer.Remove("tf_passtime_spawn_" .. self:EntIndex())
	self.BallRespawnAt = 0
	clearExistingBallEntity(self)
	clearCarrier(self)

	local spawnPos = IsValid(spawner) and spawner:GetPos() or self:GetPos()
	local spawnAng = IsValid(spawner) and spawner:GetAngles() or angle_zero

	local ball = ents.Create("tf_weapon_passtime_gun")
	if not IsValid(ball) then return false end

	local spawnSkin = 0
	if IsValid(spawner) then
		local props = spawner.Properties or {}
		local teamNum = tonumber(spawner.TeamNum or props.teamnum or props.team) or 0
		if teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS or teamNum == 3 then
			spawnSkin = 1
		end
	end

	ball:SetPos(spawnPos)
	ball:SetAngles(spawnAng)
	ball:Spawn()
	ball.WeaponSkin = spawnSkin
	ball:SetSkin(spawnSkin)
	if ball.ApplyPasstimeSkin then
		ball:ApplyPasstimeSkin(spawnSkin)
	end
	if ball.SetTrigger then
		ball:SetTrigger(true)
	end

	self.BallEntity = ball
	self.BallState = "free"
	self:TriggerOutput("OnBallFree", ball)
	if IsValid(spawner) then
		spawner:TriggerOutput("OnSpawnBall", ball)
	end
	updateGlobals(self)
	return true
end

function ENT:SpawnBallAtRandomSpawner()
	local spawner = selectSpawner()
	if not IsValid(spawner) then
		return false
	end
	return self:SpawnBallAtSpawner(spawner)
end

function ENT:RemoveBall()
	timer.Remove("tf_passtime_spawn_" .. self:EntIndex())
	self.BallRespawnAt = 0
	clearExistingBallEntity(self)
	clearCarrier(self)
	self.BallState = "removed"
	self:TriggerOutput("OnBallRemoved", self)
	updateGlobals(self)
end

hook.Add("PlayerDisconnected", "TF_PasstimeClearPassTarget_Disconnect", function(ply)
	if not IsValid(ply) then
		return
	end

	local owner = nil
	for _, candidate in ipairs(player.GetAll()) do
		if IsValid(candidate) and candidate:GetNWEntity("TFPasstimePassTarget") == ply then
			owner = candidate
			break
		end
	end

	ply:SetNWBool("TFPasstimeIsTargeted", false)

	if IsValid(owner) then
		TF_PasstimeSetPassTarget(owner, nil)
	end
end)

function ENT:OnEnterGoal(target, goal)
	if not IsValid(goal) or goal.Disabled then return false end
	if not gameplayActive() then return false end

	if IsValid(target) and target:IsPlayer() then
		if not goal:EnablePlayerScore() then return false end
		if target:Team() ~= goal.TeamNum then return false end
		if not TF_PlayerHasPasstimeBall(target) then return false end

		if goal:GetPoints() == -1 then
			local carriedWeapon = target:GetWeapon("tf_weapon_passtime_gun")
			if IsValid(carriedWeapon) then
				carriedWeapon:Remove()
			end
			clearCarrier(self, target)
			self.BallState = "removed"
			self:TriggerOutput("OnBallRemoved", goal)
			self:ScheduleRespawnBall()
			updateGlobals(self)
			return true
		end

		local carriedWeapon = target:GetWeapon("tf_weapon_passtime_gun")
		if IsValid(carriedWeapon) then
			carriedWeapon:Remove()
		end
		clearCarrier(self, target)
		self:AddScore(target:Team(), goal:GetPoints(), target, goal:WinOnScore())
		goal:TriggerScoreOutput(target:Team(), target)
		return true
	end

	if not IsValid(target) or target:GetClass() ~= "tf_projectile_passtime_ball" then
		return false
	end
	if goal:DisableBallScore() then return false end

	local thrower = target:GetOwner()
	if not IsValid(thrower) or not thrower:IsPlayer() then
		return false
	end
	if thrower:Team() ~= goal.TeamNum then return false end

	if goal:GetPoints() == -1 then
		if target == self.BallEntity then
			self.BallEntity = nil
		end
		target:Remove()
		self.BallState = "removed"
		self:TriggerOutput("OnBallRemoved", goal)
		self:ScheduleRespawnBall()
		updateGlobals(self)
		return true
	end

	target:Remove()
	self:AddScore(thrower:Team(), goal:GetPoints(), thrower, goal:WinOnScore())
	goal:TriggerScoreOutput(thrower:Team(), thrower)
	return true
end

function ENT:OnCarrierEnteredNoBallZone(ply)
	if not IsValid(ply) then return end
	local carriedWeapon = ply:GetWeapon("tf_weapon_passtime_gun")
	if IsValid(carriedWeapon) then
		carriedWeapon:Remove()
	end
	clearCarrier(self, ply)
	self.BallState = "removed"
	self:TriggerOutput("OnBallRemoved", ply)
	self:ScheduleRespawnBall()
	updateGlobals(self)
end

function ENT:OnProjectileEnteredNoBallZone(projectile)
	if not IsValid(projectile) then return end
	if projectile == self.BallEntity then
		self.BallEntity = nil
	end
	projectile:Remove()
	self.BallState = "removed"
	self:TriggerOutput("OnBallRemoved", projectile)
	self:ScheduleRespawnBall()
	updateGlobals(self)
end

function ENT:OnStayInGoal(target, goal)
	return self:OnEnterGoal(target, goal)
end

function ENT:ParseSetSection(data)
	if not isstring(data) or data == "" then return nil end

	local sectionNum, startName, endName = string.match(data, "^(%-?%d+)%s+(%S+)%s+(%S+)$")
	sectionNum = tonumber(sectionNum)
	if sectionNum == nil then
		return nil
	end

	return {
		num = sectionNum,
		start = findPathTrackByName(startName),
		finish = findPathTrackByName(endName),
	}
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))

	if name == "spawnball" then
		timer.Remove("tf_passtime_spawn_" .. self:EntIndex())
		self:RemoveBall()
		self:ScheduleRespawnBall()
		return true
	elseif name == "setsection" then
		local parsed = self:ParseSetSection(tostring(data or ""))
		if parsed and parsed.num and parsed.num >= 0 and parsed.num < math.max(self.NumSections, 1) then
			self.CurrentSection = parsed.num
			self.TrackPoints = {
				start = parsed.start,
				finish = parsed.finish,
			}
		else
			self.CurrentSection = math.Clamp(tonumber(data) or self.CurrentSection or 0, 0, self.NumSections)
		end
		updateGlobals(self)
		return true
	elseif name == "timeup" then
		if GAMEMODE and not GAMEMODE.RoundHasWinner then
			if self.RedScore > self.BlueScore then
				GAMEMODE:RoundWin(TEAM_RED)
			elseif self.BlueScore > self.RedScore then
				GAMEMODE:RoundWin(TEAM_BLU)
			elseif GAMEMODE.RoundStalemate then
				GAMEMODE:RoundStalemate()
			end
		end
		return true
	elseif name == "speedboostused" or name == "jumppadused" then
		self:AddBallPower(25, activator)
		return true
	elseif name == "enable" then
		self.Disabled = false
		updateGlobals(self)
		return true
	elseif name == "disable" then
		self.Disabled = true
		updateGlobals(self)
		return true
	end

	return false
end

function ENT:OnRemove()
	timer.Remove("tf_passtime_spawn_" .. self:EntIndex())
	if getActiveLogic() == nil then
		SetGlobalBool("tf_passtime_map", false)
	end
end

function ENT:Think()
	if IsValid(self.BallCarrier) and TF_PasstimeEntityInNoBallZone and TF_PasstimeEntityInNoBallZone(self.BallCarrier) then
		self:OnCarrierEnteredNoBallZone(self.BallCarrier)
	elseif IsValid(self.BallEntity) and self.BallEntity:GetClass() == "tf_projectile_passtime_ball" and TF_PasstimeEntityInNoBallZone and TF_PasstimeEntityInNoBallZone(self.BallEntity) then
		self:OnProjectileEnteredNoBallZone(self.BallEntity)
	end

	updateGlobals(self)

	self:NextThink(CurTime() + 0.1)
	return true
end

hook.Add("WeaponEquip", "TF_PasstimeLogic_WeaponEquip", function(weapon, owner)
	if not IsValid(weapon) or not IsValid(owner) then return end
	if weapon:GetClass() ~= "tf_weapon_passtime_gun" then return end
	TF_PasstimeBallPickedUp(owner, weapon)
end)

hook.Add("DoPlayerDeath", "TF_PasstimeLogic_PlayerDeath", function(ply)
	local logic = getActiveLogic()
	if not IsValid(logic) then return end
	if ply ~= logic.BallCarrier and ply ~= activeCarrier then return end
	clearCarrier(logic, ply)
	logic.BallState = "removed"
	logic:TriggerOutput("OnBallRemoved", ply)
	logic:ScheduleRespawnBall()
	updateGlobals(logic)
end)

hook.Add("EntityRemoved", "TF_PasstimeLogic_EntityRemoved", function(ent)
	local logic = getActiveLogic()
	if not IsValid(logic) then return end

	if ent == logic.BallEntity then
		if ent.TFPasstimeSuppressRemovedRespawn then
			ent.TFPasstimeSuppressRemovedRespawn = nil
			return
		end
		logic.BallEntity = nil
		logic:TriggerOutput("OnBallRemoved", ent)
		logic:ScheduleRespawnBall()
		logic.BallState = "removed"
		updateGlobals(logic)
	elseif ent == logic.BallCarrier then
		clearCarrier(logic, ent)
		logic.BallState = "removed"
		logic:TriggerOutput("OnBallRemoved", ent)
		logic:ScheduleRespawnBall()
		updateGlobals(logic)
	end
end)

net.Receive("TFPasstimeAskForBall", function(_, ply)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
	local logic = getActiveLogic()
	if not IsValid(logic) then return end
	if ply:GetNWFloat("TFPasstimeAskForBallUntil", 0) > CurTime() then return end

	local ball = logic.BallEntity
	if not IsValid(ball) then return end

	local carrier = logic.BallCarrier or activeCarrier
	if not IsValid(carrier) or carrier == ply then return end
	if carrier:Team() ~= ply:Team() then return end

	local canCarry, denyToken = logic:CanPlayerCarryBall(ply, true)
	if not canCarry then
		notifyPasstimeCarryDenied(ply, denyToken)
		return
	end

	if logic.MaxPassRange and logic.MaxPassRange > 0 and carrier:GetPos():DistToSqr(ply:GetPos()) > (logic.MaxPassRange * logic.MaxPassRange) then
		return
	end

	if ply.Speak then
		ply:Speak("TLK_PLAYER_ASK_FOR_BALL")
	end
	playAskForBallCue(ply, carrier)
	ply:SetNWFloat("TFPasstimeAskForBallUntil", CurTime() + 5.0)
end)

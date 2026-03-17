ENT.Base = "base_brush"
ENT.Type = "brush"

local DEFAULT_STEAL_INTERVAL = 1
local DEFAULT_STEAL_AMOUNT = 1

local function ClampToGameTeam(teamNum)
	if teamNum == TEAM_RED or teamNum == 2 then return TEAM_RED end
	if teamNum == TEAM_BLU or teamNum == 3 then return TEAM_BLU end
	return nil
end

local function GetRobotDestructionLogic()
	for _, logic in ipairs(ents.FindByClass("tf_logic_robot_destruction")) do
		if IsValid(logic) then
			return logic
		end
	end
	return nil
end

local function IsCarrierInsideVault(vault, carrier)
	if not (IsValid(vault) and IsValid(carrier)) then return false end
	if vault.TouchingPlayers and vault.TouchingPlayers[carrier] then return true end

	local mins, maxs = vault:WorldSpaceAABB()
	local pos = carrier.WorldSpaceCenter and carrier:WorldSpaceCenter() or carrier:GetPos()
	return pos.x >= mins.x and pos.x <= maxs.x
		and pos.y >= mins.y and pos.y <= maxs.y
		and pos.z >= mins.z and pos.z <= maxs.z
end

local function GetFlagOwnerTeam(flag)
	return ClampToGameTeam(tonumber(flag.TeamNum or flag.te or -1))
end

local function FindStealingCarrier(vault)
	local flagClasses = {
		"item_teamflag",
		"item_teamflag_mvm",
	}

	for _, className in ipairs(flagClasses) do
		for _, flag in ipairs(ents.FindByClass(className)) do
			if not IsValid(flag) or not IsValid(flag.Carrier) then
				continue
			end

			local ownerTeam = GetFlagOwnerTeam(flag)
			local carrier = flag.Carrier
			if not ownerTeam or carrier:Team() == ownerTeam then
				continue
			end

			if IsCarrierInsideVault(vault, carrier) then
				return carrier, flag, ownerTeam
			end
		end
	end

	return nil, nil, nil
end

function ENT:Initialize()
	self.Properties = self.Properties or {}
	self.TouchingPlayers = {}
	self.Stealing = false
	self.ActiveCarrier = NULL
	self.ActiveFlag = NULL
	self.NextStealAt = 0
	self:NextThink(CurTime())
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

function ENT:StartTouch(ent)
	if not (IsValid(ent) and ent:IsPlayer()) then return end
	self.TouchingPlayers[ent] = true
end

function ENT:EndTouch(ent)
	if not (IsValid(ent) and ent:IsPlayer()) then return end
	self.TouchingPlayers[ent] = nil

	if self.ActiveCarrier == ent and self.Stealing then
		self.Stealing = false
		self.ActiveCarrier = NULL
		self.ActiveFlag = NULL
		self:TriggerOutput("OnPointsEndStealing", ent)
	end
end

function ENT:Think()
	local carrier, flag, victimTeam = FindStealingCarrier(self)
	local now = CurTime()

	if IsValid(carrier) then
		if not self.Stealing or self.ActiveCarrier ~= carrier then
			self.Stealing = true
			self.ActiveCarrier = carrier
			self.ActiveFlag = flag
			self.NextStealAt = now
			self:TriggerOutput("OnPointsStartStealing", carrier)
		end

		if now >= (self.NextStealAt or 0) then
			local amount = DEFAULT_STEAL_AMOUNT
			local logic = GetRobotDestructionLogic()
			if IsValid(logic) then
				local interval = tonumber(logic.ScoreInterval) or DEFAULT_STEAL_INTERVAL
				self.NextStealAt = now + math.max(interval, 0.05)
				if logic.AddScore and victimTeam then
					logic:AddScore(victimTeam, -amount, carrier)
				end
			else
				self.NextStealAt = now + DEFAULT_STEAL_INTERVAL
			end

			flag.StoredVaultPoints = (tonumber(flag.StoredVaultPoints) or 0) + amount
			self:TriggerOutput("OnPointsStolen", carrier, self, tostring(amount))
		end
	elseif self.Stealing then
		self.Stealing = false
		local activator = IsValid(self.ActiveCarrier) and self.ActiveCarrier or self
		self.ActiveCarrier = NULL
		self.ActiveFlag = NULL
		self:TriggerOutput("OnPointsEndStealing", activator)
	end

	self:NextThink(CurTime())
	return true
end

function ENT:AcceptInput(name, activator, caller, data)
end

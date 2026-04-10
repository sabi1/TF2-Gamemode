ENT.Base = "base_brush"
ENT.Type = "brush"

local WARN_TIMER = "TF_MVM_BombWarningLoop"
local ANNOUNCE_COOLDOWN = 1.25
TF_MVM_BombWarnNextAnnounceAt = TF_MVM_BombWarnNextAnnounceAt or 0

local function IsMvMMap()
	return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

local function IsFlagCarrier(ent)
	if not IsValid(ent) or not ent.IsPlayer or not ent:IsPlayer() then
		return false
	end

	for _, flag in ipairs(ents.FindByClass("item_teamflag")) do
		if IsValid(flag) and flag.Carrier == ent then
			return true
		end
	end

	for _, flag in ipairs(ents.FindByClass("item_teamflag_mvm")) do
		if IsValid(flag) and flag.Carrier == ent then
			return true
		end
	end

	return false
end

local function GetActiveBombCarrier()
	for _, flag in ipairs(ents.FindByClass("item_teamflag_mvm")) do
		if IsValid(flag) and IsValid(flag.Carrier) then
			return flag.Carrier, flag
		end
	end
	return nil, nil
end

local function IsCarrierInsideAnyDetectionZone(carrier)
	if not IsValid(carrier) then return false end
	for _, zone in ipairs(ents.FindByClass("func_flagdetectionzone")) do
		if IsValid(zone) and istable(zone.Players) and zone.Players[carrier] ~= nil then
			return true
		end
	end
	return false
end

local function StartBombWarningLoop()
	if timer.Exists(WARN_TIMER) then return end
	timer.Create(WARN_TIMER, 3, 0, function()
		local carrier = GetActiveBombCarrier()
		if not IsValid(carrier) then
			timer.Remove(WARN_TIMER)
			return
		end
		if not IsCarrierInsideAnyDetectionZone(carrier) then
			timer.Remove(WARN_TIMER)
			return
		end
		for _, ply in ipairs(player.GetAll()) do
			if IsValid(ply) then
				ply:SendLua([[surface.PlaySound("mvm/mvm_bomb_warning.wav")]])
			end
		end
	end)
end

local function PlayBombAlertAndWarning(carrier)
	if not IsValid(carrier) then return end
	if not IsCarrierInsideAnyDetectionZone(carrier) then return end
	local now = CurTime()
	if now >= (tonumber(TF_MVM_BombWarnNextAnnounceAt) or 0) then
		TF_MVM_BombWarnNextAnnounceAt = now + ANNOUNCE_COOLDOWN
		for _, ply in ipairs(player.GetAll()) do
			if IsValid(ply) then
				ply:SendLua([[surface.PlaySound("vo/mvm_bomb_alerts0"..math.random(4,5)..".mp3")]])
				ply:SendLua([[surface.PlaySound("mvm/mvm_bomb_warning.wav")]])
				if (ply.TFBot and !ply:IsFriendly(carrier)) then
					ply.TargetEnt = carrier
				end
			end
		end
	end
	StartBombWarningLoop()
end

function ENT:Initialize()
	self.Team = 0
	self.Players = {}
	self.Opened = false
	self.Disabled = false
	self.TouchingFlagCarriers = {}

	local mins, maxs = self:WorldSpaceAABB()
	self.Pos = (mins + maxs) * 0.5
	
end

function ENT:KeyValue(key,value)
	if string.Left(key, 2) == "On" then
		self:StoreOutput(key, value)
		return
	end

	key = string.lower(key)
	
	if key=="teamnum" then
		self.Team = tonumber(value)
	elseif key=="associatedmodel" then
		self.ResupplyLockerName = value
	elseif key=="startdisabled" then
		self.Disabled = tonumber(value) == 1
	end
end

function ENT:FlagDropped(playerEnt)
	if not IsValid(playerEnt) then return end
	if not self.TouchingFlagCarriers[playerEnt] then return end

	self:TriggerOutput("OnDroppedFlag", playerEnt, self)
	self.TouchingFlagCarriers[playerEnt] = nil
	self:TriggerOutput("OnEndTouchFlag", self, self)
end

function ENT:FlagPickedUp(playerEnt)
	if not IsValid(playerEnt) then return end
	if self.Players[playerEnt] == nil then return end
	if self.TouchingFlagCarriers[playerEnt] then return end

	self.TouchingFlagCarriers[playerEnt] = true
	self:TriggerOutput("OnPickedUpFlag", playerEnt, self)
	self:TriggerOutput("OnStartTouchFlag", playerEnt, self)
end

function ENT:FlagCaptured(playerEnt)
	if not IsValid(playerEnt) then return end
	if not self.TouchingFlagCarriers[playerEnt] then return end

	self.TouchingFlagCarriers[playerEnt] = nil
	self:TriggerOutput("OnEndTouchFlag", self, self)
end

function ENT:StartTouch(ent)
	if self.Disabled then return end

	if ent:IsPlayer() then
		self.Players[ent] = -1
		if IsFlagCarrier(ent) and not self.TouchingFlagCarriers[ent] then
			self.TouchingFlagCarriers[ent] = true
			self:TriggerOutput("OnStartTouchFlag", ent, self)
		end

		for k,v in pairs(ents.FindByClass("item_teamflag")) do
			if v.Carrier == ent then
				if TF_IsSpecialDeliveryMap and TF_IsSpecialDeliveryMap() then
					for _,relay in pairs(ents.FindByName("touch_relay")) do
						relay:Fire( "Trigger" )
					end
				end
			end
		end
		for k,v in pairs(ents.FindByClass("item_teamflag_mvm")) do
			if v.Carrier == ent then
				if IsMvMMap() then
					self.Opened = true
					PlayBombAlertAndWarning(ent)
				end
			end
		end
	end
end 

function ENT:EndTouch(ent)
	if self.Disabled then return end

	if ent:IsPlayer() then
		self.Players[ent] = nil
		if self.TouchingFlagCarriers[ent] then
			self.TouchingFlagCarriers[ent] = nil
			self:TriggerOutput("OnEndTouchFlag", self, self)
		end
		for k,v in pairs(ents.FindByClass("item_teamflag")) do
			if v.Carrier == ent then
				if TF_IsSpecialDeliveryMap and TF_IsSpecialDeliveryMap() then
					for _,relay in pairs(ents.FindByName("drop_relay")) do
						relay:Fire( "Trigger" )
					end
				end
			end
		end
	end
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))

	if name == "enable" then
		self.Disabled = false
		return true
	elseif name == "disable" then
		self.Disabled = true
		return true
	elseif name == "test" then
		local foundCarrier = false
		for ent in pairs(self.Players) do
			if IsValid(ent) and IsFlagCarrier(ent) then
				foundCarrier = true
				self:TriggerOutput("OnStartTouchFlag", ent, self)
				break
			end
		end

		if not foundCarrier then
			self:TriggerOutput("OnEndTouchFlag", self, self)
		end
		return true
	end

	return false
end

hook.Add("TF_MVM_MissionStarted", "TF_MVM_ResetGateDetectionZones", function()
	for _, zone in ipairs(ents.FindByClass("func_flagdetectionzone")) do
		if IsValid(zone) then
			zone.Opened = false
		end
	end
	timer.Remove(WARN_TIMER)
	TF_MVM_BombWarnNextAnnounceAt = 0
end)

hook.Add("TF_MVM_BombPickedUp", "TF_MVM_BombWarn_OnPickup", function(carrier, bombEnt)
	if not IsMvMMap() then return end
	if not IsValid(carrier) then
		carrier = GetActiveBombCarrier()
	end
	if not IsValid(carrier) then return end
	if not IsCarrierInsideAnyDetectionZone(carrier) then return end
	PlayBombAlertAndWarning(carrier)
end)

hook.Add("TF_MVM_MissionFailed", "TF_MVM_StopBombWarningLoop_Failed", function()
	timer.Remove(WARN_TIMER)
	TF_MVM_BombWarnNextAnnounceAt = 0
end)

hook.Add("TF_MVM_MissionCompleted", "TF_MVM_StopBombWarningLoop_Completed", function()
	timer.Remove(WARN_TIMER)
	TF_MVM_BombWarnNextAnnounceAt = 0
end)

hook.Add("PostCleanupMap", "TF_MVM_StopBombWarningLoop_Cleanup", function()
	timer.Remove(WARN_TIMER)
	TF_MVM_BombWarnNextAnnounceAt = 0
end)

hook.Add("TF_MapFlagDropped", "TF_FlagDetectionZone_FlagDropped", function(flag, playerEnt)
	if not IsValid(playerEnt) then return end
	for _, zone in ipairs(ents.FindByClass("func_flagdetectionzone")) do
		if IsValid(zone) then
			zone:FlagDropped(playerEnt)
		end
	end
end)

hook.Add("TF_MapFlagPickedUp", "TF_FlagDetectionZone_FlagPickedUp", function(flag, playerEnt)
	if not IsValid(playerEnt) then return end
	for _, zone in ipairs(ents.FindByClass("func_flagdetectionzone")) do
		if IsValid(zone) then
			zone:FlagPickedUp(playerEnt)
		end
	end
end)

hook.Add("TF_MapFlagCaptured", "TF_FlagDetectionZone_FlagCaptured", function(flag, playerEnt)
	if not IsValid(playerEnt) then return end
	for _, zone in ipairs(ents.FindByClass("func_flagdetectionzone")) do
		if IsValid(zone) then
			zone:FlagCaptured(playerEnt)
		end
	end
end)

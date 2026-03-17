ENT.Base = "base_brush"
ENT.Type = "brush"

local WARN_TIMER = "TF_MVM_BombWarningLoop"
local ANNOUNCE_COOLDOWN = 1.25
TF_MVM_BombWarnNextAnnounceAt = TF_MVM_BombWarnNextAnnounceAt or 0

local function IsMvMMap()
	return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
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

	local mins, maxs = self:WorldSpaceAABB()
	self.Pos = (mins + maxs) * 0.5
	
end

function ENT:KeyValue(key,value)
	key = string.lower(key)
	
	if key=="teamnum" then
		self.Team = tonumber(value)
	elseif key=="associatedmodel" then
		self.ResupplyLockerName = value
	end
end

function ENT:StartTouch(ent)
	if ent:IsPlayer() then
		self.Players[ent] = -1
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
	if ent:IsPlayer() then
		self.Players[ent] = nil
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

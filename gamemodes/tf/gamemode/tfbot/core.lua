TFBotSource = TFBotSource or {}
TFBotSource.Core = TFBotSource.Core or {}

local M = TFBotSource.Core

M.AttributeType = {
	REMOVE_ON_DEATH = 1,
	AGGRESSIVE = 2,
	IS_NPC = 4,
	SUPPRESS_FIRE = 8,
	DISABLE_DODGE = 16,
	QUOTA_MANAGED = 64,
	IGNORE_ENEMIES = 1024,
	PRIORITIZE_DEFENSE = 4096,
}

M.MissionType = {
	NONE = "none",
	SEEK_AND_DESTROY = "seek_and_destroy",
	DESTROY_SENTRIES = "destroy_sentries",
	SNIPER = "sniper",
}

local function defaultProfile()
	return {
		attributes = {},
		mission = M.MissionType.NONE,
		attentionFocus = nil,
		delayedThreats = {},
		actionName = "MainAction",
	}
end

function M:EnsureState(bot, st)
	if not IsValid(bot) then return nil end
	bot._tfbotSource = bot._tfbotSource or defaultProfile()
	local profile = bot._tfbotSource
	profile.state = st
	return profile
end

function M:SetMission(bot, mission)
	local profile = self:EnsureState(bot)
	if not profile then return end
	profile.mission = tostring(mission or self.MissionType.NONE)
end

function M:GetMission(bot)
	local profile = self:EnsureState(bot)
	return profile and profile.mission or self.MissionType.NONE
end

function M:AddAttribute(bot, attr)
	local profile = self:EnsureState(bot)
	if not profile then return end
	profile.attributes[attr] = true
end

function M:HasAttribute(bot, attr)
	local profile = self:EnsureState(bot)
	return profile and profile.attributes[attr] == true or false
end

function M:SetAttentionFocus(bot, ent)
	local profile = self:EnsureState(bot)
	if not profile then return end
	profile.attentionFocus = IsValid(ent) and ent or nil
end

function M:IsAttentionFocusedOn(bot, ent)
	local profile = self:EnsureState(bot)
	return profile and profile.attentionFocus == ent or false
end

function M:SetActionTarget(bot, st, mode, ent, pos)
	if not (IsValid(bot) and st and st.objective) then return end
	st.objective.mode = tostring(mode or "none")
	st.objective.targetEnt = IsValid(ent) and ent or nil
	st.objective.targetPos = isvector(pos) and pos or (IsValid(ent) and ent:GetPos() or nil)
	if st.vision and IsValid(ent) then
		st.vision.currentThreat = ent
	end
end

function M:ClearActionTarget(st)
	if not st or not st.objective then return end
	st.objective.mode = "none"
	st.objective.targetEnt = nil
	st.objective.targetPos = nil
end

return M

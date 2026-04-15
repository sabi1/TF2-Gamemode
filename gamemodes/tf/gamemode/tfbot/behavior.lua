TFBotSource = TFBotSource or {}
TFBotSource.Behavior = TFBotSource.Behavior or {}

local M = TFBotSource.Behavior

function M:SetAction(bot, st, actionName)
	if not (IsValid(bot) and st) then return end
	local name = tostring(actionName or "MainAction")
	st.sourceBehavior = st.sourceBehavior or {}
	st.sourceBehavior.actionName = name
	if bot._tfbotSource then
		bot._tfbotSource.actionName = name
	end
end

function M:GetAction(bot, st)
	if st and st.sourceBehavior and st.sourceBehavior.actionName then
		return st.sourceBehavior.actionName
	end
	if bot and bot._tfbotSource then
		return bot._tfbotSource.actionName
	end
	return "MainAction"
end

return M


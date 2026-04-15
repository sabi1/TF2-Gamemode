TFBotSource = TFBotSource or {}
TFBotSource.MainAction = TFBotSource.MainAction or {}

local M = TFBotSource.MainAction

function M:Update(bot, st, profile)
	if not (IsValid(bot) and st and profile) then return end
	local action = tostring(profile.actionName or "MainAction")
	local attack = TFBotSource.Actions and TFBotSource.Actions.Attack or nil
	local getHealth = TFBotSource.Actions and TFBotSource.Actions.GetHealth or nil
	local getAmmo = TFBotSource.Actions and TFBotSource.Actions.GetAmmo or nil
	local retreat = TFBotSource.Actions and TFBotSource.Actions.RetreatToCover or nil
	local melee = TFBotSource.Actions and TFBotSource.Actions.MeleeAttack or nil
	local teleporter = TFBotSource.Actions and TFBotSource.Actions.UseTeleporter or nil
	local destroySentry = TFBotSource.Actions and TFBotSource.Actions.DestroyEnemySentry or nil
	local seek = TFBotSource.Actions and TFBotSource.Actions.SeekAndDestroy or nil
	local medic = TFBotSource.Actions and TFBotSource.Actions.MedicHeal or nil
	local sniper = TFBotSource.Actions and TFBotSource.Actions.SniperLurk or nil
	local flag = TFBotSource.Actions and TFBotSource.Actions.FetchFlag or nil
	local flagDefenders = TFBotSource.Actions and TFBotSource.Actions.AttackFlagDefenders or nil
	local escort = TFBotSource.Actions and TFBotSource.Actions.EscortFlagCarrier or nil
	local spyAttack = TFBotSource.Actions and TFBotSource.Actions.SpyAttack or nil
	local spySap = TFBotSource.Actions and TFBotSource.Actions.SpySap or nil
	local spy = TFBotSource.Actions and TFBotSource.Actions.SpyInfiltrate or nil
	local engineer = TFBotSource.Actions and TFBotSource.Actions.EngineerIdle or nil

	if action == "GetHealth" and getHealth and getHealth.Update and getHealth:Update(bot, st, profile) then return end
	if action == "GetAmmo" and getAmmo and getAmmo.Update and getAmmo:Update(bot, st, profile) then return end
	if action == "RetreatToCover" and retreat and retreat.Update and retreat:Update(bot, st, profile) then return end
	if action == "MeleeAttack" and melee and melee.Update and melee:Update(bot, st, profile) then return end
	if action == "UseTeleporter" and teleporter and teleporter.Update and teleporter:Update(bot, st, profile) then return end
	if action == "DestroyEnemySentry" and destroySentry and destroySentry.Update and destroySentry:Update(bot, st, profile) then return end
	if action == "MedicHeal" and medic and medic.Update and medic:Update(bot, st, profile) then return end
	if action == "SniperLurk" and sniper and sniper.Update and sniper:Update(bot, st, profile) then return end
	if action == "FetchFlag" and flag and flag.Update and flag:Update(bot, st, profile) then return end
	if action == "AttackFlagDefenders" and flagDefenders and flagDefenders.Update and flagDefenders:Update(bot, st, profile) then return end
	if action == "EscortFlagCarrier" and escort and escort.Update and escort:Update(bot, st, profile) then return end
	if action == "EngineerIdle" and engineer and engineer.Update and engineer:Update(bot, st, profile) then return end
	if action == "SpyAttack" and spyAttack and spyAttack.Update and spyAttack:Update(bot, st, nil) then return end
	if action == "SpySap" and spySap and spySap.Update and spySap:Update(bot, st, nil) then return end
	if action == "SeekAndDestroy" and seek and seek.Update and seek:Update(bot, st, profile) then return end
	if (action == "SpyInfiltrate" or action == "SpyLeaveSpawnRoom") and spy and spy.Update and spy:Update(bot, st, profile) then
		return
	end
	if action == "MissionDestroySentries" then
		if destroySentry and destroySentry.Update and destroySentry:Update(bot, st, profile) then
			return
		end
		if attack and attack.Update and attack:Update(bot, st, profile) then
			return
		end
	end

	if seek and seek.Update then
		seek:Update(bot, st, profile)
	end
end

function M:ApplyPlayerCommand(bot, cmd, st, profile)
	if not (IsValid(bot) and cmd and st and profile) then return end
	local action = tostring(profile.actionName or "MainAction")
	local medic = TFBotSource.Actions and TFBotSource.Actions.MedicHeal or nil
	local sniper = TFBotSource.Actions and TFBotSource.Actions.SniperLurk or nil

	if action == "MedicHeal" and medic and medic.ApplyPlayerCommand then
		medic:ApplyPlayerCommand(bot, cmd, st, profile)
	elseif action == "SniperLurk" and sniper and sniper.ApplyPlayerCommand then
		sniper:ApplyPlayerCommand(bot, cmd, st, profile)
	end
end

return M

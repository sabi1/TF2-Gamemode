-- ubercharged / invulnerable condition similar to TF_COND_INVULNERABLE and related.
-- shared between TF_COND_UBERCHARGED, TF_COND_INVULNERABLE, etc.

local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond

local cond = {}
cond.Type = ETFCond.TF_COND_INVULNERABLE -- placeholder; loader may alias this file for related conds

local function ApplySkinToEntity(ent, skin)
	if not IsValid(ent) then return end
	if ent.SetSkin then
		ent:SetSkin(skin)
	end
end

function cond.OnAdded(ply, provider)
	local condList = ply.tf_cond_list and ply.tf_cond_list._conds
	local condData = condList and condList[ETFCond.TF_COND_INVULNERABLE] or nil
	local duration = (condData and condData.duration) or 0
	ply.TF_UberEnd = CurTime() + duration

	ply:EmitSound("Medic.UberchargeReady")

	if CLIENT and GAMEMODE and GAMEMODE.StartUberOverlay then
		GAMEMODE:StartUberOverlay(ply)
	end

	local team = ply:Team()
	local uberSkin = (team == TEAM_RED) and 2 or 3

	ApplySkinToEntity(ply, uberSkin)
	for _, wep in ipairs(ply:GetWeapons() or {}) do
		ApplySkinToEntity(wep, uberSkin)
	end
	if ply.GetChildren then
		for _, child in ipairs(ply:GetChildren() or {}) do
			ApplySkinToEntity(child, uberSkin)
		end
	end

	if CLIENT and ply == LocalPlayer() then
		timer.Simple(0, function()
			if not IsValid(ply) then return end
			local vm = ply:GetViewModel()
			if IsValid(vm) then
				ApplySkinToEntity(vm, uberSkin)
			end
		end)
	end
end

function cond.OnRemoved(ply)
	if CLIENT and GAMEMODE and GAMEMODE.StopUberOverlay then
		GAMEMODE:StopUberOverlay(ply)
	end

	local team = ply:Team()
	local normalSkin = (team == TEAM_RED) and 0 or 1

	ApplySkinToEntity(ply, normalSkin)
	for _, wep in ipairs(ply:GetWeapons() or {}) do
		ApplySkinToEntity(wep, normalSkin)
	end
	if ply.GetChildren then
		for _, child in ipairs(ply:GetChildren() or {}) do
			ApplySkinToEntity(child, normalSkin)
		end
	end

	if CLIENT and ply == LocalPlayer() then
		timer.Simple(0, function()
			if not IsValid(ply) then return end
			local vm = ply:GetViewModel()
			if IsValid(vm) then
				ApplySkinToEntity(vm, normalSkin)
			end
		end)
	end

	ply:EmitSound("Medic.UberchargeOff")
end

function cond.OnThink(ply)
	if not CLIENT then return end

	local isInv = ply:InCond(cond.Type)
	local hide = ply:InCond(ETFCond.TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED)

	local shouldSkin = isInv
	if hide and not isInv then
		shouldSkin = ply.TF_LastDamageTime and (CurTime() < ply.TF_LastDamageTime + 2)
	end

	local team = ply:Team()
	local skin = shouldSkin and ((team == TEAM_RED) and 2 or 3) or ((team == TEAM_RED) and 0 or 1)

	ApplySkinToEntity(ply, skin)
	for _, wep in ipairs(ply:GetWeapons() or {}) do
		ApplySkinToEntity(wep, skin)
	end
	if ply.GetChildren then
		for _, child in ipairs(ply:GetChildren() or {}) do
			ApplySkinToEntity(child, skin)
		end
	end

	if ply == LocalPlayer() then
		local vm = ply:GetViewModel()
		if IsValid(vm) then
			ApplySkinToEntity(vm, skin)
		end
	end
end

function cond.ModifyDamage(ply, dmg)
	if ply:InCond(ETFCond.TF_COND_INVULNERABLE) then
		dmg:SetDamage(0)
	end
end

return cond

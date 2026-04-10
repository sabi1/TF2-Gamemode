AddCSLuaFile()

ENT.Type = "point"

local function go_to_intermission(activator)
	if GAMEMODE and GAMEMODE.GoToIntermission then
		GAMEMODE:GoToIntermission()
		return true
	end

	if GAMEMODE then
		GAMEMODE.InIntermission = true
		GAMEMODE.IntermissionStartTime = CurTime()
	end

	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) then
			ply:Freeze(true)
			ply:ConCommand("stopsound")
		end
	end

	return true
end

function ENT:Initialize()
	self:SetNoDraw(true)
end

function ENT:AcceptInput(name, activator, caller, data)
	name = string.lower(tostring(name or ""))
	if name == "activate" then
		return go_to_intermission(IsValid(activator) and activator or caller)
	end
	return false
end

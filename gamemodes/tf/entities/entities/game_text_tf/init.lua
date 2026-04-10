AddCSLuaFile()

ENT.Type = "point"

if SERVER then
	util.AddNetworkString("TF_GameTextTF_Display")
end

local RECIPIENT_TEAMS = {
	[0] = nil,
	[2] = TEAM_RED,
	[3] = TEAM_BLU,
}

function ENT:Initialize()
	self.Properties = self.Properties or {}
end

function ENT:KeyValue(key, value)
	key = string.lower(tostring(key or ""))
	self.Properties = self.Properties or {}
	if tonumber(value) then
		value = tonumber(value)
	end
	self.Properties[key] = value
end

if SERVER then
	local function get_recipient_players(teamNum)
		local resolvedTeam = RECIPIENT_TEAMS[tonumber(teamNum) or 0]
		if not resolvedTeam then
			return player.GetAll()
		end
		return team.GetPlayers(resolvedTeam)
	end

	function ENT:Display(activator)
		local message = tostring(self.Properties.message or "")
		local icon = tostring(self.Properties.icon or "")
		local background = tonumber(self.Properties.background) or 0
		local recipients = get_recipient_players(self.Properties.display_to_team)
		if #recipients <= 0 then
			return
		end

		net.Start("TF_GameTextTF_Display")
			net.WriteString(message)
			net.WriteString(icon)
			net.WriteInt(background, 8)
		net.Send(recipients)
	end

	function ENT:AcceptInput(name, activator, caller)
		name = string.lower(tostring(name or ""))
		if name == "display" then
			self:Display(activator)
			return true
		end
		return false
	end
else
	net.Receive("TF_GameTextTF_Display", function()
		local message = net.ReadString()
		local icon = net.ReadString()
		local background = net.ReadInt(8)

		message = tostring(message or "")
		if message == "" then
			return
		end

		LocalPlayer():PrintMessage(HUD_PRINTCENTER, message)
		if icon ~= "" then
			LocalPlayer():PrintMessage(HUD_PRINTTALK, string.format("[HUD %s] %s", icon, message))
		elseif background ~= 0 then
			LocalPlayer():PrintMessage(HUD_PRINTTALK, message)
		end
	end)
end

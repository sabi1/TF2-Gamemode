if SERVER then
	AddCSLuaFile()
end

SWEP.Base = "tf_weapon_base"

SWEP.ViewModel = "models/weapons/v_models/v_pda_spy.mdl"
SWEP.WorldModel = "models/weapons/w_models/w_cigarette_case.mdl"

SWEP.HoldType = "PDA"
SWEP.UseHands = false
SWEP.IsPDA = true
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 1
SWEP.Secondary.Delay = 5
SWEP.Slot = 3

if CLIENT then
	SWEP.PrintName = "Disguise PDA"
	SWEP.Crosshair = ""
	SWEP.CustomHUD = { HudSpyMenuDisguise = true }

	local function getTeamIndexForMenu()
		if TFSpyDisguiseMenu and TFSpyDisguiseMenu.GetSelectedTeamIndex then
			return TFSpyDisguiseMenu.GetSelectedTeamIndex()
		end
		local ply = LocalPlayer()
		if not IsValid(ply) then return 0 end
		return ply:Team() == TEAM_RED and 1 or 0
	end

	local function toggleTeamForMenu()
		if TFSpyDisguiseMenu and TFSpyDisguiseMenu.ToggleSelectedTeam then
			TFSpyDisguiseMenu.ToggleSelectedTeam()
		end
	end

	local function resetTeamForMenu()
		if TFSpyDisguiseMenu and TFSpyDisguiseMenu.ResetSelectedTeam then
			TFSpyDisguiseMenu.ResetSelectedTeam()
		end
	end

	hook.Add("PlayerBindPress", "TFSpyPDADisguiseBind", function(pl, bind, pressed)
		if not pressed then return end
		if not IsValid(pl) or not pl:Alive() then return end

		local wep = pl:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "tf_weapon_pda_spy" then return end

		local lowerBind = string.lower(string.Trim(tostring(bind or "")))

		if lowerBind == "disguiseteam" or lowerBind == "+reload" or lowerBind == "reload" then
			toggleTeamForMenu()
			return true
		end

		local slotNum = tonumber(string.match(lowerBind, "^slot(%d+)$") or "")
		if not slotNum then return end

		if slotNum == 10 then
			RunConsoleCommand("lastinv")
			return true
		end

		if slotNum < 1 or slotNum > 9 then
			return true
		end

		RunConsoleCommand("tf_spydisguise", tostring(slotNum), tostring(getTeamIndexForMenu()))
		return true
	end)

	function SWEP:Deploy()
		resetTeamForMenu()
		return self.BaseClass.Deploy(self)
	end
end

function SWEP:SecondaryAttack()
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

	-- Random disguise is handled through the client bind hook above so it
	-- follows the same input path as the Spy disguise menu key handling.
end

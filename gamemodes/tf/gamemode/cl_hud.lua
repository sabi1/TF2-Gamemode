

local function TFIsHL2Player(pl)
	if not IsValid(pl) then return false end
	if pl.IsHL2 then
		return pl:IsHL2()
	end
	return pl:GetNWBool("IsHL2", false)
end

local function TFGetPlayerItems(pl)
	if not IsValid(pl) then return {} end
	if pl.GetTFItems then
		return pl:GetTFItems()
	end
	return pl:GetWeapons()
end

function IsCustomHUDVisible(name)
	local lp = LocalPlayer()
	for _,v in pairs(TFGetPlayerItems(lp)) do
		local gch = v.GlobalCustomHUD
		local ch = v.CustomHUD
		
		if gch and gch[name] then
			gch = gch[name]
			if type(gch)=="function" then gch = gch(v) end
		else
			gch = nil
		end
		
		if ch and ch[name] then
			ch = ch[name]
			if type(ch)=="function" then ch = ch(v) end
		else
			ch = nil
		end
		
		if gch or (v==lp:GetActiveWeapon() and ch) then
			return true
		end
	end
	
	return false
end

local VGUIFiles = {
	"vgui_circularprogressbar";
	"vgui_spectatorhealth";
	"vgui_tf2res";
	"vgui_tfbutton";
	"vgui_itemmodelpanel";
	"vgui_classmodelpanel";
	"vgui_itemattributepanel";
	"vgui_buildinghealth";
	--"vgui_teammenubg";

	"hud_sniperchargemeter";
	
	"hud_obj_base";
	"hud_obj_sentrygun";
	"hud_obj_dispenser";
	"hud_obj_tele_entrance";
	"hud_obj_tele_exit";
	
	"hud_buildingstatus";
	
	"hud_playerclass";
	"hud_playerhealth";
	"hud_ammoweapons";
	"hud_bowcharge";
	"hud_itemeffectmeter";
	"hud_itemeffectmeter_demoman";
	
	"hud_weaponselection";
	"hud_inspectpanel";
	"hud_objectiveflagpanel";
	"hud_objectiveflagpanel_blue";
	"hud_objectivebombpanel";
	"hud_payloadpanel";
	
	"hud_demomanpipes";
	"hud_mediccharge";
	
	"hud_healthaccount";
	"hud_accountpanel";
	
	"hud_targetid";
	"hud_freezepanel";
	
	"hud_cptest";
	"hud_roundtimer";
	"hud_halloweenboss";
	"hud_menuengybuild";
	"hud_menuengydestroy";
	"hud_menuspydisguise";
	"hud_menutaunt";
	"hud_voicemenu";
	
	"menu_charinfopanel";
	"menu_charinfoloadoutsubpanel";
	"menu_fullloadoutpanel";
	"menu_motdpanel";
	"menu_teamselectpanel";
	"menu_escpanel";
	
	"scoreboard_playerlist"; 
	"mvmbotlist";
	"scoreboard_localstats";
	"scoreboard_main";
}

function LoadVGUI()
	local path
	if GM then
		path = "vgui/%s.lua"
	else
		path = string.gsub(GAMEMODE.Folder, "gamemodes/", "").."/gamemode/vgui/%s.lua"
		GAMEMODE:DestroyScoreboard()
	end
	
	for _,v in ipairs(VGUIFiles) do
		include(Format(path, v))
	end
end

concommand.Add("reload_vgui", function()
	LoadVGUI()
end)

LoadVGUI()
if IsValid(HudMvMStatus) then
	HudMvMStatus:Remove()
	HudMvMStatus = nil
end
include("cl_crosshairs.lua")
include("cl_scoreboard.lua")
include("cl_chatprefix.lua")
include("cl_vsh_hud.lua")
 
local W = ScrW()
local H = ScrH()
local WScale = ScrW()/640
local Scale = ScrH()/480

if T then T:Remove() end
--[[
T = vgui.Create("ItemAttributePanel")
T:SetPos(50,50)
T:SetSize(168*Scale,300*Scale)
T.text_ypos = 20
T.text = "THE CRAB-WALKING KIT"
T.attributes = {
{"Level 0 Cigarette Case", 1},
{"It will change your skeleton!", 2},
{"Excrutiatingly painful . . .", 4},
{". . . but worth it", 3},
}
T:SetQuality("rarity3")]]

local hud_targetid_anyteam = CreateConVar("hud_targetid_anyteam", "0", {FCVAR_CHEAT})
local hud_defaultweaponselect = CreateConVar("hud_defaultweaponselect", "0")
local hl2hudtf = CreateConVar("tf_forcehl2hud", "0")

local HiddenHudElements = {
	CHudDamageIndicator = 1,
	CHudHealth = 1,
	--CHudBattery = 1,
	CHudAmmo = 1,
	CHudSecondaryAmmo = 1,
	CHudCrosshair = 1,
	CHudSuitPower = 1,
	CHudSquadStatus = 1,
	CHudPoisonDamageIndicator = 1,
	CHudHistoryResource = 1,
}
function GM:HideHUDElement(e)
	HiddenHudElements[e] = 1
end

function GM:ShowHUDElement(e)
	HiddenHudElements[e] = nil
end

function GM:HUDAmmoPickedUp(item, amount) end
function GM:HUDItemPickedUp(item, amount) end

function GM:HUDWeaponPickedUp(wep)
	HudWeaponSelection:UpdateLoadout()
end

net.Receive("UpdateLoadout", function()
	HudWeaponSelection:UpdateLoadout()
	--print("kk")
end)

-- Weapon selection

function GM:InitWeaponSelection(class)
	local tbl = GAMEMODE.PlayerClasses[class]
	
	if tbl and not tbl.IsHL2 then
		--HudWeaponSelection:SetLoadout(tbl.Loadout)
		HudWeaponSelection:UpdateLoadout()
	end
end

-- Using concommands to make sure weapon selection is done properly in demos

concommand.Add("tf_selectslot", function(pl, cmd, args)
	GAMEMODE:ShowWeaponSelection()
	local fastSwitch = GetConVar("tf_fastweaponswitch")
	if not (fastSwitch and fastSwitch:GetBool()) then
		pl:EmitSound("Player.WeaponSelectionMoveSlot")
	end
	HudWeaponSelection:Select(tonumber(args[1]))
end)

concommand.Add("tf_useweapon", function(pl, cmd, args)
	GAMEMODE:HideWeaponSelection()
	RunConsoleCommand("use", args[1])
end)

local function TFShouldFastSwitch()
	local cvar = GetConVar("tf_fastweaponswitch")
	return cvar and cvar:GetBool()
end

local function TFAttemptFastSwitch(slot)
	if not TFShouldFastSwitch() then return end

	-- Defer by one tick so hud selection state is fully updated first.
	timer.Simple(0, function()
		if not IsValid(HudWeaponSelection) then return end
		if slot then
			HudWeaponSelection:Select(slot)
		end
		if not HudWeaponSelection:CanSelectWeapon() then return end

		local wep = HudWeaponSelection:CurrentWeapon()
		if not wep or wep == "" then return end

		RunConsoleCommand("tf_useweapon", wep)
	end)
end

function GM:PlayerSlotSelected(slot)
	
end

function GM:PlayerBindPress(pl, cmd, down)
	local bind = string.lower(string.Trim(tostring(cmd or "")))

	-- TF2 parity: +taunt opens the taunt HUD; while open, +taunt performs weapon taunt.
	if down and (string.find(bind, "^%+taunt") or string.find(bind, "^taunt$") or string.find(bind, "^impulse%s+201$")) then
		if IsValid(HudTauntMenu) then
			if HudTauntMenu:IsOpen() then
				HudTauntMenu:DoWeaponTaunt()
			else
				if not HudTauntMenu:Open() then
					RunConsoleCommand("taunt")
				end
			end
		else
			RunConsoleCommand("taunt")
		end
		return true
	end

	if ( string.find( cmd, "gmod_undo" ) ) then return true end 
	if TFIsHL2Player(pl) or hud_defaultweaponselect:GetBool() or hl2hudtf:GetBool() or GetConVar("hud_fastswitch"):GetBool() then return end
	if not down then return end

	if IsValid(HudTauntMenu) and HudTauntMenu:IsOpen() then
		if string.find(bind, "^lastinv") then
			HudTauntMenu:Close()
			return true
		end

		local tauntSlot = tonumber(string.match(bind, "slot(%d+)"))
		if tauntSlot and tauntSlot >= 1 and tauntSlot <= 8 then
			HudTauntMenu:SelectSlot(tauntSlot)
			return true
		end
	end
	
	local n = tonumber(string.match(cmd, "slot(%d+)"))
	if n then
		if not pl:Alive() then return true end
		
		if not HudWeaponSelection.NumSlots then
			self:InitWeaponSelection(pl:GetPlayerClass())
		end
		
		local r = gamemode.Call("PlayerSlotSelected", n)
		
		if not r and HudWeaponSelection:CanSelectSlot(n) then
			if LocalPlayer().ShouldUpdateWeaponSelection then
				HudWeaponSelection:UpdateLoadout()
				LocalPlayer().ShouldUpdateWeaponSelection = false
			end
			
			RunConsoleCommand("tf_selectslot", n)
			TFAttemptFastSwitch(n)
		end
		
		return true
	end
	
	if string.find(cmd, "^invnext") then
		if not pl:Alive() then return true end
		
		if not HudWeaponSelection.NumSlots then
			self:InitWeaponSelection(pl:GetPlayerClass())
		end
		
		if LocalPlayer().ShouldUpdateWeaponSelection then
			HudWeaponSelection:UpdateLoadout()
			LocalPlayer().ShouldUpdateWeaponSelection = false
		end
		
		local n
		if HudWeaponSelection:IsVisible() then	n = HudWeaponSelection.CurrentSlot
		else									n = self:GetCurrentWeaponSlot() or 0
		end
		
		n = HudWeaponSelection:GetNextSlot(n)
		RunConsoleCommand("tf_selectslot", n)
		TFAttemptFastSwitch(n)
		return true
	elseif string.find(cmd, "^invprev") then
		if not pl:Alive() then return true end
		
		if not HudWeaponSelection.NumSlots then
			self:InitWeaponSelection(pl:GetPlayerClass())
		end
		
		if LocalPlayer().ShouldUpdateWeaponSelection then
			HudWeaponSelection:UpdateLoadout()
			LocalPlayer().ShouldUpdateWeaponSelection = false
		end
		
		local n
		if HudWeaponSelection:IsVisible() then	n = HudWeaponSelection.CurrentSlot
		else									n = self:GetCurrentWeaponSlot() or 2
		end
		
		n = HudWeaponSelection:GetPreviousSlot(n)
		RunConsoleCommand("tf_selectslot", n)
		TFAttemptFastSwitch(n)
		return true
	elseif HudWeaponSelection:IsVisible() and string.find(cmd, "^+attack") then
		if not pl:Alive() then return true end
		
		if HudWeaponSelection:CanSelectWeapon() then
			RunConsoleCommand("tf_useweapon", HudWeaponSelection:CurrentWeapon())
		end
		return true
	end
end

function GM:GetCurrentWeaponSlot()
	return HudWeaponSelection:CalcCurrentWeaponSlot()
end

function GM:ShowWeaponSelection()
	if not HudWeaponSelection:IsVisible() then
		HudWeaponSelection:SetVisible(true)
	end
	HudWeaponSelection.NextHide = CurTime() + 2
end

function GM:HideWeaponSelection()
	if HudWeaponSelection:IsVisible() then
		HudWeaponSelection:SetVisible(false)
	end
	HudWeaponSelection.NextHide = nil
end

function GM:WeaponSelectionThink()
	if HudWeaponSelection.NextHide and CurTime()>HudWeaponSelection.NextHide then
		self:HideWeaponSelection()
	end
end

-- Using a custom TargetID system

function GM:HUDDrawTargetID()
	if TFIsHL2Player(LocalPlayer()) then
		
		local tr = util.GetPlayerTrace( LocalPlayer() )
		local trace = util.TraceLine( tr )
		if ( !trace.Hit ) then return end
		if ( !trace.HitNonWorld ) then return end
		
		local text = "ERROR"
		local font = "TargetID"
		
		if ( trace.Entity:IsTFPlayer() ) then
			text = GAMEMODE:EntityTargetIDName(trace.Entity)
		else
			return
			--text = trace.Entity:GetClass()
		end
		
		surface.SetFont( font )
		local w, h = surface.GetTextSize( text )
		
		local MouseX, MouseY = gui.MousePos()
		
		if ( MouseX == 0 && MouseY == 0 ) then
		
			MouseX = ScrW() / 2
			MouseY = ScrH() / 2
		
		end
		
		local x = MouseX
		local y = MouseY
		
		x = x - w / 2
		y = y + 30
		
		-- The fonts internal drop shadow looks lousy with AA on
		draw.SimpleText( text, font, x + 1, y + 1, Color( 0, 0, 0, 120 ) )
		draw.SimpleText( text, font, x + 2, y + 2, Color( 0, 0, 0, 50 ) )
		local targetTeam = GAMEMODE.GetEntityVisibleTeamForViewer and GAMEMODE:GetEntityVisibleTeamForViewer(trace.Entity, LocalPlayer()) or GAMEMODE:EntityTeam(trace.Entity)
		draw.SimpleText( text, font, x, y, team.GetColor(targetTeam) )
		
		y = y + h + 5
		
		local text = trace.Entity:Health() .. "%"
		local font = "TargetIDSmall"
		
		surface.SetFont( font )
		local w, h = surface.GetTextSize( text )
		local x = MouseX - w / 2
		
		draw.SimpleText( text, font, x + 1, y + 1, Color( 0, 0, 0, 120 ) )
		draw.SimpleText( text, font, x + 2, y + 2, Color( 0, 0, 0, 50 ) )
		local targetTeam = GAMEMODE.GetEntityVisibleTeamForViewer and GAMEMODE:GetEntityVisibleTeamForViewer(trace.Entity, LocalPlayer()) or GAMEMODE:EntityTeam(trace.Entity)
		draw.SimpleText( text, font, x, y, team.GetColor(targetTeam) )

	else
    	return false
	end
end

local function targetid_trace_condition(tr,ply)
	ply = ply or LocalPlayer()
	if TFIsHL2Player(ply) then return false end
	if not IsValid(tr.Entity) or not tr.Entity:IsTFPlayer() then return false end

	local targetTeam = GAMEMODE.GetEntityVisibleTeamForViewer and GAMEMODE:GetEntityVisibleTeamForViewer(tr.Entity, ply) or GAMEMODE:EntityTeam(tr.Entity)
	return targetTeam == ply:Team() and tr.Entity:GetMaterial() != "color" and tr.Entity:GetMaterial() != "models/shadertest/shader3" and tr.Entity:GetMaterial() != "models/props_combine/tprings_globe"
end

function GM:TargetIDThink()
	local ply = LocalPlayer()

	if LocalPlayer():GetObserverTarget() and LocalPlayer():GetObserverTarget():IsPlayer() then
		ply = LocalPlayer():GetObserverTarget()
	end

	if not ply:Alive() then
		return
	end
	
	--local ent = ply:GetEyeTrace().Entity
	
	local start = ply:GetShootPos()
	local endpos = start + ply:GetAimVector() * 10000
	
	local tr = tf_util.MixedTrace({
		start = start,
		endpos = endpos,
		filter = ply,
		mins = Vector(-5, -5, -5),
		maxs = Vector(5, 5, 5),
	}, targetid_trace_condition)
	
	if targetid_trace_condition(tr, ply) then
		HudTargetID:SetTargetEntity(tr.Entity)
		HudTargetID:SetVisible(true)
	else
		HudTargetID:SetVisible(false)
	end
end

function GM:HUDShouldDraw(n)
	if IsValid(LocalPlayer()) and (TFIsHL2Player(LocalPlayer()) or hl2hudtf:GetBool()) then
		return self.BaseClass:HUDShouldDraw(n)
	end
	
	if HiddenHudElements[n] then return false end
	return true
end

function GM:HUDPaint()
	self.BaseClass:HUDPaint()
	if LocalPlayer():Alive() and not TFIsHL2Player(LocalPlayer()) and not hl2hudtf:GetBool() then
		self:DrawDamageNotifiers()
		self:DrawDamageIndicators()
		if not LocalPlayer():GetNWBool("HalloweenKart", false) then
			self:DrawCrosshair()
		end
	end

	local lp = LocalPlayer()
	if IsValid(lp) and lp:Alive() and lp:GetNWBool("HalloweenKart", false) then
		local boostEnd = lp:GetNWFloat("TFKartBoostEndTime", 0)
		local cooldownEnd = lp:GetNWFloat("TFKartBoostCooldownEndTime", 0)
		local now = CurTime()
		local ready = now >= cooldownEnd
		local boostActive = now < boostEnd

		local barW = math.floor(ScrW() * 0.24)
		local barH = 16
		local x = math.floor((ScrW() - barW) * 0.5)
		local y = math.floor(ScrH() * 0.86)
		local frac = 1
		if not ready then
			local cdTotal = 2.5
			frac = math.Clamp(1 - ((cooldownEnd - now) / cdTotal), 0, 1)
		end

		draw.RoundedBox(4, x - 6, y - 26, barW + 12, barH + 34, Color(20, 20, 20, 170))
		draw.SimpleText("KART BOOST", "HudFontSmall", x + barW * 0.5, y - 18, Color(255, 220, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.RoundedBox(2, x, y, barW, barH, Color(40, 40, 40, 220))
		draw.RoundedBox(2, x + 1, y + 1, math.max(0, (barW - 2) * frac), barH - 2, boostActive and Color(255, 170, 60, 240) or Color(120, 220, 120, 240))

		local status = "READY (MOUSE2)"
		if boostActive then
			status = "BOOSTING"
		elseif not ready then
			status = string.format("RECHARGING: %.1fs", math.max(cooldownEnd - now, 0))
		end
		draw.SimpleText(status, "TFDefaultSmall", x + barW * 0.5, y + barH + 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
end

function GM:Think()
	self.BaseClass:Think()
	self:TargetIDThink()
	self:WeaponSelectionThink()
end

hook.Add("PreDrawHalos", "AddWeaponHalos", function()
	local lp = LocalPlayer()
	if not IsValid(lp) or lp:GetNWBool("SpawnGlows", false) ~= true then
		return
	end

	local friendlyPlayers = {}
	local redPlayers = {}
	local bluPlayers = {}
	local anyTeam = lp:Team() == TEAM_NEUTRAL
	for _, v in ipairs(player.GetAll()) do
		if IsValid(v) and (anyTeam or v:IsFriendly(lp)) then
			if anyTeam then
				if v:Team() == TEAM_RED then
					redPlayers[#redPlayers + 1] = v
				elseif v:Team() == TEAM_BLU then
					bluPlayers[#bluPlayers + 1] = v
				else
					friendlyPlayers[#friendlyPlayers + 1] = v
				end
			else
				friendlyPlayers[#friendlyPlayers + 1] = v
			end
			v:DrawModel(RENDERGROUP_VIEWMODEL)
		end
	end

	if #redPlayers > 0 then
		halo.Add(redPlayers, team.GetColor(TEAM_RED), 0, 0, 2, true, true)
	end
	if #bluPlayers > 0 then
		halo.Add(bluPlayers, team.GetColor(TEAM_BLU), 0, 0, 2, true, true)
	end
	if #friendlyPlayers > 0 then
		halo.Add(friendlyPlayers, team.GetColor(lp:Team()), 0, 0, 2, true, true)
	end
end)


DamageIndicators = {}
--local indicator_radius = CreateClientConVar("hud_dmgindicator_radius", 0.3)
--local indicator_duration = CreateClientConVar("hud_dmgindicator_duration", 1)
local indicator_tex = surface.GetTextureID("vgui/damageindicator")

local W = ScrW()
local H = ScrH()
local WScale = ScrW()/640
local Scale = ScrH()/480

BaseScaleX = 16
BaseScaleY = 16
MaxScale = 6
MaxDamage = 150 

function GM:DrawDamageIndicators()
	--local radius = ScrH() * indicator_radius:GetFloat()
	local radius = ScrH() * 0.3
	--local duration = indicator_duration:GetFloat()
	local duration = 1
	local cx, cy = ScrW()/2, ScrH()/2
	
	surface.SetTexture(indicator_tex)
	
	-- Iterating backwards, so we can remove items without fucking everything up
	for i=#DamageIndicators,1,-1 do
		local ind = DamageIndicators[i]
		
		local v = ind[1]
		local ang = v:Angle()
		ang.p = 0
		ang.y = ang.y - LocalPlayer():EyeAngles().y
		
		v = ang:Forward()
		
		local alpha = 255
		local dt = CurTime() - ind[3]
		if dt>duration then
			dt = dt - duration
			alpha = math.Clamp(255-100*dt, 0, 255)
		end
		
		local mul = 1 + MaxScale * math.Clamp(ind[2]/MaxDamage,0,1)
		local scalex = BaseScaleX * Scale * mul
		local scaley = BaseScaleY * Scale * mul
		
		surface.SetDrawColor(255,255,255,alpha)
		--surface.DrawRect(cx-radius*v.y-2, cy-radius*v.x-2, 4, 4)
		surface.DrawTexturedRectRotated(cx-radius*v.y, cy-radius*v.x, scalex, scaley, ang.y)
		
		if alpha<=0 then
			table.remove(DamageIndicators, i)
		end
	end
end

usermessage.Hook("PushDamageIndicator", function(um)
	local last = DamageIndicators[1]
	if last and CurTime() - last[3]<0.02 then
		-- For damage received from several sources at the same time
		last[0] = (last[0] or 1) + 1
		last[1] = (last[1] + um:ReadVector()) / last[0]
		last[2] = last[2] + um:ReadFloat()
	else
		table.insert(DamageIndicators, 1, {um:ReadVector(), um:ReadFloat(), CurTime()})
	end
end)



DamageNotifiers = {}
local notifier_enabled = CreateClientConVar("hud_showdamagenotifier", 0)

function GM:DrawDamageNotifiers()
	-- Iterating backwards, so we can remove items without fucking everything up
	for i=#DamageNotifiers,1,-1 do
		local ind = DamageNotifiers[i]
		
		local v = ind[1]:ToScreen()
		
		local diff = CurTime() - ind[4]
		local r = math.Clamp(diff / 1.5, 0, 1)
		
		if v.visible then
			local alpha = Lerp(r, 255, 0)
			v.y = Lerp(r, v.y, v.y - 48 * Scale)
			
			draw.Text{
				text = "-"..math.floor(ind[2]),
				pos = {v.x, v.y},
				font = "HudFontMediumSmall",
				xalign = TEXT_ALIGN_CENTER,
				yalign = TEXT_ALIGN_CENTER,
				color = Color(255, 0, 0, alpha),
			}
		end
		
		if r>=1 then
			table.remove(DamageNotifiers, i)
		end
	end
end

usermessage.Hook("PushDamageNotifier", function(um)
	local clock = um:ReadFloat()
	local pos = um:ReadVector()
	local dmg = um:ReadFloat()
	
	for _,v in ipairs(DamageNotifiers) do
		if	math.abs(v[3]-clock)<0.02 and
			math.abs(v[1].x - pos.x)<0.2 and
			math.abs(v[1].y - pos.y)<0.2 and
			math.abs(v[1].z - pos.z)<0.2 then
			v[2] = v[2] + dmg
			return
		end
	end
	
	if pos:Distance(EyePos()) < 80 then return end
	
	table.insert(DamageNotifiers, 1, {pos, dmg, clock, CurTime()})
end)

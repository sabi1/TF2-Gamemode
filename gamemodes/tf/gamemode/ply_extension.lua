
-- General player extensions
local allowedtaunts = {
	"1",
	"2",
	"3",	
	"4",
	"5"
}

rockpaperscissors = {
	"taunt_rps_scissors_win",
	"taunt_rps_scissors_lose",
	"taunt_rps_paper_win",
	"taunt_rps_paper_lose",
	"taunt_rps_rock_win",
	"taunt_rps_rock_lose",
}
rockpaperscissors2 = {
	"taunt_rps_scissors_lose",
	"taunt_rps_scissors_win",
	"taunt_rps_paper_lose",
	"taunt_rps_paper_win",
	"taunt_rps_rock_lose",
	"taunt_rps_rock_win",
}
rockpaperscissorsact = {
	ACT_DOD_SPRINT_IDLE_BAR,
	ACT_DOD_PRONEWALK_IDLE_BAR,
	ACT_DOD_ZOOMLOAD_BAZOOKA,
	ACT_DOD_RELOAD_PSCHRECK,
	ACT_DOD_ZOOMLOAD_PSCHRECK,
	ACT_DOD_RELOAD_DEPLOYED_FG42,
}

local class_hidewep = {
	"scout",
	"soldier",
	"pyro",
	"engineer",
	"medic",
}

local wep = {
	"tf_weapon_medigun",
	"tf_weapon_pistol_scout",
	"tf_weapon_rocketlauncher",
	"tf_weapon_shotgun_pyro",
	"tf_weapon_shotgun_primary",
	"tf_weapon_syringegun_medic",
}

local meta = FindMetaTable( "Player" )
if (!meta) then return end 
local builds = {}
builds[2] = "obj_sentrygun"
builds[0] = "obj_dispenser"
builds[1] = "obj_teleporter"
local Player = FindMetaTable("Player")

function RegisterStatType(obj, name)
	local name_get = name
	local name_set = "Set"..name
	local name_add = "Add"..name
	local name_umsg = "__playerSet"..name
	
	obj[name_get] = function(self)
		if not self.Stats then self.Stats = {} end
		return self.Stats[name] or 0
	end
	
	if SERVER then
		obj[name_set] = function(self, val)
			if not self.Stats then self.Stats = {} end
			self.Stats[name] = val
			umsg.Start(name_umsg)
				umsg.Entity(self)
				umsg.Long(val)
			umsg.End()
		end
		
		obj[name_add] = function(self, val)
			self[name_set](self, self[name_get](self) + val)
		end
	else
		usermessage.Hook(name_umsg, function(msg)
			local self = msg:ReadEntity()
			if not IsValid(self) or not self:IsPlayer() then return end
			if not self.Stats then self.Stats = {} end
			self.Stats[name] = msg:ReadLong()
		end)
	end
end

RegisterStatType(meta, "Kills")
RegisterStatType(meta, "Assists")
RegisterStatType(meta, "Destructions")

RegisterStatType(meta, "Captures")
RegisterStatType(meta, "Defenses")
RegisterStatType(meta, "Dominations")
RegisterStatType(meta, "Revenges")

RegisterStatType(meta, "Healing")
RegisterStatType(meta, "Invulns")
RegisterStatType(meta, "Teleports")
RegisterStatType(meta, "Headshots")

RegisterStatType(meta, "Backstabs")
RegisterStatType(meta, "Bonus")

-- Serverside


if SERVER then

if not meta.SetFrags0 then
	meta.SetFrags0 = meta.SetFrags
end
function meta:SetFrags(n)
	if not self.Stats then self.Stats = {} end
	self.Stats.Points = n
	self:SetFrags0(math.floor(self.Stats.Points))
end

function meta:AddFrags(n)
	if not self.Stats then self.Stats = {} end
	self.Stats.Points = (self.Stats.Points or self:Frags()) + n
	self:SetFrags0(math.floor(self.Stats.Points))
end

function meta:Explode(dmginfo)
	if (self:IsL4D()) then return end
		self.ShouldGib = true
		umsg.Start("GibPlayer")
			umsg.Long(self:UserID())
			umsg.Short(self.DeathFlags)	
		umsg.End()
	--self:EmitSound(")player/gib"..math.random(1,3)..".wav", 95)
	--self:EmitSound(")player/gibexplosion"..math.random(1,3)..".wav", 115) 
end
if not meta.CreateRagdollOLD then
	meta.CreateRagdollOLD = meta.CreateRagdoll
end

function meta:CreateRagdoll()
	self:CreateRagdollOLD()
end
function meta:IsNeutral()
	return self:Team() == TEAM_NEUTRAL and !self:IsBot()
end

local tauntItemCommandRules = {
	{tokens = {"schadenfreude", "laugh"}, cmd = "tf_taunt_laugh"},
	{tokens = {"conga"}, cmd = "tf_taunt_conga_start"},
	{tokens = {"kazotsky", "russian dance", "russian rubdown"}, cmd = "tf_taunt_russian_start"},
	{tokens = {"square dance", "dosido"}, cmd = "tf_taunt_squaredance_intro"},
	{tokens = {"rock, paper, scissors", "rps"}, cmd = "tf_taunt_rockpaperscissors_intro"},
	{tokens = {"flippin", "flip taunt"}, cmd = "tf_taunt_flipping_intro"},
	{tokens = {"skullcracker"}, cmd = "tf_taunt_skullcracker"},
	{tokens = {"high five"}, cmd = "tf_taunt_highfive_success"},
	{tokens = {"director's vision", "director vision"}, cmd = "tf_taunt_directors_vision"},
	{tokens = {"party trick"}, cmd = "tf_taunt_pyro_partytrick"},
	{tokens = {"meet the medic", "heroic pose"}, cmd = "tf_taunt_heroric"},
	{tokens = {"luxury lounge"}, cmd = "tf_taunt_chair"},
	{tokens = {"rancho relaxo"}, cmd = "tf_taunt_chair2"},
	{tokens = {"yeti"}, cmd = "tf_taunt_yeti"},
	{tokens = {"brutal legend", "killer solo"}, cmd = "tf_taunt_brutallegend"},
	{tokens = {"thriller"}, cmd = "tf_taunt_thriller"},
	{tokens = {"introduction"}, cmd = "tf_taunt_introduction"},
	{tokens = {"gimme 20"}, cmd = "tf_taunt_gimme20"},
	{tokens = {"slit throat"}, cmd = "tf_taunt_slit_throat"},
	{tokens = {"come and get me"}, cmd = "tf_taunt_come_and_get_me"},
	{tokens = {"oblooterated", "woohoo"}, cmd = "tf_taunt_woohoo"},
	{tokens = {"banjo"}, cmd = "tf_taunt_banjo_start"},
}

-- TF2 SDK taunt flow resolves from equipped taunt-item data first. We don't have
-- the full scene system in Lua, so map item tokens to the closest implemented command.
local function tokenCmd(token)
	return "tf_taunt_token " .. token
end

local tauntCommandByToken = {
	["schadenfreude"] = "tf_taunt_laugh",
	["conga"] = "tf_taunt_conga_start",
	["russian_arms_race"] = tokenCmd("russian_arms_race"),
	["russian_rubdown"] = tokenCmd("russian_rubdown"),
	["tuefort_tango"] = tokenCmd("tuefort_tango"),
	["rockpaperscissors"] = "tf_taunt_rockpaperscissors_intro",
	["skullcracker"] = "tf_taunt_skullcracker",
	["highfive"] = "tf_taunt_highfive",
	["the_fist_bump"] = tokenCmd("the_fist_bump"),
	["director_s_vision"] = "tf_taunt_directors_vision",
	["party_trick"] = "tf_taunt_pyro_partytrick",
	["luxury_lounge"] = tokenCmd("luxury_lounge"),
	["rancho_relaxo"] = tokenCmd("rancho_relaxo"),
	["time_out_therapy"] = tokenCmd("time_out_therapy"),
	["tailored_terminal"] = tokenCmd("tailored_terminal"),
	["yeti"] = "tf_taunt_yeti",
	["the_scaredycat"] = tokenCmd("the_scaredycat"),
	["brutal_legend"] = "tf_taunt_brutallegend",
	["killer_solo"] = tokenCmd("killer_solo"),
	["dueling_banjo"] = tokenCmd("dueling_banjo"),
	["surgeons_squeezebox"] = tokenCmd("surgeons_squeezebox"),
	["fubar_fanfare"] = tokenCmd("fubar_fanfare"),
	["didgeridrongo"] = tokenCmd("didgeridrongo"),
	["thriller"] = "tf_taunt_thriller",
	["introduction"] = "tf_taunt_introduction",
	["gimme20"] = "tf_taunt_gimme20",
	["slit_throat"] = "tf_taunt_slit_throat",
	["come_and_get_me"] = "tf_taunt_come_and_get_me",
	["oblooterated"] = "tf_taunt_woohoo",
	["disco_fever"] = "tf_taunt_disco",
	["runners_rhythm"] = tokenCmd("runners_rhythm"),
	["the_boston_breakdance"] = tokenCmd("the_boston_breakdance"),
	["the_carlton"] = tokenCmd("the_carlton"),
	["spy_boxtrot"] = tokenCmd("spy_boxtrot"),
	["neck_snap"] = tokenCmd("neck_snap"),
	["foul_play"] = tokenCmd("foul_play"),
	["unleashed_rage"] = tokenCmd("unleashed_rage"),
	["the_headcase"] = tokenCmd("the_headcase"),
	["the_homerunners_hobby"] = tokenCmd("the_homerunners_hobby"),
	["the_trackmans_touchdown"] = tokenCmd("the_trackmans_touchdown"),
	["roar_owar"] = tokenCmd("roar_owar"),
	["scotsmans_stagger"] = tokenCmd("scotsmans_stagger"),
	["drunk_manns_cannon"] = tokenCmd("drunk_manns_cannon"),
	["the_pooped_deck"] = tokenCmd("the_pooped_deck"),
	["roasty_toasty"] = tokenCmd("roasty_toasty"),
	["scorchers_solo"] = tokenCmd("scorchers_solo"),
	["cremators_condolences"] = tokenCmd("cremators_condolences"),
	["head_doctor"] = tokenCmd("head_doctor"),
	["borrowed_bones"] = tokenCmd("borrowed_bones"),
	["the_mannbulance"] = tokenCmd("the_mannbulance"),
	["soviet_strongarm"] = tokenCmd("soviet_strongarm"),
	["bare_knuckle_beatdown"] = tokenCmd("bare_knuckle_beatdown"),
	["road_rager"] = tokenCmd("road_rager"),
	["the_hot_wheeler"] = tokenCmd("the_hot_wheeler"),
	["starspangled_strategy"] = tokenCmd("starspangled_strategy"),
	["straight_shooter_tutor"] = tokenCmd("straight_shooter_tutor"),
	["most_wanted"] = tokenCmd("most_wanted"),
	["the_crypt_creeper"] = tokenCmd("the_crypt_creeper"),
	["the_profane_puppeteer"] = tokenCmd("the_profane_puppeteer"),
	["mourning_mercs"] = tokenCmd("mourning_mercs"),
	["maggots_condolence"] = tokenCmd("maggots_condolence"),
	["shanty_shipmate"] = tokenCmd("shanty_shipmate"),
	["shipwheel"] = tokenCmd("shipwheel"),
	["the_travel_agent"] = tokenCmd("the_travel_agent"),
	["the_boston_boarder"] = tokenCmd("the_boston_boarder"),
	["rocket_jockey"] = tokenCmd("rocket_jockey"),
	["tank"] = tokenCmd("tank"),
	["moped"] = "tf_taunt_moped",
	["the_scooty_scoot"] = "tf_taunt_moped",
	["chairholder"] = tokenCmd("chairholder"),
	["healthcarehog"] = tokenCmd("healthcarehog"),
	["balloonibouncer"] = tokenCmd("balloonibouncer"),
	["texas_truckin"] = tokenCmd("texas_truckin"),
	["the_skating_scorcher"] = tokenCmd("the_skating_scorcher"),
	["jumping_jack"] = tokenCmd("jumping_jack"),
	["ring_king"] = tokenCmd("ring_king"),
	["peace"] = tokenCmd("peace"),
	["peace_out"] = tokenCmd("peace_out"),
	["cheers"] = tokenCmd("cheers"),
	["commending_clap"] = tokenCmd("commending_clap"),
	["killer_joke"] = tokenCmd("killer_joke"),
	["the_punchline"] = tokenCmd("the_punchline"),
	["the_critical_fail"] = tokenCmd("the_critical_fail"),
	["crushing_defeat"] = tokenCmd("crushing_defeat"),
	["curtain_call"] = tokenCmd("curtain_call"),
	["killer_signature"] = tokenCmd("killer_signature"),
	["texan_trickshot"] = tokenCmd("texan_trickshot"),
	["texas_twirl_em"] = tokenCmd("texas_twirl_em"),
	["spintowin"] = tokenCmd("spintowin"),
	["the_final_score"] = tokenCmd("the_final_score"),
	["flying_colors"] = tokenCmd("flying_colors"),
	["the_bunnyhopper"] = tokenCmd("the_bunnyhopper"),
	["bear_hug"] = tokenCmd("bear_hug"),
	["proletariat_showoff"] = tokenCmd("proletariat_showoff"),
	["heartbreaker"] = tokenCmd("heartbreaker"),
	["dead_manns_drink"] = tokenCmd("dead_manns_drink"),
	["forehead_slice"] = tokenCmd("forehead_slice"),
}

local function normalizeTauntToken(raw)
	local token = string.lower(tostring(raw or ""))
	if token == "" then return nil end
	token = string.gsub(token, "^#", "")
	token = string.gsub(token, "^tf_", "")
	token = string.gsub(token, "^taunt_", "")
	token = string.gsub(token, "_desc$", "")
	token = string.gsub(token, "_adtext$", "")
	token = string.gsub(token, "_style%d+$", "")
	token = string.gsub(token, "[^a-z0-9_]+", "_")
	token = string.gsub(token, "_+", "_")
	token = string.gsub(token, "^_+", "")
	token = string.gsub(token, "_+$", "")
	if token == "" then return nil end
	return token
end

local function commandFromItemToken(item)
	if not istable(item) then return nil end
	local fields = {
		item.item_name,
		item.name,
		item.item_type_name,
		tf_lang and tf_lang.GetRaw and tf_lang.GetRaw(item.item_name) or nil,
		tf_lang and tf_lang.GetRaw and tf_lang.GetRaw(item.name) or nil,
		tf_lang and tf_lang.GetRaw and tf_lang.GetRaw(item.item_type_name) or nil,
	}
	for _, raw in ipairs(fields) do
		local token = normalizeTauntToken(raw)
		if token and tauntCommandByToken[token] then
			return tauntCommandByToken[token]
		end
	end
	return nil
end

local function isLikelyTauntItem(item)
	if not istable(item) then return false end
	local blob = string.lower(table.concat({
		tostring(item.name or ""),
		tostring(item.item_name or ""),
		tostring(item.item_type_name or ""),
		tostring(tf_lang and tf_lang.GetRaw and tf_lang.GetRaw(item.item_name) or ""),
		tostring(tf_lang and tf_lang.GetRaw and tf_lang.GetRaw(item.item_type_name) or ""),
	}, " "))
	return string.find(blob, "taunt", 1, true) ~= nil
end
local tauntCommandByDefindex = nil

local function getItemTextBlob(item)
	if not istable(item) then return "" end
	local parts = {}
	parts[#parts + 1] = tostring(item.name or "")
	parts[#parts + 1] = tostring(item.item_name or "")
	parts[#parts + 1] = tostring(item.item_type_name or "")
	if tf_lang and tf_lang.GetRaw then
		parts[#parts + 1] = tostring(tf_lang.GetRaw(item.item_name) or "")
		parts[#parts + 1] = tostring(tf_lang.GetRaw(item.item_type_name) or "")
	end
	return string.lower(table.concat(parts, " "))
end

local function itemHasSchemaTaunt(item)
	return istable(item) and istable(item.taunt) and istable(item.taunt.custom_taunt_scene_per_class)
end

local specialManualTauntCommands = {
	["tf_taunt_laugh"] = true,
	["tf_taunt_conga_start"] = true,
	["tf_taunt_russian_start"] = true,
	["tf_taunt_squaredance_intro"] = true,
	["tf_taunt_rockpaperscissors_intro"] = true,
	["tf_taunt_flipping_intro"] = true,
	["tf_taunt_highfive"] = true,
	["tf_taunt_highfive_success"] = true,
	["tf_taunt_highfive_fail"] = true,
	["tf_taunt_skullcracker"] = true,
	["tf_taunt_moped"] = true,
}

local function resolveTauntCommandForItem(item)
	if not istable(item) then return nil end
	local defindex = tonumber(item.id)
	if defindex and istable(tauntCommandByDefindex) and isstring(tauntCommandByDefindex[defindex]) then
		return tauntCommandByDefindex[defindex]
	end
	local mappedCmd = commandFromItemToken(item)
	if itemHasSchemaTaunt(item) and (not isstring(mappedCmd) or mappedCmd == "" or string.StartWith(mappedCmd, "tf_taunt_token ") or not specialManualTauntCommands[mappedCmd]) then
		if defindex then
			return "tf_taunt_schema " .. tostring(defindex)
		end
	end
	if isstring(mappedCmd) and mappedCmd ~= "" then
		return mappedCmd
	end
	if isLikelyTauntItem(item) then
		local rawCandidates = {
			item.item_name,
			item.name,
			item.item_type_name,
			tf_lang and tf_lang.GetRaw and tf_lang.GetRaw(item.item_name) or nil,
			tf_lang and tf_lang.GetRaw and tf_lang.GetRaw(item.name) or nil,
			tf_lang and tf_lang.GetRaw and tf_lang.GetRaw(item.item_type_name) or nil,
		}
		for _, raw in ipairs(rawCandidates) do
			local token = normalizeTauntToken(raw)
			if token and token ~= "" then
				return tokenCmd(token)
			end
		end
	end
	local blob = getItemTextBlob(item)
	if blob == "" then return nil end
	for _, rule in ipairs(tauntItemCommandRules) do
		for _, token in ipairs(rule.tokens) do
			if string.find(blob, string.lower(token), 1, true) then
				return rule.cmd
			end
		end
	end
	if isLikelyTauntItem(item) then
		return "tf_taunt_laugh"
	end
	return nil
end

local function rebuildTauntCommandDefindexMap()
	local map = {}
	if not tf_items or not tf_items.Items then
		tauntCommandByDefindex = map
		return
	end
	for _, item in pairs(tf_items.Items) do
		if istable(item) then
			local defindex = tonumber(item.id)
			if defindex and not map[defindex] then
				local cmd = resolveTauntCommandForItem(item)
				if isstring(cmd) and cmd ~= "" then
					map[defindex] = cmd
				end
			end
		end
	end
	tauntCommandByDefindex = map
end

local function ensureTauntCommandDefindexMap()
	if tauntCommandByDefindex == nil then
		rebuildTauntCommandDefindexMap()
	end
end

local function runPlayerTauntCommand(ply, cmd)
	if not IsValid(ply) or not isstring(cmd) then return false end
	cmd = string.Trim(cmd)
	if cmd == "" then return false end

	local parts = string.Explode(" ", cmd, false)
	local name = parts[1]
	if not isstring(name) or name == "" then return false end
	table.remove(parts, 1)

	if not concommand or not concommand.Run then return false end
	concommand.Run(ply, name, parts, table.concat(parts, " "))
	return true
end

function meta:TryExecuteEquippedTauntSlot(slotIndex)
	if not SERVER then return false end
	local slot = tonumber(slotIndex)
	if not slot or slot < 1 or slot > 8 then return false end

	local className = tostring(self:GetPlayerClass() or "")
	if className == "" then return false end

	local loadoutRaw = self:GetInfo("loadout_taunts_" .. className)
	if not isstring(loadoutRaw) or loadoutRaw == "" then return false end
	local split = string.Split(loadoutRaw, ",")
	local itemId = tonumber(split[slot])
	if not itemId or itemId <= 0 then return false end

	local item = (tf_items and tf_items.ItemsByID and tf_items.ItemsByID[itemId]) or nil
	if not istable(item) and tf_items and tf_items.Items then
		for _, v in pairs(tf_items.Items) do
			if istable(v) and tonumber(v.id) == itemId then
				item = v
				break
			end
		end
	end
	if not istable(item) then return false end

	ensureTauntCommandDefindexMap()
	local cmd = resolveTauntCommandForItem(item)
	if not isstring(cmd) or cmd == "" then
		-- SDK-style slot taunt path: if a taunt item is equipped, consume the request
		-- rather than falling back to weapon taunt.
		if isLikelyTauntItem(item) then
			runPlayerTauntCommand(self, "tf_taunt_laugh")
			return true
		end
		return false
	end

	return runPlayerTauntCommand(self, cmd)
end

function meta:TryExecuteTauntItemByID(itemId, slotIndex)
	if not SERVER then return false end
	local defindex = tonumber(itemId)
	if not defindex or defindex <= 0 then return false end

	local item = (tf_items and tf_items.ItemsByID and tf_items.ItemsByID[defindex]) or nil
	if not istable(item) and tf_items and tf_items.Items then
		for _, v in pairs(tf_items.Items) do
			if istable(v) and tonumber(v.id) == defindex then
				item = v
				break
			end
		end
	end
	if not istable(item) then return false end

	ensureTauntCommandDefindexMap()
	local cmd = resolveTauntCommandForItem(item)
	if not isstring(cmd) or cmd == "" then
		if isLikelyTauntItem(item) then
			cmd = "tf_taunt_laugh"
		else
			return false
		end
	end

	return runPlayerTauntCommand(self, cmd)
end

function meta:TFTaunt(args)
	local ply = self 
	local tauntArg
	if istable(args) then
		tauntArg = tostring(args[1] or "")
	elseif args ~= nil then
		tauntArg = tostring(args)
	else
		tauntArg = ""
	end
	if tauntArg == "" then
		local w = ply:GetActiveWeapon()
		if IsValid(w) and w.GetSlot then
			tauntArg = tostring((w:GetSlot() or 0) + 1)
		end
	end
	if tauntArg == "" then
		tauntArg = "1"
	end
	if SERVER then
		if ply:IsHL2() then ply:SendLua("RunConsoleCommand('act','dance')") return end
		if ply:GetNWBool("Taunting") == true then return end
		if not ply:IsOnGround() then return end
		if ply:WaterLevel() ~= 0 then return end
		
		if IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon().TryActivateViaTaunt then
			if ply:GetActiveWeapon():TryActivateViaTaunt() then
				return
			end
		end

		if ply:GetPlayerClass() == "combinesoldier" then
			EmitSentence( "COMBINE_THROW_GRENADE" .. math.random( 0, 4 ), ply:GetPos(), 1, CHAN_AUTO, 1, 75, 0, 100 )
		end
		--[[if ply:GetInfoNum("tf_robot", 0) == 1 then ply:ChatPrint("You can't taunt as a robot!") return end
		if ply:GetInfoNum("tf_giantrobot", 0) == 1 then ply:ChatPrint("You can't taunt as a mighty robot!") return end]]
		if not table.HasValue(allowedtaunts, tauntArg) then return end
		for k,v in ipairs(ents.FindInSphere(ply:GetPos(), 120)) do
			if v:GetNWBool("IWantToTaunt") ==  true then
				self:SetNWBool("IWantToTauntToo", true)
			end
		end
		if (IsValid(ply:GetActiveWeapon())) then
			if (ply:GetActiveWeapon():GetClass() == "tf_weapon_lunchbox") then
				ply:GetActiveWeapon():PrimaryAttack()
				return
			end
		end
		if ply:GetPlayerClass() != "spy" then
			if table.KeyFromValue(allowedtaunts,tauntArg) == 1 then
		
				if ply:GetWeapons()[1]:GetClass() == "weapon_crowbar" then
				
					ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
					ply:DoAnimationEvent(ACT_GMOD_TAUNT_LAUGH, true)
		
				elseif ply:GetPlayerClass() == "combinesoldier" then
					ply:DoAnimationEvent(ACT_SPECIAL_ATTACK1, true)
					ply:SetNWBool("Taunting", true)
					ply:SetNWBool("NoWeapon", true) 
					local frag = ents.Create("npc_grenade_frag")
					net.Start("ActivateTauntCam")
					net.Send(ply)
					frag:SetPos(ply:EyePos() + ( ply:GetAimVector() * 16 ) )
					frag:SetAngles( ply:EyeAngles() )
					frag:SetOwner(ply)

					timer.Simple(0.6, function()
						frag:Spawn()
						
						local phys = frag:GetPhysicsObject()
							if ( !IsValid( phys ) ) then frag:Remove() return end
							
							
							
							local velocity = ply:GetAimVector()
							velocity = velocity * 1000
							velocity = velocity + ( VectorRand() * 10 ) -- a random element
							phys:ApplyForceCenter( velocity )
							frag:Fire("SetTimer",5,0)
							frag:SetOwner(ply)
							--timer.Simple(3.5,function() frag:Ignite() end)
					end)
					timer.Simple(1.2, function()
						if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
						ply:SetNWBool("Taunting", false)
						ply:SetNWBool("NoWeapon", false)
						--print("Taunt Finished")
						net.Start("DeActivateTauntCam")
						net.Send(ply)
					end)
						
				end
				
				if ply:GetPlayerClass() == "pyro" then
					if ply:GetWeapons()[1]:GetItemData().model_player == "models/weapons/c_models/c_rainblower/c_rainblower.mdl" then
						ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
						ply:DoAnimationEvent(ACT_90_RIGHT, true)
						timer.Simple(3.15, function()
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
								if v:IsTFPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:TakeDamage(500, ply, ply)
								end
							end
						end)
					else
					
						ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
						ply:DoTauntEvent("taunt01", true)		
					end

				elseif ply:GetPlayerClass() == "sniper" then
					if ply:GetWeapons()[1]:GetClass() == "tf_weapon_compound_bow" then
						ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
						ply:DoAnimationEvent(ACT_DOD_CROUCH_IDLE_PISTOL, true)
						ply:SetNWBool("Taunting", true)
						ply:SetNWBool("NoWeapon", true)
						ply:GetActiveWeapon().NameOverride = "taunt_sniper" 
						timer.Simple(0.8, function()
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
								if v:IsTFPlayer() and not v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:TakeDamage(50, ply, ply)
								elseif v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:ConCommand("tf_stun_me")
									v:TakeDamage(50, ply, ply)
								end
							end
						end)
						timer.Simple(2.3, function()
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
								if v:IsTFPlayer() and not v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:TakeDamage(500, ply, ply)
								elseif v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:TakeDamage(500, ply, ply)
								end
							end
						end)
					else					
						ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
						ply:DoTauntEvent("taunt01", true)
					end
				elseif ply:GetPlayerClass() == "heavy" then
					ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
					ply:DoTauntEvent("taunt01", true)
				elseif ply:GetPlayerClass() == "medic" then		
					ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
					ply:DoTauntEvent("taunt01", true)
				elseif ply:GetPlayerClass() == "soldier" then
					
					if ply:GetWeapons()[1]:GetClass() == "tf_weapon_rocketlauncher_dh" then
						ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
						ply:DoAnimationEvent(ACT_DOD_RELOAD_DEPLOYED, true)	
					else
						ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
						ply:DoTauntEvent("taunt01", true)	
					end
				
				elseif ply:GetPlayerClass() == "demoman" then
					if ply:GetWeapons()[1]:GetClass() == "tf_weapon_grenadelauncher" then
						ply:PlayScene("scenes/player/demoman/low/taunt08.vcd")
						ply:DoTauntEvent("taunt02", true)
						ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
					else
						ply:DoAnimationEvent(ACT_DOD_CROUCHWALK_AIM_MP40, true)
						ply:DoTauntEvent("taunt02", true)
						ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())				
					end
				elseif ply:GetPlayerClass() == "engineer" then
					if ply:GetWeapons()[1]:GetClass() == "tf_weapon_sentry_revenge" then
						ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
						ply:DoAnimationEvent(ACT_DOD_RELOAD_DEPLOYED, true)
						ply:PlayScene("scenes/player/engineer/low/taunt07.vcd")
						ply:SetNWBool("Taunting", true)
						ply:SetNWBool("NoWeapon", true)
						ply:GetActiveWeapon().NameOverride = "taunt_guitar_kill"
						local animent2 = ents.Create( 'base_gmodentity' ) -- The entity used for the death animation	
						animent2:SetModel("models/player/items/engineer/guitar.mdl") 
						animent2:SetAngles(ply:GetAngles())
						animent2:SetPos(ply:GetPos())
						animent2:Spawn()
						animent2:Activate()
						animent2:SetParent(ply)
						animent2:AddEffects(EF_BONEMERGE)
						animent2:SetName("GuitarModel"..ply:EntIndex())
						timer.Simple(4.2, function()
							if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
							ply:SetNWBool("Taunting", false)
							ply:SetNWBool("NoWeapon", false)
							--print("Taunt Finished")
							net.Start("DeActivateTauntCam")
							net.Send(ply)
							animent2:Fire("Kill", "", 0.1)
						end)
						timer.Simple(3.7, function()
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
								if v:IsNPC() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:TakeDamage(500, ply, ply)
								elseif v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:TakeDamage(500, ply, ply)
								end
							end
						end)
					else					
						ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
						ply:DoTauntEvent("taunt01", true)
					end
				else
				
					ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
					ply:DoTauntEvent("taunt01", true)
					
				end
			elseif table.KeyFromValue(allowedtaunts,tauntArg) == 2 then
		
				if ply:GetPlayerClass() == "combinesoldier" then
					ply:DoAnimationEvent(ACT_SPECIAL_ATTACK1, true)
					ply:SetNWBool("Taunting", true)
					ply:SetNWBool("NoWeapon", true) 
					local frag = ents.Create("npc_grenade_frag")
					net.Start("ActivateTauntCam")
					net.Send(ply)
					frag:SetPos(ply:EyePos() + ( ply:GetAimVector() * 16 ) )
					frag:SetAngles( ply:EyeAngles() )
					frag:SetOwner(ply)
					timer.Simple(0.6, function()
						frag:Spawn()
						
						local phys = frag:GetPhysicsObject()
							if ( !IsValid( phys ) ) then frag:Remove() return end
							
							
							
							local velocity = ply:GetAimVector()
							velocity = velocity * 1000
							velocity = velocity + ( VectorRand() * 10 ) -- a random element
							phys:ApplyForceCenter( velocity )
							frag:Fire("SetTimer",5,0)
							frag:SetOwner(ply)
							--timer.Simple(3.5,function() frag:Ignite() end)
					end)
					timer.Simple(1.2, function()
						if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
						ply:SetNWBool("Taunting", false)
						ply:SetNWBool("NoWeapon", false)
						--print("Taunt Finished")
						net.Start("DeActivateTauntCam")
						net.Send(ply)
					end)
						

				elseif ply:GetPlayerClass() == "demoman" then
					if ply:GetWeapons()[2]:GetItemData().model_player == "models/weapons/c_models/c_scottish_resistance/c_scottish_resistance.mdl" then
						ply:SelectWeapon(ply:GetWeapons()[2]:GetClass())
						ply:DoTauntEvent("taunt08", true)
					else
						ply:SelectWeapon(ply:GetWeapons()[2]:GetClass())
						ply:DoTauntEvent("taunt01", true)
					end
				elseif ply:GetPlayerClass() == "soldier" then
					ply:SelectWeapon(ply:GetWeapons()[2]:GetClass())
					ply:DoTauntEvent("taunt04", true)
				elseif ply:GetPlayerClass() == "pyro" then
					if ply:GetWeapons()[2]:GetClass() == "tf_weapon_flaregun" then
						ply:SelectWeapon(ply:GetWeapons()[2]:GetClass())
						ply:DoTauntEvent("taunt_scorch_shot", true)
						timer.Simple(2, function()
							ply:GetWeapons()[2]:PrimaryAttack()
							ply:GetWeapons()[2]:ShootEffects()
						end)
						timer.Simple(4, function()
							if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
							ply:SetNWBool("Taunting", false)
							ply:SetNWBool("NoWeapon", false)
							--print("Taunt Finished")
							net.Start("DeActivateTauntCam")
							net.Send(ply)
						end)
					else
						ply:GetActiveWeapon().NameOverride = "taunt_pyro"
						timer.Simple(1.8, function()
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
								if v:IsTFPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									GAMEMODE:IgniteEntity(v, ply:GetActiveWeapon(), ply, 10)
								end
							end
						end)
						timer.Simple(2, function()
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
								if v:IsTFPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:TakeDamage(500, ply, ply)
								end
							end
						end)
					
					ply:SelectWeapon(ply:GetWeapons()[2]:GetClass())
					ply:DoTauntEvent("taunt02", true)
					
					end
				else
					
					ply:SelectWeapon(ply:GetWeapons()[2]:GetClass())
					ply:DoTauntEvent("taunt02", true)
				end
			elseif table.KeyFromValue(allowedtaunts,tauntArg) == 3 then	
				if ply:GetPlayerClass() == "pyro" then
					if ply:GetWeapons()[3]:GetClass() == "tf_weapon_neonsign" then
						ply:EmitSound("player/sign_bass_solo.wav", 95, 100)
						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
						ply:DoTauntEvent("taunt03", true)
					elseif ply:GetWeapons()[3]:GetItemData().model_player == "models/weapons/c_models/c_lollichop/c_lollichop.mdl" then
						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
						ply:DoAnimationEvent(ACT_COVER_MED, true)
					else
						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
						ply:DoTauntEvent("taunt03", true)
					end
				elseif ply:GetPlayerClass() == "soldier" then
					if ply:GetWeapons()[3]:GetClass() == "tf_weapon_katana" then
						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
						ply:DoAnimationEvent(ACT_DOD_RELOAD_DEPLOYED, true)	
					elseif ply:GetWeapons()[3]:GetClass() == "tf_weapon_pickaxe" then
						ply:GetWeapons()[3].NameOverride = "taunt_soldier"
						timer.Simple(3.5, function()
							if !ply:Alive() then return end
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
								if v:IsNPC() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									local d = DamageInfo()
									d:SetDamage( v:Health() )
									d:SetAttacker( ply )
									d:SetInflictor( ply:GetWeapons()[3] )
									d:SetDamageType( DMG_BLAST )
									v:TakeDamageInfo( d )
									v:EmitSound("TF_BaseExplosionEffect.Sound")
								elseif v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									local d = DamageInfo()
									d:SetDamage( v:Health() )
									d:SetAttacker( ply )
									d:SetInflictor( ply:GetWeapons()[3] )
									d:SetDamageType( DMG_BLAST )
									v:TakeDamageInfo( d )
									v:EmitSound("TF_BaseExplosionEffect.Sound")
								end
							end
							timer.Simple(0.3, function()
							
								ply:EmitSound("TF_BaseExplosionEffect.Sound")
								local dmg = DamageInfo()
								dmg:SetDamage( ply:Health() )
								dmg:SetAttacker( ply )
								dmg:SetInflictor( ply:GetWeapons()[3] )
								dmg:SetDamageType( DMG_BLAST )
								ply:TakeDamageInfo( dmg )
							end)
						end)
						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
						ply:DoAnimationEvent(ACT_COVER_LOW, true)
					else
						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
						ply:DoTauntEvent("taunt03", true)
					end
				elseif ply:GetPlayerClass() == "heavy" then
					if (ply:GetActiveWeapon():GetItemData() and ply:GetActiveWeapon():GetItemData().item_type_name and ply:GetActiveWeapon():GetItemData().item_type_name == "#TF_Weapon_Gloves") then
						ply:DoAnimationEvent(ACT_DOD_IDLE_ZOOMED,true)
						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
					else
						ply:GetActiveWeapon().NameOverride = "taunt_heavy"
						timer.Simple(1.7, function()
							local dmginfo = DamageInfo()
							dmginfo:SetDamageType(DMG_BULLET)
							dmginfo:SetAttacker(ply)
							dmginfo:SetInflictor(ply)
							dmginfo:SetDamage(500)
							dmginfo:SetDamageForce(ply:GetAimVector() * 800 + Vector(0,0,100))
							if ply:GetEyeTrace().Entity:IsNPC() and not ply:GetEyeTrace().Entity:IsFriendly(ply) then
								ply:GetEyeTrace().Entity:TakeDamageInfo(dmginfo)
							elseif ply:GetEyeTrace().Entity:IsPlayer() and not ply:GetEyeTrace().Entity:IsFriendly(ply) then
								ply:GetEyeTrace().Entity:TakeDamageInfo(dmginfo)
							end
						end)	
					
						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
						ply:DoTauntEvent("taunt03", true)
					end
				elseif ply:GetPlayerClass() == "scout" then
					if ply:GetWeapons()[3]:GetClass() == "tf_weapon_bat_wood" then
						ply:GetActiveWeapon().NameOverride = "taunt_scout"
						timer.Simple(4.2, function()
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
								if v:IsTFPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:TakeDamage(500, ply, ply)
									v:EmitSound("player/pl_impact_stun_range.wav", 95)
								end
							end
						end)
						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
						ply:DoAnimationEvent(ACT_COVER_LOW, true)
					else
						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
						ply:DoTauntEvent("taunt03", true)
					end
				elseif ply:GetPlayerClass() == "medic" then
					timer.Simple(0.3, function()
					if ply:GetWeapons()[3]:GetItemData().model_player == "models/workshop/weapons/c_models/c_uberneedle/c_uberneedle.mdl" then
						ply:EmitSound("Taunt.MedicViolinUber")
					elseif ply:GetWeapons()[3]:GetItemData().model_player != "models/weapons/c_models/c_ubersaw/c_ubersaw.mdl" then
						ply:EmitSound("Taunt.MedicViolin")
					end
					end)
					ply:DoTauntEvent("taunt03", true)
					if ply:GetWeapons()[3]:GetItemData().model_player == "models/weapons/c_models/c_ubersaw/c_ubersaw.mdl" then
						timer.Simple(2, function()
							ply:GetActiveWeapon().NameOverride = "taunt_medic"
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
								if v:IsTFPlayer() and not v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									local d = DamageInfo()
									d:SetDamage( 1 )
									d:SetAttacker( ply )
									d:SetInflictor( ply:GetActiveWeapon() )
									d:SetDamageType( DMG_BULLET )
									v:TakeDamage( d )
								elseif v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									local d = DamageInfo()
									d:SetDamage( 50 )
									d:SetAttacker( ply )
									d:SetInflictor( ply:GetActiveWeapon() )
									d:SetDamageType( DMG_BULLET )
									v:TakeDamageInfo( d )
									v:ConCommand("tf_stun_me")
								end
							end
						end)

						timer.Simple(2.89, function()
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
								if v:IsTFPlayer() and not v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									local d = DamageInfo()
									d:SetDamage( 500 )
									d:SetAttacker( ply )
									d:SetInflictor( ply:GetActiveWeapon() )
									d:SetDamageType( DMG_BULLET )
									v:TakeDamageInfo( d )
								elseif v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									local d = DamageInfo()
									d:SetDamage( 500 )
									d:SetAttacker( ply )
									d:SetInflictor( ply:GetActiveWeapon() )
									d:SetDamageType( DMG_BULLET )
									v:TakeDamageInfo( d )
								end
							end
						end)
						ply:DoTauntEvent("taunt08", true)
						ply:PlayScene("scenes/player/medic/low/taunt08.vcd")
						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())

					end
				elseif ply:GetPlayerClass() == "engineer" then
						
					if ply:GetWeapons()[3]:GetClass() == "tf_weapon_robot_arm" then

						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
						ply:DoAnimationEvent(ACT_DOD_STAND_AIM_KNIFE, true)


						timer.Simple(3.3, function()
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
								if v:IsTFPlayer() and not v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:TakeDamage(50, ply, ply)
								elseif v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:ConCommand("tf_stun_me")
									v:TakeDamage(50, ply, ply)
								end
							end
						end)
						timer.Simple(4.0, function()
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
								if v:IsTFPlayer() and not v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:TakeDamage(500, ply, ply)
								elseif v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:TakeDamage(500, ply, ply)
								end
							end
						end)
						timer.Simple(3.31, function()
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
								if v:IsTFPlayer() and not v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:TakeDamage(1, ply, ply)
								elseif v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:TakeDamage(1, ply, ply)
								end
							end
							timer.Simple(0.1, function()
								for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
									if v:IsTFPlayer() and not v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
										v:TakeDamage(1, ply, ply)
									elseif v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
										v:TakeDamage(1, ply, ply)
									end
								end
								timer.Simple(0.1, function()
									for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
										if v:IsTFPlayer() and not v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
											v:TakeDamage(1, ply, ply)
										elseif v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
											v:TakeDamage(1, ply, ply)
										end
									end
									timer.Simple(0.1, function()
										for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
											if v:IsTFPlayer() and not v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
												v:TakeDamage(1, ply, ply)
											elseif v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
												v:TakeDamage(1, ply, ply)
											end
										end
										timer.Simple(0.1, function()
											for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
												if v:IsTFPlayer() and not v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
													v:TakeDamage(1, ply, ply)
												elseif v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
													v:TakeDamage(1, ply, ply)
												end
											end
											timer.Simple(0.1, function()
												for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
													if v:IsTFPlayer() and not v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
														v:TakeDamage(1, ply, ply)
													elseif v:IsPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
														v:TakeDamage(1, ply, ply)
													end
												end
											end)
										end)
									end)
								end)
							end)
						end)

					else
						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
						ply:DoTauntEvent("taunt03", true)
					end

				elseif ply:GetPlayerClass() == "demoman" then
					if ply:GetWeapons()[3]:GetClass() == "tf_weapon_sword" or ply:GetWeapons()[3]:GetClass() == "tf_weapon_katana" then
						ply:GetActiveWeapon().NameOverride = "taunt_demoman"
						timer.Simple(2.5, function()
							for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
								if v:IsTFPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
									v:AddDeathFlag(DF_DECAP)
									v:TakeDamage(500, ply, ply)
								end
							end
						end)
						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
						ply:DoAnimationEvent(ACT_DOD_STAND_AIM_KNIFE, true)
					else
						ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
						ply:DoTauntEvent("taunt03", true)
					end
				else
					
					ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
					ply:DoTauntEvent("taunt03", true)
					
				end
			end
			
		else
			if table.KeyFromValue(allowedtaunts,tauntArg) == 1 then
				ply:SelectWeapon(ply:GetWeapons()[1]:GetClass())
				ply:DoTauntEvent("taunt01", true)
			elseif table.KeyFromValue(allowedtaunts,tauntArg) == 3 then
				timer.Simple(2, function()
					for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
						if v:IsTFPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
							v:TakeDamage(10, ply, ply)
							ply:GetActiveWeapon().NameOverride = "taunt_spy"
						end
					end
				end)		
				timer.Simple(2.5, function()
					for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
						if v:IsTFPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
							v:TakeDamage(10, ply, ply)
							ply:GetActiveWeapon().NameOverride = "taunt_spy"
						end
					end
				end)	
				timer.Simple(4, function()
					for k,v in pairs(ents.FindInSphere(ply:GetPos(), 90)) do 
						if v:IsTFPlayer() and not v:IsFriendly(ply) and v:EntIndex() != ply:EntIndex() then
							v:TakeDamage(500, ply, ply)
							ply:GetActiveWeapon().NameOverride = "taunt_spy"
						end
					end
				end)			
				ply:SelectWeapon(ply:GetWeapons()[2]:GetClass())
				ply:DoTauntEvent("taunt03", true)
			elseif table.KeyFromValue(allowedtaunts,tauntArg) == 4 then
				ply:SelectWeapon(ply:GetWeapons()[3]:GetClass())
				ply:DoTauntEvent("taunt04", true)
			elseif ply:GetActiveWeapon():GetClass() == "weapon_physcannon" then
				ply:SelectWeapon("weapon_physcannon")
				ply:DoAnimationEvent(ACT_DOD_HS_CROUCH_KNIFE, true)
			elseif ply:GetActiveWeapon():GetClass() == "weapon_physgun" then
				ply:SelectWeapon("weapon_physgun")
				ply:DoAnimationEvent(ACT_DOD_HS_CROUCH_KNIFE, true)
			end		
		end
		ply:Speak("TLK_PLAYER_TAUNT")
		ply:SetNWBool("Taunting", true)
		ply:SetLocalVelocity(Vector(0,0,0))
		if IsValid(ply:GetActiveWeapon()) and table.HasValue(wep, ply:GetActiveWeapon():GetClass()) then ply:SetNWBool("NoWeapon", true) end
		net.Start("ActivateTauntCam")
		net.Send(ply)
		
		if ply:GetPlayerClass() != "combinesoldier" then
			--print(ply:GetNWBool("SpeechTime"))
			timer.Simple(ply:GetNWBool("SpeechTime"), function()
				if not IsValid(ply) or (not ply:Alive() and not ply:GetNWBool("Taunting")) then return end
				ply:SetNWBool("Taunting", false)
				ply:SetNWBool("NoWeapon", false)
				--print("Taunt Finished")
				net.Start("DeActivateTauntCam")
				net.Send(ply)
				if !ply:IsHL2() then
					ply:GetActiveWeapon().NameOverride = ply:GetActiveWeapon():GetItemData().item_iconname
				end
			end)
		end
	end
end
function meta:Decap()
	self.ShouldGib = true
	if self:IsHL2() then
		umsg.Start("GibNPCHead")
			umsg.Entity(self)
			umsg.Short(self.DeathFlags)
		umsg.End()
	else
		umsg.Start("GibPlayerHead")
			umsg.Entity(self)
			umsg.Short(self.DeathFlags)
		umsg.End()
	end
end


function meta:SetBuilding(group, mode)
	local buildings = self.Buildings
	if not buildings or not buildings[group] or not buildings[group][mode] then
		return false
	end
	local cost = tonumber(buildings[group][mode].cost or 0) or 0
	if self:GetAmmoCount(TF_METAL) < cost then
		return false
	end

	local builder = self:GetWeapon("tf_weapon_builder")
	if not IsValid(builder) then
		self:GiveItem("TF_WEAPON_BUILDER")
		builder = self:GetWeapon("tf_weapon_builder")
		if not IsValid(builder) then
			return false
		end
	end

	builder.dt.BuildGroup = group
	builder.dt.BuildMode = mode
	if builder.SetupBuilding then
		builder:SetupBuilding(buildings[group][mode])
	end
	return true
end

function meta:SetBuilding2(group, mode)
	if self.Buildings[group] and self.Buildings[group][mode] then
		self.dt.BuildGroup = group
		self.dt.BuildMode = mode
		return true
	end
end

local old_group_translate = {
	[0] = {0,0},
	[1] = {1,0},
	[2] = {1,1},
	[3] = {2,0},
	[4] = {3,0},
}

local function CountOwnedSentries(ply)
	local regular = 0
	local disposable = 0
	for _, ent in ipairs(ents.FindByClass("obj_sentrygun")) do
		if not IsValid(ent) then continue end
		if ent:GetOwner() ~= ply and ent:GetBuilder() ~= ply and ent.Player ~= ply then continue end
		if ent.TF_MVM_DisposableSentry then
			disposable = disposable + 1
		else
			regular = regular + 1
		end
	end
	return regular, disposable
end

local function IsOwnedEngineerBuilding(ent, ply)
	if not IsValid(ent) or not IsValid(ply) then return false end
	return ent.Player == ply or ent:GetBuilder() == ply or ent:GetOwner() == ply
end

function TF_IsOwnedEngineerBuilding(ent, ply)
	return IsOwnedEngineerBuilding(ent, ply)
end

function TF_CountOwnedSentries(ply)
	return CountOwnedSentries(ply)
end

-- Canonical TF2 build-limit baseline check for Engineer objects.
-- Custom systems can layer on top, but all core build paths should pass through here.
function TF_CanPlayerBuildObject(ply, group, sub, ignoreUnlimited)
	group = tonumber(group)
	sub = tonumber(sub) or 0
	if not IsValid(ply) or not group then return false end

	if not ignoreUnlimited then
		local cv = GetConVar("tf_unlimited_buildings")
		if cv and cv:GetBool() then
			return true
		end
	end

	local className = builds[group]
	if not className then
		return true
	end

	if className == "obj_sentrygun" then
		local disposableLimit = 0
		if ply.TF_MVM_Dynamic then
			disposableLimit = math.max(0, math.floor(tonumber(ply.TF_MVM_Dynamic.DisposableSentryCount) or 0))
		end
		local regularCount, disposableCount = CountOwnedSentries(ply)
		local allowDisposable = disposableLimit > 0 and regularCount >= 1 and disposableCount < disposableLimit
		return regularCount < 1 or allowDisposable
	end

	if className == "obj_teleporter" then
		for _, ent in ipairs(ents.FindByClass("obj_teleporter")) do
			if not IsOwnedEngineerBuilding(ent, ply) then continue end
			if (sub == 0 and ent.IsEntrance and ent:IsEntrance()) or (sub == 1 and ent.IsExit and ent:IsExit()) then
				return false
			end
		end
		return true
	end

	if className == "obj_dispenser" then
		for _, ent in ipairs(ents.FindByClass("obj_dispenser")) do
			if IsOwnedEngineerBuilding(ent, ply) then
				return false
			end
		end
		return true
	end

	return true
end

function meta:Build(number1,number2)
	local group = tonumber(number1)
	local sub = tonumber(number2)
	if not group then return false end
	if not sub then
		if not old_group_translate[group] then return false end
		group, sub = unpack(old_group_translate[group])
	end

	local builder = self:GetWeapon("tf_weapon_builder")
	if not IsValid(builder) then
		self:GiveItem("TF_WEAPON_BUILDER")
		builder = self:GetWeapon("tf_weapon_builder")
	end
	if not IsValid(builder) then return false end

	if not TF_CanPlayerBuildObject(self, group, sub, false) then
		self:EmitSound("Player.DenyWeaponSelection")
		return false
	end

	builder:SetHoldType("BUILDING")
	builder.HoldType = "BUILDING"
	builder.Moving = false

	local current = self:GetActiveWeapon()
	if not self:SetBuilding(group, sub) then
		self:EmitSound("Player.DenyWeaponSelection")
		return false
	end

	if IsValid(current) and current.IsPDA then
		local last = self:GetWeapon(self.LastWeapon)
		if not IsValid(last) or last.IsPDA then
			last = self:GetWeapons()[1]
		end
		if IsValid(last) then
			builder.LastWeapon = last:GetClass()
			self:SelectWeapon(last:GetClass())
		end
	elseif IsValid(current) then
		builder.LastWeapon = current:GetClass()
	end

	self:SelectWeapon("tf_weapon_builder")
	return true
end
 
end
function meta:Move(number1,number2)
	local group = tonumber(number1)
	local sub = tonumber(number2) 
	if not group then return false end
	if not sub then
		if not old_group_translate[group] then return false end
		group, sub = unpack(old_group_translate[group])
	end

	local builder = self:GetWeapon("tf_weapon_builder")
	if not IsValid(builder) then
		self:GiveItem("TF_WEAPON_BUILDER")
		builder = self:GetWeapon("tf_weapon_builder")
	end
	
	if not IsValid(builder) then return false end
	
	builder:SetHoldType("BUILDING_DEPLOYED")
	builder.HoldType = "BUILDING_DEPLOYED"
	
	local current = self:GetActiveWeapon()
	if builder:SetBuilding2(group, sub) and (not IsValid(current) or current ~= builder) then
		if IsValid(current) and current.IsPDA then
			local last = self:GetWeapon(self.LastWeapon)
			if not IsValid(last) or last.IsPDA then
				last = self:GetWeapons()[1]
			end
			builder.LastWeapon = last:GetClass()
			self:SelectWeapon(last:GetClass())
		elseif IsValid(current) then
			builder.LastWeapon = current:GetClass()
		end
		self:SelectWeapon("tf_weapon_builder")
		builder.Moving = true
		return true
	end
	self:EmitSound("Player.DenyWeaponSelection")
	return false
end

function meta:DestroyBuilding(number1, number2)
	local group = tonumber(number1)
	local sub = tonumber(number2)
	if group == nil then return false end
	if sub == nil then
		local mapped = old_group_translate[group]
		if not mapped then
			return false
		end
		group, sub = mapped[1], mapped[2]
	end
	local destroyed = false

	if group == 2 and sub == 0 then
		for _, v in pairs(ents.FindByClass("obj_sentrygun")) do
			if IsOwnedEngineerBuilding(v, self) then
				v:Explode()
				destroyed = true
			end
		end
	end
	if group == 0 and sub == 0 then
		for _, v in pairs(ents.FindByClass("obj_dispenser")) do
			if IsOwnedEngineerBuilding(v, self) then
				v:Explode()
				destroyed = true
			end
		end
	end
	if group == 1 and sub == 0 then
		for _, v in pairs(ents.FindByClass("obj_teleporter")) do
			if IsOwnedEngineerBuilding(v, self) and v:IsExit() ~= true then
				v:Explode()
				destroyed = true
			end
		end
	end
	if group == 1 and sub == 1 then
		for _, v in pairs(ents.FindByClass("obj_teleporter")) do
			if IsOwnedEngineerBuilding(v, self) and v:IsExit() ~= false then
				v:Explode()
				destroyed = true
			end
		end
	end

	-- Valve flow parity: return to build context after a successful destroy.
	if destroyed and self:GetPlayerClass() == "engineer" then
		timer.Simple(0, function()
			if not IsValid(self) then return end
			local buildPDA = self:GetWeapon("tf_weapon_pda_engineer_build")
			if IsValid(buildPDA) then
				self:SelectWeapon("tf_weapon_pda_engineer_build")
				return
			end
			local builder = self:GetWeapon("tf_weapon_builder")
			if IsValid(builder) then
				self:SelectWeapon("tf_weapon_builder")
			end
		end)
	end

	return destroyed
end

function meta:RandomSentence(group)
	
	local class = self.playerclass
	if not class then return end
	
	--[[local tbl = class.Sounds[group]
	self:EmitSound(tbl[math.random(1,#tbl)])]]
	self:EmitSoundEx(Format("%s.%s", class, group))
end

function meta:StripTFItems()
	self:StripWeapons()
	self:StripAmmo()
	
	if self.PlayerItemList then
		for _,v in ipairs(self.PlayerItemList) do
			v:Remove()
		end
	end
end

function meta:StripHats()
	for _,v in pairs(ents.FindByClass("tf_hat")) do
		if v:GetOwner() == self then
			v:Remove()
		end
	end
	
	for i=1,10 do
		self:SetBodygroup(i,0)
	end
end

function meta:GiveTFAmmo(c, am, is_fraction)
	if c==0 then return end
	
	if not self.AmmoMax then
		if c>0 then
			return self:GiveAmmo(c, am)
		else
			return self:RemoveAmmo(-c, am)
		end
	end
	
	local a = self:GetAmmoCount(am)
	
	if is_fraction then
		if c ~= nil and not self:IsHL2() then
			c = math.ceil(c * self.AmmoMax[am])
		else
			c = 0
		end
	end
	
	if c>0 then
		c = math.min(self.AmmoMax[am] - a, c)
		if c>0 then
			self:GiveAmmo(c, am)
			if am == TF_METAL then
				umsg.Start("PlayerMetalBonus", self)
					umsg.Short(c)
				umsg.End()
			end
			return true
		end
	else
		self:RemoveAmmo(-c, am)
		if am == TF_METAL then
			umsg.Start("PlayerMetalBonus", self)
				umsg.Short(-c)
			umsg.End()
		end
	end
	
	return false
end

function meta:SetAmmoCount(c, am)
	local a = self:GetAmmoCount(am)
	
	if c > a then
		self:GiveAmmo(c - a, am)
	elseif c < a then
		self:RemoveAmmo(a - c, am)
	end
end

function meta:HasFullAmmo()
	for k,v in pairs(self.AmmoMax or {}) do
		if self:GetAmmoCount(k) < v then
			return false
		end
	end
	return true
end

function meta:ResetAttributes()
	local c = self:GetPlayerClassTable()
	
	self.TempAttributes = {}
	self:ResetClassSpeed(c.Speed or 100)
	self:ResetMaxHealth()
	self.AmmoMax = table.Copy(c.AmmoMax or {})
end

-- Shared

--[[function meta:GetCrouchedWalkSpeed()
	return self:GetNWFloat("CrouchedWalkSpeed")
end

function meta:GetWalkSpeed()
	return 1
end

function meta:GetRunSpeed()
	return 1
end

function meta:GetDuckSpeed()
	return self:GetNWFloat("TimeToDuck")
end

function meta:GetUnDuckSpeed()
	return self:GetNWFloat("TimeToUnDuck")
end]]

function meta:IsHL2()
	return self:GetNWBool("IsHL2")
end

function meta:ShouldUseDefaultHull()
	if self ~= nil then
		if GetConVar("tf_use_hl_hull_size") then
			return self:GetNWBool("IsHL2") or self:GetNWBool("IsL4D") or GetConVar("tf_use_hl_hull_size"):GetInt() == 1
		end
	end
end

function meta:GetTFItems()
	local t = self:GetWeapons()
	if self.PlayerItemList then
		table.Add(t, self.PlayerItemList)
	end
	return t
end

function meta:HasTFItem(name)
	if not name then return false end
	
	for _,v in ipairs(self:GetTFItems()) do
		if v.IsTFItem and v:GetItemData().name == name then
			return true
		end
	end
	
	return false
end

--[[
if CLIENT then

usermessage.Hook("SendWeaponAnim", function(msg)
	local act = msg:ReadShort()
	local seq = GAMEMODE.Viewmodels[1][2]:SelectWeightedSequence(act)
	if seq>=0 then
		GAMEMODE.Viewmodels[1][2]:ResetSequence(seq)
		GAMEMODE.Viewmodels[1][2]:SetCycle(0)
	end
end)

end

meta.SendWeaponAnim0 = meta.SendWeaponAnim

function meta:SendWeaponAnim(act)
	self:SendWeaponAnim0(act)
	
	if SERVER then
		umsg.Start("SendWeaponAnim", self)
			umsg.Short(act)
		umsg.End()
	else
		local seq = GAMEMODE.Viewmodels[1][2]:SelectWeightedSequence(act)
		if seq>=0 then
			GAMEMODE.Viewmodels[1][2]:ResetSequence(seq)
			GAMEMODE.Viewmodels[1][2]:ResetSequenceInfo()
		end
	end
end
]]

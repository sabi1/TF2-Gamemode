if CLIENT then return end

--[[LEADBOT STANDALONE V1.0_DEV by Lead]]--
--[["For epic developers who don't have friends to play with. 😎"]]--
--[[ONLY MEAN TO BE USED WITHIN Team Fortress 2 Gamemode Dev!!!]]--

-- secret note: kern is loved.
local profiles = {}
local bots = {} 

--local names = {"LeadKiller", "A Random Person", "Foxie117", "G.A.M.E.R v24", "Agent Agrimar"}
local names = {

		"Chucklenuts",
		"CryBaby",
		"WITCH",
		"ThatGuy",
		"Still Alive",
		"Hat-Wearing MAN",
		"Me",
		"Numnutz", 
		"H@XX0RZ",
		"The G-Man",
		"Chell",
		"The Combine",
		"Totally Not A Bot",
		"Pow!",
		"Zepheniah Mann",
		"THEM",
		"LOS LOS LOS",
		"10001011101",
		"DeadHead",
		"ZAWMBEEZ",
		"MindlessElectrons",
		"TAAAAANK!",
		"The Freeman",
		"Black Mesa",
		"Soulless",
		"CEDA",
		"BeepBeepBoop",
		"NotMe",
		"CreditToTeam",
		"BoomerBile",
		"Someone Else",
		"Mann Co.",
		"Dog",
		"Kaboom!",
		"AmNot",
		"0xDEADBEEF",
		"HI THERE",
		"SomeDude",
		"GLaDOS",
		"Hostage",
		"Headful of Eyeballs",
		"CrySomeMore",
		"Aperture Science Prototype XR7",
		"Humans Are Weak",
		"AimBot",
		"C++",
		"GutsAndGlory!",
		"Nobody",
		"Saxton Hale",
		"RageQuit",
		"Screamin' Eagles",

		"Ze Ubermensch",
		"Maggot",
		"CRITRAWKETS",
		"Herr Doktor",
		"Gentlemanne of Leisure",
		"Companion Cube",
		"Target Practice",
		"One-Man Cheeseburger Apocalypse",
		"Crowbar",
		"Delicious Cake",
		"IvanTheSpaceBiker",
		"I LIVE!",
		"Cannon Fodder",

		"trigger_hurt",
		"Nom Nom Nom",
		"Divide by Zero",
		"GENTLE MANNE of LEISURE",
		"MoreGun",
		"Tiny Baby Man",
		"Big Mean Muther Hubbard",
		"Force of Nature",

		"Crazed Gunman",
		"Grim Bloody Fable",
		"Poopy Joe",
		"A Professional With Standards",
		"Freakin' Unbelievable",
		"SMELLY UNFORTUNATE",
		"The Administrator",
		"Mentlegen",

		"Archimedes!",
		"Ribs Grow Back",
		"It's Filthy in There!",
		"Mega Baboon",
		"Kill Me",
		"Glorified Toaster with Legs",

		"John Spartan",
		"Leeloo Dallas Multipass",
		"Sho'nuff",
		"Bruce Leroy",
		"CAN YOUUUUUUUUU DIG IT?!?!?!?!",
		"Big Gulp, Huh?",
		"Stupid Hot Dog",
		"I'm your huckleberry",
		"The Crocketeer",
}
local public_usernames = {
	"steamRunner",
	"sodaCrate",
	"aimlessWizard",
	"pixelStinger",
	"rocketMailbox",
	"crispyToaster",
	"fragNoodle",
	"rustyPistol",
	"cupcakeReactor",
	"boltSnacker",
	"turboBanana",
	"silentMoose",
	"nightValve",
	"glitchCrab",
	"snackLauncher",
	"mangoSector",
	"purpleGnome",
	"zeroPingMaybe",
	"pocketMedic99",
	"lootGoblinTV",
	"unusualHatGuy",
	"foggyDuelist",
	"cableNinja",
	"soapGrenade",
	"retroJugger",
	"jellyScout",
	"teacupSpy",
	"cardboardSniper",
	"altoRobot",
	"graphiteHeavy",
	"luckyDispenser",
	"tinyWrenchKid",
	"donutEngineer",
	"melonPyro",
	"echoDemoman",
	"sideQuestOnly",
	"clutchOrCry",
	"casualLegend",
	"metalSandwich",
	"barrelWizard",
	"zippyMerc",
	"bleedingPixels",
	"stickyTapper",
	"scopeDreams",
	"alphaSentry",
	"mapControl",
	"airblastEnjoyer",
	"payloadCourier",
	"smokeAndDagger",
	"bonkPowered",
	"tinCanTitan",
	"cloudyCrits",
	"rainyRespawn",
	"widgetMedic",
	"coffeeDemoknight",
	"ragdollPilot",
	"duckTapeHero",
	"fragileGenius",
	"patchTuesday",
	"steelPancake",
	"strangeCollector",
	"honkIfSpy",
	"pingPongKing",
	"spawnRoomDJ",
	"cartPusher9000",
	"pyroMainMaybe",
	"tinyTankUnit",
	"ramenGunner",
	"pixelMaverick",
	"overhealBuddy",
	"criticalMiss",
}
local classtbl4d = {"tank_l4d","boomer","boomer","boomer","jockey","charger","charger","spitter","spitter","smoker","hunter"}
local classtb = {"scout", "soldier", "pyro", "demoman", "heavy", "engineer", "medic", "sniper", "spy"}
local bot_class = CreateConVar("tf_bot_keep_class_after_death", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY})
local bot_diff = CreateConVar("tf_bot_difficulty", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, "Sets the difficulty level for the bots. Values are: 0=easy, 1=normal, 2=hard, 3=expert. Default is \"Normal\" (1).")
local bot_respawn = CreateConVar("tf_bot_npc_respawn", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, "Should the NPC bots respawn?")
local tf_bot_notarget = CreateConVar("tf_bot_notarget", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_force_class = CreateConVar("tf_bot_force_class", "", {FCVAR_GAMEDLL})
local tf_bot_melee_only = CreateConVar("tf_bot_melee_only", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY})
local tf_bot_random_names = CreateConVar("tf_bot_random_names", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Randomize bot names from a large username list.")
local tf_bot_public_names = CreateConVar("tf_bot_public_names", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Include public username-style names in the bot name pool.")
local tf_bot_include_legacy_names = CreateConVar("tf_bot_include_legacy_names", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Include classic meme-style bot names in addition to username-style names.")
local tf_bot_name_file = CreateConVar("tf_bot_name_file", "tf_bot_usernames_public.txt", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "DATA file path for additional bot names, one per line.")
local tf_bot_random_loadouts = CreateConVar("tf_bot_random_loadouts", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Randomize bot loadouts on spawn.")
local tf_bot_randomizer_mode = CreateConVar("tf_bot_randomizer_mode", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Ignore class restrictions when randomizing bot loadouts.")
local tf_bot_loadout_mutation_chance = CreateConVar("tf_bot_loadout_mutation_chance", "0.20", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Chance a respawning bot changes one weapon slot in its saved random loadout.")
local tf_bot_loadout_debug = CreateConVar("tf_bot_loadout_debug", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable debug logs for bot loadout randomization.")
local tf_mvm_bot_allow_flag_carrier_to_fight = CreateConVar("tf_mvm_bot_allow_flag_carrier_to_fight", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Allow MvM bomb carrier bots to actively fight instead of prioritizing hatch.")
local tf_bot_ragdoll_drop_boost = CreateConVar("tf_bot_ragdoll_drop_boost", "280", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Additional downward velocity for dead bot ragdolls.")
-- Keep perf CVars defined here because this file is loaded before shared.lua.
local tf_bot_perf_enable = CreateConVar("tf_bot_perf_enable", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_perf_debug = CreateConVar("tf_bot_perf_debug", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_sense_interval = CreateConVar("tf_bot_sense_interval", "0.35", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_objective_interval = CreateConVar("tf_bot_objective_interval", "1.00", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_avoidance_interval = CreateConVar("tf_bot_avoidance_interval", "0.15", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_avoidteammates = CreateConVar("tf_avoidteammates", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable teammate avoidance for bots.")
local tf_avoidteammates_pushaway = CreateConVar("tf_avoidteammates_pushaway", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable push-away steering for bot teammate avoidance.")
local tf_bot_repath_interval = CreateConVar("tf_bot_repath_interval", "2.20", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_nav_budget_ms = CreateConVar("tf_bot_nav_budget_ms", "1.50", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_perf_scale_start = CreateConVar("tf_bot_perf_scale_start", "8", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_perf_scale_max = CreateConVar("tf_bot_perf_scale_max", "5", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_breakable_check_interval = CreateConVar("tf_bot_breakable_check_interval", "0.35", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_perf_hard_threshold = CreateConVar("tf_bot_perf_hard_threshold", "16", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bot count threshold where extra throttling kicks in.")
local tf_bot_perf_hard_multiplier = CreateConVar("tf_bot_perf_hard_multiplier", "1.6", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Extra interval multiplier used above hard threshold.")
local tf_bot_disable_social_look_highload = CreateConVar("tf_bot_disable_social_look_highload", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Disable friendly look-at-me scan when high-load threshold is reached.")
-- Source-inspired vision CVars from tf_bot_vision.cpp.
local tf_bot_choose_target_interval = CreateConVar("tf_bot_choose_target_interval", "0.30", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How often, in seconds, a bot can reselect its target.")
local tf_bot_sniper_choose_target_interval = CreateConVar("tf_bot_sniper_choose_target_interval", "3.0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How often a zoomed sniper bot can reselect its target.")
local tf_bot_vision_range = CreateConVar("tf_bot_vision_range", "6000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Maximum vision range for bot target acquisition.")
local tf_bot_target_lost_time = CreateConVar("tf_bot_target_lost_time", "1.25", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How long bots remember a target after losing line of sight.")
local tf_bot_health_critical_ratio = CreateConVar("tf_bot_health_critical_ratio", "0.30", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Critical health ratio where bots start emergency healing behavior.")
local tf_bot_health_ok_ratio = CreateConVar("tf_bot_health_ok_ratio", "0.80", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "General health ratio where bots may seek healing.")
local tf_bot_health_search_near_range = CreateConVar("tf_bot_health_search_near_range", "1000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Near health search range for healthy bots.")
local tf_bot_health_search_far_range = CreateConVar("tf_bot_health_search_far_range", "2000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Far health search range for hurt bots.")
local tf_bot_ammo_search_range = CreateConVar("tf_bot_ammo_search_range", "5000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Maximum search range for ammo scavenging.")
local tf_bot_retreat_to_cover_range = CreateConVar("tf_bot_retreat_to_cover_range", "1000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Distance budget for retreat-to-cover behavior.")
local tf_bot_wait_in_cover_min_time = CreateConVar("tf_bot_wait_in_cover_min_time", "1.0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Minimum cover wait time during retreat.")
local tf_bot_wait_in_cover_max_time = CreateConVar("tf_bot_wait_in_cover_max_time", "2.0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Maximum cover wait time during retreat.")
local tf_bot_medic_stop_follow_range = CreateConVar("tf_bot_medic_stop_follow_range", "75", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How close medics stay to their primary patient before stopping movement.")
local tf_bot_medic_start_follow_range = CreateConVar("tf_bot_medic_start_follow_range", "250", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Distance where medics begin actively following their patient.")
local tf_bot_medic_max_heal_range = CreateConVar("tf_bot_medic_max_heal_range", "600", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Maximum practical heal beam range for medic behavior.")
local tf_bot_medic_max_call_response_range = CreateConVar("tf_bot_medic_max_call_response_range", "1000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Maximum range for responding to urgent nearby heal needs.")
local tf_bot_sniper_flee_range = CreateConVar("tf_bot_sniper_flee_range", "400", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "If threat is closer than this, sniper retreats.")
local tf_bot_sniper_melee_range = CreateConVar("tf_bot_sniper_melee_range", "200", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "If threat is closer than this, sniper swaps to melee.")
local tf_bot_sniper_linger_time = CreateConVar("tf_bot_sniper_linger_time", "5", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How long sniper lingers after losing target before relocating.")
local tf_bot_sniper_patience_duration = CreateConVar("tf_bot_sniper_patience_duration", "10", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How long sniper waits at a home spot without seeing threats before picking a new one.")
local tf_bot_sniper_allow_opportunistic = CreateConVar("tf_bot_sniper_allow_opportunistic", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Allow snipers to opportunistically engage while moving to home spot.")
local tf_bot_spy_sap_range = CreateConVar("tf_bot_spy_sap_range", "80", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Range where spies commit to sapping enemy buildings.")
local tf_bot_spy_backstab_range = CreateConVar("tf_bot_spy_backstab_range", "150", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Range where spies commit to backstab attempts.")
local tf_bot_spy_lurk_time_min = CreateConVar("tf_bot_spy_lurk_time_min", "3.0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Minimum spy lurk duration before selecting a new hide spot.")
local tf_bot_spy_lurk_time_max = CreateConVar("tf_bot_spy_lurk_time_max", "5.0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Maximum spy lurk duration before selecting a new hide spot.")

local function IsBotForcedMeleeOnly(bot)
	if not IsValid(bot) then return false end
	if tf_bot_melee_only:GetBool() and not string.find(bot:GetModel() or "", "/bots") then
		return true
	end
	return bot.TF_MVM_WeaponRestriction == "meleeonly"
end

local function ForceBotMeleeWeapon(bot)
	if not IsValid(bot) then return false end
	for _, wep in ipairs(bot:GetWeapons()) do
		if IsValid(wep) and wep.IsMeleeWeapon then
			bot:SelectWeapon(wep:GetClass())
			return true
		end
	end
	return false
end

local function CVFloat(cv, fallback)
	if cv and cv.GetFloat then
		return cv:GetFloat()
	end
	return fallback
end

local function CVBool(cv, fallback)
	if cv and cv.GetBool then
		return cv:GetBool()
	end
	return fallback
end

local function IsCrouchNavArea(area)
	if not area then return false end
	local ok, hasCrouch = pcall(function()
		return area:HasAttributes(NAV_MESH_CROUCH)
	end)
	return ok and hasCrouch == true
end

concommand.Add("tf_bot_perf_profile", function(ply, _, args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	local profile = string.lower(tostring(args and args[1] or "max"))
	if profile == "ultra" then
		RunConsoleCommand("tf_bot_sense_interval", "0.45")
		RunConsoleCommand("tf_bot_objective_interval", "1.25")
		RunConsoleCommand("tf_bot_avoidance_interval", "0.22")
		RunConsoleCommand("tf_bot_repath_interval", "2.80")
		RunConsoleCommand("tf_bot_nav_budget_ms", "1.00")
		RunConsoleCommand("tf_bot_perf_scale_start", "6")
		RunConsoleCommand("tf_bot_perf_scale_max", "7")
		RunConsoleCommand("tf_bot_breakable_check_interval", "0.50")
		RunConsoleCommand("tf_bot_perf_hard_threshold", "14")
		RunConsoleCommand("tf_bot_perf_hard_multiplier", "1.8")
		RunConsoleCommand("tf_bot_disable_social_look_highload", "1")
		MsgN("[tf_bot_perf] Applied 'ultra' profile.")
		return
	end
	if profile == "balanced" then
		RunConsoleCommand("tf_bot_sense_interval", "0.30")
		RunConsoleCommand("tf_bot_objective_interval", "0.85")
		RunConsoleCommand("tf_bot_avoidance_interval", "0.12")
		RunConsoleCommand("tf_bot_repath_interval", "1.90")
		RunConsoleCommand("tf_bot_nav_budget_ms", "2.00")
		RunConsoleCommand("tf_bot_perf_scale_start", "10")
		RunConsoleCommand("tf_bot_perf_scale_max", "4")
		RunConsoleCommand("tf_bot_breakable_check_interval", "0.25")
		RunConsoleCommand("tf_bot_perf_hard_threshold", "18")
		RunConsoleCommand("tf_bot_perf_hard_multiplier", "1.2")
		RunConsoleCommand("tf_bot_disable_social_look_highload", "0")
		MsgN("[tf_bot_perf] Applied 'balanced' profile.")
		return
	end

	-- Default to max throughput profile.
	RunConsoleCommand("tf_bot_sense_interval", "0.35")
	RunConsoleCommand("tf_bot_objective_interval", "1.00")
	RunConsoleCommand("tf_bot_avoidance_interval", "0.15")
	RunConsoleCommand("tf_bot_repath_interval", "2.20")
	RunConsoleCommand("tf_bot_nav_budget_ms", "2.20")
	RunConsoleCommand("tf_bot_perf_scale_start", "8")
	RunConsoleCommand("tf_bot_perf_scale_max", "4")
	RunConsoleCommand("tf_bot_breakable_check_interval", "0.35")
	RunConsoleCommand("tf_bot_perf_hard_threshold", "16")
	RunConsoleCommand("tf_bot_perf_hard_multiplier", "1.4")
	RunConsoleCommand("tf_bot_disable_social_look_highload", "1")
	MsgN("[tf_bot_perf] Applied 'max' profile.")
end)

local objectiveCache = {
	nextRefresh = 0,
	team_train_watcher = {},
	item_teamflag = {},
	item_teamflag_mvm = {},
	func_capturezone = {},
	func_flagdetectionzone = {},
	trigger_capture_area = {},
	bot_hint_sentrygun = {},
	obj_sentrygun = {},
	obj_dispenser = {},
	obj_teleporter = {},
}

local navBudget = {
	window = 0,
	used = 0,
}

local function PerfEnabled()
	return CVBool(tf_bot_perf_enable, true)
end

local function PerfDebug(msg)
	if CVBool(tf_bot_perf_debug, false) then
		MsgN("[tf_bot_perf] " .. msg)
	end
end

local function GetAdaptivePerfScale()
	if not PerfEnabled() then return 1 end
	local startCount = math.max(CVFloat(tf_bot_perf_scale_start, 12), 1)
	local maxScale = math.max(CVFloat(tf_bot_perf_scale_max, 3), 1)
	local botCount = math.max(#player.GetBots(), 1)
	if botCount <= startCount then
		return 1
	end
	local scale = botCount / startCount
	local hardThreshold = math.max(CVFloat(tf_bot_perf_hard_threshold, 16), 1)
	if botCount >= hardThreshold then
		scale = scale * math.max(CVFloat(tf_bot_perf_hard_multiplier, 1.6), 1)
	end
	return math.Clamp(scale, 1, maxScale)
end

local function GetAdaptiveInterval(baseValue, minimum)
	local minValue = minimum or 0.05
	return math.max(baseValue * GetAdaptivePerfScale(), minValue)
end

local function RefreshObjectiveCache(force)
	if not PerfEnabled() then return end
	local now = CurTime()
	local interval = CVFloat(tf_bot_objective_interval, 0.75)
	interval = GetAdaptiveInterval(interval, 0.05)
	if not force and objectiveCache.nextRefresh > now then return end
	objectiveCache.nextRefresh = now + math.max(interval, 0.05)
	objectiveCache.team_train_watcher = ents.FindByClass("team_train_watcher")
	objectiveCache.item_teamflag = ents.FindByClass("item_teamflag")
	objectiveCache.item_teamflag_mvm = ents.FindByClass("item_teamflag_mvm")
	objectiveCache.func_capturezone = ents.FindByClass("func_capturezone")
	objectiveCache.func_flagdetectionzone = ents.FindByClass("func_flagdetectionzone")
	objectiveCache.trigger_capture_area = ents.FindByClass("trigger_capture_area")
	objectiveCache.bot_hint_sentrygun = ents.FindByClass("bot_hint_sentrygun")
	objectiveCache.obj_sentrygun = ents.FindByClass("obj_sentrygun")
	objectiveCache.obj_dispenser = ents.FindByClass("obj_dispenser")
	objectiveCache.obj_teleporter = ents.FindByClass("obj_teleporter")
end

local function GetCachedEntities(classname)
	if not PerfEnabled() then
		return ents.FindByClass(classname)
	end
	RefreshObjectiveCache(false)
	return objectiveCache[classname] or {}
end

local function GetNearbyEntities(bot, radius, minInterval)
	if not IsValid(bot) then return {} end
	if not PerfEnabled() then
		return ents.FindInSphere(bot:GetPos(), radius)
	end
	local now = CurTime()
	bot._nearbyCache = bot._nearbyCache or {}
	local key = tostring(radius)
	local cache = bot._nearbyCache[key]
	if cache and cache.next and cache.next > now then
		return cache.data
	end
	local interval = minInterval or CVFloat(tf_bot_sense_interval, 0.25)
	local data = ents.FindInSphere(bot:GetPos(), radius)
	bot._nearbyCache[key] = {
		data = data,
		next = now + math.max(interval, 0.05),
	}
	return data
end

hook.Add("Think", "TFBot_PerfCacheRefresh", function()
	RefreshObjectiveCache(false)
end)

local currentNameIndex = 0
local shuffledNameBag = {}
local shuffledNameBagIndex = 0

local function TrimString(s)
	return string.Trim(s or "")
end

local function BuildNamePool()
	local pool = {}
	local seen = {}

	local function AddName(candidate)
		if not isstring(candidate) then return end
		local cleaned = TrimString(candidate)
		if cleaned == "" then return end
		local key = string.lower(cleaned)
		if seen[key] then return end
		seen[key] = true
		pool[#pool + 1] = cleaned
	end

	if CVBool(tf_bot_public_names, true) then
		for _, n in ipairs(public_usernames) do
			AddName(n)
		end
	end

	local customPath = TrimString(tf_bot_name_file:GetString())
	if customPath ~= "" and file.Exists(customPath, "DATA") then
		local raw = file.Read(customPath, "DATA") or ""
		for line in string.gmatch(raw, "[^\r\n]+") do
			AddName(line)
		end
	end

	if CVBool(tf_bot_include_legacy_names, false) then
		for _, n in ipairs(names) do
			AddName(n)
		end
	end

	return pool
end

local function RebuildNameBag()
	shuffledNameBag = BuildNamePool()
	for i = #shuffledNameBag, 2, -1 do
		local j = math.random(i)
		shuffledNameBag[i], shuffledNameBag[j] = shuffledNameBag[j], shuffledNameBag[i]
	end
	shuffledNameBagIndex = 0
	currentNameIndex = 0
end

function GetNextBotName()
	if not CVBool(tf_bot_random_names, true) then
		if #shuffledNameBag == 0 then
			RebuildNameBag()
		end
		if #shuffledNameBag > 0 then
			currentNameIndex = currentNameIndex + 1
			if currentNameIndex > #shuffledNameBag then
				currentNameIndex = 1
			end
			return shuffledNameBag[currentNameIndex]
		end
		currentNameIndex = currentNameIndex + 1
		if currentNameIndex > #names then
			currentNameIndex = 1
		end
		return names[currentNameIndex]
	end

	if #shuffledNameBag == 0 or shuffledNameBagIndex >= #shuffledNameBag then
		RebuildNameBag()
	end
	if #shuffledNameBag == 0 then
		return "TFBot_" .. tostring(math.random(1000, 9999))
	end

	shuffledNameBagIndex = shuffledNameBagIndex + 1
	return shuffledNameBag[shuffledNameBagIndex]
end

RebuildNameBag()
cvars.AddChangeCallback("tf_bot_random_names", RebuildNameBag, "TFBotNamesRebuildRandom")
cvars.AddChangeCallback("tf_bot_public_names", RebuildNameBag, "TFBotNamesRebuildPublic")
cvars.AddChangeCallback("tf_bot_include_legacy_names", RebuildNameBag, "TFBotNamesRebuildLegacy")
cvars.AddChangeCallback("tf_bot_name_file", RebuildNameBag, "TFBotNamesRebuildFile")

local function IsValidTarget(bot,target)

	if (IsValid(target)) then
		if (target:EntIndex() == bot:EntIndex()) then
			return false
		end
		if (target:IsPlayer() and target:Team() == bot:Team()) then
			return false
		end
		if (target:Health() < 1) then
			return false
		end
		if (target:IsPlayer() and target:Team() == 1) then
			return false
		end
		if (target:EntIndex() == bot.ControllerBot:EntIndex()) then
			return false
		end
		if (target:IsFlagSet(FL_NOTARGET)) then
			return false
		end
		if (target:EntIndex() == bot:EntIndex()) then
			return false
		end
		-- Some entities/bots return inconsistent EntityTeam values on custom maps.
		-- Prefer explicit team checks for players and only reject true neutral/spectator.
		if target:IsPlayer() then
			local t = target:Team()
			if t == TEAM_SPECTATOR or t == TEAM_NEUTRAL then
				return false
			end
		else
			local et = target.EntityTeam and target:EntityTeam() or nil
			if et and et ~= TEAM_RED and et ~= TEAM_BLU and et ~= TF_TEAM_PVE_INVADERS then
				return false
			end
		end
		return true
	end
	return false

end

local function GetVisionRecognizeTime(bot)
	local diff = tonumber(bot and bot.Difficulty) or tonumber(bot_diff:GetInt()) or 1
	if diff <= 0 then return 1.0 end
	if diff == 1 then return 0.5 end
	if diff == 2 then return 0.3 end
	return 0.2
end

local function GetVisionRange(bot)
	if IsValid(bot) and tonumber(bot.VisionLimits) and tonumber(bot.VisionLimits) > 0 then
		return tonumber(bot.VisionLimits)
	end
	return math.max(CVFloat(tf_bot_vision_range, 6000), 256)
end

local function GetTargetChooseInterval(bot)
	if not IsValid(bot) then
		return math.max(CVFloat(tf_bot_choose_target_interval, 0.30), 0.05)
	end

	local base = math.max(CVFloat(tf_bot_choose_target_interval, 0.30), 0.05)
	if bot.playerclass == "Sniper" then
		local wep = bot:GetActiveWeapon()
		if IsValid(wep) and wep.ZoomStatus then
			return math.max(CVFloat(tf_bot_sniper_choose_target_interval, 3.0), base)
		end
	end
	return base
end

local function EnsureVisionMemory(bot)
	bot._visionMemory = bot._visionMemory or {}
	return bot._visionMemory
end

local function UpdateVisionMemory(bot, target, isVisible)
	if not IsValid(bot) or not IsValid(target) then return nil end
	local mem = EnsureVisionMemory(bot)
	local id = target:EntIndex()
	local now = CurTime()
	local info = mem[id]
	if not info then
		info = { firstSeen = now, lastSeen = 0, recognized = false }
		mem[id] = info
	end

	if isVisible then
		if not info.firstSeen or info.firstSeen <= 0 then
			info.firstSeen = now
		end
		info.lastSeen = now
		if (now - info.firstSeen) >= GetVisionRecognizeTime(bot) then
			info.recognized = true
		end
	end

	return info
end

local function CanTrackTarget(bot, target)
	if not IsValid(bot) or not IsValid(target) or not IsValidTarget(bot, target) then
		return false
	end

	local distance = bot:GetPos():Distance(target:GetPos())
	local maxRange = GetVisionRange(bot)
	if distance > maxRange then
		return false
	end

	local visible = bot:Visible(target)
	local info = UpdateVisionMemory(bot, target, visible)
	if not info then return false end

	if visible then
		return info.recognized == true
	end

	if info.recognized and info.lastSeen and (CurTime() - info.lastSeen) <= math.max(CVFloat(tf_bot_target_lost_time, 1.25), 0.1) then
		return true
	end

	return false
end

local function IsThreatImmediate(bot, target)
	if not IsValid(bot) or not IsValid(target) then return false end
	local dist = bot:GetPos():Distance(target:GetPos())
	local className = string.lower(tostring(target:GetClass() or ""))
	local visible = bot:Visible(target)

	if dist <= 500 then
		return true
	end

	-- Source-style sentry urgency at medium range.
	if className == "obj_sentrygun" and visible and dist <= 1650 then
		return true
	end

	if not visible then
		return false
	end

	-- Snipers with line of sight are dangerous at long range.
	if target.IsPlayer and target:IsPlayer() then
		local pclass = string.lower(tostring((target.GetPlayerClass and target:GetPlayerClass()) or target.playerclass or ""))
		if pclass == "sniper" and dist <= 3000 then
			return true
		end
	end

	return dist <= 1200
end

local function ScoreThreat(bot, target)
	if not IsValid(bot) or not IsValid(target) then
		return -math.huge
	end

	local dist = bot:GetPos():Distance(target:GetPos())
	local score = 0
	local visible = bot:Visible(target)
	local class = target:GetClass()
	local pclass = target.IsPlayer and target:IsPlayer() and string.lower(tostring((target.GetPlayerClass and target:GetPlayerClass()) or target.playerclass or "")) or ""

	-- Source-inspired "fear sentry in range" behavior.
	if class == "obj_sentrygun" and dist <= 1100 then
		score = score + 5000
	end
	local isMvM = string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
	local isMvMInvader = bot:Team() == TEAM_BLU or bot:Team() == TF_TEAM_PVE_INVADERS or bot.IsMVMRobot == true
	if isMvM and isMvMInvader and pclass == "spy" and dist <= 1000 then
		-- Source behavior strongly biases MvM invaders to kill nearby spies.
		score = score + 3200
	end
	local diff = tonumber(bot.Difficulty) or tonumber(bot_diff:GetInt()) or 1
	if diff >= 2 and pclass == "medic" and dist <= 1800 then
		score = score + 450
	end
	if IsThreatImmediate(bot, target) then
		score = score + 1500
	end
	if visible then
		score = score + 1000
	end
	if target.IsPlayer and target:IsPlayer() and target:Team() ~= TEAM_SPECTATOR then
		score = score + 250
	end

	score = score - dist
	return score
end
function lookForNearestHealthPack(bot)
	
	local npcs = {}
	for k,v in ipairs(GetNearbyEntities(bot, 2048, GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05))) do
		if (string.find(v:GetClass(),"item_healthkit") or string.find(v:GetClass(),"item_healthvial") or (string.find(v:GetClass(),"obj_dispenser") and v:IsFriendly(bot))) then
			table.insert(npcs, v)
		end
	end
	return table.Random(npcs)
	
end
function lookForNearestAmmoPack(bot)
	
	local npcs = {}
	for k,v in ipairs(GetNearbyEntities(bot, 2048, GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05))) do
		if (string.find(v:GetClass(),"item_ammopack") or string.find(v:GetClass(),"obj_dispenser")) then
			table.insert(npcs, v)
		end
	end
	return table.Random(npcs)
	
end
function lookForNearestPlayer(bot)
	if not IsValid(bot) then return nil end
	local bestTarget, bestScore = nil, -math.huge
	local range = math.min(GetVisionRange(bot), 8192)
	for _, v in ipairs(GetNearbyEntities(bot, range, GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05))) do
		if v:IsPlayer() and v:Health() > 1 and IsValidTarget(bot, v) and CanTrackTarget(bot, v) then
			local score = ScoreThreat(bot, v)
			if score > bestScore then
				bestScore = score
				bestTarget = v
			end
		end
	end
	return bestTarget
end
function lookForNearestEnemyPlayer(bot)
	if not IsValid(bot) then return nil end
	local bestTarget, bestScore = nil, -math.huge
	local range = math.min(GetVisionRange(bot), 8192)
	for _, v in ipairs(GetNearbyEntities(bot, range, GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05))) do
		if IsValid(v) and v:IsPlayer() and v:Health() > 1 and IsValidTarget(bot, v) and CanTrackTarget(bot, v) then
			local score = ScoreThreat(bot, v)
			if score > bestScore then
				bestScore = score
				bestTarget = v
			end
		end
	end
	return bestTarget
end

local function AcquireEnemyTarget(bot)
	if not IsValid(bot) then return nil end
	local now = CurTime()

	if IsValid(bot.TargetEnt) and CanTrackTarget(bot, bot.TargetEnt) and bot._nextTargetReselectTime and now < bot._nextTargetReselectTime then
		return bot.TargetEnt
	end

	local target = lookForNearestPlayer(bot)
	if not IsValid(target) then
		target = lookForNearestEnemyPlayer(bot)
	end

	if not IsValid(target) then
		local range = math.min(GetVisionRange(bot), 8192)
		local bestTarget, bestScore = nil, -math.huge
		for _, v in ipairs(GetNearbyEntities(bot, range, GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05))) do
			if IsValidTarget(bot, v) and CanTrackTarget(bot, v) then
				local className = v:GetClass()
				if v:IsPlayer() or className == "obj_sentrygun" or className == "obj_dispenser" or className == "obj_teleporter" then
					local score = ScoreThreat(bot, v)
					if score > bestScore then
						bestScore = score
						bestTarget = v
					end
				end
			end
		end
		target = bestTarget
	end

	-- Long-range fallback: keep momentum by selecting a distant enemy player
	-- when nothing is currently nearby/trackable.
	if not IsValid(target) then
		local bestTarget, bestDist = nil, math.huge
		for _, v in ipairs(player.GetAll()) do
			if IsValid(v) and v:IsPlayer() and v:Alive() and IsValidTarget(bot, v) then
				local d = bot:GetPos():DistToSqr(v:GetPos())
				if d < bestDist then
					bestDist = d
					bestTarget = v
				end
			end
		end
		target = bestTarget
	end

	bot._nextTargetReselectTime = now + GetTargetChooseInterval(bot)
	if IsValid(target) and IsValidTarget(bot, target) then
		return target
	end
	return nil
end

function lookForClosestFriendlyHumanLookingAtMe(bot)
	if not IsValid(bot) then return nil end
	if PerfEnabled() then
		local botCount = #player.GetBots()
		local hardThreshold = math.max(CVFloat(tf_bot_perf_hard_threshold, 16), 1)
		if CVBool(tf_bot_disable_social_look_highload, true) and botCount >= hardThreshold then
			return nil
		end
		bot._nextFriendlyLookCheck = bot._nextFriendlyLookCheck or 0
		if bot._nextFriendlyLookCheck > CurTime() then
			return bot._cachedFriendlyLookAtMe
		end
		bot._nextFriendlyLookCheck = CurTime() + GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.10)
	end
	local npcs = {}
		for k,v in ipairs(GetNearbyEntities(bot, 600, GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05))) do
			if (IsValid(v) and v:IsPlayer() and v:Health() > 0 and v:IsFriendly(bot) and !v:IsBot()) then
				local tr = v:GetEyeTrace()
				if tr and IsValid(tr.Entity) and (tr.Entity:EntIndex() == bot:EntIndex()) then
					table.insert(npcs, v)
				end
			end
		end
		bot._cachedFriendlyLookAtMe = table.Random(npcs)
		return bot._cachedFriendlyLookAtMe
end

local function GetPayloadWatcher()
	if GAMEMODE and GAMEMODE.GetActivePayloadWatcher then
		local watcher = GAMEMODE:GetActivePayloadWatcher()
		if IsValid(watcher) then
			return watcher
		end
	end

	for _, watcher in ipairs(GetCachedEntities("team_train_watcher")) do
		if IsValid(watcher) then
			return watcher
		end
	end

	return nil
end

local function GetPayloadState(watcher)
	if not IsValid(watcher) or not watcher.GetPayloadState then
		return {}
	end
	return watcher:GetPayloadState() or {}
end

local function GetPayloadAttackTeam(state)
	local teamNum = tonumber(state.attackTeam)
	if teamNum == TEAM_RED or teamNum == TEAM_BLU then
		return teamNum
	end
	return TEAM_BLU
end

local function GetPayloadDefendTeam(state)
	local teamNum = tonumber(state.defendTeam)
	if teamNum == TEAM_RED or teamNum == TEAM_BLU then
		return teamNum
	end
	return (GetPayloadAttackTeam(state) == TEAM_RED) and TEAM_BLU or TEAM_RED
end

local function GetPayloadCartPosition(watcher)
	if not IsValid(watcher) then return nil end
	if watcher.GetCartPosition then
		return watcher:GetCartPosition()
	end
	if IsValid(watcher.Train) then
		return watcher.Train:GetPos()
	end
	return watcher:GetPos()
end

local function GetPayloadDefendPosition(watcher)
	if not IsValid(watcher) then return nil end
	if watcher.GetDefendPosition then
		return watcher:GetDefendPosition()
	end
	return GetPayloadCartPosition(watcher)
end

local function GetPayloadObjectivePosition(bot)
	if not IsValid(bot) then return nil end

	local watcher = GetPayloadWatcher()
	if not IsValid(watcher) then return nil end

	local state = GetPayloadState(watcher)
	if state.goalReached then return nil end
	if state.active == false and not IsValid(watcher.Train) then return nil end

	local attackTeam = GetPayloadAttackTeam(state)
	local defendTeam = GetPayloadDefendTeam(state)
	local cartPos = GetPayloadCartPosition(watcher)
	if not cartPos then return nil end

	if bot:Team() == attackTeam then
		return cartPos
	end

	if bot:Team() == defendTeam then
		local cappers = tonumber(state.cappers) or 0
		local contested = cappers > 0 or state.blocked or tonumber(state.trainState) == 1
		if contested then
			return cartPos
		end
		return GetPayloadDefendPosition(watcher) or cartPos
	end

	return cartPos
end

function escortAvailable(bot)
	local watcher = GetPayloadWatcher()
	if not IsValid(watcher) then return false end

	local state = GetPayloadState(watcher)
	if state.goalReached then return false end
	if state.active == false and not IsValid(watcher.Train) then return false end

	return true
end

function flagAvailable(bot)
	local npcs = {} 
	for k,v in ipairs(GetCachedEntities("item_teamflag")) do
		if (IsValid(v)) then
			table.insert(npcs, v)		
		end
	end
	return table.Count(npcs) > 0
end
function bombAvailable(bot)
	local npcs = {} 
	for k,v in ipairs(GetCachedEntities("item_teamflag_mvm")) do
		if (IsValid(v)) then
			table.insert(npcs, v)		
		end
	end
	return table.Count(npcs) > 0
end

local GetObjectivePos

local function GetControlPointOwnerTeam(cp)
	if not IsValid(cp) then return 0 end
	if cp.GetOwnerTeam then
		local owner = tonumber(cp:GetOwnerTeam())
		if owner then return owner end
	end
	return tonumber(cp.OwnerTeam or (cp.Properties and cp.Properties.point_default_owner) or 0) or 0
end

local function TeamCanCaptureControlPoint(cp, teamNum)
	if not IsValid(cp) then return false end
	if not teamNum then return false end
	if cp.Locked then return false end
	if istable(cp.TeamCanCap) and cp.TeamCanCap[teamNum] ~= nil then
		return cp.TeamCanCap[teamNum] and true or false
	end
	return GetControlPointOwnerTeam(cp) ~= teamNum
end

local function CountCaptureAreaTeamOccupants(trigger, teamNum, fallbackPos)
	if not IsValid(trigger) or not teamNum then return 0 end
	local count = 0

	if istable(trigger.Occupants) then
		for ply in pairs(trigger.Occupants) do
			if IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply:Team() == teamNum then
				count = count + 1
			end
		end
		return count
	end

	local pos = fallbackPos or trigger:GetPos()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:Alive() and ply:Team() == teamNum and ply:GetPos():DistToSqr(pos) <= (420 * 420) then
			count = count + 1
		end
	end
	return count
end

local function FindClosestEnemyNear(pos, teamNum, maxRadius)
	if not pos then return nil end
	local enemyTeam = (teamNum == TEAM_RED) and TEAM_BLU or TEAM_RED
	local best
	local bestDist = math.huge
	local radiusSqr = (maxRadius or 900) ^ 2
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:Alive() and ply:Team() == enemyTeam then
			local d = ply:GetPos():DistToSqr(pos)
			if d <= radiusSqr and d < bestDist then
				best = ply
				bestDist = d
			end
		end
	end
	return best
end

local function controlPointAvailable(bot)
	for _, trigger in ipairs(GetCachedEntities("trigger_capture_area")) do
		if IsValid(trigger) and IsValid(trigger.CapturePoint) then
			return true
		end
	end
	return false
end

local function SelectControlPointObjective(bot)
	if not IsValid(bot) then return nil end
	local teamNum = bot:Team()
	if teamNum ~= TEAM_RED and teamNum ~= TEAM_BLU then
		return nil
	end

	local enemyTeam = (teamNum == TEAM_RED) and TEAM_BLU or TEAM_RED
	local bestDecision
	local bestScore = math.huge

	for _, trigger in ipairs(GetCachedEntities("trigger_capture_area")) do
		if not IsValid(trigger) then continue end
		local cp = trigger.CapturePoint
		if not IsValid(cp) or cp.Locked then continue end

		local ownerTeam = GetControlPointOwnerTeam(cp)
		local canWeCap = TeamCanCaptureControlPoint(cp, teamNum)
		local canEnemyCap = TeamCanCaptureControlPoint(cp, enemyTeam)

		local objectivePos = GetObjectivePos(cp) or GetObjectivePos(trigger)
		if not objectivePos then continue end

		local isDefendPoint = (ownerTeam == teamNum and canEnemyCap)
		local isAttackPoint = (ownerTeam ~= teamNum and canWeCap)
		if not isDefendPoint and not isAttackPoint then continue end

		local attackers = CountCaptureAreaTeamOccupants(trigger, enemyTeam, objectivePos)
		local defenders = CountCaptureAreaTeamOccupants(trigger, teamNum, objectivePos)
		local score = bot:GetPos():DistToSqr(objectivePos)

		if isDefendPoint then
			if attackers > 0 then
				score = score * 0.30
			else
				score = score * 0.75
			end
			score = score - (attackers * 90000)
		else
			score = score - (defenders * 30000)
		end

		if score < bestScore then
			bestScore = score
			bestDecision = {
				targetPos = objectivePos,
				defend = isDefendPoint,
				targetEnt = isDefendPoint and FindClosestEnemyNear(objectivePos, teamNum, 1200) or nil,
			}
		end
	end

	return bestDecision
end

local function IsMvMMap()
	if TF_IsMvMMap then
		return TF_IsMvMMap()
	end
	return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

GetObjectivePos = function(ent)
	if not IsValid(ent) then return nil end
	local pos = nil
	if ent.Pos then
		pos = ent.Pos
	elseif ent.WorldSpaceCenter then
		pos = ent:WorldSpaceCenter()
	else
		pos = ent:GetPos()
	end

	-- Keep objective points anchored to nav so bots do not chase brush centers in void/solid.
	if pos and navmesh and navmesh.GetNearestNavArea then
		local area = navmesh.GetNearestNavArea(pos)
		if IsValid(area) then
			return area:GetCenter()
		end
	end

	return pos
end

local function IsMvMGateBot(bot)
	if not IsValid(bot) then return false end
	if bot.TF_MVM_IsGateBot ~= nil then
		return bot.TF_MVM_IsGateBot == true
	end

	local now = CurTime()
	if bot._mvmGateBotScanNext and bot._mvmGateBotScanNext > now then
		return bot._mvmGateBotScanCached == true
	end

	local isGateBot = false
	if isfunction(bot.GetTFItems) then
		for _, item in ipairs(bot:GetTFItems()) do
			if not IsValid(item) then continue end
			local data = item.GetItemData and item:GetItemData() or nil
			local name = string.lower(tostring((data and (data.name or data.item_name)) or ""))
			if string.find(name, "gatebot", 1, true) or string.find(name, "gate bot", 1, true) then
				isGateBot = true
				break
			end
		end
	end

	bot._mvmGateBotScanCached = isGateBot
	bot._mvmGateBotScanNext = now + 0.9

	if isGateBot then
		bot.TF_MVM_IsGateBot = true
	end

	return isGateBot
end

local function GetMvMBombDeployZone()
	local fallback = nil
	for _, zone in ipairs(GetCachedEntities("func_capturezone")) do
		if not IsValid(zone) then continue end
		if not fallback then
			fallback = zone
		end
		local teamNum = tonumber(zone.TeamNum or zone.Team or 0) or 0
		if teamNum == TEAM_RED or teamNum == 2 then
			return zone
		end
	end
	return fallback
end

local function GetMvMOpenGateTargetPos(bot)
	local bestPos = nil
	local bestDist = nil
	local origin = IsValid(bot) and bot:GetPos() or vector_origin

	for _, zone in ipairs(GetCachedEntities("func_flagdetectionzone")) do
		if not IsValid(zone) then continue end
		if zone.Opened then continue end

		local pos = GetObjectivePos(zone)
		if not pos then continue end

		local dist = origin:DistToSqr(pos)
		if not bestDist or dist < bestDist then
			bestDist = dist
			bestPos = pos
		end
	end

	return bestPos
end

local function IsMvMInvaderBot(bot)
	if not IsValid(bot) then return false end
	if not IsMvMMap() then return false end
	return bot:Team() == TEAM_BLU or bot:Team() == TF_TEAM_PVE_INVADERS or bot.IsMVMRobot == true
end

local function GetMvMBombIntel()
	for _, intelEnt in ipairs(GetCachedEntities("item_teamflag_mvm")) do
		if IsValid(intelEnt) then
			return intelEnt
		end
	end
	return nil
end

local function IsMvMBombAtHome(bombIntel)
	if not IsValid(bombIntel) then return false end
	if isfunction(bombIntel.IsHome) then
		return bombIntel:IsHome() == true
	end
	-- item_teamflag_mvm uses explicit state values: 0=home, 1=carried, 2=dropped.
	return tonumber(bombIntel.State or -1) == 0
end

local function IsMvMBombCarrier(bot)
	if not IsValid(bot) or not IsMvMInvaderBot(bot) then return false end
	local intel = GetMvMBombIntel()
	if not IsValid(intel) or not IsValid(intel.Carrier) then return false end
	return intel.Carrier:EntIndex() == bot:EntIndex()
end

local function IsAnyFlagCarrier(bot)
	if not IsValid(bot) then return false end
	local entIdx = bot:EntIndex()

	for _, intel in ipairs(GetCachedEntities("item_teamflag")) do
		if IsValid(intel) and IsValid(intel.Carrier) and intel.Carrier:EntIndex() == entIdx then
			return true
		end
	end

	for _, intel in ipairs(GetCachedEntities("item_teamflag_mvm")) do
		if IsValid(intel) and IsValid(intel.Carrier) and intel.Carrier:EntIndex() == entIdx then
			return true
		end
	end

	return false
end

local function ShouldCarrierIgnoreEnemy(bot, enemy)
	if not IsMvMBombCarrier(bot) then return false end
	if not IsValid(enemy) or not enemy:IsPlayer() then return true end
	-- Keep moving unless an enemy is in close blocking range.
	return bot:GetPos():DistToSqr(enemy:GetPos()) > (480 * 480)
end

local function IsMvMSentryBuster(bot)
	if not IsValid(bot) then return false end
	return string.lower(tostring(bot:GetPlayerClass() or "")) == "sentrybuster"
end

local function IsMvMAggressiveBot(bot)
	if not IsValid(bot) then return false end
	if isfunction(bot.IsMiniBoss) and bot:IsMiniBoss() then return true end
	if bot:GetNWBool("IsBoss", false) then return true end
	return tonumber(bot.BotStrategy or 0) == 1
end

local function CountMvMEscortsForCarrier(teamNum, carrier, range)
	if not IsValid(carrier) then return 0 end
	local maxDistSqr = (range or 1200) * (range or 1200)
	local count = 0

	for _, mate in ipairs(player.GetBots()) do
		if not IsValid(mate) then continue end
		if mate:Team() ~= teamNum then continue end
		if mate:EntIndex() == carrier:EntIndex() then continue end
		if mate.intelcarrier ~= carrier then continue end
		if mate:GetPos():DistToSqr(carrier:GetPos()) > maxDistSqr then continue end
		count = count + 1
	end

	return count
end

local function SelectSentryBusterTarget(bot)
	if not IsValid(bot) then return nil end

	local bestTarget = nil
	local bestScore = -math.huge

	local function scoreBuilding(building, isPriority)
		if not IsValid(building) or building:IsFriendly(bot) then return end
		local dist = bot:GetPos():DistToSqr(building:GetPos())
		local killScore = 0
		if building.GetKills and isfunction(building.GetKills) then
			killScore = math.max(tonumber(building:GetKills()) or 0, 0) * 100000
		end
		local score = killScore - dist
		if isPriority then
			score = score + 100000000
		end
		if score > bestScore then
			bestScore = score
			bestTarget = building
		end
	end

	for _, sentry in ipairs(GetCachedEntities("obj_sentrygun")) do
		scoreBuilding(sentry, true)
	end
	for _, disp in ipairs(GetCachedEntities("obj_dispenser")) do
		scoreBuilding(disp, false)
	end
	for _, tele in ipairs(GetCachedEntities("obj_teleporter")) do
		scoreBuilding(tele, false)
	end

	return bestTarget
end

local MvMAction = {
	None = "none",
	LeaveSpawn = "leave_spawn",
	FetchBomb = "fetch_bomb",
	DeliverBomb = "deliver_bomb",
	EscortCarrier = "escort_carrier",
	PushGate = "push_gate",
	DefendBomb = "defend_bomb",
	DefendHatch = "defend_hatch",
	DestroySentries = "destroy_sentries",
	Roam = "roam",
}

local function GetFriendlySpawnAttributeForBot(bot)
	if not IsValid(bot) then return nil end
	if bot:Team() == TEAM_RED then
		return "spawn_room_red"
	end
	if bot:Team() == TEAM_BLU or bot:Team() == TF_TEAM_PVE_INVADERS then
		return "spawn_room_blue"
	end
	return nil
end

local function HasAreaTFAttribute(area, attrName)
	if not IsValid(area) or not isstring(attrName) or attrName == "" then return false end
	if not isfunction(area.HasTFAttribute) then return false end
	return area:HasTFAttribute(attrName) == true
end

local function GetSpawnExitTargetPos(bot)
	if not IsValid(bot) or not navmesh or not navmesh.GetAllNavAreas then return nil end
	local spawnAttr = GetFriendlySpawnAttributeForBot(bot)
	if not spawnAttr then return nil end

	local now = CurTime()
	if bot._mvmSpawnExitPos and bot._mvmSpawnExitUntil and bot._mvmSpawnExitUntil > now then
		return bot._mvmSpawnExitPos
	end

	local origin = bot:GetPos()
	local bestPos = nil
	local bestDist = nil
	for _, area in ipairs(navmesh.GetAllNavAreas()) do
		if not IsValid(area) then continue end
		if HasAreaTFAttribute(area, spawnAttr) then continue end

		local center = area:GetCenter()
		local dz = math.abs(center.z - origin.z)
		if dz > 512 then continue end

		local dist = origin:DistToSqr(center)
		if not bestDist or dist < bestDist then
			bestDist = dist
			bestPos = center
		end
	end

	bot._mvmSpawnExitPos = bestPos
	bot._mvmSpawnExitUntil = now + 1.0
	return bestPos
end

local function GetMvMNavObjectiveAnchor(bot)
	if not IsValid(bot) or not IsMvMMap() then return nil end

	local now = CurTime()
	if bot._mvmNavAnchor and bot._mvmNavAnchorUntil and bot._mvmNavAnchorUntil > now then
		return bot._mvmNavAnchor
	end

	local anchor = nil
	local deployPos = GetObjectivePos(GetMvMBombDeployZone())
	local bombIntel = GetMvMBombIntel()
	local bombCarrier = IsValid(bombIntel) and bombIntel.Carrier or nil

	if IsMvMInvaderBot(bot) then
		if IsValid(bombCarrier) then
			if bombCarrier:EntIndex() == bot:EntIndex() then
				anchor = deployPos
			else
				anchor = bombCarrier:GetPos()
			end
		elseif IsValid(bombIntel) then
			anchor = bombIntel:GetPos()
		else
			anchor = deployPos
		end
	elseif bot:Team() == TEAM_RED then
		if IsValid(bombCarrier) and not bombCarrier:IsFriendly(bot) then
			anchor = bombCarrier:GetPos()
		else
			anchor = deployPos
		end
	end

	if anchor and navmesh and navmesh.GetNearestNavArea then
		local navArea = navmesh.GetNearestNavArea(anchor)
		if IsValid(navArea) then
			anchor = navArea:GetCenter()
		end
	end

	bot._mvmNavAnchor = anchor
	bot._mvmNavAnchorUntil = now + 0.25
	return anchor
end

local function SelectMvMAction(bot, controller, shouldFollowCarrierFn)
	if not IsValid(bot) or not IsMvMMap() or GAMEMODE.RoundHasWinner then
		return nil
	end
	if not bombAvailable(bot) then
		return nil
	end

	local decision = {
		action = MvMAction.None,
		targetPos = nil,
		intelCarrier = nil,
		followCarrier = false,
		isCarryingBomb = false,
		targetEnt = nil,
		routeType = nil,
		ignoreCombat = false,
	}

	local deployZone = GetMvMBombDeployZone()
	local deployPos = GetObjectivePos(deployZone)
	local bombIntel = GetMvMBombIntel()
	local bombCarrier = IsValid(bombIntel) and bombIntel.Carrier or nil

	-- RED side in MvM: defend bomb/hatch.
	if bot:Team() == TEAM_RED then
		if IsValid(bombCarrier) and not bombCarrier:IsFriendly(bot) then
			decision.action = MvMAction.DefendBomb
			decision.targetEnt = bombCarrier
			decision.targetPos = bombCarrier:GetPos()
			decision.intelCarrier = bombCarrier
			return decision
		end

		if deployPos then
			local closeEnough = bot.botPos and bot:GetPos():DistToSqr(bot.botPos) < (bot:GetModelRadius() * bot:GetModelRadius() * 2.0)
			local shouldPickPatrol = (not bot._mvmDefendPatrolUntil) or (bot._mvmDefendPatrolUntil < CurTime()) or closeEnough
			if shouldPickPatrol and IsValid(controller) then
				local patrolPos = controller:FindSpot("random", { radius = 1600, pos = deployPos, type = "exposed" })
				bot._mvmDefendPatrolPos = patrolPos or deployPos
				bot._mvmDefendPatrolUntil = CurTime() + math.Rand(3, 6)
			end
			decision.action = MvMAction.DefendHatch
			decision.targetPos = bot._mvmDefendPatrolPos or deployPos
			return decision
		end

		if IsValid(controller) and (CurTime() > controller.LastSegmented or not bot.botPos) then
			bot._mvmDefendPatrolPos = controller:FindSpot("random", {radius = 3000})
			controller.LastSegmented = CurTime() + 8
		end
		decision.action = MvMAction.Roam
		decision.targetPos = bot._mvmDefendPatrolPos or bot.botPos
		return decision
	end

	if not IsMvMInvaderBot(bot) then
		decision.action = MvMAction.Roam
		decision.targetPos = IsValid(bot.TargetEnt) and bot.TargetEnt:GetPos() or deployPos
		return decision
	end

	-- BLU-side MvM invaders:
	-- 1) If there is a bomb carrier, everyone follows that carrier.
	-- 2) If there is no bomb carrier, everyone follows the bomb.
	if IsValid(bombCarrier) then
		decision.intelCarrier = bombCarrier
		if bombCarrier:EntIndex() == bot:EntIndex() then
			decision.action = MvMAction.DeliverBomb
			decision.targetPos = deployPos or bombCarrier:GetPos()
			decision.isCarryingBomb = true
			decision.routeType = "mvm_bomb_carrier"
			decision.ignoreCombat = true
			return decision
		end

		decision.action = MvMAction.EscortCarrier
		decision.targetPos = bombCarrier:GetPos()
		decision.followCarrier = true
		decision.routeType = "mvm_push"
		return decision
	end

	if IsValid(bombIntel) then
		decision.action = MvMAction.FetchBomb
		decision.targetPos = bombIntel:GetPos()
		decision.routeType = "mvm_push"
		return decision
	end

	decision.action = MvMAction.DeliverBomb
	decision.targetPos = deployPos
	decision.routeType = "mvm_push"
	return decision
end

function lookForClosestHumanPlayer(bot)
	local npcs = {} 
	if bot.TFBot then
		for k,v in ipairs(GetNearbyEntities(bot, 800, GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05))) do 
			if (v:IsPlayer() and v:Health() > 0 and !v:IsBot() and v:EntIndex() != bot:EntIndex() and v:EntityTeam(bot) != TEAM_NEUTRAL and !IsValid(bot.TargetEnt) and !v:IsFriendly(bot) and v:Team() != TEAM_NEUTRAL and v:Team() != TEAM_FRIENDLY and v:Health() > 0 ) then
				table.insert(npcs, v)
			end
		end
	end
	return table.Random(npcs)
end

-- Utility: Find visible enemy players
local function IsEnemyVisible(ply, other)
    if not IsValid(other) or not other:Alive() then return false end
    if ply:Team() == other:Team() then return false end

    local tr = util.TraceLine({
        start = ply:GetPos() + Vector(0, 0, 60),
        endpos = other:GetPos() + Vector(0, 0, 60),
        filter = { ply },
        mask = MASK_SOLID
    })

    return tr.Fraction > 0.95 -- mostly unobstructed
end

-- Utility: Check if nav area is safe (no enemy nearby or visible)
local function IsNavAreaSafe(nav, ply)
    local center = nav:GetCenter()
	local enemy = ply.TargetEnt
	if IsValid(enemy) then
		local dist = enemy:GetPos():Distance(center)
		if dist < 500 then
			return false
		end

		if dist < 1400 then
			local tr = util.TraceLine({
				start = enemy:EyePos(),
				endpos = center + Vector(0, 0, 64),
				filter = { enemy },
				mask = MASK_SOLID
			})
			if tr.Fraction > 0.92 then
				return false
			end
		end
	end
    return true
end

-- Pick a random safe nav area
local function GetSafeRetreatArea(ply)
    local areas = navmesh.GetAllNavAreas()
    local candidates = {}

    for _, area in ipairs(areas) do
        if IsNavAreaSafe(area, ply) then
            table.insert(candidates, area)
        end
    end

    if #candidates == 0 then return nil end
    return candidates[math.random(#candidates)]
end

function getNPCsAndPlayers()
end

function LBAddProfile(tab) 
	if profiles[tab["name"]] then return end
	table.insert(profiles, tab) 
end
 
function LBAddBot(team)
	--if !profiles[name] then MsgN("That is not a valid bot!") return end
	if !navmesh.IsLoaded() then
		navmesh.BeginGeneration()
		for k, v in pairs(player.GetAll()) do
			v:ChatPrint("GENERATING NAV")
		end
	end
	local diff = GetConVar("tf_bot_difficulty"):GetFloat() -- math.random(3)
--[[local diffn = "Normal"
	if diff == 0 then
		diffn = "Easy"
	if diff == 1 then 
		diffn = "Normal"
	elseif diff == 2 then
		diffn = "Hard"
	elseif diff == 3 then
		diffn = "Expert"
	end]]
	local name = GetNextBotName()
	local bot = player.CreateNextBot(name)
	local teamd = TEAM_RED
	if team == 1 then
		teamd = TEAM_BLU
	end
	
	bot.ControllerBot = ents.Create("ctf_bot_navigator")
	bot.ControllerBot:Spawn()
	bot.LastPath = nil
	bot.CurSegment = 2
	if (!bot.IsL4DZombie) then
		local random = math.random(1,9)
		if (random == 1) then
			bot:SetPlayerClass("scout")
		elseif (random == 2) then
			bot:SetPlayerClass("soldier")
		elseif (random == 3) then
			bot:SetPlayerClass("pyro")
		elseif (random == 4) then
			bot:SetPlayerClass("demoman")
		elseif (random == 5) then
			bot:SetPlayerClass("heavy")
		elseif (random == 6) then
			bot:SetPlayerClass("engineer")
		elseif (random == 7) then
			bot:SetPlayerClass("medic")
		elseif (random == 8) then
			bot:SetPlayerClass("sniper")
		elseif (random == 9) then
			bot:SetPlayerClass("spy")
		end
	end
	for k, v in pairs(player.GetAll()) do
		v:ChatPrint(tostring(team))
	end
	timer.Simple(3, function()
		if IsValid(bot) then
			bot.TFBot = true
			if string.find(game.GetMap(), "mvm_") then
				
				bot.IsMVMRobot = true
				bot:SetTeam(TEAM_BLU)
				bot:SetSkin(1)
					
			else		
			
				bot:SetTeam(TEAM_BLU)
			end
			bot:Kill()
			bot.Difficulty = diff
			table.insert(bots, bot)
		end
	end)
end

function LBFindClosest(bot)
	local players = player.GetHumans()
	local distance = 9999
	local player = player.GetHumans()[1]
	local distanceplayer = 9999
	for k, v in pairs(players) do
		distanceplayer = v:GetPos():Distance(bot:GetPos())
		if distance > distanceplayer and v ~= bot then
			distance = distanceplayer
			player = v
		end
	end

	----print(player:Nick().." is the closest!")
	bot.FollowPly = player
end

hook.Add("PlayerHurt", "LeadBot_Death", function(ply, bot, hp, dmg)
    if bot.TFBot then
        local controller = bot.ControllerBot
    end
end)

local function LeadBot_S_Add(team2)
	if !navmesh.IsLoaded() then
		ErrorNoHalt("There is no navmesh! Generate one using \"nav_generate\"!\n")
		return
	end

	local bot = player.CreateNextBot(GetNextBotName())
	local teamv = TEAM_RED
	if team2 == 1 then
		teamv = TEAM_BLU
	end

	if !IsValid(bot) then ErrorNoHalt("[LeadBot] Player limit reached!\n") return end

	--bot.LastSegmented = CurTime() + 1

	bot.ControllerBot = ents.Create("ctf_bot_navigator")
	bot.ControllerBot:Spawn()
	bot.ControllerBot:SetOwner(bot)

	bot.LastPath = nil
	bot.CurSegment = 2
	bot.TFBot = true
	bot.BotStrategy = math.random(0, 1)

    --timer.Simple(1, function()
        ----TalkToMe(bot, "join")
    --end)
	local ply = bot
	
	local nDiffBetweenTeams = 0;
	local m_iLightestTeam = 0;
	local m_iHeaviestTeam = 0;
	local iMostPlayers = 0;
	local iLeastPlayers = game.MaxPlayers() + 1;
	local i = 1; 
	for k,v in ipairs(team.GetAllTeams()) do
			local iNumPlayers = team.NumPlayers(v);

			if ( iNumPlayers < iLeastPlayers ) then
				iLeastPlayers = iNumPlayers;
				m_iLightestTeam = k; 
			end

			if ( iNumPlayers > iMostPlayers ) then
				iMostPlayers = iNumPlayers;
				m_iHeaviestTeam = k; 
			end
	end 

	nDiffBetweenTeams = ( iMostPlayers - iLeastPlayers );
	if IsMvMMap() then
		-- In TF2 MvM, AI bots are invaders (BLU-side), not RED defenders.
		ply:SetTeam(TEAM_BLU)
		ply.IsMVMRobot = true
	else
		if (team.NumPlayers(TEAM_RED) > team.NumPlayers(TEAM_BLU)) then
			ply:SetTeam(TEAM_BLU)	
		elseif (team.NumPlayers(TEAM_RED) < team.NumPlayers(TEAM_BLU)) then
			ply:SetTeam(TEAM_RED)	
		end
	end
	
	bot:Spawn()
	if IsMvMMap() then
		bot:SetTeam(TEAM_BLU)
		bot:SetSkin(1)
		bot.IsMVMRobot = true
	end
	local random = math.random(1,9)
	if (random == 1) then
		bot:SetPlayerClass("scout")
	elseif (random == 2) then
		bot:SetPlayerClass("soldier")
	elseif (random == 3) then
		bot:SetPlayerClass("pyro")
	elseif (random == 4) then
		bot:SetPlayerClass("demoman")
	elseif (random == 5) then
		bot:SetPlayerClass("heavy")
	elseif (random == 6) then
		bot:SetPlayerClass("engineer")
	elseif (random == 7) then
		bot:SetPlayerClass("medic")
	elseif (random == 8) then
		bot:SetPlayerClass("sniper")
	elseif (random == 9) then
		bot:SetPlayerClass("spy")
	end
	bot.TFBot = true

	MsgN("[LeadBot] Bot " .. bot:Nick() .. " with strategy " .. bot.BotStrategy .. " added!")
end

local function LeadBot_S_Add_Zombie(team,class,pos)
	if !navmesh.IsLoaded() then
		ErrorNoHalt("There is no navmesh! Generate one using \"nav_generate\"!\n")
		return
	end

	local botName = GetNextBotName()
	local bot = player.CreateNextBot(botName)
	local teamv = TEAM_RED
	if team == 1 then
		teamv = TEAM_INFECTED
	end

	if !IsValid(bot) then ErrorNoHalt("[LeadBot] Player limit reached!\n") return end
	--bot.LastSegmented = CurTime() + 1

	bot.ControllerBot = ents.Create("ctf_bot_navigator")
	bot.ControllerBot:Spawn()
	bot.ControllerBot:SetOwner(bot)

	bot.LastPath = nil
	bot.CurSegment = 2
	bot.TFBot = true
	bot.IsL4DZombie = true
	bot.BotStrategy = math.random(0, 1)

    --timer.Simple(1, function()
        ----TalkToMe(bot, "join")
    --end)
	bot:SetTeam(teamv)
	bot:SetPlayerClass(class)
	bot:SetPos(pos)
	timer.Simple(0.1, function()
		if IsValid(bot) then
			bot:SetPlayerClass(class)
			bot.TFBot = true
		end
	end)

	MsgN("[LeadBot] Bot " .. bot:Nick() .. " with strategy " .. bot.BotStrategy .. " added!")
end

local function LeadBot_S_Add_Survivor(team,class,pos)
	if !navmesh.IsLoaded() then
		ErrorNoHalt("There is no navmesh! Generate one using \"nav_generate\"!\n")
		return
	end

	local botName = GetNextBotName()
	local bot = player.CreateNextBot(botName)
	local teamv = TEAM_RED
	if team == 1 then
		teamv = TEAM_BLU
	end

	if !IsValid(bot) then ErrorNoHalt("[LeadBot] Player limit reached!\n") return end
	--bot.LastSegmented = CurTime() + 1

	bot.ControllerBot = ents.Create("ctf_bot_navigator")
	bot.ControllerBot:Spawn()
	bot.ControllerBot:SetOwner(bot)

	bot.LastPath = nil
	bot.CurSegment = 2
	bot.TFBot = true
	bot.IsL4DZombie = true
	bot.BotStrategy = math.random(0, 1)

    --timer.Simple(1, function()
        ----TalkToMe(bot, "join")
    --end)
	bot:SetTeam(teamv)
	bot:SetPlayerClass(class)
	bot:SetPos(pos)
	timer.Simple(0.1, function()
		if IsValid(bot) then
			bot:SetPlayerClass(class)
			bot.TFBot = true
		end
	end)

	MsgN("[LeadBot] Bot " .. bot:Nick() .. " with strategy " .. bot.BotStrategy .. " added!")
end
local function LeadBot_S_Add_BlueSurvivor(team,class,pos)
	if !navmesh.IsLoaded() then
		ErrorNoHalt("There is no navmesh! Generate one using \"nav_generate\"!\n")
		return
	end

	local botName = GetNextBotName()
	local bot = player.CreateNextBot(botName)
	local teamv = TEAM_BLU
	if team == 1 then
		teamv = TEAM_BLU
	end

	if !IsValid(bot) then ErrorNoHalt("[LeadBot] Player limit reached!\n") return end
	--bot.LastSegmented = CurTime() + 1

	bot.ControllerBot = ents.Create("ctf_bot_navigator")
	bot.ControllerBot:Spawn()
	bot.ControllerBot:SetOwner(bot)

	bot.LastPath = nil
	bot.CurSegment = 2
	bot.TFBot = true
	bot.IsL4DZombie = true
	bot.BotStrategy = math.random(0, 1)

    --timer.Simple(1, function()
        ----TalkToMe(bot, "join")
    --end)
	bot:SetTeam(teamv)
	bot:SetPlayerClass(class)
	bot:SetPos(pos)
	timer.Simple(0.1, function()
		if IsValid(bot) then
			bot:SetPlayerClass(class)
			bot.TFBot = true
		end
	end)

	MsgN("[LeadBot] Bot " .. bot:Nick() .. " with strategy " .. bot.BotStrategy .. " added!")
end

hook.Add("PostCleanupMap", "LeadBot_S_PostCleanup", function()
	for k, v in pairs(player.GetAll()) do
		if v.TFBot then
			v.ControllerBot = ents.Create("ctf_bot_navigator")
			v.ControllerBot:Spawn()
			v.ControllerBot:SetOwner(v)
		end
	end
end)

hook.Add("PostPlayerDeath", "LeadBot_S_Death", function(bot)
	if bot.TFBot then
		--[[
		local time = 6 
		timer.Simple(time, function()
			if IsValid(bot) and !bot:Alive() then
				if (bot_respawn:GetBool() and !bot:IsL4D()) then

					if (!string.find(bot:GetModel(),"/bot_")) then
						bot:Spawn()
					else
						bot:Kick("No longer needed")
					end
					 
				else
					if (!string.find(bot:GetModel(),"/bot_")) then
						if (!bot.IsL4DZombie) then
							bot:Spawn()
						else
							bot:Kick("No longer needed")
						end
					else
						if (!bot.IsL4DZombie) then
							bot:Spawn()
						else
							bot:Kick("No longer needed")
						end
					end
				end
			end
		end)]]
	end
end)

local BOT_WEAPON_SLOTS = {"primary", "secondary", "melee", "pda", "pda2", "building"}
local BOT_COSMETIC_SLOTS = {"head", "misc"}
local BOT_LOADOUT_SLOTS = {"primary", "secondary", "melee", "pda", "pda2", "building", "head", "misc"}
local botLoadoutCache = {}
local badLoadoutCandidates = {}

local function ClearBotLoadoutCache()
	botLoadoutCache = {}
	badLoadoutCandidates = {}
end

cvars.AddChangeCallback("tf_bot_random_loadouts", ClearBotLoadoutCache, "TFBotLoadoutCacheRandom")
cvars.AddChangeCallback("tf_bot_randomizer_mode", ClearBotLoadoutCache, "TFBotLoadoutCacheMode")

local function BotLoadoutDebug(bot, msg)
	if not CVBool(tf_bot_loadout_debug, false) then return end
	local who = IsValid(bot) and (bot:Nick() .. " [" .. bot:EntIndex() .. "]") or "invalid bot"
	MsgN("[tf_bot_loadout] " .. who .. " - " .. msg)
end

local function ResolveItemByName(name)
	if not isstring(name) or name == "" then return nil end
	local items = tf_items and tf_items.Items
	if not istable(items) then return nil end
	return items[name]
end

local function IsBotWeaponItem(item)
	if not istable(item) then return false end
	local itemClass = tostring(item.item_class or "")
	local prefab = tostring(item.prefab or "")
	if string.find(itemClass, "tf_weapon", 1, true) then return true end
	if string.find(itemClass, "demoshield", 1, true) then return true end
	if string.find(itemClass, "tideturnr", 1, true) then return true end
	if string.find(itemClass, "chargintard", 1, true) then return true end
	if string.find(prefab, "boots", 1, true) then return true end
	return false
end

local function IsBotCosmeticItem(item)
	if not istable(item) then return false end
	local slot = tostring(item.item_slot or "")
	if slot ~= "head" and slot ~= "misc" then return false end
	local prefab = tostring(item.prefab or "")
	local equipRegion = tostring(item.equip_region or "")
	local itemClass = tostring(item.item_class or "")
	local itemName = tostring(item.item_name or "")
	if prefab == "tournament_medal" then return false end
	if equipRegion == "medal" then return false end
	if string.find(itemName, "Taunt", 1, true) then return false end
	if itemClass == "tf_wearable" or string.find(itemClass, "wearable", 1, true) then
		return true
	end
	return false
end

local function BuildLoadoutSlotMap(bot)
	local bySlot = {}
	if not IsValid(bot) or not istable(bot.ItemLoadout) then return bySlot end
	for _, itemName in ipairs(bot.ItemLoadout) do
		local item = ResolveItemByName(itemName)
		if item and isstring(item.item_slot) and item.item_slot ~= "" then
			bySlot[item.item_slot] = itemName
		end
	end
	return bySlot
end

local function HasCategoryDifference(proposedBySlot, currentBySlot, slots)
	for _, slot in ipairs(slots) do
		if proposedBySlot[slot] and proposedBySlot[slot] ~= currentBySlot[slot] then
			return true
		end
	end
	return false
end

local function MarkBadCandidate(className, randomizerMode, slot, itemName)
	local cacheKey = className .. "|" .. (randomizerMode and "1" or "0")
	badLoadoutCandidates[cacheKey] = badLoadoutCandidates[cacheKey] or {}
	badLoadoutCandidates[cacheKey][slot] = badLoadoutCandidates[cacheKey][slot] or {}
	badLoadoutCandidates[cacheKey][slot][itemName] = true
end

local function IsBadCandidate(className, randomizerMode, slot, itemName)
	local cacheKey = className .. "|" .. (randomizerMode and "1" or "0")
	return badLoadoutCandidates[cacheKey] and badLoadoutCandidates[cacheKey][slot] and badLoadoutCandidates[cacheKey][slot][itemName]
end

local function GetRandomLoadoutCandidates(className, randomizerMode)
	local cacheKey = className .. "|" .. (randomizerMode and "1" or "0")
	local cache = botLoadoutCache[cacheKey]
	if cache and cache.nextRefresh > CurTime() then
		return cache.bySlot
	end

	local bySlot = {}
	for _, slot in ipairs(BOT_LOADOUT_SLOTS) do
		bySlot[slot] = {}
	end

	for itemName, item in pairs(tf_items.Items or {}) do
		if not istable(item) then continue end
		local slot = item.item_slot
		if not slot or not bySlot[slot] then continue end
		local isWeapon = IsBotWeaponItem(item)
		local isCosmetic = IsBotCosmeticItem(item)
		if not isWeapon and not isCosmetic then continue end
		if not randomizerMode and (not item.used_by_classes or not item.used_by_classes[className]) then continue end
		-- Use stable item keys from tf_items.Items; display/localized names can collide.
		if isstring(itemName) and itemName ~= "" and not IsBadCandidate(className, randomizerMode, slot, itemName) then
			bySlot[slot][#bySlot[slot] + 1] = itemName
		end
	end

	botLoadoutCache[cacheKey] = {
		bySlot = bySlot,
		nextRefresh = CurTime() + 20,
	}
	return bySlot
end

local function PickRandomSlotItem(slotList, previousName)
	if not istable(slotList) or #slotList == 0 then return nil end
	if #slotList == 1 then return slotList[1] end
	if not previousName then return table.Random(slotList) end

	local pick = previousName
	local maxAttempts = math.min(#slotList * 2, 24)
	for _ = 1, maxAttempts do
		pick = table.Random(slotList)
		if pick ~= previousName then
			return pick
		end
	end
	return pick
end

local function BuildInitialBotLoadoutState(candidates)
	local state = {}
	for _, slot in ipairs(BOT_LOADOUT_SLOTS) do
		state[slot] = PickRandomSlotItem(candidates[slot], nil)
	end
	return state
end

local function MaybeMutateSavedLoadout(savedBySlot, candidates)
	local chance = math.Clamp(CVFloat(tf_bot_loadout_mutation_chance, 0.20), 0, 1)
	if chance <= 0 or math.Rand(0, 1) > chance then return end

	local mutableSlots = {}
	for _, slot in ipairs(BOT_LOADOUT_SLOTS) do
		local list = candidates[slot]
		if istable(list) and #list > 1 and savedBySlot[slot] then
			mutableSlots[#mutableSlots + 1] = slot
		end
	end
	if #mutableSlots == 0 then return end

	local slotToChange = table.Random(mutableSlots)
	local old = savedBySlot[slotToChange]
	savedBySlot[slotToChange] = PickRandomSlotItem(candidates[slotToChange], old)
end

local function EnsureCategoryVariation(savedBySlot, currentBySlot, candidates, slots)
	if HasCategoryDifference(savedBySlot, currentBySlot, slots) then return true end

	local eligible = {}
	for _, slot in ipairs(slots) do
		local list = candidates[slot]
		if istable(list) and #list > 0 then
			eligible[#eligible + 1] = slot
		end
	end
	if #eligible == 0 then return false end

	for _ = 1, 4 do
		local slot = table.Random(eligible)
		savedBySlot[slot] = PickRandomSlotItem(candidates[slot], currentBySlot[slot])
		if HasCategoryDifference(savedBySlot, currentBySlot, slots) then
			return true
		end
	end

	return HasCategoryDifference(savedBySlot, currentBySlot, slots)
end

local function TryEquipSlotChoice(bot, className, randomizerMode, slot, chosenName)
	if not isstring(chosenName) or chosenName == "" then return false end
	local beforeBySlot = BuildLoadoutSlotMap(bot)
	local before = beforeBySlot[slot]
	bot:EquipInLoadout(chosenName, {}, true)
	local afterBySlot = BuildLoadoutSlotMap(bot)
	local after = afterBySlot[slot]
	if after == chosenName then
		return true
	end
	MarkBadCandidate(className, randomizerMode, slot, chosenName)
	BotLoadoutDebug(bot, "candidate failed for slot '" .. slot .. "': " .. tostring(chosenName) .. " (before=" .. tostring(before) .. ", after=" .. tostring(after) .. ")")
	return false
end

local function SetLoadoutReason(bot, reason)
	if IsValid(bot) then
		bot._lastLoadoutRandomizeReason = reason
	end
end

local function IsGmodPlayerBotClass(bot, className)
	local resolved = string.lower(tostring(className or ""))
	if resolved == "gmodplayer" then return true end
	local legacy = string.lower(tostring(IsValid(bot) and bot.playerclass or ""))
	return legacy == "gmodplayer"
end

function TFBot_ApplyRandomLoadout(bot, opts)
	if not IsValid(bot) or not bot.TFBot or bot.IsL4DZombie then return false end
	if bot.TF_MVMManaged or bot.IsMVMRobot then return false end
	if not CVBool(tf_bot_random_loadouts, true) then return false end
	opts = opts or {}
	local now = CurTime()
	if not opts.bypass_cooldown and bot._nextLoadoutApply and bot._nextLoadoutApply > now then
		SetLoadoutReason(bot, "cooldown")
		return false
	end
	bot._nextLoadoutApply = now + (opts.cooldown or 0.2)

	local className = bot:GetPlayerClass()
	if not isstring(className) or className == "" then
		SetLoadoutReason(bot, "no_class")
		BotLoadoutDebug(bot, "abort: no class")
		return false
	end
	if IsGmodPlayerBotClass(bot, className) then
		SetLoadoutReason(bot, "skip_gmodplayer")
		return false
	end
	if not istable(bot.ItemLoadout) or not istable(bot.ItemProperties) then
		if not opts.reinit_attempted then
			BotLoadoutDebug(bot, "ItemLoadout missing, forcing class rebuild and retry")
			bot:SetPlayerClass(className)
			timer.Simple(0.08, function()
				if not IsValid(bot) then return end
				TFBot_ApplyRandomLoadout(bot, {
					cooldown = 0,
					bypass_cooldown = true,
					reinit_attempted = true,
				})
			end)
		end
		SetLoadoutReason(bot, "no_itemloadout")
		return false
	end

	local randomizerMode = CVBool(tf_bot_randomizer_mode, false)
	local candidates = GetRandomLoadoutCandidates(className, randomizerMode)
	if not istable(candidates) then
		SetLoadoutReason(bot, "no_candidates_table")
		return false
	end
	local currentBySlot = BuildLoadoutSlotMap(bot)

	if not istable(bot._savedRandomLoadout) or bot._savedRandomLoadoutClass ~= className or bot._savedRandomizerMode ~= randomizerMode then
		bot._savedRandomLoadout = BuildInitialBotLoadoutState(candidates)
		bot._savedRandomLoadoutClass = className
		bot._savedRandomizerMode = randomizerMode
		EnsureCategoryVariation(bot._savedRandomLoadout, currentBySlot, candidates, BOT_WEAPON_SLOTS)
		EnsureCategoryVariation(bot._savedRandomLoadout, currentBySlot, candidates, BOT_COSMETIC_SLOTS)
	else
		MaybeMutateSavedLoadout(bot._savedRandomLoadout, candidates)
	end

	local changed = false
	for _, slot in ipairs(BOT_LOADOUT_SLOTS) do
		local chosen = bot._savedRandomLoadout[slot]
		if isstring(chosen) and chosen ~= "" then
			local equipped = TryEquipSlotChoice(bot, className, randomizerMode, slot, chosen)
			if equipped then
				changed = true
			else
				local fallback = PickRandomSlotItem(candidates[slot], chosen)
				if fallback and fallback ~= chosen then
					bot._savedRandomLoadout[slot] = fallback
					if TryEquipSlotChoice(bot, className, randomizerMode, slot, fallback) then
						changed = true
					end
				end
			end
		end
	end
	if not changed then
		SetLoadoutReason(bot, "no_changed_slots")
		BotLoadoutDebug(bot, "abort: no slot changed")
		return false
	end

	local finalBySlot = BuildLoadoutSlotMap(bot)
	local hasWeaponDiff = HasCategoryDifference(finalBySlot, currentBySlot, BOT_WEAPON_SLOTS)
	local hasCosmeticDiff = HasCategoryDifference(finalBySlot, currentBySlot, BOT_COSMETIC_SLOTS)
	local hasAnyWeaponCandidates = false
	local hasAnyCosmeticCandidates = false
	for _, slot in ipairs(BOT_WEAPON_SLOTS) do
		if istable(candidates[slot]) and #candidates[slot] > 0 then hasAnyWeaponCandidates = true break end
	end
	for _, slot in ipairs(BOT_COSMETIC_SLOTS) do
		if istable(candidates[slot]) and #candidates[slot] > 0 then hasAnyCosmeticCandidates = true break end
	end
	if hasAnyWeaponCandidates and not hasWeaponDiff then
		SetLoadoutReason(bot, "no_weapon_variation")
		BotLoadoutDebug(bot, "abort: no weapon variation")
		return false
	end
	if hasAnyCosmeticCandidates and not hasCosmeticDiff then
		SetLoadoutReason(bot, "no_cosmetic_variation")
		BotLoadoutDebug(bot, "abort: no cosmetic variation")
		return false
	end

	-- Reapply class to refresh weapons immediately after batched loadout edits.
	bot:SetPlayerClass(className)
	SetLoadoutReason(bot, "ok")
	BotLoadoutDebug(bot, "success: weaponDiff=" .. tostring(hasWeaponDiff) .. " cosmeticDiff=" .. tostring(hasCosmeticDiff))
	return true
end

concommand.Add("tf_bot_print_loadout", function(ply, _, args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	local idx = tonumber(args and args[1] or "")
	if not idx then
		MsgN("Usage: tf_bot_print_loadout <entindex>")
		return
	end
	local target = Entity(idx)
	if not IsValid(target) or not target:IsPlayer() then
		MsgN("Invalid player entindex: " .. tostring(idx))
		return
	end
	MsgN("Loadout for " .. target:Nick() .. " [" .. target:EntIndex() .. "], class=" .. tostring(target:GetPlayerClass()))
	if not istable(target.ItemLoadout) then
		MsgN("  ItemLoadout: nil")
		return
	end
	for i, itemName in ipairs(target.ItemLoadout) do
		local item = ResolveItemByName(itemName)
		local slot = item and item.item_slot or "?"
		MsgN("  [" .. i .. "] slot=" .. tostring(slot) .. " item=" .. tostring(itemName))
	end
end)

local function SafeWeaponAmmo1(weapon, owner)
	if not IsValid(weapon) then return -1 end
	if isfunction(weapon.Ammo1) then
		local ok, value = pcall(weapon.Ammo1, weapon)
		if ok and isnumber(value) then
			return value
		end
	end
	if IsValid(owner) and isfunction(weapon.GetPrimaryAmmoType) then
		local ammoType = weapon:GetPrimaryAmmoType()
		if isnumber(ammoType) and ammoType >= 0 then
			return owner:GetAmmoCount(ammoType)
		end
	end
	return -1
end

local function GetEntityTargetPos(ent)
	if not IsValid(ent) then return nil end
	if ent.Pos then
		return ent.Pos
	end
	if ent.WorldSpaceCenter then
		return ent:WorldSpaceCenter()
	end
	return ent:GetPos()
end

local function IsBlueSideTeamNum(teamNum)
	return teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS
end

local function IsFriendlyToBot(bot, ent)
	if not IsValid(bot) or not IsValid(ent) then return false end
	local botTeam, entTeam
	if GAMEMODE and GAMEMODE.EntityTeam then
		botTeam = GAMEMODE:EntityTeam(bot)
		entTeam = GAMEMODE:EntityTeam(ent)
	else
		botTeam = (isfunction(bot.Team) and bot:Team()) or TEAM_NEUTRAL
		entTeam = (isfunction(ent.Team) and ent:Team()) or TEAM_NEUTRAL
	end
	if IsBlueSideTeamNum(botTeam) then
		return IsBlueSideTeamNum(entTeam)
	end
	return botTeam == entTeam
end

local function IsUsableFriendlyDispenser(bot, ent)
	if not IsValid(bot) or not IsValid(ent) then return false end
	if ent:GetClass() ~= "obj_dispenser" then return false end
	if not IsFriendlyToBot(bot, ent) then return false end

	if isfunction(ent.IsBuilding) and ent:IsBuilding() then return false end
	if isfunction(ent.IsPlacing) and ent:IsPlacing() then return false end
	if isfunction(ent.IsDisabled) and ent:IsDisabled() then return false end
	return true
end

local function IsClosestPlayerEnemy(bot, ent, radius)
	if not IsValid(bot) or not IsValid(ent) then return false end
	local pos = GetEntityTargetPos(ent) or ent:GetPos()
	local closestDist = math.huge
	local closestPlayer = nil

	for _, pl in ipairs(ents.FindInSphere(pos, radius or 1200)) do
		if not IsValid(pl) or not pl:IsPlayer() or not pl:Alive() then continue end
		local t = pl:Team()
		if t == TEAM_SPECTATOR or t == TEAM_NEUTRAL then continue end
		local d = pl:GetPos():DistToSqr(pos)
		if d < closestDist then
			closestDist = d
			closestPlayer = pl
		end
	end

	return IsValid(closestPlayer) and not IsFriendlyToBot(bot, closestPlayer)
end

local function ComputeHealthSearchRange(bot)
	local maxHealth = math.max(bot:GetMaxHealth(), 1)
	local healthRatio = math.Clamp(bot:Health() / maxHealth, 0, 1)
	local critical = math.Clamp(CVFloat(tf_bot_health_critical_ratio, 0.30), 0.05, 0.95)
	local okRatio = math.Clamp(CVFloat(tf_bot_health_ok_ratio, 0.80), critical + 0.05, 1.0)
	local nearRange = math.max(CVFloat(tf_bot_health_search_near_range, 1000), 250)
	local farRange = math.max(CVFloat(tf_bot_health_search_far_range, 2000), nearRange)
	local t = math.Clamp((healthRatio - critical) / math.max(okRatio - critical, 0.01), 0, 1)
	return farRange + t * (nearRange - farRange)
end

local function IsHealthSourceForBot(bot, ent)
	if not IsValid(bot) or not IsValid(ent) then return false end
	local className = string.lower(tostring(ent:GetClass() or ""))

	if className == "func_regenerate" then
		local teamNum = tonumber(ent.TeamNum or ent:GetNWInt("TeamNum", TEAM_NEUTRAL)) or TEAM_NEUTRAL
		if teamNum == TEAM_NEUTRAL then return false end
		return IsBlueSideTeamNum(teamNum) and IsBlueSideTeamNum(bot:Team()) or teamNum == bot:Team()
	end

	if string.find(className, "item_healthkit", 1, true) or string.find(className, "item_healthvial", 1, true) then
		return not ent:IsEffectActive(EF_NODRAW)
	end

	return IsUsableFriendlyDispenser(bot, ent)
end

local function IsAmmoSourceForBot(bot, ent)
	if not IsValid(bot) or not IsValid(ent) then return false end
	local className = string.lower(tostring(ent:GetClass() or ""))

	if className == "func_regenerate" then
		local teamNum = tonumber(ent.TeamNum or ent:GetNWInt("TeamNum", TEAM_NEUTRAL)) or TEAM_NEUTRAL
		if teamNum == TEAM_NEUTRAL then return false end
		return IsBlueSideTeamNum(teamNum) and IsBlueSideTeamNum(bot:Team()) or teamNum == bot:Team()
	end

	if className == "tf_ammo_pack" or string.find(className, "item_ammopack", 1, true) then
		return not ent:IsEffectActive(EF_NODRAW)
	end

	return IsUsableFriendlyDispenser(bot, ent)
end

local function FindBestHealthSource(bot)
	if not IsValid(bot) then return nil end

	local range = ComputeHealthSearchRange(bot)
	local best, bestScore = nil, math.huge
	local threat = IsValid(bot.TargetEnt) and bot.TargetEnt or nil

	for _, ent in ipairs(GetNearbyEntities(bot, range, GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05))) do
		if not IsHealthSourceForBot(bot, ent) then continue end
		if IsClosestPlayerEnemy(bot, ent, 1200) then continue end

		local pos = GetEntityTargetPos(ent)
		if not pos then continue end

		local score = bot:GetPos():DistToSqr(pos)
		local className = ent:GetClass()
		if className == "obj_dispenser" then
			score = score * 1.12
		elseif className == "func_regenerate" then
			score = score * 0.92
		end

		if IsValid(threat) then
			local threatDist = threat:GetPos():DistToSqr(pos)
			if threatDist < (500 * 500) then
				score = score + (500 * 500 - threatDist)
			end
		end

		if score < bestScore then
			best = ent
			bestScore = score
		end
	end

	return best
end

local function IsWeaponDry(owner, weapon)
	if not IsValid(owner) or not IsValid(weapon) then return false end
	if weapon.IsMeleeWeapon then return false end

	local clip = weapon:Clip1()
	local ammo = SafeWeaponAmmo1(weapon, owner)
	if clip == -1 and ammo == -1 then
		-- Weapons without clip/ammo counters should not force scavenging.
		return false
	end
	local hasClip = isnumber(clip) and clip > 0
	local hasAmmo = isnumber(ammo) and ammo > 0
	return not hasClip and not hasAmmo
end

local function IsBotAmmoLow(bot)
	if not IsValid(bot) then return false end

	local activeWeapon = bot:GetActiveWeapon()
	if IsValid(activeWeapon) and IsWeaponDry(bot, activeWeapon) then
		return true
	end

	local rangedCount, dryCount = 0, 0
	for _, wep in ipairs(bot:GetWeapons()) do
		if IsValid(wep) and not wep.IsMeleeWeapon then
			rangedCount = rangedCount + 1
			if IsWeaponDry(bot, wep) then
				dryCount = dryCount + 1
			end
		end
	end

	return rangedCount > 0 and dryCount >= rangedCount
end

local function FindBestAmmoSource(bot)
	if not IsValid(bot) then return nil end

	local range = math.max(CVFloat(tf_bot_ammo_search_range, 5000), 500)
	local best, bestScore = nil, math.huge

	for _, ent in ipairs(GetNearbyEntities(bot, range, GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05))) do
		if not IsAmmoSourceForBot(bot, ent) then continue end
		if IsClosestPlayerEnemy(bot, ent, 1000) then continue end

		local pos = GetEntityTargetPos(ent)
		if not pos then continue end

		local score = bot:GetPos():DistToSqr(pos)
		if ent:GetClass() == "obj_dispenser" then
			score = score * 1.15
		end

		if score < bestScore then
			best = ent
			bestScore = score
		end
	end

	return best
end

local function ShouldSeekHealth(bot)
	if not IsValid(bot) then return false end
	local maxHealth = math.max(bot:GetMaxHealth(), 1)
	local healthRatio = bot:Health() / maxHealth
	local criticalRatio = math.Clamp(CVFloat(tf_bot_health_critical_ratio, 0.30), 0.05, 0.95)
	local okRatio = math.Clamp(CVFloat(tf_bot_health_ok_ratio, 0.80), criticalRatio + 0.05, 1.0)
	local onFire = bot:IsOnFire()
	local inCombat = IsValid(bot.TargetEnt) and bot:Visible(bot.TargetEnt)

	if inCombat or bot.playerclass == "Sniper" then
		return onFire or healthRatio < criticalRatio
	end

	return onFire or healthRatio < okRatio
end

local function NeedsBarrageReloadRetreat(bot)
	if not IsValid(bot) then return false end
	local diff = tonumber(bot.Difficulty) or tonumber(bot_diff:GetInt()) or 1
	if diff < 2 then return false end

	local primary = bot:GetWeapons()[1]
	if not IsValid(primary) then return false end

	local className = string.lower(tostring(primary:GetClass() or ""))
	local isBarrage = string.find(className, "rocketlauncher", 1, true)
		or string.find(className, "grenadelauncher", 1, true)
		or string.find(className, "pipebomblauncher", 1, true)
	if not isBarrage then return false end

	local clip = primary:Clip1()
	local ammo = SafeWeaponAmmo1(primary, bot)
	return isnumber(clip) and clip <= 1 and isnumber(ammo) and ammo > 0
end

local function FindRetreatCoverPos(bot, controller)
	if not IsValid(bot) or not IsValid(controller) then return nil end

	local area = GetSafeRetreatArea(bot)
	if area and area.GetCenter then
		return area:GetCenter()
	end

	local retreatRange = math.max(CVFloat(tf_bot_retreat_to_cover_range, 1000), 300)
	local threat = IsValid(bot.TargetEnt) and bot.TargetEnt or nil

	if IsValid(threat) then
		local away = bot:GetPos() - threat:GetPos()
		away.z = 0
		if away:LengthSqr() < 1 then
			away = Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0)
		end
		away:Normalize()
		local pivot = bot:GetPos() + away * (retreatRange * 0.75)
		local cover = controller:FindSpot("random", { radius = retreatRange, pos = pivot, type = "exposed" })
		if cover then return cover end
	end

	return controller:FindSpot("random", { radius = retreatRange, pos = bot:GetPos(), type = "exposed" })
end

local function ShouldRetreatToCover(bot)
	if not IsValid(bot) then return false end
	if not IsValid(bot.TargetEnt) then return false end
	if IsMvMInvaderBot(bot) then return false end
	if not IsThreatImmediate(bot, bot.TargetEnt) then return false end

	local maxHealth = math.max(bot:GetMaxHealth(), 1)
	local healthRatio = bot:Health() / maxHealth
	local criticalRatio = math.Clamp(CVFloat(tf_bot_health_critical_ratio, 0.30), 0.05, 0.95)
	if healthRatio < criticalRatio or bot:IsOnFire() then
		return true
	end

	return NeedsBarrageReloadRetreat(bot)
end

local function UpdateBotMaintenanceAction(bot, controller)
	if not IsValid(bot) or not IsValid(controller) then return end
	if not bot.TFBot or not bot:Alive() then return end
	if IsMvMInvaderBot(bot) then return end
	if IsMvMBombCarrier(bot) then return end
	if bot:GetNWBool("Taunting", false) then return end

	bot._nextMaintainCheck = bot._nextMaintainCheck or 0
	if bot._nextMaintainCheck > CurTime() then
		return
	end
	bot._nextMaintainCheck = CurTime() + math.Rand(0.3, 0.5)

	if ShouldRetreatToCover(bot) then
		local retreatPos = FindRetreatCoverPos(bot, controller)
		if retreatPos then
			bot.botPos = retreatPos
			bot.routeType = "safest"
			bot._retreatUntil = CurTime() + math.Rand(
				math.max(CVFloat(tf_bot_wait_in_cover_min_time, 1.0), 0.2),
				math.max(CVFloat(tf_bot_wait_in_cover_max_time, 2.0), 0.3)
			)
		end
		return
	end

	if bot._retreatUntil and bot._retreatUntil > CurTime() and IsValid(bot.TargetEnt) and IsThreatImmediate(bot, bot.TargetEnt) then
		local retreatPos = FindRetreatCoverPos(bot, controller)
		if retreatPos then
			bot.botPos = retreatPos
			bot.routeType = "safest"
		end
		return
	end

	if ShouldSeekHealth(bot) then
		local health = FindBestHealthSource(bot)
		if IsValid(health) then
			bot.healthkit = health
			bot.botPos = GetEntityTargetPos(health)
			bot.routeType = "safest"
			return
		end
	end

	if IsBotAmmoLow(bot) then
		local ammo = FindBestAmmoSource(bot)
		if IsValid(ammo) then
			bot.ammokit = ammo
			bot.botPos = GetEntityTargetPos(ammo)
			bot.routeType = "safest"
			return
		end
	end
end

hook.Add("PlayerSpawn", "LeadBot_S_PlayerSpawn", function(bot)
	if (IsValid(bot)) then
		if bot.TFBot then
				if bot.TF_MVMManaged or bot.IsMVMRobot then
					-- Popfile runtime controls class/loadout for managed MvM bots.
					bot:SetFOV(75, 0)
					return
				end
				local class = table.Random(classtb)
				if (tf_bot_force_class:GetString() != "") then
					bot:SetPlayerClass(tf_bot_force_class:GetString())
				else
					if (!bot.IsL4DZombie) then
										
						local random = math.random(1,9)
						if (random == 1) then
							bot:SetPlayerClass("scout")
						elseif (random == 2) then
							bot:SetPlayerClass("soldier")
						elseif (random == 3) then
							bot:SetPlayerClass("pyro")
						elseif (random == 4) then
							bot:SetPlayerClass("demoman")
						elseif (random == 5) then
							bot:SetPlayerClass("heavy")
						elseif (random == 6) then
							bot:SetPlayerClass("engineer")
						elseif (random == 7) then
							bot:SetPlayerClass("medic")
						elseif (random == 8) then
							bot:SetPlayerClass("sniper")
						elseif (random == 9) then
							bot:SetPlayerClass("spy")
						end
						
					end
				end
				timer.Simple(0.1, function()
					if not IsValid(bot) then return end
					TFBot_ApplyRandomLoadout(bot, { cooldown = 0.05 })
				end)
				bot:SetFOV(75, 0) 
		end
	end
end)

hook.Add("CreateEntityRagdoll", "TFBot_FasterRagdollDrop", function(ply, ragdoll)
	if not IsValid(ply) or not ply:IsPlayer() or not ply.TFBot then return end
	if not IsValid(ragdoll) then return end

	local boost = math.max(CVFloat(tf_bot_ragdoll_drop_boost, 280), 0)
	if boost <= 0 then return end

	timer.Simple(0, function()
		if not IsValid(ragdoll) then return end
		local down = Vector(0, 0, -boost)
		ragdoll:SetVelocity(down)
		for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			local phys = ragdoll:GetPhysicsObjectNum(i)
			if IsValid(phys) then
				phys:AddVelocity(down)
			end
		end
	end)
end)

hook.Remove("SetupMove", "LeadBot_Control22")
hook.Add("Move", "LeadBot_Control22", function(bot, mv)
	if _G.TFBOT_VALVE_AI_ACTIVE then return end

	local buttons = 0
	if bot.TFBot and bot:Alive() then
		-- if our targetent is not alive, don't do anything until it's nil
		--cmd:ClearMovement()
		--cmd:ClearButtons()

		if (GetConVar("ai_disabled"):GetBool()) then return end
		local ignoreCombat = bot.TF_MVM_IgnoreCombat == true and IsMvMBombCarrier(bot)
		if ignoreCombat and IsValid(bot.TargetEnt) and ShouldCarrierIgnoreEnemy(bot, bot.TargetEnt) then
			bot.TargetEnt = nil
		end
		if not ignoreCombat then
			if (IsValid(bot.TargetEnt) and not IsBotForcedMeleeOnly(bot)) then
				if (!IsValidTarget(bot,bot.TargetEnt)) then
					bot.TargetEnt = AcquireEnemyTarget(bot)
				end
			else
				bot.TargetEnt = AcquireEnemyTarget(bot)
			end
		end
		if !bot.ControllerBot.nextRandomLook or bot.ControllerBot.nextRandomLook < CurTime() then
			bot.ControllerBot.LookAt = Angle(math.Rand(-45,45),math.Rand(-360,360),0)
			bot.ControllerBot.nextRandomLook = CurTime() + math.Rand(1,3) 
		end
		local friendlyHuman = lookForClosestFriendlyHumanLookingAtMe(bot)
		if (IsValid(friendlyHuman) and (GAMEMODE.IsSetupPhase) and !bot.acknowledgedHuman) then
			if (bot.lookingAt == nil) then
				bot.lookingAt = friendlyHuman
			end
			if (bot:GetNWBool("Taunting",false) == true) then 
				return 
			end 
		
			local shouldvegoneforthehead = bot.lookingAt:EyePos()
			local bone = 1
			shouldvegoneforthehead = bot.lookingAt:GetBonePosition(bone) or bot.lookingAt:WorldSpaceCenter()

			bot:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, bot:EyeAngles(), (shouldvegoneforthehead - bot:GetShootPos()):Angle()))
			if (!bot.acknowledgeHuman) then
				timer.Create("m_acknowledgeAttentionTimer"..bot:EntIndex(),math.Rand(0,2),1,function()
					bot:TFTaunt(tostring(bot:GetActiveWeapon():GetSlot() + 1))
					bot.acknowledgedHuman = true
					bot.lookingAt = nil
				end)
				timer.Create("m_acknowledgeRetryTimer"..bot:EntIndex(),math.Rand(10,20),1,function()
					bot.acknowledgeHuman = false
					bot.acknowledgedHuman = false
				end)
				bot.acknowledgeHuman = true
			end
		end
		if (IsValid(bot.TargetEnt)) then
			if (bot.playerclass == "Sniper") then
				if (IsValid(bot:GetWeapons()[2])) then
					if (bot:GetPos():Distance(bot.TargetEnt:GetPos()) > 200 and bot:GetPos():Distance(bot.TargetEnt:GetPos()) < 750 and bot:GetWeapons()[2].IsProjectileWeapon) then
						bot:SelectWeapon(bot:GetWeapons()[2]:GetClass())
					elseif (bot:GetPos():Distance(bot.TargetEnt:GetPos()) < 200) then
						bot:SelectWeapon(bot:GetWeapons()[3]:GetClass())
					else
						bot:SelectWeapon(bot:GetWeapons()[1]:GetClass())
					end
				end
			end
			if (bot.Difficulty ~= 0) then
				if ((((bot.playerclass == "Scout" || bot.playerclass == "Engineer") and !string.find(bot:GetModel(),"bot")))) then
					if (IsValid(bot:GetWeapons()[2])) then
						if (bot:GetWeapons()[1]:Clip1() == 0 and bot:GetWeapons()[2]:Ammo1() ~= 0 and bot:GetWeapons()[2].IsProjectileWeapon) then
							bot:SelectWeapon(bot:GetWeapons()[2]:GetClass())
						end
					end
				elseif (bot.playerclass == "Soldier") then
					if (IsValid(bot:GetWeapons()[2])) then
						if (bot:GetPos():Distance(bot.TargetEnt:GetPos()) < 500) then
							if (bot:GetWeapons()[1]:Clip1() == 0 and bot:GetWeapons()[2]:Clip1() ~= 0 and bot:GetWeapons()[2].IsProjectileWeapon) then
								bot:SelectWeapon(bot:GetWeapons()[2]:GetClass())
							else
								bot:SelectWeapon(bot:GetWeapons()[1]:GetClass())		
							end
						end
					end
				elseif (bot.playerclass == "Heavy") then
					if (IsValid(bot:GetWeapons()[2])) then
						if (bot:GetWeapons()[1]:Ammo1() == 0 and bot:GetWeapons()[2]:Ammo1() > 0 and bot:GetWeapons()[2].IsProjectileWeapon) then
							bot:SelectWeapon(bot:GetWeapons()[2]:GetClass())
						elseif (bot:GetWeapons()[1]:Ammo1() == 0 and bot:GetWeapons()[2]:Ammo1() == 0 and bot:GetWeapons()[2].IsProjectileWeapon) then
							bot:SelectWeapon(bot:GetWeapons()[3]:GetClass())
						else
							bot:SelectWeapon(bot:GetWeapons()[1]:GetClass())		
						end
					end
				elseif (bot.playerclass == "Pyro" and !string.find(bot:GetModel(),"bot")) then
					if (IsValid(bot:GetWeapons()[2])) then
						if (bot:GetPos():Distance(bot.TargetEnt:GetPos()) > 750) then
							if (bot:GetWeapons()[2]:Clip1() ~= 0) then
								bot:SelectWeapon(bot:GetWeapons()[2]:GetClass())
							else
								bot:SelectWeapon(bot:GetWeapons()[1]:GetClass())		
							end
						end
					end
				elseif (bot.playerclass == "Demoman") then
					if (IsValid(bot:GetWeapons()[2])) then
						if (bot:GetPos():Distance(bot.TargetEnt:GetPos()) < 200) then
							bot:SelectWeapon(bot:GetWeapons()[3]:GetClass())
						else
							bot:SelectWeapon(bot:GetWeapons()[1]:GetClass())
						end
					end
				elseif (bot.playerclass == "Spy") then
					if (IsValid(bot:GetWeapons()[2])) then
						if (bot:GetPos():Distance(bot.TargetEnt:GetPos()) < 200) then
							bot:SelectWeapon(bot:GetWeapons()[2]:GetClass())
						else
							bot:SelectWeapon(bot:GetWeapons()[1]:GetClass())
						end
					end
				end
			end
		end
		
		bot.movingAway = false
	
		local controller = bot.ControllerBot
		if (bot:GetPlayerClass() == "samuraidemo") then
			if controller.nextStuckJump < CurTime() then
				if !bot:Crouching() then
					controller.NextJump = 0
				end
				controller.nextStuckJump = CurTime() + 10
			end
		end
		if (controller ~= nil) then
			if (bot.botPos ~= nil) then
				controller.PosGen = bot.botPos
			end
		end
		if (bot.OverrideModelScale) then
			bot:SetModelScale(bot.OverrideModelScale)
			bot:SetViewOffset(Vector(0,0,72) * bot.OverrideModelScale) 
			bot:SetViewOffsetDucked(Vector(0, 0, 48) * bot.OverrideModelScale)
		end
	
		local moveawayrange = 50 -- SDK parity: default teammate push-away radius
		if IsMvMMap() then
			moveawayrange = 150 -- SDK parity: bots stay farther apart in MvM
		end
		--[[
		if controller.NextCenter > CurTime() and bot:GetNWBool("Taunting",false) != true and bot.botPos then
			if (IsValid(bot:GetActiveWeapon()) and !bot:GetActiveWeapon().IsMeleeWeapon) then
				if controller.strafeAngle == 1 then
					mv:SetSideSpeed(bot:GetRunSpeed())
				elseif controller.strafeAngle == 2 then
					mv:SetSideSpeed(-bot:GetRunSpeed())
				else
					mv:SetForwardSpeed(-bot:GetRunSpeed())
				end
			end
		end]]
			local canRunAvoidance = CVBool(tf_avoidteammates, true) and CVBool(tf_avoidteammates_pushaway, true)
			if PerfEnabled() then
				bot._nextAvoid = bot._nextAvoid or 0
				if bot._nextAvoid > CurTime() then
					canRunAvoidance = false
				else
					bot._nextAvoid = CurTime() + GetAdaptiveInterval(CVFloat(tf_bot_avoidance_interval, 0.10), 0.05)
				end
			end
			if canRunAvoidance then
				local avoidVector = Vector(0, 0, 0)
				local nearby = GetNearbyEntities(bot, moveawayrange, GetAdaptiveInterval(CVFloat(tf_bot_avoidance_interval, 0.10), 0.05))
				local isCarrier = IsAnyFlagCarrier(bot)
				local myClass = string.lower(tostring((bot.GetPlayerClass and bot:GetPlayerClass()) or bot.playerclass or ""))
				local iAmMedic = (myClass == "medic")
				local iAmInSquad = false
				if not iAmMedic and isfunction(bot.IsInASquad) then
					local ok, inSquad = pcall(bot.IsInASquad, bot)
					iAmInSquad = ok and inSquad == true
				end
				if not isCarrier then
					for _, v in ipairs(nearby) do
						if (IsValid(v) and GAMEMODE:EntityTeam(v) == bot:Team() and v:IsPlayer() and v:EntIndex() != bot:EntIndex() and v:Health() > 0 and bot:GetNWBool("Taunting", false) != true) then
							if iAmMedic then
								local teammateClass = string.lower(tostring((v.GetPlayerClass and v:GetPlayerClass()) or v.playerclass or ""))
								if teammateClass ~= "medic" then
									continue
								end
							elseif iAmInSquad then
								continue
							end

							local between = bot:GetPos() - v:GetPos()
							between.z = 0
							local range = between:Length()
							if range > 0 and range < moveawayrange then
								between = between / range
								avoidVector = avoidVector + (1 - (range / moveawayrange)) * between
							end
						end
					end
				end

				avoidVector.z = 0
				if avoidVector:LengthSqr() > 0.0001 then
					avoidVector:Normalize()
					local vAngles = bot:EyeAngles()
					vAngles.x = 0
					local currentdir = vAngles:Forward()
					local rightdir = vAngles:Right()

					local pushStrength = 50 -- SDK parity: fixed separation max speed
					local forwardPush = avoidVector:Dot(currentdir) * pushStrength
					local sidePush = avoidVector:Dot(rightdir) * pushStrength

					bot.movingAway = true 
					bot.pushAwayMove = mv:GetForwardSpeed() + forwardPush
					mv:SetForwardSpeed(mv:GetForwardSpeed() + forwardPush)
					mv:SetSideSpeed(mv:GetSideSpeed() + sidePush)
				end
			end
		if (bot.playerclass == "Medic") then
			for k,v in ipairs(GetNearbyEntities(bot, 1200, GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05))) do
				if (v:IsPlayer() and v:EntIndex() != bot:EntIndex()) then
					if (v.TFBot and v:IsFriendly(bot) and v:Health() > 0 and v.playerclass ~= "Medic") then
						if (!IsValid(bot.TargetEnt)) then
							bot.TargetEnt = v
						end
					end
				end
			end
		end
		if (bot.playerclass == "Medic" && IsValid(bot.TargetEnt) && table.Count(bot:GetWeapons()) > 0) then
			if (bot.TargetEnt:EntityTeam() ~= bot:Team()) then

				if (bot:GetPos():Distance(bot.TargetEnt:GetPos()) < 200) then
					bot:SelectWeapon(bot:GetWeapons()[3]:GetClass())
				else
					bot:SelectWeapon(bot:GetWeapons()[1]:GetClass())
				end

			else

				bot:SelectWeapon(bot:GetWeapons()[2]:GetClass())

			end
		end	

				
		
	


				
			if IsValid(bot.TargetEnt) and bot.TargetEnt:Health() > 0 then
				if (bot:GetPlayerClass() != "tank_l4d") then
					if (bot:GetNWBool("Taunting",false) == true) then 
						return 
					end 
				end	
			
				local shouldvegoneforthehead = bot.TargetEnt:EyePos()
				local bone = 1
				if (bot.playerclass == "Sniper") then
					bone = bot.TargetEnt:LookupBone("bip_head") or bot.TargetEnt:LookupBone("ValveBiped.Bip01_Head1") or 1
				end
				shouldvegoneforthehead = bot.TargetEnt:GetBonePosition(bone) or bot.TargetEnt:WorldSpaceCenter()

				local lerp = 1.2
				if bot.Difficulty == 0 then
					lerp = 0.9
				elseif bot.Difficulty == 2 then
					lerp = 2
				elseif bot.Difficulty == 3 then
					lerp = 4
				end
				bot:SetEyeAngles(LerpAngle(FrameTime() * 5 * lerp, bot:EyeAngles(), (shouldvegoneforthehead - bot:GetShootPos()):Angle()))
			end
			if (iszoomed) then
				if (bot:Visible(bot.TargetEnt)) then
					mv:SetForwardSpeed(0)
					mv:SetMoveAngles(Angle(0,0,0))
					mv:SetSideSpeed(0)
					return
				end
			end
			if bot.shouldFollowIntelCarrier and IsValid(bot.intelcarrier) and !IsValid(bot.TargetEnt) and bot:GetPos():Distance(bot.intelcarrier:GetPos()) < 6000 and bot.intelcarrier:Health() > 0 then
				if (bot:GetPlayerClass() != "tank_l4d") then
					if (bot:GetNWBool("Taunting",false) == true) then 
						return 
					end 
				end	
			
				local shouldvegoneforthehead = bot.intelcarrier:EyePos()
				local bone = 1
				shouldvegoneforthehead = bot.intelcarrier:GetBonePosition(bone)
				if (!bot.isCarryingIntel) then
					bot.botPos = bot.intelcarrier:GetPos()
				end
				local moveDir = bot:GetVelocity()
				moveDir = Vector(moveDir.x, moveDir.y, 0)
				if moveDir:LengthSqr() < 64 and bot.botPos then
					moveDir = bot.botPos - bot:GetPos()
					moveDir.z = 0
				end
				if moveDir:LengthSqr() > 64 then
					bot:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, bot:EyeAngles(), moveDir:GetNormalized():Angle()))
				else
					bot:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, bot:EyeAngles(), (controller.LookAt * 0.5)))
				end
			end
			if (!IsValid(bot.TargetEnt)) then 
				if (bot.lookingAt) then return end
				if (bot:GetPlayerClass() != "tank_l4d") then
					if (bot:GetNWBool("Taunting",false) == true) then 
						return 
					end 
				end	 
				local moveDir = bot:GetVelocity()
				moveDir = Vector(moveDir.x, moveDir.y, 0)
				if moveDir:LengthSqr() < 64 and bot.botPos then
					moveDir = bot.botPos - bot:GetPos()
					moveDir.z = 0
				end
				if moveDir:LengthSqr() > 64 then
					bot:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, bot:EyeAngles(), moveDir:GetNormalized():Angle()))
				else
					bot:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, bot:EyeAngles(), (controller.LookAt * 0.5)))
				end
			end 
	end
end)

local function ComputePathCost(bot, area, fromArea, ladder, length)
	local self = bot

	-- When modular Valve AI is active, reuse its cost model so playerbot A* pathing
	-- gets the same MvM anchor/flank bias as the modular controller.
	if _G.TFBOT_VALVE_AI_ACTIVE and TFBotValveAI and TFBotValveAI.Pathing and TFBotValveAI.Pathing.ComputePathCost then
		local ok, delegated = pcall(TFBotValveAI.Pathing.ComputePathCost, TFBotValveAI.Pathing, bot, area, fromArea, ladder, length)
		if ok and isnumber(delegated) then
			return delegated
		end
	end

    if not fromArea then
        -- First area in path, no cost
        return 0.0
    end


    -- Avoid enemy spawn rooms (MvM invaders share BLU-side spawn ownership).
    local isBlueSide = (self:Team() == TEAM_BLU or self:Team() == TF_TEAM_PVE_INVADERS)
    if (self:Team() == TEAM_RED and HasAreaTFAttribute(area, "spawn_room_blue")) or
       (isBlueSide and HasAreaTFAttribute(area, "spawn_room_red")) then
        if not TFGameRules.RoundHasBeenWon or not TFGameRules:RoundHasBeenWon() then
            return -1.0
        end
    end

    -- Compute distance
    local dist
    if ladder then
        dist = ladder:GetLength()
    elseif length and length > 0 then
        dist = length
    else
        dist = area:GetCenter():Distance(fromArea:GetCenter())
    end

    -- Check vertical height difference
    local deltaZ = fromArea:ComputeAdjacentConnectionHeightChange(area)
    if deltaZ >= 16 then
        if deltaZ >= 64 then
            return -1.0
        end

        -- Apply jump penalty
        dist = dist * 2.0
    elseif deltaZ < -64 then
        return -1.0
    end

    -- Unique random penalty per bot/area to vary routes
    local preference = 1.0
    if self.routeType == "default" and not self:IsMiniBoss() then
        local timeMod = math.floor(CurTime() / 10) + 1
        preference = 1.0 + 50.0 * (1.0 + math.cos(self:EntIndex() * area:GetID() * timeMod))
    end

    if self.routeType == "safest" then
        if IsValid(bot.TargetEnt) then
            local intensity = 1.0
            if area.GetCombatIntensity then
                local ok, value = pcall(area.GetCombatIntensity, area)
                if ok and isnumber(value) then
                    intensity = math.max(value, 0.1)
                end
            end
            dist = dist * 4.0 * intensity
        end

        local isBlueSide = (self:Team() == TEAM_BLU or self:Team() == TF_TEAM_PVE_INVADERS)
        if (self:Team() == TEAM_RED and HasAreaTFAttribute(area, "blue_sentry_danger")) or
           (isBlueSide and HasAreaTFAttribute(area, "red_sentry_danger")) then
            dist = dist * 5.0
        end
    end

    if self.routeType == "mvm_bomb_carrier" then
        if area.IsInCombat and area:IsInCombat() then
            dist = dist * 2.2
        end
        local isBlueSide = (self:Team() == TEAM_BLU or self:Team() == TF_TEAM_PVE_INVADERS)
        if (self:Team() == TEAM_RED and HasAreaTFAttribute(area, "blue_sentry_danger")) or
           (isBlueSide and HasAreaTFAttribute(area, "red_sentry_danger")) then
            dist = dist * 3.2
        end
    end

    if self:GetPlayerClass() == "spy" then
        local enemyTeam = (self:Team() == TEAM_RED) and TEAM_BLU or TEAM_RED

        for _, ent in ipairs(GetCachedEntities("obj_sentrygun")) do
            if IsValid(ent) and ent:Team() == enemyTeam then
                if ent.GetLastKnownArea and ent:GetLastKnownArea() == area then
                    dist = dist * 10.0
                end
            end
        end

        dist = dist + dist * 10.0 * area:GetPlayerCount(self:Team())
    end

	if IsMvMMap() then
		local friendlySpawnAttr = GetFriendlySpawnAttributeForBot(self)

		local anchor = GetMvMNavObjectiveAnchor(self)
		if anchor and IsValid(fromArea) then
			local areaDist = area:GetCenter():DistToSqr(anchor)
			local fromDist = fromArea:GetCenter():DistToSqr(anchor)
			if self.routeType == "mvm_bomb_carrier" then
				if areaDist > fromDist then
					dist = dist * 2.35
				else
					dist = dist * 0.72
				end
			else
				if areaDist > fromDist then
					dist = dist * 1.45
				else
					dist = dist * 0.92
				end
			end
		end
	end
		

    local cost = dist * preference

    if area:HasAttributes(NAV_MESH_FUNC_COST) then
        cost = cost * area:ComputeFuncNavCost(self)
    end

    return cost + fromArea:GetCostSoFar()
end
hook.Add("SetupMove", "LeadBot_Control", function(bot, mv, cmd)
	if _G.TFBOT_VALVE_AI_ACTIVE then return end
	local buttons = 0
	if bot.TFBot then
		if (GetConVar("ai_disabled"):GetBool()) then return end
		-- if our targetent is not alive, don't do anything until it's nil
		local canSense = true
		if PerfEnabled() then
			bot._nextSense = bot._nextSense or 0
			if bot._nextSense > CurTime() then
				canSense = false
			else
				bot._nextSense = CurTime() + GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05)
			end
		end
		if canSense then
			local isCarrier = IsMvMBombCarrier(bot) and bot.TF_MVM_IgnoreCombat == true
			if not isCarrier then
				local acquired = AcquireEnemyTarget(bot)
				if IsValid(acquired) then
					bot.TargetEnt = acquired
				end
			elseif IsValid(bot.TargetEnt) and ShouldCarrierIgnoreEnemy(bot, bot.TargetEnt) then
				bot.TargetEnt = nil
			end
		end
		local controller = bot.ControllerBot
		bot.movement = mv
		if bot:IsPlayer() and !bot:IsBot() then
			bot:PrintMessage(HUD_PRINTCENTER, "You're being controlled by a bot, ask an admin to stop being controlled.")
		end
		bot.ControllerBot:SetPos(bot:GetPos())

		if (IsValid(bot.TargeEntity) and bot.TargeEntity:GetClass() == "tf_wearable_item_demoshield" and bot.TargeEntity.dt.Ready and bot.botPos) then
			bot.TargeEntity:StartCharging()
		end
		
		local intel
		local fintel
		local intelcap
		local fintelcap
		local targetpos = Vector(0, 0, 0)
		bot.shouldFollowIntelCarrier = false
		local function ShouldFollowIntelCarrier(botPly, carrier, isFriendlyCarrier)
			if not IsValid(botPly) or not IsValid(carrier) then return false end
			if botPly:EntIndex() == carrier:EntIndex() then return false end

			local className = string.lower(tostring(botPly:GetPlayerClass() or ""))
			if isFriendlyCarrier and className == "medic" then
				return true
			end
			if botPly:GetPos():DistToSqr(carrier:GetPos()) < (700 * 700) then
				return true
			end

			local hash = (botPly:EntIndex() + carrier:EntIndex()) % 5
			if isFriendlyCarrier then
				return hash == 0 or hash == 1
			end
			return hash == 0
		end
		local canUpdateObjective = true
		if PerfEnabled() then
			bot._nextObjective = bot._nextObjective or 0
			if bot._nextObjective > CurTime() then
				canUpdateObjective = false
			else
				bot._nextObjective = CurTime() + GetAdaptiveInterval(CVFloat(tf_bot_objective_interval, 0.75), 0.1)
			end
		end
		if canUpdateObjective then
			bot.TF_MVM_IgnoreCombat = false
			if escortAvailable(bot) and !GAMEMODE.RoundHasWinner then -- Payload AI
					local payloadPos = GetPayloadObjectivePosition(bot)
					if payloadPos then
						bot.botPos = payloadPos
					else
						for _, trigger in pairs(GetCachedEntities("trigger_capture_area")) do
							if IsValid(trigger) then
								intel = trigger
								break
							end
						end

						if IsValid(intel) then
							bot.botPos = intel.Pos or intel:GetPos()
						end
					end
					
					--bot.LastSegmented = CurTime() + math.Rand(0.5, 1)

			elseif flagAvailable(bot) and !GAMEMODE.RoundHasWinner then -- CTF AI
				for k, v in pairs(GetCachedEntities("item_teamflag")) do
					if v.TeamNum ~= bot:Team() then
						intel = v
					else
						fintel = v
					end
				end

				for k, v in pairs(GetCachedEntities("func_capturezone")) do
					if v.TeamNum ~= bot:Team() then
						intelcap = v 
					else
						fintelcap = v
					end
				end

				if IsValid(intel) and !intel.Carrier then -- neither intel has a capture
					targetpos = intel:GetPos()
					bot.intelcarrier = nil
				elseif IsValid(intel) and intel.Carrier and intel.Carrier:EntIndex() == bot:EntIndex() and IsValid(fintelcap) then -- or if friendly intelligence has capture
					targetpos = fintelcap.Pos -- goto friendly cap spot
					bot.intelcarrier = nil
				elseif IsValid(intel) and IsValid(intel.Carrier) and bot:EntIndex() != intel.Carrier:EntIndex() then -- or else if we have it already carried
					if ShouldFollowIntelCarrier(bot, intel.Carrier, true) then
						targetpos = intel.Carrier:GetPos()
						bot.intelcarrier = intel.Carrier
						bot.shouldFollowIntelCarrier = true
					else
						targetpos = IsValid(fintelcap) and fintelcap.Pos or intel:GetPos()
						bot.intelcarrier = nil
					end
				elseif IsValid(fintel) and fintel.Carrier and bot:EntIndex() != fintel.Carrier:EntIndex() then -- if our intel is being stolen...
					if ShouldFollowIntelCarrier(bot, fintel.Carrier, false) then
						targetpos = fintel.Carrier:GetPos() -- defend our intel
						bot.intelcarrier = fintel.Carrier
						bot.shouldFollowIntelCarrier = true
					else
						targetpos = IsValid(fintelcap) and fintelcap.Pos or fintel:GetPos()
						bot.intelcarrier = nil
					end
				elseif IsValid(fintelcap) then
					targetpos = fintelcap.Pos -- move to the bomb, the flag is currently invalid until a bot gets it
					bot.intelcarrier = nil
				end	

				bot.botPos = targetpos
				
				--bot.LastSegmented = CurTime() + math.Rand(0.5, 1)
			elseif controlPointAvailable(bot) and not IsMvMMap() and !GAMEMODE.RoundHasWinner then -- CP AI
				local cpDecision = SelectControlPointObjective(bot)
				if cpDecision and cpDecision.targetPos then
					bot.botPos = cpDecision.targetPos
					bot.intelcarrier = nil
					bot.shouldFollowIntelCarrier = false

					if cpDecision.defend and IsValid(cpDecision.targetEnt) then
						bot.TargetEnt = cpDecision.targetEnt
					end
				end
			elseif bombAvailable(bot) and IsMvMMap() and !GAMEMODE.RoundHasWinner then -- MvM objective selector (Phase 1)
				local mvmDecision = SelectMvMAction(bot, controller, ShouldFollowIntelCarrier)
				if mvmDecision then
					bot.mvmAction = mvmDecision.action or MvMAction.None
					bot.isCarryingIntel = mvmDecision.isCarryingBomb == true
					bot.intelcarrier = mvmDecision.intelCarrier
					bot.shouldFollowIntelCarrier = mvmDecision.followCarrier == true
					if mvmDecision.routeType then
						bot.routeType = mvmDecision.routeType
					elseif bot.mvmAction == MvMAction.DefendBomb or bot.mvmAction == MvMAction.DefendHatch then
						bot.routeType = "safest"
					else
						bot.routeType = "mvm_push"
					end
					bot.TF_MVM_IgnoreCombat = mvmDecision.ignoreCombat == true

					if IsValid(mvmDecision.targetEnt) then
						bot.TargetEnt = mvmDecision.targetEnt
					end

					targetpos = mvmDecision.targetPos
					if targetpos then
						bot.botPos = targetpos
					end
				end
			else
				if (!IsValid(bot.TargetEnt) || !bot.TargetEnt:Alive()) then
					-- our enemy doesn't exist anymore, find a random spot every 10 seconds
					local reachedPos = isvector(bot.botPos) and bot:GetPos():DistToSqr(bot.botPos) < (bot:GetModelRadius() * 1.15) ^ 2
					if (CurTime() > controller.LastSegmented || reachedPos) then
						local roamPos = controller:FindSpot("random", {radius = 4500, pos = bot:GetPos(), type = "exposed"})
						if not roamPos then
							local navArea = navmesh.GetNearestNavArea(bot:GetPos(), false, 4000, false, false, TEAM_ANY)
							if navArea then
								roamPos = navArea:GetRandomPoint()
							end
						end
						bot.botPos = roamPos or bot.botPos
			        	controller.LastSegmented = CurTime() + math.Rand(3, 6)
					end
				else
					if (bot:Visible(bot.TargetEnt)) then
						bot.botPos = bot.TargetEnt:GetPos()
					else
						if (CurTime() > controller.LastSegmented) then
							local chasePos = controller:FindSpot("random", {radius = 3000, pos = bot.TargetEnt:GetPos(), type = "exposed"})
							bot.botPos = chasePos or bot.TargetEnt:GetPos()
							controller.LastSegmented = CurTime() + math.Rand(2, 4)
						end
					end
				end
			end
		end
		
			UpdateBotMaintenanceAction(bot, controller)

			if IsMvMBombCarrier(bot) then
				local deployZone = GetMvMBombDeployZone()
				local deployPos = GetObjectivePos(deployZone)
				if deployPos then
					bot.botPos = deployPos
				end
			end
			
		if (GAMEMODE.RoundHasWinner && GAMEMODE.WinningTeam != bot:Team()) then
            local navArea = GetSafeRetreatArea(bot) 
            if navArea then
				bot.botPos = navArea:GetCenter()
			end
		end
		for _, v in ipairs(GetNearbyEntities(bot, 600, GetAdaptiveInterval(CVFloat(tf_bot_objective_interval, 0.75), 0.1))) do
			if not IsValid(v) then continue end
			if IsMvMInvaderBot(bot) then continue end
			if (v:GetClass() == "obj_teleporter" and (not IsValid(bot.intelcarrier) or v:EntIndex() != bot.intelcarrier:EntIndex())) then
				if (v:IsEntrance() and IsValid(v:GetLinkedTeleporter()) and v:IsFriendly(bot) and v:IsReady()) then 
					bot.botPos = v:GetPos()
				end
			end
		end
		for _, intel in pairs(GetCachedEntities("item_teamflag_mvm")) do
						
			if IsValid(intel.Carrier) and bot:GetPos():Distance(intel.Carrier:GetPos()) < 180 and bot:EntIndex() != intel.Carrier:EntIndex() then -- dont move if too close!
				bot.tooclose = true
			else
				bot.tooclose = false
			end

		end
		if bot.playerclass == "Medic" or bot:GetPlayerClass() == "giantmedic" then
				----print(intel)
			local targetply = player.GetAll()[1]
			local fintel
			for k, v in pairs(player.GetBots()) do
				
				for _, intel in pairs(GetCachedEntities("item_teamflag_mvm")) do
					fintel = intel
					if (IsValid(intel.Carrier)) then
						if intel.Carrier ~= bot and bot:IsFriendly(intel.Carrier) then
							targetply = v
						end
					end
				end
				if v ~= bot and bot:IsFriendly(v) and v:Health() < v:GetMaxHealth() / 2 then
					targetply = v
				end
			end
	
			if IsValid(fintel) and targetply ~= fintel.Carrier and targetply:Health() > targetply:GetMaxHealth() / 2 then
				targetply = nil
			end
	
			if IsValid(targetply) then
				targetpos = targetply:GetPos()
				local trace = util.QuickTrace(bot:EyePos(), targetply:EyePos() - bot:EyePos(), bot)
				debugoverlay.Line(trace.StartPos, trace.HitPos, 1, Color( 255, 255, 0 ))
	
				if trace.Entity == targetply and targetply:IsFriendly(bot) then
					bot.TargetEnt = targetply
				end
			end
		end
		------------------------------
		 -----[[ENTITY DETECTION]]-----
		------------------------------
		if (not IsMvMInvaderBot(bot) and IsMvMSentryBuster(bot)) then
				local className = IsValid(bot.TargetEnt) and bot.TargetEnt:GetClass() or ""
				if IsValid(bot.TargetEnt) and (bot.TargetEnt:IsPlayer() or (className != "obj_sentrygun" and className != "obj_dispenser" and className != "obj_teleporter")) then
					bot.TargetEnt = nil
				end

				if !IsValid(bot.TargetEnt) or bot.TargetEnt:IsFriendly(bot) then
					bot.TargetEnt = SelectSentryBusterTarget(bot)
				end

				if IsValid(bot.TargetEnt) then
					bot.botPos = bot.TargetEnt:GetPos()
					bot.shouldFollowIntelCarrier = false
					-- Mirror TF2 buster intent: ignore player combat and beeline objective.
					bot.tooclose = false
				end
		end
		------------------------------
		--------[[BOT LOGIC]]---------
		------------------------------
	
		if IsValid(bot.TargetEnt) then
			
			-- move to our target
			local distance = bot.TargetEnt:GetPos():Distance(bot:GetPos())

	
			-- back up if the target is really close
			-- TODO: find a random spot rather than trying to back up into what could just be a wall
			
			if IsBotForcedMeleeOnly(bot) then
				ForceBotMeleeWeapon(bot)
			end
		end

		if bot.TF_MVM_IgnoreCombat and IsValid(bot.TargetEnt) and ShouldCarrierIgnoreEnemy(bot, bot.TargetEnt) then
			bot.TargetEnt = nil
		end

		if (!bot.lookingAt and bot:GetNWBool("Taunting",false) != true) then
			if (bot:GetPlayerClass() == "engineer" and not IsMvMInvaderBot(bot)) then
				for k, v in pairs(GetCachedEntities("obj_sentrygun")) do
						
					if (IsValid(bot.SentryGun) and bot.SentryGun:GetLevel() == 3 and bot.SentryGun:Health() == bot.SentryGun:GetMaxHealth() and !IsValid(bot.Dispenser)) then
						bot.BuiltDispenser = false
						bot.botPos = v:GetPos()
					else
						if IsValid(v) and bot:GetPos():Distance(v:GetPos()) < 120 and bot:EntIndex() == v:GetBuilder():EntIndex() then -- dont move if too close!
							bot.tooclose = true
							bot.isCarryingIntel = true
							if (bot:GetActiveWeapon():GetClass() != bot:GetWeapons()[3]:GetClass()) then
								bot:SelectWeapon(bot:GetWeapons()[3]:GetClass())
							end
							if (CurTime() > bot:GetActiveWeapon():GetNextPrimaryFire()) then
								bot:GetActiveWeapon():PrimaryAttack()
							end
							bot:AddFlags(FL_DUCKING)
							
							local lerp = 1.2
							bot:SetEyeAngles(LerpAngle(0.2, bot:EyeAngles(), (v:GetPos() - bot:GetShootPos()):Angle()))
							--mv:SetSideSpeed(0)
							--mv:SetMoveAngles(Angle(0,0,0))
						else
							bot.tooclose = false
							bot.isCarryingIntel = false
							bot:RemoveFlags(FL_DUCKING)
						end

						if IsValid(v) and bot:EntIndex() == v:GetBuilder():EntIndex() and v:GetClass() == "obj_sentrygun" then -- dont move if too close!
							bot.botPos = v:GetPos()
						elseif (!IsValid(v)) then
							bot.BuiltSentry = false
						end
					end
				end
			end
		end
			
		cmd:SetButtons(buttons)
	end
end)

hook.Remove("PlayerSpawn", "leadbot_spawn")

local function DropFlagsForCarrier(carrier)
	if not carrier then return end

	for _, intel in ipairs(ents.FindByClass("item_teamflag")) do
		if IsValid(intel) and intel.Carrier == carrier then
			intel:Drop(true)
		end
	end

	for _, intel in ipairs(ents.FindByClass("item_teamflag_mvm")) do
		if IsValid(intel) and intel.Carrier == carrier then
			intel:Drop(true)
		end
	end
end

hook.Add("PlayerDisconnected", "leadbot_removed", function(ply)
	for k,v in ipairs(player.GetAll()) do
		if (k < 0) then
			GAMEMODE.round_active = false
		end
	end
	DropFlagsForCarrier(ply)
	if IsValid(ply) and IsValid(ply.ControllerBot) then
		ply.ControllerBot:Remove()
	end
	
	ply:StopSound("MVM.GiantScoutLoop")
	ply:StopSound("MVM.GiantSoldierLoop")
	ply:StopSound("MVM.GiantPyroLoop")
	ply:StopSound("MVM.GiantDemomanLoop")
	ply:StopSound("MVM.GiantHeavyLoop")
end)

hook.Add("EntityRemoved", "leadbot_drop_flag_on_removed_carrier", function(ent)
	if not ent or not ent.IsPlayer or not ent:IsPlayer() then return end
	DropFlagsForCarrier(ent)
end)

local desiredBotQuota = 0

local function IsManagedTFBot(ply)
	if not IsValid(ply) or not ply:IsBot() then return false end
	if ply.TF_MVMManaged then return true end
	return ply.TFBot == true and not ply.IsL4DZombie
end

local function CountManagedTFBots()
	local count = 0
	for _, bot in ipairs(player.GetBots()) do
		if IsManagedTFBot(bot) then
			count = count + 1
		end
	end
	return count
end

local function SetQuotaTarget(rawValue)
	local n = tonumber(rawValue or 0) or 0
	desiredBotQuota = math.max(math.floor(n), 0)
end

local function EnforceBotQuota()
	if desiredBotQuota < 0 then
		desiredBotQuota = 0
	end

	local current = CountManagedTFBots()
	if current < desiredBotQuota then
		-- Pace spawning to avoid large one-tick spikes.
		local toAdd = math.min(desiredBotQuota - current, 2)
		for _ = 1, toAdd do
			LeadBot_S_Add()
		end
		return
	end

	if current <= desiredBotQuota then return end

	local toRemove = current - desiredBotQuota
	for _, bot in ipairs(player.GetBots()) do
		if toRemove <= 0 then break end
		if not IsManagedTFBot(bot) then continue end
		bot:Kick("Bot quota reduced")
		toRemove = toRemove - 1
	end
end

hook.Add("Think", "TFBot_QuotaManager", function()
	if desiredBotQuota <= 0 then return end
	if game.SinglePlayer() then return end
	if not navmesh.IsLoaded() then return end
	if IsMvMMap() and TF_MVM and TF_MVM.Runtime and TF_MVM.Runtime.IsManagedActive and TF_MVM.Runtime:IsManagedActive() then
		-- POP-driven MvM owns spawning; don't inject generic quota bots into active waves.
		return
	end
	EnforceBotQuota()
end)

hook.Add("Think", "TFBot_MovementWatchdog", function()
	if not navmesh.IsLoaded() then return end

	local now = CurTime()
	for _, bot in ipairs(player.GetBots()) do
		if IsMvMMap() and IsValid(bot) and (bot.TF_MVMManaged or bot.IsMVMRobot) and bot:Team() ~= TEAM_BLU then
			-- Recover from external team changes pushing managed MvM bots into invalid/unassigned teams.
			bot:SetTeam(TEAM_BLU)
			bot:SetSkin(1)
		end

		if not IsManagedTFBot(bot) then continue end
		if not bot:Alive() then continue end
		if bot:GetNWBool("Taunting", false) then continue end

		local hasTarget = IsValid(bot.TargetEnt)
		local hasObjective = bot.botPos ~= nil

		-- Always maintain some objective anchor to prevent idle standstill.
		if not hasObjective and not hasTarget then
			if IsMvMMap() then
				local deploy = GetMvMBombDeployZone()
				bot.botPos = GetObjectivePos(deploy) or bot.botPos
			elseif IsValid(bot.ControllerBot) then
				bot.botPos = bot.ControllerBot:FindSpot("random", {radius = 2500}) or bot.botPos
			end
		end

		local lastPos = bot._moveWatchPos
		if not lastPos then
			bot._moveWatchPos = bot:GetPos()
			bot._moveWatchStamp = now
			continue
		end

		local movedSqr = bot:GetPos():DistToSqr(lastPos)
		if movedSqr > (32 * 32) then
			bot._moveWatchPos = bot:GetPos()
			bot._moveWatchStamp = now
			continue
		end

		local stallFor = now - (bot._moveWatchStamp or now)
		if stallFor < 2.2 then continue end
		if bot._nextWatchdogUnstuck and bot._nextWatchdogUnstuck > now then continue end

		-- Hard reset pathing state so StartCommand rebuilds a fresh route.
		bot.path = nil
		bot.targetArea = nil
		bot.lastRePath = 0
		bot.lastRePath2 = 0

		if bot:GetNWBool("InRespawnRoom", false) and IsMvMInvaderBot(bot) then
			bot.botPos = GetSpawnExitTargetPos(bot) or bot.botPos
		elseif IsValid(bot.ControllerBot) then
			local around = bot.botPos or bot:GetPos()
			bot.botPos = bot.ControllerBot:FindSpot("random", {radius = 1400, pos = around, type = "exposed"}) or bot.botPos
		end

		bot._moveWatchPos = bot:GetPos()
		bot._moveWatchStamp = now
		bot._nextWatchdogUnstuck = now + 0.75
	end
end)

hook.Add("OnPlayerReady", "leadbot_ready", function()
	RunConsoleCommand("lk.ready_bots")
end)

local function GetTeamRespawnPoint(ply)
	if not IsValid(ply) then return nil end

	local teamID = ply:Team()
	local primarySpawns = nil
	if teamID == TEAM_RED then
		primarySpawns = ents.FindByClass("info_player_redspawn")
	elseif teamID == TEAM_BLU or teamID == TEAM_GREEN or teamID == TF_TEAM_PVE_INVADERS then
		primarySpawns = ents.FindByClass("info_player_bluspawn")
	end

	if istable(primarySpawns) and #primarySpawns > 0 then
		return table.Random(primarySpawns)
	end

	local teamSpawns = {}
	for _, spawn in ipairs(ents.FindByClass("info_player_teamspawn")) do
		if not IsValid(spawn) then continue end
		local kv = spawn:GetKeyValues()
		local startDisabled = kv and tonumber(kv.StartDisabled or 0) or 0
		local spawnTeam = kv and tonumber(kv.TeamNum or -1) or -1
		if kv and startDisabled == 0 then
			if teamID == TEAM_RED and spawnTeam == 2 then
				table.insert(teamSpawns, spawn)
			elseif (teamID == TEAM_BLU or teamID == TEAM_GREEN or teamID == TF_TEAM_PVE_INVADERS) and spawnTeam == 3 then
				table.insert(teamSpawns, spawn)
			end
		end
	end

	if #teamSpawns > 0 then
		return table.Random(teamSpawns)
	end

	return nil
end

local function MoveToTeamRespawnPoint(ply)
	local spawn = GetTeamRespawnPoint(ply)
	if not IsValid(spawn) then return end

	ply:SetPos(spawn:GetPos() + Vector(0, 0, 4))
	ply:SetEyeAngles(spawn:GetAngles())
	ply:SetLocalVelocity(vector_origin)
end

local function RespawnBotAtTeamSpawn(bot)
	if not IsValid(bot) or bot:Alive() then return end
	bot:Spawn()
	timer.Simple(0, function()
		if IsValid(bot) and bot:Alive() then
			MoveToTeamRespawnPoint(bot)
		end
	end)
end

hook.Add("StartCommand", "leadbot_control", function(bot, cmd)
	if _G.TFBOT_VALVE_AI_ACTIVE then return end
	--[[if (bot.ControllingPlayer) then
		bot.ControlledButtons = cmd:GetButtons()
		bot.ControlledImpulse = cmd:GetImpulse()
		bot.ControlledMouseWheel = cmd:GetMouseWheel()
		bot.ControlledMoveForward = cmd:GetForwardMove()
		bot.ControlledMouseX = cmd:GetMouseX()
		bot.ControlledMouseY = cmd:GetMouseY()
		bot.ControlledUpMove = cmd:GetUpMove()
		bot.ControlledSideMove = cmd:GetSideMove()
		if (bot.ControllingPlayer:IsNPC()) then
			if (bot:KeyDown(IN_ATTACK)) then
				if (!bot.ControllingPlayer:IsCurrentSchedule(SCHED_MELEE_ATTACK1)) then
					bot.ControllingPlayer:SetSchedule(SCHED_MELEE_ATTACK1)
				end
			elseif (bot:KeyDown(IN_ATTACK2)) then
				if (!bot.ControllingPlayer:IsCurrentSchedule(SCHED_RANGE_ATTACK1)) then
					bot.ControllingPlayer:SetSchedule(SCHED_RANGE_ATTACK1)
				end
			end
			if (bot.ControlledMoveForward > 0 && !bot:KeyDown(IN_ATTACK)) then
				bot.ControllingPlayer:SetSaveValue( "m_vecLastPosition", bot:GetAimVector() * 500 )
				if (bot:KeyDown(IN_SPEED)) then
					bot.ControllingPlayer:SetSchedule( SCHED_FORCED_GO_RUN )
				else
					bot.ControllingPlayer:SetSchedule( SCHED_FORCED_GO )
				end
				bot.ControllingPlayer:SetMoveVelocity(bot:GetAimVector() * 1100)
			end
		end
	end
	if (bot.BeingControlled && IsValid(bot.BeingControlledBy)) then
		cmd:ClearMovement()
		cmd:ClearButtons()
		cmd:SetButtons(bot.BeingControlledBy.ControlledButtons)
		cmd:SetForwardMove(bot.BeingControlledBy.ControlledMoveForward)
		cmd:SetSideMove(bot.BeingControlledBy.ControlledSideMove)
		cmd:SetMouseX(bot.BeingControlledBy.ControlledMouseX)
		cmd:SetMouseY(bot.BeingControlledBy.ControlledMouseY)
		cmd:SetMouseWheel(bot.BeingControlledBy.ControlledMouseWheel)
		cmd:SetImpulse(bot.BeingControlledBy.ControlledImpulse)
		cmd:SetUpMove(bot.BeingControlledBy.ControlledUpMove)
		cmd:SetViewAngles(bot.BeingControlledBy:EyeAngles())
		bot:SetEyeAngles(bot.BeingControlledBy:EyeAngles())
		if (bot.TFBot) then
			bot.WasTFBot = bot.TFBot
			bot.TFBot = false
		end
	end]]
	if bot.TFBot and bot:Alive() then
			-- if our targetent is not alive, don't do anything until it's nil
			local buttons = 0
			if (bot:GetPlayerClass() == "gmodplayer" and bot.botPos) then
				if (bot:GetPos():Distance(bot.botPos) > bot:GetModelRadius() * 2) then
					buttons = buttons + IN_SPEED
				end
			end
			if IsBotForcedMeleeOnly(bot) then
				ForceBotMeleeWeapon(bot)
			end
			local controller = bot.ControllerBot
			--cmd:ClearMovement()
			--cmd:ClearButtons()
			if (GetConVar("ai_disabled"):GetBool()) then return end
							
						
		if (!bot.lookingAt and bot:GetNWBool("Taunting",false) != true) then
			if (string.find(game.GetMap(),"mvm_")) then
				if (bot.TargetEnt == nil) then
					if (IsValid(bot.SentryGun) and bot.SentryGun:GetLevel() == 3 and bot.SentryGun:Health() == bot.SentryGun:GetMaxHealth()) then
						if (IsValid(bot.SentryGunHint) and !bot.BuiltDispenser and bot:Team() != TEAM_BLU) then
							bot.botPos = bot.SentryGunHint:GetPos()
							bot:SetEyeAngles(bot:GetEyeAngles() + Angle(180,0,0))
							bot:Build(0,0)
							if (bot:GetPos():Distance(bot.SentryGunHint:GetPos()) < 150) then
								buttons = buttons + IN_ATTACK
								bot.BuiltDispenser = true
								timer.Simple(0.2, function()
									bot:SelectWeapon(bot:GetWeapons()[3]:GetClass())
								end)
							end
						end
					else
						if (bot:GetPlayerClass() == "engineer" and !IsValid(bot.SentryGunHint) and !bot.BuiltSentry and bot:Team() != TEAM_BLU) then
							bot.SentryGunHint = table.Random(GetCachedEntities("bot_hint_sentrygun"))
						elseif (IsValid(bot.SentryGunHint) and !bot.BuiltSentry and bot:Team() != TEAM_BLU) then
							bot.botPos = bot.SentryGunHint:GetPos()
							bot:Build(2,0)
							if (bot:GetPos():Distance(bot.SentryGunHint:GetPos()) < 150) then
								buttons = buttons + IN_ATTACK
								bot.BuiltSentry = true
								timer.Simple(0.2, function()
									bot:SelectWeapon(bot:GetWeapons()[3]:GetClass())
								end)
							end
						elseif (bot:GetPlayerClass() == "engineer" and !IsValid(bot.SentryGunHint) and !bot.BuiltSentry and bot:Team() == TEAM_BLU) then
							bot.SentryGunHint = table.Random(GetCachedEntities("bot_hint_sentrygun"))
						elseif (IsValid(bot.SentryGunHint) and !bot.BuiltSentry and bot:Team() == TEAM_BLU) then
							bot.botPos = bot.SentryGunHint:GetPos()
							bot:Build(1,1)
							bot:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, bot:EyeAngles(), (bot.SentryGunHint:GetPos() - bot:GetShootPos()):Angle()))
							if (bot:GetPos():Distance(bot.SentryGunHint:GetPos()) < 150) then
								buttons = buttons + IN_ATTACK
								bot.BuiltSentry = true
								timer.Simple(0.2, function()
									bot:SelectWeapon(bot:GetWeapons()[3]:GetClass())
								end)
							end
						end
					end
				end
			else
			
				if (IsValid(bot.SentryGun) and bot.SentryGun:GetLevel() == 3 and bot.SentryGun:Health() == bot.SentryGun:GetMaxHealth()) then
					if (IsValid(bot.SentryGunHint) and !bot.BuiltDispenser and bot:Team() != TEAM_BLU) then
						bot.botPos = bot.SentryGunHint:GetPos()
						bot:SetEyeAngles(bot:GetEyeAngles() + Angle(180,0,0))
						bot:Build(0,0)
						if (bot:GetPos():Distance(bot.SentryGunHint:GetPos()) < 150) then
							buttons = buttons + IN_ATTACK
							bot.BuiltDispenser = true
							timer.Simple(0.2, function()
								bot:SelectWeapon(bot:GetWeapons()[3]:GetClass())
							end)
						end
					end
				else
					if (bot:GetPlayerClass() == "engineer" and !IsValid(bot.SentryGunHint) and !bot.BuiltSentry) then
						bot.SentryGunHint = table.Random(GetCachedEntities("bot_hint_sentrygun"))
					elseif (IsValid(bot.SentryGunHint) and !bot.BuiltSentry) then
						bot.botPos = bot.SentryGunHint:GetPos()
						bot:Build(2,0)
						if (bot:GetPos():Distance(bot.SentryGunHint:GetPos()) < 150) then
							buttons = buttons + IN_ATTACK
							bot.BuiltSentry = true
							timer.Simple(0.2, function()
								bot:SelectWeapon(bot:GetWeapons()[3]:GetClass())
							end)
						end
					end
				end
			end
		end

			local activeWeapon = bot:GetActiveWeapon()
			if IsValid(activeWeapon) and not IsGmodPlayerBotClass(bot, bot:GetPlayerClass()) then
				local ammo1 = SafeWeaponAmmo1(activeWeapon, bot)
				local clip1 = isfunction(activeWeapon.Clip1) and activeWeapon:Clip1() or -1
				local primary = activeWeapon.Primary
				local clipSize = istable(primary) and tonumber(primary.ClipSize) or -1
				if (ammo1 < 0 and clip1 < 0 and clipSize ~= -1 and not activeWeapon.IsMeleeWeapon) then
					if (CurTime() > activeWeapon:GetNextPrimaryFire()) then
						if (activeWeapon.HoldType == "PRIMARY") then
							if (IsValid(activeWeapon.Owner) and IsValid(activeWeapon.Owner:GetWeapons()[2])) then
								activeWeapon.Owner:SelectWeapon(activeWeapon.Owner:GetWeapons()[2]:GetClass())
							end
						elseif ((activeWeapon.HoldType == "SECONDARY" or (activeWeapon:GetClass() == "tf_weapon_jar" or activeWeapon:GetClass() == "tf_weapon_jar_milk")) and IsValid(activeWeapon.Owner) and activeWeapon.Owner:GetPlayerClass() != "medic") then
							if (IsValid(activeWeapon.Owner:GetWeapons()[3])) then
								activeWeapon.Owner:SelectWeapon(activeWeapon.Owner:GetWeapons()[3]:GetClass())
							end
						end
					end
				end
			end
			
			if (bot:GetPlayerClass() == "samuraidemo") then
				bot:SetJumpPower(220 * 2.3)
			end
		local allowCarrierCombat = true
		if IsMvMBombCarrier(bot) and bot.TF_MVM_IgnoreCombat then
			allowCarrierCombat = IsValid(bot.TargetEnt) and bot:GetPos():DistToSqr(bot.TargetEnt:GetPos()) <= (440 * 440)
		end
		if IsValid(bot.TargetEnt) and allowCarrierCombat and bot:GetNWBool("InRespawnRoom",false) == false and bot:GetNWBool("Taunting",false) != true then
			
			if (bot.TargetEnt:Health() > 0 and !GAMEMODE.IsSetupPhase) then 

					if (!IsValid(bot:GetActiveWeapon())) then return end
					
			if bot:GetPlayerClass() == "sniper" then
				if bot:GetActiveWeapon():EntIndex() == bot:GetWeapons()[1]:EntIndex() then
					if (!bot:GetActiveWeapon().ZoomStatus and bot:Visible(bot.TargetEnt)) then
						buttons = buttons + IN_ATTACK2
					elseif (bot:GetActiveWeapon().ZoomStatus and !bot:Visible(bot.TargetEnt)) then
						buttons = buttons + IN_ATTACK2
					end
				end
			end
					if bot:GetPlayerClass() == "melee_scout_sandman" or bot:GetPlayerClass() == "melee_scout" then 
						for k,v in ipairs(ents.FindInSphere(bot:GetPos(), 240)) do
							if v == bot.TargetEnt then
								buttons = buttons + IN_ATTACK2
							end
						end
					end
					if bot:GetActiveWeapon():GetClass() == "tf_weapon_bat_wood" then 
						if (bot.TargetEnt:GetPos():Distance(bot:GetPos()) < 2500) then
							buttons = buttons + IN_ATTACK2 
						end
					end
					if bot:GetPlayerClass() == "demoknight" or bot:GetPlayerClass() == "samuraidemo" or bot:GetPlayerClass() == "giantdemoknight" or bot:GetPlayerClass() == "chieftavish" then
						if (bot.TargetEnt:GetPos():Distance(bot:GetPos()) < 500) then
							buttons = buttons + IN_ATTACK2
						end
					end
					if bot:GetPlayerClass() == "charger" then
						if (bot.TargetEnt:GetPos():Distance(bot:GetPos()) < 240) then
							buttons = buttons + IN_ATTACK2
						end
					elseif bot:GetPlayerClass() == "smoker" then
						if (bot.TargetEnt:GetPos():Distance(bot:GetPos()) < 1000) then
							buttons = buttons + IN_ATTACK2
						end
					elseif bot:GetPlayerClass() == "hunter" then
						if (bot:GetActiveWeapon().ReadyToPounce) then
							if (bot.TargetEnt:GetPos():Distance(bot:GetPos()) < 240) then
								if (bot:Visible(bot.TargetEnt)) then
									buttons = buttons + IN_ATTACK2
								end
							end
						end

					else

						if (bot:GetNWBool("Taunting",false) != true) then
							if (bot:Visible(bot.TargetEnt)) then
								if (bot.playerclass == "Sniper") then
									if (IsValid(bot:GetActiveWeapon()) and bot:GetActiveWeapon():EntIndex() == bot:GetWeapons()[1]:EntIndex()) then
										if (math.random(1,100) == 1) then
											buttons = buttons + IN_ATTACK
										end
									else

										if (bot:GetActiveWeapon().IsMeleeWeapon and bot.TargetEnt:GetPos():Distance(bot:GetPos()) > 400 * bot:GetModelScale()) then return end
										if (bot:Team() == TEAM_BLU and string.find(bot:GetModel(),"/bot_") and bot:HasGodMode()) then return end
										if (IsValid(bot.TargeEntity) and bot.TargeEntity.dt.Charging and bot:GetPlayerClass() != "samuraidemo") then return end
										if (bot:GetActiveWeapon().ReloadSingle and (!bot:GetActiveWeapon().Reloading || !bot:IsMiniBoss())) then
											buttons = buttons + IN_ATTACK
										elseif (!bot:GetActiveWeapon().ReloadSingle) then
											buttons = buttons + IN_ATTACK
										end

									end
								else 
									if ((!bot.VisionLimits and IsValid(bot:GetActiveWeapon()) and bot.TargetEnt:Health() > 0 and bot:GetPos():Distance(bot.TargetEnt:GetPos()) < 2600 * bot:GetModelScale()) or (bot.VisionLimits and IsValid(bot:GetActiveWeapon()) and bot.TargetEnt:Health() > 0 and bot:GetPos():Distance(bot.TargetEnt:GetPos()) < bot.VisionLimits)) then
										if (bot:GetPlayerClass() != "samuraidemo" and IsValid(bot.TargeEntity) and bot.TargeEntity.dt.Charging) then
										
										else
											if (bot:GetActiveWeapon().IsMeleeWeapon and bot.TargetEnt:GetPos():Distance(bot:GetPos()) > 400 * bot:GetModelScale()) then return end
											if (bot:Team() == TEAM_BLU and string.find(bot:GetModel(),"/bot_") and bot:HasGodMode()) then return end
											if (IsValid(bot.TargeEntity) and bot.TargeEntity.dt.Charging and bot:GetPlayerClass() != "samuraidemo") then return end
											if (bot:GetActiveWeapon().ReloadSingle and (!bot:GetActiveWeapon().Reloading || !bot:IsMiniBoss())) then
												buttons = buttons + IN_ATTACK
											elseif (!bot:GetActiveWeapon().ReloadSingle) then
												buttons = buttons + IN_ATTACK
											end
										end
									end
								end
							end
						end

					end

			end
		end

		-- Hard rule: only allow duck input while standing in NAV_MESH_CROUCH areas.
		local allowDuck = false
		if navmesh and navmesh.GetNearestNavArea then
			local ok, navArea = pcall(navmesh.GetNearestNavArea, bot:GetPos())
			if ok then
				allowDuck = IsCrouchNavArea(navArea)
			end
		end
		if not allowDuck then
			if bot:IsFlagSet(FL_DUCKING) then
				bot:RemoveFlags(FL_DUCKING)
			end
			if bit.band(buttons, IN_DUCK) ~= 0 then
				buttons = bit.band(buttons, bit.bnot(IN_DUCK))
			end
		end

		if IsValid(bot.ControllerBot) and (bot.ControllerBot.nextStuckJump > CurTime()) then
			buttons = buttons + IN_JUMP
		end
		cmd:ClearButtons()
		cmd:SetButtons(buttons)
		end
end)

hook.Add("PostPlayerDeath", "leadbot_respawn", function(bot)
	if (IsValid(bot)) then
		timer.Simple(6.8, function()
			if IsValid(bot) and bot:Deaths() >= 1 and bot:IsBot() then
				-- Keep regular TFBots in the respawn flow. Only remove true L4D zombies
				-- when explicit bot respawn is disabled.
				if bot.IsL4DZombie and bot:IsL4D() and not bot_respawn:GetBool() then
					bot:Kick("")
				end
			end

		end)
		timer.Simple(6.5, function()
			if IsValid(bot) and bot.TFBot and not bot:Alive() and not GAMEMODE.RoundHasWinner then
				RespawnBotAtTeamSpawn(bot)
			end
		end)
	end
end)

function table.EqualValues(t1,t2,ignore_mt)
	ignore_mt = ignore_mt or true
	local ty1 = type(t1)
	local ty2 = type(t2)
	if ty1 ~= ty2 then return false end
	-- non-table types can be directly compared
	if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
	-- as well as tables which have the metamethod __eq
	local mt = getmetatable(t1)
	if not ignore_mt and mt and mt.__eq then return t1 == t2 end
	for k1,v1 in pairs(t1) do
		local v2 = t2[k1]
		if v2 == nil or not table.EqualValues(v1,v2) then return false end
	end
	for k2,v2 in pairs(t2) do
		local v1 = t1[k2]
		if v1 == nil or not table.EqualValues(v1,v2) then return false end
	end
	return true
end

concommand.Add("print_save_data", function(ply)
	if not IsValid(ply) then return end
	PrintTable(ply:GetSaveTable())
end)
concommand.Add("tf_bot_kick_all", function() for k, v in pairs(player.GetBots()) do v:Kick("Kicked from server") end end)
concommand.Add("tf_bot_bring_all", function(ply)
	local target = IsValid(ply) and ply or Entity(1)
	if not IsValid(target) then return end
	for k, v in pairs(player.GetBots()) do
		v:SetPos(target:GetPos())
	end
end)
concommand.Add("tf_bot_goto", function(ply)
	if not IsValid(ply) then return end
	local bots = {}
	for k, v in pairs(player.GetBots()) do
		table.insert(bots, v)
	end
	if #bots == 0 then return end
	ply:SetPos(table.Random(bots):GetPos())
end)
concommand.Add("tf_bot_bring", function(ply) local bots = {} for k, v in pairs(player.GetBots()) do table.insert(bots, v) end local pos = navmesh.GetNavArea(Entity(1):GetPos(), 5):GetRandomPoint() table.Random(bots):SetPos(pos) end)
concommand.Add("tf_bot_kill_all", function() for k, v in pairs(player.GetBots()) do v:Kill() end end)
concommand.Add("tf_bot_kill_bots", function() for k, v in pairs(player.GetBots()) do v:Kill() end end)
concommand.Add("tf_bot_say", function(ply, _, args) for k, v in pairs(player.GetBots()) do v:Say(args[1]) end end)

--concommand.Add("lk.noclip", function(ply) if ply:GetMoveType() == MOVETYPE_NOCLIP then ply:SetMoveType(MOVETYPE_WALK) else ply:SetMoveType(MOVETYPE_NOCLIP) end end)
--concommand.Add("lk.downme", function(ply) ply:DownPlayer() end)
concommand.Add("tf_bot_add", function(ply, cmd, args, argStr) 
	if (game.SinglePlayer()) then 
		table.insert( Errors, {
			last	= SysTime(),
			text	= "TFBots do not work in Singleplayer! >:("
		} )
		return
	end 
	if IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin()) || !IsValid(ply) then 
		local count = math.max(math.floor(tonumber(args[1] or 1) or 1), 1)
		for i=1, count do
			LeadBot_S_Add() 
		end
	end 
end)
concommand.Add("tf_bot_name_add", function(_, _, args) table.insert(names, args[1]) MsgN(args[1].." added to names list!") end)
concommand.Add("tf_bot_quota", function(ply, cmd, args, argStr) 
	if (game.SinglePlayer()) then 
		table.insert( Errors, {
			last	= SysTime(),
			text	= "TFBots do not work in Singleplayer! >:("
		} )
		return
	end 
	if IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin()) || !IsValid(ply) then 
		SetQuotaTarget(args[1] or 0)
		EnforceBotQuota()
		MsgN("[LeadBot] tf_bot_quota set to " .. tostring(desiredBotQuota))
	end
end)

--concommand.Add("lk.playerclass", function(_, _, args) for k, v in pairs(player.GetBots()) do v:SetPlayerClass(args[1]) end end)

concommand.Add("tf_bot_scramble", function(_, _, args) for k, v in pairs(player.GetBots()) do local teamd = TEAM_RED if math.random(2) == 1 then teamd = TEAM_BLU end v:SetTeam(teamd) end end)

--concommand.Add("lk.neutral", function(_, _, args) for k, v in pairs(player.GetBots()) do v:SetTeam(TEAM_NEUTRAL) end end)
--:SpectateEntity(table.Random(player.GetBots()))
concommand.Add("tf_spectate_bot", function(ply, _, args) if args[1] == "2" then ply:Spectate(OBS_MODE_CHASE) return elseif args[1] == "1" then ply:Spectate(OBS_MODE_IN_EYE) return elseif args[1] == "3" then ply:Spectate(OBS_MODE_ROAMING) return end ply:StripWeapons() local bot = table.Random(player.GetBots()) ply:SpectateEntity(bot) ply:Spectate(OBS_MODE_IN_EYE) end)
concommand.Add("tf_unspectate_bot", function(ply) ply:UnSpectate() ply:KillSilent() ply:Spawn() end)

concommand.Add("tf_bot_takecontrol", function(ply) local bot = ply:GetObserverTarget() ply:UnSpectate() ply:SetMoveType(MOVETYPE_WALK) ply:KillSilent() ply:Spawn() ply:SetTeam(bot:Team()) ply:SetPlayerClass(bot:GetPlayerClass()) timer.Simple(0.1, function() ply:UnSpectate() ply:SetPlayerClass(bot:GetPlayerClass()) timer.Simple(0.1, function() ply:SetHealth(bot:Health()) ply:SetPos(bot:GetPos()) ply:SetEyeAngles(bot:EyeAngles()) ply:SendLua([[surface.PlaySound("misc/freeze_cam.wav")]]) bot:Kill() end) end) end)

--[[concommand.Add("tf_bot_difficulty", function(_, _, args)
	if !args[1] then MsgN("Defines the skill of bots joining the game.") return
	local diffn = "easy"
	if args[1] == "2" then
		diffn = "medium"
	elseif args[1] == "3" then
		diffn = "hard" 
	end

	for k, v in pairs(player.GetBots()) do
		v.Difficulty = args[1]
	end 

	for k, v in pairs(player.GetAll()) do 
		v:ChatPrint("Difficulty has been set to "..args[1].." ("..diffn..")") 
	end 
end)]]

hook.Add( "ShouldCollide", "TFBot_CheckCollisions", function( ent1, ent2 )
	local function isBlueBot(ent)
		if not IsValid(ent) then return false end
		local isManagedBot = (ent.TFBot == true) or (ent.IsTFBotValveBase == true)
		if not isManagedBot then return false end
		local teamNum = (ent.Team and ent:Team()) or nil
		return teamNum == TEAM_BLU or teamNum == TF_TEAM_PVE_INVADERS
	end

	if isBlueBot(ent1) and isBlueBot(ent2) then
		return false
	end
end )


-- bot movement

function Astar( bot, start, goal )
	if ( !IsValid( start ) || !IsValid( goal ) ) then return false end
	if ( start == goal ) then return true end

	start:ClearSearchLists()

	start:AddToOpenList()

	local cameFrom = {}

	start:SetCostSoFar( start:GetCenter():Distance( goal:GetCenter() ) )

	start:SetTotalCost( ComputePathCost( bot, start, goal, nil, 100000 ) )
	start:UpdateOnOpenList()

	while ( !start:IsOpenListEmpty() ) do
		local current = start:PopOpenList() // Remove the area with lowest cost in the open list and return it
		if ( current == goal ) then
			return reconstruct_path( cameFrom, current )
		end

		current:AddToClosedList()

		for k, neighbor in pairs( current:GetAdjacentAreas() ) do
			local newCostSoFar = current:GetCostSoFar()
			
			if ( ( neighbor:IsOpen() || neighbor:IsClosed() ) && neighbor:GetCostSoFar() <= newCostSoFar ) then
				continue
			else
				local newArea = navmesh.GetNearestNavArea( bot:GetPos(), true, 10000, true, true, bot:Team() )
				neighbor:SetCostSoFar( newCostSoFar );
				neighbor:SetTotalCost( newCostSoFar + ( newArea:GetCenter() - goal:GetCenter() ):LengthSqr() )

				if ( neighbor:IsClosed() ) then
				
					neighbor:RemoveFromClosedList()
				end

				if ( neighbor:IsOpen() ) then
					// This area is already on the open list, update its position in the list to keep costs sorted
					neighbor:UpdateOnOpenList()
				else
					neighbor:AddToOpenList()
				end

				cameFrom[ neighbor:GetID() ] = current:GetID()
			end
		end
	end

	return false
end


// using CNavAreas as table keys doesn't work, we use IDs
function reconstruct_path( cameFrom, current )
	local total_path = { current }

	current = current:GetID()
	while ( cameFrom[ current ] ) do
		current = cameFrom[ current ]
		table.insert( total_path, navmesh.GetNavAreaByID( current ) )
	end
	return total_path
end

function AstarVector( bot, start, goal )
	local team = (IsValid(bot) and bot.Team and bot:Team()) or nil
	local startArea = navmesh.GetNearestNavArea( start, true, 10000, true, true, team )
	local goalArea = navmesh.GetNearestNavArea( goal, true, 10000, true, true, team )
	-- Some maps don't have team-marked nav areas consistently; fallback without team filter.
	if not IsValid(startArea) then
		startArea = navmesh.GetNearestNavArea( start, true, 10000, true, true )
	end
	if not IsValid(goalArea) then
		goalArea = navmesh.GetNearestNavArea( goal, true, 10000, true, true )
	end
	if not IsValid(startArea) or not IsValid(goalArea) then
		return nil
	end
	-- Always return a segmentable path even for very short moves inside the same area.
	if startArea == goalArea then
		return { goalArea, startArea }
	end
	return Astar( bot, startArea, goalArea )
end

function drawThePath( path, time )
	local prevArea
	for _, area in pairs( path ) do
		debugoverlay.Sphere( area:GetCenter(), 8, time or 9, color_white, true  )
		if ( prevArea ) then
			debugoverlay.Line( area:GetCenter(), prevArea:GetCenter(), time or 9, color_white, true )
		end

		//area:Draw()
		prevArea = area
	end
end

concommand.Add( "test_astar", function( ply )

	// Use the start position of the player who ran the console command
	local start = navmesh.GetNearestNavArea( ply:GetPos() )

	// Target position, use the player's aim position for this example
	local goal = navmesh.GetNearestNavArea( ply:GetEyeTrace().HitPos )

	local path = Astar( ply, start, goal )
	if ( !istable( path ) ) then // We can't physically get to the goal or we are in the goal.
		return
	end

	PrintTable( path ) // Print the generated path to console for debugging
	
	drawThePath( path ) // Draw the generated path for 9 seconds

end)

local rePathDelay = 1 // How many seconds need to pass before we need to remake the path to keep it updated

local function GetAreaSteerPos(area, fromPos, fallbackPos)
	if not IsValid(area) then
		return fallbackPos or fromPos
	end

	local steerPos = area:GetCenter()
	if area.GetClosestPointOnArea and fromPos then
		local ok, closest = pcall(area.GetClosestPointOnArea, area, fromPos)
		if ok and isvector(closest) then
			steerPos = closest
		end
	end

	return steerPos
end

local function ResetPathFollowingState(ply)
	ply._segmentAreaId = nil
	ply._segmentBestDist = nil
	ply._segmentBestStamp = nil
end

local function ShouldForceJumpAtObstacle(ply, targetAng)
	if not IsValid(ply) or not ply:IsOnGround() then return false end
	local startPos = ply:GetPos() + Vector(0, 0, 8)
	local dir = targetAng:Forward()
	local tr = util.TraceHull({
		start = startPos,
		endpos = startPos + dir * 42,
		filter = ply,
		mask = MASK_PLAYERSOLID,
		mins = Vector(-16, -16, 0),
		maxs = Vector(16, 16, 48),
	})
	if not tr.Hit then return false end
	-- Ignore mostly-flat ground contacts; react to ledges/fences/walls.
	if tr.HitNormal.z > 0.65 then return false end
	return true
end

hook.Add( "StartCommand", "TFBot_Movement", function( ply, cmd )
	if _G.TFBOT_VALVE_AI_ACTIVE then
		local compatLegacyPath = GetConVar("tf_bot_valve_ai_compat_legacy_path")
		if not (compatLegacyPath and compatLegacyPath:GetBool()) then
			return
		end
	end

	// Only run this code on bots, and only if bot_mimic is set to 0
	if ( !ply.TFBot || ply.botPos == nil ) then return end
	local currentArea = navmesh.GetNearestNavArea( ply:GetPos() )
	local hiding
	cmd:ClearMovement()
	cmd:RemoveKey(IN_DUCK)

	// internal variable to regenerate the path every X seconds to keep the pace with the target player
	ply.lastRePath = ply.lastRePath or 0

	// internal variable to limit how often the path can be (re)generated
	ply.lastRePath2 = ply.lastRePath2 or 0 

	local repathDelay = rePathDelay
	if PerfEnabled() then
		repathDelay = GetAdaptiveInterval(CVFloat(tf_bot_repath_interval, 1.75), 0.25)
	end
	if ( ply.path && ply.lastRePath + repathDelay < CurTime() ) then
		ply.path = nil
		ResetPathFollowingState(ply)
		ply.lastRePath = CurTime()
	end

	if ( !ply.path && ply.lastRePath2 + repathDelay < CurTime() ) then
		if PerfEnabled() then
			ply._nextPath = ply._nextPath or 0
			if ply._nextPath > CurTime() then
				return
			end
			local spread = (ply:EntIndex() % 10) * 0.01
			ply._nextPath = CurTime() + spread
		end

		local targetPos = ply.botPos // target position to go to, the first player on the server
		if targetPos and navmesh and navmesh.GetNearestNavArea then
		end
		ply.targetArea = nil

		if PerfEnabled() then
			local budgetMs = math.max(CVFloat(tf_bot_nav_budget_ms, 2.5), 0.25)
			local window = math.floor(CurTime() * 20) -- 50 ms window
			if navBudget.window ~= window then
				navBudget.window = window
				navBudget.used = 0
			end
			if navBudget.used >= budgetMs then
				-- Budget-starved bots should retry soon rather than wait full repathDelay.
				ply._nextPath = CurTime() + 0.05 + ((ply:EntIndex() % 7) * 0.01)
				return
			end
			local t0 = SysTime()
			ply.path = AstarVector( ply, ply:GetPos(), targetPos )
			navBudget.used = navBudget.used + ((SysTime() - t0) * 1000)
			if CVBool(tf_bot_perf_debug, false) and navBudget.used > budgetMs then
				PerfDebug("Nav budget reached: " .. string.format("%.2f/%.2f ms", navBudget.used, budgetMs))
			end
		else
			ply.path = AstarVector( ply, ply:GetPos(), targetPos )
		end
			if ( !istable( ply.path ) ) then // We are in the same area as the target, or we can't navigate to the target
				ply.path = nil -- let fallback recovery logic below run this tick
				ResetPathFollowingState(ply)
				ply.lastRePath2 = CurTime()
			end
			if not istable(ply.path) then
				-- Fall through to no-path recovery block below.
			else
			//PrintTable( ply.path )

			// TODO: Add inbetween points on area intersections
			// TODO: On last area, move towards the target position, not center of the last area
			table.remove( ply.path ) // Just for this example, remove the starting area, we are already in it!
			ResetPathFollowingState(ply)
			end
	end

	// We have no path, or its empty (we arrived at the goal), try to get a new path.
	if ( !ply.path || #ply.path < 1 ) then
		ply.path = nil
		ply.targetArea = nil
		ResetPathFollowingState(ply)
		-- If we cannot build a path, recover to a nearby nav position instead of
		-- forcing straight-line movement into non-walkable space.
		if not ply._nextObjectiveRecover or ply._nextObjectiveRecover < CurTime() then
			local recoverPos = nil
			if ply.botPos and navmesh and navmesh.GetNearestNavArea then
				local goalArea = navmesh.GetNearestNavArea(ply.botPos)
				if IsValid(goalArea) then
					recoverPos = goalArea:GetCenter()
				end
			end
			if not recoverPos and IsMvMMap() then
				local anchor = GetMvMNavObjectiveAnchor(ply)
				if anchor then
					recoverPos = anchor
				end
			end
			if not recoverPos and IsValid(ply.ControllerBot) then
				recoverPos = ply.ControllerBot:FindSpot("random", {radius = 1200, pos = ply:GetPos(), type = "exposed"})
			end
			if recoverPos then
				ply.botPos = recoverPos
			end
			ply._nextObjectiveRecover = CurTime() + 0.35
		end

		-- If we're still in spawn and pathing fails, force a short forward push toward
		-- objective so bots can cross doors/thresholds and regain normal nav paths.
		if ply:GetNWBool("InRespawnRoom", false) and ply.botPos then
			local dir = ply.botPos - ply:GetPos()
				local ang = dir:GetNormalized():Angle()
				cmd:SetForwardMove(320)
				cmd:SetViewAngles(ang)
				if ShouldForceJumpAtObstacle(ply, ang) then
					local b = cmd:GetButtons()
					cmd:SetButtons(bit.bor(b, IN_JUMP))
				end
				if (!IsValid(ply.TargetEnt)) then
					ply:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, ply:EyeAngles(), ang))
				end
		end
		return
	end

	// We got a path to follow to our target!
	if (GetConVar("developer"):GetInt() > 0) then
		drawThePath( ply.path, .1 ) // Draw the path for debugging
	end

	// Select the next area we want to go into
	if ( !IsValid( ply.targetArea ) ) then
		ply.targetArea = ply.path[ #ply.path ]
	end

	local areaAdvanceDist = math.max(28, 20 * ply:GetModelScale())
	while IsValid(ply.targetArea) do
		local steerPos = GetAreaSteerPos(ply.targetArea, ply:GetPos(), ply.botPos or ply:GetPos())
		if ply.targetArea ~= currentArea and ply:GetPos():DistToSqr(steerPos) > (areaAdvanceDist * areaAdvanceDist) then
			break
		end

		table.remove(ply.path) -- Removes current segment and advances
		ply.targetArea = ply.path[#ply.path]
		ResetPathFollowingState(ply)
		if not ply.path or #ply.path < 1 then
			ply.path = nil
			ply.targetArea = nil
			return
		end
	end

	if not IsValid(ply.targetArea) then
		ply.path = nil
		ResetPathFollowingState(ply)
		return
	end

	// We got the target to go to, aim there and MOVE
	local steerPos = GetAreaSteerPos(ply.targetArea, ply:GetPos(), ply.botPos or ply:GetPos())
	local toSteer = steerPos - ply:GetPos()
	local targetang = toSteer:GetNormalized():Angle()
	local distToArea = toSteer:Length()

	-- NextBot-like segment progress monitor: if we don't get measurably closer to the current
	-- segment for a short window, force a repath and nudge out of blockers.
	local areaId = ply.targetArea:GetID()
	local now = CurTime()
	if ply._segmentAreaId ~= areaId then
		ply._segmentAreaId = areaId
		ply._segmentBestDist = distToArea
		ply._segmentBestStamp = now
	elseif distToArea + 8 < (ply._segmentBestDist or math.huge) then
		ply._segmentBestDist = distToArea
		ply._segmentBestStamp = now
	elseif now - (ply._segmentBestStamp or now) > 0.85 and ply:IsOnGround() then
		ply.path = nil
		ply.targetArea = nil
		ply.lastRePath = 0
		ply.lastRePath2 = 0
		ResetPathFollowingState(ply)
		ply._nextUnstuck = now + 0.45

		local current = cmd:GetButtons()
		cmd:SetButtons(bit.bor(current, IN_JUMP))
		cmd:SetForwardMove(280)
		cmd:SetSideMove((ply:EntIndex() % 2 == 0) and 220 or -220)
		return
	end

	-- Extra fallback if velocity collapses for too long while far from steer point.
	local speed2D = ply:GetVelocity():Length2D()
	if ply:IsOnGround() and distToArea > 120 and speed2D < 28 then
		ply._stuckSince = ply._stuckSince or now
		if now - ply._stuckSince > 0.9 and (not ply._nextUnstuck or ply._nextUnstuck < now) then
			ply.path = nil
			ply.targetArea = nil
			ply.lastRePath = 0
			ply.lastRePath2 = 0
			ResetPathFollowingState(ply)
			ply._nextUnstuck = now + 0.45

			local current = cmd:GetButtons()
			cmd:SetButtons(bit.bor(current, IN_JUMP))
			cmd:SetForwardMove(280)
			cmd:SetSideMove((ply:EntIndex() % 2 == 0) and 220 or -220)
			return
		end
	else
		ply._stuckSince = nil
	end

	if (ply:GetNWBool("Taunting",false) == true) then
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		cmd:SetUpMove(0)
		cmd:RemoveKey(IN_JUMP)
		cmd:RemoveKey(IN_DUCK)
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
	else
		cmd:SetForwardMove( 1000 )
		cmd:SetViewAngles( targetang )
		if ShouldForceJumpAtObstacle(ply, targetang) then
			local current = cmd:GetButtons()
			cmd:SetButtons(bit.bor(current, IN_JUMP))
		end
		if (!IsValid(ply.TargetEnt)) then
			ply:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, ply:EyeAngles(), targetang))
		end
	end

end )


-- CONFIGURABLE WAVE TIMES PER TEAM (seconds)
RESPAWN_TEAM_RED = tonumber(rawget(_G, "TEAM_RED")) or 2
RESPAWN_TEAM_BLU = tonumber(rawget(_G, "TEAM_BLU")) or 3
respawnWaveTimes = {
    [RESPAWN_TEAM_RED] = 20.5,
    [RESPAWN_TEAM_BLU] = 20.5
}

-- Player queues per team
respawnQueue = {
    [RESPAWN_TEAM_RED] = {},
    [RESPAWN_TEAM_BLU] = {}
}

-- Add player to the team's respawn queue
hook.Add("PlayerDeath", "TF2_RespawnWave_Queue", function(ply)
    if not IsValid(ply) or not ply:Team() then return end
	if (ply:IsBot()) then
		local teamID = ply:Team()
		local queue = respawnQueue[teamID]
		if not queue then return end

		table.insert(queue, ply)
		ply:SetNWBool("InRespawnQueue", true)

		-- Prevent automatic respawn
		ply:StripWeapons()
	end
end)

-- Respawn wave timer
function ProcessRespawnWave(teamID)
    local queue = respawnQueue[teamID]
    if not queue then return end

    for i = #queue, 1, -1 do
        local ply = queue[i]
        if IsValid(ply) and ply:Team() == teamID and ply:Alive() == false then
			RespawnBotAtTeamSpawn(ply)
            ply:SetNWBool("InRespawnQueue", false)
        end
        table.remove(queue, i)
    end
end

-- Set up per-team respawn wave timers
for teamID, waveTime in pairs(respawnWaveTimes) do
    timer.Create("TF2_RespawnWave_Team_" .. teamID, waveTime, 0, function()
        ProcessRespawnWave(teamID)
    end)
end

function BreakTouchingEntities(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

	if PerfEnabled() then
		ply._lastBreakablePos = ply._lastBreakablePos or ply:GetPos()
		if ply._lastBreakablePos:DistToSqr(ply:GetPos()) < 16 then
			return
		end
		ply._lastBreakablePos = ply:GetPos()
	end

    local bboxMin, bboxMax = ply:OBBMins(), ply:OBBMaxs()
    local pos = ply:GetPos()

    -- Find entities within player's bounding box
    local nearby = ents.FindInBox(pos + bboxMin, pos + bboxMax)
    for _, ent in ipairs(nearby) do
        if not IsValid(ent) then continue end

        local class = ent:GetClass()
        if class == "func_breakable" or class == "func_breakable_surf" then
            if ent:Health() > 0 then
                local dmg = DamageInfo()
                dmg:SetAttacker(ply)
                dmg:SetInflictor(ply)
                dmg:SetDamage(ent:Health())
                dmg:SetDamageType(DMG_CRUSH) -- or DMG_CLUB, DMG_GENERIC

                ent:TakeDamageInfo(dmg)
            end
        end
    end
end

function ProcessBreakablesTouchByBots()
	for _, ply in ipairs(player.GetAll()) do
		if ply.TFBot then
			BreakTouchingEntities(ply)
		end
	end
end

tf_bot_trigger_touch_interval = CreateConVar("tf_bot_trigger_touch_interval", "0.10", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Interval for playerbot trigger touch emulation.")
triggerTouchCache = { nextRefresh = 0, ents = {} }

function IsTriggerLikeEntity(ent)
	if not IsValid(ent) then return false end
	local class = string.lower(tostring(ent:GetClass() or ""))
	if string.StartWith(class, "trigger_") then return true end
	return class == "func_capturezone" or class == "func_flagdetectionzone"
end

function RefreshTriggerTouchCache(now)
	if now < (triggerTouchCache.nextRefresh or 0) then
		return triggerTouchCache.ents
	end
	triggerTouchCache.nextRefresh = now + 1.0
	local out = {}
	for _, ent in ipairs(ents.GetAll()) do
		if IsTriggerLikeEntity(ent) then
			out[#out + 1] = ent
		end
	end
	triggerTouchCache.ents = out
	return out
end

function IsPointInsideEntityOBB(ent, point)
	if not IsValid(ent) or not isvector(point) then return false end
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	local lp = ent:WorldToLocal(point)
	return lp.x >= mins.x and lp.x <= maxs.x
		and lp.y >= mins.y and lp.y <= maxs.y
		and lp.z >= mins.z and lp.z <= maxs.z
end

function ProcessTriggerTouchByPlayerBots()
	local now = CurTime()
	local triggerEnts = RefreshTriggerTouchCache(now)

	for _, ply in ipairs(player.GetBots()) do
		if not IsValid(ply) or not ply.TFBot or not ply:Alive() then continue end
		ply._tfbotTriggerTouches = ply._tfbotTriggerTouches or {}
		local active = ply._tfbotTriggerTouches
		local insideNow = {}
		local pos = ply:GetPos()

		for _, trg in ipairs(triggerEnts) do
			if not IsValid(trg) then continue end
			if not IsPointInsideEntityOBB(trg, pos) then continue end
			local idx = trg:EntIndex()
			insideNow[idx] = trg
			if not active[idx] and trg.StartTouch then
				pcall(trg.StartTouch, trg, ply)
			end
			if trg.Touch then
				pcall(trg.Touch, trg, ply)
			end
		end

		for idx, trg in pairs(active) do
			if not IsValid(trg) then
				active[idx] = nil
			elseif not insideNow[idx] then
				if trg.EndTouch then
					pcall(trg.EndTouch, trg, ply)
				end
				active[idx] = nil
			end
		end

		for idx, trg in pairs(insideNow) do
			active[idx] = trg
		end
	end
end

hook.Remove("Think", "BreakablesTouchByBotPlayers")
timer.Create("BreakablesTouchByBotPlayersTimer", 0.2, 0, function()
	local interval = 0.2
	if tf_bot_breakable_check_interval then
		interval = math.max(CVFloat(tf_bot_breakable_check_interval, 0.20), 0.05)
	end
	if timer.Exists("BreakablesTouchByBotPlayersTimer") then
		timer.Adjust("BreakablesTouchByBotPlayersTimer", interval, 0)
	end
	ProcessBreakablesTouchByBots()
end)

timer.Create("TFBot_TriggerTouchTimer", 0.10, 0, function()
	local interval = math.max(CVFloat(tf_bot_trigger_touch_interval, 0.10), 0.03)
	if timer.Exists("TFBot_TriggerTouchTimer") then
		timer.Adjust("TFBot_TriggerTouchTimer", interval, 0)
	end
	ProcessTriggerTouchByPlayerBots()
end)

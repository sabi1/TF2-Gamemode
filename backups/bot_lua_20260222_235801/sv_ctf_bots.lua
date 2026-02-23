if CLIENT then return end

--[[LEADBOT STANDALONE V1.0_DEV by Lead]]--
--[["For epic developers who don't have friends to play with. 😎"]]--
--[[ONLY MEAN TO BE USED WITHIN Team Fortress 2 Gamemode Dev!!!]]--

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
local tf_bot_name_file = CreateConVar("tf_bot_name_file", "tf_bot_usernames_public.txt", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "DATA file path for additional bot names, one per line.")
local tf_bot_random_loadouts = CreateConVar("tf_bot_random_loadouts", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Randomize bot loadouts on spawn.")
local tf_bot_randomizer_mode = CreateConVar("tf_bot_randomizer_mode", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Ignore class restrictions when randomizing bot loadouts.")
local tf_bot_loadout_mutation_chance = CreateConVar("tf_bot_loadout_mutation_chance", "0.20", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Chance a respawning bot changes one weapon slot in its saved random loadout.")
local tf_bot_loadout_debug = CreateConVar("tf_bot_loadout_debug", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable debug logs for bot loadout randomization.")
local tf_bot_ragdoll_drop_boost = CreateConVar("tf_bot_ragdoll_drop_boost", "280", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Additional downward velocity for dead bot ragdolls.")
-- Keep perf CVars defined here because this file is loaded before shared.lua.
local tf_bot_perf_enable = CreateConVar("tf_bot_perf_enable", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_perf_debug = CreateConVar("tf_bot_perf_debug", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_sense_interval = CreateConVar("tf_bot_sense_interval", "0.35", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_objective_interval = CreateConVar("tf_bot_objective_interval", "1.00", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_avoidance_interval = CreateConVar("tf_bot_avoidance_interval", "0.15", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_repath_interval = CreateConVar("tf_bot_repath_interval", "2.20", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_nav_budget_ms = CreateConVar("tf_bot_nav_budget_ms", "1.50", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_perf_scale_start = CreateConVar("tf_bot_perf_scale_start", "8", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_perf_scale_max = CreateConVar("tf_bot_perf_scale_max", "5", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_breakable_check_interval = CreateConVar("tf_bot_breakable_check_interval", "0.35", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
local tf_bot_perf_hard_threshold = CreateConVar("tf_bot_perf_hard_threshold", "16", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bot count threshold where extra throttling kicks in.")
local tf_bot_perf_hard_multiplier = CreateConVar("tf_bot_perf_hard_multiplier", "1.6", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Extra interval multiplier used above hard threshold.")
local tf_bot_disable_social_look_highload = CreateConVar("tf_bot_disable_social_look_highload", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Disable friendly look-at-me scan when high-load threshold is reached.")

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

	for _, n in ipairs(names) do
		AddName(n)
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

	return pool
end

local function RebuildNameBag()
	shuffledNameBag = BuildNamePool()
	for i = #shuffledNameBag, 2, -1 do
		local j = math.random(i)
		shuffledNameBag[i], shuffledNameBag[j] = shuffledNameBag[j], shuffledNameBag[i]
	end
	shuffledNameBagIndex = 0
end

function GetNextBotName()
	if not CVBool(tf_bot_random_names, true) then
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
	local npcs = {}
		for k,v in ipairs(GetNearbyEntities(bot, 2048, GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05))) do
			if (v:IsPlayer() and v:Health() > 1 and IsValidTarget(bot,v) and (bot:Visible(v))) then
				table.insert(npcs, v)	
			end
		end
		return table.Random(npcs)
end
function lookForNearestEnemyPlayer(bot)
	local npcs = {}
		for k,v in ipairs(GetNearbyEntities(bot, 2048, GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05))) do
			if (v:IsPlayer() and v:Health() > 1 and IsValidTarget(bot,v)) then
				table.insert(npcs, v)	
			end
		end
		return table.Random(npcs)
end

local function AcquireEnemyTarget(bot)
	if not IsValid(bot) then return nil end
	local target = lookForNearestPlayer(bot)
	if not IsValid(target) then
		target = lookForNearestEnemyPlayer(bot)
	end
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
function escortAvailable(bot)
	local npcs = {} 
	for k,v in ipairs(GetCachedEntities("team_train_watcher")) do
		if (IsValid(v)) then
			table.insert(npcs, v)		
		end
	end
	return table.Count(npcs) > 0
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
	if (enemy != nil) then
		if enemy:GetPos():Distance(center) < 80 then
			return false
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
				
				ply:SetTeam(TF_TEAM_PVE_INVADERS)
				ply:SetSkin(1)
					
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
	if (team.NumPlayers(TEAM_RED) > team.NumPlayers(TEAM_BLU)) then
		ply:SetTeam(TEAM_BLU)	
	elseif (team.NumPlayers(TEAM_RED) < team.NumPlayers(TEAM_BLU)) then
		ply:SetTeam(TEAM_RED)	
	end
	
	bot:Spawn()
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

	local name = string.upper(string.sub(class,1,1))..string.sub(class,2)
	local bot = player.CreateNextBot(name)
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

	MsgN("[LeadBot] Bot " .. name .. " with strategy " .. bot.BotStrategy .. " added!")
end

local function LeadBot_S_Add_Survivor(team,class,pos)
	if !navmesh.IsLoaded() then
		ErrorNoHalt("There is no navmesh! Generate one using \"nav_generate\"!\n")
		return
	end

	local name = string.upper(string.sub(class,1,1))..string.sub(class,2)
	local bot = player.CreateNextBot(name)
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

	MsgN("[LeadBot] Bot " .. name .. " with strategy " .. bot.BotStrategy .. " added!")
end
local function LeadBot_S_Add_BlueSurvivor(team,class,pos)
	if !navmesh.IsLoaded() then
		ErrorNoHalt("There is no navmesh! Generate one using \"nav_generate\"!\n")
		return
	end

	local name = string.upper(string.sub(class,1,1))..string.sub(class,2)
	local bot = player.CreateNextBot(name)
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

	MsgN("[LeadBot] Bot " .. name .. " with strategy " .. bot.BotStrategy .. " added!")
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
		local name = item.name or itemName
		if isstring(name) and not IsBadCandidate(className, randomizerMode, slot, name) then
			bySlot[slot][#bySlot[slot] + 1] = name
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

function TFBot_ApplyRandomLoadout(bot, opts)
	if not IsValid(bot) or not bot.TFBot or bot.IsL4DZombie then return false end
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

hook.Add("PlayerSpawn", "LeadBot_S_PlayerSpawn", function(bot)
	if (IsValid(bot)) then
		if bot.TFBot then
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

	local buttons = 0
	if bot.TFBot and bot:Alive() then
		-- if our targetent is not alive, don't do anything until it's nil
		--cmd:ClearMovement()
		--cmd:ClearButtons()

		if (GetConVar("ai_disabled"):GetBool()) then return end
		if (IsValid(bot.TargetEnt)) then
			if (!IsValidTarget(bot,bot.TargetEnt)) then
				bot.TargetEnt = AcquireEnemyTarget(bot)
			end
		else
			bot.TargetEnt = AcquireEnemyTarget(bot)
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
	
		local moveawayrange = 80
		if (string.find(bot:GetModel(),"/bot_") and !string.find(bot:GetModel(),"medic")) then
			moveawayrange = 150
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
			local canRunAvoidance = true
			if PerfEnabled() then
				bot._nextAvoid = bot._nextAvoid or 0
				if bot._nextAvoid > CurTime() then
					canRunAvoidance = false
				else
					bot._nextAvoid = CurTime() + GetAdaptiveInterval(CVFloat(tf_bot_avoidance_interval, 0.10), 0.05)
				end
			end
			if canRunAvoidance then
			for k,v in ipairs(GetNearbyEntities(bot, moveawayrange, GetAdaptiveInterval(CVFloat(tf_bot_avoidance_interval, 0.10), 0.05))) do
				if (IsValid(v) and GAMEMODE:EntityTeam(v) == bot:Team() and v:IsPlayer() and v:EntIndex() != bot:EntIndex() and bot:GetNWBool("Taunting",false) != true) then
					local forward = bot:EyeAngles():Forward()
					local right = bot:EyeAngles():Right()
					local avoidVector = bot:GetPos()
					local between = bot:GetPos() - v:GetPos()
					local between2 = between:GetNormalized()
					avoidVector = avoidVector + ( Vector(1,1,1) - ( between2 / moveawayrange ) ) * between
					local vecDelta = v:WorldSpaceCenter() - bot:GetPos() + Vector(0.5,0.5,0.5) + Vector(0,0,72)
					local vRad = v:WorldSpaceAABB()
					vRad.z = 0
					local flAvoidRadius = vRad:Length()
					local flPushStrength = math.Remap(vecDelta:Length(), flAvoidRadius, 0, 0, 256)
					
					local vecPush
					if (bot:GetVelocity():Length2DSqr() > 0.1) then
						local vecVelocity = bot:GetVelocity()
						vecVelocity.z = 0.0
						local vecUp = Vector( 0, 0, 1 )
						vecPush = vecUp:Cross(vecVelocity)
					else
						local angView = bot:EyeAngles()
						angView.x = 0.0
						vecPush = angView:Right()
					end
					local vecSeparationVelocity = avoidVector * 50
					if (vecDelta:Dot(vecPush) < 0) then
						local vel = vecPush * flPushStrength
						vecSeparationVelocity = vel
					else
						local vel = vecPush * -flPushStrength
						vecSeparationVelocity = vel
					end
					local flMaxPlayerSpeed = bot:GetMaxSpeed()
					local flCropFraction = 1.33333333
					if (bot:Crouching() and bot:IsOnGround()) then
						flMaxPlayerSpeed = flMaxPlayerSpeed * flCropFraction
					end
					local flMaxPlayerSpeedSqr = flMaxPlayerSpeed * flMaxPlayerSpeed

					if ( vecSeparationVelocity:LengthSqr() > flMaxPlayerSpeedSqr ) then
						vecSeparationVelocity:Normalize()
						vecSeparationVelocity = vecSeparationVelocity * flMaxPlayerSpeed
					end
					local vAngles = bot:EyeAngles()
					vAngles.x = 0 
					local currentdir = vAngles:Forward()
					local rightdir = vAngles:Right()
					local vDirection = vecSeparationVelocity:GetNormalized()
					
					local fwd = vDirection:Dot( currentdir )
					local rt = vDirection:Dot( rightdir )

					local forward2 = fwd * flPushStrength
					local side = rt * flPushStrength
					
					avoidVector:Normalize()
					bot.movingAway = true
					bot.pushAwayMove = mv:GetForwardSpeed() + (forward2)
					mv:SetForwardSpeed(mv:GetForwardSpeed() + (forward2))
					mv:SetSideSpeed(mv:GetSideSpeed() + (side))
				end
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
			if IsValid(bot.intelcarrier) and !IsValid(bot.TargetEnt) and bot:GetPos():Distance(bot.intelcarrier:GetPos()) < 6000 and bot.intelcarrier:Health() > 0 then
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
				--bot:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, bot:EyeAngles(), mva + (controller.LookAt * 0.5))) 
				bot:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, bot:EyeAngles(), (controller.LookAt * 0.5))) 
			end
			if (!IsValid(bot.TargetEnt)) then 
				if (bot.lookingAt) then return end
				if (bot:GetPlayerClass() != "tank_l4d") then
					if (bot:GetNWBool("Taunting",false) == true) then 
						return 
					end 
				end	 
				--bot:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, bot:EyeAngles(), mva + (controller.LookAt * 0.5))) 
				bot:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, bot:EyeAngles(), (controller.LookAt * 0.5))) 
			end 
	end
end)

local function ComputePathCost(bot, area, fromArea, ladder, length)
	local self = bot
    if not fromArea then
        -- First area in path, no cost
        return 0.0
    end

    -- Is the area traversable?
    if not self.loco:IsAreaTraversable(area) then
        return -1.0
    end


    -- Avoid enemy spawn rooms
    if (self:Team() == TEAM_RED and area:HasTFAttribute("spawn_room_blue")) or
       (self:Team() == TEAM_BLUE and area:HasTFAttribute("spawn_room_red")) then
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
        if area:IsInCombat() then
            dist = dist * 4.0 * area:GetCombatIntensity()
        end

        if (self:Team() == TEAM_RED and area:HasTFAttribute("blue_sentry_danger")) or
           (self:Team() == TEAM_BLUE and area:HasTFAttribute("red_sentry_danger")) then
            dist = dist * 5.0
        end
    end

    if self:GetPlayerClass() == "spy" then
        local enemyTeam = (self:Team() == TEAM_RED) and TEAM_BLUE or TEAM_RED

        for _, ent in ipairs(GetCachedEntities("obj_sentrygun")) do
            if IsValid(ent) and ent:Team() == enemyTeam then
                if ent.GetLastKnownArea and ent:GetLastKnownArea() == area then
                    dist = dist * 10.0
                end
            end
        end

        dist = dist + dist * 10.0 * area:GetPlayerCount(self:Team())
    end

		

    local cost = dist * preference

    if area:HasAttribute(NAV_MESH_FUNC_COST) then
        cost = cost * area:ComputeFuncNavCost(self)
    end

    return cost + fromArea:GetCostSoFar()
end
hook.Add("SetupMove", "LeadBot_Control", function(bot, mv, cmd)
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
			local closeTargets = GetNearbyEntities(bot, bot:GetModelRadius() * 1.02, GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05))
			for _, v in ipairs(closeTargets) do
				if v:IsPlayer() and not v:IsFriendly(bot) then
					bot.TargetEnt = v
					break
				end
			end
			if not IsValid(bot.TargetEnt) then
				local mediumTargets = GetNearbyEntities(bot, 1200, GetAdaptiveInterval(CVFloat(tf_bot_sense_interval, 0.25), 0.05))
				for _, v in ipairs(mediumTargets) do
					if v:IsPlayer() and v:Team() ~= bot:Team() and v:GetEyeTrace().Entity == bot then
						bot.TargetEnt = v
						break
					end
				end
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
			if escortAvailable(bot) and !GAMEMODE.RoundHasWinner then -- Payload AI
					for k, v in pairs(GetCachedEntities("trigger_capture_area")) do
						intel = v
					end

					if IsValid(intel) then
						bot.botPos = intel.Pos
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
					targetpos = intel.Carrier:GetPos()
					bot.intelcarrier = intel.Carrier
				elseif IsValid(fintel) and fintel.Carrier and bot:EntIndex() != fintel.Carrier:EntIndex() then -- if our intel is being stolen...
					targetpos = fintel.Carrier:GetPos() -- defend our intel
					bot.intelcarrier = fintel.Carrier
				elseif IsValid(fintelcap) then
					targetpos = fintelcap.Pos -- move to the bomb, the flag is currently invalid until a bot gets it
					bot.intelcarrier = nil
				end	

				bot.botPos = targetpos
				
				--bot.LastSegmented = CurTime() + math.Rand(0.5, 1)
			--[[
			elseif string.find(game.GetMap(), "cp_") then -- CP AI


				for k, v in pairs(ents.FindByClass("trigger_capture_area")) do
					if GAMEMODE:EntityTeam(v.CapturePoint) ~= bot:Team() then
						intelcap = v.CapturePoint
					else
						fintelcap = v.CapturePoint
					end
				end

				if GAMEMODE:EntityTeam(intelcap) != ent:Team() then -- or if friendly intelligence has capture
					targetpos = intelcap.Pos -- goto friendly cap spot
					ignoreback = true
				end

				bot.botPos = targetpos
			]]
			elseif bombAvailable(bot) and (bot:Team() == TEAM_BLU or bot:Team() == TF_TEAM_PVE_INVADERS) and bot:GetPlayerClass() != "engineer" and bot.playerclass != "medic" and bot:GetPlayerClass() != "sentrybuster" and !GAMEMODE.RoundHasWinner then -- CTF AI in MVM Maps
				for k, v in pairs(GetCachedEntities("item_teamflag_mvm")) do
					if v.TeamNum ~= bot:Team() and k == 1 then 
						intel = v
					end
				end

				for k, v in pairs(GetCachedEntities("func_capturezone")) do
					fintelcap = v
				end
				if (IsValid(intel)) then
					bot.isCarryingIntel = true
					if !intel.Carrier then -- neither intel has a capture
						targetpos = intel:GetPos()
						bot.intelcarrier = nil
					elseif intel.Carrier and intel.Carrier:EntIndex() == bot:EntIndex() and IsValid(fintelcap) then -- or if friendly intelligence has capture
						targetpos = fintelcap.Pos -- goto friendly cap spot
						bot.intelcarrier = nil
					elseif IsValid(intel.Carrier) and bot:EntIndex() != intel.Carrier:EntIndex() then -- or else if we have it already carried
						if (!bot:IsMiniBoss()) then
							targetpos = intel.Carrier:GetPos()
							bot.intelcarrier = intel.Carrier
						else
							if (IsValid(bot.TargetEnt)) then
								targetpos = bot.TargetEnt:GetPos()
							end
						end
					elseif IsValid(fintelcap) then
						targetpos = fintelcap.Pos -- move to the bomb, the flag is currently invalid until a bot gets it
						bot.intelcarrier = nil
					end	
				elseif IsValid(fintelcap) then
					targetpos = fintelcap.Pos -- goto friendly cap spot
				end

				bot.botPos = targetpos
			else
				if (!IsValid(bot.TargetEnt) || !bot.TargetEnt:Alive()) then
					-- our enemy doesn't exist anymore, find a random spot every 10 seconds
					if (CurTime() > controller.LastSegmented || IsValid(bot.botPos) and bot:GetPos():Distance(bot.botPos) < bot:GetModelRadius() * 1.05) then
						bot.botPos = controller:FindSpot("random", {radius = 12500})
			        	controller.LastSegmented = CurTime() + 10
					end
				else
					if (bot:Visible(bot.TargetEnt)) then
						bot.botPos = bot.TargetEnt:GetPos()
					else
						if (CurTime() > controller.LastSegmented) then
							bot.botPos = controller:FindSpot("random", {radius = 12500, pos = bot.TargetEnt:GetPos(), type = "exposed"})
							controller.LastSegmented = CurTime() + 10
						end
					end
				end
			end
		end
		
			if (2*bot:Health()<bot:GetMaxHealth() and !string.find(bot:GetModel(),"/bot_")) then
				if (!IsValid(bot.healthkit)) then
					bot.healthkit = lookForNearestHealthPack(bot)
				else
					bot.botPos = bot.healthkit:GetPos()
				end
			else
				if (IsValid(bot.healthkit)) then
					bot.healthkit = nil
					bot.botPos = nil
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
		if (bot:Team() == TEAM_BLU and bot:GetPlayerClass() == "sentrybuster") then
				local buildingCandidates = {}
				for _, build in ipairs(GetCachedEntities("obj_sentrygun")) do
					buildingCandidates[#buildingCandidates + 1] = build
				end
				for _, build in ipairs(GetCachedEntities("obj_dispenser")) do
					buildingCandidates[#buildingCandidates + 1] = build
				end
				for _, build in ipairs(GetCachedEntities("obj_teleporter")) do
					buildingCandidates[#buildingCandidates + 1] = build
				end
				for _, v in ipairs(buildingCandidates) do
					if (!IsValid(bot.TargetEnt)) then
						if v:EntIndex() != bot:EntIndex() then
							if (!v:IsFriendly(bot)) then -- TODO: find a better way to do this
								local targetpos = v:EyePos() - Vector(0, 0, 10) -- bot eye check, don't start shooting targets just because we barely see their head
								local trace = util.TraceLine({start = bot:GetShootPos(), endpos = targetpos, filter = function( ent ) return ent == v end})
			
								if (v:EntIndex() == bot:EntIndex()) then return end
								if (v:EntIndex() == bot.ControllerBot:EntIndex()) then return end
								bot.TargetEnt = v
							end
						end
					end
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
			
			if (tf_bot_melee_only:GetBool() and !string.find(bot:GetModel(),"/bots")) then
				if (IsValid(bot:GetWeapons()[3]) and bot:GetWeapons()[3].IsMeleeWeapon) then
					bot:SelectWeapon(bot:GetWeapons()[3])
				elseif (IsValid(bot:GetWeapons()[2]) and bot:GetWeapons()[2].IsMeleeWeapon) then
					bot:SelectWeapon(bot:GetWeapons()[2])
				elseif (IsValid(bot:GetWeapons()[1]) and bot:GetWeapons()[1].IsMeleeWeapon) then
					bot:SelectWeapon(bot:GetWeapons()[1])
				end
			end
		end

		if (!bot.lookingAt and bot:GetNWBool("Taunting",false) != true) then
			if (bot:GetPlayerClass() == "engineer") then
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
			if (bot.botPos and !bot:GetNWBool("Taunting",false)) then
				if (bot:GetVelocity():Length() < 50) then

					if (bot:IsOnGround()) then
						
						if (math.random(1,5) == 1) then
							buttons = buttons + IN_JUMP
						end
						cmd:SetSideMove(math.Rand(-520,520))
						cmd:SetForwardMove(math.Rand(-520,520))
					else
						buttons = buttons + IN_DUCK
					end
					
				end
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

			if (IsValid(bot:GetActiveWeapon())) then
					if (bot:GetActiveWeapon():Ammo1() < 0 and bot:GetActiveWeapon():Clip1() < 0 and bot:GetActiveWeapon().Primary.ClipSize ~= -1 && !bot:GetActiveWeapon().IsMeleeWeapon) then
						if (CurTime() > bot:GetActiveWeapon():GetNextPrimaryFire()) then
							if (bot:GetActiveWeapon().HoldType == "PRIMARY") then
								if (IsValid(bot:GetActiveWeapon().Owner:GetWeapons()[2])) then
									bot:GetActiveWeapon().Owner:SelectWeapon(bot:GetActiveWeapon().Owner:GetWeapons()[2]:GetClass())
								end
							elseif ((bot:GetActiveWeapon().HoldType == "SECONDARY" or (bot:GetActiveWeapon():GetClass() == "tf_weapon_jar" or bot:GetActiveWeapon():GetClass() == "tf_weapon_jar_milk")) and bot:GetActiveWeapon().Owner:GetPlayerClass() != "medic") then
								if (IsValid(bot:GetActiveWeapon().Owner:GetWeapons()[3])) then
									bot:GetActiveWeapon().Owner:SelectWeapon(bot:GetActiveWeapon().Owner:GetWeapons()[3]:GetClass())
								end
							end
						end
					end
				end
			
			if (bot:GetPlayerClass() == "samuraidemo") then
				bot:SetJumpPower(220 * 2.3)
			end
		if IsValid(bot.TargetEnt) and bot:GetNWBool("InRespawnRoom",false) == false and bot:GetNWBool("Taunting",false) != true then
			
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
							if (bot.TargetEnt:GetPos():Distance(bot:GetPos()) < 800) then
									if (!bot:IsFlagSet(FL_DUCKING)) then
										bot:AddFlags(FL_DUCKING)
									end
							end
							if (bot.TargetEnt:GetPos():Distance(bot:GetPos()) < 240) then
								if (bot:Visible(bot.TargetEnt)) then
									buttons = buttons + IN_ATTACK2
								end
							end
						else
							if (bot:IsFlagSet(FL_DUCKING)) then
								bot:RemoveFlags(FL_DUCKING)
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
										if (IsValid(bot.TargeEntity) and bot.TargeEntity.dt.Charging and ply:GetPlayerClass() != "samuraidemo") then return end
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

		if (bot.ControllerBot.nextStuckJump > CurTime()) then
			buttons = buttons + IN_JUMP
		end
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
	PrintTable(ply:GetSaveTable())
end)
concommand.Add("tf_bot_kick_all", function() for k, v in pairs(player.GetBots()) do v:Kick("Kicked from server") end end)
concommand.Add("tf_bot_bring_all", function(ply) for k, v in pairs(player.GetBots()) do v:SetPos(ply:GetPos()) end end)
concommand.Add("tf_bot_goto", function(ply) local bots = {} for k, v in pairs(player.GetBots()) do table.insert(bots, v) end ply:SetPos(table.Random(bots):GetPos()) end)
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
		for i=0, args[1]-1 do
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
		timer.Create("BotQuota",0.25,args[1]-1,function()
			LeadBot_S_Add()
		end)
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
end )


-- bot movement

function Astar( bot, start, goal )
	if ( !IsValid( start ) || !IsValid( goal ) ) then return false end
	if ( start == goal ) then return true end

	start:ClearSearchLists()

	start:AddToOpenList()

	local cameFrom = {}

	start:SetCostSoFar( 0 )

	start:SetTotalCost( heuristic_cost_so_far_estimate( bot, start, goal ) )
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
				neighbor:SetCostSoFar( newCostSoFar );
				neighbor:SetTotalCost( newCostSoFar + heuristic_cost_so_far_estimate( bot, start, goal ) )

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

function heuristic_cost_estimate( m_me, start, goal )
	return start:GetCenter():Distance( goal:GetCenter() )
end

function heuristic_cost_so_far_estimate( m_me, start, goal )
	-- this term causes the same bot to choose different routes over time,
	-- but keep the same route for a period in case of repaths
	
	local area = start
    local dist
	
    -- Unique random penalty per bot/area to vary routes
    local preference = 1.0
    if not m_me:IsMiniBoss() then
        local timeMod = math.floor(CurTime() / 10) + 1
        preference = 1.0 + 50.0 * (1.0 + math.cos(m_me:EntIndex() * area:GetID() * timeMod))
    end
    if ladder then
        dist = ladder:GetLength()
    elseif length and length > 0 then
        dist = length
    else
        dist = start:GetCenter():Distance(goal:GetCenter())
    end
		-- Crawling through a vent is very slow.
		-- NOTE: The cost is determined by the bot's crouch speed
		if area:HasAttributes( NAV_MESH_CROUCH ) then 
			
			local crouchPenalty = 5
			if IsValid( bot ) then crouchPenalty = math.floor( 1 / bot:GetCrouchedWalkSpeed() ) end
			
			dist	=	dist + ( dist * crouchPenalty )
			
		end
		
		-- If this area might damage us if we walk through it we should avoid it at all costs.
		if area:IsDamaging() || area:HasAttributes( NAV_MESH_CLIFF ) then
		
			dist	=	dist + ( dist * 100.0 )
			
		end
		
		-- The bot should avoid this area unless alternatives are too dangerous or too far.
		if area:HasAttributes( NAV_MESH_AVOID ) then 
			
			dist	=	dist + ( dist * 20 )
			
		end
		
		-- We will try not to swim since it can be slower than running on land, it can also be very dangerous, Ex. "Acid, Lava, Etc."
		if area:IsUnderwater() then
		
			dist	=	dist + ( dist * 2 )
			
		end

    local cost = dist * preference

    return cost + goal:GetCostSoFar()
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
hook.Add( "StartCommand", "TFBot_Movement", function( ply, cmd )

	// Only run this code on bots, and only if bot_mimic is set to 0
	if ( !ply.TFBot || ply.botPos == nil ) then return end
	local currentArea = navmesh.GetNearestNavArea( ply:GetPos() )
	local hiding
	cmd:ClearMovement()

	// internal variable to regenerate the path every X seconds to keep the pace with the target player
	ply.lastRePath = ply.lastRePath or 0

	// internal variable to limit how often the path can be (re)generated
	ply.lastRePath2 = ply.lastRePath2 or 0 

	local repathDelay = rePathDelay
	if PerfEnabled() then
		repathDelay = GetAdaptiveInterval(CVFloat(tf_bot_repath_interval, 1.75), 0.25)
	end
	if ( ply.path && ply.lastRePath + repathDelay < CurTime() && currentArea != ply.targetArea ) then
		ply.path = nil
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
				ply.path = nil // Clear the path, bail and try again next time
				ply.lastRePath2 = CurTime()
				return
			end
			//PrintTable( ply.path )

			// TODO: Add inbetween points on area intersections
			// TODO: On last area, move towards the target position, not center of the last area
			table.remove( ply.path ) // Just for this example, remove the starting area, we are already in it!
	end

	// We have no path, or its empty (we arrived at the goal), try to get a new path.
	if ( !ply.path || #ply.path < 1 ) then
		ply.path = nil
		ply.targetArea = nil
		local fallback = ply.botPos
		if fallback then
			local dir = (fallback - ply:GetPos())
			if dir:LengthSqr() > 64 then
				local ang = dir:GetNormalized():Angle()
				cmd:SetForwardMove(350)
				cmd:SetViewAngles(ang)
				if (!IsValid(ply.TargetEnt)) then
					ply:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, ply:EyeAngles(), ang))
				end
				return
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

	// The area we selected is invalid or we are already there, remove it, bail and wait for next cycle
	if ( !IsValid( ply.targetArea ) || ( ply.targetArea == currentArea && ply.targetArea:GetCenter():Distance( ply:GetPos() ) < 10 * ply:GetModelScale() ) ) then
		table.remove( ply.path ) // Removes last element
		ply.targetArea = nil
		return
	end

	// We got the target to go to, aim there and MOVE
	local targetang = ( ply.targetArea:GetCenter() - ply:GetPos() ):GetNormalized():Angle()
	if (ply:GetNWBool("Taunting",false) == true) then 
		cmd:SetForwardMove( 0 )
	else
		cmd:SetForwardMove( 1000 )
		cmd:SetViewAngles( targetang )
		if (!IsValid(ply.TargetEnt)) then
			ply:SetEyeAngles(LerpAngle(FrameTime() * 5 * 1.2, ply:EyeAngles(), targetang))
		end
	end

end )


-- CONFIGURABLE WAVE TIMES PER TEAM (seconds)
local respawnWaveTimes = {
    [TEAM_RED] = 20.5,
    [TEAM_BLU] = 20.5
}

-- Player queues per team
local respawnQueue = {
    [TEAM_RED] = {},
    [TEAM_BLU] = {}
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
local function ProcessRespawnWave(teamID)
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

local function BreakTouchingEntities(ply)
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

local function ProcessBreakablesTouchByBots()
	for _, ply in ipairs(player.GetAll()) do
		if ply.TFBot then
			BreakTouchingEntities(ply)
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

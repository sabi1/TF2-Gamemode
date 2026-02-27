if SERVER then
    AddCSLuaFile()
    util.AddNetworkString("TF_MVM_UpgradeOpen")
    util.AddNetworkString("TF_MVM_UpgradeAction")
    util.AddNetworkString("TF_MVM_CanteenUse")
end

TF_MVMShop = TF_MVMShop or {}

TF_MVMShop.StartingCredits = 600
TF_MVMShop.BuybackBaseCost = 200

TF_MVMShop.CanteenTypes = {
    crit = { name = "CRIT BOOST", description = "Temporary guaranteed crits.", cost = 75 },
    uber = { name = "UBERCHARGE", description = "Temporary invulnerability.", cost = 75 },
    refill = { name = "AMMO REFILL", description = "Instant clip and ammo refill.", cost = 50 },
    build = { name = "BUILD UPGRADE", description = "Repair and boost buildings.", cost = 75 },
}

TF_MVMShop.Upgrades = {
    { id = "max_health", name = "Max Health", category = "Player", target = "player", description = "+25 max health", costs = { 150, 250, 350, 450 } },
    { id = "move_speed", name = "Move Speed", category = "Player", target = "player", description = "+8% movement speed", costs = { 200, 300, 425 } },
    { id = "resist_all", name = "Damage Resistance", category = "Player", target = "player", description = "-8% incoming damage", costs = { 200, 325, 450, 600 } },
    { id = "resist_bullet", name = "Bullet Resistance", category = "Player", target = "player", description = "-10% bullet damage", costs = { 150, 250, 350 } },
    { id = "resist_blast", name = "Blast Resistance", category = "Player", target = "player", description = "-10% explosive damage", costs = { 150, 250, 350 } },
    { id = "resist_fire", name = "Fire Resistance", category = "Player", target = "player", description = "-12% fire damage", costs = { 150, 250, 350 } },
    { id = "heal_on_kill", name = "Health On Kill", category = "Player", target = "player", description = "+15 health per kill", costs = { 100, 200, 300, 450 } },
    { id = "jump_height", name = "Jump Height", category = "Player", target = "player", description = "+10% jump height", costs = { 100, 175, 250 } },

    { id = "damage_primary", name = "Primary Damage", category = "Primary", target = "primary", description = "+12% damage", costs = { 150, 250, 350, 475 } },
    { id = "firerate_primary", name = "Primary Fire Rate", category = "Primary", target = "primary", description = "+8% fire speed", costs = { 150, 250, 350, 500 } },
    { id = "reload_primary", name = "Primary Reload", category = "Primary", target = "primary", description = "+10% reload speed", costs = { 125, 225, 325 } },
    { id = "clip_primary", name = "Primary Clip Size", category = "Primary", target = "primary", description = "+20% clip size", costs = { 100, 175, 250 } },
    { id = "ammo_primary", name = "Primary Ammo", category = "Primary", target = "primary", description = "+25% max ammo", costs = { 100, 200, 300 } },

    { id = "damage_secondary", name = "Secondary Damage", category = "Secondary", target = "secondary", description = "+12% damage", costs = { 150, 250, 350, 475 } },
    { id = "firerate_secondary", name = "Secondary Fire Rate", category = "Secondary", target = "secondary", description = "+8% fire speed", costs = { 150, 250, 350, 500 } },
    { id = "reload_secondary", name = "Secondary Reload", category = "Secondary", target = "secondary", description = "+10% reload speed", costs = { 125, 225, 325 } },
    { id = "clip_secondary", name = "Secondary Clip Size", category = "Secondary", target = "secondary", description = "+20% clip size", costs = { 100, 175, 250 } },
    { id = "ammo_secondary", name = "Secondary Ammo", category = "Secondary", target = "secondary", description = "+25% max ammo", costs = { 100, 200, 300 } },

    { id = "damage_melee", name = "Melee Damage", category = "Melee", target = "melee", description = "+15% melee damage", costs = { 125, 225, 325, 425 } },
    { id = "swing_melee", name = "Melee Swing Speed", category = "Melee", target = "melee", description = "+10% swing speed", costs = { 125, 225, 325 } },
    { id = "lifesteal_melee", name = "Melee Life Steal", category = "Melee", target = "melee", description = "Heal per melee hit", costs = { 150, 275, 400 } },

    { id = "building_health", name = "Building Health", category = "Engineer", target = "player", classes = { "engineer" }, description = "+15% building health", costs = { 150, 250, 350 } },
    { id = "building_rate", name = "Building Fire Rate", category = "Engineer", target = "player", classes = { "engineer" }, description = "+10% sentry fire rate", costs = { 200, 300, 450 } },
    { id = "canteen_capacity", name = "Canteen Specialist", category = "Canteen", target = "player", description = "+1 max canteen charge", costs = { 150, 300 } },
}

local upgradesById = {}
for _, upgrade in ipairs(TF_MVMShop.Upgrades) do
    upgradesById[upgrade.id] = upgrade
end

local function IsMvMMap()
    return string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true) ~= nil
end

local function IsMvMPlayer(ply)
    return IsValid(ply) and ply:IsPlayer() and not ply.TFBot and ply:Team() == TEAM_RED
end

local function ClampInt(v)
    return math.max(0, math.floor(tonumber(v) or 0))
end

function TF_MVMShop:IsEnabledFor(ply)
    return IsMvMMap() and IsMvMPlayer(ply)
end

function TF_MVMShop:GetState(ply)
    ply.TF_MVMShopState = ply.TF_MVMShopState or {
        credits = self.StartingCredits,
        spent = 0,
        buybacks = 0,
        upgrades = {},
        canteen = {
            selected = "crit",
            cooldown = 0,
            charges = { crit = 0, uber = 0, refill = 0, build = 0 },
        },
    }
    return ply.TF_MVMShopState
end

function TF_MVMShop:GetCredits(ply)
    return self:GetState(ply).credits
end

function TF_MVMShop:SetCredits(ply, amount)
    local state = self:GetState(ply)
    state.credits = ClampInt(amount)
    ply:SetNWInt("TF_MVM_Credits", state.credits)
end

function TF_MVMShop:AddCredits(ply, amount)
    self:SetCredits(ply, self:GetCredits(ply) + (tonumber(amount) or 0))
end

function TF_MVMShop:GetLevel(ply, id)
    return ClampInt(self:GetState(ply).upgrades[id] or 0)
end

function TF_MVMShop:SetLevel(ply, id, level)
    self:GetState(ply).upgrades[id] = ClampInt(level)
end

function TF_MVMShop:GetBaseSpeed(ply)
    local classTable = ply.GetPlayerClassTable and ply:GetPlayerClassTable() or nil
    return tonumber(classTable and classTable.Speed) or 300
end

function TF_MVMShop:GetBaseHealth(ply)
    local classTable = ply.GetPlayerClassTable and ply:GetPlayerClassTable() or nil
    return tonumber(classTable and classTable.Health) or tonumber(classTable and classTable.MaxHealth) or 125
end

function TF_MVMShop:IsSetupOpenForPurchases()
    if not TF_MVM or not TF_MVM.Runtime then return true end
    if not TF_MVM.Runtime:IsManagedActive() then return true end
    return TF_MVM.Runtime:IsSetupPhase()
end

function TF_MVMShop:IsUpgradeAllowedForClass(ply, upgrade)
    if not upgrade.classes then return true end
    local className = string.lower(tostring(ply:GetPlayerClass() or ""))
    for _, name in ipairs(upgrade.classes) do
        if className == string.lower(name) then
            return true
        end
    end
    return false
end

function TF_MVMShop:CanBuyUpgrade(ply, id)
    if not self:IsEnabledFor(ply) then return false, "not_enabled" end
    if not self:IsSetupOpenForPurchases() then return false, "setup_only" end

    local upgrade = upgradesById[id]
    if not upgrade then return false, "invalid_upgrade" end
    if not self:IsUpgradeAllowedForClass(ply, upgrade) then return false, "class_restricted" end

    local level = self:GetLevel(ply, id)
    if level >= #upgrade.costs then return false, "maxed" end
    local cost = upgrade.costs[level + 1]
    if self:GetCredits(ply) < cost then return false, "no_credits" end

    return true
end

function TF_MVMShop:GetUpgradeCost(ply, id)
    local upgrade = upgradesById[id]
    if not upgrade then return nil end
    local level = self:GetLevel(ply, id)
    return upgrade.costs[level + 1]
end

function TF_MVMShop:GetWeaponSlotName(wep)
    if not IsValid(wep) then return "" end
    if wep.GetItemData then
        local itemData = wep:GetItemData()
        if itemData and isstring(itemData.item_slot) then
            local slot = string.lower(itemData.item_slot)
            if slot == "primary" or slot == "secondary" or slot == "melee" then
                return slot
            end
        end
    end

    local slot = tonumber(wep.Slot or (wep.GetSlot and wep:GetSlot()) or -1) or -1
    if slot == 0 then return "primary" end
    if slot == 1 then return "secondary" end
    if slot == 2 then return "melee" end
    return ""
end

function TF_MVMShop:GetDamageMultiplier(ply, slot)
    if slot == "primary" then return 1 + (0.12 * self:GetLevel(ply, "damage_primary")) end
    if slot == "secondary" then return 1 + (0.12 * self:GetLevel(ply, "damage_secondary")) end
    if slot == "melee" then return 1 + (0.15 * self:GetLevel(ply, "damage_melee")) end
    return 1
end
function TF_MVMShop:ApplyWeaponStats(ply)
    for _, wep in ipairs(ply:GetWeapons()) do
        if not IsValid(wep) then continue end

        local slot = self:GetWeaponSlotName(wep)
        local fireLevel = 0
        local reloadLevel = 0
        local clipLevel = 0

        if slot == "primary" then
            fireLevel = self:GetLevel(ply, "firerate_primary")
            reloadLevel = self:GetLevel(ply, "reload_primary")
            clipLevel = self:GetLevel(ply, "clip_primary")
        elseif slot == "secondary" then
            fireLevel = self:GetLevel(ply, "firerate_secondary")
            reloadLevel = self:GetLevel(ply, "reload_secondary")
            clipLevel = self:GetLevel(ply, "clip_secondary")
        elseif slot == "melee" then
            fireLevel = self:GetLevel(ply, "swing_melee")
        end

        if wep.Primary and isnumber(wep.Primary.Delay) then
            wep.TF_MVM_BasePrimaryDelay = wep.TF_MVM_BasePrimaryDelay or wep.Primary.Delay
            local mul = math.max(0.2, 1 - ((slot == "melee" and 0.1 or 0.08) * fireLevel))
            wep.Primary.Delay = wep.TF_MVM_BasePrimaryDelay * mul
        end

        if wep.Secondary and isnumber(wep.Secondary.Delay) and slot ~= "melee" then
            wep.TF_MVM_BaseSecondaryDelay = wep.TF_MVM_BaseSecondaryDelay or wep.Secondary.Delay
            local mul = math.max(0.2, 1 - (0.08 * fireLevel))
            wep.Secondary.Delay = wep.TF_MVM_BaseSecondaryDelay * mul
        end

        if isnumber(wep.ReloadTime) then
            wep.TF_MVM_BaseReloadTime = wep.TF_MVM_BaseReloadTime or wep.ReloadTime
            wep.ReloadTime = wep.TF_MVM_BaseReloadTime * math.max(0.2, 1 - (0.1 * reloadLevel))
        end

        if wep.Primary and isnumber(wep.Primary.ClipSize) and wep.Primary.ClipSize > 0 then
            wep.TF_MVM_BaseClipSize = wep.TF_MVM_BaseClipSize or wep.Primary.ClipSize
            local newClip = math.max(1, math.floor(wep.TF_MVM_BaseClipSize * (1 + (0.2 * clipLevel))))
            wep.Primary.ClipSize = newClip
            wep:SetClip1(math.min(wep:Clip1(), newClip))
        end
    end
end

function TF_MVMShop:ApplyPlayerStats(ply)
    if not self:IsEnabledFor(ply) then return end

    local hpBonus = 25 * self:GetLevel(ply, "max_health")
    local speedMul = 1 + (0.08 * self:GetLevel(ply, "move_speed"))
    local jumpMul = 1 + (0.1 * self:GetLevel(ply, "jump_height"))

    local maxHp = self:GetBaseHealth(ply) + hpBonus
    ply:SetMaxHealth(maxHp)
    if ply:Health() > maxHp then
        ply:SetHealth(maxHp)
    end

    local speed = math.floor(self:GetBaseSpeed(ply) * speedMul)
    if ply.SetClassSpeed then
        ply:SetClassSpeed(speed)
    else
        ply:SetWalkSpeed(speed)
        ply:SetRunSpeed(speed)
    end

    local baseJump = ply.TF_MVM_BaseJumpPower or ply:GetJumpPower()
    ply.TF_MVM_BaseJumpPower = baseJump
    ply:SetJumpPower(baseJump * jumpMul)

    self:ApplyWeaponStats(ply)
end

function TF_MVMShop:GetMaxCanteenCharges(ply)
    return 1 + self:GetLevel(ply, "canteen_capacity")
end

function TF_MVMShop:SyncCanteenNW(ply)
    local state = self:GetState(ply)
    ply:SetNWString("TF_MVM_CanteenSelected", state.canteen.selected or "crit")
    ply:SetNWInt("TF_MVM_Canteen_crit", ClampInt(state.canteen.charges.crit))
    ply:SetNWInt("TF_MVM_Canteen_uber", ClampInt(state.canteen.charges.uber))
    ply:SetNWInt("TF_MVM_Canteen_refill", ClampInt(state.canteen.charges.refill))
    ply:SetNWInt("TF_MVM_Canteen_build", ClampInt(state.canteen.charges.build))
end

function TF_MVMShop:BuildPayload(ply)
    local state = self:GetState(ply)
    local list = {}
    for _, upgrade in ipairs(self.Upgrades) do
        local level = self:GetLevel(ply, upgrade.id)
        list[#list + 1] = {
            id = upgrade.id,
            name = upgrade.name,
            description = upgrade.description,
            category = upgrade.category,
            target = upgrade.target,
            level = level,
            maxLevel = #upgrade.costs,
            nextCost = upgrade.costs[level + 1] or 0,
            classAllowed = self:IsUpgradeAllowedForClass(ply, upgrade),
        }
    end

    return {
        credits = self:GetCredits(ply),
        inSetup = TF_MVMState and TF_MVMState:Get("in_setup", false) or false,
        waveCurrent = TF_MVMState and TF_MVMState:Get("wave_current", 0) or 0,
        waveTotal = TF_MVMState and TF_MVMState:Get("wave_total", 0) or 0,
        canteen = {
            selected = state.canteen.selected,
            maxCharges = self:GetMaxCanteenCharges(ply),
            charges = {
                crit = ClampInt(state.canteen.charges.crit),
                uber = ClampInt(state.canteen.charges.uber),
                refill = ClampInt(state.canteen.charges.refill),
                build = ClampInt(state.canteen.charges.build),
            },
        },
        canteenTypes = self.CanteenTypes,
        upgrades = list,
    }
end

if SERVER then
    local function SendPanel(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        net.Start("TF_MVM_UpgradeOpen")
        net.WriteTable(TF_MVMShop:BuildPayload(ply))
        net.Send(ply)
    end

    function TF_MVMShop:IsNearUpgradeStation(ply)
        if ply:GetNWBool("TF_MVM_InUpgradeStation", false) then return true end
        local eyePos = ply:EyePos()
        for _, ent in ipairs(ents.FindInSphere(eyePos, 170)) do
            if not IsValid(ent) then continue end
            local className = string.lower(ent:GetClass() or "")
            local entName = ent.GetName and string.lower(ent:GetName() or "") or ""
            if string.find(className, "upgrade", 1, true) or string.find(entName, "upgrade", 1, true) then
                return true
            end
        end
        return false
    end

    function TF_MVMShop:ResetPlayer(ply, startingCredits)
        local state = self:GetState(ply)
        state.spent = 0
        state.buybacks = 0
        state.upgrades = {}
        state.canteen.selected = "crit"
        state.canteen.cooldown = 0
        state.canteen.charges = { crit = 0, uber = 0, refill = 0, build = 0 }
        self:SetCredits(ply, startingCredits or self.StartingCredits)
        self:SyncCanteenNW(ply)
        self:ApplyPlayerStats(ply)
    end

    function TF_MVMShop:ResetAllPlayers(startingCredits)
        for _, ply in ipairs(player.GetAll()) do
            if self:IsEnabledFor(ply) then
                self:ResetPlayer(ply, startingCredits)
            end
        end
    end

    function TF_MVMShop:BuyUpgrade(ply, id)
        local can, reason = self:CanBuyUpgrade(ply, id)
        if not can then return false, reason end
        local cost = self:GetUpgradeCost(ply, id)
        if not cost then return false, "invalid_upgrade" end

        local state = self:GetState(ply)
        self:AddCredits(ply, -cost)
        self:SetLevel(ply, id, self:GetLevel(ply, id) + 1)
        state.spent = state.spent + cost
        self:ApplyPlayerStats(ply)
        return true
    end

    function TF_MVMShop:Respec(ply)
        if not self:IsEnabledFor(ply) then return false, "not_enabled" end
        if not self:IsSetupOpenForPurchases() then return false, "setup_only" end

        local state = self:GetState(ply)
        local refund = ClampInt(state.spent)
        state.spent = 0
        state.upgrades = {}
        self:AddCredits(ply, refund)
        self:ApplyPlayerStats(ply)
        return true
    end

    function TF_MVMShop:BuyCanteenCharge(ply, ctype)
        if not self:IsEnabledFor(ply) then return false, "not_enabled" end
        if not self:IsSetupOpenForPurchases() then return false, "setup_only" end

        local c = self.CanteenTypes[ctype]
        if not c then return false, "invalid_canteen" end

        local state = self:GetState(ply)
        if ClampInt(state.canteen.charges[ctype]) >= self:GetMaxCanteenCharges(ply) then
            return false, "canteen_full"
        end

        if self:GetCredits(ply) < c.cost then
            return false, "no_credits"
        end

        self:AddCredits(ply, -c.cost)
        state.canteen.charges[ctype] = ClampInt(state.canteen.charges[ctype]) + 1
        self:SyncCanteenNW(ply)
        return true
    end

    function TF_MVMShop:SelectCanteen(ply, ctype)
        if not self.CanteenTypes[ctype] then return false, "invalid_canteen" end
        self:GetState(ply).canteen.selected = ctype
        self:SyncCanteenNW(ply)
        return true
    end
    local function ApplyCanteenCrit(ply)
        if GAMEMODE and GAMEMODE.AddCritBoostTime then
            GAMEMODE:AddCritBoostTime(ply, 8)
        end
    end

    local function ApplyCanteenUber(ply)
        ply.TF_MVMUberUntil = CurTime() + 5
        ply:SetNWFloat("TF_MVMUberUntil", ply.TF_MVMUberUntil)
    end

    local function ApplyCanteenRefill(ply)
        for _, wep in ipairs(ply:GetWeapons()) do
            if not IsValid(wep) then continue end
            local max1 = wep:GetMaxClip1()
            if max1 and max1 > 0 then wep:SetClip1(max1) end
            local max2 = wep:GetMaxClip2()
            if max2 and max2 > 0 then wep:SetClip2(max2) end
        end
        if GAMEMODE and GAMEMODE.GiveAmmoPercent then
            GAMEMODE:GiveAmmoPercent(ply, 100)
        end
    end

    local function ApplyCanteenBuildings(ply)
        local healthMul = 1 + (0.15 * TF_MVMShop:GetLevel(ply, "building_health"))
        local fireMul = 1 + (0.1 * TF_MVMShop:GetLevel(ply, "building_rate"))
        for _, className in ipairs({ "obj_sentrygun", "obj_dispenser", "obj_teleporter" }) do
            for _, ent in ipairs(ents.FindByClass(className)) do
                if not IsValid(ent) or ent:GetOwner() ~= ply then continue end
                local base = ent.TF_MVM_BaseMaxHealth or ent:GetMaxHealth()
                ent.TF_MVM_BaseMaxHealth = base
                local newMax = math.max(1, math.floor(base * healthMul))
                ent:SetMaxHealth(newMax)
                ent:SetHealth(newMax)
                if className == "obj_sentrygun" then
                    ent.FireRate = (ent.FireRate or 0.1) / fireMul
                end
            end
        end
    end

    function TF_MVMShop:GetBuybackCost(ply)
        local state = self:GetState(ply)
        local wave = TF_MVMState and ClampInt(TF_MVMState:Get("wave_current", 1)) or 1
        local base = self.BuybackBaseCost + (state.buybacks * 150)
        return math.floor(base * (1 + ((wave - 1) * 0.15)))
    end

    function TF_MVMShop:TryBuyback(ply)
        if not self:IsEnabledFor(ply) then return false, "not_enabled" end
        if ply:Alive() then return false, "alive" end
        if not (TF_MVM and TF_MVM.Runtime and TF_MVM.Runtime:IsWaveInProgress()) then return false, "wave_only" end

        local cost = self:GetBuybackCost(ply)
        if self:GetCredits(ply) < cost then return false, "no_credits" end

        local state = self:GetState(ply)
        state.buybacks = state.buybacks + 1
        self:AddCredits(ply, -cost)
        ply:Spawn()
        ply:EmitSound("MVM.PlayerBoughtIn")
        return true
    end

    function TF_MVMShop:UseCanteen(ply)
        if not self:IsEnabledFor(ply) then return false, "not_enabled" end
        if not ply:Alive() then return self:TryBuyback(ply) end

        if TF_MVM and TF_MVM.Runtime and TF_MVM.Runtime:IsManagedActive() and not TF_MVM.Runtime:IsWaveInProgress() then
            return false, "wave_only"
        end

        local state = self:GetState(ply)
        if state.canteen.cooldown > CurTime() then return false, "cooldown" end

        local selected = state.canteen.selected or "crit"
        local charges = ClampInt(state.canteen.charges[selected])
        if charges <= 0 then return false, "no_charge" end

        state.canteen.charges[selected] = charges - 1
        state.canteen.cooldown = CurTime() + 1.5

        if selected == "crit" then
            ApplyCanteenCrit(ply)
        elseif selected == "uber" then
            ApplyCanteenUber(ply)
        elseif selected == "refill" then
            ApplyCanteenRefill(ply)
        elseif selected == "build" then
            ApplyCanteenBuildings(ply)
        end

        self:SyncCanteenNW(ply)
        ply:EmitSound("MVM.PlayerUsedPowerup")
        return true
    end

    hook.Add("PlayerInitialSpawn", "TF_MVMShop_Init", function(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            TF_MVMShop:GetState(ply)
            local missionStart = TF_MVM and TF_MVM.Runtime and TF_MVM.Runtime.Mission and tonumber(TF_MVM.Runtime.Mission.StartingCurrency) or nil
            TF_MVMShop:SetCredits(ply, missionStart or TF_MVMShop.StartingCredits)
            TF_MVMShop:SyncCanteenNW(ply)
        end)
    end)

    hook.Add("PlayerSpawn", "TF_MVMShop_OnSpawn", function(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            TF_MVMShop:ApplyPlayerStats(ply)
        end)
    end)

    hook.Add("PlayerSwitchWeapon", "TF_MVMShop_OnSwitch", function(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        TF_MVMShop:ApplyWeaponStats(ply)
    end)

    hook.Add("EntityTakeDamage", "TF_MVMShop_DamageHooks", function(target, dmginfo)
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() and TF_MVMShop:IsEnabledFor(attacker) then
            local slot = ""
            local weapon = attacker:GetActiveWeapon()
            if IsValid(weapon) then slot = TF_MVMShop:GetWeaponSlotName(weapon) end
            dmginfo:ScaleDamage(TF_MVMShop:GetDamageMultiplier(attacker, slot))

            if slot == "melee" then
                local lifesteal = TF_MVMShop:GetLevel(attacker, "lifesteal_melee")
                if lifesteal > 0 then
                    attacker:SetHealth(math.min(attacker:Health() + 2 + (lifesteal * 2), attacker:GetMaxHealth()))
                end
            end
        end

        if IsValid(target) and target:IsPlayer() and TF_MVMShop:IsEnabledFor(target) then
            if target.TF_MVMUberUntil and target.TF_MVMUberUntil > CurTime() then
                dmginfo:ScaleDamage(0)
                return
            end

            local resistAll = TF_MVMShop:GetLevel(target, "resist_all")
            if resistAll > 0 then
                dmginfo:ScaleDamage(math.max(0.2, 1 - (0.08 * resistAll)))
            end

            local damageType = dmginfo:GetDamageType()
            if bit.band(damageType, DMG_BULLET) ~= 0 then
                local v = TF_MVMShop:GetLevel(target, "resist_bullet")
                if v > 0 then dmginfo:ScaleDamage(math.max(0.15, 1 - (0.1 * v))) end
            end
            if bit.band(damageType, DMG_BLAST) ~= 0 then
                local v = TF_MVMShop:GetLevel(target, "resist_blast")
                if v > 0 then dmginfo:ScaleDamage(math.max(0.15, 1 - (0.1 * v))) end
            end
            if bit.band(damageType, DMG_BURN) ~= 0 then
                local v = TF_MVMShop:GetLevel(target, "resist_fire")
                if v > 0 then dmginfo:ScaleDamage(math.max(0.15, 1 - (0.12 * v))) end
            end
        end
    end)

    hook.Add("PlayerDeath", "TF_MVMShop_HealOnKill", function(victim, _, attacker)
        if not IsValid(attacker) or not attacker:IsPlayer() then return end
        if attacker == victim or not TF_MVMShop:IsEnabledFor(attacker) then return end
        local level = TF_MVMShop:GetLevel(attacker, "heal_on_kill")
        if level > 0 and attacker:Alive() then
            attacker:SetHealth(math.min(attacker:Health() + level * 15, attacker:GetMaxHealth()))
        end
    end)

    hook.Add("TF_MVM_MissionStarted", "TF_MVMShop_ResetMission", function(mission)
        local start = tonumber(mission and mission.StartingCurrency) or TF_MVMShop.StartingCredits
        TF_MVMShop:ResetAllPlayers(start)
    end)

    hook.Add("TF_MVM_WaveStarted", "TF_MVMShop_ResetBuybacks", function()
        for _, ply in ipairs(player.GetAll()) do
            if TF_MVMShop:IsEnabledFor(ply) then
                TF_MVMShop:GetState(ply).buybacks = 0
            end
        end
    end)

    hook.Add("KeyPress", "TF_MVMShop_OpenOnUse", function(ply, key)
        if key ~= IN_USE then return end
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        if not TF_MVMShop:IsNearUpgradeStation(ply) then return end
        SendPanel(ply)
    end)

    concommand.Add("tf_mvm_shop", function(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        SendPanel(ply)
    end)

    concommand.Add("tf_mvm_use_canteen", function(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        TF_MVMShop:UseCanteen(ply)
    end)

    concommand.Add("tf_mvm_buyback", function(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        TF_MVMShop:TryBuyback(ply)
    end)

    concommand.Add("use_action_slot_item", function(ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        if TF_MVM and TF_MVM.Runtime and TF_MVM.Runtime:IsManagedActive() and TF_MVM.Runtime:IsSetupPhase() then
            TF_MVM.Runtime:TogglePlayerReady(ply)
            return
        end
        TF_MVMShop:UseCanteen(ply)
    end)

    net.Receive("TF_MVM_CanteenUse", function(_, ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end
        TF_MVMShop:UseCanteen(ply)
        SendPanel(ply)
    end)

    net.Receive("TF_MVM_UpgradeAction", function(_, ply)
        if not TF_MVMShop:IsEnabledFor(ply) then return end

        local action = net.ReadString()
        local arg = net.ReadString()

        if action == "request_open" then
            SendPanel(ply)
            return
        elseif action == "buy_upgrade" then
            TF_MVMShop:BuyUpgrade(ply, arg)
        elseif action == "respec" then
            TF_MVMShop:Respec(ply)
        elseif action == "buy_canteen" then
            TF_MVMShop:BuyCanteenCharge(ply, arg)
        elseif action == "select_canteen" then
            TF_MVMShop:SelectCanteen(ply, arg)
        elseif action == "buyback" then
            TF_MVMShop:TryBuyback(ply)
        end

        SendPanel(ply)
    end)
else
    local function IsNearUpgradeStationClient()
        local ply = LocalPlayer()
        if not IsValid(ply) then return false end
        if ply:GetNWBool("TF_MVM_InUpgradeStation", false) then return true end

        local eyePos = ply:EyePos()
        for _, ent in ipairs(ents.FindInSphere(eyePos, 170)) do
            if not IsValid(ent) then continue end
            local className = string.lower(ent:GetClass() or "")
            local entName = ent.GetName and string.lower(ent:GetName() or "") or ""
            if string.find(className, "upgrade", 1, true) or string.find(entName, "upgrade", 1, true) then
                return true
            end
        end

        return false
    end

    local function SendAction(action, arg)
        net.Start("TF_MVM_UpgradeAction")
        net.WriteString(action or "")
        net.WriteString(arg or "")
        net.SendToServer()
    end

    local function BuildPanel(payload)
        if not istable(payload) then return end

        if IsValid(TF_MVMUpgradeFrame) then
            TF_MVMUpgradeFrame:Remove()
        end

        local frame = vgui.Create("DFrame")
        TF_MVMUpgradeFrame = frame
        frame:SetTitle("")
        frame:SetSize(860, 580)
        frame:Center()
        frame:MakePopup()
        frame.Paint = function(self, w, h)
            surface.SetDrawColor(31, 27, 23, 245)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(197, 171, 129, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 2)

            draw.SimpleText("UPGRADE STATION", "Trebuchet24", 18, 14, Color(238, 222, 184), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("Credits: " .. tostring(payload.credits or 0), "Trebuchet24", w - 20, 14, Color(249, 223, 122), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

            local waveText = "Wave " .. tostring(payload.waveCurrent or 0) .. " / " .. tostring(payload.waveTotal or 0)
            waveText = waveText .. (payload.inSetup and "  |  SETUP" or "  |  ACTIVE")
            draw.SimpleText(waveText, "DermaDefaultBold", 20, 48, Color(214, 198, 164), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local categoryBox = vgui.Create("DComboBox", frame)
        categoryBox:SetPos(16, 54)
        categoryBox:SetSize(180, 20)
        for _, c in ipairs({ "All", "Player", "Primary", "Secondary", "Melee", "Engineer", "Canteen" }) do
            categoryBox:AddChoice(c)
        end
        categoryBox:SetValue("All")

        local selectedCategory = "All"

        local upgradeScroll = vgui.Create("DScrollPanel", frame)
        upgradeScroll:SetPos(16, 78)
        upgradeScroll:SetSize(560, 450)

        local function PopulateUpgrades()
            upgradeScroll:Clear()
            for _, up in ipairs(payload.upgrades or {}) do
                if selectedCategory ~= "All" and up.category ~= selectedCategory then
                    continue
                end

                local row = upgradeScroll:Add("DPanel")
                row:Dock(TOP)
                row:DockMargin(0, 0, 0, 8)
                row:SetTall(82)
                row.Paint = function(self, w, h)
                    surface.SetDrawColor(44, 40, 35, 230)
                    surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(96, 84, 65, 255)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                end

                local title = vgui.Create("DLabel", row)
                title:SetPos(10, 8)
                title:SetSize(340, 18)
                title:SetFont("DermaLarge")
                title:SetText(up.name .. "  (" .. tostring(up.level) .. "/" .. tostring(up.maxLevel) .. ")")

                local desc = vgui.Create("DLabel", row)
                desc:SetPos(10, 34)
                desc:SetSize(370, 16)
                desc:SetFont("DermaDefault")
                desc:SetText(up.description or "")

                local cat = vgui.Create("DLabel", row)
                cat:SetPos(10, 56)
                cat:SetSize(200, 16)
                cat:SetFont("DermaDefaultBold")
                cat:SetText("Category: " .. tostring(up.category or ""))

                local buy = vgui.Create("DButton", row)
                buy:SetPos(390, 18)
                buy:SetSize(160, 42)
                if not up.classAllowed then
                    buy:SetText("CLASS LOCKED")
                    buy:SetEnabled(false)
                elseif (up.nextCost or 0) <= 0 then
                    buy:SetText("MAXED")
                    buy:SetEnabled(false)
                else
                    buy:SetText("Buy  (" .. tostring(up.nextCost) .. " cr)")
                end
                buy.DoClick = function()
                    SendAction("buy_upgrade", up.id)
                end
            end
        end

        categoryBox.OnSelect = function(_, _, value)
            selectedCategory = value
            PopulateUpgrades()
        end

        PopulateUpgrades()

        local right = vgui.Create("DPanel", frame)
        right:SetPos(592, 78)
        right:SetSize(252, 450)
        right.Paint = function(self, w, h)
            surface.SetDrawColor(40, 36, 31, 225)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(96, 84, 65, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("POWER-UP CANTEEN", "DermaLarge", 12, 10, Color(229, 216, 183), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local canteen = payload.canteen or {}
        local selected = canteen.selected or "crit"
        local maxCharges = tonumber(canteen.maxCharges or 1) or 1
        local y = 44

        for key, info in SortedPairs(payload.canteenTypes or {}) do
            local charges = tonumber((canteen.charges and canteen.charges[key]) or 0) or 0

            local nameLabel = vgui.Create("DLabel", right)
            nameLabel:SetPos(12, y)
            nameLabel:SetSize(228, 18)
            nameLabel:SetFont("DermaDefaultBold")
            nameLabel:SetText((selected == key and "> " or "") .. info.name .. "  [" .. charges .. "/" .. maxCharges .. "]")

            local descLabel = vgui.Create("DLabel", right)
            descLabel:SetPos(12, y + 18)
            descLabel:SetSize(228, 16)
            descLabel:SetFont("DermaDefault")
            descLabel:SetText(info.description or "")

            local selectBtn = vgui.Create("DButton", right)
            selectBtn:SetPos(12, y + 36)
            selectBtn:SetSize(108, 24)
            selectBtn:SetText("Select")
            selectBtn.DoClick = function()
                SendAction("select_canteen", key)
            end

            local buyBtn = vgui.Create("DButton", right)
            buyBtn:SetPos(132, y + 36)
            buyBtn:SetSize(108, 24)
            buyBtn:SetText("Buy (" .. tostring(info.cost or 0) .. ")")
            buyBtn.DoClick = function()
                SendAction("buy_canteen", key)
            end

            y = y + 72
        end

        local useBtn = vgui.Create("DButton", right)
        useBtn:SetPos(12, right:GetTall() - 76)
        useBtn:SetSize(228, 28)
        useBtn:SetText("Use Selected Canteen")
        useBtn.DoClick = function()
            net.Start("TF_MVM_CanteenUse")
            net.SendToServer()
        end

        local respecBtn = vgui.Create("DButton", frame)
        respecBtn:SetPos(16, frame:GetTall() - 36)
        respecBtn:SetSize(130, 24)
        respecBtn:SetText("Respec")
        respecBtn.DoClick = function()
            SendAction("respec", "")
        end

        local refreshBtn = vgui.Create("DButton", frame)
        refreshBtn:SetPos(154, frame:GetTall() - 36)
        refreshBtn:SetSize(130, 24)
        refreshBtn:SetText("Refresh")
        refreshBtn.DoClick = function()
            SendAction("request_open", "")
        end

        local closeBtn = vgui.Create("DButton", frame)
        closeBtn:SetPos(frame:GetWide() - 146, frame:GetTall() - 36)
        closeBtn:SetSize(130, 24)
        closeBtn:SetText("Close")
        closeBtn.DoClick = function()
            frame:Close()
        end
    end

    local function OpenPrompt()
        if IsValid(TF_MVMUpgradePrompt) then return end
        local pnl = vgui.Create("DPanel")
        TF_MVMUpgradePrompt = pnl
        pnl:SetSize(320, 74)
        pnl:SetPos((ScrW() - 320) * 0.5, ScrH() - 185)
        pnl.Paint = function(self, w, h)
            surface.SetDrawColor(25, 22, 19, 225)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(192, 171, 127, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
            draw.SimpleText("UPGRADE STATION", "Trebuchet24", w * 0.5, 22, Color(235, 221, 182), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Press E to Upgrade", "DermaDefaultBold", w * 0.5, 50, Color(234, 220, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    local function ClosePrompt()
        if not IsValid(TF_MVMUpgradePrompt) then return end
        TF_MVMUpgradePrompt:Remove()
        TF_MVMUpgradePrompt = nil
    end

    hook.Add("Think", "TF_MVMShop_ClientPromptThink", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        if not IsMvMMap() or not ply:Alive() or GetConVarNumber("cl_drawhud") == 0 then
            ClosePrompt()
            return
        end
        if IsNearUpgradeStationClient() then
            OpenPrompt()
        else
            ClosePrompt()
        end
    end)

    hook.Add("PlayerBindPress", "TF_MVMShop_ActionSlotBind", function(_, bind, pressed)
        if not pressed then return end
        local lower = string.lower(bind or "")
        if not string.find(lower, "+use_action_slot_item", 1, true) then return end
        if not IsMvMMap() then return end
        RunConsoleCommand("tf_mvm_use_canteen")
        return true
    end)

    concommand.Add("tf_mvm_shop", function()
        SendAction("request_open", "")
    end)

    concommand.Add("tf_mvm_use_canteen", function()
        net.Start("TF_MVM_CanteenUse")
        net.SendToServer()
    end)

    net.Receive("TF_MVM_UpgradeOpen", function()
        BuildPanel(net.ReadTable() or {})
    end)
end

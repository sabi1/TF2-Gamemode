-- server console commands to help test TF2 condition system
if CLIENT then return end

local ENUM = include("tf2_conditions/sh_tfcond_enum.lua")
local ETFCond = ENUM.ETFCond

local function FindPlayerByString(str)
    if not str or str == "" then return nil end
    local n = tonumber(str)
    if n then
        return Player(n)
    end
    str = string.lower(str)
    for _, ply in ipairs(player.GetAll()) do
        if string.find(string.lower(ply:Nick()), str, 1, true) then
            return ply
        end
    end
    return nil
end

local function DoAddCond(exec, cmd, args)
    local cond = tonumber(args[1])
    if not cond then
        print("Usage: tf2_addcond <cond_id> [duration] [target]")
        return
    end
    local dur = tonumber(args[2])
    local targetArg = args[3]
    local target
    if IsValid(exec) and exec:IsPlayer() and not targetArg then
        target = exec
    else
        target = FindPlayerByString(targetArg)
    end
    if not IsValid(target) then
        print("tf2_addcond: target player not found")
        return
    end
    print(string.format("[TF2_Cond] tf2_addcond called by %s -> applying cond %s dur=%s to %s", tostring(exec or "console"), tostring(cond), tostring(dur), tostring(target)))
    if not target.TF2AddCond then
        print("tf2_addcond: TF2 condition module API not available on target")
        return
    end
    local ok = target:TF2AddCond(cond, dur, target)
    print("tf2_addcond result:", ok)
end

-- defer command registration until after map/gamemode initialized to ensure ours wins
hook.Add("InitPostEntity", "TF2_Cond_RegisterServerCommands", function()
    concommand.Add("tf2_addcond", DoAddCond)
end)

-- also allow clients to request a condition be added to themselves
util.AddNetworkString("TF2_Cond_ClientAdd")
net.Receive("TF2_Cond_ClientAdd", function(len, ply)
    local cond = net.ReadInt(16)
    local dur = net.ReadFloat()
    print("[TF2_Cond] client request to add cond", cond, "to", ply)
    if not ply.TF2AddCond then return end
    ply:TF2AddCond(cond, dur, ply)
end)


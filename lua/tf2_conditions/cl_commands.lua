-- clientside console commands for TF2 condition system
if SERVER then return end

-- send a request to the server to add a condition to ourselves
local function SendAddCond(args)
    local cond = tonumber(args[1]) or 0
    local dur = tonumber(args[2]) or 0
    net.Start("TF2_Cond_ClientAdd")
        net.WriteInt(cond,16)
        net.WriteFloat(dur)
    net.SendToServer()
end

-- register our commands after everything loads so they override gamemode's
hook.Add("InitPostEntity", "TF2_Cond_RegisterClientCommands", function()
    concommand.Add("tf2_addcond", function(ply, cmd, args)
        SendAddCond(args)
    end)
end)

print("[TF2_Cond] cl_commands loaded")

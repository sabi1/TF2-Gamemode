TF_MVMState = TF_MVMState or {}
TF_MVMState.Data = TF_MVMState.Data or {}

local STATE = TF_MVMState

local function CopyTableShallow(src)
    local out = {}
    for k, v in pairs(src or {}) do
        out[k] = v
    end
    return out
end

function STATE:Get(key, defaultValue)
    local v = self.Data[key]
    if v == nil then
        return defaultValue
    end
    return v
end

if SERVER then
    util.AddNetworkString("TF_MVM_StateFull")
    util.AddNetworkString("TF_MVM_StateDelta")

    function STATE:BroadcastFull(target)
        net.Start("TF_MVM_StateFull")
        net.WriteTable(self.Data)
        if IsValid(target) then
            net.Send(target)
        else
            net.Broadcast()
        end
    end

    function STATE:SetAll(newData, silent)
        self.Data = CopyTableShallow(newData)
        if not silent then
            self:BroadcastFull()
        end
    end

    function STATE:Set(key, value, silent)
        if self.Data[key] == value then return end

        self.Data[key] = value
        if silent then return end

        net.Start("TF_MVM_StateDelta")
        net.WriteString(tostring(key))
        net.WriteTable({ value = value })
        net.Broadcast()
    end

    function STATE:SyncPlayer(ply)
        if not IsValid(ply) then return end
        self:BroadcastFull(ply)
    end

    hook.Add("PlayerInitialSpawn", "TF_MVM_StateSyncJoin", function(ply)
        timer.Simple(0.25, function()
            if not IsValid(ply) then return end
            STATE:SyncPlayer(ply)
        end)
    end)
else
    net.Receive("TF_MVM_StateFull", function()
        local tbl = net.ReadTable() or {}
        STATE.Data = tbl
        hook.Run("TF_MVM_StateUpdated", "full", tbl)
    end)

    net.Receive("TF_MVM_StateDelta", function()
        local key = net.ReadString()
        local payload = net.ReadTable() or {}
        STATE.Data[key] = payload.value
        hook.Run("TF_MVM_StateUpdated", key, payload.value)
    end)
end

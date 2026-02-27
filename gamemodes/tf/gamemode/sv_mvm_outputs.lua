TF_MVM = TF_MVM or {}

local OUT = {}
TF_MVM.Outputs = OUT

local function ToArray(v)
    if v == nil then return {} end
    if istable(v) and v[1] ~= nil then return v end
    return { v }
end

local function ParseOutputEntry(entry)
    if not istable(entry) then
        return nil
    end

    local target = entry.Target or entry.target or ""
    local action = entry.Action or entry.action or "Trigger"
    local param = entry.Param or entry.param or ""
    local delay = tonumber(entry.Delay or entry.delay or 0) or 0

    if target == "" then
        return nil
    end

    return {
        target = tostring(target),
        action = tostring(action),
        param = tostring(param),
        delay = delay,
    }
end

function OUT:Fire(entries)
    for _, raw in ipairs(ToArray(entries)) do
        local e = ParseOutputEntry(raw)
        if not e then continue end

        for _, ent in ipairs(ents.FindByName(e.target)) do
            if not IsValid(ent) then continue end
            ent:Fire(e.action, e.param, e.delay)
        end
    end
end

return OUT

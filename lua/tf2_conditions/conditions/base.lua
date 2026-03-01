-- base helper for condition definition
-- each condition file returns a table with methods described in prompt:
-- OnAdded(ply, provider), OnRemoved(ply), OnThink(ply), ModifyDamage(ply,dmg), etc.
-- See tf_condition.h and individual C++ implementations for reference.

local tbl = {}

function tbl:Create(def)
    -- simply return definition; could add inheritance if needed
    return def
end

return tbl

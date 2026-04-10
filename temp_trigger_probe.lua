local found = 0
for _, ent in ipairs(ents.FindByClass('trigger_multiple')) do
  local kv = ent.GetKeyValues and ent:GetKeyValues() or {}
  if kv.filtername or kv.FilterName or kv.target or kv.Target then
    print(string.format('trigger #%d name=%s filter=%s target=%s parent=%s', ent:EntIndex(), tostring(ent:GetName() or ''), tostring(kv.filtername or kv.FilterName), tostring(kv.target or kv.Target), tostring(ent:GetParent())))
    found = found + 1
  end
end
print('found triggers', found)

local META = FindMetaTable("Entity")

function META:GetProxyVar(k)
    if self.__ProxyVars then
        return self.__ProxyVars[k]
    end
end

function META:SetProxyVar(k, v)
    if not self.__ProxyVars then self.__ProxyVars = {} end
    self.__ProxyVars[k] = v
end

function META:ClearProxyVars()
    self.__ProxyVars = {} 
end

if not matproxy or not matproxy.Add then
    MsgN("matproxy library not available, not installing TF2 proxies")
    return
end
 
function GM:LoadTFProxies()
    local path = string.Replace(self.Folder, "gamemodes/", "").."/gamemode/proxies/"
    for _,f in pairs(file.Find(path.."*.lua", "LUA")) do
        PROXY = {}
        include(path..f)
        
        local proxyname = string.Replace(f, ".lua", "")
        
        if type(PROXY.Init)=="function" and type(PROXY.OnBind)=="function" and type(PROXY.GetMaterial)=="function" then
            local legacyInit = PROXY.Init
            local legacyBind = PROXY.OnBind
            matproxy.Add({
                name = proxyname,
                init = function(self, mat, values)
                    if legacyInit(self, mat, values) == false then return false end
                    return true
                end,
                bind = function(self, mat, ent)
                    legacyBind(self, ent)
                end,
            })
            MsgN(Format("Registered legacy proxy '%s'", proxyname))
        else
            MsgN(Format("Loaded proxy file '%s'", proxyname))
        end
    end
    
    -- Materialien neu laden - FIXED VERSION
    if matproxy and matproxy.ReloadMaterials then
        matproxy.ReloadMaterials()
    elseif render and render.ReloadMaterials then
        render.ReloadMaterials()
    else
        -- Fallback: Material-Cache leeren
        MsgN("Warning: Could not reload materials automatically")
    end
end

GM:LoadTFProxies()
TF_VISION_FILTER_PYRO = TF_VISION_FILTER_PYRO or 0x01
TF_VISION_FILTER_ROME = TF_VISION_FILTER_ROME or 0x04

local function GetSchemaAttributeValue(item, attributeClass)
	if not istable(item) or not isstring(attributeClass) or attributeClass == "" then return nil end

	local attrs = item.attributes_by_id or item.attributes
	if not istable(attrs) then return nil end

	for _, attr in pairs(attrs) do
		if istable(attr) and attr.attribute_class == attributeClass and attr.value ~= nil then
			return tonumber(attr.value) or attr.value
		end
	end

	return nil
end

local function GetItemVisionOptInFlags(itemEnt)
	if not IsValid(itemEnt) then return 0 end

	local flags = 0
	if isfunction(itemEnt.GetAttributeValue) then
		flags = tonumber(itemEnt:GetAttributeValue("vision_opt_in_flags", 0)) or 0
	end

	if flags == 0 and isfunction(itemEnt.GetItemData) then
		flags = tonumber(GetSchemaAttributeValue(itemEnt:GetItemData(), "vision_opt_in_flags")) or 0
	end

	return flags
end

local function GetObservedTarget(ply)
	if not IsValid(ply) or not ply.IsPlayer or not ply:IsPlayer() then return nil end
	if not ply.GetObserverTarget then return nil end
	local target = ply:GetObserverTarget()
	if IsValid(target) and target:IsPlayer() then
		return target
	end
	return nil
end

function TF2_GetVisionFilterFlags(ply, options)
	options = options or {}

	local flags = 0
	local manualPyrovision = GetConVar("tf_pyrovision")
	if manualPyrovision and manualPyrovision:GetBool() and not options.ignoreManual then
		flags = bit.bor(flags, TF_VISION_FILTER_PYRO)
	end

	if IsValid(ply) and ply.GetTFItems and not options.ignoreLoadout then
		for _, item in ipairs(ply:GetTFItems()) do
			flags = bit.bor(flags, GetItemVisionOptInFlags(item))
		end
	end

	local romevisionOptIn = GetConVar("tf_romevision_opt_in")
	if romevisionOptIn
		and romevisionOptIn:GetBool()
		and GetGlobalBool("TF_MVM_RomevisionAvailable", false)
		and string.find(string.lower(game.GetMap() or ""), "mvm_", 1, true)
	then
		flags = bit.bor(flags, TF_VISION_FILTER_ROME)
	end

	if CLIENT and IsValid(ply) and ply == LocalPlayer() and not options.ignoreSpectator then
		local observed = GetObservedTarget(ply)
		if IsValid(observed) then
			flags = bit.bor(flags, TF2_GetVisionFilterFlags(observed, {
				ignoreSpectator = true,
			}))
		end
	end

	return flags
end

function TF2_IsPyrovisionEnabled(ply)
	if not IsValid(ply) then
		if CLIENT and IsValid(LocalPlayer()) then
			ply = LocalPlayer()
		end
	end

	return bit.band(TF2_GetVisionFilterFlags(ply), TF_VISION_FILTER_PYRO) ~= 0
end

function TF2_IsRomevisionEnabled(ply)
	if not IsValid(ply) then
		if CLIENT and IsValid(LocalPlayer()) then
			ply = LocalPlayer()
		end
	end

	return bit.band(TF2_GetVisionFilterFlags(ply), TF_VISION_FILTER_ROME) ~= 0
end

if CLIENT then
 
	local Suffixes = {"rt", "lf", "up", "ft", "dn", "bk"}
	local Skybox = GetConVarString("sv_skyname")
	local Replacement = "rj/sky_pyroland_01" 
	for k,v in pairs(Suffixes) do
		if TF2_IsPyrovisionEnabled(LocalPlayer()) then 
			Material(Skybox..v):SetTexture("$basetexture", Replacement..v)
		end
	end

	local function replace(str,strb,text,rembump,texture2)
		local SourceMaterial = Material(str)
		local ReplacementMaterial = Material(strb)
		local D = ReplacementMaterial:GetTexture("$basetexture")
		if(!text) then
			SourceMaterial:SetTexture("$basetexture", D)
			if(texture2 != nil) then
					SourceMaterial:SetTexture("$basetexture2", texture2)
			end
			//SourceMaterial:SetTexture("$lightwarptexture", "rj/colorbar_peach02")
		else
			if(texture2 != nil) then
				SourceMaterial:SetTexture("$basetexture2", texture2)
			end
			SourceMaterial:SetTexture("$basetexture", strb)
		end
		if(rembump) then
			SourceMaterial:SetTexture("$blendmodulatetexture", "nature/snowgrass_blendmask")
		end
	end

	timer.Create("ReplaceTextures", 1, 0, function()
		if TF2_IsPyrovisionEnabled(LocalPlayer()) then

			replace("models/props_doomsday/dirtground006","rj/papergrain_pink",true,true)
			replace("nature/blendground_doomsday001","rj/colorbar_wood02",true,true,"rj/sky_pyroland_01dn")
			replace("nature/dirtground001","rj/colorbar_peach02",true,true)
			replace("nature/dirtground001","rj/colorbar_peach02",true,true)
			replace("nature/dirtroad003","rj/colorbar_peach02",true,true)
			replace("nature/gm_construct_grass","rj/sky_pyroland_01dn",true,true)
			replace("gm_construct/grass_13","rj/sky_pyroland_01dn",true,true,"rj/sky_pyroland_01dn") 
			replace("gm_construct/flatgrass","rj/sky_pyroland_01dn",true,true,"rj/sky_pyroland_01dn") 
			replace("gm_construct/flatgrass_2","rj/sky_pyroland_01dn",true,true,"rj/sky_pyroland_01dn") 
			replace("gm_construct/grass-sand_13","rj/sky_pyroland_01dn",true,true,"rj/papergrain_pink") 
			replace("gm_construct/water_13","rj/papergrain_pink",true,true,"rj/papergrain_pink") 
			replace("gm_construct/wall_bottom","rj/sky_pyroland_01dn",true,true) 
			replace("gm_construct/wall_top","rj/papergrain_pink",true,true) 
			replace("brick/brickwall003a_construct","rj/sky_badlands_pyroland_dn",true,true,"rj/sky_badlands_pyroland_dn") 
			replace("models/props_junk/woodcrates01a","rj/papergrain_pink",true,true) 
			replace("concrete/concretefloor009a_construct","rj/papergrain_pink",true,true) 
			replace("concrete/concretefloor026a","rj/papergrain_pink",true,true) 
			replace("concrete/concretefloor028a","rj/sky_badlands_pyroland_dn",true,true,"rj/sky_badlands_pyroland_dn") 
			replace("building_template/roof_template001a","rj/sky_pyroland_01dn",true,true) 
			replace("plaster/plasterwall022c","rj/colorbar_pink01",true,true)   
			replace("models/props_junk/woodcrates02a","rj/papergrain_pink",true,true) 
			replace("gm_construct/construct_sand","rj/sky_pyroland_01dn",true,true) 
			replace("gm_construct/construct_concrete_floor","rj/sky_badlands_pyroland_dn",true,true) 
			replace("gm_construct/construct_concrete_ground","rj/papergrain_pink",true,true) 
			 
			 
			replace("models/props_mining/rock006","rj/colorbar3",true,true)
			replace("nature/blendrockgroundwall004","rj/sky_badlands_pyroland_up_rot90",true,true)
			replace("nature/blendrockground004","rj/sky_badlands_pyroland_up_rot90",true,true)
			replace("nature/rockwall007","rj/colorbar3",true,true)
			 
			 
			 
			replace("models/props_mining/rock001","rj/colorbar_purple01",true,true)
			replace("models/props_mining/rock002","rj/colorbar_purple01",true,true)
			replace("models/props_mining/rock003","rj/colorbar_purple01",true,true)
			replace("models/props_mining/rock004","rj/colorbar_purple01",true,true)
			replace("models/props_mining/rock005","rj/colorbar_purple01",true,true)
			 
			   
			 
			replace("overlays/dirtroad001","rj/papergrain_pink")
			replace("detail/detailsprites_dustbow","rj/detailsprites_pyrovision02",true,true)

		end
	end)
end

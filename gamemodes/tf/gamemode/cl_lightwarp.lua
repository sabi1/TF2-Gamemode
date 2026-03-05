local cvEnable = CreateClientConVar("tf_lightwarp_enable", "1", true, false, "Enable TF2-style lightwarp lighting for TF addon rendering.")
local cvStrength = CreateClientConVar("tf_lightwarp_strength", "1.0", true, false, "Multiplier for TF2-style lightwarp lighting intensity.")

local lwStateDepth = 0

local function GetLightwarpStrength()
	return math.Clamp(cvStrength:GetFloat(), 0.1, 2.0)
end

local function ApplyTF2LightwarpLighting(origin)
	local s = GetLightwarpStrength()
	local amb = 0.07 * s

	render.SetLightingOrigin(origin or EyePos())
	render.ResetModelLighting(amb, amb, amb)

	render.SetModelLighting(BOX_TOP, math.min(1, 0.78 * s), math.min(1, 0.76 * s), math.min(1, 0.72 * s))
	render.SetModelLighting(BOX_FRONT, math.min(1, 0.60 * s), math.min(1, 0.58 * s), math.min(1, 0.54 * s))
	render.SetModelLighting(BOX_RIGHT, math.min(1, 0.24 * s), math.min(1, 0.25 * s), math.min(1, 0.28 * s))
	render.SetModelLighting(BOX_LEFT, math.min(1, 0.15 * s), math.min(1, 0.13 * s), math.min(1, 0.11 * s))
	render.SetModelLighting(BOX_BACK, math.min(1, 0.06 * s), math.min(1, 0.06 * s), math.min(1, 0.06 * s))
	render.SetModelLighting(BOX_BOTTOM, math.min(1, 0.02 * s), math.min(1, 0.02 * s), math.min(1, 0.02 * s))
end

local function BeginLightwarp(origin)
	if not cvEnable:GetBool() then return false end

	lwStateDepth = lwStateDepth + 1
	if lwStateDepth == 1 then
		ApplyTF2LightwarpLighting(origin)
	end
	return true
end

local function EndLightwarp()
	if lwStateDepth <= 0 then return end
	lwStateDepth = lwStateDepth - 1

	if lwStateDepth == 0 then
		-- Return to neutral-ish model lighting so we do not leak state outside TF rendering hooks.
		render.ResetModelLighting(1, 1, 1)
		render.SetModelLighting(BOX_TOP, 0, 0, 0)
		render.SetModelLighting(BOX_FRONT, 0, 0, 0)
		render.SetModelLighting(BOX_RIGHT, 0, 0, 0)
		render.SetModelLighting(BOX_LEFT, 0, 0, 0)
		render.SetModelLighting(BOX_BACK, 0, 0, 0)
		render.SetModelLighting(BOX_BOTTOM, 0, 0, 0)
	end
end

TF2LightwarpApplyModelLighting = ApplyTF2LightwarpLighting

hook.Add("PrePlayerDraw", "TF2Lightwarp_PrePlayerDraw", function(ply)
	if not IsValid(ply) then return end
	BeginLightwarp(ply:GetPos() + Vector(0, 0, 64))
end)

hook.Add("PostPlayerDraw", "TF2Lightwarp_PostPlayerDraw", function()
	EndLightwarp()
end)

hook.Add("PreDrawViewModel", "TF2Lightwarp_PreDrawViewModel", function(vm)
	if not IsValid(vm) then return end
	BeginLightwarp(vm:GetPos())
end)

hook.Add("PostDrawViewModel", "TF2Lightwarp_PostDrawViewModel", function()
	EndLightwarp()
end)

hook.Add("PreDrawPlayerHands", "TF2Lightwarp_PreDrawPlayerHands", function(hands)
	if not IsValid(hands) then return end
	BeginLightwarp(hands:GetPos())
end)

hook.Add("PostDrawPlayerHands", "TF2Lightwarp_PostDrawPlayerHands", function()
	EndLightwarp()
end)

hook.Add("PreDrawOpaqueRenderables", "TF2Lightwarp_PreDrawOpaqueRenderables", function(isDepth, isSkybox)
	if isDepth or isSkybox then return end
	BeginLightwarp(EyePos())
end)

hook.Add("PostDrawOpaqueRenderables", "TF2Lightwarp_PostDrawOpaqueRenderables", function(isDepth, isSkybox)
	if isDepth or isSkybox then return end
	EndLightwarp()
end)

hook.Add("PreDrawTranslucentRenderables", "TF2Lightwarp_PreDrawTranslucentRenderables", function(isDepth, isSkybox)
	if isDepth or isSkybox then return end
	BeginLightwarp(EyePos())
end)

hook.Add("PostDrawTranslucentRenderables", "TF2Lightwarp_PostDrawTranslucentRenderables", function(isDepth, isSkybox)
	if isDepth or isSkybox then return end
	EndLightwarp()
end)

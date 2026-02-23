local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local loadout_rect = surface.GetTextureID("vgui/loadout_rect")
local loadout_rect_mouseover = surface.GetTextureID("vgui/loadout_rect_mouseover")
local loadout_dotted_line = surface.GetTextureID("vgui/loadout_dotted_line")

local loadout_round_rect = surface.GetTextureID("vgui/loadout_round_rect")
local loadout_round_rect_selected = surface.GetTextureID("vgui/loadout_round_rect_selected")

local w_machete_large = surface.GetTextureID("backpack/weapons/w_models/w_machete_large")
local w_cigarette_case = surface.GetTextureID("backpack/weapons/w_models/w_cigarette_case_large")
local c_leather_watch = surface.GetTextureID("backpack/weapons/c_models/c_leather_watch/parts/c_leather_watch_large")
local w_knife = surface.GetTextureID("backpack/weapons/w_models/w_knife_large")
local w_revolver = surface.GetTextureID("backpack/weapons/w_models/w_revolver_large")
local all_halo = surface.GetTextureID("backpack/player/items/all_class/all_halo_large")

local item_center_xoffset1 = -310
local item_center_xoffset2 = 165
local attributes_xoffset1 = 140
local attributes_xoffset2 = -168
local attributes_yoffset = 10

--[[
local ATT_TEST = {
{"Level 0 Cigarette Case", 1},
{"+900% health", 3},
{"No weapon when equipped", 4},
{"-66% speed", 4},
}]]

local ATT1 = {
{"Level 1 Revolver", 1},
}

local ATT2 = {
{"Level 5 Invisibility Watch", 1},
{"Cloak Type: Motion Sensitive", 2},
}

local ATT3 = {
{"Level 0 Cigarette Case", 1},
{"It will change your skeleton!", 2},
{"Excrutiatingly painful . . .", 4},
{". . . but worth it", 3},
}

local ATT4 = {
{"Level 42 Shitstorm Generator", 1},
}


function PANEL:Init()
	self:SetPaintBackgroundEnabled(true)
	self:SetVisible(false)
	self:SetParent(CharInfoPanel)
end

local function updateLoadout(type, id, update, class)
    local convar = GetConVar("loadout_" .. class)
    local split = string.Split(convar:GetString(), ",")

    if #split == 6 then
        split[type] = id
    else
        split = {-1, -1, -1, -1, -1, -1}
        split[type] = id
    end

    convar:SetString(table.concat(split, ","))
    if update then
        timer.Simple(0.3, function()
            RunConsoleCommand("loadout_update")
        end)
    end
end

function PANEL:PerformLayout()
	self:SetPos(0, 67*Scale)
	self:SetSize(W, H)
	
	local ply = LocalPlayer()
	local oldclass = "scout"
	if (GetConVar("tf_hud_loadout_class"):GetInt() == 1) then
		oldclass = "scout"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 2) then
		oldclass = "soldier"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 3) then
		oldclass = "pyro"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 4) then
		oldclass = "demoman"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 5) then
		oldclass = "heavy"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 6) then
		oldclass = "engineer"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 7) then
		oldclass = "medic"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 8) then
		oldclass = "sniper"
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 9) then
		oldclass = "spy"
	end
	local convar = GetConVar("loadout_" .. oldclass)
	
	local weapons = {{}, {}, {}, {}}

	for id, item in pairs(tf_items.Items) do
		if istable(item) and item.used_by_classes and item.used_by_classes[oldclass] then
			if GetConVar("tf_hud_loadout_class"):GetInt() != 4 && GetConVar("tf_hud_loadout_class"):GetInt() != 9 then
				if item.item_slot == "primary" then
					weapons[1][id] = item -- table.insert(weapons[1], ) --id) -- weapon1:AddChoice(item.name, item.id)
				elseif item.item_slot == "secondary" then
					weapons[2][id] = item -- weapon2:AddChoice(item.name, item.id)
				elseif item.item_slot == "melee" then
					weapons[3][id] = item -- weapon3:AddChoice(item.name, item.id)
				elseif item.item_slot == "head" or item.item_slot == "misc" then
					weapons[4][id] = item -- weapon3:AddChoice(item.name, item.id)
				end
			else
				if item.item_slot == "primary" then
					weapons[2][id] = item -- table.insert(weapons[1], ) --id) -- weapon1:AddChoice(item.name, item.id)
				elseif item.item_slot == "secondary" then
					weapons[1][id] = item -- weapon2:AddChoice(item.name, item.id)
				elseif item.item_slot == "melee" then
					weapons[3][id] = item -- weapon3:AddChoice(item.name, item.id)
				elseif item.item_slot == "head" or item.item_slot == "misc" then
					weapons[4][id] = item -- weapon3:AddChoice(item.name, item.id)
				end
			end
		end
	end
	
	loadout = string.Split(convar:GetString(), ",")

	-- The attribute panel, which displays the name and attributes of each item
	if not self.AttributePanel then
		local t = vgui.Create("ItemAttributePanel")
		t:SetParent(self)
		t:SetSize(168*Scale,300*Scale)
		t.text_ypos = 20
		
		self.AttributePanel = t
	end
	
		
	local Items = {
		{"NONE", "Normal", surface.GetTextureID(""), ATT4},
		{"NONE", "Normal", surface.GetTextureID(""), ATT4},
		{"NONE", "Normal", surface.GetTextureID(""), ATT4},
		{"NONE", "Normal", surface.GetTextureID(""), ATT4},
		{"NONE", "Normal", surface.GetTextureID(""), ATT4},
		{"NONE", "Normal", surface.GetTextureID(""), ATT4},
	}

	for name, wep in pairs(tf_items.Items) do
		if istable(wep) then	
			if GetConVar("tf_hud_loadout_class"):GetInt() != 4 && GetConVar("tf_hud_loadout_class"):GetInt() != 9 then
				if wep.id == tonumber(loadout[1]) then
					Items[1] = {tf_lang.GetRaw(wep.item_name), "Unique", surface.GetTextureID(wep.image_inventory), {}}
				elseif wep.id == tonumber(loadout[2]) then
					Items[2] = {tf_lang.GetRaw(wep.item_name), "Unique", surface.GetTextureID(wep.image_inventory), {}}
				elseif wep.id == tonumber(loadout[3]) then
					Items[3] = {wep.name, "Unique", surface.GetTextureID(wep.image_inventory), {}}
				elseif wep.id == tonumber(loadout[4]) then
					Items[4] = {wep.name, "Unique", surface.GetTextureID(wep.image_inventory), {}}
				elseif wep.id == tonumber(loadout[5]) then
					Items[5] = {wep.name, "Unique", surface.GetTextureID(wep.image_inventory), {}}
				elseif wep.id == tonumber(loadout[6]) then
					Items[6] = {wep.name, "Unique", surface.GetTextureID(wep.image_inventory), {}}
				end
			else
				if wep.id == tonumber(loadout[1]) then
					Items[2] = {tf_lang.GetRaw(wep.item_name), "Unique", surface.GetTextureID(wep.image_inventory), {}}
				elseif wep.id == tonumber(loadout[2]) then
					Items[1] = {tf_lang.GetRaw(wep.item_name), "Unique", surface.GetTextureID(wep.image_inventory), {}}
				elseif wep.id == tonumber(loadout[3]) then
					Items[3] = {wep.name, "Unique", surface.GetTextureID(wep.image_inventory), {}}
				elseif wep.id == tonumber(loadout[4]) then
					Items[4] = {wep.name, "Unique", surface.GetTextureID(wep.image_inventory), {}}
				elseif wep.id == tonumber(loadout[5]) then
					Items[5] = {wep.name, "Unique", surface.GetTextureID(wep.image_inventory), {}}
				elseif wep.id == tonumber(loadout[6]) then
					Items[6] = {wep.name, "Unique", surface.GetTextureID(wep.image_inventory), {}}
				end
			end
		end
	end
	-- The item panels, with the name and a picture of each item currently equipped
	if not self.ItemPanels then
		self.ItemPanels = {}
		local x, y = W/2+item_center_xoffset1*Scale, 60*Scale
		local xoffset, yoffset = attributes_xoffset1*Scale, attributes_yoffset*Scale
		for k,v in ipairs(Items) do
			local t = vgui.Create("ItemModelPanel")
			t:SetParent(self)
			t:SetPos(x, y)
			t:SetSize(140*Scale, 75*Scale)
			t.model_ypos = 5
			t.model_tall = 55
			t.activeImage = loadout_rect_mouseover
			t.inactiveImage = loadout_rect
			t.itemImage = v[3]
			t.text = v[1]
			t.text_ypos = 60
			t.attributes = v[4]
			t:SetQuality(v[2])
			
			if GetConVar("tf_hud_loadout_class"):GetInt() != 4 && GetConVar("tf_hud_loadout_class"):GetInt() != 9 then
				if (k == 1) then
					t.DoClick = function() itemSelector(1, weapons[1], self:GetParent(), GetConVar("tf_hud_loadout_class"):GetInt(), oldclass) end
				elseif (k == 2) then
					t.DoClick = function() itemSelector(2, weapons[2], self:GetParent(), GetConVar("tf_hud_loadout_class"):GetInt(), oldclass) end
				elseif (k == 3) then
					t.DoClick = function() itemSelector(3, weapons[3], self:GetParent(), GetConVar("tf_hud_loadout_class"):GetInt(), oldclass) end
				elseif (k == 4) then
					t.DoClick = function() hatSelector("hat",4,oldclass,weapons[4]) end
				elseif (k == 5) then
					t.DoClick = function() hatSelector("hat",5,oldclass,weapons[4]) end
				elseif (k == 6) then
					t.DoClick = function() hatSelector("hat",6,oldclass,weapons[4]) end
				end
			else
				if (k == 2) then 
					t.DoClick = function() itemSelector(1, weapons[2], self:GetParent(), GetConVar("tf_hud_loadout_class"):GetInt(), oldclass) end
				elseif (k == 1) then
					t.DoClick = function() itemSelector(2, weapons[1], self:GetParent(), GetConVar("tf_hud_loadout_class"):GetInt(), oldclass) end
				elseif (k == 3) then
					t.DoClick = function() itemSelector(3, weapons[3], self:GetParent(), GetConVar("tf_hud_loadout_class"):GetInt(), oldclass) end
				elseif (k == 4) then
					t.DoClick = function() hatSelector("hat",4,oldclass,weapons[4]) end
				elseif (k == 5) then
					t.DoClick = function() hatSelector("hat",5,oldclass,weapons[4]) end
				elseif (k == 6) then
					t.DoClick = function() hatSelector("hat",6,oldclass,weapons[4]) end
				end
			end
			
			--t:SetAttributePanel(self.AttributePanel, xoffset, yoffset)
			self.ItemPanels[k] = t
			
			if k==3 then
				x = W/2+item_center_xoffset2*Scale
				xoffset = attributes_xoffset2*Scale
				y = 60*Scale
			else
				y = y + 80*Scale
			end
		end
	end
	
	
	-- Move the attribute panel in front of everything
	self.AttributePanel:MoveToFront()
	
	-- And finally, the button to go back to the main loadout menu
	if not self.BackButton then
		self.BackButton = vgui.Create("TFButton")
		self.BackButton:SetParent(self)
		self.BackButton:SetPos(W/2 - 310*Scale,320*Scale) 
		self.BackButton:SetSize(100*Scale,25*Scale)
		self.BackButton.labelText = "<< BACK"
		self.BackButton.font = "HudFontSmallBold"
		function self.BackButton:DoClick()
			CharInfoLoadoutSubPanel:SelectClassLoadout(0)
		end
	end
	local t
	-- The class panel, shows the current class selected holding the last weapon equipped
	if not self.ClassPanel then
		t = vgui.Create("ClassModelPanel")
		t:SetParent(self)
		t:SetPos(W/2-100*Scale, 20*Scale)
		t:SetSize(200*Scale, 340*Scale)
		t.FOV = 50
		t.spotlight = true
		self.ClassPanel = t
		
			
		-- oh no
		--print(":O")
		if ply:GetPlayerClass() != "demoman" then

			--[[
			for name, wep in pairs(tf_items.Items) do
				if istable(wep) then
					if wep.id == tonumber(loadout[1]) then
						weapon1.text = name
						if wep.image_inventory then
							weapon1.icon = surface.GetTextureID(wep.image_inventory)
						end
					elseif wep.id == tonumber(loadout[2]) then
						weapon2.text = name
						if wep.image_inventory then
							weapon2.icon = surface.GetTextureID(wep.image_inventory)
						end
					elseif wep.id == tonumber(loadout[3]) then
						weapon3.text = name
						if wep.image_inventory then
							weapon3.icon = surface.GetTextureID(wep.image_inventory)
						end
					end
				end
			end]]
		else
			--[[
			for name, wep in pairs(tf_items.Items) do
				if istable(wep) then
					if wep.id == tonumber(loadout[2]) then
						weapon1.text = name
						if wep.image_inventory then
							weapon1.icon = surface.GetTextureID(wep.image_inventory)
						end
					elseif wep.id == tonumber(loadout[1]) then
						weapon2.text = name
						if wep.image_inventory then
							weapon2.icon = surface.GetTextureID(wep.image_inventory)
						end
					elseif wep.id == tonumber(loadout[3]) then
						weapon3.text = name
						if wep.image_inventory then
							weapon3.icon = surface.GetTextureID(wep.image_inventory)
						end
					end
				end
			end
			]]
		end

		if (GetConVar("tf_hud_loadout_class"):GetInt() == 1) then
			t:AddModel(1,"models/player/scout.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 2) then
			t:AddModel(1,"models/player/soldier.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 3) then
			t:AddModel(1,"models/player/pyro.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 4) then
			t:AddModel(1,"models/player/demo.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 5) then
			t:AddModel(1,"models/player/heavy.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 6) then
			t:AddModel(1,"models/player/engineer.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 7) then
			t:AddModel(1,"models/player/medic.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 8) then
			t:AddModel(1,"models/player/sniper.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 9) then
			t:AddModel(1,"models/player/spy.mdl",{
				Pos = Vector(190, 0, -36),
				Ang = Angle(0, 200, 0),
			})
		end

		local function getWearablePreviewModel(item, className)
			if not istable(item) then return nil end

			local perClass = item.model_player_per_class
			if istable(perClass) then
				local resolved = perClass[className] or perClass[(className == "demoman" and "demo" or className)] or perClass.basename
				if isstring(resolved) and resolved ~= "" then
					resolved = string.Replace(resolved, "%s", className)
					if className == "demoman" and not file.Exists(resolved, "GAME") then
						local demoResolved = string.Replace(resolved, "demoman", "demo")
						if file.Exists(demoResolved, "GAME") then
							resolved = demoResolved
						end
					end
					return resolved
				end
			elseif isstring(perClass) and perClass ~= "" then
				local resolved = string.Replace(perClass, "%s", className)
				if className == "demoman" and not file.Exists(resolved, "GAME") then
					local demoResolved = string.Replace(perClass, "%s", "demo")
					if file.Exists(demoResolved, "GAME") then
						resolved = demoResolved
					end
				end
				return resolved
			end
			if isstring(item.model_player) and item.model_player ~= "" then
				return item.model_player
			end
			if isstring(item.model_world) and item.model_world ~= "" then
				return item.model_world
			end
			return nil
		end

		for name, wep in pairs(tf_items.Items) do
			if istable(wep) then
				if wep.id == tonumber(loadout[4]) then
					local wearableModel = getWearablePreviewModel(wep, oldclass)
					if isstring(wearableModel) then

						t:AddModel(3, wearableModel, {
							Parent = 1,
						})
					end

				elseif wep.id == tonumber(loadout[5]) then
					local wearableModel = getWearablePreviewModel(wep, oldclass)
					if isstring(wearableModel) then

						t:AddModel(4, wearableModel, {
							Parent = 1,
						})
					end

				elseif wep.id == tonumber(loadout[6]) then
					local wearableModel = getWearablePreviewModel(wep, oldclass)
					if isstring(wearableModel) then

						t:AddModel(5, wearableModel, {
							Parent = 1,
						})
					end

				end
				local oldclass2 = oldclass
				if (oldclass == "spy" or oldclass == "demoman") then
					if wep.id == tonumber(loadout[2]) then

						t:AddModel(2,wep.model_world or wep.model_player,{
							Parent = 1,
						})
						t:StartAnimation(1,ACT_MP_STAND_SECONDARY)
					end
				else
					if wep.id == tonumber(loadout[1]) then

						t:AddModel(2,wep.model_world or wep.model_player,{
							Parent = 1,
						})
						if (oldclass == "spy") then
							t:StartAnimation(1,ACT_MP_STAND_BUILDING)
						else
							t:StartAnimation(1,ACT_MP_STAND_PRIMARY)
						end
					end
				end
			end
		end
	end
end



function PANEL:Paint()
	-- Header lines
	
	surface.SetDrawColor(255,255,255,255)	
	tf_draw.TexturedQuadTiled(loadout_dotted_line, W/2-305*Scale, 40*Scale, 610*Scale, 10*Scale, {y=false})
	
	-- Labels
	tf_draw.LabelText(
		W/2-300*Scale,
		20*Scale,
		20*Scale,
		15*Scale,
		">>",
		Color(200, 80, 60, 255),
		"HudFontSmallestBold",
		"west"
	)
	if (GetConVar("tf_hud_loadout_class"):GetInt() == 1) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"SCOUT",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 2) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"SOLDIER",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 3) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"PYRO",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 4) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"DEMOMAN",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 5) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"HEAVY",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 6) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"ENGINEER",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 7) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"MEDIC",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 8) then
		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"SNIPER",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	elseif (GetConVar("tf_hud_loadout_class"):GetInt() == 9) then

		tf_draw.LabelText(
			W/2-280*Scale,
			15*Scale,
			240*Scale,
			25*Scale,
			"SPY",
			"TanLight",
			"HudFontMediumBold",
			"west"
		)
	end
	
	tf_draw.LabelText(
		W/2-55*Scale,
		22*Scale,
		180*Scale,
		15*Scale,
		"CURRENTLY EQUIPPED:",
		"TanLight",
		"HudFontSmallestBold",
		"south-west"
	)
end
local OLDPANEL = PANEL
local PANEL = {}

local W = ScrW()
local H = ScrH()
local WScale = W/640
local Scale = H/480

local class_sel_sm = {}
local classes = {"scout", "soldier", "pyro", "demo", "heavy", "engineer", "medic", "sniper", "spy"}
local classnames = {"SCOUT", "SOLDIER", "PYRO", "DEMOMAN", "HEAVY", "ENGINEER", "MEDIC", "SNIPER", "SPY"}

local class_ypos = 40
local class_xdelta = 5
local class_wide_min = 60
local class_wide_max = 100
local class_tall_min = 120
local class_tall_max = 200
local class_distance_min = 7
local class_distance_max = 100

local class_size_speed = 10

for k,v in ipairs(classes) do
	class_sel_sm[k] = {
		surface.GetTextureID("vgui/class_sel_sm_"..v.."_red"),
		surface.GetTextureID("vgui/class_sel_sm_"..v.."_inactive")
	}
end

local backpack_01 = surface.GetTextureID("hud/backpack_01")
local backpack_01_grey = surface.GetTextureID("hud/backpack_01_grey")

function PANEL:SelectClassLoadout(c)
	if c>=1 and c<=10 then
		FullLoadoutPanel:SetVisible(true)
		self:ResetButtons()
		self:SetVisible(false)
	else
		FullLoadoutPanel:SetVisible(false)
		self:SetVisible(true)
	end
end

function PANEL:SelectClassLoadout2(c) 
	if c>=1 and c<=10 then
		if FullLoadoutPanel then FullLoadoutPanel:Remove() end
		FullLoadoutPanel = vgui.CreateFromTable(vgui.RegisterTable(OLDPANEL, "DPanel"))
		FullLoadoutPanel:SetVisible(true)
		self:ResetButtons()
		self:SetVisible(false)
	else
		FullLoadoutPanel:SetVisible(false)
		self:SetVisible(true)
	end
end

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:SetVisible(true)
	self:SetParent(CharInfoPanel)
	
	-- Class loadout buttons
	self.ClassButtons = {}
	local x = (W/2)/Scale - (4.5 * class_wide_min + 4 * class_xdelta)
	for k,_ in ipairs(classes) do
		local t = vgui.Create("TFButton")
		t:SetParent(self)
		t:SetPos(x*Scale, (28+class_ypos)*Scale)
		t:SetSize(class_wide_min*Scale,class_tall_min*Scale)
		t.activeImage = class_sel_sm[k][1]
		t.inactiveImage = class_sel_sm[k][2]
		
		t.xcenter = Scale * (x+class_wide_min/2)
		t.ycenter = Scale * (28+class_ypos+class_tall_min/2)
		
		function t:DoClick()
			RunConsoleCommand("tf_hud_loadout_class",""..k)
			timer.Simple(0.1, function()
			
				if FullLoadoutPanel then FullLoadoutPanel:Remove() end
				FullLoadoutPanel = vgui.CreateFromTable(vgui.RegisterTable(OLDPANEL, "DPanel"))
				self:GetParent():SelectClassLoadout(k)
				self:GetParent().char_model = "models/player/medic.mdl"
				
			end)
		end
		
		self.ClassButtons[k] = t
		
		x = x + class_wide_min + class_xdelta
	end
	
	-- Backpack
	local t = vgui.Create("TFButton")
	t:SetParent(self)
	t:SetPos(W/2-60*Scale, 254*Scale)
	t:SetSize(60*Scale,60*Scale)
	t.activeImage = surface.GetTextureID("overlays/no_entry")
	t.inactiveImage = surface.GetTextureID("overlays/no_entry")
	
	function t:DoClick()

		local conflict_help_frame = vgui.Create( "DFrame" )
		conflict_help_frame:SetSize(200, 200)
		conflict_help_frame:Center()
		conflict_help_frame:SetTitle("Oh no!")
		conflict_help_frame:ShowCloseButton(true)
		conflict_help_frame:SetBackgroundBlur(true)
		conflict_help_frame:MakePopup()

		local conflicttext = vgui.Create("RichText", conflict_help_frame)
		conflicttext:Dock(FILL)
		conflicttext:InsertColorChange(255, 255, 255, 255)
		conflicttext:CenterHorizontal(0.5)
		conflicttext:SetVerticalScrollbarEnabled(false)
		conflicttext:AppendText("Are you sure? This action is irreversible and all of your items in this gamemode will be reset to default!")
			local conflictbut2 = vgui.Create("DButton", conflict_help_frame)
			conflictbut2:SetSize(100, 30)
			conflictbut2:SetPos(0, 125)
			conflictbut2:CenterHorizontal(0.5)
			conflictbut2:SetText("I'm 100% sure.") 

			function conflictbut2.DoClick()
				conflict_help_frame:Close()
				RunConsoleCommand("loadout_scout","-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_soldier","-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_pyro","-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_demoman","-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_heavy","-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_engineer","-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_medic","-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_sniper","-1,-1,-1,-1,-1,-1")
				RunConsoleCommand("loadout_spy","-1,-1,-1,-1,-1,-1")
			end
	end
	
	local t = vgui.Create("TFButton")
	t:SetParent(self)
	t:SetPos(W/2+30*Scale, 254*Scale)
	t:SetSize(60*Scale,60*Scale)
	t.activeImage = backpack_01
	t.inactiveImage = backpack_01_grey
	
	function t:DoClick()
		local classMap = {
			[1] = "scout",
			[2] = "soldier",
			[3] = "pyro",
			[4] = "demoman",
			[5] = "heavy",
			[6] = "engineer",
			[7] = "medic",
			[8] = "sniper",
			[9] = "spy",
		}
		local classIndex = GetConVar("tf_hud_loadout_class"):GetInt()
		local className = classMap[classIndex] or "scout"
		if isfunction(TF_OpenStandaloneBackpack) then
			TF_OpenStandaloneBackpack(className, classIndex)
		end
	end
end

function PANEL:ResetButtons()
	local w, h = Scale*class_wide_min, Scale*class_tall_min
	for k,v in ipairs(self.ClassButtons) do
		v:SetPos(v.xcenter-w/2, v.ycenter-h/2)
		v:SetSize(w, h)
	end
end

function PANEL:PerformLayout()
	self:SetPos(0, 40*Scale)
	self:SetSize(W, H)
	
	if not self.ClassButtons then return end
	
	local active = false
	for _,v in ipairs(self.ClassButtons) do
		if v.Hover then
			active = true
			break
		end
	end
	
	if active then
		local x, y = self:CursorPos()
		for k,v in ipairs(self.ClassButtons) do
			local dist = math.Clamp(math.abs(v.xcenter - x) / Scale, class_distance_min, class_distance_max)
			local r = 1 - (dist - class_distance_min) / (class_distance_max - class_distance_min)
			
			local w, h = Scale*Lerp(r, class_wide_min, class_wide_max), Scale*Lerp(r, class_tall_min, class_tall_max)
			v.TargetSize = Vector(w, h, 0)
		end
	else
		for k,v in ipairs(self.ClassButtons) do
			local w, h = Scale*class_wide_min, Scale*class_tall_min
			v.TargetSize = Vector(w, h, 0)
		end
	end
	
	for k,v in ipairs(self.ClassButtons) do
		if v.TargetSize then
			local w0, h0 = v:GetSize()
			local dw, dh = (v.TargetSize.x - w0) * RealFrameTime() * class_size_speed, (v.TargetSize.y - h0) * RealFrameTime() * class_size_speed
			local w, h = w0 + dw, h0 + dh
			
			v:SetPos(v.xcenter-w/2, v.ycenter-h/2)
			v:SetSize(w, h)
		end
	end
end

function PANEL:Think()
	self:InvalidateLayout()
end

function PANEL:Paint()
	draw.Text{
		text="SELECT A CLASS TO MODIFY LOADOUT",
		font="HudFontSmallBold",
		pos={W/2, 330*Scale},
		color=Color(117, 107, 94, 255),
		xalign=TEXT_ALIGN_CENTER,
		yalign=TEXT_ALIGN_TOP,
	}
	
	draw.Text{
		text="CLICK THE NO ENTRY ICON TO RESET YOUR LOADOUT",
		font="HudFontSmallBold",
		pos={W/2, 360*Scale},
		color=Color(117, 107, 94, 255),
		xalign=TEXT_ALIGN_CENTER,
		yalign=TEXT_ALIGN_TOP,
	}
	for k,v in ipairs(self.ClassButtons) do
		if v.Hover then
			draw.Text{
				text=classnames[k],
				font="HudFontSmallBold",
				pos={v.xcenter, 226*Scale},
				color=Color(235, 226, 202, 255),
				xalign=TEXT_ALIGN_CENTER,
				yalign=TEXT_ALIGN_TOP,
			}
			
			draw.Text{
				text="(∞ ITEMS IN INVENTORY)",
				font="HudFontSmall",
				pos={v.xcenter, 242*Scale},
				color=Color(200, 80, 60, 255),
				xalign=TEXT_ALIGN_CENTER,
				yalign=TEXT_ALIGN_TOP,
			}
		end
	end
end

if CharInfoLoadoutSubPanel then CharInfoLoadoutSubPanel:Remove() end
CharInfoLoadoutSubPanel = vgui.CreateFromTable(vgui.RegisterTable(PANEL, "DPanel"))


local BackpackPickerPanel

local function classCanUseItem(item, className)
	if not istable(item) or not isstring(className) then return false end
	if not istable(item.used_by_classes) then return false end
	return item.used_by_classes[className] == true or item.used_by_classes[className] == 1
end

local function createBackpackPicker(title, oldclass, canEquipFn, onEquipFn)
	if IsValid(BackpackPickerPanel) then
		BackpackPickerPanel:Remove()
	end

	local loadout_rect = surface.GetTextureID("vgui/loadout_rect")
	local loadout_rect_mouseover = surface.GetTextureID("vgui/loadout_rect_mouseover")

	local parent = IsValid(CharInfoPanel) and CharInfoPanel or nil
	local panel = vgui.Create("EditablePanel", parent)
	panel:SetSize(ScrW() - 100 * Scale, ScrH() - 110 * Scale)
	panel:Center()
	panel:MakePopup()
	panel:SetKeyboardInputEnabled(true)
	panel:SetMouseInputEnabled(true)
	panel:SetZPos(9999)
	BackpackPickerPanel = panel

	function panel:Paint(w, h)
		surface.SetDrawColor(18, 17, 16, 245)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(90, 83, 72, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 2)

		draw.Text{
			text = title or "BACKPACK",
			font = "HudFontMediumBold",
			pos = {20, 18},
			color = Color(235, 226, 202, 255),
			xalign = TEXT_ALIGN_LEFT,
			yalign = TEXT_ALIGN_TOP,
		}

		draw.Text{
			text = "All items are shown. Unusable items are dimmed.",
			font = "HudFontSmall",
			pos = {20, 48},
			color = Color(170, 160, 146, 255),
			xalign = TEXT_ALIGN_LEFT,
			yalign = TEXT_ALIGN_TOP,
		}
	end

	local closeBtn = vgui.Create("TFButton", panel)
	closeBtn:SetSize(100 * Scale, 25 * Scale)
	closeBtn:SetPos(panel:GetWide() - 120 * Scale, 15 * Scale)
	closeBtn.labelText = "CLOSE"
	closeBtn.font = "HudFontSmallBold"
	function closeBtn:DoClick()
		if IsValid(panel) then panel:Remove() end
	end

	local scroll = vgui.Create("DScrollPanel", panel)
	scroll:SetPos(18 * Scale, 78 * Scale)
	scroll:SetSize(panel:GetWide() - 36 * Scale, panel:GetTall() - 96 * Scale)

	local itemicons = vgui.Create("DIconLayout", scroll)
	itemicons:Dock(FILL)
	itemicons:SetSpaceX(6)
	itemicons:SetSpaceY(6)

	local allItems = {}
	for _, item in pairs(tf_items.Items or {}) do
		if istable(item) and isnumber(item.id) and isstring(item.item_slot) then
			allItems[#allItems + 1] = item
		end
	end
	table.sort(allItems, function(a, b) return (a.id or 0) < (b.id or 0) end)

	for _, item in ipairs(allItems) do
		local model = vgui.Create("ItemModelPanel", itemicons)
		model:SetSize(140 * Scale, 75 * Scale)
		itemicons:Add(model)

		model.activeImage = loadout_rect_mouseover
		model.inactiveImage = loadout_rect
		model.model_xpos = 0
		model.model_ypos = 5
		model.model_tall = 55
		model.text_xpos = -5
		model.text_wide = 150
		model.text_ypos = 60
		model.itemImage_low = nil
		model.text = tf_lang.GetRaw(item.item_name) or item.name or "UNKNOWN ITEM"
		model.centerytext = true

		local quality = 0
		if item.item_quality then
			quality = string.upper(string.sub(item.item_quality, 1, 1)) .. string.sub(item.item_quality, 2)
		end
		model:SetQuality(quality)

		local invMat
		if isstring(item.image_inventory) and item.image_inventory ~= "" then
			invMat = Material(item.image_inventory)
		end
		if (not invMat) or invMat:IsError() then
			model.FallbackModel = item.model_player
			model.itemImage = surface.GetTextureID("backpack/weapons/c_models/c_bat")
		else
			model.itemImage = surface.GetTextureID(item.image_inventory)
		end

		if item.attributes and item.attributes["material override"] and item.attributes["material override"].value then
			model.overridematerial = item.attributes["material override"].value
		end

		if istable(item.attributes) then
			model.attributes = item.attributes
		end

		local canEquip = classCanUseItem(item, oldclass) and canEquipFn(item)
		model.disabled = not canEquip
		if not canEquip then
			model:SetAlpha(95)
		end

		model.DoClick = function()
			if not canEquip then return end
			onEquipFn(item)
			if IsValid(panel) then panel:Remove() end
		end
	end
end

local function getTargetWeaponSlot(type, className)
	local swapped = className == "demoman" or className == "spy"
	if type == 1 then
		return swapped and "secondary" or "primary"
	elseif type == 2 then
		return swapped and "primary" or "secondary"
	elseif type == 3 then
		return "melee"
	end
	return nil
end

local function mapItemToLoadoutSlot(item, className)
	if not istable(item) then return nil end

	if item.item_class == "tf_wearable_item" then
		return 4
	end

	if item.item_slot == "melee" then
		return 3
	end

	local swapped = className == "demoman" or className == "spy"
	if item.item_slot == "primary" then
		return swapped and 2 or 1
	elseif item.item_slot == "secondary" then
		return swapped and 1 or 2
	end

	return nil
end

function TF_OpenClassBackpack(className, classIndex)
	local cls = className or "scout"
	local classId = classIndex or GetConVar("tf_hud_loadout_class"):GetInt()
	TF_OpenStandaloneBackpack(cls, classId)
end

local TFStandaloneBackpackPanel

local classIndexToName = {
	[1] = "scout",
	[2] = "soldier",
	[3] = "pyro",
	[4] = "demoman",
	[5] = "heavy",
	[6] = "engineer",
	[7] = "medic",
	[8] = "sniper",
	[9] = "spy",
}

local function getSteamInventorySet()
	local raw = file.Read("tf_loadout.json", "DATA")
	if not isstring(raw) or raw == "" then return nil, "missing_file" end
	raw = string.gsub(raw, "^\239\187\191", "")
	raw = string.Trim(raw)

	local parsed = util.JSONToTable(raw)
	if not istable(parsed) then
		local wrapped = string.match(raw, "(%b{})")
		if isstring(wrapped) and wrapped ~= "" then
			parsed = util.JSONToTable(wrapped)
		end
	end
	if not istable(parsed) then
		return nil, "invalid_json"
	end

	local container = parsed.result
	if not istable(container) then
		container = parsed.response
	end
	if not istable(container) then
		container = parsed
	end

	local items = container and container.items
	if not istable(items) then
		return nil, "missing_items", tonumber(container and container.status)
	end

	local set = {}
	for _, invItem in pairs(items) do
		if istable(invItem) then
			local defindex = tonumber(invItem.defindex or invItem.itemdefid or invItem.item_def_index)
			if defindex then
				set[defindex] = true
			end
		end
	end

	return set, nil, tonumber(container and container.status)
end

local function getWearableTargetSlot(className, itemId)
	local convar = GetConVar("loadout_" .. className)
	if not convar then return 4 end

	local split = string.Split(convar:GetString(), ",")
	for i = 4, 6 do
		if tonumber(split[i]) == itemId then
			return i
		end
	end
	for i = 4, 6 do
		if tonumber(split[i]) == -1 then
			return i
		end
	end
	return 4
end

CreateClientConVar("tf_backpack_page_size", "50", true, false, "Backpack items per page (TF2-Gamemode)")
CreateClientConVar("tf_backpack_dedupe", "1", true, false, "Collapse duplicate backpack entries by defindex (TF2-Gamemode)")

function TF_OpenStandaloneBackpack(initialClassName, initialClassIndex, forcedLoadoutSlot)
	if IsValid(TFStandaloneBackpackPanel) then
		TFStandaloneBackpackPanel:Remove()
	end

	local Scale = ScrH() / 480
	local loadout_rect = surface.GetTextureID("vgui/loadout_rect")
	local loadout_rect_mouseover = surface.GetTextureID("vgui/loadout_rect_mouseover")
	local activeClass = initialClassName or classIndexToName[initialClassIndex or 1] or "scout"
	local steamSet
	local steamErr
	local steamStatus
	local currentPage = 1
	local pageSizeConVar = GetConVar("tf_backpack_page_size")
	local dedupeConVar = GetConVar("tf_backpack_dedupe")
	local pageSize = math.Clamp((pageSizeConVar and pageSizeConVar:GetInt()) or 50, 10, 50)
	local dedupeEnabled = (not dedupeConVar) or dedupeConVar:GetBool()
	local columns = 10
	local rows = 5

	local panel = vgui.Create("EditablePanel")
	panel:SetSize(ScrW(), ScrH())
	panel:SetPos(0, 0)
	panel:MakePopup()
	panel:SetKeyboardInputEnabled(true)
	panel:SetMouseInputEnabled(true)
	panel.ForcedLoadoutSlot = tonumber(forcedLoadoutSlot)
	TFStandaloneBackpackPanel = panel

	function panel:OnKeyCodePressed(key)
		if key == KEY_ESCAPE and IsValid(self) then
			self:Remove()
		end
	end

	function panel:Paint(w, h)
		surface.SetDrawColor(24, 21, 20, 248)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(44, 38, 34, 255)
		surface.DrawRect(0, 0, w, 98)
		surface.DrawRect(0, h - 72, w, 72)
		surface.SetDrawColor(112, 100, 86, 255)
		surface.DrawRect(0, 96, w, 2)
		surface.DrawRect(0, h - 74, w, 2)
	end

	local titleLoadout = vgui.Create("DLabel", panel)
	titleLoadout:SetPos(32, 18)
	titleLoadout:SetSize(230, 28)
	titleLoadout:SetFont("HudFontMediumBold")
	titleLoadout:SetTextColor(Color(235, 226, 202, 255))
	titleLoadout:SetText("LOADOUT")

	local titleBackpack = vgui.Create("DLabel", panel)
	titleBackpack:SetPos(208, 18)
	titleBackpack:SetSize(260, 28)
	titleBackpack:SetFont("HudFontMediumBold")
	titleBackpack:SetTextColor(Color(170, 160, 146, 255))
	titleBackpack:SetText("BACKPACK")

	local searchLabel = vgui.Create("DLabel", panel)
	searchLabel:SetPos(panel:GetWide() - 410, 56)
	searchLabel:SetSize(72, 22)
	searchLabel:SetText("SEARCH:")
	searchLabel:SetTextColor(Color(205, 193, 167, 255))
	searchLabel:SetFont("HudFontSmallBold")

	local searchEntry = vgui.Create("DTextEntry", panel)
	searchEntry:SetPos(panel:GetWide() - 326, 54)
	searchEntry:SetSize(296, 26)
	searchEntry:SetFont("HudFontSmall")
	searchEntry:SetUpdateOnType(true)

	local infoLabel = vgui.Create("DLabel", panel)
	infoLabel:SetPos(30, 58)
	infoLabel:SetSize(panel:GetWide() - 60, 22)
	infoLabel:SetTextColor(Color(190, 178, 155, 255))
	infoLabel:SetFont("HudFontSmall")

	local gridPanel = vgui.Create("EditablePanel", panel)
	gridPanel:SetPos(30, 86)
	gridPanel:SetSize(panel:GetWide() - 60, panel:GetTall() - 172)
	function gridPanel:Paint(w, h)
		surface.SetDrawColor(29, 25, 22, 255)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(110, 98, 84, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	local itemicons = vgui.Create("DIconLayout", gridPanel)
	itemicons:Dock(FILL)
	itemicons:SetBorder(10)
	itemicons:SetSpaceX(6)
	itemicons:SetSpaceY(6)

	local pageBar = vgui.Create("DIconLayout", panel)
	pageBar:SetPos(164, panel:GetTall() - 38)
	pageBar:SetSize(panel:GetWide() - 328, 26)
	pageBar:SetSpaceX(6)
	pageBar:SetSpaceY(0)

	local backBtn = vgui.Create("TFButton", panel)
	backBtn:SetSize(120, 30)
	backBtn:SetPos(30, panel:GetTall() - 40)
	backBtn.labelText = "BACK"
	backBtn.font = "HudFontSmallBold"
	function backBtn:DoClick()
		if IsValid(panel) then panel:Remove() end
	end

	local closeBtn = vgui.Create("TFButton", panel)
	closeBtn:SetSize(120, 30)
	closeBtn:SetPos(panel:GetWide() - 150, panel:GetTall() - 40)
	closeBtn.labelText = "CLOSE"
	closeBtn.font = "HudFontSmallBold"
	function closeBtn:DoClick()
		if IsValid(panel) then panel:Remove() end
	end

	local matValidity = {}
	local function hasValidInventoryImage(item)
		if not istable(item) or not isstring(item.image_inventory) or item.image_inventory == "" then
			return false
		end
		if matValidity[item.image_inventory] ~= nil then
			return matValidity[item.image_inventory]
		end
		local mat = Material(item.image_inventory)
		local ok = mat ~= nil and (not mat:IsError())
		matValidity[item.image_inventory] = ok
		return ok
	end

	local function getItemDisplayName(item)
		return tf_lang.GetRaw(item.item_name) or item.name or "UNKNOWN ITEM"
	end

	local function getInspectModelPath(item, className)
		if not istable(item) then return nil end

		local perClass = item.model_player_per_class
		if istable(perClass) then
			local resolved = perClass[className] or perClass[(className == "demoman" and "demo" or className)] or perClass.basename
			if isstring(resolved) and resolved ~= "" then
				resolved = string.Replace(resolved, "%s", className)
				if className == "demoman" and not file.Exists(resolved, "GAME") then
					local demoResolved = string.Replace(resolved, "demoman", "demo")
					if file.Exists(demoResolved, "GAME") then
						resolved = demoResolved
					end
				end
				return resolved
			end
		elseif isstring(perClass) and perClass ~= "" then
			local resolved = string.Replace(perClass, "%s", className)
			if className == "demoman" and not file.Exists(resolved, "GAME") then
				local demoResolved = string.Replace(perClass, "%s", "demo")
				if file.Exists(demoResolved, "GAME") then
					resolved = demoResolved
				end
			end
			return resolved
		end

		if isstring(item.model_player) and item.model_player ~= "" then
			return string.Replace(item.model_player, "%s", className)
		end
		if isstring(item.model_world) and item.model_world ~= "" then
			return item.model_world
		end

		return nil
	end

	local function openBackpackInspect(item, className)
		local mdl = getInspectModelPath(item, className)
		if not isstring(mdl) or mdl == "" or not util.IsValidModel(mdl) then
			chat.AddText(Color(220, 120, 80), "[TF2-Gamemode] Inspect preview unavailable for this item.")
			return
		end

		local frame = vgui.Create("DFrame")
		frame:SetSize(math.floor(ScrW() * 0.46), math.floor(ScrH() * 0.62))
		frame:Center()
		frame:SetTitle("Inspect: " .. getItemDisplayName(item))
		frame:ShowCloseButton(true)
		frame:SetDraggable(true)
		frame:MakePopup()

		local modelPanel = vgui.Create("DModelPanel", frame)
		modelPanel:Dock(FILL)
		modelPanel:SetModel(mdl)
		modelPanel:SetFOV(42)
		modelPanel:SetCamPos(Vector(82, 18, 44))
		modelPanel:SetLookAt(Vector(0, 0, 40))
		modelPanel.LayoutEntity = function(self, ent)
			if IsValid(ent) then
				ent:SetAngles(Angle(0, RealTime() * 18 % 360, 0))
			end
		end
	end

	local slotOrder = {
		primary = 1,
		secondary = 2,
		melee = 3,
		head = 4,
		misc = 4,
	}

	searchEntry.OnValueChange = function()
		currentPage = 1
		panel:BuildItems()
	end

	if TFDebugBridge and TFDebugBridge.Emit then
		TFDebugBridge.Emit("backpack_open", {
			class = activeClass,
			slot = panel.ForcedLoadoutSlot,
			page = currentPage,
			query = searchEntry:GetValue() or "",
		}, false)
	end

	function panel:BuildItems()
		steamSet, steamErr, steamStatus = getSteamInventorySet()

		for _, child in ipairs(itemicons:GetChildren()) do
			child:Remove()
		end
		for _, child in ipairs(pageBar:GetChildren()) do
			child:Remove()
		end

		local rawCandidates = {}
		for _, item in pairs(tf_items.Items or {}) do
			local defindex = istable(item) and tonumber(item.id) or nil
			if istable(item) and defindex and isstring(item.item_slot) then
				if item.item_slot == "primary" or item.item_slot == "secondary" or item.item_slot == "melee" or item.item_slot == "head" or item.item_slot == "misc" then
					if steamSet and steamSet[defindex] then
						rawCandidates[#rawCandidates + 1] = item
					end
				end
			end
		end

		if not steamSet then
			local detail = ""
			if steamErr == "missing_file" then
				detail = "No Steam inventory cache found. Run 'tf_merge_loadout' first."
			elseif steamErr == "invalid_json" then
				detail = "Steam inventory cache is invalid JSON. Run 'tf_merge_loadout' again. Raw response is in data/tf_loadout_last_response.txt."
			elseif steamErr == "missing_items" then
				if steamStatus then
					detail = "Steam inventory response had no item list (status " .. tostring(steamStatus) .. "). Check privacy/API response, then run 'tf_merge_loadout' again."
				else
					detail = "Steam inventory response had no item list. Run 'tf_merge_loadout' again."
				end
			else
				detail = "Steam inventory unavailable. Run 'tf_merge_loadout' first."
			end
			infoLabel:SetText(detail)
			if TFDebugBridge and TFDebugBridge.SetBackpackState then
				local snapshot = {
					event = "backpack_state_error",
					class = activeClass,
					slot = panel.ForcedLoadoutSlot,
					page = currentPage,
					query = searchEntry:GetValue() or "",
					error = steamErr or "unknown",
					status = steamStatus,
					owned_count = 0,
					dedup_count = 0,
					visible_count = 0,
				}
				TFDebugBridge.SetBackpackState(snapshot)
				if TFDebugBridge.Emit then
					TFDebugBridge.Emit("backpack_rebuild", snapshot, false)
				end
			end
			return
		end

		local sourceItems = rawCandidates
		local ownedCount = #rawCandidates
		if dedupeEnabled then
			local dedupById = {}
			local dedupByFallback = {}
			for _, item in ipairs(rawCandidates) do
				local id = tonumber(item.id)
				local key
				if id then
					key = "id:" .. tostring(id)
				else
					local nameKey = string.lower(getItemDisplayName(item))
					key = "fallback:" .. nameKey .. "|" .. tostring(item.image_inventory or "")
				end

				local existing = dedupById[key] or dedupByFallback[key]
				if not existing then
					if id then dedupById[key] = item else dedupByFallback[key] = item end
				else
					local scoreA = 0
					local scoreB = 0
					if hasValidInventoryImage(item) then scoreA = scoreA + 2 end
					if hasValidInventoryImage(existing) then scoreB = scoreB + 2 end
					if tf_lang.GetRaw(item.item_name) then scoreA = scoreA + 1 end
					if tf_lang.GetRaw(existing.item_name) then scoreB = scoreB + 1 end
					if scoreA > scoreB then
						if id then dedupById[key] = item else dedupByFallback[key] = item end
					end
				end
			end

			sourceItems = {}
			for _, item in pairs(dedupById) do sourceItems[#sourceItems + 1] = item end
			for _, item in pairs(dedupByFallback) do sourceItems[#sourceItems + 1] = item end
		end
		local dedupCount = #sourceItems

		table.sort(sourceItems, function(a, b)
			local sa = slotOrder[a.item_slot] or 99
			local sb = slotOrder[b.item_slot] or 99
			if sa ~= sb then return sa < sb end

			local na = string.lower(getItemDisplayName(a))
			local nb = string.lower(getItemDisplayName(b))
			if na ~= nb then return na < nb end

			return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
		end)

		local query = string.Trim(string.lower(searchEntry:GetValue() or ""))
		if query ~= "" then
			local filtered = {}
			for _, item in ipairs(sourceItems) do
				local name = string.lower(getItemDisplayName(item))
				local rawName = string.lower(item.name or "")
				if string.find(name, query, 1, true) or string.find(rawName, query, 1, true) then
					filtered[#filtered + 1] = item
				end
			end
			sourceItems = filtered
		end

		local forcedSlot = panel.ForcedLoadoutSlot
		local slotText = ""
		if forcedSlot then
			slotText = "  |  Slot: " .. tostring(forcedSlot)
		end
		if forcedSlot then
			local slotFiltered = {}
			for _, item in ipairs(sourceItems) do
				local slotCompatible = true
				if forcedSlot >= 4 then
					slotCompatible = item.item_class == "tf_wearable_item" and (item.item_slot == "head" or item.item_slot == "misc")
				else
					slotCompatible = mapItemToLoadoutSlot(item, activeClass) == forcedSlot
				end
				if slotCompatible then
					slotFiltered[#slotFiltered + 1] = item
				end
			end
			sourceItems = slotFiltered
		end

		local visibleCount = #sourceItems
		local totalPages = math.max(1, math.ceil(visibleCount / pageSize))
		currentPage = math.Clamp(currentPage, 1, totalPages)

		infoLabel:SetText("Owned: " .. tostring(visibleCount) .. "  |  Class: " .. string.upper(activeClass) .. slotText .. "  |  Page " .. tostring(currentPage) .. "/" .. tostring(totalPages) .. "  |  Incompatible items are disabled")

		if TFDebugBridge and TFDebugBridge.SetBackpackState then
			local snapshot = {
				event = "backpack_state",
				class = activeClass,
				slot = panel.ForcedLoadoutSlot,
				page = currentPage,
				query = searchEntry:GetValue() or "",
				owned_count = ownedCount,
				dedup_count = dedupCount,
				visible_count = visibleCount,
			}
			TFDebugBridge.SetBackpackState(snapshot)
			if TFDebugBridge.Emit then
				TFDebugBridge.Emit("backpack_rebuild", snapshot, false)
			end
		end

		for p = 1, totalPages do
			local btn = vgui.Create("DButton", pageBar)
			btn:SetSize(30, 26)
			btn:SetText("")
			btn.Paint = function(self, w, h)
				if p == currentPage then
					surface.SetDrawColor(140, 85, 70, 255)
				else
					surface.SetDrawColor(120, 112, 98, 225)
				end
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(90, 84, 76, 255)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
				draw.SimpleText(tostring(p), "HudFontSmallBold", w * 0.5, h * 0.5, Color(245, 236, 214, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			btn.DoClick = function()
				currentPage = p
				panel:BuildItems()
			end
			pageBar:Add(btn)
		end

		local startIndex = ((currentPage - 1) * pageSize) + 1
		local endIndex = math.min(#sourceItems, startIndex + pageSize - 1)
		local split = {}
		local convar = GetConVar("loadout_" .. activeClass)
		if convar then
			split = string.Split(convar:GetString(), ",")
		end

		local spaceX, spaceY = 6, 6
		local gridW, gridH = gridPanel:GetWide() - 20, gridPanel:GetTall() - 20
		local tileW = math.max(96, math.floor((gridW - ((columns - 1) * spaceX)) / columns))
		local tileH = math.max(74, math.floor((gridH - ((rows - 1) * spaceY)) / rows))

		for idx = startIndex, endIndex do
			local item = sourceItems[idx]
			local model = vgui.Create("ItemModelPanel", itemicons)
			model:SetSize(tileW, tileH)
			itemicons:Add(model)

			model.activeImage = loadout_rect_mouseover
			model.inactiveImage = loadout_rect
			model.model_xpos = 0
			model.model_ypos = 4
			model.model_tall = math.max(30, math.floor(tileH * 0.5))
			model.text_xpos = -5
			model.text_wide = tileW + 10
			model.text_ypos = tileH - 15
			model.itemImage_low = nil
			model.text = getItemDisplayName(item)
			model.centerytext = true

			local quality = 0
			if item.item_quality then
				quality = string.upper(string.sub(item.item_quality, 1, 1)) .. string.sub(item.item_quality, 2)
			end
			model:SetQuality(quality)

			local invMat
			if isstring(item.image_inventory) and item.image_inventory ~= "" then
				invMat = Material(item.image_inventory)
			end
			if (not invMat) or invMat:IsError() then
				model.FallbackModel = item.model_player
				model.itemImage = surface.GetTextureID("backpack/weapons/c_models/c_bat")
			else
				model.itemImage = surface.GetTextureID(item.image_inventory)
			end

			local compatible = classCanUseItem(item, activeClass)
			local slotCompatible = forcedSlot == nil or forcedSlot == false
			if forcedSlot then
				slotCompatible = true
			end
			compatible = compatible and slotCompatible
			model.disabled = not compatible
			if not compatible then
				model:SetAlpha(95)
			end

			local equipped = false
			local itemId = tonumber(item.id)
			if itemId and #split >= 6 then
				if forcedSlot then
					equipped = tonumber(split[forcedSlot]) == itemId
				else
					for s = 1, 6 do
						if tonumber(split[s]) == itemId then
							equipped = true
							break
						end
					end
				end
			end
			if equipped then
				model.PaintOver = function(self, w, h)
					draw.SimpleText("Equipped", "HudFontSmallBold", w - 6, h - 4, Color(238, 131, 84, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
				end
			end

			model.DoClick = function()
				if not compatible then return end

				local slot = mapItemToLoadoutSlot(item, activeClass)
				if forcedSlot then
					slot = forcedSlot
				end
				if item.item_class == "tf_wearable_item" then
					slot = forcedSlot or getWearableTargetSlot(activeClass, item.id)
				end
				if not slot then return end

				updateLoadout(slot, item.id, true, activeClass)
				surface.PlaySound(item.mouse_pressed_sound or "ui/item_hat_pickup.wav")
				if TFDebugBridge and TFDebugBridge.Emit then
					TFDebugBridge.Emit("backpack_select_item", {
						class = activeClass,
						slot = slot,
						item_id = tonumber(item.id),
						item_name = getItemDisplayName(item),
						page = currentPage,
						query = searchEntry:GetValue() or "",
					}, false)
				end
			end

			model.DoRightClick = function()
				local menu = DermaMenu()
				menu:AddOption("Inspect", function()
					openBackpackInspect(item, activeClass)
					if TFDebugBridge and TFDebugBridge.Emit then
						TFDebugBridge.Emit("backpack_inspect_item", {
							class = activeClass,
							item_id = tonumber(item.id),
							item_name = getItemDisplayName(item),
							page = currentPage,
						}, false)
					end
				end):SetIcon("icon16/magnifier.png")
				menu:Open()
			end
		end
	end

	panel:BuildItems()

	local refreshHookId = "TFStandaloneBackpackRefresh_" .. tostring(panel)
	hook.Add("TFInventoryCacheUpdated", refreshHookId, function()
		if IsValid(panel) then
			panel:BuildItems()
		else
			hook.Remove("TFInventoryCacheUpdated", refreshHookId)
		end
	end)

	panel.OnRemove = function()
		hook.Remove("TFInventoryCacheUpdated", refreshHookId)
		if TFDebugBridge and TFDebugBridge.Emit then
			TFDebugBridge.Emit("backpack_close", {
				class = activeClass,
				slot = panel.ForcedLoadoutSlot,
			}, false)
		end
	end
end

function itemSelector(type, weapons, parent, classid, oldclass)
	local classIndex = classid or GetConVar("tf_hud_loadout_class"):GetInt()
	local className = oldclass or classIndexToName[classIndex] or "scout"
	TF_OpenStandaloneBackpack(className, classIndex, type)
end

function hatSelector(type, slot, oldclass, weapons)
	local classIndex = GetConVar("tf_hud_loadout_class"):GetInt()
	local className = oldclass or classIndexToName[classIndex] or "scout"
	TF_OpenStandaloneBackpack(className, classIndex, slot)
end

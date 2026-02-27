TFJoinFlow = TFJoinFlow or {}

TFJoinFlow.InitialFlowShown = TFJoinFlow.InitialFlowShown or false
TFJoinFlow.MOTDPanel = TFJoinFlow.MOTDPanel or nil
TFJoinFlow.TeamPanel = TFJoinFlow.TeamPanel or nil
TFJoinFlow.TeamOpenCooldownUntil = TFJoinFlow.TeamOpenCooldownUntil or 0
TFJoinFlow.PendingTeamJoinUntil = TFJoinFlow.PendingTeamJoinUntil or 0
local joinflow_debug = GetConVar("tf_teamselect_debug")
if not joinflow_debug then
	joinflow_debug = CreateClientConVar("tf_teamselect_debug", "1", true, false, "Enable TF2 team select debug logging.")
end

local function jfLog(msg)
	if not joinflow_debug or not joinflow_debug:GetBool() then return end
	MsgN("[TFJoinFlow] " .. tostring(msg))
end

local function ensurePanelClass(className, retries)
	if vgui.GetControlTable(className) then
		return true
	end

	-- Failsafe: force-load known panel files when VGUI load order misses them.
	local forcedFile = nil
	if className == "TFTeamSelectPanel" then
		forcedFile = "vgui/menu_teamselectpanel.lua"
	elseif className == "TFMOTDPanel" then
		forcedFile = "vgui/menu_motdpanel.lua"
	end
	if forcedFile then
		jfLog("force include " .. forcedFile .. " for " .. className)
		local loaded = false
		if CompileFile then
			local chunk = CompileFile(forcedFile)
			if isfunction(chunk) then
				local ok, err = pcall(chunk)
				if not ok then
					jfLog("compile run failed for " .. forcedFile .. ": " .. tostring(err))
				else
					loaded = true
				end
			else
				jfLog("compile failed for " .. forcedFile)
			end
		end
		if not loaded then
			local ok, err = pcall(include, forcedFile)
			if not ok then
				jfLog("include failed for " .. forcedFile .. ": " .. tostring(err))
			end
		end
		if vgui.GetControlTable(className) then
			jfLog("panel class recovered: " .. className)
			return true
		end
	end

	if retries <= 0 then
		jfLog("panel class missing after retries: " .. className)
		return false
	end
	timer.Simple(0.1, function()
		ensurePanelClass(className, retries - 1)
	end)
	return false
end

function TFJoinFlow:ClosePanels()
	jfLog("ClosePanels called")
	if IsValid(self.MOTDPanel) then
		self.MOTDPanel:Remove()
	end
	if IsValid(self.TeamPanel) then
		self.TeamPanel:Remove()
	end
	self.MOTDPanel = nil
	self.TeamPanel = nil
end

function TFJoinFlow:OpenMOTD(initialFlow)
	jfLog("OpenMOTD initialFlow=" .. tostring(initialFlow))
	if not vgui.GetControlTable("TFMOTDPanel") then
		jfLog("TFMOTDPanel control missing, scheduling retry")
		if ensurePanelClass("TFMOTDPanel", 20) then
			jfLog("TFMOTDPanel recovered immediately")
		else
		timer.Simple(0.2, function()
			if not IsValid(LocalPlayer()) then return end
			TFJoinFlow:OpenMOTD(initialFlow)
		end)
		return
		end
	end

	if IsValid(self.TeamPanel) then
		self.TeamPanel:ClosePanel()
	end

	if not IsValid(self.MOTDPanel) then
		self.MOTDPanel = vgui.Create("TFMOTDPanel")
	end

	self.MOTDPanel:SetInitialFlow(initialFlow)
	self.MOTDPanel:SetNextCallback(function()
		TFJoinFlow:OpenTeamSelect(initialFlow)
	end)
	self.MOTDPanel:SetSkipCallback(function()
		TFJoinFlow:OpenTeamSelect(initialFlow)
	end)
	self.MOTDPanel:OpenPanel()
	jfLog("MOTD panel opened valid=" .. tostring(IsValid(self.MOTDPanel)))
end

function TFJoinFlow:OpenTeamSelect(initialFlow)
	jfLog("OpenTeamSelect initialFlow=" .. tostring(initialFlow))
	if self.TeamOpenCooldownUntil and CurTime() < self.TeamOpenCooldownUntil then
		jfLog("OpenTeamSelect ignored: cooldown")
		return
	end
	if IsValid(self.TeamPanel) and self.TeamPanel:IsVisible() then
		jfLog("OpenTeamSelect ignored: already visible")
		return
	end
	if not vgui.GetControlTable("TFTeamSelectPanel") then
		jfLog("TFTeamSelectPanel control missing, scheduling retry")
		if ensurePanelClass("TFTeamSelectPanel", 20) then
			jfLog("TFTeamSelectPanel recovered immediately")
		else
		timer.Simple(0.2, function()
			if not IsValid(LocalPlayer()) then return end
			TFJoinFlow:OpenTeamSelect(initialFlow)
		end)
		return
		end
	end

	if IsValid(self.MOTDPanel) then
		self.MOTDPanel:ClosePanel()
	end

	if IsValid(self.TeamPanel) then
		self.TeamPanel:Remove()
	end
	self.TeamPanel = vgui.Create("TFTeamSelectPanel")
	jfLog("Created TeamPanel valid=" .. tostring(IsValid(self.TeamPanel)))

	self.TeamPanel:SetInitialFlow(initialFlow)
	self.TeamPanel:OpenPanel()
	self.TeamOpenCooldownUntil = CurTime() + 0.25
	jfLog("TeamPanel open requested")
end

function TFJoinFlow:OpenInitialFlow(force)
	if self.InitialFlowShown and not force then
		return
	end

	self.InitialFlowShown = true
	self:OpenMOTD(true)
end

net.Receive("TF_OpenInitialJoinFlow", function()
	jfLog("Received TF_OpenInitialJoinFlow")
	timer.Simple(0.15, function()
		if not IsValid(LocalPlayer()) then return end
		-- Server explicitly requested initial flow: always show MOTD first.
		TFJoinFlow:OpenInitialFlow(true)
	end)
end)

hook.Add("InitPostEntity", "TFJoinFlow_ResetInitialFlow", function()
	TFJoinFlow.InitialFlowShown = false
end)

concommand.Add("tf_open_motd", function()
	TFJoinFlow:OpenMOTD(false)
end)

concommand.Add("tf_open_mapintro", function()
	TFJoinFlow:OpenMOTD(false)
end)

if concommand.Remove then
	concommand.Remove("tf_open_teamselect")
	concommand.Remove("tf_changeteam")
	concommand.Remove("tf_open_motd")
	concommand.Remove("tf_open_mapintro")
	concommand.Remove("tf_open_initial_joinflow")
end

concommand.Add("tf_open_teamselect", function()
	jfLog("concommand tf_open_teamselect")
	TFJoinFlow:OpenTeamSelect(false)
end)

concommand.Add("tf_changeteam", function()
	jfLog("concommand tf_changeteam")
	TFJoinFlow:OpenTeamSelect(false)
end)

concommand.Add("tf_open_initial_joinflow", function()
	TFJoinFlow:OpenInitialFlow(true)
end)

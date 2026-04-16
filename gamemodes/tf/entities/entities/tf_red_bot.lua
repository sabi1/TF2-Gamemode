if SERVER then AddCSLuaFile() end

ENT.Type = "anim"
ENT.PZClass = "scout" 
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.IsBoss = false
ENT.Team = "RED"
ENT.PrintName		= "Red Scout"
ENT.Category		= "TFBots"

local function SpawnManagedMercBot(team, class, pos, ent)
	if (game.SinglePlayer()) then
		table.insert( Errors, {
			last	= SysTime(),
			text	= "TFBots do not work in Singleplayer! >:("
		} )
		return
	end
	if !navmesh.IsLoaded() then
		ErrorNoHalt("There is no navmesh! Generate one using \"nav_generate\"!\n")
		return
	end

	local nickname = ent.PrintName
	if isfunction(GetNextBotName) then
		nickname = GetNextBotName()
	end
	if (ent.PreferredName ~= nil) then
		nickname = ent.PreferredName
	end
	local teamv = TEAM_RED
	if team == 1 then
		teamv = TEAM_BLU
	end

	local bot = TF_CreateManagedMapBot and TF_CreateManagedMapBot(nickname, teamv, class, pos, nil, {
		useTeamSpawn = false,
		TFBotMapOwned = true,
	}) or nil
	if !IsValid(bot) then ErrorNoHalt("[LeadBot] Player limit reached!\n") return end
	bot.LastSegmented = CurTime() + 1
	bot.TFBot = true
	bot.IsL4DZombie = false
	bot.BotStrategy = math.random(0, 1)

    --timer.Simple(1, function()
        ----TalkToMe(bot, "join")
    --end)
	bot:SetTeam(teamv)
	bot:SetPlayerClass(class)
	bot:SetPos(pos)
	timer.Simple(0.1, function()
		if IsValid(bot) then
			bot:SetPlayerClass(class)
			bot.TFBot = true
		end
	end)
	--MsgN("[LeadBot] Bot " .. name .. " with strategy " .. bot.BotStrategy .. " added!")
	return bot
end

list.Set( "NPC", "tf_red_bot", {
	Name = ENT.PrintName,
	Class = "tf_red_bot",
	Category = ENT.Category,
	AdminOnly = true
} )


function ENT:Initialize()
	if CLIENT then return end	
	self:SetModel("models/player/scout.mdl")
	self:ResetSequence(self:SelectWeightedSequence(ACT_MP_STAND_MELEE))
	self:SetSolid(SOLID_NONE)
	self:SetModelScale(1) 
	self.bots = {}
	self.infected = {}
	local team = 0
	if (self.Team == "BLU") then
		team = 1
	end
	
	if (self.PZClass == "civilian_" && !file.Exists("models/player/civilian.mdl","WORKSHOP")) then 
		self:Remove()
	end
    local npc = SpawnManagedMercBot(team, self.PZClass, self:GetPos(), self)
    if (!IsValid(npc)) then 
        ErrorNoHalt("The bot could not spawn because you are in singleplayer!") 
        return 
    end
	self:SetNoDraw(true)
    self:SetModel(npc:GetModel())
	self:ResetSequence(self:SelectWeightedSequence(ACT_MP_STAND_MELEE))
	timer.Simple(0.3, function()
		if not IsValid(self) or not IsValid(npc) then return end
		
		if (self.Team == "BLU") then
	
			npc:SetSkin(1)
				
		end
		local function TryApplyMercLoadout()
			if not IsValid(npc) then return false end
			if not isfunction(TFBot_ApplyRandomLoadout) then return false end
			return TFBot_ApplyRandomLoadout(npc, { initial_spawn = true, cooldown = 0.05 }) == true
		end

		if not TryApplyMercLoadout() then
			timer.Simple(0.3, function()
				if TryApplyMercLoadout() then return end
				timer.Simple(0.4, function()
					TryApplyMercLoadout()
				end)
			end)
		end
		local class = npc:GetPlayerClass()
		if (class != "scout" and 
			class != "soldier" and 
			class != "pyro" and 
			class != "demoman" and 
			class != "heavy" and 
			class != "engineer" and 
			class != "medic" and 
			class != "sniper" and 
			class != "spy" and 
			class != "gmodplayer") 
		then
			
			local class = npc.playerclass
			if (string.find(class,"demoman")) then
				class = "demo"
			elseif (string.find(class,"Demoman")) then
				class = "demo"
			elseif (string.find(class,"demoknight")) then
				class = "demo"
			end
		else
			
			local class = npc:GetPlayerClass()
			if (string.find(class,"demoman")) then
				class = "demo"
			elseif (string.find(class,"Demoman")) then
				class = "demo"
			elseif (string.find(class,"demoknight")) then
				class = "demo"
			end
			
		end

	end)
	self.Bot = npc
end

function ENT:Think()
	if (!IsValid(self.Bot) and SERVER) then
		self:Remove() 
	end 
	self:NextThink(CurTime() + 0.5)
	return true
end

function ENT:OnRemove()
	if SERVER then
		if IsValid(self.Bot) then
			self.Bot:Kick()
		end
	end
end

function ENT:SpawnFunction( ply, tr, ClassName )

	if ( !tr.Hit ) then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 16

	local ent = ents.Create( ClassName )
	ent:SetPos( SpawnPos )
	ent:Spawn()
	ent:Activate()

	return ent

end

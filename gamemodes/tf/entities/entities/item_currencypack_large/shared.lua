ENT.PrintName = "Currency Pack (large)"
ENT.Author = "TF2-Gamemode"
ENT.Information = "An MvM currency pickup."
ENT.Category = "Team Fortress 2"

ENT.Spawnable = true
ENT.AdminSpawnable = true

ENT.Type = "anim"
ENT.Base = "item_base"

ENT.Model = "models/items/currencypack_large.mdl"
ENT.CurrencyAmount = 100
ENT.TouchSound = Sound("MVM.MoneyPickup")

if SERVER then
	AddCSLuaFile("shared.lua")

	local function to_number(v, fallback)
		local n = tonumber(v)
		if n == nil then return fallback end
		return n
	end

	local function is_mvm_player(ply)
		return IsValid(ply) and ply:IsPlayer() and ply:Team() == TEAM_RED and not ply.TFBot
	end

	function ENT:CanPickup(ply)
		if not is_mvm_player(ply) then return false end
		if TF_MVM and TF_MVM.Runtime and TF_MVM.Runtime.Active == false then
			-- Keep map-authored packs functional even if runtime is not active.
			return true
		end
		return true
	end

	function ENT:GetCurrencyAmount()
		return math.max(0, math.floor(to_number(self.CurrencyAmount, 0)))
	end

	function ENT:GiveCurrency(collector)
		local amount = self:GetCurrencyAmount()
		if amount <= 0 then return end

		if TF_MVM and TF_MVM.Economy and TF_MVM.Economy.Distribute then
			-- Currency packs are team-shared in MvM.
			TF_MVM.Economy:Distribute(amount, nil)
			return
		end

		if TF_MVMShop and TF_MVMShop.AddCredits then
			for _, ply in ipairs(player.GetAll()) do
				if is_mvm_player(ply) then
					TF_MVMShop:AddCredits(ply, amount)
				end
			end
			return
		end

		if IsValid(collector) then
			collector:SetNWInt("TF_MVM_Credits", collector:GetNWInt("TF_MVM_Credits", 0) + amount)
		end
	end

	function ENT:PlayerTouched(pl)
		self:GiveCurrency(pl)
		if IsValid(pl) then
			pl:EmitSound(self.TouchSound)
		end
		self:Hide()
	end

	function ENT:KeyValue(key, value)
		key = string.lower(key)

		if key == "model" then
			self.Model = tostring(value)
			self:SetModel(self.Model)
			return
		end

		if key == "currency" or key == "amount" or key == "value" or key == "currencypackvalue" then
			self.CurrencyAmount = to_number(value, self.CurrencyAmount)
			return
		end

		if key == "touchsound" then
			self.TouchSound = Sound(tostring(value))
			return
		end
	end
end
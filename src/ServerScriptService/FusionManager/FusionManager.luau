local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local DataManager = require(game:GetService("ServerScriptService"):WaitForChild("DataManager"):WaitForChild("DataManager"))
local Networker = require(ReplicatedStorage.Packages.Networker)

local FusionManager = {}
local CAR_TAG = "CarModel"

-- Helper to count owned cars of a specific full name in player's Backpack
local function getOwnedCarCount(player: Player, carFullName: string): number
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return 0 end

	local count = 0
	for _, child in ipairs(backpack:GetChildren()) do
		if child.Name == carFullName then
			local amount = child:GetAttribute("Amount") or 1
			count = count + (amount :: number)
		end
	end
	return count
end

-- Helper to remove specific count of cars from player's Backpack (handles Stacks cleanly)
local function removeCarFromBackpack(player: Player, carFullName: string, amountToRemove: number)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local remaining = amountToRemove
	for _, child in ipairs(backpack:GetChildren()) do
		if child.Name == carFullName then
			local amount = child:GetAttribute("Amount") or 1
			if amount > remaining then
				child:SetAttribute("Amount", amount - remaining)
				
				local stacks = child:FindFirstChild("Stacks")
				if stacks then
					for _ = 1, remaining do
						local children = stacks:GetChildren()
						if #children > 0 then
							children[#children]:Destroy()
						end
					end
				end
				break
			else
				remaining = remaining - amount
				child:Destroy()
				if remaining <= 0 then
					break
				end
			end
		end
	end
end

-- Determine next rarity tier and vehicle template name
local function getUpgradedCar(rarity: string, carName: string): (string, string)
	local rarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "God", "Celestial" }
	local currentIdx = table.find(rarityOrder, rarity)
	if not currentIdx or currentIdx >= #rarityOrder then
		return rarity, carName
	end
	local nextRarity = rarityOrder[currentIdx + 1]

	-- 1. Try to find the same team/model in the next rarity
	if GameConfig.CarRarityList[nextRarity] and GameConfig.CarRarityList[nextRarity][carName] then
		return nextRarity, carName
	end

	-- 2. Fallback: select a random car from the next rarity pool
	local nextRarityPool = GameConfig.CarRarityList[nextRarity]
	if nextRarityPool then
		local keys = {}
		for k, _ in pairs(nextRarityPool) do
			table.insert(keys, k)
		end
		if #keys > 0 then
			local chosenName = keys[math.random(1, #keys)]
			return nextRarity, chosenName
		end
	end

	return rarity, carName
end

-- Roll output variant based on inputs
local function rollFusionVariant(inputVariant: string): string
	if inputVariant == "Normal" then
		-- Standard variant chance roll (similar to opening a box)
		local rand = math.random() * 100
		local cumulative = 0
		for vName, vData in pairs(GameConfig.Variants) do
			if vName ~= "Normal" and vName ~= "Admin" then
				cumulative = cumulative + vData.Chance
				if rand <= cumulative then
					return vName
				end
			end
		end
		return "Normal"
	else
		-- Variant input! 80% to keep, 10% to upgrade to next variant, 10% to downgrade
		local rand = math.random() * 100
		if rand <= 80 then
			return inputVariant
		elseif rand <= 90 then
			-- Upgrade variant
			local variantTiers = { "Gold", "Galaxy", "Hellfire", "Frostbite", "Cosmic", "Rainbow" }
			local idx = table.find(variantTiers, inputVariant)
			if idx and idx < #variantTiers then
				return variantTiers[idx + 1]
			end
			return inputVariant
		else
			return "Normal" -- Downgrade
		end
	end
end

-- =============================================================================
-- FUSION SERVICE API
-- =============================================================================
local FusionService = {}

function FusionService:fuseCars(player: Player, carFullName: string)
	if not player or not player.Parent then
		return { Success = false, Error = "Player tidak valid" }
	end

	local ownedCount = getOwnedCarCount(player, carFullName)
	if ownedCount < 3 then
		return { Success = false, Error = "Anda membutuhkan minimal 3 mobil yang sama untuk melakukan fusion." }
	end

	-- Parse carFullName (Format: CarName_Rarity_Variant)
	local parts = string.split(carFullName, "_")
	local carBaseName = parts[1] or carFullName
	local rarity = parts[2] or "Common"
	local variant = parts[3] or "Normal"

	if rarity == "Celestial" or rarity == "Admin" then
		return { Success = false, Error = "Mobil pada tingkat ini sudah mencapai batas upgrade maksimum!" }
	end

	-- ===== DOUBLE ROLL SYSTEM (PERFECT FUSION vs STANDARD CHANCE) =====
	local roll1 = math.random() * 100
	local isPerfect = (roll1 <= 15) -- 15% chance for instant Perfect Fusion success
	local isSuccess = isPerfect

	if not isPerfect then
		local baseChance = GameConfig.RarityFusionRates[rarity] or 0.50
		local roll2 = math.random()
		isSuccess = (roll2 <= baseChance)
	end

	if isSuccess then
		-- SUCCESS FUSION: Consume all 3 materials
		removeCarFromBackpack(player, carFullName, 3)

		-- Find output details
		local nextRarity, nextCarName = getUpgradedCar(rarity, carBaseName)
		local nextVariant = rollFusionVariant(variant)

		-- Clone and build upgraded car
		local foundTemplate = nil
		for _, carTemplate in ipairs(CollectionService:GetTagged(CAR_TAG)) do
			if carTemplate:IsDescendantOf(ServerStorage) and carTemplate.Name == nextCarName then
				foundTemplate = carTemplate
				break
			end
		end

		if not foundTemplate then
			return { Success = false, Error = "Template mobil baru tidak ditemukan di server." }
		end

		local carToolTemplate = ServerStorage:FindFirstChild("Car")
		if not carToolTemplate then
			return { Success = false, Error = "Tool 'Car' tidak ditemukan di ServerStorage!" }
		end

		local upgradedCar = carToolTemplate:Clone()
		local carModel = foundTemplate:Clone()
		carModel.Name = "Model"
		carModel.Parent = upgradedCar

		CollectionService:AddTag(upgradedCar, "Car")

		-- Setup Attributes
		local nextFullName = nextCarName .. "_" .. nextRarity .. "_" .. nextVariant
		local tierData = GameConfig.Rarities[nextRarity] or { BasePrice = 1000 }
		local baseIncome, sellPrice = GameConfig.CalculatePrice(tierData.BasePrice, nextRarity, nextVariant, nextCarName)

		upgradedCar:SetAttribute("Income", baseIncome)
		upgradedCar:SetAttribute("Price", sellPrice)
		upgradedCar:SetAttribute("Variant", nextVariant)
		upgradedCar:SetAttribute("Rarity", nextRarity)
		upgradedCar:SetAttribute("Name", nextCarName)
		upgradedCar:SetAttribute("Type", "Car")
		upgradedCar:SetAttribute("Owner", player.Name)
		upgradedCar.Name = nextFullName

		GameConfig.ApplyVisuals(upgradedCar, nextRarity, nextVariant)

		-- Add to Backpack
		GameUtils.addCarToInventory(player, upgradedCar)

		-- Unlock in Player collection Index
		local pData = DataManager.getPlayerData(player)
		if pData then
			if not pData.CarIndexCollection then
				pData.CarIndexCollection = {}
			end
			
			local indexKey = nextFullName
			if not pData.CarIndexCollection[indexKey] then
				pData.CarIndexCollection[indexKey] = true
				
				-- Recalculate permanent multiplier
				local newMulti = GameConfig.CalculateCollectionMultiplier(pData)
				player:SetAttribute("CollectionMultiplier", newMulti)

				local NotifEvent = ReplicatedStorage:FindFirstChild("NotifEvent")
				if NotifEvent then
					NotifEvent:FireClient(
						player,
						"Index Baru Dibuka!",
						`Koleksi {nextCarName} ({nextRarity}) dibuka! Multiplier Anda sekarang: {string.format("%.1f", (newMulti - 1.0) * 100)}%!`,
						4
					)
				end
			end
		end

		DataManager.syncData(player)

		return {
			Success = true,
			IsPerfect = isPerfect,
			NewCarName = nextCarName,
			NewRarity = nextRarity,
			NewVariant = nextVariant,
		}
	else
		-- FAILURE FUSION: Consume 2 materials, keep 1
		removeCarFromBackpack(player, carFullName, 2)
		DataManager.syncData(player)

		return {
			Success = false,
			Error = "Fusion Gagal! Anda kehilangan 2 mobil duplikat, tetapi berhasil menyimpan 1 mobil dasar.",
		}
	end
end

-- =============================================================================
-- BOOTSTRAPPER INIT METHOD
-- =============================================================================
function FusionManager.Init()
	print("[FusionManager] Inisialisasi API Fusion Service...")

	Networker.server.new("FusionService", FusionService, {
		FusionService.fuseCars,
	})

	print("[FusionManager] ✅ API Fusion Service aktif!")
end

return FusionManager

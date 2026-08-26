-- ===============================================
-- GAME UTILITIES - Shared client/server functions
-- ===============================================

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local GameUtils = {}

-- ===== NUMBER/CURRENCY FORMATTING =====

-- 1. Format price/money with commas (e.g., 30000 -> 30,000)
function GameUtils.formatPrice(price: number | string): string
	local str = tostring(price)
	return str:reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

-- 2. Format money compactly (e.g., 1200 -> 1,2K; 1500000 -> 1,5M)
function GameUtils.formatCompact(value: number): string
	local textMoney = tostring(value)
	local word = ""

	if value >= 1e12 then
		textMoney = string.format("%.1f", value / 1e12)
		word = "T"
	elseif value >= 1e9 then
		textMoney = string.format("%.1f", value / 1e9)
		word = "B"
	elseif value >= 1e6 then
		textMoney = string.format("%.1f", value / 1e6)
		word = "M"
	elseif value >= 1e3 then
		textMoney = string.format("%.1f", value / 1e3)
		word = "K"
	end

	-- Remove decimal if it is .0
	textMoney = textMoney:gsub("%.0$", "")
	-- Format decimal dot to comma
	textMoney = textMoney:gsub("%.", ",")

	return textMoney .. word
end

-- ===== PLOT AND AREA DETECTION =====

-- 3. Get player's plot folder
function GameUtils.getPlayerPlot(player: Player): Folder?
	if not player then
		return nil
	end
	local plotName = player:GetAttribute("MyPlotName")
	if not plotName or plotName == "" then
		return nil
	end
	return workspace.Plots:FindFirstChild(plotName)
end

-- 4. Get plot's sell area
function GameUtils.getPlotSellShopArea(plot: Folder, areaName: string): Part?
	if not plot or not areaName then
		return nil
	end
	local areaFolder = plot:FindFirstChild(areaName)
	if not areaFolder then
		return nil
	end
	return areaFolder:FindFirstChild("Area")
end

-- 5. Get player's sell area (convenient helper combining 3 & 4)
function GameUtils.getPlayerSellShopArea(player: Player, areaName: string): Part?
	local plot = GameUtils.getPlayerPlot(player)
	if not plot then
		return nil
	end
	return GameUtils.getPlotSellShopArea(plot, areaName)
end

-- ===== TOOL AND VEHICLE IDENTIFICATION =====

-- 6. Check if a tool is classified as a car
function GameUtils.isCar(tool: Instance): boolean
	if not tool or not tool:IsA("Tool") then
		return false
	end
	return CollectionService:HasTag(tool, "Car") or tool:GetAttribute("Price") ~= nil
end

function GameUtils.updateTextLabel(car: Tool)
	local billboard = car:FindFirstChild("BillboardGui") :: BillboardGui?
	if not billboard then
		return
	end
	local nameText = billboard:FindFirstChild("Name") :: TextLabel?
	local variantText = billboard:FindFirstChild("Variants") :: TextLabel?
	local PriceText = billboard:FindFirstChild("Price") :: TextLabel?

	local carName = car:GetAttribute("Name") :: string
	local carVariant = car:GetAttribute("Variant") :: string
	local carIncome = car:GetAttribute("Income") :: number
	local rarity = car:GetAttribute("Rarity") :: string

	if nameText then
		nameText.Text = carName .. " [" .. rarity .. "]"
	end
	if variantText then
		local GameConfig = require(script.Parent.GameConfig)
		variantText.Text = GameConfig.GetColoredVariantList(carVariant)
	end
	if PriceText then
		PriceText.Text = "$ " .. GameUtils.formatCompact(carIncome) .. "/sec"
	end
end

-- 7. Scan and retrieve all car tools owned by a player (backpack + equipped)
function GameUtils.getPlayerCars(player: Player): { Tool }
	local cars = {}
	if not player then
		return cars
	end

	-- Scan Backpack
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if GameUtils.isCar(tool) then
				table.insert(cars, tool)
			end
		end
	end

	-- Scan Character (Equipped tools)
	local character = player.Character
	if character then
		for _, tool in ipairs(character:GetChildren()) do
			if GameUtils.isCar(tool) then
				if not table.find(cars, tool) then
					table.insert(cars, tool)
				end
			end
		end
	end

	return cars
end

-- =============================================================================
-- INVENTORY: Centralized helper to safely add/stack a car tool to player backpack
-- =============================================================================
function GameUtils.addCarToInventory(player: Player, car: Tool)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		car:Destroy()
		return
	end

	local existingCar: Tool? = backpack:FindFirstChild(car.Name) :: Tool?
	if existingCar then
		local stackFolder = existingCar:FindFirstChild("Stacks")
		if not stackFolder then
			stackFolder = Instance.new("Folder")
			stackFolder.Name = "Stacks"
			stackFolder.Parent = existingCar
		end

		local carData = Instance.new("Configuration")
		carData.Name = "CarData_" .. (#stackFolder:GetChildren() + 1)
		for name, value in pairs(car:GetAttributes()) do
			carData:SetAttribute(name, value)
		end
		carData.Parent = stackFolder

		local carAmount = existingCar:GetAttribute("Amount") or 1
		existingCar:SetAttribute("Amount", (carAmount :: number) + 1)
		car:Destroy()
	else
		car:SetAttribute("Amount", 1)
		car.Parent = backpack
	end
end

return GameUtils

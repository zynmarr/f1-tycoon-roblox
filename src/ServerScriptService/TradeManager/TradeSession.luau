--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig") :: ModuleScript)

local TradeSession = {}
TradeSession.__index = TradeSession

export type TradeSessionState = {
	SessionId: string,
	Player1: Player,
	Player2: Player,
	Offer1: { [string]: number }, -- carName -> count
	Offer2: { [string]: number }, -- carName -> count
	IsLocked1: boolean,
	IsLocked2: boolean,
	IsConfirmed1: boolean,
	IsConfirmed2: boolean,
	Active: boolean,
}

export type SessionType = typeof(setmetatable({} :: TradeSessionState, TradeSession))

-- Helper to count total owned cars of a specific name in player's Backpack
local function getOwnedCarCount(player: Player, carName: string): number
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return 0 end

	local count = 0
	for _, child in ipairs(backpack:GetChildren()) do
		if child.Name == carName then
			local amount = child:GetAttribute("Amount") or 1
			count = count + (amount :: number)
		end
	end
	return count
end

-- Helper to remove one count of a car from player's Backpack
local function removeCarFromBackpack(player: Player, carName: string)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local foundCar = backpack:FindFirstChild(carName)
	if not foundCar then return end

	local amount = foundCar:GetAttribute("Amount") or 1
	if (amount :: number) > 1 then
		foundCar:SetAttribute("Amount", (amount :: number) - 1)
		
		-- Also remove a configurations from Stacks folder if it exists
		local stacks = foundCar:FindFirstChild("Stacks")
		if stacks then
			local children = stacks:GetChildren()
			if #children > 0 then
				children[#children]:Destroy()
			end
		end
	else
		foundCar:Destroy()
	end
end

-- Helper to safely add/gift a car to a player's Backpack based on custom properties
local function addCarToBackpack(player: Player, carFullName: string)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	-- Decipher car name, rarity and variant from the FullName format: "CarName_Rarity_Variant"
	local parts = string.split(carFullName, "_")
	local carBaseName = parts[1] or carFullName
	local rarity = parts[2] or "Common"
	local variant = parts[3] or "Admin"

	local foundTemplate = nil
	for _, carTemplate in ipairs(CollectionService:GetTagged("CarModel")) do
		if carTemplate:IsDescendantOf(ServerStorage) and carTemplate.Name == carBaseName then
			foundTemplate = carTemplate
			break
		end
	end

	if not foundTemplate then
		warn("[TradeSession] Template car model not found in ServerStorage: " .. carBaseName)
		return
	end

	-- Clone Tool "Car" dari ServerStorage
	local carToolTemplate = ServerStorage:FindFirstChild("Car")
	if not carToolTemplate then
		warn("[TradeSession] Tool 'Car' tidak ditemukan di ServerStorage!")
		return
	end

	local car = carToolTemplate:Clone()
	local carModel = foundTemplate:Clone()
	carModel.Name = "Model"
	carModel.Parent = car

	CollectionService:AddTag(car, "Car")

	-- Unanchor and setup physics tags
	for _, part in ipairs(car:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
		end
	end

	local tierData = (GameConfig.Rarities :: any)[rarity] or { BasePrice = 1000 }
	local baseIncome, sellPrice = GameConfig.CalculatePrice(tierData.BasePrice, rarity, variant)

	car:SetAttribute("Income", baseIncome)
	car:SetAttribute("Price", sellPrice)
	car:SetAttribute("Variant", variant)
	car:SetAttribute("Rarity", rarity)
	car:SetAttribute("Name", foundTemplate.Name)
	car:SetAttribute("Type", "Car")
	car.Name = carFullName

	GameConfig.ApplyVisuals(car, rarity, variant)

	local existingCar = backpack:FindFirstChild(car.Name)
	if existingCar then
		local stackFolder = existingCar:FindFirstChild("Stacks") or Instance.new("Folder", existingCar)
		stackFolder.Name = "Stacks"

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

function TradeSession.new(id: string, p1: Player, p2: Player): SessionType
	local self = setmetatable({}, TradeSession)
	self.SessionId = id
	self.Player1 = p1
	self.Player2 = p2
	self.Offer1 = {}
	self.Offer2 = {}
	self.IsLocked1 = false
	self.IsLocked2 = false
	self.IsConfirmed1 = false
	self.IsConfirmed2 = false
	self.Active = true
	return (self :: any) :: SessionType
end

function TradeSession.AddCar(self: SessionType, player: Player, carName: string): (boolean, string?)
	if not self.Active then return false, "Sesi trade tidak aktif." end
	
	local isP1 = player == self.Player1
	local isP2 = player == self.Player2
	if not (isP1 or isP2) then return false, "Pemain tidak terdaftar dalam sesi ini." end

	if isP1 and self.IsLocked1 then return false, "Tawaran Anda sudah terkunci." end
	if isP2 and self.IsLocked2 then return false, "Tawaran Anda sudah terkunci." end

	local currentOffer = isP1 and self.Offer1 or self.Offer2
	local currentCount = currentOffer[carName] or 0
	local ownedCount = getOwnedCarCount(player, carName)

	if ownedCount > currentCount then
		currentOffer[carName] = currentCount + 1
		-- Reset locks on changes
		self.IsLocked1 = false
		self.IsLocked2 = false
		self.IsConfirmed1 = false
		self.IsConfirmed2 = false
		return true
	else
		return false, "Jumlah mobil di tas tidak mencukupi."
	end
end

function TradeSession.RemoveCar(self: SessionType, player: Player, carName: string): (boolean, string?)
	if not self.Active then return false, "Sesi trade tidak aktif." end

	local isP1 = player == self.Player1
	local isP2 = player == self.Player2
	if not (isP1 or isP2) then return false, "Pemain tidak terdaftar dalam sesi ini." end

	if isP1 and self.IsLocked1 then return false, "Tawaran Anda sudah terkunci." end
	if isP2 and self.IsLocked2 then return false, "Tawaran Anda sudah terkunci." end

	local currentOffer = isP1 and self.Offer1 or self.Offer2
	local currentCount = currentOffer[carName] or 0

	if currentCount > 0 then
		if currentCount == 1 then
			currentOffer[carName] = nil
		else
			currentOffer[carName] = currentCount - 1
		end
		-- Reset locks on changes
		self.IsLocked1 = false
		self.IsLocked2 = false
		self.IsConfirmed1 = false
		self.IsConfirmed2 = false
		return true
	else
		return false, "Mobil tidak ada dalam penawaran."
	end
end

function TradeSession.Lock(self: SessionType, player: Player): (boolean, string?)
	if not self.Active then return false, "Sesi trade tidak aktif." end

	local isP1 = player == self.Player1
	local isP2 = player == self.Player2
	if not (isP1 or isP2) then return false, "Pemain tidak terdaftar dalam sesi ini." end

	if isP1 then
		self.IsLocked1 = true
	else
		self.IsLocked2 = true
	end
	return true
end

function TradeSession.Unlock(self: SessionType, player: Player): (boolean, string?)
	if not self.Active then return false, "Sesi trade tidak aktif." end

	local isP1 = player == self.Player1
	local isP2 = player == self.Player2
	if not (isP1 or isP2) then return false, "Pemain tidak terdaftar dalam sesi ini." end

	if isP1 then
		self.IsLocked1 = false
	else
		self.IsLocked2 = false
	end
	
	-- Reset confirmations
	self.IsConfirmed1 = false
	self.IsConfirmed2 = false
	return true
end

function TradeSession.Confirm(self: SessionType, player: Player): (boolean, string?)
	if not self.Active then return false, "Sesi trade tidak aktif." end
	if not (self.IsLocked1 and self.IsLocked2) then return false, "Kedua pemain harus mengunci penawaran terlebih dahulu." end

	local isP1 = player == self.Player1
	local isP2 = player == self.Player2
	if not (isP1 or isP2) then return false, "Pemain tidak terdaftar dalam sesi ini." end

	if isP1 then
		self.IsConfirmed1 = true
	else
		self.IsConfirmed2 = true
	end
	return true
end

function TradeSession.Execute(self: SessionType): (boolean, string?)
	if not self.Active then return false, "Sesi trade tidak aktif." end
	if not (self.IsConfirmed1 and self.IsConfirmed2) then return false, "Kedua pemain belum mengonfirmasi trade." end

	-- 1. Double ownership checks (Atomic verification)
	for carName, count in pairs(self.Offer1) do
		local owned = getOwnedCarCount(self.Player1, carName)
		if owned < count then
			self.Active = false
			return false, string.format("Trade gagal! %s tidak memiliki jumlah mobil yang cukup untuk %s.", self.Player1.Name, carName)
		end
	end

	for carName, count in pairs(self.Offer2) do
		local owned = getOwnedCarCount(self.Player2, carName)
		if owned < count then
			self.Active = false
			return false, string.format("Trade gagal! %s tidak memiliki jumlah mobil yang cukup untuk %s.", self.Player2.Name, carName)
		end
	end

	-- 2. Execute ownership transfers in Server
	-- Transfer from Player 1 to Player 2
	for carName, count in pairs(self.Offer1) do
		for _ = 1, count do
			removeCarFromBackpack(self.Player1, carName)
			addCarToBackpack(self.Player2, carName)
		end
	end

	-- Transfer from Player 2 to Player 1
	for carName, count in pairs(self.Offer2) do
		for _ = 1, count do
			removeCarFromBackpack(self.Player2, carName)
			addCarToBackpack(self.Player1, carName)
		end
	end

	-- 3. Save players data instantly
	local DataManager = require(ReplicatedStorage.Parent:WaitForChild("ServerScriptService"):WaitForChild("DataManager") :: ModuleScript)
	if DataManager and (DataManager :: any).syncData then
		pcall(function()
			local dm = DataManager :: any
			dm.syncData(self.Player1)
			dm.syncData(self.Player2)
		end)
	end

	self.Active = false
	return true
end

function TradeSession.GetState(self: SessionType): TradeSessionState
	return {
		SessionId = self.SessionId,
		Player1 = self.Player1,
		Player2 = self.Player2,
		Offer1 = self.Offer1,
		Offer2 = self.Offer2,
		IsLocked1 = self.IsLocked1,
		IsLocked2 = self.IsLocked2,
		IsConfirmed1 = self.IsConfirmed1,
		IsConfirmed2 = self.IsConfirmed2,
		Active = self.Active,
	}
end

return TradeSession

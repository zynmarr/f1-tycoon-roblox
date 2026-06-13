local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig"))
local ServerStorage = game:GetService("ServerStorage")
local GameUtils = require(ReplicatedStorage.GameUtils)
local ParkingAreaManager = require(game.ServerScriptService.ParkingAreaManager.ParkingAreaManager)

local CarManager = {}
local CAR_TAG = "Car"

-- export type CarAttributes = {
-- 	Name: string,
-- 	Rarity: string,
-- 	Variant: string,
-- 	Price: number,
-- 	Amount: number,
-- 	IsPicked: boolean,
-- 	RotationOffset: number,
-- 	Location: string,
-- 	Rider: string,
-- 	Income: number,
-- 	IsParked: boolean,
-- 	[string]: any, -- Mengizinkan atribut dinamis lain yang berupa string
-- }

-- -- Deklarasi tipe utama untuk CarData (Struktur Map / JSON dari DataStore)
-- export type CarData = {
-- 	Name: string,
-- 	Location: string,
-- 	Attributes: CarAttributes,
-- }

local function loadlHandle(car: Tool): BasePart
	local handle = car:FindFirstChild("Handle") :: BasePart?
	local modelContainer = car:FindFirstChild("Model") :: Model?

	-- Ambil ukuran asli model Car
	local carCFrame, carSize
	if modelContainer then
		carCFrame, carSize = modelContainer:GetBoundingBox()
	else
		carCFrame, carSize = car:GetBoundingBox()
	end

	if not handle then
		handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Parent = car
	elseif handle then
		handle:Destroy()
		handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Parent = car
	end

	handle.Size = carSize
	handle.CFrame = carCFrame
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Anchored = false

	return handle
end

local function updateTextLabel(car)
	local billboard = car:FindFirstChild("BillboardGui") :: BillboardGui?
	if not billboard then
		return
	end
	local nameText = billboard:FindFirstChild("Name") :: TextLabel?
	local variantText = billboard:FindFirstChild("Variants") :: TextLabel?
	local PriceText = billboard:FindFirstChild("Price") :: TextLabel?

	local carName = car:GetAttribute("Name")
	local carVariant = car:GetAttribute("Variant")
	local carPrice = car:GetAttribute("Price")
	local rarity = car:GetAttribute("Rarity")

	if nameText then
		nameText.Text = carName .. " [" .. rarity .. "]"
	end
	if variantText then
		variantText.Text = GameConfig.GetColoredVariantList(carVariant)
	end
	if PriceText then
		PriceText.Text = "$ " .. GameUtils.formatCompact(carPrice)
	end
end

local function processPickup(player, car)
	local rotationOffset = car:GetAttribute("RotationOffset") or 0
	local finalRot = math.rad(0 + rotationOffset)

	car.Grip = CFrame.new(0, -0.8, 2) * CFrame.Angles(0, finalRot, 0)
	updateTextLabel(car)
end

local function setupCar(car)
	if car:GetAttribute("IsInitialized") then
		return
	end
	car:SetAttribute("IsInitialized", true)

	local model = car:FindFirstChild("Model") :: Model?

	local handle = loadlHandle(car) :: BasePart
	if car:IsA("Model") or car:IsA("Tool") then
		car.PrimaryPart = handle
		if model then
			model.PrimaryPart = handle
			model:PivotTo(handle.CFrame)
		end
	end

	if not car:GetAttribute("ScaleFixed") then
		car:ScaleTo(0.2)
		car:SetAttribute("ScaleFixed", true)
	end

	GameConfig.cleanupAndWeldCar(car.Model)

	local prompt = car:FindFirstChild("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end

	GameConfig.ApplyVisuals(car, car:GetAttribute("Rarity"), car:GetAttribute("Variant"))

	if car:IsA("Tool") then
		car.Equipped:Connect(function()
			local billboard = car:FindFirstChild("BillboardGui")
			if billboard then
				billboard.Size = billboard.Size + UDim2.new(4, 0, 0.9, 0)
			end
			local character = car.Parent
			local player = game.Players:GetPlayerFromCharacter(character)
			if player then
				processPickup(player, car)
			end
		end)

		car.Unequipped:Connect(function()
			local billboard = car:FindFirstChild("BillboardGui")
			if billboard then
				billboard.Size = UDim2.new(3, 0, 0.6, 0)
			end
		end)
	end
end

local function onCarAdded(car)
	local function checkStatus(): boolean
		local inWorkspace = car:IsDescendantOf(workspace)
		local inPlayer = false
		local currentParent = car.Parent
		while currentParent ~= nil do
			if
				currentParent:IsA("Player")
				or currentParent:IsA("Backpack")
				or (currentParent:IsA("Model") and currentParent:FindFirstChild("Humanoid"))
			then
				inPlayer = true
				break
			end
			currentParent = currentParent.Parent
		end

		return inWorkspace or inPlayer
	end

	-- 1. Jalankan SETUP jika mobil sudah di tempat yang benar
	if checkStatus() then
		task.spawn(setupCar, car)
	else
		-- 2. Jika masih di Storage, tunggu sampai pindah ke tempat aktif
		local connection: RBXScriptConnection?
		connection = car.AncestryChanged:Connect(function()
			if checkStatus() then
				if connection then
					connection:Disconnect()
				end -- Berhenti memantau jika sudah ketemu
				task.spawn(setupCar, car)
			end
		end)

		-- Safety measure: Hapus koneksi jika objek hancur sebelum sempat pindah
		car.Destroying:Connect(function()
			if connection then
				connection:Disconnect()
			end
		end)
	end
end

function CarManager.Init()
	print("[CarManager] System Initialized...")
	for _, car in pairs(CollectionService:GetTagged(CAR_TAG)) do
		task.spawn(onCarAdded, car)
	end

	CollectionService:GetInstanceAddedSignal(CAR_TAG):Connect(function(car)
		onCarAdded(car)
	end)
end

function CarManager.spawnLoadedCar(player: Player, carData: any, plot: Instance): Model?
	local carFolder = ServerStorage:WaitForChild("F1 CARS")
	local carRarity = carFolder:FindFirstChild(carData.Attributes.Rarity)
	local carTemplate = carRarity:FindFirstChild(carData.Attributes.Name)
	if not carTemplate then
		warn("Mobil tidak ditemukan di ServerStorage: " .. carData.Name)
		return nil
	end

	local carModel = carTemplate:Clone()
	CollectionService:AddTag(carModel, "Car")
	carModel.Name = carData.Name

	for attr, val in pairs(carData.Attributes) do
		if attr ~= "IsInitialized" and attr ~= "OnHand" and attr ~= "ScaleFixed" then
			carModel:SetAttribute(attr, val)
		end
	end

	if carData.Location == "Backpack" then
		carModel.Parent = player:WaitForChild("Backpack", 5)
	else
		local parkingLots = plot:WaitForChild("AllParkingLots")
		local parkingArea = parkingLots:FindFirstChild(carData.Location)
		ParkingAreaManager.storeCar(player, parkingArea, carModel)
	end

	return carModel
end

return CarManager

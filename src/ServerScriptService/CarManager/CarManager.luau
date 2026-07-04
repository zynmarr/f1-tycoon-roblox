local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local GameUtils = require(ReplicatedStorage.GameUtils)
local ParkingAreaManager = require(game.ServerScriptService.ParkingAreaManager.ParkingAreaManager)

local CarManager = {}
local CAR_TAG = "Car"
local CAR_MODEL_TAG = "CarModel"

-- =============================================================================
-- HELPER: Cari model mobil berdasarkan nama dari CollectionService (tag CarModel)
-- Tidak lagi bergantung pada folder ServerStorage "F1 CARS"
-- =============================================================================
local function findCarModel(carName: string): Model?
	for _, model in pairs(CollectionService:GetTagged(CAR_MODEL_TAG)) do
		if model.Name == carName then
			return model
		end
	end
	return nil
end

-- =============================================================================
-- HANDLE: Buat atau rebuild Handle transparan yang membungkus model mobil
-- =============================================================================
local function loadHandle(car: Tool): BasePart
	-- Hitung bounding box dari Model jika ada, atau dari seluruh Tool
	local modelContainer = car:FindFirstChild("Model") :: Model?
	local carCFrame, carSize
	if modelContainer then
		carCFrame, carSize = modelContainer:GetBoundingBox()
	else
		carCFrame, carSize = car:GetBoundingBox()
	end

	-- Destroy handle lama jika ada, buat yang baru
	local existingHandle = car:FindFirstChild("Handle")
	if existingHandle then
		existingHandle:Destroy()
	end

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = carSize
	handle.CFrame = carCFrame
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Anchored = false
	handle.Parent = car

	return handle
end

-- =============================================================================
-- VISUAL: Pasang model mobil ke dalam Tool berdasarkan nama atribut
-- Dipanggil saat Tool pertama kali di-setup atau saat nama mobil berubah
-- =============================================================================
local function attachCarModel(car: Tool)
	local carName = car:GetAttribute("Name") or car.Name

	-- Hapus model lama jika ada
	local oldModel = car:FindFirstChild("Model")
	if oldModel then
		oldModel:Destroy()
	end

	-- Cari model dari CollectionService via tag CarModel
	local template = findCarModel(carName)
	if not template then
		warn("[CarManager] Model tidak ditemukan untuk mobil: " .. tostring(carName))
		return
	end

	local model: Model = template:Clone()
	model.Name = "Model"
	model.Parent = car
end

-- =============================================================================
-- SETUP: Proses inisialisasi setiap Tool Car
-- =============================================================================
local function processPickup(player: Player, car: Tool)
	local rotationOffset = car:GetAttribute("RotationOffset") or 0
	local finalRot = math.rad(0 + rotationOffset)
	car.Grip = CFrame.new(0, 0, 1) * CFrame.Angles(0, finalRot, 0)
	GameUtils.updateTextLabel(car)
end

local function setupCar(car: Tool)
	if car:GetAttribute("IsInitialized") then
		return
	end
	car:SetAttribute("IsInitialized", true)

	-- 1. Pasang model mobil ke dalam Tool (cari via tag CarModel) jika belum ada
	if not car:FindFirstChild("Model") then
		attachCarModel(car)
	end

	-- 2. Buat Handle berdasarkan ukuran model
	local handle = loadHandle(car)

	-- 3. Set PrimaryPart
	if car:IsA("Model") or car:IsA("Tool") then
		if car and car.PrimaryPart then
			car.PrimaryPart = handle :: BasePart
		end
		local model = car:FindFirstChild("Model") :: Model?
		if model then
			model.PrimaryPart = handle :: BasePart
			model:PivotTo(handle.CFrame :: CFrame)
		end
	end

	-- 4. Scale mobil ke ukuran kecil untuk inventory
	if not car:GetAttribute("ScaleFixed") then
		car:ScaleTo(0.2)
		car:SetAttribute("ScaleFixed", true)
	end

	-- 5. Weld & cleanup internal model
	local model = car:FindFirstChild("Model")
	if model then
		GameConfig.cleanupAndWeldCar(model)
	end

	-- 6. Disable ProximityPrompt jika ada
	local prompt = car:FindFirstChild("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end

	-- 7. Terapkan visual rarity & variant
	GameConfig.ApplyVisuals(car, car:GetAttribute("Rarity") :: string, car:GetAttribute("Variant") :: string)

	-- 8. Equipped / Unequipped events
	if car:IsA("Tool") then
		car.Equipped:Connect(function()
			local billboard = car:FindFirstChild("BillboardGui") :: BillboardGui
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
			local billboard = car:FindFirstChild("BillboardGui") :: BillboardGui
			if billboard then
				billboard.Size = UDim2.new(3, 0, 0.6, 0)
			end
		end)
	end
end

-- =============================================================================
-- LISTENER: Jalankan setup saat tag Car ditambahkan
-- =============================================================================
local function onCarAdded(car: Tool)
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

	if checkStatus() then
		task.spawn(setupCar, car)
	else
		-- Tunggu sampai mobil pindah ke tempat aktif (Workspace / Backpack)
		local connection: RBXScriptConnection?
		connection = car.AncestryChanged:Connect(function()
			if checkStatus() then
				if connection then
					connection:Disconnect()
				end
				task.spawn(setupCar, car)
			end
		end)

		car.Destroying:Connect(function()
			if connection then
				connection:Disconnect()
			end
		end)
	end
end

-- =============================================================================
-- PUBLIC: Init
-- =============================================================================
function CarManager.Init()
	print("[CarManager] System Initialized...")

	for _, car in pairs(CollectionService:GetTagged(CAR_TAG)) do
		task.spawn(onCarAdded, car)
	end

	CollectionService:GetInstanceAddedSignal(CAR_TAG):Connect(function(car)
		onCarAdded(car)
	end)
end

-- =============================================================================
-- PUBLIC: Spawn mobil yang sudah tersimpan di DataStore ke tempat player
-- Tidak lagi perlu folder rarity di ServerStorage — cukup cari via tag CarModel
-- =============================================================================
function CarManager.spawnLoadedCar(player: Player, carData: any, plot: Instance): Tool?
	local carName = carData.Attributes.Name

	-- Cari template model via tag CarModel
	local carTemplate = findCarModel(carName)
	if not carTemplate then
		warn("[CarManager] Mobil tidak ditemukan di CollectionService (tag CarModel): " .. tostring(carName))
		return nil
	end

	-- Clone Tool "Car" dari ServerStorage
	local carToolTemplate = ServerStorage:FindFirstChild("Car")
	if not carToolTemplate then
		warn("[CarManager] Tool 'Car' tidak ditemukan di ServerStorage!")
		return nil
	end

	local carTool = carToolTemplate:Clone()
	local carModel = carTemplate:Clone()
	carModel.Name = "Model"
	carModel.Parent = carTool

	CollectionService:AddTag(carTool, CAR_TAG)
	carTool.Name = carData.Name
	GameUtils.updateTextLabel(carTool)

	-- Pasang semua atribut dari data simpanan
	for attr, val in pairs(carData.Attributes) do
		if attr ~= "IsInitialized" and attr ~= "OnHand" and attr ~= "ScaleFixed" then
			carTool:SetAttribute(attr, val)
		end
	end
	carTool:SetAttribute("Owner", player.Name)

	-- Tempatkan ke Backpack atau Parking
	if carData.Location == "Backpack" then
		carTool.Parent = player:WaitForChild("Backpack", 5)
	else
		local parkingLots = plot:WaitForChild("AllParkingLots")
		for _, part in pairs(parkingLots:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == carData.Location then
				ParkingAreaManager.storeCar(player, part, carTool)
			end
		end
	end

	return carTool
end

-- =============================================================================
-- PUBLIC: Expose loadHandle agar bisa dipanggil dari luar jika dibutuhkan
-- =============================================================================
CarManager.loadHandle = loadHandle

return CarManager

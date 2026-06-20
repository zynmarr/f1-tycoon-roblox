local box = script.Parent
local handle = box:WaitForChild("Handle")
local prompt = handle:WaitForChild("ProximityPrompt")

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local CARS_STORAGE = ServerStorage:WaitForChild("F1 CARS")
local BoxModels = ReplicatedStorage:WaitForChild("BoxModels") -- Gudang Model Box

-- Variables untuk menyimpan status UI


-- ==========================================
-- 0. FUNGSI UPDATE VISUAL (SWAP LEVEL)
-- ==========================================
local function updateBoxVisual()
	print("Updating box visual...")
	local currentLevel = box:GetAttribute("Level") or 1
	local targetModelName = "Level" .. tostring(currentLevel)
	local newVisualTemplate = BoxModels:FindFirstChild(targetModelName)

	if not newVisualTemplate then
		warn("Model " .. targetModelName .. " tidak ditemukan!")
		return
	end

	-- 1. Hapus visual lama
	local oldVisual = box:FindFirstChild("Model")
	if oldVisual then
		oldVisual:Destroy()
	end

	-- 2. Clone model baru
	local visualContainer = newVisualTemplate:Clone()
	visualContainer.Name = "Model"
	visualContainer.Parent = box

	if not visualContainer.PrimaryPart then
		visualContainer.PrimaryPart = visualContainer:FindFirstChildWhichIsA("BasePart", true)
	end
	local primaryPart = visualContainer.PrimaryPart
	if not primaryPart then
		return
	end

	-- 3. Posisikan Awal
	local baseOffset = 0.5
	local dynamicY = baseOffset + (handle.Size.Y / 2)

	--handle.CFrame = machine.CFrame * CFrame.new(0, dynamicY, 0)

	-- 4. POSISIKAN ULANG MODEL KE HANDLE
	--currentModel:PivotTo(handle.CFrame * CFrame.new(0, -modelDynamicY + 0.4, 0))
	visualContainer:PivotTo(handle.CFrame * CFrame.new(0, -dynamicY + 0.5, 0))

	-- 4. WELD INTERNAL (WAJIB NYALA agar tidak hancur saat di-scale)
	for _, part in pairs(visualContainer:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Anchored = false
			part.Massless = true

			if part ~= primaryPart then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primaryPart
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end

	-- 5. WELD UTAMA (Model ke Handle)
	-- Kita beri nama khusus "MainWeld" agar mudah dicari dan dilepas saat scaling
	local mainWeld = Instance.new("WeldConstraint")
	mainWeld.Name = "MainWeld"
	mainWeld.Part0 = handle
	mainWeld.Part1 = primaryPart
	mainWeld.Parent = primaryPart

	handle.Transparency = 1
end

-- ==========================================
-- 1. FUNGSI PENGAMBILAN (PICKUP)
-- ==========================================
local function processPickup(player)
	if box:GetAttribute("HasPicked") then
		return
	end
	box:SetAttribute("HasPicked", true)

	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true

	prompt:SetAttribute("CanOpen", true)
	prompt.Enabled = false

	local backpack = player:FindFirstChild("Backpack")
	local existingName = backpack and backpack:FindFirstChild(box.Name)

	if existingName then
		local stackFolder = existingName:FindFirstChild("Stacks") or Instance.new("Folder", existingName)
		stackFolder.Name = "Stacks"

		local boxData = Instance.new("Configuration")
		boxData.Name = "BoxData_" .. (#stackFolder:GetChildren() + 1)

		for name, value in pairs(box:GetAttributes()) do
			boxData:SetAttribute(name, value)
		end
		boxData.Parent = stackFolder

		local currentAmount = existingName:GetAttribute("Amount") or 1
		existingName:SetAttribute("Amount", currentAmount + 1)

		Debris:AddItem(box, 0.1)
	else
		box:SetAttribute("Amount", 1)
		box.Parent = backpack
	end
end

-- ==========================================
-- 2. FUNGSI BUKA BOX (OPEN)
-- ==========================================
local function openBox(player)
	if box:GetAttribute("IsDestroying") then
		return
	end
	if not box:GetAttribute("HasPicked") then
		return
	end

	local currentAmount = box:GetAttribute("Amount") or 1
	-- local currentLevel = box:GetAttribute("Level") or 1
	local variants = box:GetAttribute("Variants") or "Normal"
	local boxBaseLuck = box:GetAttribute("LuckyChance") or 1

	local eventLuckBoost = GameConfig.CheckLuckyChanceBoost() or 0
	local playerLuckUpgrade = player:GetAttribute("Upg_LuckyChance") or 0

	local totalLuck = boxBaseLuck + eventLuckBoost + playerLuckUpgrade
	local tier = GameConfig.RollRarity(totalLuck)
	local tierData = GameConfig.Rarities[tier]

	local availableCars = GameConfig.CarRarityList[tier]

	if tier == "Admin" then
		warn("Pemain mencoba roll Admin tier dari box biasa! Mengalihkan ke Celestial.")
		availableCars = GameConfig.CarRarityList["Celestial"]
	end

	if not availableCars or #availableCars == 0 then
		availableCars = GameConfig.CarRarityList["Common"]
	end
	print(tier)

	--local chosenModelName = availableCars[math.random(1, #availableCars)]
	local carFolder = CARS_STORAGE:FindFirstChild("Common")
	local carTemplate = carFolder:GetChildren()
	--local car = cars[math.random(1, #cars)]:Clone()
	if carTemplate then
		local car = carTemplate[math.random(1, #carTemplate)]:Clone()
		--local car = CARS_STORAGE:FindFirstChild("Common"):FindFirstChild("Paindre Edition"):Clone()
		-- Proses penempelan ke pemain...
		local baseIncome, SellPrice = GameConfig.CalculatePrice(tierData.BasePrice, tier, variants)

		car:SetAttribute("Income", baseIncome)
		car:SetAttribute("Price", SellPrice)
		car:SetAttribute("Variant", variants)
		car:SetAttribute("Rarity", tier)
		car:SetAttribute("Name", car.Name)
		car.Name = car.Name .. "_" .. tier .. "_" .. variants
		GameConfig.ApplyVisuals(car, tier, variants)

		local backpack = player:FindFirstChild("Backpack")
		local existingName = backpack and backpack:FindFirstChild(car.Name)

		if existingName then
			local stackFolder = existingName:FindFirstChild("Stacks") or Instance.new("Folder", existingName)
			stackFolder.Name = "Stacks"

			local boxData = Instance.new("Configuration")
			boxData.Name = "CarData_" .. (#stackFolder:GetChildren() + 1)

			for name, value in pairs(car:GetAttributes()) do
				boxData:SetAttribute(name, value)
			end
			boxData.Parent = stackFolder

			currentAmount = existingName:GetAttribute("Amount") or 1
			existingName:SetAttribute("Amount", currentAmount + 1)

			Debris:AddItem(car, 0.1)
		else
			car:SetAttribute("Amount", 1)
			car.Parent = backpack
		end
	else
		-- warn("Model mobil '" .. chosenModelName .. "' tidak ditemukan di CARS_STORAGE! dalam folder".. carFolder.Name)
	end

	-- Logika pemotongan Stack (Tumpukan) Box
	local stackFolder = box:FindFirstChild("Stacks")
	if stackFolder and #stackFolder:GetChildren() > 0 then
		local allStacks = stackFolder:GetChildren()
		local nextBoxData = allStacks[1]

		-- UPDATE ATRIBUT BOX KE BOX BERIKUTNYA
		box:SetAttribute("Level", nextBoxData:GetAttribute("Level"))
		box:SetAttribute("Exp", nextBoxData:GetAttribute("Exp"))
		box:SetAttribute("Variants", nextBoxData:GetAttribute("Variants"))

		local newAmount = currentAmount - 1
		box:SetAttribute("Amount", newAmount)

		nextBoxData:Destroy()
	else
		box:SetAttribute("IsDestroying", true)



		box.Parent = nil
		Debris:AddItem(box, 0.1)
	end
end

-- ==========================================
-- 3. LOGIKA UI & REMOTE EVENT (CLIENT-SERVER)
-- ==========================================

-- Bikin RemoteEvent otomatis di ReplicatedStorage kalau belum ada
local openBoxEvent = ReplicatedStorage:FindFirstChild("OpenBoxEvent")
if not openBoxEvent then
	openBoxEvent = Instance.new("RemoteEvent")
	openBoxEvent.Name = "OpenBoxEvent"
	openBoxEvent.Parent = ReplicatedStorage
end

-- Server mendengarkan sinyal klik dari LocalScript UI
openBoxEvent.OnServerEvent:Connect(function(playerCalling)
	-- [KEAMANAN]: Pastikan yang klik tombol adalah orang yang sedang memegang Box ini di tangannya
	print("CALLING OPEN BOX")
	local character = box.Parent
	local playerHolding = Players:GetPlayerFromCharacter(character)

	if playerCalling == playerHolding then
		openBox(playerCalling)
	end
end)

box.Equipped:Connect(function()
	local character = box.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	--if not box:GetAttribute("HasPicked") then
	--	processPickup(player)
	--end

	box.Grip = CFrame.new(0, 0, 2)
end)

box.Unequipped:Connect(function()
	-- Handled client side
end)

-- ==========================================
-- 4. EVENTS UTAMA & INISIALISASI
-- ==========================================
prompt.Triggered:Connect(processPickup)

box.AncestryChanged:Connect(function(_, parent)
	if not parent then
		return
	end
	if parent:IsA("Backpack") then
		box:SetAttribute("OnHand", false)
	elseif parent:IsA("Model") and parent:FindFirstChild("Humanoid") then
		box:SetAttribute("OnHand", true)
	end
end)

-- Pasang Event Pendengar: Jika Level Box berubah (misal pas buka tumpukan stack), otomatis ganti visualnya!
box:GetAttributeChangedSignal("Level"):Connect(updateBoxVisual)

-- [ANTI-MUTASI SIZE]: Jika ukuran Handle di-update terus oleh script lain, visual otomatis ikut berubah!
handle:GetPropertyChangedSignal("Size"):Connect(function()
	local currentModel = box:FindFirstChild("Model")
	if not currentModel then
		return
	end

	local primaryPart = currentModel.PrimaryPart
	if not primaryPart then
		return
	end

	local machineArea = box.Parent.Parent
	local machine = box.Parent

	-- cek machine dan jika machine tag ada, maka tidak akan diubah
	if machineArea and machineArea:GetAttribute("IsRunning") == nil then
		return
	end

	-- 1. LEPAS WELD SEMENTARA
	local mainWeld = primaryPart:FindFirstChild("MainWeld")
	if mainWeld then
		mainWeld:Destroy()
	end

	-- 2. SKALAKAN MODEL
	currentModel:ScaleTo(handle.Size.X / 3)

	-- 3. KALKULASI TINGGI DINAMIS
	local baseOffset = 0.5
	local dynamicY = baseOffset + (handle.Size.Y / 2)

	-- Pengaturan CFrame handle ditangani sepenuhnya oleh SpawnerBoxManager (Box Manager)
	-- handle.CFrame = machine.CFrame * CFrame.new(0, dynamicY, 0)

	-- 4. POSISIKAN ULANG MODEL KE HANDLE
	currentModel:PivotTo(handle.CFrame * CFrame.new(0, -(handle.Size.Y / 2) + 0.5, 0))

	-- 5. PASANG KEMBALI WELD-NYA
	mainWeld = Instance.new("WeldConstraint")
	mainWeld.Name = "MainWeld"
	mainWeld.Part0 = handle
	mainWeld.Part1 = primaryPart
	mainWeld.Parent = primaryPart
end)

-- Eksekusi visual pertama kali saat box muncul di game
updateBoxVisual()

--!strict
local BoxManager = {}

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
-- local NetworkServer = game:GetService("NetworkServer")
-- local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Networker = require(ReplicatedStorage.Packages.Networker)

local CARS_STORAGE = ServerStorage:WaitForChild("F1 CARS")
local BoxModels = ReplicatedStorage:WaitForChild("BoxModels")

local BOX_TAG = "Box"

-- type Networker = Networker.Server
-- type

-- ==========================================
-- 0. FUNGSI UPDATE VISUAL (SWAP LEVEL)
-- ==========================================
local function updateBoxVisual(box: Tool)
	if not box then
		return
	end
	local handle = box:FindFirstChild("Handle") :: Part?
	if not handle then
		return
	end

	local currentLevel = box:GetAttribute("Level") or 1
	local targetModelName = "Level" .. tostring(currentLevel)
	local newVisualTemplate = BoxModels:FindFirstChild(targetModelName)

	if not newVisualTemplate then
		warn(`[BoxManager] Model {targetModelName} tidak ditemukan di ReplicatedStorage.BoxModels!`)
		return
	end

	-- 1. Hapus visual lama jika ada
	local oldVisual = box:FindFirstChild("Model")
	if oldVisual then
		oldVisual:Destroy()
	end

	-- 2. Clone model baru ke dalam Box
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

	-- 3. Kalkulasi tinggi & posisikan ulang model ke Handle
	local baseOffset = 0.5
	local dynamicY = baseOffset + (handle.Size.Y / 2)
	visualContainer:PivotTo(handle.CFrame * CFrame.new(0, -dynamicY + 0.5, 0))

	-- 4. Weld internal model agar part-part kecil menempel kuat
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

	-- 5. Main Weld (Model ke Handle utama)
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
local function processPickup(player: Player, box: Tool)
	if not box or box:GetAttribute("HasPicked") then
		return
	end
	box:SetAttribute("HasPicked", true)

	local handle = box:FindFirstChild("Handle") :: Part?
	local prompt = handle and handle:FindFirstChildOfClass("ProximityPrompt")

	if handle then
		handle.Anchored = false
		handle.CanCollide = false
		handle.Massless = true
	end

	if prompt then
		prompt.Enabled = false
	end

	-- 🚀 LOGIKA PENTING: RESET STATUS MESIN AGAR BISA RESPAWN ULANG
	local sourceMachine = box:FindFirstChild("SourceMachine") :: ObjectValue?
	if sourceMachine and sourceMachine.Value then
		local machineArea = sourceMachine.Value
		machineArea:SetAttribute("IsRunning", false)
		print(`[BoxManager] Box diambil! Membuka kunci status IsRunning pada {machineArea.Name}`)
	end

	local backpack = player:FindFirstChild("Backpack")
	local existingBox = backpack and backpack:FindFirstChild(box.Name)

	if existingBox then
		-- Tambah isi tumpukan (Stacking System)
		local stackFolder: Folder = existingBox:FindFirstChild("Stacks") :: Folder
			or Instance.new("Folder", existingBox)
		stackFolder.Name = "Stacks"

		local boxData = Instance.new("Configuration")
		boxData.Name = "BoxData_" .. (#stackFolder:GetChildren() + 1)

		for name, value in pairs(box:GetAttributes()) do
			boxData:SetAttribute(name, value)
		end
		boxData.Parent = stackFolder

		local currentAmount: number = existingBox:GetAttribute("Amount") :: number or 1
		existingBox:SetAttribute("Amount", currentAmount + 1)

		Debris:AddItem(box, 0.1)
	else
		box:SetAttribute("Amount", 1)
		box.Parent = backpack
	end
end

-- ==========================================
-- 2. LOGIKA GA_CHA BOX VIA NETWORKER
-- ==========================================
function BoxManager.openBox(player: Player, boxName: string)
	local backpack = player:FindFirstChild("Backpack")
	local boxInBackpack = backpack and backpack:FindFirstChild(boxName)

	if not boxInBackpack or boxInBackpack:GetAttribute("IsDestroying") then
		return { Success = false, Error = "Kotak tidak valid atau tidak ditemukan di dalam tas!" }
	end

	local currentAmount: number = boxInBackpack:GetAttribute("Amount") :: number or 1
	local boxBaseLuck = boxInBackpack:GetAttribute("LuckyChance") or 1
	local variants: string = boxInBackpack:GetAttribute("Variants") :: string or "Normal"

	local eventLuckBoost = GameConfig.CheckLuckyChanceBoost() or 0
	local playerLuckUpgrade = player:GetAttribute("Upg_LuckyChance") or 0
	local totalLuck = boxBaseLuck + eventLuckBoost + playerLuckUpgrade

	-- Roll rarity mobil dari GameConfig
	local tier = GameConfig.RollRarity(totalLuck)
	local tierData = GameConfig.Rarities[tier]

	if tier == "Admin" then
		tier = "Celestial"
		tierData = GameConfig.Rarities[tier]
	end

	-- Ambal folder penyimpanan aset mobil dari ServerStorage
	local rarityFolder = CARS_STORAGE:FindFirstChild(tier)
	if not rarityFolder or #rarityFolder:GetChildren() == 0 then
		rarityFolder = CARS_STORAGE:WaitForChild("Common")
		tier = "Common"
		tierData = GameConfig.Rarities[tier]
	end

	local carTemplates = rarityFolder:GetChildren()
	local chosenCarTemplate = carTemplates[math.random(1, #carTemplates)]
	local car = chosenCarTemplate:Clone()

	-- Pasang atribut finansial dan visual ke mobil baru
	local baseIncome = GameConfig.CalculatePrice(tierData.BasePrice, tier, variants)
	local sellPrice = math.floor(baseIncome * 0.6)

	car:SetAttribute("Income", baseIncome)
	car:SetAttribute("Price", sellPrice)
	car:SetAttribute("Variant", variants)
	car:SetAttribute("Rarity", tier)
	car:SetAttribute("Name", car.Name)
	car.Name = car.Name .. "_" .. tier .. "_" .. variants

	GameConfig.ApplyVisuals(car, tier, variants)

	-- Serahkan mobil ke inventory backpack/garasi pemain
	local existingCar = backpack and backpack:FindFirstChild(car.Name)
	if existingCar then
		local stackFolder: Folder = existingCar:FindFirstChild("Stacks") :: Folder
			or Instance.new("Folder", existingCar)
		stackFolder.Name = "Stacks"

		local carData = Instance.new("Configuration")
		carData.Name = "CarData_" .. (#stackFolder:GetChildren() + 1)
		for name, value in pairs(car:GetAttributes()) do
			carData:SetAttribute(name, value)
		end
		carData.Parent = stackFolder

		local carAmount: number = existingCar:GetAttribute("Amount") :: number or 1
		existingCar:SetAttribute("Amount", carAmount + 1)
		Debris:AddItem(car, 0.1)
	else
		car:SetAttribute("Amount", 1)
		car.Parent = backpack
	end

	-- 🟥 KONSUMSI ITEM: Update stack box atau hapus kotak jika habis
	local stackFolder = boxInBackpack:FindFirstChild("Stacks")
	if stackFolder and #stackFolder:GetChildren() > 0 then
		local allStacks = stackFolder:GetChildren()
		local nextBoxData = allStacks[1]

		-- Ambil data dari box cadangan berikutnya di bawahnya
		boxInBackpack:SetAttribute("Level", nextBoxData:GetAttribute("Level"))
		boxInBackpack:SetAttribute("Exp", nextBoxData:GetAttribute("Exp"))
		boxInBackpack:SetAttribute("Variants", nextBoxData:GetAttribute("Variants"))
		boxInBackpack:SetAttribute("Amount", currentAmount - 1)

		nextBoxData:Destroy()
	else
		boxInBackpack:SetAttribute("IsDestroying", true)
		boxInBackpack.Parent = nil
		Debris:AddItem(boxInBackpack, 0.1)
	end

	return {
		Success = true,
		Error = "",
		RewardName = car.Name,
		Message = `Berhasil membuka {boxName}! Mendapatkan mobil: {car.Name} ({tier})`,
	}
end

-- ==========================================
-- 3. SETUP INITIAL LISTENERS
-- ==========================================
local function setupBox(box: Tool)
	if not box then
		return
	end
	local handle = box:FindFirstChild("Handle") :: Part?
	local prompt = handle and handle:FindFirstChildOfClass("ProximityPrompt")

	updateBoxVisual(box)

	box.Equipped:Connect(function()
		box.Grip = CFrame.new(0, 0, 2)
	end)

	box:GetAttributeChangedSignal("Level"):Connect(function()
		updateBoxVisual(box)
	end)

	if prompt then
		prompt.Triggered:Connect(function(player)
			processPickup(player, box)
		end)
	end

	-- Pengecekan posisi box (OnHand / In Tas)
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

	-- Event Scaling Dinamis saat box ditaruh di conveyor/mesin jualan
	if handle then
		handle:GetPropertyChangedSignal("Size"):Connect(function()
			local currentModel: Model = box:FindFirstChild("Model") :: Model
			local primaryPart = currentModel and currentModel.PrimaryPart
			local machine = box.Parent :: BasePart?
			local machineArea = machine and machine.Parent :: Folder?

			if machineArea and machineArea:GetAttribute("IsRunning") == nil then
				return
			end
			if not currentModel or not primaryPart or not machine then
				return
			end

			local mainWeld: WeldConstraint = primaryPart:FindFirstChild("MainWeld") :: WeldConstraint
			if mainWeld then
				mainWeld:Destroy()
			end

			currentModel:ScaleTo(handle.Size.X / 3)

			local baseOffset = 0.5
			local dynamicY = baseOffset + (handle.Size.Y / 2)

			handle.CFrame = machine.CFrame * CFrame.new(0, dynamicY, 0)
			currentModel:PivotTo(handle.CFrame * CFrame.new(0, -dynamicY + 0.5, 0))

			mainWeld = Instance.new("WeldConstraint")
			mainWeld.Name = "MainWeld"
			mainWeld.Part0 = handle
			mainWeld.Part1 = primaryPart
			mainWeld.Parent = primaryPart
		end)
	end
end

function BoxManager.printTest(player: Player)
	print(`{player.Name} called the print test`)
end

-- ==========================================
-- 4. BOOTSTRAPPER INIT METHOD
-- ==========================================
function BoxManager.Init()
	print("[BoxManager] Mengaktifkan kernel sistem Box modern terpusat.")

	-- Jalankan server listener Networker untuk OpenBox UI Client
	-- local player = nil
	-- local boxName = nil
	-- local function tst(player: Player)
	-- 	return BoxManager.openBox(player, boxName)
	-- end
	-- Networker.server.new("OpenBox", BoxManager, { string, string })

	-- Dengarkan aset lama yang sudah ada di Workspace
	for _, tool in pairs(CollectionService:GetTagged(BOX_TAG)) do
		if tool:IsA("Tool") then
			task.spawn(setupBox, tool)
		end
	end

	-- Dengarkan aset box baru yang muncul dinamis secara runtime
	CollectionService:GetInstanceAddedSignal(BOX_TAG):Connect(function(instance)
		if instance:IsA("Tool") then
			task.spawn(setupBox, instance)
		end
	end)
end

return BoxManager

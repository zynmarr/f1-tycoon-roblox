local BoxManager = {}

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
-- local NetworkServer = game:GetService("NetworkServer")
-- local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local RoleManager = require(ServerScriptService.RoleManager.RoleManager)

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Networker = require(ReplicatedStorage.Packages.Networker)

local CARS_STORAGE = ServerStorage:WaitForChild("F1 CARS")
local BoxModels = ReplicatedStorage:WaitForChild("BoxModels")

local BOX_TAG = "Box"
local openBtn = nil

-- ========== RATE LIMITING ==========
local BOX_OPEN_COOLDOWN = 3 -- seconds
local playerBoxOpenTimes = {} -- {player: timestamp}

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
	if currentLevel <= 0 then
		warn(
			`[BoxManager] Level tidak valid (${currentLevel}) pada box ${box.Name}. Pastikan atribut "Level" sudah benar.`
		)
		return
	end

	local targetModelName = "Level" .. tostring(currentLevel)
	local newVisualTemplate = BoxModels:FindFirstChild(targetModelName)

	if not newVisualTemplate then
		warn(`[BoxManager] Model {targetModelName} tidak ditemukan di ReplicatedStorage.BoxModels!`)
		newVisualTemplate = BoxModels:FindFirstChild("Level14")
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

	if box:GetAttribute("Variants") and box:GetAttribute("Variants") ~= "" then
		local currentModel: Model = box:FindFirstChild("Model") :: Model
		local variants = box:GetAttribute("Variants") or "Normal"
		local EffectsFolder = ServerStorage:WaitForChild("VariantEffect")

		local listOfVariants = {}

		--loop string from variants" Like "Normal,Fire,Ice" to table {Normal=true, Fire=true, Ice=true}
		for variant in string.gmatch(variants, "([^,]+)") do
			listOfVariants[variant] = GameConfig.Variants[variant] or true
		end

		for _, part in pairs(currentModel:GetDescendants()) do
			if part:IsA("BasePart") then
				-- Cek apakah part memiliki efek varian yang sesuai dengan atribut Variants
				for name, value in pairs(listOfVariants) do
					if typeof(value) == "table" and value.Effect then
						local effectTemplate: ParticleEmitter =
							EffectsFolder:FindFirstChild(value.Effect) :: ParticleEmitter
						if effectTemplate then
							local newEffect = effectTemplate:Clone()
							newEffect.Parent = part
							if newEffect:IsA("ParticleEmitter") then
								newEffect.Size = NumberSequence.new(1.5, 1.5)
								newEffect.ZOffset = -1.5
								newEffect.Speed = NumberRange.new(0.5, 1)
								newEffect.Enabled = true
							end
						end
					end
				end
			end
		end
	end

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

	local backpack = player:FindFirstChild("Backpack")
	local existingBox = (backpack and backpack:FindFirstChild(box.Name))
		or (player.Character and player.Character:FindFirstChild(box.Name))

	-- ===== INVENTORY CAPACITY CHECK FOR PICKUP =====
	local inventoryCount = backpack and #backpack:GetChildren() or 0
	local maxInventorySlots = GameConfig.MaxInventorySlots or 50

	if not existingBox and inventoryCount >= maxInventorySlots then
		local NotifEvent = ReplicatedStorage:FindFirstChild("NotifEvent")
		if NotifEvent then
			NotifEvent:FireClient(
				player,
				"Tas Penuh",
				"Tas Anda sudah penuh! (" .. inventoryCount .. "/" .. maxInventorySlots .. " slot)",
				3
			)
		end
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
function BoxManager:openBox(player: Player, boxName: string)
	-- ===== RATE LIMITING CHECK =====
	local now = tick()
	local lastOpenTime = playerBoxOpenTimes[player] or 0
	local playerRole = RoleManager.getPlayerRole(player)

	-- Bypass cooldown untuk Owner, Developer, dan Moderator (Staff)
	if playerRole ~= "Owner" and playerRole ~= "Developer" and playerRole ~= "Moderator" then
		if now - lastOpenTime < BOX_OPEN_COOLDOWN then
			return {
				Success = false,
				Error = "Terlalu cepat membuka box! Tunggu "
					.. math.ceil(BOX_OPEN_COOLDOWN - (now - lastOpenTime))
					.. " detik.",
			}
		end
	end
	playerBoxOpenTimes[player] = now

	-- ===== ANTI-CHEAT: Type Validation =====
	if not boxName or type(boxName) ~= "string" then
		return { Success = false, Error = "Parameter tidak valid" }
	end

	-- Ambil lokasi karakter untuk mengecek barang yang sedang dipegang
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")

	-- 1. Cari box yang sedang dipegang (di dalam Character) atau di dalam Backpack
	local boxInHand = character and character:FindFirstChild(boxName) :: Tool?
	local boxInBackpack = backpack and backpack:FindFirstChild(boxName) :: Tool?

	-- Tentukan box mana yang valid digunakan (utamakan yang di tangan)
	local targetBox = boxInHand or boxInBackpack

	-- ===== ANTI-CHEAT: Validasi Type Box =====
	if targetBox and targetBox:GetAttribute("Type") ~= "Box" then
		return {
			Success = false,
			Error = "Item ini bukan kotak yang bisa dibuka!",
		}
	end

	-- Validasi keberadaan box
	if not targetBox or targetBox:GetAttribute("IsDestroying") then
		return {
			Success = false,
			Error = "Kotak tidak sedang dipegang atau tidak ditemukan di dalam tas!",
		}
	end

	-- Pastikan backpack tetap ada untuk menaruh mobil reward nanti
	if not backpack then
		return {
			Success = false,
			Error = "Gagal memproses, data tas (Backpack) tidak ditemukan!",
		}
	end

	-- ===== INVENTORY CAPACITY CHECK =====
	local inventoryCount = #backpack:GetChildren()
	local maxInventorySlots = GameConfig.MaxInventorySlots or 50
	if inventoryCount >= maxInventorySlots then
		return {
			Success = false,
			Error = "Tas Anda sudah penuh! (" .. inventoryCount .. "/" .. maxInventorySlots .. " slot)",
		}
	end

	local currentAmount: number = targetBox:GetAttribute("Amount") :: number or 1
	local boxBaseLuck = targetBox:GetAttribute("LuckyChance") or 1
	local variants: string = targetBox:GetAttribute("Variants") :: string or "Normal"

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

	-- Ambil folder penyimpanan aset mobil dari ServerStorage
	local rarityFolder = CARS_STORAGE:FindFirstChild(tier)
	if not rarityFolder or #rarityFolder:GetChildren() == 0 then
		rarityFolder = CARS_STORAGE:WaitForChild("Common")
		tier = "Common"
		tierData = GameConfig.Rarities[tier]
	end

	local carTemplates = rarityFolder:GetChildren()
	local chosenCarTemplate = carTemplates[math.random(1, #carTemplates)]
	local car = chosenCarTemplate:Clone()
	CollectionService:AddTag(car, "Car")

	-- Pasang atribut finansial dan visual ke mobil baru
	local baseIncome = GameConfig.CalculatePrice(tierData.BasePrice, tier, variants)
	local sellPrice = math.floor(baseIncome * 0.6)

	car:SetAttribute("Income", baseIncome)
	car:SetAttribute("Price", sellPrice)
	car:SetAttribute("Variant", variants)
	car:SetAttribute("Rarity", tier)
	car:SetAttribute("Name", car.Name)
	car:SetAttribute("Type", "Car")
	car.Name = car.Name .. "_" .. tier .. "_" .. variants

	GameConfig.ApplyVisuals(car, tier, variants)

	-- Serahkan mobil ke inventory backpack/garasi pemain
	local existingCar = backpack:FindFirstChild(car.Name)
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
	local stackFolder = targetBox:FindFirstChild("Stacks")
	if stackFolder and #stackFolder:GetChildren() > 0 then
		local allStacks = stackFolder:GetChildren()
		local nextBoxData = allStacks[1]

		-- Ambil data dari box cadangan berikutnya di bawahnya
		targetBox:SetAttribute("Level", nextBoxData:GetAttribute("Level"))
		targetBox:SetAttribute("Exp", nextBoxData:GetAttribute("Exp"))
		targetBox:SetAttribute("Variants", nextBoxData:GetAttribute("Variants"))
		targetBox:SetAttribute("Amount", currentAmount - 1)

		nextBoxData:Destroy()
	else
		targetBox:SetAttribute("IsDestroying", true)
		targetBox.Parent = nil
		Debris:AddItem(targetBox, 0.1)
	end

	local RebirthManager = require(game.ServerScriptService.RebirthManager.RebirthManager)
	RebirthManager.incrementQuestProgress(player, "OpenBoxes", 1)

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

	-- Store connections for cleanup
	local connections = {}

	box.Equipped:Connect(function()
		local character = box.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		--if not box:GetAttribute("HasPicked") then
		--	processPickup(player)
		--end

		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then
			return
		end

		local ui = playerGui:FindFirstChild("OpenBoxGui")
		openBtn = ui and ui:FindFirstChild("OpenBtn")

		if openBtn then
			openBtn.Visible = true
		end
		local boxSize = handle.Size or Vector3.new(1, 1, 1)
		box.Grip = CFrame.new(0, 0, boxSize.Z / 2 + 0.5)
	end)

	box.Unequipped:Connect(function()
		if openBtn then
			openBtn.Visible = false
		end
		--if buttonConnection then
		--	buttonConnection:Disconnect()
		--	buttonConnection = nil
		--end
	end)

	table.insert(
		connections,
		box:GetAttributeChangedSignal("Level"):Connect(function()
			updateBoxVisual(box)
		end)
	)

	if prompt then
		table.insert(
			connections,
			prompt.Triggered:Connect(function(player)
				processPickup(player, box)
			end)
		)
	end

	-- Pengecekan posisi box (OnHand / In Tas)
	table.insert(
		connections,
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
	)

	-- Event Scaling Dinamis saat box ditaruh di conveyor/mesin jualan
	if handle then
		table.insert(
			connections,
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
		)

		-- handle:GetAttributeChangedSignal("Variants"):Connect(function()

		-- end)
	end

	-- Cleanup all connections when box is destroyed
	local cleanupConnection
	cleanupConnection = box.AncestryChanged:Connect(function(_, parent)
		if not parent then
			for _, conn in ipairs(connections) do
				pcall(function()
					conn:Disconnect()
				end)
			end
			if cleanupConnection then
				cleanupConnection:Disconnect()
			end
		end
	end)
	table.insert(connections, cleanupConnection)
end

function BoxManager:printTest(player: Player, text: string)
	print(`[Server Test] {tostring(text)} is called in event by {player.Name}`)
end

-- ==========================================
-- 4. BOOTSTRAPPER INIT METHOD
-- ==========================================
function BoxManager.Init()
	print("[BoxManager] Mengaktifkan kernel sistem Box modern terpusat.")

	-- Cleanup rate limiting when player leaves
	local Players = game:GetService("Players")
	Players.PlayerRemoving:Connect(function(player)
		playerBoxOpenTimes[player] = nil
	end)

	Networker.server.new("OpenBox", BoxManager, {
		BoxManager.openBox,
	})

	print("[BoxManager] ✅ Networker 'OpenBox' endpoint siap mendengarkan dari client")

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

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameUtils = require(ReplicatedStorage.GameUtils)
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local boxTemplate = game:GetService("ServerStorage"):WaitForChild("Box")

local DataManager = require(script.Parent.Parent.DataManager.DataManager)
local Networker = require(ReplicatedStorage.Packages.Networker)

local SPAWNER_TAG = "SpawnerMachine"

local SpawnerBoxManager = {}

export type boardManagement = {
	area: BasePart,
	surface: SurfaceGui,
	list: Frame,
	itemTemplate: Frame,
}

local listOfBoards: { [Instance]: boardManagement } = {}
setmetatable(listOfBoards, { __mode = "k" })

local machineComponentsCache = {} -- Cache untuk menyimpan machinePart dan billboardModel agar tidak dicari terus-menerus
setmetatable(machineComponentsCache, { __mode = "k" })

local function getMachineComponents(machineArea: Instance)
	local cached = machineComponentsCache[machineArea]
	if cached then
		return cached.machinePart, cached.billboardModel
	end

	local machinePart = nil
	local billboardModel = nil

	for _, child in ipairs(machineArea:GetChildren()) do
		-- Cari spesifik Part yang berakhiran "Machine" (contoh: AtlantisMachine, OlympusMachine)
		if child:IsA("BasePart") and string.find(child.Name, "Machine") then
			machinePart = child
		-- Cari spesifik Model/Part untuk Billboard
		elseif child:IsA("Model") and string.find(child.Name, "Billboard") then
			if child:FindFirstChild("Area") or child:FindFirstChildOfClass("ModuleScript") then
				billboardModel = child
			else
				billboardModel = child:FindFirstChildOfClass("Model") or child
			end
		end
	end

	machineComponentsCache[machineArea] = {
		machinePart = machinePart,
		billboardModel = billboardModel,
	}
	-- warn(
	-- 	`[SpawnerBoxManager] getMachineComponents: Caching components for {machineArea.Name} | MachinePart: {tostring(
	-- 		machinePart
	-- 	)} | BillboardModel: {tostring(billboardModel)}`
	-- )

	return machinePart, billboardModel
end

-- ==========================================
-- 1. UTILITY: FIND PLOT OWNER (OPTIMIZED - DIRECT LOOKUP)
-- ==========================================
-- ( getPlotOwner dihapus karena kita sekarang mendeteksi langsung lewat plotModel )

local function spawnBox(player: Player, machineArea: Folder, boxData)
	if not player or not player.Parent then
		return
	end
	if machineArea:GetAttribute("IsRunning") then
		return
	end

	machineArea:SetAttribute("IsRunning", true)

	-- 1. Bedah folder area mesinnya
	local machinePart, _ = getMachineComponents(machineArea)
	assert(machinePart, "[SpawnerBoxManager] ERROR: Mesin fisik (Part) tidak ditemukan di dalam " .. machineArea.Name)

	local machinesFolder = machineArea.Parent
	local plotModel = machinesFolder and machinesFolder.Parent
	if not plotModel then
		machineArea:SetAttribute("IsRunning", false)
		return
	end

	local newBox = boxTemplate:Clone()
	local BoxModule = require(newBox.BoxModule) -- Ambil dari hasil clone agar lebih aman

	-- 1. INITIAL ATTRIBUTES
	local bLvl = 1
	local bExp = 0
	local bVariants = "Normal"
	if boxData then
		bLvl = boxData.Level or 1
		bExp = boxData.Exp or 0
		bVariants = boxData.Variants or "Normal"
	end

	local globalVariantBoost = GameConfig.CheckVariantBoost() or 0
	local allUpgrade = machineArea:GetAttribute("Upg_VariantChance_All")
		or machineArea:GetAttribute("Upg_VariantChance")
		or 0
	local activeVariants = {}

	-- Roll variants dynamically each time to ensure correct gacha randomness
	for vName, vData in pairs(GameConfig.Variants) do
		if vName ~= "Normal" then
			local specUpgrade = machineArea:GetAttribute("Upg_VariantChance_" .. vName) or 0
			local totalChance = vData.Chance + specUpgrade + allUpgrade + globalVariantBoost

			-- MENGGUNAKAN LOGIKA RANDOM YANG LEBIH PRESISI UNTUK DESIMAL
			local rng = math.random() * 100

			if rng <= totalChance then
				table.insert(activeVariants, vName)
			end
		end
	end

	if #activeVariants == 0 then
		table.insert(activeVariants, "Normal")
	end
	bVariants = table.concat(activeVariants, ",") -- Format: "Golden,Galaxy"

	newBox:SetAttribute("Owner", player.Name)
	newBox:SetAttribute("HasPicked", false)
	newBox:SetAttribute("Level", bLvl)
	newBox:SetAttribute("Exp", bExp)
	newBox:SetAttribute("Variants", bVariants)
	newBox:SetAttribute("Type", "Box")

	-- 2. INITIAL METADATA (Penting agar Level 1 langsung muncul)
	local initialLvlData = GameConfig.BoxLevels[bLvl]
	newBox:SetAttribute("MaxExp", initialLvlData.MaxExp)
	newBox:SetAttribute("Name", initialLvlData.Name) -- Memicu AttributeChanged pertama kali
	newBox:SetAttribute("LuckyChance", initialLvlData.LuckMulti)

	newBox.Name = initialLvlData.Name .. "_Variant_" .. bVariants

	local baseOffset = 0.5
	local dynamicY = baseOffset + (newBox.Handle.Size.Y / 2)
	newBox:PivotTo(machinePart.CFrame * CFrame.new(0, -dynamicY + 2, 0))
	newBox.Parent = workspace

	newBox:SetAttribute("MachineSource", machineArea.Name)

	-- Tautkan SourceMachine ObjectValue agar BoxManager bisa membuka kunci IsRunning secara instan saat diambil
	local sourceMachineVal = Instance.new("ObjectValue")
	sourceMachineVal.Name = "SourceMachine"
	sourceMachineVal.Value = machineArea
	sourceMachineVal.Parent = newBox

	-- 3. SETUP UI & PROMPT SEBELUM PARENTING
	newBox.Handle.Size = Vector3.new(2, 2, 2)
	local display = newBox.Handle:FindFirstChild("StatsDisplay")
	if not display then
		display = newBox:FindFirstChild("BoxModule"):FindFirstChild("StatsDisplay"):Clone()
		display.Parent = newBox.Handle
	end
	display.Enabled = true
	newBox.Handle:FindFirstChild("ProximityPrompt").Enabled = true

	-- Tampilkan teks awal untuk Level 1
	BoxModule.UpdateBoxText(newBox.Handle, bLvl, bExp, initialLvlData.MaxExp, bVariants)

	newBox.Parent = machinePart

	-- 4. GROWTH LOOP (OPTIMIZED)
	task.spawn(function()
		local lastSteppedRatio = -1 -- Cache untuk menghindari update fisik (Size & CFrame) berulang-ulang

		while newBox and newBox.Parent == machinePart and not newBox:GetAttribute("HasPicked") do
			local speed = machineArea:GetAttribute("Upg_SpeedExpBox") or 0
			local expBoost = machineArea:GetAttribute("Upg_ExpAmountBox") or 0
			local eventBoostPercent = GameConfig.CheckExpBoost()

			local baseExp = 20 + expBoost
			local totalMultiplier = eventBoostPercent / 100
			local finalExp = math.floor(baseExp + (baseExp * totalMultiplier))

			task.wait(math.max(0.1, 2 / (1 + (speed * 0.15))))

			if not newBox:FindFirstChild("Handle") then
				break
			end
			if not newBox or newBox.Parent ~= machinePart or newBox:GetAttribute("HasPicked") then
				break
			end

			local curLvl = newBox:GetAttribute("Level") or 1
			local curExp = newBox:GetAttribute("Exp") or 0
			local totalExpPool = curExp + finalExp

			local maxLevel = 30

			-- ==========================================
			-- LOGIKA MELOMPAT LEVEL (LOOPING EXP)
			-- ==========================================
			local levelChanged = false
			while true do
				local lvlData = GameConfig.BoxLevels[curLvl]
				if not lvlData then
					break
				end

				-- Jika Exp cukup untuk naik level DAN belum mencapai max level
				if totalExpPool >= lvlData.MaxExp and curLvl < maxLevel then
					totalExpPool -= lvlData.MaxExp
					curLvl += 1
					levelChanged = true
				else
					break
				end
			end

			-- Terapkan perubahan level jika ada
			if levelChanged then
				local newLvlData = GameConfig.BoxLevels[curLvl]
				newBox:SetAttribute("Level", curLvl)
				newBox:SetAttribute("MaxExp", newLvlData.MaxExp)
				newBox:SetAttribute("Name", newLvlData.Name)
				newBox.Name = newLvlData.Name .. "_Variant_" .. bVariants
			end

			-- ==========================================
			-- PENANGANAN EXP SAAT LEVEL MAX
			-- ==========================================
			local currentLvlData = GameConfig.BoxLevels[curLvl]
			local newExp = totalExpPool

			if curLvl >= maxLevel then
				newExp = currentLvlData.MaxExp
			end

			newBox:SetAttribute("Exp", newExp)

			-- ==========================================
			-- UPDATE VISUAL (SIZE & POSITION) - OPTIMIZED
			-- ==========================================
			local rawGrowthRatio = math.clamp(newExp / currentLvlData.MaxExp, 0, 1)
			local totalSteps = 4
			local steppedGrowthRatio = math.floor(rawGrowthRatio * totalSteps) / totalSteps

			-- Hanya perbarui properti Part (Size & CFrame) jika step pertumbuhan berubah (hanya 5 kali per lifetime)
			if steppedGrowthRatio ~= lastSteppedRatio then
				lastSteppedRatio = steppedGrowthRatio
				local startSize = Vector3.new(2, 2, 2)
				local targetSize = Vector3.new(5, 5, 5)
				local newSize = startSize:Lerp(targetSize, steppedGrowthRatio)

				newBox.Handle.Size = newSize
				local offsetInput = (machinePart.Size.Y / 2) + (newSize.Y / 2)
				newBox.Handle.CFrame = machinePart.CFrame * CFrame.new(0, offsetInput, 0)
			end

			-- ==========================================
			-- UPDATE VISUAL TEXT (OPTIMIZED - DIRECT CALL PER TICK)
			-- ==========================================
			-- Menghilangkan listener AttributeChanged dan meng-update langsung agar menghemat CPU & replikasi
			BoxModule.UpdateBoxText(newBox.Handle, curLvl, newExp, currentLvlData.MaxExp, bVariants)
		end

		-- Reset State untuk Respawn jika tidak ada box aktif lain
		local activeBox = machinePart:FindFirstChildOfClass("Tool")
		if not activeBox or activeBox == newBox then
			machineArea:SetAttribute("IsRunning", false)
			task.wait(0.2)

			local ownerName = plotModel:GetAttribute("Owner")
			if ownerName and ownerName == player.Name then
				pcall(function()
					spawnBox(player, machineArea, nil)
				end)
			else
				warn("PLAYER NO LONGER OWNER, SKIPPING RESPAWN")
			end
		else
			warn("ANOTHER ACTIVE BOX ALREADY SPAWNED, SKIPPING RESPAWN")
		end
	end)
end

-- ==========================================
-- 2. CORE LOGIC: INITIALIZE MACHINE
-- ==========================================
local function setupMachineArea(machineArea: Folder)
	if machineArea:GetAttribute("IsInitialized") then
		return
	end
	machineArea:SetAttribute("IsInitialized", true)
	local _, billboardModel = getMachineComponents(machineArea)

	local boardArea = billboardModel and billboardModel:FindFirstChild("Area")
	local boardSurface = boardArea and boardArea:FindFirstChild("SurfaceGui")
	local boardList = boardSurface and boardSurface:FindFirstChild("List")
	local boardItemTemplate = boardList and boardList:FindFirstChild("Item")

	listOfBoards[machineArea] = {
		area = boardArea,
		surface = boardSurface,
		list = boardList,
		itemTemplate = boardItemTemplate,
	}

	local board = listOfBoards[machineArea]

	-- Function to start the actual spawner logic
	local function startLogic(player, plot)
		if machineArea:GetAttribute("Active") then
			return
		end
		machineArea:SetAttribute("Active", true)

		if not player:GetAttribute("DataLoaded") then
			player:GetAttributeChangedSignal("DataLoaded"):Wait()
		end

		local machineData = nil
		local loadedData = DataManager.getPlayerData(player)

		if loadedData and loadedData.PlotData and loadedData.PlotData.Machines then
			machineData = loadedData.PlotData.Machines[machineArea.Name]

			if machineData then
				for name, value in pairs(machineData.Attributes) do
					if name ~= "IsRunning" and name ~= "Active" and name ~= "IsInitialized" then
						machineArea:SetAttribute(name, value)
					end
				end

				-- Handle UI Billboard
				if billboardModel then
					for name, _ in pairs(machineArea:GetAttributes()) do
						local item = board.list:FindFirstChild(name)
						if item then
							item:Destroy()
						end
					end
				end
			end
		end

		-- Logic Loop
		task.spawn(function()
			while machineArea:GetAttribute("Active") do
				local currentOwner = plot:GetAttribute("Owner")
				if not player or not player.Parent or currentOwner ~= player.Name then
					machineArea:SetAttribute("Active", false)
					break
				end

				if not machineArea:GetAttribute("IsRunning") then
					if machineData and machineData.ActiveBox then
						spawnBox(player, machineArea, machineData.ActiveBox)
						machineData.ActiveBox = nil
					else
						spawnBox(player, machineArea, nil)
					end
				end

				task.wait(1) -- Cooldown
			end
		end)
	end

	-- Check for owner immediately or wait for attribute change
	local machinesFolder: Folder = machineArea.Parent :: Folder
	if not machinesFolder then
		return
	end
	local plotModel: Folder = machinesFolder.Parent :: Folder
	if plotModel then
		plotModel:GetAttributeChangedSignal("Owner"):Connect(function()
			local ownerName = plotModel:GetAttribute("Owner")
			local player = ownerName and ownerName ~= "" and Players:FindFirstChild(ownerName)
			if player then
				startLogic(player, plotModel)
			end
		end)

		-- Immediate check in case owner is already set
		local ownerName = plotModel:GetAttribute("Owner")
		local player = ownerName and ownerName ~= "" and Players:FindFirstChild(ownerName)
		if player then
			startLogic(player, plotModel)
		end
	end

	if billboardModel then
		local upgradeList = UpgradeConfig.getUpgradesForArea(machineArea.Name)

		for _, v in pairs(upgradeList) do
			local attrName = v.ID

			-- Buat UI untuk setiap upgrade
			if board.list and board.itemTemplate then
				local newItem = board.itemTemplate:Clone()
				local title: TextLabel = newItem:FindFirstChild("Name") :: TextLabel
				local button: TextButton = newItem:FindFirstChild("Button") :: TextButton
				newItem.Visible = true
				newItem.Name = attrName
				title.Text = tostring(v.Title)
				button.Text = "$ " .. GameUtils.formatCompact(v.BasePrice)
				newItem.Parent = board.list
			end
		end
		if board.itemTemplate then
			board.itemTemplate:Destroy()
		end

		local upgradeLookup = {}
		for _, v in pairs(upgradeList) do
			upgradeLookup[v.ID] = true
		end

		local isUpdatingAttributes = false -- Flag untuk memblokir event cascade loop
		machineArea.AttributeChanged:Connect(function(attributeName)
			if isUpdatingAttributes then
				return
			end
			-- Hanya bereaksi jika atribut yang berubah adalah salah satu upgrade yang dibeli player
			if not upgradeLookup[attributeName] then
				return
			end

			isUpdatingAttributes = true

			-- RESET nilai ke 0 sebelum kalkulasi ulang
			local newSpeed = 0
			local newExp = 0
			local variantUpgrades = {} -- { [string]: number }

			-- Loop SEMUA upgrade yang ada di UpgradeConfig
			for _, v in pairs(upgradeList) do
				if machineArea:GetAttribute(v.ID) then
					local parts = string.split(v.ID, "_")
					local category = parts[1]

					if category == "SpeedExpBox" then
						newSpeed = newSpeed + v.Value
					elseif category == "ExpAmountBox" then
						newExp = newExp + v.Value
					elseif category == "VariantChance" then
						local variantType = parts[2] or "All"
						variantUpgrades[variantType] = (variantUpgrades[variantType] or 0) + v.Value
					end
				end
			end

			-- Update atribut hanya jika nilainya berubah
			if machineArea:GetAttribute("Upg_SpeedExpBox") ~= newSpeed then
				machineArea:SetAttribute("Upg_SpeedExpBox", newSpeed)
			end
			if machineArea:GetAttribute("Upg_ExpAmountBox") ~= newExp then
				machineArea:SetAttribute("Upg_ExpAmountBox", newExp)
			end

			-- Bersihkan/reset variant chance lama
			for name, _ in pairs(machineArea:GetAttributes()) do
				if string.find(name, "^Upg_VariantChance_") then
					machineArea:SetAttribute(name, nil)
				end
			end

			-- Terapkan nilai upgrade baru yang aktif
			for variantType, val in pairs(variantUpgrades) do
				local attrName = "Upg_VariantChance_" .. variantType
				machineArea:SetAttribute(attrName, val)
			end

			isUpdatingAttributes = false
		end)
	end
end

-- ==========================================
-- 3. NETWORKER UPGRADE MACHINE METHOD
-- ==========================================
function SpawnerBoxManager:buyUpgrade(player, machineArea, upgradeName)
	print(
		"[SpawnerBoxManager:buyUpgrade] Request by:",
		player and player.Name,
		"| Area:",
		machineArea and machineArea.Name,
		"| Upgrade:",
		upgradeName
	)
	if not player or not machineArea or not upgradeName then
		return { Success = false, Error = "Parameter tidak lengkap" }
	end

	-- 1. Validasi kepemilikan plot
	local machinesFolder = machineArea.Parent
	local plotModel = machinesFolder and machinesFolder.Parent
	local owner = plotModel and plotModel:GetAttribute("Owner")
	print("[SpawnerBoxManager:buyUpgrade] Plot Owner:", owner, "| Player Name:", player.Name)
	if owner ~= player.Name then
		return { Success = false, Error = "Anda bukan pemilik plot ini! (Owner: " .. tostring(owner) .. ")" }
	end

	-- 2. Cari billboard dan data upgrade
	local _, billboardGui = getMachineComponents(machineArea)
	if not billboardGui then
		print("[SpawnerBoxManager:buyUpgrade] Billboard not found for:", machineArea.Name)
		return { Success = false, Error = "Billboard mesin tidak ditemukan" }
	end

	local upgrades = UpgradeConfig.getUpgradesForArea(machineArea.Name)
	local upgradeItem = nil
	for _, v in ipairs(upgrades) do
		if v.ID == upgradeName then
			upgradeItem = v
			break
		end
	end

	if not upgradeItem then
		print("[SpawnerBoxManager:buyUpgrade] Upgrade item not found in UpgradeConfig for ID:", upgradeName)
		return { Success = false, Error = "Upgrade tidak valid untuk mesin ini" }
	end

	-- 3. Cek apakah sudah dibeli sebelumnya
	if machineArea:GetAttribute(upgradeName) then
		print("[SpawnerBoxManager:buyUpgrade] Already purchased:", upgradeName)
		return { Success = false, Error = "Upgrade ini sudah dibeli!" }
	end

	-- 4. Validasi Cash
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash then
		print("[SpawnerBoxManager:buyUpgrade] Leaderstats Cash not found")
		return { Success = false, Error = "Data uang tidak ditemukan" }
	end

	local cost = upgradeItem.BasePrice or 0
	print("[SpawnerBoxManager:buyUpgrade] Player Cash:", cash.Value, "| Upgrade Cost:", cost)
	if cash.Value < cost then
		return { Success = false, Error = "Uang Anda tidak cukup!" }
	end

	-- 5. Eksekusi Pembelian
	cash.Value = cash.Value - cost
	machineArea:SetAttribute(upgradeName, true)

	-- 6. Hapus UI upgrade di billboard dari server agar sinkron untuk semua player
	local billArea = billboardGui:FindFirstChild("Area")
	local surface = billArea and billArea:FindFirstChild("SurfaceGui")
	local list = surface and surface:FindFirstChild("List")
	local itemUI = list and list:FindFirstChild(upgradeName)
	if itemUI then
		itemUI:Destroy()
	end

	print("[SpawnerBoxManager] " .. player.Name .. " membeli upgrade " .. upgradeName .. " seharga $" .. cost)
	return { Success = true, Message = "Upgrade berhasil!" }
end

-- ==========================================
-- 4. COLLECTION SERVICE LISTENERS
-- ==========================================
function SpawnerBoxManager.Init()
	-- Initialize existing machines
	for _, machineArea in pairs(CollectionService:GetTagged(SPAWNER_TAG)) do
		task.spawn(setupMachineArea, machineArea)
	end

	-- Initialize new machines added later (bought from tycoon)
	CollectionService:GetInstanceAddedSignal(SPAWNER_TAG):Connect(setupMachineArea)

	-- Register Networker UpgradeMachine
	Networker.server.new("UpgradeMachine", SpawnerBoxManager, {
		SpawnerBoxManager.buyUpgrade,
	})
end

return SpawnerBoxManager

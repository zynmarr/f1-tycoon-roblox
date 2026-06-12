local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local boxTemplate = game:GetService("ServerStorage"):WaitForChild("Box")

local DataManager = require(script.Parent.Parent.DataManager.DataManager)

local SPAWNER_TAG = "SpawnerMachine"

local SpawnerBoxManager = {}

local function getMachineComponents(machineArea: Instance)
	local machinePart = nil
	local billboardModel = nil

	for _, child in pairs(machineArea:GetChildren()) do
		print(child.Name)
		-- Cari spesifik Part yang berakhiran "Machine" (contoh: AtlantisMachine, OlympusMachine)
		if child:IsA("BasePart") and string.find(child.Name, "Machine") then
			machinePart = child
		-- Cari spesifik Model/Part untuk Billboard
		elseif child:IsA("Model") and string.find(child.Name, "Billboard") then
			print("Billboard found: " .. child.Name)
			if child:FindFirstChild("Area") or child:FindFirstChildOfClass("ModuleScript") then
				billboardModel = child
			else
				billboardModel = child:FindFirstChildOfClass("Model") or child
			end
		end
	end

	return machinePart, billboardModel
end

-- ==========================================
-- 1. UTILITY: FIND PLOT OWNER
-- ==========================================
local function getPlotOwner(instance)
	-- Mencari ke atas sampai ketemu model yang punya atribut "Owner"
	local current = instance
	while current and current ~= workspace do
		if current:GetAttribute("Owner") ~= nil then
			local ownerName = current:GetAttribute("Owner")
			if ownerName ~= "" then
				return Players:FindFirstChild(ownerName), current
			end
		end
		current = current.Parent
	end
	return nil, nil
end

local function spawnBox(player: Player, machineArea: Folder, boxData)
	if not player or not player.Parent then
		return
	end
	if machineArea:GetAttribute("IsRunning") then
		print("MACHINE START RUNNING: " .. tostring(machineArea:GetAttribute("IsRunning")))
		return
	end

	machineArea:SetAttribute("IsRunning", true)

	-- 1. Bedah folder area mesinnya
	local machinePart, _ = getMachineComponents(machineArea)

	-- 2. Validasi (Jika mesin fisik tidak ketemu, hentikan agar tidak crash)
	assert(machinePart, "[SpawnerBoxManager] ERROR: Mesin fisik (Part) tidak ditemukan di dalam " .. machineArea.Name)

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
	local playerUpgrade = machinePart:GetAttribute("Upg_VariantChance") or 0
	local activeVariants = {}
	print("ACTIVE VARIANTS: ", playerUpgrade)

	-- Roll variants dynamically each time to ensure correct gacha randomness
	for vName, vData in pairs(GameConfig.Variants) do
		if vName ~= "Normal" then
			local totalChance = vData.Chance + playerUpgrade + globalVariantBoost

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

	-- 2. INITIAL METADATA (Penting agar Level 1 langsung muncul)
	local initialLvlData = GameConfig.BoxLevels[bLvl]
	newBox:SetAttribute("MaxExp", initialLvlData.MaxExp)
	newBox:SetAttribute("Name", initialLvlData.Name) -- Memicu AttributeChanged pertama kali
	newBox:SetAttribute("LuckyChance", initialLvlData.LuckMulti)

	newBox.Name = initialLvlData.Name .. "_Variant_" .. bVariants
	newBox:PivotTo(machinePart.CFrame * CFrame.new(0, 2, 0))
	newBox.Parent = workspace

	newBox:SetAttribute("MachineSource", machineArea.Name)

	-- 3. SETUP UI & PROMPT SEBELUM PARENTING
	newBox.Handle.Size = Vector3.new(3, 3, 3)
	local display = newBox.Handle:FindFirstChild("StatsDisplay")
	if not display then
		-- Ambil template display dari BoxModule atau folder yang benar
		display = newBox:FindFirstChild("BoxModule"):FindFirstChild("StatsDisplay"):Clone()
		display.Parent = newBox.Handle
	end
	display.Enabled = true
	newBox.Handle:FindFirstChild("ProximityPrompt").Enabled = true

	-- Tampilkan teks awal untuk Level 1
	BoxModule.UpdateBoxText(newBox.Handle, bLvl, bExp, initialLvlData.MaxExp, bVariants)

	newBox.Parent = machinePart

	-- 4. GROWTH LOOP
	task.spawn(function()
		while newBox and newBox.Parent == machinePart and not newBox:GetAttribute("HasPicked") do
			local speed = machinePart:GetAttribute("Upg_SpeedExpBox") or 0
			local expBoost = machinePart:GetAttribute("Upg_ExpAmountBox") or 0
			local eventBoostPercent = GameConfig.CheckExpBoost()

			local baseExp = 20 + expBoost

			local totalMultiplier = eventBoostPercent / 100
			local finalExp = math.floor(baseExp + (baseExp * totalMultiplier))
			--print("EXP FINAL: " .. finalExp .. " | Event: " .. eventBoostPercent .. "% | Upg: " .. expBoost .. "%")

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
			while true do
				local lvlData = GameConfig.BoxLevels[curLvl]
				if not lvlData then
					break
				end

				-- Jika Exp cukup untuk naik level DAN belum mencapai max level
				if totalExpPool >= lvlData.MaxExp and curLvl < maxLevel then
					totalExpPool -= lvlData.MaxExp
					curLvl += 1

					local newLvlData = GameConfig.BoxLevels[curLvl]
					newBox:SetAttribute("Level", curLvl)
					newBox:SetAttribute("MaxExp", newLvlData.MaxExp)
					newBox:SetAttribute("Name", newLvlData.Name)
					newBox.Name = newLvlData.Name .. "_Variant_" .. bVariants
				else
					-- BERHENTI LOOPING: Entah Exp habis atau sudah Level Max
					break
				end
			end

			-- ==========================================
			-- PENANGANAN EXP SAAT LEVEL MAX
			-- ==========================================
			local currentLvlData = GameConfig.BoxLevels[curLvl]
			local newExp = totalExpPool

			-- Jika sudah level max, kita batasi Exp-nya agar tidak melebihi MaxExp level tersebut
			-- (Atau biarkan saja bertambah jika kamu ingin angka Exp-nya terus naik)
			if curLvl >= maxLevel then
				-- Jika ingin visual bar/box penuh terus:
				--newExp = math.max(newExp, currentLvlData.MaxExp)
				newExp = currentLvlData.MaxExp
			end

			newBox:SetAttribute("Exp", newExp)

			-- ==========================================
			-- UPDATE VISUAL (SIZE & POSITION)
			-- ==========================================
			-- GrowthRatio 1.0 berarti box ukuran maksimal (targetSize)
			-- 1. Hitung rasio asli (dari 0.0 sampai 1.0)
			local rawGrowthRatio = math.clamp(newExp / currentLvlData.MaxExp, 0, 1)

			-- 2. Ubah rasio menjadi 4 tahap perubahan (0%, 25%, 50%, 75%, 100%)
			local totalSteps = 4
			local steppedGrowthRatio = math.floor(rawGrowthRatio * totalSteps) / totalSteps

			-- 3. Kalkulasi ukuran menggunakan rasio yang sudah bertahap
			local startSize = Vector3.new(2, 2, 2)
			local targetSize = Vector3.new(5, 5, 5)
			local newSize = startSize:Lerp(targetSize, steppedGrowthRatio)

			-- 4. Terapkan ukuran dan posisi
			newBox.Handle.Size = newSize

			local offsetInput = (machinePart.Size.Y / 2) + (newSize.Y / 2)
			newBox.Handle.CFrame = machinePart.CFrame * CFrame.new(0, offsetInput, 0)
		end

		-- Reset State for Respawn
		machineArea:SetAttribute("IsRunning", false)
		print("MACHINE HAS RUNNING HAS FALSE")

		-- Tunggu sebentar sebelum membolehkan spawn baru
		task.wait(0.2)
		-- Trigger spawn baru hanya jika pemain masih pemilik plot
		local owner, _ = getPlotOwner(machinePart)
		if owner == player then
			print("START NEW BOX")
			pcall(function()
				spawnBox(player, machineArea, nil)
			end)
		else
			print("START NEW BOX ERROR")
		end
	end)

	-- 5. LISTENER UNTUK UPDATE UI SAAT ATRIBUT BERUBAH
	newBox.AttributeChanged:Connect(function(attr)
		if attr == "Exp" or attr == "Level" or attr == "Name" or attr == "MaxExp" or attr == "Variants" then
			if not newBox or not newBox.Parent then
				return
			end

			local handle = newBox:FindFirstChild("Handle")
			if not handle then
				return
			end -- Mencegah error jika Handle sudah hilang

			local curLvl = newBox:GetAttribute("Level")
			local curExp = newBox:GetAttribute("Exp")
			local maxExp = newBox:GetAttribute("MaxExp")
			local varnt = newBox:GetAttribute("Variants")

			BoxModule.UpdateBoxText(newBox.Handle, curLvl, curExp, maxExp, varnt)
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
	local machinePart, billboardModel = getMachineComponents(machineArea)

	-- Function to start the actual spawner logic
	local function startLogic(player, plot)
		-- Asumsi 'machine' sudah dideklarasikan di luar fungsi ini
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
				-- local scopeMachine = machineArea:FindFirstChildOfClass("Part")

				-- PERBAIKAN 2: Hapus task.wait(0.5) agar pemuatan data berjalan instan tanpa lag
				--task.wait(0.5)
				for name, value in pairs(machineData.Attributes) do
					if name ~= "IsRunning" and name ~= "Active" and name ~= "IsInitialized" then
						machineArea:SetAttribute(name, value)
					end
				end

				-- Handle UI Billboard
				if billboardModel then
					local billArea = billboardModel:FindFirstChild("Area")
					if billArea then
						local surface = billArea:FindFirstChild("SurfaceGui")
						if surface then
							local list = surface:FindFirstChild("List")
							if list then
								-- Hapus elemen UI sesuai atribut
								for name, _ in pairs(machineArea:GetAttributes()) do
									local item = list:FindFirstChild(name)
									if item then
										item:Destroy()
									end
								end
							end
						end
					end
				end
			end
		end

		-- print(machineData)

		-- Logic Loop
		task.spawn(function()
			while machineArea:GetAttribute("Active") do
				-- Stop if player leaves or plot owner changes
				local currentOwner = plot:GetAttribute("Owner")
				if not player or not player.Parent or currentOwner ~= player.Name then
					machineArea:SetAttribute("Active", false)
					break
				end

				-- PERBAIKAN 3: Jangan gunakan 'return', gunakan 'if not'
				if not machineArea:GetAttribute("IsRunning") then
					print("FIRST SPAWN")
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
			local player, plot = getPlotOwner(machinePart)
			if player then
				--print("ON GET OWNER PLOT CHANGE")
				startLogic(player, plot)
			end
		end)

		-- Immediate check in case owner is already set
		local player, plot = getPlotOwner(machinePart)
		if player then
			--print("ON GET OWNER PLOT IMMEDIATE")
			startLogic(player, plot)
		end
	end

	-- local billboard = machine.Parent:FindFirstChild("Billboard")

	--print("ATTRIBUTE CHANGED: ".. attributeName)

	if billboardModel then
		local module = require(
			billboardModel:FindFirstChild("ModuleScript") or billboardModel:FindFirstChildOfClass("ModuleScript")
		)
		local area = billboardModel:FindFirstChild("Area")
		local surface = area:FindFirstChild("SurfaceGui")
		local list = surface:FindFirstChild("List")
		local itemTemplate = list:FindFirstChild("Item")
		print("MACHINE MODULE: " .. tostring(module))
		-- Variabel untuk mencegah infinite loop
		local isUpdating = false

		for _, v in pairs(module.upgradeList) do
			local attrName = v.ID
			-- machineArea:SetAttribute(attrName, machineArea:GetAttribute(attrName) or false)

			-- Buat UI untuk setiap upgrade
			if list and itemTemplate then
				print("ADDING ITEM: " .. attrName)
				local newItem = itemTemplate:Clone()
				local title: TextLabel = newItem:FindFirstChild("Name") :: TextLabel
				local button: TextButton = newItem:FindFirstChild("Button") :: TextButton
				newItem.Visible = true
				newItem.Name = attrName
				title.Text = tostring(v.Title)
				newItem.Parent = list
			end
		end
		itemTemplate:Destroy()

		machineArea.AttributeChanged:Connect(function(attributeName)
			-- Cegah update ganda & pastikan hanya bereaksi jika atribut yang berubah adalah milik upgrade
			if isUpdating then
				return
			end

			-- Jika atribut yang berubah bukan milik upgrade, abaikan
			if not string.find(attributeName, "_") then
				return
			end

			isUpdating = true

			-- RESET nilai ke 0 sebelum kalkulasi ulang
			local newSpeed = 0
			local newExp = 0
			local newVariant = 0

			-- Loop SEMUA upgrade yang ada di ModuleScript
			for _, v in pairs(module.upgradeList) do
				--local currentLevel = machine:GetAttribute(v.ID) or 0

				-- Jika level > 0, tambahkan nilainya ke total
				--if currentLevel > 0 then
				local upgradeName = string.split(v.ID, "_")[1]
				-- local currentLevel = string.split(v.ID, "_")[2]

				if upgradeName == "SpeedExpBox" and machineArea:GetAttribute(v.ID) then
					newSpeed = newSpeed + v.Value
				elseif upgradeName == "ExpAmountBox" and machineArea:GetAttribute(v.ID) then
					newExp = newExp + v.Value
				elseif upgradeName == "VariantChance" and machineArea:GetAttribute(v.ID) then
					newVariant = newVariant + v.Value
				end
			end

			-- Update atribut hanya jika nilainya benar-benar berubah (menghemat performa)
			if machineArea:GetAttribute("Upg_SpeedExpBox") ~= newSpeed then
				machineArea:SetAttribute("Upg_SpeedExpBox", newSpeed)
				print("SPEED UPGRADE: " .. newSpeed)
			end
			if machineArea:GetAttribute("Upg_ExpAmountBox") ~= newExp then
				machineArea:SetAttribute("Upg_ExpAmountBox", newExp)
				print("EXP UPGRADE: " .. newExp)
			end
			if machineArea:GetAttribute("Upg_VariantChance") ~= newVariant then
				machineArea:SetAttribute("Upg_VariantChance", newVariant)
				print("VARIANT UPGRADE: " .. newVariant)
			end

			isUpdating = false
		end)
	end
end

-- ==========================================
-- 3. COLLECTION SERVICE LISTENERS
-- ==========================================
function SpawnerBoxManager.Init()
	-- Initialize existing machines
	for _, machineArea in pairs(CollectionService:GetTagged(SPAWNER_TAG)) do
		task.spawn(setupMachineArea, machineArea)
	end

	-- Initialize new machines added later (bought from tycoon)
	CollectionService:GetInstanceAddedSignal(SPAWNER_TAG):Connect(setupMachineArea)

	-- Handle BuyUpgrade RemoteFunction
	local BuyUpgradeFunction = ReplicatedStorage:FindFirstChild("BuyUpgradeFunction")
	if BuyUpgradeFunction and BuyUpgradeFunction:IsA("RemoteFunction") then
		BuyUpgradeFunction.OnServerInvoke = function(player, machineArea, upgradeName)
			if not player or not machineArea or not upgradeName then
				return false, "Parameter tidak lengkap"
			end

			-- 1. Validasi kepemilikan plot
			local machinesFolder = machineArea.Parent
			local plotModel = machinesFolder and machinesFolder.Parent
			local owner = plotModel and plotModel:GetAttribute("Owner")
			if owner ~= player.Name then
				return false, "Anda bukan pemilik plot ini!"
			end

			-- 2. Cari billboard dan modul upgrade
			local machinePart, billboardGui = getMachineComponents(machineArea)
			if not billboardGui then
				return false, "Billboard mesin tidak ditemukan"
			end

			local moduleScript = billboardGui:FindFirstChild("ModuleScript") or billboardGui:FindFirstChildOfClass("ModuleScript")
			if not moduleScript then
				return false, "Modul upgrade tidak ditemukan"
			end

			local module = require(moduleScript)
			local upgradeItem = nil
			for _, v in ipairs(module.upgradeList) do
				if v.ID == upgradeName then
					upgradeItem = v
					break
				end
			end

			if not upgradeItem then
				return false, "Upgrade tidak valid untuk mesin ini"
			end

			-- 3. Cek apakah sudah dibeli sebelumnya
			if machineArea:GetAttribute(upgradeName) then
				return false, "Upgrade ini sudah dibeli!"
			end

			-- 4. Validasi Cash
			local leaderstats = player:FindFirstChild("leaderstats")
			local cash = leaderstats and leaderstats:FindFirstChild("Cash")
			if not cash then
				return false, "Data uang tidak ditemukan"
			end

			local cost = upgradeItem.BasePrice or 0
			if cash.Value < cost then
				return false, "Uang Anda tidak cukup!"
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
			return true, "Upgrade berhasil!"
		end
	end
end

return SpawnerBoxManager

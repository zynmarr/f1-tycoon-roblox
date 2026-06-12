local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local function safeRequire(modulePath, moduleName)
	local success, result = pcall(require, modulePath)
	if not success then
		error("[MainServer] Gagal load module " .. moduleName .. ": " .. tostring(result))
	end
	return result
end

local PlotManager = safeRequire(script.Parent.PlotManager.PlotManager, "PlotManager")
local DataManager = safeRequire(script.Parent.DataManager.DataManager, "DataManager")
local CarManager = safeRequire(game.ServerScriptService.CarManager.CarManager, "CarManager")
local SpawnerBoxManager = safeRequire(game.ServerScriptService.SpawnerBoxManager.SpawnerBoxManager, "SpawnerBoxManager")
local BoxManager = safeRequire(game.ServerScriptService.BoxManager.BoxManager, "BoxManager")
local RoleManager = safeRequire(script.Parent.RoleManager.RoleManager, "RoleManager")
-- local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig"))

-- ==========================================================
-- [1] FUNGSI UTILITY (LOAD ITEMS TO BACKPACK)
-- ==========================================================
local function loadInventoryItem(player: Player, itemData)
	local backpack = player:WaitForChild("Backpack")
	local boxTemplate = ServerStorage:WaitForChild("Box", 5)
	if not boxTemplate then
		return
	end

	local existingItem = backpack:FindFirstChild(itemData.Name)

	if existingItem then
		local currentAmount = existingItem:GetAttribute("Amount") :: number? or 1
		local additionalAmount = 1 + (itemData.Stacks and #itemData.Stacks or 0)
		existingItem:SetAttribute("Amount", currentAmount + additionalAmount)

		local stackFolder = existingItem:FindFirstChild("Stacks")
		if stackFolder then
			-- Tambahkan item utama ke stacks
			local boxData = Instance.new("Configuration")
			boxData.Name = "BoxData_" .. (#stackFolder:GetChildren() + 1)
			for name, value in pairs(itemData.Attributes) do
				if name ~= "IsRunning" and name ~= "Active" and name ~= "IsInitialized" then
					boxData:SetAttribute(name, value)
				end
			end
			boxData.Parent = stackFolder

			-- Tambahkan semua sub-stacks ke stacks
			if itemData.Stacks then
				for _, stackAttr in pairs(itemData.Stacks) do
					local subBoxData = Instance.new("Configuration")
					subBoxData.Name = "BoxData_" .. (#stackFolder:GetChildren() + 1)
					for name, value in pairs(stackAttr) do
						subBoxData:SetAttribute(name, value)
					end
					subBoxData.Parent = stackFolder
				end
			end
		end
	else
		local box = boxTemplate:Clone()
		local BoxModule = require(box.BoxModule)
		for key, value in pairs(itemData.Attributes) do
			box:SetAttribute(key, value)
		end
		box.Name = itemData.Name

		local handle = box:FindFirstChild("Handle") :: Part?
		if handle then
			handle.Anchored = false
			handle.CanCollide = false
			handle.Massless = true
		end

		box:SetAttribute("HasPicked", false)
		box:SetAttribute("IsInitialized", true)
		box:SetAttribute("Amount", 1)

		local stackFolder = Instance.new("Folder")
		stackFolder.Name = "Stacks"
		stackFolder.Parent = box

		if itemData.Stacks then
			for i, stackAttr in pairs(itemData.Stacks) do
				local boxData = Instance.new("Configuration")
				boxData.Name = "BoxData_" .. i
				for name, value in pairs(stackAttr) do
					boxData:SetAttribute(name, value)
				end
				boxData.Parent = stackFolder
			end
			box:SetAttribute("Amount", 1 + #itemData.Stacks)
		end
		local display = box.Handle.StatsDisplay
		if display then
			display.Enabled = true
		end

		local proximityPrompt = box.Handle.ProximityPrompt
		if proximityPrompt then
			proximityPrompt.Enabled = false
		end

		BoxModule.UpdateBoxText(
			box.Handle,
			box:GetAttribute("Level"),
			box:GetAttribute("Exp"),
			box:GetAttribute("MaxExp"),
			box:GetAttribute("Variants")
		)

		box.Parent = backpack
	end
end

-- ==========================================================
-- [2] LOGIKA UTAMA SINKRONISASI PLOT & DATA
-- ==========================================================
local function setupPlayerSkinsAndAssets(player: Player, data: any, myPlot: Instance)
	if data.PlotData and data.PlotData.MyCars then
		for _, carData in pairs(data.PlotData.MyCars) do
			pcall(function()
				CarManager.spawnLoadedCar(player, carData, myPlot)
			end)
		end
	end

	if data.Inventory then
		for _, item in pairs(data.Inventory) do
			if item.Attributes.Type == "Box" then
				pcall(function()
					loadInventoryItem(player, item)
				end)
			else
				pcall(function()
					CarManager.spawnLoadedCar(player, item, myPlot)
				end)
			end

			-- if item.Location == "Backpack" or item.Location == "Character" then
			-- 	loadInventoryItem(player, item)
			-- else
			-- 	pcall(function()
			-- 		CarManager.spawnLoadedCar(player, item, myPlot)
			-- 	end)
			-- end
		end
	end
end

-- ==========================================================
-- [3] PLAYER LIFE-CYCLE LISTENERS
-- ==========================================================
local function onPlayerAdded(player: Player)
	print(`[MainServer] Memproses pemain baru: {player.Name}`)

	local data = DataManager.loadData(player)
	if not data then
		player:Kick("Gagal memuat data profile Anda secara aman. Silakan masuk kembali.")
		return
	end

	local myPlot = PlotManager.claimPlot(player)
	if not myPlot then
		player:Kick("Maaf, server ini sudah penuh! Tidak ada lahan Tycoon tersisa.")
		return
	end

	player:SetAttribute("MyPlotName", myPlot.Name)

	-- Setup Leaderstats fisik
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cashVal = Instance.new("IntValue")
	cashVal.Name = "Cash"
	cashVal.Value = data.Stats.Cash or 0
	cashVal.Parent = leaderstats

	local levelVal = Instance.new("IntValue")
	levelVal.Name = "Level"
	levelVal.Value = data.Stats.Level or 1
	levelVal.Parent = leaderstats

	local rebirthVal = Instance.new("IntValue")
	rebirthVal.Name = "Rebirth"
	rebirthVal.Value = data.Stats.Rebirth or 0
	rebirthVal.Parent = leaderstats

	leaderstats.Parent = player

	-- Memuat Karakter dan Spawn
	player.CharacterAdded:Connect(function(character)
		PlotManager.teleportToPlot(player, character)
	end)

	if player.Character then
		PlotManager.teleportToPlot(player, player.Character)
	end

	task.spawn(setupPlayerSkinsAndAssets, player, data, myPlot)
	player:SetAttribute("DataLoaded", true)
end

local function onPlayerRemoving(player: Player)
	print(`[MainServer] Pemain keluar: {player.Name}. Menyimpan data...`)
	DataManager.saveData(player)
	PlotManager.releasePlot(player)
end

-- ==========================================================
-- [4] INISIALISASI UTAMA SERVER (THE BOOTSTRAPPER)
-- ==========================================================
local function InitializeServer()
	print("[MainServer] Memulai Inisialisasi Seluruh Sistem...")

	if typeof(RoleManager.Init) == "function" then
		RoleManager.Init()
	end
	if typeof(PlotManager.Init) == "function" then
		PlotManager.Init()
	end
	if typeof(CarManager.Init) == "function" then
		CarManager.Init()
	end
	if typeof(SpawnerBoxManager.Init) == "function" then
		SpawnerBoxManager.Init()
	end
	if typeof(BoxManager.Init) == "function" then
		BoxManager.Init()
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Periodic Autosave Loop (setiap 60 detik)
	task.spawn(function()
		while true do
			task.wait(60)
			print("[MainServer] Menjalankan autosave periodik untuk semua pemain...")
			for _, player in pairs(Players:GetPlayers()) do
				if player:GetAttribute("DataLoaded") then
					pcall(function()
						DataManager.syncData(player)
					end)
				end
			end
		end
	end)

	game:BindToClose(function()
		print("[MainServer] Server dimatikan. Mengamankan seluruh data pemain...")
		for _, player in pairs(Players:GetPlayers()) do
			DataManager.saveData(player)
		end
	end)
end

InitializeServer()

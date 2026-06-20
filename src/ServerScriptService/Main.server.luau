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
local ParkingAreaManager = safeRequire(script.Parent.ParkingAreaManager.ParkingAreaManager, "ParkingAreaManager")
local RebirthManager = safeRequire(script.Parent.RebirthManager.RebirthManager, "RebirthManager")
local RaceManager = safeRequire(script.Parent.RaceManager.RaceManager, "RaceManager")
local ShopManager = safeRequire(script.Parent.ShopManager.ShopManager, "ShopManager")

-- New Managers
local DeveloperBoostManager = safeRequire(script.Parent.DeveloperBoostManager.DeveloperBoostManager, "DeveloperBoostManager")
local EventManager = safeRequire(script.Parent.EventManager.EventManager, "EventManager")
local LegacyChatTagsManager = safeRequire(script.Parent.LegacyChatTagsManager.LegacyChatTagsManager, "LegacyChatTagsManager")
local OverheadManager = safeRequire(script.Parent.OverheadManager.OverheadManager, "OverheadManager")
local SellGuiManager = safeRequire(script.Parent.SellGuiManager.SellGuiManager, "SellGuiManager")
local TeleportManager = safeRequire(script.Parent.TeleportManager.TeleportManager, "TeleportManager")
local TestRunner = safeRequire(script.Parent.TestRunner.TestRunner, "TestRunner")
-- local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig"))

-- ==========================================================
-- [1] FUNGSI UTILITY (LOAD ITEMS TO BACKPACK)
-- ==========================================================
local function loadInventoryItem(player: Player, itemData)
	local backpack = player:WaitForChild("Backpack")
	local boxTemplate = ServerStorage:WaitForChild("Box", 5)
	if not boxTemplate then
		warn("[MainServer] Gagal memuat Box: Template 'Box' tidak ditemukan di ServerStorage!")
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
		box:SetAttribute("Type", "Box")
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
local function spawnPlotCars(player: Player, data: any, myPlot: Instance)
	if data.PlotData and data.PlotData.MyCars then
		for _, carData in pairs(data.PlotData.MyCars) do
			pcall(function()
				CarManager.spawnLoadedCar(player, carData, myPlot)
			end)
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

	local rebirthPointsVal = Instance.new("IntValue")
	rebirthPointsVal.Name = "RebirthPoints"
	rebirthPointsVal.Value = data.Stats.RebirthPoints or 0
	rebirthPointsVal.Parent = leaderstats

	local rpmVal = Instance.new("IntValue")
	rpmVal.Name = "RPM Tokens"
	rpmVal.Value = data.Stats.RPMTokens or 0
	rpmVal.Parent = leaderstats

	leaderstats.Parent = player

	-- Handle character loading (both initial spawn and respawn)
	local trackerConnections = {}

	local function cleanupTracker()
		for _, conn in ipairs(trackerConnections) do
			if conn.Connected then
				conn:Disconnect()
			end
		end
		table.clear(trackerConnections)
	end

	local syncPending = false
	local function sync()
		if syncPending then
			return
		end
		syncPending = true
		task.defer(function()
			task.wait(0.2) -- Beri jeda kecil agar transisi parenting tool selesai sebelum memicu sinkronisasi data
			syncPending = false
			if player.Parent and not player:GetAttribute("IsLeaving") then
				pcall(DataManager.syncData, player)
			end
		end)
	end

	local function onCharacterAdded(character)
		cleanupTracker()

		-- 1. Teleportasi ke plot lahan parkir
		PlotManager.teleportToPlot(player, character)

		-- 2. Muat item fisik backpack (inventory) dari database tersimpan
		local backpack = player:WaitForChild("Backpack", 10)
		if backpack then
			-- Hapus dulu tool bawaan jika ada untuk mencegah duplikasi (seperti dari StarterPack)
			for _, child in pairs(backpack:GetChildren()) do
				if child:IsA("Tool") then
					child:Destroy()
				end
			end

			-- Spawn item fisik (Box dan Mobil di Backpack)
			if data.Inventory then
				for _, item in pairs(data.Inventory) do
					local isBox = (item.Attributes and item.Attributes.Type == "Box")
						or (item.Name and string.find(item.Name, "Level") ~= nil)
					if isBox then
						local success, err = pcall(function()
							loadInventoryItem(player, item)
						end)
						if not success then
							warn("[MainServer] Gagal memuat Box: " .. tostring(err))
						end
					else
						local success, err = pcall(function()
							CarManager.spawnLoadedCar(player, item, myPlot)
						end)
						if not success then
							warn("[MainServer] Gagal memuat Mobil di Backpack: " .. tostring(err))
						end
					end
				end
			end

			-- Hubungkan tracker perubahan ke Backpack baru
			table.insert(trackerConnections, backpack.ChildAdded:Connect(sync))
			table.insert(trackerConnections, backpack.ChildRemoved:Connect(sync))
		else
			warn("[MainServer] Backpack tidak ditemukan dalam 10 detik untuk " .. player.Name)
		end

		-- Hubungkan tracker perubahan ke Character baru
		table.insert(trackerConnections, character.ChildAdded:Connect(sync))
		table.insert(trackerConnections, character.ChildRemoved:Connect(sync))

		-- Lakukan sinkronisasi data awal sesaat setelah load selesai
		sync()
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	player.CharacterRemoving:Connect(function(character)
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			for _, child in pairs(character:GetChildren()) do
				if child:IsA("Tool") then
					pcall(function()
						child.Parent = backpack
					end)
				end
			end
		end
	end)

	-- Spawn persistent plot cars (parking lots) secara sinkronis saat pemain pertama kali join
	local success, err = pcall(function()
		spawnPlotCars(player, data, myPlot)
	end)
	if not success then
		warn("[MainServer] Gagal memuat Mobil di Lahan: " .. tostring(err))
	end

	-- Recalculate passive income after plot cars have finished spawning and parenting
	task.spawn(function()
		task.wait(1.0)
		if player.Parent then
			ParkingAreaManager.recalculatePassiveIncome(player)
		end
	end)

	-- Tandai bahwa data awal pemain selesai dimuat (membuka kunci DataStore syncData dan menginisialisasi mesin)
	player:SetAttribute("DataLoaded", true)
end

local function onPlayerRemoving(player: Player)
	player:SetAttribute("IsLeaving", true) -- Kunci agar tidak terjadi overwrite kosong
	print(`[MainServer] Pemain keluar: {player.Name}. Menyimpan data...`)
	DataManager.saveData(player)
	PlotManager.releasePlot(player)
end

-- ==========================================================
-- [4] INISIALISASI UTAMA SERVER (THE BOOTSTRAPPER)
-- ==========================================================
local function InitializeServer()
	print("[MainServer] Memulai Inisialisasi Seluruh Sistem...")

	-- Buat RemoteEvent untuk notifikasi (harus dibuat di server untuk keamanan)
	if not game:GetService("ReplicatedStorage"):FindFirstChild("NotifEvent") then
		local notifEvent = Instance.new("RemoteEvent")
		notifEvent.Name = "NotifEvent"
		notifEvent.Parent = game:GetService("ReplicatedStorage")
	end

	-- Buat RemoteEvent untuk pengumuman chat (harus dibuat di server untuk keamanan)
	if not game:GetService("ReplicatedStorage"):FindFirstChild("ChatAnnounceEvent") then
		local chatAnnounceEvent = Instance.new("RemoteEvent")
		chatAnnounceEvent.Name = "ChatAnnounceEvent"
		chatAnnounceEvent.Parent = game:GetService("ReplicatedStorage")
	end

	if typeof(PlotManager.Init) == "function" then
		PlotManager.Init()
	end

	if typeof(RoleManager.Init) == "function" then
		RoleManager.Init()
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
	if typeof(ParkingAreaManager.Init) == "function" then
		ParkingAreaManager.Init()
	end
	if typeof(RebirthManager.Init) == "function" then
		RebirthManager.Init()
	end
	if typeof(RaceManager.Init) == "function" then
		RaceManager.Init()
	end
	if typeof(ShopManager.Init) == "function" then
		ShopManager.Init()
	end

	-- Initialize New Managers
	if typeof(DeveloperBoostManager.Init) == "function" then
		DeveloperBoostManager.Init()
	end
	if typeof(EventManager.Init) == "function" then
		EventManager.Init()
	end
	if typeof(LegacyChatTagsManager.Init) == "function" then
		LegacyChatTagsManager.Init()
	end
	if typeof(OverheadManager.Init) == "function" then
		OverheadManager.Init()
	end
	if typeof(SellGuiManager.Init) == "function" then
		SellGuiManager.Init()
	end
	if typeof(TeleportManager.Init) == "function" then
		TeleportManager.Init()
	end
	if typeof(TestRunner.Init) == "function" then
		TestRunner.Init()
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
			task.spawn(function()
				DataManager.saveData(player)
			end)
		end
		
		-- Tunggu hingga seluruh profil selesai dilepas dan dibersihkan dari cache
		while next(DataManager.Profiles) ~= nil do
			task.wait(0.1)
		end
		print("[MainServer] Seluruh data pemain telah aman dirilis!")
	end)
end

InitializeServer()

local DataManager = {}

local DEFAULT_DATA = {
	Stats = {
		Cash = 0,
		Level = 1,
		Rebirth = 0,
	},
	Inventory = {},
	PlotData = {
		MyCars = {},
		Machines = {},
	},
}

local Players = game:GetService("Players")
local ProfileService = require(game.ServerScriptService.ServerPackages.ProfileService)
local GameProfileStore = ProfileService.GetProfileStore("TycoonSave_V3", DEFAULT_DATA)

DataManager.Profiles = {}

-- ==========================================
-- Geters & Utility
-- ==========================================
function DataManager.getPlayerData(player)
	local profile = DataManager.Profiles[player]
	if profile then
		return profile.Data
	end
	return nil
end

local function extractAttributes(instance)
	local attributes = {}
	if instance then
		for name, value in pairs(instance:GetAttributes()) do
			attributes[name] = value
		end
	end
	return attributes
end

function DataManager.extractMachineData(player, machineArea: Instance)
	if not machineArea then
		return nil
	end

	local machinePart = nil
	for _, child in pairs(machineArea:GetChildren()) do
		if child:IsA("BasePart") and string.find(child.Name, "Machine") then
			machinePart = child
			break
		end
	end

	if not machinePart then
		machinePart = machineArea:FindFirstChildOfClass("BasePart")
	end

	local mData = {
		Name = machineArea.Name,
		Attributes = extractAttributes(machineArea),
		PartAttributes = extractAttributes(machinePart),
	}
	return mData
end

-- ==========================================
-- CORE: LOAD DATA (ProfileService)
-- ==========================================
function DataManager.loadData(player)
	local profile = GameProfileStore:LoadProfileAsync("Player_" .. player.UserId)

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile:ListenToRelease(function()
			DataManager.Profiles[player] = nil
			player:Kick("Data Anda sedang dimuat di server lain. Silakan masuk kembali.")
		end)

		if player:IsDescendantOf(Players) then
			DataManager.Profiles[player] = profile
			print("[DataManager] Profil berhasil dimuat untuk: " .. player.Name)
			return profile.Data
		else
			profile:Release()
			return nil
		end
	else
		warn("[DataManager] Gagal memuat data dari ProfileStore untuk: " .. player.Name)
		player:Kick("Roblox DataStore sedang bermasalah. Silakan coba beberapa saat lagi.")
		return nil
	end
end

-- ==========================================
-- CORE: SAVE & RELEASE DATA (FIXED ROLLBACK)
-- ==========================================
function DataManager.saveData(player)
	local profile = DataManager.Profiles[player]
	if not profile then
		warn("[DataManager] Profil tidak ditemukan di cache saat proses simpan untuk: " .. player.Name)
		return false
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("[DataManager] Leaderstats hilang, langsung melepas sesi kunci untuk keselamatan data.")
		profile:Release()
		DataManager.Profiles[player] = nil
		return false
	end

	-- Jalankan Live-Scan Workspace & Inventori Pemain sebelum save
	local finalSave = {
		Stats = {},
		Inventory = {},
		PlotData = {
			MyCars = {},
			Machines = {},
		},
	}

	-- 1. Ambil Nilai Stats Aktual
	finalSave.Stats.Cash = leaderstats:FindFirstChild("Cash") and leaderstats.Cash.Value or 0
	finalSave.Stats.Level = leaderstats:FindFirstChild("Level") and leaderstats.Level.Value or 1
	finalSave.Stats.Rebirth = leaderstats:FindFirstChild("Rebirth") and leaderstats.Rebirth.Value or 0

	-- 2. Scan Seluruh Item di Backpack & Karakter
	local function scanTools(folder: Instance?, locationName: string)
		if not folder then
			return
		end
		for _, item in pairs(folder:GetChildren()) do
			if item:IsA("Tool") then
				pcall(function()
					local itemRecord = {
						Name = item.Name,
						Location = locationName,
						Attributes = extractAttributes(item),
						Stacks = {},
					}
					local stacksFolder = item:FindFirstChild("Stacks")
					if stacksFolder then
						for _, stackConfig in pairs(stacksFolder:GetChildren()) do
							if stackConfig:IsA("Configuration") then
								table.insert(itemRecord.Stacks, extractAttributes(stackConfig))
							end
						end
					end
					table.insert(finalSave.Inventory, itemRecord)
				end)
			end
		end
	end

	scanTools(player:FindFirstChild("Backpack"), "Backpack")
	if player.Character then
		scanTools(player.Character, "Character")
	end

	-- 3. Scan Seluruh Mobil di Lahan Parkir & Mesin secara Dinamis
	local plotName = player:GetAttribute("MyPlotName")
	local myPlot = plotName and workspace.Plots:FindFirstChild(plotName)

	if myPlot then
		local parkingLots = myPlot:FindFirstChild("AllParkingLots")
		if parkingLots then
			for _, parking in pairs(parkingLots:GetChildren()) do
				local carsFolder = parking:FindFirstChild("MyCars", true)
				if carsFolder then
					for _, car in pairs(carsFolder:GetChildren()) do
						if car:IsA("Tool") or car:IsA("Model") then
							table.insert(finalSave.PlotData.MyCars, {
								Name = car.Name,
								Location = parking.Name,
								Attributes = extractAttributes(car),
							})
						end
					end
				end
			end
		end

		local plotMachines = myPlot:FindFirstChild("Machines")
		if plotMachines then
			for _, machineArea in pairs(plotMachines:GetChildren()) do
				finalSave.PlotData.Machines[machineArea.Name] = DataManager.extractMachineData(player, machineArea)
			end
		end
	end

	-- 4. Kirim data hasil scan ke ProfileService & Buka Kunci Sesi
	profile.Data.Stats = finalSave.Stats
	profile.Data.Inventory = finalSave.Inventory
	profile.Data.PlotData = finalSave.PlotData

	profile:Release()
	DataManager.Profiles[player] = nil
	print("[DataManager] Progress berhasil di-scan, disimpan dan diamankan untuk: " .. player.Name)
	return true
end

return DataManager

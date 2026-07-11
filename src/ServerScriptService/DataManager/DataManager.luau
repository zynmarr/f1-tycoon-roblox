local DataManager = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))

local DEFAULT_DATA = {
	Stats = {
		Cash = 0,
		Level = 1,
		Rebirth = 0,
		RebirthPoints = 0,
		RPMTokens = 0, -- Saldo RPM Tokens pemain (bermula dari 0)
		RaceStats = {
			Wins = 0,
			Losses = 0,
			CashEarned = 0,
			WinStreak = 0,
			PvPWins = 0,
		},
	},
	Inventory = {},
	PlotData = {
		MyCars = {},
		Machines = {},
	},
	RebirthUpgrades = {
		CashMultiplier = 0,
		LuckMultiplier = 0,
		WalkspeedBoost = 0,
		MaxInventorySlots = 0,
		DoubleCashChance = 0,
		AllVariantsBoost = 0,
		VariantChance_Rainbow = 0,
		VariantChance_Frostbite = 0,
		VariantChance_Galaxy = 0,
		VariantChance_Hellfire = 0,
		VariantChance_Cosmic = 0,
	},
	DailyRewards = {
		LastClaimTime = 0,
		Streak = 0,
	},
	Quests = {
		Daily = {
			LastGeneratedTime = 0,
			ActiveQuests = {},
		},
		Milestones = {
			TotalCarsSold = 0,
			TotalBoxesOpened = 0,
			ClaimedMilestones = {},
		},
	},
	DailyStolenBoxes = {
		LastResetTime = 0,
		Count = 0,
	},
	CarIndexCollection = {},
}

-- ===== ATTRIBUTE SCHEMA VALIDATION =====
local VALID_ATTRIBUTES = {
	Type = "string",
	Level = "number",
	Exp = "number",
	MaxExp = "number",
	LuckyChance = "number",
	Variants = "string",
	Variant = "string",
	Income = "number",
	Price = "number",
	Rarity = "string",
	Owner = "string",
	Amount = "number",
	OnHand = "boolean",
	HasPicked = "boolean",
	IsDestroying = "boolean",
	Name = "string",
	Location = "string",
	IsParked = "boolean",
	ScaleFixed = "boolean",
	IsInitialized = "boolean",
}

local function validateAttribute(name, value)
	if not VALID_ATTRIBUTES[name] then
		return true
	end
	local expectedType = VALID_ATTRIBUTES[name]
	if typeof(value) == expectedType then
		return true
	end
	warn(string.format("[DataManager] Invalid attribute %s: expected %s, got %s", name, expectedType, typeof(value)))
	return false
end

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
			-- Validate attribute before saving
			if validateAttribute(name, value) then
				attributes[name] = value
			end
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

	-- Scan for any active boxes currently growing on this machine part
	local activeBoxes = {}
	if machinePart then
		for _, child in pairs(machinePart:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("Level") ~= nil then
				table.insert(activeBoxes, {
					Level = child:GetAttribute("Level") or 1,
					Exp = child:GetAttribute("Exp") or 0,
					Variants = child:GetAttribute("Variants") or "Normal",
					SpawnLocationName = child:GetAttribute("SpawnLocationName"),
				})
			end
		end
	end

	local mData = {
		Name = machineArea.Name,
		Attributes = extractAttributes(machineArea),
		PartAttributes = extractAttributes(machinePart),
		ActiveBoxes = #activeBoxes > 0 and activeBoxes or nil,
		ActiveBox = #activeBoxes > 0 and activeBoxes[1] or nil, -- Keep fallback for backward compatibility
	}
	return mData
end

-- ==========================================
-- CORE: LOAD DATA (ProfileService)
-- ==========================================
function DataManager.loadData(player)
	local loadSuccess, profile = pcall(function()
		return GameProfileStore:LoadProfileAsync("Player_" .. player.UserId)
	end)

	if not loadSuccess then
		warn("[DataManager] Error saat LoadProfileAsync: " .. tostring(profile))
		player:Kick("Roblox DataStore sedang bermasalah. Silakan coba beberapa saat lagi.")
		return nil
	end

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		-- Check player state BEFORE setting up release listener (prevents race condition)
		if not player:IsDescendantOf(Players) then
			profile:Release()
			return nil
		end

		profile:ListenToRelease(function()
			DataManager.Profiles[player] = nil
			-- Only kick if still in game
			if player:IsDescendantOf(Players) then
				player:Kick("Data Anda sedang dimuat di server lain. Silakan masuk kembali.")
			end
		end)

		DataManager.Profiles[player] = profile
		print("[DataManager] Profil berhasil dimuat untuk: " .. player.Name)
		return profile.Data
	else
		warn("[DataManager] Gagal memuat data dari ProfileStore untuk: " .. player.Name)
		player:Kick("Roblox DataStore sedang bermasalah. Silakan coba beberapa saat lagi.")
		return nil
	end
end

-- ==========================================
-- CORE: SYNC DATA (UPDATE PROFILE IN-PLACE)
-- ==========================================
function DataManager.syncData(player)
	local profile = DataManager.Profiles[player]
	if not profile then
		warn("[DataManager] Profil tidak ditemukan di cache saat proses sinkronisasi untuk: " .. player.Name)
		return false
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("[DataManager] Leaderstats hilang saat sinkronisasi data.")
		return false
	end

	-- Jalankan Live-Scan Workspace & Inventori Pemain
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
	finalSave.Stats.RebirthPoints = leaderstats:FindFirstChild("RebirthPoints") and leaderstats.RebirthPoints.Value or 0
	finalSave.Stats.RPMTokens = leaderstats:FindFirstChild("RPM Tokens") and leaderstats["RPM Tokens"].Value or 0
	finalSave.Stats.RaceStats = profile.Data.Stats and profile.Data.Stats.RaceStats
		or {
			Wins = 0,
			Losses = 0,
			CashEarned = 0,
			WinStreak = 0,
			PvPWins = 0,
		}

	-- 2. Scan Seluruh Item di Backpack & Karakter (Hanya jika pemain tidak sedang keluar dan data sudah ter-load)
	if not player:GetAttribute("IsLeaving") and player:GetAttribute("DataLoaded") then
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
			scanTools(player.Character, "Backpack")
		end
	else
		-- Jika sedang keluar, pertahankan data inventori yang sudah tersinkron sebelumnya
		finalSave.Inventory = profile.Data.Inventory or {}
	end

	-- 3. Scan Seluruh Mobil di Lahan Parkir & Mesin secara Dinamis (Hanya jika data sudah ter-load)
	local myPlot = GameUtils.getPlayerPlot(player)

	if myPlot and player:GetAttribute("DataLoaded") then
		local scanSuccess, scanError = pcall(function()
			local parkingLots = myPlot:FindFirstChild("AllParkingLots")
			if parkingLots then
				for _, part in pairs(parkingLots:GetDescendants()) do
					if part:isA("BasePart") then
						local carsFolder = part:FindFirstChild("MyCars", true)
						if carsFolder then
							for _, car in pairs(carsFolder:GetChildren()) do
								if car:IsA("Tool") or car:IsA("Model") then
									table.insert(finalSave.PlotData.MyCars, {
										Name = car.Name,
										Location = part.Name,
										Attributes = extractAttributes(car),
									})
								end
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
		end)

		if not scanSuccess then
			warn(
				"[DataManager] Gagal melakukan sinkronisasi plot data untuk player: "
					.. player.Name
					.. " - Error: "
					.. tostring(scanError)
			)
		end
	else
		-- Jika data belum ter-load sepenuhnya ke workspace, pertahankan data plot dari profile
		finalSave.PlotData = profile.Data.PlotData or { MyCars = {}, Machines = {} }
	end

	-- 4. Kirim data hasil scan ke ProfileService
	profile.Data.Stats = finalSave.Stats
	profile.Data.Inventory = finalSave.Inventory
	profile.Data.PlotData = finalSave.PlotData

	-- Replikasi data ke player attribute agar client React UI bisa membaca reaktif
	local HttpService = game:GetService("HttpService")
	player:SetAttribute("RebirthPoints", finalSave.Stats.RebirthPoints or 0)
	player:SetAttribute("RebirthUpgrades", HttpService:JSONEncode(profile.Data.RebirthUpgrades or {}))
	player:SetAttribute("DailyRewards", HttpService:JSONEncode(profile.Data.DailyRewards or {}))
	player:SetAttribute("Quests", HttpService:JSONEncode(profile.Data.Quests or {}))
	player:SetAttribute(
		"RaceStats",
		HttpService:JSONEncode(
			profile.Data.Stats.RaceStats or { Wins = 0, Losses = 0, CashEarned = 0, WinStreak = 0, PvPWins = 0 }
		)
	)
	player:SetAttribute("CarIndexCollection", HttpService:JSONEncode(profile.Data.CarIndexCollection or {}))

	return true
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

	-- Jalankan sinkronisasi data aktual ke profil
	DataManager.syncData(player)

	-- Buka Kunci Sesi
	profile:Release()
	DataManager.Profiles[player] = nil
	print("[DataManager] Progress berhasil di-scan, disimpan dan diamankan untuk: " .. player.Name)
	return true
end

return DataManager

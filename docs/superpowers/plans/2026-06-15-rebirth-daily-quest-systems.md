# Rebirth, Daily Rewards, & Quest Systems Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun sistem Rebirth terintegrasi dengan reset plot terproteksi, login streak harian 7-hari (Daily Rewards), serta misi harian & pencapaian (Quests/Milestones) menggunakan arsitektur UI React Luau terpadu.

**Architecture:** Menggunakan satu UI React Hub terpadu di sisi client yang bertukar data secara reaktif dengan server melalui modul Networker. Logika server mengelola validasi, data reset, perkalian poin Rebirth eksponensial (Opsi A), dan penyimpanan ProfileService yang aman.

**Tech Stack:** React (jsdotlua/react@17.0.2), ReactRoblox (jsdotlua/react-roblox@17.0.2), ProfileService, Networker.

---

## Rencana Struktur Berkas (File Structure Map)
* **Server**:
  * [DataManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/DataManager/DataManager.luau) (Modifikasi - Skema penyimpanan data terpadu)
  * [Main.server.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/Main.server.luau) (Modifikasi - Leaderstats RebirthPoints & bootstrap)
  * [RebirthManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/RebirthManager/RebirthManager.luau) (Baru - Pengelola Rebirth, Reset, Toko Upgrade, Misi, & Login Streak)
  * [TestRunner.server.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/TestRunner.server.luau) (Baru - Verifikasi logic unit testing offline)
* **Client**:
  * [MainGuiHub.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/StarterPlayer/StarterPlayerScripts/components/MainGuiHub/MainGuiHub.luau) (Baru - Container Sidebar Tab React)
  * [RebirthTab.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/StarterPlayer/StarterPlayerScripts/components/MainGuiHub/RebirthTab.luau) (Baru - Toko Upgrade & Kontrol Rebirth)
  * [DailyRewardsTab.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/StarterPlayer/StarterPlayerScripts/components/MainGuiHub/DailyRewardsTab.luau) (Baru - Grid Streak 7-Hari)
  * [QuestsTab.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/StarterPlayer/StarterPlayerScripts/components/MainGuiHub/QuestsTab.luau) (Baru - Misi Harian & Milestone)
  * [MountMainGuiHub.client.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/StarterPlayer/StarterPlayerScripts/MountMainGuiHub.client.luau) (Baru - Mounting & sinkronisasi state React)

---

### Task 1: Modifikasi Skema Data & Pemuatan Awal (DataManager & MainServer)

**Files:**
* Modify: `src/ServerScriptService/DataManager/DataManager.luau:5-16`
* Modify: `src/ServerScriptService/Main.server.luau:182-202`

- [ ] **Step 1: Mutakhirkan Skema DEFAULT_DATA pada DataManager.luau**
  Tambahkan field RebirthPoints, RebirthUpgrades, DailyRewards, dan Quests ke dalam `DEFAULT_DATA`.
  ```lua
  local DEFAULT_DATA = {
  	Stats = {
  		Cash = 0,
  		Level = 1,
  		Rebirth = 0,
  		RebirthPoints = 0,
  	},
  	Inventory = {},
  	PlotData = {
  		MyCars = {},
  		Machines = {},
  	},
  	RebirthUpgrades = {
  		CashMultiplier = 0, -- Level upgrade (+15% per lvl)
  		LuckMultiplier = 0, -- Level upgrade (+10% per lvl)
  		VariantChance_Rainbow = 0, -- Level upgrade (+15% chance Rainbow)
  		VariantChance_All = 0, -- Level upgrade (+10% all variants)
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
  		}
  	}
  }
  ```

- [ ] **Step 2: Tambahkan Leaderstats RebirthPoints di Main.server.luau**
  Modifikasi pembuatan leaderstats saat pemain masuk untuk memuat RebirthPoints.
  ```lua
  	local rebirthPointsVal = Instance.new("IntValue")
  	rebirthPointsVal.Name = "RebirthPoints"
  	rebirthPointsVal.Value = data.Stats.RebirthPoints or 0
  	rebirthPointsVal.Parent = leaderstats
  ```

- [ ] **Step 3: Jalankan verifikasi manual**
  Pastikan script Rojo me-sync perubahan ke Roblox Studio tanpa error kompilasi.

---

### Task 2: Buat RebirthManager (Rebirth & Toko Upgrade Logic)

**Files:**
* Create: `src/ServerScriptService/RebirthManager/RebirthManager.luau`

- [ ] **Step 1: Tulis Logika Utama Rebirth & Upgrade Permanen**
  Buat file `RebirthManager.luau` yang mengekspos fungsi Rebirth, validasi biaya Cash eksponensial, pembersihan plot (kecuali barang Admin), dan Toko Upgrade menggunakan Rebirth Points.

```lua
local RebirthManager = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(game.ServerScriptService.DataManager.DataManager)
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local Networker = require(ReplicatedStorage.Packages.Networker)

local function calculateRebirthPoints(rebirthLevel: number): number
	if rebirthLevel == 0 then return 50 end
	if rebirthLevel == 1 then return 100 end
	if rebirthLevel == 2 then return 180 end
	
	local points = 180
	for i = 3, rebirthLevel do
		if i % 3 == 0 then
			points = (points * 2) + 20
		else
			points = points + 100
		end
	end
	return points
end

local function resetPlayerPlotAndAssets(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local cash = leaderstats:FindFirstChild("Cash")
		if cash then cash.Value = 0 end
	end
	
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				local isVariantAdmin = tool:GetAttribute("Variant") == "Admin"
				local hasAdminName = string.find(string.lower(tool.Name), "admin") ~= nil
				if not isVariantAdmin and not hasAdminName then
					tool:Destroy()
				end
			end
		end
	end
	
	local character = player.Character
	if character then
		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") then
				local isVariantAdmin = tool:GetAttribute("Variant") == "Admin"
				local hasAdminName = string.find(string.lower(tool.Name), "admin") ~= nil
				if not isVariantAdmin and not hasAdminName then
					tool:Destroy()
				end
			end
		end
	end
	
	local myPlot = GameUtils.getPlayerPlot(player)
	if myPlot then
		local parkingLots = myPlot:FindFirstChild("AllParkingLots")
		if parkingLots then
			for _, parking in ipairs(parkingLots:GetChildren()) do
				local carsFolder = parking:FindFirstChild("MyCars", true)
				if carsFolder then
					for _, car in ipairs(carsFolder:GetChildren()) do
						local isVariantAdmin = car:GetAttribute("Variant") == "Admin"
						local hasAdminName = string.find(string.lower(car.Name), "admin") ~= nil
						if not isVariantAdmin and not hasAdminName then
							car:Destroy()
						end
					end
				end
				local prompt = parking:FindFirstChild("ProximityPrompt")
				if prompt then
					prompt:SetAttribute("IsActive", false)
				end
			end
		end
		
		local machines = myPlot:FindFirstChild("Machines")
		if machines then
			for _, machineArea in ipairs(machines:GetChildren()) do
				machineArea:SetAttribute("IsRunning", false)
				machineArea:SetAttribute("Active", nil)
				for attr, _ in pairs(machineArea:GetAttributes()) do
					if string.find(attr, "^Upg_") then
						machineArea:SetAttribute(attr, nil)
					end
				end
				local machinePart = machineArea:FindFirstChildWhichIsA("BasePart")
				if machinePart then
					for _, child in ipairs(machinePart:GetChildren()) do
						if child:IsA("Tool") then
							child:Destroy()
						end
					end
				end
			end
		end
	end
end

function RebirthManager:requestRebirth(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then return { Success = false, Error = "Data tidak ditemukan!" } end
	
	local currentRebirth = data.Stats.Rebirth or 0
	local cost = 1000000 * (2.5 ^ currentRebirth)
	
	local leaderstats = player:FindFirstChild("leaderstats")
	local cashVal = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cashVal or cashVal.Value < cost then
		return { Success = false, Error = "Cash Anda tidak cukup untuk Rebirth!" }
	end
	
	local pointsToGrant = calculateRebirthPoints(currentRebirth)
	
	data.Stats.Rebirth = currentRebirth + 1
	data.Stats.RebirthPoints = (data.Stats.RebirthPoints or 0) + pointsToGrant
	data.Stats.Cash = 0
	
	local rebirthVal = leaderstats:FindFirstChild("Rebirth")
	local pointsVal = leaderstats:FindFirstChild("RebirthPoints")
	if rebirthVal then rebirthVal.Value = data.Stats.Rebirth end
	if pointsVal then pointsVal.Value = data.Stats.RebirthPoints end
	
	resetPlayerPlotAndAssets(player)
	DataManager.syncData(player)
	
	return { Success = true, Message = "Rebirth Berhasil! +" .. pointsToGrant .. " RP" }
end

function RebirthManager:purchaseRebirthUpgrade(player: Player, upgradeName: string)
	local data = DataManager.getPlayerData(player)
	if not data or not data.RebirthUpgrades then return { Success = false, Error = "Data upgrade tidak ditemukan!" } end
	
	local currentLevel = data.RebirthUpgrades[upgradeName]
	if not currentLevel then return { Success = false, Error = "Upgrade tidak valid!" } end
	
	local cost = 50 * (2 ^ currentLevel) -- Mulai dari 50, 100, 200, dst.
	if (data.Stats.RebirthPoints or 0) < cost then
		return { Success = false, Error = "Rebirth Points tidak cukup!" }
	end
	
	data.Stats.RebirthPoints = data.Stats.RebirthPoints - cost
	data.RebirthUpgrades[upgradeName] = currentLevel + 1
	
	local leaderstats = player:FindFirstChild("leaderstats")
	local pointsVal = leaderstats and leaderstats:FindFirstChild("RebirthPoints")
	if pointsVal then pointsVal.Value = data.Stats.RebirthPoints end
	
	DataManager.syncData(player)
	return { Success = true, Message = "Upgrade " .. upgradeName .. " berhasil dibeli!" }
end

function RebirthManager.Init()
	Networker.server.new("RebirthService", RebirthManager, {
		RebirthManager.requestRebirth,
		RebirthManager.purchaseRebirthUpgrade,
	})
end

return RebirthManager
```

---

### Task 3: Tambahkan Daily Rewards & Quests Logic ke RebirthManager

**Files:**
* Modify: `src/ServerScriptService/RebirthManager/RebirthManager.luau`

- [ ] **Step 1: Implementasi Daily Rewards, Quests generator, & Claiming Endpoints**
  Tulis kelanjutan logika gacha daily reward dan verifikasi quests.

```lua
-- Pasang fungsi tambahan di bawah RebirthManager dalam file yang sama:

local DAILY_QUEST_TEMPLATES = {
	{ ID = "sell_10", Type = "SellCars", Target = 10, RewardCash = 15000, Text = "Jual 10 Mobil ke Seller" },
	{ ID = "open_5", Type = "OpenBoxes", Target = 5, RewardCash = 10000, Text = "Buka 5 Gacha Box" },
	{ ID = "earn_50k", Type = "EarnCash", Target = 50000, RewardCash = 20000, Text = "Dapatkan $50,000 Cash" },
}

local function generateDailyQuests(player: Player, data: any)
	local now = os.time()
	local lastGen = data.Quests.Daily.LastGeneratedTime or 0
	if now - lastGen >= 86400 or #data.Quests.Daily.ActiveQuests == 0 then
		data.Quests.Daily.LastGeneratedTime = now
		data.Quests.Daily.ActiveQuests = {}
		
		-- Pilih 3 misi acak
		local pool = {1, 2, 3}
		for i = 1, 3 do
			local randIdx = table.remove(pool, math.random(1, #pool))
			local t = DAILY_QUEST_TEMPLATES[randIdx]
			table.insert(data.Quests.Daily.ActiveQuests, {
				ID = t.ID,
				Type = t.Type,
				Progress = 0,
				Target = t.Target,
				RewardCash = t.RewardCash,
				Text = t.Text,
				Completed = false,
				Claimed = false,
			})
		end
	end
end

function RebirthManager:claimDailyReward(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data or not data.DailyRewards then return { Success = false, Error = "Data daily reward error!" } end
	
	local now = os.time()
	local lastClaim = data.DailyRewards.LastClaimTime or 0
	local streak = data.DailyRewards.Streak or 0
	
	if now - lastClaim < 72000 then -- 20 jam cooldown
		local nextTime = 72000 - (now - lastClaim)
		return { Success = false, Error = "Tunggu " .. math.ceil(nextTime / 3600) .. " jam lagi untuk mengeklaim!" }
	end
	
	if now - lastClaim > 172800 then -- Lewat 48 jam, reset streak
		streak = 0
	end
	
	streak = (streak % 7) + 1
	data.DailyRewards.Streak = streak
	data.DailyRewards.LastClaimTime = now
	
	local rewardCash = 5000 * streak
	local leaderstats = player:FindFirstChild("leaderstats")
	local cashVal = leaderstats and leaderstats:FindFirstChild("Cash")
	if cashVal then cashVal.Value = cashVal.Value + rewardCash end
	
	DataManager.syncData(player)
	return { Success = true, Message = "Klaim Hadiah Hari " .. streak .. " Berhasil! +$" .. rewardCash }
end

function RebirthManager:claimDailyQuest(player: Player, questId: string)
	local data = DataManager.getPlayerData(player)
	if not data then return { Success = false, Error = "Player data error!" } end
	
	for _, q in ipairs(data.Quests.Daily.ActiveQuests) do
		if q.ID == questId then
			if q.Progress >= q.Target and not q.Claimed then
				q.Claimed = true
				q.Completed = true
				
				local leaderstats = player:FindFirstChild("leaderstats")
				local cashVal = leaderstats and leaderstats:FindFirstChild("Cash")
				if cashVal then cashVal.Value = cashVal.Value + q.RewardCash end
				
				DataManager.syncData(player)
				return { Success = true, Message = "Misi selesai! +$" .. q.RewardCash }
			end
		end
	end
	return { Success = false, Error = "Misi belum selesai atau sudah diklaim!" }
end

-- Hook tracking logic (dipanggil dari Server saat event terjadi)
function RebirthManager.incrementQuestProgress(player: Player, questType: string, amount: number)
	local data = DataManager.getPlayerData(player)
	if not data then return end
	
	generateDailyQuests(player, data)
	
	for _, q in ipairs(data.Quests.Daily.ActiveQuests) do
		if q.Type == questType and not q.Completed then
			q.Progress = math.clamp(q.Progress + amount, 0, q.Target)
			if q.Progress >= q.Target then
				q.Completed = true
			end
		end
	end
end

-- Update Networker server registration di bottom Init() method:
-- Networker.server.new("RebirthService", RebirthManager, {
--     RebirthManager.requestRebirth,
--     RebirthManager.purchaseRebirthUpgrade,
--     RebirthManager.claimDailyReward,
--     RebirthManager.claimDailyQuest,
-- })
```

---

### Task 4: Hubungkan Event Penjualan & Pembukaan Box ke Progress Tracker

**Files:**
* Modify: `src/ServerScriptService/SellGuiServer.server.luau:290-296`
* Modify: `src/ServerScriptService/BoxManager/BoxManager.luau:320-330`

- [ ] **Step 1: Tambahkan Hook Penjualan Mobil di SellGuiServer.server.luau**
  Cari baris sukses transaksi penjualan mobil di server dan tambahkan pemanggilan progress tracker.
  ```lua
  local RebirthManager = require(game.ServerScriptService.RebirthManager.RebirthManager)
  RebirthManager.incrementQuestProgress(player, "SellCars", carsCount)
  ```

- [ ] **Step 2: Tambahkan Hook Pembukaan Box di BoxManager.luau**
  Tambahkan pemanggilan progress tracker di akhir logika `openBox`.
  ```lua
  local RebirthManager = require(game.ServerScriptService.RebirthManager.RebirthManager)
  RebirthManager.incrementQuestProgress(player, "OpenBoxes", 1)
  ```

---

### Task 3 (UI): Buat React Component Subtabs (RebirthTab, DailyRewardsTab, QuestsTab)

**Files:**
* Create: `src/StarterPlayer/StarterPlayerScripts/components/MainGuiHub/RebirthTab.luau`
* Create: `src/StarterPlayer/StarterPlayerScripts/components/MainGuiHub/DailyRewardsTab.luau`
* Create: `src/StarterPlayer/StarterPlayerScripts/components/MainGuiHub/QuestsTab.luau`

- [ ] **Step 1: Rancang RebirthTab.luau**
  Desain antarmuka modular toko upgrade rebirth.
  ```lua
  local ReplicatedStorage = game:GetService("ReplicatedStorage")
  local React = require(ReplicatedStorage.Packages.React)
  local e = React.createElement

  return function(props)
	return e("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, {
		RebirthArea = e("Frame", {
			Size = UDim2.new(0.4, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(25, 25, 30),
		}, {
			TextLabel = e("TextLabel", {
				Text = "LEVEL REBIRTH: " .. tostring(props.RebirthLevel),
				Size = UDim2.new(1, 0, 0, 50),
				TextColor3 = Color3.fromRGB(255, 255, 255),
			}),
			RebirthBtn = e("TextButton", {
				Text = "REBIRTH NOW ($" .. tostring(1000000 * (2.5 ^ props.RebirthLevel)) .. ")",
				Size = UDim2.new(0.8, 0, 0, 60),
				Position = UDim2.new(0.1, 0, 0.5, -30),
				BackgroundColor3 = Color3.fromRGB(180, 40, 40),
			})
		})
	})
  end
  ```

- [ ] **Step 2: Rancang DailyRewardsTab.luau**
  ```lua
  local ReplicatedStorage = game:GetService("ReplicatedStorage")
  local React = require(ReplicatedStorage.Packages.React)
  local e = React.createElement

  return function(props)
	local days = {}
	for i = 1, 7 do
		days["Day" .. i] = e("Frame", {
			Size = UDim2.new(0.12, 0, 0.8, 0),
			BackgroundColor3 = (props.Streak >= i) and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(40, 40, 45),
		}, {
			Label = e("TextLabel", {
				Text = "Hari " .. i,
				Size = UDim2.new(1, 0, 0.3, 0),
				TextColor3 = Color3.fromRGB(255, 255, 255),
			}),
			ClaimBtn = (props.Streak + 1 == i) and e("TextButton", {
				Text = "KLAIM",
				Size = UDim2.new(0.8, 0, 0.4, 0),
				Position = UDim2.new(0.1, 0, 0.5, 0),
				BackgroundColor3 = Color3.fromRGB(200, 150, 50),
			}) or nil
		})
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, days)
  end
  ```

- [ ] **Step 3: Rancang QuestsTab.luau**
  ```lua
  local ReplicatedStorage = game:GetService("ReplicatedStorage")
  local React = require(ReplicatedStorage.Packages.React)
  local e = React.createElement

  return function(props)
	return e("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, {
		List = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
			})
		})
	})
  end
  ```

---

### Task 4 (UI): Satukan ke MainGuiHub & Client Mounting

**Files:**
* Create: `src/StarterPlayer/StarterPlayerScripts/components/MainGuiHub/MainGuiHub.luau`
* Create: `src/StarterPlayer/StarterPlayerScripts/MountMainGuiHub.client.luau`

- [ ] **Step 1: Implementasi MainGuiHub.luau**
  Tulis container utama yang merender ketiga tab tersebut secara dinamis.

- [ ] **Step 2: Buat MountMainGuiHub.client.luau**
  Tulis script inisialisasi yang melakukan `createRoot` dan me-mount React UI ke PlayerGui secara instan.

- [ ] **Step 3: Integrasikan ke Main.server.luau Bootstrapper**
  Cari inisialisasi modul server dan tambahkan inisialisasi `RebirthManager`.
  ```lua
  local RebirthManager = require(game.ServerScriptService.RebirthManager.RebirthManager)
  RebirthManager.Init()
  ```

---

### Task 5: Rencana Pengujian (TestRunner Offline Verification)

**Files:**
* Create: `src/ServerScriptService/TestRunner.server.luau`

- [ ] **Step 1: Tulis Skenario Pengujian Otomatis**
  Tulis file TestRunner sementara di server untuk memverifikasi logika kelipatan poin Rebirth Opsi A dan pembersihan plot.
  ```lua
  local RebirthManager = require(game.ServerScriptService.RebirthManager.RebirthManager)
  print("[TEST] Memulai verifikasi logic Rebirth...")
  
  -- Mock formula test
  local r1 = RebirthManager:calculateRebirthPoints(0)
  assert(r1 == 50, "Error: Rebirth 1 should grant 50 points")
  local r2 = RebirthManager:calculateRebirthPoints(1)
  assert(r2 == 100, "Error: Rebirth 2 should grant 100 points")
  local r3 = RebirthManager:calculateRebirthPoints(2)
  assert(r3 == 180, "Error: Rebirth 3 should grant 180 points")
  local r4 = RebirthManager:calculateRebirthPoints(3)
  assert(r4 == 380, "Error: Rebirth 4 should grant 380 points")
  
  print("[TEST] ✅ Seluruh logic unit testing Rebirth lolos verifikasi!")
  ```

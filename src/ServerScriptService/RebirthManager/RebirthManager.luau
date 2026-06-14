local RebirthManager = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(game.ServerScriptService.DataManager.DataManager)
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local Networker = require(ReplicatedStorage.Packages.Networker)

-- ===== REBIRTH POINTS FORMULA (OPSE A - SCALE HARD) =====
function RebirthManager:calculateRebirthPoints(rebirthLevel: number): number
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

-- ===== TYCOON RESET MECHANICS =====
local function resetPlayerPlotAndAssets(player: Player)
	-- 1. Reset Cash to 0
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local cash = leaderstats:FindFirstChild("Cash")
		if cash then cash.Value = 0 end
	end
	
	-- 2. Destroy non-Admin items from Backpack
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
	
	-- 3. Destroy non-Admin items from Character
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
	
	-- 4. Reset Plot Area & Parked Cars
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
		
		-- Reset Tycoon Machines purchase attributes & active boxes
		local machines = myPlot:FindFirstChild("Machines")
		if machines then
			for _, machineArea in ipairs(machines:GetChildren()) do
				for attr, _ in pairs(machineArea:GetAttributes()) do
					if attr ~= "IsInitialized" then
						machineArea:SetAttribute(attr, nil)
					end
				end
				local machinePart = nil
				for _, child in ipairs(machineArea:GetChildren()) do
					if child:IsA("BasePart") and string.find(child.Name, "Machine") then
						machinePart = child
						break
					end
				end
				if not machinePart then
					machinePart = machineArea:FindFirstChildOfClass("BasePart")
				end
				if machinePart then
					for _, child in ipairs(machinePart:GetChildren()) do
						if child:IsA("Tool") or child:IsA("Model") or child:GetAttribute("Level") ~= nil then
							child:Destroy()
						end
					end
				end
			end
		end
	end
end

-- ===== REBIRTH ACTION =====
function RebirthManager:requestRebirth(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then return { Success = false, Error = "Data tidak ditemukan!" } end
	
	local currentRebirth = data.Stats.Rebirth or 0
	local cost = 1000000 * (2.5 ^ currentRebirth)
	
	local leaderstats = player:FindFirstChild("leaderstats")
	local cashVal = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cashVal or cashVal.Value < cost then
		return { Success = false, Error = "Cash Anda tidak cukup untuk Rebirth! Butuh $" .. GameUtils.formatCompact(cost) }
	end
	
	local pointsToGrant = RebirthManager:calculateRebirthPoints(currentRebirth)
	
	data.Stats.Rebirth = currentRebirth + 1
	data.Stats.RebirthPoints = (data.Stats.RebirthPoints or 0) + pointsToGrant
	data.Stats.Cash = 0
	
	local rebirthVal = leaderstats:FindFirstChild("Rebirth")
	local pointsVal = leaderstats:FindFirstChild("RebirthPoints")
	if rebirthVal then rebirthVal.Value = data.Stats.Rebirth end
	if pointsVal then pointsVal.Value = data.Stats.RebirthPoints end
	
	resetPlayerPlotAndAssets(player)
	DataManager.syncData(player)
	
	return { Success = true, Message = "Rebirth Berhasil! Kelipatan poin +" .. pointsToGrant .. " RP" }
end

-- ===== PURCHASE REBIRTH UPGRADE =====
function RebirthManager:purchaseRebirthUpgrade(player: Player, upgradeName: string)
	local data = DataManager.getPlayerData(player)
	if not data or not data.RebirthUpgrades then return { Success = false, Error = "Data upgrade tidak ditemukan!" } end
	
	local currentLevel = data.RebirthUpgrades[upgradeName]
	if currentLevel == nil then return { Success = false, Error = "Upgrade '" .. upgradeName .. "' tidak valid!" } end
	
	local cost = 50 * (2 ^ currentLevel) -- Mulai dari 50, 100, 200, 400, dst.
	if (data.Stats.RebirthPoints or 0) < cost then
		return { Success = false, Error = "Rebirth Points tidak cukup! Butuh " .. cost .. " RP" }
	end
	
	data.Stats.RebirthPoints = data.Stats.RebirthPoints - cost
	data.RebirthUpgrades[upgradeName] = currentLevel + 1
	
	local leaderstats = player:FindFirstChild("leaderstats")
	local pointsVal = leaderstats and leaderstats:FindFirstChild("RebirthPoints")
	if pointsVal then pointsVal.Value = data.Stats.RebirthPoints end
	
	DataManager.syncData(player)
	return { Success = true, Message = "Upgrade " .. upgradeName .. " berhasil ditingkatkan!" }
end

-- ===== DAILY REWARDS & QUESTS LOGIC =====
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
	if not data or not data.DailyRewards then return { Success = false, Error = "Data login harian error!" } end
	
	local now = os.time()
	local lastClaim = data.DailyRewards.LastClaimTime or 0
	local streak = data.DailyRewards.Streak or 0
	
	if now - lastClaim < 72000 then -- Jeda waktu 20 jam
		local nextTime = 72000 - (now - lastClaim)
		local jam = math.ceil(nextTime / 3600)
		return { Success = false, Error = "Tunggu " .. jam .. " jam lagi untuk mengeklaim!" }
	end
	
	if now - lastClaim > 172800 then -- Jeda waktu 48 jam, reset streak
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
	return { Success = true, Message = "Klaim Hari ke-" .. streak .. " Berhasil! +$" .. GameUtils.formatCompact(rewardCash) }
end

function RebirthManager:claimDailyQuest(player: Player, questId: string)
	local data = DataManager.getPlayerData(player)
	if not data or not data.Quests or not data.Quests.Daily then return { Success = false, Error = "Data misi error!" } end
	
	for _, q in ipairs(data.Quests.Daily.ActiveQuests) do
		if q.ID == questId then
			if q.Progress >= q.Target and not q.Claimed then
				q.Claimed = true
				q.Completed = true
				
				local leaderstats = player:FindFirstChild("leaderstats")
				local cashVal = leaderstats and leaderstats:FindFirstChild("Cash")
				if cashVal then cashVal.Value = cashVal.Value + q.RewardCash end
				
				DataManager.syncData(player)
				return { Success = true, Message = "Hadiah Misi diklaim! +$" .. GameUtils.formatCompact(q.RewardCash) }
			end
		end
	end
	return { Success = false, Error = "Misi belum selesai atau sudah diklaim!" }
end

function RebirthManager.incrementQuestProgress(player: Player, questType: string, amount: number)
	local data = DataManager.getPlayerData(player)
	if not data or not data.Quests then return end
	
	-- 1. Pastikan data Quests lengkap
	if not data.Quests.Daily then
		data.Quests.Daily = {
			LastGeneratedTime = 0,
			ActiveQuests = {},
		}
	end
	if not data.Quests.Milestones then
		data.Quests.Milestones = {
			TotalCarsSold = 0,
			TotalBoxesOpened = 0,
			ClaimedMilestones = {},
		}
	end
	
	generateDailyQuests(player, data)
	
	-- 2. Increment Daily Quest Progress
	for _, q in ipairs(data.Quests.Daily.ActiveQuests) do
		if q.Type == questType and not q.Completed then
			q.Progress = math.clamp(q.Progress + amount, 0, q.Target)
			if q.Progress >= q.Target then
				q.Completed = true
			end
		end
	end
	
	-- 3. Increment Lifetime Milestones Progress
	if questType == "SellCars" then
		data.Quests.Milestones.TotalCarsSold = (data.Quests.Milestones.TotalCarsSold or 0) + amount
	elseif questType == "OpenBoxes" then
		data.Quests.Milestones.TotalBoxesOpened = (data.Quests.Milestones.TotalBoxesOpened or 0) + amount
	end
	
	-- 4. Replikasi instan atribut Quests ke Client agar React UI reaktif
	local HttpService = game:GetService("HttpService")
	player:SetAttribute("Quests", HttpService:JSONEncode(data.Quests))
end

-- ===== CLAIM LIFETIME MILESTONE =====
local MILESTONES_CONFIG = {
	sold_50 = { Type = "CarsSold", Target = 50, Reward = 15000 },
	sold_150 = { Type = "CarsSold", Target = 150, Reward = 40000 },
	sold_500 = { Type = "CarsSold", Target = 500, Reward = 15000 }, -- Sesuai dengan config client
	open_25 = { Type = "BoxesOpened", Target = 25, Reward = 10000 },
	open_100 = { Type = "BoxesOpened", Target = 100, Reward = 35000 },
	open_300 = { Type = "BoxesOpened", Target = 300, Reward = 100000 },
}

function RebirthManager:claimMilestone(player: Player, milestoneId: string)
	local data = DataManager.getPlayerData(player)
	if not data or not data.Quests or not data.Quests.Milestones then
		return { Success = false, Error = "Data pencapaian tidak ditemukan!" }
	end

	local config = MILESTONES_CONFIG[milestoneId]
	if not config then
		return { Success = false, Error = "Pencapaian tidak valid!" }
	end

	-- Cek apakah sudah diklaim
	data.Quests.Milestones.ClaimedMilestones = data.Quests.Milestones.ClaimedMilestones or {}
	if data.Quests.Milestones.ClaimedMilestones[milestoneId] then
		return { Success = false, Error = "Pencapaian ini sudah diklaim!" }
	end

	-- Cek progress
	local progress = 0
	if config.Type == "CarsSold" then
		progress = data.Quests.Milestones.TotalCarsSold or 0
	elseif config.Type == "BoxesOpened" then
		progress = data.Quests.Milestones.TotalBoxesOpened or 0
	end

	if progress < config.Target then
		return { Success = false, Error = "Pencapaian belum terpenuhi! (" .. progress .. "/" .. config.Target .. ")" }
	end

	-- Proses Klaim
	data.Quests.Milestones.ClaimedMilestones[milestoneId] = true

	local leaderstats = player:FindFirstChild("leaderstats")
	local cashVal = leaderstats and leaderstats:FindFirstChild("Cash")
	if cashVal then
		cashVal.Value = cashVal.Value + config.Reward
	end

	DataManager.syncData(player)
	return { Success = true, Message = "Pencapaian diklaim! +$" .. GameUtils.formatCompact(config.Reward) }
end

-- ===== BOOTSTRAP INITIALIZATION =====
function RebirthManager.Init()
	-- Buat Networker endpoint untuk didengar dari Client React UI
	Networker.server.new("RebirthService", RebirthManager, {
		RebirthManager.requestRebirth,
		RebirthManager.purchaseRebirthUpgrade,
		RebirthManager.claimDailyReward,
		RebirthManager.claimDailyQuest,
		RebirthManager.claimMilestone,
	})

	-- Listener untuk mendeteksi penambahan Cash secara reaktif untuk misi EarnCash
	Players.PlayerAdded:Connect(function(player)
		local function setupCashListener()
			local leaderstats = player:WaitForChild("leaderstats", 15)
			if not leaderstats then return end
			local cash = leaderstats:WaitForChild("Cash", 15)
			if not cash then return end

			local lastValue = cash.Value
			cash.Changed:Connect(function(newValue)
				local diff = newValue - lastValue
				lastValue = newValue
				if diff > 0 then
					RebirthManager.incrementQuestProgress(player, "EarnCash", diff)
				end
			end)
		end

		task.spawn(setupCashListener)
	end)

	-- Tangani player yang sudah ada
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			local leaderstats = player:FindFirstChild("leaderstats")
			local cash = leaderstats and leaderstats:FindFirstChild("Cash")
			if cash then
				local lastValue = cash.Value
				cash.Changed:Connect(function(newValue)
					local diff = newValue - lastValue
					lastValue = newValue
					if diff > 0 then
						RebirthManager.incrementQuestProgress(player, "EarnCash", diff)
					end
				end)
			end
		end)
	end
	
	print("[RebirthManager] ✅ Rebirth, Daily Rewards, dan Quests Service siap digunakan.")
end

return RebirthManager

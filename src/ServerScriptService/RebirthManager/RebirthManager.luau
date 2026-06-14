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
	if not data or not data.Quests or not data.Quests.Daily then return end
	
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

-- ===== BOOTSTRAP INITIALIZATION =====
function RebirthManager.Init()
	-- Buat Networker endpoint untuk didengar dari Client React UI
	Networker.server.new("RebirthService", RebirthManager, {
		RebirthManager.requestRebirth,
		RebirthManager.purchaseRebirthUpgrade,
		RebirthManager.claimDailyReward,
		RebirthManager.claimDailyQuest,
	})
	
	print("[RebirthManager] ✅ Rebirth, Daily Rewards, dan Quests Service siap digunakan.")
end

return RebirthManager

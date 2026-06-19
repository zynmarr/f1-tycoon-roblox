local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local Networker = require(ReplicatedStorage.Packages.Networker)
local DataManager = require(game.ServerScriptService.DataManager.DataManager)

local RaceManager = {}

-- Active sessions tracking
local activeRaces = {}
local pvpChallenges = {}

-- Create a RemoteEvent for race notifications
local raceEvent = ReplicatedStorage:FindFirstChild("RaceEvent")
if not raceEvent then
	raceEvent = Instance.new("RemoteEvent")
	raceEvent.Name = "RaceEvent"
	raceEvent.Parent = ReplicatedStorage
end

-- Rarity & Variant speed multipliers
local RaritySpeeds = {
	Common = 1.0,
	Uncommon = 1.05,
	Rare = 1.10,
	Epic = 1.15,
	Legendary = 1.20,
	Mythic = 1.25,
	God = 1.30,
	Celestial = 1.35,
}

local VariantSpeeds = {
	Normal = 1.0,
	Carbon = 1.05,
	Shiny = 1.10,
	Golden = 1.15,
	Rainbow = 1.20,
	Frostbite = 1.25,
	Galaxy = 1.30,
	Hellfire = 1.35,
}

-- Helper: find player's car from backpack, character, or data matching Name, Rarity, and Variant if specified
local function getPlayerCar(player: Player, carInfo: any)
	local carName = ""
	local targetRarity = nil
	local targetVariant = nil

	if type(carInfo) == "table" then
		carName = carInfo.Name
		targetRarity = carInfo.Rarity
		targetVariant = carInfo.Variant
	elseif type(carInfo) == "string" then
		carName = carInfo
	else
		return nil
	end

	local char = player.Character
	local backpack = player:FindFirstChild("Backpack")

	local function matchTool(tool: Instance)
		if not GameUtils.isCar(tool) then
			return false
		end
		if tool.Name ~= carName then
			return false
		end
		local toolRarity = tool:GetAttribute("Rarity") or "Common"
		local toolVariant = tool:GetAttribute("Variant") or "Normal"
		if targetRarity and toolRarity ~= targetRarity then
			return false
		end
		if targetVariant and toolVariant ~= targetVariant then
			return false
		end
		return true
	end

	if char then
		for _, child in ipairs(char:GetChildren()) do
			if matchTool(child) then
				return {
					Name = child.Name,
					Rarity = child:GetAttribute("Rarity") or "Common",
					Variant = child:GetAttribute("Variant") or "Normal",
				}
			end
		end
	end
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if matchTool(child) then
				return {
					Name = child.Name,
					Rarity = child:GetAttribute("Rarity") or "Common",
					Variant = child:GetAttribute("Variant") or "Normal",
				}
			end
		end
	end

	local data = DataManager.getPlayerData(player)
	if data and data.Inventory then
		for _, item in ipairs(data.Inventory) do
			if item.Name == carName then
				local attrs = item.Attributes or {}
				local itemRarity = attrs.Rarity or "Common"
				local itemVariant = attrs.Variant or "Normal"
				if targetRarity and itemRarity ~= targetRarity then
					continue
				end
				if targetVariant and itemVariant ~= targetVariant then
					continue
				end
				return {
					Name = item.Name,
					Rarity = itemRarity,
					Variant = itemVariant,
				}
			end
		end
	end
	return nil
end

-- Deterministic positional formula mirrored from client
local function getPositionAtTime(t: number, baseSpeed: number, multiplier: number, seed: number, index: number): number
	if t < 0 then
		return 0
	end
	local dist = baseSpeed * t
	local launchBoost = 0
	if multiplier > 1.0 then
		local maxDuration = math.min(t, 8)
		launchBoost = (multiplier - 1) * baseSpeed * (1 - math.exp(-0.5 * maxDuration)) / 0.5
	elseif multiplier < 1.0 then
		launchBoost = (multiplier - 1) * baseSpeed * math.min(t, 10)
	end
	local varianceAmp = (multiplier < 1.0) and 0.1 or 0.5
	local variance = math.sin(t * 0.7 + index * 1.5 + seed) * varianceAmp
	return dist + launchBoost + variance
end

-- =====================================================
-- Networker Endpoints
-- =====================================================

function RaceManager:getRaceStats(player: Player)
	local data = DataManager.getPlayerData(player)
	if data and data.Stats and data.Stats.RaceStats then
		return data.Stats.RaceStats
	end
	return { Wins = 0, Losses = 0, CashEarned = 0 }
end

function RaceManager:startAIRace(player: Player, carInfo: any, difficulty: string)
	print(
		"[RaceManager:startAIRace] self:",
		typeof(self),
		tostring(self),
		"player:",
		typeof(player),
		tostring(player),
		"carInfo:",
		typeof(carInfo),
		tostring(carInfo),
		"difficulty:",
		typeof(difficulty),
		tostring(difficulty)
	)
	if not player or not player.Parent then
		return { Success = false, Error = "Pemain tidak ditemukan" }
	end
	if (type(carInfo) ~= "string" and type(carInfo) ~= "table") or type(difficulty) ~= "string" then
		return { Success = false, Error = "Parameter tidak valid" }
	end

	local car = getPlayerCar(player, carInfo)
	if not car then
		return { Success = false, Error = "Mobil tidak ditemukan di garasi/tas Anda" }
	end

	local baseSpeed = 0.5 * (RaritySpeeds[car.Rarity] or 1.0) * (VariantSpeeds[car.Variant] or 1.0)

	local aiSpeeds = {}
	if difficulty == "Easy" then
		aiSpeeds = { 0.42, 0.44, 0.46 }
	elseif difficulty == "Medium" then
		aiSpeeds = { 0.48, 0.50, 0.52 }
	elseif difficulty == "Hard" then
		aiSpeeds = { 0.54, 0.56, 0.58 }
	else
		return { Success = false, Error = "Kesulitan AI tidak valid (Easy/Medium/Hard)" }
	end

	local raceId = HttpService:GenerateGUID(false)
	local seed = math.random(1, 100000)
	local startTime = workspace:GetServerTimeNow() + 7

	local session = {
		RaceId = raceId,
		Type = "AI",
		StartTime = startTime,
		Laps = 3,
		Seed = seed,
		Difficulty = difficulty,
		Winner = nil,
		Participants = {
			[tostring(player.UserId)] = {
				Name = player.Name,
				CarName = car.Name,
				BaseSpeed = baseSpeed,
				Multiplier = 1.0,
				IsHuman = true,
			},
		},
	}

	local aiCarNames = {
		"Ferrari – SF23 (Charles Leclerc)",
		"Red Bull – RB19 (Max Verstappen)",
		"Mercedes – W14 (Lewis Hamilton)",
	}

	for i, aiSpeed in ipairs(aiSpeeds) do
		local aiMultiplier = 1.0
		if difficulty == "Medium" then
			aiMultiplier = 1.12
		elseif difficulty == "Hard" then
			aiMultiplier = 1.25
		end

		session.Participants["AI_" .. i] = {
			Name = "AI " .. (aiCarNames[i] or "Rival"),
			CarName = aiCarNames[i] or ("AI Car " .. i),
			BaseSpeed = aiSpeed,
			Multiplier = aiMultiplier,
			IsHuman = false,
		}
	end

	activeRaces[raceId] = session

	return {
		Success = true,
		RaceId = raceId,
		StartTime = startTime,
		Seed = seed,
		Difficulty = difficulty,
		Participants = session.Participants,
	}
end

function RaceManager:sendPvPChallenge(player: Player, opponentName: string, carInfo: any, betAmount: number)
	if not player or not player.Parent then
		return { Success = false, Error = "Pemain tidak ditemukan" }
	end
	if
		type(opponentName) ~= "string"
		or (type(carInfo) ~= "string" and type(carInfo) ~= "table")
		or type(betAmount) ~= "number"
	then
		return { Success = false, Error = "Parameter tidak valid" }
	end

	betAmount = math.floor(betAmount)
	-- ANTI-CHEAT: Defensive comparison guarding against NaN betAmount values
	if not (betAmount >= 0 and betAmount <= 1000000000) then
		return { Success = false, Error = "Jumlah taruhan tidak valid" }
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash or cash.Value < betAmount then
		return { Success = false, Error = "Saldo Cash Anda tidak mencukupi" }
	end

	local car = getPlayerCar(player, carInfo)
	if not car then
		return { Success = false, Error = "Mobil tidak ditemukan" }
	end

	local opponent = Players:FindFirstChild(opponentName)
	if not opponent or opponent == player then
		return { Success = false, Error = "Lawan tidak ditemukan atau tidak valid" }
	end

	local oppCash = opponent:FindFirstChild("leaderstats") and opponent.leaderstats:FindFirstChild("Cash")
	if not oppCash or oppCash.Value < betAmount then
		return { Success = false, Error = "Lawan tidak memiliki cukup saldo Cash" }
	end

	local challengeId = HttpService:GenerateGUID(false)
	pvpChallenges[challengeId] = {
		ChallengeId = challengeId,
		Challenger = player,
		Opponent = opponent,
		ChallengerCar = car,
		BetAmount = betAmount,
		Time = tick(),
	}

	pcall(function()
		raceEvent:FireClient(opponent, "ChallengeReceived", {
			ChallengerName = player.Name,
			BetAmount = betAmount,
			ChallengeId = challengeId,
		})
	end)

	return { Success = true, Message = "Tantangan berhasil dikirim ke " .. opponentName }
end

function RaceManager:acceptPvPChallenge(player: Player, challengeId: string, carInfo: any)
	if not player or not player.Parent then
		return { Success = false, Error = "Pemain tidak ditemukan" }
	end
	if type(challengeId) ~= "string" or (type(carInfo) ~= "string" and type(carInfo) ~= "table") then
		return { Success = false, Error = "Parameter tidak valid" }
	end

	local challenge = pvpChallenges[challengeId]
	if not challenge then
		return { Success = false, Error = "Tantangan tidak ditemukan atau sudah kadaluarsa" }
	end
	if challenge.Opponent ~= player then
		return { Success = false, Error = "Tantangan ini bukan untuk Anda" }
	end

	local challenger = challenge.Challenger
	if not challenger or not challenger.Parent then
		return { Success = false, Error = "Penantang telah keluar dari server" }
	end

	-- Safe leaderstats lookup to prevent nil dereference runtime error
	local challStats = challenger:FindFirstChild("leaderstats")
	local oppStats = player:FindFirstChild("leaderstats")
	local challCash = challStats and challStats:FindFirstChild("Cash")
	local oppCash = oppStats and oppStats:FindFirstChild("Cash")
	if not challCash or not oppCash then
		return { Success = false, Error = "Data keuangan tidak siap" }
	end

	if challCash.Value < challenge.BetAmount then
		return { Success = false, Error = "Penantang tidak lagi memiliki saldo cukup" }
	end
	if oppCash.Value < challenge.BetAmount then
		return { Success = false, Error = "Saldo Cash Anda tidak mencukupi" }
	end

	local car = getPlayerCar(player, carInfo)
	if not car then
		return { Success = false, Error = "Mobil tidak ditemukan" }
	end

	-- Lock the bet from both players
	challCash.Value -= challenge.BetAmount
	oppCash.Value -= challenge.BetAmount
	DataManager.syncData(challenger)
	DataManager.syncData(player)

	local cSpeed = 0.5
		* (RaritySpeeds[challenge.ChallengerCar.Rarity] or 1.0)
		* (VariantSpeeds[challenge.ChallengerCar.Variant] or 1.0)
	local oSpeed = 0.5 * (RaritySpeeds[car.Rarity] or 1.0) * (VariantSpeeds[car.Variant] or 1.0)

	local raceId = HttpService:GenerateGUID(false)
	local seed = math.random(1, 100000)
	local startTime = workspace:GetServerTimeNow() + 7

	local session = {
		RaceId = raceId,
		Type = "PvP",
		StartTime = startTime,
		Laps = 3,
		Seed = seed,
		BetAmount = challenge.BetAmount,
		Winner = nil,
		Participants = {
			[tostring(challenger.UserId)] = {
				Name = challenger.Name,
				CarName = challenge.ChallengerCar.Name,
				BaseSpeed = cSpeed,
				Multiplier = 1.0,
				IsHuman = true,
			},
			[tostring(player.UserId)] = {
				Name = player.Name,
				CarName = car.Name,
				BaseSpeed = oSpeed,
				Multiplier = 1.0,
				IsHuman = true,
			},
		},
	}

	activeRaces[raceId] = session
	pvpChallenges[challengeId] = nil

	local startData = {
		RaceId = raceId,
		StartTime = startTime,
		Seed = seed,
		BetAmount = challenge.BetAmount,
		Participants = session.Participants,
	}
	pcall(function()
		raceEvent:FireClient(challenger, "StartPvPRace", startData)
		raceEvent:FireClient(player, "StartPvPRace", startData)
	end)

	return { Success = true, Message = "Tantangan diterima!" }
end

function RaceManager:submitLaunchTime(player: Player, raceId: string, reactionTime: number)
	if not player or not player.Parent then
		return { Success = false, Error = "Pemain tidak ditemukan" }
	end
	if type(raceId) ~= "string" or type(reactionTime) ~= "number" then
		return { Success = false, Error = "Parameter tidak valid" }
	end

	local session = activeRaces[raceId]
	if not session then
		return { Success = false, Error = "Sesi balapan tidak ditemukan" }
	end

	local participant = session.Participants[tostring(player.UserId)]
	if not participant then
		return { Success = false, Error = "Anda bukan bagian dari balapan ini" }
	end

	if participant.Submitted then
		return { Success = false, Error = "Waktu reaksi sudah pernah disubmit" }
	end
	participant.Submitted = true

	-- ANTI-CHEAT: Validate submission latency to prevent clients spoofing early times
	local serverTime = workspace:GetServerTimeNow()
	local elapsed = serverTime - session.StartTime
	if elapsed > 2.0 then
		-- Late launch forced to slow
		reactionTime = 999
	else
		-- Check if the client's reported reactionTime deviates too much from server time
		local latency = serverTime - (session.StartTime + reactionTime)
		if math.abs(latency) > 0.5 then
			reactionTime = elapsed
		end
	end

	local multiplier = 1.0
	local msg = "Launch Lambat!"

	if reactionTime < 0 then
		multiplier = 0.7
		msg = "JUMP START! Penalti diterapkan"
	elseif reactionTime <= 0.15 then
		multiplier = 1.25
		msg = "PERFECT LAUNCH!"
	elseif reactionTime <= 0.35 then
		multiplier = 1.12
		msg = "GOOD LAUNCH!"
	end

	participant.Multiplier = multiplier
	participant.ReactionTime = reactionTime
	return { Success = true, Multiplier = multiplier, Message = msg }
end

function RaceManager:getRaceOutcome(player: Player, raceId: string)
	if not player or not player.Parent then
		return { Success = false, Error = "Pemain tidak ditemukan" }
	end

	local session = activeRaces[raceId]
	if not session then
		return { Success = false, Error = "Balapan sudah diselesaikan atau tidak ditemukan" }
	end
	if not session.Participants[tostring(player.UserId)] then
		return { Success = false, Error = "Anda bukan peserta balapan ini" }
	end

	-- Deterministic binary-search: find finish time per participant
	local finishTimes = {}
	local targetDistance = 6 * math.pi -- 3 laps around unit circle

	for key, part in pairs(session.Participants) do
		local index = 1
		if key == tostring(player.UserId) then
			index = 1
		elseif key:sub(1, 3) == "AI_" then
			index = 3 + (tonumber(key:sub(4)) or 0)
		else
			index = 2
		end

		local low, high = 0, 200
		for _ = 1, 25 do
			local mid = (low + high) / 2
			if getPositionAtTime(mid, part.BaseSpeed, part.Multiplier, session.Seed, index) < targetDistance then
				low = mid
			else
				high = mid
			end
		end
		finishTimes[key] = low
	end

	-- Sort by finish time
	local ranks = {}
	for key, part in pairs(session.Participants) do
		table.insert(ranks, { Key = key, Name = part.Name, FinishTime = finishTimes[key] })
	end
	table.sort(ranks, function(a, b)
		return a.FinishTime < b.FinishTime
	end)

	local playerRank = #ranks
	for rank, rInfo in ipairs(ranks) do
		if rInfo.Key == tostring(player.UserId) then
			playerRank = rank
			break
		end
	end

	local isWin = (playerRank == 1)
	local rewardCash = 0

	if session.Type == "AI" and isWin then
		if session.Difficulty == "Easy" then
			rewardCash = 1000
		elseif session.Difficulty == "Medium" then
			rewardCash = 5000
		elseif session.Difficulty == "Hard" then
			rewardCash = 25000
		end
	elseif session.Type == "PvP" and isWin then
		rewardCash = session.BetAmount * 2
	end

	-- Update profile stats safely and track WinStreak and PvPWins
	local data = DataManager.getPlayerData(player)
	if data and data.Stats then
		if not data.Stats.RaceStats then
			data.Stats.RaceStats = { Wins = 0, Losses = 0, CashEarned = 0, WinStreak = 0, PvPWins = 0 }
		end
		local rStats = data.Stats.RaceStats
		if not rStats.WinStreak then
			rStats.WinStreak = 0
		end
		if not rStats.PvPWins then
			rStats.PvPWins = 0
		end

		if isWin then
			rStats.Wins += 1
			rStats.WinStreak += 1
			if session.Type == "PvP" then
				rStats.PvPWins += 1
			end
			rStats.CashEarned += rewardCash
			if rewardCash > 0 then
				local leaderstats = player:FindFirstChild("leaderstats")
				local cashVal = leaderstats and leaderstats:FindFirstChild("Cash")
				if cashVal then
					cashVal.Value += rewardCash
				end
			end
		else
			rStats.Losses += 1
			rStats.WinStreak = 0
		end
		DataManager.syncData(player)
	end

	-- PvP Race Outcome Deletion Race Condition Fix: Wait for all human players to query outcome
	session.RetrievedOutcomes = session.RetrievedOutcomes or {}
	session.RetrievedOutcomes[tostring(player.UserId)] = true

	local allRetrieved = true
	for key, part in pairs(session.Participants) do
		if part.IsHuman and not session.RetrievedOutcomes[key] then
			allRetrieved = false
			break
		end
	end
	if allRetrieved then
		activeRaces[raceId] = nil
	end
	return { Success = true, Ranks = ranks, PlayerRank = playerRank, RewardCash = rewardCash }
end

-- =====================================================
-- Bootstrap
-- =====================================================
function RaceManager.Init()
	Networker.server.new("RaceService", RaceManager, {
		RaceManager.getRaceStats,
		RaceManager.startAIRace,
		RaceManager.sendPvPChallenge,
		RaceManager.acceptPvPChallenge,
		RaceManager.submitLaunchTime,
		RaceManager.getRaceOutcome,
	})
	print("[RaceManager] RaceService Networker endpoints berhasil didaftarkan.")

	-- Expire stale PvP challenges and cleanup stale active races to prevent memory leaks
	task.spawn(function()
		while true do
			task.wait(60)
			local now = tick()
			for id, challenge in pairs(pvpChallenges) do
				if now - challenge.Time > 30 then
					pvpChallenges[id] = nil
				end
			end

			local serverTime = workspace:GetServerTimeNow()
			for id, session in pairs(activeRaces) do
				if serverTime - session.StartTime > 180 then
					activeRaces[id] = nil
				end
			end
		end
	end)
end

return RaceManager

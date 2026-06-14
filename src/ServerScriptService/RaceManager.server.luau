--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
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

-- Rarity & Variant speed config
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

local function getPlayerCar(player: Player, carName: string)
	local char = player.Character
	local backpack = player:FindFirstChild("Backpack")
	local tool = (char and char:FindFirstChild(carName)) or (backpack and backpack:FindFirstChild(carName))
	
	if tool and GameUtils.isCar(tool) then
		return {
			Name = tool.Name,
			Rarity = tool:GetAttribute("Rarity") or "Common",
			Variant = tool:GetAttribute("Variant") or "Normal",
		}
	end

	-- Check data store
	local data = DataManager.getPlayerData(player)
	if data and data.Inventory then
		for _, item in ipairs(data.Inventory) do
			if item.Name == carName then
				local attrs = item.Attributes or {}
				return {
					Name = item.Name,
					Rarity = attrs.Rarity or "Common",
					Variant = attrs.Variant or "Normal",
				}
			end
		end
	end
	return nil
end

local function getPositionAtTime(t, baseSpeed, multiplier, seed, index)
	if t < 0 then
		return 0
	end
	local dist = baseSpeed * t

	local launchBoost = 0
	if multiplier > 1.0 then
		local maxDuration = math.min(t, 8)
		launchBoost = (multiplier - 1) * baseSpeed * (1 - math.exp(-0.5 * maxDuration)) / 0.5
	elseif multiplier < 1.0 then
		local penaltyDuration = math.min(t, 10)
		launchBoost = (multiplier - 1) * baseSpeed * penaltyDuration
	end

	local variance = math.sin(t * 0.7 + index * 1.5 + seed) * 0.5
	return dist + launchBoost + variance
end

-- Expose Networker Endpoints
function RaceManager.getRaceStats(player: Player)
	local data = DataManager.getPlayerData(player)
	if data and data.Stats and data.Stats.RaceStats then
		return data.Stats.RaceStats
	end
	return { Wins = 0, Losses = 0, CashEarned = 0 }
end

function RaceManager.startAIRace(player: Player, carName: string, difficulty: string)
	if not player or not player.Parent then return { Success = false, Error = "Pemain tidak ditemukan" } end
	if type(carName) ~= "string" or type(difficulty) ~= "string" then
		return { Success = false, Error = "Parameter tidak valid" }
	end

	local car = getPlayerCar(player, carName)
	if not car then
		return { Success = false, Error = "Mobil tidak ditemukan di garasi/tas Anda" }
	end

	-- Determine base speed
	local baseSpeedMultiplier = RaritySpeeds[car.Rarity] or 1.0
	local variantSpeedMultiplier = VariantSpeeds[car.Variant] or 1.0
	local baseSpeed = 0.5 * baseSpeedMultiplier * variantSpeedMultiplier

	-- Setup AI speeds and cars
	local aiSpeeds = {}
	if difficulty == "Easy" then
		aiSpeeds = { 0.42, 0.44, 0.46 }
	elseif difficulty == "Medium" then
		aiSpeeds = { 0.48, 0.50, 0.52 }
	elseif difficulty == "Hard" then
		aiSpeeds = { 0.54, 0.56, 0.58 }
	else
		return { Success = false, Error = "Kesulitan AI tidak valid" }
	end

	local raceId = HttpService:GenerateGUID(false)
	local seed = math.random(1, 100000)
	local startTime = workspace:GetServerTimeNow() + 7 -- 7 seconds countdown

	-- Setup active session
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
			}
		}
	}

	-- Add AI participants
	local aiCars = {
		"Ferrari – SF23 (Standar) (Charles Leclerc)",
		"Red Bull – RB19 (Standar) (Max Verstappen)",
		"Mercedes – W14 (Standar) (Lewis Hamilton)",
	}

	for i, aiSpeed in ipairs(aiSpeeds) do
		-- Randomize AI reaction
		local aiReact = 0.1 + math.random() * 0.7
		local aiMultiplier = 1.0
		if difficulty == "Easy" then
			aiReact = 0.4 + math.random() * 0.4
		elseif difficulty == "Medium" then
			aiReact = 0.2 + math.random() * 0.25
			aiMultiplier = 1.12
		elseif difficulty == "Hard" then
			aiReact = 0.1 + math.random() * 0.15
			aiMultiplier = 1.25
		end

		session.Participants["AI_" .. i] = {
			Name = "AI " .. aiCars[i]:match("–%s*([^(]+)"),
			CarName = aiCars[i],
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

function RaceManager.sendPvPChallenge(player: Player, opponentName: string, carName: string, betAmount: number)
	if not player or not player.Parent then return { Success = false, Error = "Pemain tidak ditemukan" } end
	if type(opponentName) ~= "string" or type(carName) ~= "string" or type(betAmount) ~= "number" then
		return { Success = false, Error = "Parameter tidak valid" }
	end

	betAmount = math.floor(betAmount)
	if betAmount < 0 or betAmount > 1000000000 then
		return { Success = false, Error = "Jumlah taruhan tidak valid" }
	end

	-- Check Challenger cash
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash or cash.Value < betAmount then
		return { Success = false, Error = "Saldo Cash Anda tidak mencukupi" }
	end

	-- Check Challenger car
	local car = getPlayerCar(player, carName)
	if not car then
		return { Success = false, Error = "Mobil tidak ditemukan di tas/garasi Anda" }
	end

	-- Find Opponent
	local opponent = Players:FindFirstChild(opponentName)
	if not opponent or opponent == player then
		return { Success = false, Error = "Lawan tidak ditemukan atau tidak valid" }
	end

	-- Check Opponent cash
	local oppLeaderstats = opponent:FindFirstChild("leaderstats")
	local oppCash = oppLeaderstats and oppLeaderstats:FindFirstChild("Cash")
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

	-- Notify opponent
	pcall(function()
		raceEvent:FireClient(opponent, "ChallengeReceived", {
			ChallengerName = player.Name,
			BetAmount = betAmount,
			ChallengeId = challengeId,
		})
	end)

	return { Success = true, Message = "Tantangan berhasil dikirim ke " .. opponentName }
end

function RaceManager.acceptPvPChallenge(player: Player, challengeId: string, carName: string)
	if not player or not player.Parent then return { Success = false, Error = "Pemain tidak ditemukan" } end
	if type(challengeId) ~= "string" or type(carName) ~= "string" then
		return { Success = false, Error = "Parameter tidak valid" }
	end

	local challenge = pvpChallenges[challengeId]
	if not challenge then
		return { Success = false, Error = "Tantangan tidak ditemukan atau sudah kadaluarsa" }
	end

	if challenge.Opponent ~= player then
		return { Success = false, Error = "Tantangan ini bukan untuk Anda" }
	end

	-- Verify both player cash again
	local challenger = challenge.Challenger
	if not challenger or not challenger.Parent then
		return { Success = false, Error = "Penantang telah keluar dari server" }
	end

	local challCash = challenger.leaderstats.Cash
	local oppCash = player.leaderstats.Cash

	if challCash.Value < challenge.BetAmount then
		return { Success = false, Error = "Penantang tidak lagi memiliki saldo Cash yang cukup" }
	end
	if oppCash.Value < challenge.BetAmount then
		return { Success = false, Error = "Saldo Cash Anda tidak mencukupi" }
	end

	-- Get opponent's car
	local car = getPlayerCar(player, carName)
	if not car then
		return { Success = false, Error = "Mobil tidak ditemukan di tas/garasi Anda" }
	end

	-- Deduct Cash from both
	challCash.Value -= challenge.BetAmount
	oppCash.Value -= challenge.BetAmount
	DataManager.syncData(challenger)
	DataManager.syncData(player)

	-- Generate Race
	local cSpeed = 0.5 * (RaritySpeeds[challenge.ChallengerCar.Rarity] or 1.0) * (VariantSpeeds[challenge.ChallengerCar.Variant] or 1.0)
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
			}
		}
	}

	activeRaces[raceId] = session
	pvpChallenges[challengeId] = nil

	-- Notify Challenger & Opponent to start Race UI
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

function RaceManager.submitLaunchTime(player: Player, raceId: string, reactionTime: number)
	if not player or not player.Parent then return { Success = false, Error = "Pemain tidak ditemukan" } end
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

	-- Anti-Cheat / Double submission check
	if participant.Submitted then
		return { Success = false, Error = "Waktu reaksi sudah pernah disubmit" }
	end
	participant.Submitted = true

	local multiplier = 1.0
	local msg = "Launch Lambat!"

	if reactionTime < 0 then
		multiplier = 0.7
		msg = "JUMP START! Penalti 10 detik"
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

function RaceManager.getRaceOutcome(player: Player, raceId: string)
	if not player or not player.Parent then return { Success = false, Error = "Pemain tidak ditemukan" } end
	local session = activeRaces[raceId]
	if not session then
		return { Success = false, Error = "Balapan sudah diselesaikan atau tidak ditemukan" }
	end

	-- Verify if player is participant
	if not session.Participants[tostring(player.UserId)] then
		return { Success = false, Error = "Anda bukan peserta balapan ini" }
	end

	-- Run simulation to see who wins (100% deterministic)
	local finishTimes = {}
	local targetDistance = 6 * math.pi

	for key, part in pairs(session.Participants) do
		local low = 0
		local high = 100
		local index = 1
		if key == tostring(player.UserId) then
			index = 1
		elseif key:sub(1, 3) == "AI_" then
			index = 3 + (tonumber(key:sub(4)) or 0)
		else
			index = 2
		end

		for _ = 1, 20 do
			local mid = (low + high) / 2
			local pos = getPositionAtTime(mid, part.BaseSpeed, part.Multiplier, session.Seed, index)
			if pos < targetDistance then
				low = mid
			else
				high = mid
			end
		end
		finishTimes[key] = low
	end

	-- Sort participants
	local ranks = {}
	for key, part in pairs(session.Participants) do
		table.insert(ranks, { Key = key, Name = part.Name, FinishTime = finishTimes[key] })
	end
	table.sort(ranks, function(a, b)
		return a.FinishTime < b.FinishTime
	end)

	local playerRank = 4
	for rank, rInfo in ipairs(ranks) do
		if rInfo.Key == tostring(player.UserId) then
			playerRank = rank
			break
		end
	end

	local rewardCash = 0
	local isWin = (playerRank == 1)

	-- Award prizes
	if session.Type == "AI" then
		if isWin then
			if session.Difficulty == "Easy" then
				rewardCash = 1000
			elseif session.Difficulty == "Medium" then
				rewardCash = 5000
			elseif session.Difficulty == "Hard" then
				rewardCash = 25000
			end
		end
	elseif session.Type == "PvP" then
		if isWin then
			rewardCash = session.BetAmount * 2
		end
	end

	-- Apply rewards & update profile
	local data = DataManager.getPlayerData(player)
	if data and data.Stats then
		if not data.Stats.RaceStats then
			data.Stats.RaceStats = { Wins = 0, Losses = 0, CashEarned = 0 }
		end

		local rStats = data.Stats.RaceStats
		if isWin then
			rStats.Wins += 1
			rStats.CashEarned += rewardCash
			player.leaderstats.Cash.Value += rewardCash
		else
			rStats.Losses += 1
		end
		
		if isWin and (session.Difficulty == "Hard" or session.Type == "PvP") then
			player.leaderstats.Level.Value += 1
		end

		DataManager.syncData(player)
	end

	-- Clean up session
	activeRaces[raceId] = nil

	return {
		Success = true,
		Ranks = ranks,
		PlayerRank = playerRank,
		RewardCash = rewardCash,
	}
end

function RaceManager.Init()
	Networker.server.new("RaceService", RaceManager, {
		RaceManager.getRaceStats,
		RaceManager.startAIRace,
		RaceManager.sendPvPChallenge,
		RaceManager.acceptPvPChallenge,
		RaceManager.submitLaunchTime,
		RaceManager.getRaceOutcome,
	})
	print("[RaceManager] Server endpoints registered successfully.")
end

-- Clear expired challenges & races (every 60s)
task.spawn(function()
	while true do
		task.wait(60)
		local now = tick()
		for id, challenge in pairs(pvpChallenges) do
			if now - challenge.Time > 30 then
				pvpChallenges[id] = nil
			end
		end
	end
end)

return RaceManager

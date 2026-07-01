--!strict
local EventVariantManager = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local EventVariantConfig = require(ReplicatedStorage:WaitForChild("EventVariantConfig"))

-- Track active player loops to prevent duplicate threads and handle clean exits
local activeLoops: { [Player]: string } = {}

-- Track berapa player sedang dalam state Active (untuk menentukan kapan bersihkan assets)
local activeEventCount = 0

-- ============================================================
-- ASSET SYNC: Duplikat EventAssets dari ServerStorage ke
-- ReplicatedStorage agar bisa diakses client
-- ============================================================
local function ensureEventAssetsInReplicated()
	if ReplicatedStorage:FindFirstChild("EventAssets") then
		return -- Sudah ada, tidak perlu duplikat lagi
	end

	local sourceFolder = ServerStorage:FindFirstChild("EventAssets")
	if not sourceFolder then
		warn("[EventVariantManager] EventAssets tidak ditemukan di ServerStorage!")
		return
	end

	local cloned = sourceFolder:Clone()
	cloned.Parent = ReplicatedStorage
	print("[EventVariantManager] EventAssets disalin dari ServerStorage ke ReplicatedStorage")
end

local function cleanupEventAssetsFromReplicated()
	if activeEventCount > 0 then
		return -- Masih ada player dengan event aktif, jangan bersihkan
	end

	local folder = ReplicatedStorage:FindFirstChild("EventAssets")
	if folder then
		folder:Destroy()
		print("[EventVariantManager] EventAssets dihapus dari ReplicatedStorage (tidak ada event aktif)")
	end
end

-- Helper to randomly select a variant key
local function getRandomVariant(): string
	local keys = {}
	for key, _ in pairs(EventVariantConfig.Variants) do
		table.insert(keys, key)
	end
	return keys[math.random(1, #keys)]
end

function EventVariantManager.startPlayerLoop(player: Player)
	if activeLoops[player] then
		return -- Loop already running for this player
	end

	-- Create a unique session ID for this player's loop
	local loopId = game:GetService("HttpService"):GenerateGUID(false)
	activeLoops[player] = loopId

	task.spawn(function()
		-- Determine initial state (70% Rest, 30% Active)
		local isInitialRest = math.random(1, 100) <= EventVariantConfig.Chances.Rest
		local currentState = isInitialRest and "Rest" or "Active"

		-- Pre-roll the next variant if starting in Rest
		local nextVariant = getRandomVariant()

		while player and player.Parent and activeLoops[player] == loopId do
			if currentState == "Active" then
				-- 1. Setup Active Event State
				local chosenVariant = getRandomVariant()
				local varConfig = EventVariantConfig.Variants[chosenVariant]
				local duration = EventVariantConfig.Durations.Active

				-- Pastikan EventAssets tersedia di ReplicatedStorage untuk client
				activeEventCount += 1
				ensureEventAssetsInReplicated()

				player:SetAttribute("ActiveEventVariant", chosenVariant)
				player:SetAttribute("ActiveEventBoost", varConfig.Boost)
				player:SetAttribute("EventStatus", "Active")
				player:SetAttribute("EventEndTime", workspace:GetServerTimeNow() + duration)
				player:SetAttribute("EventNextVariant", "None")

				-- Wait with 1-second ticks for safety and fast termination
				local elapsed = 0
				while elapsed < duration and player.Parent and activeLoops[player] == loopId do
					task.wait(1)
					elapsed = elapsed + 1
				end

				-- Event selesai untuk player ini, kurangi counter
				activeEventCount -= 1
				cleanupEventAssetsFromReplicated()

				-- Transition to Rest next
				currentState = "Rest"
				nextVariant = getRandomVariant()
			else
				-- 2. Setup Rest State
				local duration = math.random(EventVariantConfig.Durations.RestMin, EventVariantConfig.Durations.RestMax)

				player:SetAttribute("ActiveEventVariant", "None")
				player:SetAttribute("ActiveEventBoost", 0)
				player:SetAttribute("EventStatus", "Rest")
				player:SetAttribute("EventEndTime", workspace:GetServerTimeNow() + duration)
				player:SetAttribute("EventNextVariant", nextVariant)

				-- Wait with 1-second ticks
				local elapsed = 0
				while elapsed < duration and player.Parent and activeLoops[player] == loopId do
					task.wait(1)
					elapsed = elapsed + 1
				end

				-- Transition to Active next
				currentState = "Active"
			end
		end
	end)
end

function EventVariantManager.stopPlayerLoop(player: Player)
	activeLoops[player] = nil
end

-- Cleanup on shutdown
game:BindToClose(function()
	table.clear(activeLoops)
	activeEventCount = 0
	cleanupEventAssetsFromReplicated()
end)

-- Cleanup saat player keluar
Players.PlayerRemoving:Connect(function(player)
	if activeLoops[player] then
		-- Jika player yang keluar sedang dalam event Active, kurangi counter
		if player:GetAttribute("EventStatus") == "Active" then
			activeEventCount = math.max(0, activeEventCount - 1)
			cleanupEventAssetsFromReplicated()
		end
		activeLoops[player] = nil
	end
end)

return EventVariantManager

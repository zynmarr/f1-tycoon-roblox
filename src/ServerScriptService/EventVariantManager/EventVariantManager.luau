--!strict
local EventVariantManager = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventVariantConfig = require(ReplicatedStorage:WaitForChild("EventVariantConfig") :: ModuleScript)

-- Track active player loops to prevent duplicate threads and handle clean exits
local activeLoops: { [Player]: string } = {}

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
end)

return EventVariantManager

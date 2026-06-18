local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))

-- Buat RemoteEvent untuk teleportasi (harus dibuat di server)
local teleportEvent = Instance.new("RemoteEvent")
teleportEvent.Name = "TeleportEvent"
teleportEvent.Parent = ReplicatedStorage

-- Rate limiting
local COOLDOWN = 2 -- detik
local lastTeleport = {}

Players.PlayerRemoving:Connect(function(player)
	lastTeleport[player] = nil
end)

teleportEvent.OnServerEvent:Connect(function(player, destination)
	-- Anti-spam
	local now = tick()
	if lastTeleport[player] and now - lastTeleport[player] < COOLDOWN then
		return
	end
	lastTeleport[player] = now

	-- Validasi parameter
	if type(destination) ~= "string" then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local plot = GameUtils.getPlayerPlot(player)
	if not plot then
		return
	end

	if destination == "Home" then
		local spawnLocation = plot:FindFirstChild("SpawnLocation")
		if spawnLocation then
			character:PivotTo(spawnLocation.CFrame * CFrame.new(0, 3, 0))
		end
	elseif destination == "SellArea" then
		local sellArea = GameUtils.getPlotSellShopArea(plot, "SellArea")
		local centerArea = sellArea and sellArea:FindFirstChild("LightCore")
		if sellArea and centerArea then
			character:PivotTo(centerArea.CFrame * CFrame.new(0, 0, 10))
		end
	elseif destination == "ShopArea" then
		local sellArea = GameUtils.getPlotSellShopArea(plot, "ShopArea")
		local centerArea = sellArea and sellArea:FindFirstChild("LightCore")
		if sellArea and centerArea then
			character:PivotTo(centerArea.CFrame * CFrame.new(0, 0, 10))
		end
	end
end)

print("[TeleportHandler] Server-side teleportation handler ready!")

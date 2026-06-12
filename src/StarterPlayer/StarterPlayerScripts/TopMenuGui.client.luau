local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local topMenuGui = playerGui:WaitForChild("TopMenuGui")
local frame = topMenuGui:WaitForChild("Frame")

local homeBtn = frame:WaitForChild("HomeButton")
local sellBtn = frame:WaitForChild("SellerButton")

homeBtn.MouseButton1Click:Connect(function()
	local plot = GameUtils.getPlayerPlot(player)
	if plot then
		local spawnLocation = plot:FindFirstChild("SpawnLocation")
		if spawnLocation then
			local character = player.Character
			if character then
				character:PivotTo(spawnLocation.CFrame * CFrame.new(0, 3, 0))
				print("GO TO MY PLOT: " .. plot.Name)
			end
		end
	end
end)

sellBtn.MouseButton1Click:Connect(function()
	local plot = GameUtils.getPlayerPlot(player)
	if plot then
		local sellArea = GameUtils.getPlotSellArea(plot)
		local centerArea = sellArea and sellArea:FindFirstChild("LightCore")

		if sellArea and centerArea then
			local character = player.Character
			if character then
				character:PivotTo(centerArea.CFrame * CFrame.new(0, 0, 10))
				print("TELEPORT TO SELL AREA")
			end
		end
	end
end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local topMenuGui = playerGui:WaitForChild("TopMenuGui", math.huge)
local frame = topMenuGui:WaitForChild("Frame", math.huge)

local homeBtn = frame:WaitForChild("HomeButton", math.huge)
local sellBtn = frame:WaitForChild("SellerButton", math.huge)

local teleportEvent = ReplicatedStorage:WaitForChild("TeleportEvent", 10)

homeBtn.MouseButton1Click:Connect(function()
	if teleportEvent then
		teleportEvent:FireServer("Home")
	end
end)

sellBtn.MouseButton1Click:Connect(function()
	if teleportEvent then
		teleportEvent:FireServer("SellArea")
	end
end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local topMenuGui = playerGui:WaitForChild("TopMenuGui")
local frame = topMenuGui:WaitForChild("Frame")

local homeBtn = frame:WaitForChild("HomeButton")
local sellBtn = frame:WaitForChild("SellerButton")

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

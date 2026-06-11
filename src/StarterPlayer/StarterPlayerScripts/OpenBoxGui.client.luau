local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("OpenBoxGui") :: ScreenGui
local button = screenGui:WaitForChild("OpenBtn")
local Networker = require(ReplicatedStorage.Packages.Networker)

button.Activated:Connect(function()
	-- Cari event, tunggu maksimal 5 detik kalau server belum sempat bikin
	local openBoxEvent = ReplicatedStorage:WaitForChild("OpenBoxEvent", 5)
	if openBoxEvent then
		print("OPEN BOX")
		-- openBoxEvent:FireServer() -- Kirim sinyal ke server!
		Networker.client.new("OpenBox", {})
	end
end)

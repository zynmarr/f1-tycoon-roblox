local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local topMenuGui = playerGui:WaitForChild("TopMenuGui")
local frame = topMenuGui:WaitForChild("Frame")

local homeBtn = frame:WaitForChild("HomeButton")
local sellBtn = frame:WaitForChild("SellerButton")

local plots = workspace:WaitForChild("Plots")

--local myPlot = nil
--local mobileHeight = frame.GetAttribute("MobileHeight")
--local mobileWidth = frame.GetAttribute("MobileWidth")

--if
--frame.Size = UDim2.new(0, 0, 0, 0)

homeBtn.MouseButton1Click:Connect(function()
	local plotName = player:GetAttribute("MyPlotName")
	print("==== MY PLOT NAME: " .. plotName .. "====")

	local plot = plots:FindFirstChild(plotName)
	local spawnLocation = plot:FindFirstChild("SpawnLocation")

	if plot then
		print("GO TO MY PLOT")
		if spawnLocation then
			local character = player.Character
			if character then
				character:PivotTo(spawnLocation.CFrame * CFrame.new(0, 3, 0))
			end
		end
	end
end)

sellBtn.MouseButton1Click:Connect(function()
	local plotName = player:GetAttribute("MyPlotName")
	print("==== MY PLOT NAME: " .. plotName .. "====")

	local plot = plots:FindFirstChild(plotName)
	local sellArea = plot.SellArea:FindFirstChild("Area")
	local centerArea = sellArea:FindFirstChild("LightCore")

	if plot then
		print("GO TO MY PLOT")
		if sellArea then
			local character = player.Character
			if character then
				character:PivotTo(centerArea.CFrame * CFrame.new(0, 0, 10))
			end
		end
	end
end)

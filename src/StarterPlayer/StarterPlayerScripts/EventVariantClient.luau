--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local EventVariantConfig = require(ReplicatedStorage:WaitForChild("EventVariantConfig"))

local LocalPlayer = Players.LocalPlayer

local EventVariantClient = {}

-- State variables
local currentPlot: Folder? = nil
local anchorPart: Part? = nil
local billboard: BillboardGui? = nil
local totalDuration: number = 300
local lastEndTime: number = 0

-- Effects state
local originalSkies: { { Instance: Sky, Parent: Instance? } } = {}
local activeLocalSky: Sky? = nil
local activeRainTool: Tool? = nil

-- Helper function to format time
local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", mins, secs)
end

-- Sky Effect Handler
local function cleanupSkyEffect()
	if activeLocalSky then
		activeLocalSky:Destroy()
		activeLocalSky = nil
	end
	for _, info in ipairs(originalSkies) do
		if info.Instance then
			info.Instance.Parent = info.Parent
		end
	end
	table.clear(originalSkies)
end

local function applySkyEffect(skyName: string)
	cleanupSkyEffect()

	local skyTemplate = ReplicatedStorage.EventAssets:FindFirstChild(skyName)
	if not skyTemplate then
		warn("[EventVariantClient] Sky template not found in EventAssets: " .. skyName)
		return
	end

	-- Temporarily store and disable existing skies
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then
			table.insert(originalSkies, { Instance = child, Parent = child.Parent })
			child.Parent = nil
		end
	end

	activeLocalSky = skyTemplate:Clone() :: Sky
	if activeLocalSky ~= nil then
		activeLocalSky.Parent = Lighting
	end
end

-- Rain Effect Handler
local function cleanupRainEffect()
	if activeRainTool then
		activeRainTool:Destroy()
		activeRainTool = nil
	end
end

local function applyRainEffect()
	cleanupRainEffect()
	if not currentPlot then
		return
	end

	local rainTemplate = ReplicatedStorage.EventAssets:FindFirstChild("Rain")
	if not rainTemplate then
		warn("[EventVariantClient] Rain template not found in EventAssets")
		return
	end

	local baseplate: BasePart = currentPlot:FindFirstChild("BasePlate") :: BasePart
		or currentPlot:FindFirstChild("Baseplate") :: BasePart
		or currentPlot:FindFirstChild("baseplate") :: BasePart
	if not baseplate then
		warn("[EventVariantClient] Plot baseplate not found for rain positioning")
		return
	end

	local clonedRain = rainTemplate:Clone() :: Tool
	clonedRain.Parent = baseplate

	-- Position parts centered on the plot baseplate in X and Z, keeping their Y height
	local parts = {}
	for _, child in ipairs(clonedRain:GetDescendants()) do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end

	if #parts > 0 then
		local sumX, sumZ = 0, 0
		for _, part in ipairs(parts) do
			sumX += part.Position.X
			sumZ += part.Position.Z
		end
		local avgX = sumX / #parts
		local avgZ = sumZ / #parts

		local targetX = baseplate.Position.X
		local targetZ = baseplate.Position.Z

		local diffX = targetX - avgX
		local diffZ = targetZ - avgZ

		for _, part in ipairs(parts) do
			part.Position = Vector3.new(part.Position.X + diffX, part.Position.Y, part.Position.Z + diffZ)
		end
	end

	activeRainTool = clonedRain
end

-- Update Billboard contents
local function updateState()
	if not billboard or not billboard.Parent then
		return
	end

	local mainFrame = billboard:FindFirstChild("MainFrame")
	if not mainFrame then
		return
	end

	local titleLabel = mainFrame:FindFirstChild("TitleLabel") :: TextLabel
	local subtitleLabel = mainFrame:FindFirstChild("SubtitleLabel") :: TextLabel
	local progressFill = mainFrame:FindFirstChild("ProgressBarBackground"):FindFirstChild("ProgressBarFill") :: Frame
	local stroke = mainFrame:FindFirstChild("UIStroke") :: UIStroke

	local status = LocalPlayer:GetAttribute("EventStatus") or "Rest"
	local variant = LocalPlayer:GetAttribute("ActiveEventVariant") or "None"
	local boost = LocalPlayer:GetAttribute("ActiveEventBoost") or 0
	local nextVar = LocalPlayer:GetAttribute("EventNextVariant") or "None"

	if status == "Active" and variant ~= "None" then
		local varConfig = EventVariantConfig.Variants[variant]
		if varConfig then
			titleLabel.Text = `{string.upper(varConfig.DisplayName)} EVENT {varConfig.Icon}`
			titleLabel.TextColor3 = varConfig.Color
			subtitleLabel.Text = `+{varConfig.Boost}% Rare Gacha Boost`
			stroke.Color = varConfig.Color
			progressFill.BackgroundColor3 = varConfig.Color
		else
			titleLabel.Text = `{string.upper(variant)} EVENT 📢`
			titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			subtitleLabel.Text = `+{boost}% Rare Gacha Boost`
			stroke.Color = Color3.fromRGB(255, 255, 255)
			progressFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		end

		-- Apply visual effects
		if varConfig then
			if varConfig.AssetType == "Sky" then
				cleanupRainEffect()
				applySkyEffect(varConfig.AssetName)
			elseif varConfig.AssetType == "Rain" then
				cleanupSkyEffect()
				applyRainEffect()
			else
				cleanupSkyEffect()
				cleanupRainEffect()
			end
		else
			cleanupSkyEffect()
			cleanupRainEffect()
		end
	else
		-- Rest State
		titleLabel.Text = "RESTING 💤"
		titleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		stroke.Color = Color3.fromRGB(80, 80, 90)
		progressFill.BackgroundColor3 = Color3.fromRGB(150, 150, 150)

		if nextVar ~= "None" then
			local nextConfig = EventVariantConfig.Variants[nextVar]
			local icon = nextConfig and nextConfig.Icon or "🌟"
			subtitleLabel.Text = `Next Event: {nextVar} {icon}`
		else
			subtitleLabel.Text = "Waiting for next event..."
		end

		-- Clean up visual effects during rest
		cleanupSkyEffect()
		cleanupRainEffect()
	end
end

-- Completely clean up billboard and effects
local function cleanupPlotBillboard()
	if anchorPart then
		anchorPart:Destroy()
		anchorPart = nil
	end
	if billboard then
		billboard:Destroy()
		billboard = nil
	end
	cleanupSkyEffect()
	cleanupRainEffect()
	currentPlot = nil
end

-- Set up billboard for the player's plot
local function onPlotChanged()
	cleanupPlotBillboard()

	local plotName = LocalPlayer:GetAttribute("MyPlotName")
	if not plotName or plotName == "" then
		return
	end

	local plot = workspace.Plots:WaitForChild(plotName, 10)
	if not plot then
		warn("[EventVariantClient] Plot not found in workspace.Plots: " .. tostring(plotName))
		return
	end

	currentPlot = plot

	local baseplate = plot:WaitForChild("BasePlate", 10)
		or plot:WaitForChild("Baseplate", 10)
		or plot:WaitForChild("baseplate", 10)
	if not baseplate then
		warn("[EventVariantClient] Baseplate not found in plot: " .. plot.Name)
		return
	end

	-- Create anchor part above baseplate center
	anchorPart = Instance.new("Part")
	if anchorPart ~= nil then
		anchorPart.Name = "EventVariantBillboardAnchor"
		anchorPart.Transparency = 1
		anchorPart.Anchored = true
		anchorPart.CanCollide = false
		anchorPart.CanQuery = false
		anchorPart.CanTouch = false
		anchorPart.Size = Vector3.new(1, 1, 1)
		anchorPart.CFrame = baseplate.CFrame + Vector3.new(0, baseplate.Size.Y / 2 + 45, 0)
		anchorPart.Parent = plot
	end

	-- Create BillboardGui
	billboard = Instance.new("BillboardGui")
	if billboard ~= nil then
		billboard.Name = "EventVariantBillboard"
		if anchorPart ~= nil then
			billboard.Adornee = anchorPart
		end
		billboard.Size = UDim2.new(0, 300, 0, 115)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 600
		billboard.ResetOnSpawn = false
	end

	-- Create MainFrame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	mainFrame.BackgroundTransparency = 0.25
	mainFrame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = mainFrame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "UIStroke"
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Parent = mainFrame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = mainFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = mainFrame

	-- Title Label
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 26)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.LayoutOrder = 1
	titleLabel.Parent = mainFrame

	-- Subtitle Label
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "SubtitleLabel"
	subtitleLabel.Size = UDim2.new(1, 0, 0, 18)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.GothamMedium
	subtitleLabel.TextSize = 12
	subtitleLabel.TextScaled = true
	subtitleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	subtitleLabel.LayoutOrder = 2
	subtitleLabel.Parent = mainFrame

	-- Progress Bar Background
	local progressBarBg = Instance.new("Frame")
	progressBarBg.Name = "ProgressBarBackground"
	progressBarBg.Size = UDim2.new(0.95, 0, 0, 8)
	progressBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	progressBarBg.BorderSizePixel = 0
	progressBarBg.LayoutOrder = 3
	progressBarBg.Parent = mainFrame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = progressBarBg

	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressBarFill"
	progressFill.Size = UDim2.new(1, 0, 1, 0)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBarBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = progressFill

	-- Timer Label
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(1, 0, 0, 20)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.TextSize = 14
	timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	timerLabel.LayoutOrder = 4
	timerLabel.Parent = mainFrame

	if billboard ~= nil then
		billboard.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	-- Initial duration calculation
	local endTime = LocalPlayer:GetAttribute("EventEndTime") or 0
	local now = workspace:GetServerTimeNow()
	local remaining = math.max(0, endTime - now)
	totalDuration = remaining > 0 and remaining or 1

	updateState()
end

function EventVariantClient.init()
	-- Event listener connections
	LocalPlayer:GetAttributeChangedSignal("MyPlotName"):Connect(onPlotChanged)
	LocalPlayer:GetAttributeChangedSignal("EventStatus"):Connect(updateState)
	LocalPlayer:GetAttributeChangedSignal("ActiveEventVariant"):Connect(updateState)
	LocalPlayer:GetAttributeChangedSignal("ActiveEventBoost"):Connect(updateState)
	LocalPlayer:GetAttributeChangedSignal("EventNextVariant"):Connect(updateState)

	LocalPlayer:GetAttributeChangedSignal("EventEndTime"):Connect(function()
		local endTime = LocalPlayer:GetAttribute("EventEndTime") or 0
		local now = workspace:GetServerTimeNow()
		local remaining = math.max(0, endTime - now)
		totalDuration = remaining > 0 and remaining or 1
		updateState()
	end)

	-- Heartbeat render connection for smooth timer and progress bar
	RunService.Heartbeat:Connect(function()
		if not billboard or not billboard.Parent then
			return
		end

		local mainFrame = billboard:FindFirstChild("MainFrame")
		if not mainFrame then
			return
		end

		local timerLabel = mainFrame:FindFirstChild("TimerLabel") :: TextLabel
		local progressFill =
			mainFrame:FindFirstChild("ProgressBarBackground"):FindFirstChild("ProgressBarFill") :: Frame

		local endTime = LocalPlayer:GetAttribute("EventEndTime") or 0
		local now = workspace:GetServerTimeNow()
		local remaining = math.max(0, endTime - now)

		timerLabel.Text = formatTime(math.ceil(remaining))

		local ratio = 0
		if totalDuration > 0 then
			ratio = math.clamp(remaining / totalDuration, 0, 1)
		end
		progressFill.Size = UDim2.new(ratio, 0, 1, 0)
	end)

	-- Run immediately if plot already claimed
	if LocalPlayer:GetAttribute("MyPlotName") then
		onPlotChanged()
	end

	print("[EventVariantClient] Initialized event variant client manager.")
end

return EventVariantClient

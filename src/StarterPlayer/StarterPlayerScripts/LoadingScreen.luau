--!strict
-- src/StarterPlayer/StarterPlayerScripts/LoadingScreen.luau
-- Custom F1-Tycoon Loading Screen dengan Animasi Progress Bar, Tip Rotasi & Smooth Fade Out

local LoadingScreen = {}

function LoadingScreen.init()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")
	local ContentProvider = game:GetService("ContentProvider")
	local ReplicatedFirst = game:GetService("ReplicatedFirst")

	-- Matikan default loading screen Roblox
	pcall(function()
		ReplicatedFirst:RemoveDefaultLoadingScreen()
	end)

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	-- Buat Dedicated ScreenGui untuk Loading
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CustomLoadingScreen"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 999999 -- Pastikan berada di paling atas seluruh UI
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Background Utama (Dark Cyber Racing Theme)
	local bgFrame = Instance.new("Frame")
	bgFrame.Name = "Background"
	bgFrame.Size = UDim2.new(1, 0, 1, 0)
	bgFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
	bgFrame.BorderSizePixel = 0
	bgFrame.Parent = screenGui

	-- Pattern/Gradient Background
	local bgGradient = Instance.new("UIGradient")
	bgGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 18, 25)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8, 9, 12)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 5, 8)),
	})
	bgGradient.Rotation = 45
	bgGradient.Parent = bgFrame

	-- Container Tengah
	local centerFrame = Instance.new("Frame")
	centerFrame.Name = "CenterContainer"
	centerFrame.Size = UDim2.new(0.6, 0, 0.5, 0)
	centerFrame.Position = UDim2.new(0.5, 0, 0.45, 0)
	centerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	centerFrame.BackgroundTransparency = 1
	centerFrame.Parent = bgFrame

	-- Logo / Judul Game
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 60)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🏎️ F1 TYCOON"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 42
	titleLabel.TextStrokeTransparency = 0.5
	titleLabel.TextStrokeColor3 = Color3.fromRGB(255, 60, 0)
	titleLabel.Parent = centerFrame

	-- Subtitle
	local subTitle = Instance.new("TextLabel")
	subTitle.Name = "Subtitle"
	subTitle.Size = UDim2.new(1, 0, 0, 25)
	subTitle.Position = UDim2.new(0, 0, 0, 60)
	subTitle.BackgroundTransparency = 1
	subTitle.Text = "MANAGE YOUR ULTIMATE RACING TEAM"
	subTitle.TextColor3 = Color3.fromRGB(0, 220, 255) -- Cyan Accent
	subTitle.Font = Enum.Font.GothamBold
	subTitle.TextSize = 13
	subTitle.Parent = centerFrame

	-- Outer Progress Bar Container
	local barBackground = Instance.new("Frame")
	barBackground.Name = "BarBackground"
	barBackground.Size = UDim2.new(0.85, 0, 0, 16)
	barBackground.Position = UDim2.new(0.5, 0, 0, 130)
	barBackground.AnchorPoint = Vector2.new(0.5, 0)
	barBackground.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
	barBackground.BorderSizePixel = 0
	barBackground.Parent = centerFrame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = barBackground

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Color3.fromRGB(50, 55, 75)
	barStroke.Thickness = 1.5
	barStroke.Parent = barBackground

	-- Inner Progress Bar (Fill)
	local barFill = Instance.new("Frame")
	barFill.Name = "BarFill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(255, 60, 0)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBackground

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = barFill

	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 40, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0)),
	})
	fillGradient.Parent = barFill

	-- Percentage & Status Text
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusText"
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.Position = UDim2.new(0, 0, 0, 155)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Memuat Aset & Data Server (0%)..."
	statusLabel.TextColor3 = Color3.fromRGB(180, 185, 200)
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 11
	statusLabel.Parent = centerFrame

	-- Tips Rotasi
	local tips = {
		"💡 Tip: Pemilik F1 Pass/VIP mendapatkan bonus mobil Celestial & 2x Cash Daily Absen!",
		"💡 Tip: Rebirth meningkatkan Rebirth Points untuk membuka Upgrade Permanen!",
		"💡 Tip: Gunakan F1 Team Manager untuk memasang Driver & Strategy terbaik!",
		"💡 Tip: Anda bisa mencuri hingga 3 Steel Box pemain lain setiap harinya!",
		"💡 Tip: Gunakan R&D Fusion Lab untuk menggabungkan mobil menjadi Rarity lebih tinggi!",
	}

	local tipLabel = Instance.new("TextLabel")
	tipLabel.Name = "TipText"
	tipLabel.Size = UDim2.new(0.9, 0, 0, 35)
	tipLabel.Position = UDim2.new(0.5, 0, 0, 200)
	tipLabel.AnchorPoint = Vector2.new(0.5, 0)
	tipLabel.BackgroundTransparency = 1
	tipLabel.Text = tips[1]
	tipLabel.TextColor3 = Color3.fromRGB(140, 145, 165)
	tipLabel.Font = Enum.Font.Gotham
	tipLabel.TextSize = 11
	tipLabel.TextWrapped = true
	tipLabel.Parent = centerFrame

	-- Rotasi Tips secara berkala
	local currentTipIndex = 1
	task.spawn(function()
		while bgFrame and bgFrame.Parent do
			task.wait(4)
			currentTipIndex = (currentTipIndex % #tips) + 1
			local fadeOut = TweenService:Create(tipLabel, TweenInfo.new(0.3), { TextTransparency = 1 })
			fadeOut:Play()
			fadeOut.Completed:Wait()
			tipLabel.Text = tips[currentTipIndex]
			local fadeIn = TweenService:Create(tipLabel, TweenInfo.new(0.3), { TextTransparency = 0 })
			fadeIn:Play()
		end
	end)

	-- =============================================================================
	-- LOGIKA PRELOAD ASET & DATA SYNC
	-- =============================================================================
	task.spawn(function()
		local assetsToPreload = {
			ReplicatedStorage:WaitForChild("Packages", 10),
		}

		local totalItems = #assetsToPreload + 10
		local currentLoaded = 0

		-- 1. Preload Aset Penting
		for idx, asset in ipairs(assetsToPreload) do
			if asset then
				pcall(function()
					ContentProvider:PreloadAsync({ asset })
				end)
			end
			currentLoaded = currentLoaded + 1
			local progress = math.clamp(currentLoaded / totalItems, 0, 0.6)
			
			TweenService:Create(barFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(progress, 0, 1, 0),
			}):Play()
			statusLabel.Text = string.format("Memuat Aset Utama (%d%%)...", math.floor(progress * 100))
			task.wait(0.05)
		end

		-- 2. Tunggu Data Server Selesai Ter-load (`DataLoaded` attribute)
		statusLabel.Text = "Menyelaraskan Data Profil & Plot..."
		local startWait = tick()
		while not player:GetAttribute("DataLoaded") and (tick() - startWait) < 12 do
			local simulatedProgress = 0.6 + math.min((tick() - startWait) / 12, 1) * 0.35
			TweenService:Create(barFill, TweenInfo.new(0.3), {
				Size = UDim2.new(simulatedProgress, 0, 1, 0),
			}):Play()
			statusLabel.Text = string.format("Menyelaraskan Data Profil (%d%%)...", math.floor(simulatedProgress * 100))
			task.wait(0.2)
		end

		-- 3. Finish Progress Bar (100%)
		TweenService:Create(barFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 1, 0),
		}):Play()
		statusLabel.Text = "Siap Balapan! (100%)"
		task.wait(0.5)

		-- 4. Smooth Fade Out Transition
		local fadeInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		local tweenBg = TweenService:Create(bgFrame, fadeInfo, { BackgroundTransparency = 1 })
		
		-- Fade out semua elemen teks
		for _, child in ipairs(centerFrame:GetChildren()) do
			if child:IsA("TextLabel") then
				TweenService:Create(child, fadeInfo, { TextTransparency = 1 }):Play()
			elseif child:IsA("Frame") then
				TweenService:Create(child, fadeInfo, { BackgroundTransparency = 1 }):Play()
				for _, sub in ipairs(child:GetChildren()) do
					if sub:IsA("Frame") then
						TweenService:Create(sub, fadeInfo, { BackgroundTransparency = 1 }):Play()
					end
				end
			end
		end

		tweenBg:Play()
		tweenBg.Completed:Wait()

		screenGui:Destroy()
		print("[LoadingScreen] ✅ Custom Loading Screen selesai & ditutup!")
	end)
end

return LoadingScreen

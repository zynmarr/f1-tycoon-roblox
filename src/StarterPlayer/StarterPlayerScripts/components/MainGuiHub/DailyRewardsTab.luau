local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local REWARD_LIST = {
	{ Day = 1, RewardName = "$5K Cash", Icon = "💰", Type = "Cash" },
	{ Day = 2, RewardName = "$12K Cash", Icon = "💵", Type = "Cash" },
	{ Day = 3, RewardName = "Common Box", Icon = "📦", Type = "Box" },
	{ Day = 4, RewardName = "$30K Cash", Icon = "💰", Type = "Cash" },
	{ Day = 5, RewardName = "Rare Box", Icon = "📦", Type = "Box" },
	{ Day = 6, RewardName = "$75K Cash", Icon = "💵", Type = "Cash" },
	{ Day = 7, RewardName = "Epic Box", Icon = "💎", Type = "Box" },
}

return function(props)
	local streak = props.Streak or 0
	local lastClaimTime = props.LastClaimTime or 0
	local now = os.time()

	-- Cek apakah klaim harian saat ini aktif / siap diklaim
	local isCooldownOver = (now - lastClaimTime) >= 72000 -- 20 jam
	local activeClaimDay = streak + 1
	if activeClaimDay > 7 then
		activeClaimDay = 1
	end

	-- Jika lewat 48 jam, streak kembali ke 1
	local isStreakReset = (now - lastClaimTime) > 172800
	if isStreakReset then
		activeClaimDay = 1
	end

	local rewardCards = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for _, item in ipairs(REWARD_LIST) do
		local isClaimed = not isStreakReset and item.Day <= streak
		local isCurrentClaimable = not isClaimed and item.Day == activeClaimDay and isCooldownOver
		local isLocked = not isClaimed and not isCurrentClaimable

		local cardBgColor = Color3.fromRGB(35, 35, 45)
		local borderBgColor = Color3.fromRGB(55, 55, 65)

		if isClaimed then
			cardBgColor = Color3.fromRGB(25, 45, 30)
			borderBgColor = Color3.fromRGB(45, 100, 55)
		elseif isCurrentClaimable then
			cardBgColor = Color3.fromRGB(45, 40, 30)
			borderBgColor = Color3.fromRGB(200, 150, 50)
		end

		rewardCards["Day" .. item.Day] = e("Frame", {
			Size = UDim2.new(0, 85, 0.85, 0),
			BackgroundColor3 = cardBgColor,
			BorderSizePixel = isCurrentClaimable and 2 or 1,
			BorderColor3 = borderBgColor,
			LayoutOrder = item.Day,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),

			Header = e("TextLabel", {
				Text = "HARI " .. item.Day,
				Size = UDim2.new(1, 0, 0, 25),
				Position = UDim2.new(0, 0, 0, 8),
				BackgroundTransparency = 1,
				TextColor3 = isLocked and Color3.fromRGB(130, 130, 140) or Color3.fromRGB(255, 255, 255),
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextScaled = true,
			}),

			Icon = e("TextLabel", {
				Text = item.Icon,
				Size = UDim2.new(1, 0, 0, 50),
				Position = UDim2.new(0, 0, 0, 35),
				BackgroundTransparency = 1,
				TextSize = 32,
				Font = Enum.Font.GothamBold,
			}),

			RewardNameLabel = e("TextLabel", {
				Text = item.RewardName,
				Size = UDim2.new(1, 0, 0, 20),
				Position = UDim2.new(0, 0, 0, 90),
				BackgroundTransparency = 1,
				TextColor3 = isLocked and Color3.fromRGB(150, 150, 160) or Color3.fromRGB(0, 255, 204),
				TextSize = 10,
				Font = Enum.Font.GothamBold,
				TextScaled = true,
			}),

			Overlay = isClaimed and e("TextLabel", {
				Text = "✓ KLAIMED",
				Size = UDim2.new(1, 0, 0, 22),
				Position = UDim2.new(0, 0, 1, -30),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(80, 255, 120),
				TextSize = 10,
				Font = Enum.Font.GothamBold,
				TextScaled = true,
			}) or nil,

			ClaimButton = isCurrentClaimable and e("TextButton", {
				Text = "KLAIM",
				Size = UDim2.new(0.8, 0, 0, 28),
				Position = UDim2.new(0.1, 0, 1, -38),
				BackgroundColor3 = Color3.fromRGB(200, 140, 30),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				BorderSizePixel = 0,
				TextScaled = true,
				[React.Event.Activated] = function()
					if props.onClaimReward then
						props.onClaimReward()
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}) or nil,

			LockIcon = isLocked and e("TextLabel", {
				Text = "🔒 LOCKED",
				Size = UDim2.new(1, 0, 0, 20),
				Position = UDim2.new(0, 0, 1, -30),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(110, 110, 120),
				TextSize = 9,
				Font = Enum.Font.GothamBold,
				TextScaled = true,
			}) or nil,
		})
	end

	-- Menghitung sisa waktu cooldown klaim berikutnya
	local timeString = "SIAP DIKLAIM"
	if not isCooldownOver then
		local secondsRemaining = 72000 - (now - lastClaimTime)
		local hours = math.floor(secondsRemaining / 3600)
		local minutes = math.floor((secondsRemaining % 3600) / 60)
		timeString = string.format("KLAIM BERIKUTNYA DALAM: %02d:%02d", hours, minutes)
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(25, 25, 33),
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),

		Title = e("TextLabel", {
			Text = "HADIAH HARIAN (DAILY STREAK)",
			Size = UDim2.new(1, -30, 0, 45),
			Position = UDim2.new(0, 15, 0, 15),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 18,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		SubTitle = e("TextLabel", {
			Text = "Masuk game berturut-turut setiap hari untuk mengumpulkan hadiah yang lebih besar!",
			Size = UDim2.new(1, -30, 0, 20),
			Position = UDim2.new(0, 15, 0, 50),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(160, 160, 175),
			TextSize = 11,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		CardContainer = e("ScrollingFrame", {
			Size = UDim2.new(1, -30, 1, -150),
			Position = UDim2.new(0, 15, 0, 80),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(0, 680, 0, 0),
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(80, 80, 95),
		}, rewardCards),

		CooldownDisplay = e("TextLabel", {
			Text = timeString,
			Size = UDim2.new(1, -30, 0, 30),
			Position = UDim2.new(0, 15, 1, -45),
			BackgroundTransparency = 1,
			TextColor3 = isCooldownOver and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(230, 150, 50),
			TextSize = 13,
			Font = Enum.Font.GothamBold,
		}),
	})
end

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
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local isMobile = props.IsMobile

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

		-- Sizing and Position variables based on Mobile vs PC
		local cardSize = isMobile and UDim2.fromOffset(78, 112) or UDim2.fromOffset(90, 130)
		local headerPos = isMobile and UDim2.new(0, 0, 0, 6) or UDim2.new(0, 0, 0, 8)
		local headerSize = isMobile and UDim2.new(1, 0, 0, 20) or UDim2.new(1, 0, 0, 25)
		
		local iconPos = isMobile and UDim2.new(0, 0, 0, 28) or UDim2.new(0, 0, 0, 36)
		local iconSize = isMobile and UDim2.new(1, 0, 0, 38) or UDim2.new(1, 0, 0, 48)
		local iconTextSize = isMobile and 24 or 32

		local namePos = isMobile and UDim2.new(0, 0, 0, 68) or UDim2.new(0, 0, 0, 88)
		local nameSize = isMobile and UDim2.new(1, 0, 0, 16) or UDim2.new(1, 0, 0, 18)

		local overlayPos = isMobile and UDim2.new(0, 0, 1, -22) or UDim2.new(0, 0, 1, -28)
		local overlaySize = isMobile and UDim2.new(1, 0, 0, 18) or UDim2.new(1, 0, 0, 20)

		local claimPos = isMobile and UDim2.new(0.075, 0, 1, -26) or UDim2.new(0.1, 0, 1, -32)
		local claimSize = isMobile and UDim2.new(0.85, 0, 0, 22) or UDim2.new(0.8, 0, 0, 26)

		rewardCards["Day" .. item.Day] = e("Frame", {
			Size = cardSize,
			BackgroundColor3 = cardBgColor,
			BorderSizePixel = isCurrentClaimable and 2 or 1,
			BorderColor3 = borderBgColor,
			LayoutOrder = item.Day,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),

			Header = e("TextLabel", {
				Text = "HARI " .. item.Day,
				Size = headerSize,
				Position = headerPos,
				BackgroundTransparency = 1,
				TextColor3 = isLocked and Color3.fromRGB(130, 130, 140) or Color3.fromRGB(255, 255, 255),
				TextSize = isMobile and 10 or 12,
				Font = Enum.Font.GothamBold,
				TextScaled = true,
			}),

			Icon = e("TextLabel", {
				Text = item.Icon,
				Size = iconSize,
				Position = iconPos,
				BackgroundTransparency = 1,
				TextSize = iconTextSize,
				Font = Enum.Font.GothamBold,
			}),

			RewardNameLabel = e("TextLabel", {
				Text = item.RewardName,
				Size = nameSize,
				Position = namePos,
				BackgroundTransparency = 1,
				TextColor3 = isLocked and Color3.fromRGB(150, 150, 160) or Color3.fromRGB(0, 255, 204),
				TextSize = isMobile and 9 or 10,
				Font = Enum.Font.GothamBold,
				TextScaled = true,
			}),

			Overlay = isClaimed and e("TextLabel", {
				Text = "✓ KLAIMED",
				Size = overlaySize,
				Position = overlayPos,
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(80, 255, 120),
				TextSize = isMobile and 9 or 10,
				Font = Enum.Font.GothamBold,
				TextScaled = true,
			}) or nil,

			ClaimButton = isCurrentClaimable and e("TextButton", {
				Text = "KLAIM",
				Size = claimSize,
				Position = claimPos,
				BackgroundColor3 = Color3.fromRGB(200, 140, 30),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = isMobile and 9 or 10,
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
				Size = overlaySize,
				Position = overlayPos,
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(110, 110, 120),
				TextSize = isMobile and 8 or 9,
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
			Size = UDim2.new(1, -30, 0, 30),
			Position = UDim2.new(0, 15, 0, 10),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = isMobile and 14 or 18,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		SubTitle = e("TextLabel", {
			Text = "Masuk game berturut-turut setiap hari untuk mengumpulkan hadiah yang lebih besar!",
			Size = UDim2.new(1, -30, 0, 18),
			Position = UDim2.new(0, 15, 0, 42),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(160, 160, 175),
			TextSize = isMobile and 9.5 or 11,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		CardContainer = e("ScrollingFrame", {
			Size = UDim2.new(1, -30, 0, isMobile and 120 or 140),
			Position = UDim2.new(0, 15, 0, isMobile and 68 or 80),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(80, 80, 95),
		}, rewardCards),

		CooldownDisplay = e("TextLabel", {
			Text = timeString,
			Size = UDim2.new(1, -30, 0, 20),
			Position = UDim2.new(0, 15, 1, isMobile and -25 or -35),
			BackgroundTransparency = 1,
			TextColor3 = isCooldownOver and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(230, 150, 50),
			TextSize = isMobile and 11 or 13,
			Font = Enum.Font.GothamBold,
		}),
	})
end

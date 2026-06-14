local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local e = React.createElement

local UPGRADE_INFOS = {
	CashMultiplier = { Name = "Cash Multiplier", Desc = "+15% Cash permanen dari semua sumber", Icon = "💰" },
	LuckMultiplier = { Name = "Luck Multiplier", Desc = "+10% Luck gacha box secara global", Icon = "🍀" },
	VariantChance_Rainbow = { Name = "Rainbow Chance", Desc = "+15% Rate gacha varian Rainbow", Icon = "🌈" },
	VariantChance_All = { Name = "All Variants Boost", Desc = "+10% Rate gacha seluruh varian langka", Icon = "✨" },
}

return function(props)
	local rebirthLevel = props.RebirthLevel or 0
	local rebirthPoints = props.RebirthPoints or 0
	local cash = props.Cash or 0
	local upgrades = props.RebirthUpgrades or {
		CashMultiplier = 0,
		LuckMultiplier = 0,
		VariantChance_Rainbow = 0,
		VariantChance_All = 0,
	}

	local rebirthCost = 1000000 * (2.5 ^ rebirthLevel)
	local canRebirth = cash >= rebirthCost

	local upgradeElements = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
	}

	local order = 1
	for id, info in pairs(UPGRADE_INFOS) do
		local lvl = upgrades[id] or 0
		local cost = 50 * (2 ^ lvl)
		local canBuy = rebirthPoints >= cost

		upgradeElements[id] = e("Frame", {
			Size = UDim2.new(1, 0, 0, 75),
			BackgroundColor3 = Color3.fromRGB(35, 35, 45),
			BorderSizePixel = 0,
			LayoutOrder = order,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			
			Icon = e("TextLabel", {
				Text = info.Icon,
				Size = UDim2.new(0.12, 0, 0, 45),
				Position = UDim2.new(0.02, 0, 0.5, -22),
				BackgroundTransparency = 1,
				TextSize = 24,
				Font = Enum.Font.GothamBold,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
			}),

			TextContainer = e("Frame", {
				Size = UDim2.new(0.56, 0, 1, 0),
				Position = UDim2.new(0.15, 0, 0, 0),
				BackgroundTransparency = 1,
			}, {
				List = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 2),
				}),
				Title = e("TextLabel", {
					Text = info.Name .. " <font color='#FFDF00'>Lvl " .. lvl .. "</font>",
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(240, 240, 240),
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
					RichText = true,
					TextScaled = true,
				}),
				Desc = e("TextLabel", {
					Text = info.Desc,
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(180, 180, 180),
					TextSize = 10,
					Font = Enum.Font.GothamMedium,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = true,
				})
			}),

			UpgradeButton = e("TextButton", {
				Text = string.format("UPGRADE\n(%d RP)", cost),
				Size = UDim2.new(0.26, 0, 0, 45),
				Position = UDim2.new(0.72, 0, 0.5, -22),
				BackgroundColor3 = canBuy and Color3.fromRGB(0, 170, 110) or Color3.fromRGB(80, 80, 90),
				TextColor3 = canBuy and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				BorderSizePixel = 0,
				Active = canBuy,
				TextScaled = true,
				[React.Event.Activated] = function()
					if canBuy and props.onUpgrade then
						props.onUpgrade(id)
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			})
		})

		order = order + 1
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, {
		-- LEFT PANEL: CONTROL REBIRTH
		ControlPanel = e("Frame", {
			Size = UDim2.new(0.38, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(25, 25, 33),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			
			Title = e("TextLabel", {
				Text = "AKSES REBIRTH",
				Size = UDim2.new(1, 0, 0, 45),
				Position = UDim2.new(0, 0, 0, 15),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 18,
				Font = Enum.Font.GothamBold,
			}),

			StatusIcon = e("TextLabel", {
				Text = "🔱",
				Size = UDim2.new(1, 0, 0, 80),
				Position = UDim2.new(0, 0, 0, 65),
				BackgroundTransparency = 1,
				TextSize = 55,
				Font = Enum.Font.GothamBold,
			}),

			Details = e("TextLabel", {
				Text = string.format(
					"Level Rebirth saat ini: <b><font color='#00FFCC'>%d</font></b>\n\nRebirth akan mereset Cash dan plot mesin Anda.\n\nAnda akan mendapatkan poin Rebirth dan semua mobil ber-varian <font color='#FF5555'>Admin</font> akan dipertahankan.",
					rebirthLevel
				),
				Size = UDim2.new(0.85, 0, 0, 140),
				Position = UDim2.new(0.075, 0, 0, 150),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(200, 200, 210),
				TextSize = 12,
				Font = Enum.Font.GothamMedium,
				TextWrapped = true,
				RichText = true,
			}),

			RebirthBtn = e("TextButton", {
				Text = canRebirth and "REBIRTH SEKARANG" or "BUTUH: $" .. GameUtils.formatCompact(rebirthCost),
				Size = UDim2.new(0.85, 0, 0, 50),
				Position = UDim2.new(0.075, 0, 1, -70),
				BackgroundColor3 = canRebirth and Color3.fromRGB(190, 45, 45) or Color3.fromRGB(75, 75, 85),
				TextColor3 = canRebirth and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 160),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				BorderSizePixel = 0,
				Active = canRebirth,
				TextScaled = true,
				[React.Event.Activated] = function()
					if canRebirth and props.onRebirth then
						props.onRebirth()
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			})
		}),

		-- RIGHT PANEL: UPGRADES
		UpgradesPanel = e("Frame", {
			Size = UDim2.new(0.59, 0, 1, 0),
			Position = UDim2.new(0.41, 0, 0, 0),
			BackgroundColor3 = Color3.fromRGB(25, 25, 33),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			
			Title = e("TextLabel", {
				Text = "UPGRADE PERMANEN",
				Size = UDim2.new(1, -30, 0, 45),
				Position = UDim2.new(0, 15, 0, 15),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 18,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			ScrollArea = e("ScrollingFrame", {
				Size = UDim2.new(1, -30, 1, -80),
				Position = UDim2.new(0, 15, 0, 65),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Color3.fromRGB(100, 100, 115),
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			}, upgradeElements)
		})
	})
end

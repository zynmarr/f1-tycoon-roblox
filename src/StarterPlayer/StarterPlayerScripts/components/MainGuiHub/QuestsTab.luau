local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local e = React.createElement

-- Config Milestone
local MILESTONES_CONFIG = {
	CarsSold = {
		{ Target = 50, Reward = 15000, ID = "sold_50", Label = "Jual 50 Mobil" },
		{ Target = 150, Reward = 40000, ID = "sold_150", Label = "Jual 150 Mobil" },
		{ Target = 500, Reward = 15000, ID = "sold_500", Label = "Jual 500 Mobil" },
	},
	BoxesOpened = {
		{ Target = 25, Reward = 10000, ID = "open_25", Label = "Buka 25 Box Gacha" },
		{ Target = 100, Reward = 35000, ID = "open_100", Label = "Buka 100 Box Gacha" },
		{ Target = 300, Reward = 100000, ID = "open_300", Label = "Buka 300 Box Gacha" },
	}
}

return function(props)
	local daily = props.DailyQuests or {}
	local milestones = props.MilestoneStats or {
		TotalCarsSold = 0,
		TotalBoxesOpened = 0,
		ClaimedMilestones = {},
	}

	-- 1. Daily Quests Elements
	local dailyElements = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 10),
		})
	}

	for i, q in ipairs(daily) do
		local percent = math.clamp(q.Progress / q.Target, 0, 1)
		local isCompleted = q.Progress >= q.Target
		local isClaimed = q.Claimed

		dailyElements["Quest_" .. q.ID] = e("Frame", {
			Size = UDim2.new(1, 0, 0, 65),
			BackgroundColor3 = Color3.fromRGB(35, 35, 45),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			
			InfoLabel = e("TextLabel", {
				Text = q.Text .. " <font color='#00FFCC'>(" .. q.Progress .. "/" .. q.Target .. ")</font>",
				Size = UDim2.new(0.65, 0, 0, 20),
				Position = UDim2.new(0, 15, 0, 10),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(240, 240, 240),
				TextSize = 13,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				RichText = true,
			}),

			ProgressBarBg = e("Frame", {
				Size = UDim2.new(0.65, 0, 0, 10),
				Position = UDim2.new(0, 15, 0, 38),
				BackgroundColor3 = Color3.fromRGB(20, 20, 25),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				Fill = e("Frame", {
					Size = UDim2.new(percent, 0, 1, 0),
					BackgroundColor3 = isCompleted and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(0, 130, 255),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				})
			}),

			ActionBtn = not isClaimed and e("TextButton", {
				Text = isCompleted and "KLAIM\n($" .. GameUtils.formatCompact(q.RewardCash) .. ")" or "BELUM SELESAI",
				Size = UDim2.new(0, 110, 0, 45),
				Position = UDim2.new(1, -125, 0.5, -22),
				BackgroundColor3 = isCompleted and Color3.fromRGB(0, 170, 110) or Color3.fromRGB(60, 60, 70),
				TextColor3 = isCompleted and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 160),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				BorderSizePixel = 0,
				Active = isCompleted,
				[React.Event.Activated] = function()
					if isCompleted and props.onClaimQuest then
						props.onClaimQuest(q.ID)
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}) or e("TextLabel", {
				Text = "✓ SELESAI",
				Size = UDim2.new(0, 110, 0, 45),
				Position = UDim2.new(1, -125, 0.5, -22),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(80, 255, 120),
				TextSize = 11,
				Font = Enum.Font.GothamBold,
			})
		})
	end

	-- 2. Milestone Elements
	local milestoneElements = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 10),
		})
	}

	local function addMilestoneList(listConfig, currentStat, statType)
		for _, m in ipairs(listConfig) do
			local isCompleted = currentStat >= m.Target
			local isClaimed = milestones.ClaimedMilestones[m.ID] == true
			local percent = math.clamp(currentStat / m.Target, 0, 1)

			milestoneElements[m.ID] = e("Frame", {
				Size = UDim2.new(1, 0, 0, 65),
				BackgroundColor3 = Color3.fromRGB(35, 35, 45),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				
				InfoLabel = e("TextLabel", {
					Text = m.Label .. " <font color='#00FFCC'>(" .. currentStat .. "/" .. m.Target .. ")</font>",
					Size = UDim2.new(0.65, 0, 0, 20),
					Position = UDim2.new(0, 15, 0, 10),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(240, 240, 240),
					TextSize = 13,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
					RichText = true,
				}),

				ProgressBarBg = e("Frame", {
					Size = UDim2.new(0.65, 0, 0, 10),
					Position = UDim2.new(0, 15, 0, 38),
					BackgroundColor3 = Color3.fromRGB(20, 20, 25),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
					Fill = e("Frame", {
						Size = UDim2.new(percent, 0, 1, 0),
						BackgroundColor3 = isCompleted and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(130, 80, 255),
						BorderSizePixel = 0,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
					})
				}),

				ActionBtn = not isClaimed and e("TextButton", {
					Text = isCompleted and "KLAIM\n($" .. GameUtils.formatCompact(m.Reward) .. ")" or "BELUM SELESAI",
					Size = UDim2.new(0, 110, 0, 45),
					Position = UDim2.new(1, -125, 0.5, -22),
					BackgroundColor3 = isCompleted and Color3.fromRGB(0, 170, 110) or Color3.fromRGB(60, 60, 70),
					TextColor3 = isCompleted and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 160),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					BorderSizePixel = 0,
					Active = isCompleted,
					[React.Event.Activated] = function()
						if isCompleted and props.onClaimMilestone then
							props.onClaimMilestone(m.ID)
						end
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}) or e("TextLabel", {
					Text = "✓ KLAIMED",
					Size = UDim2.new(0, 110, 0, 45),
					Position = UDim2.new(1, -125, 0.5, -22),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(80, 255, 120),
					TextSize = 11,
					Font = Enum.Font.GothamBold,
				})
			})
		end
	end

	addMilestoneList(MILESTONES_CONFIG.CarsSold, milestones.TotalCarsSold, "CarsSold")
	addMilestoneList(MILESTONES_CONFIG.BoxesOpened, milestones.TotalBoxesOpened, "BoxesOpened")

	return e("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, {
		-- LEFT PANEL: DAILY QUESTS
		DailyPanel = e("Frame", {
			Size = UDim2.new(0.48, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(25, 25, 33),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			
			Title = e("TextLabel", {
				Text = "MISI HARIAN (24 JAM)",
				Size = UDim2.new(1, -30, 0, 45),
				Position = UDim2.new(0, 15, 0, 15),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			ScrollArea = e("ScrollingFrame", {
				Size = UDim2.new(1, -20, 1, -80),
				Position = UDim2.new(0, 10, 0, 65),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(0, 0, 0, 220),
			}, dailyElements)
		}),

		-- RIGHT PANEL: LIFETIME MILESTONES
		MilestonePanel = e("Frame", {
			Size = UDim2.new(0.48, 0, 1, 0),
			Position = UDim2.new(0.52, 0, 0, 0),
			BackgroundColor3 = Color3.fromRGB(25, 25, 33),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			
			Title = e("TextLabel", {
				Text = "PENCAPAIAN LIFE-TIME",
				Size = UDim2.new(1, -30, 0, 45),
				Position = UDim2.new(0, 15, 0, 15),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			ScrollArea = e("ScrollingFrame", {
				Size = UDim2.new(1, -20, 1, -80),
				Position = UDim2.new(0, 10, 0, 65),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				CanvasSize = UDim2.new(0, 0, 0, 420),
			}, milestoneElements)
		})
	})
end

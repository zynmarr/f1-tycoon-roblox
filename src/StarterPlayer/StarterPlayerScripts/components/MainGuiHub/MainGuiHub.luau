local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect

local RebirthTab = require(script.Parent.RebirthTab)
local DailyRewardsTab = require(script.Parent.DailyRewardsTab)
local QuestsTab = require(script.Parent.QuestsTab)

return function(props)
	local activeTab, setActiveTab = useState("Rebirth")
	local viewportSize, setViewportSize = useState(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600))

	-- Pantau perubahan ukuran layar secara real-time
	useEffect(function()
		local connection: RBXScriptConnection? = nil

		local function setupCamera(cam: Camera?)
			if connection then
				connection:Disconnect()
				connection = nil
			end
			if cam then
				connection = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
					setViewportSize(cam.ViewportSize)
				end)
				setViewportSize(cam.ViewportSize)
			end
		end

		setupCamera(workspace.CurrentCamera)

		local camConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			setupCamera(workspace.CurrentCamera)
		end)

		return function()
			if connection then
				connection:Disconnect()
			end
			camConnection:Disconnect()
		end
	end, {})

	local isMobile = viewportSize.X < 650 or viewportSize.Y < 500

	-- Menentukan komponen apa yang akan dirender di konten utama
	local activeComponent = nil
	if activeTab == "Rebirth" then
		activeComponent = e(RebirthTab, {
			IsMobile = isMobile,
			Cash = props.Cash,
			RebirthLevel = props.RebirthLevel,
			RebirthPoints = props.RebirthPoints,
			RebirthUpgrades = props.RebirthUpgrades,
			onRebirth = props.onRebirth,
			onUpgrade = props.onUpgrade,
		})
	elseif activeTab == "Daily" then
		activeComponent = e(DailyRewardsTab, {
			IsMobile = isMobile,
			Streak = props.Streak,
			LastClaimTime = props.LastClaimTime,
			onClaimReward = props.onClaimReward,
		})
	elseif activeTab == "Quests" then
		activeComponent = e(QuestsTab, {
			IsMobile = isMobile,
			DailyQuests = props.DailyQuests,
			MilestoneStats = props.MilestoneStats,
			onClaimQuest = props.onClaimQuest,
			onClaimMilestone = props.onClaimMilestone,
		})
	end

	local mainContent
	if isMobile then
		mainContent = e("Frame", {
			Size = UDim2.new(0.96, 0, 0.94, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(18, 18, 24),
			BorderSizePixel = 1,
			BorderColor3 = Color3.fromRGB(45, 45, 55),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),

			SizeConstraint = e("UISizeConstraint", {
				MinSize = Vector2.new(280, 200),
				MaxSize = Vector2.new(9999, 9999),
			}),

			-- HEADER
			Header = e("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = Color3.fromRGB(24, 24, 32),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				
				Title = e("TextLabel", {
					Text = "🔱 REWARDS HUB",
					Size = UDim2.new(0.4, 0, 1, 0),
					Position = UDim2.new(0, 10, 0, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 11,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				StatsContainer = e("Frame", {
					Size = UDim2.new(0.45, 0, 1, 0),
					Position = UDim2.new(0.42, 0, 0, 0),
					BackgroundTransparency = 1,
				}, {
					List = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 8),
					}),

					CashLabel = e("TextLabel", {
						Text = "💰 <font color='#00FFAA'>$" .. GameUtils.formatCompact(props.Cash or 0) .. "</font>",
						Size = UDim2.new(0, 65, 0, 24),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 10,
						Font = Enum.Font.GothamBold,
						RichText = true,
						TextXAlignment = Enum.TextXAlignment.Right,
					}),

					RPLabel = e("TextLabel", {
						Text = "🔱 <font color='#00E5FF'>" .. GameUtils.formatCompact(props.RebirthPoints or 0) .. "</font>",
						Size = UDim2.new(0, 45, 0, 24),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 10,
						Font = Enum.Font.GothamBold,
						RichText = true,
						TextXAlignment = Enum.TextXAlignment.Right,
					}),
				}),

				CloseBtn = e("TextButton", {
					Text = "✕",
					Size = UDim2.new(0, 26, 0, 26),
					Position = UDim2.new(1, -10, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(50, 50, 60),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					BorderSizePixel = 0,
					[React.Event.Activated] = function()
						if props.onClose then
							props.onClose()
						end
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				})
			}),

			-- HORIZONTAL TAB NAVIGATION
			TabBar = e("Frame", {
				Size = UDim2.new(1, -20, 0, 30),
				Position = UDim2.new(0, 10, 0, 46),
				BackgroundTransparency = 1,
			}, {
				List = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 6),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				RebirthTabBtn = e("TextButton", {
					Text = "🔱 Rebirth",
					Size = UDim2.new(0.31, 0, 1, 0),
					BackgroundColor3 = (activeTab == "Rebirth") and Color3.fromRGB(0, 130, 255) or Color3.fromRGB(30, 30, 38),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					BorderSizePixel = 0,
					[React.Event.Activated] = function()
						setActiveTab("Rebirth")
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),

				DailyTabBtn = e("TextButton", {
					Text = "📅 Daily",
					Size = UDim2.new(0.31, 0, 1, 0),
					BackgroundColor3 = (activeTab == "Daily") and Color3.fromRGB(0, 130, 255) or Color3.fromRGB(30, 30, 38),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					BorderSizePixel = 0,
					[React.Event.Activated] = function()
						setActiveTab("Daily")
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),

				QuestsTabBtn = e("TextButton", {
					Text = "📜 Quests",
					Size = UDim2.new(0.31, 0, 1, 0),
					BackgroundColor3 = (activeTab == "Quests") and Color3.fromRGB(0, 130, 255) or Color3.fromRGB(30, 30, 38),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					BorderSizePixel = 0,
					[React.Event.Activated] = function()
						setActiveTab("Quests")
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),
			}),

			-- VIEWPORT CONTENT
			Viewport = e("Frame", {
				Size = UDim2.new(1, -20, 1, -94),
				Position = UDim2.new(0, 10, 0, 84),
				BackgroundTransparency = 1,
			}, {
				Content = activeComponent
			})
		})
	else
		mainContent = e("Frame", {
			Size = UDim2.new(0.85, 0, 0.85, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(18, 18, 24),
		BorderSizePixel = 1,
		BorderColor3 = Color3.fromRGB(45, 45, 55),
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),

		SizeConstraint = e("UISizeConstraint", {
			MinSize = Vector2.new(550, 300),
			MaxSize = Vector2.new(800, 460),
		}),

		-- HEADER STATE
		Header = e("Frame", {
			Size = UDim2.new(1, 0, 0, 55),
			BackgroundColor3 = Color3.fromRGB(24, 24, 32),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			
			Title = e("TextLabel", {
				Text = "🔱 REWARDS & REBIRTH HUB",
				Size = UDim2.new(0.4, 0, 1, 0),
				Position = UDim2.new(0, 20, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			-- STATS DISPLAY (CASH & REBIRTH POINTS)
			StatsContainer = e("Frame", {
				Size = UDim2.new(0.42, 0, 1, 0),
				Position = UDim2.new(0.52, 0, 0, 0),
				BackgroundTransparency = 1,
			}, {
				List = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 20),
				}),

				CashLabel = e("TextLabel", {
					Text = "💰 <font color='#00FFAA'>$" .. GameUtils.formatCompact(props.Cash or 0) .. "</font>",
					Size = UDim2.new(0, 140, 0, 30),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					RichText = true,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),

				RPLabel = e("TextLabel", {
					Text = "🔱 <font color='#00E5FF'>" .. tostring(props.RebirthPoints or 0) .. " RP</font>",
					Size = UDim2.new(0, 100, 0, 30),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					RichText = true,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			}),

			CloseBtn = e("TextButton", {
				Text = "X",
				Size = UDim2.new(0, 35, 0, 35),
				Position = UDim2.new(1, -45, 0.5, -17),
				BackgroundColor3 = Color3.fromRGB(50, 50, 60),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				BorderSizePixel = 0,
				[React.Event.Activated] = function()
					if props.onClose then
						props.onClose()
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 18) }),
			})
		}),

		-- SIDEBAR NAVIGATION
		Sidebar = e("Frame", {
			Size = UDim2.new(0.24, 0, 1, -55),
			Position = UDim2.new(0, 0, 0, 55),
			BackgroundColor3 = Color3.fromRGB(22, 22, 28),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			
			List = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 8),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 15),
			}),

			-- TAB BUTTONS
			RebirthTabBtn = e("TextButton", {
				Text = "🔱 Rebirth Shop",
				Size = UDim2.new(0.9, 0, 0, 45),
				BackgroundColor3 = (activeTab == "Rebirth") and Color3.fromRGB(0, 130, 255) or Color3.fromRGB(30, 30, 38),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				BorderSizePixel = 0,
				[React.Event.Activated] = function()
					setActiveTab("Rebirth")
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),

			DailyTabBtn = e("TextButton", {
				Text = "📅 Hadiah Harian",
				Size = UDim2.new(0.9, 0, 0, 45),
				BackgroundColor3 = (activeTab == "Daily") and Color3.fromRGB(0, 130, 255) or Color3.fromRGB(30, 30, 38),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				BorderSizePixel = 0,
				[React.Event.Activated] = function()
					setActiveTab("Daily")
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),

			QuestsTabBtn = e("TextButton", {
				Text = "📜 Misi & Pencapaian",
				Size = UDim2.new(0.9, 0, 0, 45),
				BackgroundColor3 = (activeTab == "Quests") and Color3.fromRGB(0, 130, 255) or Color3.fromRGB(30, 30, 38),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				BorderSizePixel = 0,
				[React.Event.Activated] = function()
					setActiveTab("Quests")
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
		}),

		-- VIEWPORT AREA
		Viewport = e("Frame", {
			Size = UDim2.new(0.73, 0, 1, -75),
			Position = UDim2.new(0.25, 0, 0, 65),
			BackgroundTransparency = 1,
		}, {
			Content = activeComponent
		})
	})
	end

	return e("Frame", {
		Size = props.IsMobile and UDim2.new(1, 0, 1, 0) or UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 0.55,
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		Active = true,
	}, {
		MainContainer = mainContent
	})
end

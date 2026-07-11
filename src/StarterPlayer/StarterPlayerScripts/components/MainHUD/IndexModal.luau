local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local player = Players.LocalPlayer

local RARITY_COLORS = {
	["Common"] = Color3.fromRGB(150, 150, 150),
	["Uncommon"] = Color3.fromRGB(0, 220, 100),
	["Rare"] = Color3.fromRGB(0, 160, 255),
	["Epic"] = Color3.fromRGB(180, 50, 255),
	["Legendary"] = Color3.fromRGB(255, 130, 0),
	["Mythic"] = Color3.fromRGB(255, 30, 80),
	["God"] = Color3.fromRGB(0, 255, 230),
	["Celestial"] = Color3.fromRGB(255, 215, 0),
}

local function IndexModal(props: {
	IsMobile: boolean,
	OnClose: () -> (),
})
	local selectedRarity, setSelectedRarity = useState("Common")

	-- Fetch Player Collection
	local collection, setCollection = useState({} :: { [string]: boolean })
	
	local function updateCollection()
		local attr = player:GetAttribute("CarIndexCollection")
		if attr then
			local success, decoded = pcall(HttpService.JSONDecode, HttpService, attr)
			if success and typeof(decoded) == "table" then
				setCollection(decoded)
				return
			end
		end
		setCollection({})
	end

	useEffect(function()
		updateCollection()
		local conn = player.AttributeChanged:Connect(function(attrName)
			if attrName == "CarIndexCollection" then
				updateCollection()
			end
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	-- Calculate Stats
	local totalCarsCount = 0
	local unlockedCarsCount = 0
	
	for rarityName, carPool in pairs(GameConfig.CarRarityList) do
		for carName, _ in pairs(carPool) do
			totalCarsCount = totalCarsCount + 1
			-- Check if base version is unlocked
			local baseKey = carName .. "_" .. rarityName .. "_Normal"
			if collection[baseKey] then
				unlockedCarsCount = unlockedCarsCount + 1
			end
		end
	end

	local percent = totalCarsCount > 0 and (unlockedCarsCount / totalCarsCount) * 100 or 0

	-- Recalculate collection multiplier
	local currentMultiplier = 1.0
	for key, _ in pairs(collection) do
		local parts = string.split(key, "_")
		local varStr = parts[3] or "Normal"
		currentMultiplier = currentMultiplier + 0.002
		if varStr ~= "Normal" then
			currentMultiplier = currentMultiplier + 0.010
		end
	end
	local multiplierPercent = (currentMultiplier - 1.0) * 100

	-- Build category tabs for rarities
	local rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "God", "Celestial" }
	local tabElements = {}
	for idx, rName in ipairs(rarities) do
		local isSelected = (selectedRarity == rName)
		local col = RARITY_COLORS[rName] or Color3.fromRGB(255, 255, 255)

		tabElements["Tab_" .. rName] = e("TextButton", {
			Text = rName,
			Size = UDim2.new(0.115, 0, 1, 0),
			BackgroundColor3 = isSelected and col or Color3.fromRGB(25, 25, 30),
			BackgroundTransparency = isSelected and 0.15 or 0.5,
			TextColor3 = isSelected and Color3.fromRGB(15, 15, 18) or Color3.fromRGB(240, 240, 240),
			Font = Enum.Font.GothamBold,
			TextSize = props.IsMobile and 8 or 9,
			LayoutOrder = idx,
			[React.Event.Activated] = function()
				setSelectedRarity(rName)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Stroke = e("UIStroke", {
				Color = isSelected and col or Color3.fromRGB(55, 55, 65),
				Thickness = 0.8,
			}),
		})
	end

	-- Build Car Catalog Cards
	local carCards = {}
	local selectedPool = GameConfig.CarRarityList[selectedRarity] or {}
	local i = 0
	for carName, _ in pairs(selectedPool) do
		i = i + 1
		
		-- Check unlocked base version
		local baseKey = carName .. "_" .. selectedRarity .. "_Normal"
		local isUnlocked = (collection[baseKey] == true)

		-- Find unlocked variants of this car
		local unlockedVariants = {}
		for key, _ in pairs(collection) do
			if string.find(key, carName .. "_" .. selectedRarity .. "_", 1, true) == 1 then
				local parts = string.split(key, "_")
				local variantName = parts[3] or "Normal"
				if variantName ~= "Normal" then
					table.insert(unlockedVariants, variantName)
				end
			end
		end

		local cardColor = RARITY_COLORS[selectedRarity] or Color3.fromRGB(100, 100, 100)

		carCards["CarCard_" .. i] = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = isUnlocked and Color3.fromRGB(20, 20, 25) or Color3.fromRGB(10, 10, 12),
			BackgroundTransparency = isUnlocked and 0.3 or 0.6,
			LayoutOrder = i,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Color = isUnlocked and cardColor or Color3.fromRGB(45, 45, 50),
				Thickness = isUnlocked and 1 or 0.8,
			}),

			-- Locked Overlay / Dark filter
			DarkOverlay = (not isUnlocked) and e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.65,
				ZIndex = 5,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				LockLabel = e("TextLabel", {
					Text = "🔒 LUCK?",
					Size = UDim2.fromScale(1, 0.4),
					Position = UDim2.fromScale(0.5, 0.4),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(140, 140, 150),
					TextSize = 10,
					Font = Enum.Font.GothamBold,
				}),
			}) or nil,

			-- Car Visual Indicator (Emoji icon)
			IconLabel = e("TextLabel", {
				Text = isUnlocked and "🏎️" or "❓",
				Size = UDim2.fromScale(1, 0.45),
				Position = UDim2.fromScale(0.5, 0.3),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				TextColor3 = cardColor,
				TextSize = 22,
				Font = Enum.Font.GothamBold,
			}),

			-- Car Name
			CarName = e("TextLabel", {
				Text = isUnlocked and carName or "??? (Terkunci)",
				Size = UDim2.new(1, -10, 0, 24),
				Position = UDim2.new(0.5, 0, 0.65, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				TextColor3 = isUnlocked and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(110, 110, 120),
				TextSize = 7.5,
				Font = Enum.Font.GothamBold,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),

			-- Variants badging indicators (e.g. G = Gold, R = Rainbow, etc.)
			VariantsList = isUnlocked and (#unlockedVariants > 0) and e("Frame", {
				Size = UDim2.new(1, -8, 0, 10),
				Position = UDim2.new(0.5, 0, 1, -16),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
			}, (function()
				local varItems = {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),
				}
				for vIdx, vName in ipairs(unlockedVariants) do
					local vData = GameConfig.Variants[vName]
					local col = (vData and typeof(vData.Color) == "Color3") and vData.Color or Color3.fromRGB(255, 255, 255)
					
					varItems["Badge_" .. vName] = e("Frame", {
						Size = UDim2.fromOffset(8, 8),
						BackgroundColor3 = col,
						LayoutOrder = vIdx,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
						Tooltip = e("UIStroke", {
							Color = Color3.fromRGB(255, 255, 255),
							Thickness = 0.5,
						}),
					})
				end
				return varItems
			end)()) or nil,
		})
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 0.55,
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		Active = true,
		ZIndex = 25,
	}, {
		-- Backdrop exit detector
		BackdropClose = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			[React.Event.Activated] = props.OnClose,
		}),

		-- Modal Container
		Modal = e("Frame", {
			Size = props.IsMobile and UDim2.new(0.85, 0, 0.85, 0) or UDim2.fromOffset(500, 360),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(15, 15, 18),
			BackgroundTransparency = 0.15,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(55, 55, 65),
				Thickness = 1.2,
			}, {
				Gradient = e("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 204)), -- Cyan outline
						ColorSequenceKeypoint.new(0.4, Color3.fromRGB(55, 55, 65)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 35)),
					}),
					Rotation = -45,
				}),
			}),

			-- Racing Accent Stripe
			RacingStripe = e("Frame", {
				Size = UDim2.new(0.25, 0, 0, 2),
				Position = UDim2.new(0.5, 0, 0, 1),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.fromRGB(0, 255, 204),
				BorderSizePixel = 0,
				ZIndex = 6,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 1) }),
			}),

			-- Layout & Padding
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 15),
				PaddingBottom = UDim.new(0, 15),
				PaddingLeft = UDim.new(0, 15),
				PaddingRight = UDim.new(0, 15),
			}),

			-- Header Block
			Header = e("Frame", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
			}, {
				Title = e("TextLabel", {
					Text = "🏆 INDEKS KOLEKSI MOBIL",
					Size = UDim2.new(0.6, 0, 1, 0),
					Position = UDim2.new(0, 0, 0, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 13,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				CloseBtn = e("TextButton", {
					Text = "X",
					Size = UDim2.fromOffset(24, 24),
					Position = UDim2.new(1, 0, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 35, 85),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					[React.Event.Activated] = props.OnClose,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),
			}),

			-- Progress Stats Bar
			ProgressBarFrame = e("Frame", {
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = Color3.fromRGB(24, 24, 28),
				LayoutOrder = 2,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(45, 45, 50),
					Thickness = 0.8,
				}),

				-- Filled progress
				Fill = e("Frame", {
					Size = UDim2.fromScale(percent / 100, 1),
					BackgroundColor3 = Color3.fromRGB(0, 255, 204),
					BackgroundTransparency = 0.85,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),

				-- Text indicator
				TextStats = e("TextLabel", {
					Text = `Membuka Koleksi: {unlockedCarsCount}/{totalCarsCount} ({string.format("%.1f", percent)}%)   •   Cash Multiplier: +{string.format("%.1f", multiplierPercent)}%`,
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(0, 255, 204),
					TextSize = 9.5,
					Font = Enum.Font.GothamBold,
				}),
			}),

			-- Rarity Category Selection Tabs
			TabsFrame = e("Frame", {
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				LayoutOrder = 3,
			}, (function()
				local tItems = {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),
				}
				for k, el in pairs(tabElements) do
					tItems[k] = el
				end
				return tItems
			end)()),

			-- Grid Catalogue Scroll Frame
			GridScroll = e("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, -100),
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y :: any,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Color3.fromRGB(0, 255, 204),
				LayoutOrder = 4,
			}, (function()
				local sItems = {
					GridLayout = e("UIGridLayout", {
						CellSize = props.IsMobile and UDim2.fromOffset(72, 72) or UDim2.fromOffset(80, 80),
						CellPadding = UDim2.fromOffset(10, 10),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
				}
				for k, el in pairs(carCards) do
					sItems[k] = el
				end
				return sItems
			end)()),
		}),
	})
end

return IndexModal

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage.Packages.React)
local ViewportManager = require(script.Parent.Parent.ViewportManager)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))

-- ===== UTILITIES =====
local viewportCache = ViewportManager.new()

local function formatPrice(price)
	return GameUtils.formatPrice(price)
end

-- ===== NESTED SUB-CAR ITEM COMPONENT (FOR STACK MEMBERS) =====
local function SubCarItem(props)
	local car = props.car
	local stackChildName = props.stackChildName
	local onSell = props.onSell
	
	local carName = props.name or "Unknown"
	local carPrice = props.price or 0
	local carVariant = props.variant or "Normal"
	local carRarity = props.rarity or "Common"
	local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
	local rarityColor = GameConfig.Rarities[carRarity] and GameConfig.Rarities[carRarity].Color or Color3.fromRGB(150, 150, 150)

	return e("Frame", {
		Size = UDim2.new(1, -30, 0, 75), -- Indented from left by 30 pixels
		Position = UDim2.new(0, 30, 0, 0),
		BackgroundColor3 = Color3.fromRGB(32, 32, 40),
		BorderColor3 = Color3.fromRGB(55, 55, 65),
		BorderSizePixel = 1,
		LayoutOrder = props.layoutOrder or 1,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		
		-- Small indicator line on the left showing rarity color
		RarityBar = e("Frame", {
			Size = UDim2.new(0, 4, 1, -12),
			Position = UDim2.new(0, 6, 0, 6),
			BackgroundColor3 = rarityColor,
			BorderSizePixel = 0,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 2) }),
		}),

		InfoContainer = e("Frame", {
			Size = UDim2.new(1, -145, 1, 0),
			Position = UDim2.new(0, 18, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 2),
			}),

			VariantText = e("TextLabel", {
				Text = ViewportManager.formatPrice and GameConfig.GetColoredVariantList(carVariant) or carVariant,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(240, 240, 240),
				TextScaled = true,
				RichText = true,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			MetaText = e("TextLabel", {
				Text = string.format("<font color='#%s'>%s</font> • <font color='#00FF00'>$%s</font>", rarityColor:ToHex(), carRarity:upper(), formatPrice(carPrice)),
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(180, 180, 180),
				TextScaled = true,
				RichText = true,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),

		ActionArea = e("Frame", {
			Size = UDim2.new(0, 90, 1, 0),
			Position = UDim2.new(1, -100, 0, 0),
			BackgroundTransparency = 1,
		}, {
			SellButton = e("TextButton", {
				Text = "SELL",
				Size = UDim2.new(1, 0, 0, 40),
				Position = UDim2.new(0, 0, 0.5, -20),
				BackgroundColor3 = Color3.fromRGB(185, 45, 45),
				BorderSizePixel = 0,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				[React.Event.Activated] = function()
					if onSell then
						onSell(car, stackChildName)
					end
				end,
			}, {
				UICorner = e("UICorner", { CornerRadius = UDim.new(0, 5) }),
			}),
		}),
	})
end

-- ===== CAR ITEM COMPONENT =====
local function CarItem(props)
	local car = props.car
	local onSell = props.onSell
	local isExpanded = props.isExpanded
	local onToggleExpand = props.onToggleExpand

	local carName = "Unknown"
	local carPrice = 0
	local carVariant = "Normal"
	local carAmount = 1
	local carRarity = "Common"
	local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

	if typeof(car) == "Instance" and car:IsA("Tool") then
		carName = car:GetAttribute("Name") or car.Name
		carPrice = car:GetAttribute("Price") or 0
		carVariant = car:GetAttribute("Variant") or "Normal"
		carAmount = car:GetAttribute("Amount") or 1
		carRarity = car:GetAttribute("Rarity") or "Common"
	elseif type(car) == "table" then
		carName = car.Name or "Unknown"
		carPrice = car.Price or 0
		carVariant = car.Variant or "Normal"
		carAmount = car.Amount or 1
		carRarity = car.Rarity or "Common"
	end

	local isStack = carAmount > 1
	local rarityColor = GameConfig.Rarities[carRarity] and GameConfig.Rarities[carRarity].Color or Color3.fromRGB(150, 150, 150)

	-- Build nested sub-items UI if it is a stack and expanded
	local subItems = {}
	if isStack and isExpanded then
		-- 1. Main Base Tool (Representing the first car item)
		table.insert(subItems, e(SubCarItem, {
			car = car,
			stackChildName = "Base",
			name = carName,
			price = carPrice,
			variant = carVariant,
			rarity = carRarity,
			onSell = onSell,
			layoutOrder = 1,
		}))

		-- 2. Inner stack configurations in tool folder
		if typeof(car) == "Instance" then
			local stacksFolder = car:FindFirstChild("Stacks")
			if stacksFolder then
				local index = 2
				for _, configNode in ipairs(stacksFolder:GetChildren()) do
					if configNode:IsA("Configuration") then
						table.insert(subItems, e(SubCarItem, {
							car = car,
							stackChildName = configNode.Name,
							name = carName,
							price = configNode:GetAttribute("Price") or 0,
							variant = configNode:GetAttribute("Variant") or "Normal",
							rarity = configNode:GetAttribute("Rarity") or "Common",
							onSell = onSell,
							layoutOrder = index,
						}))
						index = index + 1
					end
				end
			end
		else
			-- Mock stack children for UI Storybook
			for i = 2, carAmount do
				table.insert(subItems, e(SubCarItem, {
					car = car,
					stackChildName = "MockStack_" .. i,
					name = carName,
					price = carPrice,
					variant = carVariant,
					rarity = carRarity,
					onSell = onSell,
					layoutOrder = i,
				}))
			end
		end
	end

	local subItemsContainer = nil
	if #subItems > 0 then
		local layout = {
			UIListLayout = e("UIListLayout", {
				Padding = UDim.new(0, 6),
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for i, child in ipairs(subItems) do
			layout["SubCar_" .. i] = child
		end

		subItemsContainer = e("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}, layout)
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder or 1,
	}, {
		UIListLayout = e("UIListLayout", {
			Padding = UDim.new(0, 6),
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		-- Card Head (Main Info Box)
		CardHeader = e("Frame", {
			Size = UDim2.new(1, 0, 0, 110),
			BackgroundColor3 = Color3.fromRGB(24, 24, 30),
			BorderColor3 = isStack and Color3.fromRGB(0, 162, 255) or Color3.fromRGB(50, 50, 60),
			BorderSizePixel = isStack and 1.5 or 1,
			LayoutOrder = 1,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),

			-- Glowing outline visual indicator if it is a stack
			GlowLine = isStack and e("Frame", {
				Size = UDim2.new(0, 4, 1, -16),
				Position = UDim2.new(0, 6, 0, 8),
				BackgroundColor3 = Color3.fromRGB(0, 162, 255),
				BorderSizePixel = 0,
			}, {
				UICorner = e("UICorner", { CornerRadius = UDim.new(0, 2) }),
			}) or nil,

			ViewportFrame = e("ViewportFrame", {
				Name = "CarView_" .. (props.layoutOrder or 1),
				Size = UDim2.new(0, 90, 0, 90),
				Position = UDim2.new(0, 16, 0, 10),
				BackgroundColor3 = Color3.fromRGB(16, 16, 20),
				BorderSizePixel = 0,
			}, {
				UICorner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				AmountLabel = e("TextLabel", {
					Text = "x" .. tostring(carAmount),
					Size = UDim2.new(0, 35, 0, 22),
					Position = UDim2.new(0.5, -17.5, 1, -25),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = isStack and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(20, 20, 25),
					BorderColor3 = isStack and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(70, 70, 80),
					BorderSizePixel = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Font = Enum.Font.GothamBold,
				}, {
					UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				}),
			}),

			-- Click target to expand (only active if it is a stack)
			ExpandClickButton = isStack and e("TextButton", {
				Size = UDim2.new(1, -230, 1, 0),
				Position = UDim2.new(0, 120, 0, 0),
				BackgroundTransparency = 1,
				Text = "",
				[React.Event.Activated] = onToggleExpand,
			}) or nil,

			InfoContainer = e("Frame", {
				Size = UDim2.new(1, isStack and -240 or -230, 1, 0),
				Position = UDim2.new(0, 120, 0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, {
				NameLabel = e("TextLabel", {
					Text = string.sub(carName, 1, 24),
					Size = UDim2.new(1, -10, 0, 22),
					Position = UDim2.new(0, 10, 0, 10),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				VariantLabel = e("TextLabel", {
					Text = GameConfig.GetColoredVariantList(carVariant),
					Size = UDim2.new(1, -10, 0, 18),
					Position = UDim2.new(0, 10, 0, 36),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					RichText = true,
					Font = Enum.Font.GothamMedium,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				RarityBadge = e("TextLabel", {
					Text = carRarity:upper(),
					Size = UDim2.new(0, 75, 0, 18),
					Position = UDim2.new(0, 10, 0, 58),
					BackgroundColor3 = rarityColor,
					BorderSizePixel = 0,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Font = Enum.Font.GothamBold,
				}, {
					UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				}),

				PriceLabel = e("TextLabel", {
					Text = isStack and "MULTIPLE CARS STACKED" or ("$" .. formatPrice(carPrice)),
					Size = UDim2.new(1, -10, 0, 20),
					Position = UDim2.new(0, 10, 1, -26),
					BackgroundTransparency = 1,
					TextColor3 = isStack and Color3.fromRGB(0, 162, 255) or Color3.fromRGB(90, 240, 90),
					TextScaled = true,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),

			ActionArea = e("Frame", {
				Size = UDim2.new(0, 100, 1, 0),
				Position = UDim2.new(1, -110, 0, 0),
				BackgroundTransparency = 1,
			}, {
				-- Show SELL button if it is a single car
				SellButton = not isStack and e("TextButton", {
					Text = "SELL",
					Size = UDim2.new(1, 0, 0, 44),
					Position = UDim2.new(0, 0, 0.5, -22),
					BackgroundColor3 = Color3.fromRGB(185, 45, 45),
					BorderSizePixel = 0,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Font = Enum.Font.GothamBold,
					[React.Event.Activated] = function()
						if onSell then
							onSell(car)
						end
					end,
				}, {
					UICorner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}) or nil,

				-- Show EXPAND/COLLAPSE toggle button if it is a stack
				ExpandButton = isStack and e("TextButton", {
					Text = isExpanded and "COLLAPSE" or "VIEW STACK",
					Size = UDim2.new(1, 0, 0, 44),
					Position = UDim2.new(0, 0, 0.5, -22),
					BackgroundColor3 = isExpanded and Color3.fromRGB(50, 60, 75) or Color3.fromRGB(0, 110, 180),
					BorderSizePixel = 0,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Font = Enum.Font.GothamBold,
					[React.Event.Activated] = onToggleExpand,
				}, {
					UICorner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}) or nil,
			}),
		}),

		-- Sub items list below
		SubItemsList = subItemsContainer,
	})
end

-- ===== MAIN SELLGUI COMPONENT =====
local function SellGui(props)
	local isStorybook = props.isStorybook or props.IsStorybook or false
	local cars, setCars = useState({})
	local expandedStacks, setExpandedStacks = useState({})

	useEffect(function()
		local activeBackpack = player:WaitForChild("Backpack", 5) or player:FindFirstChild("Backpack")
		if not activeBackpack then
			warn("[SellGui] Backpack tidak ditemukan!")
			return
		end

		if isStorybook then
			setCars({
				{ Name = "Ferrari SF23", Price = 50000, Variant = "Golden", Rarity = "Legendary", Amount = 1 },
				{ Name = "Mercedes AMG W14", Price = 45000, Variant = "Normal", Rarity = "Epic", Amount = 3 },
				{ Name = "McLaren MCL38", Price = 35000, Variant = "Galaxy", Rarity = "Mythic", Amount = 1 },
				{ Name = "Red Bull RB19", Price = 80000, Variant = "Carbon", Rarity = "God", Amount = 2 },
			})
			return
		end

		local function updateCars()
			local backpackCars = GameUtils.getPlayerCars(player)
			print("[SellGui] Total mobil berhasil dimuat ke UI: " .. tostring(#backpackCars))
			setCars(backpackCars)
		end

		-- Pindai awal
		updateCars()

		-- Hubungkan listener perubahan backpack
		local connection = activeBackpack.ChildAdded:Connect(function()
			task.delay(0.3, updateCars)
		end)

		local removeConnection = activeBackpack.ChildRemoved:Connect(function()
			task.delay(0.1, updateCars)
		end)

		-- Hubungkan listener ketika karakter berpindah/meng-equip sesuatu
		local charAddedConn
		local charChildAddedConn
		local charChildRemovedConn

		local function setupCharacterListeners(character)
			if charChildAddedConn then charChildAddedConn:Disconnect() end
			if charChildRemovedConn then charChildRemovedConn:Disconnect() end

			charChildAddedConn = character.ChildAdded:Connect(function(child)
				if child:IsA("Tool") then
					task.delay(0.1, updateCars)
				end
			end)
			charChildRemovedConn = character.ChildRemoved:Connect(function(child)
				if child:IsA("Tool") then
					task.delay(0.1, updateCars)
				end
			end)
		end

		if player.Character then
			setupCharacterListeners(player.Character)
		end

		charAddedConn = player.CharacterAdded:Connect(function(character)
			setupCharacterListeners(character)
			task.delay(0.5, updateCars)
		end)

		return function()
			connection:Disconnect()
			removeConnection:Disconnect()
			if charAddedConn then charAddedConn:Disconnect() end
			if charChildAddedConn then charChildAddedConn:Disconnect() end
			if charChildRemovedConn then charChildRemovedConn:Disconnect() end
		end
	end, {})

	useEffect(function()
		task.defer(function()
			for i, car in ipairs(cars) do
				local carItem = playerGui:FindFirstChild("SellGui")
					and playerGui.SellGui:FindFirstChild("CarView_" .. i, true)
				if carItem and typeof(car) == "Instance" then
					ViewportManager.setupViewport(viewportCache, carItem, car, { bgTransparency = 0.95 })
				elseif carItem and not isStorybook then
					print("[SellGui] Warning: CarView_" .. i .. " not found for " .. car.Name)
				end
			end
		end)

		return function()
			for _, car in ipairs(cars) do
				if typeof(car) == "Instance" then
					ViewportManager.clearCache(viewportCache, car)
				end
			end
		end
	end, { cars })

	-- Build children for ListContainer
	local function buildListChildren()
		local children = {
			UIListLayout = e("UIListLayout", {
				Padding = UDim.new(0, 10),
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			}),
		}

		if #cars > 0 then
			for i, car in ipairs(cars) do
				children["CarItem_" .. i] = e(CarItem, {
					car = car,
					layoutOrder = i,
					isStorybook = isStorybook,
					isExpanded = expandedStacks[car] or false,
					onToggleExpand = function()
						local newExpanded = table.clone(expandedStacks)
						newExpanded[car] = not (expandedStacks[car] or false)
						setExpandedStacks(newExpanded)
					end,
					onSell = function(selectedCar, stackChildName)
						if props.onSellCar then
							props.onSellCar(selectedCar, stackChildName)
						end
					end,
				})
			end
		else
			children["EmptyState"] = e("TextLabel", {
				Text = "No cars to sell 🚗",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(150, 150, 150),
				TextScaled = true,
				Font = Enum.Font.Gotham,
			})
		end

		return children
	end

	-- Responsive styling: Scale on mobile, locked max size on PC/Tablet
	local MainFrame = e("Frame", {
		Size = isStorybook and UDim2.new(1, 0, 1, 0) or UDim2.new(0.9, 0, 0.8, 0),
		Position = not isStorybook and UDim2.new(0.5, 0, 0.5, 0) or nil,
		AnchorPoint = not isStorybook and Vector2.new(0.5, 0.5) or nil,
		BackgroundColor3 = Color3.fromRGB(15, 15, 20),
		BorderColor3 = Color3.fromRGB(60, 60, 75),
		BorderSizePixel = 1,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),

		-- Max / Min constraint for responsiveness across device types
		UISizeConstraint = not isStorybook and e("UISizeConstraint", {
			MinSize = Vector2.new(320, 420),
			MaxSize = Vector2.new(520, 680),
		}) or nil,

		-- Header Section
		Header = e("Frame", {
			Size = UDim2.new(1, 0, 0, 55),
			BackgroundColor3 = Color3.fromRGB(20, 20, 25),
			BorderColor3 = Color3.fromRGB(50, 50, 60),
			BorderSizePixel = 1,
			LayoutOrder = 1,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			
			-- Cover top corners of corner frame to look clean
			CornerBlocker = e("Frame", {
				Size = UDim2.new(1, 0, 0, 10),
				Position = UDim2.new(0, 0, 1, -10),
				BackgroundColor3 = Color3.fromRGB(20, 20, 25),
				BorderSizePixel = 0,
			}),

			Title = e("TextLabel", {
				Text = "🏎️ GARAGE SALE",
				Size = UDim2.new(1, -200, 1, 0),
				Position = UDim2.new(0, 15, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			SellAllButton = e("TextButton", {
				Text = "SELL ALL",
				Size = UDim2.new(0, 95, 0, 36),
				Position = UDim2.new(1, -155, 0.5, -18),
				BackgroundColor3 = Color3.fromRGB(40, 160, 80),
				BorderSizePixel = 0,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				[React.Event.Activated] = function()
					if props.onSellAll then
						props.onSellAll(cars)
					end
				end,
			}, {
				UICorner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),

			-- Close Button (X)
			CloseButton = not isStorybook and e("TextButton", {
				Text = "X",
				Size = UDim2.new(0, 36, 0, 36),
				Position = UDim2.new(1, -50, 0.5, -18),
				BackgroundColor3 = Color3.fromRGB(180, 50, 50),
				BorderSizePixel = 0,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				[React.Event.Activated] = function()
					if props.onClose then
						props.onClose()
					end
				end,
			}, {
				UICorner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}) or nil,
		}),

		-- List Area (Scrollable)
		ListContainer = e("ScrollingFrame", {
			Name = "CarListScroll",
			Size = UDim2.new(1, 0, 1, -55),
			Position = UDim2.new(0, 0, 0, 55),
			BackgroundColor3 = Color3.fromRGB(15, 15, 20),
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Color3.fromRGB(80, 80, 95),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, -- Auto-fits all contents
		}, buildListChildren()),
	})

	return MainFrame
end

return SellGui

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local backpack = player:WaitForChild("Backpack")

-- ===== UTILITIES =====
local renderCache = {}
local MAX_CACHE_SIZE = 10

local function formatPrice(price)
	local str = tostring(price)
	return str:reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

local function clearCacheEntry(carTool)
	if renderCache[carTool] then
		local cache = renderCache[carTool]
		if cache.Model then
			if cache.Model.Parent then
				cache.Model.Parent = nil
			end
			cache.Model:Destroy()
		end
		if cache.Camera then
			if cache.Camera.Parent then
				cache.Camera.Parent = nil
			end
			cache.Camera:Destroy()
		end
		renderCache[carTool] = nil
	end
end

local function trimCache()
	if #renderCache > MAX_CACHE_SIZE then
		local count = 0
		for key in pairs(renderCache) do
			if count >= MAX_CACHE_SIZE then
				clearCacheEntry(key)
			end
			count = count + 1
		end
	end
end

local function setupCarViewport(viewport, carTool)
	local toolID = tostring(carTool)
	if viewport:GetAttribute("LastCar") == toolID then
		return
	end

	viewport:SetAttribute("LastCar", toolID)
	viewport.BackgroundTransparency = 0.95

	for _, child in pairs(viewport:GetChildren()) do
		if child:IsA("Camera") or child:IsA("Model") then
			if child.Parent then
				child.Parent = nil
			end
		end
	end

	if not renderCache[carTool] then
		local originalModel = nil
		local retryCount = 0
		while not originalModel and retryCount < 20 do
			originalModel = carTool:FindFirstChild("Model") or carTool:FindFirstChildOfClass("Model")
			if not originalModel then
				task.wait(0.1)
				retryCount = retryCount + 1
			end
		end

		if not originalModel then
			warn("[SellGui] Model tidak ditemukan untuk: " .. tostring(carTool.Name))
			return
		end

		local carClone = originalModel:Clone()
		carClone:PivotTo(CFrame.new(0, 0, 0))
		task.wait(0.05)

		local minX, minY, minZ = math.huge, math.huge, math.huge
		local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
		local hasVisuals = false

		for _, p in pairs(carClone:GetDescendants()) do
			if p:IsA("BasePart") or p:IsA("MeshPart") then
				p.CastShadow = false
				if p.Name == "Hitbox" or p.Name == "Handle" then
					p.Transparency = 1
				end
				if p.Transparency < 1 then
					hasVisuals = true
					local pos, size = p.Position, p.Size
					minX = math.min(minX, pos.X - (size.X / 2))
					minY = math.min(minY, pos.Y - (size.Y / 2))
					minZ = math.min(minZ, pos.Z - (size.Z / 2))
					maxX = math.max(maxX, pos.X + (size.X / 2))
					maxY = math.max(maxY, pos.Y + (size.Y / 2))
					maxZ = math.max(maxZ, pos.Z + (size.Z / 2))
				end
			end
		end

		if not hasVisuals then
			carClone:Destroy()
			warn("[SellGui] Mobil tidak memiliki visual: " .. tostring(carTool.Name))
			return
		end

		local center = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
		local size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
		local maxDim = math.max(size.X, size.Y, size.Z)
		if maxDim < 1 then
			maxDim = 15
		end

		local cam = Instance.new("Camera")
		cam.FieldOfView = 40
		local dist = (maxDim / 2) / math.tan(math.rad(20)) * 1.2
		local camPos = center + Vector3.new(-dist * 0.5, dist * 0.4, -dist * 0.7)
		cam.CFrame = CFrame.new(camPos, center + Vector3.new(0, maxDim * 0.1, 0))

		renderCache[carTool] = { Model = carClone, Camera = cam }
		trimCache()
	end

	local cache = renderCache[carTool]
	if cache then
		if cache.Model.Parent then
			cache.Model.Parent = nil
		end
		cache.Model.Parent = viewport
		task.wait(0.02)
		if cache.Camera.Parent then
			cache.Camera.Parent = nil
		end
		cache.Camera.Parent = viewport
		viewport.CurrentCamera = cache.Camera
		viewport.Ambient = Color3.fromRGB(200, 200, 200)
		viewport.LightColor = Color3.fromRGB(255, 255, 255)
	end
end

-- ===== CAR ITEM COMPONENT =====
local function CarItem(props)
	local car = props.car
	local onSell = props.onSell
	local _ = props.isStorybook or false

	local carName = car.Name or "Unknown"
	local carPrice = car.Price or 0
	local carVariant = car.Variant or "Normal"
	local carAmount = car.Amount or 1
	local carRarity = car.Rarity or "Common"

	if type(car) == "userdata" and car:IsA("Tool") then
		carName = car:GetAttribute("Name") or car.Name
		carPrice = car:GetAttribute("Price") or 0
		carVariant = car:GetAttribute("Variant") or "Normal"
		carAmount = car:GetAttribute("Amount") or 1
		carRarity = car:GetAttribute("Rarity") or "Common"
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BorderColor3 = Color3.fromRGB(70, 70, 70),
		BorderSizePixel = 1,
		LayoutOrder = props.layoutOrder or 1,
	}, {
		ViewportFrame = e("ViewportFrame", {
			Name = "CarView",
			Size = UDim2.new(0, 100, 0, 100),
			Position = UDim2.new(0, 10, 0, 10),
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			BorderSizePixel = 0,
		}, {
			AmountLabel = e("TextLabel", {
				Text = "x" .. tostring(carAmount),
				Size = UDim2.new(0, 40, 0, 25),
				Position = UDim2.new(0.5, -20, 1, -30),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				BorderColor3 = Color3.fromRGB(100, 100, 100),
				BorderSizePixel = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
			}),
		}),

		InfoContainer = e("Frame", {
			Size = UDim2.new(1, -230, 1, 0),
			Position = UDim2.new(0, 120, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			NameLabel = e("TextLabel", {
				Text = string.sub(carName, 1, 25),
				Size = UDim2.new(1, -10, 0, 28),
				Position = UDim2.new(0, 10, 0, 5),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			RarityLabel = e("TextLabel", {
				Text = carRarity,
				Size = UDim2.new(0, 80, 0, 18),
				Position = UDim2.new(0, 10, 0, 33),
				BackgroundColor3 = Color3.fromRGB(60, 60, 80),
				BorderSizePixel = 0,
				TextColor3 = Color3.fromRGB(200, 200, 255),
				TextScaled = true,
				Font = Enum.Font.Gotham,
			}),

			VariantLabel = e("TextLabel", {
				Text = carVariant,
				Size = UDim2.new(1, -100, 0, 18),
				Position = UDim2.new(0, 100, 0, 33),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextScaled = true,
				Font = Enum.Font.Gotham,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			PriceLabel = e("TextLabel", {
				Text = "$" .. formatPrice(carPrice),
				Size = UDim2.new(1, -10, 0, 25),
				Position = UDim2.new(0, 10, 1, -28),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(100, 255, 100),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),

		SellButton = e("TextButton", {
			Text = "SELL",
			Size = UDim2.new(0, 100, 0, 100),
			Position = UDim2.new(1, -110, 0, 10),
			BackgroundColor3 = Color3.fromRGB(200, 50, 50),
			BorderColor3 = Color3.fromRGB(255, 100, 100),
			BorderSizePixel = 2,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			[React.Event.Activated] = function()
				if onSell then
					onSell(car)
				end
			end,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 5),
			}),
		}),
	})
end

-- ===== MAIN SELLGUI COMPONENT =====
local function SellGui(props)
	local isStorybook = props.isStorybook or false
	local cars, setCars = useState({})

	useEffect(function()
		if isStorybook then
			setCars({
				{ Name = "Ferrari F1 2024", Price = 50000, Variant = "Golden", Rarity = "Legendary", Amount = 1 },
				{ Name = "Mercedes AMG GT", Price = 45000, Variant = "Normal", Rarity = "Epic", Amount = 2 },
				{ Name = "Lamborghini Revuelto", Price = 35000, Variant = "Galaxy", Rarity = "Rare", Amount = 1 },
				{ Name = "Porsche 911 Turbo", Price = 40000, Variant = "Normal", Rarity = "Epic", Amount = 1 },
			})
			return
		end

		local backpackCars = {}
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("Price") then
				table.insert(backpackCars, tool)
			end
		end
		setCars(backpackCars)

		local connection = backpack.ChildAdded:Connect(function()
			task.delay(0.3, function()
				local updated = {}
				for _, tool in pairs(backpack:GetChildren()) do
					if tool:IsA("Tool") and tool:GetAttribute("Price") then
						table.insert(updated, tool)
					end
				end
				setCars(updated)
			end)
		end)

		return function()
			connection:Disconnect()
		end
	end)

	useEffect(function()
		task.defer(function()
			for i, car in ipairs(cars) do
				local carItem = playerGui:FindFirstChild("SellGui")
					and playerGui.SellGui:FindFirstDescendant("CarView_" .. i)
				if carItem then
					setupCarViewport(carItem, car)
				end
			end
		end)

		return function()
			for _, car in ipairs(cars) do
				clearCacheEntry(car)
			end
		end
	end)

	-- Build children for ListContainer
	local function buildListChildren()
		local children = {
			UIListLayout = e("UIListLayout", {
				Padding = UDim.new(0, 10),
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
				PaddingTop = UDim.new(0, 5),
				PaddingBottom = UDim.new(0, 5),
			}),
		}

		if #cars > 0 then
			for i, car in ipairs(cars) do
				children["CarItem_" .. i] = e(CarItem, {
					car = car,
					layoutOrder = i,
					isStorybook = isStorybook,
					onSell = function(selectedCar)
						if props.onSellCar then
							props.onSellCar(selectedCar)
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

	local MainFrame = e("Frame", {
		Size = isStorybook and UDim2.new(1, 0, 1, 0) or UDim2.new(0, 500, 0, 600),
		Position = not isStorybook and UDim2.new(0.5, 0, 0.5, 0) or nil,
		AnchorPoint = not isStorybook and Vector2.new(0.5, 0.5) or nil,
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BorderColor3 = Color3.fromRGB(100, 100, 100),
		BorderSizePixel = 1,
	}, {
		Header = e("Frame", {
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundColor3 = Color3.fromRGB(25, 25, 25),
			BorderColor3 = Color3.fromRGB(100, 100, 100),
			BorderSizePixel = 1,
		}, {
			Title = e("TextLabel", {
				Text = "🚗 SELL YOUR CARS",
				Size = UDim2.new(1, -120, 1, 0),
				Position = UDim2.new(0, 10, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			SellAllButton = e("TextButton", {
				Text = "SELL ALL",
				Size = UDim2.new(0, 110, 0, 35),
				Position = UDim2.new(1, -115, 0.5, -17.5),
				BackgroundColor3 = Color3.fromRGB(50, 150, 50),
				BorderColor3 = Color3.fromRGB(100, 255, 100),
				BorderSizePixel = 2,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				[React.Event.Activated] = function()
					if props.onSellAll then
						props.onSellAll(cars)
					end
				end,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, 5),
				}),
			}),
		}),

		ListContainer = e("ScrollingFrame", {
			Name = "CarListScroll",
			Size = UDim2.new(1, 0, 1, -50),
			Position = UDim2.new(0, 0, 0, 50),
			BackgroundColor3 = Color3.fromRGB(35, 35, 35),
			BorderSizePixel = 0,
			ScrollBarThickness = 8,
			CanvasSize = UDim2.new(0, 0, 0, math.max(130, #cars * 130 + 20)),
		}, buildListChildren()),
	})

	if isStorybook then
		return MainFrame
	end

	local ScreenGuiElement = e("ScreenGui", {
		Name = "SellGui",
		ResetOnSpawn = false,
	}, {
		MainFrame = MainFrame,
	})

	return ScreenGuiElement
end

return SellGui

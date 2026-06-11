local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Networker = require(ReplicatedStorage.Packages.Networker)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local SellGui = require(script.Parent.components.SellGui.SellGui)

-- ===============================================
-- SELL GUI CLIENT INITIALIZATION
-- ===============================================

local serviceClient = {}
local root = nil
local toastRoot = nil
local SELL_RADIUS = 20

-- Tunggu Player Setup
task.wait(0.5)

-- ===== TOAST NOTIFICATION SYSTEM =====
local function showToast(message, isSuccess, duration)
	duration = duration or 3

	if not toastRoot then
		toastRoot = ReactRoblox.createRoot(playerGui)
	end

	local function ToastComponent()
		local show, setShow = React.useState(true)

		React.useEffect(function()
			local timer = task.delay(duration, function()
				setShow(false)
			end)

			return function()
				task.cancel(timer)
			end
		end, {})

		if not show then
			toastRoot:render(nil)
			return nil
		end

		return React.createElement("ScreenGui", {
			Name = "ToastGui",
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			Toast = React.createElement("Frame", {
				Size = UDim2.new(0, 300, 0, 60),
				Position = UDim2.new(0.5, -150, 0, 20),
				BackgroundColor3 = isSuccess and Color3.fromRGB(40, 140, 40) or Color3.fromRGB(140, 40, 40),
				BorderSizePixel = 0,
			}, {
				UICorner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 8),
				}),

				TextLabel = React.createElement("TextLabel", {
					Text = message,
					Size = UDim2.new(1, -20, 1, 0),
					Position = UDim2.new(0, 10, 0, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Font = Enum.Font.GothamBold,
					TextWrapped = true,
				}),
			}),
		})
	end

	toastRoot:render(React.createElement(ToastComponent))
end

local function detectSellArea()
	-- Deteksi sell area dari plot player
	local plotName = player:GetAttribute("MyPlotName")
	if not plotName or plotName == "" then
		return nil
	end

	local myPlot = workspace.Plots:FindFirstChild(plotName)
	if not myPlot then
		return nil
	end

	local sellAreaFolder = myPlot:FindFirstChild("SellArea")
	if not sellAreaFolder then
		return nil
	end

	local sellArea = sellAreaFolder:FindFirstChild("Area")
	return sellArea
end

-- ===== SETUP REACT ROOT =====
root = ReactRoblox.createRoot(playerGui)

-- ===== INITIALIZE NETWORKER CHANNEL =====
local networker = Networker.client.new("SellGui", serviceClient)

-- ===============================================
-- HANDLERS
-- ===============================================
local function handleSellCar(car)
	if not car then
		return
	end

	local carName = nil
	if type(car) == "userdata" and car:IsA("Tool") then
		carName = car:GetAttribute("Name") or car.Name
	else
		carName = car.Name or "Unknown"
	end

	print("[SellGui] Selling car: " .. tostring(carName))

	-- Call server via Networker
	local result = networker:invoke("sellCar", car)

	if result and result.Success then
		print("[SellGui] ✅ " .. result.Message)
		showToast("✅ " .. result.Message, true, 2.5)
	else
		local errorMsg = result and result.Error or "Unknown error"
		warn("[SellGui] ❌ " .. errorMsg)
		showToast("❌ " .. errorMsg, false, 3)
	end
end

local function handleSellAll(cars)
	if not cars or #cars == 0 then
		print("[SellGui] No cars to sell")
		showToast("❌ Tidak ada mobil untuk dijual", false, 2)
		return
	end

	print("[SellGui] Selling all " .. #cars .. " cars")

	-- Call server via Networker
	local result = networker:invoke("sellAllCars", cars)

	if result and result.Success then
		print("[SellGui] ✅ " .. result.Message)
		showToast("✅ " .. result.Message, true, 2.5)
	else
		local errorMsg = result and result.Error or "Unknown error"
		warn("[SellGui] ❌ " .. errorMsg)
		showToast("❌ " .. errorMsg, false, 3)
	end
end

-- ===============================================
-- PROXIMITY DETECTION LOOP
-- ===============================================
task.spawn(function()
	local lastNearState = false

	while true do
		task.wait(0.5)

		local char = player.Character
		local humanoidRoot = char and char:FindFirstChild("HumanoidRootPart")
		if not humanoidRoot then
			if lastNearState then
				lastNearState = false
				root:render(nil) -- Hide UI
			end
			continue
		end

		-- Detect sell area
		local sellArea = detectSellArea()
		if not sellArea then
			if lastNearState then
				lastNearState = false
				root:render(nil) -- Hide UI
			end
			continue
		end

		-- Calculate distance
		local distance = (humanoidRoot.Position - sellArea:GetPivot().Position).Magnitude
		local isNear = distance <= SELL_RADIUS

		-- Update UI visibility
		if isNear ~= lastNearState then
			lastNearState = isNear
			if isNear then
				print("[SellGui] Player masuk area sell, tampilkan UI")
				-- Render SellGui
				root:render(React.createElement(SellGui, {
					onSellCar = handleSellCar,
					onSellAll = handleSellAll,
				}))
			else
				print("[SellGui] Player keluar area sell, sembunyikan UI")
				-- Hide UI
				root:render(nil)
			end
		end
	end
end)

print("[SellGui Client] Initialized and ready! (Proximity detection active)")

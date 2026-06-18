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
local SELL_RADIUS = 8
local toasts = {}

-- Tunggu Player Setup
local handleSellCar, handleSellAll
task.wait(0.5)

-- ===== CREATE DEDICATED SCREENGUI (tidak timpa UI lain) =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SellGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 15
screenGui.Parent = playerGui
screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

-- ===== TOAST STATE MANAGEMENT =====
local function ToastComponent(props)
	local message = props.message
	local isSuccess = props.isSuccess
	local toastId = props.id
	local duration = props.duration or 3

	local show, setShow = React.useState(true)

	React.useEffect(function()
		local timer = task.delay(duration, function()
			setShow(false)
			task.delay(0.3, function()
				toasts[toastId] = nil
			end)
		end)

		return function()
			task.cancel(timer)
		end
	end, {})

	if not show then
		return nil
	end

	return React.createElement("Frame", {
		Size = UDim2.new(0, 300, 0, 60),
		Position = UDim2.new(0.5, -150, 0, 20),
		BackgroundColor3 = isSuccess and Color3.fromRGB(40, 140, 40) or Color3.fromRGB(140, 40, 40),
		BorderSizePixel = 0,
		ZIndex = 100,
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
			ZIndex = 101,
		}),
	})
end

local function buildToastList()
	local toastList = {
		UIListLayout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 10),
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local order = 1
	for id, toast in pairs(toasts) do
		toastList[id] = React.createElement(ToastComponent, {
			id = id,
			message = toast.message,
			isSuccess = toast.isSuccess,
			duration = toast.duration,
			layoutOrder = order,
		})
		order = order + 1
	end

	return toastList
end

local uiIsOpen = false

local function updateUIRender()
	if not root then
		return
	end

	if uiIsOpen then
		local currentComponent = React.createElement(SellGui, {
			onSellCar = handleSellCar,
			onSellAll = handleSellAll,
			onClose = function()
				print("[SellGui CLIENT] Player menutup UI secara manual")
				uiIsOpen = false
				updateUIRender()
			end,
		})

		root:render(React.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			SellGuiContent = currentComponent,
			ToastContainer = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Name = "ToastContainer",
			}, buildToastList()),
		}))
	else
		root:render(React.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, buildToastList()))
	end
end

local function showToast(message, isSuccess, duration)
	duration = duration or 3
	local toastId = tostring(os.clock()) .. tostring(math.random())

	toasts[toastId] = {
		message = message,
		isSuccess = isSuccess,
		duration = duration,
	}

	-- Rerender UI to show new toast
	updateUIRender()

	-- Schedule clean up of toast
	task.delay(duration, function()
		toasts[toastId] = nil
		updateUIRender()
	end)
end

local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))

local function detectSellArea()
	return GameUtils.getPlayerSellShopArea(player, "SellArea")
end

-- ===== SETUP REACT ROOT ON DEDICATED SCREENGUI =====
root = ReactRoblox.createRoot(screenGui)

-- ===== INITIALIZE NETWORKER CHANNEL =====
local networker = Networker.client.new("SellGui", serviceClient)

-- ===============================================
-- HANDLERS
-- ===============================================
function handleSellCar(car, stackChildName)
	if not car then
		return
	end

	local carName = nil
	if type(car) == "userdata" and car:IsA("Tool") then
		carName = car:GetAttribute("Name") or car.Name
	else
		carName = car.Name or "Unknown"
	end

	print(
		"[SellGui CLIENT] Selling car: "
			.. tostring(carName)
			.. (stackChildName and (" (" .. stackChildName .. ")") or "")
	)

	local result = networker:fetch("sellCar", car, stackChildName)

	if result and result.Success then
		print("[SellGui CLIENT] ✅ " .. result.Message)
		showToast("✅ " .. result.Message, true, 2.5)
	else
		local errorMsg = result and result.Error or "Unknown error"
		warn("[SellGui CLIENT] ❌ " .. errorMsg)
		showToast("❌ " .. errorMsg, false, 3)
	end
end

function handleSellAll(cars)
	if not cars or #cars == 0 then
		print("[SellGui CLIENT] No cars to sell")
		showToast("❌ Tidak ada mobil untuk dijual", false, 2)
		return
	end

	print("[SellGui CLIENT] Selling all " .. #cars .. " cars")

	local result = networker:fetch("sellAllCars", cars)

	if result and result.Success then
		print("[SellGui CLIENT] ✅ " .. result.Message)
		showToast("✅ " .. result.Message, true, 2.5)
	else
		local errorMsg = result and result.Error or "Unknown error"
		warn("[SellGui CLIENT] ❌ " .. errorMsg)
		showToast("❌ " .. errorMsg, false, 3)
	end
end

-- ===============================================
-- PROXIMITY DETECTION LOOP
-- ===============================================
task.spawn(function()
	local wasInsideArea = false

	local function openUI()
		if uiIsOpen then
			return
		end
		print("[SellGui CLIENT] Player masuk area sell, tampilkan UI")
		uiIsOpen = true
		updateUIRender()
	end

	while true do
		task.wait(0.5)

		local char = player.Character
		local humanoidRoot = char and char:FindFirstChild("HumanoidRootPart")
		if not humanoidRoot then
			wasInsideArea = false
			continue
		end

		local sellArea = detectSellArea()
		if not sellArea then
			wasInsideArea = false
			continue
		end

		local distance = (humanoidRoot.Position - sellArea:GetPivot().Position).Magnitude
		local isNear = distance <= SELL_RADIUS

		-- Terbuka HANYA saat transisi masuk area (dari luar ke dalam)
		if isNear and not wasInsideArea then
			openUI()
		end

		wasInsideArea = isNear
	end
end)

print("[SellGui Client] Initialized and ready! (Proximity detection active)")

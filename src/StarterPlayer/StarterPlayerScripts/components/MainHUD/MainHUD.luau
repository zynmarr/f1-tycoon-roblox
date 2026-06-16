local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect

local Topbar = require(script.Parent.Topbar)
local Sidebar = require(script.Parent.Sidebar)
local CustomStats = require(script.Parent.CustomStats)
local Hotbar = require(script.Parent.Hotbar)
local InventoryModal = require(script.Parent.InventoryModal)
local OpenBoxOverlay = require(script.Parent.OpenBoxOverlay)

local function MainHUD(props: { Buttons: any })
	local inventoryOpen, setInventoryOpen = useState(false)
	local viewportSize, setViewportSize = useState(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600))

	-- Pantau perubahan ukuran layar secara real-time untuk responsivitas
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

	local isMobile = viewportSize.X < 600

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		-- 1. Topbar (Shop, Home, Sell)
		Topbar = e(Topbar, {
			IsMobile = isMobile,
		}),

		-- 2. Sidebar / Bottom Menu
		Sidebar = e(Sidebar, {
			IsMobile = isMobile,
			Buttons = props.Buttons,
			InventoryOpen = inventoryOpen,
			SetInventoryOpen = setInventoryOpen,
		}),

		-- 3. Custom Stats & Active Buffs
		CustomStats = e(CustomStats, {
			IsMobile = isMobile,
		}),

		-- 4. Hotbar
		Hotbar = e(Hotbar, {
			IsMobile = isMobile,
			InventoryOpen = inventoryOpen,
		}),

		-- 5. Open Box Overlay
		OpenBoxOverlay = e(OpenBoxOverlay, {
			IsMobile = isMobile,
		}),

		-- 6. Inventory Pop-up Modal
		InventoryModal = inventoryOpen and e(InventoryModal, {
			OnClose = function()
				setInventoryOpen(false)
			end,
		}) or nil,
	})
end

return MainHUD

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
	local viewportSize, setViewportSize = useState(workspace.CurrentCamera.ViewportSize)

	-- Pantau perubahan ukuran layar secara real-time untuk responsivitas
	useEffect(function()
		local camera = workspace.CurrentCamera
		if not camera then return end

		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setViewportSize(camera.ViewportSize)
		end)

		return function()
			connection:Disconnect()
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

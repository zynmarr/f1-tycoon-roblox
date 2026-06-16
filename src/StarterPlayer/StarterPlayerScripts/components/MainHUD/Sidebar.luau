local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

local function Sidebar(props: {
	IsMobile: boolean,
	Buttons: { [string]: { Name: string, Label: string, Icon: string, Callback: () -> (), Order: number? } },
	InventoryOpen: boolean,
	SetInventoryOpen: (boolean) -> (),
})
	-- Menggabungkan tombol internal (Backpack) dengan tombol dinamis dari props
	local sortedButtons = {}

	-- Tombol Backpack selalu ditambahkan sebagai built-in
	table.insert(sortedButtons, {
		Name = "Backpack",
		Label = "Backpack",
		Icon = "🎒",
		Order = 1,
		Callback = function()
			props.SetInventoryOpen(not props.InventoryOpen)
		end,
	})

	-- Menambahkan tombol dinamis dari props
	if props.Buttons then
		for _, btn in pairs(props.Buttons) do
			table.insert(sortedButtons, btn)
		end
	end

	-- Urutkan berdasarkan Order
	table.sort(sortedButtons, function(a, b)
		local aOrder = a.Order or 99
		local bOrder = b.Order or 99
		return aOrder < bOrder
	end)

	-- Merender masing-masing tombol
	local buttonElements = {}
	for index, btn in ipairs(sortedButtons) do
		local isActive = (btn.Name == "Backpack" and props.InventoryOpen)
		local size = props.IsMobile and UDim2.fromOffset(45, 36) or UDim2.fromOffset(42, 42)

		buttonElements[btn.Name] = e("TextButton", {
			Size = size,
			BackgroundColor3 = isActive and Color3.fromRGB(100, 50, 250) or Color3.fromRGB(20, 20, 25),
			BackgroundTransparency = 0.35,
			Text = btn.Icon,
			Font = Enum.Font.GothamBold,
			TextSize = props.IsMobile and 16 or 18,
			LayoutOrder = index,
			AutoButtonColor = true,
			[React.Event.Activated] = btn.Callback,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Color = isActive and Color3.fromRGB(160, 100, 255) or Color3.fromRGB(70, 70, 85),
				Thickness = 1,
			}),
		})
	end

	-- Konfigurasi layout kontainer utama berdasarkan jenis device
	local containerSize, containerPos, anchorPoint
	local fillDirection

	if props.IsMobile then
		containerSize = UDim2.new(0, #sortedButtons * 55, 0, 45)
		containerPos = UDim2.new(0.5, 0, 1, -65) -- Berada di atas Hotbar mobile sedikit
		anchorPoint = Vector2.new(0.5, 1)
		fillDirection = Enum.FillDirection.Horizontal
	else
		containerSize = UDim2.new(0, 55, 0, #sortedButtons * 55)
		containerPos = UDim2.new(0, 10, 0.5, 0)
		anchorPoint = Vector2.new(0, 0.5)
		fillDirection = Enum.FillDirection.Vertical
	end

	local children = {
		Layout = e("UIListLayout", {
			FillDirection = fillDirection,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for name, element in pairs(buttonElements) do
		children[name] = element
	end

	return e("Frame", {
		Size = containerSize,
		Position = containerPos,
		AnchorPoint = anchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, children)
end

return Sidebar

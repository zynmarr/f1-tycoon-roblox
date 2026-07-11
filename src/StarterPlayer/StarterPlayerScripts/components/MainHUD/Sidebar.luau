local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

local function Sidebar(props: {
	IsMobile: boolean,
	Buttons: { [string]: { Name: string, Label: string, Icon: string, Callback: () -> (), Order: number? } },
	InventoryOpen: boolean,
	SetInventoryOpen: (boolean) -> (),
	IndexOpen: boolean,
	SetIndexOpen: (boolean) -> (),
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
			if not props.InventoryOpen then
				props.SetIndexOpen(false)
			end
		end,
	})

	-- Tombol CarIndex selalu ditambahkan sebagai built-in
	table.insert(sortedButtons, {
		Name = "CarIndex",
		Label = "Car Index",
		Icon = "🏆",
		Order = 1.5,
		Callback = function()
			props.SetIndexOpen(not props.IndexOpen)
			if not props.IndexOpen then
				props.SetInventoryOpen(false)
			end
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
		local isActive = (btn.Name == "Backpack" and props.InventoryOpen) or (btn.Name == "CarIndex" and props.IndexOpen)
		local size = props.IsMobile and UDim2.fromOffset(36, 36) or UDim2.fromOffset(42, 42)

		buttonElements[btn.Name] = e("TextButton", {
			Size = size,
			BackgroundColor3 = isActive and Color3.fromRGB(35, 25, 28) or Color3.fromRGB(20, 20, 24),
			BackgroundTransparency = 0.35,
			Text = btn.Icon,
			Font = Enum.Font.GothamBold,
			TextColor3 = isActive and Color3.fromRGB(255, 35, 85) or Color3.fromRGB(240, 240, 240),
			TextSize = props.IsMobile and 14 or 18,
			LayoutOrder = index,
			AutoButtonColor = true,
			[React.Event.Activated] = btn.Callback,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Color = isActive and Color3.fromRGB(255, 35, 85) or Color3.fromRGB(55, 55, 65),
				Thickness = isActive and 1.5 or 1,
			}, {
				Gradient = e("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(
							0,
							isActive and Color3.fromRGB(255, 0, 60) or Color3.fromRGB(0, 0, 255)
						),
						ColorSequenceKeypoint.new(
							1,
							isActive and Color3.fromRGB(255, 0, 60) or Color3.fromRGB(0, 0, 255)
						),
					}),
					Rotation = 45,
				}),
			}),
			BackgroundGradient = e("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, isActive and Color3.fromRGB(255, 0, 38) or Color3.fromRGB(0, 0, 255)),
					ColorSequenceKeypoint.new(1, isActive and Color3.fromRGB(255, 1, 52) or Color3.fromRGB(0, 0, 255)),
				}),
				Rotation = 45,
			}),
			ActiveIndicator = isActive and e("Frame", {
				Size = UDim2.new(0.4, 0, 0, 2),
				Position = UDim2.new(0.5, 0, 1, -3),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.fromRGB(255, 35, 85),
				BorderSizePixel = 0,
				ZIndex = 4,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 1) }),
			}) or nil,
		})
	end

	-- Konfigurasi layout kontainer utama berdasarkan jenis device
	local containerSize, containerPos, anchorPoint
	local fillDirection

	if props.IsMobile then
		containerSize = UDim2.new(0, 44, 0, #sortedButtons * 44)
		containerPos = UDim2.new(1, -10, 0.45, 0) -- Tengah Kanan, sedikit naik untuk menghindari tombol lompat
		anchorPoint = Vector2.new(1, 0.5)
		fillDirection = Enum.FillDirection.Vertical
	else
		containerSize = UDim2.new(0, 55, 0, #sortedButtons * 55)
		containerPos = UDim2.new(1, -15, 0.5, 0) -- Tengah Kanan!
		anchorPoint = Vector2.new(1, 0.5)
		fillDirection = Enum.FillDirection.Vertical
	end

	local children = {
		Layout = e("UIListLayout", {
			FillDirection = fillDirection,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = props.IsMobile and UDim.new(0, 8) or UDim.new(0, 10),
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

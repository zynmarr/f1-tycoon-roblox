local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local teleportEvent = ReplicatedStorage:WaitForChild("TeleportEvent", 10)

local function Topbar(props: { IsMobile: boolean })
	-- Fungsi teleport
	local function teleport(target: string)
		if teleportEvent then
			teleportEvent:FireServer(target)
		end
	end

	-- Fungsi toggle ShopGui
	local function toggleShop()
		local shopGui = playerGui:FindFirstChild("ShopGui") :: ScreenGui?
		if shopGui then
			shopGui.Enabled = not shopGui.Enabled
		else
			warn("[Topbar] ShopGui tidak ditemukan di PlayerGui!")
		end
	end

	-- Helper pembuat tombol premium
	local function createMenuButton(name: string, text: string, layoutOrder: number, onClick: () -> ())
		return e("TextButton", {
			Size = UDim2.new(0, props.IsMobile and 70 or 90, 0, 32),
			BackgroundColor3 = Color3.fromRGB(20, 20, 25),
			BackgroundTransparency = 0.35,
			Text = text,
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.fromRGB(240, 240, 240),
			TextSize = props.IsMobile and 10 or 12,
			LayoutOrder = layoutOrder,
			AutoButtonColor = true,
			[React.Event.Activated] = onClick,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(70, 70, 85),
				Thickness = 1,
			}),
		})
	end

	return e("Frame", {
		Size = UDim2.new(0, props.IsMobile and 240 or 300, 0, 40),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		ShopBtn = createMenuButton("Shop", "🛒 Shop", 1, toggleShop),
		HomeBtn = createMenuButton("Home", "🏠 Home", 2, function() teleport("Home") end),
		SellBtn = createMenuButton("Sell", "🏪 Sell", 3, function() teleport("SellArea") end),
	})
end

return Topbar

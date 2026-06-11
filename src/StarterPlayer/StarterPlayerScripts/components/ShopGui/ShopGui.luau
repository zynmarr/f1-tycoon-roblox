local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

local function ShopGui(props)
	-- Kita buat frame utama toko
	local MainContent = e("Frame", {
		-- Jika di UI Labs, biarkan memenuhi container (1,0,1,0)
		-- Jika ingin ukuran statis, gunakan properti Size & jangkar tengah
		Size = UDim2.new(0, 300, 0, 200),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5), -- Supaya benar-benar di tengah widget
		BackgroundColor3 = Color3.fromRGB(50, 50, 50),
		BorderSizePixel = 0,
	}, {
		WelcomeLabel = e("TextLabel", {
			Text = "Welcome to the Shop!",
			Size = UDim2.new(1, 0, 0, 50),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			BackgroundTransparency = 1,
		}),
		CashLabel = e("TextLabel", {
			Text = `Your Cash: ${props.CurrentCash or 0}`, -- Antisipasi jika props nil
			Size = UDim2.new(1, 0, 0, 50),
			Position = UDim2.new(0, 0, 0, 50),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			BackgroundTransparency = 1,
		}),
		BuyButton = e("TextButton", {
			Text = "Buy Item",
			Size = UDim2.new(1, -20, 0, 40),
			Position = UDim2.new(0, 10, 1, -50),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			BackgroundColor3 = Color3.fromRGB(70, 70, 70),
		}),
	})

	-- KUNCI UTAMA: Jika props ditandai sedang dibuka dari Storybook / UI Labs,
	-- langsung return Frame utama tanpa dibungkus ScreenGui.
	if props.IsStorybook then
		return MainContent
	end

	-- Jika dijalankan di game asli, bungkus dengan ScreenGui agar muncul di layar player
	return e("ScreenGui", {
		Name = "ShopGui",
		ResetOnSpawn = false,
	}, {
		MainContent = MainContent,
	})
end

return ShopGui

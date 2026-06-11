local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local ShopGui = require(script.Parent.ShopGui)

local story = {
	name = "Shop Window Preview",
	summary = "Melihat UI Toko tanpa ScreenGui di UI Labs",
	render = function(props)
		local targetContainer = props.target
		local root = ReactRoblox.createRoot(targetContainer)

		root:render(React.createElement(ShopGui, {
			CurrentCash = 75000, -- Mengisi data angka cash palsu untuk preview
			IsStorybook = true, -- Memberitahu komponen untuk mematikan ScreenGui
		}))

		return function()
			root:unmount()
		end
	end,
}

return story

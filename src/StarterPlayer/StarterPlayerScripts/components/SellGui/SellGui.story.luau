local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local SellGui = require(script.Parent.SellGui)

local story = {
	name = "Sell GUI - Car List",
	summary = "UI untuk menjual mobil dari backpack dengan list scrollable",
	render = function(props)
		local targetContainer = props.target
		local root = ReactRoblox.createRoot(targetContainer)

		-- Mock handlers
		local function handleSellCar(car)
			print("[SellGui] Selling car:", car.Name or "Unknown")
		end

		local function handleSellAll(cars)
			print("[SellGui] Selling all", #cars, "cars")
		end

		root:render(React.createElement(SellGui, {
			IsStorybook = true,
			onSellCar = handleSellCar,
			onSellAll = handleSellAll,
		}))

		return function()
			root:unmount()
		end
	end,
}

return story

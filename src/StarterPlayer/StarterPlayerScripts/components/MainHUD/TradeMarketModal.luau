local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage.Packages.React)
local Networker = require(ReplicatedStorage.Packages.Networker)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect

local marketService = Networker.client.new("MarketService", {})

local function TradeMarketModal(props: {
	IsMobile: boolean,
	OnClose: () -> (),
})
	local listings, setListings = useState({} :: { any })
	local selectedListing, setSelectedListing = useState(nil :: any)

	local function refreshListings()
		task.spawn(function()
			local ok, res = pcall(function()
				return marketService:fetch("fetchListings")
			end)
			if ok and res and res.Listings then
				setListings(res.Listings)
			end
		end)
	end

	useEffect(function()
		refreshListings()
	end, {})

	local function handleBuyout(listingId: string)
		task.spawn(function()
			local ok, res = pcall(function()
				return marketService:fetch("buyout", listingId)
			end)
			if ok and res then
				refreshListings()
			end
		end)
	end

	local rows = {}
	for idx, item in ipairs(listings) do
		rows["Row_" .. idx] = e("Frame", {
			Size = UDim2.new(1, 0, 0, 45),
			BackgroundColor3 = Color3.fromRGB(22, 22, 28),
			LayoutOrder = idx,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			NameLabel = e("TextLabel", {
				Text = item.CarFullName,
				Size = UDim2.new(0.4, 0, 1, 0),
				Position = UDim2.new(0.03, 0, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(240, 240, 240),
				TextSize = 10,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			PriceLabel = e("TextLabel", {
				Text = `Beli Instan: ${item.BuyoutPrice}`,
				Size = UDim2.new(0.35, 0, 1, 0),
				Position = UDim2.new(0.42, 0, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(0, 255, 204),
				TextSize = 10,
				Font = Enum.Font.GothamBold,
			}),
			BuyBtn = e("TextButton", {
				Text = "⚡ BELI",
				Size = UDim2.new(0.18, 0, 0.7, 0),
				Position = UDim2.new(0.96, 0, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Color3.fromRGB(0, 255, 204),
				TextColor3 = Color3.fromRGB(15, 15, 18),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				[React.Event.Activated] = function()
					handleBuyout(item.ListingId)
				end,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 5) }) }),
		})
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 0.55,
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		Active = true,
		ZIndex = 25,
	}, {
		BackdropClose = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 1,
			[React.Event.Activated] = props.OnClose,
		}),

		Modal = e("Frame", {
			Size = props.IsMobile and UDim2.new(0.85, 0, 0.85, 0) or UDim2.fromOffset(500, 360),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(15, 15, 18),
			Active = true,
			ZIndex = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Stroke = e("UIStroke", { Color = Color3.fromRGB(255, 130, 0), Thickness = 1.2 }),

			Header = e("Frame", {
				Size = UDim2.new(1, -30, 0, 30),
				Position = UDim2.new(0.5, 0, 0, 15),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
			}, {
				Title = e("TextLabel", {
					Text = "🏛️ PASAR BURSA F1",
					Size = UDim2.new(0.7, 0, 1, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				CloseBtn = e("TextButton", {
					Text = "X",
					Size = UDim2.fromOffset(24, 24),
					Position = UDim2.new(1, 0, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 35, 85),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					[React.Event.Activated] = props.OnClose,
				}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
			}),

			ListScroll = e("ScrollingFrame", {
				Size = UDim2.new(1, -30, 1, -65),
				Position = UDim2.new(0.5, 0, 0, 50),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				AutomaticCanvasSize = Enum.AutomaticSize.Y :: any,
				ScrollBarThickness = 4,
			}, (function()
				local children = {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 8),
					}),
				}
				for k, v in pairs(rows) do children[k] = v end
				if #listings == 0 then
					children["Empty"] = e("TextLabel", {
						Text = "Belum ada mobil yang dijual di bursa pasar.",
						Size = UDim2.new(1, 0, 0, 60),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(120, 120, 130),
						TextSize = 10,
						Font = Enum.Font.GothamBold,
					})
				end
				return children
			end)()),
		}),
	})
end

return TradeMarketModal

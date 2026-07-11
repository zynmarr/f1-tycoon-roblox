local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage.Packages.React)
local Networker = require(ReplicatedStorage.Packages.Packages.Networker)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local player = Players.LocalPlayer

local RARITY_COLORS = {
	["Common"] = Color3.fromRGB(150, 150, 150),
	["Uncommon"] = Color3.fromRGB(0, 220, 100),
	["Rare"] = Color3.fromRGB(0, 160, 255),
	["Epic"] = Color3.fromRGB(180, 50, 255),
	["Legendary"] = Color3.fromRGB(255, 130, 0),
	["Mythic"] = Color3.fromRGB(255, 30, 80),
	["God"] = Color3.fromRGB(0, 255, 230),
	["Celestial"] = Color3.fromRGB(255, 215, 0),
}

-- Initialize Networker client for FusionService
local clientService = {}
local fusionService = Networker.client.new("FusionService", clientService)

local function FusionModal(props: {
	IsMobile: boolean,
	OnClose: () -> (),
})
	local [ownedCars, setOwnedCars] = useState({} :: { Tool })
	local [fusingCar, setFusingCar] = useState(nil :: string?)
	local [fusionResult, setFusionResult] = useState(nil :: any)

	-- Scan player's backpack for eligible duplicate cars (Amount >= 3)
	local function scanBackpack()
		local backpack = player:FindFirstChild("Backpack")
		if not backpack then return end
		
		local list = {}
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") and item:GetAttribute("Type") == "Car" then
				local amount = item:GetAttribute("Amount") or 1
				local rarity = item:GetAttribute("Rarity") or "Common"
				if amount >= 3 and rarity ~= "Celestial" and rarity ~= "Admin" then
					table.insert(list, item)
				end
			end
		end
		setOwnedCars(list)
	end

	useEffect(function()
		scanBackpack()
		local backpack = player:WaitForChild("Backpack", 5)
		local conAdded, conRemoved
		if backpack then
			conAdded = backpack.ChildAdded:Connect(scanBackpack)
			conRemoved = backpack.ChildRemoved:Connect(scanBackpack)
		end
		return function()
			if conAdded then conAdded:Disconnect() end
			if conRemoved then conRemoved:Disconnect() end
		end
	end, {})

	-- Perform Fusion request
	local function triggerFusion(carFullName: string)
		setFusingCar(carFullName)
		setFusionResult(nil)
		
		task.spawn(function()
			task.wait(1.5) -- Build suspense
			local success, res = pcall(function()
				return fusionService:fuseCars(carFullName)
			end)
			
			setFusingCar(nil)
			if success and res then
				setFusionResult(res)
				scanBackpack()
			else
				setFusionResult({ Success = false, Error = "Kesalahan koneksi jaringan server." })
			end
		end)
	end

	-- Build UI rows for duplicate cars
	local itemRows = {}
	for idx, car in ipairs(ownedCars) do
		local fullName = car.Name
		local baseName = car:GetAttribute("Name") or car.Name
		local rarity = car:GetAttribute("Rarity") or "Common"
		local variant = car:GetAttribute("Variant") or "Normal"
		local amount = car:GetAttribute("Amount") or 1
		local col = RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)

		local baseChance = GameConfig.RarityFusionRates[rarity] or 0.50
		local percentChance = tostring(math.floor(baseChance * 100)) .. "%"

		itemRows["Row_" .. idx] = e("Frame", {
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = Color3.fromRGB(20, 20, 24),
			BackgroundTransparency = 0.4,
			LayoutOrder = idx,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(45, 45, 50),
				Thickness = 0.8,
			}),

			-- Title details
			CarName = e("TextLabel", {
				Text = `{baseName} [x{amount}]`,
				Size = UDim2.new(0.45, 0, 0.5, 0),
				Position = UDim2.new(0, 10, 0.1, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(240, 240, 240),
				TextSize = 10,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			RarityLabel = e("TextLabel", {
				Text = `{rarity} • {variant}`,
				Size = UDim2.new(0.45, 0, 0.4, 0),
				Position = UDim2.new(0, 10, 0.5, 0),
				BackgroundTransparency = 1,
				TextColor3 = col,
				TextSize = 8,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			-- Chance info
			ChanceLabel = e("TextLabel", {
				Text = `Peluang: {percentChance}`,
				Size = UDim2.new(0.25, 0, 1, 0),
				Position = UDim2.new(0.48, 0, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(0, 255, 204),
				TextSize = 9,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),

			-- Fuse Button
			FuseBtn = e("TextButton", {
				Text = "🧪 LEBUR",
				Size = UDim2.new(0.22, 0, 0.7, 0),
				Position = UDim2.new(0.96, 0, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 35, 85),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 9.5,
				[React.Event.Activated] = function()
					if not fusingCar then
						triggerFusion(fullName)
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 5) }),
			})
		})
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 0.55,
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		Active = true,
		ZIndex = 25,
	}, {
		-- Backdrop close
		BackdropClose = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 1,
			[React.Event.Activated] = function()
				if not fusingCar then
					props.OnClose()
				end
			end,
		}),

		-- Modal Container
		Modal = e("Frame", {
			Size = props.IsMobile and UDim2.new(0.85, 0, 0.85, 0) or UDim2.fromOffset(460, 320),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(15, 15, 18),
			BackgroundTransparency = 0.15,
			Active = true,
			ZIndex = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(55, 55, 65),
				Thickness = 1.2,
			}, {
				Gradient = e("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 35, 85)), -- Red highlight
						ColorSequenceKeypoint.new(0.4, Color3.fromRGB(55, 55, 65)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 35)),
					}),
					Rotation = -45,
				}),
			}),

			-- Racing stripe
			RacingStripe = e("Frame", {
				Size = UDim2.new(0.25, 0, 0, 2),
				Position = UDim2.new(0.5, 0, 0, 1),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.fromRGB(255, 35, 85),
				BorderSizePixel = 0,
				ZIndex = 6,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 1) }),
			}),

			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 15),
				PaddingBottom = UDim.new(0, 15),
				PaddingLeft = UDim.new(0, 15),
				PaddingRight = UDim.new(0, 15),
			}),

			-- Header
			Header = e("Frame", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
			}, {
				Title = e("TextLabel", {
					Text = "🧪 R&D FUSION LAB",
					Size = UDim2.new(0.6, 0, 1, 0),
					Position = UDim2.new(0, 0, 0, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 13,
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
					[React.Event.Activated] = function()
						if not fusingCar then
							props.OnClose()
						end
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),
			}),

			-- Description info
			DescFrame = e("Frame", {
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = Color3.fromRGB(24, 24, 28),
				LayoutOrder = 2,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Label = e("TextLabel", {
					Text = "Leburkan 3 mobil identik untuk upgrade ke tingkat kelangkahan di atasnya. Gagal menghancurkan 2 bahan.",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(150, 150, 160),
					TextSize = 8,
					Font = Enum.Font.GothamBold,
				}),
			}),

			-- Scroll list of eligible duplicates
			ListScroll = e("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, -85),
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y :: any,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Color3.fromRGB(255, 35, 85),
				LayoutOrder = 3,
			}, (function()
				local sItems = {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
				}
				for k, el in pairs(itemRows) do
					sItems[k] = el
				end
				-- Show empty fallback label if no duplicate found
				if #ownedCars == 0 then
					sItems["EmptyLabel"] = e("TextLabel", {
						Text = "Tidak ada mobil duplikat (minimal x3) di tas Anda.",
						Size = UDim2.new(1, 0, 0, 60),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(110, 110, 120),
						TextSize = 10,
						Font = Enum.Font.GothamBold,
					})
				end
				return sItems
			end)()),
		}),

		-- Fusing Pending Overlay Screen
		FusingOverlay = fusingCar and e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(10, 10, 12),
			BackgroundTransparency = 0.25,
			ZIndex = 50,
			Active = true,
		}, {
			Container = e("Frame", {
				Size = UDim2.fromOffset(250, 100),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
			}, {
				SpinIcon = e("TextLabel", {
					Text = "🔬",
					Size = UDim2.fromScale(1, 0.4),
					Position = UDim2.fromScale(0.5, 0.2),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					TextSize = 36,
				}),
				InfoLabel = e("TextLabel", {
					Text = "SEDANG MELEBURKAN MOBIL...",
					Size = UDim2.fromScale(1, 0.4),
					Position = UDim2.fromScale(0.5, 0.7),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(0, 255, 204),
					TextSize = 11,
					Font = Enum.Font.GothamBold,
				})
			})
		}) or nil,

		-- Success / Failure Result Popup
		ResultPopup = fusionResult and e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(10, 10, 12),
			BackgroundTransparency = 0.4,
			ZIndex = 60,
			Active = true,
		}, {
			Box = e("Frame", {
				Size = UDim2.fromOffset(300, 180),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(18, 18, 22),
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = e("UIStroke", {
					Color = fusionResult.Success and Color3.fromRGB(0, 255, 204) or Color3.fromRGB(255, 35, 85),
					Thickness = 1.2,
				}),

				Title = e("TextLabel", {
					Text = fusionResult.Success and (fusionResult.IsPerfect and "⭐ PERFECT FUSION! ⭐" or "🎉 FUSION BERHASIL!") or "💥 FUSION GAGAL!",
					Size = UDim2.new(1, 0, 0, 30),
					Position = UDim2.new(0, 0, 0, 15),
					BackgroundTransparency = 1,
					TextColor3 = fusionResult.Success and Color3.fromRGB(0, 255, 204) or Color3.fromRGB(255, 35, 85),
					TextSize = 14,
					Font = Enum.Font.GothamBold,
				}),

				BodyText = e("TextLabel", {
					Text = fusionResult.Success 
						and `Selamat! Anda berhasil mendapatkan:\n{fusionResult.NewCarName}\n({fusionResult.NewRarity} - {fusionResult.NewVariant})`
						or fusionResult.Error,
					Size = UDim2.new(1, -20, 0, 70),
					Position = UDim2.new(0.5, 0, 0, 50),
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(240, 240, 240),
					TextSize = 10,
					Font = Enum.Font.GothamBold,
					TextWrapped = true,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),

				OkBtn = e("TextButton", {
					Text = "OK",
					Size = UDim2.fromOffset(80, 28),
					Position = UDim2.new(0.5, 0, 1, -20),
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundColor3 = fusionResult.Success and Color3.fromRGB(0, 255, 204) or Color3.fromRGB(255, 35, 85),
					TextColor3 = Color3.fromRGB(15, 15, 18),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					[React.Event.Activated] = function()
						setFusionResult(nil)
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				})
			})
		}) or nil,
	})
end

return FusionModal

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local Event = (React :: any).Event
local Change = (React :: any).Change
local useState = React.useState
local useEffect = React.useEffect

type CarInventoryData = {
	FullName: string,
	Name: string,
	Rarity: string,
	Variant: string,
	Amount: number,
}

-- Helper to scan Backpack for owned cars
local function getOwnedCars(player: Player): { CarInventoryData }
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return {}
	end

	local cars = {}
	for _, child in ipairs(backpack:GetChildren()) do
		if child:GetAttribute("Type") == "Car" then
			local amount = child:GetAttribute("Amount") or 1
			local name = child:GetAttribute("Name") or child.Name
			local rarity = child:GetAttribute("Rarity") or "Common"
			local variant = child:GetAttribute("Variant") or "Admin"

			table.insert(cars, {
				FullName = child.Name,
				Name = name,
				Rarity = rarity,
				Variant = variant,
				Amount = amount :: number,
			})
		end
	end
	return cars
end

return function(props: any)
	local state = props.state
	local localPlayer = props.localPlayer

	if not state or not state.Active then
		return nil
	end

	local isP1 = localPlayer == state.Player1
	local myOffer = isP1 and state.Offer1 or state.Offer2
	local theirOffer = isP1 and state.Offer2 or state.Offer1

	local myLocked = isP1 and state.IsLocked1 or state.IsLocked2
	local theirLocked = isP1 and state.IsLocked2 or state.IsLocked1

	local myConfirmed = isP1 and state.IsConfirmed1 or state.IsConfirmed2
	local theirConfirmed = isP1 and state.IsConfirmed2 or state.IsConfirmed1

	local otherPlayer = isP1 and state.Player2 or state.Player1

	-- 1. STATE FOR INVENTORY & FILTER
	local carSearchText, setCarSearchText = useState("")
	local ownedCars, setOwnedCars = useState(getOwnedCars(localPlayer))

	-- Sync inventory with Backpack changes dynamically
	useEffect(function()
		local backpack = localPlayer:WaitForChild("Backpack", 10)
		if not backpack then
			return
		end

		local function updateInventory()
			setOwnedCars(getOwnedCars(localPlayer))
		end

		local conn1 = backpack.ChildAdded:Connect(updateInventory)
		local conn2 = backpack.ChildRemoved:Connect(updateInventory)

		return function()
			conn1:Disconnect()
			conn2:Disconnect()
		end
	end, {})

	-- Filtered cars for inventory list (Anti-Pattern plain search fixed)
	local filteredCars = {}
	local query = string.lower(carSearchText)
	for _, car in ipairs(ownedCars) do
		-- Also ensure the car is not fully in the offer
		local offeredCount = myOffer[car.FullName] or 0
		local availableCount = car.Amount - offeredCount
		if availableCount > 0 then
			if carSearchText == "" or string.find(string.lower(car.Name), query, 1, true) then
				table.insert(filteredCars, {
					FullName = car.FullName,
					Name = car.Name,
					Rarity = car.Rarity,
					Variant = car.Variant,
					Amount = availableCount,
				})
			end
		end
	end

	-- 2. DRAFT SLOTS RENDERING HELPER
	local function renderOfferGrid(offer: { [string]: number }, isMine: boolean)
		local childrenTable = {
			Layout = e("UIGridLayout", {
				CellSize = UDim2.new(0.3, 0, 0.45, 0),
				CellPadding = UDim2.new(0.03, 0, 0.05, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}

		local index = 0
		for carFullName, count in pairs(offer) do
			index = index + 1
			local parts = string.split(carFullName, "_")
			local carName = parts[1] or carFullName
			local rarity = parts[2] or "Common"
			local variant = parts[3] or "Admin"

			childrenTable[carFullName] = e("TextButton", {
				key = carFullName,
				Text = "",
				BackgroundColor3 = Color3.fromRGB(30, 30, 38),
				BorderSizePixel = 1,
				BorderColor3 = Color3.fromRGB(55, 55, 65),
				[Event.Activated] = function()
					if isMine and not myLocked and props.onRemoveCar then
						props.onRemoveCar(carFullName)
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Title = e("TextLabel", {
					Text = carName,
					Size = UDim2.new(1, -10, 0.4, 0),
					Position = UDim2.new(0, 5, 0, 5),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(240, 240, 245),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				VariantText = e("TextLabel", {
					Text = string.format("[%s]", variant),
					Size = UDim2.new(1, -10, 0.25, 0),
					Position = UDim2.new(0, 5, 0.45, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(0, 255, 204),
					Font = Enum.Font.GothamMedium,
					TextSize = 8,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				RarityTag = e("TextLabel", {
					Text = rarity,
					Size = UDim2.new(0.6, 0, 0.25, 0),
					Position = UDim2.new(0, 5, 0.7, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(200, 200, 200),
					Font = Enum.Font.GothamMedium,
					TextSize = 8,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				CountText = count > 1 and e("TextLabel", {
					Text = "x" .. tostring(count),
					Size = UDim2.new(0.3, 0, 0.25, 0),
					Position = UDim2.new(0.65, 0, 0.7, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 200, 0),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Right,
				}) or nil,
			})
		end

		return childrenTable
	end

	-- 3. INVENTORY SLOTS RENDERING
	local function renderInventory()
		local childrenTable = {
			Layout = e("UIGridLayout", {
				CellSize = UDim2.new(0, 100, 0, 60),
				CellPadding = UDim2.new(0, 8, 0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}

		for _, car in ipairs(filteredCars) do
			childrenTable[car.FullName] = e("TextButton", {
				key = car.FullName,
				Text = "",
				BackgroundColor3 = Color3.fromRGB(25, 25, 30),
				BorderSizePixel = 0,
				[Event.Activated] = function()
					if not myLocked and props.onAddCar then
						props.onAddCar(car.FullName)
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Stroke = e("UIStroke", { Color = Color3.fromRGB(45, 45, 55), Thickness = 1 }),
				Title = e("TextLabel", {
					Text = car.Name,
					Size = UDim2.new(1, -8, 0.4, 0),
					Position = UDim2.new(0, 4, 0, 2),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(220, 220, 220),
					Font = Enum.Font.GothamBold,
					TextSize = 9,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				VariantText = e("TextLabel", {
					Text = car.Variant,
					Size = UDim2.new(1, -8, 0.3, 0),
					Position = UDim2.new(0, 4, 0.4, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(0, 220, 255),
					Font = Enum.Font.GothamMedium,
					TextSize = 7,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				CountText = e("TextLabel", {
					Text = "Tersedia: " .. tostring(car.Amount),
					Size = UDim2.new(1, -8, 0.3, 0),
					Position = UDim2.new(0, 4, 0.68, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(150, 150, 160),
					Font = Enum.Font.GothamMedium,
					TextSize = 7,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			})
		end

		if #filteredCars == 0 then
			childrenTable.NoCars = e("TextLabel", {
				Text = "Tidak ada mobil tersedia",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(120, 120, 130),
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
			})
		end

		return childrenTable
	end

	-- 4. MAIN LAYOUT
	return e("Frame", {
		Size = UDim2.new(0.85, 0, 0.85, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(15, 15, 20),
		BorderSizePixel = 1,
		BorderColor3 = Color3.fromRGB(45, 45, 55),
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
		SizeConstraint = e("UISizeConstraint", { MaxSize = Vector2.new(820, 480) }),

		-- HEADER
		Header = e("Frame", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Color3.fromRGB(22, 22, 28),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Title = e("TextLabel", {
				Text = string.format("🤝 TRADING DENGAN %s", string.upper(otherPlayer.Name)),
				Size = UDim2.new(0.6, 0, 1, 0),
				Position = UDim2.new(0, 15, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			CancelBtn = e("TextButton", {
				Text = "✕ BATAL",
				Size = UDim2.new(0, 80, 0, 26),
				Position = UDim2.new(1, -95, 0.5, -13),
				BackgroundColor3 = Color3.fromRGB(55, 30, 30),
				TextColor3 = Color3.fromRGB(255, 100, 100),
				Font = Enum.Font.GothamBold,
				TextSize = 9,
				BorderSizePixel = 0,
				[Event.Activated] = function()
					if props.onCancel then
						props.onCancel()
					end
				end,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
		}),

		-- WORKSPACE (OFFERS AREA)
		TradeArea = e("Frame", {
			Size = UDim2.new(1, -30, 0.5, 0),
			Position = UDim2.new(0, 15, 0, 50),
			BackgroundTransparency = 1,
		}, {
			-- Player 1 Offer (Mine)
			MySide = e("Frame", {
				Size = UDim2.new(0.48, 0, 1, 0),
				BackgroundTransparency = 1,
			}, {
				Title = e("TextLabel", {
					Text = "PENAWARAN ANDA",
					Size = UDim2.new(1, 0, 0, 15),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(180, 180, 190),
					Font = Enum.Font.GothamBold,
					TextSize = 9,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				GridContainer = e("Frame", {
					Size = UDim2.new(1, 0, 0.75, 0),
					Position = UDim2.new(0, 0, 0, 20),
					BackgroundColor3 = Color3.fromRGB(20, 20, 25),
					BorderSizePixel = 0,
				}, renderOfferGrid(myOffer, true)),
				LockBtn = e("TextButton", {
					Text = myLocked and "🔓 BUKA PENAWARAN" or "🔒 KUNCI PENAWARAN",
					Size = UDim2.new(1, 0, 0.18, 0),
					Position = UDim2.new(0, 0, 0.82, 0),
					BackgroundColor3 = myLocked and Color3.fromRGB(200, 100, 0) or Color3.fromRGB(0, 120, 200),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 9,
					BorderSizePixel = 0,
					[Event.Activated] = function()
						if props.onLock and props.onUnlock then
							if myLocked then
								props.onUnlock()
							else
								props.onLock()
							end
						end
					end,
				}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
			}),

			-- Player 2 Offer (Theirs)
			TheirSide = e("Frame", {
				Size = UDim2.new(0.48, 0, 1, 0),
				Position = UDim2.new(0.52, 0, 0, 0),
				BackgroundTransparency = 1,
			}, {
				Title = e("TextLabel", {
					Text = string.format("PENAWARAN %s", string.upper(otherPlayer.Name)),
					Size = UDim2.new(1, 0, 0, 15),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(180, 180, 190),
					Font = Enum.Font.GothamBold,
					TextSize = 9,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				GridContainer = e("Frame", {
					Size = UDim2.new(1, 0, 0.75, 0),
					Position = UDim2.new(0, 0, 0, 20),
					BackgroundColor3 = Color3.fromRGB(20, 20, 25),
					BorderSizePixel = 0,
				}, renderOfferGrid(theirOffer, false)),
				StatusText = e("TextLabel", {
					Text = theirLocked and "🟢 SIAP (LOCKED)" or "⌛ MENDRAF (DRAFTING)",
					Size = UDim2.new(1, 0, 0.18, 0),
					Position = UDim2.new(0, 0, 0.82, 0),
					BackgroundColor3 = theirLocked and Color3.fromRGB(20, 45, 30) or Color3.fromRGB(35, 35, 45),
					TextColor3 = theirLocked and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(180, 180, 190),
					Font = Enum.Font.GothamBold,
					TextSize = 9,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
					Stroke = e(
						"UIStroke",
						{
							Color = theirLocked and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 70),
							Thickness = 1,
						}
					),
				}),
			}),
		}),

		-- INVENTORY DRAWER (BOTTOM)
		InventoryDrawer = e("Frame", {
			Size = UDim2.new(1, -30, 0.35, 0),
			Position = UDim2.new(0, 15, 0, 280),
			BackgroundTransparency = 1,
		}, {
			Header = e("Frame", {
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
			}, {
				Title = e("TextLabel", {
					Text = "📦 PILIH MOBIL DARI TAS ANDA",
					Size = UDim2.new(0.5, 0, 1, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(180, 180, 190),
					Font = Enum.Font.GothamBold,
					TextSize = 9,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				SearchBg = e("Frame", {
					Size = UDim2.new(0.4, 0, 1, 0),
					Position = UDim2.new(0.6, 0, 0, 0),
					BackgroundColor3 = Color3.fromRGB(25, 25, 32),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
					TextBox = e("TextBox", {
						Text = carSearchText,
						PlaceholderText = "Cari Mobil...",
						Size = UDim2.new(1, -10, 1, 0),
						Position = UDim2.new(0, 5, 0, 0),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(240, 240, 240),
						PlaceholderColor3 = Color3.fromRGB(100, 100, 110),
						Font = Enum.Font.GothamMedium,
						TextSize = 8,
						ClearTextOnFocus = false,
						[Change.Text] = function(box: TextBox)
							setCarSearchText(box.Text)
						end,
					}),
				}),
			}),

			-- List
			ScrollList = e("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, -25),
				Position = UDim2.new(0, 0, 0, 25),
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = Color3.fromRGB(60, 60, 75),
			}, renderInventory()),
		}),

		-- CONFIRM OVERLAY/BUTTON DRAWER
		ConfirmOverlay = (myLocked and theirLocked)
				and e("Frame", {
					Size = UDim2.new(1, 0, 0.16, 0),
					Position = UDim2.new(0, 0, 0.84, 0),
					BackgroundColor3 = Color3.fromRGB(20, 20, 25),
					BorderSizePixel = 0,
					ZIndex = 15,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
					ConfirmBtn = e("TextButton", {
						Text = state.CountdownActive and (state.CountdownSeconds > 0 and string.format(
							"SIAP DALAM (%ds)",
							state.CountdownSeconds
						) or (myConfirmed and "MENUNGGU LAWAN..." or "SETUJUI PERTUKARAN (CONFIRM)")) or "MENUNGGU...",
						Size = UDim2.new(0.6, 0, 0.6, 0),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, 0, 0.5, 0),
						BackgroundColor3 = (state.CountdownActive and state.CountdownSeconds == 0)
								and (myConfirmed and Color3.fromRGB(20, 45, 30) or Color3.fromRGB(0, 180, 100))
							or Color3.fromRGB(35, 35, 45),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						Font = Enum.Font.GothamBold,
						TextSize = 11,
						BorderSizePixel = 0,
						[Event.Activated] = function()
							if
								state.CountdownActive
								and state.CountdownSeconds == 0
								and not myConfirmed
								and props.onConfirm
							then
								props.onConfirm()
							end
						end,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
						Stroke = e("UIStroke", {
							Color = (state.CountdownActive and state.CountdownSeconds == 0 and not myConfirmed)
									and Color3.fromRGB(0, 220, 120)
								or Color3.fromRGB(60, 60, 70),
							Thickness = 1,
						}),
					}),
				})
			or nil,
	})
end

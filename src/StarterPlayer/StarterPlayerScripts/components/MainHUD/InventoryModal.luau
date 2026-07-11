local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage.Packages.React)
local ViewportManager = require(script.Parent.Parent.ViewportManager)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

local player = Players.LocalPlayer

local function InventoryModal(props: {
	IsMobile: boolean,
	OnClose: () -> (),
	SlotMapping: { [number]: Tool },
	HeldTool: Tool?,
	IsHovered: boolean,
	SetIsHovered: (boolean) -> (),
	OnSlotInputBegan: (tool: Tool, input: InputObject) -> (),
})
	local cache = useRef(nil)
	if not cache.current then
		cache.current = ViewportManager.new()
	end

	-- State pencarian
	local searchText, setSearchText = useState("")
	local selectedTab, setSelectedTab = useState("All") -- "All", "Car", "Box"

	-- State tools
	local heldTool, setHeldTool = useState(nil :: any)
	local toolsList, setToolsList = useState({} :: { any })

	-- Refresh daftar tool di tas dan karakter
	local function refreshTools()
		local backpack = player:FindFirstChild("Backpack")
		if not backpack then return end
		local char = player.Character
		local currentHeld = char and char:FindFirstChildOfClass("Tool")
		setHeldTool(currentHeld)

		local list = {}
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") then
				table.insert(list, item)
			end
		end
		if currentHeld then
			table.insert(list, currentHeld)
		end
		setToolsList(list)
	end

	useEffect(function()
		local connections = {}

		local function cleanup()
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
			table.clear(connections)
		end

		local function setupListeners()
			cleanup()

			local backpack = player:FindFirstChild("Backpack")
			if backpack then
				table.insert(connections, backpack.ChildAdded:Connect(refreshTools))
				table.insert(connections, backpack.ChildRemoved:Connect(refreshTools))
			end

			local char = player.Character
			if char then
				table.insert(connections, char.ChildAdded:Connect(refreshTools))
				table.insert(connections, char.ChildRemoved:Connect(refreshTools))
			end

			refreshTools()
		end

		-- Jalankan kembali setup ketika karakter baru ditambahkan (respawn)
		local charAddedConn = player.CharacterAdded:Connect(function()
			task.wait(0.1) -- Jeda kecil agar Backpack baru selesai terbuat oleh engine
			setupListeners()
		end)

		setupListeners()

		return function()
			charAddedConn:Disconnect()
			cleanup()
			if cache.current then
				ViewportManager.clearAllCache(cache.current)
			end
		end
	end, {})

	-- Filter tool berdasarkan pencarian dan sembunyikan yang sudah terpasang di Hotbar
	local filteredTools = {}
	for _, tool in ipairs(toolsList) do
		local isMappedToHotbar = false
		for _, hotbarTool in pairs(props.SlotMapping) do
			if hotbarTool == tool then
				isMappedToHotbar = true
				break
			end
		end

		if not isMappedToHotbar then
			local name = tool:GetAttribute("Name") or tool.Name
			local itemType = tool:GetAttribute("Type") or "Other"

			local matchesTab = (selectedTab == "All")
				or (selectedTab == "Car" and itemType == "Car")
				or (selectedTab == "Box" and itemType == "Box")

			if matchesTab and string.find(name:lower(), searchText:lower(), 1, true) then
				table.insert(filteredTools, tool)
			end
		end
	end

	-- Render slots
	local slotElements = {}
	for i, tool in ipairs(filteredTools) do
		local isEquipped = (tool == heldTool)
		local toolName = tool:GetAttribute("Name") or tool.Name
		local amount = tool:GetAttribute("Amount") or 1

		-- Desain slot yang serasi dengan HotbarSlot
		slotElements[tool.Name .. "_" .. i] = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = isEquipped and Color3.fromRGB(35, 25, 28) or Color3.fromRGB(20, 20, 24),
			BackgroundTransparency = isEquipped and 0.15 or 0.4,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = i,
			[React.Event.InputBegan] = function(_, input)
				props.OnSlotInputBegan(tool, input)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Color = isEquipped and Color3.fromRGB(255, 35, 85) or Color3.fromRGB(55, 55, 65),
				Thickness = isEquipped and 1.5 or 1,
			}, {
				Gradient = e("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(
							0,
							isEquipped and Color3.fromRGB(255, 35, 85) or Color3.fromRGB(70, 70, 80)
						),
						ColorSequenceKeypoint.new(
							1,
							isEquipped and Color3.fromRGB(180, 20, 50) or Color3.fromRGB(40, 40, 45)
						),
					}),
					Rotation = 45,
				}),
			}),

			-- Carbon fiber background gradient
			BackgroundGradient = e("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(
						0,
						isEquipped and Color3.fromRGB(50, 15, 20) or Color3.fromRGB(24, 24, 28)
					),
					ColorSequenceKeypoint.new(1, isEquipped and Color3.fromRGB(20, 5, 8) or Color3.fromRGB(12, 12, 14)),
				}),
				Rotation = 45,
			}),

			-- Render 3D Model
			CarView = e("ViewportFrame", {
				Size = UDim2.fromScale(0.85, 0.85),
				Position = UDim2.fromScale(0.5, 0.45),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ref = function(rbx: any)
					if rbx then
						ViewportManager.setupViewport(cache.current, rbx, tool, { bgTransparency = 1 })
					end
				end,
			}),

			-- Nama Item (Lebih bersih di bagian bawah)
			ItemName = e("TextLabel", {
				Text = toolName,
				Size = UDim2.new(1, -8, 0, 12),
				Position = UDim2.new(0.5, 0, 1, -14),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(240, 240, 240),
				TextSize = 7,
				Font = Enum.Font.GothamBold,
				TextWrapped = true,
			}),

			-- Jumlah Item (Badge Pojok Kanan Atas)
			ItemAmount = (amount > 1) and e("Frame", {
				Size = UDim2.fromOffset(24, 12),
				Position = UDim2.new(1, -4, 0, 4),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Color3.fromRGB(15, 15, 18),
				ZIndex = 5,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(0, 255, 204),
					Thickness = 0.8,
				}),
				Text = e("TextLabel", {
					Text = "x" .. tostring(amount),
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(0, 255, 204),
					TextSize = 7,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
			}) or nil,

			-- Aksen Neon Merah untuk item aktif
			ActiveIndicator = isEquipped and e("Frame", {
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

	return e("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 0.55,
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		Active = true,
		ZIndex = 20,
		[React.Event.MouseEnter] = function()
			props.SetIsHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			props.SetIsHovered(false)
		end,
	}, {
		-- Deteksi klik luar untuk menutup modal
		BackdropBtn = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "X",
			ZIndex = 1,
			[React.Event.Activated] = props.OnClose,
		}),

		-- Kontainer Modal (Responsive Size & Position)
		ModalContainer = e("Frame", {
			Size = props.IsMobile and UDim2.new(0.82, 0, 0.82, 0) or UDim2.fromOffset(450, 320),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(15, 15, 18),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
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
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 35, 85)), -- Red highlight on border
						ColorSequenceKeypoint.new(0.3, Color3.fromRGB(55, 55, 65)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 35)),
					}),
					Rotation = -45,
				}),
			}),

			-- Aksen LED Shift stripe di tengah atas modal
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

			-- Layout & Padding
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 12),
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
					Text = "🏁 GARASI INVENTORY",
					Size = UDim2.new(0.5, 0, 1, 0),
					Position = UDim2.new(0, 0, 0, 0),
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
					BackgroundTransparency = 0.1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					AutoButtonColor = true,
					[React.Event.Activated] = props.OnClose,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
					Stroke = e("UIStroke", {
						Color = Color3.fromRGB(255, 100, 120),
						Thickness = 0.8,
					}),
				}),
			}),

			-- Search Bar
			SearchBarFrame = e("Frame", {
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundColor3 = Color3.fromRGB(25, 25, 30),
				BackgroundTransparency = 0.3,
				LayoutOrder = 2,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(55, 55, 65),
					Thickness = 1,
				}),

				TextBox = e("TextBox", {
					Size = UDim2.new(1, -20, 1, 0),
					Position = UDim2.new(0, 10, 0, 0),
					BackgroundTransparency = 1,
					Text = searchText,
					PlaceholderText = "Cari mobil atau perkakas...",
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextColor3 = Color3.fromRGB(240, 240, 240),
					PlaceholderColor3 = Color3.fromRGB(110, 110, 120),
					TextXAlignment = Enum.TextXAlignment.Left,
					ClearTextOnFocus = false,
					[React.Change.Text] = function(rbx: any)
						setSearchText(rbx.Text)
					end,
				}),
			}),

			-- Kategori Tabs
			TabsFrame = e("Frame", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				LayoutOrder = 3,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
				}),

				TabAll = e("TextButton", {
					Text = "🌐 Semua",
					Size = UDim2.new(0.31, 0, 1, 0),
					BackgroundColor3 = selectedTab == "All" and Color3.fromRGB(255, 35, 85) or Color3.fromRGB(25, 25, 30),
					BackgroundTransparency = selectedTab == "All" and 0.1 or 0.4,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					LayoutOrder = 1,
					[React.Event.Activated] = function()
						setSelectedTab("All")
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
					Stroke = e("UIStroke", {
						Color = selectedTab == "All" and Color3.fromRGB(255, 100, 120) or Color3.fromRGB(55, 55, 65),
						Thickness = 0.8,
					}),
				}),

				TabCars = e("TextButton", {
					Text = "🏎️ Mobil",
					Size = UDim2.new(0.31, 0, 1, 0),
					BackgroundColor3 = selectedTab == "Car" and Color3.fromRGB(255, 35, 85) or Color3.fromRGB(25, 25, 30),
					BackgroundTransparency = selectedTab == "Car" and 0.1 or 0.4,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					LayoutOrder = 2,
					[React.Event.Activated] = function()
						setSelectedTab("Car")
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
					Stroke = e("UIStroke", {
						Color = selectedTab == "Car" and Color3.fromRGB(255, 100, 120) or Color3.fromRGB(55, 55, 65),
						Thickness = 0.8,
					}),
				}),

				TabBoxes = e("TextButton", {
					Text = "📦 Kotak",
					Size = UDim2.new(0.31, 0, 1, 0),
					BackgroundColor3 = selectedTab == "Box" and Color3.fromRGB(255, 35, 85) or Color3.fromRGB(25, 25, 30),
					BackgroundTransparency = selectedTab == "Box" and 0.1 or 0.4,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					LayoutOrder = 3,
					[React.Event.Activated] = function()
						setSelectedTab("Box")
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
					Stroke = e("UIStroke", {
						Color = selectedTab == "Box" and Color3.fromRGB(255, 100, 120) or Color3.fromRGB(55, 55, 65),
						Thickness = 0.8,
					}),
				}),
			}),

			-- Grid Scroll Frame
			GridScroll = e(
				"ScrollingFrame",
				{
					Size = UDim2.new(1, 0, 1, -125),
					BackgroundTransparency = 1,
					CanvasSize = UDim2.new(0, 0, 0, 0),
					AutomaticCanvasSize = Enum.AutomaticSize.Y :: any, -- Casted to any to prevent Luau type errors
					ScrollBarThickness = 4,
					ScrollBarImageColor3 = Color3.fromRGB(255, 35, 85), -- Red scrollbar
					LayoutOrder = 4,
				},
				(function()
						local scrollChildren = {
							GridLayout = e("UIGridLayout", {
								CellSize = props.IsMobile and UDim2.fromOffset(60, 60) or UDim2.fromOffset(70, 70),
								CellPadding = props.IsMobile and UDim2.fromOffset(6, 6) or UDim2.fromOffset(10, 10),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
						}
						for name, element in pairs(slotElements) do
							scrollChildren[name] = element
						end
						return scrollChildren
					end)() :: any
			),
		}),
	})
end

return InventoryModal

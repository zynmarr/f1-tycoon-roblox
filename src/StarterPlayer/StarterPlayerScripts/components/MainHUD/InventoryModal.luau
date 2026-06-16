--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage.Packages.React)
local ViewportManager = require(script.Parent.Parent.ViewportManager)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

local player = Players.LocalPlayer

local function InventoryModal(props: { OnClose: () -> () })
	local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		warn("[InventoryModal] Backpack tidak ditemukan!")
		return nil
	end

	local cache = useRef(nil)
	if not cache.current then
		cache.current = ViewportManager.new()
	end

	-- State pencarian
	local searchText, setSearchText = useState("")

	-- State tools
	local heldTool, setHeldTool = useState(nil :: any)
	local toolsList, setToolsList = useState({} :: {any})

	-- Refresh daftar tool di tas dan karakter
	local function refreshTools()
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

		-- Pantau perubahan tas dan karakter
		table.insert(connections, backpack.ChildAdded:Connect(refreshTools))
		table.insert(connections, backpack.ChildRemoved:Connect(refreshTools))

		local function setupChar(char)
			table.insert(connections, char.ChildAdded:Connect(refreshTools))
			table.insert(connections, char.ChildRemoved:Connect(refreshTools))
			refreshTools()
		end

		table.insert(connections, player.CharacterAdded:Connect(setupChar))
		if player.Character then
			setupChar(player.Character)
		end

		refreshTools()

		return function()
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
			if cache.current then
				ViewportManager.clearAllCache(cache.current)
			end
		end
	end, {})

	-- Filter tool berdasarkan pencarian
	local filteredTools = {}
	for _, tool in ipairs(toolsList) do
		local name = tool:GetAttribute("Name") or tool.Name
		if string.find(name:lower(), searchText:lower(), 1, true) then
			table.insert(filteredTools, tool)
		end
	end

	-- Handler klik item untuk equip/unequip
	local function handleItemClick(tool: any)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			if tool.Parent == char then
				hum:UnequipTools()
			else
				hum:EquipTool(tool)
			end
		end
	end

	-- Render slots
	local slotElements = {}
	for i, tool in ipairs(filteredTools) do
		local isEquipped = (tool == heldTool)
		local toolName = tool:GetAttribute("Name") or tool.Name
		local amount = tool:GetAttribute("Amount") or 1

		slotElements[tool.Name .. "_" .. i] = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = isEquipped and Color3.fromRGB(80, 40, 180) or Color3.fromRGB(25, 25, 30),
			BackgroundTransparency = 0.35,
			Text = "",
			AutoButtonColor = true,
			LayoutOrder = i,
			[React.Event.Activated] = function()
				handleItemClick(tool)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Color = isEquipped and Color3.fromRGB(150, 80, 255) or Color3.fromRGB(70, 70, 85),
				Thickness = 1,
			}),

			-- Render 3D Model
			CarView = e("ViewportFrame", {
				Size = UDim2.fromScale(0.9, 0.9),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ref = function(rbx: any)
					if rbx then
						ViewportManager.setupViewport(cache.current, rbx, tool, { bgTransparency = 1 })
					end
				end,
			}),

			-- Nama Item
			ItemName = e("TextLabel", {
				Text = toolName,
				Size = UDim2.new(1, -6, 0, 10),
				Position = UDim2.new(0.5, 0, 1, -12),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 6,
				Font = Enum.Font.GothamMedium,
				TextWrapped = true,
			}),

			-- Jumlah Item
			ItemAmount = e("TextLabel", {
				Text = "x" .. tostring(amount),
				Size = UDim2.fromOffset(25, 12),
				Position = UDim2.new(1, -27, 0, 4),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(0, 255, 204),
				TextSize = 8,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.5,
		BackgroundColor3 = Color3.fromRGB(10, 10, 15),
		Active = true,
		ZIndex = 20,
	}, {
		-- Deteksi klik luar untuk menutup modal
		BackdropBtn = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			[React.Event.Activated] = props.OnClose,
		}),

		-- Kontainer Modal
		ModalContainer = e("Frame", {
			Size = UDim2.fromOffset(450, 350),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(20, 20, 25),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(100, 50, 250),
				Thickness = 1.5,
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
					Text = "🎒 BACKPACK",
					Size = UDim2.new(0.5, 0, 1, 0),
					Position = UDim2.new(0, 0, 0, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 16,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				CloseBtn = e("TextButton", {
					Text = "✕",
					Size = UDim2.fromOffset(24, 24),
					Position = UDim2.new(1, 0, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(40, 40, 45),
					BackgroundTransparency = 0.5,
					TextColor3 = Color3.fromRGB(255, 100, 100),
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					AutoButtonColor = true,
					[React.Event.Activated] = props.OnClose,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),
			}),

			-- Search Bar
			SearchBarFrame = e("Frame", {
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundColor3 = Color3.fromRGB(30, 30, 35),
				BackgroundTransparency = 0.5,
				LayoutOrder = 2,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(60, 60, 70),
					Thickness = 1,
				}),

				TextBox = e("TextBox", {
					Size = UDim2.new(1, -20, 1, 0),
					Position = UDim2.new(0, 10, 0, 0),
					BackgroundTransparency = 1,
					Text = searchText,
					PlaceholderText = "Cari item...",
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextColor3 = Color3.fromRGB(240, 240, 240),
					PlaceholderColor3 = Color3.fromRGB(120, 120, 130),
					TextXAlignment = Enum.TextXAlignment.Left,
					ClearTextOnFocus = false,
					[React.Change.Text] = function(rbx: any)
						setSearchText(rbx.Text)
					end,
				}),
			}),

			-- Grid Scroll Frame
			GridScroll = e("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, -80),
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Color3.fromRGB(100, 50, 250),
				LayoutOrder = 3,
			}, {
				GridLayout = e("UIGridLayout", {
					CellSize = UDim2.fromOffset(70, 70),
					CellPadding = UDim2.fromOffset(10, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				React.Children.toArray(slotElements :: any) :: any
			} :: any),
		}),
	})
end

return InventoryModal

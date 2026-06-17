local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage.Packages.React)
local ViewportManager = require(script.Parent.Parent.ViewportManager)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

local player = Players.LocalPlayer

-- Component untuk masing-masing slot Hotbar agar performa & hover state terisolasi
local function HotbarSlot(props: {
	SlotIndex: number,
	Tool: Tool?,
	IsEquipped: boolean,
	IsMobile: boolean,
	SlotSize: number,
	Cache: any,
	OnInputBegan: (input: InputObject) -> (),
	OnHoverEnter: () -> (),
	OnHoverLeave: () -> (),
})
	local isHovered, setIsHovered = useState(false)
	local buttonRef = useRef(nil :: any)

	-- Animasi pembesaran ukuran slot saat di-hover (micro-animation)
	useEffect(function()
		local rbx = buttonRef.current
		if not rbx then
			return
		end

		local slotSize = props.SlotSize
		local hoverSize = slotSize + (props.IsMobile and 4 or 6)
		local targetSize = isHovered and hoverSize or slotSize

		local tweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(rbx, tweenInfo, {
			Size = UDim2.fromOffset(targetSize, targetSize),
		})
		tween:Play()

		return function()
			tween:Cancel()
		end
	end, { isHovered, props.SlotSize, props.IsMobile } :: { any })

	local tool = props.Tool
	local isEquipped = props.IsEquipped
	local slotSize = props.SlotSize

	-- Warna dan visual state
	local backgroundColor = isEquipped and Color3.fromRGB(35, 25, 28)
		or (isHovered and Color3.fromRGB(40, 40, 48) or Color3.fromRGB(20, 20, 24))
	local backgroundTransparency = isEquipped and 0.15 or (isHovered and 0.25 or 0.4)

	local strokeColor = isEquipped and Color3.fromRGB(255, 35, 85) -- F1 Red Accent
		or (isHovered and Color3.fromRGB(180, 180, 200) or Color3.fromRGB(55, 55, 65))
	local strokeThickness = isEquipped and 2 or (isHovered and 1.2 or 1)

	local amount = tool and (tool:GetAttribute("Amount") or 1) or 1

	return e("TextButton", {
		Size = UDim2.fromOffset(slotSize, slotSize),
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = backgroundTransparency,
		LayoutOrder = props.SlotIndex,
		Text = "",
		AutoButtonColor = false,
		ClipsDescendants = false, -- Biar badge bisa sedikit keluar dari batas untuk estetika 3D
		ref = buttonRef,
		[React.Event.MouseEnter] = function()
			setIsHovered(true)
			props.OnHoverEnter()
		end,
		[React.Event.MouseLeave] = function()
			setIsHovered(false)
			props.OnHoverLeave()
		end,
		[React.Event.InputBegan] = function(_, input)
			props.OnInputBegan(input)
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Stroke = e("UIStroke", {
			Color = strokeColor,
			Thickness = strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, {
			Gradient = e("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(
						0,
						isEquipped and Color3.fromRGB(255, 35, 85)
							or (isHovered and Color3.fromRGB(220, 220, 230) or Color3.fromRGB(70, 70, 80))
					),
					ColorSequenceKeypoint.new(
						1,
						isEquipped and Color3.fromRGB(180, 20, 50)
							or (isHovered and Color3.fromRGB(120, 120, 130) or Color3.fromRGB(40, 40, 45))
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
					isEquipped and Color3.fromRGB(50, 15, 20)
						or (isHovered and Color3.fromRGB(45, 45, 52) or Color3.fromRGB(24, 24, 28))
				),
				ColorSequenceKeypoint.new(
					1,
					isEquipped and Color3.fromRGB(20, 5, 8)
						or (isHovered and Color3.fromRGB(25, 25, 30) or Color3.fromRGB(12, 12, 14))
				),
			}),
			Rotation = 45,
		}),

		-- Badge Angka Slot (Sporty Badge di pojok kiri atas)
		SlotBadge = e("Frame", {
			Size = UDim2.fromOffset(13, 13),
			Position = UDim2.fromOffset(4, 4),
			BackgroundColor3 = isEquipped and Color3.fromRGB(255, 35, 85) or Color3.fromRGB(25, 25, 30),
			BackgroundTransparency = isEquipped and 0 or 0.2,
			ZIndex = 5,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Stroke = e("UIStroke", {
				Color = isEquipped and Color3.fromRGB(255, 120, 150) or Color3.fromRGB(55, 55, 65),
				Thickness = 0.8,
			}),
			Number = e("TextLabel", {
				Text = tostring(props.SlotIndex),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 7.5,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		}),

		-- Render 3D Model Viewport (Tengahkan karena name overlay sudah dihapus)
		CarView = tool and e("ViewportFrame", {
			Size = UDim2.fromScale(0.85, 0.85),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 2,
			ref = function(rbx: any)
				if rbx then
					ViewportManager.setupViewport(props.Cache, rbx, tool, { bgTransparency = 1 })
				end
			end,
		}) or nil,

		-- Badge Jumlah Item (Lebih racy dan terbaca)
		ItemAmount = (tool and amount > 1) and e("Frame", {
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

		-- Aksen Neon Merah di bagian bawah slot saat item dilengkapi (Active Strip)
		ActiveIndicator = isEquipped and e("Frame", {
			Size = UDim2.new(0.5, 0, 0, 2.5),
			Position = UDim2.new(0.5, 0, 1, -3),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(255, 35, 85),
			BorderSizePixel = 0,
			ZIndex = 4,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 1) }),
		}) or nil,

		-- Aksen empty slot (grid crosshair tipis)
		EmptyAccent = not tool and e("Frame", {
			Size = UDim2.fromScale(0.2, 0.2),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 1,
		}, {
			Dot = e("Frame", {
				Size = UDim2.fromOffset(2, 2),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(80, 80, 90),
				BackgroundTransparency = 0.65,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		}) or nil,
	})
end

local function Hotbar(props: {
	ViewportSize: Vector2,
	InventoryOpen: boolean,
	SlotMapping: { [number]: Tool },
	HeldTool: Tool?,
	HoveredSlotIndex: number?,
	SetHoveredSlotIndex: (any) -> (),
	OnSlotInputBegan: (slotIndex: number, tool: Tool?, input: InputObject) -> (),
})
	local viewportSize = props.ViewportSize or Vector2.new(1024, 768)
	local width = viewportSize.X

	local isMobile = width < 600
	local isTablet = width >= 600 and width < 1024

	local maxSlots = 10
	if isMobile then
		maxSlots = 5
	elseif isTablet then
		maxSlots = 7
	end

	local cache = useRef(nil :: any)
	if not cache.current then
		cache.current = ViewportManager.new()
	end

	-- ===== 2. SHORTCUT KEYBOARD (1-9) UNTUK EQUIP TOOL =====
	useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			local num = nil
			if input.KeyCode == Enum.KeyCode.One then
				num = 1
			elseif input.KeyCode == Enum.KeyCode.Two then
				num = 2
			elseif input.KeyCode == Enum.KeyCode.Three then
				num = 3
			elseif input.KeyCode == Enum.KeyCode.Four then
				num = 4
			elseif input.KeyCode == Enum.KeyCode.Five then
				num = 5
			elseif input.KeyCode == Enum.KeyCode.Six and maxSlots >= 6 then
				num = 6
			elseif input.KeyCode == Enum.KeyCode.Seven and maxSlots >= 7 then
				num = 7
			elseif input.KeyCode == Enum.KeyCode.Eight and maxSlots >= 8 then
				num = 8
			elseif input.KeyCode == Enum.KeyCode.Nine and maxSlots >= 9 then
				num = 9
			elseif input.KeyCode == Enum.KeyCode.Zero and maxSlots >= 10 then
				num = 10
			end

			if num then
				local tool = props.SlotMapping[num]
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum and tool then
					if tool.Parent == char then
						hum:UnequipTools()
					else
						hum:EquipTool(tool)
					end
				end
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, { props.SlotMapping, maxSlots } :: { any })

	-- Matikan default backpack core UI
	useEffect(function()
		task.spawn(function()
			local success
			repeat
				success = pcall(function()
					game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
				end)
				task.wait(0.5)
			until success
		end)
	end, {})

	-- Dimensi layout barisan slot
	local slotSize = isMobile and 42 or (isTablet and 46 or 52)
	local gapSize = isMobile and 6 or (isTablet and 7 or 8)
	local paddingSize = isMobile and 6 or (isTablet and 7 or 8)

	-- Render daftar slot hotbar
	local slotElements = {}
	for i = 1, maxSlots do
		local tool = props.SlotMapping[i]
		local isSlotEquipped = (tool ~= nil and tool == props.HeldTool)
		local slotName = "Slot" .. i

		slotElements[slotName] = e(HotbarSlot, {
			SlotIndex = i,
			Tool = tool,
			IsEquipped = isSlotEquipped,
			IsMobile = isMobile,
			SlotSize = slotSize,
			Cache = cache.current,
			OnInputBegan = function(input)
				props.OnSlotInputBegan(i, tool, input)
			end,
			OnHoverEnter = function()
				props.SetHoveredSlotIndex(i)
			end,
			OnHoverLeave = function()
				props.SetHoveredSlotIndex(function(current)
					if current == i then
						return nil
					end
					return current
				end)
			end,
		})
	end

	local containerWidth = maxSlots * slotSize + (maxSlots - 1) * gapSize + paddingSize * 2
	local containerHeight = slotSize + paddingSize * 2
	local clampedWidth = math.min(containerWidth, width - 20)
	local isScrolling = containerWidth > clampedWidth

	-- Deteksi tool yang aktif untuk ditampilkan di NamePlate atas hotbar
	local displayTool = nil
	local hoveredSlotIndex = props.HoveredSlotIndex
	if hoveredSlotIndex and props.SlotMapping[hoveredSlotIndex] then
		displayTool = props.SlotMapping[hoveredSlotIndex]
	elseif props.HeldTool then
		displayTool = props.HeldTool
	end

	-- Rendernya NamePlate melayang di atas Hotbar jika ada tool aktif/hovered
	local namePlate = nil
	if displayTool then
		local toolName = displayTool:GetAttribute("Name") or displayTool.Name or ""
		local rarity = displayTool:GetAttribute("Rarity") or "Common"
		local level = displayTool:GetAttribute("Level")

		-- Warna rarity ala racing premium
		local rarityColor = Color3.fromRGB(240, 240, 240)
		if rarity == "Legendary" then
			rarityColor = Color3.fromRGB(255, 215, 0) -- Gold
		elseif rarity == "Epic" then
			rarityColor = Color3.fromRGB(190, 24, 219) -- Purple
		elseif rarity == "Rare" then
			rarityColor = Color3.fromRGB(24, 119, 242) -- Neon Blue
		elseif rarity == "Common" then
			rarityColor = Color3.fromRGB(160, 160, 170)
		end

		local labelText = string.upper(toolName)
		local subText = level and ("LV. " .. tostring(level)) or string.upper(rarity)

		namePlate = e("Frame", {
			Size = UDim2.fromOffset(240, 32),
			Position = UDim2.new(0.5, 0, 0, -52),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(12, 12, 16),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(45, 45, 55),
				Thickness = 1,
			}, {
				Gradient = e("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 35, 85)), -- Red accent highlight
						ColorSequenceKeypoint.new(0.2, Color3.fromRGB(45, 45, 55)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 25, 30)),
					}),
					Rotation = 0,
				}),
			}),

			-- Aksen garis merah tipis di tepi kiri
			LeftAccent = e("Frame", {
				Size = UDim2.new(0, 4, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundColor3 = Color3.fromRGB(255, 35, 85),
				BorderSizePixel = 0,
				ZIndex = 7,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),

			-- Wadah teks terformat horizontal
			TextContainer = e("Frame", {
				Size = UDim2.new(1, -16, 1, 0),
				Position = UDim2.new(0, 12, 0, 0),
				BackgroundTransparency = 1,
				ZIndex = 7,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				SubBadge = e("Frame", {
					Size = UDim2.fromOffset(48, 16),
					BackgroundColor3 = Color3.fromRGB(25, 25, 30),
					LayoutOrder = 1,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
					Stroke = e("UIStroke", {
						Color = rarityColor,
						Thickness = 0.8,
					}),
					Text = e("TextLabel", {
						Text = subText,
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = rarityColor,
						TextSize = 7.5,
						Font = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				}),

				Title = e("TextLabel", {
					Text = labelText,
					Size = UDim2.new(1, -58, 1, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 10,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					LayoutOrder = 2,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
			}),
		})
	end

	-- Layout grid slot
	local innerChildren = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, gapSize),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, paddingSize),
			PaddingRight = UDim.new(0, paddingSize),
			PaddingTop = UDim.new(0, paddingSize),
			PaddingBottom = UDim.new(0, paddingSize),
		}),
	}
	for name, element in pairs(slotElements) do
		innerChildren[name] = element
	end

	local mainChildren = {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(55, 55, 65),
			Thickness = 1.2,
		}, {
			Gradient = e("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 75, 85)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 35, 40)),
				}),
				Rotation = 45,
			}),
		}),

		-- Carbon fiber background gradient
		BackgroundGradient = e("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 24)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12)),
			}),
			Rotation = 90,
		}),

		-- Aksen LED Shift Indicator ala setir F1 di bagian tengah atas
		RacingStripe = e("Frame", {
			Size = UDim2.new(0.35, 0, 0, 2),
			Position = UDim2.new(0.5, 0, 0, 1),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(255, 35, 85),
			BorderSizePixel = 0,
			ZIndex = 6,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 1) }),
		}),

		-- Container internal untuk slot grid (ScrollingFrame jika overflow di mobile/layar sempit)
		SlotsFrame = e(isScrolling and "ScrollingFrame" or "Frame", isScrolling and {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 5,
			CanvasSize = UDim2.new(0, containerWidth - paddingSize * 2, 0, 0),
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 0,
			ClipsDescendants = true,
			ElasticBehavior = Enum.ElasticBehavior.Always,
		} or {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, innerChildren),
	}

	if namePlate then
		mainChildren.NamePlate = namePlate
	end

	return e("Frame", {
		Size = UDim2.fromOffset(clampedWidth, containerHeight),
		Position = UDim2.new(0.5, 0, 1, -15), -- Sedikit mengambang dari bawah demi tampilan modern
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(15, 15, 20),
		BackgroundTransparency = 0.25, -- Transparansi glassmorphism yang pas
		BorderSizePixel = 0,
		ZIndex = 25, -- ZIndex dinaikkan ke 25 agar Hotbar berada di atas modal backdrop (ZIndex 20)
	}, mainChildren)
end

return Hotbar

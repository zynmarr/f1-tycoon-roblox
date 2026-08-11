local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React") :: ModuleScript)
local e = React.createElement
local Event = (React :: any).Event
local Change = (React :: any).Change
local useState = React.useState
local useEffect = React.useEffect

type CarData = {
	Name: string,
	Rarity: string,
}

return function(props: any)
	-- 1. TABS MANAGEMENT
	local activeTab, setActiveTab = useState("Multipliers") -- "Multipliers" | "Broadcast" | "Gifts"
	local viewportSize, setViewportSize =
		useState(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600))

	-- Pantau perubahan ukuran layar secara real-time
	useEffect(function()
		local connection: RBXScriptConnection? = nil

		local function setupCamera(cam: Camera?)
			if connection then
				connection:Disconnect()
				connection = nil
			end
			if cam then
				connection = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
					setViewportSize(cam.ViewportSize)
				end)
				setViewportSize(cam.ViewportSize)
			end
		end

		setupCamera(workspace.CurrentCamera)

		local camConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			setupCamera(workspace.CurrentCamera)
		end)

		return function()
			if connection then
				connection:Disconnect()
			end
			camConnection:Disconnect()
		end
	end, {})

	local isMobile = viewportSize.X < 650 or viewportSize.Y < 500

	-- 2. STATE FOR EVENT MULTIPLIERS (TAB 1)
	local luckInput, setLuckInput = useState(0)
	local expInput, setExpInput = useState(0)
	local speedInput, setSpeedInput = useState(0)
	local variantInput, setVariantInput = useState(0)
	local goldenInput, setGoldenInput = useState(0)
	local rainbowInput, setRainbowInput = useState(0)
	local galaxyInput, setGalaxyInput = useState(0)
	local hellfireInput, setHellfireInput = useState(0)

	local isAccordionOpen, setIsAccordionOpen = useState(false)
	local isGlobalEvent, setIsGlobalEvent = useState(false)

	-- LIVE VALUES STATE (TAB 1 STATUS MONITOR)
	local liveLuck, setLiveLuck = useState(0)
	local liveExp, setLiveExp = useState(0)
	local liveSpeed, setLiveSpeed = useState(0)
	local liveVariant, setLiveVariant = useState(0)
	local liveGolden, setLiveGolden = useState(0)
	local liveRainbow, setLiveRainbow = useState(0)
	local liveGalaxy, setLiveGalaxy = useState(0)
	local liveHellfire, setLiveHellfire = useState(0)

	-- 3. STATE FOR BROADCAST (TAB 2)
	local broadcastText, setBroadcastText = useState("")
	local isGlobalBroadcast, setIsGlobalBroadcast = useState(true)

	-- 4. STATE FOR GIFTS (TAB 3)
	local targetType, setTargetType = useState("All") -- "All" | "Specific"
	local targetPlayerName, setTargetPlayerName = useState("")
	local isGlobalGift, setIsGlobalGift = useState(true)

	-- Gift Cash
	local giftCashAmount, setGiftCashAmount = useState(10000)

	-- Gift Box
	local giftBoxLevel, setGiftBoxLevel = useState(12)
	local boxExtraVariants, setBoxExtraVariants = useState({} :: { string })

	-- Gift Car Search & Autocomplete
	local carSearchText, setCarSearchText = useState("")
	local availableCars, setAvailableCars = useState({} :: { CarData })
	local isCarDropdownOpen, setIsCarDropdownOpen = useState(false)
	local carExtraVariants, setCarExtraVariants = useState({} :: { string })

	local adminCars, setAdminCars = useState({} :: { { Name: string } })
	local selectedAdminCar, setSelectedAdminCar = useState("")
	local isAdminCarDropdownOpen, setIsAdminCarDropdownOpen = useState(false)

	-- 5. STATE FOR CUSTOM NAME COLOR (TAB 4)
	local colorTargetPlayer, setColorTargetPlayer = useState("Self") -- "Self" | "Specific"
	local colorTargetName, setColorTargetName = useState("")
	local selectedHexColor, setSelectedHexColor = useState("#FFD700") -- Default Gold
	local customHexInput, setCustomHexInput = useState("#FFD700")

	-- 5. INITIALIZE SLIDERS FROM SERVER ON MOUNT
	useEffect(function()
		local liveEvents = ReplicatedStorage:WaitForChild("LiveEvents")
		if not liveEvents then
			return
		end

		local luckNode = liveEvents:FindFirstChild("LuckyChanceBoost") :: IntValue?
		local expNode = liveEvents:FindFirstChild("ExpBoost") :: IntValue?
		local variantNode = liveEvents:FindFirstChild("VariantBoost") :: IntValue?
		local speedVal = (ReplicatedStorage:GetAttribute("SpeedBoost") :: number?) or 0

		local goldenNode = liveEvents:FindFirstChild("VariantBoost_Golden") :: IntValue?
		local rainbowNode = liveEvents:FindFirstChild("VariantBoost_Rainbow") :: IntValue?
		local galaxyNode = liveEvents:FindFirstChild("VariantBoost_Galaxy") :: IntValue?
		local hellfireNode = liveEvents:FindFirstChild("VariantBoost_Hellfire") :: IntValue?

		if luckNode then
			setLuckInput(luckNode.Value)
		end
		if expNode then
			setExpInput(expNode.Value)
		end
		if variantNode then
			setVariantInput(variantNode.Value)
		end
		setSpeedInput(speedVal)

		if goldenNode then
			setGoldenInput(goldenNode.Value)
		end
		if rainbowNode then
			setRainbowInput(rainbowNode.Value)
		end
		if galaxyNode then
			setGalaxyInput(galaxyNode.Value)
		end
		if hellfireNode then
			setHellfireInput(hellfireNode.Value)
		end
	end, {})

	-- 6. LISTEN TO SERVER CHANGES (REAL-TIME SYNC)
	useEffect(function()
		local liveEvents = ReplicatedStorage:WaitForChild("LiveEvents")
		if not liveEvents then
			return
		end

		local function syncValues()
			local luckNode = liveEvents:FindFirstChild("LuckyChanceBoost") :: IntValue?
			local expNode = liveEvents:FindFirstChild("ExpBoost") :: IntValue?
			local variantNode = liveEvents:FindFirstChild("VariantBoost") :: IntValue?
			local speedVal = (ReplicatedStorage:GetAttribute("SpeedBoost") :: number?) or 0

			local goldenNode = liveEvents:FindFirstChild("VariantBoost_Golden") :: IntValue?
			local rainbowNode = liveEvents:FindFirstChild("VariantBoost_Rainbow") :: IntValue?
			local galaxyNode = liveEvents:FindFirstChild("VariantBoost_Galaxy") :: IntValue?
			local hellfireNode = liveEvents:FindFirstChild("VariantBoost_Hellfire") :: IntValue?

			setLiveLuck(if luckNode then luckNode.Value else 0)
			setLiveExp(if expNode then expNode.Value else 0)
			setLiveVariant(if variantNode then variantNode.Value else 0)
			setLiveSpeed(speedVal)

			setLiveGolden(if goldenNode then goldenNode.Value else 0)
			setLiveRainbow(if rainbowNode then rainbowNode.Value else 0)
			setLiveGalaxy(if galaxyNode then galaxyNode.Value else 0)
			setLiveHellfire(if hellfireNode then hellfireNode.Value else 0)
		end

		syncValues()

		local connections: { RBXScriptConnection } = {}
		local nodes = {
			"LuckyChanceBoost",
			"ExpBoost",
			"VariantBoost",
			"VariantBoost_Golden",
			"VariantBoost_Rainbow",
			"VariantBoost_Galaxy",
			"VariantBoost_Hellfire",
		}

		for _, name in ipairs(nodes) do
			local node = liveEvents:FindFirstChild(name)
			if node then
				table.insert(connections, node.Changed:Connect(syncValues))
			end
		end

		table.insert(
			connections,
			liveEvents.ChildAdded:Connect(function(child: Instance)
				if table.find(nodes, child.Name) then
					syncValues()
					table.insert(connections, (child :: any).Changed:Connect(syncValues))
				end
			end)
		)

		table.insert(connections, ReplicatedStorage:GetAttributeChangedSignal("SpeedBoost"):Connect(syncValues))

		return function()
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
		end
	end, {})

	-- 6. LOAD AVAILABLE CARS & ADMIN CARS ON MOUNT
	useEffect(function()
		if props.getAvailableCars then
			task.spawn(function()
				local cars = props.getAvailableCars() :: { CarData }?
				if cars then
					setAvailableCars(cars)
				end
			end)
		end
		if props.getAdminCars then
			task.spawn(function()
				local cars = props.getAdminCars()
				if cars then
					setAdminCars(cars)
				end
			end)
		end
	end, {})

	-- 7. EVENT ACTIONS
	local function handleApply()
		if props.onApplySettings then
			props.onApplySettings({
				Luck = luckInput,
				Exp = expInput,
				Speed = speedInput,
				Variant = variantInput,
				Golden = goldenInput,
				Rainbow = rainbowInput,
				Galaxy = galaxyInput,
				Hellfire = hellfireInput,
			}, isGlobalEvent)
		end
	end

	local function handleStopAll()
		if props.onStopAll then
			props.onStopAll(isGlobalEvent)
			setLuckInput(0)
			setExpInput(0)
			setSpeedInput(0)
			setVariantInput(0)
			setGoldenInput(0)
			setRainbowInput(0)
			setGalaxyInput(0)
			setHellfireInput(0)
		end
	end

	local function applyPreset(presetType: string)
		if presetType == "DoubleEXP" then
			setLuckInput(0)
			setExpInput(100)
			setSpeedInput(0)
			setVariantInput(0)
			setGoldenInput(0)
			setRainbowInput(0)
			setGalaxyInput(0)
			setHellfireInput(0)
		elseif presetType == "LuckyHype" then
			setLuckInput(200)
			setExpInput(0)
			setSpeedInput(0)
			setVariantInput(10)
			setGoldenInput(5)
			setRainbowInput(0)
			setGalaxyInput(0)
			setHellfireInput(0)
		elseif presetType == "WeekendBoost" then
			setLuckInput(150)
			setExpInput(150)
			setSpeedInput(10)
			setVariantInput(20)
			setGoldenInput(0)
			setRainbowInput(0)
			setGalaxyInput(0)
			setHellfireInput(0)
		end
	end

	-- 8. SLIDER GENERATOR HELPER
	local function createSliderRow(label: string, min: number, max: number, value: number, setValue: any)
		local labelSize = isMobile and UDim2.new(0.42, 0, 1, 0) or UDim2.new(0.35, 0, 1, 0)
		local inputBoxPos = isMobile and UDim2.new(1, -40, 0.5, -13) or UDim2.new(0.37, 0, 0.5, -13)
		local inputBoxSize = isMobile and UDim2.new(0, 40, 0, 26) or UDim2.new(0, 50, 0, 26)
		local sliderBgPos = isMobile and UDim2.new(0.44, 0, 0.5, -4) or UDim2.new(0.37, 60, 0.5, -4)
		local sliderBgSize = isMobile and UDim2.new(0.56, -46, 0, 8) or UDim2.new(0.63, -115, 0, 8)

		return e("Frame", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
		}, {
			Label = e("TextLabel", {
				Text = label,
				Size = labelSize,
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(230, 230, 235),
				TextSize = isMobile and 9.5 or 11,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = true,
			}),

			InputBox = e("TextBox", {
				Text = tostring(value),
				Size = inputBoxSize,
				Position = inputBoxPos,
				BackgroundColor3 = Color3.fromRGB(25, 25, 35),
				TextColor3 = Color3.fromRGB(0, 255, 204),
				Font = Enum.Font.GothamBold,
				TextSize = isMobile and 9.5 or 11,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				[Event.FocusLost] = function(box: TextBox)
					local val = tonumber(box.Text) or 0
					local clamped = math.clamp(val, min, max)
					setValue(clamped)
					box.Text = tostring(clamped)
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			}),

			SliderBg = e("TextButton", {
				Text = "",
				Size = sliderBgSize,
				Position = sliderBgPos,
				BackgroundColor3 = Color3.fromRGB(20, 20, 25),
				BorderSizePixel = 0,
				[Event.Activated] = function(btn: any, input: any)
					if not input then
						return
					end
					local btnAbsPos = btn.AbsolutePosition.X
					local btnAbsSize = btn.AbsoluteSize.X
					local mouseX = input.Position.X
					local pct = math.clamp((mouseX - btnAbsPos) / btnAbsSize, 0, 1)
					local calcVal = math.floor(min + (pct * (max - min)))
					setValue(calcVal)
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				Fill = e("Frame", {
					Size = UDim2.new(math.clamp((value - min) / (max - min), 0, 1), 0, 1, 0),
					BackgroundColor3 = Color3.fromRGB(0, 150, 255),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				}),
			}),
		})
	end

	-- 9. TAB SELECTOR RENDERER
	local function createTabBtn(tabId: string, label: string, icon: string)
		local isActive = activeTab == tabId
		return e("TextButton", {
			Text = icon .. " " .. label,
			Size = UDim2.new(0.3, 0, 1, 0),
			BackgroundColor3 = isActive and Color3.fromRGB(30, 40, 55) or Color3.fromRGB(22, 22, 28),
			TextColor3 = isActive and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(180, 180, 190),
			Font = Enum.Font.GothamBold,
			TextSize = isMobile and 9.5 or 11,
			BorderSizePixel = 0,
			[Event.Activated] = function()
				setActiveTab(tabId)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", {
				Color = isActive and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(45, 45, 55),
				Thickness = 1,
			}),
		})
	end

	-- FILTERED CARS FOR SEARCH AUTOCOMPLETE
	local filteredCars: { CarData } = {}
	if carSearchText ~= "" then
		local query = string.lower(carSearchText)
		for _, c in ipairs(availableCars :: { CarData }) do
			if string.find(string.lower(c.Name), query, 1, true) then
				table.insert(filteredCars, c)
			end
		end
	else
		filteredCars = availableCars :: { CarData }
	end

	local function createVariantPicker(selectedVariants: { string }, setSelectedVariants: (any) -> ())
		local variants = {
			{ Name = "Rainbow", Emoji = "🌈" },
			{ Name = "Frostbite", Emoji = "❄️" },
			{ Name = "Galaxy", Emoji = "🌌" },
			{ Name = "Hellfire", Emoji = "🔥" },
			{ Name = "Cosmic", Emoji = "🌀" },
			{ Name = "Golden", Emoji = "🔱" },
		}

		local buttons = {}
		for i, variant in ipairs(variants) do
			local isSelected = table.find(selectedVariants, variant.Name) ~= nil
			buttons["Var_" .. variant.Name] = e("TextButton", {
				key = "Var_" .. variant.Name,
				Text = variant.Emoji .. " " .. variant.Name,
				Font = Enum.Font.GothamBold,
				TextSize = 8,
				TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150),
				BackgroundColor3 = isSelected and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(40, 40, 45),
				Size = UDim2.new(0, 80, 0, 22),
				AutoButtonColor = true,
				LayoutOrder = i,
				[Event.Activated] = function()
					local newVariants = table.clone(selectedVariants)
					if isSelected then
						local index = table.find(newVariants, variant.Name)
						if index then
							table.remove(newVariants, index)
						end
					else
						table.insert(newVariants, variant.Name)
					end
					setSelectedVariants(newVariants)
				end,
			}, {
				UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			})
		end

		local buttonsChildren = {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 5),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
		}
		for key, button in pairs(buttons) do
			buttonsChildren[key] = button
		end

		return e("Frame", {
			Size = UDim2.new(1, 0, 0, 45),
			BackgroundTransparency = 1,
			LayoutOrder = 10,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 3),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			ButtonsFrame = e("Frame", {
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
			}, buttonsChildren),
			Label = e("TextLabel", {
				Size = UDim2.new(1, 0, 0, 12),
				BackgroundTransparency = 1,
				Text = "🔒 Admin variant otomatis ditambahkan",
				TextColor3 = Color3.fromRGB(150, 150, 150),
				TextSize = 8,
				Font = Enum.Font.Gotham,
				LayoutOrder = 2,
			}),
		})
	end

	-- TAB 1 LAYOUT: MULTIPLIERS
	local function renderMultipliersTab()
		if isMobile then
			return e("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Color3.fromRGB(80, 80, 95),
				BorderSizePixel = 0,
			}, {
				List = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 10),
				}),
				Padding = e("UIPadding", { PaddingRight = UDim.new(0, 8) }),

				Luck = createSliderRow("🍀 Luck Boost (0-500%)", 0, 500, luckInput, setLuckInput),
				Exp = createSliderRow("🆙 Exp Boost (0-500%)", 0, 500, expInput, setExpInput),
				Speed = createSliderRow("⚡ Speed Boost (0-100%)", 0, 100, speedInput, setSpeedInput),
				Variant = createSliderRow("🌟 Global Variant (0-100%)", 0, 100, variantInput, setVariantInput),

				AccordionBtn = e("TextButton", {
					Text = (isAccordionOpen and "▼ Sembunyikan Varian Khusus" or "▶ Tampilkan Varian Khusus"),
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundColor3 = Color3.fromRGB(25, 25, 32),
					TextColor3 = Color3.fromRGB(200, 200, 210),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					BorderSizePixel = 0,
					[Event.Activated] = function()
						setIsAccordionOpen(not isAccordionOpen)
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),

				AccordionFrame = isAccordionOpen and e("Frame", {
					Size = UDim2.new(1, 0, 0, 160),
					BackgroundTransparency = 1,
				}, {
					List = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 8),
					}),
					Golden = createSliderRow("🔱 Golden Boost (0-50%)", 0, 50, goldenInput, setGoldenInput),
					Rainbow = createSliderRow("🌈 Rainbow Boost (0-50%)", 0, 50, rainbowInput, setRainbowInput),
					Galaxy = createSliderRow("🌌 Galaxy Boost (0-50%)", 0, 50, galaxyInput, setGalaxyInput),
					Hellfire = createSliderRow("🔥 Hellfire Boost (0-50%)", 0, 50, hellfireInput, setHellfireInput),
				}) or nil,

				-- Live Monitor
				LiveMonitor = e("Frame", {
					Size = UDim2.new(1, 0, 0, 80),
					BackgroundColor3 = Color3.fromRGB(20, 20, 25),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Padding = e(
						"UIPadding",
						{ PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }
					),
					List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 2) }),

					Title = e("TextLabel", {
						Text = "🔴 LIVE MONITOR STATUS",
						Size = UDim2.new(1, 0, 0, 14),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(255, 60, 60),
						Font = Enum.Font.GothamBold,
						TextSize = 9,
					}),
					LuckText = e("TextLabel", {
						Text = string.format(
							"Luck: <font color='#00FFCC'>%d%%</font> | Exp: <font color='#00FFCC'>+%d%%</font>",
							liveLuck,
							liveExp
						),
						Size = UDim2.new(1, 0, 0, 12),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(220, 220, 220),
						TextSize = 8.5,
						Font = Enum.Font.GothamBold,
						RichText = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					SpeedText = e("TextLabel", {
						Text = string.format(
							"Speed: <font color='#00FFCC'>%d%%</font> | Global Variant: <font color='#00FFCC'>%d%%</font>",
							liveSpeed,
							liveVariant
						),
						Size = UDim2.new(1, 0, 0, 12),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(220, 220, 220),
						TextSize = 8.5,
						Font = Enum.Font.GothamBold,
						RichText = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					VariantsText = e("TextLabel", {
						Text = string.format(
							"🔱G:%d%% | 🌈R:%d%% | 🌌Gx:%d%% | 🔥H:%d%%",
							liveGolden,
							liveRainbow,
							liveGalaxy,
							liveHellfire
						),
						Size = UDim2.new(1, 0, 0, 12),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(180, 180, 180),
						TextSize = 8.5,
						Font = Enum.Font.GothamBold,
						RichText = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				}),

				PresetsTitle = e("TextLabel", {
					Text = "PRESET EVENT INSTAN",
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(240, 240, 240),
					Font = Enum.Font.GothamBold,
					TextSize = 9,
				}),

				PresetsContainer = e("Frame", {
					Size = UDim2.new(1, 0, 0, 52),
					BackgroundTransparency = 1,
				}, {
					List = e(
						"UIListLayout",
						{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }
					),
					BtnDoubleExp = e("TextButton", {
						Text = "🔥 DOUBLE EXP",
						Size = UDim2.new(0.32, 0, 0, 22),
						BackgroundColor3 = Color3.fromRGB(35, 35, 45),
						TextColor3 = Color3.fromRGB(0, 220, 200),
						Font = Enum.Font.GothamBold,
						TextSize = 8,
						BorderSizePixel = 0,
						[Event.Activated] = function()
							applyPreset("DoubleEXP")
						end,
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
					BtnLuckyHype = e("TextButton", {
						Text = "🍀 LUCKY HYPE",
						Size = UDim2.new(0.32, 0, 0, 22),
						BackgroundColor3 = Color3.fromRGB(35, 35, 45),
						TextColor3 = Color3.fromRGB(0, 220, 200),
						Font = Enum.Font.GothamBold,
						TextSize = 8,
						BorderSizePixel = 0,
						[Event.Activated] = function()
							applyPreset("LuckyHype")
						end,
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
					BtnWeekend = e("TextButton", {
						Text = "🎉 WEEKEND",
						Size = UDim2.new(0.32, 0, 0, 22),
						BackgroundColor3 = Color3.fromRGB(35, 35, 45),
						TextColor3 = Color3.fromRGB(230, 160, 50),
						Font = Enum.Font.GothamBold,
						TextSize = 8,
						BorderSizePixel = 0,
						[Event.Activated] = function()
							applyPreset("WeekendBoost")
						end,
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
				}),

				GlobalToggle = e("TextButton", {
					Text = (
						isGlobalEvent and "🌎 LINGKUP: GLOBAL (SEMUA SERVER)" or "🖥️ LINGKUP: SERVER INI SAJA"
					),
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundColor3 = isGlobalEvent and Color3.fromRGB(20, 50, 40) or Color3.fromRGB(40, 40, 48),
					TextColor3 = isGlobalEvent and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(200, 200, 210),
					Font = Enum.Font.GothamBold,
					TextSize = 9,
					BorderSizePixel = 0,
					[Event.Activated] = function()
						setIsGlobalEvent(not isGlobalEvent)
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
					Stroke = e("UIStroke", {
						Color = isGlobalEvent and Color3.fromRGB(0, 200, 120) or Color3.fromRGB(70, 70, 80),
						Thickness = 1,
					}),
				}),

				ActionContainer = e("Frame", {
					Size = UDim2.new(1, 0, 0, 32),
					BackgroundTransparency = 1,
				}, {
					List = e(
						"UIListLayout",
						{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }
					),
					StartEvent = e("TextButton", {
						Text = "START EVENT",
						Size = UDim2.new(0.38, 0, 1, 0),
						BackgroundColor3 = Color3.fromRGB(0, 170, 100),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						Font = Enum.Font.GothamBold,
						TextSize = 9,
						BorderSizePixel = 0,
						[Event.Activated] = handleApply,
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
					Apply = e("TextButton", {
						Text = "TERAPKAN",
						Size = UDim2.new(0.28, 0, 1, 0),
						BackgroundColor3 = Color3.fromRGB(50, 60, 75),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						Font = Enum.Font.GothamBold,
						TextSize = 9,
						BorderSizePixel = 0,
						[Event.Activated] = handleApply,
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
					Stop = e("TextButton", {
						Text = "STOP ALL",
						Size = UDim2.new(0.28, 0, 1, 0),
						BackgroundColor3 = Color3.fromRGB(190, 45, 45),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						Font = Enum.Font.GothamBold,
						TextSize = 9,
						BorderSizePixel = 0,
						[Event.Activated] = handleStopAll,
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
				}),
			})
		else
			-- PC side-by-side layout
			return e("Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
			}, {
				-- Left Scroll list (Sliders)
				SlidersScroll = e("ScrollingFrame", {
					Size = UDim2.new(0.58, 0, 1, 0),
					BackgroundTransparency = 1,
					CanvasSize = UDim2.new(0, 0, 0, 0),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollBarThickness = 4,
					ScrollBarImageColor3 = Color3.fromRGB(60, 60, 75),
				}, {
					List = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 8),
					}),
					Padding = e("UIPadding", { PaddingRight = UDim.new(0, 8) }),

					Luck = createSliderRow("🍀 Luck Boost (0-500%)", 0, 500, luckInput, setLuckInput),
					Exp = createSliderRow("🆙 Exp Boost (0-500%)", 0, 500, expInput, setExpInput),
					Speed = createSliderRow("⚡ Speed Boost (0-100%)", 0, 100, speedInput, setSpeedInput),
					Variant = createSliderRow("🌟 Global Variant (0-100%)", 0, 100, variantInput, setVariantInput),

					AccordionBtn = e("TextButton", {
						Text = (isAccordionOpen and "▼ Sembunyikan Varian Khusus" or "▶ Tampilkan Varian Khusus"),
						Size = UDim2.new(1, 0, 0, 26),
						BackgroundColor3 = Color3.fromRGB(25, 25, 32),
						TextColor3 = Color3.fromRGB(200, 200, 210),
						Font = Enum.Font.GothamBold,
						TextSize = 10,
						BorderSizePixel = 0,
						[Event.Activated] = function()
							setIsAccordionOpen(not isAccordionOpen)
						end,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
					}),

					AccordionFrame = isAccordionOpen and e("Frame", {
						Size = UDim2.new(1, 0, 0, 160),
						BackgroundTransparency = 1,
					}, {
						List = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Vertical,
							Padding = UDim.new(0, 8),
						}),
						Golden = createSliderRow("🔱 Golden Boost (0-50%)", 0, 50, goldenInput, setGoldenInput),
						Rainbow = createSliderRow("🌈 Rainbow Boost (0-50%)", 0, 50, rainbowInput, setRainbowInput),
						Galaxy = createSliderRow("🌌 Galaxy Boost (0-50%)", 0, 50, galaxyInput, setGalaxyInput),
						Hellfire = createSliderRow(
							"🔥 Hellfire Boost (0-50%)",
							0,
							50,
							hellfireInput,
							setHellfireInput
						),
					}) or nil,
				}),

				-- Right Panel (Live status & Presets & Control buttons)
				RightSide = e("Frame", {
					Size = UDim2.new(0.4, 0, 1, 0),
					Position = UDim2.new(0.6, 0, 0, 0),
					BackgroundTransparency = 1,
				}, {
					List = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 8),
					}),

					LiveMonitor = e("Frame", {
						Size = UDim2.new(1, 0, 0, 100),
						BackgroundColor3 = Color3.fromRGB(20, 20, 25),
						BorderSizePixel = 0,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
						Padding = e(
							"UIPadding",
							{ PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }
						),
						List = e(
							"UIListLayout",
							{ FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 1) }
						),

						Title = e("TextLabel", {
							Text = "🔴 LIVE MONITOR STATUS",
							Size = UDim2.new(1, 0, 0, 16),
							BackgroundTransparency = 1,
							TextColor3 = Color3.fromRGB(255, 60, 60),
							Font = Enum.Font.GothamBold,
							TextSize = 9,
						}),
						LuckText = e("TextLabel", {
							Text = string.format(
								"Luck: <font color='#00FFCC'>%d%%</font> | Exp: <font color='#00FFCC'>+%d%%</font>",
								liveLuck,
								liveExp
							),
							Size = UDim2.new(1, 0, 0, 14),
							BackgroundTransparency = 1,
							TextColor3 = Color3.fromRGB(220, 220, 220),
							TextSize = 8,
							Font = Enum.Font.GothamBold,
							RichText = true,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						SpeedText = e("TextLabel", {
							Text = string.format(
								"Speed: <font color='#00FFCC'>%d%%</font> | Global Variant: <font color='#00FFCC'>%d%%</font>",
								liveSpeed,
								liveVariant
							),
							Size = UDim2.new(1, 0, 0, 14),
							BackgroundTransparency = 1,
							TextColor3 = Color3.fromRGB(220, 220, 220),
							TextSize = 8,
							Font = Enum.Font.GothamBold,
							RichText = true,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						VariantsText = e("TextLabel", {
							Text = string.format(
								"🔱G:%d%% | 🌈R:%d%% | 🌌Gx:%d%% | 🔥H:%d%%",
								liveGolden,
								liveRainbow,
								liveGalaxy,
								liveHellfire
							),
							Size = UDim2.new(1, 0, 0, 14),
							BackgroundTransparency = 1,
							TextColor3 = Color3.fromRGB(180, 180, 180),
							TextSize = 8,
							Font = Enum.Font.GothamBold,
							RichText = true,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
					}),

					PresetsTitle = e("TextLabel", {
						Text = "PRESET EVENT INSTAN",
						Size = UDim2.new(1, 0, 0, 14),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(240, 240, 240),
						Font = Enum.Font.GothamBold,
						TextSize = 9,
					}),

					PresetsContainer = e("Frame", {
						Size = UDim2.new(1, 0, 0, 80),
						BackgroundTransparency = 1,
					}, {
						List = e(
							"UIListLayout",
							{ FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 4) }
						),

						BtnDoubleExp = e("TextButton", {
							Text = "🔥 DOUBLE EXP (+100%)",
							Size = UDim2.new(1, 0, 0, 22),
							BackgroundColor3 = Color3.fromRGB(35, 35, 45),
							TextColor3 = Color3.fromRGB(0, 220, 200),
							Font = Enum.Font.GothamBold,
							TextSize = 8,
							BorderSizePixel = 0,
							[Event.Activated] = function()
								applyPreset("DoubleEXP")
							end,
						}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),

						BtnLuckyHype = e("TextButton", {
							Text = "🍀 LUCKY HYPE (+200% Luck, +10% Var)",
							Size = UDim2.new(1, 0, 0, 22),
							BackgroundColor3 = Color3.fromRGB(35, 35, 45),
							TextColor3 = Color3.fromRGB(0, 220, 200),
							Font = Enum.Font.GothamBold,
							TextSize = 8,
							BorderSizePixel = 0,
							[Event.Activated] = function()
								applyPreset("LuckyHype")
							end,
						}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),

						BtnWeekend = e("TextButton", {
							Text = "🎉 WEEKEND BOOST (ALL MULTIPLIERS)",
							Size = UDim2.new(1, 0, 0, 22),
							BackgroundColor3 = Color3.fromRGB(35, 35, 45),
							TextColor3 = Color3.fromRGB(230, 160, 50),
							Font = Enum.Font.GothamBold,
							TextSize = 8,
							BorderSizePixel = 0,
							[Event.Activated] = function()
								applyPreset("WeekendBoost")
							end,
						}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
					}),

					-- Target global vs server toggle for event
					GlobalToggle = e("TextButton", {
						Text = (
							isGlobalEvent and "🌎 LINGKUP: GLOBAL (SEMUA SERVER)"
							or "🖥️ LINGKUP: SERVER INI SAJA"
						),
						Size = UDim2.new(1, 0, 0, 26),
						BackgroundColor3 = isGlobalEvent and Color3.fromRGB(20, 50, 40) or Color3.fromRGB(40, 40, 48),
						TextColor3 = isGlobalEvent and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(200, 200, 210),
						Font = Enum.Font.GothamBold,
						TextSize = 9,
						BorderSizePixel = 0,
						[Event.Activated] = function()
							setIsGlobalEvent(not isGlobalEvent)
						end,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
						Stroke = e("UIStroke", {
							Color = isGlobalEvent and Color3.fromRGB(0, 200, 120) or Color3.fromRGB(70, 70, 80),
							Thickness = 1,
						}),
					}),

					ActionContainer = e("Frame", {
						Size = UDim2.new(1, 0, 0, 32),
						BackgroundTransparency = 1,
					}, {
						List = e(
							"UIListLayout",
							{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }
						),

						StartEvent = e("TextButton", {
							Text = "START EVENT",
							Size = UDim2.new(0.38, 0, 1, 0),
							BackgroundColor3 = Color3.fromRGB(0, 170, 100),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 9,
							BorderSizePixel = 0,
							[Event.Activated] = handleApply,
						}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),

						Apply = e("TextButton", {
							Text = "TERAPKAN",
							Size = UDim2.new(0.28, 0, 1, 0),
							BackgroundColor3 = Color3.fromRGB(50, 60, 75),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 9,
							BorderSizePixel = 0,
							[Event.Activated] = handleApply,
						}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),

						Stop = e("TextButton", {
							Text = "STOP ALL",
							Size = UDim2.new(0.28, 0, 1, 0),
							BackgroundColor3 = Color3.fromRGB(190, 45, 45),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 9,
							BorderSizePixel = 0,
							[Event.Activated] = handleStopAll,
						}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
					}),
				}),
			})
		end
	end

	-- TAB 2 LAYOUT: BROADCAST
	local function renderBroadcastTab()
		local broadcastContent = {
			List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10) }),

			Title = e("TextLabel", {
				Text = "📢 BROADCAST ANNOUNCEMENT BANNER",
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(240, 240, 240),
				Font = Enum.Font.GothamBold,
				TextSize = isMobile and 10 or 12,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			InputBg = e("Frame", {
				Size = UDim2.new(1, 0, 0, isMobile and 80 or 100),
				BackgroundColor3 = Color3.fromRGB(20, 20, 25),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				TextBox = e("TextBox", {
					Text = broadcastText,
					PlaceholderText = "Tulis pesan pengumuman di sini... (Mendukung format RichText seperti <b>teks</b> atau <font color='#FF0000'>merah</font>)",
					Size = UDim2.new(1, -20, 1, -20),
					Position = UDim2.new(0, 10, 0, 10),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					PlaceholderColor3 = Color3.fromRGB(120, 120, 130),
					Font = Enum.Font.GothamMedium,
					TextSize = isMobile and 10 or 12,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					ClearTextOnFocus = false,
					[Change.Text] = function(box: TextBox)
						local text = box.Text
						if string.len(text) > 200 then
							box.Text = string.sub(text, 1, 200)
							setBroadcastText(box.Text)
						else
							setBroadcastText(text)
						end
					end,
				}),
			}),

			GlobalToggle = e("TextButton", {
				Text = (
					isGlobalBroadcast and "🌎 LINGKUP: GLOBAL (SEMUA SERVER)" or "🖥️ LINGKUP: SERVER INI SAJA"
				),
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = isGlobalBroadcast and Color3.fromRGB(20, 50, 40) or Color3.fromRGB(40, 40, 48),
				TextColor3 = isGlobalBroadcast and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(200, 200, 210),
				Font = Enum.Font.GothamBold,
				TextSize = 9,
				BorderSizePixel = 0,
				[Event.Activated] = function()
					setIsGlobalBroadcast(not isGlobalBroadcast)
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Stroke = e("UIStroke", {
					Color = isGlobalBroadcast and Color3.fromRGB(0, 200, 120) or Color3.fromRGB(70, 70, 80),
					Thickness = 1,
				}),
			}),

			SendBtn = e("TextButton", {
				Text = "📢 KIRIM PESAN PENGUMUMAN",
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundColor3 = Color3.fromRGB(0, 120, 220),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				BorderSizePixel = 0,
				[Event.Activated] = function()
					if broadcastText ~= "" and props.onBroadcastMessage then
						props.onBroadcastMessage(broadcastText, isGlobalBroadcast)
						setBroadcastText("") -- Reset field
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
		}

		return e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(80, 80, 95),
		}, broadcastContent)
	end

	-- TAB 3 LAYOUT: GIFTS
	local function renderGiftsTab()
		return e("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}, {
			-- Target Selector header (All or Specific)
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10) }),

			TargetHeader = e("Frame", {
				Size = isMobile and UDim2.new(1, 0, 0, targetType == "Specific" and 66 or 32) or UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 6),
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				ButtonsRow = isMobile and e("Frame", {
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 1,
				}, {
					Layout = e(
						"UIListLayout",
						{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }
					),
					AllBtn = e("TextButton", {
						Text = "👥 Semua Player",
						Size = UDim2.new(0.47, 0, 1, 0),
						BackgroundColor3 = targetType == "All" and Color3.fromRGB(30, 45, 65)
							or Color3.fromRGB(22, 22, 28),
						TextColor3 = targetType == "All" and Color3.fromRGB(0, 220, 255)
							or Color3.fromRGB(160, 160, 170),
						Font = Enum.Font.GothamBold,
						TextSize = 10,
						BorderSizePixel = 0,
						[Event.Activated] = function()
							setTargetType("All")
						end,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
						Stroke = e("UIStroke", {
							Color = targetType == "All" and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(45, 45, 55),
							Thickness = 1,
						}),
					}),
					SpecificBtn = e("TextButton", {
						Text = "👤 Spesifik Player",
						Size = UDim2.new(0.47, 0, 1, 0),
						BackgroundColor3 = targetType == "Specific" and Color3.fromRGB(30, 45, 65)
							or Color3.fromRGB(22, 22, 28),
						TextColor3 = targetType == "Specific" and Color3.fromRGB(0, 220, 255)
							or Color3.fromRGB(160, 160, 170),
						Font = Enum.Font.GothamBold,
						TextSize = 10,
						BorderSizePixel = 0,
						[Event.Activated] = function()
							setTargetType("Specific")
						end,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
						Stroke = e("UIStroke", {
							Color = targetType == "Specific" and Color3.fromRGB(0, 170, 255)
								or Color3.fromRGB(45, 45, 55),
							Thickness = 1,
						}),
					}),
				}) or nil,

				AllBtn = not isMobile
						and e("TextButton", {
							Text = "👥 Semua Player",
							Size = UDim2.new(0.3, 0, 1, 0),
							BackgroundColor3 = targetType == "All" and Color3.fromRGB(30, 45, 65)
								or Color3.fromRGB(22, 22, 28),
							TextColor3 = targetType == "All" and Color3.fromRGB(0, 220, 255)
								or Color3.fromRGB(160, 160, 170),
							Font = Enum.Font.GothamBold,
							TextSize = 10,
							BorderSizePixel = 0,
							[Event.Activated] = function()
								setTargetType("All")
							end,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
							Stroke = e("UIStroke", {
								Color = targetType == "All" and Color3.fromRGB(0, 170, 255)
									or Color3.fromRGB(45, 45, 55),
								Thickness = 1,
							}),
						})
					or nil,

				SpecificBtn = not isMobile
						and e("TextButton", {
							Text = "👤 Spesifik Player",
							Size = UDim2.new(0.3, 0, 1, 0),
							BackgroundColor3 = targetType == "Specific" and Color3.fromRGB(30, 45, 65)
								or Color3.fromRGB(22, 22, 28),
							TextColor3 = targetType == "Specific" and Color3.fromRGB(0, 220, 255)
								or Color3.fromRGB(160, 160, 170),
							Font = Enum.Font.GothamBold,
							TextSize = 10,
							BorderSizePixel = 0,
							[Event.Activated] = function()
								setTargetType("Specific")
							end,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
							Stroke = e("UIStroke", {
								Color = targetType == "Specific" and Color3.fromRGB(0, 170, 255)
									or Color3.fromRGB(45, 45, 55),
								Thickness = 1,
							}),
						})
					or nil,

				SpecificInput = targetType == "Specific" and e("TextBox", {
					Text = targetPlayerName,
					PlaceholderText = "Nama Player...",
					Size = isMobile and UDim2.new(1, 0, 0, 30) or UDim2.new(0.35, 0, 1, 0),
					BackgroundColor3 = Color3.fromRGB(20, 20, 25),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					PlaceholderColor3 = Color3.fromRGB(120, 120, 130),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					BorderSizePixel = 0,
					ClearTextOnFocus = false,
					[Change.Text] = function(box: TextBox)
						setTargetPlayerName(box.Text)
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
					Stroke = e("UIStroke", { Color = Color3.fromRGB(55, 55, 65), Thickness = 1 }),
				}) or nil,
			}),

			-- Scope for All players (Global vs Server)
			ScopeHeader = targetType == "All" and e("TextButton", {
				Text = (
					isGlobalGift and "🌎 LINGKUP: GLOBAL (GIFT SEMUA SERVER)" or "🖥️ LINGKUP: SERVER INI SAJA"
				),
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = isGlobalGift and Color3.fromRGB(20, 50, 40) or Color3.fromRGB(40, 40, 48),
				TextColor3 = isGlobalGift and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(200, 200, 210),
				Font = Enum.Font.GothamBold,
				TextSize = 9,
				BorderSizePixel = 0,
				[Event.Activated] = function()
					setIsGlobalGift(not isGlobalGift)
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Stroke = e("UIStroke", {
					Color = isGlobalGift and Color3.fromRGB(0, 200, 120) or Color3.fromRGB(70, 70, 80),
					Thickness = 1,
				}),
			}) or nil,

			-- scrolling gift cards container
			GiftCardsScroll = e("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, targetType == "All" and -72 or -46),
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Color3.fromRGB(60, 60, 75),
			}, {
				List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10) }),

				-- Row 1: Cash & Fast Actions
				CashRow = e("Frame", {
					Size = isMobile and UDim2.new(1, -6, 0, 80) or UDim2.new(1, -6, 0, 66),
					BackgroundColor3 = Color3.fromRGB(20, 20, 25),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Padding = e(
						"UIPadding",
						{ PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }
					),
					List = e("UIListLayout", {
						FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 6),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),

					TopRow = isMobile and e("Frame", {
						Size = UDim2.new(1, 0, 0, 26),
						BackgroundTransparency = 1,
					}, {
						List = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 10),
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						Title = e("TextLabel", {
							Text = "💵 GIFT CASH",
							Size = UDim2.new(0.4, 0, 1, 0),
							BackgroundTransparency = 1,
							TextColor3 = Color3.fromRGB(0, 255, 120),
							Font = Enum.Font.GothamBold,
							TextSize = 10,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						Input = e("TextBox", {
							Text = tostring(giftCashAmount),
							Size = UDim2.new(0.5, -10, 1, 0),
							BackgroundColor3 = Color3.fromRGB(30, 30, 38),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 10,
							BorderSizePixel = 0,
							ClearTextOnFocus = false,
							[Change.Text] = function(box: TextBox)
								setGiftCashAmount(tonumber(box.Text) or 0)
							end,
						}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
					}) or nil,

					Title = not isMobile and e("TextLabel", {
						Text = "💵 GIFT CASH",
						Size = UDim2.new(0.2, 0, 0, 20),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(0, 255, 120),
						Font = Enum.Font.GothamBold,
						TextSize = 10,
						TextXAlignment = Enum.TextXAlignment.Left,
					}) or nil,

					Input = not isMobile and e("TextBox", {
						Text = tostring(giftCashAmount),
						Size = UDim2.new(0.2, 0, 0, 30),
						BackgroundColor3 = Color3.fromRGB(30, 30, 38),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						Font = Enum.Font.GothamBold,
						TextSize = 11,
						BorderSizePixel = 0,
						ClearTextOnFocus = false,
						[Change.Text] = function(box: TextBox)
							setGiftCashAmount(tonumber(box.Text) or 0)
						end,
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }) or nil,

					BottomButtons = isMobile and e("Frame", {
						Size = UDim2.new(1, 0, 0, 26),
						BackgroundTransparency = 1,
					}, {
						List = e(
							"UIListLayout",
							{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }
						),
						SendBtn = e("TextButton", {
							Text = "GIFT CASH",
							Size = UDim2.new(0.45, 0, 1, 0),
							BackgroundColor3 = Color3.fromRGB(0, 150, 80),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 9,
							BorderSizePixel = 0,
							[Event.Activated] = function()
								local target = targetType == "All" and "All" or targetPlayerName
								if target ~= "" and props.onGiftReward then
									props.onGiftReward("Cash", target, isGlobalGift, { Amount = giftCashAmount })
								end
							end,
						}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),

						FastCashBtn = e("TextButton", {
							Text = "⚡ GIFT 24H CASH",
							Size = UDim2.new(0.51, 0, 1, 0),
							BackgroundColor3 = Color3.fromRGB(230, 140, 0),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 8,
							BorderSizePixel = 0,
							[Event.Activated] = function()
								local target = targetType == "All" and "All" or targetPlayerName
								if target ~= "" and props.onGiftReward then
									props.onGiftReward("24hCash", target, isGlobalGift, {})
								end
							end,
						}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
					}) or nil,

					SendBtn = not isMobile and e("TextButton", {
						Text = "GIFT CASH",
						Size = UDim2.new(0.2, 0, 0, 30),
						BackgroundColor3 = Color3.fromRGB(0, 150, 80),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						Font = Enum.Font.GothamBold,
						TextSize = 9,
						BorderSizePixel = 0,
						[Event.Activated] = function()
							local target = targetType == "All" and "All" or targetPlayerName
							if target ~= "" and props.onGiftReward then
								props.onGiftReward("Cash", target, isGlobalGift, { Amount = giftCashAmount })
							end
						end,
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }) or nil,

					FastCashBtn = not isMobile and e("TextButton", {
						Text = "⚡ GIFT INSTAN 24 JAM CASH",
						Size = UDim2.new(0.32, 0, 0, 30),
						BackgroundColor3 = Color3.fromRGB(230, 140, 0),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						Font = Enum.Font.GothamBold,
						TextSize = 8,
						BorderSizePixel = 0,
						[Event.Activated] = function()
							local target = targetType == "All" and "All" or targetPlayerName
							if target ~= "" and props.onGiftReward then
								props.onGiftReward("24hCash", target, isGlobalGift, {})
							end
						end,
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }) or nil,
				}),

				-- Row 2: Box Gifting
				BoxRow = e("Frame", {
					Size = isMobile and UDim2.new(1, -6, 0, 145) or UDim2.new(1, -6, 0, 120),
					BackgroundColor3 = Color3.fromRGB(20, 20, 25),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Padding = e(
						"UIPadding",
						{ PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }
					),
					List = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 8),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),

					TopControls = e("Frame", {
						Size = isMobile and UDim2.new(1, 0, 0, 60) or UDim2.new(1, 0, 0, 36),
						BackgroundTransparency = 1,
						LayoutOrder = 1,
					}, {
						Layout = e("UIListLayout", {
							FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 6),
							VerticalAlignment = Enum.VerticalAlignment.Center,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
						}),

						TopPart = isMobile and e("Frame", {
							Size = UDim2.new(1, 0, 0, 26),
							BackgroundTransparency = 1,
						}, {
							Layout = e("UIListLayout", {
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0, 10),
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							Title = e("TextLabel", {
								Text = "📦 GIFT BOX",
								Size = UDim2.new(0.35, 0, 1, 0),
								BackgroundTransparency = 1,
								TextColor3 = Color3.fromRGB(0, 170, 255),
								Font = Enum.Font.GothamBold,
								TextSize = 10,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							LabelLvl = e("TextLabel", {
								Text = "Lv (1-30):",
								Size = UDim2.new(0.25, 0, 1, 0),
								BackgroundTransparency = 1,
								TextColor3 = Color3.fromRGB(200, 200, 200),
								Font = Enum.Font.GothamBold,
								TextSize = 10,
								TextXAlignment = Enum.TextXAlignment.Right,
							}),
							Input = e("TextBox", {
								Text = tostring(giftBoxLevel),
								Size = UDim2.new(0.3, -10, 1, 0),
								BackgroundColor3 = Color3.fromRGB(30, 30, 38),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								Font = Enum.Font.GothamBold,
								TextSize = 10,
								BorderSizePixel = 0,
								ClearTextOnFocus = false,
								[Change.Text] = function(box: TextBox)
									local val = tonumber(box.Text) or 12
									setGiftBoxLevel(math.clamp(val, 1, 30))
								end,
							}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
						}) or nil,

						Title = not isMobile and e("TextLabel", {
							Text = "📦 GIFT BOX",
							Size = UDim2.new(0.2, 0, 0, 20),
							BackgroundTransparency = 1,
							TextColor3 = Color3.fromRGB(0, 170, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 10,
							TextXAlignment = Enum.TextXAlignment.Left,
						}) or nil,

						LabelLvl = not isMobile and e("TextLabel", {
							Text = "Lv (1-30):",
							Size = UDim2.new(0.12, 0, 0, 20),
							BackgroundTransparency = 1,
							TextColor3 = Color3.fromRGB(200, 200, 200),
							Font = Enum.Font.GothamBold,
							TextSize = 10,
						}) or nil,

						Input = not isMobile and e("TextBox", {
							Text = tostring(giftBoxLevel),
							Size = UDim2.new(0.12, 0, 0, 30),
							BackgroundColor3 = Color3.fromRGB(30, 30, 38),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 11,
							BorderSizePixel = 0,
							ClearTextOnFocus = false,
							[Change.Text] = function(box: TextBox)
								local val = tonumber(box.Text) or 12
								setGiftBoxLevel(math.clamp(val, 1, 30))
							end,
						}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }) or nil,

						BottomButtons = isMobile and e("Frame", {
							Size = UDim2.new(1, 0, 0, 26),
							BackgroundTransparency = 1,
						}, {
							List = e(
								"UIListLayout",
								{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }
							),
							SendBtn = e("TextButton", {
								Text = "GIFT BOX",
								Size = UDim2.new(0.45, 0, 1, 0),
								BackgroundColor3 = Color3.fromRGB(0, 120, 200),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								Font = Enum.Font.GothamBold,
								TextSize = 9,
								BorderSizePixel = 0,
								[Event.Activated] = function()
									local target = targetType == "All" and "All" or targetPlayerName
									if target ~= "" and props.onGiftReward then
										props.onGiftReward(
											"Box",
											target,
											isGlobalGift,
											{ Level = giftBoxLevel, ExtraVariants = boxExtraVariants }
										)
									end
								end,
							}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),

							InstantBtn = e("TextButton", {
								Text = "⚡ LV.30 ADMIN BOX",
								Size = UDim2.new(0.51, 0, 1, 0),
								BackgroundColor3 = Color3.fromRGB(150, 40, 200),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								Font = Enum.Font.GothamBold,
								TextSize = 8,
								BorderSizePixel = 0,
								[Event.Activated] = function()
									local target = targetType == "All" and "All" or targetPlayerName
									if target ~= "" and props.onGiftReward then
										props.onGiftReward(
											"Box",
											target,
											isGlobalGift,
											{ Level = 30, ExtraVariants = {} }
										)
									end
								end,
							}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
						}) or nil,

						SendBtn = not isMobile and e("TextButton", {
							Text = "GIFT BOX",
							Size = UDim2.new(0.2, 0, 0, 30),
							BackgroundColor3 = Color3.fromRGB(0, 120, 200),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 9,
							BorderSizePixel = 0,
							[Event.Activated] = function()
								local target = targetType == "All" and "All" or targetPlayerName
								if target ~= "" and props.onGiftReward then
									props.onGiftReward(
										"Box",
										target,
										isGlobalGift,
										{ Level = giftBoxLevel, ExtraVariants = boxExtraVariants }
									)
								end
							end,
						}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }) or nil,

						InstantBtn = not isMobile and e("TextButton", {
							Text = "⚡ INSTAN LV.30 ADMIN BOX",
							Size = UDim2.new(0.28, 0, 0, 30),
							BackgroundColor3 = Color3.fromRGB(150, 40, 200),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 8,
							BorderSizePixel = 0,
							[Event.Activated] = function()
								local target = targetType == "All" and "All" or targetPlayerName
								if target ~= "" and props.onGiftReward then
									props.onGiftReward("Box", target, isGlobalGift, { Level = 30, ExtraVariants = {} })
								end
							end,
						}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }) or nil,
					}),

					VariantPicker = createVariantPicker(boxExtraVariants, setBoxExtraVariants),
				}),

				-- Row 3: Car Gifting (Dropdown search autocompletion)
				CarRow = e("Frame", {
					Size = isMobile and UDim2.new(1, -6, 0, 240) or UDim2.new(1, -6, 0, 210),
					BackgroundColor3 = Color3.fromRGB(20, 20, 25),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Padding = e(
						"UIPadding",
						{ PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }
					),
					List = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 8),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),

					Title = e("TextLabel", {
						Text = "🏎️ GIFT CAR & ADMIN CAR INSTAN",
						Size = UDim2.new(1, 0, 0, 18),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(255, 100, 100),
						Font = Enum.Font.GothamBold,
						TextSize = 10,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 1,
					}),

					-- Section 1: Admin Car Selection Dropdown
					AdminSection = e("Frame", {
						Size = isMobile and UDim2.new(1, 0, 0, 50) or UDim2.new(1, 0, 0, 32),
						BackgroundTransparency = 1,
						LayoutOrder = 2,
					}, {
						Layout = e("UIListLayout", {
							FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 4),
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						Label = e("TextLabel", {
							Text = "Pilih Admin Car:",
							Size = isMobile and UDim2.new(1, 0, 0, 16) or UDim2.new(0.2, 0, 1, 0),
							BackgroundTransparency = 1,
							TextColor3 = Color3.fromRGB(200, 200, 200),
							Font = Enum.Font.GothamBold,
							TextSize = 9,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						ButtonsRow = isMobile and e("Frame", {
							Size = UDim2.new(1, 0, 0, 30),
							BackgroundTransparency = 1,
						}, {
							Layout = e(
								"UIListLayout",
								{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }
							),
							DropdownBtn = e("TextButton", {
								Text = selectedAdminCar == "" and "Pilih Admin Car..." or selectedAdminCar,
								Size = UDim2.new(0.55, 0, 1, 0),
								BackgroundColor3 = Color3.fromRGB(30, 30, 38),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								Font = Enum.Font.GothamBold,
								TextSize = 9,
								BorderSizePixel = 0,
								[Event.Activated] = function()
									setIsAdminCarDropdownOpen(not isAdminCarDropdownOpen)
								end,
							}, {
								Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
							}),
							GiftAdminBtn = e("TextButton", {
								Text = "GIFT ADMIN",
								Size = UDim2.new(0.4, 0, 1, 0),
								BackgroundColor3 = Color3.fromRGB(150, 35, 150),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								Font = Enum.Font.GothamBold,
								TextSize = 9,
								BorderSizePixel = 0,
								[Event.Activated] = function()
									local target = targetType == "All" and "All" or targetPlayerName
									if target ~= "" and selectedAdminCar ~= "" and props.onGiftReward then
										props.onGiftReward(
											"Car",
											target,
											isGlobalGift,
											{ CarName = selectedAdminCar, ExtraVariants = {} }
										)
									end
								end,
							}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),

							DropdownList = isAdminCarDropdownOpen and e(
								"ScrollingFrame",
								{
									Size = UDim2.new(0.55, 0, 0, 100),
									Position = UDim2.new(0, 0, 0, 32),
									BackgroundColor3 = Color3.fromRGB(25, 25, 30),
									BorderSizePixel = 1,
									BorderColor3 = Color3.fromRGB(55, 55, 65),
									CanvasSize = UDim2.new(0, 0, 0, 0),
									AutomaticCanvasSize = Enum.AutomaticSize.Y,
									ZIndex = 12,
									ScrollBarThickness = 3,
								},
								(function()
									local childrenTable = {
										Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical }),
									}
									for _, car in ipairs(adminCars) do
										childrenTable[car.Name] = e("TextButton", {
											Text = " " .. car.Name,
											Size = UDim2.new(1, 0, 0, 20),
											BackgroundColor3 = Color3.fromRGB(25, 25, 30),
											TextColor3 = Color3.fromRGB(220, 220, 220),
											Font = Enum.Font.GothamMedium,
											TextSize = 8,
											TextXAlignment = Enum.TextXAlignment.Left,
											BorderSizePixel = 0,
											ZIndex = 13,
											[Event.Activated] = function()
												setSelectedAdminCar(car.Name)
												setIsAdminCarDropdownOpen(false)
											end,
										})
									end
									if #adminCars == 0 then
										childrenTable.None = e("TextLabel", {
											Text = " Tidak ada admin car",
											Size = UDim2.new(1, 0, 0, 20),
											BackgroundTransparency = 1,
											TextColor3 = Color3.fromRGB(150, 150, 150),
											Font = Enum.Font.GothamMedium,
											TextSize = 8,
											TextXAlignment = Enum.TextXAlignment.Left,
											ZIndex = 13,
										})
									end
									return childrenTable
								end)()
							) or nil,
						}) or nil,

						DropdownBtn = not isMobile and e("TextButton", {
							Text = selectedAdminCar == "" and "Pilih Admin Car..." or selectedAdminCar,
							Size = UDim2.new(0.42, 0, 0, 30),
							BackgroundColor3 = Color3.fromRGB(30, 30, 38),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 9,
							BorderSizePixel = 0,
							[Event.Activated] = function()
								setIsAdminCarDropdownOpen(not isAdminCarDropdownOpen)
							end,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
						}) or nil,
						GiftAdminBtn = not isMobile and e("TextButton", {
							Text = "GIFT ADMIN CAR",
							Size = UDim2.new(0.25, 0, 0, 30),
							BackgroundColor3 = Color3.fromRGB(150, 35, 150),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 9,
							BorderSizePixel = 0,
							[Event.Activated] = function()
								local target = targetType == "All" and "All" or targetPlayerName
								if target ~= "" and selectedAdminCar ~= "" and props.onGiftReward then
									props.onGiftReward(
										"Car",
										target,
										isGlobalGift,
										{ CarName = selectedAdminCar, ExtraVariants = {} }
									)
								end
							end,
						}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }) or nil,

						DropdownList = (not isMobile and isAdminCarDropdownOpen) and e(
							"ScrollingFrame",
							{
								Size = UDim2.new(0.42, 0, 0, 100),
								Position = UDim2.new(0.2, 10, 0, 32),
								BackgroundColor3 = Color3.fromRGB(25, 25, 30),
								BorderSizePixel = 1,
								BorderColor3 = Color3.fromRGB(55, 55, 65),
								CanvasSize = UDim2.new(0, 0, 0, 0),
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								ZIndex = 12,
								ScrollBarThickness = 3,
							},
							(function()
								local childrenTable = {
									Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical }),
								}
								for _, car in ipairs(adminCars) do
									childrenTable[car.Name] = e("TextButton", {
										Text = " " .. car.Name,
										Size = UDim2.new(1, 0, 0, 20),
										BackgroundColor3 = Color3.fromRGB(25, 25, 30),
										TextColor3 = Color3.fromRGB(220, 220, 220),
										Font = Enum.Font.GothamMedium,
										TextSize = 8,
										TextXAlignment = Enum.TextXAlignment.Left,
										BorderSizePixel = 0,
										ZIndex = 13,
										[Event.Activated] = function()
											setSelectedAdminCar(car.Name)
											setIsAdminCarDropdownOpen(false)
										end,
									})
								end
								if #adminCars == 0 then
									childrenTable.None = e("TextLabel", {
										Text = " Tidak ada admin car",
										Size = UDim2.new(1, 0, 0, 20),
										BackgroundTransparency = 1,
										TextColor3 = Color3.fromRGB(150, 150, 150),
										Font = Enum.Font.GothamMedium,
										TextSize = 8,
										TextXAlignment = Enum.TextXAlignment.Left,
										ZIndex = 13,
									})
								end
								return childrenTable
							end)()
						) or nil,
					}),

					-- Section 2: Gift Car by Name search + variant picker
					SearchSection = e("Frame", {
						Size = isMobile and UDim2.new(1, 0, 0, 50) or UDim2.new(1, 0, 0, 32),
						BackgroundTransparency = 1,
						LayoutOrder = 3,
					}, {
						Layout = e("UIListLayout", {
							FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 4),
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						Label = e("TextLabel", {
							Text = "Cari Mobil:",
							Size = isMobile and UDim2.new(1, 0, 0, 16) or UDim2.new(0.2, 0, 1, 0),
							BackgroundTransparency = 1,
							TextColor3 = Color3.fromRGB(200, 200, 200),
							Font = Enum.Font.GothamBold,
							TextSize = 9,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						ButtonsRow = isMobile and e("Frame", {
							Size = UDim2.new(1, 0, 0, 30),
							BackgroundTransparency = 1,
						}, {
							Layout = e(
								"UIListLayout",
								{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }
							),
							SearchBox = e("TextBox", {
								Text = carSearchText,
								PlaceholderText = "Ketik Nama Mobil...",
								Size = UDim2.new(0.55, 0, 1, 0),
								BackgroundColor3 = Color3.fromRGB(30, 30, 38),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								PlaceholderColor3 = Color3.fromRGB(120, 120, 130),
								Font = Enum.Font.GothamBold,
								TextSize = 9,
								BorderSizePixel = 0,
								ClearTextOnFocus = false,
								[Change.Text] = function(box: TextBox)
									setCarSearchText(box.Text)
									setIsCarDropdownOpen(true)
								end,
								[Event.Focused] = function()
									setIsCarDropdownOpen(true)
								end,
							}, {
								Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
							}),
							GiftCarBtn = e("TextButton", {
								Text = "GIFT MOBIL",
								Size = UDim2.new(0.4, 0, 1, 0),
								BackgroundColor3 = Color3.fromRGB(170, 35, 35),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								Font = Enum.Font.GothamBold,
								TextSize = 9,
								BorderSizePixel = 0,
								[Event.Activated] = function()
									local target = targetType == "All" and "All" or targetPlayerName
									if target ~= "" and carSearchText ~= "" and props.onGiftReward then
										props.onGiftReward(
											"Car",
											target,
											isGlobalGift,
											{ CarName = carSearchText, ExtraVariants = carExtraVariants }
										)
									end
								end,
							}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),

							DropdownList = isCarDropdownOpen and e(
								"ScrollingFrame",
								{
									Size = UDim2.new(0.55, 0, 0, 100),
									Position = UDim2.new(0, 0, 0, 32),
									BackgroundColor3 = Color3.fromRGB(25, 25, 30),
									BorderSizePixel = 1,
									BorderColor3 = Color3.fromRGB(55, 55, 65),
									CanvasSize = UDim2.new(0, 0, 0, 0),
									AutomaticCanvasSize = Enum.AutomaticSize.Y,
									ZIndex = 10,
									ScrollBarThickness = 3,
								},
								(function()
									local childrenTable = {
										Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical }),
									}
									for index, car in ipairs(filteredCars) do
										if index > 20 then
											break
										end
										childrenTable[car.Name] = e("TextButton", {
											Text = string.format(" %s [%s]", car.Name, car.Rarity),
											Size = UDim2.new(1, 0, 0, 20),
											BackgroundColor3 = Color3.fromRGB(25, 25, 30),
											TextColor3 = Color3.fromRGB(220, 220, 220),
											Font = Enum.Font.GothamMedium,
											TextSize = 8,
											TextXAlignment = Enum.TextXAlignment.Left,
											BorderSizePixel = 0,
											ZIndex = 11,
											[Event.Activated] = function()
												setCarSearchText(car.Name)
												setIsCarDropdownOpen(false)
											end,
										})
									end
									if #filteredCars == 0 then
										childrenTable.NoCarsFound = e("TextLabel", {
											Text = " Mobil tidak ditemukan",
											Size = UDim2.new(1, 0, 0, 20),
											BackgroundTransparency = 1,
											TextColor3 = Color3.fromRGB(150, 150, 150),
											Font = Enum.Font.GothamMedium,
											TextSize = 8,
											TextXAlignment = Enum.TextXAlignment.Left,
											ZIndex = 11,
										})
									end
									return childrenTable
								end)()
							) or nil,
						}) or nil,

						SearchBox = not isMobile and e("TextBox", {
							Text = carSearchText,
							PlaceholderText = "Ketik/Cari Nama Mobil...",
							Size = UDim2.new(0.42, 0, 0, 30),
							BackgroundColor3 = Color3.fromRGB(30, 30, 38),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							PlaceholderColor3 = Color3.fromRGB(120, 120, 130),
							Font = Enum.Font.GothamBold,
							TextSize = 9,
							BorderSizePixel = 0,
							ClearTextOnFocus = false,
							[Change.Text] = function(box: TextBox)
								setCarSearchText(box.Text)
								setIsCarDropdownOpen(true)
							end,
							[Event.Focused] = function()
								setIsCarDropdownOpen(true)
							end,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
						}) or nil,
						GiftCarBtn = not isMobile and e("TextButton", {
							Text = "GIFT MOBIL",
							Size = UDim2.new(0.25, 0, 0, 30),
							BackgroundColor3 = Color3.fromRGB(170, 35, 35),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 9,
							BorderSizePixel = 0,
							[Event.Activated] = function()
								local target = targetType == "All" and "All" or targetPlayerName
								if target ~= "" and carSearchText ~= "" and props.onGiftReward then
									props.onGiftReward(
										"Car",
										target,
										isGlobalGift,
										{ CarName = carSearchText, ExtraVariants = carExtraVariants }
									)
								end
							end,
						}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }) or nil,

						DropdownList = (not isMobile and isCarDropdownOpen) and e(
							"ScrollingFrame",
							{
								Size = UDim2.new(0.42, 0, 0, 100),
								Position = UDim2.new(0.2, 10, 0, 32),
								BackgroundColor3 = Color3.fromRGB(25, 25, 30),
								BorderSizePixel = 1,
								BorderColor3 = Color3.fromRGB(55, 55, 65),
								CanvasSize = UDim2.new(0, 0, 0, 0),
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								ZIndex = 10,
								ScrollBarThickness = 3,
							},
							(function()
								local childrenTable = {
									Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical }),
								}
								for index, car in ipairs(filteredCars) do
									if index > 20 then
										break
									end
									childrenTable[car.Name] = e("TextButton", {
										Text = string.format(" %s [%s]", car.Name, car.Rarity),
										Size = UDim2.new(1, 0, 0, 20),
										BackgroundColor3 = Color3.fromRGB(25, 25, 30),
										TextColor3 = Color3.fromRGB(220, 220, 220),
										Font = Enum.Font.GothamMedium,
										TextSize = 8,
										TextXAlignment = Enum.TextXAlignment.Left,
										BorderSizePixel = 0,
										ZIndex = 11,
										[Event.Activated] = function()
											setCarSearchText(car.Name)
											setIsCarDropdownOpen(false)
										end,
									})
								end
								if #filteredCars == 0 then
									childrenTable.NoCarsFound = e("TextLabel", {
										Text = " Mobil tidak ditemukan",
										Size = UDim2.new(1, 0, 0, 20),
										BackgroundTransparency = 1,
										TextColor3 = Color3.fromRGB(150, 150, 150),
										Font = Enum.Font.GothamMedium,
										TextSize = 8,
										TextXAlignment = Enum.TextXAlignment.Left,
										ZIndex = 11,
									})
								end
								return childrenTable
							end)()
						) or nil,
					}),

					VariantPicker = createVariantPicker(carExtraVariants, setCarExtraVariants),
				}),
			}),
		})
	end

	-- TAB 4 LAYOUT: CUSTOM NAME COLOR
	local function renderNameColorTab()
		local presetColors = {
			{ Name = "Gold", Hex = "#FFD700" },
			{ Name = "Cyan", Hex = "#00FFFF" },
			{ Name = "Neon Green", Hex = "#39FF14" },
			{ Name = "Hot Pink", Hex = "#FF69B4" },
			{ Name = "Crimson Red", Hex = "#DC143C" },
			{ Name = "Royal Purple", Hex = "#9370DB" },
			{ Name = "Deep Orange", Hex = "#FF4500" },
			{ Name = "Reset (Default)", Hex = "" },
		}

		local handleApplyColor = function()
			local target = colorTargetPlayer == "Self" and "Self" or colorTargetName
			if props.onSetCustomNameColor then
				props.onSetCustomNameColor(target, selectedHexColor)
			end
		end

		local presetButtons = {}
		for idx, col in ipairs(presetColors) do
			local isSelected = selectedHexColor == col.Hex
			local btnColor = col.Hex ~= "" and Color3.fromHex(col.Hex) or Color3.fromRGB(200, 200, 200)

			presetButtons["Color_" .. idx] = e("TextButton", {
				Text = col.Name,
				Size = UDim2.new(0.48, 0, 0, 28),
				BackgroundColor3 = isSelected and Color3.fromRGB(40, 50, 65) or Color3.fromRGB(22, 22, 28),
				TextColor3 = btnColor,
				Font = Enum.Font.GothamBold,
				TextSize = 9.5,
				BorderSizePixel = 0,
				LayoutOrder = idx,
				[Event.Activated] = function()
					setSelectedHexColor(col.Hex)
					setCustomHexInput(col.Hex)
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Stroke = e("UIStroke", {
					Color = isSelected and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(45, 45, 55),
					Thickness = isSelected and 2 or 1,
				}),
			})
		end

		return e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
		}, {
			Padding = e("UIPadding", { PaddingRight = UDim.new(0, 6) }),
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10) }),

			-- Target Selection
			TargetCard = e("Frame", {
				Size = UDim2.new(1, 0, 0, 65),
				BackgroundColor3 = Color3.fromRGB(20, 20, 26),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Padding = e("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
				Title = e("TextLabel", {
					Text = "🎯 TARGET PEMAIN",
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(0, 220, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 9,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Buttons = e("Frame", {
					Size = UDim2.new(1, 0, 0, 30),
					Position = UDim2.new(0, 0, 0, 20),
					BackgroundTransparency = 1,
				}, {
					List = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
					SelfBtn = e("TextButton", {
						Text = "👤 DIRI SENDIRI",
						Size = UDim2.new(0.48, 0, 1, 0),
						BackgroundColor3 = colorTargetPlayer == "Self" and Color3.fromRGB(30, 45, 60) or Color3.fromRGB(25, 25, 30),
						TextColor3 = colorTargetPlayer == "Self" and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(150, 150, 160),
						Font = Enum.Font.GothamBold,
						TextSize = 9,
						[Event.Activated] = function()
							setColorTargetPlayer("Self")
						end,
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
					SpecificBtn = e("TextButton", {
						Text = "🔍 SPESIFIK NAMA",
						Size = UDim2.new(0.48, 0, 1, 0),
						BackgroundColor3 = colorTargetPlayer == "Specific" and Color3.fromRGB(30, 45, 60) or Color3.fromRGB(25, 25, 30),
						TextColor3 = colorTargetPlayer == "Specific" and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(150, 150, 160),
						Font = Enum.Font.GothamBold,
						TextSize = 9,
						[Event.Activated] = function()
							setColorTargetPlayer("Specific")
						end,
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
				}),
			}),

			-- Specific Player Input (Conditional)
			SpecificPlayerInput = colorTargetPlayer == "Specific" and e("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = Color3.fromRGB(20, 20, 26),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
				Input = e("TextBox", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					PlaceholderText = "Ketik username/display name pemain...",
					Text = colorTargetName,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					PlaceholderColor3 = Color3.fromRGB(120, 120, 130),
					Font = Enum.Font.GothamMedium,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Left,
					[Change.Text] = function(rbx: TextBox)
						setColorTargetName(rbx.Text)
					end,
				}),
			}) or nil,

			-- Preset Color Grid
			PresetCard = e("Frame", {
				Size = UDim2.new(1, 0, 0, 150),
				BackgroundColor3 = Color3.fromRGB(20, 20, 26),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Padding = e("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
				Title = e("TextLabel", {
					Text = "🎨 PALET WARNA PRESET",
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(0, 220, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 9,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Grid = e("Frame", {
					Size = UDim2.new(1, 0, 0, 120),
					Position = UDim2.new(0, 0, 0, 20),
					BackgroundTransparency = 1,
				}, (function()
					local gridChildren = table.clone(presetButtons)
					gridChildren.List = e("UIGridLayout", {
						CellSize = UDim2.new(0.48, 0, 0, 26),
						CellPadding = UDim2.new(0.04, 0, 0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
					})
					return gridChildren
				end)()),
			}),

			-- Custom Hex Input & Action Button
			CustomHexCard = e("Frame", {
				Size = UDim2.new(1, 0, 0, 85),
				BackgroundColor3 = Color3.fromRGB(20, 20, 26),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Padding = e("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
				Title = e("TextLabel", {
					Text = "⚙️ CUSTOM HEX CODE",
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(0, 220, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 9,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				HexContainer = e("Frame", {
					Size = UDim2.new(1, 0, 0, 30),
					Position = UDim2.new(0, 0, 0, 20),
					BackgroundTransparency = 1,
				}, {
					Input = e("TextBox", {
						Size = UDim2.new(0.6, 0, 1, 0),
						BackgroundColor3 = Color3.fromRGB(28, 28, 35),
						Text = customHexInput,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						Font = Enum.Font.GothamBold,
						TextSize = 10,
						BorderSizePixel = 0,
						[Change.Text] = function(rbx: TextBox)
							setCustomHexInput(rbx.Text)
							setSelectedHexColor(rbx.Text)
						end,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
					}),
					Preview = e("Frame", {
						Size = UDim2.new(0.36, 0, 1, 0),
						Position = UDim2.new(0.64, 0, 0, 0),
						BackgroundColor3 = (function()
							local c = nil
							pcall(function()
								c = Color3.fromHex(selectedHexColor)
							end)
							return c or Color3.fromRGB(150, 150, 150)
						end)(),
						BorderSizePixel = 0,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
						Label = e("TextLabel", {
							Size = UDim2.new(1, 0, 1, 0),
							BackgroundTransparency = 1,
							Text = "PREVIEW",
							TextColor3 = Color3.fromRGB(0, 0, 0),
							Font = Enum.Font.GothamBold,
							TextSize = 9,
						}),
					}),
				}),
				ApplyBtn = e("TextButton", {
					Text = "✨ SIMPAN & TERAPKAN WARNA NAMA",
					Size = UDim2.new(1, 0, 0, 26),
					Position = UDim2.new(0, 0, 0, 54),
					BackgroundColor3 = Color3.fromRGB(0, 170, 120),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 9.5,
					BorderSizePixel = 0,
					[Event.Activated] = handleApplyColor,
				}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
			}),
		})
	end

	-- 10. MAIN PANEL RENDER (RESPONSIVE WRAPPER)
	return e("Frame", {
		Size = props.IsMobile and UDim2.new(1, 0, 1, 0) or UDim2.new(1, 0, 1, 0),
		-- Size = props.IsMobile and UDim2.new(1, 0, 1, -80) or UDim2.new(1, 0, 1, -100),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 0.55,
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		Active = true,
		-- ZIndex = 20,
	}, {
		Container = e("Frame", {
			Size = isMobile and UDim2.new(0.82, 0, 0.82, 0) or UDim2.new(0.9, 0, 0.9, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(15, 15, 20),
			BorderSizePixel = 1,
			BorderColor3 = Color3.fromRGB(45, 45, 55),
			-- ZIndex = 21,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			SizeConstraint = e("UISizeConstraint", {
				MaxSize = isMobile and Vector2.new(9999, 9999) or Vector2.new(880, 520),
			}),

			-- HEADER
			Header = e("Frame", {
				Size = UDim2.new(1, 0, 0, 45),
				BackgroundColor3 = Color3.fromRGB(22, 22, 28),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Title = e("TextLabel", {
					Text = isMobile and "⚙️ ADMIN EVENT" or "⚙️ ADMIN EVENT SYSTEM",
					Size = UDim2.new(0.35, 0, 1, 0),
					Position = UDim2.new(0, 15, 0, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 13,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				-- TAB CONTROL CONTAINER
				Tabs = e("Frame", {
					Size = isMobile and UDim2.new(0.55, 0, 0.7, 0) or UDim2.new(0.5, 0, 0.65, 0),
					Position = isMobile and UDim2.new(0.38, 0, 0.5, -10) or UDim2.new(0.38, 0, 0.5, -12),
					BackgroundTransparency = 1,
				}, {
					List = e(
						"UIListLayout",
						{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }
					),
					Tab1 = createTabBtn("Multipliers", isMobile and "Boost" or "Boosts", "🚀"),
					Tab2 = createTabBtn("Broadcast", isMobile and "Banner" or "Banners", "📢"),
					Tab3 = createTabBtn("Gifts", isMobile and "Hadiah" or "Hadiah", "🎁"),
					Tab4 = createTabBtn("NameColor", isMobile and "Warna" or "Warna Nama", "🎨"),
				}),

				CloseBtn = e("TextButton", {
					Text = "X",
					Size = UDim2.fromOffset(24, 24),
					Position = UDim2.new(1, -15, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 35, 85),
					BackgroundTransparency = 0.1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					AutoButtonColor = true,
					[Event.Activated] = function()
						if props.onClose then
							props.onClose()
						end
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
					Stroke = e("UIStroke", {
						Color = Color3.fromRGB(255, 100, 120),
						Thickness = 0.8,
					}),
				}),
			}),

			-- MAIN BODY CONTAINER (RESPONSIVE INNER FRAME)
			Body = e("Frame", {
				Size = UDim2.new(1, -30, 1, -65),
				Position = UDim2.new(0, 15, 0, 55),
				BackgroundTransparency = 1,
			}, {
				ActiveContent = (function()
					if activeTab == "Multipliers" then
						return renderMultipliersTab()
					elseif activeTab == "Broadcast" then
						return renderBroadcastTab()
					elseif activeTab == "Gifts" then
						return renderGiftsTab()
					elseif activeTab == "NameColor" then
						return renderNameColorTab()
					end
					return nil
				end)(),
			}),
		}),
	})
end

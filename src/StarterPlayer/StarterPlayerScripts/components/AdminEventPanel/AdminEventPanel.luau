local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect

return function(props)
	-- 1. LOCAL STATE FOR SLIDERS/INPUTS (PENDING CHANGES)
	local luckInput, setLuckInput = useState(0)
	local expInput, setExpInput = useState(0)
	local speedInput, setSpeedInput = useState(0)
	local variantInput, setVariantInput = useState(0)

	local goldenInput, setGoldenInput = useState(0)
	local rainbowInput, setRainbowInput = useState(0)
	local galaxyInput, setGalaxyInput = useState(0)
	local hellfireInput, setHellfireInput = useState(0)

	local isAccordionOpen, setIsAccordionOpen = useState(false)

	-- 2. LIVE VALUES STATE (REAL-TIME SERVER VALUES)
	local liveLuck, setLiveLuck = useState(0)
	local liveExp, setLiveExp = useState(0)
	local liveSpeed, setLiveSpeed = useState(0)
	local liveVariant, setLiveVariant = useState(0)
	local liveGolden, setLiveGolden = useState(0)
	local liveRainbow, setLiveRainbow = useState(0)
	local liveGalaxy, setLiveGalaxy = useState(0)
	local liveHellfire, setLiveHellfire = useState(0)

	-- 3. LISTEN TO SERVER CHANGES IN REPLICATEDSTORAGE (REAL-TIME SYNC)
	useEffect(function()
		local liveEvents = ReplicatedStorage:WaitForChild("LiveEvents", 10)
		if not liveEvents then return end

		local function syncValues()
			local luckNode = liveEvents:FindFirstChild("LuckyChanceBoost")
			local expNode = liveEvents:FindFirstChild("ExpBoost")
			local variantNode = liveEvents:FindFirstChild("VariantBoost")
			local speedVal = ReplicatedStorage:GetAttribute("SpeedBoost") or 0

			local goldenNode = liveEvents:FindFirstChild("VariantBoost_Golden")
			local rainbowNode = liveEvents:FindFirstChild("VariantBoost_Rainbow")
			local galaxyNode = liveEvents:FindFirstChild("VariantBoost_Galaxy")
			local hellfireNode = liveEvents:FindFirstChild("VariantBoost_Hellfire")

			setLiveLuck(luckNode and luckNode.Value or 0)
			setLiveExp(expNode and expNode.Value or 0)
			setLiveVariant(variantNode and variantNode.Value or 0)
			setLiveSpeed(speedVal)

			setLiveGolden(goldenNode and goldenNode.Value or 0)
			setLiveRainbow(rainbowNode and rainbowNode.Value or 0)
			setLiveGalaxy(galaxyNode and galaxyNode.Value or 0)
			setLiveHellfire(hellfireNode and hellfireNode.Value or 0)
		end

		-- Sync Nilai Awal
		syncValues()

		-- Hubungkan Event Listener
		local connections = {}
		local nodes = {
			"LuckyChanceBoost", "ExpBoost", "VariantBoost",
			"VariantBoost_Golden", "VariantBoost_Rainbow",
			"VariantBoost_Galaxy", "VariantBoost_Hellfire"
		}

		for _, name in ipairs(nodes) do
			local node = liveEvents:FindFirstChild(name)
			if node then
				table.insert(connections, node.Changed:Connect(syncValues))
			else
				-- Jika node dibuat terlambat
				table.insert(connections, liveEvents.ChildAdded:Connect(function(child)
					if child.Name == name then
						syncValues()
						table.insert(connections, child.Changed:Connect(syncValues))
					end
				end))
			end
		end

		table.insert(connections, ReplicatedStorage:GetAttributeChangedSignal("SpeedBoost"):Connect(syncValues))

		-- Cleanup Connection saat Unmount
		return function()
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
		end
	end, {})

	-- 4. HANDLERS
	local function handleApply()
		if props.onApplySettings then
			props.onApplySettings({
				LuckBoost = luckInput,
				ExpBoost = expInput,
				SpeedBoost = speedInput,
				VariantBoost = variantInput,
				VariantBoost_Golden = goldenInput,
				VariantBoost_Rainbow = rainbowInput,
				VariantBoost_Galaxy = galaxyInput,
				VariantBoost_Hellfire = hellfireInput,
			})
		end
	end

	local function handleStopAll()
		if props.onStopAll then
			props.onStopAll()
		end
	end

	local function applyPreset(presetName)
		if presetName == "DoubleEXP" then
			setLuckInput(0)
			setExpInput(100)
			setSpeedInput(0)
			setVariantInput(0)
			setGoldenInput(0)
			setRainbowInput(0)
			setGalaxyInput(0)
			setHellfireInput(0)
			if props.onApplySettings then
				props.onApplySettings({
					LuckBoost = 0, ExpBoost = 100, SpeedBoost = 0, VariantBoost = 0,
					VariantBoost_Golden = 0, VariantBoost_Rainbow = 0, VariantBoost_Galaxy = 0, VariantBoost_Hellfire = 0
				})
			end
		elseif presetName == "LuckyHype" then
			setLuckInput(200)
			setExpInput(0)
			setSpeedInput(0)
			setVariantInput(10)
			setGoldenInput(0)
			setRainbowInput(0)
			setGalaxyInput(0)
			setHellfireInput(0)
			if props.onApplySettings then
				props.onApplySettings({
					LuckBoost = 200, ExpBoost = 0, SpeedBoost = 0, VariantBoost = 10,
					VariantBoost_Golden = 0, VariantBoost_Rainbow = 0, VariantBoost_Galaxy = 0, VariantBoost_Hellfire = 0
				})
			end
		elseif presetName == "WeekendBoost" then
			setLuckInput(150)
			setExpInput(150)
			setSpeedInput(10)
			setVariantInput(20)
			setGoldenInput(0)
			setRainbowInput(0)
			setGalaxyInput(0)
			setHellfireInput(0)
			if props.onApplySettings then
				props.onApplySettings({
					LuckBoost = 150, ExpBoost = 150, SpeedBoost = 10, VariantBoost = 20,
					VariantBoost_Golden = 0, VariantBoost_Rainbow = 0, VariantBoost_Galaxy = 0, VariantBoost_Hellfire = 0
				})
			end
		end
	end

	-- 5. RENDERING DENGAN LAYOUT RESPONSIF
	local function createSliderRow(label, min, max, value, setValue)
		return e("Frame", {
			Size = UDim2.new(1, 0, 0, 35),
			BackgroundTransparency = 1,
		}, {
			Label = e("TextLabel", {
				Text = label,
				Size = UDim2.new(0.3, 0, 1, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(240, 240, 240),
				TextSize = 11,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = true,
			}),

			-- Manual Input Box
			InputBox = e("TextBox", {
				Text = tostring(value),
				Size = UDim2.new(0, 50, 0, 25),
				Position = UDim2.new(0.32, 0, 0.5, -12),
				BackgroundColor3 = Color3.fromRGB(30, 30, 40),
				TextColor3 = Color3.fromRGB(0, 255, 204),
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				[React.Event.FocusLost] = function(box)
					local val = tonumber(box.Text) or 0
					local clamped = math.clamp(val, min, max)
					setValue(clamped)
					box.Text = tostring(clamped)
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			}),

			-- Slider Bar
			SliderBg = e("TextButton", {
				Text = "",
				Size = UDim2.new(0.55, -60, 0, 8),
				Position = UDim2.new(0.45, 0, 0.5, -4),
				BackgroundColor3 = Color3.fromRGB(25, 25, 30),
				BorderSizePixel = 0,
				[React.Event.Activated] = function(btn, input)
					-- Logic Klik/Geser Slider sederhana
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
					BackgroundColor3 = Color3.fromRGB(0, 130, 255),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				})
			})
		})
	end

	return e("Frame", {
		Size = UDim2.new(0.85, 0, 0.85, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(18, 18, 24),
		BorderSizePixel = 1,
		BorderColor3 = Color3.fromRGB(45, 45, 55),
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
		SizeConstraint = e("UISizeConstraint", {
			MinSize = Vector2.new(580, 320),
			MaxSize = Vector2.new(820, 470),
		}),

		-- HEADER
		Header = e("Frame", {
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundColor3 = Color3.fromRGB(24, 24, 32),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Title = e("TextLabel", {
				Text = "⚙️ EVENT MANAGEMENT PANEL",
				Size = UDim2.new(0.6, 0, 1, 0),
				Position = UDim2.new(0, 20, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 15,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			CloseBtn = e("TextButton", {
				Text = "✕",
				Size = UDim2.new(0, 32, 0, 32),
				Position = UDim2.new(1, -42, 0.5, -16),
				BackgroundColor3 = Color3.fromRGB(50, 50, 60),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				BorderSizePixel = 0,
				[React.Event.Activated] = function()
					if props.onClose then props.onClose() end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
			})
		}),

		-- LEFT PANEL (CONTROLS)
		Controls = e("Frame", {
			Size = UDim2.new(0.56, 0, 1, -65),
			Position = UDim2.new(0.02, 0, 0, 55),
			BackgroundTransparency = 1,
		}, {
			List = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 8),
			}),

			Luck = createSliderRow("🍀 Luck Boost (0-500%)", 0, 500, luckInput, setLuckInput),
			Exp = createSliderRow("🆙 Exp Boost (0-500%)", 0, 500, expInput, setExpInput),
			Speed = createSliderRow("⚡ Speed Boost (0-100%)", 0, 100, speedInput, setSpeedInput),
			Variant = createSliderRow("🌟 Global Variant (0-100%)", 0, 100, variantInput, setVariantInput),

			-- ACCORDION TRIGGER FOR SPECIFIC VARIANT BOOST
			AccordionBtn = e("TextButton", {
				Text = (isAccordionOpen and "▼ Sembunyikan Varian Khusus" or "▶ Tampilkan Varian Khusus"),
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = Color3.fromRGB(30, 30, 38),
				TextColor3 = Color3.fromRGB(200, 200, 210),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				BorderSizePixel = 0,
				[React.Event.Activated] = function()
					setIsAccordionOpen(not isAccordionOpen)
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),

			-- ACCORDION CONTENT
			AccordionFrame = isAccordionOpen and e("Frame", {
				Size = UDim2.new(1, 0, 0, 120),
				BackgroundTransparency = 1,
			}, {
				List = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 6),
				}),
				Golden = createSliderRow("🔱 Golden Boost (0-50%)", 0, 50, goldenInput, setGoldenInput),
				Rainbow = createSliderRow("🌈 Rainbow Boost (0-50%)", 0, 50, rainbowInput, setRainbowInput),
				Galaxy = createSliderRow("🌌 Galaxy Boost (0-50%)", 0, 50, galaxyInput, setGalaxyInput),
				Hellfire = createSliderRow("🔥 Hellfire Boost (0-50%)", 0, 50, hellfireInput, setHellfireInput),
			}) or nil,

			-- Tombol Eksekusi
			ActionContainer = e("Frame", {
				Size = UDim2.new(1, 0, 0, 45),
				BackgroundTransparency = 1,
			}, {
				List = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 10),
				}),

				Apply = e("TextButton", {
					Text = "TERAPKAN PERUBAHAN",
					Size = UDim2.new(0.58, 0, 1, 0),
					BackgroundColor3 = Color3.fromRGB(0, 170, 110),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					BorderSizePixel = 0,
					TextScaled = true,
					[React.Event.Activated] = handleApply,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),

				Stop = e("TextButton", {
					Text = "MATIKAN EVENT",
					Size = UDim2.new(0.38, 0, 1, 0),
					BackgroundColor3 = Color3.fromRGB(190, 45, 45),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					BorderSizePixel = 0,
					TextScaled = true,
					[React.Event.Activated] = handleStopAll,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				})
			})
		}),

		-- RIGHT PANEL (STATUS MONITOR & PRESETS)
		StatusPanel = e("Frame", {
			Size = UDim2.new(0.38, 0, 1, -65),
			Position = UDim2.new(0.6, 0, 0, 55),
			BackgroundColor3 = Color3.fromRGB(23, 23, 30),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
			}),

			List = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 8),
			}),

			MonitorTitle = e("TextLabel", {
				Text = "LIVE STATUS MONITOR",
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 11,
				Font = Enum.Font.GothamBold,
			}),

			-- Live Stats Monitor
			StatsBox = e("Frame", {
				Size = UDim2.new(1, 0, 0, 95),
				BackgroundColor3 = Color3.fromRGB(15, 15, 20),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 4) }),
				List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 2) }),

				LuckText = e("TextLabel", {
					Text = string.format("🍀 Luck Active: <font color='#00FF88'>%d%%</font>", liveLuck),
					Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(230, 230, 230),
					TextSize = 9, Font = Enum.Font.GothamBold, RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
				}),
				ExpText = e("TextLabel", {
					Text = string.format("🆙 Exp Active: <font color='#00FF88'>+%d%%</font>", liveExp),
					Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(230, 230, 230),
					TextSize = 9, Font = Enum.Font.GothamBold, RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
				}),
				SpeedText = e("TextLabel", {
					Text = string.format("⚡ Speed Active: <font color='#00FF88'>%d%%</font>", liveSpeed),
					Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(230, 230, 230),
					TextSize = 9, Font = Enum.Font.GothamBold, RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
				}),
				VariantText = e("TextLabel", {
					Text = string.format("🌟 Global Variant: <font color='#00FF88'>%d%%</font>", liveVariant),
					Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(230, 230, 230),
					TextSize = 9, Font = Enum.Font.GothamBold, RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
				}),
				SpecVariantText = e("TextLabel", {
					Text = string.format("🔱G:%d%% | 🌈R:%d%% | 🌌Gx:%d%% | 🔥H:%d%%", liveGolden, liveRainbow, liveGalaxy, liveHellfire),
					Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(200, 200, 200),
					TextSize = 8, Font = Enum.Font.GothamBold, RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),

			PresetTitle = e("TextLabel", {
				Text = "PRESET EVENT INSTAN",
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 11,
				Font = Enum.Font.GothamBold,
			}),

			-- Preset Buttons
			PresetDoubleExp = e("TextButton", {
				Text = "🔥 DOUBLE EXP (+100%)",
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = Color3.fromRGB(45, 45, 55),
				TextColor3 = Color3.fromRGB(0, 255, 204),
				Font = Enum.Font.GothamBold,
				TextSize = 9,
				BorderSizePixel = 0,
				TextScaled = true,
				[React.Event.Activated] = function() applyPreset("DoubleEXP") end,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),

			PresetLuckyHype = e("TextButton", {
				Text = "🍀 LUCKY HYPE (+200% L, +10% V)",
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = Color3.fromRGB(45, 45, 55),
				TextColor3 = Color3.fromRGB(0, 255, 204),
				Font = Enum.Font.GothamBold,
				TextSize = 9,
				BorderSizePixel = 0,
				TextScaled = true,
				[React.Event.Activated] = function() applyPreset("LuckyHype") end,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),

			PresetWeekend = e("TextButton", {
				Text = "🎉 WEEKEND BOOST (ALL BOOST)",
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = Color3.fromRGB(45, 45, 55),
				TextColor3 = Color3.fromRGB(200, 150, 50),
				Font = Enum.Font.GothamBold,
				TextSize = 9,
				BorderSizePixel = 0,
				TextScaled = true,
				[React.Event.Activated] = function() applyPreset("WeekendBoost") end,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
		})
	})
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage.Packages.React)
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect

local player = Players.LocalPlayer

local function CustomStats(props: { IsMobile: boolean })
	-- State untuk statistik player
	local cashVal, setCashVal = useState(0)
	local rebirthVal, setRebirthVal = useState(0)
	local rebirthPoints, setRebirthPoints = useState(0)

	-- State untuk buff event yang berjalan
	local luckBoost, setLuckBoost = useState(0)
	local expBoost, setExpBoost = useState(0)
	local variantBoost, setVariantBoost = useState(0)
	local speedBoost, setSpeedBoost = useState(0)
	local goldenBoost, setGoldenBoost = useState(0)
	local rainbowBoost, setRainbowBoost = useState(0)
	local galaxyBoost, setGalaxyBoost = useState(0)
	local hellfireBoost, setHellfireBoost = useState(0)

	-- State tooltip yang sedang aktif dibuka
	local activeTooltip, setActiveTooltip = useState(nil :: string?)

	-- ===== 1. SINKRONISASI STATISTIK PLAYER =====
	useEffect(function()
		local leaderstats = player:WaitForChild("leaderstats", 15)
		local connections: { RBXScriptConnection } = {}

		if leaderstats then
			local cashObj = leaderstats:FindFirstChild("Cash") :: IntValue?
			if cashObj then
				setCashVal(cashObj.Value)
				table.insert(connections, cashObj.Changed:Connect(function(val)
					setCashVal(val)
				end))
			end

			local rebirthObj = leaderstats:FindFirstChild("Rebirth") :: IntValue?
			if rebirthObj then
				setRebirthVal(rebirthObj.Value)
				table.insert(connections, rebirthObj.Changed:Connect(function(val)
					setRebirthVal(val)
				end))
			end
		end

		setRebirthPoints(player:GetAttribute("RebirthPoints") or 0)
		table.insert(connections, player:GetAttributeChangedSignal("RebirthPoints"):Connect(function()
			setRebirthPoints(player:GetAttribute("RebirthPoints") or 0)
		end))

		return function()
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
		end
	end, {})

	-- ===== 2. SINKRONISASI ACTIVE BUFFS =====
	useEffect(function()
		local liveEvents = ReplicatedStorage:WaitForChild("LiveEvents", 10)
		local connections: { RBXScriptConnection } = {}

		local function syncBuffs()
			if not liveEvents then return end
			local luckObj = liveEvents:FindFirstChild("LuckyChanceBoost") :: IntValue?
			local expObj = liveEvents:FindFirstChild("ExpBoost") :: IntValue?
			local varObj = liveEvents:FindFirstChild("VariantBoost") :: IntValue?
			local gldObj = liveEvents:FindFirstChild("VariantBoost_Golden") :: IntValue?
			local rnbObj = liveEvents:FindFirstChild("VariantBoost_Rainbow") :: IntValue?
			local glxObj = liveEvents:FindFirstChild("VariantBoost_Galaxy") :: IntValue?
			local hlfObj = liveEvents:FindFirstChild("VariantBoost_Hellfire") :: IntValue?

			setLuckBoost(luckObj and luckObj.Value or 0)
			setExpBoost(expObj and expObj.Value or 0)
			setVariantBoost(varObj and varObj.Value or 0)
			setGoldenBoost(gldObj and gldObj.Value or 0)
			setRainbowBoost(rnbObj and rnbObj.Value or 0)
			setGalaxyBoost(glxObj and glxObj.Value or 0)
			setHellfireBoost(hlfObj and hlfObj.Value or 0)
			setSpeedBoost(ReplicatedStorage:GetAttribute("SpeedBoost") or 0)
		end

		syncBuffs()

		if liveEvents then
			local nodes = {
				"LuckyChanceBoost", "ExpBoost", "VariantBoost",
				"VariantBoost_Golden", "VariantBoost_Rainbow",
				"VariantBoost_Galaxy", "VariantBoost_Hellfire"
			}
			for _, name in ipairs(nodes) do
				local node = liveEvents:FindFirstChild(name)
				if node then
					table.insert(connections, (node :: any).Changed:Connect(syncBuffs))
				end
			end
			table.insert(connections, liveEvents.ChildAdded:Connect(function(child)
				if table.find(nodes, child.Name) then
					syncBuffs()
					table.insert(connections, (child :: any).Changed:Connect(syncBuffs))
				end
			end))
		end

		table.insert(connections, ReplicatedStorage:GetAttributeChangedSignal("SpeedBoost"):Connect(syncBuffs))

		return function()
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
		end
	end, {})

	-- Definisi data buff untuk iterasi render
	local buffConfigs = {
		{ Key = "Luck", Name = "Luck Boost", Icon = "🍀", Value = luckBoost, Description = "Meningkatkan peluang keberuntungan saat membuka kotak (Box)." },
		{ Key = "Exp", Name = "EXP Boost", Icon = "🆙", Value = expBoost, Description = "Meningkatkan jumlah Experience (EXP) yang diperoleh oleh Box." },
		{ Key = "Variant", Name = "Variant Boost", Icon = "🌟", Value = variantBoost, Description = "Meningkatkan peluang mendapatkan varian mobil langka secara global." },
		{ Key = "Speed", Name = "Speed Boost", Icon = "⚡", Value = speedBoost, Description = "Meningkatkan kecepatan dasar berjalan kaki pemain." },
		{ Key = "Golden", Name = "Golden Boost", Icon = "🔱", Value = goldenBoost, Description = "Meningkatkan peluang mendapatkan mobil varian Golden." },
		{ Key = "Rainbow", Name = "Rainbow Boost", Icon = "🌈", Value = rainbowBoost, Description = "Meningkatkan peluang mendapatkan mobil varian Rainbow." },
		{ Key = "Galaxy", Name = "Galaxy Boost", Icon = "🌌", Value = galaxyBoost, Description = "Meningkatkan peluang mendapatkan mobil varian Galaxy." },
		{ Key = "Hellfire", Name = "Hellfire Boost", Icon = "🔥", Value = hellfireBoost, Description = "Meningkatkan peluang mendapatkan mobil varian Hellfire." },
	}

	-- Render Barisan Buff
	local activeBuffElements = {}
	local activeBuffCount = 0

	for _, config in ipairs(buffConfigs) do
		if config.Value > 0 then
			activeBuffCount += 1
			activeBuffElements[config.Key] = e("TextButton", {
				Size = UDim2.new(0, 48, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				LayoutOrder = activeBuffCount,
				[React.Event.Activated] = function()
					if activeTooltip == config.Key then
						setActiveTooltip(nil)
					else
						setActiveTooltip(config.Key)
					end
				end,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 2),
				}),
				Icon = e("TextLabel", {
					Text = config.Icon,
					Size = UDim2.fromOffset(24, 24),
					BackgroundTransparency = 1,
					TextSize = 20,
					LayoutOrder = 1,
				}),
				Value = e("TextLabel", {
					Text = "+" .. tostring(config.Value) .. "%",
					Size = UDim2.new(1, 0, 0, 12),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(0, 255, 204),
					TextSize = 9,
					Font = Enum.Font.GothamBold,
					LayoutOrder = 2,
				}),
			})
		end
	end

	-- Cari tooltip yang aktif untuk ditampilkan
	local tooltipElement = nil
	if activeTooltip then
		for _, config in ipairs(buffConfigs) do
			if config.Key == activeTooltip then
				tooltipElement = e("TextButton", {
					Size = UDim2.new(0, 200, 0, 45),
					Position = UDim2.new(1, 0, 1, 5),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundColor3 = Color3.fromRGB(15, 15, 20),
					BorderSizePixel = 0,
					ZIndex = 50,
					[React.Event.Activated] = function()
						setActiveTooltip(nil)
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
					Stroke = e("UIStroke", { Color = Color3.fromRGB(100, 50, 250), Thickness = 1 }),
					Padding = e("UIPadding", {
						PaddingTop = UDim.new(0, 5),
						PaddingBottom = UDim.new(0, 5),
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
					}),
					Text = e("TextLabel", {
						Text = `<b>{config.Name}</b>\n{config.Description}`,
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(240, 240, 240),
						TextSize = 9,
						Font = Enum.Font.Gotham,
						TextWrapped = true,
						RichText = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
					})
				})
				break
			end
		end
	end

	return e("Frame", {
		Size = UDim2.new(0, 220, 0, 160),
		Position = UDim2.new(1, -10, 0, 10),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),

		-- KARTU UTAMA STATISTIK
		StatsCard = e("Frame", {
			Size = UDim2.new(1, 0, 0, 95),
			BackgroundColor3 = Color3.fromRGB(15, 15, 20),
			BackgroundTransparency = 0.35,
			LayoutOrder = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", { Color = Color3.fromRGB(70, 70, 85), Thickness = 1 }),
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			List = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),

			-- Row 1: Cash
			CashRow = e("TextLabel", {
				Text = "💵  $ " .. GameUtils.formatCompact(cashVal),
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(0, 255, 120),
				TextSize = 13,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}),

			-- Row 2: Rebirth Points
			PointsRow = e("TextLabel", {
				Text = "✨  " .. GameUtils.formatCompact(rebirthPoints) .. " RP",
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(0, 220, 255),
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
			}),

			-- Row 3: Rebirth Level
			RebirthRow = e("TextLabel", {
				Text = "🔄  Rebirth " .. tostring(rebirthVal),
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(240, 160, 50),
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 3,
			}),
		}),

		-- KARTU BUFF AKTIF (Hanya tampil jika ada buff aktif)
		BuffsContainer = (activeBuffCount > 0) and e("Frame", {
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}, (function()
			local buffsChildren = {
				List = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
				}),
				TooltipOverlay = tooltipElement,
			}
			for name, element in pairs(activeBuffElements) do
				buffsChildren[name] = element
			end
			return buffsChildren
		end)()) or nil,
	})
end

return CustomStats

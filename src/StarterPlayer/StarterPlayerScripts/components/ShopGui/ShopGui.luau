local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local React = require(ReplicatedStorage.Packages.React)
local Networker = require(ReplicatedStorage.Packages.Networker)
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local ViewportManager = require(script.Parent.Parent:WaitForChild("ViewportManager"))

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

local player = Players.LocalPlayer

-- ===== DUMMY TOOLS CACHE FOR 3D SHOP VISUALS =====
local dummyToolsCache = {}

local function getOrCreateDummyTool(item)
	if dummyToolsCache[item.Level] then
		return dummyToolsCache[item.Level]
	end

	local dummyTool = Instance.new("Tool")
	dummyTool.Name = item.Name
	dummyTool:SetAttribute("Level", item.Level)
	dummyTool:SetAttribute("Type", "Box")

	local BoxModels = ReplicatedStorage:FindFirstChild("BoxModels")
	if BoxModels then
		local targetModelName = "Level" .. tostring(item.Level)
		local modelTemplate = BoxModels:FindFirstChild(targetModelName)
		if not modelTemplate then
			-- Fallback to Level1 if not found
			modelTemplate = BoxModels:FindFirstChild("Level1")
		end
		if modelTemplate then
			local modelClone = modelTemplate:Clone()
			modelClone.Name = "Model"
			modelClone.Parent = dummyTool
		end
	end

	dummyToolsCache[item.Level] = dummyTool
	return dummyTool
end

-- ===== TOAST STATE COMPONENT FOR FEEDBACK =====
local function ToastComponent(props)
	local show, setShow = useState(true)
	
	useEffect(function()
		local timer = task.delay(props.duration or 3, function()
			setShow(false)
			task.delay(0.3, function()
				if props.onFinished then
					props.onFinished(props.id)
				end
			end)
		end)
		return function()
			task.cancel(timer)
		end
	end, {})

	if not show then return nil end

	return e("Frame", {
		Size = UDim2.new(0, 280, 0, 50),
		BackgroundColor3 = props.isSuccess and Color3.fromRGB(30, 130, 70) or Color3.fromRGB(150, 40, 40),
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		TextLabel = e("TextLabel", {
			Text = props.message,
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			TextWrapped = true,
		})
	})
end

-- ===== CORE SHOP COMPONENT =====
local function ShopGui(props)
	local isStorybook = props.isStorybook or props.IsStorybook or false
	local activeTab, setActiveTab = useState("Items")
	local toasts, setToasts = useState({})
	
	local cache = useRef(nil)
	if not cache.current then
		cache.current = ViewportManager.new()
	end
	
	-- Pemantauan Ukuran Layar untuk Responsivitas
	local viewportSize, setViewportSize = useState(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600))
	useEffect(function()
		local connection: RBXScriptConnection? = nil
		local function setupCamera(cam: Camera?)
			if connection then connection:Disconnect() connection = nil end
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
			if connection then connection:Disconnect() end
			camConnection:Disconnect()
		end
	end, {})
	
	local isMobile = viewportSize.X < 650 or viewportSize.Y < 500
	
	-- Saldo RPM Tokens & Cash Ter-sinkronisasi Otomatis
	local rpmTokens, setRpmTokens = useState(0)
	local cash, setCash = useState(0)
	
	useEffect(function()
		if isStorybook then
			setRpmTokens(25)
			setCash(15000)
			return
		end
		
		local function setupLeaderstats(leaderstats)
			if not leaderstats then return end
			
			local tokenObj = leaderstats:WaitForChild("RPM Tokens") :: IntValue?
			local cashObj = leaderstats:WaitForChild("Cash") :: IntValue?
			
			local tokenConn, cashConn
			if tokenObj then
				tokenConn = tokenObj.Changed:Connect(function(val) setRpmTokens(val) end)
				setRpmTokens(tokenObj.Value)
			end
			if cashObj then
				cashConn = cashObj.Changed:Connect(function(val) setCash(val) end)
				setCash(cashObj.Value)
			end
			
			return function()
				if tokenConn then tokenConn:Disconnect() end
				if cashConn then cashConn:Disconnect() end
			end
		end
		
		local leaderstats = player:FindFirstChild("leaderstats")
		local cleanup
		if leaderstats then
			cleanup = setupLeaderstats(leaderstats)
		else
			local conn
			conn = player.ChildAdded:Connect(function(child)
				if child.Name == "leaderstats" then
					cleanup = setupLeaderstats(child)
					conn:Disconnect()
				end
			end)
		end
		
		return function()
			if cleanup then cleanup() end
			if cache.current then
				ViewportManager.clearAllCache(cache.current)
			end
		end
	end, {})
	
	-- Networker Client
	local networker = useState(function()
		if isStorybook then return nil end
		return Networker.client.new("ShopGui", {})
	end)
	
	-- Toast Helper
	local function showToast(message: string, isSuccess: boolean)
		local id = tostring(os.clock()) .. tostring(math.random())
		setToasts(function(prev)
			local copy = table.clone(prev)
			copy[id] = { message = message, isSuccess = isSuccess }
			return copy
		end)
	end
	
	local function removeToast(id)
		setToasts(function(prev)
			local copy = table.clone(prev)
			copy[id] = nil
			return copy
		end)
	end
	
	-- Handler Beli dengan RPM Tokens
	local function handleBuyCrateWithTokens(crateLevel)
		if isStorybook then
			showToast("Simulator: Berhasil membeli crate!", true)
			return
		end
		
		local result = networker:fetch("buyBox", crateLevel)
		if result and result.Success then
			showToast("✅ " .. result.Message, true)
		else
			local errorMsg = result and result.Error or "Pembelian gagal"
			showToast("❌ " .. errorMsg, false)
		end
	end
	
	-- Handler Beli dengan Robux
	local function handleBuyCrateWithRobux(productId)
		if isStorybook then
			showToast("Simulator: Menampilkan prompt pembelian Robux...", true)
			return
		end
		MarketplaceService:PromptProductPurchase(player, productId)
	end
	
	-- Handler Beli Gamepass
	local function handleBuyGamepass(passId)
		if isStorybook then
			showToast("Simulator: Menampilkan prompt Gamepass...", true)
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end
	
	-- ===== RENDER CARDS =====
	local function buildListChildren()
		local children = {
			UIGridLayout = e("UIGridLayout", {
				CellSize = isMobile and UDim2.new(0, 135, 0, 195) or UDim2.new(0, 155, 0, 220),
				CellPadding = UDim2.new(0, 8, 0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),
		}
		
		if activeTab == "Items" then
			for i, item in ipairs(ShopConfig.Items) do
				children["Item_" .. i] = e("Frame", {
					BackgroundColor3 = Color3.fromRGB(24, 24, 30),
					BorderColor3 = Color3.fromRGB(50, 50, 60),
					BorderSizePixel = 1,
					LayoutOrder = i,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					
					-- Judul Box
					Title = e("TextLabel", {
						Text = item.Name,
						Size = UDim2.new(1, -10, 0, 24),
						Position = UDim2.new(0, 5, 0, 6),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = isMobile and 9 or 11,
						Font = Enum.Font.GothamBold,
						TextWrapped = true,
					}),
					
					-- Deskripsi
					Desc = e("TextLabel", {
						Text = item.Description,
						Size = UDim2.new(1, -12, 0, 30),
						Position = UDim2.new(0, 6, 0, 30),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(150, 150, 160),
						TextSize = isMobile and 8 or 9,
						Font = Enum.Font.Gotham,
						TextWrapped = true,
						TextYAlignment = Enum.TextYAlignment.Top,
					}),
					
					-- Mini Crate Icon Placeholder (Visual 3D model handled at Roblox side)
					CrateVisual = e("Frame", {
						Size = UDim2.new(0, 55, 0, 55),
						Position = UDim2.new(0.5, 0, 0, 62),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.fromRGB(18, 18, 22),
						BorderSizePixel = 0,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
						BoxView = e("ViewportFrame", {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							ref = function(rbx: any)
								if rbx then
									local dummyTool = getOrCreateDummyTool(item)
									ViewportManager.setupViewport(cache.current, rbx, dummyTool, { bgTransparency = 1 })
								end
							end,
						}),
						LevelBadge = e("TextLabel", {
							Text = "Lvl " .. tostring(item.Level),
							Size = UDim2.new(0, 32, 0, 14),
							Position = UDim2.new(0.5, -16, 1, -8),
							BackgroundColor3 = Color3.fromRGB(0, 162, 255),
							BorderSizePixel = 0,
							TextColor3 = Color3.fromRGB(255, 255, 255),
							TextSize = 8,
							Font = Enum.Font.GothamBold,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0, 3) })
						})
					}),
					
					-- Container Tombol Beli
					ActionArea = e("Frame", {
						Size = UDim2.new(1, -10, 0, isMobile and 38 or 52),
						Position = UDim2.new(0, 5, 1, isMobile and -42 or -56),
						BackgroundTransparency = 1,
					}, {
						Layout = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Vertical,
							Padding = UDim.new(0, 4),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						
						-- Tombol Tokens
						TokenBtn = e("TextButton", {
							Text = `⚙️ {item.Cost} RPM`,
							Size = UDim2.new(1, 0, 0, isMobile and 17 or 24),
							BackgroundColor3 = Color3.fromRGB(0, 120, 200),
							BorderSizePixel = 0,
							TextColor3 = Color3.fromRGB(255, 255, 255),
							TextSize = isMobile and 8 or 10,
							Font = Enum.Font.GothamBold,
							LayoutOrder = 1,
							[React.Event.Activated] = function()
								handleBuyCrateWithTokens(item.Level)
							end,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) })
						}),
						
						-- Tombol Robux
						RobuxBtn = e("TextButton", {
							Text = `💵 {item.CostRobux} R$`,
							Size = UDim2.new(1, 0, 0, isMobile and 17 or 24),
							BackgroundColor3 = Color3.fromRGB(35, 145, 65),
							BorderSizePixel = 0,
							TextColor3 = Color3.fromRGB(255, 255, 255),
							TextSize = isMobile and 8 or 10,
							Font = Enum.Font.GothamBold,
							LayoutOrder = 2,
							[React.Event.Activated] = function()
								handleBuyCrateWithRobux(item.ProductID)
							end,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) })
						})
					})
				})
			end
		else
			-- Tab Gamepasses
			for i, pass in ipairs(ShopConfig.Gamepasses) do
				children["Pass_" .. i] = e("Frame", {
					BackgroundColor3 = Color3.fromRGB(24, 24, 30),
					BorderColor3 = Color3.fromRGB(50, 50, 60),
					BorderSizePixel = 1,
					LayoutOrder = i,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					
					-- Judul Pass
					Title = e("TextLabel", {
						Text = pass.Name,
						Size = UDim2.new(1, -10, 0, 24),
						Position = UDim2.new(0, 5, 0, 6),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = isMobile and 10 or 12,
						Font = Enum.Font.GothamBold,
						TextWrapped = true,
					}),
					
					-- Ikon
					Icon = e("ImageLabel", {
						Image = pass.Icon,
						Size = UDim2.new(0, 55, 0, 55),
						Position = UDim2.new(0.5, 0, 0, 32),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.fromRGB(18, 18, 22),
						BorderSizePixel = 0,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) })
					}),
					
					-- Deskripsi
					Desc = e("TextLabel", {
						Text = pass.Description,
						Size = UDim2.new(1, -12, 0, 50),
						Position = UDim2.new(0, 6, 0, 92),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(150, 150, 160),
						TextSize = isMobile and 8 or 9,
						Font = Enum.Font.Gotham,
						TextWrapped = true,
						TextYAlignment = Enum.TextYAlignment.Top,
					}),
					
					-- Tombol Beli Robux
					BuyBtn = e("TextButton", {
						Text = `💳 {pass.CostRobux} R$`,
						Size = UDim2.new(1, -12, 0, isMobile and 22 or 30),
						Position = UDim2.new(0, 6, 1, isMobile and -28 or -36),
						BackgroundColor3 = Color3.fromRGB(35, 145, 65),
						BorderSizePixel = 0,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = isMobile and 9 or 11,
						Font = Enum.Font.GothamBold,
						[React.Event.Activated] = function()
							handleBuyGamepass(pass.ID)
						end,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 5) })
					})
				})
			end
		end
		
		return children
	end
	
	-- Toast Container Layout
	local function buildToastList()
		local list = {
			Layout = e("UIListLayout", {
				Padding = UDim.new(0, 6),
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
		}
		local order = 1
		for id, data in pairs(toasts) do
			list[id] = e(ToastComponent, {
				id = id,
				message = data.message,
				isSuccess = data.isSuccess,
				duration = 2.5,
				layoutOrder = order,
				onFinished = removeToast,
			})
			order = order + 1
		end
		return list
	end

	-- Responsive Frame Toko Utama
	local MainFrame = e("Frame", {
		Size = isStorybook and UDim2.new(1, 0, 1, 0) or (isMobile and UDim2.new(0.82, 0, 0.82, 0) or UDim2.new(0.9, 0, 0.8, 0)),
		Position = not isStorybook and UDim2.new(0.5, 0, 0.5, 0) or nil,
		AnchorPoint = not isStorybook and Vector2.new(0.5, 0.5) or nil,
		BackgroundColor3 = Color3.fromRGB(15, 15, 20),
		BorderColor3 = Color3.fromRGB(60, 60, 75),
		BorderSizePixel = 1,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Constraint = not isStorybook and e("UISizeConstraint", {
			MinSize = Vector2.new(280, 240),
			MaxSize = isMobile and Vector2.new(9999, 9999) or Vector2.new(540, 700),
		}) or nil,
		
		-- HEADER SECTION
		Header = e("Frame", {
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundColor3 = Color3.fromRGB(20, 20, 25),
			BorderColor3 = Color3.fromRGB(50, 50, 60),
			BorderSizePixel = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Blocker = e("Frame", {
				Size = UDim2.new(1, 0, 0, 10),
				Position = UDim2.new(0, 0, 1, -10),
				BackgroundColor3 = Color3.fromRGB(20, 20, 25),
				BorderSizePixel = 0,
			}),
			
			Title = e("TextLabel", {
				Text = "🛒 SPEEDWAY SHOP",
				Size = UDim2.new(0.5, 0, 1, 0),
				Position = UDim2.new(0, 15, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = isMobile and 12 or 15,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			
			-- Token Stats Display
			TokenDisplay = e("TextLabel", {
				Text = `⚙️ <font color='#00E5FF'><b>{GameUtils.formatCompact(rpmTokens)} RPM</b></font>`,
				Size = UDim2.new(0, 120, 1, 0),
				Position = UDim2.new(1, isStorybook and -20 or -50, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = isMobile and 10 or 12,
				Font = Enum.Font.GothamBold,
				RichText = true,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			
			-- Close Button
			CloseBtn = not isStorybook and e("TextButton", {
				Text = "X",
				Size = UDim2.fromOffset(24, 24),
				Position = UDim2.new(1, -12, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 35, 85),
				BorderSizePixel = 0,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				[React.Event.Activated] = function()
					if props.onClose then props.onClose() end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) })
			}) or nil,
		}),
		
		-- TAB SWITCHER
		TabArea = e("Frame", {
			Size = UDim2.new(1, -20, 0, 35),
			Position = UDim2.new(0, 10, 0, 60),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
			}),
			
			ItemsTab = e("TextButton", {
				Text = "📦 ITEM GAME",
				Size = UDim2.new(0.5, -4, 1, 0),
				BackgroundColor3 = activeTab == "Items" and Color3.fromRGB(30, 30, 40) or Color3.fromRGB(20, 20, 25),
				BorderColor3 = activeTab == "Items" and Color3.fromRGB(0, 162, 255) or Color3.fromRGB(50, 50, 60),
				BorderSizePixel = 1,
				TextColor3 = activeTab == "Items" and Color3.fromRGB(0, 162, 255) or Color3.fromRGB(180, 180, 190),
				Font = Enum.Font.GothamBold,
				TextSize = isMobile and 10 or 12,
				[React.Event.Activated] = function() setActiveTab("Items") end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) })
			}),
			
			PassesTab = e("TextButton", {
				Text = "🔱 GAMEPASS",
				Size = UDim2.new(0.5, -4, 1, 0),
				BackgroundColor3 = activeTab == "Gamepasses" and Color3.fromRGB(30, 30, 40) or Color3.fromRGB(20, 20, 25),
				BorderColor3 = activeTab == "Gamepasses" and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(50, 50, 60),
				BorderSizePixel = 1,
				TextColor3 = activeTab == "Gamepasses" and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(180, 180, 190),
				Font = Enum.Font.GothamBold,
				TextSize = isMobile and 10 or 12,
				[React.Event.Activated] = function() setActiveTab("Gamepasses") end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) })
			}),
		}),
		
		-- GRID CONTENT
		GridScroll = e("ScrollingFrame", {
			Size = UDim2.new(1, -20, 1, -115),
			Position = UDim2.new(0, 10, 0, 105),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(80, 80, 95),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, buildListChildren()),
	})

	if isStorybook then
		return e("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}, {
			MainContainer = MainFrame,
			ToastsArea = e("Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Name = "ToastContainer",
			}, buildToastList())
		})
	end

	-- Render dalam background redup di game asli
	return e("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 0.55,
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		Active = true,
	}, {
		MainContainer = MainFrame,
		ToastsArea = e("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Name = "ToastContainer",
		}, buildToastList())
	})
end

return ShopGui

--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

local player = Players.LocalPlayer

-- Rarity Colors mapping
local RarityColors = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(100, 255, 100),
	Rare = Color3.fromRGB(50, 150, 255),
	Epic = Color3.fromRGB(180, 50, 255),
	Legendary = Color3.fromRGB(255, 165, 0),
	Mythic = Color3.fromRGB(255, 50, 50),
	God = Color3.fromRGB(255, 255, 0),
	Celestial = Color3.fromRGB(255, 255, 255),
}

-- Mathematical deterministic position formula
local function getPositionAtTime(t, baseSpeed, multiplier, seed, index)
	if t < 0 then
		return 0
	end
	local dist = baseSpeed * t

	local launchBoost = 0
	if multiplier > 1.0 then
		local maxDuration = math.min(t, 8)
		launchBoost = (multiplier - 1) * baseSpeed * (1 - math.exp(-0.5 * maxDuration)) / 0.5
	elseif multiplier < 1.0 then
		local penaltyDuration = math.min(t, 10)
		launchBoost = (multiplier - 1) * baseSpeed * penaltyDuration
	end

	local variance = math.sin(t * 0.7 + index * 1.5 + seed) * 0.5
	return dist + launchBoost + variance
end

-- Custom hook to track player's owned cars
local function useOwnedCars()
	local ownedCars, setOwnedCars = useState({})
	useEffect(function()
		local function scan()
			local list = {}
			local backpack = player:FindFirstChild("Backpack")
			local char = player.Character

			local function checkFolder(folder)
				if not folder then return end
				for _, child in ipairs(folder:GetChildren()) do
					if child:IsA("Tool") and GameUtils.isCar(child) then
						table.insert(list, {
							Name = child.Name,
							Rarity = child:GetAttribute("Rarity") or "Common",
							Variant = child:GetAttribute("Variant") or "Normal",
							Price = child:GetAttribute("Price") or 0,
						})
					end
				end
			end

			checkFolder(backpack)
			checkFolder(char)
			setOwnedCars(list)
		end

		scan()
		local conn1 = player.CharacterAdded:Connect(scan)
		local conn2 = player.CharacterRemoving:Connect(scan)
		local backpack = player:WaitForChild("Backpack", 5)
		local conn3 = backpack and backpack.ChildAdded:Connect(scan)
		local conn4 = backpack and backpack.ChildRemoved:Connect(scan)

		return function()
			if conn1 then conn1:Disconnect() end
			if conn2 then conn2:Disconnect() end
			if conn3 then conn3:Disconnect() end
			if conn4 then conn4:Disconnect() end
		end
	end, {})
	return ownedCars
end

local function RacePanel(props)
	local screen, setScreen = useState("Dashboard") -- Dashboard, Stats, Race, Outcome
	local stats, setStats = useState({ Wins = 0, Losses = 0, CashEarned = 0 })
	local ownedCars = useOwnedCars()

	-- Dashboard State
	local selectedCar, setSelectedCar = useState(nil)
	local aiDifficulty, setAiDifficulty = useState("Easy")
	local opponentName, setOpponentName = useState("")
	local betAmount, setBetAmount = useState("1000")
	local notification, setNotification = useState("")
	
	-- PvP Incoming Challenge State
	local currentChallenge, setCurrentChallenge = useState(nil)

	-- Race State
	local raceData, setRaceData = useState(nil)
	local positions, setPositions = useState({})
	local launchMessage, setLaunchMessage = useState("")
	local launchColor, setLaunchColor = useState(Color3.fromRGB(255, 255, 255))
	local hasLaunched, setHasLaunched = useState(false)
	local startLightsActive, setStartLightsActive = useState(false)
	local serverTimeOffset, setServerTimeOffset = useState(0)

	-- Outcome State
	local ranks, setRanks = useState({})
	local playerRank, setPlayerRank = useState(4)
	local rewardCash, setRewardCash = useState(0)

	-- Synchronize Stats reactively via player attribute
	useEffect(function()
		local function updateStats()
			local rawStats = player:GetAttribute("RaceStats")
			if rawStats then
				local ok, decoded = pcall(HttpService.JSONDecode, HttpService, rawStats)
				if ok and decoded then
					setStats(decoded)
				end
			end
		end
		updateStats()
		local conn = player:GetAttributeChangedSignal("RaceStats"):Connect(updateStats)
		return function()
			conn:Disconnect()
		end
	end, {})

	-- Auto-select first car
	useEffect(function()
		if #ownedCars > 0 and not selectedCar then
			setSelectedCar(ownedCars[1])
		end
	end, {ownedCars})

	-- Handle RaceEvent updates (challenges and starts)
	useEffect(function()
		local raceEvent = ReplicatedStorage:WaitForChild("RaceEvent", 5)
		if not raceEvent then return end

		local conn = raceEvent.OnClientEvent:Connect(function(eventType, data)
			if eventType == "ChallengeReceived" then
				setCurrentChallenge(data)
			elseif eventType == "StartPvPRace" then
				setCurrentChallenge(nil)
				setRaceData(data)
				setHasLaunched(false)
				setLaunchMessage("")
				setPositions({})
				setScreen("Race")
			end
		end)

		return function()
			conn:Disconnect()
		end
	end, {})

	-- Heartbeat Animation Loop
	useEffect(function()
		if screen ~= "Race" or not raceData then return end

		local conn
		conn = RunService.Heartbeat:Connect(function()
			local now = workspace:GetServerTimeNow()
			local t = now - raceData.StartTime

			local newPos = {}
			local finishedCount = 0
			local totalParticipants = 0

			for key, part in pairs(raceData.Participants) do
				totalParticipants += 1
				local index = 1
				if key == tostring(player.UserId) then
					index = 1
				elseif key:sub(1, 3) == "AI_" then
					index = 3 + (tonumber(key:sub(4)) or 0)
				else
					index = 2
				end

				local theta = getPositionAtTime(t, part.BaseSpeed, part.Multiplier, raceData.Seed, index)
				newPos[key] = theta

				if theta >= 6 * math.pi then
					finishedCount += 1
				end
			end

			setPositions(newPos)

			-- Finish check
			if finishedCount >= totalParticipants and t > 0 then
				if conn then
					conn:Disconnect()
					conn = nil
				end
				
				setScreen("Outcome")
				task.spawn(function()
					local ok, result = pcall(function()
						return props.raceService:getRaceOutcome(raceData.RaceId)
					end)
					if ok and result and result.Success then
						setRanks(result.Ranks)
						setPlayerRank(result.PlayerRank)
						setRewardCash(result.RewardCash)
					else
						setNotification("Gagal memproses hasil balapan dari server")
					end
				end)
			end
		end)

		return function()
			if conn then conn:Disconnect() end
		end
	end, {screen, raceData})

	local function startAIRace()
		if not selectedCar then
			setNotification("Pilih mobil terlebih dahulu!")
			return
		end
		setNotification("Menghubungkan ke balapan...")
		
		task.spawn(function()
			local ok, result = pcall(function()
				return props.raceService:startAIRace(selectedCar.Name, aiDifficulty)
			end)
			if ok and result and result.Success then
				setNotification("")
				setRaceData(result)
				setHasLaunched(false)
				setLaunchMessage("")
				setPositions({})
				setScreen("Race")
			else
				setNotification(result and result.Error or "Gagal memulai balapan AI")
			end
		end)
	end

	local function sendChallenge()
		if not selectedCar then
			setNotification("Pilih mobil terlebih dahulu!")
			return
		end
		if opponentName == "" then
			setNotification("Pilih lawan PvP!")
			return
		end
		local betNum = tonumber(betAmount) or 0
		if betNum < 0 then
			setNotification("Nominal taruhan tidak valid!")
			return
		end

		setNotification("Mengirim tantangan...")
		task.spawn(function()
			local ok, result = pcall(function()
				return props.raceService:sendPvPChallenge(opponentName, selectedCar.Name, betNum)
			end)
			if ok and result and result.Success then
				setNotification(result.Message)
			else
				setNotification(result and result.Error or "Gagal mengirim tantangan")
			end
		end)
	end

	local function acceptChallenge()
		if not currentChallenge then return end
		if not selectedCar then
			setNotification("Pilih mobil terlebih dahulu!")
			return
		end

		setNotification("Menerima tantangan...")
		task.spawn(function()
			local ok, result = pcall(function()
				return props.raceService:acceptPvPChallenge(currentChallenge.ChallengeId, selectedCar.Name)
			end)
			if not (ok and result and result.Success) then
				setNotification(result and result.Error or "Gagal menerima tantangan")
			end
		end)
	end

	local function launchCar()
		if screen ~= "Race" or not raceData or hasLaunched then return end
		setHasLaunched(true)

		local clickTime = workspace:GetServerTimeNow()
		local reactionTime = clickTime - raceData.StartTime

		task.spawn(function()
			local ok, result = pcall(function()
				return props.raceService:submitLaunchTime(raceData.RaceId, reactionTime)
			end)

			if ok and result and result.Success then
				-- Play launch visual feedback
				setLaunchMessage(result.Message)
				if result.Multiplier > 1.15 then
					setLaunchColor(Color3.fromRGB(255, 215, 0)) -- Gold
				elseif result.Multiplier > 1.0 then
					setLaunchColor(Color3.fromRGB(0, 255, 100)) -- Green
				elseif result.Multiplier < 1.0 then
					setLaunchColor(Color3.fromRGB(255, 50, 50)) -- Red
				else
					setLaunchColor(Color3.fromRGB(200, 200, 200)) -- Gray
				end

				-- Sync launch multiplier locally
				local copy = table.clone(raceData)
				local myPart = copy.Participants[tostring(player.UserId)]
				if myPart then
					myPart.Multiplier = result.Multiplier
					setRaceData(copy)
				end
			else
				setLaunchMessage("Gagal mensubmit launch!")
				setLaunchColor(Color3.fromRGB(255, 50, 50))
			end
		end)
	end

	-- Render Sidebar Navigation Item
	local function sidebarItem(title, tabName)
		local isActive = screen == tabName
		return e("TextButton", {
			Text = title,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = isActive and Color3.fromRGB(255, 30, 60) or Color3.fromRGB(20, 20, 25),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			BorderSizePixel = 0,
			[React.Event.Activated] = function()
				if screen == "Dashboard" or screen == "Stats" then
					setScreen(tabName)
				end
			end
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", { Color = isActive and Color3.fromRGB(255, 80, 100) or Color3.fromRGB(40, 40, 45), Thickness = 1 })
		})
	end

	-- Get F1 lights state
	local now = workspace:GetServerTimeNow()
	local timeLeft = raceData and (raceData.StartTime - now) or 999
	local redLights = 0
	if timeLeft <= 5 and timeLeft > 4 then redLights = 1
	elseif timeLeft <= 4 and timeLeft > 3 then redLights = 2
	elseif timeLeft <= 3 and timeLeft > 2 then redLights = 3
	elseif timeLeft <= 2 and timeLeft > 1 then redLights = 4
	elseif timeLeft <= 1 and timeLeft > 0 then redLights = 5
	end

	-- Main Layout
	return e("Frame", {
		Size = UDim2.new(0, 780, 0, 520),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(22, 22, 28),
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
		Stroke = e("UIStroke", { Color = Color3.fromRGB(55, 55, 65), Thickness = 2 }),

		-- Sidebar Panel
		Sidebar = e("Frame", {
			Size = UDim2.new(0, 180, 1, 0),
			BackgroundColor3 = Color3.fromRGB(14, 14, 18),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
			Padding = e("UIPadding", { PaddingTop = UDim.new(0, 20), PaddingBottom = UDim.new(0, 20), PaddingLeft = UDim.new(0, 15), PaddingRight = UDim.new(0, 15) }),
			List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 12) }),

			Logo = e("TextLabel", {
				Text = "🏁 F1 MANAGER",
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 30, 60),
				Font = Enum.Font.GothamBlack,
				TextSize = 16,
			}),

			DashBtn = sidebarItem("🚀 DASHBOARD", "Dashboard"),
			StatsBtn = sidebarItem("🏆 STATISTIK", "Stats"),

			Spacer = e("Frame", { Size = UDim2.new(1, 0, 1, -180), BackgroundTransparency = 1 }),

			CloseBtn = e("TextButton", {
				Text = "TUTUP",
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundColor3 = Color3.fromRGB(35, 35, 40),
				TextColor3 = Color3.fromRGB(220, 220, 220),
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				BorderSizePixel = 0,
				[React.Event.Activated] = props.onClose,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) })
			})
		}),

		-- Content Area
		Content = e("Frame", {
			Size = UDim2.new(1, -180, 1, 0),
			Position = UDim2.new(0, 180, 0, 0),
			BackgroundTransparency = 1,
		}, {
			Padding = e("UIPadding", { PaddingTop = UDim.new(0, 20), PaddingBottom = UDim.new(0, 20), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }),

			-------------------------------------------------------
			-- DASHBOARD TAB
			-------------------------------------------------------
			Dashboard = (screen == "Dashboard") and e("Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
			}, {
				List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 15) }),

				Title = e("TextLabel", {
					Text = "Dashboard Balapan",
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 18,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				-- Notification Bar
				NotifBar = (notification ~= "") and e("TextLabel", {
					Text = notification,
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundColor3 = Color3.fromRGB(35, 30, 20),
					TextColor3 = Color3.fromRGB(255, 200, 50),
					Font = Enum.Font.GothamMedium,
					TextSize = 10,
				}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),

				-- Two Columns Panel
				PanelRows = e("Frame", {
					Size = UDim2.new(1, 0, 1, (notification ~= "") and -54 or -35),
					BackgroundTransparency = 1,
				}, {
					List = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 15) }),

					-- Column Left: Garage / Car Selector
					GarageCol = e("Frame", {
						Size = UDim2.new(0.55, -8, 1, 0),
						BackgroundColor3 = Color3.fromRGB(16, 16, 22),
						BorderSizePixel = 0,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
						Padding = e("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),

						Header = e("TextLabel", {
							Text = "PILIH MOBIL AKTIF (" .. #ownedCars .. ")",
							Size = UDim2.new(1, 0, 0, 20),
							BackgroundTransparency = 1,
							TextColor3 = Color3.fromRGB(0, 170, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 10,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),

						CarScroll = e("ScrollingFrame", {
							Size = UDim2.new(1, 0, 1, -25),
							Position = UDim2.new(0, 0, 0, 25),
							BackgroundTransparency = 1,
							CanvasSize = UDim2.new(0, 0, 0, math.max(1, #ownedCars) * 50),
							ScrollBarThickness = 4,
						}, {
							List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 6) }),
							
							Cars = React.useMemo(function()
								local elements = {}
								for i, car in ipairs(ownedCars) do
									local isSelected = selectedCar and selectedCar.Name == car.Name
									local rarityColor = RarityColors[car.Rarity] or Color3.fromRGB(200, 200, 200)

									elements["Car_" .. i] = e("TextButton", {
										Text = "",
										Size = UDim2.new(0.96, 0, 0, 44),
										BackgroundColor3 = isSelected and Color3.fromRGB(26, 32, 46) or Color3.fromRGB(22, 22, 28),
										BorderSizePixel = 0,
										[React.Event.Activated] = function()
											setSelectedCar(car)
										end
									}, {
										Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
										Stroke = e("UIStroke", { Color = isSelected and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(40, 40, 45), Thickness = 1 }),
										
										-- Car Text Details
										NameText = e("TextLabel", {
											Text = car.Name:match("^([^-]+)") or car.Name,
											Size = UDim2.new(0.7, 0, 0.5, 0),
											Position = UDim2.new(0, 10, 0, 4),
											BackgroundTransparency = 1,
											TextColor3 = Color3.fromRGB(255, 255, 255),
											Font = Enum.Font.GothamBold,
											TextSize = 10,
											TextXAlignment = Enum.TextXAlignment.Left,
										}),

										SubText = e("TextLabel", {
											Text = car.Variant .. " | " .. car.Rarity,
											Size = UDim2.new(0.7, 0, 0.5, 0),
											Position = UDim2.new(0, 10, 0.5, -2),
											BackgroundTransparency = 1,
											TextColor3 = rarityColor,
											Font = Enum.Font.GothamMedium,
											TextSize = 8,
											TextXAlignment = Enum.TextXAlignment.Left,
										})
									})
								end
								return elements
							end, {ownedCars, selectedCar})
						})
					}),

					-- Column Right: Mode Selectors (AI and PvP)
					ModeCol = e("Frame", {
						Size = UDim2.new(0.45, -7, 1, 0),
						BackgroundTransparency = 1,
					}, {
						List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 15) }),

						-- AI Match Card
						AICard = e("Frame", {
							Size = UDim2.new(1, 0, 0.52, -8),
							BackgroundColor3 = Color3.fromRGB(16, 16, 22),
							BorderSizePixel = 0,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
							Padding = e("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
							List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10) }),

							Header = e("TextLabel", {
								Text = "🤖 BALAPAN AI",
								Size = UDim2.new(1, 0, 0, 15),
								BackgroundTransparency = 1,
								TextColor3 = Color3.fromRGB(0, 255, 100),
								Font = Enum.Font.GothamBold,
								TextSize = 10,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),

							-- Diff row
							DiffRow = e("Frame", {
								Size = UDim2.new(1, 0, 0, 30),
								BackgroundTransparency = 1,
							}, {
								List = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),

								Easy = e("TextButton", {
									Text = "EASY",
									Size = UDim2.new(0.31, 0, 1, 0),
									BackgroundColor3 = aiDifficulty == "Easy" and Color3.fromRGB(0, 150, 60) or Color3.fromRGB(26, 26, 32),
									TextColor3 = Color3.fromRGB(255, 255, 255),
									Font = Enum.Font.GothamBold,
									TextSize = 9,
									BorderSizePixel = 0,
									[React.Event.Activated] = function() setAiDifficulty("Easy") end
								}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),

								Medium = e("TextButton", {
									Text = "MED",
									Size = UDim2.new(0.31, 0, 1, 0),
									BackgroundColor3 = aiDifficulty == "Medium" and Color3.fromRGB(200, 120, 0) or Color3.fromRGB(26, 26, 32),
									TextColor3 = Color3.fromRGB(255, 255, 255),
									Font = Enum.Font.GothamBold,
									TextSize = 9,
									BorderSizePixel = 0,
									[React.Event.Activated] = function() setAiDifficulty("Medium") end
								}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),

								Hard = e("TextButton", {
									Text = "HARD",
									Size = UDim2.new(0.31, 0, 1, 0),
									BackgroundColor3 = aiDifficulty == "Hard" and Color3.fromRGB(200, 30, 40) or Color3.fromRGB(26, 26, 32),
									TextColor3 = Color3.fromRGB(255, 255, 255),
									Font = Enum.Font.GothamBold,
									TextSize = 9,
									BorderSizePixel = 0,
									[React.Event.Activated] = function() setAiDifficulty("Hard") end
								}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
							}),

							-- Reward Info
							RewardText = e("TextLabel", {
								Text = "Reward Win: " .. (
									aiDifficulty == "Easy" and "$1.000 Cash" or
									aiDifficulty == "Medium" and "$5.000 Cash" or
									"$25.000 Cash & +1 Level"
								),
								Size = UDim2.new(1, 0, 0, 15),
								BackgroundTransparency = 1,
								TextColor3 = Color3.fromRGB(180, 180, 180),
								Font = Enum.Font.GothamMedium,
								TextSize = 9,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),

							StartAIBtn = e("TextButton", {
								Text = "MULAI BALAP AI",
								Size = UDim2.new(1, 0, 0, 36),
								BackgroundColor3 = Color3.fromRGB(0, 120, 255),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								Font = Enum.Font.GothamBold,
								TextSize = 11,
								BorderSizePixel = 0,
								[React.Event.Activated] = startAIRace,
							}, {
								Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) })
							})
						}),

						-- PvP Match Card
						PvPCard = e("Frame", {
							Size = UDim2.new(1, 0, 0.48, -7),
							BackgroundColor3 = Color3.fromRGB(16, 16, 22),
							BorderSizePixel = 0,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
							Padding = e("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
							List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 8) }),

							Header = e("TextLabel", {
								Text = "🏁 TANTANG PEMAIN (PvP)",
								Size = UDim2.new(1, 0, 0, 15),
								BackgroundTransparency = 1,
								TextColor3 = Color3.fromRGB(255, 30, 60),
								Font = Enum.Font.GothamBold,
								TextSize = 10,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),

							-- Input Opponent Name
							OpponentInput = e("TextBox", {
								Text = opponentName,
								PlaceholderText = "Nama Player Lawan...",
								Size = UDim2.new(1, 0, 0, 24),
								BackgroundColor3 = Color3.fromRGB(26, 26, 32),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								PlaceholderColor3 = Color3.fromRGB(100, 100, 100),
								Font = Enum.Font.GothamMedium,
								TextSize = 9,
								BorderSizePixel = 0,
								[React.Change.Text] = function(box) setOpponentName(box.Text) end
							}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),

							-- Input Bet Amount
							BetRow = e("Frame", {
								Size = UDim2.new(1, 0, 0, 24),
								BackgroundTransparency = 1,
							}, {
								Label = e("TextLabel", {
									Text = "Taruhan $:",
									Size = UDim2.new(0.35, 0, 1, 0),
									BackgroundTransparency = 1,
									TextColor3 = Color3.fromRGB(200, 200, 200),
									Font = Enum.Font.GothamBold,
									TextSize = 9,
									TextXAlignment = Enum.TextXAlignment.Left,
								}),
								Input = e("TextBox", {
									Text = betAmount,
									Size = UDim2.new(0.65, 0, 1, 0),
									Position = UDim2.new(0.35, 0, 0, 0),
									BackgroundColor3 = Color3.fromRGB(26, 26, 32),
									TextColor3 = Color3.fromRGB(255, 215, 0),
									Font = Enum.Font.GothamBold,
									TextSize = 10,
									BorderSizePixel = 0,
									[React.Change.Text] = function(box) setBetAmount(box.Text) end
								}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
							}),

							ChallengeBtn = e("TextButton", {
								Text = "KIRIM TANTANAN",
								Size = UDim2.new(1, 0, 0, 32),
								BackgroundColor3 = Color3.fromRGB(150, 20, 50),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								Font = Enum.Font.GothamBold,
								TextSize = 10,
								BorderSizePixel = 0,
								[React.Event.Activated] = sendChallenge,
							}, {
								Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) })
							})
						})
					})
				})
			}),

			-------------------------------------------------------
			-- STATS TAB
			-------------------------------------------------------
			Stats = (screen == "Stats") and e("Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
			}, {
				List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 25) }),

				Title = e("TextLabel", {
					Text = "Rekor & Statistik Balap Anda",
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 18,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				Grid = e("Frame", {
					Size = UDim2.new(1, 0, 0, 240),
					BackgroundTransparency = 1,
				}, {
					Layout = e("UIGridLayout", { CellSize = UDim2.new(0.31, 0, 0, 100), CellPadding = UDim2.new(0.035, 0, 0, 20) }),

					StatWins = e("Frame", { BackgroundColor3 = Color3.fromRGB(16, 26, 18), BorderSizePixel = 0 }, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
						Stroke = e("UIStroke", { Color = Color3.fromRGB(50, 120, 60), Thickness = 1 }),
						Label = e("TextLabel", { Text = "TOTAL WINS", Size = UDim2.new(1, 0, 0.4, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(150, 220, 160), Font = Enum.Font.GothamBold, TextSize = 10 }),
						Val = e("TextLabel", { Text = tostring(stats.Wins or 0), Size = UDim2.new(1, 0, 0.6, 0), Position = UDim2.new(0, 0, 0.4, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBlack, TextSize = 24 }),
					}),

					StatLosses = e("Frame", { BackgroundColor3 = Color3.fromRGB(26, 16, 18), BorderSizePixel = 0 }, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
						Stroke = e("UIStroke", { Color = Color3.fromRGB(120, 50, 60), Thickness = 1 }),
						Label = e("TextLabel", { Text = "TOTAL LOSSES", Size = UDim2.new(1, 0, 0.4, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(220, 150, 160), Font = Enum.Font.GothamBold, TextSize = 10 }),
						Val = e("TextLabel", { Text = tostring(stats.Losses or 0), Size = UDim2.new(1, 0, 0.6, 0), Position = UDim2.new(0, 0, 0.4, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBlack, TextSize = 24 }),
					}),

					StatWinrate = e("Frame", { BackgroundColor3 = Color3.fromRGB(18, 18, 26), BorderSizePixel = 0 }, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
						Stroke = e("UIStroke", { Color = Color3.fromRGB(80, 80, 120), Thickness = 1 }),
						Label = e("TextLabel", { Text = "WIN RATE", Size = UDim2.new(1, 0, 0.4, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(180, 180, 220), Font = Enum.Font.GothamBold, TextSize = 10 }),
						Val = e("TextLabel", {
							Text = string.format("%.1f%%", ((stats.Wins or 0) + (stats.Losses or 0) > 0) and ((stats.Wins or 0) / ((stats.Wins or 0) + (stats.Losses or 0)) * 100) or 0),
							Size = UDim2.new(1, 0, 0.6, 0), Position = UDim2.new(0, 0, 0.4, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBlack, TextSize = 24
						}),
					}),

					StatEarned = e("Frame", { BackgroundColor3 = Color3.fromRGB(22, 22, 28), BorderSizePixel = 0 }, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
						Stroke = e("UIStroke", { Color = Color3.fromRGB(120, 120, 60), Thickness = 1 }),
						Label = e("TextLabel", { Text = "CASH EARNED", Size = UDim2.new(1, 0, 0.4, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(220, 220, 150), Font = Enum.Font.GothamBold, TextSize = 10 }),
						Val = e("TextLabel", { Text = "$" .. GameUtils.formatCompact(stats.CashEarned or 0), Size = UDim2.new(1, 0, 0.6, 0), Position = UDim2.new(0, 0, 0.4, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 215, 0), Font = Enum.Font.GothamBlack, TextSize = 20 }),
					})
				})
			}),

			-------------------------------------------------------
			-- ACTIVE RACE SCREEN
			-------------------------------------------------------
			Race = (screen == "Race" and raceData) and e("Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
			}, {
				-- F1 start lights countdown HUD
				LightsRow = e("Frame", {
					Size = UDim2.new(0.5, 0, 0, 44),
					Position = UDim2.new(0.25, 0, 0, 0),
					BackgroundColor3 = Color3.fromRGB(10, 10, 12),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 22) }),
					Stroke = e("UIStroke", { Color = Color3.fromRGB(40, 40, 45), Thickness = 1.5 }),
					Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }),

					Light1 = e("Frame", { Size = UDim2.new(0, 20, 0, 20), BackgroundColor3 = (redLights >= 1) and Color3.fromRGB(255, 30, 40) or Color3.fromRGB(40, 40, 45) }, { Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
					Light2 = e("Frame", { Size = UDim2.new(0, 20, 0, 20), BackgroundColor3 = (redLights >= 2) and Color3.fromRGB(255, 30, 40) or Color3.fromRGB(40, 40, 45) }, { Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
					Light3 = e("Frame", { Size = UDim2.new(0, 20, 0, 20), BackgroundColor3 = (redLights >= 3) and Color3.fromRGB(255, 30, 40) or Color3.fromRGB(40, 40, 45) }, { Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
					Light4 = e("Frame", { Size = UDim2.new(0, 20, 0, 20), BackgroundColor3 = (redLights >= 4) and Color3.fromRGB(255, 30, 40) or Color3.fromRGB(40, 40, 45) }, { Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
					Light5 = e("Frame", { Size = UDim2.new(0, 20, 0, 20), BackgroundColor3 = (redLights >= 5) and Color3.fromRGB(255, 30, 40) or Color3.fromRGB(40, 40, 45) }, { Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
				}),

				-- Launch feedback display
				FeedbackText = (launchMessage ~= "") and e("TextLabel", {
					Text = launchMessage,
					Size = UDim2.new(1, 0, 0, 30),
					Position = UDim2.new(0, 0, 0, 50),
					BackgroundTransparency = 1,
					TextColor3 = launchColor,
					Font = Enum.Font.GothamBlack,
					TextSize = 16,
				}),

				-- 2D Oval Circuit Map
				CircuitFrame = e("Frame", {
					Size = UDim2.new(0.78, 0, 0.52, 0),
					Position = UDim2.new(0.11, 0, 0, 90),
					BackgroundColor3 = Color3.fromRGB(16, 16, 22),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
					Stroke = e("UIStroke", { Color = Color3.fromRGB(40, 40, 45), Thickness = 1 }),

					-- Oval Track visual line (Capsule frame trick)
					TrackOutline = e("Frame", {
						Size = UDim2.new(0.85, 0, 0.7, 0),
						Position = UDim2.new(0.075, 0, 0.15, 0),
						BackgroundTransparency = 1,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
						Stroke = e("UIStroke", { Color = Color3.fromRGB(75, 75, 90), Thickness = 12 })
					}),

					-- Interactive Launch Button (when lights are starting)
					LaunchBtn = (not hasLaunched) and e("TextButton", {
						Text = "LAUNCH",
						Size = UDim2.new(0, 110, 0, 110),
						Position = UDim2.new(0.5, 0, 0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(0, 200, 80),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						Font = Enum.Font.GothamBlack,
						TextSize = 18,
						BorderSizePixel = 0,
						[React.Event.Activated] = launchCar
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
						Stroke = e("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 2 })
					}),

					-- Dot participants on track
					Dots = React.useMemo(function()
						local list = {}
						local Rx = 175
						local Ry = 70

						for key, theta in pairs(positions) do
							local part = raceData.Participants[key]
							local dotColor = Color3.fromRGB(255, 255, 255)

							-- Color assign
							if key == tostring(player.UserId) then
								dotColor = Color3.fromRGB(0, 255, 100) -- Player
							elseif key:sub(1, 3) == "AI_" then
								local num = tonumber(key:sub(4)) or 1
								if num == 1 then dotColor = Color3.fromRGB(255, 50, 50)
								elseif num == 2 then dotColor = Color3.fromRGB(255, 200, 0)
								else dotColor = Color3.fromRGB(255, 120, 0)
								end
							else
								dotColor = Color3.fromRGB(0, 170, 255) -- PvP Opponent
							end

							local cx = math.cos(theta) * Rx
							local cy = math.sin(theta) * Ry

							list["Dot_" .. key] = e("Frame", {
								Size = UDim2.new(0, 12, 0, 12),
								Position = UDim2.new(0.5, cx - 6, 0.5, cy - 6),
								BackgroundColor3 = dotColor,
								BorderSizePixel = 0,
							}, {
								Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
								Stroke = e("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1 }),
								
								-- Mini Floating Name Tag
								NameTag = e("TextLabel", {
									Text = part.Name:sub(1, 7),
									Size = UDim2.new(0, 60, 0, 14),
									Position = UDim2.new(0.5, -30, 0, -18),
									BackgroundTransparency = 1,
									TextColor3 = dotColor,
									Font = Enum.Font.GothamBold,
									TextSize = 8,
								})
							})
						end
						return list
					end, {positions, raceData})
				}),

				-- Live Leaderboard column on bottom
				Leaderboard = e("Frame", {
					Size = UDim2.new(1, 0, 0, 55),
					Position = UDim2.new(0, 0, 0, 385),
					BackgroundColor3 = Color3.fromRGB(14, 14, 18),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Padding = e("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
					List = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 15), VerticalAlignment = Enum.VerticalAlignment.Center }),

					Title = e("TextLabel", {
						Text = "LAP 3/3 TELEMETRI:",
						Size = UDim2.new(0.25, 0, 1, 0),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(120, 120, 130),
						Font = Enum.Font.GothamBold,
						TextSize = 10,
					}),

					Ranks = React.useMemo(function()
						local sorted = {}
						for key, theta in pairs(positions) do
							local part = raceData.Participants[key]
							table.insert(sorted, { Key = key, Name = part.Name, Theta = theta })
						end
						table.sort(sorted, function(a, b)
							return a.Theta > b.Theta
						end)

						local elements = {}
						for i, info in ipairs(sorted) do
							local isLocal = info.Key == tostring(player.UserId)
							local lap = math.floor(info.Theta / (2 * math.pi)) + 1
							if lap > 3 then lap = 3 end

							elements["P_" .. i] = e("TextLabel", {
								Text = string.format("%d. %s (Lap %d)", i, info.Name, lap),
								Size = UDim2.new(0.18, 0, 1, 0),
								BackgroundTransparency = 1,
								TextColor3 = isLocal and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(240, 240, 240),
								Font = isLocal and Enum.Font.GothamBold or Enum.Font.GothamMedium,
								TextSize = 9,
							})
						end
						return elements
					end, {positions, raceData})
				})
			}),

			-------------------------------------------------------
			-- OUTCOME SCREEN
			-------------------------------------------------------
			Outcome = (screen == "Outcome") and e("Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
			}, {
				List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 20), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }),

				Title = e("TextLabel", {
					Text = (playerRank == 1) and "🏆 KEMENANGAN BALAPAN!" or "🏁 BALAPAN SELESAI!",
					Size = UDim2.new(1, 0, 0, 40),
					BackgroundTransparency = 1,
					TextColor3 = (playerRank == 1) and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(230, 230, 230),
					Font = Enum.Font.GothamBlack,
					TextSize = 24,
				}),

				RanksBox = e("Frame", {
					Size = UDim2.new(0.8, 0, 0, 180),
					BackgroundColor3 = Color3.fromRGB(15, 15, 18),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Padding = e("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }),
					List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }),

					LeaderboardRows = React.useMemo(function()
						local rows = {}
						for i, rInfo in ipairs(ranks) do
							local isLocal = rInfo.Key == tostring(player.UserId)
							rows["RankRow_" .. i] = e("Frame", {
								Size = UDim2.new(1, 0, 0, 30),
								BackgroundTransparency = 1,
							}, {
								Index = e("TextLabel", { Text = tostring(i), Size = UDim2.new(0.1, 0, 1, 0), BackgroundTransparency = 1, TextColor3 = (i == 1) and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(180, 180, 180), Font = Enum.Font.GothamBold, TextSize = 12 }),
								Name = e("TextLabel", { Text = rInfo.Name, Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0.1, 0, 0, 0), BackgroundTransparency = 1, TextColor3 = isLocal and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(230, 230, 230), Font = isLocal and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left }),
								Time = e("TextLabel", { Text = string.format("%.2f s", rInfo.FinishTime), Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(0.6, 0, 0, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(150, 150, 155), Font = Enum.Font.GothamMedium, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right })
							})
						end
						return rows
					end, {ranks})
				}),

				RewardLabel = (rewardCash > 0) and e("TextLabel", {
					Text = "HADIAH CASH: +$" .. GameUtils.formatPrice(rewardCash),
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(0, 255, 100),
					Font = Enum.Font.GothamBold,
					TextSize = 14,
				}),

				BackBtn = e("TextButton", {
					Text = "KEMBALI KE DASHBOARD",
					Size = UDim2.new(0.5, 0, 0, 36),
					BackgroundColor3 = Color3.fromRGB(0, 120, 255),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					BorderSizePixel = 0,
					[React.Event.Activated] = function()
						setScreen("Dashboard")
						setRanks({})
						setRaceData(nil)
					end
				}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) })
			})
		}),

		-- Incoming Challenge Modal Overlay
		ChallengeModal = (currentChallenge ~= nil) and e("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(10, 10, 15, 0.75),
			BorderSizePixel = 0,
			ZIndex = 10,
		}, {
			ModalBox = e("Frame", {
				Size = UDim2.new(0, 360, 0, 220),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(22, 22, 28),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Stroke = e("UIStroke", { Color = Color3.fromRGB(255, 30, 60), Thickness = 2 }),
				Padding = e("UIPadding", { PaddingTop = UDim.new(0, 20), PaddingBottom = UDim.new(0, 20), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }),
				List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center }),

				Title = e("TextLabel", { Text = "⚔️ TANTANGAN BALAPAN", Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 30, 60), Font = Enum.Font.GothamBold, TextSize = 14 }),
				
				Desc = e("TextLabel", {
					Text = string.format("Pemain %s menantang Anda bertaruh Cash sebesar $%s!", currentChallenge.ChallengerName, GameUtils.formatPrice(currentChallenge.BetAmount)),
					Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(220, 220, 220), Font = Enum.Font.GothamMedium, TextSize = 11, TextWrapped = true
				}),

				Buttons = e("Frame", {
					Size = UDim2.new(1, 0, 0, 36),
					BackgroundTransparency = 1,
				}, {
					List = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 15), HorizontalAlignment = Enum.HorizontalAlignment.Center }),

					Decline = e("TextButton", {
						Text = "TOLAK",
						Size = UDim2.new(0.45, 0, 1, 0),
						BackgroundColor3 = Color3.fromRGB(45, 45, 50),
						TextColor3 = Color3.fromRGB(220, 220, 220),
						Font = Enum.Font.GothamBold,
						TextSize = 10,
						BorderSizePixel = 0,
						[React.Event.Activated] = function() setCurrentChallenge(nil) end
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),

					Accept = e("TextButton", {
						Text = "TERIMA",
						Size = UDim2.new(0.45, 0, 1, 0),
						BackgroundColor3 = Color3.fromRGB(0, 150, 60),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						Font = Enum.Font.GothamBold,
						TextSize = 10,
						BorderSizePixel = 0,
						[React.Event.Activated] = acceptChallenge
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) })
				})
			})
		})
	})
end

return RacePanel

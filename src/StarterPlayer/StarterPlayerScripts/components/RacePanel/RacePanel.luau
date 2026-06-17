local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect

-- Helper: merge a table of child elements into an existing children table
-- Needed because React-Roblox can't render a plain table as a child node.
local function mergeChildren(base, extra)
	for k, v in pairs(extra) do
		base[k] = v
	end
	return base
end

local player = Players.LocalPlayer

-- Rarity color map
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

-- Mirror of server formula for client-side animation
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
		launchBoost = (multiplier - 1) * baseSpeed * math.min(t, 10)
	end
	local varianceAmp = (multiplier < 1.0) and 0.1 or 0.5
	local variance = math.sin(t * 0.7 + index * 1.5 + seed) * varianceAmp
	return dist + launchBoost + variance
end

-- Scan player inventory for cars
local function useOwnedCars()
	local ownedCars, setOwnedCars = useState({})
	useEffect(function()
		local function scan()
			local list = {}
			local function checkFolder(folder)
				if not folder then
					return
				end
				for _, child in ipairs(folder:GetChildren()) do
					if child:IsA("Tool") and GameUtils.isCar(child) then
						table.insert(list, {
							Name = child.Name,
							Rarity = child:GetAttribute("Rarity") or "Common",
							Variant = child:GetAttribute("Variant") or "Normal",
						})
					end
				end
			end
			checkFolder(player:FindFirstChild("Backpack"))
			checkFolder(player.Character)
			setOwnedCars(list)
		end

		scan()
		local c1 = player.CharacterAdded:Connect(scan)
		local backpack = player:WaitForChild("Backpack", 5)
		local c2 = backpack and backpack.ChildAdded:Connect(scan)
		local c3 = backpack and backpack.ChildRemoved:Connect(scan)
		return function()
			c1:Disconnect()
			if c2 then
				c2:Disconnect()
			end
			if c3 then
				c3:Disconnect()
			end
		end
	end, {})
	return ownedCars
end

-- Build car list elements (plain function, no useMemo)
local function buildCarList(ownedCars, selectedCar, setSelectedCar)
	local elements = {}
	for i, car in ipairs(ownedCars) do
		local isSelected = selectedCar
			and selectedCar.Name == car.Name
			and selectedCar.Variant == car.Variant
			and selectedCar.Rarity == car.Rarity
		local rarityColor = RarityColors[car.Rarity] or Color3.fromRGB(200, 200, 200)
		local shortName = car.Name:match("^([^%-]+)") or car.Name
		shortName = shortName:gsub("%s+$", "")

		elements["Car_" .. i] = e("TextButton", {
			Text = "",
			Size = UDim2.new(0.96, 0, 0, 46),
			BackgroundColor3 = isSelected and Color3.fromRGB(26, 32, 46) or Color3.fromRGB(22, 22, 28),
			BorderSizePixel = 0,
			[React.Event.Activated] = function()
				setSelectedCar(car)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e(
				"UIStroke",
				{ Color = isSelected and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(40, 40, 45), Thickness = 1 }
			),
			NameText = e("TextLabel", {
				Text = shortName,
				Size = UDim2.new(0.85, 0, 0.5, 0),
				Position = UDim2.new(0, 10, 0, 4),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			SubText = e("TextLabel", {
				Text = car.Variant .. " | " .. car.Rarity,
				Size = UDim2.new(0.85, 0, 0.5, 0),
				Position = UDim2.new(0, 10, 0.5, -2),
				BackgroundTransparency = 1,
				TextColor3 = rarityColor,
				Font = Enum.Font.GothamMedium,
				TextSize = 8,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})
	end
	return elements
end

-- Build 2D dot indicators on the oval track
local function buildDots(positions, raceData, playerUserId)
	if not positions or not raceData then
		return {}
	end
	local list = {}
	local Rx, Ry = 160, 62

	for key, theta in pairs(positions) do
		local part = raceData.Participants[key]
		if not part then
			continue
		end

		local dotColor
		if key == playerUserId then
			dotColor = Color3.fromRGB(0, 255, 100)
		elseif key:sub(1, 3) == "AI_" then
			local num = tonumber(key:sub(4)) or 1
			if num == 1 then
				dotColor = Color3.fromRGB(255, 50, 50)
			elseif num == 2 then
				dotColor = Color3.fromRGB(255, 200, 0)
			else
				dotColor = Color3.fromRGB(255, 130, 0)
			end
		else
			dotColor = Color3.fromRGB(0, 170, 255)
		end

		local cx = math.cos(theta) * Rx
		local cy = math.sin(theta) * Ry
		local shortName = part.Name:sub(1, 8)

		list["Dot_" .. key] = e("Frame", {
			Size = UDim2.new(0, 13, 0, 13),
			Position = UDim2.new(0.5, cx - 6, 0.5, cy - 6),
			BackgroundColor3 = dotColor,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Stroke = e("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1 }),
			Tag = e("TextLabel", {
				Text = shortName,
				Size = UDim2.new(0, 64, 0, 14),
				Position = UDim2.new(0.5, -32, 0, -18),
				BackgroundTransparency = 1,
				TextColor3 = dotColor,
				Font = Enum.Font.GothamBold,
				TextSize = 8,
				ZIndex = 6,
			}),
		})
	end
	return list
end

-- Build sorted leaderboard from live positions
local function buildLiveRanks(positions, raceData, playerUserId)
	if not positions or not raceData then
		return {}
	end
	local sorted = {}
	for key, theta in pairs(positions) do
		local part = raceData.Participants[key]
		if part then
			table.insert(sorted, { Key = key, Name = part.Name, Theta = theta })
		end
	end
	table.sort(sorted, function(a, b)
		return a.Theta > b.Theta
	end)

	local elements = {}
	for i, info in ipairs(sorted) do
		local isLocal = info.Key == playerUserId
		local lap = math.min(3, math.floor(info.Theta / (2 * math.pi)) + 1)

		-- Match color to the dot color
		local rankColor
		local key = info.Key
		if key == playerUserId then
			rankColor = Color3.fromRGB(0, 255, 100)
		elseif key:sub(1, 3) == "AI_" then
			local num = tonumber(key:sub(4)) or 1
			if num == 1 then
				rankColor = Color3.fromRGB(255, 50, 50)
			elseif num == 2 then
				rankColor = Color3.fromRGB(255, 200, 0)
			else
				rankColor = Color3.fromRGB(255, 130, 0)
			end
		else
			rankColor = Color3.fromRGB(0, 170, 255)
		end

		elements["PR_" .. i] = e("TextLabel", {
			Text = string.format("  %d. %s (Lap %d)", i, info.Name:sub(1, 12), lap),
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			TextColor3 = rankColor,
			Font = isLocal and Enum.Font.GothamBold or Enum.Font.GothamMedium,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	return elements
end

-- Build outcome podium rows
local function buildOutcomeRows(ranks, playerUserId)
	local rows = {}
	for i, rInfo in ipairs(ranks) do
		local isLocal = rInfo.Key == playerUserId
		rows["Row_" .. i] = e("Frame", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
		}, {
			Idx = e("TextLabel", {
				Text = tostring(i),
				Size = UDim2.new(0.1, 0, 1, 0),
				BackgroundTransparency = 1,
				TextColor3 = (i == 1) and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(180, 180, 180),
				Font = Enum.Font.GothamBold,
				TextSize = 14,
			}),
			Nam = e("TextLabel", {
				Text = rInfo.Name,
				Size = UDim2.new(0.55, 0, 1, 0),
				Position = UDim2.new(0.1, 0, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = isLocal and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(230, 230, 230),
				Font = isLocal and Enum.Font.GothamBold or Enum.Font.GothamMedium,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Tim = e("TextLabel", {
				Text = string.format("%.2fs", rInfo.FinishTime),
				Size = UDim2.new(0.35, 0, 1, 0),
				Position = UDim2.new(0.65, 0, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(150, 150, 155),
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		})
	end
	return rows
end

-- =========================================================
-- Main Component
-- =========================================================
local function RacePanel(props)
	local screen, setScreen = useState("Dashboard")
	local stats, setStats = useState({ Wins = 0, Losses = 0, CashEarned = 0 })
	local ownedCars = useOwnedCars()

	-- Dashboard state
	local selectedCar, setSelectedCar = useState(nil)
	local aiDifficulty, setAiDifficulty = useState("Easy")
	local opponentName, setOpponentName = useState("")
	local betAmount, setBetAmount = useState("1000")
	local notification, setNotification = useState("")
	local currentChallenge, setCurrentChallenge = useState(nil)

	-- Race state
	local raceData, setRaceData = useState(nil)
	local positions, setPositions = useState({})
	local launchMessage, setLaunchMessage = useState("")
	local launchColor, setLaunchColor = useState(Color3.fromRGB(255, 255, 255))
	local hasLaunched, setHasLaunched = useState(false)

	-- Outcome state
	local ranks, setRanks = useState({})
	local playerRank, setPlayerRank = useState(4)
	local rewardCash, setRewardCash = useState(0)

	local playerUid = tostring(player.UserId)

	local viewportSize, setViewportSize = useState(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600))
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

	-- Sync RaceStats attribute
	useEffect(function()
		local function update()
			local raw = player:GetAttribute("RaceStats")
			if raw then
				local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
				if ok and type(decoded) == "table" then
					setStats(decoded)
				end
			end
		end
		update()
		local conn = player:GetAttributeChangedSignal("RaceStats"):Connect(update)
		return function()
			conn:Disconnect()
		end
	end, {})

	-- Auto-select first car
	useEffect(function()
		if #ownedCars > 0 and selectedCar == nil then
			setSelectedCar(ownedCars[1])
		end
	end, { ownedCars })

	-- RaceEvent listener (PvP challenges / PvP race starts)
	useEffect(function()
		local raceEvent = ReplicatedStorage:WaitForChild("RaceEvent", 5)
		if not raceEvent then
			return
		end
		local conn = raceEvent.OnClientEvent:Connect(function(evtType, data)
			if evtType == "ChallengeReceived" then
				setCurrentChallenge(data)
			elseif evtType == "StartPvPRace" then
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

	-- Heartbeat: animate dots & detect finish
	useEffect(function()
		if screen ~= "Race" or not raceData then
			return
		end
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local t = workspace:GetServerTimeNow() - raceData.StartTime
			local newPos = {}
			local finished = 0
			local total = 0
			for key, part in pairs(raceData.Participants) do
				total += 1
				local idx = 1
				if key == playerUid then
					idx = 1
				elseif key:sub(1, 3) == "AI_" then
					idx = 3 + (tonumber(key:sub(4)) or 0)
				else
					idx = 2
				end

				local theta = getPositionAtTime(t, part.BaseSpeed, part.Multiplier, raceData.Seed, idx)
				newPos[key] = theta
				if theta >= 6 * math.pi then
					finished += 1
				end
			end
			setPositions(newPos)

			if t > 0 and finished >= total then
				conn:Disconnect()
				setScreen("Outcome")
				task.spawn(function()
					local ok, result = pcall(function()
						return props.raceService:fetch("getRaceOutcome", raceData.RaceId)
					end)
					if ok and result and result.Success then
						setRanks(result.Ranks or {})
						setPlayerRank(result.PlayerRank or 4)
						setRewardCash(result.RewardCash or 0)
					else
						setNotification("Gagal mengambil hasil balapan dari server")
						setScreen("Dashboard")
					end
				end)
			end
		end)
		return function()
			if conn and conn.Connected then
				conn:Disconnect()
			end
		end
	end, { screen, raceData })

	-- Handlers
	local function startAIRace()
		if not selectedCar then
			setNotification("Pilih mobil terlebih dahulu!")
			return
		end
		setNotification("Menghubungkan ke server...")
		task.spawn(function()
			local ok, result = pcall(function()
				return props.raceService:fetch("startAIRace", selectedCar, aiDifficulty)
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
			setNotification("Pilih mobil dulu!")
			return
		end
		if opponentName == "" then
			setNotification("Masukkan nama lawan!")
			return
		end
		local betNum = tonumber(betAmount) or 0
		setNotification("Mengirim tantangan...")
		task.spawn(function()
			local ok, result = pcall(function()
				return props.raceService:fetch("sendPvPChallenge", opponentName, selectedCar, betNum)
			end)
			setNotification(ok and result and (result.Message or result.Error) or "Gagal mengirim tantangan")
		end)
	end

	local function acceptChallenge()
		if not currentChallenge or not selectedCar then
			return
		end
		task.spawn(function()
			local ok, result = pcall(function()
				return props.raceService:fetch("acceptPvPChallenge", currentChallenge.ChallengeId, selectedCar)
			end)
			if not (ok and result and result.Success) then
				setNotification(result and result.Error or "Gagal menerima tantangan")
			end
		end)
	end

	local function launchCar()
		if screen ~= "Race" or not raceData or hasLaunched then
			return
		end
		setHasLaunched(true)
		local reactionTime = workspace:GetServerTimeNow() - raceData.StartTime
		task.spawn(function()
			local ok, result = pcall(function()
				return props.raceService:fetch("submitLaunchTime", raceData.RaceId, reactionTime)
			end)
			if ok and result and result.Success then
				setLaunchMessage(result.Message)
				if result.Multiplier >= 1.25 then
					setLaunchColor(Color3.fromRGB(255, 215, 0))
				elseif result.Multiplier >= 1.12 then
					setLaunchColor(Color3.fromRGB(0, 255, 100))
				elseif result.Multiplier < 1.0 then
					setLaunchColor(Color3.fromRGB(255, 50, 50))
				else
					setLaunchColor(Color3.fromRGB(200, 200, 200))
				end
				-- Update local multiplier for rendering
				local copy = {}
				for k, v in pairs(raceData) do
					copy[k] = v
				end
				copy.Participants = {}
				for k, v in pairs(raceData.Participants) do
					copy.Participants[k] = v
				end
				local myPart = copy.Participants[playerUid]
				if myPart then
					local partCopy = {}
					for k, v in pairs(myPart) do
						partCopy[k] = v
					end
					partCopy.Multiplier = result.Multiplier
					copy.Participants[playerUid] = partCopy
				end
				setRaceData(copy)
			else
				setLaunchMessage("Gagal submit launch!")
				setLaunchColor(Color3.fromRGB(255, 50, 50))
			end
		end)
	end

	-- F1 countdown lights (recomputed each render)
	local redLights = 0
	if raceData then
		local tLeft = raceData.StartTime - workspace:GetServerTimeNow()
		if tLeft <= 5 and tLeft > 4 then
			redLights = 1
		elseif tLeft <= 4 and tLeft > 3 then
			redLights = 2
		elseif tLeft <= 3 and tLeft > 2 then
			redLights = 3
		elseif tLeft <= 2 and tLeft > 1 then
			redLights = 4
		elseif tLeft <= 1 and tLeft > 0 then
			redLights = 5
		end
	end

	-- Diff button helper
	local function diffBtn(label, diffVal, color)
		local active = aiDifficulty == diffVal
		return e("TextButton", {
			Text = label,
			Size = UDim2.new(0.31, 0, 1, 0),
			BackgroundColor3 = active and color or Color3.fromRGB(26, 26, 32),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			BorderSizePixel = 0,
			[React.Event.Activated] = function()
				setAiDifficulty(diffVal)
			end,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) })
	end

	-- Sidebar tab button helper
	local function sideBtn(label, tabVal)
		local active = screen == tabVal
		return e("TextButton", {
			Text = label,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = active and Color3.fromRGB(200, 20, 50) or Color3.fromRGB(22, 22, 28),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			BorderSizePixel = 0,
			[React.Event.Activated] = function()
				if screen == "Dashboard" or screen == "Stats" then
					setScreen(tabVal)
				end
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e(
				"UIStroke",
				{ Color = active and Color3.fromRGB(255, 60, 80) or Color3.fromRGB(40, 40, 45), Thickness = 1 }
			),
		})
	end

	-- Reward description for AI
	local aiRewardText = "Reward Win: $1.000 Cash"
	if aiDifficulty == "Medium" then
		aiRewardText = "Reward Win: $5.000 Cash"
	elseif aiDifficulty == "Hard" then
		aiRewardText = "Reward Win: $25.000 Cash & +1 Level"
	end

	-- Win-rate calculation
	local totalRaces = (stats.Wins or 0) + (stats.Losses or 0)
	local winRateStr = "0.0%"
	if totalRaces > 0 then
		winRateStr = string.format("%.1f%%", (stats.Wins or 0) / totalRaces * 100)
	end

	-- =========================================================
	-- Layout helper for mobile responsiveness
	-- =========================================================
	local garageCol = e("Frame", {
		Size = isMobile and UDim2.new(1, 0, 0, 180) or UDim2.new(0.54, -7, 1, 0),
		BackgroundColor3 = Color3.fromRGB(14, 14, 20),
		BorderSizePixel = 0,
		LayoutOrder = 1,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Pad = e(
			"UIPadding",
			{
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}
		),

		GarageHeader = e("TextLabel", {
			Text = "PILIH MOBIL AKTIF (" .. #ownedCars .. ")",
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(0, 170, 255),
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		CarScroll = e(
			"ScrollingFrame",
			{
				Size = UDim2.new(1, 0, 1, -22),
				Position = UDim2.new(0, 0, 0, 22),
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(0, 0, 0, math.max(1, #ownedCars) * 52),
				ScrollBarThickness = 4,
				BorderSizePixel = 0,
			},
			mergeChildren(
				{
					List = e(
						"UIListLayout",
						{ FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 5) }
					),
				},
				buildCarList(ownedCars, selectedCar, setSelectedCar)
			)
		),
	})

	local modeCol = e("Frame", {
		Size = isMobile and UDim2.new(1, 0, 0, 310) or UDim2.new(0.46, -7, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, {
		List = e(
			"UIListLayout",
			{ FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 14) }
		),

		AICard = e("Frame", {
			Size = isMobile and UDim2.new(1, 0, 0, 140) or UDim2.new(1, 0, 0.52, -7),
			BackgroundColor3 = Color3.fromRGB(14, 14, 20),
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Pad = e(
				"UIPadding",
				{
					PaddingTop = UDim.new(0, 12),
					PaddingBottom = UDim.new(0, 12),
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}
			),
			List = e(
				"UIListLayout",
				{ FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 8) }
			),

			AIHdr = e(
				"TextLabel",
				{
					Text = "🤖 BALAPAN AI",
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(0, 220, 80),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Left,
				}
			),

			DiffRow = e(
				"Frame",
				{ Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 },
				{
					List = e(
						"UIListLayout",
						{
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 6),
						}
					),
					Easy = diffBtn("EASY", "Easy", Color3.fromRGB(0, 140, 55)),
					Med = diffBtn("MEDIUM", "Medium", Color3.fromRGB(190, 110, 0)),
					Hard = diffBtn("HARD", "Hard", Color3.fromRGB(190, 25, 35)),
				}
			),

			RewardLbl = e(
				"TextLabel",
				{
					Text = aiRewardText,
					Size = UDim2.new(1, 0, 0, 13),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(170, 170, 170),
					Font = Enum.Font.GothamMedium,
					TextSize = 9,
					TextXAlignment = Enum.TextXAlignment.Left,
				}
			),

			StartBtn = e("TextButton", {
				Text = "▶  MULAI BALAP AI",
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundColor3 = Color3.fromRGB(0, 110, 240),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				BorderSizePixel = 0,
				[React.Event.Activated] = startAIRace,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
		}),

		PvPCard = e("Frame", {
			Size = isMobile and UDim2.new(1, 0, 0, 150) or UDim2.new(1, 0, 0.48, -7),
			BackgroundColor3 = Color3.fromRGB(14, 14, 20),
			BorderSizePixel = 0,
			LayoutOrder = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Pad = e(
				"UIPadding",
				{
					PaddingTop = UDim.new(0, 12),
					PaddingBottom = UDim.new(0, 12),
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}
			),
			List = e(
				"UIListLayout",
				{ FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 8) }
			),

			PvPHdr = e(
				"TextLabel",
				{
					Text = "⚔️  TANTANG PEMAIN (PvP)",
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(220, 20, 50),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Left,
				}
			),

			OppInput = e("TextBox", {
				Text = opponentName,
				PlaceholderText = "Nama Player Lawan...",
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundColor3 = Color3.fromRGB(24, 24, 30),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				[React.Change.Text] = function(box)
					setOpponentName(box.Text)
				end,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),

			BetInput = e("TextBox", {
				Text = betAmount,
				PlaceholderText = "Jumlah taruhan Cash...",
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundColor3 = Color3.fromRGB(24, 24, 30),
				TextColor3 = Color3.fromRGB(255, 215, 0),
				PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				[React.Change.Text] = function(box)
					setBetAmount(box.Text)
				end,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),

			ChalBtn = e("TextButton", {
				Text = "⚔  KIRIM TANTANGAN",
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = Color3.fromRGB(140, 15, 40),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				BorderSizePixel = 0,
				[React.Event.Activated] = sendChallenge,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
		}),
	})

	local columnsFrame
	if isMobile then
		columnsFrame = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, (notification ~= "") and -54 or -36),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(0, 0, 0, 510),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(80, 80, 95),
		}, {
			List = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Garage = garageCol,
			Mode = modeCol,
		})
	else
		columnsFrame = e("Frame", {
			Size = UDim2.new(1, 0, 1, (notification ~= "") and -54 or -36),
			BackgroundTransparency = 1,
		}, {
			List = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 14),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Garage = garageCol,
			Mode = modeCol,
		})
	end

	-- =========================================================
	-- Render
	-- =========================================================
	return e("Frame", {
		Size = isMobile and UDim2.new(0.96, 0, 0.94, 0) or UDim2.new(0, 800, 0, 530),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(18, 18, 24),
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
		Stroke = e("UIStroke", { Color = Color3.fromRGB(50, 50, 60), Thickness = 2 }),

		-- ===== SIDEBAR =====
		Sidebar = e("Frame", {
			Size = isMobile and UDim2.new(0, 130, 1, 0) or UDim2.new(0, 175, 1, 0),
			BackgroundColor3 = Color3.fromRGB(12, 12, 16),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
			Pad = e(
				"UIPadding",
				{
					PaddingTop = UDim.new(0, 20),
					PaddingBottom = UDim.new(0, 20),
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}
			),
			List = e("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10) }),

			Logo = e("TextLabel", {
				Text = "🏁 F1 MANAGER",
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(220, 20, 50),
				Font = Enum.Font.GothamBlack,
				TextSize = isMobile and 10 or 14,
			}),
			Sep = e("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(40, 40, 48) }),

			DashBtn = sideBtn("🚀  DASHBOARD", "Dashboard"),
			StatsBtn = sideBtn("🏆  STATISTIK", "Stats"),

			Spacer = e("Frame", { Size = UDim2.new(1, 0, 1, -220), BackgroundTransparency = 1 }),

			CloseBtn = e("TextButton", {
				Text = "X  TUTUP",
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundColor3 = Color3.fromRGB(32, 32, 38),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				BorderSizePixel = 0,
				[React.Event.Activated] = props.onClose,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
		}),

		-- ===== MAIN CONTENT =====
		Content = e("Frame", {
			Size = isMobile and UDim2.new(1, -130, 1, 0) or UDim2.new(1, -175, 1, 0),
			Position = isMobile and UDim2.new(0, 130, 0, 0) or UDim2.new(0, 175, 0, 0),
			BackgroundTransparency = 1,
		}, {
			Pad = e(
				"UIPadding",
				{
					PaddingTop = UDim.new(0, 20),
					PaddingBottom = UDim.new(0, 20),
					PaddingLeft = UDim.new(0, 18),
					PaddingRight = UDim.new(0, 18),
				}
			),

			-- ===== DASHBOARD =====
			Dashboard = (screen == "Dashboard")
					and e("Frame", {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
					}, {
						List = e(
							"UIListLayout",
							{ FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 14) }
						),

						PageTitle = e("TextLabel", {
							Text = "Dashboard Balapan",
							Size = UDim2.new(1, 0, 0, 22),
							BackgroundTransparency = 1,
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Font = Enum.Font.GothamBold,
							TextSize = 18,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),

						Notif = (notification ~= "") and e("Frame", {
							Size = UDim2.new(1, 0, 0, 24),
							BackgroundColor3 = Color3.fromRGB(36, 28, 12),
							BorderSizePixel = 0,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
							Lbl = e("TextLabel", {
								Text = notification,
								Size = UDim2.new(1, -12, 1, 0),
								Position = UDim2.new(0, 6, 0, 0),
								BackgroundTransparency = 1,
								TextColor3 = Color3.fromRGB(255, 200, 50),
								Font = Enum.Font.GothamMedium,
								TextSize = 10,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
						}) or nil,

						Columns = columnsFrame,
					})
				or nil,

			-- ===== STATS =====
			Stats = (screen == "Stats")
					and e(isMobile and "ScrollingFrame" or "Frame", {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						CanvasSize = isMobile and UDim2.new(0, 0, 0, 320) or nil,
						ScrollingDirection = isMobile and Enum.ScrollingDirection.Y or nil,
						ScrollBarThickness = isMobile and 4 or nil,
					}, {
						List = e(
							"UIListLayout",
							{ FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 20) }
						),

						StatsTitle = e(
							"TextLabel",
							{
								Text = "Statistik & Rekor Balap",
								Size = UDim2.new(1, 0, 0, 22),
								BackgroundTransparency = 1,
								TextColor3 = Color3.fromRGB(255, 255, 255),
								Font = Enum.Font.GothamBold,
								TextSize = 18,
								TextXAlignment = Enum.TextXAlignment.Left,
							}
						),

						CardGrid = e("Frame", { Size = UDim2.new(1, 0, 0, isMobile and 190 or 220), BackgroundTransparency = 1 }, {
							GridLayout = e(
								"UIGridLayout",
								{
									CellSize = isMobile and UDim2.new(0.46, 0, 0, 85) or UDim2.new(0.22, 0, 0, 100),
									CellPadding = isMobile and UDim2.new(0.08, 0, 0, 10) or UDim2.new(0.04, 0, 0, 0),
									SortOrder = Enum.SortOrder.LayoutOrder,
								}
							),

							CardWins = e(
								"Frame",
								{ BackgroundColor3 = Color3.fromRGB(14, 24, 16), BorderSizePixel = 0 },
								{
									Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
									Stroke = e("UIStroke", { Color = Color3.fromRGB(40, 110, 55), Thickness = 1 }),
									LblW = e(
										"TextLabel",
										{
											Text = "WINS",
											Size = UDim2.new(1, 0, 0.4, 0),
											BackgroundTransparency = 1,
											TextColor3 = Color3.fromRGB(130, 200, 140),
											Font = Enum.Font.GothamBold,
											TextSize = 11,
										}
									),
									ValW = e(
										"TextLabel",
										{
											Text = tostring(stats.Wins or 0),
											Size = UDim2.new(1, 0, 0.6, 0),
											Position = UDim2.new(0, 0, 0.4, 0),
											BackgroundTransparency = 1,
											TextColor3 = Color3.fromRGB(255, 255, 255),
											Font = Enum.Font.GothamBlack,
											TextSize = 28,
										}
									),
								}
							),

							CardLosses = e(
								"Frame",
								{ BackgroundColor3 = Color3.fromRGB(24, 14, 16), BorderSizePixel = 0 },
								{
									Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
									Stroke = e("UIStroke", { Color = Color3.fromRGB(110, 40, 55), Thickness = 1 }),
									LblL = e(
										"TextLabel",
										{
											Text = "LOSSES",
											Size = UDim2.new(1, 0, 0.4, 0),
											BackgroundTransparency = 1,
											TextColor3 = Color3.fromRGB(200, 130, 140),
											Font = Enum.Font.GothamBold,
											TextSize = 11,
										}
									),
									ValL = e(
										"TextLabel",
										{
											Text = tostring(stats.Losses or 0),
											Size = UDim2.new(1, 0, 0.6, 0),
											Position = UDim2.new(0, 0, 0.4, 0),
											BackgroundTransparency = 1,
											TextColor3 = Color3.fromRGB(255, 255, 255),
											Font = Enum.Font.GothamBlack,
											TextSize = 28,
										}
									),
								}
							),

							CardWR = e(
								"Frame",
								{ BackgroundColor3 = Color3.fromRGB(14, 14, 24), BorderSizePixel = 0 },
								{
									Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
									Stroke = e("UIStroke", { Color = Color3.fromRGB(60, 60, 110), Thickness = 1 }),
									LblR = e(
										"TextLabel",
										{
											Text = "WIN RATE",
											Size = UDim2.new(1, 0, 0.4, 0),
											BackgroundTransparency = 1,
											TextColor3 = Color3.fromRGB(160, 160, 210),
											Font = Enum.Font.GothamBold,
											TextSize = 11,
										}
									),
									ValR = e(
										"TextLabel",
										{
											Text = winRateStr,
											Size = UDim2.new(1, 0, 0.6, 0),
											Position = UDim2.new(0, 0, 0.4, 0),
											BackgroundTransparency = 1,
											TextColor3 = Color3.fromRGB(255, 255, 255),
											Font = Enum.Font.GothamBlack,
											TextSize = 22,
										}
									),
								}
							),

							CardCash = e(
								"Frame",
								{ BackgroundColor3 = Color3.fromRGB(20, 20, 12), BorderSizePixel = 0 },
								{
									Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
									Stroke = e("UIStroke", { Color = Color3.fromRGB(110, 110, 40), Thickness = 1 }),
									LblC = e(
										"TextLabel",
										{
											Text = "CASH EARNED",
											Size = UDim2.new(1, 0, 0.4, 0),
											BackgroundTransparency = 1,
											TextColor3 = Color3.fromRGB(200, 200, 130),
											Font = Enum.Font.GothamBold,
											TextSize = 11,
										}
									),
									ValC = e(
										"TextLabel",
										{
											Text = "$" .. GameUtils.formatCompact(stats.CashEarned or 0),
											Size = UDim2.new(1, 0, 0.6, 0),
											Position = UDim2.new(0, 0, 0.4, 0),
											BackgroundTransparency = 1,
											TextColor3 = Color3.fromRGB(255, 215, 0),
											Font = Enum.Font.GothamBlack,
											TextSize = 22,
										}
									),
								}
							),
						}),
					})
				or nil,

			-- ===== ACTIVE RACE =====
			Race = (screen == "Race" and raceData ~= nil) and e(isMobile and "ScrollingFrame" or "Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = isMobile and UDim2.new(0, 0, 0, 520) or nil,
				ScrollingDirection = isMobile and Enum.ScrollingDirection.Y or nil,
				ScrollBarThickness = isMobile and 4 or nil,
			}, {
				-- Start lights bar
				LightsBar = e("Frame", {
					Size = UDim2.new(0, 220, 0, 40),
					Position = UDim2.new(0.5, -110, 0, 0),
					BackgroundColor3 = Color3.fromRGB(10, 10, 12),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 20) }),
					Stroke = e("UIStroke", { Color = Color3.fromRGB(36, 36, 44), Thickness = 1 }),
					Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }),
					Layout = e(
						"UIListLayout",
						{
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 14),
							VerticalAlignment = Enum.VerticalAlignment.Center,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
						}
					),
					L1 = e(
						"Frame",
						{
							Size = UDim2.new(0, 18, 0, 18),
							BackgroundColor3 = redLights >= 1 and Color3.fromRGB(255, 25, 35)
								or Color3.fromRGB(38, 38, 44),
						},
						{ Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }
					),
					L2 = e(
						"Frame",
						{
							Size = UDim2.new(0, 18, 0, 18),
							BackgroundColor3 = redLights >= 2 and Color3.fromRGB(255, 25, 35)
								or Color3.fromRGB(38, 38, 44),
						},
						{ Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }
					),
					L3 = e(
						"Frame",
						{
							Size = UDim2.new(0, 18, 0, 18),
							BackgroundColor3 = redLights >= 3 and Color3.fromRGB(255, 25, 35)
								or Color3.fromRGB(38, 38, 44),
						},
						{ Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }
					),
					L4 = e(
						"Frame",
						{
							Size = UDim2.new(0, 18, 0, 18),
							BackgroundColor3 = redLights >= 4 and Color3.fromRGB(255, 25, 35)
								or Color3.fromRGB(38, 38, 44),
						},
						{ Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }
					),
					L5 = e(
						"Frame",
						{
							Size = UDim2.new(0, 18, 0, 18),
							BackgroundColor3 = redLights >= 5 and Color3.fromRGB(255, 25, 35)
								or Color3.fromRGB(38, 38, 44),
						},
						{ Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }
					),
				}),

				-- Launch feedback
				LaunchMsg = (launchMessage ~= "") and e("TextLabel", {
					Text = launchMessage,
					Size = UDim2.new(1, 0, 0, 26),
					Position = UDim2.new(0, 0, 0, 46),
					BackgroundTransparency = 1,
					TextColor3 = launchColor,
					Font = Enum.Font.GothamBlack,
					TextSize = 15,
				}) or nil,

				-- 2D Circuit Map
				Circuit = e(
					"Frame",
					{
						Size = UDim2.new(0.82, 0, 0, 240),
						Position = UDim2.new(0.09, 0, 0, 78),
						BackgroundColor3 = Color3.fromRGB(14, 14, 18),
						BorderSizePixel = 0,
					},
					mergeChildren({
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
						Stroke = e("UIStroke", { Color = Color3.fromRGB(36, 36, 44), Thickness = 1 }),

						-- Oval track outline (hollow ellipse via UIStroke)
						Oval = e("Frame", {
							Size = UDim2.new(0.88, 0, 0.72, 0),
							Position = UDim2.new(0.06, 0, 0.14, 0),
							BackgroundTransparency = 1,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
							Stroke = e("UIStroke", { Color = Color3.fromRGB(65, 65, 80), Thickness = 14 }),
						}),

						-- LAUNCH button (visible while not yet launched)
						LaunchBtn = (not hasLaunched) and e("TextButton", {
							Text = "LAUNCH",
							Size = UDim2.new(0, 100, 0, 100),
							Position = UDim2.new(0.5, -50, 0.5, -50),
							BackgroundColor3 = Color3.fromRGB(0, 185, 70),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Font = Enum.Font.GothamBlack,
							TextSize = 16,
							BorderSizePixel = 0,
							[React.Event.Activated] = launchCar,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
							Stroke = e("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 2 }),
						}) or nil,
					}, buildDots(positions, raceData, playerUid))
				),

				-- Live leaderboard bar
				LiveBoard = e(
					"Frame",
					{
						Size = UDim2.new(0.82, 0, 0, 120),
						Position = UDim2.new(0.09, 0, 0, 328),
						BackgroundColor3 = Color3.fromRGB(12, 12, 16),
						BorderSizePixel = 0,
					},
					mergeChildren({
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
						Pad = e("UIPadding", {
							PaddingTop = UDim.new(0, 10),
							PaddingBottom = UDim.new(0, 10),
							PaddingLeft = UDim.new(0, 14),
							PaddingRight = UDim.new(0, 14),
						}),
						Layout = e(
							"UIListLayout",
							{
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 3),
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
							}
						),
						BoardLabel = e(
							"TextLabel",
							{
								Text = "LIVE RANK:",
								Size = UDim2.new(1, 0, 0, 16),
								BackgroundTransparency = 1,
								TextColor3 = Color3.fromRGB(100, 100, 110),
								Font = Enum.Font.GothamBold,
								TextSize = 10,
								TextXAlignment = Enum.TextXAlignment.Left,
							}
						),
					}, buildLiveRanks(positions, raceData, playerUid))
				),
			}) or nil,

			-- ===== OUTCOME =====
			Outcome = (screen == "Outcome") and e(isMobile and "ScrollingFrame" or "Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = isMobile and UDim2.new(0, 0, 0, 420) or nil,
				ScrollingDirection = isMobile and Enum.ScrollingDirection.Y or nil,
				ScrollBarThickness = isMobile and 4 or nil,
			}, {
				List = e(
					"UIListLayout",
					{
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 18),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}
				),

				OutcomeTitle = e("TextLabel", {
					Text = (playerRank == 1) and "🏆 KEMENANGAN!" or "🏁 BALAPAN SELESAI",
					Size = UDim2.new(1, 0, 0, 36),
					BackgroundTransparency = 1,
					TextColor3 = (playerRank == 1) and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(220, 220, 220),
					Font = Enum.Font.GothamBlack,
					TextSize = 24,
				}),

				PodiumBox = e(
					"Frame",
					{
						Size = UDim2.new(0.82, 0, 0, 190),
						BackgroundColor3 = Color3.fromRGB(14, 14, 18),
						BorderSizePixel = 0,
					},
					mergeChildren({
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
						Stroke = e("UIStroke", { Color = Color3.fromRGB(40, 40, 50), Thickness = 1 }),
						Pad = e(
							"UIPadding",
							{
								PaddingTop = UDim.new(0, 12),
								PaddingBottom = UDim.new(0, 12),
								PaddingLeft = UDim.new(0, 18),
								PaddingRight = UDim.new(0, 18),
							}
						),
						Rows = e(
							"UIListLayout",
							{
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 8),
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}
						),
					}, buildOutcomeRows(ranks, playerUid))
				),

				RewardLbl = (rewardCash > 0) and e("TextLabel", {
					Text = "HADIAH: +$" .. GameUtils.formatPrice(rewardCash),
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(0, 240, 100),
					Font = Enum.Font.GothamBold,
					TextSize = 14,
				}) or nil,

				BackBtn = e("TextButton", {
					Text = "← KEMBALI KE DASHBOARD",
					Size = UDim2.new(0.55, 0, 0, 34),
					BackgroundColor3 = Color3.fromRGB(0, 110, 240),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					BorderSizePixel = 0,
					[React.Event.Activated] = function()
						setScreen("Dashboard")
						setRanks({})
						setRaceData(nil)
						setPlayerRank(4)
						setRewardCash(0)
					end,
				}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
			}) or nil,
		}),

		-- ===== PvP CHALLENGE OVERLAY =====
		ChallengeOverlay = (currentChallenge ~= nil) and e("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			ZIndex = 10,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
			Modal = e("Frame", {
				Size = UDim2.new(0, 360, 0, 220),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(20, 20, 26),
				BorderSizePixel = 0,
				ZIndex = 11,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Stroke = e("UIStroke", { Color = Color3.fromRGB(200, 20, 50), Thickness = 2 }),
				Pad = e(
					"UIPadding",
					{
						PaddingTop = UDim.new(0, 18),
						PaddingBottom = UDim.new(0, 18),
						PaddingLeft = UDim.new(0, 18),
						PaddingRight = UDim.new(0, 18),
					}
				),
				MList = e(
					"UIListLayout",
					{
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 12),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}
				),

				MTitle = e(
					"TextLabel",
					{
						Text = "⚔️ TANTANGAN BALAPAN!",
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(220, 20, 50),
						Font = Enum.Font.GothamBold,
						TextSize = 14,
						ZIndex = 12,
					}
				),

				MDesc = e("TextLabel", {
					Text = string.format(
						"%s menantang Anda! Taruhan: $%s",
						tostring(currentChallenge.ChallengerName),
						GameUtils.formatPrice(currentChallenge.BetAmount)
					),
					Size = UDim2.new(1, 0, 0, 55),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(210, 210, 210),
					Font = Enum.Font.GothamMedium,
					TextSize = 11,
					TextWrapped = true,
					ZIndex = 12,
				}),

				MBtns = e("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, ZIndex = 12 }, {
					BtnList = e(
						"UIListLayout",
						{
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 16),
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
						}
					),
					Decline = e("TextButton", {
						Text = "TOLAK",
						Size = UDim2.new(0.4, 0, 1, 0),
						BackgroundColor3 = Color3.fromRGB(38, 38, 44),
						TextColor3 = Color3.fromRGB(200, 200, 200),
						Font = Enum.Font.GothamBold,
						TextSize = 10,
						BorderSizePixel = 0,
						ZIndex = 12,
						[React.Event.Activated] = function()
							setCurrentChallenge(nil)
						end,
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
					Accept = e("TextButton", {
						Text = "TERIMA",
						Size = UDim2.new(0.4, 0, 1, 0),
						BackgroundColor3 = Color3.fromRGB(0, 140, 60),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						Font = Enum.Font.GothamBold,
						TextSize = 10,
						BorderSizePixel = 0,
						ZIndex = 12,
						[React.Event.Activated] = acceptChallenge,
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
				}),
			}),
		}) or nil,
	})
end

return RacePanel

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local React = require(ReplicatedStorage.Packages.React)
local PitStopMinigame = require(script.Parent.PitStopMinigame)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local player = Players.LocalPlayer

local function TeamManagerModal(props: {
	IsMobile: boolean,
	OnClose: () -> (),
})
	local teamData, setTeamData = useState({ Driver1 = "", Driver2 = "", Strategy = "Balanced", PitBuff = 0 })
	local ownedCars, setOwnedCars = useState({} :: { string })
	local showPitGame, setShowPitGame = useState(false)

	local function updateTeamState()
		local attr = player:GetAttribute("TeamManager")
		if attr then
			local success, decoded = pcall(HttpService.JSONDecode, HttpService, attr)
			if success and typeof(decoded) == "table" then
				setTeamData(decoded)
			end
		end

		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			local list = {}
			for _, item in ipairs(backpack:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute("Type") == "Car" then
					table.insert(list, item.Name)
				end
			end
			setOwnedCars(list)
		end
	end

	useEffect(function()
		updateTeamState()
		local conn = player.AttributeChanged:Connect(function(attrName)
			if attrName == "TeamManager" then
				updateTeamState()
			end
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	return e("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 0.55,
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		Active = true,
		ZIndex = 25,
	}, {
		BackdropClose = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 1,
			[React.Event.Activated] = props.OnClose,
		}),

		Modal = e("Frame", {
			Size = props.IsMobile and UDim2.new(0.85, 0, 0.85, 0) or UDim2.fromOffset(480, 340),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(15, 15, 18),
			Active = true,
			ZIndex = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Stroke = e("UIStroke", { Color = Color3.fromRGB(0, 255, 204), Thickness = 1.2 }),

			Header = e("Frame", {
				Size = UDim2.new(1, -30, 0, 30),
				Position = UDim2.new(0.5, 0, 0, 15),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
			}, {
				Title = e("TextLabel", {
					Text = "🏎️ F1 TEAM MANAGER",
					Size = UDim2.new(0.7, 0, 1, 0),
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
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					[React.Event.Activated] = props.OnClose,
				}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
			}),

			StatusCard = e("Frame", {
				Size = UDim2.new(1, -30, 0, 220),
				Position = UDim2.new(0.5, 0, 0, 55),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.fromRGB(22, 22, 28),
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				InfoText = e("TextLabel", {
					Text = `Driver 1: {teamData.Driver1 ~= "" and teamData.Driver1 or "Belum Dipilih"}\nDriver 2: {teamData.Driver2 ~= "" and teamData.Driver2 or "Belum Dipilih"}\nStrategi: {teamData.Strategy} | Pit Buff: +{teamData.PitBuff}%`,
					Size = UDim2.fromScale(0.9, 0.6),
					Position = UDim2.fromScale(0.5, 0.35),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(0, 255, 204),
					TextSize = 11,
					Font = Enum.Font.GothamBold,
				}),
				PitBtn = e("TextButton", {
					Text = "🔧 MAIN PIT STOP MINIGAME",
					Size = UDim2.new(0.8, 0, 0, 28),
					Position = UDim2.new(0.5, 0, 0.82, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 130, 0),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					[React.Event.Activated] = function()
						setShowPitGame(true)
					end,
				}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
			}),

			PitOverlay = showPitGame and e(PitStopMinigame, {
				OnComplete = function(bonus)
					setShowPitGame(false)
					setTeamData(function(prev)
						local newT = table.clone(prev)
						newT.PitBuff = (newT.PitBuff or 0) + bonus
						return newT
					end)
				end,
			}) or nil,
		}),
	})
end

return TeamManagerModal

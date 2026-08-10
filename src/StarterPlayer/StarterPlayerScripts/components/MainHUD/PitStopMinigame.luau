local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local useState = React.useState

local player = Players.LocalPlayer

local function PitStopMinigame(props: {
	OnComplete: (bonusPercent: number) -> (),
})
	local progress, setProgress = useState(0)
	local isFinished, setIsFinished = useState(false)

	local function handleTap()
		if isFinished then return end
		local newProgress = math.min(100, progress + 20)
		setProgress(newProgress)
		if newProgress >= 100 then
			setIsFinished(true)
			props.OnComplete(25) -- Grant +25% pit strategy speed buff
		end
	end

	return e("Frame", {
		Size = UDim2.fromOffset(260, 140),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(18, 18, 22),
		ZIndex = 40,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", { Color = Color3.fromRGB(255, 130, 0), Thickness = 1.2 }),

		Title = e("TextLabel", {
			Text = "⚙️ PIT STOP SPEED RUN!",
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 0, 10),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(255, 130, 0),
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),

		BarBackground = e("Frame", {
			Size = UDim2.new(0.85, 0, 0, 18),
			Position = UDim2.new(0.5, 0, 0.45, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(30, 30, 35),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 5) }),
			Fill = e("Frame", {
				Size = UDim2.new(progress / 100, 0, 1, 0),
				BackgroundColor3 = Color3.fromRGB(0, 255, 204),
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 5) }) }),
		}),

		TapBtn = e("TextButton", {
			Text = isFinished and "SELESAI! (+25% BUFF)" or "TEKAN CEPAT GANTI BAN! 🔧",
			Size = UDim2.new(0.85, 0, 0, 32),
			Position = UDim2.new(0.5, 0, 0.8, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = isFinished and Color3.fromRGB(0, 255, 204) or Color3.fromRGB(255, 35, 85),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			[React.Event.Activated] = handleTap,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }) }),
	})
end

return PitStopMinigame

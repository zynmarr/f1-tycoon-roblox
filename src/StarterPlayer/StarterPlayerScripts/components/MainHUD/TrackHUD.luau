local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect

local player = Players.LocalPlayer

local function TrackHUD(props: { IsMobile: boolean })
	local currentSpeed, setCurrentSpeed = useState(0)
	local lapTime, setLapTime = useState(0)
	local isDriving, setIsDriving = useState(false)

	useEffect(function()
		local connection = RunService.RenderStepped:Connect(function(dt)
			local character = player.Character
			if not character then
				setIsDriving(false)
				return
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local seat = humanoid and humanoid.SeatPart

			if seat and (seat:IsA("VehicleSeat") or seat.Name == "DriveSeat") then
				setIsDriving(true)
				local carModel = seat:FindFirstAncestorOfClass("Model")
				local driveSpeed = carModel and (carModel:GetAttribute("DriveSpeed") or carModel:GetAttribute("Speed")) or 120
				setCurrentSpeed(driveSpeed)
				setLapTime(function(prev) return prev + dt end)
			else
				setIsDriving(false)
				setLapTime(0)
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	if not isDriving then
		return nil
	end

	local minutes = math.floor(lapTime / 60)
	local seconds = lapTime % 60
	local lapTimeString = string.format("%02d:%05.2f", minutes, seconds)

	return e("Frame", {
		Size = UDim2.fromOffset(220, 75),
		Position = UDim2.new(0.5, 0, 0.92, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(15, 15, 20),
		BackgroundTransparency = 0.2,
		ZIndex = 30,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(0, 255, 204),
			Thickness = 1.2,
		}),

		-- Speed display
		SpeedLabel = e("TextLabel", {
			Text = `⚡ {currentSpeed} KM/H`,
			Size = UDim2.new(1, 0, 0.5, 0),
			Position = UDim2.new(0, 0, 0.05, 0),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(0, 255, 204),
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),

		-- Lap timer display
		LapLabel = e("TextLabel", {
			Text = `⏱ LAP: {lapTimeString}`,
			Size = UDim2.new(1, 0, 0.4, 0),
			Position = UDim2.new(0, 0, 0.55, 0),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(240, 240, 240),
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
	})
end

return TrackHUD

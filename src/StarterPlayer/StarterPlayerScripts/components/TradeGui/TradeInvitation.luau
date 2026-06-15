--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local Event = (React :: any).Event
local useState = React.useState
local useEffect = React.useEffect

type TradeInvitationProps = {
	senderName: string,
	onAccept: () -> (),
	onDecline: () -> (),
}

return function(props: TradeInvitationProps)
	local timeLeft, setTimeLeft = useState(15)

	useEffect(function()
		local active = true
		task.spawn(function()
			while active and timeLeft > 0 do
				task.wait(1)
				if not active then break end
				local nextVal = 0
				setTimeLeft(function(prev: number)
					nextVal = prev - 1
					return nextVal
				end)
				if nextVal <= 0 then
					props.onDecline()
					break
				end
			end
		end)
		return function()
			active = false
		end
	end, {})

	return e("Frame", {
		Size = UDim2.new(0.3, 0, 0.25, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.4, 0),
		BackgroundColor3 = Color3.fromRGB(15, 15, 20),
		BorderSizePixel = 0,
		ZIndex = 30,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Stroke = e("UIStroke", { Color = Color3.fromRGB(0, 180, 255), Thickness = 1.5 }),
		SizeConstraint = e("UISizeConstraint", { MaxSize = Vector2.new(350, 160) }),

		-- Title/Header
		Header = e("Frame", {
			Size = UDim2.new(1, 0, 0, 35),
			BackgroundColor3 = Color3.fromRGB(22, 22, 28),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Title = e("TextLabel", {
				Text = "🤝 UNDANGAN PERTUKARAN",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		}),

		-- Body text
		Body = e("TextLabel", {
			Text = string.format("<b>%s</b> mengajak Anda untuk bertukar mobil.", props.senderName),
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.new(0, 10, 0, 45),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(220, 220, 230),
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			RichText = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),

		-- Timer Text / Progress Bar container
		TimerContainer = e("Frame", {
			Size = UDim2.new(1, -40, 0, 6),
			Position = UDim2.new(0, 20, 0, 85),
			BackgroundColor3 = Color3.fromRGB(30, 30, 40),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
			Bar = e("Frame", {
				Size = UDim2.new(timeLeft / 15, 0, 1, 0),
				BackgroundColor3 = Color3.fromRGB(0, 220, 255),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 3) })
			})
		}),
		
		TimerText = e("TextLabel", {
			Text = string.format("Otomatis menolak dalam %ds", timeLeft),
			Size = UDim2.new(1, -20, 0, 12),
			Position = UDim2.new(0, 10, 0, 95),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(150, 150, 160),
			Font = Enum.Font.Gotham,
			TextSize = 8,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),

		-- Buttons
		ButtonContainer = e("Frame", {
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.new(0, 10, 0, 115),
			BackgroundTransparency = 1,
		}, {
			Decline = e("TextButton", {
				Text = "TOLAK",
				Size = UDim2.new(0.46, 0, 1, 0),
				BackgroundColor3 = Color3.fromRGB(55, 30, 30),
				TextColor3 = Color3.fromRGB(255, 100, 100),
				Font = Enum.Font.GothamBold,
				TextSize = 9,
				BorderSizePixel = 0,
				[Event.Activated] = props.onDecline,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) })
			}),

			Accept = e("TextButton", {
				Text = "TERIMA",
				Size = UDim2.new(0.46, 0, 1, 0),
				Position = UDim2.new(0.54, 0, 0, 0),
				BackgroundColor3 = Color3.fromRGB(0, 120, 200),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 9,
				BorderSizePixel = 0,
				[Event.Activated] = props.onAccept,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) })
			})
		})
	})
end

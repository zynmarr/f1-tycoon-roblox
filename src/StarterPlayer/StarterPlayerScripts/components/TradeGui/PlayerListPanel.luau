local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local Event = (React :: any).Event
local useState = React.useState
local useEffect = React.useEffect

type PlayerListPanelProps = {
	onClose: () -> (),
	onInvite: (playerName: string) -> (),
}

type PlayerInfo = {
	Player: Player,
	Name: string,
	Rebirths: number,
}

local function getRebirthCount(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local rebirthVal = leaderstats and leaderstats:FindFirstChild("Rebirth") :: IntValue?
	return rebirthVal and rebirthVal.Value or 0
end

return function(props: PlayerListPanelProps)
	local playersList, setPlayersList = useState(Players:GetPlayers())

	useEffect(function()
		local function updateList()
			setPlayersList(Players:GetPlayers())
		end

		local conn1 = Players.PlayerAdded:Connect(updateList)
		local conn2 = Players.PlayerRemoving:Connect(updateList)

		-- Periodic check for rebirth changes
		local active = true
		task.spawn(function()
			while active do
				task.wait(2)
				if not active then
					break
				end
				updateList()
			end
		end)

		return function()
			active = false
			conn1:Disconnect()
			conn2:Disconnect()
		end
	end, {})

	local otherPlayers: { PlayerInfo } = {}
	for _, p in ipairs(playersList) do
		if p ~= Players.LocalPlayer then
			table.insert(otherPlayers, {
				Player = p,
				Name = p.Name,
				Rebirths = getRebirthCount(p),
			})
		end
	end

	local function renderPlayerRows()
		local childrenTable = {
			Layout = e("UIListLayout", {
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}

		for index, info in ipairs(otherPlayers) do
			local meetsRequirement = info.Rebirths >= 5

			childrenTable[info.Name] = e("Frame", {
				key = info.Name,
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = Color3.fromRGB(22, 22, 28),
				BorderSizePixel = 0,
				LayoutOrder = index,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),

				-- Info container
				Info = e("Frame", {
					Size = UDim2.new(0.65, 0, 1, 0),
					BackgroundTransparency = 1,
				}, {
					NameText = e("TextLabel", {
						Text = info.Name,
						Size = UDim2.new(1, -15, 0.5, 0),
						Position = UDim2.new(0, 10, 0.1, 0),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(240, 240, 245),
						Font = Enum.Font.GothamBold,
						TextSize = 10,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					RebirthText = e("TextLabel", {
						Text = string.format("Rebirth: %d", info.Rebirths),
						Size = UDim2.new(1, -15, 0.4, 0),
						Position = UDim2.new(0, 10, 0.5, 0),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(0, 220, 255),
						Font = Enum.Font.GothamMedium,
						TextSize = 8,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				}),

				-- Action Button
				InviteBtn = e("TextButton", {
					Text = meetsRequirement and "🤝 AJAK TRADE" or "🔒 MIN. 5",
					Size = UDim2.new(0.3, 0, 0.7, 0),
					Position = UDim2.new(0.67, 0, 0.15, 0),
					BackgroundColor3 = meetsRequirement and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(40, 40, 45),
					TextColor3 = meetsRequirement and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 120, 125),
					Font = Enum.Font.GothamBold,
					TextSize = 8,
					BorderSizePixel = 0,
					Active = meetsRequirement,
					[Event.Activated] = function()
						if meetsRequirement then
							props.onInvite(info.Name)
						end
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				}),
			})
		end

		if #otherPlayers == 0 then
			childrenTable.NoPlayers = e("TextLabel", {
				Text = "Tidak ada pemain lain di server",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(120, 120, 130),
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
			})
		end

		return childrenTable
	end

	return e("Frame", {
		Size = UDim2.new(0.85, 0, 0.75, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(15, 15, 20),
		BorderSizePixel = 0,
		ZIndex = 25,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Stroke = e("UIStroke", { Color = Color3.fromRGB(45, 45, 55), Thickness = 1.5 }),
		SizeConstraint = e("UISizeConstraint", {
			MinSize = Vector2.new(240, 180),
			MaxSize = Vector2.new(380, 320),
		}),

		-- HEADER
		Header = e("Frame", {
			Size = UDim2.new(1, 0, 0, 35),
			BackgroundColor3 = Color3.fromRGB(22, 22, 28),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Title = e("TextLabel", {
				Text = "🤝 MULAI TRADING",
				Size = UDim2.new(0.7, 0, 1, 0),
				Position = UDim2.new(0, 15, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			CloseBtn = e("TextButton", {
				Text = "✕",
				Size = UDim2.fromOffset(24, 24),
				Position = UDim2.new(1, -15, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 35, 85),
				BackgroundTransparency = 0.1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				AutoButtonColor = true,
				[Event.Activated] = props.onClose,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(255, 100, 120),
					Thickness = 0.8,
				}),
			}),
		}),

		-- PLAYER SCROLL LIST
		ScrollList = e("ScrollingFrame", {
			Size = UDim2.new(1, -20, 1, -55),
			Position = UDim2.new(0, 10, 0, 45),
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Color3.fromRGB(60, 60, 75),
		}, renderPlayerRows()),
	})
end

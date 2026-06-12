--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RoleManager = require(ServerScriptService:WaitForChild("RoleManager"):WaitForChild("RoleManager"))
local RoleConfig = require(ReplicatedStorage:WaitForChild("RoleConfig"))

-- Membuat dan memasang overhead UI di atas kepala player
local function createOverhead(player: Player, character: Model)
	local head = character:WaitForChild("Head", 5)
	if not head then
		return
	end

	-- Hapus overhead lama agar tidak duplikat
	local oldOverhead = head:FindFirstChild("OverheadGui")
	if oldOverhead then
		oldOverhead:Destroy()
	end

	local roleName = RoleManager.getPlayerRole(player)
	local roleData = RoleConfig.Roles[roleName]
	if not roleData then
		return
	end

	-- Buat BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OverheadGui"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120 -- Biar tidak terlalu ramai dari kejauhan
	billboard.Parent = head

	-- Main Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = billboard

	if roleName == "Player" then
		billboard.Size = UDim2.new(0, 160, 0, 30)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0) -- Ketinggian lebih rendah untuk text biasa
		
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "PlayerName"
		nameLabel.Size = UDim2.new(1, 0, 1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = player.DisplayName
		nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 15
		nameLabel.TextStrokeTransparency = 0.35
		nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		nameLabel.Parent = frame
	else
		billboard.Size = UDim2.new(0, 190, 0, 62)
		billboard.StudsOffset = Vector3.new(0, 3.3, 0) -- Lebih tinggi untuk menampung card premium
		
		-- Background Card Frame (Premium Glassmorphism Effect)
		local card = Instance.new("Frame")
		card.Name = "Card"
		card.Size = UDim2.new(1, 0, 1, 0)
		card.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
		card.BackgroundTransparency = 0.25 -- Transparan bergaya kaca gelap
		card.Parent = frame
		
		-- Rounded Corners
		local uiCorner = Instance.new("UICorner")
		uiCorner.CornerRadius = UDim.new(0, 10)
		uiCorner.Parent = card
		
		-- Glowing Gradient Outline
		local uiStroke = Instance.new("UIStroke")
		uiStroke.Thickness = 1.8
		uiStroke.Color = roleData.Color
		uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		uiStroke.Parent = card
		
		-- Gradient berkilau pada border outline
		local strokeGradient = Instance.new("UIGradient")
		local baseColor = roleData.Color
		strokeGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, baseColor),
			ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 255, 255)), -- titik berkilau
			ColorSequenceKeypoint.new(0.6, baseColor),
			ColorSequenceKeypoint.new(1.0, baseColor),
		})
		strokeGradient.Parent = uiStroke
		
		-- Tag agar client-side script dapat mendeteksi dan menganimasikan rotasi gradasi ini
		local CollectionService = game:GetService("CollectionService")
		CollectionService:AddTag(strokeGradient, "RotatingGradient")
		
		-- UIListLayout untuk penataan item di dalam card
		local listLayout = Instance.new("UIListLayout")
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Padding = UDim.new(0, 3)
		listLayout.Parent = card
		
		-- Pill Frame untuk Role Tag
		local pill = Instance.new("Frame")
		pill.Name = "RolePill"
		pill.AutomaticSize = Enum.AutomaticSize.XY
		pill.Size = UDim2.new(0, 0, 0, 18)
		pill.BackgroundColor3 = roleData.Color
		pill.BackgroundTransparency = 0.85 -- Transparan tipis sewarna role
		pill.LayoutOrder = 1
		pill.Parent = card
		
		local pillCorner = Instance.new("UICorner")
		pillCorner.CornerRadius = UDim.new(0, 9)
		pillCorner.Parent = pill
		
		local pillStroke = Instance.new("UIStroke")
		pillStroke.Thickness = 1
		pillStroke.Color = roleData.Color
		pillStroke.Transparency = 0.4
		pillStroke.Parent = pill
		
		local pillPadding = Instance.new("UIPadding")
		pillPadding.PaddingLeft = UDim.new(0, 8)
		pillPadding.PaddingRight = UDim.new(0, 8)
		pillPadding.PaddingTop = UDim.new(0, 1)
		pillPadding.PaddingBottom = UDim.new(0, 1)
		pillPadding.Parent = pill
		
		-- Role Text Label di dalam Pill
		local roleLabel = Instance.new("TextLabel")
		roleLabel.Name = "RoleLabel"
		roleLabel.BackgroundTransparency = 1
		roleLabel.Text = (roleData.Emoji ~= "" and roleData.Emoji .. " " or "") .. string.upper(roleData.DisplayName)
		roleLabel.TextColor3 = roleData.Color
		roleLabel.Font = Enum.Font.GothamBold
		roleLabel.TextSize = 10
		roleLabel.Size = UDim2.new(0, 0, 1, 0)
		roleLabel.AutomaticSize = Enum.AutomaticSize.X
		roleLabel.Parent = pill
		
		-- Gradasi teks agar role berkilau
		local textGradient = Instance.new("UIGradient")
		textGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, roleData.Color),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1.0, roleData.Color),
		})
		textGradient.Parent = roleLabel
		CollectionService:AddTag(textGradient, "ShimmeringGradient")
		
		-- Player Name Label di dalam Card
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "PlayerName"
		nameLabel.Size = UDim2.new(0.9, 0, 0, 18)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = player.DisplayName
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 13
		nameLabel.TextStrokeTransparency = 0.5
		nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		nameLabel.LayoutOrder = 2
		nameLabel.Parent = card
	end
end

-- Hubungkan listener untuk setup character
local function setupPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		createOverhead(player, character)
	end)

	player:GetAttributeChangedSignal("Role"):Connect(function()
		local character = player.Character
		if character then
			createOverhead(player, character)
		end
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
	if player.Character then
		task.spawn(createOverhead, player, player.Character)
	end
end

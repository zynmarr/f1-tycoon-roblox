--!strict
local OverheadManager = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

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

	local customColorHex = player:GetAttribute("CustomNameColor") :: string?
	local customColor: Color3? = nil
	if customColorHex and typeof(customColorHex) == "string" and customColorHex ~= "" then
		pcall(function()
			customColor = Color3.fromHex(customColorHex)
		end)
	end

	if roleName == "Player" then
		billboard.Size = UDim2.new(0, 300, 0, 30)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0) -- Ketinggian lebih rendah untuk text biasa

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "PlayerName"
		nameLabel.Size = UDim2.new(1, 0, 1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = player.DisplayName
		nameLabel.TextColor3 = customColor or Color3.fromRGB(240, 240, 240)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 15
		nameLabel.TextScaled = false
		nameLabel.TextStrokeTransparency = 0.35
		nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		nameLabel.Parent = frame
	else
		billboard.Size = UDim2.new(0, 300, 0, 30)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0) -- Ketinggian sama dengan player biasa karena sebaris

		-- UI List Layout untuk susunan horizontal sebaris tanpa bingkai
		local listLayout = Instance.new("UIListLayout")
		listLayout.FillDirection = Enum.FillDirection.Horizontal
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Padding = UDim.new(0, 6)
		listLayout.Parent = frame

		-- Label Nama Player
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "PlayerName"
		nameLabel.AutomaticSize = Enum.AutomaticSize.XY
		nameLabel.Size = UDim2.new(0, 0, 1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = player.DisplayName
		nameLabel.TextColor3 = customColor or Color3.fromRGB(255, 255, 255)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 15
		nameLabel.TextScaled = false
		nameLabel.TextStrokeTransparency = 0.35
		nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		nameLabel.LayoutOrder = 1
		nameLabel.Parent = frame

		-- Label Tag Role di samping nama (Contoh: [⚡ OWNER])
		local roleLabel = Instance.new("TextLabel")
		roleLabel.Name = "RoleLabel"
		roleLabel.AutomaticSize = Enum.AutomaticSize.XY
		roleLabel.Size = UDim2.new(0, 0, 1, 0)
		roleLabel.BackgroundTransparency = 1
		local roleText = string.format(
			"[%s%s]",
			roleData.Emoji ~= "" and roleData.Emoji .. " " or "",
			string.upper(roleData.DisplayName)
		)
		roleLabel.Text = roleText
		roleLabel.TextColor3 = roleData.Color
		roleLabel.Font = Enum.Font.GothamBold
		roleLabel.TextSize = 15
		roleLabel.TextScaled = false
		roleLabel.TextStrokeTransparency = 0.35
		roleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		roleLabel.LayoutOrder = 2
		roleLabel.Parent = frame

		-- UIGradient untuk menganimasikan efek role masing-masing di client
		local roleGradient = Instance.new("UIGradient")
		roleGradient.Name = "RoleGradient"
		local baseColor = roleData.Color
		roleGradient.Color = ColorSequence.new(baseColor)
		roleGradient.Parent = roleLabel

		-- Tandai dengan CollectionService agar client-side mendeteksi dan memberi animasi custom
		CollectionService:AddTag(roleGradient, "RoleGradient")
		roleGradient:SetAttribute("RoleName", roleName)
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

	player:GetAttributeChangedSignal("CustomNameColor"):Connect(function()
		local character = player.Character
		if character then
			createOverhead(player, character)
		end
	end)
end

function OverheadManager.Init()
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(setupPlayer, player)
		if player.Character then
			task.spawn(createOverhead, player, player.Character)
		end
	end
end

return OverheadManager

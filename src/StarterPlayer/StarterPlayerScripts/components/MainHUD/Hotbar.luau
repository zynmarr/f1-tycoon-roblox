local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage.Packages.React)
local ViewportManager = require(script.Parent.Parent.ViewportManager)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

local player = Players.LocalPlayer

local function Hotbar(props: { IsMobile: boolean, InventoryOpen: boolean })
	local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		warn("[Hotbar] Backpack tidak ditemukan!")
		return nil
	end

	local maxSlots = props.IsMobile and 5 or 9
	local cache = useRef(nil)
	if not cache.current then
		cache.current = ViewportManager.new()
	end

	-- State untuk melacak item yang sedang dipegang & item di tas
	local heldTool, setHeldTool = useState(nil :: any)
	local _toolsList, setToolsList = useState({} :: {any})

	-- State slot mapping: [slotIndex] = Tool
	local slotMapping, setSlotMapping = useState({} :: { [number]: any })

	-- ===== 1. DETEKSI TOOLS DI CHARACTER DAN BACKPACK =====
	local function refreshTools()
		local char = player.Character
		local currentHeld = char and char:FindFirstChildOfClass("Tool")
		setHeldTool(currentHeld)

		local list = {}
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") then
				table.insert(list, item)
			end
		end
		if currentHeld then
			table.insert(list, currentHeld)
		end
		setToolsList(list)

		-- Update slot mapping secara cerdas (pastikan tool masih ada)
		setSlotMapping(function(oldMapping)
			local newMapping = table.clone(oldMapping)
			-- Hapus mapping jika tool tidak lagi dimiliki
			for i = 1, maxSlots do
				local tool = newMapping[i]
				if tool then
					if not tool.Parent or (tool.Parent ~= backpack and tool.Parent ~= char) then
						newMapping[i] = nil
					end
				end
			end
			-- Masukkan tool baru yang belum ter-map ke slot kosong
			for _, tool in ipairs(list) do
				local alreadyMapped = false
				for i = 1, maxSlots do
					if newMapping[i] == tool then
						alreadyMapped = true
						break
					end
				end
				if not alreadyMapped then
					for i = 1, maxSlots do
						if not newMapping[i] then
							newMapping[i] = tool
							break
						end
					end
				end
			end
			return newMapping
		end)
	end

	useEffect(function()
		local connections: { RBXScriptConnection } = {}

		-- Pantau Backpack
		table.insert(connections, backpack.ChildAdded:Connect(refreshTools))
		table.insert(connections, backpack.ChildRemoved:Connect(refreshTools))

		-- Pantau Character (untuk held tool)
		local function setupChar(char)
			table.insert(connections, char.ChildAdded:Connect(refreshTools))
			table.insert(connections, char.ChildRemoved:Connect(refreshTools))
			refreshTools()
		end

		table.insert(connections, player.CharacterAdded:Connect(setupChar))
		if player.Character then
			setupChar(player.Character)
		end

		refreshTools()

		return function()
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
			if cache.current then
				ViewportManager.clearAllCache(cache.current)
			end
		end
	end, {maxSlots})

	-- ===== 2. SHORTCUT KEYBOARD (1-9) UNTUK EQUIP TOOL =====
	useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then return end
			local num = nil
			if input.KeyCode == Enum.KeyCode.One then num = 1
			elseif input.KeyCode == Enum.KeyCode.Two then num = 2
			elseif input.KeyCode == Enum.KeyCode.Three then num = 3
			elseif input.KeyCode == Enum.KeyCode.Four then num = 4
			elseif input.KeyCode == Enum.KeyCode.Five then num = 5
			elseif input.KeyCode == Enum.KeyCode.Six and maxSlots >= 6 then num = 6
			elseif input.KeyCode == Enum.KeyCode.Seven and maxSlots >= 7 then num = 7
			elseif input.KeyCode == Enum.KeyCode.Eight and maxSlots >= 8 then num = 8
			elseif input.KeyCode == Enum.KeyCode.Nine and maxSlots >= 9 then num = 9
			end

			if num then
				local tool = slotMapping[num]
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum and tool then
					if tool.Parent == char then
						hum:UnequipTools()
					else
						hum:EquipTool(tool)
					end
				end
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, {slotMapping, maxSlots})

	-- Fungsi penanganan klik slot
	local function handleSlotClick(tool: Tool?)
		if not tool then return end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			if tool.Parent == char then
				hum:UnequipTools()
			else
				hum:EquipTool(tool)
			end
		end
	end

	-- Matikan default backpack core UI
	useEffect(function()
		task.spawn(function()
			local success
			repeat
				success = pcall(function()
					game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
				end)
				task.wait(0.5)
			until success
		end)
	end, {})

	-- Render daftar slot hotbar
	local slotElements = {}
	for i = 1, maxSlots do
		local tool = slotMapping[i]
		local isSlotEquipped = (tool ~= nil and tool == heldTool)
		local slotName = "Slot" .. i

		slotElements[slotName] = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = isSlotEquipped and Color3.fromRGB(80, 40, 180) or Color3.fromRGB(20, 20, 25),
			BackgroundTransparency = 0.35,
			LayoutOrder = i,
			Text = "",
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				handleSlotClick(tool)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Color = isSlotEquipped and Color3.fromRGB(150, 80, 255) or Color3.fromRGB(70, 70, 85),
				Thickness = 1,
			}),

			-- Angka Slot
			SlotNumber = e("TextLabel", {
				Text = tostring(i),
				Size = UDim2.fromOffset(12, 12),
				Position = UDim2.fromOffset(4, 4),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextSize = 8,
				Font = Enum.Font.GothamBold,
			}),

			-- Render 3D Model Viewport
			CarView = tool and e("ViewportFrame", {
				Size = UDim2.fromScale(0.9, 0.9),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ref = function(rbx: any)
					if rbx then
						ViewportManager.setupViewport(cache.current, rbx, tool, { bgTransparency = 1 })
					end
				end,
			}) or nil,

			-- Nama Item (Hanya tampil jika ada tool)
			ItemName = tool and e("TextLabel", {
				Text = tool:GetAttribute("Name") or tool.Name,
				Size = UDim2.new(1, -6, 0, 10),
				Position = UDim2.new(0.5, 0, 1, -12),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 6,
				Font = Enum.Font.GothamMedium,
				TextWrapped = true,
			}) or nil,

			-- Jumlah Item
			ItemAmount = tool and e("TextLabel", {
				Text = "x" .. tostring(tool:GetAttribute("Amount") or 1),
				Size = UDim2.fromOffset(25, 12),
				Position = UDim2.new(1, -27, 0, 4),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(0, 255, 204),
				TextSize = 8,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Right,
			}) or nil,
		})
	end

	-- Menyembunyikan hotbar jika inventory modal sedang dibuka
	if props.InventoryOpen then
		return nil
	end

	local children = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for name, element in pairs(slotElements) do
		children[name] = element
	end

	return e("Frame", {
		Size = UDim2.new(0, maxSlots * (props.IsMobile and 50 or 60) + (maxSlots - 1) * 8, 0, props.IsMobile and 45 or 55),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, children)
end

return Hotbar

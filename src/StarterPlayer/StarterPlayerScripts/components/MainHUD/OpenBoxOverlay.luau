local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

local player = Players.LocalPlayer
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Networker = require(Packages.Networker)
local openBoxService = Networker.client.new("OpenBox", {})

local function OpenBoxOverlay(props: { IsMobile: boolean })
	local heldBox, setHeldBox = useState(nil :: any)
	local isOpening, setIsOpening = useState(false)
	local tweenRef = useRef(nil)

	-- Deteksi apakah tool yang di-equip adalah box
	local function checkIfBox(tool: any): boolean
		if not tool then
			return false
		end
		return CollectionService:HasTag(tool, "Box")
			or tool:GetAttribute("Type") == "Box"
			or string.find(tool.Name:lower(), "box") ~= nil
			or tool:GetAttribute("Level") ~= nil
	end

	-- Pantau character equip/unequip tool
	useEffect(function()
		local connections = {}

		local function refreshHeldTool()
			local char = player.Character
			local tool = char and char:FindFirstChildOfClass("Tool")
			if checkIfBox(tool) then
				setHeldBox(tool)
			else
				setHeldBox(nil)
			end
		end

		local function setupChar(char)
			table.insert(connections, char.ChildAdded:Connect(refreshHeldTool))
			table.insert(connections, char.ChildRemoved:Connect(refreshHeldTool))
			refreshHeldTool()
		end

		table.insert(connections, player.CharacterAdded:Connect(setupChar))
		if player.Character then
			setupChar(player.Character)
		end

		refreshHeldTool()

		return function()
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
		end
	end, {})

	-- Jika tidak memegang box, tidak merender apa-apa
	if not heldBox then
		return nil
	end

	-- Handler klik Buka Box
	local function handleOpenBox()
		if isOpening or not heldBox then
			return
		end
		setIsOpening(true)

		task.spawn(function()
			local boxName = heldBox.Name
			local success, result = pcall(function()
				return openBoxService:fetch("openBox", boxName)
			end)

			setIsOpening(false)

			if success and result then
				if result.Success then
					StarterGui:SetCore("SendNotification", {
						Title = "Sukses",
						Text = result.Message or "Box berhasil dibuka!",
						Duration = 3,
					})
				else
					StarterGui:SetCore("SendNotification", {
						Title = "Gagal",
						Text = result.Error or "Gagal membuka box!",
						Duration = 3,
					})
				end
			else
				StarterGui:SetCore("SendNotification", {
					Title = "Gagal",
					Text = "Terjadi kesalahan koneksi saat membuka box.",
					Duration = 3,
				})
			end
		end)
	end

	-- Base size dan target size untuk pulsing animation
	local baseSize = props.IsMobile and UDim2.fromOffset(120, 32) or UDim2.fromOffset(150, 36)
	local targetSize = props.IsMobile and UDim2.fromOffset(132, 36) or UDim2.fromOffset(165, 40)

	return e("Frame", {
		Size = baseSize,
		Position = UDim2.new(0.5, 0, 1, props.IsMobile and -120 or -80),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, {
		OpenBtn = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(110, 30, 230),
			BackgroundTransparency = 0.25,
			Text = isOpening and "Membuka..." or "📦 Buka Box",
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = props.IsMobile and 12 or 14,
			AutoButtonColor = true,
			[React.Event.Activated] = handleOpenBox,
			ref = function(rbx: any)
				if rbx then
					-- Hentikan tween yang sudah ada jika ada
					if tweenRef.current then
						tweenRef.current:Cancel()
					end
					-- Bikin tween denyut baru
					local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true)
					local tween = TweenService:Create(rbx, tweenInfo, {
						Size = targetSize,
					})
					tweenRef.current = tween
					tween:Play()
				else
					if tweenRef.current then
						tweenRef.current:Cancel()
						tweenRef.current = nil
					end
				end
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(200, 80, 255),
				Thickness = 1.5,
			}),
		}),
	})
end

return OpenBoxOverlay

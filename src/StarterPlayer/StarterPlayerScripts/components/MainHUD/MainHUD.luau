local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

local Topbar = require(script.Parent.Topbar)
local Sidebar = require(script.Parent.Sidebar)
local CustomStats = require(script.Parent.CustomStats)
local Hotbar = require(script.Parent.Hotbar)
local InventoryModal = require(script.Parent.InventoryModal)
local IndexModal = require(script.Parent.IndexModal)
local FusionModal = require(script.Parent.FusionModal)
local OpenBoxOverlay = require(script.Parent.OpenBoxOverlay)
local ViewportManager = require(script.Parent.Parent.ViewportManager)

local player = Players.LocalPlayer

local function MainHUD(props: { Buttons: any })
	local inventoryOpen, setInventoryOpen = useState(false)
	local indexOpen, setIndexOpen = useState(false)
	local fusionOpen, setFusionOpen = useState(false)
	local viewportSize, setViewportSize = useState(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600))

	-- Cache Viewport Frame untuk preview barang saat di-drag
	local cache = useRef(nil :: any)
	if not cache.current then
		cache.current = ViewportManager.new()
	end

	-- ===== DRAG & DROP STATE =====
	local slotMapping, setSlotMapping = useState({} :: { [number]: Tool })
	local manuallyUnmapped = useRef({} :: { [Tool]: boolean })
	local pendingRemovals = useRef({} :: { [Tool]: boolean })
	local heldTool, setHeldTool = useState(nil :: Tool?)
	
	local draggedItem, setDraggedItem = useState(nil :: { Tool: Tool, Source: string, SlotIndex: number? }?)
	local dragStartInfo, setDragStartInfo = useState(nil :: { Tool: Tool, Source: string, SlotIndex: number?, StartPos: Vector2 }?)
	local mousePos, setMousePos = useState(Vector2.new(0, 0))
	
	local hoveredHotbarIndex, setHoveredHotbarIndex = useState(nil :: number?)
	local isHoveredInventory, setIsHoveredInventory = useState(false)

	-- Pantau perubahan ukuran layar secara real-time untuk responsivitas
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

	-- ===== 1. DETEKSI TOOLS DI BACKPACK DAN CHARACTER (SHARED SOURCE OF TRUTH) =====
	local refreshScheduled = false
	local function refreshTools()
		if refreshScheduled then return end
		refreshScheduled = true
		task.defer(function()
			task.wait(0.05) -- Beri waktu agar frame transisi parent tool selesai
			refreshScheduled = false
			local backpack = player:FindFirstChild("Backpack")
			if not backpack then return end
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

			setSlotMapping(function(oldMapping)
				local newMapping = table.clone(oldMapping)
				-- Masukkan tool baru yang belum ter-map ke slot kosong
				for _, tool in ipairs(list) do
					local alreadyMapped = false
					for i = 1, 10 do
						if newMapping[i] == tool then
							alreadyMapped = true
							break
						end
					end
					if not alreadyMapped and not manuallyUnmapped.current[tool] then
						for i = 1, 10 do
							if not newMapping[i] then
								newMapping[i] = tool
								break
							end
						end
					end
				end

				-- Periksa apakah ada tool yang dilepas dari kepemilikan
				for i = 1, 10 do
					local tool = newMapping[i]
					if tool then
						local parent = tool.Parent
						if not parent or (parent ~= backpack and parent ~= char) then
							-- Tool dilepas/tidak ada di tas atau karakter.
							-- Untuk mencegah bouncing (mental ke backpack) akibat delay replikasi di server asli,
							-- kita tunda penghapusan selama 0.5 detik untuk memastikan item benar-benar dihapus secara permanen.
							if not pendingRemovals.current[tool] then
								pendingRemovals.current[tool] = true
								task.delay(0.5, function()
									pendingRemovals.current[tool] = nil
									local latestChar = player.Character
									local latestBackpack = player:FindFirstChild("Backpack")
									local latestParent = tool.Parent
									if not latestParent or (latestParent ~= latestBackpack and latestParent ~= latestChar) then
										-- Memang benar-benar dihapus secara permanen (misal: dijual/dibuang/ditukar)
										setSlotMapping(function(old)
											local new = table.clone(old)
											for slotIdx = 1, 10 do
												if new[slotIdx] == tool then
													new[slotIdx] = nil
												end
											end
											return new
										end)
									end
								end)
							end
						else
							-- Jika tool kembali terdeteksi di backpack/char sebelum 0.5 detik, batalkan status pending removal
							pendingRemovals.current[tool] = nil
						end
					end
				end

				return newMapping
			end)
		end)
	end

	useEffect(function()
		local connections = {}

		local function cleanup()
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
			table.clear(connections)
		end

		local function setupListeners()
			cleanup()

			local backpack = player:FindFirstChild("Backpack")
			if backpack then
				table.insert(connections, backpack.ChildAdded:Connect(refreshTools))
				table.insert(connections, backpack.ChildRemoved:Connect(refreshTools))
			end

			local char = player.Character
			if char then
				table.insert(connections, char.ChildAdded:Connect(refreshTools))
				table.insert(connections, char.ChildRemoved:Connect(refreshTools))
			end

			refreshTools()
		end

		-- Jalankan kembali setup ketika karakter baru ditambahkan (respawn)
		local charAddedConn = player.CharacterAdded:Connect(function()
			task.wait(0.1) -- Jeda kecil agar Backpack baru selesai terbuat oleh engine
			setupListeners()
		end)

		setupListeners()

		return function()
			charAddedConn:Disconnect()
			cleanup()
		end
	end, {})

	-- ===== 2. GLOBAL MOUSE POSITION TRACKER =====
	useEffect(function()
		local connection = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				setMousePos(Vector2.new(input.Position.X, input.Position.Y))
				
				-- Jika sedang proses click-hold, cek threshold drag
				if dragStartInfo and not draggedItem then
					local currentPos = Vector2.new(input.Position.X, input.Position.Y)
					local dist = (currentPos - dragStartInfo.StartPos).Magnitude
					if dist > 8 then
						setDraggedItem({
							Tool = dragStartInfo.Tool,
							Source = dragStartInfo.Source,
							SlotIndex = dragStartInfo.SlotIndex,
						})
					end
				end
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, {dragStartInfo, draggedItem} :: {any})

	-- ===== 3. GLOBAL MOUSE RELEASE TRACKER (DROP HANDLER) =====
	useEffect(function()
		local connection = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if dragStartInfo then
					if draggedItem then
						-- Menangani logika jatuhnya barang (Drop)
						if hoveredHotbarIndex then
							local targetSlot = hoveredHotbarIndex
							local source = draggedItem.Source
							local tool = draggedItem.Tool

							if source == "Hotbar" then
								local sourceSlot = draggedItem.SlotIndex
								if sourceSlot and sourceSlot ~= targetSlot then
									setSlotMapping(function(old)
										local new = table.clone(old)
										local temp = new[targetSlot]
										new[targetSlot] = new[sourceSlot]
										new[sourceSlot] = temp
										return new
									end)
								end
							elseif source == "Inventory" then
								-- Cari apakah tool sudah dipasang di slot lain
								local existingSlot = nil
								for idx, t in pairs(slotMapping) do
									if t == tool then
										existingSlot = idx
										break
									end
								end

								manuallyUnmapped.current[tool] = nil

								setSlotMapping(function(old)
									local new = table.clone(old)
									if existingSlot then
										-- Tukar dengan target jika ada item di target
										new[existingSlot] = new[targetSlot]
									end
									new[targetSlot] = tool
									return new
								end)
							end
						elseif isHoveredInventory then
							-- Dilepas di area inventory: Hapus dari hotbar
							local source = draggedItem.Source
							local sourceSlot = draggedItem.SlotIndex
							if source == "Hotbar" and sourceSlot then
								local tool = slotMapping[sourceSlot]
								if tool then
									manuallyUnmapped.current[tool] = true
								end
								setSlotMapping(function(old)
									local new = table.clone(old)
									new[sourceSlot] = nil
									return new
								end)
							end
						end
					else
						-- Logika Click biasa (Equip/Unequip)
						local tool = dragStartInfo.Tool
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

					-- Reset state drag
					setDragStartInfo(nil)
					setDraggedItem(nil)
				end
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, {dragStartInfo, draggedItem, hoveredHotbarIndex, isHoveredInventory, slotMapping} :: {any})

	-- Input handler untuk diteruskan ke HotbarSlot
	local function handleHotbarInputBegan(slotIndex: number, tool: Tool?, input: InputObject)
		if not tool then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setDragStartInfo({
				Tool = tool,
				Source = "Hotbar",
				SlotIndex = slotIndex,
				StartPos = Vector2.new(input.Position.X, input.Position.Y),
			})
		end
	end

	-- Input handler untuk diteruskan ke InventorySlot
	local function handleInventoryInputBegan(tool: Tool, input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setDragStartInfo({
				Tool = tool,
				Source = "Inventory",
				SlotIndex = nil,
				StartPos = Vector2.new(input.Position.X, input.Position.Y),
			})
		end
	end

	local isMobile = viewportSize.X < 600

	-- Thumbnail melayang mengikuti mouse saat menyeret (Drag Preview)
	local dragThumbnail = nil
	if draggedItem then
		dragThumbnail = e("Frame", {
			Size = UDim2.fromOffset(45, 45),
			Position = UDim2.fromOffset(mousePos.X, mousePos.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 0.4,
			BackgroundColor3 = Color3.fromRGB(15, 15, 20),
			ZIndex = 100,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 35, 85),
				Thickness = 1,
			}),
			CarView = e("ViewportFrame", {
				Size = UDim2.fromScale(0.9, 0.9),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ref = function(rbx: any)
					if rbx then
						ViewportManager.setupViewport(cache.current, rbx, draggedItem.Tool, { bgTransparency = 1 })
					end
				end,
			})
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		-- 1. Topbar (Shop, Home, Sell)
		Topbar = e(Topbar, {
			IsMobile = isMobile,
		}),

		-- 2. Sidebar / Bottom Menu
		Sidebar = e(Sidebar, {
			IsMobile = isMobile,
			Buttons = props.Buttons,
			InventoryOpen = inventoryOpen,
			SetInventoryOpen = setInventoryOpen,
			IndexOpen = indexOpen,
			SetIndexOpen = setIndexOpen,
			FusionOpen = fusionOpen,
			SetFusionOpen = setFusionOpen,
		}),

		-- 3. Custom Stats & Active Buffs
		CustomStats = e(CustomStats, {
			IsMobile = isMobile,
		}),

		-- 4. Hotbar (Sekarang selalu muncul saat Inventory terbuka sesuai request)
		Hotbar = e(Hotbar, {
			ViewportSize = viewportSize,
			InventoryOpen = false, -- Dipaksa false agar Hotbar tetap muncul saat inventory dibuka
			SlotMapping = slotMapping,
			HeldTool = heldTool,
			HoveredSlotIndex = hoveredHotbarIndex,
			SetHoveredSlotIndex = setHoveredHotbarIndex,
			OnSlotInputBegan = handleHotbarInputBegan,
		}),

		-- 5. Open Box Overlay
		OpenBoxOverlay = e(OpenBoxOverlay, {
			IsMobile = isMobile,
		}),

		-- 6. Inventory Pop-up Modal
		InventoryModal = inventoryOpen and e(InventoryModal, {
			IsMobile = isMobile,
			OnClose = function()
				setInventoryOpen(false)
			end,
			SlotMapping = slotMapping,
			HeldTool = heldTool,
			IsHovered = isHoveredInventory,
			SetIsHovered = setIsHoveredInventory,
			OnSlotInputBegan = handleInventoryInputBegan,
		}) or nil,

		-- 7. Index Catalogue Modal
		IndexModal = indexOpen and e(IndexModal, {
			IsMobile = isMobile,
			OnClose = function()
				setIndexOpen(false)
			end,
		}) or nil,

		-- 8. R&D Fusion Lab Modal
		FusionModal = fusionOpen and e(FusionModal, {
			IsMobile = isMobile,
			OnClose = function()
				setFusionOpen(false)
			end,
		}) or nil,

		-- 9. Drag Preview Thumbnail
		DragThumbnail = dragThumbnail,
	})
end

return MainHUD

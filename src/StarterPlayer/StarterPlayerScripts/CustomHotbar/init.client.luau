-- SERVICES
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local HotbarModule = require(script:WaitForChild("HotbarModule"))

-- REFERENCES
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local backpack = player:WaitForChild("Backpack")
local screenGui = HotbarModule.screenGui() :: ScreenGui
local hotbarContainer = screenGui:WaitForChild("Container", 5)
local invPanel = screenGui:WaitForChild("InventoryPanel", 5)
local searchBox = invPanel:WaitForChild("SearchBox", 5)
local scrollArea = invPanel:WaitForChild("ScrollArea", 5)
local template = script:WaitForChild("SlotTemplate", 5)

local sideMenuGui = playerGui:WaitForChild("SideMenuGui", 5)
local mainMenuGui = sideMenuGui:WaitForChild("MainContainer", 5)
local backpackBtn = mainMenuGui:WaitForChild("BackpackBtn", 5)

-- SETTINGS & MEMORY
local MAX_HOTBAR_SLOTS = UserInputService.TouchEnabled and 5 or 9

local updateQueued = false
local knownTools = {}
local slotInputConnections = {}
local renderCache = {}

-- 1. INITIAL UI STATE
hotbarContainer.Visible = true
invPanel.Visible = false

-- 2. DISABLE DEFAULT UI
task.spawn(function()
	local success
	repeat
		success = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		task.wait(0.5)
	until success
end)

-- ==========================================
-- VISUALIZER 3D (OPTIMIZED WITH ASSET LOADING WAIT)
-- ==========================================
local function setupCarViewport(viewport, carTool)
	local toolID = tostring(carTool)
	if viewport:GetAttribute("LastCar") == toolID then
		return
	end

	viewport:SetAttribute("LastCar", toolID)
	viewport.BackgroundTransparency = 1

	for _, child in pairs(viewport:GetChildren()) do
		child.Parent = nil
	end

	if not renderCache[carTool] then
		-- ===== FIX: Wait untuk Model siap (penting untuk car baru dari gacha) =====
		local originalModel = nil
		local retryCount = 0
		while not originalModel and retryCount < 20 do -- Max 4 detik (20 * 0.2s)
			originalModel = carTool:FindFirstChild("Model") or carTool:FindFirstChildOfClass("Model")
			if not originalModel then
				task.wait(0.2)
				retryCount = retryCount + 1
			end
		end

		if not originalModel then
			warn("[CustomHotbar] Model tidak ditemukan setelah wait untuk: " .. carTool.Name)
			return
		end

		-- ===== FIX: Pastikan Model punya descendants sebelum clone =====
		local modelDescendantCount = #originalModel:GetDescendants()
		local descendantRetries = 0
		while modelDescendantCount == 0 and descendantRetries < 10 do
			task.wait(0.1)
			modelDescendantCount = #originalModel:GetDescendants()
			descendantRetries = descendantRetries + 1
		end

		if modelDescendantCount == 0 then
			warn("[CustomHotbar] Model empty (no descendants) for: " .. carTool.Name)
			return
		end

		local carClone = originalModel:Clone()
		carClone:PivotTo(CFrame.new(0, 0, 0))

		-- ===== FIX: Wait untuk semua descendants fully loaded (terutama textures) =====
		task.wait(0.1)
		for _, part in pairs(carClone:GetDescendants()) do
			if part:IsA("BasePart") then
				part:IsDescendantOf(carClone) -- Force stability check
			end
		end
		task.wait(0.2)

		local minX, minY, minZ = math.huge, math.huge, math.huge
		local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
		local hasVisuals = false
		local partCount = 0

		for _, p in pairs(carClone:GetDescendants()) do
			if p:IsA("BasePart") or p:IsA("MeshPart") then
				p.CastShadow = false
				-- ===== FIX: Handle hitbox/invisible parts properly =====
				if p.Name == "Hitbox" or p.Name == "Handle" then
					p.Transparency = 1
				else
					-- Make sure part is visible (transparency < 1)
					if p.Transparency >= 1 then
						p.Transparency = 0 -- Force visibility for debugging
					end
				end

				if p.Transparency < 1 then
					hasVisuals = true
					partCount = partCount + 1
					local pos, size = p.Position, p.Size
					minX = math.min(minX, pos.X - (size.X / 2))
					minY = math.min(minY, pos.Y - (size.Y / 2))
					minZ = math.min(minZ, pos.Z - (size.Z / 2))
					maxX = math.max(maxX, pos.X + (size.X / 2))
					maxY = math.max(maxY, pos.Y + (size.Y / 2))
					maxZ = math.max(maxZ, pos.Z + (size.Z / 2))
				end
			end
		end

		if not hasVisuals or partCount == 0 then
			warn("[CustomHotbar] No visible parts found for model: " .. carTool.Name .. " (Parts count: " .. partCount .. ")")
			carClone:Destroy()
			return
		end

		-- ===== FIX: Better bounding box calculation with margin =====
		local center = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
		local size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
		local maxDim = math.max(size.X, size.Y, size.Z)

		-- Add safety margin for small models
		if maxDim < 1 then
			maxDim = 15
		elseif maxDim < 2 then
			maxDim = maxDim * 1.5
		end

		local cam = Instance.new("Camera")
		if carTool:GetAttribute("Price") then
			cam.FieldOfView = 40
			local dist = (maxDim / 2) / math.tan(math.rad(20)) * 1.5
			local camPos = center + Vector3.new(-dist * 0.6, dist * 0.5, -dist * 0.75)
			cam.CFrame = CFrame.new(camPos, center + Vector3.new(0, maxDim * 0.1, 0))
		else
			cam.FieldOfView = 30
			local dist = (maxDim / 2) / math.tan(math.rad(15)) * 1.5
			local camPos = center + Vector3.new(-dist * 0.6, dist * 0.5, -dist * 0.75)
			cam.CFrame = CFrame.new(camPos, center)
		end

		renderCache[carTool] = { Model = carClone, Camera = cam, LoadTime = tick() }
	end

	local cache = renderCache[carTool]
	if cache then
		-- ===== FIX: Detach before reparenting to prevent lock =====
		if cache.Model.Parent then
			cache.Model.Parent = nil
		end

		local success = pcall(function()
			cache.Model.Parent = viewport
		end)

		if not success then
			warn("[CustomHotbar] Failed to parent model for: " .. carTool.Name)
			return
		end

		task.wait(0.05) -- Frame stabilization

		if cache.Camera.Parent then
			cache.Camera.Parent = nil
		end
		cache.Camera.Parent = viewport
		task.wait(0.05)
		viewport.CurrentCamera = cache.Camera
		viewport.Ambient = Color3.fromRGB(220, 220, 220)
		viewport.LightColor = Color3.fromRGB(255, 255, 255)
	end
end

local function queueRefresh()
	if updateQueued then
		return
	end
	updateQueued = true

	-- ===== FIX: Spawn dengan delay untuk asset loading =====
	task.delay(0.15, function()
		updateQueued = false

		local char = player.Character
		local heldTool = char and char:FindFirstChildOfClass("Tool")
		local toolsInBackpack = backpack:GetChildren()

		local allOwned = {}
		for _, t in pairs(toolsInBackpack) do
			table.insert(allOwned, t)
		end
		if heldTool then
			table.insert(allOwned, heldTool)
		end

		-- 1. PEMBERSIHAN SLOT & SMART AUTO-FILL
		for i = 1, MAX_HOTBAR_SLOTS do
			local tool = HotbarModule.slotMapping[i]
			if tool then
				if not tool.Parent or (tool.Parent ~= backpack and tool.Parent ~= char) then
					HotbarModule.slotMapping[i] = nil
				end
			end
		end

		for _, tool in pairs(allOwned) do
			if not knownTools[tool] then
				knownTools[tool] = true
				local found = false
				for i = 1, MAX_HOTBAR_SLOTS do
					if HotbarModule.slotMapping[i] == tool then
						found = true
						break
					end
				end
				if not found then
					for i = 1, MAX_HOTBAR_SLOTS do
						if not HotbarModule.slotMapping[i] then
							HotbarModule.slotMapping[i] = tool
							break
						end
					end
				end
			end
		end

		-- 2. RENDER HOTBAR
		local toolsInHotbar = {}

		for i = 1, MAX_HOTBAR_SLOTS do
			local slotName = "Slot" .. i
			local hSlot = hotbarContainer:FindFirstChild(slotName)
			if not hSlot and template then
				hSlot = template:Clone()
				hSlot.Name = slotName
				hSlot.Parent = hotbarContainer
				hSlot.LayoutOrder = i
			end

			if hSlot then
				local tool = HotbarModule.slotMapping[i]
				if tool then
					toolsInHotbar[tool] = true
					hSlot.Visible = true
					if hSlot:FindFirstChild("SlotNumber") then
						hSlot.SlotNumber.Text = tostring(i)
					end

					local cv = hSlot:FindFirstChild("CarView")
					if cv then
						setupCarViewport(cv, tool)
					end

					local nameLabel = hSlot:FindFirstChild("ItemName")
					if nameLabel then
						nameLabel.Text = tool:GetAttribute("Name") or tool.Name
					end

					local amountLabel = hSlot:FindFirstChild("ItemAmount")
					if amountLabel then
						local count = tool:GetAttribute("Amount")
							or (tool:FindFirstChild("Amount") and tool.Amount.Value)
							or 1
						amountLabel.Text = "x" .. tostring(count)
					end

					if hSlot:GetAttribute("ToolUID") ~= tostring(tool) then
						hSlot:SetAttribute("ToolUID", tostring(tool))
						if slotInputConnections[hSlot] then
							slotInputConnections[hSlot]:Disconnect()
						end

						-- PERBAIKAN: Mengirim fungsi queueRefresh sebagai callback
						slotInputConnections[hSlot] = HotbarModule.bindSlotEvents(hSlot, tool, i, queueRefresh)
					end

					hSlot.BackgroundColor3 = (tool == heldTool) and Color3.fromRGB(130, 130, 130)
						or Color3.fromRGB(35, 35, 35)
					hSlot.Size = (tool == heldTool) and UDim2.fromScale(1.05, 1.05) or UDim2.fromScale(1, 1)
				else
					hSlot.Visible = invPanel.Visible
					hSlot.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
					hSlot.Size = UDim2.fromScale(1, 1)
					if hSlot:FindFirstChild("SlotNumber") then
						hSlot.SlotNumber.Text = tostring(i)
					end

					local cv = hSlot:FindFirstChild("CarView")
					if cv then
						for _, child in pairs(cv:GetChildren()) do
							child.Parent = nil
						end
						cv:SetAttribute("LastCar", "")
					end

					local nameLabel = hSlot:FindFirstChild("ItemName")
					if nameLabel then
						nameLabel.Text = ""
					end
					local amountLabel = hSlot:FindFirstChild("ItemAmount")
					if amountLabel then
						amountLabel.Text = ""
					end

					if hSlot:GetAttribute("ToolUID") ~= "" then
						hSlot:SetAttribute("ToolUID", "")
						if slotInputConnections[hSlot] then
							slotInputConnections[hSlot]:Disconnect()
							slotInputConnections[hSlot] = nil
						end
					end
				end
			end
		end

		-- 3. INVENTORY PANEL REFRESH
		if invPanel.Visible then
			local searchText = searchBox.Text:lower()
			local activeSlots = {}
			for _, v in pairs(scrollArea:GetChildren()) do
				if v:IsA("ImageButton") or v:IsA("Frame") then
					activeSlots[v] = true
				end
			end

			for _, tool in pairs(allOwned) do
				if not toolsInHotbar[tool] then
					local existingSlot = nil
					for slot, _ in pairs(activeSlots) do
						local ref = slot:FindFirstChild("ToolRef")
						if ref and ref.Value == tool then
							existingSlot = slot
							activeSlots[slot] = nil
							break
						end
					end

					local iSlot = existingSlot
					if not iSlot then
						iSlot = template:Clone()
						iSlot.Name = "Inv_" .. tool.Name
						iSlot.Parent = scrollArea

						local toolRef = Instance.new("ObjectValue")
						toolRef.Name = "ToolRef"
						toolRef.Value = tool
						toolRef.Parent = iSlot

						if iSlot:FindFirstChild("SlotNumber") then
							iSlot.SlotNumber.Visible = false
						end

						local cv = iSlot:FindFirstChild("CarView")
						if cv then
							setupCarViewport(cv, tool)
						end

						slotInputConnections[iSlot] = HotbarModule.bindSlotEvents(iSlot, tool, nil, queueRefresh)
					end

					local nameLabel = iSlot:FindFirstChild("ItemName")
					if nameLabel then
						nameLabel.Text = tool:GetAttribute("Name") or tool.Name
					end

					local amountLabel = iSlot:FindFirstChild("ItemAmount")
					if amountLabel then
						local count = tool:GetAttribute("Amount")
							or (tool:FindFirstChild("Amount") and tool.Amount.Value)
							or 1
						amountLabel.Text = "x" .. tostring(count)
					end

					if tool.Name:lower():find(searchText) then
						iSlot.Visible = true
					else
						iSlot.Visible = false
					end
				end
			end

			for slot, _ in pairs(activeSlots) do
				if slotInputConnections[slot] then
					slotInputConnections[slot]:Disconnect()
					slotInputConnections[slot] = nil
				end
				local cv = slot:FindFirstChild("CarView")
				if cv then
					for _, child in pairs(cv:GetChildren()) do
						child.Parent = nil
					end
				end
				slot:Destroy()
			end
		end
	end)
end

-- ==========================================
-- REAL-TIME AMOUNT TRACKER & MEMORY CLEANUP
-- ==========================================
local function monitorAmount(tool)
	if not tool:IsA("Tool") then
		return
	end
	tool:GetAttributeChangedSignal("Amount"):Connect(queueRefresh)

	local amountObj = tool:FindFirstChild("Amount")
	if amountObj and amountObj:IsA("ValueBase") then
		amountObj.Changed:Connect(queueRefresh)
	end

	-- PERBAIKAN: Bersihkan Memory Leak (Pastikan cache & tabel dihapus total)
	tool.AncestryChanged:Connect(function(_, parent)
		if not parent then
			task.delay(3, function()
				if not tool.Parent then
					if renderCache[tool] then
						renderCache[tool].Model:Destroy()
						renderCache[tool].Camera:Destroy()
						renderCache[tool] = nil
					end
					knownTools[tool] = nil -- Hapus dari memori pengingat inventaris
				end
			end)
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	local keys = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
		[Enum.KeyCode.Six] = 6,
		[Enum.KeyCode.Seven] = 7,
		[Enum.KeyCode.Eight] = 8,
		[Enum.KeyCode.Nine] = 9,
	}

	local idx = keys[input.KeyCode]
	if idx and HotbarModule.slotMapping[idx] then
		local tool = HotbarModule.slotMapping[idx]
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if tool and hum then
			if tool.Parent == player.Character or tool.Parent == backpack then
				if tool.Parent == player.Character then
					hum:UnequipTools()
				else
					hum:EquipTool(tool)
				end
			end
		end
	end

	if input.KeyCode == Enum.KeyCode.Tab or input.KeyCode == Enum.KeyCode.B then
		invPanel.Visible = not invPanel.Visible
		queueRefresh()
	end

	if backpackBtn then
		backpackBtn.MouseButton1Click:Connect(function()
			invPanel.Visible = not invPanel.Visible
			queueRefresh()
		end)
	end
end)

local closeBtn = invPanel:FindFirstChild("CloseButton")
if closeBtn then
	closeBtn.MouseButton1Click:Connect(function()
		invPanel.Visible = false
		queueRefresh()
	end)
end

searchBox:GetPropertyChangedSignal("Text"):Connect(queueRefresh)

-- ===== FIX: Add delay untuk asset loading pada car baru =====
backpack.ChildAdded:Connect(function(child)
	monitorAmount(child)
	-- Delay 0.5 detik untuk pastikan Model child sudah ada dan ready
	task.delay(0.5, queueRefresh)
end)
backpack.ChildRemoved:Connect(queueRefresh)

player.CharacterAdded:Connect(function(char)
	HotbarModule.slotMapping = {} -- PERBAIKAN SCOPE
	queueRefresh()

	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			monitorAmount(c)
			-- Delay 0.5 detik untuk pastikan Model child sudah ada dan ready
			task.delay(0.5, queueRefresh)
		end
	end)
	char.ChildRemoved:Connect(queueRefresh)
end)

for _, t in pairs(backpack:GetChildren()) do
	monitorAmount(t)
end

if player.Character then
	for _, t in pairs(player.Character:GetChildren()) do
		monitorAmount(t)
	end
	player.Character.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			monitorAmount(c)
			queueRefresh()
		end
	end)
	player.Character.ChildRemoved:Connect(queueRefresh)
end

queueRefresh()

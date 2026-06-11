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
-- VISUALIZER 3D (OPTIMIZED)
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
		local originalModel = carTool:FindFirstChild("Model") or carTool:FindFirstChildOfClass("Model")
		if not originalModel then
			return
		end

		local carClone = originalModel:Clone()
		carClone:PivotTo(CFrame.new(0, 0, 0))
		task.wait(0.3)
		local minX, minY, minZ = math.huge, math.huge, math.huge
		local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
		local hasVisuals = false

		for _, p in pairs(carClone:GetDescendants()) do
			if p:IsA("BasePart") or p:IsA("MeshPart") then
				p.CastShadow = false
				if p.Name == "Hitbox" or p.Name == "Handle" then
					p.Transparency = 1
				end
				if p.Transparency < 1 then
					hasVisuals = true
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

		if not hasVisuals then
			carClone:Destroy()
			return
		end

		local center = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
		local size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
		local maxDim = math.max(size.X, size.Y, size.Z)
		if maxDim < 1 then
			maxDim = 15
		end

		local cam = Instance.new("Camera")
		if carTool:GetAttribute("Price") then
			cam.FieldOfView = 40
			local dist = (maxDim / 2) / math.tan(math.rad(30)) * 1.25
			local camPos = center + Vector3.new(-dist * 0.7, dist * 0.4, -dist * 0.8)
			cam.CFrame = CFrame.new(camPos, center)
		else
			cam.FieldOfView = 25
			local dist = (maxDim / 2) / math.tan(math.rad(cam.FieldOfView / 2.5)) * 1.25
			local camPos = center + Vector3.new(-dist * 0.7, dist * 0.4, -dist * 0.8)
			cam.CFrame = CFrame.new(camPos, center)
		end

		renderCache[carTool] = { Model = carClone, Camera = cam }
	end

	local cache = renderCache[carTool]
	if cache then
		cache.Model.Parent = viewport
		cache.Camera.Parent = viewport
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

	task.defer(function()
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

backpack.ChildAdded:Connect(function(child)
	monitorAmount(child)
	queueRefresh()
end)
backpack.ChildRemoved:Connect(queueRefresh)

player.CharacterAdded:Connect(function(char)
	HotbarModule.slotMapping = {} -- PERBAIKAN SCOPE
	queueRefresh()

	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			monitorAmount(c)
			queueRefresh()
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

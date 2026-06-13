local HotbarModule = {}
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local backpack = player:WaitForChild("Backpack")
local screenGui = playerGui:WaitForChild("CustomHotbar", math.huge) :: ScreenGui

HotbarModule.slotMapping = {} :: { [number]: Tool? }

-- DRAG & DROP VARIABLES
local isDragging = false
local dragGhost = nil
local dragConnection = nil
local dragUpConnection = nil

function HotbarModule.screenGui(): ScreenGui?
	if screenGui then
		return screenGui
	else
		print(
			"ScreenGui reference is missing! Please ensure the CustomHotbar ScreenGui is properly set up in StarterGui."
		)
		return nil
	end
end

-- ==========================================
-- DRAG AND DROP LOGIC
-- ==========================================
function HotbarModule.getTargetSlot(x, y)
	local guis = player.PlayerGui:GetGuiObjectsAtPosition(x, y)
	for _, gui in ipairs(guis) do
		if gui.Name:match("^Slot(%d+)$") then
			return "Hotbar", tonumber(gui.Name:match("^Slot(%d+)$"))
		elseif gui.Name == "InventoryPanel" or gui.Name == "ScrollArea" or gui.Name == "InvPanel" then
			return "Inventory", nil
		end
	end
	return nil, nil
end

-- DITAMBAHKAN: parameter refreshCallback agar tidak error panggil fungsi LocalScript
function HotbarModule.bindSlotEvents(uiElement, tool, slotIndex, refreshCallback)
	local connection = uiElement.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local startPos = input.Position

			dragConnection = UserInputService.InputChanged:Connect(function(moveInput)
				if
					moveInput.UserInputType == Enum.UserInputType.MouseMovement
					or moveInput.UserInputType == Enum.UserInputType.Touch
				then
					if (moveInput.Position - startPos).Magnitude > 5 and not isDragging then
						isDragging = true
						dragGhost = uiElement:Clone()
						dragGhost.Parent = HotbarModule.screenGui()
						dragGhost.Size = UDim2.fromOffset(uiElement.AbsoluteSize.X, uiElement.AbsoluteSize.Y)
						dragGhost.ZIndex = 100
						if dragGhost:FindFirstChild("SlotNumber") then
							dragGhost.SlotNumber.Visible = false
						end

						if uiElement:IsA("ImageButton") then
							uiElement.ImageTransparency = 0.5
						else
							uiElement.BackgroundTransparency = 0.5
						end
					end

					if isDragging and dragGhost then
						dragGhost.Position = UDim2.fromOffset(
							moveInput.Position.X - dragGhost.Size.X.Offset / 2,
							moveInput.Position.Y - dragGhost.Size.Y.Offset / 2
						)
					end
				end
			end)

			dragUpConnection = UserInputService.InputEnded:Connect(function(endInput)
				if
					endInput.UserInputType == Enum.UserInputType.MouseButton1
					or endInput.UserInputType == Enum.UserInputType.Touch
				then
					if dragConnection then
						dragConnection:Disconnect()
					end
					if dragUpConnection then
						dragUpConnection:Disconnect()
					end

					if isDragging then
						isDragging = false
						if dragGhost then
							dragGhost:Destroy()
							dragGhost = nil
						end

						if uiElement:IsA("ImageButton") then
							uiElement.ImageTransparency = 0
						else
							uiElement.BackgroundTransparency = 0
						end

						local dropTarget, targetIndex =
							HotbarModule.getTargetSlot(endInput.Position.X, endInput.Position.Y)

						if dropTarget == "Hotbar" and targetIndex then
							if slotIndex then
								local temp = HotbarModule.slotMapping[targetIndex]
								HotbarModule.slotMapping[targetIndex] = HotbarModule.slotMapping[slotIndex]
								HotbarModule.slotMapping[slotIndex] = temp
							else
								HotbarModule.slotMapping[targetIndex] = tool
							end
						elseif dropTarget == "Inventory" and slotIndex then
							HotbarModule.slotMapping[slotIndex] = nil
						end

						-- Eksekusi Callback jika ada
						if refreshCallback then
							refreshCallback()
						end
					else
						local char = player.Character
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						if tool and tool.Parent and hum then
							if tool.Parent == char or tool.Parent == backpack then
								if tool.Parent == char then
									hum:UnequipTools()
								else
									hum:EquipTool(tool)
								end
							end
						end
					end
				end
			end)
		end
	end)

	return connection
end

return HotbarModule

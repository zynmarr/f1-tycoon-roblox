local UpgradeMachineArea = {}

function UpgradeMachineArea.init()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local player = Players.LocalPlayer
	local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))

	local Networker = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networker"))
	local serviceClient = {}
	local networker = Networker.client.new("UpgradeMachine", serviceClient)

	local function getBillboard(machineArea: Folder): Model?
		for _, child in ipairs(machineArea:GetChildren()) do
			if child:IsA("Model") and string.find(child.Name, "Billboard") then
				return child
			end
		end
		return machineArea:FindFirstChildOfClass("Model")
	end

	local function setupMachineArea(machineArea: Folder)
		if not machineArea:IsA("Folder") then
			return
		end

		local billboard = getBillboard(machineArea)
		if not billboard then
			billboard = machineArea:WaitForChild("Billboard", 5) or machineArea:FindFirstChildOfClass("Model")
		end

		if billboard then
			local area = billboard:WaitForChild("Area", 5)
			if area then
				local surface = area:WaitForChild("SurfaceGui", 5)
				if surface then
					local frame = surface:WaitForChild("Frame", 5)
					local list = frame:WaitForChild("List", 5)
					if list then
						local function setupButtons()
							for _, item in ipairs(list:GetChildren()) do
								if item:IsA("Frame") then
									local button = item:WaitForChild("Button", 5) :: TextButton?
									if button and not button:GetAttribute("Connected") then
										button:SetAttribute("Connected", true)

										local buying = false
										button.MouseButton1Click:Connect(function()
											if buying then
												return
											end
											buying = true

											local originalText = button.Text
											button.Text = "..."

											print(
												"[UpgradeClient] Mencoba membeli upgrade: "
													.. item.Name
													.. " untuk "
													.. machineArea.Name
											)
											local result = networker:fetch("buyUpgrade", machineArea, item.Name)
											if result and result.Success then
												print("[UpgradeClient] ✅ Upgrade sukses: " .. item.Name)
											else
												local errMsg = result and result.Error or "Unknown error"
												warn("[UpgradeClient] ❌ Upgrade gagal: " .. tostring(errMsg))
											end
											button.Text = originalText
											buying = false
										end)
									end
								end
							end
						end

						-- Initial setup
						setupButtons()

						-- In case items are added dynamically later
						list.ChildAdded:Connect(function(child)
							if child:IsA("Frame") then
								task.defer(setupButtons)
							end
						end)
					end
				end
			end
		end
	end

	local function bindPlotMachines()
		local plot = GameUtils.getPlayerPlot(player)
		if not plot then
			return
		end

		local machines = plot:WaitForChild("Machines", 5) :: Folder?
		if not machines then
			return
		end

		for _, machineArea in ipairs(machines:GetChildren()) do
			if machineArea:IsA("Folder") then
				task.spawn(setupMachineArea, machineArea)
			end
		end

		if not machines:GetAttribute("ClientConnected") then
			machines:SetAttribute("ClientConnected", true)
			machines.ChildAdded:Connect(function(child)
				if child:IsA("Folder") then
					task.spawn(setupMachineArea, child)
				end
			end)
		end
	end

	player:GetAttributeChangedSignal("MyPlotName"):Connect(function()
		task.wait(0.2)
		bindPlotMachines()
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		bindPlotMachines()
	end)

	task.spawn(function()
		local attempts = 0
		while attempts < 20 do
			bindPlotMachines()
			local plot = GameUtils.getPlayerPlot(player)
			if plot and plot:FindFirstChild("Machines") then
				break
			end
			task.wait(0.5)
			attempts = attempts + 1
		end
	end)

	print("[UpgradeClient] Initialized machine upgrade listener!")
end

return UpgradeMachineArea

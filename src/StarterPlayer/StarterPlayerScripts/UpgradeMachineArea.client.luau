local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))

-- 1. WAIT FOR PLOT AND MACHINES FOLDER
local plot = GameUtils.getPlayerPlot(player)
if not plot then
	player:GetAttributeChangedSignal("MyPlotName"):Wait()
	plot = GameUtils.getPlayerPlot(player)
	while not plot do
		task.wait(0.5)
		plot = GameUtils.getPlayerPlot(player)
	end
end

local machines = plot:WaitForChild("Machines", 15) :: Folder?
if not machines then
	warn("[UpgradeClient] Folder Machines tidak ditemukan di plot!")
	return
end

local BuyUpgradeFunction = ReplicatedStorage:WaitForChild("BuyUpgradeFunction") :: RemoteFunction

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
		local moduleScript = billboard:WaitForChild("ModuleScript", 5)
			or billboard:FindFirstChildOfClass("ModuleScript")
		if moduleScript then
			local module = require(moduleScript)
			local area = billboard:WaitForChild("Area", 5)
			if area then
				local surface = area:WaitForChild("SurfaceGui", 5)
				if surface then
					local list = surface:WaitForChild("List", 5)
					if list then
						local function setupButtons()
							for _, item in ipairs(list:GetChildren()) do
								if item:IsA("Frame") then
									local button = item:WaitForChild("Button", 5) :: TextButton?
									if button and not button:GetAttribute("Connected") then
										button:SetAttribute("Connected", true)
										button.MouseButton1Click:Connect(function()
											print(
												"[UpgradeClient] Mencoba membeli upgrade: "
													.. item.Name
													.. " untuk "
													.. machineArea.Name
											)
											local success, msg = BuyUpgradeFunction:InvokeServer(machineArea, item.Name)
											if success then
												print("[UpgradeClient] ✅ Upgrade sukses: " .. item.Name)
											else
												warn("[UpgradeClient] ❌ Upgrade gagal: " .. tostring(msg))
											end
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
end

-- Setup existing machines
for _, machineArea in ipairs(machines:GetChildren()) do
	if machineArea:IsA("Folder") then
		task.spawn(setupMachineArea, machineArea)
	end
end

-- Handle dynamically added machines
machines.ChildAdded:Connect(function(child)
	if child:IsA("Folder") then
		task.spawn(setupMachineArea, child)
	end
end)

print("[UpgradeClient] Initialized machine upgrade listener!")

-- !strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))

local PLOT_TAG = "PlotArea"

local PlotManager = {}

PlotManager.billboard = {}

local function plotArea(plot: Folder)
	local billboard = plot:FindFirstChild("Billboard")
	local part = billboard and billboard:FindFirstChild("Sign")
	local surfaceGui = part and part:FindFirstChild("SurfaceGui")

	for _, child in pairs(plot:GetDescendants()) do
		if child:IsA("BasePart") then
			child.CanCollide = true
			child.Anchored = true
		end
	end

	if surfaceGui then
		local textLabel = surfaceGui:FindFirstChild("TextLabel")
		if textLabel then
			textLabel.Text = "Plot Kosong"
		end
		PlotManager.billboard[plot.Name] = {
			plot = plot,
			owner = nil,
			billboard = billboard,
			textLabel = textLabel,
		}
	end

	if plot:GetAttribute("Owner") and plot:GetAttribute("Owner") ~= "" then
		local ownerName = plot:GetAttribute("Owner")
		local billboardInfo = PlotManager.billboard[plot.Name]
		if billboardInfo then
			billboardInfo.owner = ownerName
		end
	end

	plot.AttributeChanged:Connect(function(attrName)
		if attrName == "Owner" then
			local ownerName = plot:GetAttribute("Owner")
			local billboardInfo = PlotManager.billboard[plot.Name]
			if billboardInfo then
				billboardInfo.owner = ownerName
				if billboardInfo.textLabel then
					if ownerName and ownerName ~= "" then
						billboardInfo.textLabel.Text = "Plot Owner: " .. ownerName
					else
						billboardInfo.textLabel.Text = "Plot Empty"
					end
				end
			end
		end
	end)
end

function PlotManager.Init()
	local function onSpawnerAdded(plot: Folder)
		task.spawn(plotArea, plot)
	end

	-- 1. Tangani objek yang baru muncul nanti (Dynamic)
	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(onSpawnerAdded)

	-- 2. Tangani objek yang sudah ada sekarang (Static/Pre-loaded)
	for _, plot in pairs(CollectionService:GetTagged(PLOT_TAG)) do
		onSpawnerAdded(plot)
	end
end

local function spawnRaceStation(plot: Folder)
	local spawnLocation = plot:FindFirstChild("SpawnLocation") :: BasePart?
	if not spawnLocation then
		warn("[PlotManager] SpawnLocation tidak ditemukan untuk spawn RaceStation di plot: " .. plot.Name)
		return
	end

	local raceStation = plot:FindFirstChild("RaceStation")
	if not raceStation then
		local model = Instance.new("Model")
		model.Name = "RaceStation"

		-- DeskPart
		local desk = Instance.new("Part")
		desk.Name = "DeskPart"
		desk.Size = Vector3.new(5, 3.5, 2.5)
		desk.Color = Color3.fromRGB(50, 50, 50)
		desk.Material = Enum.Material.Metal
		desk.Anchored = true
		desk.CanCollide = true
		desk.CFrame = spawnLocation.CFrame * CFrame.new(7, 1.25, 0)
		desk.Parent = model

		-- ScreenPart
		local screen = Instance.new("Part")
		screen.Name = "ScreenPart"
		screen.Size = Vector3.new(3.5, 2.5, 0.2)
		screen.Color = Color3.fromRGB(0, 170, 255)
		screen.Material = Enum.Material.Neon
		screen.Anchored = true
		screen.CanCollide = true
		screen.CFrame = desk.CFrame * CFrame.new(0, 2.5, 0)
		screen.Parent = model

		-- ProximityPrompt
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RacePrompt"
		prompt.ActionText = "Kelola Balapan"
		prompt.ObjectText = "Stasiun Balap F1"
		prompt.MaxActivationDistance = 8
		prompt.HoldDuration = 0.5
		prompt.RequiresLineOfSight = false
		prompt.Parent = screen

		model.PrimaryPart = desk
		model.Parent = plot
	end
end

function PlotManager.claimPlot(player): Instance?
	local plotsFolder = workspace:WaitForChild("Plots")

	for _, plot in pairs(plotsFolder:GetChildren()) do
		local currentOwner = plot:GetAttribute("Owner")
		if not currentOwner or currentOwner == "" then
			plot:SetAttribute("Owner", player.Name)
			pcall(function()
				spawnRaceStation(plot)
			end)
			return plot
		end
	end
	return nil
end

function PlotManager.releasePlot(player)
	local plot = GameUtils.getPlayerPlot(player)
	if plot then
		-- Hancurkan RaceStation jika ada
		local raceStation = plot:FindFirstChild("RaceStation")
		if raceStation then
			pcall(function()
				raceStation:Destroy()
			end)
		end

		-- 1. Reset Owner Plot
		plot:SetAttribute("Owner", "")
		local label = plot:FindFirstChild("TextLabel", true)
		if label then
			label.Text = "Plot Kosong"
		end

		-- 2. Bersihkan Mobil di Lahan Parkir (AllParkingLots)
		local parkingLots = plot:FindFirstChild("AllParkingLots")
		if parkingLots then
			for _, parking in pairs(parkingLots:GetChildren()) do
				local carsFolder = parking:FindFirstChild("MyCars", true)
				if carsFolder then
					for _, car in pairs(carsFolder:GetChildren()) do
						pcall(function()
							car:Destroy()
						end)
					end
				end

				-- Reset ProximityPrompt status di area parkir
				local prompt = parking:FindFirstChildOfClass("ProximityPrompt")
					or parking:FindFirstChild("ProximityPrompt", true)
				if prompt then
					prompt:SetAttribute("IsActive", false)
				end
			end
		end

		-- 3. Bersihkan Box & Reset Atribut Mesin (Machines)
		local plotMachines = plot:FindFirstChild("Machines")
		if plotMachines then
			for _, machineArea in pairs(plotMachines:GetChildren()) do
				-- Nonaktifkan mesin spawner
				machineArea:SetAttribute("Active", false)
				machineArea:SetAttribute("IsRunning", false)

				-- Cari part fisik mesin
				local machinePart = nil
				for _, child in pairs(machineArea:GetChildren()) do
					if child:IsA("BasePart") and string.find(child.Name, "Machine") then
						machinePart = child
						break
					end
				end

				if not machinePart then
					machinePart = machineArea:FindFirstChildOfClass("BasePart")
				end

				if machinePart then
					-- Hancurkan box-box yang tersisa di dalam mesin
					for _, child in pairs(machinePart:GetChildren()) do
						-- Hancurkan objek bertag Box atau Tool/Model
						if child:IsA("Tool") or child:IsA("Model") or CollectionService:HasTag(child, "Box") then
							pcall(function()
								child:Destroy()
							end)
						end
					end

					-- Reset semua upgrade atribut pada part mesin kembali ke nil
					for name, _ in pairs(machinePart:GetAttributes()) do
						pcall(function()
							machinePart:SetAttribute(name, nil)
						end)
					end
				end

				-- Reset semua atribut kustom pada folder machineArea sendiri
				for name, _ in pairs(machineArea:GetAttributes()) do
					if name ~= "IsInitialized" then -- Pertahankan inisialisasi awal
						pcall(function()
							machineArea:SetAttribute(name, nil)
						end)
					end
				end
			end
		end
	end
end

function PlotManager.teleportToPlot(player, character)
	local plot = GameUtils.getPlayerPlot(player)
	if plot then
		local spawnPos = plot:FindFirstChild("SpawnLocation")
		if spawnPos then
			character:PivotTo(spawnPos.CFrame * CFrame.new(0, 3, 0))
			print("++++ TELEPORTED TO PLOT: " .. plot.Name)
		end
	end
end

return PlotManager

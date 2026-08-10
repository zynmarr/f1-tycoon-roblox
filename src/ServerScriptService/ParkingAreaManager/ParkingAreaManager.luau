--!strict

local ParkingAreaManager = {}
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameUtils = require(ReplicatedStorage.GameUtils)
local RoleManager = require(game.ServerScriptService.RoleManager.RoleManager)
local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local SPAWNER_TAG = "ParkingArea"
local playerPassiveIncome = {} -- [Player] = number (total passive income/sec)

local function getOrCalculateCarIncome(car: Instance): number
	local income = car:GetAttribute("Income") :: number?
	if income and income > 0 then
		return income
	end

	local rarity: string = car:GetAttribute("Rarity") :: string or "Common"
	local variant: string? = car:GetAttribute("Variant") :: string? or "Normal"
	local tierData = GameConfig.Rarities[rarity] or GameConfig.Rarities.Common
	local carName = car:GetAttribute("Name") or car.Name
	local baseIncome, _ = GameConfig.CalculatePrice(tierData.BasePrice, rarity, variant, carName)

	car:SetAttribute("Income", baseIncome)
	return baseIncome
end

local function processPickup(player: Player, car: Tool)
	local allowed, errMsg = GameConfig.CanPlayerPickUp(player, car)
	if not allowed then
		local NotifEvent = ReplicatedStorage:FindFirstChild("NotifEvent")
		if NotifEvent then
			NotifEvent:FireClient(player, "Akses Ditolak", errMsg or "Tidak dapat mengambil mobil ini!", 3)
		end
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local handle = car:FindFirstChild("Handle") :: BasePart?
	if handle then
		handle.Anchored = false
		handle.CanCollide = false
		handle.CanTouch = true
	end

	GameConfig.ClearHands(player)
	car:ScaleTo(0.2)

	-- Bind drive speed attribute based on Rarity and Variant
	local rarity = car:GetAttribute("Rarity") or "Common"
	local variant = car:GetAttribute("Variant") or "Normal"
	local carName = car:GetAttribute("Name") or car.Name
	local speed = GameConfig.CalculateDriveSpeed(rarity, variant, carName)
	car:SetAttribute("DriveSpeed", speed)

	car.Parent = character

	-- Hook: Subtract income from player passive income cache
	local carIncome = getOrCalculateCarIncome(car)
	playerPassiveIncome[player] = math.max(0, (playerPassiveIncome[player] or 0) - carIncome)
end

local function storeCarToArea(player: Player, area: Part, tool: Tool)
	local myCars: Folder? = area:FindFirstChild("MyCars") :: Folder?
		or (area.Parent and area.Parent:FindFirstChild("MyCars")) :: Folder?
	local prompt: ProximityPrompt? = area:FindFirstChild("ProximityPrompt") :: ProximityPrompt?
		or (area.Parent and area.Parent:FindFirstChild("ProximityPrompt")) :: ProximityPrompt?

	if myCars then
	else
		local newFolder = Instance.new("Folder") :: Folder
		newFolder.Name = "MyCars"
		newFolder.Parent = area.Parent or area
		myCars = newFolder
	end

	if tool:IsA("Tool") and tool:GetAttribute("Price") then
		local isEdition = tool:GetAttribute("IsEdition")

		-- 3. PINDAHKAN PARENT DULU
		-- (Sangat penting agar koordinat relatif PivotTo dihitung di container yang baru)
		tool.Parent = myCars :: Folder
		local rotation = -90
		local angle = CFrame.Angles(0, math.rad(rotation), 0)
		local areaPosition = area.CFrame.Position :: Vector3

		local targetCFrame: CFrame = CFrame.new(areaPosition.X, areaPosition.Y + 2.25, areaPosition.Z) * angle

		-- 4. EKSEKUSI POSISI (Gunakan World Pivot agar aman)
		-- Kita arahkan ke tengah area parkir, naik 2.5 studs (sumbu Y)
		if isEdition then
			rotation = 180
			angle = CFrame.Angles(0, math.rad(rotation), 0)
			targetCFrame = CFrame.new(areaPosition.X, areaPosition.Y + 2.25, areaPosition.Z) * angle
		end

		local lotGroup: Folder = area.Parent :: Folder
		if lotGroup.Name == "Lots1" then
			rotation = 90
			angle = CFrame.Angles(0, math.rad(rotation), 0)
			targetCFrame = CFrame.new(areaPosition.X, areaPosition.Y + 2.25, areaPosition.Z) * angle

			if isEdition then
				rotation = 360
				angle = CFrame.Angles(0, math.rad(rotation), 0)
				targetCFrame = CFrame.new(areaPosition.X, areaPosition.Y + 2.25, areaPosition.Z) * angle
			end
		end

		task.wait() -- Beri jeda 1 frame agar engine Roblox meregistrasi parent baru
		tool:PivotTo(targetCFrame)

		local handle = tool:FindFirstChild("Handle") :: BasePart?

		if not handle then
			return warn("Handle not found in tool: " .. tool.Name)
		end

		if handle then
			handle.Anchored = true
			handle.CanCollide = false
			handle.CanTouch = false
		end

		-- 5. RESET GRIP & SCALE
		--tool.Grip = CFrame.new(0, 120, 0)
		if isEdition then
			tool:ScaleTo(0.8)
		else
			tool:ScaleTo(0.7)
		end

		-- 6. UPDATE ATTRIBUTE
		tool:SetAttribute("Location", "MyCars")
		tool:SetAttribute("IsParked", true)
		if prompt then
			prompt:SetAttribute("IsActive", true)
		end

		-- Hook: Add income to player passive income cache
		local carIncome = getOrCalculateCarIncome(tool)
		playerPassiveIncome[player] = (playerPassiveIncome[player] or 0) + carIncome

		warn("Mobil berhasil diparkir di: " .. tostring(targetCFrame.Position))
	end
end

local function parkedInArea(area: Part)
	local prompt: ProximityPrompt? = area:FindFirstChild("ProximityPrompt") :: ProximityPrompt?
		or (area.Parent and area.Parent:FindFirstChild("ProximityPrompt")) :: ProximityPrompt?
	if prompt == nil then
		return
	end

	-- 1. UPDATE TEKS PROMPT BERDASARKAN STATUS
	prompt.AttributeChanged:Connect(function(attributeName)
		if attributeName == "IsActive" then
			local isActive = prompt:GetAttribute("IsActive")
			if isActive then
				-- Jika IsActive TRUE, berarti ada mobil di sana
				prompt.ActionText = "Pick Car"
				prompt.ObjectText = "Vehicle Occupied"
			else
				-- Jika IsActive FALSE, berarti area kosong
				prompt.ActionText = "Park Car"
				prompt.ObjectText = "Empty Lot"
			end
		end
	end)

	prompt.Triggered:Connect(function(player)
		local character = player.Character
		local toolOnCharacter = if character then character:FindFirstChildOfClass("Tool") :: Tool else nil
		local isActive = prompt:GetAttribute("IsActive")

		local allParkingLots: Folder = area:FindFirstAncestor("AllParkingLots") :: Folder -- Asumsi struktur: Workspace > Plots > Plot1 > AllParkingLots > ParkingArea
		local plot = if allParkingLots then allParkingLots.Parent else nil

		if plot and plot:GetAttribute("Owner") ~= player.Name then
			return warn("This parking area belongs to another player!")
		end

		-- MODE: PARKIR (Jika area sedang Kosong)
		if not isActive then
			local isCarTool = toolOnCharacter and GameUtils.isCar(toolOnCharacter)
			if toolOnCharacter and isCarTool then
				warn("Parking mode: Menyimpan mobil...")
				storeCarToArea(player, area, toolOnCharacter)
				prompt:SetAttribute("IsActive", true) -- Tandai area sudah terisi
			else
				warn("You not holding a car tool or no character found!")
			end

			-- MODE: AMBIL (Jika area sedang Terisi)
		else
			warn("Pick mode: Mengambil mobil dari parkiran...")
			local myCars = area:FindFirstChild("MyCars") or (area.Parent and area.Parent:FindFirstChild("MyCars"))

			if myCars then
				local carFound = false
				for _, item in pairs(myCars:GetChildren()) do
					if item:IsA("Tool") then
						processPickup(player, item)
						--item.Parent = player:WaitForChild("Backpack")
						carFound = true
						break -- Ambil satu mobil saja
					end
				end

				if carFound then
					prompt:SetAttribute("IsActive", false) -- Tandai area sekarang kosong
				end
			else
				warn("MyCars folder not found in parking area: " .. area.Name)
			end
		end
	end)
end

function ParkingAreaManager.Init()
	local function onSpawnerAdded(area: Part)
		task.spawn(parkedInArea, area)
	end

	-- 1. Tangani objek yang baru muncul nanti (Dynamic)
	CollectionService:GetInstanceAddedSignal(SPAWNER_TAG):Connect(onSpawnerAdded)

	-- 2. Tangani objek yang sudah ada sekarang (Static/Pre-loaded)
	for _, area in pairs(CollectionService:GetTagged(SPAWNER_TAG)) do
		onSpawnerAdded(area)
	end

	-- Cleanup on leave
	Players.PlayerRemoving:Connect(function(player)
		playerPassiveIncome[player] = nil
	end)

	-- Passive Income Loop
	task.spawn(function()
		while true do
			task.wait(1)
			for player, totalIncome in pairs(playerPassiveIncome) do
				if player and player.Parent and totalIncome > 0 then
					local leaderstats = player:FindFirstChild("leaderstats") :: Folder
					local cash = leaderstats:FindFirstChild("Cash") :: IntValue
					if cash then
						-- Calculate VIP/Staff Multiplier
						local multiplier = 1.0
						local roleInfo = RoleManager.getPlayerRole(player)
						if
							roleInfo
							and (
								roleInfo == "VIP"
								or roleInfo == "Staff"
								or roleInfo == "Moderator"
								or roleInfo == "Developer"
								or roleInfo == "Owner"
							)
						then
							multiplier = 1.2
						end

						-- Rebirth: Cash Multiplier
						local data = require(game.ServerScriptService.DataManager.DataManager).getPlayerData(player)
						local rebirthUpgrades = data and data.RebirthUpgrades or {}
						local cashMulLevel = rebirthUpgrades.CashMultiplier or 0
						local cashMulBonus = 1 + (RebirthConfig.getUpgradeEffect("CashMultiplier", cashMulLevel) / 100)

						-- Rebirth: Double Cash Chance
						local dccLevel = rebirthUpgrades.DoubleCashChance or 0
						local dccChance = RebirthConfig.getUpgradeEffect("DoubleCashChance", dccLevel)
						local doubleMultiplier = (math.random() * 100 < dccChance) and 2 or 1

						-- Collection Index Multiplier
						local collectionMulti = player:GetAttribute("CollectionMultiplier") or 1.0

						local addedCash =
							math.floor(totalIncome * multiplier * cashMulBonus * doubleMultiplier * collectionMulti :: number)
						cash.Value = cash.Value + addedCash
					end
				end
			end
		end
	end)
end

function ParkingAreaManager.storeCar(player: Player, area: Part, tool: Tool): ()
	assert(player and area and tool, "Missing arguments for storeCar")
	GameUtils.updateTextLabel(tool)
	storeCarToArea(player, area, tool)
end

function ParkingAreaManager.resetPassiveIncome(player: Player)
	playerPassiveIncome[player] = 0
end

function ParkingAreaManager.recalculatePassiveIncome(player: Player)
	local totalIncome = 0
	local myPlot = GameUtils.getPlayerPlot(player)
	if myPlot then
		local parkingLots = myPlot:FindFirstChild("AllParkingLots")
		if parkingLots then
			for _, parking in ipairs(parkingLots:GetChildren()) do
				local carsFolder = parking:FindFirstChild("MyCars", true)
				if carsFolder then
					for _, car in ipairs(carsFolder:GetChildren()) do
						if car:IsA("Tool") then
							local carIncome = getOrCalculateCarIncome(car)
							totalIncome = totalIncome + carIncome
						end
					end
				end
			end
		end
	end
	playerPassiveIncome[player] = totalIncome
end

function ParkingAreaManager.getPlayerPassiveIncome(player: Player): number
	return playerPassiveIncome[player] or 0
end

return ParkingAreaManager

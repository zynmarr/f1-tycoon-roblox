--!strict
-- Baris pertama wajib "--!strict" agar Linter (Selene/Luau-LSP)
-- mendeteksi tipe data secara agresif.

local ParkingAreaManager = {}
local CollectionService = game:GetService("CollectionService")
local SPAWNER_TAG = "ParkingArea"

local function processPickup(player: Player, car: Tool)
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

	car:ScaleTo(0.2)
	car.Parent = character
end

local function storeCarToArea(player: Player, area: Part, tool: Tool)
	local myCars = area:FindFirstChild("MyCars")
	local prompt = area:FindFirstChild("ProximityPrompt") :: ProximityPrompt

	if not myCars then
		return warn("MyCars folder not found in parking area: " .. area.Name)
	end

	if tool:IsA("Tool") and tool:GetAttribute("Price") then
		local isEdition = tool:GetAttribute("IsEdition")

		-- 3. PINDAHKAN PARENT DULU
		-- (Sangat penting agar koordinat relatif PivotTo dihitung di container yang baru)
		tool.Parent = myCars
		local targetCFrame = area:GetPivot() * CFrame.new(0, 2.25, 0)

		-- 4. EKSEKUSI POSISI (Gunakan World Pivot agar aman)
		-- Kita arahkan ke tengah area parkir, naik 2.5 studs (sumbu Y)
		if isEdition then
			targetCFrame = area:GetPivot() * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, math.rad(180), 0)
		end

		task.wait() -- Beri jeda 1 frame agar engine Roblox meregistrasi parent baru
		tool:PivotTo(targetCFrame)

		local handle = tool:FindFirstChild("Handle") :: BasePart?

		if not handle then
			return warn("Handle not found in tool: " .. tool.Name)
		end

		handle.Anchored = true
		handle.CanCollide = false
		handle.CanTouch = false

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

		warn("Mobil berhasil diparkir di: " .. tostring(targetCFrame.Position))
	end
end

local function parkedInArea(area: Part)
	local prompt = area:FindFirstChild("ProximityPrompt") :: ProximityPrompt
	if not prompt then
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

		local allParkingLots = area:FindFirstAncestor("AllParkingLots") :: Folder? -- Asumsi struktur: Workspace > Plots > Plot1 > AllParkingLots > ParkingArea
		local plot = if allParkingLots then allParkingLots.Parent else nil

		if plot and plot:GetAttribute("Owner") ~= player.Name then
			return warn("This parking area belongs to another player!")
		end

		-- MODE: PARKIR (Jika area sedang Kosong)

		-- MODE: PARKIR (Jika area sedang Kosong)
		if not isActive then
			if toolOnCharacter and CollectionService:HasTag(toolOnCharacter, "Car") then
				warn("Parking mode: Menyimpan mobil...")
				storeCarToArea(player, area, toolOnCharacter)
				prompt:SetAttribute("IsActive", true) -- Tandai area sudah terisi
			else
				warn("You not holding a car tool or no character found!")
			end

			-- MODE: AMBIL (Jika area sedang Terisi)
		else
			warn("Pick mode: Mengambil mobil dari parkiran...")
			local myCars = area:FindFirstChild("MyCars")

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

function ParkingAreaManager:Init()
	local function onSpawnerAdded(area: Part)
		task.spawn(parkedInArea, area)
	end

	-- 1. Tangani objek yang baru muncul nanti (Dynamic)
	CollectionService:GetInstanceAddedSignal(SPAWNER_TAG):Connect(onSpawnerAdded)

	-- 2. Tangani objek yang sudah ada sekarang (Static/Pre-loaded)
	for _, area in pairs(CollectionService:GetTagged(SPAWNER_TAG)) do
		onSpawnerAdded(area)
	end
end

function ParkingAreaManager.storeCar(player: Player, area: Part, tool: Tool): ()
	assert(player and area and tool, "Missing arguments for storeCar")
	storeCarToArea(player, area, tool)
end

return ParkingAreaManager

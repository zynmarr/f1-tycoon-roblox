local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local Players = game:GetService("Players")
local Networker = require(ReplicatedStorage.Packages.Networker)

-- ===============================================
-- SELLGUI SERVER HANDLER (NETWORKER VERSION)
-- ===============================================

local MAX_DISTANCE = 200

local SellGuiManager = {}

-- ===============================================
-- SELL SINGLE CAR
-- ===============================================
function SellGuiManager:sellCar(player, car, stackChildName)
	if not player or not player.Parent then
		return {
			Success = false,
			Error = "Player tidak ditemukan",
		}
	end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not root then
		return {
			Success = false,
			Error = "Character tidak ditemukan",
		}
	end

	-- ===== ANTI-CHEAT: Verifikasi lokasi =====
	local plotName = player:GetAttribute("MyPlotName")
	if not plotName or plotName == "" then
		return {
			Success = false,
			Error = "Plot tidak ditemukan",
		}
	end

	local myPlot = workspace.Plots:FindFirstChild(plotName)
	if not myPlot then
		return {
			Success = false,
			Error = "Plot tidak valid",
		}
	end

	local sellArea = myPlot:FindFirstChild("SellArea") and myPlot.SellArea:FindFirstChild("Area")
	if not sellArea then
		return {
			Success = false,
			Error = "Sell area tidak ditemukan",
		}
	end

	-- Hitung jarak asli di server
	local jarak = (root.Position - sellArea:GetPivot().Position).Magnitude
	if jarak > MAX_DISTANCE then
		warn("[ANTI-CHEAT] " .. player.Name .. " mencoba jual mobil dari luar area! Jarak: " .. jarak)
		return {
			Success = false,
			Error = "Anda terlalu jauh dari sell area! (" .. math.floor(jarak) .. "m)",
		}
	end

	-- ===== VALIDASI MOBIL =====
	local inBackpack = car and car:IsDescendantOf(player) or false
	local inCharacter = car and player.Character and car:IsDescendantOf(player.Character) or false
	
	print("[SellGuiServer] sellCar -> Player:", player.Name, "| Car:", tostring(car), "| Parent:", car and tostring(car.Parent) or "nil", "| inBackpack:", inBackpack, "| inCharacter:", inCharacter, "| Stack:", tostring(stackChildName))

	if not car or (not inBackpack and not inCharacter) then
		return {
			Success = false,
			Error = "Mobil tidak valid atau tidak milik Anda",
		}
	end

	-- ===== PROSES HARGA BERDASARKAN TUMPUKAN (STACK) =====
	local harga = 0
	local nama = car:GetAttribute("Name") or car.Name
	local amount = car:GetAttribute("Amount") or 1
	local stacksFolder = car:FindFirstChild("Stacks")

	if stackChildName and stackChildName ~= "" and amount > 1 then
		if stackChildName == "Base" then
			-- Jual mobil basis utama, promosikan stack berikutnya menjadi basis baru
			harga = car:GetAttribute("Price") or 0
			if stacksFolder then
				local allStacks = stacksFolder:GetChildren()
				if #allStacks > 0 then
					local nextConfig = allStacks[1]
					-- Salin atribut dari stack cadangan ke Tool utama
					for attrName, value in pairs(nextConfig:GetAttributes()) do
						car:SetAttribute(attrName, value)
					end
					nextConfig:Destroy()
				end
			end
			car:SetAttribute("Amount", amount - 1)
		else
			-- Jual salah satu mobil di dalam folder Stacks
			if stacksFolder then
				local configNode = stacksFolder:FindFirstChild(stackChildName)
				if configNode then
					harga = configNode:GetAttribute("Price") or 0
					configNode:Destroy()
					car:SetAttribute("Amount", amount - 1)
				else
					return {
						Success = false,
						Error = "Data tumpukan mobil tidak ditemukan",
					}
				end
			else
				return {
					Success = false,
					Error = "Folder tumpukan tidak ditemukan",
				}
			end
		end
	else
		-- Jual mobil tunggal (normal)
		harga = car:GetAttribute("Price") or 0
		car:Destroy()
	end

	-- Validasi harga hasil akhir
	if harga <= 0 or harga > 999999999 then
		warn("[ANTI-CHEAT] " .. player.Name .. " mencoba jual dengan harga invalid: " .. harga)
		return {
			Success = false,
			Error = "Harga mobil tidak valid",
		}
	end

	-- ===== EKSEKUSI TRANSAKSI =====
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats or not leaderstats:FindFirstChild("Cash") then
		return {
			Success = false,
			Error = "Leaderstats tidak ditemukan",
		}
	end

	-- Tambah uang
	leaderstats.Cash.Value = leaderstats.Cash.Value + harga

	print("[SellGui] " .. player.Name .. " cuan $" .. harga .. " dari " .. nama .. (stackChildName and " (Stack)" or ""))

	return {
		Success = true,
		Message = "Berhasil menjual " .. nama .. " seharga $" .. harga,
	}
end

-- ===============================================
-- SELL ALL CARS
-- ===============================================
function SellGuiManager:sellAllCars(player, cars)
	if not player or not player.Parent then
		return {
			Success = false,
			Error = "Player tidak ditemukan",
		}
	end

	if not cars or #cars == 0 then
		return {
			Success = false,
			Error = "Tidak ada mobil untuk dijual",
		}
	end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not root then
		return {
			Success = false,
			Error = "Character tidak ditemukan",
		}
	end

	-- ===== ANTI-CHEAT: Verifikasi lokasi =====
	local plotName = player:GetAttribute("MyPlotName")
	local myPlot = plotName and workspace.Plots:FindFirstChild(plotName)
	local sellArea = myPlot and myPlot:FindFirstChild("SellArea") and myPlot.SellArea:FindFirstChild("Area")

	if sellArea then
		local jarak = (root.Position - sellArea:GetPivot().Position).Magnitude
		if jarak > MAX_DISTANCE then
			return {
				Success = false,
				Error = "Anda terlalu jauh dari sell area! (" .. math.floor(jarak) .. "m)",
			}
		end
	end

	-- ===== PROSES SEMUA MOBIL =====
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats or not leaderstats:FindFirstChild("Cash") then
		return {
			Success = false,
			Error = "Leaderstats tidak ditemukan",
		}
	end

	local totalEarned = 0
	local carsCount = 0

	for _, car in ipairs(cars) do
		if car then
			local inBackpack = car:IsDescendantOf(player)
			local inCharacter = player.Character and car:IsDescendantOf(player.Character) or false
			if inBackpack or inCharacter then
				-- Tambahkan harga mobil utama
				local basePrice = car:GetAttribute("Price") or 0
				if basePrice > 0 and basePrice <= 999999999 then
					leaderstats.Cash.Value = leaderstats.Cash.Value + basePrice
					totalEarned = totalEarned + basePrice
					carsCount = carsCount + 1
				end

				-- Tambahkan harga dari seluruh mobil di dalam tumpukan Stacks
				local stacksFolder = car:FindFirstChild("Stacks")
				if stacksFolder then
					for _, configNode in ipairs(stacksFolder:GetChildren()) do
						if configNode:IsA("Configuration") then
							local stackPrice = configNode:GetAttribute("Price") or 0
							if stackPrice > 0 and stackPrice <= 999999999 then
								leaderstats.Cash.Value = leaderstats.Cash.Value + stackPrice
								totalEarned = totalEarned + stackPrice
								carsCount = carsCount + 1
							end
						end
					end
				end

				car:Destroy()
			end
		end
	end

	if carsCount > 0 then
		print("[SellGui] " .. player.Name .. " jual " .. carsCount .. " mobil, dapatkan $" .. totalEarned)
		return {
			Success = true,
			Message = "Berhasil menjual " .. carsCount .. " mobil seharga $" .. totalEarned,
		}
	else
		return {
			Success = false,
			Error = "Tidak ada mobil valid untuk dijual",
		}
	end
end

-- ===============================================
-- SETUP NETWORKER
-- ===============================================
Networker.server.new("SellGui", SellGuiManager, {
	SellGuiManager.sellCar,
	SellGuiManager.sellAllCars,
})

print("[SellGui Server] Initialized and ready!")

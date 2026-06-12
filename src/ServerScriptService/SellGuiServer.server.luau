local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local Players = game:GetService("Players")
local Networker = require(ReplicatedStorage.Packages.Networker)

-- ===============================================
-- SELLGUI SERVER HANDLER (NETWORKER VERSION)
-- ===============================================

local MAX_DISTANCE = 8

local SellGuiManager = {}

-- ===============================================
-- SELL SINGLE CAR
-- ===============================================
function SellGuiManager:sellCar(player, car)
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
	if not car or not car:IsDescendantOf(player) then
		return {
			Success = false,
			Error = "Mobil tidak valid atau tidak milik Anda",
		}
	end

	local harga = car:GetAttribute("Price") or 0
	if harga <= 0 or harga > 999999999 then
		warn("[ANTI-CHEAT] " .. player.Name .. " mencoba jual dengan harga invalid: " .. harga)
		return {
			Success = false,
			Error = "Harga mobil tidak valid",
		}
	end

	-- ===== EKSEKUSI TRANSAKSI =====
	local nama = car:GetAttribute("Name") or car.Name
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats or not leaderstats:FindFirstChild("Cash") then
		return {
			Success = false,
			Error = "Leaderstats tidak ditemukan",
		}
	end

	-- Tambah uang
	leaderstats.Cash.Value = leaderstats.Cash.Value + harga

	-- Hapus mobil
	car:Destroy()

	print("[SellGui] " .. player.Name .. " cuan $" .. harga .. " dari " .. nama)

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
		if car and car:IsDescendantOf(player) then
			local harga = car:GetAttribute("Price") or 0
			if harga > 0 and harga <= 999999999 then
				leaderstats.Cash.Value = leaderstats.Cash.Value + harga
				totalEarned = totalEarned + harga
				carsCount = carsCount + 1
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

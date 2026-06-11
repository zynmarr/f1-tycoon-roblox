local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local passAreaFolder = script.Parent
local areaModel = passAreaFolder:WaitForChild("Area") -- Ini adalah Model

-- ==========================================
-- MASUKKAN ID GAME PASS KAMU DI BAWAH INI
-- ==========================================
local GAME_PASS_ID = 1819444791

-- Tabel debounce untuk mencegah pop-up spam berkali-kali dalam 1 detik
local debounce = {}

local billboardGui = passAreaFolder.Area:FindFirstChildWhichIsA("BillboardGui", true)
local txtPassName = billboardGui:FindFirstChild("PassName")
local txtPrice = billboardGui.Frame:FindFirstChild("Price")

local function cleanUpCar()
	for _, car in pairs(passAreaFolder:GetChildren()) do
		if car:IsA("Tool") or car:IsA("Model") then
			for _, tool in pairs(car:GetDescendants()) do
				if tool:IsA("BasePart") then
					tool.Anchored = true
					tool.CanCollide = true
				end
			end
		end
	end
end

task.spawn(function()
	cleanUpCar()
	local success, passInfo = pcall(function()
		-- Enum.InfoType.GamePass wajib agar Roblox tahu ini ID Game Pass, bukan ID Baju/Model
		--return MarketplaceService:GetProductInfo(GAME_PASS_ID, Enum.InfoType.GamePass)
		return MarketplaceService:GetProductInfoAsync(GAME_PASS_ID, Enum.InfoType.GamePass)
	end)

	if success and passInfo then
		local namaPass = passInfo.Name
		local hargaPass = passInfo.PriceInRobux

		if txtPassName and txtPrice then
			txtPassName.Text = namaPass
			txtPrice.Text = hargaPass

			task.spawn(function()
				while txtPassName and txtPassName.Parent do
					-- tick() berjalan terus menerus seiring waktu.
					-- Angka 3 mengatur kecepatan (semakin kecil angka = semakin cepat ganti warna)
					local hue = (tick() % 3) / 3
					txtPassName.TextColor3 = Color3.fromHSV(hue, 1, 1)

					-- Jeda 1 frame agar animasi mulus dan tidak bikin lag
					task.wait()
				end
			end)
		else
			warn("BillboardGui atau TextLabel tidak ditemukan di dalam PassArea!")
		end
	else
		warn("Gagal memuat info Game Pass. Pastikan ID-nya benar.")
	end
end)

-- Kita pisahkan fungsi sentuhannya agar lebih rapi
local function onTouched(hit)
	local character = hit.Parent
	local player = Players:GetPlayerFromCharacter(character)

	-- Pastikan yang menginjak adalah pemain asli
	if player then
		-- Cek apakah player sedang dalam masa cooldown (debounce)
		if not debounce[player.UserId] then
			debounce[player.UserId] = true

			-- Cek dulu apakah player sudah membeli pass ini sebelumnya
			local success, hasPass = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAME_PASS_ID)
			end)

			if success and hasPass then
				print(player.Name .. " sudah memiliki Game Pass ini.")
			else
				-- Jika belum punya, munculkan layar pembelian
				MarketplaceService:PromptGamePassPurchase(player, GAME_PASS_ID)
			end

			-- Beri jeda 3 detik sebelum pop-up bisa terpancing lagi
			task.wait(3)
			debounce[player.UserId] = nil
		end
	end
end

-- ==========================================
-- PERBAIKAN: Looping untuk mendeteksi semua Part di dalam Model
-- ==========================================
for _, part in pairs(areaModel:GetDescendants()) do
	-- Pastikan hanya objek berbentuk part fisik yang dipasangi sensor
	if part:IsA("BasePart") then
		part.Touched:Connect(onTouched)
	end
end

local repStorage = game:GetService("ReplicatedStorage")
local prosesJualEvent = repStorage:WaitForChild("SellCarEvent")

-- Radius aman (Beri toleransi lag: Kalau client 12, di server kita kasih 16)
local MAX_DISTANCE = 16

prosesJualEvent.OnServerEvent:Connect(function(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not root then
		return
	end

	-- =======================================
	-- 1. VERIFIKASI KEAMANAN (ANTI-CHEAT)
	-- =======================================
	-- Cari plot milik player
	local plotName = player:GetAttribute("MyPlotName")
	if not plotName or plotName == "" then
		return
	end

	local myPlot = workspace.Plots:FindFirstChild(plotName)
	if not myPlot then
		return
	end

	-- Cari area jual di dalam plot tersebut
	local sellArea = myPlot:FindFirstChild("SellArea") and myPlot.SellArea:FindFirstChild("Area")
	if not sellArea then
		return
	end

	-- Hitung jarak asli di server (Hacker gak bisa nipu ini)
	local jarak = (root.Position - sellArea:GetPivot().Position).Magnitude
	if jarak > MAX_DISTANCE then
		warn("[ANTI-CHEAT] " .. player.Name .. " mencoba jual mobil dari luar area!")
		return
	end

	-- =======================================
	-- 2. CARI MOBIL DI TANGAN
	-- =======================================
	local mobilDiPegang = nil
	for _, obj in pairs(char:GetChildren()) do
		if (obj:IsA("Model") or obj:IsA("Tool")) and obj:GetAttribute("Price") then
			mobilDiPegang = obj
			break
		end
	end

	-- =======================================
	-- 3. EKSEKUSI TRANSAKSI & EFEK
	-- =======================================
	if mobilDiPegang then
		local harga = mobilDiPegang:GetAttribute("Price") or 0
		local nama = mobilDiPegang:GetAttribute("Name") or mobilDiPegang.Name
		local leaderstats = player:FindFirstChild("leaderstats")

		if leaderstats and leaderstats:FindFirstChild("Cash") then
			-- A. Tambah Uang
			leaderstats.Cash.Value += harga

			-- B. Tambah EXP Player (Misal 15 EXP per penjualan)
			local exp = player:FindFirstChild("Experience")
			if exp then
				exp.Value += 15
			end

			-- D. Hancurkan Mobil dari dunia nyata (Otomatis hilang dari tas/save)
			mobilDiPegang:Destroy()

			-- Log Sukses (Bisa dihapus nanti kalau menuhi Output)
			print(player.Name .. " cuan $" .. harga .. " dari " .. nama)
		end
	end
end)

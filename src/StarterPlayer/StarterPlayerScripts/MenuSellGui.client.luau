-- local player = game.Players.LocalPlayer
-- local repStorage = game:GetService("ReplicatedStorage")
-- local TweenService = game:GetService("TweenService")
-- local playerGui = player:WaitForChild("PlayerGui")

-- local gui = playerGui:WaitForChild("MenuSellGui") :: ScreenGui
-- local frame = gui:WaitForChild("Frame")
-- local txtInfo = frame:WaitForChild("TextLabel")
-- local btnJual = frame.Frame:WaitForChild("SellBtn")
-- local btnTutup = frame.Frame:WaitForChild("CloseBtn")

-- -- Tambahkan UIScale di dalam Frame lewat Studio, atau script ini bakal buatkan otomatis
-- local uiScale = frame:FindFirstChild("UIScale") or Instance.new("UIScale", frame)

-- -- =======================================
-- -- 1. SETUP UI & ANIMASI (Hanya Scale & Fade)
-- -- =======================================
-- frame.Visible = false
-- uiScale.Scale = 0

-- local function toggleUI(muncul)
-- 	if muncul then
-- 		frame.Visible = true
-- 		TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
-- 			Scale = 1,
-- 		}):Play()

-- 		pcall(function()
-- 			TweenService:Create(frame, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
-- 		end)
-- 	else
-- 		local closeTween =
-- 			TweenService:Create(uiScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
-- 				Scale = 0,
-- 			})
-- 		closeTween:Play()

-- 		pcall(function()
-- 			TweenService:Create(frame, TweenInfo.new(0.15), { GroupTransparency = 1 }):Play()
-- 		end)

-- 		closeTween.Completed:Wait()
-- 		frame.Visible = false
-- 	end
-- end

-- -- =======================================
-- -- 2. FORMAT ANGKA KE DOLAR ($,$$$)
-- -- =======================================
-- local function formatDollar(angka)
-- 	local str = tostring(angka)
-- 	return str:reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
-- end

-- -- =======================================
-- -- 3. DETEKSI PLOT OTOMATIS
-- -- =======================================
-- local AREA_HIJAU = nil
-- local RADIUS = 8

-- task.spawn(function()
-- 	while not AREA_HIJAU do
-- 		local plotName = player:GetAttribute("MyPlotName")
-- 		if plotName and plotName ~= "" then
-- 			local myPlot = workspace.Plots:FindFirstChild(plotName)
-- 			if myPlot then
-- 				local sellAreaFolder = myPlot:FindFirstChild("SellArea")
-- 				if sellAreaFolder then
-- 					AREA_HIJAU = sellAreaFolder:FindFirstChild("Area")
-- 				end
-- 			end
-- 		end
-- 		task.wait(1)
-- 	end
-- end)

-- -- =======================================
-- -- 4. MONITORING (OPTIMIZED POLLING WITH DEBOUNCING)
-- -- =======================================
-- local mobilDiPegang = nil
-- local uiSedangTerbuka = false
-- local lastUICheckTime = 0
-- local UI_CHECK_DEBOUNCE = 0.3 -- Check every 300ms instead of 200ms

-- -- Mengganti Heartbeat dengan loop yang lebih optimized
-- task.spawn(function()
-- 	while true do
-- 		task.wait(0.3) -- Cek setiap 300ms (kurangi dari 200ms untuk hemat CPU)

-- 		if not AREA_HIJAU then
-- 			continue
-- 		end

-- 		local char = player.Character
-- 		local root = char and char:FindFirstChild("HumanoidRootPart")
-- 		if not root then
-- 			continue
-- 		end

-- 		-- HITUNG JARAK (Gunakan squared distance untuk menghindari sqrt)
-- 		local delta = root.Position - AREA_HIJAU:GetPivot().Position
-- 		local jarak = math.sqrt(delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z)

-- 		-- Cari mobil di tangan
-- 		local mobilDiPegang = nil
-- 		for _, obj in pairs(char:GetChildren()) do
-- 			if (obj:IsA("Model") or obj:IsA("Tool")) and obj:GetAttribute("Price") then
-- 				mobilDiPegang = obj
-- 				break
-- 			end
-- 		end

-- 		-- LOGIKA UI dengan debouncing
-- 		if jarak <= RADIUS and mobilDiPegang then
-- 			if not uiSedangTerbuka then
-- 				uiSedangTerbuka = true

-- 				local nama = mobilDiPegang:GetAttribute("Name") or mobilDiPegang.Name
-- 				local harga = mobilDiPegang:GetAttribute("Price") or 0
-- 				local rarity = mobilDiPegang:GetAttribute("Rarity") or "Common"

-- 				txtInfo.Text = "Jual [" .. rarity .. "] " .. nama .. "\nHarga: $" .. formatDollar(harga) .. "?"
-- 				toggleUI(true)
-- 			end
-- 		else
-- 			-- Jika sudah di luar radius ATAU mobil lepas
-- 			if uiSedangTerbuka then
-- 				uiSedangTerbuka = false
-- 				toggleUI(false)
-- 			end
-- 		end
-- 	end
-- end)

-- -- =======================================
-- -- 5. BUTTON LOGIC
-- -- =======================================
-- local isSelling = false
-- btnJual.MouseButton1Click:Connect(function()
-- 	if isSelling then
-- 		return
-- 	end

-- 	if mobilDiPegang then
-- 		isSelling = true

-- 		local sfxTemplate = game:GetService("SoundService"):FindFirstChild("CuanSound")
-- 		if sfxTemplate then
-- 			local sfx = sfxTemplate:Clone()
-- 			sfx.Parent = gui
-- 			sfx:Play()
-- 			game:GetService("Debris"):AddItem(sfx, 3)
-- 		end

-- 		repStorage:WaitForChild("SellCarEvent"):FireServer()

-- 		uiSedangTerbuka = false
-- 		toggleUI(false)

-- 		task.wait(0.5)
-- 		isSelling = false
-- 	end
-- end)

-- btnTutup.MouseButton1Click:Connect(function()
-- 	uiSedangTerbuka = false
-- 	toggleUI(false)
-- end)

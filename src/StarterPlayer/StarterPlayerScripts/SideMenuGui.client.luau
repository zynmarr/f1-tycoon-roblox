local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local sideMenuGui = playerGui:WaitForChild("SideMenuGui", math.huge) :: ScreenGui
local container = sideMenuGui:WaitForChild("MainContainer")
local tweenService = game:GetService("TweenService")

-- Kecepatan animasi
local tweenInfo = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

for _, btn in pairs(container:GetChildren()) do
	-- Cek apakah objek tersebut adalah tombol
	if btn:IsA("TextButton") or btn:IsA("ImageButton") then
		-- Simpan ukuran asli tombol
		local ukuranAsli = btn.Size
		local ukuranHover =
			UDim2.new(btn.Size.X.Scale, btn.Size.X.Offset + 10, btn.Size.Y.Scale, btn.Size.Y.Offset + 10)

		-- Saat mouse masuk (Membesar)
		btn.MouseEnter:Connect(function()
			tweenService:Create(btn, tweenInfo, { Size = ukuranHover }):Play()
		end)

		-- Saat mouse keluar (Kembali normal)
		btn.MouseLeave:Connect(function()
			tweenService:Create(btn, tweenInfo, { Size = ukuranAsli }):Play()
		end)

		-- Saat tombol diklik (Efek mengecil sedikit)
		btn.MouseButton1Down:Connect(function()
			tweenService:Create(btn, TweenInfo.new(0.1), { Size = ukuranAsli }):Play()
		end)

		btn.MouseButton1Up:Connect(function()
			tweenService:Create(btn, tweenInfo, { Size = ukuranHover }):Play()
		end)
	end
end

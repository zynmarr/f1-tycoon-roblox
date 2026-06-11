local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Pastikan PlayerGui sudah ter-load sempurna
local playerGui = player:WaitForChild("PlayerGui")

-- ==========================================
-- PAKSA LAYAR BERPUTAR KE HORIZONTAL (LANDSCAPE)
-- ==========================================
-- Baris ini akan memaksa HP Android/iOS otomatis berputar tidur ke samping kiri atau kanan
task.spawn(function()
	-- Tunggu sebentar untuk memastikan semua UI sudah siap
	task.wait(1)

	-- Coba setel orientasi layar ke LandscapeSensor
	local success, err = pcall(function()
		playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
	end)

	if success then
		print("Screen orientation set to LandscapeSensor successfully.")
	else
		warn("Failed to set screen orientation: " .. tostring(err))
	end
end)

-- playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

-- [OPSIONAL] Jika nanti setelah loading selesai kamu mau membebaskannya lagi:
-- playerGui.ScreenOrientation = Enum.ScreenOrientation.Sensor

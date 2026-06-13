local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- Menunggu RemoteEvent dari server (TIDAK membuat dari client untuk keamanan)
local notifEvent = ReplicatedStorage:WaitForChild("NotifEvent", 10)
if not notifEvent then
	warn("[NotifHandler] NotifEvent tidak ditemukan dari server!")
	return
end

-- Mendengarkan sinyal dari Server
notifEvent.OnClientEvent:Connect(function(judul, pesan, durasi)
	durasi = durasi or 3 -- Default 3 detik jika tidak diatur

	local success, err = pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = judul;
			Text = pesan;
			Duration = durasi;
		})
	end)

	if not success then
		warn("Gagal menampilkan notifikasi: " .. tostring(err))
	end
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- Membuat RemoteEvent secara otomatis jika belum ada di ReplicatedStorage
local notifEvent = ReplicatedStorage:FindFirstChild("NotifEvent")
if not notifEvent then
	notifEvent = Instance.new("RemoteEvent")
	notifEvent.Name = "NotifEvent"
	notifEvent.Parent = ReplicatedStorage
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

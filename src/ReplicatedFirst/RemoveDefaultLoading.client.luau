--!strict
-- src/ReplicatedFirst/RemoveDefaultLoading.client.luau
-- Hapus loading screen bawaan Roblox secara instan sejak frame pertama saat game dimuat

local ReplicatedFirst = game:GetService("ReplicatedFirst")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)
print("[ReplicatedFirst] 🚫 Loading screen bawaan Roblox telah dimatikan secara instan!")

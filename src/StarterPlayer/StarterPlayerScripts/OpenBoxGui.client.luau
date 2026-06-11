local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("OpenBoxGui") :: ScreenGui
local button = screenGui:WaitForChild("OpenBtn")
local Networker = require(ReplicatedStorage.Packages.Networker)

local serviceClient = {}

button.Activated:Connect(function()
	local character = player.Character or player.CharacterAdded:Wait()
	local selectedBox: string? = nil

	-- Cari box yang sedang dipegang (OnHand) baik di Backpack atau di Character
	-- Karena saat di-equip, Tool berpindah dari Backpack ke Character!
	local toolInHand = character:FindFirstChildWhichIsA("Tool")
	if toolInHand and toolInHand:GetAttribute("OnHand") then
		selectedBox = toolInHand.Name
	else
		-- Jika tidak di tangan, cari di backpack
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			for _, item in pairs(backpack:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute("Level") then
					selectedBox = item.Name
					break
				end
			end
		end
	end

	-- Validasi: pastikan ada box yang akan dibuka
	if not selectedBox then
		warn("❌ Tidak ada box untuk dibuka atau dipegang!")
		return
	end

	print(`🎁 Mengirim event OpenBox untuk kotak: {selectedBox}`)

	-- Inisialisasi networker client menuju kanal "OpenBox"
	local networker = Networker.client.new("OpenBox", serviceClient)

	-- Panggil server (Gunakan :invoke() jika mengharapkan return/kembalian data, atau :fire() jika hanya satu arah)
	-- Asumsi: Networker Anda menggunakan :invoke() untuk mendapatkan return nilai table gacha
	local result = networker:fetch("openBox", selectedBox)

	if result and result.Success then
		print(`✅ {result.Message}`)
	else
		warn(`❌ Gagal membuka box: {result and result.Error or "Unknown error"}`)
	end
end)

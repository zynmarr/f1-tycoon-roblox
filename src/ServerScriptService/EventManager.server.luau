-- ==========================================
-- SCRIPT: EventManager (ServerScriptService)
-- ==========================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- 1. DAFTAR ADMIN (Mudah ditambah jika punya teman/staff)
local ADMINS = {
	["aceu9922"] = true,
}

-- 2. SETUP FOLDER & VALUES
local liveEvents = Instance.new("Folder")
liveEvents.Name = "LiveEvents"
liveEvents.Parent = ReplicatedStorage

local variantBoost = Instance.new("IntValue")
variantBoost.Name = "VariantBoost"
variantBoost.Value = 0 
variantBoost.Parent = liveEvents

local luckBoost = Instance.new("IntValue")
luckBoost.Name = "LuckyChanceBoost"
luckBoost.Value = 0
luckBoost.Parent = liveEvents

local expBoost = Instance.new("IntValue")
expBoost.Name = "ExpBoost"
expBoost.Value = 0 -- 0 artinya tidak ada bonus, 50 artinya +50% Exp
expBoost.Parent = liveEvents

-- Set nilai awal Attribute agar script lain tidak error mencari nilai 'nil'
ReplicatedStorage:SetAttribute("SpeedBoost", 0)

-- ==========================================
-- 3. SISTEM COMMAND PARSER (LEBIH AMAN & FLEKSIBEL)
-- ==========================================
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		-- 1. Keamanan: Berhenti jika player bukan admin
		if not ADMINS[player.Name] then return end

		-- 2. Memecah pesan chat berdasarkan Spasi
		-- Contoh Chat: "/luck 50" -> args[1] = "/luck", args[2] = "50"
		local args = string.split(msg, " ")

		-- Jadikan command huruf kecil semua agar tidak sensitif huruf besar/kecil
		local command = string.lower(args[1]) 

		-- Ubah argumen kedua menjadi angka (menghindari error teks)
		local value = tonumber(args[2]) 

		-- 3. LOGIKA COMMAND
		if command == "/variant" then
			if value then
				variantBoost.Value = value
				print(string.format("[EVENT] 🌟 Variant Boost aktif: %d%%", value))
				-- TODO: FireAllClients untuk memunculkan Banner UI di layar
			else
				warn("[EVENT] Format salah! Gunakan: /variant [angka]")
			end

		elseif command == "/luck" then
			if value then
				luckBoost.Value = value
				print(string.format("[EVENT] 🍀 Lucky Chance diset: %d", value))
			else
				warn("[EVENT] Format salah! Gunakan: /luck [angka]")
			end
			
		elseif command == "/exp" then
			if value then
				expBoost.Value = value
				print(string.format("[EVENT] 🆙 Exp Boost aktif: +%d%%", value))
			else
				warn("[EVENT] Format salah! Gunakan: /exp [angka]")
			end

		elseif command == "/speed" then
			if value then
				ReplicatedStorage:SetAttribute("SpeedBoost", value)
				print(string.format("[EVENT] ⚡ Speed Boost aktif: %d", value))
			else
				warn("[EVENT] Format salah! Gunakan: /speed [angka]")
			end

		elseif command == "/stop" then
			-- Reset Semua
			variantBoost.Value = 0
			luckBoost.Value = 0
			ReplicatedStorage:SetAttribute("SpeedBoost", 0)
			print("[EVENT] 🛑 SEMUA EVENT TELAH DIMATIKAN!")
			-- TODO: FireAllClients untuk menyembunyikan Banner UI
		end
	end)
end)
-- ==========================================
-- SCRIPT: EventManager (ServerScriptService)
-- ==========================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- 1. IMPORT ROLE MANAGER
local RoleManager = require(script.Parent:WaitForChild("RoleManager"):WaitForChild("RoleManager"))

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

local commandCooldowns = {}
local COOLDOWN_DURATION = 1 -- 1 detik antar command

local function checkCooldown(playerId)
	local lastCommand = commandCooldowns[playerId] or 0
	local now = tick()

	if now - lastCommand < COOLDOWN_DURATION then
		return false
	end

	commandCooldowns[playerId] = now
	return true
end

-- ==========================================
-- 3. SISTEM COMMAND PARSER (LEBIH AMAN & FLEKSIBEL)
-- ==========================================
local function onPlayerAdded(player)
	player.Chatted:Connect(function(msg)
		-- 1. Keamanan: Berhenti jika player tidak memiliki izin mengubah konfigurasi event game
		if not RoleManager.hasPermission(player, "EditGameConfigs") then
			return
		end

		if not checkCooldown(player.UserId) then
			warn("[EVENT] ⏱️ Command terlalu cepat! Tunggu " .. COOLDOWN_DURATION .. " detik")
			return
		end

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
				variantBoost.Value = math.clamp(value, 0, 100)
				print(
					string.format(
						"[EVENT] 🌟 Variant Boost aktif: %d%% | Admin: %s (ID: %d)",
						variantBoost.Value,
						player.Name,
						player.UserId
					)
				)
			else
				warn("[EVENT] Format salah! Gunakan: /variant [angka]")
			end
		elseif command == "/luck" then
			if value then
				luckBoost.Value = math.clamp(value, 0, 500)
				print(
					string.format(
						"[EVENT] 🍀 Lucky Chance diset: %d%% | Admin: %s (ID: %d)",
						luckBoost.Value,
						player.Name,
						player.UserId
					)
				)
			else
				warn("[EVENT] Format salah! Gunakan: /luck [angka]")
			end
		elseif command == "/exp" then
			if value then
				expBoost.Value = math.clamp(value, 0, 500)
				print(
					string.format(
						"[EVENT] 🆙 Exp Boost aktif: +%d%% | Admin: %s (ID: %d)",
						expBoost.Value,
						player.Name,
						player.UserId
					)
				)
			else
				warn("[EVENT] Format salah! Gunakan: /exp [angka]")
			end
		elseif command == "/speed" then
			if value then
				local clampedSpeed = math.clamp(value, 0, 100)
				ReplicatedStorage:SetAttribute("SpeedBoost", clampedSpeed)
				print(
					string.format(
						"[EVENT] ⚡ Speed Boost aktif: %d%% | Admin: %s (ID: %d)",
						clampedSpeed,
						player.Name,
						player.UserId
					)
				)
			else
				warn("[EVENT] Format salah! Gunakan: /speed [angka]")
			end
		elseif command == "/stop" then
			if #args > 1 then
				warn("[EVENT] ❌ Command /stop tidak butuh argumen!")
				return
			end
			-- Reset Semua
			variantBoost.Value = 0
			luckBoost.Value = 0
			expBoost.Value = 0
			ReplicatedStorage:SetAttribute("SpeedBoost", 0)
			print(string.format("[EVENT] 🛑 SEMUA EVENT TELAH DIMATIKAN! | Admin: %s", player.Name))
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	commandCooldowns[player.UserId] = nil
end)

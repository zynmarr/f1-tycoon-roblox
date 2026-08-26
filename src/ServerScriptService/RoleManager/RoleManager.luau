--!strict
local RoleManager = {} :: any
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MessagingService = game:GetService("MessagingService")

local RoleConfig = require(ReplicatedStorage:WaitForChild("RoleConfig"))

-- Cache data role player saat ini di dalam server
local playerRoles = {} -- { [Player]: string }

-- Cache daftar staff global yang dimuat dari DataStore
local staffDatabase = {} -- { [string]: string } -- { ["UserId"]: "Moderator" }

-- CONFIGS
local VIP_GAMEPASS_ID = 1819444791 -- Ganti dengan ID Gamepass VIP Anda

local OWNER_USER_IDS = {
	[8361115924] = true, -- UserID Owner Utama
	-- [7612035806] = true, -- UserID Owner Kedua
}

local DEVELOPER_USER_IDS = {
	-- [UserID] = true (Jika ada Developer tambahan yang ingin di-hardcode)
}

-- DataStore khusus Staff Registry
local StaffDataStore = DataStoreService:GetDataStore("StaffRegistry_V1")

-- Load database staff global saat server menyala
local function loadStaffDatabase()
	local success, result = pcall(function()
		return StaffDataStore:GetAsync("GlobalStaffList")
	end)
	if success and type(result) == "table" then
		staffDatabase = result
		print("[RoleManager] Berhasil memuat daftar staff global dari DataStore.")
	else
		staffDatabase = {}
		warn("[RoleManager] Gagal memuat daftar staff global, membuat list kosong.")
	end
end

-- Simpan database staff global ke DataStore
local function saveStaffDatabase()
	local success, err = pcall(function()
		StaffDataStore:SetAsync("GlobalStaffList", staffDatabase)
	end)
	if success then
		print("[RoleManager] Daftar staff global berhasil disimpan ke DataStore.")
	else
		warn("[RoleManager] Gagal menyimpan daftar staff global: " .. tostring(err))
	end
end

-- Menentukan role pemain saat bergabung
function RoleManager.determineRole(player: Player): string
	local userIdStr = tostring(player.UserId)

	-- Otomatis jadikan Owner jika testing di Roblox Studio (biar gak stuck saat test play)
	if RunService:IsStudio() then
		return "Owner"
	end

	-- 1. Cek Owner List (Hardcoded)
	if OWNER_USER_IDS[player.UserId] then
		return "Owner"
	end

	-- 2. Cek Developer List (Hardcoded)
	if DEVELOPER_USER_IDS[player.UserId] then
		return "Developer"
	end

	-- 3. Cek Database Staff Global (Moderator/Developer dinamis)
	if staffDatabase[userIdStr] then
		local dbRole = staffDatabase[userIdStr]
		if RoleConfig.Roles[dbRole] then
			return dbRole
		end
	end

	-- 4. Cek Gamepass VIP
	local hasVIP = false
	local gpSuccess, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
	end)
	if gpSuccess then
		hasVIP = result
	end

	if hasVIP then
		return "VIP"
	end

	return "Player"
end

-- Ambil role pemain aktif
function RoleManager.getPlayerRole(player: Player): string
	return playerRoles[player] or "Player"
end

-- Validasi hak akses pemain
function RoleManager.hasPermission(player: Player, permission: string): boolean
	local roleName = RoleManager.getPlayerRole(player)
	local roleData = RoleConfig.Roles[roleName]
	if not roleData then
		return false
	end

	-- Owner dan Developer bypass semua permission
	if roleName == "Owner" or roleName == "Developer" then
		return true
	end

	return table.find(roleData.Permissions, permission) ~= nil
end

-- Mengangkat / mempromosikan staff baru (Hanya bisa dipanggil oleh Owner)
function RoleManager.promote(executor: Player, targetUserId: number, roleName: string): (boolean, string)
	local executorRole = RoleManager.getPlayerRole(executor)
	if executorRole ~= "Owner" then
		return false, "Hanya Owner yang dapat mempromosikan staff!"
	end

	if not RoleConfig.Roles[roleName] then
		return false, "Role '" .. roleName .. "' tidak terdaftar!"
	end

	if roleName == "Owner" then
		return false, "Owner tambahan tidak bisa diangkat melalui DataStore demi alasan keamanan!"
	end

	local targetUserIdStr = tostring(targetUserId)
	staffDatabase[targetUserIdStr] = roleName
	saveStaffDatabase()

	-- Terapkan langsung secara instan jika player target sedang online di server ini
	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if targetPlayer then
		playerRoles[targetPlayer] = roleName
		targetPlayer:SetAttribute("Role", roleName)
	end

	return true, "Berhasil mempromosikan UserID " .. targetUserId .. " menjadi " .. roleName
end

-- Menurunkan pangkat staff (Hanya bisa dipanggil oleh Owner)
function RoleManager.demote(executor: Player, targetUserId: number): (boolean, string)
	local executorRole = RoleManager.getPlayerRole(executor)
	if executorRole ~= "Owner" then
		return false, "Hanya Owner yang dapat menurunkan pangkat staff!"
	end

	local targetUserIdStr = tostring(targetUserId)
	if not staffDatabase[targetUserIdStr] then
		return false, "Pemain tersebut tidak terdaftar di database staff global!"
	end

	staffDatabase[targetUserIdStr] = nil
	saveStaffDatabase()

	-- Terapkan langsung secara instan jika player target sedang online di server ini
	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if targetPlayer then
		local fallbackRole = RoleManager.determineRole(targetPlayer)
		playerRoles[targetPlayer] = fallbackRole
		targetPlayer:SetAttribute("Role", fallbackRole)
	end

	return true, "Berhasil menurunkan pangkat UserID " .. targetUserId
end

-- Memberikan hadiah mobil Celestial (Rarity Tertinggi) 1 kali untuk pembeli F1 Pass / VIP
local function checkAndGiveF1PassBonusCar(player: Player)
	local DataManager = require(game:GetService("ServerScriptService"):WaitForChild("DataManager"):WaitForChild("DataManager"))
	local pData = DataManager.getPlayerData(player)
	if not pData then
		return
	end

	-- Pastikan bonus hanya diberikan 1 kali (Cek flag HasReceivedF1PassCar)
	if not pData.HasReceivedF1PassCar then
		pData.HasReceivedF1PassCar = true
		DataManager.syncData(player)

		-- Berikan mobil Rarity Tertinggi (Celestial): Triple Crown MCL60 - Lando Norris
		local EventManager = require(game:GetService("ServerScriptService"):WaitForChild("EventManager"):WaitForChild("EventManager"))
		local bonusCarName = "Triple Crown MCL60 - Lando Norris"
		pcall(function()
			(EventManager :: any).giftCarToPlayer(player, bonusCarName, { "Cosmic" })
		end)

		local NotifEvent = ReplicatedStorage:FindFirstChild("NotifEvent")
		if NotifEvent then
			NotifEvent:FireClient(
				player,
				"🎁 F1 PASS BONUS",
				"Selamat! Anda mendapatkan mobil Rarity Tertinggi (Celestial): " .. bonusCarName .. "!",
				5
			)
		end
		print(`[RoleManager] 🏎️ Berhasil memberikan F1 Pass Bonus Car (Celestial) ke {player.Name}`)
	end
end

-- Memproses pembelian gamepass dan memicu pengumuman global
function RoleManager.handleGamePassPurchase(player: Player, gamePassId: number)
	-- Update instan role VIP di server jika membeli VIP gamepass
	if gamePassId == VIP_GAMEPASS_ID then
		playerRoles[player] = "VIP"
		player:SetAttribute("Role", "VIP")
		print(`[RoleManager] {player.Name} membeli VIP gamepass. Role diupdate secara instan!`)
		task.spawn(checkAndGiveF1PassBonusCar, player)
	end

	-- Dapatkan info gamepass secara dinamis
	local success, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(gamePassId, Enum.InfoType.GamePass)
	end)

	local gamePassName = success and info and info.Name or "Gamepass #" .. tostring(gamePassId)
	local roleName = RoleManager.getPlayerRole(player)

	local payload = {
		PlayerName = player.Name,
		GamePassName = gamePassName,
		RoleName = roleName,
	}

	-- Kirim siaran global
	local publishSuccess, err = pcall(function()
		MessagingService:PublishAsync("GlobalGamePassPurchase", payload)
	end)

	if not publishSuccess then
		warn("[RoleManager] Gagal mengirim siaran global gamepass: " .. tostring(err))
	end
end

-- Inisialisasi Server
function RoleManager.Init()
	print("[RoleManager] Memulai inisialisasi...")
	loadStaffDatabase()

	local function onPlayerAdded(player: Player)
		local role = RoleManager.determineRole(player)
		playerRoles[player] = role
		player:SetAttribute("Role", role)

		local roleData = RoleConfig.Roles[role]
		print(
			string.format(
				"[RoleManager] %s bergabung dengan role: %s (Pangkat %d)",
				player.Name,
				roleData.DisplayName,
				roleData.Rank
			)
		)

		-- Cek jika pemilik F1 Pass / VIP belum menerima bonus mobil Celestial saat login
		if role == "VIP" or role == "Owner" or role == "Developer" then
			task.spawn(function()
				task.wait(3) -- Tunggu data ter-load penuh
				checkAndGiveF1PassBonusCar(player)
			end)
		end

		-- Setup Chat Commands untuk Owner
		player.Chatted:Connect(function(msg)
			local roleName = RoleManager.getPlayerRole(player)
			if roleName ~= "Owner" then
				return
			end

			local args = string.split(msg, " ")
			local command = string.lower(args[1])

			if command == "/promote" then
				local targetId = tonumber(args[2])
				local promoteRole = args[3]
				if targetId and promoteRole then
					local success, response = RoleManager.promote(player, targetId, promoteRole)
					if success then
						print("[RoleManager] " .. response)
					else
						warn("[RoleManager] " .. response)
					end
				else
					warn("[RoleManager] Format salah! Gunakan: /promote [targetUserId] [RoleName]")
				end
			elseif command == "/demote" then
				local targetId = tonumber(args[2])
				if targetId then
					local success, response = RoleManager.demote(player, targetId)
					if success then
						print("[RoleManager] " .. response)
					else
						warn("[RoleManager] " .. response)
					end
				else
					warn("[RoleManager] Format salah! Gunakan: /demote [targetUserId]")
				end
			end
		end)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		playerRoles[player] = nil
	end)

	-- Hubungkan listener pembelian gamepass
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
		if wasPurchased then
			task.spawn(function()
				RoleManager.handleGamePassPurchase(player, gamePassId)
			end)
		end
	end)

	-- Berlangganan ke siaran gamepass global lintas server
	pcall(function()
		MessagingService:SubscribeAsync("GlobalGamePassPurchase", function(message)
			local data = message.Data
			if not data or type(data) ~= "table" then
				return
			end

			local playerName = data.PlayerName
			local gamePassName = data.GamePassName
			local roleName = data.RoleName or "Player"

			-- Dapatkan role info untuk mewarnai prefix
			local roleData = RoleConfig.Roles[roleName]
			local roleColorHex = roleData and roleData.Color:ToHex() or "AFAFAF"
			local roleEmoji = roleData and roleData.Emoji or ""
			local roleDisplayName = roleData and roleData.DisplayName or "Player"

			-- Bangun teks rich text
			local prefixText = ""
			if roleName ~= "Player" and roleData then
				prefixText = string.format(
					"<font color='#%s'><b>[%s %s]</b></font> ",
					roleColorHex,
					roleEmoji,
					string.upper(roleDisplayName)
				)
			end

			local playerText = string.format("<font color='#%s'><b>%s</b></font>", roleColorHex, playerName)
			local messageBody = string.format(": baru saja membeli Gamepass <b>%s</b>!", gamePassName)
			-- Ikon global 🌐 dengan warna emas khas VIP (#ffc800) untuk badan pesan
			local richText =
				string.format("🌐 %s%s<font color='#ffc800'>%s</font>", prefixText, playerText, messageBody)

			print("[RoleManager] Menyiarkan pengumuman global gamepass: " .. playerName .. " membeli " .. gamePassName)

			-- Siarkan ke Client untuk ditampilkan di Chat UI
			local chatAnnounceEventOptional = ReplicatedStorage:FindFirstChild("ChatAnnounceEvent") :: RemoteEvent?
			local chatAnnounceEvent: RemoteEvent
			if not chatAnnounceEventOptional then
				local newEvent = Instance.new("RemoteEvent") :: RemoteEvent
				newEvent.Name = "ChatAnnounceEvent"
				newEvent.Parent = ReplicatedStorage
				chatAnnounceEvent = newEvent
			else
				chatAnnounceEvent = chatAnnounceEventOptional :: RemoteEvent
			end

			chatAnnounceEvent:FireAllClients(richText)
		end)
	end)
end

return RoleManager

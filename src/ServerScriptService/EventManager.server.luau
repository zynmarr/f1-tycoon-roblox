-- ==========================================
-- SCRIPT: EventManager (ServerScriptService)
-- ==========================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")

-- 1. IMPORT ROLE MANAGER, NETWORKER & PARKING AREA
local RoleManager = require(script.Parent:WaitForChild("RoleManager"):WaitForChild("RoleManager"))
local Networker = require(ReplicatedStorage.Packages.Networker)
local ParkingAreaManager = require(script.Parent:WaitForChild("ParkingAreaManager"):WaitForChild("ParkingAreaManager"))

-- Buat RemoteEvent untuk pengumuman
local announcementEvent = ReplicatedStorage:FindFirstChild("AnnouncementEvent")
if not announcementEvent then
	announcementEvent = Instance.new("RemoteEvent")
	announcementEvent.Name = "AnnouncementEvent"
	announcementEvent.Parent = ReplicatedStorage
end

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

local goldenBoost = Instance.new("IntValue")
goldenBoost.Name = "VariantBoost_Golden"
goldenBoost.Value = 0
goldenBoost.Parent = liveEvents

local rainbowBoost = Instance.new("IntValue")
rainbowBoost.Name = "VariantBoost_Rainbow"
rainbowBoost.Value = 0
rainbowBoost.Parent = liveEvents

local galaxyBoost = Instance.new("IntValue")
galaxyBoost.Name = "VariantBoost_Galaxy"
galaxyBoost.Value = 0
galaxyBoost.Parent = liveEvents

local hellfireBoost = Instance.new("IntValue")
hellfireBoost.Name = "VariantBoost_Hellfire"
hellfireBoost.Value = 0
hellfireBoost.Parent = liveEvents

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
			goldenBoost.Value = 0
			rainbowBoost.Value = 0
			galaxyBoost.Value = 0
			hellfireBoost.Value = 0
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

-- ==========================================
-- 4. NETWORKER ADMIN EVENT SERVICE ENDPOINTS
-- ==========================================
local AdminEventService = {}
local TOPIC_NAME = "GlobalAdminEvents_V1"

local function applyLocalEventValues(values)
	variantBoost.Value = math.clamp(values.VariantBoost or 0, 0, 100)
	luckBoost.Value = math.clamp(values.LuckBoost or 0, 0, 500)
	expBoost.Value = math.clamp(values.ExpBoost or 0, 0, 500)
	ReplicatedStorage:SetAttribute("SpeedBoost", math.clamp(values.SpeedBoost or 0, 0, 100))

	goldenBoost.Value = math.clamp(values.VariantBoost_Golden or 0, 0, 50)
	rainbowBoost.Value = math.clamp(values.VariantBoost_Rainbow or 0, 0, 50)
	galaxyBoost.Value = math.clamp(values.VariantBoost_Galaxy or 0, 0, 50)
	hellfireBoost.Value = math.clamp(values.VariantBoost_Hellfire or 0, 0, 50)
end

local function stopLocalEvents()
	variantBoost.Value = 0
	luckBoost.Value = 0
	expBoost.Value = 0
	ReplicatedStorage:SetAttribute("SpeedBoost", 0)

	goldenBoost.Value = 0
	rainbowBoost.Value = 0
	galaxyBoost.Value = 0
	hellfireBoost.Value = 0
end

local function displayLocalAnnouncement(message, duration)
	local annEvent = ReplicatedStorage:FindFirstChild("AnnouncementEvent")
	if annEvent then
		annEvent:FireAllClients(message, duration or 8)
	end
end

local function giftBoxToPlayer(player: Player, level: number)
	local boxTemplate = game:GetService("ServerStorage"):FindFirstChild("Box")
	local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
	if not boxTemplate then
		warn("[EventManager] Box template tidak ditemukan di ServerStorage!")
		return false
	end
	
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return false
	end
	
	local newBox = boxTemplate:Clone()
	
	-- Unanchor all parts to prevent player flinging
	for _, part in ipairs(newBox:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
		end
	end
	
	local initialLvlData = GameConfig.BoxLevels[level]
	if not initialLvlData then
		return false
	end
	
	newBox:SetAttribute("Owner", player.Name)
	newBox:SetAttribute("HasPicked", true)
	newBox:SetAttribute("Level", level)
	newBox:SetAttribute("Exp", 0)
	newBox:SetAttribute("Variants", "Admin")
	newBox:SetAttribute("Type", "Box")
	newBox:SetAttribute("MaxExp", initialLvlData.MaxExp)
	newBox:SetAttribute("Name", initialLvlData.Name)
	newBox:SetAttribute("LuckyChance", initialLvlData.LuckMulti)
	newBox.Name = initialLvlData.Name .. "_Variant_Admin"

	newBox.Handle.Size = Vector3.new(2, 2, 2)
	
	local display = newBox.Handle:FindFirstChild("StatsDisplay")
	if not display then
		local moduleNode = newBox:FindFirstChild("BoxModule")
		local moduleDisplay = moduleNode and moduleNode:FindFirstChild("StatsDisplay")
		if moduleDisplay then
			display = moduleDisplay:Clone()
			display.Parent = newBox.Handle
		end
	end
	if display then
		display.Enabled = true
	end
	
	local boxModule = newBox:FindFirstChild("BoxModule")
	if boxModule then
		local BoxModuleRequire = require(boxModule)
		BoxModuleRequire.UpdateBoxText(newBox.Handle, level, 0, initialLvlData.MaxExp, "Admin")
	end
	
	newBox.Parent = backpack
	return true
end

local function giftCarToPlayer(player: Player, carName: string, variant: string?)
	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
	
	local foundTemplate = nil
	local foundRarity = "Common"
	
	for _, carTemplate in ipairs(CollectionService:GetTagged("Car")) do
		if carTemplate:IsDescendantOf(ServerStorage) and carTemplate.Name == carName then
			foundTemplate = carTemplate
			local parent = carTemplate.Parent
			if parent and parent:IsA("Folder") then
				foundRarity = parent.Name
			end
			break
		end
	end
	
	if not foundTemplate then
		return false
	end
	
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return false
	end
	
	-- Check capacity
	local inventoryCount = #backpack:GetChildren()
	local maxInventorySlots = GameConfig.MaxInventorySlots or 50
	if inventoryCount >= maxInventorySlots then
		return false
	end
	
	local car = foundTemplate:Clone()
	CollectionService:AddTag(car, "Car")
	
	-- Unanchor all parts to prevent player flinging
	for _, part in ipairs(car:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
		end
	end
	
	local tierData = GameConfig.Rarities[foundRarity] or { BasePrice = 1000 }
	local variants = variant or "Admin"
	local baseIncome = GameConfig.CalculatePrice(tierData.BasePrice, foundRarity, variants)
	local sellPrice = math.floor(baseIncome * 0.6)
	
	car:SetAttribute("Income", baseIncome)
	car:SetAttribute("Price", sellPrice)
	car:SetAttribute("Variant", variants)
	car:SetAttribute("Rarity", foundRarity)
	car:SetAttribute("Name", car.Name)
	car:SetAttribute("Type", "Car")
	car.Name = car.Name .. "_" .. foundRarity .. "_" .. variants
	
	GameConfig.ApplyVisuals(car, foundRarity, variants)
	
	local existingCar = backpack:FindFirstChild(car.Name)
	if existingCar then
		local stackFolder = existingCar:FindFirstChild("Stacks") or Instance.new("Folder", existingCar)
		stackFolder.Name = "Stacks"
		
		local carData = Instance.new("Configuration")
		carData.Name = "CarData_" .. (#stackFolder:GetChildren() + 1)
		for name, value in pairs(car:GetAttributes()) do
			carData:SetAttribute(name, value)
		end
		carData.Parent = stackFolder
		
		local carAmount = existingCar:GetAttribute("Amount") or 1
		existingCar:SetAttribute("Amount", carAmount + 1)
		car:Destroy()
	else
		car:SetAttribute("Amount", 1)
		car.Parent = backpack
	end
	
	return true
end

local function giftLocalPlayer(targetPlayerName, giftType, params)
	local targetPlayers = {}
	if targetPlayerName == "All" then
		targetPlayers = Players:GetPlayers()
	else
		local target = Players:FindFirstChild(targetPlayerName)
		if target then
			table.insert(targetPlayers, target)
		end
	end

	for _, p in ipairs(targetPlayers) do
		pcall(function()
			if giftType == "Cash" then
				local amount = params.Amount or 0
				local leaderstats = p:FindFirstChild("leaderstats")
				local cash = leaderstats and leaderstats:FindFirstChild("Cash")
				if cash then
					cash.Value = cash.Value + amount
				end
			elseif giftType == "24hCash" then
				local rate = ParkingAreaManager.getPlayerPassiveIncome(p)
				local amount = rate * 24 * 3600
				local leaderstats = p:FindFirstChild("leaderstats")
				local cash = leaderstats and leaderstats:FindFirstChild("Cash")
				if cash then
					cash.Value = cash.Value + amount
				end
			elseif giftType == "Box" then
				local level = params.Level or 12
				giftBoxToPlayer(p, level)
			elseif giftType == "Car" then
				local carName = params.CarName
				if carName then
					giftCarToPlayer(p, carName)
				end
			end
		end)
	end
end

local function publishGlobalEvent(action: string, data: any)
	local success, err = pcall(function()
		local payload = {
			Action = action,
			Data = data,
			SenderServerId = game.JobId,
		}
		MessagingService:PublishAsync(TOPIC_NAME, HttpService:JSONEncode(payload))
	end)
	if not success then
		warn("[EventManager] Gagal mempublikasikan ke MessagingService: " .. tostring(err))
	end
end

local function onGlobalMessageReceived(messageData)
	local success, decoded = pcall(HttpService.JSONDecode, HttpService, messageData.Data)
	if not success or not decoded then return end
	
	-- Lewati jika dikirim oleh server ini sendiri
	if decoded.SenderServerId == game.JobId then
		return
	end
	
	local action = decoded.Action
	local data = decoded.Data
	
	if action == "UpdateEvents" then
		applyLocalEventValues(data)
	elseif action == "StopEvents" then
		stopLocalEvents()
	elseif action == "BroadcastMessage" then
		displayLocalAnnouncement(data.Message, data.Duration)
	elseif action == "GiftAll" then
		giftLocalPlayer("All", data.GiftType, data.Params)
	end
end

local subscribeSuccess, subscribeConnection = pcall(function()
	return MessagingService:SubscribeAsync(TOPIC_NAME, onGlobalMessageReceived)
end)

if not subscribeSuccess then
	warn("[EventManager] Gagal berlangganan ke MessagingService: " .. tostring(subscribeConnection))
end

-- --- API ENDPOINTS ---

function AdminEventService:setEventValues(player: Player, values: any, isGlobal: boolean)
	if not RoleManager.hasPermission(player, "EditGameConfigs") then
		return { Success = false, Error = "Akses ditolak! Anda tidak memiliki izin." }
	end
	if typeof(values) ~= "table" then
		return { Success = false, Error = "Parameter tidak valid!" }
	end

	applyLocalEventValues(values)
	
	if isGlobal then
		publishGlobalEvent("UpdateEvents", values)
	end

	print(string.format("[EVENT] ⚙️ Konfigurasi event diperbarui oleh Admin %s (Global: %s)", player.Name, tostring(isGlobal)))
	return { Success = true, Message = "Konfigurasi event berhasil diperbarui!" }
end

function AdminEventService:stopAllEvents(player: Player, isGlobal: boolean)
	if not RoleManager.hasPermission(player, "EditGameConfigs") then
		return { Success = false, Error = "Akses ditolak! Anda tidak memiliki izin." }
	end

	stopLocalEvents()
	
	if isGlobal then
		publishGlobalEvent("StopEvents", {})
	end

	print(string.format("[EVENT] 🛑 Semua event dimatikan oleh Admin %s (Global: %s)", player.Name, tostring(isGlobal)))
	return { Success = true, Message = "Semua event berhasil dimatikan!" }
end

function AdminEventService:broadcastMessage(player: Player, message: string, isGlobal: boolean)
	if not RoleManager.hasPermission(player, "EditGameConfigs") then
		return { Success = false, Error = "Akses ditolak! Anda tidak memiliki izin." }
	end
	if type(message) ~= "string" or message == "" then
		return { Success = false, Error = "Pesan tidak boleh kosong!" }
	end

	local formattedMessage = string.format("📢 <font color='#FF5533'><b>[ADMIN %s]</b></font>: %s", player.Name, message)
	
	displayLocalAnnouncement(formattedMessage, 8)
	
	if isGlobal then
		publishGlobalEvent("BroadcastMessage", { Message = formattedMessage, Duration = 8 })
	end

	return { Success = true, Message = "Pengumuman berhasil dikirim!" }
end

function AdminEventService:giftPlayerReward(player: Player, giftType: string, targetPlayerName: string, isGlobal: boolean, params: any)
	if not RoleManager.hasPermission(player, "EditGameConfigs") then
		return { Success = false, Error = "Akses ditolak! Anda tidak memiliki izin." }
	end
	if type(giftType) ~= "string" or type(targetPlayerName) ~= "string" then
		return { Success = false, Error = "Parameter tidak valid!" }
	end
	
	local parsedParams = params or {}
	giftLocalPlayer(targetPlayerName, giftType, parsedParams)
	
	if isGlobal and targetPlayerName == "All" then
		publishGlobalEvent("GiftAll", { GiftType = giftType, Params = parsedParams })
	end

	return { Success = true, Message = "Hadiah berhasil dikirim!" }
end

function AdminEventService:getAvailableCars(player: Player)
	if not RoleManager.hasPermission(player, "EditGameConfigs") then
		return {}
	end
	
	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	
	local cars = {}
	local added = {}
	
	for _, carTemplate in ipairs(CollectionService:GetTagged("Car")) do
		if carTemplate:IsDescendantOf(ServerStorage) and (carTemplate:IsA("Tool") or carTemplate:IsA("Model")) then
			local carName = carTemplate.Name
			if not added[carName] then
				added[carName] = true
				
				local rarity = "Common"
				local parent = carTemplate.Parent
				if parent and parent:IsA("Folder") then
					rarity = parent.Name
				end
				
				table.insert(cars, {
					Name = carName,
					Rarity = rarity,
				})
			end
		end
	end
	
	table.sort(cars, function(a, b)
		return a.Name < b.Name
	end)
	
	return cars
end

Networker.server.new("AdminEventService", AdminEventService, {
	AdminEventService.setEventValues,
	AdminEventService.stopAllEvents,
	AdminEventService.broadcastMessage,
	AdminEventService.giftPlayerReward,
	AdminEventService.getAvailableCars,
})


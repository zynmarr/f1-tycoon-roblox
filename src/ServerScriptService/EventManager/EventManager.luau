local EventManager = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")

local RoleManager = require(game.ServerScriptService.RoleManager.RoleManager)
local Networker = require(ReplicatedStorage.Packages.Networker)
local ParkingAreaManager = require(game.ServerScriptService.ParkingAreaManager.ParkingAreaManager)
local BoxManager = require(game.ServerScriptService.BoxManager.BoxManager)

-- Variables & Folder Setup
local announcementEvent = ReplicatedStorage:FindFirstChild("AnnouncementEvent")
if not announcementEvent then
	announcementEvent = Instance.new("RemoteEvent")
	announcementEvent.Name = "AnnouncementEvent"
	announcementEvent.Parent = ReplicatedStorage
end

local liveEvents = ReplicatedStorage:FindFirstChild("LiveEvents")
if not liveEvents then
	liveEvents = Instance.new("Folder")
	liveEvents.Name = "LiveEvents"
	liveEvents.Parent = ReplicatedStorage
end

local function getOrCreateInt(name, defaultValue)
	local val = liveEvents:FindFirstChild(name)
	if not val then
		val = Instance.new("IntValue")
		val.Name = name
		val.Value = defaultValue
		val.Parent = liveEvents
	end
	return val
end

local variantBoost = getOrCreateInt("VariantBoost", 0)
local luckBoost = getOrCreateInt("LuckyChanceBoost", 0)
local expBoost = getOrCreateInt("ExpBoost", 0)
local goldenBoost = getOrCreateInt("VariantBoost_Golden", 0)
local rainbowBoost = getOrCreateInt("VariantBoost_Rainbow", 0)
local galaxyBoost = getOrCreateInt("VariantBoost_Galaxy", 0)
local hellfireBoost = getOrCreateInt("VariantBoost_Hellfire", 0)

ReplicatedStorage:SetAttribute("SpeedBoost", 0)

local commandCooldowns = {}
local COOLDOWN_DURATION = 1

local function checkCooldown(playerId)
	local lastCommand = commandCooldowns[playerId] or 0
	local now = tick()
	if now - lastCommand < COOLDOWN_DURATION then
		return false
	end
	commandCooldowns[playerId] = now
	return true
end

local function onPlayerAdded(player)
	player.Chatted:Connect(function(msg)
		if not RoleManager.hasPermission(player, "EditGameConfigs") then
			return
		end

		if not checkCooldown(player.UserId) then
			warn("[EVENT] ⏱️ Command terlalu cepat! Tunggu " .. COOLDOWN_DURATION .. " detik")
			return
		end

		local args = string.split(msg, " ")
		local command = string.lower(args[1])
		local value = tonumber(args[2])

		if command == "/variant" then
			if value then
				variantBoost.Value = math.clamp(value, 0, 100)
				print(string.format("[EVENT] 🌟 Variant Boost aktif: %d%% | Admin: %s (ID: %d)", variantBoost.Value, player.Name, player.UserId))
			else
				warn("[EVENT] Format salah! Gunakan: /variant [angka]")
			end
		elseif command == "/luck" then
			if value then
				luckBoost.Value = math.clamp(value, 0, 500)
				print(string.format("[EVENT] 🍀 Lucky Chance diset: %d%% | Admin: %s (ID: %d)", luckBoost.Value, player.Name, player.UserId))
			else
				warn("[EVENT] Format salah! Gunakan: /luck [angka]")
			end
		elseif command == "/exp" then
			if value then
				expBoost.Value = math.clamp(value, 0, 500)
				print(string.format("[EVENT] 🆙 Exp Boost aktif: +%d%% | Admin: %s (ID: %d)", expBoost.Value, player.Name, player.UserId))
			else
				warn("[EVENT] Format salah! Gunakan: /exp [angka]")
			end
		elseif command == "/speed" then
			if value then
				local clampedSpeed = math.clamp(value, 0, 100)
				ReplicatedStorage:SetAttribute("SpeedBoost", clampedSpeed)
				print(string.format("[EVENT] ⚡ Speed Boost aktif: %d%% | Admin: %s (ID: %d)", clampedSpeed, player.Name, player.UserId))
			else
				warn("[EVENT] Format salah! Gunakan: /speed [angka]")
			end
		elseif command == "/stop" then
			if #args > 1 then
				warn("[EVENT] ❌ Command /stop tidak butuh argumen!")
				return
			end
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

local AdminEventService = {}
local TOPIC_NAME = "GlobalAdminEvents_V1"

local function applyEventValues(values)
	variantBoost.Value = math.clamp(values.VariantBoost or values.Variant or 0, 0, 100)
	luckBoost.Value = math.clamp(values.LuckBoost or values.Luck or 0, 0, 500)
	expBoost.Value = math.clamp(values.ExpBoost or values.Exp or 0, 0, 500)
	ReplicatedStorage:SetAttribute("SpeedBoost", math.clamp(values.SpeedBoost or values.Speed or 0, 0, 100))

	goldenBoost.Value = math.clamp(values.VariantBoost_Golden or values.Golden or 0, 0, 50)
	rainbowBoost.Value = math.clamp(values.VariantBoost_Rainbow or values.Rainbow or 0, 0, 50)
	galaxyBoost.Value = math.clamp(values.VariantBoost_Galaxy or values.Galaxy or 0, 0, 50)
	hellfireBoost.Value = math.clamp(values.VariantBoost_Hellfire or values.Hellfire or 0, 0, 50)
end

local function stopEvents()
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

local function giftBoxToPlayer(player: Player, level: number, extraVariants: {string}?)
	local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
	local initialLvlData = GameConfig.BoxLevels[level]
	if not initialLvlData then
		return false
	end
	
	local variantStr = "Admin"
	if extraVariants and #extraVariants > 0 then
		variantStr = "Admin," .. table.concat(extraVariants, ",")
	end
	
	local lvl30Data = GameConfig.BoxLevels[30]
	local luckyChance = lvl30Data and lvl30Data.LuckMulti or 500.0
	
	return BoxManager.giveBoxToPlayer(player, level, variantStr, luckyChance, player.Name)
end

local function giftCarToPlayer(player: Player, carName: string, extraVariants: {string}?)
	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
	
	local foundTemplate = nil
	local foundRarity = ""

	-- Cari template via tag CarModel di ServerStorage
	for _, carTemplate in ipairs(CollectionService:GetTagged("CarModel")) do
		if carTemplate:IsDescendantOf(ServerStorage) and carTemplate.Name == carName then
			foundTemplate = carTemplate
			break
		end
	end
	
	if not foundTemplate then
		warn("[EventManager] Mobil dengan nama " .. tostring(carName) .. " tidak ditemukan!")
		return false
	end

	-- Cari rarity dari GameConfig
	for rName, list in pairs(GameConfig.CarRarityList) do
		if list[carName] then
			foundRarity = rName
			break
		end
	end
	
	-- Jika tidak ada di list rarity (seperti mobil Admin custom baru), default ke "Admin"
	if foundRarity == "" then
		foundRarity = "Admin"
	end
	
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return false
	end
	
	local inventoryCount = #backpack:GetChildren()
	local maxInventorySlots = GameConfig.MaxInventorySlots or 50
	if inventoryCount >= maxInventorySlots then
		return false
	end
	
	-- Clone Tool "Car" dari ServerStorage
	local carToolTemplate = ServerStorage:FindFirstChild("Car")
	if not carToolTemplate then
		warn("[EventManager] Tool 'Car' tidak ditemukan di ServerStorage!")
		return false
	end

	local car = carToolTemplate:Clone()
	local carModel = foundTemplate:Clone()
	carModel.Name = "Model"
	carModel.Parent = car

	CollectionService:AddTag(car, "Car")
	
	for _, part in ipairs(car:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
		end
	end
	
	local variantStr = "Admin"
	if extraVariants and #extraVariants > 0 then
		variantStr = "Admin," .. table.concat(extraVariants, ",")
	end
	
	local tierData = GameConfig.Rarities[foundRarity] or { BasePrice = 1000 }
	local baseIncome, sellPrice = GameConfig.CalculatePrice(tierData.BasePrice, foundRarity, variantStr)
	
	car:SetAttribute("Income", baseIncome)
	car:SetAttribute("Price", sellPrice)
	car:SetAttribute("Variant", variantStr)
	car:SetAttribute("Rarity", foundRarity)
	car:SetAttribute("Name", foundTemplate.Name)
	car:SetAttribute("Type", "Car")
	car.Name = foundTemplate.Name .. "_" .. foundRarity .. "_" .. string.gsub(variantStr, ",", "_")

	pcall(function()
		GameConfig.ApplyVisuals(car, foundRarity, variantStr)
	end)
	
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
		local success, err = pcall(function()
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
				local level = params.Level or 30
				local extraVariants = params.ExtraVariants or {}
				giftBoxToPlayer(p, level, extraVariants)
			elseif giftType == "Car" then
				local carName = params.CarName or "Paindre Edition"
				local extraVariants = params.ExtraVariants or {}
				if carName then
					giftCarToPlayer(p, carName, extraVariants)
				end
			end
		end)
		if not success then
			warn("[EventManager] Error gifting reward: " .. tostring(err))
		end
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
	
	if decoded.SenderServerId == game.JobId then
		return
	end
	
	local action = decoded.Action
	local data = decoded.Data
	
	if action == "UpdateEvents" then
		applyEventValues(data)
	elseif action == "StopEvents" then
		stopEvents()
	elseif action == "BroadcastMessage" then
		displayLocalAnnouncement(data.Message, data.Duration)
	elseif action == "GiftAll" then
		giftLocalPlayer("All", data.GiftType, data.Params)
	end
end

function AdminEventService:getAdminCars(player: Player): { { Name: string } }
	if not RoleManager.hasPermission(player, "EditGameConfigs") then
		warn("[EventManager] Player " .. player.Name .. " mencoba mengambil list admin car tanpa permission!")
		return {}
	end

	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

	local cars = {}
	local added = {}
	
	for _, carTemplate in ipairs(CollectionService:GetTagged("CarModel")) do
		if carTemplate:IsDescendantOf(ServerStorage) then
			local carName = carTemplate.Name
			if not added[carName] then
				-- Cek apakah rarity-nya Admin atau tidak terdaftar (berarti custom Admin car)
				local isAdmin = true
				for rName, list in pairs(GameConfig.CarRarityList) do
					if rName ~= "Admin" and list[carName] then
						isAdmin = false
						break
					end
				end
				
				if isAdmin then
					added[carName] = true
					table.insert(cars, { Name = carName })
				end
			end
		end
	end

	table.sort(cars, function(a, b) return a.Name < b.Name end)
	return cars
end

function AdminEventService:setEventValues(player: Player, values: any, isGlobal: boolean)
	if not RoleManager.hasPermission(player, "EditGameConfigs") then
		return { Success = false, Error = "Akses ditolak! Anda tidak memiliki izin." }
	end
	if typeof(values) ~= "table" then
		return { Success = false, Error = "Parameter tidak valid!" }
	end

	applyEventValues(values)
	
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

	stopEvents()
	
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
	
	local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
	
	for _, carTemplate in ipairs(CollectionService:GetTagged("CarModel")) do
		if carTemplate:IsDescendantOf(ServerStorage) and (carTemplate:IsA("Tool") or carTemplate:IsA("Model")) then
			local carName = carTemplate.Name
			if not added[carName] then
				added[carName] = true
				
				local rarity = ""
				for rName, list in pairs(GameConfig.CarRarityList) do
					if list[carName] then
						rarity = rName
						break
					end
				end
				if rarity == "" then
					rarity = "Admin"
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

function EventManager.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		commandCooldowns[player.UserId] = nil
	end)

	local subscribeSuccess, subscribeConnection = pcall(function()
		return MessagingService:SubscribeAsync(TOPIC_NAME, onGlobalMessageReceived)
	end)
	if not subscribeSuccess then
		warn("[EventManager] Gagal berlangganan ke MessagingService: " .. tostring(subscribeConnection))
	end

	Networker.server.new("AdminEventService", AdminEventService, {
		AdminEventService.setEventValues,
		AdminEventService.stopAllEvents,
		AdminEventService.broadcastMessage,
		AdminEventService.giftPlayerReward,
		AdminEventService.getAvailableCars,
		AdminEventService.getAdminCars,
	})

	print("[EventManager] ✅ AdminEventService Networker endpoints initialized.")
end

return EventManager

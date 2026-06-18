local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")

local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local DataManager = require(game:GetService("ServerScriptService"):WaitForChild("DataManager"):WaitForChild("DataManager"))
local Networker = require(ReplicatedStorage.Packages.Networker)

local ShopManager = {}
local MAX_DISTANCE = 50

-- ===== LOOP WAKTU BERMAIN (RPM TOKENS ACCUMULATION) =====
local function startPlaytimeLoop(player: Player)
	task.spawn(function()
		while player and player.Parent do
			task.wait(60) -- Tambah 1 Token setiap 1 menit (60 detik)
			
			local leaderstats = player:FindFirstChild("leaderstats")
			local rpmVal = leaderstats and leaderstats:FindFirstChild("RPM Tokens") :: IntValue?
			
			if rpmVal then
				rpmVal.Value = rpmVal.Value + 1
				
				-- Sinkronisasikan secara instan ke profil data cache
				local profile = DataManager.Profiles[player]
				if profile and profile.Data and profile.Data.Stats then
					profile.Data.Stats.RPMTokens = rpmVal.Value
				end
			end
		end
	end)
end

-- ===== PROSES TRANSAKSI ROBOH / ROBUX (DEVELOPER PRODUCTS) =====
local function processReceipt(receiptInfo)
	local playerId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local player = Players:GetPlayerByUserId(playerId)
	
	if not player then
		-- Pemain keluar, coba lagi nanti saat login berikutnya
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	local item = ShopConfig.getItemByProductId(productId)
	if item then
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			local boxTemplate = ServerStorage:FindFirstChild("Box")
			if boxTemplate then
				local newBox = boxTemplate:Clone()
				newBox:SetAttribute("Level", item.Level)
				newBox:SetAttribute("Exp", 0)
				local boxLevels = GameConfig.BoxLevels or {}
				local maxExp = boxLevels[item.Level] and boxLevels[item.Level].MaxExp or 100
				newBox:SetAttribute("MaxExp", maxExp)
				newBox:SetAttribute("Variants", "Normal")
				newBox:SetAttribute("Type", "Box")
				newBox:SetAttribute("Amount", 1)
				newBox.Name = boxLevels[item.Level] and boxLevels[item.Level].Name or "Crate Level " .. tostring(item.Level)
				
				-- Setup visual di client
				CollectionService:AddTag(newBox, "Box")
				newBox.Parent = backpack
				
				print(`[ShopManager] 💳 Pembelian Robux Berhasil: {player.Name} membeli {item.Name}`)
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
	end
	
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ==========================================================
-- METHOD TRANSAKSI BELI BOX VIA RPM TOKENS
-- ==========================================================
function ShopManager:buyBox(player: Player, boxLevel: number)
	if not player or not player.Parent then
		return { Success = false, Error = "Player tidak valid" }
	end
	
	if type(boxLevel) ~= "number" then
		return { Success = false, Error = "Level box tidak valid" }
	end
	
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local backpack = player:FindFirstChild("Backpack")
	
	if not char or not root or not backpack then
		return { Success = false, Error = "Karakter atau tas tidak ditemukan" }
	end
	
	-- ===== 1. VALIDASI LOKASI (ANTI-CHEAT) =====
	local shopArea = GameUtils.getPlayerSellShopArea(player, "ShopArea")
	if not shopArea then
		return { Success = false, Error = "Shop area tidak ditemukan di plot Anda!" }
	end
	
	local jarak = (root.Position - shopArea.Position).Magnitude
	if jarak > MAX_DISTANCE then
		warn(`[ANTI-CHEAT] {player.Name} mencoba membeli Box dari luar area Shop! Jarak: {jarak}m`)
		return { Success = false, Error = "Anda terlalu jauh dari shop area!" }
	end
	
	-- ===== 2. VALIDASI JENIS ITEM TOKO =====
	local item = ShopConfig.getItemByLevel(boxLevel)
	if not item then
		return { Success = false, Error = "Tipe Crate tidak terdaftar di Toko!" }
	end
	
	-- ===== 3. VALIDASI KAPASITAS TAS =====
	local inventoryCount = #backpack:GetChildren()
	local rebirthInvBonus = player:GetAttribute("RebirthInventoryBonus") or 0
	local maxInventorySlots = (GameConfig.MaxInventorySlots or 50) + rebirthInvBonus
	if inventoryCount >= maxInventorySlots then
		return { Success = false, Error = "Tas Anda sudah penuh! (" .. inventoryCount .. "/" .. maxInventorySlots .. " slot)" }
	end
	
	-- ===== 4. VALIDASI SALDO RPM TOKENS =====
	local leaderstats = player:FindFirstChild("leaderstats")
	local rpmVal = leaderstats and leaderstats:FindFirstChild("RPM Tokens") :: IntValue?
	if not rpmVal or rpmVal.Value < item.Cost then
		return {
			Success = false,
			Error = `RPM Tokens tidak mencukupi! ({rpmVal and rpmVal.Value or 0}/{item.Cost} RPM)`,
		}
	end
	
	-- ===== 5. EKSEKUSI TRANSAKSI =====
	-- A. Potong Token
	rpmVal.Value = rpmVal.Value - item.Cost
	local profile = DataManager.Profiles[player]
	if profile and profile.Data and profile.Data.Stats then
		profile.Data.Stats.RPMTokens = rpmVal.Value
	end
	
	-- B. Kloning Box
	local boxTemplate = ServerStorage:FindFirstChild("Box")
	if not boxTemplate then
		return { Success = false, Error = "Aset Box template tidak ditemukan di ServerStorage!" }
	end
	
	local newBox = boxTemplate:Clone()
	newBox:SetAttribute("Level", item.Level)
	newBox:SetAttribute("Exp", 0)
	local boxLevels = GameConfig.BoxLevels or {}
	local maxExp = boxLevels[item.Level] and boxLevels[item.Level].MaxExp or 100
	newBox:SetAttribute("MaxExp", maxExp)
	newBox:SetAttribute("Variants", "Normal")
	newBox:SetAttribute("Type", "Box")
	newBox:SetAttribute("Amount", 1)
	newBox.Name = boxLevels[item.Level] and boxLevels[item.Level].Name or "Crate Level " .. tostring(item.Level)
	
	-- Tag box
	CollectionService:AddTag(newBox, "Box")
	newBox.Parent = backpack
	
	print(`[ShopManager] ⚙️ Pembelian Berhasil: {player.Name} membeli {newBox.Name} seharga {item.Cost} RPM Tokens`)
	return {
		Success = true,
		Message = `Berhasil membeli {item.Name} seharga {item.Cost} RPM!`,
	}
end

-- ==========================================================
-- BOOTSTRAPPER INIT METHOD
-- ==========================================================
function ShopManager.Init()
	print("[ShopManager] Inisialisasi modul Toko & Akumulasi RPM Tokens...")
	
	-- Mulai loop playtime untuk pemain yang sudah ada (pencegahan)
	for _, player in ipairs(Players:GetPlayers()) do
		startPlaytimeLoop(player)
	end
	
	-- Mulai loop playtime untuk pemain baru bergabung
	Players.PlayerAdded:Connect(startPlaytimeLoop)
	
	-- Daftarkan Networker channel "ShopGui"
	Networker.server.new("ShopGui", ShopManager, {
		ShopManager.buyBox,
	})
	
	-- Ikat ProcessReceipt untuk Developer Products Robux
	MarketplaceService.ProcessReceipt = processReceipt
	
	print("[ShopManager] ✅ Modul Toko & RPM Tokens telah aktif!")
end

return ShopManager

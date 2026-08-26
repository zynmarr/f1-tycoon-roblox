local BoxManager = {}

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
-- local NetworkServer = game:GetService("NetworkServer")
-- local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local RoleManager = require(ServerScriptService.RoleManager.RoleManager)
local DataManager = require(ServerScriptService.DataManager.DataManager)

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))
local RoleConfig = require(ReplicatedStorage:WaitForChild("RoleConfig"))
local Networker = require(ReplicatedStorage.Packages.Networker)

local BoxModels = ServerStorage:WaitForChild("BoxModels")

local BOX_TAG = "Box"

-- ========== RATE LIMITING ==========
local BOX_OPEN_COOLDOWN = 3 -- seconds
local playerBoxOpenTimes = {} -- {player: timestamp}

-- type Networker = Networker.Server
-- type

-- ==========================================
-- 0. FUNGSI UPDATE VISUAL (SWAP LEVEL)
-- ==========================================
local function updateBoxVisual(box: Tool)
	if not box then
		return
	end
	local handle = box:FindFirstChild("Handle") :: Part?
	if not handle then
		return
	end

	local currentLevel = box:GetAttribute("Level") or 1
	if currentLevel <= 0 then
		warn(
			`[BoxManager] Level tidak valid (${currentLevel}) pada box ${box.Name}. Pastikan atribut "Level" sudah benar.`
		)
		return
	end

	local targetModelName = "Level" .. tostring(currentLevel)
	local newVisualTemplate = BoxModels:FindFirstChild(targetModelName)

	if not newVisualTemplate then
		warn(`[BoxManager] Model {targetModelName} tidak ditemukan di ReplicatedStorage.BoxModels!`)
		newVisualTemplate = BoxModels:FindFirstChild("Level14")
	end

	-- 1. Hapus visual lama jika ada
	local oldVisual = box:FindFirstChild("Model")
	if oldVisual then
		oldVisual:Destroy()
	end

	-- 2. Clone model baru ke dalam Box
	local visualContainer: Model = newVisualTemplate:Clone() :: Model
	visualContainer.Name = "Model"
	visualContainer.Parent = box

	if box:GetAttribute("Variants") and box:GetAttribute("Variants") ~= "" then
		local currentModel: Model = box:FindFirstChild("Model") :: Model
		local variants = box:GetAttribute("Variants") or "Normal"
		local EffectsFolder = ServerStorage:WaitForChild("VariantEffect")

		local listOfVariants = {}

		--loop string from variants" Like "Normal,Fire,Ice" to table {Normal=true, Fire=true, Ice=true}
		for variant in string.gmatch(variants, "([^,]+)") do
			listOfVariants[variant] = GameConfig.Variants[variant] or true
		end

		for _, part in pairs(currentModel:GetDescendants()) do
			if part:IsA("BasePart") then
				-- Cek apakah part memiliki efek varian yang sesuai dengan atribut Variants
				for name, value in pairs(listOfVariants) do
					if typeof(value) == "table" and value.Effect then
						local effectTemplate: ParticleEmitter =
							EffectsFolder:FindFirstChild(value.Effect) :: ParticleEmitter
						if effectTemplate then
							local newEffect = effectTemplate:Clone()
							newEffect.Parent = part
							if newEffect:IsA("ParticleEmitter") then
								newEffect.Size = NumberSequence.new(1.5, 1.5)
								newEffect.ZOffset = -1.5
								newEffect.Speed = NumberRange.new(0.5, 1)
								newEffect.Enabled = true
							end
						end
					end
				end
			end
		end
	end

	if not visualContainer.PrimaryPart then
		visualContainer.PrimaryPart = visualContainer:FindFirstChildWhichIsA("BasePart", true)
	end

	local primaryPart = visualContainer.PrimaryPart
	if not primaryPart then
		return
	end

	-- 3. Kalkulasi tinggi & posisikan ulang model ke Handle
	local baseOffset = 0.5
	local dynamicY = baseOffset + (handle.Size.Y / 2)
	visualContainer:ScaleTo(handle.Size.X / 3)
	visualContainer:PivotTo(handle.CFrame * CFrame.new(0, -dynamicY + 0.5, 0))

	-- 4. Weld internal model agar part-part kecil menempel kuat
	for _, part in pairs(visualContainer:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Anchored = false
			part.Massless = true

			if part ~= primaryPart then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primaryPart
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end

	-- 5. Main Weld (Model ke Handle utama)
	local mainWeld = Instance.new("WeldConstraint")
	mainWeld.Name = "MainWeld"
	mainWeld.Part0 = handle
	mainWeld.Part1 = primaryPart
	mainWeld.Parent = primaryPart

	handle.Transparency = 1
end

local function updateModelSize(box: Tool, onHand: boolean)
	local handle: BasePart = box:FindFirstChild("Handle") :: BasePart
	local currentModel: Model = box:FindFirstChild("Model") :: Model
	local primaryPart = currentModel and currentModel.PrimaryPart
	local machine = box.Parent :: BasePart?
	local machineArea = machine and machine.Parent :: Folder?

	local level = box:GetAttribute("Level") or 1

	if onHand == false then
		if machineArea and machineArea:GetAttribute("IsRunning") == nil then
			return
		end
		if not currentModel or not primaryPart or not machine then
			return
		end
	end

	local mainWeld: WeldConstraint = primaryPart:FindFirstChild("MainWeld") :: WeldConstraint
	if mainWeld then
		mainWeld:Destroy()
	end

	if level >= 8 then
		currentModel:ScaleTo(handle.Size.X / 3.5)
	else
		currentModel:ScaleTo(handle.Size.X / 2)
	end

	-- local baseOffset = 0.5
	-- local dynamicY = baseOffset + (handle.Size.Y / 2)

	-- Pengaturan CFrame handle ditangani sepenuhnya oleh SpawnerBoxManager (Box Manager)
	-- handle.CFrame = machine.CFrame * CFrame.new(0, dynamicY, 0)
	currentModel:PivotTo(handle.CFrame * CFrame.new(0, -(handle.Size.Y / 2), 0))

	mainWeld = Instance.new("WeldConstraint")
	mainWeld.Name = "MainWeld"
	mainWeld.Part0 = handle
	mainWeld.Part1 = primaryPart
	mainWeld.Parent = primaryPart
end

-- ==========================================
-- 1. FUNGSI PENGAMBILAN (PICKUP)
-- ==========================================
local function processPickup(player: Player, box: Tool)
	if not box or box:GetAttribute("HasPicked") then
		return
	end

	local backpack = player:FindFirstChild("Backpack")
	local existingBox = (backpack and backpack:FindFirstChild(box.Name))
		or (player.Character and player.Character:FindFirstChild(box.Name))

	-- ===== INVENTORY CAPACITY CHECK FOR PICKUP =====
	local inventoryCount = backpack and #backpack:GetChildren() or 0
	local rebirthInvBonus = player:GetAttribute("RebirthInventoryBonus") or 0
	local maxInventorySlots = (GameConfig.MaxInventorySlots or 50) + rebirthInvBonus

	local allowed, errMsg = GameConfig.CanPlayerPickUp(player, box)
	if not allowed then
		local NotifEvent = ReplicatedStorage:FindFirstChild("NotifEvent")
		if NotifEvent then
			NotifEvent:FireClient(
				player,
				"Akses Ditolak",
				errMsg or "Tidak dapat mengambil box ini!",
				3
			)
		end
		return
	end

	if not existingBox and inventoryCount >= maxInventorySlots then
		local NotifEvent = ReplicatedStorage:FindFirstChild("NotifEvent")
		if NotifEvent then
			NotifEvent:FireClient(
				player,
				"Tas Penuh",
				"Tas Anda sudah penuh! (" .. inventoryCount .. "/" .. maxInventorySlots .. " slot)",
				3
			)
		end
		return
	end

	box:SetAttribute("HasPicked", true)

	-- Logika kuota pencurian jika mengambil box orang lain
	local boxOwner = box:GetAttribute("Owner")
	if boxOwner and boxOwner ~= player.Name then
		local pData = DataManager.getPlayerData(player)
		if pData then
			if not pData.DailyStolenBoxes then
				pData.DailyStolenBoxes = { LastResetTime = os.time(), Count = 0 }
			end

			-- Logika Reset Harian GMT
			local now = os.time()
			local lastReset = pData.DailyStolenBoxes.LastResetTime or 0
			local lastDate = os.date("!*t", lastReset)
			local nowDate = os.date("!*t", now)

			local didReset = false
			if lastDate.yday ~= nowDate.yday or lastDate.year ~= nowDate.year then
				pData.DailyStolenBoxes.Count = 0
				pData.DailyStolenBoxes.LastResetTime = now
				didReset = true
			end

			if didReset then
				local NotifEvent = ReplicatedStorage:FindFirstChild("NotifEvent")
				if NotifEvent then
					NotifEvent:FireClient(
						player,
						"Kuota Segar",
						"Batas pencurian box harian Anda telah di-reset (0/3)!",
						3
					)
				end
			end

			if (pData.DailyStolenBoxes.Count or 0) >= 3 then
				local NotifEvent = ReplicatedStorage:FindFirstChild("NotifEvent")
				if NotifEvent then
					NotifEvent:FireClient(
						player,
						"Akses Ditolak",
						"Batas pencurian box harian Anda sudah penuh hari ini (3/3 box)! Silakan coba lagi besok.",
						4
					)
				end
				return
			end

			pData.DailyStolenBoxes.Count = (pData.DailyStolenBoxes.Count or 0) + 1
			DataManager.syncData(player)

			local NotifEvent = ReplicatedStorage:FindFirstChild("NotifEvent")
			if NotifEvent then
				NotifEvent:FireClient(
					player,
					"Box Dicuri!",
					"Anda telah mencuri box milik " .. boxOwner .. " (" .. tostring(pData.DailyStolenBoxes.Count) .. "/5 hari ini)",
					3
				)
			end
		end
	end

	local handle = box:FindFirstChild("Handle") :: Part?
	local prompt = handle and handle:FindFirstChildOfClass("ProximityPrompt")

	if handle then
		handle.Anchored = false
		handle.CanCollide = false
		handle.Massless = true
	end

	if prompt then
		prompt.Enabled = false
	end

	-- 🚀 LOGIKA PENTING: RESET STATUS MESIN AGAR BISA RESPAWN ULANG
	local sourceMachine = box:FindFirstChild("SourceMachine") :: ObjectValue?
	if sourceMachine and sourceMachine.Value then
		local machineArea = sourceMachine.Value
		machineArea:SetAttribute("IsRunning", false)
		print(`[BoxManager] Box diambil! Membuka kunci status IsRunning pada {machineArea.Name}`)
	end

	if existingBox then
		-- Tambah isi tumpukan (Stacking System)
		local stackFolder: Folder = existingBox:FindFirstChild("Stacks") :: Folder
			or Instance.new("Folder", existingBox)
		stackFolder.Name = "Stacks"

		local boxData = Instance.new("Configuration")
		boxData.Name = "BoxData_" .. (#stackFolder:GetChildren() + 1)

		for name, value in pairs(box:GetAttributes()) do
			boxData:SetAttribute(name, value)
		end
		boxData.Parent = stackFolder

		local currentAmount: number = existingBox:GetAttribute("Amount") :: number or 1
		existingBox:SetAttribute("Amount", currentAmount + 1)

		Debris:AddItem(box, 0.1)
	else
		box:SetAttribute("Amount", 1)
		GameConfig.ClearHands(player)
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			box.Parent = player.Character
		else
			box.Parent = backpack
		end
	end
end

-- ==========================================
-- 2. LOGIKA GA_CHA BOX VIA NETWORKER
-- ==========================================
function BoxManager:openBox(player: Player, boxName: string)
	-- ===== RATE LIMITING CHECK =====
	local now = tick()
	local lastOpenTime = playerBoxOpenTimes[player] or 0
	local playerRole = RoleManager.getPlayerRole(player)

	-- Bypass cooldown untuk Owner, Developer, dan Moderator (Staff)
	if playerRole ~= "Owner" and playerRole ~= "Developer" and playerRole ~= "Moderator" then
		if now - lastOpenTime < BOX_OPEN_COOLDOWN then
			return {
				Success = false,
				Error = "Terlalu cepat membuka box! Tunggu "
					.. math.ceil(BOX_OPEN_COOLDOWN - (now - lastOpenTime))
					.. " detik.",
			}
		end
	end
	playerBoxOpenTimes[player] = now

	-- ===== ANTI-CHEAT: Type Validation =====
	if not boxName or type(boxName) ~= "string" then
		return { Success = false, Error = "Parameter tidak valid" }
	end

	-- Ambil lokasi karakter untuk mengecek barang yang sedang dipegang
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")

	-- 1. Cari box yang sedang dipegang (di dalam Character) atau di dalam Backpack
	local boxInHand = character and character:FindFirstChild(boxName) :: Tool?
	local boxInBackpack = backpack and backpack:FindFirstChild(boxName) :: Tool?

	-- Tentukan box mana yang valid digunakan (utamakan yang di tangan)
	local targetBox = boxInHand or boxInBackpack

	-- ===== ANTI-CHEAT: Validasi Type Box =====
	if targetBox and targetBox:GetAttribute("Type") ~= "Box" then
		return {
			Success = false,
			Error = "Item ini bukan kotak yang bisa dibuka!",
		}
	end

	-- Validasi keberadaan box
	if not targetBox or targetBox:GetAttribute("IsDestroying") then
		return {
			Success = false,
			Error = "Kotak tidak sedang dipegang atau tidak ditemukan di dalam tas!",
		}
	end

	-- Pastikan backpack tetap ada untuk menaruh mobil reward nanti
	if not backpack then
		return {
			Success = false,
			Error = "Gagal memproses, data tas (Backpack) tidak ditemukan!",
		}
	end

	-- ===== INVENTORY CAPACITY CHECK =====
	local inventoryCount = #backpack:GetChildren()
	local rebirthInvBonus = player:GetAttribute("RebirthInventoryBonus") or 0
	local maxInventorySlots = (GameConfig.MaxInventorySlots or 50) + rebirthInvBonus
	if inventoryCount >= maxInventorySlots then
		return {
			Success = false,
			Error = "Tas Anda sudah penuh! (" .. inventoryCount .. "/" .. maxInventorySlots .. " slot)",
		}
	end

	local currentLevel = targetBox:GetAttribute("Level") or 1
	local currentAmount: number = targetBox:GetAttribute("Amount") :: number or 1
	local boxBaseLuck = targetBox:GetAttribute("LuckyChance") or 1
	local variants: string = targetBox:GetAttribute("Variants") :: string or "Normal"

	local eventLuckBoost = GameConfig.CheckLuckyChanceBoost() or 0
	local playerLuckUpgrade = player:GetAttribute("Upg_LuckyChance") or 0
	local totalLuck = boxBaseLuck + eventLuckBoost + playerLuckUpgrade

	-- Rebirth: Luck Multiplier
	local DataManager = require(game.ServerScriptService.DataManager.DataManager)
	local playerData = DataManager.getPlayerData(player)
	local luckMulLevel = playerData and playerData.RebirthUpgrades and playerData.RebirthUpgrades.LuckMultiplier or 0
	local luckMulBonus = RebirthConfig.getUpgradeEffect("LuckMultiplier", luckMulLevel)
	totalLuck = totalLuck * (1 + (luckMulBonus / 100))

	-- Roll rarity mobil dari GameConfig
	local tier = GameConfig.RollRarity(totalLuck)
	local tierData = GameConfig.Rarities[tier]

	-- Cari template model mobil via tag CarModel (tidak perlu folder rarity di ServerStorage)
	local carModelTag = "CarModel"
	local carTemplates = CollectionService:GetTagged(carModelTag)

	-- Filter hanya mobil yang sesuai dengan rarity yang di-roll
	local rarityCarNames = GameConfig.CarRarityList[tier]
	if not rarityCarNames or next(rarityCarNames) == nil then
		-- Fallback ke Common jika rarity tidak punya mobil terdaftar
		tier = "Common"
		tierData = GameConfig.Rarities[tier]
		rarityCarNames = GameConfig.CarRarityList[tier]
	end

	-- Kumpulkan template yang namanya ada di CarRarityList tier ini
	local matchingTemplates = {}
	for _, model in pairs(carTemplates) do
		if rarityCarNames[model.Name] then
			table.insert(matchingTemplates, model)
		end
	end

	if #matchingTemplates == 0 then
		warn("[BoxManager] Tidak ada model CarModel ditemukan untuk tier: " .. tier)
		return { Success = false, Error = "Tidak ada mobil tersedia untuk tier " .. tier }
	end

	local chosenCarTemplate = matchingTemplates[math.random(1, #matchingTemplates)]

	-- Clone the Tool "Car" from ServerStorage
	local carToolTemplate = ServerStorage:FindFirstChild("Car")
	if not carToolTemplate then
		warn("[BoxManager] Tool 'Car' tidak ditemukan di ServerStorage!")
		return { Success = false, Error = "Tool 'Car' tidak ditemukan di ServerStorage!" }
	end

	local car = carToolTemplate:Clone()
	local carModel = chosenCarTemplate:Clone()
	carModel.Name = "Model"
	carModel.Parent = car

	CollectionService:AddTag(car, "Car")

	-- Pasang atribut finansial dan visual ke mobil baru
	local baseIncome, sellPrice = GameConfig.CalculatePrice(tierData.BasePrice, tier, variants, chosenCarTemplate.Name)

	car:SetAttribute("Income", baseIncome)
	car:SetAttribute("Price", sellPrice)
	car:SetAttribute("Variant", variants)
	car:SetAttribute("Rarity", tier)
	car:SetAttribute("Name", chosenCarTemplate.Name)
	car:SetAttribute("Type", "Car")
	car:SetAttribute("Owner", player.Name)
	car.Name = chosenCarTemplate.Name .. "_" .. tier .. "_" .. variants

	GameConfig.ApplyVisuals(car, tier, variants)

	-- Serahkan mobil ke inventory backpack/garasi pemain
	GameUtils.addCarToInventory(player, car)

	-- Unlock in Player collection Index
	local pData = DataManager.getPlayerData(player)
	if pData then
		if not pData.CarIndexCollection then
			pData.CarIndexCollection = {}
		end
		
		local indexKey = chosenCarTemplate.Name .. "_" .. tier .. "_" .. variants
		if not pData.CarIndexCollection[indexKey] then
			pData.CarIndexCollection[indexKey] = true
			
			local newMulti = GameConfig.CalculateCollectionMultiplier(pData)
			player:SetAttribute("CollectionMultiplier", newMulti)

			local NotifEvent = ReplicatedStorage:FindFirstChild("NotifEvent")
			if NotifEvent then
				NotifEvent:FireClient(
					player,
					"Index Baru Dibuka!",
					`Koleksi {chosenCarTemplate.Name} ({tier}) dibuka! Multiplier Anda sekarang: {string.format("%.1f", (newMulti - 1.0) * 100)}%!`,
					4
				)
			end
		end
	end

	-- 🟥 KONSUMSI ITEM: Update stack box atau hapus kotak jika habis
	local stackFolder = targetBox:FindFirstChild("Stacks")
	if stackFolder and #stackFolder:GetChildren() > 0 then
		local allStacks = stackFolder:GetChildren()
		local nextBoxData = allStacks[1]

		-- Ambil data dari box cadangan berikutnya di bawahnya
		targetBox:SetAttribute("Level", nextBoxData:GetAttribute("Level"))
		targetBox:SetAttribute("Exp", nextBoxData:GetAttribute("Exp"))
		targetBox:SetAttribute("Variants", nextBoxData:GetAttribute("Variants"))
		targetBox:SetAttribute("Amount", currentAmount - 1)

		nextBoxData:Destroy()
	else
		targetBox:SetAttribute("IsDestroying", true)
		targetBox.Parent = nil
		Debris:AddItem(targetBox, 0.1)
	end

	local RebirthManager = require(game.ServerScriptService.RebirthManager.RebirthManager)
	RebirthManager.incrementQuestProgress(player, "OpenBoxes", 1)

	-- ===== CHAT ANNOUNCEMENT FOR EPIC+ CARS =====
	local announcementTiers = { "Epic", "Legendary", "Mythic", "God", "Celestial", "Admin" }
	if table.find(announcementTiers, tier) then
		task.spawn(function()
			local roleName = RoleManager.getPlayerRole(player)
			local roleData = RoleConfig.Roles[roleName]
			local roleColorHex = roleData and roleData.Color:ToHex() or "AFAFAF"
			local roleEmoji = roleData and roleData.Emoji or ""
			local roleDisplayName = roleData and roleData.DisplayName or "Player"

			-- Dapatkan nama box dasar secara rapi dari level box
			local boxLevelConfig = GameConfig.BoxLevels[currentLevel]
			local boxDisplayName = boxLevelConfig and boxLevelConfig.Name or targetBox.Name

			-- Dapatkan nama mobil dasar (tanpa varian)
			local carDisplayName = chosenCarTemplate.Name
			local rarityColor = tierData.Color or Color3.fromRGB(255, 255, 255)
			local rarityColorHex = rarityColor:ToHex()

			-- Bangun teks dengan format rich text
			local prefixText = ""
			if roleName ~= "Player" and roleData then
				prefixText = string.format(
					"<font color='#%s'><b>[%s %s]</b></font> ",
					roleColorHex,
					roleEmoji,
					string.upper(roleDisplayName)
				)
			end

			local playerText = string.format("<font color='#%s'><b>%s</b></font>", roleColorHex, player.Name)
			local messageBody =
				string.format(": telah mendapatkan mobil <b>%s</b> dari <b>%s</b>", carDisplayName, boxDisplayName)
			local richText =
				string.format("%s%s<font color='#%s'>%s</font>", prefixText, playerText, rarityColorHex, messageBody)

			print(
				"[BoxManager] Menyiarkan pengumuman gacha mobil Epic+: "
					.. player.Name
					.. " mendapatkan "
					.. carDisplayName
			)

			-- Siarkan ke Client untuk ditampilkan di Chat UI
			local chatAnnounceEventOptional = ReplicatedStorage:FindFirstChild("ChatAnnounceEvent") :: RemoteEvent?
			local chatAnnounceEvent: RemoteEvent
			if not chatAnnounceEventOptional then
				local newEvent = Instance.new("RemoteEvent")
				newEvent.Name = "ChatAnnounceEvent"
				newEvent.Parent = ReplicatedStorage
				chatAnnounceEvent = newEvent
			else
				chatAnnounceEvent = chatAnnounceEventOptional :: RemoteEvent
			end
			chatAnnounceEvent:FireAllClients(richText, rarityColor)
		end)
	end

	return {
		Success = true,
		Error = "",
		RewardName = car.Name,
		Message = `Berhasil membuka {boxName}! Mendapatkan mobil: {car.Name} ({tier})`,
	}
end

-- ==========================================
-- 3. SETUP INITIAL LISTENERS
-- ==========================================
local function setupBox(box: Tool)
	if not box then
		return
	end
	local handle: BasePart = box:FindFirstChild("Handle") :: BasePart
	local prompt = handle and handle:FindFirstChildOfClass("ProximityPrompt")

	-- Store connections for cleanup
	local connections = {}

	updateBoxVisual(box)

	box.Equipped:Connect(function()
		local character = box.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		--if not box:GetAttribute("HasPicked") then
		--	processPickup(player)
		--end
		handle.Size = Vector3.new(2, 2, 2)
		updateModelSize(box, true)

		local boxSize = handle.Size or Vector3.new(2, 2, 2)
		box.Grip = CFrame.new(0, 0, boxSize.Z / 2)
	end)

	box.Unequipped:Connect(function()
		-- Handled client side
	end)

	table.insert(
		connections,
		box:GetAttributeChangedSignal("Level"):Connect(function()
			updateBoxVisual(box)
		end)
	)

	if prompt then
		table.insert(
			connections,
			prompt.Triggered:Connect(function(player)
				processPickup(player, box)
			end)
		)
	end

	-- Pengecekan posisi box (OnHand / In Tas)
	table.insert(
		connections,
		box.AncestryChanged:Connect(function(_, parent)
			if not parent then
				return
			end
			if parent:IsA("Backpack") then
				box:SetAttribute("OnHand", false)
			elseif parent:IsA("Model") and parent:FindFirstChild("Humanoid") then
				box:SetAttribute("OnHand", true)
			end
		end)
	)

	-- Event Scaling Dinamis saat box ditaruh di conveyor/mesin jualan
	if handle then
		table.insert(
			connections,
			handle:GetPropertyChangedSignal("Size"):Connect(function()
				updateModelSize(box, false)
			end)
		)
	end

	-- Cleanup all connections when box is destroyed
	local cleanupConnection
	cleanupConnection = box.AncestryChanged:Connect(function(_, parent)
		if not parent then
			for _, conn in ipairs(connections) do
				pcall(function()
					conn:Disconnect()
				end)
			end
			if cleanupConnection then
				cleanupConnection:Disconnect()
			end
		end
	end)
	table.insert(connections, cleanupConnection)
end

function BoxManager.giveBoxToPlayer(
	player: Player,
	level: number,
	variants: string?,
	customLuckyChance: number?,
	ownerName: string?
)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return false
	end

	local boxTemplate = ServerStorage:FindFirstChild("Box")
	if not boxTemplate then
		warn("[BoxManager] Box template tidak ditemukan di ServerStorage!")
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
	local maxExp = initialLvlData and initialLvlData.MaxExp or 100
	local boxName = initialLvlData and initialLvlData.Name or "Crate Level " .. tostring(level)

	local variantStr = variants or "Normal"

	newBox:SetAttribute("Level", level)
	newBox:SetAttribute("Exp", 0)
	newBox:SetAttribute("MaxExp", maxExp)
	newBox:SetAttribute("Variants", variantStr)
	newBox:SetAttribute("Type", "Box")
	newBox:SetAttribute("Amount", 1)
	newBox:SetAttribute("HasPicked", true)
	newBox:SetAttribute("Name", boxName)

	if ownerName then
		newBox:SetAttribute("Owner", ownerName)
	end

	if customLuckyChance then
		newBox:SetAttribute("LuckyChance", customLuckyChance)
	else
		-- Default lucky chance dari level box
		newBox:SetAttribute("LuckyChance", initialLvlData and initialLvlData.LuckMulti or 1.0)
	end

	-- Tentukan nama tool berdasarkan variant
	if variantStr == "Normal" then
		newBox.Name = boxName
	else
		newBox.Name = boxName .. "_Variant_" .. string.gsub(variantStr, ",", "_")
	end

	newBox.Handle.Size = Vector3.new(2, 2, 2)

	-- Aktifkan StatsDisplay jika ada
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

	-- Update Text visual box awal
	local boxModule = newBox:FindFirstChild("BoxModule")
	if boxModule then
		local BoxModuleRequire = require(boxModule)
		BoxModuleRequire.UpdateBoxText(newBox.Handle, level, 0, maxExp, variantStr)
	end

	-- Setup visual di client via tag
	CollectionService:AddTag(newBox, "Box")

	-- LOGIKA STACKING (PENUMPUKAN)
	local existingBox = backpack:FindFirstChild(newBox.Name)
		or (player.Character and player.Character:FindFirstChild(newBox.Name))

	if existingBox then
		local stackFolder = existingBox:FindFirstChild("Stacks")
		if not stackFolder then
			stackFolder = Instance.new("Folder")
			stackFolder.Name = "Stacks"
			stackFolder.Parent = existingBox
		end

		local boxData = Instance.new("Configuration")
		boxData.Name = "BoxData_" .. (#stackFolder:GetChildren() + 1)
		for name, value in pairs(newBox:GetAttributes()) do
			boxData:SetAttribute(name, value)
		end
		boxData.Parent = stackFolder

		local currentAmount = existingBox:GetAttribute("Amount") or 1
		existingBox:SetAttribute("Amount", currentAmount + 1)

		newBox:Destroy()
		print(`[BoxManager] 📦 Stacked {existingBox.Name} untuk {player.Name}. Jumlah baru: {currentAmount + 1}`)
	else
		newBox.Parent = backpack
		print(`[BoxManager] 📦 Memberikan {newBox.Name} baru ke {player.Name}`)
	end

	return true
end

function BoxManager:printTest(player: Player, text: string)
	print(`[Server Test] {tostring(text)} is called in event by {player.Name}`)
end

-- ==========================================
-- 4. BOOTSTRAPPER INIT METHOD
-- ==========================================

function BoxManager.Init()
	print("[BoxManager] Mengaktifkan kernel sistem Box modern terpusat.")

	-- Copy BoxModels to ReplicatedStorage so client ShopGui/ViewportManager can access it
	local sourceBoxModels = ServerStorage:FindFirstChild("BoxModels")
	if sourceBoxModels and not ReplicatedStorage:FindFirstChild("BoxModels") then
		local cloned = sourceBoxModels:Clone()
		cloned.Parent = ReplicatedStorage
		print("[BoxManager] BoxModels replicated to ReplicatedStorage for client use")
	end

	-- Cleanup rate limiting when player leaves
	local Players = game:GetService("Players")
	Players.PlayerRemoving:Connect(function(player)
		playerBoxOpenTimes[player] = nil
	end)

	Networker.server.new("OpenBox", BoxManager, {
		BoxManager.openBox,
	})

	print("[BoxManager] ✅ Networker 'OpenBox' endpoint siap mendengarkan dari client")

	-- Dengarkan aset lama yang sudah ada di Workspace
	for _, tool in pairs(CollectionService:GetTagged(BOX_TAG)) do
		if tool:IsA("Tool") then
			task.spawn(setupBox, tool)
		end
	end

	-- Dengarkan aset box baru yang muncul dinamis secara runtime
	CollectionService:GetInstanceAddedSignal(BOX_TAG):Connect(function(instance)
		if instance:IsA("Tool") then
			task.spawn(setupBox, instance)
		end
	end)
end

return BoxManager

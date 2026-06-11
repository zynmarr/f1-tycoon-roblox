--local ReplicatedStorage = game:GetService("ReplicatedStorage")
--local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

--local toggleEvent = ReplicatedStorage:WaitForChild("ToggleItemEvent")
--local setCapacityEvent = ReplicatedStorage:WaitForChild("SetHotbarCapacity")
--local moveItemEvent = ReplicatedStorage:WaitForChild("MoveItemEvent")

---- =======================================
---- 1. SETUP FOLDER INVENTORY
---- =======================================
--game.Players.PlayerAdded:Connect(function(player)
--	local inv = Instance.new("Folder")
--	inv.Name = "ItemInventory"
--	inv.Parent = player

--	local hotbar = Instance.new("Folder", inv)
--	hotbar.Name = "Hotbar"

--	local bag = Instance.new("Folder", inv)
--	bag.Name = "Bag"

--	local capacity = Instance.new("IntValue", inv)
--	capacity.Name = "HotbarCapacity"
--	capacity.Value = 4 

--	-- Anti-Item Hilang saat mati
--	player.CharacterRemoving:Connect(function(char)
--		local invFolder = player:FindFirstChild("ItemInventory")
--		local savedBag = invFolder and invFolder:FindFirstChild("Bag")

--		if savedBag then
--			for _, obj in pairs(char:GetChildren()) do
--				if obj:GetAttribute("ItemName") then
--					GameConfig.StoreItem(obj, savedBag)
--					obj:SetAttribute("LastLocation", "Bag")
--				end
--			end
--		end
--	end)
--end)

--setCapacityEvent.OnServerEvent:Connect(function(player, maxSlots)
--	local inv = player:FindFirstChild("ItemInventory")
--	if inv and inv:FindFirstChild("HotbarCapacity") then
--		inv.HotbarCapacity.Value = maxSlots 
--	end
--end)

---- =======================================
---- 2. LOGIKA EQUIP / UN-EQUIP (SANGAT BERSIH SEKARANG)
---- =======================================
--toggleEvent.OnServerEvent:Connect(function(player, itemPilihan)
--	local char = player.Character
--	local invFolder = player:FindFirstChild("ItemInventory")
--	if not char or not invFolder or not itemPilihan then return end

--	local hotbar = invFolder:FindFirstChild("Hotbar")
--	local bag = invFolder:FindFirstChild("Bag")
--	local capacity = invFolder:FindFirstChild("HotbarCapacity")

--	-- Cari item yang sedang dipegang
--	local itemDiTangan = nil
--	for _, obj in pairs(char:GetChildren()) do
--		if obj:GetAttribute("ItemName") then
--			itemDiTangan = obj
--			break
--		end
--	end

--	-- Helper buat tentuin folder balikan
--	local function tentukanFolder(item)
--		local lastLocation = item:GetAttribute("LastLocation")
--		if lastLocation == "Hotbar" or #hotbar:GetChildren() < capacity.Value then
--			item:SetAttribute("LastLocation", "Hotbar")
--			return hotbar
--		else
--			item:SetAttribute("LastLocation", "Bag")
--			return bag
--		end
--	end

--	-- JIKA KLIK BARANG YANG SAMA DI TANGAN -> MASUKIN KE TAS
--	if itemDiTangan == itemPilihan then
--		GameConfig.StoreItem(itemPilihan, tentukanFolder(itemPilihan))
--		return
--	end

--	-- JIKA LAGI PEGANG BARANG LAIN -> MASUKIN DULU BARANG LAMA KE TAS
--	if itemDiTangan then
--		GameConfig.StoreItem(itemDiTangan, tentukanFolder(itemDiTangan))
--	end

--	-- PEGANG BARANG BARU (Panggil GameConfig)
--	GameConfig.HoldItem(char, itemPilihan)
--end)

---- =======================================
---- 3. LOGIKA DRAG & DROP (PINDAH FOLDER)
---- =======================================
--moveItemEvent.OnServerEvent:Connect(function(player, item, targetFolderName)
--	local invFolder = player:FindFirstChild("ItemInventory")
--	if not invFolder or not item then return end

--	local hotbar = invFolder:FindFirstChild("Hotbar")
--	local bag = invFolder:FindFirstChild("Bag")
--	local capacity = invFolder:FindFirstChild("HotbarCapacity")

--	if targetFolderName == "Hotbar" then
--		if #hotbar:GetChildren() < capacity.Value then
--			item.Parent = hotbar
--			item:SetAttribute("LastLocation", "Hotbar")
--		else
--			-- Swap ke item terakhir di hotbar kalau kepenuhan
--			local items = hotbar:GetChildren()
--			local lastItem = items[#items]
--			if lastItem then 
--				lastItem.Parent = bag 
--				lastItem:SetAttribute("LastLocation", "Bag")
--			end
--			item.Parent = hotbar
--			item:SetAttribute("LastLocation", "Hotbar")
--		end
--	elseif targetFolderName == "Bag" then
--		item.Parent = bag
--		item:SetAttribute("LastLocation", "Bag")
--	end
--end)
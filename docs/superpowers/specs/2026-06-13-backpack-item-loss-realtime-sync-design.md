# Design Spec: Preventing Backpack Item Loss via Real-time Sync & Protection

**Date:** 2026-06-13
**Status:** Approved by User
**Problem Statement:** The asynchronous nature of player leaves and stops in Roblox Studio can lead to race conditions where the player's `Backpack` or `Character` is cleared by the engine before `Players.PlayerRemoving` runs its sync code. This causes `syncData` to scan an empty inventory and overwrite the database profile with empty data.

---

## 1. Architecture & Data Flow

To ensure maximum safety and zero data loss, we implement a hybrid system:
1. **Real-time Event-Driven Synchronization**: Listen to `ChildAdded` and `ChildRemoved` events on the player's `Backpack` and `Character`. Any inventory changes (pickup, equip, unequip, open, park, sell) update the database profile in memory immediately.
2. **Character-to-Backpack Safety Reparenting**: When `CharacterRemoving` fires, we programmatically move the equipped `Tool` from the `Character` model to the `Backpack` model to prevent it from being destroyed in hand.
3. **Leaving Protection Flag (`IsLeaving`)**: When `Players.PlayerRemoving` is triggered, we set the attribute `IsLeaving = true` on the player. When this flag is active, `syncData` skips scanning the physical instances (which may already be cleared) and instead preserves the last known valid inventory saved in memory.

---

## 2. Component Design & Changes

### 2.1. `src/ServerScriptService/DataManager/DataManager.luau`

We modify [DataManager.syncData](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/DataManager/DataManager.luau#L190) to check for `IsLeaving` and skip physical inventory scanning if the player is leaving:

```lua
	-- 2. Scan Seluruh Item di Backpack & Karakter (Hanya jika pemain tidak sedang keluar)
	if not player:GetAttribute("IsLeaving") then
		local function scanTools(folder: Instance?, locationName: string)
			if not folder then
				return
			end
			for _, item in pairs(folder:GetChildren()) do
				if item:IsA("Tool") then
					pcall(function()
						local itemRecord = {
							Name = item.Name,
							Location = locationName,
							Attributes = extractAttributes(item),
							Stacks = {},
						}
						local stacksFolder = item:FindFirstChild("Stacks")
						if stacksFolder then
							for _, stackConfig in pairs(stacksFolder:GetChildren()) do
								if stackConfig:IsA("Configuration") then
									table.insert(itemRecord.Stacks, extractAttributes(stackConfig))
								end
							end
						end
						table.insert(finalSave.Inventory, itemRecord)
					end)
				end
			end
		end

		scanTools(player:FindFirstChild("Backpack"), "Backpack")
		if player.Character then
			scanTools(player.Character, "Character")
		end
	else
		-- Jika sedang keluar, pertahankan inventory yang sudah ada sebelumnya
		finalSave.Inventory = profile.Data.Inventory or {}
	end
```

### 2.2. `src/ServerScriptService/Main.server.luau`

We modify the [onPlayerAdded](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/Main.server.luau#L157) and `onPlayerRemoving` functions:

1. **Reparent Tool & Real-time Sync in `onPlayerAdded`:**
   ```lua
	-- Memuat Karakter dan Spawn
	player.CharacterAdded:Connect(function(character)
		PlotManager.teleportToPlot(player, character)
	end)

	player.CharacterRemoving:Connect(function(character)
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			for _, child in pairs(character:GetChildren()) do
				if child:IsA("Tool") then
					pcall(function()
						child.Parent = backpack
					end)
				end
			end
		end
	end)

	-- Tracker perubahan inventori real-time (dengan debounce per frame)
	local function connectInventoryTracker(character)
		local backpack = player:WaitForChild("Backpack", 5)
		local syncPending = false

		local function sync()
			if syncPending then return end
			syncPending = true
			task.defer(function()
				syncPending = false
				if player.Parent and not player:GetAttribute("IsLeaving") then
					pcall(DataManager.syncData, player)
				end
			end)
		end

		if backpack then
			backpack.ChildAdded:Connect(sync)
			backpack.ChildRemoved:Connect(sync)
		end
		if character then
			character.ChildAdded:Connect(sync)
			character.ChildRemoved:Connect(sync)
		end
	end

	player.CharacterAdded:Connect(connectInventoryTracker)
	if player.Character then
		task.spawn(connectInventoryTracker, player.Character)
	end
   ```

2. **Flag `IsLeaving` in `onPlayerRemoving`:**
   ```lua
   local function onPlayerRemoving(player: Player)
       player:SetAttribute("IsLeaving", true)
       print(`[MainServer] Pemain keluar: {player.Name}. Menyimpan data...`)
       DataManager.saveData(player)
       PlotManager.releasePlot(player)
   end
   ```

---

## 3. Testing & Validation

1. **Equipped Item Save Test:**
   * Enter the game, equip a Box/item.
   * Press **Stop** in Roblox Studio.
   * Re-enter the game and verify that the item is successfully saved.

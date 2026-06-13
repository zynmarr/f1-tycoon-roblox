# Design Spec: Preventing Backpack Item Loss on Player Leave or Reset

**Date:** 2026-06-13
**Status:** Approved by User
**Problem Statement:** Items equipped by players (which reside inside the player's `Character` model rather than the `Backpack`) are lost when the player leaves the game, resets, or when the game is stopped in Roblox Studio. This happens because Roblox destroys the player's Character model before the `Players.PlayerRemoving` event listener executes, making the equipped items undetectable during final data sync.

---

## 1. Architecture & Data Flow

### The Problematic Flow
```
[Player Leaves / Stop Game] 
       │
       ▼
[Roblox destroys Character]  ──► Equipped items inside Character are destroyed!
       │
       ▼
[PlayerRemoving event fires]
       │
       ▼
[DataManager.saveData()]
       │
       ▼
[DataManager.syncData()]     ──► Scans Backpack (empty/missing the equipped item)
                                 Scans Character (nil/already destroyed)
                                 Result: Equipped item is NOT saved.
```

### The New Flow (Reparenting on CharacterRemoving)
```
[Player Leaves / Stop Game]
       │
       ▼
[CharacterRemoving event fires] ──► Move equipped tools from Character to Backpack
       │
       ▼
[Roblox destroys Character]
       │
       ▼
[PlayerRemoving event fires]
       │
       ▼
[DataManager.saveData()]        ──► Scans Backpack (which now contains the previously equipped item!)
                                    Saves complete inventory list.
                                    Releases profile to save to DataStore.
```

---

## 2. Component Design & Changes

### 2.1. `src/ServerScriptService/Main.server.luau`

We modify the [onPlayerAdded](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/Main.server.luau#L157) function to connect to the `CharacterRemoving` event. Whenever a player's character is being removed, we scan the character model for any equipped `Tool` instances and parent them back to the player's `Backpack`:

```lua
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
```

This ensures that the equipped item is safely tucked away in the `Backpack` before the Character is completely destroyed. Since `DataManager.syncData` scans the `Backpack` during normal saving/autosaving processes, this completely solves the equipped tool loss bug.

---

## 3. Testing & Validation

1. **Equipped Item Save Test:**
   * Enter the game.
   * Obtain a Box/item.
   * Hold the item in hand (equip it).
   * Press **Stop** in Roblox Studio or leave the server.
   * Re-enter the game and verify that the item is still in your Backpack.

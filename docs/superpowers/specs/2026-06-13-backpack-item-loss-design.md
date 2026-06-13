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

### The New Flow
```
[Player Leaves / Reset Character / Stop Game]
       │
       ▼
[CharacterRemoving event fires] (Character and its equipped tools still exist in memory)
       │
       ▼
[DataManager.syncData(player, character)] ──► Scans Backpack & the removing Character
                                              Updates Profile.Data in-memory
       │
       ▼
[Roblox destroys Character]
       │
       ▼
[PlayerRemoving event fires]
       │
       ▼
[DataManager.saveData()] ──► Profile.Data is already up-to-date!
                             Calls profile:Release() to save securely to DataStore.
```

---

## 2. Component Design & Changes

### 2.1. `src/ServerScriptService/DataManager/DataManager.luau`

We will modify [DataManager.syncData](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/DataManager/DataManager.luau#L162) to accept an optional `character` argument:

```lua
-- Modified syncData signature to accept character parameter
function DataManager.syncData(player, character)
```

Within the function, the character scanning step will fall back to `player.Character` only if the `character` argument is not supplied:

```lua
	scanTools(player:FindFirstChild("Backpack"), "Backpack")
	local char = character or player.Character
	if char then
		scanTools(char, "Character")
	end
```

### 2.2. `src/ServerScriptService/Main.server.luau`

We will modify the [onPlayerAdded](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/Main.server.luau#L157) function to connect to the `CharacterRemoving` event:

```lua
	-- Sync equipped tools before character is destroyed
	player.CharacterRemoving:Connect(function(character)
		pcall(function()
			DataManager.syncData(player, character)
		end)
	end)
```

---

## 3. Testing & Validation

1. **Equipped Item Save Test:**
   * Enter the game.
   * Obtain a Box/item.
   * Hold the item in hand (equip it).
   * Press **Stop** in Roblox Studio or leave the server.
   * Re-enter the game and verify that the item is still in your Backpack.

2. **Reset/Respawn Test:**
   * Hold an item.
   * Reset character (die).
   * Verify that the item remains in the Backpack after respawning.

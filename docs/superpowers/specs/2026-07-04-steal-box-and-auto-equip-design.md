# Design Spec: Steal Box Gamepass & Dynamic Auto-Equip

**Date**: 2026-07-04  
**Topic**: Implement Steal Box Gamepass and Auto-Equip Tools (ClearHands)

---

## 1. Problem Statement

We want to implement the following features:
1. **Ownership Validation & Stealing**:
   - By default, players should only be able to pick up items (boxes or cars) that belong to them (i.e. `Owner == player.Name`).
   - If a player purchases the **"Steal Box Pass"** (Gamepass ID `1819444793`), they can steal other players' spawned boxes (not cars) up to 5 times per day.
   - Steal stats must be persistent and reset daily (GMT).
2. **Auto-Equipping Tools**:
   - When a player picks up a box or car, instead of placing it into the Backpack by default, it should be equipped directly into their hand (`Character`).
   - Any currently held item should be automatically returned to the Backpack.

---

## 2. Proposed Changes

### A. Database Scheme (`DataManager.luau`)
Add the following tracker field to `DEFAULT_DATA`:
```lua
DailyStolenBoxes = {
    LastResetTime = 0,
    Count = 0,
}
```

### B. Gamepass Registration (`ShopConfig.luau`)
Add the new Gamepass to `ShopConfig.Gamepasses`:
```lua
{
    ID = 1819444793,
    Name = "Steal Box Pass",
    CostRobux = 150,
    Description = "Memungkinkan Anda mencuri hingga 5 box dari plot pemain lain setiap harinya (mobil tidak bisa dicuri).",
    Icon = "rbxassetid://15682855591",
}
```

### C. GameConfig Updates (`GameConfig.luau`)
Modify `GameConfig.CanPlayerPickUp` and `GameConfig.ClearHands` to implement the safety checks and tool unequipping.

### D. Spawner and Owner Integrations
Piping `Owner` attribute initialization across all spawner modules:
1. `BoxManager.luau` (unboxing)
2. `EventManager.luau` (admin gifting)
3. `CarManager.luau` (plot load spawning)
4. `TradeSession.luau` (updating owner on trade completion)

---

## 3. Detailed Interface & API Changes

### `GameConfig.CanPlayerPickUp`
```lua
function GameConfig.CanPlayerPickUp(player: Player, item: Instance): (boolean, string?)
	local itemOwner = item:GetAttribute("Owner")
	local itemType = item:GetAttribute("Type")

	if not itemOwner or itemOwner == "" then
		return true
	end
	if itemOwner == player.Name then
		return true
	end

	if itemType == "Car" then
		return false, "Anda tidak dapat mengambil mobil milik pemain lain!"
	elseif itemType == "Box" then
		local MarketplaceService = game:GetService("MarketplaceService")
		local hasGamepass = false
		local success, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, 1819444793)
		end)
		if success then
			hasGamepass = result
		end

		if not hasGamepass then
			return false, "Anda membutuhkan Gamepass 'Steal Box' untuk mengambil box pemain lain!"
		end

		local DataManager = require(game:GetService("ServerScriptService"):WaitForChild("DataManager"):WaitForChild("DataManager"))
		local pData = DataManager.getPlayerData(player)
		if not pData then
			return false, "Gagal memuat data pemain. Silakan coba lagi nanti."
		end

		if not pData.DailyStolenBoxes then
			pData.DailyStolenBoxes = { LastResetTime = os.time(), Count = 0 }
		end

		local now = os.time()
		local lastReset = pData.DailyStolenBoxes.LastResetTime or 0
		local lastDate = os.date("!*t", lastReset)
		local nowDate = os.date("!*t", now)

		if lastDate.yday ~= nowDate.yday or lastDate.year ~= nowDate.year then
			pData.DailyStolenBoxes.Count = 0
			pData.DailyStolenBoxes.LastResetTime = now
		end

		if (pData.DailyStolenBoxes.Count or 0) >= 5 then
			return false, "Batas pencurian box harian Anda sudah penuh hari ini (5/5)!"
		end

		return true
	end

	return false, "Aksi tidak diizinkan."
end
```

### `GameConfig.ClearHands`
```lua
function GameConfig.ClearHands(player: Player)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid:UnequipTools()
end
```

---

## 4. Test Plan
1. **Purchase Pass**: Verify that buying/owning gamepass `1819444793` permits picking up another player's Box, while not owning it warns the player and blocks the pickup.
2. **Steal Cap**: Steal 5 boxes and verify that the 6th theft attempt is blocked with a limit notification.
3. **Car Steal Block**: Ensure cars spawned on other players' plots/parking lots cannot be stolen even with the pass.
4. **Auto-Equip Swapping**: Verify that when picking up any Box or Car, the player equips it immediately, and their old tool is returned to their Backpack/Hotbar.

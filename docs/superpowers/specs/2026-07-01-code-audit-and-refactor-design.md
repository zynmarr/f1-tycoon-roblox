# Design Spec: F1-Tycoon Code Audit & Refactoring

**Date**: 2026-07-01  
**Topic**: Code Review, Performance, Security, and Clean/DRY Refactoring

---

## 1. Problem Statement

A comprehensive review of the F1-Tycoon codebase identified several areas where security, performance, and code duplication can be optimized:
1. **Security & Fault Tolerance**:
   - `game:BindToClose` blocks server shutdown until all profiles are released. If a DataStore call fails and hangs, the server is locked in an infinite wait.
   - The anti-cheat distance check in `ShopManager:buyBox` is set to 50 studs, which is excessively loose for shop transactions.
2. **Performance & Memory Leaks**:
   - The playtime loop in `ShopManager.luau` waits for 60 seconds inside a while loop. If a player leaves during this wait, the thread remains active for up to 60 seconds before terminating.
   - Periodic autosaving processes all players in the server at the exact same frame, which can cause CPU frame spikes when multiple players are present.
3. **Code Duplication (DRY Violation)**:
   - Identical logic to add and stack cars in the player's backpack is written in `BoxManager.luau`, `EventManager.luau`, and `TradeSession.luau`.
   - `ViewportManager.formatPrice` duplicates currency formatting code from `GameUtils.formatCompact`.

---

## 2. Proposed Changes

### A. Centralized Car Inventory Management (`GameUtils.luau`)
Introduce a helper function `GameUtils.addCarToInventory(player: Player, car: Tool)` inside `GameUtils.luau` that handles:
- Checking if the car already exists in the player's backpack.
- Creating the `Stacks` folder if missing.
- Instantiating a `Configuration` stack object and copying attributes.
- Incrementing the `"Amount"` attribute.
- Destroying the cloned tool if stacked, or parenting it to the backpack.

We will replace duplicate stacking blocks in `BoxManager.luau`, `EventManager.luau`, and `TradeSession.luau` with calls to this centralized function.

### B. Security & Validation Tweaks
1. **Shop Distance Check**: Lower `MAX_DISTANCE` in `ShopManager.luau` from `50` to `20` studs to restrict remote exploit purchases.
2. **BindToClose Safety Timeout**: Set a maximum fallback timeout of 5 seconds in `Main.server.luau`'s `BindToClose` listener. If profiles aren't released in 5 seconds, the shutdown finishes to avoid server hangs.

### C. Performance & Memory Management
1. **Playtime Loop Early Termination**: In `ShopManager.luau`, verify player active status immediately after `task.wait(60)` inside the loop, allowing rapid thread cancellation when players leave.
2. **Autosave Staggering**: In `Main.server.luau`, introduce a `task.wait(0.5)` delay between saving each player during the periodic autosave loop.

---

## 3. Detailed Interface & API Changes

### `GameUtils.luau`
```lua
-- Centralized helper to safely add a car tool to a player's inventory
function GameUtils.addCarToInventory(player: Player, car: Tool)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		car:Destroy()
		return
	end

	local existingCar = backpack:FindFirstChild(car.Name)
	if existingCar then
		local stackFolder = existingCar:FindFirstChild("Stacks")
		if not stackFolder then
			stackFolder = Instance.new("Folder")
			stackFolder.Name = "Stacks"
			stackFolder.Parent = existingCar
		end

		local carData = Instance.new("Configuration")
		carData.Name = "CarData_" .. (#stackFolder:GetChildren() + 1)
		for name, value in pairs(car:GetAttributes()) do
			carData:SetAttribute(name, value)
		end
		carData.Parent = stackFolder

		local carAmount = existingCar:GetAttribute("Amount") or 1
		existingCar:SetAttribute("Amount", (carAmount :: number) + 1)
		car:Destroy()
	else
		car:SetAttribute("Amount", 1)
		car.Parent = backpack
	end
end
```

---

## 4. Test Plan

### Automated Verification
Run `rojo build` to verify there are no compilation or Rojo setup errors.

### Manual Verification
1. **Gacha Box Opening**: Open boxes and verify cars are successfully added to the backpack and stack correctly (increasing Amount and adding items under `Stacks`).
2. **Admin Gift Command**: Run the gift car command from the admin panel and ensure it stacks/adds correctly.
3. **Trading**: Complete a trade between two players and verify the offered cars are transferred and saved/stacked correctly.
4. **Shutdown Logs**: Close the server and verify the shutdown logs do not hang and cleanly release profiles.

# Implementation Plan: Steal Box Gamepass & Dynamic Auto-Equip

This plan outlines the steps to implement the Steal Box Gamepass, daily limits, and auto-equipping tools.

---

## Phase 1: Database Setup and Registry

### Step 1.1: Add Skema Data to `DataManager.luau`
- Open [DataManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/DataManager/DataManager.luau).
- Locate `DEFAULT_DATA` table.
- Insert `DailyStolenBoxes = { LastResetTime = 0, Count = 0 }`.

### Step 1.2: Register Gamepass in `ShopConfig.luau`
- Open [ShopConfig.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ReplicatedStorage/ShopConfig.luau).
- Locate `ShopConfig.Gamepasses` array.
- Add Steal Box Pass metadata (ID `1819444793`).

---

## Phase 2: GameConfig Logic Implementation

### Step 2.1: Implement `CanPlayerPickUp` and `ClearHands` in `GameConfig.luau`
- Open [GameConfig.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ReplicatedStorage/GameConfig.luau).
- Rewrite `CanPlayerPickUp` and `ClearHands` using the specifications in the design document.

---

## Phase 3: Spawner & Box Pickup Integrations

### Step 3.1: Initialize `Owner` Attribute for Cars
- In [BoxManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/BoxManager/BoxManager.luau)'s `openBox`, assign `car:SetAttribute("Owner", player.Name)`.
- In [EventManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/EventManager/EventManager.luau)'s `giftCarToPlayer`, assign `car:SetAttribute("Owner", player.Name)`.
- In [CarManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/CarManager/CarManager.luau)'s `spawnLoadedCar`, assign `carTool:SetAttribute("Owner", player.Name)`.
- In [TradeSession.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/TradeManager/TradeSession.luau)'s `addCarToBackpack` function, assign `car:SetAttribute("Owner", player.Name)`.

### Step 3.2: Update Box Pickup Logic
- In [BoxManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/BoxManager/BoxManager.luau)'s `processPickup` function:
  - Add `GameConfig.CanPlayerPickUp` check.
  - Increment stolen counts for other players' boxes and trigger server sync.
  - Implement `GameConfig.ClearHands` and equip the box to `player.Character` instead of parenting it to Backpack.

### Step 3.3: Update Car Parking Pickup Logic
- In [ParkingAreaManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/ParkingAreaManager/ParkingAreaManager.luau)'s `processPickup` function:
  - Add `GameConfig.CanPlayerPickUp` check.
  - Implement `GameConfig.ClearHands` and equip the car tool to `character` instead of Backpack.

---

## Verification
- Run `rojo build` to verify compilation.
- Commit all code to git repository.

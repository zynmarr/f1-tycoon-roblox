# Implementation Plan: F1-Tycoon Code Audit & Refactoring

This plan outlines the step-by-step implementation of security, performance, and code quality improvements approved in the design specification.

---

## Phase 1: GameUtils Refactoring (DRY Integration)

### Step 1.1: Add `addCarToInventory` to `GameUtils.luau`
- Open [GameUtils.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ReplicatedStorage/GameUtils.luau) and append the helper function `addCarToInventory` at the bottom before `return GameUtils`.
- Ensure it handles the stacking logic, including configurations under `Stacks`, attribute copying, and parenting.

### Step 1.2: Integrate in `BoxManager.luau`
- Open [BoxManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/BoxManager/BoxManager.luau).
- Locate the duplicate stacking block in `openBox` (around lines 390-410).
- Replace with `GameUtils.addCarToInventory(player, car)`.

### Step 1.3: Integrate in `EventManager.luau`
- Open [EventManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/EventManager/EventManager.luau).
- Locate the duplicate stacking block in `giftCarToPlayer` (around lines 260-280).
- Replace with `GameUtils.addCarToInventory(player, car)`.

### Step 1.4: Integrate in `TradeSession.luau`
- Open [TradeSession.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/TradeManager/TradeSession.luau).
- Locate the duplicate stacking block in `addCarToBackpack` (around lines 125-144).
- Replace with `GameUtils.addCarToInventory(player, car)`.

---

## Phase 2: Performance Optimizations

### Step 2.1: Optimize Playtime Loop
- Open [ShopManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/ShopManager/ShopManager.luau).
- Modify the `startPlaytimeLoop` while loop so it terminates immediately if the player is nil/destroyed right after `task.wait(60)`.

### Step 2.2: Stagger Autosaving Loop
- Open [Main.server.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/Main.server.luau).
- Locate the periodic autosave loop (around lines 405-418).
- Introduce a staggered delay `task.wait(0.5)` between each player's save call to prevent frame spikes.

---

## Phase 3: Security & Stability Improvements

### Step 3.1: Enforce Closer Shop Distance Check
- Open [ShopManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/ShopManager/ShopManager.luau).
- Change `MAX_DISTANCE` constant from `50` to `20` studs to enforce strict distance checking.

### Step 3.2: Implement BindToClose Timeout Safeguard
- Open [Main.server.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/Main.server.luau).
- Locate `game:BindToClose` (around lines 420-433).
- Wrap the release check loop in a safety timeout of 5 seconds to ensure the server never hangs indefinitely if profile release crashes.

---

## Verification & Deployment
- Run `rojo build` to verify syntax.
- Manually test:
  1. Gacha opening
  2. Trading
  3. Gifting cars
  4. Server shutdown logs

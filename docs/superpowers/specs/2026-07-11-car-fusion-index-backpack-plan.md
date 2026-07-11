# Implementation Plan: F1-Tycoon Car Fusion, Car Index, and Categorized Backpack

This plan outlines the steps to build the Fusion system, Collection Index, and Backpack filters.

---

## Phase 1: Database Setup and Registry

### Step 1.1: Add Skema Data to `DataManager.luau`
- Open [DataManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/DataManager/DataManager.luau).
- Insert `CarIndexCollection = {}` into `DEFAULT_DATA`.

### Step 1.2: Register Gamepass & Fusion Constants in `GameConfig.luau`
- Open [GameConfig.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ReplicatedStorage/GameConfig.luau).
- Define `GameConfig.RarityFusionRates` and `GameConfig.CalculateCollectionMultiplier` functions.

---

## Phase 2: R&D Fusion System (Server Logic)

### Step 2.1: Create `FusionManager.luau`
- Create `src/ServerScriptService/FusionManager/FusionManager.luau`.
- Implement `FusionService:fuseCars(player, carFullName)` with:
  - Material validation (requires >= 3 cars).
  - Double roll (Perfect Fusion 15% vs Base Chance).
  - Failure handler: destroy 2, keep 1.
  - Success handler: spawn next tier car, register to Index, trigger data sync.

### Step 2.2: Bootstrap in `Main.server.luau`
- Open [Main.server.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/Main.server.luau).
- Initialize `FusionManager` in the server startup phase.

---

## Phase 3: Collection Multiplier Integration

### Step 3.1: Apply Index Multiplier in Income Loop
- Open [ParkingAreaManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/ParkingAreaManager/ParkingAreaManager.luau).
- Update the cash multiplier calculation to include the index collection multiplier.

### Step 3.2: Record Unlocks on Obtain
- Auto-unlock entries in player collection when cars are unboxed (`BoxManager`), gifted (`EventManager`), or traded (`TradeSession`).

---

## Phase 4: UI Updates (Backpack & Index Catalogue)

### Step 4.1: Category Tabs in `InventoryModal.luau`
- Open [InventoryModal.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/StarterPlayer/StarterPlayerScripts/components/MainHUD/InventoryModal.luau).
- Add `selectedTab` state and filter elements by type.
- Add tabs layout container.

### Step 4.2: Create Index Catalogue UI
- Create `IndexModal.luau` catalog viewer display.

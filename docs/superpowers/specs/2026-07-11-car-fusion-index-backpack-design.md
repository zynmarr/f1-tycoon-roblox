# Design Spec: F1-Tycoon Car Fusion, Car Index, and Categorized Backpack

**Date**: 2026-07-11  
**Topic**: Implement R&D Car Fusion System, Car Collection Index (Catalog), and Categorized Backpack UI.

---

## 1. Problem Statement

We want to introduce three major features to drive player progression, collection, and inventory convenience:
1. **R&D Car Fusion**: Allow players to fuse 3 identical cars of Rarity X to obtain 1 car of Rarity X+1. This serves as a key item sink.
   - Compound chance: Roll 1 has a 15% chance to hit a "Perfect Fusion" (100% success). If Roll 1 fails, Roll 2 checks base success rate (90% for Common down to 25% for God).
   - Friendlier Failure: On failure, consume 2 duplicates and refund/keep 1 baseline car.
   - Out of Bounds Upgrade Fallback: If a team has no car in the next rarity tier (e.g. Haas has no Rare car), grant a random car from that next rarity pool.
2. **Car Collection Index**: A collection catalogue (book) tracking unique unlocked cars.
   - Standard rarity unlocks grant **+0.2% permanent Cash Multiplier**.
   - Special variant unlocks (Golden, Rainbow, etc.) grant **+1.0% permanent Cash Multiplier**.
   - Stats are persistent and calculate in the passive income loop.
3. **Categorized Backpack**: Tab filters inside `InventoryModal` to swap between All, Cars, and Boxes.

---

## 2. Proposed Changes

### A. Database Additions (`DataManager.luau`)
Add the catalog data list to `DEFAULT_DATA`:
```lua
CarIndexCollection = {
    -- Format: ["CarName_Rarity_Variant"] = true
}
```

### B. GameConfig Updates (`GameConfig.luau`)
Introduce:
1. `GameConfig.RarityFusionRates` dictionary mapped by rarity names.
2. `GameConfig.CalculateCollectionMultiplier(playerData)` to dynamically calculate the cash multiplier.

### C. Fusion Manager Service (`FusionManager.luau`)
Create a new server module `src/ServerScriptService/FusionManager/FusionManager.luau` handling:
- `FusionService:fuseCars(player, carFullName)`

### D. UI Integrations
1. **Backpack Filtering**: Modify `InventoryModal.luau` to render a 3-tab bar ([All], [Cars], [Boxes]) and filter list based on type.
2. **Index Menu**: Create `IndexModal.luau` catalogue display.

---

## 3. Test Plan
1. **Fusion Rate Test**: Perform fusions and verify base success rates, perfect fusions, and item consumption/refunding.
2. **Multipliers**: Unlock new index entries and verify that the permanent passive income multiplier increments.
3. **Backpack Tabs**: Switch tabs in Backpack and verify item listings update correctly.

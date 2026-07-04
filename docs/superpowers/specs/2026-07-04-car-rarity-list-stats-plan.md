# Implementation Plan: CarRarityList Stat Binding

This plan outlines the steps to implement static income & price bindings from GameConfig.CarRarityList.

---

## Phase 1: GameConfig Updates

### Step 1.1: Modify `CalculatePrice` in `GameConfig.luau`
- Open [GameConfig.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ReplicatedStorage/GameConfig.luau).
- Locate `CalculatePrice` function.
- Update its signature and implementation to check `GameConfig.CarRarityList[rName][carName]` for static `price` and `income` values.

---

## Phase 2: Spawner Integration

### Step 2.1: Integrate in `BoxManager.luau`
- Open [BoxManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/BoxManager/BoxManager.luau).
- Locate the `CalculatePrice` call inside `openBox`.
- Pass `chosenCarTemplate.Name` as the 4th parameter.

### Step 2.2: Integrate in `EventManager.luau`
- Open [EventManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/EventManager/EventManager.luau).
- Locate the `CalculatePrice` call inside `giftCarToPlayer`.
- Pass `foundTemplate.Name` as the 4th parameter.

### Step 2.3: Integrate in `TradeSession.luau`
- Open [TradeSession.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/TradeManager/TradeSession.luau).
- Locate the `CalculatePrice` call inside `addCarToBackpack`.
- Pass `carBaseName` as the 4th parameter.

### Step 2.4: Integrate in `ParkingAreaManager.luau`
- Open [ParkingAreaManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/ParkingAreaManager/ParkingAreaManager.luau).
- Locate the `CalculatePrice` call inside `getOrCalculateCarIncome`.
- Pass `car:GetAttribute("Name") or car.Name` as the 4th parameter.

---

## Verification
- Run `rojo build` to verify compilation.
- Commit all code to git repository.

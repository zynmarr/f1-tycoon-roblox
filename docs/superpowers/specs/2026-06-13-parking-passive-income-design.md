# Design Spec: Parking Passive Income & Parking Improvements

**Date:** 2026-06-13
**Status:** Approved by User
**Problem Statement:** In F1-Tycoon, F1 vehicles are configured with an `Income` attribute, and players can park their vehicles in the plot's parking lots. However, this `Income` attribute is currently unused, meaning parked cars act solely as visual decorations. We want to implement a highly performant, event-driven passive income system that awards Cash to players every second for each car parked on their plot, with VIP/Staff multiplier support.

---

## 1. Architecture & State Management

To avoid performance overhead, we will use an **Event-driven Cache Tracking** architecture. Instead of scanning the physical Workspace every second, the server will keep track of each active player's total passive income in an in-memory cache.

### Data Flow
```
[Car Parked]   ──► Add car's Income to playerPassiveIncome[player]
[Car Picked]   ──► Subtract car's Income from playerPassiveIncome[player]
[Player Leave] ──► Clear playerPassiveIncome[player]
```

### 1-Second Passive Income Loop
A central background thread running every 1 second will iterate over the `playerPassiveIncome` table and grant cash to players:

$$\text{Added Cash} = \lfloor \text{Total Income} \times \text{VIP/Staff Multiplier} \rfloor$$

---

## 2. Component Design & Changes

### 2.1. `src/ServerScriptService/ParkingAreaManager/ParkingAreaManager.luau`

We will implement the following changes in the [ParkingAreaManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/ParkingAreaManager/ParkingAreaManager.luau) module:

1. **State Cache & Imports:**
   ```lua
   local Players = game:GetService("Players")
   local RoleManager = require(game.ServerScriptService.RoleManager.RoleManager)

   local playerPassiveIncome = {} -- [Player] = number (total income/sec)
   ```

2. **Hooking into `storeCarToArea`:**
   At the end of [storeCarToArea](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/ParkingAreaManager/ParkingAreaManager.luau#L26), add:
   ```lua
   local carIncome = tool:GetAttribute("Income") or 0
   playerPassiveIncome[player] = (playerPassiveIncome[player] or 0) + carIncome
   ```

3. **Hooking into `processPickup`:**
   At the end of [processPickup](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/ParkingAreaManager/ParkingAreaManager.luau#L9), add:
   ```lua
   local carIncome = car:GetAttribute("Income") or 0
   playerPassiveIncome[player] = math.max(0, (playerPassiveIncome[player] or 0) - carIncome)
   ```

4. **1-Second Server Loop & Player Cleanup:**
   Inside `ParkingAreaManager:Init()`, add the player removing listener and the loop:
   ```lua
   -- Cleanup on leave
   Players.PlayerRemoving:Connect(function(player)
       playerPassiveIncome[player] = nil
   end)

   -- Passive Income Loop
   task.spawn(function()
       while true do
           task.wait(1)
           for player, totalIncome in pairs(playerPassiveIncome) do
               if player and player.Parent and totalIncome > 0 then
                   local leaderstats = player:FindFirstChild("leaderstats")
                   local cash = leaderstats and leaderstats:FindFirstChild("Cash")
                   if cash then
                       -- Calculate VIP/Staff Multiplier
                       local multiplier = 1.0
                       local roleInfo = RoleManager.getRole(player)
                       if roleInfo and (roleInfo.Name == "VIP" or roleInfo.Name == "Staff" or roleInfo.Name == "Moderator" or roleInfo.Name == "Developer" or roleInfo.Name == "Owner") then
                           multiplier = 1.2
                       end
                       
                       local addedCash = math.floor(totalIncome * multiplier)
                       cash.Value = cash.Value + addedCash
                   end
               end
           end
       end
   end)
   ```

---

## 3. Testing & Verification

1. **Park Car Test:** Park an F1 car in the parking lot and verify that Cash increases every second.
2. **VIP Multiplier Test:** Assign a VIP role to the player and ensure that the income per second receives a +20% bonus.
3. **Pickup Car Test:** Pick up the parked car and check that passive income decreases correctly.
4. **Rejoin Test:** Park a car, leave, rejoin, and confirm that the spawned car starts generating passive income immediately.

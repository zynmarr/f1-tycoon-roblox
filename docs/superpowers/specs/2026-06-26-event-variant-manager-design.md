# Spec Design: Event Variant Manager

## 1. Problem Statement & Goals
Currently, variant boxes and variant cars are obtained based on fixed base rarity chances and static upgrades purchased by the player. To make the unboxing gameplay more dynamic and engaging:
* We want to implement an **Event Variant Manager** system.
* The system will run **individual per-player event loops** that cycle between **Active Boost Events** (5 minutes of +25% boost to a random variant) and **Rest States** (random 3-5 minutes of no boost).
* The event loops are stateless (no save/load data needed, timers start fresh when joining and are destroyed upon leaving).
* The active event must be displayed via a 3D **BillboardGui** floating high above the player's plot (visible from a distance but only visible to the owner of the plot).
* The active event must also dynamically update the client's React HUD under the **Custom Stats** panel, displaying the active boost percentage and matching variant icon.

---

## 2. System Architecture & Data Flow

We will follow a clean **Server-Replicated State & Client-Side Rendering** architecture (Approach 1):

```
[Player Joins] ──► Start Loop (Server) ──► Set Attributes on Player Instance
                                                       │
         ┌─────────────────────────────────────────────┴─────────────────────────────────────────────┐
         ▼                                                                                           ▼
[Gacha Logic] (SpawnerBoxManager)                                                         [Client Renderer] (EventVariantClient)
Reads player attributes and applies                                                       Listens to attribute changes,
+25% chance to the active variant                                                          renders BillboardGui locally above plot
                                                                                           and updates CustomStats React HUD
```

### A. Server-Side: Player Event Loop (`EventVariantManager.luau`)
Located under `src/ServerScriptService/eventvariantmanager/EventVariantManager.luau`.
* When a player joins (`Players.PlayerAdded`), the server starts an asynchronous event loop for that player.
* **Initial State Roll**:
  * **30% Chance**: Start in the **Active** state immediately.
  * **70% Chance**: Start in the **Rest** state.
* **State Transition Loop**:
  * **Active State**:
    * Duration: Exactly 5 minutes (300 seconds).
    * Randomly select a variant from the 5 supported variants: `Rainy`, `Shiny`, `Golden`, `Rainbow`, `Frostbite`.
    * Apply +25% boost.
    * Replicate to player attributes.
    * Wait 300 seconds (or until player leaves).
  * **Rest State**:
    * Duration: Randomly chosen between 3 and 5 minutes (180 to 300 seconds).
    * Pre-select the next variant for display.
    * Apply 0% boost.
    * Replicate to player attributes.
    * Wait chosen seconds (or until player leaves).
* **State Replication via Player Attributes**:
  * `ActiveEventVariant` (string): Active variant name (e.g. `"Golden"`, or `"None"` during rest).
  * `ActiveEventBoost` (number): Active boost percentage (e.g. `25`, or `0` during rest).
  * `EventStatus` (string): Current state (`"Active"` or `"Rest"`).
  * `EventEndTime` (number): The timestamp when the current state ends, calculated using `workspace:GetServerTimeNow() + duration`.
  * `EventNextVariant` (string): The variant scheduled to run after the current state ends (e.g., `"Rainbow"`).
* **Cleanup on Leave**:
  * When a player leaves (`Players.PlayerRemoving`), the player's event loop automatically terminates.

### B. Server-Side: Gacha Chance Modification (`SpawnerBoxManager.luau`)
In `src/ServerScriptService/SpawnerBoxManager/SpawnerBoxManager.luau`:
* During `spawnBox` gacha calculation, look up the `player` attributes:
  ```luau
  local activeVariant = player:GetAttribute("ActiveEventVariant")
  local activeBoost = player:GetAttribute("ActiveEventBoost") or 0
  if activeVariant == vName then
      totalChance = totalChance + activeBoost
  end
  ```

### C. Client-Side: Local BillboardGui Rendering (`EventVariantClient.luau`)
Located under `src/StarterPlayer/StarterPlayerScripts/EventVariantClient.luau` (loaded as part of the client initialization).
* Runs locally for each client.
* Monitors attributes of the `LocalPlayer`: `ActiveEventVariant`, `EventStatus`, `EventEndTime`, `EventNextVariant`.
* Obtains the local player's plot via `GameUtils.getPlayerPlot(LocalPlayer)`.
* Places a transparent pivot part at the center of the local plot, floating approximately 25 studs above the plot.
* Clones/Creates a `BillboardGui` attached to this pivot part:
  * Since it is created locally, it is **only visible to the local player** on their own plot.
  * `MaxDistance` set to `150` studs, and `AlwaysOnTop = false` to allow distance viewing while maintaining occlusion behind physical buildings.
* **UI Layout**:
  * **Header/Title**:
    * Active: `🌈 RAINBOW EVENT!` or `👑 GOLDEN EVENT!` in large colored fonts.
    * Rest: `💤 RESTING` and small `(Next: Frostbite ❄️)`.
  * **Progress Bar**:
    * Sleek horizontal bar displaying elapsed/remaining time.
    * Filled width is updated on every render frame (`RunService.RenderStepped`) by comparing `workspace:GetServerTimeNow()` to `EventEndTime`.
    * Filled color matches the variant theme (e.g. gold for Golden, ice-blue for Frostbite, rainbow gradient for Rainbow) or neutral grey/green for Rest.
    * Text overlay shows time remaining (e.g. `04:12`).

### D. Client-Side: HUD Custom Stats (`CustomStats.luau`)
In `src/StarterPlayer/StarterPlayerScripts/components/MainHUD/CustomStats.luau`:
* Update the React state hook or read the player attributes directly to render a new row in the stats list when `EventStatus == "Active"`:
  * **Varian Icons**:
    * `Rainy` -> 🌧️
    * `Shiny` -> ✨
    * `Golden` -> 🪙
    * `Rainbow` -> 🌈
    * `Frostbite` -> ❄️
  * **Stat Card Details**:
    * Name: `Event [VariantName] Boost`
    * Value: `+25%`
    * Description: `Increases the chance of unboxing [VariantName] boxes from spawners.`
  * When `EventStatus == "Rest"`, this stat card is automatically hidden.

---

## 3. Configuration & Data Schemas

### A. Supported Variant Mapping
* `Rainy` (🌧️, Neon Blue, base multiplier 2.0x)
* `Shiny` (✨, Neon White, base multiplier 2.0x)
* `Golden` (🪙, Golden, base multiplier 5.0x)
* `Rainbow` (🌈, Rainbow, base multiplier 10.0x)
* `Frostbite` (❄️, Light Blue, base multiplier 12.0x)

---

## 4. Test & Validation Plan

### A. Server Lifecycle Test
1. **Join State Randomization**:
   * Join a server 10 times. Verify that some entries begin in `Rest` status and some in `Active` status with a random variant chosen.
2. **Timer Continuity**:
   * Verify that timers run exactly 5 minutes for Active state, and random 3-5 minutes for Rest state.
3. **Leave Termination**:
   * Verify that leaving the game terminates the thread and frees player attributes without leaking threads.

### B. Gacha Calculation Test
1. **Variant Chance Injection**:
   * Enable `Golden` event on a player. Spawner boxes grown during this event must have +25% added to their `Golden` variant chance.

### C. Client UI & HUD Test
1. **Local Visibility**:
   * Join with two players. Verify that Player 1 only sees Player 1's billboard above Plot 1, and Player 2 only sees Player 2's billboard above Player 2's plot.
2. **Progress Bar Updates**:
   * Confirm the progress bar shrinks smoothly and turns green/grey during rest, and matches variant colors during active events.
3. **HUD Reaction**:
   * Confirm the custom stats panel adds and removes the boost modifier card when transitions occur.

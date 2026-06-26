# Spec Design: Event Variant Manager

## 1. Problem Statement & Goals
Currently, variant boxes and variant cars are obtained based on fixed base rarity chances and static upgrades purchased by the player. To make the unboxing gameplay more dynamic and engaging:
* We want to implement an **Event Variant Manager** system.
* The system will run **individual per-player event loops** that cycle between **Active Boost Events** (5 minutes of +25% boost to a random variant) and **Rest States** (random 3-5 minutes of no boost).
* The event loops are stateless (no save/load data needed, timers start fresh when joining and are destroyed upon leaving).
* The active event must be displayed via a 3D **BillboardGui** floating high above the player's plot (visible from a distance but only visible to the owner of the plot).
* The active event must also dynamically update the client's React HUD under the **Custom Stats** panel, displaying the active boost percentage and matching variant icon.
* **Text in GUI/HUD** must be written in **English**.
* **Visual Effects**:
  * When an event is active, apply a localized sky effect matching the variant from `ReplicatedStorage.eventassets`.
  * The `Rainy` event is unique and will spawn a specific `Rain` tool from `ReplicatedStorage.eventassets` onto the client's local plot baseplate, aligning the X and Z coordinates with the plot center while preserving the template's Y coordinate.
* **Decoupled Configuration**:
  * All event settings (variant names, icons, colors, boost amounts, and the names/types of visual assets to clone) will be stored in a central config module `EventVariantConfig.luau` under `ReplicatedStorage`. This allows the user to easily change asset names or configurations without editing the core code.

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
+25% chance to the active variant                                                          reads config from EventVariantConfig,
                                                                                           renders BillboardGui locally above plot,
                                                                                           updates CustomStats React HUD,
                                                                                           and applies local sky/rain effects
```

### A. Configuration Module (`EventVariantConfig.luau`)
Located under `src/ReplicatedStorage/EventVariantConfig.luau`.
This module returns a configuration table, easily editable by the user:
```luau
local EventVariantConfig = {
	Variants = {
		Rainy = {
			DisplayName = "Rainy",
			Icon = "🌧️",
			Color = Color3.fromRGB(0, 157, 255),
			Boost = 25,
			AssetName = "Rain",
			AssetType = "Rain", -- "Rain" spawns on the plot baseplate
		},
		Shiny = {
			DisplayName = "Shiny",
			Icon = "✨",
			Color = Color3.fromRGB(255, 255, 255),
			Boost = 25,
			AssetName = "ShinySky",
			AssetType = "Sky",  -- "Sky" spawns in game.Lighting
		},
		Golden = {
			DisplayName = "Golden",
			Icon = "🪙",
			Color = Color3.fromRGB(255, 215, 0),
			Boost = 25,
			AssetName = "GoldenSky",
			AssetType = "Sky",
		},
		Rainbow = {
			DisplayName = "Rainbow",
			Icon = "🌈",
			Color = Color3.fromRGB(255, 100, 255),
			Boost = 25,
			AssetName = "RainbowSky",
			AssetType = "Sky",
		},
		Frostbite = {
			DisplayName = "Frostbite",
			Icon = "❄️",
			Color = Color3.fromRGB(150, 220, 255),
			Boost = 25,
			AssetName = "FrostbiteSky",
			AssetType = "Sky",
		},
	},
	Chances = {
		Rest = 70,    -- 70% chance to start in Rest state on join
		Active = 30,  -- 30% chance to start in Active state on join
	},
	Durations = {
		Active = 300,        -- 5 minutes in seconds
		RestMin = 180,       -- 3 minutes in seconds
		RestMax = 300,       -- 5 minutes in seconds
	}
}

return EventVariantConfig
```

### B. Server-Side: Player Event Loop (`EventVariantManager.luau`)
Located under `src/ServerScriptService/eventvariantmanager/EventVariantManager.luau`.
* When a player joins (`Players.PlayerAdded`), the server starts an asynchronous event loop for that player.
* **Initial State Roll**:
  * **30% Chance**: Start in the **Active** state immediately.
  * **70% Chance**: Start in the **Rest** state.
* **State Transition Loop** (using values from `EventVariantConfig`):
  * **Active State**:
    * Duration: `EventVariantConfig.Durations.Active` (300 seconds).
    * Randomly select a variant from the 5 supported variants: `Rainy`, `Shiny`, `Golden`, `Rainbow`, `Frostbite`.
    * Apply boost value defined in `EventVariantConfig`.
    * Replicate to player attributes.
    * Wait 300 seconds (or until player leaves).
  * **Rest State**:
    * Duration: Randomly chosen between `EventVariantConfig.Durations.RestMin` (180s) and `EventVariantConfig.Durations.RestMax` (300s).
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

### C. Server-Side: Gacha Chance Modification (`SpawnerBoxManager.luau`)
In `src/ServerScriptService/SpawnerBoxManager/SpawnerBoxManager.luau`:
* During `spawnBox` gacha calculation, look up the `player` attributes:
  ```luau
  local activeVariant = player:GetAttribute("ActiveEventVariant")
  local activeBoost = player:GetAttribute("ActiveEventBoost") or 0
  if activeVariant == vName then
      totalChance = totalChance + activeBoost
  end
  ```

### D. Client-Side: Local BillboardGui & Visual Effects (`EventVariantClient.luau`)
Located under `src/StarterPlayer/StarterPlayerScripts/EventVariantClient.luau` (loaded as part of the client initialization).
* Runs locally for each client.
* Monitors attributes of the `LocalPlayer`: `ActiveEventVariant`, `EventStatus`, `EventEndTime`, `EventNextVariant`.
* Obtains the local player's plot via `GameUtils.getPlayerPlot(LocalPlayer)`.
* Places a transparent pivot part at the center of the local plot, floating approximately 25 studs above the plot.
* Clones/Creates a `BillboardGui` attached to this pivot part:
  * Since it is created locally, it is **only visible to the local player** on their own plot.
  * `MaxDistance` set to `200` studs, and `AlwaysOnTop = false` to allow distance viewing while maintaining occlusion behind physical buildings.
* **UI Layout (English text)**:
  * **Header/Title**:
    * Active: `🌈 RAINBOW EVENT!` or `👑 GOLDEN EVENT!` (reads config display names/icons).
    * Rest: `💤 RESTING` and small `(Next: Frostbite ❄️)`.
  * **Progress Bar**:
    * Sleek horizontal bar displaying elapsed/remaining time.
    * Filled width is updated on every render frame (`RunService.RenderStepped`) by comparing `workspace:GetServerTimeNow()` to `EventEndTime`.
    * Filled color matches the variant theme (reads `Color` from `EventVariantConfig`) or neutral grey/green for Rest.
    * Text overlay shows time remaining (e.g. `04:12`).
* **Visual Effects Rendering (Local to client only)**:
  * **Clean Up previous effects**: Whenever the state changes, destroy any active local Sky or local Rain tools.
  * **Sky Effects**:
    * If an event is active and the config lists `AssetType = "Sky"`, search for `ReplicatedStorage.eventassets[AssetName]`.
    * If found (e.g., a `Sky` object), clone it and parent it to `game.Lighting`.
  * **Rainy Event**:
    * If the active variant config lists `AssetType = "Rain"`, search for a `Tool` matching `AssetName` (default: `"Rain"`) in `ReplicatedStorage.eventassets`.
    * If found, clone the tool and parent it to the plot's baseplate (`plot:FindFirstChild("baseplate")` or `plot:FindFirstChild("Baseplate")` or fallback to `plot`).
    * Align position: Keep the original Y coordinate of the template `Rain` tool, but update its X and Z coordinates to match the center pivot of the player's plot.
    ```luau
    local plotCFrame = plot:GetPivot()
    local originalPivot = rainTemplate:GetPivot()
    local targetPivot = CFrame.new(plotCFrame.Position.X, originalPivot.Position.Y, plotCFrame.Position.Z) * originalPivot.Rotation
    clonedRain:PivotTo(targetPivot)
    ```

### E. Client-Side: HUD Custom Stats (`CustomStats.luau`)
In `src/StarterPlayer/StarterPlayerScripts/components/MainHUD/CustomStats.luau`:
* Update the React state hook or read the player attributes directly to render a new row in the stats list when `EventStatus == "Active"`:
  * Reads details directly from `EventVariantConfig.Variants[activeVariantName]`:
    * Icon: `config.Icon`
    * Name: `Event [DisplayName] Boost` (e.g. `Event Golden Boost`)
    * Value: `+[Boost]%` (e.g. `+25%`)
    * Description: `Increases the chance of unboxing [DisplayName] boxes from spawners.`
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
   * Join with two players. Verify that Player 1 only sees Player 1's billboard and local sky/rain effects, and Player 2 only sees Player 2's billboard and local sky/rain effects.
2. **Progress Bar Updates**:
   * Confirm the progress bar shrinks smoothly and turns green/grey during rest, and matches variant colors during active events.
3. **HUD Reaction**:
   * Confirm the custom stats panel adds and removes the boost modifier card when transitions occur.

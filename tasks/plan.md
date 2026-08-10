# Implementation Plan: Shared Track, Team Manager & Global F1 Trade Market

## Overview
Implementation plan for major gameplay extensions:
1. **Shared Community Race Track (Feature 2)** - *Completed*
2. **F1 Team Manager & Automated Race Day (Feature 3)** - *Completed*
3. **Global F1 Trade Market & Auction House (Feature 4)**: Centralized auction & buyout market allowing players to list, bid on, and trade cars with safe server validation and transaction fees.

---

## Architecture Decisions
- **Market Manager Engine**: Build `MarketManager.luau` in `ServerScriptService` to handle auction listing lifecycle, active bidding timers, and item/cash transfers.
- **Data Persistence**: Use `MemoryStoreService` / DataStore structures for global listing propagation across servers.
- **UI Component**: Build `TradeMarketModal.luau` inside `StarterPlayerScripts/components/MainHUD/` with search, filter, and bid controls.

---

## Task List

### Phase 1: Shared Community Race Track (Feature 2) - [COMPLETED]
- [x] **Task 1**: Update vehicle driving physics and speed scaling (`GameConfig.luau` & `ParkingAreaManager.luau`).
- [x] **Task 2**: Implement track zone boundary validation (`RaceManager.luau`).
- [x] **Task 3**: Add track UI HUD overlay for lap timing and active speed indicator (`TrackHUD.luau`).

### Phase 2: F1 Team Manager & Automated Championship (Feature 3) - [COMPLETED]
- [x] **Task 4**: Add Team Manager data schema (`DEFAULT_DATA.TeamManager` in `DataManager.luau`).
- [x] **Task 5**: Build Team Principal UI (`TeamManagerModal.luau`) for selecting 2 main drivers/cars.
- [x] **Task 6**: Implement 5-minute automated server race loop (`RaceManager.luau`).
- [x] **Task 7**: Add Pit Stop quick-time minigame (`PitStopMinigame.luau`) to grant pit strategy buffs.

### Phase 3: Global F1 Trade Market & Auction House (Feature 4)
- [ ] **Task 8**: Build `MarketManager.luau` backend engine (listing, bidding, buyout, 5% fee & item transfer logic).
- [ ] **Task 9**: Create `TradeMarketModal.luau` UI for browsing active listings, placing bids, and buyout purchases.
- [ ] **Task 10**: Add "List on Market" action button to `InventoryModal.luau` for owned cars.

### Checkpoint 3: Complete Feature Suite
- [ ] Market listings persist and process buyout/bidding transactions cleanly.
- [ ] All unit and build tests pass via `rojo build`.

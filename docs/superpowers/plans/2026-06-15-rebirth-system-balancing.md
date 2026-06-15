# Implementation Plan: Rebirth System Balancing Update

Dokumen ini adalah rencana implementasi untuk memperbarui sistem Rebirth dan Toko Upgrade Rebirth berdasarkan spesifikasi desain di `docs/superpowers/specs/2026-06-15-rebirth-system-balancing-design.md`.

---

## Task 1: Buat `RebirthConfig.luau` — Tabel Konfigurasi Terpusat
**File:** `src/ReplicatedStorage/RebirthConfig.luau` (baru)

Buat modul baru berisi semua data konfigurasi rebirth agar tidak tersebar di banyak file.

### Steps:
1. Buat file `src/ReplicatedStorage/RebirthConfig.luau`
2. Isi dengan:
   - `RebirthConfig.MAX_REBIRTH = 25`
   - `RebirthConfig.UPGRADE_CURVES` — tabel look-up non-flat untuk setiap upgrade (level 0-10 atau 0-5)
   - `RebirthConfig.UPGRADE_CAPS` — max level per upgrade
   - `RebirthConfig.UPGRADE_COST_FORMULA` — tabel berisi base cost per upgrade untuk formula `base * 2^level`
   - `RebirthConfig.UPGRADE_META` — nama tampilan, deskripsi, ikon, dan kategori (Easy/Medium/Hard) untuk UI

---

## Task 2: Update `DataManager.luau` — Tambah 7 Field Upgrade Baru
**File:** `src/ServerScriptService/DataManager/DataManager.luau`

### Steps:
1. Di tabel `DEFAULT_DATA.RebirthUpgrades`, tambahkan 7 field baru:
   - `WalkspeedBoost = 0`
   - `MaxInventorySlots = 0`
   - `DoubleCashChance = 0`
   - `AllVariantsBoost = 0`
   - `VariantChance_Rainbow = 0`
   - `VariantChance_Frostbite = 0`
   - `VariantChance_Galaxy = 0`
   - `VariantChance_Hellfire = 0`
   - `VariantChance_Cosmic = 0`

---

## Task 3: Update `RebirthManager.luau` — Formula Baru & Max Level Cap
**File:** `src/ServerScriptService/RebirthManager/RebirthManager.luau`

### Steps:
1. `require` modul `RebirthConfig` di bagian atas file.
2. **Update `calculateRebirthPoints`:**
   - Ubah formula menjadi: `340 * (rebirthLevel + 1)`
3. **Update `requestRebirth`:**
   - Ubah formula biaya: `1000000 * (1.6 ^ currentRebirth)`
   - Tambah validasi batas maksimum: jika `currentRebirth >= RebirthConfig.MAX_REBIRTH` return error.
4. **Update `purchaseRebirthUpgrade`:**
   - Ambil `maxLevel` dari `RebirthConfig.UPGRADE_CAPS[upgradeName]` — jika sudah max, return error "Sudah Maksimum!".
   - Hitung `cost` menggunakan formula dari `RebirthConfig.UPGRADE_COST_FORMULA[upgradeName]`.
   - Setelah upgrade berhasil, panggil helper `applyRebirthUpgrades(player)` untuk menerapkan efek langsung.
5. **Tambah fungsi `applyRebirthUpgrades(player)`:**
   - Baca `data.RebirthUpgrades` dari DataManager.
   - Hitung dan terapkan Walkspeed langsung ke `Humanoid.WalkSpeed`.
   - Update atribut `MaxInventorySlots` pada player agar bisa dibaca oleh BoxManager.

---

## Task 4: Integrasi Walkspeed & Inventory ke Server (`Main.server.luau` atau `RebirthManager.luau`)
**File:** `src/ServerScriptService/RebirthManager/RebirthManager.luau`

### Steps:
1. Hook `Player.CharacterAdded` di dalam `RebirthManager.Init()`.
2. Setiap kali karakter spawn, panggil `applyRebirthUpgrades(player)` agar Walkspeed diterapkan ulang.

---

## Task 5: Integrasi Cash Multiplier & Double Cash ke `ParkingAreaManager.luau`
**File:** `src/ServerScriptService/ParkingAreaManager/ParkingAreaManager.luau`

### Steps:
1. `require` modul `RebirthConfig` di bagian atas.
2. Di dalam passive income loop (setiap 1 detik per player):
   - Baca level `CashMultiplier` dan `DoubleCashChance` dari atribut player.
   - Hitung `cashMultiplierBonus`: `1 + (UPGRADE_CURVES.CashMultiplier[level] / 100)`.
   - Roll peluang `DoubleCashChance`: jika `math.random() * 100 < chanceValue`, kalikan `addedCash` dengan 2.
   - Terapkan: `addedCash = math.floor(totalIncome * multiplier * cashMultiplierBonus * doubleMultiplier)`.

---

## Task 6: Integrasi Cash Multiplier & Double Cash ke Sell System
**File:** `src/ServerScriptService/SellGuiServer.server.luau`

### Steps:
1. Baca level `CashMultiplier` dan `DoubleCashChance` dari atribut player.
2. Terapkan bonus `cashMultiplierBonus` ke harga jual sebelum ditambahkan ke Cash pemain.
3. Roll peluang double cash — jika hoki, harga jual dilipatgandakan.

---

## Task 7: Integrasi Luck Multiplier ke `BoxManager.luau`
**File:** `src/ServerScriptService/BoxManager/BoxManager.luau`

### Steps:
1. Baca level `LuckMultiplier` dari atribut player.
2. Ambil efek dari `RebirthConfig.UPGRADE_CURVES.LuckMultiplier[level]`.
3. Terapkan ke `totalLuck`:
   ```lua
   totalLuck = totalLuck * (1 + (luckBonus / 100))
   ```

---

## Task 8: Integrasi Variant Chances ke `SpawnerBoxManager.luau`
**File:** `src/ServerScriptService/SpawnerBoxManager/SpawnerBoxManager.luau`

### Steps:
1. Baca seluruh level variant upgrade dari atribut player (`VariantChance_Rainbow`, `Frostbite`, `Galaxy`, `Hellfire`, `Cosmic`, `AllVariantsBoost`).
2. Di dalam loop gacha varian, sebelum rolling setiap varian:
   - Tambahkan bonus rate spesifik varian dari `UPGRADE_CURVES.VariantChance_<NamaVarian>[level]`.
   - Tambahkan bonus global `AllVariantsBoost` dari `UPGRADE_CURVES.AllVariantsBoost[level]` ke semua varian langka (bukan Normal dan bukan Admin).

---

## Task 9: Update `RebirthTab.luau` — UI Shop Baru dengan Kategori & MAXED State
**File:** `src/StarterPlayer/StarterPlayerScripts/components/MainGuiHub/RebirthTab.luau`

### Steps:
1. Perluas tabel `UPGRADE_INFOS` dengan 7 item baru: `WalkspeedBoost`, `MaxInventorySlots`, `DoubleCashChance`, `AllVariantsBoost`, `VariantChance_Rainbow`, `VariantChance_Frostbite`, `VariantChance_Galaxy`, `VariantChance_Hellfire`, `VariantChance_Cosmic`.
2. Tambahkan field `Category` ("Easy"/"Medium"/"Hard") dan `MaxLevel` ke setiap item di `UPGRADE_INFOS`.
3. Ubah rendering upgrade agar dikelompokkan per kategori dengan header label.
4. Hitung biaya upgrade menggunakan formula yang benar per upgrade (masing-masing punya base cost berbeda).
5. Tambahkan state **MAXED**: jika `lvl >= MaxLevel`, disable tombol dan ubah teks menjadi `"✓ MAXED"` dengan warna hijau.
6. Tampilkan deskripsi efek dinamis di setiap item (misal: "Walkspeed +14 → +17" saat hover/klik).

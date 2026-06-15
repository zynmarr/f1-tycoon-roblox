# Spesifikasi Desain: Pembaruan & Perimbangan Sistem Rebirth & Toko Rebirth

Dokumen spesifikasi ini menjelaskan arsitektur baru, perimbangan matematis, skema data, dan detail implementasi untuk pembaruan fitur **Rebirth** dan **Toko Upgrade Rebirth (Rebirth Shop)** pada proyek **F1-Tycoon**.

---

## 1. Batasan Level & Progresi Matematika Rebirth

*   **Batas Level Rebirth Maksimum (`Stats.Rebirth`):** 25.
*   **Formula Biaya Rebirth:**
    Biaya Cash bertambah secara eksponensial sedang dari base $1,000,000$ (1M):
    $$\text{Biaya} = 1,000,000 \times (1.6^{\text{Rebirth Level Saat Ini}})$$
*   **Formula Perolehan Rebirth Points (RP):**
    RP yang diperoleh bertambah secara linier:
    $$\text{RP Diterima} = 340 \times (\text{Rebirth Level Saat Ini} + 1)$$

### Tabel Simulasi Progresi Rebirth 1 - 25:
*   Rebirth 1 (Lvl 0 -> 1): Biaya = **$1,000,000** | Reward = **340 RP** | Akumulasi = **340 RP**
*   Rebirth 2 (Lvl 1 -> 2): Biaya = **$1,600,000** | Reward = **680 RP** | Akumulasi = **1,020 RP**
*   Rebirth 5 (Lvl 4 -> 5): Biaya = **$6,553,600** | Reward = **1,700 RP** | Akumulasi = **5,100 RP**
*   Rebirth 10 (Lvl 9 -> 10): Biaya = **$68,719,476** | Reward = **3,400 RP** | Akumulasi = **18,700 RP**
*   Rebirth 15 (Lvl 14 -> 15): Biaya = **$720,575,940** | Reward = **5,100 RP** | Akumulasi = **40,800 RP**
*   Rebirth 20 (Lvl 19 -> 20): Biaya = **$7,555,786,113** | Reward = **6,800 RP** | Akumulasi = **71,400 RP**
*   Rebirth 25 (Lvl 24 -> 25): Biaya = **$79,496,847,203** | Reward = **8,500 RP** | Akumulasi = **110,500 RP**

---

## 2. Kategori Upgrade & Struktur Biaya Toko (RP Cost)

Toko Upgrade Rebirth memiliki **11 upgrade** yang dikelompokkan ke dalam 3 tingkat kesulitan:

### A. Kategori EASY (Total Biaya: 15,965 RP)
1.  **Cash Multiplier (Max Lvl 10):** Formula $15 \times 2^{\text{Level}}$
    *   *Harga per Level:* 15, 30, 60, 120, 240, 480, 960, 1,920, 3,840, 7,680 RP.
    *   *Total Biaya:* **15,345 RP**
2.  **Max Inventory Slots (Max Lvl 5):** Formula $20 \times 2^{\text{Level}}$
    *   *Harga per Level:* 20, 40, 80, 160, 320 RP.
    *   *Total Biaya:* **620 RP**

### B. Kategori MEDIUM (Total Biaya: 34,255 RP)
3.  **Luck Multiplier (Max Lvl 10):** Formula $25 \times 2^{\text{Level}}$
    *   *Harga per Level:* 25, 50, 100, 200, 400, 800, 1,600, 3,200, 6,400, 12,800 RP.
    *   *Total Biaya:* **25,575 RP**
4.  **Walkspeed Boost (Max Lvl 5):** Formula $80 \times 2^{\text{Level}}$
    *   *Harga per Level:* 80, 160, 320, 640, 1,280 RP.
    *   *Total Biaya:* **2,480 RP**
5.  **Variant Chance - Galaxy (Max Lvl 5):** Formula $80 \times 2^{\text{Level}}$
    *   *Harga per Level:* 80, 160, 320, 640, 1,280 RP.
    *   *Total Biaya:* **2,480 RP**
6.  **Variant Chance - Rainbow (Max Lvl 5):** Formula $60 \times 2^{\text{Level}}$
    *   *Harga per Level:* 60, 120, 240, 480, 960 RP.
    *   *Total Biaya:* **1,860 RP**
7.  **Variant Chance - Frostbite (Max Lvl 5):** Formula $60 \times 2^{\text{Level}}$
    *   *Harga per Level:* 60, 120, 240, 480, 960 RP.
    *   *Total Biaya:* **1,860 RP**

### C. Kategori HARD (Total Biaya: 59,017 RP)
8.  **All Variants Boost (Max Lvl 5):** Formula $600 \times 2^{\text{Level}}$
    *   *Harga per Level:* 600, 1,200, 2,400, 4,800, 9,600 RP.
    *   *Total Biaya:* **18,600 RP**
9.  **Variant Chance - Cosmic (Max Lvl 5):** Formula $600 \times 2^{\text{Level}}$
    *   *Harga per Level:* 600, 1,200, 2,400, 4,800, 9,600 RP.
    *   *Total Biaya:* **18,600 RP**
10. **Variant Chance - Hellfire (Max Lvl 5):** Formula $500 \times 2^{\text{Level}}$
    *   *Harga per Level:* 500, 1,000, 2,000, 4,000, 8,000 RP.
    *   *Total Biaya:* **15,500 RP**
11. **Double Cash Chance (Max Lvl 5):** Formula $150 \times 2.2^{\text{Level}}$
    *   *Harga per Level:* 150, 330, 726, 1,597, 3,514 RP.
    *   *Total Biaya:* **6,317 RP**

**Grand Total Biaya Seluruh Upgrade Toko:** **110,322 RP** (Sisa **178 RP** dari akumulasi RP maksimum di Rebirth 25).

---

## 3. Kurva Progresi Peningkatan Non-Flat (Tapered / Diminishing Returns)

Untuk merelasikan peningkatan level dengan efek riil dalam game secara non-flat, didefinisikan tabel look-up berikut:

```lua
local REBIRTH_UPGRADE_CURVES = {
    -- Level:                     0, 1, 2,  3,  4,  5,  6,  7,  8,  9,  10
    CashMultiplier =            { 0, 5, 9, 12, 15, 18, 21, 24, 26, 28,  30 }, -- Max 30% (+% Cash)
    LuckMultiplier =            { 0, 8, 15, 21, 27, 32, 37, 41, 45, 48, 50 }, -- Max 50% (+% Luck)
    
    -- Level:                     0, 1,  2,  3,  4,  5
    WalkspeedBoost =            { 0, 5, 10, 14, 17, 20 },                     -- Max +20 Speed
    MaxInventorySlots =         { 0, 8, 14, 19, 23, 25 },                     -- Max +25 Slots
    DoubleCashChance =          { 0, 6, 11, 16, 21, 25 },                     -- Max 25% Chance
    
    VariantChance_Rainbow =     { 0, 5,  9, 13, 17, 20 },                     -- Max +20% Rate
    VariantChance_Frostbite =   { 0, 4,  7, 10, 13, 15 },                     -- Max +15% Rate
    VariantChance_Galaxy =      { 0, 3,  6,  9, 11, 13 },                     -- Max +13% Rate
    VariantChance_Hellfire =    { 0, 3,  5,  7,  9, 10 },                     -- Max +10% Rate
    VariantChance_Cosmic =      { 0, 1,  2,  3,  4,  5 },                     -- Max +5% Rate
    AllVariantsBoost =          { 0, 5,  9, 13, 17, 20 },                     -- Max +20% Rate
}
```

---

## 4. Struktur Data & Integrasi Kode (Fungsional Penuh)

### A. Skema Data (`DataManager.luau`)
Struktur data `RebirthUpgrades` pada profile service diperbarui untuk mencakup semua 11 jenis upgrade:
```lua
RebirthUpgrades = {
    CashMultiplier = 0,
    LuckMultiplier = 0,
    DoubleCashChance = 0,
    AllVariantsBoost = 0,
    WalkspeedBoost = 0,
    MaxInventorySlots = 0,
    VariantChance_Rainbow = 0,
    VariantChance_Frostbite = 0,
    VariantChance_Galaxy = 0,
    VariantChance_Hellfire = 0,
    VariantChance_Cosmic = 0,
}
```

### B. Integrasi Fungsional Upgrade (Penerapan Riil ke Sistem Game)
Semua upgrade yang dibeli pemain akan diintegrasikan secara fungsional ke dalam sistem game:

1.  **Integrasi Mesin Spawner Varian (`SpawnerBoxManager.luau`):**
    Saat mesin spawner melakukan gacha varian box:
    *   Sistem memuat data `RebirthUpgrades` pemain.
    *   Untuk setiap varian (Rainbow, Frostbite, Galaxy, Hellfire, Cosmic), bonus rate dari tabel `REBIRTH_UPGRADE_CURVES` ditambahkan ke `totalChance` sebelum di-roll.
    *   Bonus dari `AllVariantsBoost` ditambahkan secara global ke seluruh varian langka.
    *   *Hasil:* Semakin tinggi level upgrade varian pemain, semakin tinggi pula presentase nyata varian tersebut muncul dari mesin spawner.

2.  **Walkspeed Boost:**
    Diterapkan di server melalui trigger `Player.CharacterAdded`. Ketika pemain spawn atau meningkatkan upgrade Walkspeed di shop, kecepatan lari karakter langsung disesuaikan:
    $$\text{WalkSpeed} = 16 + \text{REBIRTH\_UPGRADE\_CURVES.WalkspeedBoost[level]}$$

3.  **Max Inventory Slots:**
    Kapasitas slot penyimpanan tas di-adjust secara dinamis saat validasi kapasitas tas di `BoxManager.luau` dan `EventManager.server.luau`:
    $$\text{MaxSlots} = 50 + \text{REBIRTH\_UPGRADE\_CURVES.MaxInventorySlots[level]}$$

4.  **Cash Multiplier & Double Cash Chance:**
    *   **Pendapatan Pasif (`ParkingAreaManager.luau`):** Pendapatan per detik dikali dengan `1 + (CashMultiplierEffect / 100)`. Selain itu, setiap detik terdapat peluang sebesar `DoubleCashChanceEffect` % untuk melipatgandakan (2x) pendapatan detik tersebut.
    *   **Penjualan Mobil (`SellGuiServer.server.luau` & `SellManager.server.luau`):** Hasil penjualan dikali dengan `1 + (CashMultiplierEffect / 100)`. Ada peluang `DoubleCashChanceEffect` % untuk mendapatkan harga jual 2x lipat.

5.  **Luck Multiplier:**
    Ditambahkan ke kalkulasi `totalLuck` di `BoxManager:openBox` sebagai pengali pasif keberuntungan box:
    $$\text{totalLuck} = (\text{boxBaseLuck} + \text{eventLuckBoost} + \text{playerLuckUpgrade}) \times (1 + \frac{\text{LuckMultiplierEffect}}{100})$$

### C. Pembaruan Frontend UI (`RebirthTab.luau`)
*   Menampilkan seluruh 11 upgrade yang dikelompokkan berdasarkan tab kategori: **Easy**, **Medium**, dan **Hard** agar rapi.
*   Tombol upgrade di-disable jika level upgrade bersangkutan telah mencapai batas maksimum (Max Level Cap) dengan tulisan "MAXED".

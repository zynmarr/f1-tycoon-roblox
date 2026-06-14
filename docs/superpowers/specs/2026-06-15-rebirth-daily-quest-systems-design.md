# Spesifikasi Desain: Sistem Rebirth, Hadiah Harian, dan Misi (Quests)

Dokumen spesifikasi ini menjelaskan arsitektur data, logika server, struktur UI berbasis React Luau, dan detail jaringan untuk implementasi fitur **Rebirth**, **Daily Rewards (Hadiah Harian)**, dan **Quests (Misi Harian & Milestone)** pada proyek **F1-Tycoon**.

---

## 1. Skema Data & Penyimpanan (DataManager)

Untuk mendukung fitur-fitur baru ini, skema data default pada modul `DataManager.luau` ditingkatkan menjadi:

```lua
local DEFAULT_DATA = {
    Stats = {
        Cash = 0,
        Level = 1,
        Rebirth = 0,
        RebirthPoints = 0, -- Poin yang diperoleh dari Rebirth untuk membeli upgrade
    },
    -- Upgrade permanen yang dibeli menggunakan Rebirth Points
    RebirthUpgrades = {
        CashMultiplier = 0,        -- Level upgrade pengali Cash (+15% per level)
        LuckMultiplier = 0,        -- Level upgrade keberuntungan umum (+10% per level)
        VariantChance_Rainbow = 0,   -- Level upgrade khusus meningkatkan rate varian Rainbow
        VariantChance_All = 0,       -- Level upgrade meningkatkan rate seluruh varian langka
    },
    -- Pelacakan login harian berturut-turut
    DailyRewards = {
        LastClaimTime = 0,         -- Unix timestamp saat klaim terakhir kali
        Streak = 0,                -- Rentetan login aktif (1 sampai 7)
    },
    -- Pelacakan progress misi pemain
    Quests = {
        Daily = {
            LastGeneratedTime = 0,   -- Waktu terakhir misi harian di-generasi
            ActiveQuests = {}        -- Array berisi 3 misi aktif hari ini
        },
        Milestones = {
            TotalCarsSold = 0,        -- Akumulasi mobil yang berhasil dijual
            TotalBoxesOpened = 0,     -- Akumulasi box yang berhasil dibuka
            ClaimedMilestones = {}    -- Map penanda milestone yang sudah diklaim hadiahnya
        }
    }
}
```

---

## 2. Mekanik & Logika Server

### A. Mekanik Rebirth & Reset
1. **Biaya Rebirth**:
   Biaya bertambah secara eksponensial dihitung dengan rumus:
   $$\text{Biaya} = 1.000.000 \times 2,5^{\text{Rebirth Level}}$$
   * Rebirth ke-1 (Level 0 ke 1): \$1.000.000
   * Rebirth ke-2 (Level 1 ke 2): \$2.500.000
   * Rebirth ke-3 (Level 2 ke 3): \$6.250.000
2. **Poin Rebirth yang Diperoleh (Skala Hard - Opsi A)**:
   Pemain akan menerima poin dalam jumlah ratusan yang bertumbuh setiap 3 level rebirth:
   * Level 1: **50 Poin**
   * Level 2: **100 Poin**
   * Level 3: **180 Poin**
   * Level 4: $(180 \times 2) + 20 = $ **380 Poin**
   * Level 5: $380 + 100 = $ **480 Poin**
   * Level 6: $480 + 100 = $ **580 Poin**
   * Level 7: $(580 \times 2) + 20 = $ **1180 Poin**
3. **Mekanisme Reset Aset**:
   Saat Rebirth dikonfirmasi:
   * `Cash` pemain diset kembali ke `0`.
   * Seluruh status kepemilikan mesin tycoon (dalam plot pemain) dikembalikan ke kondisi belum dibeli (`purchased = false` dan level di-reset ke awal).
   * Seluruh mobil di dalam `Backpack` (tas) dan karakter pemain, serta mobil yang terparkir di `Parking Area` akan **dihapus sepenuhnya**, **KECUALI** mobil/box yang memiliki atribut `Variant == "Admin"` atau namanya mengandung kata `"Admin"`.

### B. Misi (Quests) & Milestone
Server memantau kemajuan misi melalui pelacakan event:
* **Misi Harian (Daily Quests)**:
  Setiap 24 jam sekali, server menghasilkan 3 misi baru. Contoh misi:
  * `"SellCars"`: Menjual sejumlah kendaraan (Target: 5 - 20 mobil).
  * `"OpenBoxes"`: Membuka sejumlah box gacha (Target: 3 - 10 box).
  * `"EarnCash"`: Menghasilkan sejumlah Cash (Target: \$50.000 - \$500.000).
* **Misi Jangka Panjang (Milestones)**:
  Tercatat seumur hidup dan tidak pernah di-reset:
  * `"TotalCarsSold"`: Reward diberikan pada kelipatan 50, 100, 250, 500, dst.
  * `"TotalBoxesOpened"`: Reward diberikan pada kelipatan 25, 50, 150, 300, dst.

### C. Hadiah Harian (Daily Rewards)
* **Klaim Hadiah**: Diizinkan jika selisih waktu saat ini dengan `LastClaimTime` lebih besar atau sama dengan 20 jam (`os.time() - LastClaimTime >= 72000`).
* **Pengecekan Streak**:
  * Jika diklaim dalam jangka waktu $20$ hingga $48$ jam sejak klaim terakhir, streak login bertambah 1 hari (maksimal Hari 7).
  * Jika jeda waktu melebihi 48 jam, streak login di-reset kembali ke Hari 1.
* **Tabel Hadiah**:
  * Hari 1: \$5.000 Cash
  * Hari 2: \$12.000 Cash
  * Hari 3: 1x Common Box
  * Hari 4: \$30.000 Cash
  * Hari 5: 1x Rare Box
  * Hari 6: \$75.000 Cash
  * Hari 7: 1x Epic Box / Mobil Khusus

---

## 3. Komunikasi Jaringan (Networker & RemoteEvents)

Untuk pertukaran data antara client dan server, kita akan mendaftarkan beberapa endpoint baru menggunakan modul **Networker**:

```lua
-- Hubungkan aksi client ke server
Networker.server.new("RebirthService", RebirthManager, {
    RebirthManager.requestRebirth,         -- Memicu proses Rebirth & Reset
    RebirthManager.purchaseRebirthUpgrade, -- Membeli upgrade permanen menggunakan RP
    RebirthManager.claimDailyReward,       -- Mengeklaim hadiah login harian
    RebirthManager.claimDailyQuest,        -- Mengeklaim reward misi harian yang selesai
    RebirthManager.claimMilestoneQuest,    -- Mengeklaim reward milestone
})
```

---

## 4. Arsitektur Antarmuka (React UI Hub)

Semua menu akan diintegrasikan ke dalam satu UI Hub terpadu untuk performa maksimal dan kemudahan navigasi.

### Pohon Komponen React (React Component Tree):
```
MainGuiHub (ScreenGui)
 └── MainContainer (Frame - Centered, Translucent Blur)
      ├── Header (Frame)
      │    ├── Title ("F1 Tycoon Rewards & Rebirth")
      │    └── StatsBar (Cash Display & Rebirth Points Display)
      ├── Sidebar (Frame - Left Aligned)
      │    ├── TabButton ("Rebirth Shop")
      │    ├── TabButton ("Hadiah Harian")
      │    └── TabButton ("Misi & Pencapaian")
      ├── ContentArea (Frame - Right Aligned)
      │    ├── RebirthTab (Rendered conditionally)
      │    │    ├── RebirthControl (Info level Rebirth, tombol "REBIRTH" merah besar)
      │    │    └── UpgradeList (ScrollingFrame berisi daftar permanent upgrades)
      │    ├── DailyRewardsTab (Rendered conditionally)
      │    │    └── DayGrid (Tampilan grid 7 kartu hadiah harian dengan indikator status)
      │    └── QuestsTab (Rendered conditionally)
      │         ├── DailyQuestsGroup (Scrolling list misi harian dengan progress bar)
      │         └── MilestonesGroup (Scrolling list pencapaian jangka panjang)
      └── CloseButton (ImageButton - Top Right Corner)
```

---

## 5. Rencana Pengujian (Testing Plan)
* **Pengujian Reset Rebirth**: Memastikan bahwa ketika Rebirth ditekan dengan uang yang cukup, seluruh plot ter-reset kembali ke kondisi nol, uang di-reset menjadi 0, dan semua mobil non-Admin di backpack serta tempat parkir terhapus sempurna.
* **Pengujian Multiplier**: Memverifikasi bahwa setelah membeli upgrade "CashMultiplier", semua pendapatan dari parkir atau penjualan mobil menerima tambahan persenan multiplier yang tepat.
* **Pengujian Simpan/Muat Misi**: Menjamin data streak hadiah harian dan kemajuan misi tidak hilang atau terulang saat pemain keluar dan masuk kembali ke server.

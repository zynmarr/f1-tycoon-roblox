# Implementation Plan: Event Variant Manager Update

Dokumen ini adalah rencana implementasi untuk membuat sistem Event Variant Manager, mereplikasi status event ke client, serta menambahkan efek visual lokal dan memperbarui HUD pemain berdasarkan spesifikasi desain di `docs/superpowers/specs/2026-06-26-event-variant-manager-design.md`.

---

## Task 1: Buat Modul Konfigurasi `EventVariantConfig.luau`
**File:** `src/ReplicatedStorage/EventVariantConfig.luau` (baru)

Buat file konfigurasi terpusat agar admin/pembuat game dapat dengan mudah mengedit parameter durasi, persentase boost, nama aset efek visual, dan tipe render efek tanpa merusak logika script utama.

### Steps:
1. Buat file `src/ReplicatedStorage/EventVariantConfig.luau`.
2. Isi dengan tabel konfigurasi varian (`Rainy`, `Shiny`, `Golden`, `Rainbow`, `Frostbite`), persentase peluang awal (70% Rehat, 30% Aktif), serta durasi waktu (Event Aktif 5 menit, Rehat acak 3-5 menit).

---

## Task 2: Buat Server Script `EventVariantManager.luau`
**File:** `src/ServerScriptService/eventvariantmanager/EventVariantManager.luau` (baru)

Buat modul baru di server untuk mengelola siklus timer event individual per pemain secara dinamis.

### Steps:
1. Buat folder `src/ServerScriptService/eventvariantmanager` jika belum ada.
2. Buat file `src/ServerScriptService/eventvariantmanager/EventVariantManager.luau`.
3. Terapkan fungsi `EventVariantManager.startPlayerLoop(player: Player)`:
   - Roll peluang awal (70% Rehat, 30% Aktif).
   - Jalankan loop `while player and player.Parent do`:
     - **Jika Active**: Pilih varian acak, set attributes pada player (`ActiveEventVariant`, `ActiveEventBoost`, `EventStatus`, `EventEndTime`, `EventNextVariant`), lalu tunggu 300 detik.
     - **Jika Rest**: Set attributes pada player (`ActiveEventVariant = "None"`, `ActiveEventBoost = 0`, `EventStatus = "Rest"`), tentukan waktu rehat acak (180 - 300 detik), tentukan varian berikutnya secara acak, lalu tunggu durasi rehat tersebut.
4. Terapkan fungsi `EventVariantManager.stopPlayerLoop(player: Player)` untuk menghentikan loop/membersihkan thread ketika player keluar.

---

## Task 3: Hubungkan EventVariantManager ke Player Lifecycle
**File:** `src/ServerScriptService/Main.server.luau`

Hubungkan loop individual per player ke alur login/logout game utama.

### Steps:
1. `require` modul `EventVariantManager` di bagian atas file.
2. Di dalam fungsi `onPlayerAdded(player)`:
   - Panggil `EventVariantManager.startPlayerLoop(player)` setelah data awal pemain selesai dimuat (`player:SetAttribute("DataLoaded", true)`).
3. Di dalam fungsi `onPlayerRemoving(player)`:
   - Panggil `EventVariantManager.stopPlayerLoop(player)`.

---

## Task 4: Integrasikan Boost Event ke Logika Gacha Spawner Box
**File:** `src/ServerScriptService/SpawnerBoxManager/SpawnerBoxManager.luau`

Modifikasi logika spawn box agar memperhitungkan bonus peluang +25% dari event variant aktif milik player.

### Steps:
1. Di dalam fungsi `spawnBox(player, machineArea, ...)`:
2. Sebelum menghitung peluang gacha untuk setiap varian (`vName`):
   - Baca atribut `ActiveEventVariant` dan `ActiveEventBoost` dari objek `player`.
   - Jika `activeVariant == vName`, tambahkan peluang dasar varian dengan `activeBoost` (yaitu +25%).

---

## Task 5: Buat Folder Aset dan Placeholder `eventassets`
**File:** `src/ReplicatedStorage/eventassets/` (baru)

Siapkan folder penyimpanan aset efek visual di `ReplicatedStorage` agar dapat diakses oleh Client Script secara lokal, beserta beberapa placeholder sementara untuk pengetesan.

### Steps:
1. Buat folder `src/ReplicatedStorage/eventassets` jika belum ada.
2. Buat objek placeholder sementara di dalamnya (melalui Roblox Studio):
   - Sebuah objek `Sky` bernama `RainySky` (atau sejenisnya).
   - Sebuah `Tool` bernama `Rain` (untuk efek hujan sementara).
   - Objek `Sky` lain untuk `ShinySky`, `GoldenSky`, `RainbowSky`, `FrostbiteSky`.
3. Buat file `.meta.json` yang sesuai untuk folder baru ini agar Rojo mendeteksinya dengan benar.

---

## Task 6: Buat Client Script `EventVariantClient.luau`
**File:** `src/StarterPlayer/StarterPlayerScripts/EventVariantClient.luau` (baru)

Buat Client Script lokal untuk merender UI BillboardGui melayang di atas plot dan menangani efek visual (langit/hujan) secara lokal.

### Steps:
1. Buat file `src/StarterPlayer/StarterPlayerScripts/EventVariantClient.luau`.
2. Modul ini akan mendengarkan perubahan atribut player: `ActiveEventVariant`, `EventStatus`, `EventEndTime`, `EventNextVariant`.
3. **Logika Render UI**:
   - Deteksi plot milik pemain menggunakan `GameUtils.getPlayerPlot(LocalPlayer)`.
   - Buat `BillboardGui` lokal di atas plot pemain.
   - Perbarui Teks (bahasa Inggris, misal `GOLDEN EVENT!`, `RESTING`, dsb.), progress bar, dan warna bar secara real-time menggunakan event `RunService.RenderStepped` berdasarkan `EventEndTime`.
4. **Logika Efek Visual (Lokal)**:
   - Jika terjadi pergantian status/event, bersihkan efek langit dan hujan lama.
   - **Efek Langit**: Kloning objek `Sky` yang sesuai dari `ReplicatedStorage.eventassets` ke `game.Lighting` secara lokal.
   - **Efek Hujan (Rainy)**: Kloning Tool `Rain` ke `plot.Baseplate`, kemudian posisikan pivotnya secara lokal agar X & Z sejajar dengan plot pemain, namun tingginya (Y) tetap mengikuti tinggi template aslinya.

---

## Task 7: Update HUD Statistik Modifikasi
**File:** `src/StarterPlayer/StarterPlayerScripts/components/MainHUD/CustomStats.luau`

Tambahkan baris modifier baru pada daftar statistik di HUD React client ketika event variant aktif sedang berlangsung.

### Steps:
1. `require` modul `EventVariantConfig` di bagian atas file.
2. Baca atribut `ActiveEventVariant` dan `EventStatus` dari player lokal.
3. Di dalam list statistik yang di-render React:
   - Jika `EventStatus == "Active"` dan `ActiveEventVariant` valid:
     - Cari ikon, DisplayName, dan nilai boost dari `EventVariantConfig.Variants[ActiveEventVariant]`.
     - Masukkan baris baru:
       - Icon: (Sesuai icon varian, misal 👑, 🌈, ❄️)
       - Name: `"Event [VariantName] Boost"` (Bahasa Inggris)
       - Value: `"+25%"`
       - Description: `"Increases the chance of unboxing [VariantName] boxes."` (Bahasa Inggris)
   - Jika `EventStatus == "Rest"`, sembunyikan baris statistik ini secara otomatis.

# Rencana Implementasi: Sistem RPM Tokens & Toko Game (ShopGui) Responsif

Rencana ini membagi pekerjaan implementasi Toko RPM dan Gamepass menjadi langkah-langkah terperinci untuk diselesaikan secara berurutan.

---

## Tugas 1: Perbaikan Bug Deteksi Area & Penguatan Teleportasi (Server-Side & Shared)

- [ ] **Langkah 1: Perbaiki `GameUtils.getPlotSellShopArea`**
  Lokasi File: [GameUtils.luau](file:///C:/Project/Roblox Studio Projects/Projects/F1-Tycoon/src/ReplicatedStorage/GameUtils.luau)
  * Ubah fungsi `getPlotSellShopArea` agar tidak melakukan pencarian hardcoded `"SellArea"`, melainkan menggunakan parameter `areaName` yang dikirim:
    ```luau
    function GameUtils.getPlotSellShopArea(plot: Folder, areaName: string): Part?
        if not plot or not areaName then return nil end
        local areaFolder = plot:FindFirstChild(areaName)
        if not areaFolder then return nil end
        return areaFolder:FindFirstChild("Area")
    end
    ```

- [ ] **Langkah 2: Perbaiki Bug Crash Penjualan Mobil**
  Lokasi File: [SellGuiServer.server.luau](file:///C:/Project/Roblox Studio Projects/Projects/F1-Tycoon/src/ServerScriptService/SellGuiServer.server.luau)
  * Di baris 44 dan 242, ubah pemanggilan fungsi `GameUtils.getPlayerSellArea(player)` menjadi `GameUtils.getPlayerSellShopArea(player, "SellArea")`.

- [ ] **Langkah 3: Perkuat Logika Teleportasi**
  Lokasi File: [TeleportHandler.server.luau](file:///C:/Project/Roblox Studio Projects/Projects/F1-Tycoon/src/ServerScriptService/TeleportHandler.server.luau)
  * Perbarui handler teleportasi untuk target `"SellArea"` dan `"ShopArea"`. Gunakan fallback aman ke CFrame utama `Area` jika part `LightCore` tidak ditemukan.

---

## Tugas 2: Implementasi Skema Penyimpanan RPM Tokens (Server-Side)

- [ ] **Langkah 1: Tambahkan RPMTokens ke Skema Data Profil**
  Lokasi File: [DataManager.luau](file:///C:/Project/Roblox Studio Projects/Projects/F1-Tycoon/src/ServerScriptService/DataManager/DataManager.luau)
  * Tambahkan `RPMTokens = 0` di dalam `DEFAULT_DATA.Stats`.
  * Di dalam fungsi `DataManager.syncData`, tambahkan pembacaan dari leaderstats `"RPM Tokens"` untuk disimpan kembali ke profil saat pemain keluar atau auto-save:
    ```luau
    finalSave.Stats.RPMTokens = leaderstats:FindFirstChild("RPM Tokens") and leaderstats["RPM Tokens"].Value or 0
    ```

- [ ] **Langkah 2: Tambahkan RPM Tokens ke Leaderboard Fisik**
  Lokasi File: [Main.server.luau](file:///C:/Project/Roblox Studio Projects/Projects/F1-Tycoon/src/ServerScriptService/Main.server.luau)
  * Di fungsi `onPlayerAdded`, di dalam pembuatan folder `leaderstats`, buatlah `IntValue` bernama `"RPM Tokens"`, set nilainya sesuai data profil pemain, dan pasang ke folder leaderstats.

---

## Tugas 3: Pembuatan Modul Shop & RPM Token Manager (Server-Side)

- [ ] **Langkah 1: Buat Modul Server `ShopManager`**
  Lokasi File: `src/ServerScriptService/ShopManager/ShopManager.luau`
  * Buat file modul baru `ShopManager.luau`.
  * Implementasikan fungsi `ShopManager.Init()`:
    * Daftarkan channel Networker `"ShopGui"`.
    * Hubungkan listener `Players.PlayerAdded` untuk memulai thread background loop playtime pemain: setiap 60 detik bermain, tambahkan `1` RPM Token ke leaderstats `"RPM Tokens"` dan sinkronisasikan ke cache profil.
  * Buat metode Networker `buyBox(player, boxLevel: number)`:
    * Validasi jarak pemain ke `ShopArea` menggunakan `GameUtils.getPlayerSellShopArea`.
    * Cek ketersediaan RPM Tokens dan sisa slot tas pemain.
    * Kurangi saldo RPM Tokens, kloning template `Box` dari `ServerStorage`, set atribut `Level = boxLevel` dan berikan tag `"Box"`, lalu taruh di `Backpack` pemain.
  * Tambahkan binding `MarketplaceService.ProcessReceipt` untuk menangani pembelian instan box via Robux Developer Products (sesuai ID produk di konfigurasi).

- [ ] **Langkah 2: Hubungkan `ShopManager` ke Bootstrapper Server**
  Lokasi File: [Main.server.luau](file:///C:/Project/Roblox Studio Projects/Projects/F1-Tycoon/src/ServerScriptService/Main.server.luau)
  * Impor `ShopManager` di baris atas berkas menggunakan `safeRequire`.
  * Jalankan `ShopManager.Init()` secara berurutan dalam logika inisialisasi server.

---

## Tugas 4: Integrasi Konfigurasi Toko & Gamepass (Shared)

- [ ] **Langkah 1: Buat Konfigurasi `ShopConfig`**
  Lokasi File: `src/ReplicatedStorage/ShopConfig.luau`
  * Definisikan daftar box/crate yang dijual (dengan level, nama, harga token, harga Robux, dan ProductID).
  * Definisikan daftar Gamepass yang dijual (dengan ID gamepass, nama, harga Robux, deskripsi, dan ikon aset).

---

## Tugas 5: UI React ShopGui & Proximity Loop (Client-Side)

- [ ] **Langkah 1: Desain Ulang Komponen React `ShopGui`**
  Lokasi File: [ShopGui.luau](file:///C:/Project/Roblox Studio Projects/Projects/F1-Tycoon/src/StarterPlayer/StarterPlayerScripts/components/ShopGui/ShopGui.luau)
  * Ganti template lama dengan struktur React baru:
    * Layout modern dengan tab switcher (`Item Game` vs `Gamepass`).
    * Grid responsive (`UIGridLayout`) untuk menampilkan kartu barang dagangan.
    * Tampilan saldo RPM Tokens di header.
    * Setiap kartu Box memiliki dua tombol beli: "RPM Tokens" dan "Robux".
    * Pemicu prompt pembelian Roblox (`MarketplaceService:PromptProductPurchase` & `PromptGamePassPurchase`) saat tombol Robux diklik.

- [ ] **Langkah 2: Buat Controller Proximity Client**
  Lokasi File: `src/StarterPlayer/StarterPlayerScripts/ShopGui.client.luau`
  * Buat script client baru untuk menggantikan `MountShop.client.luau`.
  * Mount komponen React `ShopGui` ke `PlayerGui`.
  * Jalankan loop deteksi jarak 0.5 detik ke `ShopArea` plot milik pemain untuk otomatis membuka/menutup UI Toko.

---

## Tugas 6: Pengujian & Validasi Sistem (Testing)

- [ ] **Langkah 1: Tes Akumulasi RPM Tokens pasif** (tunggu 1 menit dan cek papan skor).
- [ ] **Langkah 2: Tes Auto Open/Close UI Toko** (berjalan mendekati dan menjauhi area fisik toko).
- [ ] **Langkah 3: Tes Pembelian Box menggunakan Tokens** (serta validasi jika token kurang).
- [ ] **Langkah 4: Tes Pembelian Box menggunakan Robux** (klik tombol Robux, cek prompt developer product muncul).
- [ ] **Langkah 5: Tes Pembelian Gamepass** (klik tombol Gamepass, cek prompt Robux muncul).

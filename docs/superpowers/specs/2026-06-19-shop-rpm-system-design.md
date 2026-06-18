# Spesifikasi Desain: Sistem RPM Tokens & Toko Game (ShopGui) Responsif

Dokumen spesifikasi ini menjelaskan arsitektur penyimpanan data, logika penambahan RPM Tokens server-side, sistem transaksi pembelian box, perbaikan bug deteksi area, dan desain antarmuka UI React responsif untuk **Toko RPM (ShopGui)** pada proyek **F1-Tycoon**.

---

## 1. Skema Data & Penyimpanan Permanen (`DataManager`)

Untuk menyimpan akumulasi **RPM Tokens** (mata uang berbasis lama bermain) milik pemain secara permanen, kita melakukan pembaruan skema data berikut:

### A. Skema Data Default (`DataManager.luau`)
Field `RPMTokens` ditambahkan ke dalam sub-tabel `Stats` di dalam data default:
```luau
local DEFAULT_DATA = {
	Stats = {
		Cash = 0,
		Level = 1,
		Rebirth = 0,
		RebirthPoints = 0,
		RPMTokens = 0, -- Saldo RPM Tokens pemain (bermula dari 0)
		RaceStats = {
			Wins = 0,
			Losses = 0,
			CashEarned = 0,
			WinStreak = 0,
			PvPWins = 0,
		},
	},
	Inventory = {},
	PlotData = {
		MyCars = {},
		Machines = {},
	},
	-- ...
}
```

### B. Sinkronisasi Data Saat Keluar/Auto-save (`DataManager.syncData`)
Nilai aktual dari leaderstats `RPM Tokens` dibaca secara live dan disimpan kembali ke ProfileStore saat `syncData` dipanggil:
```luau
finalSave.Stats.RPMTokens = leaderstats:FindFirstChild("RPM Tokens") and leaderstats["RPM Tokens"].Value or 0
```

---

## 2. Mekanik Server & Loop Waktu Bermain (`ShopManager.luau`)

Kita membuat modul server baru **`src/ServerScriptService/ShopManager/ShopManager.luau`** yang terintegrasi secara modular ke dalam sistem manager server. Modul ini bertanggung jawab atas:

### A. Loop Akumulasi RPM Tokens Pasif
* Ketika pemain masuk game (`Players.PlayerAdded`), server memulai thread background khusus pemain tersebut.
* Setiap **60 detik (1 menit)** bermain, server akan:
  1. Menambah nilai `RPMTokens` di dalam cache data profil pemain sebanyak `1`.
  2. Memperbarui nilai `IntValue` `"RPM Tokens"` di dalam leaderstats fisik pemain agar diperbarui secara visual di papan skor.

### B. Komunikasi Jaringan (Networker `"ShopGui"`)
Server mendaftarkan channel Networker `"ShopGui"` dengan satu metode: `buyBox(player, boxLevel: number)`:
1. **Validasi Lokasi (Anti-Cheat)**: Memastikan jarak pemain ke `ShopArea` miliknya sendiri berada dalam radius aman (maksimal 50 studs) menggunakan helper `GameUtils.getPlayerSellShopArea(player, "ShopArea")`.
2. **Validasi Saldo RPM Tokens**: Memastikan saldo `RPM Tokens` pemain mencukupi untuk harga box yang diminta.
3. **Validasi Kapasitas Tas**: Memastikan tas (`Backpack`) pemain masih memiliki slot kosong (`inventoryCount < maxInventorySlots`).
4. **Eksekusi Transaksi**:
   * Mengurangi saldo RPM Tokens pemain (leaderstats & profil data).
   * Membuat box baru dari template `ServerStorage.Box`, menyetel atribut `Level` sesuai boxLevel yang dibeli, dan memberikannya tag `"Box"` (sehingga `BoxManager` otomatis menginisialisasi model visual dan sensor fisik 3D box tersebut).
   * Menaruh Box baru tersebut di dalam `Backpack` pemain.
   * Mengembalikan `{ Success = true, Message = "Berhasil membeli " .. boxName }` ke client.

---

## 3. Perbaikan Bug Deteksi Area & Teleportasi

Kita mendeteksi dan memperbaiki beberapa kesalahan logika yang ada pada berkas pembantu dan handler sebelumnya:

### A. Perbaikan Bug `GameUtils.getPlotSellShopArea`
Fungsi sebelumnya salah mengabaikan parameter `areaName` dan selalu mencari `"SellArea"`. Kita memperbaikinya agar dinamis:
```luau
function GameUtils.getPlotSellShopArea(plot: Folder, areaName: string): Part?
	if not plot or not areaName then
		return nil
	end
	local areaFolder = plot:FindFirstChild(areaName)
	if not areaFolder then
		return nil
	end
	return areaFolder:FindFirstChild("Area")
end
```

### B. Perbaikan Bug Crash di `SellGuiServer.server.luau`
Fungsi ini sebelumnya memanggil `GameUtils.getPlayerSellArea(player)` yang tidak pernah ada (seharusnya `GameUtils.getPlayerSellShopArea(player, "SellArea")`). Kita memperbaikinya agar client dapat menjual mobil tanpa error.

### C. Penguatan Teleportasi `TeleportHandler.server.luau`
Menambahkan fallback aman di mana jika part target `LightCore` di dalam area tidak ditemukan, server tetap melakukan teleportasi ke koordinat bagian utama `Area`.

---

## 4. Konfigurasi Item Toko & Gamepass (`ShopConfig.luau`)

Kita membuat file konfigurasi terpusat baru **`src/ReplicatedStorage/ShopConfig.luau`** yang digunakan oleh client maupun server:

```luau
local ShopConfig = {}

-- Daftar Box yang dijual menggunakan RPM Tokens
ShopConfig.Items = {
	{ Level = 1, Name = "Starter Wooden Crate", Cost = 5, Description = "Kotak kayu dasar untuk pemula." },
	{ Level = 3, Name = "Reinforced Steel Case", Cost = 15, Description = "Kotak baja kokoh dengan rate gacha lebih baik." },
	{ Level = 5, Name = "Bronze Tier Container", Cost = 30, Description = "Kontainer perunggu berisi mobil kelas menengah." },
	{ Level = 8, Name = "Platinum F1 Box", Cost = 75, Description = "Kotak platinum dengan peluang besar mendapat mobil legendaris." },
	{ Level = 10, Name = "Emerald Paddock Case", Cost = 150, Description = "Casing eksklusif dengan peluang mobil mitos F1." },
}

-- Daftar Gamepass yang dipajang di Toko (pembelian via Robux)
ShopConfig.Gamepasses = {
	{
		ID = 1819444791,
		Name = "VIP Access",
		CostRobux = 400,
		Description = "Dapatkan cash 1.2x lebih banyak, tag obrolan VIP, dan akses area khusus.",
		Icon = "rbxassetid://15682855589", -- ID Aset Ikon Gamepass
	},
	{
		ID = 99999999, -- Ganti dengan ID asli nanti
		Name = "Double Cash",
		CostRobux = 250,
		Description = "Kesempatan 25% mendapatkan Cash 2x lipat saat menjual mobil.",
		Icon = "rbxassetid://15682855590",
	},
}

return ShopConfig
```

---

## 5. UI React & Interaksi Client (`ShopGui.luau` & `ShopGui.client.luau`)

### A. Komponen UI React (`ShopGui.luau`)
* **Responsive Layout**: Menggunakan kerangka grid dinamis yang otomatis mereduksi ukuran kartu dan menyesuaikan kolom sesuai perangkat (Mobile/Tablet/PC).
* **Tab Switcher**: Tombol tab navigasi `"📦 ITEM"` dan `"🔱 GAMEPASS"` untuk memisahkan daftar barang belanjaan.
* **Integrasi Status**: Menampilkan saldo `RPM Tokens` pemain saat ini secara real-time di header.
* **Aksi Pembelian**:
  * Untuk **Item Game**: Mengirim request fetch melalui Networker `"ShopGui"` ke server. Menampilkan umpan balik visual (*Toast*) jika berhasil atau gagal.
  * Untuk **Gamepass**: Memanggil `MarketplaceService:PromptGamePassPurchase` langsung dari sisi client untuk membuka layar Robux Roblox.

### B. Client Proximity Controller (`ShopGui.client.luau`)
Menggantikan `MountShop.client.luau` yang sebelumnya dinonaktifkan:
* Melakukan inisialisasi awal (*mount*) komponen React `ShopGui` ke `PlayerGui`.
* Menjalankan loop deteksi jarak (setiap 0.5 detik):
  * Jika pemain berada di dalam radius `8 studs` dari `ShopArea` miliknya, UI otomatis terbuka (`Enabled = true`).
  * Jika berjalan keluar radius `8 studs`, UI otomatis tertutup (`Enabled = false`).

---

## 6. Alur Pengujian & Validasi (Testing Plan)

1. **Uji Coba Waktu Bermain**: Masuk ke dalam game, diam selama 1 menit, dan pastikan nilai stats `RPM Tokens` di kanan atas bertambah dari 0 menjadi 1, dan datanya tersimpan saat keluar game.
2. **Uji Coba Deteksi Jarak**: Dekati area fisik `ShopArea` di plot, pastikan UI Toko langsung menyembul di layar secara responsif. Menjauh dari area tersebut, dan pastikan UI menghilang.
3. **Uji Transaksi Pembelian Box**:
   * Coba beli Box Level 1 jika saldo token kurang, pastikan muncul notifikasi kegagalan.
   * Coba beli Box Level 1 setelah mengumpulkan 5 RPM Tokens. Pastikan saldo berkurang, box masuk ke Backpack, dan model visual box terpasang dengan benar.
4. **Uji Pembelian Gamepass**: Klik tombol beli gamepass di tab GAMEPASS, dan pastikan prompt pembelian Robux bawaan Roblox muncul di layar.

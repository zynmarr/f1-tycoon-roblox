# Spesifikasi Desain: Redesain Unified React HUD

Dokumen ini menjelaskan spesifikasi arsitektur dan visual untuk merombak UI standar biner (`.rbxm`) di `StarterGui` menjadi sistem **Unified React HUD** yang dinamis, premium, dan sepenuhnya responsif di semua perangkat (PC, Tablet, Mobile).

---

## 1. Ringkasan Perubahan

| Fitur / UI | Sistem Lama (Biner / Script Tradisional) | Sistem Baru (Unified React HUD) |
|---|---|---|
| **Penyimpanan UI** | File `.rbxm` biner di `src/StarterGui` | Komponen React fungsional di `src/StarterPlayer/StarterPlayerScripts/components/MainHUD` |
| **Tata Letak (Layout)** | Statis (ScreenGui terpisah) | Dinamis & Responsif (Satu ScreenGui induk `MainHUD`, tata letak menyesuaikan lebar layar) |
| **Topbar** | `TopMenuGui.rbxm` (Home, Sell) | Komponen `Topbar.luau` React (Shop, Home, Sell di tengah atas) |
| **Sidebar** | `SideMenuGui.rbxm` (Backpack, Rebirth, Trade, dll.) | Komponen `Sidebar.luau` React (Navigasi samping di PC, navigasi bawah di Mobile) |
| **Statistik (Stats)** | `CustomStatsGui.rbxm` (Hanya Cash) | Komponen `CustomStats.luau` React (Uang, Poin Rebirth Shop, Level Rebirth di kanan atas) |
| **Buff Aktif** | Tidak ada indikator visual langsung | Komponen `ActiveBuffs.luau` (Ikon buff besar di atas, persentase kecil di bawah, tooltip saat di-klik) |
| **Hotbar & Inventory** | `CustomHotbar.rbxm` + `SlotTemplate.rbxm` | Komponen `Hotbar.luau` & `InventoryModal.luau` React (ViewportFrame 3D dinamis) |
| **Buka Box** | `OpenBoxGui.rbxm` (Tombol statis dimanipulasi server) | Komponen `OpenBoxOverlay.luau` React (Muncul otomatis di atas hotbar saat memegang Box) |

---

## 2. Struktur File & Folder Baru

Semua file biner `.rbxm` di `src/StarterGui` akan dihapus, dan diganti dengan struktur komponen berikut:

```
src/
├── StarterGui/ (Semua file biner lama dihapus)
│
├── StarterPlayer/
│   └── StarterPlayerScripts/
│       ├── MountMainHUD.client.luau  (Controller utama untuk me-mount React HUD)
│       │
│       └── components/
│           └── MainHUD/
│               ├── MainHUD.luau        (Komponen induk utama React HUD)
│               ├── Topbar.luau         (Komponen menu atas: Shop, Home, Sell)
│               ├── Sidebar.luau        (Komponen menu samping/bawah responsif)
│               ├── CustomStats.luau    (Komponen penampil stats player & active buffs)
│               ├── Hotbar.luau         (Komponen slot hotbar di bawah)
│               ├── InventoryModal.luau (Komponen modal grid inventory/backpack)
│               └── OpenBoxOverlay.luau (Komponen tombol "Buka Box" di atas hotbar)
```

---

## 3. Spesifikasi Arsitektur & Aliran Data

### 3A. Registrasi Tombol Sidebar Dinamis via BindableEvent
Untuk mendecouple logic modul UI lain (Rebirth, Trade, Admin Panel) dari HUD utama, `MountMainHUD` akan mendaftarkan BindableEvent di `ReplicatedStorage`:
* `RegisterSidebarButton` (parameter: `config: { Name: string, Label: string, Icon: string, Callback: () -> (), Order: number? }`)
* `UnregisterSidebarButton` (parameter: `name: string`)

Ketika dipanggil, `MainHUD.luau` akan memperbarui statenya dan merender tombol tersebut secara real-time di `Sidebar.luau`.

### 3B. Sinkronisasi Data Stats & Active Buffs
* **Stats:**
  * **Cash:** Memantau `leaderstats.Cash.Value` (diubah formatnya dengan `GameUtils.formatCompact`).
  * **Rebirth:** Memantau `leaderstats.Rebirth.Value`.
  * **RebirthPoints:** Memantau attribute `"RebirthPoints"` pada Player object.
* **Active Buffs:**
  * Memantau folder `ReplicatedStorage.LiveEvents` untuk mendeteksi `LuckyChanceBoost` (🍀), `ExpBoost` (🆙), `VariantBoost` (🌟), `VariantBoost_Golden` (🔱), `VariantBoost_Rainbow` (🌈), `VariantBoost_Galaxy` (🌌), `VariantBoost_Hellfire` (🔥).
  * Memantau attribute `"SpeedBoost"` (⚡) pada `ReplicatedStorage`.
  * Jika nilai boost > 0, tampilkan di bawah kartu `CustomStats`.

---

## 4. Desain Komponen UI (Aestetika Premium)

### 4A. Aestetika Umum
* **Warna Latar:** Slate gelap transparan (`Color3.fromRGB(15, 15, 20)` dengan `BackgroundTransparency = 0.35`) untuk efek glassmorphism.
* **Garis Tepi:** `UIStroke` tipis warna aksen ungu/biru transparan (`Color3.fromRGB(80, 80, 100)`).
* **Font:** `Enum.Font.GothamBold` untuk judul/tombol, `Enum.Font.Gotham` untuk teks kecil.
* **UICorner:** Radius tetap `UDim.new(0, 8)`.

### 4B. Detail Komponen Utama

#### Topbar (Menu Atas)
* Posisi: Tengah-atas layar, melayang secara horizontal.
* Tombol: 🛒 Shop (Toggles ShopGui), 🏠 Home (teleport Home), 🏪 Sell (teleport SellArea).
* Aksi: Klik Home/Sell memicu RemoteEvent `TeleportEvent:FireServer(...)`.

#### Sidebar & BottomBar (Responsif)
* Di PC (Lebar >= 600px): Sidebar vertikal di sebelah kiri layar.
* Di Mobile (Lebar < 600px): Bottom navigation bar horizontal di bawah layar.
* Berisi tombol: Backpack (membuka Inventory), Rewards (membuka Rebirth), Trade (membuka Trade), dan Admin (jika admin).

#### CustomStats & ActiveBuffs (Kanan Atas)
* Kartu Statistik: Berisi 3 baris informasi (Cash, Rebirth Points, Rebirth Level).
* Barisan Buff (di bawah Kartu):
  * Disusun secara horizontal.
  * Setiap buff memiliki Ikon besar (24x24 px) di atas, dan persentase kecil (TextSize = 9) terpusat di bawah ikon.
  * Klik pada Ikon Buff memunculkan balon penjelasan (tooltip) mini di dekatnya dengan teks deskripsi buff.

#### Hotbar & InventoryModal (Bawah Tengah & Tengah Layar)
* Hotbar: Menampilkan slot item aktif dengan ViewportFrame 3D mobil yang berputar secara mulus.
* InventoryModal: Grid item melayang transparan di tengah layar ketika Backpack di-klik. Dilengkapi bar pencarian di atas untuk menyaring item.

#### OpenBoxOverlay (Di atas Hotbar)
* Pemicu: Muncul otomatis saat player melengkapi Box di Backpack/Character.
* Tampilan: Tombol ungu bersinar dengan teks `"Buka Box"`, animasi pulse lembut. Klik memanggil API Networker `openBox`.

---

## 5. Rencana Migrasi & Refactoring

1. **Hapus File Biner:** Hapus semua file `.rbxm` dari direktori `src/StarterGui/`.
2. **Hapus Script Lama:** Hapus/Nonaktifkan script client lama:
   - `SideMenuGui.client.luau`
   - `TopMenuGui.client.luau`
   - `CustomStats.client.luau`
   - `OpenBoxGui.client.luau`
   - `CustomHotbar/init.client.luau`
   - `CustomHotbar/HotbarModule.luau`
3. **Refactor Server Script:** Hapus baris kode manipulasi GUI langsung (`playerGui.OpenBoxGui.OpenBtn.Visible = ...`) dari `BoxManager.luau` and `ServerStorage/Box/Script.server.luau`.
4. **Implementasi Mount & Komponen Baru:** Buat script controller `MountMainHUD.client.luau` and seluruh komponen React di folder `src/StarterPlayer/StarterPlayerScripts/components/MainHUD/`.
5. **Daftarkan Tombol:** Perbarui `MountMainGuiHub.client.luau`, `MountTradeGui.client.luau`, `MountAdminEventPanel.client.luau`, and `Hotbar` untuk mendaftarkan tombol navigasinya ke `RegisterSidebarButton`.

---

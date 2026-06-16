# Rencana Implementasi: Redesain Unified React HUD

Rencana ini memandu proses migrasi dari GUI standar lama (biner `.rbxm`) ke sistem **Unified React HUD** fungsional. Proses harus diikuti tugas-demi-tugas secara konsisten.

---

### Tugas 1: Pembersihan & Refactoring Sisi Server

**File:**
* Modifikasi: `src/ServerScriptService/BoxManager/BoxManager.luau`
* Modifikasi: `src/ServerStorage/Box/Script.server.luau`

- [ ] **Langkah 1: Bersihkan Manipulasi GUI Server di `BoxManager.luau`**
  Hapus referensi langsung ke `PlayerGui.OpenBoxGui.OpenBtn` saat Box di-equip/unequip.
  * Hapus baris 423-433 (pencarian `OpenBoxGui` dan set `Visible = true`).
  * Hapus baris 439-441 (penyembunyian `OpenBtn` saat Unequipped).
  * *Verifikasi:* Pastikan script tidak memicu error ketika Box di-equip secara ingame.

- [ ] **Langkah 2: Bersihkan Manipulasi GUI Server di `Script.server.luau` (Box Template)**
  Hapus referensi manipulasi GUI langsung di dalam script template Box.
  * Hapus baris 274-284 pada event `box.Equipped`.
  * Hapus baris 290-292 pada event `box.Unequipped`.
  * *Verifikasi:* Pastikan script server template Box terbebas dari referensi `OpenBoxGui`.

---

### Tugas 2: Pembersihan Aset GUI Tradisional Lama

- [ ] **Langkah 1: Hapus Semua File UI Biner**
  Hapus file biner `.rbxm` berikut di direktori `src/StarterGui/`:
  * `CustomHotbar.rbxm`
  * `CustomStatsGui.rbxm`
  * `MenuSellGui.rbxm`
  * `NotifGui.rbxm`
  * `OpenBoxGui.rbxm`
  * `SideMenuGui.rbxm`
  * `TopMenuGui.rbxm`
  * *Verifikasi:* Jalankan `git status` dan pastikan semua file di atas ditandai sebagai `deleted`.

- [ ] **Langkah 2: Hapus/Nonaktifkan Script Client Lama**
  Hapus atau kosongkan isi file script client tradisional berikut di `src/StarterPlayer/StarterPlayerScripts/`:
  * `SideMenuGui.client.luau`
  * `TopMenuGui.client.luau`
  * `CustomStats.client.luau`
  * `OpenBoxGui.client.luau`
  * Seluruh folder `CustomHotbar/` (termasuk `init.client.luau` dan `HotbarModule.luau`).

---

### Tugas 3: Implementasi Controller Utama React (`MountMainHUD.client.luau`)

**File Baru:**
* Buat: `src/StarterPlayer/StarterPlayerScripts/MountMainHUD.client.luau`

- [ ] **Langkah 1: Buat Script Mount HUD Utama**
  Tulis kode untuk:
  * Inisialisasi React virtual root baru pada objek `ScreenGui` bernama `"MainHUD"`.
  * Buat `BindableEvent` `"RegisterSidebarButton"` dan `"UnregisterSidebarButton"` di `ReplicatedStorage`.
  * Hubungkan event tersebut ke state manager di dalam komponen React utama.

---

### Tugas 4: Implementasi Komponen React HUD Baru

**File Baru:**
* Buat komponen di dalam direktori `src/StarterPlayer/StarterPlayerScripts/components/MainHUD/`

- [ ] **Langkah 1: Buat Komponen Utama `MainHUD.luau`**
  Komponen induk yang mengontrol state global seperti visibilitas Inventory modal, deteksi orientasi layar (PC vs Mobile), serta daftar tombol sidebar yang terdaftar dinamis.

- [ ] **Langkah 2: Buat Komponen Topbar `Topbar.luau`**
  Merender menu atas (Shop, Home, Sell) di posisi tengah atas layar secara horizontal. Ketika diklik, memicu RemoteEvent `TeleportEvent` atau memicu callback visual.

- [ ] **Langkah 3: Buat Komponen Sidebar `Sidebar.luau`**
  Merender menu samping (untuk layar PC) atau bar navigasi bawah (untuk layar Mobile). Tombol digambar dinamis berdasarkan data yang masuk ke `RegisterSidebarButton`.

- [ ] **Langkah 4: Buat Komponen Statistik `CustomStats.luau`**
  * Merender 3 baris teks di kanan-atas: Uang (Cash), Poin Rebirth (RebirthPoints), dan Tingkat Rebirth (Rebirth Level).
  * Di bawah statistik, buat barisan **Active Buffs** horizontal. Setiap ikon buff melambangkan event aktif (🍀, 🆙, 🌟, ⚡, dll.) dengan persentase di bawahnya.
  * Implementasikan state untuk balon bantuan (tooltip) ketika ikon buff aktif di-klik.

- [ ] **Langkah 5: Buat Komponen Hotbar `Hotbar.luau`**
  Merender slot item di bagian bawah tengah layar (9 slot PC / 5 slot Mobile) lengkap dengan rendering 3D ViewportFrame menggunakan `ViewportManager` untuk mobil yang dipegang.

- [ ] **Langkah 6: Buat Komponen `InventoryModal.luau`**
  Merender grid modal transparan di tengah layar yang menampilkan seluruh sisa item di Backpack player lengkap dengan search filter bar.

- [ ] **Langkah 7: Buat Komponen `OpenBoxOverlay.luau`**
  Tombol melayang tepat di atas Hotbar bertuliskan `"Buka Box"` dengan animasi denyut (*pulse*) premium yang memicu Remote / API Networker `"openBox"` saat diklik.

---

### Tugas 5: Refactoring Integrasi Modul UI Client

**File:**
* Modifikasi: `src/StarterPlayer/StarterPlayerScripts/MountMainGuiHub.client.luau`
* Modifikasi: `src/StarterPlayer/StarterPlayerScripts/MountTradeGui.client.luau`
* Modifikasi: `src/StarterPlayer/StarterPlayerScripts/MountAdminEventPanel.client.luau`

- [ ] **Langkah 1: Integrasikan Rebirth Menu dengan Sidebar Baru**
  Perbarui `MountMainGuiHub.client.luau` agar mendaftarkan tombol `"Rebirth / Rewards"` (menggunakan ikon 🎁 atau 🔄) ke `RegisterSidebarButton` di awal inisialisasi.

- [ ] **Langkah 2: Integrasikan Trade Menu dengan Sidebar Baru**
  Perbarui `MountTradeGui.client.luau` untuk mendaftarkan tombol `"Trade"` (ikon 🤝) jika player memenuhi syarat rebirth >= 5 melalui `RegisterSidebarButton`.

- [ ] **Langkah 3: Integrasikan Admin Event Panel dengan Sidebar Baru**
  Perbarui `MountAdminEventPanel.client.luau` untuk mendaftarkan tombol `"Admin Event"` (ikon ⚙️) jika player memiliki hak akses admin ke `RegisterSidebarButton`.

- [ ] **Langkah 4: Jalankan Linter & Verifikasi Akhir**
  Jalankan `luau-analyze-rojo` untuk memastikan tidak ada kesalahan penulisan (*syntax error*) di semua file yang baru dibuat dan dimodifikasi.

---

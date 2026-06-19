# Rencana Implementasi: Modularisasi Client & Bootstrapper Terpusat

Rencana implementasi ini dirancang berdasarkan dokumen spesifikasi desain pada [2026-06-19-client-modularization-loader-design.md](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/docs/superpowers/specs/2026-06-19-client-modularization-loader-design.md). Dokumen ini memetakan langkah-langkah kerja untuk mengubah 15 client script terpisah menjadi ModuleScript dan memuatnya secara teratur melalui loader `MainClient.client.luau`.

---

## Task 1: Buat Loader Utama (`MainClient.client.luau`)
**File:** `src/StarterPlayer/StarterPlayerScripts/MainClient.client.luau` (baru)

### Langkah:
1. Buat file baru bernama `MainClient.client.luau` di folder `src/StarterPlayer/StarterPlayerScripts/`.
2. Isi file tersebut dengan kode bootstrapper sekuensial hibrida yang membagi pemuatan menjadi kelompok `CORE_MODULES` (sinkron) dan `FEATURE_MODULES` (asinkron).
3. Pastikan penanganan error menggunakan `pcall` dan pelacakan log kesalahan (`warn`) diimplementasikan sepenuhnya.

---

## Task 2: Konversi & Wrapper Modul Client (15 Modul)
**Lokasi Folder:** `src/StarterPlayer/StarterPlayerScripts/`

Untuk setiap file di bawah ini, lakukan:
1. Ganti nama file dari `NamaFile.client.luau` menjadi `NamaFile.luau` agar Rojo mengompilasinya menjadi **ModuleScript** di Roblox Studio.
2. Bungkus isi kode asli di dalam template modul standar:
   ```lua
   local Module = {}
   function Module.init()
       -- [Kode logika asli]
   end
   return Module
   ```

### Daftar File Modul yang Dikonversi:
1.  **`ScreenOrientation`**: Ganti nama `ScreenOrientation.client.luau` $\rightarrow$ `ScreenOrientation.luau` dan tambahkan wrapper modul.
2.  **`NotifHandlerGui`**: Ganti nama `NotifHandlerGui.client.luau` $\rightarrow$ `NotifHandlerGui.luau` dan tambahkan wrapper modul.
3.  **`ChatAnnounceHandler`**: Ganti nama `ChatAnnounceHandler.client.luau` $\rightarrow$ `ChatAnnounceHandler.luau` dan tambahkan wrapper modul.
4.  **`ChatTags`**: Ganti nama `ChatTags.client.luau` $\rightarrow$ `ChatTags.luau` dan tambahkan wrapper modul.
5.  **`OverheadClient`**: Ganti nama `OverheadClient.client.luau` $\rightarrow$ `OverheadClient.luau` dan tambahkan wrapper modul.
6.  **`ShopGui`**: Ganti nama `ShopGui.client.luau` $\rightarrow$ `ShopGui.luau` dan tambahkan wrapper modul.
7.  **`SellGui`**: Ganti nama `SellGui.client.luau` $\rightarrow$ `SellGui.luau` dan tambahkan wrapper modul.
8.  **`MenuSellGui`**: Ganti nama `MenuSellGui.client.luau` $\rightarrow$ `MenuSellGui.luau` dan tambahkan wrapper modul.
9.  **`UpgradeMachineArea`**: Ganti nama `UpgradeMachineArea.client.luau` $\rightarrow$ `UpgradeMachineArea.luau` dan tambahkan wrapper modul.
10. **`AnnouncementGui`**: Ganti nama `AnnouncementGui.client.luau` $\rightarrow$ `AnnouncementGui.luau` dan tambahkan wrapper modul.
11. **`MountMainHUD`**: Ganti nama `MountMainHUD.client.luau` $\rightarrow$ `MountMainHUD.luau` dan tambahkan wrapper modul.
12. **`MountMainGuiHub`**: Ganti nama `MountMainGuiHub.client.luau` $\rightarrow$ `MountMainGuiHub.luau` dan tambahkan wrapper modul.
13. **`MountAdminEventPanel`**: Ganti nama `MountAdminEventPanel.client.luau` $\rightarrow$ `MountAdminEventPanel.luau` dan tambahkan wrapper modul.
14. **`MountRacePanel`**: Ganti nama `MountRacePanel.client.luau` $\rightarrow$ `MountRacePanel.luau` dan tambahkan wrapper modul.
15. **`MountTradeGui`**: Ganti nama `MountTradeGui.client.luau` $\rightarrow$ `MountTradeGui.luau` dan tambahkan wrapper modul.

---

## Task 3: Verifikasi Fungsionalitas & Log Hasil
Lakukan pengujian akhir setelah proses konversi selesai:
1.  **Cek Kompilasi Rojo:** Pastikan Rojo berhasil mendeteksi perubahan nama file dan mengunggahnya sebagai instansi `ModuleScript` ke Roblox Studio.
2.  **Cek Dev Console (F9):** Jalankan game di Studio atau server lokal, cari log:
    *   `[MainClient] Memulai inisialisasi seluruh sistem client...`
    *   `[MainClient] ✅ Seluruh modul client berhasil dijadwalkan / dimuat!`
    *   Pastikan tidak ada pesan error `❌ Gagal...` dari loader.
3.  **Pengujian Fitur UI & Jaringan:** Pastikan warning *"Infinite yield"* dari `NetworkerClient` tidak muncul lagi pada saat awal memuat modul panel. Verifikasi bahwa UI Toko, Hotbar, dan fitur game lainnya tetap berjalan normal dan responsif.

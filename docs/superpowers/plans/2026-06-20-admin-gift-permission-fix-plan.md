# Rencana Implementasi: Perbaikan Izin Gift Admin Car

Rencana ini berisi langkah-langkah terperinci untuk mengubah validasi hak akses pada fungsi `getAdminCars` di server agar menggunakan `RoleManager.hasPermission`.

---

## Tugas 1: Memperbarui Pemeriksaan Izin Server-Side
Lokasi File: [EventManager.luau](file:///C:/Project/Roblox Studio Projects/Projects/F1-Tycoon/src/ServerScriptService/EventManager/EventManager.luau)

- [ ] **Langkah 1: Perbarui Validasi Izin di `AdminEventService:getAdminCars`**
  Cari deklarasi fungsi `AdminEventService:getAdminCars` di [EventManager.luau](file:///C:/Project/Roblox Studio Projects/Projects/F1-Tycoon/src/ServerScriptService/EventManager/EventManager.luau#L353).
  Ubah baris 354-361:
  ```luau
	local RoleConfig = require(ReplicatedStorage:WaitForChild("RoleConfig"))
	local playerRole = (player:GetAttribute("Role") :: string?) or "Player"
	local roleData = (RoleConfig.Roles :: any)[playerRole]

	if not roleData or not roleData.Permissions["EditGameConfigs"] then
  ```
  Menjadi:
  ```luau
	if not RoleManager.hasPermission(player, "EditGameConfigs") then
  ```
  Ini akan mendelegasikan pengecekan hak akses secara penuh dan benar ke `RoleManager`, yang menangani array izin pemain dengan benar dan mendukung bypass untuk `Owner` dan `Developer`.

---

## Tugas 2: Pengujian & Verifikasi Akhir
- [ ] **Langkah 1: Jalankan Mode Pengujian Studio**
  Buka game di Roblox Studio (menjadikan Anda sebagai `Owner` otomatis).
- [ ] **Langkah 2: Validasi Dropdown Admin Car**
  Tekan `F4` untuk membuka **Admin Event Panel**.
  Buka tab **Gifts** (Hadiah).
  Klik dropdown **"Pilih Admin Car..."**.
  Pastikan dropdown memuat nama mobil `"Paindre Edition"` (tidak menampilkan "Tidak ada admin car").
  Pastikan tidak ada warning error permission di Server Console.
- [ ] **Langkah 3: Validasi Pengiriman Gift Admin Car**
  Pilih target nama player Anda sendiri, pilih `"Paindre Edition"`, lalu klik tombol **"GIFT ADMIN CAR"**.
  Pastikan mobil admin dikloning dan dimasukkan ke Backpack Anda dengan benar.

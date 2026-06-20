# Rencana Implementasi: Sistem Spawner Box Multi-Lokasi

Rencana ini membagi tugas untuk menambahkan spawner multi-box menggunakan folder `Locations` dan memperbarui penyimpanan data di server.

---

## Tugas 1: Memperbarui Penyimpanan Data (Server-Side)
Lokasi File: [DataManager.luau](file:///C:/Project/Roblox Studio Projects/Projects/F1-Tycoon/src/ServerScriptService/DataManager/DataManager.luau)

- [ ] **Langkah 1: Ubah Pemindaian Box Aktif di `extractMachineData`**
  Cari fungsi `extractMachineData` di [DataManager.luau](file:///C:/Project/Roblox Studio Projects/Projects/F1-Tycoon/src/ServerScriptService/DataManager/DataManager.luau#L125).
  Ubah bagian pemindaian activeBox agar men-scan seluruh box tool aktif dan menyimpannya dalam array `ActiveBoxes` yang berisi level, exp, varian, dan nama lokasi spawn-nya.

---

## Tugas 2: Memperbarui Spawner Logic (Server-Side)
Lokasi File: [SpawnerBoxManager.luau](file:///C:/Project/Roblox Studio Projects/Projects/F1-Tycoon/src/ServerScriptService/SpawnerBoxManager/SpawnerBoxManager.luau)

- [ ] **Langkah 1: Perbarui Parameter `spawnBox`**
  Ubah deklarasi fungsi `spawnBox` agar menerima parameter `locationName: string?`.
  Tambahkan pengecekan apakah lokasi spesifik sudah terisi sebelum men-spawn box. Setel atribut `SpawnLocationName = locationName` pada box yang baru di-spawn.
- [ ] **Langkah 2: Perbarui Inisialisasi Lokasi `boxPosition`**
  Di dalam fungsi `startLogic`, ganti pengecekan hardcode area `"AthenaArea"` dengan pemindaian dinamis folder `Locations` di dalam folder area mesin.
- [ ] **Langkah 3: Perbarui Logika Loop Spawning di `startLogic`**
  Ubah logika loop utama spawner agar memindai lokasi kosong secara berkala. Setel `IsRunning` menjadi `true` hanya jika tidak ada lokasi kosong tersisa. Pemicu `spawnBox` hanya akan dikirim untuk lokasi yang kosong.
- [ ] **Langkah 4: Modifikasi Akhir Growth Loop**
  Sesuaikan logika reset state di akhir growth loop box agar tidak memblokir respawn spawner lain jika ada lokasi yang kosong pada spawner multi-lokasi.

---

## Tugas 3: Pengujian & Verifikasi Akhir
- [ ] **Langkah 1: Pengujian Spawn Awal**
  Pastikan box di-spawn di seluruh part lokasi yang terdaftar di folder `Locations`.
- [ ] **Langkah 2: Pengujian Respawn Dinamis**
  Ambil salah satu box dan pastikan box baru muncul kembali hanya di posisi lokasi yang kosong.
- [ ] **Langkah 3: Pengujian Data Persistence (Save/Load)**
  Pastikan data box tersimpan dan termuat kembali dengan benar di posisi awalnya saat keluar/masuk game.

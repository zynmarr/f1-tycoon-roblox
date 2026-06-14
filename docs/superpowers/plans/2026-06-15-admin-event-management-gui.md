# Rencana Implementasi: Admin Event Management GUI

Dokumen ini berisi langkah-langkah detail untuk mengimplementasikan fitur GUI Panel Manajemen Event khusus Admin.

---

## 📋 Daftar Tugas (Todo List)

- [ ] **Tugas 1: Peningkatan Backend Server (`EventManager.server.luau`)**
  * Membuat parameter IntValue baru untuk variant-specific boosts (`VariantBoost_Golden`, `VariantBoost_Rainbow`, `VariantBoost_Galaxy`, `VariantBoost_Hellfire`) di dalam folder `LiveEvents`.
  * Membuat Networker service server baru (`AdminEventService`) dengan fungsi `setEventValues` (dengan clamping ketat) dan `stopAllEvents`.
  * Mempertahankan legacy chat commands sebagai fallback.
  * *Verifikasi*: Jalankan server dan pastikan IntValue baru berhasil dibuat di `ReplicatedStorage.LiveEvents`.

- [ ] **Tugas 2: Integrasi Gacha Chance (`SpawnerBoxManager.luau`)**
  * Membaca nilai boost spesifik varian dari `LiveEvents` (`VariantBoost_Golden`, dll.).
  * Menambahkan nilai boost ini ke perhitungan `totalChance` saat spawner box menentukan varian box.
  * *Verifikasi*: Uji secara manual/simulasi bahwa meningkatkan nilai `VariantBoost_Golden` di server menaikkan frekuensi kemunculan Golden box.

- [ ] **Tugas 3: Membuat Komponen React (`AdminEventPanel.luau`)**
  * Membuat file baru `src/StarterPlayer/StarterPlayerScripts/components/AdminEventPanel/AdminEventPanel.luau`.
  * Merancang UI modern dark theme (glassmorphism) berisi panel kontrol kiri (Luck, EXP, Speed, Global Variant, Accordion untuk spesifik variant boost, tombol STOP ALL, tombol APPLY) dan panel kanan (Live Status monitor & Preset buttons).
  * *Verifikasi*: Pastikan komponen React terkompilasi tanpa error sintaksis.

- [ ] **Tugas 4: Integrasi & Pemicu UI (`MountAdminEventPanel.client.luau`)**
  * Membuat file controller klien baru di `src/StarterPlayer/StarterPlayerScripts/MountAdminEventPanel.client.luau`.
  * Memeriksa permission pemain (`EditGameConfigs`) secara lokal berdasarkan role pemain.
  * Menyuntikkan tombol bulat "⚙️ Panel Event" secara dinamis ke dalam `SideMenuGui.MainContainer` milik admin.
  * Menghubungkan tombol tersebut untuk melakukan *toggle* (buka/tutup) ScreenGui `AdminEventGui` yang merender React `AdminEventPanel`.
  * *Verifikasi*: Masuk sebagai admin, pastikan tombol muncul di menu samping dan panel GUI terbuka saat tombol diklik.

---

## 🛠️ Detail Langkah Implementasi

### Tugas 1: Peningkatan Backend Server (`EventManager.server.luau`)
1. Di `EventManager.server.luau`, setelah baris pembuatan `expBoost` (baris 28), tambahkan pembuatan parameter `IntValue` baru:
   ```lua
   local goldenBoost = Instance.new("IntValue")
   goldenBoost.Name = "VariantBoost_Golden"
   goldenBoost.Value = 0
   goldenBoost.Parent = liveEvents

   local rainbowBoost = Instance.new("IntValue")
   rainbowBoost.Name = "VariantBoost_Rainbow"
   rainbowBoost.Value = 0
   rainbowBoost.Parent = liveEvents

   local galaxyBoost = Instance.new("IntValue")
   galaxyBoost.Name = "VariantBoost_Galaxy"
   galaxyBoost.Value = 0
   galaxyBoost.Parent = liveEvents

   local hellfireBoost = Instance.new("IntValue")
   hellfireBoost.Name = "VariantBoost_Hellfire"
   hellfireBoost.Value = 0
   hellfireBoost.Parent = liveEvents
   ```
2. Impor `Networker` di bagian atas file jika belum ada.
3. Buat service server `AdminEventService` menggunakan `Networker`:
   ```lua
   local AdminEventService = {}

   function AdminEventService:setEventValues(player, values)
       if not RoleManager.hasPermission(player, "EditGameConfigs") then
           return { Success = false, Error = "Akses Ditolak!" }
       end
       if typeof(values) ~= "table" then
           return { Success = false, Error = "Parameter tidak valid" }
       end

       -- Clamping ketat di server untuk keamanan
       variantBoost.Value = math.clamp(values.VariantBoost or 0, 0, 100)
       luckBoost.Value = math.clamp(values.LuckBoost or 0, 0, 500)
       expBoost.Value = math.clamp(values.ExpBoost or 0, 0, 500)
       ReplicatedStorage:SetAttribute("SpeedBoost", math.clamp(values.SpeedBoost or 0, 0, 100))

       goldenBoost.Value = math.clamp(values.VariantBoost_Golden or 0, 0, 50)
       rainbowBoost.Value = math.clamp(values.VariantBoost_Rainbow or 0, 0, 50)
       galaxyBoost.Value = math.clamp(values.VariantBoost_Galaxy or 0, 0, 50)
       hellfireBoost.Value = math.clamp(values.VariantBoost_Hellfire or 0, 0, 50)

       print(string.format("[EVENT] ⚙️ Event values updated by Admin %s", player.Name))
       return { Success = true, Message = "Konfigurasi event berhasil diperbarui!" }
   end

   function AdminEventService:stopAllEvents(player)
       if not RoleManager.hasPermission(player, "EditGameConfigs") then
           return { Success = false, Error = "Akses Ditolak!" }
       end

       variantBoost.Value = 0
       luckBoost.Value = 0
       expBoost.Value = 0
       ReplicatedStorage:SetAttribute("SpeedBoost", 0)

       goldenBoost.Value = 0
       rainbowBoost.Value = 0
       galaxyBoost.Value = 0
       hellfireBoost.Value = 0

       print(string.format("[EVENT] 🛑 All events stopped by Admin %s", player.Name))
       return { Success = true, Message = "Semua event berhasil dimatikan!" }
   end

   -- Inisialisasi Networker Service
   local Networker = require(ReplicatedStorage.Packages.Networker)
   Networker.server.new("AdminEventService", AdminEventService, {
       AdminEventService.setEventValues,
       AdminEventService.stopAllEvents,
   })
   ```

### Tugas 2: Integrasi Gacha Chance (`SpawnerBoxManager.luau`)
1. Buka `src/ServerScriptService/SpawnerBoxManager/SpawnerBoxManager.luau`.
2. Cari bagian pencarian peluang varian (di dalam loop di mana `globalVariantBoost` didapatkan).
3. Ubah perhitungan `totalChance` menjadi:
   ```lua
   -- Cari boost spesifik untuk varian ini dari LiveEvents
   local specVariantBoost = 0
   local specVariantNode = liveEvents:FindFirstChild("VariantBoost_" .. vName)
   if specVariantNode then
       specVariantBoost = specVariantNode.Value
   end

   local totalChance = vData.Chance + specUpgrade + allUpgrade + globalVariantBoost + specVariantBoost
   ```

### Tugas 3: Komponen React (`AdminEventPanel.luau`)
1. Buat folder baru jika belum ada: `src/StarterPlayer/StarterPlayerScripts/components/AdminEventPanel/`.
2. Buat file `AdminEventPanel.luau`.
3. Buat UI dengan layout kolom responsif:
   * Sisi kiri: Form input berupa slider + text box untuk input angka presisi untuk Luck, EXP, Speed, Global Variant, Golden, Rainbow, Galaxy, Hellfire.
   * Accordion untuk melipat input varian spesifik agar panel tetap bersih.
   * Tombol "APPLY CHANGES" dan "STOP ALL EVENTS".
   * Sisi kanan: Status Live Monitor yang menampilkan nilai event yang sedang aktif di `ReplicatedStorage.LiveEvents` secara reaktif + 3 tombol Preset instan (Double EXP, Lucky Hype, Weekend Boost).

### Tugas 4: Integrasi & Pemicu UI (`MountAdminEventPanel.client.luau`)
1. Buat file `src/StarterPlayer/StarterPlayerScripts/MountAdminEventPanel.client.luau`.
2. Lakukan pengecekan permission pemain:
   ```lua
   local RoleConfig = require(game.ReplicatedStorage:WaitForChild("RoleConfig"))
   local playerRole = player:GetAttribute("Role") or "Player"
   local roleData = RoleConfig.Roles[playerRole]
   local hasPermission = false
   if playerRole == "Owner" or playerRole == "Developer" then
       hasPermission = true
   elseif roleData then
       hasPermission = table.find(roleData.Permissions, "EditGameConfigs") ~= nil
   end
   ```
3. Jika `hasPermission == true`, cari `SideMenuGui.MainContainer` dan tambahkan tombol bulat "⚙️ Panel Event" baru secara dinamis.
4. Klik tombol tersebut akan mengubah `.Enabled` dari ScreenGui `AdminEventGui` dan merender/unmount `AdminEventPanel`.

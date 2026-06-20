# Design Spec: Perbaikan Izin Gift Admin Car

**Masalah:** Pilihan admin car pada Admin Event Panel menampilkan "Tidak ada admin car" dan mencetak warning di Server Console (`[EventManager] Player ... mencoba mengambil list admin car tanpa permission!`) saat player mencoba membuka dropdown admin car, meskipun player memiliki akses admin (seperti Owner atau Developer).

**Penyebab:** Pada file `EventManager.luau` di fungsi `AdminEventService:getAdminCars`, server melakukan pengecekan izin menggunakan `roleData.Permissions["EditGameConfigs"]`. Namun, `Permissions` pada `RoleConfig.luau` didefinisikan sebagai array/list string (contoh: `{"EditGameConfigs", ...}`), bukan dictionary. Akibatnya, pengecekan tersebut selalu menghasilkan nilai `nil`.

---

## 1. Solusi Desain

Kita akan mengganti baris pengecekan manual tersebut di `EventManager.luau` dengan menggunakan fungsi pemeriksaan izin terpusat yang sudah ada:
```luau
if not RoleManager.hasPermission(player, "EditGameConfigs") then
```
Fungsi `RoleManager.hasPermission` menggunakan `table.find` untuk memindai array izin pemain dengan benar dan otomatis meloloskan (bypass) role `Owner` dan `Developer`.

---

## 2. Rincian Perubahan Kode

### 2.1. `src/ServerScriptService/EventManager/EventManager.luau`
Ubah fungsi `AdminEventService:getAdminCars` untuk menggunakan `RoleManager.hasPermission`:

```diff
 function AdminEventService:getAdminCars(player: Player): { { Name: string } }
-	local RoleConfig = require(ReplicatedStorage:WaitForChild("RoleConfig"))
-	local playerRole = (player:GetAttribute("Role") :: string?) or "Player"
-	local roleData = (RoleConfig.Roles :: any)[playerRole]
-
-	if not roleData or not roleData.Permissions["EditGameConfigs"] then
+	if not RoleManager.hasPermission(player, "EditGameConfigs") then
 		warn("[EventManager] Player " .. player.Name .. " mencoba mengambil list admin car tanpa permission!")
 		return {}
 	end
```

---

## 3. Rencana Pengujian (Testing Plan)

1. **Pengujian Izin di Roblox Studio**:
   - Jalankan test play di Roblox Studio (pemain lokal akan otomatis mendapatkan role `Owner`).
   - Tekan `F4` untuk membuka **Admin Event Panel**.
   - Masuk ke tab **Gifts** (Hadiah).
   - Klik dropdown pada bagian **"Pilih Admin Car..."**.
   - **Hasil yang Diharapkan**: List admin car memuat `"Paindre Edition"` dan tidak ada log warning "tanpa permission" di Output/Server Console.
2. **Pengujian Pengiriman Gift**:
   - Pilih target player (misal: `"All"` atau nama Anda sendiri).
   - Pilih `"Paindre Edition"` di dropdown admin car.
   - Klik tombol **"GIFT ADMIN CAR"**.
   - **Hasil yang Diharapkan**: Mobil `"Paindre Edition"` masuk ke Backpack pemain target, dengan atribut `Rarity = "Admin"` dan `Variant = "Admin"`.

# Hasil Analisis dan Pemeriksaan Menyeluruh Proyek F1-Tycoon

Dokumen ini merangkum seluruh temuan dari pemeriksaan mendalam (deep audit) terhadap kode server, client, konfigurasi, dan utilitas pada proyek **F1-Tycoon**.

Kami menemukan beberapa **bug kritis**, **kerentanan logika**, **potensi kebocoran memori (memory leak)**, dan **celah keamanan** yang harus segera ditangani untuk menjamin stabilitas permainan dan keselamatan data pemain.

---

## 🔍 Temuan Masalah & Analisis Detail

### 1. 💾 Kerentanan Rollback Data Pemain (Kritis)
* **Lokasi**: [DataManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/DataManager/DataManager.luau) & [Main.server.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/Main.server.luau)
* **Deskripsi Masalah**:
  ProfileService memiliki mekanisme autosave otomatis setiap 30 detik untuk mengamankan data yang berada di dalam `profile.Data`. Namun, `profile.Data` di server game ini **hanya diperbarui** ketika pemain keluar dari game (`DataManager.saveData()`). 
  Jika server crash, mati mendadak, atau pemain terputus secara tidak normal tanpa memicu event `PlayerRemoving` dengan sempurna, data terbaru pemain di workspace (Cash terbaru, upgrade, mobil, inventori) tidak akan pernah tersinkronisasi ke `profile.Data`. Akibatnya, data pemain akan **mengalami rollback total** ke kondisi awal saat mereka masuk ke server di sesi tersebut.
* **Solusi**:
  1. Ditambahkan fungsi `DataManager.syncData(player)` untuk membaca nilai stats, backpack, dan plot aktual ke `profile.Data` tanpa melakukan *release* profil (menutup sesi kunci).
  2. Fungsi `saveData(player)` diubah untuk memanggil `syncData(player)` sebelum melepas sesi kunci (`profile:Release()`).
  3. Dibuat loop autosave berkala (setiap 60 detik) di `Main.server.luau` untuk memanggil `DataManager.syncData(player)` bagi seluruh pemain aktif di server.

---

### 2. 🧠 Kebocoran Memori Viewport UI Client (Memory Leak)
* **Lokasi**: [ViewportManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/StarterPlayer/StarterPlayerScripts/components/ViewportManager.luau#L45-L55)
* **Deskripsi Masalah**:
  Mekanisme pemangkasan cache (`trimCache`) bertujuan agar jumlah model 3D yang disimpan di cache client tidak melebihi batas `MAX_CACHE_SIZE = 10`. Namun, kondisinya ditulis seperti ini:
  ```lua
  if #cache.renderCache > cache.MAX_CACHE_SIZE then
  ```
  Di dalam Lua/Luau, operator panjang `#` hanya bekerja untuk tabel bertipe array dengan indeks integer berurutan. Karena `cache.renderCache` menggunakan objek `Tool` (Instance) sebagai key (sehingga bertindak sebagai *dictionary*), nilai `#cache.renderCache` akan **selalu mengembalikan 0**.
  Akibatnya, kondisi trim cache tidak pernah bernilai `true` dan pembersihan model/kamera yang lama (`clearCacheEntry`) tidak pernah dieksekusi. Cache akan terus menumpuk tanpa batas seiring waktu saat pemain membuka-buka daftar garasi atau hotbar, menyebabkan kebocoran memori (RAM) pada client.
* **Solusi**:
  Diubah metode pengukuran ukuran dictionary dengan melakukan iterasi hitung manual:
  ```lua
  local function trimCache(cache)
      local count = 0
      for _ in pairs(cache.renderCache) do
          count = count + 1
      end
      if count > cache.MAX_CACHE_SIZE then
          local excess = count - cache.MAX_CACHE_SIZE
          local removed = 0
          for key in pairs(cache.renderCache) do
              clearCacheEntry(cache, key)
              removed = removed + 1
              if removed >= excess then
                  break
              end
          end
      end
  end
  ```

---

### 3. 🛡️ Kerentanan Penghancuran Item & Keamanan Transaksi Penjualan (Kritis)
* **Lokasi**: [SellGuiServer.server.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/SellGuiServer.server.luau#L16-L239)
* **Deskripsi Masalah**:
  Ada dua masalah keamanan dan logika serius pada sistem penjualan:
  * **Hancurnya Box Secara Tidak Sengaja**: Pada fungsi `sellCar`, server memanggil `car:Destroy()` **sebelum** melakukan validasi harga (`harga <= 0`). Jika pemain secara tidak sengaja memicu transaksi penjualan untuk item non-mobil (misalnya `Box` yang tidak memiliki atribut `Price`), nilai `harga` akan bernilai `0`. Server akan menolak transaksi dengan error `"Harga mobil tidak valid"`, tetapi objek box milik pemain **sudah terlanjur dihancurkan secara permanen**!
  * **Pemberantasan Inventori pada Sell All**: Pada fungsi `sellAllCars`, server menerima daftar item dari client dan menghancurkannya secara mutlak (`car:Destroy()`) di akhir loop tanpa memeriksa apakah item tersebut benar-benar sebuah mobil. Jika client mengirimkan daftar yang berisi box, seluruh box di tas pemain akan dihapus tanpa memberikan kompensasi Cash sepeser pun.
* **Solusi**:
  1. Validasi jenis item ditambahkan menggunakan `GameUtils.isCar(car)` di awal fungsi `sellCar` and `sellAllCars` agar menolak mentah-mentah jika item tersebut bukan mobil.
  2. Pada `sellCar`, pengambilan harga dan validasi dipindahkan **sebelum** memanggil `:Destroy()`.
  3. Pada `sellAllCars`, loop penyaringan hanya memproses dan menghancurkan item jika `GameUtils.isCar(car)` bernilai `true`.

---

### 4. 📦 Bug Stacking Kotak saat Di-equip (OnHand)
* **Lokasi**: [BoxManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/BoxManager/BoxManager.luau#L170-L195)
* **Deskripsi Masalah**:
  Saat pemain mengambil kotak dari spawner, sistem stacking mengecek apakah pemain sudah memiliki kotak bertipe sama menggunakan baris berikut:
  ```lua
  local backpack = player:FindFirstChild("Backpack")
  local existingBox = backpack and backpack:FindFirstChild(box.Name)
  ```
  Di Roblox, ketika pemain meng-equip (memegang) suatu `Tool` di tangan, objek Tool tersebut secara otomatis dipindahkan oleh engine dari folder `Backpack` ke dalam folder `Character` milik pemain.
  Jika pemain sedang memegang kotak tipe A di tangan lalu mengambil kotak tipe A baru dari mesin, server hanya mencari kotak di `Backpack` dan gagal menemukannya. Kotak baru tersebut kemudian dimasukkan sebagai item baru yang terpisah alih-alih ditumpuk ke dalam `Stacks`, merusak sistem tumpukan kotak.
* **Solusi**:
  Pencarian `existingBox` diperluas ke folder `Character` pemain:
  ```lua
  local backpack = player:FindFirstChild("Backpack")
  local existingBox = (backpack and backpack:FindFirstChild(box.Name)) or (player.Character and player.Character:FindFirstChild(box.Name))
  ```

---

### 5. 🎒 Bypass Batas Slot Inventori (Tas) pada Pickup Box
* **Lokasi**: [BoxManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/BoxManager/BoxManager.luau#L143-L195)
* **Deskripsi Masalah**:
  Batas maksimal kapasitas inventori (`GameConfig.MaxInventorySlots = 50`) hanya divalidasi ketika pemain mencoba **membuka** kotak (`openBox`). 
  Tidak ada pemeriksaan kapasitas sama sekali pada fungsi pengambilan kotak fisik dari tanah (`processPickup`). Pemain dapat mengambil kotak tanpa batasan dari spawner mereka dan menumpuk ratusan kotak unik di tas mereka, melewati batasan game yang seharusnya.
* **Solusi**:
  Tambahkan pengecekan kapasitas tas sebelum kotak diambil ke Backpack di dalam `processPickup`. Jika tas sudah penuh dan kotak tersebut **tidak akan menumpuk** (bukan item yang sudah dimiliki), batalkan pickup, biarkan ProximityPrompt tetap aktif, dan kirimkan notifikasi ke client:
  ```lua
  local inventoryCount = backpack and #backpack:GetChildren() or 0
  local maxInventorySlots = GameConfig.MaxInventorySlots or 50

  if not existingBox and inventoryCount >= maxInventorySlots then
      local NotifEvent = ReplicatedStorage:FindFirstChild("NotifEvent")
      if NotifEvent then
          NotifEvent:FireClient(player, "Tas Penuh", "Tas Anda sudah penuh! (" .. inventoryCount .. "/" .. maxInventorySlots .. " slot)", 3)
      end
      return
  end
  ```

---

### 6. 🔓 Bug Spawner Tertahan (Spawner Lock Bug)
* **Lokasi**: [BoxManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/BoxManager/BoxManager.luau#L163-L168) & [SpawnerBoxManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/SpawnerBoxManager/SpawnerBoxManager.luau#L64-L140)
* **Deskripsi Masalah**:
  Di `BoxManager.luau` pada fungsi `processPickup`, terdapat logika untuk langsung membuka kembali status mesin spawner agar bisa memproses spawn baru segera setelah box diambil:
  ```lua
  local sourceMachine = box:FindFirstChild("SourceMachine") :: ObjectValue?
  if sourceMachine and sourceMachine.Value then
      local machineArea = sourceMachine.Value
      machineArea:SetAttribute("IsRunning", false)
  end
  ```
  Namun, pada `SpawnerBoxManager.luau` saat melakukan cloning/spawning box, **sistem tidak pernah membuat objek `SourceMachine` (ObjectValue)** di dalam model box tersebut! Objek box hanya diberi attribute string `"MachineSource" = machineArea.Name`.
  Hal ini menyebabkan `FindFirstChild("SourceMachine")` selalu mengembalikan `nil`. Akibatnya, mesin spawner tidak pernah langsung terbuka status kuncinya saat box diambil. Mesin baru akan terbuka ketika loop pertumbuhan utama di server terbangun dari jeda `task.wait()` dan menyadari box sudah tidak berada di mesin lagi, yang bisa memakan waktu hingga beberapa detik.
* **Solusi**:
  Pada `SpawnerBoxManager.luau` fungsi `spawnBox`, ditambahkan instansiasi dan penautan `ObjectValue` bernama `"SourceMachine"` ke dalam box baru:
  ```lua
  local sourceMachineVal = Instance.new("ObjectValue")
  sourceMachineVal.Name = "SourceMachine"
  sourceMachineVal.Value = machineArea
  sourceMachineVal.Parent = newBox
  ```

---

### 7. 💥 Potensi Crash Pemuatan Sesi Parkir (ProximityPrompt Nil)
* **Lokasi**: [ParkingAreaManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/ParkingAreaManager/ParkingAreaManager.luau#L28-L72)
* **Deskripsi Masalah**:
  Fungsi `storeCarToArea` langsung mengambil objek `ProximityPrompt` dan menulis atribut padanya:
  ```lua
  local prompt = area:FindFirstChild("ProximityPrompt") :: ProximityPrompt
  ...
  prompt:SetAttribute("IsActive", true)
  ```
  Jika area parkir tertentu tidak memiliki `ProximityPrompt` (atau belum sempat ter-load karena masalah replikasi), pemanggilan `prompt:SetAttribute(...)` akan melempar error `attempt to index nil with 'SetAttribute'` dan menghentikan thread secara total. Karena fungsi ini dipanggil saat pemain pertama kali bergabung untuk memuat mobil cadangan mereka (`spawnLoadedCar`), crash ini akan merusak alur inisialisasi join pemain.
* **Solusi**:
  Ditambahkan validasi pengaman (nil check) sebelum mengakses properti atau atribut `prompt`:
  ```lua
  if prompt then
      prompt:SetAttribute("IsActive", true)
  end
  ```

---

### 8. ✉️ Ketidakcocokan Tipe Data Event Notifikasi
* **Lokasi**: [NotifHandlerGui.client.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/StarterPlayer/StarterPlayerScripts/NotifHandlerGui.client.luau#L13-L21)
* **Deskripsi Masalah**:
  Client mendengarkan event dengan parameter string:
  ```lua
  notifEvent.OnClientEvent:Connect(function(judul, pesan, durasi)
  ```
  Tetapi pada implementasi saran perbaikan sebelumnya, event dipanggil dengan format satu parameter bertipe tabel: `FireClient(player, { Type = "Error", Text = "..." })`. Format ini akan memicu error konversi tipe data pada client dan notifikasi tidak akan muncul di layar pemain.
* **Solusi**:
  Gunakan pemanggilan sesuai tanda tangan fungsi client:
  ```lua
  NotifEvent:FireClient(player, "Nama Judul", "Pesan Notifikasi", durasi)
  ```

---

### 9. 🏎️ Refaktorisasi Event Upgrade Mesin ke API Networker (Permintaan Pengguna)
* **Lokasi**: [SpawnerBoxManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/SpawnerBoxManager/SpawnerBoxManager.luau) & [UpgradeMachineArea.client.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/StarterPlayer/StarterPlayerScripts/UpgradeMachineArea.client.luau)
* **Deskripsi Masalah**:
  Sebelumnya, sistem pembelian upgrade mesin dari client ke server menggunakan RemoteFunction bawaan Roblox (`BuyUpgradeFunction`).
  Untuk menjaga keseragaman arsitektur komunikasi (seperti sistem `OpenBox`), event ini dimigrasikan menggunakan library Networker yang lebih modern, aman, dan modular.
* **Solusi**:
  1. Di sisi Server (`SpawnerBoxManager.luau`), RemoteFunction `BuyUpgradeFunction` dihapus. Dibuat method baru `SpawnerBoxManager:buyUpgrade(player, machineArea, upgradeName)` yang mengembalikan tabel `{ Success = boolean, Error = string?, Message = string? }`. Method ini didaftarkan di bawah Networker channel `"UpgradeMachine"`.
  2. Di sisi Client (`UpgradeMachineArea.client.luau`), panggilan `BuyUpgradeFunction:InvokeServer(...)` diganti menggunakan `networker:fetch("buyUpgrade", machineArea, item.Name)` dan respons dibaca dengan benar dari field `.Success` dan `.Error`.

---

### 10. 📦 Bug Mismatch Amount Box saat Muat Data Game (Kritis)
* **Lokasi**: [Main.server.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/Main.server.luau#L61-L78)
* **Deskripsi Masalah**:
  Ketika data inventori pemain dimuat saat masuk game (`loadInventoryItem`), server mengkloning template box dari ServerStorage dan menerapkan seluruh atribut dari database.
  Namun, setelah loop atribut, server secara mutlak (hardcode) menetapkan `Amount = 1` pada box tersebut. 
  Padahal jika pemain memiliki tumpukan box (misalnya 5 box), folder `Stacks` akan memiliki 4 item configuration di dalamnya. Akibat penulisan hardcode `Amount = 1`, saat pemain membuka box pertama kali, `Amount` berkurang menjadi `0` (`1 - 1 = 0`) bukannya menghilang. Box pun masih bisa diklik dan dibuka kembali hingga `Amount` menjadi negatif (`-1`), menyebabkan inkonsistensi data tumpukan kotak.
* **Solusi**:
  Diubah inisialisasi `Amount` di `loadInventoryItem` agar dinamis menghitung jumlah stacks yang dimuat dari database:
  ```lua
  if itemData.Stacks then
      -- memuat stacks config ...
      box:SetAttribute("Amount", 1 + #itemData.Stacks)
  end
  ```

---

## 📊 Ringkasan Prioritas Perbaikan

| No | Temuan Masalah | Tingkat Keparahan | Status Perbaikan |
| :-: | - | :-: | :-: |
| 1 | **Rollback Data Pemain** | 🔥 Kritis | ✅ Selesai Diperbaiki |
| 2 | **Kebocoran Memori Viewport UI** | ⚠️ Tinggi | ✅ Selesai Diperbaiki |
| 3 | **Griefing/Hancur Item di Sell GUI** | 🔥 Kritis | ✅ Selesai Diperbaiki |
| 4 | **Bug Stacking Kotak saat Di-equip** | ⚠️ Tinggi | ✅ Selesai Diperbaiki |
| 5 | **Bypass Batas Tas pada Spawner** | ℹ️ Sedang | ✅ Selesai Diperbaiki |
| 6 | **Bug Spawner Tertahan (Lock)** | ℹ️ Sedang | ✅ Selesai Diperbaiki |
| 7 | **Crash Pemuatan Sesi Parkir** | ⚠️ Tinggi | ✅ Selesai Diperbaiki |
| 8 | **Ketidakcocokan Tipe Data Notifikasi** | ℹ️ Rendah | ✅ Selesai Diperbaiki |
| 9 | **Migrasi Upgrade Event ke Networker** | ℹ️ Sedang | ✅ Selesai Diperbaiki |
| 10 | **Bug Mismatch Amount Box saat Load** | 🔥 Kritis | ✅ Selesai Diperbaiki |

---

> [!NOTE]
> Semua perbaikan di atas telah diterapkan secara lokal pada file-file proyek Anda. Silakan uji coba di Roblox Studio sebelum melakukan komit atau publikasi ke Git.

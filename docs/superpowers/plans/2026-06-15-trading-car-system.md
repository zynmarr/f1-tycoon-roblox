# Rencana Implementasi: Fitur Trading Car (F1-Tycoon)

Dokumen ini mendefinisikan rencana implementasi terperinci untuk membuat fitur pertukaran mobil antar pemain (Trading Car) secara terpusat di server dengan validasi anti-scam.

---

## 📋 Daftar Tugas (Todo List)

- [ ] **Tugas 1: Membuat Sesi Trade OOP Server (`TradeSession.luau`)**
  * Membuat file baru `src/ServerScriptService/TradeManager/TradeSession.luau`.
  * Merancang class OOP `TradeSession` untuk mengelola data penawaran (`Offer1`, `Offer2`), status lock (`IsLocked1`, `IsLocked2`), dan hitung mundur confirm.
  * Menambahkan validasi kepemilikan mobil saat item ditambahkan dan finalisasi pertukaran secara atomik (dengan data autosave).
  * *Verifikasi*: Pastikan modul OOP dapat di-require tanpa error sintaksis.

- [ ] **Tugas 2: Backend Pengelola Trade Server (`TradeManager.server.luau`)**
  * Membuat file baru `src/ServerScriptService/TradeManager/TradeManager.server.luau`.
  * Mengintegrasikan `RoleManager` atau pengecekan data untuk memastikan kedua pemain memiliki `Rebirths >= 5`.
  * Membuat Networker service server `TradeService` untuk menangani API request client (RequestTrade, AcceptTrade, DeclineTrade, AddCar, RemoveCar, LockOffer, ConfirmTrade).
  * *Verifikasi*: Menjalankan simulasi / mock player join, pastikan validasi prasyarat Rebirth >= 5 berhasil memblokir request trade jika pemain tidak memenuhi syarat.

- [ ] **Tugas 3: Membuat UI Panel Trading Client (`TradePanel.luau`)**
  * Membuat file baru `src/StarterPlayer/StarterPlayerScripts/components/TradeGui/TradePanel.luau`.
  * Merancang panel modal glassmorphism dengan React untuk menampilkan:
    * Slot penawaran Anda di sisi kiri (maks 6 mobil).
    * Slot penawaran lawan di sisi kanan.
    * Tombol LOCK / UNLOCK dan status text (READY / DRAFTING).
    * Inventori mobil di bagian bawah beserta search bar (dengan pencarian plain string aman).
  * *Verifikasi*: Pastikan komponen React terkompilasi tanpa error sintaksis.

- [ ] **Tugas 4: Integrasi Client & Undangan Trade (`MountTradeGui.client.luau`)**
  * Membuat file controller klien baru di `src/StarterPlayer/StarterPlayerScripts/MountTradeGui.client.luau` beserta komponen `TradeInvitation.luau`.
  * Menambahkan tombol "🤝 Trade" di UI daftar pemain (SideMenu) jika Rebirth >= 5.
  * Mengaktifkan interaksi fisik ProximityPrompt pada karakter pemain lain.
  * Menampilkan pop-up undangan trade reaktif dengan auto-timeout 15 detik.
  * *Verifikasi*: Masuk ke server dengan 2 akun, pastikan pengiriman undangan, penerimaan undangan, dan pembukaan panel trade berjalan seragam di kedua layar pemain.

---

## 🛠️ Detail Langkah Implementasi

### Tugas 1: Membuat Sesi Trade OOP Server (`TradeSession.luau`)
1. Buat folder baru `src/ServerScriptService/TradeManager/` jika belum ada.
2. Buat file `TradeSession.luau` dengan strict mode (`--!strict`).
3. Buat kerangka class OOP:
   ```luau
   local TradeSession = {}
   TradeSession.__index = TradeSession
   
   function TradeSession.new(id: string, p1: Player, p2: Player)
       local self = setmetatable({}, TradeSession)
       self.SessionId = id
       self.Player1 = p1
       self.Player2 = p2
       self.Offer1 = {} -- List UUID / Nama mobil unik
       self.Offer2 = {}
       self.IsLocked1 = false
       self.IsLocked2 = false
       self.IsConfirmed1 = false
       self.IsConfirmed2 = false
       self.Active = true
       return self
   end
   ```
4. Buat fungsi `AddCar` dan `RemoveCar` dengan validasi:
   * Cek apakah `IsLocked` bernilai true, jika ya kembalikan error.
   * Cek apakah pemain memiliki mobil tersebut di `Backpack`-nya.
   * Masukkan ke array `Offer` masing-masing.
   * Jika Player A menambah/menghapus mobil, reset `IsLocked1` dan `IsLocked2` ke `false`.
5. Buat fungsi `ExecuteTrade` secara atomik:
   * Lakukan check kepemilikan akhir terhadap seluruh mobil di `Offer1` dan `Offer2`. Jika ada mobil yang tidak ditemukan di Backpack pemilik aslinya, batalkan trade.
   * Pindahkan parent mobil ke Backpack lawan secara fisik.
   * Ubah atribut `Owner` mobil ke nama pemilik barunya.
   * Panggil `DataManager.syncData(player)` secara instan untuk kedua pemain.

### Tugas 2: Backend Pengelola Trade Server (`TradeManager.server.luau`)
1. Buat file `TradeManager.server.luau` di `src/ServerScriptService/TradeManager/`.
2. Buat tabel cooldown untuk menyimpan pengiriman undangan trade antar pemain.
3. Gunakan `Networker` untuk mendaftarkan endpoint RPC service `TradeService`:
   * `sendTradeRequest(player, targetName)`: Mengecek `Rebirths >= 5` untuk kedua pemain. Jika lolos, kirim event undangan ke target client.
   * `respondToRequest(player, senderName, accepted)`: Jika `accepted == true`, inisiasi objek `TradeSession.new` dan kirim state awal ke kedua pemain.
   * `addCarToOffer(player, carUUID)` / `removeCarFromOffer(player, carUUID)`: Teruskan ke fungsi instansi `TradeSession`.
   * `lockOffer(player)`: Kunci penawaran. Jika kedua pemain terkunci, jalankan task.delay 3 detik untuk finalisasi.
   * `confirmTrade(player)`: Konfirmasi trade di fase kedua.
   * `cancelTrade(player)`: Batalkan trade secara paksa, hancurkan instansi `TradeSession`, dan beri tahu kedua client untuk menutup panel.

### Tugas 3: Membuat UI Panel Trading Client (`TradePanel.luau`)
1. Buat folder baru `src/StarterPlayer/StarterPlayerScripts/components/TradeGui/` jika belum ada.
2. Buat file `TradePanel.luau` di folder tersebut.
3. Rancang visual UI dengan detail:
   * Sisi Kiri (Pemain 1): Grid 2x3 slots penawaran kita.
   * Sisi Kanan (Pemain 2): Grid 2x3 slots penawaran lawan.
   * Bagian Bawah: Grid daftar mobil milik kita di tas (diambil dengan memindai `Backpack` lokal).
   * Kolom Filter/Search: Menggunakan `string.find(string.lower(c.Name), query, 1, true)` untuk mencari nama mobil tanpa crash pattern.
   * Hubungkan input klik item inventori untuk memicu pemanggilan remote event `addCarToOffer` ke server.

### Tugas 4: Integrasi Client & Undangan Trade (`MountTradeGui.client.luau`)
1. Buat file `src/StarterPlayer/StarterPlayerScripts/MountTradeGui.client.luau`.
2. Buat UI popup undangan reaktif `TradeInvitation.luau` yang akan muncul jika target menerima event `TradeRequestInvitation`.
3. Buat script yang mendeteksi input `ProximityPrompt` pada karakter lain:
   * Server menaruh `ProximityPrompt` ke karakter pemain jika `Rebirths >= 5`.
   * Di client, saat tombol di-trigger, panggil remote `sendTradeRequest`.
4. Tambahkan tombol "🤝 Trade" di list daftar pemain SideMenuGui jika memenuhi syarat rebirth.

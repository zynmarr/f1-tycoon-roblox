# Riwayat Perubahan Proyek F1-Tycoon

Dokumen ini mencatat seluruh riwayat pemeriksaan, perbaikan, optimasi, audit mendalam, serta penambahan fitur baru yang telah diimplementasikan pada proyek **F1-Tycoon**.

---

## 1. Modul Utilitas Bersama (GameUtils)
Untuk menghindari duplikasi fungsi dan menjaga prinsip DRY (Don't Repeat Yourself), dibuatlah modul baru di `ReplicatedStorage`:
*   **File Baru**: `src/ReplicatedStorage/GameUtils.luau`
*   **Fungsi yang Disatukan**:
    *   `formatPrice(price)`: Memformat harga dengan koma (misal: `30,000`).
    *   `formatCompact(value)`: Memformat angka secara ringkas untuk tampilan stats (misal: `1K`, `1,2M`, `5B`).
    *   `getPlayerPlot(player)`: Mencari folder Plot milik player secara aman menggunakan atribut `MyPlotName`.
    *   `getPlotSellArea(plot)` / `getPlayerSellArea(player)`: Mengembalikan objek area penjualan fisik pada plot pemain.
    *   `isCar(tool)`: Memvalidasi apakah suatu objek `Tool` adalah mobil (menggunakan Tag/Attribute).
    *   `getPlayerCars(player)`: Memindai seluruh mobil milik pemain, baik yang ada di dalam `Backpack` maupun sedang di-equip di dalam `Character`.

---

## 2. Optimasi & Peningkatan Sell GUI
*   **Keamanan & Jarak Jual**:
    *   Batas jarak jual (`MAX_DISTANCE`) di server (`SellGuiServer.server.luau`) ditingkatkan menjadi `200` stud agar pemain dapat menjual dari area mana saja di plot mereka.
    *   Proximity detection di client (`SellGui.client.luau`) diubah agar **hanya membuka UI** ketika pemain pertama kali memasuki area penjualan.
    *   UI **tidak akan menutup secara otomatis** saat pemain menjauh atau saat transaksi sukses. UI hanya akan menutup jika tombol manual **"X"** diklik.
*   **Responsivitas UI & Stack Grouping**:
    *   Mengatur ukuran UI agar responsif menggunakan persentase skala relatif (`0.9, 0.8`) dan membatasi ukuran maksimal/minimal menggunakan `UISizeConstraint` agar pas di Mobile, Tablet, maupun PC.
    *   Menambahkan tombol tutup manual **"X"** di header UI.
    *   Jika pemain memiliki mobil dengan tipe yang sama (`Amount > 1`), tombol **SELL** akan disembunyikan dan diganti dengan tombol **VIEW STACK**. Ketika diklik, list mobil yang sama akan terbuka ke bawah (*expandable sub-list*) dengan tombol **SELL** masing-masing. Jika sisa mobil tinggal 1, list akan kembali menampilkan tombol **SELL** utama secara otomatis.
    *   Mengoptimalkan loop render React dengan menambahkan dependency array `{ cars }` pada `useEffect` untuk mencegah lag infinite re-render loop.

---

## 3. Penyesuaian Formula Harga & Tampilan Kartu
*   **Tampilan Detail Kartu**:
    *   Mengubah susunan info di header kartu mobil: **Nama Mobil** -> **Variant Text (Berwarna)** -> **Rarity Badge** -> **Harga**.
    *   Mengaktifkan `RichText` pada label Variant dengan mengambil format warna dari `GameConfig.GetColoredVariantList` agar nama variant (seperti `[Shiny]`, `[Golden]`, dll.) tampil dengan warna tema masing-masing.
*   **Formula Multiplier Variant (GameConfig)**:
    *   Mengubah kalkulasi harga gabungan variant di `GameConfig.CalculatePrice` menjadi **Aditif** (ditambahkan) daripada **Multiplikatif** (dikalikan). Hal ini mencegah harga mobil dengan banyak variant naik secara ekstrem hingga triliunan rupiah (misal dari `6.750.000.000.000` menjadi harga yang lebih masuk akal dan seimbang).

---

## 4. Perbaikan Kamera Viewport (ViewportManager)
*   Meningkatkan presisi rendering 3D pada slot Hotbar dan Sell GUI list:
    *   **Box / Kotak**: Diatur dengan `FieldOfView = 45` dan jarak kamera `1.6x` lebih jauh agar seluruh bodi kotak muat sempurna dalam frame tanpa terpotong.
    *   **Car / Mobil**: Diatur dengan `FieldOfView = 30` dan jarak kamera `0.95x` lebih dekat agar detail mobil terlihat jelas dan tidak terlalu kekecilan.

---

## 5. Perbaikan Bug Spawner & Sistem Upgrade Mesin
*   **Perbaikan Bug Billboard (SpawnerBoxManager)**:
    *   Memperbaiki bug pencarian `billboardGui` di server yang menggunakan fungsi salah `FindFirstChild(number)` akibat `string.find`. Sekarang server mendeteksi objek billboard secara akurat dengan memeriksa keberadaan `Area` atau `ModuleScript` secara langsung.
*   **Sistem Upgrade Mesin (UpgradeMachineArea)**:
    *   `UpgradeMachineArea.client.luau`: Mengatasi error crash saat player spawn dengan mendeteksi plot secara dinamis. Mendengarkan event `ChildAdded` pada folder `Machines` agar mesin baru yang dibeli dari tycoon langsung mendapatkan listener tombol upgrade.
    *   `Sinkronisasi Remote (BuyUpgradeFunction)`: Mengubah pemrosesan upgrade yang sebelumnya dilakukan secara ilegal di client menjadi panggilan aman ke server melalui RemoteFunction `BuyUpgradeFunction`. Server akan memotong uang (`player.leaderstats.Cash`), menyimpan level upgrade ke attribute mesin, dan menghapus kartu upgrade di Billboard secara tersinkronisasi untuk semua pemain.

---

## 6. Hasil Analisis & Pemeriksaan Menyeluruh (Deep Audit Fixes)

Berikut adalah 10 perbaikan prioritas dari hasil audit mendalam sistem F1-Tycoon:

1.  **Rollback Data Pemain**: Memperbaiki kerentanan rollback dengan membuat fungsi sinkronisasi `DataManager.syncData(player)` yang dipanggil saat `saveData` dan secara berkala setiap 60 detik (autosave) melalui `Main.server.luau`.
2.  **Kebocoran Memori Viewport UI (Client)**: Memperbaiki fungsi `trimCache` di `ViewportManager.luau` agar menghitung ukuran cache dictionary secara manual (menggunakan iterasi `pairs`), karena operator `#` tidak berfungsi pada dictionary.
3.  **Keamanan Transaksi Penjualan**: Mengamankan `sellCar` dan `sellAllCars` di `SellGuiServer.server.luau` dengan melakukan validasi jenis item (`isCar`) dan pembacaan harga sebelum memanggil `:Destroy()`, mencegah terhapusnya box secara tidak sengaja.
4.  **Bug Stacking Kotak On-Hand**: Memperluas pengecekan stacking kotak di `BoxManager.luau` agar memindai folder `Character` (ketika kotak di-equip di tangan) selain folder `Backpack`.
5.  **Bypass Batas Slot Tas**: Menambahkan validasi kapasitas maksimum tas (`MaxInventorySlots = 50`) di `processPickup` sebelum kotak diambil, dan mengirim notifikasi jika tas penuh.
6.  **Bug Spawner Tertahan (Lock)**: Menambahkan instansiasi `SourceMachine` (ObjectValue) saat memproduksi box di `SpawnerBoxManager.luau` agar status mesin spawner (`IsRunning`) langsung terbuka ketika box diambil.
7.  **Crash Sesi Parkir (Nil Check)**: Menambahkan validasi pengaman (nil check) pada pencarian `ProximityPrompt` di `ParkingAreaManager.luau` sebelum memanggil `SetAttribute` untuk mencegah error crash inisialisasi join.
8.  **Event Notifikasi**: Menyesuaikan parameter pemanggilan `NotifEvent:FireClient` di server agar sesuai dengan tanda tangan fungsi handler di client (`judul, pesan, durasi`).
9.  **Migrasi Event Upgrade ke Networker**: Mengganti RemoteFunction `BuyUpgradeFunction` lama dengan sistem request Networker `"UpgradeMachine"` untuk menjaga keseragaman arsitektur game.
10. **Bug Mismatch Amount Box**: Mengubah load data box di `Main.server.luau` agar `Amount` dihitung secara dinamis berdasarkan jumlah stack yang dimuat dari database (`1 + #itemData.Stacks`), bukan di-hardcode `Amount = 1`.

---

## 7. Sistem Role Dinamis & Kustomisasi Tampilan Premium

Menambahkan sistem role mandiri tanpa Roblox Group (menggunakan DataStore global `StaffRegistry_V1`) dan kustomisasi visual premium:

*   **Visual Nameplate Overhead (Overhead Tag)**:
    *   Pemain biasa hanya menampilkan nama dengan outline sederhana untuk menghemat render layar.
    *   VIP & Staff mendapatkan *Glassmorphism card* (bingkai kaca gelap semi-transparan), outline dengan rotasi gradasi neon, serta *Role Pill Badge* khusus (seperti `👑 VIP`, `🛡️ MODERATOR`, `🛠️ DEVELOPER`, dan `⚡ OWNER`).
*   **Animasi Gradient Client-Side**:
    *   Membuat script `OverheadClient.client.luau` untuk memutar rotasi outline border (`RotatingGradient`) dan menyapu teks badge dengan kilauan shimmer putih secara halus (`ShimmeringGradient`) menggunakan `CollectionService`.
    *   Menambahkan anotasi tipe data `: number` pada parameter delta time (`dt`) untuk kepatuhan ketat Luau tipe.
*   **Tampilan Nama di Chat**:
    *   `TextChatService`: Menghias prefix pesan chat dengan emoji role bold dan mewarnai nama pengirim di chat sesuai warna rolenya masing-masing.
    *   `Legacy Chat`: Menambahkan emoji role pada tags ChatService dan menyinkronkan warna teks nama pengirim menggunakan properti `NameColor`.

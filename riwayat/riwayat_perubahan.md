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

---

## 8. Perbaikan Bug Stacking & Kuantitas (Amount) Crate Pembelian dan Event Gift
*   **Penyebab Masalah**:
    *   **Masalah Stacking**: Pembelian box di Toko (`ShopManager.luau`) dan pemberian box hadiah admin (`EventManager.server.luau`) sebelumnya langsung meletakkan klon box baru ke `Backpack` tanpa melakukan pemeriksaan apakah tipe box yang sama sudah ada di dalam tas pemain. Hal ini menyebabkan box bertumpuk secara fisik sebagai tool terpisah alih-alih masuk ke dalam folder `Stacks` box yang sudah ada.
    *   **Masalah Kuantitas (Amount) Bernilai Nil/0**: Pada event hadiah admin (`EventManager.server.luau`), atribut `Amount` pada box yang dibuat sama sekali tidak diatur (nil), yang menyebabkan ketidaksinkronan data dan membuat UI hotbar/tas menampilkannya secara tidak benar atau tidak konsisten.
*   **Perbaikan yang Diterapkan**:
    *   **Fungsi Terpadu `giveBoxToPlayer`**: Menambahkan fungsi utilitas terpusat `BoxManager.giveBoxToPlayer` di dalam `BoxManager.luau`. Fungsi ini bertanggung jawab untuk kloning template box, inisialisasi visual, setup client tag, dan yang terpenting: melakukan logika pengecekan item lama (`existingBox`).
    *   **Sistem Stacking Server-Side**: Jika player sudah memiliki box dengan nama yang sama, fungsi `giveBoxToPlayer` akan secara otomatis memasukkan atribut box baru ke dalam folder `Stacks` konfigurasi dan meningkatkan atribut `Amount` sebanyak 1. Jika belum ada, box akan dimasukkan ke backpack dengan atribut `Amount` awal bernilai 1.
    *   **Refaktorisasi Shop & Event**: Mengintegrasikan `ShopManager.luau` (pembelian via Robux dan RPM Token) serta `EventManager.server.luau` (hadiah box admin) agar sepenuhnya memanggil fungsi terpusat `BoxManager.giveBoxToPlayer` untuk konsistensi sistem inventori.

---

## 9. Peningkatan Tampilan 3D Model Box di Shop (ShopGui)
*   **Pembaruan Fitur**:
    *   Mengganti ikon statis emoji box `"📦"` pada daftar produk di Shop GUI (`ShopGui.luau`) dengan `ViewportFrame` dinamis untuk merender visual 3D dari box sesuai levelnya masing-masing.
*   **Implementasi Teknis**:
    *   **Impor ViewportManager**: Menghubungkan modul `ViewportManager.luau` ke `ShopGui.luau` untuk memproses setup kamera 3D, orientasi, pencahayaan, dan bounding box model secara seragam.
    *   **Pembuatan Dummy Tool & Caching**: Menggunakan helper `getOrCreateDummyTool` untuk merakit instance tool tiruan yang mewakili model box dari `ReplicatedStorage.BoxModels` (misalnya `"Level1"`, `"Level3"`, dll.) secara ter-cache agar hemat memori saat React merender ulang UI.
    *   **Lifecycle Cleanup**: Menambahkan callback pembersihan `ViewportManager.clearAllCache(cache.current)` pada cleanup hook `useEffect` saat Shop GUI unmount guna menghindari kebocoran memori (memory leak).

---

## 10. Implementasi Tampilan RPM Tokens pada Stats HUD Utama (CustomStats)
*   **Pembaruan Fitur**:
    *   Menampilkan jumlah saldo **RPM Tokens** (RPM Points) pemain secara *real-time* langsung pada kartu statistik di sidebar HUD utama (`CustomStats.luau`), tepat di bawah baris **Cash** dan di atas **Rebirth Points (RP)**.
*   **Implementasi Teknis**:
    *   **Sinkronisasi State**: Menambahkan state `rpmVal` dan menghubungkannya dengan perubahan nilai `RPM Tokens` dari `leaderstats` secara reaktif di dalam `useEffect`.
    *   **Penyelarasan Tata Letak (Layout)**:
        *   Mengatur `LayoutOrder` baru pada barisan stats: **Cash (1)** -> **RPM Tokens (2)** -> **Rebirth Points (3)** -> **Rebirth Level (4)**.
        *   Meningkatkan tinggi `StatsCard` dari `75` menjadi `100` dan wadah luar `Frame` utama HUD dari `160` menjadi `185` untuk mencegah terjadinya tumpang tindih visual (overlapping) atau pemotongan elemen (clipping).
        *   Mewarnai nilai RPM dengan kode warna kuning premium `Color3.fromRGB(255, 185, 0)` dan menyertakan ikon roda gigi `"⚙️"`.

---

## 11. Perbaikan Bug Render 3D Model Hotbar Melar / 100% (ViewportManager)
*   **Penyebab Masalah**:
    *   **Replication Race Condition**: Saat membuka box atau menerima item baru, instance `Model` dari server terkadang belum selesai mereplikasi seluruh keturunannya (bagian part dalam mobil/box) ketika client mulai mendeteksi keberadaan objek tersebut. Hal ini menyebabkan perhitungan bounding box menghasilkan nilai `maxDim` yang sangat kecil atau salah, sehingga rasio kamera zoom menjadi terlalu besar (melar 100% memenuhi layar slot).
    *   **Cache Mismatch**: Karena cache render sebelumnya hanya menggunakan referensi tool instance (`toolID`), perubahan isi visual model (seperti level box yang berubah saat dikonsumsi dari stack) tidak terdeteksi oleh `LastCar` check, sehingga client melewatkan re-render dan menampilkan model lama yang tidak sesuai.
*   **Perbaikan yang Diterapkan**:
    *   **Pemeriksaan Stabilitas Keturunan**: Menambahkan loop tunggu pada `ViewportManager.luau` untuk memastikan jumlah keturunan model (`#originalModel:GetDescendants()`) telah stabil (tidak berubah) selama minimal 3 check frame berturut-turut sebelum melakukan kloning dan pemosisian kamera. Dilengkapi dengan timeout pengaman sebesar `0.5` detik.
    *   **Kombinasi Render Key Dinamis**: Mengubah kunci identifikasi viewport (`LastCar` dan cache key) dari `toolID` biasa menjadi `renderKey` gabungan: `toolID_Level_Variant`. Jika level atau varian item berubah secara dinamis (seperti saat membuka box atau stack berkurang), sistem akan mendeteksi perbedaan key dan memaksa pemuatan ulang model baru secara akurat.

---

## 12. Perbaikan Bug Sinkronisasi Online (Sistem Macet & Data Hilang Saat Log Out)
*   **Penyebab Masalah**:
    *   **Data Backpack Hilang (Race Condition Server)**: Di server online, karakter pemain membutuhkan waktu lebih lama untuk memuat (ping/asset delay) dibanding di Studio. Logika pemuatan item awal (`setupPlayerSkinsAndAssets`) berjalan selesai **sebelum** karakter spawn, padahal tracker inventori (`connectInventoryTracker`) hanya dipasang saat karakter spawn. Akibatnya, pemuatan awal box/mobil tidak memicu `syncData` (tracker belum aktif), menyisakan `profile.Data.Inventory` dalam keadaan kosong (`{}`). Ketika pemain keluar, sistem mendeteksi `IsLeaving = true` dan menyimpan data inventori kosong tersebut langsung ke DataStore, menghapus seluruh barang di tas.
    *   **Sistem Gagal Memuat Online (Replication Delay Client)**: Beberapa UI krusial (seperti `MainHUD`, `InventoryModal`, `CustomStats`, `ShopGui`, dan `AdminEventPanel`) menggunakan pemanggilan `WaitForChild` dengan batas waktu singkat (5 hingga 15 detik) untuk mencari folder `Backpack`, `leaderstats`, `LiveEvents`, serta nilai RPM/Cash. Di server online dengan ping tinggi, objek-objek tersebut terlambat direplikasi ke client melebihi batas waktu tersebut, menyebabkan inisialisasi UI terputus setengah jalan dan tidak merender stats/indikator event.
*   **Perbaikan yang Diterapkan**:
    *   **Perbaikan Tracker Inventori Terpusat**:
        *   Membuat `startInventoryTracker` di `Main.server.luau` berjalan **langsung** setelah data pemain dimuat, tanpa menunggu karakter spawn. Ini menghubungkan listener `ChildAdded/ChildRemoved` pada `Backpack` seketika saat player join.
        *   Menyisipkan panggilan `pcall(DataManager.syncData, player)` di bagian akhir fungsi `setupPlayerSkinsAndAssets` untuk memastikan data inventori awal yang dimuat langsung tersinkronisasi dengan aman dan utuh di DataStore sebelum pemain bertransaksi atau log out.
    *   **Penghapusan Timeout Replikasi**:
        *   Menghapus seluruh parameter batas waktu (seperti `5`, `10`, `15` detik) pada `WaitForChild` untuk objek-objek terjamin (seperti `Backpack` di `MainHUD`/`InventoryModal`, `leaderstats` dan `LiveEvents` di `CustomStats`, `AdminEventPanel`, dan `ShopGui`). Client kini akan menunggu objek tersebut selesai direplikasi sepenuhnya secara aman, meniadakan kegagalan loading sistem online.

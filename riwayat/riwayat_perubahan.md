# Riwayat Perubahan Proyek F1-Tycoon

Dokumen ini mencatat seluruh riwayat pemeriksaan, perbaikan, dan optimasi yang telah diimplementasikan pada proyek F1-Tycoon.

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
    *   **UpgradeMachineArea.client.luau**: Mengatasi error crash saat player spawn dengan mendeteksi plot secara dinamis. Mendengarkan event `ChildAdded` pada folder `Machines` agar mesin baru yang dibeli dari tycoon langsung mendapatkan listener tombol upgrade.
    *   **Sinkronisasi Remote (BuyUpgradeFunction)**: Mengubah pemrosesan upgrade yang sebelumnya dilakukan secara ilegal di client menjadi panggilan aman ke server melalui RemoteFunction `BuyUpgradeFunction`. Server akan memotong uang (`player.leaderstats.Cash`), menyimpan level upgrade ke attribute mesin, dan menghapus kartu upgrade di Billboard secara tersinkronisasi untuk semua pemain.

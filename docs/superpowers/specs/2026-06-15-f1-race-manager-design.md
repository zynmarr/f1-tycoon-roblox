# Spesifikasi Desain: F1 Race Manager System

Dokumen ini mendefinisikan rancangan sistem balapan taktis F1 berbasis GUI Manager untuk game F1-Tycoon, yang mencakup mekanisme simulasi balapan 2D deterministik, taruhan PvP, dan spawning stasiun fisik secara otomatis di dalam plot tycoon.

---

## 1. Ringkasan Fitur (Feature Overview)

Sistem **F1 Race Manager** adalah fitur baru di mana pemain dapat menggunakan koleksi mobil F1 mereka untuk balapan melawan AI atau menantang pemain lain (PvP) dengan bertaruh sejumlah uang Cash.

### Fitur Utama:
1. **F1 Race Station (Fisik)**: Objek stasiun balap (meja komputer + monitor neon) yang otomatis memicu spawning di plot tycoon pemain saat diklaim. Berfungsi sebagai gerbang interaksi fisik (ProximityPrompt) untuk membuka GUI balapan.
2. **Dashboard Manajemen Balap (GUI)**:
   * **Garage Selector**: Grid untuk memilih mobil aktif yang akan dipakai balapan dari tas pemain.
   * **Mode Balapan AI**: Pilihan kesulitan (Easy, Medium, Hard) dengan sistem *reward* Cash & XP dinamis.
   * **Mode Tantangan PvP**: Menantang pemain online lain di server dengan nominal taruhan Cash tertentu.
3. **Mekanisme Start Interaktif (Reaction Launch Boost)**:
   * Pemain harus mengklik tombol "LAUNCH" tepat saat kelima lampu merah padam. Reaksi yang sangat cepat (< 0.15 detik) memberikan akselerasi start instan.
4. **Simulasi Sirkuit 2D Deterministik**:
   * Balapan di-render sebagai animasi titik-titik lingkaran mobil yang berputar mengitari sirkuit 2D secara mulus (60 FPS) menggunakan rumus matematika berbasis waktu server. Hasilnya dijamin 100% sinkron antar pemain tanpa membebani performa server.

---

## 2. Arsitektur & Struktur Data (Architecture & Data Structures)

### 2.1. File Sirkuit & Lokasi Kode
```
src/
├── ServerScriptService/
│   ├── RaceManager.server.luau (Script server utama, logika balap, & endpoints)
│   └── PlotManager/PlotManager.luau (Diperbarui untuk spawn RaceStation di plot)
└── StarterPlayer/
    └── StarterPlayerScripts/
        ├── MountRacePanel.client.luau (Controller klien, rendering React UI)
        └── components/
            └── RacePanel/
                └── RacePanel.luau (Komponen React untuk dashboard & simulasi balap)
```

### 2.2. Struktur Data Balapan Server (Server State)
Server melacak sesi balapan aktif di dalam memori menggunakan tabel `activeRaces`:
```lua
type RaceSession = {
	RaceId: string,
	Type: "AI" | "PvP",
	StartTime: number, -- timestamp server
	Laps: number, -- default 3
	Seed: number, -- benih acak untuk variansi balapan
	Participants: {
		[Player]: {
			CarName: string,
			BaseSpeed: number,
			ReactionTime: number?, -- nil sampai mereka klik launch
			LaunchMultiplier: number, -- default 1.0 (ditentukan setelah klik)
		}
	},
	Difficulty: string?, -- "Easy" | "Medium" | "Hard" (untuk mode AI)
	BetAmount: number?, -- jumlah uang taruhan (untuk mode PvP)
	Winner: Player?,
}
```

### 2.3. Networker Service Endpoints (`RaceService`)
* **`getRaceStats(player)`**: Memuat rekor balapan pemain (Total Wins, Losses, Cash earned).
* **`startAIRace(player, carName, difficulty)`**: Memulai balapan AI. Server memvalidasi kepemilikan mobil dan memotong biaya balapan (jika ada). Mengembalikan metadata sesi balap.
* **`sendPvPChallenge(player, opponentName, carName, betAmount)`**: Mengirim tantangan PvP. Server memverifikasi bahwa penantang memiliki saldo Cash yang cukup untuk taruhan.
* **`acceptPvPChallenge(player, challengeId, carName)`**: Menyetujui tantangan. Server memotong saldo uang taruhan dari kedua pemain, lalu menginisialisasi sesi balap global.
* **`submitLaunchTime(player, raceId, clickTimeOffset)`**: Mengirimkan waktu reaksi klik tombol start. Server memvalidasi bahwa waktu klik masuk akal dan menyimpan multiplier launch.

---

## 3. Logika Simulasi & Formula Matematika (Race Engine Math)

### 3.1. Penentuan Launch Multiplier (Reaction Time)
Waktu reaksi dihitung dari selisih milidetik sejak lampu padam (`LightsOutTime`) hingga klik terkirim:
* $t_{\text{reaction}} = t_{\text{click}} - t_{\text{lights\_out}}$
* **Mekanisme Skala Boost**:
  * $t_{\text{reaction}} < 0$: **JUMP START** $\rightarrow$ Kecepatan dikurangi penalti (Multiplier = 0.7) selama 10 detik.
  * $t_{\text{reaction}} \le 0.15$: **PERFECT LAUNCH** $\rightarrow$ Multiplier = 1.25 (Durasi boost 8 detik).
  * $t_{\text{reaction}} \le 0.35$: **GOOD LAUNCH** $\rightarrow$ Multiplier = 1.12 (Durasi boost 8 detik).
  * $t_{\text{reaction}} > 0.5$: **SLOW LAUNCH** $\rightarrow$ Multiplier = 1.0 (Tanpa boost).

### 3.2. Gerakan Titik Deterministik (Parametric Trajectory)
Setiap pembalap memiliki nilai sudut putaran $\theta_i(t)$ pada detik ke-$t$ sejak balapan dimulai.
* Formula sudut putaran (progres lintasan):
  $$\theta_i(t) = (\text{BaseSpeed}_i \cdot t) + \text{LaunchBoost}_i(t) + \text{Variance}_i(t, \text{Seed})$$
  Di mana:
  * $\text{BaseSpeed}_i$: Kecepatan konstan mobil berbasis statistika (Rarity + Variant + Upgrades).
  * $\text{LaunchBoost}_i(t)$: Menggunakan fungsi peluruhan eksponensial untuk mempercepat mobil di awal lalu meluruh kembali ke nol:
    $$\text{LaunchBoost}_i(t) = \text{maxBoost}_i \cdot e^{-0.5t}$$
  * $\text{Variance}_i(t, \text{Seed})$: Fungsi sinus berbasis seed acak agar mobil saling menyalip secara visual:
    $$\text{Variance}_i(t) = \sin(t \cdot 0.7 + i + \text{Seed}) \cdot 0.25$$

* Konversi ke Posisi Sirkuit Oval 2D (X, Y):
  Klien menggambar lintasan oval dengan jejari $R_x$ (horizontal) dan $R_y$ (vertical). Titik mobil diplot di layar menggunakan:
  $$X_i(t) = \cos(\theta_i(t)) \cdot R_x$$
  $$Y_i(t) = \sin(\theta_i(t)) \cdot R_y$$

---

## 4. Spesifikasi UI & Alur Layar (UI/UX Wireframes)

GUI `RacePanel` dirancang dengan layout berstruktur tab untuk memudahkan navigasi:

```
+-------------------------------------------------------------------------+
|  🏁 F1 RACE MANAGER SYSTEM                                         [✕]  |
|  +--------------+ +---------------------------------------------------+ |
|  |  🚀 DASHBOARD| | TAB: DASHBOARD BALAP                              | |
|  |  🏆 STATS    | |                                                   | |
|  |              | |  [ PILIH MOBIL ]         [ MODE BALAPAN AI ]      | |
|  |              | |  +-------------+         Difficulty:              | |
|  |              | |  | Ferrari     |         [ Easy ] [ Med ] [ Hard ]| |
|  |              | |  | Epic / Admin|         Reward: $5,000 / +50 XP  | |
|  |              | |  +-------------+         [ START AI RACE ]        | |
|  |              | |                                                   | |
|  |              | |  [ TANTANGAN PvP ]                                | |
|  |              | |  Lawan: [Pilih Player Online     v]               | |
|  |              | |  Taruhan: $[ 50000 ]  [ KIRIM TANTANGAN ]         | |
|  +--------------+ +---------------------------------------------------+ |
+-------------------------------------------------------------------------+
```

### Animasi Layar Balapan Aktif (Active Race View):
1. **Lampu F1 Count-down**: Papan HUD di bagian atas yang merender 5 lampu bulat neon. Menyala merah satu demi satu, lalu padam serentak.
2. **Lintasan Sirkuit**: Di tengah panel, terdapat visualisasi garis lintasan oval modern. Empat titik berwarna kontras bergerak berputar memutari sirkuit secara mulus.
3. **Papan Peringkat Telemetri**: Di sisi kanan sirkuit, peringkat peserta (`1st`, `2nd`, `3rd`, dst.) ter-update secara *real-time* berdasarkan sudut putaran terbesar ($\theta_i(t)$), lengkap dengan indikator jarak selisih waktu lap.

---

## 5. Spawner Stasiun Balap Tycoon (Race Station Spawner)

Untuk integrasi mulus dengan game Tycoon:
1. Ketika player mengklaim plot, script [PlotManager.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/PlotManager/PlotManager.luau) akan memeriksa keberadaan folder `"RaceStation"` di dalam plot tersebut.
2. Jika tidak ditemukan, server secara dinamis membuat Model `"RaceStation"` baru berisi:
   * **DeskPart** (Part dasar meja abu-abu metalik).
   * **ScreenPart** (Monitor dengan permukaan Neon biru menyala).
   * **ProximityPrompt** (Aksi: *"Kelola Balapan"*, Jarak aktivasi: 8 studs, Durasi tahan: 0.5s).
3. Stasiun ditempatkan secara teratur di sebelah kanan `SpawnLocation` plot:
   $$\text{CFrame}_{\text{Station}} = \text{CFrame}_{\text{SpawnLocation}} \cdot \text{CFrame.new}(6, 0, 0)$$
4. Di sisi klien, ketika prompt dipicu, UI akan terbuka bagi pemilik plot tersebut.

---

## 6. Tindakan Keamanan & Anti-Cheat (Security Measures)

1. **Server-Side Validation**:
   * Seluruh data penentuan pemenang dihitung secara final di server. Klien hanya merender animasi visual secara lokal. Hal ini mencegah exploiter memanipulasi posisi mobil atau langsung mengeklaim kemenangan instan via klien.
2. **Validasi Saldo Taruhan**:
   * Sebelum tantangan PvP disebarkan, server memverifikasi secara ketat bahwa saldo Cash penantang dan penerima tantangan mencukupi nominal taruhan. Uang taruhan langsung dikunci dan dipotong di server sesaat setelah tantangan diterima.
3. **Anti-Cheat Lampu Start**:
   * Server mencatat waktu padamnya lampu merah secara rahasia. Waktu klik reaksi (`submitLaunchTime`) yang dikirim klien akan diverifikasi kecocokannya dengan selisih waktu di server. Jika ada anomali (misal waktu reaksi < 0.001 detik yang mencurigakan), server otomatis mengategorikannya sebagai penalti Jump Start atau membatalkannya demi mencegah *auto-clicker exploit*.

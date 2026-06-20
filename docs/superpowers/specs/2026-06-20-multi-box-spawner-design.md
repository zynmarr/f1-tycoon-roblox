# Design Spec: Multi-Box Spawner System (Locations Folder)

**Deskripsi:** Mengimplementasikan dukungan spawner box multi-lokasi menggunakan folder `Locations` di dalam area mesin. Sistem ini juga memperbarui modul penyimpanan data agar dapat men-save dan men-load lebih dari satu box aktif untuk setiap mesin.

---

## 1. Perubahan Struktur Folder (Roblox Studio)

Untuk spawner yang men-spawn banyak box (misal: `AthenaArea`), susunan foldernya adalah:
- `AthenaArea` (Folder)
  - `AthenaMachine` (BasePart)
  - `Locations` (Folder baru)
    - `Location1` (BasePart penanda lokasi spawn)
    - `Location2` (BasePart penanda lokasi spawn)

Jika folder `Locations` tidak ditemukan, spawner akan default ke perilaku spawner 1-box (spawning tepat di atas `machinePart`).

---

## 2. Rincian Perubahan Kode

### 2.1. `src/ServerScriptService/SpawnerBoxManager/SpawnerBoxManager.luau`

#### A. Inisialisasi `boxPosition` Dinamis
Mengganti pengecekan hardcode `"AthenaArea"` dengan pencarian folder `Locations`:
```luau
		local boxPosition: { [string]: CFrame } = {}
		local locationsFolder = machineArea:FindFirstChild("Locations")

		if locationsFolder then
			for _, child in ipairs(locationsFolder:GetChildren()) do
				if child:IsA("BasePart") then
					boxPosition[child.Name] = child.CFrame
				end
			end
		end
```

#### B. Pengecekan Keterisian Lokasi & Spawning Beruntun
Pada logika loop utama:
1. Memindai folder `Locations` dan mencari tahu lokasi mana saja yang tidak memiliki box tool aktif (memeriksa `child:GetAttribute("SpawnLocationName") == locName`).
2. Menyetel atribut `IsRunning = true` jika semua lokasi terisi, dan `false` jika ada lokasi kosong.
3. Memanggil `spawnBox` dengan parameter `loc.CFrame` dan `loc.Name` untuk masing-masing lokasi kosong tersebut.

#### C. Modifikasi `spawnBox`
1. Menerima parameter baru `locationName: string?`.
2. Jika `locationName` diberikan, periksa apakah lokasi tersebut sudah terisi. Jika ya, batalkan spawn.
3. Atur atribut `SpawnLocationName = locationName` pada box yang baru di-spawn.

#### D. Modifikasi Reset State di Akhir Growth Loop
Untuk spawner multi-lokasi, jangan hentikan respawn jika masih ada lokasi yang kosong. Kita biarkan logic loop di `startLogic` menangani deteksi lokasi kosong dan memicu spawn kembali secara otomatis.

---

### 2.2. `src/ServerScriptService/DataManager/DataManager.luau`

#### A. Penyimpanan Multi-Box (`ActiveBoxes`)
Ubah pemindaian box aktif agar tidak langsung berhenti (`break`) saat menemukan 1 box. Scan semua box dan simpan ke array `ActiveBoxes`:
```luau
	local activeBoxes = {}
	if machinePart then
		for _, child in pairs(machinePart:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("Level") ~= nil then
				table.insert(activeBoxes, {
					Level = child:GetAttribute("Level") or 1,
					Exp = child:GetAttribute("Exp") or 0,
					Variants = child:GetAttribute("Variants") or "Normal",
					SpawnLocationName = child:GetAttribute("SpawnLocationName"),
				})
			end
		end
	end
```

---

## 3. Rencana Pengujian (Testing Plan)
- **Verifikasi Spawning**: Tambahkan folder `Locations` berisi beberapa part di `AthenaArea` di Roblox Studio. Jalankan game, pastikan box muncul di seluruh lokasi tersebut.
- **Verifikasi Respawn**: Ambil salah satu box, pastikan box baru muncul kembali hanya di lokasi yang kosong tersebut.
- **Verifikasi Save/Load**: Biarkan beberapa box tumbuh, keluar dari game, dan pastikan setelah masuk kembali semua box tersebut ter-spawn di lokasi asalnya masing-masing dengan level/exp yang sesuai.

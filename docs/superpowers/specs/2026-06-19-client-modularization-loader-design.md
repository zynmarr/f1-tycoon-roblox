# Spesifikasi Desain: Modularisasi Client & Bootstrapper Terpusat (Client Loader)

Dokumen spesifikasi desain ini menjelaskan langkah-langkah, arsitektur baru, dan rencana migrasi untuk menyatukan 15 client script terpisah di dalam `StarterPlayerScripts` menjadi ModuleScript yang diatur urutan pemuatannya secara sekuensial melalui satu entry point terpusat (`MainClient.client.luau`).

---

## 1. Latar Belakang & Masalah
Saat ini terdapat 15 file `.client.luau` di dalam folder `src/StarterPlayer/StarterPlayerScripts`. Semua script ini dieksekusi secara bersamaan (paralel) oleh engine Roblox saat pemain masuk ke dalam game.
Hal ini memicu masalah **Race Condition** (kondisi balapan) di server online, di mana:
*   Beberapa script UI (seperti `MountRacePanel` atau `MountAdminEventPanel`) mencoba memproses inisialisasi jaringan sebelum koneksi jaringan (`NetworkerClient` / `RaceService` / `AdminEventService`) siap sepenuhnya.
*   Hal ini memicu warning `"Infinite yield possible on _remotes:WaitForChild(...)"` dan terkadang menyebabkan UI hotbar atau fitur panel admin gagal memuat secara benar di server asli, meskipun di Studio terlihat normal karena latensi jaringan lokal mendekati nol.

---

## 2. Arsitektur Solusi: Bootstrapper Hibrida Sekuensial
Untuk menyelesaikan masalah ini, kita menerapkan **Opsi C (Pendekatan Hibrida)**:
1.  **Pemisahan Tanggung Jawab:** Mengubah semua file `.client.luau` yang ada menjadi `ModuleScript` biasa (`.luau`).
2.  **Satu LocalScript Aktif:** Membuat satu-satunya LocalScript aktif bernama `MainClient.client.luau` di `StarterPlayerScripts` sebagai entry point sistem client.
3.  **Inisialisasi Hibrida:**
    *   **Core Systems:** Dimuat secara sinkron berurutan (Strict Sequential) di thread utama loader untuk menjamin fondasi sistem siap 100% sebelum fitur lainnya berjalan.
    *   **Features & UI:** Dimuat secara asinkron (`task.spawn`) setelah modul Core siap. Ini memastikan kegagalan atau keterlambatan rendering satu panel UI tidak menghambat pemuatan UI atau fitur lainnya.

---

## 3. Konfigurasi Rojo & Struktur File Baru
Berdasarkan konfigurasi proyek Rojo (`default.project.json`), jenis instansi di Roblox Studio ditentukan oleh nama file eksternal:
*   `*.client.luau` $\rightarrow$ `LocalScript`
*   `*.luau` $\rightarrow$ `ModuleScript`

Kita akan mengubah nama semua file client lama dari format `NamaFile.client.luau` menjadi `NamaFile.luau` agar terbaca sebagai `ModuleScript` di Roblox Studio.

### Daftar Modul yang Dimigrasi:
1.  `ScreenOrientation.luau` (CORE)
2.  `NotifHandlerGui.luau` (CORE)
3.  `ChatAnnounceHandler.luau` (CORE)
4.  `ChatTags.luau` (CORE)
5.  `OverheadClient.luau` (CORE)
6.  `ShopGui.luau` (FEATURE)
7.  `SellGui.luau` (FEATURE)
8.  `MenuSellGui.luau` (FEATURE)
9.  `UpgradeMachineArea.luau` (FEATURE)
10. `AnnouncementGui.luau` (FEATURE)
11. `MountMainHUD.luau` (FEATURE)
12. `MountMainGuiHub.luau` (FEATURE)
13. `MountAdminEventPanel.luau` (FEATURE)
14. `MountRacePanel.luau` (FEATURE)
15. `MountTradeGui.luau` (FEATURE)

---

## 4. Implementasi Entry Point: `MainClient.client.luau`
Script utama ini akan mendefinisikan urutan loading serta mengeksekusi fungsi `init()` dari setiap modul secara aman menggunakan penanganan error (`pcall`).

```lua
--!strict
-- src/StarterPlayer/StarterPlayerScripts/MainClient.client.luau
-- Bootstrapper Terpusat untuk seluruh sistem Client F1-Tycoon

print("[MainClient] Memulai inisialisasi seluruh sistem client...")

local CORE_MODULES: {string} = {
	"ScreenOrientation",
	"NotifHandlerGui",
	"ChatAnnounceHandler",
	"ChatTags",
	"OverheadClient",
}

local FEATURE_MODULES: {string} = {
	"ShopGui",
	"SellGui",
	"MenuSellGui",
	"UpgradeMachineArea",
	"AnnouncementGui",
	"MountMainHUD",
	"MountMainGuiHub",
	"MountAdminEventPanel",
	"MountRacePanel",
	"MountTradeGui",
}

-- Fungsi pembantu untuk memuat dan menginisialisasi ModuleScript secara aman
local function loadModule(name: string, isAsync: boolean)
	local scriptObj = script.Parent:WaitForChild(name, 10)
	if not scriptObj or not scriptObj:IsA("ModuleScript") then
		warn("[MainClient] ❌ Gagal menemukan ModuleScript: " .. name)
		return
	end

	local success, module = pcall(require, scriptObj)
	if not success then
		warn("[MainClient] ❌ Gagal require modul: " .. name .. " | Error: " .. tostring(module))
		return
	end

	if module and typeof(module.init) == "function" then
		if isAsync then
			task.spawn(function()
				local ok, err = pcall(module.init)
				if not ok then
					warn("[MainClient] ❌ Runtime error pada init() modul: " .. name .. " | Error: " .. tostring(err))
				end
			end)
		else
			local ok, err = pcall(module.init)
			if not ok then
				warn("[MainClient] ❌ Runtime error pada init() modul: " .. name .. " | Error: " .. tostring(err))
			end
		end
	else
		warn("[MainClient] ⚠️ Modul " .. name .. " tidak mengekspos fungsi init() yang valid.")
	end
end

-- =============================================================================
-- EKSEKUSI PEMUATAN
-- =============================================================================

-- 1. Eksekusi Core Modules secara sinkron (blocking / berurutan ketat)
for _, moduleName in ipairs(CORE_MODULES) do
	loadModule(moduleName, false)
end

-- 2. Eksekusi Feature & UI Modules secara asinkron (tidak saling memblokir jika yield)
for _, moduleName in ipairs(FEATURE_MODULES) do
	loadModule(moduleName, true)
end

print("[MainClient] ✅ Seluruh modul client berhasil dijadwalkan / dimuat!")
```

---

## 5. Standarisasi Format Modul Client
Setiap file `.luau` harus mengikuti struktur standard berikut agar dapat dibaca oleh loader:

```lua
local ModulName = {}

function ModulName.init()
	-- Seluruh kode logika asli diletakkan di dalam sini
end

return ModulName
```

Contoh migrasi riil untuk file sederhana seperti `ScreenOrientation.luau`:
```lua
-- Sebelum (ScreenOrientation.client.luau):
local Players = game:GetService("Players")
-- ... kode logika ...

-- Sesudah (ScreenOrientation.luau):
local ScreenOrientation = {}

function ScreenOrientation.init()
	local Players = game:GetService("Players")
	-- ... kode logika asli ...
end

return ScreenOrientation
```

---

## 6. Rencana Pengujian
Setelah migrasi dilakukan:
1.  **Pengujian Jaringan & Race Condition:** Jalankan game di Roblox Studio lokal maupun live server online, pastikan tidak ada warning *"Infinite yield"* dari `NetworkerClient` saat memuat panel UI.
2.  **Verifikasi Fungsionalitas:** Pastikan seluruh UI (Toko, Jual Mobil, Panel Admin, Hotbar, dan HUD Utama) ter-render dan dapat beroperasi normal seperti sediakala.
3.  **Runtime Log Check:** Buka Developer Console (F9), pastikan pesan `[MainClient] ✅ Seluruh modul client berhasil dijadwalkan / dimuat!` muncul dan tidak ada log error merah (`❌`) dari pemanggilan `loadModule`.

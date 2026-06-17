# Rencana Implementasi: Sistem Pengumuman Chat (Gacha Mobil & Pembelian Gamepass Global)

Rencana ini membagi pekerjaan menjadi langkah-langkah terperinci untuk mengimplementasikan fitur pengumuman chat lokal dan global di dalam game.

---

## Tugas 1: Implementasi Pengumuman Gacha Mobil Lokal (Server-Side)
Lokasi File: [BoxManager.luau](file:///C:/Project/Roblox Studio Projects/Projects/F1-Tycoon/src/ServerScriptService/BoxManager/BoxManager.luau)

- [ ] **Langkah 1: Tambahkan Import Konfigurasi**
  Tambahkan `RoleConfig` di bagian atas file:
  ```lua
  local RoleConfig = require(ReplicatedStorage:WaitForChild("RoleConfig"))
  ```

- [ ] **Langkah 2: Tambahkan Logika Pengumuman Gacha**
  Di dalam fungsi `BoxManager:openBox`, tepat sebelum pernyataan `return`, periksa apakah `tier` (kelangkaan mobil) adalah Epic ke atas, lalu siarkan pesan.
  * Tambahkan daftar kelangkaan yang berhak diumumkan: `{"Epic", "Legendary", "Mythic", "God", "Celestial", "Admin"}`.
  * Ambil role pemain menggunakan `RoleManager.getPlayerRole(player)`.
  * Ambil nama box dasar: `GameConfig.BoxLevels[currentLevel].Name`.
  * Ambil nama mobil dasar: `chosenCarTemplate.Name`.
  * Format pesan dengan HTML Rich Text untuk `TextChatService`.
  * Saring tag HTML untuk cadangan `Legacy ChatService` dan kirim dengan `ChatColor`.

---

## Tugas 2: Implementasi Pengumuman Gamepass Global (Server-Side)
Lokasi File: [RoleManager.luau](file:///C:/Project/Roblox Studio Projects/Projects/F1-Tycoon/src/ServerScriptService/RoleManager/RoleManager.luau)

- [ ] **Langkah 1: Hubungkan Listener Pembelian Gamepass**
  Di dalam fungsi `RoleManager.Init()`, buat koneksi ke `MarketplaceService.PromptGamePassPurchaseFinished`:
  ```lua
  MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
      if wasPurchased then
          task.spawn(function()
              RoleManager.handleGamePassPurchase(player, gamePassId)
          end)
      end
  end)
  ```

- [ ] **Langkah 2: Buat Fungsi Handler Pembelian**
  Buat fungsi `RoleManager.handleGamePassPurchase(player, gamePassId)`:
  * Jika `gamePassId == VIP_GAMEPASS_ID`, langsung update role pemain ke `"VIP"` di cache server dan attribute pemain: `player:SetAttribute("Role", "VIP")`.
  * Panggil `MarketplaceService:GetProductInfoAsync` dengan `pcall` untuk mendapatkan nama Gamepass.
  * Kirim payload data pembelian ke `MessagingService` menggunakan topik `"GlobalGamePassPurchase"`.

- [ ] **Langkah 3: Berlangganan (Subscribe) ke Topik Global**
  Di dalam `RoleManager.Init()`, tambahkan langganan `MessagingService:SubscribeAsync("GlobalGamePassPurchase")`:
  * Terima payload data pembelian global.
  * Susun teks pengumuman menggunakan rich text dan tambahkan ikon bola dunia `🌐` di depannya.
  * Siarkan ke chat server lokal menggunakan `TextChatService` dan fallback `Legacy ChatService`.

---

## Tugas 3: Pengujian & Verifikasi Akhir
- [ ] **Langkah 1: Tes Gacha Box Lokal**
  Buka box dan pastikan pengumuman muncul di chat lokal jika mendapatkan mobil Epic ke atas.
- [ ] **Langkah 2: Tes Pembelian Gamepass Global**
  Simulasikan pembelian gamepass di server dan pastikan pesan pengumuman global terkirim serta peran VIP langsung terpasang.

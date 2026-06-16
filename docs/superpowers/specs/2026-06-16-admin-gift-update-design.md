# Spesifikasi Desain: Update Fitur Admin Gift Box & Car

Dokumen ini menjelaskan perubahan yang diperlukan untuk memperbarui sistem gift admin pada `EventManager.server.luau` dan `AdminEventPanel.luau`.

---

## 1. Ringkasan Perubahan

| Fitur | Sebelum | Sesudah |
|---|---|---|
| Instant gift box | Level 12, variant Admin | **Level 30**, variant Admin (fixed) |
| Gift box by level | Level picker saja | Level picker + **multi-select variant tambahan** |
| Gift car instant | Tidak ada | **Baru: dropdown mobil dari `F1 CARS/Admin/`**, variant Admin fixed |
| Gift car by name | Search + gift tanpa variant | Search + gift + **multi-select variant tambahan** |
| Variant Admin | Selalu diterapkan | **Tetap selalu otomatis**, tidak muncul sebagai opsi pilihan |

---

## 2. Perubahan Server-side (`EventManager.server.luau`)

### 2A. `giftBoxToPlayer` — Signature Baru

```lua
local function giftBoxToPlayer(player: Player, level: number, extraVariants: {string}?)
```

- Variant string dibangun: mulai dari `"Admin"`, lalu append extraVariants yang dipilih.
- Contoh: `extraVariants = {"Rainbow", "Hellfire"}` → variant string = `"Admin,Rainbow,Hellfire"`
- Jika `extraVariants` kosong atau nil → variant string = `"Admin"`
- Level untuk instant gift = **30** (bukan 12 seperti sebelumnya).

**Logika build variant string:**
```lua
local variantStr = "Admin"
if extraVariants and #extraVariants > 0 then
    variantStr = "Admin," .. table.concat(extraVariants, ",")
end
newBox:SetAttribute("Variants", variantStr)
```

### 2B. `giftCarToPlayer` — Signature Baru

```lua
local function giftCarToPlayer(player: Player, carName: string, extraVariants: {string}?)
```

- Variant mobil dimulai dari `"Admin"`, kemudian digabung dengan extraVariants.
- Contoh: `extraVariants = {"Galaxy"}` → variant = `"Admin,Galaxy"`
- Jika kosong → variant = `"Admin"`
- Untuk Instant Admin Car, `carName` diambil dari folder `F1 CARS/Admin/` dan `extraVariants = nil`.

**Logika build variant string:**
```lua
local variantStr = "Admin"
if extraVariants and #extraVariants > 0 then
    variantStr = "Admin," .. table.concat(extraVariants, ",")
end
car:SetAttribute("Variant", variantStr)
```

### 2C. Endpoint Baru: `getAdminCars(player)`

```lua
function AdminEventService:getAdminCars(player: Player): { { Name: string } }
```

- Memerlukan permission `"EditGameConfigs"`.
- Scan `ServerStorage/F1 CARS/Admin/` dan kembalikan list nama semua Tool/Model di dalamnya.
- Rarity selalu `"Admin"` (hardcoded, diambil dari nama folder).

**Return format:**
```lua
{ { Name = "Paindre Edition" }, { Name = "NamaMobil2" }, ... }
```

### 2D. `giftLocalPlayer` & `giftPlayerReward` — Teruskan `ExtraVariants`

- `params.ExtraVariants` (array string) diteruskan dari endpoint ke `giftBoxToPlayer` dan `giftCarToPlayer`.
- Endpoint `giftPlayerReward` tidak perlu perubahan signature — `extraVariants` sudah masuk lewat `params`.

### 2E. Networker — Daftarkan `getAdminCars`

```lua
Networker.server.new("AdminEventService", AdminEventService, {
    AdminEventService.setEventValues,
    AdminEventService.stopAllEvents,
    AdminEventService.broadcastMessage,
    AdminEventService.giftPlayerReward,
    AdminEventService.getAvailableCars,
    AdminEventService.getAdminCars, -- BARU
})
```

---

## 3. Perubahan UI Client (`AdminEventPanel.luau`)

### 3A. State Baru

```lua
-- Gift Box variant tambahan
local boxExtraVariants, setBoxExtraVariants = useState({} :: {string})

-- Gift Car (Instant Admin)
local adminCars, setAdminCars = useState({} :: { {Name: string} })
local selectedAdminCar, setSelectedAdminCar = useState("")
local isAdminCarDropdownOpen, setIsAdminCarDropdownOpen = useState(false)

-- Gift Car (by Name) variant tambahan
local carExtraVariants, setCarExtraVariants = useState({} :: {string})
```

### 3B. Load Admin Cars on Mount

```lua
useEffect(function()
    if props.getAdminCars then
        task.spawn(function()
            local cars = props.getAdminCars()
            if cars then setAdminCars(cars) end
        end)
    end
end, {})
```

### 3C. Helper: `createVariantPicker(selectedVariants, setSelectedVariants)`

Fungsi reusable yang menghasilkan baris toggle-button untuk memilih variant tambahan.

- Variant yang tersedia: `Rainbow`, `Frostbite`, `Galaxy`, `Hellfire`, `Cosmic`, `Golden`
- Admin **tidak ditampilkan** (sudah fixed)
- Toggle: klik variant yang belum dipilih → masuk ke array; klik lagi → keluar dari array
- Styling: aktif = warna accent (biru/ungu), tidak aktif = abu-abu gelap
- Di bawah picker, tampilkan label kecil: `"🔒 Admin variant sudah otomatis ditambahkan"`

### 3D. Perubahan BoxRow

**Instant button** — diubah dari `"FAST LEVEL 12 BOX"` menjadi `"⚡ INSTAN LV.30 ADMIN BOX"`:
```lua
props.onGiftReward("Box", target, isGlobalGift, { Level = 30, ExtraVariants = {} })
```

**Gift Box button** — tambahkan `ExtraVariants`:
```lua
props.onGiftReward("Box", target, isGlobalGift, { Level = giftBoxLevel, ExtraVariants = boxExtraVariants })
```

**Tambahkan variant picker** di bawah row utama (gunakan `createVariantPicker`).

**BoxRow height** — naikkan dari `66` menjadi `120`.

### 3E. Perubahan CarRow

CarRow dipisah menjadi 2 sub-section dalam satu frame:

**Sub-section A — Instant Admin Car (BARU):**
- Label: `"🏆 ADMIN CAR"`
- Dropdown sederhana menampilkan list dari `adminCars` state
- Klik nama mobil → `setSelectedAdminCar(car.Name)`, tutup dropdown
- Tombol `"⚡ GIFT ADMIN CAR"`: aktif hanya jika `selectedAdminCar ~= ""`
  ```lua
  props.onGiftReward("Car", target, isGlobalGift, { CarName = selectedAdminCar, ExtraVariants = {} })
  ```
- Tidak ada variant picker — Admin fixed.

**Sub-section B — Gift Car by Name (EXISTING, diperluas):**
- Label: `"🔍 CARI MOBIL"`
- Search box + autocomplete dropdown tetap sama
- Tambahkan variant picker (`createVariantPicker`) di bawah search
- Tombol `"GIFT MOBIL"` — tambahkan `ExtraVariants`:
  ```lua
  props.onGiftReward("Car", target, isGlobalGift, { CarName = carSearchText, ExtraVariants = carExtraVariants })
  ```

**CarRow height** — naikkan dari `80` menjadi `210`.

---

## 4. Alur Data Lengkap (Gift Box dengan Variant Tambahan)

```
Admin klik variant [Rainbow] + [Hellfire] di BoxRow
    → boxExtraVariants = {"Rainbow", "Hellfire"}
Admin klik "GIFT BOX" (Level 15)
    → onGiftReward("Box", "All", true, { Level = 15, ExtraVariants = {"Rainbow", "Hellfire"} })
    → Server: giftBoxToPlayer(player, 15, {"Rainbow", "Hellfire"})
    → variantStr = "Admin,Rainbow,Hellfire"
    → newBox:SetAttribute("Variants", "Admin,Rainbow,Hellfire")
    → Box masuk ke backpack player dengan variant Admin+Rainbow+Hellfire
```

---

## 5. Alur Data Lengkap (Instant Admin Car)

```
Admin buka dropdown Admin Car → pilih "Paindre Edition"
    → selectedAdminCar = "Paindre Edition"
Admin klik "GIFT ADMIN CAR"
    → onGiftReward("Car", "All", true, { CarName = "Paindre Edition", ExtraVariants = {} })
    → Server: giftCarToPlayer(player, "Paindre Edition", {})
    → Cari di F1 CARS/Admin/Paindre Edition
    → variantStr = "Admin"
    → car masuk ke backpack dengan Rarity=Admin, Variant=Admin
```

---

## 6. Variant yang Bisa Dipilih (Extra)

| Nama | Emoji | Key String |
|---|---|---|
| Rainbow | 🌈 | `"Rainbow"` |
| Frostbite | ❄️ | `"Frostbite"` |
| Galaxy | 🌌 | `"Galaxy"` |
| Hellfire | 🔥 | `"Hellfire"` |
| Cosmic | 🌀 | `"Cosmic"` |
| Golden | 🔱 | `"Golden"` |

Admin tidak masuk daftar ini — selalu otomatis ditambahkan server-side.

---

## 7. File yang Diubah

| File | Jenis Perubahan |
|---|---|
| `src/ServerScriptService/EventManager.server.luau` | Update `giftBoxToPlayer`, `giftCarToPlayer`, `giftLocalPlayer`, tambah `getAdminCars`, daftarkan ke Networker |
| `src/StarterPlayer/StarterPlayerScripts/components/AdminEventPanel/AdminEventPanel.luau` | Tambah state baru, helper `createVariantPicker`, update BoxRow, update CarRow |
| `src/StarterPlayer/StarterPlayerScripts/MountAdminEventPanel.client.luau` | Tambah prop `getAdminCars` ke komponen |

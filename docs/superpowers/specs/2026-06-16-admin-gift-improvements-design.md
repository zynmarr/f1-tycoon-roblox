# Design Spec: Admin Gift Box & Car Feature Improvements
Date: 2026-06-16

---

## 1. Overview & Purpose
This document specifies the improvements to the **Admin Event Panel** gifting system (Gifts Tab). The goals are to simplify instant gifting of premium items (Level 30 Box and Admin Cars) and to allow admins to select multiple additional variants dynamically when gifting custom boxes or searching/gifting cars.

---

## 2. Requirements & User Intent
*   **Default Variant Behavior:** Every box or car gifted by an admin will automatically receive the `"Admin"` variant as its primary variant.
*   **Multi-Variant Selection:** For regular/custom gifts, admins can select multiple additional variants (e.g. `Golden`, `Rainbow`, `Galaxy`, etc.). These extra variants will be appended to the primary `"Admin"` variant as a comma-separated string (e.g., `"Admin,Golden,Rainbow"`).
*   **Instant Gift Box:** 
    *   One-click button that directly awards a **Level 30 Box** with the **"Admin"** variant.
    *   No level input or extra variant choices are needed for this button.
*   **Instant Gift Car:** 
    *   A list/dropdown displaying all cars loaded from the server's `F1 CARS/Admin/` folder.
    *   A button to gift the selected Admin car instantly with the **"Admin"** variant.
    *   No manual car search or extra variant choices are needed for this button.
*   **Custom Gift Car Search:**
    *   Keep the existing autocomplete search textbox for custom car gifting.
    *   When a custom car is gifted, it also automatically receives the `"Admin"` variant, plus any additional variants selected by the admin via a multi-select dropdown.

---

## 3. Server-side Architecture & Data Model

### 3.1. Networker Endpoint
The `AdminEventService:giftPlayerReward(player, giftType, targetPlayerName, isGlobal, params)` endpoint on [EventManager.server.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/ServerScriptService/EventManager.server.luau) will handle extra parameters in `params`:
*   `Level` (number, default: 30 for instant box)
*   `CarName` (string)
*   `ExtraVariants` (array of strings, e.g., `{"Golden", "Rainbow"}`)

### 3.2. Variant Construction
When processing the variant attribute in `giftBoxToPlayer` and `giftCarToPlayer`:
```luau
local finalVariants = "Admin"
if params.ExtraVariants and #params.ExtraVariants > 0 then
    -- Validate that all variants exist in GameConfig.Variants to prevent exploit payloads
    local validExtras = {}
    for _, variantName in ipairs(params.ExtraVariants) do
        if GameConfig.Variants[variantName] then
            table.insert(validExtras, variantName)
        end
    end
    if #validExtras > 0 then
        finalVariants = finalVariants .. "," .. table.concat(validExtras, ",")
    end
end
```

### 3.3. Admin Car Query
The `giftCarToPlayer` function will resolve the template from `ServerStorage/F1 CARS/Admin` dynamically if it exists:
```luau
local adminFolder = ServerStorage:FindFirstChild("F1 CARS") and ServerStorage["F1 CARS"]:FindFirstChild("Admin")
local adminTemplate = adminFolder and adminFolder:FindFirstChild(carName)

if adminTemplate then
    foundTemplate = adminTemplate
    foundRarity = "Admin"
else
    -- Fallback to search through CollectionService tagged "Car" models
end
```

---

## 4. Client-side UI & State Management

### 4.1. Local State Variables in `AdminEventPanel.luau`
The [AdminEventPanel.luau](file:///C:/Project/Roblox%20Studio%20Projects/Projects/F1-Tycoon/src/StarterPlayer/StarterPlayerScripts/components/AdminEventPanel/AdminEventPanel.luau) component will maintain the following states:
```luau
local selectedBoxVariants, setSelectedBoxVariants = useState({} :: { [string]: boolean })
local selectedCarVariants, setSelectedCarVariants = useState({} :: { [string]: boolean })
local isBoxDropdownOpen, setIsBoxDropdownOpen = useState(false)
local isCarDropdownOpen, setIsCarDropdownOpen = useState(false)
local selectedAdminCar, setSelectedAdminCar = useState("")
local isAdminCarDropdownOpen, setIsAdminCarDropdownOpen = useState(false)
```

### 4.2. UI Elements & Layout Structure
*   **Box Gifting Section:**
    *   *Input Row:* Label `Level (1-30)` -> `TextBox` (Level input) -> `GIFT BOX` button -> `🎁 INSTANT BOX LV 30` button.
    *   *Variant Row:* Dropdown button `Varian Tambahan (None | +N Selected)` that toggles the dropdown overlay containing checkboxes for `Carbon`, `Shiny`, `Golden`, `Rainbow`, `Frostbite`, `Galaxy`, `Hellfire`, `Cosmic`.
*   **Car Gifting Section:**
    *   *Search & Autocomplete Row:* Autocomplete search textbox -> `GIFT MOBIL` button -> Dropdown selector for Admin Cars (lists cars fetched with rarity `"Admin"`) -> `⚡ INSTANT ADMIN CAR` button.
    *   *Variant Row:* Dropdown button `Varian Tambahan (None | +N Selected)` identical to the Box section.

---

## 5. Edge Cases & Validations

| Edge Case | Description | Mitigation |
| :--- | :--- | :--- |
| **Empty Admin Folder** | If no Admin cars exist in `ServerStorage/F1 CARS/Admin/`. | Client UI will show "No Admin Cars Found" in the dropdown list and disable the "Instant Gift Car" button. |
| **Inventory Full** | Target player has full inventory (capacity >= 50). | Server-side check in `giftCarToPlayer` returns false and does not award the car. Response with error message is sent. |
| **Invalid/Malicious Variant Name** | Network payload sent with unregistered variant name. | Server-side validation parses names against `GameConfig.Variants` and discards invalid entries. |
| **Duplicate/Multiple stack of same item** | Admin gifts same car/variant combo multiple times. | Server-side stack logic will increment the `Amount` attribute on the existing tool stack in player's Backpack instead of cloning new tools. |

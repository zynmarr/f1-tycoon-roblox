# Admin Gift Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the new Admin Gift capabilities from the `2026-06-16-admin-gift-update-design.md` spec, enabling instant level 30 admin boxes, multi-select variants for boxes and cars, and a dropdown for instant admin cars.

**Architecture:** 
1. Update `EventManager.server.luau` to handle `ExtraVariants` arrays, build comma-separated variant strings, change the instant box level to 30, and expose a new `getAdminCars` network endpoint.
2. Update `MountAdminEventPanel.client.luau` to pass `getAdminCars` to the UI component.
3. Update `AdminEventPanel.luau` to introduce variant pickers, a dropdown for admin cars, and integrate `ExtraVariants` and `CarName` properties into the payload sent to the server.

**Tech Stack:** Luau, React (Roblox), Networker.

---

### Task 1: Update Server-Side Logic (`EventManager.server.luau`)

**Files:**
- Modify: `src/ServerScriptService/EventManager.server.luau`

- [ ] **Step 1: Update `giftBoxToPlayer` Signature and Logic**
Update the signature to accept `extraVariants` and build the comma-separated string.
Edit `src/ServerScriptService/EventManager.server.luau`:
Replace the `giftBoxToPlayer` function:
```lua
local function giftBoxToPlayer(player: Player, level: number, extraVariants: {string}?)
        local boxTemplate = game:GetService("ServerStorage"):FindFirstChild("Box")
        local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
        if not boxTemplate then
                warn("[EventManager] Box template tidak ditemukan di ServerStorage!")
                return false
        end

        local backpack = player:FindFirstChild("Backpack")
        if not backpack then
                return false
        end

        local newBox = boxTemplate:Clone()

        -- Unanchor all parts to prevent player flinging
        for _, part in ipairs(newBox:GetDescendants()) do
                if part:IsA("BasePart") then
                        part.Anchored = false
                        part.CanCollide = false
                end
        end

        -- Build variant string
        local variantStr = "Admin"
        if extraVariants and #extraVariants > 0 then
                variantStr = "Admin," .. table.concat(extraVariants, ",")
        end

        newBox:SetAttribute("Level", level)
        newBox:SetAttribute("Variants", variantStr)
        newBox.Parent = backpack

        return true
end
```

- [ ] **Step 2: Update `giftCarToPlayer` Signature and Logic**
Update the signature to accept `extraVariants` and build the comma-separated string.
Edit `src/ServerScriptService/EventManager.server.luau`:
Replace the `giftCarToPlayer` function:
```lua
local function giftCarToPlayer(player: Player, carName: string, extraVariants: {string}?)
        local CollectionService = game:GetService("CollectionService")
        local ServerStorage = game:GetService("ServerStorage")
        local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

        local f1Cars = ServerStorage:FindFirstChild("F1 CARS")
        local adminFolder = f1Cars and f1Cars:FindFirstChild("Admin")
        
        local foundTemplate = nil
        local foundRarity = ""

        -- First check if it's an admin car
        local adminTemplate = adminFolder and adminFolder:FindFirstChild(carName)
        if adminTemplate then
                foundTemplate = adminTemplate
                foundRarity = "Admin"
        else
                for _, carTemplate in ipairs(CollectionService:GetTagged("Car")) do
                        if carTemplate:IsDescendantOf(ServerStorage) and carTemplate.Name == carName then
                                foundTemplate = carTemplate
                                local parent = carTemplate.Parent
                                if parent and parent:IsA("Folder") then
                                        foundRarity = parent.Name
                                end
                                break
                        end
                end
        end

        if not foundTemplate then
                warn("[EventManager] Mobil dengan nama " .. tostring(carName) .. " tidak ditemukan!")
                return false
        end

        local backpack = player:FindFirstChild("Backpack")
        if not backpack then
                return false
        end

        local car = foundTemplate:Clone()

        -- Build variant string
        local variantStr = "Admin"
        if extraVariants and #extraVariants > 0 then
                variantStr = "Admin," .. table.concat(extraVariants, ",")
        end

        car:SetAttribute("Rarity", foundRarity)
        car:SetAttribute("Variant", variantStr)
        
        -- Default stats from config
        local stats = GameConfig.CarStats[carName]
        if stats then
                car:SetAttribute("TopSpeed", stats.TopSpeed or 0)
                car:SetAttribute("Acceleration", stats.Acceleration or 0)
                car:SetAttribute("Handling", stats.Handling or 0)
                car:SetAttribute("Value", stats.Value or 0)
        end

        local existingCar = backpack:FindFirstChild(carName)
        if existingCar then
                local carAmount = existingCar:GetAttribute("Amount") or 1
                existingCar:SetAttribute("Amount", carAmount + 1)
                car:Destroy()
        else
                car:SetAttribute("Amount", 1)
                car.Parent = backpack
        end

        return true
end
```

- [ ] **Step 3: Update `giftLocalPlayer` to Pass `ExtraVariants`**
Ensure `ExtraVariants` is passed to the core functions. Note: we need to find `giftLocalPlayer` and update its Box and Car branches.
Edit `src/ServerScriptService/EventManager.server.luau`:
Inside `local function giftLocalPlayer(targetPlayerName, giftType, params)`, locate the `elseif giftType == "Box" then` and `elseif giftType == "Car" then` blocks and replace them:
```lua
                    elseif giftType == "Box" then
                            local level = params.Level or 30
                            local extraVariants = params.ExtraVariants or {}
                            giftBoxToPlayer(p, level, extraVariants)
                    elseif giftType == "Car" then
                            local carName = params.CarName or "Paindre Edition"
                            local extraVariants = params.ExtraVariants or {}
                            giftCarToPlayer(p, carName, extraVariants)
```

- [ ] **Step 4: Implement `getAdminCars`**
Add the new endpoint function before `AdminEventService:setEventValues`.
Edit `src/ServerScriptService/EventManager.server.luau`:
```lua
function AdminEventService:getAdminCars(player: Player): { { Name: string } }
        local playerRole = (player:GetAttribute("Role") :: string?) or "Player"
        local roleData = (RoleConfig.Roles :: any)[playerRole]

        if not roleData or not roleData.Permissions["EditGameConfigs"] then
                warn("[EventManager] Player " .. player.Name .. " mencoba mengambil list admin car tanpa permission!")
                return {}
        end

        local cars = {}
        local f1Cars = game:GetService("ServerStorage"):FindFirstChild("F1 CARS")
        local adminFolder = f1Cars and f1Cars:FindFirstChild("Admin")
        
        if adminFolder then
                for _, item in ipairs(adminFolder:GetChildren()) do
                        if item:IsA("Tool") or item:IsA("Model") then
                                table.insert(cars, { Name = item.Name })
                        end
                end
        end

        table.sort(cars, function(a, b) return a.Name < b.Name end)
        return cars
end
```

- [ ] **Step 5: Register `getAdminCars` in Networker**
Update the Networker initialization at the bottom of the script.
Edit `src/ServerScriptService/EventManager.server.luau`:
Locate `Networker.server.new("AdminEventService", AdminEventService, {` and add `AdminEventService.getAdminCars` to the table:
```lua
Networker.server.new("AdminEventService", AdminEventService, {
        AdminEventService.setEventValues,
        AdminEventService.stopAllEvents,
        AdminEventService.broadcastMessage,
        AdminEventService.giftPlayerReward,
        AdminEventService.getAvailableCars,
        AdminEventService.getAdminCars,
})
```

### Task 2: Pass Endpoint to Client UI

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/MountAdminEventPanel.client.luau`

- [ ] **Step 1: Pass `getAdminCars` Prop**
Edit `src/StarterPlayer/StarterPlayerScripts/MountAdminEventPanel.client.luau`:
Locate the `root:render(React.createElement(AdminEventPanel, {` block and add the `getAdminCars` prop:
```lua
                getAvailableCars = function()
                        return adminEventService:fetch("getAvailableCars") :: any
                end,
                getAdminCars = function()
                        return adminEventService:fetch("getAdminCars") :: any
                end,
```

### Task 3: Update Client UI Component (`AdminEventPanel.luau`)

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/components/AdminEventPanel/AdminEventPanel.luau`

- [ ] **Step 1: Add New State Variables**
Locate `-- 4. STATE FOR GIFTS (TAB 3)` in `AdminEventPanel.luau` and add the new states.
```lua
        -- 4. STATE FOR GIFTS (TAB 3)
        local targetType, setTargetType = useState("All") -- "All" | "Specific"
        local targetPlayerName, setTargetPlayerName = useState("")
        local isGlobalGift, setIsGlobalGift = useState(true)

        local giftBoxLevel, setGiftBoxLevel = useState(1)
        local boxExtraVariants, setBoxExtraVariants = useState({} :: {string})

        local carSearchText, setCarSearchText = useState("")
        local availableCars, setAvailableCars = useState({} :: {CarData})
        local isCarDropdownOpen, setIsCarDropdownOpen = useState(false)
        local carExtraVariants, setCarExtraVariants = useState({} :: {string})

        local adminCars, setAdminCars = useState({} :: { {Name: string} })
        local selectedAdminCar, setSelectedAdminCar = useState("")
        local isAdminCarDropdownOpen, setIsAdminCarDropdownOpen = useState(false)
```

- [ ] **Step 2: Fetch Admin Cars on Mount**
Locate the `useEffect` block that fetches available cars, and add logic to fetch admin cars.
```lua
        -- Fetch available cars & admin cars on mount
        useEffect(function()
                if props.getAvailableCars then
                        task.spawn(function()
                                local cars = props.getAvailableCars()
                                if cars then
                                        setAvailableCars(cars)
                                end
                        end)
                end
                if props.getAdminCars then
                        task.spawn(function()
                                local cars = props.getAdminCars()
                                if cars then
                                        setAdminCars(cars)
                                end
                        end)
                end
        end, {})
```

- [ ] **Step 3: Create Variant Picker Helper**
Before `local renderTabContent = function()`, add the `createVariantPicker` helper:
```lua
        local function createVariantPicker(selectedVariants: {string}, setSelectedVariants: (any) -> ())
                local variants = {
                        {Name = "Rainbow", Emoji = "🌈"},
                        {Name = "Frostbite", Emoji = "❄️"},
                        {Name = "Galaxy", Emoji = "🌌"},
                        {Name = "Hellfire", Emoji = "🔥"},
                        {Name = "Cosmic", Emoji = "🌀"},
                        {Name = "Golden", Emoji = "🔱"},
                }

                local buttons = {}
                for i, variant in ipairs(variants) do
                        local isSelected = table.find(selectedVariants, variant.Name) ~= nil
                        table.insert(buttons, e("TextButton", {
                                Key = "Var_" .. variant.Name,
                                Text = variant.Emoji .. " " .. variant.Name,
                                Font = Enum.Font.GothamBold,
                                TextSize = 12,
                                TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150),
                                BackgroundColor3 = isSelected and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(40, 40, 45),
                                Size = UDim2.new(0, 80, 0, 25),
                                AutoButtonColor = true,
                                LayoutOrder = i,
                                [Event.Activated] = function()
                                        local newVariants = table.clone(selectedVariants)
                                        if isSelected then
                                                local index = table.find(newVariants, variant.Name)
                                                if index then table.remove(newVariants, index) end
                                        else
                                                table.insert(newVariants, variant.Name)
                                        end
                                        setSelectedVariants(newVariants)
                                end,
                        }, {
                                UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) })
                        }))
                end

                return e("Frame", {
                        Size = UDim2.new(1, 0, 0, 50),
                        BackgroundTransparency = 1,
                        LayoutOrder = 10,
                }, {
                        Layout = e("UIListLayout", {
                                FillDirection = Enum.FillDirection.Vertical,
                                SortOrder = Enum.SortOrder.LayoutOrder,
                                Padding = UDim.new(0, 5),
                                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        }),
                        ButtonsFrame = e("Frame", {
                                Size = UDim2.new(1, 0, 0, 25),
                                BackgroundTransparency = 1,
                                LayoutOrder = 1,
                        }, {
                                Layout = e("UIListLayout", {
                                        FillDirection = Enum.FillDirection.Horizontal,
                                        SortOrder = Enum.SortOrder.LayoutOrder,
                                        Padding = UDim.new(0, 5),
                                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                                }),
                                React.Children.toArray(buttons)
                        }),
                        Label = e("TextLabel", {
                                Size = UDim2.new(1, 0, 0, 15),
                                BackgroundTransparency = 1,
                                Text = "🔒 Admin variant otomatis ditambahkan",
                                TextColor3 = Color3.fromRGB(150, 150, 150),
                                TextSize = 10,
                                Font = Enum.Font.Gotham,
                                LayoutOrder = 2,
                        })
                })
        end
```

- [ ] **Step 4: Update BoxRow Component**
Inside `renderTabContent` -> `if activeTab == "Gifts"`, update `BoxRow`:
1. Change Height to `120`.
2. Add Variant Picker.
3. Update Instant Box parameter (`Level = 30`).
4. Add `ExtraVariants` parameter to Gift Box button.

Replace the existing `BoxRow` block with:
```lua
                                BoxRow = e("Frame", {
                                        Size = UDim2.new(1, 0, 0, 120),
                                        BackgroundColor3 = Color3.fromRGB(30, 30, 35),
                                        LayoutOrder = 3,
                                }, {
                                        UICorner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
                                        UIPadding = e("UIPadding", {
                                                PaddingTop = UDim.new(0, 10),
                                                PaddingBottom = UDim.new(0, 10),
                                                PaddingLeft = UDim.new(0, 15),
                                                PaddingRight = UDim.new(0, 15),
                                        }),
                                        Layout = e("UIListLayout", {
                                                FillDirection = Enum.FillDirection.Vertical,
                                                SortOrder = Enum.SortOrder.LayoutOrder,
                                                Padding = UDim.new(0, 10),
                                        }),
                                        TopControls = e("Frame", {
                                                Size = UDim2.new(1, 0, 0, 30),
                                                BackgroundTransparency = 1,
                                                LayoutOrder = 1,
                                        }, {
                                                Layout = e("UIListLayout", {
                                                        FillDirection = Enum.FillDirection.Horizontal,
                                                        SortOrder = Enum.SortOrder.LayoutOrder,
                                                        Padding = UDim.new(0, 10),
                                                        VerticalAlignment = Enum.VerticalAlignment.Center,
                                                }),
                                                Icon = e("TextLabel", {
                                                        Size = UDim2.new(0, 30, 0, 30),
                                                        BackgroundTransparency = 1,
                                                        Text = "📦",
                                                        TextSize = 20,
                                                        LayoutOrder = 1,
                                                }),
                                                Title = e("TextLabel", {
                                                        Size = UDim2.new(0, 100, 0, 30),
                                                        BackgroundTransparency = 1,
                                                        Text = "GIFT BOX",
                                                        TextColor3 = Color3.fromRGB(220, 220, 220),
                                                        TextSize = 14,
                                                        Font = Enum.Font.GothamBold,
                                                        TextXAlignment = Enum.TextXAlignment.Left,
                                                        LayoutOrder = 2,
                                                }),
                                                LevelInput = e("TextBox", {
                                                        Size = UDim2.new(0, 60, 0, 30),
                                                        BackgroundColor3 = Color3.fromRGB(20, 20, 25),
                                                        TextColor3 = Color3.fromRGB(255, 255, 255),
                                                        Text = tostring(giftBoxLevel),
                                                        Font = Enum.Font.GothamBold,
                                                        TextSize = 14,
                                                        PlaceholderText = "Lv",
                                                        LayoutOrder = 3,
                                                        [Event.FocusLost] = function(rbx)
                                                                local val = tonumber(rbx.Text)
                                                                if val then setGiftBoxLevel(val) else rbx.Text = tostring(giftBoxLevel) end
                                                        end,
                                                }, { UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
                                                GiftBtn = e("TextButton", {
                                                        Size = UDim2.new(0, 90, 0, 30),
                                                        BackgroundColor3 = Color3.fromRGB(40, 150, 80),
                                                        TextColor3 = Color3.fromRGB(255, 255, 255),
                                                        Text = "GIFT BOX",
                                                        Font = Enum.Font.GothamBold,
                                                        TextSize = 12,
                                                        LayoutOrder = 4,
                                                        [Event.Activated] = function()
                                                                local target = targetType == "All" and "All" or targetPlayerName
                                                                if target == "" then return end
                                                                if props.onGiftReward then
                                                                        props.onGiftReward("Box", target, isGlobalGift, { Level = giftBoxLevel, ExtraVariants = boxExtraVariants })
                                                                end
                                                        end,
                                                }, { UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
                                                Spacer = e("Frame", { Size = UDim2.new(1, -330, 0, 30), BackgroundTransparency = 1, LayoutOrder = 5 }),
                                                InstantBtn = e("TextButton", {
                                                        Size = UDim2.new(0, 200, 0, 30),
                                                        BackgroundColor3 = Color3.fromRGB(160, 40, 160),
                                                        TextColor3 = Color3.fromRGB(255, 255, 255),
                                                        Text = "⚡ INSTAN LV.30 ADMIN BOX",
                                                        Font = Enum.Font.GothamBold,
                                                        TextSize = 12,
                                                        LayoutOrder = 6,
                                                        [Event.Activated] = function()
                                                                local target = targetType == "All" and "All" or targetPlayerName
                                                                if target == "" then return end
                                                                if props.onGiftReward then
                                                                        props.onGiftReward("Box", target, isGlobalGift, { Level = 30, ExtraVariants = {} })
                                                                end
                                                        end,
                                                }, { UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
                                        }),
                                        createVariantPicker(boxExtraVariants, setBoxExtraVariants)
                                }),
```

- [ ] **Step 5: Update CarRow Component**
Inside `renderTabContent` -> `if activeTab == "Gifts"`, update `CarRow`.
This requires completely replacing the `CarRow` logic to split it into Sub-section A (Admin Car) and Sub-section B (Search Car). Due to the complexity, replace the `CarRow` definition with:

```lua
                                CarRow = e("Frame", {
                                        Size = UDim2.new(1, 0, 0, 210),
                                        BackgroundColor3 = Color3.fromRGB(30, 30, 35),
                                        LayoutOrder = 4,
                                }, {
                                        UICorner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
                                        UIPadding = e("UIPadding", {
                                                PaddingTop = UDim.new(0, 10),
                                                PaddingBottom = UDim.new(0, 10),
                                                PaddingLeft = UDim.new(0, 15),
                                                PaddingRight = UDim.new(0, 15),
                                        }),
                                        Layout = e("UIListLayout", {
                                                FillDirection = Enum.FillDirection.Vertical,
                                                SortOrder = Enum.SortOrder.LayoutOrder,
                                                Padding = UDim.new(0, 10),
                                        }),
                                        -- Sub-section A: Instant Admin Car
                                        AdminCarSection = e("Frame", {
                                                Size = UDim2.new(1, 0, 0, 30),
                                                BackgroundTransparency = 1,
                                                LayoutOrder = 1,
                                        }, {
                                                Layout = e("UIListLayout", {
                                                        FillDirection = Enum.FillDirection.Horizontal,
                                                        SortOrder = Enum.SortOrder.LayoutOrder,
                                                        Padding = UDim.new(0, 10),
                                                        VerticalAlignment = Enum.VerticalAlignment.Center,
                                                }),
                                                Icon = e("TextLabel", {
                                                        Size = UDim2.new(0, 30, 0, 30),
                                                        BackgroundTransparency = 1,
                                                        Text = "🏆",
                                                        TextSize = 20,
                                                        LayoutOrder = 1,
                                                }),
                                                Title = e("TextLabel", {
                                                        Size = UDim2.new(0, 100, 0, 30),
                                                        BackgroundTransparency = 1,
                                                        Text = "ADMIN CAR",
                                                        TextColor3 = Color3.fromRGB(220, 220, 220),
                                                        TextSize = 14,
                                                        Font = Enum.Font.GothamBold,
                                                        TextXAlignment = Enum.TextXAlignment.Left,
                                                        LayoutOrder = 2,
                                                }),
                                                CarDropdownBtn = e("TextButton", {
                                                        Size = UDim2.new(0, 200, 0, 30),
                                                        BackgroundColor3 = Color3.fromRGB(20, 20, 25),
                                                        TextColor3 = Color3.fromRGB(255, 255, 255),
                                                        Text = selectedAdminCar ~= "" and selectedAdminCar or "Pilih Admin Car...",
                                                        Font = Enum.Font.Gotham,
                                                        TextSize = 14,
                                                        LayoutOrder = 3,
                                                        [Event.Activated] = function() setIsAdminCarDropdownOpen(not isAdminCarDropdownOpen) end,
                                                }, {
                                                        UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
                                                        DropdownList = isAdminCarDropdownOpen and e("ScrollingFrame", {
                                                                Size = UDim2.new(1, 0, 0, 150),
                                                                Position = UDim2.new(0, 0, 1, 5),
                                                                BackgroundColor3 = Color3.fromRGB(20, 20, 25),
                                                                ZIndex = 50,
                                                                CanvasSize = UDim2.new(0, 0, 0, #adminCars * 30),
                                                                ScrollBarThickness = 4,
                                                        }, {
                                                                Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
                                                                React.Children.toArray((function()
                                                                        local items = {}
                                                                        for i, car in ipairs(adminCars) do
                                                                                table.insert(items, e("TextButton", {
                                                                                        Size = UDim2.new(1, 0, 0, 30),
                                                                                        BackgroundColor3 = Color3.fromRGB(20, 20, 25),
                                                                                        TextColor3 = Color3.fromRGB(255, 255, 255),
                                                                                        Text = " " .. car.Name,
                                                                                        Font = Enum.Font.Gotham,
                                                                                        TextSize = 14,
                                                                                        TextXAlignment = Enum.TextXAlignment.Left,
                                                                                        ZIndex = 51,
                                                                                        LayoutOrder = i,
                                                                                        AutoButtonColor = true,
                                                                                        [Event.Activated] = function()
                                                                                                setSelectedAdminCar(car.Name)
                                                                                                setIsAdminCarDropdownOpen(false)
                                                                                        end,
                                                                                }))
                                                                        end
                                                                        return items
                                                                end)())
                                                        })
                                                }),
                                                GiftAdminCarBtn = e("TextButton", {
                                                        Size = UDim2.new(0, 160, 0, 30),
                                                        BackgroundColor3 = selectedAdminCar ~= "" and Color3.fromRGB(160, 40, 160) or Color3.fromRGB(60, 60, 60),
                                                        TextColor3 = Color3.fromRGB(255, 255, 255),
                                                        Text = "⚡ GIFT ADMIN CAR",
                                                        Font = Enum.Font.GothamBold,
                                                        TextSize = 12,
                                                        LayoutOrder = 4,
                                                        AutoButtonColor = selectedAdminCar ~= "",
                                                        [Event.Activated] = function()
                                                                if selectedAdminCar == "" then return end
                                                                local target = targetType == "All" and "All" or targetPlayerName
                                                                if target == "" then return end
                                                                if props.onGiftReward then
                                                                        props.onGiftReward("Car", target, isGlobalGift, { CarName = selectedAdminCar, ExtraVariants = {} })
                                                                end
                                                        end,
                                                }, { UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
                                        }),
                                        Divider = e("Frame", {
                                                Size = UDim2.new(1, 0, 0, 1),
                                                BackgroundColor3 = Color3.fromRGB(50, 50, 55),
                                                BorderSizePixel = 0,
                                                LayoutOrder = 2,
                                        }),
                                        -- Sub-section B: Cari Mobil
                                        SearchCarSection = e("Frame", {
                                                Size = UDim2.new(1, 0, 0, 30),
                                                BackgroundTransparency = 1,
                                                LayoutOrder = 3,
                                                ZIndex = 1,
                                        }, {
                                                Layout = e("UIListLayout", {
                                                        FillDirection = Enum.FillDirection.Horizontal,
                                                        SortOrder = Enum.SortOrder.LayoutOrder,
                                                        Padding = UDim.new(0, 10),
                                                        VerticalAlignment = Enum.VerticalAlignment.Center,
                                                }),
                                                Icon = e("TextLabel", {
                                                        Size = UDim2.new(0, 30, 0, 30),
                                                        BackgroundTransparency = 1,
                                                        Text = "🔍",
                                                        TextSize = 20,
                                                        LayoutOrder = 1,
                                                }),
                                                Title = e("TextLabel", {
                                                        Size = UDim2.new(0, 100, 0, 30),
                                                        BackgroundTransparency = 1,
                                                        Text = "CARI MOBIL",
                                                        TextColor3 = Color3.fromRGB(220, 220, 220),
                                                        TextSize = 14,
                                                        Font = Enum.Font.GothamBold,
                                                        TextXAlignment = Enum.TextXAlignment.Left,
                                                        LayoutOrder = 2,
                                                }),
                                                SearchWrapper = e("Frame", {
                                                        Size = UDim2.new(0, 250, 0, 30),
                                                        BackgroundTransparency = 1,
                                                        LayoutOrder = 3,
                                                        ZIndex = 10,
                                                }, {
                                                        SearchInput = e("TextBox", {
                                                                Size = UDim2.new(1, 0, 1, 0),
                                                                BackgroundColor3 = Color3.fromRGB(20, 20, 25),
                                                                TextColor3 = Color3.fromRGB(255, 255, 255),
                                                                Text = carSearchText,
                                                                Font = Enum.Font.Gotham,
                                                                TextSize = 14,
                                                                PlaceholderText = "Ketik nama mobil...",
                                                                ClearTextOnFocus = false,
                                                                ZIndex = 10,
                                                                [Event.Changed] = function(rbx, prop)
                                                                        if prop == "Text" then
                                                                                setCarSearchText(rbx.Text)
                                                                                setIsCarDropdownOpen(string.len(rbx.Text) > 0)
                                                                        end
                                                                end,
                                                                [Event.FocusLost] = function(rbx, enterPressed)
                                                                        task.delay(0.2, function() setIsCarDropdownOpen(false) end)
                                                                end,
                                                        }, { UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
                                                        Dropdown = isCarDropdownOpen and e("ScrollingFrame", {
                                                                Size = UDim2.new(1, 0, 0, 150),
                                                                Position = UDim2.new(0, 0, 1, 5),
                                                                BackgroundColor3 = Color3.fromRGB(25, 25, 30),
                                                                ZIndex = 20,
                                                                CanvasSize = UDim2.new(0, 0, 0, 0),
                                                                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                                                                ScrollBarThickness = 4,
                                                        }, {
                                                                Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
                                                                React.Children.toArray((function()
                                                                        local items = {}
                                                                        local count = 0
                                                                        local lowerSearch = string.lower(carSearchText)
                                                                        for _, car in ipairs(availableCars) do
                                                                                if string.find(string.lower(car.Name), lowerSearch, 1, true) then
                                                                                        count += 1
                                                                                        if count > 20 then break end
                                                                                        table.insert(items, e("TextButton", {
                                                                                                Size = UDim2.new(1, 0, 0, 30),
                                                                                                BackgroundColor3 = Color3.fromRGB(25, 25, 30),
                                                                                                TextColor3 = Color3.fromRGB(255, 255, 255),
                                                                                                Text = " [" .. car.Rarity .. "] " .. car.Name,
                                                                                                Font = Enum.Font.Gotham,
                                                                                                TextSize = 12,
                                                                                                TextXAlignment = Enum.TextXAlignment.Left,
                                                                                                ZIndex = 21,
                                                                                                LayoutOrder = count,
                                                                                                AutoButtonColor = true,
                                                                                                [Event.Activated] = function()
                                                                                                        setCarSearchText(car.Name)
                                                                                                        setIsCarDropdownOpen(false)
                                                                                                end,
                                                                                        }))
                                                                                end
                                                                        end
                                                                        return items
                                                                end)())
                                                        })
                                                }),
                                                GiftCarBtn = e("TextButton", {
                                                        Size = UDim2.new(0, 90, 0, 30),
                                                        BackgroundColor3 = Color3.fromRGB(40, 150, 80),
                                                        TextColor3 = Color3.fromRGB(255, 255, 255),
                                                        Text = "GIFT MOBIL",
                                                        Font = Enum.Font.GothamBold,
                                                        TextSize = 12,
                                                        LayoutOrder = 4,
                                                        [Event.Activated] = function()
                                                                local target = targetType == "All" and "All" or targetPlayerName
                                                                if target == "" or carSearchText == "" then return end
                                                                if props.onGiftReward then
                                                                        props.onGiftReward("Car", target, isGlobalGift, { CarName = carSearchText, ExtraVariants = carExtraVariants })
                                                                end
                                                        end,
                                                }, { UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
                                        }),
                                        createVariantPicker(carExtraVariants, setCarExtraVariants)
                                }),
```

- [ ] **Step 6: Commit**
```bash
git add src/ServerScriptService/EventManager.server.luau src/StarterPlayer/StarterPlayerScripts/MountAdminEventPanel.client.luau src/StarterPlayer/StarterPlayerScripts/components/AdminEventPanel/AdminEventPanel.luau
git commit -m "feat: implement admin gift box & car variant updates"
```
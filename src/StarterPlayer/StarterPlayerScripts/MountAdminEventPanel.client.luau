--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)
local Networker = require(Packages.Networker)
local RoleConfig = require(ReplicatedStorage:WaitForChild("RoleConfig"))

local AdminEventPanel = require(script.Parent.components.AdminEventPanel.AdminEventPanel)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== RETRIEVE NETWORKER SERVICE =====
local clientService = {}
local adminEventService = Networker.client.new("AdminEventService", clientService)

-- ===== REACT ROOT =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdminEventGui"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = playerGui

local root = ReactRoblox.createRoot(screenGui)

-- ===== STATE VARIABLES & HELPERS =====
local uiIsOpen = false
local adminBtn: GuiButton? = nil

local function checkAdminPermission(): boolean
	local playerRole = player:GetAttribute("Role") or "Player"
	local roleData = RoleConfig.Roles[playerRole]
	
	if playerRole == "Owner" or playerRole == "Developer" then
		return true
	elseif roleData then
		return table.find(roleData.Permissions, "EditGameConfigs") ~= nil
	end
	
	return false
end

local function updateUIRender()
	if not uiIsOpen then
		screenGui.Enabled = false
		root:render(nil)
		return
	end

	screenGui.Enabled = true

	root:render(React.createElement(AdminEventPanel, {
		onClose = function()
			uiIsOpen = false
			updateUIRender()
		end,
		onApplySettings = function(settings)
			local result = adminEventService:fetch("setEventValues", settings)
			if result and result.Success then
				print("[Client] Berhasil memperbarui konfigurasi event: " .. tostring(result.Message))
			else
				warn("[Client] Gagal memperbarui konfigurasi event: " .. tostring(result and result.Error or "Unknown error"))
			end
		end,
		onStopAll = function()
			local result = adminEventService:fetch("stopAllEvents")
			if result and result.Success then
				print("[Client] Berhasil menonaktifkan semua event: " .. tostring(result.Message))
			else
				warn("[Client] Gagal menonaktifkan semua event: " .. tostring(result and result.Error or "Unknown error"))
			end
		end,
	}))
end

-- ===== DYNAMIC SIDEBAR BUTTON MANAGEMENT =====
local function destroyAdminButton()
	if adminBtn then
		adminBtn:Destroy()
		adminBtn = nil
	end
end

local function createAdminButton()
	if adminBtn then return end -- Sudah dibuat

	local sideMenuGui = playerGui:WaitForChild("SideMenuGui", 10)
	if not sideMenuGui then
		warn("[AdminEventPanel] SideMenuGui tidak ditemukan!")
		return
	end

	local container = sideMenuGui:WaitForChild("MainContainer", 10)
	if not container then
		warn("[AdminEventPanel] MainContainer tidak ditemukan di SideMenuGui!")
		return
	end

	-- Mencari template tombol samping yang ada agar visualisasi seragam
	local template = container:FindFirstChild("RebirthBtn")
		or container:FindFirstChild("RewardsBtn")
		or container:FindFirstChildOfClass("ImageButton")
		or container:FindFirstChildOfClass("TextButton")

	if template then
		local clone = template:Clone() :: GuiButton
		clone.Name = "AdminEventBtn"

		-- Konfigurasi teks / ikon
		if clone:IsA("TextButton") then
			clone.Text = "⚙️ Event"
		end

		local textLabel = clone:FindFirstChildOfClass("TextLabel")
		if textLabel then
			textLabel.Text = "⚙️ Event"
		end

		local imageLabel = clone:FindFirstChildOfClass("ImageLabel")
		if imageLabel then
			imageLabel.Image = "rbxassetid://10617937307" -- Gear icon
		end
		
		adminBtn = clone
	else
		-- Fallback: buat tombol manual bergaya dark modern rounded jika template tidak ada
		local manualBtn = Instance.new("TextButton")
		manualBtn.Name = "AdminEventBtn"
		manualBtn.Size = UDim2.new(1, -10, 0, 40)
		manualBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		manualBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
		manualBtn.Font = Enum.Font.GothamBold
		manualBtn.TextSize = 12
		manualBtn.Text = "⚙️ Event"

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = manualBtn

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(60, 60, 75)
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = manualBtn

		adminBtn = manualBtn
	end

	adminBtn.Parent = container

	-- Setup Animasi Hover & Click sesuai SideMenuGui.client.luau
	local tweenInfo = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local ukuranAsli = adminBtn.Size
	local ukuranHover = UDim2.new(ukuranAsli.X.Scale, ukuranAsli.X.Offset + 10, ukuranAsli.Y.Scale, ukuranAsli.Y.Offset + 10)

	adminBtn.MouseEnter:Connect(function()
		if adminBtn then
			TweenService:Create(adminBtn, tweenInfo, { Size = ukuranHover }):Play()
		end
	end)

	adminBtn.MouseLeave:Connect(function()
		if adminBtn then
			TweenService:Create(adminBtn, tweenInfo, { Size = ukuranAsli }):Play()
		end
	end)

	adminBtn.MouseButton1Down:Connect(function()
		if adminBtn then
			TweenService:Create(adminBtn, TweenInfo.new(0.1), { Size = ukuranAsli }):Play()
		end
	end)

	adminBtn.MouseButton1Up:Connect(function()
		if adminBtn then
			TweenService:Create(adminBtn, tweenInfo, { Size = ukuranHover }):Play()
		end
	end)

	-- Aktifkan Klik Toggle Panel
	adminBtn.Activated:Connect(function()
		uiIsOpen = not uiIsOpen
		updateUIRender()
	end)
end

local function onRoleChanged()
	local hasPermission = checkAdminPermission()
	if hasPermission then
		createAdminButton()
	else
		destroyAdminButton()
		if uiIsOpen then
			uiIsOpen = false
			updateUIRender()
		end
	end
end

-- Hubungkan ke perubahan role dinamis
player:GetAttributeChangedSignal("Role"):Connect(onRoleChanged)

-- Jalankan sekali di awal (gunakan task.spawn/defer jika attribute butuh waktu replikasi)
task.defer(onRoleChanged)

-- ===== SHORTCUT KEYBOARD TOGGLE (F4) =====
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F4 then
		if checkAdminPermission() then
			uiIsOpen = not uiIsOpen
			updateUIRender()
		end
	end
end)

print("[Client] React AdminEventPanel mounting controller siap! Tekan F4 atau klik tombol sidebar (Admin) untuk membuka.")

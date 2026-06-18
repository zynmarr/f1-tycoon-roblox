local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ShopGui = require(script.Parent.components.ShopGui.ShopGui)

-- ===============================================
-- SHOP GUI CLIENT INITIALIZATION
-- ===============================================
local root = nil
local SHOP_RADIUS = 10 -- Radius deteksi area toko (dalam studs)
local uiIsOpen = false

-- ===== CREATE DEDICATED SCREENGUI FOR SHOP =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShopGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 14
screenGui.Enabled = false -- Mulai dalam kondisi tertutup
screenGui.Parent = playerGui
screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

-- ===== SETUP REACT ROOT ON SCREENGUI =====
root = ReactRoblox.createRoot(screenGui)

-- ===== RE-RENDER UI MANAGER =====
local function updateUIRender()
	if not root then return end

	if uiIsOpen then
		screenGui.Enabled = true
		root:render(React.createElement(ShopGui, {
			onClose = function()
				print("[ShopGui CLIENT] Pemain menutup Toko secara manual")
				uiIsOpen = false
				updateUIRender()
			end,
		}))
	else
		screenGui.Enabled = false
		root:render(nil)
	end
end

-- ===== DETECT SHOP AREA =====
local function detectShopArea()
	return GameUtils.getPlayerSellShopArea(player, "ShopArea")
end

-- ===============================================
-- PROXIMITY DETECTION LOOP (AUTO OPEN/CLOSE)
-- ===============================================
task.spawn(function()
	local wasInsideArea = false

	local function openUI()
		if uiIsOpen then return end
		print("[ShopGui CLIENT] Player masuk area Shop, membuka UI")
		uiIsOpen = true
		updateUIRender()
	end

	while true do
		task.wait(0.5)

		local char = player.Character
		local humanoidRoot = char and char:FindFirstChild("HumanoidRootPart")
		if not humanoidRoot then
			wasInsideArea = false
			continue
		end

		local shopArea = detectShopArea()
		if not shopArea then
			wasInsideArea = false
			continue
		end

		local distance = (humanoidRoot.Position - shopArea:GetPivot().Position).Magnitude
		local isNear = distance <= SHOP_RADIUS

		-- Terbuka HANYA saat transisi masuk area (dari luar ke dalam)
		if isNear and not wasInsideArea then
			openUI()
		elseif not isNear and wasInsideArea then
			-- Otomatis tutup saat melangkah keluar
			if uiIsOpen then
				print("[ShopGui CLIENT] Player keluar area Shop, menutup UI")
				uiIsOpen = false
				updateUIRender()
			end
		end

		wasInsideArea = isNear
	end
end)

print("[ShopGui Client] Inisialisasi controller Toko selesai (Loop Proximity Aktif)")

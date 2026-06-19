local MountAdminEventPanel = {}

function MountAdminEventPanel.init()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local UserInputService = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")

	local Packages = ReplicatedStorage:WaitForChild("Packages")
	local React = require(Packages.React)
	local ReactRoblox = require(Packages.ReactRoblox)
	local Networker = require(Packages.Networker)
	local RoleConfig = require(ReplicatedStorage:WaitForChild("RoleConfig") :: ModuleScript)

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
	screenGui.DisplayOrder = 15
	screenGui.Parent = playerGui
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

	local root = ReactRoblox.createRoot(screenGui)

	-- ===== STATE VARIABLES & HELPERS =====
	local uiIsOpen = false
	local adminBtnRegistered = false
	local RegisterSidebarButton = ReplicatedStorage:FindFirstChild("RegisterSidebarButton") :: BindableEvent
	if not RegisterSidebarButton then
		local bindable = Instance.new("BindableEvent")
		bindable.Name = "RegisterSidebarButton"
		bindable.Parent = ReplicatedStorage
		RegisterSidebarButton = bindable :: any
	end

	local UnregisterSidebarButton = ReplicatedStorage:FindFirstChild("UnregisterSidebarButton") :: BindableEvent
	if not UnregisterSidebarButton then
		local bindable = Instance.new("BindableEvent")
		bindable.Name = "UnregisterSidebarButton"
		bindable.Parent = ReplicatedStorage
		UnregisterSidebarButton = bindable :: any
	end

	local function checkAdminPermission(): boolean
		local playerRole = (player:GetAttribute("Role") :: string?) or "Player"
		local roleData = (RoleConfig.Roles :: any)[playerRole]

		if playerRole == "Owner" or playerRole == "Developer" then
			return true
		elseif roleData then
			return table.find(roleData.Permissions :: { string }, "EditGameConfigs") ~= nil
		end

		return false
	end

	local updateUIRender

	updateUIRender = function()
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
			onApplySettings = function(settings: any, isGlobal: boolean)
				local result = adminEventService:fetch("setEventValues", settings, isGlobal) :: any
				if result and result.Success then
					print("[Client] Berhasil memperbarui konfigurasi event: " .. tostring(result.Message))
				else
					warn(
						"[Client] Gagal memperbarui konfigurasi event: "
							.. tostring(result and result.Error or "Unknown error")
					)
				end
			end,
			onStopAll = function(isGlobal: boolean)
				local result = adminEventService:fetch("stopAllEvents", isGlobal) :: any
				if result and result.Success then
					print("[Client] Berhasil menonaktifkan semua event: " .. tostring(result.Message))
				else
					warn(
						"[Client] Gagal menonaktifkan semua event: " .. tostring(result and result.Error or "Unknown error")
					)
				end
			end,
			onBroadcastMessage = function(message: string, isGlobal: boolean)
				local result = adminEventService:fetch("broadcastMessage", message, isGlobal) :: any
				if result and result.Success then
					print("[Client] Pengumuman terkirim: " .. tostring(result.Message))
				else
					warn("[Client] Gagal mengirim pengumuman: " .. tostring(result and result.Error or "Unknown error"))
				end
			end,
			onGiftReward = function(giftType: string, targetPlayerName: string, isGlobal: boolean, params: any)
				local result =
					adminEventService:fetch("giftPlayerReward", giftType, targetPlayerName, isGlobal, params) :: any
				if result and result.Success then
					print("[Client] Gift terkirim: " .. tostring(result.Message))
				else
					warn("[Client] Gagal mengirim gift: " .. tostring(result and result.Error or "Unknown error"))
				end
			end,
			getAvailableCars = function()
				return adminEventService:fetch("getAvailableCars") :: any
			end,
			getAdminCars = function()
				return adminEventService:fetch("getAdminCars") :: any
			end,
		}))
	end

	-- ===== DYNAMIC SIDEBAR BUTTON MANAGEMENT =====
	local function destroyAdminButton()
		if adminBtnRegistered then
			UnregisterSidebarButton:Fire("AdminEvent")
			adminBtnRegistered = false
		end
	end

	local function createAdminButton()
		if adminBtnRegistered then
			return
		end
		RegisterSidebarButton:Fire({
			Name = "AdminEvent",
			Label = "Admin Event",
			Icon = "⚙️",
			Order = 5,
			Callback = function()
				uiIsOpen = not uiIsOpen
				updateUIRender()
			end,
		})
		adminBtnRegistered = true
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
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F4 then
			if checkAdminPermission() then
				uiIsOpen = not uiIsOpen
				updateUIRender()
			end
		end
	end)

	print(
		"[Client] React AdminEventPanel mounting controller siap! Tekan F4 atau klik tombol sidebar (Admin) untuk membuka."
	)
end

return MountAdminEventPanel

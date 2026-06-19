local MountMainGuiHub = {}

function MountMainGuiHub.init()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local UserInputService = game:GetService("UserInputService")
	local HttpService = game:GetService("HttpService")

	local Packages = ReplicatedStorage:WaitForChild("Packages")
	local React = require(Packages.React)
	local ReactRoblox = require(Packages.ReactRoblox)
	local Networker = require(Packages.Networker)

	local MainGuiHub = require(script.Parent.components.MainGuiHub.MainGuiHub)

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local leaderstats = player:WaitForChild("leaderstats", 15)

	-- ===== RETRIEVE ENDPOINTS =====
	local clientService = {}
	local rebirthService = Networker.client.new("RebirthService", clientService)

	-- ===== REACT ROOT =====
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RewardsRebirthGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.DisplayOrder = 15
	screenGui.Parent = playerGui
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

	local root = ReactRoblox.createRoot(screenGui)

	-- ===== STATE VARIABLES & HELPERS =====
	local uiIsOpen = false

	local function getJSONAttribute(name: string, fallback: any)
		local attr = player:GetAttribute(name)
		if not attr then
			return fallback
		end

		local success, decoded = pcall(HttpService.JSONDecode, HttpService, attr)
		if success and decoded then
			return decoded
		end
		return fallback
	end

	local updateUIRender

	updateUIRender = function()
		if not uiIsOpen then
			screenGui.Enabled = false
			root:render(nil)
			return
		end

		screenGui.Enabled = true

		local cash = leaderstats and leaderstats:FindFirstChild("Cash") and leaderstats.Cash.Value or 0
		local rebirthLevel = leaderstats and leaderstats:FindFirstChild("Rebirth") and leaderstats.Rebirth.Value or 0
		local rebirthPoints = player:GetAttribute("RebirthPoints") or 0
		local upgrades = getJSONAttribute("RebirthUpgrades", {})
		local dailyData = getJSONAttribute("DailyRewards", { Streak = 0, LastClaimTime = 0 })
		local questData = getJSONAttribute("Quests", {
			Daily = { ActiveQuests = {} },
			Milestones = { TotalCarsSold = 0, TotalBoxesOpened = 0, ClaimedMilestones = {} },
		})

		-- Render komponen utama
		root:render(React.createElement(MainGuiHub, {
			Cash = cash,
			RebirthLevel = rebirthLevel,
			RebirthPoints = rebirthPoints,
			RebirthUpgrades = upgrades,

			Streak = dailyData.Streak or 0,
			LastClaimTime = dailyData.LastClaimTime or 0,

			DailyQuests = questData.Daily and questData.Daily.ActiveQuests or {},
			MilestoneStats = questData.Milestones or { TotalCarsSold = 0, TotalBoxesOpened = 0, ClaimedMilestones = {} },

			onClose = function()
				uiIsOpen = false
				updateUIRender()
			end,

			onRebirth = function()
				local result = rebirthService:fetch("requestRebirth")
				if result and result.Success then
					print("[Client] Rebirth Berhasil: " .. tostring(result.Message))
				else
					warn("[Client] Gagal Rebirth: " .. tostring(result and result.Error or "Unknown error"))
				end
			end,

			onUpgrade = function(upgradeName: string)
				local result = rebirthService:fetch("purchaseRebirthUpgrade", upgradeName)
				if result and result.Success then
					print("[Client] Upgrade Berhasil: " .. tostring(result.Message))
				else
					warn("[Client] Gagal Upgrade: " .. tostring(result and result.Error or "Unknown error"))
				end
			end,

			onClaimReward = function()
				local result = rebirthService:fetch("claimDailyReward")
				if result and result.Success then
					print("[Client] Klaim Hadiah Berhasil: " .. tostring(result.Message))
				else
					warn("[Client] Gagal Klaim Hadiah: " .. tostring(result and result.Error or "Unknown error"))
				end
			end,

			onClaimQuest = function(questId: string)
				local result = rebirthService:fetch("claimDailyQuest", questId)
				if result and result.Success then
					print("[Client] Klaim Misi Berhasil: " .. tostring(result.Message))
				else
					warn("[Client] Gagal Klaim Misi: " .. tostring(result and result.Error or "Unknown error"))
				end
			end,

			onClaimMilestone = function(milestoneId: string)
				local result = rebirthService:fetch("claimMilestone", milestoneId)
				if result and result.Success then
					print("[Client] Klaim Pencapaian Berhasil: " .. tostring(result.Message))
				else
					warn("[Client] Gagal Klaim Pencapaian: " .. tostring(result and result.Error or "Unknown error"))
				end
			end,
		}))
	end

	-- ===== LISTEN TO STATS CHANGES TO RENDER REACTIVE =====
	if leaderstats then
		local cashVal = leaderstats:FindFirstChild("Cash")
		if cashVal then
			cashVal.Changed:Connect(function()
				if uiIsOpen then
					updateUIRender()
				end
			end)
		end

		local rebirthVal = leaderstats:FindFirstChild("Rebirth")
		if rebirthVal then
			rebirthVal.Changed:Connect(function()
				if uiIsOpen then
					updateUIRender()
				end
			end)
		end
	end

	player.AttributeChanged:Connect(function(attrName)
		if
			attrName == "RebirthPoints"
			or attrName == "RebirthUpgrades"
			or attrName == "DailyRewards"
			or attrName == "Quests"
		then
			if uiIsOpen then
				updateUIRender()
			end
		end
	end)

	-- ===== TOGGLE KEYBOARD F3 =====
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F3 then
			uiIsOpen = not uiIsOpen
			updateUIRender()
		end
	end)

	-- ===== INTEGRASI SIDEBAR DENGAN REACT HUD =====
	local RegisterSidebarButton = ReplicatedStorage:FindFirstChild("RegisterSidebarButton") :: BindableEvent
	if not RegisterSidebarButton then
		local bindable = Instance.new("BindableEvent")
		bindable.Name = "RegisterSidebarButton"
		bindable.Parent = ReplicatedStorage
		RegisterSidebarButton = bindable :: any
	end
	RegisterSidebarButton:Fire({
		Name = "RebirthRewards",
		Label = "Rebirth / Rewards",
		Icon = "🎁",
		Order = 2,
		Callback = function()
			uiIsOpen = not uiIsOpen
			updateUIRender()
		end,
	})

	print("[Client] React MountMainGuiHub sukses diinisialisasi! Tekan F3 atau klik tombol di Sidebar untuk membuka menu.")
end

return MountMainGuiHub

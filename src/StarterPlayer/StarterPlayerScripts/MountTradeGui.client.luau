--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)
local Networker = require(Packages.Networker)

local TradePanel = require(script.Parent.components.TradeGui.TradePanel)
local TradeInvitation = require(script.Parent.components.TradeGui.TradeInvitation)
local PlayerListPanel = require(script.Parent.components.TradeGui.PlayerListPanel)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local leaderstats = player:WaitForChild("leaderstats", 15)

-- ===== RETRIEVE NETWORKER SERVICE =====
local clientService = {}
local tradeService = Networker.client.new("TradeService", clientService)

-- ===== REMOTE EVENTS =====
local tradeInvitationEvent = ReplicatedStorage:WaitForChild("TradeInvitationEvent") :: RemoteEvent
local tradeStateUpdateEvent = ReplicatedStorage:WaitForChild("TradeStateUpdateEvent") :: RemoteEvent

-- ===== REACT ROOT =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TradeGui"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.DisplayOrder = 15
screenGui.Parent = playerGui
screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

local root = ReactRoblox.createRoot(screenGui)

-- ===== STATE VARIABLES =====
local activeInvitation: string? = nil
local tradeState: any = nil
local playerListIsOpen = false
local tradeBtnRegistered = false
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

-- ===== NOTIFICATION HELPER =====
local function showNotification(title: string, text: string)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = 5,
		})
	end)
end

-- ===== UPDATE RENDER FUNCTION =====
local updateRender: () -> ()
function updateRender()
	if activeInvitation then
		screenGui.Enabled = true
		root:render(React.createElement(TradeInvitation, {
			senderName = activeInvitation,
			onAccept = function()
				tradeService:fetch("respondToRequest", activeInvitation, true)
				activeInvitation = nil
				updateRender()
			end,
			onDecline = function()
				tradeService:fetch("respondToRequest", activeInvitation, false)
				activeInvitation = nil
				updateRender()
			end,
		}))
	elseif tradeState and tradeState.Active then
		screenGui.Enabled = true
		root:render(React.createElement(TradePanel, {
			state = tradeState,
			localPlayer = player,
			onAddCar = function(carFullName)
				tradeService:fetch("addCarToOffer", carFullName)
			end,
			onRemoveCar = function(carFullName)
				tradeService:fetch("removeCarFromOffer", carFullName)
			end,
			onLock = function()
				tradeService:fetch("lockOffer")
			end,
			onUnlock = function()
				tradeService:fetch("unlockOffer")
			end,
			onConfirm = function()
				tradeService:fetch("confirmTrade")
			end,
			onCancel = function()
				tradeService:fetch("cancelTrade")
			end,
		}))
	elseif playerListIsOpen then
		screenGui.Enabled = true
		root:render(React.createElement(PlayerListPanel, {
			onClose = function()
				playerListIsOpen = false
				updateRender()
			end,
			onInvite = function(targetName)
				local result = tradeService:fetch("sendTradeRequest", targetName) :: any
				if result and result.Success then
					showNotification("Undangan Terkirim", "Berhasil mengirim undangan trade ke " .. targetName)
					playerListIsOpen = false
					updateRender()
				elseif result and result.Error then
					showNotification("Gagal", result.Error)
				else
					showNotification("Gagal", "Gagal mengirim undangan trade.")
				end
			end,
		}))
	else
		screenGui.Enabled = false
		root:render(nil)
	end
end

-- ===== LISTEN TO INVITATIONS & STATE UPDATES =====
tradeInvitationEvent.OnClientEvent:Connect(function(senderName: string, status: string?)
	if status == "declined" then
		showNotification("Trade Ditolak", string.format("%s menolak undangan trade Anda.", senderName))
	elseif status == "error_rebirth" then
		showNotification("Trade Gagal", string.format("%s tidak memenuhi syarat Rebirth (min 5).", senderName))
	elseif status == "error_busy" then
		showNotification("Trade Gagal", string.format("%s sedang sibuk bertransaksi.", senderName))
	else
		-- New invitation request
		activeInvitation = senderName
		updateRender()
	end
end)

tradeStateUpdateEvent.OnClientEvent:Connect(function(state)
	tradeState = state

	if state and not state.Active then
		if state.Success then
			showNotification("Trade Sukses", "Pertukaran mobil berhasil dilakukan!")
		elseif state.Cancelled then
			showNotification("Trade Dibatalkan", "Sesi trade telah dibatalkan.")
		elseif state.Error then
			showNotification("Trade Gagal", "Terjadi kesalahan: " .. tostring(state.Error))
		end
		activeInvitation = nil
		tradeState = nil
		playerListIsOpen = false
	end

	updateRender()
end)

-- ===== DYNAMIC SIDEBAR BUTTON MANAGEMENT =====
local function destroyTradeButton()
	if tradeBtnRegistered then
		UnregisterSidebarButton:Fire("Trade")
		tradeBtnRegistered = false
	end
end

local function createTradeButton()
	if tradeBtnRegistered then
		return
	end
	RegisterSidebarButton:Fire({
		Name = "Trade",
		Label = "Trade",
		Icon = "🤝",
		Order = 4,
		Callback = function()
			playerListIsOpen = not playerListIsOpen
			updateRender()
		end,
	})
	tradeBtnRegistered = true
end

local function onRebirthsChanged()
	local rebirths = 0
	local leaderstatsFolder = player:FindFirstChild("leaderstats")
	local rebirthVal: IntValue? = nil
	if leaderstatsFolder then
		rebirthVal = leaderstatsFolder:FindFirstChild("Rebirth") :: IntValue?
	end
	if rebirthVal then
		rebirths = rebirthVal.Value
	end

	if rebirths >= 5 then
		createTradeButton()
	else
		destroyTradeButton()
		if playerListIsOpen then
			playerListIsOpen = false
			updateRender()
		end
	end
end

-- Connect stats check to Rebirth stat
if leaderstats then
	local rebirthVal = leaderstats:FindFirstChild("Rebirth")
	if rebirthVal then
		rebirthVal.Changed:Connect(onRebirthsChanged)
	end
end
task.defer(onRebirthsChanged)

-- ===== HIDE OWN PROXIMITY PROMPT =====
local function disableOwnPrompt(char: Model)
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if not hrp then
		return
	end

	local function checkPrompt(child: Instance)
		if child.Name == "TradePrompt" and child:IsA("ProximityPrompt") then
			child.Enabled = false
		end
	end

	hrp.ChildAdded:Connect(checkPrompt)
	for _, child in ipairs(hrp:GetChildren()) do
		checkPrompt(child)
	end
end

player.CharacterAdded:Connect(disableOwnPrompt)
if player.Character then
	task.spawn(disableOwnPrompt, player.Character)
end

-- ===== PROXIMITY PROMPT INTERACTION =====
ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered == player and prompt.Name == "TradePrompt" then
		local targetPlayerName = prompt.ObjectText
		local targetPlayer = Players:FindFirstChild(targetPlayerName)
		if targetPlayer then
			local myRebirths = 0
			local statsFolder = player:FindFirstChild("leaderstats")
			local rebirthVal: IntValue? = nil
			if statsFolder then
				rebirthVal = statsFolder:FindFirstChild("Rebirth") :: IntValue?
			end
			if rebirthVal then
				myRebirths = rebirthVal.Value
			end

			if myRebirths < 5 then
				showNotification("Akses Ditolak", "Anda harus memiliki minimal 5 Rebirth untuk melakukan trading.")
				return
			end

			-- Send invitation request
			local result = tradeService:fetch("sendTradeRequest", targetPlayerName) :: any
			if result and result.Success then
				showNotification("Undangan Terkirim", "Undangan trade dikirim ke " .. targetPlayerName)
			elseif result and result.Error then
				showNotification("Gagal", result.Error)
			else
				showNotification("Gagal", "Gagal mengirim undangan trade.")
			end
		end
	end
end)

print(
	"[Client] React MountTradeGui mounting controller siap! Klik tombol 'Trade' di SideMenu atau dekati pemain lain (min. 5 Rebirth) lalu tekan E."
)

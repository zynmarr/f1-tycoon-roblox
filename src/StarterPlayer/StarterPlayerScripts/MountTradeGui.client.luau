--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
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
screenGui.Parent = playerGui

local root = ReactRoblox.createRoot(screenGui)

-- ===== STATE VARIABLES =====
local activeInvitation: string? = nil
local tradeState: any = nil
local playerListIsOpen = false
local tradeBtn: GuiButton? = nil

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
local function updateRender()
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
	local btn = tradeBtn
	if btn then
		btn:Destroy()
		tradeBtn = nil
	end
end

local function createTradeButton()
	if tradeBtn then return end -- Already created

	local sideMenuGui = playerGui:WaitForChild("SideMenuGui", 10)
	if not sideMenuGui then return end

	local container = sideMenuGui:WaitForChild("MainContainer", 10)
	if not container then return end

	-- Find a button template for consistent design
	local template = container:FindFirstChild("BackpackBtn")
		or container:FindFirstChild("ShopBtn")
		or container:FindFirstChild("SettingBtn")
		or container:FindFirstChildOfClass("ImageButton")
		or container:FindFirstChildOfClass("TextButton")

	if template and template:IsA("GuiButton") then
		local clone = (template :: Instance):Clone() :: GuiButton
		clone.Name = "TradeBtn"

		if clone:IsA("TextButton") then
			clone.Text = "🤝 Trade"
		end

		local textLabel = clone:FindFirstChildOfClass("TextLabel") :: TextLabel?
		if textLabel then
			textLabel.Text = "🤝 Trade"
		end

		local imageLabel = clone:FindFirstChildOfClass("ImageLabel") :: ImageLabel?
		if imageLabel then
			imageLabel.Image = "rbxassetid://10609355799" -- Modern shake hands icon
		end
		
		tradeBtn = clone
	else
		-- Fallback modern rounded button
		local manualBtn = Instance.new("TextButton")
		manualBtn.Name = "TradeBtn"
		manualBtn.Size = UDim2.new(1, -10, 0, 40)
		manualBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		manualBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
		manualBtn.Font = Enum.Font.GothamBold
		manualBtn.TextSize = 12
		manualBtn.Text = "🤝 Trade"

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = manualBtn

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(60, 60, 75)
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = manualBtn

		tradeBtn = manualBtn
	end

	local btn = tradeBtn :: GuiButton
	btn.Parent = container

	-- Setup Hover & Click Animations
	local tweenInfo = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local originalSize = btn.Size
	local hoverSize = UDim2.new(originalSize.X.Scale, originalSize.X.Offset + 10, originalSize.Y.Scale, originalSize.Y.Offset + 10)

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, tweenInfo, { Size = hoverSize }):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, tweenInfo, { Size = originalSize }):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), { Size = originalSize }):Play()
	end)

	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btn, tweenInfo, { Size = hoverSize }):Play()
	end)

	-- Click Action
	btn.Activated:Connect(function()
		playerListIsOpen = not playerListIsOpen
		updateRender()
	end)
end

local function onRebirthsChanged()
	local rebirths = 0
	local leaderstatsFolder = player:FindFirstChild("leaderstats")
	local rebirthVal = leaderstatsFolder and leaderstatsFolder:FindFirstChild("Rebirth") :: IntValue?
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

-- ===== PROXIMITY PROMPT INTERACTION =====
ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered == player and prompt.Name == "TradePrompt" then
		local targetPlayerName = prompt.ObjectText
		local targetPlayer = Players:FindFirstChild(targetPlayerName)
		if targetPlayer then
			local myRebirths = 0
			local statsFolder = player:FindFirstChild("leaderstats")
			local rebirthVal = statsFolder and statsFolder:FindFirstChild("Rebirth") :: IntValue?
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

print("[Client] React MountTradeGui mounting controller siap! Klik tombol 'Trade' di SideMenu atau dekati pemain lain (min. 5 Rebirth) lalu tekan E.")

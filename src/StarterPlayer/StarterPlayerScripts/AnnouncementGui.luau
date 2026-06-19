--!strict
local AnnouncementGui = {}

function AnnouncementGui.init()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Menunggu AnnouncementEvent dari server
	local announcementEvent = ReplicatedStorage:WaitForChild("AnnouncementEvent", 15) :: RemoteEvent?
	if not announcementEvent then
		warn("[AnnouncementGui] AnnouncementEvent tidak ditemukan dari server!")
		return
	end

	-- ===== CREATE MODERN GLASS UI =====
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AnnouncementGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.Size = UDim2.new(0.5, 0, 0, 60)
	banner.Position = UDim2.new(0.5, 0, 0, -80) -- Sembunyikan di atas layar
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	banner.BackgroundTransparency = 0.15
	banner.BorderSizePixel = 0
	banner.Parent = screenGui

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(380, 60)
	sizeConstraint.MaxSize = Vector2.new(700, 60)
	sizeConstraint.Parent = banner

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = banner

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 170, 255) -- Warna aksen biru neon
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = banner

	-- Layout horizontal
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.Parent = banner

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 15)
	padding.PaddingRight = UDim.new(0, 15)
	padding.Parent = banner

	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 32, 0, 32)
	icon.BackgroundTransparency = 1
	icon.Text = "📢"
	icon.TextSize = 22
	icon.Font = Enum.Font.GothamBold
	icon.Parent = banner

	-- Pesan
	local msgLabel = Instance.new("TextLabel")
	msgLabel.Name = "Message"
	msgLabel.Size = UDim2.new(1, -90, 1, 0)
	msgLabel.BackgroundTransparency = 1
	msgLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	msgLabel.TextSize = 13
	msgLabel.Font = Enum.Font.GothamMedium
	-- Mengaktifkan RichText untuk format bold/warna dari server
	msgLabel.RichText = true
	msgLabel.TextWrapped = true
	msgLabel.TextXAlignment = Enum.TextXAlignment.Left
	msgLabel.TextYAlignment = Enum.TextYAlignment.Center
	msgLabel.Text = "Pengumuman sistem aktif..."
	msgLabel.Parent = banner

	-- Tombol Tutup
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 24, 0, 24)
	closeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 10
	closeBtn.Text = "X"
	closeBtn.Parent = banner

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = closeBtn

	-- ===== ANIMATION VARIABLES =====
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local hideTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local showPosition = UDim2.new(0.5, 0, 0, 30)
	local hidePosition = UDim2.new(0.5, 0, 0, -80)

	local currentThread: thread? = nil

	local function hideBanner()
		TweenService:Create(banner, hideTweenInfo, { Position = hidePosition }):Play()
	end

	local function showAnnouncement(text: string, duration: number)
		msgLabel.Text = text
		banner.Position = hidePosition
		
		-- Mainkan Animasi Slide Down
		TweenService:Create(banner, tweenInfo, { Position = showPosition }):Play()
		
		-- Batalkan thread timeout sebelumnya jika ada yang sedang berjalan
		if currentThread then
			task.cancel(currentThread)
		end
		
		currentThread = task.delay(duration, function()
			hideBanner()
			currentThread = nil
		end)
	end

	-- Connect Close Button
	closeBtn.Activated:Connect(function()
		if currentThread then
			task.cancel(currentThread)
			currentThread = nil
		end
		hideBanner()
	end)

	-- Hubungkan Event Listener dari Server
	announcementEvent.OnClientEvent:Connect(function(text: string, duration: number)
		showAnnouncement(text, duration or 8)
	end)
end

return AnnouncementGui
